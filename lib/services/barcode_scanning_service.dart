import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import '../models/nutrition_info.dart';
import '../config/ai_config.dart';

// TimeoutException is available from dart:async

/// Clean barcode scanning service using only free APIs
class BarcodeScanningService {
  static const String _openFoodFactsBaseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const String _upcItemDbBaseUrl = 'https://api.upcitemdb.com/prod/trial/lookup';
  static const String _gtinSearchBaseUrl = 'https://gtinsearch.org/api/v1';
  static const String _mealDbBaseUrl = 'https://www.themealdb.com/api/json/v1/1';
  
  static List<Map<String, dynamic>>? _indianPackaged;
  static final Map<String, NutritionInfo> _cache = {}; // Cache for faster responses
  static final Map<String, DateTime> _cacheTimestamps = {}; // Cache timestamps
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
    // Expanded popular global products with their barcodes and nutrition info
    final popularProducts = [
      // Beverages
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
      // Indian Products
      {
        'barcode': '8901030865958',
        'name': 'Maggi 2-Minute Noodles Masala',
        'brand': 'Maggi',
        'weight': 70.0,
        'units': 'g',
        'calories': 329.0,
        'protein': 8.4,
        'carbs': 60.1,
        'fat': 7.0,
        'fiber': 3.0,
        'sugar': 4.0,
        'category': 'Instant Noodles',
      },
      {
        'barcode': '8901030865965',
        'name': 'Good Day Butter Cookies',
        'brand': 'Britannia',
        'weight': 100.0,
        'units': 'g',
        'calories': 472.0,
        'protein': 6.9,
        'carbs': 69.0,
        'fat': 19.0,
        'fiber': 2.0,
        'sugar': 22.0,
        'category': 'Biscuits & Cookies',
      },
      {
        'barcode': '8901030865972',
        'name': 'Parle-G Original Glucose Biscuits',
        'brand': 'Parle',
        'weight': 100.0,
        'units': 'g',
        'calories': 456.0,
        'protein': 7.5,
        'carbs': 75.0,
        'fat': 14.5,
        'fiber': 1.5,
        'sugar': 18.0,
        'category': 'Biscuits & Cookies',
      },
      // Common Dairy
      {
        'barcode': '1234567890123',
        'name': 'Milk Full Fat',
        'brand': 'Generic',
        'weight': 250.0,
        'units': 'ml',
        'calories': 150.0,
        'protein': 8.0,
        'carbs': 12.0,
        'fat': 8.0,
        'fiber': 0.0,
        'sugar': 12.0,
        'category': 'Dairy',
      },
      // Common Bread
      {
        'barcode': '2345678901234',
        'name': 'White Bread',
        'brand': 'Generic',
        'weight': 100.0,
        'units': 'g',
        'calories': 265.0,
        'protein': 9.0,
        'carbs': 49.0,
        'fat': 3.2,
        'fiber': 2.7,
        'sugar': 5.0,
        'category': 'Bakery',
      },
      // Rice
      {
        'barcode': '3456789012345',
        'name': 'Basmati Rice',
        'brand': 'Generic',
        'weight': 100.0,
        'units': 'g',
        'calories': 345.0,
        'protein': 7.1,
        'carbs': 78.0,
        'fat': 0.9,
        'fiber': 1.3,
        'sugar': 0.1,
        'category': 'Grains',
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

  /// Scan barcode and get nutrition information (optimized with parallel lookups)
  static Future<NutritionInfo?> scanBarcode(String barcode) async {
    // Clean and normalize the barcode (moved outside try block for catch block access)
    final cleanBarcode = _cleanBarcode(barcode);
    try {
      print('🔍 === BARCODE SCANNING STARTED ===');
      print('📱 Barcode: $cleanBarcode (cleaned from: $barcode)');
      
      // Check cache first (fastest path)
      if (_cache.containsKey(cleanBarcode)) {
        final cachedResult = _cache[cleanBarcode]!;
        final cacheTime = _cacheTimestamps[cleanBarcode]!;
        
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          print('💾 Cache hit for barcode: $cleanBarcode');
          // Validate cached result before returning
          if (cachedResult.isValid && cachedResult.calories > 0) {
            return cachedResult;
          } else {
            // Remove invalid cache entry
            _cache.remove(cleanBarcode);
            _cacheTimestamps.remove(cleanBarcode);
          }
        } else {
          // Remove expired cache entry
          _cache.remove(cleanBarcode);
          _cacheTimestamps.remove(cleanBarcode);
        }
      }

      // Try multiple sources in parallel for speed (Open Food Facts + Local Dataset)
      print('🚀 Starting parallel lookup: Open Food Facts + Local Dataset');
      print('   - Open Food Facts URL: $_openFoodFactsBaseUrl/$cleanBarcode.json');
      print('   - Local dataset loaded: ${_indianPackaged != null}');
      
      // Initialize local dataset if needed (non-blocking check)
      if (_indianPackaged == null) {
        print('⚙️ Local dataset not loaded, initializing...');
        initialize().catchError((e) => print('⚠️ Local dataset init error: $e'));
      }
      
      // Parallel API calls with reduced timeouts for speed
      final results = await Future.wait([
        _scanWithOpenFoodFacts(cleanBarcode).timeout(
          const Duration(seconds: 2), // Reduced from 3 to 2 seconds
          onTimeout: () {
            print('⏱️ Open Food Facts timeout');
            return null;
          },
        ),
        Future.microtask(() {
          if (_indianPackaged == null) return null;
          return _searchLocalPackagedFood(cleanBarcode);
        }).timeout(
          const Duration(milliseconds: 50), // Reduced from 100ms to 50ms
          onTimeout: () => null,
        ),
      ], eagerError: false);

      final openFoodFactsResult = results[0];
      final localResult = results[1];
      
      print('📊 Parallel lookup results:');
      print('   - Open Food Facts: ${openFoodFactsResult != null ? "${openFoodFactsResult.foodName} (valid: ${openFoodFactsResult.isValid})" : "not found"}');
      print('   - Local Dataset: ${localResult != null ? "${localResult.foodName} (valid: ${localResult.isValid})" : "not found"}');

      // Prioritize Open Food Facts (more complete data)
      if (openFoodFactsResult != null && openFoodFactsResult.isValid) {
        print('✅ SUCCESS: Found in Open Food Facts');
        print('   - Product: ${openFoodFactsResult.foodName}');
        print('   - Calories: ${openFoodFactsResult.calories}');
        print('   - Macros: P${openFoodFactsResult.protein}g C${openFoodFactsResult.carbs}g F${openFoodFactsResult.fat}g');
        print('   - Weight: ${openFoodFactsResult.weightGrams}g');
        // Only validate once - don't modify correct values
        final validatedResult = _validateAndFixNutritionInfo(openFoodFactsResult);
        _cache[cleanBarcode] = validatedResult;
        _cacheTimestamps[cleanBarcode] = DateTime.now();
        return validatedResult;
      }

      // Fallback to local dataset
      if (localResult != null && localResult.isValid) {
        print('✅ SUCCESS: Found in local Indian dataset');
        print('   - Product: ${localResult.foodName}');
        print('   - Calories: ${localResult.calories}');
        print('   - Macros: P${localResult.protein}g C${localResult.carbs}g F${localResult.fat}g');
        print('   - Weight: ${localResult.weightGrams}g');
        // Only validate once - don't modify correct values
        final validatedResult = _validateAndFixNutritionInfo(localResult);
        _cache[cleanBarcode] = validatedResult;
        _cacheTimestamps[cleanBarcode] = DateTime.now();
        return validatedResult;
      }

      // If Open Food Facts failed, try alternative database (UPCitemdb) with shorter timeout
      if (openFoodFactsResult == null) {
        print('🔄 Open Food Facts failed, trying alternative database (UPCitemdb)...');
        final upcItemDbResult = await _scanWithUPCItemDb(cleanBarcode).timeout(
          const Duration(seconds: 2), // Reduced from 3 to 2 seconds
          onTimeout: () {
            print('⏱️ UPCitemdb timeout');
            return null;
          },
        );
        
        if (upcItemDbResult != null) {
          print('✅ Found product info in UPCitemdb: ${upcItemDbResult.foodName}');
          
          // UPCitemdb only provides product name, so try to get nutrition data
          // Try AI lookup ONLY if calories are truly 0 (not just low - low-calorie foods are valid)
          if (upcItemDbResult.source == 'UPCitemdb' && upcItemDbResult.calories == 0) {
            // First, try searching local Indian dataset by product name
            print('🔍 Searching local Indian dataset for: ${upcItemDbResult.foodName}');
            final localSearchResult = _searchLocalDatasetByName(upcItemDbResult.foodName);
            if (localSearchResult != null && localSearchResult.isValid) {
              print('✅ Found in local Indian dataset: ${localSearchResult.foodName}');
              final validatedResult = _validateAndFixNutritionInfo(localSearchResult);
              _cache[cleanBarcode] = validatedResult;
              _cacheTimestamps[cleanBarcode] = DateTime.now();
              return validatedResult;
            }
            
            // Try TheMealDB for Indian dish names (skip if not urgent - speed optimization)
            // Skip TheMealDB for now - it's slow and rarely provides nutrition data
            // print('🔍 Trying TheMealDB for: ${upcItemDbResult.foodName}');
            // final mealDbResult = await _searchTheMealDb(upcItemDbResult.foodName).timeout(
            //   const Duration(seconds: 1),
            //   onTimeout: () => null,
            // );
            final mealDbResult = null; // Skip for speed
            
            if (mealDbResult != null) {
              // If TheMealDB found an Indian dish, try to get nutrition from local dataset
              print('✅ Found Indian dish in TheMealDB: ${mealDbResult.foodName}');
              final localMealResult = _searchLocalDatasetByName(mealDbResult.foodName);
              
              if (localMealResult != null && localMealResult.isValid) {
                print('✅ Found nutrition data in local dataset for: ${localMealResult.foodName}');
                final validatedResult = _validateAndFixNutritionInfo(localMealResult);
                _cache[cleanBarcode] = validatedResult;
                _cacheTimestamps[cleanBarcode] = DateTime.now();
                return validatedResult;
              }
              
              // If local dataset doesn't have it, return TheMealDB result (estimated)
              final validatedResult = _validateAndFixNutritionInfo(mealDbResult);
              _cache[cleanBarcode] = validatedResult;
              _cacheTimestamps[cleanBarcode] = DateTime.now();
              return validatedResult;
            }
            
            // If not found locally or in TheMealDB, try AI
            print('🤖 Attempting to get nutrition data via AI for: ${upcItemDbResult.foodName}');
            final aiResult = await _getNutritionFromOpenRouter(
              upcItemDbResult.foodName,
              cleanBarcode,
            ).timeout(const Duration(seconds: 5), onTimeout: () => null);
            
            if (aiResult != null && aiResult.isValid) {
              print('✅ Got nutrition data via AI for UPCitemdb product');
              final validatedResult = _validateAndFixNutritionInfo(aiResult);
              _cache[cleanBarcode] = validatedResult;
              _cacheTimestamps[cleanBarcode] = DateTime.now();
              return validatedResult;
            }
          }
          
          // If AI failed or result is valid, return the UPCitemdb result
          final validatedResult = _validateAndFixNutritionInfo(upcItemDbResult);
          _cache[cleanBarcode] = validatedResult;
          _cacheTimestamps[cleanBarcode] = DateTime.now();
          return validatedResult;
        }

        // If UPCitemdb also failed, try GTINsearch with shorter timeout
        if (upcItemDbResult == null) {
          print('🔄 UPCitemdb failed, trying GTINsearch...');
          final gtinSearchResult = await _scanWithGTINSearch(cleanBarcode).timeout(
            const Duration(seconds: 2), // Reduced from 3 to 2 seconds
            onTimeout: () {
              print('⏱️ GTINsearch timeout');
              return null;
            },
          );
          
          if (gtinSearchResult != null) {
            print('✅ Found product info in GTINsearch: ${gtinSearchResult.foodName}');
            
            // GTINsearch only provides product name, so try to get nutrition data
            // Try AI lookup ONLY if calories are truly 0 (not just low)
            if (gtinSearchResult.source == 'GTINsearch' && gtinSearchResult.calories == 0) {
              // First, try searching local Indian dataset by product name
              print('🔍 Searching local Indian dataset for: ${gtinSearchResult.foodName}');
              final localSearchResult = _searchLocalDatasetByName(gtinSearchResult.foodName);
              if (localSearchResult != null && localSearchResult.isValid) {
                print('✅ Found in local Indian dataset: ${localSearchResult.foodName}');
                final validatedResult = _validateAndFixNutritionInfo(localSearchResult);
                _cache[cleanBarcode] = validatedResult;
                _cacheTimestamps[cleanBarcode] = DateTime.now();
                return validatedResult;
              }
              
              // Skip TheMealDB for speed - it's slow and rarely provides nutrition data
              final mealDbResult = null;
              
              if (mealDbResult != null) {
                // If TheMealDB found an Indian dish, try to get nutrition from local dataset
                print('✅ Found Indian dish in TheMealDB: ${mealDbResult.foodName}');
                final localMealResult = _searchLocalDatasetByName(mealDbResult.foodName);
                
                if (localMealResult != null && localMealResult.isValid) {
                  print('✅ Found nutrition data in local dataset for: ${localMealResult.foodName}');
                  final validatedResult = _validateAndFixNutritionInfo(localMealResult);
                  _cache[cleanBarcode] = validatedResult;
                  _cacheTimestamps[cleanBarcode] = DateTime.now();
                  return validatedResult;
                }
                
                // If local dataset doesn't have it, return TheMealDB result (estimated)
                final validatedResult = _validateAndFixNutritionInfo(mealDbResult);
                _cache[cleanBarcode] = validatedResult;
                _cacheTimestamps[cleanBarcode] = DateTime.now();
                return validatedResult;
              }
              
              // If not found locally or in TheMealDB, try AI with shorter timeout
              print('🤖 Attempting to get nutrition data via AI for: ${gtinSearchResult.foodName}');
              final aiResult = await _getNutritionFromOpenRouter(
                gtinSearchResult.foodName,
                cleanBarcode,
              ).timeout(const Duration(seconds: 3), onTimeout: () => null); // Reduced from 5s to 3s
              
              if (aiResult != null && aiResult.isValid) {
                print('✅ Got nutrition data via AI for GTINsearch product');
                final validatedResult = _validateAndFixNutritionInfo(aiResult);
                _cache[cleanBarcode] = validatedResult;
                _cacheTimestamps[cleanBarcode] = DateTime.now();
                return validatedResult;
              }
            }
            
            // If AI failed or result is valid, return the GTINsearch result
            final validatedResult = _validateAndFixNutritionInfo(gtinSearchResult);
            _cache[cleanBarcode] = validatedResult;
            _cacheTimestamps[cleanBarcode] = DateTime.now();
            return validatedResult;
          }
        }
      }

      // If Open Food Facts found product but data is invalid, try AI to fix it
      if (openFoodFactsResult != null && !openFoodFactsResult.isValid && 
          openFoodFactsResult.foodName != 'Unknown Product') {
        print('⚠️ Product found but invalid data, trying AI fix...');
        final aiResult = await _getNutritionFromOpenRouter(
          openFoodFactsResult.foodName, 
          cleanBarcode,
        ).timeout(const Duration(seconds: 5), onTimeout: () => null);
        
        if (aiResult != null && aiResult.isValid) {
          print('✅ Fixed via AI: ${aiResult.foodName}');
          _cache[cleanBarcode] = aiResult;
          _cacheTimestamps[cleanBarcode] = DateTime.now();
          return aiResult;
        }
      }

      // Try common product pattern matching as fallback
      print('🔍 Trying common product pattern matching...');
      final patternResult = _tryCommonProductPatterns(cleanBarcode);
      if (patternResult != null) {
        print('✅ Found via pattern matching: ${patternResult.foodName}');
        _cache[cleanBarcode] = patternResult;
        _cacheTimestamps[cleanBarcode] = DateTime.now();
        return patternResult;
      }

      // Final fallback: Try AI to estimate nutrition based on barcode (skip for speed)
      // Skip final AI fallback - too slow and often inaccurate
      // print('🤖 All databases failed, trying AI fallback for barcode: $cleanBarcode');
      // AI fallback code removed - too slow and often inaccurate
      // try {
      //   final aiResult = await _getNutritionFromOpenRouter(
      //     'Barcode: $cleanBarcode',
      //     cleanBarcode,
      //   ).timeout(const Duration(seconds: 3), onTimeout: () => null);
      //   if (aiResult != null && aiResult.isValid) {
      //     print('✅ AI provided nutrition data for barcode: ${aiResult.foodName}');
      //     _cache[cleanBarcode] = aiResult;
      //     _cacheTimestamps[cleanBarcode] = DateTime.now();
      //     return aiResult;
      //   }
      // } catch (e) {
      //   print('⚠️ AI fallback failed: $e');
      // }

      // If everything fails, return fallback with estimated values
      print('❌ No valid nutrition data found for barcode: $cleanBarcode');
      print('💡 Returning estimated values as fallback');
      final fallbackResult = _createFallbackNutritionInfo(cleanBarcode);
      if (fallbackResult != null) {
        print('🆘 Returning fallback nutrition data');
        return fallbackResult;
      }

      print('💡 Suggestion: Try manual entry or scan again under better lighting');
      return null;

    } catch (e) {
      print('❌ Error scanning barcode: $e');
      // Try to provide a helpful fallback even on error
      final fallbackResult = _createFallbackNutritionInfo(cleanBarcode);
      if (fallbackResult != null) {
        print('🆘 Returning fallback nutrition data');
        return fallbackResult;
      }
      return null;
    }
  }

  /// Try to match common product patterns when exact lookup fails
  static NutritionInfo? _tryCommonProductPatterns(String barcode) {
    // Common barcode prefix patterns for different product types
    final patterns = {
      // Indian dairy products (common prefix patterns)
      '890103': {
        'name': 'Dairy Product',
        'calories': 60.0,
        'protein': 3.2,
        'carbs': 4.8,
        'fat': 3.2,
        'category': 'Dairy',
        'weight': 100.0,
      },
      // Common biscuit patterns
      '890102': {
        'name': 'Biscuits',
        'calories': 450.0,
        'protein': 7.0,
        'carbs': 70.0,
        'fat': 16.0,
        'category': 'Biscuits & Cookies',
        'weight': 100.0,
      },
      // Beverage patterns
      '544900': {
        'name': 'Carbonated Beverage',
        'calories': 42.0,
        'protein': 0.0,
        'carbs': 10.6,
        'fat': 0.0,
        'category': 'Beverages',
        'weight': 100.0,
      },
    };

    for (final prefix in patterns.keys) {
      if (barcode.startsWith(prefix)) {
        final pattern = patterns[prefix]!;
        return NutritionInfo(
          foodName: pattern['name'] as String,
          weightGrams: pattern['weight'] as double,
          calories: pattern['calories'] as double,
          protein: pattern['protein'] as double,
          carbs: pattern['carbs'] as double,
          fat: pattern['fat'] as double,
          fiber: 2.0,
          sugar: (pattern['carbs'] as double) * 0.3, // Estimate 30% of carbs as sugar
          source: 'Pattern Matching (Estimated)',
          category: pattern['category'] as String,
          notes: 'Estimated values based on product category. Please verify.',
        );
      }
    }
    return null;
  }

  /// Create fallback nutrition info when all else fails
  static NutritionInfo? _createFallbackNutritionInfo(String barcode) {
    // Only provide fallback for valid-looking barcodes
    if (barcode.length >= 8) {
      return NutritionInfo(
        foodName: 'Unknown Product',
        weightGrams: 100.0,
        calories: 200.0,
        protein: 5.0,
        carbs: 30.0,
        fat: 8.0,
        fiber: 2.0,
        sugar: 10.0,
        source: 'Fallback Estimate',
        category: 'Unknown',
        notes: 'Estimated values - please verify and update manually. Barcode: $barcode',
      );
    }
    return null;
  }
  
  /// Validate and fix nutrition info if needed (conservative - only fix if clearly missing)
  static NutritionInfo _validateAndFixNutritionInfo(NutritionInfo info) {
    // Only fix if data is clearly missing, not if it's just low
    
    // If calories are zero but macros exist, calculate calories
    // Only do this if calories are truly 0 (not just low)
    if (info.calories == 0 && (info.protein > 0 || info.carbs > 0 || info.fat > 0)) {
      final calculatedCalories = (info.protein * 4) + (info.carbs * 4) + (info.fat * 9);
      if (calculatedCalories > 0) {
        print('🔧 Fixed missing calories from macros: $calculatedCalories kcal');
        print('   Original values: P${info.protein}g C${info.carbs}g F${info.fat}g');
        return info.copyWith(calories: calculatedCalories);
      }
    }
    
    // If all macros are zero but calories exist, estimate macros
    // Only do this if ALL macros are truly 0 (not just low)
    if (info.calories > 0 && info.protein == 0 && info.carbs == 0 && info.fat == 0) {
      // Use standard ratios: 20% protein, 55% carbs, 25% fat
      final protein = (info.calories * 0.20 / 4);
      final carbs = (info.calories * 0.55 / 4);
      final fat = (info.calories * 0.25 / 9);
      print('🔧 Estimated macros from calories (all macros were 0)');
      print('   Calories: ${info.calories}, Estimated: P${protein.toStringAsFixed(1)}g C${carbs.toStringAsFixed(1)}g F${fat.toStringAsFixed(1)}g');
      return info.copyWith(
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
    }
    
    // Sanity check: Verify calories match macros if both exist
    if (info.calories > 0 && (info.protein > 0 || info.carbs > 0 || info.fat > 0)) {
      final calculatedCalories = (info.protein * 4) + (info.carbs * 4) + (info.fat * 9);
      if (calculatedCalories > 0) {
        final difference = (info.calories - calculatedCalories).abs();
        final percentDiff = (difference / info.calories) * 100;
        
        // If difference is > 50%, log warning but don't auto-fix (might be correct for special cases)
        if (percentDiff > 50) {
          print('⚠️ Large calorie mismatch: Reported ${info.calories.toStringAsFixed(0)} kcal, Calculated ${calculatedCalories.toStringAsFixed(0)} kcal (${percentDiff.toStringAsFixed(1)}% diff)');
          print('   Product: ${info.foodName}, Source: ${info.source}');
          print('   Keeping reported values - may be correct for this product type');
        }
      }
    }
    
    // Don't modify if data looks valid
    return info;
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

      // Try AI fallback with shorter timeout for speed
      print('🤖 Trying AI analysis...');
      final aiResult = await _getNutritionFromOpenRouter(cleanName, '').timeout(const Duration(seconds: 3), onTimeout: () => null);
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

  /// Search for packaged food in local dataset with accurate calorie calculation
  static NutritionInfo? _searchLocalPackagedFood(String barcode) {
    if (_indianPackaged == null) return null;
    
    for (final product in _indianPackaged!) {
      if (product['barcode'] == barcode) {
        final caloriesPer100g = (product['calories_per_100g'] as num).toDouble();
        final servingSizeGrams = (product['serving_size_grams'] as num).toDouble();
        
        // Calculate total calories for the entire product
        final totalCalories = (caloriesPer100g * servingSizeGrams) / 100;
        
        print('📦 Local product: ${product['name']}');
        print('📏 Serving size: ${servingSizeGrams}g');
        print('🔥 Calories per 100g: $caloriesPer100g');
        print('🔥 Total calories: ${totalCalories.toStringAsFixed(0)} kcal');
        
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
          notes: 'Indian product - ${servingSizeGrams}g serving (${totalCalories.toStringAsFixed(0)} kcal total)',
        );
      }
    }
    return null;
  }

  /// Search local Indian dataset by product name (fuzzy matching)
  /// This helps when we get product name from UPCitemdb/GTINsearch but no barcode match
  static NutritionInfo? _searchLocalDatasetByName(String productName) {
    if (_indianPackaged == null) return null;
    
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
        
        print('📦 Local match found: ${product['name']}');
        
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
          notes: 'Indian product - ${servingSizeGrams}g serving (${totalCalories.toStringAsFixed(0)} kcal total)',
        );
      }
    }
    
