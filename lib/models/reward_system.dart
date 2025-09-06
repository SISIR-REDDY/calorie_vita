import 'dart:math';
import 'package:flutter/material.dart';

// Reward System Enums
enum RewardType {
  daily,
  weekly,
  monthly,
  milestone,
  special,
  streak,
  challenge,
}

enum BadgeCategory {
  logging,
  nutrition,
  exercise,
  water,
  consistency,
  achievement,
  sleep,
  weight,
  meditation,
  steps,
}

enum UserLevel {
  beginner('Beginner', 0, Colors.grey, '🌱'),
  rookie('Rookie', 500, Colors.blue, '🔰'),
  enthusiast('Enthusiast', 1500, Colors.green, '💪'),
  champion('Champion', 3000, Colors.orange, '🏆'),
  master('Master', 5000, Colors.purple, '👑'),
  legend('Legend', 10000, Colors.amber, '⭐'),
  titan('Titan', 25000, Colors.red, '⚡'),
  immortal('Immortal', 50000, Colors.indigo, '🌟'),
  deity('Deity', 100000, Colors.cyan, '✨');

  const UserLevel(this.title, this.requiredPoints, this.color, this.emoji);
  
  final String title;
  final int requiredPoints;
  final Color color;
  final String emoji;
}

/// Activity types that can earn rewards
enum ActivityType {
  mealLogging,
  exercise,
  calorieGoal,
  steps,
  weightCheckIn,
  meditation,
  dailyGoalCompletion,
}

// Reward Models
class UserReward {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final int points;
  final RewardType type;
  final BadgeCategory? category;
  final DateTime? earnedAt;
  final bool isUnlocked;
  final Color color;

  const UserReward({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.points,
    required this.type,
    this.category,
    this.earnedAt,
    this.isUnlocked = false,
    this.color = Colors.blue,
  });

  UserReward copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    int? points,
    RewardType? type,
    BadgeCategory? category,
    DateTime? earnedAt,
    bool? isUnlocked,
    Color? color,
  }) {
    return UserReward(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      points: points ?? this.points,
      type: type ?? this.type,
      category: category ?? this.category,
      earnedAt: earnedAt ?? this.earnedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'emoji': emoji,
      'points': points,
      'type': type.name,
      'category': category?.name,
      'earnedAt': earnedAt?.millisecondsSinceEpoch,
      'isUnlocked': isUnlocked,
      'color': color.value,
    };
  }

  factory UserReward.fromMap(Map<String, dynamic> map) {
    return UserReward(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      emoji: map['emoji'] ?? '🏆',
      points: map['points']?.toInt() ?? 0,
      type: RewardType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RewardType.daily,
      ),
      category: map['category'] != null 
          ? BadgeCategory.values.firstWhere(
              (e) => e.name == map['category'],
              orElse: () => BadgeCategory.achievement,
            )
          : null,
      earnedAt: map['earnedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['earnedAt'])
          : null,
      isUnlocked: map['isUnlocked'] ?? false,
      color: Color(map['color'] ?? Colors.blue.value),
    );
  }
}

class UserProgress {
  final int totalPoints;
  final int currentStreak;
  final int longestStreak;
  final UserLevel currentLevel;
  final int pointsToNextLevel;
  final double levelProgress;
  final List<UserReward> unlockedRewards;
  final Map<String, int> categoryProgress;

  const UserProgress({
    required this.totalPoints,
    required this.currentStreak,
    required this.longestStreak,
    required this.currentLevel,
    required this.pointsToNextLevel,
    required this.levelProgress,
    required this.unlockedRewards,
    required this.categoryProgress,
  });

  factory UserProgress.initial() {
    return const UserProgress(
      totalPoints: 0,
      currentStreak: 0,
      longestStreak: 0,
      currentLevel: UserLevel.beginner,
      pointsToNextLevel: 500,
      levelProgress: 0.0,
      unlockedRewards: [],
      categoryProgress: {},
    );
  }

  UserProgress copyWith({
    int? totalPoints,
    int? currentStreak,
    int? longestStreak,
    UserLevel? currentLevel,
    int? pointsToNextLevel,
    double? levelProgress,
    List<UserReward>? unlockedRewards,
    Map<String, int>? categoryProgress,
  }) {
    return UserProgress(
      totalPoints: totalPoints ?? this.totalPoints,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      currentLevel: currentLevel ?? this.currentLevel,
      pointsToNextLevel: pointsToNextLevel ?? this.pointsToNextLevel,
      levelProgress: levelProgress ?? this.levelProgress,
      unlockedRewards: unlockedRewards ?? this.unlockedRewards,
      categoryProgress: categoryProgress ?? this.categoryProgress,
    );
  }
}

