import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/optimized_food_scanner_pipeline.dart';
import '../config/ai_config.dart';
import '../services/network_service.dart';
import '../services/barcode_scanning_service.dart';
// Unused imports removed
import '../models/food_history_entry.dart';
import '../models/nutrition_info.dart';
import '../models/portion_estimation_result.dart';
import '../models/food_recognition_result.dart';
import '../models/user_goals.dart';
import '../widgets/food_result_card.dart';
import '../widgets/manual_food_entry_dialog.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';
import '../services/food_history_service.dart';
// Unused import removed
import '../config/production_config.dart';

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
  UserGoals? _userGoals;
  bool _isLoadingGoals = false;
  double _todaysCalories = 0.0;

  final ImagePicker _picker = ImagePicker();
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _loadUserGoals();
  }

  Future<void> _loadUserGoals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() => _isLoadingGoals = true);
        final goalsDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('goals')
            .doc('current')
            .get();
        
        // Load today's calories
        _todaysCalories = await FoodHistoryService.getTodaysTotalCalories();
        
        if (mounted) {
          setState(() {
            if (goalsDoc.exists) {
              _userGoals = UserGoals.fromMap(goalsDoc.data()!);
            } else {
              _userGoals = const UserGoals(calorieGoal: 2000);
            }
            _isLoadingGoals = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _userGoals = const UserGoals(calorieGoal: 2000);
          _isLoadingGoals = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userGoals = const UserGoals(calorieGoal: 2000);
          _isLoadingGoals = false;
        });
      }
    }
  }

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
    if (kDebugMode) debugPrint('📸 Image picker initiated');
    setState(() {
      _loading = true;
      _error = null;
      _scannerResult = null;
      _showPortionSelector = false;
    });

    try {
      // Preflight: ensure AI vision is enabled, API key present, and network online
      if (kDebugMode) {
        if (kDebugMode) debugPrint('🔍 Preflight checks for image analysis...');
        if (kDebugMode) debugPrint('   - Image analysis enabled: ${AIConfig.enableImageAnalysis}');
        // SECURITY: Never log API key details in production
        if (kDebugMode) debugPrint('   - API key configured: ${AIConfig.apiKey.isNotEmpty}');
        if (kDebugMode) debugPrint('   - Network online: ${NetworkService().isOnline}');
        if (kDebugMode) debugPrint('   - Vision model: ${AIConfig.visionModel}');
      }
      
      if (!AIConfig.enableImageAnalysis) {
        if (kDebugMode) debugPrint('❌ Image analysis is disabled in configuration');
        setState(() {
          _loading = false;
          _error = 'Image analysis is disabled in configuration. You can add food manually.';
        });
        return;
      }

      if (AIConfig.apiKey.isEmpty) {
        if (kDebugMode) debugPrint('❌ API key is empty - config may not have loaded from Firebase');
        if (kDebugMode) debugPrint('   - Check Firebase console for app_config/ai_settings document');
        setState(() {
          _loading = false;
          _error = 'AI service is not configured (missing API key). Please sign in and try again later or add food manually.';
        });
        return;
      }

      if (!NetworkService().isOnline) {
        if (kDebugMode) debugPrint('❌ Network is offline');
        setState(() {
          _loading = false;
          _error = 'No internet connection. Please connect to the internet or add food manually.';
        });
        return;
      }
      
      if (kDebugMode) debugPrint('✅ All preflight checks passed, proceeding with image capture...');

      final picked = await _picker.pickImage(source: ImageSource.camera).catchError((error) {
        if (kDebugMode) debugPrint('❌ Image picker error: $error');
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
        if (kDebugMode) debugPrint('✅ Image captured: ${picked.path}');
        setState(() {
          _imageFile = File(picked.path);
        });
        
        // Process image through the optimized food scanner pipeline
        if (kDebugMode) debugPrint('🚀 Starting image processing pipeline...');
        var result = await OptimizedFoodScannerPipeline.processFoodImage(_imageFile!);
        if (kDebugMode) debugPrint('📊 Image processing result: success=${result.success}, error=${result.error}');

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
            if (kDebugMode) debugPrint('❌ Image analysis failed: ${result.error}');
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
      if (kDebugMode) debugPrint('❌ Error in image picker: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');
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
    if (kDebugMode) debugPrint('📱 Barcode scanner initiated');
    
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
      if (kDebugMode) debugPrint('✅ Barcode scanner started and ready - waiting for barcode detection...');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error starting scanner: $e');
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
      if (kDebugMode) debugPrint('📱 Barcode detected: $barcode');
      
      // Set processing flag to prevent multiple detections
      _barcodeProcessing = true;
      _scannerDisabled = true; // Completely disable scanner
      
      // Stop and dispose the scanner immediately to prevent automatic switching
      try {
        await _scannerController?.stop();
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error stopping scanner: $e');
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
        if (kDebugMode) debugPrint('🔍 Starting barcode processing pipeline for: $barcode');
        final result = await OptimizedFoodScannerPipeline.processBarcodeScan(barcode);
        if (kDebugMode) debugPrint('📊 Barcode processing result: success=${result.success}, error=${result.error}');
        
        // Check result and fix missing nutrition data if needed
        if (result.success && result.nutritionInfo != null) {
          final nutrition = result.nutritionInfo!;
          if (kDebugMode) debugPrint('✅ Barcode scan successful: ${nutrition.foodName}');
          
          // Check if nutrition data is valid and try to fix if needed
          if (nutrition.calories == 0 || (nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0)) {
            if (kDebugMode) debugPrint('⚠️ Missing nutrition data, attempting to fix...');
            
            // Try to get nutrition data from product name
            try {
              final fixedNutrition = await _tryFixMissingNutrition(nutrition);
              if (fixedNutrition != null) {
                if (kDebugMode) debugPrint('✅ Fixed nutrition data: ${fixedNutrition.calories} calories');
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
              if (kDebugMode) debugPrint('❌ Failed to fix nutrition data: $e');
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
        if (kDebugMode) debugPrint('❌ Barcode processing error: $e');
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
      if (kDebugMode) debugPrint('🔍 Attempting to fix nutrition data for: ${originalNutrition.foodName}');
      
      // Use the barcode scanning service to get nutrition from product name
      final fixedNutrition = await BarcodeScanningService.getNutritionFromProductName(originalNutrition.foodName);
      
      if (fixedNutrition != null && fixedNutrition.calories > 0) {
        if (kDebugMode) debugPrint('✅ Found nutrition data for product name: ${fixedNutrition.calories} calories');
        
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
      if (kDebugMode) debugPrint('❌ Error fixing nutrition data: $e');
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
          if (kDebugMode) debugPrint('✅ Food entry saved to history: ${result.nutritionInfo!.foodName}');
          // Don't clear the scanner result - keep showing the food details
          setState(() {
            _loading = false;
            _showPortionSelector = false;
          });
        } else {
          if (kDebugMode) debugPrint('❌ Failed to save food entry to history');
          setState(() {
            _loading = false;
            _error = 'Failed to save food entry';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving food entry to history: $e');
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
      if (kDebugMode) debugPrint('✅ Auto-saved food: ${result.nutritionInfo!.foodName}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error auto-saving food: $e');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? kDarkAppBackground : kAppBackground,
      appBar: _buildPremiumAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [kDarkAppBackground, kDarkSurfaceLight]
                : [kAppBackground, kSurfaceLight],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDark ? kDarkSurfaceLight : Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(
        color: isDark ? kDarkTextPrimary : kTextDark,
      ),
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
              color: isDark ? kDarkTextPrimary : kTextDark,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceLight : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark ? kDarkCardShadow : kCardShadow,
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
                    color: isDark ? kDarkTextPrimary : kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? kDarkTextSecondary : kTextSecondary,
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
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'AI Service Temporarily Unavailable',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? kDarkTextPrimary : kTextDark,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        'You can still add food manually while we restore AI services.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
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
      if (kDebugMode) debugPrint('❌ Nutrition data is invalid');
    }
    
    if (nutrition.calories <= 0) {
      if (kDebugMode) debugPrint('❌ No calories found');
    }
    
    if (nutrition.protein == 0 && nutrition.carbs == 0 && nutrition.fat == 0) {
      if (kDebugMode) debugPrint('❌ No macro nutrients found');
    }

    // If nutrition data is invalid or missing, show a special message
    if (!nutrition.isValid || nutrition.calories <= 0) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // Product info card
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kAccentBlue, kAccentBlue.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark ? kDarkCardShadow : kCardShadow,
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
                );
              },
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

    // Calculate health metrics
    final healthGrade = _calculateHealthGrade(nutrition);
    final mealTime = _getMealTime();
    final dailyGoalContribution = _getDailyGoalContribution(nutrition);
    final calorieDensity = _getCalorieDensity(nutrition);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 360 ? 4 : 6,
        vertical: 8,
      ),
      child: Column(
        children: [
          // Compact Enhanced Header Card
          _buildCompactHeaderCard(nutrition, healthGrade, mealTime, dailyGoalContribution, calorieDensity),
          
          const SizedBox(height: 10),
          
          // Health Grade Card
          _buildHealthGradeCard(healthGrade),
          
          const SizedBox(height: 10),
          
          // Enhanced Nutrition Card with Macros
          _buildCompactNutritionCard(nutrition),
          
          const SizedBox(height: 10),
          
          // Personalized Health Recommendations
          _buildPersonalizedRecommendationsCard(nutrition, healthGrade),
          
          const SizedBox(height: 10),
          
          // Food Description
          if (_scannerResult!.snapToCalorieResult != null) ...[
            _buildFoodDescription(_scannerResult!.snapToCalorieResult!, nutrition),
            const SizedBox(height: 10),
          ],
          
          // AI Analysis
          if (aiAnalysis != null && aiAnalysis['insights'] != null) ...[
            _buildAIAnalysis(aiAnalysis),
            const SizedBox(height: 10),
          ],
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
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      'Scan Your Food',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? kDarkTextPrimary : kTextDark,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Text(
                      'Take a photo or scan a barcode to get\nnutritional information instantly',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        color: isDark 
            ? kAccentBlue.withOpacity(0.15)
            : kAccentBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? kAccentBlue.withOpacity(0.4)
              : kAccentBlue.withOpacity(0.2),
        ),
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
                    color: isDark ? kDarkTextPrimary : kTextDark,
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
                  child: Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Text(
                        part,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                          height: 1.4,
                        ),
                      );
                    },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insights = aiAnalysis['insights'] as List<dynamic>? ?? [];
    final recommendations = aiAnalysis['recommendations'] as List<dynamic>? ?? [];
    final tips = aiAnalysis['tips'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceDark : kSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? kDarkBorderColor : kBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'AI Analysis',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? kDarkTextPrimary : kTextDark,
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
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? kDarkTextPrimary : kTextDark,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 4),
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Text(
                '• ${item.toString()}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              );
            },
          ),
        )),
      ],
    );
  }

  Widget _buildPortionSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceLight : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        children: [
          Text(
            'Adjust Portion Size',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? kDarkTextPrimary : kTextDark,
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
                      color: isDark ? kDarkTextPrimary : kTextDark,
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

  // Health grade calculation
  Map<String, dynamic> _calculateHealthGrade(NutritionInfo nutrition) {
    double score = 100.0;
    
    final weight = nutrition.weightGrams > 0 ? nutrition.weightGrams : 100.0;
    final caloriesPer100g = (nutrition.calories / weight * 100);
    final proteinPer100g = (nutrition.protein / weight * 100);
    final carbsPer100g = (nutrition.carbs / weight * 100);
    final fatPer100g = (nutrition.fat / weight * 100);
    final fiberPer100g = (nutrition.fiber / weight * 100);
    final sugarPer100g = (nutrition.sugar / weight * 100);
    
    // Calorie density penalty
    if (caloriesPer100g > 500) {
      score -= 20;
    } else if (caloriesPer100g > 400) {
      score -= 15;
    } else if (caloriesPer100g > 300) {
      score -= 10;
    } else if (caloriesPer100g < 50) {
      score += 5;
    }
    
    // Sugar penalty
    if (sugarPer100g > 30) {
      score -= 25;
    } else if (sugarPer100g > 20) {
      score -= 15;
    } else if (sugarPer100g > 10) {
      score -= 8;
    }
    
    // Fiber bonus
    if (fiberPer100g > 5) {
      score += 15;
    } else if (fiberPer100g > 3) {
      score += 10;
    } else if (fiberPer100g > 1) {
      score += 5;
    }
    
    // Protein bonus
    if (proteinPer100g > 15) {
      score += 10;
    } else if (proteinPer100g > 10) {
      score += 5;
    }
    
    // Fat penalty
    if (fatPer100g > 30) {
      score -= 15;
    } else if (fatPer100g > 20) {
      score -= 8;
    }
    
    // Sugar to carbs ratio
    if (carbsPer100g > 0) {
      final sugarRatio = (sugarPer100g / carbsPer100g) * 100;
      if (sugarRatio > 50) {
        score -= 10;
      } else if (sugarRatio > 30) {
        score -= 5;
      }
    }
    
    // Determine grade
    String grade;
    String label;
    Color color;
    
    if (score >= 85) {
      grade = 'A';
      label = 'Excellent';
      color = kSuccessColor;
    } else if (score >= 70) {
      grade = 'B';
      label = 'Good';
      color = kInfoColor;
    } else if (score >= 55) {
      grade = 'C';
      label = 'Average';
      color = kWarningColor;
    } else if (score >= 40) {
      grade = 'D';
      label = 'Below Average';
      color = kAccentColor;
    } else {
      grade = 'E';
      label = 'Unhealthy';
      color = kErrorColor;
    }
    
    return {
      'grade': grade,
      'label': label,
      'color': color,
      'score': score,
    };
  }

  // Get meal time
  String _getMealTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Breakfast';
    } else if (hour >= 11 && hour < 15) {
      return 'Lunch';
    } else if (hour >= 15 && hour < 18) {
      return 'Snack';
    } else if (hour >= 18 && hour < 22) {
      return 'Dinner';
    } else {
      return 'Late Night';
    }
  }

  // Get daily goal contribution
  double _getDailyGoalContribution(NutritionInfo nutrition) {
    final calorieGoal = _userGoals?.calorieGoal ?? 2000;
    return (nutrition.calories / calorieGoal * 100);
  }

  // Get calorie density
  double _getCalorieDensity(NutritionInfo nutrition) {
    return nutrition.weightGrams > 0
        ? (nutrition.calories / nutrition.weightGrams * 100)
        : 0.0;
  }

  // Compact Header Card
  Widget _buildCompactHeaderCard(NutritionInfo nutrition, Map<String, dynamic> healthGrade, String mealTime, double dailyGoalContribution, double calorieDensity) {
    final isDark = context.isDarkMode;
    final grade = healthGrade['grade'] as String;
    final gradeLabel = healthGrade['label'] as String;
    final gradeColor = healthGrade['color'] as Color;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor.withValues(alpha: 0.2),
            kPrimaryColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kPrimaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: isDark ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        children: [
          // Top section with food name and health grade
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                // Food Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        gradeColor.withValues(alpha: 0.3),
                        gradeColor.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: gradeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Food Name and Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nutrition.foodName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: gradeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  grade,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: gradeColor,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  gradeLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: gradeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: kInfoColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time_rounded, size: 11, color: kInfoColor),
                                const SizedBox(width: 3),
                                Text(
                                  mealTime,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kInfoColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Confidence Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_rounded, color: Colors.white, size: 14),
                      const SizedBox(height: 2),
                      Text(
                        '${_scannerResult!.confidencePercentage.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom section with compact stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceDark : kSurfaceLight,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildCompactStatItem(
                    Icons.local_fire_department_rounded,
                    '${nutrition.calories.toStringAsFixed(0)}',
                    'kcal',
                    kPrimaryColor,
                  ),
                ),
                Container(width: 1, height: 24, color: isDark ? kDarkDividerColor : kDividerColor),
                Expanded(
                  child: _buildCompactStatItem(
                    Icons.track_changes_rounded,
                    '${dailyGoalContribution.toStringAsFixed(1)}%',
                    'Goal',
                    kAccentColor,
                  ),
                ),
                Container(width: 1, height: 24, color: isDark ? kDarkDividerColor : kDividerColor),
                Expanded(
                  child: _buildCompactStatItem(
                    Icons.scale_rounded,
                    nutrition.formattedWeight,
                    'Size',
                    kInfoColor,
                  ),
                ),
                Container(width: 1, height: 24, color: isDark ? kDarkDividerColor : kDividerColor),
                Expanded(
                  child: _buildCompactStatItem(
                    Icons.speed_rounded,
                    '${calorieDensity.toStringAsFixed(0)}',
                    'kcal/100g',
                    kWarningColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }


  // Compact Nutrition Card
  Widget _buildCompactNutritionCard(NutritionInfo nutrition) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDarkMode ? kDarkSurfaceLight : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode ? kDarkBorderColor : kBorderColor,
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: kPrimaryColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Nutrition',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Compact Macros Grid
          Row(
            children: [
              Expanded(
                child: _buildCompactMacroCard('Protein', nutrition.protein, kInfoColor, Icons.egg_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactMacroCard('Carbs', nutrition.carbs, kAccentColor, Icons.bakery_dining_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCompactMacroCard('Fat', nutrition.fat, kWarningColor, Icons.opacity_rounded),
              ),
            ],
          ),
          // Fiber and Sugar if available
          if (nutrition.fiber > 0 || nutrition.sugar > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (nutrition.fiber > 0)
                  Expanded(
                    child: _buildCompactMacroCard('Fiber', nutrition.fiber, kSuccessColor, Icons.fiber_manual_record_rounded),
                  ),
                if (nutrition.fiber > 0 && nutrition.sugar > 0) const SizedBox(width: 6),
                if (nutrition.sugar > 0)
                  Expanded(
                    child: _buildCompactMacroCard('Sugar', nutrition.sugar, kWarningColor, Icons.auto_awesome_rounded),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactMacroCard(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'g',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }



  // Health Grade Card
  Widget _buildHealthGradeCard(Map<String, dynamic> healthGrade) {
    final grade = healthGrade['grade'] as String;
    final gradeLabel = healthGrade['label'] as String;
    final gradeColor = healthGrade['color'] as Color;
    final score = healthGrade['score'] as double;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradeColor.withValues(alpha: 0.15),
            gradeColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gradeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                grade,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: gradeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Status',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gradeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: gradeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Score: ${score.toStringAsFixed(0)}/100',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Personalized Health Recommendations Card
  Widget _buildPersonalizedRecommendationsCard(NutritionInfo nutrition, Map<String, dynamic> healthGrade) {
    final recommendations = _generatePersonalizedRecommendations(nutrition, healthGrade);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDarkMode
              ? [
                  kPrimaryColor.withValues(alpha: 0.15),
                  kPrimaryColor.withValues(alpha: 0.08),
                ]
              : [
                  kPrimaryColor.withValues(alpha: 0.08),
                  kPrimaryColor.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kPrimaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, color: kPrimaryColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Health Recommendations',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((rec) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRecommendationItem(rec),
          )),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generatePersonalizedRecommendations(NutritionInfo nutrition, Map<String, dynamic> healthGrade) {
    final recommendations = <Map<String, dynamic>>[];
    final calorieGoal = _userGoals?.calorieGoal ?? 2000;
    final totalCaloriesAfter = _todaysCalories + nutrition.calories;
    final calorieDeficit = calorieGoal - totalCaloriesAfter;
    final fitnessGoal = _userGoals?.fitnessGoal ?? 'maintenance';
    final grade = healthGrade['grade'] as String;
    final calorieDensity = _getCalorieDensity(nutrition);

    // Calorie-based recommendations
    if (totalCaloriesAfter > calorieGoal * 1.1) {
      final excess = totalCaloriesAfter - calorieGoal;
      final reduceBy = (excess / nutrition.calories * nutrition.weightGrams).round();
      recommendations.add({
        'type': 'warning',
        'icon': Icons.warning_amber_rounded,
        'color': kWarningColor,
        'title': 'Calorie Excess',
        'message': 'This will exceed your daily goal by ${excess.toStringAsFixed(0)} kcal. Consider reducing portion by ~${reduceBy}g.',
      });
    } else if (totalCaloriesAfter < calorieGoal * 0.8 && fitnessGoal != 'weight_loss') {
      recommendations.add({
        'type': 'info',
        'icon': Icons.add_circle_outline_rounded,
        'color': kInfoColor,
        'title': 'Good Addition',
        'message': 'This fits well within your daily goal. You\'ll have ${calorieDeficit.toStringAsFixed(0)} kcal remaining.',
      });
    }

    // Portion recommendations
    if (calorieDensity > 500) {
      recommendations.add({
        'type': 'tip',
        'icon': Icons.tips_and_updates_rounded,
        'color': kAccentColor,
        'title': 'High Calorie Density',
        'message': 'This food is calorie-dense. Consider smaller portions or pair with low-calorie foods for balance.',
      });
    }

    // Health grade recommendations
    if (grade == 'D' || grade == 'E') {
      recommendations.add({
        'type': 'health',
        'icon': Icons.health_and_safety_rounded,
        'color': kErrorColor,
        'title': 'Health Consideration',
        'message': 'This food has a lower health grade. Enjoy in moderation and balance with nutrient-dense foods.',
      });
    } else if (grade == 'A' || grade == 'B') {
      recommendations.add({
        'type': 'health',
        'icon': Icons.check_circle_outline_rounded,
        'color': kSuccessColor,
        'title': 'Healthy Choice',
        'message': 'Great choice! This food aligns well with your health goals.',
      });
    }

    // Macro-specific recommendations
    if (nutrition.protein < 5 && fitnessGoal == 'muscle_building') {
      recommendations.add({
        'type': 'tip',
        'icon': Icons.fitness_center_rounded,
        'color': kInfoColor,
        'title': 'Protein Boost',
        'message': 'Consider adding a protein source to support muscle building goals.',
      });
    }

    if (nutrition.sugar > 20) {
      recommendations.add({
        'type': 'warning',
        'icon': Icons.warning_amber_rounded,
        'color': kWarningColor,
        'title': 'High Sugar Content',
        'message': 'This item contains ${nutrition.sugar.toStringAsFixed(1)}g sugar. Monitor your daily sugar intake.',
      });
    }

    if (nutrition.fiber > 3) {
      recommendations.add({
        'type': 'tip',
        'icon': Icons.eco_rounded,
        'color': kSuccessColor,
        'title': 'Good Fiber Source',
        'message': 'Excellent fiber content! This supports digestive health and satiety.',
      });
    }

    // Fitness goal specific
    if (fitnessGoal == 'weight_loss' && nutrition.calories > 300) {
      recommendations.add({
        'type': 'tip',
        'icon': Icons.trending_down_rounded,
        'color': kInfoColor,
        'title': 'Weight Loss Tip',
        'message': 'For weight loss, consider reducing portion size or choosing a lower-calorie alternative.',
      });
    }

    return recommendations.take(4).toList(); // Limit to 4 recommendations
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    final icon = recommendation['icon'] as IconData;
    final color = recommendation['color'] as Color;
    final title = recommendation['title'] as String;
    final message = recommendation['message'] as String;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

