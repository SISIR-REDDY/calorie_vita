import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enhanced Google Fit service with robust connection management and data updates
class EnhancedGoogleFitService {
  static final EnhancedGoogleFitService _instance = EnhancedGoogleFitService._internal();
  factory EnhancedGoogleFitService() => _instance;
  EnhancedGoogleFitService._internal();

  final Logger _logger = Logger();
  final Connectivity _connectivity = Connectivity();

  // Google Fit API configuration
  static const String _fitnessApiScope = 'https://www.googleapis.com/auth/fitness.activity.read';
  static const String _fitnessBodyScope = 'https://www.googleapis.com/auth/fitness.body.read';
  static const String _fitnessLocationScope = 'https://www.googleapis.com/auth/fitness.location.read';
  static const String _fitnessNutritionScope = 'https://www.googleapis.com/auth/fitness.nutrition.read';

  // API endpoints
  static const String _baseUrl = 'https://www.googleapis.com/fitness/v1';

  GoogleSignIn? _googleSignIn;
  AuthClient? _authClient;
  bool _isAuthenticated = false;
  bool _isInitialized = false;

  // Connection management
  Timer? _connectionCheckTimer;
  Timer? _dataRefreshTimer;
  StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  StreamController<Map<String, dynamic>> _dataController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Retry mechanism
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  static const Duration _connectionCheckInterval = Duration(minutes: 2);
  static const Duration _dataRefreshInterval = Duration(minutes: 5);

  // Getters
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  bool get isAuthenticated => _isAuthenticated;
  bool get isConnected => _isAuthenticated && _authClient != null && _googleSignIn?.currentUser != null;

  /// Initialize the enhanced Google Fit service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('🔧 EnhancedGoogleFitService: Initializing...');

      _googleSignIn = GoogleSignIn(
        scopes: [
          _fitnessApiScope,
          _fitnessBodyScope,
          _fitnessLocationScope,
          _fitnessNutritionScope,
        ],
      );

      // Check for existing authentication
      await _checkExistingAuthentication();

      // Start connection monitoring
      _startConnectionMonitoring();

