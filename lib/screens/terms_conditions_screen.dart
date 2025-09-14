import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';

/// Terms & Conditions Screen for Calorie Vita App
/// Comprehensive terms and conditions with actual content
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kSurfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kAccentGreen.withOpacity(0.1), kAccentBlue.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: kAccentGreen,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Terms & Conditions',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            _buildSection(
              title: '1. Acceptance of Terms',
              content: '''
By downloading, installing, or using the Calorie Vita mobile application ("App"), you agree to be bound by these Terms and Conditions ("Terms").

Agreement to Terms:
• You acknowledge that you have read and understood these Terms
• You agree to comply with all applicable laws and regulations
• You represent that you are at least 13 years of age
• You have the legal capacity to enter into this agreement

Updates to Terms:
• We may modify these Terms at any time
• Continued use constitutes acceptance of changes
• We will notify you of material changes
• Your rights and obligations remain in effect
              ''',
            ),

            _buildSection(
              title: '2. Description of Service',
              content: '''
Calorie Vita is a comprehensive health and fitness application that provides:

Core Features:
• Food logging and calorie tracking
• AI-powered nutrition recommendations
• Fitness goal setting and progress tracking
• Personalized coaching and insights
• Photo-based food recognition
• Health analytics and reporting

AI Services:
• Google Gemini API integration for personalized advice
• Machine learning for nutrition recommendations
• Automated meal planning and suggestions
• Intelligent progress analysis

Additional Services:
• Social features and community support
• Integration with health devices
• Export and data portability
• Premium features and subscriptions
              ''',
            ),

            _buildSection(
              title: '3. User Accounts and Registration',
              content: '''
To access certain features, you must create an account with accurate information.

Account Requirements:
• Provide accurate and complete information
• Maintain the security of your account credentials
• Notify us immediately of any unauthorized access
• You are responsible for all activities under your account

Account Restrictions:
• One account per person
• No sharing of account credentials
• No creating accounts for others
• No impersonation or false information

Account Termination:
• We may suspend or terminate accounts for violations
• You may delete your account at any time
• Data deletion policies apply upon termination
• Some information may be retained for legal purposes
              ''',
            ),

            _buildSection(
              title: '4. Acceptable Use Policy',
              content: '''
You agree to use the App only for lawful purposes and in accordance with these Terms.

Permitted Uses:
• Personal health and fitness tracking
• Educational and informational purposes
• Sharing your own health data
• Participating in community features

Prohibited Uses:
• Violating any applicable laws or regulations
• Infringing on intellectual property rights
• Transmitting harmful or malicious content
• Attempting to gain unauthorized access
• Interfering with the App's functionality
• Creating fake or misleading information
• Harassing or abusing other users
• Commercial use without permission
              ''',
            ),

            _buildSection(
              title: '5. Health and Medical Disclaimer',
              content: '''
IMPORTANT: Calorie Vita is not a medical device or healthcare provider.

Health Information:
• The App provides general health and fitness information
• Information is not intended as medical advice
• Always consult healthcare professionals for medical decisions
• We do not diagnose, treat, or cure any medical conditions

Limitations:
• AI recommendations are for informational purposes only
• Individual results may vary
• Not suitable for people with certain medical conditions
• Emergency situations require immediate medical attention

Your Responsibility:
• Consult healthcare providers before making health changes
• Monitor your health and seek medical attention when needed
• Use the App as a supplement, not replacement for medical care
• Report any adverse effects to your healthcare provider
              ''',
            ),

            _buildSection(
              title: '6. Intellectual Property Rights',
              content: '''
The App and its content are protected by intellectual property laws.

Our Rights:
• We own all rights to the App and its content
• Trademarks, logos, and branding are our property
• Software code and algorithms are proprietary
• User interface and design elements are protected

Your Rights:
• You retain ownership of your personal data
• You may use the App for personal, non-commercial purposes
• You may export your data in accordance with our policies
• You may provide feedback and suggestions

Restrictions:
• No copying, modifying, or distributing the App
• No reverse engineering or decompilation
• No creating derivative works
• No removing copyright or proprietary notices
              ''',
            ),

            _buildSection(
              title: '7. Privacy and Data Protection',
              content: '''
Your privacy is important to us. Please review our Privacy Policy for detailed information.

Data Collection:
• We collect information necessary to provide our services
• Personal health data is handled with special care
• We implement appropriate security measures
• We comply with applicable privacy laws

Your Rights:
• Access, update, or delete your personal information
• Control how your data is used and shared
• Export your data in a portable format
• Opt out of certain data processing activities

Data Sharing:
• We do not sell your personal information
• Limited sharing with service providers
• Compliance with legal requirements
• Protection of our rights and property
              ''',
            ),

            _buildSection(
              title: '8. Subscription and Payment Terms',
              content: '''
Some features may require a paid subscription.

Subscription Plans:
• Free tier with basic features
• Premium subscriptions with advanced features
• Family plans for multiple users
• Enterprise plans for organizations

Payment Terms:
• Subscriptions are billed in advance
• Automatic renewal unless cancelled
• Prices may change with notice
• Refunds subject to our refund policy

Cancellation:
• Cancel anytime through your account settings
• Access continues until the end of the billing period
• No refunds for partial periods
• Data retention policies apply after cancellation
              ''',
            ),

            _buildSection(
              title: '9. Disclaimers and Limitations',
              content: '''
THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND.

Service Availability:
• We strive for high availability but cannot guarantee 100% uptime
• Maintenance and updates may cause temporary interruptions
• Third-party services may affect functionality
• We reserve the right to modify or discontinue features

Limitation of Liability:
• We are not liable for indirect or consequential damages
• Our total liability is limited to the amount you paid us
• We are not responsible for third-party actions
• Some jurisdictions may not allow liability limitations

Accuracy of Information:
• We strive for accuracy but cannot guarantee perfection
• Information may become outdated
• Users should verify important information
• We are not liable for reliance on inaccurate information
              ''',
            ),

            _buildSection(
              title: '10. Indemnification',
              content: '''
You agree to indemnify and hold us harmless from certain claims.

Your Indemnification Obligations:
• Claims arising from your use of the App
• Violations of these Terms or applicable laws
• Infringement of third-party rights
• Misuse of the App or its features

Our Rights:
• We may assume control of any defense
• You must cooperate with our defense efforts
• We may settle claims as we see fit
• You remain liable for any damages or costs
              ''',
            ),

            _buildSection(
              title: '11. Termination',
              content: '''
Either party may terminate this agreement at any time.

Termination by You:
• Delete your account through the App settings
• Stop using the App and delete it from your device
• Contact us to request account deletion
• Data deletion policies will apply

Termination by Us:
• For violations of these Terms
• For fraudulent or illegal activity
• For non-payment of subscription fees
• For any reason with appropriate notice

Effect of Termination:
• Your right to use the App ceases immediately
• We may delete your account and data
• Some provisions survive termination
• You remain liable for obligations incurred before termination
              ''',
            ),

            _buildSection(
              title: '12. Governing Law and Disputes',
              content: '''
These Terms are governed by applicable laws and dispute resolution procedures.

Governing Law:
• These Terms are governed by the laws of [Jurisdiction]
• International users may be subject to local laws
• We comply with applicable consumer protection laws
• Some terms may vary by jurisdiction

Dispute Resolution:
• We encourage resolving disputes through direct communication
• Mediation may be required before litigation
• Arbitration may be required for certain disputes
• Class action waivers may apply

Legal Proceedings:
• Jurisdiction for legal proceedings is [Court Location]
• You consent to the jurisdiction of these courts
• We may seek injunctive relief in any court
• Time limits for bringing claims may apply
              ''',
            ),

            _buildSection(
              title: '13. Contact Information',
              content: '''
For questions about these Terms or our services, please contact us:

General Inquiries:
Email: support@calorievita.com
Phone: +1 (555) 123-4567
Address: Calorie Vita Support Team
123 Health Street, Wellness City, WC 12345

Legal Matters:
Email: legal@calorievita.com
Address: Calorie Vita Legal Department
123 Health Street, Wellness City, WC 12345

Response Times:
• General inquiries: 24-48 hours
• Technical support: 12-24 hours
• Legal matters: 5-7 business days
• Emergency issues: Immediate attention
              ''',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kTextSecondary.withOpacity(0.2)),
            ),
            child: Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: kTextDark,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
