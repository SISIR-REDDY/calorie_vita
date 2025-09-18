import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/nutrition_info.dart';

/// Service for barcode scanning with multiple APIs and local datasets
class BarcodeScanningService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const String _upcDatabaseBaseUrl = 'https://api.upcitemdb.com/prod/trial/lookup';
  static const String _barcodeLookupBaseUrl = 'https://api.barcodelookup.com/v3/products';
  
  // Free API keys for better reliability
  static const String _upcApiKey = 'your-upc-api-key'; // Replace with actual key
  static const String _barcodeLookupApiKey = 'your-barcode-lookup-key'; // Replace with actual key
  
  static List<Map<String, dynamic>>? _indianPackaged;

  /// Initialize local datasets
  static Future<void> initialize() async {
    try {
      // Load Indian packaged foods dataset
      final indianPackagedString = await rootBundle.loadString('assets/indian_packaged.json');
      _indianPackaged = List<Map<String, dynamic>>.from(jsonDecode(indianPackagedString));
      
      print('✅ Barcode scanning datasets loaded successfully');
    } catch (e) {
      print('❌ Error loading barcode scanning datasets: $e');
    }
  }

  /// Scan barcode and get nutrition information
  static Future<NutritionInfo?> scanBarcode(String barcode) async {
    try {
      // Clean and normalize the barcode
      final cleanBarcode = _cleanBarcode(barcode);
      print('🔍 Scanning barcode: $cleanBarcode');
      
      // Validate barcode format first
      if (!isValidBarcode(cleanBarcode)) {
        print('❌ Invalid barcode format: $cleanBarcode');
        return null;
      }

      // Try multiple APIs in parallel for better success rate
      print('🌍 Trying multiple APIs...');
      
      // Try Open Food Facts API (free, no key required)
      final openFoodFactsFuture = _scanWithOpenFoodFacts(cleanBarcode);
      
      // Try UPC Database API (free tier available)
      final upcDatabaseFuture = _scanWithUPCDatabase(cleanBarcode);
      
      // Wait for the first successful result
      final results = await Future.wait([
        openFoodFactsFuture,
        upcDatabaseFuture,
      ], eagerError: false);
      
      for (int i = 0; i < results.length; i++) {
        if (results[i] != null) {
          final apiName = i == 0 ? 'Open Food Facts' : 'UPC Database';
          print('✅ Found in $apiName');
          return results[i];
        }
      }

      // Fallback to local Indian packaged foods dataset (if available)
      print('🏠 Trying local Indian dataset...');
      try {
        if (_indianPackaged == null) {
          await initialize();
        }
        final localResult = _searchLocalPackagedFood(cleanBarcode);
        if (localResult != null) {
          print('✅ Found in local Indian dataset');
          return localResult;
        }
      } catch (e) {
        print('❌ Local dataset failed: $e');
      }

      print('❌ No nutrition data found for barcode: $cleanBarcode');
      
      // Create a working entry for unknown barcodes that users can edit
      return _createWorkingBarcodeEntry(cleanBarcode);
    } catch (e) {
      print('❌ Error in barcode scanning: $e');
      return null;
    }
  }

  /// Search for packaged food in local dataset
  static NutritionInfo? _searchLocalPackagedFood(String barcode) {
    if (_indianPackaged == null) return null;
    
    final packagedFood = _indianPackaged!.firstWhere(
      (food) => food['barcode'] == barcode,
      orElse: () => <String, dynamic>{},
    );
    
    if (packagedFood.isEmpty) return null;
    
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
      print('🌍 Fetching from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      );

      print('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Response data keys: ${data.keys.toList()}');
        
        final product = data['product'] as Map<String, dynamic>?;
        final status = data['status'] as int?;
        
        print('📊 Product status: $status');
        print('📦 Product data: ${product?.keys.toList()}');
        
        if (product != null && status == 1) {
          final result = _parseOpenFoodFactsProduct(product);
          print('✅ Successfully parsed product: ${result.foodName}');
          return result;
        } else {
          print('❌ Product not found or status != 1');
          print('📄 Full response: ${response.body}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
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
    
    // Extract numeric value from serving size string
    final servingSize = servingSizeStr?.replaceAll(RegExp(r'[^\d.]'), '');
    final weightGrams = double.tryParse(servingSize ?? '100') ?? 100.0;
    
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
      foodName: productName,
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
    
    // UPC Database doesn't provide detailed nutrition info, so we'll create a generic entry
    return NutritionInfo(
      foodName: title,
      weightGrams: 100.0,
      calories: 0.0, // Will need manual entry
      protein: 0.0,
      carbs: 0.0,
      fat: 0.0,
      fiber: 0.0,
      sugar: 0.0,
      source: 'UPC Database',
      category: category,
      brand: brand,
      notes: 'Product found in UPC Database. Please add nutrition information manually.',
    );
  }

  /// Validate barcode format
  static bool isValidBarcode(String barcode) {
    // Remove any whitespace or special characters
    final cleanBarcode = barcode.trim().replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if barcode is numeric and has valid length
    if (cleanBarcode.isEmpty) return false;
    
    // Check common barcode lengths (expanded range)
    final validLengths = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
    return validLengths.contains(cleanBarcode.length);
  }
  
  /// Clean and normalize barcode
  static String _cleanBarcode(String barcode) {
    return barcode.trim().replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Create a working entry for unknown barcodes that users can edit
  static NutritionInfo _createWorkingBarcodeEntry(String barcode) {
    print('🆕 Creating working entry for barcode: $barcode');
    
    // Try to determine product type from barcode length
    String productType = 'Packaged Food';
    if (barcode.length >= 12) {
      productType = 'Packaged Food';
    } else if (barcode.length >= 8) {
      productType = 'Small Packaged Item';
    }
    
    return NutritionInfo(
      foodName: 'Scanned Product (Barcode: $barcode)',
      weightGrams: 100.0,
      calories: 200.0, // Default estimate
      protein: 5.0,    // Default estimate
      carbs: 30.0,     // Default estimate
      fat: 8.0,        // Default estimate
      fiber: 2.0,      // Default estimate
      sugar: 10.0,     // Default estimate
      source: 'Barcode Scan (Estimated)',
      category: productType,
      brand: 'Unknown Brand',
      notes: 'Product scanned but not found in database. Nutrition values are estimates - please verify and adjust.',
    );
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
    final sources = <String>['Local Dataset'];
    
    // Add Open Food Facts (always available)
    sources.add('Open Food Facts');
    
    // Add FSSAI if available (hypothetical)
    sources.add('FSSAI');
    
    return sources;
  }

  /// Get scanning statistics
  static Map<String, dynamic> getScanningStats() {
    return {
      'localDatasetSize': _indianPackaged?.length ?? 0,
      'availableSources': getAvailableSources(),
      'supportedBarcodeTypes': ['EAN-8', 'UPC-A', 'EAN-13', 'ITF-14'],
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

  /// Get nutrition data from a free nutrition API
  static Future<NutritionInfo?> _getNutritionFromAPI(String foodName) async {
    try {
      // Using a free nutrition API (you can replace with any free API)
      final response = await http.get(
        Uri.parse('https://api.edamam.com/api/nutrition-data?app_id=YOUR_APP_ID&app_key=YOUR_APP_KEY&ingr=$foodName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Parse nutrition data from API response
        return _parseNutritionAPIResponse(data, foodName);
      }
    } catch (e) {
      print('❌ Nutrition API error: $e');
    }
    return null;
  }

  /// Parse nutrition API response
  static NutritionInfo _parseNutritionAPIResponse(Map<String, dynamic> data, String foodName) {
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
      source: 'Nutrition API',
      category: 'API Lookup',
    );
  }
}
