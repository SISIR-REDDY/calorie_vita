import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/nutrition_info.dart';
import 'ai_suggestions_service.dart';
import 'nutrition_lookup_service.dart';

/// Enhanced snap-to-calorie service using OpenRouter AI vision
/// Implements the complete pipeline: IDENTIFY -> MEASURE -> CALORIE -> OUTPUT
class SnapToCalorieService {
  static const String _baseUrl = AIConfig.baseUrl;
  static const String _apiKey = AIConfig.apiKey;
  static const String _visionModel = AIConfig.visionModel;
  static const String _backupVisionModel = AIConfig.backupVisionModel;

  /// Process food image through complete snap-to-calorie pipeline with AI suggestions
  static Future<SnapToCalorieResult> processFoodImage(
    File imageFile, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
    List<String>? dietaryRestrictions,
    bool includeSuggestions = true,
  }) async {
    try {
      print('🔍 Starting snap-to-calorie pipeline with AI suggestions...');
      
      // Step 1: IDENTIFY - Use OpenRouter AI vision
      final identificationResult = await _identifyFoodItems(imageFile);
      if (identificationResult == null || identificationResult.isEmpty) {
        return _createErrorResult('No food items identified in image');
      }

      final List<FoodItemAnalysis> items = [];
      double totalConfidence = 0.0;

      // Process each identified food item
      for (final item in identificationResult) {
        // Step 2: MEASURE - Estimate volume and weight
        final measurementResult = await _measureFoodItem(imageFile, item);
        
        // Step 3: CALORIE - Calculate calories
        final calorieResult = await _calculateCalories(measurementResult, foodName: item['name']);
        
        items.add(FoodItemAnalysis(
          id: item['id'] ?? _generateUuid(),
          name: item['name'] ?? 'Unknown Food',
          alternatives: item['alternatives'] ?? [],
          segmentationMaskProvided: item['segmentation_mask_provided'] ?? false,
          volumeCm3: VolumeMeasurement(
            value: measurementResult['volume_cm3'] ?? 0.0,
            uncertaintyPct: measurementResult['uncertainty_pct'] ?? 20.0,
            method: measurementResult['method'] ?? 'monocular',
          ),
          massG: MassMeasurement(
            value: measurementResult['mass_g'] ?? 0.0,
            uncertaintyPct: measurementResult['mass_uncertainty_pct'] ?? 25.0,
            densityUsedGCm3: measurementResult['density_used_g_cm3'] ?? 1.0,
            densitySource: measurementResult['density_source'] ?? 'prior',
          ),
          kcalTotal: CalorieMeasurement(
            value: calorieResult['kcal_total'] ?? 0.0,
            uncertaintyKcal: calorieResult['uncertainty_kcal'] ?? 10.0,
          ),
          kcalPer100g: calorieResult['kcal_per_100g'] ?? 100.0,
          provenance: [
            'food_id:openrouter/vision',
            'volume:${measurementResult['method'] ?? 'monocular'}',
            'nutrition_source:internal_db',
          ],
          confidence: item['confidence'] ?? 0.5,
        ));

        totalConfidence += item['confidence'] ?? 0.5;
      }

      final overallConfidence = items.isNotEmpty ? totalConfidence / items.length : 0.0;
      final recommendedAction = overallConfidence < 0.6 ? 'resnap_with_reference' : 'accept';

      // Create initial result
      final result = SnapToCalorieResult(
        items: items,
        overallConfidence: overallConfidence,
        recommendedAction: recommendedAction,
        notes: _generateNotes(items, overallConfidence),
      );

      // Step 4: AI SUGGESTIONS - Generate personalized recommendations
      AISuggestionsResult? aiSuggestions;
      if (includeSuggestions && result.isSuccessful) {
        print('🤖 Generating AI suggestions...');
        try {
          aiSuggestions = await AISuggestionsService.generateSuggestions(
            scanResult: result,
            userProfile: userProfile,
            userGoals: userGoals,
            dietaryRestrictions: dietaryRestrictions,
          );
          
          if (aiSuggestions.isSuccessful) {
            print('✅ AI suggestions generated successfully');
          } else {
            print('⚠️ AI suggestions failed: ${aiSuggestions.error}');
          }
        } catch (e) {
          print('❌ Error generating AI suggestions: $e');
        }
      }

      // Add suggestions to result
      return SnapToCalorieResult(
        items: items,
        overallConfidence: overallConfidence,
        recommendedAction: recommendedAction,
        notes: _generateNotes(items, overallConfidence),
        aiSuggestions: aiSuggestions,
      );

    } catch (e) {
      print('❌ Error in snap-to-calorie pipeline: $e');
      return _createErrorResult('Pipeline processing failed: $e');
    }
  }

  /// Step 1: IDENTIFY - Use OpenRouter AI vision to identify food items
  static Future<List<Map<String, dynamic>>?> _identifyFoodItems(File imageFile) async {
    try {
      final result = await _identifyFoodItemsWithModel(imageFile, _visionModel);
      if (result != null) return result;
      
      // Try backup model if main model fails
      if (_visionModel != _backupVisionModel) {
        print('🔄 Trying backup vision model for food identification...');
        return await _identifyFoodItemsWithModel(imageFile, _backupVisionModel);
      }
      
      return null;
    } catch (e) {
      print('❌ Error in food identification: $e');
      return null;
    }
  }

  /// Identify food items with specific model
  static Future<List<Map<String, dynamic>>?> _identifyFoodItemsWithModel(File imageFile, String model) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final prompt = '''
You are a food recognition expert. Analyze this image and identify EVERY SINGLE VISIBLE INGREDIENT AND FOOD COMPONENT separately.

Return ONLY valid JSON in this exact format:
{
  "items": [
    {
      "id": "unique_id",
      "name": "specific_ingredient_name",
      "alternatives": [{"name": "alternative_name", "confidence": 0.8}],
      "segmentation_mask_provided": false,
      "ingredient_type": "main|sauce|garnish|accompaniment",
      "confidence": 0.85
    }
  ]
}
''';

      final response = await _callOpenRouterVisionWithModel(prompt, base64Image, model);
      if (response == null) return null;

      try {
        final result = jsonDecode(response);
        return (result['items'] as List<dynamic>).cast<Map<String, dynamic>>();
      } catch (e) {
        print('❌ Failed to parse AI response: $e');
        return null;
      }

    } catch (e) {
      print('❌ Error in food identification with model $model: $e');
      return null;
    }
  }

  /// Call OpenRouter vision API with specific model
  static Future<String?> _callOpenRouterVisionWithModel(String prompt, String base64Image, String model) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      };

      final body = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                }
              }
            ],
          }
        ],
        'max_tokens': AIConfig.visionMaxTokens,
        'temperature': AIConfig.visionTemperature,
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(AIConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('❌ OpenRouter API error with model $model: ${response.statusCode} - ${response.body}');
        return null;
      }

    } catch (e) {
      print('❌ Error calling OpenRouter vision with model $model: $e');
      return null;
    }
  }

  /// Step 2: MEASURE - Estimate volume and weight based on food type
  static Future<Map<String, dynamic>> _measureFoodItem(File imageFile, Map<String, dynamic> item) async {
    final foodName = item['name']?.toString().toLowerCase() ?? '';
    final confidence = item['confidence']?.toDouble() ?? 0.5;
    
    // Estimate portion size based on food type and confidence
    final portionEstimate = _estimatePortionSize(foodName, confidence);
    
    return {
      'volume_cm3': portionEstimate['volume_cm3'],
      'uncertainty_pct': portionEstimate['uncertainty_pct'],
      'method': 'food_type_estimation',
      'mass_g': portionEstimate['mass_g'],
      'mass_uncertainty_pct': portionEstimate['mass_uncertainty_pct'],
      'density_used_g_cm3': portionEstimate['density_used_g_cm3'],
      'density_source': 'food_type_prior',
    };
  }

  /// Estimate portion size based on food type
  static Map<String, double> _estimatePortionSize(String foodName, double confidence) {
    // Adjust portion size based on confidence (lower confidence = smaller portions)
    final confidenceMultiplier = 0.5 + (confidence * 0.5); // Range: 0.5 to 1.0
    
    // Base portion estimates (in grams) for typical Indian servings
    double baseMass = 100.0; // Default
    double density = 1.0; // Default density g/cm³
    double uncertainty = 30.0; // Default uncertainty %
    
    if (foodName.contains('rice') || foodName.contains('biryani') || foodName.contains('pulao')) {
      baseMass = 150.0; // Typical rice serving
      density = 0.6; // Rice is less dense
      uncertainty = 25.0;
    } else if (foodName.contains('dal') || foodName.contains('lentil') || foodName.contains('soup')) {
      baseMass = 200.0; // Typical dal serving
      density = 1.0; // Similar to water
      uncertainty = 20.0;
    } else if (foodName.contains('roti') || foodName.contains('naan') || foodName.contains('chapati')) {
      baseMass = 50.0; // Single roti
      density = 0.8; // Bread density
      uncertainty = 15.0;
    } else if (foodName.contains('curry') || foodName.contains('sabzi') || foodName.contains('vegetable')) {
      baseMass = 100.0; // Typical vegetable serving
      density = 0.9; // Vegetable density
      uncertainty = 25.0;
    } else if (foodName.contains('chicken') || foodName.contains('mutton') || foodName.contains('fish')) {
      baseMass = 120.0; // Typical protein serving
      density = 1.1; // Meat density
      uncertainty = 20.0;
    } else if (foodName.contains('paneer')) {
      baseMass = 80.0; // Paneer serving
      density = 1.0; // Cheese density
      uncertainty = 20.0;
    } else if (foodName.contains('sweet') || foodName.contains('dessert') || foodName.contains('mithai')) {
      baseMass = 50.0; // Small sweet serving
      density = 1.2; // Dense sweets
      uncertainty = 30.0;
    } else if (foodName.contains('fried') || foodName.contains('pakora') || foodName.contains('samosa')) {
      baseMass = 60.0; // Fried snack serving
      density = 0.7; // Fried foods are less dense
      uncertainty = 25.0;
    }
    
    // Apply confidence multiplier
    final adjustedMass = baseMass * confidenceMultiplier;
    final volume = adjustedMass / density;
    
    return {
      'mass_g': adjustedMass,
      'volume_cm3': volume,
      'density_used_g_cm3': density,
      'uncertainty_pct': uncertainty,
      'mass_uncertainty_pct': uncertainty,
    };
  }

  /// Step 3: CALORIE - Calculate calories using proper nutrition lookup
  static Future<Map<String, dynamic>> _calculateCalories(
    Map<String, dynamic> measurement, {
    String? foodName,
  }) async {
    final massG = measurement['mass_g'] ?? 120.0;
    
    // Try to get accurate nutrition data
    double kcalPer100g = 150.0; // Default fallback
    double uncertaintyKcal = 20.0; // Higher uncertainty for estimates
    
    if (foodName != null && foodName.isNotEmpty) {
      try {
        // Use the nutrition lookup service to get accurate data
        final nutritionInfo = await _getNutritionForFood(foodName, massG);
        if (nutritionInfo != null && nutritionInfo.calories > 0) {
          kcalPer100g = (nutritionInfo.calories / massG) * 100;
          uncertaintyKcal = 10.0; // Lower uncertainty for accurate data
          print('✅ Found accurate nutrition data for $foodName: ${kcalPer100g.toStringAsFixed(1)} kcal/100g');
        } else {
          print('⚠️ No nutrition data found for $foodName, using category-based estimate');
          kcalPer100g = _getCategoryBasedCalorieDensity(foodName);
        }
      } catch (e) {
        print('❌ Error looking up nutrition for $foodName: $e');
        kcalPer100g = _getCategoryBasedCalorieDensity(foodName);
      }
    } else {
      print('⚠️ No food name provided, using default calorie density');
    }
    
    final totalCalories = (massG * kcalPer100g / 100);
    
    return {
      'kcal_total': totalCalories,
      'uncertainty_kcal': uncertaintyKcal,
      'kcal_per_100g': kcalPer100g,
    };
  }

  /// Get nutrition information for a specific food
  static Future<NutritionInfo?> _getNutritionForFood(String foodName, double weightGrams) async {
    try {
      // Import the nutrition lookup service
      final nutritionInfo = await NutritionLookupService.lookupNutrition(
        foodName,
        weightGrams,
        null, // category will be inferred
      );
      
      if (nutritionInfo.calories > 0) {
        return nutritionInfo;
      }
    } catch (e) {
      print('❌ Error in nutrition lookup for $foodName: $e');
    }
    return null;
  }

  /// Get category-based calorie density for foods not found in database
  static double _getCategoryBasedCalorieDensity(String foodName) {
    final name = foodName.toLowerCase();
    
    // Rice and grains
    if (name.contains('rice') || name.contains('biryani') || name.contains('pulao')) {
      return 130.0; // kcal per 100g
    }
    
    // Dal and legumes
    if (name.contains('dal') || name.contains('lentil') || name.contains('chana') || 
        name.contains('rajma') || name.contains('moong')) {
      return 120.0;
    }
    
    // Bread and roti
    if (name.contains('roti') || name.contains('naan') || name.contains('chapati') || 
        name.contains('paratha') || name.contains('bread')) {
      return 250.0;
    }
    
    // Curries and vegetables
    if (name.contains('curry') || name.contains('sabzi') || name.contains('vegetable') ||
        name.contains('aloo') || name.contains('gobi') || name.contains('baingan')) {
      return 80.0;
    }
    
    // Protein sources
    if (name.contains('chicken') || name.contains('mutton') || name.contains('fish') ||
        name.contains('paneer') || name.contains('egg')) {
      return 200.0;
    }
    
    // Dairy
    if (name.contains('milk') || name.contains('yogurt') || name.contains('curd') ||
        name.contains('cheese')) {
      return 60.0;
    }
    
    // Sweets and desserts
    if (name.contains('sweet') || name.contains('dessert') || name.contains('mithai') ||
        name.contains('halwa') || name.contains('kheer')) {
      return 350.0;
    }
    
    // Fried foods
    if (name.contains('fried') || name.contains('pakora') || name.contains('samosa') ||
        name.contains('vada') || name.contains('bonda')) {
      return 300.0;
    }
    
    // Default for unknown foods
    return 150.0;
  }

  /// Generate UUID
  static String _generateUuid() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Generate notes
  static String _generateNotes(List<FoodItemAnalysis> items, double confidence) {
    if (items.isEmpty) return 'No food items identified';
    return 'Identified ${items.length} food item(s) with ${(confidence * 100).toStringAsFixed(1)}% confidence';
  }

  /// Create error result
  static SnapToCalorieResult _createErrorResult(String error) {
    return SnapToCalorieResult(
      items: [],
      overallConfidence: 0.0,
      recommendedAction: 'manual_entry',
      notes: error,
    );
  }
}

