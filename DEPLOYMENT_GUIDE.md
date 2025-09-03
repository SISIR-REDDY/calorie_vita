# Calorie Vita - Production Deployment Guide

## 🚀 Overview

This guide will help you deploy your Calorie Vita app to production with all features fully integrated and optimized for real-time performance.

## 📋 Pre-Deployment Checklist

### ✅ Core Features Integration
- [x] Centralized state management with AppStateService
- [x] Real-time data synchronization across all screens
- [x] Comprehensive error handling and offline support
- [x] Performance optimization with caching
- [x] Production-ready configuration

### ✅ Firebase Setup
- [x] Firebase project configured
- [x] Authentication enabled
- [x] Firestore database set up
- [x] Storage configured
- [x] Analytics enabled
- [x] Crashlytics configured

### ✅ Dependencies
- [x] All production dependencies added
- [x] Firebase services integrated
- [x] Performance monitoring tools
- [x] Offline support libraries

## 🔧 Configuration Steps

### 1. Firebase Configuration

#### Update Firebase Options
```dart
// lib/firebase_options.dart
// Ensure your production Firebase project is configured
```

#### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

#### Storage Security Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 2. Environment Configuration

#### Update Deployment Config
```dart
// lib/config/deployment_config.dart
static const bool isProduction = true;
static const bool enableDebugMode = false;
static const bool enableAnalytics = true;
static const bool enableCrashReporting = true;
```

### 3. API Keys Configuration

#### Gemini API Key
```dart
// lib/services/gemini_service.dart
// Replace with your actual Gemini API key
static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

#### OpenRouter API Key (for Sisir)
```dart
// lib/services/sisir_service.dart
// Replace with your actual OpenRouter API key
static const String _openRouterApiKey = 'YOUR_OPENROUTER_API_KEY_HERE';
```

## 🏗️ Build Configuration

### Android Build

#### Update android/app/build.gradle.kts
```kotlin
android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.calorievita.app"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### Signing Configuration
```kotlin
// android/app/build.gradle.kts
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

### iOS Build

#### Update ios/Runner/Info.plist
```xml
<key>CFBundleDisplayName</key>
<string>Calorie Vita</string>
<key>CFBundleVersion</key>
<string>1.0.0</string>
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
```

## 🚀 Deployment Commands

### 1. Clean and Get Dependencies
```bash
flutter clean
flutter pub get
```

### 2. Build for Production

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle (Recommended for Play Store)
```bash
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

### 3. Test Production Build
```bash
# Test on device
flutter install --release

# Run integration tests
flutter test integration_test/
```

## 📱 App Store Deployment

### Google Play Store

1. **Create App Bundle**
   ```bash
   flutter build appbundle --release
   ```

2. **Upload to Play Console**
   - Go to Google Play Console
   - Create new app
   - Upload the generated .aab file
   - Fill in store listing details
   - Submit for review

### Apple App Store

1. **Build for iOS**
   ```bash
   flutter build ios --release
   ```

2. **Archive in Xcode**
   - Open ios/Runner.xcworkspace in Xcode
   - Select "Any iOS Device" as target
   - Product → Archive
   - Upload to App Store Connect

## 🔍 Monitoring and Analytics

### Firebase Analytics
- User engagement tracking
- Feature usage analytics
- Performance monitoring
- Custom event tracking

### Crashlytics
- Crash reporting
- Performance monitoring
- User session tracking

### Custom Analytics
```dart
// Track custom events
FirebaseAnalytics.instance.logEvent(
  name: 'food_entry_added',
  parameters: {
    'calories': calories,
    'food_type': foodType,
  },
);
```

## 🛡️ Security Considerations

### Data Protection
- All user data encrypted in transit
- Local data encrypted at rest
- Secure API key management
- User authentication required

### Privacy Compliance
- GDPR compliance
- Data retention policies
- User consent management
- Privacy policy implementation

## 🔧 Performance Optimization

### Caching Strategy
- Memory caching for frequently accessed data
- Local storage for offline support
- Image caching and optimization
- Database query optimization

### Network Optimization
- Request batching
- Offline-first architecture
- Retry mechanisms with exponential backoff
- Connection monitoring

## 📊 Monitoring Dashboard

### Key Metrics to Monitor
- App crashes and errors
- User engagement
- Feature adoption
- Performance metrics
- API response times

### Alerts Setup
- Crash rate > 1%
- API error rate > 5%
- App startup time > 3 seconds
- Memory usage > 80%

## 🚨 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

#### Firebase Connection Issues
- Verify firebase_options.dart
- Check internet connectivity
- Validate API keys
- Review Firestore security rules

#### Performance Issues
- Enable performance monitoring
- Check memory usage
- Optimize image loading
- Review database queries

## 📞 Support

### Contact Information
- Email: support@calorievita.com
- Documentation: [Link to docs]
- Issue Tracker: [Link to GitHub issues]

### Emergency Contacts
- Technical Lead: [Contact info]
- DevOps Team: [Contact info]
- Product Manager: [Contact info]

## 🎯 Post-Deployment

### Immediate Actions
1. Monitor app performance
2. Check error logs
3. Verify analytics data
4. Test critical user flows

### First Week Monitoring
1. User feedback collection
2. Performance metrics review
3. Crash report analysis
4. Feature usage statistics

### Ongoing Maintenance
1. Regular security updates
2. Performance optimization
3. Feature enhancements
4. Bug fixes and improvements

---

## 🎉 Congratulations!

Your Calorie Vita app is now ready for production deployment with:
- ✅ Fully integrated real-time features
- ✅ Comprehensive error handling
- ✅ Offline support
- ✅ Performance optimization
- ✅ Production-ready configuration
- ✅ Security best practices
- ✅ Monitoring and analytics

The app is now a fully functional, production-ready calorie tracking application with all features interconnected and optimized for real-time performance!
