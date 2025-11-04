import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_entry.dart';
import '../models/user_goals.dart';
import '../models/user_preferences.dart';
import '../models/daily_summary.dart';
import '../models/macro_breakdown.dart';
import '../models/user_achievement.dart';
import 'firebase_service.dart';

/// Centralized app state management service
/// Handles real-time data synchronization, caching, and offline support
class AppStateService {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for real-time updates
  final StreamController<User?> _userController =
      StreamController<User?>.broadcast();
  final StreamController<List<FoodEntry>> _foodEntriesController =
      StreamController<List<FoodEntry>>.broadcast();
  final StreamController<UserGoals?> _goalsController =
      StreamController<UserGoals?>.broadcast();
  final StreamController<UserPreferences> _preferencesController =
      StreamController<UserPreferences>.broadcast();
  final StreamController<DailySummary?> _dailySummaryController =
      StreamController<DailySummary?>.broadcast();
  final StreamController<MacroBreakdown> _macroBreakdownController =
      StreamController<MacroBreakdown>.broadcast();
  final StreamController<List<UserAchievement>> _achievementsController =
      StreamController<List<UserAchievement>>.broadcast();
  final StreamController<bool> _isOnlineController =
      StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>?> _profileDataController =
      StreamController<Map<String, dynamic>?>.broadcast();

  // Current state
  User? _currentUser;
  List<FoodEntry> _foodEntries = [];
  UserGoals? _userGoals;
  UserPreferences _userPreferences = const UserPreferences();
  DailySummary? _dailySummary;
  MacroBreakdown _macroBreakdown =
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
  List<UserAchievement> _achievements = [];
  Map<String, dynamic>? _profileData;
  bool _isOnline = true;
  bool _isInitialized = false;

  // Stream subscriptions
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _foodEntriesSubscription;
  StreamSubscription<DocumentSnapshot>? _goalsSubscription;
  StreamSubscription<DocumentSnapshot>? _preferencesSubscription;
  StreamSubscription<DocumentSnapshot>? _achievementsSubscription;
  StreamSubscription<DocumentSnapshot>? _profileDataSubscription;

  // Getters for streams
  Stream<User?> get userStream => _userController.stream;
  Stream<List<FoodEntry>> get foodEntriesStream =>
      _foodEntriesController.stream;
  Stream<UserGoals?> get goalsStream => _goalsController.stream;
  Stream<UserPreferences> get preferencesStream =>
      _preferencesController.stream;
  Stream<DailySummary?> get dailySummaryStream =>
      _dailySummaryController.stream;
  Stream<MacroBreakdown> get macroBreakdownStream =>
      _macroBreakdownController.stream;
  Stream<List<UserAchievement>> get achievementsStream =>
      _achievementsController.stream;
  Stream<bool> get isOnlineStream => _isOnlineController.stream;
  Stream<Map<String, dynamic>?> get profileDataStream =>
      _profileDataController.stream;

  // Getters for current state
  User? get currentUser => _currentUser;
  List<FoodEntry> get foodEntries => _foodEntries;
  UserGoals? get userGoals => _userGoals;
  UserPreferences get userPreferences => _userPreferences;
  DailySummary? get dailySummary => _dailySummary;
  MacroBreakdown get macroBreakdown => _macroBreakdown;
  List<UserAchievement> get achievements => _achievements;
  Map<String, dynamic>? get profileData => _profileData;
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  FirebaseService get firebaseService => _firebaseService;

  /// Initialize the app state service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up auth state listener
      _authSubscription = _auth.authStateChanges().listen((user) {
        _currentUser = user;
        _userController.add(user);

        if (user != null) {
          _setupUserDataListeners(user.uid);
        } else {
          _clearUserData();
        }
      });

      // Set up connectivity monitoring
      _setupConnectivityMonitoring();

      // Load cached data
      await _loadCachedData();

