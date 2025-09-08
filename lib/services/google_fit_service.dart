import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isGoogleFitAvailable = false;
  String? _lastError;

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
  bool get isGoogleFitAvailable => _isGoogleFitAvailable;
  String? get lastError => _lastError;

  /// Check if Google Fit/Health Connect is available on the device
  Future<bool> checkGoogleFitAvailability() async {
    try {
      if (kDebugMode) print('🔍 Checking Health Connect availability...');
      
      if (!Platform.isAndroid) {
        _lastError = 'Health Connect is only available on Android devices';
        if (kDebugMode) print('❌ Not Android device');
        return false;
      }

      _health = Health();
      if (kDebugMode) print('✅ Health service created');
      
      // Try to check if Health Connect is available
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      if (kDebugMode) print('📅 Testing data access for: ${startOfDay.toString()} to ${endOfDay.toString()}');

      // This will throw an exception if Health Connect is not available
      final testData = await _health!.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: [HealthDataType.STEPS], // Just check one type for availability
      );

      _isGoogleFitAvailable = true;
      _lastError = null;
      if (kDebugMode) print('✅ Health Connect is available');
      if (kDebugMode) print('📊 Test data retrieved: ${testData.length} points');
      return true;
    } catch (e) {
      _isGoogleFitAvailable = false;
      _lastError = _getUserFriendlyError(e);
      if (kDebugMode) print('❌ Health Connect not available: $e');
      if (kDebugMode) print('💡 Error type: ${e.runtimeType}');
      if (kDebugMode) print('💡 This usually means Health Connect is not installed or not set up');
      return false;
    }
  }

  /// Initialize Google Fit service (now Health Connect)
  Future<bool> initialize() async {
    try {
      if (!Platform.isAndroid) {
        _lastError = 'Health Connect is only available on Android devices';
        if (kDebugMode) print('Health Connect is only available on Android');
        return false;
      }

      // First check if Google Fit/Health Connect is available
      final isAvailable = await checkGoogleFitAvailability();
      if (!isAvailable) {
        return false;
      }

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
      if (kDebugMode) print('🚀 Starting Health Connect connection process...');
      
      if (!_isInitialized) {
        if (kDebugMode) print('🔧 Initializing Health Connect...');
        final initialized = await initialize();
        if (!initialized) {
          if (kDebugMode) print('❌ Failed to initialize Health Connect');
          _lastError = 'Failed to initialize Health Connect service';
          return false;
        }
        if (kDebugMode) print('✅ Health Connect initialized successfully');
      }

      // Check if Google Fit/Health Connect is available
      if (!_isGoogleFitAvailable) {
        _lastError = 'Health Connect is not installed or not available on this device';
        if (kDebugMode) print('❌ Health Connect not available - _isGoogleFitAvailable: $_isGoogleFitAvailable');
        return false;
      }
      if (kDebugMode) print('✅ Health Connect availability confirmed');

      // Check if already connected
      if (_isConnected) {
        if (kDebugMode) print('✅ Already connected to Health Connect');
        return true;
      }

      if (kDebugMode) print('🔐 Requesting Health Connect permissions...');
      // Request permissions first
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        _lastError = 'Health Connect permissions were denied. Please grant permissions to access your health data.';
        if (kDebugMode) print('❌ Health Connect permissions denied');
        return false;
      }
      if (kDebugMode) print('✅ Health Connect permissions granted');

      if (kDebugMode) print('📊 Testing Health Connect connection...');
      // Test connection by fetching today's data
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      if (kDebugMode) print('📅 Fetching data for: ${startOfDay.toString()} to ${endOfDay.toString()}');
      
      // Test connection by fetching today's data
      final healthData = await _health!.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: endOfDay,
        types: _healthDataTypes,
      );

      _isConnected = true;
      _connectionStatusController.add(true);
      _lastError = null;
      
      if (kDebugMode) print('✅ Connected to Health Connect successfully');
      if (kDebugMode) print('📈 Retrieved ${healthData.length} health data points');
      
      // Log what data we got
      if (kDebugMode) {
        for (final dataPoint in healthData) {
          print('📊 Data: ${dataPoint.type} = ${dataPoint.value}');
        }
      }
      
      return true;
    } catch (e) {
      _lastError = _getUserFriendlyError(e);
      _errorHandler.handleDataError('health_connect_connect', e);
      if (kDebugMode) print('❌ Failed to connect to Health Connect: $e');
      if (kDebugMode) print('💡 Error type: ${e.runtimeType}');
      if (kDebugMode) print('💡 Error details: ${e.toString()}');
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

  /// Get user-friendly error message
  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (kDebugMode) print('🔍 Error details: $error');
    
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Health Connect permissions are required. Please grant permissions in your device settings.';
    } else if (errorString.contains('not available') || errorString.contains('not found')) {
      return 'Health Connect is not installed. Please install it from the Play Store.';
    } else if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    } else if (errorString.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    } else if (errorString.contains('android')) {
      return 'This feature is only available on Android devices.';
    } else if (errorString.contains('security') || errorString.contains('exception')) {
      return 'Permission denied. Please check Health Connect settings and grant all required permissions.';
    } else if (errorString.contains('unavailable') || errorString.contains('disabled')) {
      return 'Health Connect is disabled. Please enable it in your device settings.';
    } else if (errorString.contains('healthconnect') || errorString.contains('health connect')) {
      return 'Health Connect is not properly set up. Please open Health Connect app and complete the setup.';
    } else {
      return 'Unable to connect to Health Connect. Please install Health Connect app and grant permissions.';
    }
  }

  /// Check if Health Connect is properly set up
  Future<Map<String, dynamic>> getHealthConnectStatus() async {
    final status = <String, dynamic>{
      'isAndroid': Platform.isAndroid,
      'isInitialized': _isInitialized,
      'isAvailable': _isGoogleFitAvailable,
      'isConnected': _isConnected,
      'lastError': _lastError,
    };

    if (kDebugMode) {
      print('📊 Health Connect Status:');
      status.forEach((key, value) {
        print('   $key: $value');
      });
    }

    return status;
  }

  /// Open Health Connect in Play Store
  Future<bool> openGoogleFitInPlayStore() async {
    try {
      // Try Health Connect first (the new Android health platform)
      const healthConnectUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthconnect';
      final healthConnectUri = Uri.parse(healthConnectUrl);
      
      if (await canLaunchUrl(healthConnectUri)) {
        await launchUrl(healthConnectUri, mode: LaunchMode.externalApplication);
        if (kDebugMode) print('✅ Opened Health Connect in Play Store');
        return true;
      } else {
        // Fallback to Google Fit
        const googleFitUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.fitness';
        final googleFitUri = Uri.parse(googleFitUrl);
        
        if (await canLaunchUrl(googleFitUri)) {
          await launchUrl(googleFitUri, mode: LaunchMode.externalApplication);
          if (kDebugMode) print('✅ Opened Google Fit in Play Store');
          return true;
        } else {
          if (kDebugMode) print('❌ Cannot open Play Store URLs');
          return false;
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error opening Play Store: $e');
      return false;
    }
  }

  /// Open Health Connect settings
  Future<bool> openHealthConnectSettings() async {
    try {
      const settingsUrl = 'content://com.google.android.apps.healthconnect/settings';
      final uri = Uri.parse(settingsUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback to general settings
        const generalSettingsUrl = 'android.settings.APPLICATION_DETAILS_SETTINGS';
        final generalUri = Uri.parse(generalSettingsUrl);
        if (await canLaunchUrl(generalUri)) {
          await launchUrl(generalUri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error opening settings: $e');
      return false;
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
