class CaloriesModel {
  final DateTime date;
  final double activeCalories;

  CaloriesModel({
    required this.date,
    required this.activeCalories,
  });

  factory CaloriesModel.fromJson(Map<String, dynamic> json) {
    return CaloriesModel(
      date: DateTime.parse(json['date'] as String),
      activeCalories: (json['activeCalories'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'activeCalories': activeCalories,
    };
  }

  CaloriesModel copyWith({
    DateTime? date,
    double? activeCalories,
  }) {
    return CaloriesModel(
      date: date ?? this.date,
      activeCalories: activeCalories ?? this.activeCalories,
    );
  }

  @override
  String toString() =>
      'CaloriesModel(date: $date, activeCalories: $activeCalories)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CaloriesModel &&
        other.date == date &&
        other.activeCalories == activeCalories;
  }

  @override
  int get hashCode => date.hashCode ^ activeCalories.hashCode;
}

