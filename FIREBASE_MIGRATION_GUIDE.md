# Firebase Structure Migration Guide

## 🎯 Clean Firebase Structure (No Duplicates)

### **Firestore Collections:**

```
📁 Firestore Database
├── 📁 app_config/                    # App configuration (read-only)
├── 📁 users/{userId}/               # Main user collection
│   ├── 📄 {userId}                   # User profile document
│   ├── 📁 food_entries/{entryId}/    # Food entries
│   ├── 📁 daily_summaries/{dateKey}/ # Daily summaries
│   ├── 📁 weight_logs/{logId}/       # Weight logs (separate)
│   ├── 📁 goals/goal                # User goals (single document)
│   ├── 📁 achievements/{achievementId}/ # Achievements
│   ├── 📁 streaks/streak             # Streaks (single document)
│   └── 📁 chats/{sessionId}/         # AI trainer chats
├── 📁 food_database/                 # Public food database
└── 📁 admin/                         # Admin collections (server-only)
```

### **Storage Structure:**

```
📁 Firebase Storage
├── 📁 users/{userId}/               # User files (images, etc.)
├── 📁 public/                        # Public assets
└── 📁 admin/                         # Admin files (server-only)
```

---

## 🔄 Migration Steps

### **Step 1: Backup Your Data**
```bash
# Export your current Firestore data
gcloud firestore export gs://your-backup-bucket/firestore-backup
```

### **Step 2: Update Firestore Rules**
1. Copy the new `firestore.rules` content
2. Deploy to Firebase Console → Firestore → Rules
3. Test the rules in Firebase Console

### **Step 3: Update Storage Rules**
1. Copy the new `storage.rules` content
2. Deploy to Firebase Console → Storage → Rules
3. Test the rules in Firebase Console

### **Step 4: Data Migration Script**

Create a migration script to move your existing data:

```javascript
// migration-script.js
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./path-to-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://calorie-vita.firebaseio.com'
});

const db = admin.firestore();

async function migrateUserData(userId) {
  const userRef = db.collection('users').doc(userId);
  
  try {
    // 1. Move food entries
    const oldEntries = await db.collection('users').doc(userId)
      .collection('entries').get();
    
    const batch = db.batch();
    
    oldEntries.forEach(doc => {
      const newRef = userRef.collection('food_entries').doc(doc.id);
      batch.set(newRef, doc.data());
    });
    
    // 2. Move daily summaries
    const oldSummaries = await db.collection('users').doc(userId)
      .collection('dailySummaries').get();
    
    oldSummaries.forEach(doc => {
      const newRef = userRef.collection('daily_summaries').doc(doc.id);
      batch.set(newRef, doc.data());
    });
    
    // 3. Move health data
    const oldHealthData = await db.collection('users').doc(userId)
      .collection('healthData').get();
    
    oldHealthData.forEach(doc => {
      const newRef = userRef.collection('daily_summaries').doc(doc.id);
      batch.set(newRef, doc.data());
    });
    
    // 4. Move weight logs
    const oldWeightLogs = await db.collection('users').doc(userId)
      .collection('weightLogs').get();
    
    oldWeightLogs.forEach(doc => {
      const newRef = userRef.collection('weight_logs').doc(doc.id);
      batch.set(newRef, doc.data());
    });
    
    // 5. Move goals to single document
    const oldGoals = await db.collection('users').doc(userId)
      .collection('goals').get();
    
    if (!oldGoals.empty) {
      const goalData = oldGoals.docs[0].data();
      const goalRef = userRef.collection('goals').doc('goal');
      batch.set(goalRef, goalData);
    }
    
    // 6. Move streaks to single document
    const oldStreaks = await db.collection('users').doc(userId)
      .collection('streaks').get();
    
    if (!oldStreaks.empty) {
      const streakData = oldStreaks.docs[0].data();
      const streakRef = userRef.collection('streaks').doc('streak');
      batch.set(streakRef, streakData);
    }
    
    // 7. Move trainer chats
    const oldChats = await db.collection('users').doc(userId)
      .collection('trainerChats').get();
    
    oldChats.forEach(doc => {
      const newRef = userRef.collection('chats').doc(doc.id);
      batch.set(newRef, doc.data());
    });
    
    // 8. Move achievements
    const oldAchievements = await db.collection('users').doc(userId)
      .collection('achievements').get();
    
    oldAchievements.forEach(doc => {
      const newRef = userRef.collection('achievements').doc(doc.id);
      batch.set(newRef, doc.data());
    });
    
    await batch.commit();
    console.log(`✅ Migrated data for user: ${userId}`);
    
  } catch (error) {
    console.error(`❌ Error migrating user ${userId}:`, error);
  }
}

// Run migration for all users
async function migrateAllUsers() {
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    await migrateUserData(userDoc.id);
  }
  
  console.log('🎉 Migration completed!');
}

// Run the migration
migrateAllUsers().catch(console.error);
```

