import 'package:flutter/material.dart';
import '../services/health_connect_manager.dart';
import '../models/google_fit_data.dart';
import 'package:flutter/foundation.dart';
import '../config/production_config.dart';

/// Mixin to add automatic Health Connect sync to any screen
mixin GoogleFitSyncMixin<T extends StatefulWidget> on State<T> {
  final HealthConnectManager _googleFitManager = HealthConnectManager();

  // Override these in your widget to handle Google Fit data
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    // Default implementation - override in your screen
    if (kDebugMode) debugPrint('GoogleFitSyncMixin: Data updated - Steps: ${syncData['steps']}');
  }

  void onGoogleFitConnectionChanged(bool isConnected) {
    // Default implementation - override in your screen
    if (kDebugMode) debugPrint('GoogleFitSyncMixin: Connection changed - Connected: $isConnected');
  }

  /// Initialize Google Fit sync for this screen with enhanced error handling
  Future<void> initializeGoogleFitSync() async {
    try {
      if (kDebugMode) debugPrint('GoogleFitSyncMixin: Initializing sync for ${widget.runtimeType}');

      // Initialize optimized manager
      await _googleFitManager.initialize();

      // Listen to data stream
      _googleFitManager.dataStream.listen(
        (data) {
          if (mounted && data != null) {
            try {
              final syncData = {
                'steps': data.steps,
                'caloriesBurned': data.caloriesBurned,
                'workoutSessions': data.workoutSessions,
                'workoutDuration': data.workoutDuration,
              };
              onGoogleFitDataUpdate(syncData);
            } catch (e) {
              if (kDebugMode) debugPrint('GoogleFitSyncMixin: Error in data update callback: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('GoogleFitSyncMixin: Data stream error: $error');
        },
      );

      // Listen to connection state
      _googleFitManager.connectionStream.listen(
        (isConnected) {
          if (mounted) {
            try {
              onGoogleFitConnectionChanged(isConnected);
            } catch (e) {
              if (kDebugMode) debugPrint('GoogleFitSyncMixin: Error in connection callback: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint('GoogleFitSyncMixin: Connection stream error: $error');
        },
      );

      // Get current data immediately
      final currentData = _googleFitManager.getCurrentData();
      if (currentData != null && mounted) {
        final syncData = {
          'steps': currentData.steps,
          'caloriesBurned': currentData.caloriesBurned,
          'workoutSessions': currentData.workoutSessions,
          'workoutDuration': currentData.workoutDuration,
        };
        onGoogleFitDataUpdate(syncData);
      }

      if (kDebugMode) debugPrint('GoogleFitSyncMixin: Sync initialized for ${widget.runtimeType}');
    } catch (e) {
      if (kDebugMode) debugPrint(
          'GoogleFitSyncMixin: Sync initialization failed for ${widget.runtimeType}: $e');
    }
  }

  /// Force immediate Google Fit sync
  Future<Map<String, dynamic>?> forceGoogleFitSync() async {
    try {
      final data = await _googleFitManager.forceRefresh();
      if (data != null) {
        return {
          'steps': data.steps,
          'caloriesBurned': data.caloriesBurned,
          'workoutSessions': data.workoutSessions,
          'workoutDuration': data.workoutDuration,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleFitSyncMixin: Force sync failed: $e');
      return null;
    }
  }

  /// Check if Google Fit is connected
  bool get isGoogleFitConnected => _googleFitManager.isConnected;

  /// Connect to Health Connect
  Future<bool> connectToGoogleFit() async {
    return await _googleFitManager.requestPermissions();
  }

  /// Helper to convert sync data to GoogleFitData model
  GoogleFitData? syncDataToGoogleFitData(Map<String, dynamic> syncData) {
    try {
      return GoogleFitData(
        date: DateTime.now(),
        steps: syncData['steps'] as int?,
        caloriesBurned: (syncData['caloriesBurned'] as num?)?.toDouble(),
        workoutSessions: syncData['workoutSessions'] as int?,
        workoutDuration: (syncData['workoutDuration'] as num?)?.toDouble(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleFitSyncMixin: Failed to convert sync data: $e');
      return null;
    }
  }
}

/// Widget mixin for screens that display Google Fit data
mixin GoogleFitDataDisplayMixin<T extends StatefulWidget>
    on State<T>, GoogleFitSyncMixin<T> {
  GoogleFitData? _currentGoogleFitData;
  bool _isGoogleFitConnected = false;
  DateTime? _lastSyncTime;

  GoogleFitData? get currentGoogleFitData => _currentGoogleFitData;
  bool get isGoogleFitConnectedDisplay => _isGoogleFitConnected;
  DateTime? get lastSyncTime => _lastSyncTime;

  @override
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    try {
      final data = syncDataToGoogleFitData(syncData);
      if (data != null && mounted) {
        // Check if data has actually changed to avoid unnecessary UI updates
        if (_currentGoogleFitData == null || 
            _currentGoogleFitData!.steps != data.steps ||
            _currentGoogleFitData!.caloriesBurned != data.caloriesBurned ||
            _currentGoogleFitData!.workoutSessions != data.workoutSessions) {
          setState(() {
            _currentGoogleFitData = data;
            _lastSyncTime = DateTime.now();
          });
          if (kDebugMode) debugPrint('GoogleFitDataDisplayMixin: Data updated - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleFitDataDisplayMixin: Error updating data: $e');
    }
  }

  @override
  void onGoogleFitConnectionChanged(bool isConnected) {
    try {
      if (mounted && _isGoogleFitConnected != isConnected) {
        setState(() {
          _isGoogleFitConnected = isConnected;
        });
        if (kDebugMode) debugPrint('GoogleFitDataDisplayMixin: Connection changed to: $isConnected');
        
        // If disconnected, clear data
        if (!isConnected) {
          setState(() {
            _currentGoogleFitData = null;
            _lastSyncTime = null;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('GoogleFitDataDisplayMixin: Error updating connection state: $e');
    }
  }

  /// Get formatted sync time for display
  String get formattedLastSyncTime {
    if (_lastSyncTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

