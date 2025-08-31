import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Theme management
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Initialize settings
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    } catch (e) {
      print('Error initializing settings service: $e');
      // Use default values if SharedPreferences fails
      _isDarkMode = false;
    }
  }

  // Toggle theme
  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', isDark);
    } catch (e) {
      print('Error saving theme setting: $e');
      // Continue without saving if SharedPreferences fails
    }
    
    // Notify listeners (you can implement a proper state management solution here)
    // For now, this will be handled by the main app
  }

  // Get theme data
  ThemeData getThemeData(bool isDark) {
    if (isDark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFF1F2937),
          surfaceVariant: const Color(0xFF111827),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFFFFFFFF),
          surfaceVariant: const Color(0xFFF9FAFB),
        ),
      );
    }
  }

  // Get notification settings
  Future<bool> getNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications') ?? true;
    } catch (e) {
      print('Error getting notification settings: $e');
      return true; // Default value
    }
  }

  // Set notification settings
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications', enabled);
    } catch (e) {
      print('Error setting notification settings: $e');
      // Continue without saving
    }
  }

  // Get unit preference
  Future<bool> getUseKcal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('useKcal') ?? true;
    } catch (e) {
      print('Error getting unit preference: $e');
      return true; // Default value
    }
  }

  // Set unit preference
  Future<void> setUseKcal(bool useKcal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useKcal', useKcal);
    } catch (e) {
      print('Error setting unit preference: $e');
      // Continue without saving
    }
  }

  // Get language preference
  Future<String> getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('language') ?? 'English';
    } catch (e) {
      print('Error getting language preference: $e');
      return 'English'; // Default value
    }
  }

  // Set language preference
  Future<void> setLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', language);
    } catch (e) {
      print('Error setting language preference: $e');
      // Continue without saving
    }
  }

  // Clear all settings
  Future<void> clearAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _isDarkMode = false;
    } catch (e) {
      print('Error clearing settings: $e');
      // Reset to default values
      _isDarkMode = false;
    }
  }
} 