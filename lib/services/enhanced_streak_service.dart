import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/simple_streak_system.dart';
import '../models/daily_summary.dart';
import '../models/user_goals.dart';
import 'error_handler.dart';

/// Enhanced streak service that calculates streaks based on actual daily goal achievements
class EnhancedStreakService {
  static final EnhancedStreakService _instance = EnhancedStreakService._internal();
  factory EnhancedStreakService() => _instance;
  EnhancedStreakService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ErrorHandler _errorHandler = ErrorHandler();

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
  
  // Prevent duplicate operations
  bool _isCalculatingStreaks = false;
  DateTime? _lastCalculationTime;
  Timer? _refreshDebounceTimer;
  bool _hasLoggedDuplicateCall = false; // Track if duplicate call has been logged

  /// Initialize enhanced streak service with timeout to prevent blocking
  Future<void> initialize() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No authenticated user, using default streak data');
        _currentStreaks = _getDefaultStreakData();
        return;
      }

      // Debug logging removed for performance

      // Add timeout to prevent blocking the UI
      await _calculateAndUpdateStreaks().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Streak calculation timed out, using fallback data');
          _currentStreaks = _getDefaultStreakData();
        },
      );

      // Debug logging removed for performance
    } catch (e) {
      debugPrint('❌ Error initializing enhanced streak service: $e');
      _errorHandler.handleDataError('enhanced_streak_init', e);
      // Provide fallback data
      _currentStreaks = _getDefaultStreakData();
    }
  }

  /// Calculate and update streaks based on actual daily summary data
  Future<void> _calculateAndUpdateStreaks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Debug logging removed for performance - only log on errors
      
      // Get user goals for current targets
      final userGoals = await _getUserGoals(user.uid);
      
      // Get daily summaries for the last 30 days
      final dailySummaries = await _getDailySummaries(user.uid, days: 30);
      // Debug logging removed - only log on errors or significant changes
      
      // Calculate streaks for each goal type (only main goals)
      final goalStreaks = <DailyGoalType, GoalStreak>{};
      
      // Only process main daily goals, exclude sleep and weight tracking
      final mainGoalTypes = [
        DailyGoalType.calorieGoal,
        DailyGoalType.steps, // Add steps tracking
        DailyGoalType.exercise,
        DailyGoalType.waterIntake,
      ];
      
      for (final goalType in mainGoalTypes) {
        goalStreaks[goalType] = _calculateStreakForGoal(
          goalType, 
          dailySummaries, 
          userGoals
        );
        // Debug logging removed for performance - only log on errors
      }

      // Calculate overall statistics
      final totalActiveStreaks = goalStreaks.values
          .where((streak) => streak.achievedToday)
          .length;
      
      final longestOverallStreak = goalStreaks.values
          .map((streak) => streak.longestStreak)
          .fold(0, (a, b) => a > b ? a : b);

      final totalDaysActive = goalStreaks.values
          .map((streak) => streak.totalDaysAchieved)
          .fold(0, (a, b) => a > b ? a : b);

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
    DateTime streakStartDate = DateTime.now().subtract(const Duration(days: 1));
    bool achievedToday = false;

    // Calculate current streak (consecutive days from today backwards)
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Check if achieved today first
    if (sortedSummaries.isNotEmpty) {
      final todaySummary = sortedSummaries.first;
      final todaySummaryDate = DateTime(todaySummary.date.year, todaySummary.date.month, todaySummary.date.day);
      
      if (todaySummaryDate.isAtSameMomentAs(todayDate)) {
        achievedToday = _isGoalAchieved(goalType, todaySummary, userGoals);
        if (achievedToday) {
          currentStreak = 1;
          lastAchievedDate = todayDate;
          streakStartDate = todayDate;
        }
      }
    }

    // Continue counting consecutive days backwards from today
    if (achievedToday && sortedSummaries.length > 1) {
      for (int i = 1; i < sortedSummaries.length; i++) {
        final summary = sortedSummaries[i];
        final summaryDate = DateTime(summary.date.year, summary.date.month, summary.date.day);
        final previousSummary = sortedSummaries[i - 1];
        final previousDate = DateTime(previousSummary.date.year, previousSummary.date.month, previousSummary.date.day);
        
        // Check if this is the next consecutive day
        final daysDiff = previousDate.difference(summaryDate).inDays;
        if (daysDiff != 1) break; // Not consecutive, stop counting
        
        final goalAchieved = _isGoalAchieved(goalType, summary, userGoals);
        
        if (goalAchieved) {
          currentStreak++;
          streakStartDate = summaryDate;
        } else {
          break; // Streak broken, stop counting
        }
      }
    }

    // Calculate longest streak and total days achieved
    int tempStreak = 0;
    
    for (final summary in sortedSummaries) {
      final goalAchieved = _isGoalAchieved(goalType, summary, userGoals);
      
      if (goalAchieved) {
        tempStreak++;
        totalDaysAchieved++;
        
        // Update longest streak if this is better
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    return GoalStreak(
      goalType: goalType,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastAchievedDate: achievedToday ? todayDate : lastAchievedDate,
      achievedToday: achievedToday,
      streakStartDate: streakStartDate,
      totalDaysAchieved: totalDaysAchieved,
    );
  }

  /// Check if a specific goal is achieved for a given daily summary
  bool _isGoalAchieved(DailyGoalType goalType, DailySummary summary, UserGoals userGoals) {
    bool achieved = false;
    
    switch (goalType) {
      case DailyGoalType.calorieGoal:
        // Check if calorie goal is met
        final calorieGoal = userGoals.calorieGoal ?? 2000;
        achieved = summary.caloriesConsumed >= calorieGoal;
        break;
      
      case DailyGoalType.steps:
        // Check if steps goal is met
        final stepsGoal = userGoals.stepsPerDayGoal ?? 10000;
        achieved = summary.steps >= stepsGoal;
        break;
      
      case DailyGoalType.exercise:
        // Consider exercise achieved if calories burned > 0 or steps > 5000
        achieved = summary.caloriesBurned > 0 || summary.steps > 5000;
        break;
      
      case DailyGoalType.waterIntake:
        // Check if water intake goal is met
        final waterGoal = userGoals.waterGlassesGoal ?? 8;
        achieved = summary.waterGlasses >= waterGoal;
        break;
      
      case DailyGoalType.sleep:
        // Check if sleep goal is met (simplified - could be enhanced with actual sleep data)
        // For now, consider it achieved if user logged any activity
        achieved = summary.caloriesConsumed > 0;
        break;
      
      case DailyGoalType.weightTracking:
        // Check if weight tracking goal is met (simplified - could be enhanced with actual weight data)
        // For now, consider it achieved if user logged any activity
        achieved = summary.caloriesConsumed > 0;
        break;
    }
    
    // Debug logging removed - this method is called in loops multiple times
    // Logging is done at the streak calculation level instead
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
        return const UserGoals(
          calorieGoal: 2000,
          stepsPerDayGoal: 10000,
          waterGlassesGoal: 8,
          weightGoal: 70.0,
        );
      }
    } catch (e) {
      _errorHandler.handleDataError('get_user_goals', e);
      // Return default goals on error
      return const UserGoals(
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

      // Query using milliseconds since epoch (int) format
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .where('date', isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch)
          .where('date', isLessThanOrEqualTo: endDate.millisecondsSinceEpoch)
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
  /// OPTIMIZED: Added debouncing to prevent excessive calls
  Future<void> refreshStreaks() async {
    // Prevent duplicate concurrent calls
    if (_isCalculatingStreaks) {
      // Reduced logging - only log once per session to avoid spam
      if (kDebugMode && !_hasLoggedDuplicateCall) {
        debugPrint('⚠️ Streak calculation already in progress, skipping duplicate call');
        _hasLoggedDuplicateCall = true;
      }
      return;
    }
    
    // Debounce rapid successive calls (within 2 seconds)
    final now = DateTime.now();
    if (_lastCalculationTime != null && 
        now.difference(_lastCalculationTime!).inSeconds < 2) {
      debugPrint('⚠️ Streak refresh called too soon after last calculation, debouncing...');
      // Cancel previous debounce timer and set new one
      _refreshDebounceTimer?.cancel();
      _refreshDebounceTimer = Timer(const Duration(seconds: 2), () {
        refreshStreaks();
      });
      return;
    }
    
    _isCalculatingStreaks = true;
    _lastCalculationTime = now;
    _refreshDebounceTimer?.cancel();
    
    try {
      // Debug logging removed for performance
      await _calculateAndUpdateStreaks();
      
      // Notify listeners of updated streak data
      _streakController.add(_currentStreaks);
      
      // Reduced logging - only log on errors or when active streaks change significantly
      // Debug logging removed for performance - streaks are updated via streams
    } catch (e) {
      debugPrint('❌ Error refreshing streaks: $e');
      _errorHandler.handleDataError('streak_refresh', e);
    } finally {
      _isCalculatingStreaks = false;
    }
  }

  /// Force refresh streaks with new data
  Future<void> forceRefreshStreaks() async {
    // Debug logging removed for performance
    try {
      await _calculateAndUpdateStreaks();
      debugPrint('✅ Force refresh completed');
    } catch (e) {
      debugPrint('❌ Error in force refresh: $e');
      rethrow;
    }
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
      // 'activeStreaks': _currentStreaks.activeStreaks.length,
      // 'streaksNeedingAttention': _currentStreaks.streaksNeedingAttention.length,
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

  /// Get default streak data when initialization fails
  UserStreakSummary _getDefaultStreakData() {
    final now = DateTime.now();
    return UserStreakSummary(
      goalStreaks: {
        DailyGoalType.calorieGoal: GoalStreak(
          goalType: DailyGoalType.calorieGoal,
          currentStreak: 0,
          longestStreak: 0,
          achievedToday: false,
          lastAchievedDate: now,
          streakStartDate: now,
          totalDaysAchieved: 0,
        ),
        DailyGoalType.steps: GoalStreak(
          goalType: DailyGoalType.steps,
          currentStreak: 0,
          longestStreak: 0,
          achievedToday: false,
          lastAchievedDate: now,
          streakStartDate: now,
          totalDaysAchieved: 0,
        ),
        DailyGoalType.exercise: GoalStreak(
          goalType: DailyGoalType.exercise,
          currentStreak: 0,
          longestStreak: 0,
          achievedToday: false,
          lastAchievedDate: now,
          streakStartDate: now,
          totalDaysAchieved: 0,
        ),
        DailyGoalType.waterIntake: GoalStreak(
          goalType: DailyGoalType.waterIntake,
          currentStreak: 0,
          longestStreak: 0,
          achievedToday: false,
          lastAchievedDate: now,
          streakStartDate: now,
          totalDaysAchieved: 0,
        ),
      },
      totalActiveStreaks: 0,
      longestOverallStreak: 0,
      lastActivityDate: now,
      totalDaysActive: 0,
    );
  }

  /// Dispose resources
  void dispose() {
    _streakController.close();
  }
}

