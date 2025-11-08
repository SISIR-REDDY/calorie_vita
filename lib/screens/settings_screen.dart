import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/app_colors.dart';
import '../services/app_state_service.dart';
import '../services/real_time_input_service.dart';
import '../services/health_connect_manager.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../widgets/setup_warning_popup.dart';
import '../services/setup_check_service.dart';

import '../models/user_preferences.dart';
import 'profile_edit_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'goals_screen.dart';
import 'weight_log_screen.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Professional Settings Screen for Calorie Vita App
/// Features: Profile section, settings toggles, navigation options, and logout
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppStateService _appStateService = AppStateService();
  final RealTimeInputService _realTimeInputService = RealTimeInputService();
  final HealthConnectManager _healthConnectManager = HealthConnectManager();
  static final LoggerService _logger = LoggerService();

  // User data
  User? _user;
  String? _userName;
  String? _userEmail;
  String? _profileImageUrl;
  UserPreferences _userPreferences = const UserPreferences();

  // Stream subscriptions
  StreamSubscription<DocumentSnapshot>? _profileSubscription;
  StreamSubscription<User?>? _userSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<UserPreferences>? _preferencesSubscription;

  // Settings state variables

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

  // Removed didChangeDependencies and didUpdateWidget to prevent duplicate loads
  // Stream listeners handle real-time updates automatically

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
        if (kDebugMode) debugPrint('Firebase Auth state changed - User: ${user?.displayName}');
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

            _userEmail = user.email ?? 'user@example.com';
            _profileImageUrl = data['profileImageUrl'];
          } else {
            // Fallback to Auth data
            _userName = user.displayName?.isNotEmpty == true
                ? user.displayName
                : 'User';
            _userEmail = user.email ?? 'user@example.com';
          }
        });
      }
    } catch (e) {
      // Fallback to Auth data on error
      if (mounted) {
        setState(() {
          _userName =
              user.displayName?.isNotEmpty == true ? user.displayName : 'User';
          _userEmail = user.email ?? 'user@example.com';
        });
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
        });
      }
    }, onError: (error) {
      if (kDebugMode) debugPrint('Settings Screen - Error listening to profile data: $error');
    });
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contact Us',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For support and feedback, please contact us at:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchEmail(),
              onLongPress: () => _copyEmailToClipboard(),
              child: Row(
                children: [
                  const Icon(Icons.email, color: kPrimaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'calorievita@gmail.com',
                      style: GoogleFonts.poppins(
                        color: kPrimaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.content_copy,
                    size: 16,
                    color: kPrimaryColor.withOpacity(0.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to email • Long press to copy',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: kTextSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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

  /// Launch email app
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'calorievita@gmail.com',
      query: 'subject=Calorie Vita Support',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open email app. Please email us at: calorievita@gmail.com',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}\nPlease email: calorievita@gmail.com',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Copy email to clipboard
  Future<void> _copyEmailToClipboard() async {
    const email = 'calorievita@gmail.com';
    
    try {
      await Clipboard.setData(const ClipboardData(text: email));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Email copied to clipboard!',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            backgroundColor: kSuccessColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to copy email',
              style: GoogleFonts.poppins(),
            ),
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
            const Icon(Icons.contact_support, color: kAccentGreen),
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
              const Icon(
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
              style: GoogleFonts.poppins(
                  color: kErrorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Use AuthService for complete logout including Google Fit
        final authService = AuthService();
        await authService.signOut();

        if (mounted) {
          // Close loading dialog
          Navigator.pop(context);
          
          // Wait for auth state to be properly updated
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Force navigation to welcome screen with proper cleanup
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/welcome', (route) => false);
          }
        }
      } catch (e) {
        _logger.error('Logout error', {'error': e.toString()});
        if (mounted) {
          // Close loading dialog if still open
          Navigator.pop(context);
          
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
      if (kDebugMode) debugPrint('Profile edit completed, refreshing user data...');

      // Add a small delay to ensure Firebase Auth update has propagated
      await Future.delayed(const Duration(milliseconds: 500));

      // Force refresh the current user from Firebase Auth
      _user = FirebaseAuth.instance.currentUser;
      if (kDebugMode) debugPrint('Current user after edit: ${_user?.displayName}');

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
      // Goals were updated, trigger immediate refresh
      _loadUserData();
      
      // Small delay to ensure goals are fully processed
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Force refresh the app state to ensure home screen gets updated
      await _appStateService.refreshUserData();
      
      // Also trigger a global goals update to ensure all screens are notified
      final currentGoals = _appStateService.userGoals;
      if (currentGoals != null) {
        _appStateService.forceGoalsUpdate(currentGoals);
      }
      
      // Show success message to confirm goals were updated
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Goals updated successfully! 🎯'),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: MediaQuery.of(context).size.width < 360 ? 35 : 40,
              height: MediaQuery.of(context).size.width < 360 ? 35 : 40,
              constraints: const BoxConstraints(
                minWidth: 30,
                maxWidth: 50,
                minHeight: 30,
                maxHeight: 50,
              ),
              child: Image.asset(
                'calorie_logo.png',
                fit: BoxFit.cover,
              ),
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
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
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


            // Weight Log Section
            _buildUniformSettingsCard(
              icon: Icons.monitor_weight,
              title: 'Weight Log',
              subtitle: 'Track your weight history',
              color: kAccentGreen,
              onTap: _navigateToWeightLog,
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
          height: MediaQuery.of(context).size.width < 360 ? 70 : 80,
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 12 : 16),
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
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: kTextSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// Initialize Google Fit service (with persistence check)
  Future<void> _initializeGoogleFit() async {
    try {
      // Check if already connected without triggering re-authentication
      if (_healthConnectManager.isConnected) {
        setState(() {
          _isGoogleFitConnected = true;
          _lastGoogleFitSync = DateTime.now();
        });
        if (kDebugMode) debugPrint('Google Fit already connected, skipping initialization');
        return;
      }

      // Only initialize if not already connected
      await _healthConnectManager.initialize();
      setState(() {
        _isGoogleFitConnected = _healthConnectManager.isConnected;
        if (_isGoogleFitConnected) {
          _lastGoogleFitSync = DateTime.now();
        }
      });

      if (kDebugMode) debugPrint(
          'Google Fit initialization completed. Connected: $_isGoogleFitConnected');
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing Google Fit: $e');
      setState(() {
        _isGoogleFitConnected = false;
      });
    }
  }

  /// Refresh Google Fit connection status without re-authentication
  void _refreshGoogleFitStatus() {
    if (_healthConnectManager.isConnected) {
      setState(() {
        _isGoogleFitConnected = true;
        _lastGoogleFitSync = DateTime.now();
      });
    } else {
      setState(() {
        _isGoogleFitConnected = false;
      });
    }
  }

  /// Connect to Google Fit with improved user experience
  Future<void> _connectToGoogleFit() async {
    if (_isConnectingToGoogleFit) return;

    setState(() {
      _isConnectingToGoogleFit = true;
    });

    try {
      // Step 1: Check if Health Connect is available
      final isAvailable = _healthConnectManager.isAvailable;
      
      if (!isAvailable) {
        // Health Connect is not installed
        setState(() {
          _isConnectingToGoogleFit = false;
        });
        _showHealthConnectNotInstalledDialog();
        return;
      }

      // Step 2: Check if permissions are granted
      final success = await _healthConnectManager.requestPermissions();
      
      if (success) {
        // Permissions granted successfully
        setState(() {
          _isGoogleFitConnected = true;
          _lastGoogleFitSync = DateTime.now();
          _isConnectingToGoogleFit = false; // Stop the buffering indicator
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Successfully connected to Google Fit!'),
                  ),
                ],
              ),
              backgroundColor: kSuccessColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }

        _checkAndMarkSetupComplete();
      } else {
        // Permissions not granted - guide user to Health Connect settings
        setState(() {
          _isConnectingToGoogleFit = false;
        });
        _showPermissionInstructionsDialog();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error connecting to Google Fit: $e');
      setState(() {
        _isConnectingToGoogleFit = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Connection error. Please try again.'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Show dialog when Health Connect is not installed
  void _showHealthConnectNotInstalledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.health_and_safety, color: kPrimaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Health Connect Required',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To sync your fitness data, you need to install:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildRequirementItem('1. Health Connect by Google', true),
            const SizedBox(height: 8),
            _buildRequirementItem('2. Google Fit', true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kInfoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: kInfoColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Both apps are free from Play Store',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: kInfoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Later',
              style: GoogleFonts.poppins(color: kTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              // Open Health Connect settings (will redirect to Play Store)
              await _healthConnectManager.openHealthConnectSettings();
            },
            icon: const Icon(Icons.download),
            label: Text(
              'Install Now',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog with instructions to grant permissions
  void _showPermissionInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kWarningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_open, color: kWarningColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Grant Permissions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To sync your fitness data, please grant the following permissions:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildPermissionStep('1', 'Tap "Open Settings" button below'),
            const SizedBox(height: 8),
            _buildPermissionStep('2', 'Find "CalorieVita" in the list'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kWarningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kWarningColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: kWarningColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Samsung users: Search for "Health Connect" in Settings if not visible',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: kWarningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildPermissionStep('3', 'Enable these permissions:'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequirementItem('• Steps', false),
                  const SizedBox(height: 4),
                  _buildRequirementItem('• Active calories burned', false),
                  const SizedBox(height: 4),
                  _buildRequirementItem('• Total calories burned', false),
                  const SizedBox(height: 4),
                  _buildRequirementItem('• Exercise', false),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildPermissionStep('4', 'Return to CalorieVita'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSuccessColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: kSuccessColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your data is secure and private',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: kSuccessColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              // Open Health Connect settings
              final opened = await _healthConnectManager.openHealthConnectSettings();
              
              if (opened) {
                // Show a snackbar to remind user to come back
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Grant permissions and come back to CalorieVita',
                        style: GoogleFonts.poppins(),
                      ),
                      duration: const Duration(seconds: 5),
                      backgroundColor: kInfoColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      action: SnackBarAction(
                        label: 'OK',
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.settings),
            label: Text(
              'Open Settings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a requirement item widget
  Widget _buildRequirementItem(String text, bool showIcon) {
    return Row(
      children: [
        if (showIcon)
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.download, color: kPrimaryColor, size: 16),
          ),
        if (showIcon) const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build a permission step widget
  Widget _buildPermissionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Disconnect from Google Fit
  Future<void> _disconnectFromGoogleFit() async {
    try {
      await _healthConnectManager.signOut();
      setState(() {
        _isGoogleFitConnected = false;
        _lastGoogleFitSync = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from Google Fit'),
            backgroundColor: kInfoColor,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error disconnecting from Google Fit: $e');
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

  /// Build Google Health Connection card
  Widget _buildGoogleHealthCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _isGoogleFitConnected
            ? _disconnectFromGoogleFit
            : _connectToGoogleFit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
          child: Row(
            children: [
              // Google Fit Logo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isGoogleFitConnected
                      ? Colors.white
                      : Colors.grey[50],
                  boxShadow: [
                    BoxShadow(
                      color: _isGoogleFitConnected
                          ? kSuccessColor.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _isConnectingToGoogleFit
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(kPrimaryColor),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(2),
                          child: Image.asset(
                            'google-fit-png-logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback icon if image fails to load
                              return Icon(
                                Icons.favorite,
                                size: 36,
                                color: _isGoogleFitConnected 
                                    ? kSuccessColor 
                                    : Colors.grey[400],
                              );
                            },
                          ),
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
                        color: _isGoogleFitConnected
                            ? kSuccessColor
                            : kTextSecondary,
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
                  color:
                      _isGoogleFitConnected ? kSuccessColor : Colors.grey[400],
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
          padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
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

  /// Build profile card with user info and edit button
  Widget _buildProfileCard() {
    // Get the current user directly from Firebase Auth for real-time updates
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = currentUser?.displayName;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
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
                      (displayName?.isNotEmpty == true
                              ? displayName!
                              : _userName?.isNotEmpty == true
                                  ? _userName!
                                  : 'U')
                          .substring(0, 1)
                          .toUpperCase(),
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
                    displayName?.isNotEmpty == true
                        ? displayName!
                        : (_userName?.isNotEmpty == true ? _userName! : 'User'),
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
    _userSubscription?.cancel();
    _authStateSubscription?.cancel();
    _preferencesSubscription?.cancel();
    super.dispose();
  }
}

