# Firebase Database Schema - Calorie Vita App

## Project Overview
- **Project ID**: calorie-vita
- **Package Name**: com.sisirlabs.calorievita
- **Platforms**: Android, Web

## Database Structure

### Root Collections

#### 1. `users` Collection
Each user document contains subcollections for organized data management.

```
users/{userId}/
├── profile/
│   ├── userData (document)
│   └── preferences (document)
├── entries/
│   └── {entryId} (documents)
├── dailySummaries/
│   └── {dateKey} (documents)
├── goals/
│   └── current (document)
├── achievements/
│   └── {achievementId} (documents)
├── streaks/
│   └── summary (document)
├── trainerChats/
│   └── {sessionId} (documents)
├── healthData/
│   └── {dateKey} (documents)
└── analytics/
    └── {period} (documents)
```

### Document Schemas

#### 1. User Profile (`users/{userId}/profile/userData`)
```json
{
  "displayName": "string",
  "email": "string",
  "photoURL": "string",
  "dateOfBirth": "timestamp",
  "gender": "string", // "male", "female", "other"
  "height": "number", // in cm
  "weight": "number", // in kg
  "activityLevel": "string", // "sedentary", "light", "moderate", "active", "very_active"
  "createdAt": "timestamp",
  "lastUpdated": "timestamp",
  "isPremium": "boolean",
  "subscriptionExpiry": "timestamp"
}
```

#### 2. User Preferences (`users/{userId}/profile/preferences`)
```json
{
  "calorieUnit": "string", // "kcal", "cal"
  "weightUnit": "string", // "kg", "lbs"
  "heightUnit": "string", // "cm", "ft"
  "distanceUnit": "string", // "km", "miles"
  "temperatureUnit": "string", // "celsius", "fahrenheit"
  "language": "string", // "en", "es", "fr", etc.
  "theme": "string", // "light", "dark", "system"
  "notifications": {
    "dailyReminders": "boolean",
    "goalAchievements": "boolean",
    "weeklyReports": "boolean",
    "mealReminders": "boolean"
  },
  "privacy": {
    "shareData": "boolean",
    "analyticsOptIn": "boolean"
  },
  "lastUpdated": "timestamp"
}
```

#### 3. Food Entries (`users/{userId}/entries/{entryId}`)
```json
{
  "foodName": "string",
  "brand": "string",
  "quantity": "number",
  "unit": "string", // "g", "ml", "cup", "piece", etc.
  "calories": "number",
  "macroBreakdown": {
    "carbs": "number",
    "protein": "number",
    "fat": "number",
    "fiber": "number",
    "sugar": "number"
  },
  "mealCategory": "string", // "breakfast", "lunch", "dinner", "snack"
  "timestamp": "timestamp",
  "imageUrl": "string",
  "barcode": "string",
  "isVerified": "boolean",
  "source": "string", // "manual", "barcode", "camera", "ai"
  "createdAt": "timestamp",
  "lastUpdated": "timestamp"
}
```

#### 4. Daily Summaries (`users/{userId}/dailySummaries/{dateKey}`)
```json
{
  "date": "timestamp",
  "dateKey": "string", // "2024-01-15"
  "caloriesConsumed": "number",
  "caloriesBurned": "number",
  "caloriesGoal": "number",
  "waterIntake": "number", // glasses
  "waterGoal": "number",
  "steps": "number",
  "stepsGoal": "number",
  "workoutMinutes": "number",
  "workoutGoal": "number",
  "macroBreakdown": {
    "carbs": "number",
    "protein": "number",
    "fat": "number",
    "fiber": "number",
    "sugar": "number"
  },
  "goalsAchieved": "array", // ["calories", "steps", "water"]
  "mood": "string", // "excellent", "good", "okay", "poor"
  "notes": "string",
  "createdAt": "timestamp",
  "lastUpdated": "timestamp"
}
```

#### 5. User Goals (`users/{userId}/goals/current`)
```json
{
  "calorieGoal": "number",
  "waterGlassesGoal": "number",
  "stepsPerDayGoal": "number",
  "workoutMinutesGoal": "number",
  "weightGoal": "number",
  "macroGoals": {
    "carbsPercentage": "number",
    "proteinPercentage": "number",
    "fatPercentage": "number"
  },
  "weeklyWeightLossGoal": "number", // kg per week
  "targetDate": "timestamp",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "lastUpdated": "timestamp"
}
```

