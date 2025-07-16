import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_entry.dart';

class FoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get food entries for a specific user
  Stream<List<FoodEntry>> getUserFoodEntries(String userId) {
    return _firestore
        .collection('food_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();
    });
  }

  // Get today's food entries for a user
  Stream<List<FoodEntry>> getTodayFoodEntries(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('food_entries')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();
    });
  }

  // Get weekly food entries for a user
  Stream<List<FoodEntry>> getWeeklyFoodEntries(String userId) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return _firestore
        .collection('food_entries')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();
    });
  }

  // Calculate total calories for today
  Stream<int> getTodayCalories(String userId) {
    return getTodayFoodEntries(userId).map((entries) {
      return entries.fold(0, (sum, entry) => sum + entry.calories);
    });
  }

  // Calculate total calories for the week
  Stream<int> getWeeklyCalories(String userId) {
    return getWeeklyFoodEntries(userId).map((entries) {
      return entries.fold(0, (sum, entry) => sum + entry.calories);
    });
  }
} 