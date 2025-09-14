import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../services/auth_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isGoogleSigningIn = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
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
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google successfully!'),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    } catch (e) {
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
        child: FadeTransition(
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
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          children: [
            Image.asset(
              'calorie_logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
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
              color: color.withOpacity(0.1),
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

  /// Professional Google Sign-In Button following Google Brand Guidelines
  Widget _buildProfessionalGoogleButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFDADCE0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isGoogleSigningIn ? null : _signInWithGoogle,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGoogleSigningIn) ...[
                  // Loading indicator
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3C4043),
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
                      letterSpacing: 0.25,
                    ),
                  ),
                ] else ...[
                  // Google Logo using official colors
                  _buildGoogleLogo(),
                  const SizedBox(width: 12),
                  // Google Text
                  Text(
                    'Sign in with Google',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF3C4043),
                      letterSpacing: 0.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Official Google Logo using proper brand colors
  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

/// Official Google Logo Painter following Google Brand Guidelines
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Official Google brand colors
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;
    
    paint.style = PaintingStyle.fill;
    
    // Blue section (top-right)
    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, // -90 degrees
      1.57,  // 90 degrees
      true,
      paint,
    );
    
    // Red section (right)
    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,     // 0 degrees
      1.57,  // 90 degrees
      true,
      paint,
    );
    
    // Yellow section (bottom)
    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.57,  // 90 degrees
      1.57,  // 90 degrees
      true,
      paint,
    );
    
    // Green section (left)
    paint.color = green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14,  // 180 degrees
      1.57,  // 90 degrees
      true,
      paint,
    );
    
    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.65, paint);
    
    // Blue "G" cutout
    paint.color = blue;
    final path = Path();
    path.moveTo(center.dx, center.dy - radius * 0.65);
    path.arcTo(
      Rect.fromCircle(center: center, radius: radius * 0.65),
      -1.57, // -90 degrees
      4.71,  // 270 degrees
      false,
    );
    path.lineTo(center.dx + radius * 0.25, center.dy);
    path.lineTo(center.dx + radius * 0.65, center.dy);
    path.lineTo(center.dx + radius * 0.65, center.dy + radius * 0.1);
    path.lineTo(center.dx + radius * 0.25, center.dy + radius * 0.1);
    path.lineTo(center.dx + radius * 0.25, center.dy);
    path.close();
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}