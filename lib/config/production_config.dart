/// Production configuration with enhanced security and performance settings
class ProductionConfig {
  // Environment detection
  static const bool isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const bool isDebug = bool.fromEnvironment('DEBUG', defaultValue: true);
  
  // API Configuration with environment-based keys
  static String get openRouterApiKey {
    if (isProduction) {
      return const String.fromEnvironment('OPENROUTER_API_KEY_PROD', defaultValue: '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');
    } else {
      return const String.fromEnvironment('OPENROUTER_API_KEY_DEV', defaultValue: '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');
    }
  }
  
  // Enhanced AI Configuration for better accuracy and speed
  static const Map<String, dynamic> aiConfig = {
    'chat_model': 'openai/gpt-3.5-turbo',
    'vision_model': 'google/gemini-pro-1.5-exp',
    'backup_vision_model': 'google/gemini-pro-1.5',
    'max_tokens_chat': 130, // Balanced responses (80-100 words)
    'max_tokens_vision': 350, // Increased for more detailed analysis
    'temperature_chat': 0.8, // Higher for friendly responses
    'temperature_vision': 0.05, // Very low for consistent food recognition
    'timeout_seconds': 20, // Optimized for speed
    'retry_attempts': 3, // Add retry logic for better accuracy
    'cache_duration_minutes': 45, // Longer cache for better performance
    'confidence_threshold': 0.75, // Higher threshold for better accuracy
  };
  
  // Performance optimization settings
  static const Map<String, dynamic> performanceConfig = {
    'image_max_size': 1200, // Optimized for better AI accuracy
    'image_quality': 90, // Higher quality for better food recognition
    'cache_size_mb': 75, // Increased cache for better performance
    'max_concurrent_requests': 2, // Reduced for better stability
    'request_timeout_ms': 20000, // 20 second timeout for better reliability
    'enable_image_compression': true,
    'enable_response_caching': true,
    'enable_lazy_loading': true,
    'enable_parallel_processing': true, // Enable parallel image processing
    'memory_optimization': true, // Enable memory optimization
  };
  
  // Firebase configuration
  static const Map<String, dynamic> firebaseConfig = {
    'enable_crashlytics': true,
    'enable_analytics': true,
    'enable_performance_monitoring': true,
    'batch_size': 100, // Batch operations for better performance
    'retry_attempts': 3,
    'timeout_seconds': 10,
  };
  
  // Security settings
  static const Map<String, dynamic> securityConfig = {
    'enable_certificate_pinning': true,
    'enable_request_signing': true,
    'max_request_size_mb': 10,
    'rate_limit_requests_per_minute': 60,
    'enable_input_validation': true,
    'enable_sql_injection_protection': true,
  };
  
  // Feature flags for gradual rollout
  static const Map<String, bool> featureFlags = {
    'enable_advanced_ai_analysis': true,
    'enable_offline_mode': true,
    'enable_smart_caching': true,
    'enable_performance_monitoring': true,
    'enable_advanced_error_handling': true,
    'enable_user_analytics': true,
  };
  
  // App metadata
  static const String appName = 'Calorie Vita';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String appUrl = 'https://calorievita.com';
  
  // Validation methods
  static bool isValidApiKey(String key) {
    return key.isNotEmpty && key.length >= 20;
  }
  
  static bool isFeatureEnabled(String feature) {
    return featureFlags[feature] ?? false;
  }
  
  static Map<String, dynamic> getConfigForEnvironment() {
    return {
      'is_production': isProduction,
      'is_debug': isDebug,
      'ai_config': aiConfig,
      'performance_config': performanceConfig,
      'firebase_config': firebaseConfig,
      'security_config': securityConfig,
      'feature_flags': featureFlags,
    };
  }
}
