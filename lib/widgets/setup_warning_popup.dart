import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/app_colors.dart';

class SetupWarningPopup extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onNavigateToSettings;

  const SetupWarningPopup({
    super.key,
    this.onComplete,
    this.onNavigateToSettings,
  });

  @override
  State<SetupWarningPopup> createState() => _SetupWarningPopupState();
}

class _SetupWarningPopupState extends State<SetupWarningPopup>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _markAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_warning_shown', true);
    } catch (e) {
      // Handle error silently
    }
  }

  void _handleComplete() async {
    await _markAsShown();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onComplete?.call();
    }
  }

  void _handleNavigateToSettings() async {
    await _markAsShown();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onNavigateToSettings?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isDark ? kDarkSurfaceLight : kSurfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              kPrimaryColor,
                              kPrimaryLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        'Complete Your Setup',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? kDarkTextPrimary : kTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      Text(
                        'To provide you with the best experience, please complete your profile setup by filling in your personal details, setting your fitness goals, and connecting to Google Fit for accurate health tracking.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? kDarkTextSecondary : kTextSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _handleComplete,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? kDarkTextTertiary : kTextTertiary,
                                side: BorderSide(
                                  color: isDark ? kDarkBorderColor : kBorderColor,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Maybe Later',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _handleNavigateToSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Complete Setup',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
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
          ),
        );
      },
    );
  }
}

class SetupWarningService {
  static const String _setupWarningKey = 'setup_warning_shown';
  static const String _setupCompleteKey = 'setup_complete';

  /// Check if setup warning has been shown before
  static Future<bool> hasShownWarning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_setupWarningKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark setup warning as shown
  static Future<void> markWarningAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupWarningKey, true);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Check if setup is complete
  static Future<bool> isSetupComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_setupCompleteKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark setup as complete
  static Future<void> markSetupComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupCompleteKey, true);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Reset setup status (for testing)
  static Future<void> resetSetupStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_setupWarningKey);
      await prefs.remove(_setupCompleteKey);
    } catch (e) {
      // Handle error silently
    }
  }
}
