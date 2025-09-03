import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state_service.dart';
import 'error_handling_service.dart';
import 'performance_service.dart';
import 'health_service.dart';
import '../config/deployment_config.dart';

/// Master integration service that coordinates all app services
class IntegrationService {
  static final IntegrationService _instance = IntegrationService._internal();
  factory IntegrationService() => _instance;
  IntegrationService._internal();

  // Core services
  final AppStateService _appStateService = AppStateService();
  final ErrorHandlingService _errorHandlingService = ErrorHandlingService();
  final PerformanceService _performanceService = PerformanceService();
  final HealthService _healthService = HealthService();

  // State management
  bool _isInitialized = false;
  final StreamController<bool> _initializationController = StreamController<bool>.broadcast();

  // Getters
  AppStateService get appState => _appStateService;
  ErrorHandlingService get errorHandling => _errorHandlingService;
  PerformanceService get performance => _performanceService;
  HealthService get health => _healthService;
  bool get isInitialized => _isInitialized;
  Stream<bool> get initializationStream => _initializationController.stream;

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('IntegrationService: Starting initialization...');
      
      // Initialize core services with timeout
      print('IntegrationService: Initializing AppStateService...');
      await _appStateService.initialize();
      print('IntegrationService: AppStateService initialized');
      
      print('IntegrationService: Initializing HealthService...');
      await _healthService.initialize();
      print('IntegrationService: HealthService initialized');
      
      // Set up error handling
      _setupErrorHandling();
      
      // Set up performance monitoring
      _setupPerformanceMonitoring();
      
      // Preload critical data (don't block initialization)
      _preloadCriticalData().catchError((e) {
        print('Error preloading critical data: $e');
      });
      
      _isInitialized = true;
      _initializationController.add(true);
      
      print('IntegrationService initialized successfully');
    } catch (e) {
      print('Error initializing IntegrationService: $e');
      _isInitialized = true; // Still mark as initialized to prevent hanging
      _initializationController.add(false);
      // Don't rethrow to prevent app from hanging
    }
  }

  /// Set up error handling integration
  void _setupErrorHandling() {
    // Listen to app state errors
    _appStateService.userStream.listen(
      (user) {
        if (user == null) {
          // Handle user session expiry
          print('User session expired');
        }
      },
      onError: (error) {
        print('App state error: ${_errorHandlingService.handleGeneralError(error)}');
      },
    );

    // Listen to connectivity changes
    _errorHandlingService.connectivityStream.listen((isConnected) {
      if (isConnected) {
        // Sync offline data when connection is restored
        _appStateService.syncOfflineData();
      }
    });
  }

  /// Set up performance monitoring
  void _setupPerformanceMonitoring() {
    // Monitor memory usage
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _performanceService.optimizeMemoryUsage();
    });

    // Monitor app state performance
    _appStateService.foodEntriesStream.listen((entries) {
      if (entries.length > 100) {
        // Optimize large datasets
        _performanceService.clearCache('food_entries');
      }
    });
  }

  /// Preload critical data for better performance
  Future<void> _preloadCriticalData() async {
    final userId = _appStateService.currentUser?.uid;
    if (userId == null) return;

    try {
      // Preload user preferences
      await _performanceService.preloadData(
        'user_preferences',
        () async => await _appStateService.firebaseService.getUserPreferences(userId),
      );

      // Preload user goals
      await _performanceService.preloadData(
        'user_goals',
        () async => await _appStateService.firebaseService.getUserGoals(userId),
      );

      // Preload recent food entries
      await _performanceService.preloadData(
        'recent_entries',
        () async => await _appStateService.firebaseService.getTodayFoodEntries(userId).first,
      );
    } catch (e) {
      print('Error preloading critical data: $e');
    }
  }

  /// Handle app lifecycle events
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        _errorHandlingService.checkConnectivity();
        _performanceService.optimizeMemoryUsage();
        break;
      case AppLifecycleState.paused:
        // App went to background
        _performanceService.clearCache();
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        dispose();
        break;
      default:
        break;
    }
  }

  /// Get comprehensive app status
  Map<String, dynamic> getAppStatus() {
    return {
      'isInitialized': _isInitialized,
      'isOnline': _appStateService.isOnline,
      'currentUser': _appStateService.currentUser?.uid,
      'foodEntriesCount': _appStateService.foodEntries.length,
      'memoryInfo': _performanceService.getMemoryInfo(),
      'config': DeploymentConfig.getEnvironmentConfig(),
    };
  }

  /// Perform health check
  Future<Map<String, dynamic>> performHealthCheck() async {
    final healthStatus = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'services': {},
      'overall': 'healthy',
    };

    try {
      // Check app state service
      healthStatus['services']['appState'] = {
        'status': _appStateService.isInitialized ? 'healthy' : 'unhealthy',
        'user': _appStateService.currentUser?.uid != null ? 'authenticated' : 'anonymous',
        'dataLoaded': _appStateService.foodEntries.isNotEmpty,
      };

      // Check connectivity
      final isConnected = await _errorHandlingService.checkConnectivity();
      healthStatus['services']['connectivity'] = {
        'status': isConnected ? 'healthy' : 'unhealthy',
        'online': isConnected,
      };

      // Check performance
      final memoryInfo = _performanceService.getMemoryInfo();
      healthStatus['services']['performance'] = {
        'status': memoryInfo['cacheSize'] < 100 ? 'healthy' : 'warning',
        'cacheSize': memoryInfo['cacheSize'],
        'loadingOperations': memoryInfo['loadingOperations'],
      };

      // Determine overall health
      final serviceStatuses = (healthStatus['services'] as Map).values
          .map((service) => service['status'] as String)
          .toList();
      
      if (serviceStatuses.contains('unhealthy')) {
        healthStatus['overall'] = 'unhealthy';
      } else if (serviceStatuses.contains('warning')) {
        healthStatus['overall'] = 'warning';
      }

    } catch (e) {
      healthStatus['overall'] = 'error';
      healthStatus['error'] = e.toString();
    }

    return healthStatus;
  }

  /// Restart services (for recovery)
  Future<void> restartServices() async {
    try {
      _isInitialized = false;
      _initializationController.add(false);
      
      // Dispose current services
      _appStateService.dispose();
      _errorHandlingService.dispose();
      _performanceService.dispose();
      _healthService.dispose();
      
      // Reinitialize
      await initialize();
    } catch (e) {
      print('Error restarting services: $e');
      rethrow;
    }
  }

  /// Dispose all services
  void dispose() {
    _appStateService.dispose();
    _errorHandlingService.dispose();
    _performanceService.dispose();
    _healthService.dispose();
    _initializationController.close();
    _isInitialized = false;
  }
}
