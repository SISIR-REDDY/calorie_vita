import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Secure configuration service using Firebase Remote Config
/// This service manages API keys and sensitive configuration securely
/// without exposing them in the client code
class SecureConfigService {
  static SecureConfigService? _instance;
  static SecureConfigService get instance => _instance ??= SecureConfigService._();
  
  SecureConfigService._();
  
  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;
  
  // Cache for configuration values
  final Map<String, dynamic> _configCache = {};
  
  /// Initialize the remote config service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Set default values for development/fallback
      await _remoteConfig!.setDefaults({
        'openrouter_api_key': 'your_api_key_here',
        'openrouter_base_url': 'https://openrouter.ai/api/v1/chat/completions',
        'chat_model': 'openai/gpt-3.5-turbo',
        'vision_model': 'google/gemini-pro-1.5-exp',
        'backup_vision_model': 'google/gemini-pro-1.5',
        'max_tokens': 100,
        'chat_max_tokens': 100,
        'analytics_max_tokens': 120,
        'vision_max_tokens': 300,
        'temperature': 0.7,
        'vision_temperature': 0.1,
        'app_name': 'Calorie Vita',
        'app_url': 'https://calorievita.com',
        'max_requests_per_minute': 60,
        'request_timeout_seconds': 30,
        'enable_chat': true,
        'enable_analytics': true,
        'enable_recommendations': true,
        'enable_image_analysis': true,
        'enable_debug_logs': kDebugMode,
        'enable_api_response_logging': false,
      });
      
      // Set fetch timeout
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      // Fetch and activate config
      await _fetchAndActivate();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('SecureConfigService initialized successfully');
      }
    } catch (e) {
      print('Error initializing SecureConfigService: $e');
      // Continue with default values
      _isInitialized = true;
    }
  }
  
  /// Fetch and activate remote config
  Future<void> _fetchAndActivate() async {
    try {
      await _remoteConfig!.fetchAndActivate();
      
      // Cache all values
      _configCache.clear();
      final allKeys = _remoteConfig!.getAll();
      for (final entry in allKeys.entries) {
        _configCache[entry.key] = entry.value.asString();
      }
      
      if (kDebugMode) {
        print('Remote config fetched and activated');
      }
    } catch (e) {
      print('Error fetching remote config: $e');
      // Use default values from cache
    }
  }
  
  /// Force refresh configuration from Firebase
  Future<void> refresh() async {
    await _fetchAndActivate();
  }
  
  /// Get string value from config
  String getString(String key, {String defaultValue = ''}) {
    if (!_isInitialized) {
      print('Warning: SecureConfigService not initialized, using default value');
      return defaultValue;
    }
    
    try {
      return _remoteConfig?.getString(key) ?? defaultValue;
    } catch (e) {
      print('Error getting string config for key $key: $e');
      return defaultValue;
    }
  }
  
  /// Get int value from config
  int getInt(String key, {int defaultValue = 0}) {
    if (!_isInitialized) {
      print('Warning: SecureConfigService not initialized, using default value');
      return defaultValue;
    }
    
    try {
      return _remoteConfig?.getInt(key) ?? defaultValue;
    } catch (e) {
      print('Error getting int config for key $key: $e');
      return defaultValue;
    }
  }
  
  /// Get double value from config
  double getDouble(String key, {double defaultValue = 0.0}) {
    if (!_isInitialized) {
      print('Warning: SecureConfigService not initialized, using default value');
      return defaultValue;
    }
    
    try {
      return _remoteConfig?.getDouble(key) ?? defaultValue;
    } catch (e) {
      print('Error getting double config for key $key: $e');
      return defaultValue;
    }
  }
  
  /// Get boolean value from config
  bool getBool(String key, {bool defaultValue = false}) {
    if (!_isInitialized) {
      print('Warning: SecureConfigService not initialized, using default value');
      return defaultValue;
    }
    
    try {
      return _remoteConfig?.getBool(key) ?? defaultValue;
    } catch (e) {
      print('Error getting bool config for key $key: $e');
      return defaultValue;
    }
  }
  
  /// Get all configuration as a map (for debugging)
  Map<String, dynamic> getAllConfig() {
    if (!_isInitialized) return {};
    
    try {
      final allKeys = _remoteConfig?.getAll() ?? {};
      final config = <String, dynamic>{};
      
      for (final entry in allKeys.entries) {
        config[entry.key] = entry.value.asString();
      }
      
      return config;
    } catch (e) {
      print('Error getting all config: $e');
      return {};
    }
  }
  
  /// Check if a key exists in the config
  bool hasKey(String key) {
    if (!_isInitialized) return false;
    
    try {
      return _remoteConfig?.getAll().containsKey(key) ?? false;
    } catch (e) {
      print('Error checking key existence for $key: $e');
      return false;
    }
  }
  
  /// Get last fetch time
  DateTime? getLastFetchTime() {
    if (!_isInitialized) return null;
    
    try {
      return _remoteConfig?.lastFetchTime;
    } catch (e) {
      print('Error getting last fetch time: $e');
      return null;
    }
  }
  
  /// Get last fetch status
  RemoteConfigFetchStatus? getLastFetchStatus() {
    if (!_isInitialized) return null;
    
    try {
      return _remoteConfig?.lastFetchStatus;
    } catch (e) {
      print('Error getting last fetch status: $e');
      return null;
    }
  }
}
