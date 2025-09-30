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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only (both upright and upside-down)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize performance monitoring first
  final performanceMonitor = PerformanceMonitor();
  await performanceMonitor.initialize();
  performanceMonitor.startTimer('app_startup');

  // Initialize network service
  final networkService = NetworkService();
  await networkService.initialize();

  // Initialize error handler
  final errorHandler = ErrorHandler();
  await errorHandler.initialize();

  // Initialize Firebase with basic configuration
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase services
    await _initializeFirebaseServices();

    firebaseInitialized = true;
    print('✅ Firebase initialized successfully');
    performanceMonitor.logEvent('firebase_initialized', {'success': true});

    // Update error handler with Firebase availability
    await errorHandler.initialize(firebaseAvailable: true);
  } catch (e) {
    // If Firebase is already initialized, that's fine
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
      firebaseInitialized = true;
      await errorHandler.initialize(firebaseAvailable: true);
    } else {
      print('❌ Firebase initialization error: $e');
      print('Continuing without Firebase - app will work in demo mode');
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
  print('App startup completed in ${startupDuration['average_ms']}ms');

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
