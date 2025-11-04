import 'dart:async';
import 'firebase_service.dart';
import 'performance_monitor.dart';
import 'network_service.dart';
import 'error_handler.dart';
import 'auth_service.dart';
import '../config/ai_config.dart';

/// Centralized app state manager that coordinates all services
class AppStateManager {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  // Services
  late final FirebaseService _firebaseService;
  late final PerformanceMonitor _performanceMonitor;
  late final NetworkService _networkService;
  late final ErrorHandler _errorHandler;
  late final AuthService _authService;

  // State
  bool _isInitialized = false;
  bool _isOnline = true;
  bool _isFirebaseAvailable = false;
  String _currentUserId = '';

  // Streams
  final StreamController<AppState> _stateController =
      StreamController<AppState>.broadcast();
  final StreamController<bool> _initializationController =
      StreamController<bool>.broadcast();

  // Getters
  Stream<AppState> get stateStream => _stateController.stream;
  Stream<bool> get initializationStream => _initializationController.stream;
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  String get currentUserId => _currentUserId;

  // Service getters
  FirebaseService get firebaseService => _firebaseService;
  PerformanceMonitor get performanceMonitor => _performanceMonitor;
  NetworkService get networkService => _networkService;
  ErrorHandler get errorHandler => _errorHandler;
  AuthService get authService => _authService;

  /// Initialize the app state manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 Initializing AppStateManager...');

      // Initialize services
      _firebaseService = FirebaseService();
      _performanceMonitor = PerformanceMonitor();
      _networkService = NetworkService();
      _errorHandler = ErrorHandler();
      _authService = AuthService();

      // Initialize performance monitoring first
      await _performanceMonitor.initialize();
      _performanceMonitor.startTimer('app_state_init');

      // Initialize error handler
      await _errorHandler.initialize();

      // Initialize network service
      await _networkService.initialize();
      _isOnline = _networkService.isOnline;

      // Listen to network changes
      _networkService.connectivityStream.listen((isOnline) {
        _isOnline = isOnline;
        _updateAppState();
        _performanceMonitor.startTimer('network_status_changed');
        _performanceMonitor.stopTimer('network_status_changed');
      });

      // Initialize Firebase service
      _isFirebaseAvailable = _firebaseService.isAvailable;

      // Initialize auth service
      await _authService.initialize();

