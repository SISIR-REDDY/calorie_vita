import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/health_data_model.dart';
import '../models/workout_model.dart';
import '../controller/health_controller.dart';
import '../repository/health_repository.dart';
import '../../config/production_config.dart';

/// Centralized Data Hub for Health Connect data
/// 
/// This hub stores all health data (steps, calories, workouts) in one place
/// and makes it easily accessible throughout the app.
/// 
/// Features:
/// - Single source of truth for health data
/// - Real-time updates via streams
/// - Automatic refresh capability
/// - Background sync support
/// - Persistent state management
/// - Easy UI integration
/// 
/// Usage:
/// ```dart
/// final hub = HealthDataHub();
/// await hub.initialize();
/// 
/// // Get data
/// print('Steps: ${hub.steps}');
/// print('Calories: ${hub.calories}');
/// 
/// // Listen to changes
/// hub.dataStream.listen((data) {
///   print('Data updated: $data');
/// });
/// 
/// // Refresh data
/// await hub.refresh();
/// ```
class HealthDataHub extends ChangeNotifier {
  static final HealthDataHub _instance = HealthDataHub._internal();
  factory HealthDataHub() => _instance;
  HealthDataHub._internal();

  // Controllers and services
  final HealthController _controller = HealthController();
  final HealthRepository _repository = HealthRepository();

  // Data state
  HealthDataModel? _data;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdateTime;

  // Stream controllers for real-time updates
  final StreamController<HealthDataModel?> _dataStreamController =
      StreamController<HealthDataModel?>.broadcast();
  final StreamController<int> _stepsStreamController =
      StreamController<int>.broadcast();
  final StreamController<double> _caloriesStreamController =
      StreamController<double>.broadcast();
  final StreamController<List<WorkoutModel>> _workoutsStreamController =
      StreamController<List<WorkoutModel>>.broadcast();

  // Auto-refresh timer
  Timer? _autoRefreshTimer;
  Duration _autoRefreshInterval = const Duration(minutes: 5);

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Check if hub is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently loading data
  bool get isLoading => _isLoading;

  /// Check if data is available
  bool get hasData => _data != null;

  /// Check if error occurred
  bool get hasError => _errorMessage != null;

  /// Get error message
  String? get errorMessage => _errorMessage;

  /// Get last update time
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Get complete health data
  HealthDataModel? get data => _data;

  /// Get today's steps
  int get steps => _data?.steps ?? 0;

  /// Get today's calories burned
  double get calories => _data?.calories ?? 0.0;

  /// Get today's workouts
  List<WorkoutModel> get workouts => _data?.workouts ?? [];

  /// Get today's heart rate data
  List<int> get heartRate => _data?.heartRate ?? [];

  /// Get workout count
  int get workoutCount => workouts.length;

  /// Get total workout calories
  double get workoutCalories {
    return workouts.fold<double>(0.0, (sum, w) => sum + w.calories);
  }

  /// Get total workout duration in minutes
  int get totalWorkoutDuration {
    return workouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
  }

  /// Get average heart rate
  int? get averageHeartRate {
    if (heartRate.isEmpty) return null;
    final sum = heartRate.reduce((a, b) => a + b);
    return sum ~/ heartRate.length;
  }

