import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/google_fit_data.dart';
import 'google_fit_service.dart';
import 'optimized_google_fit_service.dart';

/// Optimized Google Fit Cache Service for fast data loading
/// 
/// This service implements a multi-tier caching strategy:
/// 1. Memory cache (fastest) - for immediate UI updates
/// 2. Local storage cache (fast) - for app restarts
/// 3. Firebase cache (medium) - for cross-device sync
/// 4. Google Fit API (slowest) - for fresh data
class OptimizedGoogleFitCacheService {
  static final OptimizedGoogleFitCacheService _instance = 
      OptimizedGoogleFitCacheService._internal();
  factory OptimizedGoogleFitCacheService() => _instance;
  OptimizedGoogleFitCacheService._internal();

  // Services
  final GoogleFitService _googleFitService = GoogleFitService();
  final OptimizedGoogleFitService _optimizedGoogleFitService = OptimizedGoogleFitService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Memory cache (fastest access)
  GoogleFitData? _memoryCache;
  DateTime? _memoryCacheTimestamp;
  static const Duration _memoryCacheExpiry = Duration(minutes: 2);

  // Local storage cache keys
  static const String _localCacheKey = 'google_fit_local_cache';
  static const String _localCacheTimestampKey = 'google_fit_local_timestamp';
  static const String _localCacheExpiryKey = 'google_fit_local_expiry';
  static const Duration _localCacheExpiry = Duration(minutes: 10);

  // Firebase cache configuration
  static const Duration _firebaseCacheExpiry = Duration(minutes: 15);

  // Background sync
  Timer? _backgroundSyncTimer;
  Timer? _memoryRefreshTimer;
  static const Duration _backgroundSyncInterval = Duration(minutes: 5);
  static const Duration _memoryRefreshInterval = Duration(minutes: 1);

  // Stream controllers for real-time updates
  final StreamController<GoogleFitData> _liveDataController = 
      StreamController<GoogleFitData>.broadcast();
  final StreamController<bool> _connectionStateController = 
      StreamController<bool>.broadcast();

  // State management
  bool _isInitialized = false;
  bool _isBackgroundSyncActive = false;
  bool _isLoading = false;

  /// Stream for live data updates
  Stream<GoogleFitData> get liveDataStream => _liveDataController.stream;

  /// Stream for connection state changes
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if background sync is active
  bool get isBackgroundSyncActive => _isBackgroundSyncActive;

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 OptimizedGoogleFitCacheService: Initializing...');

      // Initialize underlying services
      await Future.wait([
        _googleFitService.initialize(),
        _optimizedGoogleFitService.initialize(),
      ]);

      // Load cached data into memory
      await _loadCachedDataIntoMemory();

      // Start background sync
      _startBackgroundSync();

      // Start memory refresh timer
      _startMemoryRefreshTimer();

