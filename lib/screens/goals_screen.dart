import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_colors.dart';
import '../models/user_goals.dart';
import '../services/firebase_service.dart';
import '../services/real_time_input_service.dart';
import '../services/calorie_units_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form controllers
  final _weightController = TextEditingController();
  final _calorieController = TextEditingController();
  final _bmiController = TextEditingController();
  final _waterController = TextEditingController();
  final _stepsController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();

  // Current values
  UserGoals? _currentGoals;
  bool _isLoading = true;
  bool _isSaving = false;

  final FirebaseService _firebaseService = FirebaseService();
  final RealTimeInputService _realTimeInputService = RealTimeInputService();
  final CalorieUnitsService _calorieUnitsService = CalorieUnitsService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _calorieUnitsService.initialize();
    _loadGoals();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _weightController.dispose();
    _calorieController.dispose();
    _bmiController.dispose();
    _waterController.dispose();
    _stepsController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final goals = await _firebaseService.getUserGoals(user.uid);
        setState(() {
          _currentGoals = goals;
          _populateFields();
        });
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateFields() {
    if (_currentGoals != null) {
      _weightController.text = _currentGoals!.weightGoal?.toString() ?? '';
      _calorieController.text = _calorieUnitsService.formatCaloriesShort(_currentGoals!.calorieGoal?.toDouble() ?? 2000);
      _bmiController.text = _currentGoals!.bmiGoal?.toString() ?? '';
      _waterController.text = _currentGoals!.waterGlassesGoal?.toString() ?? '';
      _stepsController.text = _currentGoals!.stepsPerDayGoal?.toString() ?? '';
      
      if (_currentGoals!.macroGoals != null) {
        _carbsController.text = _calorieUnitsService.formatCaloriesShort(_currentGoals!.macroGoals!.carbsCalories?.toDouble() ?? 900);
        _proteinController.text = _calorieUnitsService.formatCaloriesShort(_currentGoals!.macroGoals!.proteinCalories?.toDouble() ?? 500);
        _fatController.text = _calorieUnitsService.formatCaloriesShort(_currentGoals!.macroGoals!.fatCalories?.toDouble() ?? 600);
      } else {
        // Set default values
        _carbsController.text = _calorieUnitsService.formatCaloriesShort(MacroGoals.defaultMacros.carbsCalories?.toDouble() ?? 900);
        _proteinController.text = _calorieUnitsService.formatCaloriesShort(MacroGoals.defaultMacros.proteinCalories?.toDouble() ?? 500);
        _fatController.text = _calorieUnitsService.formatCaloriesShort(MacroGoals.defaultMacros.fatCalories?.toDouble() ?? 600);
      }
    } else {
      // Set default values for new users
      _calorieController.text = _calorieUnitsService.formatCaloriesShort(2000);
      _waterController.text = '8';
      _stepsController.text = '10000';
      _carbsController.text = _calorieUnitsService.formatCaloriesShort(MacroGoals.defaultMacros.carbsCalories?.toDouble() ?? 900);
      _proteinController.text = _calorieUnitsService.formatCaloriesShort(MacroGoals.defaultMacros.proteinCalories?.toDouble() ?? 500);
      _fatController.text = _calorieUnitsService.formatCaloriesShort(MacroGoals.defaultMacros.fatCalories?.toDouble() ?? 600);
    }
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final goals = UserGoals(
          weightGoal: double.tryParse(_weightController.text),
          calorieGoal: _calorieUnitsService.convertToKcal(double.tryParse(_calorieController.text) ?? 2000).round(),
          bmiGoal: double.tryParse(_bmiController.text),
          waterGlassesGoal: int.tryParse(_waterController.text),
          stepsPerDayGoal: int.tryParse(_stepsController.text),
          macroGoals: MacroGoals(
            carbsCalories: _calorieUnitsService.convertToKcal(double.tryParse(_carbsController.text) ?? 900).round(),
            proteinCalories: _calorieUnitsService.convertToKcal(double.tryParse(_proteinController.text) ?? 500).round(),
            fatCalories: _calorieUnitsService.convertToKcal(double.tryParse(_fatController.text) ?? 600).round(),
          ),
          lastUpdated: DateTime.now(),
        );

        // Use real-time input service for faster updates
        await _realTimeInputService.handleUserGoalsUpdate(
          context,
          goals,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Goals saved successfully! 🎯'),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving goals: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Set Your Goals',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                                             _buildWeightGoalCard(),
                       const SizedBox(height: 16),
                       _buildCalorieGoalCard(),
                       const SizedBox(height: 16),
                       _buildBMIGoalCard(),
                       const SizedBox(height: 16),
                       _buildWaterGoalCard(),
                       const SizedBox(height: 16),
                       _buildStepsGoalCard(),
                       const SizedBox(height: 16),
                       _buildMacroGoalsCard(),
                      const SizedBox(height: 32),
                      _buildSaveButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
              Icons.flag,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your goals...',
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
    );
  }

  Widget _buildHeader() {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Your Health Goals',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define your targets for a healthier lifestyle',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightGoalCard() {
    return _buildGoalCard(
      title: 'Weight Goal',
      icon: Icons.monitor_weight,
      color: kAccentColor,
      child: TextField(
        controller: _weightController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter target weight (kg)',
          suffixText: 'kg',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildCalorieGoalCard() {
    return _buildGoalCard(
      title: 'Daily Calorie Goal',
      icon: Icons.local_fire_department,
      color: kSecondaryColor,
      child: TextField(
        controller: _calorieController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter daily calorie target',
          suffixText: _calorieUnitsService.unitSuffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildBMIGoalCard() {
    return _buildGoalCard(
      title: 'BMI Goal',
      icon: Icons.analytics,
      color: kAccentBlue,
      child: TextField(
        controller: _bmiController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter target BMI',
          suffixText: 'BMI',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildWaterGoalCard() {
    return _buildGoalCard(
      title: 'Daily Water Goal',
      icon: Icons.water_drop,
      color: kAccentBlue,
      child: TextField(
        controller: _waterController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter daily water glasses',
          suffixText: 'glasses',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildStepsGoalCard() {
    return _buildGoalCard(
      title: 'Daily Steps Goal',
      icon: Icons.directions_walk,
      color: kSecondaryColor,
      child: TextField(
        controller: _stepsController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Enter daily steps target',
          suffixText: 'steps',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildMacroGoalsCard() {
    return _buildGoalCard(
      title: 'Macro Nutrient Goals',
      icon: Icons.pie_chart,
      color: kPrimaryColor,
      child: Column(
        children: [
          // Macro distribution header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor.withValues(alpha: 0.1), kAccentColor.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_outline, color: kPrimaryColor, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Macro Distribution',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set your daily macro targets in calories',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: kPrimaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Individual macro input fields
          _buildMacroField(
            controller: _carbsController,
            label: 'Carbohydrates',
            icon: Icons.grain,
            color: Colors.orange,
            description: 'Primary energy source',
          ),
          const SizedBox(height: 16),
          
          _buildMacroField(
            controller: _proteinController,
            label: 'Protein',
            icon: Icons.fitness_center,
            color: Colors.red,
            description: 'Muscle building & repair',
          ),
          const SizedBox(height: 16),
          
          _buildMacroField(
            controller: _fatController,
            label: 'Fat',
            icon: Icons.opacity,
            color: Colors.blue,
            description: 'Essential nutrients & energy',
          ),
          const SizedBox(height: 20),
          
          // Total calculation and recommendations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: kAccentColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kAccentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calculate, color: kAccentColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recommended Distribution',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kAccentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroRecommendation(
                        label: 'Carbs',
                        value: '45-65%',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMacroRecommendation(
                        label: 'Protein',
                        value: '10-35%',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMacroRecommendation(
                        label: 'Fat',
                        value: '20-35%',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total should equal your daily calorie goal',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kAccentColor.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    required String description,
  }) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter $label calories',
              suffixText: _calorieUnitsService.unitSuffix,
              prefixIcon: Icon(Icons.local_fire_department, color: color, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRecommendation({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveGoals,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Save Goals',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
