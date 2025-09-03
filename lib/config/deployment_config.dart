/// Deployment configuration for production environment
class DeploymentConfig {
  // App Information
  static const String appName = 'Calorie Vita';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  
  // Environment
  static const bool isProduction = true;
  static const bool enableDebugMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  
  // API Configuration
  static const String baseUrl = 'https://api.calorievita.com';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  
  // Firebase Configuration
  static const bool enableFirebase = true;
  static const bool enableFirestore = true;
  static const bool enableFirebaseAuth = true;
  static const bool enableFirebaseStorage = true;
  
  // Feature Flags
  static const bool enableCameraFeature = true;
  static const bool enableAITrainer = true;
  static const bool enableAnalyticsScreen = true;
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  
  // Performance Settings
  static const int maxCacheSize = 100;
  static const Duration cacheExpiry = Duration(minutes: 5);
  static const int maxImageCacheSize = 50;
  static const Duration imageCacheExpiry = Duration(hours: 1);
  
  // Security Settings
  static const bool enableBiometricAuth = true;
  static const bool enableDataEncryption = true;
  static const Duration sessionTimeout = Duration(hours: 24);
  
  // UI Settings
  static const bool enableDarkMode = true;
  static const bool enableAnimations = true;
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // Error Handling
  static const bool enableErrorReporting = true;
  static const bool enableCrashlytics = true;
  static const int maxErrorLogs = 100;
  
  // Network Settings
  static const bool enableNetworkMonitoring = true;
  static const Duration networkCheckInterval = Duration(seconds: 30);
  static const bool enableOfflineSync = true;
  
  // Analytics Settings
  static const bool enableUserAnalytics = true;
  static const bool enablePerformanceMonitoring = true;
  static const bool enableCustomEvents = true;
  
  // Development Settings (should be false in production)
  static const bool enableDebugLogs = false;
  static const bool enableTestData = false;
  static const bool enableMockServices = false;
  
  /// Get configuration value with fallback
  static T getConfig<T>(String key, T defaultValue) {
    // In a real app, this would read from environment variables or config files
    switch (key) {
      case 'appName':
        return appName as T;
      case 'appVersion':
        return appVersion as T;
      case 'isProduction':
        return isProduction as T;
      case 'enableDebugMode':
        return enableDebugMode as T;
      case 'enableAnalytics':
        return enableAnalytics as T;
      case 'enableCrashReporting':
        return enableCrashReporting as T;
      case 'baseUrl':
        return baseUrl as T;
      case 'apiTimeout':
        return apiTimeout as T;
      case 'maxRetryAttempts':
        return maxRetryAttempts as T;
      case 'enableFirebase':
        return enableFirebase as T;
      case 'enableFirestore':
        return enableFirestore as T;
      case 'enableFirebaseAuth':
        return enableFirebaseAuth as T;
      case 'enableFirebaseStorage':
        return enableFirebaseStorage as T;
      case 'enableCameraFeature':
        return enableCameraFeature as T;
      case 'enableAITrainer':
        return enableAITrainer as T;
      case 'enableAnalyticsScreen':
        return enableAnalyticsScreen as T;
      case 'enableOfflineMode':
        return enableOfflineMode as T;
      case 'enablePushNotifications':
        return enablePushNotifications as T;
      case 'maxCacheSize':
        return maxCacheSize as T;
      case 'cacheExpiry':
        return cacheExpiry as T;
      case 'maxImageCacheSize':
        return maxImageCacheSize as T;
      case 'imageCacheExpiry':
        return imageCacheExpiry as T;
      case 'enableBiometricAuth':
        return enableBiometricAuth as T;
      case 'enableDataEncryption':
        return enableDataEncryption as T;
      case 'sessionTimeout':
        return sessionTimeout as T;
      case 'enableDarkMode':
        return enableDarkMode as T;
      case 'enableAnimations':
        return enableAnimations as T;
      case 'animationDuration':
        return animationDuration as T;
      case 'enableErrorReporting':
        return enableErrorReporting as T;
      case 'enableCrashlytics':
        return enableCrashlytics as T;
      case 'maxErrorLogs':
        return maxErrorLogs as T;
      case 'enableNetworkMonitoring':
        return enableNetworkMonitoring as T;
      case 'networkCheckInterval':
        return networkCheckInterval as T;
      case 'enableOfflineSync':
        return enableOfflineSync as T;
      case 'enableUserAnalytics':
        return enableUserAnalytics as T;
      case 'enablePerformanceMonitoring':
        return enablePerformanceMonitoring as T;
      case 'enableCustomEvents':
        return enableCustomEvents as T;
      case 'enableDebugLogs':
        return enableDebugLogs as T;
      case 'enableTestData':
        return enableTestData as T;
      case 'enableMockServices':
        return enableMockServices as T;
      default:
        return defaultValue;
    }
  }
  
  /// Validate configuration
  static bool validateConfig() {
    try {
      // Check required configurations
      if (appName.isEmpty) return false;
      if (appVersion.isEmpty) return false;
      if (baseUrl.isEmpty) return false;
      
      // Check feature flags consistency
      if (enableAITrainer && !enableFirebase) return false;
      if (enableAnalyticsScreen && !enableFirestore) return false;
      if (enableOfflineMode && !enableFirestore) return false;
      
      return true;
    } catch (e) {
      print('Configuration validation error: $e');
      return false;
    }
  }
  
  /// Get environment-specific configuration
  static Map<String, dynamic> getEnvironmentConfig() {
    return {
      'appName': appName,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'isProduction': isProduction,
      'enableDebugMode': enableDebugMode,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'baseUrl': baseUrl,
      'apiTimeout': apiTimeout.inMilliseconds,
      'maxRetryAttempts': maxRetryAttempts,
      'enableFirebase': enableFirebase,
      'enableFirestore': enableFirestore,
      'enableFirebaseAuth': enableFirebaseAuth,
      'enableFirebaseStorage': enableFirebaseStorage,
      'enableCameraFeature': enableCameraFeature,
      'enableAITrainer': enableAITrainer,
      'enableAnalyticsScreen': enableAnalyticsScreen,
      'enableOfflineMode': enableOfflineMode,
      'enablePushNotifications': enablePushNotifications,
      'maxCacheSize': maxCacheSize,
      'cacheExpiry': cacheExpiry.inMilliseconds,
      'maxImageCacheSize': maxImageCacheSize,
      'imageCacheExpiry': imageCacheExpiry.inMilliseconds,
      'enableBiometricAuth': enableBiometricAuth,
      'enableDataEncryption': enableDataEncryption,
      'sessionTimeout': sessionTimeout.inMilliseconds,
      'enableDarkMode': enableDarkMode,
      'enableAnimations': enableAnimations,
      'animationDuration': animationDuration.inMilliseconds,
      'enableErrorReporting': enableErrorReporting,
      'enableCrashlytics': enableCrashlytics,
      'maxErrorLogs': maxErrorLogs,
      'enableNetworkMonitoring': enableNetworkMonitoring,
      'networkCheckInterval': networkCheckInterval.inMilliseconds,
      'enableOfflineSync': enableOfflineSync,
      'enableUserAnalytics': enableUserAnalytics,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
      'enableCustomEvents': enableCustomEvents,
      'enableDebugLogs': enableDebugLogs,
      'enableTestData': enableTestData,
      'enableMockServices': enableMockServices,
    };
  }
}
