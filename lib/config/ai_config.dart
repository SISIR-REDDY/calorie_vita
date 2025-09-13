/// AI Configuration for OpenRouter API
/// 
/// This file contains configuration settings for AI features.
/// Replace the placeholder API key with your actual OpenRouter API key.
class AIConfig {
  /// OpenRouter API Key
  /// Get your free API key from: https://openrouter.ai/
  static const String apiKey = '';
  
  /// OpenRouter API Base URL
  static const String baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  /// Model configurations
  static const String chatModel = 'openai/gpt-3.5-turbo';
  static const String visionModel = 'openai/gpt-4o'; // Best vision model for food analysis
  static const String backupVisionModel = 'google/gemini-pro-1.5'; // Backup option
  
  /// API request settings
  static const int maxTokens = 1000;
  static const int chatMaxTokens = 300; // Shorter responses for chat
  static const int analyticsMaxTokens = 400; // Medium length for analytics
  static const int visionMaxTokens = 2000; // More tokens for detailed food analysis
  static const double temperature = 0.7;
  static const double visionTemperature = 0.3; // Lower temperature for more consistent food analysis
  
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
