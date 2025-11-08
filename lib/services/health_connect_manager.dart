import 'dart:async';
import 'package:flutter/services.dart';
import '../models/google_fit_data.dart';

/// Health Connect Manager - Direct interface to Health Connect API
/// 
/// Architecture: Google Fit → Health Connect → This Manager → UI
/// 
/// Benefits:
/// - NO OAuth 2.0 verification required
/// - NO restricted scopes
/// - NO Google approval needed
/// - Uses Android permissions only
/// - Works with Google Fit, Samsung Health, and other apps
/// 
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
  bool _hasPermissions = false;
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
  bool get isConnected => _hasPermissions && _isAvailable;
  GoogleFitData? get currentData => _cachedData;
  bool get hasValidCache => _cachedData != null && _cacheTime != null && 
      DateTime.now().difference(_cacheTime!) < _cacheValidDuration;

  /// Initialize the manager (uses Health Connect native API)
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚡ HealthConnectManager: Already initialized');
      return;
    }

    try {
      print('🚀 HealthConnectManager: Initializing with Health Connect API...');
      
      // Check if Health Connect is available
      final available = await _channel.invokeMethod<bool>('checkAvailability') ?? false;
      _isAvailable = available;

      if (!_isAvailable) {
        print('⚠️ HealthConnectManager: Health Connect not available on this device');
        print('💡 User needs to install Health Connect from Play Store');
        _isInitialized = true;
        _connectionController.add(false);
        return;
      }

      print('✅ HealthConnectManager: Health Connect is available');

      // Check/request permissions
      await requestPermissions();

      if (_hasPermissions) {
        print('✅ HealthConnectManager: Permissions granted - ready to fetch data');
        
        // Load data immediately
        await _syncData(force: true);
        
        // Start background sync
        _startBackgroundSync();
        
        _connectionController.add(true);
      } else {
        print('⚠️ HealthConnectManager: Permissions not granted');
        print('💡 User needs to grant permissions in Health Connect settings');
        _connectionController.add(false);
      }

      _isInitialized = true;
      
      print('✅ HealthConnectManager: Initialization complete (using Health Connect API)');
    } catch (e) {
      print('❌ HealthConnectManager: Initialization failed: $e');
      _isInitialized = false;
      _isAvailable = false;
      _connectionController.add(false);
    }
  }

  /// Request permissions from Health Connect
  Future<bool> requestPermissions() async {
    try {
      print('🔐 HealthConnectManager: Checking Health Connect permissions...');
      
      // Check permissions through native Android
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      _hasPermissions = result ?? false;
      
      if (_hasPermissions) {
        print('✅ HealthConnectManager: Health Connect permissions granted');
        _connectionController.add(true);
      } else {
        print('⚠️ HealthConnectManager: Health Connect permissions not granted');
        print('💡 IMPORTANT: Health Connect requires manual permission grant!');
        print('   📱 On your phone:');
        print('   1. Open Settings');
        print('   2. Search for "Health Connect"');
        print('   3. Tap "App permissions"');
        print('   4. Find "CalorieVita"');
        print('   5. Enable: Steps, Calories, Exercise, Heart Rate');
        print('   6. Restart this app');
        _connectionController.add(false);
      }
      
      return _hasPermissions;
    } catch (e) {
      print('❌ HealthConnectManager: Permission check failed: $e');
      _hasPermissions = false;
      _connectionController.add(false);
      return false;
    }
  }
  
  /// Open Health Connect settings (if available)
  Future<void> openHealthConnectSettings() async {
    try {
      print('📱 HealthConnectManager: Opening Health Connect settings...');
      // Note: This requires adding an intent handler in native code
      // For now, just log instructions
      print('💡 Please manually open: Settings → Health Connect → App permissions → CalorieVita');
    } catch (e) {
      print('❌ Failed to open Health Connect settings: $e');
    }
  }

  /// Sync data from Health Connect with caching
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

    if (!_hasPermissions || !_isAvailable) {
      print('⚠️ HealthConnectManager: Cannot sync - no permissions or Health Connect not available');
      return null;
    }

    _isSyncing = true;
    _loadingController.add(true);

    try {
      print('🔄 HealthConnectManager: Fetching data from Health Connect...');
      
      final data = await _fetchTodayData();
      
      if (data != null) {
        _cachedData = data;
        _cacheTime = DateTime.now();
        
        // Notify listeners
        _dataController.add(data);
        
        print('✅ HealthConnectManager: Data synced from Health Connect - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
        print('📊 Data source: Health Connect → Google Fit/Samsung Health');
      } else {
        print('⚠️ HealthConnectManager: No data available from Health Connect');
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

  /// Fetch today's data from Health Connect native API
  Future<GoogleFitData?> _fetchTodayData() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayData');
      
      if (result == null) {
        print('⚠️ HealthConnectManager: getTodayData returned null');
        return null;
      }

      final data = GoogleFitData(
        date: DateTime.now(),
        steps: result['steps'] as int?,
        caloriesBurned: (result['caloriesBurned'] as num?)?.toDouble(),
        workoutSessions: result['workoutSessions'] as int?,
        workoutDuration: (result['workoutDuration'] as num?)?.toDouble(),
      );
      
      print('📊 HealthConnectManager: Received data from native - Steps: ${data.steps}, Calories: ${data.caloriesBurned}, Workouts: ${data.workoutSessions}');
      
      return data;
    } catch (e) {
      print('❌ HealthConnectManager: Fetch from Health Connect failed: $e');
      return null;
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_hasPermissions && _isAvailable) {
        _syncData(force: false); // Use cache if valid
      }
    });
    print('🔄 HealthConnectManager: Background sync started ($_syncInterval)');
  }

  /// Force refresh from Health Connect (public method)
  Future<GoogleFitData?> forceRefresh() async {
    print('🔄 HealthConnectManager: Force refresh requested from Health Connect');
    return await _syncData(force: true);
  }

  /// Get current data immediately (cached)
  GoogleFitData? getCurrentData() {
    if (hasValidCache) {
      print('⚡ HealthConnectManager: Returning cached Health Connect data');
      return _cachedData;
    }
    
    // Trigger background sync if cache is stale
    if (_hasPermissions && _isAvailable && !_isSyncing) {
      _syncData(force: false);
    }
    
    return _cachedData;
  }

  /// Sign out (clear Health Connect data)
  Future<void> signOut() async {
    try {
      print('🔌 HealthConnectManager: Signing out...');
      
      // Stop background sync
      _syncTimer?.cancel();
      
      // Clear state
      _hasPermissions = false;
      _cachedData = null;
      _cacheTime = null;
      
      // Notify listeners
      _connectionController.add(false);
      _dataController.add(null);
      
      print('✅ HealthConnectManager: Signed out');
    } catch (e) {
      print('❌ HealthConnectManager: Sign out failed: $e');
      
      // Force reset
      _hasPermissions = false;
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
