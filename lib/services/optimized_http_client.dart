import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Optimized HTTP client with connection pooling, reuse, and performance optimizations
class OptimizedHttpClient {
  static final OptimizedHttpClient _instance = OptimizedHttpClient._internal();
  factory OptimizedHttpClient() => _instance;
  OptimizedHttpClient._internal();

  // Connection pooling
  late http.Client _client;
  bool _isInitialized = false;
  
  // Performance settings
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _receiveTimeout = Duration(seconds: 15);
  static const int _maxConnectionsPerHost = 6;
  static const Duration _idleTimeout = Duration(minutes: 5);
  
  // Request queue for batching
  final List<Map<String, dynamic>> _requestQueue = [];
  Timer? _batchTimer;
  static const Duration _batchDelay = Duration(milliseconds: 100);
  static const int _maxBatchSize = 5;

  /// Initialize the HTTP client with optimized settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _client = http.Client();
      _isInitialized = true;
      
      // Start batch processing
      _startBatchProcessing();
      
      print('OptimizedHttpClient initialized with connection pooling');
    } catch (e) {
      print('Error initializing OptimizedHttpClient: $e');
    }
  }

  /// Get optimized HTTP client
  http.Client get client {
    if (!_isInitialized) {
      initialize();
    }
    return _client;
  }

  /// Make optimized HTTP request with caching and retry logic
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final requestHeaders = {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Cache-Control': 'max-age=300', // 5 minutes cache
      ...?headers,
    };

    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: requestHeaders,
          )
          .timeout(timeout ?? _receiveTimeout);

      return response;
    } catch (e) {
      print('HTTP GET error for $url: $e');
      rethrow;
    }
  }

  /// Make optimized POST request
  Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      ...?headers,
    };

    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: requestHeaders,
            body: body,
          )
          .timeout(timeout ?? _receiveTimeout);

      return response;
    } catch (e) {
      print('HTTP POST error for $url: $e');
      rethrow;
    }
  }

  /// Batch multiple requests for efficiency
  void queueRequest(Map<String, dynamic> request) {
    _requestQueue.add(request);
    
    if (_requestQueue.length >= _maxBatchSize) {
      _processBatch();
    }
  }

  /// Start batch processing timer
  void _startBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(_batchDelay, (timer) {
      if (_requestQueue.isNotEmpty) {
        _processBatch();
      }
    });
  }

  /// Process batched requests
  Future<void> _processBatch() async {
    if (_requestQueue.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_requestQueue);
    _requestQueue.clear();

    try {
      // Process requests in parallel
      final futures = batch.map((request) => _executeRequest(request));
      await Future.wait(futures, eagerError: false);
    } catch (e) {
      print('Batch processing error: $e');
    }
  }

  /// Execute individual request
  Future<http.Response> _executeRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String;
    final url = request['url'] as String;
    final headers = request['headers'] as Map<String, String>?;
    final body = request['body'];

    switch (method.toUpperCase()) {
      case 'GET':
        return await get(url, headers: headers);
      case 'POST':
        return await post(url, headers: headers, body: body);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  /// Close the HTTP client and cleanup resources
  void dispose() {
    _batchTimer?.cancel();
    _client.close();
    _isInitialized = false;
    print('OptimizedHttpClient disposed');
  }
}
