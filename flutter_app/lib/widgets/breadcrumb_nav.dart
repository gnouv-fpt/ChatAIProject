import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const BreadcrumbItem({required this.label, this.onTap, this.icon});
}

class BreadcrumbNav extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const BreadcrumbNav({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.slate200, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.slate600.withValues(alpha: 0.65),
                  ),
                ),
              _buildItem(items[i], isLast: i == items.length - 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BreadcrumbItem item, {required bool isLast}) {
    final hasAction = item.onTap != null && !isLast;

    return MouseRegion(
      cursor: hasAction ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: hasAction ? item.onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Container(
            padding: isLast
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                : EdgeInsets.zero,
            decoration: isLast
                ? BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: 16,
                    color: isLast ? AppTheme.primaryDark : AppTheme.slate600,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isLast ? FontWeight.w700 : FontWeight.w600,
                    color: isLast ? AppTheme.primaryDark : AppTheme.slate600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
