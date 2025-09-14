import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';

/// Privacy Policy Screen for Calorie Vita App
/// Comprehensive privacy policy with actual content
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
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
                  colors: [kAccentBlue.withOpacity(0.1), kAccentPurple.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    size: 48,
                    color: kAccentBlue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Privacy Policy',
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
              title: '1. Information We Collect',
              content: '''
We collect information you provide directly to us, such as when you create an account, use our services, or contact us for support.

Personal Information:
• Name, email address, and profile information
• Age, gender, height, weight, and fitness goals
• Dietary preferences and health information
• Profile photos and user-generated content

Usage Information:
• App usage patterns and feature interactions
• Device information and operating system
• Log data and analytics information
• Camera and photo library access (for food logging)
              ''',
            ),

            _buildSection(
              title: '2. How We Use Your Information',
              content: '''
We use the information we collect to provide, maintain, and improve our services:

Service Provision:
• Provide personalized nutrition and fitness recommendations
• Track your health and fitness progress
• Enable AI-powered coaching and suggestions
• Sync data across your devices

Communication:
• Send important updates about our services
• Provide customer support and respond to inquiries
• Send notifications about your health goals
• Share relevant tips and educational content

Improvement:
• Analyze usage patterns to improve our app
• Develop new features and services
• Conduct research and analytics
• Ensure app security and prevent fraud
              ''',
            ),

            _buildSection(
              title: '3. Information Sharing',
              content: '''
We do not sell, trade, or rent your personal information to third parties. We may share your information in the following limited circumstances:

Service Providers:
• Cloud storage providers (Firebase, Google Cloud)
• Analytics services (Google Analytics)
• AI service providers (Google Gemini API)
• Payment processors (if applicable)

Legal Requirements:
• When required by law or legal process
• To protect our rights and property
• To prevent fraud or security issues
• In case of business transfers or mergers

With Your Consent:
• When you explicitly authorize sharing
• For research purposes (anonymized data)
• For social features (if you choose to participate)
              ''',
            ),

            _buildSection(
              title: '4. Data Security',
              content: '''
We implement appropriate security measures to protect your personal information:

Technical Safeguards:
• Encryption of data in transit and at rest
• Secure authentication and access controls
• Regular security audits and updates
• Secure cloud infrastructure (Firebase)

Operational Safeguards:
• Limited access to personal information
• Employee training on data protection
• Incident response procedures
• Regular backup and recovery systems

Your Responsibility:
• Keep your login credentials secure
• Use strong, unique passwords
• Log out from shared devices
• Report any suspicious activity
              ''',
            ),

            _buildSection(
              title: '5. Your Rights and Choices',
              content: '''
You have certain rights regarding your personal information:

Access and Control:
• View and update your profile information
• Download your data in a portable format
• Delete your account and associated data
• Opt out of certain communications

Privacy Settings:
• Control what information is shared
• Manage notification preferences
• Adjust privacy and security settings
• Control camera and location permissions

Data Portability:
• Export your health and fitness data
• Transfer data to other health apps
• Request data deletion
• Object to certain data processing
              ''',
            ),

            _buildSection(
              title: '6. Children\'s Privacy',
              content: '''
Our services are not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.

If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately.

For users between 13-18:
• Parental consent may be required
• Limited data collection and sharing
• Enhanced privacy protections
• Special safeguards for minors
              ''',
            ),

            _buildSection(
              title: '7. International Data Transfers',
              content: '''
Your information may be transferred to and processed in countries other than your own.

Data Processing Locations:
• United States (primary processing location)
• European Union (GDPR compliance)
• Other countries where our service providers operate

Protection Measures:
• Standard contractual clauses
• Adequacy decisions by relevant authorities
• Appropriate safeguards for data transfers
• Compliance with applicable privacy laws
              ''',
            ),

            _buildSection(
              title: '8. Changes to This Policy',
              content: '''
We may update this Privacy Policy from time to time to reflect changes in our practices or applicable laws.

Notification of Changes:
• We will notify you of material changes
• Updates will be posted in the app
• Email notifications for significant changes
• Continued use constitutes acceptance

Your Rights:
• Review updated policies
• Object to changes if applicable
• Delete your account if you disagree
• Contact us with questions or concerns
              ''',
            ),

            _buildSection(
              title: '9. Contact Information',
              content: '''
If you have any questions about this Privacy Policy or our privacy practices, please contact us:

Email: privacy@calorievita.com
Address: Calorie Vita Privacy Team
123 Health Street, Wellness City, WC 12345

Response Time:
• We aim to respond within 48 hours
• Complex requests may take up to 30 days
• We will provide updates on request status
• Multiple contact methods available
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
