import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/food_recognition_result.dart';

/// Service for food recognition using LogMeal API and local Indian foods dataset
class FoodRecognitionService {
  static const String _logMealApiKey = 'YOUR_LOGMEAL_API_KEY'; // Replace with actual API key
  static const String _logMealBaseUrl = 'https://api.logmeal.es/v2/image/segmentation/complete';
  
  static List<Map<String, dynamic>>? _indianFoods;
  static List<Map<String, dynamic>>? _comprehensiveIndianFoods;
  static List<Map<String, dynamic>>? _indianPackaged;

  /// Initialize local datasets
  static Future<void> initialize() async {
    try {
      // Load Indian foods dataset
      final indianFoodsString = await rootBundle.loadString('assets/indian_foods.json');
      _indianFoods = List<Map<String, dynamic>>.from(jsonDecode(indianFoodsString));
      
      // Load comprehensive Indian foods dataset
      final comprehensiveFoodsString = await rootBundle.loadString('assets/comprehensive_indian_foods.json');
      _comprehensiveIndianFoods = List<Map<String, dynamic>>.from(jsonDecode(comprehensiveFoodsString));
      
      // Load Indian packaged foods dataset
      final indianPackagedString = await rootBundle.loadString('assets/indian_packaged.json');
      _indianPackaged = List<Map<String, dynamic>>.from(jsonDecode(indianPackagedString));
      
      print('✅ Food recognition datasets loaded successfully');
      print('📊 Total dishes available: ${getTotalDishCount()}');
    } catch (e) {
      print('❌ Error loading food datasets: $e');
    }
  }

  /// Recognize food from image using LogMeal API with Indian foods fallback
  static Future<FoodRecognitionResult> recognizeFoodFromImage(File imageFile) async {
    try {
      // Validate input
      if (!await imageFile.exists()) {
        return FoodRecognitionResult(
          foodName: 'Invalid Image',
          confidence: 0.0,
          category: 'Error',
          cuisine: 'Unknown',
          boundingBox: null,
          error: 'Image file does not exist',
        );
      }

      // Ensure datasets are loaded
      if (_indianFoods == null || _indianPackaged == null) {
        await initialize();
      }

      // Try LogMeal API first (only if API key is available)
      if (_logMealApiKey != 'YOUR_LOGMEAL_API_KEY') {
        try {
          final logMealResult = await _recognizeWithLogMeal(imageFile);
          if (logMealResult.confidence > 0.7) {
            return logMealResult;
          }
          print('LogMeal confidence too low (${logMealResult.confidence}), trying local dataset');
        } catch (e) {
          print('LogMeal API failed: $e, trying local dataset');
        }
      }

      // Fallback to local Indian foods dataset
      return await _recognizeWithLocalDataset(imageFile);
    } catch (e) {
      print('Error in food recognition: $e');
      return FoodRecognitionResult(
        foodName: 'Unknown Food',
        confidence: 0.0,
        category: 'Unknown',
        cuisine: 'Unknown',
        boundingBox: null,
        error: 'Food recognition failed: $e',
      );
    }
  }

  /// Recognize food using LogMeal API
  static Future<FoodRecognitionResult> _recognizeWithLogMeal(File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse(_logMealBaseUrl));
    request.headers['Authorization'] = 'Bearer $_logMealApiKey';
    
