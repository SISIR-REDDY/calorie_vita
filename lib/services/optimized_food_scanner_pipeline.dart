import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
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
  // Extended cache duration for better cost efficiency (cached results avoid API calls)
  static const Duration _cacheExpiry = Duration(hours: 2); // Extended from 30min to 2 hours to reduce API costs

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
          await Future.delayed(const Duration(milliseconds: 200)); // Reduced wait for Firestore to load
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
      
      // Fast image optimization for faster upload and processing
      List<int> optimizedBytes = imageBytes;
      if (imageBytes.length > 200 * 1024) { // If > 200KB, compress and resize (reduced threshold for faster processing)
        print('⚡ Optimizing large image for faster processing...');
        try {
          final decodedImage = img.decodeImage(imageBytes);
          if (decodedImage != null) {
            // Resize to max 800px on longest side (faster processing, still good enough for AI)
            final maxSize = 800;
            img.Image resizedImage = decodedImage;
            
            if (decodedImage.width > maxSize || decodedImage.height > maxSize) {
              final aspectRatio = decodedImage.width / decodedImage.height;
              int newWidth, newHeight;
              
              if (aspectRatio > 1) {
                newWidth = maxSize;
                newHeight = (maxSize / aspectRatio).round();
              } else {
                newHeight = maxSize;
                newWidth = (maxSize * aspectRatio).round();
              }
              
              resizedImage = img.copyResize(
                decodedImage,
                width: newWidth,
                height: newHeight,
                interpolation: img.Interpolation.linear, // Fast interpolation
              );
              print('   📐 Resized: ${decodedImage.width}x${decodedImage.height} → $newWidth x $newHeight');
            }
            
            // Compress with quality 75 (good quality, smaller size, faster upload)
            optimizedBytes = img.encodeJpg(resizedImage, quality: 75);
            final originalSizeKB = (imageBytes.length / 1024);
            final optimizedSizeKB = (optimizedBytes.length / 1024);
            final reduction = ((1 - optimizedSizeKB / originalSizeKB) * 100);
            print('   ✅ Optimized: ${originalSizeKB.toStringAsFixed(1)}KB → ${optimizedSizeKB.toStringAsFixed(1)}KB (${reduction.toStringAsFixed(1)}% reduction)');
          }
        } catch (e) {
          print('   ⚠️ Image optimization failed, using original: $e');
          optimizedBytes = imageBytes; // Fallback to original
        }
      } else {
        print('   ✅ Image size is acceptable, using as-is');
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
      final base64SizeKB = base64Image.length / 1024;
      print('✅ Image encoded: ${(optimizedBytes.length / 1024).toStringAsFixed(1)}KB → base64 length: ${base64SizeKB.toStringAsFixed(1)}KB');
      
      // Calculate adaptive timeout based on image size
      // Small images (< 500KB): Fast timeout (25s total, 20s primary)
      // Medium images (500KB - 1MB): Moderate timeout (35s total, 25s primary)
      // Large images (> 1MB): Longer timeout (50s total, 35s primary)
      int totalTimeoutSeconds;
      int primaryTimeoutSeconds;
      int fallbackTimeoutSeconds;
      
      if (base64SizeKB < 500) {
        // Small/optimized images - fast processing
        totalTimeoutSeconds = 25;
        primaryTimeoutSeconds = 20;
        fallbackTimeoutSeconds = 25;
        print('⚡ Small image detected - using fast timeouts (${totalTimeoutSeconds}s total)');
      } else if (base64SizeKB < 1000) {
        // Medium images - moderate timeout
        totalTimeoutSeconds = 35;
        primaryTimeoutSeconds = 25;
        fallbackTimeoutSeconds = 30;
        print('⚖️ Medium image detected - using moderate timeouts (${totalTimeoutSeconds}s total)');
      } else {
        // Large images - longer timeout for safety
        totalTimeoutSeconds = 50;
        primaryTimeoutSeconds = 35;
        fallbackTimeoutSeconds = 40;
        print('⚠️ Large image detected (${base64SizeKB.toStringAsFixed(1)}KB) - using extended timeouts (${totalTimeoutSeconds}s total)');
        print('   Consider optimizing image size for faster processing');
      }
      
      // Validate base64 encoding
      if (base64Image.isEmpty) {
        print('❌ Base64 encoding failed - image is empty');
        return {
          'success': false,
          'error': 'Failed to encode image. Please try again.',
        };
      }
      
      print('✅ Image validation passed - ready for AI vision');

      // Enhanced prompt - trained to identify food even with other objects present
      // EXTENSIVE GLOBAL CUISINE KNOWLEDGE (Indian, Italian, Chinese, Mexican, Thai, Japanese, Mediterranean, American, etc.)
      // for accurate recognition and fast, correct nutrition analysis
      const prompt = '''
You are a world-class food nutrition analyzer with EXTENSIVE knowledge of GLOBAL CUISINES (Indian, Italian, Chinese, Mexican, Thai, Japanese, Mediterranean, American, French, Korean, Middle Eastern, etc.). Your task is to identify FOOD items in images with HIGH ACCURACY and provide CORRECT nutrition values FAST, even when other objects (plates, utensils, backgrounds, people, etc.) are visible.

CRITICAL INSTRUCTIONS:
1. Focus ONLY on food items - ignore plates, utensils, backgrounds, people, or other non-food objects
2. If multiple food items are present, identify the PRIMARY food item (largest/most prominent)
3. If food is partially visible or in the background, still analyze it if identifiable
4. Even if the image contains other objects, if FOOD is visible, you MUST analyze it
5. Return ONLY valid JSON - no explanations, no markdown, no text outside JSON

INDIAN FOOD EXPERTISE (CRITICAL FOR ACCURACY):
You have comprehensive knowledge of Indian cuisine including:

NORTH INDIAN DISHES (examples - you know hundreds more including regional specialties):
- Roti/Naan/Paratha/Chapati: 70-100g each, ~250-350 kcal, 8-12g protein, 45-55g carbs, 5-10g fat
- Dal (Lentils): 100g serving ~120-180 kcal, 7-10g protein, 20-25g carbs, 2-5g fat
- Sabzi (Vegetable curry): 100g ~80-150 kcal, 2-5g protein, 10-20g carbs, 3-8g fat
- Paneer dishes (Paneer Butter Masala, Paneer Tikka): 100g ~250-350 kcal, 15-20g protein, 8-15g carbs, 15-25g fat
- Chicken dishes (Butter Chicken, Chicken Curry, Tandoori Chicken): 100g ~200-300 kcal, 20-25g protein, 5-10g carbs, 10-20g fat
- Biryani: 200g serving ~400-600 kcal, 15-25g protein, 60-80g carbs, 10-20g fat
- Samosa: 50g each ~150-200 kcal, 3-5g protein, 20-25g carbs, 8-12g fat
- Pakora/Bhajiya: 50g ~100-150 kcal, 2-4g protein, 15-20g carbs, 5-8g fat
- You also know: Chole Bhature, Rajma, Aloo Gobi, Palak Paneer, Malai Kofta, Shahi Paneer, Kadai Paneer, Dal Makhani, Aloo Paratha, Paneer Paratha, Tandoori Roti, Garlic Naan, Butter Naan, Chicken Tikka Masala, Lamb Curry, Mutton Curry, and hundreds more regional dishes

SOUTH INDIAN DISHES:
- Dosa (Plain/Masala): 100g ~150-250 kcal, 4-6g protein, 25-35g carbs, 4-8g fat
- Idli: 100g ~100-120 kcal, 3-4g protein, 20-25g carbs, 1-2g fat
- Sambar: 100g ~50-80 kcal, 2-3g protein, 8-12g carbs, 1-2g fat
- Rasam: 100g ~20-40 kcal, 1-2g protein, 4-6g carbs, 0.5-1g fat
- Upma/Poha: 100g ~150-200 kcal, 3-5g protein, 30-35g carbs, 3-5g fat
- Vada: 50g ~100-150 kcal, 2-4g protein, 15-20g carbs, 5-8g fat

WEST INDIAN DISHES:
- Dhokla: 100g ~100-150 kcal, 4-6g protein, 20-25g carbs, 2-4g fat
- Thepla: 50g ~120-150 kcal, 3-4g protein, 20-25g carbs, 3-5g fat
- Khandvi: 100g ~120-150 kcal, 4-5g protein, 20-25g carbs, 3-4g fat

EAST INDIAN DISHES:
- Luchi/Puri: 30g each ~100-120 kcal, 2-3g protein, 15-18g carbs, 4-6g fat
- Aloo Posto: 100g ~150-200 kcal, 3-5g protein, 20-25g carbs, 8-12g fat

SWEETS & DESSERTS:
- Gulab Jamun: 50g each ~150-200 kcal, 3-4g protein, 25-30g carbs, 6-10g fat
- Jalebi: 50g ~150-200 kcal, 2-3g protein, 35-40g carbs, 5-8g fat
- Rasgulla: 50g each ~80-100 kcal, 2-3g protein, 18-20g carbs, 0.5-1g fat
- Barfi: 50g ~150-200 kcal, 3-4g protein, 25-30g carbs, 6-10g fat

STREET FOODS:
- Chaat (Bhel Puri, Papdi Chaat): 100g ~150-250 kcal, 3-6g protein, 30-40g carbs, 5-10g fat
- Vada Pav: 150g ~300-400 kcal, 8-12g protein, 45-55g carbs, 10-15g fat
- Pav Bhaji: 200g ~350-450 kcal, 8-12g protein, 50-60g carbs, 12-18g fat

COMMON INDIAN INGREDIENTS:
- Rice: 100g cooked ~130 kcal, 2.7g protein, 28g carbs, 0.3g fat
- Ghee/Oil: Used generously in cooking, add 50-100 kcal per 100g dish
- Spices: Turmeric, cumin, coriander, garam masala - minimal calories
- Yogurt/Curd: 100g ~60 kcal, 3-4g protein, 4-5g carbs, 3-4g fat

TYPICAL INDIAN PORTION SIZES:
- One Roti/Naan: 70-100g
- One Katori (bowl) Rice: 150-200g
- One Katori Dal/Sabzi: 100-150g
- One Thali (full meal): 400-600g total
- One Dosa: 100-150g
- One Idli: 30-40g (usually 2-4 served)

SCENARIOS TO HANDLE:
- Food on a plate with utensils → Analyze the food, ignore plate/utensils
- Food with people in background → Analyze the food, ignore people
- Food on table with other items → Focus on food items, ignore other objects
- Multiple food items → Identify primary food item or combine them
- Food partially visible → Still analyze if identifiable
- Food in container/package → Analyze the visible food portion
- Indian thali with multiple items → Identify all major items and combine nutrition

ANALYSIS REQUIREMENTS (when food is present):
1. Identify the food name (be VERY specific - e.g., "Butter Chicken with Naan" not just "Chicken", "Masala Dosa" not just "Dosa")
2. For Indian foods, use authentic names (e.g., "Dal Tadka", "Paneer Butter Masala", "Chole Bhature")
3. ESTIMATE WEIGHT (weightGrams) - Analyze the VISIBLE food portion and estimate weight in grams:
   - Use visual cues: plate size, food dimensions, typical serving sizes
   - Compare to reference objects (utensils, plates, bowls) if visible
   - Use your knowledge of typical portion sizes for each dish type
   - Estimate based on food density and volume (e.g., rice is denser than salad)
   - Be accurate: 100g of chicken looks different from 100g of pasta
   - Focus ONLY on visible food, ignore plate/container weight
4. ESTIMATE VOLUME (volumeEstimate) - Provide descriptive volume/portion estimate:
   - Use standard measurements: "1 plate", "1 bowl", "1 cup", "1 serving", "1 piece", "2 pieces", etc.
   - For liquids: "1 cup", "250ml", "1 glass", etc.
   - For discrete items: "1 slice", "2 pieces", "3 pieces", etc.
   - For bulk items: "1 plate", "1 bowl", "half plate", "quarter plate", etc.
   - Be specific: "1 medium plate" vs "1 small plate" when size is clear
   - Use culturally appropriate terms (e.g., "1 katori" for Indian dishes, "1 bowl" for soups)
5. Calculate calories based on food type, cuisine, estimated weight, and volume
6. For Indian dishes, account for oil/ghee used in cooking (typically adds 50-100 kcal per 100g)
7. Estimate macros: protein, carbs, fat, fiber, sugar
8. List main ingredients if visible
9. Provide category (e.g., "Main Course", "Snack", "Dessert", "Side Dish", "Bread", "Curry")
10. Provide cuisine type if identifiable (e.g., "Indian", "North Indian", "South Indian", "Italian", "American")
11. Provide confidence level (0.0-1.0)

Food JSON format (required when isFood=true):
{"isFood":true,"foodName":"specific food name with details","ingredients":["ingredient1","ingredient2"],"weightGrams":200,"volumeEstimate":"1 plate","calories":350,"protein":25,"carbs":45,"fat":10,"fiber":3,"sugar":5,"category":"category name","cuisine":"cuisine type","confidence":0.9}

Not food JSON format (ONLY use if NO food is visible at all):
{"isFood":false,"foodName":"Not a food item","message":"No food items visible in the image","confidence":0,"calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0,"sugar":0,"weightGrams":0}

CRITICAL RULES:
1. Always return valid JSON starting with { and ending with }
2. If ANY food is visible (even partially), set isFood=true and analyze it
3. Ignore non-food objects completely - they should not affect your analysis
4. WEIGHT ESTIMATION: Estimate weightGrams based on VISIBLE food portion only:
   - Use visual analysis: food dimensions, plate/bowl size, food density
   - Compare to typical serving sizes (e.g., one roti is 70-100g, one dosa is 100-150g)
   - Consider food type: dense foods (meat, rice) vs light foods (salad, soup)
   - Use reference objects: if utensils/plates are visible, use them to estimate scale
   - Be realistic: don't overestimate or underestimate - use your knowledge of food weights
5. VOLUME ESTIMATION: Always provide volumeEstimate as descriptive text:
   - Use standard portion descriptions: "1 plate", "1 bowl", "1 cup", "1 serving"
   - For multiple items: "2 pieces", "3 slices", "4 pieces"
   - For partial portions: "half plate", "quarter plate", "small bowl"
   - For liquids: include volume if estimable (e.g., "1 cup (250ml)", "1 glass (200ml)")
   - Be culturally appropriate: use terms that match the cuisine
6. Calculate calories: (protein×4 + carbs×4 + fat×9) ± 10%
7. Be specific with food names - include cooking method if visible (grilled, fried, baked, tandoori, etc.)
8. For Indian foods, use authentic regional names when identifiable
9. If multiple foods are visible, identify the primary/main food item and estimate combined weight/volume
10. If unsure about exact nutrition, provide best estimates based on food type, cuisine, estimated weight, and portion size
11. Confidence should reflect how clearly the food is visible (0.9+ for clear food, 0.7-0.9 for partially visible)
12. For Indian dishes, account for typical cooking methods (tadka, tawa, tandoor, etc.) which affect nutrition

EXAMPLES:
- Image with pasta on plate, fork, and table → Analyze pasta, ignore plate/fork/table
- Image with burger on table, phone visible → Analyze burger, ignore phone
- Image with rice and curry, person in background → Analyze rice and curry, ignore person
- Image with pizza slice on plate with other items → Analyze pizza slice, ignore other items
- Image with Roti and Dal on thali → Analyze both, combine nutrition: "Roti with Dal"
- Image with Dosa on banana leaf → Analyze Dosa, use authentic name: "Masala Dosa" or "Plain Dosa"
- Image with Biryani in plate → Analyze Biryani, estimate portion size, use authentic name

GLOBAL CUISINE EXPERTISE (FOR WIDE VARIETY COVERAGE):

IMPORTANT: The examples below are REFERENCE GUIDES for accuracy. You have EXTENSIVE knowledge of THOUSANDS of dishes from global cuisines. Use your FULL knowledge base to recognize ANY food item, not just the examples listed. You can identify virtually any dish from ANY cuisine worldwide.

ITALIAN CUISINE (examples - you know many more):
- Pasta (Spaghetti, Penne, Fettuccine): 100g cooked ~130-150 kcal, 4-5g protein, 25-30g carbs, 1-2g fat
- Pizza (Margherita, Pepperoni): 100g ~250-300 kcal, 10-15g protein, 30-35g carbs, 10-15g fat
- Risotto: 100g ~150-200 kcal, 4-6g protein, 30-35g carbs, 4-6g fat
- Lasagna: 100g ~200-250 kcal, 12-15g protein, 20-25g carbs, 10-15g fat
- Tiramisu: 100g ~300-400 kcal, 5-8g protein, 35-45g carbs, 15-20g fat

CHINESE CUISINE (examples - you know thousands more including regional variations):
- Fried Rice: 100g ~150-200 kcal, 4-6g protein, 30-35g carbs, 4-6g fat
- Sweet and Sour Chicken: 100g ~200-250 kcal, 15-20g protein, 20-25g carbs, 8-12g fat
- Kung Pao Chicken: 100g ~180-220 kcal, 18-22g protein, 10-15g carbs, 8-10g fat
- Beef Lo Mein: 100g ~150-200 kcal, 8-12g protein, 25-30g carbs, 4-6g fat
- Dumplings (steamed/fried): 50g each ~80-120 kcal, 3-5g protein, 12-15g carbs, 2-4g fat
- Spring Rolls: 50g each ~100-150 kcal, 3-5g protein, 15-20g carbs, 4-6g fat
- You also know: General Tso's Chicken, Orange Chicken, Mapo Tofu, Peking Duck, Dim Sum varieties, Hot Pot, Chow Mein, Wonton Soup, Egg Rolls, and hundreds more

MEXICAN CUISINE (examples - you know many more):
- Tacos (beef, chicken, fish): 100g ~200-250 kcal, 12-18g protein, 20-25g carbs, 8-12g fat
- Burritos: 200g ~400-500 kcal, 20-25g protein, 50-60g carbs, 12-18g fat
- Quesadilla: 150g ~350-450 kcal, 15-20g protein, 35-40g carbs, 18-22g fat
- Nachos: 100g ~250-300 kcal, 8-12g protein, 30-35g carbs, 12-15g fat
- Guacamole: 100g ~160-200 kcal, 2-3g protein, 8-10g carbs, 14-18g fat
- Enchiladas: 200g ~350-450 kcal, 20-25g protein, 40-50g carbs, 15-20g fat

THAI CUISINE:
- Pad Thai: 200g ~400-500 kcal, 15-20g protein, 60-70g carbs, 12-18g fat
- Green Curry: 100g ~150-200 kcal, 8-12g protein, 10-15g carbs, 10-15g fat
- Tom Yum Soup: 200g ~50-80 kcal, 5-8g protein, 8-12g carbs, 1-2g fat
- Pad See Ew: 200g ~400-500 kcal, 15-20g protein, 60-70g carbs, 12-18g fat
- Mango Sticky Rice: 150g ~300-350 kcal, 3-4g protein, 65-75g carbs, 4-6g fat

JAPANESE CUISINE:
- Sushi (Nigiri, Maki): 50g piece ~50-80 kcal, 3-5g protein, 8-12g carbs, 0.5-2g fat
- Sashimi: 100g ~120-150 kcal, 20-25g protein, 0-2g carbs, 3-5g fat
- Ramen: 400g bowl ~500-600 kcal, 20-25g protein, 70-80g carbs, 15-20g fat
- Tempura: 100g ~200-250 kcal, 5-8g protein, 25-30g carbs, 10-15g fat
- Teriyaki Chicken: 100g ~180-220 kcal, 20-25g protein, 8-12g carbs, 6-10g fat
- Udon: 200g ~300-400 kcal, 10-15g protein, 60-70g carbs, 2-4g fat

MEDITERRANEAN CUISINE:
- Hummus: 100g ~166 kcal, 8g protein, 20g carbs, 6g fat
- Falafel: 50g each ~100-150 kcal, 4-6g protein, 15-20g carbs, 4-6g fat
- Greek Salad: 200g ~150-200 kcal, 5-8g protein, 10-15g carbs, 10-15g fat
- Moussaka: 200g ~350-450 kcal, 18-22g protein, 25-30g carbs, 20-25g fat
- Pita Bread: 60g each ~165 kcal, 5g protein, 33g carbs, 1g fat

AMERICAN CUISINE:
- Burger (with bun): 200g ~500-600 kcal, 25-30g protein, 40-50g carbs, 25-30g fat
- Hot Dog: 100g ~250-300 kcal, 10-12g protein, 20-25g carbs, 15-18g fat
- Fried Chicken: 100g ~250-300 kcal, 20-25g protein, 10-15g carbs, 15-20g fat
- BBQ Ribs: 100g ~250-300 kcal, 20-25g protein, 5-10g carbs, 15-20g fat
- Mac and Cheese: 200g ~400-500 kcal, 15-20g protein, 50-60g carbs, 18-22g fat

MIDDLE EASTERN CUISINE:
- Shawarma: 150g ~300-400 kcal, 20-25g protein, 30-35g carbs, 12-18g fat
- Kebabs: 100g ~200-250 kcal, 20-25g protein, 5-10g carbs, 10-15g fat
- Baklava: 50g ~250-300 kcal, 3-4g protein, 30-35g carbs, 15-18g fat

FRENCH CUISINE:
- Croissant: 50g ~200-250 kcal, 4-5g protein, 25-30g carbs, 10-15g fat
- Quiche: 150g ~350-450 kcal, 15-18g protein, 25-30g carbs, 22-28g fat
- Coq au Vin: 200g ~350-400 kcal, 30-35g protein, 10-15g carbs, 20-25g fat

KOREAN CUISINE:
- Bibimbap: 300g ~500-600 kcal, 20-25g protein, 70-80g carbs, 15-20g fat
- Kimchi: 100g ~15-20 kcal, 1-2g protein, 3-4g carbs, 0.5g fat
- Bulgogi: 100g ~200-250 kcal, 20-25g protein, 10-15g carbs, 10-12g fat

COMMON GLOBAL FOODS:
- Salads: 200g ~100-200 kcal (varies by dressing)
- Sandwiches: 150g ~300-400 kcal (varies by filling)
- Soups: 200g ~100-200 kcal (varies by type)
- Stir-fries: 200g ~200-300 kcal (varies by ingredients)
- Grilled meats: 100g ~200-250 kcal (varies by type)
- Seafood: 100g ~100-200 kcal (varies by type)

ACCURACY REQUIREMENTS:
- Use authentic dish names when identifiable
- Provide accurate nutrition values based on standard recipes
- Account for cooking methods (fried, grilled, steamed, baked, etc.)
- Consider typical portion sizes for each cuisine
- Account for oils, sauces, and condiments used in cooking
- Provide realistic macro breakdowns (protein×4 + carbs×4 + fat×9 ≈ calories)

SPEED & ACCURACY OPTIMIZATION:
- Identify food quickly based on visual characteristics
- Use your extensive knowledge base for instant recognition
- Provide correct nutrition values without hesitation
- Be confident in your analysis (0.9+ confidence for clear food items)

CRITICAL: You have EXTENSIVE knowledge of THOUSANDS of dishes from ALL global cuisines. The examples above are REFERENCE GUIDES only - they represent just a small fraction of your knowledge. Use your FULL knowledge base to recognize and analyze ANY food item from ANY cuisine worldwide, including:
- Regional variations and specialties
- Street foods from all countries
- Traditional and modern dishes
- Fusion cuisine
- Restaurant dishes
- Home-cooked meals
- Snacks, desserts, beverages, and all food categories

You can identify and analyze virtually ANY food item, not limited to the examples. Be confident in using your extensive knowledge to provide accurate nutrition analysis for dishes you know, even if they're not explicitly listed above.

Remember: Your ONLY job is to identify and analyze FOOD items with HIGH ACCURACY and FAST responses. Use your comprehensive knowledge of THOUSANDS of dishes from global cuisines (Indian, Italian, Chinese, Mexican, Thai, Japanese, Mediterranean, American, French, Korean, Middle Eastern, African, South American, European, Asian, etc.) to provide CORRECT nutrition analysis for ALL types of foods. The examples are references - your knowledge extends far beyond them. Everything else is irrelevant.
''';

      print('📡 Calling OpenRouter AI Vision API...');
      print('   Model: ${AIConfig.visionModel}');
      print('   API Key present: ${AIConfig.apiKey.isNotEmpty}');
      print('   Base URL: ${AIConfig.baseUrl}');
      
      // Pass adaptive timeout values to the API call
      final response = await _callOpenRouterVisionFast(
        prompt, 
        base64Image,
        primaryTimeoutSeconds: primaryTimeoutSeconds,
        fallbackTimeoutSeconds: fallbackTimeoutSeconds,
      ).timeout(
        Duration(seconds: totalTimeoutSeconds),
        onTimeout: () {
          print('⏱️ AI vision API call timed out after $totalTimeoutSeconds seconds (all models exhausted)');
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
        final lowerResponse = cleanedResponse.toLowerCase();
        if (lowerResponse.contains("i'm sorry") || 
            lowerResponse.contains("i can't") ||
            lowerResponse.contains("cannot") ||
            lowerResponse.contains("does not depict") ||
            lowerResponse.contains("unable to") ||
            lowerResponse.contains("i don't") ||
            lowerResponse.contains("i cannot")) {
          print('⚠️ AI returned error message instead of JSON');
          print('   Response preview: ${cleanedResponse.substring(0, cleanedResponse.length > 200 ? 200 : cleanedResponse.length)}...');
          print('   Full response length: ${cleanedResponse.length}');
          
          // Try to extract JSON even if there's an error message
          final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(cleanedResponse);
          if (jsonMatch != null) {
            print('   ✅ Found JSON in response despite error message, attempting to parse...');
            try {
              final extractedJson = jsonMatch.group(0)!.trim();
              final parsedResult = jsonDecode(extractedJson) as Map<String, dynamic>;
              final isFood = parsedResult['isFood'] as bool? ?? true;
              if (isFood) {
                print('   ✅ JSON parsed successfully, isFood=true');
                cleanedResponse = extractedJson;
                // Continue with normal parsing below
              } else {
                return {
                  'success': false,
                  'error': parsedResult['message'] as String? ?? 'AI could not identify food in the image. Please try a clearer photo or enter manually.',
                  'isFood': false,
                };
              }
            } catch (e) {
              print('   ❌ Failed to parse extracted JSON: $e');
              print('🔄 Attempting to extract nutrition data directly from AI response...');
              final directExtraction = _extractNutritionFromText(response, cleanedResponse);
              if (directExtraction != null && directExtraction['success'] == true) {
                print('✅ Successfully extracted nutrition data from AI response text');
                return directExtraction;
              }
              return {
                'success': false,
                'error': 'AI could not identify food in the image. Please try a clearer photo or enter manually.',
              };
            }
          } else {
            print('🔄 Attempting to extract nutrition data directly from AI response...');
            final directExtraction = _extractNutritionFromText(response, cleanedResponse);
            if (directExtraction != null && directExtraction['success'] == true) {
              print('✅ Successfully extracted nutrition data from AI response text');
              return directExtraction;
            }
            return {
              'success': false,
              'error': 'AI could not identify food in the image. Please try a clearer photo or enter manually.',
            };
          }
        }
        
        // Try to extract JSON from the response (if not already extracted above)
        if (!cleanedResponse.trim().startsWith('{')) {
          // Extract JSON using proper brace counting
          final jsonStart = cleanedResponse.indexOf('{');
          if (jsonStart != -1) {
            int braceCount = 0;
            int bracketCount = 0;
            int jsonEnd = -1;
            bool inString = false;
            bool escapeNext = false;
            
            for (int i = jsonStart; i < cleanedResponse.length; i++) {
              final char = cleanedResponse[i];
              
              if (escapeNext) {
                escapeNext = false;
                continue;
              }
              
              if (char == '\\') {
                escapeNext = true;
                continue;
              }
              
              if (char == '"' && !escapeNext) {
                inString = !inString;
                continue;
              }
              
              if (!inString) {
                if (char == '{') {
                  braceCount++;
                } else if (char == '}') {
                  braceCount--;
                  if (braceCount == 0 && bracketCount == 0) {
                    jsonEnd = i + 1;
                    break;
                  }
                } else if (char == '[') {
                  bracketCount++;
                } else if (char == ']') {
                  bracketCount--;
                  if (braceCount == 0 && bracketCount == 0) {
                    jsonEnd = i + 1;
                    break;
                  }
                }
              }
            }
            
            if (jsonEnd > jsonStart) {
              print('   📝 Extracting JSON from response using brace counting...');
              cleanedResponse = cleanedResponse.substring(jsonStart, jsonEnd).trim();
            } else {
              // Fallback to regex if brace counting fails
              final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(cleanedResponse);
              if (jsonMatch != null) {
                final regexExtracted = jsonMatch.group(0)!.trim();
                // Validate regex extracted JSON is complete
                final openBraces = regexExtracted.split('{').length - 1;
                final closeBraces = regexExtracted.split('}').length - 1;
                final openBrackets = regexExtracted.split('[').length - 1;
                final closeBrackets = regexExtracted.split(']').length - 1;
                if (openBraces == closeBraces && openBrackets == closeBrackets) {
                  print('   📝 Extracting JSON from response (regex fallback - validated)...');
                  cleanedResponse = regexExtracted;
                } else {
                  print('❌ Regex extracted incomplete JSON (braces: $openBraces/$closeBraces, brackets: $openBrackets/$closeBrackets)');
                  print('   Response preview: ${cleanedResponse.substring(0, cleanedResponse.length > 300 ? 300 : cleanedResponse.length)}');
                  print('🔄 Attempting to extract nutrition data directly from AI response...');
                  final directExtraction = _extractNutritionFromText(response, cleanedResponse);
                  if (directExtraction != null && directExtraction['success'] == true) {
                    print('✅ Successfully extracted nutrition data from AI response text');
                    return directExtraction;
                  }
                  return {
                    'success': false,
                    'error': 'AI returned incomplete JSON. Please try again with a clearer photo or enter manually.',
                  };
                }
              } else {
                print('❌ No JSON found in AI response');
                print('   Response preview: ${cleanedResponse.substring(0, cleanedResponse.length > 300 ? 300 : cleanedResponse.length)}');
                print('🔄 Attempting to extract nutrition data directly from AI response...');
                final directExtraction = _extractNutritionFromText(response, cleanedResponse);
                if (directExtraction != null && directExtraction['success'] == true) {
                  print('✅ Successfully extracted nutrition data from AI response text');
                  return directExtraction;
                }
                return {
                  'success': false,
                  'error': 'AI returned invalid response format. The image may be unclear or the service is having issues. Please try again with a clearer photo or enter manually.',
                };
              }
            }
          } else {
            print('❌ No JSON found in AI response');
            print('   Response preview: ${cleanedResponse.substring(0, cleanedResponse.length > 300 ? 300 : cleanedResponse.length)}');
            print('🔄 Attempting to extract nutrition data directly from AI response...');
            final directExtraction = _extractNutritionFromText(response, cleanedResponse);
            if (directExtraction != null && directExtraction['success'] == true) {
              print('✅ Successfully extracted nutrition data from AI response text');
              return directExtraction;
            }
            return {
              'success': false,
              'error': 'AI returned invalid response format. The image may be unclear or the service is having issues. Please try again with a clearer photo or enter manually.',
            };
          }
        }
        
        print('   ✅ Final JSON length: ${cleanedResponse.length} characters');
        Map<String, dynamic> result;
        try {
          result = jsonDecode(cleanedResponse) as Map<String, dynamic>;
        } catch (jsonError) {
          print('❌ JSON parsing failed: $jsonError');
          print('🔄 Attempting to extract nutrition data directly from AI response...');
          final directExtraction = _extractNutritionFromText(response, cleanedResponse);
          if (directExtraction != null && directExtraction['success'] == true) {
            print('✅ Successfully extracted nutrition data from AI response text');
            return directExtraction;
          }
          print('❌ Direct extraction also failed, falling back to offline recognition');
          rethrow; // Re-throw to go to outer catch block
        }
        
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
        print('   Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
        if (ingredientsList.isNotEmpty) {
          print('   Ingredients: ${ingredientsList.join(", ")}');
        }
        if (volumeEstimate != null) {
          print('   Volume estimate: $volumeEstimate');
        }
        print('   Weight: ${weightGrams ?? "missing"}g');
        print('   Calories: ${calories ?? "missing"}');
        print('   Protein: ${protein ?? "missing"}g, Carbs: ${carbs ?? "missing"}g, Fat: ${fat ?? "missing"}g');
        
        // Log if food name suggests multiple items or complex dish
        if (foodName.toLowerCase().contains('with') || 
            foodName.toLowerCase().contains('and') ||
            foodName.toLowerCase().contains('+') ||
            ingredientsList.length > 3) {
          print('   ℹ️ Complex dish detected - analyzing combined items');
        }
        
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

  /// Extract nutrition data directly from AI response text when JSON parsing fails
  static Map<String, dynamic>? _extractNutritionFromText(String originalResponse, String cleanedResponse) {
    try {
      print('   🔍 Extracting nutrition data from text using pattern matching...');
      
      // Use the original response for better pattern matching (contains full text)
      final text = originalResponse.toLowerCase();
      
      // Extract food name - look for patterns like "food name:", "item:", "dish:", or quotes
      String? foodName;
      final foodNamePatterns = [
        RegExp(r'food\s*name\s*[:=]\s*["'']?([^"'']+)["'']?', caseSensitive: false),
        RegExp(r'item\s*[:=]\s*["'']?([^"'']+)["'']?', caseSensitive: false),
        RegExp(r'dish\s*[:=]\s*["'']?([^"'']+)["'']?', caseSensitive: false),
        RegExp(r'["'']([^"'']+)["'']', caseSensitive: false),
      ];
      
      for (final pattern in foodNamePatterns) {
        final match = pattern.firstMatch(originalResponse);
        if (match != null && match.group(1) != null) {
          foodName = match.group(1)!.trim();
          if (foodName.isNotEmpty && foodName.length > 2 && foodName.length < 100) {
            break;
          }
        }
      }
      
      // Extract calories - look for patterns like "250 calories", "250 kcal", "calories: 250"
      double? calories;
      final caloriePatterns = [
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:calories|kcal)', caseSensitive: false),
        RegExp(r'calories?\s*[:=]\s*(\d+(?:\.\d+)?)', caseSensitive: false),
        RegExp(r'(\d+(?:\.\d+)?)\s*cal', caseSensitive: false),
      ];
      
      for (final pattern in caloriePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value > 0 && value < 10000) {
            calories = value;
            break;
          }
        }
      }
      
      // Extract protein - look for patterns like "15g protein", "protein: 15g"
      double? protein;
      final proteinPatterns = [
        RegExp(r'(\d+(?:\.\d+)?)\s*g\s*protein', caseSensitive: false),
        RegExp(r'protein\s*[:=]\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false),
        RegExp(r'protein\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false),
      ];
      
      for (final pattern in proteinPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value >= 0 && value < 1000) {
            protein = value;
            break;
          }
        }
      }
      
      // Extract carbs - look for patterns like "30g carbs", "carbs: 30g"
      double? carbs;
      final carbsPatterns = [
        RegExp(r'(\d+(?:\.\d+)?)\s*g\s*(?:carbs|carbohydrates)', caseSensitive: false),
        RegExp(r'(?:carbs|carbohydrates)\s*[:=]\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false),
        RegExp(r'(?:carbs|carbohydrates)\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false),
      ];
      
      for (final pattern in carbsPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value >= 0 && value < 1000) {
            carbs = value;
            break;
          }
        }
      }
      
      // Extract fat - look for patterns like "10g fat", "fat: 10g"
      double? fat;
      final fatPatterns = [
        RegExp(r'(\d+(?:\.\d+)?)\s*g\s*fat', caseSensitive: false),
        RegExp(r'fat\s*[:=]\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false),
        RegExp(r'fat\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false),
      ];
      
      for (final pattern in fatPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value >= 0 && value < 1000) {
            fat = value;
            break;
          }
        }
      }
      
      // Extract fiber - optional
      double? fiber;
      final fiberPatterns = [
        RegExp(r'(\d+(?:\.\d+)?)\s*g\s*fiber', caseSensitive: false),
        RegExp(r'fiber\s*[:=]\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false),
      ];
      
      for (final pattern in fiberPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value >= 0 && value < 1000) {
            fiber = value;
            break;
          }
        }
      }
      
      // Extract weight - look for patterns like "100g", "weight: 100g", "100 grams"
      double? weightGrams;
      final weightPatterns = [
        RegExp(r'weight\s*[:=]\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false),
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|grams?)\s*(?:weight|portion|serving)', caseSensitive: false),
        RegExp(r'(?:serving|portion)\s*(?:size|weight)?\s*[:=]\s*(\d+(?:\.\d+)?)\s*g', caseSensitive: false),
      ];
      
      for (final pattern in weightPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value > 0 && value < 10000) {
            weightGrams = value;
            break;
          }
        }
      }
      
      // Validate that we have at least calories or macros
      if (calories == null && protein == null && carbs == null && fat == null) {
        print('   ❌ No nutrition data found in text');
        return null;
      }
      
      // Calculate calories from macros if missing
      double finalCalories = calories ?? 0.0;
      if (finalCalories == 0 && protein != null && carbs != null && fat != null) {
        finalCalories = (protein * 4) + (carbs * 4) + (fat * 9);
        print('   🔧 Calculated calories from extracted macros: ${finalCalories.toStringAsFixed(0)} kcal');
      }
      
      // If still no calories, return null
      if (finalCalories == 0) {
        print('   ❌ No calories available (could not calculate from macros)');
        return null;
      }
      
      // Build result map
      final result = <String, dynamic>{
        'success': true,
        'source': 'AI Vision Analysis (Text Extraction)',
        'foodName': foodName ?? 'Food Item',
        'calories': finalCalories,
        'protein': protein ?? 0.0,
        'carbs': carbs ?? 0.0,
        'fat': fat ?? 0.0,
        'fiber': fiber ?? 0.0,
        'sugar': 0.0,
        'weightGrams': weightGrams ?? 100.0,
        'confidence': 0.7, // Lower confidence for text extraction
        'isFood': true,
      };
      
      print('   ✅ Extracted nutrition data:');
      print('      Food: ${result['foodName']}');
      print('      Calories: ${finalCalories.toStringAsFixed(0)} kcal');
      print('      Protein: ${result['protein']}g, Carbs: ${result['carbs']}g, Fat: ${result['fat']}g');
      print('      Weight: ${result['weightGrams']}g');
      
      return result;
    } catch (e) {
      print('   ❌ Error extracting nutrition from text: $e');
      return null;
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
  /// [primaryTimeoutSeconds] - Timeout for primary model (default: 20s)
  /// [fallbackTimeoutSeconds] - Timeout for fallback model (default: 25s)
  static Future<String?> _callOpenRouterVisionFast(
    String prompt, 
    String base64Image, {
    int primaryTimeoutSeconds = 20,
    int fallbackTimeoutSeconds = 25,
  }) async {
    try {
      if (kDebugMode) {
        print('🔧 AI Vision Configuration:');
        print('   - Base URL: ${AIConfig.baseUrl}');
        // SECURITY: Never log API key previews in production
        print('   - API Key: ${AIConfig.apiKey.isNotEmpty ? "CONFIGURED (${AIConfig.apiKey.length} chars)" : "MISSING"}');
        print('   - Primary Model: ${AIConfig.visionModel}');
        print('   - Fallback Model: ${AIConfig.backupVisionModel}');
        print('   - Image size: ${(base64Image.length / 1024).toStringAsFixed(1)}KB base64');
      }
      
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
      
      // SECURITY: Never log API key previews in production
      if (kDebugMode) {
        // Verify API key format (OpenRouter keys start with 'sk-or-v1-')
        if (!AIConfig.apiKey.startsWith('sk-or-v1-') && !AIConfig.apiKey.startsWith('sk-')) {
          print('⚠️ API key format may be incorrect (should start with sk-or-v1- or sk-)');
        }
      }
      
      // Build headers with API key - ensure it's properly formatted
      final apiKey = AIConfig.apiKey.trim(); // Remove any whitespace
      
      // SECURITY: Never log API key previews in production
      if (kDebugMode) {
        print('🔑 Using API key (length: ${apiKey.length})');
        // Verify API key format (only in debug mode)
        if (!apiKey.startsWith('sk-or-v1-') && !apiKey.startsWith('sk-')) {
          print('⚠️ WARNING: API key format may be incorrect');
          print('   Expected: starts with "sk-or-v1-" or "sk-"');
        }
      }
      
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': AIConfig.appUrl,
        'X-Title': AIConfig.appName,
      };
      
      // SECURITY: Never log Authorization header in production
      if (kDebugMode) {
        print('📡 Request headers prepared:');
        print('   - Authorization: Bearer [REDACTED]');
        print('   - HTTP-Referer: ${AIConfig.appUrl}');
        print('   - X-Title: ${AIConfig.appName}');
      }

      // Try primary model first, fallback only if enabled and budget allows
      final models = [
        AIConfig.visionModel,
        // Only use fallback if enabled and budget allows (fallback model is more expensive)
        if (AIConfig.visionFallbackEnabled) AIConfig.backupVisionModel,
      ];

      for (int attempt = 0; attempt < models.length; attempt++) {
        final model = models[attempt];
        print('🤖 Attempting vision analysis with model: $model (attempt ${attempt + 1})');

        try {
          // Build request body with strong system message to enforce JSON
          final body = <String, dynamic>{
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a world-class food nutrition analysis API with EXTENSIVE knowledge of THOUSANDS of dishes from ALL GLOBAL CUISINES (Indian, Italian, Chinese, Mexican, Thai, Japanese, Mediterranean, American, French, Korean, Middle Eastern, African, South American, European, Asian, etc.). Your knowledge extends to regional variations, street foods, traditional dishes, fusion cuisine, and virtually any food item worldwide. Your ONLY job is to identify and analyze FOOD items in images with HIGH ACCURACY and provide CORRECT nutrition values FAST, even when other objects (plates, utensils, people, backgrounds) are visible. Focus ONLY on food - ignore everything else. You have comprehensive knowledge of global cuisines, authentic dish names, regional variations, typical portion sizes, and accurate nutrition values. Use authentic food names when identifiable. Provide ACCURATE and CORRECT nutrition values based on standard recipes and cooking methods. You can recognize and analyze ANY food item, not limited to specific examples. You MUST respond with ONLY valid JSON. Never include markdown, explanations, or text outside JSON. Your response must start with { and end with }. If ANY food is visible (even partially), return JSON with isFood=true and complete nutrition data. Only return isFood=false if NO food is visible at all. CRITICAL: Return ONLY the JSON object, nothing else. Be FAST and ACCURATE.',
              },
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image',
                      'detail': 'low', // Use low detail for faster processing (images are already optimized)
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

          // Adaptive timeout based on image size (passed from caller)
          // Use shorter timeout for faster model, longer for fallback
          final timeout = Duration(seconds: attempt == 0 ? primaryTimeoutSeconds : fallbackTimeoutSeconds);
          
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
              
              // Always try to extract JSON using proper brace counting (handles newlines/formatting)
              final trimmedContent = content.trim();
              if (trimmedContent.startsWith('{')) {
                // Extract complete JSON by counting braces and brackets
                final jsonStart = trimmedContent.indexOf('{');
                int braceCount = 0;
                int bracketCount = 0;
                int jsonEnd = -1;
                bool inString = false;
                bool escapeNext = false;
                
                for (int i = jsonStart; i < trimmedContent.length; i++) {
                  final char = trimmedContent[i];
                  
                  if (escapeNext) {
                    escapeNext = false;
                    continue;
                  }
                  
                  if (char == '\\') {
                    escapeNext = true;
                    continue;
                  }
                  
                  if (char == '"' && !escapeNext) {
                    inString = !inString;
                    continue;
                  }
                  
                  if (!inString) {
                    if (char == '{') {
                      braceCount++;
                    } else if (char == '}') {
                      braceCount--;
                      if (braceCount == 0 && bracketCount == 0) {
                        jsonEnd = i + 1;
                        break;
                      }
                    } else if (char == '[') {
                      bracketCount++;
                    } else if (char == ']') {
                      bracketCount--;
                      if (braceCount == 0 && bracketCount == 0) {
                        jsonEnd = i + 1;
                        break;
                      }
                    }
                  }
                }
                
                if (jsonEnd > jsonStart) {
                  final extractedJson = trimmedContent.substring(jsonStart, jsonEnd).trim();
                  print('   ✅ Extracted complete JSON (${extractedJson.length} chars from ${trimmedContent.length} chars)');
                  return extractedJson;
                }
              }
              
              // If brace counting failed, check for error message and try regex fallback
              print('   ⚠️ Could not extract JSON with brace counting, checking for error message...');
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
                  final regexExtracted = jsonMatch.group(0)!.trim();
                  // Validate regex extracted JSON is complete
                  final openBraces = regexExtracted.split('{').length - 1;
                  final closeBraces = regexExtracted.split('}').length - 1;
                  final openBrackets = regexExtracted.split('[').length - 1;
                  final closeBrackets = regexExtracted.split(']').length - 1;
                  if (openBraces == closeBraces && openBrackets == closeBrackets) {
                    print('   ✅ Found complete JSON in response (regex fallback)');
                    return regexExtracted;
                  } else {
                    print('   ❌ Regex extracted incomplete JSON (braces: $openBraces/$closeBraces, brackets: $openBrackets/$closeBrackets)');
                  }
                }
                // If no JSON found, continue to next model
                continue;
              } else {
                // Unexpected format - try to extract JSON with regex as last resort
                final jsonMatch = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(content);
                if (jsonMatch != null) {
                  final regexExtracted = jsonMatch.group(0)!.trim();
                  // Validate regex extracted JSON is complete
                  final openBraces = regexExtracted.split('{').length - 1;
                  final closeBraces = regexExtracted.split('}').length - 1;
                  final openBrackets = regexExtracted.split('[').length - 1;
                  final closeBrackets = regexExtracted.split(']').length - 1;
                  if (openBraces == closeBraces && openBrackets == closeBrackets) {
                    print('   ✅ Found complete JSON in response (regex fallback)');
                    return regexExtracted;
                  } else {
                    print('   ❌ Regex extracted incomplete JSON');
                  }
                }
                print('   ❌ No valid JSON found in response');
                continue;
              }
            } else {
              print('⚠️ Empty response from model: $model');
              print('   Response data: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}...');
              continue; // Try next model
            }
          } else if (response.statusCode == 401) {
            print('❌ Authentication failed (401 Unauthorized)');
            print('   This means the API key is invalid, expired, or not authorized for this model');
            // SECURITY: Never log API key previews in production
            if (kDebugMode) {
              print('   API key length: ${apiKey.length}');
            }
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
              await Future.delayed(const Duration(milliseconds: 150)); // Reduced retry delay for speed
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
          print('⏱️ Timeout for model: $model');
          print('   This may be due to:');
          print('   1. Large image size taking longer to process');
          print('   2. Network latency');
          print('   3. API service being slow');
          print('   Attempting fallback model...');
          if (attempt < models.length - 1) {
            // Wait briefly before trying next model
            await Future.delayed(const Duration(milliseconds: 200)); // Reduced delay before fallback
          }
          continue; // Try next model
        } catch (e, stackTrace) {
          print('❌ Error with model $model: $e');
          print('   Error type: ${e.runtimeType}');
          print('   Stack trace: $stackTrace');
          if (attempt < models.length - 1) {
            // Wait briefly before trying next model
            await Future.delayed(const Duration(milliseconds: 150)); // Reduced retry delay for speed
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
