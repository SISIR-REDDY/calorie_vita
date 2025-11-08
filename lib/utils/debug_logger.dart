import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Global debug logging utility that respects production mode
/// This prevents excessive logging in production builds
class DebugLogger {
  /// Log debug message (only in debug mode)
  static void log(String message) {
    if (ProductionConfig.enableDebugLogs) {
      debugPrint(message);
    }
  }

  /// Log info message (only in debug mode)
  static void info(String message) {
    if (ProductionConfig.enableInfoLogs) {
      debugPrint('ℹ️ $message');
    }
  }

  /// Log warning message (only in debug mode)
  static void warning(String message) {
    if (ProductionConfig.enableInfoLogs) {
      debugPrint('⚠️ $message');
    }
  }

  /// Log error message (always logged)
  static void error(String message) {
    debugPrint('❌ $message');
  }

  /// Log success message (only in debug mode)
  static void success(String message) {
    if (ProductionConfig.enableDebugLogs) {
      debugPrint('✅ $message');
    }
  }

  /// Log performance message (only in debug mode)
  static void performance(String message) {
    if (ProductionConfig.enablePerformanceLogs) {
      debugPrint('⚡ $message');
    }
  }
}

