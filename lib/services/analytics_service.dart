import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import 'firebase_service.dart';
import 'logger_service.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final LoggerService _logger = LoggerService();

  // Stream controllers for real-time updates (recreated if closed)
  StreamController<List<DailySummary>>? _dailySummariesController;
  StreamController<MacroBreakdown>? _macroBreakdownController;
  StreamController<List<UserAchievement>>? _achievementsController;
  StreamController<List<Map<String, dynamic>>>? _insightsController;
  StreamController<List<Map<String, dynamic>>>? _recommendationsController;
  StreamController<Map<String, dynamic>>? _weeklyStatsController;

  // Getter methods that ensure controllers exist and are not closed
  StreamController<List<DailySummary>> get _ensureDailySummariesController {
    if (_dailySummariesController == null || _dailySummariesController!.isClosed) {
      _dailySummariesController =
          StreamController<List<DailySummary>>.broadcast();
    }
    return _dailySummariesController!;
  }

  StreamController<MacroBreakdown> get _ensureMacroBreakdownController {
    if (_macroBreakdownController == null || _macroBreakdownController!.isClosed) {
      _macroBreakdownController = StreamController<MacroBreakdown>.broadcast();
    }
    return _macroBreakdownController!;
  }

  StreamController<List<UserAchievement>> get _ensureAchievementsController {
    if (_achievementsController == null || _achievementsController!.isClosed) {
      _achievementsController =
          StreamController<List<UserAchievement>>.broadcast();
    }
    return _achievementsController!;
  }

  StreamController<List<Map<String, dynamic>>> get _ensureInsightsController {
    if (_insightsController == null || _insightsController!.isClosed) {
      _insightsController =
          StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _insightsController!;
  }

  StreamController<List<Map<String, dynamic>>>
      get _ensureRecommendationsController {
    if (_recommendationsController == null || _recommendationsController!.isClosed) {
      _recommendationsController =
          StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _recommendationsController!;
  }

  StreamController<Map<String, dynamic>> get _ensureWeeklyStatsController {
    if (_weeklyStatsController == null || _weeklyStatsController!.isClosed) {
      _weeklyStatsController = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _weeklyStatsController!;
  }

  // Streams for real-time data
  Stream<List<DailySummary>> get dailySummariesStream =>
      _ensureDailySummariesController.stream;
  Stream<MacroBreakdown> get macroBreakdownStream =>
      _ensureMacroBreakdownController.stream;
  Stream<List<UserAchievement>> get achievementsStream =>
      _ensureAchievementsController.stream;
  Stream<List<Map<String, dynamic>>> get insightsStream =>
      _ensureInsightsController.stream;
  Stream<List<Map<String, dynamic>>> get recommendationsStream =>
      _ensureRecommendationsController.stream;
  Stream<Map<String, dynamic>> get weeklyStatsStream =>
      _ensureWeeklyStatsController.stream;

  // Cache for offline support
  List<DailySummary> _cachedDailySummaries = [];
  MacroBreakdown _cachedMacroBreakdown =
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
  List<UserAchievement> _cachedAchievements = [];
  List<Map<String, dynamic>> _cachedInsights = [];
  List<Map<String, dynamic>> _cachedRecommendations = [];

  // Real-time listeners
  StreamSubscription<QuerySnapshot>? _foodEntriesSubscription;
  StreamSubscription<DocumentSnapshot>? _achievementsSubscription;
  StreamSubscription<QuerySnapshot>? _weightHistorySubscription;

  /// Check if service is properly initialized
  bool get isInitialized =>
      _foodEntriesSubscription != null ||
      _achievementsSubscription != null ||
      _weightHistorySubscription != null;

  /// Initialize real-time analytics with automated data tracking (with network timeouts)
  Future<void> initializeRealTimeAnalytics({int days = 7}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _logger.warning('No authenticated user for analytics initialization');
      return;
    }

    // Cancel existing listeners to prevent duplicates
    await _cancelExistingListeners();

    try {
      _logger.info('Setting up analytics listeners', {'userId': userId});

      // Ensure stream controllers are available
      _ensureDailySummariesController;
      _ensureMacroBreakdownController;
      _ensureAchievementsController;
      _ensureInsightsController;
      _ensureRecommendationsController;
      _ensureWeeklyStatsController;

      // Set up real-time listeners with timeouts
      await Future.wait([
        _setupFoodEntriesListener(userId, days).timeout(
            const Duration(seconds: 3),
            onTimeout: () => _logger.warning('Food entries listener setup timed out')),
        _setupAchievementsListener(userId).timeout(const Duration(seconds: 2),
            onTimeout: () => _logger.warning('Achievements listener setup timed out')),
        _setupWeightHistoryListener(userId).timeout(const Duration(seconds: 2),
            onTimeout: () => _logger.warning('Weight history listener setup timed out')),
      ]);

      _logger.info('Analytics listeners set up successfully');

      // Generate initial insights and recommendations with timeout (non-blocking)
      _generateInsights(userId)
          .timeout(const Duration(seconds: 3),
              onTimeout: () => _logger.warning('Insights generation timed out'))
          .catchError((error) => _logger.error('Error generating insights', {'error': error.toString()}));

      _generateRecommendations(userId)
          .timeout(const Duration(seconds: 3),
              onTimeout: () => _logger.warning('Recommendations generation timed out'))
          .catchError(
              (error) => _logger.error('Error generating recommendations', {'error': error.toString()}));

      _logger.info('Analytics initialization completed');
    } catch (e) {
      _logger.error('Error during analytics initialization', {'error': e.toString()});
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

      _logger.debug('Existing analytics listeners cancelled');
    } catch (e) {
      _logger.error('Error cancelling existing listeners', {'error': e.toString()});
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
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen(
          (snapshot) async {
            try {
              await _processFoodEntriesUpdate(snapshot, days);
            } catch (e) {
              _logger.error('Error processing food entries update', {'error': e.toString()});
            }
          },
          onError: (error) {
            _logger.error('Food entries listener error', {'error': error.toString()});
          },
        );
  }

  /// Process food entries update
  Future<void> _processFoodEntriesUpdate(
      QuerySnapshot snapshot, int days) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Group entries by date
    final Map<String, List<QueryDocumentSnapshot>> entriesByDate = {};
    for (final doc in snapshot.docs) {
      final timestamp =
          (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
      final date = timestamp.toDate();
      final dateKey = '${date.year}-${date.month}-${date.day}';
      entriesByDate.putIfAbsent(dateKey, () => []).add(doc);
    }

    // Generate daily summaries for a continuous window (include zero days)
    final List<DailySummary> summaries = [];
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days - 1));

    // Track which dates have entries
    final datesWithData = entriesByDate.keys.toSet();
    
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final dayEntries = entriesByDate[dateKey] ?? [];

      final caloriesConsumed = dayEntries.fold(0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        return sum + (data['calories'] as int? ?? 0);
      });

      final macros = dayEntries.fold(
        MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
        (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum +
              MacroBreakdown(
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
        waterGlasses: 0, // If tracked elsewhere, will be merged when available
        waterGlassesGoal: userGoals['waterGlassesGoal'] ?? 8,
        date: date,
        macroBreakdown: macros, // Pass the calculated macro data
      ));
    }
    
    // Clean up old dailySummary data (older than 7 days) - non-blocking
    _cleanupOldDailySummaryData(userId).catchError((e) {
      _logger.warning('Cleanup error (non-blocking)', {'error': e.toString()});
    });

    _cachedDailySummaries = summaries;
    try {
      if (!_ensureDailySummariesController.isClosed) {
        _ensureDailySummariesController.add(summaries);
      }
    } catch (e) {
      _logger.error('Error broadcasting daily summaries', {'error': e.toString()});
    }

    // Update macro breakdown
    final totalMacros = summaries.fold(
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
      (sum, day) => sum + day.macroBreakdown,
    );
    _cachedMacroBreakdown = totalMacros;
    try {
      if (!_ensureMacroBreakdownController.isClosed) {
        _ensureMacroBreakdownController.add(totalMacros);
      }
    } catch (e) {
      _logger.error('Error broadcasting macro breakdown', {'error': e.toString()});
    }

    // Regenerate insights and recommendations
    await _generateInsights(userId);
    await _generateRecommendations(userId);

    // Broadcast weekly stats (calories, steps, workout sessions)
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days - 1));
      final calories = <int>[];
      final steps = <int>[];
      final workouts = <int>[];

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final ds = summaries.firstWhere(
          (s) => _sameDay(s.date, date),
          orElse: () => DailySummary(
            caloriesConsumed: 0,
            caloriesBurned: 0,
            caloriesGoal: 2000,
            steps: 0,
            stepsGoal: 10000,
            waterGlasses: 0,
            waterGlassesGoal: 8,
            date: date,
          ),
        );

        final exerciseMinutes = await _getActualExerciseMinutes(userId, date);
        calories.add(ds.caloriesConsumed);
        steps.add(ds.steps);
        workouts.add((exerciseMinutes > 0 || ds.caloriesBurned > 0) ? 1 : 0);
      }

      final payload = {
        'startDate': startDate,
        'endDate': endDate,
        'calories': calories,
        'steps': steps,
        'workoutSessions': workouts,
      };
      if (!_ensureWeeklyStatsController.isClosed) {
        _ensureWeeklyStatsController.add(payload);
      }
    } catch (e) {
      print('Error broadcasting weekly stats: $e');
    }
  }

  /// Set up achievements listener
  Future<void> _setupAchievementsListener(String userId) async {
    _achievementsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('achievements')
        .snapshots()
        .listen(
          (snapshot) async {
            try {
              if (snapshot.exists) {
                final data = snapshot.data() ?? {};
                final achievements = <UserAchievement>[];

                for (final achievementData in data['achievements'] ?? []) {
                  achievements.add(UserAchievement.fromJson(achievementData));
                }

                _cachedAchievements = achievements;
                if (!_ensureAchievementsController.isClosed) {
                  _ensureAchievementsController.add(achievements);
                }
              } else {
                // Return default achievements if none exist
                final defaultAchievements = Achievements.defaultAchievements;
                _cachedAchievements = defaultAchievements;
                if (!_ensureAchievementsController.isClosed) {
                  _ensureAchievementsController.add(defaultAchievements);
                }
              }
            } catch (e) {
              _logger.error('Error processing achievements snapshot', {'error': e.toString()});
            }
          },
          onError: (error) {
            _logger.error('Achievements listener error', {'error': error.toString()});
          },
        );
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
        .listen(
          (snapshot) {
            try {
              // Weight history updates can trigger insights regeneration (debounced)
              _generateInsights(userId)
                  .timeout(const Duration(seconds: 3),
                      onTimeout: () => _logger.warning('Insights generation timed out'))
                  .catchError((error) => _logger.error('Error generating insights', {'error': error.toString()}));
            } catch (e) {
              _logger.error('Error processing weight history snapshot', {'error': e.toString()});
            }
          },
          onError: (error) {
            _logger.error('Weight history listener error', {'error': error.toString()});
          },
        );
  }

  /// Generate AI insights based on current data
  Future<void> _generateInsights(String userId) async {
    try {
      final insights = <Map<String, dynamic>>[];

      // Analyze calorie trends
      if (_cachedDailySummaries.length >= 7) {
        final thisWeek = _cachedDailySummaries
            .take(7)
            .fold(0, (sum, day) => sum + day.caloriesConsumed);
        final lastWeek = _cachedDailySummaries.length >= 14
            ? _cachedDailySummaries
                .skip(7)
                .take(7)
                .fold(0, (sum, day) => sum + day.caloriesConsumed)
            : thisWeek;

        if (lastWeek > 0) {
          final changePercent =
              ((thisWeek - lastWeek) / lastWeek * 100).round();
          if (changePercent > 10) {
            insights.add({
              'title': '📈 Calorie Increase',
              'message':
                  'You consumed $changePercent% more calories this week compared to last week.',
              'color': 'warning',
              'timestamp': DateTime.now(),
            });
          } else if (changePercent < -10) {
            insights.add({
              'title': '📉 Calorie Decrease',
              'message':
                  'You consumed ${changePercent.abs()}% fewer calories this week compared to last week.',
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
          'message':
              'Your macro distribution needs adjustment. Consider consulting with a nutritionist.',
          'color': 'warning',
          'timestamp': DateTime.now(),
        });
      }

      // Analyze consistency
      final goalMetDays =
          _cachedDailySummaries.where((day) => day.isGoalAchieved).length;
      if (goalMetDays >= 5) {
        insights.add({
          'title': '🎯 Goal Consistency',
          'message':
              'Great job! You met your calorie goal $goalMetDays days this week.',
          'color': 'success',
          'timestamp': DateTime.now(),
        });
      }

      _cachedInsights = insights;
      try {
        if (!_ensureInsightsController.isClosed) {
          _ensureInsightsController.add(insights);
        }
      } catch (e) {
        _logger.error('Error broadcasting insights', {'error': e.toString()});
      }
    } catch (e) {
      _logger.error('Error generating insights', {'error': e.toString()});
    }
  }

  /// Generate personalized recommendations
  Future<void> _generateRecommendations(String userId) async {
    try {
      final recommendations = <Map<String, dynamic>>[];

      // Get user profile for personalized recommendations
      Map<String, dynamic>? profile;
      try {
        profile = await _firebaseService.getUserProfile(userId);
      } catch (e) {
        print('⚠️ Could not load user profile for recommendations: $e');
      }

      // Get user goals for better recommendations
      final userGoals = await _getUserGoals(userId);
      final calorieGoal = userGoals['caloriesGoal'] ?? 2000;

      // Calorie-based recommendations
      if (_cachedDailySummaries.isNotEmpty) {
        final today = _cachedDailySummaries.last;
        final todayCalories = today.caloriesConsumed;
        final calorieDeficit = calorieGoal - todayCalories;

        if (todayCalories < 1200) {
          recommendations.add({
            'title': 'Increase calorie intake',
            'description':
                'You\'re below your minimum daily calorie needs ($todayCalories/$calorieGoal kcal). Consider adding healthy snacks or a balanced meal.',
            'type': 'nutrition',
            'priority': 'high',
            'timestamp': DateTime.now(),
          });
        } else if (todayCalories > calorieGoal * 1.2) {
          recommendations.add({
            'title': 'Balance your calories',
            'description':
                'You\'ve exceeded your daily goal by ${((todayCalories - calorieGoal) / calorieGoal * 100).toStringAsFixed(0)}%. Consider light activity or adjusting tomorrow\'s intake.',
            'type': 'activity',
            'priority': 'medium',
            'timestamp': DateTime.now(),
          });
        } else if (calorieDeficit > 0 && calorieDeficit < 200) {
          recommendations.add({
            'title': 'Almost at your goal!',
            'description':
                'You\'re ${calorieDeficit.toStringAsFixed(0)} calories away from your daily goal. A small healthy snack can help you reach it!',
            'type': 'general',
            'priority': 'low',
            'timestamp': DateTime.now(),
          });
        }
      }

      // Macro-based recommendations
      final avgDailyProtein = _cachedDailySummaries.isNotEmpty
          ? (_cachedMacroBreakdown.protein / _cachedDailySummaries.length)
          : 0.0;
      final avgDailyCarbs = _cachedDailySummaries.isNotEmpty
          ? (_cachedMacroBreakdown.carbs / _cachedDailySummaries.length)
          : 0.0;
      final avgDailyFat = _cachedDailySummaries.isNotEmpty
          ? (_cachedMacroBreakdown.fat / _cachedDailySummaries.length)
          : 0.0;

      // Protein recommendations
      if (avgDailyProtein < 80) {
        final proteinNeeded = (80 - avgDailyProtein).toStringAsFixed(0);
        recommendations.add({
          'title': 'Boost protein intake',
          'description':
              'Your average protein is ${avgDailyProtein.toStringAsFixed(0)}g/day. Aim for ${proteinNeeded}g more for muscle recovery and satiety. Try lean meats, eggs, or legumes.',
            'type': 'nutrition',
            'priority': 'high',
          'timestamp': DateTime.now(),
        });
      }

      // Carb recommendations
      if (avgDailyCarbs < 100) {
        recommendations.add({
          'title': 'Add healthy carbs',
          'description':
              'Include more whole grains, fruits, and vegetables to fuel your activities and support recovery.',
            'type': 'nutrition',
            'priority': 'medium',
          'timestamp': DateTime.now(),
        });
      }

      // Balance recommendations
      final totalMacros = _cachedMacroBreakdown.protein + _cachedMacroBreakdown.carbs + _cachedMacroBreakdown.fat;
      if (totalMacros > 0) {
        final proteinPercent = (_cachedMacroBreakdown.protein / totalMacros) * 100;
        final carbsPercent = (_cachedMacroBreakdown.carbs / totalMacros) * 100;
        final fatPercent = (_cachedMacroBreakdown.fat / totalMacros) * 100;

        if (proteinPercent < 15 || proteinPercent > 40) {
          recommendations.add({
            'title': 'Balance your macros',
            'description':
                'Your protein is ${proteinPercent.toStringAsFixed(0)}% of total macros. Aim for 20-30% protein, 40-50% carbs, and 20-30% fat for optimal nutrition.',
            'type': 'nutrition',
            'priority': 'medium',
            'timestamp': DateTime.now(),
          });
        }
      }

      // Consistency recommendations
      if (_cachedDailySummaries.length >= 7) {
        final goalMetDays = _cachedDailySummaries
            .where((day) => day.caloriesConsumed >= day.caloriesGoal * 0.9 && 
                           day.caloriesConsumed <= day.caloriesGoal * 1.1)
            .length;
        
        if (goalMetDays < 3) {
          recommendations.add({
            'title': 'Improve consistency',
            'description':
                'You met your calorie goal $goalMetDays/7 days this week. Consistency is key to achieving your goals!',
            'type': 'activity',
            'priority': 'medium',
            'timestamp': DateTime.now(),
          });
        } else if (goalMetDays >= 5) {
          recommendations.add({
            'title': 'Great consistency!',
            'description':
                'Excellent work! You\'ve been consistent with your goals $goalMetDays/7 days this week. Keep it up!',
            'type': 'general',
            'priority': 'low',
            'timestamp': DateTime.now(),
          });
        }
      }

      // Profile-based recommendations
      if (profile != null) {
        final age = profile['age'] as int?;
        final gender = profile['gender'] as String?;
        final height = profile['height'] as double?;
        final weight = profile['weight'] as double?;

        if (age != null && gender != null && height != null && weight != null) {
          final bmi = weight / (height * height);
          if (bmi < 18.5) {
            recommendations.add({
              'title': 'Focus on healthy weight gain',
              'description':
                  'Based on your profile (BMI: ${bmi.toStringAsFixed(1)}), consider increasing calorie intake with nutrient-dense foods and strength training.',
              'type': 'nutrition',
              'priority': 'high',
              'timestamp': DateTime.now(),
            });
          } else if (bmi > 25) {
            recommendations.add({
              'title': 'Focus on sustainable weight management',
              'description':
                  'Based on your profile (BMI: ${bmi.toStringAsFixed(1)}), maintain a moderate calorie deficit through balanced nutrition and regular activity.',
              'type': 'nutrition',
              'priority': 'high',
              'timestamp': DateTime.now(),
            });
          }
        }
      }

      // Sort by priority (high -> medium -> low)
      final priorityOrder = {'high': 1, 'medium': 2, 'low': 3};
      recommendations.sort((a, b) {
        final aPriority = priorityOrder[a['priority']] ?? 4;
        final bPriority = priorityOrder[b['priority']] ?? 4;
        return aPriority.compareTo(bPriority);
      });

      // Limit to top 5 recommendations
      final finalRecommendations = recommendations.take(5).toList();

      _cachedRecommendations = finalRecommendations;
      try {
        if (!_ensureRecommendationsController.isClosed) {
          _ensureRecommendationsController.add(finalRecommendations);
          _logger.info('Generated personalized recommendations', {'count': finalRecommendations.length});
        }
      } catch (e) {
        _logger.error('Error broadcasting recommendations', {'error': e.toString()});
      }
    } catch (e) {
      _logger.error('Error generating recommendations', {'error': e.toString()});
      // Return empty list on error
      _cachedRecommendations = [];
      try {
        if (!_ensureRecommendationsController.isClosed) {
          _ensureRecommendationsController.add([]);
        }
      } catch (e2) {
        _logger.error('Error broadcasting empty recommendations', {'error': e2.toString()});
      }
    }
  }

  /// Get cached data for immediate access
  List<DailySummary> get cachedDailySummaries => _cachedDailySummaries;
  MacroBreakdown get cachedMacroBreakdown => _cachedMacroBreakdown;
  List<UserAchievement> get cachedAchievements => _cachedAchievements;
  List<Map<String, dynamic>> get cachedInsights => _cachedInsights;
  List<Map<String, dynamic>> get cachedRecommendations =>
      _cachedRecommendations;

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
      final summaries =
          await _firebaseService.getDailySummaries(userId, days: 30);

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
    final totalCaloriesConsumed =
        summaries.fold(0, (sum, s) => sum + s.caloriesConsumed);
    final totalSteps = summaries.fold(0, (sum, s) => sum + s.steps);
    final totalWaterGlasses =
        summaries.fold(0, (sum, s) => sum + s.waterGlasses);
    final daysWithFoodLogged =
        summaries.where((s) => s.caloriesConsumed > 0).length;
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
  Future<void> _saveStreaksAndAchievements(String userId,
      Map<String, int> streaks, List<UserAchievement> achievements) async {
    try {
      final batch = _firestore.batch();

      // Save streaks
      final streaksRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc('streaks');
      batch.set(streaksRef, {
        'streaks': streaks,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Save achievements
      final achievementsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc('achievements');
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
          .collection('dailySummary')
          .doc('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')
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
          .collection('dailySummary')
          .doc('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')
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

  /// Get actual exercise minutes for a specific date
  Future<int> _getActualExerciseMinutes(String userId, DateTime date) async {
    try {
      final summaryDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .doc('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')
          .get();

      if (summaryDoc.exists) {
        final data = summaryDoc.data()!;
        return (data['exerciseMinutes'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting actual exercise minutes: $e');
      return 0;
    }
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

  /// Clean up old dailySummary data (older than 7 days) to save space
  Future<void> _cleanupOldDailySummaryData(String userId) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 7));
      
      // Get all dailySummary documents
      final allSummaries = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailySummary')
          .get();

      final batch = _firestore.batch();
      int deletedCount = 0;

      for (final doc in allSummaries.docs) {
        try {
          final data = doc.data();
          final dateValue = data['date'];
          
          DateTime? summaryDate;
          if (dateValue is Timestamp) {
            summaryDate = dateValue.toDate();
          } else if (dateValue is DateTime) {
            summaryDate = dateValue;
          } else {
            // Try to parse from document ID (format: YYYY-MM-DD)
            try {
              final parts = doc.id.split('-');
              if (parts.length == 3) {
                summaryDate = DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                );
              }
            } catch (_) {
              // Skip if can't parse
              continue;
            }
          }

          // Delete if older than 7 days
          if (summaryDate != null && summaryDate.isBefore(cutoffDate)) {
            batch.delete(doc.reference);
            deletedCount++;
          }
        } catch (e) {
          print('Error processing summary document ${doc.id}: $e');
          // Continue with other documents
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
      _logger.info('Cleaned up old dailySummary documents', {'deleted': deletedCount});
      }
    } catch (e) {
      _logger.error('Error cleaning up old dailySummary data', {'error': e.toString()});
      // Don't throw - cleanup failure shouldn't break analytics
    }
  }

  /// Dispose resources
  /// Clean up resources (but don't close controllers for singleton)
  Future<void> cleanup() async {
    try {
      _logger.debug('Cleaning up analytics service...');
      await _cancelExistingListeners();
      _logger.debug('Analytics service cleaned up');
    } catch (e) {
      _logger.error('Error during analytics cleanup', {'error': e.toString()});
    }
  }

  /// Dispose method for singleton - only cancel listeners, don't close controllers
  void dispose() {
    _logger.debug('Analytics service dispose called - cleaning up listeners only');
    cleanup();
    // Don't close controllers since this is a singleton that may be reused
  }
}
