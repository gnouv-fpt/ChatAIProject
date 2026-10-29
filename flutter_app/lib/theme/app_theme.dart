import 'package:flutter/material.dart';

/// Design System & Theme Tokens chuẩn UI Mục 8.4 cho toàn app FLM.
/// Các khối B, C, D, E dùng chung theme này để đồng nhất trải nghiệm.
class AppTheme {
  AppTheme._();

  // Primary palette (FPT Blue & Tech Slate)
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFFE3F2FD);
  // White text on this accent is 5.5:1 (the former #F57C00 was 2.7:1).
  static const Color accentOrange = Color(0xFFB34700);
  static const Color accentAmber = Color(0xFFFFB300);

  // Surface & Neutral tones (Obsidian-inspired)
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Status & Badge colors
  static const Color peBadgeBg = Color(0xFFFFF3E0);
  static const Color peBadgeText = Color(0xFFE65100);
  static const Color gpaBadgeBg = Color(0xFFE8F5E9);
  static const Color gpaBadgeText = Color(0xFF2E7D32);
  static const Color nonGpaBadgeBg = Color(0xFFECEFF1);
  static const Color nonGpaBadgeText = Color(0xFF546E7A);

  // Radius tokens
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 18.0;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double targetSize = 48;
  static const Color success = Color(0xFF166534);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFF92400E);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSurface = Color(0xFFFEF2F2);

  static ThemeData darkTheme() {
    final light = lightTheme();
    return light.copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        surface: slate800,
      ),
      scaffoldBackgroundColor: slate900,
      iconTheme: const IconThemeData(color: slate100),
      iconButtonTheme: IconButtonThemeData(
        style: light.iconButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(slate100),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: light.outlinedButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(Color(0xFF90CAF9)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFF90CAF9)),
          ),
        ),
      ),
      textTheme: light.textTheme.apply(
        bodyColor: slate100,
        displayColor: slate50,
      ),
      appBarTheme: light.appBarTheme.copyWith(
        backgroundColor: slate800,
        foregroundColor: slate50,
        titleTextStyle: light.appBarTheme.titleTextStyle?.copyWith(
          color: slate50,
        ),
      ),
      cardTheme: light.cardTheme.copyWith(color: slate800),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(
        fillColor: slate800,
        hintStyle: light.inputDecorationTheme.hintStyle?.copyWith(
          color: slate200,
        ),
      ),
      navigationBarTheme: light.navigationBarTheme.copyWith(
        backgroundColor: slate800,
        indicatorColor: primaryDark,
        labelTextStyle: WidgetStatePropertyAll(
          light.textTheme.labelMedium!.copyWith(color: slate100),
        ),
      ),
      chipTheme: light.chipTheme.copyWith(
        backgroundColor: slate700,
        selectedColor: primaryDark,
        labelStyle: light.chipTheme.labelStyle?.copyWith(color: slate100),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentOrange,
        surface: slate50,
      ),
      scaffoldBackgroundColor: slate50,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: slate900,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: slate900,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: slate900,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: slate800),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: slate700),
        bodySmall: TextStyle(fontSize: 14, height: 1.4, color: slate600),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(targetSize, targetSize),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(targetSize, targetSize),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primaryLight,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: slate900,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: slate900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: slate200, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: slate100,
        selectedColor: primaryLight,
        disabledColor: slate200,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: slate800,
        ),
        checkmarkColor: primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        ),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryLight;
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryDark;
            }
            return slate700;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(fontSize: 14, color: slate600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
