import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/chat/providers/chat_provider.dart';
import '../models/load_status.dart';
import '../state/auth_view_model.dart';
import '../state/course_catalog.dart';
import '../state/learning_profile_provider.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/data_state_view.dart';
import '../widgets/m3_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverController;
  late final TextEditingController _careerController;
  bool _profileHydrated = false;
  String? _courseGoal;
  String? _learningStyle;
  String? _studyPriority;
  String? _longTermGoal;
  int? _currentSemester;

  double? _targetGpa;
  int _versionTapCount = 0;
  bool _developerMode = !kReleaseMode;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(
      text: context.read<ChatProvider>().baseUrl,
    );
    final profile = context.read<LearningProfileProvider>();
    _courseGoal = profile.courseGoal;
    _learningStyle = profile.learningStyle;
    _studyPriority = profile.studyPriority;
    _longTermGoal = profile.longTermGoal;
    _currentSemester = profile.currentSemester;
    _careerController = TextEditingController(text: profile.careerGoal ?? '');
    _profileHydrated = profile.isLoaded;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _careerController.dispose();
    super.dispose();
  }

  Future<void> _signOut(AuthViewModel auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất tài khoản?'),
        content: const Text(
          'Bạn sẽ cần đăng nhập lại bằng Google để đồng bộ bảng điểm và lịch sử học tập.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await auth.signOut();
    }
  }

  Future<void> _clearTranscript() async {
    final transcript = context.read<TranscriptProvider>();
    final usesCloud = transcript.usesCloud;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bảng điểm?'),
        content: Text(
          usesCloud
              ? 'Bảng điểm lưu trong tài khoản của bạn sẽ bị xóa hoàn toàn. Bạn có thể nhập lại bất kỳ lúc nào.'
              : 'Dữ liệu bảng điểm đã lưu trên thiết bị này sẽ bị xóa hoàn toàn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await transcript.clearTranscript();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa bảng điểm.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa bảng điểm. Vui lòng thử lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onVersionTapped() {
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      setState(() => _developerMode = !_developerMode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _developerMode
                ? 'Đã mở khóa Cấu hình máy chủ nâng cao.'
                : 'Đã ẩn Cấu hình máy chủ nâng cao.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthViewModel?>();
    final profile = context.watch<LearningProfileProvider>();
    final transcript = context.watch<TranscriptProvider>();
    final chat = context.watch<ChatProvider>();
    final catalog = context.watch<CourseCatalog>();
    final curriculum = catalog.curriculum;

    if (profile.status == LoadStatus.loading ||
        profile.status == LoadStatus.error) {
      return Scaffold(
        appBar: const FlmAppBar(
          title: 'Cài đặt',
          subtitle: 'Tài khoản, mục tiêu học tập và kết nối AI',
        ),
        body: DataStateView(
          status: profile.status,
          message: profile.error,
          onRetry: profile.status == LoadStatus.error
              ? () => profile.load(retry: true)
              : null,
        ),
      );
    }

    if (!_profileHydrated && profile.isLoaded) {
      _courseGoal = profile.courseGoal;
      _learningStyle = profile.learningStyle;
      _studyPriority = profile.studyPriority;
      _longTermGoal = profile.longTermGoal;
      _currentSemester = profile.currentSemester;
      _careerController.text = profile.careerGoal ?? '';
      _profileHydrated = true;
    }

    // Keep local target GPA aligned with provider unless user is dragging
    final effectiveTargetGpa = (_targetGpa ?? transcript.targetGpa).clamp(5.0, 10.0);

    return Scaffold(
      appBar: const FlmAppBar(
        title: 'Cài đặt',
        subtitle: 'Tài khoản, mục tiêu học tập và kết nối AI',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          // ==========================================
          // 1. PHẦN TÀI KHOẢN (ACCOUNT)
          // ==========================================
          const SectionHeader(
            title: 'Tài khoản',
            icon: Icons.account_circle_outlined,
          ),
          const SizedBox(height: 6),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: Text(
                          (auth?.account?.name ?? 'U').characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth?.account?.name ?? 'Người dùng FLM',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth?.account?.email?.isNotEmpty == true
                                  ? auth!.account!.email!
                                  : (auth?.account?.uid.isNotEmpty == true
                                      ? 'Tài khoản Google đã kết nối'
                                      : 'Tài khoản khách'),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          profile.usesCloud
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_off_rounded,
                          size: 16,
                          color: profile.usesCloud
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profile.usesCloud
                                ? 'Đã đồng bộ với tài khoản.'
                                : 'Dữ liệu lưu riêng tư trên thiết bị.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (auth?.message != null) ...[
                    const SizedBox(height: 10),
                    InlineBanner(
                      message: auth!.message!,
                      severity: BannerSeverity.info,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================
          // 2. PHẦN MỤC TIÊU HỌC TẬP (LEARNING GOALS)
          // ==========================================
          const SectionHeader(
            title: 'Mục tiêu học tập',
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 6),

          // "Xem chương trình" moved into this section
          if (curriculum != null) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.account_tree_outlined,
                  color: colorScheme.primary,
                ),
                title: Text(
                  'Chương trình đào tạo: ${curriculum.id}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${curriculum.nameVi.isNotEmpty ? curriculum.nameVi : curriculum.name} · ${curriculum.totalCredits} tín chỉ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/curricula/${Uri.encodeComponent(curriculum.id)}',
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // GPA Slider Card (5.0 - 10.0, step 0.5, large display, end labels, haptic, auto-save)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        'Mục tiêu GPA',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            effectiveTargetGpa.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            ' / 10',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kéo để thay đổi mục tiêu GPA (bước 0.5). Hệ thống tự lưu.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: colorScheme.primary,
                      thumbColor: colorScheme.primary,
                      overlayColor: colorScheme.primary.withValues(alpha: 0.12),
                      valueIndicatorColor: colorScheme.primary,
                      showValueIndicator: ShowValueIndicator.onDrag,
                    ),
                    child: Slider(
                      value: effectiveTargetGpa,
                      min: 5.0,
                      max: 10.0,
                      divisions: 10,
                      label: effectiveTargetGpa.toStringAsFixed(1),
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _targetGpa = val);
                      },
                      onChangeEnd: (val) {
                        transcript.setTargetGpa(val);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã lưu mục tiêu GPA: ${val.toStringAsFixed(1)}',
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5.0 (Tối thiểu)',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '10.0 (Xuất sắc)',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Consulting Profile Form Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hồ sơ tư vấn học tập',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thông tin này giúp Trợ lý AI đưa ra lời khuyên sát với lộ trình của bạn.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _currentSemester,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ hiện tại (tự xác nhận)',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Chưa xác định'),
                      ),
                      for (var semester = 0; semester <= 12; semester++)
                        DropdownMenuItem(
                          value: semester,
                          child: Text('Học kỳ $semester'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _currentSemester = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _courseGoal,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu môn học',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pass', child: Text('Qua môn')),
                      DropdownMenuItem(
                        value: 'high_score',
                        child: Text('Đạt điểm cao'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _courseGoal = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _learningStyle,
                    decoration: const InputDecoration(
                      labelText: 'Cách học ưu tiên',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'practice',
                        child: Text('Làm bài thực hành'),
                      ),
                      DropdownMenuItem(
                        value: 'reading',
                        child: Text('Đọc và tóm tắt lý thuyết'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _learningStyle = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _studyPriority,
                    decoration: const InputDecoration(
                      labelText: 'Ưu tiên học tập',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'time',
                        child: Text('Tập trung phần quan trọng trước'),
                      ),
                      DropdownMenuItem(
                        value: 'depth',
                        child: Text('Hiểu sâu và làm sản phẩm thực tế'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _studyPriority = value),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _longTermGoal,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu dài hạn',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'graduate',
                        child: Text('Hoàn thành chương trình đúng hạn'),
                      ),
                      DropdownMenuItem(
                        value: 'career',
                        child: Text('Chuẩn bị nghề nghiệp & đi làm'),
                      ),
                      DropdownMenuItem(
                        value: 'study_abroad',
                        child: Text('Chuẩn bị du học & nghiên cứu'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _longTermGoal = value),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _careerController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Định hướng nghề nghiệp (tùy chọn)',
                      hintText: 'Ví dụ: Mobile Developer Flutter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: profile.saving
                          ? null
                          : () async {
                              try {
                                await profile.update(
                                  courseGoal: _courseGoal,
                                  learningStyle: _learningStyle,
                                  studyPriority: _studyPriority,
                                  longTermGoal: _longTermGoal,
                                  currentSemester: _currentSemester,
                                  careerGoal: _careerController.text,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      profile.usesCloud
                                          ? 'Đã lưu hồ sơ tư vấn lên Firestore.'
                                          : 'Đã lưu hồ sơ tư vấn trên thiết bị.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      profile.error ??
                                          'Không thể lưu hồ sơ. Vui lòng thử lại.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      icon: profile.saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(profile.saving ? 'Đang lưu...' : 'Lưu hồ sơ'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================
          // 3. PHẦN TRỢ LÝ AI (AI ASSISTANT)
          // ==========================================
          const SectionHeader(
            title: 'Trợ lý AI',
            icon: Icons.smart_toy_outlined,
          ),
          const SizedBox(height: 6),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trạng thái kết nối',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chat.isServerOnline == true
                                  ? 'Kết nối ổn định với máy chủ cố vấn'
                                  : 'Không kết nối được với máy chủ AI',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (chat.isServerOnline == null)
                        StatusChip.info(label: 'Đang kiểm tra...')
                      else if (chat.isServerOnline == true)
                        StatusChip.success(label: 'Trực tuyến')
                      else
                        StatusChip.error(label: 'Ngoại tuyến'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: chat.checkServerHealth,
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Thử kết nối lại'),
                    ),
                  ),

                  // Advanced Server Config (shown in Debug or if 7-tapped)
                  if (_developerMode) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.build_circle_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: const Text(
                            'Cấu hình máy chủ nâng cao (Nhà phát triển)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ API máy chủ',
                        hintText: 'http://localhost:8000',
                        prefixIcon: Icon(Icons.dns_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: () {
                          final uri = Uri.tryParse(_serverController.text.trim());
                          if (uri == null ||
                              !uri.hasAuthority ||
                              (uri.scheme != 'http' && uri.scheme != 'https')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nhập địa chỉ API hợp lệ.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          chat.updateBaseUrl(
                            _serverController.text.trim().replaceAll(RegExp(r'/$'), ''),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã cập nhật địa chỉ API.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text('Áp dụng URL'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================
          // 4. PHẦN DỮ LIỆU (DATA & DANGER ACTIONS)
          // ==========================================
          const SectionHeader(
            title: 'Dữ liệu',
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 6),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                SettingsTile(
                  title: 'Tải lại dữ liệu môn học',
                  subtitle: 'Cập nhật lại danh mục môn học và điều kiện tiên quyết',
                  leadingIcon: Icons.refresh_rounded,
                  leadingColor: colorScheme.primary,
                  onTap: () {
                    context.read<CourseCatalog>().load();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đang làm mới dữ liệu chương trình...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  indent: 68,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                SettingsTile(
                  title: 'Xóa bảng điểm cá nhân',
                  subtitle: transcript.usesCloud
                      ? 'Xóa toàn bộ điểm số đã lưu trong tài khoản của bạn'
                      : 'Xóa toàn bộ điểm số lưu trên thiết bị này',
                  leadingIcon: Icons.delete_outline_rounded,
                  isDestructive: true,
                  enabled: transcript.hasTranscript,
                  onTap: transcript.hasTranscript ? _clearTranscript : null,
                ),
              ],
            ),
          ),

          // Sign Out Action Button at bottom
          if (auth != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: auth.busy ? null : () => _signOut(auth),
                icon: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: colorScheme.error,
                ),
                label: Text(
                  'Đăng xuất tài khoản',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Version Footer (Tap 7 times to toggle developer options)
          InkWell(
            onTap: _onVersionTapped,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Cố vấn học tập FLM',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Phiên bản 1.0.0${_developerMode ? ' (Chế độ nhà phát triển)' : ''}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
