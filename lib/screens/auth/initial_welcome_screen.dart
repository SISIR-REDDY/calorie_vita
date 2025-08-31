import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ui/app_colors.dart';

class InitialWelcomeScreen extends StatefulWidget {
  const InitialWelcomeScreen({super.key});

  @override
  State<InitialWelcomeScreen> createState() => _InitialWelcomeScreenState();
}

class _InitialWelcomeScreenState extends State<InitialWelcomeScreen> {
  bool _isSignIn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // App Logo/Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: kElevatedShadow,
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // App Title
              Text(
                'Calorie Vita',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle
              Text(
                'Your AI-powered nutrition companion',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: kTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Feature List
              _buildFeatureItem(
                Icons.camera_alt,
                'AI Food Recognition',
                'Take a photo and get instant nutrition info',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.track_changes,
                'Smart Tracking',
                'Monitor your daily calorie intake',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.auto_awesome,
                'Personalized Tips',
                'Get AI-powered nutrition advice',
              ),
              
              const Spacer(),
              
              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showAuthDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSignIn ? 'Sign In' : 'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isSignIn = !_isSignIn;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: BorderSide(color: kPrimaryColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSignIn ? 'Create Account' : 'Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
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
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAuthDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: kSurfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: kPrimaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isSignIn ? 'Sign In' : 'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Form Fields
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement authentication
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isSignIn ? 'Signing in...' : 'Creating account...'),
                        backgroundColor: kSuccessColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSignIn ? kPrimaryColor : kSecondaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSignIn ? 'Sign In' : 'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
} 