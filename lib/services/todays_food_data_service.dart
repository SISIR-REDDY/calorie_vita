import 'dart:async';
import '../models/food_history_entry.dart';
import '../services/food_history_service.dart';

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

  // Stream subscription
  StreamSubscription<List<FoodHistoryEntry>>? _foodEntriesSubscription;

  /// Initialize the service
  Future<void> initialize() async {
    // INSTANT: Load existing data immediately for instant UI display
    try {
      final existingEntries = await FoodHistoryService.getTodaysFoodEntries();
      if (existingEntries.isNotEmpty) {
        calculateAndUpdateData(existingEntries);
        print('✅ TodaysFoodDataService: Loaded ${existingEntries.length} existing entries immediately');
      }
    } catch (e) {
      print('❌ Error loading existing food entries: $e');
    }
    
    // Listen to today's food entries stream (same as TodaysFoodScreen)
    _foodEntriesSubscription?.cancel(); // Cancel existing subscription first
    _foodEntriesSubscription = FoodHistoryService.getTodaysFoodEntriesStream().listen(
      (entries) {
        calculateAndUpdateData(entries);
      },
      onError: (error) {
        print('❌ TodaysFoodDataService: Error in food entries stream: $error');
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
    print('🍎 TodaysFoodDataService: ${entries.length} food entries');
    print('   Calories: $consumedCalories');
    print('   Protein: ${macroNutrients['protein']}g, Carbs: ${macroNutrients['carbs']}g, Fat: ${macroNutrients['fat']}g');

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
    
    print('⚡ TodaysFoodDataService: Streams updated immediately');
  }

  /// ULTRA FAST: Update with pre-calculated values (no calculations needed)
  void updateWithPreCalculatedValues(int consumedCalories, Map<String, double> macroNutrients) {
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
    
    print('🚀 TodaysFoodDataService: ULTRA FAST update - Calories: $consumedCalories');
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
