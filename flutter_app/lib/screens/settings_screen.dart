import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/providers/chat_provider.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../state/learning_profile_provider.dart';
import '../state/auth_view_model.dart';
import '../models/load_status.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/data_state_view.dart';

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

  Future<void> _clearTranscript() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bảng điểm?'),
        content: Text(
          context.read<TranscriptProvider>().usesCloud
              ? 'Bảng điểm của tài khoản trên Firestore sẽ bị xóa.'
              : 'Dữ liệu bảng điểm đã lưu trên thiết bị sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<TranscriptProvider>().clearTranscript();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa bảng điểm.')));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa bảng điểm. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel?>();
    final profile = context.watch<LearningProfileProvider>();
    if (profile.status == LoadStatus.loading ||
        profile.status == LoadStatus.error) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt'),
          actions: [
            if (auth != null)
              TextButton.icon(
                onPressed: auth.busy ? null : auth.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
          ],
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
    final transcript = context.watch<TranscriptProvider>();
    final chat = context.watch<ChatProvider>();
    final curriculum = context.watch<CourseCatalog>().curriculum;
    return Scaffold(
      appBar: const FlmAppBar(
        title: 'Cài đặt',
        subtitle: 'Tài khoản, mục tiêu học tập và kết nối AI',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (context.read<AuthViewModel?>() case final auth?) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconTile(
                          icon: Icons.verified_user_rounded,
                          color: AppTheme.primaryBlue,
                          size: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.account?.name ?? 'Tài khoản Google',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.slate900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.usesCloud
                                    ? 'Hồ sơ và bảng điểm lưu trên Firestore theo tài khoản.'
                                    : 'Bộ nhớ cá nhân tách theo tài khoản; chưa bật đồng bộ cloud.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (auth.message != null) ...[
                      const SizedBox(height: 8),
                      Text(auth.message!),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: auth.busy ? null : auth.signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (curriculum != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/curricula/${Uri.encodeComponent(curriculum.id)}',
                ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Xem chương trình'),
              ),
            ),
          const SectionHeader(
            title: 'Mục tiêu học tập',
            icon: Icons.flag_rounded,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconTile(
                        icon: Icons.track_changes_rounded,
                        color: Color(0xFF00796B),
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'GPA mục tiêu: ${transcript.targetGpa.toStringAsFixed(1)} / 10',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slate900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (transcript.saveError != null) Text(transcript.saveError!),
                  Slider(
                    value: transcript.targetGpa,
                    min: 0,
                    max: 10,
                    divisions: 100,
                    label: transcript.targetGpa.toStringAsFixed(1),
                    onChanged: transcript.setTargetGpa,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      IconTile(
                        icon: Icons.person_search_rounded,
                        color: Color(0xFF6A1B9A),
                        size: 40,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hồ sơ tư vấn (có thể bổ sung dần)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slate900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (profile.error != null) Text(profile.error!),
                  const SizedBox(height: 12),
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
                    onChanged: (value) =>
                        setState(() => _currentSemester = value),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
                        child: Text('Đọc và tóm tắt'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _learningStyle = value),
                  ),
                  const SizedBox(height: 12),
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
                        child: Text('Hiểu sâu và làm sản phẩm'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _studyPriority = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _longTermGoal,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu dài hạn',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'graduate',
                        child: Text('Hoàn thành chương trình'),
                      ),
                      DropdownMenuItem(
                        value: 'career',
                        child: Text('Chuẩn bị nghề nghiệp'),
                      ),
                      DropdownMenuItem(
                        value: 'study_abroad',
                        child: Text('Chuẩn bị du học'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _longTermGoal = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _careerController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu nghề nghiệp (tùy chọn)',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
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
                                          ? 'Đã lưu hồ sơ lên Firestore.'
                                          : 'Đã lưu hồ sơ tư vấn trên thiết bị.',
                                    ),
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      profile.error ?? 'Không thể lưu hồ sơ. Vui lòng thử lại.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Lưu hồ sơ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader(
            title: 'Kết nối trợ lý AI',
            icon: Icons.smart_toy_rounded,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ API',
                      hintText: 'http://localhost:8000',
                      prefixIcon: Icon(Icons.dns_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final uri = Uri.tryParse(
                              _serverController.text.trim(),
                            );
                            if (uri == null ||
                                !uri.hasAuthority ||
                                (uri.scheme != 'http' &&
                                    uri.scheme != 'https')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nhập địa chỉ API hợp lệ.'),
                                ),
                              );
                              return;
                            }
                            chat.updateBaseUrl(
                              _serverController.text.trim().replaceAll(
                                RegExp(r'/$'),
                                '',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã áp dụng địa chỉ API cho phiên này.',
                                ),
                              ),
                            );
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: chat.checkServerHealth,
                          child: const Text('Thử kết nối'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StatusPill(
                    label: chat.isServerOnline == null
                        ? 'Đang kiểm tra kết nối...'
                        : chat.isServerOnline!
                        ? 'Máy chủ đang hoạt động'
                        : 'Không kết nối được. Dữ liệu môn học vẫn dùng được.',
                    icon: chat.isServerOnline == null
                        ? Icons.sync_rounded
                        : chat.isServerOnline!
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: chat.isServerOnline == true
                        ? AppTheme.success
                        : AppTheme.slate700,
                    background: chat.isServerOnline == true
                        ? AppTheme.successSurface
                        : AppTheme.slate100,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Dữ liệu', icon: Icons.storage_rounded),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const IconTile(
                    icon: Icons.refresh_rounded,
                    color: AppTheme.primaryBlue,
                    size: 40,
                  ),
                  title: const Text('Tải lại dữ liệu môn học'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: context.read<CourseCatalog>().load,
                ),
                const Divider(height: 1, indent: 68),
                ListTile(
                  leading: const IconTile(
                    icon: Icons.delete_outline_rounded,
                    color: AppTheme.danger,
                    size: 40,
                  ),
                  title: const Text('Xóa bảng điểm trên thiết bị'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: transcript.hasTranscript ? _clearTranscript : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
