import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { dark, light, system }

extension AppThemeModeExtension on AppThemeMode {
  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'app_theme';
  AppThemeMode _themeMode = AppThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  AppThemeMode get currentTheme => _themeMode;
  ThemeMode get themeMode => _themeMode.toThemeMode();

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_key);
    if (themeStr != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.toString() == themeStr,
        orElse: () => AppThemeMode.system,
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
}

final themeProvider = ThemeProvider();
