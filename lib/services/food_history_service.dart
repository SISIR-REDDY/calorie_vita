import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_history_entry.dart';
import '../models/nutrition_info.dart';

/// Service for managing food history entries
class FoodHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _collectionName = 'food_history';
  static const int _maxHistoryEntries = 100; // Limit to prevent excessive data

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Add a new food entry to history
  static Future<bool> addFoodEntry(FoodHistoryEntry entry) async {
    try {
      if (_userId == null) {
        print('❌ User not authenticated');
        return false;
      }

      // Add to Firestore
      await _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .doc(entry.id)
          .set(entry.toMap());

      // Clean up old entries if we exceed the limit
      await _cleanupOldEntries();

      print('✅ Food entry added to history: ${entry.foodName}');
      return true;
    } catch (e) {
      print('❌ Error adding food entry to history: $e');
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
      print('❌ Error creating food entry from nutrition info: $e');
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
        print('❌ User not authenticated');
        return [];
      }

      Query query = _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // Add date filters if provided
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FoodHistoryEntry.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error getting food history: $e');
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
      print('❌ Error getting today\'s food entries: $e');
      return [];
    }
  }

  /// Get recent food entries (last 7 days)
  static Future<List<FoodHistoryEntry>> getRecentFoodEntries({int limit = 10}) async {
    try {
      return await getFoodHistory(limit: limit);
    } catch (e) {
      print('❌ Error getting recent food entries: $e');
      return [];
    }
  }

  /// Delete a food entry
  static Future<bool> deleteFoodEntry(String entryId) async {
    try {
      if (_userId == null) {
        print('❌ User not authenticated');
        return false;
      }

      await _firestore
          .collection(_collectionName)
          .doc(_userId)
          .collection('entries')
          .doc(entryId)
          .delete();

      print('✅ Food entry deleted: $entryId');
      return true;
    } catch (e) {
      print('❌ Error deleting food entry: $e');
      return false;
    }
  }

  /// Clear all food history
  static Future<bool> clearAllHistory() async {
    try {
      if (_userId == null) {
        print('❌ User not authenticated');
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
      print('✅ All food history cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing food history: $e');
      return false;
    }
  }

  /// Get total calories from today's entries
  static Future<double> getTodaysTotalCalories() async {
    try {
      final todaysEntries = await getTodaysFoodEntries();
      return todaysEntries.fold<double>(0.0, (total, entry) => total + entry.calories);
    } catch (e) {
      print('❌ Error calculating today\'s total calories: $e');
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
      print('❌ Error calculating recent total calories: $e');
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
      print('❌ Error getting history stats: $e');
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
        print('✅ Cleaned up ${entriesToDelete.length} old food history entries');
      }
    } catch (e) {
      print('❌ Error cleaning up old entries: $e');
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

  /// Stream of today's food entries
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
