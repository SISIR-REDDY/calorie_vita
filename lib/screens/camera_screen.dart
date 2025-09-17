import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/ai_service.dart';
import '../services/app_state_service.dart';
import '../models/food_entry.dart';
import '../widgets/food_result_card.dart';
import '../ui/app_colors.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  String? _barcode;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;
  bool _showBarcodeScanner = false;

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
      _result = null;
    });

    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
        final aiResult = await AIService.detectCaloriesFromImage(_imageFile!);
        setState(() {
          _result = aiResult;
        });
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
      _result = null;
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null) {
      setState(() {
        _showBarcodeScanner = false;
        _loading = true;
        _barcode = barcode;
      });
      try {
        // Use the correct barcode method instead of image analysis
        final barcodeResult = await AIService.getNutritionFromBarcode(barcode);
        setState(() {
          _result = barcodeResult;
        });
      } catch (e) {
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
      _result = null;
      _error = null;
      _loading = false;
      _showBarcodeScanner = false;
    });
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
          if (_result != null) _buildResultState(),
          if (_imageFile != null && _result == null) _buildImagePreview(),
          if (_result == null && !_loading) _buildActionButtons(),
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
                              _result!['food'] ?? 'Unknown Food',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _result!['serving_size'] ?? '1 serving',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
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
                              '${((_result!['confidence'] ?? 0.0) * 100).toInt()}%',
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
                              '${_result!['calories'] ?? 0}',
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
                              _parseMacroValue(_result!['protein']),
                              kAccentGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMacroCard(
                              'Carbs',
                              _parseMacroValue(_result!['carbs']),
                              kWarningColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMacroCard(
                              'Fat',
                              _parseMacroValue(_result!['fat']),
                              kErrorColor,
                            ),
                          ),
                        ],
                      ),
                      
                      // Additional nutrition info
                      if (_result!['fiber'] != null || _result!['sugar'] != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (_result!['fiber'] != null)
                              Expanded(
                                child: _buildMacroCard(
                                  'Fiber',
                                  _parseMacroValue(_result!['fiber']),
                                  kAccentPurple,
                                ),
                              ),
                            if (_result!['fiber'] != null && _result!['sugar'] != null)
                              const SizedBox(width: 12),
                            if (_result!['sugar'] != null)
                              Expanded(
                                child: _buildMacroCard(
                                  'Sugar',
                                  _parseMacroValue(_result!['sugar']),
                                  kAccentPurple,
                                ),
                              ),
                          ],
                        ),
                      ],
                      
                      // Analysis details
                      if (_result!['analysis_details'] != null) ...[
                        const SizedBox(height: 20),
                        _buildAnalysisDetails(),
                      ],
                      
                      // Notes
                      if (_result!['notes'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kSurfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _result!['notes'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: kTextSecondary,
                              fontStyle: FontStyle.italic,
                            ),
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
                if (_result != null) {
                  try {
                    // Parse macro values from AI result
                    final protein = _parseMacroValue(_result!['protein']);
                    final carbs = _parseMacroValue(_result!['carbs']);
                    final fat = _parseMacroValue(_result!['fat']);
                    final fiber = _parseMacroValue(_result!['fiber']);
                    final sugar = _parseMacroValue(_result!['sugar']);

                    // Create food entry
                    final foodEntry = FoodEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _result!['food'] ?? 'Unknown Food',
                      calories: (_result!['calories'] as num?)?.round() ?? 0,
                      timestamp: DateTime.now(),
                      imageUrl:
                          null, // TODO: Upload image to Firebase Storage if needed
                      protein: protein,
                      carbs: carbs,
                      fat: fat,
                      fiber: fiber,
                      sugar: sugar,
                    );

                    // Save to app state (which will sync to Firestore)
                    await AppStateService().saveFoodEntry(foodEntry);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Food saved to history! Calories: ${foodEntry.calories}, Protein: ${protein.toStringAsFixed(1)}g, Carbs: ${carbs.toStringAsFixed(1)}g, Fat: ${fat.toStringAsFixed(1)}g',
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

  Widget _buildAnalysisDetails() {
    final analysisDetails = _result!['analysis_details'] as Map<String, dynamic>?;
    if (analysisDetails == null) return const SizedBox.shrink();

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
            'Analysis Details',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          
          // Ingredients
          if (analysisDetails['ingredients_identified'] != null) ...[
            _buildDetailRow(
              'Ingredients',
              (analysisDetails['ingredients_identified'] as List).join(', '),
              Icons.restaurant,
            ),
            const SizedBox(height: 8),
          ],
          
          // Weight and cooking method
          Row(
            children: [
              if (analysisDetails['estimated_weight_grams'] != null)
                Expanded(
                  child: _buildDetailRow(
                    'Weight',
                    '${analysisDetails['estimated_weight_grams']}g',
                    Icons.monitor_weight,
                  ),
                ),
              if (analysisDetails['estimated_weight_grams'] != null && 
                  analysisDetails['cooking_method'] != null)
                const SizedBox(width: 16),
              if (analysisDetails['cooking_method'] != null)
                Expanded(
                  child: _buildDetailRow(
                    'Cooking',
                    analysisDetails['cooking_method'],
                    Icons.local_fire_department,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kTextSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: kTextDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
