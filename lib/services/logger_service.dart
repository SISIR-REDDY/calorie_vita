import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../config/production_config.dart';

/// Advanced logging service for production monitoring and debugging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final List<LogEntry> _logs = [];
  final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  final Map<String, int> _logCounts = {};
  
  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;
  Timer? _logFlushTimer;
  
  // Performance tracking
  final Map<String, Stopwatch> _operationTimers = {};
  final Map<String, List<Duration>> _operationDurations = {};
  
  // Streams
  Stream<LogEntry> get logStream => _logController.stream;
  List<LogEntry> get recentLogs => _logs.length > 100 ? _logs.sublist(_logs.length - 100) : _logs;
  
  /// Initialize the logger service
  Future<void> initialize({bool firebaseAvailable = false}) async {
    if (_isInitialized) return;
    
    _isFirebaseAvailable = firebaseAvailable;
    
    // Start periodic log flushing for performance
    _startLogFlushTimer();
    
    // Load cached logs
    await _loadCachedLogs();
    
    _isInitialized = true;
    info('LoggerService initialized', {'firebase_available': firebaseAvailable});
  }
  
  /// Start periodic log flushing
  void _startLogFlushTimer() {
    _logFlushTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _flushLogsToCache();
    });
  }
  
  /// Log info message
  void info(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.info, message, data);
  }
  
  /// Log warning message
  void warning(String message, [Map<String, dynamic>? data]) {
    _log(LogLevel.warning, message, data);
  }
  
  /// Log error message
  void error(String message, [Map<String, dynamic>? data, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, data, stackTrace);
  }
  
  /// Log debug message (only in debug mode)
  void debug(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode || ProductionConfig.isDebug) {
      _log(LogLevel.debug, message, data);
    }
  }
  
  /// Log performance metrics
  void performance(String operation, Duration duration, [Map<String, dynamic>? data]) {
    _log(LogLevel.performance, 'Performance: $operation took ${duration.inMilliseconds}ms', data);
  }
  
  /// Start timing an operation
  void startTimer(String operation) {
    _operationTimers[operation] = Stopwatch()..start();
  }
  
  /// Stop timing an operation and log the result
  Duration stopTimer(String operation, [Map<String, dynamic>? data]) {
    final timer = _operationTimers.remove(operation);
    if (timer == null) {
      warning('Timer for $operation was not started');
      return Duration.zero;
    }
    
    timer.stop();
    final duration = timer.elapsed;
    
    // Record performance data
    _operationDurations.putIfAbsent(operation, () => []).add(duration);
    if (_operationDurations[operation]!.length > 50) {
      _operationDurations[operation]!.removeAt(0);
    }
    
    // Log performance
    performance(operation, duration, data);
    
    return duration;
  }
  
  /// Time an operation with automatic logging
  Future<T> timeOperation<T>(String operation, Future<T> Function() fn, [Map<String, dynamic>? data]) async {
    startTimer(operation);
    try {
      final result = await fn();
      stopTimer(operation, data);
      return result;
    } catch (e, stackTrace) {
      stopTimer(operation, {...?data, 'error': e.toString()});
      error('Operation $operation failed', data, stackTrace);
      rethrow;
    }
  }
  
  /// Log user action for analytics
  void userAction(String action, [Map<String, dynamic>? data]) {
    _log(LogLevel.userAction, 'User Action: $action', data);
    
    // Send to Firebase Analytics if available
    if (_isFirebaseAvailable) {
      try {
        FirebaseAnalytics.instance.logEvent(
          name: action.toLowerCase().replaceAll(' ', '_'),
          parameters: (data ?? {}).cast<String, Object>(),
        );
      } catch (e) {
        debug('Failed to log user action to Firebase Analytics: $e');
      }
    }
  }
  
  /// Log API request
  void apiRequest(String endpoint, String method, [Map<String, dynamic>? data]) {
    _log(LogLevel.api, 'API Request: $method $endpoint', data);
  }
  
  /// Log API response
  void apiResponse(String endpoint, int statusCode, Duration duration, [Map<String, dynamic>? data]) {
    _log(LogLevel.api, 'API Response: $endpoint - $statusCode (${duration.inMilliseconds}ms)', data);
  }
  
  /// Internal log method
  void _log(LogLevel level, String message, [Map<String, dynamic>? data, StackTrace? stackTrace]) {
    if (!_isInitialized) return;
    
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      data: data ?? {},
      stackTrace: stackTrace,
    );
    
    _logs.add(entry);
    _logController.add(entry);
    
    // Update log counts
    _logCounts[level.name] = (_logCounts[level.name] ?? 0) + 1;
    
    // Keep only last 1000 logs for memory efficiency
    if (_logs.length > 1000) {
      _logs.removeAt(0);
    }
    
    // Report to Firebase Crashlytics for errors
    if (level == LogLevel.error && _isFirebaseAvailable) {
      try {
        FirebaseCrashlytics.instance.recordError(
          message,
          stackTrace,
          fatal: false,
          information: [
            'Data: ${jsonEncode(data ?? {})}',
            'Timestamp: ${entry.timestamp.toIso8601String()}',
          ],
        );
      } catch (e) {
        debug('Failed to report error to Firebase Crashlytics: $e');
      }
    }
    
    // Print to console in debug mode
    if (kDebugMode) {
      print('${level.emoji} [${level.name.toUpperCase()}] $message');
      if (data != null && data.isNotEmpty) {
        print('  Data: $data');
      }
    }
  }
  
  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final operation in _operationDurations.keys) {
      final durations = _operationDurations[operation]!;
      if (durations.isNotEmpty) {
        final totalMs = durations.fold(0, (sum, d) => sum + d.inMilliseconds);
        final avgMs = totalMs / durations.length;
        final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        
        stats[operation] = {
          'count': durations.length,
          'avg_ms': avgMs.round(),
          'min_ms': minMs,
          'max_ms': maxMs,
          'total_ms': totalMs,
        };
      }
    }
    
    return stats;
  }
  
  /// Get log statistics
  Map<String, dynamic> getLogStats() {
    return {
      'total_logs': _logs.length,
      'log_counts': Map<String, int>.from(_logCounts),
      'recent_logs_count': recentLogs.length,
      'performance_stats': getPerformanceStats(),
    };
  }
  
  /// Get logs by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }
  
  /// Get recent logs by level
  List<LogEntry> getRecentLogsByLevel(LogLevel level, {int limit = 50}) {
    final logs = getLogsByLevel(level);
    return logs.length > limit ? logs.sublist(logs.length - limit) : logs;
  }
  
  /// Cache logs to local storage
  Future<void> _flushLogsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = _logs.map((log) => log.toMap()).toList();
      final logsString = jsonEncode(logsJson);
      
      await prefs.setString('cached_logs', logsString);
      await prefs.setInt('cached_logs_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      debug('Logs cached to local storage', {'count': _logs.length});
    } catch (e) {
      debug('Failed to cache logs: $e');
    }
  }
  
  /// Load cached logs from local storage
  Future<void> _loadCachedLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsString = prefs.getString('cached_logs');
      final cacheTimestamp = prefs.getInt('cached_logs_timestamp') ?? 0;
      
      if (logsString != null) {
        // Only load logs from last 24 hours
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        if (cacheAge < 86400000) { // 24 hours
          final logsJson = jsonDecode(logsString) as List;
          final cachedLogs = logsJson.map((json) => LogEntry.fromMap(json)).toList();
          
          _logs.addAll(cachedLogs);
          debug('Loaded cached logs', {'count': cachedLogs.length});
        }
      }
    } catch (e) {
      debug('Failed to load cached logs: $e');
    }
  }
  
  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    _logCounts.clear();
    _operationTimers.clear();
    _operationDurations.clear();
    info('All logs cleared');
  }
  
  /// Export logs for debugging
  Map<String, dynamic> exportLogs() {
    return {
      'export_timestamp': DateTime.now().toIso8601String(),
      'log_stats': getLogStats(),
      'logs': _logs.map((log) => log.toMap()).toList(),
    };
  }
  
  /// Dispose resources
  void dispose() {
    _logFlushTimer?.cancel();
    _logController.close();
  }
}

/// Log levels
enum LogLevel {
  debug('🐛', 'debug'),
  info('ℹ️', 'info'),
  warning('⚠️', 'warning'),
  error('❌', 'error'),
  performance('⚡', 'performance'),
  userAction('👤', 'user_action'),
  api('🌐', 'api');
  
  const LogLevel(this.emoji, this.name);
  final String emoji;
  final String name;
}

/// Log entry model
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic> data;
  final StackTrace? stackTrace;
  
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.data,
    this.stackTrace,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'data': data,
      'has_stack_trace': stackTrace != null,
    };
  }
  
  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      timestamp: DateTime.parse(map['timestamp']),
      level: LogLevel.values.firstWhere((l) => l.name == map['level']),
      message: map['message'],
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }
  
  @override
  String toString() {
    return '${level.emoji} [${level.name.toUpperCase()}] $message';
  }
}
