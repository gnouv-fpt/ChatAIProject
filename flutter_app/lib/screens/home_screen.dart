import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../state/learning_profile_provider.dart';
import '../services/learning_progress.dart';
import '../theme/app_theme.dart';
import '../models/load_status.dart';
import '../widgets/data_state_view.dart';
import '../widgets/learning_journey_card.dart';

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
    final inProgress = progress.inProgressCodes.toList()..sort();
    final nextCourses = progress.nextSemesterCourses;
    final readyNext = nextCourses
        .where(
          (course) =>
              progress.status(course).readiness == CourseReadiness.ready,
        )
        .toList();
    final total = catalog.courses.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Cố vấn học tập FLM')),
      body: catalog.isLoading && total == 0
          ? const Center(child: CircularProgressIndicator())
          : catalog.error != null && total == 0
          ? _LoadError(message: catalog.error!, onRetry: catalog.load)
          : RefreshIndicator(
              onRefresh: catalog.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    catalog.curriculum?.nameVi ?? 'Chương trình đào tạo',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (transcript.status == LoadStatus.loading ||
                      transcript.status == LoadStatus.error)
                    DataStateView(
                      status: transcript.status,
                      message: transcript.loadError,
                      onRetry: transcript.status == LoadStatus.error
                          ? transcript.load
                          : null,
                    )
                  else
                    LearningJourneyCard(
                      progress: progress,
                      hasTranscript: transcript.hasTranscript,
                      nextStep: readyNext.isNotEmpty
                          ? 'Có ${readyNext.length} môn kỳ tới đủ điều kiện học.'
                          : null,
                      onOpen: () =>
                          onNavigate(transcript.hasTranscript ? 1 : 3),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Tín chỉ tích lũy',
                          value: transcript.hasTranscript
                              ? '${transcript.evaluation.totalAccumulatedCredits}'
                              : '—',
                          icon: Icons.school_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: 'GPA hiện tại',
                          value:
                              transcript.hasTranscript &&
                                  transcript.evaluation.totalGpaCredits > 0
                              ? transcript.evaluation.currentGpa
                                    .toStringAsFixed(2)
                              : '—',
                          icon: Icons.insights_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vị trí hiện tại',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            progress.currentSemester == null
                                ? 'Chưa xác định học kỳ: hãy nhập bảng điểm để cá nhân hóa lộ trình.'
                                : profile.currentSemester != null
                                ? 'Học kỳ hiện tại bạn xác nhận: ${progress.currentSemester}'
                                : inProgress.isEmpty
                                ? 'Học kỳ gần nhất có kết quả: ${progress.currentSemester}'
                                : 'Học kỳ suy ra từ môn đang học: ${progress.currentSemester}',
                          ),
                          if (inProgress.isNotEmpty)
                            Text('Môn đang học: ${inProgress.join(', ')}'),
                          if (progress.nextSemester != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Kỳ ${progress.nextSemester}: ${readyNext.length}/${nextCourses.length} môn đủ tiên quyết theo bảng điểm đã nhập.',
                            ),
                            if (readyNext.isNotEmpty)
                              ...readyNext
                                  .take(3)
                                  .map(
                                    (course) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.check_circle_outline,
                                        color: AppTheme.success,
                                      ),
                                      title: Text(
                                        '${course.code} · ${course.nameVi.isEmpty ? course.name : course.nameVi}',
                                      ),
                                      subtitle: const Text(
                                        'Xem điều kiện và nhận tư vấn theo mục tiêu',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/courses/${Uri.encodeComponent(course.code)}',
                                      ),
                                    ),
                                  ),
                          ],
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                onNavigate(transcript.hasTranscript ? 1 : 3),
                            icon: Icon(
                              transcript.hasTranscript
                                  ? Icons.route
                                  : Icons.edit_note,
                            ),
                            label: Text(
                              transcript.hasTranscript
                                  ? 'Xem môn kỳ tới và điều kiện học'
                                  : 'Nhập kết quả học tập',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('Mục tiêu và cách học của bạn'),
                      subtitle: Text(
                        profile.courseGoal == null
                            ? 'Bổ sung mục tiêu để nhận chiến lược phù hợp.'
                            : profile.courseGoal == 'pass'
                            ? 'Ưu tiên qua môn · Có thể cập nhật bất cứ lúc nào.'
                            : 'Ưu tiên điểm cao · Có thể cập nhật bất cứ lúc nào.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onNavigate(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Khám phá thêm',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.route,
                        color: AppTheme.primaryBlue,
                      ),
                      title: const Text('Khám phá lộ trình môn học'),
                      subtitle: const Text('Xem môn tiên quyết và sơ đồ'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onNavigate(1),
                    ),
                  ),
                  if (catalog.curriculum != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.account_tree_outlined,
                          color: AppTheme.primaryBlue,
                        ),
                        title: const Text('Chương trình đào tạo'),
                        subtitle: const Text(
                          'Xem tổng quan và chi tiết học kỳ',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/curricula/${Uri.encodeComponent(catalog.curriculum!.id)}',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.smart_toy_outlined,
                        color: AppTheme.primaryBlue,
                      ),
                      title: const Text('Hỏi trợ lý AI'),
                      subtitle: const Text('Tra cứu môn học và tư vấn học tập'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onNavigate(2),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryBlue),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppTheme.accentOrange,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
