import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Labeled AI Assistant button replacing the raw robot icon.
///
/// Combines a clear text label ("Hỏi AI") with an AI icon.
/// Includes a [visible] parameter to cleanly hide the button on screens
/// where AI assistance is not contextually appropriate (e.g. Settings).
class AskAiButton extends StatelessWidget {
  const AskAiButton({
    super.key,
    required this.onPressed,
    this.visible = true,
    this.label = 'Hỏi AI',
    this.icon = Icons.smart_toy_outlined,
    this.tooltip = 'Hỏi trợ lý AI FLM',
  });

  final VoidCallback? onPressed;
  final bool visible;
  final String label;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

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

