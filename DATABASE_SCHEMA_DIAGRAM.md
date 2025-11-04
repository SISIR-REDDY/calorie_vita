# Firebase Database Schema Diagram

## Complete Collection Structure

```
📦 calorie-vita (Firebase Project)
│
├── 📁 app_config/                          ⚙️ App Configuration
│   └── 📄 ai_settings                      🔑 AI API Keys & Settings
│
├── 📁 users/                               👥 User Data
│   └── 👤 {userId}/                        🔐 User ID (UID)
│       │
│       ├── 📁 entries/                     🍽️ Food Entries
│       │   └── 📄 {entryId}
│       │       ├── name: string
│       │       ├── calories: number
│       │       ├── timestamp: timestamp
│       │       ├── imageUrl: string?
│       │       ├── protein: number?
│       │       ├── carbs: number?
│       │       ├── fat: number?
│       │       ├── fiber: number?
│       │       └── sugar: number?
│       │
│       ├── 📁 profile/                     👤 User Profile
│       │   │
│       │   ├── 📄 userData                 📝 Basic Info
│       │   │   ├── onboardingCompleted: boolean
│       │   │   ├── displayName: string
│       │   │   ├── email: string
│       │   │   ├── photoURL: string?
│       │   │   ├── createdAt: timestamp
│       │   │   └── lastLogin: timestamp
│       │   │
│       │   ├── 📄 goals                    🎯 User Goals
│       │   │   ├── weightGoal: number?
│       │   │   ├── calorieGoal: number?
│       │   │   ├── bmiGoal: number?
│       │   │   ├── waterGlassesGoal: number?
│       │   │   ├── stepsPerDayGoal: number?
│       │   │   ├── macroGoals: object
│       │   │   │   ├── carbsCalories: number?
│       │   │   │   ├── proteinCalories: number?
│       │   │   │   └── fatCalories: number?
│       │   │   ├── fitnessGoal: string?
│       │   │   └── lastUpdated: timestamp?
│       │   │
│       │   ├── 📄 preferences               ⚙️ App Preferences
│       │   │   ├── calorieUnit: string
│       │   │   ├── notificationsEnabled: boolean
│       │   │   ├── darkModeEnabled: boolean
│       │   │   └── lastUpdated: timestamp?
│       │   │
│       │   └── 📄 achievements              🏆 Achievements
│       │       └── achievements: array
│       │           └── object
│       │               ├── id: string
│       │               ├── title: string
│       │               ├── description: string
│       │               ├── icon: string
│       │               ├── color: number
│       │               ├── points: number
│       │               ├── type: number
│       │               ├── isUnlocked: boolean
│       │               ├── unlockedAt: number?
│       │               └── requirements: object
│       │
│       ├── 📁 dailySummary/                📊 Daily Analytics
│       │   └── 📄 {dateKey}                📅 YYYY-MM-DD Format
│       │       ├── caloriesConsumed: number
│       │       ├── caloriesBurned: number
│       │       ├── caloriesGoal: number
│       │       ├── steps: number
│       │       ├── stepsGoal: number
│       │       ├── waterGlasses: number
│       │       ├── waterGlassesGoal: number
│       │       ├── date: timestamp
│       │       └── lastUpdated: timestamp?
│       │
│       ├── 📁 trainerChats/                💬 AI Trainer Messages
│       │   └── 📄 {messageId}              ⚠️ Auto-cleanup: 50 messages
│       │       ├── sender: string
│       │       ├── text: string
│       │       ├── timestamp: timestamp
│       │       └── sessionId: string
│       │
│       ├── 📁 chatSessions/                📋 Chat Sessions
│       │   └── 📄 {sessionId}              ⚠️ Auto-cleanup: 5 sessions
│       │       ├── title: string
│       │       ├── lastMessage: string
│       │       ├── lastMessageTime: timestamp
│       │       └── messageCount: number
│       │
│       ├── 📁 weightLogs/                  ⚖️ Weight Tracking
│       │   └── 📄 {logId}
│       │       ├── weight: number
│       │       ├── bmi: number
│       │       ├── date: timestamp
│       │       └── createdAt: timestamp
│       │
│       └── 📁 food_history/                📜 Food History
│           └── 📁 entries/
│               └── 📄 {entryId}            ⚠️ Limit: 100 entries
│                   ├── id: string
│                   ├── foodName: string
│                   ├── calories: number
│                   ├── protein: number
│                   ├── carbs: number
│                   ├── fat: number
│                   ├── fiber: number
│                   ├── sugar: number
│                   ├── weightGrams: number
│                   ├── category: string?
│                   ├── brand: string?
│                   ├── notes: string?
│                   ├── source: string
│                   ├── timestamp: timestamp
│                   ├── imagePath: string?
│                   └── scanData: object?
│
├── 📁 food_database/                       🗄️ Public Food Database
│   └── 📄 {document}                       🌐 Read-only for all users
│
└── 📁 admin/                               🔒 Admin Only
    └── 📄 {document=**}                    🚫 Server-side access only
```

---

## Legend

