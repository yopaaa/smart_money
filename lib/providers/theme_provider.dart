import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedTheme = await DatabaseHelper.instance.getSetting('@theme');
      if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      } else if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Theme load error: $e');
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      try {
        await DatabaseHelper.instance.saveSetting('@theme', 'dark');
      } catch (e) {
        debugPrint('Save theme error: $e');
      }
    } else {
      _themeMode = ThemeMode.light;
      try {
        await DatabaseHelper.instance.saveSetting('@theme', 'light');
      } catch (e) {
        debugPrint('Save theme error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    try {
      await DatabaseHelper.instance.saveSetting('@theme', mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('Save theme error: $e');
    }
    notifyListeners();
  }
}
