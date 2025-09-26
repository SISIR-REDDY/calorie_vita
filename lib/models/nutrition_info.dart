/// Model for nutrition information
class NutritionInfo {
  final String foodName;
  final double weightGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final String source;
  final String? category;
  final String? cuisine;
  final String? brand;
  final String? notes;
  final String? error;

  NutritionInfo({
    required this.foodName,
    required this.weightGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.source,
    this.category,
    this.cuisine,
    this.brand,
    this.notes,
    this.error,
  });

  /// Check if the nutrition info is valid
  bool get isValid => error == null && calories > 0;

  /// Get total macronutrients
  double get totalMacros => protein + carbs + fat;

  /// Get protein percentage of total macros
  double get proteinPercentage => totalMacros > 0 ? (protein / totalMacros) * 100 : 0;

  /// Get carbs percentage of total macros
  double get carbsPercentage => totalMacros > 0 ? (carbs / totalMacros) * 100 : 0;

  /// Get fat percentage of total macros
  double get fatPercentage => totalMacros > 0 ? (fat / totalMacros) * 100 : 0;

  /// Get calories per gram
  double get caloriesPerGram => weightGrams > 0 ? calories / weightGrams : 0;

  /// Get protein per 100g
  double get proteinPer100g => (protein / weightGrams) * 100;

  /// Get carbs per 100g
  double get carbsPer100g => (carbs / weightGrams) * 100;

  /// Get fat per 100g
  double get fatPer100g => (fat / weightGrams) * 100;

  /// Get fiber per 100g
  double get fiberPer100g => (fiber / weightGrams) * 100;

  /// Get sugar per 100g
  double get sugarPer100g => (sugar / weightGrams) * 100;

  /// Get formatted weight string
  String get formattedWeight {
    if (weightGrams >= 1000) {
      return '${(weightGrams / 1000).toStringAsFixed(1)}kg';
    } else {
      return '${weightGrams.toStringAsFixed(0)}g';
    }
  }

  /// Get formatted calories string
  String get formattedCalories => '${calories.toStringAsFixed(0)} kcal';

  /// Get formatted protein string
  String get formattedProtein => '${protein.toStringAsFixed(1)}g';

  /// Get formatted carbs string
  String get formattedCarbs => '${carbs.toStringAsFixed(1)}g';

  /// Get formatted fat string
  String get formattedFat => '${fat.toStringAsFixed(1)}g';

  /// Get formatted fiber string
  String get formattedFiber => '${fiber.toStringAsFixed(1)}g';

  /// Get formatted sugar string
  String get formattedSugar => '${sugar.toStringAsFixed(1)}g';

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'foodName': foodName,
      'weightGrams': weightGrams,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'source': source,
      'category': category,
      'cuisine': cuisine,
      'brand': brand,
      'notes': notes,
      'error': error,
    };
  }

  /// Create from JSON
  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      foodName: json['foodName'] as String? ?? 'Unknown Food',
      weightGrams: (json['weightGrams'] as num?)?.toDouble() ?? 0.0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? 'Unknown',
      category: json['category'] as String?,
      cuisine: json['cuisine'] as String?,
      brand: json['brand'] as String?,
      notes: json['notes'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Create a copy with updated values
  NutritionInfo copyWith({
    String? foodName,
    double? weightGrams,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    String? source,
    String? category,
    String? cuisine,
    String? brand,
    String? notes,
    String? error,
  }) {
    return NutritionInfo(
      foodName: foodName ?? this.foodName,
      weightGrams: weightGrams ?? this.weightGrams,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      source: source ?? this.source,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      brand: brand ?? this.brand,
      notes: notes ?? this.notes,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'NutritionInfo(food: $foodName, weight: $formattedWeight, calories: $formattedCalories, protein: $formattedProtein, carbs: $formattedCarbs, fat: $formattedFat)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionInfo &&
        other.foodName == foodName &&
        other.weightGrams == weightGrams &&
        other.calories == calories &&
        other.protein == protein &&
        other.carbs == carbs &&
        other.fat == fat &&
        other.fiber == fiber &&
        other.sugar == sugar &&
        other.source == source &&
        other.category == category &&
        other.cuisine == cuisine &&
        other.brand == brand &&
        other.notes == notes &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      foodName,
      weightGrams,
      calories,
      protein,
      carbs,
      fat,
      fiber,
      sugar,
      source,
      category,
      cuisine,
      brand,
      notes,
      error,
    );
  }
}
