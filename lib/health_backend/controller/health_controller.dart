import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/health_data_model.dart';
import '../models/workout_model.dart';
import '../repository/health_repository.dart';

/// Enum representing the current state of health data loading
enum HealthState {
  /// Initial state, no data loaded yet
  idle,

  /// Currently loading data
  loading,

  /// Data loaded successfully
  loaded,

  /// Error occurred while loading data
  error,
}

/// Controller for managing health data state and operations
/// Uses ChangeNotifier for state management
class HealthController extends ChangeNotifier {
  static final HealthController _instance = HealthController._internal();
  factory HealthController() => _instance;
  HealthController._internal();

  final HealthRepository _repository = HealthRepository();

  /// Current state of the controller
  HealthState _state = HealthState.idle;
  HealthState get state => _state;

  /// Current health data
  HealthDataModel? _data;
  HealthDataModel? get data => _data;

  /// Error message if state is error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Check if currently loading
  bool get isLoading => _state == HealthState.loading;

  /// Check if data is loaded
  bool get isLoaded => _state == HealthState.loaded;

  /// Check if error occurred
  bool get hasError => _state == HealthState.error;

  /// Load health data from repository
  /// Uses cache if available and valid
  Future<void> loadData() async {
    try {
      developer.log('Loading health data...');

      // Check if cached data is available
      final cachedData = _repository.cachedData;
      if (cachedData != null) {
        developer.log('Using cached health data');
        _data = cachedData;
        _state = HealthState.loaded;
        _errorMessage = null;
        notifyListeners();
        return;
      }

      // Set loading state
      _state = HealthState.loading;
      _errorMessage = null;
      notifyListeners();

      // Check if Health Connect is available
      final isAvailable = await _repository.isHealthConnectAvailable();
      if (!isAvailable) {
        throw Exception('Health Connect is not available on this device');
      }

      // Check permissions
      final hasPerms = await _repository.hasPermissions();
      if (!hasPerms) {
        // Try to request permissions
        final granted = await _repository.requestPermissions();
        if (!granted) {
          throw Exception('Health Connect permissions not granted');
        }
      }

      // Fetch data from repository
      final healthData = await _repository.refreshAllData();

      // Update state
      _data = healthData;
      _state = HealthState.loaded;
      _errorMessage = null;

      developer.log('Health data loaded successfully');
      notifyListeners();
    } catch (e) {
      developer.log('Error loading health data: $e');
      _state = HealthState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Refresh health data (force reload from Health Connect)
  Future<void> refresh() async {
    try {
      developer.log('Refreshing health data...');

      // Clear cache to force fresh data
      _repository.clearCache();

      // Set loading state
      _state = HealthState.loading;
      _errorMessage = null;
      notifyListeners();

      // Check if Health Connect is available
      final isAvailable = await _repository.isHealthConnectAvailable();
      if (!isAvailable) {
        throw Exception('Health Connect is not available on this device');
      }

      // Check permissions
      final hasPerms = await _repository.hasPermissions();
      if (!hasPerms) {
        throw Exception('Health Connect permissions not granted. Please grant permissions and try again.');
      }

      // Fetch fresh data from repository
      final healthData = await _repository.refreshAllData();

      // Update state
      _data = healthData;
      _state = HealthState.loaded;
      _errorMessage = null;

      developer.log('Health data refreshed successfully');
      notifyListeners();
    } catch (e) {
      developer.log('Error refreshing health data: $e');
      _state = HealthState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Request Health Connect permissions
  Future<bool> requestPermissions() async {
    try {
      developer.log('Requesting Health Connect permissions...');
      final granted = await _repository.requestPermissions();
      developer.log('Permissions granted: $granted');
      return granted;
    } catch (e) {
      developer.log('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      return await _repository.hasPermissions();
    } catch (e) {
      developer.log('Error checking permissions: $e');
      return false;
    }
  }

  /// Open Health Connect settings
  Future<void> openHealthConnectSettings() async {
    try {
      await _repository.openHealthConnectSettings();
    } catch (e) {
      developer.log('Error opening Health Connect settings: $e');
    }
  }

  /// Reset controller state
  void reset() {
    _state = HealthState.idle;
    _data = null;
    _errorMessage = null;
    _repository.clearCache();
    notifyListeners();
  }

  /// Get steps count
  int get steps => _data?.steps ?? 0;

  /// Get calories burned
  double get calories => _data?.calories ?? 0.0;

  /// Get workouts list
  List<WorkoutModel> get workouts => _data?.workouts ?? [];

  /// Get heart rate data
  List<int> get heartRate => _data?.heartRate ?? [];

  /// Get average heart rate
  int? get averageHeartRate {
    final hr = heartRate;
    if (hr.isEmpty) return null;
    final sum = hr.reduce((a, b) => a + b);
    return sum ~/ hr.length;
  }

  /// Get minimum heart rate
  int? get minHeartRate {
    final hr = heartRate;
    if (hr.isEmpty) return null;
    return hr.reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum heart rate
  int? get maxHeartRate {
    final hr = heartRate;
    if (hr.isEmpty) return null;
    return hr.reduce((a, b) => a > b ? a : b);
  }

  /// Get total workout count
  int get workoutCount => workouts.length;

  /// Get total workout calories
  double get workoutCalories {
    return workouts.fold<double>(0.0, (sum, workout) => sum + workout.calories);
  }

  /// Get total workout duration in minutes
  int get totalWorkoutDuration {
    return workouts.fold<int>(
      0,
      (sum, workout) => sum + workout.durationMinutes,
    );
  }
}

