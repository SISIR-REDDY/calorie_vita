class AIConfig {
  static const String apiKey = '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';

  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String chatModel = 'openai/gpt-3.5-turbo';
  static const String visionModel =
      'microsoft/phi-3-vision-128k-instruct'; // Cost-effective vision model
  static const String backupVisionModel =
      'meta-llama/llama-3.2-11b-vision-instruct'; // Backup option

  static const int maxTokens = 800;
  static const int chatMaxTokens = 250;
  static const int analyticsMaxTokens = 300;
  static const int visionMaxTokens = 1500;
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
