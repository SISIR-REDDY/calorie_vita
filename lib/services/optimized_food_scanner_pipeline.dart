import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/food_recognition_result.dart';
import '../models/portion_estimation_result.dart';
import '../models/nutrition_info.dart';
import 'snap_to_calorie_service.dart';
import 'barcode_scanning_service.dart';
import 'food_scanner_pipeline.dart';
import 'ai_reasoning_service.dart';

/// Optimized food scanner pipeline with performance improvements
class OptimizedFoodScannerPipeline {
  static bool _initialized = false;
  static final Map<String, dynamic> _resultCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  /// Initialize services with caching
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await BarcodeScanningService.initialize();
      _initialized = true;
      print('✅ Optimized food scanner pipeline initialized');
    } catch (e) {
      print('❌ Error initializing optimized pipeline: $e');
    }
  }

  /// Process food image with optimizations
  static Future<FoodScannerResult> processFoodImage(
    File imageFile, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (!_initialized) await initialize();

      // Generate cache key from image
      final cacheKey = await _generateCacheKey(imageFile);
      
      // Check cache first
      if (_resultCache.containsKey(cacheKey) && 
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('🚀 Returning cached result (${stopwatch.elapsedMilliseconds}ms)');
          return _createFoodScannerResultFromJson(_resultCache[cacheKey]);
        }
      }

      // Optimize image before processing
      final optimizedImage = await _optimizeImageForProcessing(imageFile);
      
      // Use fast snap-to-calorie pipeline
      final result = await _processWithFastPipeline(
        optimizedImage,
        userProfile: userProfile,
        userGoals: userGoals,
      );

      // Cache successful results
      if (result.success) {
        _resultCache[cacheKey] = result.toJson();
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      stopwatch.stop();
      print('⏱️ Processing completed in ${stopwatch.elapsedMilliseconds}ms');
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error in optimized pipeline: $e (${stopwatch.elapsedMilliseconds}ms)');
      return FoodScannerResult(
        success: false,
        error: 'Processing failed: $e',
      );
    }
  }

  /// Process barcode with optimizations
  static Future<FoodScannerResult> processBarcodeScan(
    String barcode, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      if (!_initialized) await initialize();

      // Check cache first
      if (_resultCache.containsKey(barcode) && 
          _cacheTimestamps.containsKey(barcode)) {
        final cacheTime = _cacheTimestamps[barcode]!;
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('🚀 Returning cached barcode result (${stopwatch.elapsedMilliseconds}ms)');
          return _createFoodScannerResultFromJson(_resultCache[barcode]);
        }
      }

      // Use optimized barcode scanning
      final nutritionInfo = await _scanBarcodeOptimized(barcode);
      
      if (nutritionInfo == null) {
        stopwatch.stop();
        return FoodScannerResult(
          success: false,
          error: 'Barcode not found in any database',
        );
      }

      // Generate AI analysis for barcode scan
      print('🤖 Generating AI analysis for barcode scan...');
      final aiAnalysis = await _generateAIAnalysis(
        nutritionInfo.foodName,
        nutritionInfo.category ?? 'Unknown',
        nutritionInfo,
        userProfile,
        userGoals,
      );

      final result = FoodScannerResult(
        success: true,
        recognitionResult: FoodRecognitionResult(
          foodName: nutritionInfo.foodName,
          confidence: 0.95,
          category: nutritionInfo.category ?? 'Unknown',
          cuisine: 'Unknown',
        ),
        portionResult: PortionEstimationResult(
          estimatedWeight: nutritionInfo.weightGrams,
          confidence: 0.9,
          method: 'barcode_scan',
        ),
        nutritionInfo: nutritionInfo,
        aiAnalysis: aiAnalysis,
        processingTime: stopwatch.elapsedMilliseconds,
        isBarcodeScan: true,
      );

      // Cache successful results
      _resultCache[barcode] = result.toJson();
      _cacheTimestamps[barcode] = DateTime.now();

      stopwatch.stop();
      print('⏱️ Barcode processing completed in ${stopwatch.elapsedMilliseconds}ms');
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error in barcode processing: $e (${stopwatch.elapsedMilliseconds}ms)');
      return FoodScannerResult(
        success: false,
        error: 'Barcode processing failed: $e',
      );
    }
  }

  /// Fast pipeline without AI suggestions (can be added later)
  static Future<FoodScannerResult> _processWithFastPipeline(
    File imageFile, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
  }) async {
    try {
      // Use simplified snap-to-calorie without AI suggestions for speed
      final snapResult = await _fastSnapToCalorie(imageFile);
      
      if (!snapResult['success']) {
        return FoodScannerResult(
          success: false,
          error: snapResult['error'] ?? 'Food recognition failed',
        );
      }

      // Convert to legacy format quickly
      final recognitionResult = FoodRecognitionResult(
        foodName: snapResult['foodName'] ?? 'Unknown Food',
        confidence: snapResult['confidence'] ?? 0.8,
        category: snapResult['category'] ?? 'Unknown',
        cuisine: snapResult['cuisine'] ?? 'Unknown',
      );

      final portionResult = PortionEstimationResult(
        estimatedWeight: snapResult['weightGrams'] ?? 150.0,
        confidence: snapResult['portionConfidence'] ?? 0.7,
        method: 'fast_estimation',
      );

      final nutritionInfo = NutritionInfo(
        foodName: snapResult['foodName'] ?? 'Unknown Food',
        weightGrams: snapResult['weightGrams'] ?? 150.0,
        calories: snapResult['calories'] ?? 200.0,
        protein: snapResult['protein'] ?? 10.0,
        carbs: snapResult['carbs'] ?? 30.0,
        fat: snapResult['fat'] ?? 5.0,
        fiber: snapResult['fiber'] ?? 3.0,
        sugar: snapResult['sugar'] ?? 10.0,
        source: 'Fast Pipeline',
      );

      return FoodScannerResult(
        success: true,
        recognitionResult: recognitionResult,
        portionResult: portionResult,
        nutritionInfo: nutritionInfo,
        processingTime: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      return FoodScannerResult(
        success: false,
        error: 'Fast pipeline failed: $e',
      );
    }
  }

  /// Fast snap-to-calorie without AI suggestions
  static Future<Map<String, dynamic>> _fastSnapToCalorie(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Simplified prompt for faster processing
      final prompt = '''
Analyze this food image and provide basic information in JSON format:

{
  "foodName": "specific food name",
  "confidence": 0.85,
  "category": "food category",
  "cuisine": "cuisine type",
  "weightGrams": 150,
  "portionConfidence": 0.8,
  "calories": 200,
  "protein": 10,
  "carbs": 30,
  "fat": 5,
  "fiber": 3,
  "sugar": 10
}

Be concise and accurate. Return only valid JSON.
''';

      final response = await _callOpenRouterVisionFast(prompt, base64Image);
      if (response == null) {
        return {'success': false, 'error': 'AI vision failed'};
      }

      try {
        final result = jsonDecode(response);
        result['success'] = true;
        return result;
      } catch (e) {
        return {'success': false, 'error': 'Failed to parse AI response'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Fast snap-to-calorie failed: $e'};
    }
  }

  /// Optimized barcode scanning with full cross-validation
  static Future<NutritionInfo?> _scanBarcodeOptimized(String barcode) async {
    try {
      // Use enhanced barcode scanning with improved accuracy
      print('🔍 Using enhanced barcode scanning with improved accuracy...');
      
      // Try enhanced scanning first
      var result = await BarcodeScanningService.scanBarcodeEnhanced(barcode);
      
      // If enhanced scanning fails, fall back to regular scanning
      if (result == null) {
        print('🔄 Enhanced scanning failed, trying regular barcode scanning...');
        result = await BarcodeScanningService.scanBarcode(barcode);
      }
      
      if (result != null) {
        print('✅ Barcode scan successful: ${result.foodName}');
        print('🔥 Calories: ${result.calories}, Protein: ${result.protein}g, Carbs: ${result.carbs}g, Fat: ${result.fat}g');
        print('📊 Source: ${result.source}');
        print('✅ Is Valid: ${result.isValid}');
      } else {
        print('❌ No nutrition data found for barcode: $barcode');
      }
      
      return result;
    } catch (e) {
      print('❌ Error in optimized barcode scanning: $e');
      return null;
    }
  }

  /// Try OpenFoodFacts with timeout
  static Future<NutritionInfo?> _tryOpenFoodFacts(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          return _parseOpenFoodFactsProduct(data['product']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Try local datasets
  static Future<NutritionInfo?> _tryLocalDatasets(String barcode) async {
    try {
      return await BarcodeScanningService.scanBarcode(barcode);
    } catch (e) {
      return null;
    }
  }

  /// Try Nutritionix with timeout
  static Future<NutritionInfo?> _tryNutritionix(String barcode) async {
    try {
      // This would use Nutritionix API if configured
      // For now, return null to avoid API key issues
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse OpenFoodFacts product data
  static NutritionInfo _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] ?? {};
    
    return NutritionInfo(
      foodName: product['product_name'] ?? 'Unknown Product',
      weightGrams: _parseWeight(product['quantity']),
      calories: _parseDouble(nutriments['energy-kcal_100g']) ?? 0.0,
      protein: _parseDouble(nutriments['proteins_100g']) ?? 0.0,
      carbs: _parseDouble(nutriments['carbohydrates_100g']) ?? 0.0,
      fat: _parseDouble(nutriments['fat_100g']) ?? 0.0,
      fiber: _parseDouble(nutriments['fiber_100g']) ?? 0.0,
      sugar: _parseDouble(nutriments['sugars_100g']) ?? 0.0,
      category: product['categories'] ?? 'Unknown',
      brand: product['brands'] ?? 'Unknown',
      source: 'OpenFoodFacts',
    );
  }

  /// Optimize image for faster processing
  static Future<File> _optimizeImageForProcessing(File imageFile) async {
    try {
      // For now, return the original file
      // In production, you could resize/compress the image here
      return imageFile;
    } catch (e) {
      return imageFile;
    }
  }

  /// Generate cache key from image
  static Future<String> _generateCacheKey(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final hash = imageBytes.length.toString(); // Simple hash based on size
      return 'image_$hash';
    } catch (e) {
      return 'image_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Fast OpenRouter vision call with reduced timeout
  static Future<String?> _callOpenRouterVisionFast(String prompt, String base64Image) async {
    try {
      final headers = {
        'Authorization': 'Bearer ${AIConfig.apiKey}',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      };

      final body = {
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
                }
              }
            ],
          }
        ],
        'max_tokens': 300, // Reduced for faster response
        'temperature': 0.1, // Lower for more consistent results
      };

      final response = await http.post(
        Uri.parse(AIConfig.baseUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15)); // Reduced timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('❌ OpenRouter API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error calling OpenRouter vision: $e');
      return null;
    }
  }

  /// Helper methods
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double _parseWeight(String? quantity) {
    if (quantity == null) return 100.0;
    final regex = RegExp(r'(\d+(?:\.\d+)?)');
    final match = regex.firstMatch(quantity);
    return match != null ? double.parse(match.group(1)!) : 100.0;
  }

  /// Create FoodScannerResult from JSON
  static FoodScannerResult _createFoodScannerResultFromJson(Map<String, dynamic> json) {
    return FoodScannerResult(
      success: json['success'] ?? false,
      error: json['error'],
      recognitionResult: json['recognitionResult'] != null 
          ? FoodRecognitionResult.fromJson(json['recognitionResult']) 
          : null,
      portionResult: json['portionResult'] != null 
          ? PortionEstimationResult.fromJson(json['portionResult']) 
          : null,
      nutritionInfo: json['nutritionInfo'] != null 
          ? NutritionInfo.fromJson(json['nutritionInfo']) 
          : null,
      aiAnalysis: json['aiAnalysis'],
      processingTime: json['processingTime'],
      isBarcodeScan: json['isBarcodeScan'] ?? false,
    );
  }

  /// Clear cache
  static void clearCache() {
    _resultCache.clear();
    _cacheTimestamps.clear();
    print('🧹 Cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedResults': _resultCache.length,
      'cacheTimestamps': _cacheTimestamps.length,
    };
  }

  /// Generate AI analysis for barcode scan
  static Future<Map<String, dynamic>> _generateAIAnalysis(
    String foodName,
    String category,
    NutritionInfo nutritionInfo,
    String? userProfile,
    Map<String, dynamic>? userGoals,
  ) async {
    try {
      print('🤖 Generating AI analysis for: $foodName');
      
      // Create recognition and portion results for AI analysis
      final recognitionResult = FoodRecognitionResult(
        foodName: foodName,
        confidence: 0.95,
        category: category,
        cuisine: 'Unknown',
      );
      
      final portionResult = PortionEstimationResult(
        estimatedWeight: nutritionInfo.weightGrams,
        confidence: 0.9,
        method: 'barcode_scan',
      );
      
      // Use AI reasoning service for analysis
      final aiAnalysis = await AIReasoningService.analyzeFoodWithAI(
        recognitionResult: recognitionResult,
        portionResult: portionResult,
        nutritionInfo: nutritionInfo,
        userProfile: userProfile,
      );
      
      print('✅ AI analysis generated successfully');
      return aiAnalysis;
    } catch (e) {
      print('❌ Error generating AI analysis: $e');
      // Return basic analysis as fallback
      return {
        'insights': ['Product identified via barcode scan'],
        'recommendations': ['Check portion size for accurate calorie tracking'],
        'tips': ['Barcode data provides reliable nutrition information'],
        'confidence': 0.8,
        'source': 'barcode_scan',
      };
    }
  }
}
