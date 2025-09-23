import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
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
import '../services/calorie_units_service.dart';
import '../services/analytics_service.dart';
import '../services/goals_event_bus.dart';
import '../services/google_fit_service.dart';
import '../services/google_fit_cache_service.dart';
import '../services/optimized_google_fit_service.dart';
import '../services/global_goals_manager.dart';
import '../services/global_google_fit_manager.dart';
import '../mixins/google_fit_sync_mixin.dart';
import '../services/simple_goals_notifier.dart';
import '../services/rewards_service.dart';
import '../models/reward_system.dart';
import '../widgets/simple_streak_widgets.dart';
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
        GoogleFitSyncMixin,
        GoogleFitDataDisplayMixin {
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
  final GoogleFitService _googleFitService = GoogleFitService();
  final GoogleFitCacheService _googleFitCacheService = GoogleFitCacheService();
  final OptimizedGoogleFitService _optimizedGoogleFitService = OptimizedGoogleFitService();
  final GlobalGoogleFitManager _globalGoogleFitManager =
      GlobalGoogleFitManager();
  final TaskService _taskService = TaskService();
  final FastDataRefreshService _fastDataRefreshService = FastDataRefreshService();
  final TodaysFoodDataService _todaysFoodDataService = TodaysFoodDataService();

  // Data
  DailySummary? _dailySummary;
  MacroBreakdown? _macroBreakdown;
  UserPreferences _preferences = const UserPreferences();
  String _motivationalQuote = '';
  final bool _isLoading = false; // Start with false to show UI immediately
  bool _isRefreshing = false; // Track background data loading
  bool _isRefreshingFoodData = false; // Prevent multiple simultaneous food data refreshes
  
  // Debouncing for UI updates
  Timer? _uiUpdateTimer;
  bool _hasPendingUIUpdate = false;
  
  // UI update throttling
  DateTime? _lastUIUpdate;
  static const Duration _minUIUpdateInterval = Duration(milliseconds: 300); // Reduced from 800ms to 300ms

  // Rewards data
  UserProgress? _userProgress;
  List<UserReward> _recentRewards = [];
  bool _isStreakLoading = true;

  // Google Fit data
  bool _isGoogleFitConnected = false;
  int? _googleFitSteps;
  double? _googleFitCaloriesBurned;
  double? _googleFitDistance;
  String _activityLevel = 'Unknown';
  bool _isLiveSyncing = false;
  bool _isGoogleFitLoading = false;
  DateTime? _lastSyncTime;

  // Task management
  List<Task> _tasks = [];
  bool _isTasksLoading = true;
  bool _hasUserTasks = false;

  // Stream subscriptions
  StreamSubscription<DailySummary?>? _dailySummarySubscription;
  StreamSubscription<MacroBreakdown>? _macroBreakdownSubscription;
  StreamSubscription<UserPreferences>? _preferencesSubscription;
  StreamSubscription<UserGoals?>? _goalsSubscription;
  StreamSubscription<UserGoals>? _goalsEventBusSubscription;
  StreamSubscription<List<Task>>? _tasksSubscription;
  StreamSubscription<Map<String, dynamic>>? _googleFitLiveStreamSubscription;
  StreamSubscription? _googleFitCacheStreamSubscription;
  StreamSubscription<int>? _consumedCaloriesSubscription;
  StreamSubscription<List<FoodHistoryEntry>>? _todaysFoodSubscription;
  StreamSubscription<Map<String, dynamic>>? _fastMacroBreakdownSubscription;
  StreamSubscription<int>? _todaysFoodCaloriesSubscription;
  StreamSubscription<Map<String, double>>? _todaysFoodMacroSubscription;
  Timer? _goalsCheckTimer;
  Timer? _googleFitRefreshTimer;
  Timer? _streakRefreshTimer;
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

    // Initialize immediately without waiting
    _initializeServicesAsync();
    _setupStreamListeners();
    _setupTodaysFoodDataService();
    _loadData();
    _loadRewardsDataAsync();
    _initializeGoogleFitAsync();
    initializeGoogleFitSync();
    
    // Set up periodic streak refresh to ensure data stays current
    _setupPeriodicStreakRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh goals when screen becomes visible
    _forceRefreshGoals();
    
    // Refresh consumed calories and macro nutrients when screen becomes visible
    _refreshFoodData();
  }

  /// Setup today's food data service for immediate UI updates
  Future<void> _setupTodaysFoodDataService() async {
    try {
      await _todaysFoodDataService.initialize();
      
      // INSTANT: Load cached data immediately for instant UI display
      final cachedCalories = _todaysFoodDataService.getCachedConsumedCalories();
      final cachedMacros = _todaysFoodDataService.getCachedMacroNutrients();
      
      if (cachedCalories > 0 || cachedMacros.isNotEmpty) {
        setState(() {
          // Update consumed calories immediately
          if (_dailySummary != null) {
            _dailySummary = _dailySummary!.copyWith(caloriesConsumed: cachedCalories);
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
        print('✅ Home: Loaded cached data immediately - Calories: $cachedCalories');
      }
      
      // Listen to consumed calories stream (same data as TodaysFoodScreen)
      _todaysFoodCaloriesSubscription = _todaysFoodDataService.consumedCaloriesStream.listen((calories) {
        _debounceUIUpdate(() {
          if (mounted && _dailySummary != null) {
            _dailySummary = _dailySummary!.copyWith(caloriesConsumed: calories);
          }
        });
      });

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

  /// Initialize Google Fit asynchronously
  Future<void> _initializeGoogleFitAsync() async {
    _initializeGoogleFit()
        .catchError((e) => debugPrint('Google Fit initialization error: $e'));
    _initializeGoogleFitCache().catchError(
        (e) => debugPrint('Google Fit cache initialization error: $e'));
  }

  Future<void> _initializeServices() async {
    await _realTimeInputService.initialize();
    await _dailySummaryService.initialize();
    await _streakService.initialize();
    await _enhancedStreakService.initialize();
    await _taskService.initialize();
    await _calorieUnitsService.initialize();
    _currentUserId = _realTimeInputService.getCurrentUserId();
  }

  void _setupStreamListeners() {
    // Listen to real-time data updates (non-blocking)
    try {
      // Listen to daily summary updates from real-time service
      if (_currentUserId != null) {
        _realTimeInputService
            .getTodaySummary(_currentUserId!)
            .listen((summary) {
          if (mounted) {
            setState(() {
              _dailySummary = summary;
            });
          }
        }).onError((error) {
          debugPrint('Daily summary stream error: $error');
        });

        // Listen to enhanced streak updates
        _enhancedStreakService.streakStream.listen((streakSummary) {
          if (mounted) {
            setState(() {
              _streakSummary = streakSummary;
            });
          }
        }).onError((error) {
          debugPrint('Enhanced streak stream error: $error');
        });

        // Listen to task updates with optimized state management
        _taskService.tasksStream.listen((tasks) {
          debugPrint('📋 Task stream received ${tasks.length} tasks');
          debugPrint('📋 Task titles: ${tasks.map((t) => t.title).toList()}');
          if (mounted) {
            // Only update state if tasks actually changed and we're not in the middle of a manual update
            if (_tasks.length != tasks.length || 
                !_listsEqual(_tasks, tasks)) {
              // Add a delay to prevent conflicts with manual updates
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    _tasks = tasks;
                    _isTasksLoading = false;
                    _hasUserTasks = _taskService.hasUserTasks();
                  });
                  debugPrint('📋 UI updated with ${_tasks.length} tasks, hasUserTasks: $_hasUserTasks');
                }
              });
            }
            
            // Add example tasks if user has no tasks and we haven't loaded any yet
            if (tasks.isEmpty && !_hasUserTasks && !_taskService.hasExampleTasksAdded) {
              debugPrint('📋 No tasks found, adding example tasks...');
              _taskService.addExampleTasks();
            }
          }
        }).onError((error) {
          debugPrint('❌ Task stream error: $error');
          if (mounted) {
            setState(() {
              _isTasksLoading = false;
            });
          }
        });

        // Fallback: Load tasks directly after a delay if stream doesn't work
        Timer(const Duration(seconds: 5), () {
          if (_isTasksLoading && mounted) {
            debugPrint('📋 Task stream timeout, loading tasks directly...');
            _loadTasksData();
          }
        });
      }

      // Keep existing app state service listeners for backward compatibility
      _appStateService.macroBreakdownStream.listen((breakdown) {
        if (mounted) {
          setState(() {
            _macroBreakdown = breakdown;
          });
        }
      }).onError((error) {
        debugPrint('Macro breakdown stream error: $error');
      });

      _appStateService.preferencesStream.listen((preferences) {
        if (mounted) {
          setState(() {
            _preferences = preferences;
          });
        }
      }).onError((error) {
        debugPrint('Preferences stream error: $error');
      });

      // Goals stream listener is now in _setupDataListeners() to ensure AppStateService is initialized
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
    _googleFitRefreshTimer?.cancel();
    _streakRefreshTimer?.cancel();
    _googleFitLiveStreamSubscription?.cancel();
    _googleFitCacheStreamSubscription?.cancel();
    _consumedCaloriesSubscription?.cancel();
    _todaysFoodSubscription?.cancel();
    _fastMacroBreakdownSubscription?.cancel();
    _todaysFoodCaloriesSubscription?.cancel();
    _todaysFoodMacroSubscription?.cancel();
    _uiUpdateTimer?.cancel();
    _googleFitCacheService.stopLiveUpdates();
    _googleFitCacheService.dispose();
    _fastDataRefreshService.dispose();
    _todaysFoodDataService.dispose();
    _stopLiveSync();
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

  Future<void> _loadData() async {
    try {
      // Load cached data first (non-blocking)
      _loadCachedDataImmediate();

      // Set up real-time data listeners immediately
      _setupDataListeners();

      // Initialize AppStateService with timeout (non-blocking)
      _initializeAppStateAsync();

      // Load fresh data in background (non-blocking)
      _loadFreshDataAsync();
      
      // Force refresh goals to ensure UI is up to date
      _forceRefreshGoals();
    } catch (e) {
      // Handle error silently in production
      debugPrint('Error loading home data: $e');
    }
  }

  /// Load cached data immediately to show something to user
  void _loadCachedDataImmediate() {
    try {
      // Load cached summary if available
      _dailySummary ??= DailySummary(
        caloriesConsumed: 0,
        caloriesBurned: 0,
        caloriesGoal: 2000,
        steps: 0,
        stepsGoal: 10000,
        waterGlasses: 0,
        waterGlassesGoal: 8,
        date: DateTime.now(),
      );

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

  /// Load consumed calories from food history
  Future<void> _loadConsumedCaloriesFromFoodHistory() async {
    try {
      // Get consumed calories from food history
      final consumedCalories = await FoodHistoryService.getTodaysConsumedCalories();
      
      if (mounted) {
        setState(() {
          if (_dailySummary != null) {
            _dailySummary = _dailySummary!.copyWith(caloriesConsumed: consumedCalories);
          }
        });
      }
      
      print('✅ Loaded consumed calories from food history: $consumedCalories');
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
    _uiUpdateTimer = Timer(const Duration(milliseconds: 200), () { // Reduced from 500ms to 200ms
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
      print('⚠️ Food data refresh already in progress, skipping...');
      return;
    }
    
    try {
      _isRefreshingFoodData = true;
      
      // Force refresh to get fresh data and clear any stale cache
      await _fastDataRefreshService.forceRefresh();
      
      // Also manually refresh consumed calories and macro data to ensure accuracy
      await _loadConsumedCaloriesFromFoodHistory();
      await _loadMacroNutrientsFromFoodHistory();
      
      print('✅ Refreshed food data when screen became visible');
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

  /// Load rewards data
  Future<void> _loadRewardsData() async {
    try {
      await _rewardsService.initialize();

      // Listen to progress updates
      _rewardsService.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _userProgress = progress;
          });
        }
      });

      // Listen to new rewards
      _rewardsService.newRewardsStream.listen((rewards) {
        if (mounted) {
          setState(() {
            _recentRewards = rewards.take(3).toList(); // Show only recent 3
          });
        }
      });
    } catch (e) {
      print('Error loading rewards data: $e');
    }
  }

  /// Initialize Google Fit service and load data (with persistence and RAM clearing support)
  Future<void> _initializeGoogleFit() async {
    try {
      // Initialize both services
      await _googleFitService.initialize();
      await _optimizedGoogleFitService.initialize();

      // Check authentication status immediately
      final isAuthenticated = await _googleFitService.validateAuthentication();
      setState(() {
        _isGoogleFitConnected = isAuthenticated;
      });

      if (_isGoogleFitConnected) {
        // Load Google Fit data immediately for instant UI update using optimized service
        await _loadGoogleFitDataOptimized();

        // Start live sync for real-time updates
        _startLiveSync();
        _startGoogleFitRefreshTimer();

        print('Google Fit initialized and connected - UI updated instantly with optimized service');
      } else {
        print('Google Fit not connected - user needs to authenticate');
      }
    } catch (e) {
      print('Error initializing Google Fit: $e');
      setState(() {
        _isGoogleFitConnected = false;
      });
    }
  }

  /// Initialize Google Fit cache service for enhanced performance
  Future<void> _initializeGoogleFitCache() async {
    try {
      await _googleFitCacheService.initialize();

      // Listen to cached data stream for real-time updates
      _googleFitCacheStreamSubscription =
          _googleFitCacheService.liveDataStream.listen((data) {
        if (mounted) {
          setState(() {
            _googleFitSteps = data.steps ?? 0;
            _googleFitCaloriesBurned = data.caloriesBurned ?? 0.0;
            _googleFitDistance = data.distance ?? 0.0;
            _activityLevel = _calculateActivityLevel(data.steps);
            _lastSyncTime = DateTime.now();
          });

          // Update daily summary if available
          if (_dailySummary != null) {
            _updateDailySummaryWithGoogleFitData();
          }
        }
      });

      // Start live updates for enhanced real-time experience
      _googleFitCacheService.startLiveUpdates();

      print('Google Fit cache service initialized with real-time updates');
    } catch (e) {
      print('Error initializing Google Fit cache service: $e');
    }
  }

  /// Override mixin method to handle Google Fit data updates
  @override
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    super.onGoogleFitDataUpdate(syncData);

    if (mounted) {
      setState(() {
        _googleFitSteps = syncData['steps'] as int? ?? 0;
        _googleFitCaloriesBurned =
            (syncData['caloriesBurned'] as num?)?.toDouble() ?? 0.0;
        _googleFitDistance = (syncData['distance'] as num?)?.toDouble() ?? 0.0;
        _activityLevel = _calculateActivityLevel(syncData['steps'] as int?);
        _lastSyncTime = DateTime.now();
      });

      // Update daily summary if available
      if (_dailySummary != null) {
        _updateDailySummaryWithGoogleFitData();
      }

      print(
          'Home screen: Updated with global Google Fit data - Steps: ${syncData['steps']}');
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
        print('Home screen: Google Fit connected via global manager');
        _loadGoogleFitData();
        _startLiveSync();
      } else {
        print('Home screen: Google Fit disconnected via global manager');
        _stopLiveSync();
      }
    }
  }

  /// Load Google Fit data asynchronously
  Future<void> _loadGoogleFitDataAsync() async {
    try {
      await _loadGoogleFitData();
      _startLiveSync();
      _startGoogleFitRefreshTimer();
    } catch (e) {
      print('Error loading Google Fit data asynchronously: $e');
    }
  }

  /// Load Google Fit data using optimized service with caching
  Future<void> _loadGoogleFitDataOptimized() async {
    if (!_isGoogleFitConnected) return;

    setState(() {
      _isGoogleFitLoading = true;
    });

    try {
      // Use optimized service with caching
      final fitnessData = await _optimizedGoogleFitService.getOptimizedFitnessData();

      if (fitnessData != null) {
        final steps = fitnessData['steps'] as int? ?? 0;
        final calories = fitnessData['caloriesBurned'] as double? ?? 0.0;
        final distance = fitnessData['distance'] as double? ?? 0.0;
        final weight = fitnessData['weight'] as double?;

        setState(() {
          _googleFitSteps = steps;
          _googleFitCaloriesBurned = calories;
          _googleFitDistance = distance;
          _activityLevel = fitnessData['activityLevel'] ?? 'Unknown';
          _lastSyncTime = DateTime.now();
        });

        // Update daily summary with Google Fit data if available
        if (_dailySummary != null) {
          await _updateDailySummaryWithGoogleFitData();
        }

        print('Google Fit data loaded (optimized): Steps=$steps, Calories=$calories, Distance=$distance');
      } else {
        // Fallback to original service if optimized fails
        await _loadGoogleFitDataFallback();
      }
    } catch (e) {
      print('Error loading optimized Google Fit data: $e');
      // Try fallback method
      await _loadGoogleFitDataFallback();
    } finally {
      setState(() {
        _isGoogleFitLoading = false;
      });
    }
  }

  /// Load Google Fit data and update UI (optimized with caching)
  Future<void> _loadGoogleFitData() async {
    if (!_isGoogleFitConnected) return;

    setState(() {
      _isGoogleFitLoading = true;
    });

    try {
      // Use the batch method for faster response
      final batchData = await _googleFitService.getTodayFitnessDataBatch();

      if (batchData != null) {
        final steps = batchData['steps'] as int? ?? 0;
        final calories = batchData['caloriesBurned'] as double? ?? 0.0;
        final distance = batchData['distance'] as double? ?? 0.0;

        setState(() {
          _googleFitSteps = steps;
          _googleFitCaloriesBurned = calories;
          _googleFitDistance = distance;
          _activityLevel = batchData['activityLevel'] ?? 'Unknown';
          _lastSyncTime = DateTime.now();
        });

        // Update daily summary with Google Fit data if available
        if (_dailySummary != null) {
          await _updateDailySummaryWithGoogleFitData();
        }

        print(
            'Google Fit data loaded (batch): Steps=$steps, Calories=$calories, Distance=$distance');
      } else {
        // Fallback to individual calls if batch fails
        await _loadGoogleFitDataFallback();
      }
    } catch (e) {
      print('Error loading Google Fit data: $e');
      // Try fallback method
      await _loadGoogleFitDataFallback();
    } finally {
      setState(() {
        _isGoogleFitLoading = false;
      });
    }
  }

  /// Fallback method for loading Google Fit data
  Future<void> _loadGoogleFitDataFallback() async {
    try {
      final today = DateTime.now();

      // Individual API calls with error handling
      final steps =
          await _googleFitService.getDailySteps(today).catchError((e) {
                print('Steps fetch failed: $e');
                return 0;
              }) ??
              0;

      final calories =
          await _googleFitService.getDailyCaloriesBurned(today).catchError((e) {
                print('Calories fetch failed: $e');
                return 0.0;
              }) ??
              0.0;

      final distance =
          await _googleFitService.getDailyDistance(today).catchError((e) {
                print('Distance fetch failed: $e');
                return 0.0;
              }) ??
              0.0;

      setState(() {
        _googleFitSteps = steps;
        _googleFitCaloriesBurned = calories;
        _googleFitDistance = distance;
        _activityLevel = _calculateActivityLevel(steps);
        _lastSyncTime = DateTime.now();
      });

      if (_dailySummary != null) {
        await _updateDailySummaryWithGoogleFitData();
      }

      print(
          'Google Fit data loaded (fallback): Steps=$steps, Calories=$calories, Distance=$distance');
    } catch (e) {
      print('Fallback Google Fit loading failed: $e');
      setState(() {
        _googleFitSteps = 0;
        _googleFitCaloriesBurned = 0.0;
        _googleFitDistance = 0.0;
        _activityLevel = 'Unknown';
        _lastSyncTime = DateTime.now();
      });
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
    if (_dailySummary == null || !_isGoogleFitConnected) return;

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

      setState(() {
        _dailySummary = updatedSummary;
      });
    } catch (e) {
      print('Error updating daily summary with Google Fit data: $e');
    }
  }

  /// Connect to Google Fit
  Future<void> _connectToGoogleFit() async {
    try {
      final success = await _googleFitService.authenticate();
      if (success) {
        setState(() {
          _isGoogleFitConnected = true;
        });
        await _loadGoogleFitData();
        _startLiveSync();

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

  /// Refresh Google Fit data (called periodically or on user interaction)
  Future<void> _refreshGoogleFitData() async {
    if (_isGoogleFitConnected) {
      await _loadGoogleFitData();
    }
  }

  /// Start live sync for Google Fit data (optimized for speed)
  void _startLiveSync() {
    if (!_isGoogleFitConnected) return;

    _googleFitService.startLiveSync();

    // Listen to live data stream with immediate updates
    _googleFitLiveStreamSubscription?.cancel();
    _googleFitLiveStreamSubscription =
        _googleFitService.liveDataStream?.listen((liveData) {
      if (mounted && liveData['isLive'] == true) {
        // Immediate UI update for faster response
        setState(() {
          _isLiveSyncing = true;
          _lastSyncTime = DateTime.now();

          // Update data immediately
          if (liveData['steps'] != null) _googleFitSteps = liveData['steps'];
          if (liveData['caloriesBurned'] != null)
            _googleFitCaloriesBurned = liveData['caloriesBurned'];
          if (liveData['distance'] != null)
            _googleFitDistance = liveData['distance'];
          if (liveData['activityLevel'] != null)
            _activityLevel = liveData['activityLevel'];
        });

        // Update daily summary immediately
        if (_dailySummary != null) {
          _updateDailySummaryWithGoogleFitData();
        }

        // Quick reset of live sync indicator
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLiveSyncing = false;
            });
          }
        });
      }
    });
  }

  /// Stop live sync
  void _stopLiveSync() {
    _googleFitService.stopLiveSync();
    _googleFitLiveStreamSubscription?.cancel();
    _googleFitLiveStreamSubscription = null;
    _isLiveSyncing = false;
  }

  /// Start periodic refresh timer for Google Fit data (backup)
  void _startGoogleFitRefreshTimer() {
    _googleFitRefreshTimer?.cancel();
    _googleFitRefreshTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshGoogleFitData();
    });
  }

  /// Stop Google Fit refresh timer
  void _stopGoogleFitRefreshTimer() {
    _googleFitRefreshTimer?.cancel();
    _googleFitRefreshTimer = null;
  }

  /// Set up periodic streak refresh to ensure data stays current
  void _setupPeriodicStreakRefresh() {
    _streakRefreshTimer?.cancel();
    _streakRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _refreshStreaksPeriodically();
    });
    debugPrint('Periodic streak refresh timer set up');
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

  /// Set up real-time data listeners from AppStateService
  void _setupDataListeners() {
    // Listen to daily summary updates
    _dailySummarySubscription?.cancel();
    _dailySummarySubscription =
        _appStateService.dailySummaryStream.listen((summary) async {
      if (mounted) {
        setState(() {
          _dailySummary = summary;
        });
        
        // Refresh streaks when daily summary changes
        try {
          await _enhancedStreakService.refreshStreaks();
        } catch (e) {
          debugPrint('Error refreshing streaks after daily summary update: $e');
        }
      }
    });

    // Listen to macro breakdown updates
    _macroBreakdownSubscription?.cancel();
    _macroBreakdownSubscription =
        _appStateService.macroBreakdownStream.listen((breakdown) {
      if (mounted) {
        setState(() {
          _macroBreakdown = breakdown;
        });
      }
    });

    // Listen to preferences updates
    _preferencesSubscription?.cancel();
    _preferencesSubscription =
        _appStateService.preferencesStream.listen((preferences) {
      if (mounted) {
        setState(() {
          _preferences = preferences;
        });
      }
    });

    // Health data functionality removed

    // Listen to goals updates
    debugPrint('Setting up goals stream listener in _setupDataListeners');
    _goalsSubscription?.cancel();
    _goalsSubscription = _appStateService.goalsStream.listen(
      (goals) async {
        debugPrint('=== HOME SCREEN GOALS STREAM UPDATE ===');
        debugPrint('Received goals update: ${goals?.toMap()}');
        debugPrint(
            'Current daily summary before update: ${_dailySummary?.toMap()}');
        if (mounted) {
          // Force a complete refresh of the daily summary
          await _refreshDailySummaryWithNewGoals(goals);
          debugPrint('Daily summary after update: ${_dailySummary?.toMap()}');
          debugPrint(
              'UI should now show updated goals: Calorie=${goals?.calorieGoal}, Steps=${goals?.stepsPerDayGoal}, Water=${goals?.waterGlassesGoal}');
          
          // Force UI refresh to ensure changes are visible
          setState(() {
            // Trigger a rebuild to show updated goals
          });
        }
        debugPrint('=== END HOME SCREEN GOALS STREAM UPDATE ===');
      },
      onError: (error) {
        debugPrint('Goals stream error: $error');
      },
    );
    debugPrint('Goals stream listener set up successfully');

    // Listen to goals event bus for immediate updates
    _goalsEventBusSubscription?.cancel();
    _goalsEventBusSubscription = GoalsEventBus().goalsStream.listen(
      (goals) async {
        debugPrint('=== HOME SCREEN GOALS EVENT BUS UPDATE ===');
        debugPrint('Received goals update via event bus: ${goals.toMap()}');
        if (mounted) {
          // Force a complete refresh of the daily summary
          await _refreshDailySummaryWithNewGoals(goals);
        }
        debugPrint('=== END HOME SCREEN GOALS EVENT BUS UPDATE ===');
      },
      onError: (error) {
        debugPrint('Goals event bus error: $error');
      },
    );
    debugPrint('Goals event bus listener set up successfully');

    // Register global callback for immediate goals updates
    GlobalGoalsManager().setGoalsUpdateCallback((goals) async {
      debugPrint('=== GLOBAL GOALS CALLBACK TRIGGERED ===');
      debugPrint('Received goals update via global callback: ${goals.toMap()}');
      if (mounted) {
        await _refreshDailySummaryWithNewGoals(goals);
        // Also force a complete UI refresh
        forceUIRefresh();
      }
      debugPrint('=== END GLOBAL GOALS CALLBACK ===');
    });
    debugPrint('Global goals callback registered');

    // Set up periodic goals check
    _goalsCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkForGoalsUpdate();
    });
    debugPrint('Periodic goals check timer set up');

    // Listen to achievements updates
    _analyticsService.achievementsStream.listen((achievements) {
      if (mounted) {
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
  Future<void> _refreshDailySummaryWithNewGoals(UserGoals? goals) async {
    debugPrint('=== REFRESHING DAILY SUMMARY WITH NEW GOALS ===');
    debugPrint('New goals: ${goals?.toMap()}');
    debugPrint(
        'Current daily summary before update: ${_dailySummary?.toMap()}');

    if (mounted) {
      setState(() {
        // Goals updated - refresh daily summary with new goals
        if (_dailySummary != null) {
          _dailySummary = _dailySummary!.copyWith(
            caloriesGoal: goals?.calorieGoal ?? 2000,
            stepsGoal: goals?.stepsPerDayGoal ?? 10000,
            waterGlassesGoal: goals?.waterGlassesGoal ?? 8,
          );
          debugPrint('Updated existing daily summary with new goals');
        } else {
          _dailySummary = _getEmptyDailySummary();
          debugPrint('Created new daily summary with goals');
        }
        debugPrint('Daily summary after setState: ${_dailySummary?.toMap()}');
      });

      // Save updated daily summary to Firestore with new goals
      try {
        await _saveDailySummaryToFirestore();
        debugPrint('Daily summary saved to Firestore successfully');
      } catch (e) {
        debugPrint('Error saving updated daily summary: $e');
      }

      // Recalculate streaks and achievements based on new goals
      try {
        await _analyticsService.calculateStreaksAndAchievements();
        await _enhancedStreakService.refreshStreaks();
        debugPrint('Streaks and achievements recalculated successfully');
      } catch (e) {
        debugPrint('Error recalculating streaks and achievements: $e');
      }
    }
    debugPrint('=== END REFRESHING DAILY SUMMARY WITH NEW GOALS ===');
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
      debugPrint('Force refreshing goals...');
      final currentGoals = _appStateService.userGoals;
      if (currentGoals != null) {
        debugPrint('Current goals from AppState: ${currentGoals.toMap()}');
        await _refreshDailySummaryWithNewGoals(currentGoals);
        debugPrint('Goals force refreshed successfully');
      } else {
        debugPrint('No goals available in AppState');
      }
    } catch (e) {
      debugPrint('Error force refreshing goals: $e');
    }
  }

  /// Check for goals update periodically
  void _checkForGoalsUpdate() {
    if (!mounted) return;

    final simpleGoals = SimpleGoalsNotifier().currentGoals;
    final appStateGoals = _appStateService.userGoals;

    debugPrint('Periodic goals check - Simple: ${simpleGoals?.toMap()}, AppState: ${appStateGoals?.toMap()}');

    // Check if goals have changed
    if (simpleGoals != null && appStateGoals != null) {
      if (simpleGoals.calorieGoal != appStateGoals.calorieGoal ||
          simpleGoals.stepsPerDayGoal != appStateGoals.stepsPerDayGoal ||
          simpleGoals.waterGlassesGoal != appStateGoals.waterGlassesGoal) {
        debugPrint('Goals change detected via periodic check - refreshing UI');
        _refreshDailySummaryWithNewGoals(simpleGoals);
      }
    } else if (simpleGoals != null && appStateGoals == null) {
      debugPrint('Simple goals available but AppState goals null - refreshing with simple goals');
      _refreshDailySummaryWithNewGoals(simpleGoals);
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
        _dailySummary = _dailySummary!.copyWith(caloriesConsumed: value);
      } else {
        _dailySummary = _dailySummary!.copyWith(caloriesBurned: value);
      }
    });

    // Save to Firestore or local storage
    await _saveDailySummaryToFirestore();
    
    // Refresh streaks after calorie update
    try {
      await _enhancedStreakService.refreshStreaks();
    } catch (e) {
      debugPrint('Error refreshing streaks after calorie update: $e');
    }
  }

  /// Update water glasses value and save to Firestore
  Future<void> _updateWaterGlassesValue(int value) async {
    _dailySummary ??= _getEmptyDailySummary();

    setState(() {
      _dailySummary = _dailySummary!.copyWith(waterGlasses: value);
    });

    await _saveDailySummaryToFirestore();
    
    // Refresh streaks after water update
    try {
      await _enhancedStreakService.refreshStreaks();
    } catch (e) {
      debugPrint('Error refreshing streaks after water update: $e');
    }
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
    
    // Refresh streaks after water target update
    try {
      await _enhancedStreakService.refreshStreaks();
    } catch (e) {
      debugPrint('Error refreshing streaks after water target update: $e');
    }
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
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.green, size: 16),
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
      // Provide immediate fallback data for better UX
      _streakSummary = _getDefaultStreakData();
      setState(() => _isStreakLoading = false);

      // Load actual streak data from the enhanced streak service
      _streakSummary = _enhancedStreakService.currentStreaks;
      if (mounted) {
        setState(() => _isStreakLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading streak data: $e');
      if (mounted) {
        setState(() => _isStreakLoading = false);
      }
    }
  }

  /// Load tasks data with fallback
  Future<void> _loadTasksData() async {
    try {
      debugPrint('📋 Loading tasks data...');
      final tasks = await _taskService.getTasks();
      debugPrint('📋 Loaded ${tasks.length} tasks from service');
      
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

  UserStreakSummary _getDefaultStreakData() {
    final goalStreaks = <DailyGoalType, GoalStreak>{};

    for (final goalType in DailyGoalType.values) {
      goalStreaks[goalType] = GoalStreak(
        goalType: goalType,
        currentStreak: 0,
        longestStreak: 0,
        lastAchievedDate: DateTime.now().subtract(const Duration(days: 1)),
        achievedToday: false,
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
              onRefresh: _loadData,
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 40,
              ),
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

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
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
                // Date badge
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
                  child: GestureDetector(
                    onTap: () => _showCalorieInputDialog('consumed'),
                    child: _buildEnhancedSummaryCard(
                      'Consumed',
                      _calorieUnitsService.formatCaloriesShort(
                          summary.caloriesConsumed.toDouble()),
                      _calorieUnitsService.unitSuffix,
                      Icons.restaurant,
                      Colors.green[600]!,
                      'Tap to edit calories consumed',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCalorieInputDialog('burned'),
                    child: _buildEnhancedSummaryCard(
                      'Burned',
                      _calorieUnitsService.formatCaloriesShort(
                          summary.caloriesBurned.toDouble()),
                      _calorieUnitsService.unitSuffix,
                      Icons.directions_run,
                      Colors.red[600]!,
                      'Tap to edit calories burned',
                    ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.left,
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
    final fitnessGoal = userGoals?.fitnessGoal ?? 'maintenance';
    
    // Calculate remaining calories based on fitness goal
    final caloriesToTarget = FitnessGoalCalculator.calculateRemainingCalories(
      fitnessGoal: fitnessGoal,
      caloriesConsumed: _dailySummary!.caloriesConsumed,
      caloriesBurned: _dailySummary!.caloriesBurned,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.left,
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
                    '${_dailySummary?.steps ?? 0}',
                    '${_dailySummary?.stepsGoal ?? 10000}',
                    'steps',
                    Icons.directions_walk,
                    kSecondaryColor,
                    (_dailySummary?.stepsProgress ?? 0.0) * 100,
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
      height: 180, // Fixed height for consistent sizing
      padding: const EdgeInsets.all(18),
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
                  fontSize: 28,
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
            else if (_tasks.isEmpty && !_hasUserTasks)
              ExampleTasksWidget(
                onAddTask: () => _showAddTaskDialog(),
              )
            else
              ..._tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  onToggleCompletion: () => _toggleTaskCompletion(task.id),
                  onDelete: () => _deleteTask(task.id),
                ),
              )),
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

  /// Show rewards details dialog
  void _showRewardsDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRewardsBottomSheet(),
    );
  }

  /// Build rewards bottom sheet
  Widget _buildRewardsBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rewards & Achievements',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weekly Streak Calendar
                  WeeklyStreakCalendar(
                    goalStreaks: _streakSummary.goalStreaks,
                    weekStart: DateTime.now()
                        .subtract(Duration(days: DateTime.now().weekday - 1)),
                  ),
                  const SizedBox(height: 24),

                  // Goal Streaks
                  _buildGoalStreaksSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build goal streaks section
  Widget _buildGoalStreaksSection() {
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
                  color: kAccentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up,
                    color: kAccentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Daily Goal Streaks',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isStreakLoading)
            ...List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GoalStreakCard(
                  streak: _streakSummary.goalStreaks.values.first,
                  isLoading: true,
                  onTap: () {},
                ),
              ),
            )
          else
            ..._streakSummary.goalStreaks.values.map(
              (streak) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GoalStreakCard(
                  streak: streak,
                  onTap: () {
                    // Handle goal tap if needed
                  },
                ),
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

                  // Streak Motivation
                  StreakMotivationWidget(
                    streakSummary: _streakSummary,
                  ),
                  const SizedBox(height: 40),
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
                       streak.lastActivityDate != null &&
                       streak.lastActivityDate!.day == date.day &&
                       streak.lastActivityDate!.month == date.month &&
                       streak.lastActivityDate!.year == date.year;
              });
              
              // Check if this date has rewards (simplified - could be enhanced)
              final hasReward = false; // Could be enhanced with actual reward data

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
          _loadData();
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
        // Show success message INSTANTLY (no delays)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task added'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(milliseconds: 800),
          ),
        );
        
        // FORCE immediate UI update - bypass stream completely
        _refreshTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add task'),
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
            content: Text('Task updated'),
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
            content: Text('Failed to update task'),
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
            content: Text('Task deleted'),
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
            content: Text('Failed to delete task'),
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
                        child: Icon(
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
                      icon: Icon(
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

  /// Get food icon color based on category
  Color _getFoodIconColor(FoodHistoryEntry entry) {
    final category = entry.category?.toLowerCase();
    if (category == null) return AppColors.primaryColor;
    
    if (category.contains('fruit') || category.contains('apple') || category.contains('banana')) {
      return Colors.red[600]!;
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return Colors.green[600]!;
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return Colors.brown[600]!;
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return Colors.blue[600]!;
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return Colors.orange[600]!;
    } else if (category.contains('drink') || category.contains('beverage')) {
      return Colors.cyan[600]!;
    } else if (category.contains('snack') || category.contains('chip')) {
      return Colors.purple[600]!;
    } else {
      return AppColors.primaryColor;
    }
  }

  /// Get source color based on source type
  Color _getSourceColor(String source) {
    switch (source) {
      case 'camera_scan':
        return Colors.blue[600]!;
      case 'barcode_scan':
        return Colors.green[600]!;
      case 'manual_entry':
        return Colors.orange[600]!;
      default:
        return AppColors.primaryColor;
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
