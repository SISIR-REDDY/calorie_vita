import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/nutrition_info.dart';

/// Service for nutrition lookup using USDA FoodData Central API and local datasets
class NutritionLookupService {
  static const String _usdaApiKey = 'YOUR_USDA_API_KEY'; // Replace with actual API key
  static const String _usdaBaseUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';
  
  static List<Map<String, dynamic>>? _indianFoods;
  static List<Map<String, dynamic>>? _indianPackaged;

  /// Initialize local datasets
  static Future<void> initialize() async {
    try {
      // Load Indian foods dataset
      final indianFoodsString = await rootBundle.loadString('assets/indian_foods.json');
      _indianFoods = List<Map<String, dynamic>>.from(jsonDecode(indianFoodsString));
      
      // Load Indian packaged foods dataset
      final indianPackagedString = await rootBundle.loadString('assets/indian_packaged.json');
      _indianPackaged = List<Map<String, dynamic>>.from(jsonDecode(indianPackagedString));
      
      print('✅ Nutrition lookup datasets loaded successfully');
    } catch (e) {
      print('❌ Error loading nutrition datasets: $e');
    }
  }

  /// Look up nutrition information for a food item
  static Future<NutritionInfo> lookupNutrition(
    String foodName,
    double weightGrams,
    String? category,
  ) async {
    try {
      // Ensure datasets are loaded
      if (_indianFoods == null || _indianPackaged == null) {
        await initialize();
      }

      // First, try local Indian foods dataset
      final indianFood = _searchIndianFoods(foodName);
      if (indianFood != null) {
        return _calculateNutritionFromIndianFood(indianFood, weightGrams);
      }

      // Try USDA FoodData Central API
      try {
        final usdaResult = await _lookupWithUSDA(foodName);
        if (usdaResult != null) {
          return _calculateNutritionFromUSDA(usdaResult, weightGrams);
        }
      } catch (e) {
        print('USDA lookup failed: $e');
      }

      // Fallback to generic nutrition based on category
      return _getGenericNutrition(foodName, weightGrams, category);
    } catch (e) {
      print('Error in nutrition lookup: $e');
      return NutritionInfo(
        foodName: foodName,
        weightGrams: weightGrams,
        calories: 0,
        protein: 0.0,
        carbs: 0.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 0.0,
        source: 'Error',
        error: 'Nutrition lookup failed: $e',
      );
    }
  }