/// Result model for snap-to-calorie analysis
class SnapToCalorieResult {
  final List<FoodItemAnalysis> items;
  final double overallConfidence;
  final String recommendedAction;
  final String notes;
  final AISuggestionsResult? aiSuggestions;

  SnapToCalorieResult({
    required this.items,
    required this.overallConfidence,
    required this.recommendedAction,
    required this.notes,
    this.aiSuggestions,
  });

  /// Convert to the exact JSON format specified
  Map<String, dynamic> toJson() {
    final json = {
      'items': items.map((item) => item.toJson()).toList(),
      'overall_confidence': overallConfidence,
      'recommended_action': recommendedAction,
      'notes': notes,
    };

    // Add AI suggestions if available
    if (aiSuggestions != null) {
      json['ai_suggestions'] = aiSuggestions!.toJson();
    }

    return json;
  }

  /// Check if result is successful
  bool get isSuccessful => items.isNotEmpty && overallConfidence > 0.0;

  /// Get total calories across all items
  double get totalCalories => items.fold(0.0, (sum, item) => sum + item.kcalTotal.value);

  /// Get total weight across all items
  double get totalWeight => items.fold(0.0, (sum, item) => sum + item.massG.value);
}

/// Food item analysis result
class FoodItemAnalysis {
  final String id;
  final String name;
  final List<Map<String, dynamic>> alternatives;
  final bool segmentationMaskProvided;
  final VolumeMeasurement volumeCm3;
  final MassMeasurement massG;
  final CalorieMeasurement kcalTotal;
  final double kcalPer100g;
  final List<String> provenance;
  final double confidence;

