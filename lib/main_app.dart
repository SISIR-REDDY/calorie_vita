import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/trainer_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/settings_screen.dart';
import 'ui/app_theme.dart';
import 'services/integration_service.dart';
import 'services/bluetooth_device_service.dart';
import 'services/demo_auth_service.dart';
import 'firebase_options.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final IntegrationService _integrationService = IntegrationService();
  final BluetoothDeviceService _bluetoothService = BluetoothDeviceService();
  final DemoAuthService _demoAuth = DemoAuthService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('Starting app initialization...');
    
    // Initialize demo auth service
    await _demoAuth.initialize();
    
    // Initialize Bluetooth service and restore connected devices
    _bluetoothService.restoreConnectedDevices().catchError((error) {
      print('Bluetooth service initialization error: $error');
    });
    
    // Skip all complex initialization for now
    await Future.delayed(const Duration(milliseconds: 100));
    
    print('App initialization completed (minimal)');
    setState(() {
      _isInitialized = true;
    });
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
    try {
      // Check if Firebase is properly configured
      final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
      final apiKey = firebaseOptions.apiKey;
      
      // If API key contains placeholder text, use demo authentication
      if (apiKey.contains('YOUR_FIREBASE') || apiKey.contains('HERE')) {
        print('Firebase not configured (placeholder API key), using demo authentication');
        return StreamBuilder<DemoUser?>(
          stream: _demoAuth.userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const WelcomeScreen();
            }
            return const MainNavigation();
          },
        );
      }
      
      // Firebase is configured, use Firebase authentication
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Handle Firebase errors gracefully - show welcome screen
            print('Firebase auth error: ${snapshot.error}');
            return const WelcomeScreen();
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const WelcomeScreen();
          }
          return const MainNavigation();
        },
      );
    } catch (e) {
      // If Firebase is not available, use demo authentication
      print('Firebase not available, using demo authentication: $e');
      return StreamBuilder<DemoUser?>(
        stream: _demoAuth.userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const WelcomeScreen();
          }
          return const MainNavigation();
        },
      );
    }
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
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Initializing Calorie Vita...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
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
      home: _buildHomeScreen(),
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
    const AnalyticsScreen(),
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