  /// Search for food in Indian foods dataset
  static Map<String, dynamic>? _searchIndianFoods(String foodName) {
    if (_indianFoods == null) return null;
    
    final searchTerm = foodName.toLowerCase();
    for (final food in _indianFoods!) {
      final name = (food['name'] as String? ?? '').toLowerCase();
      final aliases = (food['aliases'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      
      if (name.contains(searchTerm) || 
          aliases.any((alias) => alias.contains(searchTerm))) {
        return food;
      }
    }
    return null;
  }

  /// Calculate nutrition from Indian food data
  static NutritionInfo _calculateNutritionFromIndianFood(
    Map<String, dynamic> foodData,
    double weightGrams,
  ) {
    final baseWeight = 100.0; // All values are per 100g
    final multiplier = weightGrams / baseWeight;
    
    return NutritionInfo(
      foodName: foodData['name'] as String? ?? 'Unknown Food',
      weightGrams: weightGrams,
      calories: ((foodData['calories_per_100g'] as num?)?.toDouble() ?? 0.0) * multiplier,
      protein: ((foodData['protein_per_100g'] as num?)?.toDouble() ?? 0.0) * multiplier,
      carbs: ((foodData['carbs_per_100g'] as num?)?.toDouble() ?? 0.0) * multiplier,
      fat: ((foodData['fat_per_100g'] as num?)?.toDouble() ?? 0.0) * multiplier,
      fiber: ((foodData['fiber_per_100g'] as num?)?.toDouble() ?? 0.0) * multiplier,
      sugar: ((foodData['sugar_per_100g'] as num?)?.toDouble() ?? 0.0) * multiplier,
      source: 'Indian Foods Dataset',
      category: foodData['category'] as String?,
      cuisine: foodData['cuisine'] as String?,
    );
  }

  /// Look up nutrition using USDA FoodData Central API
  static Future<Map<String, dynamic>?> _lookupWithUSDA(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$_usdaBaseUrl?api_key=$_usdaApiKey&query=$foodName&pageSize=1'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final foods = data['foods'] as List<dynamic>?;
        if (foods != null && foods.isNotEmpty) {
          return foods.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('USDA API error: $e');
    }
    return null;
  }

  /// Calculate nutrition from USDA data
  static NutritionInfo _calculateNutritionFromUSDA(
    Map<String, dynamic> usdaData,
    double weightGrams,
  ) {
    final nutrients = usdaData['foodNutrients'] as List<dynamic>? ?? [];
    
    // Extract nutrient values
    double calories = 0.0;
    double protein = 0.0;
    double carbs = 0.0;
    double fat = 0.0;
    double fiber = 0.0;
    double sugar = 0.0;
    
    for (final nutrient in nutrients) {
      final nutrientData = nutrient as Map<String, dynamic>;
      final nutrientInfo = nutrientData['nutrient'] as Map<String, dynamic>?;
      final amount = (nutrientData['amount'] as num?)?.toDouble() ?? 0.0;
      
      if (nutrientInfo != null) {
        final nutrientId = nutrientInfo['id'] as int?;
        final nutrientName = (nutrientInfo['name'] as String? ?? '').toLowerCase();
        
        // Map USDA nutrient IDs to our values
        if (nutrientId == 1008 || nutrientName.contains('energy')) {
          calories = amount;
        } else if (nutrientId == 1003 || nutrientName.contains('protein')) {
          protein = amount;
        } else if (nutrientId == 1005 || nutrientName.contains('carbohydrate')) {
          carbs = amount;
        } else if (nutrientId == 1004 || nutrientName.contains('fat')) {
          fat = amount;
        } else if (nutrientId == 1079 || nutrientName.contains('fiber')) {
          fiber = amount;
        } else if (nutrientId == 2000 || nutrientName.contains('sugar')) {
          sugar = amount;
        }
      }
    }
    
    // Convert from per 100g to per gram, then multiply by weight
    final multiplier = weightGrams / 100.0;
    
    return NutritionInfo(
      foodName: usdaData['description'] as String? ?? 'Unknown Food',
      weightGrams: weightGrams,
      calories: calories * multiplier,
      protein: protein * multiplier,
      carbs: carbs * multiplier,
      fat: fat * multiplier,
      fiber: fiber * multiplier,
      sugar: sugar * multiplier,
      source: 'USDA FoodData Central',
    );
  }

  /// Get generic nutrition based on food category
  static NutritionInfo _getGenericNutrition(
    String foodName,
    double weightGrams,
    String? category,
  ) {
    // Generic nutrition values per 100g by category
    final genericValues = {
      'Bread': {'calories': 250.0, 'protein': 8.0, 'carbs': 50.0, 'fat': 2.0, 'fiber': 2.0, 'sugar': 2.0},
      'Curry': {'calories': 120.0, 'protein': 5.0, 'carbs': 15.0, 'fat': 4.0, 'fiber': 3.0, 'sugar': 5.0},
      'Rice Dish': {'calories': 150.0, 'protein': 3.0, 'carbs': 30.0, 'fat': 2.0, 'fiber': 1.0, 'sugar': 1.0},
      'Dairy': {'calories': 200.0, 'protein': 15.0, 'carbs': 5.0, 'fat': 12.0, 'fiber': 0.0, 'sugar': 3.0},
      'Pancake': {'calories': 200.0, 'protein': 6.0, 'carbs': 35.0, 'fat': 4.0, 'fiber': 2.0, 'sugar': 2.0},
      'Steamed': {'calories': 80.0, 'protein': 3.0, 'carbs': 15.0, 'fat': 0.5, 'fiber': 2.0, 'sugar': 1.0},
      'Vegetable Curry': {'calories': 100.0, 'protein': 3.0, 'carbs': 12.0, 'fat': 4.0, 'fiber': 3.0, 'sugar': 4.0},
      'Non-Veg Curry': {'calories': 180.0, 'protein': 15.0, 'carbs': 8.0, 'fat': 10.0, 'fiber': 1.0, 'sugar': 3.0},
      'Grilled': {'calories': 200.0, 'protein': 25.0, 'carbs': 2.0, 'fat': 10.0, 'fiber': 0.0, 'sugar': 0.0},
      'Side Dish': {'calories': 50.0, 'protein': 2.0, 'carbs': 5.0, 'fat': 2.0, 'fiber': 1.0, 'sugar': 3.0},
      'Snack': {'calories': 300.0, 'protein': 8.0, 'carbs': 35.0, 'fat': 15.0, 'fiber': 3.0, 'sugar': 2.0},
      'Fried Snack': {'calories': 350.0, 'protein': 10.0, 'carbs': 30.0, 'fat': 20.0, 'fiber': 2.0, 'sugar': 1.0},
      'Beverage': {'calories': 80.0, 'protein': 3.0, 'carbs': 15.0, 'fat': 2.0, 'fiber': 0.0, 'sugar': 12.0},
      'Dessert': {'calories': 300.0, 'protein': 5.0, 'carbs': 50.0, 'fat': 10.0, 'fiber': 1.0, 'sugar': 40.0},
    };

    final values = genericValues[category] ?? genericValues['Curry']!;
    final multiplier = weightGrams / 100.0;
    
    return NutritionInfo(
      foodName: foodName,
      weightGrams: weightGrams,
      calories: values['calories']! * multiplier,
      protein: values['protein']! * multiplier,
      carbs: values['carbs']! * multiplier,
      fat: values['fat']! * multiplier,
      fiber: values['fiber']! * multiplier,
      sugar: values['sugar']! * multiplier,
      source: 'Generic estimation',
      category: category,
      notes: 'Estimated based on food category',
    );
  }

  /// Look up nutrition for packaged food by barcode
  static Future<NutritionInfo?> lookupPackagedFood(String barcode) async {
    if (_indianPackaged == null) {
      await initialize();
    }
    
    final packagedFood = _indianPackaged!.firstWhere(
      (food) => food['barcode'] == barcode,
      orElse: () => <String, dynamic>{},
    );
    
    if (packagedFood.isEmpty) return null;
    
    final servingSize = (packagedFood['serving_size_grams'] as num?)?.toDouble() ?? 100.0;
    
    return NutritionInfo(
      foodName: packagedFood['name'] as String? ?? 'Unknown Product',
      weightGrams: servingSize,
      calories: (packagedFood['calories_per_100g'] as num?)?.toDouble() ?? 0.0,
      protein: (packagedFood['protein_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbs: (packagedFood['carbs_per_100g'] as num?)?.toDouble() ?? 0.0,
      fat: (packagedFood['fat_per_100g'] as num?)?.toDouble() ?? 0.0,
      fiber: (packagedFood['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
      sugar: (packagedFood['sugar_per_100g'] as num?)?.toDouble() ?? 0.0,
      source: 'Indian Packaged Foods',
      category: packagedFood['category'] as String?,
      brand: packagedFood['brand'] as String?,
    );
  }
}
