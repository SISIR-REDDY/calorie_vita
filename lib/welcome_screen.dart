import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home/home_screen.dart';
import 'ui/app_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _showAuthDialog({required bool isSignUp}) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: isSignUp ? kSecondaryGradient : kPrimaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isSignUp ? Icons.person_add : Icons.login,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            isSignUp ? 'Create Account' : 'Welcome Back',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Email field
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email address',
                          prefixIcon: Icon(Icons.email_outlined, color: kTextTertiary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: kSurfaceLight,
                        ),
                        validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Icons.lock_outline, color: kTextTertiary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: kSurfaceLight,
                        ),
                        validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters',
                      ),
                      const SizedBox(height: 24),
                      
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSignUp ? kSecondaryColor : kPrimaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => loading = true);
                                  try {
                                    if (isSignUp) {
                                      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                        email: emailController.text.trim(),
                                        password: passwordController.text.trim(),
                                      );
                                    } else {
                                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                                        email: emailController.text.trim(),
                                        password: passwordController.text.trim(),
                                      );
                                    }
                                    if (mounted) {
                                      Navigator.pop(context); // Close dialog
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                                      );
                                    }
                                  } on FirebaseAuthException catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.message ?? 'Authentication failed'),
                                          backgroundColor: kErrorColor,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => loading = false);
                                    }
                                  }
                                },
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isSignUp ? 'Create Account' : 'Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

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
              
              // App Subtitle
              Text(
                'Track your nutrition, achieve your goals',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: kTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Features
              _buildFeatureItem(
                Icons.camera_alt,
                'AI Food Recognition',
                'Take a photo and get instant nutrition info',
              ),
              const SizedBox(height: 20),
              _buildFeatureItem(
                Icons.track_changes,
                'Smart Tracking',
                'Monitor calories and macros effortlessly',
              ),
              const SizedBox(height: 20),
              _buildFeatureItem(
                Icons.psychology,
                'AI Coach',
                'Get personalized nutrition advice',
              ),
              
              const Spacer(),
              
              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _showAuthDialog(isSignUp: false),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _showAuthDialog(isSignUp: true),
                      child: Text(
                        'Create Account',
                        style: GoogleFonts.inter(
                          fontSize: 18,
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
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
                  subtitle,
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
      ),
    );
  }
} 