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
        label: 'Thi thực hành PE',
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
        label: 'Tính GPA',
        backgroundColor: AppTheme.gpaBadgeBg,
        textColor: AppTheme.gpaBadgeText,
        icon: Icons.check_circle_outline,
      );
    }
    return const StatusBadge(
      label: 'Không tính GPA',
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
