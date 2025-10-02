import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore-based configuration service as alternative to Remote Config
class FirestoreConfigService {
  static final FirestoreConfigService _instance = FirestoreConfigService._internal();
  factory FirestoreConfigService() => _instance;
  FirestoreConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic> _config = {};
  DateTime? _lastFetchTime;

  /// Initialize the configuration service
  Future<void> initialize() async {
    try {
      await _loadConfig();
      print('✅ Firestore config service initialized');
    } catch (e) {
      print('❌ Error initializing Firestore config: $e');
      // Use default values if Firestore fails
      _setDefaultConfig();
    }
  }

  /// Load configuration from Firestore
  Future<void> _loadConfig() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('ai_settings')
          .get();

      if (doc.exists) {
        _config = doc.data()!;
        _lastFetchTime = DateTime.now();
        print('✅ Loaded config from Firestore');
      } else {
        print('⚠️ No config found in Firestore, using defaults');
        _setDefaultConfig();
      }
    } catch (e) {
      print('❌ Error loading config from Firestore: $e');
      _setDefaultConfig();
    }
  }

  /// Set default configuration values
  void _setDefaultConfig() {
    _config = {
      'openrouter_api_key': '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',
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
      'enable_debug_logs': false,
      'enable_api_response_logging': false,
    };
    _lastFetchTime = DateTime.now();
  }

  /// Refresh configuration from Firestore
  Future<void> refresh() async {
    await _loadConfig();
  }

  /// Get string value
  String getString(String key, {String defaultValue = ''}) {
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
      print('✅ Config updated in Firestore');
    } catch (e) {
      print('❌ Error updating config: $e');
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
