import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/trainer_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/reward_notification_widget.dart';
import 'ui/app_theme.dart';
import 'services/app_state_manager.dart';
import 'firebase_options.dart';

class MainApp extends StatefulWidget {
  final bool firebaseInitialized;
  
  const MainApp({super.key, this.firebaseInitialized = false});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final AppStateManager _appStateManager = AppStateManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Immediate initialization - no waiting
    _initializeAppImmediately();
  }

  void _initializeAppImmediately() {
    print('Starting immediate app initialization...');
    
    // Set initialized immediately - no waiting
    setState(() {
      _isInitialized = true;
    });
    
    print('App initialized immediately - showing welcome screen');
    
    // Initialize app state manager in background (non-blocking)
    _initializeAppStateManager();
  }

  void _initializeAppStateManager() async {
    try {
      print('Initializing AppStateManager in background...');
      
      // Initialize the centralized app state manager
      await _appStateManager.initialize();
      
      // Listen to app state changes
      _appStateManager.stateStream.listen((state) {
        print('AppStateManager state change: userId=${state.currentUserId}, initialized=${state.isInitialized}');
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state if needed
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
        print('App state snapshot: ${snapshot.connectionState}, data: ${snapshot.data}');
        
        if (snapshot.hasError) {
          print('App state error: ${snapshot.error}');
          return const WelcomeScreen();
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('App state waiting...');
          return const Center(child: CircularProgressIndicator());
        }
        
        final appState = snapshot.data;
        print('App state data: isInitialized=${appState?.isInitialized}, userId=${appState?.currentUserId}');
        
        if (appState == null || appState.currentUserId.isEmpty) {
          print('No user authenticated, showing welcome screen');
          return const WelcomeScreen();
        }
        
        print('User authenticated, showing main navigation');
        return const MainNavigation();
      },
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Restart the app
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainApp()),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Calorie Vita',
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                  Color(0xFFf093fb),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'calorie_logo.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  
                  // App Title
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1200),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Text(
                          'Calorie Vita',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Loading indicator
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Initializing Calorie Vita...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Debug button to force initialization
                            ElevatedButton(
                              onPressed: () {
                                print('Force initialization button pressed');
                                setState(() {
                                  _isInitialized = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Skip Loading'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calorie Vita',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: RewardNotificationWidget(
        child: _buildHomeScreen(),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const PremiumHomeScreen(),
    AnalyticsScreen(),
    const SizedBox(), // Placeholder for FAB
    const AITrainerScreen(),
    const SettingsScreen(), 
  ];



  void _onTabSelected(int index) {
    print('Tab selected: $index'); // Debug log
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
      print('Invalid index: $index, screens length: ${_screens.length}'); // Debug log
    }
  }

  @override
  Widget build(BuildContext context) {
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
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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