    return null;
  }

  /// Scan barcode using Open Food Facts API (optimized with timeout)
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
      ).timeout(
        const Duration(seconds: 2), // Reduced from 3 to 2 seconds for speed
        onTimeout: () {
          print('⏱️ Open Food Facts request timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 2));
        },
      );

      print('📡 Open Food Facts response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('📦 Open Food Facts response: ${data.keys.toList()}');
        
        if (data['status'] == 1) {
          final product = data['product'] as Map<String, dynamic>?;
          if (product != null) {
            final nutrition = _parseOpenFoodFactsProduct(product);
            // Validate the parsed data
            if (nutrition != null && nutrition.isValid && nutrition.calories > 0) {
              return nutrition;
            } else {
              print('⚠️ Invalid nutrition data from Open Food Facts');
              return null;
            }
          }
        } else {
          print('❌ Product not found in Open Food Facts (status: ${data['status']})');
        }
      } else {
        print('❌ Open Food Facts API error: ${response.statusCode}');
      }
    } on TimeoutException {
      print('⏱️ Open Food Facts timeout');
      return null;
    } catch (e) {
      print('❌ Open Food Facts API error: $e');
    }
    return null;
  }

  /// Scan barcode using UPCitemdb API (fallback when Open Food Facts fails)
  /// Free tier: 100 requests/day (no signup required)
  static Future<NutritionInfo?> _scanWithUPCItemDb(String barcode) async {
    try {
      final url = '$_upcItemDbBaseUrl?upc=$barcode';
      print('📡 Calling UPCitemdb: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 2), // Reduced from 3 to 2 seconds
        onTimeout: () {
          print('⏱️ UPCitemdb request timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 2));
        },
      );

      print('📡 UPCitemdb response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('📦 UPCitemdb response: ${data.keys.toList()}');
        
        final code = data['code'] as String?;
        final items = data['items'] as List?;
        
        // Check if we have items regardless of code (some responses might have different codes)
        if (items != null && items.isNotEmpty) {
          final item = items.first as Map<String, dynamic>;
          final title = item['title'] as String? ?? item['description'] as String? ?? 'Unknown Product';
          final brand = item['brand'] as String?;
          final category = item['category'] as String?;
          
          // Only proceed if we have a valid product name
          if (title.isNotEmpty && title != 'Unknown Product') {
            // UPCitemdb doesn't provide nutrition data, but we can use the product name
            // and try to get nutrition from Open Router AI
            print('✅ UPCitemdb found product: $title (code: $code)');
            
            // Return basic product info - nutrition will be estimated or fetched via AI
            return NutritionInfo(
              foodName: title,
              weightGrams: 100.0,
              calories: 0.0, // Set to 0 to trigger AI lookup (calories <= 200 check)
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
          } else {
            print('⚠️ UPCitemdb returned empty or invalid product name');
          }
        } else {
          print('❌ Product not found in UPCitemdb (code: $code, items: ${items?.length ?? 0})');
        }
      } else {
        print('❌ UPCitemdb API error: ${response.statusCode}');
      }
    } on TimeoutException {
      print('⏱️ UPCitemdb timeout');
      return null;
    } catch (e) {
      print('❌ UPCitemdb API error: $e');
    }
    return null;
  }

  /// Search TheMealDB for Indian dishes by name (completely free, no API key)
  /// This helps identify Indian dishes when we get product names from UPCitemdb/GTINsearch
  static Future<NutritionInfo?> _searchTheMealDb(String productName) async {
    try {
      // Search by meal name
      final searchUrl = '$_mealDbBaseUrl/search.php?s=${Uri.encodeComponent(productName)}';
      print('📡 Calling TheMealDB: $searchUrl');
      
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('⏱️ TheMealDB request timeout');
          throw TimeoutException('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final meals = data['meals'] as List?;
        
        if (meals != null && meals.isNotEmpty) {
          final meal = meals.first as Map<String, dynamic>;
          final mealName = meal['strMeal'] as String? ?? productName;
          final category = meal['strCategory'] as String? ?? 'Indian';
          final area = meal['strArea'] as String? ?? '';
          
          // Check if it's Indian cuisine
          if (area.toLowerCase().contains('indian') || 
              category.toLowerCase().contains('indian') ||
              mealName.toLowerCase().contains('curry') ||
              mealName.toLowerCase().contains('dal') ||
              mealName.toLowerCase().contains('biryani') ||
              mealName.toLowerCase().contains('dosa') ||
              mealName.toLowerCase().contains('roti') ||
              mealName.toLowerCase().contains('idli') ||
              mealName.toLowerCase().contains('samosa')) {
            
            print('📦 TheMealDB found Indian dish: $mealName');
            
            // TheMealDB doesn't provide nutrition data, but we can use the dish name
            // to search our local Indian dataset or estimate based on common Indian dishes
            // Return basic info - AI or local dataset will provide actual nutrition
            return NutritionInfo(
              foodName: mealName,
              weightGrams: 200.0, // Default serving size for Indian dishes
              calories: 250.0, // Estimated average
              protein: 8.0,
              carbs: 35.0,
              fat: 8.0,
              fiber: 3.0,
              sugar: 5.0,
              source: 'TheMealDB',
              category: category,
              brand: null,
              notes: 'Indian dish identified from TheMealDB. Nutrition estimated - please verify.',
            );
          }
        }
      }
    } on TimeoutException {
      print('⏱️ TheMealDB timeout');
      return null;
    } catch (e) {
      print('❌ TheMealDB API error: $e');
    }
    return null;
  }

  /// Scan barcode using GTINsearch API (fallback when UPCitemdb also fails)
  /// Free tier: 100 requests/day (no signup required)
  static Future<NutritionInfo?> _scanWithGTINSearch(String barcode) async {
    try {
      final url = '$_gtinSearchBaseUrl/gtin/$barcode';
      print('📡 Calling GTINsearch: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'CalorieVita/1.0',
        },
      ).timeout(
        const Duration(seconds: 2), // Reduced from 3 to 2 seconds
        onTimeout: () {
          print('⏱️ GTINsearch request timeout');
          throw TimeoutException('Request timeout', const Duration(seconds: 2));
        },
      );

      print('📡 GTINsearch response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('📦 GTINsearch response: ${data.keys.toList()}');
        
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          final brand = data['brand'] as String?;
          final category = data['category'] as String?;
          
          print('📦 GTINsearch found product: $name');
          
          // GTINsearch provides basic product info
          // Return basic product info - nutrition will be estimated or fetched via AI
          return NutritionInfo(
            foodName: name,
            weightGrams: 100.0,
            calories: 200.0, // Default estimate
            protein: 5.0,
            carbs: 30.0,
            fat: 8.0,
            fiber: 2.0,
            sugar: 10.0,
            source: 'GTINsearch',
            category: category ?? 'Unknown',
            brand: brand,
            notes: 'Basic product info from GTINsearch. Nutrition data estimated - please verify.',
          );
        } else {
          print('❌ Product not found in GTINsearch');
        }
      } else {
        print('❌ GTINsearch API error: ${response.statusCode}');
      }
    } on TimeoutException {
      print('⏱️ GTINsearch timeout');
      return null;
    } catch (e) {
      print('❌ GTINsearch API error: $e');
    }
    return null;
  }

  /// Parse Open Food Facts product data with accurate calorie calculation
  static NutritionInfo? _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    final productName = product['product_name'] as String? ?? 
                       product['product_name_en'] as String? ?? 
                       'Unknown Product';
    
    final brand = product['brands'] as String? ?? product['brand'] as String?;
    final categories = product['categories'] as String?;
    final quantity = product['quantity'] as String?;
    
    // Extract nutrition data
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    
    // IMPORTANT: In Open Food Facts, 'energy-kcal' and 'energy' are typically per serving or per 100g
    // NOT necessarily for the whole product. We need to check if there's a serving_size
    // to determine what these values represent.
    
    // Check for serving-specific calories first (if serving_size exists)
    double servingCalories = 0.0;
    final servingSize = _parseNutrient(nutriments, 'serving_size') ?? 0.0;
    final energyKcal = _parseNutrient(nutriments, 'energy-kcal');
    final energy = _parseNutrient(nutriments, 'energy'); // May be in kJ
    final energyUnit = nutriments['energy_unit'] as String? ?? 
                      nutriments['energy-kcal_unit'] as String? ?? 'kcal';
    
    // If serving_size exists and we have energy-kcal/energy, it's likely for the serving
    if (servingSize > 0 && (energyKcal != null || energy != null)) {
      if (energyKcal != null) {
        servingCalories = energyKcal;
        print('✅ Using energy-kcal for serving (${servingSize.toStringAsFixed(0)}g): $servingCalories kcal');
      } else if (energy != null) {
        if (energyUnit.toLowerCase() == 'kj' || energyUnit.toLowerCase() == 'kilojoule') {
          servingCalories = energy / 4.184;
          print('✅ Converted energy from kJ for serving: ${energy} kJ = $servingCalories kcal');
        } else {
          servingCalories = energy;
          print('✅ Using energy (kcal) for serving: $servingCalories kcal');
        }
      }
    }
    
    // Also check for total product calories (less common)
    double totalCalories = 0.0;
    if (servingCalories == 0) {
      // Only use total calories if no serving calories found
      if (energyKcal != null) {
        totalCalories = energyKcal;
        print('✅ Using energy-kcal: $totalCalories kcal (may be per serving or per 100g)');
      } else if (energy != null) {
        if (energyUnit.toLowerCase() == 'kj' || energyUnit.toLowerCase() == 'kilojoule') {
          totalCalories = energy / 4.184;
          print('✅ Converted energy from kJ: ${energy} kJ = $totalCalories kcal');
        } else {
          totalCalories = energy;
          print('✅ Using energy (kcal): $totalCalories kcal');
        }
      }
    }
    
    // If no total calories, try per 100g and calculate
    double caloriesPer100g = 0.0;
    final energyKcal100g = _parseNutrient(nutriments, 'energy-kcal_100g');
    final energy100g = _parseNutrient(nutriments, 'energy_100g'); // May be in kJ
    final energy100gUnit = nutriments['energy_100g_unit'] as String? ?? 
                          nutriments['energy-kcal_100g_unit'] as String? ?? 'kcal';
    
    if (energyKcal100g != null) {
      caloriesPer100g = energyKcal100g;
      print('✅ Using energy-kcal_100g: $caloriesPer100g kcal/100g');
    } else if (energy100g != null) {
      // Check unit explicitly - don't guess
      if (energy100gUnit.toLowerCase() == 'kj' || energy100gUnit.toLowerCase() == 'kilojoule') {
        // Confirmed in kJ, convert to kcal
        caloriesPer100g = energy100g / 4.184;
        print('✅ Converted energy_100g from kJ: ${energy100g} kJ = $caloriesPer100g kcal/100g');
      } else {
        // Already in kcal
        caloriesPer100g = energy100g;
        print('✅ Using energy_100g (kcal): $caloriesPer100g kcal/100g');
      }
    }
    
    // Get other nutrients per 100g
    final proteinPer100g = _parseNutrient(nutriments, 'proteins_100g') ?? 0.0;
    final carbsPer100g = _parseNutrient(nutriments, 'carbohydrates_100g') ?? 0.0;
    final fatPer100g = _parseNutrient(nutriments, 'fat_100g') ?? 0.0;
    final fiberPer100g = _parseNutrient(nutriments, 'fiber_100g') ?? 0.0;
    final sugarPer100g = _parseNutrient(nutriments, 'sugars_100g') ?? 0.0;
    
    // CRITICAL: Determine serving size FIRST - this is the most important for accuracy
    // Priority: serving_size from nutriments > detected size > default
    final servingSizeGrams = _parseNutrient(nutriments, 'serving_size') ?? 0.0;
    
    // Determine actual product size with enhanced detection (for fallback)
    final productSize = _determineProductSize(product, quantity);
    final detectedWeight = productSize['weight'];
    final detectedVolume = productSize['volume'];
    final isLiquid = productSize['isLiquid'];
    final sizeInfo = productSize['display'];
    
    // Determine the actual serving size to use
    double actualWeight = 0.0;
    double actualVolume = 0.0;
    
    // Priority 1: Use serving_size from nutriments (most accurate - matches nutrition data)
    if (servingSizeGrams > 0) {
      if (isLiquid) {
        actualVolume = servingSizeGrams;
        actualWeight = servingSizeGrams; // For liquids, 1ml ≈ 1g
        print('📏 Using serving_size from nutriments: ${servingSizeGrams.toStringAsFixed(0)}ml');
      } else {
        actualWeight = servingSizeGrams;
        print('📏 Using serving_size from nutriments: ${servingSizeGrams.toStringAsFixed(0)}g');
      }
    } 
    // Priority 2: Use detected size from product info
    else if (detectedWeight > 0 || detectedVolume > 0) {
      actualWeight = detectedWeight;
      actualVolume = detectedVolume;
      print('📏 Using detected size: $sizeInfo (Weight: ${detectedWeight}g, Volume: ${detectedVolume}ml)');
    }
    // Priority 3: Default fallback (should be rare)
    else {
      if (isLiquid) {
        actualVolume = 100.0;
        actualWeight = 100.0;
        print('⚠️ No size info - using default 100ml for liquid');
      } else {
        actualWeight = 100.0;
        print('⚠️ No size info - using default 100g for solid');
      }
    }
    
    // Use the same base amount for all calculations to ensure consistency
    final baseAmount = isLiquid && actualVolume > 0 ? actualVolume : actualWeight;
    
    print('📊 Final serving size: $baseAmount${isLiquid ? 'ml' : 'g'} (source: ${servingSizeGrams > 0 ? 'nutriments' : (detectedWeight > 0 || detectedVolume > 0 ? 'detected' : 'default')})');
    
    // Calculate total calories for the serving/product size
    double finalCalories;
    
    // Priority 1: Use serving calories if available (most accurate)
    if (servingCalories > 0 && servingSizeGrams > 0) {
      // Verify that servingSize matches baseAmount (they should be the same)
      if ((baseAmount - servingSizeGrams).abs() < 5) {
        // Serving size matches our base amount - use serving calories directly
        finalCalories = servingCalories;
        print('✅ Using serving calories: $finalCalories kcal for ${servingSizeGrams.toStringAsFixed(0)}g serving');
      } else {
        // Serving size doesn't match - recalculate from per 100g
        if (caloriesPer100g > 0) {
          finalCalories = (caloriesPer100g * baseAmount) / 100;
          print('⚠️ Serving size mismatch - recalculating from per 100g');
          print('   Serving calories: $servingCalories for ${servingSizeGrams.toStringAsFixed(0)}g');
          print('   Calculated: $caloriesPer100g kcal/100g × $baseAmount g = $finalCalories kcal');
        } else {
          // Use serving calories but scale to baseAmount
          finalCalories = (servingCalories * baseAmount) / servingSizeGrams;
          print('⚠️ Scaling serving calories to match base amount');
          print('   Serving: $servingCalories kcal for ${servingSizeGrams.toStringAsFixed(0)}g');
          print('   Scaled: $finalCalories kcal for ${baseAmount.toStringAsFixed(0)}g');
        }
      }
    } 
    // Priority 2: Use total calories if available (may be for whole product)
    else if (totalCalories > 0 && baseAmount > 0) {
      // Check if totalCalories is reasonable for the baseAmount
      final caloriesPerGram = totalCalories / baseAmount;
      if (caloriesPerGram > 0.1 && caloriesPerGram < 10) {
        // Reasonable - use as-is
        finalCalories = totalCalories;
        print('✅ Using total calories: $finalCalories kcal for ${baseAmount.toStringAsFixed(0)}g');
      } else {
        // Unreasonable - likely per 100g, recalculate
        if (caloriesPer100g > 0) {
          finalCalories = (caloriesPer100g * baseAmount) / 100;
          print('⚠️ Total calories seem unreasonable, using per 100g calculation');
        } else {
          // Use total calories but log warning
          finalCalories = totalCalories;
          print('⚠️ Using total calories (may be incorrect): $finalCalories kcal');
        }
      }
    } 
    // Priority 3: Calculate from per 100g data
    else if (caloriesPer100g > 0 && baseAmount > 0) {
      finalCalories = (caloriesPer100g * baseAmount) / 100;
      print('✅ Calculated calories: $caloriesPer100g kcal/100${isLiquid ? 'ml' : 'g'} × $baseAmount${isLiquid ? 'ml' : 'g'} = $finalCalories kcal');
    } 
    // No data available
    else if (baseAmount == 0) {
      finalCalories = 0.0;
      print('❌ No size information available - cannot calculate calories accurately');
    } else {
      finalCalories = 0.0;
      print('❌ No calorie data available');
    }
    
    // If we still don't have calories or size, return null to try other sources
    if (finalCalories == 0 && baseAmount == 0) {
      print('❌ Cannot calculate nutrition: missing both calories and size data');
      return null;
    }
    
    // Calculate nutrients using the SAME baseAmount as calories for consistency
    // CRITICAL: Use serving size nutrients if they match our baseAmount, otherwise calculate from per 100g
    
    // Get serving size nutrients if available
    final servingProteinValue = _parseNutrient(nutriments, 'proteins');
    final servingCarbsValue = _parseNutrient(nutriments, 'carbohydrates');
    final servingFatValue = _parseNutrient(nutriments, 'fat');
    final servingFiberValue = _parseNutrient(nutriments, 'fiber');
    final servingSugarValue = _parseNutrient(nutriments, 'sugars');
    
    // Check if serving size nutrients match our baseAmount (within 5g tolerance)
    final bool useServingNutrients = servingSizeGrams > 0 && 
        servingProteinValue != null &&
        (baseAmount - servingSizeGrams).abs() < 5;
    
    double servingProtein;
    double servingCarbs;
    double servingFat;
    double servingFiber;
    double servingSugar;
    
    if (useServingNutrients) {
      // Use serving size nutrients directly (most accurate)
      // servingProteinValue is guaranteed non-null by useServingNutrients check (line 1267)
      servingProtein = servingProteinValue;
      servingCarbs = servingCarbsValue ?? (carbsPer100g * baseAmount) / 100;
      servingFat = servingFatValue ?? (fatPer100g * baseAmount) / 100;
      servingFiber = servingFiberValue ?? (fiberPer100g * baseAmount) / 100;
      servingSugar = servingSugarValue ?? (sugarPer100g * baseAmount) / 100;
      print('✅ Using serving size nutrients for ${servingSizeGrams.toStringAsFixed(0)}g');
    } else {
      // Calculate from per 100g using baseAmount
      servingProtein = (proteinPer100g * baseAmount) / 100;
      servingCarbs = (carbsPer100g * baseAmount) / 100;
      servingFat = (fatPer100g * baseAmount) / 100;
      servingFiber = (fiberPer100g * baseAmount) / 100;
      servingSugar = (sugarPer100g * baseAmount) / 100;
      print('✅ Calculated nutrients from per 100g for ${baseAmount.toStringAsFixed(0)}g');
    }
    
    print('📊 Nutrients for $baseAmount${isLiquid ? 'ml' : 'g'}: P${servingProtein.toStringAsFixed(1)}g C${servingCarbs.toStringAsFixed(1)}g F${servingFat.toStringAsFixed(1)}g');
    
    // Cross-validate calories: log warnings but be conservative about changing values
    final calculatedCaloriesFromMacros = (servingProtein * 4) + (servingCarbs * 4) + (servingFat * 9);
    if (finalCalories > 0 && calculatedCaloriesFromMacros > 0) {
      final difference = (finalCalories - calculatedCaloriesFromMacros).abs();
      final percentDiff = (difference / finalCalories) * 100;
      
      // Only use macro calculation if difference is > 30% AND we have all macros
      // This prevents overriding correct values for products with special nutrition profiles
      if (percentDiff > 30 && servingProtein > 0 && servingCarbs > 0 && servingFat > 0) {
        print('⚠️ Significant calorie mismatch detected (>30%). Using macro-based calculation.');
        print('   Reported: ${finalCalories.toStringAsFixed(0)} kcal');
        print('   Calculated from macros: ${calculatedCaloriesFromMacros.toStringAsFixed(0)} kcal');
        print('   Difference: ${percentDiff.toStringAsFixed(1)}%');
        finalCalories = calculatedCaloriesFromMacros;
      } else if (percentDiff > 10) {
        // Log warning but keep reported value if difference is moderate
        print('ℹ️ Calorie difference: Reported ${finalCalories.toStringAsFixed(0)} kcal vs Calculated ${calculatedCaloriesFromMacros.toStringAsFixed(0)} kcal (${percentDiff.toStringAsFixed(1)}% diff)');
        print('   Keeping reported value - may be correct for this product');
      }
    }
    
    // Create display name with size information
    String displayName = productName;
    if (brand != null && brand.isNotEmpty && !displayName.toLowerCase().contains(brand.toLowerCase())) {
      displayName = '$brand $displayName';
    }
    if (sizeInfo.isNotEmpty) {
      displayName = '$displayName ($sizeInfo)';
    }
    
    // Create detailed notes
    String notes = 'Size: $sizeInfo';
    if (totalCalories > 0) {
      notes += ' | Total calories: ${finalCalories.toStringAsFixed(0)} kcal';
    } else {
      notes += ' | Calculated from ${caloriesPer100g.toStringAsFixed(0)} kcal/100${isLiquid ? 'ml' : 'g'}';
    }
    
    // Final validation: Ensure weight is set correctly
    final finalWeight = actualWeight > 0 ? actualWeight : (isLiquid ? actualVolume : 100.0);
    
    // Only return if we have valid data
    if (finalCalories > 0 || (servingProtein > 0 || servingCarbs > 0 || servingFat > 0)) {
      print('✅ Returning validated nutrition data');
      print('   Product: $displayName');
      print('   Size: $finalWeight${isLiquid ? 'ml' : 'g'}');
      print('   Calories: $finalCalories kcal');
      print('   Macros: P${servingProtein.toStringAsFixed(1)}g C${servingCarbs.toStringAsFixed(1)}g F${servingFat.toStringAsFixed(1)}g');
      
      return NutritionInfo(
        foodName: displayName,
        weightGrams: finalWeight,
        calories: finalCalories,
        protein: servingProtein,
        carbs: servingCarbs,
        fat: servingFat,
        fiber: servingFiber,
        sugar: servingSugar,
        source: 'Open Food Facts',
        category: categories?.split(',').first.trim() ?? 'Unknown',
        brand: brand,
        notes: notes,
      );
    } else {
      print('❌ Invalid nutrition data - returning null to try other sources');
      return null;
    }
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
          final nutrition = _parseOpenFoodFactsProduct(product);
          if (nutrition != null && nutrition.isValid) {
            return nutrition;
          }
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
          final nutrition = _parseOpenFoodFactsProduct(product);
          if (nutrition != null && nutrition.isValid) {
            return nutrition;
          }
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
              'content': '''You are a certified fitness nutritionist. Provide ACCURATE and REALISTIC nutritional information for the given product.

CRITICAL REQUIREMENTS:
- Use REAL nutritional data from actual food products, not generic estimates
- Calories must be accurate (check: protein×4 + carbs×4 + fat×9 should approximately equal total calories)
- Values must be realistic for the product type (e.g., a cookie won't have 200g protein)
- If unsure, use conservative estimates but mark confidence as low
- Provide values per 100g serving unless specified otherwise

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
  "confidence": <0.0-1.0 based on certainty>,
  "fitness_category": "muscle_building|fat_loss|performance|recovery"
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
            final protein = _parseMacro(parsed['protein']);
            final carbs = _parseMacro(parsed['carbs']);
            final fat = _parseMacro(parsed['fat']);
            final fiber = _parseMacro(parsed['fiber']);
            final sugar = _parseMacro(parsed['sugar']);
            
            // Validate AI response - log warnings but don't overwrite correct values
            // AI might have more accurate calorie data than macro calculation (e.g., fiber, alcohol)
            final calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9);
            if (calories != null && calories > 0 && calculatedCalories > 0) {
              final difference = (calories - calculatedCalories).abs();
              final percentDiff = (difference / calories) * 100;
              
              if (percentDiff > 30) {
                print('⚠️ AI response validation: Large calorie mismatch (${percentDiff.toStringAsFixed(1)}%)');
                print('   Reported: $calories kcal, Calculated: ${calculatedCalories.toStringAsFixed(0)} kcal');
                print('   Keeping AI-reported values - may include fiber/alcohol or be more accurate');
              } else if (percentDiff > 10) {
                print('ℹ️ AI response validation: Moderate calorie difference (${percentDiff.toStringAsFixed(1)}%)');
                print('   Keeping AI-reported values - within acceptable range');
              } else {
                print('✅ AI response validated: Calories match macros (${percentDiff.toStringAsFixed(1)}% diff)');
              }
            }
            
            return NutritionInfo(
              foodName: (parsed['food'] ?? productName).toString(),
              weightGrams: 100.0, // Default serving size
              calories: calories ?? 0,
              protein: protein,
              carbs: carbs,
              fat: fat,
              fiber: fiber,
              sugar: sugar,
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

  /// Determine product size with enhanced detection for accurate calorie calculation
  static Map<String, dynamic> _determineProductSize(Map<String, dynamic> product, String? quantity) {
    // Check multiple sources for size information
    final quantityInfo = quantity ?? '';
    final productName = (product['product_name'] as String? ?? '').toLowerCase();
    final categories = (product['categories'] as String? ?? '').toLowerCase();
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
    
    // Check for liquid indicators
    final isLiquid = _isLiquidProduct(productName, categories, quantityInfo);
    
    // Try to get size from various sources
    double weight = 0.0;
    double volume = 0.0;
    String display = '';
    
    // 1. Check quantity field first
    if (quantityInfo.isNotEmpty) {
      final extracted = _extractWeightAndUnits(quantityInfo);
      weight = extracted['weight'];
      volume = extracted['volume'];
      display = extracted['display'];
      
      if (isLiquid && volume > 0) {
        print('📏 Size from quantity: $display (Volume: ${volume}ml)');
        return {
          'weight': weight,
          'volume': volume,
          'isLiquid': isLiquid,
          'display': display,
        };
      } else if (!isLiquid && weight > 0) {
        print('📏 Size from quantity: $display (Weight: ${weight}g)');
        return {
          'weight': weight,
          'volume': volume,
          'isLiquid': isLiquid,
          'display': display,
        };
      }
    }
    
    // 2. Check product name for size information
    final nameSize = _extractSizeFromText(productName);
    if (nameSize['weight'] > 0 || nameSize['volume'] > 0) {
      weight = nameSize['weight'];
      volume = nameSize['volume'];
      display = nameSize['display'];
      
      if (isLiquid && volume > 0) {
        print('📏 Size from product name: $display (Volume: ${volume}ml)');
        return {
          'weight': weight,
          'volume': volume,
          'isLiquid': isLiquid,
          'display': display,
        };
      } else if (!isLiquid && weight > 0) {
        print('📏 Size from product name: $display (Weight: ${weight}g)');
        return {
          'weight': weight,
          'volume': volume,
          'isLiquid': isLiquid,
          'display': display,
        };
      }
    }
    
    // 3. Check nutriments for serving size information
    final servingSize = _parseNutrient(nutriments, 'serving_size') ?? 0.0;
    if (servingSize > 0) {
      if (isLiquid) {
        volume = servingSize;
        display = '${servingSize.toStringAsFixed(0)}ml';
        print('📏 Size from nutriments: $display (Volume: ${volume}ml)');
      } else {
        weight = servingSize;
        display = '${servingSize.toStringAsFixed(0)}g';
        print('📏 Size from nutriments: $display (Weight: ${weight}g)');
      }
      
      return {
        'weight': weight,
        'volume': volume,
        'isLiquid': isLiquid,
        'display': display,
      };
    }
    
    // 4. Don't use defaults - return 0 if size not found
    // This prevents wrong calculations. Better to return 0 and let AI/fallback handle it
    if (weight == 0 && volume == 0) {
      print('⚠️ No size information found - returning 0 to prevent wrong calculations');
      return {
        'weight': 0.0,
        'volume': 0.0,
        'isLiquid': isLiquid,
        'display': 'Size unknown',
      };
    }
    
    return {
      'weight': weight,
      'volume': volume,
      'isLiquid': isLiquid,
      'display': display,
    };
  }

  /// Check if product is liquid based on name, categories, and quantity
  static bool _isLiquidProduct(String productName, String categories, String quantity) {
    final liquidKeywords = [
      'drink', 'beverage', 'juice', 'soda', 'water', 'milk', 'tea', 'coffee',
      'beer', 'wine', 'spirit', 'liquor', 'syrup', 'sauce', 'oil', 'vinegar',
      'ml', 'liter', 'litre', 'pint', 'quart', 'gallon', 'fluid'
    ];
    
    final liquidCategories = [
      'beverages', 'drinks', 'juices', 'alcoholic-beverages', 'waters',
      'oils', 'vinegars', 'sauces', 'syrups'
    ];
    
    final textToCheck = '$productName $categories $quantity'.toLowerCase();
    
    // Check for liquid keywords
    for (final keyword in liquidKeywords) {
      if (textToCheck.contains(keyword)) {
        return true;
      }
    }
    
    // Check for liquid categories
    for (final category in liquidCategories) {
      if (textToCheck.contains(category)) {
        return true;
      }
    }
    
    // Check for volume units in quantity
    if (quantity.isNotEmpty) {
      final volumeUnits = ['ml', 'l', 'liter', 'litre', 'pint', 'quart', 'gallon', 'fl oz'];
      for (final unit in volumeUnits) {
        if (quantity.toLowerCase().contains(unit)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Extract size information from text with enhanced patterns
  static Map<String, dynamic> _extractSizeFromText(String text) {
    // Enhanced patterns for better size detection
    final patterns = [
      // Weight patterns
      RegExp(r'(\d+(?:\.\d+)?)\s*(g|gram|grams)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(kg|kilogram|kilograms)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(oz|ounce|ounces)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(lb|pound|pounds)'),
      
      // Volume patterns
      RegExp(r'(\d+(?:\.\d+)?)\s*(ml|milliliter|milliliters)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(l|liter|litre|liters|litres)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(fl\s*oz|fluid\s*ounce|fluid\s*ounces)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(pint|pints)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(quart|quarts)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(gallon|gallons)'),
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
            weight = amount; // Assume 1ml = 1g for liquids
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
        
        return {
          'weight': weight,
          'volume': volume,
          'display': display,
        };
      }
    }
    
    return {
      'weight': 0.0,
      'volume': 0.0,
      'display': '',
    };
  }

  /// Extract weight and units from string (enhanced version)
  static Map<String, dynamic> _extractWeightAndUnits(String text) {
    final extracted = _extractSizeFromText(text);
    if (extracted['weight'] > 0 || extracted['volume'] > 0) {
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
      
      if (unit == 'kg') {
        weightInGrams = weight * 1000;
      } else if (unit == 'ml') {
        weightInGrams = weight;
        volumeInMl = weight;
      } else if (unit == 'l') {
        weightInGrams = weight * 1000;
        volumeInMl = weight * 1000;
      } else if (unit == 'oz') {
        weightInGrams = weight * 28.35;
      } else if (unit == 'lb') {
        weightInGrams = weight * 453.59;
      }
      
      return {
        'weight': weightInGrams,
        'volume': volumeInMl,
        'unit': unit,
        'display': '$weight $unit',
      };
    }
    
    return {
      'weight': 100.0,
      'volume': 0.0,
      'unit': 'g',
      'display': '100g',
    };
  }

}
