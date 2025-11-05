import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

/// Firestore-based configuration service as alternative to Remote Config
/// 
/// Expected Firebase Structure:
/// Collection: app_config
/// Document ID: ai_settings
/// 
/// Required fields:
/// - openrouter_api_key: String (your OpenRouter API key)
/// - vision_model: String (default: 'google/gemini-1.5-flash')
/// - enable_image_analysis: Boolean (default: true)
/// 
/// To verify config is loaded, check console logs for:
/// ✅ "Successfully loaded config from Firestore"
/// 🔑 API Key loaded message
/// 👁️ Vision model message
class FirestoreConfigService {
  static final FirestoreConfigService _instance = FirestoreConfigService._internal();
  factory FirestoreConfigService() => _instance;
  FirestoreConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggerService _logger = LoggerService();
  
  Map<String, dynamic> _config = {};
  DateTime? _lastFetchTime;
  DateTime? _lastRefreshTime;
  static const Duration _refreshDebounce = Duration(seconds: 5); // Prevent continuous refresh calls
  bool _hasLoggedApiKey = false; // Track if API key has been logged to prevent duplicate logs

  /// Initialize the configuration service
  Future<void> initialize() async {
    try {
      await _loadConfig();
      _logger.info('Firestore config service initialized');
      
      // Verify API key is loaded from Firebase
      if (!_config.containsKey('openrouter_api_key') || _config['openrouter_api_key'] == null || (_config['openrouter_api_key'] as String).isEmpty) {
        _logger.warning('API key not found in Firestore - AI features will not work');
        print('⚠️ WARNING: API key is missing from Firebase');
        print('📌 The app requires the API key to be set in Firestore at: app_config/ai_settings/openrouter_api_key');
      }
    } catch (e) {
      _logger.error('Error initializing Firestore config', {'error': e.toString()});
      // Use default config without API key if Firestore fails
      _setDefaultConfigWithoutAPIKey();
    }
  }

  /// Load configuration from Firestore
  Future<void> _loadConfig() async {
    try {
      print('🔍 Loading AI configuration from Firestore: app_config/ai_settings');
      final doc = await _firestore
          .collection('app_config')
          .doc('ai_settings')
          .get();

      if (doc.exists) {
        _config = doc.data()!;
        _lastFetchTime = DateTime.now();
        _logger.info('Loaded config from Firestore');
        // Reduced logging - only log once per load, not on every refresh
        if (kDebugMode) {
          print('✅ Config loaded from Firestore');
        }
        
        // Log API key status for verification - SAFE: Only log length, never preview
        if (_config.containsKey('openrouter_api_key') && _config['openrouter_api_key'] != null) {
          final apiKey = _config['openrouter_api_key'] as String;
          if (apiKey.isNotEmpty) {
            // SECURITY: Never log API key previews in production
            // Reduced logging - only log API key status once per session
            if (kDebugMode && !_hasLoggedApiKey) {
              print('🔑 API Key loaded: ${apiKey.length} chars from Firestore');
              _hasLoggedApiKey = true;
            }
          } else {
            print('❌ API key is EMPTY in Firestore document');
            print('   ⚠️ AI features will NOT work - configure openrouter_api_key in Firebase');
          }
        } else {
          print('❌ API key not found in Firestore document');
          print('   ⚠️ AI features will NOT work - add openrouter_api_key field to Firebase');
        }
        
        // Log vision model for verification
        if (_config.containsKey('vision_model')) {
          print('👁️ Vision model: ${_config['vision_model']}');
        }
        
        if (_config.containsKey('enable_image_analysis')) {
          print('🖼️ Image analysis enabled: ${_config['enable_image_analysis']}');
        }
      } else {
        _logger.warning('No config found in Firestore - API key required from Firebase');
        print('❌ No config document found at app_config/ai_settings in Firestore');
        print('⚠️ API key MUST be configured in Firebase - no fallback available');
        print('📌 Create Firestore document at: app_config/ai_settings');
        print('📌 Add field: openrouter_api_key (String) with your API key');
        print('📌 The app will NOT work without the API key in Firebase');
        _setDefaultConfigWithoutAPIKey();
      }
    } catch (e) {
      _logger.error('Error loading config from Firestore', {'error': e.toString()});
      print('❌ Error loading config from Firestore: $e');
      print('⚠️ API key MUST be configured in Firebase - no fallback available');
      print('📌 Ensure Firestore is accessible and create document at: app_config/ai_settings');
      print('📌 Add field: openrouter_api_key (String) with your API key');
      print('📌 The app will NOT work without the API key in Firebase');
      _setDefaultConfigWithoutAPIKey();
    }
  }