// Predefined Rewards System
class RewardSystem {
  static List<UserReward> getAllRewards() {
    return [
      // ===== STREAK REWARDS =====
      // Water Streak Rewards
      const UserReward(
        id: 'water_streak_7',
        title: 'Hydration Hero',
        description: '7-day water intake streak',
        emoji: '💧',
        points: 100,
        type: RewardType.streak,
        category: BadgeCategory.water,
        color: Colors.blue,
      ),
      const UserReward(
        id: 'water_streak_30',
        title: 'Water Champion',
        description: '30-day water intake streak',
        emoji: '🌊',
        points: 500,
        type: RewardType.streak,
        category: BadgeCategory.water,
        color: Colors.cyan,
      ),
      const UserReward(
        id: 'water_streak_100',
        title: 'Aqua Master',
        description: '100-day water intake streak',
        emoji: '🏊‍♂️',
        points: 1000,
        type: RewardType.streak,
        category: BadgeCategory.water,
        color: Colors.lightBlue,
      ),
      const UserReward(
        id: 'water_streak_365',
        title: 'Ocean Lord',
        description: '365-day water intake streak',
        emoji: '🌊',
        points: 2500,
        type: RewardType.streak,
        category: BadgeCategory.water,
        color: Colors.indigo,
      ),

      // Meal Streak Rewards
      const UserReward(
        id: 'meal_streak_7',
        title: 'Meal Rookie',
        description: '7-day meal logging streak',
        emoji: '🍽️',
        points: 100,
        type: RewardType.streak,
        category: BadgeCategory.logging,
        color: Colors.green,
      ),
      const UserReward(
        id: 'meal_streak_30',
        title: 'Meal Tracker',
        description: '30-day meal logging streak',
        emoji: '📊',
        points: 500,
        type: RewardType.streak,
        category: BadgeCategory.logging,
        color: Colors.orange,
      ),
      const UserReward(
        id: 'meal_streak_100',
        title: 'Meal Pro',
        description: '100-day meal logging streak',
        emoji: '👨‍🍳',
        points: 1000,
        type: RewardType.streak,
        category: BadgeCategory.logging,
        color: Colors.deepOrange,
      ),
      const UserReward(
        id: 'meal_streak_365',
        title: 'Nutrition Legend',
        description: '365-day meal logging streak',
        emoji: '👑',
        points: 2500,
        type: RewardType.streak,
        category: BadgeCategory.logging,
        color: Colors.purple,
      ),

      // Exercise Streak Rewards
      const UserReward(
        id: 'exercise_streak_7',
        title: 'Fitness Rookie',
        description: '7-day exercise streak',
        emoji: '💪',
        points: 150,
        type: RewardType.streak,
        category: BadgeCategory.exercise,
        color: Colors.red,
      ),
      const UserReward(
        id: 'exercise_streak_30',
        title: 'Fitness Warrior',
        description: '30-day exercise streak',
        emoji: '🏋️‍♂️',
        points: 750,
        type: RewardType.streak,
        category: BadgeCategory.exercise,
        color: const Color(0xFFD32F2F),
      ),
      const UserReward(
        id: 'exercise_streak_100',
        title: 'Iron Body',
        description: '100-day exercise streak',
        emoji: '🏆',
        points: 1500,
        type: RewardType.streak,
        category: BadgeCategory.exercise,
        color: Colors.amber,
      ),
      const UserReward(
        id: 'exercise_streak_365',
        title: 'Titan',
        description: '365-day exercise streak',
        emoji: '⚡',
        points: 3000,
        type: RewardType.streak,
        category: BadgeCategory.exercise,
        color: Colors.orange,
      ),

      // Sleep Streak Rewards
      const UserReward(
        id: 'sleep_streak_7',
        title: 'Dream Rookie',
        description: '7-day sleep logging streak',
        emoji: '😴',
        points: 100,
        type: RewardType.streak,
        category: BadgeCategory.sleep,
        color: Colors.indigo,
      ),
      const UserReward(
        id: 'sleep_streak_30',
        title: 'Sleep Guardian',
        description: '30-day sleep logging streak',
        emoji: '🌙',
        points: 500,
        type: RewardType.streak,
        category: BadgeCategory.sleep,
        color: Colors.purple,
      ),
      const UserReward(
        id: 'sleep_streak_100',
        title: 'Zen Sleeper',
        description: '100-day sleep logging streak',
        emoji: '🧘‍♂️',
        points: 1000,
        type: RewardType.streak,
        category: BadgeCategory.sleep,
        color: Colors.deepPurple,
      ),
      const UserReward(
        id: 'sleep_streak_365',
        title: 'Dream Lord',
        description: '365-day sleep logging streak',
        emoji: '✨',
        points: 2500,
        type: RewardType.streak,
        category: BadgeCategory.sleep,
        color: Colors.cyan,
      ),

      // ===== MILESTONE REWARDS =====
      // Meal Milestones
      const UserReward(
        id: 'meals_10',
        title: 'Meal Beginner',
        description: 'Logged 10 meals',
        emoji: '🍽️',
        points: 50,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.green,
      ),
      const UserReward(
        id: 'meals_50',
        title: 'Meal Enthusiast',
        description: 'Logged 50 meals',
        emoji: '🥗',
        points: 200,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.lightGreen,
      ),
      const UserReward(
        id: 'meals_100',
        title: 'Meal Expert',
        description: 'Logged 100 meals',
        emoji: '👨‍🍳',
        points: 400,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.orange,
      ),
      const UserReward(
        id: 'meals_500',
        title: 'Meal Master',
        description: 'Logged 500 meals',
        emoji: '🏆',
        points: 1000,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.amber,
      ),
      const UserReward(
        id: 'meals_1000',
        title: 'Meal Legend',
        description: 'Logged 1000 meals',
        emoji: '👑',
        points: 2000,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.purple,
      ),
      const UserReward(
        id: 'meals_5000',
        title: 'Meal Deity',
        description: 'Logged 5000 meals',
        emoji: '🌟',
        points: 5000,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.cyan,
      ),

      // Water Milestones
      const UserReward(
        id: 'water_100',
        title: 'Water Rookie',
        description: 'Logged 100 glasses of water',
        emoji: '💧',
        points: 100,
        type: RewardType.milestone,
        category: BadgeCategory.water,
        color: Colors.blue,
      ),
      const UserReward(
        id: 'water_1000',
        title: 'Hydration Hero',
        description: 'Logged 1000 glasses of water',
        emoji: '🌊',
        points: 500,
        type: RewardType.milestone,
        category: BadgeCategory.water,
        color: Colors.cyan,
      ),
      const UserReward(
        id: 'water_5000',
        title: 'Ocean Lord',
        description: 'Logged 5000 glasses of water',
        emoji: '🏊‍♂️',
        points: 1500,
        type: RewardType.milestone,
        category: BadgeCategory.water,
        color: Colors.indigo,
      ),

      // Exercise Milestones
      const UserReward(
        id: 'exercise_10',
        title: 'Fitness Starter',
        description: 'Completed 10 workouts',
        emoji: '💪',
        points: 200,
        type: RewardType.milestone,
        category: BadgeCategory.exercise,
        color: Colors.red,
      ),
      const UserReward(
        id: 'exercise_100',
        title: 'Iron Body',
        description: 'Completed 100 workouts',
        emoji: '🏋️‍♂️',
        points: 1000,
        type: RewardType.milestone,
        category: BadgeCategory.exercise,
        color: const Color(0xFFD32F2F),
      ),
      const UserReward(
        id: 'exercise_500',
        title: 'Titan',
        description: 'Completed 500 workouts',
        emoji: '⚡',
        points: 3000,
        type: RewardType.milestone,
        category: BadgeCategory.exercise,
        color: Colors.orange,
      ),

      // Steps Milestones
      const UserReward(
        id: 'steps_10000',
        title: 'Step Rookie',
        description: 'Walked 10,000 steps',
        emoji: '🚶‍♂️',
        points: 50,
        type: RewardType.milestone,
        category: BadgeCategory.steps,
        color: Colors.green,
      ),
      const UserReward(
        id: 'steps_100000',
        title: 'Step Hero',
        description: 'Walked 100,000 steps',
        emoji: '🏃‍♂️',
        points: 300,
        type: RewardType.milestone,
        category: BadgeCategory.steps,
        color: Colors.blue,
      ),
      const UserReward(
        id: 'steps_1000000',
        title: 'Marathoner',
        description: 'Walked 1,000,000 steps',
        emoji: '🏃‍♀️',
        points: 1000,
        type: RewardType.milestone,
        category: BadgeCategory.steps,
        color: Colors.purple,
      ),

      // ===== SPECIAL ACHIEVEMENTS =====
      const UserReward(
        id: 'first_meal',
        title: 'First Bite',
        description: 'Logged your first meal',
        emoji: '👶',
        points: 50,
        type: RewardType.special,
        category: BadgeCategory.logging,
        color: Colors.green,
      ),
      const UserReward(
        id: 'perfect_week',
        title: 'Perfect Week',
        description: 'Hit all daily goals for 7 consecutive days',
        emoji: '⭐',
        points: 500,
        type: RewardType.special,
        category: BadgeCategory.achievement,
        color: Colors.amber,
      ),
      const UserReward(
        id: 'nutrition_master',
        title: 'Nutrition Master',
        description: 'Perfect nutrition for 7 days',
        emoji: '🥗',
        points: 300,
        type: RewardType.special,
        category: BadgeCategory.nutrition,
        color: Colors.green,
      ),
      const UserReward(
        id: 'calorie_burner',
        title: 'Calorie Burner',
        description: 'Burned 1000+ calories in workouts',
        emoji: '🔥',
        points: 200,
        type: RewardType.special,
        category: BadgeCategory.exercise,
        color: Colors.red,
      ),
      const UserReward(
        id: 'hot_streak',
        title: 'Hot Streak',
        description: '100 days of any streak',
        emoji: '🔥',
        points: 1000,
        type: RewardType.special,
        category: BadgeCategory.consistency,
        color: Colors.orange,
      ),
      const UserReward(
        id: 'year_hero',
        title: 'Year Hero',
        description: 'Logged at least one activity every day for a year',
        emoji: '🌍',
        points: 5000,
        type: RewardType.special,
        category: BadgeCategory.achievement,
        color: Colors.cyan,
      ),
      const UserReward(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Logged breakfast before 8 AM for 7 days',
        emoji: '🌅',
        points: 150,
        type: RewardType.special,
        category: BadgeCategory.logging,
        color: Colors.orange,
      ),
      const UserReward(
        id: 'night_owl_restraint',
        title: 'Night Owl Restraint',
        description: 'No late-night snacks for 7 days',
        emoji: '🦉',
        points: 200,
        type: RewardType.special,
        category: BadgeCategory.nutrition,
        color: Colors.deepPurple,
      ),
      const UserReward(
        id: 'consistency_king',
        title: 'Consistency King',
        description: '30-day app usage streak',
        emoji: '👑',
        points: 1000,
        type: RewardType.special,
        category: BadgeCategory.consistency,
        color: Colors.purple,
      ),
      const UserReward(
        id: 'yearly_meal_tracker',
        title: 'Yearly Meal Tracker',
        description: 'Logged 500 meals in a year',
        emoji: '🗓️',
        points: 2000,
        type: RewardType.special,
        category: BadgeCategory.logging,
        color: Colors.indigo,
      ),

      // ===== CHALLENGE REWARDS =====
      const UserReward(
        id: 'daily_challenge_winner',
        title: 'Daily Champion',
        description: 'Completed daily challenge',
        emoji: '🏅',
        points: 100,
        type: RewardType.challenge,
        category: BadgeCategory.achievement,
        color: Colors.amber,
      ),
      const UserReward(
        id: 'weekly_challenge_winner',
        title: 'Weekly Warrior',
        description: 'Completed weekly challenge',
        emoji: '🥇',
        points: 500,
        type: RewardType.challenge,
        category: BadgeCategory.achievement,
        color: Colors.amber,
      ),
      const UserReward(
        id: 'monthly_challenge_winner',
        title: 'Monthly Master',
        description: 'Completed monthly challenge',
        emoji: '🏆',
        points: 2000,
        type: RewardType.challenge,
        category: BadgeCategory.achievement,
        color: Colors.purple,
      ),
    ];
  }

