import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/google_fit_service.dart';
import '../models/google_fit_data.dart';

/// Enhanced Google Fit service with Firebase caching and real-time updates
class GoogleFitCacheService {
  static final GoogleFitCacheService _instance = GoogleFitCacheService._internal();
  factory GoogleFitCacheService() => _instance;
  GoogleFitCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleFitService _googleFitService = GoogleFitService();

  // Cache controllers
  final StreamController<GoogleFitData> _liveDataController = 
      StreamController<GoogleFitData>.broadcast();
  
  Timer? _refreshTimer;
  Timer? _backgroundSyncTimer;
  GoogleFitData? _cachedTodayData;
  DateTime? _lastCacheUpdate;
  
  // Cache configuration
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _liveUpdateInterval = Duration(seconds: 10);
  static const Duration _backgroundSyncInterval = Duration(minutes: 2);

  /// Get live data stream for real-time updates
  Stream<GoogleFitData> get liveDataStream => _liveDataController.stream;

  /// Initialize the cache service
  Future<void> initialize() async {
    await _googleFitService.initialize();
    _startBackgroundSync();
  }

  /// Get today's data with caching
  Future<GoogleFitData?> getTodayData({bool forceRefresh = false}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    // Check cache first
    if (!forceRefresh && _isCacheValid()) {
      return _cachedTodayData;
    }

    try {
      // Check Firebase cache
      GoogleFitData? firebaseData = await _getFromFirebaseCache(userId);
      
      if (!forceRefresh && firebaseData != null && 
          _isDataRecent(firebaseData.date)) {
        _cachedTodayData = firebaseData;
        _lastCacheUpdate = DateTime.now();
        return firebaseData;
      }

      // Fetch from Google Fit API
      GoogleFitData? freshData = await _fetchFreshData();
      
      if (freshData != null) {
        // Cache in memory and Firebase
        _cachedTodayData = freshData;
        _lastCacheUpdate = DateTime.now();
        
        // Save to Firebase (fire and forget)
        _saveToFirebaseCache(userId, freshData);
        
        // Emit to live stream
        _liveDataController.add(freshData);
      }
      
      return freshData;
    } catch (e) {
      print('Error getting today data: $e');
      // Return cached data if available
      return _cachedTodayData;
    }
  }

  /// Fetch fresh data from Google Fit API with optimized batch calls
  Future<GoogleFitData?> _fetchFreshData() async {
    if (!_googleFitService.isAuthenticated) {
      return null;
    }

    try {
      final today = DateTime.now();
      
      // Use the optimized batch API call from GoogleFitService
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
      print('Error fetching fresh Google Fit data: $e');
      return null;
    }
  }

  /// Get data from Firebase cache
  Future<GoogleFitData?> _getFromFirebaseCache(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
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
      print('Error getting Firebase cache: $e');
    }
    return null;
  }

  /// Save data to Firebase cache
  Future<void> _saveToFirebaseCache(String userId, GoogleFitData data) async {
    try {
      final dateKey = '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}-${data.date.day.toString().padLeft(2, '0')}';
      
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
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving to Firebase cache: $e');
    }
  }

  /// Start background sync for automatic updates
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (timer) {
      _performBackgroundSync();
    });
    
    // Initial sync
    _performBackgroundSync();
  }

  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    if (!_googleFitService.isAuthenticated) return;
    
    try {
      final data = await getTodayData(forceRefresh: true);
      if (data != null) {
        _liveDataController.add(data);
      }
    } catch (e) {
      print('Background sync error: $e');
    }
  }

  /// Start live updates for real-time data
  void startLiveUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_liveUpdateInterval, (timer) {
      _updateLiveData();
    });
  }

  /// Stop live updates
  void stopLiveUpdates() {
    _refreshTimer?.cancel();
  }

  /// Update live data
  Future<void> _updateLiveData() async {
    try {
      final data = await getTodayData();
      if (data != null) {
        _liveDataController.add(data);
      }
    } catch (e) {
      print('Live update error: $e');
    }
  }

  /// Check if cached data is valid
  bool _isCacheValid() {
    if (_cachedTodayData == null || _lastCacheUpdate == null) return false;
    
    final now = DateTime.now();
    final cacheAge = now.difference(_lastCacheUpdate!);
    
    return cacheAge < _cacheExpiry && _isToday(_cachedTodayData!.date);
  }

  /// Check if date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  /// Check if data is recent (within last hour)
  bool _isDataRecent(DateTime date) {
    final now = DateTime.now();
    return now.difference(date) < const Duration(hours: 1);
  }

  /// Force refresh data
  Future<GoogleFitData?> forceRefresh() async {
    return await getTodayData(forceRefresh: true);
  }

  /// Get weekly data with caching
  Future<List<GoogleFitData>> getWeeklyData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final weeklyData = <GoogleFitData>[];
      final now = DateTime.now();
      
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        // Try cache first
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
        } else {
          // Fetch from API if not cached
          final fitnessData = await _googleFitService.getFitnessData(date, date);
          if (fitnessData != null) {
            final googleFitData = GoogleFitData(
              date: date,
              steps: fitnessData['steps'] as int?,
              caloriesBurned: (fitnessData['caloriesBurned'] as num?)?.toDouble(),
              distance: (fitnessData['distance'] as num?)?.toDouble(),
              weight: null,
            );
            weeklyData.add(googleFitData);
            
            // Cache it
            _saveToFirebaseCache(userId, googleFitData);
          }
        }
      }
      
      return weeklyData;
    } catch (e) {
      print('Error getting weekly data: $e');
      return [];
    }
  }

  /// Clean up old cache data (call daily)
  Future<void> cleanupCache() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
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
    } catch (e) {
      print('Error cleaning cache: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _backgroundSyncTimer?.cancel();
    _liveDataController.close();
  }
}