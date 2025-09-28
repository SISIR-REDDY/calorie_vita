import 'package:flutter/material.dart';
import '../services/global_google_fit_manager.dart';
import '../models/google_fit_data.dart';

/// Mixin to add automatic Google Fit sync to any screen
mixin GoogleFitSyncMixin<T extends StatefulWidget> on State<T> {
  final GlobalGoogleFitManager _googleFitManager = GlobalGoogleFitManager();

  // Override these in your widget to handle Google Fit data
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    // Default implementation - override in your screen
    print('GoogleFitSyncMixin: Data updated - Steps: ${syncData['steps']}');
  }

  void onGoogleFitConnectionChanged(bool isConnected) {
    // Default implementation - override in your screen
    print('GoogleFitSyncMixin: Connection changed - Connected: $isConnected');
  }

  /// Initialize Google Fit sync for this screen with enhanced error handling
  Future<void> initializeGoogleFitSync() async {
    try {
      print('GoogleFitSyncMixin: Initializing sync for ${widget.runtimeType}');

      // Ensure sync is active with timeout
      await _googleFitManager.ensureSync().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('GoogleFitSyncMixin: Sync initialization timed out');
        },
      );

      // Listen to sync data updates with error handling
      _googleFitManager.syncDataStream.listen(
        (syncData) {
          if (mounted) {
            try {
              onGoogleFitDataUpdate(syncData);
            } catch (e) {
              print('GoogleFitSyncMixin: Error in data update callback: $e');
            }
          }
        },
        onError: (error) {
          print('GoogleFitSyncMixin: Sync data stream error: $error');
        },
      );

      // Listen to connection state changes with error handling
      _googleFitManager.connectionStateStream.listen(
        (isConnected) {
          if (mounted) {
            try {
              onGoogleFitConnectionChanged(isConnected);
            } catch (e) {
              print('GoogleFitSyncMixin: Error in connection callback: $e');
            }
          }
        },
        onError: (error) {
          print('GoogleFitSyncMixin: Connection stream error: $error');
        },
      );

      // Get current data immediately with timeout
      try {
        final currentData = await _googleFitManager.getCurrentData().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('GoogleFitSyncMixin: Current data fetch timed out');
            return null;
          },
        );
        if (currentData != null && mounted) {
          onGoogleFitDataUpdate(currentData);
        }
      } catch (e) {
        print('GoogleFitSyncMixin: Error fetching current data: $e');
      }

      print('GoogleFitSyncMixin: Sync initialized for ${widget.runtimeType}');
    } catch (e) {
      print(
          'GoogleFitSyncMixin: Sync initialization failed for ${widget.runtimeType}: $e');
    }
  }

  /// Force immediate Google Fit sync
  Future<Map<String, dynamic>?> forceGoogleFitSync() async {
    try {
      return await _googleFitManager.forceSync();
    } catch (e) {
      print('GoogleFitSyncMixin: Force sync failed: $e');
      return null;
    }
  }

  /// Check if Google Fit is connected
  bool get isGoogleFitConnected => _googleFitManager.isConnected;

  /// Connect to Google Fit
  Future<bool> connectToGoogleFit() async {
    return await _googleFitManager.connect();
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
      print('GoogleFitSyncMixin: Failed to convert sync data: $e');
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
          print('GoogleFitDataDisplayMixin: Data updated - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
        }
      }
    } catch (e) {
      print('GoogleFitDataDisplayMixin: Error updating data: $e');
    }
  }

  @override
  void onGoogleFitConnectionChanged(bool isConnected) {
    try {
      if (mounted && _isGoogleFitConnected != isConnected) {
        setState(() {
          _isGoogleFitConnected = isConnected;
        });
        print('GoogleFitDataDisplayMixin: Connection changed to: $isConnected');
        
        // If disconnected, clear data
        if (!isConnected) {
          setState(() {
            _currentGoogleFitData = null;
            _lastSyncTime = null;
          });
        }
      }
    } catch (e) {
      print('GoogleFitDataDisplayMixin: Error updating connection state: $e');
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
