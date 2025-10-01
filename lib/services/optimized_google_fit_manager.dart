import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/google_fit_data.dart';

/// Optimized Google Fit Manager - Single source of truth
/// Features:
/// - Caching to avoid unnecessary API calls
/// - Batch API requests (1 call instead of 3)
/// - Single timer for background sync
/// - Real-time updates via streams
/// - Instant UI reflection
class OptimizedGoogleFitManager {
  static final OptimizedGoogleFitManager _instance = OptimizedGoogleFitManager._internal();
  factory OptimizedGoogleFitManager() => _instance;
  OptimizedGoogleFitManager._internal();

  // Configuration
  static const String _baseUrl = 'https://www.googleapis.com/fitness/v1';
  static const Duration _cacheValidDuration = Duration(seconds: 30); // Cache for 30 seconds
  static const Duration _syncInterval = Duration(minutes: 2); // Background sync every 2 minutes
  static const Duration _apiTimeout = Duration(seconds: 10);

  // Authentication
  GoogleSignIn? _googleSignIn;
  AuthClient? _authClient;
  bool _isAuthenticated = false;
  final Connectivity _connectivity = Connectivity();

  // State management
  bool _isInitialized = false;
  bool _isSyncing = false;
  GoogleFitData? _cachedData;
  DateTime? _cacheTime;
  Timer? _syncTimer;

  // Stream controllers
  final StreamController<GoogleFitData?> _dataController = StreamController<GoogleFitData?>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<bool> _loadingController = StreamController<bool>.broadcast();

  // Public streams
  Stream<GoogleFitData?> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;

  // Public getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isAuthenticated && _authClient != null && _googleSignIn?.currentUser != null;
  GoogleFitData? get currentData => _cachedData;
  bool get hasValidCache => _cachedData != null && _cacheTime != null && 
      DateTime.now().difference(_cacheTime!) < _cacheValidDuration;

