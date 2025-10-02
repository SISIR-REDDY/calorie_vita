import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import 'snap_to_calorie_service.dart';

/// AI-powered suggestions service for post-scan recommendations
class AISuggestionsService {
  static String get _baseUrl => AIConfig.baseUrl;
  static String get _apiKey => AIConfig.apiKey;
  static String get _chatModel => AIConfig.chatModel;
  static String get _backupModel => AIConfig.backupVisionModel;

  /// Generate comprehensive AI suggestions based on scanned food analysis
  static Future<AISuggestionsResult> generateSuggestions({
    required SnapToCalorieResult scanResult,
    String? userProfile,
    Map<String, dynamic>? userGoals,
    List<String>? dietaryRestrictions,
  }) async {
    try {
      print('🤖 Generating AI suggestions for scanned food...');
      
      // Prepare context for AI analysis
      final context = _buildAnalysisContext(scanResult, userProfile, userGoals, dietaryRestrictions);
      
      // Generate different types of suggestions
      final healthSuggestions = await _generateHealthSuggestions(context);
      final nutritionAdvice = await _generateNutritionAdvice(context);
      final alternativeSuggestions = await _generateAlternativeSuggestions(context);
      final portionAdvice = await _generatePortionAdvice(context);
      final mealBalanceAdvice = await _generateMealBalanceAdvice(context);

      return AISuggestionsResult(
        healthSuggestions: healthSuggestions,
        nutritionAdvice: nutritionAdvice,
        alternativeSuggestions: alternativeSuggestions,
        portionAdvice: portionAdvice,
        mealBalanceAdvice: mealBalanceAdvice,
        overallRecommendation: _generateOverallRecommendation(
          scanResult, healthSuggestions, nutritionAdvice
        ),
        confidence: _calculateSuggestionConfidence(scanResult),
      );

    } catch (e) {
      print('❌ Error generating AI suggestions: $e');
      return AISuggestionsResult.error('Failed to generate suggestions: $e');
    }
  }

  /// Build context for AI analysis
  static Map<String, dynamic> _buildAnalysisContext(
    SnapToCalorieResult scanResult,
    String? userProfile,
    Map<String, dynamic>? userGoals,
    List<String>? dietaryRestrictions,
  ) {
    final totalCalories = scanResult.totalCalories;
    final ingredients = scanResult.items.map((item) => {
      'name': item.name,
      'calories': item.kcalTotal.value,
      'weight': item.massG.value,
      'confidence': item.confidence,
    }).toList();

    return {
      'total_calories': totalCalories,
      'ingredients': ingredients,
      'overall_confidence': scanResult.overallConfidence,
      'recommended_action': scanResult.recommendedAction,
      'user_profile': userProfile,
      'user_goals': userGoals,
      'dietary_restrictions': dietaryRestrictions,
      'food_items_count': ingredients.length,
    };
  }

  /// Generate health-focused suggestions
  static Future<List<HealthSuggestion>> _generateHealthSuggestions(Map<String, dynamic> context) async {
    try {
      final prompt = '''
You are a certified fitness nutritionist and sports dietitian. Analyze the scanned food and provide fitness-focused suggestions.

FOOD ANALYSIS:
Total Calories: ${context['total_calories']} kcal
Ingredients: ${context['ingredients']}
User Goals: ${context['user_goals'] ?? 'General fitness'}
Dietary Restrictions: ${context['dietary_restrictions'] ?? 'None'}

Provide 3-5 fitness/nutrition suggestions focusing on:
1. Fitness benefits for muscle building/performance
2. Macronutrient balance for fitness goals
3. Pre/post workout suitability
4. Portion control for fitness objectives
5. Recovery and performance optimization

ALLOWED TOPICS ONLY:
• Fitness and exercise performance
• Nutrition for muscle building/fat loss
• Pre/post workout nutrition timing
• Macronutrient optimization
• Recovery and hydration
• Supplement recommendations

PROFESSIONAL BOUNDARIES:
- Focus ONLY on fitness, nutrition, and wellness
- Do NOT provide medical advice or diagnosis
- Redirect health concerns to healthcare providers

Return JSON format:
{
  "suggestions": [
    {
      "type": "fitness_benefit|nutrition_concern|workout_advice|performance_tip",
      "title": "Short fitness-focused title",
      "description": "Detailed fitness/nutrition explanation",
      "priority": "high|medium|low",
      "icon": "emoji_or_description",
      "fitness_category": "muscle_building|fat_loss|performance|recovery"
    }
  ]
}
''';

      final response = await _callOpenRouterAPI(prompt);
      if (response == null) return [];

      final data = jsonDecode(response);
      final suggestions = (data['suggestions'] as List<dynamic>?)
          ?.map((s) => HealthSuggestion.fromJson(s))
          .toList() ?? [];

      return suggestions;

    } catch (e) {
      print('❌ Error generating health suggestions: $e');
      return [];
    }
  }

