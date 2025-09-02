/// Model for macro nutrient breakdown
class MacroBreakdown {
  final double carbs;
  final double protein;
  final double fat;
  final double fiber;
  final double sugar;

  MacroBreakdown({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.fiber,
    required this.sugar,
  });

  /// Get total calories from macros
  double get totalCalories => (carbs * 4) + (protein * 4) + (fat * 9);

  /// Get carbs percentage
  double get carbsPercentage => carbs > 0 ? (carbs * 4) / totalCalories : 0.0;

  /// Get protein percentage
  double get proteinPercentage => protein > 0 ? (protein * 4) / totalCalories : 0.0;

  /// Get fat percentage
  double get fatPercentage => fat > 0 ? (fat * 9) / totalCalories : 0.0;

  /// Get recommended daily values (based on 2000 calorie diet)
  MacroBreakdown get recommendedDaily {
    return MacroBreakdown(
      carbs: 300, // 50% of 2000 calories
      protein: 150, // 30% of 2000 calories
      fat: 67, // 20% of 2000 calories
      fiber: 25,
      sugar: 50,
    );
  }

  /// Check if macros are within recommended ranges
  bool get isWithinRecommended {
    final recommended = recommendedDaily;
    return carbs <= recommended.carbs * 1.2 &&
           protein >= recommended.protein * 0.8 &&
           protein <= recommended.protein * 1.2 &&
           fat <= recommended.fat * 1.2;
  }

  /// Get macro quality score (0-100)
  double get qualityScore {
    final recommended = recommendedDaily;
    double score = 0;
    
    // Carbs score (40% weight)
    final carbsScore = (1 - (carbs - recommended.carbs).abs() / recommended.carbs).clamp(0.0, 1.0);
    score += carbsScore * 0.4;
    
    // Protein score (35% weight)
    final proteinScore = (1 - (protein - recommended.protein).abs() / recommended.protein).clamp(0.0, 1.0);
    score += proteinScore * 0.35;
    
    // Fat score (25% weight)
    final fatScore = (1 - (fat - recommended.fat).abs() / recommended.fat).clamp(0.0, 1.0);
    score += fatScore * 0.25;
    
    return (score * 100).clamp(0.0, 100.0);
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
    };
  }

  /// Create from JSON
  factory MacroBreakdown.fromJson(Map<String, dynamic> json) {
    return MacroBreakdown(
      carbs: (json['carbs'] ?? 0.0).toDouble(),
      protein: (json['protein'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? 0.0).toDouble(),
      fiber: (json['fiber'] ?? 0.0).toDouble(),
      sugar: (json['sugar'] ?? 0.0).toDouble(),
    );
  }

  /// Copy with new values
  MacroBreakdown copyWith({
    double? carbs,
    double? protein,
    double? fat,
    double? fiber,
    double? sugar,
  }) {
    return MacroBreakdown(
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
    );
  }

  /// Add another macro breakdown
  MacroBreakdown operator +(MacroBreakdown other) {
    return MacroBreakdown(
      carbs: carbs + other.carbs,
      protein: protein + other.protein,
      fat: fat + other.fat,
      fiber: fiber + other.fiber,
      sugar: sugar + other.sugar,
    );
  }

  @override
  String toString() {
    return 'MacroBreakdown(carbs: ${carbs.toStringAsFixed(1)}g, protein: ${protein.toStringAsFixed(1)}g, fat: ${fat.toStringAsFixed(1)}g)';
  }
}
