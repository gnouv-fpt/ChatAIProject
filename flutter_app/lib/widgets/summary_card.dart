import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Single metric displayed inside [SummaryCard].
class SummaryMetric {
  const SummaryMetric({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
}

/// Material 3 tonal summary card.
///
/// Replaces heavy, high-contrast gradient hero panels with an accessible,
/// content-first card following M3 surface guidelines.
/// Metrics row automatically wraps on small screens (360px) and large text scales (1.3x).
/// CTA button is completely optional.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.metrics = const [],
    this.child,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<SummaryMetric> metrics;
  final Widget? child;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      color: backgroundColor ?? colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Title + Subtitle & Optional Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  badge!,
                ],
              ],
            ),

            // Optional Metrics Row (responsive layout prevents overflow at 360px & text scale 1.3)
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildMetrics(context),
            ],

            // Optional Custom Child
            if (child != null) ...[
              const SizedBox(height: 12),
              child!,
            ],

            // Optional Action Button (renders ONLY when both label and callback are provided)
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: actionIcon != null ? Icon(actionIcon, size: 18) : const SizedBox.shrink(),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final isTight = textScaler.scale(14) > 15.5 || MediaQuery.sizeOf(context).width < 375;

    if (isTight && metrics.length > 2) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80),
                  child: _buildSingleMetric(context, metric),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0)
              Container(
                height: 28,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            Expanded(
              child: _buildSingleMetric(context, metrics[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleMetric(BuildContext context, SummaryMetric metric) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (metric.icon != null) ...[
              Icon(
                metric.icon,
                size: 14,
                color: metric.color ?? colorScheme.primary,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                metric.value,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: metric.color ?? colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          style: textTheme.bodySmall?.copyWith(
            fontSize: 11.5,
            color: colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