  /// Generate nutrition advice
  static Future<List<NutritionAdvice>> _generateNutritionAdvice(Map<String, dynamic> context) async {
    try {
      final prompt = '''
You are a certified sports nutritionist and fitness expert. Analyze the scanned food ingredients and provide detailed fitness-focused nutrition advice.

FOOD ANALYSIS:
Ingredients: ${context['ingredients']}
Total Calories: ${context['total_calories']} kcal
User Profile: ${context['user_profile'] ?? 'General fitness'}

Provide fitness/nutrition advice focusing on:
1. Macronutrient balance for fitness goals (protein, carbs, fats)
2. Pre/post workout nutrition suitability
3. Muscle building and recovery nutrients
4. Performance optimization nutrients
5. Fitness supplement timing and recommendations

ALLOWED TOPICS ONLY:
• Fitness and athletic performance nutrition
• Macronutrient ratios for muscle building/fat loss
• Pre/post workout meal timing
• Recovery and muscle repair nutrients
• Hydration for performance
• Supplement optimization for fitness

PROFESSIONAL BOUNDARIES:
- Focus ONLY on fitness, nutrition, and wellness
- Do NOT provide medical advice or diagnosis
- Redirect health concerns to healthcare providers

Return JSON format:
{
  "advice": [
    {
      "category": "fitness_macronutrients|performance_nutrients|recovery_nutrients|pre_workout|post_workout",
      "title": "Fitness-focused advice title",
      "description": "Detailed fitness nutrition information",
      "importance": "high|medium|low",
      "suggestion": "Specific fitness/nutrition recommendation",
      "fitness_benefit": "muscle_building|fat_loss|performance|recovery"
    }
  ]
}
''';

      final response = await _callOpenRouterAPI(prompt);
      if (response == null) return [];

      final data = jsonDecode(response);
      final advice = (data['advice'] as List<dynamic>?)
          ?.map((a) => NutritionAdvice.fromJson(a))
          .toList() ?? [];

      return advice;

    } catch (e) {
      print('❌ Error generating nutrition advice: $e');
      return [];
    }
  }

  /// Generate alternative food suggestions
  static Future<List<AlternativeSuggestion>> _generateAlternativeSuggestions(Map<String, dynamic> context) async {
    try {
      final prompt = '''
You are a culinary and nutrition expert. Suggest healthier or alternative food options based on the scanned food.

FOOD ANALYSIS:
Ingredients: ${context['ingredients']}
Total Calories: ${context['total_calories']} kcal
Dietary Restrictions: ${context['dietary_restrictions'] ?? 'None'}

Suggest 3-5 alternatives focusing on:
1. Healthier versions of the same dish
2. Lower-calorie alternatives
3. More nutritious ingredient swaps
4. Vegetarian/vegan options if applicable
5. Traditional vs modern preparations

Return JSON format:
{
  "alternatives": [
    {
      "type": "healthier|lower_calorie|more_nutritious|vegetarian|traditional",
      "name": "Alternative food name",
      "description": "What makes it better",
      "calorie_reduction": "Estimated calorie difference",
      "benefits": ["benefit1", "benefit2"],
      "preparation_tip": "How to make it"
    }
  ]
}
''';

      final response = await _callOpenRouterAPI(prompt);
      if (response == null) return [];

      final data = jsonDecode(response);
      final alternatives = (data['alternatives'] as List<dynamic>?)
          ?.map((a) => AlternativeSuggestion.fromJson(a))
          .toList() ?? [];

      return alternatives;

    } catch (e) {
      print('❌ Error generating alternatives: $e');
      return [];
    }
  }

  /// Generate portion control advice
  static Future<List<PortionAdvice>> _generatePortionAdvice(Map<String, dynamic> context) async {
    try {
      final prompt = '''
You are a portion control expert. Analyze the scanned food portions and provide portion management advice.

FOOD ANALYSIS:
Ingredients: ${context['ingredients']}
Total Calories: ${context['total_calories']} kcal
User Goals: ${context['user_goals'] ?? 'Maintain weight'}

Provide portion advice focusing on:
1. Current portion assessment
2. Ideal portion recommendations
3. Portion control techniques
4. Visual portion guides
5. Meal planning tips

Return JSON format:
{
  "advice": [
    {
      "ingredient": "Specific ingredient or 'overall'",
      "current_assessment": "Too much|Just right|Too little",
      "recommendation": "Suggested portion",
      "technique": "Portion control method",
      "visual_guide": "Reference object for size"
    }
  ]
}
''';

      final response = await _callOpenRouterAPI(prompt);
      if (response == null) return [];

      final data = jsonDecode(response);
      final advice = (data['advice'] as List<dynamic>?)
          ?.map((a) => PortionAdvice.fromJson(a))
          .toList() ?? [];

      return advice;

    } catch (e) {
      print('❌ Error generating portion advice: $e');
      return [];
    }
  }