  static UserLevel getCurrentLevel(int points) {
    for (int i = UserLevel.values.length - 1; i >= 0; i--) {
      if (points >= UserLevel.values[i].requiredPoints) {
        return UserLevel.values[i];
      }
    }
    return UserLevel.beginner;
  }

  static UserLevel getNextLevel(UserLevel currentLevel) {
    final currentIndex = UserLevel.values.indexOf(currentLevel);
    if (currentIndex < UserLevel.values.length - 1) {
      return UserLevel.values[currentIndex + 1];
    }
    return currentLevel; // Already at max level
  }

  static int getPointsToNextLevel(int currentPoints, UserLevel currentLevel) {
    final nextLevel = getNextLevel(currentLevel);
    if (nextLevel == currentLevel) return 0;
    return nextLevel.requiredPoints - currentPoints;
  }

  static double getLevelProgress(int currentPoints, UserLevel currentLevel) {
    final nextLevel = getNextLevel(currentLevel);
    if (nextLevel == currentLevel) return 1.0;
    
    final levelRange = nextLevel.requiredPoints - currentLevel.requiredPoints;
    final currentProgress = currentPoints - currentLevel.requiredPoints;
    
    return (currentProgress / levelRange).clamp(0.0, 1.0);
  }

  /// Calculate XP based on activity type and data
  static int calculateXp({
    required ActivityType activityType,
    required Map<String, dynamic> activityData,
    int streakDays = 0,
  }) {
    int baseXp = 0;
    
    switch (activityType) {
      case ActivityType.mealLogging:
        baseXp = 10; // +10 XP per meal
        break;
      case ActivityType.exercise:
        baseXp = 20; // +20 XP per workout
        break;
      case ActivityType.calorieGoal:
        baseXp = 20; // +20 XP for meeting calorie goal
        break;
      case ActivityType.steps:
        final steps = activityData['steps'] as int? ?? 0;
        baseXp = (steps / 1000).floor() * 5; // +5 XP per 1000 steps
        break;
      case ActivityType.weightCheckIn:
        baseXp = 15; // +15 XP per weight log
        break;
      case ActivityType.meditation:
        baseXp = 15; // +15 XP per meditation session
        break;
      case ActivityType.dailyGoalCompletion:
        baseXp = 50; // +50 XP for completing all daily goals
        break;
    }
    
    // Apply streak multiplier
    double multiplier = _getStreakMultiplier(streakDays);
    return (baseXp * multiplier).round();
  }

