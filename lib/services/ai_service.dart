import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class FoodAIService {
  // TODO: Replace with your actual Google Cloud Vision API key
  static const String _visionApiKey = 'YOUR_API_KEY_HERE';

  static Future<Map<String, dynamic>> detectFoodLabels(File imageFile) async {
    try {
      // Read image as base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      // Prepare Vision API request
      final url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_visionApiKey');
      final body = jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 5}
            ]
          }
        ]
      });
      final response = await http.post(url, body: body, headers: {'Content-Type': 'application/json'});
      if (response.statusCode != 200) {
        throw Exception('Vision API error');
      }
      final data = jsonDecode(response.body);
      final labels = data['responses'][0]['labelAnnotations'] as List<dynamic>?;
      if (labels == null || labels.isEmpty) {
        return {
          'title': 'No food detected',
          'comment': "Couldn't detect food. Try again or add manually.",
        };
      }
      final topLabel = (labels[0]['description'] as String).toLowerCase();
      final calorieMap = await loadCalorieMapping();
      final calories = calorieMap[topLabel];
      String comment = '';
      if (calories != null) {
        comment = "Hey! That $topLabel has $calories kcal. Try balancing it with a walk later today 💪";
      } else {
        comment = "Couldn't estimate calories for $topLabel. Try again or add manually.";
      }
      return {
        'title': topLabel[0].toUpperCase() + topLabel.substring(1),
        'calories': calories,
        'comment': comment,
        'imageUrl': imageFile.path,
      };
    } catch (e) {
      return {
        'title': 'Detection failed',
        'comment': "Couldn't estimate calories. Try again or add manually.",
      };
    }
  }

  static Future<Map<String, dynamic>> fetchBarcodeNutrition(String barcode) async {
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('OpenFoodFacts API error');
      }
      final data = jsonDecode(response.body);
      if (data['status'] != 1) {
        return {
          'title': 'Product not found',
          'comment': "Couldn't find product. Try again or add manually.",
        };
      }
      final product = data['product'];
      final productName = product['product_name'] ?? 'Unknown Product';
      final nutriments = product['nutriments'] ?? {};
      final calories = nutriments['energy-kcal_100g']?.toInt();
      final macros = {
        'protein': nutriments['proteins_100g']?.toDouble(),
        'carbs': nutriments['carbohydrates_100g']?.toDouble(),
        'fat': nutriments['fat_100g']?.toDouble(),
      };
      String comment = '';
      if (calories != null) {
        comment = "Hey! $productName has $calories kcal per 100g. Check the macros for a balanced diet!";
      } else {
        comment = "Couldn't estimate calories for $productName. Try again or add manually.";
      }
      return {
        'title': productName,
        'calories': calories,
        'macros': macros,
        'comment': comment,
        'imageUrl': product['image_front_url'],
      };
    } catch (e) {
      return {
        'title': 'Lookup failed',
        'comment': "Couldn't fetch product info. Try again or add manually.",
      };
    }
  }

  static Future<Map<String, int>> loadCalorieMapping() async {
    final data = await rootBundle.loadString('assets/calorie_data.json');
    return Map<String, int>.from(json.decode(data));
  }
} 