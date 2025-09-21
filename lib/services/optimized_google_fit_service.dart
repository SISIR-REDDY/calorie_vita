import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optimized Google Fit service with caching and performance improvements
class OptimizedGoogleFitService {
  static final OptimizedGoogleFitService _instance = OptimizedGoogleFitService._internal();
  factory OptimizedGoogleFitService() => _instance;
  OptimizedGoogleFitService._internal();

  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  // Google Fit API configuration
  static const String _fitnessApiScope = 'https://www.googleapis.com/auth/fitness.activity.read';
  static const String _fitnessBodyScope = 'https://www.googleapis.com/auth/fitness.body.read';
  static const String _fitnessLocationScope = 'https://www.googleapis.com/auth/fitness.location.read';

  // API endpoints
  static const String _baseUrl = 'https://www.googleapis.com/fitness/v1';

  GoogleSignIn? _googleSignIn;
  AuthClient? _authClient;
  bool _isAuthenticated = false;

  // Caching
  static const String _cacheKey = 'google_fit_cache';
  static const String _lastSyncKey = 'google_fit_last_sync';
  static const Duration _cacheValidity = Duration(minutes: 5); // Cache for 5 minutes
  Map<String, dynamic>? _cachedData;
  DateTime? _lastSyncTime;

  // Performance optimization
  bool _isLoading = false;
  Completer<Map<String, dynamic>?>? _loadingCompleter;

