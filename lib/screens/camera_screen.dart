import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/food_scanner_pipeline.dart';
import '../services/optimized_food_scanner_pipeline.dart';
import '../services/barcode_scanning_service.dart';
import '../services/app_state_service.dart';
import '../models/food_entry.dart';
import '../models/nutrition_info.dart';
import '../models/portion_estimation_result.dart';
import '../widgets/food_result_card.dart';
import '../ui/app_colors.dart';
import '../services/food_history_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  String? _barcode;
  bool _loading = false;
  FoodScannerResult? _scannerResult;
  String? _error;
  bool _showBarcodeScanner = false;
  bool _showPortionSelector = false;
  double _selectedPortion = 150.0; // Default portion in grams

  final ImagePicker _picker = ImagePicker();

  /// Parse macro value from string (e.g., "15g" -> 15.0)
  double _parseMacroValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove 'g' suffix and parse
      final cleanValue = value.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(cleanValue) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _pickImage() async {
    setState(() {
      _loading = true;
      _error = null;
      _scannerResult = null;
      _showPortionSelector = false;
    });

    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
        
        // Process image through the optimized food scanner pipeline
        final result = await OptimizedFoodScannerPipeline.processFoodImage(_imageFile!);
        
        setState(() {
          _scannerResult = result;
          if (result.success && result.portionResult != null) {
            _selectedPortion = result.portionResult!.estimatedWeight;
          }
        });
        
        // Save to food history if successful
        if (result.success && result.nutritionInfo != null) {
          await _saveToFoodHistory(result, 'camera_scan');
        }
        
        // Show portion selector if needed
        if (result.success && result.portionResult != null && 
            result.portionResult!.isLowConfidence) {
          setState(() {
            _showPortionSelector = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = "Couldn't capture or analyze image. Try again.";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _showBarcodeScanner = true;
      _error = null;
      _scannerResult = null;
      _showPortionSelector = false;
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null) {
      print('📱 Barcode detected: $barcode');
      setState(() {
        _showBarcodeScanner = false;
        _loading = true;
        _barcode = barcode;
      });
      try {
        // Process barcode through the optimized food scanner pipeline
        final result = await OptimizedFoodScannerPipeline.processBarcodeScan(barcode);
        
        // Debug: Print nutrition data to help identify issues
        if (result != null && result.success && result.nutritionInfo != null) {
          final nutrition = result.nutritionInfo!;
          print('🔍 DEBUG - Barcode scan result:');
          print('📦 Product: ${nutrition.foodName}');
          print('⚖️ Weight: ${nutrition.weightGrams}g');
          print('🔥 Calories: ${nutrition.calories}');
          print('🥩 Protein: ${nutrition.protein}g');
          print('🍞 Carbs: ${nutrition.carbs}g');
          print('🧈 Fat: ${nutrition.fat}g');
          print('🌾 Fiber: ${nutrition.fiber}g');
          print('🍯 Sugar: ${nutrition.sugar}g');
          print('📊 Source: ${nutrition.source}');
          print('🏷️ Category: ${nutrition.category}');
          print('🏢 Brand: ${nutrition.brand}');
          
          // Check if nutrition data is valid and try to fix if needed
          if (nutrition.calories == 0 || (nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0)) {
            print('❌ WARNING: Missing nutrition data! Attempting to fix...');
            
            // Try to get nutrition data from product name
            try {
              final fixedNutrition = await _tryFixMissingNutrition(nutrition);
              if (fixedNutrition != null) {
                print('✅ Fixed nutrition data: ${fixedNutrition.calories} calories');
                final fixedResult = FoodScannerResult(
                  success: true,
                  recognitionResult: result.recognitionResult,
                  portionResult: result.portionResult,
                  nutritionInfo: fixedNutrition,
                  aiAnalysis: result.aiAnalysis,
                  processingTime: result.processingTime,
                  isBarcodeScan: result.isBarcodeScan,
                );
                setState(() {
                  _scannerResult = fixedResult;
                });
                return;
              }
            } catch (e) {
              print('❌ Failed to fix nutrition data: $e');
            }
          }
        }
        
        setState(() {
          _scannerResult = result;
          if (result != null && !result.success) {
            _error = result.error ?? "Barcode not found in any database";
          }
        });
        
        // Save to food history if successful
        if (result != null && result.success && result.nutritionInfo != null) {
          await _saveToFoodHistory(result, 'barcode_scan');
        }
      } catch (e) {
        print('❌ Barcode processing error: $e');
        setState(() {
          _error = "Couldn't fetch product info. Try again.";
        });
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _barcode = null;
      _scannerResult = null;
      _error = null;
      _loading = false;
      _showBarcodeScanner = false;
      _showPortionSelector = false;
      _selectedPortion = 150.0;
    });
  }

  void _testBarcodeScanning() async {
    print('🧪 Testing barcode scanning...');
    await BarcodeScanningService.testBarcodeScanning();
  }

  /// Test specific barcode for debugging
  void _testSpecificBarcode(String barcode) async {
    print('🧪 Testing specific barcode: $barcode');
    setState(() {
      _loading = true;
      _error = null;
      _scannerResult = null;
    });
    
    try {
      final result = await OptimizedFoodScannerPipeline.processBarcodeScan(barcode);
      
      print('🔍 Test result for barcode $barcode:');
      print('Success: ${result?.success}');
      if (result?.nutritionInfo != null) {
        final nutrition = result!.nutritionInfo!;
        print('Product: ${nutrition.foodName}');
        print('Calories: ${nutrition.calories}');
        print('Protein: ${nutrition.protein}');
        print('Carbs: ${nutrition.carbs}');
        print('Fat: ${nutrition.fat}');
        print('Source: ${nutrition.source}');
        print('Is Valid: ${nutrition.isValid}');
      }
      
      setState(() {
        _scannerResult = result;
        _loading = false;
      });
    } catch (e) {
      print('❌ Test error: $e');
      setState(() {
        _error = 'Test failed: $e';
        _loading = false;
      });
    }
  }

  /// Try to fix missing nutrition data by looking up the product name
  Future<NutritionInfo?> _tryFixMissingNutrition(NutritionInfo originalNutrition) async {
    try {
      print('🔍 Attempting to fix nutrition data for: ${originalNutrition.foodName}');
      
      // Use the barcode scanning service to get nutrition from product name
      final fixedNutrition = await BarcodeScanningService.getNutritionFromProductName(originalNutrition.foodName);
      
      if (fixedNutrition != null && fixedNutrition.calories > 0) {
        print('✅ Found nutrition data for product name: ${fixedNutrition.calories} calories');
        
        // Merge the fixed nutrition with original data
        return NutritionInfo(
          foodName: originalNutrition.foodName,
          weightGrams: originalNutrition.weightGrams,
          calories: fixedNutrition.calories,
          protein: fixedNutrition.protein,
          carbs: fixedNutrition.carbs,
          fat: fixedNutrition.fat,
          fiber: fixedNutrition.fiber,
          sugar: fixedNutrition.sugar,
          source: '${originalNutrition.source} + Product Name Lookup',
          category: originalNutrition.category ?? fixedNutrition.category,
          brand: originalNutrition.brand ?? fixedNutrition.brand,
          notes: '${originalNutrition.notes ?? ''} | Fixed via product name lookup',
        );
      }
    } catch (e) {
      print('❌ Error fixing nutrition data: $e');
    }
    
    return null;
  }

  void _updatePortion(double newPortion) {
    setState(() {
      _selectedPortion = newPortion;
    });
  }

  /// Save food entry to history
  Future<void> _saveToFoodHistory(FoodScannerResult result, String source) async {
    try {
      if (result.nutritionInfo != null) {
        // Create scan data for detailed view
        Map<String, dynamic>? scanData;
        if (result.snapToCalorieResult != null) {
          scanData = {
            'confidence': result.snapToCalorieResult!.overallConfidence,
            'overall_confidence': result.snapToCalorieResult!.overallConfidence,
            'recommended_action': result.snapToCalorieResult!.recommendedAction,
            'notes': result.snapToCalorieResult!.notes,
            'items_count': result.snapToCalorieResult!.items.length,
            'ai_suggestions': result.snapToCalorieResult!.aiSuggestions?.toJson(),
          };
        }
        
        final success = await FoodHistoryService.addFoodFromNutritionInfo(
          result.nutritionInfo!,
          source: source,
          imagePath: _imageFile?.path,
          scanData: scanData,
        );
        
        if (success) {
          print('✅ Food entry saved to history: ${result.nutritionInfo!.foodName}');
        } else {
          print('❌ Failed to save food entry to history');
        }
      }
    } catch (e) {
      print('❌ Error saving food entry to history: $e');
    }
  }

  void _confirmPortion() {
    setState(() {
      _showPortionSelector = false;
    });
    // Recalculate nutrition with new portion
    if (_scannerResult != null && _scannerResult!.nutritionInfo != null) {
      final nutrition = _scannerResult!.nutritionInfo!;
      final multiplier = _selectedPortion / nutrition.weightGrams;
      
      setState(() {
        _scannerResult = FoodScannerResult(
          success: true,
          recognitionResult: _scannerResult!.recognitionResult,
          portionResult: PortionEstimationResult(
            estimatedWeight: _selectedPortion,
            confidence: 0.8,
            method: 'Manual selection',
          ),
          nutritionInfo: nutrition.copyWith(
            weightGrams: _selectedPortion,
            calories: nutrition.calories * multiplier,
            protein: nutrition.protein * multiplier,
            carbs: nutrition.carbs * multiplier,
            fat: nutrition.fat * multiplier,
            fiber: nutrition.fiber * multiplier,
            sugar: nutrition.sugar * multiplier,
          ),
          aiAnalysis: _scannerResult!.aiAnalysis,
          processingTime: _scannerResult!.processingTime,
          isBarcodeScan: _scannerResult!.isBarcodeScan,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: _buildPremiumAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kAppBackground, kSurfaceLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _showBarcodeScanner
              ? _buildBarcodeScanner()
              : _buildMainContent(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Food Scanner',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: kTextDark,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: const [],
    );
  }

  Widget _buildBarcodeScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: _onBarcodeDetected,
        ),
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _reset,
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Point your camera at a barcode',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_loading) _buildLoadingState(),
          if (_error != null) _buildErrorState(),
          if (_scannerResult != null) _buildResultState(),
          if (_showPortionSelector) _buildPortionSelector(),
          if (_imageFile != null && _scannerResult == null) _buildImagePreview(),
          if (_scannerResult == null && !_loading) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(kAccentBlue),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  'Analyzing your food...',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: FoodResultCard(
        title: 'Error',
        comment: _error,
        onRetry: _reset,
      ),
    );
  }

  Widget _buildResultState() {
    if (_scannerResult == null || !_scannerResult!.success) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: FoodResultCard(
          title: 'Error',
          comment: _scannerResult?.error ?? 'Unknown error',
          onRetry: _reset,
        ),
      );
    }

    final nutrition = _scannerResult!.nutritionInfo!;
    final recognition = _scannerResult!.recognitionResult;
    final portion = _scannerResult!.portionResult;
    final aiAnalysis = _scannerResult!.aiAnalysis;

    // DEBUG: Print detailed nutrition data for UI rendering
    print('🔍 UI DEBUG - Rendering nutrition data:');
    print('📦 Product: ${nutrition.foodName}');
    print('⚖️ Weight: ${nutrition.weightGrams}g');
    print('🔥 Calories: ${nutrition.calories} (formatted: ${nutrition.formattedCalories})');
    print('🥩 Protein: ${nutrition.protein}g (formatted: ${nutrition.formattedProtein})');
    print('🍞 Carbs: ${nutrition.carbs}g (formatted: ${nutrition.formattedCarbs})');
    print('🧈 Fat: ${nutrition.fat}g (formatted: ${nutrition.formattedFat})');
    print('🌾 Fiber: ${nutrition.fiber}g (formatted: ${nutrition.formattedFiber})');
    print('🍯 Sugar: ${nutrition.sugar}g (formatted: ${nutrition.formattedSugar})');
    print('📊 Source: ${nutrition.source}');
    print('🏷️ Category: ${nutrition.category}');
    print('🏢 Brand: ${nutrition.brand}');
    print('📝 Notes: ${nutrition.notes}');
    print('❌ Error: ${nutrition.error}');
    print('✅ Is Valid: ${nutrition.isValid}');
    
    // Check if nutrition data is actually valid
    if (!nutrition.isValid) {
      print('❌ CRITICAL: Nutrition data is marked as invalid!');
    }
    
    if (nutrition.calories <= 0) {
      print('❌ CRITICAL: No calories found!');
    }
    
    if (nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0) {
      print('❌ CRITICAL: No macro nutrients found!');
    }

    // If nutrition data is invalid or missing, show a special message
    if (!nutrition.isValid || nutrition.calories <= 0) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // Product info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kAccentBlue, kAccentBlue.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nutrition.foodName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nutrition.formattedWeight,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            if (nutrition.brand != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'by ${nutrition.brand}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Nutrition data missing message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nutrition Data Not Available',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We found the product "${nutrition.foodName}" but couldn\'t retrieve nutrition information. This might be a new product or the barcode might not be in our database.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.orange[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Try to get nutrition from product name
                          _tryFixMissingNutrition(nutrition).then((fixedNutrition) {
                            if (fixedNutrition != null) {
                              setState(() {
                                _scannerResult = FoodScannerResult(
                                  success: true,
                                  recognitionResult: _scannerResult!.recognitionResult,
                                  portionResult: _scannerResult!.portionResult,
                                  nutritionInfo: fixedNutrition,
                                  aiAnalysis: _scannerResult!.aiAnalysis,
                                  processingTime: _scannerResult!.processingTime,
                                  isBarcodeScan: _scannerResult!.isBarcodeScan,
                                );
                              });
                            }
                          });
                        },
                        icon: Icon(Icons.refresh, color: Colors.white),
                        label: Text('Try Again', style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _reset,
                        icon: Icon(Icons.camera_alt, color: Colors.white),
                        label: Text('Scan Again', style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentBlue,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Enhanced Food Result Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                // Header with confidence indicator
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nutrition.foodName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nutrition.formattedWeight,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            if (nutrition.brand != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'by ${nutrition.brand}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Confidence indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_scannerResult!.confidencePercentage}%',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Nutrition details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Calories
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kAccentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Calories',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: kTextDark,
                              ),
                            ),
                            Text(
                              nutrition.formattedCalories,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: kAccentBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Macros
                      Row(
                        children: [
                          Expanded(
                            child: _buildMacroCard(
                              'Protein',
                              nutrition.protein,
                              kAccentGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMacroCard(
                              'Carbs',
                              nutrition.carbs,
                              kWarningColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMacroCard(
                              'Fat',
                              nutrition.fat,
                              kErrorColor,
                            ),
                          ),
                        ],
                      ),
                      
                      // Additional nutrition info
                      if (nutrition.fiber > 0 || nutrition.sugar > 0) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (nutrition.fiber > 0)
                              Expanded(
                                child: _buildMacroCard(
                                  'Fiber',
                                  nutrition.fiber,
                                  kAccentPurple,
                                ),
                              ),
                            if (nutrition.fiber > 0 && nutrition.sugar > 0)
                              const SizedBox(width: 12),
                            if (nutrition.sugar > 0)
                              Expanded(
                                child: _buildMacroCard(
                                  'Sugar',
                                  nutrition.sugar,
                                  kAccentPurple,
                                ),
                              ),
                          ],
                        ),
                      ],
                      
                      // AI Analysis
                      if (aiAnalysis != null && aiAnalysis!['insights'] != null) ...[
                        const SizedBox(height: 20),
                        _buildAIAnalysis(aiAnalysis!),
                      ],
                      
                      // Source information
                      if (nutrition.source != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kSurfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: kTextSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Source: ${nutrition.source}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: kCardShadow,
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                'Save to History',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              onPressed: () async {
                if (_scannerResult != null && _scannerResult!.success) {
                  try {
                    final nutrition = _scannerResult!.nutritionInfo!;

                    // Create food entry
                    final foodEntry = FoodEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nutrition.foodName,
                      calories: nutrition.calories.round(),
                      timestamp: DateTime.now(),
                      imageUrl: null, // TODO: Upload image to Firebase Storage if needed
                      protein: nutrition.protein,
                      carbs: nutrition.carbs,
                      fat: nutrition.fat,
                      fiber: nutrition.fiber,
                      sugar: nutrition.sugar,
                    );

                    // Save to app state (which will sync to Firestore)
                    await AppStateService().saveFoodEntry(foodEntry);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Food saved to history! Calories: ${foodEntry.calories}, Protein: ${nutrition.formattedProtein}, Carbs: ${nutrition.formattedCarbs}, Fat: ${nutrition.formattedFat}',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: kSuccessColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );

                      // Navigate back or reset the camera
                      _reset();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error saving food entry: $e',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No food data to save!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: kElevatedShadow,
          ),
          child: Image.file(
            _imageFile!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.only(bottom: 40),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: kCardShadow,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Scan Your Food',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a photo or scan a barcode to get\nnutritional information instantly',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: kTextSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Action Buttons - Equally Spaced
          Column(
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                title: 'Take Photo',
                subtitle: 'Capture food image',
                onTap: _pickImage,
                gradient: LinearGradient(
                  colors: [kAccentBlue, kAccentBlue.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              const SizedBox(height: 20),
              _buildActionButton(
                icon: Icons.qr_code_scanner,
                title: 'Scan Barcode',
                subtitle: 'Scan product code',
                onTap: _scanBarcode,
                gradient: LinearGradient(
                  colors: [kAccentGreen, kAccentGreen.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              
              // Debug buttons (only in debug mode)
              if (kDebugMode) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _testSpecificBarcode('7622210734962'), // Example barcode
                        icon: const Icon(Icons.bug_report, size: 16),
                        label: Text(
                          'Test Barcode',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testBarcodeScanning,
                        icon: const Icon(Icons.science, size: 16),
                        label: Text(
                          'Debug Test',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required LinearGradient gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysis(Map<String, dynamic> aiAnalysis) {
    final insights = aiAnalysis['insights'] as List<dynamic>? ?? [];
    final recommendations = aiAnalysis['recommendations'] as List<dynamic>? ?? [];
    final tips = aiAnalysis['tips'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Analysis',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          
          if (insights.isNotEmpty) ...[
            _buildAnalysisSection('Insights', insights, Icons.lightbulb_outline),
            const SizedBox(height: 12),
          ],
          
          if (recommendations.isNotEmpty) ...[
            _buildAnalysisSection('Recommendations', recommendations, Icons.recommend),
            const SizedBox(height: 12),
          ],
          
          if (tips.isNotEmpty) ...[
            _buildAnalysisSection('Tips', tips, Icons.tips_and_updates),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, List<dynamic> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kAccentBlue),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 4),
          child: Text(
            '• ${item.toString()}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kTextSecondary,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildPortionSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Text(
            'Adjust Portion Size',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            '${_selectedPortion.toStringAsFixed(0)}g',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kAccentBlue,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Slider(
            value: _selectedPortion,
            min: 50,
            max: 500,
            divisions: 45,
            activeColor: kAccentBlue,
            inactiveColor: kAccentBlue.withOpacity(0.3),
            onChanged: _updatePortion,
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmPortion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showPortionSelector = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: kTextDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
