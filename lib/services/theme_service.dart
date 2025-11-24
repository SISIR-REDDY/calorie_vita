import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app theme (light/dark mode)
/// Persists user's theme preference across app sessions
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themePreferenceKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  /// Get current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Check if dark mode is enabled
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize theme service and load saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePreferenceKey);
      
      if (savedTheme != null) {
        _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing theme service: $e');
      _isInitialized = true;
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _saveThemePreference();
    notifyListeners();
  }

  /// Set theme mode explicitly
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _saveThemePreference();
    notifyListeners();
  }

  /// Set dark mode (convenience method)
  Future<void> setDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// Save theme preference to local storage
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themePreferenceKey,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  /// Reset to light mode
  Future<void> reset() async {
    _themeMode = ThemeMode.light;
    await _saveThemePreference();
    notifyListeners();
  }
}

