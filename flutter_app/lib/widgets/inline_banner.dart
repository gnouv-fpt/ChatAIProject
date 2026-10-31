import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BannerSeverity {
  info,
  warning,
  error,
  success,
}

/// A compact, 1-line or 2-line Material 3 notice banner.
///
/// Designed for inline alerts, status hints, or network state warnings
/// without cluttering the main content.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.severity = BannerSeverity.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String message;
  final BannerSeverity severity;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final customColors = context.customColors;

    final (Color bg, Color fg, IconData defaultIcon) = switch (severity) {
      BannerSeverity.info => (
        customColors.infoContainer.withValues(alpha: 0.6),
        customColors.onInfoContainer,
        Icons.info_outline_rounded,
      ),
      BannerSeverity.warning => (
        customColors.warningContainer.withValues(alpha: 0.7),
        customColors.onWarningContainer,
        Icons.warning_amber_rounded,
      ),
      BannerSeverity.error => (
        colorScheme.errorContainer.withValues(alpha: 0.7),
        colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      BannerSeverity.success => (
        customColors.successContainer.withValues(alpha: 0.6),
        customColors.onSuccessContainer,
        Icons.check_circle_outline_rounded,
      ),
    };

    final resolvedIcon = icon ?? defaultIcon;

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Thông báo: $message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: fg.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(resolvedIcon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: fg,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(48, 36),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: fg,
                tooltip: 'Đóng thông báo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppTheme.targetSize,
                  minHeight: AppTheme.targetSize,
                ),
                onPressed: onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

