import 'dart:async';
import '../models/food_history_entry.dart';
import '../services/food_history_service.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Service that provides today's food data (calories and macro nutrients)
/// Uses the same data source as TodaysFoodScreen
class TodaysFoodDataService {
  static final TodaysFoodDataService _instance = TodaysFoodDataService._internal();
  factory TodaysFoodDataService() => _instance;
  TodaysFoodDataService._internal();

  // Stream controllers for real-time updates
  final StreamController<int> _consumedCaloriesController = StreamController<int>.broadcast();
  final StreamController<Map<String, double>> _macroNutrientsController = StreamController<Map<String, double>>.broadcast();

  // Getters for streams
  Stream<int> get consumedCaloriesStream => _consumedCaloriesController.stream;
  Stream<Map<String, double>> get macroNutrientsStream => _macroNutrientsController.stream;

  // Cache for fast access
  int _cachedConsumedCalories = 0;
  Map<String, double> _cachedMacroNutrients = {};
  
  // Track initialization to allow legitimate 0 updates after initial load
  bool _hasLoadedInitialData = false;
  DateTime? _lastValidDataTime;

  // Stream subscription
  StreamSubscription<List<FoodHistoryEntry>>? _foodEntriesSubscription;

  /// Initialize the service
  Future<void> initialize() async {
    // INSTANT: Load existing data immediately for instant UI display
    try {
      final existingEntries = await FoodHistoryService.getTodaysFoodEntries();
      if (existingEntries.isNotEmpty) {
        calculateAndUpdateData(existingEntries);
        if (kDebugMode) debugPrint('✅ TodaysFoodDataService: Loaded ${existingEntries.length} existing entries immediately');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading existing food entries: $e');
    }
    
    // Listen to today's food entries stream (same as TodaysFoodScreen)
    _foodEntriesSubscription?.cancel(); // Cancel existing subscription first
    _foodEntriesSubscription = FoodHistoryService.getTodaysFoodEntriesStream().listen(
      (entries) {
        calculateAndUpdateData(entries);
      },
      onError: (error) {
        if (kDebugMode) debugPrint('❌ TodaysFoodDataService: Error in food entries stream: $error');
      },
    );
  }

  /// Calculate consumed calories and macro nutrients from food entries
  void calculateAndUpdateData(List<FoodHistoryEntry> entries) {
    // Calculate consumed calories (same logic as TodaysFoodScreen._calculateTotals)
    final consumedCalories = entries.fold<int>(0, (total, entry) => total + entry.calories.round());
    
    // Calculate macro nutrients (same logic as TodaysFoodScreen._calculateTotals)
    final macroNutrients = {
      'protein': entries.fold<double>(0, (total, entry) => total + entry.protein),
      'carbs': entries.fold<double>(0, (total, entry) => total + entry.carbs),
      'fat': entries.fold<double>(0, (total, entry) => total + entry.fat),
      'fiber': entries.fold<double>(0, (total, entry) => total + entry.fiber),
      'sugar': entries.fold<double>(0, (total, entry) => total + entry.sugar),
    };

    // Debug logging
    if (kDebugMode) debugPrint('🍎 TodaysFoodDataService: ${entries.length} food entries');
    if (kDebugMode) debugPrint('   Calculated Calories: $consumedCalories (cached: $_cachedConsumedCalories)');
    if (kDebugMode) debugPrint('   Protein: ${macroNutrients['protein']}g, Carbs: ${macroNutrients['carbs']}g, Fat: ${macroNutrients['fat']}g');

    // CRITICAL FIX: Intelligent cache protection
    // Prevents zero-flash from Firestore init delays while allowing legitimate 0 updates
    bool shouldUpdate = false;
    
    if (consumedCalories > 0) {
      // Always update with valid positive data
      shouldUpdate = true;
      _hasLoadedInitialData = true;
      _lastValidDataTime = DateTime.now();
    } else if (_cachedConsumedCalories == 0) {
      // Update if cache is currently 0 (initial state or truly empty)
      shouldUpdate = true;
      _hasLoadedInitialData = true;
    } else if (_hasLoadedInitialData && _lastValidDataTime != null) {
      // Allow 0 update only if enough time has passed since last valid data
      // This handles legitimate deletions while preventing init flickers
      final timeSinceLastUpdate = DateTime.now().difference(_lastValidDataTime!);
      if (timeSinceLastUpdate.inSeconds >= 2) {
        // After 2 seconds, accept 0 as legitimate (user may have deleted all food)
        shouldUpdate = true;
        if (kDebugMode) debugPrint('✅ TodaysFoodDataService: Accepting 0 after ${timeSinceLastUpdate.inSeconds}s');
      } else {
        // Too soon after valid data - likely Firestore init flicker
        if (kDebugMode) debugPrint('⚠️  TodaysFoodDataService: Ignoring 0 (only ${timeSinceLastUpdate.inMilliseconds}ms since valid data)');
        shouldUpdate = false;
      }
    } else {
      // Haven't loaded initial data yet and getting 0 - likely init delay
      if (kDebugMode) debugPrint('⚠️  TodaysFoodDataService: Ignoring 0 during init - preserving cache: $_cachedConsumedCalories');
      shouldUpdate = false;
    }
    
    if (shouldUpdate) {
      // Update cache immediately
      _cachedConsumedCalories = consumedCalories;
      _cachedMacroNutrients = macroNutrients;

      // Emit updates immediately (no await, no delay) - check if controllers are closed
      if (!_consumedCaloriesController.isClosed) {
        _consumedCaloriesController.add(consumedCalories);
      }
      if (!_macroNutrientsController.isClosed) {
        _macroNutrientsController.add(macroNutrients);
      }
      
      if (kDebugMode) debugPrint('⚡ TodaysFoodDataService: Cache & streams updated - Calories: $consumedCalories');
    } else {
      if (kDebugMode) debugPrint('🛡️ TodaysFoodDataService: Cache protected - NOT updating with 0');
    }
  }

  /// ULTRA FAST: Update with pre-calculated values (no calculations needed)
  void updateWithPreCalculatedValues(int consumedCalories, Map<String, double> macroNutrients) {
    // CRITICAL FIX: Intelligent cache protection (same logic as calculateAndUpdateData)
    bool shouldUpdate = false;
    
    if (consumedCalories > 0) {
      // Always update with valid positive data
      shouldUpdate = true;
      _hasLoadedInitialData = true;
      _lastValidDataTime = DateTime.now();
    } else if (_cachedConsumedCalories == 0) {
      // Update if cache is currently 0 (initial state or truly empty)
      shouldUpdate = true;
      _hasLoadedInitialData = true;
    } else if (_hasLoadedInitialData && _lastValidDataTime != null) {
      // Allow 0 update only if enough time has passed since last valid data
      final timeSinceLastUpdate = DateTime.now().difference(_lastValidDataTime!);
      if (timeSinceLastUpdate.inSeconds >= 2) {
        shouldUpdate = true;
        if (kDebugMode) debugPrint('✅ TodaysFoodDataService: Pre-calc accepting 0 after ${timeSinceLastUpdate.inSeconds}s');
      } else {
        if (kDebugMode) debugPrint('⚠️  TodaysFoodDataService: Ignoring pre-calc 0 (only ${timeSinceLastUpdate.inMilliseconds}ms since valid data)');
        shouldUpdate = false;
      }
    } else {
      // Haven't loaded initial data yet and getting 0 - likely init delay
      if (kDebugMode) debugPrint('⚠️  TodaysFoodDataService: Ignoring pre-calc 0 during init - preserving cache: $_cachedConsumedCalories');
      shouldUpdate = false;
    }
    
    if (shouldUpdate) {
      // Update cache immediately (no calculations)
      _cachedConsumedCalories = consumedCalories;
      _cachedMacroNutrients = macroNutrients;

      // Emit updates immediately (no calculations, no delays)
      if (!_consumedCaloriesController.isClosed) {
        _consumedCaloriesController.add(consumedCalories);
      }
      if (!_macroNutrientsController.isClosed) {
        _macroNutrientsController.add(macroNutrients);
      }
      
      if (kDebugMode) debugPrint('🚀 TodaysFoodDataService: ULTRA FAST update - Calories: $consumedCalories');
    } else {
      if (kDebugMode) debugPrint('🛡️ TodaysFoodDataService: Pre-calc cache protected - NOT updating with 0');
    }
  }

  /// Get cached consumed calories (for immediate UI updates)
  int getCachedConsumedCalories() {
    return _cachedConsumedCalories;
  }

  /// Get cached macro nutrients (for immediate UI updates)
  Map<String, double> getCachedMacroNutrients() {
    return _cachedMacroNutrients;
  }

  /// Dispose of the service
  void dispose() {
    _foodEntriesSubscription?.cancel();
    _consumedCaloriesController.close();
    _macroNutrientsController.close();
  }
}

