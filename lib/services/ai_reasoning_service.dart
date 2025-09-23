import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/nutrition_info.dart';
import '../models/food_recognition_result.dart';
import '../models/portion_estimation_result.dart';

/// Service for AI reasoning and food analysis using OpenRouter API
class AIReasoningService {
  static String get _baseUrl => AIConfig.baseUrl;
  static String get _apiKey => AIConfig.apiKey;
  static String get _chatModel => AIConfig.chatModel;

  /// Analyze food and provide comprehensive nutrition insights
  static Future<Map<String, dynamic>> analyzeFoodWithAI({
    required FoodRecognitionResult recognitionResult,
    required PortionEstimationResult portionResult,
    required NutritionInfo nutritionInfo,
    String? userProfile,
  }) async {
    try {
      final foodData = {
        'recognition': recognitionResult.toJson(),
        'portion': portionResult.toJson(),
        'nutrition': nutritionInfo.toJson(),
      };

      final response = await _makeAIRequest(
        'Analyze this food data and provide comprehensive insights:',
        foodData,
        userProfile,
      );

      return _parseAIResponse(response);
    } catch (e) {
      print('Error in AI food analysis: $e');
      return {
        'error': 'AI analysis failed: $e',
        'confidence': 0.0,
        'insights': [],
        'recommendations': [],
      };
    }
  }

  /// Get personalized nutrition recommendations
  static Future<Map<String, dynamic>> getPersonalizedRecommendations({
    required NutritionInfo nutritionInfo,
    String? userProfile,
    Map<String, dynamic>? dailyGoals,
  }) async {
    try {
      final requestData = {
        'nutrition': nutritionInfo.toJson(),
        'dailyGoals': dailyGoals ?? {},
      };

      final response = await _makeAIRequest(
        'Provide personalized nutrition recommendations based on this food:',
        requestData,
        userProfile,
      );

      return _parseAIResponse(response);
    } catch (e) {
      print('Error in AI recommendations: $e');
      return {
        'error': 'AI recommendations failed: $e',
        'recommendations': [],
        'tips': [],
      };
    }
  }

  /// Analyze meal composition and balance
  static Future<Map<String, dynamic>> analyzeMealBalance({
    required List<NutritionInfo> foods,
    String? userProfile,
  }) async {
    try {
      final mealData = {
        'foods': foods.map((f) => f.toJson()).toList(),
        'totalCalories': foods.fold(0.0, (sum, f) => sum + f.calories),
        'totalProtein': foods.fold(0.0, (sum, f) => sum + f.protein),
        'totalCarbs': foods.fold(0.0, (sum, f) => sum + f.carbs),
        'totalFat': foods.fold(0.0, (sum, f) => sum + f.fat),
      };

      final response = await _makeAIRequest(
        'Analyze this meal composition and provide balance insights:',
        mealData,
        userProfile,
      );

      return _parseAIResponse(response);
    } catch (e) {
      print('Error in AI meal analysis: $e');
      return {
        'error': 'AI meal analysis failed: $e',
        'balance': 'Unknown',
        'insights': [],
      };
    }
  }

  /// Get food substitution suggestions
  static Future<Map<String, dynamic>> getFoodSubstitutions({
    required NutritionInfo currentFood,
    String? userProfile,
    List<String>? dietaryRestrictions,
  }) async {
    try {
      final requestData = {
        'currentFood': currentFood.toJson(),
        'dietaryRestrictions': dietaryRestrictions ?? [],
      };

      final response = await _makeAIRequest(
        'Suggest healthier food substitutions for this item:',
        requestData,
        userProfile,
      );

      return _parseAIResponse(response);
    } catch (e) {
      print('Error in AI substitutions: $e');
      return {
        'error': 'AI substitutions failed: $e',
        'substitutions': [],
        'alternatives': [],
      };
    }
  }

  /// Analyze cooking method impact on nutrition
  static Future<Map<String, dynamic>> analyzeCookingMethod({
    required String foodName,
    required String cookingMethod,
    required NutritionInfo baseNutrition,
  }) async {
    try {
      final requestData = {
        'foodName': foodName,
        'cookingMethod': cookingMethod,
        'baseNutrition': baseNutrition.toJson(),
      };

      final response = await _makeAIRequest(
        'Analyze how this cooking method affects the nutrition:',
        requestData,
        null,
      );

      return _parseAIResponse(response);
    } catch (e) {
      print('Error in AI cooking analysis: $e');
      return {
        'error': 'AI cooking analysis failed: $e',
        'nutritionImpact': 'Unknown',
        'adjustments': {},
      };
    }
  }

