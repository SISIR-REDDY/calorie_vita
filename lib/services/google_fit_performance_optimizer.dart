import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/google_fit_data.dart';

/// Google Fit Performance Optimizer
/// Reduces API calls and improves data loading performance
class GoogleFitPerformanceOptimizer {
  static final GoogleFitPerformanceOptimizer _instance = GoogleFitPerformanceOptimizer._internal();
  factory GoogleFitPerformanceOptimizer() => _instance;
  GoogleFitPerformanceOptimizer._internal();

  // Performance tracking
  final Map<String, DateTime> _lastApiCall = {};
  final Map<String, int> _apiCallCount = {};
  final Map<String, GoogleFitData> _dataCache = {};
  
  // Performance settings
  static const Duration _minApiInterval = Duration(minutes: 1); // Minimum 1 minute between API calls
  static const Duration _cacheValidity = Duration(minutes: 30); // Cache valid for 30 minutes (increased for better persistence)
  static const int _maxApiCallsPerMinute = 10; // Rate limiting
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  
  // Data validation
  static const int _minStepsThreshold = 0; // Allow any steps (changed from 100 to 0)
  static const double _maxCaloriesThreshold = 10000.0; // Ignore unrealistic calorie data
  static const double _maxDistanceThreshold = 100.0; // Ignore unrealistic distance data

  /// Check if API call should be made (rate limiting)
  bool shouldMakeApiCall(String endpoint) {
    final now = DateTime.now();
    final lastCall = _lastApiCall[endpoint];
    
    if (lastCall == null) return true;
    
    // Check minimum interval
    if (now.difference(lastCall) < _minApiInterval) {
      return false;
    }
    
    // Check rate limiting
    final callCount = _apiCallCount[endpoint] ?? 0;
    if (callCount >= _maxApiCallsPerMinute) {
      return false;
    }
    
    return true;
  }

  /// Record API call for rate limiting
  void recordApiCall(String endpoint) {
    final now = DateTime.now();
    _lastApiCall[endpoint] = now;
    _apiCallCount[endpoint] = (_apiCallCount[endpoint] ?? 0) + 1;
    
    // Reset counter after rate limit window
    Timer(_rateLimitWindow, () {
      _apiCallCount[endpoint] = 0;
    });
  }

  /// Validate Google Fit data for consistency
  bool validateData(GoogleFitData data) {
    // Check if data is for today
    final now = DateTime.now();
    final isToday = data.date.year == now.year &&
        data.date.month == now.month &&
        data.date.day == now.day;
    
    if (!isToday) return false;
    
    // Validate steps
    if (data.steps != null && data.steps! < _minStepsThreshold) {
      print('⚠️ Google Fit data validation: Steps too low (${data.steps}), ignoring');
      return false;
    }
    
    // Validate calories
    if (data.caloriesBurned != null && data.caloriesBurned! > _maxCaloriesThreshold) {
      print('⚠️ Google Fit data validation: Calories too high (${data.caloriesBurned}), ignoring');
      return false;
    }
    
    // Validate distance
    if (data.distance != null && data.distance! > _maxDistanceThreshold) {
      print('⚠️ Google Fit data validation: Distance too high (${data.distance}), ignoring');
      return false;
    }
    
    return true;
  }

  /// Cache data with validation
  void cacheData(String key, GoogleFitData data) {
    if (validateData(data)) {
      _dataCache[key] = data;
      print('✅ Google Fit data cached: $key - Steps: ${data.steps}');
    } else {
      print('❌ Google Fit data validation failed, not cached: $key');
    }
  }

  /// Get cached data if valid
  GoogleFitData? getCachedData(String key) {
    final cached = _dataCache[key];
    if (cached == null) return null;
    
    final now = DateTime.now();
    final cacheAge = now.difference(cached.date);
    
    if (cacheAge < _cacheValidity) {
      return cached;
    }
    
    // Remove expired cache
    _dataCache.remove(key);
    return null;
  }

