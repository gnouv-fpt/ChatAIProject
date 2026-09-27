import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/course_node.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class CourseSummaryModal extends StatelessWidget {
  final String code;
  final String name;
  final String nameVi;
  final int semester;
  final int credits;
  final bool hasPe;
  final bool countsInGpa;
  final List<String> prerequisites;
  final VoidCallback onDetailsPressed;
  final VoidCallback? onAdvisorPressed;
  final VoidCallback? onLinksPressed;

  const CourseSummaryModal({
    super.key,
    required this.code,
    required this.name,
    this.nameVi = '',
    required this.semester,
    required this.credits,
    this.hasPe = false,
    this.countsInGpa = true,
    this.prerequisites = const [],
    required this.onDetailsPressed,
    this.onAdvisorPressed,
    this.onLinksPressed,
  });

  static void showFromNode(
    BuildContext context, {
    required CourseNode course,
    required VoidCallback onDetailsPressed,
    VoidCallback? onAdvisorPressed,
    VoidCallback? onLinksPressed,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CourseSummaryModal(
        code: course.id,
        name: course.name,
        semester: course.semester,
        credits: course.credits,
        prerequisites: course.prerequisites,
        onDetailsPressed: () {
          Navigator.of(ctx).pop();
          onDetailsPressed();
        },
        onAdvisorPressed: onAdvisorPressed != null
            ? () {
                Navigator.of(ctx).pop();
                onAdvisorPressed();
              }
            : null,
        onLinksPressed: onLinksPressed != null
            ? () {
                Navigator.of(ctx).pop();
                onLinksPressed();
              }
            : null,
      ),
    );
  }

  static void showFromCourse(
    BuildContext context, {
    required Course course,
    required VoidCallback onDetailsPressed,
    VoidCallback? onAdvisorPressed,
    VoidCallback? onLinksPressed,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CourseSummaryModal(
        code: course.code,
        name: course.name,
        nameVi: course.nameVi,
        semester: course.semester,
        credits: course.credits,
        hasPe: course.hasPe,
        countsInGpa: course.countsInGpa,
        prerequisites: course.prerequisites,
        onDetailsPressed: () {
          Navigator.of(ctx).pop();
          onDetailsPressed();
        },
        onAdvisorPressed: onAdvisorPressed != null
            ? () {
                Navigator.of(ctx).pop();
                onAdvisorPressed();
              }
            : null,
        onLinksPressed: onLinksPressed != null
            ? () {
                Navigator.of(ctx).pop();
                onLinksPressed();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.semester(semester),
              const SizedBox(width: 6),
              StatusBadge.credits(credits),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Đóng',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nameVi.isNotEmpty ? nameVi : name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.slate900,
            ),
          ),
          if (nameVi.isNotEmpty && name.isNotEmpty && nameVi != name) ...[
            const SizedBox(height: 3),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusBadge.pe(hasPe: hasPe),
              StatusBadge.gpa(countsInGpa: countsInGpa),
              if (prerequisites.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    'Tiên quyết: ' + prerequisites.join(', '),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text(
                    'Xem chi tiết',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onDetailsPressed,
                ),
              ),
              if (onAdvisorPressed != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentOrange,
                      side: const BorderSide(color: AppTheme.accentOrange, width: 1.3),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.psychology_outlined, size: 18),
                    label: const Text(
                      'Tư vấn',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onAdvisorPressed,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
