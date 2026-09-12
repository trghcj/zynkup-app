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

  bool _isTransitioning = false;

  /// Optional pre-transition hook to snapshot the screen before theme changes.
  Future<void> Function()? onBeforeThemeChange;

  AppThemeMode get currentTheme => _themeMode;
  ThemeMode get themeMode => _themeMode.toThemeMode();
  bool get isDark => _themeMode == AppThemeMode.dark;
  bool get isTransitioning => _isTransitioning;

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
    if (mode == _themeMode || _isTransitioning) return;
    _isTransitioning = true;
    try {
      if (onBeforeThemeChange != null) {
        await onBeforeThemeChange!();
      }
    } catch (_) {}

    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.toString());
    _isTransitioning = false;
  }

  Future<void> toggle() async {
    await setTheme(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }
}

final themeProvider = ThemeProvider();
