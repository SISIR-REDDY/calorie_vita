import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../services/analytics_service.dart';
import '../services/firebase_service.dart';
import '../services/ai_service.dart';
import '../services/app_state_service.dart';
import '../services/google_fit_service.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import '../models/google_fit_data.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = 'Weekly';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];
  
  // Services
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirebaseService _firebaseService = FirebaseService();
  final AppStateService _appStateService = AppStateService();
  final GoogleFitService _googleFitService = GoogleFitService();
  
  // State management
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  bool _isGeneratingInsights = false;
  String _aiInsights = '';
  
  // Stream subscriptions
  StreamSubscription<Map<String, dynamic>?>? _profileDataSubscription;
  
  // Real-time data
  List<DailySummary> _dailySummaries = [];
  MacroBreakdown _macroBreakdown = MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
  List<UserAchievement> _achievements = [];
  List<Map<String, dynamic>> _insights = [];
  List<Map<String, dynamic>> _recommendations = [];
  
  // Google Fit data
  GoogleFitData? _todayGoogleFitData;
  List<GoogleFitData> _weeklyGoogleFitData = [];
  bool _isGoogleFitConnected = false;
  
  // User profile data for BMI calculation
  double? _userHeight; // in meters
  double? _userWeight; // in kg
  String? _userGender;
  int? _userAge;
  

  @override
  void initState() {
    super.initState();
    _initializeAnalytics();
  }

  @override
  void dispose() {
    _profileDataSubscription?.cancel();
    _analyticsService.dispose();
    super.dispose();
  }

  /// Initialize real-time analytics (optimized for faster loading)
  Future<void> _initializeAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all data in parallel for faster initialization
      final futures = <Future>[];
      
      // Initialize services in parallel
      futures.add(_appStateService.initialize());
      futures.add(_loadUserProfileData());
      
      // Wait for basic services to initialize
      await Future.wait(futures);
      print('AppStateService initialized in analytics screen');

      // Initialize analytics service with current period (fast)
      final days = _getDaysForPeriod(_selectedPeriod);
      await _analyticsService.initializeRealTimeAnalytics(days: days);
      
      // Set up real-time listeners (non-blocking)
      _setupRealTimeListeners();
      
      // Show UI immediately for faster response
      setState(() {
        _isLoading = false;
      });
      
      // Load Google Fit data asynchronously (non-blocking)
      _loadGoogleFitDataAsync();

      // Calculate achievements in background (non-blocking)
      _analyticsService.calculateStreaksAndAchievements();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load analytics: ${e.toString()}';
      });
    }
  }

  /// Load Google Fit data asynchronously without blocking UI (optimized for RAM clearing)
  Future<void> _loadGoogleFitDataAsync() async {
    try {
      // Initialize Google Fit service with persistence check
      await _googleFitService.initialize();
      
      // Load Google Fit data immediately
      await _loadGoogleFitData();
      
      // Start live sync if connected
      if (_isGoogleFitConnected) {
        _googleFitService.startLiveSync();
        _setupGoogleFitLiveStream();
        print('Analytics: Google Fit live sync started');
      }
    } catch (e) {
      print('Error loading Google Fit data asynchronously: $e');
      // Don't show error to user as this is background loading
    }
  }


  /// Load Google Fit data
  Future<void> _loadGoogleFitData() async {
    try {
      final isAuthenticated = await _googleFitService.validateAuthentication();
      setState(() {
        _isGoogleFitConnected = isAuthenticated;
      });
      
      if (_isGoogleFitConnected) {
        // Load today's data with batched API calls for faster response
        final today = DateTime.now();
        final futures = await Future.wait([
          _googleFitService.getDailySteps(today),
          _googleFitService.getDailyCaloriesBurned(today),
          _googleFitService.getDailyDistance(today),
          _googleFitService.getCurrentWeight(),
        ]);
        
        setState(() {
          _todayGoogleFitData = GoogleFitData(
            date: today,
            steps: futures[0] as int? ?? 0,
            caloriesBurned: futures[1] as double? ?? 0.0,
            distance: futures[2] as double? ?? 0.0,
            weight: futures[3] as double?,
          );
        });
        
        // Load weekly data for better analytics
        await _loadWeeklyGoogleFitData();
      }
    } catch (e) {
      print('Error loading Google Fit data: $e');
      // Don't set error state for Google Fit as it's optional
    }
  }

  /// Load weekly Google Fit data for analytics (optimized for speed)
  Future<void> _loadWeeklyGoogleFitData() async {
    try {
      if (_isGoogleFitConnected) {
        // Load weekly data in parallel for faster response
        final now = DateTime.now();
        final weeklyData = <GoogleFitData>[];
        final futures = <Future>[];
        
        // Load data for each day of the week in parallel
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          futures.add(_loadSingleDayGoogleFitData(date, weeklyData));
        }
        
        await Future.wait(futures);
        
        setState(() {
          _weeklyGoogleFitData = weeklyData;
        });
        print('Loaded ${_weeklyGoogleFitData.length} days of Google Fit data in parallel');
      }
    } catch (e) {
      print('Error loading weekly Google Fit data: $e');
    }
  }

  /// Load single day Google Fit data (helper method for parallel loading)
  Future<void> _loadSingleDayGoogleFitData(DateTime date, List<GoogleFitData> weeklyData) async {
    try {
      final futures = await Future.wait([
        _googleFitService.getDailySteps(date),
        _googleFitService.getDailyCaloriesBurned(date),
        _googleFitService.getDailyDistance(date),
      ]);
      
      final steps = futures[0] as int? ?? 0;
      final calories = futures[1] as double? ?? 0.0;
      final distance = futures[2] as double? ?? 0.0;
      
      weeklyData.add(GoogleFitData(
        date: date,
        steps: steps,
        caloriesBurned: calories,
        distance: distance,
        weight: null,
      ));
    } catch (e) {
      // Add empty data if loading fails
      weeklyData.add(GoogleFitData(
        date: date,
        steps: 0,
        caloriesBurned: 0,
        distance: 0,
        weight: null,
      ));
    }
  }

  /// Refresh analytics data when period changes (optimized)
  Future<void> _refreshAnalyticsForPeriod() async {
    try {
      setState(() {
        _isRefreshing = true;
      });

      // Only reload Google Fit data if connected and not already syncing
      if (_isGoogleFitConnected && !_isRefreshing) {
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
            distance: newDistance ?? _todayGoogleFitData!.distance,
            weight: _todayGoogleFitData!.weight,
          );
          
          // Only update if data has actually changed
          if (updatedData.steps != _todayGoogleFitData!.steps ||
              updatedData.caloriesBurned != _todayGoogleFitData!.caloriesBurned ||
              updatedData.distance != _todayGoogleFitData!.distance) {
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
          setState(() {
            // Height is stored in cm, convert to meters for BMI calculation
            final heightCm = data['height']?.toDouble();
            _userHeight = heightCm != null ? heightCm / 100.0 : null;
            _userWeight = data['weight']?.toDouble();
            _userGender = data['gender']?.toString();
            _userAge = data['age']?.toInt();
          });
          print('Parsed Profile Data - Height: $_userHeight, Weight: $_userWeight, Gender: $_userGender, Age: $_userAge');
        } else {
          print('Profile document does not exist');
        }
      }
    } catch (e) {
      print('Error loading user profile data: $e');
      // Don't set default values - let user input their data
      setState(() {
        _userHeight = null;
        _userWeight = null;
        _userGender = null;
        _userAge = null;
      });
    }
  }


  /// Set up real-time data listeners
  void _setupRealTimeListeners() {
    // Listen to daily summaries
    _analyticsService.dailySummariesStream.listen((summaries) {
      if (mounted) {
        setState(() {
          _dailySummaries = summaries;
        });
      }
    });

    // Listen to macro breakdown
    _analyticsService.macroBreakdownStream.listen((breakdown) {
      if (mounted) {
        setState(() {
          _macroBreakdown = breakdown;
        });
      }
    });

    // Listen to achievements
    _analyticsService.achievementsStream.listen((achievements) {
      if (mounted) {
        setState(() {
          _achievements = achievements;
        });
      }
    });

    // Listen to profile data changes (for BMI updates)
    _profileDataSubscription?.cancel();
    _profileDataSubscription = _appStateService.profileDataStream.listen((profileData) {
      print('Profile data stream received in analytics: $profileData');
      if (mounted && profileData != null) {
        setState(() {
          // Update height and weight from profile data
          final heightCm = profileData['height']?.toDouble();
          _userHeight = heightCm != null ? heightCm / 100.0 : null;
          _userWeight = profileData['weight']?.toDouble();
          _userGender = profileData['gender']?.toString();
          _userAge = profileData['age']?.toInt();
        });
        print('Profile data updated in analytics: Height=${_userHeight}m, Weight=${_userWeight}kg');
        print('BMI will be recalculated with new values');
      } else {
        print('Profile data is null or widget not mounted');
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
  }

  /// Get number of days for selected period
  int _getDaysForPeriod(String period) {
    switch (period) {
      case 'Daily':
        return 1;
      case 'Weekly':
        return 7;
      case 'Monthly':
        return 30;
      default:
        return 7;
    }
  }

  /// Calculate percentage change for metrics (no hardcoded values)
  String _calculatePercentageChange(String metric) {
    if (_dailySummaries.length < 2) return '0%';
    
    final currentPeriod = _dailySummaries.take(_getDaysForPeriod(_selectedPeriod));
    final previousPeriod = _dailySummaries.skip(_getDaysForPeriod(_selectedPeriod)).take(_getDaysForPeriod(_selectedPeriod));
    
    if (previousPeriod.isEmpty || currentPeriod.isEmpty) return '0%';
    
    double currentValue = 0;
    double previousValue = 0;
    
    switch (metric) {
      case 'calories':
        currentValue = currentPeriod.fold(0, (sum, s) => sum + s.caloriesConsumed).toDouble();
        previousValue = previousPeriod.fold(0, (sum, s) => sum + s.caloriesConsumed).toDouble();
        break;
      case 'steps':
        currentValue = currentPeriod.fold(0, (sum, s) => sum + s.steps).toDouble();
        previousValue = previousPeriod.fold(0, (sum, s) => sum + s.steps).toDouble();
        break;
    }
    
    if (previousValue == 0) return '0%';
    
    final change = ((currentValue - previousValue) / previousValue * 100).round();
    return change >= 0 ? '+$change%' : '$change%';
  }

  /// Calculate workout change (no hardcoded values)
  String _calculateWorkoutChange() {
    if (_dailySummaries.length < 2) return '0';
    
    final currentPeriod = _dailySummaries.take(_getDaysForPeriod(_selectedPeriod));
    final previousPeriod = _dailySummaries.skip(_getDaysForPeriod(_selectedPeriod)).take(_getDaysForPeriod(_selectedPeriod));
    
    if (previousPeriod.isEmpty || currentPeriod.isEmpty) return '0';
    
    final currentWorkouts = currentPeriod.where((s) => s.caloriesBurned > 0).length;
    final previousWorkouts = previousPeriod.where((s) => s.caloriesBurned > 0).length;
    
    final change = currentWorkouts - previousWorkouts;
    return change >= 0 ? '+$change' : '$change';
  }

  /// Refresh data for current period
  Future<void> _refreshData() async {
    if (_isRefreshing) return;

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
        futures.add(_loadGoogleFitDataForPeriod(_selectedPeriod));
      }
      
      // Refresh user profile data
      futures.add(_loadUserProfileData());
      
      // Wait for all refreshes to complete
      await Future.wait(futures);
      
      print('Analytics data refreshed successfully');
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh data: ${e.toString()}';
      });
      print('Error refreshing analytics data: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Handle period change (optimized for speed)
  Future<void> _onPeriodChanged(String period) async {
    if (period == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = period;
      _isLoading = true;
    });

    try {
      // Load Google Fit data and refresh analytics in parallel for faster response
      final futures = <Future>[];
      
      if (_isGoogleFitConnected) {
        futures.add(_loadGoogleFitDataForPeriod(period));
      }
      futures.add(_refreshAnalyticsForPeriod());
      
      await Future.wait(futures);
    } catch (e) {
      setState(() {
        _error = 'Failed to change period: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Load Google Fit data for specific period (optimized)
  Future<void> _loadGoogleFitDataForPeriod(String period) async {
    try {
      switch (period) {
        case 'Daily':
          // Load today's data
          final today = DateTime.now();
          final futures = await Future.wait([
            _googleFitService.getDailySteps(today),
            _googleFitService.getDailyCaloriesBurned(today),
            _googleFitService.getDailyDistance(today),
            _googleFitService.getCurrentWeight(),
          ]);
          
          setState(() {
            _todayGoogleFitData = GoogleFitData(
              date: today,
              steps: futures[0] as int? ?? 0,
              caloriesBurned: futures[1] as double? ?? 0.0,
              distance: futures[2] as double? ?? 0.0,
              weight: futures[3] as double?,
            );
          });
          break;
          
        case 'Weekly':
          // Load weekly data in parallel
          await _loadWeeklyGoogleFitData();
          break;
          
        case 'Monthly':
          // Load monthly data (last 30 days) in parallel
          await _loadMonthlyGoogleFitData();
          break;
      }
    } catch (e) {
      print('Error loading Google Fit data for period $period: $e');
    }
  }

  /// Load monthly Google Fit data (optimized for speed)
  Future<void> _loadMonthlyGoogleFitData() async {
    try {
      if (_isGoogleFitConnected) {
        // Load monthly data in parallel for faster response
        final now = DateTime.now();
        final monthlyData = <GoogleFitData>[];
        final futures = <Future>[];
        
        // Load data for each day of the month in parallel (sample every 3rd day for performance)
        for (int i = 0; i < 30; i += 3) {
          final date = now.subtract(Duration(days: i));
          futures.add(_loadSingleDayGoogleFitData(date, monthlyData));
        }
        
        await Future.wait(futures);
        
        setState(() {
          _weeklyGoogleFitData = monthlyData; // Reuse the same variable for monthly data
        });
        print('Loaded ${monthlyData.length} days of monthly Google Fit data in parallel');
      }
    } catch (e) {
      print('Error loading monthly Google Fit data: $e');
    }
  }

  /// Generate AI insights based on current data
  Future<void> _generateAIInsights() async {
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
        'recent_calories': _dailySummaries.map((summary) => {
          'date': summary.date.toIso8601String().split('T')[0],
          'calories': summary.caloriesConsumed,
        }).toList(),
        'recent_steps': _dailySummaries.map((summary) => {
          'date': summary.date.toIso8601String().split('T')[0],
          'steps': summary.steps,
        }).toList(),
        // Note: Weight and BMI data would need to be fetched separately from user profile
        
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
            ? _dailySummaries.map((s) => s.caloriesConsumed).reduce((a, b) => a + b) / _dailySummaries.length
            : 0,
        'average_steps': _dailySummaries.isNotEmpty 
            ? _dailySummaries.map((s) => s.steps).reduce((a, b) => a + b) / _dailySummaries.length
            : 0,
      };

      final insights = await AIService.getAnalyticsInsights(userData);
      
      setState(() {
        _aiInsights = insights;
        _isGeneratingInsights = false;
      });
    } catch (e) {
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
            Text(
              'Failed to load analytics',
              style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      if (_isGoogleFitConnected && _googleFitService.isLiveSyncing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
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
                      if (_isGoogleFitConnected && _googleFitService.isLiveSyncing)
                        const SizedBox(width: 8),
                      IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
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
    // Calculate real-time data with Google Fit integration based on selected period
    int totalCalories = 0;
    int totalSteps = 0;
    int totalWorkouts = 0;
    
    // Get data based on selected period
    switch (_selectedPeriod) {
      case 'Daily':
        // Use today's data from Google Fit and app data
        totalCalories = _dailySummaries.isNotEmpty ? _dailySummaries.last.caloriesConsumed : 0;
        totalSteps = _dailySummaries.isNotEmpty ? _dailySummaries.last.steps : 0;
        
        // Use Google Fit data if available (don't add to app data to avoid confusion)
        if (_isGoogleFitConnected && _todayGoogleFitData != null) {
          final todayData = _todayGoogleFitData!;
          if (todayData.caloriesBurned != null && todayData.caloriesBurned! > 0) {
            totalCalories = todayData.caloriesBurned!.round(); // Use Google Fit data instead of app data
          }
          if (todayData.steps != null && todayData.steps! > 0) {
            totalSteps = todayData.steps!; // Use Google Fit data instead of app data
          }
        }
        
        totalWorkouts = _dailySummaries.isNotEmpty && _dailySummaries.last.caloriesBurned > 0 ? 1 : 0;
        break;
        
      case 'Weekly':
        // Sum up last 7 days
        totalCalories = _dailySummaries.take(7).fold(0, (sum, summary) => sum + summary.caloriesConsumed);
        totalSteps = _dailySummaries.take(7).fold(0, (sum, summary) => sum + summary.steps);
        
        // Use Google Fit weekly data if available (don't add to app data to avoid confusion)
        if (_isGoogleFitConnected && _weeklyGoogleFitData.isNotEmpty) {
          int fitCalories = 0;
          int fitSteps = 0;
          for (final fitData in _weeklyGoogleFitData.take(7)) {
            if (fitData.caloriesBurned != null && fitData.caloriesBurned! > 0) {
              fitCalories += fitData.caloriesBurned!.round();
            }
            if (fitData.steps != null && fitData.steps! > 0) {
              fitSteps += fitData.steps!;
            }
          }
          // Use Google Fit data if it's higher than app data
          if (fitCalories > totalCalories) totalCalories = fitCalories;
          if (fitSteps > totalSteps) totalSteps = fitSteps;
        }
        
        totalWorkouts = _dailySummaries.take(7).where((summary) => summary.caloriesBurned > 0).length;
        break;
        
      case 'Monthly':
        // Sum up last 30 days
        totalCalories = _dailySummaries.take(30).fold(0, (sum, summary) => sum + summary.caloriesConsumed);
        totalSteps = _dailySummaries.take(30).fold(0, (sum, summary) => sum + summary.steps);
        
        // Use Google Fit monthly data if available (don't add to app data to avoid confusion)
        if (_isGoogleFitConnected && _weeklyGoogleFitData.isNotEmpty) {
          final weeklyFitCalories = _weeklyGoogleFitData.fold(0, (sum, data) => 
            sum + (data.caloriesBurned?.round() ?? 0));
          final weeklyFitSteps = _weeklyGoogleFitData.fold(0, (sum, data) => 
            sum + (data.steps ?? 0));
          
          // Estimate monthly data (weekly * 4.3 weeks)
          final monthlyFitCalories = (weeklyFitCalories * 4.3).round();
          final monthlyFitSteps = (weeklyFitSteps * 4.3).round();
          
          // Use Google Fit data if it's higher than app data
          if (monthlyFitCalories > totalCalories) totalCalories = monthlyFitCalories;
          if (monthlyFitSteps > totalSteps) totalSteps = monthlyFitSteps;
        }
        
        totalWorkouts = _dailySummaries.take(30).where((summary) => summary.caloriesBurned > 0).length;
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

  /// Format numbers with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Calculate macro percentage
  int _calculateMacroPercentage(double value) {
    final total = _macroBreakdown.carbs + _macroBreakdown.protein + _macroBreakdown.fat;
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

  Widget _buildSummaryCard(String title, String value, String unit, IconData icon, Color color, String change, Color changeColor) {
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
          const Text(
            'Macronutrient Breakdown',
                style: TextStyle(
              fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMacroItem('Carbs', '${_macroBreakdown.carbs}g', '${_calculateMacroPercentage(_macroBreakdown.carbs)}%', kAccentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroItem('Protein', '${_macroBreakdown.protein}g', '${_calculateMacroPercentage(_macroBreakdown.protein)}%', kSecondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroItem('Fat', '${_macroBreakdown.fat}g', '${_calculateMacroPercentage(_macroBreakdown.fat)}%', kInfoColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSuccessColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: kSuccessColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Well Balanced',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kSuccessColor,
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

  Widget _buildMacroItem(String label, String value, String percentage, Color color) {
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

  /// Build BMI Analytics section
  Widget _buildBMIAnalytics() {
    // Check if we have real user data (no hardcoded defaults)
    final hasRealData = _userWeight != null && _userHeight != null && _userWeight! > 0 && _userHeight! > 0;
    
    if (!hasRealData) {
      // Show message to input profile data instead of fake data
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
            const Text(
              'Please complete your profile to see BMI analytics',
              style: TextStyle(
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
                colors: [bmiColor.withValues(alpha: 0.1), bmiColor.withValues(alpha: 0.05)],
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
                      Text(
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
                      if (hasRealData) ...[
                        Text(
                          'Height: ${(_userHeight! * 100).round()} cm | Weight: ${_userWeight!.round()} kg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary,
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: kInfoColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
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
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: kSuccessColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
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
            style: TextStyle(
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
      baseRecommendation = 'Consider increasing your calorie intake with healthy foods and strength training to build muscle mass.';
    } else if (bmi < 25.0) {
      baseRecommendation = 'Great job! Maintain your current healthy lifestyle with balanced nutrition and regular exercise.';
    } else if (bmi < 30.0) {
      baseRecommendation = 'Focus on creating a moderate calorie deficit through healthy eating and increased physical activity.';
    } else {
      baseRecommendation = 'Consider consulting with a healthcare professional for a personalized weight management plan.';
    }
    
    if (hasRealData) {
      return '$baseRecommendation Based on your profile (${gender}, ${age} years old), this recommendation is personalized for you.';
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
                onPressed: _generateAIInsights,
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
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: kAccentPurple,
                size: 16,
              ),
              const SizedBox(width: 8),
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
                  recommendation['description']?.toString() ?? 'No description available',
                  _getRecommendationIcon(recommendation['type']?.toString() ?? 'general'),
                  _getRecommendationColor(recommendation['priority']?.toString() ?? 'medium'),
                ),
                const SizedBox(height: 8),
              ],
            )).toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String title, String description, IconData icon, Color color) {
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