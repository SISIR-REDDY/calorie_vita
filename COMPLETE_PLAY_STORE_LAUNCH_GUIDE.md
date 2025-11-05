# 🚀 Complete Play Store Launch Guide - Calorie Vita

## 📋 Overview

**Total Time:** 2-3 hours  
**Cost:** $25 one-time Google Play Developer registration fee  
**App Status:** 95% Production Ready ✅

This guide covers everything you need to launch your Calorie Vita app on Google Play Store, including all APIs, Firebase services, and external dependencies.

---

## 🎯 STEP 1: Generate Production Keystore (5 minutes)

### Why This is Critical
- **Play Store Requirement:** All apps must be signed with a production key
- **Permanent Key:** You'll use this same key for ALL future updates
- **Security:** If you lose this key, you CANNOT update your app on Play Store

### How to Generate

**Option A: Automated Script (Recommended)**
```powershell
.\generate_keystore.ps1
```

**What You'll Need:**
- Keystore password (min 6 characters) - **SAVE THIS FOREVER!**
- Key password (can be same as keystore password)
- Your name, organization, city, state, country code (2 letters)

**Output:**
- `android/calorie-vita-release.jks` - Your keystore file
- `android/key.properties` - Auto-generated configuration

**Option B: Manual Method**
```bash
keytool -genkey -v -keystore android/calorie-vita-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias calorie-vita
```

### ✅ Critical Checklist
- [ ] Keystore file generated: `android/calorie-vita-release.jks`
- [ ] Key properties created: `android/key.properties`
- [ ] **BACKED UP keystore** to secure location (USB drive, cloud storage)
- [ ] **SAVED passwords** securely - you'll need them forever!
- [ ] **NEVER commit** keystore or key.properties to Git

---

## 🏗️ STEP 2: Build Production Release (10-15 minutes)

### Build Command

**Option A: Automated Script (Recommended)**
```powershell
.\launch_production.ps1
```

**Option B: Manual Method**
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Output Location
- **File:** `build/app/outputs/bundle/release/app-release.aab`
- **Expected Size:** ~25-35 MB (optimized with ProGuard)

### ✅ Build Checklist
- [ ] Build completed successfully
- [ ] No errors or warnings
- [ ] App bundle exists: `app-release.aab`
- [ ] Bundle size is reasonable (< 50 MB)

---

## 🧪 STEP 3: Test Release Build (30-60 minutes)

### Build Test APK
```bash
flutter build apk --release
```

### Install on Device
```bash
flutter install --release
```

Or manually install from: `build/app/outputs/flutter-apk/app-release.apk`

### Test All Features

#### Core Features
- [ ] App launches successfully
- [ ] User authentication (Google Sign-In)
- [ ] Firebase authentication works
- [ ] User can create account and login

#### Camera & Food Recognition
- [ ] Camera permission requested correctly
- [ ] Can take photo of food
- [ ] AI food recognition works (OpenRouter API)
- [ ] Food details displayed correctly
- [ ] Can save food entry

#### Barcode Scanning
- [ ] Barcode scanner works
- [ ] Can scan product barcodes
- [ ] Product information loads from databases:
  - [ ] Open Food Facts
  - [ ] Local Indian dataset
  - [ ] UPCitemdb (if available)
  - [ ] GTINsearch (if available)
- [ ] Can save barcode-scanned items

#### Firebase Integration
- [ ] Data syncs to Firestore
- [ ] User profile saved correctly
- [ ] Food entries stored in Firebase
- [ ] Daily summaries update
- [ ] Analytics events tracked
- [ ] Crashlytics working (if errors occur)

#### AI Features (OpenRouter API)
- [ ] AI config loads from Firestore
- [ ] Chat with Trainer Sisir works
- [ ] Vision model recognizes food
- [ ] API key configured in Firestore (`app_config/ai_settings/openrouter_api_key`)

#### Google Fit Integration
- [ ] Google Fit connection works
- [ ] Can sync steps, calories, etc.
- [ ] Health data displays correctly

#### Offline Functionality
- [ ] App works without internet
- [ ] Data syncs when connection restored
- [ ] Graceful error handling

