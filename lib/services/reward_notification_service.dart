import 'package:flutter/material.dart';
import 'dart:async';
import '../models/reward_system.dart';
import 'rewards_service.dart';

/// Service to handle reward notifications and animations
class RewardNotificationService {
  static final RewardNotificationService _instance = RewardNotificationService._internal();
  factory RewardNotificationService() => _instance;
  RewardNotificationService._internal();

  final StreamController<RewardNotification> _notificationController = 
      StreamController<RewardNotification>.broadcast();
  final StreamController<LevelUpNotification> _levelUpController = 
      StreamController<LevelUpNotification>.broadcast();

  Stream<RewardNotification> get notificationStream => _notificationController.stream;
  Stream<LevelUpNotification> get levelUpStream => _levelUpController.stream;

  /// Show a reward notification
  void showRewardNotification(UserReward reward) {
    _notificationController.add(RewardNotification(
      reward: reward,
      timestamp: DateTime.now(),
    ));
  }

  /// Show a level up notification
  void showLevelUpNotification(LevelUpEvent levelUp) {
    _levelUpController.add(LevelUpNotification(
      oldLevel: levelUp.oldLevel,
      newLevel: levelUp.newLevel,
      totalXp: levelUp.totalXp,
      timestamp: DateTime.now(),
    ));
  }

  /// Show a streak notification
  void showStreakNotification(ActivityType activityType, int streakDays) {
    final reward = _createStreakReward(activityType, streakDays);
    showRewardNotification(reward);
  }

  /// Show a milestone notification
  void showMilestoneNotification(ActivityType activityType, int milestone) {
    final reward = _createMilestoneReward(activityType, milestone);
    showRewardNotification(reward);
  }

  /// Create a streak reward for notification
  UserReward _createStreakReward(ActivityType activityType, int streakDays) {
    String title = '';
    String emoji = '';
    int points = 0;
    Color color = Colors.blue;

    if (activityType == ActivityType.mealLogging) {
      if (streakDays >= 365) {
        title = 'Nutrition Legend';
        emoji = '👑';
        points = 2500;
        color = Colors.purple;
      } else if (streakDays >= 100) {
        title = 'Meal Pro';
        emoji = '👨‍🍳';
        points = 1000;
        color = Colors.deepOrange;
      } else if (streakDays >= 30) {
        title = 'Meal Tracker';
        emoji = '📊';
        points = 500;
        color = Colors.orange;
      } else if (streakDays >= 7) {
        title = 'Meal Rookie';
        emoji = '🍽️';
        points = 100;
        color = Colors.green;
      }
    } else if (activityType == ActivityType.exercise) {
      if (streakDays >= 365) {
        title = 'Titan';
        emoji = '⚡';
        points = 3000;
        color = Colors.orange;
      } else if (streakDays >= 100) {
        title = 'Iron Body';
        emoji = '🏆';
        points = 1500;
        color = Colors.amber;
      } else if (streakDays >= 30) {
        title = 'Fitness Warrior';
        emoji = '🏋️‍♂️';
        points = 750;
        color = Colors.red.shade700;
      } else if (streakDays >= 7) {
        title = 'Fitness Rookie';
        emoji = '💪';
        points = 150;
        color = Colors.red;
      }
    } else {
      title = 'Streak Master';
      emoji = '🔥';
      points = streakDays * 10;
      color = Colors.orange;
    }

    return UserReward(
      id: '${activityType.name}_streak_$streakDays',
      title: title,
      description: '$streakDays-day ${_getActivityName(activityType)} streak',
      emoji: emoji,
      points: points,
      type: RewardType.streak,
      category: _getActivityCategory(activityType),
      color: color,
      isUnlocked: true,
      earnedAt: DateTime.now(),
    );
  }