  /// Generate meal balance advice
  static Future<List<MealBalanceAdvice>> _generateMealBalanceAdvice(Map<String, dynamic> context) async {
    try {
      final prompt = '''
You are a meal planning expert. Analyze the scanned food and provide meal balance recommendations.

FOOD ANALYSIS:
Ingredients: ${context['ingredients']}
Total Calories: ${context['total_calories']} kcal
User Goals: ${context['user_goals'] ?? 'Balanced nutrition'}

Provide meal balance advice focusing on:
1. Current meal balance assessment
2. Missing food groups
3. Suggested additions for balance
4. Meal timing recommendations
5. Combination with other meals

Return JSON format:
{
  "advice": [
    {
      "category": "protein|carbs|vegetables|fruits|dairy|fats",
      "current_status": "adequate|excess|deficient",
      "recommendation": "What to add or reduce",
      "reason": "Why this matters",
      "examples": ["example1", "example2"]
    }
  ]
}
''';

      final response = await _callOpenRouterAPI(prompt);
      if (response == null) return [];

      final data = jsonDecode(response);
      final advice = (data['advice'] as List<dynamic>?)
          ?.map((a) => MealBalanceAdvice.fromJson(a))
          .toList() ?? [];

      return advice;

    } catch (e) {
      print('❌ Error generating meal balance advice: $e');
      return [];
    }
  }

  /// Generate overall recommendation
  static String _generateOverallRecommendation(
    SnapToCalorieResult scanResult,
    List<HealthSuggestion> healthSuggestions,
    List<NutritionAdvice> nutritionAdvice,
  ) {
    final totalCalories = scanResult.totalCalories;
    final confidence = scanResult.overallConfidence;
    
    if (totalCalories > 600) {
      return "High-calorie meal detected. Consider reducing portion size or choosing lighter alternatives for better calorie control.";
    } else if (totalCalories < 200) {
      return "Light meal detected. Consider adding more nutritious ingredients to meet your daily nutritional needs.";
    } else if (confidence < 0.6) {
      return "Food identification confidence is low. Consider rescanning with better lighting or a reference object for more accurate analysis.";
    } else {
      return "Well-balanced meal detected! The ingredients provide good nutritional value. Consider the suggestions below for optimization.";
    }
  }

  /// Calculate suggestion confidence
  static double _calculateSuggestionConfidence(SnapToCalorieResult scanResult) {
    final baseConfidence = scanResult.overallConfidence;
    final ingredientCount = scanResult.items.length;
    
    // Adjust confidence based on ingredient diversity
    final diversityBonus = (ingredientCount / 10.0).clamp(0.0, 0.2);
    
    return (baseConfidence + diversityBonus).clamp(0.0, 1.0);
  }

  /// Call OpenRouter API with backup model
  static Future<String?> _callOpenRouterAPIWithBackup(String prompt) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      };

      final body = {
        'model': _backupModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'max_tokens': AIConfig.maxTokens,
        'temperature': AIConfig.temperature,
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
        print('❌ Backup model also failed: ${response.statusCode} - ${response.body}');
        return null;
      }

    } catch (e) {
      print('❌ Error calling backup model: $e');
      return null;
    }
  }

  /// Call OpenRouter API
  static Future<String?> _callOpenRouterAPI(String prompt) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      };

      final body = {
        'model': _chatModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'max_tokens': AIConfig.maxTokens,
        'temperature': AIConfig.temperature,
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
        print('❌ OpenRouter API error: ${response.statusCode} - ${response.body}');
        
        // Try backup model if main model fails
        if (_chatModel != _backupModel && response.statusCode == 400) {
          print('🔄 Trying backup model for AI suggestions...');
          return await _callOpenRouterAPIWithBackup(prompt);
        }
        
        return null;
      }

    } catch (e) {
      print('❌ Error calling OpenRouter API: $e');
      return null;
    }
  }
}

/// Result of AI suggestions analysis
class AISuggestionsResult {
  final List<HealthSuggestion> healthSuggestions;
  final List<NutritionAdvice> nutritionAdvice;
  final List<AlternativeSuggestion> alternativeSuggestions;
  final List<PortionAdvice> portionAdvice;
  final List<MealBalanceAdvice> mealBalanceAdvice;
  final String overallRecommendation;
  final double confidence;
  final String? error;

