import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/food_ai_service.dart';
import '../widgets/food_result_card.dart';

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

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    setState(() { _loading = true; _error = null; });
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        setState(() { _imageFile = File(picked.path); });
        // TODO: Call FoodAIService.detectFoodLabels and update _result
      }
    } catch (e) {
      setState(() { _error = 'Failed to capture image.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _onBarcodeScanned(String barcode) async {
    setState(() { _loading = true; _error = null; _barcode = barcode; });
    try {
      // TODO: Call FoodAIService.fetchBarcodeNutrition and update _result
    } catch (e) {
      setState(() { _error = 'Failed to fetch product info.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')), // TODO: Style with blue theme
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Food'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () async {
                      // TODO: Show barcode scanner and call _onBarcodeScanned
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Barcode'),
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 32),
                FoodResultCard(
                  title: 'Error',
                  comment: _error,
                  onRetry: () {
                    setState(() { _error = null; _result = null; });
                  },
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
                  onRetry: _pickImage,
                  onAskTrainer: () {
                    // TODO: Navigate to Sisir chatbot
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
              // TODO: Add barcode scanner preview if needed
            ],
          ),
        ),
      ),
    );
  }
} 