  /// Merge multiple data sources intelligently
  GoogleFitData? mergeDataSources(List<GoogleFitData> dataSources) {
    if (dataSources.isEmpty) return null;
    
    // Filter valid data
    final validData = dataSources.where(validateData).toList();
    if (validData.isEmpty) return null;
    
    // Use the most recent data as base
    validData.sort((a, b) => b.date.compareTo(a.date));
    final baseData = validData.first;
    
    // Merge with other valid data (take highest values for fitness metrics)
    int? mergedSteps = baseData.steps;
    double? mergedCalories = baseData.caloriesBurned;
    double? mergedDistance = baseData.distance;
    double? mergedWeight = baseData.weight;
    
    for (final data in validData.skip(1)) {
      if (data.steps != null && (mergedSteps == null || data.steps! > mergedSteps)) {
        mergedSteps = data.steps;
      }
      if (data.caloriesBurned != null && (mergedCalories == null || data.caloriesBurned! > mergedCalories)) {
        mergedCalories = data.caloriesBurned;
      }
      if (data.distance != null && (mergedDistance == null || data.distance! > mergedDistance)) {
        mergedDistance = data.distance;
      }
      if (data.weight != null && (mergedWeight == null || data.weight! > mergedWeight)) {
        mergedWeight = data.weight;
      }
    }
    
    return GoogleFitData(
      date: baseData.date,
      steps: mergedSteps,
      caloriesBurned: mergedCalories,
      distance: mergedDistance,
      weight: mergedWeight,
    );
  }

  /// Debounce data updates to prevent UI flickering
  Timer? _debounceTimer;
  void debounceDataUpdate(Function() updateCallback, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, updateCallback);
  }

  /// Calculate data freshness score (0-1, higher is fresher)
  double calculateFreshnessScore(GoogleFitData data) {
    final now = DateTime.now();
    final age = now.difference(data.date);
    
    // Score based on age (newer = higher score)
    if (age.inMinutes < 5) return 1.0;
    if (age.inMinutes < 15) return 0.8;
    if (age.inMinutes < 30) return 0.6;
    if (age.inMinutes < 60) return 0.4;
    return 0.2;
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'cachedDataCount': _dataCache.length,
      'apiCallCounts': Map.from(_apiCallCount),
      'lastApiCalls': Map.from(_lastApiCall),
      'cacheKeys': _dataCache.keys.toList(),
    };
  }

  /// Clear all caches
  void clearCache() {
    _dataCache.clear();
    _lastApiCall.clear();
    _apiCallCount.clear();
    print('🧹 Google Fit performance optimizer cache cleared');
  }

  /// Optimize data for display (smooth out rapid changes)
  GoogleFitData? smoothData(GoogleFitData newData, GoogleFitData? previousData) {
    if (previousData == null) return newData;
    
    // Only smooth if data is from the same day
    if (newData.date.day != previousData.date.day) return newData;
    
    // Smooth steps (prevent rapid jumps)
    int? smoothedSteps = newData.steps;
    if (newData.steps != null && previousData.steps != null) {
      final stepDiff = (newData.steps! - previousData.steps!).abs();
      if (stepDiff > 1000) { // Large jump, smooth it
        smoothedSteps = ((newData.steps! + previousData.steps!) / 2).round();
      }
    }
    
    // Smooth calories (prevent rapid jumps)
    double? smoothedCalories = newData.caloriesBurned;
    if (newData.caloriesBurned != null && previousData.caloriesBurned != null) {
      final calorieDiff = (newData.caloriesBurned! - previousData.caloriesBurned!).abs();
      if (calorieDiff > 500) { // Large jump, smooth it
        smoothedCalories = (newData.caloriesBurned! + previousData.caloriesBurned!) / 2;
      }
    }
    
    return GoogleFitData(
      date: newData.date,
      steps: smoothedSteps,
      caloriesBurned: smoothedCalories,
      distance: newData.distance,
      weight: newData.weight,
    );
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    clearCache();
    print('🗑️ Google Fit performance optimizer disposed');
  }
}