  /// Get portion size recommendations
  static Future<Map<String, dynamic>> getPortionRecommendations({
    required String foodName,
    required double currentPortion,
    String? userProfile,
    Map<String, dynamic>? goals,
  }) async {
    try {
      final requestData = {
        'foodName': foodName,
        'currentPortion': currentPortion,
        'goals': goals ?? {},
      };

      final response = await _makeAIRequest(
        'Provide portion size recommendations for this food:',
        requestData,
        userProfile,
      );

      return _parseAIResponse(response);
    } catch (e) {
      print('Error in AI portion recommendations: $e');
      return {
        'error': 'AI portion recommendations failed: $e',
        'recommendedPortion': currentPortion,
        'reasoning': 'Unable to analyze',
      };
    }
  }

  /// Make AI request to OpenRouter API
  static Future<Map<String, dynamic>> _makeAIRequest(
    String prompt,
    Map<String, dynamic> data,
    String? userProfile,
  ) async {
    final messages = [
      {
        'role': 'system',
        'content': '''You are a professional nutritionist and food analysis expert. Analyze the provided food data and give comprehensive, actionable insights.

ANALYSIS REQUIREMENTS:
- Provide specific, actionable recommendations
- Use clear, professional language
- Include relevant numbers and percentages
- Consider Indian cuisine and dietary preferences
- Be encouraging and supportive
- Keep responses concise but comprehensive

RESPONSE FORMAT:
Return a JSON object with the following structure:
{
  "confidence": 0.0-1.0,
  "insights": ["insight1", "insight2", "insight3"],
  "recommendations": ["rec1", "rec2", "rec3"],
  "tips": ["tip1", "tip2"],
  "warnings": ["warning1", "warning2"],
  "substitutions": ["sub1", "sub2"],
  "cookingTips": ["tip1", "tip2"],
  "portionAdvice": "advice text",
  "nutritionScore": 0-100,
  "healthRating": "Excellent/Good/Fair/Poor"
}

Be specific, helpful, and encouraging in your analysis.''',
      },
      {
        'role': 'user',
        'content': '$prompt\n\nData: ${jsonEncode(data)}${userProfile != null ? '\n\nUser Profile: $userProfile' : ''}',
      },
    ];

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      },
      body: jsonEncode({
        'model': _chatModel,
        'messages': messages,
        'max_tokens': 100,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 402) {
      throw Exception('AI_CREDITS_EXCEEDED');
    } else if (response.statusCode == 429) {
      throw Exception('AI_RATE_LIMIT');
    } else {
      throw Exception('AI API request failed: ${response.statusCode} - ${response.body}');
    }
  }

  /// Parse AI response and extract structured data
  static Map<String, dynamic> _parseAIResponse(Map<String, dynamic> response) {
    try {
      final content = response['choices'][0]['message']['content'] as String? ?? '';
      
      // Try to parse JSON from the response
      String cleanedContent = content.trim();
      cleanedContent = cleanedContent.replaceAll('```json', '').replaceAll('```', '');
      
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedContent);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!.trim();
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }
      
      // Fallback: extract insights from text
      return _extractInsightsFromText(content);
    } catch (e) {
      print('Error parsing AI response: $e');
      return {
        'error': 'Failed to parse AI response',
        'confidence': 0.0,
        'insights': [],
        'recommendations': [],
      };
    }
  }

  /// Extract insights from text when JSON parsing fails
  static Map<String, dynamic> _extractInsightsFromText(String text) {
    final insights = <String>[];
    final recommendations = <String>[];
    final tips = <String>[];
    
    // Simple text extraction (in a real implementation, you'd use more sophisticated NLP)
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('*')) {
        final content = trimmed.substring(1).trim();
        if (content.toLowerCase().contains('recommend')) {
          recommendations.add(content);
        } else if (content.toLowerCase().contains('tip')) {
          tips.add(content);
        } else {
          insights.add(content);
        }
      }
    }
    
    return {
      'confidence': 0.6,
      'insights': insights,
      'recommendations': recommendations,
      'tips': tips,
      'warnings': [],
      'substitutions': [],
      'cookingTips': [],
      'portionAdvice': 'Consider portion size based on your goals',
      'nutritionScore': 70,
      'healthRating': 'Good',
    };
  }

  /// Get AI service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'available': true,
      'model': _chatModel,
      'maxTokens': AIConfig.maxTokens,
      'temperature': AIConfig.temperature,
      'features': [
        'Food Analysis',
        'Personalized Recommendations',
        'Meal Balance Analysis',
        'Food Substitutions',
        'Cooking Method Analysis',
        'Portion Recommendations',
      ],
    };
  }
}
