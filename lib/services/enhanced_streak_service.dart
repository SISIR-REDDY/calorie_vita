import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/simple_streak_system.dart';
import '../models/daily_summary.dart';
import '../models/user_goals.dart';
import 'error_handler.dart';
import 'daily_summary_service.dart';

/// Enhanced streak service that calculates streaks based on actual daily goal achievements
class EnhancedStreakService {
  static final EnhancedStreakService _instance = EnhancedStreakService._internal();
  factory EnhancedStreakService() => _instance;
  EnhancedStreakService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ErrorHandler _errorHandler = ErrorHandler();
  final DailySummaryService _dailySummaryService = DailySummaryService();

  // Stream controllers for real-time updates
  final StreamController<UserStreakSummary> _streakController =
      StreamController<UserStreakSummary>.broadcast();

  // Getters
  Stream<UserStreakSummary> get streakStream => _streakController.stream;

  // Current streak data
  UserStreakSummary _currentStreaks = UserStreakSummary(
    goalStreaks: {},
    totalActiveStreaks: 0,
    longestOverallStreak: 0,
    lastActivityDate: DateTime.now(),
    totalDaysActive: 0,
  );

  /// Initialize enhanced streak service
  Future<void> initialize() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _calculateAndUpdateStreaks();
    } catch (e) {
      _errorHandler.handleDataError('enhanced_streak_init', e);
    }
  }

  /// Calculate and update streaks based on actual daily summary data
  Future<void> _calculateAndUpdateStreaks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      debugPrint('=== ENHANCED STREAK CALCULATION ===');
      
      // Get user goals for current targets
      final userGoals = await _getUserGoals(user.uid);
      debugPrint('User goals: ${userGoals.toMap()}');
      
      // Get daily summaries for the last 30 days
      final dailySummaries = await _getDailySummaries(user.uid, days: 30);
      debugPrint('Found ${dailySummaries.length} daily summaries');
      
      // Calculate streaks for each goal type
      final goalStreaks = <DailyGoalType, GoalStreak>{};
      
      for (final goalType in DailyGoalType.values) {
        goalStreaks[goalType] = _calculateStreakForGoal(
          goalType, 
          dailySummaries, 
          userGoals
        );
        debugPrint('${goalType.displayName}: Current=${goalStreaks[goalType]!.currentStreak}, Longest=${goalStreaks[goalType]!.longestStreak}, AchievedToday=${goalStreaks[goalType]!.achievedToday}');
      }

      // Calculate overall statistics
      final totalActiveStreaks = goalStreaks.values
          .where((streak) => streak.achievedToday)
          .length;
      
      final longestOverallStreak = goalStreaks.values
          .map((streak) => streak.longestStreak)
          .reduce((a, b) => a > b ? a : b);

      final totalDaysActive = goalStreaks.values
          .map((streak) => streak.totalDaysAchieved)
          .reduce((a, b) => a > b ? a : b);

      // Update current streaks
      _currentStreaks = UserStreakSummary(
        goalStreaks: goalStreaks,
        totalActiveStreaks: totalActiveStreaks,
        longestOverallStreak: longestOverallStreak,
        lastActivityDate: DateTime.now(),
        totalDaysActive: totalDaysActive,
      );

      // Save to Firestore and notify listeners
      await _saveUserStreaks();
      _streakController.add(_currentStreaks);
    } catch (e) {
      _errorHandler.handleDataError('calculate_streaks', e);
    }
  }

  /// Calculate streak for a specific goal type
  GoalStreak _calculateStreakForGoal(
    DailyGoalType goalType,
    List<DailySummary> dailySummaries,
    UserGoals userGoals,
  ) {
    // Sort summaries by date (newest first)
    final sortedSummaries = List<DailySummary>.from(dailySummaries)
      ..sort((a, b) => b.date.compareTo(a.date));

    int currentStreak = 0;
    int longestStreak = 0;
    int totalDaysAchieved = 0;
    DateTime lastAchievedDate = DateTime.now().subtract(const Duration(days: 1));
    bool achievedToday = false;

    // Calculate current streak
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    for (int i = 0; i < sortedSummaries.length; i++) {
      final summary = sortedSummaries[i];
      final summaryDate = DateTime(summary.date.year, summary.date.month, summary.date.day);
      final daysDiff = todayDate.difference(summaryDate).inDays;

      // Only count consecutive days
      if (daysDiff != i) break;

      final goalAchieved = _isGoalAchieved(goalType, summary, userGoals);
      
      if (goalAchieved) {
        if (i == 0) {
          achievedToday = true;
          lastAchievedDate = summaryDate;
        }
        currentStreak++;
        totalDaysAchieved++;
      } else {
        break;
      }
    }

    // Calculate longest streak
    int tempStreak = 0;
    for (final summary in sortedSummaries) {
      final goalAchieved = _isGoalAchieved(goalType, summary, userGoals);
      
      if (goalAchieved) {
        tempStreak++;
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      } else {
        tempStreak = 0;
      }
    }

    return GoalStreak(
      goalType: goalType,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastAchievedDate: lastAchievedDate,
      achievedToday: achievedToday,
      totalDaysAchieved: totalDaysAchieved,
    );
  }

  /// Check if a specific goal is achieved for a given daily summary
  bool _isGoalAchieved(DailyGoalType goalType, DailySummary summary, UserGoals userGoals) {
    bool achieved = false;
    
    switch (goalType) {
      case DailyGoalType.mealLogging:
        // Consider meal logging achieved if calories consumed > 0
        achieved = summary.caloriesConsumed > 0;
        break;
      
      case DailyGoalType.exercise:
        // Consider exercise achieved if calories burned > 0
        achieved = summary.caloriesBurned > 0;
        break;
      
      case DailyGoalType.steps:
        // Check if steps goal is met
        final stepsGoal = userGoals.stepsPerDayGoal ?? 10000;
        achieved = summary.steps >= stepsGoal;
        break;
      
      case DailyGoalType.calorieGoal:
        // Check if calorie goal is met
        final calorieGoal = userGoals.calorieGoal ?? 2000;
        achieved = summary.caloriesConsumed >= calorieGoal;
        break;
    }
    
    debugPrint('Goal ${goalType.displayName}: ${achieved ? "ACHIEVED" : "NOT ACHIEVED"} (Calories: ${summary.caloriesConsumed}, Steps: ${summary.steps}, Burned: ${summary.caloriesBurned})');
    return achieved;
  }

  /// Get user goals from Firestore
  Future<UserGoals> _getUserGoals(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('goals')
          .doc('current')
          .get();

      if (doc.exists) {
        return UserGoals.fromMap(doc.data()!);
      } else {
        // Return default goals
        return UserGoals(
          calorieGoal: 2000,
          stepsPerDayGoal: 10000,
          waterGlassesGoal: 8,
          weightGoal: 70.0,
        );
      }
    } catch (e) {
      _errorHandler.handleDataError('get_user_goals', e);
      // Return default goals on error
      return UserGoals(
        calorieGoal: 2000,
        stepsPerDayGoal: 10000,
        waterGlassesGoal: 8,
        weightGoal: 70.0,
      );
    }
  }

  /// Get daily summaries from Firestore
  Future<List<DailySummary>> _getDailySummaries(String userId, {int days = 30}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => DailySummary.fromMap(doc.data()))
          .toList();
    } catch (e) {
      _errorHandler.handleDataError('get_daily_summaries', e);
      return [];
    }
  }

  /// Save user streaks to Firestore
  Future<void> _saveUserStreaks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('streaks')
          .doc('summary')
          .set(_currentStreaks.toMap());
    } catch (e) {
      _errorHandler.handleDataError('save_streaks', e);
    }
  }

  /// Refresh streaks (call this when daily summary is updated)
  Future<void> refreshStreaks() async {
    await _calculateAndUpdateStreaks();
  }

  /// Get current streak summary
  UserStreakSummary get currentStreaks => _currentStreaks;

  /// Get streak for specific goal type
  GoalStreak? getStreakForGoal(DailyGoalType goalType) {
    return _currentStreaks.goalStreaks[goalType];
  }

  /// Check if goal was achieved today
  bool isGoalAchievedToday(DailyGoalType goalType) {
    final streak = _currentStreaks.goalStreaks[goalType];
    return streak?.achievedToday ?? false;
  }

  /// Get streak statistics
  Map<String, dynamic> getStreakStats() {
    return {
      'totalActiveStreaks': _currentStreaks.totalActiveStreaks,
      'longestOverallStreak': _currentStreaks.longestOverallStreak,
      'totalDaysActive': _currentStreaks.totalDaysActive,
      'activeStreaks': _currentStreaks.activeStreaks.length,
      'streaksNeedingAttention': _currentStreaks.streaksNeedingAttention.length,
    };
  }

  /// Reset all streaks (for testing or user request)
  Future<void> resetAllStreaks() async {
    try {
      _currentStreaks = UserStreakSummary(
        goalStreaks: {},
        totalActiveStreaks: 0,
        longestOverallStreak: 0,
        lastActivityDate: DateTime.now(),
        totalDaysActive: 0,
      );
      await _saveUserStreaks();
      _streakController.add(_currentStreaks);
    } catch (e) {
      _errorHandler.handleDataError('reset_streaks', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _streakController.close();
  }
}