  /// Initialize the optimized Google Fit service
  Future<void> initialize() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: [
          _fitnessApiScope,
          _fitnessBodyScope,
          _fitnessLocationScope,
        ],
      );

      await _checkPersistentAuthentication();
      await _loadCachedData();

      _logger.i('Optimized Google Fit service initialized');
    } catch (e) {
      _logger.e('Failed to initialize optimized Google Fit service: $e');
      rethrow;
    }
  }

  /// Check for persistent authentication
  Future<void> _checkPersistentAuthentication() async {
    try {
      if (_googleSignIn == null) return;

      if (_isAuthenticated && _authClient != null && _googleSignIn!.currentUser != null) {
        _logger.d('Google Fit already authenticated, skipping re-authentication');
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
            [_fitnessApiScope, _fitnessBodyScope, _fitnessLocationScope],
          ),
        );
        _isAuthenticated = true;
        _logger.i('Google Fit authenticated silently');
      }
    } catch (e) {
      _logger.w('Silent authentication failed: $e');
    }
  }

  /// Load cached data from SharedPreferences
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(_cacheKey);
      final lastSyncString = prefs.getString(_lastSyncKey);

      if (cachedDataString != null && lastSyncString != null) {
        _cachedData = Map<String, dynamic>.from(jsonDecode(cachedDataString));
        _lastSyncTime = DateTime.parse(lastSyncString);
        _logger.d('Loaded cached Google Fit data');
      }
    } catch (e) {
      _logger.w('Failed to load cached data: $e');
    }
  }

  /// Save data to cache
  Future<void> _saveCachedData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      _cachedData = data;
      _lastSyncTime = DateTime.now();
      _logger.d('Saved Google Fit data to cache');
    } catch (e) {
      _logger.w('Failed to save cached data: $e');
    }
  }

  /// Check if cached data is still valid
  bool _isCacheValid() {
    if (_cachedData == null || _lastSyncTime == null) return false;
    return DateTime.now().difference(_lastSyncTime!) < _cacheValidity;
  }

  /// Check network connectivity
  Future<bool> _hasNetworkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      _logger.w('Error checking connectivity: $e');
      return false;
    }
  }

  /// Get optimized fitness data with caching and parallel requests
  Future<Map<String, dynamic>?> getOptimizedFitnessData() async {
    // Return cached data if valid
    if (_isCacheValid() && _cachedData != null) {
      _logger.d('Returning cached Google Fit data');
      return _cachedData;
    }

    // If already loading, wait for the current request
    if (_isLoading && _loadingCompleter != null) {
      _logger.d('Google Fit data already loading, waiting...');
      return await _loadingCompleter!.future;
    }

    // Start new loading process
    _isLoading = true;
    _loadingCompleter = Completer<Map<String, dynamic>?>();

    try {
      if (!_isAuthenticated || _authClient == null) {
        _logger.w('Not authenticated with Google Fit');
        return _cachedData; // Return cached data if available
      }

      if (!await _hasNetworkConnection()) {
        _logger.w('No network connection, returning cached data');
        return _cachedData;
      }

      final today = DateTime.now();
      final data = await _fetchFitnessDataOptimized(today);

      if (data != null) {
        await _saveCachedData(data);
        _loadingCompleter?.complete(data);
        return data;
      } else {
        _loadingCompleter?.complete(_cachedData);
        return _cachedData;
      }
    } catch (e) {
      _logger.e('Error fetching optimized fitness data: $e');
      _loadingCompleter?.complete(_cachedData);
      return _cachedData;
    } finally {
      _isLoading = false;
      _loadingCompleter = null;
    }
  }

  /// Fetch fitness data with optimized parallel requests
  Future<Map<String, dynamic>?> _fetchFitnessDataOptimized(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Create optimized batch request body
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
            'dataTypeName': 'com.google.distance.delta',
            'dataSourceId': 'derived:com.google.distance.delta:com.google.android.gms:merge_distance_delta'
          }
        ],
        'bucketByTime': {'durationMillis': 86400000}, // 24 hours
        'startTimeMillis': startOfDay.millisecondsSinceEpoch.toString(),
        'endTimeMillis': endOfDay.millisecondsSinceEpoch.toString(),
      };

      // Make single optimized API call
      final response = await _authClient!.post(
        Uri.parse('$_baseUrl/users/me/dataset:aggregate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 3)); // Reduced timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buckets = data['bucket'] as List?;

        if (buckets != null && buckets.isNotEmpty) {
          final bucket = buckets.first;
          final datasets = bucket['dataset'] as List;

          int steps = 0;
          double calories = 0.0;
          double distance = 0.0;

          // Parse all data types from single response
          for (final dataset in datasets) {
            final dataTypeName = dataset['dataSourceId'] as String?;
            final points = dataset['point'] as List?;

            if (points != null && points.isNotEmpty) {
              final point = points.first;
              final values = point['value'] as List?;

              if (values != null && values.isNotEmpty) {
                final value = values.first;

                if (dataTypeName?.contains('step_count') == true) {
                  steps = value['intVal'] as int? ?? 0;
                } else if (dataTypeName?.contains('calories') == true) {
                  calories = (value['fpVal'] as num?)?.toDouble() ?? 0.0;
                } else if (dataTypeName?.contains('distance') == true) {
                  distance = (value['fpVal'] as num?)?.toDouble() ?? 0.0;
                }
              }
            }
          }

          // Get weight separately (less critical, can be cached longer)
          final weight = await _getCurrentWeightOptimized();

          final result = {
            'timestamp': date.toIso8601String(),
            'steps': steps,
            'caloriesBurned': calories,
            'distance': distance,
            'weight': weight,
            'activityLevel': _calculateActivityLevel(steps),
            'cached': false,
          };

          _logger.i('Optimized Google Fit data fetched: Steps=$steps, Calories=$calories, Distance=$distance');
          return result;
        }
      } else {
        _logger.e('Google Fit API error: ${response.statusCode} - ${response.body}');
      }

      return null;
    } catch (e) {
      _logger.e('Error fetching optimized fitness data: $e');
      return null;
    }
  }

  /// Get current weight with caching
  Future<double?> _getCurrentWeightOptimized() async {
    try {
      if (!_isAuthenticated || _authClient == null) return null;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.weight',
            'dataSourceId': 'derived:com.google.weight:com.google.android.gms:merge_weight'
          }
        ],
        'bucketByTime': {'durationMillis': 86400000},
        'startTimeMillis': startOfDay.millisecondsSinceEpoch.toString(),
        'endTimeMillis': endOfDay.millisecondsSinceEpoch.toString(),
      };

      final response = await _authClient!.post(
        Uri.parse('$_baseUrl/users/me/dataset:aggregate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 2)); // Short timeout for weight

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buckets = data['bucket'] as List?;

        if (buckets != null && buckets.isNotEmpty) {
          final datasets = buckets.first['dataset'] as List;
          if (datasets.isNotEmpty) {
            final points = datasets.first['point'] as List;
            if (points.isNotEmpty) {
              final values = points.first['value'] as List;
              if (values.isNotEmpty) {
                return (values.first['fpVal'] as num?)?.toDouble();
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      _logger.w('Error fetching weight: $e');
      return null;
    }
  }

  /// Calculate activity level based on steps
  String _calculateActivityLevel(int? steps) {
    if (steps == null) return 'Unknown';
    if (steps < 5000) return 'Sedentary';
    if (steps < 7500) return 'Lightly Active';
    if (steps < 10000) return 'Moderately Active';
    if (steps < 12500) return 'Active';
    return 'Very Active';
  }

  /// Force refresh data (bypass cache)
  Future<Map<String, dynamic>?> forceRefresh() async {
    _cachedData = null;
    _lastSyncTime = null;
    return await getOptimizedFitnessData();
  }

  /// Get cached data without network request
  Map<String, dynamic>? getCachedData() {
    return _isCacheValid() ? _cachedData : null;
  }

  /// Check if data is currently loading
  bool get isLoading => _isLoading;

  /// Check if user is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Dispose resources
  void dispose() {
    _authClient?.close();
    _googleSignIn?.disconnect();
  }
}
