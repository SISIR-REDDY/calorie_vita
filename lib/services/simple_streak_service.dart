import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/simple_streak_system.dart';
import 'error_handler.dart';

/// Simple streak service focused on daily goals and consistency
class SimpleStreakService {
  static final SimpleStreakService _instance = SimpleStreakService._internal();
  factory SimpleStreakService() => _instance;
  SimpleStreakService._internal();

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

  /// Initialize streak service
  Future<void> initialize() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _loadUserStreaks();
    } catch (e) {
      _errorHandler.handleDataError('streak_init', e);
    }
  }

  /// Load user streaks from Firestore with caching
  Future<void> _loadUserStreaks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // First, emit default data immediately for better UX
      _currentStreaks = _initializeDefaultStreaks();
      _streakController.add(_currentStreaks);

      // Then load actual data from Firestore
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('streaks')
          .doc('summary')
          .get();

      if (doc.exists) {
        _currentStreaks = UserStreakSummary.fromMap(doc.data()!);
      } else {
        // Initialize with default streaks for all goal types
        _currentStreaks = _initializeDefaultStreaks();
        await _saveUserStreaks();
      }

      // Emit the actual data
      _streakController.add(_currentStreaks);
    } catch (e) {
      _errorHandler.handleDataError('load_streaks', e);
      // Keep the default data if loading fails
    }
  }

  /// Initialize default streaks for all goal types
  UserStreakSummary _initializeDefaultStreaks() {
    final goalStreaks = <DailyGoalType, GoalStreak>{};

    for (final goalType in DailyGoalType.values) {
      goalStreaks[goalType] = GoalStreak(
        goalType: goalType,
        currentStreak: 0,
        longestStreak: 0,
        lastAchievedDate: DateTime.now().subtract(const Duration(days: 1)),
        achievedToday: false,
        streakStartDate: DateTime.now().subtract(const Duration(days: 1)),
        totalDaysAchieved: 0,
      );
    }

    return UserStreakSummary(
      goalStreaks: goalStreaks,
      totalActiveStreaks: 0,
      longestOverallStreak: 0,
      lastActivityDate: DateTime.now(),
      totalDaysActive: 0,
    );
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

  /// Mark a daily goal as achieved today
  Future<void> markGoalAchieved(DailyGoalType goalType) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get current streak for this goal
      final currentStreak = _currentStreaks.goalStreaks[goalType] ??
          GoalStreak(
            goalType: goalType,
            currentStreak: 0,
            longestStreak: 0,
            lastAchievedDate: today.subtract(const Duration(days: 1)),
            achievedToday: false,
            streakStartDate: today.subtract(const Duration(days: 1)),
            totalDaysAchieved: 0,
          );

      // Check if already achieved today
      if (currentStreak.achievedToday) return;

      // Calculate new streak
      int newCurrentStreak = currentStreak.currentStreak;
      int newLongestStreak = currentStreak.longestStreak;

      if (currentStreak.lastAchievedDate
          .isBefore(today.subtract(const Duration(days: 1)))) {
        // Streak was broken, reset to 1
        newCurrentStreak = 1;
      } else if (currentStreak.lastAchievedDate
          .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
        // Continuing streak
        newCurrentStreak = currentStreak.currentStreak + 1;
      } else {
        // Same day, no change needed
        return;
      }

      // Update longest streak if needed
      if (newCurrentStreak > newLongestStreak) {
        newLongestStreak = newCurrentStreak;
      }

      // Create updated streak
      final updatedStreak = currentStreak.copyWith(
        currentStreak: newCurrentStreak,
        longestStreak: newLongestStreak,
        lastAchievedDate: today,
        achievedToday: true,
        totalDaysAchieved: currentStreak.totalDaysAchieved + 1,
      );

      // Update the streaks map
      final updatedGoalStreaks =
          Map<DailyGoalType, GoalStreak>.from(_currentStreaks.goalStreaks);
      updatedGoalStreaks[goalType] = updatedStreak;

      // Update overall summary
      _currentStreaks = _currentStreaks.copyWith(
        goalStreaks: updatedGoalStreaks,
        totalActiveStreaks:
            updatedGoalStreaks.values.where((s) => s.achievedToday).length,
        longestOverallStreak: updatedGoalStreaks.values
            .map((s) => s.longestStreak)
            .reduce((a, b) => a > b ? a : b),
        lastActivityDate: today,
        totalDaysActive: _currentStreaks.totalDaysActive + 1,
      );

      // Save to Firestore and notify listeners
      await _saveUserStreaks();
      _streakController.add(_currentStreaks);
    } catch (e) {
      _errorHandler.handleDataError('mark_goal_achieved', e);
    }
  }

  /// Mark a daily goal as not achieved (for streak breaking)
  Future<void> markGoalNotAchieved(DailyGoalType goalType) async {
    try {
      final currentStreak = _currentStreaks.goalStreaks[goalType];
      if (currentStreak == null || !currentStreak.achievedToday) return;

      // Create updated streak
      final updatedStreak = currentStreak.copyWith(
        achievedToday: false,
      );

      // Update the streaks map
      final updatedGoalStreaks =
          Map<DailyGoalType, GoalStreak>.from(_currentStreaks.goalStreaks);
      updatedGoalStreaks[goalType] = updatedStreak;

      // Update overall summary
      _currentStreaks = _currentStreaks.copyWith(
        goalStreaks: updatedGoalStreaks,
        totalActiveStreaks:
            updatedGoalStreaks.values.where((s) => s.achievedToday).length,
      );

      // Save to Firestore and notify listeners
      await _saveUserStreaks();
      _streakController.add(_currentStreaks);
    } catch (e) {
      _errorHandler.handleDataError('mark_goal_not_achieved', e);
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
      _currentStreaks = _initializeDefaultStreaks();
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
