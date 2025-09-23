import '../models/nutrition_info.dart';

/// Service for manual food entry when AI scanning fails
class ManualFoodEntryService {
  static final ManualFoodEntryService _instance = ManualFoodEntryService._internal();
  factory ManualFoodEntryService() => _instance;
  ManualFoodEntryService._internal();

  /// Create a basic nutrition info for manual entry
  static NutritionInfo createManualEntry({
    required String foodName,
    double calories = 0.0,
    double protein = 0.0,
    double carbs = 0.0,
    double fat = 0.0,
    double fiber = 0.0,
    double sugar = 0.0,
    double weightGrams = 100.0,
    String? category,
    String? brand,
    String? notes,
  }) {
    return NutritionInfo(
      foodName: foodName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      weightGrams: weightGrams,
      source: 'manual_entry',
      category: category ?? 'Unknown',
      brand: brand,
      notes: notes ?? 'Manual entry',
    );
  }

  /// Get common food items with basic nutrition data
  static List<Map<String, dynamic>> getCommonFoods() {
    return [
      {
        'name': 'Apple',
        'calories': 52.0,
        'protein': 0.3,
        'carbs': 13.8,
        'fat': 0.2,
        'fiber': 2.4,
        'sugar': 10.4,
        'category': 'Fruit',
      },
      {
        'name': 'Banana',
        'calories': 89.0,
        'protein': 1.1,
        'carbs': 22.8,
        'fat': 0.3,
        'fiber': 2.6,
        'sugar': 12.2,
        'category': 'Fruit',
      },
      {
        'name': 'Rice (Cooked)',
        'calories': 130.0,
        'protein': 2.7,
        'carbs': 28.0,
        'fat': 0.3,
        'fiber': 0.4,
        'sugar': 0.1,
        'category': 'Grains',
      },
      {
        'name': 'Chicken Breast',
        'calories': 165.0,
        'protein': 31.0,
        'carbs': 0.0,
        'fat': 3.6,
        'fiber': 0.0,
        'sugar': 0.0,
        'category': 'Protein',
      },
      {
        'name': 'Egg',
        'calories': 155.0,
        'protein': 13.0,
        'carbs': 1.1,
        'fat': 11.0,
        'fiber': 0.0,
        'sugar': 1.1,
        'category': 'Protein',
      },
      {
        'name': 'Milk (Whole)',
        'calories': 61.0,
        'protein': 3.2,
        'carbs': 4.8,
        'fat': 3.3,
        'fiber': 0.0,
        'sugar': 4.8,
        'category': 'Dairy',
      },
      {
        'name': 'Bread (White)',
        'calories': 265.0,
        'protein': 9.0,
        'carbs': 49.0,
        'fat': 3.2,
        'fiber': 2.7,
        'sugar': 5.7,
        'category': 'Grains',
      },
      {
        'name': 'Potato',
        'calories': 77.0,
        'protein': 2.0,
        'carbs': 17.5,
        'fat': 0.1,
        'fiber': 2.2,
        'sugar': 0.8,
        'category': 'Vegetable',
      },
    ];
  }

  /// Create nutrition info from common food data
  static NutritionInfo createFromCommonFood(Map<String, dynamic> foodData, double weightGrams) {
    final multiplier = weightGrams / 100.0; // Convert to per 100g basis
    
    return NutritionInfo(
      foodName: foodData['name'],
      calories: (foodData['calories'] as double) * multiplier,
      protein: (foodData['protein'] as double) * multiplier,
      carbs: (foodData['carbs'] as double) * multiplier,
      fat: (foodData['fat'] as double) * multiplier,
      fiber: (foodData['fiber'] as double) * multiplier,
      sugar: (foodData['sugar'] as double) * multiplier,
      weightGrams: weightGrams,
      source: 'manual_entry',
      category: foodData['category'],
      notes: 'Manual entry from common foods',
    );
  }
}
