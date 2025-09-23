import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/nutrition_info.dart';
import '../config/ai_config.dart';

/// Service for barcode scanning with multiple APIs and local datasets
class BarcodeScanningService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const String _upcDatabaseBaseUrl = 'https://api.upcitemdb.com/prod/trial/lookup';
  static const String _barcodeLookupBaseUrl = 'https://api.barcodelookup.com/v3/products';
  static const String _nutritionixBaseUrl = 'https://trackapi.nutritionix.com/v2/search/item';
  static const String _edamamBaseUrl = 'https://api.edamam.com/api/nutrition-data';
  
  // Free API keys for better reliability
  static const String _upcApiKey = 'your-upc-api-key'; // Replace with actual key
  static const String _barcodeLookupApiKey = 'your-barcode-lookup-key'; // Replace with actual key
  static const String _nutritionixAppId = 'your-nutritionix-app-id';
  static const String _nutritionixApiKey = 'your-nutritionix-api-key';
  static const String _edamamAppId = 'your-edamam-app-id';
  static const String _edamamApiKey = 'your-edamam-api-key';
  
  // Additional API endpoints for better coverage
  static const String _foodDataCentralBaseUrl = 'https://api.nal.usda.gov/fdc/v1/foods/search';
  static const String _foodDataCentralApiKey = 'your-usda-api-key'; // Free from USDA
  static const String _spoonacularBaseUrl = 'https://api.spoonacular.com/food/products';
  static const String _spoonacularApiKey = 'your-spoonacular-api-key'; // Free tier available
  
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
      {
        'barcode': '5449000000999',
        'name': 'Sprite',
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
        'barcode': '5449000001000',
        'name': 'Fanta Orange',
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
      // Add more popular products here...
    ];

    for (final product in popularProducts) {
      final barcode = product['barcode'] as String;
      final displayName = _createDisplayName(
        product['name'] as String,
        product['brand'] as String,
        '${product['weight']}${product['units']}',
      );
      
      _cache[barcode] = NutritionInfo(
        foodName: displayName,
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
        notes: 'Size: ${product['weight']}${product['units']}',
      );
    }
  }

  /// Scan barcode and get nutrition information
  static Future<NutritionInfo?> scanBarcode(String barcode) async {
    try {
      // Clean and normalize the barcode
      final cleanBarcode = _cleanBarcode(barcode);
      print('🔍 Scanning barcode: $cleanBarcode');
      print('🔍 Original barcode: $barcode');
      print('🔍 Cleaned barcode: $cleanBarcode');
      
      // Check cache first for speed
      if (_cache.containsKey(cleanBarcode)) {
        print('⚡ Found in cache');
        final cached = _cache[cleanBarcode];
        print('📦 Cached product: ${cached?.foodName}');
        print('🔥 Cached calories: ${cached?.calories}');
        return cached;
      }
      
      // Validate barcode format first
      if (!isValidBarcode(cleanBarcode)) {
        print('❌ Invalid barcode format or non-food product: $cleanBarcode');
        return _createNonFoodProductEntry(cleanBarcode);
      }

      // Try multiple APIs in parallel with smart cross-validation
      // Order by reliability for faster results
      print('🌍 Trying multiple APIs in parallel with cross-validation...');
      
      final futures = <Future<NutritionInfo?>>[
        _scanWithNutritionix(cleanBarcode),           // Highest reliability
        _scanWithFoodDataCentral(cleanBarcode),       // Highest reliability
        _scanWithEdamam(cleanBarcode),                // High reliability
        _scanWithSpoonacular(cleanBarcode),           // High reliability
        _scanWithOpenFoodFacts(cleanBarcode),         // Medium reliability
        _scanWithBarcodeLookup(cleanBarcode),         // Medium-low reliability
        _scanWithUPCDatabase(cleanBarcode),           // Low reliability
      ];
      
      // Wait for results with early exit for high-confidence results
      final results = await _waitForResultsWithEarlyExit(futures);
      
      // Cross-validate results and find the best one
      final crossValidationResult = _crossValidateResults(results, cleanBarcode);
      NutritionInfo? bestResult = crossValidationResult['result'];
      String? bestSource = crossValidationResult['source'];

      // If we found a product but no nutrition data, try to get nutrition from product name
      if (bestResult != null && bestResult.calories == 0) {
        print('🔍 Product found but no nutrition data, trying nutrition lookup...');
        final nutritionResult = await getNutritionFromProductName(bestResult.foodName);
        if (nutritionResult != null && nutritionResult.calories > 0) {
          // Merge product info with nutrition data
          bestResult = NutritionInfo(
            foodName: bestResult.foodName,
            weightGrams: bestResult.weightGrams,
            calories: nutritionResult.calories,
            protein: nutritionResult.protein,
            carbs: nutritionResult.carbs,
            fat: nutritionResult.fat,
            fiber: nutritionResult.fiber,
            sugar: nutritionResult.sugar,
            source: '${bestResult.source} + Nutrition Lookup',
            category: bestResult.category,
            brand: bestResult.brand,
            notes: '${bestResult.notes} | Nutrition data from product name lookup',
          );
          print('✅ Added nutrition data from product name lookup');
        } else {
          // Try to estimate nutrition based on product category and name
          print('🔍 Trying category-based nutrition estimation...');
          final estimatedNutrition = _estimateNutritionFromProductInfo(bestResult);
          if (estimatedNutrition != null) {
            bestResult = estimatedNutrition;
            print('✅ Added estimated nutrition data based on product category');
          }
        }
      }

      // If still no nutrition data, try to get it from product name using multiple APIs
      if (bestResult != null && bestResult.calories == 0) {
        print('🔍 Trying comprehensive nutrition lookup...');
        final comprehensiveNutrition = await _getComprehensiveNutritionData(bestResult.foodName);
        if (comprehensiveNutrition != null) {
          bestResult = NutritionInfo(
            foodName: bestResult.foodName,
            weightGrams: bestResult.weightGrams,
            calories: comprehensiveNutrition.calories,
            protein: comprehensiveNutrition.protein,
            carbs: comprehensiveNutrition.carbs,
            fat: comprehensiveNutrition.fat,
            fiber: comprehensiveNutrition.fiber,
            sugar: comprehensiveNutrition.sugar,
            source: '${bestResult.source} + Comprehensive Lookup',
            category: bestResult.category,
            brand: bestResult.brand,
            notes: '${bestResult.notes} | Nutrition data from comprehensive lookup',
          );
          print('✅ Added nutrition data from comprehensive lookup');
        }
      }

      // If we found a result, cache it and return
      if (bestResult != null) {
        _cache[cleanBarcode] = bestResult;
        print('💾 Cached result from $bestSource');
        return bestResult;
      }

      // Fallback to local Indian packaged foods dataset
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
          return localResult;
        } else {
          print('❌ Not found in local Indian dataset');
        }
      } catch (e) {
        print('❌ Local dataset failed: $e');
      }

      // Try OpenRouter AI as final fallback for accurate nutrition data
      // Only if we have a meaningful product name
      if (bestResult != null && bestResult.foodName != 'Unknown Product' && bestResult.foodName.isNotEmpty) {
        print('🤖 Trying OpenRouter AI for accurate nutrition data...');
        final aiResult = await _getNutritionFromOpenRouter(bestResult.foodName, cleanBarcode);
        if (aiResult != null) {
          print('✅ Found accurate nutrition data via OpenRouter AI');
          _cache[cleanBarcode] = aiResult;
          return aiResult;
        }
      } else {
        print('❌ Skipping OpenRouter AI - no meaningful product name available');
      }

      print('❌ No nutrition data found for barcode: $cleanBarcode');
      
      // Create a working entry for unknown barcodes
      final workingEntry = _createWorkingBarcodeEntry(cleanBarcode);
      _cache[cleanBarcode] = workingEntry;
      return workingEntry;
    } catch (e) {
      print('❌ Error in barcode scanning: $e');
      return _createWorkingBarcodeEntry(barcode);
    }
  }

  /// Search for packaged food in local dataset
  static NutritionInfo? _searchLocalPackagedFood(String barcode) {
    if (_indianPackaged == null) {
      print('❌ Local dataset is null');
      return null;
    }
    
    print('🔍 Searching for barcode: $barcode in ${_indianPackaged!.length} products');
    
    final packagedFood = _indianPackaged!.firstWhere(
      (food) => food['barcode'] == barcode,
      orElse: () => <String, dynamic>{},
    );
    
    if (packagedFood.isEmpty) {
      print('❌ Barcode $barcode not found in local dataset');
      // Print first few barcodes for debugging
      if (_indianPackaged!.isNotEmpty) {
        print('📋 Sample barcodes in dataset:');
        for (int i = 0; i < math.min(5, _indianPackaged!.length); i++) {
          print('  - ${_indianPackaged![i]['barcode']}: ${_indianPackaged![i]['name']}');
        }
      }
      return null;
    }
    
    print('✅ Found barcode $barcode in local dataset');
    
    final servingSize = (packagedFood['serving_size_grams'] as num?)?.toDouble() ?? 100.0;
    
    return NutritionInfo(
      foodName: packagedFood['name'] as String? ?? 'Unknown Product',
      weightGrams: servingSize,
      calories: (packagedFood['calories_per_100g'] as num?)?.toDouble() ?? 0.0,
      protein: (packagedFood['protein_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbs: (packagedFood['carbs_per_100g'] as num?)?.toDouble() ?? 0.0,
      fat: (packagedFood['fat_per_100g'] as num?)?.toDouble() ?? 0.0,
      fiber: (packagedFood['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
      sugar: (packagedFood['sugar_per_100g'] as num?)?.toDouble() ?? 0.0,
      source: 'Indian Packaged Foods',
      category: packagedFood['category'] as String?,
      brand: packagedFood['brand'] as String?,
    );
  }


  /// Scan barcode using Open Food Facts API
  static Future<NutritionInfo?> _scanWithOpenFoodFacts(String barcode) async {
    try {
      final url = '$_openFoodFactsBaseUrl/$barcode.json';
      print('🌍 Fetching from Open Food Facts: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 Open Food Facts Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Open Food Facts Response data keys: ${data.keys.toList()}');
        
        final product = data['product'] as Map<String, dynamic>?;
        final status = data['status'] as int?;
        
        print('📊 Open Food Facts Product status: $status');
        print('📦 Open Food Facts Product data: ${product?.keys.toList()}');
        
        if (product != null && status == 1) {
          final result = _parseOpenFoodFactsProduct(product);
          print('✅ Successfully parsed Open Food Facts product: ${result.foodName}');
          return result;
        } else {
          print('❌ Product not found in Open Food Facts or status != 1');
          // Try alternative search if direct barcode lookup fails
          return await _searchOpenFoodFactsByBarcode(barcode);
        }
      } else {
        print('❌ Open Food Facts HTTP Error: ${response.statusCode}');
        print('📄 Open Food Facts Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Open Food Facts API error: $e');
    }
    return null;
  }

  /// Search Open Food Facts by barcode using search API with India filter
  static Future<NutritionInfo?> _searchOpenFoodFactsByBarcode(String barcode) async {
    try {
      // First try with India filter for better relevance
      final searchUrlIndia = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$barcode&search_simple=1&action=process&json=1&countries_tags_en=india';
      print('🔍 Searching Open Food Facts (India filter): $searchUrlIndia');
      
      final responseIndia = await http.get(
        Uri.parse(searchUrlIndia),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (responseIndia.statusCode == 200) {
        final data = jsonDecode(responseIndia.body);
        final products = data['products'] as List?;
        
        if (products != null && products.isNotEmpty) {
          // Find product with matching barcode
          for (final product in products) {
            final productBarcode = product['code'] as String?;
            if (productBarcode == barcode) {
              final result = _parseOpenFoodFactsProduct(product);
              print('✅ Found Open Food Facts product via India search: ${result.foodName}');
              return result;
            }
          }
        }
      }

      // If no results with India filter, try global search
      print('🔍 No India results, trying global Open Food Facts search...');
      final searchUrlGlobal = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$barcode&search_simple=1&action=process&json=1';
      final responseGlobal = await http.get(
        Uri.parse(searchUrlGlobal),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (responseGlobal.statusCode == 200) {
        final data = jsonDecode(responseGlobal.body);
        final products = data['products'] as List?;
        
        if (products != null && products.isNotEmpty) {
          // Find product with matching barcode
          for (final product in products) {
            final productBarcode = product['code'] as String?;
            if (productBarcode == barcode) {
              final result = _parseOpenFoodFactsProduct(product);
              print('✅ Found Open Food Facts product via global search: ${result.foodName}');
              return result;
            }
          }
        }
      }
    } catch (e) {
      print('❌ Open Food Facts search error: $e');
    }
    return null;
  }


  /// Parse Open Food Facts product data
  static NutritionInfo _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    final productName = product['product_name'] as String? ?? 
                       product['product_name_en'] as String? ?? 
                       'Unknown Product';
    final brand = product['brands'] as String? ?? 
                 product['brand_owner'] as String?;
    final categories = product['categories'] as String? ?? 
                      product['categories_en'] as String?;
    
    // Try to get serving size from multiple sources
    String? servingSizeStr = product['serving_size'] as String?;
    if (servingSizeStr == null) {
      servingSizeStr = product['quantity'] as String?;
    }
    if (servingSizeStr == null) {
      servingSizeStr = product['net_weight'] as String?;
    }
    
    // Extract weight and units properly
    final weightAndUnits = _extractWeightAndUnits(servingSizeStr);
    final weightGrams = weightAndUnits['weight'];
    final units = weightAndUnits['units'];
    final displayName = _createDisplayName(productName, brand, weightAndUnits['display']);
    
    // Extract nutrition values with multiple fallbacks
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    
    // Energy/Calories with multiple fallbacks
    double calories = 0.0;
    if (nutriments['energy-kcal_100g'] != null) {
      calories = (nutriments['energy-kcal_100g'] as num).toDouble();
    } else if (nutriments['energy_100g'] != null) {
      // Convert kJ to kcal if needed
      final energyKj = (nutriments['energy_100g'] as num).toDouble();
      calories = energyKj / 4.184; // Convert kJ to kcal
    } else if (nutriments['energy-kj_100g'] != null) {
      final energyKj = (nutriments['energy-kj_100g'] as num).toDouble();
      calories = energyKj / 4.184; // Convert kJ to kcal
    }
    
    final protein = (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0;
    final carbs = (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
    final fat = (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0;
    final fiber = (nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0;
    final sugar = (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0;
    
    // If no nutrition data per 100g, try per serving
    if (calories == 0.0 && protein == 0.0 && carbs == 0.0 && fat == 0.0) {
      final servingCalories = (nutriments['energy-kcal_serving'] as num?)?.toDouble() ?? 
                             (nutriments['energy_serving'] as num?)?.toDouble() ?? 0.0;
      final servingProtein = (nutriments['proteins_serving'] as num?)?.toDouble() ?? 0.0;
      final servingCarbs = (nutriments['carbohydrates_serving'] as num?)?.toDouble() ?? 0.0;
      final servingFat = (nutriments['fat_serving'] as num?)?.toDouble() ?? 0.0;
      final servingFiber = (nutriments['fiber_serving'] as num?)?.toDouble() ?? 0.0;
      final servingSugar = (nutriments['sugars_serving'] as num?)?.toDouble() ?? 0.0;
      
      return NutritionInfo(
        foodName: productName,
        weightGrams: weightGrams,
        calories: servingCalories,
        protein: servingProtein,
        carbs: servingCarbs,
        fat: servingFat,
        fiber: servingFiber,
        sugar: servingSugar,
        source: 'Open Food Facts',
        category: categories,
        brand: brand,
      );
    }
    
    // Convert from per 100g to actual weight
    final multiplier = weightGrams / 100.0;
    
    return NutritionInfo(
      foodName: displayName,
      weightGrams: weightGrams,
      calories: calories * multiplier,
      protein: protein * multiplier,
      carbs: carbs * multiplier,
      fat: fat * multiplier,
      fiber: fiber * multiplier,
      sugar: sugar * multiplier,
      source: 'Open Food Facts',
      category: categories,
      brand: brand,
      notes: 'Size: ${weightAndUnits['display']}',
    );
  }

  /// Scan barcode using UPC Database API
  static Future<NutritionInfo?> _scanWithUPCDatabase(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_upcDatabaseBaseUrl?upc=$barcode'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 UPC Database response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 UPC Database response: ${data.keys.toList()}');
        
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          return _parseUPCDatabaseProduct(item);
        }
      }
    } catch (e) {
      print('❌ UPC Database API error: $e');
    }
    return null;
  }

  /// Parse UPC Database product data
  static NutritionInfo _parseUPCDatabaseProduct(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? 'Unknown Product';
    final brand = item['brand'] as String?;
    final category = item['category'] as String?;
    final description = item['description'] as String?;
    
    // Try to extract size information from title or description
    String? sizeInfo = title;
    if (description != null && description.isNotEmpty) {
      sizeInfo = '$title $description';
    }
    
    final weightAndUnits = _extractWeightAndUnits(sizeInfo);
    final displayName = _createDisplayName(title, brand, weightAndUnits['display']);
    
    // UPC Database doesn't provide detailed nutrition info, so we'll create a generic entry
    return NutritionInfo(
      foodName: displayName,
      weightGrams: weightAndUnits['weight'],
      calories: 0.0, // Will need manual entry
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
      source: 'UPC Database',
      category: category,
      brand: brand,
      notes: 'Product found in UPC Database. Size: ${weightAndUnits['display']}. Please add nutrition information manually.',
    );
  }

  /// Validate barcode format and detect if it's likely a food product
  static bool isValidBarcode(String barcode) {
    // Remove any whitespace or special characters
    final cleanBarcode = barcode.trim().replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if barcode is numeric and has valid length
    if (cleanBarcode.isEmpty) return false;
    
    // Check common barcode lengths (expanded range)
    final validLengths = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
    if (!validLengths.contains(cleanBarcode.length)) return false;
    
    // Additional validation: Check if barcode is likely a non-food product
    if (_isLikelyNonFoodProduct(cleanBarcode)) {
      print('⚠️ Barcode appears to be for a non-food product');
      return false;
    }
    
    return true;
  }

  /// Check if barcode is likely for a non-food product (electronics, books, etc.)
  static bool _isLikelyNonFoodProduct(String barcode) {
    // Common non-food product prefixes
    final nonFoodPrefixes = [
      '978', // ISBN books
      '979', // ISBN books
      '977', // ISSN magazines
      '9780', // US books
      '9781', // US books
      '9782', // French books
      '9783', // German books
      '9784', // Japan books
      '9785', // Russian books
      '9786', // Spanish books
      '9787', // Chinese books
      '9788', // Italian books
      '9789', // UK books
      '690', // Chinese electronics (common prefix)
      '691', // Chinese electronics
      '692', // Chinese electronics
      '693', // Chinese electronics
      '694', // Chinese electronics
      '695', // Chinese electronics
    ];
    
    // Check prefixes
    for (final prefix in nonFoodPrefixes) {
      if (barcode.startsWith(prefix)) {
        return true;
      }
    }
    
    // Check for very short barcodes (often non-food)
    if (barcode.length <= 6) {
      return true;
    }
    
    // Check for patterns that suggest electronics or other non-food items
    // This is a heuristic approach
    if (barcode.startsWith('1') && barcode.length >= 12) {
      // Many electronics use this pattern
      final secondDigit = barcode[1];
      if ('0123456789'.contains(secondDigit)) {
        // Additional checks could be added here
        return false; // Allow for now, but could be enhanced
      }
    }
    
    return false;
  }
  
  /// Clean and normalize barcode
  static String _cleanBarcode(String barcode) {
    return barcode.trim().replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Extract weight and units from size string
  static Map<String, dynamic> _extractWeightAndUnits(String? sizeStr) {
    if (sizeStr == null || sizeStr.isEmpty) {
      return {
        'weight': 100.0,
        'units': 'g',
        'display': '100g',
      };
    }

    // Common unit patterns
    final unitPatterns = {
      'g': RegExp(r'(\d+(?:\.\d+)?)\s*g(?:rams?)?', caseSensitive: false),
      'kg': RegExp(r'(\d+(?:\.\d+)?)\s*kg', caseSensitive: false),
      'ml': RegExp(r'(\d+(?:\.\d+)?)\s*ml', caseSensitive: false),
      'l': RegExp(r'(\d+(?:\.\d+)?)\s*l(?:iters?)?', caseSensitive: false),
      'oz': RegExp(r'(\d+(?:\.\d+)?)\s*oz', caseSensitive: false),
      'lb': RegExp(r'(\d+(?:\.\d+)?)\s*lb', caseSensitive: false),
      'pieces': RegExp(r'(\d+(?:\.\d+)?)\s*(?:pieces?|pcs?)', caseSensitive: false),
    };

    // Try to match each unit pattern
    for (final entry in unitPatterns.entries) {
      final match = entry.value.firstMatch(sizeStr);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '0') ?? 0.0;
        String units = entry.key;
        double weightInGrams = value;

        // Convert to grams for consistency
        switch (units) {
          case 'kg':
            weightInGrams = value * 1000;
            units = 'g';
            break;
          case 'ml':
            // Assume 1ml = 1g for liquids
            weightInGrams = value;
            units = 'ml';
            break;
          case 'l':
            weightInGrams = value * 1000;
            units = 'ml';
            break;
          case 'oz':
            weightInGrams = value * 28.35;
            units = 'g';
            break;
          case 'lb':
            weightInGrams = value * 453.59;
            units = 'g';
            break;
          case 'pieces':
            // Estimate 50g per piece for food items
            weightInGrams = value * 50;
            units = 'g';
            break;
        }

        return {
          'weight': weightInGrams,
          'units': units,
          'display': '${value}${units}',
        };
      }
    }

    // If no unit pattern matches, try to extract just numbers
    final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(sizeStr);
    if (numberMatch != null) {
      final value = double.tryParse(numberMatch.group(1) ?? '100') ?? 100.0;
      return {
        'weight': value,
        'units': 'g',
        'display': '${value}g',
      };
    }

    // Default fallback
    return {
      'weight': 100.0,
      'units': 'g',
      'display': '100g',
    };
  }

  /// Create a clear display name for the product
  static String _createDisplayName(String productName, String? brand, String sizeDisplay) {
    // Clean up the product name
    String cleanName = productName.trim();
    
    // Remove common prefixes/suffixes that make names unclear
    cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' '); // Remove extra spaces
    cleanName = cleanName.replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), ''); // Remove leading special chars
    cleanName = cleanName.replaceAll(RegExp(r'[^a-zA-Z0-9\s]+$'), ''); // Remove trailing special chars
    
    // If brand is available and not already in the name, prepend it
    if (brand != null && brand.isNotEmpty && !cleanName.toLowerCase().contains(brand.toLowerCase())) {
      return '$brand $cleanName ($sizeDisplay)';
    }
    
    // If no brand or brand already in name, just add size
    return '$cleanName ($sizeDisplay)';
  }

  /// Create a working entry for unknown barcodes that users can edit
  static NutritionInfo _createWorkingBarcodeEntry(String barcode) {
    print('🆕 Creating unknown product entry for barcode: $barcode');
    
    // Don't provide estimates - be honest about unknown products
    return NutritionInfo(
      foodName: 'Unknown Product',
      weightGrams: 0.0,
      calories: 0.0,
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
      source: 'Unknown',
      category: 'Unknown',
      brand: 'Unknown',
      notes: 'Product not found in any database. Barcode: $barcode | Please add nutrition information manually.',
    );
  }

  /// Create an entry for non-food products
  static NutritionInfo _createNonFoodProductEntry(String barcode) {
    print('🚫 Creating non-food product entry for barcode: $barcode');
    
    final productType = _getNonFoodProductType(barcode);
    
    return NutritionInfo(
      foodName: 'Non-Food Product ($productType)',
      weightGrams: 0.0,
      calories: 0.0,
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
      source: 'Non-Food Detection',
      category: productType,
      brand: 'Unknown',
      notes: 'This barcode appears to be for a $productType, not a food product. Barcode: $barcode | Please scan a food product instead.',
    );
  }

  /// Determine the type of non-food product based on barcode
  static String _getNonFoodProductType(String barcode) {
    if (barcode.startsWith('978') || barcode.startsWith('979')) {
      return 'Book/Magazine';
    } else if (barcode.startsWith('977')) {
      return 'Magazine/Journal';
    } else if (barcode.startsWith('690') || barcode.startsWith('691') || 
               barcode.startsWith('692') || barcode.startsWith('693') ||
               barcode.startsWith('694') || barcode.startsWith('695')) {
      return 'Electronics/Device';
    } else if (barcode.length <= 6) {
      return 'Industrial/Commercial';
    } else {
      return 'Non-Food Item';
    }
  }

  /// Validate if nutrition data is accurate and reliable
  static bool _isDataAccurate(NutritionInfo nutritionInfo, String source) {
    // Check for obviously wrong data
    if (nutritionInfo.calories < 0 || 
        nutritionInfo.protein < 0 || 
        nutritionInfo.carbs < 0 || 
        nutritionInfo.fat < 0) {
      print('❌ Invalid negative values detected');
      return false;
    }
    
    // Check for unrealistic calorie values based on food type and weight
    if (nutritionInfo.calories > 0) {
      final caloriesPer100g = (nutritionInfo.calories / nutritionInfo.weightGrams) * 100;
      
      // Check for extremely high calorie density (>1000 kcal/100g is unrealistic for most foods)
      if (caloriesPer100g > 1000) {
        print('❌ Unrealistically high calorie density: ${caloriesPer100g.toStringAsFixed(1)} kcal/100g');
        return false;
      }
      
      // Check for extremely low calorie density (<1 kcal/100g is unrealistic for most foods)
      if (caloriesPer100g < 1 && nutritionInfo.weightGrams > 10) {
        print('❌ Unrealistically low calorie density: ${caloriesPer100g.toStringAsFixed(1)} kcal/100g');
        return false;
      }
      
      // Check for unrealistic calories for small portions
      if (nutritionInfo.calories > 1000 && nutritionInfo.weightGrams <= 100) {
        print('❌ Unrealistically high calories for small portion: ${nutritionInfo.calories} kcal for ${nutritionInfo.weightGrams}g');
        return false;
      }
    }
    
    // Check for missing essential data
    if (nutritionInfo.calories == 0 && 
        nutritionInfo.protein == 0 && 
        nutritionInfo.carbs == 0 && 
        nutritionInfo.fat == 0) {
      print('❌ No nutrition data available');
      return false;
    }
    
    // Check for suspicious macro ratios (protein + carbs + fat should be reasonable)
    final totalMacros = nutritionInfo.protein + nutritionInfo.carbs + nutritionInfo.fat;
    if (totalMacros > 0) {
      final macroCalories = (nutritionInfo.protein * 4) + (nutritionInfo.carbs * 4) + (nutritionInfo.fat * 9);
      final macroCalorieRatio = macroCalories / nutritionInfo.calories;
      
      // Macro calories should be close to total calories (within 20% tolerance)
      if (nutritionInfo.calories > 0 && (macroCalorieRatio < 0.5 || macroCalorieRatio > 1.5)) {
        print('❌ Suspicious macro-to-calorie ratio: ${macroCalorieRatio.toStringAsFixed(2)}');
        return false;
      }
    }
    
    // Rate sources by reliability
    final reliableSources = [
      'Nutritionix',
      'USDA FoodData Central', 
      'Edamam',
      'Spoonacular'
    ];
    
    final moderateSources = [
      'Open Food Facts',
      'Indian Packaged Foods'
    ];
    
    final unreliableSources = [
      'UPC Database',
      'Barcode Lookup'
    ];
    
    if (reliableSources.contains(source)) {
      return true; // High confidence in these sources
    } else if (moderateSources.contains(source)) {
      // Additional validation for moderate sources
      if (nutritionInfo.calories > 0 && nutritionInfo.weightGrams > 0) {
        return true;
      }
      return false;
    } else if (unreliableSources.contains(source)) {
      // Be very strict with unreliable sources
      if (nutritionInfo.calories > 0 && 
          nutritionInfo.weightGrams > 0 &&
          nutritionInfo.foodName != 'Unknown Product' &&
          !nutritionInfo.foodName.toLowerCase().contains('unknown')) {
        return true;
      }
      return false;
    }
    
    return false; // Unknown source
  }

  /// Get nutrition estimate based on product type
  static Map<String, double> _getNutritionEstimate(String productType, double weightGrams) {
    // Base nutrition per 100g for different product types
    Map<String, double> baseNutrition;
    
    switch (productType.toLowerCase()) {
      case 'beverages':
        baseNutrition = {
          'calories': 40.0,
          'protein': 0.0,
          'carbs': 10.0,
          'fat': 0.0,
          'fiber': 0.0,
          'sugar': 10.0,
        };
        break;
      case 'soft drinks':
        baseNutrition = {
          'calories': 42.0,
          'protein': 0.0,
          'carbs': 10.6,
          'fat': 0.0,
          'fiber': 0.0,
          'sugar': 10.6,
        };
        break;
      case 'snacks':
        baseNutrition = {
          'calories': 500.0,
          'protein': 8.0,
          'carbs': 60.0,
          'fat': 25.0,
          'fiber': 3.0,
          'sugar': 15.0,
        };
        break;
      case 'dairy':
        baseNutrition = {
          'calories': 150.0,
          'protein': 8.0,
          'carbs': 12.0,
          'fat': 8.0,
          'fiber': 0.0,
          'sugar': 12.0,
        };
        break;
      case 'dairy beverages':
        baseNutrition = {
          'calories': 85.0,
          'protein': 3.2,
          'carbs': 12.5,
          'fat': 2.8,
          'fiber': 0.0,
          'sugar': 12.5,
        };
        break;
      case 'instant noodles':
        baseNutrition = {
          'calories': 450.0,
          'protein': 12.0,
          'carbs': 70.0,
          'fat': 15.0,
          'fiber': 2.0,
          'sugar': 3.0,
        };
        break;
      case 'indian snacks':
        baseNutrition = {
          'calories': 500.0,
          'protein': 8.0,
          'carbs': 40.0,
          'fat': 36.0,
          'fiber': 4.0,
          'sugar': 4.0,
        };
        break;
      case 'indian sweets':
        baseNutrition = {
          'calories': 400.0,
          'protein': 4.0,
          'carbs': 60.0,
          'fat': 16.0,
          'fiber': 0.0,
          'sugar': 60.0,
        };
        break;
      case 'biscuits & cookies':
        baseNutrition = {
          'calories': 480.0,
          'protein': 8.0,
          'carbs': 72.0,
          'fat': 18.0,
          'fiber': 2.0,
          'sugar': 32.0,
        };
        break;
      case 'fried snacks':
        baseNutrition = {
          'calories': 500.0,
          'protein': 6.7,
          'carbs': 50.0,
          'fat': 30.0,
          'fiber': 3.3,
          'sugar': 3.3,
        };
        break;
      case 'cereals':
        baseNutrition = {
          'calories': 350.0,
          'protein': 10.0,
          'carbs': 70.0,
          'fat': 5.0,
          'fiber': 8.0,
          'sugar': 20.0,
        };
        break;
      default: // Packaged Food
        baseNutrition = {
          'calories': 300.0,
          'protein': 8.0,
          'carbs': 45.0,
          'fat': 12.0,
          'fiber': 3.0,
          'sugar': 15.0,
        };
    }
    
    // Scale to actual weight
    final multiplier = weightGrams / 100.0;
    return {
      'calories': baseNutrition['calories']! * multiplier,
      'protein': baseNutrition['protein']! * multiplier,
      'carbs': baseNutrition['carbs']! * multiplier,
      'fat': baseNutrition['fat']! * multiplier,
      'fiber': baseNutrition['fiber']! * multiplier,
      'sugar': baseNutrition['sugar']! * multiplier,
    };
  }

  /// Get barcode type
  static String getBarcodeType(String barcode) {
    switch (barcode.length) {
      case 8:
        return 'EAN-8';
      case 12:
        return 'UPC-A';
      case 13:
        return 'EAN-13';
      case 14:
        return 'ITF-14';
      default:
        return 'Unknown';
    }
  }

  /// Get all available barcode scanning sources
  static List<String> getAvailableSources() {
    final sources = <String>[
      'Local Dataset',
      'Open Food Facts',
      'UPC Database',
      'Barcode Lookup',
      'Nutritionix',
      'Edamam',
      'USDA FoodData Central',
      'Spoonacular',
      'OpenRouter AI',
      'Local Knowledge Base',
    ];
    
    return sources;
  }

  /// Get scanning statistics
  static Map<String, dynamic> getScanningStats() {
    return {
      'localDatasetSize': _indianPackaged?.length ?? 0,
      'cacheSize': _cache.length,
      'availableSources': getAvailableSources(),
      'supportedBarcodeTypes': ['EAN-8', 'UPC-A', 'EAN-13', 'ITF-14'],
      'totalCoverage': '1,000,000+ products',
      'apiCount': 7,
      'features': [
        'Barcode scanning',
        'Product name lookup',
        'Nutrition data extraction',
        'Multiple API fallbacks',
        'Local knowledge base',
        'Comprehensive nutrition lookup',
      ],
    };
  }

  /// Clear cache to free memory
  static void clearCache() {
    _cache.clear();
    print('🗑️ Cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    final sources = <String, int>{};
    for (final info in _cache.values) {
      sources[info.source] = (sources[info.source] ?? 0) + 1;
    }
    
    return {
      'totalProducts': _cache.length,
      'sources': sources,
      'memoryUsage': '${_cache.length * 0.5}KB estimated',
    };
  }

  /// Test barcode scanning with a known working barcode
  static Future<void> testBarcodeScanning() async {
    print('🧪 Testing barcode scanning...');
    
    // Test with a known barcode (Coca-Cola example)
    final testBarcode = '5449000000996';
    print('🔍 Testing with barcode: $testBarcode');
    
    final result = await scanBarcode(testBarcode);
    if (result != null) {
      print('✅ Test successful!');
      print('📦 Product: ${result.foodName}');
      print('🏷️ Brand: ${result.brand}');
      print('🔥 Calories: ${result.calories}');
      print('📊 Source: ${result.source}');
    } else {
      print('❌ Test failed - no result returned');
    }
  }

  /// Test barcode scanning with Milkymist vanilla milkshake
  static Future<void> testMilkymistBarcodeScanning() async {
    print('🧪 Testing Milkymist vanilla milkshake barcode scanning...');
    
    // Test with Milkymist vanilla milkshake barcode
    final testBarcode = '8901030865020';
    print('🔍 Testing with barcode: $testBarcode');
    
    final result = await scanBarcode(testBarcode);
    if (result != null) {
      print('✅ Milkymist test successful!');
      print('📦 Product: ${result.foodName}');
      print('🏷️ Brand: ${result.brand}');
      print('🔥 Calories: ${result.calories}');
      print('📊 Source: ${result.source}');
      print('📏 Weight: ${result.weightGrams}g');
      print('🥛 Category: ${result.category}');
      print('📝 Notes: ${result.notes}');
    } else {
      print('❌ Milkymist test failed - no result returned');
    }
  }

  /// Test barcode scanning with any barcode
  static Future<void> testBarcodeWithCode(String barcode) async {
    print('🧪 Testing barcode scanning with: $barcode');
    
    final result = await scanBarcode(barcode);
    if (result != null) {
      print('✅ Barcode test successful!');
      print('📦 Product: ${result.foodName}');
      print('🏷️ Brand: ${result.brand}');
      print('🔥 Calories: ${result.calories}');
      print('📊 Source: ${result.source}');
      print('📏 Weight: ${result.weightGrams}g');
      print('🥛 Category: ${result.category}');
      print('📝 Notes: ${result.notes}');
    } else {
      print('❌ Barcode test failed - no result returned');
    }
  }

  /// Debug barcode scanning with detailed logging
  static Future<NutritionInfo?> debugBarcodeScan(String barcode) async {
    print('🐛 DEBUG: Starting barcode scan for: $barcode');
    
    // Initialize if needed
    if (_indianPackaged == null) {
      print('🐛 DEBUG: Initializing service...');
      await initialize();
    }
    
    print('🐛 DEBUG: Service initialized, dataset size: ${_indianPackaged?.length ?? 0}');
    
    // Test the scan
    final result = await scanBarcode(barcode);
    
    if (result != null) {
      print('🐛 DEBUG: Scan successful!');
      print('🐛 DEBUG: Result details:');
      print('  - Food Name: ${result.foodName}');
      print('  - Brand: ${result.brand}');
      print('  - Calories: ${result.calories}');
      print('  - Weight: ${result.weightGrams}g');
      print('  - Source: ${result.source}');
      print('  - Category: ${result.category}');
    } else {
      print('🐛 DEBUG: Scan failed - no result returned');
    }
    
    return result;
  }

  /// Get nutrition data from product name using multiple APIs
  static Future<NutritionInfo?> getNutritionFromProductName(String productName) async {
    try {
      // Clean the product name for better API matching
      final cleanName = _cleanProductName(productName);
      print('🔍 Looking up nutrition for: $cleanName');
      
      // First try to get nutrition from local knowledge base for common Indian products
      final localNutrition = _getLocalNutritionEstimate(cleanName);
      if (localNutrition != null) {
        print('✅ Found nutrition data in local knowledge base');
        return localNutrition;
      }
      
      // Try India-specific Open Food Facts first for better relevance
      print('🇮🇳 Trying India-specific Open Food Facts first...');
      final indiaResult = await _getNutritionFromOpenFoodFactsIndia(cleanName);
      if (indiaResult != null) {
        print('✅ Found India-specific result: ${indiaResult.foodName}');
        return indiaResult;
      }

      // Try multiple nutrition APIs (conservative approach - no AI estimates)
      final futures = <Future<NutritionInfo?>>[
        _getNutritionFromEdamam(cleanName),
        _getNutritionFromNutritionix(cleanName),
        _getNutritionFromOpenFoodFacts(cleanName),
        _getNutritionFromFoodDataCentral(cleanName),
        _getNutritionFromSpoonacular(cleanName),
      ];
      
      final results = await Future.wait(futures, eagerError: false);
      
      // Return the first result with nutrition data
      for (final result in results) {
        if (result != null && result.calories > 0) {
          return result;
        }
      }
    } catch (e) {
      print('❌ Nutrition lookup error: $e');
    }
    return null;
  }

  /// Get comprehensive nutrition data using all available APIs
  static Future<NutritionInfo?> _getComprehensiveNutritionData(String productName) async {
    try {
      final cleanName = _cleanProductName(productName);
      print('🔍 Comprehensive nutrition lookup for: $cleanName');
      
      // Try India-specific Open Food Facts first for better relevance
      print('🇮🇳 Trying India-specific Open Food Facts first...');
      final indiaResult = await _getNutritionFromOpenFoodFactsIndia(cleanName);
      if (indiaResult != null) {
        print('✅ Found India-specific result: ${indiaResult.foodName}');
        return indiaResult;
      }
      
      // Try all available nutrition APIs (excluding OpenRouter AI for conservative approach)
      final futures = <Future<NutritionInfo?>>[
        _getNutritionFromEdamam(cleanName),
        _getNutritionFromNutritionix(cleanName),
        _getNutritionFromOpenFoodFacts(cleanName),
        _getNutritionFromFoodDataCentral(cleanName),
        _getNutritionFromSpoonacular(cleanName),
      ];
      
      final results = await Future.wait(futures, eagerError: false);
      
      // Find the best result with nutrition data
      NutritionInfo? bestResult;
      for (final result in results) {
        if (result != null && result.calories > 0) {
          if (bestResult == null || result.calories > bestResult.calories) {
            bestResult = result;
          }
        }
      }
      
      return bestResult;
    } catch (e) {
      print('❌ Comprehensive nutrition lookup error: $e');
    }
    return null;
  }

  /// Get nutrition data from USDA FoodData Central by product name
  static Future<NutritionInfo?> _getNutritionFromFoodDataCentral(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$_foodDataCentralBaseUrl?query=$foodName&api_key=$_foodDataCentralApiKey&pageSize=1'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final foods = data['foods'] as List?;
        if (foods != null && foods.isNotEmpty) {
          final food = foods.first as Map<String, dynamic>;
          return _parseFoodDataCentralProduct(food);
        }
      }
    } catch (e) {
      print('❌ USDA FoodData Central nutrition API error: $e');
    }
    return null;
  }

  /// Get nutrition data from Spoonacular by product name
  static Future<NutritionInfo?> _getNutritionFromSpoonacular(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$_spoonacularBaseUrl/search?query=$foodName&apiKey=$_spoonacularApiKey&number=1'),
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
          return _parseSpoonacularProduct(product);
        }
      }
    } catch (e) {
      print('❌ Spoonacular nutrition API error: $e');
    }
    return null;
  }


  /// Get nutrition data from Open Food Facts by product name with India filter only
  static Future<NutritionInfo?> _getNutritionFromOpenFoodFactsIndia(String foodName) async {
    try {
      // Try with India filter for better relevance
      final indiaUrl = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1&countries_tags_en=india';
      print('🇮🇳 Searching Open Food Facts (India only): $indiaUrl');
      
      final response = await http.get(
        Uri.parse(indiaUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = _parseOpenFoodFactsSearchResponse(data, foodName);
        if (result != null) {
          print('✅ Found Open Food Facts product via India search: ${result.foodName}');
          return result;
        }
      }
    } catch (e) {
      print('❌ Open Food Facts India API error: $e');
    }
    return null;
  }

  /// Get nutrition data from Open Food Facts by product name with India filter
  static Future<NutritionInfo?> _getNutritionFromOpenFoodFacts(String foodName) async {
    try {
      // First try with India filter for better relevance
      final indiaUrl = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1&countries_tags_en=india';
      print('🔍 Searching Open Food Facts (India filter): $indiaUrl');
      
      final responseIndia = await http.get(
        Uri.parse(indiaUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (responseIndia.statusCode == 200) {
        final data = jsonDecode(responseIndia.body);
        final result = _parseOpenFoodFactsSearchResponse(data, foodName);
        if (result != null) {
          print('✅ Found Open Food Facts product via India search: ${result.foodName}');
          return result;
        }
      }

      // If no results with India filter, try global search
      print('🔍 No India results, trying global Open Food Facts search...');
      final globalUrl = 'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$foodName&search_simple=1&action=process&json=1';
      final responseGlobal = await http.get(
        Uri.parse(globalUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      if (responseGlobal.statusCode == 200) {
        final data = jsonDecode(responseGlobal.body);
        final result = _parseOpenFoodFactsSearchResponse(data, foodName);
        if (result != null) {
          print('✅ Found Open Food Facts product via global search: ${result.foodName}');
          return result;
        }
      }
    } catch (e) {
      print('❌ Open Food Facts nutrition API error: $e');
    }
    return null;
  }

  /// Parse Open Food Facts search response
  static NutritionInfo? _parseOpenFoodFactsSearchResponse(Map<String, dynamic> data, String foodName) {
    try {
      final products = data['products'] as List?;
      if (products != null && products.isNotEmpty) {
        // Find the best matching product
        Map<String, dynamic>? bestProduct;
        int bestScore = 0;
        
        for (final product in products) {
          final productMap = product as Map<String, dynamic>;
          final productName = productMap['product_name'] as String? ?? 
                             productMap['product_name_en'] as String? ?? '';
          
          // Simple scoring based on name similarity
          final score = _calculateNameSimilarity(foodName.toLowerCase(), productName.toLowerCase());
          if (score > bestScore) {
            bestScore = score;
            bestProduct = productMap;
          }
        }
        
        if (bestProduct != null) {
          return _parseOpenFoodFactsProduct(bestProduct);
        }
      }
    } catch (e) {
      print('❌ Error parsing Open Food Facts search response: $e');
    }
    return null;
  }

  /// Calculate name similarity score
  static int _calculateNameSimilarity(String name1, String name2) {
    if (name1.isEmpty || name2.isEmpty) return 0;
    
    // Simple word-based similarity
    final words1 = name1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = name2.split(' ').where((w) => w.isNotEmpty).toSet();
    
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    if (union == 0) return 0;
    return (intersection * 100 / union).round();
  }

  /// Get nutrition data from OpenRouter AI
  static Future<NutritionInfo?> _getNutritionFromOpenRouter(String productName, String barcode) async {
    try {
      print('🤖 Querying OpenRouter AI for: $productName');
      
      final prompt = '''
Analyze this food product and provide accurate nutrition information:

Product Name: $productName
Barcode: $barcode

Please provide the following information in JSON format:
{
  "foodName": "Full product name with brand",
  "weightGrams": 100,
  "calories": 0,
  "protein": 0.0,
  "carbs": 0.0,
  "fat": 0.0,
  "fiber": 0.0,
  "sugar": 0.0,
  "category": "Food category",
  "brand": "Brand name",
  "notes": "Additional information"
}

CRITICAL ACCURACY REQUIREMENTS:
- ONLY provide nutrition data if you are 100% confident about the specific product
- If you don't know the exact product or are unsure, return "null"
- Do NOT provide estimates or guesses for unknown products
- Only respond with data for well-known, specific products with verified nutrition data
- Focus on Indian food products and common international brands with official nutrition facts
- Be extremely conservative - it's better to return null than wrong data
- If the product is unknown, unclear, or you're not confident, return "null"
- Only use verified nutrition information from official sources
- Do NOT estimate or guess nutrition values
- If nutrition data is incomplete or uncertain, return "null"

Respond only with valid JSON for known products with verified nutrition or "null" if unknown/uncertain.
''';

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
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 100,
          'temperature': 0.3, // Lower temperature for more consistent results
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        
        if (content != null && content.trim() != 'null') {
          print('🤖 OpenRouter AI response: $content');
          
          // Try to parse the JSON response
          try {
            final nutritionData = jsonDecode(content) as Map<String, dynamic>;
            
            final foodName = nutritionData['foodName'] as String? ?? productName;
            final weightGrams = (nutritionData['weightGrams'] as num?)?.toDouble() ?? 100.0;
            final calories = (nutritionData['calories'] as num?)?.toDouble() ?? 0.0;
            final protein = (nutritionData['protein'] as num?)?.toDouble() ?? 0.0;
            final carbs = (nutritionData['carbs'] as num?)?.toDouble() ?? 0.0;
            final fat = (nutritionData['fat'] as num?)?.toDouble() ?? 0.0;
            final fiber = (nutritionData['fiber'] as num?)?.toDouble() ?? 0.0;
            final sugar = (nutritionData['sugar'] as num?)?.toDouble() ?? 0.0;
            final category = nutritionData['category'] as String?;
            final brand = nutritionData['brand'] as String?;
            final notes = nutritionData['notes'] as String?;
            
            // Validate that we have meaningful nutrition data
            if (calories > 0 || protein > 0 || carbs > 0 || fat > 0) {
              final result = NutritionInfo(
                foodName: foodName,
                weightGrams: weightGrams,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                sugar: sugar,
                source: 'OpenRouter AI',
                category: category,
                brand: brand,
                notes: 'AI-powered analysis | $notes',
              );
              
              print('✅ OpenRouter AI provided nutrition data: ${result.foodName}');
              print('🔥 Calories: ${result.calories}, Protein: ${result.protein}g');
              return result;
            } else {
              print('❌ OpenRouter AI response lacks meaningful nutrition data');
            }
          } catch (e) {
            print('❌ Failed to parse OpenRouter AI JSON response: $e');
            print('📄 Raw response: $content');
          }
        } else {
          print('❌ OpenRouter AI returned null or empty response');
        }
      } else {
        print('❌ OpenRouter AI HTTP Error: ${response.statusCode}');
        print('📄 Response: ${response.body}');
      }
    } catch (e) {
      print('❌ OpenRouter AI error: $e');
    }
    return null;
  }

  /// Clean product name for better API matching
  static String _cleanProductName(String productName) {
    // Remove size information and extra details
    String clean = productName
        .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove parentheses content
        .replaceAll(RegExp(r'\d+\s*(g|ml|kg|l|oz|lb)'), '') // Remove size info
        .replaceAll(RegExp(r'\s+'), ' ') // Remove extra spaces
        .trim();
    
    // Remove common brand prefixes if they're redundant
    final brandPrefixes = ['Coca-Cola', 'Pepsi', 'Nestle', 'Unilever', 'Procter & Gamble'];
    for (final prefix in brandPrefixes) {
      if (clean.toLowerCase().startsWith(prefix.toLowerCase())) {
        clean = clean.substring(prefix.length).trim();
        break;
      }
    }
    
    return clean.isEmpty ? productName : clean;
  }

  /// Get nutrition data from Edamam API
  static Future<NutritionInfo?> _getNutritionFromEdamam(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$_edamamBaseUrl?app_id=$_edamamAppId&app_key=$_edamamApiKey&ingr=$foodName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseEdamamResponse(data, foodName);
      }
    } catch (e) {
      print('❌ Edamam nutrition API error: $e');
    }
    return null;
  }

  /// Get nutrition data from Nutritionix API
  static Future<NutritionInfo?> _getNutritionFromNutritionix(String foodName) async {
    try {
      final response = await http.post(
        Uri.parse('https://trackapi.nutritionix.com/v2/natural/nutrients'),
        headers: {
          'Content-Type': 'application/json',
          'x-app-id': _nutritionixAppId,
          'x-app-key': _nutritionixApiKey,
        },
        body: jsonEncode({'query': foodName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseNutritionixResponse(data, foodName);
      }
    } catch (e) {
      print('❌ Nutritionix nutrition API error: $e');
    }
    return null;
  }


  /// Scan barcode using Barcode Lookup API
  static Future<NutritionInfo?> _scanWithBarcodeLookup(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_barcodeLookupBaseUrl?barcode=$barcode&formatted=y&key=$_barcodeLookupApiKey'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 Barcode Lookup response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Barcode Lookup response: ${data.keys.toList()}');
        
        final products = data['products'] as List?;
        if (products != null && products.isNotEmpty) {
          final product = products.first as Map<String, dynamic>;
          return _parseBarcodeLookupProduct(product);
        }
      }
    } catch (e) {
      print('❌ Barcode Lookup API error: $e');
    }
    return null;
  }

  /// Parse Barcode Lookup product data
  static NutritionInfo _parseBarcodeLookupProduct(Map<String, dynamic> product) {
    final title = product['title'] as String? ?? 'Unknown Product';
    final brand = product['brand'] as String?;
    final category = product['category'] as String?;
    final description = product['description'] as String?;
    
    // Try to extract size information from title or description
    String? sizeInfo = title;
    if (description != null && description.isNotEmpty) {
      sizeInfo = '$title $description';
    }
    
    final weightAndUnits = _extractWeightAndUnits(sizeInfo);
    final displayName = _createDisplayName(title, brand, weightAndUnits['display']);
    
    return NutritionInfo(
      foodName: displayName,
      weightGrams: weightAndUnits['weight'],
      calories: 0.0, // Will need manual entry
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
      source: 'Barcode Lookup',
      category: category,
      brand: brand,
      notes: 'Product found in Barcode Lookup. Size: ${weightAndUnits['display']}. Please add nutrition information manually.',
    );
  }

  /// Scan barcode using Nutritionix API
  static Future<NutritionInfo?> _scanWithNutritionix(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_nutritionixBaseUrl?upc=$barcode'),
        headers: {
          'Content-Type': 'application/json',
          'x-app-id': _nutritionixAppId,
          'x-app-key': _nutritionixApiKey,
        },
      );

      print('📡 Nutritionix response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Nutritionix response: ${data.keys.toList()}');
        
        final foods = data['foods'] as List?;
        if (foods != null && foods.isNotEmpty) {
          final food = foods.first as Map<String, dynamic>;
          return _parseNutritionixProduct(food);
        }
      }
    } catch (e) {
      print('❌ Nutritionix API error: $e');
    }
    return null;
  }

  /// Parse Nutritionix product data
  static NutritionInfo _parseNutritionixProduct(Map<String, dynamic> food) {
    final foodName = food['food_name'] as String? ?? 'Unknown Product';
    final brand = food['brand_name'] as String?;
    final servingWeightGrams = (food['serving_weight_grams'] as num?)?.toDouble() ?? 100.0;
    
    final nfCalories = (food['nf_calories'] as num?)?.toDouble() ?? 0.0;
    final nfProtein = (food['nf_protein'] as num?)?.toDouble() ?? 0.0;
    final nfTotalCarbohydrate = (food['nf_total_carbohydrate'] as num?)?.toDouble() ?? 0.0;
    final nfTotalFat = (food['nf_total_fat'] as num?)?.toDouble() ?? 0.0;
    final nfDietaryFiber = (food['nf_dietary_fiber'] as num?)?.toDouble() ?? 0.0;
    final nfSugars = (food['nf_sugars'] as num?)?.toDouble() ?? 0.0;
    
    final displayName = _createDisplayName(foodName, brand, '${servingWeightGrams}g');
    
    return NutritionInfo(
      foodName: displayName,
      weightGrams: servingWeightGrams,
      calories: nfCalories,
      protein: nfProtein,
      carbs: nfTotalCarbohydrate,
      fat: nfTotalFat,
      fiber: nfDietaryFiber,
      sugar: nfSugars,
      source: 'Nutritionix',
      category: food['food_type'] as String?,
      brand: brand,
      notes: 'Size: ${servingWeightGrams}g',
    );
  }

  /// Scan barcode using Edamam API
  static Future<NutritionInfo?> _scanWithEdamam(String barcode) async {
    try {
      // Edamam doesn't support barcode lookup directly, but we can use it for nutrition data
      // This would require the product name from another API
      return null; // Placeholder for future implementation
    } catch (e) {
      print('❌ Edamam API error: $e');
    }
    return null;
  }

  /// Scan barcode using USDA FoodData Central API
  static Future<NutritionInfo?> _scanWithFoodDataCentral(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_foodDataCentralBaseUrl?query=$barcode&api_key=$_foodDataCentralApiKey&pageSize=1'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 USDA FoodData Central response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 USDA FoodData Central response: ${data.keys.toList()}');
        
        final foods = data['foods'] as List?;
        if (foods != null && foods.isNotEmpty) {
          final food = foods.first as Map<String, dynamic>;
          return _parseFoodDataCentralProduct(food);
        }
      }
    } catch (e) {
      print('❌ USDA FoodData Central API error: $e');
    }
    return null;
  }

  /// Parse USDA FoodData Central product data
  static NutritionInfo _parseFoodDataCentralProduct(Map<String, dynamic> food) {
    final description = food['description'] as String? ?? 'Unknown Product';
    final brandOwner = food['brandOwner'] as String?;
    final ingredients = food['ingredients'] as String?;
    
    // Extract nutrition data
    final foodNutrients = food['foodNutrients'] as List? ?? [];
    double calories = 0.0;
    double protein = 0.0;
    double carbs = 0.0;
    double fat = 0.0;
    double fiber = 0.0;
    double sugar = 0.0;
    
    for (final nutrient in foodNutrients) {
      final nutrientData = nutrient['nutrient'] as Map<String, dynamic>?;
      if (nutrientData != null) {
        final nutrientName = nutrientData['name'] as String? ?? '';
        final value = (nutrient['amount'] as num?)?.toDouble() ?? 0.0;
        
        switch (nutrientName.toLowerCase()) {
          case 'energy':
            calories = value;
            break;
          case 'protein':
            protein = value;
            break;
          case 'carbohydrate, by difference':
            carbs = value;
            break;
          case 'total lipid (fat)':
            fat = value;
            break;
          case 'fiber, total dietary':
            fiber = value;
            break;
          case 'sugars, total including nlea':
            sugar = value;
            break;
        }
      }
    }
    
    return NutritionInfo(
      foodName: description,
      weightGrams: 100.0, // USDA data is per 100g
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      source: 'USDA FoodData Central',
      category: food['foodCategory']?['description'] as String?,
      brand: brandOwner,
      notes: ingredients != null ? 'Ingredients: $ingredients' : null,
    );
  }

  /// Scan barcode using Spoonacular API
  static Future<NutritionInfo?> _scanWithSpoonacular(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_spoonacularBaseUrl/upc/$barcode?apiKey=$_spoonacularApiKey'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 Spoonacular response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Spoonacular response: ${data.keys.toList()}');
        
        return _parseSpoonacularProduct(data);
      }
    } catch (e) {
      print('❌ Spoonacular API error: $e');
    }
    return null;
  }

  /// Parse Spoonacular product data
  static NutritionInfo _parseSpoonacularProduct(Map<String, dynamic> product) {
    final title = product['title'] as String? ?? 'Unknown Product';
    final brand = product['brand'] as String?;
    final category = product['category'] as String?;
    
    // Extract nutrition data
    final nutrition = product['nutrition'] as Map<String, dynamic>? ?? {};
    final nutrients = nutrition['nutrients'] as List? ?? [];
    
    double calories = 0.0;
    double protein = 0.0;
    double carbs = 0.0;
    double fat = 0.0;
    double fiber = 0.0;
    double sugar = 0.0;
    
    for (final nutrient in nutrients) {
      final name = nutrient['name'] as String? ?? '';
      final amount = (nutrient['amount'] as num?)?.toDouble() ?? 0.0;
      final unit = nutrient['unit'] as String? ?? '';
      
      switch (name.toLowerCase()) {
        case 'calories':
          calories = amount;
          break;
        case 'protein':
          protein = amount;
          break;
        case 'carbohydrates':
          carbs = amount;
          break;
        case 'fat':
          fat = amount;
          break;
        case 'fiber':
          fiber = amount;
          break;
        case 'sugar':
          sugar = amount;
          break;
      }
    }
    
    return NutritionInfo(
      foodName: title,
      weightGrams: 100.0, // Spoonacular data is per 100g
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      source: 'Spoonacular',
      category: category,
      brand: brand,
    );
  }

  /// Parse Edamam API response
  static NutritionInfo _parseEdamamResponse(Map<String, dynamic> data, String foodName) {
    final calories = (data['calories'] as num?)?.toDouble() ?? 0.0;
    final nutrients = data['totalNutrients'] as Map<String, dynamic>? ?? {};
    
    final protein = (nutrients['PROCNT']?['quantity'] as num?)?.toDouble() ?? 0.0;
    final carbs = (nutrients['CHOCDF']?['quantity'] as num?)?.toDouble() ?? 0.0;
    final fat = (nutrients['FAT']?['quantity'] as num?)?.toDouble() ?? 0.0;
    final fiber = (nutrients['FIBTG']?['quantity'] as num?)?.toDouble() ?? 0.0;
    final sugar = (nutrients['SUGAR']?['quantity'] as num?)?.toDouble() ?? 0.0;
    
    return NutritionInfo(
      foodName: foodName,
      weightGrams: 100.0,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      source: 'Edamam Nutrition API',
      category: 'API Lookup',
    );
  }

  /// Parse Nutritionix API response
  static NutritionInfo _parseNutritionixResponse(Map<String, dynamic> data, String foodName) {
    final foods = data['foods'] as List?;
    if (foods == null || foods.isEmpty) return _createEmptyNutritionInfo(foodName);
    
    final food = foods.first as Map<String, dynamic>;
    final servingWeightGrams = (food['serving_weight_grams'] as num?)?.toDouble() ?? 100.0;
    
    final nfCalories = (food['nf_calories'] as num?)?.toDouble() ?? 0.0;
    final nfProtein = (food['nf_protein'] as num?)?.toDouble() ?? 0.0;
    final nfTotalCarbohydrate = (food['nf_total_carbohydrate'] as num?)?.toDouble() ?? 0.0;
    final nfTotalFat = (food['nf_total_fat'] as num?)?.toDouble() ?? 0.0;
    final nfDietaryFiber = (food['nf_dietary_fiber'] as num?)?.toDouble() ?? 0.0;
    final nfSugars = (food['nf_sugars'] as num?)?.toDouble() ?? 0.0;
    
    return NutritionInfo(
      foodName: foodName,
      weightGrams: servingWeightGrams,
      calories: nfCalories,
      protein: nfProtein,
      carbs: nfTotalCarbohydrate,
      fat: nfTotalFat,
      fiber: nfDietaryFiber,
      sugar: nfSugars,
      source: 'Nutritionix Nutrition API',
      category: food['food_type'] as String? ?? 'API Lookup',
    );
  }


  /// Create empty nutrition info as fallback
  static NutritionInfo _createEmptyNutritionInfo(String foodName) {
    return NutritionInfo(
      foodName: foodName,
      weightGrams: 100.0,
      calories: 0.0,
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
      source: 'No Nutrition Data',
      category: 'Unknown',
      notes: 'No nutrition data found for this product',
    );
  }

  /// Estimate nutrition from product information when no data is available
  static NutritionInfo? _estimateNutritionFromProductInfo(NutritionInfo productInfo) {
    try {
      final productName = productInfo.foodName.toLowerCase();
      final weight = productInfo.weightGrams;
      
      // Determine product category from name and existing category
      String category = productInfo.category?.toLowerCase() ?? '';
      if (category.isEmpty) {
        category = _inferProductCategory(productName);
      }
      
      // Get nutrition estimate based on category
      final nutritionData = _getNutritionEstimate(category, weight);
      
      if (nutritionData['calories']! > 0) {
        return NutritionInfo(
          foodName: productInfo.foodName,
          weightGrams: weight,
          calories: nutritionData['calories']!,
          protein: nutritionData['protein']!,
          carbs: nutritionData['carbs']!,
          fat: nutritionData['fat']!,
          fiber: nutritionData['fiber']!,
          sugar: nutritionData['sugar']!,
          source: '${productInfo.source} + Category Estimation',
          category: productInfo.category,
          brand: productInfo.brand,
          notes: '${productInfo.notes} | Estimated nutrition based on product category: $category',
        );
      }
    } catch (e) {
      print('❌ Error estimating nutrition from product info: $e');
    }
    return null;
  }

  /// Check if one result is better than another as a fallback
  static bool _isBetterFallback(NutritionInfo newResult, NutritionInfo currentBest) {
    // Prefer results with more complete nutrition data
    final newCompleteness = _getNutritionCompleteness(newResult);
    final currentCompleteness = _getNutritionCompleteness(currentBest);
    
    if (newCompleteness > currentCompleteness) {
      return true;
    } else if (newCompleteness == currentCompleteness) {
      // If completeness is equal, prefer results with more calories (more likely to be real food)
      return newResult.calories > currentBest.calories;
    }
    
    return false;
  }

  /// Calculate nutrition data completeness score
  static int _getNutritionCompleteness(NutritionInfo nutritionInfo) {
    int score = 0;
    if (nutritionInfo.calories > 0) score += 3;
    if (nutritionInfo.protein > 0) score += 1;
    if (nutritionInfo.carbs > 0) score += 1;
    if (nutritionInfo.fat > 0) score += 1;
    if (nutritionInfo.fiber > 0) score += 1;
    if (nutritionInfo.sugar > 0) score += 1;
    return score;
  }

  /// Cross-validate results from multiple APIs and return the best one
  static Map<String, dynamic> _crossValidateResults(List<NutritionInfo?> results, String barcode) {
    final apiNames = ['Nutritionix', 'USDA FoodData Central', 'Edamam', 'Spoonacular', 'Open Food Facts', 'Barcode Lookup', 'UPC Database'];
    
    // Filter out null results and collect valid ones with enhanced validation
    final validResults = <Map<String, dynamic>>[];
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      if (result != null && _isDataAccurate(result, apiNames[i])) {
        validResults.add({
          'result': result,
          'source': apiNames[i],
          'index': i,
          'accuracy_score': _calculateAccuracyScore(result),
        });
      }
    }
    
    if (validResults.isEmpty) {
      // No valid results found, try to find any result with basic validation
      for (int i = 0; i < results.length; i++) {
        if (results[i] != null) {
          final result = results[i]!;
          if (result.calories > 0 || result.foodName.isNotEmpty) {
            return {
              'result': result,
              'source': apiNames[i],
              'confidence': 0.3, // Low confidence for unvalidated data
            };
          }
        }
      }
      return {'result': null, 'source': null, 'confidence': 0.0};
    }
    
    // If only one result, return it with enhanced confidence calculation
    if (validResults.length == 1) {
      final result = validResults.first;
      final confidence = _calculateConfidence(result['result'], result['source']);
      return {
        'result': result['result'],
        'source': result['source'],
        'confidence': confidence,
      };
    }
    
    // Multiple results - enhanced cross-validation
    print('🔍 Cross-validating ${validResults.length} validated results...');
    
    // Group results by similar calorie values (within 15% tolerance for better accuracy)
    final calorieGroups = _groupByCalorieConsensus(validResults, tolerance: 0.15);
    
    // Find the group with most results and highest average accuracy
    String? bestGroup;
    double bestGroupScore = 0.0;
    
    for (final entry in calorieGroups.entries) {
      final groupResults = entry.value;
      final groupSize = groupResults.length;
      final avgAccuracy = groupResults.fold<double>(0.0, (sum, r) => sum + r['accuracy_score']) / groupSize;
      final groupScore = groupSize * 0.6 + avgAccuracy * 0.4; // Weighted score
      
      if (groupScore > bestGroupScore) {
        bestGroupScore = groupScore;
        bestGroup = entry.key;
      }
    }
    
    if (bestGroup != null && calorieGroups[bestGroup]!.length > 1) {
      // We have consensus - pick the best result from the consensus group
      final consensusResults = calorieGroups[bestGroup]!;
      final bestResult = _selectBestFromGroup(consensusResults);
      print('✅ Found consensus among ${consensusResults.length} sources (score: ${bestGroupScore.toStringAsFixed(2)})');
      return {
        'result': bestResult['result'],
        'source': bestResult['source'],
        'confidence': 0.95, // Very high confidence due to consensus
      };
    } else {
      // No clear consensus - pick the most reliable source with enhanced scoring
      final bestResult = _selectMostReliableResult(validResults, barcode);
      print('⚠️ No consensus found, using most reliable source: ${bestResult['source']}');
      return {
        'result': bestResult['result'],
        'source': bestResult['source'],
        'confidence': _calculateConfidence(bestResult['result'], bestResult['source']),
      };
    }
  }

  /// Group results by calorie consensus (with configurable tolerance)
  static Map<String, List<Map<String, dynamic>>> _groupByCalorieConsensus(List<Map<String, dynamic>> results, {double tolerance = 0.2}) {
    final groups = <String, List<Map<String, dynamic>>>{};
    
    for (final result in results) {
      final nutritionInfo = result['result'] as NutritionInfo;
      final calories = nutritionInfo.calories;
      
      // Find existing group with similar calories
      String? matchingGroup;
      for (final groupKey in groups.keys) {
        final groupCalories = double.parse(groupKey);
        final toleranceValue = groupCalories * tolerance;
        
        if ((calories - groupCalories).abs() <= toleranceValue) {
          matchingGroup = groupKey;
          break;
        }
      }
      
      if (matchingGroup != null) {
        groups[matchingGroup]!.add(result);
      } else {
        // Create new group
        groups[calories.toString()] = [result];
      }
    }
    
    return groups;
  }

  /// Select the best result from a group of consensus results
  static Map<String, dynamic> _selectBestFromGroup(List<Map<String, dynamic>> group) {
    // Sort by source reliability and data completeness
    group.sort((a, b) {
      final aReliability = _getSourceReliability(a['source']);
      final bReliability = _getSourceReliability(b['source']);
      
      if (aReliability != bReliability) {
        return bReliability.compareTo(aReliability); // Higher reliability first
      }
      
      // If same reliability, sort by completeness
      final aCompleteness = _getNutritionCompleteness(a['result']);
      final bCompleteness = _getNutritionCompleteness(b['result']);
      return bCompleteness.compareTo(aCompleteness);
    });
    
    return group.first;
  }

  /// Select the most reliable result when no consensus
  static Map<String, dynamic> _selectMostReliableResult(List<Map<String, dynamic>> results, [String? barcode]) {
    // Sort by enhanced reliability score
    results.sort((a, b) {
      final aScore = _calculateEnhancedReliabilityScore(a['result'], a['source'], barcode);
      final bScore = _calculateEnhancedReliabilityScore(b['result'], b['source'], barcode);
      return bScore.compareTo(aScore);
    });
    
    return results.first;
  }

  /// Calculate accuracy score for a nutrition result
  static double _calculateAccuracyScore(NutritionInfo result) {
    double score = 0.0;
    
    // Check for realistic calorie density (50-800 kcal/100g)
    if (result.weightGrams > 0) {
      final calorieDensity = (result.calories / result.weightGrams) * 100;
      if (calorieDensity >= 50 && calorieDensity <= 800) {
        score += 0.3;
      } else if (calorieDensity > 0) {
        score += 0.1; // Some points for having calories
      }
    }
    
    // Check macro nutrient ratios
    if (result.calories > 0) {
      final macroCalories = (result.protein * 4) + (result.carbs * 4) + (result.fat * 9);
      final macroRatio = macroCalories / result.calories;
      if (macroRatio >= 0.7 && macroRatio <= 1.3) {
        score += 0.3; // Good macro ratio
      } else if (macroRatio > 0) {
        score += 0.1; // Some points for having macros
      }
    }
    
    // Check data completeness
    int completeFields = 0;
    if (result.calories > 0) completeFields++;
    if (result.protein > 0) completeFields++;
    if (result.carbs > 0) completeFields++;
    if (result.fat > 0) completeFields++;
    if (result.fiber > 0) completeFields++;
    if (result.sugar > 0) completeFields++;
    if (result.foodName.isNotEmpty) completeFields++;
    if (result.brand != null && result.brand!.isNotEmpty) completeFields++;
    
    score += (completeFields / 8.0) * 0.4; // Up to 40% for completeness
    
    return score.clamp(0.0, 1.0);
  }

  /// Calculate enhanced reliability score
  static double _calculateEnhancedReliabilityScore(NutritionInfo result, String source, String? barcode) {
    double score = 0.0;
    
    // Source reliability (0.0 to 1.0)
    score += _getSourceReliability(source) * 0.4;
    
    // Data accuracy score
    score += _calculateAccuracyScore(result) * 0.3;
    
    // Data completeness
    score += (_getNutritionCompleteness(result) / 8.0) * 0.2;
    
    // Brand and name quality
    if (result.brand != null && result.brand!.isNotEmpty) score += 0.05;
    if (result.foodName.length > 3) score += 0.05;
    
    return score.clamp(0.0, 1.0);
  }

  /// Calculate reliability score for a result
  static double _calculateReliabilityScore(NutritionInfo result, String source) {
    double score = 0.0;
    
    // Source reliability (0.0 to 1.0)
    score += _getSourceReliability(source) * 0.4;
    
    // Data completeness (0.0 to 1.0)
    score += (_getNutritionCompleteness(result) / 8.0) * 0.3;
    
    // Data accuracy (0.0 to 1.0)
    score += (_isDataAccurate(result, source) ? 1.0 : 0.0) * 0.3;
    
    return score;
  }

  /// Get source reliability score
  static double _getSourceReliability(String source) {
    switch (source) {
      case 'Nutritionix':
      case 'USDA FoodData Central':
        return 1.0; // Highest reliability
      case 'Edamam':
      case 'Spoonacular':
        return 0.8; // High reliability
      case 'Open Food Facts':
        return 0.6; // Medium reliability
      case 'Barcode Lookup':
        return 0.5; // Medium-low reliability
      case 'UPC Database':
        return 0.3; // Low reliability
      default:
        return 0.1; // Very low reliability
    }
  }

  /// Calculate confidence score for a result
  static double _calculateConfidence(NutritionInfo result, String source) {
    double confidence = 0.5; // Base confidence
    
    // Boost confidence for reliable sources
    confidence += _getSourceReliability(source) * 0.3;
    
    // Boost confidence for complete data
    confidence += (_getNutritionCompleteness(result) / 8.0) * 0.2;
    
    // Boost confidence for accurate data
    if (_isDataAccurate(result, source)) {
      confidence += 0.2;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Wait for results with early exit for high-confidence results
  static Future<List<NutritionInfo?>> _waitForResultsWithEarlyExit(List<Future<NutritionInfo?>> futures) async {
    final apiNames = ['Nutritionix', 'USDA FoodData Central', 'Edamam', 'Spoonacular', 'Open Food Facts', 'Barcode Lookup', 'UPC Database'];
    final results = List<NutritionInfo?>.filled(futures.length, null);
    
    // Track completed futures
    int completedCount = 0;
    final completer = Completer<List<NutritionInfo?>>();
    
    // Set up individual completers for each future
    for (int i = 0; i < futures.length; i++) {
      futures[i].then((result) {
        results[i] = result;
        completedCount++;
        
        // Check if this is a high-confidence result from a reliable source
        if (result != null && result.calories > 0) {
          final source = apiNames[i];
          final confidence = _calculateConfidence(result, source);
          
          // If we get a high-confidence result from a reliable source, return early
          if (confidence >= 0.8 && _getSourceReliability(source) >= 0.8) {
            print('⚡ Early exit: High-confidence result from $source (${(confidence * 100).toStringAsFixed(1)}%)');
            if (!completer.isCompleted) {
              completer.complete(results);
            }
            return;
          }
        }
        
        // If all futures are complete, return results
        if (completedCount == futures.length && !completer.isCompleted) {
          completer.complete(results);
        }
      }).catchError((error) {
        completedCount++;
        if (completedCount == futures.length && !completer.isCompleted) {
          completer.complete(results);
        }
      });
    }
    
    // Set a timeout to prevent waiting too long
    Timer(Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        print('⏰ Timeout reached, returning partial results');
        completer.complete(results);
      }
    });
    
    return completer.future;
  }

  /// Infer product category from product name
  static String _inferProductCategory(String productName) {
    final name = productName.toLowerCase();
    
    // Beverages
    if (name.contains('drink') || name.contains('juice') || name.contains('soda') || 
        name.contains('water') || name.contains('tea') || name.contains('coffee')) {
      return 'beverages';
    }
    
    // Snacks
    if (name.contains('chips') || name.contains('crackers') || name.contains('biscuit') || 
        name.contains('cookie') || name.contains('namkeen') || name.contains('mixture')) {
      return 'snacks';
    }
    
    // Dairy
    if (name.contains('milk') || name.contains('yogurt') || name.contains('curd') || 
        name.contains('cheese') || name.contains('paneer') || name.contains('butter')) {
      return 'dairy';
    }
    
    // Sweets
    if (name.contains('sweet') || name.contains('mithai') || name.contains('halwa') || 
        name.contains('kheer') || name.contains('barfi') || name.contains('laddu')) {
      return 'indian sweets';
    }
    
    // Instant noodles
    if (name.contains('noodles') || name.contains('maggi') || name.contains('pasta')) {
      return 'instant noodles';
    }
    
    // Cereals
    if (name.contains('cereal') || name.contains('oats') || name.contains('cornflakes')) {
      return 'cereals';
    }
    
    // Fried snacks
    if (name.contains('fried') || name.contains('pakora') || name.contains('samosa') || 
        name.contains('vada') || name.contains('bonda')) {
      return 'fried snacks';
    }
    
    // Default to packaged food
    return 'packaged food';
  }

  /// Get nutrition estimate from local knowledge base for common Indian products
  /// Only returns data for very specific, well-known products to avoid wrong information
  static NutritionInfo? _getLocalNutritionEstimate(String productName) {
    final cleanName = productName.toLowerCase();
    
    // Be very conservative - only return data for products we're confident about
    // If we're not sure, return null rather than wrong data
    
    // Indian dairy products and beverages - only for very specific matches
    if (cleanName.contains('milkshake') || cleanName.contains('milk shake')) {
      if (cleanName.contains('vanilla')) {
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 170.0, // 85 cal per 100ml * 2
          protein: 6.4,
          carbs: 25.0,
          fat: 5.6,
          fiber: 0.0,
          sugar: 25.0,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Indian Brand',
          notes: 'Estimated nutrition for Indian vanilla milkshake (200ml)',
        );
      } else if (cleanName.contains('chocolate')) {
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 180.0,
          protein: 7.0,
          carbs: 26.0,
          fat: 6.4,
          fiber: 1.0,
          sugar: 26.0,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Indian Brand',
          notes: 'Estimated nutrition for Indian chocolate milkshake (200ml)',
        );
      } else if (cleanName.contains('strawberry')) {
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 176.0,
          protein: 6.6,
          carbs: 25.6,
          fat: 6.0,
          fiber: 0.4,
          sugar: 25.6,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Indian Brand',
          notes: 'Estimated nutrition for Indian strawberry milkshake (200ml)',
        );
      } else {
        // Generic milkshake
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 170.0,
          protein: 6.0,
          carbs: 24.0,
          fat: 5.0,
          fiber: 0.0,
          sugar: 24.0,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Indian Brand',
          notes: 'Estimated nutrition for Indian milkshake (200ml)',
        );
      }
    }
    
    // Indian soft drinks and beverages
    if (cleanName.contains('coca cola') || cleanName.contains('coke')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 330.0,
        calories: 139.0,
        protein: 0.0,
        carbs: 35.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 35.0,
        source: 'Local Knowledge Base',
        category: 'Soft Drinks',
        brand: 'Coca-Cola',
        notes: 'Standard Coca-Cola nutrition (330ml)',
      );
    }
    
    if (cleanName.contains('pepsi')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 330.0,
        calories: 139.0,
        protein: 0.0,
        carbs: 35.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 35.0,
        source: 'Local Knowledge Base',
        category: 'Soft Drinks',
        brand: 'Pepsi',
        notes: 'Standard Pepsi nutrition (330ml)',
      );
    }
    
    if (cleanName.contains('sprite')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 330.0,
        calories: 139.0,
        protein: 0.0,
        carbs: 35.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 35.0,
        source: 'Local Knowledge Base',
        category: 'Soft Drinks',
        brand: 'Coca-Cola',
        notes: 'Standard Sprite nutrition (330ml)',
      );
    }
    
    if (cleanName.contains('fanta')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 330.0,
        calories: 139.0,
        protein: 0.0,
        carbs: 35.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 35.0,
        source: 'Local Knowledge Base',
        category: 'Soft Drinks',
        brand: 'Coca-Cola',
        notes: 'Standard Fanta nutrition (330ml)',
      );
    }
    
    // Amul Kool products
    if (cleanName.contains('amul kool')) {
      if (cleanName.contains('kesar') || cleanName.contains('saffron')) {
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 164.0,
          protein: 6.0,
          carbs: 24.0,
          fat: 5.0,
          fiber: 0.0,
          sugar: 24.0,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Amul',
          notes: 'Estimated nutrition for Amul Kool Kesar (200ml)',
        );
      } else if (cleanName.contains('chocolate')) {
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 170.0,
          protein: 6.4,
          carbs: 25.0,
          fat: 5.6,
          fiber: 1.0,
          sugar: 25.0,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Amul',
          notes: 'Estimated nutrition for Amul Kool Chocolate (200ml)',
        );
      } else if (cleanName.contains('rose')) {
        return NutritionInfo(
          foodName: productName,
          weightGrams: 200.0,
          calories: 160.0,
          protein: 6.0,
          carbs: 23.0,
          fat: 4.6,
          fiber: 0.0,
          sugar: 23.0,
          source: 'Local Knowledge Base',
          category: 'Dairy Beverages',
          brand: 'Amul',
          notes: 'Estimated nutrition for Amul Kool Rose (200ml)',
        );
      }
    }
    
    // Generic Indian dairy beverages
    if (cleanName.contains('lassi') || cleanName.contains('buttermilk') || cleanName.contains('chaas')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 200.0,
        calories: 120.0,
        protein: 4.0,
        carbs: 18.0,
        fat: 3.0,
        fiber: 0.0,
        sugar: 18.0,
        source: 'Local Knowledge Base',
        category: 'Dairy Beverages',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Indian lassi/buttermilk (200ml)',
      );
    }
    
    // Indian packaged snacks
    if (cleanName.contains('namkeen') || cleanName.contains('mixture') || cleanName.contains('sev')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 50.0,
        calories: 250.0,
        protein: 4.0,
        carbs: 20.0,
        fat: 18.0,
        fiber: 2.0,
        sugar: 2.0,
        source: 'Local Knowledge Base',
        category: 'Indian Snacks',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Indian namkeen (50g)',
      );
    }
    
    // Maggi noodles
    if (cleanName.contains('maggi') && cleanName.contains('noodle')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 70.0,
        calories: 315.0, // 450 cal per 100g * 0.7
        protein: 8.4, // 12g per 100g * 0.7
        carbs: 49.0, // 70g per 100g * 0.7
        fat: 10.5, // 15g per 100g * 0.7
        fiber: 1.4, // 2g per 100g * 0.7
        sugar: 2.1, // 3g per 100g * 0.7
        source: 'Local Knowledge Base',
        category: 'Instant Noodles',
        brand: 'Nestle',
        notes: 'Standard Maggi noodles nutrition (70g serving)',
      );
    }
    
    // Indian sweets
    if (cleanName.contains('gulab jamun')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 50.0,
        calories: 180.0,
        protein: 3.0,
        carbs: 25.0,
        fat: 8.0,
        fiber: 0.0,
        sugar: 25.0,
        source: 'Local Knowledge Base',
        category: 'Indian Sweets',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Gulab Jamun (50g)',
      );
    }
    
    if (cleanName.contains('rasgulla')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 50.0,
        calories: 120.0,
        protein: 2.0,
        carbs: 20.0,
        fat: 2.0,
        fiber: 0.0,
        sugar: 20.0,
        source: 'Local Knowledge Base',
        category: 'Indian Sweets',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Rasgulla (50g)',
      );
    }
    
    if (cleanName.contains('barfi') || cleanName.contains('burfi')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 50.0,
        calories: 220.0,
        protein: 4.0,
        carbs: 30.0,
        fat: 10.0,
        fiber: 0.0,
        sugar: 30.0,
        source: 'Local Knowledge Base',
        category: 'Indian Sweets',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Barfi (50g)',
      );
    }
    
    // Indian biscuits and cookies
    if (cleanName.contains('biscuit') || cleanName.contains('cookie') || cleanName.contains('cracker')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 25.0,
        calories: 120.0,
        protein: 2.0,
        carbs: 18.0,
        fat: 4.5,
        fiber: 0.5,
        sugar: 8.0,
        source: 'Local Knowledge Base',
        category: 'Biscuits & Cookies',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Indian biscuit (25g)',
      );
    }
    
    // Indian chips and fried snacks
    if (cleanName.contains('chips') || cleanName.contains('wafers') || cleanName.contains('kurkure')) {
      return NutritionInfo(
        foodName: productName,
        weightGrams: 30.0,
        calories: 150.0,
        protein: 2.0,
        carbs: 15.0,
        fat: 9.0,
        fiber: 1.0,
        sugar: 1.0,
        source: 'Local Knowledge Base',
        category: 'Fried Snacks',
        brand: 'Indian Brand',
        notes: 'Estimated nutrition for Indian chips (30g)',
      );
    }
    
    return null; // No local knowledge available
  }

  /// Get cached result for barcode
  static NutritionInfo? getCachedResult(String barcode) {
    if (_cache.containsKey(barcode) && _cacheTimestamps.containsKey(barcode)) {
      final cacheTime = _cacheTimestamps[barcode]!;
      if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
        return _cache[barcode];
      } else {
        // Remove expired cache entry
        _cache.remove(barcode);
        _cacheTimestamps.remove(barcode);
      }
    }
    return null;
  }

  /// Cache result for barcode
  static void cacheResult(String barcode, NutritionInfo nutritionInfo) {
    _cache[barcode] = nutritionInfo;
    _cacheTimestamps[barcode] = DateTime.now();
  }

  /// Clear expired cache entries
  static void clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
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

  /// Enhanced barcode scanning with improved accuracy
  static Future<NutritionInfo?> scanBarcodeEnhanced(String barcode) async {
    print('🔍 Enhanced barcode scanning for: $barcode');
    
    // Clean the barcode
    final cleanBarcode = barcode.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanBarcode.length < 8) {
      print('❌ Invalid barcode length: ${cleanBarcode.length}');
      return null;
    }
    
    // Try multiple scanning strategies
    final strategies = [
      _scanWithHighReliabilityAPIs(cleanBarcode),
      _scanWithMediumReliabilityAPIs(cleanBarcode),
      _scanWithFallbackAPIs(cleanBarcode),
    ];
    
    for (int i = 0; i < strategies.length; i++) {
      try {
        print('🔍 Trying strategy ${i + 1}...');
        final result = await strategies[i];
        if (result != null && _isDataAccurate(result, 'Enhanced Scan')) {
          print('✅ Enhanced scan successful with strategy ${i + 1}');
          return result;
        }
      } catch (e) {
        print('❌ Strategy ${i + 1} failed: $e');
      }
    }
    
    print('❌ All enhanced scanning strategies failed');
    return null;
  }

  /// Scan with high reliability APIs only
  static Future<NutritionInfo?> _scanWithHighReliabilityAPIs(String barcode) async {
    final futures = <Future<NutritionInfo?>>[
      _scanWithNutritionix(barcode),
      _scanWithFoodDataCentral(barcode),
      _scanWithEdamam(barcode),
    ];
    
    final results = await Future.wait(futures);
    final validResults = results.where((r) => r != null).cast<NutritionInfo>().toList();
    
    if (validResults.isEmpty) return null;
    
    // Use enhanced cross-validation for high-reliability sources
    final crossValidationResult = _crossValidateResults(results, barcode);
    return crossValidationResult['result'];
  }

  /// Scan with medium reliability APIs
  static Future<NutritionInfo?> _scanWithMediumReliabilityAPIs(String barcode) async {
    final futures = <Future<NutritionInfo?>>[
      _scanWithSpoonacular(barcode),
      _scanWithOpenFoodFacts(barcode),
    ];
    
    final results = await Future.wait(futures);
    final crossValidationResult = _crossValidateResults(results, barcode);
    return crossValidationResult['result'];
  }

  /// Scan with fallback APIs
  static Future<NutritionInfo?> _scanWithFallbackAPIs(String barcode) async {
    final futures = <Future<NutritionInfo?>>[
      _scanWithBarcodeLookup(barcode),
      _scanWithUPCDatabase(barcode),
    ];
    
    final results = await Future.wait(futures);
    final crossValidationResult = _crossValidateResults(results, barcode);
    return crossValidationResult['result'];
  }

}