  /// Get streak multiplier based on streak days
  static double _getStreakMultiplier(int streakDays) {
    if (streakDays >= 365) return 2.0; // +100% XP
    if (streakDays >= 100) return 1.5; // +50% XP
    if (streakDays >= 30) return 1.2; // +20% XP
    if (streakDays >= 7) return 1.1; // +10% XP
    return 1.0;
  }

  /// Calculate points to next level using the formula: currentLevel * 100
  static int calculatePointsToNextLevel(int currentLevel, int currentPoints) {
    final nextLevelPoints = (currentLevel + 1) * 100;
    return nextLevelPoints - currentPoints;
  }

  /// Get level from total points using the formula
  static int getLevelFromPoints(int totalPoints) {
    // Using quadratic formula: level * 100 = totalPoints
    // So level = sqrt(totalPoints / 100)
    return (sqrt(totalPoints / 100)).floor();
  }

  static List<UserReward> checkForNewRewards(
    UserProgress currentProgress,
    int newPoints,
    Map<String, dynamic> activityData,
  ) {
    List<UserReward> newRewards = [];
    final allRewards = getAllRewards();
    
    // Check each reward condition
    for (final reward in allRewards) {
      if (currentProgress.unlockedRewards.any((r) => r.id == reward.id)) {
        continue; // Already unlocked
      }
      
      bool shouldUnlock = false;
      
      switch (reward.id) {
        case 'first_log':
          shouldUnlock = activityData['mealsLogged'] != null && activityData['mealsLogged'] >= 1;
          break;
        case 'water_warrior':
          shouldUnlock = activityData['waterGlasses'] != null && activityData['waterGlasses'] >= 8;
          break;
        case 'calorie_tracker':
          shouldUnlock = activityData['metCalorieGoal'] == true;
          break;
        case 'week_warrior':
          shouldUnlock = currentProgress.currentStreak >= 7;
          break;
        case 'hundred_club':
          shouldUnlock = activityData['totalMealsLogged'] != null && activityData['totalMealsLogged'] >= 100;
          break;
        // Add more conditions as needed
      }
      
      if (shouldUnlock) {
        newRewards.add(reward.copyWith(
          isUnlocked: true,
          earnedAt: DateTime.now(),
        ));
      }
    }
    
    return newRewards;
  }
}
