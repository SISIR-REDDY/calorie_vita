import 'dart:developer' as developer;
import 'package:flutter/services.dart';

class HealthConnectService {
  static final HealthConnectService _instance = HealthConnectService._internal();
  factory HealthConnectService() => _instance;
  HealthConnectService._internal();

  static const MethodChannel _channel = MethodChannel('health_connect');

  /// Check if Health Connect is available on this device
  Future<bool> isAvailable() async {
    try {
      final availability = await _channel.invokeMethod<bool>('checkAvailability') ?? false;
      developer.log('Health Connect availability: $availability');
      return availability;
    } catch (e) {
      developer.log('Error checking Health Connect availability: $e');
      return false;
    }
  }

  /// Request permissions for all required health data types
  Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions') ?? false;
      developer.log('Permissions requested. Result: $result');
      return result;
    } catch (e) {
      developer.log('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if all required permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermissions') ?? false;
      developer.log('Permissions check result: $result');
      return result;
    } catch (e) {
      developer.log('Error checking permissions: $e');
      return false;
    }
  }

  /// Get steps data for a date range
  Future<int> getSteps(DateTime start, DateTime end) async {
    try {
      // Validate permissions
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        developer.log('No permissions to read steps');
        return 0;
      }

      // Read steps from Health Connect
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getSteps',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );

      if (result == null) {
        developer.log('No steps records found for range: $start to $end');
        return 0;
      }

      final steps = result['steps'] as int? ?? 0;
      developer.log('Retrieved $steps steps');
      return steps;
    } catch (e) {
      developer.log('Error reading steps: $e');
      return 0;
    }
  }

  /// Get calories burned data for a date range
  Future<double> getCalories(DateTime start, DateTime end) async {
    try {
      // Validate permissions
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        developer.log('No permissions to read calories');
        return 0.0;
      }

      // Read calories from Health Connect
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCalories',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );

      if (result == null) {
        developer.log('No calories records found for range: $start to $end');
        return 0.0;
      }

      final calories = (result['calories'] as num?)?.toDouble() ?? 0.0;
      developer.log('Retrieved $calories calories');
      return calories;
    } catch (e) {
      developer.log('Error reading calories: $e');
      return 0.0;
    }
  }

  /// Get workout/exercise session data for a date range
  Future<List<Map<String, dynamic>>> getWorkouts(
      DateTime start, DateTime end) async {
    try {
      // Validate permissions
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        developer.log('No permissions to read workouts');
        return [];
      }

      // Read workouts from Health Connect
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getWorkouts',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );

      if (result == null || result.isEmpty) {
        developer.log('No workout records found for range: $start to $end');
        return [];
      }

      final workouts = result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      developer.log('Retrieved ${workouts.length} workout records');
      return workouts;
    } catch (e) {
      developer.log('Error reading workouts: $e');
      return [];
    }
  }

  /// Get heart rate data for a date range
  Future<List<int>> getHeartRate(DateTime start, DateTime end) async {
    try {
      // Validate permissions
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        developer.log('No permissions to read heart rate');
        return [];
      }

      // Read heart rate from Health Connect
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getHeartRate',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );

      if (result == null || result.isEmpty) {
        developer.log('No heart rate records found for range: $start to $end');
        return [];
      }

      final heartRates = result.map((e) => e as int).toList();
      developer.log('Retrieved ${heartRates.length} heart rate records');
      return heartRates;
    } catch (e) {
      developer.log('Error reading heart rate: $e');
      return [];
    }
  }

  /// Open Health Connect settings
  Future<void> openHealthConnectSettings() async {
    try {
      await _channel.invokeMethod('openHealthConnectSettings');
    } catch (e) {
      developer.log('Error opening Health Connect settings: $e');
    }
  }

  /// Get today's data in a single batch call (optimized)
  Future<Map<String, dynamic>?> getTodayData() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayData');
      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      developer.log('Error getting today\'s data: $e');
      return null;
    }
  }
}