      // Check if there's already a current user
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        _currentUserId = currentUser.uid;
        print('Current user found during initialization: ${currentUser.email}');
        // Load API config after authentication (for secure access)
        _loadAIConfigAfterAuth();
      }

      // Listen to auth changes
      _authService.userStream.listen((user) {
        print(
            'Auth state changed: user=${user?.uid ?? 'null'}, email=${user?.email ?? 'null'}');
        _currentUserId = user?.uid ?? '';
        
        // Load API config when user authenticates (for secure access)
        if (user != null) {
          _loadAIConfigAfterAuth();
        }
        
        _updateAppState();
        _performanceMonitor.startTimer('auth_state_changed');
        _performanceMonitor.stopTimer('auth_state_changed');
      });

      _isInitialized = true;
      _initializationController.add(true);
      _updateAppState();

      _performanceMonitor.stopTimer('app_state_init');
      print('✅ AppStateManager initialized successfully');
    } catch (e) {
      print('❌ Error initializing AppStateManager: $e');
      _errorHandler.handleBusinessError('app_state_init', e);
      _initializationController.add(false);
    }
  }

  /// Update the current app state
  void _updateAppState() {
    final state = AppState(
      isInitialized: _isInitialized,
      isOnline: _isOnline,
      isFirebaseAvailable: _isFirebaseAvailable,
      currentUserId: _currentUserId,
      timestamp: DateTime.now(),
    );

    print(
        'Updating app state: userId=$_currentUserId, initialized=$_isInitialized');
    _stateController.add(state);
  }

  /// Manually update user state (useful for immediate navigation)
  Future<void> updateUserState(String userId) async {
    print('🔄 Manually updating user state: $userId');
    _currentUserId = userId;
    _updateAppState();
    print('✅ User state updated successfully');
  }

  /// Get current app state
  AppState getCurrentState() {
    return AppState(
      isInitialized: _isInitialized,
      isOnline: _isOnline,
      isFirebaseAvailable: _isFirebaseAvailable,
      currentUserId: _currentUserId,
      timestamp: DateTime.now(),
    );
  }

  /// Get app health status
  Future<AppHealthStatus> getHealthStatus() async {
    final performanceStats = _performanceMonitor.getAllStats();
    final errorStats = _errorHandler.getErrorStats();
    final networkInfo = await _networkService.getNetworkInfo();

    // Calculate health score (0-100)
    int healthScore = 100;

    // Deduct points for errors
    final totalErrors = errorStats['total_errors'] as int;
    if (totalErrors > 0) {
      healthScore -= (totalErrors * 2).clamp(0, 50);
    }

    // Deduct points for performance issues
    final slowOps = _performanceMonitor.getSlowOperations(thresholdMs: 2000);
    if (slowOps.isNotEmpty) {
      healthScore -= (slowOps.length * 5).clamp(0, 30);
    }

    // Deduct points for offline status
    if (!_isOnline) {
      healthScore -= 20;
    }

    // Deduct points for Firebase unavailability
    if (!_isFirebaseAvailable) {
      healthScore -= 10;
    }

    healthScore = healthScore.clamp(0, 100);

    return AppHealthStatus(
      score: healthScore,
      isHealthy: healthScore >= 70,
      performanceStats: performanceStats,
      errorStats: errorStats,
      networkInfo: networkInfo,
      recommendations:
          _getHealthRecommendations(healthScore, errorStats, slowOps),
    );
  }

  /// Get health recommendations
  List<String> _getHealthRecommendations(int healthScore,
      Map<String, dynamic> errorStats, List<Map<String, dynamic>> slowOps) {
    final recommendations = <String>[];

    if (healthScore < 70) {
      recommendations.add(
          'App health is below optimal. Consider reviewing the issues below.');
    }

    if (!_isOnline) {
      recommendations.add('App is offline. Check internet connection.');
    }

    if (!_isFirebaseAvailable) {
      recommendations
          .add('Firebase is not available. App is running in demo mode.');
    }

    final totalErrors = errorStats['total_errors'] as int;
    if (totalErrors > 10) {
      recommendations
          .add('High error count detected. Review error logs for details.');
    }

    if (slowOps.isNotEmpty) {
      recommendations.add(
          'Performance issues detected. Consider optimizing slow operations.');
    }

    return recommendations;
  }

  /// Force refresh all services
  Future<void> refreshServices() async {
    try {
      _performanceMonitor.startTimer('services_refresh');

      // Refresh network status
      await _networkService.initialize();
      _isOnline = _networkService.isOnline;

      // Refresh Firebase availability
      _isFirebaseAvailable = _firebaseService.isAvailable;

      // Refresh auth state
      await _authService.initialize();

      _updateAppState();
      _performanceMonitor.stopTimer('services_refresh');

      print('✅ Services refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing services: $e');
      _errorHandler.handleBusinessError('services_refresh', e);
    }
  }

  /// Clear all caches
  void clearCaches() {
    try {
      // Clear Firebase cache
      _performanceMonitor.clearData();
      print('✅ All caches cleared');
    } catch (e) {
      print('❌ Error clearing caches: $e');
      _errorHandler.handleBusinessError('clear_caches', e);
    }
  }

  /// Load AI config after authentication (for secure API key access)
  Future<void> _loadAIConfigAfterAuth() async {
    try {
      print('🔐 User authenticated - loading secure AI config from Firestore...');
      await AIConfig.refresh();
      
      final apiKey = AIConfig.apiKey;
      if (apiKey.isNotEmpty) {
        print('✅ API Key loaded after authentication: ${apiKey.length} characters');
        print('   🔑 Key preview: ${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}');
      } else {
        print('⚠️ API Key is still empty after authentication');
        print('   📌 Check Firestore config at: app_config/ai_settings/openrouter_api_key');
      }
    } catch (e) {
      print('❌ Error loading AI config after authentication: $e');
      _errorHandler.handleBusinessError('ai_config_load_after_auth', e);
    }
  }

  /// Get comprehensive app diagnostics
  Future<Map<String, dynamic>> getDiagnostics() async {
    return {
      'app_state': getCurrentState().toMap(),
      'health_status': await getHealthStatus(),
      'performance_stats': _performanceMonitor.getAllStats(),
      'error_stats': _errorHandler.getErrorStats(),
      'network_info': _networkService.getNetworkInfo(),
      'firebase_stats': 'Firebase service available: ${_firebaseService.isAvailable}',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose all resources
  void dispose() {
    _stateController.close();
    _initializationController.close();
    // _firebaseService.dispose(); // FirebaseService doesn't have dispose method
    // _performanceMonitor.dispose(); // PerformanceMonitor doesn't have dispose method
    _networkService.dispose();
    _errorHandler.dispose();
    _authService.dispose();
    print('AppStateManager disposed');
  }
}

/// App state model
class AppState {
  final bool isInitialized;
  final bool isOnline;
  final bool isFirebaseAvailable;
  final String currentUserId;
  final DateTime timestamp;

  AppState({
    required this.isInitialized,
    required this.isOnline,
    required this.isFirebaseAvailable,
    required this.currentUserId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'is_initialized': isInitialized,
      'is_online': isOnline,
      'is_firebase_available': isFirebaseAvailable,
      'current_user_id': currentUserId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AppState(initialized: $isInitialized, online: $isOnline, firebase: $isFirebaseAvailable, user: $currentUserId)';
  }
}

/// App health status model
class AppHealthStatus {
  final int score;
  final bool isHealthy;
  final Map<String, dynamic> performanceStats;
  final Map<String, dynamic> errorStats;
  final Map<String, dynamic> networkInfo;
  final List<String> recommendations;

  AppHealthStatus({
    required this.score,
    required this.isHealthy,
    required this.performanceStats,
    required this.errorStats,
    required this.networkInfo,
    required this.recommendations,
  });

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'is_healthy': isHealthy,
      'performance_stats': performanceStats,
      'error_stats': errorStats,
      'network_info': networkInfo,
      'recommendations': recommendations,
    };
  }
}