  /// Set default configuration values WITHOUT API key
  /// NOTE: API key MUST come from Firebase - no fallback in code
  /// The API key should be stored in Firestore at app_config/ai_settings/openrouter_api_key
  void _setDefaultConfigWithoutAPIKey() {
    print('📝 Setting default configuration (WITHOUT API key - must come from Firebase)');
    _config = {
      // IMPORTANT: API key is NOT included here - it MUST come from Firebase
      // If Firestore is not configured or fails, the API key will be empty
      // The app will NOT work without the API key configured in Firebase
      // To configure: Set openrouter_api_key in Firestore at app_config/ai_settings/openrouter_api_key
      'openrouter_api_key': '', // EMPTY - must come from Firebase
      'openrouter_base_url': 'https://openrouter.ai/api/v1/chat/completions',
      'chat_model': 'openai/gpt-3.5-turbo',
      'vision_model': 'google/gemini-1.5-flash', // Primary vision model - Gemini 1.5 Flash
      'backup_vision_model': 'openai/gpt-4o', // Fallback vision model - GPT-4o if Gemini fails
      'max_tokens': 100,
      'chat_max_tokens': 100,
      'analytics_max_tokens': 120,
      'vision_max_tokens': 150, // Optimized for speed while maintaining accuracy
      'temperature': 0.7,
      'vision_temperature': 0.1, // Lower for faster, more deterministic responses
      'app_name': 'Calorie Vita',
      'app_url': 'https://calorievita.com',
      'max_requests_per_minute': 30, // More conservative rate limiting
      'request_timeout_seconds': 15, // Faster timeout for better UX
      'enable_chat': true,
      'enable_analytics': true,
      'enable_recommendations': true,
      'enable_image_analysis': true,
      'enable_debug_logs': false,
      'enable_api_response_logging': false,
      'vision_retry_attempts': 3, // Number of retry attempts
      'vision_fallback_enabled': true, // Enable fallback models
    };
    _lastFetchTime = DateTime.now();
    
    // Log that API key is missing and must come from Firebase
    final apiKey = _config['openrouter_api_key'] as String;
    if (apiKey.isEmpty) {
      print('❌ API Key is EMPTY - must be configured in Firebase');
      print('   ⚠️ AI features will NOT work without the API key');
      print('   📌 Configure in Firestore: app_config/ai_settings/openrouter_api_key');
      print('   📌 Add field: openrouter_api_key (String) with your API key value');
    }
  }

  /// Refresh configuration from Firestore (with debouncing to prevent continuous calls)
  Future<void> refresh() async {
    // Debounce: Only refresh if enough time has passed since last refresh
    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _refreshDebounce) {
        print('⏭️ Config refresh skipped (debounced - last refresh was ${timeSinceLastRefresh.inSeconds}s ago)');
        return;
      }
    }
    
    _lastRefreshTime = DateTime.now();
    try {
      await _loadConfig();
    } catch (e) {
      _logger.error('Error refreshing config', {'error': e.toString()});
      // Don't rethrow - allow app to continue with cached config
    }
  }

  /// Get string value
  /// For openrouter_api_key, returns empty string if not found (no fallback)
  String getString(String key, {String defaultValue = ''}) {
    // Special handling for API key - never use fallback, must come from Firebase
    if (key == 'openrouter_api_key') {
      final value = _config[key];
      if (value == null || value.toString().isEmpty) {
        return ''; // Return empty string - API key must come from Firebase
      }
      return value.toString();
    }
    return _config[key]?.toString() ?? defaultValue;
  }

  /// Get integer value
  int getInt(String key, {int defaultValue = 0}) {
    final value = _config[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Get double value
  double getDouble(String key, {double defaultValue = 0.0}) {
    final value = _config[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Get boolean value
  bool getBool(String key, {bool defaultValue = false}) {
    final value = _config[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  /// Get all configuration
  Map<String, dynamic> getAllConfig() {
    return Map<String, dynamic>.from(_config);
  }

  /// Get last fetch time
  DateTime? getLastFetchTime() {
    return _lastFetchTime;
  }

  /// Update configuration in Firestore (admin only)
  Future<void> updateConfig(Map<String, dynamic> newConfig) async {
    try {
      await _firestore
          .collection('app_config')
          .doc('ai_settings')
          .set(newConfig, SetOptions(merge: true));
      
      _config = newConfig;
      _lastFetchTime = DateTime.now();
      _logger.info('Config updated in Firestore');
    } catch (e) {
      _logger.error('Error updating config', {'error': e.toString()});
      rethrow;
    }
  }

  /// Get debug configuration (sensitive values masked)
  Map<String, dynamic> getDebugConfig() {
    final config = Map<String, dynamic>.from(_config);
    
    // Mask sensitive values
    if (config.containsKey('openrouter_api_key')) {
      final apiKey = config['openrouter_api_key'] as String;
      if (apiKey.length > 12) {
        config['openrouter_api_key'] = '${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}';
      } else {
        config['openrouter_api_key'] = '***masked***';
      }
    }
    
    return config;
  }
}
