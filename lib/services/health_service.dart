import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_data.dart';
import '../models/daily_summary.dart';
import 'app_state_service.dart';

/// Health and fitness tracking service
/// Integrates with Google Fit, Apple Health, and other fitness trackers
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final AppStateService _appStateService = AppStateService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for real-time health data
  final StreamController<HealthData> _healthDataController = StreamController<HealthData>.broadcast();
  final StreamController<bool> _isConnectedController = StreamController<bool>.broadcast();
  final StreamController<List<FitnessDevice>> _connectedDevicesController = StreamController<List<FitnessDevice>>.broadcast();

  // Current state
  HealthData _currentHealthData = HealthData.empty();
  bool _isConnected = false;
  List<FitnessDevice> _connectedDevices = [];
  Timer? _healthDataTimer;

  // Getters
  Stream<HealthData> get healthDataStream => _healthDataController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  Stream<List<FitnessDevice>> get connectedDevicesStream => _connectedDevicesController.stream;
  HealthData get currentHealthData => _currentHealthData;
  bool get isConnected => _isConnected;
  List<FitnessDevice> get connectedDevices => _connectedDevices;

  /// Initialize health service
  Future<void> initialize() async {
    await _loadHealthSettings();
    await _checkConnectionStatus();
    _startHealthDataMonitoring();
  }

  /// Load health settings from Firestore
  Future<void> _loadHealthSettings() async {
    final userId = _appStateService.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('health')
          .doc('settings')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _isConnected = data['isConnected'] ?? false;
        _connectedDevices = (data['connectedDevices'] as List?)
            ?.map((device) => FitnessDevice.fromMap(device))
            .toList() ?? [];
        
        _isConnectedController.add(_isConnected);
        _connectedDevicesController.add(_connectedDevices);
      }
    } catch (e) {
      print('Error loading health settings: $e');
    }
  }

  /// Check connection status with fitness platforms
  Future<void> _checkConnectionStatus() async {
    try {
      // Check Google Fit connection
      final googleFitConnected = await _checkGoogleFitConnection();
      
      // Check Apple Health connection
      final appleHealthConnected = await _checkAppleHealthConnection();
      
      // Check other device connections
      final otherDevicesConnected = await _checkOtherDeviceConnections();

      _isConnected = googleFitConnected || appleHealthConnected || otherDevicesConnected;
      _isConnectedController.add(_isConnected);

      if (_isConnected) {
        await _fetchHealthData();
      }
    } catch (e) {
      print('Error checking connection status: $e');
    }
  }

  /// Check Google Fit connection
  Future<bool> _checkGoogleFitConnection() async {
    try {
      // In a real implementation, you would use the Google Fit API
      // For now, we'll simulate the connection check
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Simulate connection check
      final isConnected = _connectedDevices.any((device) => device.platform == 'google_fit');
      return isConnected;
    } catch (e) {
      print('Error checking Google Fit connection: $e');
      return false;
    }
  }

  /// Check Apple Health connection
  Future<bool> _checkAppleHealthConnection() async {
    try {
      // In a real implementation, you would use the HealthKit API
      // For now, we'll simulate the connection check
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Simulate connection check
      final isConnected = _connectedDevices.any((device) => device.platform == 'apple_health');
      return isConnected;
    } catch (e) {
      print('Error checking Apple Health connection: $e');
      return false;
    }
  }

  /// Check other device connections (Fitbit, Samsung Health, etc.)
  Future<bool> _checkOtherDeviceConnections() async {
    try {
      // In a real implementation, you would check various fitness tracker APIs
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Simulate connection check
      final isConnected = _connectedDevices.any((device) => 
          device.platform != 'google_fit' && device.platform != 'apple_health');
      return isConnected;
    } catch (e) {
      print('Error checking other device connections: $e');
      return false;
    }
  }

  /// Start monitoring health data
  void _startHealthDataMonitoring() {
    _healthDataTimer?.cancel();
    _healthDataTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isConnected) {
        _fetchHealthData();
      }
    });
  }

  /// Fetch health data from connected platforms
  Future<void> _fetchHealthData() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Fetch data from Google Fit
      final googleFitData = await _fetchGoogleFitData(today);
      
      // Fetch data from Apple Health
      final appleHealthData = await _fetchAppleHealthData(today);
      
      // Fetch data from other devices
      final otherDevicesData = await _fetchOtherDevicesData(today);

      // Combine all health data
      _currentHealthData = HealthData(
        date: today,
        steps: _getMaxIntValue([
          googleFitData['steps'] ?? 0,
          appleHealthData['steps'] ?? 0,
          otherDevicesData['steps'] ?? 0,
        ]),
        caloriesBurned: _getMaxIntValue([
          googleFitData['caloriesBurned'] ?? 0,
          appleHealthData['caloriesBurned'] ?? 0,
          otherDevicesData['caloriesBurned'] ?? 0,
        ]),
        distance: _getMaxDoubleValue([
          googleFitData['distance'] ?? 0.0,
          appleHealthData['distance'] ?? 0.0,
          otherDevicesData['distance'] ?? 0.0,
        ]),
        activeMinutes: _getMaxIntValue([
          googleFitData['activeMinutes'] ?? 0,
          appleHealthData['activeMinutes'] ?? 0,
          otherDevicesData['activeMinutes'] ?? 0,
        ]),
        heartRate: _getAverageValue([
          googleFitData['heartRate'] ?? 0,
          appleHealthData['heartRate'] ?? 0,
          otherDevicesData['heartRate'] ?? 0,
        ]),
        sleepHours: _getAverageValue([
          googleFitData['sleepHours'] ?? 0.0,
          appleHealthData['sleepHours'] ?? 0.0,
          otherDevicesData['sleepHours'] ?? 0.0,
        ]),
        weight: _getLatestValue([
          googleFitData['weight'] ?? 0.0,
          appleHealthData['weight'] ?? 0.0,
          otherDevicesData['weight'] ?? 0.0,
        ]),
        lastUpdated: now,
      );

      _healthDataController.add(_currentHealthData);
      await _saveHealthData();
      await _updateDailySummary();
    } catch (e) {
      print('Error fetching health data: $e');
    }
  }

  /// Fetch data from Google Fit
  Future<Map<String, dynamic>> _fetchGoogleFitData(DateTime date) async {
    try {
      // In a real implementation, you would use the Google Fit API
      // For now, we'll simulate the data fetch
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Simulate Google Fit data
      return {
        'steps': 8500 + (DateTime.now().hour * 200),
        'caloriesBurned': 450 + (DateTime.now().hour * 25),
        'distance': 6.2 + (DateTime.now().hour * 0.3),
        'activeMinutes': 45 + (DateTime.now().hour * 2),
        'heartRate': 72 + (DateTime.now().hour % 10),
        'sleepHours': 7.5,
        'weight': 70.5,
      };
    } catch (e) {
      print('Error fetching Google Fit data: $e');
      return {};
    }
  }

  /// Fetch data from Apple Health
  Future<Map<String, dynamic>> _fetchAppleHealthData(DateTime date) async {
    try {
      // In a real implementation, you would use the HealthKit API
      // For now, we'll simulate the data fetch
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Simulate Apple Health data
      return {
        'steps': 8200 + (DateTime.now().hour * 180),
        'caloriesBurned': 420 + (DateTime.now().hour * 22),
        'distance': 5.8 + (DateTime.now().hour * 0.25),
        'activeMinutes': 42 + (DateTime.now().hour * 1.5),
        'heartRate': 75 + (DateTime.now().hour % 8),
        'sleepHours': 7.8,
        'weight': 70.2,
      };
    } catch (e) {
      print('Error fetching Apple Health data: $e');
      return {};
    }
  }

  /// Fetch data from other devices
  Future<Map<String, dynamic>> _fetchOtherDevicesData(DateTime date) async {
    try {
      // In a real implementation, you would use various fitness tracker APIs
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Simulate other devices data
      return {
        'steps': 8800 + (DateTime.now().hour * 220),
        'caloriesBurned': 480 + (DateTime.now().hour * 28),
        'distance': 6.5 + (DateTime.now().hour * 0.35),
        'activeMinutes': 48 + (DateTime.now().hour * 2.5),
        'heartRate': 70 + (DateTime.now().hour % 12),
        'sleepHours': 7.2,
        'weight': 70.8,
      };
    } catch (e) {
      print('Error fetching other devices data: $e');
      return {};
    }
  }

  /// Get maximum value from list (for steps, calories, etc.)
  int _getMaxIntValue(List<int> values) {
    return values.where((v) => v > 0).fold(0, (max, value) => value > max ? value : max);
  }

  /// Get maximum value from list (for distance, weight, etc.)
  double _getMaxDoubleValue(List<double> values) {
    return values.where((v) => v > 0).fold(0.0, (max, value) => value > max ? value : max);
  }

  /// Get average value from list (for heart rate, sleep, etc.)
  double _getAverageValue(List<double> values) {
    final validValues = values.where((v) => v > 0).toList();
    if (validValues.isEmpty) return 0.0;
    return validValues.reduce((a, b) => a + b) / validValues.length;
  }

  /// Get latest value from list (for weight, etc.)
  double _getLatestValue(List<double> values) {
    final validValues = values.where((v) => v > 0).toList();
    return validValues.isNotEmpty ? validValues.last : 0.0;
  }

  /// Save health data to Firestore
  Future<void> _saveHealthData() async {
    final userId = _appStateService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health')
          .doc('data')
          .set(_currentHealthData.toMap());
    } catch (e) {
      print('Error saving health data: $e');
    }
  }

  /// Update daily summary with health data
  Future<void> _updateDailySummary() async {
    // This will trigger the AppStateService to recalculate daily summary
    // with the new health data
    _appStateService.updateDailySummary();
  }

  /// Connect to Google Fit
  Future<bool> connectToGoogleFit() async {
    try {
      // In a real implementation, you would use the Google Fit API
      // For now, we'll simulate the connection
      await Future.delayed(const Duration(seconds: 2));
      
      final device = FitnessDevice(
        id: 'google_fit_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Google Fit',
        platform: 'google_fit',
        isConnected: true,
        lastSync: DateTime.now(),
        capabilities: [
          'steps',
          'calories_burned',
          'distance',
          'active_minutes',
          'heart_rate',
          'sleep',
          'weight',
        ],
      );

      _connectedDevices.add(device);
      _isConnected = true;
      
      _isConnectedController.add(_isConnected);
      _connectedDevicesController.add(_connectedDevices);
      
      await _saveHealthSettings();
      await _fetchHealthData();
      
      return true;
    } catch (e) {
      print('Error connecting to Google Fit: $e');
      return false;
    }
  }

  /// Connect to Apple Health
  Future<bool> connectToAppleHealth() async {
    try {
      // In a real implementation, you would use the HealthKit API
      // For now, we'll simulate the connection
      await Future.delayed(const Duration(seconds: 2));
      
      final device = FitnessDevice(
        id: 'apple_health_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Apple Health',
        platform: 'apple_health',
        isConnected: true,
        lastSync: DateTime.now(),
        capabilities: [
          'steps',
          'calories_burned',
          'distance',
          'active_minutes',
          'heart_rate',
          'sleep',
          'weight',
        ],
      );

      _connectedDevices.add(device);
      _isConnected = true;
      
      _isConnectedController.add(_isConnected);
      _connectedDevicesController.add(_connectedDevices);
      
      await _saveHealthSettings();
      await _fetchHealthData();
      
      return true;
    } catch (e) {
      print('Error connecting to Apple Health: $e');
      return false;
    }
  }

  /// Connect to Fitbit
  Future<bool> connectToFitbit() async {
    try {
      // In a real implementation, you would use the Fitbit API
      // For now, we'll simulate the connection
      await Future.delayed(const Duration(seconds: 2));
      
      final device = FitnessDevice(
        id: 'fitbit_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Fitbit',
        platform: 'fitbit',
        isConnected: true,
        lastSync: DateTime.now(),
        capabilities: [
          'steps',
          'calories_burned',
          'distance',
          'active_minutes',
          'heart_rate',
          'sleep',
          'weight',
        ],
      );

      _connectedDevices.add(device);
      _isConnected = true;
      
      _isConnectedController.add(_isConnected);
      _connectedDevicesController.add(_connectedDevices);
      
      await _saveHealthSettings();
      await _fetchHealthData();
      
      return true;
    } catch (e) {
      print('Error connecting to Fitbit: $e');
      return false;
    }
  }

  /// Connect to Samsung Health
  Future<bool> connectToSamsungHealth() async {
    try {
      // In a real implementation, you would use the Samsung Health API
      // For now, we'll simulate the connection
      await Future.delayed(const Duration(seconds: 2));
      
      final device = FitnessDevice(
        id: 'samsung_health_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Samsung Health',
        platform: 'samsung_health',
        isConnected: true,
        lastSync: DateTime.now(),
        capabilities: [
          'steps',
          'calories_burned',
          'distance',
          'active_minutes',
          'heart_rate',
          'sleep',
          'weight',
        ],
      );

      _connectedDevices.add(device);
      _isConnected = true;
      
      _isConnectedController.add(_isConnected);
      _connectedDevicesController.add(_connectedDevices);
      
      await _saveHealthSettings();
      await _fetchHealthData();
      
      return true;
    } catch (e) {
      print('Error connecting to Samsung Health: $e');
      return false;
    }
  }

  /// Disconnect from a fitness platform
  Future<void> disconnectFromPlatform(String platform) async {
    try {
      _connectedDevices.removeWhere((device) => device.platform == platform);
      _isConnected = _connectedDevices.isNotEmpty;
      
      _isConnectedController.add(_isConnected);
      _connectedDevicesController.add(_connectedDevices);
      
      await _saveHealthSettings();
      
      if (!_isConnected) {
        _currentHealthData = HealthData.empty();
        _healthDataController.add(_currentHealthData);
      }
    } catch (e) {
      print('Error disconnecting from platform: $e');
    }
  }

  /// Save health settings to Firestore
  Future<void> _saveHealthSettings() async {
    final userId = _appStateService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('health')
          .doc('settings')
          .set({
        'isConnected': _isConnected,
        'connectedDevices': _connectedDevices.map((device) => device.toMap()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving health settings: $e');
    }
  }

  /// Get available fitness platforms
  List<FitnessPlatform> getAvailablePlatforms() {
    return [
      FitnessPlatform(
        id: 'google_fit',
        name: 'Google Fit',
        description: 'Track your fitness with Google Fit',
        icon: 'google_fit',
        isAvailable: true,
      ),
      FitnessPlatform(
        id: 'apple_health',
        name: 'Apple Health',
        description: 'Sync with Apple Health app',
        icon: 'apple_health',
        isAvailable: true,
      ),
      FitnessPlatform(
        id: 'fitbit',
        name: 'Fitbit',
        description: 'Connect your Fitbit device',
        icon: 'fitbit',
        isAvailable: true,
      ),
      FitnessPlatform(
        id: 'samsung_health',
        name: 'Samsung Health',
        description: 'Sync with Samsung Health',
        icon: 'samsung_health',
        isAvailable: true,
      ),
    ];
  }

  /// Dispose resources
  void dispose() {
    _healthDataTimer?.cancel();
    _healthDataController.close();
    _isConnectedController.close();
    _connectedDevicesController.close();
  }
}
