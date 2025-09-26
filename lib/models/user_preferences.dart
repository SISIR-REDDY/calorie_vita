enum CalorieUnit {
  kcal,
}

extension CalorieUnitExtension on CalorieUnit {
  String get displayName {
    switch (this) {
      case CalorieUnit.kcal:
        return 'kcal';
    }
  }

  String get fullName {
    switch (this) {
      case CalorieUnit.kcal:
        return 'Kilocalories';
    }
  }

  double convertFromKcal(double kcalValue) {
    switch (this) {
      case CalorieUnit.kcal:
        return kcalValue;
    }
  }

  double convertToKcal(double value) {
    switch (this) {
      case CalorieUnit.kcal:
        return value;
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
