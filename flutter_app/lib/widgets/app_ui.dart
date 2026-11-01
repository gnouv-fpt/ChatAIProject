import 'package:flutter/material.dart';

export 'section_header.dart';

/// Material 3 "medium" style top app bar: bold headline + supporting subtitle,
/// matching the Figma S01–S07 headers.
class FlmAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FlmAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 56 : 64);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppBar(
      toolbarHeight: preferredSize.height,
      leading: leading,
      titleSpacing: leading == null ? 20 : 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.headlineSmall?.copyWith(fontSize: 22, height: 1.2),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}

/// Rounded tinted square holding an icon (Figma course/list leading tile).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: color, size: size * 0.52),
  );
}

/// Small colored label with icon; status never relies on color alone.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}


