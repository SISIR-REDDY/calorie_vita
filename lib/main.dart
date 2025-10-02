import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'main_app.dart';
import 'services/network_service.dart';
import 'services/performance_monitor.dart';
import 'services/error_handler.dart';
import 'services/logger_service.dart';
import 'services/push_notification_service.dart';
import 'config/production_config.dart';
import 'config/ai_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only (both upright and upside-down)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize logger service first for better debugging
  final logger = LoggerService();
  await logger.initialize();
  logger.info('App starting', {'version': ProductionConfig.appVersion});

  // Initialize performance monitoring
  final performanceMonitor = PerformanceMonitor();
  await performanceMonitor.initialize();
  performanceMonitor.startTimer('app_startup');

  // Initialize network service
  final networkService = NetworkService();
  await networkService.initialize();

  // Initialize error handler
  final errorHandler = ErrorHandler();
  await errorHandler.initialize();
  
  logger.info('Core services initialized', {
    'performance_monitor': true,
    'network_service': true,
    'error_handler': true,
  });

  // Initialize Firebase with basic configuration
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

  // Initialize Firebase services
  await _initializeFirebaseServices();

  // Initialize secure configuration service
  try {
    await AIConfig.initialize();
    logger.info('Secure configuration initialized successfully');
  } catch (e) {
    logger.error('Secure configuration initialization error', {'error': e.toString()});
  }

  // Initialize push notification service
  final pushNotificationService = PushNotificationService();
  await pushNotificationService.initialize();

  firebaseInitialized = true;
  logger.info('Firebase initialized successfully');
    performanceMonitor.logEvent('firebase_initialized', {'success': true});

    // Update error handler and logger with Firebase availability
    await errorHandler.initialize(firebaseAvailable: true);
    await logger.initialize(firebaseAvailable: true);
  } catch (e) {
    // If Firebase is already initialized, that's fine
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
      firebaseInitialized = true;
      await errorHandler.initialize(firebaseAvailable: true);
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
