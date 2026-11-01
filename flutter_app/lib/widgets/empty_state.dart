import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Clean Material 3 empty state widget.
///
/// Features a prominent icon in a soft tinted container, a clear title,
/// a concise 1-line description, and an actionable CTA button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.padding = const EdgeInsets.all(24),
    this.iconSize = 32,
    this.containerSize = 64,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double containerSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tinted Icon Container
            Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),

            // 1-line Description
            Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // Action Buttons
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: actionIcon != null ? Icon(actionIcon, size: 18) : const SizedBox.shrink(),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(140, AppTheme.targetSize),
                ),
              ),
            ],

            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