### ✅ Testing Checklist
- [ ] Tested on physical Android device
- [ ] All core features working
- [ ] No crashes or critical errors
- [ ] Performance is smooth
- [ ] All APIs and services working

---

## 🎨 STEP 4: Prepare Play Store Assets (30-60 minutes)

### Required Assets

#### 1. App Icon ✅ (Already Have)
- **File:** `calorie_logo.png` (512x512 PNG)
- **Status:** ✅ Ready to use

#### 2. Feature Graphic ⚠️ (Need to Create)
- **Size:** 1024x500 PNG
- **Content:** 
  - App name: "Calorie Vita"
  - Tagline: "AI-Powered Calorie Tracking"
  - Key features: Camera scan, Barcode scan, AI recognition
- **Tools:** Canva, Figma, Photoshop, or any design tool

#### 3. Screenshots ⚠️ (Need to Create)
- **Quantity:** Minimum 2, recommended 4-6
- **Format:** Phone screenshots (portrait or landscape)
- **Required Screenshots:**
  1. Home screen with food log
  2. Camera/food photo scanning
  3. Barcode scanning
  4. AI Trainer chat
  5. Analytics/daily summary
  6. Settings/profile

**How to Get Screenshots:**
1. Run app on device
2. Navigate to each key screen
3. Take screenshots (Power + Volume Down)
4. Optionally add captions using design tools

#### 4. Short Description ⚠️ (Need to Write)
- **Max:** 80 characters
- **Example:** "AI-powered calorie tracking with food photo recognition"
- **Tips:** Include keywords: calorie, tracking, AI, food, nutrition

#### 5. Full Description ⚠️ (Need to Write)
- **Max:** 4000 characters
- **Recommended Structure:**

```
Calorie Vita - AI-Powered Calorie Tracking Made Simple

Track your calories effortlessly with AI-powered food recognition. 
Simply snap a photo of your meal and let our advanced AI identify 
it automatically!

🌟 KEY FEATURES:

📸 AI Food Recognition
Take a photo of your food and our AI instantly identifies it, 
calculates calories, and tracks your nutrition.

📊 Barcode Scanning
Scan product barcodes to quickly log packaged foods with accurate 
nutrition information.

🤖 AI Personal Trainer
Chat with your AI trainer "Sisir" for personalized nutrition advice 
and meal recommendations.

📈 Daily Analytics
Track your daily calories, macros (carbs, protein, fat), and progress 
towards your goals.

🔥 Google Fit Integration
Sync your activity data from Google Fit to get a complete picture of 
your health.

☁️ Cloud Sync
Your data syncs across all your devices using Firebase, so you never 
lose your progress.

📱 OFFLINE MODE
Track calories even without internet. Your data syncs automatically 
when you're back online.

🎯 SET ACHIEVEMENTS
Unlock achievements and track your streaks to stay motivated!

---

Perfect for anyone looking to:
- Track calories easily
- Monitor nutrition and macros
- Get AI-powered meal recommendations
- Sync with Google Fit
- Set and achieve fitness goals

Download now and start your journey to better health! 🚀
```

### ✅ Assets Checklist
- [ ] App icon ready (512x512 PNG)
- [ ] Feature graphic created (1024x500 PNG)
- [ ] Screenshots prepared (2-8 images)
- [ ] Short description written (80 chars max)
- [ ] Full description written (4000 chars max)

---

## 📜 STEP 5: Create Legal Documents (30-60 minutes)

### Why Required
Your app uses Firebase (data collection), Google Sign-In, Google Fit, and external APIs, so you MUST have:
- Privacy Policy (REQUIRED)
- Terms of Service (Recommended)
- Data Safety Declaration (In Play Console)

### 1. Privacy Policy ⚠️ (REQUIRED)

**Required Content:**

