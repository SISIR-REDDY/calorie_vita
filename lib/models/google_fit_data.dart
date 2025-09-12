/// Model class for Google Fit fitness data
class GoogleFitData {
  final DateTime date;
  final int? steps;
  final double? caloriesBurned;
  final double? distance; // in kilometers
  final double? weight; // in kilograms
  
  const GoogleFitData({
    required this.date,
    this.steps,
    this.caloriesBurned,
    this.distance,
    this.weight,
  });
  
  /// Create GoogleFitData from JSON
  factory GoogleFitData.fromJson(Map<String, dynamic> json) {
    return GoogleFitData(
      date: DateTime.parse(json['date']),
      steps: json['steps'] as int?,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }
  
  /// Convert GoogleFitData to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'distance': distance,
      'weight': weight,
    };
  }
  
  /// Create a copy with updated fields
  GoogleFitData copyWith({
    DateTime? date,
    int? steps,
    double? caloriesBurned,
    double? distance,
    double? weight,
  }) {
    return GoogleFitData(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distance: distance ?? this.distance,
      weight: weight ?? this.weight,
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
  
  /// Get formatted distance
  String get formattedDistance {
    if (distance == null) return 'N/A';
    return '${distance!.toStringAsFixed(2)} km';
  }
  
  /// Get formatted weight
  String get formattedWeight {
    if (weight == null) return 'N/A';
    return '${weight!.toStringAsFixed(1)} kg';
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
    return 'GoogleFitData(date: $date, steps: $steps, caloriesBurned: $caloriesBurned, distance: $distance, weight: $weight)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is GoogleFitData &&
        other.date == date &&
        other.steps == steps &&
        other.caloriesBurned == caloriesBurned &&
        other.distance == distance &&
        other.weight == weight;
  }
  
  @override
  int get hashCode {
    return date.hashCode ^
        steps.hashCode ^
        caloriesBurned.hashCode ^
        distance.hashCode ^
        weight.hashCode;
  }
}

/// Model for weekly fitness summary
class WeeklyFitnessSummary {
  final List<GoogleFitData> dailyData;
  final int totalSteps;
  final double totalCaloriesBurned;
  final double totalDistance;
  final double averageSteps;
  final double averageCalories;
  final double averageDistance;
  
  const WeeklyFitnessSummary({
    required this.dailyData,
    required this.totalSteps,
    required this.totalCaloriesBurned,
    required this.totalDistance,
    required this.averageSteps,
    required this.averageCalories,
    required this.averageDistance,
  });
  
  /// Create from list of daily data
  factory WeeklyFitnessSummary.fromDailyData(List<GoogleFitData> dailyData) {
    final validData = dailyData.where((data) => data.hasData).toList();
    
    if (validData.isEmpty) {
      return WeeklyFitnessSummary(
        dailyData: dailyData,
        totalSteps: 0,
        totalCaloriesBurned: 0,
        totalDistance: 0,
        averageSteps: 0,
        averageCalories: 0,
        averageDistance: 0,
      );
    }
    
    final totalSteps = validData.fold<int>(0, (sum, data) => sum + (data.steps ?? 0));
    final totalCalories = validData.fold<double>(0, (sum, data) => sum + (data.caloriesBurned ?? 0));
    final totalDist = validData.fold<double>(0, (sum, data) => sum + (data.distance ?? 0));
    
    final dataCount = validData.length;
    
    return WeeklyFitnessSummary(
      dailyData: dailyData,
      totalSteps: totalSteps,
      totalCaloriesBurned: totalCalories,
      totalDistance: totalDist,
      averageSteps: totalSteps / dataCount,
      averageCalories: totalCalories / dataCount,
      averageDistance: totalDist / dataCount,
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
  String get formattedTotalCalories => '${totalCaloriesBurned.toStringAsFixed(0)} cal';
  
  /// Get formatted total distance
  String get formattedTotalDistance => '${totalDistance.toStringAsFixed(2)} km';
  
  /// Get average activity level
  String get averageActivityLevel {
    if (averageSteps < 5000) return 'Low';
    if (averageSteps < 10000) return 'Moderate';
    if (averageSteps < 15000) return 'Active';
    return 'Very Active';
  }
}
