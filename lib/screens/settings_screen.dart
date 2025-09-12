import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:health/health.dart';  // Temporarily disabled
import '../ui/app_colors.dart';
import '../services/app_state_service.dart';
import '../services/demo_auth_service.dart';
import '../services/firebase_service.dart';
import '../services/real_time_input_service.dart';
import '../services/calorie_units_service.dart';
import '../services/google_fit_service.dart';

import '../models/user_preferences.dart';
import '../models/user_goals.dart';
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
  final GoogleFitService _googleFitService = GoogleFitService();
  
  // User data
  User? _user;
  DemoUser? _demoUser;
  String? _userName;
  String? _userEmail;
  String? _profileImageUrl;
  UserPreferences _userPreferences = const UserPreferences();
  
  // Stream subscription for profile data
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  
  // Settings state variables
  bool _isDarkMode = false;
  
  // Google Fit state
  bool _isGoogleFitConnected = false;
  bool _isConnectingToGoogleFit = false;
  DateTime? _lastGoogleFitSync;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupStreamListeners();
    _initializeGoogleFit();
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
            _setupProfileDataListener(user.uid);
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
            _setupProfileDataListener(user.uid);
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
      // Load from the correct Firestore path: users/{userId}/profile/userData
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('userData')
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
            print('Settings Screen - No Firestore profile data, using Auth name: ${user.displayName}');
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

  /// Set up real-time listener for profile data changes
  void _setupProfileDataListener(String userId) {
    // Cancel existing subscription
    _profileSubscription?.cancel();
    
    // Set up new subscription to listen for profile data changes
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('userData')
        .snapshots()
        .listen((doc) {
      if (mounted && doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Update profile data in real-time
          final firestoreName = data['name']?.toString();
          final authName = _user?.displayName;
          
          _userName = firestoreName?.isNotEmpty == true 
              ? firestoreName 
              : authName?.isNotEmpty == true 
                  ? authName 
                  : 'User';
          
          _profileImageUrl = data['profileImageUrl'];
          
          print('Settings Screen - Profile data updated in real-time: $_userName');
        });
      }
    }, onError: (error) {
      print('Settings Screen - Error listening to profile data: $error');
    });
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

  /// Navigate to Contact Us
  void _navigateToContact() {
    // For now, show a simple dialog. You can replace this with a proper contact screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contact Us',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'For support and feedback, please contact us at:\n\nEmail: support@calorievita.com\nPhone: +1 (555) 123-4567',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Show calorie units selection dialog
  void _navigateToCalorieUnits() {
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
                          colors: [kAccentGold, kAccentGold.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kAccentGold.withValues(alpha: 0.3),
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
                              backgroundColor: kAccentGold,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: kAccentGold.withValues(alpha: 0.4),
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
                  colors: [kAccentGold.withValues(alpha: 0.1), kAccentGold.withValues(alpha: 0.05)],
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
                ? kAccentGold
                : kTextSecondary.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: kAccentGold.withValues(alpha: 0.2),
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
                  color: isSelected ? kAccentGold : kTextSecondary.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1.5,
                ),
                color: isSelected ? kAccentGold : Colors.transparent,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: kAccentGold.withValues(alpha: 0.3),
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
                            color: isSelected ? kAccentGold : kTextPrimary,
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
                                  colors: [kAccentGold, kAccentGold.withValues(alpha: 0.8)],
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
                              color: kAccentGold.withValues(alpha: 0.3),
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
                      color: isSelected ? kAccentGold.withValues(alpha: 0.8) : kTextSecondary,
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
                  color: kAccentGold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kAccentGold.withValues(alpha: 0.3),
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
            backgroundColor: kAccentGold,
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

  /// Navigate to Weight Log
  void _navigateToWeightLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WeightLogScreen(),
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
            const SizedBox(height: 12),

            const SizedBox(height: 12),

            // Goals & Targets Section
            _buildUniformSettingsCard(
              icon: Icons.flag,
              title: 'Goals & Targets',
              subtitle: 'Set your health goals and targets',
              color: kAccentPurple,
              onTap: _navigateToGoals,
            ),
            const SizedBox(height: 12),

            // Calorie Units Section
            _buildUniformSettingsCard(
              icon: Icons.scale,
              title: 'Calorie Units',
              subtitle: 'Choose your preferred calorie unit',
              color: kAccentGold,
              onTap: _navigateToCalorieUnits,
            ),
            const SizedBox(height: 12),

            // Weight Log Section
            _buildUniformSettingsCard(
              icon: Icons.monitor_weight,
              title: 'Weight Log',
              subtitle: 'Track your weight history',
              color: kAccentGreen,
              onTap: _navigateToWeightLog,
            ),
            const SizedBox(height: 12),

            // Dark Mode Section
            _buildUniformSettingsCard(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Switch to dark theme',
              color: kAccentPurple,
              onTap: () {},
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                },
                activeColor: kAccentPurple,
              ),
            ),
            const SizedBox(height: 12),

            // Privacy Policy Section
            _buildUniformSettingsCard(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              color: kAccentGreen,
              onTap: _navigateToPrivacyPolicy,
            ),
            const SizedBox(height: 12),

            // Terms & Conditions Section
            _buildUniformSettingsCard(
              icon: Icons.description,
              title: 'Terms & Conditions',
              subtitle: 'Read our terms and conditions',
              color: kAccentGold,
              onTap: _navigateToTerms,
            ),
            const SizedBox(height: 12),

            // Share App Section
            _buildUniformSettingsCard(
              icon: Icons.share,
              title: 'Share App',
              subtitle: 'Share this app with friends',
              color: kAccentBlue,
              onTap: _shareApp,
            ),
            const SizedBox(height: 12),

            // Rate Us Section
            _buildUniformSettingsCard(
              icon: Icons.star,
              title: 'Rate Us',
              subtitle: 'Rate our app on the store',
              color: kAccentGold,
              onTap: _rateApp,
            ),
            const SizedBox(height: 12),

            // Contact Us Section
            _buildUniformSettingsCard(
              icon: Icons.contact_support,
              title: 'Contact Us',
              subtitle: 'Get help and support',
              color: kAccentGreen,
              onTap: _navigateToContact,
            ),
            const SizedBox(height: 24),

            // Logout Section
            _buildLogoutCard(),
          ],
        ),
      ),
    );
  }


  Widget _buildUniformSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 80, // Fixed height for all cards
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              
              // Trailing Widget (Switch or Arrow)
              if (trailing != null)
                trailing
              else
                const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
            ],
          ),
        ),
      ),
    );
  }


  /// Initialize Google Fit service (with persistence check)
  Future<void> _initializeGoogleFit() async {
    try {
      await _googleFitService.initialize();
      final isAuthenticated = await _googleFitService.validateAuthentication();
      setState(() {
        _isGoogleFitConnected = isAuthenticated;
        if (_isGoogleFitConnected) {
          _lastGoogleFitSync = DateTime.now();
        }
      });
    } catch (e) {
      print('Error initializing Google Fit: $e');
    }
  }

  /// Connect to Google Fit
  Future<void> _connectToGoogleFit() async {
    if (_isConnectingToGoogleFit) return;

    setState(() {
      _isConnectingToGoogleFit = true;
    });

    try {
      final success = await _googleFitService.authenticate();
      if (success) {
        setState(() {
          _isGoogleFitConnected = true;
          _lastGoogleFitSync = DateTime.now();
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully connected to Google Fit!'),
              backgroundColor: kSuccessColor,
            ),
          );
        }
      } else {
        throw Exception('Authentication failed');
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
    } finally {
      setState(() {
        _isConnectingToGoogleFit = false;
      });
    }
  }

  /// Disconnect from Google Fit
  Future<void> _disconnectFromGoogleFit() async {
    try {
      await _googleFitService.signOut();
      setState(() {
        _isGoogleFitConnected = false;
        _lastGoogleFitSync = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from Google Fit'),
            backgroundColor: kInfoColor,
          ),
        );
      }
    } catch (e) {
      print('Error disconnecting from Google Fit: $e');
    }
  }

  /// Format last sync time
  String _formatLastSyncTime() {
    if (_lastGoogleFitSync == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(_lastGoogleFitSync!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Build Google Health Connection card
  Widget _buildGoogleHealthCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _isGoogleFitConnected ? _disconnectFromGoogleFit : _connectToGoogleFit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Health Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isGoogleFitConnected ? kSuccessColor.withValues(alpha: 0.1) : Colors.grey[100],
                  border: Border.all(
                    color: _isGoogleFitConnected ? kSuccessColor : Colors.grey[300]!, 
                    width: 1
                  ),
                ),
                child: Center(
                  child: _isConnectingToGoogleFit
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                          ),
                        )
                      : Image.asset(
                          'google-fit-png-logo.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Fit',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isGoogleFitConnected 
                          ? 'Connected - Last sync: ${_formatLastSyncTime()}'
                          : 'Connect to sync fitness data',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _isGoogleFitConnected ? kSuccessColor : kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Status indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isGoogleFitConnected ? kSuccessColor : Colors.grey[400],
                ),
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
        onTap: _navigateToCalorieUnits,
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


  /// Show health integration dialog (disabled - Google Fit removed)
  void _showHealthIntegrationDialog() {
    // Health integration disabled - Google Fit removed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health integration is currently disabled'),
        backgroundColor: Colors.orange,
      ),
    );
  }


  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}