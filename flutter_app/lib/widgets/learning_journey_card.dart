import 'package:flutter/material.dart';

import '../services/learning_progress.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

class LearningJourneyCard extends StatelessWidget {
  const LearningJourneyCard({
    super.key,
    required this.progress,
    required this.hasTranscript,
    required this.onOpen,
    this.nextStep,
  });
  final LearningProgress progress;
  final bool hasTranscript;
  final VoidCallback onOpen;
  final String? nextStep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(
                  icon: Icons.route_rounded,
                  color: AppTheme.primaryBlue,
                  size: 40,
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Text(
                    'Hành trình học của bạn',
                    style: text.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              hasTranscript
                  ? '${progress.completedCount}/${progress.totalCount} môn đã hoàn thành'
                  : 'Bắt đầu từ kết quả của bạn',
              style: text.titleLarge,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            if (hasTranscript) ...[
              LinearProgressIndicator(
                value: progress.completionRatio,
                minHeight: AppTheme.spaceSm,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                semanticsLabel: 'Tiến độ theo bảng điểm đã nhập',
                semanticsValue: '${(progress.completionRatio * 100).round()}%',
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Wrap(
                spacing: AppTheme.spaceSm,
                runSpacing: AppTheme.spaceSm,
                children: [
                  _stat(
                    context,
                    'Còn lại',
                    progress.remainingCount,
                    AppTheme.primaryDark,
                  ),
                  _stat(
                    context,
                    'Đang học',
                    progress.ongoingCount,
                    AppTheme.primaryDark,
                  ),
                  _stat(
                    context,
                    'Cần học lại',
                    progress.failedCodes.length,
                    AppTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),
            ] else
              Text(
                'Nhập điểm để biết đã học tới đâu, còn bao nhiêu môn và môn nào cần ưu tiên. Chưa có điểm vẫn có thể khám phá chương trình.',
                style: text.bodyMedium,
              ),
            if (hasTranscript && nextStep != null)
              Text(nextStep!, style: text.bodyMedium),
            const SizedBox(height: AppTheme.spaceMd),
            FilledButton.icon(
              onPressed: onOpen,
              icon: Icon(hasTranscript ? Icons.route : Icons.edit_note),
              label: Text(
                hasTranscript ? 'Mở lộ trình học' : 'Bổ sung bảng điểm',
              ),
            ),
            if (hasTranscript) ...[
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('Theo từng học kỳ', style: text.titleMedium),
                children: [
                  Wrap(
                    spacing: AppTheme.spaceSm,
                    runSpacing: AppTheme.spaceSm,
                    children: [
                      for (final semester in progress.semesters)
                        Semantics(
                          label:
                              'Học kỳ ${semester.semester}, hoàn thành ${semester.completed} trên ${semester.total} môn',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceMd,
                              vertical: AppTheme.spaceSm,
                            ),
                            decoration: BoxDecoration(
                              color: semester.completed == semester.total
                                  ? AppTheme.successSurface
                                  : AppTheme.slate100,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd,
                              ),
                            ),
                            child: Text(
                              'HK${semester.semester} · ${semester.completed}/${semester.total}',
                              style: text.bodyMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                'Theo bảng điểm đã nhập. Còn lại gồm môn đang học và môn chưa có kết quả trong chương trình.',
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      );
}
