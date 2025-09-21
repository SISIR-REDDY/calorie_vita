import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_history_entry.dart';
import '../services/food_history_service.dart';
import '../services/daily_summary_service.dart';

/// Service for fast data refresh and real-time updates
class FastDataRefreshService {
  static final FastDataRefreshService _instance = FastDataRefreshService._internal();
  factory FastDataRefreshService() => _instance;
  FastDataRefreshService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DailySummaryService _dailySummaryService = DailySummaryService();

  // Stream controllers for real-time updates
  final StreamController<int> _consumedCaloriesController = StreamController<int>.broadcast();
  final StreamController<List<FoodHistoryEntry>> _todaysFoodController = StreamController<List<FoodHistoryEntry>>.broadcast();
  final StreamController<Map<String, dynamic>> _macroBreakdownController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<int> get consumedCaloriesStream => _consumedCaloriesController.stream;
  Stream<List<FoodHistoryEntry>> get todaysFoodStream => _todaysFoodController.stream;
  Stream<Map<String, dynamic>> get macroBreakdownStream => _macroBreakdownController.stream;

  // Cache for fast access
  int _cachedConsumedCalories = 0;
  List<FoodHistoryEntry> _cachedTodaysFood = [];
  Map<String, dynamic> _cachedMacroBreakdown = {};

  // Refresh timers
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  
  // Debouncing for UI updates
  Timer? _debounceTimer;
  bool _hasPendingUpdate = false;

  /// Initialize the service
  Future<void> initialize() async {
    await _dailySummaryService.initialize();
    _startPeriodicRefresh();
    _setupRealTimeListeners();
  }

  /// Start periodic refresh for fast updates (disabled to prevent flickering)
  void _startPeriodicRefresh() {
    // Disable periodic refresh to prevent unnecessary updates
    // Data will only update when there are actual changes from Firestore
    _refreshTimer?.cancel();
    // _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
    //   if (!_isRefreshing) {
    //     _refreshData();
    //   }
    // });
  }

  /// Setup real-time listeners with debouncing
  void _setupRealTimeListeners() {
    // Listen to today's food entries
    FoodHistoryService.getTodaysFoodEntriesStream().listen((entries) {
      _cachedTodaysFood = entries;
      
      // Calculate consumed calories
      final consumedCalories = entries.fold<int>(0, (total, entry) => total + entry.calories.round());
      
      // Calculate macro breakdown
      _calculateMacroBreakdown(entries);
      
      // Debounce UI updates to prevent flickering
      _debounceUIUpdates(entries, consumedCalories);
    });
  }

  /// Debounce UI updates to prevent flickering
  void _debounceUIUpdates(List<FoodHistoryEntry> entries, int consumedCalories) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_hasPendingUpdate) {
        _hasPendingUpdate = true;
        
        // Update food entries
        _todaysFoodController.add(entries);
        
        // Update consumed calories if changed
        if (consumedCalories != _cachedConsumedCalories) {
          _cachedConsumedCalories = consumedCalories;
          _consumedCaloriesController.add(consumedCalories);
        }
        
        _hasPendingUpdate = false;
      }
    });
  }

  /// Calculate macro breakdown from food entries
  void _calculateMacroBreakdown(List<FoodHistoryEntry> entries) {
    double totalProtein = 0.0;
    double totalCarbs = 0.0;
    double totalFat = 0.0;
    double totalFiber = 0.0;
    double totalSugar = 0.0;

    for (final entry in entries) {
      totalProtein += entry.protein;
      totalCarbs += entry.carbs;
      totalFat += entry.fat;
      totalFiber += entry.fiber;
      totalSugar += entry.sugar;
    }

    final macroBreakdown = {
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
      'fiber': totalFiber,
      'sugar': totalSugar,
      'calories': _cachedConsumedCalories,
    };

    // Only update if data has actually changed
    if (_hasMacroDataChanged(macroBreakdown)) {
      _cachedMacroBreakdown = macroBreakdown;
      _macroBreakdownController.add(macroBreakdown);
    }
  }

  /// Check if macro data has actually changed to prevent unnecessary updates
  bool _hasMacroDataChanged(Map<String, dynamic> newData) {
    if (_cachedMacroBreakdown.isEmpty) return true;
    
    return _cachedMacroBreakdown['protein'] != newData['protein'] ||
           _cachedMacroBreakdown['carbs'] != newData['carbs'] ||
           _cachedMacroBreakdown['fat'] != newData['fat'] ||
           _cachedMacroBreakdown['fiber'] != newData['fiber'] ||
           _cachedMacroBreakdown['sugar'] != newData['sugar'];
  }

  /// Refresh data immediately
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    try {
      // Get today's food entries
      final entries = await FoodHistoryService.getTodaysFoodEntries();
      
      if (!listEquals(entries, _cachedTodaysFood)) {
        _cachedTodaysFood = entries;
        _todaysFoodController.add(entries);
        
        // Calculate consumed calories
        final consumedCalories = entries.fold<int>(0, (total, entry) => total + entry.calories.round());
        if (consumedCalories != _cachedConsumedCalories) {
          _cachedConsumedCalories = consumedCalories;
          _consumedCaloriesController.add(consumedCalories);
        }

        // Calculate macro breakdown
        _calculateMacroBreakdown(entries);
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Force refresh data (for immediate updates)
  Future<void> forceRefresh() async {
    await _refreshData();
  }

  /// Get cached consumed calories (for immediate UI updates)
  int getCachedConsumedCalories() {
    return _cachedConsumedCalories;
  }

  /// Get cached today's food entries (for immediate UI updates)
  List<FoodHistoryEntry> getCachedTodaysFood() {
    return _cachedTodaysFood;
  }

  /// Get cached macro breakdown (for immediate UI updates)
  Map<String, dynamic> getCachedMacroBreakdown() {
    return _cachedMacroBreakdown;
  }

  /// Add food entry and refresh immediately
  Future<bool> addFoodEntryAndRefresh(FoodHistoryEntry entry) async {
    try {
      // Add to food history
      final success = await FoodHistoryService.addFoodEntry(entry);
      
      if (success) {
        // Force immediate refresh
        await forceRefresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding food entry and refreshing: $e');
      return false;
    }
  }

  /// Delete food entry and refresh immediately
  Future<bool> deleteFoodEntryAndRefresh(String entryId) async {
    try {
      // Delete from food history
      final success = await FoodHistoryService.deleteFoodEntry(entryId);
      
      if (success) {
        // Force immediate refresh
        await forceRefresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting food entry and refreshing: $e');
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _consumedCaloriesController.close();
    _todaysFoodController.close();
    _macroBreakdownController.close();
  }
}