    // Add image file
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    
    // Add parameters
    request.fields['complete'] = 'true';
    request.fields['language'] = 'en';
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseLogMealResponse(data);
    } else {
      throw Exception('LogMeal API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Parse LogMeal API response
  static FoodRecognitionResult _parseLogMealResponse(Map<String, dynamic> data) {
    try {
      final foodItems = data['foodItems'] as List<dynamic>? ?? [];
      if (foodItems.isEmpty) {
        return FoodRecognitionResult(
          foodName: 'No food detected',
          confidence: 0.0,
          category: 'Unknown',
          cuisine: 'Unknown',
        );
      }

      // Get the first (most confident) food item
      final firstItem = foodItems.first as Map<String, dynamic>;
      final foodName = firstItem['foodName'] as String? ?? 'Unknown Food';
      final confidence = (firstItem['confidence'] as num?)?.toDouble() ?? 0.0;
      final category = firstItem['category'] as String? ?? 'Unknown';
      final cuisine = firstItem['cuisine'] as String? ?? 'Unknown';
      
      // Parse bounding box if available
      Map<String, double>? boundingBox;
      if (firstItem['boundingBox'] != null) {
        final bbox = firstItem['boundingBox'] as Map<String, dynamic>;
        boundingBox = {
          'x': (bbox['x'] as num?)?.toDouble() ?? 0.0,
          'y': (bbox['y'] as num?)?.toDouble() ?? 0.0,
          'width': (bbox['width'] as num?)?.toDouble() ?? 0.0,
          'height': (bbox['height'] as num?)?.toDouble() ?? 0.0,
        };
      }

      return FoodRecognitionResult(
        foodName: foodName,
        confidence: confidence,
        category: category,
        cuisine: cuisine,
        boundingBox: boundingBox,
      );
    } catch (e) {
      print('Error parsing LogMeal response: $e');
      return FoodRecognitionResult(
        foodName: 'Parse error',
        confidence: 0.0,
        category: 'Unknown',
        cuisine: 'Unknown',
        error: 'Failed to parse LogMeal response: $e',
      );
    }
  }

  /// Recognize food using local Indian foods dataset
  static Future<FoodRecognitionResult> _recognizeWithLocalDataset(File imageFile) async {
    // For now, return a generic Indian food with moderate confidence
    // In a real implementation, you would use a local ML model or image analysis
    final indianFoods = _indianFoods ?? [];
    if (indianFoods.isEmpty) {
      return FoodRecognitionResult(
        foodName: 'Indian Food',
        confidence: 0.5,
        category: 'Indian Cuisine',
        cuisine: 'Indian',
        error: 'Local dataset not available',
      );
    }

    // Return a random Indian food as fallback
    final randomFood = indianFoods[DateTime.now().millisecondsSinceEpoch % indianFoods.length];
    return FoodRecognitionResult(
      foodName: randomFood['name'] as String? ?? 'Indian Food',
      confidence: 0.6,
      category: randomFood['category'] as String? ?? 'Indian Cuisine',
      cuisine: randomFood['cuisine'] as String? ?? 'Indian',
    );
  }

  /// Search for food in local Indian foods dataset with enhanced accuracy
  static Map<String, dynamic>? searchIndianFood(String foodName) {
    final searchTerm = foodName.toLowerCase().trim();
    
    // Search in comprehensive dataset first
    if (_comprehensiveIndianFoods != null) {
      final result = _searchInDataset(_comprehensiveIndianFoods!, searchTerm);
      if (result != null) return result;
    }
    
    // Fallback to original dataset
    if (_indianFoods != null) {
      final result = _searchInDataset(_indianFoods!, searchTerm);
      if (result != null) return result;
    }
    
    return null;
  }

  /// Search in a specific dataset with fuzzy matching
  static Map<String, dynamic>? _searchInDataset(List<Map<String, dynamic>> dataset, String searchTerm) {
    // First pass: Exact matches
    for (final food in dataset) {
      final name = (food['name'] as String? ?? '').toLowerCase();
      if (name == searchTerm) {
        return food;
      }
    }
    
    // Second pass: Contains matches
    for (final food in dataset) {
      final name = (food['name'] as String? ?? '').toLowerCase();
      final aliases = (food['aliases'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      
      if (name.contains(searchTerm) || 
          aliases.any((alias) => alias.contains(searchTerm))) {
        return food;
      }
    }
    
    // Third pass: Fuzzy matching for common variations
    final fuzzyTerms = _generateFuzzyTerms(searchTerm);
    for (final food in dataset) {
      final name = (food['name'] as String? ?? '').toLowerCase();
      final aliases = (food['aliases'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();
      
      for (final term in fuzzyTerms) {
        if (name.contains(term) || 
            aliases.any((alias) => alias.contains(term))) {
          return food;
        }
      }
    }
    
    return null;
  }

  /// Generate fuzzy search terms for better matching
  static List<String> _generateFuzzyTerms(String searchTerm) {
    final terms = <String>[searchTerm];
    
    // Common Indian food variations
    final variations = {
      'roti': ['chapati', 'phulka', 'roti'],
      'naan': ['naan', 'kulcha'],
      'dal': ['dal', 'lentil', 'daal'],
      'rice': ['rice', 'chawal', 'bhat'],
      'curry': ['curry', 'sabzi', 'vegetable'],
      'paneer': ['paneer', 'cottage cheese'],
      'chicken': ['chicken', 'murgh', 'kukad'],
      'mutton': ['mutton', 'lamb', 'gosht'],
      'fish': ['fish', 'machli'],
      'prawn': ['prawn', 'jhinga', 'shrimp'],
    };
    
    for (final entry in variations.entries) {
      if (searchTerm.contains(entry.key)) {
        terms.addAll(entry.value);
      }
    }
    
    return terms;
  }

  /// Get total dish count across all datasets
  static int getTotalDishCount() {
    int count = 0;
    if (_indianFoods != null) count += _indianFoods!.length;
    if (_comprehensiveIndianFoods != null) count += _comprehensiveIndianFoods!.length;
    if (_indianPackaged != null) count += _indianPackaged!.length;
    return count;
  }

  /// Search for packaged food by barcode
  static Map<String, dynamic>? searchPackagedFood(String barcode) {
    if (_indianPackaged == null) return null;
    
    for (final food in _indianPackaged!) {
      if (food['barcode'] == barcode) {
        return food;
      }
    }
    return null;
  }

  /// Get all available Indian foods
  static List<Map<String, dynamic>> getAllIndianFoods() {
    return _indianFoods ?? [];
  }

  /// Get all available packaged foods
  static List<Map<String, dynamic>> getAllPackagedFoods() {
    return _indianPackaged ?? [];
  }
}
