import 'package:flutter/material.dart';

/// Simple streak tracking system focused on daily goals and consistency
class SimpleStreakSystem {
  static const int maxStreakDays = 365;
  static const int streakMilestones = 7; // Show milestone every 7 days
}

/// Daily goal types that can be tracked
enum DailyGoalType {
  mealLogging('Meal Logging', '🍽️', Colors.green),
  exercise('Exercise', '🏃‍♂️', Colors.orange),
  steps('Steps', '👣', Colors.cyan),
  calorieGoal('Calorie Goal', '🔥', Colors.red);

  const DailyGoalType(this.displayName, this.emoji, this.color);
  
  final String displayName;
  final String emoji;
  final Color color;
}

/// Individual streak for a specific goal type
class GoalStreak {
  final DailyGoalType goalType;
  final int currentStreak;
  final int longestStreak;
  final DateTime lastAchievedDate;
  final bool achievedToday;
  final int totalDaysAchieved;

  const GoalStreak({
    required this.goalType,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastAchievedDate,
    required this.achievedToday,
    required this.totalDaysAchieved,
  });

  GoalStreak copyWith({
    DailyGoalType? goalType,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastAchievedDate,
    bool? achievedToday,
    int? totalDaysAchieved,
  }) {
    return GoalStreak(
      goalType: goalType ?? this.goalType,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastAchievedDate: lastAchievedDate ?? this.lastAchievedDate,
      achievedToday: achievedToday ?? this.achievedToday,
      totalDaysAchieved: totalDaysAchieved ?? this.totalDaysAchieved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalType': goalType.name,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastAchievedDate': lastAchievedDate.millisecondsSinceEpoch,
      'achievedToday': achievedToday,
      'totalDaysAchieved': totalDaysAchieved,
    };
  }

  factory GoalStreak.fromMap(Map<String, dynamic> map) {
    return GoalStreak(
      goalType: DailyGoalType.values.firstWhere(
        (e) => e.name == map['goalType'],
        orElse: () => DailyGoalType.mealLogging,
      ),
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      lastAchievedDate: DateTime.fromMillisecondsSinceEpoch(map['lastAchievedDate'] ?? 0),
      achievedToday: map['achievedToday'] ?? false,
      totalDaysAchieved: map['totalDaysAchieved'] ?? 0,
    );
  }

  /// Get streak status message
  String get statusMessage {
    if (achievedToday) {
      if (currentStreak == 1) {
        return 'Great start! Keep it up!';
      } else if (currentStreak < 7) {
        return 'Building momentum! Day $currentStreak';
      } else if (currentStreak < 30) {
        return 'On fire! $currentStreak day streak!';
      } else if (currentStreak < 100) {
        return 'Incredible! $currentStreak days strong!';
      } else {
        return 'Legendary! $currentStreak days!';
      }
    } else {
      if (currentStreak == 0) {
        return 'Start your streak today!';
      } else {
        return 'Continue your $currentStreak day streak!';
      }
    }
  }

  /// Get streak level based on current streak
  StreakLevel get streakLevel {
    if (currentStreak == 0) return StreakLevel.none;
    if (currentStreak < 3) return StreakLevel.starter;
    if (currentStreak < 7) return StreakLevel.building;
    if (currentStreak < 30) return StreakLevel.strong;
    if (currentStreak < 100) return StreakLevel.expert;
    return StreakLevel.legendary;
  }
}

/// Streak levels for visual representation
enum StreakLevel {
  none('None', Colors.grey, '🌱'),
  starter('Starter', Colors.blue, '🔰'),
  building('Building', Colors.green, '💪'),
  strong('Strong', Colors.orange, '🔥'),
  expert('Expert', Colors.purple, '🏆'),
  legendary('Legendary', Colors.amber, '⭐');

  const StreakLevel(this.name, this.color, this.emoji);
  
  final String name;
  final Color color;
  final String emoji;
}

/// Overall user streak summary
class UserStreakSummary {
  final Map<DailyGoalType, GoalStreak> goalStreaks;
  final int totalActiveStreaks;
  final int longestOverallStreak;
  final DateTime lastActivityDate;
  final int totalDaysActive;

  const UserStreakSummary({
    required this.goalStreaks,
    required this.totalActiveStreaks,
    required this.longestOverallStreak,
    required this.lastActivityDate,
    required this.totalDaysActive,
  });

  /// Get the most impressive streak
  GoalStreak? get mostImpressiveStreak {
    if (goalStreaks.isEmpty) return null;
    
    return goalStreaks.values.reduce((a, b) {
      if (a.currentStreak > b.currentStreak) return a;
      if (a.currentStreak == b.currentStreak && a.longestStreak > b.longestStreak) return a;
      return b;
    });
  }

  /// Get streaks that are currently active (achieved today)
  List<GoalStreak> get activeStreaks {
    return goalStreaks.values.where((streak) => streak.achievedToday).toList();
  }

  /// Get streaks that need attention (not achieved today but have a streak)
  List<GoalStreak> get streaksNeedingAttention {
    return goalStreaks.values.where((streak) => 
      !streak.achievedToday && streak.currentStreak > 0
    ).toList();
  }

  /// Get overall motivation message
  String get motivationMessage {
    final activeCount = activeStreaks.length;
    final totalCount = goalStreaks.length;
    
    if (activeCount == totalCount) {
      return 'Perfect day! All goals achieved! 🎉';
    } else if (activeCount > totalCount / 2) {
      return 'Great progress! Keep going! 💪';
    } else if (activeCount > 0) {
      return 'Good start! You can do more! 🌟';
    } else {
      return 'New day, new opportunities! Start fresh! 🌱';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'goalStreaks': goalStreaks.map((key, value) => MapEntry(key.name, value.toMap())),
      'totalActiveStreaks': totalActiveStreaks,
      'longestOverallStreak': longestOverallStreak,
      'lastActivityDate': lastActivityDate.millisecondsSinceEpoch,
      'totalDaysActive': totalDaysActive,
    };
  }

  factory UserStreakSummary.fromMap(Map<String, dynamic> map) {
    final goalStreaksMap = <DailyGoalType, GoalStreak>{};
    if (map['goalStreaks'] != null) {
      (map['goalStreaks'] as Map<String, dynamic>).forEach((key, value) {
        final goalType = DailyGoalType.values.firstWhere(
          (e) => e.name == key,
          orElse: () => DailyGoalType.mealLogging,
        );
        goalStreaksMap[goalType] = GoalStreak.fromMap(value);
      });
    }

    return UserStreakSummary(
      goalStreaks: goalStreaksMap,
      totalActiveStreaks: map['totalActiveStreaks'] ?? 0,
      longestOverallStreak: map['longestOverallStreak'] ?? 0,
      lastActivityDate: DateTime.fromMillisecondsSinceEpoch(map['lastActivityDate'] ?? 0),
      totalDaysActive: map['totalDaysActive'] ?? 0,
    );
  }

  UserStreakSummary copyWith({
    Map<DailyGoalType, GoalStreak>? goalStreaks,
    int? totalActiveStreaks,
    int? longestOverallStreak,
    DateTime? lastActivityDate,
    int? totalDaysActive,
  }) {
    return UserStreakSummary(
      goalStreaks: goalStreaks ?? this.goalStreaks,
      totalActiveStreaks: totalActiveStreaks ?? this.totalActiveStreaks,
      longestOverallStreak: longestOverallStreak ?? this.longestOverallStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      totalDaysActive: totalDaysActive ?? this.totalDaysActive,
    );
  }
}
