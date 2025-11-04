import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import '../ui/app_colors.dart';
import '../services/auth_service.dart';
import '../services/app_state_manager.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final AppStateManager _appStateManager = AppStateManager();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isGoogleSigningIn = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupAuthListener();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800), // Reduced duration
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600), // Reduced duration
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Reduced offset
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations with a small delay to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _slideController.forward();
          }
        });
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  void _setupAuthListener() {
    // Listen to auth state changes for immediate navigation
    _authService.userStream.listen((user) {
      if (user != null && mounted) {
        print('🔐 Auth state changed in welcome screen: ${user.email}');
        // Navigate to home screen immediately
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isGoogleSigningIn) return;

    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      print('🔐 Starting Google Sign-In process...');
      final user = await _authService.signInWithGoogle();
      
      if (user != null && mounted) {
        print('✅ Google Sign-In successful: ${user.email}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google successfully!'),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            duration: Duration(seconds: 2),
          ),
        );

        // Update app state to trigger navigation
        print('🔄 Updating app state with user: ${user.uid}');
        await _appStateManager.updateUserState(user.uid);
        
        // The navigation will be handled by the StreamBuilder in main_app.dart
        // which listens to the app state changes
        print('✅ App state updated, navigation should happen automatically');
        
        // Fallback navigation after a short delay if the automatic navigation doesn't work
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            print('🔄 Fallback navigation triggered');
            Navigator.of(context).pushReplacementNamed('/home');
          }
        });
      } else {
        print('❌ Google Sign-In returned null user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google sign-in was cancelled'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${e.toString()}'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      body: SafeArea(
        child: _isInitialized
            ? FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: CustomScrollView(
                    slivers: [
                      _buildHeaderSection(),
                      _buildAuthenticationSection(),
                      _buildFeaturesSection(),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 40),
                      ),
                    ],
                  ),
                ),
              )
            : _buildLoadingState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width < 360 ? 60 : 80,
            height: MediaQuery.of(context).size.width < 360 ? 60 : 80,
            constraints: const BoxConstraints(
              minWidth: 50,
              maxWidth: 100,
              minHeight: 50,
              maxHeight: 100,
            ),
            child: Image.asset(
              'calorie_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Calorie Vita',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kAccentBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          children: [
            Container(
              width: MediaQuery.of(context).size.width < 360 ? 80 : 100,
              height: MediaQuery.of(context).size.width < 360 ? 80 : 100,
              constraints: const BoxConstraints(
                minWidth: 70,
                maxWidth: 120,
                minHeight: 70,
                maxHeight: 120,
              ),
              child: Image.asset(
                'calorie_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Calorie Vita',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Track your nutrition, achieve your goals with AI-powered insights',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: kTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Features',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              icon: Icons.camera_alt_rounded,
              title: 'AI Food Recognition',
              description: 'Take a photo and get instant nutrition information',
              color: kAccentBlue,
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              icon: Icons.track_changes_rounded,
              title: 'Smart Tracking',
              description: 'Monitor calories and macros effortlessly',
              color: kAccentGreen,
            ),
            const SizedBox(height: 12),
            _buildFeatureCard(
              icon: Icons.psychology_rounded,
              title: 'AI Coach',
              description: 'Get personalized nutrition advice and insights',
              color: kAccentPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get Started',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildProfessionalGoogleButton(),
            const SizedBox(height: 24),
            Text(
              'Sign in with your Google account to start tracking your nutrition journey',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: kTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Professional Google Sign-In Button using Google's official design guidelines
  Widget _buildProfessionalGoogleButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isGoogleSigningIn
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFDADCE0),
                  width: 1,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4285F4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Signing in...',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF3C4043),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: SignInButton(
                Buttons.Google,
                text: "Sign in with Google",
                onPressed: _signInWithGoogle,
              ),
            ),
    );
  }

}