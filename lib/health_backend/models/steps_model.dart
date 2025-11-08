class StepsModel {
  final DateTime date;
  final int stepCount;

  StepsModel({
    required this.date,
    required this.stepCount,
  });

  factory StepsModel.fromJson(Map<String, dynamic> json) {
    return StepsModel(
      date: DateTime.parse(json['date'] as String),
      stepCount: json['stepCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'stepCount': stepCount,
    };
  }

  StepsModel copyWith({
    DateTime? date,
    int? stepCount,
  }) {
    return StepsModel(
      date: date ?? this.date,
      stepCount: stepCount ?? this.stepCount,
    );
  }

  @override
  String toString() => 'StepsModel(date: $date, stepCount: $stepCount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepsModel &&
        other.date == date &&
        other.stepCount == stepCount;
  }

  @override
  int get hashCode => date.hashCode ^ stepCount.hashCode;
}

