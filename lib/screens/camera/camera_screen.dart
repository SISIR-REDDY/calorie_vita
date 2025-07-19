import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/food_ai_service.dart';
import '../../widgets/food_result_card.dart';

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

  Future<void> _pickImage() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        setState(() { _imageFile = File(picked.path); });
        final aiResult = await FoodAIService.detectFoodLabels(_imageFile!);
        setState(() { _result = aiResult; });
      }
    } catch (e) {
      setState(() { _error = "Couldn't capture or analyze image. Try again."; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _scanBarcode() async {
    setState(() { _showBarcodeScanner = true; _error = null; _result = null; });
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null) {
      setState(() { _showBarcodeScanner = false; _loading = true; _barcode = barcode; });
      try {
        final barcodeResult = await FoodAIService.fetchBarcodeNutrition(barcode);
        setState(() { _result = barcodeResult; });
      } catch (e) {
        setState(() { _error = "Couldn't fetch product info. Try again."; });
      } finally {
        setState(() { _loading = false; });
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
      appBar: AppBar(
        title: const Text('Food Camera'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _showBarcodeScanner
              ? Stack(
                  children: [
                    MobileScanner(
                      onDetect: _onBarcodeDetected,
                    ),
                    Positioned(
                      top: 40,
                      left: 20,
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.close, color: Colors.blue),
                        onPressed: _reset,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_loading) ...[
                          const SizedBox(height: 32),
                          const CircularProgressIndicator(),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 32),
                          FoodResultCard(
                            title: 'Error',
                            comment: _error,
                            onRetry: _reset,
                          ),
                        ],
                        if (_result != null) ...[
                          const SizedBox(height: 32),
                          FoodResultCard(
                            title: _result!['title'] ?? '',
                            calories: _result!['calories'],
                            macros: _result!['macros'],
                            comment: _result!['comment'],
                            imageUrl: _result!['imageUrl'],
                            onRetry: _reset,
                            onAskTrainer: () {
                              // TODO: Navigate to Sisir chatbot
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Save to History'),
                            onPressed: () {
                              // TODO: Save result to history
                            },
                          ),
                        ],
                        if (_imageFile != null && _result == null) ...[
                          const SizedBox(height: 32),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_imageFile!, height: 180),
                          ),
                        ],
                        if (_result == null && !_loading) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Capture Food'),
                                onPressed: _pickImage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan Barcode'),
                                onPressed: _scanBarcode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
} 