import '../models/reward_system.dart';
import '../services/rewards_service.dart';
import '../services/reward_notification_service.dart';

/// Helper service to easily integrate rewards with existing activities
class RewardIntegrationHelper {
  static final RewardIntegrationHelper _instance = RewardIntegrationHelper._internal();
  factory RewardIntegrationHelper() => _instance;
  RewardIntegrationHelper._internal();

  final RewardsService _rewardsService = RewardsService();
  final RewardNotificationService _notificationService = RewardNotificationService();

  /// Process meal logging activity
  Future<void> processMealLogging({
    required String mealType,
    required int calories,
    required DateTime timestamp,
  }) async {
    final result = await _rewardsService.processActivity(
      activityType: ActivityType.mealLogging,
      activityData: {
        'mealType': mealType,
        'calories': calories,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
      timestamp: timestamp,
    );

    if (result.success) {
      // Show notifications for new rewards
      for (final reward in result.newRewards) {
        _notificationService.showRewardNotification(reward);
      }

      // Show level up notification if applicable
      if (result.levelUp != null) {
        _notificationService.showLevelUpNotification(result.levelUp!);
      }
    }
  }


  /// Process exercise activity
  Future<void> processExercise({
    required String exerciseType,
    required int caloriesBurned,
    required int durationMinutes,
    required DateTime timestamp,
  }) async {
    final result = await _rewardsService.processActivity(
      activityType: ActivityType.exercise,
      activityData: {
        'exerciseType': exerciseType,
        'caloriesBurned': caloriesBurned,
        'durationMinutes': durationMinutes,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
      timestamp: timestamp,
    );

    if (result.success) {
      for (final reward in result.newRewards) {
        _notificationService.showRewardNotification(reward);
      }

      if (result.levelUp != null) {
        _notificationService.showLevelUpNotification(result.levelUp!);
      }
    }
  }


  /// Process steps activity
  Future<void> processSteps({
    required int steps,
    required DateTime timestamp,
  }) async {
    final result = await _rewardsService.processActivity(
      activityType: ActivityType.steps,
      activityData: {
        'steps': steps,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
      timestamp: timestamp,
    );

    if (result.success) {
      for (final reward in result.newRewards) {
        _notificationService.showRewardNotification(reward);
      }

      if (result.levelUp != null) {
        _notificationService.showLevelUpNotification(result.levelUp!);
      }
    }
  }

  /// Process weight check-in activity
  Future<void> processWeightCheckIn({
    required double weight,
    required DateTime timestamp,
  }) async {
    final result = await _rewardsService.processActivity(
      activityType: ActivityType.weightCheckIn,
      activityData: {
        'weight': weight,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
      timestamp: timestamp,
    );

    if (result.success) {
      for (final reward in result.newRewards) {
        _notificationService.showRewardNotification(reward);
      }

      if (result.levelUp != null) {
        _notificationService.showLevelUpNotification(result.levelUp!);
      }
    }
  }

  /// Process meditation activity
  Future<void> processMeditation({
    required int durationMinutes,
    required String meditationType,
    required DateTime timestamp,
  }) async {
    final result = await _rewardsService.processActivity(
      activityType: ActivityType.meditation,
      activityData: {
        'durationMinutes': durationMinutes,
        'meditationType': meditationType,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
      timestamp: timestamp,
    );

    if (result.success) {
      for (final reward in result.newRewards) {
        _notificationService.showRewardNotification(reward);
      }

      if (result.levelUp != null) {
        _notificationService.showLevelUpNotification(result.levelUp!);
      }
    }
  }

  /// Process calorie goal achievement
  Future<void> processCalorieGoalAchievement({
    required int targetCalories,
    required int actualCalories,
    required DateTime timestamp,
  }) async {
    final result = await _rewardsService.processActivity(
      activityType: ActivityType.calorieGoal,
      activityData: {
        'targetCalories': targetCalories,
        'actualCalories': actualCalories,
        'achieved': actualCalories <= targetCalories,
        'timestamp': timestamp.millisecondsSinceEpoch,
      },
      timestamp: timestamp,
    );

    if (result.success) {
      for (final reward in result.newRewards) {
        _notificationService.showRewardNotification(reward);
      }

      if (result.levelUp != null) {
        _notificationService.showLevelUpNotification(result.levelUp!);
      }
    }
  }

  /// Process daily goal completion
  Future<void> processDailyGoalCompletion({
    required Map<String, bool> goals,
    required DateTime timestamp,
  }) async {
    final allGoalsCompleted = goals.values.every((completed) => completed);
    
    if (allGoalsCompleted) {
      final result = await _rewardsService.processActivity(
        activityType: ActivityType.dailyGoalCompletion,
        activityData: {
          'goals': goals,
          'allCompleted': true,
          'timestamp': timestamp.millisecondsSinceEpoch,
        },
        timestamp: timestamp,
      );

      if (result.success) {
        for (final reward in result.newRewards) {
          _notificationService.showRewardNotification(reward);
        }

        if (result.levelUp != null) {
          _notificationService.showLevelUpNotification(result.levelUp!);
        }
      }
    }
  }

  /// Get current user progress
  UserProgress getCurrentProgress() {
    return _rewardsService.currentProgress;
  }

  /// Get activity streak
  ActivityStreak getActivityStreak(ActivityType activityType) {
    return _rewardsService.getActivityStreak(activityType);
  }

  /// Get unlocked rewards
  List<UserReward> getUnlockedRewards() {
    return _rewardsService.getUnlockedRewards();
  }

  /// Get available challenges
  List<Challenge> getAvailableChallenges() {
    return _rewardsService.getAvailableChallenges();
  }

  /// Initialize the rewards system
  Future<void> initialize() async {
    await _rewardsService.initialize();
  }
}
