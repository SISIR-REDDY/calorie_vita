import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Comprehensive Firebase configuration and initialization service
class FirebaseConfigService {
  static final FirebaseConfigService _instance = FirebaseConfigService._internal();
  factory FirebaseConfigService() => _instance;
  FirebaseConfigService._internal();

  // Firebase services
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;
  FirebaseMessaging? _messaging;
  
  // Connectivity
  final Connectivity _connectivity = Connectivity();
  
  // Configuration
  bool _isInitialized = false;
  String? _currentUserId;
  Map<String, dynamic> _appConfig = {};

  // Getters
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;
  FirebaseAnalytics get analytics => _analytics ?? FirebaseAnalytics.instance;
  FirebaseCrashlytics get crashlytics => _crashlytics ?? FirebaseCrashlytics.instance;
  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;

  /// Initialize Firebase with comprehensive configuration
  Future<bool> initialize() async {
    try {
      print('🔥 Initializing Firebase...');
      
      // Initialize Firebase Core
      await Firebase.initializeApp();
      print('✅ Firebase Core initialized');

      // Initialize services
      await _initializeAuth();
      await _initializeFirestore();
      await _initializeStorage();
      await _initializeAnalytics();
      await _initializeCrashlytics();
      await _initializeMessaging();
      
      // Load app configuration
      await _loadAppConfiguration();
      
      // Set up connectivity monitoring
      await _setupConnectivityMonitoring();
      
      // Set up auth state listener
      _setupAuthStateListener();
      
      _isInitialized = true;
      print('🎉 Firebase initialization completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Firebase initialization failed: $e');
      await _logError('firebase_init', e);
      return false;
    }
  }

  /// Initialize Firebase Authentication
  Future<void> _initializeAuth() async {
    _auth = FirebaseAuth.instance;
    
    // Configure auth settings
    await _auth!.setSettings(
      appVerificationDisabledForTesting: false,
      forceRecaptchaFlow: false,
    );
    
    print('✅ Firebase Auth initialized');
  }

  /// Initialize Firestore with optimized settings
  Future<void> _initializeFirestore() async {
    _firestore = FirebaseFirestore.instance;
    
    // Configure Firestore settings
    _firestore!.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    
    print('✅ Firestore initialized');
  }

  /// Initialize Firebase Storage
  Future<void> _initializeStorage() async {
    _storage = FirebaseStorage.instance;
    
    // Configure storage settings
    _storage!.setMaxUploadRetryTime(const Duration(seconds: 30));
    _storage!.setMaxDownloadRetryTime(const Duration(seconds: 30));
    
    print('✅ Firebase Storage initialized');
  }

  /// Initialize Firebase Analytics
  Future<void> _initializeAnalytics() async {
    _analytics = FirebaseAnalytics.instance;
    
    // Set analytics collection enabled
    await _analytics!.setAnalyticsCollectionEnabled(true);
    
    // Set user properties
    await _analytics!.setUserProperty(
      name: 'app_version',
      value: '1.0.0', // Replace with actual version
    );
    
    print('✅ Firebase Analytics initialized');
  }

  /// Initialize Firebase Crashlytics
  Future<void> _initializeCrashlytics() async {
    _crashlytics = FirebaseCrashlytics.instance;
    
    // Set up crashlytics
    await _crashlytics!.setCrashlyticsCollectionEnabled(true);
    
    // Set up error handling
    FlutterError.onError = (errorDetails) {
      _crashlytics!.recordFlutterFatalError(errorDetails);
    };
    
    print('✅ Firebase Crashlytics initialized');
  }

  /// Initialize Firebase Messaging
  Future<void> _initializeMessaging() async {
    _messaging = FirebaseMessaging.instance;
    
    // Request permission for notifications
    final settings = await _messaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permissions granted');
    } else {
      print('⚠️ Notification permissions denied');
    }
    
    // Get FCM token
    final token = await _messaging!.getToken();
    if (token != null) {
      print('📱 FCM Token: ${token.substring(0, 20)}...');
      await _saveFCMToken(token);
    }
    