      _isInitialized = true;
    } catch (e) {
      print('Error initializing AppStateService: $e');
      rethrow;
    }
  }

  /// Set up real-time listeners for user data
  void _setupUserDataListeners(String userId) {
    // Food entries listener
    _foodEntriesSubscription?.cancel();
    _foodEntriesSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('entries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _foodEntries =
                  snapshot.docs.map((doc) => FoodEntry.fromFirestore(doc)).toList();
              _foodEntriesController.add(_foodEntries);
              updateDailySummary();
              _updateMacroBreakdown();
              _cacheFoodEntries();
            } catch (e) {
              print('Error processing food entries snapshot: $e');
            }
          },
          onError: (error) {
            print('Food entries listener error: $error');
            // Don't crash - just log the error
          },
        );

    // Goals listener
    _goalsSubscription?.cancel();
    _goalsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('goals')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              if (snapshot.exists) {
                _userGoals = UserGoals.fromMap(snapshot.data()!);
              } else {
                _userGoals = null;
              }
              _goalsController.add(_userGoals);
              _cacheUserGoals();
            } catch (e) {
              print('Error processing goals snapshot: $e');
            }
          },
          onError: (error) {
            print('Goals listener error: $error');
          },
        );

    // Preferences listener
    _preferencesSubscription?.cancel();
    _preferencesSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('preferences')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              if (snapshot.exists) {
                _userPreferences = UserPreferences.fromMap(snapshot.data()!);
              } else {
                _userPreferences = const UserPreferences();
              }
              _preferencesController.add(_userPreferences);
              _cacheUserPreferences();
            } catch (e) {
              print('Error processing preferences snapshot: $e');
            }
          },
          onError: (error) {
            print('Preferences listener error: $error');
          },
        );

    // Achievements listener
    _achievementsSubscription?.cancel();
    _achievementsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('achievements')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              if (snapshot.exists) {
                final data = snapshot.data()!;
                _achievements = (data['achievements'] as List?)
                        ?.map((a) => UserAchievement.fromJson(a))
                        .toList() ??
                    [];
              } else {
                _achievements = [];
              }
              _achievementsController.add(_achievements);
              _cacheAchievements();
            } catch (e) {
              print('Error processing achievements snapshot: $e');
            }
          },
          onError: (error) {
            print('Achievements listener error: $error');
          },
        );

    // Profile data listener (for height, weight, etc.)
    _profileDataSubscription?.cancel();
    _profileDataSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('userData')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              print(
                  'Profile data snapshot received in AppStateService: ${snapshot.exists}');
              if (snapshot.exists) {
                _profileData = snapshot.data()!;
                print('Profile data updated: $_profileData');
              } else {
                _profileData = null;
                print('Profile data document does not exist');
              }
              _profileDataController.add(_profileData);
              _cacheProfileData();
            } catch (e) {
              print('Error processing profile data snapshot: $e');
            }
          },
          onError: (error) {
            print('Profile data listener error: $error');
          },
        );
  }

  /// Update daily summary based on current food entries and health data
  void updateDailySummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayEntries = _foodEntries.where((entry) {
      final entryDate = DateTime(
          entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      return entryDate.isAtSameMomentAs(today);
    }).toList();

    final caloriesConsumed =
        todayEntries.fold(0, (sum, entry) => sum + entry.calories);

    _dailySummary = DailySummary(
      caloriesConsumed: caloriesConsumed,
      caloriesBurned: 0, // Health data removed
      caloriesGoal: _userGoals?.calorieGoal ?? 2000,
      steps: 0, // Health data removed
      stepsGoal: _userGoals?.stepsPerDayGoal ?? 10000,
      waterGlasses: 0, // Default value, will be updated from user input
      waterGlassesGoal: _userGoals?.waterGlassesGoal ?? 8,
      date: today,
    );

    _dailySummaryController.add(_dailySummary);
  }

  /// Update macro breakdown based on current food entries
  void _updateMacroBreakdown() {
    _macroBreakdown = _foodEntries.fold<MacroBreakdown>(
      MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0),
      (sum, entry) => sum + entry.macroBreakdown,
    );
    _macroBreakdownController.add(_macroBreakdown);
  }

  /// Set up connectivity monitoring (optimized)
  void _setupConnectivityMonitoring() {
    // Simple connectivity check - reduced frequency to 2 minutes
    Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkConnectivity();
    });
  }

  /// Check connectivity status
  Future<void> _checkConnectivity() async {
    try {
      await _firestore.collection('connectivity').doc('test').get();
      if (!_isOnline) {
        _isOnline = true;
        _isOnlineController.add(true);
        await syncOfflineData();
      }
    } catch (e) {
      if (_isOnline) {
        _isOnline = false;
        _isOnlineController.add(false);
      }
    }
  }

  /// Sync offline data when coming back online
  Future<void> syncOfflineData() async {
    if (_currentUser == null) return;

    try {
      // Sync any pending food entries
      final prefs = await SharedPreferences.getInstance();
      final pendingEntries = prefs.getStringList('pending_food_entries') ?? [];

      for (final entryJson in pendingEntries) {
        try {
          final entry = FoodEntry.fromJson(
              Map<String, dynamic>.from(jsonDecode(entryJson)));
          await _firebaseService.saveFoodEntry(_currentUser!.uid, entry);
        } catch (e) {
          print('Error syncing pending entry: $e');
        }
      }

      // Clear pending entries after sync
      await prefs.remove('pending_food_entries');
    } catch (e) {
      print('Error syncing offline data: $e');
    }
  }

  /// Load cached data from local storage
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached food entries
      final cachedEntries = prefs.getStringList('cached_food_entries') ?? [];
      _foodEntries = [];
      for (final json in cachedEntries) {
        try {
          if (json.isNotEmpty) {
            final decoded = jsonDecode(json);
            _foodEntries.add(FoodEntry.fromJson(Map<String, dynamic>.from(decoded)));
          }
        } catch (e) {
          print('⚠️ Skipping invalid cached entry: $e');
          // Continue with other entries
        }
      }
      _foodEntriesController.add(_foodEntries);

      // Load cached preferences
      final cachedPrefs = prefs.getString('cached_preferences');
      if (cachedPrefs != null && cachedPrefs.isNotEmpty) {
        try {
          // Try to parse as JSON first
          final decoded = jsonDecode(cachedPrefs);
          _userPreferences = UserPreferences.fromMap(
              Map<String, dynamic>.from(decoded));
          _preferencesController.add(_userPreferences);
        } catch (e) {
          // If JSON parsing fails, try to parse as Map directly
          print('⚠️ Cached preferences not valid JSON, clearing cache: $e');
          // Clear invalid cache
          await prefs.remove('cached_preferences');
        }
      }

      // Load cached goals
      final cachedGoals = prefs.getString('cached_goals');
      if (cachedGoals != null && cachedGoals.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedGoals);
          _userGoals = UserGoals.fromMap(
              Map<String, dynamic>.from(decoded));
          _goalsController.add(_userGoals);
        } catch (e) {
          print('⚠️ Cached goals not valid JSON, clearing cache: $e');
          // Clear invalid cache
          await prefs.remove('cached_goals');
        }
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  /// Cache food entries locally
  Future<void> _cacheFoodEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = _foodEntries.map((entry) => jsonEncode(entry.toJson())).toList();
      await prefs.setStringList('cached_food_entries', entriesJson);
    } catch (e) {
      print('Error caching food entries: $e');
    }
  }

  /// Cache user preferences locally
  Future<void> _cacheUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'cached_preferences', jsonEncode(_userPreferences.toMap()));
    } catch (e) {
      print('Error caching preferences: $e');
    }
  }

  /// Cache user goals locally
  Future<void> _cacheUserGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userGoals != null) {
        await prefs.setString('cached_goals', jsonEncode(_userGoals!.toMap()));
      } else {
        await prefs.remove('cached_goals');
      }
    } catch (e) {
      print('Error caching goals: $e');
    }
  }

  /// Cache achievements locally
  Future<void> _cacheAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsJson = _achievements.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList('cached_achievements', achievementsJson);
    } catch (e) {
      print('Error caching achievements: $e');
    }
  }

  /// Cache profile data locally
  Future<void> _cacheProfileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'cached_profile_data', _profileData?.toString() ?? '');
    } catch (e) {
      print('Error caching profile data: $e');
    }
  }

  /// Save food entry with offline support
  Future<void> saveFoodEntry(FoodEntry entry) async {
    if (_currentUser == null) return;

    try {
      if (_isOnline) {
        await _firebaseService.saveFoodEntry(_currentUser!.uid, entry);
      } else {
        // Save to pending entries for later sync
        final prefs = await SharedPreferences.getInstance();
        final pendingEntries =
            prefs.getStringList('pending_food_entries') ?? [];
        pendingEntries.add(entry.toJson().toString());
        await prefs.setStringList('pending_food_entries', pendingEntries);
      }

      // Update local state immediately for better UX
      _foodEntries.insert(0, entry);
      _foodEntriesController.add(_foodEntries);
      updateDailySummary();
      _updateMacroBreakdown();
    } catch (e) {
      print('Error saving food entry: $e');
      rethrow;
    }
  }

  /// Update user preferences with offline support
  Future<void> updateUserPreferences(UserPreferences preferences) async {
    if (_currentUser == null) return;

    try {
      if (_isOnline) {
        await _firebaseService.saveUserPreferences(
            _currentUser!.uid, preferences);
      }

      // Update local state immediately
      _userPreferences = preferences;
      _preferencesController.add(_userPreferences);
      _cacheUserPreferences();
    } catch (e) {
      print('Error updating preferences: $e');
      rethrow;
    }
  }

  /// Update user goals with offline support
  Future<void> updateUserGoals(UserGoals goals) async {
    if (_currentUser == null) return;

    print('=== APPSATE SERVICE UPDATE USER GOALS ===');
    print('Updating goals: ${goals.toMap()}');

    try {
      if (_isOnline) {
        await _firebaseService.saveUserGoals(_currentUser!.uid, goals);
        print('Goals saved to Firestore successfully');
      }

      // Update local state immediately
      _userGoals = goals;
      _goalsController.add(_userGoals);
      print('Goals broadcasted via stream controller');
      _cacheUserGoals();
      updateDailySummary(); // Recalculate daily summary with new goals
      print('Daily summary updated with new goals');
    } catch (e) {
      print('Error updating goals: $e');
      rethrow;
    }
    print('=== END APPSATE SERVICE UPDATE USER GOALS ===');
  }

  /// Force goals update to trigger immediate UI refresh
  void forceGoalsUpdate(UserGoals goals) {
    if (_currentUser == null) return;

    print('=== FORCE GOALS UPDATE ===');
    print('Forcing goals update: ${goals.toMap()}');

    // Update local state immediately
    _userGoals = goals;
    _goalsController.add(_userGoals);
    print('Goals broadcasted via stream controller');
    _cacheUserGoals();
    updateDailySummary(); // Recalculate daily summary with new goals
    print('Daily summary updated with new goals');
    print('=== END FORCE GOALS UPDATE ===');
  }

  /// Force update profile data
  void forceProfileDataUpdate(Map<String, dynamic> profileData) {
    _profileData = profileData;
    _profileDataController.add(_profileData);
    _cacheProfileData();
    print('Profile data force updated: $_profileData');
  }

  /// Refresh all user data to ensure UI is up to date
  Future<void> refreshUserData() async {
    if (_currentUser == null) return;

    try {
      print('=== REFRESHING USER DATA ===');
      
      // Force refresh all data streams
      await _loadCachedData();
      
      // Trigger a fresh daily summary calculation
      updateDailySummary();
      
      // Force broadcast current state to all listeners
      _userController.add(_currentUser);
      _foodEntriesController.add(_foodEntries);
      _goalsController.add(_userGoals);
      _preferencesController.add(_userPreferences);
      _dailySummaryController.add(_dailySummary);
      _macroBreakdownController.add(_macroBreakdown);
      _achievementsController.add(_achievements);
      _profileDataController.add(_profileData);
      
      print('User data refreshed successfully');
      print('=== END REFRESHING USER DATA ===');
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  /// Delete food entry
  Future<void> deleteFoodEntry(String entryId) async {
    if (_currentUser == null) return;

    try {
      if (_isOnline) {
        await _firebaseService.deleteFoodEntry(_currentUser!.uid, entryId);
      }

      // Update local state immediately
      _foodEntries.removeWhere((entry) => entry.id == entryId);
      _foodEntriesController.add(_foodEntries);
      updateDailySummary();
      _updateMacroBreakdown();
    } catch (e) {
      print('Error deleting food entry: $e');
      rethrow;
    }
  }

  /// Clear user data when user logs out
  void _clearUserData() {
    _foodEntries = [];
    _userGoals = null;
    _userPreferences = const UserPreferences();
    _dailySummary = null;
    _macroBreakdown =
        MacroBreakdown(carbs: 0, protein: 0, fat: 0, fiber: 0, sugar: 0);
    _achievements = [];

    _foodEntriesController.add(_foodEntries);
    _goalsController.add(_userGoals);
    _preferencesController.add(_userPreferences);
    _dailySummaryController.add(_dailySummary);
    _macroBreakdownController.add(_macroBreakdown);
    _achievementsController.add(_achievements);
    // Health data removed

    // Cancel all subscriptions
    _foodEntriesSubscription?.cancel();
    _goalsSubscription?.cancel();
    _preferencesSubscription?.cancel();
    _achievementsSubscription?.cancel();
  }

  /// Dispose resources
  void dispose() {
    _authSubscription?.cancel();
    _foodEntriesSubscription?.cancel();
    _goalsSubscription?.cancel();
    _preferencesSubscription?.cancel();
    _achievementsSubscription?.cancel();
    _profileDataSubscription?.cancel();

    _userController.close();
    _foodEntriesController.close();
    _goalsController.close();
    _preferencesController.close();
    _dailySummaryController.close();
    _macroBreakdownController.close();
    _achievementsController.close();
    _isOnlineController.close();
    _profileDataController.close();
  }
}
