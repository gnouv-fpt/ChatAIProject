import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/chat/providers/chat_provider.dart';
import '../models/load_status.dart';
import '../state/auth_view_model.dart';
import '../state/course_catalog.dart';
import '../state/learning_profile_provider.dart';
import '../state/theme_provider.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../utils/curriculum_formatters.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _profileHydrated = false;
  String? _courseGoal;
  String? _learningStyle;
  String? _studyPriority;
  String? _longTermGoal;
  int? _currentSemester;

  String? _initialCourseGoal;
  String? _initialLearningStyle;
  String? _initialStudyPriority;
  String? _initialLongTermGoal;
  int? _initialCurrentSemester;
  String _initialCareerGoal = '';

  double? _targetGpa;
  int _versionTapCount = 0;
  bool _developerMode = !kReleaseMode;

  bool get _hasProfileChanges {
    return _courseGoal != _initialCourseGoal ||
        _learningStyle != _initialLearningStyle ||
        _studyPriority != _initialStudyPriority ||
        _longTermGoal != _initialLongTermGoal ||
        _currentSemester != _initialCurrentSemester ||
        _careerController.text.trim() != _initialCareerGoal.trim();
  }

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(
      text: context.read<ChatProvider>().baseUrl,
    );
    final profile = context.read<LearningProfileProvider>();
    _courseGoal = profile.courseGoal;
    _initialCourseGoal = profile.courseGoal;
    _learningStyle = profile.learningStyle;
    _initialLearningStyle = profile.learningStyle;
    _studyPriority = profile.studyPriority;
    _initialStudyPriority = profile.studyPriority;
    _longTermGoal = profile.longTermGoal;
    _initialLongTermGoal = profile.longTermGoal;
    _currentSemester = profile.currentSemester;
    _initialCurrentSemester = profile.currentSemester;
    _careerController = TextEditingController(text: profile.careerGoal ?? '');
    _initialCareerGoal = profile.careerGoal ?? '';
    _careerController.addListener(_onCareerChanged);
    _profileHydrated = profile.isLoaded;
  }

  void _onCareerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _serverController.dispose();
    _careerController.dispose();
    _scrollController.dispose();
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
              ? 'Bảng điểm lưu trong tài khoản của bạn và trên thiết bị này sẽ bị xóa hoàn toàn. Bạn có thể nhập lại bất kỳ lúc nào.'
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
          SnackBar(
            content: Text(
              usesCloud
                  ? 'Đã xóa bảng điểm trong tài khoản và trên thiết bị.'
                  : 'Đã xóa bảng điểm trên thiết bị.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              usesCloud
                  ? 'Không thể xóa bảng điểm trên đám mây. Dữ liệu chưa bị xóa. Vui lòng kiểm tra mạng và thử lại.'
                  : 'Không thể xóa bảng điểm trên thiết bị. Vui lòng thử lại.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasProfileChanges) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa lưu?'),
        content: const Text(
          'Bạn có thay đổi trong hồ sơ tư vấn chưa được lưu. Bạn có muốn bỏ các thay đổi này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _courseGoal = _initialCourseGoal;
        _learningStyle = _initialLearningStyle;
        _studyPriority = _initialStudyPriority;
        _longTermGoal = _initialLongTermGoal;
        _currentSemester = _initialCurrentSemester;
        _careerController.text = _initialCareerGoal;
      });
      return true;
    }
    return false;
  }

  Future<void> _saveProfile(LearningProfileProvider profile) async {
    try {
      await profile.update(
        courseGoal: _courseGoal,
        learningStyle: _learningStyle,
        studyPriority: _studyPriority,
        longTermGoal: _longTermGoal,
        currentSemester: _currentSemester,
        careerGoal: _careerController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _initialCourseGoal = _courseGoal;
        _initialLearningStyle = _learningStyle;
        _initialStudyPriority = _studyPriority;
        _initialLongTermGoal = _longTermGoal;
        _initialCurrentSemester = _currentSemester;
        _initialCareerGoal = _careerController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu hồ sơ tư vấn học tập thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profile.error ?? 'Không thể lưu hồ sơ. Vui lòng thử lại.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSemesterPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn học kỳ hiện tại',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: const Text('Chưa xác định'),
                    trailing: _currentSemester == null
                        ? Icon(Icons.check_rounded, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _currentSemester = null);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  for (var s = 0; s <= 12; s++)
                    ListTile(
                      title: Text('Học kỳ $s'),
                      trailing: _currentSemester == s
                          ? Icon(Icons.check_rounded, color: colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() => _currentSemester = s);
                        Navigator.pop(sheetCtx);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileChoiceField({
    required String label,
    required String helperText,
    required String displayValue,
    required List<({String key, String label})> options,
    required String? selectedKey,
    required ValueChanged<String?> onSelected,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: displayValue == 'Chưa chọn'
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayValue == 'Chưa chọn' ? 'Chưa chọn' : 'Đã chọn: $displayValue',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: displayValue == 'Chưa chọn'
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          helperText,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((opt) {
            final isSelected = selectedKey == opt.key;
            return ChoiceChip(
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (selected) {
                onSelected(selected ? opt.key : null);
              },
            );
          }).toList(),
        ),
      ],
    );
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
    ThemeProvider? themeProvider;
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (_) {}
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
      _initialCourseGoal = profile.courseGoal;
      _learningStyle = profile.learningStyle;
      _initialLearningStyle = profile.learningStyle;
      _studyPriority = profile.studyPriority;
      _initialStudyPriority = profile.studyPriority;
      _longTermGoal = profile.longTermGoal;
      _initialLongTermGoal = profile.longTermGoal;
      _currentSemester = profile.currentSemester;
      _initialCurrentSemester = profile.currentSemester;
      _careerController.text = profile.careerGoal ?? '';
      _initialCareerGoal = profile.careerGoal ?? '';
      _profileHydrated = true;
    }

    // Keep local target GPA aligned with provider unless user is dragging
    final effectiveTargetGpa = (_targetGpa ?? transcript.targetGpa).clamp(5.0, 10.0);

    if (kIsWeb) {
      final scrollParam = Uri.base.queryParameters['scroll'];
      if (scrollParam != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            if (scrollParam == 'bottom') {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            } else if (scrollParam == 'profile') {
              _scrollController.jumpTo(420.0);
            } else if (scrollParam == 'data') {
              _scrollController.jumpTo(1150.0);
            }
          }
        });
      }
    }

    return PopScope(
      canPop: !_hasProfileChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldDiscard = await _confirmDiscardChanges();
        if (shouldDiscard && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: const FlmAppBar(
          title: 'Cài đặt',
          subtitle: 'Tài khoản, mục tiêu học tập và kết nối AI',
        ),
        body: ListView(
        controller: _scrollController,
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
                  '${formatMajorName(nameVi: curriculum.nameVi, name: curriculum.name)} · ${formatCurriculumCredits(catalog.totalCredits > 100 ? catalog.totalCredits : (curriculum.totalCredits > 0 ? curriculum.totalCredits : catalog.totalCredits))}',
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
                      const Flexible(
                        child: Text(
                          'Mục tiêu GPA',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                        Flexible(
                          child: Text(
                            '5.0 (Tối thiểu)',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '10.0 (Xuất sắc)',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
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

                  // 0. Current Semester (Bottom Sheet Picker)
                  InkWell(
                    onTap: _showSemesterPicker,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Học kỳ hiện tại (tự xác nhận)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _currentSemester == null
                                            ? colorScheme.surfaceContainerHighest
                                            : colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _currentSemester != null ? 'Học kỳ $_currentSemester' : 'Chưa chọn',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: _currentSemester == null
                                              ? colorScheme.onSurfaceVariant
                                              : colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Chọn học kỳ từ HK0 đến HK9 để AI gợi ý môn phù hợp giai đoạn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Course Goal (Mục tiêu từng môn)
                  _buildProfileChoiceField(
                    label: 'Mục tiêu từng môn',
                    helperText: 'Lựa chọn giữa "Qua môn" hoặc "Đạt điểm cao"',
                    displayValue: _courseGoal == 'pass'
                        ? 'Qua môn'
                        : _courseGoal == 'high_score'
                            ? 'Đạt điểm cao'
                            : 'Chưa chọn',
                    options: const [
                      (key: 'pass', label: 'Qua môn'),
                      (key: 'high_score', label: 'Đạt điểm cao'),
                    ],
                    selectedKey: _courseGoal,
                    onSelected: (val) => setState(() => _courseGoal = val),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // 2. Learning Style (Hình thức học tập)
                  _buildProfileChoiceField(
                    label: 'Hình thức học tập',
                    helperText: 'Chọn giữa "Làm bài thực hành" hoặc "Đọc và tóm tắt"',
                    displayValue: _learningStyle == 'practice'
                        ? 'Làm bài thực hành'
                        : _learningStyle == 'reading'
                            ? 'Đọc và tóm tắt'
                            : 'Chưa chọn',
                    options: const [
                      (key: 'practice', label: 'Làm bài thực hành'),
                      (key: 'reading', label: 'Đọc và tóm tắt'),
                    ],
                    selectedKey: _learningStyle,
                    onSelected: (val) => setState(() => _learningStyle = val),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // 3. Study Priority (Trọng tâm học kỳ)
                  _buildProfileChoiceField(
                    label: 'Trọng tâm học kỳ',
                    helperText: 'Tập trung vào phần quan trọng trước hoặc hiểu sâu để làm sản phẩm',
                    displayValue: _studyPriority == 'time'
                        ? 'Tập trung phần quan trọng trước'
                        : _studyPriority == 'depth'
                            ? 'Hiểu sâu và làm sản phẩm thực tế'
                            : 'Chưa chọn',
                    options: const [
                      (key: 'time', label: 'Tập trung phần quan trọng trước'),
                      (key: 'depth', label: 'Hiểu sâu và làm sản phẩm thực tế'),
                    ],
                    selectedKey: _studyPriority,
                    onSelected: (val) => setState(() => _studyPriority = val),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // 4. Long Term Goal (Định hướng sau tốt nghiệp)
                  _buildProfileChoiceField(
                    label: 'Định hướng sau tốt nghiệp',
                    helperText: 'Hoàn thành đúng hạn, chuẩn bị nghề nghiệp hoặc du học & nghiên cứu',
                    displayValue: _longTermGoal == 'graduate'
                        ? 'Hoàn thành chương trình đúng hạn'
                        : _longTermGoal == 'career'
                            ? 'Chuẩn bị nghề nghiệp'
                            : _longTermGoal == 'study_abroad'
                                ? 'Chuẩn bị du học & nghiên cứu'
                                : 'Chưa chọn',
                    options: const [
                      (key: 'graduate', label: 'Hoàn thành chương trình đúng hạn'),
                      (key: 'career', label: 'Chuẩn bị nghề nghiệp'),
                      (key: 'study_abroad', label: 'Chuẩn bị du học & nghiên cứu'),
                    ],
                    selectedKey: _longTermGoal,
                    onSelected: (val) => setState(() => _longTermGoal = val),
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),

                  // 5. Career Goal (Mục tiêu nghề nghiệp)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Mục tiêu nghề nghiệp (tùy chọn)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _careerController.text.trim().isEmpty
                                  ? colorScheme.surfaceContainerHighest
                                  : colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _careerController.text.trim().isNotEmpty
                                  ? _careerController.text.trim()
                                  : 'Chưa chọn',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _careerController.text.trim().isEmpty
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vị trí hoặc lĩnh vực mong muốn (vd: Mobile Developer Flutter)',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _careerController,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: Mobile Developer Flutter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Save Profile Action Button (Disabled unless dirty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (!profile.saving && _hasProfileChanges)
                          ? () => _saveProfile(profile)
                          : null,
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
                        StatusChip.warning(label: 'Ngoại tuyến'),
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
          // 4. PHẦN GIAO DIỆN (APPEARANCE)
          // ==========================================
          const SectionHeader(
            title: 'Giao diện',
            icon: Icons.palette_outlined,
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
                  Text(
                    'Chế độ hiển thị',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tùy chỉnh giao diện sáng, tối hoặc tự động đồng bộ theo thiết bị.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final currentMode = themeProvider?.themeMode ?? ThemeMode.system;
                      return SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          segments: const [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 18),
                              label: Text(
                                'Hệ thống',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 18),
                              label: Text(
                                'Sáng',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 18),
                              label: Text(
                                'Tối',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          selected: {currentMode},
                          onSelectionChanged: (newSelection) {
                            if (newSelection.isNotEmpty) {
                              themeProvider?.setThemeMode(newSelection.first);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ==========================================
          // 5. PHẦN DỮ LIỆU (DATA & DANGER ACTIONS)
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
                  subtitle: !transcript.hasTranscript
                      ? 'Chưa có bảng điểm để xóa'
                      : (transcript.usesCloud
                          ? 'Xóa toàn bộ điểm số lưu trong tài khoản và trên thiết bị này'
                          : 'Xóa toàn bộ điểm số lưu trên thiết bị này'),
                  leadingIcon: Icons.delete_outline_rounded,
                  isDestructive: transcript.hasTranscript,
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
    ),
  );
}
}
