import 'dart:async';
import 'google_fit_service.dart';
import 'global_google_fit_manager.dart';
import '../models/google_fit_data.dart';

/// Unified Google Fit Manager to prevent data conflicts and improve performance
/// This service coordinates all Google Fit data sources and provides a single source of truth
class UnifiedGoogleFitManager {
  static final UnifiedGoogleFitManager _instance = UnifiedGoogleFitManager._internal();
  factory UnifiedGoogleFitManager() => _instance;
  UnifiedGoogleFitManager._internal();

  // Prevent multiple disposals
  bool _isDisposed = false;

  // Services - Live data only
  final GoogleFitService _googleFitService = GoogleFitService();
  final GlobalGoogleFitManager _globalGoogleFitManager = GlobalGoogleFitManager();

  // State management
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isLoading = false;
  GoogleFitData? _currentData;
  DateTime? _lastUpdateTime;

  // Stream controllers for unified data
  final StreamController<GoogleFitData?> _dataController = StreamController<GoogleFitData?>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<bool> _loadingController = StreamController<bool>.broadcast();

  // Performance optimization
  Timer? _refreshTimer;
  Timer? _connectionCheckTimer;
  static const Duration _refreshInterval = Duration(minutes: 2);
  static const Duration _connectionCheckInterval = Duration(minutes: 5);


  /// Streams
  Stream<GoogleFitData?> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;

  /// Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  GoogleFitData? get currentData => _currentData;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Get live Google Fit data
  Future<GoogleFitData?> getLiveData() async {
    if (!_isConnected) return null;

    try {
      // Use live Google Fit service for real-time data
      await _loadLiveData();
      // Data is updated internally by _loadLiveData
    } catch (e) {
      print('❌ Live Google Fit data fetch failed: $e');
    }

    return _currentData;
  }

