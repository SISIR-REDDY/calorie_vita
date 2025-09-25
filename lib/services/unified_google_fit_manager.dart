import 'dart:async';
import 'google_fit_service.dart';
import 'optimized_google_fit_service.dart';
import 'optimized_google_fit_cache_service.dart';
import 'global_google_fit_manager.dart';
import 'google_fit_performance_optimizer.dart';
import '../models/google_fit_data.dart';

/// Unified Google Fit Manager to prevent data conflicts and improve performance
/// This service coordinates all Google Fit data sources and provides a single source of truth
class UnifiedGoogleFitManager {
  static final UnifiedGoogleFitManager _instance = UnifiedGoogleFitManager._internal();
  factory UnifiedGoogleFitManager() => _instance;
  UnifiedGoogleFitManager._internal();

  // Services
  final GoogleFitService _googleFitService = GoogleFitService();
  final OptimizedGoogleFitService _optimizedGoogleFitService = OptimizedGoogleFitService();
  final OptimizedGoogleFitCacheService _optimizedCacheService = OptimizedGoogleFitCacheService();
  final GlobalGoogleFitManager _globalGoogleFitManager = GlobalGoogleFitManager();
  final GoogleFitPerformanceOptimizer _performanceOptimizer = GoogleFitPerformanceOptimizer();

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

  // Data validation
  static const Duration _dataValidityDuration = Duration(minutes: 5);

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

  /// Initialize the unified manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 UnifiedGoogleFitManager: Initializing...');

      // Initialize all services
      await Future.wait([
        _googleFitService.initialize(),
        _optimizedGoogleFitService.initialize(),
        _optimizedCacheService.initialize(),
        _globalGoogleFitManager.initialize(),
      ]);

      // Check connection status
      await _checkConnectionStatus();

      // Load cached data immediately for instant display
      await _loadCachedDataImmediately();

      // Start background refresh
      _startBackgroundRefresh();

