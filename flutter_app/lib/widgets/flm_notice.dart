import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum NoticeTone { info, warning, error }

/// One semantic message pattern for import, validation and data recovery.
class FlmNotice extends StatelessWidget {
  const FlmNotice({
    super.key,
    required this.message,
    this.tone = NoticeTone.info,
  });
  final String message;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (tone) {
      NoticeTone.info => (
        AppTheme.primaryLight,
        AppTheme.primaryDark,
        Icons.info_outline,
      ),
      NoticeTone.warning => (
        AppTheme.warningSurface,
        AppTheme.warning,
        Icons.warning_amber_rounded,
      ),
      NoticeTone.error => (
        AppTheme.dangerSurface,
        AppTheme.danger,
        Icons.error_outline,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
