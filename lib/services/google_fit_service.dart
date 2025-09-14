import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Service for integrating with Google Fit API
/// Handles authentication and data retrieval for fitness metrics
class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final Logger _logger = Logger();

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

  // Live sync properties
  Timer? _liveSyncTimer;
  StreamController<Map<String, dynamic>>? _liveDataController;
  bool _isLiveSyncing = false;

  /// Initialize Google Fit service with Google Sign-In (enhanced for RAM clearing)
  Future<void> initialize() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: [
          _fitnessApiScope,
          _fitnessBodyScope,
          _fitnessLocationScope,
        ],
      );

      // Always check for persistent authentication on initialization
      await _checkPersistentAuthentication();

      _logger.i('Google Fit service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Google Fit service: $e');
      rethrow;
    }
  }

  /// Check for persistent authentication (handles RAM clearing)
  Future<void> _checkPersistentAuthentication() async {
    try {
      if (_googleSignIn == null) return;

      // If already authenticated and client exists, skip re-authentication
      if (_isAuthenticated &&
          _authClient != null &&
          _googleSignIn!.currentUser != null) {
        _logger
            .d('Google Fit already authenticated, skipping re-authentication');
        return;
      }

      // Try silent sign-in first
      final currentUser = await _googleSignIn!.signInSilently();
      if (currentUser != null) {
        _isAuthenticated = true;
        _logger.i('Google Fit persistent authentication restored');

        // Initialize HTTP client with restored authentication
        await _initializeAuthClient();

        // Wait a moment for authentication to fully establish
        await Future.delayed(const Duration(milliseconds: 500));

        // Start live sync immediately if authenticated
        if (!_isLiveSyncing) {
          startLiveSync();
        }
        return;
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

  /// Sign out from Google Fit
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _authClient?.close();
      _authClient = null;
      _isAuthenticated = false;
      _logger.i('Signed out from Google Fit');
    } catch (e) {
      _logger.e('Sign out failed: $e');
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

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      _logger.e('Error getting daily steps: $e');
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

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

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
      _logger.e('Error getting daily calories burned: $e');
      return null;
    }
  }

  /// Get daily distance traveled for a specific date
  Future<double?> getDailyDistance(DateTime date) async {
    if (!_isAuthenticated ||
        _authClient == null ||
        _googleSignIn?.currentUser == null) {
      _logger.w('Not authenticated with Google Fit');
      return null;
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      const url = '$_baseUrl/users/me/dataset:aggregate';

      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.distance.delta',
            'dataSourceId':
                'derived:com.google.distance.delta:com.google.android.gms:merge_distance_delta'
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
      );

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
                // Convert from meters to kilometers
                final meters =
                    (value.first['fpVal'] as num?)?.toDouble() ?? 0.0;
                return meters / 1000.0;
              }
            }
          }
        }
      } else {
        _logger.e(
            'Failed to get distance data: ${response.statusCode} - ${response.body}');
      }

      return null;
    } catch (e) {
      _logger.e('Error getting daily distance: $e');
      return null;
    }
  }

  /// Get current weight from Google Fit
  Future<double?> getCurrentWeight() async {
    if (!_isAuthenticated || _authClient == null) {
      _logger.w('Not authenticated with Google Fit');
      return null;
    }

    try {
      const url = '$_baseUrl/users/me/dataSources';
      final response = await _authClient!.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dataSources = data['dataSource'] as List?;

        if (dataSources != null) {
          // Find weight data source
          for (final source in dataSources) {
            if (source['dataType']['name'] == 'com.google.weight') {
              final sourceId = source['dataStreamId'] as String;

              // Get latest weight data
              final weightUrl =
                  '$_baseUrl/users/me/dataSources/$sourceId/datasets/latest';
              final weightResponse =
                  await _authClient!.get(Uri.parse(weightUrl));

              if (weightResponse.statusCode == 200) {
                final weightData = jsonDecode(weightResponse.body);
                final points = weightData['point'] as List?;

                if (points != null && points.isNotEmpty) {
                  final latestPoint = points.last;
                  final value = latestPoint['value'] as List;
                  if (value.isNotEmpty) {
                    // Convert from kilograms to the user's preferred unit
                    return (value.first['fpVal'] as num?)?.toDouble();
                  }
                }
              }
              break;
            }
          }
        }
      }

      return null;
    } catch (e) {
      _logger.e('Error getting current weight: $e');
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
      final distance = await getDailyDistance(startDate);

      return {
        'steps': steps,
        'caloriesBurned': calories,
        'distance': distance,
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

    // Sync every 10 seconds for faster updates
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _performLiveSync();
    });

    // Initial sync
    _performLiveSync();

    _logger.i('Live sync started with 10-second intervals for faster updates');
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
      // Don't recreate client if it already exists and is valid
      if (_authClient != null && _googleSignIn?.currentUser != null) {
        _logger.d('HTTP client already exists and is valid');
        return;
      }

      if (_googleSignIn?.currentUser == null) {
        _logger.w('No authenticated user for HTTP client initialization');
        return;
      }

      final auth = await _googleSignIn!.currentUser!.authentication;
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

  /// Perform live sync operation (optimized for speed)
  Future<void> _performLiveSync() async {
    if (!_isAuthenticated || _liveDataController == null) return;

    try {
      final today = DateTime.now();

      // Batch API calls for faster response with longer timeout
      final futures = await Future.wait([
        getDailySteps(today),
        getDailyCaloriesBurned(today),
        getDailyDistance(today),
      ]).timeout(
          const Duration(seconds: 8)); // Increased timeout for reliability

      final steps = futures[0] as int? ?? 0;
      final calories = futures[1] as double? ?? 0.0;
      final distance = futures[2] as double? ?? 0.0;

      // Create live data package
      final liveData = {
        'timestamp': DateTime.now().toIso8601String(),
        'steps': steps,
        'caloriesBurned': calories,
        'distance': distance,
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
        getDailyDistance(today).catchError((e) {
          _logger.w('Distance fetch failed: $e');
          return null;
        }),
        getCurrentWeight().catchError((e) {
          _logger.w('Weight fetch failed: $e');
          return null;
        }),
      ], eagerError: false);

      return {
        'timestamp': today.toIso8601String(),
        'steps': results[0] as int?,
        'caloriesBurned': results[1] as double?,
        'distance': results[2] as double?,
        'weight': results[3] as double?,
        'activityLevel': _calculateActivityLevel(results[0] as int?),
      };
    } catch (e) {
      _logger.e('Batch fitness data fetch failed: $e');
      return null;
    }
  }
}
