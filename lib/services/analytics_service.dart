import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import 'firebase_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Stream controllers for real-time updates (recreated if closed)
  StreamController<List<DailySummary>>? _dailySummariesController;
  StreamController<MacroBreakdown>? _macroBreakdownController;
  StreamController<List<UserAchievement>>? _achievementsController;
  StreamController<List<Map<String, dynamic>>>? _insightsController;
  StreamController<List<Map<String, dynamic>>>? _recommendationsController;

  // Getter methods that ensure controllers exist and are not closed
  StreamController<List<DailySummary>> get _ensureDailySummariesController {
    if (_dailySummariesController?.isClosed != false) {
      _dailySummariesController = StreamController<List<DailySummary>>.broadcast();
    }
    return _dailySummariesController!;
  }

  StreamController<MacroBreakdown> get _ensureMacroBreakdownController {
    if (_macroBreakdownController?.isClosed != false) {
      _macroBreakdownController = StreamController<MacroBreakdown>.broadcast();
    }
    return _macroBreakdownController!;
  }

  StreamController<List<UserAchievement>> get _ensureAchievementsController {
    if (_achievementsController?.isClosed != false) {
      _achievementsController = StreamController<List<UserAchievement>>.broadcast();
    }
    return _achievementsController!;
  }

  StreamController<List<Map<String, dynamic>>> get _ensureInsightsController {
    if (_insightsController?.isClosed != false) {
      _insightsController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _insightsController!;
  }

  StreamController<List<Map<String, dynamic>>> get _ensureRecommendationsController {
    if (_recommendationsController?.isClosed != false) {
      _recommendationsController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _recommendationsController!;
  }

  // Streams for real-time data
  Stream<List<DailySummary>> get dailySummariesStream => _ensureDailySummariesController.stream;
  Stream<MacroBreakdown> get macroBreakdownStream => _ensureMacroBreakdownController.stream;
  Stream<List<UserAchievement>> get achievementsStream => _ensureAchievementsController.stream;
  Stream<List<Map<String, dynamic>>> get insightsStream => _ensureInsightsController.stream;
  Stream<List<Map<String, dynamic>>> get recommendationsStream => _ensureRecommendationsController.stream;

  // Cache for offline support
  List<DailySummary> _cachedDailySummaries = [];
  MacroBreakdown _cachedMacroBreakdown = MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
  List<UserAchievement> _cachedAchievements = [];
  List<Map<String, dynamic>> _cachedInsights = [];
  List<Map<String, dynamic>> _cachedRecommendations = [];

  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _foodEntriesSubscription;
  StreamSubscription<DocumentSnapshot>? _achievementsSubscription;
  StreamSubscription<QuerySnapshot>? _weightHistorySubscription;

  /// Check if service is properly initialized
  bool get isInitialized => _foodEntriesSubscription != null || 
                           _achievementsSubscription != null || 
                           _weightHistorySubscription != null;

  /// Initialize real-time analytics with automated data tracking (with network timeouts)
  Future<void> initializeRealTimeAnalytics({int days = 7}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No authenticated user for analytics initialization');
      return;
    }

    // Cancel existing listeners to prevent duplicates
    await _cancelExistingListeners();

    try {
      print('Setting up analytics listeners for user: $userId');
      
      // Ensure stream controllers are available
      _ensureDailySummariesController;
      _ensureMacroBreakdownController;
      _ensureAchievementsController;
      _ensureInsightsController;
      _ensureRecommendationsController;
      
      // Set up real-time listeners with timeouts
      await Future.wait([
        _setupFoodEntriesListener(userId, days).timeout(
          const Duration(seconds: 3),
          onTimeout: () => print('Food entries listener setup timed out')
        ),
        _setupAchievementsListener(userId).timeout(
          const Duration(seconds: 2),
          onTimeout: () => print('Achievements listener setup timed out')
        ),
        _setupWeightHistoryListener(userId).timeout(
          const Duration(seconds: 2),
          onTimeout: () => print('Weight history listener setup timed out')
        ),
      ]);
      
      print('Analytics listeners set up successfully');
      
      // Generate initial insights and recommendations with timeout (non-blocking)
      _generateInsights(userId).timeout(
        const Duration(seconds: 3),
        onTimeout: () => print('Insights generation timed out')
      ).catchError((error) => print('Error generating insights: $error'));
      
      _generateRecommendations(userId).timeout(
        const Duration(seconds: 3),
        onTimeout: () => print('Recommendations generation timed out')
      ).catchError((error) => print('Error generating recommendations: $error'));
      
      print('Analytics initialization completed');
      
    } catch (e) {
      print('Error during analytics initialization: $e');
      // Don't throw - let the app continue with empty data
    }
  }

  /// Cancel existing listeners to prevent duplicates
  Future<void> _cancelExistingListeners() async {
    try {
      await _foodEntriesSubscription?.cancel();
      await _achievementsSubscription?.cancel();
      await _weightHistorySubscription?.cancel();
      
      _foodEntriesSubscription = null;
      _achievementsSubscription = null;
      _weightHistorySubscription = null;
      
      print('Existing analytics listeners cancelled');
    } catch (e) {
      print('Error cancelling existing listeners: $e');
    }
  }

  /// Set up real-time food entries listener
  Future<void> _setupFoodEntriesListener(String userId, int days) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    _foodEntriesSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('entries')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
      await _processFoodEntriesUpdate(snapshot, days);
    });
  }

  /// Process food entries update
  Future<void> _processFoodEntriesUpdate(QuerySnapshot snapshot, int days) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Group entries by date
    final Map<String, List<QueryDocumentSnapshot>> entriesByDate = {};
    for (final doc in snapshot.docs) {
      final timestamp = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      final date = timestamp.toDate();
      final dateKey = '${date.year}-${date.month}-${date.day}';
      entriesByDate.putIfAbsent(dateKey, () => []).add(doc);
    }

    // Generate daily summaries
    final List<DailySummary> summaries = [];
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final dayEntries = entriesByDate[dateKey] ?? [];
      
      final caloriesConsumed = dayEntries.fold(0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        return sum + (data['calories'] as int? ?? 0);
      });

      final macros = dayEntries.fold(
        MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
        (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + MacroBreakdown(
            carbs: (data['carbs'] ?? 0.0).toDouble(),
            protein: (data['protein'] ?? 0.0).toDouble(),
            fat: (data['fat'] ?? 0.0).toDouble(),
            fiber: (data['fiber'] ?? 0.0).toDouble(),
            sugar: (data['sugar'] ?? 0.0).toDouble(),
          );
        },
      );

      // Get actual user data instead of hardcoded values
      final actualCaloriesBurned = await _getActualCaloriesBurned(userId, date);
      final actualSteps = await _getActualSteps(userId, date);
      final userGoals = await _getUserGoals(userId);
      
      summaries.add(DailySummary(
        caloriesConsumed: caloriesConsumed,
        caloriesBurned: actualCaloriesBurned,
        caloriesGoal: userGoals['caloriesGoal'] ?? 2000,
        steps: actualSteps,
        stepsGoal: userGoals['stepsGoal'] ?? 10000,
        waterGlasses: 0, // This should be tracked from user input
        waterGlassesGoal: userGoals['waterGlassesGoal'] ?? 8,
        date: date,
        macroBreakdown: macros, // Pass the calculated macro data
      ));
    }

    _cachedDailySummaries = summaries;
    try {
      _ensureDailySummariesController.add(summaries);
    } catch (e) {
      print('Error broadcasting daily summaries: $e');
    }

    // Update macro breakdown
    final totalMacros = summaries.fold(
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
      (sum, day) => sum + day.macroBreakdown,
    );
    _cachedMacroBreakdown = totalMacros;
    try {
      _ensureMacroBreakdownController.add(totalMacros);
    } catch (e) {
      print('Error broadcasting macro breakdown: $e');
    }

    // Regenerate insights and recommendations
    await _generateInsights(userId);
    await _generateRecommendations(userId);
  }

  /// Set up achievements listener
  Future<void> _setupAchievementsListener(String userId) async {
    _achievementsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('achievements')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() ?? {};
        final achievements = <UserAchievement>[];
        
        for (final achievementData in data['achievements'] ?? []) {
          achievements.add(UserAchievement.fromJson(achievementData));
        }
        
        _cachedAchievements = achievements;
        try {
          _ensureAchievementsController.add(achievements);
        } catch (e) {
          print('Error broadcasting achievements: $e');
        }
      } else {
        // Return default achievements if none exist
        final defaultAchievements = Achievements.defaultAchievements;
        _cachedAchievements = defaultAchievements;
        try {
          _ensureAchievementsController.add(defaultAchievements);
        } catch (e) {
          print('Error broadcasting default achievements: $e');
        }
      }
    });
  }

  /// Set up weight history listener
  Future<void> _setupWeightHistoryListener(String userId) async {
    _weightHistorySubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('weightLogs')
        .orderBy('date', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) {
      // Weight history updates can trigger insights regeneration
      _generateInsights(userId);
    });
  }

  /// Generate AI insights based on current data
  Future<void> _generateInsights(String userId) async {
    try {
      final insights = <Map<String, dynamic>>[];
      
      // Analyze calorie trends
      if (_cachedDailySummaries.length >= 7) {
        final thisWeek = _cachedDailySummaries.take(7).fold(0, (sum, day) => sum + day.caloriesConsumed);
        final lastWeek = _cachedDailySummaries.length >= 14 
            ? _cachedDailySummaries.skip(7).take(7).fold(0, (sum, day) => sum + day.caloriesConsumed)
            : thisWeek;
        
        if (lastWeek > 0) {
          final changePercent = ((thisWeek - lastWeek) / lastWeek * 100).round();
          if (changePercent > 10) {
            insights.add({
              'title': '📈 Calorie Increase',
              'message': 'You consumed $changePercent% more calories this week compared to last week.',
              'color': 'warning',
              'timestamp': DateTime.now(),
            });
          } else if (changePercent < -10) {
            insights.add({
              'title': '📉 Calorie Decrease',
              'message': 'You consumed ${changePercent.abs()}% fewer calories this week compared to last week.',
              'color': 'info',
              'timestamp': DateTime.now(),
            });
          }
        }
      }
      
      // Analyze macro balance
      if (!_cachedMacroBreakdown.isWithinRecommended) {
        insights.add({
          'title': '⚖️ Macro Imbalance',
          'message': 'Your macro distribution needs adjustment. Consider consulting with a nutritionist.',
          'color': 'warning',
          'timestamp': DateTime.now(),
        });
      }
      
      // Analyze consistency
      final goalMetDays = _cachedDailySummaries.where((day) => day.isGoalAchieved).length;
      if (goalMetDays >= 5) {
        insights.add({
          'title': '🎯 Goal Consistency',
          'message': 'Great job! You met your calorie goal $goalMetDays days this week.',
          'color': 'success',
          'timestamp': DateTime.now(),
        });
      }
      
      _cachedInsights = insights;
      try {
        _ensureInsightsController.add(insights);
      } catch (e) {
        print('Error broadcasting insights: $e');
      }
    } catch (e) {
      print('Error generating insights: $e');
    }
  }

  /// Generate personalized recommendations
  Future<void> _generateRecommendations(String userId) async {
    try {
      final recommendations = <Map<String, dynamic>>[];
      
      // Get user profile for personalized recommendations
      final profile = await _firebaseService.getUserProfile(userId);
      
      // Calorie-based recommendations
      if (_cachedDailySummaries.isNotEmpty) {
        final todayCalories = _cachedDailySummaries.last.caloriesConsumed;
        
        if (todayCalories < 1500) {
          recommendations.add({
            'title': 'Increase calorie intake',
            'description': 'You\'re below your minimum daily calorie needs. Consider adding healthy snacks.',
            'icon': '🍎',
            'color': 'info',
            'priority': 1,
            'timestamp': DateTime.now(),
          });
        } else if (todayCalories > 2500) {
          recommendations.add({
            'title': 'Take a 20-minute walk',
            'description': 'Balance today\'s calorie surplus with light activity.',
            'icon': '🚶',
            'color': 'info',
            'priority': 2,
            'timestamp': DateTime.now(),
          });
        }
      }
      
      
      // Protein recommendations
      if (_cachedMacroBreakdown.protein < 100) {
        recommendations.add({
          'title': 'Increase protein intake',
          'description': 'Add ${(120 - _cachedMacroBreakdown.protein).toStringAsFixed(0)}g protein for better muscle recovery.',
          'icon': '💪',
          'color': 'success',
          'priority': 4,
          'timestamp': DateTime.now(),
        });
      }
      
      // Sort by priority
      recommendations.sort((a, b) => (a['priority'] ?? 999).compareTo(b['priority'] ?? 999));
      
      _cachedRecommendations = recommendations;
      try {
        _ensureRecommendationsController.add(recommendations);
      } catch (e) {
        print('Error broadcasting recommendations: $e');
      }
    } catch (e) {
      print('Error generating recommendations: $e');
    }
  }

  /// Get cached data for immediate access
  List<DailySummary> get cachedDailySummaries => _cachedDailySummaries;
  MacroBreakdown get cachedMacroBreakdown => _cachedMacroBreakdown;
  List<UserAchievement> get cachedAchievements => _cachedAchievements;
  List<Map<String, dynamic>> get cachedInsights => _cachedInsights;
  List<Map<String, dynamic>> get cachedRecommendations => _cachedRecommendations;

  /// Update period and refresh data
  Future<void> updatePeriod(int days) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Cancel existing listeners
    await _foodEntriesSubscription?.cancel();
    
    // Set up new listener with updated period
    await _setupFoodEntriesListener(userId, days);
  }

  /// Save weight log entry
  Future<void> saveWeightLog(double weight, double bmi) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firebaseService.saveWeightLog(userId, weight, bmi);
  }

  /// Save user achievement
  Future<void> saveUserAchievement(UserAchievement achievement) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firebaseService.saveUserAchievement(userId, achievement);
  }

  /// Calculate streaks and achievements based on automated tracking
  Future<void> calculateStreaksAndAchievements() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get daily summaries for streak calculation
      final summaries = await _firebaseService.getDailySummaries(userId, days: 30);
      
      // Calculate streaks based on automated data
      final streaks = _calculateStreaks(summaries);
      
      // Calculate achievements based on automated data
      final achievements = _calculateAchievements(summaries);
      
      // Update cached data
      _cachedAchievements = achievements;
      try {
        _ensureAchievementsController.add(achievements);
      } catch (e) {
        print('Error broadcasting calculated achievements: $e');
      }
      
      // Save to Firebase
      await _saveStreaksAndAchievements(userId, streaks, achievements);
      
    } catch (e) {
      print('Error calculating streaks and achievements: $e');
    }
  }

  /// Calculate streaks from daily summaries
  Map<String, int> _calculateStreaks(List<DailySummary> summaries) {
    final streaks = <String, int>{
      'calorieGoal': 0,
      'stepsGoal': 0,
      'waterGoal': 0,
      'overall': 0,
    };

    // Sort summaries by date (newest first)
    summaries.sort((a, b) => b.date.compareTo(a.date));
    
    // Calculate streaks for each goal
    for (final goal in streaks.keys) {
      int currentStreak = 0;
      final today = DateTime.now();
      
      for (int i = 0; i < summaries.length; i++) {
        final summary = summaries[i];
        final summaryDate = summary.date;
        final daysDiff = today.difference(summaryDate).inDays;
        
        // Only count consecutive days
        if (daysDiff != i) break;
        
        bool goalMet = false;
        switch (goal) {
          case 'calorieGoal':
            goalMet = summary.caloriesConsumed >= summary.caloriesGoal;
            break;
          case 'stepsGoal':
            goalMet = summary.steps >= summary.stepsGoal;
            break;
          case 'waterGoal':
            goalMet = summary.waterGlasses >= summary.waterGlassesGoal;
            break;
          case 'overall':
            goalMet = summary.overallProgress >= 0.8; // 80% of all goals
            break;
        }
        
        if (goalMet) {
          currentStreak++;
        } else {
          break;
        }
      }
      
      streaks[goal] = currentStreak;
    }
    
    return streaks;
  }

  /// Calculate achievements based on automated data
  List<UserAchievement> _calculateAchievements(List<DailySummary> summaries) {
    final achievements = <UserAchievement>[];
    
    // Calculate total stats
    final totalCaloriesConsumed = summaries.fold(0, (sum, s) => sum + s.caloriesConsumed);
    final totalSteps = summaries.fold(0, (sum, s) => sum + s.steps);
    final totalWaterGlasses = summaries.fold(0, (sum, s) => sum + s.waterGlasses);
    final daysWithFoodLogged = summaries.where((s) => s.caloriesConsumed > 0).length;
    final daysWithSteps = summaries.where((s) => s.steps > 0).length;
    
    // Define achievement criteria
    final achievementCriteria = [
      {
        'id': 'first_meal',
        'title': 'First Meal Logged',
        'description': 'Logged your first meal',
        'condition': daysWithFoodLogged >= 1,
        'icon': '🍽️',
      },
      {
        'id': 'calorie_tracker',
        'title': 'Calorie Tracker',
        'description': 'Logged 7 days of meals',
        'condition': daysWithFoodLogged >= 7,
        'icon': '📊',
      },
      {
        'id': 'step_master',
        'title': 'Step Master',
        'description': 'Walked 10,000 steps in a day',
        'condition': summaries.any((s) => s.steps >= 10000),
        'icon': '🚶‍♂️',
      },
      {
        'id': 'water_warrior',
        'title': 'Water Warrior',
        'description': 'Drank 8 glasses of water in a day',
        'condition': summaries.any((s) => s.waterGlasses >= 8),
        'icon': '💧',
      },
      {
        'id': 'week_warrior',
        'title': 'Week Warrior',
        'description': 'Met your goals for 7 consecutive days',
        'condition': _calculateStreaks(summaries)['overall']! >= 7,
        'icon': '🏆',
      },
      {
        'id': 'month_master',
        'title': 'Month Master',
        'description': 'Met your goals for 30 consecutive days',
        'condition': _calculateStreaks(summaries)['overall']! >= 30,
        'icon': '👑',
      },
    ];
    
    // Check each achievement
    for (final criteria in achievementCriteria) {
      if (criteria['condition'] as bool) {
        achievements.add(UserAchievement(
          id: criteria['id'] as String,
          title: criteria['title'] as String,
          description: criteria['description'] as String,
          icon: criteria['icon'] as String,
          color: Colors.blue,
          points: 0, // No points system
          type: AchievementType.bronze,
          isUnlocked: true,
          unlockedAt: DateTime.now(),
          requirements: {},
        ));
      }
    }
    
    return achievements;
  }

  /// Save streaks and achievements to Firebase
  Future<void> _saveStreaksAndAchievements(String userId, Map<String, int> streaks, List<UserAchievement> achievements) async {
    try {
      final batch = _firestore.batch();
      
      // Save streaks
      final streaksRef = _firestore.collection('users').doc(userId).collection('progress').doc('streaks');
      batch.set(streaksRef, {
        'streaks': streaks,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Save achievements
      final achievementsRef = _firestore.collection('users').doc(userId).collection('progress').doc('achievements');
      batch.set(achievementsRef, {
        'achievements': achievements.map((a) => a.toJson()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
    } catch (e) {
      print('Error saving streaks and achievements: $e');
    }
  }

  /// Get actual calories burned for a specific date
  Future<int> _getActualCaloriesBurned(String userId, DateTime date) async {
    try {
      // Try to get from daily summary first
      final summaryDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc('${date.year}-${date.month}-${date.day}')
          .get();
      
      if (summaryDoc.exists) {
        final data = summaryDoc.data()!;
        return data['caloriesBurned'] ?? 0;
      }
      
      // If no data found, return 0 instead of fake data
      return 0;
    } catch (e) {
      print('Error getting actual calories burned: $e');
      return 0;
    }
  }

  /// Get actual steps for a specific date
  Future<int> _getActualSteps(String userId, DateTime date) async {
    try {
      // Try to get from daily summary first
      final summaryDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_summaries')
          .doc('${date.year}-${date.month}-${date.day}')
          .get();
      
      if (summaryDoc.exists) {
        final data = summaryDoc.data()!;
        return data['steps'] ?? 0;
      }
      
      // If no data found, return 0 instead of fake data
      return 0;
    } catch (e) {
      print('Error getting actual steps: $e');
      return 0;
    }
  }

  /// Get user goals from profile
  Future<Map<String, int>> _getUserGoals(String userId) async {
    try {
      final goalsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('goals')
          .doc('current')
          .get();
      
      if (goalsDoc.exists) {
        final data = goalsDoc.data()!;
        return {
          'caloriesGoal': data['dailyCalorieGoal'] ?? 2000,
          'stepsGoal': data['dailyStepGoal'] ?? 10000,
          'waterGlassesGoal': data['dailyWaterGoal'] ?? 8,
        };
      }
      
      // Return reasonable defaults if no goals set
      return {
        'caloriesGoal': 2000,
        'stepsGoal': 10000,
        'waterGlassesGoal': 8,
      };
    } catch (e) {
      print('Error getting user goals: $e');
      return {
        'caloriesGoal': 2000,
        'stepsGoal': 10000,
        'waterGlassesGoal': 8,
      };
    }
  }

  /// Dispose resources
  /// Clean up resources (but don't close controllers for singleton)
  Future<void> cleanup() async {
    try {
      print('Cleaning up analytics service...');
      await _cancelExistingListeners();
      print('Analytics service cleaned up');
    } catch (e) {
      print('Error during analytics cleanup: $e');
    }
  }

  /// Dispose method for singleton - only cancel listeners, don't close controllers
  void dispose() {
    print('Analytics service dispose called - cleaning up listeners only');
    cleanup();
    // Don't close controllers since this is a singleton that may be reused
  }
}