      _isInitialized = true;
      print('✅ OptimizedGoogleFitCacheService: Initialized successfully');
    } catch (e) {
      print('❌ OptimizedGoogleFitCacheService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Get today's Google Fit data with optimized caching
  Future<GoogleFitData?> getTodayData({bool forceRefresh = false}) async {
    try {
      // 1. Check memory cache first (fastest)
      if (!forceRefresh && _isMemoryCacheValid()) {
        print('📱 Using memory cache for Google Fit data');
        return _memoryCache;
      }

      // 2. Check if already loading to prevent duplicate requests
      if (_isLoading) {
        print('⏳ Google Fit data already loading, waiting...');
        // Wait for current request to complete
        await Future.delayed(const Duration(milliseconds: 500));
        return _memoryCache;
      }

      _isLoading = true;

      try {
        // 3. Try local storage cache
        if (!forceRefresh) {
          final localData = await _getLocalStorageCache();
          if (localData != null && await _isLocalCacheValid(localData)) {
            print('💾 Using local storage cache for Google Fit data');
            await _updateMemoryCache(localData);
            return localData;
          }
        }

        // 4. Try Firebase cache
        if (!forceRefresh) {
          final firebaseData = await _getFirebaseCache();
          if (firebaseData != null && _isFirebaseCacheValid(firebaseData)) {
            print('🔥 Using Firebase cache for Google Fit data');
            await _updateMemoryCache(firebaseData);
            await _saveToLocalStorage(firebaseData);
            return firebaseData;
          }
        }

        // 5. Fetch from Google Fit API (slowest)
        print('🌐 Fetching fresh data from Google Fit API...');
        
        // Clear all cache layers before fetching fresh data
        await _clearAllCacheLayers();
        
        final freshData = await _fetchFreshDataFromAPI();
        
        if (freshData != null) {
          // Update all cache layers with fresh data
          await _updateMemoryCache(freshData);
          await _saveToLocalStorage(freshData);
          await _saveToFirebaseCache(freshData);
          
          // Emit to live stream
          _liveDataController.add(freshData);
          
          print('✅ Fresh Google Fit data fetched and cached');
          return freshData;
        } else {
          // Return best available cached data
          print('⚠️ API fetch failed, returning best cached data');
          return _memoryCache;
        }
      } finally {
        _isLoading = false;
      }
    } catch (e) {
      print('❌ Error getting today data: $e');
      _isLoading = false;
      return _memoryCache; // Return cached data as fallback
    }
  }

  /// Load cached data into memory on initialization
  Future<void> _loadCachedDataIntoMemory() async {
    try {
      // Try local storage first (faster than Firebase)
      final localData = await _getLocalStorageCache();
      if (localData != null) {
        _memoryCache = localData;
        _memoryCacheTimestamp = DateTime.now();
        print('💾 Loaded local cache into memory');
        return;
      }

      // Fallback to Firebase cache
      final firebaseData = await _getFirebaseCache();
      if (firebaseData != null) {
        _memoryCache = firebaseData;
        _memoryCacheTimestamp = DateTime.now();
        print('🔥 Loaded Firebase cache into memory');
      }
    } catch (e) {
      print('⚠️ Error loading cached data into memory: $e');
    }
  }

  /// Check if memory cache is valid
  bool _isMemoryCacheValid() {
    if (_memoryCache == null || _memoryCacheTimestamp == null) return false;
    
    // Check if cache is for today and not expired
    final now = DateTime.now();
    final isToday = _memoryCache!.date.year == now.year &&
        _memoryCache!.date.month == now.month &&
        _memoryCache!.date.day == now.day;
    
    final isNotExpired = now.difference(_memoryCacheTimestamp!) < _memoryCacheExpiry;
    
    return isToday && isNotExpired;
  }

  /// Update memory cache
  Future<void> _updateMemoryCache(GoogleFitData data) async {
    // Clear old cache data first to ensure clean replacement
    _memoryCache = null;
    _memoryCacheTimestamp = null;
    
    // Then set new data
    _memoryCache = data;
    _memoryCacheTimestamp = DateTime.now();
  }

  /// Get data from local storage
  Future<GoogleFitData?> _getLocalStorageCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_localCacheKey);
      final timestampStr = prefs.getString(_localCacheTimestampKey);
      
      if (cacheData != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        return GoogleFitData.fromJson(jsonDecode(cacheData));
      }
    } catch (e) {
      print('⚠️ Error reading local storage cache: $e');
    }
    return null;
  }

  /// Check if local cache is valid
  Future<bool> _isLocalCacheValid(GoogleFitData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_localCacheTimestampKey);
      if (timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();
        
        // Check if cache is for today and not expired
        final isToday = data.date.year == now.year &&
            data.date.month == now.month &&
            data.date.day == now.day;
        
        final isNotExpired = now.difference(timestamp) < _localCacheExpiry;
        
        return isToday && isNotExpired;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Save data to local storage
  Future<void> _saveToLocalStorage(GoogleFitData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear old cache data first to ensure clean replacement
      await prefs.remove(_localCacheKey);
      await prefs.remove(_localCacheTimestampKey);
      await prefs.remove(_localCacheExpiryKey);
      
      // Then save new data
      await prefs.setString(_localCacheKey, jsonEncode(data.toJson()));
      await prefs.setString(_localCacheTimestampKey, DateTime.now().toIso8601String());
      await prefs.setString(_localCacheExpiryKey, DateTime.now().add(_localCacheExpiry).toIso8601String());
    } catch (e) {
      print('⚠️ Error saving to local storage: $e');
    }
  }

  /// Get data from Firebase cache
  Future<GoogleFitData?> _getFirebaseCache() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final today = DateTime.now();
      final dateKey = _getDateKey(today);

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('googleFitCache')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return GoogleFitData(
          date: (data['timestamp'] as Timestamp).toDate(),
          steps: data['steps'] as int?,
          caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble(),
          distance: (data['distance'] as num?)?.toDouble(),
          weight: (data['weight'] as num?)?.toDouble(),
        );
      }
    } catch (e) {
      print('⚠️ Error reading Firebase cache: $e');
    }
    return null;
  }

  /// Check if Firebase cache is valid
  bool _isFirebaseCacheValid(GoogleFitData data) {
    final now = DateTime.now();
    
    // Check if cache is for today and not expired
    final isToday = data.date.year == now.year &&
        data.date.month == now.month &&
        data.date.day == now.day;
    
    final isNotExpired = now.difference(data.date) < _firebaseCacheExpiry;
    
    return isToday && isNotExpired;
  }

  /// Save data to Firebase cache
  Future<void> _saveToFirebaseCache(GoogleFitData data) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final dateKey = _getDateKey(data.date);

      // First, delete any existing data for this date to ensure clean replacement
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('googleFitCache')
          .doc(dateKey)
          .delete();

      // Then set the new data (no merge to ensure complete replacement)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('googleFitCache')
          .doc(dateKey)
          .set({
        'steps': data.steps,
        'caloriesBurned': data.caloriesBurned,
        'distance': data.distance,
        'weight': data.weight,
        'timestamp': Timestamp.fromDate(data.date),
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print('⚠️ Error saving to Firebase cache: $e');
    }
  }

  /// Fetch fresh data from Google Fit API
  Future<GoogleFitData?> _fetchFreshDataFromAPI() async {
    try {
      // Try optimized service first
      final optimizedData = await _optimizedGoogleFitService.getOptimizedFitnessData();
      if (optimizedData != null) {
        return GoogleFitData(
          date: DateTime.now(),
          steps: optimizedData['steps'] as int?,
          caloriesBurned: (optimizedData['caloriesBurned'] as num?)?.toDouble(),
          distance: (optimizedData['distance'] as num?)?.toDouble(),
          weight: (optimizedData['weight'] as num?)?.toDouble(),
        );
      }

      // Fallback to original service
      final today = DateTime.now();
      final futures = await Future.wait([
        _googleFitService.getDailySteps(today),
        _googleFitService.getDailyCaloriesBurned(today),
        _googleFitService.getDailyDistance(today),
        _googleFitService.getCurrentWeight(),
      ], eagerError: false);

      return GoogleFitData(
        date: today,
        steps: futures[0] as int?,
        caloriesBurned: futures[1] as double?,
        distance: futures[2] as double?,
        weight: futures[3] as double?,
      );
    } catch (e) {
      print('❌ Error fetching fresh data from API: $e');
      return null;
    }
  }

  /// Get date key for caching
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (timer) {
      _performBackgroundSync();
    });
    _isBackgroundSyncActive = true;
    print('🔄 Background sync started (${_backgroundSyncInterval.inMinutes}m intervals)');
  }

  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    try {
      print('🔄 Performing background sync...');
      final data = await getTodayData(forceRefresh: true);
      if (data != null) {
        _liveDataController.add(data);
        print('✅ Background sync completed');
      }
    } catch (e) {
      print('⚠️ Background sync error: $e');
    }
  }

  /// Start memory refresh timer
  void _startMemoryRefreshTimer() {
    _memoryRefreshTimer?.cancel();
    _memoryRefreshTimer = Timer.periodic(_memoryRefreshInterval, (timer) {
      _refreshMemoryCache();
    });
    print('🧠 Memory refresh timer started (${_memoryRefreshInterval.inMinutes}m intervals)');
  }

  /// Refresh memory cache with latest data
  Future<void> _refreshMemoryCache() async {
    try {
      if (_memoryCache != null && !_isMemoryCacheValid()) {
        print('🧠 Refreshing memory cache...');
        final data = await getTodayData();
        if (data != null) {
          await _updateMemoryCache(data);
        }
      }
    } catch (e) {
      print('⚠️ Memory cache refresh error: $e');
    }
  }

  /// Force refresh all cache layers
  Future<GoogleFitData?> forceRefresh() async {
    print('🔄 Force refreshing all cache layers...');
    
    // Clear all cache layers first
    await _clearAllCacheLayers();
    
    return await getTodayData(forceRefresh: true);
  }

  /// Clear all cache layers to ensure clean data replacement
  Future<void> _clearAllCacheLayers() async {
    try {
      // Clear memory cache
      _memoryCache = null;
      _memoryCacheTimestamp = null;
      
      // Clear local storage cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCacheKey);
      await prefs.remove(_localCacheTimestampKey);
      await prefs.remove(_localCacheExpiryKey);
      
      // Clear Firebase cache for today
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final today = DateTime.now();
        final dateKey = _getDateKey(today);
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('googleFitCache')
            .doc(dateKey)
            .delete();
      }
      
      print('🧹 All cache layers cleared');
    } catch (e) {
      print('⚠️ Error clearing cache layers: $e');
    }
  }

  /// Get weekly data with caching
  Future<List<GoogleFitData>> getWeeklyData() async {
    try {
      final weeklyData = <GoogleFitData>[];
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateKey = _getDateKey(date);

        // Try Firebase cache first for historical data
        try {
          final userId = _auth.currentUser?.uid;
          if (userId != null) {
            final doc = await _firestore
                .collection('users')
                .doc(userId)
                .collection('googleFitCache')
                .doc(dateKey)
                .get();

            if (doc.exists) {
              final data = doc.data()!;
              weeklyData.add(GoogleFitData(
                date: date,
                steps: data['steps'] as int?,
                caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble(),
                distance: (data['distance'] as num?)?.toDouble(),
                weight: (data['weight'] as num?)?.toDouble(),
              ));
              continue;
            }
          }
        } catch (e) {
          print('⚠️ Error reading weekly cache for $dateKey: $e');
        }

        // If not cached, fetch from API (only for today)
        if (i == 0) {
          final todayData = await getTodayData();
          if (todayData != null) {
            weeklyData.add(todayData);
          }
        } else {
          // For historical data, add empty data
          weeklyData.add(GoogleFitData(
            date: date,
            steps: 0,
            caloriesBurned: 0.0,
            distance: 0.0,
            weight: null,
          ));
        }
      }

      return weeklyData;
    } catch (e) {
      print('❌ Error getting weekly data: $e');
      return [];
    }
  }

  /// Clean up old cache data
  Future<void> cleanupCache() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Clean up Firebase cache older than 7 days
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('googleFitCache')
          .where('timestamp', isLessThan: Timestamp.fromDate(oneWeekAgo))
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }

      print('🧹 Cache cleanup completed');
    } catch (e) {
      print('⚠️ Cache cleanup error: $e');
    }
  }

  /// Get cached data without triggering refresh
  GoogleFitData? getCachedData() {
    return _isMemoryCacheValid() ? _memoryCache : null;
  }

  /// Check if data is currently loading
  bool get isLoading => _isLoading;

  /// Dispose resources
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _memoryRefreshTimer?.cancel();
    _liveDataController.close();
    _connectionStateController.close();
    print('🗑️ OptimizedGoogleFitCacheService disposed');
  }
}
