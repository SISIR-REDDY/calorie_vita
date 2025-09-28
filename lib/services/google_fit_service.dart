import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for integrating with Google Fit API
/// Handles authentication and data retrieval for fitness metrics
class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  // Google Fit API configuration
  static const String _fitnessApiScope =
      'https://www.googleapis.com/auth/fitness.activity.read';
  static const String _fitnessBodyScope =
      'https://www.googleapis.com/auth/fitness.body.read';
  static const String _fitnessLocationScope =
      'https://www.googleapis.com/auth/fitness.location.read';

  // API endpoints
  static const String _baseUrl = 'https://www.googleapis.com/fitness/v1';

  GoogleSignIn? _googleSignIn;
  AuthClient? _authClient;
  bool _isAuthenticated = false;

  /// Check if device has network connectivity
  Future<bool> _hasNetworkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      _logger.w('Error checking connectivity: $e');
      return false;
    }
  }

  /// Handle network errors with user-friendly messages
  void _handleNetworkError(String operation, dynamic error) {
    if (error.toString().contains('SocketException') || 
        error.toString().contains('Failed host lookup')) {
      _logger.w('$operation failed: No internet connection');
    } else if (error.toString().contains('timeout')) {
      _logger.w('$operation failed: Request timeout');
    } else {
      _logger.e('$operation failed: $error');
    }
  }

  // Live sync properties
  Timer? _liveSyncTimer;
  StreamController<Map<String, dynamic>>? _liveDataController;
  bool _isLiveSyncing = false;
  bool _isSyncInProgress = false;

  /// Initialize Google Fit service with Google Sign-In (enhanced for RAM clearing)
  Future<void> initialize() async {
    try {
      print('🚀 GoogleFitService: Initializing...');
      _googleSignIn = GoogleSignIn(
        scopes: [
          _fitnessApiScope,
          _fitnessBodyScope,
          _fitnessLocationScope,
        ],
      );
      print('✅ GoogleFitService: GoogleSignIn configured');

      // Always check for persistent authentication on initialization
      print('🔐 GoogleFitService: Checking persistent authentication...');
      await _checkPersistentAuthentication();
      print('📡 GoogleFitService: Authentication status: $_isAuthenticated');

      _logger.i('Google Fit service initialized');
      print('✅ GoogleFitService: Initialization complete');
    } catch (e) {
      _logger.e('Failed to initialize Google Fit service: $e');
      print('❌ GoogleFitService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Check for persistent authentication (handles RAM clearing)
  Future<void> _checkPersistentAuthentication() async {
    try {
      if (_googleSignIn == null) {
        print('❌ GoogleFitService: GoogleSignIn is null');
        return;
      }

      // If already authenticated and client exists, skip re-authentication
      if (_isAuthenticated &&
          _authClient != null &&
          _googleSignIn!.currentUser != null) {
        _logger
            .d('Google Fit already authenticated, skipping re-authentication');
        print('✅ GoogleFitService: Already authenticated, skipping re-auth');
        return;
      }

      // Try silent sign-in first
      print('🔍 GoogleFitService: Attempting silent sign-in...');
      final currentUser = await _googleSignIn!.signInSilently();
      if (currentUser != null) {
        _isAuthenticated = true;
        _logger.i('Google Fit persistent authentication restored');
        print('✅ GoogleFitService: Silent sign-in successful');

        // Initialize HTTP client with restored authentication
        print('🔧 GoogleFitService: Initializing auth client...');
        await _initializeAuthClient();

        // Wait a moment for authentication to fully establish
        await Future.delayed(const Duration(milliseconds: 500));

        // Start live sync immediately if authenticated
        if (!_isLiveSyncing) {
          print('🔄 GoogleFitService: Starting live sync...');
          startLiveSync();
        }
        return;
      } else {
        print('⚠️ GoogleFitService: Silent sign-in failed - user not signed in');
      }

      // If silent sign-in fails, try to get current sign-in status
      final isSignedIn = await _googleSignIn!.isSignedIn();
      if (isSignedIn) {
        // Verify authentication by getting current user
        final user = _googleSignIn!.currentUser;
        if (user != null) {
          _isAuthenticated = true;
          _logger.i('Google Fit authentication status restored');

          // Initialize HTTP client with restored authentication
          await _initializeAuthClient();

          // Wait a moment for authentication to fully establish
          await Future.delayed(const Duration(milliseconds: 500));

          // Start live sync immediately if authenticated
          if (!_isLiveSyncing) {
            startLiveSync();
          }
        } else {
          _isAuthenticated = false;
          _logger.d('Google Fit user is null despite being signed in');
        }
      } else {
        _isAuthenticated = false;
        _logger.d('No persistent Google Fit authentication found');
      }
    } catch (e) {
      _isAuthenticated = false;
      _logger.e('Error checking persistent authentication: $e');
    }
  }

  /// Enhanced authentication validation with retry mechanism
  Future<bool> validateAuthenticationWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔍 GoogleFitService: Authentication validation attempt $attempt/$maxRetries');
        
        if (_googleSignIn == null) {
          print('❌ GoogleFitService: GoogleSignIn is null');
          return false;
        }

        // Check if we're already authenticated with valid client
        if (_isAuthenticated && _authClient != null && _googleSignIn!.currentUser != null) {
          // Test the connection with a simple API call
          try {
            await getDailySteps(DateTime.now()).timeout(const Duration(seconds: 5));
            print('✅ GoogleFitService: Authentication validated with API test');
            return true;
          } catch (e) {
            print('⚠️ GoogleFitService: API test failed, re-authenticating...');
            _isAuthenticated = false;
            _authClient = null;
          }
        }

        // Try to restore authentication
        final isSignedIn = await _googleSignIn!.isSignedIn();
        if (!isSignedIn) {
          print('❌ GoogleFitService: Not signed in');
          _isAuthenticated = false;
          _authClient = null;
          return false;
        }

        // Get current user and reinitialize client
        final currentUser = _googleSignIn!.currentUser;
        if (currentUser != null) {
          _isAuthenticated = true;
          await _initializeAuthClient();
          
          // Test the connection
          try {
            await getDailySteps(DateTime.now()).timeout(const Duration(seconds: 5));
            print('✅ GoogleFitService: Authentication restored and validated');
            return true;
          } catch (e) {
            print('⚠️ GoogleFitService: API test failed after re-initialization');
            if (attempt < maxRetries) {
              await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
              continue;
            }
          }
        }

        return false;
      } catch (e) {
        print('❌ GoogleFitService: Authentication validation error (attempt $attempt): $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    
    print('❌ GoogleFitService: All authentication validation attempts failed');
    _isAuthenticated = false;
    _authClient = null;
    return false;
  }

  /// Authenticate user with Google Fit
  Future<bool> authenticate() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }

      final GoogleSignInAccount? account = await _googleSignIn!.signIn();
      if (account == null) {
        _logger.w('User cancelled Google Sign-In');
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      if (auth.accessToken == null) {
        _logger.e('Failed to get access token');
        return false;
      }

      // Create authenticated HTTP client
      _authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', auth.accessToken!,
              DateTime.now().toUtc().add(const Duration(hours: 1))),
          auth.idToken,
          _getScopes(),
        ),
      );

      _isAuthenticated = true;
      _logger.i('Successfully authenticated with Google Fit');
      return true;
    } catch (e) {
      _logger.e('Authentication failed: $e');
      _isAuthenticated = false;
      return false;
    }
  }

  /// Get list of required scopes
  List<String> _getScopes() => [
        _fitnessApiScope,
        _fitnessBodyScope,
        _fitnessLocationScope,
      ];

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Get current connection status without triggering authentication
  bool get isConnected =>
      _isAuthenticated &&
      _authClient != null &&
      _googleSignIn?.currentUser != null;

  /// Sign out from Google Fit with complete cleanup
  Future<void> signOut() async {
    try {
      print('🔌 GoogleFitService: Starting sign out process...');
      
      // Stop live sync first
      stopLiveSync();
      
      // Close HTTP client
      if (_authClient != null) {
        _authClient!.close();
        _authClient = null;
        print('🔌 GoogleFitService: HTTP client closed');
      }
      
      // Sign out from Google Sign-In
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
        print('🔌 GoogleFitService: Google Sign-In signed out');
      }
      
      // Reset authentication state
      _isAuthenticated = false;
      
      // Clear any cached data
      _liveDataController?.close();
      _liveDataController = null;
      
      _logger.i('Signed out from Google Fit');
      print('✅ GoogleFitService: Sign out completed successfully');
    } catch (e) {
      _logger.e('Sign out failed: $e');
      print('❌ GoogleFitService: Sign out error: $e');
      
      // Force reset state even if sign out fails
      _isAuthenticated = false;
      _authClient = null;
      _liveDataController?.close();
      _liveDataController = null;
    }
  }

  /// Get daily step count for a specific date
  Future<int?> getDailySteps(DateTime date) async {
    if (!_isAuthenticated ||
        _authClient == null ||
        _googleSignIn?.currentUser == null) {
      _logger.w('Not authenticated with Google Fit');
      return null;
    }

    // Check network connectivity first
    if (!await _hasNetworkConnection()) {
      _logger.w('No network connection available for Google Fit API');
      return null;
    }

    // Validate date
    if (date.isAfter(DateTime.now())) {
      _logger.w('Cannot get steps for future date');
      return null;
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      const url = '$_baseUrl/users/me/dataset:aggregate';

      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.step_count.delta',
            'dataSourceId':
                'derived:com.google.step_count.delta:com.google.android.gms:estimated_steps'
          }
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 24 hours
        'startTimeMillis': startOfDay.millisecondsSinceEpoch.toString(),
        'endTimeMillis': endOfDay.millisecondsSinceEpoch.toString(),
      };

      // Validate client before making request
      if (_authClient == null) {
        _logger.w('HTTP client is null, cannot make request');
        return null;
      }

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buckets = data['bucket'] as List?;

        if (buckets != null && buckets.isNotEmpty) {
          final dataset = buckets.first['dataset'] as List;
          if (dataset.isNotEmpty) {
            final dataPoint = dataset.first['point'] as List;
            if (dataPoint.isNotEmpty) {
              final value = dataPoint.first['value'] as List;
              if (value.isNotEmpty) {
                return value.first['intVal'] as int?;
              }
            }
          }
        }
      } else {
        _logger.e(
            'Failed to get steps data: ${response.statusCode} - ${response.body}');
      }

      return null;
    } catch (e) {
      _handleNetworkError('Getting daily steps', e);
      return null;
    }
  }

  /// Get daily calories burned for a specific date
  Future<double?> getDailyCaloriesBurned(DateTime date) async {
    if (!_isAuthenticated ||
        _authClient == null ||
        _googleSignIn?.currentUser == null) {
      _logger.w('Not authenticated with Google Fit');
      return null;
    }

    // Check network connectivity first
    if (!await _hasNetworkConnection()) {
      _logger.w('No network connection available for Google Fit API');
      return null;
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      const url = '$_baseUrl/users/me/dataset:aggregate';

      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.calories.expended',
            'dataSourceId':
                'derived:com.google.calories.expended:com.google.android.gms:merge_calories_expended'
          }
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 24 hours
        'startTimeMillis': startOfDay.millisecondsSinceEpoch.toString(),
        'endTimeMillis': endOfDay.millisecondsSinceEpoch.toString(),
      };

      // Validate client before making request
      if (_authClient == null) {
        _logger.w('HTTP client is null, cannot make request');
        return null;
      }

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buckets = data['bucket'] as List?;

        if (buckets != null && buckets.isNotEmpty) {
          final dataset = buckets.first['dataset'] as List;
          if (dataset.isNotEmpty) {
            final dataPoint = dataset.first['point'] as List;
            if (dataPoint.isNotEmpty) {
              final value = dataPoint.first['value'] as List;
              if (value.isNotEmpty) {
                return (value.first['fpVal'] as num?)?.toDouble();
              }
            }
          }
        }
      } else {
        _logger.e(
            'Failed to get calories data: ${response.statusCode} - ${response.body}');
      }

      return null;
    } catch (e) {
      _handleNetworkError('Getting daily calories burned', e);
      return null;
    }
  }

  /// Get workout sessions for a specific date
  Future<int?> getWorkoutSessions(DateTime date) async {
    if (!_isAuthenticated ||
        _authClient == null ||
        _googleSignIn?.currentUser == null) {
      _logger.w('Not authenticated with Google Fit');
      return null;
    }

    // Check network connectivity first
    if (!await _hasNetworkConnection()) {
      _logger.w('No network connection available for Google Fit API');
      return null;
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      const url = '$_baseUrl/users/me/dataset:aggregate';

      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.activity.segment',
            'dataSourceId':
                'derived:com.google.activity.segment:com.google.android.gms:merge_activity_segments'
          }
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 24 hours
        'startTimeMillis': startOfDay.millisecondsSinceEpoch.toString(),
        'endTimeMillis': endOfDay.millisecondsSinceEpoch.toString(),
      };

      // Validate client before making request
      if (_authClient == null) {
        _logger.w('HTTP client is null, cannot make request');
        return null;
      }

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buckets = data['bucket'] as List?;

        if (buckets != null && buckets.isNotEmpty) {
          final dataset = buckets.first['dataset'] as List;
          if (dataset.isNotEmpty) {
            final dataPoint = dataset.first['point'] as List;
            if (dataPoint.isNotEmpty) {
              // Count workout sessions (activities other than still, sleeping, etc.)
              int workoutCount = 0;
              for (final point in dataPoint) {
                final values = point['value'] as List?;
                if (values != null && values.isNotEmpty) {
                  final value = values.first;
                  final activityType = value['intVal'] as int?;
                  
                  // Activity types that count as workouts
                  if (activityType != null && 
                      activityType != 0 && // still
                      activityType != 72 && // sleeping
                      activityType != 109) { // unknown
                    workoutCount++;
                  }
                }
              }
              return workoutCount;
            }
          }
        }
      } else {
        _logger.e(
            'Failed to get workout sessions data: ${response.statusCode} - ${response.body}');
      }

      return null;
    } catch (e) {
      _handleNetworkError('Getting workout sessions', e);
      return null;
    }
  }


  /// Get fitness data for a date range
  Future<Map<String, dynamic>?> getFitnessData(
      DateTime startDate, DateTime endDate) async {
    if (!_isAuthenticated || _authClient == null) {
      _logger.w('Not authenticated with Google Fit');
      return null;
    }

    try {
      final steps = await getDailySteps(startDate);
      final calories = await getDailyCaloriesBurned(startDate);
      final workoutSessions = await getWorkoutSessions(startDate);

      return {
        'steps': steps,
        'caloriesBurned': calories,
        'workoutSessions': workoutSessions,
        'date': startDate.toIso8601String().split('T')[0],
      };
    } catch (e) {
      _logger.e('Error getting fitness data: $e');
      return null;
    }
  }

  /// Get weekly fitness summary
  Future<List<Map<String, dynamic>>> getWeeklyFitnessData() async {
    final List<Map<String, dynamic>> weeklyData = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final data = await getFitnessData(date, date);
      if (data != null) {
        weeklyData.add(data);
      }
    }

    return weeklyData;
  }

  /// Start live sync for real-time data updates (optimized for speed)
  void startLiveSync() {
    if (!_isAuthenticated || _isLiveSyncing) return;

    _isLiveSyncing = true;
    _liveDataController = StreamController<Map<String, dynamic>>.broadcast();

    // Sync every 2 minutes to reduce API calls
    _liveSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _performLiveSync();
    });

    // Initial sync
    _performLiveSync();

    _logger.i('Live sync started with 2-minute intervals to reduce API calls');
  }

  /// Stop live sync
  void stopLiveSync() {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
    _liveDataController?.close();
    _liveDataController = null;
    _isLiveSyncing = false;

    _logger.i('Live sync stopped');
  }

  /// Get live data stream
  Stream<Map<String, dynamic>>? get liveDataStream =>
      _liveDataController?.stream;

  /// Check if live sync is active
  bool get isLiveSyncing => _isLiveSyncing;

  /// Initialize HTTP client with authentication
  Future<void> _initializeAuthClient() async {
    try {
      // Always create a fresh client to avoid stale connections
      if (_authClient != null) {
        _authClient!.close();
        _authClient = null;
      }

      if (_googleSignIn?.currentUser == null) {
        _logger.w('No authenticated user for HTTP client initialization');
        return;
      }

      final auth = await _googleSignIn!.currentUser!.authentication;
      
      // Validate access token
      if (auth.accessToken == null || auth.accessToken!.isEmpty) {
        _logger.w('Invalid access token');
        return;
      }

      _authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', auth.accessToken!,
              DateTime.now().toUtc().add(const Duration(hours: 1))),
          auth.idToken,
          [
            'https://www.googleapis.com/auth/fitness.activity.read',
            'https://www.googleapis.com/auth/fitness.body.read',
            'https://www.googleapis.com/auth/fitness.location.read',
          ],
        ),
      );
      _logger.i('HTTP client initialized with authentication');
    } catch (e) {
      _logger.e('Failed to initialize HTTP client: $e');
      _authClient = null;
    }
  }

  /// Get authentication status with validation
  Future<bool> validateAuthentication() async {
    if (_googleSignIn == null) return false;

    try {
      // First check if we're already authenticated with valid client
      if (_isAuthenticated &&
          _authClient != null &&
          _googleSignIn!.currentUser != null) {
        _logger.d('Google Fit authentication already validated');
        return true;
      }

      // Check if user is signed in without triggering new authentication
      final isSignedIn = await _googleSignIn!.isSignedIn();
      if (!isSignedIn) {
        _isAuthenticated = false;
        _authClient = null;
        return false;
      }

      // Get current user without forcing sign-in
      final currentUser = _googleSignIn!.currentUser;
      if (currentUser != null) {
        _isAuthenticated = true;
        // Ensure HTTP client is initialized
        if (_authClient == null) {
          await _initializeAuthClient();
        }
        return true;
      } else {
        // Try silent sign-in as last resort
        final silentUser = await _googleSignIn!.signInSilently();
        if (silentUser != null) {
          _isAuthenticated = true;
          if (_authClient == null) {
            await _initializeAuthClient();
          }
          return true;
        }
      }

      _isAuthenticated = false;
      _authClient = null;
      return false;
    } catch (e) {
      _logger.e('Authentication validation error: $e');
      // Don't immediately invalidate authentication on error
      // Return current state if we were authenticated before
      return _isAuthenticated && _authClient != null;
    }
  }

  /// Perform live sync operation (optimized for speed with throttling)
  Future<void> _performLiveSync() async {
    if (!_isAuthenticated || _liveDataController == null || _isSyncInProgress) return;

    _isSyncInProgress = true;
    try {
      final today = DateTime.now();

      // Batch API calls for faster response with longer timeout
      final futures = await Future.wait([
        getDailySteps(today),
        getDailyCaloriesBurned(today),
        getWorkoutSessions(today),
      ]).timeout(
          const Duration(seconds: 8)); // Increased timeout for reliability

      final steps = futures[0] as int? ?? 0;
      final calories = futures[1] as double? ?? 0.0;
      final workoutSessions = futures[2] as int? ?? 0;

      // Create live data package
      final liveData = {
        'timestamp': DateTime.now().toIso8601String(),
        'steps': steps,
        'caloriesBurned': calories,
        'workoutSessions': workoutSessions,
        'activityLevel': _calculateActivityLevel(steps),
        'isLive': true,
        'cached': false, // Mark as fresh data
      };

      // Emit live data immediately
      if (!_liveDataController!.isClosed) {
        _liveDataController!.add(liveData);
      }

      _logger.d('Live sync completed: Steps=$steps, Calories=$calories');
    } catch (e) {
      _logger.e('Live sync failed: $e');

      // Emit error data but don't mark as live to avoid UI disruption
      if (!_liveDataController!.isClosed) {
        _liveDataController!.add({
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'isLive': false, // Don't disrupt UI on error
        });
      }
    } finally {
      _isSyncInProgress = false;
    }
  }

  /// Calculate activity level based on steps
  String _calculateActivityLevel(int? steps) {
    if (steps == null) return 'Unknown';

    if (steps < 5000) return 'Low';
    if (steps < 10000) return 'Moderate';
    if (steps < 15000) return 'Active';
    return 'Very Active';
  }

  /// Get current live data (cached)
  Map<String, dynamic>? getCurrentLiveData() {
    // This could be enhanced to cache the last live data
    return null;
  }

  /// Get all fitness data for today in a single optimized call
  Future<Map<String, dynamic>?> getTodayFitnessDataBatch() async {
    if (!_isAuthenticated || _authClient == null) {
      _logger.w('Not authenticated with Google Fit for batch request');
      return null;
    }

    try {
      final today = DateTime.now();

      // Use Future.wait with individual error handling to prevent one failure from stopping all
      final results = await Future.wait([
        getDailySteps(today).catchError((e) {
          _logger.w('Steps fetch failed: $e');
          return null;
        }),
        getDailyCaloriesBurned(today).catchError((e) {
          _logger.w('Calories fetch failed: $e');
          return null;
        }),
        getWorkoutSessions(today).catchError((e) {
          _logger.w('Workout sessions fetch failed: $e');
          return null;
        }),
      ], eagerError: false);

      return {
        'timestamp': today.toIso8601String(),
        'steps': results[0] as int?,
        'caloriesBurned': results[1] as double?,
        'workoutSessions': results[2] as int?,
        'activityLevel': _calculateActivityLevel(results[0] as int?),
      };
    } catch (e) {
      _logger.e('Batch fitness data fetch failed: $e');
      return null;
    }
  }
}
