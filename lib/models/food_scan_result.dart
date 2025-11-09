/// Model for food scan results from AI recognition
class FoodScanResult {
  final String dishName;
  final String cuisine;
  final double portionSizeGrams;
  final List<FoodIngredient> ingredients;
  final NutritionInfo nutrition;
  final double confidence;
  final String? preparationMethod;
  final String? region;

  FoodScanResult({
    required this.dishName,
    required this.cuisine,
    required this.portionSizeGrams,
    required this.ingredients,
    required this.nutrition,
    required this.confidence,
    this.preparationMethod,
    this.region,
  });

  factory FoodScanResult.fromJson(Map<String, dynamic> json) {
    return FoodScanResult(
      dishName: json['dish_name'] ?? json['dish'] ?? 'Unknown Dish',
      cuisine: json['cuisine'] ?? 'Unknown',
      portionSizeGrams: (json['portion_size_grams'] ?? 250).toDouble(),
      ingredients: (json['ingredients'] as List?)
              ?.map((i) => FoodIngredient.fromJson(i))
              .toList() ??
          [],
      nutrition: NutritionInfo.fromJson(json['nutrition'] ?? json),
      confidence: (json['confidence'] ?? 0.7).toDouble(),
      preparationMethod: json['preparation_method'],
      region: json['region'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dish_name': dishName,
      'cuisine': cuisine,
      'portion_size_grams': portionSizeGrams,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'nutrition': nutrition.toJson(),
      'confidence': confidence,
      'preparation_method': preparationMethod,
      'region': region,
    };
  }

  /// Create a copy with updated portion size
  FoodScanResult copyWithPortion(double newPortionGrams) {
    final multiplier = newPortionGrams / portionSizeGrams;
    return FoodScanResult(
      dishName: dishName,
      cuisine: cuisine,
      portionSizeGrams: newPortionGrams,
      ingredients: ingredients
          .map((i) => i.copyWith(weightGrams: i.weightGrams * multiplier))
          .toList(),
      nutrition: nutrition.copyWith(
        calories: (nutrition.calories * multiplier).round(),
        protein: nutrition.protein * multiplier,
        carbs: nutrition.carbs * multiplier,
        fat: nutrition.fat * multiplier,
      ),
      confidence: confidence,
      preparationMethod: preparationMethod,
      region: region,
    );
  }
}

/// Individual food ingredient
class FoodIngredient {
  final String name;
  final double weightGrams;
  final int calories;

  FoodIngredient({
    required this.name,
    required this.weightGrams,
    required this.calories,
  });

  factory FoodIngredient.fromJson(Map<String, dynamic> json) {
    return FoodIngredient(
      name: json['name'] ?? '',
      weightGrams: (json['weight_grams'] ?? json['weight'] ?? 0).toDouble(),
      calories: (json['calories'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight_grams': weightGrams,
      'calories': calories,
    };
  }

  FoodIngredient copyWith({double? weightGrams, int? calories}) {
    return FoodIngredient(
      name: name,
      weightGrams: weightGrams ?? this.weightGrams,
      calories: calories ?? this.calories,
    );
  }
}

/// Nutrition information
class NutritionInfo {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final double? sugar;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sugar,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['total_calories'] ?? json['calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? json['protein_g'] ?? 0).toDouble(),
      carbs: (json['carbs'] ?? json['carbs_g'] ?? 0).toDouble(),
      fat: (json['fat'] ?? json['fat_g'] ?? 0).toDouble(),
      fiber: json['fiber'] != null ? (json['fiber']).toDouble() : null,
      sugar: json['sugar'] != null ? (json['sugar']).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      if (fiber != null) 'fiber': fiber,
      if (sugar != null) 'sugar': sugar,
    };
  }

  NutritionInfo copyWith({
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
  }) {
    return NutritionInfo(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
    );
  }
}

