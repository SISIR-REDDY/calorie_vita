import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for handling daily resets and data cleanup
class DailyResetService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static Timer? _resetTimer;
  static DateTime? _lastResetDate;

  /// Initialize daily reset service
  static void initialize() {
    _scheduleNextReset();
    _checkAndResetIfNeeded();
  }

  /// Schedule the next reset at midnight
  static void _scheduleNextReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    _resetTimer?.cancel();
    _resetTimer = Timer(timeUntilMidnight, () {
      _performDailyReset();
      _scheduleNextReset(); // Schedule the next reset
    });

    print('🕛 Daily reset scheduled for ${tomorrow.toString()}');
  }

  /// Check if reset is needed and perform it
  static Future<void> _checkAndResetIfNeeded() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Check if we've already reset today
    if (_lastResetDate != null && _lastResetDate!.isAtSameMomentAs(today)) {
      return;
    }

    // Check if it's a new day
    final lastReset = await _getLastResetDate();
    if (lastReset == null || !lastReset.isAtSameMomentAs(today)) {
      await _performDailyReset();
    }
  }

  /// Perform daily reset
  static Future<void> _performDailyReset() async {
    try {
      print('🔄 Performing daily reset...');
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Update last reset date
      await _setLastResetDate(today);
      _lastResetDate = today;

      // Clear old food history (keep only last 30 days)
      await _cleanupOldFoodHistory();

      // Reset daily counters and goals
      await _resetDailyCounters();

      print('✅ Daily reset completed successfully');
    } catch (e) {
      print('❌ Error during daily reset: $e');
    }
  }

  /// Clean up old food history entries (keep only last 30 days)
  static Future<void> _cleanupOldFoodHistory() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final query = _firestore
          .collection('food_history')
          .doc(userId)
          .collection('entries')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo));

      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        
        print('🧹 Cleaned up ${snapshot.docs.length} old food history entries');
      }
    } catch (e) {
      print('❌ Error cleaning up old food history: $e');
    }
  }

  /// Reset daily counters and goals
  static Future<void> _resetDailyCounters() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Reset daily summary
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(todayStr)
          .set({
        'date': todayStr,
        'caloriesConsumed': 0,
        'caloriesBurned': 0,
        'steps': 0,
        'waterIntake': 0,
        'protein': 0.0,
        'carbs': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sugar': 0.0,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      // Reset daily goals progress
      await _firestore
          .collection('daily_goals')
          .doc(userId)
          .collection('entries')
          .doc(todayStr)
          .set({
        'date': todayStr,
        'calorieGoal': 2000,
        'stepsGoal': 8000,
        'waterGoal': 8,
        'caloriesProgress': 0.0,
        'stepsProgress': 0.0,
        'waterProgress': 0.0,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      print('📊 Reset daily counters and goals for $todayStr');
    } catch (e) {
      print('❌ Error resetting daily counters: $e');
    }
  }

  /// Get last reset date
  static Future<DateTime?> _getLastResetDate() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore
          .collection('user_settings')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final lastReset = data?['lastDailyReset'] as Timestamp?;
        return lastReset?.toDate();
      }
      return null;
    } catch (e) {
      print('❌ Error getting last reset date: $e');
      return null;
    }
  }

  /// Set last reset date
  static Future<void> _setLastResetDate(DateTime date) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('user_settings')
          .doc(userId)
          .set({
        'lastDailyReset': Timestamp.fromDate(date),
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error setting last reset date: $e');
    }
  }

  /// Force reset (for testing or manual reset)
  static Future<void> forceReset() async {
    await _performDailyReset();
  }

  /// Dispose of the service
  static void dispose() {
    _resetTimer?.cancel();
    _resetTimer = null;
  }
}
