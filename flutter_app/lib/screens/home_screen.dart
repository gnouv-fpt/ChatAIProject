import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_launcher.dart';
import '../models/load_status.dart';
import '../services/learning_progress.dart';
import '../state/course_catalog.dart';
import '../state/learning_profile_provider.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
import '../utils/curriculum_formatters.dart';
import '../widgets/app_ui.dart';
import '../widgets/m3_components.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CourseCatalog>();
    final transcript = context.watch<TranscriptProvider>();
    final profile = context.watch<LearningProfileProvider>();

    final progress = LearningProgress(
      catalog.courses,
      transcript.entries,
      currentSemester: profile.currentSemester,
    );
    final nextCourses = progress.nextSemesterCourses;
    final readyNext = nextCourses
        .where(
          (course) => progress.status(course).readiness == CourseReadiness.ready,
        )
        .toList();
    final total = catalog.courses.length;
    final totalCredits = catalog.courses.fold<int>(0, (sum, c) => sum + c.credits);



    return Scaffold(
      appBar: FlmAppBar(
        title: 'Cố vấn học tập FLM',
        subtitle: formatProgramSubtitle(
          nameVi: catalog.curriculum?.nameVi,
          name: catalog.curriculum?.name,
        ),
        actions: [
          ContextualChatLauncher(
            curriculumId: catalog.curriculum?.id ?? '',
            contextKey: 'home',
            title: 'trang chủ',
            contextHint: 'Tổng quan tiến độ học tập và chương trình ${catalog.curriculum?.id ?? ''}',
            suggestedQuestions: const [
              'Tôi nên học gì tiếp theo?',
              'Tóm tắt tiến độ học tập của tôi.',
            ],
          ),
        ],
      ),
      body: catalog.isLoading && total == 0
          ? _buildLoadingSkeleton(context)
          : catalog.error != null && total == 0
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Không thể tải dữ liệu môn học',
              description: catalog.error!,
              actionLabel: 'Thử lại',
              actionIcon: Icons.refresh_rounded,
              onAction: catalog.load,
            )
          : RefreshIndicator(
              onRefresh: catalog.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [

                  // 2. Offline / Cloud status banner (if needed)
                  if (transcript.status == LoadStatus.error && transcript.loadError != null) ...[
                    InlineBanner(
                      message: transcript.loadError!,
                      severity: BannerSeverity.warning,
                      actionLabel: 'Thử lại',
                      onAction: transcript.load,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Compact Hero Card with Blue Gradient & High-Contrast White CTA
                  _buildHeroCard(
                    context: context,
                    hasTranscript: transcript.hasTranscript,
                    progress: progress,
                    totalCourses: total,
                    totalCredits: totalCredits,
                    totalSemesters: catalog.totalSemesters,
                    transcript: transcript,
                    readyNextCount: readyNext.length,
                  ),
                  const SizedBox(height: 20),

                  // 4. If empty: 3-step onboarding checklist; If populated: Priority courses + goals
                  if (!transcript.hasTranscript) ...[
                    _buildOnboardingChecklist(context, transcript),
                    const SizedBox(height: 20),
                  ] else ...[
                    if (readyNext.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Môn ưu tiên kỳ tới',
                        icon: Icons.playlist_add_check_circle_outlined,
                        trailing: TextButton(
                          onPressed: () => onNavigate(1),
                          child: Text('Xem tất cả (${readyNext.length})'),
                        ),
                      ),
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < readyNext.take(3).length; i++) ...[
                              if (i > 0) const Divider(height: 1, indent: 64),
                              ListTile(
                                leading: IconTile(
                                  icon: Icons.play_circle_outline_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 40,
                                ),
                                title: Text(
                                  '${readyNext[i].code} · ${readyNext[i].nameVi.isNotEmpty ? readyNext[i].nameVi : readyNext[i].name}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${readyNext[i].credits} tín chỉ · Đủ điều kiện học',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: StatusChip.eligible(compact: true),
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/courses/${Uri.encodeComponent(readyNext[i].code)}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    SectionHeader(
                      title: 'Mục tiêu học tập',
                      icon: Icons.flag_outlined,
                    ),
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: SettingsTile(
                        leadingIcon: Icons.tune_rounded,
                        leadingColor: AppTheme.accentOrange,
                        title: profile.courseGoal == 'pass'
                            ? 'Ưu tiên qua môn an toàn'
                            : 'Ưu tiên điểm số cao (GPA)',
                        subtitle: profile.courseGoal == null
                            ? 'Thiết lập mục tiêu để nhận tư vấn môn học phù hợp'
                            : 'Mục tiêu GPA: ${transcript.targetGpa.toStringAsFixed(1)} · Chạm để thay đổi',
                        onTap: () => onNavigate(4),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6. Quick Shortcuts (No duplicate items with BottomNavigationBar)
                  if (catalog.curriculum != null) ...[
                    SectionHeader(
                      title: 'Khám phá chương trình',
                      icon: Icons.account_tree_outlined,
                    ),
                    Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const IconTile(
                              icon: Icons.menu_book_rounded,
                              color: Color(0xFF00796B),
                              size: 40,
                            ),
                            title: const Text(
                              'Khung chương trình đào tạo',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                            ),
                            subtitle: Text(
                              'Chi tiết các học kỳ, chuẩn đầu ra (PLO) và cấu trúc môn',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/curricula/${Uri.encodeComponent(catalog.curriculum!.id)}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }



  Widget _buildHeroCard({
    required BuildContext context,
    required bool hasTranscript,
    required LearningProgress progress,
    required int totalCourses,
    required int totalCredits,
    required int totalSemesters,
    required TranscriptProvider transcript,
    required int readyNextCount,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? const [Color(0xFF1E3A8A), Color(0xFF0F172A)]
        : const [Color(0xFF1565C0), Color(0xFF0D47A1)];

    final currentSem = progress.currentSemester ?? 1;
    final nextSem = progress.nextSemester ?? (currentSem + 1);

    final descText = !hasTranscript
        ? 'Bạn chưa nhập bảng điểm. Hãy nhập để nhận lộ trình gợi ý.'
        : readyNextCount > 0
            ? 'Có $readyNextCount môn kỳ $nextSem đã đủ điều kiện tiên quyết.'
            : 'Đang theo đúng lộ trình đào tạo chuẩn.';

    final ctaLabel = !hasTranscript ? 'Nhập bảng điểm ngay' : 'Xem gợi ý môn kỳ tới';
    final ctaIcon = !hasTranscript ? Icons.upload_file_rounded : Icons.arrow_forward_rounded;
    final onCtaPressed = !hasTranscript ? () => onNavigate(3) : () => onNavigate(1);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: isDark ? 0.3 : 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'BƯỚC TIẾP THEO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasTranscript) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Đang theo dõi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            descText,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Translucent metrics row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: !hasTranscript
                  ? [
                      _buildMetricItem('$totalCourses môn', 'Chương trình'),
                      _buildMetricDivider(),
                      _buildMetricItem(formatCurriculumCredits(totalCredits, compact: true), 'Tổng số'),
                      _buildMetricDivider(),
                      _buildMetricItem(formatCurriculumSemesters(totalSemesters, compact: true), 'Thời gian'),
                    ]
                  : [
                      _buildMetricItem('${progress.completedCount}/$totalCourses môn', 'Đã xong'),
                      _buildMetricDivider(),
                      _buildMetricItem('${transcript.evaluation.totalAccumulatedCredits}/$totalCredits TC', 'Tích lũy'),
                      _buildMetricDivider(),
                      _buildMetricItem(
                        transcript.evaluation.totalGpaCredits > 0
                            ? transcript.evaluation.currentGpa.toStringAsFixed(2)
                            : '—',
                        'GPA hiện tại',
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 12),
          // Full-width 48dp CTA button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onCtaPressed,
              icon: Icon(ctaIcon, size: 18),
              label: Text(
                ctaLabel,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 22,
      color: Colors.white.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildOnboardingChecklist(BuildContext context, TranscriptProvider transcript) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasTranscript = transcript.hasTranscript;
    final targetGpa = transcript.targetGpa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '3 bước bắt đầu',
          icon: Icons.checklist_rounded,
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: IconTile(
                  icon: hasTranscript ? Icons.check_circle_rounded : Icons.looks_one_rounded,
                  color: hasTranscript ? AppTheme.success : colorScheme.primary,
                  size: 40,
                ),
                title: const Text(
                  '1. Nhập bảng điểm',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: Text(
                  hasTranscript
                      ? 'Đã hoàn thành · Sẵn sàng phân tích lộ trình'
                      : 'Tải ảnh hoặc nhập điểm thủ công để bắt đầu',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
                trailing: hasTranscript
                    ? StatusChip.success(label: 'Đã xong', compact: true)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => onNavigate(3),
              ),
              const Divider(height: 1, indent: 64),
              ListTile(
                leading: const IconTile(
                  icon: Icons.looks_two_rounded,
                  color: AppTheme.accentOrange,
                  size: 40,
                ),
                title: const Text(
                  '2. Đặt mục tiêu GPA',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: Text(
                  transcript.hasExplicitTargetGpa
                      ? 'Mục tiêu đã đặt: ${targetGpa.toStringAsFixed(1)} · Chạm để điều chỉnh'
                      : 'Chưa đặt · mặc định 8.0 · Chạm để thiết lập',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
                trailing: transcript.hasExplicitTargetGpa
                    ? StatusChip.info(label: targetGpa.toStringAsFixed(1), compact: true)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () => onNavigate(4),
              ),
              const Divider(height: 1, indent: 64),
              ListTile(
                leading: IconTile(
                  icon: hasTranscript ? Icons.looks_3_rounded : Icons.lock_outline_rounded,
                  color: hasTranscript
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                  size: 40,
                ),
                title: Text(
                  '3. Xem môn nên học kỳ tới',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  hasTranscript
                      ? 'Xem các môn đủ điều kiện tiên quyết'
                      : 'Cần nhập bảng điểm ở bước 1 để mở khóa gợi ý môn',
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
                trailing: hasTranscript
                    ? const Icon(Icons.chevron_right_rounded)
                    : Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                onTap: hasTranscript ? () => onNavigate(1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonLine(width: 180, height: 24),
        SizedBox(height: 6),
        SkeletonLine(width: 120, height: 14),
        SizedBox(height: 16),
        SkeletonCard(height: 140),
        SizedBox(height: 20),
        SkeletonLine(width: 140, height: 18),
        SizedBox(height: 12),
        SkeletonCard(height: 90),
        SizedBox(height: 12),
        SkeletonCard(height: 90),
      ],
    );
  }
}
