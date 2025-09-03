import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../ui/app_colors.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import '../models/daily_summary.dart';
import '../models/reward_system.dart';
import '../services/app_state_service.dart';
import '../services/firebase_service.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Services
  final FirebaseService _firebaseService = FirebaseService();
  
  // Data
  DailySummary? _dailySummary;
  MacroBreakdown? _macroBreakdown;
  List<UserAchievement> _achievements = [];
  UserPreferences _preferences = const UserPreferences();
  String _motivationalQuote = '';
  bool _isLoading = true;
  UserProgress _userProgress = UserProgress.initial();
  List<UserReward> _allRewards = [];
  
  // Task management
  List<Map<String, dynamic>> _completedTasks = [];
  List<Map<String, dynamic>> _tasks = [
    {
      'id': 'task_1',
      'emoji': '💧',
      'title': 'Drink 8 glasses of water',
      'isCompleted': false,
      'priority': 'High',
      'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'id': 'task_2',
      'emoji': '🏃',
      'title': '30 minutes morning walk',
      'isCompleted': true,
      'priority': 'Medium',
      'createdAt': DateTime.now().subtract(const Duration(hours: 4)),
    },
    {
      'id': 'task_3',
      'emoji': '🥗',
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

  // Services
  final AppStateService _appStateService = AppStateService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupStreamListeners();
    _loadData();
  }

  void _setupStreamListeners() {
    // Listen to real-time data updates
    _appStateService.dailySummaryStream.listen((summary) {
      if (mounted) {
        setState(() {
          _dailySummary = summary;
        });
      }
    });

    _appStateService.macroBreakdownStream.listen((breakdown) {
      if (mounted) {
        setState(() {
          _macroBreakdown = breakdown;
        });
      }
    });

    _appStateService.achievementsStream.listen((achievements) {
      if (mounted) {
        setState(() {
          _achievements = achievements;
        });
      }
    });

    _appStateService.preferencesStream.listen((preferences) {
      if (mounted) {
        setState(() {
          _preferences = preferences;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load daily summary
        await _loadDailySummary(user.uid);
        
        // Load achievements
        await _loadAchievements(user.uid);
        
        // Load preferences
        await _loadPreferences(user.uid);
        
        // Load reward system
        await _loadRewardSystem();
        
        // Load motivational quote
        _loadMotivationalQuote();
      }
    } catch (e) {
      // Handle error silently in production
      debugPrint('Error loading home data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDailySummary(String userId) async {
    // Mock data for now - replace with real data from Firestore
    _dailySummary = DailySummary(
      caloriesConsumed: 1450,
      caloriesBurned: 320,
      caloriesGoal: 2000,
      waterIntake: 6,
      waterGoal: 8,
      steps: 8500,
      stepsGoal: 10000,
      sleepHours: 7.5,
      sleepGoal: 8.0,
      date: DateTime.now(),
    );

    // Mock macro breakdown
    _macroBreakdown = MacroBreakdown(
      carbs: 180.0,
      protein: 95.0,
      fat: 65.0,
      fiber: 25.0,
      sugar: 45.0,
    );
  }



  Future<void> _loadAchievements(String userId) async {
    // Mock achievements - replace with real data
    _achievements = Achievements.defaultAchievements.map((achievement) {
      // Simulate some unlocked achievements
      final isUnlocked = ['streak_3', 'water_7', 'early_bird'].contains(achievement.id);
      return achievement.copyWith(
        isUnlocked: isUnlocked,
        unlockedAt: isUnlocked ? DateTime.now().subtract(const Duration(days: 2)) : null,
      );
    }).toList();
  }

  Future<void> _loadPreferences(String userId) async {
    try {
      final preferences = await _firebaseService.getUserPreferences(userId);
      if (preferences != null) {
        setState(() {
          _preferences = preferences;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _loadRewardSystem() async {
    try {
      // Load all available rewards
      _allRewards = RewardSystem.getAllRewards();
      
      // Calculate mock user progress (in real app, load from Firebase)
      final mockTotalPoints = 1750;
      final mockCurrentStreak = 7;
      final mockUnlockedRewards = _allRewards.take(8).map((reward) => 
        reward.copyWith(isUnlocked: true, earnedAt: DateTime.now().subtract(Duration(days: DateTime.now().day % 7)))
      ).toList();
      
      final currentLevel = RewardSystem.getCurrentLevel(mockTotalPoints);
      final pointsToNext = RewardSystem.getPointsToNextLevel(mockTotalPoints, currentLevel);
      final levelProgress = RewardSystem.getLevelProgress(mockTotalPoints, currentLevel);
      
      setState(() {
        _userProgress = UserProgress(
          totalPoints: mockTotalPoints,
          currentStreak: mockCurrentStreak,
          longestStreak: 15,
          currentLevel: currentLevel,
          pointsToNextLevel: pointsToNext,
          levelProgress: levelProgress,
          unlockedRewards: mockUnlockedRewards,
          categoryProgress: {
            'logging': 85,
            'nutrition': 72,
            'exercise': 60,
            'water': 90,
            'consistency': 78,
          },
        );
      });
    } catch (e) {
      debugPrint('Error loading reward system: $e');
    }
  }

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
                  
                  // Health Insights
                  _buildHealthInsightsSection(),
                  
                  // Spacing between sections
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                  
                  // Streak & Rewards
                  _buildStreakRewardsSection(),
                  
                  // Spacing between sections
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                  
                  // Recent Activity
                  _buildRecentActivitySection(),
                  
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
                  
                  // AI Suggestions
                  _buildAISuggestionsSection(),
                  
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: user?.photoURL != null 
                          ? NetworkImage(user!.photoURL!) 
                          : null,
                      child: user?.photoURL == null 
                          ? const Icon(Icons.person, color: Colors.white, size: 28)
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
    if (_dailySummary == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Summary',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Consumed',
                    _preferences.calorieUnit.convertFromKcal(_dailySummary!.caloriesConsumed.toDouble()).round(),
                    Icons.restaurant,
                    kAccentColor,
                    _preferences.calorieUnit.displayName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Burned',
                    _preferences.calorieUnit.convertFromKcal(_dailySummary!.caloriesBurned.toDouble()).round(),
                    Icons.directions_run,
                    kSecondaryColor,
                    _preferences.calorieUnit.displayName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Remaining',
                    _preferences.calorieUnit.convertFromKcal(_dailySummary!.caloriesRemaining.toDouble()).round(),
                    Icons.local_fire_department,
                    kAccentBlue,
                    _preferences.calorieUnit.displayName,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, int value, IconData icon, Color color, String unit) {
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthInsightsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kAccentBlue.withValues(alpha: 0.1), kAccentBlue.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: kAccentBlue.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.insights, color: kAccentBlue, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Health Insights',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildInsightCard(
                    'Hydration',
                    '${_dailySummary?.waterIntake ?? 0}/${_dailySummary?.waterGoal ?? 8} glasses',
                    Icons.water_drop,
                    kAccentBlue,
                    (_dailySummary?.waterProgress ?? 0.0) * 100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightCard(
                    'Activity',
                    '${_dailySummary?.steps ?? 0}/${_dailySummary?.stepsGoal ?? 10000} steps',
                    Icons.directions_walk,
                    kSecondaryColor,
                    (_dailySummary?.stepsProgress ?? 0.0) * 100,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: kSuccessColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You\'re doing great! Keep up the healthy habits.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildInsightCard(String title, String subtitle, IconData icon, Color color, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
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
                    color: kSecondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history, color: kSecondaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Activity',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Show completed tasks first if any
            ..._completedTasks.take(3).map((task) => _buildActivityItem(
              task['emoji'], 
              task['title'], 
              task['time'], 
              task['detail'], 
              task['entryId']
            )),
            
            // Show regular activity items
            if (_completedTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            _buildActivityItem('🍎', 'Logged Apple', '2 hours ago', '+52 ${_preferences.calorieUnit.displayName}', 'apple_1'),
            _buildActivityItem('🏃', 'Morning Run', '4 hours ago', '-320 ${_preferences.calorieUnit.displayName}', 'run_1'),
            _buildActivityItem('💧', 'Water Intake', '1 hour ago', '250ml', 'water_1'),
            _buildActivityItem('🥗', 'Lunch Salad', '3 hours ago', '+180 ${_preferences.calorieUnit.displayName}', 'salad_1'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String emoji, String title, String time, String detail, String entryId) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                detail,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(entryId, title),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kErrorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: kErrorColor,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                  child: const Icon(Icons.task_alt, color: kAccentColor, size: 24),
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

  Widget _buildTaskItem(String emoji, String task, bool isCompleted, String priority, String taskId) {
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
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              child: Icon(
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

  Widget _buildStreakRewardsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _userProgress.currentLevel.color.withValues(alpha: 0.8),
              _userProgress.currentLevel.color,
              _userProgress.currentLevel.color.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _userProgress.currentLevel.color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with level info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _userProgress.currentLevel.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userProgress.currentLevel.title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_userProgress.totalPoints} total points',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level ${UserLevel.values.indexOf(_userProgress.currentLevel) + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Level Progress Bar
            _buildLevelProgressBar(),
            const SizedBox(height: 20),
            
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildRewardStat('🔥', '${_userProgress.currentStreak} Day Streak', 'On fire!'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRewardStat('🏆', '${_userProgress.unlockedRewards.length} Rewards', 'Earned!'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRewardStat('⭐', '${_userProgress.totalPoints} Points', 'Amazing!'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgressBar() {
    final nextLevel = RewardSystem.getNextLevel(_userProgress.currentLevel);
    final isMaxLevel = nextLevel == _userProgress.currentLevel;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress to ${isMaxLevel ? 'Max Level' : nextLevel.title}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              isMaxLevel ? 'MAX' : '${_userProgress.pointsToNextLevel} points to go',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _userProgress.levelProgress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardStat(String icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAISuggestionsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: kPrimaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Suggestions',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Daily Tip',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adding more protein to your breakfast to keep you full longer and boost your metabolism!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToAITrainer(),
                icon: const Icon(Icons.chat),
                label: const Text('Ask Trainer Sisir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
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
      case 'red': return kErrorColor;
      case 'orange': return kWarningColor;
      case 'blue': return kInfoColor;
      case 'green': return kSuccessColor;
      default: return kTextSecondary;
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

  Widget _buildProfileScreen() {
    final user = FirebaseAuth.instance.currentUser;
    final unlockedAchievements = _achievements.where((a) => a.isUnlocked).toList();
    
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: kPrimaryColor,
                      backgroundImage: user?.photoURL != null 
                          ? NetworkImage(user!.photoURL!) 
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              user?.displayName?.isNotEmpty == true 
                                  ? user!.displayName!.substring(0, 1).toUpperCase() 
                                  : 'U',
                              style: GoogleFonts.poppins(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // User Name
                    Text(
                      user?.displayName ?? 'User',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // User Email
                    Text(
                      user?.email ?? 'user@example.com',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Quick Stats
                    _buildSimpleQuickStats(),
                ],
              ),
            ),
            
            // Content Sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Weekly Streak Calendar Section
                  _buildWeeklyStreakCalendarSection(),
                  const SizedBox(height: 24),
                  
                  // Current Streaks Section
                  _buildStreaksSection(),
                  const SizedBox(height: 24),
                  
                  // Achievements Section
                  _buildLeetCodeAchievementsSection(),
                  const SizedBox(height: 24),
                  
                  // Rewards Section
                  _buildRewardsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleQuickStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSimpleStatCard('7', 'Day Streak', Icons.local_fire_department, kPrimaryColor),
        _buildSimpleStatCard('12', 'Achievements', Icons.emoji_events, kAccentColor),
        _buildSimpleStatCard('1,250', 'Points', Icons.stars, kSecondaryColor),
      ],
    );
  }

  Widget _buildSimpleStatCard(String value, String label, IconData icon, Color color) {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
                child: const Icon(Icons.calendar_month, color: kPrimaryColor, size: 24),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            children: weekDays.map((day) => Expanded(
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
            )).toList(),
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
              final hasStreak = _hasStreakForDay(date.day);
              final hasReward = _hasRewardForDay(date.day);
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildBeautifulCalendarDay(date.day, isToday, hasStreak, hasReward),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBeautifulCalendarDay(int day, bool isToday, bool hasStreak, bool hasReward) {
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
        decoration: BoxDecoration(
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
        decoration: BoxDecoration(
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

  // New Reward System UI Components
  Widget _buildCategoryRewards(Map<String, List<UserReward>> categoryRewards) {
    final categories = categoryRewards.keys.toList();
    
    return Column(
      children: [
        // Category Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.category, color: kPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Reward Categories',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Categories Grid
        ...categories.take(3).map((category) {
          final rewards = categoryRewards[category]!;
          final unlockedCount = rewards.where((r) => 
            _userProgress.unlockedRewards.any((ur) => ur.id == r.id)
          ).length;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: _buildCategoryCard(category, rewards, unlockedCount),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCategoryCard(String category, List<UserReward> rewards, int unlockedCount) {
    final categoryEmojis = {
      'logging': '📝',
      'nutrition': '🥗',
      'exercise': '🏃‍♂️',
      'water': '💧',
      'consistency': '🔥',
      'achievement': '🏆',
    };
    
    final categoryColors = {
      'logging': Colors.blue,
      'nutrition': Colors.green,
      'exercise': Colors.red,
      'water': Colors.cyan,
      'consistency': Colors.orange,
      'achievement': Colors.purple,
    };
    
    final emoji = categoryEmojis[category] ?? '🎯';
    final color = categoryColors[category] ?? kPrimaryColor;
    final progress = unlockedCount / rewards.length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unlockedCount/${rewards.length} unlocked',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeautifulRewardCard(UserReward reward) {
    final isUnlocked = _userProgress.unlockedRewards.any((r) => r.id == reward.id);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked 
            ? reward.color.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked 
              ? reward.color 
              : Colors.grey.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: isUnlocked ? [
          BoxShadow(
            color: reward.color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ] : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reward Icon/Emoji
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isUnlocked 
                  ? reward.color.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                reward.emoji,
                style: TextStyle(
                  fontSize: 24,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Reward Title
          Text(
            reward.title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? reward.color : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked 
                  ? reward.color.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${reward.points} pts',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? reward.color : Colors.grey,
              ),
            ),
          ),
          
          // Unlocked indicator
          if (isUnlocked) ...[
            const SizedBox(height: 8),
            Icon(
              Icons.check_circle,
              color: reward.color,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }

  // Mock functions for calendar data
  bool _hasStreakForDay(int day) {
    // Mock: return true for some days to show streak pattern
    return day % 3 == 0 || day % 5 == 0;
  }

  bool _hasRewardForDay(int day) {
    // Mock: return true for some days to show rewards
    return day % 7 == 0;
  }

  Widget _buildStreaksSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kSuccessColor.withValues(alpha: 0.1),
            kPrimaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kSuccessColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  gradient: LinearGradient(
                    colors: [kSuccessColor, Colors.orange],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Streaks',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Your progress this week',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildStreakCard('🔥', 'Logging Streak', '7 days', kPrimaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStreakCard('💧', 'Water Streak', '5 days', kAccentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStreakCard('🏃', 'Exercise Streak', '3 days', kSecondaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStreakCard('🥗', 'Healthy Eating', '12 days', Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(String emoji, String title, String days, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            days,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeetCodeAchievementsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  gradient: LinearGradient(
                    colors: [kAccentColor, Colors.amber],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievements',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Unlock badges by building healthy habits',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kAccentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_userProgress.unlockedRewards.length}/15',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kAccentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Beautiful Achievement Grid
          _buildBeautifulAchievementGrid(),
        ],
      ),
    );
  }

  Widget _buildBeautifulAchievementGrid() {
    final achievementData = [
      {'emoji': '🔥', 'title': 'Logger', 'description': '7 days', 'unlocked': true, 'color': Colors.orange},
      {'emoji': '💧', 'title': 'Hydration', 'description': '8 glasses', 'unlocked': true, 'color': Colors.blue},
      {'emoji': '🏃‍♂️', 'title': 'Fitness', 'description': '3 times', 'unlocked': true, 'color': Colors.green},
      {'emoji': '🥗', 'title': 'Healthy', 'description': 'Nutrition', 'unlocked': true, 'color': Colors.lightGreen},
      {'emoji': '⭐', 'title': 'Warrior', 'description': '7 streak', 'unlocked': true, 'color': Colors.amber},
      {'emoji': '💪', 'title': 'Strong', 'description': '15 days', 'unlocked': true, 'color': Colors.red},
      {'emoji': '🎯', 'title': 'Crusher', 'description': 'All goals', 'unlocked': false, 'color': Colors.purple},
      {'emoji': '🏆', 'title': 'Champion', 'description': '30 streak', 'unlocked': false, 'color': Colors.indigo},
      {'emoji': '👑', 'title': 'King', 'description': 'Perfect', 'unlocked': false, 'color': Colors.deepPurple},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemCount: achievementData.length,
      itemBuilder: (context, index) {
        final achievement = achievementData[index];
        return _buildSimpleAchievementCard(
          achievement['emoji'] as String,
          achievement['title'] as String,
          achievement['description'] as String,
          achievement['unlocked'] as bool,
          achievement['color'] as Color,
        );
      },
    );
  }

  Widget _buildSimpleAchievementCard(String emoji, String title, String description, bool isUnlocked, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isUnlocked 
            ? color.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnlocked ? color : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Achievement Icon
          Text(
            emoji,
            style: TextStyle(
              fontSize: 20,
              color: isUnlocked ? null : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          
          // Achievement Title
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? color : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 1),
          
          // Achievement Description
          Flexible(
            child: Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 7,
                color: isUnlocked ? kTextSecondary : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Status Indicator
          const SizedBox(height: 2),
          if (isUnlocked)
            Icon(
              Icons.check_circle,
              color: color,
              size: 10,
            )
          else
            Icon(
              Icons.lock,
              color: Colors.grey,
              size: 10,
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(UserAchievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              achievement.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Unlocked',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kAccentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
                  color: kSecondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard, color: kSecondaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Earned Rewards',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Recent Rewards
          _buildRecentRewards(),
          const SizedBox(height: 16),
          
          // All Rewards Grid
          _buildRewardsGrid(),
        ],
      ),
    );
  }

  Widget _buildRecentRewards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Rewards',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _buildRecentRewardItem('🎯', 'Goal Master', 'Completed 5 goals this week', '2 days ago', Colors.blue),
        const SizedBox(height: 8),
        _buildRecentRewardItem('💧', 'Hydration Hero', 'Drank 8 glasses for 7 days', '5 days ago', Colors.cyan),
      ],
    );
  }

  Widget _buildRecentRewardItem(String emoji, String title, String description, String time, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Rewards',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRewardCard('🎯', 'Goal Master', 'Complete 5 goals', Colors.blue, true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRewardCard('📊', 'Data Tracker', 'Log 30 days', Colors.green, true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRewardCard('💪', 'Fitness Fan', 'Exercise 20 days', Colors.orange, true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRewardCard('🥇', 'Champion', 'All achievements', Colors.purple, false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildRewardCard('💧', 'Hydration Hero', '7 day water streak', Colors.cyan, true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRewardCard('⭐', 'Perfect Week', 'Meet all goals', Colors.amber, false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardCard(String emoji, String title, String description, Color color, bool isEarned) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEarned 
            ? color.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEarned 
              ? color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Text(
                emoji, 
                style: TextStyle(
                  fontSize: 24,
                  color: isEarned ? null : Colors.grey,
                ),
              ),
              if (isEarned)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: kSuccessColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isEarned ? color : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isEarned 
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                  : Colors.grey.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (isEarned)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kSuccessColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Earned',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: kSuccessColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          title: Text('High', style: GoogleFonts.poppins(fontSize: 12)),
                          value: 'High',
                          groupValue: selectedPriority,
                          onChanged: (value) => setState(() => selectedPriority = value!),
                          activeColor: kErrorColor,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Medium', style: GoogleFonts.poppins(fontSize: 12)),
                          value: 'Medium',
                          groupValue: selectedPriority,
                          onChanged: (value) => setState(() => selectedPriority = value!),
                          activeColor: Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: Text('Low', style: GoogleFonts.poppins(fontSize: 12)),
                          value: 'Low',
                          groupValue: selectedPriority,
                          onChanged: (value) => setState(() => selectedPriority = value!),
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
                  child: Text('Cancel', style: GoogleFonts.poppins(color: kTextSecondary)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add Task', style: GoogleFonts.poppins(color: Colors.white)),
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
      // Create new task
      final newTask = {
        'id': 'task_${DateTime.now().millisecondsSinceEpoch}',
        'emoji': _getTaskEmoji(taskTitle),
        'title': taskTitle,
        'isCompleted': false,
        'priority': priority,
        'createdAt': DateTime.now(),
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
        
        // If task was just completed, add to recent activity
        if (!wasCompleted) {
          final completedTask = {
            'emoji': task['emoji'],
            'title': 'Completed: ${task['title']}',
            'time': 'Just now',
            'detail': 'Task completed',
            'entryId': 'task_${DateTime.now().millisecondsSinceEpoch}',
          };
          
          _completedTasks.insert(0, completedTask);
          // Keep only last 10 completed tasks
          if (_completedTasks.length > 10) {
            _completedTasks = _completedTasks.take(10).toList();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task completed: ${task['title']}'),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task marked as incomplete: ${task['title']}'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    });
  }

  String _getTaskEmoji(String task) {
    if (task.toLowerCase().contains('water')) return '💧';
    if (task.toLowerCase().contains('walk') || task.toLowerCase().contains('exercise')) return '🏃';
    if (task.toLowerCase().contains('vegetables') || task.toLowerCase().contains('eat')) return '🥗';
    if (task.toLowerCase().contains('log') || task.toLowerCase().contains('app')) return '📱';
    if (task.toLowerCase().contains('sleep')) return '😴';
    return '✅';
  }

  void _showDeleteTaskConfirmation(String taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child: Text('Cancel', style: GoogleFonts.poppins(color: kTextSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteTask(taskId, taskTitle);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kErrorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
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

}
