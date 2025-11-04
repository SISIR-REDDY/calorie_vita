# Firebase Structure Documentation - Calorie Vita

**Version:** 1.0.0  
**Last Updated:** 2024  
**Project ID:** `calorie-vita`

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Firebase Services](#firebase-services)
3. [Firestore Database Structure](#firestore-database-structure)
4. [Firebase Storage Structure](#firebase-storage-structure)
5. [Authentication Methods](#authentication-methods)
6. [Data Models](#data-models)
7. [Security Rules](#security-rules)
8. [Configuration Management](#configuration-management)
9. [Performance Optimizations](#performance-optimizations)

---

## 🎯 Overview

Calorie Vita uses Firebase as the backend infrastructure for a calorie tracking application with AI-powered food recognition. The structure is designed for scalability, security, and optimal performance.

### Key Features
- Real-time data synchronization
- Offline support with Firestore persistence
- Image storage for food photos
- AI-powered food recognition integration
- Comprehensive user analytics
- Achievement system
- Google Fit integration

---

## 🔧 Firebase Services

### Active Services
1. **Firebase Authentication** (`firebase_auth: ^5.6.0`)
2. **Cloud Firestore** (`cloud_firestore: ^5.6.9`)
3. **Firebase Storage** (`firebase_storage: ^12.4.7`)
4. **Firebase Analytics** (`firebase_analytics: ^11.3.3`)
5. **Firebase Crashlytics** (`firebase_crashlytics: ^4.1.3`)
6. **Firebase Messaging** (`firebase_messaging: ^15.1.3`)
7. **Firebase Remote Config** (`firebase_remote_config: ^5.1.3`)

### Configuration
```dart
Project ID: calorie-vita
Messaging Sender ID: 868343457049
Storage Bucket: calorie-vita.firebasestorage.app
Auth Domain: calorie-vita.firebaseapp.com
```

---

## 🗄️ Firestore Database Structure

### Top-Level Collections

```
📁 app_config/                    # Application Configuration
📁 users/                         # User Data
📁 food_database/                 # Public Food Database
📁 admin/                         # Admin Only (Server-side)
```

---

### 1️⃣ App Configuration Collection

**Path:** `app_config/{document}`  
**Access:** Read by authenticated users, Write by admins only

#### Documents
- **`ai_settings`** - AI Configuration & API Keys
  ```json
  {
    "openrouter_api_key": "sk-or-v1-...",
    "openrouter_base_url": "https://openrouter.ai/api/v1/chat/completions",
    "chat_model": "openai/gpt-3.5-turbo",
    "vision_model": "google/gemini-pro-1.5-exp",
    "backup_vision_model": "google/gemini-pro-1.5",
    "max_tokens": 100,
    "chat_max_tokens": 100,
    "analytics_max_tokens": 120,
    "vision_max_tokens": 300,
    "temperature": 0.7,
    "vision_temperature": 0.1,
    "app_name": "Calorie Vita",
    "app_url": "https://calorievita.com",
    "max_requests_per_minute": 60,
    "request_timeout_seconds": 30,
    "enable_chat": true,
    "enable_analytics": true,
    "enable_recommendations": true,
    "enable_image_analysis": true,
    "enable_debug_logs": false,
    "enable_api_response_logging": false
  }
  ```

---

### 2️⃣ Users Collection

**Path:** `users/{userId}/`  
**Access:** Owner read/write only

#### Sub-collections Structure

```
users/{userId}/
├── entries/                          # Food Entries
│   └── {entryId}                     # FoodEntry Document
├── profile/                          # User Profile Data
│   ├── userData                      # User Profile Document
│   ├── goals                         # UserGoals Document
│   ├── preferences                   # UserPreferences Document
│   └── achievements                  # Achievements Array
├── dailySummary/                     # Daily Summaries
│   └── {dateKey}                     # Format: "YYYY-MM-DD"
├── trainerChats/                     # AI Trainer Messages
│   └── {messageId}                   # Chat Message
├── chatSessions/                     # Chat Session Metadata
│   └── {sessionId}                   # Session Info
├── weightLogs/                       # Weight Tracking
│   └── {logId}                       # Weight Entry
└── food_history/                     # Extended Food History
    └── entries/
        └── {entryId}                 # FoodHistoryEntry
```

---

#### A. Food Entries Sub-collection

**Path:** `users/{userId}/entries/{entryId}`

```json
{
  "name": "Grilled Chicken Breast",
  "calories": 231,
  "timestamp": "2024-01-15T12:30:00Z",
  "imageUrl": "gs://calorie-vita.appspot.com/users/{userId}/images/{imageId}.jpg",
  "protein": 43.5,
  "carbs": 0.0,
  "fat": 5.0,
  "fiber": 0.0,
  "sugar": 0.0
}
```

**Validation Rules:**
- `name`: String, 1-200 characters
- `calories`: Number, 0-10,000
- `timestamp`: Valid timestamp ≤ current time

---

#### B. Profile Sub-collection

**Path:** `users/{userId}/profile/`

##### B1. User Data Document

**Path:** `users/{userId}/profile/userData`

```json
{
  "onboardingCompleted": true,
  "displayName": "John Doe",
  "email": "john@example.com",
  "photoURL": "https://...",
  "createdAt": "2024-01-01T00:00:00Z",
  "lastLogin": "2024-01-15T10:00:00Z"
}
```

##### B2. Goals Document

**Path:** `users/{userId}/profile/goals`

```json
{
  "weightGoal": 75.0,
  "calorieGoal": 2000,
  "bmiGoal": 24.0,
  "waterGlassesGoal": 8,
  "stepsPerDayGoal": 10000,
  "macroGoals": {
    "carbsCalories": 900,
    "proteinCalories": 500,
    "fatCalories": 600
  },
  "fitnessGoal": "weight_loss",
  "lastUpdated": "2024-01-15T00:00:00Z"
}
```

**Fitness Goals:** `weight_loss`, `weight_gain`, `maintenance`, `muscle_building`

**Validation Rules:**
- `calorieGoal`: 500-10,000
- `waterGlassesGoal`: 1-50
- `stepsPerDayGoal`: 1,000-100,000

##### B3. Preferences Document

**Path:** `users/{userId}/profile/preferences`

```json
{
  "calorieUnit": "kcal",
  "notificationsEnabled": true,
  "darkModeEnabled": false,
  "lastUpdated": "2024-01-15T00:00:00Z"
}
```

##### B4. Achievements Document

**Path:** `users/{userId}/profile/achievements`

```json
{
  "achievements": [
    {
      "id": "streak_7",
      "title": "Week Warrior",
      "description": "Log meals for 7 consecutive days",
      "icon": "🔥",
      "color": 4286735679,
      "points": 150,
      "type": 1,
      "isUnlocked": true,
      "unlockedAt": 1705276800000,
      "requirements": {
        "streak_days": 7
      }
    }
  ]
}
```

**Achievement Types:**
- `0`: Bronze
- `1`: Silver
- `2`: Gold
- `3`: Platinum
- `4`: Diamond

---

#### C. Daily Summary Sub-collection

**Path:** `users/{userId}/dailySummary/{dateKey}`  
**Date Format:** `YYYY-MM-DD` (e.g., "2024-01-15")

```json
{
  "caloriesConsumed": 1850,
  "caloriesBurned": 300,
  "caloriesGoal": 2000,
  "steps": 8500,
  "stepsGoal": 10000,
  "waterGlasses": 6,
  "waterGlassesGoal": 8,
  "date": "2024-01-15T00:00:00Z",
  "lastUpdated": "2024-01-15T23:59:59Z"
}
```

**Validation Rules:**
- `caloriesConsumed`: 0-50,000
- `caloriesBurned`: 0-10,000
- `steps`: 0-100,000
- `dateKey`: String, max 20 characters

---

#### D. Trainer Chats Sub-collection

**Path:** `users/{userId}/trainerChats/{messageId}`  
**Limit:** Last 50 messages (≈5 conversations)

```json
{
  "sender": "user",
  "text": "What should I eat for breakfast?",
  "timestamp": "2024-01-15T08:00:00Z",
  "sessionId": "session_abc123"
}
```

**Sender Types:** `user`, `assistant`

---

#### E. Chat Sessions Sub-collection

**Path:** `users/{userId}/chatSessions/{sessionId}`  
**Limit:** Last 5 sessions

```json
{
  "title": "What should I eat...",
  "lastMessage": "Great suggestions!",
  "lastMessageTime": "2024-01-15T08:30:00Z",
  "messageCount": 12
}
```

---

#### F. Weight Logs Sub-collection

**Path:** `users/{userId}/weightLogs/{logId}`

```json
{
  "weight": 78.5,
  "bmi": 25.2,
  "date": "2024-01-15T00:00:00Z",
  "createdAt": "2024-01-15T07:00:00Z"
}
```

**Validation Rules:**
- `weight`: 10-1,000 kg
- Valid timestamps required

---

#### G. Food History Sub-collection

**Path:** `users/{userId}/food_history/entries/{entryId}`  
**Limit:** 100 entries

```json
{
  "id": "entry_abc123",
  "foodName": "Grilled Salmon",
  "calories": 280.5,
  "protein": 39.2,
  "carbs": 0.0,
  "fat": 12.5,
  "fiber": 0.0,
  "sugar": 0.0,
  "weightGrams": 150.0,
  "category": "Protein",
  "brand": null,
  "notes": "Grilled with lemon",
  "source": "camera_scan",
  "timestamp": "2024-01-15T19:00:00Z",
  "imagePath": "gs://calorie-vita.appspot.com/users/{userId}/images/{imageId}.jpg",
  "scanData": {}
}
```

**Sources:** `camera_scan`, `barcode_scan`, `manual_entry`

---

### 3️⃣ Food Database Collection

**Path:** `food_database/{document}`  
**Access:** Read by all, Write by admins only

Public food database for reference and lookup.

---

### 4️⃣ Admin Collection

**Path:** `admin/{document=**}`  
**Access:** Server-side only, no client access

---

## 📦 Firebase Storage Structure

**Bucket:** `calorie-vita.firebasestorage.app`  
**Max File Size:** 8 MB (images only)

### Directory Structure

```
📁 users/
│   └── {userId}/
│       └── {allPaths=**}              # All user files
│           └── images/
│               └── {imageId}.jpg      # Food photos
│
📁 public/
│   └── {allPaths=**}                  # Public assets
│
📁 admin/
│   └── {allPaths=**}                  # Admin files (server-only)
```

### Validation Rules
- **Content Type:** `image/*` only
- **File Size:** < 8 MB
- **Access:** Owner read/write only

---

## 🔐 Authentication Methods

### Supported Methods
1. **Email/Password**
   - Standard Firebase Auth
   - Email verification supported

2. **Google Sign-In**
   - OAuth integration
   - Google Fit scopes included

3. **Phone Authentication**
   - SMS verification
   - OTP support

### Google Fit Scopes
```dart
[
  'email',
  'profile',
  'openid',
  'https://www.googleapis.com/auth/fitness.activity.read',
  'https://www.googleapis.com/auth/fitness.body.read',
  'https://www.googleapis.com/auth/fitness.nutrition.read',
  'https://www.googleapis.com/auth/fitness.sleep.read'
]
```

---

## 📊 Data Models

### Core Models

#### FoodEntry
```dart
class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final DateTime timestamp;
  final String? imageUrl;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
}
```

#### DailySummary
```dart
class DailySummary {
  final int caloriesConsumed;
  final int caloriesBurned;
  final int caloriesGoal;
  final int steps;
  final int stepsGoal;
  final int waterGlasses;
  final int waterGlassesGoal;
  final DateTime date;
  final MacroBreakdown macroBreakdown;
}
```

#### UserGoals
```dart
class UserGoals {
  final double? weightGoal;
  final int? calorieGoal;
  final double? bmiGoal;
  final int? waterGlassesGoal;
  final int? stepsPerDayGoal;
  final MacroGoals? macroGoals;
  final String? fitnessGoal;
  final DateTime? lastUpdated;
}
```

#### MacroBreakdown
```dart
class MacroBreakdown {
  final double carbs;
  final double protein;
  final double fat;
  final double fiber;
  final double sugar;
  
  // Computed properties
  double get totalCalories => (carbs * 4) + (protein * 4) + (fat * 9);
  double get carbsPercentage;
  double get proteinPercentage;
  double get fatPercentage;
  MacroBreakdown get recommendedDaily;
  bool get isWithinRecommended;
  double get qualityScore;
}
```

---

## 🛡️ Security Rules

### Firestore Security Rules

```javascript
// Helper functions
function isAuthenticated() {
  return request.auth != null;
}

function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}

function isValidTimestamp(timestamp) {
  return timestamp is timestamp && timestamp <= request.time;
}

function isValidString(str, maxLength) {
  return str is string && str.size() > 0 && str.size() <= maxLength;
}

function isValidNumber(num, min, max) {
  return num is number && num >= min && num <= max;
}
```

### Access Control
- **App Config:** Authenticated read, admin write
- **User Data:** Owner read/write
- **Food Database:** Public read, admin write
- **Admin Collections:** No client access

---

## ⚙️ Configuration Management

### Production Configuration

```dart
class ProductionConfig {
  // AI Configuration
  static const Map<String, dynamic> aiConfig = {
    'chat_model': 'openai/gpt-3.5-turbo',
    'vision_model': 'google/gemini-pro-1.5-exp',
    'backup_vision_model': 'google/gemini-pro-1.5',
    'max_tokens_chat': 100,
    'max_tokens_vision': 300,
    'temperature_chat': 0.7,
    'temperature_vision': 0.05,
    'timeout_seconds': 15,
    'retry_attempts': 3,
    'cache_duration_minutes': 45,
    'confidence_threshold': 0.75,
  };
  
  // Performance Configuration
  static const Map<String, dynamic> performanceConfig = {
    'image_max_size': 1200,
    'image_quality': 90,
    'cache_size_mb': 75,
    'max_concurrent_requests': 2,
    'request_timeout_ms': 20000,
    'enable_image_compression': true,
    'enable_response_caching': true,
    'enable_lazy_loading': true,
    'enable_parallel_processing': true,
    'memory_optimization': true,
  };
  
  // Firebase Configuration
  static const Map<String, dynamic> firebaseConfig = {
    'enable_crashlytics': true,
    'enable_analytics': true,
    'enable_performance_monitoring': true,
    'batch_size': 100,
    'retry_attempts': 3,
    'timeout_seconds': 10,
  };
}
```

---

## ⚡ Performance Optimizations

### Data Management
- **Batch Operations:** Batch size of 100
- **Pagination:** Results limited to reasonable sizes
- **Indexing:** Optimized queries with proper indexes
- **Caching:** 75 MB cache with 45-minute duration

### Auto-cleanup
- **Chat Messages:** Keep last 50 messages
- **Chat Sessions:** Keep last 5 sessions
- **Food History:** Limit to 100 entries
- **Daily Summaries:** Date-based partitioning

### Real-time Updates
- Streams for:
  - Food entries
  - Daily summaries
  - User goals
  - User preferences
  - Achievement updates

---

## 🔗 Additional Resources

- **Project Repository:** Private
- **Firebase Console:** https://console.firebase.google.com/project/calorie-vita
- **Documentation:** Internal Wiki
- **Support:** sisirlabs.com

---

**Document Status:** Active  
**Maintained By:** SISIR Labs  
**Last Review:** 2024

