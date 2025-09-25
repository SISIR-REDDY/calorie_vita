import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/google_fit_data.dart';

/// Optimized Google Fit Service focused on steps, calories, and workout detection
/// Removes unnecessary data fetching for distance, weight, height
class OptimizedGoogleFitWorkoutService {
  static final OptimizedGoogleFitWorkoutService _instance = OptimizedGoogleFitWorkoutService._internal();
  factory OptimizedGoogleFitWorkoutService() => _instance;
  OptimizedGoogleFitWorkoutService._internal();

  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  // Google Fit API configuration - Only essential scopes
  static const String _fitnessApiScope = 'https://www.googleapis.com/auth/fitness.activity.read';
  static const String _fitnessBodyScope = 'https://www.googleapis.com/auth/fitness.body.read';

  // API endpoints
  static const String _baseUrl = 'https://www.googleapis.com/fitness/v1';

  GoogleSignIn? _googleSignIn;
  AuthClient? _authClient;
  bool _isAuthenticated = false;

  // Live sync properties
  Timer? _liveSyncTimer;
  StreamController<Map<String, dynamic>>? _liveDataController;
  bool _isLiveSyncing = false;
  bool _isSyncInProgress = false;

  // Data cache for faster access
  final Map<String, GoogleFitData> _dataCache = {};
  DateTime? _lastCacheUpdate;

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

