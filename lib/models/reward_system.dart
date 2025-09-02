import 'package:flutter/material.dart';

// Reward System Enums
enum RewardType {
  daily,
  weekly,
  monthly,
  milestone,
  special,
}

enum BadgeCategory {
  logging,
  nutrition,
  exercise,
  water,
  consistency,
  achievement,
}

enum UserLevel {
  beginner('Beginner', 0, Colors.grey, '🌱'),
  rookie('Rookie', 500, Colors.blue, '🔰'),
  enthusiast('Enthusiast', 1500, Colors.green, '💪'),
  champion('Champion', 3000, Colors.orange, '🏆'),
  master('Master', 5000, Colors.purple, '👑'),
  legend('Legend', 10000, Colors.amber, '⭐');

  const UserLevel(this.title, this.requiredPoints, this.color, this.emoji);
  
  final String title;
  final int requiredPoints;
  final Color color;
  final String emoji;
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
      // Daily Rewards
      const UserReward(
        id: 'first_log',
        title: 'First Steps',
        description: 'Logged your first meal',
        emoji: '👶',
        points: 50,
        type: RewardType.daily,
        category: BadgeCategory.logging,
        color: Colors.green,
      ),
      const UserReward(
        id: 'water_warrior',
        title: 'Water Warrior',
        description: 'Drank 8 glasses of water',
        emoji: '💧',
        points: 25,
        type: RewardType.daily,
        category: BadgeCategory.water,
        color: Colors.blue,
      ),
      const UserReward(
        id: 'calorie_tracker',
        title: 'Calorie Tracker',
        description: 'Stayed within calorie goal',
        emoji: '🎯',
        points: 100,
        type: RewardType.daily,
        category: BadgeCategory.nutrition,
        color: Colors.orange,
      ),
      const UserReward(
        id: 'exercise_hero',
        title: 'Exercise Hero',
        description: 'Completed daily exercise',
        emoji: '🏃‍♂️',
        points: 75,
        type: RewardType.daily,
        category: BadgeCategory.exercise,
        color: Colors.red,
      ),

      // Weekly Rewards
      const UserReward(
        id: 'week_warrior',
        title: 'Week Warrior',
        description: '7-day logging streak',
        emoji: '🔥',
        points: 200,
        type: RewardType.weekly,
        category: BadgeCategory.consistency,
        color: Colors.deepOrange,
      ),
      const UserReward(
        id: 'nutrition_master',
        title: 'Nutrition Master',
        description: 'Perfect nutrition week',
        emoji: '🥗',
        points: 300,
        type: RewardType.weekly,
        category: BadgeCategory.nutrition,
        color: Colors.green,
      ),
      const UserReward(
        id: 'hydration_hero',
        title: 'Hydration Hero',
        description: 'Perfect water intake week',
        emoji: '🌊',
        points: 250,
        type: RewardType.weekly,
        category: BadgeCategory.water,
        color: Colors.cyan,
      ),

      // Monthly Rewards
      const UserReward(
        id: 'consistency_king',
        title: 'Consistency King',
        description: '30-day streak achievement',
        emoji: '👑',
        points: 1000,
        type: RewardType.monthly,
        category: BadgeCategory.consistency,
        color: Colors.purple,
      ),
      const UserReward(
        id: 'health_champion',
        title: 'Health Champion',
        description: 'Perfect month of healthy habits',
        emoji: '🏆',
        points: 1500,
        type: RewardType.monthly,
        category: BadgeCategory.achievement,
        color: Colors.amber,
      ),

      // Milestone Rewards
      const UserReward(
        id: 'hundred_club',
        title: 'Hundred Club',
        description: '100 meals logged',
        emoji: '💯',
        points: 500,
        type: RewardType.milestone,
        category: BadgeCategory.logging,
        color: Colors.indigo,
      ),
      const UserReward(
        id: 'marathon_runner',
        title: 'Marathon Runner',
        description: '1000 calories burned',
        emoji: '🏃‍♀️',
        points: 750,
        type: RewardType.milestone,
        category: BadgeCategory.exercise,
        color: Colors.red,
      ),
      const UserReward(
        id: 'water_champion',
        title: 'Water Champion',
        description: '500 glasses of water',
        emoji: '🥤',
        points: 400,
        type: RewardType.milestone,
        category: BadgeCategory.water,
        color: Colors.lightBlue,
      ),

      // Special Rewards
      const UserReward(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Logged breakfast 7 days in a row',
        emoji: '🌅',
        points: 150,
        type: RewardType.special,
        category: BadgeCategory.logging,
        color: Colors.orange,
      ),
      const UserReward(
        id: 'night_owl',
        title: 'Night Owl Restraint',
        description: 'No late night snacking for a week',
        emoji: '🦉',
        points: 200,
        type: RewardType.special,
        category: BadgeCategory.nutrition,
        color: Colors.deepPurple,
      ),
      const UserReward(
        id: 'social_butterfly',
        title: 'Social Butterfly',
        description: 'Shared progress 5 times',
        emoji: '🦋',
        points: 100,
        type: RewardType.special,
        category: BadgeCategory.achievement,
        color: Colors.pink,
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

  static int calculateDailyPoints({
    bool loggedMeals = false,
    bool metCalorieGoal = false,
    bool metWaterGoal = false,
    bool exercised = false,
    int streakBonus = 0,
  }) {
    int points = 0;
    
    if (loggedMeals) points += 25;
    if (metCalorieGoal) points += 50;
    if (metWaterGoal) points += 25;
    if (exercised) points += 40;
    
    // Streak bonus (5 points per day of streak)
    points += streakBonus * 5;
    
    return points;
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
