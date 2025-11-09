import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/food_scan_result.dart';
import '../config/ai_config.dart';

/// Service for AI-powered food recognition using OpenRouter API
/// Uses the existing AIConfig for API key and model configuration
class GeminiFoodService {
  // Singleton pattern
  static final GeminiFoodService _instance = GeminiFoodService._internal();
  factory GeminiFoodService() => _instance;
  
  GeminiFoodService._internal();

  /// Recognize food from image and return detailed nutrition information
  Future<FoodScanResult> recognizeFood(File imageFile) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 Starting food recognition with ${AIConfig.visionModel}...');
      }

      // Read and encode image as base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Create prompt for food recognition
      final prompt = _createFoodRecognitionPrompt();
      
      // Make API request to OpenRouter using existing AIConfig
      final response = await http.post(
        Uri.parse(AIConfig.baseUrl),
        headers: {
          'Authorization': 'Bearer ${AIConfig.apiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': AIConfig.appUrl,
          'X-Title': AIConfig.appName,
        },
        body: json.encode({
          'model': AIConfig.visionModel, // Use configured vision model (gpt-4o-mini)
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'temperature': AIConfig.visionTemperature,
          'max_tokens': AIConfig.visionMaxTokens,
        }),
      ).timeout(AIConfig.requestTimeout);

      if (response.statusCode != 200) {
        throw Exception('OpenRouter API error: ${response.statusCode} - ${response.body}');
      }

      final responseData = json.decode(response.body);
      final aiResponse = responseData['choices'][0]['message']['content'] as String;
      
      // Parse JSON response
      final jsonResponse = _extractJson(aiResponse);
      
      if (kDebugMode) {
        debugPrint('✅ Food recognized: ${jsonResponse['dish_name']}');
        debugPrint('📊 Calories: ${jsonResponse['nutrition']['calories']}');
      }

      return FoodScanResult.fromJson(jsonResponse);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Food recognition error: $e');
      }
      rethrow;
    }
  }

  /// Create detailed prompt for food recognition
  String _createFoodRecognitionPrompt() {
    return '''
Analyze this food image and provide detailed nutrition information.

**IMPORTANT INSTRUCTIONS:**
1. Identify the main dish/food item
2. Determine the cuisine type (Indian, Chinese, Western, Thai, etc.)
3. Estimate the portion size in grams
4. List key ingredients with their approximate weights
5. Calculate total nutrition (calories, protein, carbs, fat)
6. Specify preparation method if visible (fried, grilled, steamed, etc.)
7. Identify regional variation if applicable (e.g., Hyderabadi Biryani, Punjabi Chole)

**FOCUS ON INDIAN CUISINE:**
- Be extremely accurate with Indian dishes (Biryani, Curry, Dal, Roti, etc.)
- Distinguish between similar dishes (e.g., Paneer Tikka vs Paneer Butter Masala)
- Account for oil/ghee used in Indian cooking
- Recognize regional variations (North, South, East, West Indian styles)

**OUTPUT FORMAT (JSON ONLY):**
{
  "dish_name": "Exact dish name",
  "cuisine": "Cuisine type",
  "portion_size_grams": 300,
  "ingredients": [
    {"name": "ingredient1", "weight_grams": 150, "calories": 200},
    {"name": "ingredient2", "weight_grams": 100, "calories": 150}
  ],
  "nutrition": {
    "calories": 650,
    "protein": 28,
    "carbs": 85,
    "fat": 22,
    "fiber": 5,
    "sugar": 3
  },
  "confidence": 0.85,
  "preparation_method": "fried/grilled/steamed/etc",
  "region": "Regional variation if applicable"
}

**RETURN ONLY THE JSON, NO MARKDOWN, NO EXPLANATIONS.**
''';
  }

  /// Extract JSON from response text
  Map<String, dynamic> _extractJson(String responseText) {
    try {
      // Remove markdown code blocks if present
      String jsonStr = responseText.trim();
      
      // Remove ```json and ``` if present
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      
      jsonStr = jsonStr.trim();
      
      // Parse JSON
      return json.decode(jsonStr) as Map<String, dynamic>;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ JSON parsing error: $e');
        debugPrint('Response text: $responseText');
      }
      
      // Return a fallback result
      return {
        'dish_name': 'Unknown Dish',
        'cuisine': 'Unknown',
        'portion_size_grams': 250,
        'ingredients': [],
        'nutrition': {
          'calories': 0,
          'protein': 0,
          'carbs': 0,
          'fat': 0,
        },
        'confidence': 0.3,
      };
    }
  }

  /// Quick estimation (for preview while waiting for full analysis)
  Future<Map<String, dynamic>> quickEstimate(File imageFile) async {
    try {
      // Read and encode image as base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      final prompt = '''
Quick food identification. Return ONLY JSON:
{"dish": "food name", "calories": estimated_calories}
''';
      
      // Make API request to OpenRouter using existing AIConfig
      final response = await http.post(
        Uri.parse(AIConfig.baseUrl),
        headers: {
          'Authorization': 'Bearer ${AIConfig.apiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': AIConfig.appUrl,
          'X-Title': AIConfig.appName,
        },
        body: json.encode({
          'model': AIConfig.visionModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'temperature': AIConfig.visionTemperature,
          'max_tokens': 50, // Minimal tokens for quick estimate
        }),
      ).timeout(AIConfig.requestTimeout);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final aiResponse = responseData['choices'][0]['message']['content'] as String;
        return _extractJson(aiResponse);
      }
      
      return {'dish': 'Unknown', 'calories': 0};
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Quick estimate error: $e');
      }
      return {'dish': 'Unknown', 'calories': 0};
    }
  }
}

