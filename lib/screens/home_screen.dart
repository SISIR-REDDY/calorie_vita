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
import '../services/calorie_units_service.dart';
import '../services/analytics_service.dart';
import '../services/goals_event_bus.dart';
import '../services/google_fit_service.dart';
import '../services/google_fit_cache_service.dart';
import '../services/global_goals_manager.dart';
import '../services/global_google_fit_manager.dart';
import '../mixins/google_fit_sync_mixin.dart';
import '../services/simple_goals_notifier.dart';
import '../services/rewards_service.dart';
import '../models/reward_system.dart';
import '../widgets/simple_streak_widgets.dart';
import 'camera_screen.dart';
import 'trainer_screen.dart';
import '../models/user_preferences.dart';

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
  final CalorieUnitsService _calorieUnitsService = CalorieUnitsService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final RewardsService _rewardsService = RewardsService();
  final GoogleFitService _googleFitService = GoogleFitService();
  final GoogleFitCacheService _googleFitCacheService = GoogleFitCacheService();
  final GlobalGoogleFitManager _globalGoogleFitManager =
      GlobalGoogleFitManager();

  // Data
  DailySummary? _dailySummary;
  MacroBreakdown? _macroBreakdown;
  UserPreferences _preferences = const UserPreferences();
  String _motivationalQuote = '';
  final bool _isLoading = false; // Start with false to show UI immediately
  bool _isRefreshing = false; // Track background data loading

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

  // Stream subscriptions
  StreamSubscription<DailySummary?>? _dailySummarySubscription;
  StreamSubscription<MacroBreakdown>? _macroBreakdownSubscription;
  StreamSubscription<UserPreferences>? _preferencesSubscription;
  StreamSubscription<UserGoals?>? _goalsSubscription;
  StreamSubscription<UserGoals>? _goalsEventBusSubscription;
  StreamSubscription<Map<String, dynamic>>? _googleFitLiveStreamSubscription;
  StreamSubscription? _googleFitCacheStreamSubscription;
  Timer? _goalsCheckTimer;
  Timer? _googleFitRefreshTimer;
  UserStreakSummary _streakSummary = UserStreakSummary(
    goalStreaks: {},
    totalActiveStreaks: 0,
    longestOverallStreak: 0,
    lastActivityDate: DateTime.now(),
    totalDaysActive: 0,
  );
  List<UserAchievement> _achievements = [];
  String? _currentUserId;

  // Task management
  final List<Map<String, dynamic>> _tasks = [
    {
      'id': 'task_1',
      'emoji': DynamicIconService().generateIcon('Drink 8 glasses of water'),
      'title': 'Drink 8 glasses of water',
      'isCompleted': false,
      'priority': 'High',
      'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': 'task_2',
      'emoji': DynamicIconService().generateIcon('30 minutes morning walk'),
      'title': '30 minutes morning walk',
      'isCompleted': true,
      'priority': 'Medium',
      'createdAt': DateTime.now().subtract(const Duration(hours: 4)),
    },
    {
      'id': 'task_3',
      'emoji':
          DynamicIconService().generateIcon('Eat 5 servings of vegetables'),
      'title': 'Eat 5 servings of vegetables',
      'isCompleted': false,
      'priority': 'High',
      'createdAt': DateTime.now().subtract(const Duration(hours: 1)),
    },
    {
      'id': 'task_4',
      'emoji': '📱',
      'title': 'Log all meals in app',
      'isCompleted': true,
      'priority': 'Low',
      'createdAt': DateTime.now().subtract(const Duration(minutes: 30)),
    },
    {
      'id': 'task_5',
      'emoji': '😴',
      'title': 'Get 8 hours of sleep',
      'isCompleted': false,
      'priority': 'High',
      'createdAt': DateTime.now().subtract(const Duration(minutes: 15)),
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();

    // Initialize immediately without waiting
    _initializeServicesAsync();
    _setupStreamListeners();
    _loadData();
    _loadRewardsDataAsync();
    _initializeGoogleFitAsync();
    initializeGoogleFitSync();
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

        // Listen to streak updates
        _streakService.streakStream.listen((streakSummary) {
          if (mounted) {
            setState(() {
              _streakSummary = streakSummary;
            });
          }
        }).onError((error) {
          debugPrint('Streak stream error: $error');
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
    _googleFitLiveStreamSubscription?.cancel();
    _googleFitCacheStreamSubscription?.cancel();
    _googleFitCacheService.stopLiveUpdates();
    _googleFitCacheService.dispose();
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

      // Load default motivational quote
      if (_motivationalQuote.isEmpty) {
        _loadMotivationalQuote();
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
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
      await _googleFitService.initialize();

      // Check authentication status immediately
      final isAuthenticated = await _googleFitService.validateAuthentication();
      setState(() {
        _isGoogleFitConnected = isAuthenticated;
      });

      if (_isGoogleFitConnected) {
        // Load Google Fit data immediately for instant UI update
        await _loadGoogleFitData();

        // Start live sync for real-time updates
        _startLiveSync();
        _startGoogleFitRefreshTimer();

        print('Google Fit initialized and connected - UI updated instantly');
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
        _appStateService.dailySummaryStream.listen((summary) {
      if (mounted) {
        setState(() {
          _dailySummary = summary;
        });
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

  /// Check for goals update periodically
  void _checkForGoalsUpdate() {
    if (!mounted) return;

    final simpleGoals = SimpleGoalsNotifier().currentGoals;
    final appStateGoals = _appStateService.userGoals;

    // Check if goals have changed
    if (simpleGoals != null && appStateGoals != null) {
      if (simpleGoals.calorieGoal != appStateGoals.calorieGoal ||
          simpleGoals.stepsPerDayGoal != appStateGoals.stepsPerDayGoal ||
          simpleGoals.waterGlassesGoal != appStateGoals.waterGlassesGoal) {
        debugPrint('Goals change detected via periodic check');
        _refreshDailySummaryWithNewGoals(simpleGoals);
      }
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
              onPressed: () {
                final value = int.tryParse(controller.text) ?? 0;
                _updateCalorieValue(type, value);
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
  void _updateCalorieValue(String type, int value) {
    _dailySummary ??= _getEmptyDailySummary();

    setState(() {
      if (type == 'consumed') {
        _dailySummary = _dailySummary!.copyWith(caloriesConsumed: value);
      } else {
        _dailySummary = _dailySummary!.copyWith(caloriesBurned: value);
      }
    });

    // Save to Firestore or local storage
    _saveDailySummaryToFirestore();
  }

  /// Update water glasses value and save to Firestore
  Future<void> _updateWaterGlassesValue(int value) async {
    _dailySummary ??= _getEmptyDailySummary();

    setState(() {
      _dailySummary = _dailySummary!.copyWith(waterGlasses: value);
    });

    await _saveDailySummaryToFirestore();
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

      // Load actual streak data from the analytics service (real-time data)
      _streakSummary = _streakService.currentStreaks;
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
    final caloriesToTarget =
        _dailySummary!.caloriesGoal - _dailySummary!.caloriesConsumed;
    final isReached = caloriesToTarget <= 0;
    final color = isReached
        ? const Color(0xFF2196F3)
        : Colors.orange[
            600]!; // Blue when reached, yellowish orange when not reached
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
                  isReached
                      ? 'You have successfully reached your daily calorie goal! 🏆'
                      : 'Keep going to reach your daily target! 💪',
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
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
            ..._tasks.map((task) => Column(
                  children: [
                    _buildTaskItem(
                      task['emoji'],
                      task['title'],
                      task['isCompleted'],
                      task['priority'],
                      task['id'],
                    ),
                    const SizedBox(height: 12),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(String emoji, String task, bool isCompleted,
      String priority, String taskId) {
    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = kErrorColor;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = kSuccessColor;
        break;
      default:
        priorityColor = kTextSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? kSuccessColor.withValues(alpha: 0.1)
            : Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? kSuccessColor.withValues(alpha: 0.3)
              : priorityColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Task completion checkbox
          GestureDetector(
            onTap: () => _toggleTaskCompletion(taskId, task),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? kSuccessColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted ? kSuccessColor : priorityColor,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),

          // Task emoji
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),

          // Task details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)
                        : Theme.of(context).colorScheme.onSurface,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        priority,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: kSuccessColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Completed',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kSuccessColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Delete button
          GestureDetector(
            onTap: () => _showDeleteTaskConfirmation(taskId, task),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: kErrorColor,
                size: 16,
              ),
            ),
          ),
        ],
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
              const hasStreak = false; // Simplified for streak system
              const hasReward = false; // Simplified for streak system

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
    final TextEditingController taskController = TextEditingController();
    String selectedPriority = 'Medium';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Add New Task',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskController,
                    decoration: InputDecoration(
                      labelText: 'Task description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Priority',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('High',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          value: 'High',
                          groupValue: selectedPriority,
                          onChanged: (value) =>
                              setState(() => selectedPriority = value!),
                          activeColor: kErrorColor,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Medium',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          value: 'Medium',
                          groupValue: selectedPriority,
                          onChanged: (value) =>
                              setState(() => selectedPriority = value!),
                          activeColor: Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Low',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          value: 'Low',
                          groupValue: selectedPriority,
                          onChanged: (value) =>
                              setState(() => selectedPriority = value!),
                          activeColor: kSuccessColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: kTextSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (taskController.text.isNotEmpty) {
                      _addTask(taskController.text, selectedPriority);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add Task',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addTask(String taskTitle, String priority) {
    setState(() {
      // Create new task with improved icon generation
      final dynamicIconService = DynamicIconService();
      final bestCategory = dynamicIconService.getBestCategory(taskTitle);
      final confidence =
          dynamicIconService.getCategoryConfidence(taskTitle, bestCategory);

      final newTask = {
        'id': 'task_${DateTime.now().millisecondsSinceEpoch}',
        'emoji': _getTaskEmoji(taskTitle),
        'title': taskTitle,
        'isCompleted': false,
        'priority': priority,
        'createdAt': DateTime.now(),
        'category': bestCategory,
        'confidence': confidence,
      };

      // Add to the beginning of the list
      _tasks.insert(0, newTask);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task added: $taskTitle'),
        backgroundColor: kAccentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleTaskCompletion(String taskId, String taskTitle) {
    setState(() {
      // Find and update the task
      final taskIndex = _tasks.indexWhere((task) => task['id'] == taskId);
      if (taskIndex != -1) {
        final task = _tasks[taskIndex];
        final wasCompleted = task['isCompleted'] as bool;

        // Toggle completion status
        _tasks[taskIndex]['isCompleted'] = !wasCompleted;

        if (!wasCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task completed: ${task['title']}'),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task marked as incomplete: ${task['title']}'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    });
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
                _deleteTask(taskId, taskTitle);
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

  void _deleteTask(String taskId, String taskTitle) {
    setState(() {
      // Remove task from the list
      _tasks.removeWhere((task) => task['id'] == taskId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task deleted: $taskTitle'),
        backgroundColor: kErrorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
}
