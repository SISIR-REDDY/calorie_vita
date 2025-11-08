import 'workout_model.dart';

class HealthDataModel {
  final int steps;
  final double calories;
  final List<WorkoutModel> workouts;
  final List<int> heartRate;
  final DateTime lastUpdated;

  HealthDataModel({
    required this.steps,
    required this.calories,
    required this.workouts,
    required this.heartRate,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory HealthDataModel.empty() {
    return HealthDataModel(
      steps: 0,
      calories: 0.0,
      workouts: [],
      heartRate: [],
    );
  }

  factory HealthDataModel.fromJson(Map<String, dynamic> json) {
    return HealthDataModel(
      steps: json['steps'] as int,
      calories: (json['calories'] as num).toDouble(),
      workouts: (json['workouts'] as List<dynamic>)
          .map((e) => WorkoutModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      heartRate: (json['heartRate'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps,
      'calories': calories,
      'workouts': workouts.map((e) => e.toJson()).toList(),
      'heartRate': heartRate,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  HealthDataModel copyWith({
    int? steps,
    double? calories,
    List<WorkoutModel>? workouts,
    List<int>? heartRate,
    DateTime? lastUpdated,
  }) {
    return HealthDataModel(
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      workouts: workouts ?? this.workouts,
      heartRate: heartRate ?? this.heartRate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() =>
      'HealthDataModel(steps: $steps, calories: $calories, workouts: ${workouts.length}, heartRate: ${heartRate.length}, lastUpdated: $lastUpdated)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HealthDataModel &&
        other.steps == steps &&
        other.calories == calories &&
        _listEquals(other.workouts, workouts) &&
        _listEquals(other.heartRate, heartRate) &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode =>
      steps.hashCode ^
      calories.hashCode ^
      workouts.hashCode ^
      heartRate.hashCode ^
      lastUpdated.hashCode;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

