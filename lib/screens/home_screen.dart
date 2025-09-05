import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/simple_streak_system.dart';
import '../services/app_state_service.dart';
import '../services/firebase_service.dart';
import '../services/dynamic_icon_service.dart';
import '../services/real_time_input_service.dart';
import '../services/daily_summary_service.dart';
import '../services/simple_streak_service.dart';
import '../services/calorie_units_service.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Services
  final FirebaseService _firebaseService = FirebaseService();
  final RealTimeInputService _realTimeInputService = RealTimeInputService();
  final DailySummaryService _dailySummaryService = DailySummaryService();
  final SimpleStreakService _streakService = SimpleStreakService();
  final CalorieUnitsService _calorieUnitsService = CalorieUnitsService();
  
  // Data
  DailySummary? _dailySummary;
  MacroBreakdown? _macroBreakdown;
  UserPreferences _preferences = const UserPreferences();
  String _motivationalQuote = '';
  bool _isLoading = true;
  bool _isStreakLoading = true;
  UserStreakSummary _streakSummary = UserStreakSummary(
    goalStreaks: {},
    totalActiveStreaks: 0,
    longestOverallStreak: 0,
    lastActivityDate: DateTime.now(),
    totalDaysActive: 0,
  );
  String? _currentUserId;
  
  // Task management
  List<Map<String, dynamic>> _tasks = [
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
      'emoji': DynamicIconService().generateIcon('Eat 5 servings of vegetables'),
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
    _initializeServices();
    _setupStreamListeners();
    _loadData();
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
        _realTimeInputService.getTodaySummary(_currentUserId!).listen((summary) {
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
    } catch (e) {
      debugPrint('Stream setup error: $e');
    }
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
      // Load mock data for demo mode
      await _loadDailySummary('demo_user');
      await _loadPreferences('demo_user');
      await _loadStreakData();
      _loadMotivationalQuote();
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



  Future<void> _loadStreakData() async {
    try {
      // Provide immediate fallback data for better UX
      _streakSummary = _getDefaultStreakData();
      setState(() => _isStreakLoading = false);
      
      // Load actual streak data from the service in background
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

  /// Handle water intake input
  Future<void> _handleWaterIntake() async {
    if (_currentUserId == null) return;

    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Water Intake'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many glasses of water did you drink?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Glasses',
                hintText: 'Enter number of glasses',
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
              final glasses = int.tryParse(controller.text);
              if (glasses != null) {
                Navigator.pop(context, glasses);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _realTimeInputService.handleWaterIntake(context, result);
    }
  }

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

  /// Handle sleep hours input
  Future<void> _handleSleepHours() async {
    if (_currentUserId == null) return;

    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Sleep'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How many hours did you sleep?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sleep Hours',
                hintText: 'e.g., 7.5',
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
              final hours = double.tryParse(controller.text);
              if (hours != null) {
                Navigator.pop(context, hours);
              }
            },
            child: const Text('Log Sleep'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _realTimeInputService.handleSleepHours(context, result);
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimaryColor.withValues(alpha: 0.1),
              kPrimaryColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: kPrimaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.1),
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
                      colors: [kPrimaryColor, kPrimaryColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withValues(alpha: 0.3),
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
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Date badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    _calorieUnitsService.formatCaloriesShort(_dailySummary!.caloriesConsumed.toDouble()),
                    _calorieUnitsService.unitSuffix,
                    Icons.restaurant,
                    kAccentColor,
                    'Calories eaten today',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEnhancedSummaryCard(
                    'Burned',
                    _calorieUnitsService.formatCaloriesShort(_dailySummary!.caloriesBurned.toDouble()),
                    _calorieUnitsService.unitSuffix,
                    Icons.directions_run,
                    kSecondaryColor,
                    'Calories burned today',
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

  Widget _buildEnhancedSummaryCard(String label, String value, String unit, IconData icon, Color color, String description) {
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesToTargetCard() {
    final caloriesToTarget = _dailySummary!.caloriesGoal - _dailySummary!.caloriesConsumed;
    final isReached = caloriesToTarget <= 0;
    final color = isReached ? const Color(0xFF2196F3) : kAccentColor; // Blue when reached, red when working
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
                    ? 'Congratulations!'
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
                    ? 'You have successfully reached your daily calorie goal'
                    : 'Keep going to reach your daily target',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

  Widget _buildDailyGoalsSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryColor.withValues(alpha: 0.1), kPrimaryColor.withValues(alpha: 0.05)],
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            
            // Main Goals Grid
            Row(
              children: [
                Expanded(
                  child: _buildGoalCard(
                    'Calories',
                    _calorieUnitsService.formatCaloriesShort(_dailySummary?.caloriesConsumed.toDouble() ?? 0),
                    _calorieUnitsService.formatCaloriesShort(_dailySummary?.caloriesGoal.toDouble() ?? 2000),
                    _calorieUnitsService.unitSuffix,
                    Icons.local_fire_department,
                    kAccentColor,
                    (_dailySummary?.calorieProgress ?? 0.0) * 100,
                    () => _showCalorieGoalDialog(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGoalCard(
                    'Water',
                    '${_dailySummary?.waterIntake ?? 0}',
                    '${_dailySummary?.waterGoal ?? 8}',
                    'glasses',
                    Icons.water_drop,
                    kAccentBlue,
                    (_dailySummary?.waterProgress ?? 0.0) * 100,
                    () => _handleWaterIntake(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    () => _handleSteps(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGoalCard(
                    'Sleep',
                    '${_dailySummary?.sleepHours.toStringAsFixed(1) ?? '0.0'}',
                    '${_dailySummary?.sleepGoal.toStringAsFixed(1) ?? '8.0'}',
                    'hours',
                    Icons.bedtime,
                    kAccentPurple,
                    (_dailySummary?.sleepProgress ?? 0.0) * 100,
                    () => _handleSleepHours(),
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
                    child: const Icon(Icons.trending_up, color: kSuccessColor, size: 20),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildGoalCard(String title, String current, String target, String unit, IconData icon, Color color, double progress, VoidCallback onTap) {
    final isCompleted = progress >= 100;
    final progressColor = isCompleted ? kSuccessColor : color;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180, // Fixed height for consistent sizing
        padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted ? kSuccessColor.withValues(alpha: 0.4) : color.withValues(alpha: 0.3),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              '${progress.round()}% complete',
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
                    weekStart: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Goal Streaks',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        if (_isStreakLoading)
          ...List.generate(4, (index) => 
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GoalStreakCard(
                streak: _streakSummary.goalStreaks.values.first,
                isLoading: true,
                onTap: () {},
              ),
            ),
          )
        else
        ..._streakSummary.goalStreaks.values.map((streak) => 
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GoalStreakCard(
              streak: streak,
              onTap: () {
                // Handle goal tap if needed
              },
            ),
          ),
        ).toList(),
      ],
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
                  _buildGoalStreaksSection(),
                  const SizedBox(height: 24),
                  
                  // Streak Motivation
                  StreakMotivationWidget(
                    streakSummary: _streakSummary,
                  ),
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
              final hasStreak = false; // Simplified for streak system
              final hasReward = false; // Simplified for streak system
              
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
      // Create new task with improved icon generation
      final dynamicIconService = DynamicIconService();
      final bestCategory = dynamicIconService.getBestCategory(taskTitle);
      final confidence = dynamicIconService.getCategoryConfidence(taskTitle, bestCategory);
      
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
    // Use the enhanced dynamic icon service with contextual awareness
    final dynamicIconService = DynamicIconService();
    
    // Get contextual icons based on current time
    final contextualIcons = dynamicIconService.getContextualIcons(task, timeOfDay: DateTime.now());
    
    // Return the first contextual icon if available, otherwise use the best match
    return contextualIcons.isNotEmpty ? contextualIcons.first : dynamicIconService.generateIcon(task);
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

  // Helper methods for Daily Goals section
  String _getDailyProgressMessage() {
    final calorieProgress = (_dailySummary?.calorieProgress ?? 0.0) * 100;
    final waterProgress = (_dailySummary?.waterProgress ?? 0.0) * 100;
    final stepsProgress = (_dailySummary?.stepsProgress ?? 0.0) * 100;
    final sleepProgress = (_dailySummary?.sleepProgress ?? 0.0) * 100;
    
    final completedGoals = [calorieProgress, waterProgress, stepsProgress, sleepProgress]
        .where((progress) => progress >= 100).length;
    
    if (completedGoals == 4) {
      return 'Amazing! You\'ve completed all your daily goals! 🎉';
    } else if (completedGoals >= 3) {
      return 'Great progress! You\'re almost there! 💪';
    } else if (completedGoals >= 2) {
      return 'Good job! Keep up the momentum! 🌟';
    } else if (completedGoals >= 1) {
      return 'Nice start! Keep going! 🚀';
    } else {
      return 'Ready to start your healthy day? Let\'s go! 💫';
    }
  }

  double _getOverallProgressPercentage() {
    final calorieProgress = (_dailySummary?.calorieProgress ?? 0.0) * 100;
    final waterProgress = (_dailySummary?.waterProgress ?? 0.0) * 100;
    final stepsProgress = (_dailySummary?.stepsProgress ?? 0.0) * 100;
    final sleepProgress = (_dailySummary?.sleepProgress ?? 0.0) * 100;
    
    return (calorieProgress + waterProgress + stepsProgress + sleepProgress) / 4;
  }

  void _showCalorieGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calorie Goal'),
        content: const Text('Your calorie goal is set to 2000 calories. You can adjust this in the Goals & Targets screen.'),
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
