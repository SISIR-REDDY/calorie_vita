import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/food_entry.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';

/// Optimized Firebase service with caching, offline support, and performance improvements
class OptimizedFirebaseService {
  static final OptimizedFirebaseService _instance =
      OptimizedFirebaseService._internal();
  factory OptimizedFirebaseService() => _instance;
  OptimizedFirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  // Cache management
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _maxCacheSize = 100;

  // Offline support
  bool _isOffline = false;
  final List<Map<String, dynamic>> _pendingWrites = [];

  // Performance monitoring
  final Map<String, int> _operationCounts = {};
  final Map<String, Duration> _operationTimes = {};

  /// Initialize the service with proper configuration
  Future<void> initialize() async {
    try {
      // Configure Firestore for offline support
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Monitor connectivity
      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        _isOffline = results.contains(ConnectivityResult.none);
        if (!_isOffline && _pendingWrites.isNotEmpty) {
          _processPendingWrites();
        }
      });

      // Check initial connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      _isOffline = connectivityResults.contains(ConnectivityResult.none);

      print('OptimizedFirebaseService initialized. Offline: $_isOffline');
    } catch (e) {
      print('Error initializing OptimizedFirebaseService: $e');
    }
  }

  /// Check if Firebase is available and properly configured
  bool get isAvailable {
    try {
      _auth.currentUser;
      return true;
    } catch (e) {
      print('Firebase not available: $e');
      return false;
    }
  }

  /// Get current user ID with null safety
  String? getCurrentUserId() {
    try {
      return _auth.currentUser?.uid;
    } catch (e) {
      print('Error getting current user ID: $e');
      return null;
    }
  }

  /// Optimized method to get user food entries with caching and pagination
  Stream<List<FoodEntry>> getUserFoodEntries(String userId,
      {int limit = 20, DocumentSnapshot? lastDocument}) {
    if (!isAvailable) {
      return Stream.value([]);
    }

    final cacheKey = 'user_food_entries_$userId';

    // Return cached data if available and not expired
    if (_isCacheValid(cacheKey)) {
      final cachedData = _cache[cacheKey] as List<dynamic>?;
      if (cachedData != null) {
        final entries =
            cachedData.map((data) => FoodEntry.fromJson(data)).toList();
        return Stream.value(entries);
      }
    }

    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      return query.snapshots().map((snapshot) {
        final entries =
            snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();

        // Cache the results
        _cacheData(cacheKey, entries.map((e) => e.toMap()).toList());

        return entries;
      }).handleError((error) {
        print('Error getting user food entries: $error');
        return <FoodEntry>[];
      });
    } catch (e) {
      print('Error in getUserFoodEntries: $e');
      return Stream.value([]);
    }
  }

  /// Get today's food entries with caching
  Stream<List<FoodEntry>> getTodayFoodEntries(String userId) {
    if (!isAvailable) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final cacheKey = 'today_food_entries_$userId';

    // Return cached data if available and not expired
    if (_isCacheValid(cacheKey)) {
      final cachedData = _cache[cacheKey] as List<dynamic>?;
      if (cachedData != null) {
        final entries =
            cachedData.map((data) => FoodEntry.fromJson(data)).toList();
        return Stream.value(entries);
      }
    }

    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        final entries =
            snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();

        // Cache the results
        _cacheData(cacheKey, entries.map((e) => e.toMap()).toList());

        return entries;
      }).handleError((error) {
        print('Error getting today food entries: $error');
        return <FoodEntry>[];
      });
    } catch (e) {
      print('Error in getTodayFoodEntries: $e');
      return Stream.value([]);
    }
  }

  /// Calculate total calories for today with caching
  Stream<int> getTodayCalories(String userId) {
    return getTodayFoodEntries(userId).map((entries) {
      return entries.fold(0, (sum, entry) => sum + entry.calories);
    });
  }

  /// Save food entry with offline support
  Future<void> saveFoodEntry(String userId, FoodEntry entry) async {
    if (!isAvailable) {
      print('Firebase not available, cannot save food entry');
      return;
    }

    try {
      if (_isOffline) {
        // Store for later when online
        _pendingWrites.add({
          'type': 'save_food_entry',
          'userId': userId,
          'data': entry.toMap(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('Food entry queued for offline save');
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .add(entry.toMap());

      // Invalidate related caches
      _invalidateCache('user_food_entries_$userId');
      _invalidateCache('today_food_entries_$userId');

      print('Food entry saved successfully');
    } catch (e) {
      print('Error saving food entry: $e');
      // Store for retry
      _pendingWrites.add({
        'type': 'save_food_entry',
        'userId': userId,
        'data': entry.toMap(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      rethrow;
    }
  }

  /// Delete food entry with offline support
  Future<void> deleteFoodEntry(String userId, String entryId) async {
    if (!isAvailable) {
      print('Firebase not available, cannot delete food entry');
      return;
    }

    try {
      if (_isOffline) {
        // Store for later when online
        _pendingWrites.add({
          'type': 'delete_food_entry',
          'userId': userId,
          'entryId': entryId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('Food entry deletion queued for offline');
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .doc(entryId)
          .delete();

      // Invalidate related caches
      _invalidateCache('user_food_entries_$userId');
      _invalidateCache('today_food_entries_$userId');

      print('Food entry deleted successfully');
    } catch (e) {
      print('Error deleting food entry: $e');
      rethrow;
    }
  }

  /// Get user profile with caching
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    if (!isAvailable) {
      return {};
    }

    final cacheKey = 'user_profile_$userId';

    // Return cached data if available and not expired
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey] as Map<String, dynamic>? ?? {};
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('userData')
          .get();

      final data = doc.exists
          ? Map<String, dynamic>.from(doc.data() ?? {})
          : <String, dynamic>{};

      // Cache the result
      _cacheData(cacheKey, data);

      return data;
    } catch (e) {
      print('Error fetching user profile: $e');
      return {};
    }
  }

  /// Save user profile with caching
  Future<void> saveUserProfile(
      String userId, Map<String, dynamic> profileData) async {
    if (!isAvailable) {
      print('Firebase not available, cannot save user profile');
      return;
    }

    try {
      if (_isOffline) {
        // Store for later when online
        _pendingWrites.add({
          'type': 'save_user_profile',
          'userId': userId,
          'data': profileData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('User profile queued for offline save');
        return;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('userData')
          .set(profileData, SetOptions(merge: true));

      // Update cache
      _cacheData('user_profile_$userId', profileData);

      print('User profile saved successfully');
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }

  /// Get trainer chat history with pagination and caching
  Stream<List<Map<String, dynamic>>> getTrainerChatHistory(String userId,
      {int limit = 50}) {
    if (!isAvailable) {
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('trainerChats')
          .orderBy('timestamp', descending: false)
          .limitToLast(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'sender': data['sender'] ?? '',
            'text': data['text'] ?? '',
            'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
            'sessionId': data['sessionId'] ?? 'default',
          };
        }).toList();
      }).handleError((error) {
        print('Error getting trainer chat history: $error');
        return <Map<String, dynamic>>[];
      });
    } catch (e) {
      print('Error in getTrainerChatHistory: $e');
      return Stream.value([]);
    }
  }

  /// Save trainer chat message with session tracking
  Future<void> saveTrainerChatMessage(
      String userId, Map<String, dynamic> messageData) async {
    if (!isAvailable) {
      print('Firebase not available, cannot save chat message');
      return;
    }

    try {
      if (_isOffline) {
        // Store for later when online
        _pendingWrites.add({
          'type': 'save_chat_message',
          'userId': userId,
          'data': messageData,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print('Chat message queued for offline save');
        return;
      }

      final sessionId = messageData['sessionId'] ?? 'default';

      // Save the message
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('trainerChats')
          .add({
        'sender': messageData['sender'],
        'text': messageData['text'],
        'timestamp':
            Timestamp.fromDate(messageData['timestamp'] ?? DateTime.now()),
        'sessionId': sessionId,
      });

      // Update session metadata if it's a user message
      if (messageData['sender'] == 'user') {
        final messageText = messageData['text'] ?? '';
        final title = _generateSessionTitle(messageText);
        await saveChatSession(userId, sessionId, title, messageText);
      }

      print('Chat message saved successfully');
    } catch (e) {
      print('Error saving chat message: $e');
      rethrow;
    }
  }

  /// Save chat session metadata
  Future<void> saveChatSession(
      String userId, String sessionId, String title, String lastMessage) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('chatSessions')
          .doc(sessionId)
          .set({
        'title': title,
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromDate(DateTime.now()),
        'messageCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving chat session: $e');
    }
  }

  /// Get daily summaries for analytics with caching
  Future<List<DailySummary>> getDailySummaries(String userId,
      {int days = 7}) async {
    if (!isAvailable) {
      return [];
    }

    final cacheKey = 'daily_summaries_${userId}_$days';

    // Return cached data if available and not expired
    if (_isCacheValid(cacheKey)) {
      final cachedData = _cache[cacheKey] as List<dynamic>?;
      if (cachedData != null) {
        return cachedData.map((data) => DailySummary.fromMap(data)).toList();
      }
    }

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));

      final entries = await _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: false)
          .get();

      // Group entries by date and calculate daily summaries
      final Map<String, List<FoodEntry>> entriesByDate = {};
      for (final doc in entries.docs) {
        final entry = FoodEntry.fromFirestore(doc);
        final dateKey =
            '${entry.timestamp.year}-${entry.timestamp.month}-${entry.timestamp.day}';
        entriesByDate.putIfAbsent(dateKey, () => []).add(entry);
      }

      final List<DailySummary> summaries = [];
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = '${date.year}-${date.month}-${date.day}';
        final dayEntries = entriesByDate[dateKey] ?? [];

        final caloriesConsumed =
            dayEntries.fold(0, (sum, entry) => sum + entry.calories);

        summaries.add(DailySummary(
          caloriesConsumed: caloriesConsumed,
          caloriesBurned: 300, // Default - should be tracked separately
          caloriesGoal: 2000, // Should come from user profile
          steps: 5000, // Default - should be tracked separately
          stepsGoal: 10000,
          waterGlasses: 0, // Default value
          waterGlassesGoal: 8, // Default value
          date: date,
        ));
      }

      // Cache the results
      _cacheData(cacheKey, summaries.map((s) => s.toMap()).toList());

      return summaries;
    } catch (e) {
      print('Error fetching daily summaries: $e');
      return [];
    }
  }

  /// Process pending writes when back online
  Future<void> _processPendingWrites() async {
    if (_pendingWrites.isEmpty) return;

    print('Processing ${_pendingWrites.length} pending writes...');

    final writesToProcess = List<Map<String, dynamic>>.from(_pendingWrites);
    _pendingWrites.clear();

    for (final write in writesToProcess) {
      try {
        switch (write['type']) {
          case 'save_food_entry':
            await saveFoodEntry(
                write['userId'], FoodEntry.fromJson(write['data']));
            break;
          case 'delete_food_entry':
            await deleteFoodEntry(write['userId'], write['entryId']);
            break;
          case 'save_user_profile':
            await saveUserProfile(write['userId'], write['data']);
            break;
          case 'save_chat_message':
            await saveTrainerChatMessage(write['userId'], write['data']);
            break;
        }
      } catch (e) {
        print('Error processing pending write: $e');
        // Re-add to pending writes for retry
        _pendingWrites.add(write);
      }
    }
  }

  /// Cache management methods
  void _cacheData(String key, dynamic data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();

    // Clean up old cache entries if we exceed max size
    if (_cache.length > _maxCacheSize) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _cache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  bool _isCacheValid(String key) {
    if (!_cacheTimestamps.containsKey(key)) return false;
    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  void _invalidateCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Generate a session title from the first user message
  String _generateSessionTitle(String message) {
    if (message.length > 30) {
      return '${message.substring(0, 30)}...';
    }
    return message;
  }

  /// Clear all caches
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('Cache cleared');
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'cacheSize': _cache.length,
      'pendingWrites': _pendingWrites.length,
      'isOffline': _isOffline,
      'operationCounts': Map<String, int>.from(_operationCounts),
    };
  }

  /// Dispose resources
  void dispose() {
    _cache.clear();
    _cacheTimestamps.clear();
    _pendingWrites.clear();
    _operationCounts.clear();
    _operationTimes.clear();
  }
}
