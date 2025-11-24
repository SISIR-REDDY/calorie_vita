import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';
import '../services/real_time_input_service.dart';
import '../services/app_state_service.dart';
import '../widgets/setup_warning_popup.dart';
import '../services/setup_check_service.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Comprehensive Profile Editing Screen for Calorie Vita App
/// Features: Personal info, fitness goals, preferences, profile photo
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _professionController = TextEditingController();
  final _bioController = TextEditingController();

  // Form state variables
  String? _selectedGender;
  String? _selectedActivityLevel;
  String? _selectedFitnessGoal;
  String? _selectedDietPreference;
  String? _selectedProfession;
  List<String> _selectedHobbies = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _profileImageUrl;

  // User reference
  User? _user;
  String? _userId;

  // Services
  final RealTimeInputService _realTimeInputService = RealTimeInputService();
  final AppStateService _appStateService = AppStateService();

  // Dropdown options
  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say'
  ];
  final List<String> _activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
    'Extremely Active'
  ];
  final List<String> _fitnessGoals = [
    'Weight Loss',
    'Weight Gain',
    'Muscle Building',
    'Maintenance',
    'General Fitness',
    'Athletic Performance'
  ];
  final List<String> _dietPreferences = [
    'No Restrictions',
    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
    'Mediterranean',
    'Low Carb',
    'High Protein',
    'Gluten Free',
    'Dairy Free'
  ];

  // Profession options
  final List<String> _professionOptions = [
    'Software Developer',
    'Designer',
    'Engineer',
    'Doctor',
    'Teacher',
    'Student',
    'Business Owner',
    'Marketing',
    'Sales',
    'Finance',
    'Healthcare',
    'Education',
    'Technology',
    'Media',
    'Sports',
    'Artist',
    'Writer',
    'Lawyer',
    'Consultant',
    'Other'
  ];

  // Hobbies options
  final List<String> _hobbiesOptions = [
    'Reading',
    'Writing',
    'Photography',
    'Music',
    'Sports',
    'Gaming',
    'Cooking',
    'Traveling',
    'Painting',
    'Dancing',
    'Swimming',
    'Running',
    'Cycling',
    'Hiking',
    'Yoga',
    'Meditation',
    'Gardening',
    'Movies',
    'Art',
    'Fitness',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _hobbiesController.dispose();
    _professionController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Initialize current user
  void _initializeUser() {
    _user = FirebaseAuth.instance.currentUser;
    _userId = _user?.uid;
    if (_user != null) {
      _nameController.text = _user!.displayName ?? '';
      _emailController.text = _user!.email ?? '';
    }
  }

  /// Load user profile data from Firestore
  Future<void> _loadUserProfile() async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('profile')
          .doc('userData')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Load name from Firestore if available, otherwise keep Auth name
          if (data['name'] != null && data['name'].toString().isNotEmpty) {
            _nameController.text = data['name'];
          }
          // Only set text if the value is not null and not 0.0
          if (data['age'] != null && data['age'] != 0) {
            _ageController.text = data['age'].toString();
          }
          if (data['height'] != null && data['height'] != 0.0) {
            _heightController.text = data['height'].toString();
          }
          if (data['weight'] != null && data['weight'] != 0.0) {
            _weightController.text = data['weight'].toString();
          }
          _hobbiesController.text = data['hobbies'] ?? '';
          _professionController.text = data['profession'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _selectedGender = data['gender'];
          _selectedActivityLevel = data['activityLevel'];
          _selectedFitnessGoal = data['fitnessGoal'];
          _selectedDietPreference = data['dietPreference'];
          _selectedProfession = data['profession'];
          _selectedHobbies = data['hobbiesList'] != null
              ? List<String>.from(data['hobbiesList'])
              : [];
          _profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Save profile data to Firestore with real-time updates
  Future<void> _saveProfile() async {
    // Optional validation - only validate if fields have content
    if (_nameController.text.trim().isNotEmpty &&
        _nameController.text.trim().length < 2) {
      _showErrorSnackBar('Name must be at least 2 characters if provided');
      return;
    }

    if (_ageController.text.trim().isNotEmpty) {
      final age = int.tryParse(_ageController.text);
      if (age == null || age < 1 || age > 120) {
        _showErrorSnackBar('Please enter a valid age (1-120) if provided');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      // Prepare user data with only non-empty values
      final userData = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Only add fields that have values
      if (_nameController.text.trim().isNotEmpty) {
        userData['name'] = _nameController.text.trim();
      }
      if (_emailController.text.trim().isNotEmpty) {
        userData['email'] = _emailController.text.trim();
      }
      if (_ageController.text.trim().isNotEmpty) {
        final age = int.tryParse(_ageController.text);
        if (age != null) userData['age'] = age;
      }
      if (_heightController.text.trim().isNotEmpty) {
        final height = double.tryParse(_heightController.text);
        if (height != null) userData['height'] = height;
      }
      if (_weightController.text.trim().isNotEmpty) {
        final weight = double.tryParse(_weightController.text);
        if (weight != null) userData['weight'] = weight;
      }
      if (_selectedGender != null) {
        userData['gender'] = _selectedGender;
      }
      if (_selectedActivityLevel != null) {
        userData['activityLevel'] = _selectedActivityLevel;
      }
      if (_selectedFitnessGoal != null) {
        userData['fitnessGoal'] = _selectedFitnessGoal;
      }
      if (_selectedDietPreference != null) {
        userData['dietPreference'] = _selectedDietPreference;
      }
      if (_selectedProfession != null) {
        userData['profession'] = _selectedProfession;
      }
      if (_hobbiesController.text.trim().isNotEmpty) {
        userData['hobbies'] = _hobbiesController.text.trim();
      }
      if (_selectedHobbies.isNotEmpty) {
        userData['hobbiesList'] = _selectedHobbies;
      }
      if (_professionController.text.trim().isNotEmpty) {
        userData['profession'] = _professionController.text.trim();
      }
      if (_bioController.text.trim().isNotEmpty) {
        userData['bio'] = _bioController.text.trim();
      }
      if (_profileImageUrl != null) {
        userData['profileImageUrl'] = _profileImageUrl;
      }

      // Use real-time input service for faster updates
      await _realTimeInputService.handleProfileUpdate(
        context,
        userData,
      );

      // Update AppStateService to trigger real-time updates
      _appStateService.forceProfileDataUpdate(userData);
      if (kDebugMode) debugPrint('Profile data updated in AppStateService: $userData');

      // Update Firebase Auth display name if name is provided
      if (_user != null && _nameController.text.trim().isNotEmpty) {
        await _user!.updateDisplayName(_nameController.text.trim());
      }

      _showSuccessSnackBar('Profile updated successfully! 🎉');
      
      // Check if setup is now complete and mark it
      _checkAndMarkSetupComplete();
      
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      _showErrorSnackBar('Error saving profile: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: kErrorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: kAccentGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Check if setup is complete and mark it
  Future<void> _checkAndMarkSetupComplete() async {
    try {
      // Check if setup is complete
      final isComplete = await SetupCheckService.isSetupComplete();
      
      if (isComplete) {
        await SetupWarningService.markSetupComplete();
        if (kDebugMode) debugPrint('Setup marked as complete!');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking setup completion: $e');
    }
  }

  /// Get activity level description
  String _getActivityLevelDescription(String level) {
    switch (level) {
      case 'Sedentary':
        return 'Little to no exercise';
      case 'Lightly Active':
        return 'Light exercise 1-3 days/week';
      case 'Moderately Active':
        return 'Moderate exercise 3-5 days/week';
      case 'Very Active':
        return 'Hard exercise 6-7 days/week';
      case 'Extremely Active':
        return 'Very hard exercise, physical job';
      default:
        return '';
    }
  }

  /// Show profession selection dialog
  void _showProfessionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? kDarkSurfaceLight : Colors.white,
        title: Text(
          'Select Profession',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? kDarkTextPrimary : kTextDark,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _professionOptions.length,
            itemBuilder: (context, index) {
              final profession = _professionOptions[index];
              return ListTile(
                title: Text(
                  profession,
                  style: GoogleFonts.poppins(
                    color: isDark ? kDarkTextPrimary : kTextDark,
                  ),
                ),
                selected: _selectedProfession == profession,
                selectedTileColor: isDark 
                    ? kDarkSurfaceDark.withOpacity(0.5) 
                    : kAccentBlue.withOpacity(0.1),
                onTap: () {
                  setState(() {
                    _selectedProfession = profession;
                    if (profession == 'Other') {
                      _professionController.clear();
                    } else {
                      _professionController.text = profession;
                    }
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: isDark ? kDarkTextSecondary : kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show hobbies selection dialog
  void _showHobbiesDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? kDarkSurfaceLight : Colors.white,
          title: Text(
            'Select Hobbies & Interests',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDark ? kDarkTextPrimary : kTextDark,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _hobbiesOptions.length,
                    itemBuilder: (context, index) {
                      final hobby = _hobbiesOptions[index];
                      final isSelected = _selectedHobbies.contains(hobby);
                      return CheckboxListTile(
                        title: Text(
                          hobby,
                          style: GoogleFonts.poppins(
                            color: isDark ? kDarkTextPrimary : kTextDark,
                          ),
                        ),
                        value: isSelected,
                        activeColor: kAccentBlue,
                        checkColor: Colors.white,
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              _selectedHobbies.add(hobby);
                            } else {
                              _selectedHobbies.remove(hobby);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (_selectedHobbies.contains('Other')) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hobbiesController,
                    style: GoogleFonts.poppins(
                      color: isDark ? kDarkTextPrimary : kTextDark,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Enter custom hobbies',
                      hintText: 'e.g., Rock climbing, Chess, etc.',
                      labelStyle: GoogleFonts.poppins(
                        color: isDark ? kDarkTextSecondary : kTextSecondary,
                      ),
                      hintStyle: GoogleFonts.poppins(
                        color: isDark ? kDarkTextTertiary : kTextTertiary,
                      ),
                      filled: true,
                      fillColor: isDark ? kDarkSurfaceDark : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark 
                              ? kDarkBorderColor.withOpacity(0.5) 
                              : kTextSecondary.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark 
                              ? kDarkBorderColor.withOpacity(0.5) 
                              : kTextSecondary.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: kAccentBlue, 
                          width: 2,
                        ),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // Update hobbies text field with selected hobbies
                  final selectedHobbies =
                      _selectedHobbies.where((h) => h != 'Other').toList();
                  if (_hobbiesController.text.isNotEmpty) {
                    selectedHobbies.add(_hobbiesController.text.trim());
                  }
                  _hobbiesController.text = selectedHobbies.join(', ');
                });
                Navigator.pop(context);
              },
              child: Text(
                'Done',
                style: GoogleFonts.poppins(
                  color: kAccentBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? kDarkAppBackground : kAppBackground,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? kDarkTextPrimary : kTextDark,
          ),
        ),
        backgroundColor: isDark ? kDarkSurfaceLight : kSurfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? kDarkTextPrimary : kTextDark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? kDarkTextPrimary : kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: kAccentBlue,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo Section
                    _buildProfilePhotoSection(),
                    const SizedBox(height: 24),

                    // Personal Information
                    _buildSectionCard(
                      title: 'Personal Information',
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          icon: Icons.person,
                          validator: (value) {
                            if (value != null &&
                                value.trim().isNotEmpty &&
                                value.trim().length < 2) {
                              return 'Name must be at least 2 characters if provided';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                          enabled: false, // Email is read-only
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _ageController,
                          label: 'Age',
                          icon: Icons.cake,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final age = int.tryParse(value);
                              if (age == null || age < 1 || age > 120) {
                                return 'Please enter a valid age';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          value: _selectedGender,
                          label: 'Gender',
                          icon: Icons.wc,
                          items: _genderOptions,
                          onChanged: (value) =>
                              setState(() => _selectedGender = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Physical Information
                    _buildSectionCard(
                      title: 'Physical Information',
                      children: [
                        _buildTextField(
                          controller: _heightController,
                          label: 'Height (cm)',
                          icon: Icons.height,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final height = double.tryParse(value);
                              if (height == null ||
                                  height < 50 ||
                                  height > 300) {
                                return 'Please enter a valid height';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _weightController,
                          label: 'Weight (kg)',
                          icon: Icons.monitor_weight,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final weight = double.tryParse(value);
                              if (weight == null ||
                                  weight < 20 ||
                                  weight > 300) {
                                return 'Please enter a valid weight';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Fitness & Lifestyle
                    _buildSectionCard(
                      title: 'Fitness & Lifestyle',
                      children: [
                        _buildDropdown(
                          value: _selectedActivityLevel,
                          label: 'Activity Level',
                          icon: Icons.fitness_center,
                          items: _activityLevels,
                          onChanged: (value) =>
                              setState(() => _selectedActivityLevel = value),
                        ),
                        if (_selectedActivityLevel != null) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              return Text(
                                _getActivityLevelDescription(
                                    _selectedActivityLevel!),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark ? kDarkTextSecondary : kTextSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildDropdown(
                          value: _selectedFitnessGoal,
                          label: 'Fitness Goal',
                          icon: Icons.flag,
                          items: _fitnessGoals,
                          onChanged: (value) =>
                              setState(() => _selectedFitnessGoal = value),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown(
                          value: _selectedDietPreference,
                          label: 'Diet Preference',
                          icon: Icons.restaurant,
                          items: _dietPreferences,
                          onChanged: (value) =>
                              setState(() => _selectedDietPreference = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Personal Details
                    _buildSectionCard(
                      title: 'Personal Details',
                      children: [
                        // Profession
                        _buildSelectionField(
                          label: 'Profession',
                          icon: Icons.work,
                          value: _selectedProfession ?? 'Select profession',
                          onTap: _showProfessionDialog,
                        ),
                        const SizedBox(height: 16),

                        // Hobbies & Interests
                        _buildSelectionField(
                          label: 'Hobbies & Interests',
                          icon: Icons.favorite,
                          value: _selectedHobbies.isNotEmpty
                              ? '${_selectedHobbies.length} selected'
                              : 'Select hobbies',
                          onTap: _showHobbiesDialog,
                        ),
                        const SizedBox(height: 16),

                        // Bio
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio',
                          icon: Icons.description,
                          maxLines: 3,
                          hintText: 'Tell us about yourself...',
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  /// Build profile photo section
  Widget _buildProfilePhotoSection() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: kAccentBlue.withOpacity(0.1),
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null
                ? const Icon(
                    Icons.person,
                    size: 60,
                    color: kAccentBlue,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// Build section card
  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      color: isDark ? kDarkSurfaceLight : kSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? kDarkTextPrimary : kTextDark,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Build text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      style: GoogleFonts.poppins(
        color: isDark ? kDarkTextPrimary : kTextDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: GoogleFonts.poppins(
          color: isDark ? kDarkTextSecondary : kTextSecondary,
        ),
        hintStyle: GoogleFonts.poppins(
          color: isDark ? kDarkTextTertiary : kTextTertiary,
        ),
        prefixIcon: Icon(icon, color: kAccentBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark 
                ? kDarkBorderColor.withOpacity(0.5) 
                : kTextSecondary.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark 
                ? kDarkBorderColor.withOpacity(0.5) 
                : kTextSecondary.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccentBlue, width: 2),
        ),
        filled: true,
        fillColor: enabled 
            ? (isDark ? kDarkSurfaceDark : Colors.white)
            : (isDark ? kDarkSurfaceDark.withOpacity(0.5) : kTextSecondary.withOpacity(0.1)),
      ),
    );
  }

  /// Build dropdown field
  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: isDark ? kDarkSurfaceLight : Colors.white,
      style: GoogleFonts.poppins(
        color: isDark ? kDarkTextPrimary : kTextDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: isDark ? kDarkTextSecondary : kTextSecondary,
        ),
        prefixIcon: Icon(icon, color: kAccentBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark 
                ? kDarkBorderColor.withOpacity(0.5) 
                : kTextSecondary.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark 
                ? kDarkBorderColor.withOpacity(0.5) 
                : kTextSecondary.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccentBlue, width: 2),
        ),
        filled: true,
        fillColor: isDark ? kDarkSurfaceDark : Colors.white,
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.poppins(
              color: isDark ? kDarkTextPrimary : kTextDark,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// Build selection field (for profession and hobbies)
  Widget _buildSelectionField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark 
                ? kDarkBorderColor.withOpacity(0.5) 
                : kTextSecondary.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDark ? kDarkSurfaceDark : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kAccentBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? kDarkTextPrimary : kTextDark,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

