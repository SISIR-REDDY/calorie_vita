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

  /// Ask Trainer Sisir for fitness and nutrition advice with conversation context
  static Future<String> askTrainerSisir(
    String query, {
    Map<String, dynamic>? userProfile,
    List<Map<String, String>>? conversationHistory,
  }) async {
    try {
      // Prepare personalized context if profile data is available
      String personalizedContext = '';
      if (userProfile != null && userProfile.isNotEmpty) {
        personalizedContext = _formatProfileForAI(userProfile);
      }

      // Build conversation messages with context
      List<Map<String, dynamic>> messages = [
        {
          'role': 'system',
          'content':
              '''You are Trainer Sisir, a professional fitness and nutrition coach with 15+ years of experience. You provide concise, actionable advice like a real trainer.

${personalizedContext.isNotEmpty ? 'CLIENT PROFILE:\n$personalizedContext\n\n' : ''}RESPONSE GUIDELINES:
- Keep responses under 150 words
- Be direct and actionable
- Use bullet points for multiple items
- Give specific numbers (calories, reps, sets, days)
- Be encouraging but professional
- Reference previous conversations when relevant
- Focus on what they can do TODAY
- Use trainer language (e.g., "Let's hit", "Focus on", "Your target is")

EXAMPLE STYLE:
"Your maintenance is 2,200 calories. For fat loss, aim for 1,800-1,900 daily. 

This week's plan:
• Cardio: 4x 30min sessions
• Strength: 3x full body
• Protein: 140g daily

Start with meal prep Sunday - prep your proteins and veggies. Track everything in the app.

You got this! 💪"

Be concise, specific, and motivational like a real trainer.''',
        },
      ];

      // Add conversation history if provided (last 10 messages to maintain context)
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final recentHistory = conversationHistory.length > 10
            ? conversationHistory.sublist(conversationHistory.length - 10)
            : conversationHistory;

        for (final msg in recentHistory) {
          messages.add({
            'role': msg['role'] ?? 'user',
            'content': msg['content'] ?? '',
          });
        }
      }

      // Add current user query
      messages.add({
        'role': 'user',
        'content': query,
      });

      final response = await _makeRequest(
        model: _chatModel,
        messages: messages,
        isChatRequest: true,
      );

      return response['choices'][0]['message']['content'] ??
          'Sorry, I couldn\'t process your request.';
    } catch (e) {
      print('Error in askTrainerSisir: $e');
      return '⚠️ AI service unavailable, please try again later.';
    }
  }

  /// Get AI-powered analytics insights based on user data
  static Future<String> getAnalyticsInsights(
      Map<String, dynamic> userData) async {
    try {
      final dataSummary = _formatUserDataForAI(userData);

      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content':
                '''You are a professional health analytics expert. Provide concise, actionable insights from user data.

ANALYSIS REQUIREMENTS:
- Keep response under 200 words
- Use clear sections with headers
- Focus on 3-4 key insights only
- Give specific numbers and percentages
- Include 1-2 immediate action items
- Be encouraging about progress
- Highlight concerns briefly

FORMAT:
📊 **Key Metrics**
• [Specific number/percentage]
• [Trend analysis]

🎯 **Progress Status**
• [Goal achievement]
• [Areas of concern]

⚡ **Action Items**
• [Immediate step 1]
• [Immediate step 2]

💪 **Next Week Focus**
• [Primary goal]

Be professional, concise, and actionable.''',
          },
          {
            'role': 'user',
            'content':
                'Analyze this health data and provide concise professional insights:\n\n$dataSummary',
          },
        ],
        isAnalyticsRequest: true,
      );

      return response['choices'][0]['message']['content'] ??
          'Unable to generate insights at this time.';
    } catch (e) {
      print('Error in getAnalyticsInsights: $e');
      return '⚠️ AI service unavailable, please try again later.';
    }
  }

  /// Get personalized health and nutrition recommendations
  static Future<String> getPersonalizedRecommendations(
      Map<String, dynamic> profile) async {
    try {
      final profileSummary = _formatProfileForAI(profile);

      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content':
                '''You are a certified trainer and dietitian. Provide concise, personalized recommendations.

REQUIREMENTS:
- Keep under 250 words
- Focus on 4-5 key recommendations
- Give specific numbers (calories, macros, reps)
- Include timeline and milestones
- Be actionable and practical

FORMAT:
🎯 **Your Targets**
• Calories: [number]
• Protein: [number]g daily
• [Other key metrics]

🥗 **Nutrition Plan**
• [Main dietary focus]
• [Key foods to prioritize]

💪 **Workout Strategy**
• [Frequency and type]
• [Key exercises/sessions]

📅 **Weekly Schedule**
• [Specific days/times]
• [Milestone targets]

⚡ **Start Today**
• [Immediate first step]

Be professional, specific, and motivating.''',
          },
          {
            'role': 'user',
            'content':
                'Provide personalized recommendations for this profile:\n\n$profileSummary',
          },
        ],
        isAnalyticsRequest: true,
      );

      return response['choices'][0]['message']['content'] ??
          'Unable to generate recommendations at this time.';
    } catch (e) {
      print('Error in getPersonalizedRecommendations: $e');
      return '⚠️ AI service unavailable, please try again later.';
    }
  }

  /// Detect calories and nutrition info from food image with high accuracy
  static Future<Map<String, dynamic>> detectCaloriesFromImage(
      File imageFile) async {
    try {
      // Optimize image before sending
      final optimizedImageBytes = await _optimizeImageForAnalysis(imageFile);
      final base64Image = base64Encode(optimizedImageBytes);

      // Try primary model first
      try {
        final result = await _analyzeFoodWithModel(base64Image, _visionModel);
        if (result['confidence'] >= 0.7) {
          return result;
        }
        print(
            'Primary model confidence too low (${result['confidence']}), trying backup model');
      } catch (e) {
        print('Primary model failed: $e, trying backup model');
      }

      // Try backup model if primary fails or confidence is low
      try {
        return await _analyzeFoodWithModel(
            base64Image, AIConfig.backupVisionModel);
      } catch (e) {
        print('Backup model also failed: $e');
        throw Exception('All vision models failed');
      }
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

  /// Analyze food with specific model
  static Future<Map<String, dynamic>> _analyzeFoodWithModel(
      String base64Image, String model) async {
    final response = await _makeRequest(
      model: model,
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  '''You are an expert nutritionist and food scientist with 20+ years of experience. Analyze this food image with maximum accuracy.

CRITICAL ANALYSIS STEPS:
1. Identify EVERY food item visible (main dishes, sides, drinks, condiments)
2. Estimate portion sizes using common references (cup, slice, piece, etc.)
3. Consider cooking methods (fried, baked, grilled, raw, etc.)
4. Account for visible oils, sauces, and toppings
5. Calculate nutrition for the ENTIRE portion shown

ACCURACY REQUIREMENTS:
- Confidence must be 0.8+ for high accuracy
- Provide specific, realistic estimates
- Consider food density and preparation methods
- Account for all visible ingredients

Return ONLY this exact JSON format (no other text):
{
  "food": "Complete description of all foods visible",
  "calories": number,
  "protein": "X.Xg",
  "carbs": "X.Xg",
  "fat": "X.Xg",
  "serving_size": "Accurate portion description",
  "confidence": 0.0-1.0,
  "notes": "Cooking method and key ingredients",
  "breakdown": {
    "main_food": "Primary food item",
    "sides": ["Side dish 1", "Side dish 2"],
    "beverages": ["Any drinks visible"],
    "condiments": ["Sauces, oils, toppings"]
  }
}

Be extremely precise. If confidence < 0.8, provide conservative estimates.''',
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
      isVisionRequest: true,
    );

    final content = response['choices'][0]['message']['content'] ?? '';
    print('AI Vision Response ($model): $content');

    return _parseFoodAnalysisResponse(content);
  }

  /// Parse and validate food analysis response
  static Map<String, dynamic> _parseFoodAnalysisResponse(String content) {
    try {
      // Clean the response
      String cleanedContent = content.trim();
      cleanedContent =
          cleanedContent.replaceAll('```json', '').replaceAll('```', '');

      // Find JSON object with better regex
      final jsonMatch =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedContent);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!.trim();
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Validate and clean the parsed data
        final calories = _parseNumber(parsed['calories']);
        final confidence = _parseNumber(parsed['confidence']) ?? 0.5;

        // Validate confidence
        final validatedConfidence = confidence.clamp(0.0, 1.0);

        return {
          'food': (parsed['food'] ?? 'Unknown Food').toString().trim(),
          'calories': calories ?? 0,
          'protein': _formatMacro(parsed['protein']),
          'carbs': _formatMacro(parsed['carbs']),
          'fat': _formatMacro(parsed['fat']),
          'serving_size':
              (parsed['serving_size'] ?? '1 serving').toString().trim(),
          'confidence': validatedConfidence,
          'notes': parsed['notes']?.toString(),
          'breakdown': parsed['breakdown'],
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      print('Error parsing food analysis JSON: $e');
      print('Raw response: $content');
    }

    // Enhanced fallback with better text extraction
    return _extractFoodInfoFromText(content);
  }

  /// Optimize image for better AI analysis
  static Future<List<int>> _optimizeImageForAnalysis(File imageFile) async {
    try {
      // Read and decode image
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        print('Could not decode image, using original bytes');
        return imageBytes;
      }

      // Resize if too large (max 1024x1024 for better processing)
      img.Image optimizedImage = image;
      if (image.width > 1024 || image.height > 1024) {
        optimizedImage = img.copyResize(
          image,
          width: image.width > image.height ? 1024 : null,
          height: image.height > image.width ? 1024 : null,
          interpolation: img.Interpolation.linear,
        );
      }

      // Enhance contrast slightly for better recognition
      optimizedImage = img.contrast(optimizedImage, contrast: 1.1);

      // Convert back to bytes
      return img.encodeJpg(optimizedImage, quality: 90);
    } catch (e) {
      print('Error optimizing image: $e, using original');
      return await imageFile.readAsBytes();
    }
  }

  /// Parse number from dynamic value
  static double? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleanValue = value.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(cleanValue);
    }
    return null;
  }

  /// Format macro value properly
  static String _formatMacro(dynamic value) {
    if (value == null) return '0g';
    if (value is String) {
      final cleanValue = value.toString().trim();
      if (cleanValue.isEmpty) return '0g';
      if (cleanValue.contains('g')) return cleanValue;
      return '${cleanValue}g';
    }
    if (value is num) {
      return '${value.toStringAsFixed(1)}g';
    }
    return '0g';
  }

  /// Extract food info from text when JSON parsing fails (enhanced)
  static Map<String, dynamic> _extractFoodInfoFromText(String text) {
    final result = {
      'food': 'Food detected',
      'calories': 0,
      'protein': '0g',
      'carbs': '0g',
      'fat': '0g',
      'serving_size': '1 serving',
      'confidence': 0.4,
      'note':
          'AI analysis completed but format was unclear. Manual verification recommended.',
    };

    // Enhanced calorie extraction
    final caloriePatterns = [
      RegExp(r'(\d+)\s*calories?', caseSensitive: false),
      RegExp(r'calorie[:\s]*(\d+)', caseSensitive: false),
      RegExp(r'kcal[:\s]*(\d+)', caseSensitive: false),
    ];

    for (final pattern in caloriePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['calories'] = int.tryParse(match.group(1)!) ?? 0;
        break;
      }
    }

    // Enhanced food name extraction
    final foodPatterns = [
      RegExp(r'(?:food|item|dish|meal)[:\s]*([^.]+)', caseSensitive: false),
      RegExp(r'"food":\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'food[:\s]*([a-zA-Z\s]+)', caseSensitive: false),
    ];

    for (final pattern in foodPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['food'] = match.group(1)!.trim();
        break;
      }
    }

    // Extract macros
    final proteinMatch =
        RegExp(r'protein[:\s]*([0-9.]+g?)', caseSensitive: false)
            .firstMatch(text);
    if (proteinMatch != null) {
      result['protein'] = proteinMatch.group(1)!;
    }

    final carbsMatch = RegExp(r'(?:carbs|carbohydrates)[:\s]*([0-9.]+g?)',
            caseSensitive: false)
        .firstMatch(text);
    if (carbsMatch != null) {
      result['carbs'] = carbsMatch.group(1)!;
    }

    final fatMatch =
        RegExp(r'fat[:\s]*([0-9.]+g?)', caseSensitive: false).firstMatch(text);
    if (fatMatch != null) {
      result['fat'] = fatMatch.group(1)!;
    }

    // Extract serving size
    final servingMatch =
        RegExp(r'(?:serving|portion)[:\s]*([^.]+)', caseSensitive: false)
            .firstMatch(text);
    if (servingMatch != null) {
      result['serving_size'] = servingMatch.group(1)!.trim();
    }

    return result;
  }

  /// Get nutrition info from barcode using AI
  static Future<Map<String, dynamic>> getNutritionFromBarcode(
      String barcode) async {
    try {
      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content':
                '''You are a nutrition database expert. When given a barcode, provide nutritional information for the most likely product.

Return ONLY a valid JSON object in this exact format:
{
  "food": "Product name and description",
  "calories": number,
  "protein": "X.Xg",
  "carbs": "X.Xg",
  "fat": "X.Xg", 
  "serving_size": "Standard serving size",
  "confidence": 0.0-1.0,
  "notes": "Any additional info about the product"
}

If you cannot identify the product from the barcode, set confidence to 0.2 or lower and provide generic estimates based on the most likely product type.''',
          },
          {
            'role': 'user',
            'content': 'Provide nutritional information for barcode: $barcode',
          },
        ],
      );

      final content = response['choices'][0]['message']['content'] ?? '';
      print('AI Barcode Response: $content');

      // Try to parse JSON from the response
      try {
        String cleanedContent = content.trim();
        cleanedContent =
            cleanedContent.replaceAll('```json', '').replaceAll('```', '');

        final jsonMatch = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}')
            .firstMatch(cleanedContent);
        if (jsonMatch != null) {
          final jsonStr = jsonMatch.group(0)!.trim();
          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

          final calories = _parseNumber(parsed['calories']);
          final confidence = _parseNumber(parsed['confidence']) ?? 0.3;

          return {
            'food': (parsed['food'] ?? 'Unknown Product').toString(),
            'calories': calories ?? 0,
            'protein': _formatMacro(parsed['protein']),
            'carbs': _formatMacro(parsed['carbs']),
            'fat': _formatMacro(parsed['fat']),
            'serving_size': (parsed['serving_size'] ?? '1 serving').toString(),
            'confidence': confidence,
            'notes': parsed['notes']?.toString(),
            'barcode': barcode,
          };
        }
      } catch (e) {
        print('Error parsing barcode JSON: $e');
      }

      // Fallback for barcode
      return {
        'food': 'Product from barcode $barcode',
        'calories': 0,
        'protein': '0g',
        'carbs': '0g',
        'fat': '0g',
        'serving_size': '1 serving',
        'confidence': 0.2,
        'note':
            'Could not identify product from barcode. Please verify manually.',
        'barcode': barcode,
      };
    } catch (e) {
      print('Error in getNutritionFromBarcode: $e');
      return {
        'food': 'Unable to analyze barcode',
        'calories': 0,
        'protein': '0g',
        'carbs': '0g',
        'fat': '0g',
        'serving_size': '1 serving',
        'confidence': 0.0,
        'error': '⚠️ AI service unavailable, please try again later.',
        'barcode': barcode,
      };
    }
  }

  /// Make HTTP request to OpenRouter API
  static Future<Map<String, dynamic>> _makeRequest({
    required String model,
    required List<Map<String, dynamic>> messages,
    bool isVisionRequest = false,
    bool isChatRequest = false,
    bool isAnalyticsRequest = false,
  }) async {
    // Determine appropriate token limit and temperature
    int maxTokens;
    double temperature;

    if (isVisionRequest) {
      maxTokens = AIConfig.visionMaxTokens;
      temperature = AIConfig.visionTemperature;
    } else if (isChatRequest) {
      maxTokens = AIConfig.chatMaxTokens;
      temperature = AIConfig.temperature;
    } else if (isAnalyticsRequest) {
      maxTokens = AIConfig.analyticsMaxTokens;
      temperature = AIConfig.temperature;
    } else {
      maxTokens = AIConfig.maxTokens;
      temperature = AIConfig.temperature;
    }

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
        'max_tokens': maxTokens,
        'temperature': temperature,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'API request failed with status ${response.statusCode}: ${response.body}');
    }
  }

  /// Format user data for AI analysis
  static String _formatUserDataForAI(Map<String, dynamic> userData) {
    final buffer = StringBuffer();

    // Basic info
    if (userData['age'] != null) buffer.writeln('Age: ${userData['age']}');
    if (userData['weight'] != null)
      buffer.writeln('Weight: ${userData['weight']} kg');
    if (userData['height'] != null)
      buffer.writeln('Height: ${userData['height']} cm');
    if (userData['activity_level'] != null)
      buffer.writeln('Activity Level: ${userData['activity_level']}');

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
    if (profile['gender'] != null)
      buffer.writeln('Gender: ${profile['gender']}');
    if (profile['weight'] != null)
      buffer.writeln('Weight: ${profile['weight']} kg');
    if (profile['height'] != null)
      buffer.writeln('Height: ${profile['height']} cm');
    if (profile['activity_level'] != null)
      buffer.writeln('Activity Level: ${profile['activity_level']}');

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
