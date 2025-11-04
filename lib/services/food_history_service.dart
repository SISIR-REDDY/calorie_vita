import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_history_entry.dart';
import '../models/nutrition_info.dart';
import '../models/food_entry.dart';
import 'daily_summary_service.dart';
import 'logger_service.dart';

/// Service for managing food history entries
class FoodHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final LoggerService _logger = LoggerService();
  
  static const String _collectionName = 'food_history';
  static const int _maxHistoryEntries = 100; // Limit to prevent excessive data

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Add a new food entry to history
  static Future<bool> addFoodEntry(FoodHistoryEntry entry) async {
    try {
      if (_userId == null) {
        _logger.warning('User not authenticated when adding food entry');
        return false;
      }

      // Validate entry data
      if (entry.id.isEmpty) {
        _logger.warning('Entry ID cannot be empty');
        return false;
      }
      if (entry.foodName.isEmpty) {
        _logger.warning('Food name cannot be empty');
        return false;
      }
      if (entry.calories < 0) {
        _logger.warning('Calories cannot be negative');
        return false;
      }

      // Add to Firestore
      await _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .doc(entry.id)
          .set(entry.toMap());

      // Sync with daily summary service for consumed calories
      await _syncWithDailySummary(entry);

      // Clean up old entries if we exceed the limit
      await _cleanupOldEntries();

      _logger.info('Food entry added to history', {'foodName': entry.foodName});
      return true;
    } catch (e) {
      _logger.error('Error adding food entry to history', {'error': e.toString()});
      return false;
    }
  }

  /// Add food entry from nutrition info
  static Future<bool> addFoodFromNutritionInfo(
    NutritionInfo nutritionInfo, {
    String source = 'camera_scan',
    String? imagePath,
    Map<String, dynamic>? scanData,
  }) async {
    try {
      final entry = FoodHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        foodName: nutritionInfo.foodName,
        calories: nutritionInfo.calories,
        protein: nutritionInfo.protein,
        carbs: nutritionInfo.carbs,
        fat: nutritionInfo.fat,
        fiber: nutritionInfo.fiber,
        sugar: nutritionInfo.sugar,
        weightGrams: nutritionInfo.weightGrams,
        category: nutritionInfo.category,
        brand: nutritionInfo.brand,
        notes: nutritionInfo.notes,
        source: source,
        timestamp: DateTime.now(),
        imagePath: imagePath,
        scanData: scanData,
      );

      return await addFoodEntry(entry);
    } catch (e) {
      _logger.error('Error creating food entry from nutrition info', {'error': e.toString()});
      return false;
    }
  }

  /// Get food history entries
  static Future<List<FoodHistoryEntry>> getFoodHistory({
    int limit = 20,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_userId == null) {
        _logger.warning('User not authenticated when getting food history');
        return [];
      }

      // Build query efficiently - add where clauses before orderBy
      Query query;
      
      if (startDate != null && endDate != null) {
        // Both filters - orderBy must match first where clause
        query = _firestore
            .collection(_collectionName)
            .doc(_userId)
            .collection('entries')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .orderBy('timestamp', descending: true)
            .limit(limit);
      } else if (startDate != null) {
        query = _firestore
            .collection(_collectionName)
            .doc(_userId)
            .collection('entries')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .orderBy('timestamp', descending: true)
            .limit(limit);
      } else if (endDate != null) {
        query = _firestore
            .collection(_collectionName)
            .doc(_userId)
            .collection('entries')
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .orderBy('timestamp', descending: true)
            .limit(limit);
      } else {
        query = _firestore
            .collection(_collectionName)
            .doc(_userId)
            .collection('entries')
            .orderBy('timestamp', descending: true)
            .limit(limit);
      }

      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
      );
      
      return snapshot.docs
          .map((doc) {
            try {
              return FoodHistoryEntry.fromMap(doc.data() as Map<String, dynamic>);
            } catch (e) {
              _logger.error('Error parsing food history entry', {'id': doc.id, 'error': e.toString()});
              return null;
            }
          })
          .whereType<FoodHistoryEntry>()
          .toList();
    } catch (e) {
      _logger.error('Error getting food history', {'error': e.toString()});
      return [];
    }
  }

  /// Get today's food entries
  static Future<List<FoodHistoryEntry>> getTodaysFoodEntries() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return await getFoodHistory(
        startDate: startOfDay,
        endDate: endOfDay,
        limit: 50,
      );
    } catch (e) {
      _logger.error('Error getting today\'s food entries', {'error': e.toString()});
      return [];
    }
  }

  /// Get today's food entries as a stream (optimized)
  static Stream<List<FoodHistoryEntry>> getTodaysFoodEntriesStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collectionName)
        .doc(_userId)
        .collection('entries')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) {
                  try {
                    return FoodHistoryEntry.fromMap(doc.data());
                  } catch (e) {
                    _logger.error('Error parsing entry', {'id': doc.id, 'error': e.toString()});
                    return null;
                  }
                })
                .whereType<FoodHistoryEntry>()
                .toList();
          } catch (e) {
            _logger.error('Error processing food entries stream', {'error': e.toString()});
            return <FoodHistoryEntry>[];
          }
        })
        .handleError((error) {
          _logger.error('Stream error getting today food entries', {'error': error.toString()});
          return <FoodHistoryEntry>[];
        });
  }

  /// Get recent food entries (last 7 days)
  static Future<List<FoodHistoryEntry>> getRecentFoodEntries({int limit = 10}) async {
    try {
      return await getFoodHistory(limit: limit);
    } catch (e) {
      _logger.error('Error getting recent food entries', {'error': e.toString()});
      return [];
    }
  }

  /// Delete a food entry
  static Future<bool> deleteFoodEntry(String entryId) async {
    try {
      if (_userId == null) {
        _logger.warning('User not authenticated when deleting food entry');
        return false;
      }

      await _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .doc(entryId)
          .delete();

      _logger.info('Food entry deleted', {'entryId': entryId});
      return true;
    } catch (e) {
      _logger.error('Error deleting food entry', {'error': e.toString()});
      return false;
    }
  }

  /// Clear all food history
  static Future<bool> clearAllHistory() async {
    try {
      if (_userId == null) {
        _logger.warning('User not authenticated when clearing history');
        return false;
      }

      final batch = _firestore.batch();
      final entries = await _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .get();

      for (final doc in entries.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.info('All food history cleared');
      return true;
    } catch (e) {
      _logger.error('Error clearing food history', {'error': e.toString()});
      return false;
    }
  }

  /// Get total calories from today's entries
  static Future<double> getTodaysTotalCalories() async {
    try {
      final todaysEntries = await getTodaysFoodEntries();
      return todaysEntries.fold<double>(0.0, (total, entry) => total + entry.calories);
    } catch (e) {
      _logger.error('Error calculating today\'s total calories', {'error': e.toString()});
      return 0.0;
    }
  }

  /// Get total calories from recent entries
  static Future<double> getRecentTotalCalories({int days = 7}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      
      final entries = await getFoodHistory(
        startDate: startDate,
        endDate: now,
        limit: 100,
      );
      
      return entries.fold<double>(0.0, (total, entry) => total + entry.calories);
    } catch (e) {
      _logger.error('Error calculating recent total calories', {'error': e.toString()});
      return 0.0;
    }
  }

  /// Get food history statistics
  static Future<Map<String, dynamic>> getHistoryStats() async {
    try {
      final todaysEntries = await getTodaysFoodEntries();
      final recentEntries = await getRecentFoodEntries(limit: 50);
      
      final todaysCalories = todaysEntries.fold<double>(0.0, (total, entry) => total + entry.calories);
      final recentCalories = recentEntries.fold<double>(0.0, (total, entry) => total + entry.calories);
      
      final uniqueFoods = recentEntries.map((e) => e.foodName).toSet().length;
      final mostCommonFood = _getMostCommonFood(recentEntries);
      
      return {
        'todaysEntries': todaysEntries.length,
        'todaysCalories': todaysCalories,
        'recentEntries': recentEntries.length,
        'recentCalories': recentCalories,
        'uniqueFoods': uniqueFoods,
        'mostCommonFood': mostCommonFood,
        'lastEntry': recentEntries.isNotEmpty ? recentEntries.first.timestamp : null,
      };
    } catch (e) {
      _logger.error('Error getting history stats', {'error': e.toString()});
      return {};
    }
  }

  /// Get most common food from entries
  static String _getMostCommonFood(List<FoodHistoryEntry> entries) {
    if (entries.isEmpty) return 'None';
    
    final foodCounts = <String, int>{};
    for (final entry in entries) {
      foodCounts[entry.foodName] = (foodCounts[entry.foodName] ?? 0) + 1;
    }
    
    if (foodCounts.isEmpty) return 'None';
    
    return foodCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Sync food entry with daily summary service for consumed calories
  static Future<void> _syncWithDailySummary(FoodHistoryEntry entry) async {
    try {
      if (_userId == null) return;

      // Convert FoodHistoryEntry to FoodEntry for daily summary
      final foodEntry = FoodEntry(
        id: entry.id,
        name: entry.foodName,
        calories: entry.calories.round(),
        timestamp: entry.timestamp,
        imageUrl: entry.imagePath,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
        fiber: entry.fiber,
        sugar: entry.sugar,
      );

      // Update daily summary with consumed calories
      final dailySummaryService = DailySummaryService();
      await dailySummaryService.onMealLogged(_userId!, foodEntry);

      _logger.info('Synced food entry with daily summary', {'foodName': entry.foodName});
    } catch (e) {
      _logger.error('Error syncing with daily summary', {'error': e.toString()});
    }
  }

  /// Get total consumed calories for today
  static Future<int> getTodaysConsumedCalories() async {
    try {
      final entries = await getTodaysFoodEntries();
      return entries.fold<int>(0, (total, entry) => total + entry.calories.round());
    } catch (e) {
      _logger.error('Error calculating today\'s consumed calories', {'error': e.toString()});
      return 0;
    }
  }

  /// Get total consumed calories for today as a stream
  static Stream<int> getTodaysConsumedCaloriesStream() {
    return getTodaysFoodEntriesStream().map((entries) {
      return entries.fold<int>(0, (total, entry) => total + entry.calories.round());
    });
  }

  /// Clean up old entries to maintain limit
  static Future<void> _cleanupOldEntries() async {
    try {
      if (_userId == null) return;

      final entries = await _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .orderBy('timestamp', descending: true)
          .get();

      if (entries.docs.length > _maxHistoryEntries) {
        final batch = _firestore.batch();
        final entriesToDelete = entries.docs.skip(_maxHistoryEntries);
        
        for (final doc in entriesToDelete) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        _logger.info('Cleaned up old food history entries', {'deleted': entriesToDelete.length});
      }
    } catch (e) {
      _logger.error('Error cleaning up old entries', {'error': e.toString()});
    }
  }

  /// Stream of food history entries
  static Stream<List<FoodHistoryEntry>> getFoodHistoryStream({int limit = 20}) {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collectionName)
        .doc(_userId)
        .collection('entries')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodHistoryEntry.fromMap(doc.data()))
            .toList());
  }


  /// Stream of recent food entries (today only for home screen)
  static Stream<List<FoodHistoryEntry>> getRecentFoodEntriesStream({int limit = 10}) {
    if (_userId == null) {
      return Stream.value([]);
    }

    // Only show today's entries for the home screen
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection(_collectionName)
        .doc(_userId)
        .collection('entries')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodHistoryEntry.fromMap(doc.data()))
            .toList());
  }
}
