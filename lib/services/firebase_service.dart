import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/food_entry.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import '../models/user_goals.dart';
import '../models/user_preferences.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();

  /// Check if Firebase is available and properly configured
  bool get isAvailable {
    try {
      // Try to access Firebase services
      _auth.currentUser;
      return true;
    } catch (e) {
      print('Firebase not available: $e');
      return false;
    }
  }

  /// Check if device has network connectivity
  Future<bool> _hasNetworkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  /// Handle Firebase errors with user-friendly messages
  void _handleFirebaseError(String operation, dynamic error) {
    if (error.toString().contains('unavailable') || 
        error.toString().contains('UNAVAILABLE')) {
      print('$operation failed: Firebase service temporarily unavailable');
    } else if (error.toString().contains('permission-denied')) {
      print('$operation failed: Permission denied');
    } else if (error.toString().contains('not-found')) {
      print('$operation failed: Resource not found');
    } else {
      print('$operation failed: $error');
    }
  }

  // Get food entries for a specific user
  Stream<List<FoodEntry>> getUserFoodEntries(String userId) {
    if (!isAvailable) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('entries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();
    }).handleError((error) {
      print('Error getting user food entries: $error');
      return <FoodEntry>[];
    });
  }

  // Get today's food entries for a user
  Stream<List<FoodEntry>> getTodayFoodEntries(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

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
      return snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();
    });
  }

  // Get weekly food entries for a user
  Stream<List<FoodEntry>> getWeeklyFoodEntries(String userId) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('entries')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay))
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

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Get user profile data
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('userData')
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('Error fetching user profile: $e');
      return {};
    }
  }

  // Save user profile data
  Future<void> saveUserProfile(
      String userId, Map<String, dynamic> profileData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('userData')
          .set(profileData, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }

  // Save user profile data (alias for onboarding)
  Future<void> saveUserProfileData(
      String userId, Map<String, dynamic> profileData) async {
    return saveUserProfile(userId, profileData);
  }

  // Check if user has completed onboarding
  Future<bool> isOnboardingCompleted(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      return profile['onboardingCompleted'] == true;
    } catch (e) {
      print('Error checking onboarding status: $e');
      return false;
    }
  }

  // Get trainer chat history (last 5 conversations)
  Stream<List<Map<String, dynamic>>> getTrainerChatHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('trainerChats')
        .orderBy('timestamp', descending: false)
        .limitToLast(50) // Keep last 50 messages (roughly 5 conversations)
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
    });
  }

  // Get recent chat sessions (last 5 sessions)
  Future<List<Map<String, dynamic>>> getRecentChatSessions(
      String userId) async {
    try {
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chatSessions')
          .orderBy('lastMessageTime', descending: true)
          .limit(5)
          .get();

      return sessionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'sessionId': doc.id,
          'title': data['title'] ?? 'Chat Session',
          'lastMessage': data['lastMessage'] ?? '',
          'lastMessageTime':
              data['lastMessageTime']?.toDate() ?? DateTime.now(),
          'messageCount': data['messageCount'] ?? 0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching chat sessions: $e');
      return [];
    }
  }

  // Save chat session metadata
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

  // Save trainer chat message with session tracking
  Future<void> saveTrainerChatMessage(
      String userId, Map<String, dynamic> messageData) async {
    try {
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
    } catch (e) {
      print('Error saving chat message: $e');
      rethrow;
    }
  }

  // Generate a session title from the first user message
  String _generateSessionTitle(String message) {
    if (message.length > 30) {
      return '${message.substring(0, 30)}...';
    }
    return message;
  }

  // Clear trainer chat history
  Future<void> clearTrainerChatHistory(String userId) async {
    try {
      final batch = _firestore.batch();
      final chatDocs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('trainerChats')
          .get();

      for (final doc in chatDocs.docs) {
        batch.delete(doc.reference);
      }

      // Also clear chat sessions
      final sessionDocs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chatSessions')
          .get();

      for (final doc in sessionDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing chat history: $e');
      rethrow;
    }
  }

  // Clean up old chat history (keep only last 5 sessions worth of messages)
  Future<void> cleanupOldChatHistory(String userId) async {
    try {
      // Get all messages ordered by timestamp
      final allMessages = await _firestore
          .collection('users')
          .doc(userId)
          .collection('trainerChats')
          .orderBy('timestamp', descending: false)
          .get();

      // Keep only the last 50 messages (roughly 5 conversations)
      if (allMessages.docs.length > 50) {
        final messagesToDelete =
            allMessages.docs.take(allMessages.docs.length - 50);
        final batch = _firestore.batch();

        for (final doc in messagesToDelete) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        print('Cleaned up ${messagesToDelete.length} old chat messages');
      }

      // Clean up old chat sessions (keep only last 5)
      final allSessions = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chatSessions')
          .orderBy('lastMessageTime', descending: true)
          .get();

      if (allSessions.docs.length > 5) {
        final sessionsToDelete = allSessions.docs.skip(5);
        final batch = _firestore.batch();

        for (final doc in sessionsToDelete) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        print('Cleaned up ${sessionsToDelete.length} old chat sessions');
      }
    } catch (e) {
      print('Error cleaning up chat history: $e');
    }
  }

  // ========== ANALYTICS METHODS ==========

  // Get daily summaries for analytics
  Future<List<DailySummary>> getDailySummaries(String userId,
      {int days = 7}) async {
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

      return summaries;
    } catch (e) {
      print('Error fetching daily summaries: $e');
      return [];
    }
  }

  // Get macro breakdown for a specific period
  Future<MacroBreakdown> getMacroBreakdown(String userId,
      {int days = 7}) async {
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
          .get();

      return entries.docs.fold<MacroBreakdown>(
        MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
        (MacroBreakdown sum, QueryDocumentSnapshot doc) =>
            sum + FoodEntry.fromFirestore(doc).macroBreakdown,
      );
    } catch (e) {
      print('Error fetching macro breakdown: $e');
      return MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
    }
  }

  // Get user achievements
  Future<List<UserAchievement>> getUserAchievements(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('achievements')
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final achievements = <UserAchievement>[];

        for (final achievementData in data['achievements'] ?? []) {
          achievements.add(UserAchievement.fromJson(achievementData));
        }

        return achievements;
      }

      // Return default achievements if none exist
      return Achievements.defaultAchievements;
    } catch (e) {
      print('Error fetching user achievements: $e');
      return Achievements.defaultAchievements;
    }
  }

  // Save user achievement
  Future<void> saveUserAchievement(
      String userId, UserAchievement achievement) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('achievements');

      final doc = await docRef.get();
      final achievements = <Map<String, dynamic>>[];

      if (doc.exists) {
        final data = doc.data() ?? {};
        achievements
            .addAll((data['achievements'] ?? []).cast<Map<String, dynamic>>());
      }

      // Update or add the achievement
      final existingIndex =
          achievements.indexWhere((a) => a['id'] == achievement.id);
      if (existingIndex >= 0) {
        achievements[existingIndex] = achievement.toJson();
      } else {
        achievements.add(achievement.toJson());
      }

      await docRef.set({'achievements': achievements});
    } catch (e) {
      print('Error saving user achievement: $e');
      rethrow;
    }
  }

  // Get weight history
  Future<List<Map<String, dynamic>>> getWeightHistory(String userId,
      {int days = 30}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));

      final entries = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weightLogs')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      return entries.docs.map((doc) {
        final data = doc.data();
        return {
          'date': data['date']?.toDate() ?? DateTime.now(),
          'weight': data['weight'] ?? 0.0,
          'bmi': data['bmi'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching weight history: $e');
      return [];
    }
  }

  // Save weight log entry
  Future<void> saveWeightLog(String userId, double weight, double bmi) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('weightLogs')
          .add({
        'weight': weight,
        'bmi': bmi,
        'date': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error saving weight log: $e');
      rethrow;
    }
  }

  // Get analytics insights (placeholder for AI integration)
  Future<List<Map<String, dynamic>>> getAnalyticsInsights(String userId) async {
    try {
      // This would integrate with AI service in the future
      // For now, return mock insights based on data patterns
      final dailySummaries = await getDailySummaries(userId, days: 14);
      final currentMacros = await getMacroBreakdown(userId, days: 7);

      final insights = <Map<String, dynamic>>[];

      // Analyze calorie trends
      if (dailySummaries.length >= 7) {
        final thisWeek = dailySummaries
            .take(7)
            .fold(0, (sum, day) => sum + day.caloriesConsumed);
        final lastWeek = dailySummaries
            .skip(7)
            .fold(0, (sum, day) => sum + day.caloriesConsumed);

        if (thisWeek > lastWeek * 1.1) {
          insights.add({
            'type': 'calorie_increase',
            'title': '📈 Calorie Increase',
            'message':
                'You consumed ${((thisWeek - lastWeek) / lastWeek * 100).toStringAsFixed(0)}% more calories this week compared to last week.',
            'color': 'warning',
          });
        } else if (thisWeek < lastWeek * 0.9) {
          insights.add({
            'type': 'calorie_decrease',
            'title': '📉 Calorie Decrease',
            'message':
                'You consumed ${((lastWeek - thisWeek) / lastWeek * 100).toStringAsFixed(0)}% fewer calories this week compared to last week.',
            'color': 'info',
          });
        }
      }

      // Analyze macro balance
      if (!currentMacros.isWithinRecommended) {
        insights.add({
          'type': 'macro_imbalance',
          'title': '⚖️ Macro Imbalance',
          'message':
              'Your macro distribution needs adjustment. Consider consulting with a nutritionist.',
          'color': 'warning',
        });
      }

      return insights;
    } catch (e) {
      print('Error generating analytics insights: $e');
      return [];
    }
  }

  // Get personalized recommendations
  Future<List<Map<String, dynamic>>> getPersonalizedRecommendations(
      String userId) async {
    try {
      final todayCalories = await getTodayCalories(userId).first;
      final recommendations = <Map<String, dynamic>>[];

      // Calorie-based recommendations
      if (todayCalories < 1500) {
        recommendations.add({
          'title': 'Increase calorie intake',
          'description':
              'You\'re below your minimum daily calorie needs. Consider adding healthy snacks.',
          'icon': '🍎',
          'color': 'info',
        });
      } else if (todayCalories > 2500) {
        recommendations.add({
          'title': 'Take a 20-minute walk',
          'description':
              'Balance today\'s calorie surplus with light activity.',
          'icon': '🚶',
          'color': 'info',
        });
      }

      // Water recommendations
      recommendations.add({
        'title': 'Drink more water',
        'description': 'You\'re 2 glasses short of your daily goal.',
        'icon': '💧',
        'color': 'info',
      });

      // Protein recommendations
      recommendations.add({
        'title': 'Increase protein intake',
        'description': 'Add 30g protein for better muscle recovery.',
        'icon': '💪',
        'color': 'success',
      });

      return recommendations;
    } catch (e) {
      print('Error generating personalized recommendations: $e');
      return [];
    }
  }

  // User Goals Methods
  Future<UserGoals?> getUserGoals(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('goals')
          .get();

      if (doc.exists) {
        return UserGoals.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user goals: $e');
      return null;
    }
  }

  Future<void> saveUserGoals(String userId, UserGoals goals) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('goals')
          .set(goals.toMap());
    } catch (e) {
      print('Error saving user goals: $e');
      rethrow;
    }
  }

  Stream<UserGoals?> getUserGoalsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('goals')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserGoals.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // User Preferences Methods
  Future<UserPreferences?> getUserPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('preferences')
          .get();

      if (doc.exists) {
        return UserPreferences.fromMap(doc.data()!);
      }
      return const UserPreferences();
    } catch (e) {
      print('Error getting user preferences: $e');
      return const UserPreferences();
    }
  }

  Future<void> saveUserPreferences(
      String userId, UserPreferences preferences) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('preferences')
          .set(preferences.toMap());
    } catch (e) {
      print('Error saving user preferences: $e');
      rethrow;
    }
  }

  Stream<UserPreferences> getUserPreferencesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('preferences')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserPreferences.fromMap(doc.data()!);
      }
      return const UserPreferences();
    });
  }

  // Delete food entry method
  Future<void> deleteFoodEntry(String userId, String entryId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .doc(entryId)
          .delete();
    } catch (e) {
      print('Error deleting food entry: $e');
      rethrow;
    }
  }

  // Save food entry method
  Future<void> saveFoodEntry(String userId, FoodEntry entry) async {
    if (!isAvailable) {
      print('Firebase not available, cannot save food entry');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('entries')
          .add(entry.toMap());
    } catch (e) {
      print('Error saving food entry: $e');
      rethrow;
    }
  }

  // ========== DAILY SUMMARY METHODS ==========

  /// Get today's daily summary with real-time updates
  Stream<DailySummary> getTodayDailySummary(String userId) {
    final today = DateTime.now();
    final dateKey = _getDateKey(today);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('dailySummary')
        .doc(dateKey)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return DailySummary.fromMap(doc.data()!);
      } else {
        // Create default summary for today
        return DailySummary(
          caloriesConsumed: 0,
          caloriesBurned: 0,
          caloriesGoal: 2000,
          steps: 0,
          stepsGoal: 10000,
          waterGlasses: 0,
          waterGlassesGoal: 8,
          date: today,
        );
      }
    }).handleError((error) {
      print('Error getting today daily summary: $error');
      return DailySummary(
        caloriesConsumed: 0,
        caloriesBurned: 0,
        caloriesGoal: 2000,
        steps: 0,
        stepsGoal: 10000,
        waterGlasses: 0,
        waterGlassesGoal: 8,
        date: today,
      );
    });
  }

  /// Update exercise data in daily summary
  Future<void> updateExercise(
    String userId, {
    required int caloriesBurned,
    required int durationMinutes,
    required String exerciseType,
  }) async {
    try {
      if (caloriesBurned < 0 || caloriesBurned > 5000) {
        throw Exception('Invalid calories burned: $caloriesBurned');
      }
      if (durationMinutes < 0 || durationMinutes > 480) {
        throw Exception('Invalid duration: $durationMinutes minutes');
      }

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(dateKey);

      await docRef.set({
        'caloriesBurned': FieldValue.increment(caloriesBurned),
        'exerciseMinutes': FieldValue.increment(durationMinutes),
        'exerciseType': exerciseType,
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(today),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating exercise: $e');
      rethrow;
    }
  }

  /// Update steps in daily summary
  Future<void> updateSteps(String userId, int steps) async {
    try {
      if (steps < 0 || steps > 100000) {
        throw Exception('Invalid steps: $steps');
      }

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(dateKey);

      await docRef.set({
        'steps': steps,
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(today),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating steps: $e');
      rethrow;
    }
  }

  /// Update weight in daily summary
  Future<void> updateWeight(String userId, double weight, double bmi) async {
    try {
      if (weight < 20 || weight > 500) {
        throw Exception('Invalid weight: $weight kg');
      }
      if (bmi < 10 || bmi > 100) {
        throw Exception('Invalid BMI: $bmi');
      }

      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(dateKey);

      await docRef.set({
        'weight': weight,
        'bmi': bmi,
        'lastWeightUpdate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(today),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating weight: $e');
      rethrow;
    }
  }

  /// Update user goals in daily summary
  Future<void> updateUserGoalsInDailySummary(
      String userId, UserGoals goals) async {
    try {
      final today = DateTime.now();
      final dateKey = _getDateKey(today);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc(dateKey);

      final updateData = {
        'caloriesGoal': goals.calorieGoal ?? 2000,
        'waterGlassesGoal': goals.waterGlassesGoal ?? 8,
        'stepsGoal': goals.stepsPerDayGoal ?? 10000,
        'sleepGoal': 8.0,
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(today),
      };

      await docRef.set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user goals in daily summary: $e');
      rethrow;
    }
  }

  /// Get historical daily summaries
  Stream<List<DailySummary>> getHistoricalDailySummaries(String userId,
      {int days = 7}) {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('dailySummary')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DailySummary.fromMap(doc.data()))
          .toList();
    }).handleError((error) {
      print('Error getting historical daily summaries: $error');
      return <DailySummary>[];
    });
  }

  /// Get date key for Firestore document
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
