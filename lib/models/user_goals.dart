class UserGoals {
  final double? weightGoal;
  final int? calorieGoal;
  final double? bmiGoal;
  final int? waterGlassesGoal;
  final int? stepsPerDayGoal;
  final MacroGoals? macroGoals;
  final DateTime? lastUpdated;

  const UserGoals({
    this.weightGoal,
    this.calorieGoal,
    this.bmiGoal,
    this.waterGlassesGoal,
    this.stepsPerDayGoal,
    this.macroGoals,
    this.lastUpdated,
  });

  factory UserGoals.fromMap(Map<String, dynamic> map) {
    return UserGoals(
      weightGoal: map['weightGoal']?.toDouble(),
      calorieGoal: map['calorieGoal']?.toInt(),
      bmiGoal: map['bmiGoal']?.toDouble(),
      waterGlassesGoal: map['waterGlassesGoal']?.toInt(),
      stepsPerDayGoal: map['stepsPerDayGoal']?.toInt(),
      macroGoals: map['macroGoals'] != null
          ? MacroGoals.fromMap(map['macroGoals'])
          : null,
      lastUpdated: map['lastUpdated']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weightGoal': weightGoal,
      'calorieGoal': calorieGoal,
      'bmiGoal': bmiGoal,
      'waterGlassesGoal': waterGlassesGoal,
      'stepsPerDayGoal': stepsPerDayGoal,
      'macroGoals': macroGoals?.toMap(),
      'lastUpdated': lastUpdated,
    };
  }

  UserGoals copyWith({
    double? weightGoal,
    int? calorieGoal,
    double? bmiGoal,
    int? waterGlassesGoal,
    int? stepsPerDayGoal,
    MacroGoals? macroGoals,
    DateTime? lastUpdated,
  }) {
    return UserGoals(
      weightGoal: weightGoal ?? this.weightGoal,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      bmiGoal: bmiGoal ?? this.bmiGoal,
      waterGlassesGoal: waterGlassesGoal ?? this.waterGlassesGoal,
      stepsPerDayGoal: stepsPerDayGoal ?? this.stepsPerDayGoal,
      macroGoals: macroGoals ?? this.macroGoals,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class MacroGoals {
  final int? carbsCalories;
  final int? proteinCalories;
  final int? fatCalories;

  const MacroGoals({
    this.carbsCalories,
    this.proteinCalories,
    this.fatCalories,
  });

  factory MacroGoals.fromMap(Map<String, dynamic> map) {
    return MacroGoals(
      carbsCalories: map['carbsCalories']?.toInt(),
      proteinCalories: map['proteinCalories']?.toInt(),
      fatCalories: map['fatCalories']?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'carbsCalories': carbsCalories,
      'proteinCalories': proteinCalories,
      'fatCalories': fatCalories,
    };
  }

  MacroGoals copyWith({
    int? carbsCalories,
    int? proteinCalories,
    int? fatCalories,
  }) {
    return MacroGoals(
      carbsCalories: carbsCalories ?? this.carbsCalories,
      proteinCalories: proteinCalories ?? this.proteinCalories,
      fatCalories: fatCalories ?? this.fatCalories,
    );
  }

  // Default macro goals (balanced diet for 2000 calories)
  static const MacroGoals defaultMacros = MacroGoals(
    carbsCalories: 900, // 45% of 2000 calories
    proteinCalories: 500, // 25% of 2000 calories
    fatCalories: 600, // 30% of 2000 calories
  );
}
