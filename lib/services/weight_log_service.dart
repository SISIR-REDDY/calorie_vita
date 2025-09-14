import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/weight_log.dart';

/// Service for managing weight log entries
class WeightLogService {
  static final WeightLogService _instance = WeightLogService._internal();
  factory WeightLogService() => _instance;
  WeightLogService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Add a new weight log entry
  Future<String> addWeightLog({
    required double weight,
    required DateTime date,
    String? notes,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final weightLog = WeightLog(
      id: '', // Will be set by Firestore
      userId: _userId!,
      weight: weight,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    final docRef =
        await _firestore.collection('weightLogs').add(weightLog.toFirestore());

    return docRef.id;
  }

  /// Update an existing weight log entry
  Future<void> updateWeightLog({
    required String id,
    required double weight,
    required DateTime date,
    String? notes,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    await _firestore.collection('weightLogs').doc(id).update({
      'weight': weight,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Delete a weight log entry
  Future<void> deleteWeightLog(String id) async {
    if (_userId == null) throw Exception('User not authenticated');

    await _firestore.collection('weightLogs').doc(id).delete();
  }

  /// Get all weight log entries for the current user
  Future<List<WeightLog>> getWeightLogs() async {
    if (_userId == null) throw Exception('User not authenticated');

    final querySnapshot = await _firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: _userId)
        .orderBy('date', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => WeightLog.fromFirestore(doc))
        .toList();
  }

  /// Get weight log entries stream for real-time updates
  Stream<List<WeightLog>> getWeightLogsStream() {
    if (_userId == null) {
      debugPrint('WeightLogService: No user ID available');
      return Stream.value([]);
    }

    debugPrint('WeightLogService: Getting weight logs for user: $_userId');

    return _firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: _userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint(
          'WeightLogService: Received ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) => WeightLog.fromFirestore(doc)).toList();
    }).handleError((error) {
      // Log error for debugging
      debugPrint('WeightLogService Error: $error');
      throw error;
    });
  }

  /// Get weight log entries for a specific date range
  Future<List<WeightLog>> getWeightLogsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_userId == null) throw Exception('User not authenticated');

    final querySnapshot = await _firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: _userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => WeightLog.fromFirestore(doc))
        .toList();
  }

  /// Get the latest weight log entry
  Future<WeightLog?> getLatestWeightLog() async {
    if (_userId == null) throw Exception('User not authenticated');

    final querySnapshot = await _firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: _userId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return WeightLog.fromFirestore(querySnapshot.docs.first);
  }

  /// Get weight log statistics
  Future<WeightLogStats> getWeightLogStats() async {
    if (_userId == null) throw Exception('User not authenticated');

    final weightLogs = await getWeightLogs();

    if (weightLogs.isEmpty) {
      return const WeightLogStats(
        currentWeight: 0.0,
        totalEntries: 0,
      );
    }

    final currentWeight = weightLogs.first.weight;
    final previousWeight = weightLogs.length > 1 ? weightLogs[1].weight : null;
    final weightChange =
        previousWeight != null ? currentWeight - previousWeight : null;

    final totalWeight =
        weightLogs.fold(0.0, (total, log) => total + log.weight);
    final averageWeight = totalWeight / weightLogs.length;

    final firstEntryDate = weightLogs.last.date;
    final lastEntryDate = weightLogs.first.date;

    return WeightLogStats(
      currentWeight: currentWeight,
      previousWeight: previousWeight,
      weightChange: weightChange,
      averageWeight: averageWeight,
      totalEntries: weightLogs.length,
      firstEntryDate: firstEntryDate,
      lastEntryDate: lastEntryDate,
    );
  }

  /// Get weight log statistics stream for real-time updates
  Stream<WeightLogStats> getWeightLogStatsStream() {
    return getWeightLogsStream().map((weightLogs) {
      if (weightLogs.isEmpty) {
        return const WeightLogStats(
          currentWeight: 0.0,
          totalEntries: 0,
        );
      }

      final currentWeight = weightLogs.first.weight;
      final previousWeight =
          weightLogs.length > 1 ? weightLogs[1].weight : null;
      final weightChange =
          previousWeight != null ? currentWeight - previousWeight : null;

      final totalWeight =
          weightLogs.fold(0.0, (total, log) => total + log.weight);
      final averageWeight = totalWeight / weightLogs.length;

      final firstEntryDate = weightLogs.last.date;
      final lastEntryDate = weightLogs.first.date;

      return WeightLogStats(
        currentWeight: currentWeight,
        previousWeight: previousWeight,
        weightChange: weightChange,
        averageWeight: averageWeight,
        totalEntries: weightLogs.length,
        firstEntryDate: firstEntryDate,
        lastEntryDate: lastEntryDate,
      );
    }).handleError((error) {
      // Log error for debugging
      debugPrint('WeightLogStats Error: $error');
      throw error;
    });
  }

  /// Check if weight log exists for a specific date
  Future<bool> hasWeightLogForDate(DateTime date) async {
    if (_userId == null) return false;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final querySnapshot = await _firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: _userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  /// Get weight log entry for a specific date
  Future<WeightLog?> getWeightLogForDate(DateTime date) async {
    if (_userId == null) return null;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final querySnapshot = await _firestore
        .collection('weightLogs')
        .where('userId', isEqualTo: _userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return WeightLog.fromFirestore(querySnapshot.docs.first);
  }
}
