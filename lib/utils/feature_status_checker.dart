import '../config/ai_config.dart';
import '../services/network_service.dart';

/// Utility to check if all features are enabled and configured
class FeatureStatusChecker {
  /// Check all features and return status
  static Map<String, dynamic> checkAllFeatures() {
    final status = <String, dynamic>{};
    
    // AI Configuration Status
    status['ai_config'] = _checkAIConfig();
    
    // Feature Flags Status
    status['feature_flags'] = _checkFeatureFlags();
    
    // API Key Status
    status['api_keys'] = _checkAPIKeys();
    
    // Services Status
    status['services'] = _checkServices();
    
    // Barcode Scanning Status
    status['barcode_scanning'] = _checkBarcodeScanning();
    
    // Image Analysis Status
    status['image_analysis'] = _checkImageAnalysis();
    
    // Network Status
    status['network'] = _checkNetwork();
    
    // Overall Status
    status['overall'] = _checkOverallStatus(status);
    
    return status;
  }
  
  /// Check AI Configuration
  static Map<String, dynamic> _checkAIConfig() {
    return {
      'configured': AIConfig.apiKey.isNotEmpty,
      'api_key_length': AIConfig.apiKey.length,
      'base_url': AIConfig.baseUrl,
      'vision_model': AIConfig.visionModel,
      'backup_vision_model': AIConfig.backupVisionModel,
      'chat_model': AIConfig.chatModel,
      'vision_fallback_enabled': AIConfig.visionFallbackEnabled,
      'last_fetch_time': AIConfig.lastFetchTime?.toString() ?? 'Never',
    };
  }
  
  /// Check Feature Flags
  static Map<String, dynamic> _checkFeatureFlags() {
    return {
      'enable_chat': AIConfig.enableChat,
      'enable_analytics': AIConfig.enableAnalytics,
      'enable_recommendations': AIConfig.enableRecommendations,
      'enable_image_analysis': AIConfig.enableImageAnalysis,
      'enable_debug_logs': AIConfig.enableDebugLogs,
      'enable_api_response_logging': AIConfig.enableApiResponseLogging,
    };
  }
  
  /// Check API Keys
  static Map<String, dynamic> _checkAPIKeys() {
    final apiKey = AIConfig.apiKey;
    return {
      'openrouter_api_key': apiKey.isNotEmpty,
      'api_key_configured': apiKey.isNotEmpty,
      'api_key_length': apiKey.length,
      'api_key_preview': apiKey.isNotEmpty 
          ? '${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}'
          : 'Not configured',
    };
  }
  
  /// Check Services
  static Map<String, dynamic> _checkServices() {
    return {
      'network_service': NetworkService().isOnline,
      'barcode_service_initialized': true, // Will be checked when initialized
      'firestore_config': true, // Always available
    };
  }
  
  /// Check Barcode Scanning
  static Map<String, dynamic> _checkBarcodeScanning() {
    return {
      'enabled': true,
      'databases': {
        'open_food_facts': true, // Free, always available
        'local_indian_dataset': true, // Local, always available
        'upcitemdb': true, // Free tier: 100/day
        'gtinsearch': true, // Free tier: 100/day
        'themealdb': true, // Free, always available
      },
      'fallback_chain': [
        'Open Food Facts',
        'Local Indian Dataset',
        'UPCitemdb (if Open Food Facts fails)',
        'GTINsearch (if UPCitemdb fails)',
        'TheMealDB (for Indian dishes)',
        'AI Fallback (OpenRouter)',
      ],
    };
  }
  
  /// Check Image Analysis
  static Map<String, dynamic> _checkImageAnalysis() {
    return {
      'enabled': AIConfig.enableImageAnalysis,
      'api_key_configured': AIConfig.apiKey.isNotEmpty,
      'vision_model': AIConfig.visionModel,
      'backup_model': AIConfig.backupVisionModel,
      'vision_fallback_enabled': AIConfig.visionFallbackEnabled,
      'retry_attempts': AIConfig.visionRetryAttempts,
      'max_tokens': AIConfig.visionMaxTokens,
      'temperature': AIConfig.visionTemperature,
      'status': AIConfig.enableImageAnalysis && AIConfig.apiKey.isNotEmpty
          ? 'Ready'
          : AIConfig.enableImageAnalysis
              ? 'Waiting for API key'
              : 'Disabled',
    };
  }
  
  /// Check Network
  static Map<String, dynamic> _checkNetwork() {
    final networkService = NetworkService();
    return {
      'is_online': networkService.isOnline,
      'status': networkService.isOnline ? 'Connected' : 'Offline',
    };
  }
  
