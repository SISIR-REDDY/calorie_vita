import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import '../models/food_recognition_result.dart';
import '../models/portion_estimation_result.dart';
import '../models/nutrition_info.dart';
import 'barcode_scanning_service.dart';
import 'network_service.dart';

// Import TimeoutException from network_service
// TimeoutException is defined in network_service.dart

/// Simple result class for food scanner pipeline
class FoodScannerResult {
  final bool success;
  final NutritionInfo? nutritionInfo;
  final PortionEstimationResult? portionResult;
  final FoodRecognitionResult? recognitionResult;
  final int processingTime;
  final String source;
  final String? message;
  final String? error;
  final Map<String, dynamic>? aiAnalysis;
  final bool isBarcodeScan;
  final Map<String, dynamic>? snapToCalorieResult;
  final double confidencePercentage;

  FoodScannerResult({
    required this.success,
    this.nutritionInfo,
    this.portionResult,
    this.recognitionResult,
    this.processingTime = 0,
    this.source = 'unknown',
    this.message,
    this.error,
    this.aiAnalysis,
    this.isBarcodeScan = false,
    this.snapToCalorieResult,
    this.confidencePercentage = 0.0,
  });
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'nutritionInfo': nutritionInfo?.toJson(),
      'portionResult': portionResult?.toJson(),
      'recognitionResult': recognitionResult?.toJson(),
      'processingTime': processingTime,
      'source': source,
      'message': message,
      'error': error,
      'aiAnalysis': aiAnalysis,
      'isBarcodeScan': isBarcodeScan,
      'snapToCalorieResult': snapToCalorieResult,
      'confidencePercentage': confidencePercentage,
    };
  }
}

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
      print('🖼️ Processing food image...');
      if (!_initialized) {
        print('⚙️ Initializing pipeline...');
        await initialize();
      }
      
      // CRITICAL: Ensure AIConfig is initialized and API key is loaded
      print('🔍 Verifying AI configuration...');
      if (AIConfig.apiKey.isEmpty) {
        print('⚠️ API key is empty - attempting to initialize AIConfig...');
        try {
          await AIConfig.initialize();
          await Future.delayed(const Duration(milliseconds: 500)); // Wait for Firestore to load
          await AIConfig.refresh(); // Force refresh
        } catch (e) {
          print('❌ Failed to initialize AIConfig: $e');
        }
        
        // Check again after initialization
        if (AIConfig.apiKey.isEmpty) {
          print('❌ API key is still empty after initialization attempt');
          print('   This means Firestore config may not be loaded or API key is missing');
          return FoodScannerResult(
            success: false,
            error: 'AI service is not configured. Please check your settings or add food manually.',
          );
        } else {
          print('✅ API key loaded after initialization: ${AIConfig.apiKey.length} characters');
        }
      } else {
        print('✅ API key is present: ${AIConfig.apiKey.length} characters');
      }
      
      // Verify vision model is configured
      print('👁️ Vision model: ${AIConfig.visionModel}');
      print('👁️ Image analysis enabled: ${AIConfig.enableImageAnalysis}');
      
      if (!AIConfig.enableImageAnalysis) {
        print('❌ Image analysis is disabled in configuration');
        return FoodScannerResult(
          success: false,
          error: 'Image analysis is disabled. Please enable it in settings or add food manually.',
        );
      }

      // Generate cache key from image (fast - just use file path hash)
      final cacheKey = await _generateCacheKey(imageFile);
      print('🔑 Cache key: $cacheKey');
      
      // Check cache first (fast path)
      if (_resultCache.containsKey(cacheKey) && 
          _cacheTimestamps.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey]!;
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('🚀 Returning cached result (${stopwatch.elapsedMilliseconds}ms)');
          stopwatch.stop();
          return _createFoodScannerResultFromJson(_resultCache[cacheKey]);
        } else {
          print('⏰ Cache expired, processing fresh...');
        }
      } else {
        print('📝 No cache found, processing fresh image...');
      }

      // Skip image optimization for speed - process directly
      // print('🔄 Optimizing image for processing...');
      // final optimizedImage = await _optimizeImageForProcessing(imageFile);
      
      // Use fast snap-to-calorie pipeline directly
      print('🤖 Starting fast AI vision pipeline...');
      final result = await _processWithFastPipeline(
        imageFile, // Use original file directly
        userProfile: userProfile,
        userGoals: userGoals,
      );
      print('✅ Fast pipeline completed: success=${result.success}');

      // Validate and fix result if needed
      if (result.success && result.nutritionInfo != null) {
        final nutrition = result.nutritionInfo!;
        
      // Validate nutrition data - be more lenient
      if (nutrition.calories == 0) {
        // Only fix if calories are truly 0 (not just low)
        print('⚠️ Calories are 0, attempting to fix from macros...');
        
        // Try to estimate calories from macros
        if (nutrition.protein > 0 || nutrition.carbs > 0 || nutrition.fat > 0) {
          final estimatedCalories = (nutrition.protein * 4) + 
                                   (nutrition.carbs * 4) + 
                                   (nutrition.fat * 9);
          if (estimatedCalories > 0) {
            print('🔧 Fixed calories from macros: $estimatedCalories kcal');
            final fixedResult = FoodScannerResult(
              success: true,
              recognitionResult: result.recognitionResult,
              portionResult: result.portionResult,
              nutritionInfo: nutrition.copyWith(calories: estimatedCalories),
              aiAnalysis: result.aiAnalysis,
              processingTime: result.processingTime,
              isBarcodeScan: result.isBarcodeScan,
              confidencePercentage: result.confidencePercentage * 0.9, // Slightly lower confidence
            );
            
            // Cache the fixed result
            _resultCache[cacheKey] = fixedResult.toJson();
            _cacheTimestamps[cacheKey] = DateTime.now();
            
            stopwatch.stop();
            return fixedResult;
          }
        }
        
        // If we can't fix it, return error
        print('❌ Cannot fix: no calories and no macros available');
        stopwatch.stop();
        return FoodScannerResult(
          success: false,
          error: 'Could not determine calories for this food. Please try again or enter manually.',
        );
      }
      
      // Additional validation: check if calories match macros
      if (nutrition.calories > 0 && (nutrition.protein > 0 || nutrition.carbs > 0 || nutrition.fat > 0)) {
        final calculatedCalories = (nutrition.protein * 4) + 
                                   (nutrition.carbs * 4) + 
                                   (nutrition.fat * 9);
        if (calculatedCalories > 0) {
          final difference = (nutrition.calories - calculatedCalories).abs();
          final percentDiff = (difference / nutrition.calories) * 100;
          
          if (percentDiff > 30) {
            print('⚠️ Large calorie mismatch: ${percentDiff.toStringAsFixed(1)}%');
            print('   Reported: ${nutrition.calories} kcal');
            print('   Calculated: ${calculatedCalories.toStringAsFixed(0)} kcal');
            print('   Keeping reported values - may be correct for this food type');
          }
        }
      }
      }

      // Cache successful results
      if (result.success && result.nutritionInfo != null && result.nutritionInfo!.isValid) {
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
      print('🔍 Processing barcode scan...');
      if (!_initialized) {
        print('⚙️ Initializing pipeline...');
        await initialize();
      }

      // Clean barcode
      final cleanBarcode = barcode.replaceAll(RegExp(r'[^0-9]'), '');
      print('🧹 Cleaned barcode: $cleanBarcode (original: $barcode)');
      if (cleanBarcode.length < 8) {
        print('❌ Invalid barcode length: ${cleanBarcode.length}');
        return FoodScannerResult(
          success: false,
          error: 'Invalid barcode format. Please scan a valid barcode.',
        );
      }

      // Check cache first
      if (_resultCache.containsKey(cleanBarcode) && 
          _cacheTimestamps.containsKey(cleanBarcode)) {
        final cacheTime = _cacheTimestamps[cleanBarcode]!;
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('🚀 Returning cached barcode result (${stopwatch.elapsedMilliseconds}ms)');
          final cached = _createFoodScannerResultFromJson(_resultCache[cleanBarcode]);
          // Validate cached result
          if (cached.nutritionInfo != null && cached.nutritionInfo!.isValid) {
            return cached;
          } else {
            print('⚠️ Cached result invalid, processing fresh...');
          }
        } else {
          print('⏰ Cache expired, processing fresh...');
        }
      } else {
        print('📝 No cache found, processing fresh barcode...');
      }

      // Use optimized barcode scanning
      print('🔍 Starting optimized barcode scanning...');
      var nutritionInfo = await _scanBarcodeOptimized(cleanBarcode);
      
      // Don't validate/fix here - BarcodeScanningService already did that
      // Just check if data is valid
      if (nutritionInfo != null) {
        print('📊 Barcode scan result:');
        print('   Product: ${nutritionInfo.foodName}');
        print('   Calories: ${nutritionInfo.calories}, Protein: ${nutritionInfo.protein}g, Carbs: ${nutritionInfo.carbs}g, Fat: ${nutritionInfo.fat}g');
        print('   Weight: ${nutritionInfo.weightGrams}g, Source: ${nutritionInfo.source}');
        
        // Only check validity - don't modify data that's already been validated
        if (!nutritionInfo.isValid) {
          print('⚠️ Invalid nutrition data from barcode scan');
        }
      }
      
      if (nutritionInfo == null || !nutritionInfo.isValid) {
        stopwatch.stop();
        return FoodScannerResult(
          success: false,
          error: 'Barcode not found in database. Try scanning again or enter manually.',
        );
      }

      // Use nutrition info as-is - it's already been validated by BarcodeScanningService
      // Don't modify it again here (that causes double-processing and incorrect values)
      final finalNutritionInfo = nutritionInfo;
      
      // Only validate basic sanity - don't modify values
      if (finalNutritionInfo.calories > 0 && finalNutritionInfo.weightGrams > 0) {
        final caloriesPerGram = finalNutritionInfo.calories / finalNutritionInfo.weightGrams;
        // Check if calories per gram is reasonable (typically 0.5-10 kcal/g)
        if (caloriesPerGram > 10) {
          print('⚠️ Warning: Very high calories per gram (${caloriesPerGram.toStringAsFixed(2)} kcal/g)');
          print('   Product: ${finalNutritionInfo.foodName}, Source: ${finalNutritionInfo.source}');
          print('   Keeping values as-is - may be correct for this product type');
        } else {
          print('✅ Nutrition data validated: ${caloriesPerGram.toStringAsFixed(2)} kcal/g (reasonable)');
        }
      }

      // Skip AI analysis for barcode scans - it's slow and not critical
      // Generate AI analysis asynchronously (non-blocking) - don't wait for it
      final aiAnalysis = <String, dynamic>{}; // Return empty - skip for speed
      // _generateAIAnalysis(
      //   nutritionInfo.foodName,
      //   nutritionInfo.category ?? 'Unknown',
      //   nutritionInfo,
      //   userProfile,
      //   userGoals,
      // ).catchError((e) {
      //   print('⚠️ AI analysis failed, continuing without it: $e');
      //   return <String, dynamic>{};
      // });

      final result = FoodScannerResult(
        success: true,
        recognitionResult: FoodRecognitionResult(
          foodName: finalNutritionInfo.foodName,
          confidence: 0.95,
          category: finalNutritionInfo.category ?? 'Unknown',
          cuisine: 'Unknown',
        ),
        portionResult: PortionEstimationResult(
          estimatedWeight: finalNutritionInfo.weightGrams > 0 ? finalNutritionInfo.weightGrams : 100.0,
          confidence: 0.9,
          method: 'barcode_scan',
        ),
        nutritionInfo: finalNutritionInfo,
        aiAnalysis: aiAnalysis,
        processingTime: stopwatch.elapsedMilliseconds,
        isBarcodeScan: true,
        confidencePercentage: 95.0,
      );

      // Cache successful results
      _resultCache[cleanBarcode] = result.toJson();
      _cacheTimestamps[cleanBarcode] = DateTime.now();

      stopwatch.stop();
      print('⏱️ Barcode processing completed in ${stopwatch.elapsedMilliseconds}ms');
      print('✅ Product: ${finalNutritionInfo.foodName}');
      print('🔥 Calories: ${finalNutritionInfo.calories}');
      print('📊 Macros: P${finalNutritionInfo.protein}g C${finalNutritionInfo.carbs}g F${finalNutritionInfo.fat}g');
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ Error in barcode processing: $e (${stopwatch.elapsedMilliseconds}ms)');
      return FoodScannerResult(
        success: false,
        error: 'Failed to process barcode: ${e.toString()}',
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

      // Use weight from AI response, don't default to 150g
      final estimatedWeight = _parseDouble(snapResult['weightGrams']) ?? 100.0;
      final portionResult = PortionEstimationResult(
        estimatedWeight: estimatedWeight > 0 ? estimatedWeight : 100.0,
        confidence: _parseDouble(snapResult['portionConfidence']) ?? 0.7,
        method: 'fast_estimation',
      );

      final foodName = snapResult['foodName']?.toString() ?? 'Food Item';
      final weightGrams = estimatedWeight;
      final calories = _parseDouble(snapResult['calories']) ?? 0.0;
      final protein = _parseDouble(snapResult['protein']) ?? 0.0;
      final carbs = _parseDouble(snapResult['carbs']) ?? 0.0;
      final fat = _parseDouble(snapResult['fat']) ?? 0.0;
      final fiber = _parseDouble(snapResult['fiber']) ?? 0.0;
      final sugar = _parseDouble(snapResult['sugar']) ?? 0.0;
      
      // Calculate calories from macros ONLY if calories are truly 0 (not just low)
      double finalCalories = calories;
      if (calories == 0 && (protein > 0 || carbs > 0 || fat > 0)) {
        finalCalories = (protein * 4) + (carbs * 4) + (fat * 9);
        print('🔧 Calculated calories from macros: $finalCalories kcal');
      }
      
      // ONLY estimate macros if ALL are truly 0 (don't overwrite low values)
      double finalProtein = protein;
      double finalCarbs = carbs;
      double finalFat = fat;
      
      if (protein == 0 && carbs == 0 && fat == 0 && finalCalories > 0) {
        // All macros missing - estimate from calories
        finalProtein = (finalCalories * 0.20 / 4);
        finalCarbs = (finalCalories * 0.55 / 4);
        finalFat = (finalCalories * 0.25 / 9);
        print('🔧 Estimated macros from calories (all were 0)');
      }
      
      // Use weight from AI, don't default to 150g
      final finalWeight = weightGrams > 0 ? weightGrams : 100.0;
      
      // Don't default calories - if 0 and can't calculate, return error
      if (finalCalories == 0) {
        print('❌ No calories available - cannot create nutrition info');
        return FoodScannerResult(
          success: false,
          error: 'Could not determine calories for this food item',
        );
      }
      
      final nutritionInfo = NutritionInfo(
        foodName: foodName,
        weightGrams: finalWeight,
        calories: finalCalories,
        protein: finalProtein,
        carbs: finalCarbs,
        fat: finalFat,
        fiber: fiber,
        sugar: sugar,
        source: 'AI Vision Analysis',
        category: snapResult['category']?.toString(),
      );
      
      print('✅ AI Vision result: $foodName');
      print('   Weight: ${finalWeight}g, Calories: ${finalCalories.toStringAsFixed(0)} kcal');
      print('   Macros: P${finalProtein.toStringAsFixed(1)}g C${finalCarbs.toStringAsFixed(1)}g F${finalFat.toStringAsFixed(1)}g');

      // Validate nutrition info
      if (!nutritionInfo.isValid) {
        return FoodScannerResult(
          success: false,
          error: 'Could not extract valid nutrition data from image',
        );
      }

      final confidence = _parseDouble(snapResult['confidence']) ?? 0.8;
      
      // Store detailed info for description (ingredients, volume, category, cuisine)
      final ingredients = snapResult['ingredients'] as List?;
      final volumeEstimate = snapResult['volumeEstimate'] as String?;
      final cuisine = snapResult['cuisine'] as String?;
      
      final snapToCalorieResult = <String, dynamic>{
        'ingredients': ingredients ?? [],
        'volumeEstimate': volumeEstimate,
        'category': snapResult['category'],
        'cuisine': cuisine,
      };
      
      return FoodScannerResult(
        success: true,
        recognitionResult: recognitionResult,
        portionResult: portionResult,
        nutritionInfo: nutritionInfo,
        processingTime: DateTime.now().millisecondsSinceEpoch,
        confidencePercentage: (confidence * 100).clamp(0.0, 100.0),
        snapToCalorieResult: snapToCalorieResult,
      );
    } catch (e) {
      return FoodScannerResult(
        success: false,
        error: 'Fast pipeline failed: $e',
      );
    }
  }

  /// Fast snap-to-calorie with offline fallback
  static Future<Map<String, dynamic>> _fastSnapToCalorie(File imageFile) async {
    try {
      print('📸 Encoding image for AI vision...');
      
      // Validate image file exists and is readable
      if (!await imageFile.exists()) {
        print('❌ Image file does not exist: ${imageFile.path}');
        return {
          'success': false,
          'error': 'Image file not found. Please try again.',
        };
      }
      
      final imageBytes = await imageFile.readAsBytes();
      
      // Validate image has content
      if (imageBytes.isEmpty) {
        print('❌ Image file is empty');
        return {
          'success': false,
          'error': 'Image file is empty. Please try again.',
        };
      }
      
      print('✅ Image file loaded: ${(imageBytes.length / 1024).toStringAsFixed(1)}KB');
      
      // Optimize image size for faster processing (reduce if too large)
      List<int> optimizedBytes = imageBytes;
      if (imageBytes.length > 500 * 1024) { // If > 500KB, compress
        print('⚠️ Image is large (${(imageBytes.length / 1024).toStringAsFixed(1)}KB), using as-is for speed');
        // For now, use as-is - compression would add delay
        // In production, could resize/compress here
      }
      
      // Validate image is not too small (might be corrupted)
      if (imageBytes.length < 100) {
        print('❌ Image file is too small (${imageBytes.length} bytes) - likely corrupted');
        return {
          'success': false,
          'error': 'Image file appears corrupted. Please try again.',
        };
      }
      
      final base64Image = base64Encode(optimizedBytes);
      print('✅ Image encoded: ${(optimizedBytes.length / 1024).toStringAsFixed(1)}KB → base64 length: ${base64Image.length}');
      
      // Validate base64 encoding
      if (base64Image.isEmpty) {
        print('❌ Base64 encoding failed - image is empty');
        return {
          'success': false,
          'error': 'Failed to encode image. Please try again.',
        };
      }
      
      print('✅ Image validation passed - ready for AI vision');

      // Optimized prompt - concise for faster processing, focused on calories
      const prompt = '''
Analyze image. Return ONLY JSON. If food: identify name, estimate weight, calculate calories + macros. If not food: isFood=false.

Food JSON format:
{"isFood":true,"foodName":"food name","ingredients":["ing1","ing2"],"weightGrams":200,"volumeEstimate":"1 plate","calories":350,"protein":25,"carbs":45,"fat":10,"fiber":3,"sugar":5,"category":"category","cuisine":"cuisine"}

Not food JSON format:
{"isFood":false,"foodName":"Not a food item","message":"Food not clearly visible","confidence":0,"calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0,"sugar":0,"weightGrams":0}

Requirements: JSON only. Estimate weight visually. Calories = (protein×4 + carbs×4 + fat×9) ± 10%.
''';

      print('📡 Calling OpenRouter AI Vision API...');
      print('   Model: ${AIConfig.visionModel}');
      print('   API Key present: ${AIConfig.apiKey.isNotEmpty}');
      print('   Base URL: ${AIConfig.baseUrl}');
      
      final response = await _callOpenRouterVisionFast(prompt, base64Image).timeout(
        const Duration(seconds: 18), // Faster timeout for speed (allows 3 attempts × 15s + overhead)
        onTimeout: () {
          print('⏱️ AI vision API call timed out after 18 seconds (all models exhausted)');
          return null;
        },
      );
      
      if (response == null || response.isEmpty) {
        print('❌ AI vision API call returned null or empty response');
        print('   This could mean:');
        print('   1. API key is missing or invalid');
        print('   2. Network connection failed');
        print('   3. API request timed out');
        print('   4. All vision models failed');
        print('🔄 Falling back to offline food recognition...');
        final offlineResult = await _offlineFoodRecognition(imageFile);
        return offlineResult;
      }
      print('✅ Received response from AI vision API (length: ${response.length})');

      try {
        // Clean the response to extract JSON
        String cleanedResponse = response.trim();
        
        // Remove markdown code blocks if present
        cleanedResponse = cleanedResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        
        // Check if response contains error message (not JSON)
        if (cleanedResponse.toLowerCase().contains("i'm sorry") || 
            cleanedResponse.toLowerCase().contains("i can't") ||
            cleanedResponse.toLowerCase().contains("cannot") ||
            cleanedResponse.toLowerCase().contains("does not depict")) {
          print('⚠️ AI returned error message instead of JSON');
          print('   Response: ${cleanedResponse.substring(0, cleanedResponse.length > 100 ? 100 : cleanedResponse.length)}...');
          return {
            'success': false,
            'error': 'AI could not identify food in the image. Please try a clearer photo or enter manually.',
          };
        }
        
        // Try to extract JSON from the response
        final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(cleanedResponse);
        if (jsonMatch != null) {
          cleanedResponse = jsonMatch.group(0)!.trim();
        } else {
          // No JSON found in response
          print('❌ No JSON found in AI response');
          print('   Response: ${cleanedResponse.substring(0, cleanedResponse.length > 200 ? 200 : cleanedResponse.length)}');
          return {
            'success': false,
            'error': 'AI returned invalid response format. Please try again or enter manually.',
          };
        }
        
        final result = jsonDecode(cleanedResponse) as Map<String, dynamic>;
        
        // Validate the result - parse carefully
        // Check if this is a food item or not
        final isFood = result['isFood'] as bool? ?? true; // Default to true for backward compatibility
        
        if (!isFood) {
          // Image is not food - return appropriate message
          final message = result['message'] as String? ?? 'The image does not clearly show food or the food is not clearly visible';
          print('⚠️ AI detected: Not a food item');
          print('   Message: $message');
          return {
            'success': false,
            'error': message,
            'isFood': false,
          };
        }
        
        // It's food - parse nutrition data
        final calories = _parseDouble(result['calories']);
        final protein = _parseDouble(result['protein']);
        final carbs = _parseDouble(result['carbs']);
        final fat = _parseDouble(result['fat']);
        final fiber = _parseDouble(result['fiber']);
        final sugar = _parseDouble(result['sugar']);
        final weightGrams = _parseDouble(result['weightGrams']);
        final foodNameRaw = result['foodName'];
        final foodName = (foodNameRaw != null && foodNameRaw.toString().trim().isNotEmpty) 
            ? foodNameRaw.toString().trim() 
            : 'Unknown Food';
        final confidence = _parseDouble(result['confidence']) ?? 0.8;
        
        // Extract ingredients if available
        final ingredients = result['ingredients'];
        final ingredientsList = ingredients is List 
            ? List<String>.from(ingredients.map((e) => e.toString())) 
            : <String>[];
        
        // Extract volume estimate if available
        final volumeEstimate = result['volumeEstimate'] as String?;
        
        print('📊 Parsed AI response (Food detected):');
        print('   Food: $foodName');
        if (ingredientsList.isNotEmpty) {
          print('   Ingredients: ${ingredientsList.join(", ")}');
        }
        if (volumeEstimate != null) {
          print('   Volume estimate: $volumeEstimate');
        }
        print('   Weight: ${weightGrams ?? "missing"}g');
        print('   Calories: ${calories ?? "missing"}');
        print('   Protein: ${protein ?? "missing"}g, Carbs: ${carbs ?? "missing"}g, Fat: ${fat ?? "missing"}g');
        
        // Validate that we have at least calories OR macros
        if ((calories == null || calories == 0) && 
            (protein == null || protein == 0) && 
            (carbs == null || carbs == 0) && 
            (fat == null || fat == 0)) {
          print('❌ AI response missing all nutrition data');
          return {
            'success': false,
            'error': 'AI could not determine nutrition values. Please try again or enter manually.',
          };
        }
        
        // Calculate calories from macros if missing
        double finalCalories = calories ?? 0.0;
        if (finalCalories == 0 && protein != null && carbs != null && fat != null) {
          final estimatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);
          if (estimatedCalories > 0) {
            finalCalories = estimatedCalories;
            print('🔧 Calculated calories from macros: $finalCalories kcal');
          }
        }
        
        // If still no calories, return error
        if (finalCalories == 0) {
          print('❌ No calories available (could not calculate from macros)');
          return {
            'success': false,
            'error': 'Could not determine calories for this food. Please enter manually.',
          };
        }
        
        // Calculate macros if missing (but only if ALL are missing)
        double finalProtein = protein ?? 0.0;
        double finalCarbs = carbs ?? 0.0;
        double finalFat = fat ?? 0.0;
        
        if (finalProtein == 0 && finalCarbs == 0 && finalFat == 0 && finalCalories > 0) {
          // All macros missing - estimate from calories
          finalProtein = (finalCalories * 0.20 / 4);
          finalCarbs = (finalCalories * 0.55 / 4);
          finalFat = (finalCalories * 0.25 / 9);
          print('🔧 Estimated macros from calories (all were 0)');
        }
        
        // Use weight from AI, minimal fallback if missing
        final finalWeight = (weightGrams != null && weightGrams > 0) ? weightGrams : 100.0;
        if (weightGrams == null || weightGrams <= 0) {
          print('⚠️ No weight provided by AI - using 100g as fallback');
        }
        
        // Use food name from AI
        final finalFoodName = (foodName != 'Unknown Food' && foodName.isNotEmpty) 
            ? foodName 
            : 'Food Item';
        
        // Update result with validated values
        result['foodName'] = finalFoodName;
        result['weightGrams'] = finalWeight;
        result['calories'] = finalCalories;
        result['protein'] = finalProtein;
        result['carbs'] = finalCarbs;
        result['fat'] = finalFat;
        result['fiber'] = fiber ?? 0.0;
        result['sugar'] = sugar ?? 0.0;
        result['confidence'] = confidence;
        result['isFood'] = true; // Mark as food
        
        // Add ingredients and volume if available
        if (ingredientsList.isNotEmpty) {
          result['ingredients'] = ingredientsList;
        }
        if (volumeEstimate != null) {
          result['volumeEstimate'] = volumeEstimate;
        }
        
        print('✅ AI Vision validated: $finalFoodName');
        print('   Weight: ${finalWeight}g, Calories: ${finalCalories.toStringAsFixed(0)} kcal');
        print('   Macros: P${finalProtein.toStringAsFixed(1)}g C${finalCarbs.toStringAsFixed(1)}g F${finalFat.toStringAsFixed(1)}g');
        
        result['success'] = true;
        result['source'] = 'AI Vision Analysis';
        return result;
      } catch (e, stackTrace) {
        print('❌ Failed to parse AI response: $e');
        print('Stack trace: $stackTrace');
        print('Response was: ${response.length > 300 ? response.substring(0, 300) + "..." : response}');
        print('🔄 Trying offline food recognition...');
        final offlineResult = await _offlineFoodRecognition(imageFile);
        return offlineResult;
      }
    } catch (e, stackTrace) {
      print('❌ Fast snap-to-calorie failed: $e');
      print('Stack trace: $stackTrace');
      print('🔄 Trying offline food recognition...');
      final offlineResult = await _offlineFoodRecognition(imageFile);
      return offlineResult;
    }
  }

  /// Offline food recognition fallback when AI vision fails
  static Future<Map<String, dynamic>> _offlineFoodRecognition(File imageFile) async {
    try {
      print('📱 Using offline food recognition...');
      
      // Check if API key is missing
      if (AIConfig.apiKey.isEmpty) {
        return {
          'success': false,
          'error': 'AI service is not configured. Please check your settings or add food manually.',
          'offline': true,
          'manualEntryPrompt': true,
          'suggestedAction': 'show_manual_entry',
        };
      }
      
      // Check if network is offline
      if (!NetworkService().isOnline) {
        return {
          'success': false,
          'error': 'No internet connection. Please connect to the internet or add food manually.',
          'offline': true,
          'manualEntryPrompt': true,
          'suggestedAction': 'show_offline_options',
        };
      }
      
      // Load offline food database
      final offlineData = await _loadOfflineFoodDatabase();
      
      // For now, we'll return a user-friendly prompt to enter manually
      // In a more advanced implementation, you could use local ML models
      // or image analysis to suggest foods from the offline database
      
      return {
        'success': false,
        'error': 'AI vision service is temporarily unavailable. Please select from common foods or enter manually.',
        'offline': true,
        'manualEntryPrompt': true,
        'suggestedAction': 'show_offline_options',
        'offlineOptions': _getCommonFoodSuggestions(offlineData),
        'defaultValues': {
          'foodName': 'Food Item',
          'weightGrams': 100.0,
          'calories': 150.0,
          'protein': 8.0,
          'carbs': 20.0,
          'fat': 5.0,
          'fiber': 2.0,
          'sugar': 3.0,
        }
      };
    } catch (e) {
      print('❌ Offline recognition failed: $e');
      return {
        'success': false,
        'error': 'Unable to analyze food image. Please enter food details manually.',
        'offline': true,
        'manualEntryPrompt': true,
      };
    }
  }

  /// Load offline food database
  static Future<Map<String, dynamic>> _loadOfflineFoodDatabase() async {
    try {
      // Try to load from existing assets - prioritize calorie_data.json
      try {
        final String jsonString = await rootBundle.loadString('assets/calorie_data.json');
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        if (data.isNotEmpty) {
          print('✅ Loaded offline food database: calorie_data.json');
          return data;
        }
      } catch (e) {
        print('⚠️ calorie_data.json not available, trying alternatives...');
      }
      
      // Fallback to comprehensive_indian_foods.json
      try {
        final String jsonString = await rootBundle.loadString('assets/comprehensive_indian_foods.json');
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        if (data.isNotEmpty) {
          print('✅ Loaded offline food database: comprehensive_indian_foods.json');
          return data;
        }
      } catch (e) {
        print('⚠️ comprehensive_indian_foods.json not available, trying alternatives...');
      }
      
      // Fallback to indian_foods.json
      try {
        final String jsonString = await rootBundle.loadString('assets/indian_foods.json');
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        if (data.isNotEmpty) {
          print('✅ Loaded offline food database: indian_foods.json');
          return data;
        }
      } catch (e) {
        print('⚠️ indian_foods.json not available');
      }
      
      // Return empty map if no database available
      print('⚠️ No offline food database available');
      return {};
    } catch (e) {
      print('❌ Failed to load offline food database: $e');
      return {};
    }
  }

  /// Get common food suggestions from offline database
  static List<Map<String, dynamic>> _getCommonFoodSuggestions(Map<String, dynamic> offlineData) {
    final suggestions = <Map<String, dynamic>>[];
    
    try {
      // Add common foods
      final commonFoods = offlineData['common_foods'] as List<dynamic>? ?? [];
      for (final food in commonFoods.take(10)) {
        final foodMap = food as Map<String, dynamic>;
        final servingSize = foodMap['common_serving'] as int? ?? 100;
        final caloriesPer100g = foodMap['calories_per_100g'] as int? ?? 100;
        final totalCalories = (caloriesPer100g * servingSize / 100).round();
        
        suggestions.add({
          'name': foodMap['name'],
          'category': foodMap['category'],
          'serving_size': servingSize,
          'total_calories': totalCalories,
          'nutritionInfo': {
            'calories': caloriesPer100g * servingSize / 100,
            'protein': (foodMap['protein_per_100g'] as num? ?? 0) * servingSize / 100,
            'carbs': (foodMap['carbs_per_100g'] as num? ?? 0) * servingSize / 100,
            'fat': (foodMap['fat_per_100g'] as num? ?? 0) * servingSize / 100,
            'fiber': (foodMap['fiber_per_100g'] as num? ?? 0) * servingSize / 100,
            'sugar': (foodMap['sugar_per_100g'] as num? ?? 0) * servingSize / 100,
          }
        });
      }
      
      // Add Indian dishes
      final indianDishes = offlineData['indian_dishes'] as List<dynamic>? ?? [];
      for (final dish in indianDishes.take(5)) {
        final dishMap = dish as Map<String, dynamic>;
        final servingSize = dishMap['common_serving'] as int? ?? 100;
        final caloriesPer100g = dishMap['calories_per_100g'] as int? ?? 100;
        final totalCalories = (caloriesPer100g * servingSize / 100).round();
        
        suggestions.add({
          'name': dishMap['name'],
          'category': dishMap['category'],
          'serving_size': servingSize,
          'total_calories': totalCalories,
          'nutritionInfo': {
            'calories': caloriesPer100g * servingSize / 100,
            'protein': (dishMap['protein_per_100g'] as num? ?? 0) * servingSize / 100,
            'carbs': (dishMap['carbs_per_100g'] as num? ?? 0) * servingSize / 100,
            'fat': (dishMap['fat_per_100g'] as num? ?? 0) * servingSize / 100,
            'fiber': (dishMap['fiber_per_100g'] as num? ?? 0) * servingSize / 100,
            'sugar': (dishMap['sugar_per_100g'] as num? ?? 0) * servingSize / 100,
          }
        });
      }
    } catch (e) {
      print('❌ Error processing offline suggestions: $e');
    }
    
    return suggestions;
  }

  /// Optimized barcode scanning with full cross-validation
  static Future<NutritionInfo?> _scanBarcodeOptimized(String barcode) async {
    try {
      // Use optimized barcode scanning (includes all fallbacks including AI)
      print('🔍 Using optimized barcode scanning...');
      
      // Use regular scanning which already includes all fallbacks
      var result = await BarcodeScanningService.scanBarcode(barcode);
      
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

  /// Generate cache key from image (fast - use file path and size)
  static Future<String> _generateCacheKey(File imageFile) async {
    try {
      // Use file path and modification time for fast cache key
      // Don't read entire file - too slow
      final stat = await imageFile.stat();
      return 'image_${imageFile.path.hashCode}_${stat.modified.millisecondsSinceEpoch}';
    } catch (e) {
      return 'image_${imageFile.path.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Fast OpenRouter vision call with model fallback and better error handling
  static Future<String?> _callOpenRouterVisionFast(String prompt, String base64Image) async {
    try {
      print('🔧 AI Vision Configuration:');
      print('   - Base URL: ${AIConfig.baseUrl}');
      print('   - API Key: ${AIConfig.apiKey.isNotEmpty ? "${AIConfig.apiKey.substring(0, 12)}..." : "MISSING"}');
      print('   - API Key length: ${AIConfig.apiKey.length}');
      print('   - Primary Model: ${AIConfig.visionModel}');
      print('   - Fallback Model: ${AIConfig.backupVisionModel}');
      print('   - Image size: ${(base64Image.length / 1024).toStringAsFixed(1)}KB base64');
      
      // Validate configuration FIRST before making any API calls
      if (AIConfig.apiKey.isEmpty) {
        print('❌ AI vision not configured: missing API key');
        print('   ⚠️ Check Firebase config at app_config/ai_settings/openrouter_api_key');
        print('   ⚠️ Make sure AIConfig.initialize() was called');
        print('   🔄 Attempting to reload configuration...');
        
        // Try to reload configuration (only once per call to prevent loops)
        try {
          await AIConfig.refresh(); // Refresh has built-in debouncing
          
          if (AIConfig.apiKey.isEmpty) {
            print('❌ API key still empty after refresh - check Firestore configuration');
            return null;
          } else {
            print('✅ API key loaded after refresh: ${AIConfig.apiKey.length} characters');
          }
        } catch (e) {
          print('❌ Error refreshing config: $e');
          return null;
        }
      }
      
      // Verify API key format (OpenRouter keys start with 'sk-or-v1-')
      if (!AIConfig.apiKey.startsWith('sk-or-v1-') && !AIConfig.apiKey.startsWith('sk-')) {
        print('⚠️ API key format may be incorrect (should start with sk-or-v1- or sk-)');
        print('   Current key starts with: ${AIConfig.apiKey.substring(0, AIConfig.apiKey.length > 10 ? 10 : AIConfig.apiKey.length)}');
      }
      
      // Build headers with API key - ensure it's properly formatted
      final apiKey = AIConfig.apiKey.trim(); // Remove any whitespace
      print('🔑 Using API key: ${apiKey.substring(0, apiKey.length > 12 ? 12 : apiKey.length)}... (length: ${apiKey.length})');
      
      // Verify API key format
      if (!apiKey.startsWith('sk-or-v1-') && !apiKey.startsWith('sk-')) {
        print('⚠️ WARNING: API key format may be incorrect');
        print('   Expected: starts with "sk-or-v1-" or "sk-"');
        print('   Actual: starts with "${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}"');
      }
      
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      };
      
      print('📡 Request headers prepared:');
      print('   - Authorization: Bearer ${apiKey.substring(0, 12)}...');
      print('   - HTTP-Referer: ${AIConfig.appUrl}');
      print('   - X-Title: ${AIConfig.appName}');

      // Try primary model (Gemini 1.5 Flash), fallback to GPT-4o if it fails
      final models = [
        AIConfig.visionModel,
        AIConfig.backupVisionModel,
      ];

      for (int attempt = 0; attempt < models.length; attempt++) {
        final model = models[attempt];
        print('🤖 Attempting vision analysis with model: $model (attempt ${attempt + 1})');

        try {
          // Build request body with system message to enforce JSON
          final body = <String, dynamic>{
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a nutrition analysis API. You MUST ALWAYS respond with ONLY valid JSON. Never include explanatory text, apologies, markdown, or any text outside JSON. Analyze the image: if it shows food, return JSON with isFood=true and nutrition data. If it does not show food, return JSON with isFood=false and a message. Never return plain text - always JSON.',
              },
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image',
                      'detail': attempt == 0 ? 'low' : 'high', // Low detail for speed on first attempt, high for accuracy on backup
                    }
                  }
                ],
              }
            ],
            'max_tokens': AIConfig.visionMaxTokens,
            'temperature': AIConfig.visionTemperature,
          };
          
          // Add response_format for models that support it (OpenAI models)
          // Some models might not support this, so we'll handle both cases
          if (model.startsWith('openai/')) {
            body['response_format'] = {'type': 'json_object'};
            print('   ✅ Added response_format for OpenAI model');
          } else {
            print('   ⚠️ Model may not support response_format - will rely on prompt');
          }

          // Optimized timeout for faster responses (Gemini 1.5 Flash is fast)
          const timeout = Duration(seconds: 15); // Faster timeout for speed
          
          print('📤 Sending request to OpenRouter:');
          print('   Model: $model');
          print('   Max tokens: ${AIConfig.visionMaxTokens}');
          print('   Temperature: ${AIConfig.visionTemperature}');
          print('   Image size: ${(base64Image.length / 1024).toStringAsFixed(1)}KB base64');
          print('   Image URL format: data:image/jpeg;base64,[${base64Image.length} chars]');
          print('   Image URL preview: data:image/jpeg;base64,${base64Image.substring(0, base64Image.length > 50 ? 50 : base64Image.length)}...');
          print('   Request timeout: ${timeout.inSeconds}s');
          print('   Has response_format: ${body.containsKey('response_format')}');
          
          final requestBody = jsonEncode(body);
          print('   Request body size: ${(requestBody.length / 1024).toStringAsFixed(1)}KB');
          print('   Request body preview: ${requestBody.substring(0, requestBody.length > 500 ? 500 : requestBody.length)}...');
          
          final response = await http.post(
            Uri.parse(AIConfig.baseUrl),
            headers: headers,
            body: requestBody,
          ).timeout(
            timeout,
            onTimeout: () {
              print('⏱️ Vision API timeout for model: $model (after ${timeout.inSeconds}s)');
              throw TimeoutException('Vision API timeout', timeout);
            },
          );
          
          print('📥 Received response from OpenRouter:');
          print('   Status code: ${response.statusCode}');
          print('   Response size: ${(response.body.length / 1024).toStringAsFixed(1)}KB');

          if (response.statusCode == 200) {
            print('✅ API request successful (200 OK)');
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            print('   Response keys: ${data.keys.toList()}');
            final content = data['choices']?[0]?['message']?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              print('✅ Vision analysis successful with model: $model');
              print('   Response content length: ${content.length} characters');
              print('   Response preview: ${content.substring(0, content.length > 100 ? 100 : content.length)}...');
              
              // Validate that content is JSON or can be parsed
              if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
                print('   ✅ Response appears to be JSON');
                return content;
              } else {
                print('   ⚠️ Response is NOT JSON - checking for error message');
                // Check if it's an error message
                final lowerContent = content.toLowerCase();
                if (lowerContent.contains("i'm sorry") || 
                    lowerContent.contains("i can't") ||
                    lowerContent.contains("cannot") ||
                    lowerContent.contains("does not depict") ||
                    lowerContent.contains("no food")) {
                  print('   ❌ AI returned error text instead of JSON');
                  print('   Full response: $content');
                  // Try to extract JSON if it's mixed with text
                  final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(content);
                  if (jsonMatch != null) {
                    print('   ✅ Found JSON in response, extracting...');
                    return jsonMatch.group(0)!.trim();
                  }
                  // If no JSON found, continue to next model
                  continue;
                } else {
                  // Unexpected format - try to extract JSON
                  final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(content);
                  if (jsonMatch != null) {
                    print('   ✅ Found JSON in response, extracting...');
                    return jsonMatch.group(0)!.trim();
                  }
                  print('   ❌ No JSON found in response');
                  continue;
                }
              }
            } else {
              print('⚠️ Empty response from model: $model');
              print('   Response data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
              continue; // Try next model
            }
          } else if (response.statusCode == 401) {
            print('❌ Authentication failed (401 Unauthorized)');
            print('   This means the API key is invalid, expired, or not authorized for this model');
            print('   API key used: ${apiKey.substring(0, 12)}...');
            print('   Model attempted: $model');
            print('   Response body: ${response.body}');
            print('   Check Firestore config at app_config/ai_settings/openrouter_api_key');
            print('   Verify API key is valid and has access to vision models');
            // Don't try other models if auth fails - they'll all fail with same key
            return null;
          } else if (response.statusCode == 429) {
            print('❌ Rate limit hit for model: $model');
            print('   Response body: ${response.body}');
            if (attempt < models.length - 1) {
              // Wait less before trying next model (speed optimization)
              await Future.delayed(const Duration(milliseconds: 300)); // Faster retry delay for speed
              continue;
            } else {
              return null; // All models exhausted
            }
          } else {
            print('❌ API error for model $model: ${response.statusCode}');
            try {
              final errorBody = jsonDecode(response.body);
              print('   Error response: ${errorBody.toString()}');
              if (errorBody.containsKey('error')) {
                final error = errorBody['error'];
                if (error is Map) {
                  print('   Error type: ${error['type']}');
                  print('   Error message: ${error['message']}');
                  print('   Error code: ${error['code']}');
                } else {
                  print('   Error details: $error');
                }
              }
            } catch (e) {
              print('   Raw response body: ${response.body}');
              print('   Failed to parse error: $e');
            }
            continue; // Try next model
          }
        } on TimeoutException {
          print('⏱️ Timeout for model: $model (timeout: 20s)');
          if (attempt < models.length - 1) {
            // Wait briefly before trying next model
            await Future.delayed(const Duration(milliseconds: 300)); // Faster retry delay
          }
          continue; // Try next model
        } catch (e, stackTrace) {
          print('❌ Error with model $model: $e');
          print('   Error type: ${e.runtimeType}');
          print('   Stack trace: $stackTrace');
          if (attempt < models.length - 1) {
            // Wait briefly before trying next model
            await Future.delayed(const Duration(milliseconds: 300)); // Faster retry delay
          }
          continue; // Try next model
        }
      }

      print('❌ All vision models failed after ${models.length} attempts');
      print('   Models attempted: ${models.join(", ")}');
      print('   API Key present: ${apiKey.isNotEmpty}');
      print('   Base URL: ${AIConfig.baseUrl}');
      return null;

    } catch (e, stackTrace) {
      print('❌ Fatal error in vision call: $e');
      print('   Stack trace: $stackTrace');
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

  // Removed unused _parseWeight helper

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
      
      // Return basic analysis as fallback
      return {
        'insights': ['Product identified via barcode scan'],
        'recommendations': ['Check portion size for accurate calorie tracking'],
        'tips': ['Barcode data provides reliable nutrition information'],
      };
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
