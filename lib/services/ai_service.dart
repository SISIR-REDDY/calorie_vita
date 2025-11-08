import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import 'logger_service.dart';
import 'image_processing_service.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// AI Service for OpenRouter API integration
/// Handles all AI functionality including chat, analytics, recommendations, and image analysis
class AIService {
  // Enhanced configuration with production settings
  static String get _baseUrl => AIConfig.baseUrl;
  static String get _apiKey => AIConfig.apiKey;
  static String get _chatModel => AIConfig.chatModel;
  static String get _visionModel => AIConfig.visionModel;
  
  // Performance and caching
  static final LoggerService _logger = LoggerService();
  static final Map<String, String> _responseCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 45);

  /// Ask Trainer Sisir for fitness and nutrition advice with conversation context
  static Future<String> askTrainerSisir(
    String query, {
    Map<String, dynamic>? userProfile,
    List<Map<String, String>>? conversationHistory,
    Map<String, dynamic>? currentFitnessData,
  }) async {
    return await _logger.timeOperation('askTrainerSisir', () async {
      try {
        // Generate cache key
        final cacheKey = _generateCacheKey(query, userProfile, currentFitnessData);
        
        // Check cache first
        if (_responseCache.containsKey(cacheKey) && _cacheTimestamps.containsKey(cacheKey)) {
          final cacheTime = _cacheTimestamps[cacheKey]!;
          if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
            if (kDebugMode) debugPrint('⚡ AI Service: Using cached response');
            return _responseCache[cacheKey]!;
          } else {
            // Remove expired cache
            _responseCache.remove(cacheKey);
            _cacheTimestamps.remove(cacheKey);
          }
        }
      // Build user context from profile and fitness data
      String userContext = '';
      if (userProfile != null && userProfile.isNotEmpty) {
        userContext = _buildUserContextString(userProfile);
      }
      
      String fitnessContext = '';
      if (currentFitnessData != null && currentFitnessData.isNotEmpty) {
        fitnessContext = _buildFitnessContextString(currentFitnessData);
      }

      // Build conversation messages with context
      List<Map<String, dynamic>> messages = [
        {
          'role': 'system',
          'content':
              '''You are Trainer Sisir, a certified fitness and nutrition coach with 10+ years of experience helping people achieve their health goals. You're friendly, professional, and genuinely care about helping people succeed.

$userContext$fitnessContext

YOUR PERSONALITY:
- Warm and encouraging like a trusted friend
- Professional and knowledgeable like an expert coach
- Clear and direct without being harsh
- Understanding of challenges and setbacks
- Celebratory of progress, big or small

FOCUS ONLY ON:
• Exercise & workouts • Nutrition & diet • Weight management • Fitness goals
• Meal planning • Recovery & rest • Fitness motivation

NEVER DISCUSS:
- Medical advice (always say "Please consult your doctor for medical concerns")
- Injuries (say "For injuries, see a healthcare professional")
- Mental health therapy (refer to professionals)
- Relationships or personal life outside fitness
- Anything unrelated to fitness/nutrition

RESPONSE STYLE - FRIENDLY, PROFESSIONAL & FAST:
1. Opening: Warm greeting (1 sentence max)
   - Examples: "Hey! Great to hear from you!", "Hi! Let's work on this together.", "Hey there! I'm here to help."

2. Main Content: Clear, actionable advice (60-90 words)
   - Be specific with numbers and facts
   - Use their actual data when available
   - Reference their goals and progress
   - Give 2-3 actionable steps maximum
   - Use simple formatting: dashes (-) for lists

3. Closing: Brief encouragement (1 sentence)
   - Examples: "You've got this!", "Keep pushing forward!", "Small steps lead to big results!"

FORMATTING RULES:
- ABSOLUTELY NO MARKDOWN: Never use **, *, __, #, [], (), etc.
- Write PLAIN TEXT like texting a friend
- Use simple dashes (-) for lists, max 3 items
- Use line breaks for clarity (double line break between sections)
- 1 emoji max, only if it adds warmth

ACCURACY REQUIREMENTS:
- Always use their actual data: current calories, macros, weight, goals
- Reference specific numbers from their profile
- If data is missing, acknowledge it and provide general guidance
- Base recommendations on their actual fitness level and goals
- Adjust advice based on their progress (celebrate improvements!)

MEASUREMENT UNITS (USE INDIAN/METRIC ONLY):
- Weight: grams (g), kilograms (kg) - NEVER ounces (oz) or pounds (lbs)
- Liquids: milliliters (ml), liters (L) - NEVER cups or fluid ounces
- Distance: meters (m), kilometers (km) - NEVER miles or feet
- Height: centimeters (cm) - NEVER inches
- Example: "Aim for 120g protein daily" NOT "4 oz protein"
- Example: "Drink 2-3 liters water" NOT "8 cups water"

PERFECT EXAMPLE (COPY THIS STYLE):
"Hey! Great question about building muscle.

Based on your current stats, here's what will work:
- Protein: Aim for 1.6g per kg body weight (around 120g for you)
- Training: 4-5 strength sessions weekly, progressive overload
- Recovery: 7-8 hours sleep, rest days between workouts

You're making solid progress - keep it up! 💪"

ANOTHER EXAMPLE FOR NUTRITION:
"Hi! Your macros look good today.

To optimize for your weight loss goal:
- Cut refined carbs by 30g daily
- Add 20g more protein from lean sources
- Increase water to 3 liters daily

You're on the right track! 🔥"

CRITICAL RULES:
- Be friendly but professional - balance warmth with expertise
- Be accurate - always reference their actual data
- Be clear - simple language, no jargon unless explained
- Be fast - concise responses (60-90 words ideal)
- Be encouraging - celebrate progress and motivate
- NO markdown formatting ever - plain text only''',
        },
      ];

      // Add conversation history if provided (last 6 messages for maximum speed)
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        final recentHistory = conversationHistory.length > 6
            ? conversationHistory.sublist(conversationHistory.length - 6)
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

        final rawResult = response['choices'][0]['message']['content'] ??
            'Sorry, I couldn\'t process your request.';
        
        // Clean up any markdown formatting that slipped through
        final result = _cleanMarkdownFormatting(rawResult);
        
        // Cache the response for future use
        _cacheResponse(cacheKey, result);
        
        _logger.userAction('chat_query_completed', {
          'query_length': query.length,
          'has_profile': userProfile != null,
          'has_fitness_data': currentFitnessData != null,
        });
        
        return result;
      } catch (e) {
        _logger.error('Error in askTrainerSisir', {'query': query, 'error': e.toString()});
        if (e.toString().contains('AI_CREDITS_EXCEEDED')) {
          return '💡 AI credits exhausted. Please upgrade your plan or try again later.';
        } else if (e.toString().contains('AI_RATE_LIMIT')) {
          return '⏱️ AI service is busy. Please wait a moment and try again.';
        }
        return '⚠️ AI service temporarily unavailable. Please try again later.';
      }
    });
  }

  /// Get AI-powered analytics insights based on user data
  static Future<String> getAnalyticsInsights(
      Map<String, dynamic> userData, {
      Map<String, dynamic>? currentFitnessData,
    }) async {
    try {
      final dataSummary = _formatUserDataForAI(userData);
      
      // Add current fitness data if available
      String fitnessSummary = '';
      if (currentFitnessData != null && currentFitnessData.isNotEmpty) {
        fitnessSummary = '\n\nCURRENT FITNESS STATUS:\n${_formatFitnessDataForAI(currentFitnessData)}';
      }

      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content':
                '''You are a certified fitness and nutrition analytics expert. Provide accurate, actionable insights focused ONLY on fitness, nutrition, and wellness data.

ANALYSIS REQUIREMENTS:
- Keep response under 180 words
- Use clear sections with headers
- Focus on 2-3 key fitness/nutrition insights only
- Give specific numbers, percentages, and metrics
- Include 1 immediate actionable step
- Be encouraging about fitness progress
- Highlight fitness concerns with solutions

ALLOWED TOPICS:
• Calorie intake vs. goals and activity levels
• Macronutrient balance (protein, carbs, fats)
• Exercise consistency and intensity
• Weight and body composition trends
• Hydration and recovery patterns
• Sleep quality and fitness performance

PROFESSIONAL BOUNDARIES:
- Focus ONLY on fitness, nutrition, and wellness
- Do NOT provide medical advice or diagnosis
- Do NOT discuss mental health or medical conditions
- Redirect medical concerns to healthcare providers

FORMAT (NO MARKDOWN FORMATTING):
📊 Fitness Metrics
• [Specific number/percentage related to fitness]
• [Trend analysis for fitness goals]

🎯 Progress Status
• [Fitness goal achievement]
• [Nutrition/activity areas needing attention]

⚡ Action Items
• [Immediate fitness/nutrition step]
• [This week's focus area]

💪 Next Week Focus
• [Primary fitness/nutrition goal]

Be professional, encouraging, and strictly fitness-focused. Use specific numbers and actionable advice.''',
          },
          {
            'role': 'user',
            'content':
                'Analyze this health data and provide concise professional insights:\n\n$dataSummary$fitnessSummary',
          },
        ],
        isAnalyticsRequest: true,
      ).timeout(const Duration(seconds: 10)); // Add 10-second timeout

      return response['choices'][0]['message']['content'] ??
          'Unable to generate insights at this time.';
    } catch (e) {
      _logger.error('Error in getAnalyticsInsights', {'error': e.toString()});
      if (e.toString().contains('AI_CREDITS_EXCEEDED')) {
        return '📊 Analytics insights temporarily unavailable due to service limits.';
      } else if (e.toString().contains('AI_RATE_LIMIT')) {
        return '⏱️ Analytics service is busy. Please try again in a moment.';
      }
      return '📊 Analytics insights temporarily unavailable. Please try again later.';
    }
  }

  /// Get personalized health and nutrition recommendations
  static Future<String> getPersonalizedRecommendations(
      Map<String, dynamic> profile, {
      Map<String, dynamic>? currentFitnessData,
    }) async {
    try {
      final profileSummary = _formatProfileForAI(profile);
      
      // Add current fitness data if available
      String fitnessSummary = '';
      if (currentFitnessData != null && currentFitnessData.isNotEmpty) {
        fitnessSummary = '\n\nCURRENT FITNESS STATUS:\n${_formatFitnessDataForAI(currentFitnessData)}';
      }

      final response = await _makeRequest(
        model: _chatModel,
        messages: [
          {
            'role': 'system',
            'content':
                '''You are a certified fitness trainer and sports nutritionist. Provide accurate, personalized fitness and nutrition recommendations ONLY.

REQUIREMENTS:
- Keep under 280 words
- Focus on 4-5 key fitness/nutrition recommendations
- Give specific numbers (calories, macros, reps, sets, weights)
- Include realistic timeline and milestones
- Be actionable and practical for fitness goals

ALLOWED TOPICS:
• Fitness goals (strength, endurance, weight loss/gain)
• Nutrition targets (calories, macros, meal timing)
• Exercise programming (frequency, intensity, duration)
• Recovery and sleep optimization
• Supplement recommendations (if appropriate)
• Progress tracking methods

PROFESSIONAL BOUNDARIES:
- Focus ONLY on fitness, nutrition, and wellness
- Do NOT provide medical advice or diagnosis
- Do NOT discuss medications or medical treatments
- Redirect health concerns to healthcare providers

FORMAT (NO MARKDOWN FORMATTING):
🎯 Your Fitness Targets
• Calories: [number] based on [goal]
• Protein: [number]g daily for [muscle/fat loss]
• Training: [frequency] sessions/week

🥗 Nutrition Strategy
• [Main dietary approach for fitness goals]
• [Key foods for performance/recovery]
• [Meal timing for workouts]

💪 Training Plan
• [Exercise type and frequency]
• [Progressive overload strategy]
• [Recovery and rest days]

📅 Weekly Schedule
• [Specific workout days/times]
• [Nutrition milestones]

⚡ Start Today
• [Immediate fitness/nutrition action]

Be professional, specific, and motivating while maintaining strict fitness/nutrition focus.''',
          },
          {
            'role': 'user',
            'content':
                'Provide personalized recommendations for this profile:\n\n$profileSummary$fitnessSummary',
          },
        ],
        isAnalyticsRequest: true,
      );

      return response['choices'][0]['message']['content'] ??
          'Unable to generate recommendations at this time.';
    } catch (e) {
      _logger.error('Error in getPersonalizedRecommendations', {'error': e.toString()});
      if (e.toString().contains('AI_CREDITS_EXCEEDED')) {
        return '💡 Personalized recommendations temporarily unavailable due to service limits.';
      } else if (e.toString().contains('AI_RATE_LIMIT')) {
        return '⏱️ Recommendation service is busy. Please try again in a moment.';
      }
      return '💡 Personalized recommendations temporarily unavailable. Please try again later.';
    }
  }

  /// Detect calories and nutrition info from food image with high accuracy
  static Future<Map<String, dynamic>> detectCaloriesFromImage(
      File imageFile) async {
    return await _logger.timeOperation('detectCaloriesFromImage', () async {
      try {
        // Check if image analysis is enabled
        if (!AIConfig.enableImageAnalysis) {
          throw Exception('Image analysis is disabled');
        }
        
        // Validate API key
        if (_apiKey.isEmpty) {
          throw Exception('OpenRouter API key not configured');
        }
        
        // Use enhanced image processing service for better accuracy and speed
        final optimizedImageBytes = await ImageProcessingService.optimizeImageForAnalysis(imageFile);
        final base64Image = base64Encode(optimizedImageBytes);
        
        _logger.info('Image processed for AI analysis', {
          'original_size_kb': (await imageFile.readAsBytes()).length / 1024,
          'optimized_size_kb': optimizedImageBytes.length / 1024,
        });

      // Try primary model first
      try {
        final result = await _analyzeFoodWithModel(base64Image, _visionModel);
        if (result['confidence'] >= 0.7) {
          return result;
        }
        _logger.warning('Primary model confidence too low', {'confidence': result['confidence']});
      } catch (e) {
        _logger.warning('Primary model failed, trying backup', {'error': e.toString()});
      }

      // Try backup model if primary fails or confidence is low
      try {
        return await _analyzeFoodWithModel(
            base64Image, AIConfig.backupVisionModel);
      } catch (e) {
        _logger.error('Backup model also failed', {'error': e.toString()});
        throw Exception('All vision models failed');
      }
    } catch (e) {
      _logger.error('Error in detectCaloriesFromImage', {'error': e.toString()});
      String errorMessage = '⚠️ AI service unavailable, please try again later.';
      if (e.toString().contains('AI_CREDITS_EXCEEDED')) {
        errorMessage = '💡 Image analysis temporarily unavailable due to service limits.';
      } else if (e.toString().contains('AI_RATE_LIMIT')) {
        errorMessage = '⏱️ Image analysis service is busy. Please try again in a moment.';
      }
      
        return {
          'food': 'Unable to analyze',
          'calories': 0,
          'protein': '0g',
          'carbs': '0g',
          'fat': '0g',
          'serving_size': '1 serving',
          'confidence': 0.0,
          'error': errorMessage,
        };
      }
    });
  }

  /// Analyze food with specific model - Enhanced for accuracy
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
                  '''You are a certified fitness nutritionist and sports dietitian. Quickly analyze this food image and provide nutritional information focused on fitness and performance.

Focus on Indian cuisine and fitness nutrition. Be fast and accurate.

Return ONLY this JSON:
{
  "food": "Description of all visible foods",
  "calories": number,
  "protein": "X.Xg",
  "carbs": "X.Xg", 
  "fat": "X.Xg",
  "fiber": "X.Xg",
  "sugar": "X.Xg",
  "serving_size": "Portion description with weight",
  "confidence": 0.0-1.0,
  "analysis_details": {
    "ingredients_identified": ["ingredient1", "ingredient2"],
    "estimated_weight_grams": number,
    "cooking_method": "method used"
  },
  "breakdown": {
    "main_food": "Primary food item",
    "sides": ["Side dish 1", "Side dish 2"],
    "condiments": ["Sauces, oils, toppings"]
  },
  "fitness_analysis": {
    "pre_workout_suitable": true/false,
    "post_workout_suitable": true/false,
    "muscle_building_benefit": "high|medium|low",
    "recovery_benefit": "high|medium|low",
    "fitness_category": "muscle_building|fat_loss|performance|recovery"
  },
  "notes": "Brief fitness nutrition analysis"
}

Be accurate and realistic while focusing on fitness nutrition.''',
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
    _logger.debug('AI Vision Response', {'model': model, 'content': content});

    return _parseFoodAnalysisResponse(content);
  }

  /// Parse and validate food analysis response - Enhanced for accuracy
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

        // Extract analysis details
        final analysisDetails = parsed['analysis_details'] as Map<String, dynamic>? ?? {};
        final breakdown = parsed['breakdown'] as Map<String, dynamic>? ?? {};

        return {
          'food': (parsed['food'] ?? 'Unknown Food').toString().trim(),
          'calories': calories ?? 0,
          'protein': _formatMacro(parsed['protein']),
          'carbs': _formatMacro(parsed['carbs']),
          'fat': _formatMacro(parsed['fat']),
          'fiber': _formatMacro(parsed['fiber']),
          'sugar': _formatMacro(parsed['sugar']),
          'serving_size':
              (parsed['serving_size'] ?? '1 serving').toString().trim(),
          'confidence': validatedConfidence,
          'notes': parsed['notes']?.toString(),
          'breakdown': breakdown,
          'analysis_details': {
            'ingredients_identified': analysisDetails['ingredients_identified'] ?? [],
            'estimated_weight_grams': _parseNumber(analysisDetails['estimated_weight_grams']) ?? 0,
            'cooking_method': analysisDetails['cooking_method']?.toString() ?? 'Unknown',
          },
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      _logger.error('Error parsing food analysis JSON', {'error': e.toString(), 'content': content});
    }

    // Enhanced fallback with better text extraction
    return _extractFoodInfoFromText(content);
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
      _logger.debug('AI Barcode Response', {'content': content});

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
        _logger.error('Error parsing barcode JSON', {'error': e.toString()});
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
      _logger.error('Error in getNutritionFromBarcode', {'error': e.toString()});
      String errorMessage = '⚠️ AI service unavailable, please try again later.';
      if (e.toString().contains('AI_CREDITS_EXCEEDED')) {
        errorMessage = '💡 Barcode analysis temporarily unavailable due to service limits.';
      } else if (e.toString().contains('AI_RATE_LIMIT')) {
        errorMessage = '⏱️ Barcode analysis service is busy. Please try again in a moment.';
      }
      
      return {
        'food': 'Unable to analyze barcode',
        'calories': 0,
        'protein': '0g',
        'carbs': '0g',
        'fat': '0g',
        'serving_size': '1 serving',
        'confidence': 0.0,
        'error': errorMessage,
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
    // Validate API key
    if (kDebugMode) debugPrint('🔑 Using model: $model | API Key length: ${_apiKey.length}');
    if (_apiKey.isEmpty) {
      throw Exception('OpenRouter API key not configured');
    }

    // Validate inputs
    if (model.isEmpty) {
      throw Exception('Model name cannot be empty');
    }
    if (messages.isEmpty) {
      throw Exception('Messages cannot be empty');
    }

    // Determine appropriate token limit and temperature
    int maxTokens;
    double temperature;

    if (isVisionRequest) {
      maxTokens = AIConfig.visionMaxTokens;
      temperature = AIConfig.visionTemperature;
    } else if (isChatRequest) {
      // Optimize for speed: reduce tokens for faster responses
      maxTokens = 150; // Reduced from default for faster chat responses
      temperature = 0.7; // Balanced creativity and consistency
    } else if (isAnalyticsRequest) {
      maxTokens = AIConfig.analyticsMaxTokens;
      temperature = AIConfig.temperature;
    } else {
      maxTokens = AIConfig.maxTokens;
      temperature = AIConfig.temperature;
    }

    try {
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
      ).timeout(
        isChatRequest 
            ? const Duration(seconds: 10)  // Faster timeout for chat (10s)
            : const Duration(seconds: 15), // Standard timeout for other requests
        onTimeout: () {
          if (kDebugMode) debugPrint('⏱️ AI request timeout');
          throw TimeoutException('AI request timeout');
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 402) {
        // Credit limit exceeded
        if (kDebugMode) debugPrint('❌ API Error 402: Credits exceeded');
        throw Exception('AI_CREDITS_EXCEEDED');
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        if (kDebugMode) debugPrint('❌ API Error 429: Rate limit');
        throw Exception('AI_RATE_LIMIT');
      } else {
        if (kDebugMode) debugPrint('❌ API Error ${response.statusCode}: ${response.body}');
        throw Exception(
            'API request failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Request Exception: $e');
      if (e.toString().contains('AI_CREDITS_EXCEEDED') || 
          e.toString().contains('AI_RATE_LIMIT')) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  /// Format user data for AI analysis
  static String _formatUserDataForAI(Map<String, dynamic> userData) {
    final buffer = StringBuffer();

    // Basic info
    if (userData['age'] != null) buffer.writeln('Age: ${userData['age']}');
    if (userData['weight'] != null) {
      buffer.writeln('Weight: ${userData['weight']} kg');
    }
    if (userData['height'] != null) {
      buffer.writeln('Height: ${userData['height']} cm');
    }
    if (userData['activity_level'] != null) {
      buffer.writeln('Activity Level: ${userData['activity_level']}');
    }

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
    if (profile['gender'] != null) {
      buffer.writeln('Gender: ${profile['gender']}');
    }
    if (profile['weight'] != null) {
      buffer.writeln('Weight: ${profile['weight']} kg');
    }
    if (profile['height'] != null) {
      buffer.writeln('Height: ${profile['height']} cm');
    }
    if (profile['activity_level'] != null) {
      buffer.writeln('Activity Level: ${profile['activity_level']}');
    }

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

  /// Format current fitness data for AI analysis
  static String _formatFitnessDataForAI(Map<String, dynamic> fitnessData) {
    final buffer = StringBuffer();

    buffer.writeln('Today\'s Activity:');
    
    if (fitnessData['steps'] != null) {
      buffer.writeln('• Steps: ${fitnessData['steps']}');
    }
    
    if (fitnessData['caloriesBurned'] != null) {
      buffer.writeln('• Calories Burned: ${fitnessData['caloriesBurned']} kcal');
    }
    
    if (fitnessData['distance'] != null) {
      buffer.writeln('• Distance: ${fitnessData['distance']} km');
    }
    
    if (fitnessData['weight'] != null) {
      buffer.writeln('• Current Weight: ${fitnessData['weight']} kg');
    }
    
    if (fitnessData['activityLevel'] != null) {
      buffer.writeln('• Activity Level: ${fitnessData['activityLevel']}');
    }

    // Add timestamp if available
    if (fitnessData['timestamp'] != null) {
      try {
        final timestamp = DateTime.parse(fitnessData['timestamp']);
        final now = DateTime.now();
        final difference = now.difference(timestamp);
        
        if (difference.inMinutes < 60) {
          buffer.writeln('• Data Age: ${difference.inMinutes} minutes ago');
        } else if (difference.inHours < 24) {
          buffer.writeln('• Data Age: ${difference.inHours} hours ago');
        } else {
          buffer.writeln('• Data Age: ${difference.inDays} days ago');
        }
      } catch (e) {
        buffer.writeln('• Data Age: Recent');
      }
    }

    return buffer.toString();
  }

  /// Build user context string for chat
  static String _buildUserContextString(Map<String, dynamic> profile) {
    final buffer = StringBuffer();
    buffer.writeln('\n==== USER PROFILE ====');
    
    if (profile['name'] != null) {
      buffer.writeln('Name: ${profile['name']}');
    }
    if (profile['age'] != null) {
      buffer.writeln('Age: ${profile['age']} years');
    }
    if (profile['gender'] != null) {
      buffer.writeln('Gender: ${profile['gender']}');
    }
    if (profile['weight'] != null) {
      buffer.writeln('Current Weight: ${profile['weight']} kg');
    }
    if (profile['height'] != null) {
      buffer.writeln('Height: ${profile['height']} cm');
    }
    if (profile['fitnessGoal'] != null) {
      buffer.writeln('Fitness Goal: ${profile['fitnessGoal']}');
    }
    if (profile['activityLevel'] != null) {
      buffer.writeln('Activity Level: ${profile['activityLevel']}');
    }
    if (profile['dietPreference'] != null) {
      buffer.writeln('Diet Preference: ${profile['dietPreference']}');
    }
    if (profile['calorieGoal'] != null) {
      buffer.writeln('Daily Calorie Goal: ${profile['calorieGoal']} kcal');
    }
    if (profile['proteinGoal'] != null) {
      buffer.writeln('Protein Goal: ${profile['proteinGoal']}g');
    }
    if (profile['carbsGoal'] != null) {
      buffer.writeln('Carbs Goal: ${profile['carbsGoal']}g');
    }
    if (profile['fatGoal'] != null) {
      buffer.writeln('Fat Goal: ${profile['fatGoal']}g');
    }
    
    buffer.writeln('==================\n');
    return buffer.toString();
  }

  /// Build fitness context string for chat
  static String _buildFitnessContextString(Map<String, dynamic> fitnessData) {
    final buffer = StringBuffer();
    buffer.writeln('\n==== TODAY\'S DATA ====');
    
    if (fitnessData['caloriesConsumed'] != null) {
      buffer.writeln('Calories Consumed: ${fitnessData['caloriesConsumed']} kcal');
    }
    if (fitnessData['proteinConsumed'] != null) {
      buffer.writeln('Protein Consumed: ${fitnessData['proteinConsumed']}g');
    }
    if (fitnessData['carbsConsumed'] != null) {
      buffer.writeln('Carbs Consumed: ${fitnessData['carbsConsumed']}g');
    }
    if (fitnessData['fatConsumed'] != null) {
      buffer.writeln('Fat Consumed: ${fitnessData['fatConsumed']}g');
    }
    if (fitnessData['steps'] != null) {
      buffer.writeln('Steps: ${fitnessData['steps']}');
    }
    if (fitnessData['caloriesBurned'] != null) {
      buffer.writeln('Calories Burned: ${fitnessData['caloriesBurned']} kcal');
    }
    if (fitnessData['waterIntake'] != null) {
      buffer.writeln('Water Intake: ${fitnessData['waterIntake']} ml');
    }
    if (fitnessData['recentMeals'] != null) {
      buffer.writeln('Recent Meals: ${fitnessData['recentMeals']}');
    }
    
    buffer.writeln('==================\n');
    return buffer.toString();
  }

  /// Clean markdown formatting from AI response
  static String _cleanMarkdownFormatting(String text) {
    // Remove all markdown formatting characters
    String cleaned = text;
    
    // Remove bold (**text** or __text__)
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^\*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    
    // Remove italic (*text* or _text_)
    cleaned = cleaned.replaceAll(RegExp(r'\*([^\*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    
    // Remove headers (# text)
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    
    // Remove code blocks (```text```)
    cleaned = cleaned.replaceAll(RegExp(r'```[^`]*```'), '');
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    
    return cleaned;
  }
  
  /// Generate cache key for requests
  static String _generateCacheKey(String query, Map<String, dynamic>? userProfile, Map<String, dynamic>? fitnessData) {
    final profileHash = userProfile?.hashCode.toString() ?? 'no_profile';
    final fitnessHash = fitnessData?.hashCode.toString() ?? 'no_fitness';
    return '${query.hashCode}_${profileHash}_$fitnessHash';
  }
  
  /// Cache response for future use
  static void _cacheResponse(String cacheKey, String response) {
    // Limit cache size for memory efficiency
    if (_responseCache.length > 50) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _responseCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
    
    _responseCache[cacheKey] = response;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }
  
  /// Clear all cached responses
  static void clearCache() {
    _responseCache.clear();
    _cacheTimestamps.clear();
    _logger.info('AI service cache cleared');
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cache_size': _responseCache.length,
      'cache_keys': _responseCache.keys.toList(),
      'oldest_cache': _cacheTimestamps.values.isNotEmpty 
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
          : null,
      'newest_cache': _cacheTimestamps.values.isNotEmpty 
          ? _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b).toIso8601String()
          : null,
    };
  }
}

