class WorkoutModel {
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final double calories;

  WorkoutModel({
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.calories,
  });

  /// Duration in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  factory WorkoutModel.fromJson(Map<String, dynamic> json) {
    return WorkoutModel(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      type: json['type'] as String,
      calories: (json['calories'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type,
      'calories': calories,
    };
  }

  WorkoutModel copyWith({
    DateTime? startTime,
    DateTime? endTime,
    String? type,
    double? calories,
  }) {
    return WorkoutModel(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      calories: calories ?? this.calories,
    );
  }

  @override
  String toString() =>
      'WorkoutModel(startTime: $startTime, endTime: $endTime, type: $type, calories: $calories)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutModel &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.type == type &&
        other.calories == calories;
  }

  @override
  int get hashCode =>
      startTime.hashCode ^ endTime.hashCode ^ type.hashCode ^ calories.hashCode;
}