### Icons
- 📁 Collection
- 📄 Document
- 🔑 Configuration
- 👥 Users
- 👤 User Profile
- 🍽️ Food Data
- 📊 Analytics
- 💬 Chat
- ⚖️ Weight
- 🏆 Achievements
- 🎯 Goals
- ⚙️ Settings
- 🔐 Secure
- 🌐 Public
- 🔒 Private
- 🚫 Restricted

### Metadata
- ⚠️ Auto-cleanup enabled
- 🔐 Owner access only
- 🌐 Public read access
- 🚫 No client access

---

## Data Flow Diagrams

### Food Entry Flow
```
Camera/Manual → Image Processing → AI Recognition → FoodEntry → Firestore
                                                               ↓
                                                    Daily Summary Update
```

### Daily Summary Calculation
```
Food Entries → Aggregate by Date → Daily Summary → Real-time Stream
                                                            ↓
                                                      UI Update
```

### Chat Flow
```
User Message → Firestore → AI Service → Response → Firestore → UI Update
                 ↓                                      ↓
          Session Metadata                    Keep last 50 messages
```

---

## Collection Sizes & Limits

| Collection | Limit | Cleanup Strategy |
|------------|-------|------------------|
| entries | Unlimited | Manual or TTL |
| profile/* | Single document each | Manual update |
| dailySummary | One per date | Date-based auto-cleanup |
| trainerChats | Last 50 messages | Oldest deleted first |
| chatSessions | Last 5 sessions | Oldest deleted first |
| weightLogs | Unlimited | Manual cleanup |
| food_history/entries | 100 entries | Oldest deleted first |
| food_database | Unlimited | Admin only |

---

## Indexing Strategy

### Required Indexes
```javascript
// users/{userId}/entries
{ collection: 'entries', fields: ['timestamp', 'desc'] }
{ collection: 'entries', fields: ['timestamp', 'asc'], where: ['timestamp', '>='] }

// users/{userId}/dailySummary
{ collection: 'dailySummary', fields: ['date', 'desc'] }

// users/{userId}/trainerChats
{ collection: 'trainerChats', fields: ['timestamp', 'asc'] }

// users/{userId}/chatSessions
{ collection: 'chatSessions', fields: ['lastMessageTime', 'desc'] }

// users/{userId}/weightLogs
{ collection: 'weightLogs', fields: ['date', 'asc'] }
{ collection: 'weightLogs', fields: ['date', 'desc'] }
```

---

## Query Patterns

### Common Queries

#### Get Today's Food Entries
```dart
firestore
  .collection('users/{userId}/entries')
  .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
  .where('timestamp', isLessThan: endOfDay)
  .orderBy('timestamp', descending: true)
```

#### Get Weekly Calories
```dart
firestore
  .collection('users/{userId}/entries')
  .where('timestamp', isGreaterThanOrEqualTo: startOfWeek)
  .get()
```

#### Get User Goals
```dart
firestore
  .collection('users/{userId}/profile')
  .doc('goals')
  .get()
```

#### Real-time Daily Summary
```dart
firestore
  .collection('users/{userId}/dailySummary')
  .doc(todayDateKey)
  .snapshots()
```

---

## Security Model

```
┌─────────────────────────────────────────────────────────┐
│                    Security Layers                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Authentication Required                                │
│  ├── Email/Password ✅                                  │
│  ├── Google Sign-In ✅                                  │
│  └── Phone Auth ✅                                      │
│                                                         │
│  Authorization Rules                                    │
│  ├── Owner Access Only                                  │
│  │   └── users/{userId}/**/*                           │
│  ├── Authenticated Read                                 │
│  │   └── app_config/**/*                               │
│  ├── Public Read                                        │
│  │   └── food_database/**/*                            │
│  └── No Client Access                                   │
│      └── admin/**/*                                     │
│                                                         │
│  Data Validation                                        │
│  ├── String Length Limits                               │
│  ├── Number Range Checks                                │
│  ├── Timestamp Validation                               │
│  └── Type Enforcement                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Storage Structure

```
🏢 Storage Bucket: calorie-vita.firebasestorage.app

users/
├── {userId}/
│   ├── images/
│   │   ├── food_{timestamp}_{uuid}.jpg
│   │   ├── profile_{userId}.jpg
│   │   └── ...
│   └── documents/
│       └── ...

public/
├── assets/
│   ├── app_icon.png
│   ├── logo.png
│   └── ...
└── food_images/
    └── sample/

admin/
└── system/
    └── backup/
```

---

## Performance Metrics

### Read Performance
- **Average Query Time:** < 100ms
- **Real-time Stream Latency:** < 50ms
- **Cache Hit Rate:** 85%

### Write Performance
- **Average Write Time:** < 150ms
- **Batch Write:** 100 docs in < 500ms
- **Image Upload:** < 2s (8MB limit)

### Storage
- **Average User:** 5-10 MB
- **Largest Documents:** food_history entries
- **Image Storage:** Optimized with compression

---

**Last Updated:** 2024  
**Schema Version:** 1.0

