import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:health/health.dart';
import '../ui/app_colors.dart';
import '../services/app_state_service.dart';
import '../services/demo_auth_service.dart';
import '../services/real_time_input_service.dart';
import '../services/health_data_service.dart';
import '../services/calorie_units_service.dart';

import '../models/user_preferences.dart';
import '../widgets/health_integration_widget.dart';
import '../widgets/health_integration_dialog.dart';
import 'profile_edit_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'goals_screen.dart';
import 'weight_log_screen.dart';

/// Professional Settings Screen for Calorie Vita App
/// Features: Profile section, settings toggles, navigation options, and logout
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppStateService _appStateService = AppStateService();
  final DemoAuthService _demoAuth = DemoAuthService();
  final RealTimeInputService _realTimeInputService = RealTimeInputService();
  final HealthDataService _healthDataService = HealthDataService();
  
  // User data
  User? _user;
  DemoUser? _demoUser;
  String? _userName;
  String? _userEmail;
  String? _profileImageUrl;
  UserPreferences _userPreferences = const UserPreferences();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupStreamListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user data when screen becomes visible
    _loadUserData();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh user data when widget is updated
    _loadUserData();
  }

  void _setupStreamListeners() {
    // Listen to Firebase user stream
    _appStateService.userStream.listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          if (user != null) {
            _loadUserProfileData(user);
          }
        });
      }
    });

    // Listen to Firebase Auth state changes directly
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          if (user != null) {
            _loadUserProfileData(user);
          }
        });
        print('Firebase Auth state changed - User: ${user?.displayName}');
      }
    });

    // Listen to demo user stream
    _demoAuth.userStream.listen((demoUser) {
      if (mounted) {
        setState(() {
          _demoUser = demoUser;
          if (demoUser != null) {
            _userName = demoUser.displayName ?? 'Demo User';
            _userEmail = demoUser.email;
          }
        });
      }
    });

    // Listen to preferences stream
    _appStateService.preferencesStream.listen((preferences) {
      if (mounted) {
        setState(() {
          _userPreferences = preferences;
        });
      }
    });
  }

  /// Load current user data from Firebase Auth and Firestore
  Future<void> _loadUserData() async {
    _user = _appStateService.currentUser;
    _demoUser = _demoAuth.currentUser;
    
    if (_user != null) {
      _loadUserProfileData(_user!);
    } else if (_demoUser != null) {
      _userName = _demoUser!.displayName ?? 'Demo User';
      _userEmail = _demoUser!.email;
    }
  }

  /// Load user profile data
  Future<void> _loadUserProfileData(User user) async {
    try {
      // Load from Firestore first, fallback to Auth data
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (mounted) {
        setState(() {
          if (doc.exists) {
            final data = doc.data()!;
            // Use Firestore name if available, otherwise use Auth displayName
            final firestoreName = data['name']?.toString();
            final authName = user.displayName;
            
            _userName = firestoreName?.isNotEmpty == true 
                ? firestoreName 
                : authName?.isNotEmpty == true 
                    ? authName 
                    : 'User';
            
            // Debug print to help troubleshoot
            print('Settings Screen - Firestore name: $firestoreName, Auth name: $authName, Final name: $_userName');
            _userEmail = user.email ?? 'user@example.com';
            _profileImageUrl = data['profileImageUrl'];
          } else {
            // Fallback to Auth data
            _userName = user.displayName?.isNotEmpty == true ? user.displayName : 'User';
            _userEmail = user.email ?? 'user@example.com';
            print('Settings Screen - No Firestore data, using Auth name: ${user.displayName}');
          }
        });
      }
    } catch (e) {
      // Fallback to Auth data on error
      if (mounted) {
        setState(() {
          _userName = user.displayName?.isNotEmpty == true ? user.displayName : 'User';
          _userEmail = user.email ?? 'user@example.com';
        });
        print('Settings Screen - Error loading profile, using Auth name: ${user.displayName}');
      }
    }
  }

  /// Handle notification toggle
  void _onNotificationToggle(bool value) async {
    try {
      final updatedPreferences = _userPreferences.copyWith(
        notificationsEnabled: value,
        lastUpdated: DateTime.now(),
      );
      await _appStateService.updateUserPreferences(updatedPreferences);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating notification settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle dark mode toggle
  void _onDarkModeToggle(bool value) async {
    try {
      final updatedPreferences = _userPreferences.copyWith(
        darkModeEnabled: value,
        lastUpdated: DateTime.now(),
      );
      await _appStateService.updateUserPreferences(updatedPreferences);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating dark mode settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Navigate to Privacy Policy
  void _navigateToPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(),
      ),
    );
  }

  /// Navigate to Terms & Conditions
  void _navigateToTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsConditionsScreen(),
      ),
    );
  }

  /// Share app functionality
  void _shareApp() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality will be implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Rate app functionality
  void _rateApp() {
    // TODO: Implement rate app functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rate app functionality will be implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Contact us functionality
  void _contactUs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.contact_support, color: kAccentGreen),
            const SizedBox(width: 12),
            Text(
              'Contact Us',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We\'d love to hear from you! Get in touch with us:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 20),
            
            // Email
            _buildContactOption(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'support@calorievita.com',
              onTap: () {
                // TODO: Implement email functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email functionality will be implemented'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Phone
            _buildContactOption(
              icon: Icons.phone_outlined,
              title: 'Phone',
              subtitle: '+1 (555) 123-4567',
              onTap: () {
                // TODO: Implement phone functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Phone functionality will be implemented'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Business Hours
            _buildContactOption(
              icon: Icons.access_time_outlined,
              title: 'Business Hours',
              subtitle: 'Mon-Fri: 9:00 AM - 6:00 PM\nSat: 10:00 AM - 4:00 PM',
              onTap: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: kTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Build contact option widget
  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kAccentGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kAccentGreen.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kAccentGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: kTextDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: kTextSecondary,
              ),
          ],
        ),
      ),
    );
  }

  /// Handle logout
  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: kErrorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // Try Firebase logout first
        if (_user != null) {
          await FirebaseAuth.instance.signOut();
        }
        
        // Also try demo logout
        if (_demoUser != null) {
          await _demoAuth.signOut();
        }
        
        if (mounted) {
          // Navigate to welcome screen
          Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: kErrorColor,
            ),
          );
        }
      }
    }
  }

  /// Edit profile functionality
  void _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileEditScreen(),
      ),
    );
    
    // Reload user data if profile was updated
    if (result == true) {
      print('Profile edit completed, refreshing user data...');
      
      // Add a small delay to ensure Firebase Auth update has propagated
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force refresh the current user from Firebase Auth
      _user = FirebaseAuth.instance.currentUser;
      print('Current user after edit: ${_user?.displayName}');
      
      await _loadUserData();
      // Also reload profile data specifically for Firebase users
      if (_user != null) {
        await _loadUserProfileData(_user!);
      }
      // Force a rebuild to ensure UI updates
      if (mounted) {
        setState(() {});
      }
      
      // Additional refresh after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _user = FirebaseAuth.instance.currentUser;
          });
        }
      });
    }
  }

  /// Navigate to goals screen
  Future<void> _navigateToGoals() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GoalsScreen(),
      ),
    );
    
    if (result == true) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'calorie_logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 12),
            Text(
              'Settings',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ],
        ),
        backgroundColor: kSurfaceColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileCard(),
            const SizedBox(height: 16),

            // Google Health Connection Section
            _buildGoogleHealthCard(),
            const SizedBox(height: 16),

            // Goals & Targets Section
            _buildGoalsCard(),
            const SizedBox(height: 16),

            // Calorie Units Section
            _buildCalorieUnitsCard(),
            const SizedBox(height: 24),

            // Settings Options
            _buildSettingsCard(),
            const SizedBox(height: 24),

            // Logout Section
            _buildLogoutCard(),
          ],
        ),
      ),
    );
  }

  /// Build Google Health Connection card
  Widget _buildGoogleHealthCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _showHealthIntegrationDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Google Fit Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    child: Image.asset(
                      'google-fit-png-logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Google Health',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'to track your steps',
                      style: GoogleFonts.poppins(
                        color: kTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: kTextSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Goals & Targets card
  Widget _buildGoalsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToGoals(),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag_circle_outlined,
                  color: kPrimaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goals & Targets',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set your health goals and targets',
                      style: GoogleFonts.poppins(
                        color: kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: kPrimaryColor,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build Calorie Units card
  Widget _buildCalorieUnitsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _showCalorieUnitsDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.straighten_outlined,
                  color: kAccentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calorie Units',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose your preferred calorie unit',
                      style: GoogleFonts.poppins(
                        color: kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: kAccentColor,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show calorie units selection dialog
  void _showCalorieUnitsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Get current unit from CalorieUnitsService (should be up-to-date)
        final CalorieUnitsService calorieUnitsService = CalorieUnitsService();
        String selectedUnit = calorieUnitsService.unitSuffix;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 20,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.white.withValues(alpha: 0.95)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    // Header with icon and title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kAccentColor, kAccentColor.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kAccentColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.straighten, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Select Calorie Unit',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Description
                    Text(
                      'Choose your preferred unit for displaying calories throughout the app',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Unit options
                    _buildEnhancedUnitOption('kcal', 'Kilocalories', 'kcal', 'Most common unit', selectedUnit, () {
                      setState(() => selectedUnit = 'kcal');
                    }),
                    const SizedBox(height: 16),
                    _buildEnhancedUnitOption('cal', 'Calories', 'cal', 'Small calorie unit', selectedUnit, () {
                      setState(() => selectedUnit = 'cal');
                    }),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: kTextSecondary.withValues(alpha: 0.3)),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: kTextSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _saveCalorieUnit(selectedUnit);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kAccentColor,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: kAccentColor.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Save Unit',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  /// Build enhanced unit option for dialog
  Widget _buildEnhancedUnitOption(String value, String label, String unit, String description, String selectedUnit, VoidCallback onTap) {
    final isSelected = selectedUnit == value;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? LinearGradient(
                  colors: [kAccentColor.withValues(alpha: 0.1), kAccentColor.withValues(alpha: 0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.white.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? kAccentColor
                : kTextSecondary.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: kAccentColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Radio button with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kAccentColor : kTextSecondary.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? kAccentColor : Colors.transparent,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: kAccentColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? kAccentColor : kTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: isSelected 
                              ? LinearGradient(
                                  colors: [kAccentColor, kAccentColor.withValues(alpha: 0.8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [kTextSecondary.withValues(alpha: 0.1), kTextSecondary.withValues(alpha: 0.05)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: kAccentColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ] : null,
                        ),
                        child: Text(
                          unit,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isSelected ? kAccentColor.withValues(alpha: 0.8) : kTextSecondary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Selection indicator
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kAccentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kAccentColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Save calorie unit preference
  void _saveCalorieUnit(String unit) async {
    try {
      final calorieUnit = CalorieUnit.values.firstWhere(
        (u) => u.name == unit,
        orElse: () => CalorieUnit.kcal,
      );
      
      final updatedPreferences = _userPreferences.copyWith(
        calorieUnit: calorieUnit,
        lastUpdated: DateTime.now(),
      );
      
      await _appStateService.updateUserPreferences(updatedPreferences);
      
      // Update the global calorie units service
      final calorieUnitsService = CalorieUnitsService();
      calorieUnitsService.updateUnit(calorieUnit);
      
      // Update local preferences
      setState(() {
        _userPreferences = updatedPreferences;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Calorie unit set to $unit'),
              ],
            ),
            backgroundColor: kAccentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating calorie unit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build profile card with user info and edit button
  Widget _buildProfileCard() {
    // Get the current user directly from Firebase Auth for real-time updates
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = currentUser?.displayName;
    
    // Debug print to see what we're getting
    print('Profile Card - Current user displayName: $displayName, _userName: $_userName');
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: kPrimaryColor,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _profileImageUrl == null
                  ? Text(
                      (displayName?.isNotEmpty == true ? displayName! : _userName?.isNotEmpty == true ? _userName! : 'U').substring(0, 1).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName?.isNotEmpty == true ? displayName! : (_userName?.isNotEmpty == true ? _userName! : 'User'),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? _userEmail ?? 'user@example.com',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Edit Button
            IconButton(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit, color: kAccentBlue),
              tooltip: 'Edit Profile',
            ),
          ],
        ),
      ),
    );
  }

  /// Build settings options card
  Widget _buildSettingsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Notifications
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: kAccentBlue, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'Receive app notifications',
                        style: GoogleFonts.poppins(
                          color: kTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _userPreferences.notificationsEnabled,
                  onChanged: _onNotificationToggle,
                  activeColor: kAccentBlue,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Dark Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.dark_mode_outlined, color: kAccentPurple, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'Switch to dark theme',
                        style: GoogleFonts.poppins(
                          color: kTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _userPreferences.darkModeEnabled,
                  onChanged: _onDarkModeToggle,
                  activeColor: kAccentPurple,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Weight Log
          ListTile(
            leading: const Icon(Icons.monitor_weight, color: kAccentGreen),
            title: Text(
              'Weight Log',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Track your weight history',
              style: GoogleFonts.poppins(
                color: kTextSecondary,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WeightLogScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),

          // Privacy Policy
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: kAccentGreen),
            title: Text(
              'Privacy Policy',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            onTap: _navigateToPrivacyPolicy,
          ),
          const Divider(height: 1),

          // Terms & Conditions
          ListTile(
            leading: const Icon(Icons.description_outlined, color: kAccentGold),
            title: Text(
              'Terms & Conditions',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            onTap: _navigateToTerms,
          ),
          const Divider(height: 1),

          // Share App
          ListTile(
            leading: const Icon(Icons.share_outlined, color: kAccentBlue),
            title: Text(
              'Share App',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            onTap: _shareApp,
          ),
          const Divider(height: 1),

          // Rate Us
          ListTile(
            leading: const Icon(Icons.star_outline, color: kAccentGold),
            title: Text(
              'Rate Us',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            onTap: _rateApp,
          ),
          const Divider(height: 1),

          // Contact Us
          ListTile(
            leading: const Icon(Icons.contact_support_outlined, color: kAccentGreen),
            title: Text(
              'Contact Us',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            onTap: _contactUs,
          ),
        ],
      ),
    );
  }

  /// Build logout card with red styling
  Widget _buildLogoutCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.logout, color: kErrorColor),
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: kErrorColor,
          ),
        ),
        onTap: _logout,
      ),
    );
  }

  /// Show health integration dialog
  void _showHealthIntegrationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HealthIntegrationDialog(
        healthDataService: _healthDataService,
      ),
    );
  }
}
