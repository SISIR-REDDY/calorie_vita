import 'dart:async';
import 'package:flutter/services.dart';
import '../models/google_fit_data.dart';

/// Health Connect Manager - Replacement for Google Fit
/// Features:
/// - Auto-permission request on first launch
/// - Caching to avoid unnecessary API calls
/// - Background sync every 2 minutes
/// - Real-time updates via streams
/// - Instant UI reflection
class HealthConnectManager {
  static final HealthConnectManager _instance = HealthConnectManager._internal();
  factory HealthConnectManager() => _instance;
  HealthConnectManager._internal();

  static const MethodChannel _channel = MethodChannel('health_connect');
  static const Duration _cacheValidDuration = Duration(seconds: 30);
  static const Duration _syncInterval = Duration(minutes: 2);

  // State management
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isAuthenticated = false;
  bool _isSyncing = false;
  GoogleFitData? _cachedData;
  DateTime? _cacheTime;
  Timer? _syncTimer;

  // Stream controllers
  final StreamController<GoogleFitData?> _dataController = StreamController<GoogleFitData?>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<bool> _loadingController = StreamController<bool>.broadcast();

  // Public streams
  Stream<GoogleFitData?> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  bool get isConnected => _isAuthenticated && _isAvailable;
  GoogleFitData? get currentData => _cachedData;
  bool get hasValidCache => _cachedData != null && _cacheTime != null && 
      DateTime.now().difference(_cacheTime!) < _cacheValidDuration;

  /// Initialize the manager
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚡ HealthConnectManager: Already initialized');
      return;
    }

    try {
      print('🚀 HealthConnectManager: Initializing...');
      
      // Check if Health Connect is available
      final available = await _channel.invokeMethod<bool>('checkAvailability') ?? false;
      _isAvailable = available;

      if (!_isAvailable) {
        print('⚠️ HealthConnectManager: Health Connect not available');
        _isInitialized = true;
        _connectionController.add(false);
        return;
      }

      // Request permissions (auto-opens on first launch)
      await requestPermissions();

      if (_isAuthenticated) {
        print('✅ HealthConnectManager: Authenticated');
        
        // Load data immediately
        await _syncData(force: true);
        
        // Start background sync
        _startBackgroundSync();
      } else {
        print('⚠️ HealthConnectManager: Not authenticated');
      }

      _isInitialized = true;
      _connectionController.add(_isAuthenticated);
      
      print('✅ HealthConnectManager: Initialization complete');
    } catch (e) {
      print('❌ HealthConnectManager: Initialization failed: $e');
      _isInitialized = false;
      _isAvailable = false;
      _connectionController.add(false);
    }
  }

  /// Request permissions (auto-opens dialog on first launch)
  Future<bool> requestPermissions() async {
    try {
      print('🔐 HealthConnectManager: Checking permissions...');
      
      // Check if permissions are already granted
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      _isAuthenticated = result ?? false;
      
      if (_isAuthenticated) {
        print('✅ HealthConnectManager: Permissions already granted');
        _connectionController.add(true);
      } else {
        print('⚠️ HealthConnectManager: Permissions not granted (will be requested on first launch)');
        // Permissions will be auto-requested by MainActivity on first launch
        _connectionController.add(false);
      }
      
      return _isAuthenticated;
    } catch (e) {
      print('❌ HealthConnectManager: Permission check failed: $e');
      _isAuthenticated = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Sync data with caching
  Future<GoogleFitData?> _syncData({bool force = false}) async {
    // Return cached data if valid and not forced
    if (!force && hasValidCache) {
      print('⚡ HealthConnectManager: Using cached data (${DateTime.now().difference(_cacheTime!).inSeconds}s old)');
      return _cachedData;
    }

    // Prevent multiple simultaneous syncs
    if (_isSyncing) {
      print('⚠️ HealthConnectManager: Sync already in progress');
      return _cachedData;
    }

    if (!_isAuthenticated || !_isAvailable) {
      print('⚠️ HealthConnectManager: Not authenticated or not available');
      return null;
    }

    _isSyncing = true;
    _loadingController.add(true);

    try {
      print('🔄 HealthConnectManager: Fetching fresh data...');
      
      final data = await _fetchTodayData();
      
      if (data != null) {
        _cachedData = data;
        _cacheTime = DateTime.now();
        
        // Notify listeners
        _dataController.add(data);
        
        print('✅ HealthConnectManager: Data synced - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
      }
      
      return data;
    } catch (e) {
      print('❌ HealthConnectManager: Sync failed: $e');
      return _cachedData; // Return cached data on error
    } finally {
      _isSyncing = false;
      _loadingController.add(false);
    }
  }

  /// Fetch today's data in a single batch call
  Future<GoogleFitData?> _fetchTodayData() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayData');
      
      if (result == null) {
        return null;
      }

      return GoogleFitData(
        date: DateTime.now(),
        steps: result['steps'] as int?,
        caloriesBurned: (result['caloriesBurned'] as num?)?.toDouble(),
        workoutSessions: result['workoutSessions'] as int?,
        workoutDuration: (result['workoutDuration'] as num?)?.toDouble(),
      );
    } catch (e) {
      print('❌ HealthConnectManager: Fetch failed: $e');
      return null;
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_isAuthenticated && _isAvailable) {
        _syncData(force: false); // Use cache if valid
      }
    });
    print('🔄 HealthConnectManager: Background sync started ($_syncInterval)');
  }

  /// Force refresh (public method)
  Future<GoogleFitData?> forceRefresh() async {
    print('🔄 HealthConnectManager: Force refresh requested');
    return await _syncData(force: true);
  }

  /// Get current data immediately (cached)
  GoogleFitData? getCurrentData() {
    if (hasValidCache) {
      print('⚡ HealthConnectManager: Returning cached data instantly');
      return _cachedData;
    }
    
    // Trigger background sync if cache is stale
    if (_isAuthenticated && _isAvailable && !_isSyncing) {
      _syncData(force: false);
    }
    
    return _cachedData;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      print('🔌 HealthConnectManager: Signing out...');
      
      // Stop background sync
      _syncTimer?.cancel();
      
      // Clear state
      _isAuthenticated = false;
      _cachedData = null;
      _cacheTime = null;
      
      // Notify listeners
      _connectionController.add(false);
      _dataController.add(null);
      
      print('✅ HealthConnectManager: Signed out');
    } catch (e) {
      print('❌ HealthConnectManager: Sign out failed: $e');
      
      // Force reset
      _isAuthenticated = false;
      _cachedData = null;
      _cacheTime = null;
    }
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    
    if (!_dataController.isClosed) _dataController.close();
    if (!_connectionController.isClosed) _connectionController.close();
    if (!_loadingController.isClosed) _loadingController.close();
    
    print('🗑️ HealthConnectManager: Disposed');
  }
}

