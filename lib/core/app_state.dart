import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central app state that holds language and theme values previously passed
/// down through many widget layers by hand. Screens read from this object
/// instead of having the values injected via constructor parameters.
///
/// Extends ChangeNotifier so the app root can rebuild when values change
/// (notably when saved preferences arrive right after the first frame).
class AppState extends ChangeNotifier {
  /// Whether Marathi language is currently selected.
  bool _isMarathi = false;

  /// Current theme mode (light or dark).
  ThemeMode _themeMode = ThemeMode.light;

  /// Whether time is shown in 24-hour format (true) or 12-hour with AM/PM (false).
  bool _is24Hour = true;

  /// Whether Marathi language is currently selected.
  bool get isMarathi => _isMarathi;

  /// Current theme mode (light or dark).
  ThemeMode get themeMode => _themeMode;

  /// Whether time is shown in 24-hour format.
  bool get is24Hour => _is24Hour;

  static const String _keyMarathi = 'is_marathi';
  static const String _keyDark = 'is_dark_theme';
  static const String _key24Hour = 'is_24_hour';

  /// Set Marathi language and notify listeners.
  void setMarathi(bool marathi) {
    if (_isMarathi == marathi) return;
    _isMarathi = marathi;
    notifyListeners();
  }

  /// Set theme mode and notify listeners.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Set time format (24-hour or 12-hour) and notify listeners.
  void setTimeFormat24Hour(bool is24) {
    if (_is24Hour == is24) return;
    _is24Hour = is24;
    notifyListeners();
  }

  /// Loads all saved preferences from SharedPreferences.
  /// Call this after the first frame so startup isn't blocked.
  Future<void> loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMarathi = prefs.getBool(_keyMarathi) ?? false;
      final isDark = prefs.getBool(_keyDark) ?? false;
      final is24Hour = prefs.getBool(_key24Hour) ?? true;
      _isMarathi = isMarathi;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _is24Hour = is24Hour;
      notifyListeners();
    } catch (_) {
      // Keep defaults if preferences unavailable.
    }
  }

  /// Persists the current language choice.
  Future<void> saveMarathi(bool marathi) async {
    _isMarathi = marathi;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMarathi, marathi);
  }

  /// Persists the current theme mode.
  Future<void> saveThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDark, mode == ThemeMode.dark);
  }

  /// Persists the current time format choice.
  Future<void> saveTimeFormat24Hour(bool is24) async {
    _is24Hour = is24;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key24Hour, is24);
  }
}
