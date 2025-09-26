import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'google_fit_service.dart';

/// Global Google Fit manager for automatic sync across all screens
class GlobalGoogleFitManager {
  static final GlobalGoogleFitManager _instance =
      GlobalGoogleFitManager._internal();
  factory GlobalGoogleFitManager() => _instance;
  GlobalGoogleFitManager._internal();

  final GoogleFitService _googleFitService = GoogleFitService();

  // Initialization state
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isConnected = false;

  // Auto-sync properties
  Timer? _autoSyncTimer;
  Timer? _connectionCheckTimer;
  bool _isSyncInProgress = false;

  // Stream controllers for global state
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _syncDataController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Current fitness data
  Map<String, dynamic>? _currentFitnessData;

  // Configuration
  static const Duration _autoSyncInterval = Duration(minutes: 5);
  static const Duration _connectionCheckInterval = Duration(minutes: 10);
  static const Duration _initTimeout = Duration(seconds: 8);

  /// Stream for connection state changes
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Stream for sync data updates
  Stream<Map<String, dynamic>> get syncDataStream => _syncDataController.stream;

  /// Check if Google Fit is connected
  bool get isConnected => _isConnected;

  /// Check if manager is initialized
  bool get isInitialized => _isInitialized;

  /// Get current fitness data
  Map<String, dynamic>? get currentFitnessData => _currentFitnessData;

  /// Initialize Google Fit manager globally
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;