  AISuggestionsResult({
    required this.healthSuggestions,
    required this.nutritionAdvice,
    required this.alternativeSuggestions,
    required this.portionAdvice,
    required this.mealBalanceAdvice,
    required this.overallRecommendation,
    required this.confidence,
    this.error,
  });

  factory AISuggestionsResult.error(String error) {
    return AISuggestionsResult(
      healthSuggestions: [],
      nutritionAdvice: [],
      alternativeSuggestions: [],
      portionAdvice: [],
      mealBalanceAdvice: [],
      overallRecommendation: 'Unable to generate suggestions',
      confidence: 0.0,
      error: error,
    );
  }

  bool get isSuccessful => error == null;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'health_suggestions': healthSuggestions.map((s) => s.toJson()).toList(),
      'nutrition_advice': nutritionAdvice.map((a) => a.toJson()).toList(),
      'alternative_suggestions': alternativeSuggestions.map((a) => a.toJson()).toList(),
      'portion_advice': portionAdvice.map((a) => a.toJson()).toList(),
      'meal_balance_advice': mealBalanceAdvice.map((a) => a.toJson()).toList(),
      'overall_recommendation': overallRecommendation,
      'confidence': confidence,
      'error': error,
    };
  }
}

/// Health-focused suggestion
class HealthSuggestion {
  final String type;
  final String title;
  final String description;
  final String priority;
  final String icon;

  HealthSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.icon,
  });

  factory HealthSuggestion.fromJson(Map<String, dynamic> json) {
    return HealthSuggestion(
      type: json['type'] ?? 'advice',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'medium',
      icon: json['icon'] ?? '💡',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'priority': priority,
      'icon': icon,
    };
  }
}

/// Nutrition advice
class NutritionAdvice {
  final String category;
  final String title;
  final String description;
  final String importance;
  final String suggestion;

  NutritionAdvice({
    required this.category,
    required this.title,
    required this.description,
    required this.importance,
    required this.suggestion,
  });

  factory NutritionAdvice.fromJson(Map<String, dynamic> json) {
    return NutritionAdvice(
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      importance: json['importance'] ?? 'medium',
      suggestion: json['suggestion'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'description': description,
      'importance': importance,
      'suggestion': suggestion,
    };
  }
}

/// Alternative food suggestion
class AlternativeSuggestion {
  final String type;
  final String name;
  final String description;
  final String calorieReduction;
  final List<String> benefits;
  final String preparationTip;

  AlternativeSuggestion({
    required this.type,
    required this.name,
    required this.description,
    required this.calorieReduction,
    required this.benefits,
    required this.preparationTip,
  });

  factory AlternativeSuggestion.fromJson(Map<String, dynamic> json) {
    return AlternativeSuggestion(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      calorieReduction: json['calorie_reduction'] ?? '',
      benefits: List<String>.from(json['benefits'] ?? []),
      preparationTip: json['preparation_tip'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'description': description,
      'calorie_reduction': calorieReduction,
      'benefits': benefits,
      'preparation_tip': preparationTip,
    };
  }
}

/// Portion control advice
class PortionAdvice {
  final String ingredient;
  final String currentAssessment;
  final String recommendation;
  final String technique;
  final String visualGuide;

  PortionAdvice({
    required this.ingredient,
    required this.currentAssessment,
    required this.recommendation,
    required this.technique,
    required this.visualGuide,
  });

  factory PortionAdvice.fromJson(Map<String, dynamic> json) {
    return PortionAdvice(
      ingredient: json['ingredient'] ?? '',
      currentAssessment: json['current_assessment'] ?? '',
      recommendation: json['recommendation'] ?? '',
      technique: json['technique'] ?? '',
      visualGuide: json['visual_guide'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredient': ingredient,
      'current_assessment': currentAssessment,
      'recommendation': recommendation,
      'technique': technique,
      'visual_guide': visualGuide,
    };
  }
}

/// Meal balance advice
class MealBalanceAdvice {
  final String category;
  final String currentStatus;
  final String recommendation;
  final String reason;
  final List<String> examples;

  MealBalanceAdvice({
    required this.category,
    required this.currentStatus,
    required this.recommendation,
    required this.reason,
    required this.examples,
  });

  factory MealBalanceAdvice.fromJson(Map<String, dynamic> json) {
    return MealBalanceAdvice(
      category: json['category'] ?? '',
      currentStatus: json['current_status'] ?? '',
      recommendation: json['recommendation'] ?? '',
      reason: json['reason'] ?? '',
      examples: List<String>.from(json['examples'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'current_status': currentStatus,
      'recommendation': recommendation,
      'reason': reason,
      'examples': examples,
    };
  }
}
