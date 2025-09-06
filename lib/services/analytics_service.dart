import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Stream controllers for real-time updates
  final StreamController<List<DailySummary>> _dailySummariesController = 
      StreamController<List<DailySummary>>.broadcast();
  final StreamController<MacroBreakdown> _macroBreakdownController = 
      StreamController<MacroBreakdown>.broadcast();
  final StreamController<List<UserAchievement>> _achievementsController = 
      StreamController<List<UserAchievement>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _insightsController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _recommendationsController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Streams for real-time data
  Stream<List<DailySummary>> get dailySummariesStream => _dailySummariesController.stream;
  Stream<MacroBreakdown> get macroBreakdownStream => _macroBreakdownController.stream;
  Stream<List<UserAchievement>> get achievementsStream => _achievementsController.stream;
  Stream<List<Map<String, dynamic>>> get insightsStream => _insightsController.stream;
  Stream<List<Map<String, dynamic>>> get recommendationsStream => _recommendationsController.stream;

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

  /// Initialize real-time analytics
  Future<void> initializeRealTimeAnalytics({int days = 7}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Set up real-time listeners
    await _setupFoodEntriesListener(userId, days);
    await _setupAchievementsListener(userId);
    await _setupWeightHistoryListener(userId);
    
    // Generate initial insights and recommendations
    await _generateInsights(userId);
    await _generateRecommendations(userId);
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

      summaries.add(DailySummary(
        caloriesConsumed: caloriesConsumed,
        caloriesBurned: 300, // Default - should be tracked separately
        caloriesGoal: 2000, // Should come from user profile
        steps: 5000, // Default - should be tracked separately
        stepsGoal: 10000,
        date: date,
      ));
    }

    _cachedDailySummaries = summaries;
    _dailySummariesController.add(summaries);

    // Update macro breakdown
    final totalMacros = summaries.fold(
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
      (sum, day) => sum + day.macroBreakdown,
    );
    _cachedMacroBreakdown = totalMacros;
    _macroBreakdownController.add(totalMacros);

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
        _achievementsController.add(achievements);
      } else {
        // Return default achievements if none exist
        final defaultAchievements = Achievements.defaultAchievements;
        _cachedAchievements = defaultAchievements;
        _achievementsController.add(defaultAchievements);
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
      _insightsController.add(insights);
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
      _recommendationsController.add(recommendations);
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

  /// Dispose resources
  void dispose() {
    _foodEntriesSubscription?.cancel();
    _achievementsSubscription?.cancel();
    _weightHistorySubscription?.cancel();
    
    _dailySummariesController.close();
    _macroBreakdownController.close();
    _achievementsController.close();
    _insightsController.close();
    _recommendationsController.close();
  }
}
