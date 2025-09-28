import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/daily_summary.dart';
import '../models/food_entry.dart';
import '../models/user_goals.dart';
import '../models/reward_system.dart';
import '../services/rewards_service.dart';
import '../services/error_handler.dart';
import '../services/enhanced_streak_service.dart';

/// Comprehensive daily summary service for real-time Firestore integration
class DailySummaryService {
  static final DailySummaryService _instance = DailySummaryService._internal();
  factory DailySummaryService() => _instance;
  DailySummaryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RewardsService _rewardsService = RewardsService();
  final ErrorHandler _errorHandler = ErrorHandler();

  // Stream controllers for real-time updates
  final StreamController<DailySummary> _dailySummaryController =
      StreamController<DailySummary>.broadcast();
  final StreamController<Map<String, dynamic>> _progressController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<DailySummary> get dailySummaryStream => _dailySummaryController.stream;
  Stream<Map<String, dynamic>> get progressStream => _progressController.stream;

  // Current daily summary cache
  DailySummary? _currentDailySummary;
  DateTime? _lastUpdateDate;

  /// Initialize the service
  Future<void> initialize() async {
    await _rewardsService.initialize();
    _startDailyResetTimer();
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Get today's daily summary with real-time updates
  Stream<DailySummary> getTodaySummary(String userId) {
    final today = DateTime.now();
    final dateKey = _getDateKey(today);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_summaries')
        .doc(dateKey)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final summary = DailySummary.fromMap(data);
        _currentDailySummary = summary;
        _lastUpdateDate = today;
        _dailySummaryController.add(summary);
        return summary;
      } else {
        // Create default summary for today
        final defaultSummary = _createDefaultSummary(today);
        _currentDailySummary = defaultSummary;
        _lastUpdateDate = today;
        _dailySummaryController.add(defaultSummary);
        return defaultSummary;
      }
    }).handleError((error) {
      _errorHandler.handleFirebaseError('getTodaySummary', error);
      return _createDefaultSummary(today);
    });
  }

  /// Update exercise data
  Future<void> updateExercise(
    String userId, {
    required int caloriesBurned,
    required int durationMinutes,
    required String exerciseType,
  }) async {
    try {
      // Validate input
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }
      if (caloriesBurned < 0 || caloriesBurned > 5000) {
        throw Exception('Invalid calories burned: $caloriesBurned');
      }
      if (durationMinutes < 0 || durationMinutes > 480) {
        throw Exception('Invalid duration: $durationMinutes minutes');
      }
      if (exerciseType.isEmpty) {
        throw Exception('Exercise type cannot be empty');
      }

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey);

      await docRef.set({
        'caloriesBurned': FieldValue.increment(caloriesBurned),
        'exerciseMinutes': FieldValue.increment(durationMinutes),
        'exerciseType': exerciseType,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger rewards
      await _rewardsService.processActivity(
        activityType: ActivityType.exercise,
        activityData: {
          'calories': caloriesBurned,
          'duration': durationMinutes,
          'type': exerciseType,
        },
      );

      // Update local cache
      await _updateLocalSummary(userId, {
        'caloriesBurned':
            (_currentDailySummary?.caloriesBurned ?? 0) + caloriesBurned,
      });

      // Refresh streaks after exercise update
      try {
        final enhancedStreakService = EnhancedStreakService();
        await enhancedStreakService.refreshStreaks();
      } catch (e) {
        debugPrint('Error refreshing streaks after exercise update: $e');
      }

      // Exercise updated successfully
    } catch (e) {
      _errorHandler.handleFirebaseError('updateExercise', e);
      rethrow;
    }
  }

  /// Update steps
  Future<void> updateSteps(String userId, int steps) async {
    try {
      // Validate input
      if (steps < 0 || steps > 100000) {
        throw Exception('Invalid steps: $steps');
      }

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey);

      await docRef.set({
        'steps': steps,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger rewards
      await _rewardsService.processActivity(
        activityType: ActivityType.steps,
        activityData: {'steps': steps},
      );

      // Update local cache
      await _updateLocalSummary(userId, {'steps': steps});

      // Refresh streaks after steps update
      try {
        final enhancedStreakService = EnhancedStreakService();
        await enhancedStreakService.refreshStreaks();
      } catch (e) {
        debugPrint('Error refreshing streaks after steps update: $e');
      }

      // Steps updated successfully
    } catch (e) {
      _errorHandler.handleFirebaseError('updateSteps', e);
      rethrow;
    }
  }

  /// Update meal logging (called when food entry is added)
  Future<void> onMealLogged(String userId, FoodEntry foodEntry) async {
    try {
      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey);

      // Get current summary
      final currentSummary = await _getCurrentSummary(userId, dateKey);

      // Update calories consumed
      final newCaloriesConsumed =
          (currentSummary['caloriesConsumed'] ?? 0) + foodEntry.calories;

      await docRef.set({
        'caloriesConsumed': newCaloriesConsumed,
        'lastMealLogged': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger rewards
      await _rewardsService.processActivity(
        activityType: ActivityType.mealLogging,
        activityData: {
          'calories': foodEntry.calories,
          'foodName': foodEntry.name,
          'mealType':
              'meal', // Default meal type since FoodEntry doesn't have this property
        },
      );

      // Update local cache
      await _updateLocalSummary(
          userId, {'caloriesConsumed': newCaloriesConsumed});

      // Refresh streaks after meal logging
      try {
        final enhancedStreakService = EnhancedStreakService();
        await enhancedStreakService.refreshStreaks();
      } catch (e) {
        debugPrint('Error refreshing streaks after meal logging: $e');
      }

      // Meal logged successfully
    } catch (e) {
      _errorHandler.handleFirebaseError('onMealLogged', e);
      rethrow;
    }
  }

  /// Update weight
  Future<void> updateWeight(String userId, double weight, double bmi) async {
    try {
      // Validate input
      if (weight < 20 || weight > 500) {
        throw Exception('Invalid weight: $weight kg');
      }
      if (bmi < 10 || bmi > 100) {
        throw Exception('Invalid BMI: $bmi');
      }

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey);

      await docRef.set({
        'weight': weight,
        'bmi': bmi,
        'lastWeightUpdate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger rewards
      await _rewardsService.processActivity(
        activityType: ActivityType.weightCheckIn,
        activityData: {'weight': weight, 'bmi': bmi},
      );

      // Update local cache
      await _updateLocalSummary(userId, {'weight': weight, 'bmi': bmi});

      // Weight updated successfully
    } catch (e) {
      _errorHandler.handleFirebaseError('updateWeight', e);
      rethrow;
    }
  }

  /// Update user goals in daily summary
  Future<void> updateUserGoals(String userId, UserGoals goals) async {
    try {
      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey);

      await docRef.set({
        'caloriesGoal': goals.calorieGoal ?? 2000,
        'waterGoal': goals.waterGlassesGoal ?? 8,
        'stepsGoal': goals.stepsPerDayGoal ?? 10000,
        'sleepGoal': 8.0, // Default sleep goal
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local cache
      await _updateLocalSummary(userId, {
        'caloriesGoal': goals.calorieGoal ?? 2000,
        'waterGoal': goals.waterGlassesGoal ?? 8,
        'stepsGoal': goals.stepsPerDayGoal ?? 10000,
        'sleepGoal': 8.0,
      });

      // User goals updated successfully
    } catch (e) {
      _errorHandler.handleFirebaseError('updateUserGoals', e);
      rethrow;
    }
  }

  /// Get historical daily summaries
  Stream<List<DailySummary>> getHistoricalSummaries(String userId,
      {int days = 7}) {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_summaries')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DailySummary.fromMap(doc.data()))
          .toList();
    }).handleError((error) {
      _errorHandler.handleFirebaseError('getHistoricalSummaries', error);
      return <DailySummary>[];
    });
  }

  /// Get current summary data
  Future<Map<String, dynamic>> _getCurrentSummary(
      String userId, String dateKey) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey)
          .get();

      return doc.exists ? doc.data()! : {};
    } catch (e) {
      _errorHandler.handleFirebaseError('_getCurrentSummary', e);
      return {};
    }
  }

  /// Update daily summary with Google Fit data
  Future<void> updateDailySummary(DailySummary updatedSummary) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return;

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc(dateKey);

      await docRef.set({
        'caloriesConsumed': updatedSummary.caloriesConsumed,
        'caloriesBurned': updatedSummary.caloriesBurned,
        'steps': updatedSummary.steps,
        'caloriesGoal': updatedSummary.caloriesGoal,
        'stepsGoal': updatedSummary.stepsGoal,
        'waterGlasses': updatedSummary.waterGlasses,
        'waterGlassesGoal': updatedSummary.waterGlassesGoal,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local cache
      _currentDailySummary = updatedSummary;
      _dailySummaryController.add(updatedSummary);

      // Daily summary updated successfully
    } catch (e) {
      _errorHandler.handleFirebaseError('updateDailySummary', e);
      rethrow;
    }
  }

  /// Update local summary cache
  Future<void> _updateLocalSummary(
      String userId, Map<String, dynamic> updates) async {
    if (_currentDailySummary == null) return;

    final updatedSummary = _currentDailySummary!.copyWith(
      caloriesConsumed:
          updates['caloriesConsumed'] ?? _currentDailySummary!.caloriesConsumed,
      caloriesBurned:
          updates['caloriesBurned'] ?? _currentDailySummary!.caloriesBurned,
      steps: updates['steps'] ?? _currentDailySummary!.steps,
      caloriesGoal:
          updates['caloriesGoal'] ?? _currentDailySummary!.caloriesGoal,
      stepsGoal: updates['stepsGoal'] ?? _currentDailySummary!.stepsGoal,
    );

    _currentDailySummary = updatedSummary;
    _dailySummaryController.add(updatedSummary);

    // Emit progress update
    _progressController.add({
      'calorieProgress': updatedSummary.calorieProgress,
      'stepsProgress': updatedSummary.stepsProgress,
      'overallProgress': updatedSummary.overallProgress,
    });
  }

  /// Create default summary for a date
  DailySummary _createDefaultSummary(DateTime date) {
    return DailySummary(
      caloriesConsumed: 0,
      caloriesBurned: 0,
      caloriesGoal: 2000,
      steps: 0,
      stepsGoal: 10000,
      waterGlasses: 0,
      waterGlassesGoal: 8,
      date: date,
    );
  }

  /// Get date key for Firestore document
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Start daily reset timer
  void _startDailyResetTimer() {
    Timer.periodic(const Duration(hours: 1), (timer) {
      final now = DateTime.now();
      if (now.hour == 0) {
        _performDailyReset();
      }
    });
  }

  /// Perform daily reset
  void _performDailyReset() {
    // Reset daily summary cache
    _currentDailySummary = null;
    _lastUpdateDate = null;

    // Emit reset event
    _progressController.add({
      'dailyReset': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Dispose resources
  void dispose() {
    _dailySummaryController.close();
    _progressController.close();
  }
}
