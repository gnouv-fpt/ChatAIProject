import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/views/widgets/contextual_chat_launcher.dart';
import '../models/load_status.dart';
import '../services/learning_progress.dart';
import '../state/auth_view_model.dart';
import '../state/course_catalog.dart';
import '../state/learning_profile_provider.dart';
import '../state/transcript_provider.dart';
import '../theme/app_theme.dart';
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
    final auth = context.watch<AuthViewModel?>();

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

    // Resolve greeting name
    final fullName = auth?.account?.name;
    final greetingName = fullName != null && fullName.trim().isNotEmpty
        ? fullName.trim().split(' ').last
        : 'bạn';

    return Scaffold(
      appBar: FlmAppBar(
        title: 'Cố vấn học tập FLM',
        actions: [
          ContextualChatLauncher(
            curriculumId: catalog.curriculum?.id ?? '',
            contextKey: 'home',
            title: 'trang chủ',
            contextHint: 'Tổng quan tiến độ học tập và chương trình ${catalog.curriculum?.id ?? ''}',
            showLabel: true,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  // 1. User Greeting & Program Identity
                  _buildGreetingHeader(context, greetingName, catalog),
                  const SizedBox(height: 16),

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

                  // 3. Single "Next Step" M3 SummaryCard (Adaptive to transcript state)
                  _buildNextStepCard(
                    context: context,
                    hasTranscript: transcript.hasTranscript,
                    progress: progress,
                    totalCourses: total,
                    totalCredits: totalCredits,
                    transcript: transcript,
                    readyNextCount: readyNext.length,
                  ),
                  const SizedBox(height: 20),

                  // 4. Priority Next Courses (Only shown when transcript is present and courses are ready)
                  if (transcript.hasTranscript && readyNext.isNotEmpty) ...[
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

                  // 5. Advising Goals & Strategy
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

  Widget _buildGreetingHeader(
    BuildContext context,
    String greetingName,
    CourseCatalog catalog,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final curriculumName = catalog.curriculum?.nameVi.isNotEmpty == true
        ? catalog.curriculum!.nameVi
        : (catalog.curriculum?.name ?? 'Kỹ thuật phần mềm');
    final curriculumCode = catalog.curriculum?.id ?? 'BIT_SE_K19B';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chào $greetingName 👋',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$curriculumName · $curriculumCode',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextStepCard({
    required BuildContext context,
    required bool hasTranscript,
    required LearningProgress progress,
    required int totalCourses,
    required int totalCredits,
    required TranscriptProvider transcript,
    required int readyNextCount,
  }) {
    final customColors = context.customColors;

    if (!hasTranscript) {
      // Empty / Initial state: exactly ONE clear CTA to import transcript
      return SummaryCard(
        title: 'Bước tiếp theo: Thiết lập lộ trình',
        subtitle: 'Nhập bảng điểm để tự động theo dõi môn tiên quyết và GPA dự kiến',
        badge: StatusChip.neutral(label: 'Chưa có bảng điểm'),
        metrics: [
          SummaryMetric(
            label: 'Chương trình',
            value: '$totalCourses môn',
            icon: Icons.book_outlined,
          ),
          SummaryMetric(
            label: 'Tổng tín chỉ',
            value: '$totalCredits TC',
            icon: Icons.workspace_premium_outlined,
          ),
          const SummaryMetric(
            label: 'Thời gian',
            value: '9 học kỳ',
            icon: Icons.schedule_rounded,
          ),
        ],
        actionLabel: 'Nhập bảng điểm',
        actionIcon: Icons.upload_file_rounded,
        onAction: () => onNavigate(3),
      );
    }

    // Populated state: detailed academic progress and next term recommendation
    final currentSem = progress.currentSemester ?? 1;
    final nextSem = progress.nextSemester ?? (currentSem + 1);

    return SummaryCard(
      title: 'Học kỳ $currentSem · Kế hoạch kỳ $nextSem',
      subtitle: readyNextCount > 0
          ? 'Có $readyNextCount môn kỳ $nextSem đã đủ điều kiện tiên quyết'
          : 'Đang theo đúng lộ trình đào tạo chuẩn',
      badge: StatusChip.success(label: 'Đang theo dõi'),
      metrics: [
        SummaryMetric(
          label: 'Đã hoàn thành',
          value: '${progress.completedCount}/$totalCourses môn',
          icon: Icons.check_circle_outlined,
          color: customColors.success,
        ),
        SummaryMetric(
          label: 'Tín chỉ tích lũy',
          value: '${transcript.evaluation.totalAccumulatedCredits} TC',
          icon: Icons.workspace_premium_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        SummaryMetric(
          label: 'GPA hiện tại',
          value: transcript.evaluation.totalGpaCredits > 0
              ? transcript.evaluation.currentGpa.toStringAsFixed(2)
              : '—',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF00796B),
        ),
      ],
      actionLabel: 'Xem lộ trình môn học',
      actionIcon: Icons.arrow_forward_rounded,
      onAction: () => onNavigate(1),
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
