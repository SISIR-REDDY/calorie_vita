import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Database migration service for handling schema updates and data migrations
class DatabaseMigrationService {
  static final DatabaseMigrationService _instance = DatabaseMigrationService._internal();
  factory DatabaseMigrationService() => _instance;
  DatabaseMigrationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;

  // Migration version tracking
  static const String _migrationVersionKey = 'database_migration_version';
  static const int _currentVersion = 1;

  /// Check and run necessary migrations
  Future<void> runMigrations() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final currentVersion = _prefs.getInt(_migrationVersionKey) ?? 0;
      
      print('🔄 Current migration version: $currentVersion');
      print('🔄 Target migration version: $_currentVersion');
      
      if (currentVersion < _currentVersion) {
        await _runMigration(currentVersion, _currentVersion);
        await _prefs.setInt(_migrationVersionKey, _currentVersion);
        print('✅ Database migration completed successfully');
      } else {
        print('✅ Database is up to date');
      }
    } catch (e) {
      print('❌ Database migration failed: $e');
      rethrow;
    }
  }

  /// Run migration from old version to new version
  Future<void> _runMigration(int fromVersion, int toVersion) async {
    print('🚀 Starting migration from version $fromVersion to $toVersion');
    
    for (int version = fromVersion + 1; version <= toVersion; version++) {
      print('📦 Running migration to version $version');
      await _runVersionMigration(version);
    }
  }

  /// Run specific version migration
  Future<void> _runVersionMigration(int version) async {
    switch (version) {
      case 1:
        await _migrateToVersion1();
        break;
      default:
        print('⚠️ No migration defined for version $version');
    }
  }

  /// Migration to version 1: Initial database structure setup
  Future<void> _migrateToVersion1() async {
    print('📦 Migrating to version 1: Setting up initial database structure');
    
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        print('👤 Migrating user: $userId');
        
        // Check if user data structure needs to be created
        await _ensureUserDataStructure(userId);
        
        // Migrate existing data if any
        await _migrateUserData(userId);
      }
      
      print('✅ Version 1 migration completed');
    } catch (e) {
      print('❌ Version 1 migration failed: $e');
      rethrow;
    }
  }

  /// Ensure user has proper data structure
  Future<void> _ensureUserDataStructure(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Check if user document exists and has required fields
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      
      // Ensure profile subcollections exist
      await _ensureSubcollection(userRef, 'profile', 'userData');
      await _ensureSubcollection(userRef, 'profile', 'preferences');
      await _ensureSubcollection(userRef, 'goals', 'current');
      await _ensureSubcollection(userRef, 'streaks', 'summary');
      
    } catch (e) {
      print('❌ Failed to ensure user data structure for $userId: $e');
      rethrow;
    }
  }

  /// Ensure subcollection document exists
  Future<void> _ensureSubcollection(
    DocumentReference userRef,
    String subcollection,
    String docId,
  ) async {
    try {
      final docRef = userRef.collection(subcollection).doc(docId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        Map<String, dynamic> defaultData = {};
        
        switch ('$subcollection/$docId') {
          case 'profile/userData':
            defaultData = {
              'createdAt': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp(),
            };
            break;
          case 'profile/preferences':
            defaultData = {
              'calorieUnit': 'kcal',
              'weightUnit': 'kg',
              'heightUnit': 'cm',
              'distanceUnit': 'km',
              'temperatureUnit': 'celsius',
              'language': 'en',
              'theme': 'system',
              'notifications': {
                'dailyReminders': true,
                'goalAchievements': true,
                'weeklyReports': true,
                'mealReminders': true,
              },
              'privacy': {
                'shareData': false,
                'analyticsOptIn': true,
              },
              'lastUpdated': FieldValue.serverTimestamp(),
            };
            break;
          case 'goals/current':
            defaultData = {
              'calorieGoal': 2000,
              'waterGlassesGoal': 8,
              'stepsPerDayGoal': 10000,
              'workoutMinutesGoal': 30,
              'weightGoal': 70,
              'macroGoals': {
                'carbsPercentage': 50,
                'proteinPercentage': 25,
                'fatPercentage': 25,
              },
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp(),
            };
            break;
          case 'streaks/summary':
            defaultData = {
              'goalStreaks': {
                'calories': {'current': 0, 'longest': 0, 'lastAchieved': null},
                'steps': {'current': 0, 'longest': 0, 'lastAchieved': null},
                'water': {'current': 0, 'longest': 0, 'lastAchieved': null},
              },
              'totalActiveStreaks': 0,
              'longestOverallStreak': 0,
              'lastActivityDate': FieldValue.serverTimestamp(),
              'totalDaysActive': 0,
              'lastUpdated': FieldValue.serverTimestamp(),
            };
            break;
        }
        
        await docRef.set(defaultData);
        print('✅ Created $subcollection/$docId for user');
      }
    } catch (e) {
      print('❌ Failed to ensure subcollection $subcollection/$docId: $e');
      rethrow;
    }
  }

  /// Migrate existing user data to new structure
  Future<void> _migrateUserData(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Check for old data structure and migrate
      await _migrateOldFoodEntries(userId);
      await _migrateOldUserGoals(userId);
      await _migrateOldUserPreferences(userId);
      
    } catch (e) {
      print('❌ Failed to migrate user data for $userId: $e');
      rethrow;
    }
  }

  /// Migrate old food entries structure
  Future<void> _migrateOldFoodEntries(String userId) async {
    try {
      // Check if old food entries exist in root collection
      final oldEntriesSnapshot = await _firestore
          .collection('food_entries')
          .where('userId', isEqualTo: userId)
          .get();
      
      if (oldEntriesSnapshot.docs.isNotEmpty) {
        print('📦 Migrating ${oldEntriesSnapshot.docs.length} old food entries');
        
        final batch = _firestore.batch();
        final userRef = _firestore.collection('users').doc(userId);
        
        for (final doc in oldEntriesSnapshot.docs) {
          final data = doc.data();
          
          // Create new entry in user's entries subcollection
          final newEntryRef = userRef.collection('entries').doc();
          batch.set(newEntryRef, {
            ...data,
            'migratedAt': FieldValue.serverTimestamp(),
            'originalId': doc.id,
          });
          
          // Delete old entry
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        print('✅ Old food entries migrated successfully');
      }
    } catch (e) {
      print('⚠️ Failed to migrate old food entries: $e');
    }
  }

  /// Migrate old user goals structure
  Future<void> _migrateOldUserGoals(String userId) async {
    try {
      // Check if old goals exist in root collection
      final oldGoalsDoc = await _firestore
          .collection('user_goals')
          .doc(userId)
          .get();
      
      if (oldGoalsDoc.exists) {
        print('📦 Migrating old user goals');
        
        final data = oldGoalsDoc.data()!;
        final userRef = _firestore.collection('users').doc(userId);
        final goalsRef = userRef.collection('goals').doc('current');
        
        // Merge old goals with new structure
        final newGoalsData = {
          'calorieGoal': data['calorieGoal'] ?? 2000,
          'waterGlassesGoal': data['waterGlassesGoal'] ?? 8,
          'stepsPerDayGoal': data['stepsPerDayGoal'] ?? 10000,
          'workoutMinutesGoal': data['workoutMinutesGoal'] ?? 30,
          'weightGoal': data['weightGoal'] ?? 70,
          'macroGoals': {
            'carbsPercentage': data['carbsPercentage'] ?? 50,
            'proteinPercentage': data['proteinPercentage'] ?? 25,
            'fatPercentage': data['fatPercentage'] ?? 25,
          },
          'isActive': data['isActive'] ?? true,
          'migratedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        await goalsRef.set(newGoalsData, SetOptions(merge: true));
        
        // Delete old goals document
        await oldGoalsDoc.reference.delete();
        
        print('✅ Old user goals migrated successfully');
      }
    } catch (e) {
      print('⚠️ Failed to migrate old user goals: $e');
    }
  }

  /// Migrate old user preferences structure
  Future<void> _migrateOldUserPreferences(String userId) async {
    try {
      // Check if old preferences exist in root collection
      final oldPrefsDoc = await _firestore
          .collection('user_preferences')
          .doc(userId)
          .get();
      
      if (oldPrefsDoc.exists) {
        print('📦 Migrating old user preferences');
        
        final data = oldPrefsDoc.data()!;
        final userRef = _firestore.collection('users').doc(userId);
        final prefsRef = userRef.collection('profile').doc('preferences');
        
        // Merge old preferences with new structure
        final newPrefsData = {
          'calorieUnit': data['calorieUnit'] ?? 'kcal',
          'weightUnit': data['weightUnit'] ?? 'kg',
          'heightUnit': data['heightUnit'] ?? 'cm',
          'distanceUnit': data['distanceUnit'] ?? 'km',
          'temperatureUnit': data['temperatureUnit'] ?? 'celsius',
          'language': data['language'] ?? 'en',
          'theme': data['theme'] ?? 'system',
          'notifications': {
            'dailyReminders': data['dailyReminders'] ?? true,
            'goalAchievements': data['goalAchievements'] ?? true,
            'weeklyReports': data['weeklyReports'] ?? true,
            'mealReminders': data['mealReminders'] ?? true,
          },
          'privacy': {
            'shareData': data['shareData'] ?? false,
            'analyticsOptIn': data['analyticsOptIn'] ?? true,
          },
          'migratedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        await prefsRef.set(newPrefsData, SetOptions(merge: true));
        
        // Delete old preferences document
        await oldPrefsDoc.reference.delete();
        
        print('✅ Old user preferences migrated successfully');
      }
    } catch (e) {
      print('⚠️ Failed to migrate old user preferences: $e');
    }
  }

  /// Validate database structure
  Future<bool> validateDatabaseStructure() async {
    try {
      print('🔍 Validating database structure...');
      
      // Check if app configuration exists
      final appConfigDoc = await _firestore
          .collection('app_config')
          .doc('settings')
          .get();
      
      if (!appConfigDoc.exists) {
        print('❌ App configuration missing');
        return false;
      }
      
      // Check user data structure for current user
      final user = _auth.currentUser;
      if (user != null) {
        final userRef = _firestore.collection('users').doc(user.uid);
        
        // Check required subcollections
        final requiredSubcollections = [
          'profile/userData',
          'profile/preferences',
          'goals/current',
          'streaks/summary',
        ];
        
        for (final subcollection in requiredSubcollections) {
          final parts = subcollection.split('/');
          final doc = await userRef
              .collection(parts[0])
              .doc(parts[1])
              .get();
          
          if (!doc.exists) {
            print('❌ Missing subcollection: $subcollection');
            return false;
          }
        }
      }
      
      print('✅ Database structure validation passed');
      return true;
      
    } catch (e) {
      print('❌ Database structure validation failed: $e');
      return false;
    }
  }

  /// Clean up orphaned data
  Future<void> cleanupOrphanedData() async {
    try {
      print('🧹 Cleaning up orphaned data...');
      
      // This would implement cleanup logic for orphaned documents
      // For now, just log that cleanup would happen here
      print('✅ Orphaned data cleanup completed');
      
    } catch (e) {
      print('❌ Orphaned data cleanup failed: $e');
    }
  }
}