      _isInitialized = true;
      print('✅ UnifiedGoogleFitManager: Initialized successfully');
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Initialization failed: $e');
      rethrow;
    }
  }

  /// Load cached data immediately for instant display
  Future<void> _loadCachedDataImmediately() async {
    try {
      print('📱 UnifiedGoogleFitManager: Loading cached data immediately...');
      
      // Try to get cached data from performance optimizer first
      final cachedData = _performanceOptimizer.getCachedData('unified_google_fit');
      if (cachedData != null) {
        _updateData(cachedData);
        print('✅ UnifiedGoogleFitManager: Cached data loaded instantly');
        return;
      }

      // Try optimized cache service
      final optimizedCacheData = await _optimizedCacheService.getTodayData();
      if (optimizedCacheData != null) {
        _performanceOptimizer.cacheData('unified_google_fit', optimizedCacheData);
        _updateData(optimizedCacheData);
        print('✅ UnifiedGoogleFitManager: Optimized cache data loaded');
        return;
      }

      // Try global manager cache
      final globalData = await _globalGoogleFitManager.getCurrentData();
      if (globalData != null) {
        final googleFitData = GoogleFitData(
          date: DateTime.now(),
          steps: globalData['steps'] as int?,
          caloriesBurned: (globalData['caloriesBurned'] as num?)?.toDouble(),
          distance: (globalData['distance'] as num?)?.toDouble(),
          weight: (globalData['weight'] as num?)?.toDouble(),
        );
        _performanceOptimizer.cacheData('unified_google_fit', googleFitData);
        _updateData(googleFitData);
        print('✅ UnifiedGoogleFitManager: Global manager cache data loaded');
        return;
      }

      print('⚠️ UnifiedGoogleFitManager: No cached data available');
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Error loading cached data: $e');
    }
  }

  /// Check connection status
  Future<void> _checkConnectionStatus() async {
    try {
      final wasConnected = _isConnected;
      
      // Check multiple services for connection status
      _isConnected = _googleFitService.isConnected || 
                    _optimizedGoogleFitService.isConnected ||
                    _globalGoogleFitManager.isConnected;

      if (wasConnected != _isConnected) {
        _connectionController.add(_isConnected);
        
        if (_isConnected) {
          print('✅ UnifiedGoogleFitManager: Connected');
          await _loadData();
        } else {
          print('⚠️ UnifiedGoogleFitManager: Disconnected');
          _currentData = null;
          _dataController.add(null);
        }
      }
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Connection check failed: $e');
    }
  }

  /// Load Google Fit data with priority order and performance optimization
  Future<GoogleFitData?> _loadData() async {
    if (!_isConnected || _isLoading) return _currentData;

    _isLoading = true;
    _loadingController.add(true);

    try {
      print('🔄 UnifiedGoogleFitManager: Loading data...');

      // Check cache first
      final cachedData = _performanceOptimizer.getCachedData('unified_google_fit');
      if (cachedData != null) {
        print('📱 Using cached data from performance optimizer');
        _updateData(cachedData);
        return cachedData;
      }

      // Collect data from all sources
      final dataSources = <GoogleFitData>[];
      
      // Priority 1: Try optimized cache service (fastest)
      if (_performanceOptimizer.shouldMakeApiCall('optimized_cache')) {
        final data = await _loadFromOptimizedCache();
        if (data != null) dataSources.add(data);
        _performanceOptimizer.recordApiCall('optimized_cache');
      }

      // Priority 2: Try global manager
      if (_performanceOptimizer.shouldMakeApiCall('global_manager')) {
        final data = await _loadFromGlobalManager();
        if (data != null) dataSources.add(data);
        _performanceOptimizer.recordApiCall('global_manager');
      }

      // Priority 3: Try optimized service
      if (_performanceOptimizer.shouldMakeApiCall('optimized_service')) {
        final data = await _loadFromOptimizedService();
        if (data != null) dataSources.add(data);
        _performanceOptimizer.recordApiCall('optimized_service');
      }

      // Priority 4: Try original service
      if (_performanceOptimizer.shouldMakeApiCall('original_service')) {
        final data = await _loadFromOriginalService();
        if (data != null) dataSources.add(data);
        _performanceOptimizer.recordApiCall('original_service');
      }

      // Merge and validate data from all sources
      final mergedData = _performanceOptimizer.mergeDataSources(dataSources);
      if (mergedData != null) {
        // Smooth data to prevent UI flickering
        final smoothedData = _performanceOptimizer.smoothData(mergedData, _currentData);
        
        // Cache the data
        _performanceOptimizer.cacheData('unified_google_fit', smoothedData!);
        
        _updateData(smoothedData);
        return smoothedData;
      }

      print('⚠️ UnifiedGoogleFitManager: No valid data found');
      return _currentData;
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Data loading failed: $e');
      return _currentData;
    } finally {
      _isLoading = false;
      _loadingController.add(false);
    }
  }

  /// Load from optimized cache service
  Future<GoogleFitData?> _loadFromOptimizedCache() async {
    try {
      return await _optimizedCacheService.getTodayData();
    } catch (e) {
      print('⚠️ Optimized cache failed: $e');
      return null;
    }
  }

  /// Load from global manager
  Future<GoogleFitData?> _loadFromGlobalManager() async {
    try {
      final data = await _globalGoogleFitManager.getCurrentData();
      if (data != null) {
        return GoogleFitData(
          date: DateTime.now(),
          steps: data['steps'] as int?,
          caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble(),
          distance: (data['distance'] as num?)?.toDouble(),
          weight: (data['weight'] as num?)?.toDouble(),
        );
      }
      return null;
    } catch (e) {
      print('⚠️ Global manager failed: $e');
      return null;
    }
  }

  /// Load from optimized service
  Future<GoogleFitData?> _loadFromOptimizedService() async {
    try {
      final data = await _optimizedGoogleFitService.getOptimizedFitnessData();
      if (data != null) {
        return GoogleFitData(
          date: DateTime.now(),
          steps: data['steps'] as int?,
          caloriesBurned: (data['caloriesBurned'] as num?)?.toDouble(),
          distance: (data['distance'] as num?)?.toDouble(),
          weight: (data['weight'] as num?)?.toDouble(),
        );
      }
      return null;
    } catch (e) {
      print('⚠️ Optimized service failed: $e');
      return null;
    }
  }

  /// Load from original service
  Future<GoogleFitData?> _loadFromOriginalService() async {
    try {
      final today = DateTime.now();
      final futures = await Future.wait([
        _googleFitService.getDailySteps(today),
        _googleFitService.getDailyCaloriesBurned(today),
        _googleFitService.getDailyDistance(today),
        _googleFitService.getCurrentWeight(),
      ], eagerError: false);

      return GoogleFitData(
        date: today,
        steps: futures[0] as int?,
        caloriesBurned: futures[1] as double?,
        distance: futures[2] as double?,
        weight: futures[3] as double?,
      );
    } catch (e) {
      print('⚠️ Original service failed: $e');
      return null;
    }
  }

  /// Update data and notify listeners
  void _updateData(GoogleFitData data) {
    _currentData = data;
    _lastUpdateTime = DateTime.now();
    _dataController.add(data);
    print('✅ UnifiedGoogleFitManager: Data updated - Steps: ${data.steps}, Calories: ${data.caloriesBurned}');
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

  /// Disconnect from Google Fit
  Future<void> disconnect() async {
    try {
      await _googleFitService.signOut();
      _isConnected = false;
      _currentData = null;
      _connectionController.add(false);
      _dataController.add(null);
      print('🔌 UnifiedGoogleFitManager: Disconnected');
    } catch (e) {
      print('❌ UnifiedGoogleFitManager: Disconnect failed: $e');
    }
  }

  /// Get current data without triggering refresh
  GoogleFitData? getCurrentData() {
    return _currentData;
  }

  /// Preload data for instant display (call this when app starts)
  Future<void> preloadData() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Force load cached data immediately
    await _loadCachedDataImmediately();
    
    // If no cached data, try to load fresh data in background
    if (_currentData == null) {
      _loadData();
    }
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _dataController.close();
    _connectionController.close();
    _loadingController.close();
    _performanceOptimizer.dispose();
    print('🗑️ UnifiedGoogleFitManager: Disposed');
  }
}
