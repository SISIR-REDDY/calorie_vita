import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import '../models/user_goals.dart';
import '../models/user_preferences.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';

/// Performance optimization service for caching and lazy loading
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Cache management
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Duration _cacheExpiry = const Duration(minutes: 5);

  // Lazy loading
  final Map<String, Completer<dynamic>> _loadingOperations = {};

  /// Get cached data or load from source
  Future<T?> getCachedData<T>(
    String key,
    Future<T> Function() loader, {
    Duration? expiry,
  }) async {
    // Check memory cache first
    if (_memoryCache.containsKey(key) && !_isCacheExpired(key, expiry)) {
      return _memoryCache[key] as T?;
    }

    // Check if already loading
    if (_loadingOperations.containsKey(key)) {
      return await _loadingOperations[key]!.future as T?;
    }

    // Start loading
    final completer = Completer<T?>();
    _loadingOperations[key] = completer;

    try {
      final data = await loader();
      _memoryCache[key] = data;
      _cacheTimestamps[key] = DateTime.now();
      completer.complete(data);
      return data;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loadingOperations.remove(key);
    }
  }

  /// Check if cache is expired
  bool _isCacheExpired(String key, Duration? customExpiry) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return true;
    
    final expiry = customExpiry ?? _cacheExpiry;
    return DateTime.now().difference(timestamp) > expiry;
  }

  /// Clear cache
  void clearCache([String? key]) {
    if (key != null) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    } else {
      _memoryCache.clear();
      _cacheTimestamps.clear();
    }
  }

  /// Preload data
  Future<void> preloadData(String key, Future<dynamic> Function() loader) async {
    if (!_memoryCache.containsKey(key) || _isCacheExpired(key, null)) {
      try {
        final data = await loader();
        _memoryCache[key] = data;
        _cacheTimestamps[key] = DateTime.now();
      } catch (e) {
        print('Error preloading data for key $key: $e');
      }
    }
  }

  /// Optimize image loading
  Widget buildOptimizedImage({
    required String imageUrl,
    required Widget placeholder,
    required Widget errorWidget,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder;
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget;
      },
      // Enable caching
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
    );
  }

  /// Debounce function calls
  Timer? _debounceTimer;
  void debounce(VoidCallback callback, {Duration delay = const Duration(milliseconds: 300)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, callback);
  }

  /// Throttle function calls
  DateTime? _lastThrottleCall;
  bool throttle(VoidCallback callback, {Duration delay = const Duration(milliseconds: 1000)}) {
    final now = DateTime.now();
    if (_lastThrottleCall == null || now.difference(_lastThrottleCall!) > delay) {
      _lastThrottleCall = now;
      callback();
      return true;
    }
    return false;
  }

  /// Batch operations
  final List<Future<void> Function()> _batchOperations = [];
  Timer? _batchTimer;

  void addBatchOperation(Future<void> Function() operation) {
    _batchOperations.add(operation);
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), _executeBatch);
  }

  Future<void> _executeBatch() async {
    if (_batchOperations.isEmpty) return;

    final operations = List<Future<void> Function()>.from(_batchOperations);
    _batchOperations.clear();

    try {
      await Future.wait(operations.map((op) => op()));
    } catch (e) {
      print('Error executing batch operations: $e');
    }
  }

  /// Lazy loading widget
  Widget buildLazyLoadingWidget({
    required String key,
    required Future<Widget> Function() loader,
    required Widget placeholder,
    required Widget errorWidget,
  }) {
    return FutureBuilder<Widget?>(
      future: getCachedData(key, loader),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder;
        } else if (snapshot.hasError) {
          return errorWidget;
        } else if (snapshot.hasData && snapshot.data != null) {
          return snapshot.data!;
        } else {
          return placeholder;
        }
      },
    );
  }

  /// Optimize list rendering
  Widget buildOptimizedList<T>({
    required List<T> items,
    required Widget Function(BuildContext context, T item, int index) itemBuilder,
    ScrollController? controller,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
  }) {
    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return itemBuilder(context, items[index], index);
      },
      // Performance optimizations
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      addSemanticIndexes: false,
    );
  }

  /// Memory management
  void optimizeMemoryUsage() {
    // Clear old cache entries
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Get memory usage info
  Map<String, dynamic> getMemoryInfo() {
    return {
      'cacheSize': _memoryCache.length,
      'cacheKeys': _memoryCache.keys.toList(),
      'loadingOperations': _loadingOperations.length,
    };
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _batchTimer?.cancel();
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _loadingOperations.clear();
  }
}
