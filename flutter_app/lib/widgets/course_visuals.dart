import 'package:flutter/material.dart';

import '../services/learning_progress.dart';
import '../theme/app_theme.dart';

/// Accent pair for one semester: [fg] meets 4.5:1 on white and on [bg].
class SemesterPalette {
  const SemesterPalette(this.fg, this.bg);
  final Color fg;
  final Color bg;

  static const _palettes = [
    SemesterPalette(Color(0xFF475569), Color(0xFFF1F5F9)), // HK0 slate
    SemesterPalette(Color(0xFF1565C0), Color(0xFFE3F2FD)), // blue
    SemesterPalette(Color(0xFF00796B), Color(0xFFE0F2F1)), // teal
    SemesterPalette(Color(0xFF6A1B9A), Color(0xFFF3E5F5)), // purple
    SemesterPalette(Color(0xFFB34700), Color(0xFFFFF3E0)), // orange
    SemesterPalette(Color(0xFFAD1457), Color(0xFFFCE4EC)), // pink
    SemesterPalette(Color(0xFF283593), Color(0xFFE8EAF6)), // indigo
    SemesterPalette(Color(0xFF2E7D32), Color(0xFFE8F5E9)), // green
    SemesterPalette(Color(0xFF00695C), Color(0xFFE0F7FA)), // cyan
    SemesterPalette(Color(0xFF8D6E00), Color(0xFFFFF8E1)), // amber
    SemesterPalette(Color(0xFFC62828), Color(0xFFFFEBEE)), // red
  ];

  static SemesterPalette of(int semester) =>
      _palettes[semester.clamp(0, 1 << 20) % _palettes.length];
}

/// Icon by subject family inferred from the course code prefix.
IconData courseIcon(String code) {
  final c = code.toUpperCase();
  bool any(List<String> p) => p.any(c.startsWith);
  if (any(['PRF', 'PRO', 'PRN', 'PRJ', 'PRM', 'CSD', 'LAB'])) {
    return Icons.code_rounded;
  }
  if (any(['MAE', 'MAD', 'MAS', 'MAI', 'MAT'])) return Icons.functions_rounded;
  if (any(['DBI', 'DBW'])) return Icons.storage_rounded;
  if (any(['CEA', 'OSG', 'NWC', 'IOT', 'CSI'])) return Icons.memory_rounded;
  if (any(['SWE', 'SWT', 'SWR', 'SWD', 'SWP', 'SWM'])) {
    return Icons.architecture_rounded;
  }
  if (any(['AIL', 'AIG', 'DAP', 'DWP', 'MLN1'])) return Icons.psychology_rounded;
  if (any(['ENW', 'ENG', 'TRS', 'EAW', 'JPD', 'KOR', 'CHN'])) {
    return Icons.translate_rounded;
  }
  if (any(['SSL', 'SSG', 'PMG', 'EXE', 'ITE'])) return Icons.groups_rounded;
  if (any(['OJT', 'SEP', 'GRP'])) return Icons.work_rounded;
  if (any(['MLN', 'HCM', 'VNR', 'PHE'])) return Icons.account_balance_rounded;
  if (any(['VOV', 'OTP', 'GDQP', 'PEN'])) return Icons.sports_martial_arts;
  if (any(['WED', 'WDU', 'FER', 'SWW'])) return Icons.web_rounded;
  return Icons.menu_book_rounded;
}

/// Visual status for a course readiness value.
class ReadinessStyle {
  const ReadinessStyle(this.icon, this.fg, this.bg);
  final IconData icon;
  final Color fg;
  final Color bg;

  static ReadinessStyle of(CourseReadiness readiness, {required bool known}) {
    if (!known &&
        readiness != CourseReadiness.completed &&
        readiness != CourseReadiness.inProgress) {
      return const ReadinessStyle(
        Icons.help_outline_rounded,
        AppTheme.slate600,
        AppTheme.slate100,
      );
    }
    return switch (readiness) {
      CourseReadiness.completed => const ReadinessStyle(
        Icons.check_circle_rounded,
        AppTheme.success,
        AppTheme.successSurface,
      ),
      CourseReadiness.inProgress => const ReadinessStyle(
        Icons.timelapse_rounded,
        AppTheme.primaryDark,
        AppTheme.primaryLight,
      ),
      CourseReadiness.ready => const ReadinessStyle(
        Icons.lock_open_rounded,
        Color(0xFF00695C),
        Color(0xFFE0F2F1),
      ),
      CourseReadiness.blocked => const ReadinessStyle(
        Icons.lock_rounded,
        AppTheme.danger,
        AppTheme.dangerSurface,
      ),
      CourseReadiness.unverified => const ReadinessStyle(
        Icons.report_gmailerrorred_rounded,
        AppTheme.warning,
        AppTheme.warningSurface,
      ),
    };
  }
}

