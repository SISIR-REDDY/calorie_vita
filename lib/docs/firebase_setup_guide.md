# Firebase Setup Guide - Calorie Vita App

## Overview
This guide will help you set up Firebase for the Calorie Vita app with proper database structure, security rules, and configuration.

## Prerequisites
- Firebase project created
- Flutter project configured
- Android/iOS app registered in Firebase Console

## Step 1: Firebase Project Setup

### 1.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `calorie-vita`
4. Enable Google Analytics (recommended)
5. Choose Analytics account or create new one

### 1.2 Configure Authentication
1. Go to Authentication > Sign-in method
2. Enable the following providers:
   - **Email/Password**: Enable
   - **Google**: Enable and configure
   - **Anonymous**: Enable (for demo mode)

### 1.3 Configure Firestore Database
1. Go to Firestore Database
2. Click "Create database"
3. Choose "Start in test mode" (we'll update rules later)
4. Select location closest to your users

### 1.4 Configure Storage
1. Go to Storage
2. Click "Get started"
3. Choose "Start in test mode" (we'll update rules later)
4. Select same location as Firestore

## Step 2: Security Rules Setup

### 2.1 Firestore Rules
1. Go to Firestore Database > Rules
2. Replace the default rules with the content from `firestore.rules`
3. Click "Publish"

### 2.2 Storage Rules
1. Go to Storage > Rules
2. Replace the default rules with the content from `storage.rules`
3. Click "Publish"

## Step 3: Database Indexes

### 3.1 Create Composite Indexes
Go to Firestore Database > Indexes and create the following:

1. **Collection**: `users/{userId}/entries`
   - Fields: `timestamp` (Descending)

2. **Collection**: `users/{userId}/dailySummaries`
   - Fields: `date` (Descending)

3. **Collection**: `users/{userId}/achievements`
   - Fields: `unlockedAt` (Descending)

4. **Collection**: `users/{userId}/trainerChats`
   - Fields: `timestamp` (Descending)

## Step 4: App Configuration

### 4.1 Update Firebase Options
1. Update `lib/firebase_options.dart` with your project configuration
2. Replace placeholder values with actual Firebase project details

### 4.2 Android Configuration
1. Download `google-services.json` from Firebase Console
2. Place it in `android/app/` directory
3. Ensure `android/app/build.gradle.kts` includes:
   ```kotlin
   plugins {
       id("com.google.gms.google-services")
   }
   ```

### 4.3 Web Configuration
1. Go to Project Settings > General > Your apps
2. Add web app if not already added
3. Copy the configuration and update `lib/firebase_options.dart`

## Step 5: Environment Variables

### 5.1 Create Environment File
Create `lib/config/environment.dart`:
```dart
class Environment {
  static const String firebaseProjectId = 'calorie-vita';
  static const String firebaseApiKey = 'YOUR_API_KEY';
  static const String firebaseAppId = 'YOUR_APP_ID';
  static const String firebaseMessagingSenderId = 'YOUR_SENDER_ID';
  static const String firebaseStorageBucket = 'calorie-vita.firebasestorage.app';
  static const String firebaseAuthDomain = 'calorie-vita.firebaseapp.com';
}
```

## Step 6: Database Initialization

### 6.1 Run Initial Setup
The app will automatically:
1. Initialize Firebase services
2. Run database migrations
3. Validate database structure
4. Create user data structure for new users

### 6.2 Manual Database Setup (Optional)
If you need to manually set up the database:

1. **Create App Configuration**:
   ```javascript
   // Run in Firebase Console > Firestore
   db.collection('app_config').doc('settings').set({
     version: '1.0.0',
     minSupportedVersion: '1.0.0',
     features: {
       aiTrainer: true,
       barcodeScanning: true,
       healthIntegration: true,
       premiumFeatures: true
     },
     limits: {
       maxFoodEntriesPerDay: 50,
       maxChatMessagesPerSession: 100,
       maxImageSizeMB: 10
     },
     analytics: {
       enabled: true,
       retentionDays: 365
     },
     lastUpdated: new Date()
   });
   ```

## Step 7: Testing

### 7.1 Test Authentication
1. Run the app
2. Try creating an account
3. Verify user document is created in Firestore
4. Check user subcollections are created

### 7.2 Test Data Operations
1. Add a food entry
2. Set user goals
3. Update preferences
4. Verify data is saved correctly

### 7.3 Test Security Rules
1. Try accessing another user's data (should fail)
2. Verify file upload restrictions work
3. Test offline functionality

## Step 8: Monitoring and Analytics

### 8.1 Enable Monitoring
1. Go to Firebase Console > Performance
2. Enable Performance Monitoring
3. Add custom traces in your app

### 8.2 Configure Analytics
1. Go to Analytics > Events
2. Set up custom events for:
   - Food entries added
   - Goals achieved
   - AI trainer interactions
   - App crashes

### 8.3 Set up Alerts
1. Go to Firebase Console > Functions > Monitoring
2. Set up alerts for:
   - High error rates
   - Unusual activity patterns
   - Storage usage spikes

## Step 9: Production Deployment

### 9.1 Update Security Rules
1. Review and test all security rules
2. Enable production mode
3. Remove test data

### 9.2 Configure Backup
1. Go to Firestore > Backup
2. Enable automated backups
3. Set retention period

### 9.3 Set up Monitoring
1. Configure Cloud Monitoring
2. Set up log aggregation
3. Create dashboards

## Troubleshooting

### Common Issues

1. **Firebase not initializing**:
   - Check `google-services.json` is in correct location
   - Verify package name matches Firebase project
   - Check internet connectivity

2. **Permission denied errors**:
   - Verify security rules are deployed
   - Check user authentication status
   - Ensure user has proper permissions

3. **Data not syncing**:
   - Check Firestore indexes are created
   - Verify network connectivity
   - Check for quota limits

4. **Storage upload failures**:
   - Verify storage rules are correct
   - Check file size limits
   - Ensure proper file types

### Debug Mode
Enable debug logging by setting:
```dart
FirebaseFirestore.setLoggingEnabled(true);
```

## Security Best Practices

1. **Never expose API keys** in client code
2. **Use security rules** to protect data
3. **Validate all inputs** on both client and server
4. **Implement rate limiting** for API calls
5. **Regular security audits** of rules and data access
6. **Monitor for suspicious activity**
7. **Keep dependencies updated**

## Performance Optimization

1. **Use pagination** for large collections
2. **Implement caching** for frequently accessed data
3. **Optimize queries** with proper indexes
4. **Use batch operations** for multiple writes
5. **Monitor query performance** in Firebase Console

## Backup and Recovery

1. **Enable automated backups**
2. **Test restore procedures** regularly
3. **Export data** for compliance requirements
4. **Document recovery procedures**

## Support

For additional help:
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Support](https://firebase.google.com/support)
