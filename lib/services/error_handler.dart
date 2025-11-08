import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../config/production_config.dart';

/// Comprehensive error handling service
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final List<ErrorEvent> _errors = [];
  final StreamController<ErrorEvent> _errorController =
      StreamController<ErrorEvent>.broadcast();

  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;

  // Streams
  Stream<ErrorEvent> get errorStream => _errorController.stream;
  List<ErrorEvent> get recentErrors =>
      _errors.length > 50 ? _errors.sublist(_errors.length - 50) : _errors;

  /// Initialize the error handler
  Future<void> initialize({bool firebaseAvailable = false}) async {
    if (_isInitialized) return;

    _isFirebaseAvailable = firebaseAvailable;

    // Set up Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(
        ErrorType.flutter,
        details.exception.toString(),
        stackTrace: details.stack,
        context: details.context?.toString(),
      );
    };

    // Set up zone error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(
        ErrorType.platform,
        error.toString(),
        stackTrace: stack,
      );
      return true;
    };

    _isInitialized = true;
    if (kDebugMode) debugPrint('ErrorHandler initialized');
  }

  /// Handle an error
  void _handleError(
    ErrorType type,
    String message, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    if (!_isInitialized) {
      if (kDebugMode) debugPrint('ErrorHandler not initialized, cannot handle error: $message');
      return;
    }

    final error = ErrorEvent(
      timestamp: DateTime.now(),
      type: type,
      message: message,
      stackTrace: stackTrace,
      context: context,
      additionalData: additionalData ?? {},
    );

    _errors.add(error);
    _errorController.add(error);

    // Keep only last 100 errors
    if (_errors.length > 100) {
      _errors.removeAt(0);
    }

    // Log to console in debug mode
    if (kDebugMode) {
      if (kDebugMode) debugPrint('🚨 Error [${type.name}]: $message');
      if (stackTrace != null) {
        if (kDebugMode) debugPrint('Stack trace: $stackTrace');
      }
    }

    // Report to Firebase if available
    if (_isFirebaseAvailable) {
      _reportToFirebase(error);
    }
  }

  /// Report error to Firebase
  void _reportToFirebase(ErrorEvent error) {
    try {
      // Report to Crashlytics
      FirebaseCrashlytics.instance.recordError(
        error.message,
        error.stackTrace,
        fatal:
            error.type == ErrorType.flutter || error.type == ErrorType.platform,
        information: [
          'Type: ${error.type.name}',
          'Context: ${error.context ?? 'N/A'}',
          'Additional Data: ${error.additionalData}',
        ],
      );

      // Log to Analytics
      FirebaseAnalytics.instance.logEvent(
        name: 'error_occurred',
        parameters: {
          'error_type': error.type.name,
          'error_message': error.message.length > 100
              ? error.message.substring(0, 100)
              : error.message,
          'has_stack_trace': error.stackTrace != null,
          'has_context': error.context != null,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to report error to Firebase: $e');
    }
  }

  /// Handle Firebase errors
  void handleFirebaseError(String operation, dynamic error,
      {StackTrace? stackTrace}) {
    _handleError(
      ErrorType.firebase,
      'Firebase $operation failed: $error',
      stackTrace: stackTrace,
      additionalData: {'operation': operation},
    );
  }

  /// Handle network errors
  void handleNetworkError(String operation, dynamic error,
      {StackTrace? stackTrace}) {
    _handleError(
      ErrorType.network,
      'Network $operation failed: $error',
      stackTrace: stackTrace,
      additionalData: {'operation': operation},
    );
  }

  /// Handle authentication errors
  void handleAuthError(String operation, dynamic error,
      {StackTrace? stackTrace}) {
    _handleError(
      ErrorType.authentication,
      'Auth $operation failed: $error',
      stackTrace: stackTrace,
      additionalData: {'operation': operation},
    );
  }

  /// Handle data processing errors
  void handleDataError(String operation, dynamic error,
      {StackTrace? stackTrace}) {
    _handleError(
      ErrorType.data,
      'Data $operation failed: $error',
      stackTrace: stackTrace,
      additionalData: {'operation': operation},
    );
  }

  /// Handle UI errors
  void handleUIError(String operation, dynamic error,
      {StackTrace? stackTrace}) {
    _handleError(
      ErrorType.ui,
      'UI $operation failed: $error',
      stackTrace: stackTrace,
      additionalData: {'operation': operation},
    );
  }

  /// Handle business logic errors
  void handleBusinessError(String operation, dynamic error,
      {StackTrace? stackTrace}) {
    _handleError(
      ErrorType.business,
      'Business $operation failed: $error',
      stackTrace: stackTrace,
      additionalData: {'operation': operation},
    );
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    final errorCounts = <ErrorType, int>{};
    final recentErrorCounts = <ErrorType, int>{};

    for (final error in _errors) {
      errorCounts[error.type] = (errorCounts[error.type] ?? 0) + 1;
    }

    final recentErrors = _errors.length > 24
        ? _errors.sublist(_errors.length - 24)
        : _errors; // Last 24 hours
    for (final error in recentErrors) {
      recentErrorCounts[error.type] = (recentErrorCounts[error.type] ?? 0) + 1;
    }

    return {
      'total_errors': _errors.length,
      'recent_errors': recentErrors.length,
      'error_counts': errorCounts.map((k, v) => MapEntry(k.name, v)),
      'recent_error_counts':
          recentErrorCounts.map((k, v) => MapEntry(k.name, v)),
      'last_error': _errors.isNotEmpty ? _errors.last.toMap() : null,
    };
  }

  /// Get errors by type
  List<ErrorEvent> getErrorsByType(ErrorType type) {
    return _errors.where((error) => error.type == type).toList();
  }

  /// Get recent errors (last N hours)
  List<ErrorEvent> getRecentErrors({int hours = 24}) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    return _errors.where((error) => error.timestamp.isAfter(cutoff)).toList();
  }

  /// Clear all errors
  void clearErrors() {
    _errors.clear();
    if (kDebugMode) debugPrint('All errors cleared');
  }

  /// Clear errors by type
  void clearErrorsByType(ErrorType type) {
    _errors.removeWhere((error) => error.type == type);
    if (kDebugMode) debugPrint('Errors of type ${type.name} cleared');
  }

  /// Check if there are critical errors
  bool hasCriticalErrors() {
    return _errors.any((error) =>
        error.type == ErrorType.flutter ||
        error.type == ErrorType.platform ||
        error.message.toLowerCase().contains('fatal'));
  }

  /// Get error recommendations
  List<String> getErrorRecommendations() {
    final recommendations = <String>[];
    final stats = getErrorStats();

    // Check for high error rates
    final totalErrors = stats['total_errors'] as int;
    if (totalErrors > 50) {
      recommendations
          .add('High error count detected. Consider reviewing error logs.');
    }

    // Check for specific error patterns
    final firebaseErrors = getErrorsByType(ErrorType.firebase).length;
    if (firebaseErrors > 10) {
      recommendations.add(
          'Multiple Firebase errors detected. Check Firebase configuration.');
    }

    final networkErrors = getErrorsByType(ErrorType.network).length;
    if (networkErrors > 20) {
      recommendations.add(
          'Network connectivity issues detected. Check internet connection.');
    }

    final authErrors = getErrorsByType(ErrorType.authentication).length;
    if (authErrors > 5) {
      recommendations
          .add('Authentication issues detected. Check user credentials.');
    }

    return recommendations;
  }

  /// Dispose resources
  void dispose() {
    _errorController.close();
  }
}

/// Error types
enum ErrorType {
  flutter,
  platform,
  firebase,
  network,
  authentication,
  data,
  ui,
  business,
}

/// Error event model
class ErrorEvent {
  final DateTime timestamp;
  final ErrorType type;
  final String message;
  final StackTrace? stackTrace;
  final String? context;
  final Map<String, dynamic> additionalData;

  ErrorEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    this.stackTrace,
    this.context,
    this.additionalData = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'message': message,
      'context': context,
      'additional_data': additionalData,
      'has_stack_trace': stackTrace != null,
    };
  }

  @override
  String toString() {
    return 'ErrorEvent(type: ${type.name}, message: $message, timestamp: $timestamp)';
  }
}

