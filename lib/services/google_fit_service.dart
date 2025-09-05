import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/health_data.dart';
import 'error_handler.dart';

/// Google Fit integration service for Android health data
class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final ErrorHandler _errorHandler = ErrorHandler();
  Health? _health;
  bool _isInitialized = false;
  bool _isConnected = false;

  // Health data types to track
  final List<HealthDataType> _healthDataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.WATER,
  ];

  // Stream controllers for real-time updates
  final StreamController<HealthData> _healthDataController = StreamController<HealthData>.broadcast();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  // Getters
  Stream<HealthData> get healthDataStream => _healthDataController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;

  /// Initialize Google Fit service (now Health Connect)
  Future<bool> initialize() async {
    try {
      if (!Platform.isAndroid) {
        if (kDebugMode) print('Health Connect is only available on Android');
        return false;
      }

      _health = Health();
      _isInitialized = true;
      
      if (kDebugMode) print('✅ Health service initialized');
      return true;
    } catch (e) {
      _errorHandler.handleDataError('health_connect_init', e);
      if (kDebugMode) print('❌ Failed to initialize Health service: $e');
      return false;
    }
  }

  /// Request permissions for health data access
  Future<bool> requestPermissions() async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) print('🔧 Initializing Health Connect for permissions...');
        await initialize();
      }

      if (kDebugMode) print('🔐 Requesting Health Connect authorization...');
      // Request health permissions for Health Connect
      final permissions = await _health!.requestAuthorization(
        _healthDataTypes,
        permissions: List.filled(_healthDataTypes.length, HealthDataAccess.READ),
      );

      if (permissions) {
        if (kDebugMode) print('✅ Health Connect authorization granted');
        
        // Request additional permissions
        if (kDebugMode) print('🔐 Requesting Bluetooth permissions...');
        final bluetoothPermission = await Permission.bluetoothConnect.request();
        
        if (kDebugMode) print('🔐 Requesting Location permissions...');
        final locationPermission = await Permission.location.request();
        
        _isConnected = true;
        _connectionStatusController.add(true);
        
        if (kDebugMode) print('✅ All Health Connect permissions granted');
        return true;
      } else {
        if (kDebugMode) print('❌ Health Connect authorization denied by user');
        if (kDebugMode) print('💡 Please install Health Connect app from Google Play Store');
        return false;
      }
    } catch (e) {
      _errorHandler.handleDataError('health_connect_permissions', e);
      if (kDebugMode) print('❌ Failed to request Health Connect permissions: $e');
      if (kDebugMode) print('💡 Error details: ${e.toString()}');
      return false;
    }
  }

  /// Connect to Health Connect
  Future<bool> connect() async {
    try {
      if (!_isInitialized) {
        if (kDebugMode) print('🔧 Initializing Health Connect...');
        final initialized = await initialize();
        if (!initialized) {
          if (kDebugMode) print('❌ Failed to initialize Health Connect');
          return false;
        }
      }

      // Check if already connected
      if (_isConnected) {
        if (kDebugMode) print('✅ Already connected to Health Connect');
        return true;
      }

      if (kDebugMode) print('🔐 Requesting Health Connect permissions...');
      // Request permissions first
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        if (kDebugMode) print('❌ Health Connect permissions denied');
        return false;
      }

      if (kDebugMode) print('📊 Testing Health Connect connection...');
      // Test connection by fetching today's data
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Test connection by fetching today's data
      final healthData = await _health!.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: _healthDataTypes,
      );

      _isConnected = true;
      _connectionStatusController.add(true);
      
      if (kDebugMode) print('✅ Connected to Health Connect successfully');
      if (kDebugMode) print('📈 Retrieved ${healthData.length} health data points');
      return true;
    } catch (e) {
      _errorHandler.handleDataError('health_connect_connect', e);
      if (kDebugMode) print('❌ Failed to connect to Health Connect: $e');
      if (kDebugMode) print('💡 Make sure Health Connect is installed and permissions are granted');
      return false;
    }
  }

  /// Disconnect from Health Connect
  Future<void> disconnect() async {
    try {
      _isConnected = false;
      _connectionStatusController.add(false);
      if (kDebugMode) print('🔌 Disconnected from Health Connect');
    } catch (e) {
      _errorHandler.handleDataError('health_connect_disconnect', e);
    }
  }

  /// Get today's health data
  Future<HealthData> getTodayHealthData() async {
    try {
      if (!_isConnected) {
        throw Exception('Not connected to Health Connect');
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final healthDataPoints = await _health!.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: _healthDataTypes,
      );

      return _processHealthData(healthDataPoints, today);
    } catch (e) {
      _errorHandler.handleDataError('google_fit_get_data', e);
      rethrow;
    }
  }

  /// Get health data for a specific date range
  Future<HealthData> getHealthDataForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      if (!_isConnected) {
        throw Exception('Not connected to Health Connect');
      }

      final healthDataPoints = await _health!.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: _healthDataTypes,
      );

      return _processHealthData(healthDataPoints, startDate);
    } catch (e) {
      _errorHandler.handleDataError('google_fit_get_range', e);
      rethrow;
    }
  }

  /// Start real-time health data monitoring
  Future<void> startRealTimeMonitoring() async {
    try {
      if (!_isConnected) {
        if (kDebugMode) print('❌ Not connected to Health Connect');
        return;
      }

      // Set up periodic data fetching
      Timer.periodic(const Duration(minutes: 5), (timer) async {
        if (!_isConnected) {
          timer.cancel();
          return;
        }

        try {
          final healthData = await getTodayHealthData();
          _healthDataController.add(healthData);
        } catch (e) {
          if (kDebugMode) print('❌ Error in real-time monitoring: $e');
        }
      });

      if (kDebugMode) print('✅ Started real-time Google Fit monitoring');
    } catch (e) {
      _errorHandler.handleDataError('google_fit_realtime', e);
    }
  }

  /// Process raw health data points into HealthData model
  HealthData _processHealthData(List<HealthDataPoint> dataPoints, DateTime date) {
    int steps = 0;
    double caloriesBurned = 0.0;
    double distance = 0.0;
    double heartRate = 0.0;
    double sleepHours = 0.0;
    double waterIntake = 0.0;

    for (final dataPoint in dataPoints) {
      switch (dataPoint.type) {
        case HealthDataType.STEPS:
          steps += (dataPoint.value as NumericHealthValue).numericValue.toInt();
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          caloriesBurned += (dataPoint.value as NumericHealthValue).numericValue;
          break;
        case HealthDataType.DISTANCE_DELTA:
          distance += (dataPoint.value as NumericHealthValue).numericValue;
          break;
        case HealthDataType.HEART_RATE:
          heartRate = (dataPoint.value as NumericHealthValue).numericValue.toDouble();
          break;
        case HealthDataType.SLEEP_IN_BED:
          sleepHours += (dataPoint.value as NumericHealthValue).numericValue;
          break;
        case HealthDataType.WATER:
          waterIntake += (dataPoint.value as NumericHealthValue).numericValue;
          break;
        default:
          break;
      }
    }

    return HealthData(
      date: date,
      steps: steps,
      caloriesBurned: caloriesBurned,
      distance: distance,
      activeMinutes: 0, // Default value
      heartRate: heartRate,
      sleepHours: sleepHours,
      waterIntake: waterIntake,
      weight: 0.0, // Default value
      source: 'Health Connect',
      lastUpdated: DateTime.now(),
    );
  }

  /// Check if Health Connect is available on device
  Future<bool> isAvailable() async {
    try {
      if (!Platform.isAndroid) {
        if (kDebugMode) print('❌ Health Connect is only available on Android');
        return false;
      }
      
      if (!_isInitialized) {
        if (kDebugMode) print('🔧 Initializing Health Connect to check availability...');
        await initialize();
      }
      
      if (_health == null) {
        if (kDebugMode) print('❌ Health Connect service is null');
        return false;
      }
      
      if (kDebugMode) print('✅ Health Connect service is available');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error checking Health Connect availability: $e');
      if (kDebugMode) print('💡 Make sure Health Connect app is installed on your device');
      return false;
    }
  }

  /// Get device health capabilities
  Future<Map<String, bool>> getDeviceCapabilities() async {
    try {
      if (!_isConnected) return {};

      final capabilities = <String, bool>{};
      
      // Check if device supports different health metrics
      for (final dataType in _healthDataTypes) {
        try {
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          
          await _health!.getHealthDataFromTypes(
            startTime: startOfDay,
            endTime: endOfDay,
            types: [dataType],
          );
          
          capabilities[dataType.toString()] = true;
        } catch (e) {
          capabilities[dataType.toString()] = false;
        }
      }

      return capabilities;
    } catch (e) {
      _errorHandler.handleDataError('google_fit_capabilities', e);
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    _healthDataController.close();
    _connectionStatusController.close();
  }
}
