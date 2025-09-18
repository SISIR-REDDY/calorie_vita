import 'dart:io';
import '../models/food_recognition_result.dart';
import '../models/portion_estimation_result.dart';
import '../models/nutrition_info.dart';
import 'food_recognition_service.dart';
import 'portion_estimation_service.dart';
import 'nutrition_lookup_service.dart';
import 'barcode_scanning_service.dart';
import 'ai_reasoning_service.dart';

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
    } catch (e) {
      print('❌ Error in food scanner pipeline: $e');
      return FoodScannerResult(
        success: false,
        error: 'Pipeline processing failed: $e',
      );
    }
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
      },
      'capabilities': [
        'Food recognition from images',
        'Portion estimation (AR + manual)',
        'Nutrition lookup (Indian + USDA)',
        'Barcode scanning (Open Food Facts)',
        'AI analysis and recommendations',
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

  FoodScannerResult({
    required this.success,
    this.error,
    this.recognitionResult,
    this.portionResult,
    this.nutritionInfo,
    this.aiAnalysis,
    this.processingTime,
    this.isBarcodeScan = false,
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
    };
  }

  @override
  String toString() {
    return 'FoodScannerResult(success: $success, confidence: ${confidencePercentage}%, processingTime: $formattedProcessingTime)';
  }
}
