import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Service to check if Firebase is properly set up
class FirebaseSetupChecker {
  static final FirebaseSetupChecker _instance = FirebaseSetupChecker._internal();
  factory FirebaseSetupChecker() => _instance;
  FirebaseSetupChecker._internal();

  final Map<String, bool> _serviceStatus = {};

  /// Check all Firebase services
  Future<Map<String, dynamic>> checkAllServices() async {
    print('🔍 Checking Firebase services...');
    
    final results = <String, dynamic>{};
    
    try {
      // Check Firebase Core
      results['firebase_core'] = await _checkFirebaseCore();
      
      // Check Authentication
      results['authentication'] = await _checkAuthentication();
      
      // Check Firestore
      results['firestore'] = await _checkFirestore();
      
      // Check Storage
      results['storage'] = await _checkStorage();
      
      // Check Remote Config
      results['remote_config'] = await _checkRemoteConfig();
      
      // Check Analytics
      results['analytics'] = await _checkAnalytics();
      
      // Check Crashlytics
      results['crashlytics'] = await _checkCrashlytics();
      
      // Check AI Configuration
      results['ai_config'] = await _checkAIConfiguration();
      
      // Overall status
      final allWorking = results.values.every((status) => 
          status is bool ? status : status['working'] == true);
      results['overall_status'] = allWorking ? '✅ All services working' : '❌ Some services have issues';
      
      print('📊 Firebase setup check completed');
      _printResults(results);
      
    } catch (e) {
      print('❌ Error checking Firebase services: $e');
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Check Firebase Core initialization
  Future<bool> _checkFirebaseCore() async {
    try {
      final app = Firebase.app();
      print('✅ Firebase Core: Initialized (${app.name})');
      return true;
    } catch (e) {
      print('❌ Firebase Core: Not initialized - $e');
      return false;
    }
  }

  /// Check Authentication service
  Future<bool> _checkAuthentication() async {
    try {
      final auth = FirebaseAuth.instance;
      print('✅ Authentication: Available');
      return true;
    } catch (e) {
      print('❌ Authentication: Not available - $e');
      return false;
    }
  }

  /// Check Firestore service
  Future<bool> _checkFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Try to read a test document
      await firestore.collection('test').limit(1).get();
      print('✅ Firestore: Available and accessible');
      return true;
    } catch (e) {
      print('❌ Firestore: Not accessible - $e');
      return false;
    }
  }

  /// Check Storage service
  Future<bool> _checkStorage() async {
    try {
      final storage = FirebaseStorage.instance;
      // Try to get reference to test bucket
      final ref = storage.ref().child('test');
      print('✅ Storage: Available');
      return true;
    } catch (e) {
      print('❌ Storage: Not available - $e');
      return false;
    }
  }

  /// Check Remote Config service
  Future<bool> _checkRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      print('✅ Remote Config: Available');
      return true;
    } catch (e) {
      print('❌ Remote Config: Not available - $e');
      return false;
    }
  }

  /// Check Analytics service
  Future<bool> _checkAnalytics() async {
    try {
      final analytics = FirebaseAnalytics.instance;
      print('✅ Analytics: Available');
      return true;
    } catch (e) {
      print('❌ Analytics: Not available - $e');
      return false;
    }
  }

  /// Check Crashlytics service
  Future<bool> _checkCrashlytics() async {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      print('✅ Crashlytics: Available');
      return true;
    } catch (e) {
      print('❌ Crashlytics: Not available - $e');
      return false;
    }
  }

  /// Check AI Configuration
  Future<Map<String, dynamic>> _checkAIConfiguration() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      
      final apiKey = remoteConfig.getString('openrouter_api_key');
      final baseUrl = remoteConfig.getString('openrouter_base_url');
      final chatModel = remoteConfig.getString('chat_model');
      final visionModel = remoteConfig.getString('vision_model');
      
      final hasApiKey = apiKey.isNotEmpty && apiKey != 'your_actual_api_key_here';
      final hasBaseUrl = baseUrl.isNotEmpty;
      final hasChatModel = chatModel.isNotEmpty;
      final hasVisionModel = visionModel.isNotEmpty;
      
      final allConfigured = hasApiKey && hasBaseUrl && hasChatModel && hasVisionModel;
      
      print('${allConfigured ? '✅' : '❌'} AI Configuration: ${allConfigured ? 'Complete' : 'Incomplete'}');
      
      if (!allConfigured) {
        print('   Missing: ${!hasApiKey ? 'API Key ' : ''}${!hasBaseUrl ? 'Base URL ' : ''}${!hasChatModel ? 'Chat Model ' : ''}${!hasVisionModel ? 'Vision Model ' : ''}');
      }
      
      return {
        'working': allConfigured,
        'api_key': hasApiKey,
        'base_url': hasBaseUrl,
        'chat_model': hasChatModel,
        'vision_model': hasVisionModel,
        'details': {
          'api_key': hasApiKey ? 'Set' : 'Missing',
          'base_url': hasBaseUrl ? 'Set' : 'Missing',
          'chat_model': hasChatModel ? 'Set' : 'Missing',
          'vision_model': hasVisionModel ? 'Set' : 'Missing',
        }
      };
    } catch (e) {
      print('❌ AI Configuration: Error checking - $e');
      return {
        'working': false,
        'error': e.toString(),
      };
    }
  }

  /// Print results in a formatted way
  void _printResults(Map<String, dynamic> results) {
    print('\n📋 Firebase Setup Status:');
    print('=' * 50);
    
    for (final entry in results.entries) {
      if (entry.key == 'overall_status') {
        print('${entry.value}');
        continue;
      }
      
      if (entry.value is bool) {
        print('${entry.value ? '✅' : '❌'} ${entry.key}: ${entry.value ? 'Working' : 'Not Working'}');
      } else if (entry.value is Map) {
        final map = entry.value as Map<String, dynamic>;
        final working = map['working'] == true;
        print('${working ? '✅' : '❌'} ${entry.key}: ${working ? 'Working' : 'Issues Found'}');
        
        if (map.containsKey('details')) {
          final details = map['details'] as Map<String, dynamic>;
          for (final detail in details.entries) {
            print('   ${detail.value == 'Set' ? '✅' : '❌'} ${detail.key}: ${detail.value}');
          }
        }
      }
    }
    
    print('=' * 50);
  }

  /// Get setup recommendations
  List<String> getSetupRecommendations(Map<String, dynamic> results) {
    final recommendations = <String>[];
    
    if (results['firebase_core'] != true) {
      recommendations.add('Initialize Firebase Core in main.dart');
    }
    
    if (results['authentication'] != true) {
      recommendations.add('Enable Authentication in Firebase Console');
    }
    
    if (results['firestore'] != true) {
      recommendations.add('Enable Firestore Database in Firebase Console');
    }
    
    if (results['storage'] != true) {
      recommendations.add('Enable Storage in Firebase Console');
    }
    
    if (results['remote_config'] != true) {
      recommendations.add('Enable Remote Config in Firebase Console');
    }
    
    if (results['analytics'] != true) {
      recommendations.add('Enable Analytics in Firebase Console');
    }
    
    if (results['crashlytics'] != true) {
      recommendations.add('Enable Crashlytics in Firebase Console');
    }
    
    if (results['ai_config'] is Map && (results['ai_config'] as Map)['working'] != true) {
      recommendations.add('Set up AI configuration in Remote Config');
      recommendations.add('Get OpenRouter API key from https://openrouter.ai/');
    }
    
    return recommendations;
  }
}
