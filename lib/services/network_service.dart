import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Network service to handle connectivity and offline/online states
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.none];
  Timer? _connectivityCheckTimer;

  // Streams
  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool get isOnline => _isOnline;
  List<ConnectivityResult> get currentConnectivity => _currentConnectivity;

  /// Initialize the network service
  Future<void> initialize() async {
    try {
      // Get initial connectivity state
      _currentConnectivity = await _connectivity.checkConnectivity();
      _isOnline = !_currentConnectivity.contains(ConnectivityResult.none);
      
      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      
      // Start periodic connectivity checks
      _startConnectivityChecks();
      
      print('NetworkService initialized. Online: $_isOnline, Type: $_currentConnectivity');
    } catch (e) {
      print('Error initializing NetworkService: $e');
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _currentConnectivity = results;
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      _connectivityController.add(_isOnline);
      print('Connectivity changed: ${_isOnline ? 'Online' : 'Offline'} ($results)');
    }
  }

  /// Start periodic connectivity checks
  void _startConnectivityChecks() {
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkConnectivity();
    });
  }

  /// Check connectivity by making a test request
  Future<void> _checkConnectivity() async {
    try {
      // Try to reach a reliable endpoint
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));
      
      final wasOnline = _isOnline;
      _isOnline = response.statusCode == 200;
      
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
        print('Connectivity check: ${_isOnline ? 'Online' : 'Offline'}');
      }
    } catch (e) {
      final wasOnline = _isOnline;
      _isOnline = false;
      
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
        print('Connectivity check failed: Offline');
      }
    }
  }

  /// Check if we can reach a specific URL
  Future<bool> canReachUrl(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check if we can reach Firebase services
  Future<bool> canReachFirebase() async {
    try {
      // Try to reach Firebase Auth endpoint
      final response = await http.get(
        Uri.parse('https://identitytoolkit.googleapis.com'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode < 500; // Any response < 500 means Firebase is reachable
    } catch (e) {
      return false;
    }
  }

  /// Get network quality based on response time
  Future<NetworkQuality> getNetworkQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 15));
      
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;
      
      if (response.statusCode == 200) {
        if (responseTime < 500) {
          return NetworkQuality.excellent;
        } else if (responseTime < 1000) {
          return NetworkQuality.good;
        } else if (responseTime < 2000) {
          return NetworkQuality.fair;
        } else {
          return NetworkQuality.poor;
        }
      } else {
        return NetworkQuality.poor;
      }
    } catch (e) {
      return NetworkQuality.poor;
    }
  }

  /// Get detailed network information
  Future<Map<String, dynamic>> getNetworkInfo() async {
    final quality = await getNetworkQuality();
    
    return {
      'is_online': _isOnline,
      'connectivity_type': _currentConnectivity.toString(),
      'network_quality': quality.toString(),
      'can_reach_firebase': await canReachFirebase(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Wait for network to become available
  Future<void> waitForNetwork({Duration timeout = const Duration(minutes: 5)}) async {
    if (_isOnline) return;
    
    final completer = Completer<void>();
    late StreamSubscription subscription;
    Timer? timeoutTimer;
    
    subscription = _connectivityController.stream.listen((isOnline) {
      if (isOnline) {
        subscription.cancel();
        timeoutTimer?.cancel();
        completer.complete();
      }
    });
    
    timeoutTimer = Timer(timeout, () {
      subscription.cancel();
      completer.completeError(TimeoutException('Network did not become available within timeout', timeout));
    });
    
    return completer.future;
  }

  /// Dispose resources
  void dispose() {
    _connectivityCheckTimer?.cancel();
    _connectivityController.close();
  }
}

/// Network quality enumeration
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
}

/// Timeout exception for network operations
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message (timeout: ${timeout.inSeconds}s)';
}