    print('✅ Firebase Messaging initialized');
  }

  /// Load app configuration from Firestore
  Future<void> _loadAppConfiguration() async {
    try {
      final doc = await _firestore!
          .collection('app_config')
          .doc('settings')
          .get();
      
      if (doc.exists) {
        _appConfig = doc.data() ?? {};
        print('✅ App configuration loaded');
      } else {
        // Create default configuration
        await _createDefaultConfiguration();
        print('✅ Default app configuration created');
      }
    } catch (e) {
      print('⚠️ Failed to load app configuration: $e');
      await _createDefaultConfiguration();
    }
  }

  /// Create default app configuration
  Future<void> _createDefaultConfiguration() async {
    _appConfig = {
      'version': '1.0.0',
      'minSupportedVersion': '1.0.0',
      'features': {
        'aiTrainer': true,
        'barcodeScanning': true,
        'healthIntegration': true,
        'premiumFeatures': true,
      },
      'limits': {
        'maxFoodEntriesPerDay': 50,
        'maxChatMessagesPerSession': 100,
        'maxImageSizeMB': 10,
      },
      'analytics': {
        'enabled': true,
        'retentionDays': 365,
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    
    await _firestore!
        .collection('app_config')
        .doc('settings')
        .set(_appConfig);
  }

  /// Set up connectivity monitoring
  Future<void> _setupConnectivityMonitoring() async {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      print('🌐 Connectivity: ${isOnline ? 'Online' : 'Offline'}');
      
      // Update user's online status
      if (_currentUserId != null) {
        _updateUserOnlineStatus(isOnline);
      }
    });
  }

  /// Set up authentication state listener
  void _setupAuthStateListener() {
    _auth!.authStateChanges().listen((User? user) {
      _currentUserId = user?.uid;
      
      if (user != null) {
        print('👤 User signed in: ${user.uid}');
        _updateUserOnlineStatus(true);
        _trackUserEvent('user_sign_in');
      } else {
        print('👤 User signed out');
        _updateUserOnlineStatus(false);
        _trackUserEvent('user_sign_out');
      }
    });
  }

  /// Update user's online status
  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    if (_currentUserId == null) return;
    
    try {
      await _firestore!
          .collection('users')
          .doc(_currentUserId!)
          .update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Failed to update user online status: $e');
    }
  }

  /// Save FCM token to user document
  Future<void> _saveFCMToken(String token) async {
    if (_currentUserId == null) return;
    
    try {
      await _firestore!
          .collection('users')
          .doc(_currentUserId!)
          .update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Failed to save FCM token: $e');
    }
  }

  /// Track user events
  Future<void> _trackUserEvent(String eventName, {Map<String, Object>? parameters}) async {
    try {
      await _analytics!.logEvent(
        name: eventName,
        parameters: parameters,
      );
    } catch (e) {
      print('⚠️ Failed to track event: $e');
    }
  }

  /// Log errors to Crashlytics
  Future<void> _logError(String context, dynamic error, {StackTrace? stackTrace}) async {
    try {
      await _crashlytics!.recordError(
        error,
        stackTrace,
        fatal: false,
      );
    } catch (e) {
      print('⚠️ Failed to log error: $e');
    }
  }

  /// Get app configuration value
  T? getConfigValue<T>(String key) {
    final keys = key.split('.');
    dynamic value = _appConfig;
    
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return null;
      }
    }
    
    return value as T?;
  }

  /// Check if feature is enabled
  bool isFeatureEnabled(String featureName) {
    return getConfigValue<bool>('features.$featureName') ?? false;
  }

  /// Get app limits
  int getAppLimit(String limitName) {
    return getConfigValue<int>('limits.$limitName') ?? 0;
  }

  /// Initialize user data structure
  Future<void> initializeUserData(String userId) async {
    try {
      final batch = _firestore!.batch();
      
      // Create user document
      final userRef = _firestore!.collection('users').doc(userId);
      batch.set(userRef, {
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      // Create profile subcollection
      final profileRef = userRef.collection('profile').doc('userData');
      batch.set(profileRef, {
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Create preferences subcollection
      final preferencesRef = userRef.collection('profile').doc('preferences');
      batch.set(preferencesRef, {
        'calorieUnit': 'kcal',
        'weightUnit': 'kg',
        'heightUnit': 'cm',
        'distanceUnit': 'km',
        'temperatureUnit': 'celsius',
        'language': 'en',
        'theme': 'system',
        'notifications': {
          'dailyReminders': true,
          'goalAchievements': true,
          'weeklyReports': true,
          'mealReminders': true,
        },
        'privacy': {
          'shareData': false,
          'analyticsOptIn': true,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Create goals subcollection
      final goalsRef = userRef.collection('goals').doc('current');
      batch.set(goalsRef, {
        'calorieGoal': 2000,
        'waterGlassesGoal': 8,
        'stepsPerDayGoal': 10000,
        'workoutMinutesGoal': 30,
        'weightGoal': 70,
        'macroGoals': {
          'carbsPercentage': 50,
          'proteinPercentage': 25,
          'fatPercentage': 25,
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Create streaks subcollection
      final streaksRef = userRef.collection('streaks').doc('summary');
      batch.set(streaksRef, {
        'goalStreaks': {
          'calories': {'current': 0, 'longest': 0, 'lastAchieved': null},
          'steps': {'current': 0, 'longest': 0, 'lastAchieved': null},
          'water': {'current': 0, 'longest': 0, 'lastAchieved': null},
        },
        'totalActiveStreaks': 0,
        'longestOverallStreak': 0,
        'lastActivityDate': FieldValue.serverTimestamp(),
        'totalDaysActive': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      print('✅ User data structure initialized for: $userId');
      
    } catch (e) {
      print('❌ Failed to initialize user data: $e');
      await _logError('user_data_init', e);
      rethrow;
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    try {
      // Update user offline status
      if (_currentUserId != null) {
        await _updateUserOnlineStatus(false);
      }
      
      print('🧹 Firebase configuration service disposed');
    } catch (e) {
      print('⚠️ Error during disposal: $e');
    }
  }
}
