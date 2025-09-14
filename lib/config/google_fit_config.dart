/// Google Fit Configuration
/// 
/// This file contains configuration settings for Google Fit integration.
/// Follow the setup instructions to configure Google Fit API access.
library;

class GoogleFitConfig {
  /// Google Fit API Configuration
  /// 
  /// To use Google Fit integration, you need to:
  /// 1. Create a Google Cloud Project
  /// 2. Enable the Fitness API
  /// 3. Create OAuth 2.0 credentials
  /// 4. Configure the Android app
  
  /// Google Cloud Project Configuration
  /// Replace with your actual project details
  static const String projectId = 'calorie-vita';
  static const String clientId = '868343457049-ferbh43bj0pahp1b1ghh8hkkerakic9i.apps.googleusercontent.com';
  
  /// Your SHA-1 fingerprint (from logs)
  static const String sha1Fingerprint = 'fc8f2fd7b4c4072afe837b115676feaf70fc7cfd';
  
  /// API Scopes for Google Fit
  static const List<String> requiredScopes = [
    'https://www.googleapis.com/auth/fitness.activity.read',
    'https://www.googleapis.com/auth/fitness.body.read',
    'https://www.googleapis.com/auth/fitness.location.read',
  ];
  
  /// Google Fit Data Types
  static const Map<String, String> dataTypes = {
    'steps': 'com.google.step_count.delta',
    'calories': 'com.google.calories.expended',
    'distance': 'com.google.distance.delta',
    'weight': 'com.google.weight',
    'height': 'com.google.height',
    'heartRate': 'com.google.heart_rate.bpm',
    'sleep': 'com.google.sleep.segment',
  };
  
  /// Data Source IDs for Google Fit
  static const Map<String, String> dataSources = {
    'steps': 'derived:com.google.step_count.delta:com.google.android.gms:estimated_steps',
    'calories': 'derived:com.google.calories.expended:com.google.android.gms:merge_calories_expended',
    'distance': 'derived:com.google.distance.delta:com.google.android.gms:merge_distance_delta',
  };
  
  /// Setup Instructions
  static const String setupInstructions = '''
Google Fit Integration Setup Instructions:

1. Google Cloud Console Setup:
   - Go to https://console.cloud.google.com/
   - Create a new project or select existing one
   - Enable the "Fitness API"
   - Go to "Credentials" and create OAuth 2.0 Client ID
   - Add your Android package name: com.sisirlabs.calorievita
   - Add SHA-1 fingerprint from your debug keystore

2. Android Configuration:
   - Update google-services.json with your project configuration
   - Ensure all required permissions are in AndroidManifest.xml
   - Test with debug build first

3. Flutter Configuration:
   - Update GoogleFitConfig with your client ID
   - Test authentication flow
   - Verify data retrieval

4. Production Setup:
   - Create release keystore
   - Add release SHA-1 fingerprint to Google Cloud Console
   - Update google-services.json for production
   - Test on physical device

Note: Google Fit requires physical device for testing.
''';
  
  /// Debug Settings
  static const bool enableDebugLogs = true;
  static const bool enableApiResponseLogging = false;
  
  /// Rate Limiting
  static const int maxRequestsPerMinute = 100;
  static const Duration requestTimeout = Duration(seconds: 30);
}
