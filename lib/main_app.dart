import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/trainer_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/reward_notification_widget.dart';
import 'widgets/setup_warning_popup.dart';
import 'ui/app_theme.dart';
import 'ui/responsive_utils.dart';
import 'services/app_state_manager.dart';
import 'services/global_google_fit_manager.dart';
import 'services/setup_check_service.dart';
import 'services/firebase_service.dart';
import 'services/daily_reset_service.dart';

class MainApp extends StatefulWidget {
  final bool firebaseInitialized;

  const MainApp({super.key, this.firebaseInitialized = false});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final AppStateManager _appStateManager = AppStateManager();
  final GlobalGoogleFitManager _googleFitManager = GlobalGoogleFitManager();
  bool _hasShownSetupWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Immediate initialization - no waiting
    _initializeAppImmediately();
  }

  void _initializeAppImmediately() {
    print('Starting immediate app initialization...');

    // Initialize app state manager in background (non-blocking)
    _initializeAppStateManager();

    // Initialize global Google Fit manager
    _initializeGoogleFitManager();
    
    // Initialize daily reset service
    DailyResetService.initialize();
    
    // Check and show setup warning if needed
    _checkAndShowSetupWarning();
  }

  Future<void> _checkAndShowSetupWarning() async {
    try {
      // Check if warning has been shown before
      final hasShownWarning = await SetupWarningService.hasShownWarning();
      if (hasShownWarning) return;

      // Check if setup is complete
      final isSetupComplete = await SetupCheckService.isSetupComplete();
      if (isSetupComplete) {
        // Mark warning as shown since setup is complete
        await SetupWarningService.markWarningAsShown();
        return;
      }

      // Show warning after a short delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted && !_hasShownSetupWarning) {
        setState(() {
          _hasShownSetupWarning = true;
        });
        
        _showSetupWarning();
      }
    } catch (e) {
      print('Error checking setup warning: $e');
    }
  }

  void _showSetupWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SetupWarningPopup(
        onComplete: () {
          // User chose "Maybe Later"
          print('User chose to complete setup later');
        },
        onNavigateToSettings: () {
          // Navigate to settings screen
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
        },
      ),
    );
  }

  void _initializeAppStateManager() async {
    try {
      print('Initializing AppStateManager in background...');

      // Initialize the centralized app state manager
      await _appStateManager.initialize();

      // Listen to app state changes
      _appStateManager.stateStream.listen((state) {
        print(
            'AppStateManager state change: userId=${state.currentUserId}, initialized=${state.isInitialized}');
        if (mounted) {
          setState(() {
            // Update UI based on app state changes
          });
        }
      });

      print('✅ AppStateManager initialization completed');
    } catch (e) {
      print('❌ AppStateManager initialization error: $e');
    }
  }

  void _initializeGoogleFitManager() async {
    try {
      print('Initializing GlobalGoogleFitManager in background...');

      // Initialize Google Fit manager for global sync
      await _googleFitManager.initialize();

      print('✅ GlobalGoogleFitManager initialization completed');
    } catch (e) {
      print('❌ GlobalGoogleFitManager initialization error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('🔄 App resumed - Ensuring Google Fit sync...');
        _googleFitManager.ensureSync();
        break;
      case AppLifecycleState.paused:
        print('⏸️ App paused - Google Fit will continue in background');
        break;
      case AppLifecycleState.detached:
        print('🔌 App detached - Cleaning up Google Fit resources...');
        _googleFitManager.dispose();
        break;
      case AppLifecycleState.inactive:
        print('⏸️ App inactive - Google Fit sync paused');
        break;
      case AppLifecycleState.hidden:
        print('👁️ App hidden - Google Fit sync continues');
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildHomeScreen() {
    return StreamBuilder<AppState>(
      stream: _appStateManager.stateStream,
      builder: (context, snapshot) {
        print(
            'App state snapshot: ${snapshot.connectionState}, data: ${snapshot.data}');

        if (snapshot.hasError) {
          print('App state error: ${snapshot.error}');
          return const WelcomeScreen();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('App state waiting...');
          return const Center(child: CircularProgressIndicator());
        }

        final appState = snapshot.data;
        print(
            'App state data: isInitialized=${appState?.isInitialized}, userId=${appState?.currentUserId}');

        if (appState == null || appState.currentUserId.isEmpty) {
          print('No user authenticated, showing welcome screen');
          return const WelcomeScreen();
        }

        print('User authenticated, showing main navigation');
        return const MainNavigation();
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calorie Vita',
      theme: AppTheme.lightTheme,
      home: RewardNotificationWidget(
        child: _buildHomeScreen(),
      ),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const MainNavigation(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/welcome') {
          return MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalGoogleFitManager _googleFitManager = GlobalGoogleFitManager();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isCheckingOnboarding = true;
  bool _onboardingCompleted = false;
  
  final List<Widget> _screens = [
    const PremiumHomeScreen(),
    const AnalyticsScreen(),
    const SizedBox(), // Placeholder for FAB
    const AITrainerScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboardingStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check onboarding status when app resumes
      _checkOnboardingStatus();
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final userId = _firebaseService.getCurrentUserId();
      if (userId != null) {
        final isCompleted = await _firebaseService.isOnboardingCompleted(userId);
        if (mounted) {
          setState(() {
            _onboardingCompleted = isCompleted;
            _isCheckingOnboarding = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _onboardingCompleted = false;
            _isCheckingOnboarding = false;
          });
        }
      }
    } catch (e) {
      print('Error checking onboarding status: $e');
      if (mounted) {
        setState(() {
          _onboardingCompleted = false;
          _isCheckingOnboarding = false;
        });
      }
    }
  }

  // Method to refresh onboarding status (called from onboarding screen)
  void refreshOnboardingStatus() {
    _checkOnboardingStatus();
  }


  void _onTabSelected(int index) {
    print('Tab selected: $index'); // Debug log

    // Trigger Google Fit sync whenever a screen is opened
    _googleFitManager.ensureSync().catchError((e) {
      print('Failed to ensure Google Fit sync on screen change: $e');
    });

    if (index == 2) {
      // Open camera
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    } else if (index == 3) {
      // AI Trainer screen
      setState(() => _currentIndex = 3);
    } else if (index == 4) {
      // Settings screen
      setState(() => _currentIndex = 4);
    } else if (index >= 0 && index < _screens.length && index != 2) {
      print('Setting current index to: $index'); // Debug log
      setState(() => _currentIndex = index);
    } else {
      print(
          'Invalid index: $index, screens length: ${_screens.length}'); // Debug log
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking onboarding status
    if (_isCheckingOnboarding) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your profile...'),
            ],
          ),
        ),
      );
    }

    // Show onboarding if not completed
    if (!_onboardingCompleted) {
      return OnboardingScreen(
        onCompleted: () {
          // Refresh onboarding status when completed
          _checkOnboardingStatus();
        },
      );
    }

    // Show main navigation if onboarding is completed
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _screens[_currentIndex],
      ),

      // Custom Bottom Navigation with Large Center Button
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home Tab
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabSelected(0),
                ),

                // Analytics Tab
                _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Analytics',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                ),

                // Center Camera Button (Larger)
                _buildCenterCameraButton(),

                // AI Trainer Tab
                _buildNavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Trainer',
                  isSelected: _currentIndex == 3,
                  onTap: () => _onTabSelected(3),
                ),

                // Settings Tab
                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isSelected: _currentIndex == 4,
                  onTap: () => _onTabSelected(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterCameraButton() {
    return GestureDetector(
      onTap: () => _onTabSelected(2),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

