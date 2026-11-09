import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Labeled AI Assistant button replacing the raw robot icon.
///
/// Combines a clear text label ("Hỏi AI") with an AI icon.
/// Automatically collapses to icon-only + tooltip when the top app bar is crowded
/// (on small screen widths < 375px or large text scales > 1.1x).
/// Includes a [visible] parameter to cleanly hide the button on screens
/// where AI assistance is redundant or not contextually appropriate (e.g. Chat, Settings).
class AskAiButton extends StatelessWidget {
  const AskAiButton({
    super.key,
    required this.onPressed,
    this.visible = true,
    this.compact,
    this.label = 'Hỏi AI',
    this.icon = Icons.smart_toy_rounded,
    this.tooltip = 'Hỏi trợ lý AI FLM',
  });

  final VoidCallback? onPressed;
  final bool visible;
  final bool? compact;
  final String label;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    // Quy tắc duy nhất: nhãn khi rộng >= 375dp và text scale <= 1.15, ngược lại icon-only.
    // Áp dụng cho MỌI màn qua cùng một component.
    final bool showTextLabel = compact != null
        ? !compact!
        : (width >= 375 && textScale <= 1.15);

    if (!showTextLabel) {
      return Semantics(
        button: true,
        label: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: IconButton.filledTonal(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            tooltip: tooltip,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              minimumSize: const Size(AppTheme.targetSize, AppTheme.targetSize),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(80, AppTheme.targetSize),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
