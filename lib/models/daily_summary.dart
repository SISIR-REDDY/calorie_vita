import 'macro_breakdown.dart';

/// Model for daily calorie and activity summary
class DailySummary {
  final int caloriesConsumed;
  final int caloriesBurned;
  final int caloriesGoal;
  final int waterIntake;
  final int waterGoal;
  final int steps;
  final int stepsGoal;
  final double sleepHours;
  final double sleepGoal;
  final DateTime date;

  DailySummary({
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.caloriesGoal,
    required this.waterIntake,
    required this.waterGoal,
    required this.steps,
    required this.stepsGoal,
    required this.sleepHours,
    required this.sleepGoal,
    required this.date,
  });

  /// Calculate remaining calories
  int get caloriesRemaining => caloriesGoal - caloriesConsumed + caloriesBurned;

  /// Calculate calorie progress percentage
  double get calorieProgress => (caloriesConsumed / caloriesGoal).clamp(0.0, 1.0);

  /// Calculate water progress percentage
  double get waterProgress => (waterIntake / waterGoal).clamp(0.0, 1.0);

  /// Calculate steps progress percentage
  double get stepsProgress => (steps / stepsGoal).clamp(0.0, 1.0);

  /// Calculate sleep progress percentage
  double get sleepProgress => (sleepHours / sleepGoal).clamp(0.0, 1.0);

  /// Check if daily goal is achieved
  bool get isGoalAchieved => caloriesConsumed >= caloriesGoal;

  /// Get overall progress score (0-100)
  double get overallProgress {
    final progress = (calorieProgress + waterProgress + stepsProgress + sleepProgress) / 4;
    return (progress * 100).clamp(0.0, 100.0);
  }

  /// Get macro breakdown for this day (placeholder - should be calculated from food entries)
  MacroBreakdown get macroBreakdown {
    // This should be calculated from actual food entries for this day
    // For now, return a default breakdown
    return MacroBreakdown(
      carbs: 250,
      protein: 120,
      fat: 80,
      fiber: 25,
      sugar: 45,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'caloriesConsumed': caloriesConsumed,
      'caloriesBurned': caloriesBurned,
      'caloriesGoal': caloriesGoal,
      'waterIntake': waterIntake,
      'waterGoal': waterGoal,
      'steps': steps,
      'stepsGoal': stepsGoal,
      'sleepHours': sleepHours,
      'sleepGoal': sleepGoal,
      'date': date.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      caloriesConsumed: json['caloriesConsumed'] ?? 0,
      caloriesBurned: json['caloriesBurned'] ?? 0,
      caloriesGoal: json['caloriesGoal'] ?? 2000,
      waterIntake: json['waterIntake'] ?? 0,
      waterGoal: json['waterGoal'] ?? 8,
      steps: json['steps'] ?? 0,
      stepsGoal: json['stepsGoal'] ?? 10000,
      sleepHours: (json['sleepHours'] ?? 0.0).toDouble(),
      sleepGoal: (json['sleepGoal'] ?? 8.0).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  /// Copy with new values
  DailySummary copyWith({
    int? caloriesConsumed,
    int? caloriesBurned,
    int? caloriesGoal,
    int? waterIntake,
    int? waterGoal,
    int? steps,
    int? stepsGoal,
    double? sleepHours,
    double? sleepGoal,
    DateTime? date,
  }) {
    return DailySummary(
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      caloriesGoal: caloriesGoal ?? this.caloriesGoal,
      waterIntake: waterIntake ?? this.waterIntake,
      waterGoal: waterGoal ?? this.waterGoal,
      steps: steps ?? this.steps,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepGoal: sleepGoal ?? this.sleepGoal,
      date: date ?? this.date,
    );
  }
}
