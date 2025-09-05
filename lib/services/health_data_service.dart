import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/health_data.dart';
import '../models/daily_summary.dart';
import '../models/reward_system.dart';
import 'google_fit_service.dart';
import 'rewards_service.dart';
import 'error_handler.dart';

/// Unified health data service that manages all health sources
class HealthDataService {
  static final HealthDataService _instance = HealthDataService._internal();
  factory HealthDataService() => _instance;
  HealthDataService._internal();

  final ErrorHandler _errorHandler = ErrorHandler();
  final RewardsService _rewardsService = RewardsService();
  
  // Health source services
  final GoogleFitService _googleFitService = GoogleFitService();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State management
  bool _isInitialized = false;
  String? _activeSource;
  Timer? _syncTimer;

  // Stream controllers
  final StreamController<HealthData> _healthDataController = StreamController<HealthData>.broadcast();
  final StreamController<Map<String, bool>> _sourceStatusController = StreamController<Map<String, bool>>.broadcast();

  // Getters
  Stream<HealthData> get healthDataStream => _healthDataController.stream;
  Stream<Map<String, bool>> get sourceStatusStream => _sourceStatusController.stream;
  String? get activeSource => _activeSource;
  bool get isInitialized => _isInitialized;

  /// Initialize health data service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Initialize all health services
      await _googleFitService.initialize();

      // Set up listeners for each service
      _setupServiceListeners();

