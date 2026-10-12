import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
  });

  factory StatusBadge.pe({bool hasPe = true}) {
    if (hasPe) {
      return const StatusBadge(
        label: 'Thi PE',
        backgroundColor: AppTheme.peBadgeBg,
        textColor: AppTheme.peBadgeText,
        icon: Icons.code,
      );
    }
    return const StatusBadge(
      label: 'Không PE',
      backgroundColor: AppTheme.slate100,
      textColor: AppTheme.slate600,
      icon: Icons.assignment_outlined,
    );
  }

  factory StatusBadge.gpa({bool countsInGpa = true}) {
    if (countsInGpa) {
      return const StatusBadge(
        label: 'GPA',
        backgroundColor: AppTheme.gpaBadgeBg,
        textColor: AppTheme.gpaBadgeText,
        icon: Icons.check_circle_outline,
      );
    }
    return const StatusBadge(
      label: 'Không GPA',
      backgroundColor: AppTheme.nonGpaBadgeBg,
      textColor: AppTheme.nonGpaBadgeText,
      icon: Icons.remove_circle_outline,
    );
  }

  factory StatusBadge.credits(int credits) {
    return StatusBadge(
      label: '$credits TC',
      backgroundColor: AppTheme.primaryLight,
      textColor: AppTheme.primaryBlue,
      icon: Icons.credit_score,
    );
  }

  factory StatusBadge.semester(int semester) {
    return StatusBadge(
      label: semester == 0 ? 'Giai đoạn 0' : 'Học kỳ $semester',
      backgroundColor: AppTheme.slate100,
      textColor: AppTheme.slate700,
      icon: Icons.calendar_today,
    );
  }

  factory StatusBadge.grade({required double score, required bool isPassed}) {
    final isGood = score >= 7.0;
    final color = isPassed
        ? (isGood ? const Color(0xFF16A34A) : const Color(0xFF2563EB))
        : const Color(0xFFDC2626);
    final bg = isPassed
        ? (isGood ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE))
        : const Color(0xFFFEE2E2);
    return StatusBadge(
      label: '${score.toStringAsFixed(1)} • ${isPassed ? "Đạt" : "Học lại"}',
      backgroundColor: bg,
      textColor: color,
      icon: isPassed ? Icons.check_circle : Icons.warning_amber_rounded,
    );
  }

  factory StatusBadge.learningStatus(String status, {double? score}) {
    switch (status) {
      case 'passed':
        final text = score != null ? '${score.toStringAsFixed(1)} • Đạt' : 'Đã học';
        return StatusBadge(
          label: '$text ▾',
          backgroundColor: const Color(0xFFDCFCE7),
          textColor: const Color(0xFF15803D),
          icon: Icons.check_circle,
        );
      case 'retake':
        final text = score != null ? '${score.toStringAsFixed(1)} • Học lại' : 'Cần học lại';
        return StatusBadge(
          label: '$text ▾',
          backgroundColor: const Color(0xFFFEE2E2),
          textColor: const Color(0xFFB91C1C),
          icon: Icons.error_outline_rounded,
        );
      case 'in_progress':
        return const StatusBadge(
          label: 'Đang học ▾',
          backgroundColor: Color(0xFFDBEAFE),
          textColor: Color(0xFF1D4ED8),
          icon: Icons.hourglass_top_rounded,
        );
      case 'not_started':
      default:
        return const StatusBadge(
          label: 'Chưa học ▾',
          backgroundColor: Color(0xFFF1F5F9),
          textColor: Color(0xFF64748B),
          icon: Icons.radio_button_unchecked,
        );
    }
  }

  factory StatusBadge.notStudied() {
    return const StatusBadge(
      label: 'Chưa học',
      backgroundColor: Color(0xFFF1F5F9),
      textColor: Color(0xFF64748B),
      icon: Icons.radio_button_unchecked,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1.5, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
