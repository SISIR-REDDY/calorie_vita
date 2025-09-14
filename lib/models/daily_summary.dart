import 'macro_breakdown.dart';

/// Model for daily calorie and activity summary
class DailySummary {
  final int caloriesConsumed;
  final int caloriesBurned;
  final int caloriesGoal;
  final int steps;
  final int stepsGoal;
  final int waterGlasses;
  final int waterGlassesGoal;
  final DateTime date;
  final MacroBreakdown _macroBreakdown;

  DailySummary({
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.caloriesGoal,
    required this.steps,
    required this.stepsGoal,
    required this.waterGlasses,
    required this.waterGlassesGoal,
    required this.date,
    MacroBreakdown? macroBreakdown,
  }) : _macroBreakdown = macroBreakdown ??
            MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);

  /// Calculate remaining calories
  int get caloriesRemaining => caloriesGoal - caloriesConsumed + caloriesBurned;

  /// Calculate calorie progress percentage
  double get calorieProgress =>
      (caloriesConsumed / caloriesGoal).clamp(0.0, 1.0);

  /// Calculate steps progress percentage
  double get stepsProgress => (steps / stepsGoal).clamp(0.0, 1.0);

  /// Calculate water glasses progress percentage
  double get waterGlassesProgress =>
      (waterGlasses / waterGlassesGoal).clamp(0.0, 1.0);

  /// Check if daily goal is achieved
  bool get isGoalAchieved => caloriesConsumed >= caloriesGoal;

  /// Get overall progress score (0-100)
  double get overallProgress {
    final progress = (stepsProgress + waterGlassesProgress) / 2;
    return (progress * 100).clamp(0.0, 100.0);
  }

  /// Get macro breakdown for this day (calculated from actual food entries)
  MacroBreakdown get macroBreakdown => _macroBreakdown;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'caloriesConsumed': caloriesConsumed,
      'caloriesBurned': caloriesBurned,
      'caloriesGoal': caloriesGoal,
      'steps': steps,
      'stepsGoal': stepsGoal,
      'waterGlasses': waterGlasses,
      'waterGlassesGoal': waterGlassesGoal,
      'date': date.millisecondsSinceEpoch,
    };
  }

  /// Convert to Map (alias for toJson)
  Map<String, dynamic> toMap() => toJson();

  /// Create from JSON
  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      caloriesConsumed: json['caloriesConsumed'] ?? 0,
      caloriesBurned: json['caloriesBurned'] ?? 0,
      caloriesGoal: json['caloriesGoal'] ?? 2000,
      steps: json['steps'] ?? 0,
      stepsGoal: json['stepsGoal'] ?? 10000,
      waterGlasses: json['waterGlasses'] ?? 0,
      waterGlassesGoal: json['waterGlassesGoal'] ?? 8,
      date: DateTime.fromMillisecondsSinceEpoch(
          json['date'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  /// Create from Map (alias for fromJson)
  factory DailySummary.fromMap(Map<String, dynamic> map) =>
      DailySummary.fromJson(map);

  /// Copy with new values
  DailySummary copyWith({
    int? caloriesConsumed,
    int? caloriesBurned,
    int? caloriesGoal,
    int? steps,
    int? stepsGoal,
    int? waterGlasses,
    int? waterGlassesGoal,
    DateTime? date,
    MacroBreakdown? macroBreakdown,
  }) {
    return DailySummary(
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      caloriesGoal: caloriesGoal ?? this.caloriesGoal,
      steps: steps ?? this.steps,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      waterGlasses: waterGlasses ?? this.waterGlasses,
      waterGlassesGoal: waterGlassesGoal ?? this.waterGlassesGoal,
      date: date ?? this.date,
      macroBreakdown: macroBreakdown ?? _macroBreakdown,
    );
  }
}