      _isInitialized = true;
      if (kDebugMode) print('✅ Health Data Service initialized');
      return true;
    } catch (e) {
      _errorHandler.handleDataError('health_data_init', e);
      if (kDebugMode) print('❌ Failed to initialize Health Data Service: $e');
      return false;
    }
  }

  /// Set up listeners for all health services
  void _setupServiceListeners() {
    // Health Connect listener
    _googleFitService.healthDataStream.listen((data) {
      _processHealthData(data, 'Health Connect');
    });



    // Connection status listeners
    _googleFitService.connectionStatusStream.listen((connected) {
      _updateSourceStatus('Health Connect', connected);
    });


  }

  /// Process health data from any source
  Future<void> _processHealthData(HealthData data, String source) async {
    try {
      // Update active source
      _activeSource = source;

      // Save to Firestore
      await _saveHealthDataToFirestore(data);

      // Update daily summary
      await _updateDailySummary(data);

      // Check for goal achievements and update rewards
      await _checkGoalAchievements(data);

      // Emit to listeners
      _healthDataController.add(data);

      if (kDebugMode) print('✅ Processed health data from $source: ${data.steps} steps, ${data.caloriesBurned} calories');
    } catch (e) {
      _errorHandler.handleDataError('process_health_data', e);
      if (kDebugMode) print('❌ Error processing health data: $e');
    }
  }

  /// Save health data to Firestore
  Future<void> _saveHealthDataToFirestore(HealthData data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dateKey = _getDateKey(data.date);
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailySummary')
          .doc(dateKey);

      await docRef.set({
        'steps': data.steps,
        'caloriesBurned': data.caloriesBurned,
        'distance': data.distance,
        'heartRate': data.heartRate,
        'sleepHours': data.sleepHours,
        'waterIntake': data.waterIntake,
        'healthSource': data.source,
        'lastHealthUpdate': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(data.date),
      }, SetOptions(merge: true));

      if (kDebugMode) print('✅ Saved health data to Firestore');
    } catch (e) {
      _errorHandler.handleFirebaseError('save_health_data', e);
      if (kDebugMode) print('❌ Error saving health data to Firestore: $e');
    }
  }

  /// Update daily summary with health data
  Future<void> _updateDailySummary(HealthData data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dateKey = _getDateKey(data.date);
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailySummary')
          .doc(dateKey);

      await docRef.set({
        'steps': data.steps,
        'caloriesBurned': data.caloriesBurned,
        'distance': data.distance,
        'heartRate': data.heartRate,
        'sleepHours': data.sleepHours,
        'waterIntake': data.waterIntake,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) print('✅ Updated daily summary with health data');
    } catch (e) {
      _errorHandler.handleFirebaseError('update_daily_summary', e);
      if (kDebugMode) print('❌ Error updating daily summary: $e');
    }
  }

  /// Check for goal achievements and update rewards
  Future<void> _checkGoalAchievements(HealthData data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check steps goal
      if (data.steps >= 10000) {
        await _rewardsService.processActivity(
          activityType: ActivityType.steps,
          activityData: {'steps': data.steps, 'goalReached': true},
        );
      }

      // Check calories goal
      if (data.caloriesBurned >= 500) {
        await _rewardsService.processActivity(
          activityType: ActivityType.exercise,
          activityData: {'calories': data.caloriesBurned, 'goalReached': true},
        );
      }

      // Check distance goal
      if (data.distance >= 5.0) {
        await _rewardsService.processActivity(
          activityType: ActivityType.exercise,
          activityData: {'distance': data.distance, 'goalReached': true},
        );
      }

      if (kDebugMode) print('✅ Checked goal achievements for health data');
    } catch (e) {
      _errorHandler.handleDataError('check_goal_achievements', e);
      if (kDebugMode) print('❌ Error checking goal achievements: $e');
    }
  }

  /// Update source status
  void _updateSourceStatus(String source, bool connected) {
    final status = <String, bool>{
      'Google Health': _googleFitService.isConnected,
    };
    _sourceStatusController.add(status);
  }

  /// Connect to Health Connect
  Future<bool> connectGoogleFit() async {
    try {
      if (!Platform.isAndroid) {
        if (kDebugMode) print('❌ Health Connect is only available on Android');
        return false;
      }

      final connected = await _googleFitService.connect();
      if (connected) {
        await _googleFitService.startRealTimeMonitoring();
      }
      return connected;
    } catch (e) {
      _errorHandler.handleDataError('connect_health_connect', e);
      return false;
    }
  }



  /// Get available health sources
  Future<Map<String, bool>> getAvailableSources() async {
    try {
      final sources = <String, bool>{};

      if (Platform.isAndroid) {
        sources['Google Health'] = await _googleFitService.isAvailable();
      }


      return sources;
    } catch (e) {
      _errorHandler.handleDataError('get_available_sources', e);
      return {};
    }
  }

  /// Get current health data from all connected sources
  Future<List<HealthData>> getCurrentHealthData() async {
    try {
      final healthDataList = <HealthData>[];

      if (_googleFitService.isConnected) {
        try {
          final data = await _googleFitService.getTodayHealthData();
          healthDataList.add(data);
        } catch (e) {
          if (kDebugMode) print('❌ Error getting Google Fit data: $e');
        }
      }



      return healthDataList;
    } catch (e) {
      _errorHandler.handleDataError('get_current_health_data', e);
      return [];
    }
  }

  /// Start automatic health data sync
  Future<void> startAutoSync() async {
    try {
      // Sync every 5 minutes
      _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
        await _syncAllHealthData();
      });

      if (kDebugMode) print('✅ Started automatic health data sync');
    } catch (e) {
      _errorHandler.handleDataError('start_auto_sync', e);
    }
  }

  /// Stop automatic health data sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (kDebugMode) print('🛑 Stopped automatic health data sync');
  }

  /// Sync all health data
  Future<void> _syncAllHealthData() async {
    try {
      final healthDataList = await getCurrentHealthData();
      for (final data in healthDataList) {
        await _processHealthData(data, data.source);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error in auto sync: $e');
    }
  }

  /// Get date key for Firestore
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Disconnect from all sources
  Future<void> disconnectAll() async {
    try {
      await _googleFitService.disconnect();
      stopAutoSync();
      if (kDebugMode) print('🔌 Disconnected from all health sources');
    } catch (e) {
      _errorHandler.handleDataError('disconnect_all', e);
    }
  }

  /// Dispose resources
  void dispose() {
    disconnectAll();
    _healthDataController.close();
    _sourceStatusController.close();
  }
}
