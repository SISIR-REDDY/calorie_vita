import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/optimized_food_scanner_pipeline.dart';
import '../config/ai_config.dart';
import '../services/network_service.dart';
import '../services/barcode_scanning_service.dart';
// Unused imports removed
import '../models/food_history_entry.dart';
import '../models/nutrition_info.dart';
import '../models/portion_estimation_result.dart';
import '../models/food_recognition_result.dart';
import '../widgets/food_result_card.dart';
import '../widgets/manual_food_entry_dialog.dart';
import '../ui/app_colors.dart';
import '../services/food_history_service.dart';
// Unused import removed

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  // _barcode removed - never used
  bool _loading = false;
  FoodScannerResult? _scannerResult;
  String? _error;
  bool _showBarcodeScanner = false;
  bool _showPortionSelector = false;
  double _selectedPortion = 150.0; // Default portion in grams
  bool _barcodeProcessing = false; // Prevent multiple barcode detections
  bool _scannerDisabled = false; // Completely disable scanner after detection

  final ImagePicker _picker = ImagePicker();
  MobileScannerController? _scannerController;

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
    print('📸 Image picker initiated');
    setState(() {
      _loading = true;
      _error = null;
      _scannerResult = null;
      _showPortionSelector = false;
    });

    try {
      // Preflight: ensure AI vision is enabled, API key present, and network online
      if (kDebugMode) {
        print('🔍 Preflight checks for image analysis...');
        print('   - Image analysis enabled: ${AIConfig.enableImageAnalysis}');
        // SECURITY: Never log API key details in production
        print('   - API key configured: ${AIConfig.apiKey.isNotEmpty}');
        print('   - Network online: ${NetworkService().isOnline}');
        print('   - Vision model: ${AIConfig.visionModel}');
      }
      
      if (!AIConfig.enableImageAnalysis) {
        print('❌ Image analysis is disabled in configuration');
        setState(() {
          _loading = false;
          _error = 'Image analysis is disabled in configuration. You can add food manually.';
        });
        return;
      }

      if (AIConfig.apiKey.isEmpty) {
        print('❌ API key is empty - config may not have loaded from Firebase');
        print('   - Check Firebase console for app_config/ai_settings document');
        setState(() {
          _loading = false;
          _error = 'AI service is not configured (missing API key). Please sign in and try again later or add food manually.';
        });
        return;
      }

      if (!NetworkService().isOnline) {
        print('❌ Network is offline');
        setState(() {
          _loading = false;
          _error = 'No internet connection. Please connect to the internet or add food manually.';
        });
        return;
      }
      
      print('✅ All preflight checks passed, proceeding with image capture...');

      final picked = await _picker.pickImage(source: ImageSource.camera).catchError((error) {
        print('❌ Image picker error: $error');
        if (mounted) {
          setState(() {
            // Provide user-friendly error messages based on error type
            if (error.toString().contains('permission') || error.toString().contains('Permission')) {
              _error = 'Camera permission is required. Please enable camera access in your device settings to take food photos.';
            } else if (error.toString().contains('not available') || error.toString().contains('unavailable')) {
              _error = 'Camera is not available. Please check if another app is using the camera.';
            } else {
              _error = 'Could not access camera. Please try again or add food manually.';
            }
            _loading = false;
          });
        }
        return null;
      });
      
      if (picked != null) {
        print('✅ Image captured: ${picked.path}');
        setState(() {
          _imageFile = File(picked.path);
        });
        
        // Process image through the optimized food scanner pipeline
        print('🚀 Starting image processing pipeline...');
        var result = await OptimizedFoodScannerPipeline.processFoodImage(_imageFile!);
        print('📊 Image processing result: success=${result.success}, error=${result.error}');

        // If result is missing calories or macros, attempt to fix via product name lookup
        if (result.success && result.nutritionInfo != null) {
          final nutrition = result.nutritionInfo!;
          final missingCalories = nutrition.calories <= 0;
          final missingMacros = nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0;
          if (missingCalories || missingMacros) {
            try {
              final fixedNutrition = await _tryFixMissingNutrition(nutrition);
              if (fixedNutrition != null) {
                final fixedResult = FoodScannerResult(
                  success: true,
                  recognitionResult: result.recognitionResult,
                  portionResult: result.portionResult,
                  nutritionInfo: fixedNutrition,
                  aiAnalysis: result.aiAnalysis,
                  processingTime: result.processingTime,
                  isBarcodeScan: result.isBarcodeScan,
                  confidencePercentage: (result.confidencePercentage * 0.9).clamp(0.0, 100.0),
                );
                result = fixedResult;
              }
            } catch (_) {}
          }
        }

        setState(() {
          _scannerResult = result;
          if (!result.success) {
            _error = result.error ?? "Couldn't analyze image. Please try again or add food manually.";
            print('❌ Image analysis failed: ${result.error}');
          } else {
            // Clear error on success to avoid showing duplicate errors
            _error = null;
            if (result.portionResult != null) {
              _selectedPortion = result.portionResult!.estimatedWeight;
            }
          }
        });

        // Auto-save successful scan results
        if (result.success && result.nutritionInfo != null) {
          _autoSaveFood(result, 'camera_scan');
        }
        
        // Show portion selector if needed
        if (result.success && result.portionResult != null && 
            result.portionResult!.isLowConfidence) {
          setState(() {
            _showPortionSelector = true;
          });
        }
      } else {
        // User cancelled image picker
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
    } catch (e, stackTrace) {
      print('❌ Error in image picker: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = "Couldn't capture or analyze image: ${e.toString()}. Please try again or add food manually.";
          _loading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _scanBarcode() async {
    print('📱 Barcode scanner initiated');
    
    // Dispose existing controller if any
    _scannerController?.dispose();
    
    setState(() {
      _showBarcodeScanner = true;
      _error = null;
      _scannerResult = null;
      _showPortionSelector = false;
      _barcodeProcessing = false; // Reset processing flag
      _scannerDisabled = false; // Reset scanner disabled flag
    });
    
    // Initialize scanner controller with proper configuration
    _scannerController = MobileScannerController(
      formats: [BarcodeFormat.all],
      facing: CameraFacing.back,
      autoStart: true,
    );
    
    // Ensure scanner starts
    try {
      await _scannerController?.start();
      print('✅ Barcode scanner started and ready - waiting for barcode detection...');
    } catch (e) {
      print('❌ Error starting scanner: $e');
      if (mounted) {
        setState(() {
          // Provide user-friendly error message with actionable guidance
          if (e.toString().contains('permission') || e.toString().contains('Permission')) {
            _error = 'Camera permission is required to scan barcodes. Please enable camera access in your device settings.';
          } else if (e.toString().contains('not available') || e.toString().contains('unavailable')) {
            _error = 'Camera is not available. Please check if another app is using the camera.';
          } else {
            _error = 'Could not start camera. Please try again or add food manually.';
          }
          _showBarcodeScanner = false;
        });
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && _showBarcodeScanner && !_barcodeProcessing && !_scannerDisabled) { // Only process if still in barcode scanner mode and not already processing
      print('📱 Barcode detected: $barcode');
      
      // Set processing flag to prevent multiple detections
      _barcodeProcessing = true;
      _scannerDisabled = true; // Completely disable scanner
      
      // Stop and dispose the scanner immediately to prevent automatic switching
      try {
        await _scannerController?.stop();
      } catch (e) {
        print('⚠️ Error stopping scanner: $e');
      }
      _scannerController?.dispose();
      _scannerController = null;
      
      setState(() {
        _showBarcodeScanner = false;
        _loading = true;
        // _barcode removed
      });
      try {
        // Process barcode through the optimized food scanner pipeline
        print('🔍 Starting barcode processing pipeline for: $barcode');
        final result = await OptimizedFoodScannerPipeline.processBarcodeScan(barcode);
        print('📊 Barcode processing result: success=${result.success}, error=${result.error}');
        
        // Check result and fix missing nutrition data if needed
        if (result.success && result.nutritionInfo != null) {
          final nutrition = result.nutritionInfo!;
          print('✅ Barcode scan successful: ${nutrition.foodName}');
          
          // Check if nutrition data is valid and try to fix if needed
          if (nutrition.calories == 0 || (nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0)) {
            print('⚠️ Missing nutrition data, attempting to fix...');
            
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
          if (!result.success) {
            _error = result.error ?? "Barcode not found in any database";
          } else {
            // Clear error on success to avoid showing duplicate errors
            _error = null;
          }
        });
        
        // Auto-save successful barcode scan results
        if (result.success && result.nutritionInfo != null) {
          _autoSaveFood(result, 'barcode_scan');
        }
        
      } catch (e) {
        print('❌ Barcode processing error: $e');
        if (mounted) {
          setState(() {
            _error = "Couldn't fetch product info. Try again.";
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
            _barcodeProcessing = false; // Reset processing flag
          });
        }
      }
    }
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      // _barcode removed
      _scannerResult = null;
      _error = null;
      _loading = false;
      _showBarcodeScanner = false;
      _showPortionSelector = false;
      _selectedPortion = 150.0;
      _barcodeProcessing = false; // Reset processing flag
      _scannerDisabled = false; // Reset scanner disabled flag
    });
    
    // Dispose scanner controller
    _scannerController?.dispose();
    _scannerController = null;
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
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
            'confidence': result.snapToCalorieResult!['overallConfidence'],
            'overall_confidence': result.snapToCalorieResult!['overallConfidence'],
            'recommended_action': result.snapToCalorieResult!['recommendedAction'],
            'notes': result.snapToCalorieResult!['notes'],
            'items_count': (result.snapToCalorieResult!['items'] as List?)?.length ?? 0,
            'ai_suggestions': result.snapToCalorieResult!['aiSuggestions'],
          };
        }
        
        // Create food history entry
        final entry = FoodHistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          foodName: result.nutritionInfo!.foodName,
          calories: result.nutritionInfo!.calories,
          protein: result.nutritionInfo!.protein,
          carbs: result.nutritionInfo!.carbs,
          fat: result.nutritionInfo!.fat,
          fiber: result.nutritionInfo!.fiber,
          sugar: result.nutritionInfo!.sugar,
          weightGrams: result.nutritionInfo!.weightGrams,
          category: result.nutritionInfo!.category,
          brand: result.nutritionInfo!.brand,
          notes: result.nutritionInfo!.notes,
          source: source,
          timestamp: DateTime.now(),
          imagePath: _imageFile?.path,
          scanData: scanData,
        );
        
        // Save directly to FoodHistoryService to ensure today's food screen updates
        final success = await FoodHistoryService.addFoodEntry(entry);
        
        if (success) {
          print('✅ Food entry saved to history: ${result.nutritionInfo!.foodName}');
          // Don't clear the scanner result - keep showing the food details
          setState(() {
            _loading = false;
            _showPortionSelector = false;
          });
        } else {
          print('❌ Failed to save food entry to history');
          setState(() {
            _loading = false;
            _error = 'Failed to save food entry';
          });
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

  /// Show manual food entry dialog when AI fails
  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => ManualFoodEntryDialog(
        onFoodSelected: (nutritionInfo) {
          // Create a successful scanner result with manual entry
          final manualResult = FoodScannerResult(
            success: true,
            recognitionResult: FoodRecognitionResult(
              foodName: nutritionInfo.foodName,
              category: nutritionInfo.category ?? 'Unknown',
              cuisine: 'Unknown',
              confidence: 1.0,
            ),
            portionResult: PortionEstimationResult(
              estimatedWeight: nutritionInfo.weightGrams,
              confidence: 1.0,
              method: 'Manual entry',
            ),
            nutritionInfo: nutritionInfo,
            aiAnalysis: null,
            processingTime: DateTime.now().millisecondsSinceEpoch,
            isBarcodeScan: false,
          );
          
          setState(() {
            _scannerResult = manualResult;
          });
          
          // Auto-save manual food entry
          _autoSaveFood(manualResult, 'manual_entry');
        },
      ),
    );
  }

  /// Automatically save food to history (silent operation)
  Future<void> _autoSaveFood(FoodScannerResult result, String source) async {
    if (!result.success || result.nutritionInfo == null) {
      return;
    }

    try {
      // Save to food history silently
      await _saveToFoodHistory(result, source);
      print('✅ Auto-saved food: ${result.nutritionInfo!.foodName}');
    } catch (e) {
      print('❌ Error auto-saving food: $e');
    }
  }

  /// Add scanned food to history (manual operation - kept for compatibility)
  Future<void> _addFoodToHistory() async {
    if (_scannerResult == null || !_scannerResult!.success || _scannerResult!.nutritionInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No food data to add'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Determine source based on scan type
      String source = 'manual_entry';
      if (_scannerResult!.isBarcodeScan == true) {
        source = 'barcode_scan';
      } else if (_imageFile != null) {
        source = 'camera_scan';
      }

      // Save to food history
      await _saveToFoodHistory(_scannerResult!, source);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_scannerResult!.nutritionInfo!.foodName} added to food history!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error adding food: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
    if (_scannerController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onBarcodeDetected,
          errorBuilder: (context, error, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Error: ${error.toString()}',
                    style: GoogleFonts.poppins(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reset,
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
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
          // Show error only if there's an error AND no scanner result (to avoid duplication)
          // If scanner result exists, let _buildResultState handle the error display
          if (_error != null && _scannerResult == null) _buildErrorState(),
          // Show result state only if we have a result (it will handle its own errors)
          if (_scannerResult != null) _buildResultState(),
          if (_showPortionSelector) _buildPortionSelector(),
          if (_imageFile != null && _scannerResult == null) _buildImagePreview(),
          if (_scannerResult == null && !_loading && _error == null) _buildActionButtons(),
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
    // Check if error is due to AI credits exhaustion
    final isAICreditsExhausted = _error?.contains('service limits') == true || 
                                _error?.contains('AI_CREDITS_EXCEEDED') == true ||
                                _error?.contains('temporarily unavailable') == true;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          FoodResultCard(
            title: 'Error',
            comment: _error,
            onRetry: _reset,
          ),
          
          if (isAICreditsExhausted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kInfoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kInfoColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    color: kInfoColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Service Temporarily Unavailable',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can still add food manually while we restore AI services.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: Text(
                      'Add Food Manually',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultState() {
    // Only show error from result if result exists and failed
    // Don't show error if result is null (that's handled by _buildErrorState)
    if (_scannerResult != null && !_scannerResult!.success) {
      // Check if error is due to AI credits exhaustion
      final errorMessage = _scannerResult!.error ?? 'Unknown error';
      final isAICreditsExhausted = errorMessage.contains('service limits') || 
                                  errorMessage.contains('AI_CREDITS_EXCEEDED') ||
                                  errorMessage.contains('temporarily unavailable');
      
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            FoodResultCard(
              title: 'Error',
              comment: errorMessage,
              onRetry: _reset,
            ),
            
            if (isAICreditsExhausted) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.restaurant_menu,
                      color: Colors.blue,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI Service Temporarily Unavailable',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can still add food manually while we restore AI services.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      label: Text(
                        'Add Food Manually',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final nutrition = _scannerResult!.nutritionInfo!;
    // final recognition = _scannerResult!.recognitionResult;
    // final portion = _scannerResult!.portionResult;
    final aiAnalysis = _scannerResult!.aiAnalysis;

    // Check if nutrition data is valid for UI rendering
    if (!nutrition.isValid) {
      print('❌ Nutrition data is invalid');
    }
    
    if (nutrition.calories <= 0) {
      print('❌ No calories found');
    }
    
    if (nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0) {
      print('❌ No macro nutrients found');
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nutrition.formattedWeight,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (nutrition.brand != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'by ${nutrition.brand}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
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
                color: kWarningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kWarningColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: kWarningColor,
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
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: Text('Try Again', style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: Text('Scan Again', style: GoogleFonts.poppins(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  decoration: const BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.only(
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nutrition.formattedWeight,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (nutrition.brand != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'by ${nutrition.brand}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
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
                            const Icon(
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
                      
                      // Food Description
                      if (_scannerResult!.snapToCalorieResult != null) ...[
                        const SizedBox(height: 20),
                        _buildFoodDescription(_scannerResult!.snapToCalorieResult!, nutrition),
                      ],
                      
                      // AI Analysis
                      if (aiAnalysis != null && aiAnalysis['insights'] != null) ...[
                        const SizedBox(height: 20),
                        _buildAIAnalysis(aiAnalysis),
                      ],
                      
                      
                    ],
                  ),
                ),
              ],
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
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCard(String label, double value, Color color) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth < 360 ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: screenWidth < 360 ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: screenWidth < 360 ? 3 : 4),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: GoogleFonts.poppins(
              fontSize: screenWidth < 360 ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFoodDescription(Map<String, dynamic> snapResult, NutritionInfo nutrition) {
    final ingredients = snapResult['ingredients'] as List?;
    final volumeEstimate = snapResult['volumeEstimate'] as String?;
    final category = snapResult['category'] as String?;
    final cuisine = snapResult['cuisine'] as String?;
    
    // Build description text
    final descriptionParts = <String>[];
    
    if (ingredients != null && ingredients.isNotEmpty) {
      final ingredientsList = ingredients.map((e) => e.toString()).toList();
      if (ingredientsList.length <= 5) {
        descriptionParts.add('Ingredients: ${ingredientsList.join(", ")}');
      } else {
        descriptionParts.add('Ingredients: ${ingredientsList.take(5).join(", ")} and more');
      }
    }
    
    if (volumeEstimate != null && volumeEstimate.isNotEmpty) {
      descriptionParts.add('Portion: $volumeEstimate');
    }
    
    if (category != null && category.isNotEmpty && category != 'Unknown') {
      descriptionParts.add('Category: $category');
    }
    
    if (cuisine != null && cuisine.isNotEmpty && cuisine != 'Unknown') {
      descriptionParts.add('Cuisine: $cuisine');
    }
    
    // If no description parts, return empty container
    if (descriptionParts.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 12 : 16),
      decoration: BoxDecoration(
        color: kAccentBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccentBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: kAccentBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'About This Food',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...descriptionParts.map((part) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: kAccentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    part,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: kTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
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
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
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
