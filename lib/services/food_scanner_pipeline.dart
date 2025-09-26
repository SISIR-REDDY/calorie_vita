import 'dart:io';
import '../models/food_recognition_result.dart';
import '../models/portion_estimation_result.dart';
import '../models/nutrition_info.dart';
import 'food_recognition_service.dart';
import 'portion_estimation_service.dart';
import 'nutrition_lookup_service.dart';
import 'barcode_scanning_service.dart';
import 'ai_reasoning_service.dart';
import 'snap_to_calorie_service.dart';

/// Main food scanner pipeline that integrates all components
class FoodScannerPipeline {
  static bool _initialized = false;

  /// Initialize all services
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Future.wait([
        FoodRecognitionService.initialize(),
        PortionEstimationService.initialize(),
        NutritionLookupService.initialize(),
        BarcodeScanningService.initialize(),
      ]);
      
      _initialized = true;
      print('✅ Food scanner pipeline initialized successfully');
    } catch (e) {
      print('❌ Error initializing food scanner pipeline: $e');
    }
  }

  /// Process food image through the complete pipeline
  static Future<FoodScannerResult> processFoodImage(
    File imageFile, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // Use enhanced snap-to-calorie pipeline for better accuracy
      print('🔍 Using enhanced snap-to-calorie pipeline with AI suggestions...');
      final snapResult = await SnapToCalorieService.processFoodImage(
        imageFile,
        userProfile: userProfile,
        userGoals: userGoals,
        dietaryRestrictions: userGoals?['dietary_restrictions']?.cast<String>(),
        includeSuggestions: true,
      );
      
      if (!snapResult.isSuccessful) {
        // Fallback to original pipeline
        print('⚠️ Snap-to-calorie failed, falling back to original pipeline...');
        return await _processWithOriginalPipeline(imageFile);
      }

      // Convert snap-to-calorie result to legacy format for compatibility
      final recognitionResult = _convertSnapToLegacyRecognition(snapResult);
      final portionResult = _convertSnapToLegacyPortion(snapResult);
      final nutritionInfo = await _convertSnapToLegacyNutrition(snapResult);

      // AI Analysis
      print('🤖 Step 4: AI analysis and recommendations...');
      final aiAnalysis = await AIReasoningService.analyzeFoodWithAI(
        recognitionResult: recognitionResult,
        portionResult: portionResult,
        nutritionInfo: nutritionInfo,
        userProfile: userProfile,
      );

      return FoodScannerResult(
        success: true,
        recognitionResult: recognitionResult,
        portionResult: portionResult,
        nutritionInfo: nutritionInfo,
        aiAnalysis: aiAnalysis,
        processingTime: DateTime.now().millisecondsSinceEpoch,
        snapToCalorieResult: snapResult, // Include the enhanced result
      );
    } catch (e) {
      print('❌ Error in food scanner pipeline: $e');
      return FoodScannerResult(
        success: false,
        error: 'Pipeline processing failed: $e',
      );
    }
  }

  /// Original pipeline as fallback
  static Future<FoodScannerResult> _processWithOriginalPipeline(
    File imageFile, {
    String? userProfile,
  }) async {
    // Step 1: Food Recognition
    print('🔍 Step 1: Recognizing food...');
    final recognitionResult = await FoodRecognitionService.recognizeFoodFromImage(imageFile);
    
    if (!recognitionResult.isSuccessful) {
      return FoodScannerResult(
        success: false,
        error: 'Food recognition failed: ${recognitionResult.error}',
      );
    }

    // Step 2: Portion Estimation
    print('📏 Step 2: Estimating portion size...');
    PortionEstimationResult portionResult;
    
    if (PortionEstimationService.isArAvailable) {
      portionResult = await PortionEstimationService.estimatePortionWithAR();
    } else {
      // Fallback to food type estimation
      portionResult = PortionEstimationService.estimatePortionByFoodType(
        recognitionResult.foodName,
        recognitionResult.category,
        recognitionResult.confidence,
      );
    }

    // Step 3: Nutrition Lookup
    print('🥗 Step 3: Looking up nutrition information...');
    final nutritionInfo = await NutritionLookupService.lookupNutrition(
      recognitionResult.foodName,
      portionResult.estimatedWeight,
      recognitionResult.category,
    );

    // Step 4: AI Reasoning and Analysis
    print('🤖 Step 4: AI analysis and recommendations...');
    final aiAnalysis = await AIReasoningService.analyzeFoodWithAI(
      recognitionResult: recognitionResult,
      portionResult: portionResult,
      nutritionInfo: nutritionInfo,
      userProfile: userProfile,
    );

    return FoodScannerResult(
      success: true,
      recognitionResult: recognitionResult,
      portionResult: portionResult,
      nutritionInfo: nutritionInfo,
      aiAnalysis: aiAnalysis,
      processingTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Process barcode scan through the complete pipeline
  static Future<FoodScannerResult> processBarcodeScan(
    String barcode, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // Step 1: Barcode Scanning
      print('📱 Step 1: Scanning barcode...');
      final nutritionInfo = await BarcodeScanningService.scanBarcode(barcode);
      
      if (nutritionInfo == null) {
        return FoodScannerResult(
          success: false,
          error: 'Barcode not found in any database',
        );
      }

      // Step 2: AI Analysis
      print('🤖 Step 2: AI analysis and recommendations...');
      final aiAnalysis = await AIReasoningService.analyzeFoodWithAI(
        recognitionResult: FoodRecognitionResult(
          foodName: nutritionInfo.foodName,
          confidence: 0.9, // High confidence for barcode scans
          category: nutritionInfo.category ?? 'Unknown',
          cuisine: nutritionInfo.cuisine ?? 'Unknown',
        ),
        portionResult: PortionEstimationResult(
          estimatedWeight: nutritionInfo.weightGrams,
          confidence: 0.9,
          method: 'Barcode scan',
        ),
        nutritionInfo: nutritionInfo,
        userProfile: userProfile,
      );

      return FoodScannerResult(
        success: true,
        nutritionInfo: nutritionInfo,
        aiAnalysis: aiAnalysis,
        processingTime: DateTime.now().millisecondsSinceEpoch,
        isBarcodeScan: true,
      );
    } catch (e) {
      print('❌ Error in barcode scanner pipeline: $e');
      return FoodScannerResult(
        success: false,
        error: 'Barcode processing failed: $e',
      );
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
      return await AIReasoningService.getPortionRecommendations(
        foodName: foodName,
        currentPortion: currentPortion,
        userProfile: userProfile,
        goals: goals,
      );
    } catch (e) {
      print('❌ Error getting portion recommendations: $e');
      return {
        'error': 'Failed to get portion recommendations: $e',
        'recommendedPortion': currentPortion,
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
      return await AIReasoningService.getFoodSubstitutions(
        currentFood: currentFood,
        userProfile: userProfile,
        dietaryRestrictions: dietaryRestrictions,
      );
    } catch (e) {
      print('❌ Error getting food substitutions: $e');
      return {
        'error': 'Failed to get food substitutions: $e',
        'substitutions': [],
      };
    }
  }

  /// Analyze meal balance
  static Future<Map<String, dynamic>> analyzeMealBalance({
    required List<NutritionInfo> foods,
    String? userProfile,
  }) async {
    try {
      return await AIReasoningService.analyzeMealBalance(
        foods: foods,
        userProfile: userProfile,
      );
    } catch (e) {
      print('❌ Error analyzing meal balance: $e');
      return {
        'error': 'Failed to analyze meal balance: $e',
        'balance': 'Unknown',
      };
    }
  }

  /// Process food image and return snap-to-calorie JSON output directly
  static Future<Map<String, dynamic>?> processSnapToCalorie(
    File imageFile, {
    String? userProfile,
    Map<String, dynamic>? userGoals,
    List<String>? dietaryRestrictions,
    bool includeSuggestions = true,
  }) async {
    try {
      final snapResult = await SnapToCalorieService.processFoodImage(
        imageFile,
        userProfile: userProfile,
        userGoals: userGoals,
        dietaryRestrictions: dietaryRestrictions,
        includeSuggestions: includeSuggestions,
      );
      return snapResult.toJson();
    } catch (e) {
      print('❌ Error in snap-to-calorie processing: $e');
      return null;
    }
  }

  /// Get pipeline status
  static Map<String, dynamic> getPipelineStatus() {
    return {
      'initialized': _initialized,
      'services': {
        'foodRecognition': true,
        'portionEstimation': PortionEstimationService.isArAvailable,
        'nutritionLookup': true,
        'barcodeScanning': true,
        'aiReasoning': true,
        'snapToCalorie': true,
      },
      'capabilities': [
        'Food recognition from images',
        'Portion estimation (AR + manual)',
        'Nutrition lookup (Indian + USDA)',
        'Barcode scanning (Open Food Facts)',
        'AI analysis and recommendations',
        'Enhanced snap-to-calorie pipeline',
      ],
    };
  }

  /// Get available portion estimation methods
  static List<String> getAvailablePortionMethods() {
    return PortionEstimationService.getAvailableMethods();
  }

  /// Get predefined portion options
  static List<PortionOption> getPredefinedPortions() {
    return PortionEstimationService.getPredefinedPortions();
  }

  /// Convert snap-to-calorie result to legacy recognition format
  static FoodRecognitionResult _convertSnapToLegacyRecognition(SnapToCalorieResult snapResult) {
    if (snapResult.items.isEmpty) {
      return FoodRecognitionResult(
        foodName: 'Unknown Food',
        confidence: 0.0,
        category: 'Unknown',
        cuisine: 'Unknown',
        error: 'No items identified',
      );
    }

    final primaryItem = snapResult.items.first;
    return FoodRecognitionResult(
      foodName: primaryItem.name,
      confidence: primaryItem.confidence,
      category: _inferCategory(primaryItem.name),
      cuisine: 'Indian', // Default for our use case
    );
  }

  /// Convert snap-to-calorie result to legacy portion format
  static PortionEstimationResult _convertSnapToLegacyPortion(SnapToCalorieResult snapResult) {
    if (snapResult.items.isEmpty) {
      return PortionEstimationResult(
        estimatedWeight: 0.0,
        confidence: 0.0,
        method: 'Unknown',
      );
    }

    final totalWeight = snapResult.items.fold(0.0, (sum, item) => sum + item.massG.value);
    final avgConfidence = snapResult.overallConfidence;
    
    return PortionEstimationResult(
      estimatedWeight: totalWeight,
      confidence: avgConfidence,
      method: 'snap_to_calorie',
    );
  }

  /// Convert snap-to-calorie result to legacy nutrition format
  static Future<NutritionInfo> _convertSnapToLegacyNutrition(SnapToCalorieResult snapResult) async {
    if (snapResult.items.isEmpty) {
      return NutritionInfo(
        foodName: 'Unknown Food',
        calories: 0.0,
        weightGrams: 0.0,
        protein: 0.0,
        carbs: 0.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 0.0,
        source: 'snap_to_calorie_service',
      );
    }

    final primaryItem = snapResult.items.first;
    final totalCalories = snapResult.totalCalories;
    final totalWeight = snapResult.items.fold(0.0, (sum, item) => sum + item.massG.value);
    
    // Estimate macros based on food type (with nutrition lookup)
    final macros = await _estimateMacros(primaryItem.name, totalWeight);
    
    return NutritionInfo(
      foodName: primaryItem.name,
      calories: totalCalories,
      weightGrams: totalWeight,
      protein: macros['protein'] ?? 0.0,
      carbs: macros['carbs'] ?? 0.0,
      fat: macros['fat'] ?? 0.0,
      fiber: macros['fiber'] ?? 0.0,
      sugar: (macros['carbs'] ?? 0.0) * 0.3, // Estimate sugar as 30% of carbs
      source: 'snap_to_calorie_service',
      category: _inferCategory(primaryItem.name),
      cuisine: 'Indian',
    );
  }

  /// Infer food category from name
  static String _inferCategory(String foodName) {
    final name = foodName.toLowerCase();
    if (name.contains('rice')) return 'Grains';
    if (name.contains('dal') || name.contains('lentil')) return 'Legumes';
    if (name.contains('chicken') || name.contains('meat')) return 'Protein';
    if (name.contains('curry') || name.contains('sabzi')) return 'Vegetables';
    if (name.contains('roti') || name.contains('naan') || name.contains('bread')) return 'Bread';
    if (name.contains('paneer')) return 'Dairy';
    return 'Other';
  }

  /// Estimate macros for food using nutrition lookup service
  static Future<Map<String, double>> _estimateMacros(String foodName, double weight) async {
    try {
      // Try to get accurate nutrition data first
      final nutritionInfo = await NutritionLookupService.lookupNutrition(
        foodName,
        weight,
        null, // category will be inferred
      );
      
      if (nutritionInfo.calories > 0) {
        return {
          'protein': nutritionInfo.protein,
          'carbs': nutritionInfo.carbs,
          'fat': nutritionInfo.fat,
          'fiber': nutritionInfo.fiber,
        };
      }
    } catch (e) {
      print('❌ Error looking up macros for $foodName: $e');
    }
    
    // Fallback to category-based estimation
    final name = foodName.toLowerCase();
    
    if (name.contains('rice') || name.contains('biryani') || name.contains('pulao')) {
      return {
        'protein': (weight * 2.7) / 100,
        'carbs': (weight * 28.0) / 100,
        'fat': (weight * 0.3) / 100,
        'fiber': (weight * 0.4) / 100,
      };
    } else if (name.contains('dal') || name.contains('lentil') || name.contains('chana')) {
      return {
        'protein': (weight * 24.0) / 100,
        'carbs': (weight * 63.0) / 100,
        'fat': (weight * 2.0) / 100,
        'fiber': (weight * 10.0) / 100,
      };
    } else if (name.contains('chicken') || name.contains('mutton') || name.contains('fish')) {
      return {
        'protein': (weight * 27.0) / 100,
        'carbs': (weight * 0.0) / 100,
        'fat': (weight * 14.0) / 100,
        'fiber': (weight * 0.0) / 100,
      };
    } else if (name.contains('paneer') || name.contains('cheese')) {
      return {
        'protein': (weight * 18.0) / 100,
        'carbs': (weight * 1.0) / 100,
        'fat': (weight * 20.0) / 100,
        'fiber': (weight * 0.0) / 100,
      };
    } else if (name.contains('roti') || name.contains('naan') || name.contains('bread')) {
      return {
        'protein': (weight * 8.0) / 100,
        'carbs': (weight * 50.0) / 100,
        'fat': (weight * 2.0) / 100,
        'fiber': (weight * 2.0) / 100,
      };
    } else if (name.contains('curry') || name.contains('sabzi') || name.contains('vegetable')) {
      return {
        'protein': (weight * 2.0) / 100,
        'carbs': (weight * 8.0) / 100,
        'fat': (weight * 0.5) / 100,
        'fiber': (weight * 3.0) / 100,
      };
    } else {
      // Default estimation
      return {
        'protein': (weight * 10.0) / 100,
        'carbs': (weight * 20.0) / 100,
        'fat': (weight * 5.0) / 100,
        'fiber': (weight * 2.0) / 100,
      };
    }
  }
}

/// Result of the food scanner pipeline
class FoodScannerResult {
  final bool success;
  final String? error;
  final FoodRecognitionResult? recognitionResult;
  final PortionEstimationResult? portionResult;
  final NutritionInfo? nutritionInfo;
  final Map<String, dynamic>? aiAnalysis;
  final int? processingTime;
  final bool isBarcodeScan;
  final SnapToCalorieResult? snapToCalorieResult;

  FoodScannerResult({
    required this.success,
    this.error,
    this.recognitionResult,
    this.portionResult,
    this.nutritionInfo,
    this.aiAnalysis,
    this.processingTime,
    this.isBarcodeScan = false,
    this.snapToCalorieResult,
  });

  /// Get formatted processing time
  String get formattedProcessingTime {
    if (processingTime == null) return 'Unknown';
    final duration = DateTime.now().millisecondsSinceEpoch - processingTime!;
    return '${duration}ms';
  }

  /// Get confidence score
  double get confidenceScore {
    if (recognitionResult != null && portionResult != null) {
      return (recognitionResult!.confidence + portionResult!.confidence) / 2;
    }
    return 0.0;
  }

  /// Get formatted confidence percentage
  int get confidencePercentage => (confidenceScore * 100).round();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'error': error,
      'recognitionResult': recognitionResult?.toJson(),
      'portionResult': portionResult?.toJson(),
      'nutritionInfo': nutritionInfo?.toJson(),
      'aiAnalysis': aiAnalysis,
      'processingTime': processingTime,
      'isBarcodeScan': isBarcodeScan,
      'snapToCalorieResult': snapToCalorieResult?.toJson(),
    };
  }

  @override
  String toString() {
    return 'FoodScannerResult(success: $success, confidence: ${confidencePercentage}%, processingTime: $formattedProcessingTime)';
  }
}