    try {
      print('🔧 GlobalGoogleFitManager: Starting initialization...');

      // Initialize services with timeout
      await _googleFitService.initialize().timeout(_initTimeout);

      // Check authentication status
      _isConnected = await _googleFitService
          .validateAuthentication()
          .timeout(const Duration(seconds: 5));
      _isInitialized = true;

      if (_isConnected) {
        print('✅ GlobalGoogleFitManager: Connected - Starting auto sync');
        _startAutoSync();
        _startConnectionCheck();

        // Initial data sync
        _performSync();
      } else {
        print(
            '⚠️ GlobalGoogleFitManager: Not connected - Will check periodically');
        _startConnectionCheck();
      }

      // Emit initial connection state
      _connectionStateController.add(_isConnected);

      print('✅ GlobalGoogleFitManager: Initialization completed');
    } catch (e) {
      print('❌ GlobalGoogleFitManager: Initialization failed: $e');
      _isConnected = false;
      _connectionStateController.add(false);
    } finally {
      _isInitializing = false;
    }
  }

  /// Ensure Google Fit is synced when any screen is opened
  Future<void> ensureSync() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    if (!_isConnected) {
      // Try to reconnect
      await _checkConnection();
      return;
    }

    // Perform immediate sync if connected
    _performSync();
  }

  /// Start automatic sync timer
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) {
      if (_isConnected) {
        _performSync();
      }
    });

    print(
        '🔄 GlobalGoogleFitManager: Auto-sync started (${_autoSyncInterval.inMinutes}m intervals)');
  }

  /// Start connection check timer
  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(_connectionCheckInterval, (timer) {
      _checkConnection();
    });

    print(
        '🔍 GlobalGoogleFitManager: Connection check started (${_connectionCheckInterval.inMinutes}m intervals)');
  }

  /// Check Google Fit connection status
  Future<void> _checkConnection() async {
    try {
      final wasConnected = _isConnected;
      
      // Check connection using the Google Fit service
      _isConnected = await _googleFitService
          .validateAuthentication()
          .timeout(const Duration(seconds: 5));

      // If connection state changed
      if (wasConnected != _isConnected) {
        _connectionStateController.add(_isConnected);

        if (_isConnected) {
          print('✅ GlobalGoogleFitManager: Connection restored');
          _startAutoSync();
          _performSync(); // Immediate sync on reconnection
        } else {
          print('⚠️ GlobalGoogleFitManager: Connection lost');
          _autoSyncTimer?.cancel();
        }
      }
    } catch (e) {
      if (_isConnected) {
        print('⚠️ GlobalGoogleFitManager: Connection check failed: $e');
        _isConnected = false;
        _connectionStateController.add(false);
        _autoSyncTimer?.cancel();
      }
    }
  }

  /// Perform sync operation
  void _performSync() {
    if (!_isConnected || _isSyncInProgress) return;
    
    _isSyncInProgress = true;

    // Use live Google Fit service for real-time data
    _googleFitService.getTodayFitnessDataBatch().then((data) {
      if (data != null) {
        final syncData = {
          'timestamp': DateTime.now().toIso8601String(),
          'steps': data['steps'] ?? 0,
          'caloriesBurned': data['caloriesBurned'] ?? 0.0,
          'workoutSessions': data['workoutSessions'] ?? 0,
          'workoutDuration': data['workoutDuration'] ?? 0.0,
          'isAutoSync': true,
        };

        _currentFitnessData = syncData;
        _syncDataController.add(syncData);
        print(
            '🔄 GlobalGoogleFitManager: Live sync completed - Steps: ${data['steps']}');
      }
    }).catchError((e) {
      print('❌ GlobalGoogleFitManager: Live sync failed: $e');
    }).whenComplete(() {
      _isSyncInProgress = false;
    });
  }

  /// Force immediate sync (called by user action)
  Future<Map<String, dynamic>?> forceSync() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isConnected) {
      await _checkConnection();
      if (!_isConnected) {
        throw Exception('Google Fit not connected');
      }
    }

    try {
      print('🔄 GlobalGoogleFitManager: Force sync initiated');
      // Use live Google Fit service for force sync
      final data = await _googleFitService.getTodayFitnessDataBatch();

      if (data != null) {
        final syncData = {
          'timestamp': DateTime.now().toIso8601String(),
          'steps': data['steps'] ?? 0,
          'caloriesBurned': data['caloriesBurned'] ?? 0.0,
          'workoutSessions': data['workoutSessions'] ?? 0,
          'workoutDuration': data['workoutDuration'] ?? 0.0,
          'isForceSync': true,
        };

        _currentFitnessData = syncData;
        _syncDataController.add(syncData);
        print('✅ GlobalGoogleFitManager: Force sync completed');
        return syncData;
      }
    } catch (e) {
      print('❌ GlobalGoogleFitManager: Force sync failed: $e');
      rethrow;
    }

    return null;
  }

  /// Get current live data without triggering sync
  Future<Map<String, dynamic>?> getCurrentData() async {
    if (!_isConnected) return null;

    try {
      // Get live data from Google Fit service
      final data = await _googleFitService.getTodayFitnessDataBatch();
      if (data != null) {
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'steps': data['steps'] ?? 0,
          'caloriesBurned': data['caloriesBurned'] ?? 0.0,
          'workoutSessions': data['workoutSessions'] ?? 0,
          'workoutDuration': data['workoutDuration'] ?? 0.0,
          'isLive': true,
        };
      }
    } catch (e) {
      print('❌ GlobalGoogleFitManager: Failed to get live data: $e');
    }

    return null;
  }

  /// Connect to Google Fit (authentication)
  Future<bool> connect() async {
    try {
      print('🔧 GlobalGoogleFitManager: Connecting to Google Fit...');

      // Try enhanced service first
      bool success = await _googleFitService.authenticate();
      
      // Fallback to original service if enhanced fails
      if (!success) {
        print('⚠️ GlobalGoogleFitManager: Enhanced auth failed, trying fallback...');
        success = await _googleFitService.authenticate();
      }

      if (success) {
        _isConnected = true;
        _connectionStateController.add(true);

        _startAutoSync();
        _performSync(); // Initial sync

        print('✅ GlobalGoogleFitManager: Connected successfully');
        return true;
      } else {
        _isConnected = false;
        _connectionStateController.add(false);
        print('❌ GlobalGoogleFitManager: Connection failed');
        return false;
      }
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(false);
      print('❌ GlobalGoogleFitManager: Connection error: $e');
      return false;
    }
  }

  /// Disconnect from Google Fit
  Future<void> disconnect() async {
    try {
      // Disconnect from Google Fit service
      await _googleFitService.signOut();

      _isConnected = false;
      _connectionStateController.add(false);

      _autoSyncTimer?.cancel();
      _connectionCheckTimer?.cancel();

      print('🔌 GlobalGoogleFitManager: Disconnected');
    } catch (e) {
      print('❌ GlobalGoogleFitManager: Disconnect error: $e');
    }
  }

  /// Start live sync (real-time updates)
  void startLiveSync() {
    if (_isConnected) {
      _googleFitService.startLiveSync();
      print('🔴 GlobalGoogleFitManager: Live sync started');
    }
  }

  /// Stop live sync
  void stopLiveSync() {
    _googleFitService.stopLiveSync();
    print('⏸️ GlobalGoogleFitManager: Live sync stopped');
  }

  /// Check if device supports Google Fit
  bool get isSupported {
    // Google Fit requires Android or iOS with Google Play Services
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  /// Dispose resources
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _connectionStateController.close();
    _syncDataController.close();

    print('🗑️ GlobalGoogleFitManager: Disposed');
  }

  /// Reset manager (for debugging)
  void reset() {
    _autoSyncTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _isInitialized = false;
    _isInitializing = false;
    _isConnected = false;

    print('🔄 GlobalGoogleFitManager: Reset');
  }
}
