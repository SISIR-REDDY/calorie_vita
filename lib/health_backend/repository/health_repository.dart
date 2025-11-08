import 'dart:developer' as developer;
import '../data_source/health_connect_service.dart';
import '../models/health_data_model.dart';
import '../models/workout_model.dart';

class HealthRepository {
  static final HealthRepository _instance = HealthRepository._internal();
  factory HealthRepository() => _instance;
  HealthRepository._internal();

  final HealthConnectService _healthConnectService = HealthConnectService();

  /// In-memory cache for health data
  HealthDataModel? _cachedData;
  DateTime? _lastCacheTime;

  /// Cache validity duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get cached data if available and valid
  HealthDataModel? get cachedData {
    if (_cachedData != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      return _cachedData;
    }
    return null;
  }

  /// Clear cache
  void clearCache() {
    _cachedData = null;
    _lastCacheTime = null;
    developer.log('Health data cache cleared');
  }

  /// Fetch today's step count
  Future<int> fetchTodaySteps() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final steps = await _healthConnectService.getSteps(startOfDay, endOfDay);
      developer.log('Total steps for today: $steps');
      return steps;
    } catch (e) {
      developer.log('Error fetching today steps: $e');
      return 0;
    }
  }

  /// Fetch today's calories burned
  Future<double> fetchTodayCalories() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final calories = await _healthConnectService.getCalories(startOfDay, endOfDay);
      developer.log('Total calories for today: $calories');
      return calories;
    } catch (e) {
      developer.log('Error fetching today calories: $e');
      return 0.0;
    }
  }

  /// Fetch today's workout sessions
  Future<List<WorkoutModel>> fetchTodayWorkouts() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final records = await _healthConnectService.getWorkouts(startOfDay, endOfDay);

      if (records.isEmpty) {
        developer.log('No workout data found for today');
        return [];
      }

      // Convert records to WorkoutModel
      final workouts = records.map((record) {
        final startTime = DateTime.fromMillisecondsSinceEpoch(
          record['startTime'] as int,
        );
        final endTime = DateTime.fromMillisecondsSinceEpoch(
          record['endTime'] as int,
        );
        final type = record['type'] as String? ?? 'Unknown';
        final calories = (record['calories'] as num?)?.toDouble() ?? 0.0;

        return WorkoutModel(
          startTime: startTime,
          endTime: endTime,
          type: type,
          calories: calories,
        );
      }).toList();

      // Sort by start time (most recent first)
      workouts.sort((a, b) => b.startTime.compareTo(a.startTime));

      developer.log('Total workouts for today: ${workouts.length}');
      return workouts;
    } catch (e) {
      developer.log('Error fetching today workouts: $e');
      return [];
    }
  }

  /// Fetch today's heart rate data
  Future<List<int>> fetchTodayHeartRate() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final heartRates = await _healthConnectService.getHeartRate(startOfDay, endOfDay);
      developer.log('Total heart rate samples for today: ${heartRates.length}');
      return heartRates;
    } catch (e) {
      developer.log('Error fetching today heart rate: $e');
      return [];
    }
  }

  /// Refresh all health data and return a complete HealthDataModel
  Future<HealthDataModel> refreshAllData() async {
    try {
      developer.log('Refreshing all health data...');

      // Check if Health Connect is available
      final isAvailable = await _healthConnectService.isAvailable();
      if (!isAvailable) {
        developer.log('Health Connect is not available');
        return HealthDataModel.empty();
      }

      // Check permissions
      final hasPerms = await _healthConnectService.hasPermissions();
      if (!hasPerms) {
        developer.log('Missing Health Connect permissions');
        return HealthDataModel.empty();
      }

      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        fetchTodaySteps(),
        fetchTodayCalories(),
        fetchTodayWorkouts(),
        fetchTodayHeartRate(),
      ]);

      final healthData = HealthDataModel(
        steps: results[0] as int,
        calories: results[1] as double,
        workouts: results[2] as List<WorkoutModel>,
        heartRate: results[3] as List<int>,
      );

      // Update cache
      _cachedData = healthData;
      _lastCacheTime = DateTime.now();

      developer.log('Health data refreshed successfully: $healthData');
      return healthData;
    } catch (e) {
      developer.log('Error refreshing all health data: $e');
      return HealthDataModel.empty();
    }
  }

  /// Request permissions for Health Connect
  Future<bool> requestPermissions() async {
    return await _healthConnectService.requestPermissions();
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    return await _healthConnectService.hasPermissions();
  }

  /// Check if Health Connect is available
  Future<bool> isHealthConnectAvailable() async {
    return await _healthConnectService.isAvailable();
  }

  /// Open Health Connect settings
  Future<void> openHealthConnectSettings() async {
    await _healthConnectService.openHealthConnectSettings();
  }

}

