import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/nutrition_info.dart';
import '../config/ai_config.dart';
import 'network_service.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

// TimeoutException is available from dart:async

/// Restructured barcode scanning service with improved reliability and coverage
/// 
/// Uses multiple FREE APIs for comprehensive food coverage:
/// 1. Open Food Facts - Free, no API key needed, 100k+ Indian products database
/// 2. Open Food Facts India - India-specific search with country filter (100k+ products)
/// 3. Advanced Search - Multiple search strategies for maximum coverage
/// 4. Local Indian Dataset - Pre-loaded Indian packaged foods database
/// 5. UPCitemdb - Free tier (100 requests/day), no API key needed
/// 6. GTINsearch - Free tier, no API key needed
/// 7. AI Fallback - OpenRouter API (if configured) for missing nutrition data
/// 
/// Coverage:
/// - Global products: Excellent via Open Food Facts (millions of products)
/// - Indian products: 100k+ products via Open Food Facts India database
/// - Advanced search: Multiple strategies to find products in 100k+ database
/// - Fallback chain: Multiple sources tried in parallel for speed
class BarcodeScanningService {
  // API Endpoints - All Free APIs (No API keys required)
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const String _openFoodFactsSearchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';
  static const String _upcItemDbBaseUrl = 'https://api.upcitemdb.com/prod/trial/lookup';
  static const String _gtinSearchBaseUrl = 'https://gtinsearch.org/api/v1';
  
  // Local datasets
  static List<Map<String, dynamic>>? _indianPackaged;
  static List<Map<String, dynamic>>? _indianFoods;
  static List<Map<String, dynamic>>? _comprehensiveIndianFoods;
  
