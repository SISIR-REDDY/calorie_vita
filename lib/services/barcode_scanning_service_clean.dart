import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/nutrition_info.dart';
import '../config/ai_config.dart';

/// Clean barcode scanning service using only free APIs
class BarcodeScanningService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  
  static List<Map<String, dynamic>>? _indianPackaged;
  static Map<String, NutritionInfo> _cache = {}; // Cache for faster responses
  static Map<String, DateTime> _cacheTimestamps = {}; // Cache timestamps
  static const Duration _cacheExpiry = Duration(hours: 24); // Cache for 24 hours

  /// Initialize local datasets
  static Future<void> initialize() async {
    try {
      // Load Indian packaged foods dataset
      final indianPackagedString = await rootBundle.loadString('assets/indian_packaged.json');
      _indianPackaged = List<Map<String, dynamic>>.from(jsonDecode(indianPackagedString));
      
      // Add popular global products to cache for faster access
      _addPopularProductsToCache();
      
      print('✅ Barcode scanning datasets loaded successfully');
      print('📊 Cache size: ${_cache.length} products');
    } catch (e) {
      print('❌ Error loading barcode scanning datasets: $e');
    }
  }

  /// Add popular global products to cache for faster access
  static void _addPopularProductsToCache() {
    // Popular global products with their barcodes and nutrition info
    final popularProducts = [
      {
        'barcode': '5449000000996',
        'name': 'Coca-Cola Classic',
        'brand': 'Coca-Cola',
        'weight': 330.0,
        'units': 'ml',
        'calories': 139.0,
        'protein': 0.0,
        'carbs': 35.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 35.0,
        'category': 'Beverages',
      },
      {
        'barcode': '5449000000997',
        'name': 'Coca-Cola Zero',
        'brand': 'Coca-Cola',
        'weight': 330.0,
        'units': 'ml',
        'calories': 0.0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'category': 'Beverages',
      },
      {
        'barcode': '5449000000998',
        'name': 'Pepsi Cola',
        'brand': 'Pepsi',
        'weight': 330.0,
        'units': 'ml',
        'calories': 139.0,
        'protein': 0.0,
        'carbs': 35.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 35.0,
        'category': 'Beverages',
      },
    ];

    for (final product in popularProducts) {
      final barcode = product['barcode'] as String;
      final nutrition = NutritionInfo(
        foodName: '${product['brand']} ${product['name']}',
        weightGrams: (product['weight'] as num).toDouble(),
        calories: (product['calories'] as num).toDouble(),
        protein: (product['protein'] as num).toDouble(),
        carbs: (product['carbs'] as num).toDouble(),
        fat: (product['fat'] as num).toDouble(),
        fiber: (product['fiber'] as num).toDouble(),
        sugar: (product['sugar'] as num).toDouble(),
        source: 'Popular Products Cache',
        category: product['category'] as String,
        brand: product['brand'] as String,
        notes: 'Size: ${product['weight']} ${product['units']}',
      );
      
      _cache[barcode] = nutrition;
      _cacheTimestamps[barcode] = DateTime.now();
    }
  }

  /// Scan barcode and get nutrition information
  static Future<NutritionInfo?> scanBarcode(String barcode) async {
    try {
      // Clean and normalize the barcode
      final cleanBarcode = _cleanBarcode(barcode);
      print('🔍 Scanning barcode: $cleanBarcode');
      
      // Check cache first
      if (_cache.containsKey(cleanBarcode)) {
        final cachedResult = _cache[cleanBarcode]!;
        final cacheTime = _cacheTimestamps[cleanBarcode]!;
        
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('💾 Cache hit for barcode: $cleanBarcode');
          return cachedResult;
        } else {
          // Remove expired cache entry
          _cache.remove(cleanBarcode);
          _cacheTimestamps.remove(cleanBarcode);
        }
      }

      // Try Open Food Facts API (free)
      print('🌍 Trying Open Food Facts...');
      final openFoodFactsResult = await _scanWithOpenFoodFacts(cleanBarcode);
      if (openFoodFactsResult != null) {
        print('✅ Found in Open Food Facts: ${openFoodFactsResult.foodName}');
        _cache[cleanBarcode] = openFoodFactsResult;
        _cacheTimestamps[cleanBarcode] = DateTime.now();
        return openFoodFactsResult;
      }

      // Fallback to local Indian dataset
      print('🏠 Trying local Indian dataset...');
      try {
        if (_indianPackaged == null) {
          print('📦 Initializing local dataset...');
          await initialize();
        }
        print('📊 Local dataset size: ${_indianPackaged?.length ?? 0}');
        final localResult = _searchLocalPackagedFood(cleanBarcode);
        if (localResult != null) {
          print('✅ Found in local Indian dataset');
          print('📦 Local product: ${localResult.foodName}');
          print('🔥 Local calories: ${localResult.calories}');
          _cache[cleanBarcode] = localResult;
          _cacheTimestamps[cleanBarcode] = DateTime.now();
          return localResult;
        } else {
          print('❌ Not found in local Indian dataset');
        }
      } catch (e) {
        print('❌ Local dataset failed: $e');
      }

      // Try OpenRouter AI as final fallback
      print('🤖 Trying OpenRouter AI for unknown product...');
      final aiResult = await _getNutritionFromOpenRouter('Unknown Product', cleanBarcode);
      if (aiResult != null) {
        print('✅ Found via AI analysis: ${aiResult.foodName}');
        _cache[cleanBarcode] = aiResult;
        _cacheTimestamps[cleanBarcode] = DateTime.now();
        return aiResult;
      }

      print('❌ No nutrition data found for barcode: $cleanBarcode');
      return null;

    } catch (e) {
      print('❌ Error scanning barcode: $e');
      return null;
    }
  }

  /// Enhanced barcode scanning with improved accuracy
  static Future<NutritionInfo?> scanBarcodeEnhanced(String barcode) async {
    print('🔍 Enhanced barcode scanning for: $barcode');
    
    // Clean the barcode
    final cleanBarcode = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanBarcode.length < 8) {
      print('❌ Invalid barcode length: ${cleanBarcode.length}');
      return null;
    }
    
    // Try regular scanning first
    final result = await scanBarcode(cleanBarcode);
    if (result != null) {
      print('✅ Enhanced scan successful');
      return result;
    }
    
    print('❌ Enhanced scanning failed');
    return null;
  }

  /// Get nutrition data from product name using free APIs
  static Future<NutritionInfo?> getNutritionFromProductName(String productName) async {
    try {
      // Clean the product name for better API matching
      final cleanName = _cleanProductName(productName);
      print('🔍 Getting nutrition for product name: $cleanName');

      // Try India-specific Open Food Facts first for better relevance
      print('🇮🇳 Trying India-specific Open Food Facts first...');
      final indiaResult = await _getNutritionFromOpenFoodFactsIndia(cleanName);
      if (indiaResult != null) {
        print('✅ Found India-specific result: ${indiaResult.foodName}');
        return indiaResult;
      }

      // Try Open Food Facts
      print('🌍 Trying Open Food Facts...');
      final openFoodFactsResult = await _getNutritionFromOpenFoodFacts(cleanName);
      if (openFoodFactsResult != null) {
        print('✅ Found in Open Food Facts: ${openFoodFactsResult.foodName}');
        return openFoodFactsResult;
      }

      // Try AI fallback
      print('🤖 Trying AI analysis...');
      final aiResult = await _getNutritionFromOpenRouter(cleanName, '');
      if (aiResult != null) {
        print('✅ Found via AI: ${aiResult.foodName}');
        return aiResult;
      }

      print('❌ No nutrition data found for product: $cleanName');
      return null;

    } catch (e) {
      print('❌ Error getting nutrition from product name: $e');
      return null;
    }
  }

  /// Search for packaged food in local dataset
  static NutritionInfo? _searchLocalPackagedFood(String barcode) {
    if (_indianPackaged == null) return null;
    
    for (final product in _indianPackaged!) {
      if (product['barcode'] == barcode) {
        final caloriesPer100g = (product['calories_per_100g'] as num).toDouble();
        final servingSizeGrams = (product['serving_size_grams'] as num).toDouble();
        final servingCalories = (caloriesPer100g * servingSizeGrams) / 100;
        
        return NutritionInfo(
          foodName: product['name'] as String,
          weightGrams: servingSizeGrams,
          calories: servingCalories,
          protein: (product['protein_per_100g'] as num).toDouble() * servingSizeGrams / 100,
          carbs: (product['carbs_per_100g'] as num).toDouble() * servingSizeGrams / 100,
          fat: (product['fat_per_100g'] as num).toDouble() * servingSizeGrams / 100,
          fiber: (product['fiber_per_100g'] as num).toDouble() * servingSizeGrams / 100,
          sugar: (product['sugar_per_100g'] as num).toDouble() * servingSizeGrams / 100,
          source: 'Local Indian Dataset',
          category: product['category'] as String,
          brand: product['brand'] as String,
          notes: 'Indian product from local database',
        );
      }
    }
    return null;
  }

  /// Scan barcode using Open Food Facts API
  static Future<NutritionInfo?> _scanWithOpenFoodFacts(String barcode) async {
    try {
      final url = '$_openFoodFactsBaseUrl/$barcode.json';
      print('📡 Calling Open Food Facts: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 Open Food Facts response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Open Food Facts response: ${data.keys.toList()}');
        
        if (data['status'] == 1) {
          final product = data['product'] as Map<String, dynamic>?;
          if (product != null) {
            return _parseOpenFoodFactsProduct(product);
          }
        } else {
          print('❌ Product not found in Open Food Facts');
        }
      } else {
        print('❌ Open Food Facts API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Open Food Facts API error: $e');
    }
    return null;
  }

  /// Parse Open Food Facts product data
  static NutritionInfo _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    final productName = product['product_name'] as String? ?? 
                       product['product_name_en'] as String? ?? 
                       'Unknown Product';
    
    final brand = product['brands'] as String? ?? product['brand'] as String?;
    final categories = product['categories'] as String?;
    final quantity = product['quantity'] as String?;
    
    // Extract nutrition data
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    
    final caloriesPer100g = _parseNutrient(nutriments, 'energy-kcal_100g') ?? 
                           _parseNutrient(nutriments, 'energy_100g') ?? 0.0;
    
    final proteinPer100g = _parseNutrient(nutriments, 'proteins_100g') ?? 0.0;
    final carbsPer100g = _parseNutrient(nutriments, 'carbohydrates_100g') ?? 0.0;
    final fatPer100g = _parseNutrient(nutriments, 'fat_100g') ?? 0.0;
    final fiberPer100g = _parseNutrient(nutriments, 'fiber_100g') ?? 0.0;
    final sugarPer100g = _parseNutrient(nutriments, 'sugars_100g') ?? 0.0;
    
    // Try to determine serving size
    double servingSize = 100.0; // Default to 100g
    if (quantity != null && quantity.isNotEmpty) {
      final weightAndUnits = _extractWeightAndUnits(quantity);
      if (weightAndUnits['weight'] > 0) {
        servingSize = weightAndUnits['weight'];
      }
    }
    
    // Calculate nutrition for the serving size
    final servingCalories = (caloriesPer100g * servingSize) / 100;
    final servingProtein = (proteinPer100g * servingSize) / 100;
    final servingCarbs = (carbsPer100g * servingSize) / 100;
    final servingFat = (fatPer100g * servingSize) / 100;
    final servingFiber = (fiberPer100g * servingSize) / 100;
    final servingSugar = (sugarPer100g * servingSize) / 100;
    
    // Create display name
    String displayName = productName;
    if (brand != null && brand.isNotEmpty && !displayName.toLowerCase().contains(brand.toLowerCase())) {
      displayName = '$brand $displayName';
    }
    if (quantity != null && quantity.isNotEmpty) {
      displayName = '$displayName ($quantity)';
    }
    
    return NutritionInfo(
      foodName: displayName,
      weightGrams: servingSize,
      calories: servingCalories,
      protein: servingProtein,
      carbs: servingCarbs,
      fat: servingFat,
      fiber: servingFiber,
      sugar: servingSugar,
      source: 'Open Food Facts',
      category: categories?.split(',').first.trim() ?? 'Unknown',
      brand: brand,
      notes: quantity != null ? 'Size: $quantity' : null,
    );
  }

  /// Get nutrition data from Open Food Facts by product name with India filter
  static Future<NutritionInfo?> _getNutritionFromOpenFoodFacts(String foodName) async {
    try {
      // Try with India filter for better relevance
      final indiaUrl = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1&countries_tags_en=india';
      
      final response = await http.get(
        Uri.parse(indiaUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['products'] as List?;
        
        if (products != null && products.isNotEmpty) {
          final product = products.first as Map<String, dynamic>;
          return _parseOpenFoodFactsProduct(product);
        }
      }
    } catch (e) {
      print('❌ Open Food Facts search error: $e');
    }
    return null;
  }

  /// Get nutrition data from Open Food Facts by product name with India filter only
  static Future<NutritionInfo?> _getNutritionFromOpenFoodFactsIndia(String foodName) async {
    try {
      // Try with India filter for better relevance
      final indiaUrl = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1&countries_tags_en=india';
      
      final response = await http.get(
        Uri.parse(indiaUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['products'] as List?;
        
        if (products != null && products.isNotEmpty) {
          final product = products.first as Map<String, dynamic>;
          return _parseOpenFoodFactsProduct(product);
        }
      }
    } catch (e) {
      print('❌ Open Food Facts India search error: $e');
    }
    return null;
  }

  /// Get nutrition data from OpenRouter AI
  static Future<NutritionInfo?> _getNutritionFromOpenRouter(String productName, String barcode) async {
    try {
      print('🤖 Querying OpenRouter AI for: $productName');
      
      final response = await http.post(
        Uri.parse(AIConfig.baseUrl),
        headers: {
          'Authorization': 'Bearer ${AIConfig.apiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': AIConfig.appUrl,
          'X-Title': AIConfig.appName,
        },
        body: jsonEncode({
          'model': AIConfig.chatModel,
          'messages': [
            {
              'role': 'system',
              'content': '''You are a certified fitness nutritionist. Provide accurate nutritional information for the given product.

Return ONLY valid JSON:
{
  "food": "Product name",
  "calories": number,
  "protein": "X.Xg",
  "carbs": "X.Xg", 
  "fat": "X.Xg",
  "fiber": "X.Xg",
  "sugar": "X.Xg",
  "serving_size": "Portion description",
  "confidence": 0.0-1.0,
  "fitness_category": "muscle_building|fat_loss|performance|recovery"
}

Be accurate and realistic while focusing on fitness nutrition.''',
            },
            {
              'role': 'user',
              'content': 'Provide nutritional information for: $productName${barcode.isNotEmpty ? ' (barcode: $barcode)' : ''}',
            },
          ],
          'max_tokens': AIConfig.maxTokens,
          'temperature': AIConfig.temperature,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String? ?? '';
        
        print('🤖 OpenRouter AI response: $content');
        
        // Try to parse JSON from the response
        try {
          String cleanedContent = content.trim();
          cleanedContent = cleanedContent.replaceAll('```json', '').replaceAll('```', '');
          
          final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedContent);
          if (jsonMatch != null) {
            final jsonStr = jsonMatch.group(0)!.trim();
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
            
            final calories = _parseNumber(parsed['calories']);
            final confidence = _parseNumber(parsed['confidence']) ?? 0.3;
            
            return NutritionInfo(
              foodName: (parsed['food'] ?? productName).toString(),
              weightGrams: 100.0, // Default serving size
              calories: calories ?? 0,
              protein: _parseMacro(parsed['protein']),
              carbs: _parseMacro(parsed['carbs']),
              fat: _parseMacro(parsed['fat']),
              fiber: _parseMacro(parsed['fiber']),
              sugar: _parseMacro(parsed['sugar']),
              source: 'OpenRouter AI',
              category: parsed['fitness_category']?.toString() ?? 'Unknown',
              brand: null,
              notes: 'AI analysis - confidence: ${(confidence * 100).toStringAsFixed(0)}%',
            );
          }
        } catch (e) {
          print('❌ Failed to parse OpenRouter AI JSON response: $e');
        }
        
        print('❌ OpenRouter AI response lacks meaningful nutrition data');
      } else {
        print('❌ OpenRouter AI HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ OpenRouter AI error: $e');
    }
    return null;
  }

  /// Clean and normalize barcode
  static String _cleanBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Clean product name for better API matching
  static String _cleanProductName(String productName) {
    return productName
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// Parse nutrient value from Open Food Facts
  static double? _parseNutrient(Map<String, dynamic> nutriments, String key) {
    final value = nutriments[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  /// Parse number from dynamic value
  static double? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleanValue = value.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(cleanValue);
    }
    return null;
  }

  /// Parse macro value properly
  static double _parseMacro(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleanValue = value.toString().trim();
      if (cleanValue.isEmpty) return 0.0;
      if (cleanValue.contains('g')) {
        final number = cleanValue.replaceAll('g', '').trim();
        return double.tryParse(number) ?? 0.0;
      }
      return double.tryParse(cleanValue) ?? 0.0;
    }
    return 0.0;
  }

  /// Extract weight and units from string
  static Map<String, dynamic> _extractWeightAndUnits(String text) {
    final weightPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb)');
    final match = weightPattern.firstMatch(text.toLowerCase());
    
    if (match != null) {
      final weight = double.tryParse(match.group(1)!) ?? 0.0;
      final unit = match.group(2)!;
      
      double weightInGrams = weight;
      if (unit == 'kg') weightInGrams = weight * 1000;
      else if (unit == 'ml') weightInGrams = weight; // Assume 1ml = 1g for liquids
      else if (unit == 'l') weightInGrams = weight * 1000;
      else if (unit == 'oz') weightInGrams = weight * 28.35;
      else if (unit == 'lb') weightInGrams = weight * 453.59;
      
      return {
        'weight': weightInGrams,
        'unit': unit,
        'display': '$weight $unit',
      };
    }
    
    return {
      'weight': 100.0,
      'unit': 'g',
      'display': '100g',
    };
  }

  /// Clear expired cache entries
  static void _clearExpiredCache() {
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (DateTime.now().difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      print('🧹 Cleared ${expiredKeys.length} expired cache entries');
    }
  }
}
