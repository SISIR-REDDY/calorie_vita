import 'package:flutter/material.dart';
import '../ui/app_colors.dart';

/// Model for user achievements and rewards
class UserAchievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final Color color;
  final int points;
  final AchievementType type;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final Map<String, dynamic> requirements;

  UserAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.points,
    required this.type,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.requirements,
  });

  /// Get achievement rarity color
  String get rarityColor {
    switch (type) {
      case AchievementType.bronze:
        return '#CD7F32'; // Bronze
      case AchievementType.silver:
        return '#C0C0C0'; // Silver
      case AchievementType.gold:
        return '#FFD700'; // Gold
      case AchievementType.platinum:
        return '#E5E4E2'; // Platinum
      case AchievementType.diamond:
        return '#B9F2FF'; // Diamond
    }
  }

  /// Get achievement rarity name
  String get rarityName {
    switch (type) {
      case AchievementType.bronze:
        return 'Bronze';
      case AchievementType.silver:
        return 'Silver';
      case AchievementType.gold:
        return 'Gold';
      case AchievementType.platinum:
        return 'Platinum';
      case AchievementType.diamond:
        return 'Diamond';
    }
  }

  /// Copy with new values
  UserAchievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    Color? color,
    int? points,
    AchievementType? type,
    bool? isUnlocked,
    DateTime? unlockedAt,
    Map<String, dynamic>? requirements,
  }) {
    return UserAchievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      points: points ?? this.points,
      type: type ?? this.type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      requirements: requirements ?? this.requirements,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'color': color.value,
      'points': points,
      'type': type.index,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.millisecondsSinceEpoch,
      'requirements': requirements,
    };
  }

  /// Create from JSON
  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '🏆',
      color: Color(json['color'] ?? 0xFF6366F1),
      points: json['points'] ?? 0,
      type: AchievementType.values[json['type'] ?? 0],
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['unlockedAt'])
          : null,
      requirements: Map<String, dynamic>.from(json['requirements'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'UserAchievement(id: $id, title: $title, isUnlocked: $isUnlocked)';
  }
}

/// Achievement types with different rarities
enum AchievementType {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

/// Predefined achievements
class Achievements {
  static final List<UserAchievement> defaultAchievements = [
    // Streak achievements
    UserAchievement(
      id: 'streak_3',
      title: 'Getting Started',
      description: 'Log meals for 3 consecutive days',
      icon: '🔥',
      color: kAccentColor,
      points: 50,
      type: AchievementType.bronze,
      requirements: {'streak_days': 3},
    ),
    UserAchievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: 'Log meals for 7 consecutive days',
      icon: '🔥',
      color: kAccentColor,
      points: 150,
      type: AchievementType.silver,
      requirements: {'streak_days': 7},
    ),
    UserAchievement(
      id: 'streak_30',
      title: 'Month Master',
      description: 'Log meals for 30 consecutive days',
      icon: '🔥',
      color: kAccentColor,
      points: 500,
      type: AchievementType.gold,
      requirements: {'streak_days': 30},
    ),
    UserAchievement(
      id: 'streak_100',
      title: 'Century Champion',
      description: 'Log meals for 100 consecutive days',
      icon: '🔥',
      color: kAccentColor,
      points: 1000,
      type: AchievementType.platinum,
      requirements: {'streak_days': 100},
    ),

    // Calorie achievements
    UserAchievement(
      id: 'calorie_goal_7',
      title: 'Goal Getter',
      description: 'Meet your calorie goal for 7 days',
      icon: '🎯',
      color: kSuccessColor,
      points: 100,
      type: AchievementType.silver,
      requirements: {'calorie_goal_days': 7},
    ),
    UserAchievement(
      id: 'calorie_goal_30',
      title: 'Goal Guardian',
      description: 'Meet your calorie goal for 30 days',
      icon: '🎯',
      color: kSuccessColor,
      points: 400,
      type: AchievementType.gold,
      requirements: {'calorie_goal_days': 30},
    ),

    // Water achievements
    UserAchievement(
      id: 'water_7',
      title: 'Hydration Hero',
      description: 'Drink enough water for 7 days',
      icon: '💧',
      color: kInfoColor,
      points: 75,
      type: AchievementType.bronze,
      requirements: {'water_goal_days': 7},
    ),

    // Exercise achievements
    UserAchievement(
      id: 'exercise_7',
      title: 'Fitness Fanatic',
      description: 'Log workouts for 7 days',
      icon: '💪',
      color: kSecondaryColor,
      points: 200,
      type: AchievementType.silver,
      requirements: {'exercise_days': 7},
    ),

    // Special achievements
    UserAchievement(
      id: 'perfect_week',
      title: 'Perfect Week',
      description: 'Meet all goals (calories, water, exercise) for 7 days',
      icon: '⭐',
      color: kAccentGold,
      points: 300,
      type: AchievementType.gold,
      requirements: {'perfect_days': 7},
    ),
    UserAchievement(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Log breakfast before 8 AM for 7 days',
      icon: '🌅',
      color: kAccentColor,
      points: 100,
      type: AchievementType.bronze,
      requirements: {'early_breakfast_days': 7},
    ),
  ];

  /// Get achievement by ID
  static UserAchievement? getById(String id) {
    try {
      return defaultAchievements.firstWhere((achievement) => achievement.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get achievements by type
  static List<UserAchievement> getByType(AchievementType type) {
    return defaultAchievements.where((achievement) => achievement.type == type).toList();
  }

  /// Get unlocked achievements
  static List<UserAchievement> getUnlocked(List<UserAchievement> userAchievements) {
    return userAchievements.where((achievement) => achievement.isUnlocked).toList();
  }

  /// Get total points from unlocked achievements
  static int getTotalPoints(List<UserAchievement> userAchievements) {
    return userAchievements
        .where((achievement) => achievement.isUnlocked)
        .fold(0, (sum, achievement) => sum + achievement.points);
  }
}