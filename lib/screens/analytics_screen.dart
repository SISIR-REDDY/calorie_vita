import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_colors.dart';
import '../services/analytics_service.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import '../services/app_state_service.dart';
import '../services/google_fit_service.dart';
import '../services/global_google_fit_manager.dart';
import '../services/unified_google_fit_manager.dart';
import '../services/todays_food_data_service.dart';
import '../mixins/google_fit_sync_mixin.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import '../models/user_goals.dart';
import '../models/google_fit_data.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with
        TickerProviderStateMixin,
        GoogleFitSyncMixin,
        GoogleFitDataDisplayMixin {
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly'];

  // Services
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseService _firebaseService = FirebaseService();
  final AppStateService _appStateService = AppStateService();
  final GoogleFitService _googleFitService = GoogleFitService();
  final GlobalGoogleFitManager _googleFitManager = GlobalGoogleFitManager();
  final UnifiedGoogleFitManager _unifiedGoogleFitManager = UnifiedGoogleFitManager();
  final TodaysFoodDataService _todaysFoodDataService = TodaysFoodDataService();

  // State management
  bool _isLoading = false; // Start with false to show UI immediately
  bool _isRefreshing = false;
  String? _error;
  bool _isGeneratingInsights = false;
  String _aiInsights = '';
  

  // UI update debouncing
  Timer? _uiUpdateTimer;
  Timer? _profileUpdateTimer;
  bool _hasPendingUIUpdate = false;
  static const Duration _minUIUpdateInterval = Duration(milliseconds: 300);

  // Stream subscriptions
  StreamSubscription<Map<String, dynamic>?>? _profileDataSubscription;
  StreamSubscription<Map<String, dynamic>>? _fastMacroBreakdownSubscription;
  StreamSubscription<UserGoals?>? _goalsSubscription;
  StreamSubscription<Map<String, double>>? _todaysFoodMacroSubscription;
  StreamSubscription<int>? _todaysFoodCaloriesSubscription;
  StreamSubscription<GoogleFitData?>? _unifiedGoogleFitSubscription;
  StreamSubscription<bool>? _unifiedGoogleFitConnectionSubscription;
  StreamSubscription<bool>? _unifiedGoogleFitLoadingSubscription;

  // Real-time data
  List<DailySummary> _dailySummaries = [];
  MacroBreakdown _macroBreakdown =
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
  List<UserAchievement> _achievements = [];
  List<Map<String, dynamic>> _insights = [];
  List<Map<String, dynamic>> _recommendations = [];

  // Google Fit data - Optimized for steps, calories, and workouts only
  GoogleFitData _todayGoogleFitData = GoogleFitData(
    date: DateTime.now(),
    steps: 0,
    caloriesBurned: 0.0,
    workoutSessions: 0,
    workoutDuration: 0.0,
  );
  List<GoogleFitData> _weeklyGoogleFitData = [];
  bool _isGoogleFitConnected = false;
  bool _isGoogleFitLoading = false; // Track loading state for Google Fit

  // User profile data for BMI calculation
  double? _userHeight; // in meters
  double? _userWeight; // in kg
  String? _userGender;
  int? _userAge;

  @override
  void initState() {
    super.initState();
    
    // Load cached data first to prevent UI lag
    _loadCachedAnalyticsData();
    
    // Initialize services asynchronously
    _setupTodaysFoodDataService();
    _initializeGoogleFitData();
    
    // Ensure profile data is loaded for weight progress and BMI
    _loadUserProfileData();
  }

  @override
  void dispose() {
    _profileDataSubscription?.cancel();
    _fastMacroBreakdownSubscription?.cancel();
    _goalsSubscription?.cancel();
    _todaysFoodMacroSubscription?.cancel();
    _todaysFoodCaloriesSubscription?.cancel();
    _uiUpdateTimer?.cancel();
    _profileUpdateTimer?.cancel();
    _analyticsService.dispose();
    _todaysFoodDataService.dispose();
    
    super.dispose();
  }

  /// Debounce UI updates to prevent flickering
  void _debounceUIUpdate(VoidCallback updateCallback) {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer(_minUIUpdateInterval, () {
      if (mounted && !_hasPendingUIUpdate) {
        _hasPendingUIUpdate = true;
        updateCallback();
        _hasPendingUIUpdate = false;
      }
    });
  }





  /// Initialize unified Google Fit manager for analytics
  Future<void> _initializeUnifiedGoogleFit() async {
    try {
      await _unifiedGoogleFitManager.initialize();
      
      // Load current data immediately to prevent zero display
      final currentData = _unifiedGoogleFitManager.getCurrentData();
      if (currentData != null && mounted) {
        setState(() {
          _todayGoogleFitData = currentData;
        });
      }
      
      // Listen to unified Google Fit data stream with debouncing
      _unifiedGoogleFitSubscription = _unifiedGoogleFitManager.dataStream.listen((data) {
        if (mounted && data != null) {
          // Use debounced update to prevent UI flickering
          _debounceUIUpdate(() {
            setState(() {
              _todayGoogleFitData = data;
            });
          });
        }
      });
      
      // Listen to connection status
      _unifiedGoogleFitConnectionSubscription = _unifiedGoogleFitManager.connectionStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isGoogleFitConnected = isConnected;
          });
        }
      });
      
      // Listen to loading status
      _unifiedGoogleFitLoadingSubscription = _unifiedGoogleFitManager.loadingStream.listen((isLoading) {
        if (mounted) {
          setState(() {
            _isGoogleFitLoading = isLoading;
          });
        }
      });
      
    } catch (e) {
    }
  }

  /// Override mixin method to handle Google Fit data updates
  @override
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    super.onGoogleFitDataUpdate(syncData);

    final todayData = syncDataToGoogleFitData(syncData);
    if (todayData != null && mounted) {
      setState(() {
        _todayGoogleFitData = todayData;
      });
    }
  }

  /// Override mixin method to handle Google Fit connection changes
  @override
  void onGoogleFitConnectionChanged(bool isConnected) {
    super.onGoogleFitConnectionChanged(isConnected);

    if (mounted) {
      setState(() {
        _isGoogleFitConnected = isConnected;
      });

      if (isConnected) {
        _loadGoogleFitData();
      }
    }
  }

  /// Initialize real-time analytics (optimized for instant UI display)
  Future<void> _initializeAnalytics() async {
    try {
      setState(() {
        _error = null;
      });


      // Show default data immediately
      _showDefaultDataImmediate();

      // Set up listeners first (fastest operation)
      _setupRealTimeListeners();

      // Load fresh data in background without blocking UI
      _loadFreshAnalyticsData();
    } catch (e) {
      setState(() {
        _error = '⚠️ Loading error. Tap to retry.';
      });
    }
  }

  /// Show default data immediately for instant UI display
  void _showDefaultDataImmediate() {
    try {
      // Load default data immediately (0ms delay)
      
      // 1. Load default daily summaries
      if (_dailySummaries.isEmpty) {
        _dailySummaries = _generateDefaultSummaries();
      }

      // 2. Load default macro breakdown
      if (_macroBreakdown.totalCalories == 0) {
        _macroBreakdown =
            MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
      }

      // 3. Load default Google Fit data immediately
      _todayGoogleFitData ??= GoogleFitData(
        date: DateTime.now(),
        steps: 0,
        caloriesBurned: 0.0,
        workoutSessions: 0,
        workoutDuration: 0.0,
      );
      _weeklyGoogleFitData = _weeklyGoogleFitData.isEmpty
          ? _generateDefaultWeeklyGoogleFitData()
          : _weeklyGoogleFitData;

    } catch (e) {
    }
  }

  /// Generate default summaries to show immediate UI
  List<DailySummary> _generateDefaultSummaries() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      return DailySummary(
        caloriesConsumed: 0,
        caloriesBurned: 0,
        caloriesGoal: 2000,
        steps: 0,
        stepsGoal: 10000,
        waterGlasses: 0,
        waterGlassesGoal: 8,
        date: now.subtract(Duration(days: 6 - index)),
      );
    });
  }

  /// Generate default weekly Google Fit data - Optimized for workouts
  List<GoogleFitData> _generateDefaultWeeklyGoogleFitData() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      return GoogleFitData(
        date: now.subtract(Duration(days: 6 - index)),
        steps: 0,
        caloriesBurned: 0.0,
        workoutSessions: 0,
        workoutDuration: 0.0,
      );
    });
  }

  /// Load fresh analytics data in background
  Future<void> _loadFreshAnalyticsData() async {
    setState(() => _isRefreshing = true);

    try {

      // Initialize services with short timeouts (non-blocking)
      await Future.wait([
        _initializeAppStateService(),
        _initializeAnalyticsService(),
        _loadUserProfileData(), // Load user profile data for BMI calculation
      ]).timeout(const Duration(seconds: 4));

      // Load Google Fit data in background (lowest priority)
      _loadGoogleFitDataAsync();

      // Generate AI insights after data is loaded
      _generateAIInsights();
    } catch (e) {
      // Don't show error to user, just log it
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// Initialize app state service with timeout
  Future<void> _initializeAppStateService() async {
    try {
      if (!_appStateService.isInitialized) {
        await _appStateService.initialize().timeout(const Duration(seconds: 3),
            onTimeout: () => null);
      }
    } catch (e) {
    }
  }

  /// Initialize analytics service with timeout
  Future<void> _initializeAnalyticsService() async {
    try {
      final days = _getDaysForPeriod(_selectedPeriod);
      await _analyticsService.initializeRealTimeAnalytics(days: days).timeout(
          const Duration(seconds: 4),
          onTimeout: () => null);
    } catch (e) {
    }
  }

  /// Load Google Fit data asynchronously (lowest priority)
  Future<void> _loadGoogleFitDataAsync() async {
    try {
      // Load Google Fit data in background
      _loadGoogleFitData()
          .timeout(const Duration(seconds: 3),
              onTimeout: () => null)
          .catchError((e) => null);
    } catch (e) {
    }
  }

  /// Load additional data in background
  Future<void> _loadBackgroundData() async {
    try {
      // Load Google Fit data asynchronously (non-blocking)
      _loadGoogleFitDataAsync();

      // Calculate achievements in background (non-blocking)
      _analyticsService.calculateStreaksAndAchievements();
    } catch (e) {
      // Don't show error to user as this is background loading
    }
  }

  /// Set up real-time listeners
  void _setupRealTimeListeners() {
    try {
      // Listen to daily summaries with error handling
      _analyticsService.dailySummariesStream.listen((summaries) {
        if (mounted) {
          setState(() {
            _dailySummaries = summaries;
          });
        }
      }).onError((error) => print('Daily summaries stream error: $error'));

      // Note: Macro breakdown is handled by TodaysFoodDataService for real-time updates

      // Listen to achievements with error handling
      _analyticsService.achievementsStream.listen((achievements) {
        if (mounted) {
          setState(() {
            _achievements = achievements;
          });
        }
      }).onError((error) => print('Achievements stream error: $error'));

      // Listen to profile data changes (for BMI updates)
      _profileDataSubscription?.cancel();
      _profileDataSubscription =
          _appStateService.profileDataStream.listen((profileData) {
        print('Profile data stream received in analytics: $profileData');
        if (mounted && profileData != null) {
          // Only update if there are actual changes to avoid unnecessary rebuilds
          final heightCm = profileData['height']?.toDouble();
          final newHeight = heightCm != null ? heightCm / 100.0 : null;
          final newGender = profileData['gender']?.toString();
          final newAge = profileData['age']?.toInt();
          
          // Check if values actually changed before calling setState
          if (_userHeight != newHeight || _userGender != newGender || _userAge != newAge) {
            // Debounce the update to prevent excessive rebuilds
            _profileUpdateTimer?.cancel();
            _profileUpdateTimer = Timer(Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  _userHeight = newHeight;
                  _userGender = newGender;
                  _userAge = newAge;
                });
                print('Profile data updated in analytics: Height=${_userHeight}m');
                print('BMI will be recalculated with new values');
              }
            });
          }
        } else {
          print('Profile data is null or widget not mounted');
        }
      });

      // Listen to goals changes (for macro goals updates)
      _goalsSubscription?.cancel();
      _goalsSubscription = _appStateService.goalsStream.listen(
        (goals) {
          print('Goals stream received in analytics: ${goals?.toMap()}');
          if (mounted) {
            setState(() {
              // This will trigger UI rebuild with updated macro goals
            });
          }
        },
        onError: (error) => print('Goals stream error: $error'),
      );

      // Listen to Google Fit weight changes for BMI
      _googleFitService.liveDataStream?.listen((liveData) {
        if (mounted && liveData['weight'] != null) {
          setState(() {
            _userWeight = liveData['weight']?.toDouble();
          });
          print('BMI updated from Google Fit weight: ${liveData['weight']}');
        }
      });

      // Listen to insights
      _analyticsService.insightsStream.listen((insights) {
        if (mounted) {
          setState(() {
            _insights = insights;
          });
        }
      });

      // Listen to recommendations
      _analyticsService.recommendationsStream.listen((recommendations) {
        if (mounted) {
          setState(() {
            _recommendations = recommendations;
          });
        }
      });
    } catch (e) {
      print('Error setting up real-time listeners: $e');
    }
  }

  /// Load cached analytics data immediately to prevent UI lag
  void _loadCachedAnalyticsData() {
    try {
      // Set default values to prevent null errors
      _dailySummaries = [];
      _achievements = [];
      _insights = [];
      _recommendations = [];
      
      // Set loading states
      _isLoading = false;
      _isRefreshing = false;
      _isGeneratingInsights = false;
      
      debugPrint('📊 Loaded cached analytics data');
    } catch (e) {
      debugPrint('❌ Error loading cached analytics data: $e');
    }
  }

  /// Initialize Google Fit data with better error handling
  Future<void> _initializeGoogleFitData() async {
    try {
      // Data is already initialized with default values
      // Trigger UI update
      if (mounted) {
        setState(() {});
      }
      
      // Try to load real data in background
      _loadGoogleFitData().catchError((error) {
        // Keep default data if loading fails
      });
    } catch (e) {
      // Keep default data if initialization fails
    }
  }

  /// Setup today's food data service for immediate updates
  Future<void> _setupTodaysFoodDataService() async {
    try {
      // Initialize service in background (non-blocking)
      _todaysFoodDataService.initialize().then((_) {
        print('✅ Analytics: Food data service initialized');
      }).catchError((e) {
        print('❌ Analytics: Food data service init error: $e');
      });
      
      // Listen to consumed calories stream (same data as TodaysFoodScreen)
      _todaysFoodCaloriesSubscription = _todaysFoodDataService.consumedCaloriesStream.listen((calories) {
        if (mounted) {
          // Update the daily summaries with consumed calories from today's food
          setState(() {
            if (_dailySummaries.isNotEmpty) {
              // Update today's summary with consumed calories from food entries
              final todaySummary = _dailySummaries.last;
              _dailySummaries[_dailySummaries.length - 1] = todaySummary.copyWith(
                caloriesConsumed: calories,
              );
            }
          });
          print('✅ Analytics: Consumed calories updated from TodaysFoodDataService: $calories');
        }
      });
      
      // Listen to macro nutrients stream (same data as TodaysFoodScreen)
      _todaysFoodMacroSubscription = _todaysFoodDataService.macroNutrientsStream.listen((macros) {
        if (mounted) {
          setState(() {
            _macroBreakdown = MacroBreakdown(
              protein: macros['protein'] ?? 0.0,
              carbs: macros['carbs'] ?? 0.0,
              fat: macros['fat'] ?? 0.0,
              fiber: macros['fiber'] ?? 0.0,
              sugar: macros['sugar'] ?? 0.0,
            );
          });
          print('✅ Analytics: Macro breakdown updated from TodaysFoodDataService');
          print('   Protein: ${macros['protein'] ?? 0.0}g, Carbs: ${macros['carbs'] ?? 0.0}g, Fat: ${macros['fat'] ?? 0.0}g');
        }
      });
      
      print('✅ Today\'s food data service initialized for analytics');
    } catch (e) {
      print('❌ Error initializing today\'s food data service for analytics: $e');
    }
  }

  /// Get number of days for selected period
  int _getDaysForPeriod(String period) {
    switch (period) {
      case 'Daily':
        return 1;
      case 'Weekly':
        return 7;
      default:
        return 7;
    }
  }

  /// Load Google Fit data using optimized workout service - Fastest method
  Future<void> _loadGoogleFitData() async {
    try {
      setState(() {
        _isGoogleFitLoading = true;
      });
      
      // Check authentication with network timeout
      final isAuthenticated = await _googleFitService
          .validateAuthentication()
          .timeout(const Duration(seconds: 2), onTimeout: () {
        print('Google Fit authentication check timed out');
        return false;
      });
      
      setState(() {
        _isGoogleFitConnected = isAuthenticated;
      });
      
      if (_isGoogleFitConnected) {
        try {
          // Use live Google Fit data
          final todayData = await _unifiedGoogleFitManager.getLiveData();
          
          if (todayData != null) {
            setState(() {
              _todayGoogleFitData = todayData;
              _isGoogleFitLoading = false;
            });
            
            print('✅ Analytics: Google Fit live data loaded: ${_todayGoogleFitData?.steps} steps, ${_todayGoogleFitData?.caloriesBurned} calories, ${_todayGoogleFitData?.workoutSessions} workouts');
          } else {
            print('⚠️ Analytics: Google Fit live data is null, trying fallback...');
            // Fallback to original service
            await _loadGoogleFitDataFallback();
          }
          
          // Load weekly data in background
          _loadWeeklyGoogleFitData(forceRefresh: false).catchError((error) {
            print('Weekly Google Fit data loading failed: $error');
          });
        } catch (dataError) {
          print('Error loading optimized workout data: $dataError');
          await _loadGoogleFitDataFallback();
        }
      } else {
        // Network not available, try cached data
        print('⚠️ Analytics: No Google Fit connection, trying cached data...');
        await _loadCachedGoogleFitData();
      }
    } catch (e) {
      print('Error in Google Fit data loading: $e');
      // Try cached data as last resort
      await _loadCachedGoogleFitData();
    }
  }

  /// Load cached Google Fit data when network is unavailable
  Future<void> _loadCachedGoogleFitData() async {
    try {
      // Try to get cached data from SharedPreferences or local storage
      // For now, we'll use default values but this could be enhanced
      final cachedData = GoogleFitData(
        date: DateTime.now(),
        steps: 0, // Could be loaded from cache
        caloriesBurned: 0.0, // Could be loaded from cache
        workoutSessions: 0, // Could be loaded from cache
        workoutDuration: 0.0,
      );
      
      setState(() {
        _todayGoogleFitData = cachedData;
        _isGoogleFitLoading = false;
        _isGoogleFitConnected = false; // Mark as offline
      });
      
      print('📱 Analytics: Using cached Google Fit data (offline mode)');
    } catch (e) {
      print('❌ Analytics: Error loading cached data: $e');
    }
  }
  Future<void> _loadGoogleFitDataFallback() async {
    try {
      final today = DateTime.now();
      final batchData = await _googleFitService
          .getTodayFitnessDataBatch()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      
      GoogleFitData todayData;
      if (batchData != null) {
        todayData = GoogleFitData(
          date: today,
          steps: batchData['steps'] as int? ?? 0,
          caloriesBurned: batchData['caloriesBurned'] as double? ?? 0.0,
          workoutSessions: batchData['workoutSessions'] as int? ?? 0,
          workoutDuration: (batchData['workoutDuration'] as num?)?.toDouble() ?? 0.0,
        );
      } else {
        final futures = await Future.wait([
          _googleFitService
              .getDailySteps(today)
              .timeout(const Duration(seconds: 3), onTimeout: () => 0),
          _googleFitService
              .getDailyCaloriesBurned(today)
              .timeout(const Duration(seconds: 3), onTimeout: () => 0.0),
          _googleFitService
              .getWorkoutSessions(today)
              .timeout(const Duration(seconds: 3), onTimeout: () => 0),
        ]);
        todayData = GoogleFitData(
          date: today,
          steps: futures[0] as int? ?? 0,
          caloriesBurned: futures[1] as double? ?? 0.0,
          workoutSessions: futures[2] as int? ?? 0,
          workoutDuration: 0.0,
        );
      }
      
      setState(() {
        _todayGoogleFitData = todayData;
        _isGoogleFitLoading = false;
      });
      
      print('Google Fit today data loaded (fallback): ${_todayGoogleFitData?.steps} steps');
    } catch (dataError) {
      print('Error loading Google Fit data fallback: $dataError');
      setState(() {
        _todayGoogleFitData = GoogleFitData(
          date: DateTime.now(),
          steps: 0,
          caloriesBurned: 0.0,
          workoutSessions: 0,
          workoutDuration: 0.0,
        );
        _isGoogleFitLoading = false;
      });
    }
  }

  /// Load weekly Google Fit data for analytics (optimized for speed with force refresh)
  Future<void> _loadWeeklyGoogleFitData({bool forceRefresh = false}) async {
    try {
      if (_isGoogleFitConnected) {
        print('🔄 Analytics: Loading weekly Google Fit data (forceRefresh: $forceRefresh)');
        
        // Load weekly data in parallel for faster response
        final now = DateTime.now();
        final weeklyData = <GoogleFitData>[];
        final futures = <Future>[];

        // Load data for each day of the week in parallel
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          futures.add(_loadSingleDayGoogleFitData(date, weeklyData, forceRefresh: forceRefresh));
        }

        await Future.wait(futures);

        if (mounted) {
          setState(() {
            _weeklyGoogleFitData = weeklyData;
          });
        }
        
        final totalSteps = weeklyData.fold<int>(0, (sum, data) => sum + (data.steps ?? 0));
        final totalCalories = weeklyData.fold<double>(0, (sum, data) => sum + (data.caloriesBurned ?? 0));
        final totalWorkouts = weeklyData.fold<int>(0, (sum, data) => sum + (data.workoutSessions ?? 0));
        
        print('✅ Analytics: Loaded ${_weeklyGoogleFitData.length} days of Google Fit data - Total: $totalSteps steps, $totalCalories calories, $totalWorkouts workouts');
      }
    } catch (e) {
      print('❌ Error loading weekly Google Fit data: $e');
    }
  }

  /// Load single day Google Fit data (helper method for parallel loading with force refresh)
  Future<void> _loadSingleDayGoogleFitData(
      DateTime date, List<GoogleFitData> weeklyData, {bool forceRefresh = false}) async {
    try {
      final futures = await Future.wait([
        _googleFitService.getDailySteps(date),
        _googleFitService.getDailyCaloriesBurned(date),
        _googleFitService.getWorkoutSessions(date),
      ]);

      final steps = futures[0] as int? ?? 0;
      final calories = futures[1] as double? ?? 0.0;
      final workoutSessions = futures[2] as int? ?? 0;

      weeklyData.add(GoogleFitData(
        date: date,
        steps: steps,
        caloriesBurned: calories,
        workoutSessions: workoutSessions,
        workoutDuration: 0.0,
      ));
      
      if (forceRefresh) {
        print('🔄 Analytics: Refreshed data for ${date.toIso8601String().split('T')[0]} - Steps: $steps, Calories: $calories, Workouts: $workoutSessions');
      }
    } catch (e) {
      // Add empty data if loading fails
      weeklyData.add(GoogleFitData(
        date: date,
        steps: 0,
        caloriesBurned: 0,
        workoutSessions: 0,
        workoutDuration: 0.0,
      ));
      
      if (forceRefresh) {
        print('⚠️ Analytics: Failed to refresh data for ${date.toIso8601String().split('T')[0]}: $e');
      }
    }
  }

  /// Refresh analytics data when period changes (optimized)
  Future<void> _refreshAnalyticsForPeriod() async {
    try {
      setState(() {
        _isRefreshing = true;
      });

      // Only reload Google Fit data if connected
      if (_isGoogleFitConnected) {
        await _loadGoogleFitData();
      }

      // Reload analytics service with new period (cached when possible)
      final days = _getDaysForPeriod(_selectedPeriod);
      await _analyticsService.updatePeriod(days);

      // Batch state updates
      setState(() {
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _isRefreshing = false;
        _error = 'Failed to refresh analytics: ${e.toString()}';
      });
    }
  }

  /// Setup Google Fit live stream for real-time updates (optimized for speed)
  void _setupGoogleFitLiveStream() {
    _googleFitService.liveDataStream?.listen((liveData) {
      if (mounted && liveData['isLive'] == true) {
        // Immediate update for faster response
        final newSteps = liveData['steps'];
        final newCalories = liveData['caloriesBurned'];
        final newDistance = liveData['distance'];

        // Update today's data with live data immediately
        if (_todayGoogleFitData != null) {
          final updatedData = GoogleFitData(
            date: _todayGoogleFitData!.date,
            steps: newSteps ?? _todayGoogleFitData!.steps,
            caloriesBurned: newCalories ?? _todayGoogleFitData!.caloriesBurned,
            workoutSessions: _todayGoogleFitData!.workoutSessions,
            workoutDuration: _todayGoogleFitData!.workoutDuration,
          );

          // Only update if data has actually changed
          if (updatedData.steps != _todayGoogleFitData!.steps ||
              updatedData.caloriesBurned !=
                  _todayGoogleFitData!.caloriesBurned ||
              updatedData.workoutSessions != _todayGoogleFitData!.workoutSessions ||
              updatedData.workoutDuration != _todayGoogleFitData!.workoutDuration) {
            setState(() {
              _todayGoogleFitData = updatedData;
            });
          }
        }
      }
    });
  }

  /// Load user profile data for BMI calculation
  Future<void> _loadUserProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('profile')
            .doc('userData')
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          print('Profile Data Loaded: $data');
          
          // Height is stored in cm, convert to meters for BMI calculation
          final heightCm = data['height']?.toDouble();
          final weight = data['weight']?.toDouble();
          final gender = data['gender']?.toString();
          final age = data['age']?.toInt();
          
          if (mounted) {
            setState(() {
              _userHeight = heightCm != null ? heightCm / 100.0 : null;
              _userWeight = weight;
              _userGender = gender;
              _userAge = age;
            });
          }
          
          print('Parsed Profile Data - Height: $_userHeight, Weight: $_userWeight, Gender: $_userGender, Age: $_userAge');
        } else {
          print('Profile document does not exist');
          if (mounted) {
            setState(() {
              _userHeight = null;
              _userWeight = null;
              _userGender = null;
              _userAge = null;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user profile data: $e');
      // Don't set default values - let user input their data
      if (mounted) {
        setState(() {
          _userHeight = null;
          _userWeight = null;
          _userGender = null;
          _userAge = null;
        });
      }
    }
  }

  /// Calculate percentage change for metrics (no hardcoded values)
  String _calculatePercentageChange(String metric) {
    if (_dailySummaries.length < 2) return '0%';

    final currentPeriod =
        _dailySummaries.take(_getDaysForPeriod(_selectedPeriod));
    final previousPeriod = _dailySummaries
        .skip(_getDaysForPeriod(_selectedPeriod))
        .take(_getDaysForPeriod(_selectedPeriod));

    if (previousPeriod.isEmpty || currentPeriod.isEmpty) return '0%';

    double currentValue = 0;
    double previousValue = 0;

    switch (metric) {
      case 'calories':
        currentValue = currentPeriod
            .fold(0, (sum, s) => sum + s.caloriesConsumed)
            .toDouble();
        previousValue = previousPeriod
            .fold(0, (sum, s) => sum + s.caloriesConsumed)
            .toDouble();
        break;
      case 'steps':
        currentValue =
            currentPeriod.fold(0, (sum, s) => sum + s.steps).toDouble();
        previousValue =
            previousPeriod.fold(0, (sum, s) => sum + s.steps).toDouble();
        break;
    }

    if (previousValue == 0) return '0%';

    final change =
        ((currentValue - previousValue) / previousValue * 100).round();
    return change >= 0 ? '+$change%' : '$change%';
  }

  /// Calculate workout change (no hardcoded values)
  String _calculateWorkoutChange() {
    if (_dailySummaries.length < 2) return '0';

    final currentPeriod =
        _dailySummaries.take(_getDaysForPeriod(_selectedPeriod));
    final previousPeriod = _dailySummaries
        .skip(_getDaysForPeriod(_selectedPeriod))
        .take(_getDaysForPeriod(_selectedPeriod));

    if (previousPeriod.isEmpty || currentPeriod.isEmpty) return '0';

    final currentWorkouts =
        currentPeriod.where((s) => s.caloriesBurned > 0).length;
    final previousWorkouts =
        previousPeriod.where((s) => s.caloriesBurned > 0).length;

    final change = currentWorkouts - previousWorkouts;
    return change >= 0 ? '+$change' : '$change';
  }

  /// Refresh data for current period
  Future<void> _refreshData() async {
    if (_isRefreshing) {
      print('⚠️ Analytics: Refresh already in progress, skipping...');
      return;
    }

    print('🔄 Analytics: Starting data refresh...');
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      // Refresh all data in parallel for faster response
      final futures = <Future>[];

      // Refresh analytics data
      final days = _getDaysForPeriod(_selectedPeriod);
      futures.add(_analyticsService.updatePeriod(days));
      futures.add(_analyticsService.calculateStreaksAndAchievements());

      // Refresh Google Fit data if connected
      if (_isGoogleFitConnected) {
        print('🔄 Analytics: Refreshing Google Fit data for $_selectedPeriod view...');
        futures.add(_loadGoogleFitDataForPeriod(_selectedPeriod, forceRefresh: true));
      } else {
        print('⚠️ Analytics: Google Fit not connected, skipping Google Fit refresh');
      }

      // Refresh user profile data
      futures.add(_loadUserProfileData());

      // Wait for all refreshes to complete
      await Future.wait(futures);

      // Generate fresh AI insights after data refresh
      _generateAIInsights();

      print('✅ Analytics: Data refreshed successfully');
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh data: ${e.toString()}';
      });
      print('❌ Error refreshing analytics data: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
      print('🔄 Analytics: Refresh completed');
    }
  }

  /// Handle period change (optimized for speed)
  Future<void> _onPeriodChanged(String period) async {
    if (period == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = period;
    });

    try {
      // Only refresh Google Fit data for the new period
      if (_isGoogleFitConnected) {
        await _loadGoogleFitDataForPeriod(period, forceRefresh: true);
      }
    } catch (e) {
      print('Error refreshing data for period $period: $e');
    }
  }

  /// Load Google Fit data for specific period (optimized with force refresh)
  Future<void> _loadGoogleFitDataForPeriod(String period, {bool forceRefresh = false}) async {
    try {
      
      switch (period) {
        case 'Daily':
          // Use live Google Fit data
          GoogleFitData? todayData;
          
          if (forceRefresh) {
            // Force refresh from Google Fit API
            todayData = await _unifiedGoogleFitManager.forceRefresh();
            print('🔄 Analytics: Force refreshed today\'s data from Google Fit API');
          } else {
            // Use live data
            todayData = await _unifiedGoogleFitManager.getLiveData();
          }
          
          if (todayData != null) {
            setState(() {
              _todayGoogleFitData = todayData!;
            });
            print('✅ Analytics: Today\'s Google Fit data loaded: ${todayData.steps} steps, ${todayData.caloriesBurned} calories, ${todayData.workoutSessions} workouts');
          } else {
            print('⚠️ Analytics: No Google Fit data available for today');
          }
          break;

        case 'Weekly':
          // Load weekly data with force refresh if requested
          await _loadWeeklyGoogleFitData(forceRefresh: forceRefresh);
          break;
      }
    } catch (e) {
      print('❌ Error loading Google Fit data for period $period: $e');
    }
  }

  /// Generate AI insights based on current data
  Future<void> _generateAIInsights({bool forceRefresh = false}) async {
    if (_isGeneratingInsights) return;

    setState(() {
      _isGeneratingInsights = true;
    });

    try {

      // Fetch user profile data for comprehensive analysis
      final user = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? userProfile;
      if (user != null) {
        userProfile = await FirebaseService().getUserProfile(user.uid);
      }

      // Prepare comprehensive user data for AI analysis
      final userData = {
        // Profile data
        if (userProfile != null) ...userProfile,

        // Recent activity data
        'recent_calories': _dailySummaries
            .map((summary) => {
                  'date': summary.date.toIso8601String().split('T')[0],
                  'calories': summary.caloriesConsumed,
                })
            .toList(),
        'recent_steps': _dailySummaries
            .map((summary) => {
                  'date': summary.date.toIso8601String().split('T')[0],
                  'steps': summary.steps,
                })
            .toList(),

        // Macro breakdown
        'macro_breakdown': {
          'carbs': _macroBreakdown.carbs,
          'protein': _macroBreakdown.protein,
          'fat': _macroBreakdown.fat,
          'fiber': _macroBreakdown.fiber,
          'sugar': _macroBreakdown.sugar,
        },

        // Analysis period
        'period': _selectedPeriod,

        // Additional metrics
        'total_days_analyzed': _dailySummaries.length,
        'average_calories': _dailySummaries.isNotEmpty
            ? _dailySummaries
                    .map((s) => s.caloriesConsumed)
                    .reduce((a, b) => a + b) /
                _dailySummaries.length
            : 0,
        'average_steps': _dailySummaries.isNotEmpty
            ? _dailySummaries.map((s) => s.steps).reduce((a, b) => a + b) /
                _dailySummaries.length
            : 0,
      };

      print('Generating fresh AI insights for period: $_selectedPeriod');
      final insights = await AIService.getAnalyticsInsights(
        userData,
        currentFitnessData: _googleFitManager.currentFitnessData,
      );

      setState(() {
        _aiInsights = insights;
        _isGeneratingInsights = false;
      });
    } catch (e) {
      print('Error generating AI insights: $e');
      setState(() {
        _aiInsights = '⚠️ AI service unavailable, please try again later.';
        _isGeneratingInsights = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_isLoading && _dailySummaries.isEmpty)
            SliverFillRemaining(
              child: _buildLoadingState(),
            )
          else if (_error != null && _dailySummaries.isEmpty)
            SliverFillRemaining(
              child: _buildErrorState(),
            )
          else
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPeriodSelector(),
                      const SizedBox(height: 20),
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      _buildWeightProgressSection(),
                      const SizedBox(height: 24),
                      _buildMacroBreakdown(),
                      const SizedBox(height: 24),
                      _buildBMIAnalytics(),
                      const SizedBox(height: 24),
                      _buildAIInsights(),
                      const SizedBox(height: 24),
                      _buildPersonalizedRecommendations(),
                      const SizedBox(height: 100), // Bottom spacing
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
          ),
          SizedBox(height: 16),
          Text(
            'Loading analytics...',
            style: TextStyle(
              fontSize: 16,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading summary cards to prevent showing wrong data
  Widget _buildLoadingSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildLoadingSummaryCard('Calories', 'kcal'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLoadingSummaryCard('Steps', 'steps'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLoadingSummaryCard('Workouts', 'times'),
        ),
      ],
    );
  }

  /// Build individual loading summary card
  Widget _buildLoadingSummaryCard(String title, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 24,
            width: 60,
            decoration: BoxDecoration(
              color: kTextSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: SizedBox(
                height: 12,
                width: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(kTextSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: kTextSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load analytics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeAnalytics,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: kSurfaceColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: kPrimaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'calorie_logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Analytics 📊',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Track your health journey',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Live sync indicator
                      if (_isGoogleFitConnected &&
                          _googleFitService.isLiveSyncing)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.green),
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isGoogleFitConnected &&
                          _googleFitService.isLiveSyncing)
                        const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isRefreshing ? null : _refreshData,
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 20,
                              ),
                        tooltip: _isRefreshing ? 'Refreshing...' : 'Refresh data',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: _periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : kTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCards() {
    // Always show the summary cards with Google Fit data
    // The data should be available from initialization

    // Calculate real-time data with Google Fit integration based on selected period
    int totalCalories = 0;
    int totalSteps = 0;
    int totalWorkouts = 0;

    // Get data based on selected period
    switch (_selectedPeriod) {
      case 'Daily':
        // Use today's Google Fit data for instant data loading
        totalCalories = _todayGoogleFitData.caloriesBurned?.round() ?? 0;
        totalSteps = _todayGoogleFitData.steps ?? 0;
        totalWorkouts = _todayGoogleFitData.workoutSessions ?? 0;
        break;

      case 'Weekly':
        // Use actual Google Fit weekly data that's being loaded
        if (_weeklyGoogleFitData.isNotEmpty) {
          // Calculate totals from the weekly Google Fit data
          totalCalories = _weeklyGoogleFitData
              .fold(0, (sum, data) => sum + (data.caloriesBurned?.round() ?? 0));
          totalSteps = _weeklyGoogleFitData
              .fold(0, (sum, data) => sum + (data.steps ?? 0));
          totalWorkouts = _weeklyGoogleFitData
              .fold(0, (sum, data) => sum + (data.workoutSessions ?? 0));
        } else {
          // Fallback to today's data if weekly stats not available
          totalCalories = _todayGoogleFitData.caloriesBurned?.round() ?? 0;
          totalSteps = _todayGoogleFitData.steps ?? 0;
          totalWorkouts = _todayGoogleFitData.workoutSessions ?? 0;
        }
        break;
    }

    // Calculate actual changes (no hardcoded demo values)
    final caloriesChange = _calculatePercentageChange('calories');
    final stepsChange = _calculatePercentageChange('steps');
    final workoutsChange = _calculateWorkoutChange();


    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Calories',
            _formatNumber(totalCalories),
            'kcal',
            Icons.local_fire_department,
            kAccentColor,
            caloriesChange,
            kSuccessColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Steps',
            _formatNumber(totalSteps),
            'steps',
            Icons.directions_walk,
            kInfoColor,
            stepsChange,
            kSuccessColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Workouts',
            totalWorkouts.toString(),
            'sessions',
            Icons.fitness_center,
            kSecondaryColor,
            workoutsChange,
            kSuccessColor,
          ),
        ),
      ],
    );
  }

  /// Build weight progress section
  Widget _buildWeightProgressSection() {
    final userGoals = _appStateService.userGoals;
    final weightGoal = userGoals?.weightGoal;
    final currentWeight = _userWeight;
    
    // Debug logging
    print('=== WEIGHT PROGRESS SECTION DEBUG ===');
    print('Weight Progress Debug - AppStateService initialized: ${_appStateService.isInitialized}');
    print('Weight Progress Debug - userGoals from AppStateService: $userGoals');
    print('Weight Progress Debug - userGoals?.fitnessGoal: ${userGoals?.fitnessGoal}');
    print('Weight Progress Debug - userGoals?.fitnessGoal == null: ${userGoals?.fitnessGoal == null}');
    print('Weight Progress Debug - userGoals?.fitnessGoal == "": ${userGoals?.fitnessGoal == ""}');
    print('Weight Progress Debug - userGoals?.fitnessGoal?.isEmpty: ${userGoals?.fitnessGoal?.isEmpty}');
    print('Weight Progress Debug - Current Weight: $currentWeight, Weight Goal: $weightGoal');
    print('=== END WEIGHT PROGRESS SECTION DEBUG ===');
    
    // Check if we have both current weight and weight goal
    if (currentWeight == null || weightGoal == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: kPrimaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weight Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kWarningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kWarningColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: kWarningColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentWeight == null 
                          ? 'Weight data unavailable. Please update your profile in settings.'
                          : 'Set your weight goal in settings to track progress.',
                      style: TextStyle(
                        fontSize: 14,
                        color: kWarningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Calculate weight progress
    final weightDifference = currentWeight - weightGoal;
    final progressPercentage = _calculateWeightProgress(currentWeight, weightGoal);
    
    // Get user's fitness goal to determine success criteria
    String fitnessGoal = 'maintenance';
    
    if (userGoals != null) {
      fitnessGoal = userGoals!.fitnessGoal ?? 'maintenance';
      print('Weight Progress Debug - Using fitnessGoal from AppStateService: "$fitnessGoal"');
    } else {
      // Fallback: userGoals is null, use default
      print('Weight Progress Debug - userGoals is null from AppStateService, using default maintenance');
      fitnessGoal = 'maintenance';
    }
    
    // If fitnessGoal is still null or empty, try to get it from the profile data
    if (fitnessGoal == 'maintenance' && (userGoals?.fitnessGoal == null || userGoals?.fitnessGoal == '')) {
      print('Weight Progress Debug - fitnessGoal is null/empty, checking profile data...');
      // Try to get fitness goal from the profile data that's already loaded
      // The fitness goal might be in the profile data stream
      final profileData = _appStateService.profileData;
      if (profileData != null && profileData['fitnessGoal'] != null) {
        fitnessGoal = profileData['fitnessGoal'].toString();
        print('Weight Progress Debug - Loaded fitnessGoal from profile data: "$fitnessGoal"');
      } else {
        print('Weight Progress Debug - fitnessGoal not found in profile data, using maintenance');
      }
    }
    
    // Debug logging for fitness goal
    print('=== WEIGHT PROGRESS DEBUG START ===');
    print('Weight Progress Debug - userGoals object: $userGoals');
    if (userGoals != null) {
      print('Weight Progress Debug - userGoals.fitnessGoal: "${userGoals.fitnessGoal}"');
      print('Weight Progress Debug - userGoals.weightGoal: ${userGoals.weightGoal}');
      print('Weight Progress Debug - userGoals.calorieGoal: ${userGoals.calorieGoal}');
      print('Weight Progress Debug - userGoals.macroGoals: ${userGoals.macroGoals}');
      if (userGoals.macroGoals != null) {
        print('Weight Progress Debug - userGoals.macroGoals.proteinCalories: ${userGoals.macroGoals!.proteinCalories}');
        print('Weight Progress Debug - userGoals.macroGoals.carbsCalories: ${userGoals.macroGoals!.carbsCalories}');
        print('Weight Progress Debug - userGoals.macroGoals.fatCalories: ${userGoals.macroGoals!.fatCalories}');
      }
    } else {
      print('Weight Progress Debug - userGoals is NULL!');
    }
    print('Weight Progress Debug - Raw fitnessGoal: "$fitnessGoal"');
    print('Weight Progress Debug - fitnessGoal.toLowerCase(): "${fitnessGoal.toLowerCase()}"');
    print('Weight Progress Debug - fitnessGoal.length: ${fitnessGoal.length}');
    print('Weight Progress Debug - fitnessGoal.codeUnits: ${fitnessGoal.codeUnits}');
    
    // Test the fitness goal matching logic
    final testFitnessGoal = fitnessGoal.toLowerCase();
    print('Weight Progress Debug - Testing fitness goal matching:');
    print('  - "weight loss" match: ${testFitnessGoal == "weight loss"}');
    print('  - "weight_loss" match: ${testFitnessGoal == "weight_loss"}');
    print('  - "weight gain" match: ${testFitnessGoal == "weight gain"}');
    print('  - "weight_gain" match: ${testFitnessGoal == "weight_gain"}');
    print('  - "maintenance" match: ${testFitnessGoal == "maintenance"}');
    print('  - "general fitness" match: ${testFitnessGoal == "general fitness"}');
    print('  - "general_fitness" match: ${testFitnessGoal == "general_fitness"}');
    print('=== WEIGHT PROGRESS DEBUG END ===');
    
    // Determine if goal is achieved based on fitness goal
    bool isGoalAchieved = false;
    final fitnessGoalLower = fitnessGoal.toLowerCase();
    
    // Handle all possible fitness goal formats (underscore, space, title case, etc.)
    print('Weight Progress Debug - About to check fitness goal: "$fitnessGoalLower"');
    print('Weight Progress Debug - weightDifference: $weightDifference');
    
    // Normalize the fitness goal to handle all possible formats
    final normalizedGoal = fitnessGoalLower
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    
    print('Weight Progress Debug - Normalized fitness goal: "$normalizedGoal"');
    
    if (normalizedGoal == 'weight loss' || normalizedGoal == 'general fitness') {
      // Weight Loss + General Fitness: Success when current weight ≤ goal weight (losing weight)
      isGoalAchieved = weightDifference <= 0;
      print('Weight Progress Debug - Weight Loss/General Fitness: isGoalAchieved = $isGoalAchieved (weightDifference <= 0: ${weightDifference <= 0})');
    } else if (normalizedGoal == 'weight gain' || normalizedGoal == 'muscle building' || normalizedGoal == 'athletic performance') {
      // Weight Gain + Muscle Building + Athletic Performance: Success when current weight ≥ goal weight (gaining weight)
      isGoalAchieved = weightDifference >= 0;
      print('Weight Progress Debug - Weight Gain/Muscle Building/Athletic Performance: isGoalAchieved = $isGoalAchieved (weightDifference >= 0: ${weightDifference >= 0})');
    } else if (normalizedGoal == 'maintenance') {
      // Maintenance: Success when current weight is within 2kg of goal weight
      isGoalAchieved = weightDifference.abs() <= 2.0;
      print('Weight Progress Debug - Maintenance: isGoalAchieved = $isGoalAchieved (weightDifference.abs() <= 2.0: ${weightDifference.abs() <= 2.0})');
    } else {
      // Default to maintenance logic for unknown goals
      isGoalAchieved = weightDifference.abs() <= 2.0;
      print('Weight Progress Debug - Unknown goal "$normalizedGoal", using maintenance logic: isGoalAchieved = $isGoalAchieved');
    }
    
    // Debug logging for weight progress
    print('Weight Progress Calculation - Current: $currentWeight, Goal: $weightGoal, Difference: $weightDifference, Progress: $progressPercentage%, Fitness Goal: $fitnessGoal, Achieved: $isGoalAchieved');
    print('Weight Progress Debug - isGoalAchieved: $isGoalAchieved, weightDifference: $weightDifference, fitnessGoal: $fitnessGoal');
    print('Weight Progress Debug - weightDifference <= 0: ${weightDifference <= 0}, weightDifference >= 0: ${weightDifference >= 0}');
    
    // Determine progress color and status based on fitness goal
    Color progressColor;
    String progressStatus;
    IconData progressIcon;
    
    if (isGoalAchieved) {
      progressColor = kSuccessColor; // Green color for success
      progressStatus = 'Goal Achieved!';
      progressIcon = Icons.check_circle;
      print('Weight Progress Debug - Using GREEN color for achieved goal');
    } else {
      // Handle color determination based on fitness goal rules
      if (normalizedGoal == 'weight loss' || normalizedGoal == 'general fitness') {
        // Weight Loss + General Fitness: Orange when above goal, Blue when on track
        if (weightDifference > 0) {
          progressColor = kWarningColor; // Orange for above goal
          progressStatus = 'Above Goal';
          progressIcon = Icons.trending_up;
          print('Weight Progress Debug - Using ORANGE color for weight loss above goal');
        } else {
          progressColor = kInfoColor; // Blue for on track
          progressStatus = 'On Track';
          progressIcon = Icons.trending_down;
          print('Weight Progress Debug - Using BLUE color for weight loss on track');
        }
      } else if (normalizedGoal == 'weight gain' || normalizedGoal == 'muscle building' || normalizedGoal == 'athletic performance') {
        // Weight Gain + Muscle Building + Athletic Performance: Orange when below goal, Blue when on track
        if (weightDifference < 0) {
          progressColor = kWarningColor; // Orange for below goal
          progressStatus = 'Below Goal';
          progressIcon = Icons.trending_down;
          print('Weight Progress Debug - Using ORANGE color for weight gain below goal');
        } else {
          progressColor = kInfoColor; // Blue for on track
          progressStatus = 'On Track';
          progressIcon = Icons.trending_up;
          print('Weight Progress Debug - Using BLUE color for weight gain on track');
        }
      } else {
        // Maintenance or default case: Orange when off target, Green when within 2kg
        if (weightDifference.abs() > 2.0) {
          progressColor = kWarningColor; // Orange for off target
          progressStatus = 'Off Target';
          progressIcon = weightDifference > 0 ? Icons.trending_up : Icons.trending_down;
          print('Weight Progress Debug - Using ORANGE color for maintenance off target');
        } else {
          progressColor = kSuccessColor; // Green for maintenance success
          progressStatus = 'Goal Achieved!';
          progressIcon = Icons.check_circle;
          print('Weight Progress Debug - Using GREEN color for maintenance success');
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  progressIcon,
                  color: progressColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weight Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  progressStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Weight display with progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  progressColor.withValues(alpha: 0.1),
                  progressColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: progressColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Current weight vs goal weight
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildWeightDisplay(
                        'Current',
                        '${currentWeight.toStringAsFixed(1)} kg',
                        kTextPrimary,
                        Icons.person,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: progressColor.withValues(alpha: 0.3),
                    ),
                    Expanded(
                      child: _buildWeightDisplay(
                        'Goal',
                        '${weightGoal.toStringAsFixed(1)} kg',
                        progressColor,
                        Icons.flag,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: progressColor,
                          ),
                        ),
                        Text(
                          '${progressPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progressPercentage / 100,
                      backgroundColor: progressColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getWeightProgressMessage(weightDifference, isGoalAchieved),
                      style: TextStyle(
                        fontSize: 12,
                        color: progressColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual weight display
  Widget _buildWeightDisplay(String label, String value, Color color, IconData icon) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  /// Calculate weight progress percentage based on fitness goal
  double _calculateWeightProgress(double currentWeight, double goalWeight) {
    if (goalWeight == 0) return 0.0;
    
    // Get user's fitness goal to determine success criteria
    final userGoals = _appStateService.userGoals;
    final fitnessGoal = userGoals?.fitnessGoal ?? 'maintenance';
    
    // Calculate how close we are to the goal (0-100%)
    final difference = currentWeight - goalWeight;
    
    // Determine success based on fitness goal
    bool isGoalAchieved = false;
    
    final fitnessGoalLower = fitnessGoal.toLowerCase();
    
    // Normalize the fitness goal to handle all possible formats
    final normalizedGoal = fitnessGoalLower
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    
    if (normalizedGoal == 'weight loss' || normalizedGoal == 'general fitness') {
      // Weight Loss + General Fitness: Success when current weight <= goal weight (losing weight)
      isGoalAchieved = difference <= 0;
    } else if (normalizedGoal == 'weight gain' || normalizedGoal == 'muscle building' || normalizedGoal == 'athletic performance') {
      // Weight Gain + Muscle Building + Athletic Performance: Success when current weight >= goal weight (gaining weight)
      isGoalAchieved = difference >= 0;
    } else if (normalizedGoal == 'maintenance') {
      // Maintenance: Success when current weight is within 2kg of goal weight
      isGoalAchieved = difference.abs() <= 2.0;
    } else {
      // Default to maintenance logic for unknown goals
      isGoalAchieved = difference.abs() <= 2.0;
    }
    
    if (isGoalAchieved) {
      return 100.0;
    } else {
      // Calculate progress based on fitness goal
      // Calculate progress based on fitness goal rules
      if (normalizedGoal == 'weight loss' || normalizedGoal == 'general fitness') {
        // Weight Loss + General Fitness: Progress towards losing weight
        if (difference > 0) {
          // Above goal, calculate how much to lose
          final maxWeightAboveGoal = goalWeight * 0.3; // 30% above goal as max
          return ((maxWeightAboveGoal - difference) / maxWeightAboveGoal * 100).clamp(0.0, 100.0);
        } else {
          // Below goal, already achieved
          return 100.0;
        }
      } else if (normalizedGoal == 'weight gain' || normalizedGoal == 'muscle building' || normalizedGoal == 'athletic performance') {
        // Weight Gain + Muscle Building + Athletic Performance: Progress towards gaining weight
        if (difference < 0) {
          // Below goal, calculate how much to gain
          final maxWeightBelowGoal = goalWeight * 0.2; // 20% below goal as max
          return ((maxWeightBelowGoal + difference.abs()) / maxWeightBelowGoal * 100).clamp(0.0, 100.0);
        } else {
          // Above goal, already achieved
          return 100.0;
        }
      } else {
        // Maintenance or default case: Progress towards maintaining weight
        final maxDeviation = goalWeight * 0.1; // 10% deviation as max
        return ((maxDeviation - difference.abs()) / maxDeviation * 100).clamp(0.0, 100.0);
      }
    }
  }

  /// Get weight progress message based on fitness goal
  String _getWeightProgressMessage(double weightDifference, bool isGoalAchieved) {
    // Get user's fitness goal for appropriate messaging
    final userGoals = _appStateService.userGoals;
    final fitnessGoal = userGoals?.fitnessGoal ?? 'maintenance';
    
    if (isGoalAchieved) {
      return '🎉 Congratulations! You\'ve reached your weight goal!';
    } else {
      final fitnessGoalLower = fitnessGoal.toLowerCase();
      
      // Normalize the fitness goal to handle all possible formats
      final normalizedGoal = fitnessGoalLower
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .trim();
      
      // Handle messages based on fitness goal rules
      if (normalizedGoal == 'weight loss' || normalizedGoal == 'general fitness') {
        // Weight Loss + General Fitness messages
        if (weightDifference > 0) {
          return '${weightDifference.toStringAsFixed(1)} kg above goal. Keep working towards your target!';
        } else {
          return '${(-weightDifference).toStringAsFixed(1)} kg to go. You\'re making great progress!';
        }
      } else if (normalizedGoal == 'weight gain' || normalizedGoal == 'muscle building' || normalizedGoal == 'athletic performance') {
        // Weight Gain + Muscle Building + Athletic Performance messages
        if (weightDifference < 0) {
          return '${(-weightDifference).toStringAsFixed(1)} kg below goal. Keep working towards your target!';
        } else {
          return '${weightDifference.toStringAsFixed(1)} kg above goal. You\'re making great progress!';
        }
      } else {
        // Maintenance or default case messages
        if (weightDifference.abs() <= 2.0) {
          return 'Great job! You\'re maintaining your target weight!';
        } else if (weightDifference > 0) {
          return '${weightDifference.toStringAsFixed(1)} kg above goal. Work towards your target!';
        } else {
          return '${(-weightDifference).toStringAsFixed(1)} kg below goal. Work towards your target!';
        }
      }
    }
  }

  /// Format numbers with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// Calculate macro percentage
  int _calculateMacroPercentage(double value) {
    final total =
        _macroBreakdown.carbs + _macroBreakdown.protein + _macroBreakdown.fat;
    if (total == 0) return 0;
    return ((value / total) * 100).round();
  }

  /// Get color for insight type
  Color _getInsightColor(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return kSuccessColor;
      case 'warning':
        return kWarningColor;
      case 'error':
        return Colors.red;
      case 'info':
      default:
        return kInfoColor;
    }
  }

  /// Build empty insights state
  Widget _buildEmptyInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kTextSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 32,
            color: kTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No insights available yet',
            style: TextStyle(
              fontSize: 14,
              color: kTextSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Get icon for recommendation type
  IconData _getRecommendationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'exercise':
        return Icons.fitness_center;
      case 'nutrition':
        return Icons.restaurant;
      case 'hydration':
        return Icons.water_drop;
      case 'sleep':
        return Icons.bedtime;
      case 'activity':
        return Icons.directions_walk;
      default:
        return Icons.lightbulb;
    }
  }

  /// Get color for recommendation priority
  Color _getRecommendationColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return kWarningColor;
      case 'low':
        return kInfoColor;
      default:
        return kSecondaryColor;
    }
  }

  /// Build empty recommendations state
  Widget _buildEmptyRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kTextSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 32,
            color: kTextSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No recommendations available yet',
            style: TextStyle(
              fontSize: 14,
              color: kTextSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String unit,
      IconData icon, Color color, String change, Color changeColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBreakdown() {
    final userGoals = _appStateService.userGoals;
    final macroGoals = userGoals?.macroGoals;
    
    // Debug logging
    print('🔍 Analytics Macro Breakdown UI - Protein: ${_macroBreakdown.protein}g, Carbs: ${_macroBreakdown.carbs}g, Fat: ${_macroBreakdown.fat}g');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Macronutrient Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              if (macroGoals != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'vs Goals',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Macro items with progress against goals
          Row(
            children: [
              Expanded(
                child: _buildEnhancedMacroItem(
                  'Carbs',
                  _macroBreakdown.carbs,
                  macroGoals?.carbsCalories?.toDouble() ?? 0,
                  kAccentColor,
                  'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnhancedMacroItem(
                  'Protein',
                  _macroBreakdown.protein,
                  macroGoals?.proteinCalories?.toDouble() ?? 0,
                  kSecondaryColor,
                  'g',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnhancedMacroItem(
                  'Fat',
                  _macroBreakdown.fat,
                  macroGoals?.fatCalories?.toDouble() ?? 0,
                  kInfoColor,
                  'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Macro goal progress summary
          if (macroGoals != null) ...[
            _buildMacroProgressSummary(),
            const SizedBox(height: 16),
          ],
          
          // Macro balance indicator
          _buildMacroBalanceIndicator(),
        ],
      ),
    );
  }

  Widget _buildMacroItem(
      String label, String value, String percentage, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
          ),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Enhanced macro item with goal progress
  Widget _buildEnhancedMacroItem(
      String label, double current, double goalCalories, Color color, String unit) {
    // Convert goal calories to grams (approximate conversion)
    double goalGrams = 0;
    if (label == 'Carbs' || label == 'Protein') {
      goalGrams = goalCalories / 4; // 4 calories per gram
    } else if (label == 'Fat') {
      goalGrams = goalCalories / 9; // 9 calories per gram
    }
    
    final progress = goalGrams > 0 ? (current / goalGrams).clamp(0.0, 1.0) : 0.0;
    final percentage = goalGrams > 0 ? ((current / goalGrams) * 100).round() : 0;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: progress >= 1.0 ? kSuccessColor : color.withValues(alpha: 0.3),
          width: progress >= 1.0 ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Current value
          Text(
            '${current.toStringAsFixed(0)}$unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
          ),
          // Progress percentage
          Text(
            goalGrams > 0 ? '$percentage% of goal' : 'No goal set',
            style: TextStyle(
              fontSize: 10,
              color: progress >= 1.0 ? kSuccessColor : color.withValues(alpha: 0.7),
              fontWeight: progress >= 1.0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          if (goalGrams > 0)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? kSuccessColor : color,
              ),
              minHeight: 4,
            ),
        ],
      ),
    );
  }

  /// Build macro progress summary
  Widget _buildMacroProgressSummary() {
    final userGoals = _appStateService.userGoals;
    final macroGoals = userGoals?.macroGoals;
    
    if (macroGoals == null) return const SizedBox.shrink();
    
    // Calculate overall macro goal achievement
    final carbsProgress = _calculateMacroGoalProgress(_macroBreakdown.carbs, macroGoals.carbsCalories?.toDouble() ?? 0, 'carbs');
    final proteinProgress = _calculateMacroGoalProgress(_macroBreakdown.protein, macroGoals.proteinCalories?.toDouble() ?? 0, 'protein');
    final fatProgress = _calculateMacroGoalProgress(_macroBreakdown.fat, macroGoals.fatCalories?.toDouble() ?? 0, 'fat');
    
    final overallProgress = (carbsProgress + proteinProgress + fatProgress) / 3;
    final achievedGoals = [carbsProgress, proteinProgress, fatProgress].where((p) => p >= 1.0).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor.withValues(alpha: 0.1),
            kAccentColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                achievedGoals == 3 ? Icons.check_circle : Icons.trending_up,
                color: achievedGoals == 3 ? kSuccessColor : kPrimaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Macro Goal Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: achievedGoals == 3 ? kSuccessColor : kPrimaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${(overallProgress * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: achievedGoals == 3 ? kSuccessColor : kPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achievedGoals == 3 
                ? 'Excellent! All macro goals achieved 🎉'
                : '$achievedGoals of 3 macro goals achieved',
            style: TextStyle(
              fontSize: 12,
              color: achievedGoals == 3 ? kSuccessColor : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate macro goal progress
  double _calculateMacroGoalProgress(double current, double goalCalories, String macroType) {
    if (goalCalories <= 0) return 0.0;
    
    // Convert goal calories to grams
    double goalGrams = 0;
    if (macroType == 'carbs' || macroType == 'protein') {
      goalGrams = goalCalories / 4; // 4 calories per gram
    } else if (macroType == 'fat') {
      goalGrams = goalCalories / 9; // 9 calories per gram
    }
    
    return goalGrams > 0 ? (current / goalGrams).clamp(0.0, 1.0) : 0.0;
  }

  /// Build macro balance indicator
  Widget _buildMacroBalanceIndicator() {
    final total = _macroBreakdown.carbs + _macroBreakdown.protein + _macroBreakdown.fat;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWarningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: kWarningColor, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No macro data available',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kWarningColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    final carbsPercent = (_macroBreakdown.carbs / total) * 100;
    final proteinPercent = (_macroBreakdown.protein / total) * 100;
    final fatPercent = (_macroBreakdown.fat / total) * 100;
    
    // Determine balance status
    String balanceStatus;
    Color balanceColor;
    IconData balanceIcon;
    
    if (carbsPercent >= 45 && carbsPercent <= 65 && 
        proteinPercent >= 10 && proteinPercent <= 35 && 
        fatPercent >= 20 && fatPercent <= 35) {
      balanceStatus = 'Well Balanced';
      balanceColor = kSuccessColor;
      balanceIcon = Icons.check_circle;
    } else if (carbsPercent > 70 || proteinPercent > 40 || fatPercent > 40) {
      balanceStatus = 'Needs Adjustment';
      balanceColor = kWarningColor;
      balanceIcon = Icons.warning;
    } else {
      balanceStatus = 'Good Balance';
      balanceColor = kInfoColor;
      balanceIcon = Icons.info;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: balanceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(balanceIcon, color: balanceColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              balanceStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: balanceColor,
              ),
            ),
          ),
          Text(
            'C${carbsPercent.round()}% P${proteinPercent.round()}% F${fatPercent.round()}%',
            style: TextStyle(
              fontSize: 10,
              color: balanceColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Build BMI Analytics section
  Widget _buildBMIAnalytics() {
    // Check if we have real user data from profile (not Google Fit)
    final hasHeight = _userHeight != null && _userHeight! > 0;
    final hasWeight = _userWeight != null && _userWeight! > 0;
    
    // Debug logging
    print('BMI Analytics Debug - Height: $_userHeight, Weight: $_userWeight');
    
    if (!hasHeight || !hasWeight) {
      // Show message if either height or weight is missing
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.monitor_weight,
                    color: kPrimaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'BMI Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hasHeight 
                  ? 'Weight data unavailable. Please update your profile in settings.'
                  : 'Height data unavailable. Please update your profile in settings.',
              style: const TextStyle(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate BMI from real user profile data only
    final bmi = _userWeight! / (_userHeight! * _userHeight!);
    final bmiCategory = _getBMICategory(bmi);
    final bmiColor = _getBMIColor(bmi);

    // Debug logging
    print('BMI Debug - Weight: $_userWeight, Height: $_userHeight');
    print('BMI Debug - Calculated BMI: $bmi');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bmiColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.monitor_weight,
                  color: bmiColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'BMI Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // BMI Value and Category
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  bmiColor.withValues(alpha: 0.1),
                  bmiColor.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bmiColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current BMI',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bmi.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: bmiColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bmiCategory,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: bmiColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show user data if available
                      if (hasHeight && hasWeight) ...[
                        Text(
                          'Height: ${(_userHeight! * 100).round()} cm | Weight: ${_userWeight!.round()} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary,
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Update your profile for accurate BMI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // BMI Range Information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kInfoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: kInfoColor,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'BMI Categories',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kInfoColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBMIRangeItem('Underweight', '< 18.5', Colors.blue),
                _buildBMIRangeItem('Normal', '18.5 - 24.9', Colors.green),
                _buildBMIRangeItem('Overweight', '25.0 - 29.9', Colors.orange),
                _buildBMIRangeItem('Obese', '≥ 30.0', Colors.red),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Health Recommendations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: kSuccessColor,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Health Recommendations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kSuccessColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getBMIRecommendation(bmi),
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMIRangeItem(String category, String range, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            category,
            style: const TextStyle(
              fontSize: 12,
              color: kTextPrimary,
            ),
          ),
          const Spacer(),
          Text(
            range,
            style: const TextStyle(
              fontSize: 12,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _getBMIColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return Colors.green;
    if (bmi < 30.0) return Colors.orange;
    return Colors.red;
  }

  String _getBMIRecommendation(double bmi) {
    final hasRealData = _userWeight != null && _userHeight != null;
    final gender = _userGender ?? 'Unknown';
    final age = _userAge ?? 25;

    String baseRecommendation;
    if (bmi < 18.5) {
      baseRecommendation =
          'Consider increasing your calorie intake with healthy foods and strength training to build muscle mass.';
    } else if (bmi < 25.0) {
      baseRecommendation =
          'Great job! Maintain your current healthy lifestyle with balanced nutrition and regular exercise.';
    } else if (bmi < 30.0) {
      baseRecommendation =
          'Focus on creating a moderate calorie deficit through healthy eating and increased physical activity.';
    } else {
      baseRecommendation =
          'Consider consulting with a healthcare professional for a personalized weight management plan.';
    }

    if (hasRealData) {
      return '$baseRecommendation Based on your profile ($gender, $age years old), this recommendation is personalized for you.';
    } else {
      return '$baseRecommendation Update your profile in settings for more personalized recommendations.';
    }
  }

  Widget _buildAIInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAccentPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: kAccentPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI-Generated Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _generateAIInsights(forceRefresh: true),
                icon: _isGeneratingInsights
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: kAccentPurple),
                tooltip: 'Generate AI Insights',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_aiInsights.isEmpty && !_isGeneratingInsights)
            _buildEmptyInsights()
          else if (_isGeneratingInsights)
            _buildLoadingInsights()
          else
            _buildAIInsightsContent(),
        ],
      ),
    );
  }

  Widget _buildLoadingInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kAccentPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Generating AI insights...',
            style: TextStyle(
              fontSize: 14,
              color: kAccentPurple.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAccentPurple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kAccentPurple.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: kAccentPurple,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'AI Analysis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kAccentPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiInsights,
            style: const TextStyle(
              fontSize: 13,
              color: kTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: kTextSecondary,
              height: 1.4,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: kSecondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Personalized Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recommendations.isEmpty)
            _buildEmptyRecommendations()
          else
            ..._recommendations.map((recommendation) => Column(
                  children: [
                    _buildRecommendationItem(
                      recommendation['title']?.toString() ?? 'Recommendation',
                      recommendation['description']?.toString() ??
                          'No description available',
                      _getRecommendationIcon(
                          recommendation['type']?.toString() ?? 'general'),
                      _getRecommendationColor(
                          recommendation['priority']?.toString() ?? 'medium'),
                    ),
                    const SizedBox(height: 8),
                  ],
                )),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
      String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
