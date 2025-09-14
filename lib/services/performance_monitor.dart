import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Performance monitoring service to track app performance and identify bottlenecks
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, Stopwatch> _timers = {};
  final Map<String, List<Duration>> _operationTimes = {};
  final Map<String, int> _operationCounts = {};
  final List<PerformanceEvent> _events = [];

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Connectivity _connectivity = Connectivity();

  String? _deviceModel;
  String? _appVersion;
  String? _connectivityType;
  bool _isInitialized = false;

  /// Initialize the performance monitor
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get device information
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceModel = '${iosInfo.name} ${iosInfo.model}';
      }

      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      // Monitor connectivity
      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        _connectivityType = results.toString();
        logEvent('connectivity_changed', {'type': _connectivityType});
      });

      // Get initial connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      _connectivityType = connectivityResults.toString();

      _isInitialized = true;
      logEvent('performance_monitor_initialized', {
        'device': _deviceModel,
        'app_version': _appVersion,
        'connectivity': _connectivityType,
      });

      print('PerformanceMonitor initialized');
    } catch (e) {
      print('Error initializing PerformanceMonitor: $e');
    }
  }

  /// Start timing an operation
  void startTimer(String operationName) {
    _timers[operationName] = Stopwatch()..start();
  }

  /// Stop timing an operation and record the duration
  Duration stopTimer(String operationName) {
    final timer = _timers.remove(operationName);
    if (timer == null) {
      print('Warning: Timer for $operationName was not started');
      return Duration.zero;
    }

    timer.stop();
    final duration = timer.elapsed;

    // Record the operation time
    _operationTimes.putIfAbsent(operationName, () => []).add(duration);
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;

    // Log the event
    logEvent('operation_completed', {
      'operation': operationName,
      'duration_ms': duration.inMilliseconds,
      'success': true,
    });

    // Keep only last 100 measurements per operation
    if (_operationTimes[operationName]!.length > 100) {
      _operationTimes[operationName]!.removeAt(0);
    }

    return duration;
  }

  /// Time an operation with automatic cleanup
  Future<T> timeOperation<T>(
      String operationName, Future<T> Function() operation) async {
    startTimer(operationName);
    try {
      final result = await operation();
      stopTimer(operationName);
      return result;
    } catch (e) {
      stopTimer(operationName);
      logEvent('operation_failed', {
        'operation': operationName,
        'error': e.toString(),
        'success': false,
      });
      rethrow;
    }
  }

  /// Time a synchronous operation
  T timeSyncOperation<T>(String operationName, T Function() operation) {
    startTimer(operationName);
    try {
      final result = operation();
      stopTimer(operationName);
      return result;
    } catch (e) {
      stopTimer(operationName);
      logEvent('operation_failed', {
        'operation': operationName,
        'error': e.toString(),
        'success': false,
      });
      rethrow;
    }
  }

  /// Log a performance event
  void logEvent(String eventType, Map<String, dynamic> data) {
    final event = PerformanceEvent(
      timestamp: DateTime.now(),
      eventType: eventType,
      data: data,
    );

    _events.add(event);

    // Keep only last 1000 events
    if (_events.length > 1000) {
      _events.removeAt(0);
    }

    if (kDebugMode) {
      print('Performance Event: $eventType - $data');
    }
  }

  /// Get performance statistics for an operation
  Map<String, dynamic> getOperationStats(String operationName) {
    final times = _operationTimes[operationName] ?? [];
    final count = _operationCounts[operationName] ?? 0;

    if (times.isEmpty) {
      return {
        'operation': operationName,
        'count': 0,
        'average_ms': 0,
        'min_ms': 0,
        'max_ms': 0,
        'total_ms': 0,
      };
    }

    final totalMs =
        times.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    final averageMs = totalMs / times.length;
    final minMs =
        times.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
    final maxMs =
        times.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);

    return {
      'operation': operationName,
      'count': count,
      'average_ms': averageMs.round(),
      'min_ms': minMs,
      'max_ms': maxMs,
      'total_ms': totalMs,
    };
  }

  /// Get all performance statistics
  Map<String, dynamic> getAllStats() {
    final operationStats = <String, Map<String, dynamic>>{};

    for (final operation in _operationTimes.keys) {
      operationStats[operation] = getOperationStats(operation);
    }

    return {
      'device_info': {
        'model': _deviceModel,
        'app_version': _appVersion,
        'connectivity': _connectivityType,
        'platform': Platform.operatingSystem,
      },
      'operations': operationStats,
      'total_events': _events.length,
      'recent_events': _events.length > 10
          ? _events.sublist(_events.length - 10).map((e) => e.toMap()).toList()
          : _events.map((e) => e.toMap()).toList(),
    };
  }

  /// Get slow operations (above threshold)
  List<Map<String, dynamic>> getSlowOperations({int thresholdMs = 1000}) {
    final slowOps = <Map<String, dynamic>>[];

    for (final operation in _operationTimes.keys) {
      final stats = getOperationStats(operation);
      if (stats['average_ms'] > thresholdMs) {
        slowOps.add(stats);
      }
    }

    // Sort by average time descending
    slowOps.sort(
        (a, b) => (b['average_ms'] as int).compareTo(a['average_ms'] as int));

    return slowOps;
  }

  /// Get recent events of a specific type
  List<Map<String, dynamic>> getRecentEvents(String eventType,
      {int limit = 10}) {
    final filteredEvents =
        _events.where((event) => event.eventType == eventType).toList();
    final startIndex =
        filteredEvents.length > limit ? filteredEvents.length - limit : 0;
    return filteredEvents
        .sublist(startIndex)
        .map((event) => event.toMap())
        .toList();
  }

  /// Check if app is performing well
  bool isPerformanceGood() {
    final slowOps = getSlowOperations(thresholdMs: 2000);
    return slowOps.isEmpty;
  }

  /// Get performance recommendations
  List<String> getPerformanceRecommendations() {
    final recommendations = <String>[];
    final slowOps = getSlowOperations(thresholdMs: 1000);

    for (final op in slowOps) {
      final operation = op['operation'] as String;
      final avgMs = op['average_ms'] as int;

      if (operation.contains('firebase')) {
        recommendations
            .add('Consider adding caching for $operation (avg: ${avgMs}ms)');
      } else if (operation.contains('image')) {
        recommendations.add(
            'Consider image optimization for $operation (avg: ${avgMs}ms)');
      } else if (operation.contains('network')) {
        recommendations
            .add('Check network connectivity for $operation (avg: ${avgMs}ms)');
      } else {
        recommendations.add('Optimize $operation (avg: ${avgMs}ms)');
      }
    }

    // Check for memory issues
    final totalEvents = _events.length;
    if (totalEvents > 500) {
      recommendations.add('Consider reducing event logging frequency');
    }

    return recommendations;
  }

  /// Clear all performance data
  void clearData() {
    _timers.clear();
    _operationTimes.clear();
    _operationCounts.clear();
    _events.clear();
    print('Performance data cleared');
  }

  /// Export performance data for analysis
  Map<String, dynamic> exportData() {
    return {
      'export_timestamp': DateTime.now().toIso8601String(),
      'device_info': {
        'model': _deviceModel,
        'app_version': _appVersion,
        'connectivity': _connectivityType,
        'platform': Platform.operatingSystem,
      },
      'statistics': getAllStats(),
      'events': _events.map((e) => e.toMap()).toList(),
    };
  }
}

/// Performance event model
class PerformanceEvent {
  final DateTime timestamp;
  final String eventType;
  final Map<String, dynamic> data;

  PerformanceEvent({
    required this.timestamp,
    required this.eventType,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'event_type': eventType,
      'data': data,
    };
  }
}
