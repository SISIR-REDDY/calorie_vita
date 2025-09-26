import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ui/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/app_state_service.dart';
import '../models/user_goals.dart';
import '../models/user_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onCompleted;
  
  const OnboardingScreen({super.key, this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form controllers
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Form state
  String? _selectedGender;
  String? _selectedActivityLevel;
  String? _selectedFitnessGoal;
  String? _selectedDietPreference;
  int _currentStep = 0;
  bool _isLoading = false;

  // Services
  final FirebaseService _firebaseService = FirebaseService();
  final AppStateService _appStateService = AppStateService();

  // Gender options
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  // Activity level options
  final List<Map<String, String>> _activityLevels = [
    {
      'value': 'sedentary',
      'label': 'Sedentary',
      'description': 'Little to no exercise, desk job'
    },
    {
      'value': 'lightly_active',
      'label': 'Lightly Active',
      'description': 'Light exercise 1-3 days/week'
    },
    {
      'value': 'moderately_active',
      'label': 'Moderately Active',
      'description': 'Moderate exercise 3-5 days/week'
    },
    {
      'value': 'very_active',
      'label': 'Very Active',
      'description': 'Heavy exercise 6-7 days/week'
    },
    {
      'value': 'extremely_active',
      'label': 'Extremely Active',
      'description': 'Very heavy exercise, physical job'
    },
  ];

  // Fitness goal options
  final List<Map<String, String>> _fitnessGoals = [
    {
      'value': 'weight_loss',
      'label': 'Weight Loss',
      'description': 'Lose weight and burn fat'
    },
    {
      'value': 'weight_gain',
      'label': 'Weight Gain',
      'description': 'Gain muscle and weight'
    },
    {
      'value': 'maintenance',
      'label': 'Maintenance',
      'description': 'Maintain current weight'
    },
    {
      'value': 'muscle_building',
      'label': 'Muscle Building',
      'description': 'Build muscle and strength'
    },
  ];

  // Diet preference options - must match profile edit screen exactly
  final List<Map<String, String>> _dietPreferences = [
    {
      'value': 'no_restrictions',
      'label': 'No Restrictions',
      'description': 'All foods in moderation'
    },
    {
      'value': 'vegetarian',
      'label': 'Vegetarian',
      'description': 'No meat, includes dairy and eggs'
    },
    {
      'value': 'vegan',
      'label': 'Vegan',
      'description': 'No animal products'
    },
    {
      'value': 'keto',
      'label': 'Keto',
      'description': 'Low carb, high fat'
    },
    {
      'value': 'paleo',
      'label': 'Paleo',
      'description': 'Whole foods, no processed'
    },
    {
      'value': 'mediterranean',
      'label': 'Mediterranean',
      'description': 'Olive oil, fish, vegetables'
    },
    {
      'value': 'low_carb',
      'label': 'Low Carb',
      'description': 'Reduced carbohydrate intake'
    },
    {
      'value': 'high_protein',
      'label': 'High Protein',
      'description': 'Increased protein consumption'
    },
    {
      'value': 'gluten_free',
      'label': 'Gluten Free',
      'description': 'No gluten-containing foods'
    },
    {
      'value': 'dairy_free',
      'label': 'Dairy Free',
      'description': 'No dairy products'
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupTextControllers();
  }

  void _setupTextControllers() {
    // Add listeners to text controllers to trigger rebuild when text changes
    _ageController.addListener(() {
      setState(() {});
    });
    _heightController.addListener(() {
      setState(() {});
    });
    _weightController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Handle back button press
          if (_currentStep > 0) {
            _previousStep();
          } else {
            _goBackToWelcomeScreen();
          }
        }
      },
      child: Scaffold(
        backgroundColor: kAppBackground,
        body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildStepContent(),
                  ),
                ),
                _buildNavigation(),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          // Logo
          Image.asset(
            'calorie_logo.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          
          // Title
          Text(
            'Welcome to Calorie Vita!',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          
          // Subtitle
          Text(
            'Let\'s set up your profile to personalize your experience',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
            decoration: BoxDecoration(
              color: index <= _currentStep
                  ? kPrimaryColor
                  : kBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildActivityLevelStep();
      case 2:
        return _buildFitnessGoalStep();
      case 3:
        return _buildDietPreferenceStep();
      default:
        return _buildPersonalInfoStep();
    }
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'Personal Information',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about yourself to get personalized recommendations',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Age
          _buildInputField(
            controller: _ageController,
            label: 'Age',
            hint: 'Enter your age',
            suffix: 'years',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          
          // Gender
          Text(
            'Gender',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildGenderSelector(),
          const SizedBox(height: 24),
          
          // Height
          _buildInputField(
            controller: _heightController,
            label: 'Height',
            hint: 'Enter your height',
            suffix: 'cm',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          
          // Weight
          _buildInputField(
            controller: _weightController,
            label: 'Weight',
            hint: 'Enter your weight',
            suffix: 'kg',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24), // Extra spacing at bottom
        ],
    );
  }

  Widget _buildActivityLevelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'Activity Level',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'How active are you on a typical day?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          ..._activityLevels.map((level) => _buildOptionCard(
            title: level['label']!,
            description: level['description']!,
            value: level['value']!,
            groupValue: _selectedActivityLevel,
            onChanged: (value) {
              setState(() {
                _selectedActivityLevel = value;
              });
            },
          )).toList(),
          const SizedBox(height: 24), // Extra spacing at bottom
        ],
    );
  }

  Widget _buildFitnessGoalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'Fitness Goal',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What do you want to achieve?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          ..._fitnessGoals.map((goal) => _buildOptionCard(
            title: goal['label']!,
            description: goal['description']!,
            value: goal['value']!,
            groupValue: _selectedFitnessGoal,
            onChanged: (value) {
              setState(() {
                _selectedFitnessGoal = value;
              });
            },
          )).toList(),
          const SizedBox(height: 24), // Extra spacing at bottom
        ],
    );
  }

  Widget _buildDietPreferenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            'Diet Preference',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What type of diet do you follow?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          ..._dietPreferences.map((diet) => _buildOptionCard(
            title: diet['label']!,
            description: diet['description']!,
            value: diet['value']!,
            groupValue: _selectedDietPreference,
            onChanged: (value) {
              setState(() {
                _selectedDietPreference = value;
              });
            },
          )).toList(),
          const SizedBox(height: 24), // Extra spacing at bottom
        ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: kSurfaceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: _genderOptions.map((gender) {
        final isSelected = _selectedGender == gender;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = gender;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : kSurfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? kPrimaryColor : kBorderColor,
                  width: 2,
                ),
              ),
              child: Text(
                gender,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : kTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required String value,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    final isSelected = groupValue == value;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? kPrimaryColor.withValues(alpha: 0.1) : kSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? kPrimaryColor : kBorderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? kPrimaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? kPrimaryColor : kBorderColor,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? kPrimaryColor : kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isSelected ? kPrimaryColor.withValues(alpha: 0.8) : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: TextButton(
                onPressed: _previousStep,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: kBorderColor),
                  ),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: Builder(
              builder: (context) {
                final canProceed = _canProceed();
                print('Button state - Step: $_currentStep, Can proceed: $canProceed');
                return ElevatedButton(
                  onPressed: canProceed ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed ? kPrimaryColor : kBorderColor,
                    foregroundColor: canProceed ? Colors.white : kTextSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _currentStep == 3 ? 'Complete Setup' : 'Next',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    bool canProceed = false;
    switch (_currentStep) {
      case 0:
        canProceed = _ageController.text.isNotEmpty &&
            _selectedGender != null &&
            _heightController.text.isNotEmpty &&
            _weightController.text.isNotEmpty;
        print('Step 0 - Age: ${_ageController.text}, Gender: $_selectedGender, Height: ${_heightController.text}, Weight: ${_weightController.text}, Can proceed: $canProceed');
        break;
      case 1:
        canProceed = _selectedActivityLevel != null;
        print('Step 1 - Activity Level: $_selectedActivityLevel, Can proceed: $canProceed');
        break;
      case 2:
        canProceed = _selectedFitnessGoal != null;
        print('Step 2 - Fitness Goal: $_selectedFitnessGoal, Can proceed: $canProceed');
        break;
      case 3:
        canProceed = _selectedDietPreference != null;
        print('Step 3 - Diet Preference: $_selectedDietPreference, Can proceed: $canProceed');
        break;
      default:
        canProceed = false;
    }
    return canProceed;
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      // If on initial step, go back to welcome screen
      _goBackToWelcomeScreen();
    }
  }

  /// Navigate back to welcome screen
  void _goBackToWelcomeScreen() {
    // Navigate to welcome screen
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  void _nextStep() {
    print('Next step pressed - Current step: $_currentStep, Can proceed: ${_canProceed()}');
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      print('Moved to step: $_currentStep');
    } else {
      print('Completing onboarding...');
      _completeOnboarding();
    }
  }

  // Map activity level from onboarding to profile edit format
  String _mapActivityLevel(String value) {
    switch (value) {
      case 'sedentary':
        return 'Sedentary';
      case 'lightly_active':
        return 'Lightly Active';
      case 'moderately_active':
        return 'Moderately Active';
      case 'very_active':
        return 'Very Active';
      case 'extremely_active':
        return 'Extremely Active';
      default:
        return 'Moderately Active';
    }
  }

  // Map fitness goal from onboarding to profile edit format
  String _mapFitnessGoal(String value) {
    switch (value) {
      case 'weight_loss':
        return 'Weight Loss';
      case 'weight_gain':
        return 'Weight Gain';
      case 'maintenance':
        return 'Maintenance';
      case 'muscle_building':
        return 'Muscle Building';
      default:
        return 'Maintenance';
    }
  }

  // Map diet preference from onboarding to profile edit format
  String _mapDietPreference(String value) {
    switch (value) {
      case 'no_restrictions':
        return 'No Restrictions';
      case 'vegetarian':
        return 'Vegetarian';
      case 'vegan':
        return 'Vegan';
      case 'keto':
        return 'Keto';
      case 'paleo':
        return 'Paleo';
      case 'mediterranean':
        return 'Mediterranean';
      case 'low_carb':
        return 'Low Carb';
      case 'high_protein':
        return 'High Protein';
      case 'gluten_free':
        return 'Gluten Free';
      case 'dairy_free':
        return 'Dairy Free';
      default:
        return 'No Restrictions';
    }
  }

  // Calculate BMI from weight and height
  double _calculateBMI(double weight, double height) {
    if (height <= 0) return 0.0;
    final heightInMeters = height / 100.0; // Convert cm to meters
    return weight / (heightInMeters * heightInMeters);
  }

  // Create initial goals based on onboarding data
  Future<void> _createInitialGoals(String userId, Map<String, dynamic> profileData) async {
    try {
      final age = profileData['age'] as int;
      final gender = profileData['gender'] as String;
      final height = profileData['height'] as double;
      final weight = profileData['weight'] as double;
      final activityLevel = profileData['activityLevel'] as String;
      final fitnessGoal = profileData['fitnessGoal'] as String;

      // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
      double bmr;
      if (gender.toLowerCase() == 'male') {
        bmr = 10 * weight + 6.25 * height - 5 * age + 5;
      } else {
        bmr = 10 * weight + 6.25 * height - 5 * age - 161;
      }

      // Calculate TDEE (Total Daily Energy Expenditure) based on activity level
      double tdee = bmr;
      switch (activityLevel.toLowerCase()) {
        case 'sedentary':
          tdee = bmr * 1.2;
          break;
        case 'lightly active':
          tdee = bmr * 1.375;
          break;
        case 'moderately active':
          tdee = bmr * 1.55;
          break;
        case 'very active':
          tdee = bmr * 1.725;
          break;
        case 'extremely active':
          tdee = bmr * 1.9;
          break;
      }

      // Adjust calorie goal based on fitness goal
      double calorieGoal = tdee;
      switch (fitnessGoal.toLowerCase()) {
        case 'weight loss':
          calorieGoal = tdee - 500; // 500 calorie deficit
          break;
        case 'weight gain':
          calorieGoal = tdee + 500; // 500 calorie surplus
          break;
        case 'muscle building':
          calorieGoal = tdee + 300; // 300 calorie surplus
          break;
        case 'maintenance':
        default:
          calorieGoal = tdee;
          break;
      }

      // Create initial goals
      final initialGoals = {
        'calorieGoal': calorieGoal.round(),
        'waterGlassesGoal': 8,
        'stepsPerDayGoal': 10000,
        'sleepGoal': 8.0,
        'fitnessGoal': fitnessGoal,
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Save to Firebase
      await _firebaseService.saveUserGoals(userId, UserGoals.fromMap(initialGoals));
      
      print('Initial goals created for user: $userId');
    } catch (e) {
      print('Error creating initial goals: $e');
    }
  }

  // Create initial preferences based on onboarding data
  Future<void> _createInitialPreferences(String userId, Map<String, dynamic> profileData) async {
    try {
      final dietPreference = profileData['dietPreference'] as String;
      final fitnessGoal = profileData['fitnessGoal'] as String;

      // Create initial preferences
      final initialPreferences = {
        'notificationsEnabled': true,
        'waterReminders': true,
        'mealReminders': true,
        'exerciseReminders': true,
        'weeklyReports': true,
        'dietPreference': dietPreference,
        'fitnessGoal': fitnessGoal,
        'units': 'metric', // Default to metric
        'theme': 'system', // Default to system theme
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Save to Firebase
      await _firebaseService.saveUserPreferences(userId, UserPreferences.fromMap(initialPreferences));
      
      print('Initial preferences created for user: $userId');
    } catch (e) {
      print('Error creating initial preferences: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Prepare comprehensive profile data for Firebase storage
      final profileData = {
        // Basic personal information
        'age': int.tryParse(_ageController.text) ?? 25,
        'gender': _selectedGender ?? 'Other',
        'height': double.tryParse(_heightController.text) ?? 170.0,
        'weight': double.tryParse(_weightController.text) ?? 70.0,
        
        // Activity and fitness information
        'activityLevel': _mapActivityLevel(_selectedActivityLevel ?? 'moderately_active'),
        'fitnessGoal': _mapFitnessGoal(_selectedFitnessGoal ?? 'maintenance'),
        'dietPreference': _mapDietPreference(_selectedDietPreference ?? 'no_restrictions'),
        
        // Onboarding completion status
        'onboardingCompleted': true,
        'onboardingCompletedAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
        
        // Additional profile metadata
        'profileCreatedAt': DateTime.now().toIso8601String(),
        'profileVersion': '1.0',
        'source': 'onboarding',
        
        // Calculate BMI for immediate use
        'bmi': _calculateBMI(
          double.tryParse(_weightController.text) ?? 70.0,
          double.tryParse(_heightController.text) ?? 170.0,
        ),
        
        // Store raw onboarding values for reference
        'onboardingData': {
          'age': int.tryParse(_ageController.text) ?? 25,
          'gender': _selectedGender ?? 'Other',
          'height': double.tryParse(_heightController.text) ?? 170.0,
          'weight': double.tryParse(_weightController.text) ?? 70.0,
          'activityLevel': _selectedActivityLevel ?? 'moderately_active',
          'fitnessGoal': _selectedFitnessGoal ?? 'maintenance',
          'dietPreference': _selectedDietPreference ?? 'no_restrictions',
        },
      };

      // Save to Firebase
      await _firebaseService.saveUserProfileData(user.uid, profileData);

      // Create initial goals based on onboarding data
      await _createInitialGoals(user.uid, profileData);

      // Create initial preferences based on onboarding data
      await _createInitialPreferences(user.uid, profileData);

      // Update AppStateService
      _appStateService.forceProfileDataUpdate(profileData);

      // Show success message and call completion callback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile setup completed! 🎉'),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        
        // Call completion callback if provided
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else {
          // Fallback: navigate back
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: kErrorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
