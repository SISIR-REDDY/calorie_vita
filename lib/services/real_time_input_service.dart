import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/daily_summary.dart';
import '../models/food_entry.dart';
import '../models/user_goals.dart';
import '../models/user_preferences.dart';
import '../models/reward_system.dart';
import '../services/firebase_service.dart';
import '../services/daily_summary_service.dart';
import '../services/rewards_service.dart';
import '../services/input_validation_service.dart';
import '../services/error_handler.dart';

/// Comprehensive real-time input service that handles all user inputs with Firestore integration
class RealTimeInputService {
  static final RealTimeInputService _instance = RealTimeInputService._internal();
  factory RealTimeInputService() => _instance;
  RealTimeInputService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final DailySummaryService _dailySummaryService = DailySummaryService();
  final RewardsService _rewardsService = RewardsService();
  final ErrorHandler _errorHandler = ErrorHandler();

  // Stream controllers for real-time updates
  final StreamController<DailySummary> _dailySummaryController = StreamController<DailySummary>.broadcast();
  final StreamController<UserProgress> _progressController = StreamController<UserProgress>.broadcast();
  final StreamController<List<UserReward>> _rewardsController = StreamController<List<UserReward>>.broadcast();
  final StreamController<String> _notificationController = StreamController<String>.broadcast();