  /// Initialize the manager
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚡ OptimizedGoogleFitManager: Already initialized');
      return;
    }

    try {
      print('🚀 OptimizedGoogleFitManager: Initializing...');
      
      // Initialize Google Sign-In
      _googleSignIn = GoogleSignIn(
        scopes: [
          'https://www.googleapis.com/auth/fitness.activity.read',
          'https://www.googleapis.com/auth/fitness.body.read',
          'https://www.googleapis.com/auth/fitness.location.read',
        ],
      );

      // Check for existing authentication
      await _checkAuthentication();

      if (_isAuthenticated) {
        print('✅ OptimizedGoogleFitManager: Authenticated');
        
        // Load data immediately
        await _syncData(force: true);
        
        // Start background sync
        _startBackgroundSync();
      } else {
        print('⚠️ OptimizedGoogleFitManager: Not authenticated');
      }

      _isInitialized = true;
      _connectionController.add(_isAuthenticated);
      
      print('✅ OptimizedGoogleFitManager: Initialization complete');
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Initialization failed: $e');
      _isInitialized = false;
    }
  }

  /// Check authentication status
  Future<void> _checkAuthentication() async {
    try {
      if (_googleSignIn == null) return;

      // Try silent sign-in first
      final user = await _googleSignIn!.signInSilently();
      if (user != null) {
        _isAuthenticated = true;
        await _initializeAuthClient();
        return;
      }

      // Check if user is already signed in
      final isSignedIn = await _googleSignIn!.isSignedIn();
      if (isSignedIn) {
        final currentUser = _googleSignIn!.currentUser;
        if (currentUser != null) {
          _isAuthenticated = true;
          await _initializeAuthClient();
          return;
        }
      }

      _isAuthenticated = false;
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Authentication check failed: $e');
      _isAuthenticated = false;
    }
  }

  /// Initialize HTTP client
  Future<void> _initializeAuthClient() async {
    try {
      if (_googleSignIn?.currentUser == null) return;

      final auth = await _googleSignIn!.currentUser!.authentication;
      if (auth.accessToken == null) return;

      // Close old client if exists
      _authClient?.close();

      _authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', auth.accessToken!, DateTime.now().toUtc().add(const Duration(hours: 1))),
          auth.idToken,
          [
            'https://www.googleapis.com/auth/fitness.activity.read',
            'https://www.googleapis.com/auth/fitness.body.read',
            'https://www.googleapis.com/auth/fitness.location.read',
          ],
        ),
      );
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Failed to initialize HTTP client: $e');
    }
  }

  /// Authenticate user
  Future<bool> authenticate() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }

      final account = await _googleSignIn!.signIn();
      if (account == null) return false;

      _isAuthenticated = true;
      await _initializeAuthClient();
      
      // Load data immediately after authentication
      await _syncData(force: true);
      
      // Start background sync
      _startBackgroundSync();
      
      _connectionController.add(true);
      
      print('✅ OptimizedGoogleFitManager: Authentication successful');
      return true;
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Authentication failed: $e');
      _isAuthenticated = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      print('🔌 OptimizedGoogleFitManager: Signing out...');
      
      // Stop background sync
      _syncTimer?.cancel();
      
      // Close HTTP client
      _authClient?.close();
      _authClient = null;
      
      // Sign out from Google
      await _googleSignIn?.signOut();
      
      // Clear state
      _isAuthenticated = false;
      _cachedData = null;
      _cacheTime = null;
      
      // Notify listeners
      _connectionController.add(false);
      _dataController.add(null);
      
      print('✅ OptimizedGoogleFitManager: Signed out');
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Sign out failed: $e');
      
      // Force reset
      _isAuthenticated = false;
      _cachedData = null;
      _cacheTime = null;
      _authClient = null;
    }
  }

  /// Sync data with caching
  Future<GoogleFitData?> _syncData({bool force = false}) async {
    // Return cached data if valid and not forced
    if (!force && hasValidCache) {
      print('⚡ OptimizedGoogleFitManager: Using cached data (${DateTime.now().difference(_cacheTime!).inSeconds}s old)');
      return _cachedData;
    }

    // Prevent multiple simultaneous syncs
    if (_isSyncing) {
      print('⚠️ OptimizedGoogleFitManager: Sync already in progress');
      return _cachedData;
    }

    if (!_isAuthenticated || _authClient == null) {
      print('⚠️ OptimizedGoogleFitManager: Not authenticated');
      return null;
    }

    // Check network connectivity
    final hasNetwork = await _hasNetwork();
    if (!hasNetwork) {
      print('⚠️ OptimizedGoogleFitManager: No network connection');
      return _cachedData; // Return cached data if available
    }

    _isSyncing = true;
    _loadingController.add(true);

    try {
      print('🔄 OptimizedGoogleFitManager: Fetching fresh data...');
      
      final data = await _fetchBatchData();
      
      if (data != null) {
        _cachedData = data;
        _cacheTime = DateTime.now();
        
        // Notify listeners
        _dataController.add(data);
        
        print('✅ OptimizedGoogleFitManager: Data synced - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
      }
      
      return data;
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Sync failed: $e');
      return _cachedData; // Return cached data on error
    } finally {
      _isSyncing = false;
      _loadingController.add(false);
    }
  }

  /// Fetch data in a single batch API call (OPTIMIZED)
  Future<GoogleFitData?> _fetchBatchData() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      const url = '$_baseUrl/users/me/dataset:aggregate';

      // Single batched request for all data types
      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.step_count.delta',
            'dataSourceId': 'derived:com.google.step_count.delta:com.google.android.gms:estimated_steps'
          },
          {
            'dataTypeName': 'com.google.calories.expended',
            'dataSourceId': 'derived:com.google.calories.expended:com.google.android.gms:merge_calories_expended'
          },
          {
            'dataTypeName': 'com.google.activity.segment',
            'dataSourceId': 'derived:com.google.activity.segment:com.google.android.gms:merge_activity_segments'
          }
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 24 hours
        'startTimeMillis': startOfDay.millisecondsSinceEpoch.toString(),
        'endTimeMillis': endOfDay.millisecondsSinceEpoch.toString(),
      };

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buckets = data['bucket'] as List?;

        int steps = 0;
        double calories = 0.0;
        int workoutSessions = 0;

        if (buckets != null && buckets.isNotEmpty) {
          final datasets = buckets.first['dataset'] as List;

          // Parse steps (dataset 0)
          if (datasets.isNotEmpty) {
            final stepsDataset = datasets[0]['point'] as List?;
            if (stepsDataset != null && stepsDataset.isNotEmpty) {
              final value = stepsDataset.first['value'] as List?;
              if (value != null && value.isNotEmpty) {
                steps = value.first['intVal'] as int? ?? 0;
              }
            }
          }

          // Parse calories (dataset 1)
          if (datasets.length > 1) {
            final caloriesDataset = datasets[1]['point'] as List?;
            if (caloriesDataset != null && caloriesDataset.isNotEmpty) {
              final value = caloriesDataset.first['value'] as List?;
              if (value != null && value.isNotEmpty) {
                calories = (value.first['fpVal'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }

          // Parse workout sessions (dataset 2)
          if (datasets.length > 2) {
            final activitiesDataset = datasets[2]['point'] as List?;
            if (activitiesDataset != null) {
              for (final point in activitiesDataset) {
                final values = point['value'] as List?;
                if (values != null && values.isNotEmpty) {
                  final activityType = values.first['intVal'] as int?;
                  // Count only actual workouts (not still, sleeping, unknown)
                  if (activityType != null && 
                      activityType != 0 && // still
                      activityType != 72 && // sleeping
                      activityType != 109) { // unknown
                    workoutSessions++;
                  }
                }
              }
            }
          }
        }

        return GoogleFitData(
          date: today,
          steps: steps,
          caloriesBurned: calories,
          workoutSessions: workoutSessions,
          workoutDuration: 0.0, // Duration not included in batch call
        );
      } else {
        print('❌ OptimizedGoogleFitManager: API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ OptimizedGoogleFitManager: Fetch failed: $e');
      return null;
    }
  }

  /// Check network connectivity
  Future<bool> _hasNetwork() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Start background sync timer
  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_isAuthenticated) {
        _syncData(force: false); // Use cache if valid
      }
    });
    print('🔄 OptimizedGoogleFitManager: Background sync started ($_syncInterval)');
  }

  /// Force refresh (public method)
  Future<GoogleFitData?> forceRefresh() async {
    print('🔄 OptimizedGoogleFitManager: Force refresh requested');
    return await _syncData(force: true);
  }

  /// Get current data immediately (cached)
  GoogleFitData? getCurrentData() {
    if (hasValidCache) {
      print('⚡ OptimizedGoogleFitManager: Returning cached data instantly');
      return _cachedData;
    }
    
    // Trigger background sync if cache is stale
    if (_isAuthenticated && !_isSyncing) {
      _syncData(force: false);
    }
    
    return _cachedData;
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _authClient?.close();
    
    if (!_dataController.isClosed) _dataController.close();
    if (!_connectionController.isClosed) _connectionController.close();
    if (!_loadingController.isClosed) _loadingController.close();
    
    print('🗑️ OptimizedGoogleFitManager: Disposed');
  }
}

