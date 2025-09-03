import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:health/health.dart';
import '../ui/app_colors.dart';
import '../services/app_state_service.dart';
import '../services/bluetooth_device_service.dart';

import '../models/user_preferences.dart';
import '../widgets/health_integration_widget.dart';
import 'profile_edit_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'goals_screen.dart';

/// Professional Settings Screen for Calorie Vita App
/// Features: Profile section, settings toggles, navigation options, and logout
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppStateService _appStateService = AppStateService();
  
  // User data
  User? _user;
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

  void _setupStreamListeners() {
    // Listen to user stream
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
    if (_user != null) {
      _loadUserProfileData(_user!);
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
      
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _userName = data['name'] ?? user.displayName ?? 'User';
            _userEmail = user.email ?? 'user@example.com';
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      } else {
        // Fallback to Auth data
        if (mounted) {
          setState(() {
            _userName = user.displayName ?? 'User';
            _userEmail = user.email ?? 'user@example.com';
          });
        }
      }
    } catch (e) {
      // Fallback to Auth data on error
      if (mounted) {
        setState(() {
          _userName = user.displayName ?? 'User';
          _userEmail = user.email ?? 'user@example.com';
        });
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
        await FirebaseAuth.instance.signOut();
        if (mounted) {
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
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        backgroundColor: kSurfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
                            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
            // Profile Section
            _buildProfileCard(),
            const SizedBox(height: 24),

            // Goals & Targets Section
            _buildGoalsCard(),
            const SizedBox(height: 16),

            // Device Connection Section
            _buildDeviceConnectionCard(),
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

  /// Build Device Connection card
  Widget _buildDeviceConnectionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _showDeviceConnectionDialog,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAccentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bluetooth_connected,
                  color: kAccentBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to Device',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect smartwatch or health apps',
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
                  color: kAccentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: kAccentBlue,
                  size: 16,
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
    String selectedUnit = 'kcal'; // Default selection
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kAccentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.straighten, color: kAccentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Calorie Unit',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Choose your preferred unit for displaying calories throughout the app',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildEnhancedUnitOption('kcal', 'Kilocalories', 'kcal', 'Most common unit', selectedUnit, () {
                      setState(() => selectedUnit = 'kcal');
                    }),
                    const SizedBox(height: 8),
                    _buildEnhancedUnitOption('cal', 'Calories', 'cal', 'Small calorie unit', selectedUnit, () {
                      setState(() => selectedUnit = 'cal');
                    }),
                    const SizedBox(height: 8),
                    _buildEnhancedUnitOption('J', 'Joules', 'J', 'SI energy unit', selectedUnit, () {
                      setState(() => selectedUnit = 'J');
                    }),
                    const SizedBox(height: 8),
                    _buildEnhancedUnitOption('kJ', 'Kilojoules', 'kJ', 'Large energy unit', selectedUnit, () {
                      setState(() => selectedUnit = 'kJ');
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _saveCalorieUnit(selectedUnit);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Save Unit',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? kAccentColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? kAccentColor
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? kAccentColor : kTextSecondary,
                  width: 2,
                ),
                color: isSelected ? kAccentColor : Colors.transparent,
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
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? kAccentColor : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? kAccentColor.withValues(alpha: 0.2)
                              : kTextSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          unit,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? kAccentColor : kTextSecondary,
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
                      color: kTextSecondary,
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
                      _userName?.isNotEmpty == true ? _userName!.substring(0, 1).toUpperCase() : 'U',
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
                    _userName ?? 'User',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail ?? 'user@example.com',
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

  /// Show device connection dialog
  void _showDeviceConnectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeviceConnectionBottomSheet(),
    );
  }
}

/// Device Connection Bottom Sheet
class DeviceConnectionBottomSheet extends StatefulWidget {
  const DeviceConnectionBottomSheet({super.key});

  @override
  State<DeviceConnectionBottomSheet> createState() => _DeviceConnectionBottomSheetState();
}

class _DeviceConnectionBottomSheetState extends State<DeviceConnectionBottomSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final BluetoothDeviceService _bluetoothService = BluetoothDeviceService();

  List<BluetoothDevice> _availableDevices = [];
  List<BluetoothDevice> _connectedDevices = [];
  bool _isScanning = false;
  String _connectionStatus = 'Ready to connect';
  bool _isHealthConnected = false;
  String _healthStatus = 'Not connected';
  Map<String, dynamic> _latestDeviceData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupListeners();
    _initializeHealthService();
  }

  void _setupListeners() {
    _bluetoothService.isScanningStream.listen((isScanning) {
      if (mounted) {
        setState(() {
          _isScanning = isScanning;
        });
      }
    });

    _bluetoothService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    });

    _bluetoothService.connectedDevicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _connectedDevices = devices;
        });
      }
    });

    // Listen to real-time device data
    _bluetoothService.deviceDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _latestDeviceData[data['dataType']] = data['value'];
        });
      }
    });



    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _availableDevices = results
              .map((result) => result.device)
              .where((device) => _bluetoothService.isFitnessDevice(
                  device.platformName.isNotEmpty 
                      ? device.platformName 
                      : device.remoteId.toString()))
              .toList();
        });
      }
    });
  }

  Future<void> _initializeHealthService() async {
    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ];

      final permissions = await Health().hasPermissions(types);
      if (mounted) {
        setState(() {
          _isHealthConnected = permissions ?? false;
        });
      }
    } catch (e) {
      print('Error initializing health service: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kTextSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bluetooth_connected,
                    color: kAccentBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Connect to Device',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: kTextSecondary),
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: kAccentBlue,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kAccentBlue,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(
                icon: Icon(Icons.bluetooth, size: 20),
                text: 'Bluetooth',
              ),
              Tab(
                icon: Icon(Icons.favorite, size: 20),
                text: 'Health Apps',
              ),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBluetoothTab(),
                _buildHealthTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor().withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _connectionStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Connected Devices
          if (_connectedDevices.isNotEmpty) ...[
            Text(
              'Connected Devices',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            ..._connectedDevices.map((device) => _buildConnectedDeviceCard(device)),
            const SizedBox(height: 20),

            // Real-time Data Display
            _buildRealTimeDataSection(),
            const SizedBox(height: 20),
          ],

          // Available Devices
          Text(
            'Available Devices',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),

          if (_availableDevices.isEmpty && !_isScanning)
            _buildNoDevicesState()
          else
            ..._availableDevices.map((device) => _buildAvailableDeviceCard(device)),

          const SizedBox(height: 20),

          // Scan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScanning,
              icon: _isScanning 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search, size: 20),
              label: Text(
                _isScanning ? 'Scanning...' : 'Scan for Devices',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isHealthConnected 
                  ? kAccentGreen.withOpacity(0.1)
                  : kTextSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHealthConnected 
                    ? kAccentGreen.withOpacity(0.3)
                    : kTextSecondary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isHealthConnected ? Icons.check_circle : Icons.health_and_safety,
                  color: _isHealthConnected ? kAccentGreen : kTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isHealthConnected 
                            ? 'Health apps connected'
                            : 'Health apps not connected',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _isHealthConnected ? kAccentGreen : kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_healthStatus.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _healthStatus,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_isHealthConnected)
                  ElevatedButton(
                    onPressed: _connectToHealthApps,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: Text(
                      'Connect',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),



          // Health Integration Widget (fallback)
          const HealthIntegrationWidget(),
        ],
      ),
    );
  }

  Widget _buildNoDevicesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: kTextSecondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.devices_other_outlined,
            size: 48,
            color: kTextSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No devices found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your device is nearby and in pairing mode',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kTextSecondary.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceCard(BluetoothDevice device) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';
    final deviceIcon = _bluetoothService.getDeviceIcon(deviceName);
    final deviceColor = _bluetoothService.getDeviceColor(deviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: deviceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: deviceColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(deviceIcon, color: deviceColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              deviceName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextDark,
              ),
            ),
          ),
          Icon(
            Icons.check_circle,
            color: kAccentGreen,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeviceCard(BluetoothDevice device) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';
    final deviceIcon = _bluetoothService.getDeviceIcon(deviceName);
    final deviceColor = _bluetoothService.getDeviceColor(deviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kTextSecondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(deviceIcon, color: deviceColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              deviceName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextDark,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _connectToDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: deviceColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: Text(
              'Connect',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_connectionStatus.contains('Connected')) {
      return kAccentGreen;
    } else if (_connectionStatus.contains('Scanning')) {
      return kAccentBlue;
    } else if (_connectionStatus.contains('Error')) {
      return kErrorColor;
    } else {
      return kTextSecondary;
    }
  }

  IconData _getStatusIcon() {
    if (_connectionStatus.contains('Connected')) {
      return Icons.check_circle;
    } else if (_connectionStatus.contains('Scanning')) {
      return Icons.search;
    } else if (_connectionStatus.contains('Error')) {
      return Icons.error;
    } else {
      return Icons.bluetooth;
    }
  }

  void _startScanning() {
    _bluetoothService.startScanning();
  }

  void _connectToDevice(BluetoothDevice device) async {
    final success = await _bluetoothService.connectToDevice(device);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.platformName}'),
          backgroundColor: kAccentGreen,
        ),
      );
    }
  }

  void _connectToHealthApps() async {
    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_DELTA,
      ];

      final requested = await Health().requestAuthorization(types);
      if (mounted) {
        setState(() {
          _isHealthConnected = requested ?? false;
          _healthStatus = requested == true ? 'Connected' : 'Permission denied';
        });
        
        if (requested == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to health apps successfully!'),
              backgroundColor: kAccentGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Health permissions denied'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to health apps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }





  Widget _buildHealthDataChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: kTextSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeDataSection() {
    if (_latestDeviceData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kTextSecondary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.sync,
              color: kTextSecondary.withOpacity(0.5),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for device data...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccentGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync,
                color: kAccentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Real-time Data',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LIVE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: kAccentGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _buildDataChips(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDataChips() {
    final chips = <Widget>[];

    if (_latestDeviceData.containsKey('heartRate')) {
      chips.add(_buildDataChip(
        'Heart Rate',
        '${_latestDeviceData['heartRate']} bpm',
        Icons.favorite,
        Colors.red,
      ));
    }

    if (_latestDeviceData.containsKey('steps')) {
      chips.add(_buildDataChip(
        'Steps',
        '${_latestDeviceData['steps']}',
        Icons.directions_walk,
        kAccentBlue,
      ));
    }

    if (_latestDeviceData.containsKey('calories')) {
      chips.add(_buildDataChip(
        'Calories',
        '${_latestDeviceData['calories']}',
        Icons.local_fire_department,
        Colors.orange,
      ));
    }

    if (_latestDeviceData.containsKey('distance')) {
      chips.add(_buildDataChip(
        'Distance',
        '${_latestDeviceData['distance'].toStringAsFixed(1)} km',
        Icons.straighten,
        kAccentGreen,
      ));
    }

    if (_latestDeviceData.containsKey('batteryLevel')) {
      chips.add(_buildDataChip(
        'Battery',
        '${_latestDeviceData['batteryLevel']}%',
        Icons.battery_std,
        kAccentBlue,
      ));
    }

    if (_latestDeviceData.containsKey('bloodPressure')) {
      final bp = _latestDeviceData['bloodPressure'] as Map<String, int>;
      chips.add(_buildDataChip(
        'Blood Pressure',
        '${bp['systolic']}/${bp['diastolic']}',
        Icons.monitor_heart,
        Colors.red,
      ));
    }

    return chips;
  }

  Widget _buildDataChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: kTextSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 