import 'dart:async';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/google_fit_data.dart';
import 'bmr_calculator.dart';

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

  // User profile data for BMR calculation (cached for performance)
  double? _userWeight;
  double? _userHeight;
  int? _userAge;
  String? _userGender;
  DateTime? _profileLastFetched;

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
        print('   5. Enable: Steps, Active calories burned, Total calories burned, Exercise');
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

  /// Load user profile data for BMR calculation (cached for performance)
  Future<void> _loadUserProfile() async {
    try {
      // Only fetch if cache is old (> 1 hour) or doesn't exist
      if (_profileLastFetched != null && 
          DateTime.now().difference(_profileLastFetched!) < const Duration(hours: 1)) {
        return; // Use cached profile
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ HealthConnectManager: No user logged in');
        return;
      }

      // Read from correct location: users/{uid}/profile/userData
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('userData')
          .get();

      if (!doc.exists) {
        print('⚠️ HealthConnectManager: No profile data found at users/${user.uid}/profile/userData');
        return;
      }

      final data = doc.data()!;
      _userWeight = (data['weight'] as num?)?.toDouble();
      _userHeight = (data['height'] as num?)?.toDouble();
      _userAge = data['age'] as int?;
      _userGender = data['gender'] as String?;
      _profileLastFetched = DateTime.now();

      print('✅ HealthConnectManager: User profile loaded for BMR calculation');
      print('   Weight: $_userWeight kg, Height: $_userHeight cm, Age: $_userAge, Gender: $_userGender');
    } catch (e) {
      print('⚠️ HealthConnectManager: Failed to load user profile: $e');
    }
  }

  /// Calculate active calories DIRECTLY from activity data (like Cal AI does)
  /// This is more accurate than trying to parse total calories
  double _calculateActiveCalories(int steps, int workoutSessions, double? workoutDuration) {
    print('🔍 DEBUG: Calculating active calories from activity data');
    print('   Steps: $steps, Workouts: $workoutSessions, Duration: ${workoutDuration ?? 0} mins');
    
    double totalActive = 0.0;
    
    // 1. Calories from STEPS (most accurate for walking/running)
    final stepsCalories = _estimateCaloriesFromSteps(steps);
    totalActive += stepsCalories;
    print('   📊 Steps calories: ${stepsCalories.toStringAsFixed(1)} kcal');
    
    // 2. Calories from WORKOUTS (if any)
    if (workoutSessions > 0 && workoutDuration != null && workoutDuration > 0) {
      // Average workout burns 5-10 kcal/min depending on intensity
      // Use 7 kcal/min as moderate intensity
      final workoutCalories = workoutDuration * 7.0;
      totalActive += workoutCalories;
      print('   🏋️ Workout calories: ${workoutCalories.toStringAsFixed(1)} kcal');
    }
    
    // 3. Add baseline activity calories for the day (phone movements, standing, etc.)
    // Google Fit typically adds 50-100 kcal for general daily movements
    final now = DateTime.now();
    final hoursElapsed = now.hour + now.minute / 60.0;
    
    // Scale baseline by time of day: 100 kcal over 24 hours = ~4 kcal/hour
    final baselineCalories = (hoursElapsed / 24.0) * 100.0;
    totalActive += baselineCalories;
    print('   🕒 Baseline activity (${hoursElapsed.toStringAsFixed(1)}h): ${baselineCalories.toStringAsFixed(1)} kcal');
    
    print('✅ Total active calories: ${totalActive.toStringAsFixed(1)} kcal');
    
    return totalActive;
  }

  /// Estimate calories burned from steps
  /// Average: 0.04-0.05 kcal per step, adjusted by weight
  double _estimateCaloriesFromSteps(int steps) {
    if (steps <= 0) return 0.0;
    
    // Base rate: 0.045 kcal per step for 70kg person
    // Adjust by user's weight if available
    final weightFactor = _userWeight != null ? (_userWeight! / 70.0) : 1.0;
    final caloriesPerStep = 0.045 * weightFactor;
    
    return steps * caloriesPerStep;
  }

  /// Fetch today's data from Health Connect native API
  Future<GoogleFitData?> _fetchTodayData() async {
    try {
      // Load user profile for weight-adjusted calorie calculations
      await _loadUserProfile();

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayData');
      
      if (result == null) {
        print('⚠️ HealthConnectManager: getTodayData returned null');
        return null;
      }

      // Get raw data from Health Connect
      final steps = result['steps'] as int? ?? 0;
      final workoutSessions = result['workoutSessions'] as int? ?? 0;
      final workoutDuration = (result['workoutDuration'] as num?)?.toDouble();
      
      // Calculate active calories DIRECTLY from activity data (more accurate)
      final activeCalories = _calculateActiveCalories(steps, workoutSessions, workoutDuration);
      
      final data = GoogleFitData(
        date: DateTime.now(),
        steps: steps,
        caloriesBurned: activeCalories, // Active calories from steps + workouts + baseline
        workoutSessions: workoutSessions,
        workoutDuration: workoutDuration,
      );
      
      print('📊 HealthConnectManager: Received data from native');
      print('   Steps: ${data.steps}');
      print('   Calories (active): ${data.caloriesBurned?.toStringAsFixed(1)}');
      print('   Workouts: ${data.workoutSessions}');
      
      if (data.caloriesBurned == null || data.caloriesBurned == 0.0) {
        print('⚠️ WARNING: Active calories are ${data.caloriesBurned ?? 'null'}!');
        print('💡 Possible reasons:');
        print('   1. Haven\'t done any activity yet today');
        print('   2. Total calories = basal calories (no active movement)');
      } else {
        print('✅ Active calories calculated: ${data.caloriesBurned?.toStringAsFixed(1)} kcal');
      }
      
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

  /// Clear profile cache (call when user profile changes)
  void clearProfileCache() {
    _userWeight = null;
    _userHeight = null;
    _userAge = null;
    _userGender = null;
    _profileLastFetched = null;
    BMRCalculator.clearCache();
    print('🔄 HealthConnectManager: Profile cache cleared');
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
      
      // Clear profile cache
      clearProfileCache();
      
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
      clearProfileCache();
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
