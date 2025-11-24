import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';

/// Privacy Policy Screen for Calorie Vita App
/// Comprehensive privacy policy with actual content
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? kDarkAppBackground : kAppBackground,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? kDarkTextPrimary : kTextDark,
          ),
        ),
        backgroundColor: isDark ? kDarkSurfaceLight : kSurfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? kDarkTextPrimary : kTextDark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? kDarkTextPrimary : kTextDark),
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
                    kAccentBlue.withOpacity(0.1),
                    kAccentPurple.withOpacity(0.1)
                  ],
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
                      color: isDark ? kDarkTextPrimary : kTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? kDarkTextSecondary : kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            _buildSection(
              context: context,
              title: '1. Information We Collect',
              content: '''
We collect various types of information in connection with your use of the Calorie Vita application to provide, improve, and personalize our services.

Personal Information You Provide:
• Account Information: Name, email address, password (encrypted), date of birth, and gender
• Health Profile Data: Height, weight, body measurements, fitness goals, target weight, and BMI
• Dietary Information: Food preferences, allergies, dietary restrictions, and nutritional goals
• User-Generated Content: Profile photos, food photos, notes, and journal entries
• Communication Data: Customer support inquiries, feedback, and survey responses

Automatically Collected Information:
• Device Information: Device model, operating system version, unique device identifiers, mobile network information
• Usage Data: App features accessed, interaction patterns, session duration, screen views, and navigation paths
• Location Data: Approximate location based on IP address (precise location only with explicit permission)
• Camera and Media Access: Photos captured or selected for food logging (processed locally and via AI services)
• Performance Data: Crash reports, error logs, diagnostic information, and app performance metrics

Health and Fitness Data:
• Activity Data: Steps, distance, calories burned, exercise duration (when integrated with Google Fit or Health Connect)
• Nutritional Intake: Food consumption, calorie intake, macronutrient breakdown, meal timing
• Progress Metrics: Weight changes, goal achievements, streak data, and behavioral patterns
• Biometric Data: Body measurements, BMI calculations, and other health metrics you choose to provide

Third-Party Integration Data:
• Google Fit and Health Connect data (steps, activity, calories burned)
• Wearable device synchronization data
• Social media profile information (if you choose to connect social accounts)
              ''',
            ),

            _buildSection(
              context: context,
              title: '2. How We Use Your Information',
              content: '''
We process your personal information for the following legitimate purposes, in accordance with applicable data protection laws:

Service Delivery and Functionality:
• Provide core app functionality including food tracking, calorie counting, and progress monitoring
• Generate personalized nutrition and fitness recommendations using AI-powered analysis
• Process and analyze food photographs for nutritional content identification
• Synchronize your data across multiple devices and platforms
• Maintain your account and authenticate your identity
• Enable social features and community interactions (if you opt-in)

AI-Powered Personalization:
• Utilize OpenRouter AI services to provide intelligent nutrition analysis and recommendations
• Generate personalized meal suggestions based on your dietary preferences and health goals
• Provide AI-driven coaching insights and behavioral pattern analysis
• Improve accuracy of food recognition and nutritional estimation algorithms

Communication and Support:
• Send transactional communications (account confirmations, password resets, critical updates)
• Provide customer support and respond to your inquiries and requests
• Send push notifications about goal progress, reminders, and achievements (with your consent)
• Deliver educational content, health tips, and wellness information (with your consent)
• Conduct user surveys and collect feedback to improve our services

Analytics and Improvement:
• Analyze usage patterns, trends, and user behavior to improve app functionality
• Conduct statistical analysis and research to develop new features
• Perform A/B testing to optimize user experience
• Monitor app performance, identify bugs, and resolve technical issues
• Generate anonymized and aggregated data for research and development

Security and Compliance:
• Detect, prevent, and respond to fraud, security threats, and unauthorized access
• Comply with legal obligations and regulatory requirements
• Enforce our Terms and Conditions and protect our legal rights
• Prevent abuse, harmful activity, and violations of our policies
• Maintain data integrity and system security
              ''',
            ),

            _buildSection(
              context: context,
              title: '3. Information Sharing and Disclosure',
              content: '''
We do not sell, rent, or trade your personal information to third parties for their marketing purposes. We may share your information only in the following limited circumstances:

Essential Service Providers (Data Processors):
• Cloud Infrastructure: Firebase (Google Cloud Platform) for secure data storage and synchronization
• AI Services: OpenRouter API for intelligent food recognition and nutrition analysis
• Analytics Platforms: Firebase Analytics and Google Analytics for app performance monitoring
• Authentication Services: Firebase Authentication and Google Sign-In for secure account access
• Crash Reporting: Firebase Crashlytics for error detection and app stability
• Push Notifications: Firebase Cloud Messaging for delivering timely alerts and reminders
• Payment Processors: [YOUR_PAYMENT_PROCESSOR - if applicable] for subscription billing

All service providers are contractually obligated to:
• Process data only on our instructions
• Implement appropriate security measures
• Delete or return data upon termination
• Comply with applicable data protection laws

Legal and Regulatory Compliance:
• Compliance with legal obligations, court orders, subpoenas, or regulatory requests
• Protection of our legal rights, property, and interests
• Investigation and prevention of fraud, security threats, or illegal activities
• Protection of user safety and prevention of harm
• Enforcement of our Terms and Conditions

Business Transfers:
• In connection with mergers, acquisitions, corporate restructuring, or asset sales
• Your data may be transferred as a business asset
• We will notify you of any such transfer
• Your privacy rights will continue to be protected

With Your Explicit Consent:
• Sharing with third-party health and fitness applications (when you authorize integration)
• Participation in research studies (with anonymized data and your explicit opt-in)
• Social features and community sharing (only information you choose to make public)
• Export of your data to other platforms (at your request)

Aggregated and Anonymized Data:
• We may share non-identifiable, aggregated, or anonymized data for research, analytics, and business purposes
• This data cannot be used to identify individual users
• Used for industry research, statistical analysis, and service improvement
              ''',
            ),

            _buildSection(
              context: context,
              title: '4. Data Security and Protection',
              content: '''
We implement comprehensive security measures designed to protect your personal information from unauthorized access, disclosure, alteration, and destruction.

Technical Security Measures:
• Encryption: All data transmitted between your device and our servers uses industry-standard TLS/SSL encryption
• Data at Rest: Personal information stored in Firebase is encrypted using AES-256 encryption
• Secure Authentication: Password-based authentication with bcrypt hashing and OAuth 2.0 for Google Sign-In
• Access Controls: Role-based access control (RBAC) and principle of least privilege for system access
• Network Security: Firewall protection, intrusion detection systems, and regular security monitoring
• Secure APIs: API authentication, rate limiting, and request validation to prevent abuse

Infrastructure Security:
• Cloud Security: Hosted on Google Cloud Platform (Firebase) with SOC 2, ISO 27001, and GDPR compliance
• Regular Backups: Automated daily backups with encrypted storage and disaster recovery procedures
• Security Updates: Continuous monitoring and timely application of security patches
• Penetration Testing: Regular security audits and vulnerability assessments
• Incident Response: 24/7 security monitoring with documented incident response procedures

Organizational Safeguards:
• Access Limitation: Personal data access restricted to authorized personnel with legitimate business needs
• Employee Training: Regular security and privacy training for all team members with data access
• Confidentiality Agreements: All personnel bound by strict confidentiality obligations
• Vendor Management: Security requirements for all third-party service providers
• Data Minimization: Collection and retention of only necessary personal information

User Security Responsibilities:
• Account Security: Maintain strong, unique passwords and enable two-factor authentication when available
• Device Security: Keep your device and operating system updated with latest security patches
• Network Caution: Avoid accessing your account on public or unsecured Wi-Fi networks
• Logout Practices: Always log out when using shared or public devices
• Suspicious Activity: Immediately report any unauthorized access or suspicious activity to support@calorievita.com

Data Breach Response:
• Notification: We will notify affected users within 72 hours of discovering a data breach (as required by law)
• Remediation: Immediate action to contain and remediate security incidents
• Investigation: Thorough investigation to determine cause, scope, and impact
• Prevention: Implementation of additional safeguards to prevent future incidents

Important Notice: While we implement robust security measures, no method of electronic transmission or storage is 100% secure. You acknowledge and accept the inherent security risks of internet-based services.
              ''',
            ),

            _buildSection(
              context: context,
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
              context: context,
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
              context: context,
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
              context: context,
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
              context: context,
              title: '9. Contact Information and Data Protection',
              content: '''
For questions, concerns, or requests regarding this Privacy Policy or our data processing practices, please contact us:

Email: calorievita@gmail.com

Types of Inquiries We Handle:
• General privacy inquiries and questions
• Data subject rights requests (access, deletion, portability)
• Privacy complaints and concerns
• Data protection matters
• GDPR/CCPA compliance questions

For Data Subject Rights Requests, please include in your email:
• Subject Line: "Data Rights Request - [Access/Deletion/Portability]"
• Your registered email address
• Specific details of your request
• Proof of identity for verification

Response Timeframes:
• General privacy inquiries: Within 48-72 business hours
• Data access requests: Within 30 days (as required by GDPR/CCPA)
• Data deletion requests: Within 30 days of verification
• Data portability requests: Within 30 days in machine-readable format
• Privacy complaints: Acknowledged within 48 hours, resolved within 30 days

Regulatory Authorities:
If you are not satisfied with our response to your privacy concern, you have the right to lodge a complaint with your local data protection authority or supervisory authority.

• EU Users: Contact your national Data Protection Authority
• California Users: Contact California Attorney General's Office
• Other Jurisdictions: Contact your applicable data protection regulator

Important Note: To protect your privacy and security, we will verify your identity before processing data rights requests. Please provide your registered email address and be prepared to verify account ownership.
              ''',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required BuildContext context, required String title, required String content}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              color: isDark ? kDarkTextPrimary : kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? kDarkSurfaceLight : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark 
                    ? kDarkBorderColor.withOpacity(0.3) 
                    : kTextSecondary.withOpacity(0.2),
              ),
            ),
            child: Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? kDarkTextPrimary : kTextDark,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
