# Firebase Setup Guide for Calorie Vita

This guide will help you set up Firebase for your Calorie Vita app so that user authentication and data storage work properly.

## 🔥 Why Firebase Setup is Needed

Currently, your app is using placeholder Firebase credentials, which means:
- ❌ User login fails to store data
- ❌ User data isn't processed or saved
- ❌ Authentication doesn't work properly
- ❌ App can't connect to Firebase services

## 📋 Prerequisites

1. **Google Account** - You'll need a Google account to access Firebase Console
2. **Flutter Project** - Your Calorie Vita project should be ready
3. **FlutterFire CLI** - We'll install this to configure Firebase

## 🚀 Step-by-Step Setup

### Step 1: Install FlutterFire CLI

```bash
# Install FlutterFire CLI globally
dart pub global activate flutterfire_cli

# Verify installation
flutterfire --version
```

### Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"**
3. Enter project name: `calorie-vita` (or your preferred name)
4. Enable Google Analytics (optional but recommended)
5. Click **"Create project"**

### Step 3: Add Android App to Firebase

1. In Firebase Console, click **"Add app"** → **Android**
2. Enter your package name: `com.sisirlabs.calorievita`
3. Enter app nickname: `Calorie Vita Android`
4. Click **"Register app"**
5. Download the `google-services.json` file
6. Place it in `android/app/` directory

### Step 4: Add iOS App to Firebase (if needed)

1. In Firebase Console, click **"Add app"** → **iOS**
2. Enter your bundle ID: `com.sisirlabs.calorievita`
3. Enter app nickname: `Calorie Vita iOS`
4. Click **"Register app"**
5. Download the `GoogleService-Info.plist` file
6. Place it in `ios/Runner/` directory

### Step 5: Configure Firebase Services

1. **Enable Authentication:**
   - Go to **Authentication** → **Sign-in method**
   - Enable **Email/Password** provider
   - Click **"Save"**

2. **Enable Firestore Database:**
   - Go to **Firestore Database**
   - Click **"Create database"**
   - Choose **"Start in test mode"** (for development)
   - Select a location (choose closest to your users)
   - Click **"Done"**

3. **Enable Storage (optional):**
   - Go to **Storage**
   - Click **"Get started"**
   - Choose **"Start in test mode"**
   - Select a location
   - Click **"Done"**

### Step 6: Configure Flutter App

Run this command in your project directory:

```bash
# Configure Firebase for your Flutter app
flutterfire configure
```

This will:
- Automatically detect your Firebase project
- Generate the `firebase_options.dart` file with real credentials
- Update your `pubspec.yaml` if needed

### Step 7: Update Android Configuration

1. Open `android/app/build.gradle`
2. Add this line at the top:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

3. Open `android/build.gradle`
4. Add this in the dependencies:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.3.15'
   }
   ```

### Step 8: Test Firebase Connection

1. Run your app:
   ```bash
   flutter run
   ```

2. Try to sign up with a test email
3. Check Firebase Console → Authentication to see if user was created
4. Check Firestore Database to see if user data is stored

## 🔧 Troubleshooting

### Common Issues:

1. **"Firebase not configured" error:**
   - Make sure `google-services.json` is in `android/app/`
   - Run `flutter clean && flutter pub get`

2. **Authentication not working:**
   - Check if Email/Password is enabled in Firebase Console
   - Verify your package name matches Firebase project

3. **Build errors:**
   - Make sure all Firebase dependencies are in `pubspec.yaml`
   - Run `flutter pub get`

### Verification Checklist:

- [ ] Firebase project created
- [ ] Android app added to Firebase
- [ ] `google-services.json` downloaded and placed correctly
- [ ] `flutterfire configure` completed successfully
- [ ] Authentication enabled in Firebase Console
- [ ] Firestore Database created
- [ ] App builds and runs without errors
- [ ] User can sign up and data is stored

## 🎯 After Setup

Once Firebase is properly configured:

1. **User Authentication** will work properly
2. **User data** will be stored in Firestore
3. **Login details** will be processed and saved
4. **App will work** in production mode

## 📱 Demo Mode vs Production

- **Demo Mode**: Works without Firebase (current state)
- **Production Mode**: Requires proper Firebase setup

The app automatically falls back to demo mode when Firebase is not configured, but for full functionality, you need to complete the Firebase setup.

## 🆘 Need Help?

If you encounter issues:

1. Check the [Firebase Documentation](https://firebase.google.com/docs/flutter/setup)
2. Verify your `firebase_options.dart` has real credentials (not placeholders)
3. Make sure all files are in the correct locations
4. Run `flutter clean && flutter pub get` after changes

---

**Note**: This setup is required for the app to store and process user login details properly. Without it, the app will continue to work in demo mode but won't persist user data.