      _isInitialized = true;
      _logger.i('✅ EnhancedGoogleFitService: Initialized successfully');
    } catch (e) {
      _logger.e('❌ EnhancedGoogleFitService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Check for existing authentication and restore if possible
  Future<void> _checkExistingAuthentication() async {
    try {
      if (_googleSignIn == null) return;

      // Try silent sign-in first
      final currentUser = await _googleSignIn!.signInSilently();
      if (currentUser != null) {
        await _restoreAuthentication(currentUser);
        return;
      }

      // Check if user is already signed in
      final isSignedIn = await _googleSignIn!.isSignedIn();
      if (isSignedIn) {
        final user = _googleSignIn!.currentUser;
        if (user != null) {
          await _restoreAuthentication(user);
        }
      }
    } catch (e) {
      _logger.w('⚠️ EnhancedGoogleFitService: Authentication check failed: $e');
      _isAuthenticated = false;
    }
  }

  /// Restore authentication with existing user
  Future<void> _restoreAuthentication(GoogleSignInAccount user) async {
    try {
      final auth = await user.authentication;
      if (auth.accessToken != null) {
        await _initializeAuthClient(auth);
        _isAuthenticated = true;
        _connectionController.add(true);
        _logger.i('✅ EnhancedGoogleFitService: Authentication restored');
        
        // Start data refresh
        _startDataRefresh();
      }
    } catch (e) {
      _logger.e('❌ EnhancedGoogleFitService: Authentication restore failed: $e');
      _isAuthenticated = false;
    }
  }

  /// Initialize authenticated HTTP client
  Future<void> _initializeAuthClient(GoogleSignInAuthentication auth) async {
    _authClient = authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken('Bearer', auth.accessToken!, DateTime.now().toUtc().add(const Duration(hours: 1))),
        auth.idToken,
        _getScopes(),
      ),
    );
  }

  /// Get required scopes
  List<String> _getScopes() => [
    _fitnessApiScope,
    _fitnessBodyScope,
    _fitnessLocationScope,
    _fitnessNutritionScope,
  ];

  /// Authenticate with Google Fit
  Future<bool> authenticate() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }

      _logger.i('🔐 EnhancedGoogleFitService: Starting authentication...');
      final account = await _googleSignIn!.signIn();
      if (account == null) {
        _logger.w('⚠️ EnhancedGoogleFitService: User cancelled authentication');
        return false;
      }

      final auth = await account.authentication;
      if (auth.accessToken == null) {
        _logger.e('❌ EnhancedGoogleFitService: No access token received');
        return false;
      }

      await _initializeAuthClient(auth);
      _isAuthenticated = true;
      _retryCount = 0; // Reset retry count on successful auth
      
      _connectionController.add(true);
      _startDataRefresh();
      
      _logger.i('✅ EnhancedGoogleFitService: Authentication successful');
      return true;
    } catch (e) {
      _logger.e('❌ EnhancedGoogleFitService: Authentication failed: $e');
      _isAuthenticated = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Start connection monitoring
  void _startConnectionMonitoring() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(_connectionCheckInterval, (timer) {
      _checkConnection();
    });
  }

  /// Start data refresh
  void _startDataRefresh() {
    _dataRefreshTimer?.cancel();
    _dataRefreshTimer = Timer.periodic(_dataRefreshInterval, (timer) {
      _refreshData();
    });
    
    // Immediate data refresh
    _refreshData();
  }

  /// Check connection status and attempt reconnection if needed
  Future<void> _checkConnection() async {
    try {
      if (_googleSignIn == null) return;

      final wasConnected = _isAuthenticated;
      
      // Check if user is still signed in
      final isSignedIn = await _googleSignIn!.isSignedIn();
      if (!isSignedIn) {
        _isAuthenticated = false;
        _authClient = null;
        if (wasConnected) {
          _connectionController.add(false);
          _logger.w('⚠️ EnhancedGoogleFitService: User signed out');
        }
        return;
      }

      // Check if we have a valid user
      final currentUser = _googleSignIn!.currentUser;
      if (currentUser == null) {
        _isAuthenticated = false;
        _authClient = null;
        if (wasConnected) {
          _connectionController.add(false);
          _logger.w('⚠️ EnhancedGoogleFitService: No current user');
        }
        return;
      }

      // If we were disconnected, try to restore
      if (!_isAuthenticated) {
        await _restoreAuthentication(currentUser);
        if (_isAuthenticated && !wasConnected) {
          _connectionController.add(true);
          _logger.i('✅ EnhancedGoogleFitService: Connection restored');
        }
      }
    } catch (e) {
      _logger.e('❌ EnhancedGoogleFitService: Connection check failed: $e');
      if (_isAuthenticated) {
        _isAuthenticated = false;
        _connectionController.add(false);
      }
    }
  }

  /// Refresh fitness data
  Future<void> _refreshData() async {
    if (!_isAuthenticated) return;

    try {
      final data = await getTodayFitnessDataBatch();
      if (data != null) {
        _dataController.add(data);
        _retryCount = 0; // Reset retry count on successful data fetch
        _logger.d('✅ EnhancedGoogleFitService: Data refreshed successfully');
      }
    } catch (e) {
      _logger.w('⚠️ EnhancedGoogleFitService: Data refresh failed: $e');
      _handleDataRefreshError();
    }
  }

  /// Handle data refresh errors with retry logic
  void _handleDataRefreshError() {
    _retryCount++;
    if (_retryCount <= _maxRetries) {
      _logger.i('🔄 EnhancedGoogleFitService: Retrying data refresh ($_retryCount/$_maxRetries)');
      Timer(_retryDelay, () {
        _refreshData();
      });
    } else {
      _logger.e('❌ EnhancedGoogleFitService: Max retries reached, checking connection');
      _checkConnection();
      _retryCount = 0;
    }
  }

  /// Get all fitness data for today in a single optimized call
  Future<Map<String, dynamic>?> getTodayFitnessDataBatch() async {
    if (!_isAuthenticated || _authClient == null) {
      _logger.w('⚠️ EnhancedGoogleFitService: Not authenticated for batch request');
      return null;
    }

    // Check network connectivity
    if (!await _hasNetworkConnection()) {
      _logger.w('⚠️ EnhancedGoogleFitService: No network connection');
      return null;
    }

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Use parallel requests with individual error handling
      final results = await Future.wait([
        _getStepsData(startOfDay, endOfDay).catchError((e) {
          _logger.w('Steps fetch failed: $e');
          return null;
        }),
        _getCaloriesData(startOfDay, endOfDay).catchError((e) {
          _logger.w('Calories fetch failed: $e');
          return null;
        }),
        _getDistanceData(startOfDay, endOfDay).catchError((e) {
          _logger.w('Distance fetch failed: $e');
          return null;
        }),
        _getWeightData().catchError((e) {
          _logger.w('Weight fetch failed: $e');
          return null;
        }),
      ], eagerError: false);

      final data = {
        'timestamp': today.toIso8601String(),
        'steps': results[0] as int? ?? 0,
        'caloriesBurned': results[1] as double? ?? 0.0,
        'distance': results[2] as double? ?? 0.0,
        'weight': results[3] as double?,
        'activityLevel': _calculateActivityLevel(results[0] as int?),
        'isConnected': true,
      };

      return data;
    } catch (e) {
      _logger.e('❌ EnhancedGoogleFitService: Batch data fetch failed: $e');
      return null;
    }
  }

  /// Get steps data for a specific time range
  Future<int?> _getStepsData(DateTime startTime, DateTime endTime) async {
    const url = '$_baseUrl/users/me/dataset:aggregate';
    
    final requestBody = {
      'aggregateBy': [
        {
          'dataTypeName': 'com.google.step_count.delta',
          'dataSourceId': 'derived:com.google.step_count.delta:com.google.android.gms:estimated_steps'
        }
      ],
      'bucketByTime': {'durationMillis': 86400000},
      'startTimeMillis': startTime.millisecondsSinceEpoch.toString(),
      'endTimeMillis': endTime.millisecondsSinceEpoch.toString(),
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
      _logger.e('Steps API error: ${response.statusCode} - ${response.body}');
    }

    return null;
  }

  /// Get calories data for a specific time range
  Future<double?> _getCaloriesData(DateTime startTime, DateTime endTime) async {
    const url = '$_baseUrl/users/me/dataset:aggregate';
    
    final requestBody = {
      'aggregateBy': [
        {
          'dataTypeName': 'com.google.calories.expended',
          'dataSourceId': 'derived:com.google.calories.expended:com.google.android.gms:from_activities'
        }
      ],
      'bucketByTime': {'durationMillis': 86400000},
      'startTimeMillis': startTime.millisecondsSinceEpoch.toString(),
      'endTimeMillis': endTime.millisecondsSinceEpoch.toString(),
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
      _logger.e('Calories API error: ${response.statusCode} - ${response.body}');
    }

    return null;
  }

  /// Get distance data for a specific time range
  Future<double?> _getDistanceData(DateTime startTime, DateTime endTime) async {
    const url = '$_baseUrl/users/me/dataset:aggregate';
    
    final requestBody = {
      'aggregateBy': [
        {
          'dataTypeName': 'com.google.distance.delta',
          'dataSourceId': 'derived:com.google.distance.delta:com.google.android.gms:from_steps'
        }
      ],
      'bucketByTime': {'durationMillis': 86400000},
      'startTimeMillis': startTime.millisecondsSinceEpoch.toString(),
      'endTimeMillis': endTime.millisecondsSinceEpoch.toString(),
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
      _logger.e('Distance API error: ${response.statusCode} - ${response.body}');
    }

    return null;
  }

  /// Get current weight data
  Future<double?> _getWeightData() async {
    const url = '$_baseUrl/users/me/dataSources';
    
    final response = await _authClient!.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final dataSources = data['dataSource'] as List?;
      
      if (dataSources != null) {
        for (final source in dataSources) {
          if (source['dataType']['name'] == 'com.google.weight') {
            // Get the latest weight data
            final dataStreamId = source['dataStreamId'];
            final weightUrl = '$_baseUrl/users/me/dataSources/$dataStreamId/datasets/0-${DateTime.now().millisecondsSinceEpoch}';
            
            final weightResponse = await _authClient!.get(Uri.parse(weightUrl));
            if (weightResponse.statusCode == 200) {
              final weightData = jsonDecode(weightResponse.body);
              final points = weightData['point'] as List?;
              if (points != null && points.isNotEmpty) {
                final latestPoint = points.last;
                final value = latestPoint['value'] as List;
                if (value.isNotEmpty) {
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
  }

  /// Check network connectivity
  Future<bool> _hasNetworkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      _logger.w('Network check failed: $e');
      return false;
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

  /// Force data refresh
  Future<void> forceRefresh() async {
    _logger.i('🔄 EnhancedGoogleFitService: Force refresh requested');
    await _refreshData();
  }

  /// Sign out from Google Fit
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _authClient?.close();
      _authClient = null;
      _isAuthenticated = false;
      
      _connectionCheckTimer?.cancel();
      _dataRefreshTimer?.cancel();
      
      _connectionController.add(false);
      _logger.i('🔌 EnhancedGoogleFitService: Signed out');
    } catch (e) {
      _logger.e('❌ EnhancedGoogleFitService: Sign out failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _connectionCheckTimer?.cancel();
    _dataRefreshTimer?.cancel();
    _connectionController.close();
    _dataController.close();
    _authClient?.close();
  }
}
