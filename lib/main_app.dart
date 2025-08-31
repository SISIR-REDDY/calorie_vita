import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home/home_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/camera/camera_screen.dart';
// import 'screens/ai_trainer/ai_trainer_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/auth/initial_welcome_screen.dart';
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
  final List<Widget> _screens = [
    const HomeScreen(),
    const AnalyticsScreen(),
    const SizedBox(), // Placeholder for FAB
    // AITrainerScreen(),
    const SettingsScreen(),
  ];



  void _onTabSelected(int index) {
    print('Tab selected: $index'); // Debug log
    if (index == 2) {
      // Open camera
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
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
                
                // Placeholder for AI Trainer
                _buildNavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Trainer',
                  isSelected: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Trainer coming soon!')),
                    );
                  },
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