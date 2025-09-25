/// Model class for Google Fit fitness data - Optimized for steps and calories only
class GoogleFitData {
  final DateTime date;
  final int? steps;
  final double? caloriesBurned;
  final int? workoutSessions; // Number of workout sessions detected
  final double? workoutDuration; // Total workout duration in minutes

  const GoogleFitData({
    required this.date,
    this.steps,
    this.caloriesBurned,
    this.workoutSessions,
    this.workoutDuration,
  });

  /// Create GoogleFitData from JSON
  factory GoogleFitData.fromJson(Map<String, dynamic> json) {
    return GoogleFitData(
      date: DateTime.parse(json['date']),
      steps: json['steps'] as int?,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble(),
      workoutSessions: json['workoutSessions'] as int?,
      workoutDuration: (json['workoutDuration'] as num?)?.toDouble(),
    );
  }

  /// Convert GoogleFitData to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'workoutSessions': workoutSessions,
      'workoutDuration': workoutDuration,
    };
  }

  /// Create a copy with updated fields
  GoogleFitData copyWith({
    DateTime? date,
    int? steps,
    double? caloriesBurned,
    int? workoutSessions,
    double? workoutDuration,
  }) {
    return GoogleFitData(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      workoutSessions: workoutSessions ?? this.workoutSessions,
      workoutDuration: workoutDuration ?? this.workoutDuration,
    );
  }

  /// Get formatted steps count
  String get formattedSteps {
    if (steps == null) return 'N/A';
    if (steps! >= 1000000) {
      return '${(steps! / 1000000).toStringAsFixed(1)}M';
    } else if (steps! >= 1000) {
      return '${(steps! / 1000).toStringAsFixed(1)}K';
    }
    return steps.toString();
  }

  /// Get formatted calories burned
  String get formattedCalories {
    if (caloriesBurned == null) return 'N/A';
    return '${caloriesBurned!.toStringAsFixed(0)} cal';
  }

  /// Get formatted workout sessions
  String get formattedWorkoutSessions {
    if (workoutSessions == null) return 'N/A';
    return '${workoutSessions} sessions';
  }

  /// Get formatted workout duration
  String get formattedWorkoutDuration {
    if (workoutDuration == null) return 'N/A';
    if (workoutDuration! >= 60) {
      final hours = (workoutDuration! / 60).floor();
      final minutes = (workoutDuration! % 60).round();
      return '${hours}h ${minutes}m';
    }
    return '${workoutDuration!.toStringAsFixed(0)}m';
  }

  /// Check if data is complete (has at least steps or calories)
  bool get hasData => steps != null || caloriesBurned != null;

  /// Get activity level based on steps
  String get activityLevel {
    if (steps == null) return 'Unknown';

    if (steps! < 5000) return 'Low';
    if (steps! < 10000) return 'Moderate';
    if (steps! < 15000) return 'Active';
    return 'Very Active';
  }

  @override
  String toString() {
    return 'GoogleFitData(date: $date, steps: $steps, caloriesBurned: $caloriesBurned, workoutSessions: $workoutSessions, workoutDuration: $workoutDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GoogleFitData &&
        other.date == date &&
        other.steps == steps &&
        other.caloriesBurned == caloriesBurned &&
        other.workoutSessions == workoutSessions &&
        other.workoutDuration == workoutDuration;
  }

  @override
  int get hashCode {
    return date.hashCode ^
        steps.hashCode ^
        caloriesBurned.hashCode ^
        workoutSessions.hashCode ^
        workoutDuration.hashCode;
  }
}

/// Model for weekly fitness summary - Optimized for steps, calories, and workouts
class WeeklyFitnessSummary {
  final List<GoogleFitData> dailyData;
  final int totalSteps;
  final double totalCaloriesBurned;
  final int totalWorkoutSessions;
  final double totalWorkoutDuration;
  final double averageSteps;
  final double averageCalories;
  final double averageWorkoutSessions;
  final double averageWorkoutDuration;

  const WeeklyFitnessSummary({
    required this.dailyData,
    required this.totalSteps,
    required this.totalCaloriesBurned,
    required this.totalWorkoutSessions,
    required this.totalWorkoutDuration,
    required this.averageSteps,
    required this.averageCalories,
    required this.averageWorkoutSessions,
    required this.averageWorkoutDuration,
  });

  /// Create from list of daily data
  factory WeeklyFitnessSummary.fromDailyData(List<GoogleFitData> dailyData) {
    final validData = dailyData.where((data) => data.hasData).toList();

    if (validData.isEmpty) {
      return WeeklyFitnessSummary(
        dailyData: dailyData,
        totalSteps: 0,
        totalCaloriesBurned: 0,
        totalWorkoutSessions: 0,
        totalWorkoutDuration: 0,
        averageSteps: 0,
        averageCalories: 0,
        averageWorkoutSessions: 0,
        averageWorkoutDuration: 0,
      );
    }

    final totalSteps =
        validData.fold<int>(0, (sum, data) => sum + (data.steps ?? 0));
    final totalCalories = validData.fold<double>(
        0, (sum, data) => sum + (data.caloriesBurned ?? 0));
    final totalWorkouts = validData.fold<int>(
        0, (sum, data) => sum + (data.workoutSessions ?? 0));
    final totalDuration = validData.fold<double>(
        0, (sum, data) => sum + (data.workoutDuration ?? 0));

    final dataCount = validData.length;

    return WeeklyFitnessSummary(
      dailyData: dailyData,
      totalSteps: totalSteps,
      totalCaloriesBurned: totalCalories,
      totalWorkoutSessions: totalWorkouts,
      totalWorkoutDuration: totalDuration,
      averageSteps: totalSteps / dataCount,
      averageCalories: totalCalories / dataCount,
      averageWorkoutSessions: totalWorkouts / dataCount,
      averageWorkoutDuration: totalDuration / dataCount,
    );
  }

  /// Get formatted total steps
  String get formattedTotalSteps {
    if (totalSteps >= 1000000) {
      return '${(totalSteps / 1000000).toStringAsFixed(1)}M';
    } else if (totalSteps >= 1000) {
      return '${(totalSteps / 1000).toStringAsFixed(1)}K';
    }
    return totalSteps.toString();
  }

  /// Get formatted total calories
  String get formattedTotalCalories =>
      '${totalCaloriesBurned.toStringAsFixed(0)} cal';

  /// Get formatted total workout sessions
  String get formattedTotalWorkoutSessions => '$totalWorkoutSessions sessions';

  /// Get formatted total workout duration
  String get formattedTotalWorkoutDuration {
    if (totalWorkoutDuration >= 60) {
      final hours = (totalWorkoutDuration / 60).floor();
      final minutes = (totalWorkoutDuration % 60).round();
      return '${hours}h ${minutes}m';
    }
    return '${totalWorkoutDuration.toStringAsFixed(0)}m';
  }

  /// Get average activity level
  String get averageActivityLevel {
    if (averageSteps < 5000) return 'Low';
    if (averageSteps < 10000) return 'Moderate';
    if (averageSteps < 15000) return 'Active';
    return 'Very Active';
  }
}
