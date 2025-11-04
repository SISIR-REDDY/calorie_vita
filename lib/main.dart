import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'main_app.dart';
import 'services/network_service.dart';
import 'services/performance_monitor.dart';
import 'services/error_handler.dart';
import 'services/logger_service.dart';
import 'services/push_notification_service.dart';
import 'config/production_config.dart';
import 'config/ai_config.dart';
import 'utils/feature_status_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only (both upright and upside-down)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize logger service first for better debugging (minimal delay)
  final logger = LoggerService();
  await logger.initialize();
  logger.info('App starting', {'version': ProductionConfig.appVersion});

  // Initialize performance monitoring (minimal delay)
  final performanceMonitor = PerformanceMonitor();
  await performanceMonitor.initialize();
  performanceMonitor.startTimer('app_startup');

  // Initialize core services in parallel for faster startup
  final networkService = NetworkService();
  final errorHandler = ErrorHandler();
  
  // Run network and error handler initialization in parallel (non-blocking)
  await Future.wait([
    networkService.initialize(),
    errorHandler.initialize(),
  ]);
  
  logger.info('Core services initialized', {
    'performance_monitor': true,
    'network_service': true,
    'error_handler': true,
  });

  // Initialize Firebase with basic configuration (required for app to work)
  bool firebaseInitialized = false;
  try {
    // Initialize Firebase in parallel with other operations
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase services (minimal delay)
    await _initializeFirebaseServices();
    
    // Enable Firestore persistence in background (non-blocking)
    FirebaseFirestore.instance.enablePersistence().then((_) {
      logger.info('Firestore persistence enabled');
    }).catchError((e) {
      logger.warning('Firestore persistence already enabled or not available');
    });

    firebaseInitialized = true;
    logger.info('Firebase initialized successfully');
    performanceMonitor.logEvent('firebase_initialized', {'success': true});

    // Update error handler and logger with Firebase availability in background (non-blocking)
    Future(() {
      errorHandler.initialize(firebaseAvailable: true).catchError((e) {
        logger.warning('Error handler re-initialization error', {'error': e.toString()});
      });
      logger.initialize(firebaseAvailable: true).catchError((e) {
        logger.warning('Logger re-initialization error', {'error': e.toString()});
      });
    });

    // Initialize secure configuration service in background (non-blocking)
    // Note: Config may fail to load if user is not authenticated (security rules require auth)
    // The config will be loaded automatically after user authentication via AppStateManager
    AIConfig.initialize().then((_) {
      logger.info('Secure configuration initialization attempted');
      
      // Log API key source for debugging (in background)
      final apiKey = AIConfig.apiKey;
      if (apiKey.isNotEmpty) {
        print('🔑 API Key Status: ${apiKey.length} characters (${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)})');
        print('   📍 Check FirestoreConfigService logs above to see if it came from Firebase or code');
      } else {
        print('⚠️ API Key is EMPTY - will load after user authentication');
        print('   📌 Security: Config requires authentication (see firestore.rules)');
        print('   📌 Config will be loaded automatically when user logs in');
      }
      
      // Print feature status report in background (non-blocking, no delay)
      Future(() {
        try {
          FeatureStatusChecker.printStatusReport();
        } catch (e) {
          logger.debug('Feature status check skipped', {'error': e.toString()});
        }
      });
    }).catchError((e) {
      // Config load failure is expected if user is not authenticated
      // It will be loaded automatically after authentication
      if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        logger.info('Config load requires authentication - will load after user login');
        print('ℹ️ Config requires authentication - will load after user login');
      } else {
        logger.warning('Secure configuration initialization error', {'error': e.toString()});
        print('⚠️ Config initialization error: $e (may be due to missing auth)');
      }
    });

    // Initialize push notification service in background (non-blocking)
    final pushNotificationService = PushNotificationService();
    pushNotificationService.initialize().then((_) {
      logger.info('Push notification service initialized');
    }).catchError((e) {
      logger.warning('Push notification service initialization error', {'error': e.toString()});
    });

  } catch (e) {
    // If Firebase is already initialized, that's fine
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
      firebaseInitialized = true;
      // Re-initialize error handler in background (non-blocking)
      Future(() {
        errorHandler.initialize(firebaseAvailable: true).catchError((err) {
          logger.warning('Error handler re-initialization error', {'error': err.toString()});
        });
      });
    } else {
      logger.error('Firebase initialization error', {'error': e.toString()});
      logger.warning('Continuing without Firebase - app will work in demo mode');
      performanceMonitor.logEvent('firebase_init_error', {
        'error': e.toString(),
        'success': false,
      });
      errorHandler.handleFirebaseError('initialization', e);
    }
  }

  performanceMonitor.stopTimer('app_startup');

  // Log startup performance
  final startupDuration = performanceMonitor.getOperationStats('app_startup');
  logger.info('App startup completed', {
    'duration_ms': startupDuration['average_ms'],
    'firebase_initialized': firebaseInitialized,
  });

  runApp(MainApp(firebaseInitialized: firebaseInitialized));
}

/// Initialize Firebase services
Future<void> _initializeFirebaseServices() async {
  try {
    // Initialize Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Initialize Analytics
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    print('Firebase services initialized successfully');
  } catch (e) {
    print('Error initializing Firebase services: $e');
    rethrow;
  }
}
