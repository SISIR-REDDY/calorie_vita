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
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';

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

  /// Initialize real-time analytics
  Future<void> _initializeAnalytics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Initialize AppStateService first
      await _appStateService.initialize();
      print('AppStateService initialized in analytics screen');

      // Load user profile data for BMI calculation
      await _loadUserProfileData();

      // Initialize analytics service with current period
      final days = _getDaysForPeriod(_selectedPeriod);
      await _analyticsService.initializeRealTimeAnalytics(days: days);

      // Set up real-time listeners
      _setupRealTimeListeners();

      // Calculate streaks and achievements based on automated data
      await _analyticsService.calculateStreaksAndAchievements();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load analytics: ${e.toString()}';
      });
    }
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
      // Set default values if loading fails
      setState(() {
        _userHeight = 1.75; // Default height in meters
        _userWeight = 70.0; // Default weight in kg
        _userGender = 'Unknown';
        _userAge = 25;
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

  /// Refresh data for current period
  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final days = _getDaysForPeriod(_selectedPeriod);
      await _analyticsService.updatePeriod(days);
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Handle period change
  Future<void> _onPeriodChanged(String period) async {
    if (period == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = period;
      _isLoading = true;
    });

    try {
      final days = _getDaysForPeriod(period);
      await _analyticsService.updatePeriod(days);
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
                      _buildCaloriesChart(),
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
                  IconButton(
                    onPressed: () {
                      // Refresh functionality
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
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
    // Calculate real-time data
    final totalCalories = _dailySummaries.fold(0, (sum, summary) => sum + summary.caloriesConsumed);
    final totalSteps = _dailySummaries.fold(0, (sum, summary) => sum + summary.steps);
    final totalWorkouts = _dailySummaries.length; // Use number of active days as workout sessions
    
    // Calculate changes (simplified - in real app, compare with previous period)
    final caloriesChange = _dailySummaries.isNotEmpty ? '+5%' : '0%';
    final stepsChange = _dailySummaries.isNotEmpty ? '+12%' : '0%';
    final workoutsChange = _dailySummaries.isNotEmpty ? '+2' : '0';

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

  Widget _buildCaloriesChart() {
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
            'Calories Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 48,
                    color: kPrimaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chart Coming Soon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    'Real-time charts will be available soon',
                    style: TextStyle(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
    // Calculate BMI from real user profile data
    final currentWeight = _userWeight ?? 70.0; // Use real user weight or default
    final currentHeight = _userHeight ?? 1.75; // Use real user height or default
    final bmi = currentWeight / (currentHeight * currentHeight);
    final bmiCategory = _getBMICategory(bmi);
    final bmiColor = _getBMIColor(bmi);
    
    // Debug logging
    print('BMI Debug - Weight: $_userWeight, Height: $_userHeight');
    print('BMI Debug - Current Weight: $currentWeight, Current Height: $currentHeight');
    print('BMI Debug - Calculated BMI: $bmi');
    
    // Check if we have real user data (not null and not zero)
    final hasRealData = _userWeight != null && _userHeight != null && _userWeight! > 0 && _userHeight! > 0;
    
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