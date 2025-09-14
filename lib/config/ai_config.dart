class AIConfig {
  static const String apiKey = '';

  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String chatModel = 'openai/gpt-3.5-turbo';
  static const String visionModel =
      'openai/gpt-4o'; // Best vision model for food analysis
  static const String backupVisionModel =
      'google/gemini-pro-1.5'; // Backup option

  static const int maxTokens = 1000;
  static const int chatMaxTokens = 300;
  static const int analyticsMaxTokens = 400;
  static const int visionMaxTokens = 2000;
  static const double temperature = 0.7;
  static const double visionTemperature = 0.3;

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