  /// Initialize the unified manager
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) {
      print('⚠️ UnifiedGoogleFitManager: Already initialized or disposed, skipping...');
      return;
    }

    try {
      print('🚀 UnifiedGoogleFitManager: Initializing...');

      // Initialize services - Live data only
      print('🔧 UnifiedGoogleFitManager: Initializing services...');
      await Future.wait([
        _googleFitService.initialize(),
        _globalGoogleFitManager.initialize(),
      ]);
      print('✅ UnifiedGoogleFitManager: All services initialized');

      // Check connection status
      print('🔍 UnifiedGoogleFitManager: Checking connection status...');
      await _checkConnectionStatus();
      print('📡 UnifiedGoogleFitManager: Connection status: $_isConnected');

      // Load live data immediately
      print('📡 UnifiedGoogleFitManager: Loading live data...');
      await _loadLiveData();

      // Start background refresh
      print('🔄 UnifiedGoogleFitManager: Starting background refresh...');
      _startBackgroundRefresh();

      _isInitialized = true;
      print('✅ UnifiedGoogleFitManager: Initialized successfully');
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Initialization failed: $e');
      rethrow;
    }
  }

  /// Load live data immediately
  Future<void> _loadLiveData() async {
    try {
      print('📡 UnifiedGoogleFitManager: Loading live data immediately...');
      
      // Load live data from Google Fit service
      final liveData = await _loadLiveDataFromService();
      if (liveData != null) {
        _updateData(liveData);
        print('✅ UnifiedGoogleFitManager: Live data loaded');
        return;
      }

      print('⚠️ UnifiedGoogleFitManager: No live data available');
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Error loading live data: $e');
    }
  }

  /// Update data and notify listeners safely
  void _updateData(GoogleFitData data) {
    if (_isDisposed) return;
    
    _currentData = data;
    _lastUpdateTime = DateTime.now();
    
    // Only add to stream if controller is not closed
    if (!_dataController.isClosed) {
      _dataController.add(data);
    }
  }

  /// Check connection status with enhanced validation
  Future<void> _checkConnectionStatus() async {
    try {
      final wasConnected = _isConnected;
      
      // Use enhanced validation with retry mechanism
      final googleFitConnected = await _googleFitService
          .validateAuthenticationWithRetry(maxRetries: 2)
          .timeout(const Duration(seconds: 8));
      final globalConnected = _globalGoogleFitManager.isConnected;
      
      print('🔍 UnifiedGoogleFitManager: Service connection status - GoogleFit: $googleFitConnected, Global: $globalConnected');
      
      _isConnected = googleFitConnected || globalConnected;

      if (wasConnected != _isConnected) {
        if (!_connectionController.isClosed) {
          _connectionController.add(_isConnected);
        }
        
        if (_isConnected) {
          print('✅ UnifiedGoogleFitManager: Connected');
          await _loadData();
        } else {
          print('⚠️ UnifiedGoogleFitManager: Disconnected');
          _currentData = null;
          if (!_dataController.isClosed) {
            _dataController.add(null);
          }
        }
      } else {
        print('📡 UnifiedGoogleFitManager: Connection status unchanged: $_isConnected');
      }
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Connection check failed: $e');
      
      // If we were connected and now we're not, update the state
      if (_isConnected) {
        _isConnected = false;
        _currentData = null;
        if (!_connectionController.isClosed) {
          _connectionController.add(false);
        }
        if (!_dataController.isClosed) {
          _dataController.add(null);
        }
      }
    }
  }

  /// Load Google Fit data from live sources
  Future<GoogleFitData?> _loadData() async {
    if (!_isConnected || _isLoading || _isDisposed) return _currentData;

    _isLoading = true;
    if (!_loadingController.isClosed) {
      _loadingController.add(true);
    }

    try {
      print('🔄 UnifiedGoogleFitManager: Loading live data...');

      // Load live data from Google Fit service
      final liveData = await _loadLiveDataFromService();
      if (liveData != null) {
        _updateData(liveData);
        return liveData;
      }

      print('⚠️ UnifiedGoogleFitManager: No live data found');
      return _currentData;
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Data loading failed: $e');
      return _currentData;
    } finally {
      _isLoading = false;
      if (!_loadingController.isClosed) {
        _loadingController.add(false);
      }
    }
  }

  /// Load live data from Google Fit service
  Future<GoogleFitData?> _loadLiveDataFromService() async {
    try {
      final today = DateTime.now();
      final futures = await Future.wait([
        _googleFitService.getDailySteps(today),
        _googleFitService.getDailyCaloriesBurned(today),
        _googleFitService.getWorkoutSessions(today),
      ], eagerError: false);

      return GoogleFitData(
        date: today,
        steps: futures[0] as int?,
        caloriesBurned: futures[1] as double?,
        workoutSessions: futures[2] as int? ?? 0,
        workoutDuration: 0.0,
      );
    } catch (e) {
      print('⚠️ Live Google Fit service failed: $e');
      return null;
    }
  }



  /// Start background refresh
  void _startBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (_isConnected && !_isLoading) {
        _loadData();
      }
    });

    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(_connectionCheckInterval, (timer) {
      _checkConnectionStatus();
    });
  }

  /// Force refresh data
  Future<GoogleFitData?> forceRefresh() async {
    if (!_isConnected) return _currentData;
    
    print('🔄 UnifiedGoogleFitManager: Force refresh requested');
    return await _loadData();
  }

  /// Connect to Google Fit
  Future<bool> connect() async {
    try {
      final success = await _googleFitService.authenticate();
      if (success) {
        await _checkConnectionStatus();
        if (_isConnected) {
          await _loadData();
        }
      }
      return success;
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Connection failed: $e');
      return false;
    }
  }

  /// Disconnect from Google Fit with complete cleanup
  Future<void> disconnect() async {
    try {
      print('🔌 UnifiedGoogleFitManager: Starting disconnect process...');
      
      // Stop all timers first
      _refreshTimer?.cancel();
      _connectionCheckTimer?.cancel();
      
      // Disconnect from Google Fit service
      await _googleFitService.signOut();
      
      // Reset connection state
      _isConnected = false;
      _currentData = null;
      
      // Notify listeners of disconnection
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
      if (!_dataController.isClosed) {
        _dataController.add(null);
      }
      
      print('✅ UnifiedGoogleFitManager: Disconnected successfully');
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Disconnect failed: $e');
      
      // Force reset state even if disconnect fails
      _isConnected = false;
      _currentData = null;
      _refreshTimer?.cancel();
      _connectionCheckTimer?.cancel();
    }
  }

  /// Get current data without triggering refresh
  GoogleFitData? getCurrentData() {
    return _currentData;
  }

  /// Preload live data for instant display (call this when app starts)
  Future<void> preloadData() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Force load live data immediately
    await _loadLiveData();
    
    // If no live data, try to load fresh data in background
    if (_currentData == null) {
      _loadData();
    }
  }

  /// Dispose resources
  void dispose() {
    if (_isDisposed) {
      print('⚠️ UnifiedGoogleFitManager: Already disposed, skipping...');
      return;
    }

    _isDisposed = true;
    _refreshTimer?.cancel();
    _connectionCheckTimer?.cancel();
    
    // Only close controllers if they haven't been closed already
    if (!_dataController.isClosed) {
      _dataController.close();
    }
    if (!_connectionController.isClosed) {
      _connectionController.close();
    }
    if (!_loadingController.isClosed) {
      _loadingController.close();
    }
    
    print('🗑️ UnifiedGoogleFitManager: Disposed');
  }
}
