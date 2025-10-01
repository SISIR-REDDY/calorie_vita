class AIConfig {
  static const String apiKey = String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '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');

  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const String chatModel = 'openai/gpt-3.5-turbo'; // OpenAI (PAID - not free!)
  static const String visionModel = 'google/gemini-pro-1.5-exp'; // Vision model for food recognition
  static const String backupVisionModel = 'google/gemini-pro-1.5'; // Fast backup option

  static const int maxTokens = 100;
  static const int chatMaxTokens = 100; // Optimized for speed (60-80 words)
  static const int analyticsMaxTokens = 120;
  static const int visionMaxTokens = 300; // Optimized for faster vision analysis
  static const double temperature = 0.7; // Balanced for speed and quality
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