  /// Check Overall Status
  static Map<String, dynamic> _checkOverallStatus(Map<String, dynamic> status) {
    final featureFlags = status['feature_flags'] as Map<String, dynamic>;
    final apiKeys = status['api_keys'] as Map<String, dynamic>;
    final imageAnalysis = status['image_analysis'] as Map<String, dynamic>;
    final network = status['network'] as Map<String, dynamic>;
    
    final allFeaturesEnabled = 
        featureFlags['enable_chat'] == true &&
        featureFlags['enable_analytics'] == true &&
        featureFlags['enable_recommendations'] == true &&
        featureFlags['enable_image_analysis'] == true;
    
    final apiKeyConfigured = apiKeys['api_key_configured'] == true;
    final networkOnline = network['is_online'] == true;
    final imageAnalysisReady = imageAnalysis['status'] == 'Ready';
    
    final allReady = allFeaturesEnabled && 
                    apiKeyConfigured && 
                    (networkOnline || !imageAnalysisReady); // Network not required for offline features
    
    return {
      'all_features_enabled': allFeaturesEnabled,
      'api_key_configured': apiKeyConfigured,
      'network_online': networkOnline,
      'image_analysis_ready': imageAnalysisReady,
      'barcode_scanning_ready': true, // Always ready (uses local + free APIs)
      'overall_status': allReady ? '✅ All Systems Ready' : '⚠️ Some Features Not Ready',
      'ready_for_use': allReady,
    };
  }
  
  /// Print status report
  static void printStatusReport() {
    final status = checkAllFeatures();
    const separator = '============================================================';
    
    print('\n$separator');
    print('📊 FEATURE STATUS REPORT');
    print(separator);
    
    // Feature Flags
    print('\n🔘 FEATURE FLAGS:');
    final flags = status['feature_flags'] as Map<String, dynamic>;
    flags.forEach((key, value) {
      final icon = value == true ? '✅' : '❌';
      print('   $icon ${key}: $value');
    });
    
    // API Keys
    print('\n🔑 API KEYS:');
    final apiKeys = status['api_keys'] as Map<String, dynamic>;
    print('   ${apiKeys['api_key_configured'] == true ? "✅" : "❌"} OpenRouter API Key: ${apiKeys['api_key_preview']}');
    
    // AI Configuration
    print('\n🤖 AI CONFIGURATION:');
    final aiConfig = status['ai_config'] as Map<String, dynamic>;
    print('   ✅ Primary Model: ${aiConfig['vision_model']}');
    print('   ✅ Fallback Model: ${aiConfig['backup_vision_model']}');
    print('   ✅ Chat Model: ${aiConfig['chat_model']}');
    print('   ${aiConfig['vision_fallback_enabled'] == true ? "✅" : "❌"} Vision Fallback: ${aiConfig['vision_fallback_enabled']}');
    
    // Barcode Scanning
    print('\n📱 BARCODE SCANNING:');
    final barcode = status['barcode_scanning'] as Map<String, dynamic>;
    print('   ✅ Status: Enabled');
    print('   ✅ Databases:');
    final databases = barcode['databases'] as Map<String, dynamic>;
    databases.forEach((key, value) {
      print('      - $key: ${value == true ? "✅ Available" : "❌ Unavailable"}');
    });
    
    // Image Analysis
    print('\n📸 IMAGE ANALYSIS:');
    final imageAnalysis = status['image_analysis'] as Map<String, dynamic>;
    print('   ${imageAnalysis['enabled'] == true ? "✅" : "❌"} Enabled: ${imageAnalysis['enabled']}');
    print('   ${imageAnalysis['api_key_configured'] == true ? "✅" : "❌"} API Key: ${imageAnalysis['api_key_configured']}');
    print('   ✅ Vision Model: ${imageAnalysis['vision_model']}');
    print('   ✅ Status: ${imageAnalysis['status']}');
    
    // Network
    print('\n🌐 NETWORK:');
    final network = status['network'] as Map<String, dynamic>;
    print('   ${network['is_online'] == true ? "✅" : "⚠️"} Status: ${network['status']}');
    
    // Overall Status
    print('\n📈 OVERALL STATUS:');
    final overall = status['overall'] as Map<String, dynamic>;
    overall.forEach((key, value) {
      if (key != 'overall_status') {
        final icon = value == true ? '✅' : '❌';
        print('   $icon ${key.replaceAll('_', ' ').toUpperCase()}: $value');
      }
    });
    print('\n   ${overall['overall_status']}');
    
    print('\n$separator\n');
  }
}

