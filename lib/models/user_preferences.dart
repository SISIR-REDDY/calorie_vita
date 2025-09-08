enum CalorieUnit {
  kcal,
  cal,
}

extension CalorieUnitExtension on CalorieUnit {
  String get displayName {
    switch (this) {
      case CalorieUnit.kcal:
        return 'kcal';
      case CalorieUnit.cal:
        return 'cal';
    }
  }

  String get fullName {
    switch (this) {
      case CalorieUnit.kcal:
        return 'Kilocalories';
      case CalorieUnit.cal:
        return 'Calories';
    }
  }

  double convertFromKcal(double kcalValue) {
    switch (this) {
      case CalorieUnit.kcal:
        return kcalValue;
      case CalorieUnit.cal:
        return kcalValue * 1000;
    }
  }

  double convertToKcal(double value) {
    switch (this) {
      case CalorieUnit.kcal:
        return value;
      case CalorieUnit.cal:
        return value / 1000;
    }
  }
}

class UserPreferences {
  final CalorieUnit calorieUnit;
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final DateTime? lastUpdated;

  const UserPreferences({
    this.calorieUnit = CalorieUnit.kcal,
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
    this.lastUpdated,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      calorieUnit: CalorieUnit.values.firstWhere(
        (unit) => unit.name == map['calorieUnit'],
        orElse: () => CalorieUnit.kcal,
      ),
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      darkModeEnabled: map['darkModeEnabled'] ?? false,
      lastUpdated: map['lastUpdated']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calorieUnit': calorieUnit.name,
      'notificationsEnabled': notificationsEnabled,
      'darkModeEnabled': darkModeEnabled,
      'lastUpdated': lastUpdated,
    };
  }

  UserPreferences copyWith({
    CalorieUnit? calorieUnit,
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    DateTime? lastUpdated,
  }) {
    return UserPreferences(
      calorieUnit: calorieUnit ?? this.calorieUnit,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}