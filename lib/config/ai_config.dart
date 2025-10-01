class AIConfig {
  static const String apiKey = String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: 'YOUR_OPENROUTER_API_KEY_HERE');

  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String chatModel = 'xai/grok-beta';
  static const String visionModel = 'google/gemini-2.0-flash-exp'; // Fast and accurate vision model for food recognition
  static const String backupVisionModel = 'google/gemini-1.5-flash'; // Fast backup option

  static const int maxTokens = 100;
  static const int chatMaxTokens = 100;
  static const int analyticsMaxTokens = 100;
  static const int visionMaxTokens = 300; // Increased for more detailed food analysis
  static const double temperature = 0.7;
  static const double visionTemperature = 0.1; // Lower for more consistent food recognition

  /// App identification for OpenRouter
  static const String appName = 'Calorie Vita';
  static const String appUrl = 'https://calorievita.com';

  /// Rate limiting settings
  static const int maxRequestsPerMinute = 60;
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Feature flags
  static const bool enableChat = true;
  static const bool enableAnalytics = true;
  static const bool enableRecommendations = true;
  static const bool enableImageAnalysis = true;

  /// Debug settings
  static const bool enableDebugLogs = true;
  static const bool enableApiResponseLogging = false;
}