  // Caching for faster responses
  static final Map<String, NutritionInfo> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 24);
  
  // Open Food Facts search parameters for maximum coverage
  static const int _maxSearchResults = 20; // Search up to 20 products for best match

  /// Initialize local datasets
  static Future<void> initialize() async {
    try {
      int totalProducts = 0;
      
      // Load Indian packaged foods dataset
      try {
        final indianPackagedString = await rootBundle.loadString('assets/indian_packaged.json');
        _indianPackaged = List<Map<String, dynamic>>.from(jsonDecode(indianPackagedString));
        totalProducts += _indianPackaged!.length;
        if (kDebugMode) debugPrint('✅ Loaded Indian packaged foods dataset: ${_indianPackaged!.length} products');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Indian packaged foods dataset not available: $e');
        _indianPackaged = [];
      }
      
      // Load Indian foods dataset (for name-based search)
      try {
        final indianFoodsString = await rootBundle.loadString('assets/indian_foods.json');
        _indianFoods = List<Map<String, dynamic>>.from(jsonDecode(indianFoodsString));
        totalProducts += _indianFoods!.length;
        if (kDebugMode) debugPrint('✅ Loaded Indian foods dataset: ${_indianFoods!.length} products');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Indian foods dataset not available: $e');
        _indianFoods = [];
      }
      
      // Load comprehensive Indian foods dataset
      try {
        final comprehensiveString = await rootBundle.loadString('assets/comprehensive_indian_foods.json');
        _comprehensiveIndianFoods = List<Map<String, dynamic>>.from(jsonDecode(comprehensiveString));
        totalProducts += _comprehensiveIndianFoods!.length;
        if (kDebugMode) debugPrint('✅ Loaded comprehensive Indian foods dataset: ${_comprehensiveIndianFoods!.length} products');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Comprehensive Indian foods dataset not available: $e');
        _comprehensiveIndianFoods = [];
      }
      
      // Add popular products to cache for faster access
      _addPopularProductsToCache();
      
      if (kDebugMode) debugPrint('✅ Barcode scanning service initialized');
      if (kDebugMode) debugPrint('📊 Total local products: $totalProducts');
      if (kDebugMode) debugPrint('📊 Cache size: ${_cache.length} products');
      if (kDebugMode) debugPrint('🌐 Using Open Food Facts for 100k+ Indian products coverage');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error initializing barcode scanning service: $e');
    }
  }

  /// Add popular global products to cache for faster access
  static void _addPopularProductsToCache() {
    final popularProducts = [
      // Beverages
      {
        'barcode': '5449000000996',
        'name': 'Coca-Cola Classic',
        'brand': 'Coca-Cola',
        'weight': 330.0,
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
        'calories': 0.0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'category': 'Beverages',
      },
      // Indian Products
      {
        'barcode': '8901030865958',
        'name': 'Maggi 2-Minute Noodles Masala',
        'brand': 'Maggi',
        'weight': 70.0,
        'calories': 329.0,
        'protein': 8.4,
        'carbs': 60.1,
        'fat': 7.0,
        'fiber': 3.0,
        'sugar': 4.0,
        'category': 'Instant Noodles',
      },
      {
        'barcode': '8901030865941',
        'name': 'Maggi 2-Minute Noodles Chicken',
        'brand': 'Maggi',
        'weight': 70.0,
        'calories': 329.0,
        'protein': 8.4,
        'carbs': 60.1,
        'fat': 7.0,
        'fiber': 3.0,
        'sugar': 4.0,
        'category': 'Instant Noodles',
      },
      {
        'barcode': '8901030865934',
        'name': 'Maggi 2-Minute Noodles Vegetable',
        'brand': 'Maggi',
        'weight': 70.0,
        'calories': 329.0,
        'protein': 8.4,
        'carbs': 60.1,
        'fat': 7.0,
        'fiber': 3.0,
        'sugar': 4.0,
        'category': 'Instant Noodles',
      },
    ];

    for (final product in popularProducts) {
      final barcode = product['barcode'] as String;
      final nutrition = NutritionInfo(
        foodName: product['name'] as String,
        weightGrams: product['weight'] as double,
        calories: product['calories'] as double,
        protein: product['protein'] as double,
        carbs: product['carbs'] as double,
        fat: product['fat'] as double,
        fiber: product['fiber'] as double,
        sugar: product['sugar'] as double,
        source: 'Popular Products Cache',
        category: product['category'] as String,
        brand: product['brand'] as String,
      );
      
      _cache[barcode] = nutrition;
      _cacheTimestamps[barcode] = DateTime.now();
    }
    
    if (kDebugMode) debugPrint('✅ Added ${popularProducts.length} popular products to cache');
  }

  /// Main barcode scanning method - restructured with better fallback chain
  static Future<NutritionInfo?> scanBarcode(String barcode) async {
    final stopwatch = Stopwatch()..start();
    final cleanBarcode = _cleanBarcode(barcode);
    
    try {
      if (kDebugMode) debugPrint('🔍 === BARCODE SCANNING STARTED ===');
      if (kDebugMode) debugPrint('📱 Barcode: $cleanBarcode (cleaned from: $barcode)');
      
      // Step 1: Check cache first (fastest path)
      final cachedResult = _getCachedResult(cleanBarcode);
      if (cachedResult != null) {
        if (kDebugMode) debugPrint('💾 Cache hit: ${cachedResult.foodName} (${stopwatch.elapsedMilliseconds}ms)');
        return cachedResult;
      }

      // Step 2: Try parallel lookups from multiple sources (fastest)
      // Open Food Facts has 100k+ Indian products, so we prioritize it
      if (kDebugMode) debugPrint('🚀 Starting parallel lookup from multiple sources...');
      if (kDebugMode) debugPrint('🌐 Using Open Food Facts (100k+ Indian products database)...');
      final parallelResults = await Future.wait([
        _tryOpenFoodFactsIndia(cleanBarcode),     // Indian products specifically (100k+ coverage)
        _tryOpenFoodFacts(cleanBarcode),           // Global products
        _tryLocalDataset(cleanBarcode),           // Local Indian dataset
        _tryOpenFoodFactsAdvancedSearch(cleanBarcode), // Advanced search with multiple strategies
      ], eagerError: false);

      final offIndiaResult = parallelResults[0];
      final offResult = parallelResults[1];
      final localResult = parallelResults[2];
      final advancedResult = parallelResults[3];

      if (kDebugMode) debugPrint('📊 Parallel lookup results:');
      if (kDebugMode) debugPrint('   - Open Food Facts (India): ${offIndiaResult != null ? "${offIndiaResult.foodName} (valid: ${offIndiaResult.isValid})" : "not found"}');
      if (kDebugMode) debugPrint('   - Open Food Facts (Global): ${offResult != null ? "${offResult.foodName} (valid: ${offResult.isValid})" : "not found"}');
      if (kDebugMode) debugPrint('   - Local Dataset: ${localResult != null ? "${localResult.foodName} (valid: ${localResult.isValid})" : "not found"}');
      if (kDebugMode) debugPrint('   - Advanced Search: ${advancedResult != null ? "${advancedResult.foodName} (valid: ${advancedResult.isValid})" : "not found"}');

      // Priority 1: Open Food Facts India (best for Indian products)
      if (offIndiaResult != null && offIndiaResult.isValid && offIndiaResult.calories > 0) {
        if (kDebugMode) debugPrint('✅ SUCCESS: Found in Open Food Facts (India)');
        return _cacheAndReturn(cleanBarcode, offIndiaResult);
      }

      // Priority 2: Open Food Facts Global (most complete nutrition data)
      if (offResult != null && offResult.isValid && offResult.calories > 0) {
        if (kDebugMode) debugPrint('✅ SUCCESS: Found in Open Food Facts (Global)');
        return _cacheAndReturn(cleanBarcode, offResult);
      }

      // Priority 3: Advanced search result
      if (advancedResult != null && advancedResult.isValid && advancedResult.calories > 0) {
        if (kDebugMode) debugPrint('✅ SUCCESS: Found via Advanced Search');
        return _cacheAndReturn(cleanBarcode, advancedResult);
      }

      // Priority 4: Local Indian dataset (fast, reliable for Indian products)
      if (localResult != null && localResult.isValid && localResult.calories > 0) {
        if (kDebugMode) debugPrint('✅ SUCCESS: Found in Local Indian Dataset');
        return _cacheAndReturn(cleanBarcode, localResult);
      }

      // Step 3: If Open Food Facts found product but missing nutrition, try AI
      final productWithName = offIndiaResult ?? offResult;
      if (productWithName != null && productWithName.foodName != 'Unknown Product' && 
          (productWithName.calories == 0 || !productWithName.isValid)) {
        if (kDebugMode) debugPrint('⚠️ Product found but missing nutrition data, trying AI...');
        final aiResult = await _tryAIForNutrition(productWithName.foodName, cleanBarcode);
        if (aiResult != null && aiResult.isValid && aiResult.calories > 0) {
          if (kDebugMode) debugPrint('✅ SUCCESS: AI provided nutrition data');
          return _cacheAndReturn(cleanBarcode, aiResult);
        }
      }

      // Step 4: Try alternative barcode databases (UPCitemdb, GTINsearch)
      if (kDebugMode) debugPrint('🔄 Trying alternative barcode databases...');
      final altDatabases = await Future.wait([
        _tryUPCItemDb(cleanBarcode),
        _tryGTINSearch(cleanBarcode),
      ], eagerError: false);

      final upcResult = altDatabases[0];
      final gtinResult = altDatabases[1];

      // Process UPCitemdb result
      if (upcResult != null && upcResult.foodName != 'Unknown Product') {
        if (kDebugMode) debugPrint('✅ Found product name in UPCitemdb: ${upcResult.foodName}');
        // Try to get nutrition data for this product
        final nutritionResult = await _getNutritionForProductName(upcResult.foodName, cleanBarcode);
        if (nutritionResult != null && nutritionResult.isValid && nutritionResult.calories > 0) {
          if (kDebugMode) debugPrint('✅ SUCCESS: Got nutrition data for UPCitemdb product');
          return _cacheAndReturn(cleanBarcode, nutritionResult);
        }
        // If no nutrition found, return basic product info
        if (upcResult.calories > 0 || upcResult.isValid) {
          return _cacheAndReturn(cleanBarcode, upcResult);
        }
      }

      // Process GTINsearch result
      if (gtinResult != null && gtinResult.foodName != 'Unknown Product') {
        if (kDebugMode) debugPrint('✅ Found product name in GTINsearch: ${gtinResult.foodName}');
        // Try to get nutrition data for this product
        final nutritionResult = await _getNutritionForProductName(gtinResult.foodName, cleanBarcode);
        if (nutritionResult != null && nutritionResult.isValid && nutritionResult.calories > 0) {
          if (kDebugMode) debugPrint('✅ SUCCESS: Got nutrition data for GTINsearch product');
          return _cacheAndReturn(cleanBarcode, nutritionResult);
        }
        // If no nutrition found, return basic product info
        if (gtinResult.calories > 0 || gtinResult.isValid) {
          return _cacheAndReturn(cleanBarcode, gtinResult);
        }
      }

      // Step 5: Final fallback - try AI directly with barcode
      if (NetworkService().isOnline && AIConfig.apiKey.isNotEmpty) {
        if (kDebugMode) debugPrint('🤖 Final fallback: Trying AI with barcode...');
        final aiResult = await _tryAIForNutrition('Barcode: $cleanBarcode', cleanBarcode);
        if (aiResult != null && aiResult.isValid && aiResult.calories > 0) {
          if (kDebugMode) debugPrint('✅ SUCCESS: AI provided nutrition data');
          return _cacheAndReturn(cleanBarcode, aiResult);
        }
      }

      if (kDebugMode) debugPrint('❌ No nutrition data found for barcode: $cleanBarcode');
      if (kDebugMode) debugPrint('⏱️ Total time: ${stopwatch.elapsedMilliseconds}ms');
      return null;

    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('❌ Error scanning barcode: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get nutrition data from product name (used as fallback)
  static Future<NutritionInfo?> getNutritionFromProductName(String productName) async {
    try {
      if (kDebugMode) debugPrint('🔍 Getting nutrition for product name: $productName');
      return await _getNutritionForProductName(productName, '');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting nutrition from product name: $e');
      return null;
    }
  }

  /// Get nutrition data for a product name (internal method)
  static Future<NutritionInfo?> _getNutritionForProductName(String productName, String barcode) async {
    final cleanName = _cleanProductName(productName);
    
    // Try multiple sources in parallel (prioritize Indian sources)
    final results = await Future.wait([
      _tryLocalDatasetByName(cleanName),           // Local Indian dataset
      _tryOpenFoodFactsByNameIndia(cleanName),    // Open Food Facts India search
      _tryOpenFoodFactsByName(cleanName),         // Open Food Facts global search
    ], eagerError: false);

    final localResult = results[0];
    final offIndiaResult = results[1];
    final offResult = results[2];

    // Priority 1: Local dataset (fastest, most reliable for Indian products)
    if (localResult != null && localResult.isValid && localResult.calories > 0) {
      if (kDebugMode) debugPrint('✅ Found in local dataset: ${localResult.foodName}');
      return localResult;
    }

    // Priority 2: Open Food Facts India search (better for Indian products)
    if (offIndiaResult != null && offIndiaResult.isValid && offIndiaResult.calories > 0) {
      if (kDebugMode) debugPrint('✅ Found in Open Food Facts (India): ${offIndiaResult.foodName}');
      return offIndiaResult;
    }

    // Priority 3: Open Food Facts global search
    if (offResult != null && offResult.isValid && offResult.calories > 0) {
      if (kDebugMode) debugPrint('✅ Found in Open Food Facts: ${offResult.foodName}');
      return offResult;
    }

    // Priority 4: Try AI
    if (NetworkService().isOnline && AIConfig.apiKey.isNotEmpty) {
      if (kDebugMode) debugPrint('🤖 Trying AI for product name: $productName');
      final aiResult = await _tryAIForNutrition(productName, barcode);
      if (aiResult != null && aiResult.isValid && aiResult.calories > 0) {
        if (kDebugMode) debugPrint('✅ AI provided nutrition data: ${aiResult.foodName}');
        return aiResult;
      }
    }

    return null;
  }

  // ==================== CACHE METHODS ====================

  /// Get cached result if available and valid
  static NutritionInfo? _getCachedResult(String barcode) {
    if (!_cache.containsKey(barcode) || !_cacheTimestamps.containsKey(barcode)) {
      return null;
    }

    final cachedResult = _cache[barcode]!;
    final cacheTime = _cacheTimestamps[barcode]!;
    
    if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
      if (cachedResult.isValid && cachedResult.calories > 0) {
        return cachedResult;
      } else {
        // Remove invalid cache entry
        _cache.remove(barcode);
        _cacheTimestamps.remove(barcode);
      }
    } else {
      // Remove expired cache entry
      _cache.remove(barcode);
      _cacheTimestamps.remove(barcode);
    }
    
    return null;
  }

  /// Cache and return result
  static NutritionInfo _cacheAndReturn(String barcode, NutritionInfo result) {
    _cache[barcode] = result;
    _cacheTimestamps[barcode] = DateTime.now();
    return result;
  }

  // ==================== DATA SOURCE METHODS ====================

  /// Try Open Food Facts API
  static Future<NutritionInfo?> _tryOpenFoodFacts(String barcode) async {
    try {
      final url = '$_openFoodFactsBaseUrl/$barcode.json';
      if (kDebugMode) debugPrint('📡 Calling Open Food Facts: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) debugPrint('⏱️ Open Food Facts timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['status'] == 1) {
          final product = data['product'] as Map<String, dynamic>?;
          if (product != null) {
            final nutrition = _parseOpenFoodFactsProduct(product);
            if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
              if (kDebugMode) debugPrint('✅ Open Food Facts: Found ${nutrition.foodName}');
              return nutrition;
            } else {
              if (kDebugMode) debugPrint('⚠️ Open Food Facts: Product found but invalid nutrition data');
              // Return basic product info even if nutrition is incomplete
              return _createBasicProductInfo(product, 'Open Food Facts');
            }
          }
        } else {
          if (kDebugMode) debugPrint('❌ Open Food Facts: Product not found (status: ${data['status']})');
        }
      } else {
        if (kDebugMode) debugPrint('❌ Open Food Facts: HTTP error ${response.statusCode}');
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ Open Food Facts: Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Open Food Facts: Error - $e');
    }
    return null;
  }

  /// Try Open Food Facts API with India filter (better for Indian products)
  static Future<NutritionInfo?> _tryOpenFoodFactsIndia(String barcode) async {
    try {
      // First try direct barcode lookup
      final url = '$_openFoodFactsBaseUrl/$barcode.json';
      if (kDebugMode) debugPrint('📡 Calling Open Food Facts (India): $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) debugPrint('⏱️ Open Food Facts (India) timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['status'] == 1) {
          final product = data['product'] as Map<String, dynamic>?;
          if (product != null) {
            // Check if product is from India
            final countries = product['countries_tags'] as List?;
            final countriesTags = product['countries_tags_en'] as List?;
            
            bool isIndianProduct = false;
            if (countries != null) {
              for (final country in countries) {
                if (country.toString().toLowerCase().contains('india') ||
                    country.toString().toLowerCase().contains('en:india')) {
                  isIndianProduct = true;
                  break;
                }
              }
            }
            if (!isIndianProduct && countriesTags != null) {
              for (final country in countriesTags) {
                if (country.toString().toLowerCase().contains('india')) {
                  isIndianProduct = true;
                  break;
                }
              }
            }
            
            // If it's an Indian product, parse it
            if (isIndianProduct || countries == null || countries.isEmpty) {
              // Also check product name for Indian keywords
              final productName = (product['product_name'] as String? ?? 
                                  product['product_name_en'] as String? ?? '').toLowerCase();
              final isLikelyIndian = productName.contains('india') ||
                                   productName.contains('indian') ||
                                   productName.contains('namkeen') ||
                                   productName.contains('biscuit') ||
                                   productName.contains('maggi') ||
                                   productName.contains('parle') ||
                                   productName.contains('britannia') ||
                                   productName.contains('haldiram') ||
                                   productName.contains('lays') ||
                                   productName.contains('kurkure');
              
              if (isIndianProduct || isLikelyIndian || countries == null || countries.isEmpty) {
                final nutrition = _parseOpenFoodFactsProduct(product);
                if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
                  if (kDebugMode) debugPrint('✅ Open Food Facts (India): Found ${nutrition.foodName}');
                  return nutrition;
                } else if (nutrition != null) {
                  if (kDebugMode) debugPrint('⚠️ Open Food Facts (India): Product found but invalid nutrition data');
                  return _createBasicProductInfo(product, 'Open Food Facts (India)');
                }
              }
            }
          }
        }
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ Open Food Facts (India): Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Open Food Facts (India): Error - $e');
    }
    return null;
  }

  /// Try local Indian packaged foods dataset
  static Future<NutritionInfo?> _tryLocalDataset(String barcode) async {
    try {
      if (_indianPackaged == null) {
        await initialize();
      }
      
      if (_indianPackaged == null || _indianPackaged!.isEmpty) {
        return null;
      }

      for (final product in _indianPackaged!) {
        if (product['barcode'] == barcode) {
          final caloriesPer100g = (product['calories_per_100g'] as num).toDouble();
          final servingSizeGrams = (product['serving_size_grams'] as num).toDouble();
          final totalCalories = (caloriesPer100g * servingSizeGrams) / 100;
          
          if (kDebugMode) debugPrint('✅ Local Dataset: Found ${product['name']}');
          
          return NutritionInfo(
            foodName: product['name'] as String,
            weightGrams: servingSizeGrams,
            calories: totalCalories,
            protein: (product['protein_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            carbs: (product['carbs_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            fat: (product['fat_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            fiber: (product['fiber_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            sugar: (product['sugar_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            source: 'Local Indian Dataset',
            category: product['category'] as String,
            brand: product['brand'] as String,
            notes: 'Indian product - ${servingSizeGrams}g serving',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Local Dataset: Error - $e');
    }
    return null;
  }

  /// Try local dataset by product name (fuzzy matching)
  static Future<NutritionInfo?> _tryLocalDatasetByName(String productName) async {
    try {
      if (_indianPackaged == null) {
        await initialize();
      }
      
      if (_indianPackaged == null || _indianPackaged!.isEmpty) {
        return null;
      }

      final cleanSearchName = productName.toLowerCase().trim();
      
      // Try exact match first
      for (final product in _indianPackaged!) {
        final productNameLower = (product['name'] as String).toLowerCase();
        if (productNameLower == cleanSearchName || 
            productNameLower.contains(cleanSearchName) ||
            cleanSearchName.contains(productNameLower)) {
          final caloriesPer100g = (product['calories_per_100g'] as num).toDouble();
          final servingSizeGrams = (product['serving_size_grams'] as num).toDouble();
          final totalCalories = (caloriesPer100g * servingSizeGrams) / 100;
          
          if (kDebugMode) debugPrint('✅ Local Dataset: Found ${product['name']} by name');
          
          return NutritionInfo(
            foodName: product['name'] as String,
            weightGrams: servingSizeGrams,
            calories: totalCalories,
            protein: (product['protein_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            carbs: (product['carbs_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            fat: (product['fat_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            fiber: (product['fiber_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            sugar: (product['sugar_per_100g'] as num).toDouble() * servingSizeGrams / 100,
            source: 'Local Indian Dataset',
            category: product['category'] as String,
            brand: product['brand'] as String,
            notes: 'Indian product - ${servingSizeGrams}g serving',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Local Dataset by name: Error - $e');
    }
    return null;
  }

  /// Try UPCitemdb API
  static Future<NutritionInfo?> _tryUPCItemDb(String barcode) async {
    try {
      final url = '$_upcItemDbBaseUrl?upc=$barcode';
      if (kDebugMode) debugPrint('📡 Calling UPCitemdb: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) debugPrint('⏱️ UPCitemdb timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List?;
        
        if (items != null && items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          final title = item['title'] as String? ?? item['description'] as String? ?? 'Unknown Product';
          final brand = item['brand'] as String?;
          final category = item['category'] as String?;
          
          if (title.isNotEmpty && title != 'Unknown Product') {
            if (kDebugMode) debugPrint('✅ UPCitemdb: Found $title');
            return NutritionInfo(
              foodName: title,
              weightGrams: 100.0,
              calories: 0.0, // Will be filled by AI or other sources
              protein: 0.0,
              carbs: 0.0,
              fat: 0.0,
              fiber: 0.0,
              sugar: 0.0,
              source: 'UPCitemdb',
              category: category ?? 'Unknown',
              brand: brand,
              notes: 'Product found in UPCitemdb. Fetching nutrition data...',
            );
          }
        }
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ UPCitemdb: Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ UPCitemdb: Error - $e');
    }
    return null;
  }

  /// Try GTINsearch API
  static Future<NutritionInfo?> _tryGTINSearch(String barcode) async {
    try {
      final url = '$_gtinSearchBaseUrl/$barcode';
      if (kDebugMode) debugPrint('📡 Calling GTINsearch: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) debugPrint('⏱️ GTINsearch timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final name = data['name'] as String?;
        
        if (name != null && name.isNotEmpty) {
          final brand = data['brand'] as String?;
          final category = data['category'] as String?;
          
          if (kDebugMode) debugPrint('✅ GTINsearch: Found $name');
          return NutritionInfo(
            foodName: name,
            weightGrams: 100.0,
            calories: 0.0, // Will be filled by AI or other sources
            protein: 0.0,
            carbs: 0.0,
            fat: 0.0,
            fiber: 0.0,
            sugar: 0.0,
            source: 'GTINsearch',
            category: category ?? 'Unknown',
            brand: brand,
            notes: 'Product found in GTINsearch. Fetching nutrition data...',
          );
        }
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ GTINsearch: Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ GTINsearch: Error - $e');
    }
    return null;
  }

  /// Try Open Food Facts by product name (India-specific search)
  /// Enhanced to search Open Food Facts' 100k+ Indian products database
  static Future<NutritionInfo?> _tryOpenFoodFactsByNameIndia(String productName) async {
    try {
      // Search with India filter for better relevance - increased page size for better coverage
      final indiaUrl = '$_openFoodFactsSearchUrl?search_terms=${Uri.encodeComponent(productName)}&search_simple=1&action=process&json=1&countries_tags_en=india&page_size=$_maxSearchResults';
      
      if (kDebugMode) debugPrint('📡 Calling Open Food Facts (India) search: $productName');
      
      final response = await http.get(
        Uri.parse(indiaUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Request timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List?;
        
        if (products != null && products.isNotEmpty) {
          // Try to find the best match
          for (final productData in products) {
            final product = productData as Map<String, dynamic>;
            final nutrition = _parseOpenFoodFactsProduct(product);
            if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
              if (kDebugMode) debugPrint('✅ Open Food Facts (India) search: Found ${nutrition.foodName}');
              return nutrition;
            }
          }
        }
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ Open Food Facts (India) search: Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Open Food Facts (India) search: Error - $e');
    }
    return null;
  }

  /// Advanced Open Food Facts search with multiple strategies for maximum coverage
  /// This searches Open Food Facts' 100k+ Indian products database using various methods
  static Future<NutritionInfo?> _tryOpenFoodFactsAdvancedSearch(String barcode) async {
    try {
      // Strategy 1: Search by barcode with India filter and multiple page sizes
      final searchStrategies = [
        // Direct barcode search with India filter (most specific)
        '$_openFoodFactsSearchUrl?code=$barcode&countries_tags_en=india&json=1&page_size=$_maxSearchResults',
        // Search by barcode prefix (for variations)
        if (barcode.length >= 8)
          '$_openFoodFactsSearchUrl?code=${barcode.substring(0, 8)}&countries_tags_en=india&json=1&page_size=$_maxSearchResults',
        // Search India products with high completeness
        '$_openFoodFactsSearchUrl?countries_tags_en=india&tagtype_0=packaging_codes&tag_contains_0=contains&tag_0=$barcode&json=1&page_size=$_maxSearchResults',
      ];

      for (final strategyUrl in searchStrategies) {
        try {
          if (kDebugMode) debugPrint('📡 Advanced search: Trying strategy...');
          final response = await http.get(
            Uri.parse(strategyUrl),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'CalorieVita/1.0',
            },
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Request timeout', const Duration(seconds: 5));
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final products = data['products'] as List?;
            
            if (products != null && products.isNotEmpty) {
              // Try all products to find best match
              for (final productData in products) {
                final product = productData as Map<String, dynamic>;
                
                // Check if barcode matches
                final productCode = product['code'] as String?;
                if (productCode == barcode) {
                  final nutrition = _parseOpenFoodFactsProduct(product);
                  if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
                    if (kDebugMode) debugPrint('✅ Advanced search: Found exact match ${nutrition.foodName}');
                    return nutrition;
                  }
                }
                
                // Also check for products with matching barcode in packaging codes
                final packagingCodes = product['packaging_codes'] as String?;
                if (packagingCodes != null && packagingCodes.contains(barcode)) {
                  final nutrition = _parseOpenFoodFactsProduct(product);
                  if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
                    if (kDebugMode) debugPrint('✅ Advanced search: Found match via packaging codes ${nutrition.foodName}');
                    return nutrition;
                  }
                }
              }
              
              // If no exact barcode match, try first product with valid nutrition
              for (final productData in products) {
                final product = productData as Map<String, dynamic>;
                final nutrition = _parseOpenFoodFactsProduct(product);
                if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
                  // Check if it's likely an Indian product
                  final countries = product['countries_tags'] as List?;
                  final countriesTags = product['countries_tags_en'] as List?;
                  bool isIndian = false;
                  
                  if (countries != null) {
                    for (final country in countries) {
                      if (country.toString().toLowerCase().contains('india')) {
                        isIndian = true;
                        break;
                      }
                    }
                  }
                  
                  if (isIndian || countriesTags == null || countriesTags.isEmpty) {
                    if (kDebugMode) debugPrint('✅ Advanced search: Found Indian product ${nutrition.foodName}');
                    return nutrition;
                  }
                }
              }
            }
          }
        } on TimeoutException {
          // Continue to next strategy on timeout
          continue;
        } catch (e) {
          // Continue to next strategy on other errors
          continue;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Advanced search: Error - $e');
    }
    return null;
  }

  /// Try Open Food Facts by product name (global search)
  /// Enhanced to search more products for better coverage
  static Future<NutritionInfo?> _tryOpenFoodFactsByName(String productName) async {
    try {
      // Global search without country filter - increased page size for better coverage
      final globalUrl = '$_openFoodFactsSearchUrl?search_terms=${Uri.encodeComponent(productName)}&search_simple=1&action=process&json=1&page_size=$_maxSearchResults';
      
      if (kDebugMode) debugPrint('📡 Calling Open Food Facts (Global) search: $productName');
      
      final response = await http.get(
        Uri.parse(globalUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Request timeout', const Duration(seconds: 5));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List?;
        
        if (products != null && products.isNotEmpty) {
          // Try to find the best match
          for (final productData in products) {
            final product = productData as Map<String, dynamic>;
            final nutrition = _parseOpenFoodFactsProduct(product);
            if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
              if (kDebugMode) debugPrint('✅ Open Food Facts (Global) search: Found ${nutrition.foodName}');
              return nutrition;
            }
          }
        }
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ Open Food Facts (Global) search: Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Open Food Facts (Global) search: Error - $e');
    }
    return null;
  }

  /// Try AI for nutrition data
  static Future<NutritionInfo?> _tryAIForNutrition(String productName, String barcode) async {
    try {
      if (!NetworkService().isOnline) {
        if (kDebugMode) debugPrint('❌ AI: Network offline');
        return null;
      }

      if (AIConfig.apiKey.isEmpty) {
        if (kDebugMode) debugPrint('❌ AI: API key not configured');
        return null;
      }

      if (kDebugMode) debugPrint('🤖 Calling AI for: $productName');
      
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
              'content': '''You are a certified fitness nutritionist with EXPERT knowledge of Indian food products. Provide ACCURATE and REALISTIC nutritional information for the given product.

CRITICAL REQUIREMENTS:
- Use REAL nutritional data from actual food products, not generic estimates
- PRIORITIZE Indian products - use authentic Indian food nutrition values
- For Indian products: Consider typical cooking methods (oil/ghee usage), spices, and regional variations
- Calories must be accurate (check: protein×4 + carbs×4 + fat×9 should approximately equal total calories)
- Values must be realistic for the product type
- Provide values per 100g serving unless specified otherwise
- For Indian packaged foods: Use actual product nutrition labels when available

Return ONLY valid JSON (no markdown, no extra text):
{
  "food": "Exact product name",
  "calories": <accurate number per 100g>,
  "protein": "<number>g",
  "carbs": "<number>g", 
  "fat": "<number>g",
  "fiber": "<number>g",
  "sugar": "<number>g",
  "serving_size": "100g or actual serving size",
  "confidence": <0.0-1.0 based on certainty>
}

VERIFY: Total calories = (protein × 4) + (carbs × 4) + (fat × 9) ± 10%
Be accurate - wrong nutrition data can mislead users!''',
            },
            {
              'role': 'user',
              'content': 'Provide nutritional information for: $productName${barcode.isNotEmpty ? ' (barcode: $barcode)' : ''}',
            },
          ],
          'max_tokens': AIConfig.maxTokens,
          'temperature': AIConfig.temperature,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) debugPrint('⏱️ AI: Timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 10));
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content'] as String? ?? '';
        
        // Parse JSON from response
        try {
          String cleanedContent = content.trim();
          cleanedContent = cleanedContent.replaceAll('```json', '').replaceAll('```', '').trim();
          
          final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedContent);
          if (jsonMatch != null) {
            final jsonStr = jsonMatch.group(0)!.trim();
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
            
            final calories = _parseNumber(parsed['calories']);
            final protein = _parseMacro(parsed['protein']);
            final carbs = _parseMacro(parsed['carbs']);
            final fat = _parseMacro(parsed['fat']);
            final fiber = _parseMacro(parsed['fiber']);
            final sugar = _parseMacro(parsed['sugar']);
            
            if (calories != null && calories > 0) {
              if (kDebugMode) debugPrint('✅ AI: Provided nutrition data for ${parsed['food']}');
              return NutritionInfo(
                foodName: (parsed['food'] ?? productName).toString(),
                weightGrams: 100.0,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                sugar: sugar,
                source: 'AI Analysis',
                category: 'Unknown',
                brand: null,
                notes: 'AI analysis - confidence: ${((parsed['confidence'] ?? 0.7) * 100).toStringAsFixed(0)}%',
              );
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ AI: Failed to parse JSON response - $e');
        }
      } else {
        if (kDebugMode) debugPrint('❌ AI: HTTP error ${response.statusCode}');
      }
    } on TimeoutException {
      if (kDebugMode) debugPrint('⏱️ AI: Timeout');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ AI: Error - $e');
    }
    return null;
  }

  // ==================== PARSING METHODS ====================

  /// Parse Open Food Facts product data with accurate calorie calculation
  static NutritionInfo? _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    try {
      final productName = product['product_name'] as String? ?? 
                         product['product_name_en'] as String? ?? 
                         'Unknown Product';
      
      final brand = product['brands'] as String? ?? product['brand'] as String?;
      final categories = product['categories'] as String?;
      final quantity = product['quantity'] as String?;
      
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
      
      // Get calories per 100g
      double caloriesPer100g = 0.0;
      final energyKcal100g = _parseNutrient(nutriments, 'energy-kcal_100g');
      final energy100g = _parseNutrient(nutriments, 'energy_100g');
      final energy100gUnit = nutriments['energy_100g_unit'] as String? ?? 'kcal';
      
      if (energyKcal100g != null) {
        caloriesPer100g = energyKcal100g;
      } else if (energy100g != null) {
        if (energy100gUnit.toLowerCase() == 'kj' || energy100gUnit.toLowerCase() == 'kilojoule') {
          caloriesPer100g = energy100g / 4.184;
        } else {
          caloriesPer100g = energy100g;
        }
      }
      
      // Get other nutrients per 100g
      final proteinPer100g = _parseNutrient(nutriments, 'proteins_100g') ?? 0.0;
      final carbsPer100g = _parseNutrient(nutriments, 'carbohydrates_100g') ?? 0.0;
      final fatPer100g = _parseNutrient(nutriments, 'fat_100g') ?? 0.0;
      final fiberPer100g = _parseNutrient(nutriments, 'fiber_100g') ?? 0.0;
      final sugarPer100g = _parseNutrient(nutriments, 'sugars_100g') ?? 0.0;
      
      // Determine serving size
      final servingSizeGrams = _parseNutrient(nutriments, 'serving_size') ?? 0.0;
      final productSize = _determineProductSize(product, quantity);
      final detectedWeight = productSize['weight'] as double;
      final detectedVolume = productSize['volume'] as double;
      final isLiquid = productSize['isLiquid'] as bool;
      
      double finalWeight = 0.0;
      if (servingSizeGrams > 0) {
        finalWeight = servingSizeGrams;
      } else if (detectedWeight > 0) {
        finalWeight = detectedWeight;
      } else if (isLiquid && detectedVolume > 0) {
        finalWeight = detectedVolume;
      } else {
        finalWeight = 100.0; // Default to 100g
      }
      
      // Calculate total calories for the serving size
      double finalCalories = 0.0;
      if (caloriesPer100g > 0 && finalWeight > 0) {
        finalCalories = (caloriesPer100g * finalWeight) / 100;
      } else {
        // Try to get serving calories directly
        final energyKcal = _parseNutrient(nutriments, 'energy-kcal');
        final energy = _parseNutrient(nutriments, 'energy');
        final energyUnit = nutriments['energy_unit'] as String? ?? 'kcal';
        
        if (energyKcal != null) {
          finalCalories = energyKcal;
        } else if (energy != null) {
          if (energyUnit.toLowerCase() == 'kj' || energyUnit.toLowerCase() == 'kilojoule') {
            finalCalories = energy / 4.184;
          } else {
            finalCalories = energy;
          }
        }
      }
      
      // Calculate nutrients for serving size
      double finalProtein = 0.0;
      double finalCarbs = 0.0;
      double finalFat = 0.0;
      double finalFiber = 0.0;
      double finalSugar = 0.0;
      
      if (finalWeight > 0) {
        finalProtein = (proteinPer100g * finalWeight) / 100;
        finalCarbs = (carbsPer100g * finalWeight) / 100;
        finalFat = (fatPer100g * finalWeight) / 100;
        finalFiber = (fiberPer100g * finalWeight) / 100;
        finalSugar = (sugarPer100g * finalWeight) / 100;
      }
      
      // Validate data
      if (finalCalories == 0 && finalProtein == 0 && finalCarbs == 0 && finalFat == 0) {
        if (kDebugMode) debugPrint('⚠️ Open Food Facts: No nutrition data available');
        return null;
      }
      
      // If calories are missing but macros exist, calculate calories
      if (finalCalories == 0 && (finalProtein > 0 || finalCarbs > 0 || finalFat > 0)) {
        finalCalories = (finalProtein * 4) + (finalCarbs * 4) + (finalFat * 9);
        if (kDebugMode) debugPrint('🔧 Calculated calories from macros: $finalCalories kcal');
      }
      
      // Create display name
      String displayName = productName;
      if (brand != null && brand.isNotEmpty && !displayName.toLowerCase().contains(brand.toLowerCase())) {
        displayName = '$brand $displayName';
      }
      
      final sizeInfo = productSize['display'] as String? ?? '';
      if (sizeInfo.isNotEmpty) {
        displayName = '$displayName ($sizeInfo)';
      }
      
      if (kDebugMode) debugPrint('✅ Parsed Open Food Facts: $displayName');
      if (kDebugMode) debugPrint('   Size: ${finalWeight}g, Calories: ${finalCalories.toStringAsFixed(0)} kcal');
      if (kDebugMode) debugPrint('   Macros: P${finalProtein.toStringAsFixed(1)}g C${finalCarbs.toStringAsFixed(1)}g F${finalFat.toStringAsFixed(1)}g');
      
      return NutritionInfo(
        foodName: displayName,
        weightGrams: finalWeight,
        calories: finalCalories,
        protein: finalProtein,
        carbs: finalCarbs,
        fat: finalFat,
        fiber: finalFiber,
        sugar: finalSugar,
        source: 'Open Food Facts',
        category: categories?.split(',').first.trim() ?? 'Unknown',
        brand: brand,
        notes: 'Size: ${finalWeight}g',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error parsing Open Food Facts product: $e');
      return null;
    }
  }

  /// Create basic product info from Open Food Facts product (when nutrition is incomplete)
  static NutritionInfo? _createBasicProductInfo(Map<String, dynamic> product, String source) {
    try {
      final productName = product['product_name'] as String? ?? 
                         product['product_name_en'] as String? ?? 
                         'Unknown Product';
      
      final brand = product['brands'] as String? ?? product['brand'] as String?;
      final categories = product['categories'] as String?;
      
      String displayName = productName;
      if (brand != null && brand.isNotEmpty) {
        displayName = '$brand $displayName';
      }
      
      return NutritionInfo(
        foodName: displayName,
        weightGrams: 100.0,
        calories: 0.0, // Will be filled by AI
        protein: 0.0,
        carbs: 0.0,
        fat: 0.0,
        fiber: 0.0,
        sugar: 0.0,
        source: source,
        category: categories?.split(',').first.trim() ?? 'Unknown',
        brand: brand,
        notes: 'Product found but nutrition data incomplete. Fetching nutrition data...',
      );
    } catch (e) {
      return null;
    }
  }

  // ==================== HELPER METHODS ====================

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

  /// Determine product size with enhanced detection
  static Map<String, dynamic> _determineProductSize(Map<String, dynamic> product, String? quantity) {
    final quantityInfo = quantity ?? '';
    final productName = (product['product_name'] as String? ?? '').toLowerCase();
    final categories = (product['categories'] as String? ?? '').toLowerCase();
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    
    // Check if product is liquid
    final isLiquid = _isLiquidProduct(productName, categories, quantityInfo);
    
    double weight = 0.0;
    double volume = 0.0;
    String display = '';
    
    // Priority 1: Check serving_size from nutriments
    final servingSize = _parseNutrient(nutriments, 'serving_size') ?? 0.0;
    if (servingSize > 0) {
      if (isLiquid) {
        volume = servingSize;
        weight = servingSize;
        display = '${servingSize.toStringAsFixed(0)}ml';
      } else {
        weight = servingSize;
        display = '${servingSize.toStringAsFixed(0)}g';
      }
      return {
        'weight': weight,
        'volume': volume,
        'isLiquid': isLiquid,
        'display': display,
      };
    }
    
    // Priority 2: Extract from quantity field
    if (quantityInfo.isNotEmpty) {
      final extracted = _extractWeightAndUnits(quantityInfo);
      weight = extracted['weight'] as double;
      volume = extracted['volume'] as double;
      display = extracted['display'] as String;
      
      if (weight > 0 || volume > 0) {
        return {
          'weight': weight,
          'volume': volume,
          'isLiquid': isLiquid,
          'display': display,
        };
      }
    }
    
    // Priority 3: Extract from product name
    final nameSize = _extractSizeFromText(productName);
    if (nameSize['weight'] > 0 || nameSize['volume'] > 0) {
      weight = nameSize['weight'] as double;
      volume = nameSize['volume'] as double;
      display = nameSize['display'] as String;
      
      return {
        'weight': weight,
        'volume': volume,
        'isLiquid': isLiquid,
        'display': display,
      };
    }
    
    // No size found
    return {
      'weight': 0.0,
      'volume': 0.0,
      'isLiquid': isLiquid,
      'display': 'Size unknown',
    };
  }

  /// Check if product is liquid
  static bool _isLiquidProduct(String productName, String categories, String quantity) {
    final liquidKeywords = [
      'drink', 'beverage', 'juice', 'soda', 'water', 'milk', 'tea', 'coffee',
      'beer', 'wine', 'spirit', 'liquor', 'syrup', 'sauce', 'oil', 'vinegar',
      'ml', 'liter', 'litre', 'pint', 'quart', 'gallon', 'fluid'
    ];
    
    final textToCheck = '$productName $categories $quantity'.toLowerCase();
    
    for (final keyword in liquidKeywords) {
      if (textToCheck.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }

  /// Extract size information from text
  static Map<String, dynamic> _extractSizeFromText(String text) {
    final patterns = [
      // Weight patterns
      RegExp(r'(\d+(?:\.\d+)?)\s*(g|gram|grams|kg|kilogram|kilograms|oz|ounce|ounces|lb|pound|pounds)'),
      // Volume patterns
      RegExp(r'(\d+(?:\.\d+)?)\s*(ml|milliliter|milliliters|l|liter|litre|liters|litres|fl\s*oz|fluid\s*ounce|pint|pints|quart|quarts|gallon|gallons)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.toLowerCase());
      if (match != null) {
        final amount = double.tryParse(match.group(1)!) ?? 0.0;
        final unit = match.group(2)!.toLowerCase();
        
        double weight = 0.0;
        double volume = 0.0;
        String display = '';
        
        // Convert to standard units
        switch (unit) {
          case 'g':
          case 'gram':
          case 'grams':
            weight = amount;
            display = '${amount.toStringAsFixed(0)}g';
            break;
          case 'kg':
          case 'kilogram':
          case 'kilograms':
            weight = amount * 1000;
            display = '${amount.toStringAsFixed(1)}kg';
            break;
          case 'oz':
          case 'ounce':
          case 'ounces':
            weight = amount * 28.35;
            display = '${amount.toStringAsFixed(0)}oz';
            break;
          case 'lb':
          case 'pound':
          case 'pounds':
            weight = amount * 453.59;
            display = '${amount.toStringAsFixed(1)}lb';
            break;
          case 'ml':
          case 'milliliter':
          case 'milliliters':
            volume = amount;
            weight = amount;
            display = '${amount.toStringAsFixed(0)}ml';
            break;
          case 'l':
          case 'liter':
          case 'litre':
          case 'liters':
          case 'litres':
            volume = amount * 1000;
            weight = amount * 1000;
            display = '${amount.toStringAsFixed(1)}L';
            break;
          case 'fl oz':
          case 'fluid ounce':
          case 'fluid ounces':
            volume = amount * 29.57;
            weight = amount * 29.57;
            display = '${amount.toStringAsFixed(0)}fl oz';
            break;
          case 'pint':
          case 'pints':
            volume = amount * 473.18;
            weight = amount * 473.18;
            display = '${amount.toStringAsFixed(0)}pt';
            break;
          case 'quart':
          case 'quarts':
            volume = amount * 946.35;
            weight = amount * 946.35;
            display = '${amount.toStringAsFixed(0)}qt';
            break;
          case 'gallon':
          case 'gallons':
            volume = amount * 3785.41;
            weight = amount * 3785.41;
            display = '${amount.toStringAsFixed(1)}gal';
            break;
        }
        
        if (weight > 0 || volume > 0) {
          return {
            'weight': weight,
            'volume': volume,
            'display': display,
          };
        }
      }
    }
    
    return {
      'weight': 0.0,
      'volume': 0.0,
      'display': '',
    };
  }

  /// Extract weight and units from string
  static Map<String, dynamic> _extractWeightAndUnits(String text) {
    final extracted = _extractSizeFromText(text);
    if ((extracted['weight'] as double) > 0 || (extracted['volume'] as double) > 0) {
      return extracted;
    }
    
    // Fallback to simple pattern
    final weightPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(g|kg|ml|l|oz|lb)');
    final match = weightPattern.firstMatch(text.toLowerCase());
    
    if (match != null) {
      final weight = double.tryParse(match.group(1)!) ?? 0.0;
      final unit = match.group(2)!;
      
      double weightInGrams = weight;
      double volumeInMl = 0.0;
      
      switch (unit) {
        case 'kg':
          weightInGrams = weight * 1000;
          break;
        case 'ml':
          weightInGrams = weight;
          volumeInMl = weight;
          break;
        case 'l':
          weightInGrams = weight * 1000;
          volumeInMl = weight * 1000;
          break;
        case 'oz':
          weightInGrams = weight * 28.35;
          break;
        case 'lb':
          weightInGrams = weight * 453.59;
          break;
      }
      
      return {
        'weight': weightInGrams,
        'volume': volumeInMl,
        'display': '$weight $unit',
      };
    }
    
    return {
      'weight': 0.0,
      'volume': 0.0,
      'display': '',
    };
  }

  /// Validate and fix nutrition info (if needed)
  static NutritionInfo _validateAndFixNutritionInfo(NutritionInfo nutrition) {
    // If nutrition is already valid, return as-is
    if (nutrition.isValid && nutrition.calories > 0) {
      return nutrition;
    }
    
    // If calories are missing but macros exist, calculate calories
    if (nutrition.calories == 0 && (nutrition.protein > 0 || nutrition.carbs > 0 || nutrition.fat > 0)) {
      final calculatedCalories = (nutrition.protein * 4) + (nutrition.carbs * 4) + (nutrition.fat * 9);
      if (calculatedCalories > 0) {
        return nutrition.copyWith(calories: calculatedCalories);
      }
    }
    
    return nutrition;
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    if (kDebugMode) debugPrint('🧹 Barcode cache cleared');
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedResults': _cache.length,
      'cacheTimestamps': _cacheTimestamps.length,
    };
  }
}