  // Getters for streams
  Stream<DailySummary> get dailySummaryStream => _dailySummaryController.stream;
  Stream<UserProgress> get progressStream => _progressController.stream;
  Stream<List<UserReward>> get rewardsStream => _rewardsController.stream;
  Stream<String> get notificationStream => _notificationController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _dailySummaryService.initialize();
    await _rewardsService.initialize();
    _setupStreamListeners();
  }

  /// Setup stream listeners for real-time updates
  void _setupStreamListeners() {
    // Listen to daily summary updates
    _dailySummaryService.dailySummaryStream.listen((summary) {
      _dailySummaryController.add(summary);
    });

    // Listen to rewards progress updates
    _rewardsService.progressStream.listen((progress) {
      _progressController.add(progress);
    });

    // Listen to new rewards
    _rewardsService.newRewardsStream.listen((rewards) {
      _rewardsController.add(rewards);
      if (rewards.isNotEmpty) {
        _notificationController.add('🎉 New reward unlocked: ${rewards.first.title}');
      }
    });

    // Listen to level up events
    _rewardsService.levelUpStream.listen((levelUp) {
      _notificationController.add('🚀 Level up! You are now ${levelUp.newLevel.title}');
    });
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }


  /// Handle exercise input
  Future<bool> handleExercise(BuildContext context, {
    required int caloriesBurned,
    required int durationMinutes,
    required String exerciseType,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    // Validate inputs
    final caloriesValidation = InputValidationService.validateCaloriesBurned(caloriesBurned);
    final durationValidation = InputValidationService.validateExerciseDuration(durationMinutes);

    if (!caloriesValidation.isValid) {
      InputValidationService.showValidationResult(context, caloriesValidation);
      return false;
    }

    if (!durationValidation.isValid) {
      InputValidationService.showValidationResult(context, durationValidation);
      return false;
    }

    try {
      // Update Firestore
      await _firebaseService.updateExercise(
        userId,
        caloriesBurned: caloriesBurned,
        durationMinutes: durationMinutes,
        exerciseType: exerciseType,
      );
      await _dailySummaryService.updateExercise(
        userId,
        caloriesBurned: caloriesBurned,
        durationMinutes: durationMinutes,
        exerciseType: exerciseType,
      );

      // Show warnings if any
      if (caloriesValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, caloriesValidation);
      }
      if (durationValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, durationValidation);
      }

      _showSuccess(context, 'Exercise logged: $exerciseType');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleExercise', e);
      _showError(context, 'Failed to log exercise: $e');
      return false;
    }
  }

  /// Handle steps input
  Future<bool> handleSteps(BuildContext context, int steps) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    // Validate input
    final validation = InputValidationService.validateSteps(steps);
    if (!validation.isValid) {
      InputValidationService.showValidationResult(context, validation);
      return false;
    }

    try {
      // Update Firestore
      await _firebaseService.updateSteps(userId, steps);
      await _dailySummaryService.updateSteps(userId, steps);

      // Show warning if any
      if (validation.warningMessage != null) {
        InputValidationService.showValidationResult(context, validation);
      }

      _showSuccess(context, 'Steps updated: $steps steps');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleSteps', e);
      _showError(context, 'Failed to update steps: $e');
      return false;
    }
  }


  /// Handle weight input
  Future<bool> handleWeight(BuildContext context, double weight, double bmi) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    // Validate inputs
    final weightValidation = InputValidationService.validateWeight(weight);
    final bmiValidation = InputValidationService.validateBMI(bmi);

    if (!weightValidation.isValid) {
      InputValidationService.showValidationResult(context, weightValidation);
      return false;
    }

    if (!bmiValidation.isValid) {
      InputValidationService.showValidationResult(context, bmiValidation);
      return false;
    }

    try {
      // Update Firestore
      await _firebaseService.updateWeight(userId, weight, bmi);
      await _dailySummaryService.updateWeight(userId, weight, bmi);

      // Show warnings if any
      if (weightValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, weightValidation);
      }
      if (bmiValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, bmiValidation);
      }

      _showSuccess(context, 'Weight updated: ${weight.toStringAsFixed(1)} kg');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleWeight', e);
      _showError(context, 'Failed to update weight: $e');
      return false;
    }
  }

  /// Handle meal logging
  Future<bool> handleMealLogging(BuildContext context, FoodEntry foodEntry) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    // Validate food entry
    final nameValidation = InputValidationService.validateFoodName(foodEntry.name);
    final caloriesValidation = InputValidationService.validateCalories(foodEntry.calories);
    final portionValidation = InputValidationService.validatePortionSize(1.0); // Default portion since FoodEntry doesn't have this property

    if (!nameValidation.isValid) {
      InputValidationService.showValidationResult(context, nameValidation);
      return false;
    }

    if (!caloriesValidation.isValid) {
      InputValidationService.showValidationResult(context, caloriesValidation);
      return false;
    }

    if (!portionValidation.isValid) {
      InputValidationService.showValidationResult(context, portionValidation);
      return false;
    }

    try {
      // Save food entry to Firestore
      await _firebaseService.saveFoodEntry(userId, foodEntry);
      
      // Update daily summary
      await _dailySummaryService.onMealLogged(userId, foodEntry);

      // Show warnings if any
      if (nameValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, nameValidation);
      }
      if (caloriesValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, caloriesValidation);
      }
      if (portionValidation.warningMessage != null) {
        InputValidationService.showValidationResult(context, portionValidation);
      }

      _showSuccess(context, 'Meal logged: ${foodEntry.name}');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleMealLogging', e);
      _showError(context, 'Failed to log meal: $e');
      return false;
    }
  }

  /// Handle user goals update
  Future<bool> handleUserGoalsUpdate(BuildContext context, UserGoals goals) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    // Validate goals
    if (goals.calorieGoal != null) {
      final validation = InputValidationService.validateCalorieGoal(goals.calorieGoal!);
      if (!validation.isValid) {
        InputValidationService.showValidationResult(context, validation);
        return false;
      }
    }

    if (goals.waterGlassesGoal != null) {
      final validation = InputValidationService.validateWaterGoal(goals.waterGlassesGoal!);
      if (!validation.isValid) {
        InputValidationService.showValidationResult(context, validation);
        return false;
      }
    }

    if (goals.stepsPerDayGoal != null) {
      final validation = InputValidationService.validateStepsGoal(goals.stepsPerDayGoal!);
      if (!validation.isValid) {
        InputValidationService.showValidationResult(context, validation);
        return false;
      }
    }

    try {
      // Save goals to Firestore
      await _firebaseService.saveUserGoals(userId, goals);
      await _firebaseService.updateUserGoalsInDailySummary(userId, goals);
      await _dailySummaryService.updateUserGoals(userId, goals);

      _showSuccess(context, 'Goals updated successfully');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleUserGoalsUpdate', e);
      _showError(context, 'Failed to update goals: $e');
      return false;
    }
  }

  /// Handle user preferences update
  Future<bool> handleUserPreferencesUpdate(BuildContext context, UserPreferences preferences) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    try {
      // Save preferences to Firestore
      await _firebaseService.saveUserPreferences(userId, preferences);

      _showSuccess(context, 'Preferences updated successfully');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleUserPreferencesUpdate', e);
      _showError(context, 'Failed to update preferences: $e');
      return false;
    }
  }

  /// Handle profile update
  Future<bool> handleProfileUpdate(BuildContext context, Map<String, dynamic> profileData) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      _showError(context, 'User not authenticated');
      return false;
    }

    // Validate profile data
    if (profileData['age'] != null) {
      final validation = InputValidationService.validateAge(profileData['age']);
      if (!validation.isValid) {
        InputValidationService.showValidationResult(context, validation);
        return false;
      }
    }

    if (profileData['height'] != null) {
      final validation = InputValidationService.validateHeight(profileData['height']);
      if (!validation.isValid) {
        InputValidationService.showValidationResult(context, validation);
        return false;
      }
    }

    if (profileData['weight'] != null) {
      final validation = InputValidationService.validateWeight(profileData['weight']);
      if (!validation.isValid) {
        InputValidationService.showValidationResult(context, validation);
        return false;
      }
    }

    try {
      // Save profile to Firestore
      await _firebaseService.saveUserProfile(userId, profileData);

      _showSuccess(context, 'Profile updated successfully');
      return true;
    } catch (e) {
      _errorHandler.handleFirebaseError('handleProfileUpdate', e);
      _showError(context, 'Failed to update profile: $e');
      return false;
    }
  }

  /// Get today's daily summary stream
  Stream<DailySummary> getTodaySummary(String userId) {
    return _firebaseService.getTodayDailySummary(userId);
  }

  /// Get historical daily summaries stream
  Stream<List<DailySummary>> getHistoricalSummaries(String userId, {int days = 7}) {
    return _firebaseService.getHistoricalDailySummaries(userId, days: days);
  }

  /// Get user progress stream
  Stream<UserProgress> getUserProgress() {
    return _rewardsService.progressStream;
  }

  /// Get rewards stream
  Stream<List<UserReward>> getRewards() {
    return _rewardsService.newRewardsStream;
  }

  /// Show success message
  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show error message
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _dailySummaryController.close();
    _progressController.close();
    _rewardsController.close();
    _notificationController.close();
  }
}