### **Step 5: Update Your Flutter Code**

Update your model classes to match the new structure:

```dart
// Update food entry service
class FoodEntryService {
  static CollectionReference get _collection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(AuthService.currentUser!.uid)
        .collection('food_entries'); // Changed from 'entries'
  }
}

// Update daily summary service
class DailySummaryService {
  static CollectionReference get _collection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(AuthService.currentUser!.uid)
        .collection('daily_summaries'); // Changed from 'dailySummaries'
  }
}

// Update weight logs service
class WeightLogsService {
  static CollectionReference get _collection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(AuthService.currentUser!.uid)
        .collection('weight_logs'); // Changed from 'weightLogs'
  }
}

// Update goals service
class GoalsService {
  static DocumentReference get _document {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(AuthService.currentUser!.uid)
        .collection('goals')
        .doc('goal'); // Single document instead of collection
  }
}

// Update streaks service
class StreaksService {
  static DocumentReference get _document {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(AuthService.currentUser!.uid)
        .collection('streaks')
        .doc('streak'); // Single document instead of collection
  }
}

// Update chat service
class ChatService {
  static CollectionReference get _collection {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(AuthService.currentUser!.uid)
        .collection('chats'); // Changed from 'trainerChats'
  }
}
```

### **Step 6: Clean Up Old Collections**

After successful migration, delete the old collections:

```javascript
// cleanup-script.js
async function cleanupOldCollections(userId) {
  const userRef = db.collection('users').doc(userId);
  
  // Delete old collections
  const collectionsToDelete = [
    'entries',
    'dailySummaries', 
    'healthData',
    'weightLogs',
    'analytics',
    'trainerChats'
  ];
  
  for (const collectionName of collectionsToDelete) {
    const collectionRef = userRef.collection(collectionName);
    const snapshot = await collectionRef.get();
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`🗑️ Deleted old collection: ${collectionName}`);
  }
}
```

---

## ✅ What Was Removed/Consolidated

### **Duplicates Removed:**
- ❌ `healthData` + `dailySummaries` → ✅ `daily_summaries` (merged)
- ❌ `analytics` → ✅ `daily_summaries` (calculated from summaries)
- ❌ `profile` subcollection → ✅ User document directly
- ❌ `system` collection → ✅ `admin` collection
- ✅ `weightLogs` → `weight_logs` (kept separate as requested)

### **Simplified Structure:**
- ✅ Single document for goals instead of collection
- ✅ Single document for streaks instead of collection
- ✅ Consolidated health data into daily summaries
- ✅ Simplified storage structure
- ✅ Removed redundant validation rules

---

## 🚀 Benefits of New Structure

1. **No Duplicates** - Each piece of data has one clear location
2. **Simplified Queries** - Fewer collections to manage
3. **Better Performance** - Reduced reads and writes
4. **Easier Maintenance** - Clear, logical structure
5. **Cost Effective** - Fewer Firestore operations

---

## ⚠️ Important Notes

1. **Test First** - Run migration on a copy of your database
2. **Backup Data** - Always backup before migration
3. **Update App** - Deploy new app version with updated code
4. **Monitor** - Watch for any issues after migration
5. **Rollback Plan** - Keep old structure until confirmed working

---

## 📞 Support

If you encounter any issues during migration:
1. Check Firebase Console logs
2. Verify rules are deployed correctly
3. Test with a single user first
4. Contact support if needed

Your Firebase structure is now clean and optimized! 🎉