  FoodItemAnalysis({
    required this.id,
    required this.name,
    required this.alternatives,
    required this.segmentationMaskProvided,
    required this.volumeCm3,
    required this.massG,
    required this.kcalTotal,
    required this.kcalPer100g,
    required this.provenance,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'alternatives': alternatives,
      'segmentation_mask_provided': segmentationMaskProvided,
      'volume_cm3': {
        'value': volumeCm3.value,
        'uncertainty_pct': volumeCm3.uncertaintyPct,
        'method': volumeCm3.method,
      },
      'mass_g': {
        'value': massG.value,
        'uncertainty_pct': massG.uncertaintyPct,
        'density_used_g_cm3': massG.densityUsedGCm3,
        'density_source': massG.densitySource,
      },
      'kcal_total': {
        'value': kcalTotal.value,
        'uncertainty_kcal': kcalTotal.uncertaintyKcal,
      },
      'kcal_per_100g': kcalPer100g,
      'provenance': provenance,
      'confidence': confidence,
    };
  }
}

/// Volume measurement
class VolumeMeasurement {
  final double value;
  final double uncertaintyPct;
  final String method;

  VolumeMeasurement({
    required this.value,
    required this.uncertaintyPct,
    required this.method,
  });
}

/// Mass measurement
class MassMeasurement {
  final double value;
  final double uncertaintyPct;
  final double densityUsedGCm3;
  final String densitySource;

  MassMeasurement({
    required this.value,
    required this.uncertaintyPct,
    required this.densityUsedGCm3,
    required this.densitySource,
  });
}

/// Calorie measurement
class CalorieMeasurement {
  final double value;
  final double uncertaintyKcal;

  CalorieMeasurement({
    required this.value,
    required this.uncertaintyKcal,
  });
}
