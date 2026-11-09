// Read-only palette diagnostic for AppTheme.lightTheme, using the app's locked
// material_color_utilities package. Run from repo root with:
// dart --packages=flutter_app/.dart_tool/package_config.json design/mobile-material-palette.dart
import 'dart:convert';
import 'package:material_color_utilities/material_color_utilities.dart';

void main() {
  final scheme = SchemeTonalSpot(sourceColorHct: Hct.fromInt(0xFF1565C0), isDark: false, contrastLevel: 0);
  final colors = <String, DynamicColor>{
    'surfaceContainer': MaterialDynamicColors.surfaceContainer,
    'secondaryContainer': MaterialDynamicColors.secondaryContainer,
    'onSecondaryContainer': MaterialDynamicColors.onSecondaryContainer,
    'onSurface': MaterialDynamicColors.onSurface,
    'onSurfaceVariant': MaterialDynamicColors.onSurfaceVariant,
    'error': MaterialDynamicColors.error,
    'errorContainer': MaterialDynamicColors.errorContainer,
  };
  print(const JsonEncoder.withIndent('  ').convert(colors.map((k, v) => MapEntry(k, '#${v.getArgb(scheme).toRadixString(16).substring(2).toUpperCase()}'))));
}