```
PRIVACY POLICY FOR CALORIE VITA

Last Updated: [Date]

1. INFORMATION WE COLLECT

We collect the following information to provide and improve our services:

User Account Information:
- Email address (for authentication)
- Display name
- Profile photo (optional)

Health & Fitness Data:
- Food entries and calorie logs
- Daily nutrition summaries
- Weight and body measurements (if entered)
- Activity data from Google Fit (if connected)

App Usage Data:
- App analytics (features used, session duration)
- Crash reports (to improve app stability)
- Performance metrics

Device Information:
- Device model, OS version
- Unique device identifiers
- IP address

2. HOW WE USE YOUR INFORMATION

- Provide app functionality (calorie tracking, AI recommendations)
- Sync data across your devices
- Improve app performance and fix bugs
- Send you app updates and notifications
- Analyze app usage to improve features

3. DATA STORAGE & SECURITY

Your data is stored securely using:
- Firebase (Google Cloud Platform)
- Encrypted connections (HTTPS)
- Secure authentication (Firebase Auth)

4. THIRD-PARTY SERVICES

We use the following third-party services:
- Firebase (Google) - Authentication, database, analytics
- OpenRouter API - AI food recognition and chat
- Google Sign-In - User authentication
- Google Fit - Health data integration
- Open Food Facts - Product database
- UPCitemdb, GTINsearch - Barcode lookup services

5. YOUR RIGHTS

You have the right to:
- Access your data
- Delete your account and data
- Opt out of analytics (via device settings)
- Contact us with privacy concerns

6. DATA RETENTION

We retain your data as long as your account is active. 
You can delete your account at any time from Settings.

7. CONTACT US

For privacy questions, contact: [Your Email]
Privacy Policy URL: [Your Hosted URL]
```

**Hosting Options:**
1. **Firebase Hosting** (Recommended - free)
2. **GitHub Pages** (Free)
3. **Your own website**
4. **Privacy Policy Generator** (e.g., privacypolicygenerator.info)

**You'll need the URL for Play Store!**

### 2. Terms of Service ⚠️ (Recommended)

**Required Content:**

```
TERMS OF SERVICE FOR CALORIE VITA

Last Updated: [Date]

1. ACCEPTANCE OF TERMS

By using Calorie Vita, you agree to these terms.

2. USE OF THE APP

- You must be 13+ years old to use this app
- You are responsible for maintaining account security
- You agree not to misuse the app or APIs

3. HEALTH DISCLAIMER

- Calorie and nutrition data are estimates
- Not a substitute for professional medical advice
- Consult healthcare professionals for health decisions

4. THIRD-PARTY SERVICES

We use third-party APIs and services:
- OpenRouter API for AI features
- Firebase for data storage
- Google services for authentication
- Food databases (Open Food Facts, etc.)

5. LIMITATION OF LIABILITY

- We are not liable for health decisions based on app data
- API availability depends on third-party services
- We strive for accuracy but cannot guarantee it

6. CONTACT

For questions: [Your Email]
```

### 3. Data Safety Form (In Play Console)

You'll complete this directly in Play Console (Step 6).

### ✅ Legal Documents Checklist
- [ ] Privacy Policy created and hosted (URL ready)
- [ ] Terms of Service created and hosted (URL ready)
- [ ] Both documents include all required sections
- [ ] Contact email added to both documents

---

## 🏪 STEP 6: Google Play Console Setup (30-60 minutes)

### 6.1. Create Google Play Developer Account

1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with your Google account
3. **Pay $25 one-time registration fee** (credit/debit card)
4. Complete developer profile:
   - Developer name: "SISIR Labs" (or your organization name)
   - Email address
   - Phone number
   - Address

### 6.2. Create App Listing

