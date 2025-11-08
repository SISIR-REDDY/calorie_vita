import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../ui/responsive_utils.dart';
import '../ui/responsive_widgets.dart';
import '../ui/dynamic_columns.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/simple_streak_system.dart';
import '../models/user_goals.dart';
import '../models/user_achievement.dart';
import '../services/app_state_service.dart';
import '../services/firebase_service.dart';
import '../services/dynamic_icon_service.dart';
import '../services/real_time_input_service.dart';
import '../services/daily_summary_service.dart';
import '../services/simple_streak_service.dart';
import '../services/enhanced_streak_service.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../widgets/task_popup.dart';
import '../widgets/task_card.dart';
import '../widgets/profile_widgets.dart';
import '../services/calorie_units_service.dart';
import '../services/analytics_service.dart';
import '../services/goals_event_bus.dart';
import '../services/health_connect_manager.dart';
import '../services/global_goals_manager.dart';
import '../models/google_fit_data.dart';
import '../services/simple_goals_notifier.dart';
import '../services/rewards_service.dart';
import '../models/reward_system.dart';
import '../services/fitness_goal_calculator.dart';
import 'camera_screen.dart';
import 'trainer_screen.dart';
import '../models/user_preferences.dart';
import '../models/food_history_entry.dart';
import '../services/food_history_service.dart';
import '../services/fast_data_refresh_service.dart';
import '../services/todays_food_data_service.dart';
import 'food_history_detail_screen.dart';
import 'todays_food_screen.dart';

/// Premium Home Screen with modern UI and comprehensive features
class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => _PremiumHomeScreenState();
}

