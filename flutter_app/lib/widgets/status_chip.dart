import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusType {
  success,
  warning,
  error,
  info,
  neutral,
}

/// Multimodal Material 3 status chip.
///
/// Ensures accessibility by combining an explicit icon and text label;
/// never conveys status through color alone (WCAG 1.4.1).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.onTap,
    this.compact = false,
  });

  /// Factory for a success status (e.g. "Đã đạt", "Hoàn thành").
  factory StatusChip.success({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool compact = false,
  }) =>
      StatusChip(
        key: key,
        label: label,
        type: StatusType.success,
        icon: icon ?? Icons.check_circle_outline_rounded,
        onTap: onTap,
        compact: compact,
      );

  /// Factory for a warning status (e.g. "Cần chú ý", "Chưa đạt").
  factory StatusChip.warning({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool compact = false,
  }) =>
      StatusChip(
        key: key,
        label: label,
        type: StatusType.warning,
        icon: icon ?? Icons.warning_amber_rounded,
        onTap: onTap,
        compact: compact,
      );

  /// Factory for an error status (e.g. "Rớt môn", "Thất bại").
  factory StatusChip.error({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool compact = false,
  }) =>
      StatusChip(
        key: key,
        label: label,
        type: StatusType.error,
        icon: icon ?? Icons.error_outline_rounded,
        onTap: onTap,
        compact: compact,
      );

  /// Factory for an info status (e.g. "Đang học", "Đề xuất").
  factory StatusChip.info({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool compact = false,
  }) =>
      StatusChip(
        key: key,
        label: label,
        type: StatusType.info,
        icon: icon ?? Icons.info_outline_rounded,
        onTap: onTap,
        compact: compact,
      );

  /// Factory for a neutral status (e.g. "Chưa học", "Chờ xếp lớp").
  factory StatusChip.neutral({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool compact = false,
  }) =>
      StatusChip(
        key: key,
        label: label,
        type: StatusType.neutral,
        icon: icon ?? Icons.radio_button_unchecked_rounded,
        onTap: onTap,
        compact: compact,
      );

  final String label;
  final StatusType type;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final customColors = context.customColors;

    final (Color bg, Color fg, IconData defaultIcon) = switch (type) {
      StatusType.success => (
        customColors.successContainer,
        customColors.onSuccessContainer,
        Icons.check_circle_outline_rounded,
      ),
      StatusType.warning => (
        customColors.warningContainer,
        customColors.onWarningContainer,
        Icons.warning_amber_rounded,
      ),
      StatusType.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      StatusType.info => (
        customColors.infoContainer,
        customColors.onInfoContainer,
        Icons.info_outline_rounded,
      ),
      StatusType.neutral => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        Icons.radio_button_unchecked_rounded,
      ),
    };

    final resolvedIcon = icon ?? defaultIcon;
    final horizontalPad = compact ? 8.0 : 10.0;
    final verticalPad = compact ? 3.0 : 5.0;
    final iconSize = compact ? 13.0 : 15.0;
    final fontSize = compact ? 11.5 : 12.5;

    Widget chipContent = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolvedIcon, size: iconSize, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      chipContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: chipContent,
      );
    }

    return Semantics(
      label: '$label: ${_typeDescription(type)}',
      button: onTap != null,
      child: chipContent,
    );
  }

  String _typeDescription(StatusType type) => switch (type) {
    StatusType.success => 'thành công / đã đạt',
    StatusType.warning => 'cảnh báo / cần chú ý',
    StatusType.error => 'lỗi / chưa đạt',
    StatusType.info => 'thông tin / đề xuất',
    StatusType.neutral => 'chưa có dữ liệu / mặc định',
  };
}

