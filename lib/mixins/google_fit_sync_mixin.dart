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

  /// Initialize Google Fit sync for this screen
  Future<void> initializeGoogleFitSync() async {
    try {
      print('GoogleFitSyncMixin: Initializing sync for ${widget.runtimeType}');
      
      // Ensure sync is active
      await _googleFitManager.ensureSync();
      
      // Listen to sync data updates
      _googleFitManager.syncDataStream.listen((syncData) {
        if (mounted) {
          onGoogleFitDataUpdate(syncData);
        }
      });
      
      // Listen to connection state changes
      _googleFitManager.connectionStateStream.listen((isConnected) {
        if (mounted) {
          onGoogleFitConnectionChanged(isConnected);
        }
      });
      
      // Get current data immediately
      final currentData = await _googleFitManager.getCurrentData();
      if (currentData != null && mounted) {
        onGoogleFitDataUpdate(currentData);
      }
      
      print('GoogleFitSyncMixin: Sync initialized for ${widget.runtimeType}');
      
    } catch (e) {
      print('GoogleFitSyncMixin: Sync initialization failed for ${widget.runtimeType}: $e');
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
        distance: (syncData['distance'] as num?)?.toDouble(),
        weight: (syncData['weight'] as num?)?.toDouble(),
      );
    } catch (e) {
      print('GoogleFitSyncMixin: Failed to convert sync data: $e');
      return null;
    }
  }
}

/// Widget mixin for screens that display Google Fit data
mixin GoogleFitDataDisplayMixin<T extends StatefulWidget> on State<T>, GoogleFitSyncMixin<T> {
  GoogleFitData? _currentGoogleFitData;
  bool _isGoogleFitConnected = false;
  DateTime? _lastSyncTime;

  GoogleFitData? get currentGoogleFitData => _currentGoogleFitData;
  bool get isGoogleFitConnectedDisplay => _isGoogleFitConnected;
  DateTime? get lastSyncTime => _lastSyncTime;

  @override
  void onGoogleFitDataUpdate(Map<String, dynamic> syncData) {
    final data = syncDataToGoogleFitData(syncData);
    if (data != null && mounted) {
      setState(() {
        _currentGoogleFitData = data;
        _lastSyncTime = DateTime.now();
      });
    }
    // Display mixin handles data display - base sync already handled by GoogleFitSyncMixin
  }

  @override
  void onGoogleFitConnectionChanged(bool isConnected) {
    if (mounted) {
      setState(() {
        _isGoogleFitConnected = isConnected;
      });
    }
    // Display mixin handles connection display - base sync already handled by GoogleFitSyncMixin  
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