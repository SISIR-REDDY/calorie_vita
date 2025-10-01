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
                  colors: [
                    kAccentGreen.withOpacity(0.1),
                    kAccentBlue.withOpacity(0.1)
                  ],
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
Calorie Vita is a comprehensive health and wellness mobile application designed to assist users with nutritional tracking and fitness goal management.

Core Features:
• Food logging and calorie tracking with photo recognition
• AI-powered nutrition analysis and recommendations
• Fitness goal setting and progress monitoring
• Personalized health coaching and insights
• Macro and micronutrient tracking
• Health analytics and comprehensive reporting
• Weight management and BMI tracking

AI-Powered Services:
• Advanced AI integration via OpenRouter API for intelligent nutrition analysis
• Machine learning algorithms for personalized meal recommendations
• Automated nutritional content analysis from food photographs
• Intelligent progress tracking and pattern recognition
• AI-driven health insights and coaching suggestions

Integration Capabilities:
• Google Fit and Health Connect integration
• Wearable device synchronization
• Cloud-based data storage and synchronization via Firebase
• Data export and portability features
• Third-party health platform compatibility

The Service is provided on an "as-is" and "as-available" basis. We reserve the right to modify, suspend, or discontinue any aspect of the Service at any time with or without notice.
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
IMPORTANT MEDICAL DISCLAIMER: Calorie Vita is a nutritional tracking and wellness tool and is NOT a medical device, healthcare provider, or substitute for professional medical advice, diagnosis, or treatment.

Health Information Disclaimer:
• The App provides general health, fitness, and nutritional information for educational and informational purposes only
• All content, including AI-generated recommendations, is not intended as medical advice, diagnosis, or treatment
• You must always consult qualified healthcare professionals before making any health-related decisions, including dietary changes, exercise programs, or weight management strategies
• We do not diagnose, treat, cure, or prevent any disease, medical condition, or health problem

AI-Generated Content Limitations:
• AI recommendations and nutrition analysis are automated and for informational purposes only
• AI-generated content may contain errors, inaccuracies, or be incomplete
• Individual nutritional needs vary significantly based on medical conditions, medications, allergies, and personal health factors
• AI analysis should never replace professional nutritional counseling or medical advice

Health and Safety Warnings:
• Not suitable for individuals with eating disorders, diabetes, cardiovascular disease, or other serious medical conditions without physician oversight
• Pregnant or nursing women must consult healthcare providers before using dietary tracking features
• Individuals taking medications that interact with diet must seek medical guidance
• Emergency medical situations require immediate professional medical attention - do not rely on the App for emergencies

User Responsibility and Acknowledgment:
• You acknowledge sole responsibility for all health and fitness decisions
• You agree to consult licensed healthcare providers before implementing any dietary or fitness changes
• You agree to monitor your health status and seek immediate medical attention for any adverse symptoms
• You understand the App is a supplementary tool and not a replacement for professional medical care
• You agree to inform your healthcare providers about your use of this App and any data collected
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
              title: '12. Governing Law and Dispute Resolution',
              content: '''
These Terms shall be governed by and construed in accordance with applicable laws and regulations.

Governing Law:
• These Terms are governed by the laws of [YOUR_JURISDICTION - e.g., "the State of California, United States" or "India"]
• International users remain subject to their local consumer protection laws and regulations
• We comply with applicable data protection regulations including GDPR (where applicable)
• Certain provisions may vary by jurisdiction to comply with local legal requirements

Informal Dispute Resolution:
• Prior to initiating formal proceedings, parties agree to attempt good-faith negotiation
• Notice of dispute must be sent in writing to: legal@calorievita.com
• Parties shall have 30 days from notice to attempt informal resolution
• This requirement does not apply to claims seeking injunctive relief

Arbitration Agreement:
• Any dispute arising from these Terms shall be resolved through binding arbitration
• Arbitration shall be conducted under the rules of [YOUR_ARBITRATION_BODY - e.g., "American Arbitration Association" or relevant local body]
• Arbitration location: [YOUR_ARBITRATION_LOCATION - e.g., "San Francisco, California" or relevant city]
• Each party bears their own costs unless otherwise awarded by arbitrator
• Class action waiver: You agree to resolve disputes individually and waive rights to class action proceedings

Legal Proceedings and Jurisdiction:
• Exclusive jurisdiction for any court proceedings: [YOUR_COURT_JURISDICTION - e.g., "courts located in San Francisco County, California"]
• You irrevocably consent to the personal jurisdiction of these courts
• Either party may seek equitable relief (including injunctive relief) in any competent court
• Claims must be brought within one (1) year of the cause of action arising, after which claims are time-barred

Exceptions:
• Small claims court proceedings (up to jurisdictional limit)
• Claims for intellectual property infringement
• Claims seeking emergency injunctive relief
              ''',
            ),

            _buildSection(
              title: '13. Contact Information',
              content: '''
For questions, concerns, or inquiries regarding these Terms and Conditions or our services, please contact us:

Email: calorievita@gmail.com

You can reach us for:
• General inquiries and customer support
• Technical support and troubleshooting
• Legal and compliance matters
• Privacy and data protection concerns
• Feedback and suggestions

Expected Response Times:
• General customer support: Within 24-48 business hours
• Technical support issues: Within 12-24 business hours
• Legal and compliance matters: Within 5-7 business days
• Data protection requests (GDPR/Privacy): Within 30 days as required by law
• Urgent security issues: Immediate priority response

Note: Response times may vary during holidays or periods of high volume. We appreciate your patience and will respond to all inquiries as promptly as possible.
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