  /// Initialize the optimized service
  Future<void> initialize() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: [_fitnessApiScope, _fitnessBodyScope],
      );

      await _checkPersistentAuthentication();
      _logger.i('Optimized Google Fit Workout Service initialized');
    } catch (e) {
      _logger.e('Failed to initialize Optimized Google Fit Workout Service: $e');
      rethrow;
    }
  }

  /// Check for persistent authentication
  Future<void> _checkPersistentAuthentication() async {
    try {
      if (_googleSignIn == null) return;

      if (_isAuthenticated && _authClient != null && _googleSignIn!.currentUser != null) {
        _logger.d('Already authenticated, skipping re-authentication');
        return;
      }

      final currentUser = await _googleSignIn!.signInSilently();
      if (currentUser != null) {
        final auth = await currentUser.authentication;
        _authClient = authenticatedClient(
          http.Client(),
          AccessCredentials(
            AccessToken('Bearer', auth.accessToken!, DateTime.now().add(const Duration(hours: 1))),
            auth.idToken,
            [_fitnessApiScope, _fitnessBodyScope],
          ),
        );
        _isAuthenticated = true;
        _logger.i('Silent authentication successful');
      }
    } catch (e) {
      _logger.w('Silent authentication failed: $e');
    }
  }

  /// Authenticate with Google Fit
  Future<bool> authenticate() async {
    try {
      if (!await _hasNetworkConnection()) {
        _logger.w('No network connection available');
        return false;
      }

      if (_googleSignIn == null) {
        await initialize();
      }

      final user = await _googleSignIn!.signIn();
      if (user == null) {
        _logger.w('User cancelled authentication');
        return false;
      }

      final auth = await user.authentication;
      _authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', auth.accessToken!, DateTime.now().add(const Duration(hours: 1))),
          auth.idToken,
          [_fitnessApiScope, _fitnessBodyScope],
        ),
      );

      _isAuthenticated = true;
      _logger.i('Authentication successful');
      return true;
    } catch (e) {
      _logger.e('Authentication failed: $e');
      return false;
    }
  }

  /// Sign out from Google Fit
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _authClient?.close();
      _authClient = null;
      _isAuthenticated = false;
      _dataCache.clear();
      _lastCacheUpdate = null;
      _logger.i('Signed out successfully');
    } catch (e) {
      _logger.e('Sign out failed: $e');
    }
  }

  /// Get today's fitness data - Optimized for steps, calories, and workouts only
  Future<GoogleFitData?> getTodayFitnessData() async {
    if (!_isAuthenticated || _authClient == null) {
      _logger.w('Not authenticated');
      return null;
    }

    try {
      if (!await _hasNetworkConnection()) {
        _logger.w('No network connection, returning cached data');
        return _getCachedData('today');
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Fetch data in parallel for better performance
      final futures = await Future.wait([
        _getStepsData(startOfDay, endOfDay),
        _getCaloriesData(startOfDay, endOfDay),
        _getWorkoutData(startOfDay, endOfDay),
      ]);

      final steps = futures[0] as int;
      final calories = futures[1] as double;
      final workoutData = futures[2] as Map<String, dynamic>;

      final data = GoogleFitData(
        date: today,
        steps: steps,
        caloriesBurned: calories,
        workoutSessions: workoutData['sessions'],
        workoutDuration: workoutData['duration'],
      );

      // Cache the data
      _cacheData('today', data);
      
      _logger.i('Today\'s fitness data loaded: Steps=$steps, Calories=$calories, Workouts=${workoutData['sessions']}');
      return data;
    } catch (e) {
      _logger.e('Failed to get today\'s fitness data: $e');
      return _getCachedData('today');
    }
  }

  /// Get steps data for a specific time range
  Future<int> _getStepsData(DateTime start, DateTime end) async {
    try {
      final url = '$_baseUrl/users/me/dataset:aggregate';
      final requestBody = {
        'aggregateBy': [
          {'dataTypeName': 'com.google.step_count.delta'}
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 1 day
        'startTimeMillis': start.millisecondsSinceEpoch,
        'endTimeMillis': end.millisecondsSinceEpoch,
      };

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final buckets = data['bucket'] as List? ?? [];
        
        int totalSteps = 0;
        for (final bucket in buckets) {
          final datasets = bucket['dataset'] as List? ?? [];
          for (final dataset in datasets) {
            final points = dataset['point'] as List? ?? [];
            for (final point in points) {
              final values = point['value'] as List? ?? [];
              for (final value in values) {
                totalSteps += (value['intVal'] as int? ?? 0);
              }
            }
          }
        }
        
        return totalSteps;
      } else {
        _logger.w('Steps API returned status: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      _logger.e('Failed to get steps data: $e');
      return 0;
    }
  }

  /// Get calories data for a specific time range
  Future<double> _getCaloriesData(DateTime start, DateTime end) async {
    try {
      final url = '$_baseUrl/users/me/dataset:aggregate';
      final requestBody = {
        'aggregateBy': [
          {'dataTypeName': 'com.google.calories.expended'}
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 1 day
        'startTimeMillis': start.millisecondsSinceEpoch,
        'endTimeMillis': end.millisecondsSinceEpoch,
      };

      final response = await _authClient!.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final buckets = data['bucket'] as List? ?? [];
        
        double totalCalories = 0.0;
        for (final bucket in buckets) {
          final datasets = bucket['dataset'] as List? ?? [];
          for (final dataset in datasets) {
            final points = dataset['point'] as List? ?? [];
            for (final point in points) {
              final values = point['value'] as List? ?? [];
              for (final value in values) {
                totalCalories += (value['fpVal'] as double? ?? 0.0);
              }
            }
          }
        }
        
        return totalCalories;
      } else {
        _logger.w('Calories API returned status: ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      _logger.e('Failed to get calories data: $e');
      return 0.0;
    }
  }

  /// Get workout data for a specific time range
  Future<Map<String, dynamic>> _getWorkoutData(DateTime start, DateTime end) async {
    try {
      final url = '$_baseUrl/users/me/sessions';
      final params = {
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
      };

      final uri = Uri.parse(url).replace(queryParameters: params);
      final response = await _authClient!.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sessions = data['session'] as List? ?? [];
        
        int workoutSessions = 0;
        double totalDuration = 0.0;
        
        for (final session in sessions) {
          final activityType = session['activityType'] as int? ?? 0;
          // Filter for actual workout activities (not sleep, etc.)
          if (activityType >= 1 && activityType <= 100) { // Common workout activity types
            workoutSessions++;
            final startTime = DateTime.parse(session['startTimeMillis'] as String);
            final endTime = DateTime.parse(session['endTimeMillis'] as String);
            totalDuration += endTime.difference(startTime).inMinutes;
          }
        }
        
        return {
          'sessions': workoutSessions,
          'duration': totalDuration,
        };
      } else {
        _logger.w('Workout API returned status: ${response.statusCode}');
        return {'sessions': 0, 'duration': 0.0};
      }
    } catch (e) {
      _logger.e('Failed to get workout data: $e');
      return {'sessions': 0, 'duration': 0.0};
    }
  }

  /// Cache data for faster access
  void _cacheData(String key, GoogleFitData data) {
    _dataCache[key] = data;
    _lastCacheUpdate = DateTime.now();
  }

  /// Get cached data
  GoogleFitData? _getCachedData(String key) {
    final data = _dataCache[key];
    if (data != null && _lastCacheUpdate != null) {
      final age = DateTime.now().difference(_lastCacheUpdate!);
      if (age.inMinutes < 5) { // Cache valid for 5 minutes
        return data;
      }
    }
    return null;
  }

  /// Start live sync for real-time updates
  Future<void> startLiveSync() async {
    if (_isLiveSyncing || !_isAuthenticated) return;

    _isLiveSyncing = true;
    _liveDataController = StreamController<Map<String, dynamic>>.broadcast();

    _liveSyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_isSyncInProgress) return;
      
      _isSyncInProgress = true;
      try {
        final data = await getTodayFitnessData();
        if (data != null && _liveDataController != null && !_liveDataController!.isClosed) {
          _liveDataController!.add({
            'steps': data.steps,
            'caloriesBurned': data.caloriesBurned,
            'workoutSessions': data.workoutSessions,
            'workoutDuration': data.workoutDuration,
            'isLive': true,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } catch (e) {
        _logger.e('Live sync error: $e');
      } finally {
        _isSyncInProgress = false;
      }
    });

    _logger.i('Live sync started');
  }

  /// Stop live sync
  Future<void> stopLiveSync() async {
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
    await _liveDataController?.close();
    _liveDataController = null;
    _isLiveSyncing = false;
    _logger.i('Live sync stopped');
  }

  /// Get live data stream
  Stream<Map<String, dynamic>>? get liveDataStream => _liveDataController?.stream;

  /// Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLiveSyncing => _isLiveSyncing;

  /// Dispose resources
  void dispose() {
    _liveSyncTimer?.cancel();
    _liveDataController?.close();
    _authClient?.close();
  }
}
