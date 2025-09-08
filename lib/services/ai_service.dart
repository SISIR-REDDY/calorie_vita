import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../config/ai_config.dart';

/// AI Service for OpenRouter API integration
/// Handles all AI functionality including chat, analytics, recommendations, and image analysis
class AIService {
  // Use configuration from AIConfig
  static String get _baseUrl => AIConfig.baseUrl;
  static String get _apiKey => AIConfig.apiKey;
  static String get _chatModel => AIConfig.chatModel;
  static String get _visionModel => AIConfig.visionModel;
  
  /// Ask Trainer Sisir for fitness and nutrition advice
  static Future<String> askTrainerSisir(String query, {Map<String, dynamic>? userProfile}) async {
    try {
      // Prepare personalized context if profile data is available
      String personalizedContext = '';
      if (userProfile != null && userProfile.isNotEmpty) {
        personalizedContext = _formatProfileForAI(userProfile);
      }
      
      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content': '''You are Trainer Sisir, a professional fitness and nutrition coach with 15+ years of experience. You provide personalized, evidence-based advice tailored to each individual's specific profile, goals, and circumstances.

${personalizedContext.isNotEmpty ? 'CURRENT CLIENT PROFILE:\n$personalizedContext\n\n' : ''}As Trainer Sisir, you should:
- Analyze the client's complete profile (height, weight, age, goals, activity level, dietary preferences)
- Provide specific, actionable recommendations based on their individual metrics
- Calculate appropriate calorie targets, macro ratios, and workout intensities
- Consider their lifestyle, preferences, and any limitations
- Give professional, encouraging, and motivating advice
- Use scientific principles for nutrition and fitness guidance
- Be specific with numbers, measurements, and timelines
- Address their current status and progress toward goals

Always personalize your response based on their profile data when available.''',
          },
          {
            'role': 'user',
            'content': query,
          },
        ],
      );
      
      return response['choices'][0]['message']['content'] ?? 'Sorry, I couldn\'t process your request.';
    } catch (e) {
      print('Error in askTrainerSisir: $e');
      return '⚠️ AI service unavailable, please try again later.';
    }
  }
  
  /// Get AI-powered analytics insights based on user data
  static Future<String> getAnalyticsInsights(Map<String, dynamic> userData) async {
    try {
      final dataSummary = _formatUserDataForAI(userData);
      
      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content': '''You are a professional health analytics expert and data scientist with expertise in fitness, nutrition, and wellness tracking. Analyze the provided user health data and provide comprehensive, evidence-based insights.

Your analysis should include:
- Detailed trend analysis of calories, steps, weight, and other metrics
- Identification of patterns, both positive and concerning
- Specific, actionable recommendations based on the data
- Professional assessment of progress toward goals
- Identification of areas needing attention or improvement
- Celebration of achievements and positive trends
- Scientific explanations for recommendations
- Specific numbers, percentages, and measurable targets
- Timeline-based action plans

Be thorough, professional, and encouraging while maintaining scientific accuracy.''',
          },
          {
            'role': 'user',
            'content': 'Analyze this comprehensive health data and provide detailed professional insights:\n\n$dataSummary',
          },
        ],
      );
      
      return response['choices'][0]['message']['content'] ?? 'Unable to generate insights at this time.';
    } catch (e) {
      print('Error in getAnalyticsInsights: $e');
      return '⚠️ AI service unavailable, please try again later.';
    }
  }
  
  /// Get personalized health and nutrition recommendations
  static Future<String> getPersonalizedRecommendations(Map<String, dynamic> profile) async {
    try {
      final profileSummary = _formatProfileForAI(profile);
      
      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content': '''You are a certified personal trainer and registered dietitian with 20+ years of experience. Provide highly personalized, evidence-based recommendations tailored to the individual's specific profile, goals, and circumstances.

Your recommendations should include:
- Personalized calorie and macro targets based on their height, weight, age, and goals
- Specific meal plans and food suggestions tailored to their dietary preferences
- Customized workout routines based on their fitness level and available equipment
- Lifestyle modifications specific to their schedule and preferences
- Supplement recommendations if appropriate
- Hydration and sleep optimization strategies
- Progress tracking methods and milestone targets
- Risk factors and health considerations
- Motivational strategies and habit formation techniques
- Specific timelines and measurable goals

Be extremely specific with numbers, measurements, and actionable steps. Consider their complete profile including medical history, limitations, and preferences.''',
          },
          {
            'role': 'user',
            'content': 'Provide comprehensive personalized recommendations based on this detailed profile:\n\n$profileSummary',
          },
        ],
      );
      
      return response['choices'][0]['message']['content'] ?? 'Unable to generate recommendations at this time.';
    } catch (e) {
      print('Error in getPersonalizedRecommendations: $e');
      return '⚠️ AI service unavailable, please try again later.';
    }
  }
  
  /// Detect calories and nutrition info from food image
  static Future<Map<String, dynamic>> detectCaloriesFromImage(File imageFile) async {
    try {
      // Convert image to base64
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      final response = await _makeRequest(
        model: _visionModel,
        messages: [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Analyze this food image and provide detailed nutritional information. Return the response in this exact JSON format: {"food": "Food Name", "calories": number, "protein": "Xg", "carbs": "Xg", "fat": "Xg", "serving_size": "X serving(s)"}. Be as accurate as possible with calorie estimates.',
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
      );
      
      final content = response['choices'][0]['message']['content'] ?? '';
      
      // Try to parse JSON from the response
      try {
        // Extract JSON from the response (it might be wrapped in text)
        final jsonMatch = RegExp(r'\{.*\}').firstMatch(content);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!;
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          
          return {
            'food': parsed['food'] ?? 'Unknown Food',
            'calories': parsed['calories'] ?? 0,
            'protein': parsed['protein'] ?? '0g',
            'carbs': parsed['carbs'] ?? '0g',
            'fat': parsed['fat'] ?? '0g',
            'serving_size': parsed['serving_size'] ?? '1 serving',
            'confidence': 0.8, // Default confidence
          };
        }
      } catch (e) {
        print('Error parsing JSON from AI response: $e');
      }
      
      // Fallback: return basic info if JSON parsing fails
      return {
        'food': 'Food detected',
        'calories': 300, // Default estimate
        'protein': '15g',
        'carbs': '45g',
        'fat': '10g',
        'serving_size': '1 serving',
        'confidence': 0.5,
        'note': 'AI analysis completed but couldn\'t parse detailed nutrition info.',
      };
    } catch (e) {
      print('Error in detectCaloriesFromImage: $e');
      return {
        'food': 'Unable to analyze',
        'calories': 0,
        'protein': '0g',
        'carbs': '0g',
        'fat': '0g',
        'serving_size': '1 serving',
        'confidence': 0.0,
        'error': '⚠️ AI service unavailable, please try again later.',
      };
    }
  }
  
  /// Make HTTP request to OpenRouter API
  static Future<Map<String, dynamic>> _makeRequest({
    required String model,
    required List<Map<String, dynamic>> messages,
  }) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': AIConfig.maxTokens,
        'temperature': AIConfig.temperature,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('API request failed with status ${response.statusCode}: ${response.body}');
    }
  }
  
  /// Format user data for AI analysis
  static String _formatUserDataForAI(Map<String, dynamic> userData) {
    final buffer = StringBuffer();
    
    // Basic info
    if (userData['age'] != null) buffer.writeln('Age: ${userData['age']}');
    if (userData['weight'] != null) buffer.writeln('Weight: ${userData['weight']} kg');
    if (userData['height'] != null) buffer.writeln('Height: ${userData['height']} cm');
    if (userData['activity_level'] != null) buffer.writeln('Activity Level: ${userData['activity_level']}');
    
    // Goals
    if (userData['goals'] != null) {
      buffer.writeln('\nGoals:');
      final goals = userData['goals'] as Map<String, dynamic>?;
      goals?.forEach((key, value) {
        if (value != null) buffer.writeln('- $key: $value');
      });
    }
    
    // Recent data
    if (userData['recent_calories'] != null) {
      buffer.writeln('\nRecent Calorie Intake:');
      final calories = userData['recent_calories'] as List<dynamic>?;
      calories?.forEach((day) {
        if (day is Map<String, dynamic>) {
          buffer.writeln('- ${day['date']}: ${day['calories']} calories');
        }
      });
    }
    
    if (userData['recent_steps'] != null) {
      buffer.writeln('\nRecent Steps:');
      final steps = userData['recent_steps'] as List<dynamic>?;
      steps?.forEach((day) {
        if (day is Map<String, dynamic>) {
          buffer.writeln('- ${day['date']}: ${day['steps']} steps');
        }
      });
    }
    
    // Health metrics
    if (userData['health_metrics'] != null) {
      buffer.writeln('\nHealth Metrics:');
      final metrics = userData['health_metrics'] as Map<String, dynamic>?;
      metrics?.forEach((key, value) {
        if (value != null) buffer.writeln('- $key: $value');
      });
    }
    
    return buffer.toString();
  }
  
  /// Format user profile for AI recommendations
  static String _formatProfileForAI(Map<String, dynamic> profile) {
    final buffer = StringBuffer();
    
    // Basic profile
    buffer.writeln('User Profile:');
    if (profile['name'] != null) buffer.writeln('Name: ${profile['name']}');
    if (profile['age'] != null) buffer.writeln('Age: ${profile['age']}');
    if (profile['gender'] != null) buffer.writeln('Gender: ${profile['gender']}');
    if (profile['weight'] != null) buffer.writeln('Weight: ${profile['weight']} kg');
    if (profile['height'] != null) buffer.writeln('Height: ${profile['height']} cm');
    if (profile['activity_level'] != null) buffer.writeln('Activity Level: ${profile['activity_level']}');
    
    // Goals and preferences
    if (profile['goals'] != null) {
      buffer.writeln('\nGoals:');
      final goals = profile['goals'] as Map<String, dynamic>?;
      goals?.forEach((key, value) {
        if (value != null) buffer.writeln('- $key: $value');
      });
    }
    
    if (profile['dietary_preferences'] != null) {
      buffer.writeln('\nDietary Preferences:');
      final prefs = profile['dietary_preferences'] as List<dynamic>?;
      prefs?.forEach((pref) => buffer.writeln('- $pref'));
    }
    
    if (profile['allergies'] != null) {
      buffer.writeln('\nAllergies:');
      final allergies = profile['allergies'] as List<dynamic>?;
      allergies?.forEach((allergy) => buffer.writeln('- $allergy'));
    }
    
    // Current status
    if (profile['current_calories'] != null) {
      buffer.writeln('\nCurrent Status:');
      buffer.writeln('Today\'s Calories: ${profile['current_calories']}');
      if (profile['calorie_goal'] != null) {
        buffer.writeln('Calorie Goal: ${profile['calorie_goal']}');
      }
    }
    
    return buffer.toString();
  }
}