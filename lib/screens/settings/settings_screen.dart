import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ui/app_colors.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  late SharedPreferences _prefs;
  bool _isLoading = true;
  
  // Settings state
  bool _darkMode = false;
  bool _notifications = true;
  bool _useKcal = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    print('Loading settings...'); // Debug print
    try {
      _prefs = await SharedPreferences.getInstance();
      setState(() {
        _darkMode = _prefs.getBool('darkMode') ?? false;
        _notifications = _prefs.getBool('notifications') ?? true;
        _useKcal = _prefs.getBool('useKcal') ?? true;

        _isLoading = false;
      });
      print('Settings loaded successfully'); // Debug print
    } catch (e) {
      print('Error loading settings: $e'); // Debug print
      // Fallback to default values if SharedPreferences fails
      setState(() {
        _darkMode = false;
        _notifications = true;
        _useKcal = true;

        _isLoading = false;
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is String) {
        await _prefs.setString(key, value);
      }
    } catch (e) {
      print('Error saving setting: $e');
      // Continue without saving if SharedPreferences fails
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kSurfaceLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Add error handling for Firebase Auth
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      print('Firebase Auth error: $e');
      // Continue with null user - don't let Firebase errors break the UI
      user = null;
    }
    
    // Simple fallback UI if there are any issues
    try {
      return Scaffold(
        backgroundColor: kSurfaceLight,
        body: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: kSurfaceColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: kSecondaryGradient,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Settings ⚙️',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Customize your experience',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Simple Settings List
                    Container(
                      decoration: const BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: kCardShadow,
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.dark_mode),
                            title: const Text('Dark Mode'),
                            trailing: Switch(
                              value: _darkMode,
                              onChanged: (value) {
                                setState(() => _darkMode = value);
                                _saveSetting('darkMode', value);
                                _settingsService.toggleTheme(value);
                              },
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.notifications),
                            title: const Text('Notifications'),
                            trailing: Switch(
                              value: _notifications,
                              onChanged: (value) {
                                setState(() => _notifications = value);
                                _saveSetting('notifications', value);
                              },
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.science),
                            title: const Text('Use Kcal'),
                            trailing: Switch(
                              value: _useKcal,
                              onChanged: (value) {
                                setState(() => _useKcal = value);
                                _saveSetting('useKcal', value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // User Info (if available)
                    if (user != null)
                      Container(
                        decoration: const BoxDecoration(
                          color: kSurfaceColor,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          boxShadow: kCardShadow,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(user.displayName ?? 'User'),
                          subtitle: Text(user.email ?? ''),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // TODO: Navigate to profile
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Fallback to simple UI if there are any rendering errors
      print('Error rendering settings screen: $e');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings, size: 64, color: kPrimaryColor),
              const SizedBox(height: 16),
              const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Basic settings functionality'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() => _darkMode = !_darkMode);
                  _saveSetting('darkMode', _darkMode);
                },
                child: Text('Toggle Dark Mode: ${_darkMode ? "ON" : "OFF"}'),
              ),
            ],
          ),
        ),
      );
    }
  }
} 