1. Click **"Create app"** button
2. Fill in app details:
   - **App name:** "Calorie Vita"
   - **Default language:** English (United States)
   - **App type:** App (not Game)
   - **Free or paid:** Free
   - **Privacy policy:** Select **"Yes"** (you'll add URL later)
   - **Government app:** No
3. Check box: "I understand that I need to complete all required sections..."
4. Click **"Create app"**

### 6.3. Upload App Bundle

1. Go to **"Release"** → **"Production"** (or **"Internal testing"** first)
2. Click **"Create new release"**
3. Upload your app bundle:
   - Click **"Upload"**
   - Select: `build/app/outputs/bundle/release/app-release.aab`
4. Add **Release notes** (what's new):
   ```
   🎉 Calorie Vita v1.0.0 - Initial Release!
   
   ✨ Features:
   - AI-powered food recognition from photos
   - Barcode scanning for packaged foods
   - AI personal trainer chat
   - Daily calorie and nutrition tracking
   - Google Fit integration
   - Cloud sync across devices
   - Offline mode support
   ```
5. Click **"Save"** (NOT "Review release" yet)

### 6.4. Complete Store Listing

Go to **"Store presence"** → **"Main store listing"**

#### Required Information:

1. **App icon**
   - Upload: `calorie_logo.png` (512x512 PNG)
   - Must be 512x512 pixels

2. **Feature graphic**
   - Upload your 1024x500 feature graphic
   - Must be exactly 1024x500 pixels

3. **Screenshots**
   - Upload 2-8 phone screenshots
   - At least 2 required
   - Recommended: 4-6 screenshots

4. **Short description**
   - Max 80 characters
   - Example: "AI-powered calorie tracking with food photo recognition"

5. **Full description**
   - Max 4000 characters
   - Use the description you wrote in Step 4

6. **Privacy policy URL**
   - Enter your hosted privacy policy URL
   - Must be publicly accessible
   - Example: `https://yourdomain.com/privacy-policy`

7. **App category**
   - **Primary:** Health & Fitness
   - **Secondary:** (Optional)

8. **Contact details**
   - **Email:** Your support email
   - **Website:** (Optional) Your website URL
   - **Phone:** (Optional)

9. **Default language**
   - English (United States)

10. Click **"Save"**

### 6.5. Complete Content Rating

1. Go to **"Policy"** → **"App content"**
2. Click **"Start questionnaire"**
3. Answer questions:
   - **Category:** Health & Fitness
   - **Content:** None (no sensitive content)
   - **User-generated content:** No
   - **Social features:** No
   - **Location sharing:** Optional (for Google Fit)
   - **Health information:** Yes (calorie tracking)
4. Complete questionnaire
5. Get rating certificate (usually automatic)
6. Click **"Save"**

### 6.6. Complete Data Safety Form

1. Go to **"Policy"** → **"Data safety"**
2. Click **"Start"**
3. Answer questions about data collection:

#### Data Collection Questions:

**Q: Does your app collect or share any of the required user data types?**
- **Answer: Yes**

**Q: What data types do you collect?**

**Location (Optional):**
- ✅ Approximate location
- **Purpose:** Google Fit integration
- **Shared:** Yes (with Google/Firebase)

**Personal info:**
- ✅ User IDs (email, Firebase Auth ID)
- **Purpose:** Account creation, authentication
- **Shared:** Yes (with Firebase/Google)

**Health & fitness:**
- ✅ Health info (food logs, calorie data, weight)
- **Purpose:** App core functionality
- **Shared:** No

**App activity:**
- ✅ App interactions (features used, analytics)
- **Purpose:** Improve app, fix bugs
- **Shared:** Yes (with Firebase Analytics)

**Device or other IDs:**
- ✅ Device IDs (for analytics)
- **Purpose:** Analytics, crash reporting
- **Shared:** Yes (with Firebase)

**Photos and videos:**
- ✅ Photos (food photos for recognition)
- **Purpose:** Core app functionality
- **Shared:** Yes (with OpenRouter API for AI)

#### Data Security:
- ✅ Data encrypted in transit (HTTPS)
- ✅ Data encrypted at rest (Firebase)
- ✅ Users can request data deletion

#### Data Sharing:
- ✅ Shared with Google (Firebase, Analytics)
- ✅ Shared with OpenRouter (AI processing)
- ✅ Shared with food databases (Open Food Facts, etc.)

4. Review and **"Save"**

### 6.7. App Access (Declare APIs)

Since your app uses:
- **Camera API** - Required for food photos
- **Google Sign-In API** - Required for authentication
- **Google Fit API** - Required for health data
- **External APIs** - OpenRouter, food databases

**Action Required:**
1. Go to **"App content"** → **"App access"**
2. Declare all APIs and permissions
3. Justify why each permission is needed:
   - **Camera:** Required for food photo recognition
   - **Location:** Optional, for Google Fit integration
   - **Storage:** Required for saving food photos

### ✅ Play Console Checklist
- [ ] Google Play Developer account created ($25 paid)
- [ ] App listing created
- [ ] App bundle uploaded (app-release.aab)
- [ ] Store listing completed (icon, graphics, screenshots, descriptions)
- [ ] Privacy policy URL added
- [ ] Content rating obtained
- [ ] Data safety form completed
- [ ] App access/permissions declared

---

## ✅ STEP 7: Submit for Review (5 minutes)

### Pre-Submission Checklist

Before submitting, verify:
- [ ] All required fields completed
- [ ] Assets uploaded (icon, feature graphic, screenshots)
- [ ] Legal documents linked (privacy policy)
- [ ] Data safety form completed
- [ ] Content rating obtained
- [ ] App tested on physical device
- [ ] No errors shown in Play Console
- [ ] Release notes added

### Submit for Review

1. Go to **"Release"** → **"Production"** (or your chosen track)
2. Review your release:
   - App bundle version
   - Release notes
   - All requirements met
3. Click **"Start rollout to Production"** (or **"Submit for review"**)
4. Confirm submission

### What Happens Next

**Review Timeline:**
- **Initial review:** 1-3 days (usually)
- **Status:** Check Play Console dashboard
- **Notifications:** You'll receive email when reviewed

**Possible Outcomes:**
- ✅ **Approved:** App goes live on Play Store!
- ⚠️ **Rejected:** Review feedback provided, fix issues and resubmit
- ⏳ **Pending:** Still under review

**After Approval:**
- ✅ App appears on Play Store
- ✅ Users can download and install
- ✅ You can monitor analytics and reviews
- ✅ You can push updates

### ✅ Submission Checklist
- [ ] All requirements met
- [ ] App submitted for review
- [ ] Monitoring Play Console for status
- [ ] Email notifications enabled

---

## 🔐 IMPORTANT: API & Service Configuration

### Firebase Configuration

**Before Launch, Verify:**

1. **Firebase Project Setup:**
   - [ ] Firebase project created
   - [ ] `google-services.json` in `android/app/`
   - [ ] Firestore security rules deployed
   - [ ] Storage security rules deployed
   - [ ] Analytics enabled
   - [ ] Crashlytics enabled

2. **Firestore Security Rules:**
   - [ ] Rules deployed: `firestore.rules`
   - [ ] Tested with authenticated users
   - [ ] Config access requires authentication

3. **API Key Configuration:**
   - [ ] OpenRouter API key in Firestore: `app_config/ai_settings/openrouter_api_key`
   - [ ] API key is valid and has sufficient credits
   - [ ] Config loads correctly in app

**Firestore Structure Required:**
```
app_config/
  └── ai_settings/
      ├── openrouter_api_key: "sk-or-v1-..."
      ├── openrouter_base_url: "https://openrouter.ai/api/v1/chat/completions"
      ├── chat_model: "openai/gpt-3.5-turbo"
      ├── vision_model: "google/gemini-1.5-flash"
      └── ... (other config fields)
```

### External APIs Used

**OpenRouter API:**
- **Purpose:** AI food recognition, chat trainer
- **Cost:** Pay-per-use (check your plan)
- **Rate Limits:** Check your plan limits
- **Status:** Must be configured in Firestore

**Food Databases (Free):**
- Open Food Facts (free, unlimited)
- Local Indian dataset (bundled with app)
- UPCitemdb (free tier: 100/day)
- GTINsearch (free tier: 100/day)
- TheMealDB (free, unlimited)

**Google Services:**
- Google Sign-In (free)
- Google Fit (free)
- Firebase (free tier available)

### Rate Limits & Quotas

**Before Launch, Check:**
- [ ] OpenRouter API quota/credits sufficient
- [ ] Firebase quota limits (free tier: 50K reads/day)
- [ ] Google Fit API enabled in Google Cloud Console
- [ ] Google Sign-In OAuth client configured

---

## 🚀 Launch Strategy (Recommended)

### Phase 1: Internal Testing (Recommended First)

**Why:** Test with real users before public launch

1. Upload to **"Internal testing"** track
2. Add testers (up to 100 emails)
3. Test with team/friends
4. Gather feedback
5. Fix any issues
6. **Timeline:** 1-2 weeks

### Phase 2: Closed Testing (Optional)

**Why:** Get more feedback from beta users

1. Upload to **"Closed testing"** track
2. Create test group (up to 20,000 users)
3. Share join link
4. Gather feedback
5. Optimize based on usage
6. **Timeline:** 2-4 weeks

### Phase 3: Open Testing (Optional)

**Why:** Public beta before full launch

1. Upload to **"Open testing"** track
2. Anyone can join
3. Get wider feedback
4. **Timeline:** 1-2 weeks

### Phase 4: Production Launch

**Why:** Full public release

1. Upload to **"Production"** track
2. Submit for review
3. App goes live!
4. Monitor reviews and analytics

---

## 📊 Quick Reference

### App Information
- **Package Name:** `com.sisirlabs.calorievita`
- **Version:** `1.0.0` (Build: `1`)
- **Target SDK:** 34 (Android 14)
- **Min SDK:** 26 (Android 8.0)

### Build Commands
```powershell
# Generate keystore
.\generate_keystore.ps1

# Build production release
.\launch_production.ps1

# Build APK for testing
flutter build apk --release

# Install on device
flutter install --release
```

### File Locations
- **App Bundle:** `build/app/outputs/bundle/release/app-release.aab`
- **Test APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **Keystore:** `android/calorie-vita-release.jks`
- **Key Properties:** `android/key.properties`

### Play Console Links
- **Play Console:** https://play.google.com/console
- **Help Center:** https://support.google.com/googleplay/android-developer

---

## ⚠️ Critical Warnings

### Keystore Security
- ⚠️ **NEVER lose your keystore!** You cannot update your app without it
- ⚠️ **Back up keystore** to multiple secure locations (USB drive, cloud storage)
- ⚠️ **Save passwords** securely - you'll need them for ALL updates
- ⚠️ **Never commit** keystore or key.properties to Git

### API Keys
- ⚠️ **OpenRouter API key** must be configured in Firestore before launch
- ⚠️ **Monitor API usage** to avoid quota limits
- ⚠️ **Test API connections** before submitting

### Play Store Requirements
- ✅ Must have privacy policy if collecting data (you are - Firebase)
- ✅ Must complete data safety form
- ✅ Must have content rating
- ✅ Must test app before production launch
- ✅ Must declare all permissions and APIs

---

## 🎉 Summary Checklist

**Before Launch:**
- [ ] Production keystore generated and backed up
- [ ] Production build created (app-release.aab)
- [ ] App tested on physical device
- [ ] All features working (camera, barcode, AI, Firebase)
- [ ] Store assets prepared (icon, graphics, screenshots, descriptions)
- [ ] Legal documents created and hosted (privacy policy, terms)
- [ ] Firebase API key configured in Firestore
- [ ] All APIs tested and working

**Play Console Setup:**
- [ ] Google Play Developer account created ($25 paid)
- [ ] App listing created
- [ ] App bundle uploaded
- [ ] Store listing completed
- [ ] Privacy policy URL added
- [ ] Content rating obtained
- [ ] Data safety form completed
- [ ] App submitted for review

**After Launch:**
- [ ] Monitor Play Console for approval
- [ ] Respond to user reviews
- [ ] Track analytics
- [ ] Fix bugs and release updates

---

## 🎯 Total Time Breakdown

1. ✅ Generate keystore: **5 minutes**
2. ✅ Build release: **10-15 minutes**
3. ✅ Test on device: **30-60 minutes**
4. ✅ Create assets: **30-60 minutes**
5. ✅ Write legal docs: **30-60 minutes**
6. ✅ Upload to Play Store: **30 minutes**
7. ✅ Submit for review: **5 minutes**

**Total: 2-3 hours** + **Review time: 1-3 days**

---

## 🎉 You're Ready!

Follow this guide step-by-step, and your Calorie Vita app will be live on Google Play Store! 🚀

**Good luck with your launch!** 🎉