  /// Get minimum heart rate
  int? get minHeartRate {
    if (heartRate.isEmpty) return null;
    return heartRate.reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum heart rate
  int? get maxHeartRate {
    if (heartRate.isEmpty) return null;
    return heartRate.reduce((a, b) => a > b ? a : b);
  }

  // ============================================================================
  // Streams
  // ============================================================================

  /// Stream of complete health data updates
  Stream<HealthDataModel?> get dataStream => _dataStreamController.stream;

  /// Stream of steps updates
  Stream<int> get stepsStream => _stepsStreamController.stream;

  /// Stream of calories updates
  Stream<double> get caloriesStream => _caloriesStreamController.stream;

  /// Stream of workouts updates
  Stream<List<WorkoutModel>> get workoutsStream =>
      _workoutsStreamController.stream;

  // ============================================================================
  // Initialization
  // ============================================================================

  /// Initialize the hub and load initial data
  Future<void> initialize({bool autoRefresh = true}) async {
    if (_isInitialized) {
      developer.log('HealthDataHub: Already initialized');
      return;
    }

    try {
      developer.log('HealthDataHub: Initializing...');
      _isLoading = true;
      notifyListeners();

      // Check if Health Connect is available
      final isAvailable = await _repository.isHealthConnectAvailable();
      if (!isAvailable) {
        throw Exception('Health Connect is not available on this device');
      }

      // Check and request permissions
      final hasPerms = await _repository.hasPermissions();
      if (!hasPerms) {
        final granted = await _repository.requestPermissions();
        if (!granted) {
          throw Exception('Health Connect permissions not granted');
        }
      }

      // Load initial data
      await _loadData();

      // Setup auto-refresh if enabled
      if (autoRefresh) {
        _startAutoRefresh();
      }

      _isInitialized = true;
      developer.log('HealthDataHub: Initialization complete');
    } catch (e) {
      _errorMessage = e.toString();
      developer.log('HealthDataHub: Initialization failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // Data Loading
  // ============================================================================

  /// Load health data from Health Connect
  Future<void> _loadData() async {
    try {
      developer.log('HealthDataHub: Loading data...');

      // Fetch data from repository
      final data = await _repository.refreshAllData();

      // Update state
      _data = data;
      _lastUpdateTime = DateTime.now();
      _errorMessage = null;

      // Notify listeners
      notifyListeners();

      // Broadcast to streams
      _dataStreamController.add(data);
      _stepsStreamController.add(data.steps);
      _caloriesStreamController.add(data.calories);
      _workoutsStreamController.add(data.workouts);

      developer.log(
          'HealthDataHub: Data loaded - Steps: ${data.steps}, Calories: ${data.calories}');
    } catch (e) {
      _errorMessage = e.toString();
      developer.log('HealthDataHub: Load data failed: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh data (public method for UI)
  Future<void> refresh({bool force = false}) async {
    if (_isLoading) {
      developer.log('HealthDataHub: Refresh already in progress');
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Clear cache if force refresh
      if (force) {
        _repository.clearCache();
      }

      await _loadData();

      developer.log('HealthDataHub: Refresh complete');
    } catch (e) {
      _errorMessage = e.toString();
      developer.log('HealthDataHub: Refresh failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // Auto-Refresh
  // ============================================================================

  /// Start automatic background refresh
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (_isInitialized && !_isLoading) {
        developer.log('HealthDataHub: Auto-refresh triggered');
        refresh(force: false);
      }
    });
    developer.log(
        'HealthDataHub: Auto-refresh started (interval: $_autoRefreshInterval)');
  }

  /// Stop automatic refresh
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    developer.log('HealthDataHub: Auto-refresh stopped');
  }

  /// Change auto-refresh interval
  void setAutoRefreshInterval(Duration interval) {
    _autoRefreshInterval = interval;
    if (_autoRefreshTimer != null) {
      _startAutoRefresh(); // Restart with new interval
    }
    developer.log('HealthDataHub: Auto-refresh interval set to $interval');
  }

  // ============================================================================
  // Permission Management
  // ============================================================================

  /// Request Health Connect permissions
  Future<bool> requestPermissions() async {
    try {
      return await _repository.requestPermissions();
    } catch (e) {
      developer.log('HealthDataHub: Request permissions failed: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      return await _repository.hasPermissions();
    } catch (e) {
      developer.log('HealthDataHub: Check permissions failed: $e');
      return false;
    }
  }

  /// Open Health Connect settings
  Future<void> openHealthConnectSettings() async {
    try {
      await _repository.openHealthConnectSettings();
    } catch (e) {
      developer.log('HealthDataHub: Open settings failed: $e');
    }
  }

  // ============================================================================
  // Data Access Methods
  // ============================================================================

  /// Get steps for a specific date (future enhancement)
  Future<int> getStepsForDate(DateTime date) async {
    // TODO: Implement date-specific queries
    return steps; // For now, return today's steps
  }

  /// Get calories for a specific date (future enhancement)
  Future<double> getCaloriesForDate(DateTime date) async {
    // TODO: Implement date-specific queries
    return calories; // For now, return today's calories
  }

  /// Get workouts for a specific date (future enhancement)
  Future<List<WorkoutModel>> getWorkoutsForDate(DateTime date) async {
    // TODO: Implement date-specific queries
    return workouts; // For now, return today's workouts
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// Get formatted summary
  String getSummary() {
    if (!hasData) return 'No data available';

    return '''
Health Summary (Updated: ${lastUpdateTime?.toString() ?? 'Never'})
Steps: $steps
Calories: ${calories.toStringAsFixed(1)} kcal
Workouts: $workoutCount sessions (${totalWorkoutDuration} min)
Heart Rate: ${averageHeartRate ?? 'N/A'} bpm (avg)
''';
  }

  /// Reset hub to initial state
  void reset() {
    _data = null;
    _isInitialized = false;
    _isLoading = false;
    _errorMessage = null;
    _lastUpdateTime = null;
    _repository.clearCache();
    stopAutoRefresh();
    notifyListeners();
    developer.log('HealthDataHub: Reset complete');
  }

  // ============================================================================
  // Disposal
  // ============================================================================

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    if (!_dataStreamController.isClosed) _dataStreamController.close();
    if (!_stepsStreamController.isClosed) _stepsStreamController.close();
    if (!_caloriesStreamController.isClosed) _caloriesStreamController.close();
    if (!_workoutsStreamController.isClosed) _workoutsStreamController.close();
    super.dispose();
    developer.log('HealthDataHub: Disposed');
  }
}


