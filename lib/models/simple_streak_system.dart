/// Simple streak system models for tracking user progress and goals

/// Enum for different types of daily goals
enum DailyGoalType {
  calorieGoal,
  waterIntake,
  exercise,
  sleep,
  weightTracking,
}

extension DailyGoalTypeExtension on DailyGoalType {
  String get displayName {
    switch (this) {
      case DailyGoalType.calorieGoal:
        return 'Calorie Goal';
      case DailyGoalType.waterIntake:
        return 'Water Intake';
      case DailyGoalType.exercise:
        return 'Exercise';
      case DailyGoalType.sleep:
        return 'Sleep';
      case DailyGoalType.weightTracking:
        return 'Weight Tracking';
    }
  }
}

/// Represents a streak for a specific goal type
class GoalStreak {
  final DailyGoalType goalType;
  final int currentStreak;
  final int longestStreak;
  final bool achievedToday;
  final DateTime lastAchievedDate;
  final DateTime streakStartDate;
  final int totalDaysAchieved;

  const GoalStreak({
    required this.goalType,
    required this.currentStreak,
    required this.longestStreak,
    required this.achievedToday,
    required this.lastAchievedDate,
    required this.streakStartDate,
    required this.totalDaysAchieved,
  });

  factory GoalStreak.empty(DailyGoalType goalType) {
    final now = DateTime.now();
    return GoalStreak(
      goalType: goalType,
      currentStreak: 0,
      longestStreak: 0,
      achievedToday: false,
      lastAchievedDate: now,
      streakStartDate: now,
      totalDaysAchieved: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalType': goalType.name,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'achievedToday': achievedToday,
      'lastAchievedDate': lastAchievedDate.toIso8601String(),
      'streakStartDate': streakStartDate.toIso8601String(),
      'totalDaysAchieved': totalDaysAchieved,
    };
  }

  factory GoalStreak.fromMap(Map<String, dynamic> map) {
    return GoalStreak(
      goalType: DailyGoalType.values.firstWhere(
        (e) => e.name == map['goalType'],
        orElse: () => DailyGoalType.calorieGoal,
      ),
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      achievedToday: map['achievedToday'] ?? false,
      lastAchievedDate: DateTime.parse(map['lastAchievedDate'] ?? DateTime.now().toIso8601String()),
      streakStartDate: DateTime.parse(map['streakStartDate'] ?? DateTime.now().toIso8601String()),
      totalDaysAchieved: map['totalDaysAchieved'] ?? 0,
    );
  }

  GoalStreak copyWith({
    DailyGoalType? goalType,
    int? currentStreak,
    int? longestStreak,
    bool? achievedToday,
    DateTime? lastAchievedDate,
    DateTime? streakStartDate,
    int? totalDaysAchieved,
  }) {
    return GoalStreak(
      goalType: goalType ?? this.goalType,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      achievedToday: achievedToday ?? this.achievedToday,
      lastAchievedDate: lastAchievedDate ?? this.lastAchievedDate,
      streakStartDate: streakStartDate ?? this.streakStartDate,
      totalDaysAchieved: totalDaysAchieved ?? this.totalDaysAchieved,
    );
  }
}

/// Summary of all user streaks
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

  factory UserStreakSummary.empty() {
    final goalStreaks = <DailyGoalType, GoalStreak>{};
    for (final goalType in DailyGoalType.values) {
      goalStreaks[goalType] = GoalStreak.empty(goalType);
    }
    
    return UserStreakSummary(
      goalStreaks: goalStreaks,
      totalActiveStreaks: 0,
      longestOverallStreak: 0,
      lastActivityDate: DateTime.now(),
      totalDaysActive: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalStreaks': goalStreaks.map((key, value) => MapEntry(key.name, value.toMap())),
      'totalActiveStreaks': totalActiveStreaks,
      'longestOverallStreak': longestOverallStreak,
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'totalDaysActive': totalDaysActive,
    };
  }

  factory UserStreakSummary.fromMap(Map<String, dynamic> map) {
    final goalStreaksMap = Map<String, dynamic>.from(map['goalStreaks'] ?? {});
    final goalStreaks = <DailyGoalType, GoalStreak>{};
    
    for (final entry in goalStreaksMap.entries) {
      final goalType = DailyGoalType.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => DailyGoalType.calorieGoal,
      );
      goalStreaks[goalType] = GoalStreak.fromMap(Map<String, dynamic>.from(entry.value));
    }

    return UserStreakSummary(
      goalStreaks: goalStreaks,
      totalActiveStreaks: map['totalActiveStreaks'] ?? 0,
      longestOverallStreak: map['longestOverallStreak'] ?? 0,
      lastActivityDate: DateTime.parse(map['lastActivityDate'] ?? DateTime.now().toIso8601String()),
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