class _PremiumHomeScreenState extends State<PremiumHomeScreen>
    with
        TickerProviderStateMixin,
        ResponsiveWidgetMixin,
        DynamicColumnMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Services
  final AppStateService _appStateService = AppStateService();
  final FirebaseService _firebaseService = FirebaseService();
  final RealTimeInputService _realTimeInputService = RealTimeInputService();
  final DailySummaryService _dailySummaryService = DailySummaryService();
  final SimpleStreakService _streakService = SimpleStreakService();
  final EnhancedStreakService _enhancedStreakService = EnhancedStreakService();
  final CalorieUnitsService _calorieUnitsService = CalorieUnitsService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final RewardsService _rewardsService = RewardsService();
  final HealthConnectManager _healthConnectManager = HealthConnectManager();
  final TaskService _taskService = TaskService();
  final FastDataRefreshService _fastDataRefreshService = FastDataRefreshService();
  final TodaysFoodDataService _todaysFoodDataService = TodaysFoodDataService();

  // Data
  DailySummary? _dailySummary;
  MacroBreakdown? _macroBreakdown;
  UserPreferences _preferences = const UserPreferences();
  String _motivationalQuote = '';
  bool _isLoading = false; // Track loading state
  bool _isRefreshing = false; // Track background data loading
  bool _isRefreshingFoodData = false; // Prevent multiple simultaneous food data refreshes
  
  // Debouncing for UI updates
  Timer? _uiUpdateTimer;
  bool _hasPendingUIUpdate = false;

  // Manual overrides for today's edits (UI-first, persisted via _dailySummary)
  int? _manualCaloriesConsumedOverride;
  int? _manualCaloriesBurnedOverride;
  
  // UI update throttling - Optimized for sub-second updates
  DateTime? _lastUIUpdate;
  static const Duration _minUIUpdateInterval = Duration(milliseconds: 100); // Ultra-fast updates

  // Rewards data
  UserProgress? _userProgress;
  final List<UserReward> _recentRewards = [];
  bool _isStreakLoading = true;
  
  // Debug panel
  final bool _showDebugPanel = false;
  
  // Initialization tracking
  bool _hasInitialized = false;
  
  // Data refresh tracking
  DateTime? _lastFoodDataRefresh;

  // Google Fit data - Optimized for steps, calories, and workouts only
  bool _isGoogleFitConnected = false;
  int? _googleFitSteps;
  double? _googleFitCaloriesBurned;
  int? _googleFitWorkoutSessions;
  double? _googleFitWorkoutDuration;
  String _activityLevel = 'Unknown';
  final bool _isLiveSyncing = false;
  bool _isGoogleFitLoading = false;
  DateTime? _lastSyncTime;

  // Task management
  List<Task> _tasks = [];
  bool _isTasksLoading = true;
  bool _hasUserTasks = false;
  bool _hasLoggedNoGoogleFitData = false; // Track if "No Google Fit data" has been logged
  bool _hasLoggedGoalsRefreshDuplicate = false; // Track if goals refresh duplicate has been logged
  bool _hasLoggedStreakTimeout = false; // Track if streak timeout has been logged

  // Food entries
  List<FoodHistoryEntry> _todaysFoodEntries = [];

  // Stream subscriptions
  StreamSubscription<DailySummary?>? _dailySummarySubscription;
  StreamSubscription<MacroBreakdown>? _macroBreakdownSubscription;
  StreamSubscription<UserPreferences>? _preferencesSubscription;
  StreamSubscription<UserGoals?>? _goalsSubscription;
  StreamSubscription<UserGoals>? _goalsEventBusSubscription;
  StreamSubscription<List<Task>>? _tasksSubscription;
  StreamSubscription<GoogleFitData?>? _googleFitDataSubscription;
  StreamSubscription<bool>? _googleFitConnectionSubscription;
  StreamSubscription<bool>? _googleFitLoadingSubscription;
  StreamSubscription<int>? _consumedCaloriesSubscription;
  StreamSubscription<List<FoodHistoryEntry>>? _todaysFoodSubscription;
  StreamSubscription<Map<String, dynamic>>? _fastMacroBreakdownSubscription;
  StreamSubscription<int>? _todaysFoodCaloriesSubscription;
  StreamSubscription<Map<String, double>>? _todaysFoodMacroSubscription;
  Timer? _goalsCheckTimer;
  Timer? _goalsDebounceTimer;
  Timer? _googleFitRefreshTimer;
  Timer? _streakRefreshTimer;
  
  // Prevent duplicate operations
  bool _isRefreshingGoals = false;
  bool _isRefreshingStreaks = false;
  DateTime? _lastGoalsRefreshTime;
  DateTime? _lastStreakRefreshTime;
  UserStreakSummary _streakSummary = UserStreakSummary(
    goalStreaks: {},
    totalActiveStreaks: 0,
    longestOverallStreak: 0,
    lastActivityDate: DateTime.now(),
    totalDaysActive: 0,
  );
  List<UserAchievement> _achievements = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    // Load instant data first to prevent UI lag
    _loadInstantDataFromCache();
    
    // Initialize services asynchronously to prevent blocking
    _initializeServicesAsync();
    
    // Set up essential listeners only (reduced from full setup)
    _setupEssentialListeners();
    
    // Load data with proper loading states
    _loadDataWithLoadingState();
    
    
    // Set up periodic streak refresh to ensure data stays current
    _setupPeriodicStreakRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if this is the first time dependencies change
    // This prevents excessive refresh when switching between screens
    if (!_hasInitialized) {
      _hasInitialized = true;
    // Refresh goals when screen becomes visible
    _forceRefreshGoals();
    
    // CRITICAL: Load cached calories IMMEDIATELY before any streams can emit 0
    // This prevents the zero-value flash when switching screens
    final cachedCalories = _todaysFoodDataService.getCachedConsumedCalories();
    if (cachedCalories > 0 && _dailySummary != null) {
      // Update immediately with cached value to prevent zero flash
      if (_dailySummary!.caloriesConsumed == 0) {
        setState(() {
          _dailySummary = _dailySummary!.copyWith(caloriesConsumed: cachedCalories);
        });
        print('⚡ Home: Loaded cached calories on screen change: $cachedCalories');
      }
    }
    
    // Refresh consumed calories and macro nutrients when screen becomes visible
    _refreshFoodData();
      
      // Refresh Google Fit data when screen becomes visible
      _loadGoogleFitDataImmediate();
      
      // Load tasks immediately when screen becomes visible to prevent buffering
      _loadTasksDataImmediate();
    }
  }

  /// Setup today's food data service for immediate UI updates
  Future<void> _setupTodaysFoodDataService() async {
    try {
      // INSTANT: Load cached data BEFORE initialization for fastest UI
      final cachedCalories = _todaysFoodDataService.getCachedConsumedCalories();
      final cachedMacros = _todaysFoodDataService.getCachedMacroNutrients();
      
      // Update UI immediately with cached data (0ms delay)
      // CRITICAL: Always update even if value is 0 to prevent stale data
      if (mounted) {
        setState(() {
          // Update consumed calories immediately (even if 0, to ensure consistency)
          if (_dailySummary != null) {
            // Only update if cached value is greater than current, or current is 0
            if (cachedCalories > _dailySummary!.caloriesConsumed || 
                _dailySummary!.caloriesConsumed == 0) {
              _dailySummary = _dailySummary!.copyWith(caloriesConsumed: cachedCalories);
            }
          } else {
            // Create daily summary if it doesn't exist
            _dailySummary = DailySummary(
              caloriesConsumed: cachedCalories,
              caloriesBurned: 0,
              caloriesGoal: 2000,
              steps: 0,
              stepsGoal: 10000,
              waterGlasses: 0,
              waterGlassesGoal: 8,
              date: DateTime.now(),
            );
          }
          
          // Update macro breakdown immediately
          if (cachedMacros.isNotEmpty) {
            _macroBreakdown = MacroBreakdown(
              protein: cachedMacros['protein'] ?? 0.0,
              carbs: cachedMacros['carbs'] ?? 0.0,
              fat: cachedMacros['fat'] ?? 0.0,
              fiber: cachedMacros['fiber'] ?? 0.0,
              sugar: cachedMacros['sugar'] ?? 0.0,
            );
          }
        });
        if (cachedCalories > 0) {
          print('⚡ Home: INSTANT cached data loaded - Calories: $cachedCalories');
        }
      }
      
      // Initialize service in background (non-blocking)
      // This will reload data from Firestore and update streams
      _todaysFoodDataService.initialize().then((_) {
        print('✅ Home: Food data service initialized');
        // After initialization, ensure cached data is still displayed
        final updatedCalories = _todaysFoodDataService.getCachedConsumedCalories();
        if (updatedCalories > 0 && mounted && _dailySummary != null) {
          setState(() {
            if (_dailySummary!.caloriesConsumed == 0 || updatedCalories > _dailySummary!.caloriesConsumed) {
              _dailySummary = _dailySummary!.copyWith(caloriesConsumed: updatedCalories);
            }
          });
        }
      }).catchError((e) {
        print('❌ Home: Food data service init error: $e');
      });
      
      // Listen to consumed calories stream (same data as TodaysFoodScreen)
      _todaysFoodCaloriesSubscription?.cancel(); // Cancel existing subscription first
      _todaysFoodCaloriesSubscription = _todaysFoodDataService.consumedCaloriesStream.listen(
        (calories) {
          _debounceUIUpdate(() {
            if (!mounted) return;
            // Respect manual override for the current session
            if (_manualCaloriesConsumedOverride != null) return;
            // Always update calories from TodaysFoodDataService (primary source)
            if (_dailySummary != null) {
              setState(() {
                _dailySummary = _dailySummary!.copyWith(caloriesConsumed: calories);
              });
              print('✅ Home: Calories updated from TodaysFoodDataService: $calories');
            } else {
              // Create daily summary if it doesn't exist
              setState(() {
                _dailySummary = DailySummary(
                  caloriesConsumed: calories,
                  caloriesBurned: 0,
                  caloriesGoal: 2000,
                  steps: 0,
                  stepsGoal: 10000,
                  waterGlasses: 0,
                  waterGlassesGoal: 8,
                  date: DateTime.now(),
                );
              });
            }
          });
        },
        onError: (error) {
          print('❌ Home: Error in consumed calories stream: $error');
        },
      );

      // Listen to macro nutrients stream (same data as TodaysFoodScreen)
      _todaysFoodMacroSubscription = _todaysFoodDataService.macroNutrientsStream.listen((macros) {
        _debounceUIUpdate(() {
          if (mounted) {
            _macroBreakdown = MacroBreakdown(
              protein: macros['protein'] ?? 0.0,
              carbs: macros['carbs'] ?? 0.0,
              fat: macros['fat'] ?? 0.0,
              fiber: macros['fiber'] ?? 0.0,
              sugar: macros['sugar'] ?? 0.0,
            );
          }
        });
      });

      print('✅ Today\'s food data service initialized');
    } catch (e) {
      print('❌ Error initializing today\'s food data service: $e');
    }
  }

  /// Initialize services asynchronously to not block UI
  Future<void> _initializeServicesAsync() async {
    _initializeServices()
        .catchError((e) => debugPrint('Services initialization error: $e'));
  }

  /// Load rewards data asynchronously
  Future<void> _loadRewardsDataAsync() async {
    _loadRewardsData()
        .catchError((e) => debugPrint('Rewards data loading error: $e'));
  }

  /// Preload Google Fit data for instant display
  Future<void> _preloadGoogleFitData() async {
    try {
      await _healthConnectManager.initialize();
      print('✅ Home screen: Google Fit data preloaded');
    } catch (e) {
      print('❌ Home screen: Google Fit data preload failed: $e');
    }
  }

  /// Load instant data from global cache to prevent UI lag
  void _loadInstantDataFromCache() {
    try {
      print('⚡ Home: Loading instant data from global cache...');
      
      // Load tasks instantly to prevent buffering
      _loadTasksDataImmediate();
      
      // Load Google Fit data instantly
      // Note: Caching removed for simplification
      
      // Load consumed calories and macros instantly
      // Note: Caching removed for simplification
      
      // Note: Caching logic removed for simplification
      
      print('✅ Home: Instant data loading completed');
    } catch (e) {
      print('❌ Home: Instant data loading failed: $e');
    }
  }




  /// Initialize Google Fit services in proper order
  Future<void> _initializeGoogleFitServices() async {
    try {
      print('🚀 Home: Initializing Google Fit services...');
      
      // Step 1: Initialize unified manager first
      await _initializeUnifiedGoogleFit();
      
      // Step 2: Preload data for instant display
      await _preloadGoogleFitData();
      
      // Sync mixin removed - using optimized manager
      
      print('✅ Home: Google Fit services initialized successfully');
    } catch (e) {
      print('❌ Home: Google Fit services initialization failed: $e');
    }
  }

  /// Diagnostic method removed - OptimizedGoogleFitManager handles everything  
  Future<void> _testGoogleFitConnection() async {
    // Old diagnostic code removed - OptimizedGoogleFitManager provides:
    // - Automatic authentication checking
    // - Built-in logging
    // - Real-time connection status via streams
    debugPrint('🔍 Home: Using OptimizedGoogleFitManager - diagnostics built-in');
  }

  /// Initialize optimized Google Fit manager
  Future<void> _initializeUnifiedGoogleFit() async {
    try {
      print('🚀 Home: Starting optimized Google Fit initialization...');
      await _healthConnectManager.initialize();
      
      // Check connection status
      final isConnected = _healthConnectManager.isConnected;
      print('🔍 Home: Google Fit connection status: $isConnected');
      
      // INSTANT: Load current data immediately (0ms delay) from cache
      final currentData = _healthConnectManager.getCurrentData();
      print('📊 Home: Current Google Fit data: $currentData');
      
      if (currentData != null && mounted) {
        // Update UI immediately for instant display
        setState(() {
          _googleFitSteps = currentData.steps ?? 0;
          _googleFitCaloriesBurned = currentData.caloriesBurned ?? 0.0;
          _googleFitWorkoutSessions = currentData.workoutSessions ?? 0;
          _googleFitWorkoutDuration = currentData.workoutDuration ?? 0.0;
          _activityLevel = _calculateActivityLevel(currentData.steps);
          _lastSyncTime = DateTime.now();
          _isGoogleFitConnected = true;
        });
        
        _updateDailySummaryWithGoogleFitData();
        print('⚡ Home: INSTANT Google Fit data loaded');
        print('   Steps: ${currentData.steps}');
        print('   Calories: ${currentData.caloriesBurned}');
        print('   _googleFitCaloriesBurned set to: $_googleFitCaloriesBurned');
      }
      
      // Set up listeners for real-time updates
      _setupGoogleFitListeners();
      
      print('✅ Optimized Google Fit manager initialized');
    } catch (e) {
      print('❌ Optimized Google Fit initialization failed: $e');
    }
  }

  Future<void> _initializeServices() async {
    await _realTimeInputService.initialize();
    await _dailySummaryService.initialize();
    await _streakService.initialize();
    await _enhancedStreakService.initialize();
    await _taskService.initialize();
    await _calorieUnitsService.initialize();
    _currentUserId = _realTimeInputService.getCurrentUserId();
    
    // Initialize Google Fit services
    await _initializeGoogleFitServices();
  }

  /// Set up only essential listeners to reduce buffering
  void _setupEssentialListeners() {
    try {
      // Only set up task listeners here - all other listeners are in _setupDataListeners()
      // Listen to task updates with instant state management (no delays)
      _tasksSubscription?.cancel();
      _tasksSubscription = _taskService.tasksStream.listen(
        (tasks) {
          // Always update state when stream emits to ensure UI is in sync
          if (mounted) {
            // Update immediately without delay to prevent buffering
            setState(() {
              _tasks = tasks;
              _isTasksLoading = false;
              _hasUserTasks = _taskService.hasUserTasks();
            });
            // Log for debugging
            if (kDebugMode) {
              debugPrint('📋 Tasks updated from stream: ${tasks.length} tasks, hasUserTasks: $_hasUserTasks');
              if (tasks.isNotEmpty) {
                debugPrint('📋 Task titles: ${tasks.map((t) => t.title).join(", ")}');
              }
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Task stream error: $error');
          if (mounted) {
            setState(() {
              _isTasksLoading = false;
            });
          }
        },
      );

      // Fallback: Load tasks directly after a short delay if stream doesn't work
      Timer(const Duration(seconds: 1), () {
        if (_isTasksLoading && mounted) {
          debugPrint('📋 Task stream timeout, loading tasks directly...');
          _loadTasksData();
        }
      });

      // All other listeners (daily summary, streaks, goals, macro, preferences) are in _setupDataListeners()
    } catch (e) {
      debugPrint('Stream setup error: $e');
    }
  }

  /// Helper method to compare task lists efficiently
  bool _listsEqual(List<Task> list1, List<Task> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || 
          list1[i].isCompleted != list2[i].isCompleted ||
          list1[i].title != list2[i].title) {
        return false;
      }
    }
    return true;
  }

  /// Force refresh tasks list
  void _refreshTasks() {
    setState(() {
      _tasks = _taskService.getCurrentTasks();
      _isTasksLoading = false;
      _hasUserTasks = _taskService.hasUserTasks();
    });
    print('📋 Tasks refreshed: ${_tasks.length} tasks');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dailySummarySubscription?.cancel();
    _macroBreakdownSubscription?.cancel();
    _preferencesSubscription?.cancel();
    _goalsSubscription?.cancel();
    _goalsEventBusSubscription?.cancel();
    _goalsCheckTimer?.cancel();
    _goalsDebounceTimer?.cancel();
    _googleFitRefreshTimer?.cancel();
    _streakRefreshTimer?.cancel();
    _googleFitDataSubscription?.cancel();
    _googleFitConnectionSubscription?.cancel();
    _googleFitLoadingSubscription?.cancel();
    _consumedCaloriesSubscription?.cancel();
    _todaysFoodSubscription?.cancel();
    _fastMacroBreakdownSubscription?.cancel();
    _todaysFoodCaloriesSubscription?.cancel();
    _todaysFoodMacroSubscription?.cancel();
    _tasksSubscription?.cancel();
    _uiUpdateTimer?.cancel();
    // GoogleFitCacheService removed for simplification
    _fastDataRefreshService.dispose();
    // Don't dispose unified manager as it's a singleton
    // _unifiedGoogleFitManager.dispose();
    
    _todaysFoodDataService.dispose();
    // OptimizedGoogleFitManager handles its own lifecycle
    GlobalGoalsManager().clearCallback();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  /// Load data with proper loading states to prevent buffering
  Future<void> _loadDataWithLoadingState() async {
    try {
      // Show loading state
      if (mounted) {
        setState(() => _isLoading = true);
      }

      // Load cached data first (non-blocking)
      _loadCachedDataImmediate();

      // Set up real-time data listeners immediately
      _setupDataListeners();

      // Initialize AppStateService with timeout (non-blocking)
      _initializeAppStateAsync();

      // Load essential data in parallel with timeouts
      await Future.wait([
        _loadStreakData().timeout(const Duration(seconds: 2)),
        _loadRewardsData().timeout(const Duration(seconds: 2)),
        _loadTasksData().timeout(const Duration(seconds: 1)),
      ]).catchError((e) {
        debugPrint('Essential data loading error: $e');
        return <void>[];
      });
      
      // Force refresh goals to ensure UI is up to date
      _forceRefreshGoals();
      
      // Hide loading state immediately after essential data is loaded
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      // Load additional data in background without blocking UI
      _loadBackgroundData();
      
    } catch (e) {
      // Handle error silently in production
      debugPrint('Error loading home data: $e');

      // Hide loading state even on error
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Load additional data in background without blocking UI
  void _loadBackgroundData() {
    // Load non-essential data in background
    Future.microtask(() async {
      try {
        // Load data in parallel with timeouts to prevent blocking
        await Future.wait([
          if (_isGoogleFitConnected) 
            _refreshGoogleFitData().timeout(const Duration(seconds: 3)),
          _refreshFoodData().timeout(const Duration(seconds: 2)),
        ]).catchError((e) {
          debugPrint('Background data loading error: $e');
          return <void>[];
        });
        
        // Refresh streak, rewards, and tasks data with shorter timeouts
        await Future.wait([
          _loadStreakData().timeout(const Duration(seconds: 1)),
          _loadRewardsData().timeout(const Duration(seconds: 1)),
          _refreshTasksData().timeout(const Duration(seconds: 1)),
        ]).catchError((e) {
          debugPrint('Streak/rewards/tasks refresh error: $e');
          return <void>[];
        });
      } catch (e) {
        debugPrint('Background data loading error: $e');
      }
    });
  }

  /// Load Google Fit data immediately if available
  void _loadGoogleFitDataImmediate() {
    try {
      // Get current data from optimized manager (instant from cache)
      final currentData = _healthConnectManager.getCurrentData();
      if (currentData != null) {
        setState(() {
          _googleFitSteps = currentData.steps ?? 0;
          _googleFitCaloriesBurned = currentData.caloriesBurned ?? 0.0;
          _googleFitWorkoutSessions = currentData.workoutSessions ?? 0;
          _googleFitWorkoutDuration = currentData.workoutDuration ?? 0.0;
          _activityLevel = _calculateActivityLevel(currentData.steps);
          _isGoogleFitConnected = _healthConnectManager.isConnected;
        });
        print('✅ Home: Loaded Google Fit data immediately - Steps: ${currentData.steps}, Calories: ${currentData.caloriesBurned}');
      } else {
        setState(() {
          _googleFitSteps = 0;
          _googleFitCaloriesBurned = 0.0;
          _googleFitWorkoutSessions = 0;
          _googleFitWorkoutDuration = 0.0;
          _activityLevel = 'Unknown';
          _isGoogleFitConnected = false;
        });
        // Reduced logging - only log once, not on every check
        if (kDebugMode && !_hasLoggedNoGoogleFitData) {
          debugPrint('⚠️ Home: No Google Fit data available');
          _hasLoggedNoGoogleFitData = true;
        }
      }
    } catch (e) {
      print('❌ Home: Error loading Google Fit data: $e');
    }
  }

  /// Load cached data immediately to show something to user
  void _loadCachedDataImmediate() {
    try {
      // Load cached summary if available, but preserve consumed calories if already loaded
      if (_dailySummary == null) {
        // Try to get cached calories from TodaysFoodDataService first
        final cachedCalories = _todaysFoodDataService.getCachedConsumedCalories();
        _dailySummary = DailySummary(
          caloriesConsumed: cachedCalories, // Use cached calories instead of 0
          caloriesBurned: 0,
          caloriesGoal: 2000,
          steps: 0,
          stepsGoal: 10000,
          waterGlasses: 0,
          waterGlassesGoal: 8,
          date: DateTime.now(),
        );
        if (cachedCalories > 0) {
          print('✅ Home: Loaded cached calories: $cachedCalories');
        }
      } else {
        // If summary exists, try to update with cached calories if it's 0
        final cachedCalories = _todaysFoodDataService.getCachedConsumedCalories();
        if (_dailySummary!.caloriesConsumed == 0 && cachedCalories > 0) {
          setState(() {
            _dailySummary = _dailySummary!.copyWith(caloriesConsumed: cachedCalories);
          });
          print('✅ Home: Updated calories from cache: $cachedCalories');
        }
      }

      // Load Google Fit data immediately if available
      _loadGoogleFitDataImmediate();

      // Note: Consumed calories and macro nutrients will be loaded via streams
      // in _setupFastDataRefresh() to prevent conflicts and flickering

      // Load default motivational quote
      if (_motivationalQuote.isEmpty) {
        _loadMotivationalQuote();
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  /// Load consumed calories from food history (deprecated - use TodaysFoodDataService stream instead)
  /// This is kept for fallback only
  Future<void> _loadConsumedCaloriesFromFoodHistory() async {
    try {
      // Get consumed calories from food history
      final consumedCalories = await FoodHistoryService.getTodaysConsumedCalories();
      
      if (mounted && consumedCalories > 0) {
        // Only update if we have real data and current value is 0
        // This prevents overwriting stream data
        final currentCalories = _dailySummary?.caloriesConsumed ?? 0;
        if (currentCalories == 0 && consumedCalories > 0) {
          setState(() {
            if (_dailySummary != null) {
              _dailySummary = _dailySummary!.copyWith(caloriesConsumed: consumedCalories);
            }
          });
          print('✅ Loaded consumed calories from food history (fallback): $consumedCalories');
        }
      }
    } catch (e) {
      print('❌ Error loading consumed calories from food history: $e');
    }
  }

  /// Load macro nutrients from food history
  Future<void> _loadMacroNutrientsFromFoodHistory() async {
    try {
      // Get today's food entries
      final entries = await FoodHistoryService.getTodaysFoodEntries();
      
      // Calculate macro breakdown
      double totalProtein = 0.0;
      double totalCarbs = 0.0;
      double totalFat = 0.0;
      double totalFiber = 0.0;
      double totalSugar = 0.0;

      for (final entry in entries) {
        totalProtein += entry.protein;
        totalCarbs += entry.carbs;
        totalFat += entry.fat;
        totalFiber += entry.fiber;
        totalSugar += entry.sugar;
      }

      if (mounted) {
        setState(() {
          _macroBreakdown = MacroBreakdown(
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            sugar: totalSugar,
          );
        });
      }
      
      print('✅ Loaded macro nutrients from food history: Protein: ${totalProtein.toStringAsFixed(1)}g, Carbs: ${totalCarbs.toStringAsFixed(1)}g, Fat: ${totalFat.toStringAsFixed(1)}g');
    } catch (e) {
      print('❌ Error loading macro nutrients from food history: $e');
    }
  }

  /// Load today's food entries for UI display
  Future<void> _loadTodaysFoodEntries() async {
    try {
      final entries = await FoodHistoryService.getTodaysFoodEntries();
      if (mounted) {
        setState(() {
          _todaysFoodEntries = entries;
        });
      }
      print('✅ Loaded ${entries.length} food entries for UI');
    } catch (e) {
      print('❌ Error loading today\'s food entries: $e');
    }
  }

  /// Check if food entries have actually changed
  bool _hasFoodEntriesChanged(List<dynamic> newEntries) {
    // For now, always return true to trigger update
    // This can be optimized later with more sophisticated comparison
    return true;
  }

  /// Check if macro data has actually changed
  bool _hasMacroDataChanged(Map<String, dynamic> newData) {
    if (_macroBreakdown == null) return true;
    
    return _macroBreakdown!.protein != (newData['protein'] ?? 0.0) ||
           _macroBreakdown!.carbs != (newData['carbs'] ?? 0.0) ||
           _macroBreakdown!.fat != (newData['fat'] ?? 0.0) ||
           _macroBreakdown!.fiber != (newData['fiber'] ?? 0.0) ||
           _macroBreakdown!.sugar != (newData['sugar'] ?? 0.0);
  }

  /// Debounce UI updates to prevent flickering with throttling
  void _debounceUIUpdate(VoidCallback updateCallback) {
    // Check if enough time has passed since last update
    final now = DateTime.now();
    if (_lastUIUpdate != null && 
        now.difference(_lastUIUpdate!) < _minUIUpdateInterval) {
      return; // Skip this update to prevent too frequent updates
    }
    
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer(const Duration(milliseconds: 50), () { // Ultra-fast: 50ms for sub-second updates
      if (mounted && !_hasPendingUIUpdate) {
        _hasPendingUIUpdate = true;
        _lastUIUpdate = DateTime.now();
        setState(() {
          updateCallback();
        });
        _hasPendingUIUpdate = false;
      }
    });
  }

  /// Refresh food data when screen becomes visible
  Future<void> _refreshFoodData() async {
    // Prevent multiple simultaneous refreshes
    if (_isRefreshingFoodData) {
      return;
    }
    
    try {
      _isRefreshingFoodData = true;
      
      // Only force refresh if data is stale (avoid unnecessary API calls)
      final now = DateTime.now();
      if (_lastFoodDataRefresh == null || 
          now.difference(_lastFoodDataRefresh!).inMinutes > 5) {
        // Use timeout to prevent blocking
        await _fastDataRefreshService.forceRefresh().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('⚠️ Food data refresh timeout');
          },
        );
        _lastFoodDataRefresh = now;
      }
      
      // Load data with timeout to prevent blocking
      await Future.wait([
        _loadConsumedCaloriesFromFoodHistory(),
        _loadMacroNutrientsFromFoodHistory(),
        _loadTodaysFoodEntries(),
      ]).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ Food data loading timeout');
          return <void>[];
        },
      );
      
    } catch (e) {
      print('❌ Error refreshing food data: $e');
    } finally {
      _isRefreshingFoodData = false;
    }
  }

  /// Initialize AppStateService asynchronously
  Future<void> _initializeAppStateAsync() async {
    try {
      if (!_appStateService.isInitialized) {
        await _appStateService.initialize().timeout(const Duration(seconds: 3),
            onTimeout: () =>
                debugPrint('AppStateService initialization timed out'));
      }
    } catch (e) {
      debugPrint('Error initializing AppStateService: $e');
    }
  }

  /// Load fresh data in background without blocking UI
  Future<void> _loadFreshDataAsync() async {
    setState(() => _isRefreshing = true);

    try {
      // Load critical data with short timeouts
      await Future.wait([
        _loadTodaysSummary().timeout(const Duration(seconds: 3),
            onTimeout: () => debugPrint('Today summary load timed out')),
        _loadStreakData().timeout(const Duration(seconds: 2),
            onTimeout: () => debugPrint('Streak data load timed out')),
        _loadTasksData().timeout(const Duration(seconds: 3),
            onTimeout: () => debugPrint('Tasks data load timed out')),
      ]).timeout(const Duration(seconds: 5));

      // Initialize analytics service in background (lower priority)
      _analyticsService
          .initializeRealTimeAnalytics(days: 30)
          .timeout(const Duration(seconds: 5),
              onTimeout: () =>
                  debugPrint('Analytics service initialization timed out'))
          .then((_) {
        // Calculate achievements after analytics is ready
        return _analyticsService.calculateStreaksAndAchievements().timeout(
            const Duration(seconds: 3),
            onTimeout: () => debugPrint('Achievements calculation timed out'));
      }).catchError(
              (e) => debugPrint('Analytics background loading error: $e'));
    } catch (e) {
      debugPrint('Error loading fresh data: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }


  /// Initialize Google Fit - DEPRECATED  
  @Deprecated('Use _initializeUnifiedGoogleFit instead')
  Future<void> _initializeGoogleFit() async {
    print('⚠️ _initializeGoogleFit is deprecated - use OptimizedGoogleFitManager');
    // Old implementation removed - use OptimizedGoogleFitManager instead
  }

  /// Initialize Google Fit cache service for enhanced performance
  Future<void> _initializeGoogleFitCache() async {
    try {
      // GoogleFitCacheService removed for simplification

      print('Google Fit cache service initialized with real-time updates');
    } catch (e) {
      print('Error initializing Google Fit cache service: $e');
    }
  }

  /// Initialize optimized Google Fit cache service for faster data loading
  Future<void> _initializeOptimizedGoogleFitCache() async {
    try {
      // OptimizedCacheService removed for simplification

      // Get cached data immediately for instant UI display
      // OptimizedCacheService removed for simplification
      // if (cachedData != null && mounted) {
        // setState(() {
        //   _googleFitSteps = cachedData.steps ?? 0;
        //   _googleFitCaloriesBurned = cachedData.caloriesBurned ?? 0.0;
        //   _googleFitWorkoutSessions = cachedData.workoutSessions ?? 0;
        //   _googleFitWorkoutDuration = cachedData.workoutDuration ?? 0.0;
        //   _activityLevel = _calculateActivityLevel(cachedData.steps);
        //   _lastSyncTime = DateTime.now();
        // });

        // // Update daily summary if available
        // if (_dailySummary != null) {
        //   _updateDailySummaryWithGoogleFitData();
        // }
        
        // print('✅ Optimized Google Fit cache: Instant data loaded - Steps: ${cachedData.steps}');
      // }

      // Listen to optimized cache stream for real-time updates
      // OptimizedCacheService removed for simplification
        // if (mounted) {
        //   setState(() {
        //     _googleFitSteps = data.steps ?? 0;
        //     _googleFitCaloriesBurned = data.caloriesBurned ?? 0.0;
        //     _googleFitWorkoutSessions = data.workoutSessions ?? 0;
        //     _googleFitWorkoutDuration = data.workoutDuration ?? 0.0;
        //     _activityLevel = _calculateActivityLevel(data.steps);
        //     _lastSyncTime = DateTime.now();
        //   });

        //   // Update daily summary if available
        //   if (_dailySummary != null) {
        //     _updateDailySummaryWithGoogleFitData();
        //   }
        // }
      // });

      print('✅ Optimized Google Fit cache service initialized with instant data loading');
    } catch (e) {
      print('❌ Error initializing optimized Google Fit cache service: $e');
    }
  }

  /// Old mixin methods removed - OptimizedGoogleFitManager handles data via streams automatically
  /// Data updates come through _setupGoogleFitListeners() via the optimized manager's streams

  /// Load Google Fit data asynchronously - now handled by unified manager
  @Deprecated('Use unified manager instead')
  Future<void> _loadGoogleFitDataAsync() async {
    // This is now handled by the unified manager
    print('⚠️ Legacy Google Fit data loading called - using unified manager instead');
  }

  /// Load Google Fit data using optimized service - now handled by unified manager
  @Deprecated('Use unified manager instead')
  Future<void> _loadGoogleFitDataOptimized() async {
    // This is now handled by the unified manager
    print('⚠️ Legacy optimized Google Fit data loading called - using unified manager instead');
  }

  /// Load Google Fit data and update UI (optimized with caching)
  Future<void> _loadGoogleFitData() async {
    try {
      if (mounted) {
        setState(() {
          _isGoogleFitLoading = true;
        });
      }

      // Force refresh data from optimized manager
      final workoutData = await _healthConnectManager.forceRefresh();

      if (workoutData != null && mounted) {
        setState(() {
          _googleFitSteps = workoutData.steps ?? 0;
          _googleFitCaloriesBurned = workoutData.caloriesBurned ?? 0.0;
          _googleFitWorkoutSessions = workoutData.workoutSessions ?? 0;
          _googleFitWorkoutDuration = workoutData.workoutDuration ?? 0.0;
          _activityLevel = _calculateActivityLevel(workoutData.steps);
          _lastSyncTime = DateTime.now();
        });

        // Update daily summary with Google Fit data if available
        if (_dailySummary != null) {
          await _updateDailySummaryWithGoogleFitData();
        }

        print('✅ Google Fit data loaded: Steps=${workoutData.steps}, Calories=${workoutData.caloriesBurned}');
      } else {
        // Fallback to individual calls if optimized service fails
        await _loadGoogleFitDataFallback();
      }
    } catch (e) {
      print('❌ Error loading Google Fit data: $e');
      // Try fallback method
      await _loadGoogleFitDataFallback();
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleFitLoading = false;
        });
      }
    }
  }

  /// Fallback method for loading Google Fit data
  Future<void> _loadGoogleFitDataFallback() async {
    try {
      final today = DateTime.now();

      // Use optimized manager for data
      final data = _healthConnectManager.getCurrentData();
      final steps = data?.steps ?? 0;
      final calories = data?.caloriesBurned ?? 0.0;

      if (mounted) {
        setState(() {
          _googleFitSteps = steps;
          _googleFitCaloriesBurned = calories;
          _googleFitWorkoutSessions = 0; // Will be updated by workout detection
          _googleFitWorkoutDuration = 0.0;
          _activityLevel = _calculateActivityLevel(steps);
          _lastSyncTime = DateTime.now();
        });
      }

      if (_dailySummary != null) {
        await _updateDailySummaryWithGoogleFitData();
      }

      print(
          'Google Fit data loaded (fallback): Steps=$steps, Calories=$calories, Workouts=$_googleFitWorkoutSessions');
    } catch (e) {
      print('Fallback Google Fit loading failed: $e');
      if (mounted) {
        setState(() {
          _googleFitSteps = 0;
          _googleFitCaloriesBurned = 0.0;
          _googleFitWorkoutSessions = 0;
          _googleFitWorkoutDuration = 0.0;
          _activityLevel = 'Unknown';
          _lastSyncTime = DateTime.now();
        });
      }
    }
  }

  /// Calculate activity level based on steps
  String _calculateActivityLevel(int? steps) {
    if (steps == null) return 'Unknown';

    if (steps < 5000) return 'Low';
    if (steps < 10000) return 'Moderate';
    if (steps < 15000) return 'Active';
    return 'Very Active';
  }

  /// Update daily summary with Google Fit data
  Future<void> _updateDailySummaryWithGoogleFitData() async {
    if (_dailySummary == null) return;

    try {
      // Create updated daily summary with Google Fit data
      final updatedSummary = DailySummary(
        date: _dailySummary!.date,
        caloriesConsumed: _dailySummary!.caloriesConsumed,
        caloriesBurned:
            _googleFitCaloriesBurned?.round() ?? _dailySummary!.caloriesBurned,
        caloriesGoal: _dailySummary!.caloriesGoal,
        steps: _googleFitSteps ?? _dailySummary!.steps,
        stepsGoal: _dailySummary!.stepsGoal,
        waterGlasses: _dailySummary!.waterGlasses,
        waterGlassesGoal: _dailySummary!.waterGlassesGoal,
      );

      // Update the daily summary service
      await _dailySummaryService.updateDailySummary(updatedSummary);

      // Refresh streaks after updating daily summary
      await _enhancedStreakService.refreshStreaks();

      if (mounted) {
        setState(() {
          _dailySummary = updatedSummary;
        });
      }
    } catch (e) {
      print('❌ Error updating daily summary with Google Fit data: $e');
    }
  }

  /// Connect to Google Fit using unified manager
  Future<void> _connectToGoogleFit() async {
    try {
      final success = await _healthConnectManager.requestPermissions();
      if (success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Google Fit connected successfully! Your data will sync automatically.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to Google Fit. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error connecting to Google Fit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to Google Fit: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Refresh Google Fit data using unified manager
  Future<void> _refreshGoogleFitData() async {
    try {
      // Only test connection if not already connected
      if (!_isGoogleFitConnected) {
        await _testGoogleFitConnection().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print('⚠️ Google Fit connection timeout');
          },
        );
      }
      
      // Force refresh from optimized manager with timeout
    if (_isGoogleFitConnected) {
        final data = await _healthConnectManager.forceRefresh().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Google Fit data refresh timeout');
            return null;
          },
        );
        
        if (data != null && mounted) {
          setState(() {
            _googleFitSteps = data.steps ?? 0;
            _googleFitCaloriesBurned = data.caloriesBurned ?? 0.0;
            _googleFitWorkoutSessions = data.workoutSessions ?? 0;
            _googleFitWorkoutDuration = data.workoutDuration ?? 0.0;
            _activityLevel = _calculateActivityLevel(data.steps);
            _lastSyncTime = DateTime.now();
          });
          
          // Update daily summary with Google Fit data
          _updateDailySummaryWithGoogleFitData();
        }
      }
    } catch (e) {
      print('❌ Error refreshing Google Fit data: $e');
    }
  }

  /// Live sync is now handled automatically by OptimizedGoogleFitManager
  /// No manual start/stop needed - it uses background timer with caching

  /// Start periodic refresh timer for Google Fit data (backup)
  void _startGoogleFitRefreshTimer() {
    _googleFitRefreshTimer?.cancel();
    // Google Fit refresh handled by OptimizedGoogleFitManager (every 2 minutes)
    // No need for separate timer here
  }

  /// Stop Google Fit refresh timer
  void _stopGoogleFitRefreshTimer() {
    _googleFitRefreshTimer?.cancel();
    _googleFitRefreshTimer = null;
  }

  /// Set up periodic streak refresh to ensure data stays current
  /// OPTIMIZED: Reduced from 30s to 5 minutes to reduce API calls and improve performance
  void _setupPeriodicStreakRefresh() {
    _streakRefreshTimer?.cancel();
    _streakRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshStreaksPeriodically();
    });
    debugPrint('Periodic streak refresh timer set up (optimized: 5 min interval)');
  }

  /// Refresh streaks periodically to ensure data stays current
  Future<void> _refreshStreaksPeriodically() async {
    try {
      await _enhancedStreakService.refreshStreaks();
      debugPrint('Periodic streak refresh completed');
    } catch (e) {
      debugPrint('Error in periodic streak refresh: $e');
    }
  }

  /// Format last sync time for display
  String _formatLastSyncTime(DateTime syncTime) {
    final now = DateTime.now();
    final difference = now.difference(syncTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  /// Set up Google Fit listeners for real-time updates
  void _setupGoogleFitListeners() {
    // Listen to optimized Google Fit data stream
    _googleFitDataSubscription?.cancel();
    _googleFitDataSubscription = _healthConnectManager.dataStream.listen((data) {
      if (mounted && data != null) {
        print('📥 Home: Received data from HealthConnectManager stream');
        print('   Steps: ${data.steps}');
        print('   Calories: ${data.caloriesBurned}');
        print('   Workouts: ${data.workoutSessions}');
        
        setState(() {
          _googleFitSteps = data.steps ?? 0;
          _googleFitCaloriesBurned = data.caloriesBurned ?? 0.0;
          _googleFitWorkoutSessions = data.workoutSessions ?? 0;
          _googleFitWorkoutDuration = data.workoutDuration ?? 0.0;
          _activityLevel = _calculateActivityLevel(data.steps);
          _lastSyncTime = DateTime.now();
        });
        
        print('✅ Home: UI state updated - _googleFitCaloriesBurned = $_googleFitCaloriesBurned');
        
        _updateDailySummaryWithGoogleFitData();
        print('⚡ Home: Real-time Google Fit update - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
      }
    });
    
    // Listen to connection status
    _googleFitConnectionSubscription?.cancel();
    _googleFitConnectionSubscription = _healthConnectManager.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isGoogleFitConnected = isConnected;
        });
        print('🔗 Home: Google Fit connection changed: $isConnected');
      }
    });
    
    // Listen to loading status
    _googleFitLoadingSubscription?.cancel();
    _googleFitLoadingSubscription = _healthConnectManager.loadingStream.listen((isLoading) {
      if (mounted) {
        setState(() {
          _isGoogleFitLoading = isLoading;
        });
      }
    });
    
    print('✅ Home: Google Fit listeners set up');
  }

  /// Set up real-time data listeners from AppStateService
  void _setupDataListeners() {
    // Listen to daily summary updates with debouncing
    _dailySummarySubscription?.cancel();
    _dailySummarySubscription =
        _appStateService.dailySummaryStream.listen((summary) async {
      if (!mounted) return;
      
      // Only update if data actually changed
      if (_dailySummary?.toMap() != summary?.toMap()) {
        // CRITICAL FIX: Check consumed calories BEFORE setState to prevent flickering
        final currentConsumedCalories = _dailySummary?.caloriesConsumed ?? 0;
        final newConsumedCalories = summary?.caloriesConsumed ?? 0;
        final cachedCalories = _todaysFoodDataService.getCachedConsumedCalories();
        
        // Determine which calories value to use (priority: cached > current > new)
        int caloriesToUse;
        if (cachedCalories > 0) {
          // Always use cached calories from TodaysFoodDataService (highest priority)
          caloriesToUse = cachedCalories;
        } else if (currentConsumedCalories > 0) {
          // Preserve current calories if no cache but we have data
          caloriesToUse = currentConsumedCalories;
        } else {
          // Only use new calories if we have no cached or current data
          caloriesToUse = newConsumedCalories;
        }
        
        // Only update if the new summary is valid
        if (summary != null) {
          setState(() {
            // ALWAYS preserve consumed calories from TodaysFoodDataService
            // This prevents AppStateService from causing flickering with 0 values
            _dailySummary = summary.copyWith(caloriesConsumed: caloriesToUse);
          });
        }
        
        // OPTIMIZED: Removed automatic streak refresh here to prevent excessive API calls
        // Streaks are refreshed periodically (every 5 min) and after user actions
        // This prevents refreshing on every stream update
      }
    });

    // Listen to macro breakdown updates with change detection
    _macroBreakdownSubscription?.cancel();
    _macroBreakdownSubscription =
        _appStateService.macroBreakdownStream.listen((breakdown) {
      if (!mounted) return;
      
      // Only update if macro data actually changed
      if (_hasMacroDataChanged({
        'protein': breakdown.protein,
        'carbs': breakdown.carbs,
        'fat': breakdown.fat,
        'fiber': breakdown.fiber,
        'sugar': breakdown.sugar,
      })) {
        setState(() {
          _macroBreakdown = breakdown;
        });
      }
    });

    // Listen to preferences updates with change detection
    _preferencesSubscription?.cancel();
    _preferencesSubscription =
        _appStateService.preferencesStream.listen((preferences) {
      if (!mounted) return;
      
      // Only update if preferences actually changed
      if (_preferences.toMap() != preferences.toMap()) {
        setState(() {
          _preferences = preferences;
        });
      }
    });

    // Health data functionality removed

    // Set up Google Fit listeners
    _setupGoogleFitListeners();

    // Listen to goals updates with debouncing and change detection
    // Debug logging removed for performance
    _goalsSubscription?.cancel();
    _goalsSubscription = _appStateService.goalsStream.listen(
      (goals) {
        if (!mounted) return;
        
        // OPTIMIZED: Increased debounce from 300ms to 1s to prevent rapid refreshes
        _goalsDebounceTimer?.cancel();
        _goalsDebounceTimer = Timer(const Duration(seconds: 1), () async {
          if (!mounted) return;
          
          // Only update if goals actually changed (debug logging removed)
          final currentGoals = _appStateService.userGoals;
          final currentMap = currentGoals?.toMap();
          final newMap = goals?.toMap();
          if (currentMap != newMap) {
            await _refreshDailySummaryWithNewGoals(goals);
            
            if (mounted) {
              setState(() {
                // Trigger a rebuild to show updated goals
              });
            }
          }
        });
      },
      onError: (error) {
        // Only log errors, not normal operations
        debugPrint('Goals stream error: $error');
        // Show user-friendly error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating goals. Please try again.'),
              backgroundColor: Colors.orange[600],
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );

    // Listen to goals event bus for immediate updates
    // OPTIMIZED: Added change detection to prevent duplicate refreshes
    _goalsEventBusSubscription?.cancel();
    _goalsEventBusSubscription = GoalsEventBus().goalsStream.listen(
      (goals) async {
        if (mounted) {
          // Check if goals actually changed before refreshing (debug logging removed)
          final currentGoalsMap = _appStateService.userGoals?.toMap();
          final newGoalsMap = goals.toMap();
          if (currentGoalsMap != newGoalsMap) {
            await _refreshDailySummaryWithNewGoals(goals);
          }
        }
      },
      onError: (error) {
        debugPrint('Goals event bus error: $error');
      },
    );

    // Register global callback for immediate goals updates
    // OPTIMIZED: Added change detection and debouncing to prevent duplicate refreshes
    GlobalGoalsManager().setGoalsUpdateCallback((goals) async {
      // Debounce to prevent rapid successive calls
      _goalsDebounceTimer?.cancel();
      _goalsDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        
        // Check if goals actually changed before refreshing (debug logging removed)
        final currentGoalsMap = _appStateService.userGoals?.toMap();
        final newGoalsMap = goals.toMap();
        if (currentGoalsMap != newGoalsMap) {
          await _refreshDailySummaryWithNewGoals(goals);
          // Also force a complete UI refresh
          forceUIRefresh();
        }
      });
    });

    // Set up periodic goals check (optimized - every 5 minutes instead of 30 seconds)
    // Goals are already updated via streams, so periodic check is just a safety net
    _goalsCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkForGoalsUpdate();
    });
    // Debug logging removed for performance

    // Listen to achievements updates with change detection
    _analyticsService.achievementsStream.listen((achievements) {
      if (!mounted) return;
      
      // Only update if achievements list actually changed
      bool hasChanged = _achievements.length != achievements.length;
      if (!hasChanged) {
        // Check if any achievement IDs changed
        final currentIds = _achievements.map((a) => a.id).toList();
        final newIds = achievements.map((a) => a.id).toList();
        hasChanged = currentIds.join(',') != newIds.join(',');
      }
      
      if (hasChanged) {
        setState(() {
          _achievements = achievements;
        });
      }
    });
  }

  /// Navigate to settings screen
  void _navigateToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  /// Get empty daily summary for when no data is available
  DailySummary _getEmptyDailySummary() {
    final userGoals = _appStateService.userGoals;
    debugPrint('Getting empty daily summary with goals: ${userGoals?.toMap()}');
    return DailySummary(
      caloriesConsumed: 0,
      caloriesBurned: 0,
      caloriesGoal: userGoals?.calorieGoal ?? 2000,
      steps: 0,
      stepsGoal: userGoals?.stepsPerDayGoal ?? 10000,
      waterGlasses: 0,
      waterGlassesGoal: userGoals?.waterGlassesGoal ?? 8,
      date: DateTime.now(),
    );
  }

  /// Refresh daily summary with new goals
  /// OPTIMIZED: Added locking to prevent duplicate concurrent calls
  Future<void> _refreshDailySummaryWithNewGoals(UserGoals? goals) async {
    // Prevent duplicate concurrent calls
    if (_isRefreshingGoals) {
      // Reduced logging - only log once per session
      if (kDebugMode && !_hasLoggedGoalsRefreshDuplicate) {
        debugPrint('⚠️ Goals refresh already in progress, skipping duplicate call');
        _hasLoggedGoalsRefreshDuplicate = true;
      }
      return;
    }
    
    // Prevent rapid successive calls (debounce within 500ms)
    final now = DateTime.now();
    if (_lastGoalsRefreshTime != null && 
        now.difference(_lastGoalsRefreshTime!).inMilliseconds < 500) {
      debugPrint('⚠️ Goals refresh called too soon after last refresh, skipping');
      return;
    }
    
    _isRefreshingGoals = true;
    _lastGoalsRefreshTime = now;
    
    try {
      // Debug logging removed for performance - only log on errors

      if (mounted) {
        setState(() {
          // Goals updated - refresh daily summary with new goals
          if (_dailySummary != null) {
            _dailySummary = _dailySummary!.copyWith(
              caloriesGoal: goals?.calorieGoal ?? 2000,
              stepsGoal: goals?.stepsPerDayGoal ?? 10000,
              waterGlassesGoal: goals?.waterGlassesGoal ?? 8,
            );
            // Debug logging removed for performance
          } else {
            _dailySummary = _getEmptyDailySummary();
            // Debug logging removed for performance
          }
        });

        // Save updated daily summary to Firestore with new goals
        try {
          await _saveDailySummaryToFirestore();
          debugPrint('Daily summary saved to Firestore successfully');
        } catch (e) {
          debugPrint('Error saving updated daily summary: $e');
        }

        // Recalculate streaks and achievements based on new goals (debounced)
        // Only refresh streaks if not already refreshing
        if (!_isRefreshingStreaks) {
          try {
            await _refreshStreaksDebounced();
            debugPrint('Streaks and achievements recalculated successfully');
          } catch (e) {
            debugPrint('Error recalculating streaks and achievements: $e');
          }
        }
      }
    } finally {
      _isRefreshingGoals = false;
    }
        // Debug logging removed for performance
  }
  
  /// Refresh streaks with debouncing to prevent excessive calls
  Future<void> _refreshStreaksDebounced() async {
    // Prevent duplicate concurrent calls
    if (_isRefreshingStreaks) {
      debugPrint('⚠️ Streak refresh already in progress, skipping duplicate call');
      return;
    }
    
    // Prevent rapid successive calls (debounce within 2 seconds)
    final now = DateTime.now();
    if (_lastStreakRefreshTime != null && 
        now.difference(_lastStreakRefreshTime!).inSeconds < 2) {
      debugPrint('⚠️ Streak refresh called too soon after last refresh, skipping');
      return;
    }
    
    _isRefreshingStreaks = true;
    _lastStreakRefreshTime = now;
    
    try {
      await _analyticsService.calculateStreaksAndAchievements();
      await _enhancedStreakService.refreshStreaks();
    } finally {
      _isRefreshingStreaks = false;
    }
  }

  /// Force refresh the daily summary with current goals from AppStateService
  Future<void> forceRefreshDailySummary() async {
    if (mounted) {
      final currentGoals = _appStateService.userGoals;
      if (currentGoals != null) {
        await _refreshDailySummaryWithNewGoals(currentGoals);
      }
    }
  }

  /// Force complete UI refresh
  void forceUIRefresh() {
    if (mounted) {
      setState(() {
        // Force a complete rebuild of the UI
        debugPrint('Forcing complete UI refresh');
      });
    }
  }

  /// Force refresh goals to ensure UI is up to date
  Future<void> _forceRefreshGoals() async {
    try {
      // Debug logging removed for performance
      final currentGoals = _appStateService.userGoals;
      if (currentGoals != null) {
        await _refreshDailySummaryWithNewGoals(currentGoals);
      }
    } catch (e) {
      debugPrint('Error force refreshing goals: $e');
    }
  }

  /// Check for goals update periodically
  /// OPTIMIZED: Added change detection to prevent unnecessary refreshes
  Future<void> _checkForGoalsUpdate() async {
    if (!mounted) return;

    try {
      final simpleGoals = SimpleGoalsNotifier().currentGoals;
      final appStateGoals = _appStateService.userGoals;

      // Check if goals actually changed
      final simpleMap = simpleGoals?.toMap();
      final appStateMap = appStateGoals?.toMap();
      
      // Debug logging removed - only refresh if there's an actual difference

      // Only refresh if there's an actual difference
      if (simpleGoals != null && appStateGoals != null) {
        if (simpleMap != appStateMap) {
          debugPrint('Goals change detected via periodic check - refreshing UI');
          await _refreshDailySummaryWithNewGoals(simpleGoals);
        } else {
          debugPrint('Periodic goals check - no change detected, skipping refresh');
        }
      } else if (simpleGoals != null && appStateGoals == null) {
        debugPrint('Simple goals available but AppState goals null - refreshing with simple goals');
        await _refreshDailySummaryWithNewGoals(simpleGoals);
      } else {
        debugPrint('Periodic goals check - both null or no change, skipping');
      }
    } catch (e) {
      debugPrint('Error checking for goals update: $e');
    }
  }

  /// Show calorie input dialog for manual entry
  void _showCalorieInputDialog(String type) {
    final isConsumed = type == 'consumed';
    final currentValue = isConsumed
        ? (_dailySummary?.caloriesConsumed ?? 0)
        : (_dailySummary?.caloriesBurned ?? 0);

    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isConsumed ? 'Edit Calories Consumed' : 'Edit Calories Burned',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isConsumed
                    ? 'How many calories did you consume today?'
                    : 'How many calories did you burn today?',
                style: GoogleFonts.poppins(
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Calories',
                  hintText: 'Enter calories',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(
                    isConsumed ? Icons.restaurant : Icons.directions_run,
                    color: isConsumed ? Colors.orange[600] : Colors.red[600],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: kTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = int.tryParse(controller.text) ?? 0;
                await _updateCalorieValue(type, value);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isConsumed ? Colors.orange[600] : Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Update',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Update calorie value in the daily summary
  Future<void> _updateCalorieValue(String type, int value) async {
    _dailySummary ??= _getEmptyDailySummary();

    setState(() {
      if (type == 'consumed') {
        // Manual consumed editing disabled; ignore
      } else {
        _manualCaloriesBurnedOverride = value;
        _dailySummary = _dailySummary!.copyWith(caloriesBurned: value);
      }
    });

    // Save to Firestore or local storage
    if (type != 'consumed') {
      await _saveDailySummaryToFirestore();
    }
    
    // OPTIMIZED: Streaks are refreshed periodically (every 5 min) instead of after every update
    // This reduces API calls significantly while still keeping data fresh
    // Streaks will be refreshed on next periodic timer (5 min) or when user explicitly refreshes
  }

  /// Update water glasses value and save to Firestore
  Future<void> _updateWaterGlassesValue(int value) async {
    _dailySummary ??= _getEmptyDailySummary();

    setState(() {
      _dailySummary = _dailySummary!.copyWith(waterGlasses: value);
    });

    await _saveDailySummaryToFirestore();
    
    // OPTIMIZED: Streaks are refreshed periodically (every 5 min) instead of after every update
    // This reduces API calls significantly while still keeping data fresh
  }

  /// Update water target value and save to Firestore
  Future<void> _updateWaterTargetValue(int value) async {
    _dailySummary ??= _getEmptyDailySummary();

    setState(() {
      _dailySummary = _dailySummary!.copyWith(waterGlassesGoal: value);
    });

    await _saveDailySummaryToFirestore();

    // Also update the user goals in AppStateService
    await _appStateService.updateUserGoals(
        _appStateService.userGoals?.copyWith(waterGlassesGoal: value) ??
            const UserGoals(waterGlassesGoal: 8));
    
    // OPTIMIZED: Streaks are refreshed periodically (every 5 min) instead of after every update
    // This reduces API calls significantly while still keeping data fresh
  }

  /// Show water glasses input dialog
  void _showWaterGlassesDialog() {
    final currentValue = _dailySummary?.waterGlasses ?? 0;
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Water Intake',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How many glasses of water have you had today?',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Glasses',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: 'glasses',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 0;
              _updateWaterGlassesValue(value);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Update', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  /// Show water target dialog
  void _showWaterTargetDialog() {
    final currentValue = _dailySummary?.waterGlassesGoal ?? 8;
    final controller = TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Water Target',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How many glasses of water do you want to drink daily?',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Glasses',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: 'glasses',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSuccessColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: kSuccessColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recommended: 8 glasses (2 liters) per day',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text) ?? 8;
              _updateWaterTargetValue(value);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Update', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  /// Save daily summary to Firestore
  Future<void> _saveDailySummaryToFirestore() async {
    if (_dailySummary == null) return;

    try {
      final user = _appStateService.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('daily_summaries')
            .doc(DateTime.now()
                .toIso8601String()
                .split('T')[0]) // Today's date as document ID
            .set(_dailySummary!.toMap());
      }
    } catch (e) {
      debugPrint('Error saving daily summary: $e');
    }
  }

  /// Load today's daily summary with daily reset functionality
  Future<void> _loadTodaysSummary() async {
    try {
      final user = _appStateService.currentUser;
      if (user == null) {
        _dailySummary = _getEmptyDailySummary();
        return;
      }

      // Clean up old data first
      await _cleanupOldDailySummaries();

      final today = DateTime.now().toIso8601String().split('T')[0];
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_summaries')
          .doc(today)
          .get();

      if (doc.exists) {
        // Load existing data for today
        _dailySummary = DailySummary.fromMap(doc.data()!);
      } else {
        // Create new empty summary for today (daily reset)
        _dailySummary = _getEmptyDailySummary();
        await _saveDailySummaryToFirestore();
      }
    } catch (e) {
      debugPrint('Error loading today\'s summary: $e');
      _dailySummary = _getEmptyDailySummary();
    }
  }

  /// Clean up old daily summary data from Firebase
  Future<void> _cleanupOldDailySummaries() async {
    try {
      final user = _appStateService.currentUser;
      if (user == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Get all daily summary documents
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_summaries')
          .get();

      // Delete all documents except today's (strict cleanup)
      final batch = FirebaseFirestore.instance.batch();
      int deletedCount = 0;

      for (final doc in querySnapshot.docs) {
        final docId = doc.id;
        // Only keep today's data, delete everything else
        if (docId != today) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('Cleaned up $deletedCount old daily summary documents');
      }
    } catch (e) {
      debugPrint('Error cleaning up old daily summaries: $e');
    }
  }

  Future<void> _loadStreakData() async {
    try {
      // Get current streak data immediately (non-blocking)
      _streakSummary = _enhancedStreakService.currentStreaks;
      
      // Initialize enhanced streak service in background with timeout
      _enhancedStreakService.initialize().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          // Reduced logging - only log once per session
          if (kDebugMode && !_hasLoggedStreakTimeout) {
            debugPrint('⚠️ Streak service initialization timeout');
            _hasLoggedStreakTimeout = true;
          }
        },
      ).then((_) {
        // Update with fresh data if initialization succeeds
        if (mounted) {
          setState(() {
      _streakSummary = _enhancedStreakService.currentStreaks;
          });
        }
      }).catchError((e) {
        debugPrint('❌ Streak service initialization error: $e');
      });
      
      if (mounted) {
        setState(() => _isStreakLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading streak data: $e');
      // Provide fallback data
      _streakSummary = _getDefaultStreakData();
      if (mounted) {
        setState(() => _isStreakLoading = false);
      }
    }
  }

  /// Load rewards data based on current streak data
  Future<void> _loadRewardsData() async {
    try {
      // Calculate user progress based on current streak data
      final currentStreak = _streakSummary.longestOverallStreak;
      final currentLevel = RewardSystem.getCurrentLevel(currentStreak);
      final nextLevel = RewardSystem.getNextLevel(currentLevel);
      final daysToNextLevel = RewardSystem.getDaysToNextLevel(currentStreak, currentLevel);
      final levelProgress = RewardSystem.getLevelProgress(currentStreak, currentLevel);
      
      // Get unlocked rewards (simplified - could be enhanced with actual reward tracking)
      final unlockedRewards = _getUnlockedRewards(currentStreak);
      
      _userProgress = UserProgress(
        currentStreak: currentStreak,
        longestStreak: _streakSummary.longestOverallStreak,
        currentLevel: currentLevel,
        daysToNextLevel: daysToNextLevel,
        levelProgress: levelProgress,
        unlockedRewards: unlockedRewards,
        categoryProgress: _calculateCategoryProgress(),
      );
      
      debugPrint('🏆 Loaded rewards: Level ${currentLevel.title}, ${unlockedRewards.length} rewards unlocked');
    } catch (e) {
      debugPrint('❌ Error loading rewards data: $e');
      _userProgress = UserProgress.initial();
    }
  }

  /// Get unlocked rewards based on current streak data
  List<UserReward> _getUnlockedRewards(int currentStreak) {
    final allRewards = RewardSystem.getAllRewards();
    final unlockedRewards = <UserReward>[];
    
    for (final reward in allRewards) {
      bool shouldUnlock = false;
      
      // Check streak-based rewards using actual streak data
      if (reward.type == RewardType.streak) {
        switch (reward.id) {
          case 'water_streak_7':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.waterIntake]?.currentStreak ?? 0) >= 7;
            break;
          case 'water_streak_30':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.waterIntake]?.currentStreak ?? 0) >= 30;
            break;
          case 'water_streak_100':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.waterIntake]?.currentStreak ?? 0) >= 100;
            break;
          case 'water_streak_365':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.waterIntake]?.currentStreak ?? 0) >= 365;
            break;
          case 'meal_streak_7':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.calorieGoal]?.currentStreak ?? 0) >= 7;
            break;
          case 'meal_streak_30':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.calorieGoal]?.currentStreak ?? 0) >= 30;
            break;
          case 'meal_streak_100':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.calorieGoal]?.currentStreak ?? 0) >= 100;
            break;
          case 'meal_streak_365':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.calorieGoal]?.currentStreak ?? 0) >= 365;
            break;
          case 'exercise_streak_7':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.exercise]?.currentStreak ?? 0) >= 7;
            break;
          case 'exercise_streak_30':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.exercise]?.currentStreak ?? 0) >= 30;
            break;
          case 'exercise_streak_100':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.exercise]?.currentStreak ?? 0) >= 100;
            break;
          case 'exercise_streak_365':
            shouldUnlock = (_streakSummary.goalStreaks[DailyGoalType.exercise]?.currentStreak ?? 0) >= 365;
            break;
        }
      }
      
      // Check special achievements using overall streak data
      if (reward.type == RewardType.special) {
        switch (reward.id) {
          case 'perfect_week':
            shouldUnlock = currentStreak >= 7;
            break;
          case 'hot_streak':
            shouldUnlock = currentStreak >= 100;
            break;
          case 'consistency_king':
            shouldUnlock = currentStreak >= 30;
            break;
        }
      }
      
      if (shouldUnlock) {
        unlockedRewards.add(reward.copyWith(
          isUnlocked: true,
          earnedAt: DateTime.now(),
        ));
      }
    }
    
    return unlockedRewards;
  }

  /// Calculate category progress based on streak data
  Map<String, int> _calculateCategoryProgress() {
    return {
      'logging': _streakSummary.goalStreaks[DailyGoalType.calorieGoal]?.totalDaysAchieved ?? 0,
      'exercise': _streakSummary.goalStreaks[DailyGoalType.exercise]?.totalDaysAchieved ?? 0,
      'water': _streakSummary.goalStreaks[DailyGoalType.waterIntake]?.totalDaysAchieved ?? 0,
      'steps': _streakSummary.goalStreaks[DailyGoalType.steps]?.totalDaysAchieved ?? 0,
    };
  }

  /// Load tasks data immediately without loading state (for instant display)
  void _loadTasksDataImmediate() {
    try {
      // Reduced logging - tasks are loaded silently via stream
      final tasks = _taskService.getCurrentTasks();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isTasksLoading = false;
          _hasUserTasks = _taskService.hasUserTasks();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading tasks immediately: $e');
      if (mounted) {
        setState(() {
          _isTasksLoading = false;
        });
      }
    }
  }

  /// Load tasks data with fallback
  Future<void> _loadTasksData() async {
    try {
      // CRITICAL FIX: Use getCurrentTasks() instead of getTasks()
      // getCurrentTasks() returns from _localTasks (includes temp tasks)
      // getTasks() queries Firestore directly (doesn't include unsaved temp tasks)
      final tasks = _taskService.getCurrentTasks();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isTasksLoading = false;
          // Check if user has any tasks (not just example tasks)
          _hasUserTasks = _taskService.hasUserTasks();
        });
        
        // Example tasks are handled by the stream listener
      }
    } catch (e) {
      debugPrint('❌ Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _isTasksLoading = false;
        });
      }
    }
  }

  /// Refresh tasks data without full screen refresh (for pull-to-refresh)
  Future<void> _refreshTasksData() async {
    try {
      debugPrint('📋 Refreshing tasks data...');
      // CRITICAL FIX: Use getCurrentTasks() to preserve temp tasks
      final tasks = _taskService.getCurrentTasks();
      debugPrint('📋 Refreshed ${tasks.length} tasks from service');
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _hasUserTasks = _taskService.hasUserTasks();
        });
      }
    } catch (e) {
      debugPrint('❌ Error refreshing tasks: $e');
    }
  }

  UserStreakSummary _getDefaultStreakData() {
    final goalStreaks = <DailyGoalType, GoalStreak>{};

    for (final goalType in DailyGoalType.values) {
      goalStreaks[goalType] = GoalStreak(
        goalType: goalType,
        currentStreak: 0,
        longestStreak: 0,
        lastAchievedDate: DateTime.now().subtract(const Duration(days: 1)),
        achievedToday: false,
        streakStartDate: DateTime.now().subtract(const Duration(days: 1)),
        totalDaysAchieved: 0,
      );
    }

    return UserStreakSummary(
      goalStreaks: goalStreaks,
      totalActiveStreaks: 0,
      longestOverallStreak: 0,
      lastActivityDate: DateTime.now(),
      totalDaysActive: 0,
    );
  }

  // Preferences are now loaded via real-time stream from AppStateService

  void _loadMotivationalQuote() {
    final quotes = [
      "Every meal is a chance to nourish your body! 🌟",
      "Small steps lead to big changes! 💪",
      "Your health is your greatest wealth! 🏆",
      "Progress, not perfection! 🎯",
      "Fuel your body, fuel your dreams! ⚡",
    ];
    _motivationalQuote = quotes[DateTime.now().day % quotes.length];
  }

  // ========== INPUT HANDLING METHODS ==========

  /// Handle exercise input
  Future<void> _handleExercise() async {
    if (_currentUserId == null) return;

    final caloriesController = TextEditingController();
    final durationController = TextEditingController();
    final typeController = TextEditingController();
    String selectedType = 'Cardio';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Log Exercise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your exercise details:'),
              const SizedBox(height: 16),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Type',
                  hintText: 'e.g., Running, Weightlifting',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories Burned',
                  hintText: 'Enter calories burned',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: 'Enter duration in minutes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final calories = int.tryParse(caloriesController.text);
                final duration = int.tryParse(durationController.text);
                final type = typeController.text.trim();

                if (calories != null && duration != null && type.isNotEmpty) {
                  Navigator.pop(context, {
                    'calories': calories,
                    'duration': duration,
                    'type': type,
                  });
                }
              },
              child: const Text('Log Exercise'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _realTimeInputService.handleExercise(
        context,
        caloriesBurned: result['calories'],
        durationMinutes: result['duration'],
        exerciseType: result['type'],
      );
    }
  }

  /// Handle steps input
  Future<void> _handleSteps() async {
    if (_currentUserId == null) return;

    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Steps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many steps did you take today?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps',
                hintText: 'Enter number of steps',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final steps = int.tryParse(controller.text);
              if (steps != null) {
                Navigator.pop(context, steps);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _realTimeInputService.handleSteps(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: RefreshIndicator(
              onRefresh: _loadDataWithLoadingState,
              child: CustomScrollView(
                slivers: [
                  // Greeting Section
                  _buildGreetingSection(),

                  // Daily Summary Cards
                  _buildDailySummarySection(),

                  // Spacing between sections
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),

                  // Daily Goals
                  _buildDailyGoalsSection(),

                  // Spacing between sections
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),

                  // Food History
                  _buildFoodHistorySection(),

                  // Spacing between sections
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),

                  // Tasks & To-Do
                  _buildTasksSection(),

                  // Spacing between sections
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final iconSize = screenWidth < 360 ? 60.0 : (screenWidth < 600 ? 80.0 : 100.0);
                final iconInnerSize = iconSize * 0.5;
                return Container(
                  width: iconSize,
                  height: iconSize,
                  constraints: const BoxConstraints(
                    minWidth: 50,
                    maxWidth: 100,
                    minHeight: 50,
                    maxHeight: 100,
                  ),
                  decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.circular(iconSize / 2),
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: iconInnerSize,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your day...',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection() {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    final screenWidth = MediaQuery.of(context).size.width;
    final margin = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 20.0 : 24.0);
    final padding = screenWidth < 360 ? 16.0 : (screenWidth < 600 ? 24.0 : 28.0);
    
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(margin),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: kPrimaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: kElevatedShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting,',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.displayName ?? 'User',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _showProfileSheet,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person,
                              color: Colors.white, size: 28)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _motivationalQuote,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummarySection() {
    // Always show the summary cards, even when empty
    final summary = _dailySummary ?? _getEmptyDailySummary();

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue[50]!,
              Colors.blue[100]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.blue[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.today,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Summary',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your daily progress',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Live status badge
                if (_isGoogleFitConnected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kSuccessColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kSuccessColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Live',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kSuccessColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Main summary cards
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedSummaryCard(
                    'Consumed',
                    _calorieUnitsService.formatCaloriesShort(
                        summary.caloriesConsumed.toDouble()),
                    _calorieUnitsService.unitSuffix,
                    Icons.restaurant,
                    Colors.green[600]!,
                    'Auto-tracked from Food Log',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEnhancedSummaryCard(
                    'Burned',
                    _calorieUnitsService.formatCaloriesShort(
                        (_googleFitCaloriesBurned?.round() ?? summary.caloriesBurned)
                          .toDouble()),
                    _calorieUnitsService.unitSuffix,
                    Icons.directions_run,
                    Colors.red[600]!,
                    'Synced from Google Fit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calories to target card (full width)
            _buildCaloriesToTargetCard(),
          ],
        ),
      ),
    );
  }


  Widget _buildEnhancedSummaryCard(String label, String value, String unit,
      IconData icon, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$value $unit',
            style: GoogleFonts.poppins(
              fontSize: MediaQuery.of(context).size.width < 360 ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesToTargetCard() {
    // Get user goals to determine fitness goal
    final userGoals = _appStateService.userGoals;
    final profileData = _appStateService.profileData;
    final fitnessGoal = (userGoals?.fitnessGoal ??
        profileData?['fitnessGoal']?.toString() ?? 'maintenance');
    
    // Use manual overrides if available for immediate UI accuracy
    // Consumed should be sourced from data, not manual input
    final uiCaloriesConsumed = _dailySummary!.caloriesConsumed;
    // Burned should always reflect synced Google Fit data, not manual edits
    final uiCaloriesBurned = (_googleFitCaloriesBurned?.round() ?? _dailySummary!.caloriesBurned);

    // Calculate remaining calories based on fitness goal
    final caloriesToTarget = FitnessGoalCalculator.calculateRemainingCalories(
      fitnessGoal: fitnessGoal,
      caloriesConsumed: uiCaloriesConsumed,
      caloriesBurned: uiCaloriesBurned,
      baseCalorieGoal: _dailySummary!.caloriesGoal,
    );
    
    final isReached = FitnessGoalCalculator.isGoalReached(
      fitnessGoal: fitnessGoal,
      remainingCalories: caloriesToTarget,
    );
    
    final colorValue = FitnessGoalCalculator.getProgressColor(
      fitnessGoal: fitnessGoal,
      isGoalReached: isReached,
      remainingCalories: caloriesToTarget,
    );
    
    final color = Color(colorValue);
    final icon = isReached ? Icons.check_circle : Icons.flag;
    final status = isReached ? 'Goal Reached!' : 'To Reach Goal';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 4),
                Text(
                  isReached
                      ? 'Congratulations! 🎉'
                      : '${_calorieUnitsService.formatCaloriesShort(caloriesToTarget.abs().toDouble())} ${_calorieUnitsService.unitSuffix} remaining',
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  FitnessGoalCalculator.getMotivationalMessage(
                    fitnessGoal: fitnessGoal,
                    remainingCalories: caloriesToTarget,
                    isGoalReached: isReached,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, int value, IconData icon, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 1000),
            builder: (context, animatedValue, child) {
              return Text(
                '$animatedValue $unit',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimaryColor.withValues(alpha: 0.1),
              kPrimaryColor.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: kPrimaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag, color: kPrimaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Daily Goals',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Track Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Goals Grid - Single Row: Steps and Water (Always show)
            Row(
              children: [
                Expanded(
                  child: _buildGoalCard(
                    'Steps',
                    '${_googleFitSteps ?? 0}',
                    '10000',
                    'steps',
                    Icons.directions_walk,
                    kSecondaryColor,
                    ((_googleFitSteps ?? 0) / 10000.0).clamp(0.0, 1.0) * 100,
                    null, // No tap functionality
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGoalCard(
                    'Water',
                    '${_dailySummary?.waterGlasses ?? 0}',
                    '${_dailySummary?.waterGlassesGoal ?? 8}',
                    'glasses',
                    Icons.water_drop,
                    Colors.blue,
                    (_dailySummary?.waterGlassesProgress ?? 0.0) * 100,
                    () => _showWaterGlassesDialog(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kSuccessColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_up,
                        color: kSuccessColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getDailyProgressMessage(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_getOverallProgressPercentage().round()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(
      String title,
      String current,
      String target,
      String unit,
      IconData icon,
      Color color,
      double progress,
      VoidCallback? onTap) {
    final isCompleted = progress >= 100;
    final progressColor =
        isCompleted ? kSuccessColor : color; // Use original colors

    Widget cardContent = Container(
      height: MediaQuery.of(context).size.width < 360 ? 160 : 180,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? kSuccessColor.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: progressColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kSuccessColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
            ],
          ),

          // Values section with better spacing
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current value - larger and more prominent
              Text(
                current,
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 360 ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                  height: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              // Target value with unit
              Text(
                'of $target $unit',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),

          // Progress section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  backgroundColor: progressColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCompleted
                    ? 'Goal Reached! 🎉'
                    : '${progress.round()}% complete',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Return with or without GestureDetector based on onTap
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }

  Widget _buildTasksSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.task_alt, color: kAccentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tasks & To-Do',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                if (_isTasksLoading)
                  GestureDetector(
                    onTap: () => _loadTasksData(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  )
                else
                GestureDetector(
                  onTap: () => _showAddTaskDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kAccentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: kAccentColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Today's Tasks
            if (_isTasksLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading tasks...'),
                    ],
                  ),
                ),
              )
            else if (_tasks.isNotEmpty)
              // Show tasks if they exist - this takes priority over everything
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TaskCard(
                    task: task,
                    onToggleCompletion: () => _toggleTaskCompletion(task.id),
                    onDelete: () => _deleteTask(task.id),
                  ),
                )).toList(),
              )
            else if (!_hasUserTasks)
              // Only show example widget if no tasks exist
              ExampleTasksWidget(
                onAddTask: () => _showAddTaskDialog(),
              )
            else
              // Empty state
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }


  // Helper methods
  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'red':
        return kErrorColor;
      case 'orange':
        return kWarningColor;
      case 'blue':
        return kInfoColor;
      case 'green':
        return kSuccessColor;
      default:
        return kTextSecondary;
    }
  }

  void _showProfileSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _buildProfileScreen(),
        fullscreenDialog: true,
      ),
    );
  }


  /// Build goal streaks section with responsive design
  Widget _buildGoalStreaksSection() {
    return ResponsiveCard(
      padding: responsivePadding,
      margin: responsiveMargin,
      borderRadius: ResponsiveUtils.getResponsiveBorderRadius(context, 24.0),
      elevation: ResponsiveUtils.getResponsiveElevation(context, 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context, 12.0)),
                decoration: BoxDecoration(
                  color: kAccentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(context, 12.0),
                  ),
                ),
                child: ResponsiveIcon(
                  Icons.trending_up,
                  color: kAccentColor,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 24.0),
                ),
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 12.0)),
              ResponsiveText(
                'Daily Goal Streaks',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20.0)),
          
          // Display actual goal streaks with responsive layout
          if (_isStreakLoading)
            ...List.generate(4, (index) => 
              Padding(
                padding: EdgeInsets.only(
                  bottom: ResponsiveUtils.getResponsiveSpacing(context, 12.0),
                ),
                child: ProfileWidgets.buildLoadingStreakCard(context),
              ),
            )
          else
            ..._streakSummary.goalStreaks.values.map(
              (streak) => Padding(
                padding: EdgeInsets.only(
                  bottom: ResponsiveUtils.getResponsiveSpacing(context, 12.0),
                ),
                child: ProfileWidgets.buildGoalStreakCard(context, streak),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileScreen() {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(
          'Profile & Progress',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        backgroundColor: kAppBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryColor.withValues(alpha: 0.1),
                    kPrimaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Profile Avatar with enhanced design
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: kPrimaryColor,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              user?.displayName?.isNotEmpty == true
                                  ? user!.displayName!
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'U',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Name
                  Text(
                    user?.displayName ?? 'User',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // User Email
                  Text(
                    user?.email ?? 'user@example.com',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Streak Card
                  _buildSimpleQuickStats(),
                ],
              ),
            ),

            // Content Sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // Weekly Streak Calendar Section
                  _buildWeeklyStreakCalendarSection(),
                  const SizedBox(height: 32),

                  // Current Streaks Section
                  _buildGoalStreaksSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleQuickStats() {
    return Center(
      child: _buildStreakCard(),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.deepOrange.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Streak Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.deepOrange,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),

          // Streak Number
          Text(
            '${_streakSummary.longestOverallStreak}',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 4),

          // Streak Label
          Text(
            'Day Streak',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 2),

          // Motivational Text
          Text(
            _streakSummary.longestOverallStreak > 0
                ? 'Keep the momentum going! 🔥'
                : 'Start your journey today! 🌟',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStreakCalendarSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month,
                    color: kPrimaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weekly Streak Calendar',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kSuccessColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '7 Days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kSuccessColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Weekly Calendar Grid
          _buildImprovedWeeklyCalendar(),
          const SizedBox(height: 16),

          // Legend
          _buildSimpleCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildImprovedWeeklyCalendar() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Week day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: weekDays
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Week calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isToday = date.day == now.day && date.month == now.month;
              
              // Check if this date has streak data
              final hasStreak = _streakSummary.goalStreaks.values.any((streak) {
                return streak.currentStreak > 0 && 
                       streak.lastAchievedDate.day == date.day &&
                       streak.lastAchievedDate.month == date.month &&
                       streak.lastAchievedDate.year == date.year;
              });
              
              // Check if this date has rewards (simplified - could be enhanced)
              const hasReward = false; // Could be enhanced with actual reward data

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildBeautifulCalendarDay(
                      date.day, isToday, hasStreak, hasReward),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBeautifulCalendarDay(
      int day, bool isToday, bool hasStreak, bool hasReward) {
    Color backgroundColor = Theme.of(context).colorScheme.surface;
    Color textColor = kTextSecondary;
    Color borderColor = Colors.transparent;
    Widget? indicator;

    if (isToday) {
      backgroundColor = kPrimaryColor;
      textColor = Colors.white;
      borderColor = kPrimaryColor;
    } else if (hasStreak) {
      backgroundColor = kSuccessColor.withValues(alpha: 0.2);
      textColor = kSuccessColor;
      borderColor = kSuccessColor;
      indicator = Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: kSuccessColor,
          shape: BoxShape.circle,
        ),
      );
    } else if (hasReward) {
      backgroundColor = kAccentColor.withValues(alpha: 0.2);
      textColor = kAccentColor;
      borderColor = kAccentColor;
      indicator = Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: kAccentColor,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.toString(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          if (indicator != null) indicator,
        ],
      ),
    );
  }

  Widget _buildSimpleCalendarLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Today', kPrimaryColor),
        _buildLegendItem('Streak Day', kSuccessColor),
        _buildLegendItem('Reward Earned', kAccentColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }

  // Removed reward/achievement methods - replaced with streak system

  void _showDeleteConfirmation(String entryId, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Entry',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$title"?',
            style: GoogleFonts.poppins(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: kTextSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteFoodEntry(entryId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFoodEntry(String entryId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firebaseService.deleteFoodEntry(user.uid, entryId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Entry deleted successfully! 🗑️'),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          // Refresh the data
          _loadDataWithLoadingState();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting entry: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _navigateToCamera() {
    // Navigate to camera screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
  }

  void _navigateToAITrainer() {
    // Navigate to AI Trainer screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AITrainerScreen()),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TaskPopup(
          onAddTask: (title, description) {
            _addTask(title, description);
          },
        );
      },
    );
  }

  void _addTask(String taskTitle, String? description) {
    try {
      // INSTANT add - no async/await delays
      final task = _taskService.addTask(
        title: taskTitle,
        description: description,
      );

      if (task != null) {
        // FORCE immediate UI update BEFORE showing snackbar
        // This ensures tasks are visible immediately
        if (mounted) {
          final currentTasks = _taskService.getCurrentTasks();
          setState(() {
            _tasks = currentTasks;
            _isTasksLoading = false;
            _hasUserTasks = _taskService.hasUserTasks();
          });
          print('📋 Task added immediately: ${task.title}, total tasks: ${_tasks.length}');
          print('📋 Current _tasks in UI: ${_tasks.map((t) => '${t.id}:${t.title}').join(", ")}');
          print('📋 _hasUserTasks: $_hasUserTasks');
        }
        
        // Show success message INSTANTLY (no delays)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Task added'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
        
        // Also refresh to ensure consistency
        _refreshTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add task'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding task: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _toggleTaskCompletion(String taskId) {
    try {
      print('🔄 Toggling task completion for ID: $taskId');
      print('🔄 Available tasks: ${_tasks.map((t) => '${t.id}:${t.title}').toList()}');
      
      // Find task before toggling for snackbar message
      final task = _tasks.firstWhere((task) => task.id == taskId);
      final wasCompleted = task.isCompleted;
      print('🔄 Found task: ${task.title}, was completed: $wasCompleted');
      
      // Try to toggle with the current task ID first
      bool success = _taskService.toggleTaskCompletion(taskId);
      print('🔄 Toggle result with original ID: $success');
      
      // If that fails, try to find the task by title and toggle it
      if (!success) {
        print('🔄 Original ID failed, trying to find task by title: ${task.title}');
        final serviceTasks = _taskService.getCurrentTasks();
        final matchingTask = serviceTasks.firstWhere(
          (t) => t.title == task.title,
          orElse: () => throw Exception('Task not found'),
        );
        print('🔄 Found matching task with ID: ${matchingTask.id}');
        success = _taskService.toggleTaskCompletion(matchingTask.id);
        print('🔄 Toggle result with matching ID: $success');
      }
      
      if (success) {
        // Show success message INSTANTLY (no delays)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task updated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
        
        // FORCE immediate UI update - bypass stream completely
        _refreshTasks();
        print('🔄 UI refreshed after toggle');
      } else {
        print('🔄 Toggle failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update task'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      print('❌ Error toggling task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _deleteTask(String taskId) {
    try {
      print('🗑️ Deleting task with ID: $taskId');
      
      // Find task before deleting for fallback
      final task = _tasks.firstWhere((task) => task.id == taskId);
      
      // Try to delete with the current task ID first
      bool success = _taskService.deleteTask(taskId);
      print('🗑️ Delete result with original ID: $success');
      
      // If that fails, try to find the task by title and delete it
      if (!success) {
        print('🗑️ Original ID failed, trying to find task by title: ${task.title}');
        final serviceTasks = _taskService.getCurrentTasks();
        final matchingTask = serviceTasks.firstWhere(
          (t) => t.title == task.title,
          orElse: () => throw Exception('Task not found'),
        );
        print('🗑️ Found matching task with ID: ${matchingTask.id}');
        success = _taskService.deleteTask(matchingTask.id);
        print('🗑️ Delete result with matching ID: $success');
      }
      
      if (success) {
        // Show success message INSTANTLY (no delays)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
        
        // Force immediate UI update as fallback
        _refreshTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete task'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting task: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  String _getTaskEmoji(String task) {
    // Use the enhanced dynamic icon service with contextual awareness
    final dynamicIconService = DynamicIconService();

    // Get contextual icons based on current time
    final contextualIcons =
        dynamicIconService.getContextualIcons(task, timeOfDay: DateTime.now());

    // Return the first contextual icon if available, otherwise use the best match
    return contextualIcons.isNotEmpty
        ? contextualIcons.first
        : dynamicIconService.generateIcon(task);
  }

  void _showDeleteTaskConfirmation(String taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Task',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "$taskTitle"?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: kTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTask(taskId);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Delete',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }






  // Helper methods for Daily Goals section
  String _getDailyProgressMessage() {
    final calorieProgress = (_dailySummary?.calorieProgress ?? 0.0) * 100;
    final stepsProgress = (_dailySummary?.stepsProgress ?? 0.0) * 100;

    final completedGoals = [calorieProgress, stepsProgress]
        .where((progress) => progress >= 100)
        .length;

    if (completedGoals == 2) {
      return 'Amazing! You\'ve completed all your daily goals! 🎉';
    } else if (completedGoals >= 1) {
      return 'Great progress! You\'re almost there! 💪';
    } else {
      return 'Ready to start your healthy day? Let\'s go! 💫';
    }
  }

  double _getOverallProgressPercentage() {
    final calorieProgress = (_dailySummary?.calorieProgress ?? 0.0) * 100;
    final stepsProgress = (_dailySummary?.stepsProgress ?? 0.0) * 100;

    return (calorieProgress + stepsProgress) / 2;
  }

  void _showCalorieGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calorie Goal'),
        content: const Text(
            'Your calorie goal is set to 2000 calories. You can adjust this in the Goals & Targets screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to goals screen
              // You can implement navigation to goals screen here
            },
            child: const Text('Edit Goals'),
          ),
        ],
      ),
    );
  }

  /// Build food history section (simplified without streams to prevent flickering)
  Widget _buildFoodHistorySection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Food Summary Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withOpacity(0.1),
                    AppColors.secondaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Food',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          Text(
                            'Tap to view all food entries',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _showAllFoodHistory(),
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.primaryColor,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  /// Build food history item
  Widget _buildFoodHistoryItem(FoodHistoryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToFoodDetail(entry),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Food icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFoodIcon(entry),
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.foodName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.formattedTimestamp,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Calories
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${entry.calories.toStringAsFixed(0)} kcal',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  /// Get food icon based on category
  IconData _getFoodIcon(FoodHistoryEntry entry) {
    final category = entry.category?.toLowerCase();
    if (category == null) return Icons.restaurant;
    
    if (category.contains('fruit') || category.contains('apple') || category.contains('banana')) {
      return Icons.apple;
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return Icons.eco;
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return Icons.grass;
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return Icons.local_drink;
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return Icons.grain;
    } else if (category.contains('drink') || category.contains('beverage')) {
      return Icons.local_cafe;
    } else if (category.contains('snack') || category.contains('chip')) {
      return Icons.cookie;
    } else {
      return Icons.restaurant;
    }
  }

  /// Get food icon color based on category (using app_colors constants)
  Color _getFoodIconColor(FoodHistoryEntry entry) {
    final category = entry.category?.toLowerCase();
    if (category == null) return kPrimaryColor;
    
    if (category.contains('fruit') || category.contains('apple') || category.contains('banana')) {
      return kErrorColor; // Red for fruits
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return kSuccessColor; // Green for vegetables
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return kAccentColor; // Orange/Amber for meat
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return kInfoColor; // Blue for dairy
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return kAccentColor; // Orange/Amber for grains
    } else if (category.contains('drink') || category.contains('beverage')) {
      return kInfoColor; // Blue for drinks
    } else if (category.contains('snack') || category.contains('chip')) {
      return kAccentPurple; // Purple for snacks
    } else {
      return kPrimaryColor;
    }
  }

  /// Get source color based on source type (using app_colors constants)
  Color _getSourceColor(String source) {
    switch (source) {
      case 'camera_scan':
        return kInfoColor; // Blue for camera
      case 'barcode_scan':
        return kSuccessColor; // Green for barcode
      case 'manual_entry':
        return kAccentColor; // Orange/Amber for manual
      default:
        return kPrimaryColor;
    }
  }

  /// Get source icon based on source type
  String _getSourceIcon(String source) {
    switch (source) {
      case 'camera_scan':
        return '📷';
      case 'barcode_scan':
        return '📱';
      case 'manual_entry':
        return '✏️';
      default:
        return '❓';
    }
  }

  /// Navigate to food detail screen
  void _navigateToFoodDetail(FoodHistoryEntry entry) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodHistoryDetailScreen(entry: entry),
      ),
    );
    
    // If entry was deleted, refresh the data
    if (result == true) {
      setState(() {});
    }
  }

  /// Show all food history
  void _showAllFoodHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TodaysFoodScreen(),
      ),
    );
  }





}
