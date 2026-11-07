import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý chế độ giao diện (Sáng / Tối / Hệ thống) của ứng dụng.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({ThemeMode initialMode = ThemeMode.system})
      : _themeMode = initialMode;

  static const String _storageKey = 'flm_app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Đọc cài đặt đã lưu từ SharedPreferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      // Fallback an toàn nếu chưa khởi tạo hoặc môi trường không có storage
    }
  }

  /// Cập nhật chế độ giao diện và lưu trữ cục bộ.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system';
      await prefs.setString(_storageKey, value);
    } catch (_) {}
  }
}
