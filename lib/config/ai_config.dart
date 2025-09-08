/// AI Configuration for OpenRouter API
/// 
/// This file contains configuration settings for AI features.
/// Replace the placeholder API key with your actual OpenRouter API key.
class AIConfig {
  /// OpenRouter API Key
  /// Get your free API key from: https://openrouter.ai/
  static const String apiKey = 'AI-API-KEY-HERE';
  
  /// OpenRouter API Base URL
  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  /// Model configurations
  static const String chatModel = 'openai/gpt-3.5-turbo';
  static const String visionModel = 'nousresearch/nous-hermes-2-vision';
  
  /// API request settings
  static const int maxTokens = 1000;
  static const double temperature = 0.7;
  
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
