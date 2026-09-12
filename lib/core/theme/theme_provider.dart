import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { dark, light }

extension AppThemeModeExtension on AppThemeMode {
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'app_theme';

  // Default to dark (the approved visual identity)
  AppThemeMode _themeMode = AppThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  AppThemeMode get currentTheme => _themeMode;
  ThemeMode get themeMode => _themeMode.toThemeMode();
  bool get isDark => _themeMode == AppThemeMode.dark;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_key);
    if (themeStr != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.toString() == themeStr,
        orElse: () => AppThemeMode.dark,
      );
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.toString());
  }

  Future<void> toggle() async {
    await setTheme(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }
}

final themeProvider = ThemeProvider();
