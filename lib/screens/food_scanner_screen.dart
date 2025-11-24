import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart';
import '../services/gemini_food_service.dart';
import '../services/food_database_service.dart';
import '../models/food_scan_result.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';
import 'food_confirmation_screen.dart';

/// Screen for scanning food with camera and AI recognition
class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isProcessing = false;
  String _processingStatus = '';

  final _geminiFoodService = GeminiFoodService();
  final _foodDatabaseService = FoodDatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isInitializing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera found')),
          );
        }
        return;
      }

      _cameraController = CameraController(
        _cameras![0], // Use back camera
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Camera initialization error: $e');
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Capturing image...';
    });

    try {
      // Capture image
      final XFile image = await _cameraController!.takePicture();
      
      setState(() {
        _processingStatus = 'Analyzing food...';
      });

      // Get quick estimate first (for instant feedback)
      final quickEstimate = await _geminiFoodService.quickEstimate(File(image.path));
      
      setState(() {
        _processingStatus = 'Identifying ${quickEstimate['dish'] ?? 'food'}...';
      });

      // Get full analysis
      final result = await _geminiFoodService.recognizeFood(File(image.path));

      setState(() {
        _isProcessing = false;
      });

      // Navigate to confirmation screen
      if (mounted) {
        final confirmed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => FoodConfirmationScreen(
              result: result,
              imagePath: image.path,
            ),
          ),
        );

        if (confirmed == true) {
          // Food was added to diary
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Food analysis error: $e');
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing food: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              children: [
                // Camera preview
                if (_cameraController != null &&
                    _cameraController!.value.isInitialized)
                  SizedBox.expand(
                    child: CameraPreview(_cameraController!),
                  ),

                // Processing overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _processingStatus,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This may take a few seconds...',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          const Spacer(),
                          Text(
                            'Scan Food',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 48), // Balance for close button
                        ],
                      ),
                    ),
                  ),
                ),

                // Guide overlay
                if (!_isProcessing)
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                // Instructions
                if (!_isProcessing)
                  Positioned(
                    top: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Position food in the frame',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Capture button
                if (!_isProcessing)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _captureAndAnalyze,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Tips
                if (!_isProcessing)
                  Positioned(
                    bottom: 140,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '💡 Tips for best results:',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTip('Good lighting'),
                          _buildTip('Show full plate/dish'),
                          _buildTip('Avoid shadows'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

