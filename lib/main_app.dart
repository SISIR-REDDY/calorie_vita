import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home/home_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/camera/camera_screen.dart';
import 'screens/ai_trainer/ai_trainer_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/auth/initial_welcome_screen.dart';
import 'widgets/premium_nav_bar.dart';
import 'ui/app_theme.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calorie Vita',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const InitialWelcomeScreen();
          }
          return const MainNavigation();
        },
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
  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    SizedBox(), // Placeholder for FAB
    AITrainerScreen(),
    SettingsScreen(),
  ];

  void _onTabSelected(int index) {
    if (index == 2) {
      // Open camera
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isAITrainer = _currentIndex == 3;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _screens[_currentIndex],
      ),
      floatingActionButton: (!isKeyboardOpen || !isAITrainer)
          ? FloatingActionButton(
              onPressed: () => _onTabSelected(2),
              child: const Icon(Icons.camera_alt_rounded),
              shape: const CircleBorder(),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: PremiumNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }
} 