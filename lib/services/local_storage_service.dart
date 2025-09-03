import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import '../models/user_goals.dart';
import '../models/user_preferences.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';

/// Local storage service for development and offline support
/// Stores user data locally when Firebase is not available
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _userEmailKey = 'user_email';
  static const String _userPasswordKey = 'user_password';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _foodEntriesKey = 'food_entries';
  static const String _userGoalsKey = 'user_goals';
  static const String _userPreferencesKey = 'user_preferences';
  static const String _dailySummaryKey = 'daily_summary';
  static const String _macroBreakdownKey = 'macro_breakdown';
  static const String _achievementsKey = 'achievements';

  /// Save user login credentials locally
  Future<void> saveUserCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userPasswordKey, password);
    await prefs.setBool(_isLoggedInKey, true);
    print('User credentials saved locally: $email');
  }

  /// Get saved user credentials
  Future<Map<String, String>?> getUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_userEmailKey);
    final password = prefs.getString(_userPasswordKey);
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// Check if user is logged in locally
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Logout user (clear local data)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPasswordKey);
    await prefs.setBool(_isLoggedInKey, false);
    print('User logged out locally');
  }

  /// Save food entries locally
  Future<void> saveFoodEntries(List<FoodEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_foodEntriesKey, jsonEncode(entriesJson));
    print('Food entries saved locally: ${entries.length} entries');
  }

  /// Get food entries from local storage
  Future<List<FoodEntry>> getFoodEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_foodEntriesKey);
    
    if (entriesJson != null) {
      try {
        final List<dynamic> entriesList = jsonDecode(entriesJson);
        return entriesList.map((e) => FoodEntry.fromJson(e)).toList();
      } catch (e) {
        print('Error parsing food entries: $e');
      }
    }
    return [];
  }

  /// Save user goals locally
  Future<void> saveUserGoals(UserGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userGoalsKey, jsonEncode(goals.toMap()));
    print('User goals saved locally');
  }

  /// Get user goals from local storage
  Future<UserGoals?> getUserGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsJson = prefs.getString(_userGoalsKey);
    
    if (goalsJson != null) {
      try {
        final Map<String, dynamic> goalsMap = jsonDecode(goalsJson);
        return UserGoals.fromMap(goalsMap);
      } catch (e) {
        print('Error parsing user goals: $e');
      }
    }
    return null;
  }

  /// Save user preferences locally
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPreferencesKey, jsonEncode(preferences.toMap()));
    print('User preferences saved locally');
  }

  /// Get user preferences from local storage
  Future<UserPreferences> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final preferencesJson = prefs.getString(_userPreferencesKey);
    
    if (preferencesJson != null) {
      try {
        final Map<String, dynamic> preferencesMap = jsonDecode(preferencesJson);
        return UserPreferences.fromMap(preferencesMap);
      } catch (e) {
        print('Error parsing user preferences: $e');
      }
    }
    return const UserPreferences();
  }

  /// Save daily summary locally
  Future<void> saveDailySummary(DailySummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailySummaryKey, jsonEncode(summary.toJson()));
    print('Daily summary saved locally');
  }

  /// Get daily summary from local storage
  Future<DailySummary?> getDailySummary() async {
    final prefs = await SharedPreferences.getInstance();
    final summaryJson = prefs.getString(_dailySummaryKey);
    
    if (summaryJson != null) {
      try {
        final Map<String, dynamic> summaryMap = jsonDecode(summaryJson);
        return DailySummary.fromJson(summaryMap);
      } catch (e) {
        print('Error parsing daily summary: $e');
      }
    }
    return null;
  }

  /// Save macro breakdown locally
  Future<void> saveMacroBreakdown(MacroBreakdown breakdown) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_macroBreakdownKey, jsonEncode(breakdown.toJson()));
    print('Macro breakdown saved locally');
  }

  /// Get macro breakdown from local storage
  Future<MacroBreakdown> getMacroBreakdown() async {
    final prefs = await SharedPreferences.getInstance();
    final breakdownJson = prefs.getString(_macroBreakdownKey);
    
    if (breakdownJson != null) {
      try {
        final Map<String, dynamic> breakdownMap = jsonDecode(breakdownJson);
        return MacroBreakdown.fromJson(breakdownMap);
      } catch (e) {
        print('Error parsing macro breakdown: $e');
      }
    }
    return MacroBreakdown(
      carbs: 0.0,
      protein: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
    );
  }

  /// Save achievements locally
  Future<void> saveAchievements(List<UserAchievement> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = achievements.map((a) => a.toJson()).toList();
    await prefs.setString(_achievementsKey, jsonEncode(achievementsJson));
    print('Achievements saved locally: ${achievements.length} achievements');
  }

  /// Get achievements from local storage
  Future<List<UserAchievement>> getAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = prefs.getString(_achievementsKey);
    
    if (achievementsJson != null) {
      try {
        final List<dynamic> achievementsList = jsonDecode(achievementsJson);
        return achievementsList.map((a) => UserAchievement.fromJson(a)).toList();
      } catch (e) {
        print('Error parsing achievements: $e');
      }
    }
    return [];
  }

  /// Clear all local data
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_foodEntriesKey);
    await prefs.remove(_userGoalsKey);
    await prefs.remove(_userPreferencesKey);
    await prefs.remove(_dailySummaryKey);
    await prefs.remove(_macroBreakdownKey);
    await prefs.remove(_achievementsKey);
    print('All local data cleared');
  }
}
