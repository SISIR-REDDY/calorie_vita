import '../services/firestore_config_service.dart';

/// Secure AI Configuration using Firestore
/// This class provides secure access to API keys and configuration
/// without exposing sensitive data in the client code
/// 
/// IMPORTANT: There is ONE API key used for everything in the app:
/// - Chat (Trainer Sisir)
/// - Vision (Snap to Calorie)
/// - Analytics
/// - Recommendations
/// - All AI features
/// 
/// The API key is stored in Firestore at: app_config/ai_settings/openrouter_api_key
/// If Firestore fails, it falls back to a default key (for development only)
class AIConfig {
  static FirestoreConfigService get _config => FirestoreConfigService();
  
  /// Initialize the configuration service
  static Future<void> initialize() async {
    await _config.initialize();
  }
  
  /// Refresh configuration from Firebase
  static Future<void> refresh() async {
    await _config.refresh();
  }

  /// Secure API Key from Firebase Remote Config
  /// 
  /// THIS IS THE SINGLE API KEY USED FOR EVERYTHING IN THE APP:
  /// - Chat (Trainer Sisir) uses: AIConfig.apiKey
  /// - Vision (Snap to Calorie) uses: AIConfig.apiKey
  /// - Analytics uses: AIConfig.apiKey
  /// - All AI services use: AIConfig.apiKey
  /// 
  /// Source: Firestore app_config/ai_settings/openrouter_api_key
  /// IMPORTANT: API key MUST be configured in Firebase - NO fallback in code
  /// If API key is empty, AI features will not work
  static String get apiKey => _config.getString('openrouter_api_key');
  
  /// Base URL for API calls
  static String get baseUrl => _config.getString('openrouter_base_url', 
      defaultValue: 'https://openrouter.ai/api/v1/chat/completions');

  /// AI Models
  static String get chatModel => _config.getString('chat_model', 
      defaultValue: 'openai/gpt-3.5-turbo');
  static String get visionModel => _config.getString('vision_model', 
      defaultValue: 'openai/gpt-4o-mini'); // Primary vision model - fastest for food recognition
  static String get backupVisionModel => _config.getString('backup_vision_model', 
      defaultValue: 'openai/gpt-4o'); // Backup vision model - more accurate if needed
  static String get fallbackVisionModel => _config.getString('fallback_vision_model', 
      defaultValue: 'openai/gpt-4-turbo'); // Fallback vision model (supports vision)

  /// Token Limits
  static int get maxTokens => _config.getInt('max_tokens', defaultValue: 100);
  static int get chatMaxTokens => _config.getInt('chat_max_tokens', defaultValue: 100);
  static int get analyticsMaxTokens => _config.getInt('analytics_max_tokens', defaultValue: 120);
  static int get visionMaxTokens => _config.getInt('vision_max_tokens', defaultValue: 150); // Optimized for speed
  
  /// Temperature Settings
  static double get temperature => _config.getDouble('temperature', defaultValue: 0.7);
  static double get visionTemperature => _config.getDouble('vision_temperature', defaultValue: 0.1); // Lower for faster, more deterministic responses

  /// App identification for OpenRouter
  static String get appName => _config.getString('app_name', defaultValue: 'Calorie Vita');
  static String get appUrl => _config.getString('app_url', defaultValue: 'https://calorievita.com');

  /// Rate limiting settings
  static int get maxRequestsPerMinute => _config.getInt('max_requests_per_minute', defaultValue: 30);
  static Duration get requestTimeout => Duration(
      seconds: _config.getInt('request_timeout_seconds', defaultValue: 15));

  /// Vision-specific settings
  static int get visionRetryAttempts => _config.getInt('vision_retry_attempts', defaultValue: 3);
  static bool get visionFallbackEnabled => _config.getBool('vision_fallback_enabled', defaultValue: true);

  /// Feature flags
  static bool get enableChat => _config.getBool('enable_chat', defaultValue: true);
  static bool get enableAnalytics => _config.getBool('enable_analytics', defaultValue: true);
  static bool get enableRecommendations => _config.getBool('enable_recommendations', defaultValue: true);
  static bool get enableImageAnalysis => _config.getBool('enable_image_analysis', defaultValue: true);

  /// Debug settings
  static bool get enableDebugLogs => _config.getBool('enable_debug_logs', defaultValue: false);
  static bool get enableApiResponseLogging => _config.getBool('enable_api_response_logging', defaultValue: false);
  
  /// Get last configuration fetch time
  static DateTime? get lastFetchTime => _config.getLastFetchTime();
  
  /// Get all configuration for debugging (sensitive values masked)
  static Map<String, dynamic> getDebugConfig() {
    final config = _config.getAllConfig();
    // Mask sensitive values for security
    if (config.containsKey('openrouter_api_key')) {
      final apiKey = config['openrouter_api_key'] as String;
      config['openrouter_api_key'] = '${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}';
    }
    return config;
  }
}
