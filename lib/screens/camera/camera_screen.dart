import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    setState(() => _loading = true);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    setState(() => _loading = false);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
      _showAIDialog();
    }
  }

  void _showAIDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Detection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_imageFile!, height: 120),
              ),
            const SizedBox(height: 16),
            const Text('Detected: Salad\nEstimated Calories: 220 kcal'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Camera')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imageFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_imageFile!, height: 180),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera),
                    label: const Text('Capture Food'),
                    onPressed: _pickImage,
                  ),
                ],
              ),
      ),
    );
  }
} 