#### 6. Achievements (`users/{userId}/achievements/{achievementId}`)
```json
{
  "achievementId": "string",
  "title": "string",
  "description": "string",
  "icon": "string",
  "category": "string", // "streak", "milestone", "goal", "social"
  "points": "number",
  "unlockedAt": "timestamp",
  "isRead": "boolean",
  "progress": "number", // 0-100
  "maxProgress": "number"
}
```

#### 7. Streaks (`users/{userId}/streaks/summary`)
```json
{
  "goalStreaks": {
    "calories": {
      "current": "number",
      "longest": "number",
      "lastAchieved": "timestamp"
    },
    "steps": {
      "current": "number",
      "longest": "number",
      "lastAchieved": "timestamp"
    },
    "water": {
      "current": "number",
      "longest": "number",
      "lastAchieved": "timestamp"
    }
  },
  "totalActiveStreaks": "number",
  "longestOverallStreak": "number",
  "lastActivityDate": "timestamp",
  "totalDaysActive": "number",
  "lastUpdated": "timestamp"
}
```

#### 8. Trainer Chats (`users/{userId}/trainerChats/{sessionId}`)
```json
{
  "sessionId": "string",
  "title": "string",
  "messages": "array",
  "userId": "string",
  "timestamp": "timestamp",
  "isActive": "boolean",
  "lastMessageAt": "timestamp"
}
```

#### 9. Health Data (`users/{userId}/healthData/{dateKey}`)
```json
{
  "date": "timestamp",
  "dateKey": "string",
  "steps": "number",
  "caloriesBurned": "number",
  "heartRate": {
    "average": "number",
    "resting": "number",
    "max": "number"
  },
  "sleep": {
    "duration": "number", // hours
    "quality": "string", // "excellent", "good", "fair", "poor"
    "bedtime": "timestamp",
    "wakeTime": "timestamp"
  },
  "weight": "number",
  "bodyFat": "number",
  "muscleMass": "number",
  "source": "string", // "google_fit", "apple_health", "manual"
  "lastUpdated": "timestamp"
}
```

#### 10. Analytics (`users/{userId}/analytics/{period}`)
```json
{
  "period": "string", // "daily", "weekly", "monthly"
  "startDate": "timestamp",
  "endDate": "timestamp",
  "insights": "array",
  "recommendations": "array",
  "trends": {
    "calories": "array",
    "weight": "array",
    "steps": "array"
  },
  "generatedAt": "timestamp"
}
```

## Security Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Subcollections inherit parent permissions
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Public data (if any)
    match /public/{document} {
      allow read: if true;
    }
  }
}
```

### Storage Security Rules
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

## Indexes Required

### Composite Indexes
1. `users/{userId}/entries` - `timestamp` (descending)
2. `users/{userId}/dailySummaries` - `date` (descending)
3. `users/{userId}/achievements` - `unlockedAt` (descending)
4. `users/{userId}/trainerChats` - `timestamp` (descending)

## Data Validation

### Client-Side Validation
- All numeric values must be positive
- Timestamps must be valid dates
- Email addresses must be valid format
- Enum values must match predefined options

### Server-Side Validation
- User authentication required for all operations
- Data type validation
- Range validation for numeric fields
- Required field validation

## Performance Optimizations

1. **Pagination**: Use `limit()` and `startAfter()` for large collections
2. **Caching**: Implement local caching for frequently accessed data
3. **Offline Support**: Use Firestore offline persistence
4. **Batch Operations**: Group multiple writes in batches
5. **Real-time Updates**: Use streams for live data updates

## Migration Strategy

1. **Version Control**: Add version field to all documents
2. **Backward Compatibility**: Maintain old field names during transition
3. **Data Cleanup**: Remove deprecated fields after migration
4. **Testing**: Thoroughly test all operations before deployment

## Monitoring and Analytics

1. **Firebase Analytics**: Track user behavior and app performance
2. **Crashlytics**: Monitor app crashes and errors
3. **Performance Monitoring**: Track database query performance
4. **Custom Metrics**: Track business-specific metrics

## Backup and Recovery

1. **Automated Backups**: Daily automated backups
2. **Point-in-time Recovery**: Restore to specific timestamps
3. **Data Export**: Regular data exports for compliance
4. **Disaster Recovery**: Multi-region backup strategy
