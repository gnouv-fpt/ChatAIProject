import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const BreadcrumbItem({
    required this.label,
    this.onTap,
    this.icon,
  });
}

class BreadcrumbNav extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const BreadcrumbNav({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.slate200, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 18, color: AppTheme.slate600.withOpacity(0.6)),
              ),
            _buildItem(items[i], isLast: i == items.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BreadcrumbItem item, {required bool isLast}) {
    final hasAction = item.onTap != null && !isLast;

    return MouseRegion(
      cursor: hasAction ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: hasAction ? item.onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 16,
                  color: isLast ? AppTheme.slate900 : AppTheme.primaryBlue,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                  color: isLast ? AppTheme.slate900 : AppTheme.primaryBlue,
                  decoration: hasAction ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