  /// Create a milestone reward for notification
  UserReward _createMilestoneReward(ActivityType activityType, int milestone) {
    String title = '';
    String emoji = '';
    int points = 0;
    Color color = Colors.blue;

    if (activityType == ActivityType.mealLogging) {
      if (milestone >= 5000) {
        title = 'Meal Deity';
        emoji = '🌟';
        points = 5000;
        color = Colors.cyan;
      } else if (milestone >= 1000) {
        title = 'Meal Legend';
        emoji = '👑';
        points = 2000;
        color = Colors.purple;
      } else if (milestone >= 500) {
        title = 'Meal Master';
        emoji = '🏆';
        points = 1000;
        color = Colors.amber;
      } else if (milestone >= 100) {
        title = 'Meal Expert';
        emoji = '👨‍🍳';
        points = 400;
        color = Colors.orange;
      } else if (milestone >= 50) {
        title = 'Meal Enthusiast';
        emoji = '🥗';
        points = 200;
        color = Colors.lightGreen;
      } else if (milestone >= 10) {
        title = 'Meal Beginner';
        emoji = '🍽️';
        points = 50;
        color = Colors.green;
      }
    } else if (activityType == ActivityType.exercise) {
      if (milestone >= 500) {
        title = 'Titan';
        emoji = '⚡';
        points = 3000;
        color = Colors.orange;
      } else if (milestone >= 100) {
        title = 'Iron Body';
        emoji = '🏋️‍♂️';
        points = 1000;
        color = Colors.red.shade700;
      } else if (milestone >= 10) {
        title = 'Fitness Starter';
        emoji = '💪';
        points = 200;
        color = Colors.red;
      }
    } else if (activityType == ActivityType.steps) {
      if (milestone >= 1000000) {
        title = 'Marathoner';
        emoji = '🏃‍♀️';
        points = 1000;
        color = Colors.purple;
      } else if (milestone >= 100000) {
        title = 'Step Hero';
        emoji = '🏃‍♂️';
        points = 300;
        color = Colors.blue;
      } else if (milestone >= 10000) {
        title = 'Step Rookie';
        emoji = '🚶‍♂️';
        points = 50;
        color = Colors.green;
      }
    } else {
      title = 'Milestone Master';
      emoji = '🎯';
      points = milestone * 5;
      color = Colors.amber;
    }

    return UserReward(
      id: '${activityType.name}_$milestone',
      title: title,
      description: 'Reached $milestone ${_getActivityName(activityType)} milestone',
      emoji: emoji,
      points: points,
      type: RewardType.milestone,
      category: _getActivityCategory(activityType),
      color: color,
      isUnlocked: true,
      earnedAt: DateTime.now(),
    );
  }

  String _getActivityName(ActivityType activityType) {
    if (activityType == ActivityType.mealLogging) {
      return 'meals';
    } else if (activityType == ActivityType.exercise) {
      return 'workouts';
    } else if (activityType == ActivityType.calorieGoal) {
      return 'calorie goals';
    } else if (activityType == ActivityType.steps) {
      return 'steps';
    } else if (activityType == ActivityType.weightCheckIn) {
      return 'weight check-ins';
    } else if (activityType == ActivityType.meditation) {
      return 'meditation sessions';
    } else if (activityType == ActivityType.dailyGoalCompletion) {
      return 'daily goals';
    }
    return 'activities';
  }

  BadgeCategory _getActivityCategory(ActivityType activityType) {
    if (activityType == ActivityType.mealLogging) {
      return BadgeCategory.logging;
    } else if (activityType == ActivityType.exercise) {
      return BadgeCategory.exercise;
    } else if (activityType == ActivityType.calorieGoal) {
      return BadgeCategory.nutrition;
    } else if (activityType == ActivityType.steps) {
      return BadgeCategory.steps;
    } else if (activityType == ActivityType.weightCheckIn) {
      return BadgeCategory.weight;
    } else if (activityType == ActivityType.meditation) {
      return BadgeCategory.meditation;
    } else if (activityType == ActivityType.dailyGoalCompletion) {
      return BadgeCategory.achievement;
    }
    return BadgeCategory.achievement;
  }

  void dispose() {
    _notificationController.close();
    _levelUpController.close();
  }
}

/// Reward notification model
class RewardNotification {
  final UserReward reward;
  final DateTime timestamp;

  const RewardNotification({
    required this.reward,
    required this.timestamp,
  });
}

/// Level up notification model
class LevelUpNotification {
  final UserLevel oldLevel;
  final UserLevel newLevel;
  final int totalXp;
  final DateTime timestamp;

  const LevelUpNotification({
    required this.oldLevel,
    required this.newLevel,
    required this.totalXp,
    required this.timestamp,
  });
}
