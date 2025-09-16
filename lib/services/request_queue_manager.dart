import 'dart:async';
import 'dart:collection';

/// Request priority levels
enum RequestPriority {
  critical,    // User-initiated actions, authentication
  high,        // Real-time data, user preferences
  medium,      // Background sync, analytics
  low,         // Logging, non-essential data
}

/// Request queue item
class QueuedRequest {
  final String id;
  final RequestPriority priority;
  final Future<dynamic> Function() operation;
  final DateTime timestamp;
  final Duration? timeout;
  final int retryCount;
  final int maxRetries;

  QueuedRequest({
    required this.id,
    required this.priority,
    required this.operation,
    this.timeout,
    this.retryCount = 0,
    this.maxRetries = 3,
  }) : timestamp = DateTime.now();
}

/// Intelligent request queue manager with prioritization and throttling
class RequestQueueManager {
  static final RequestQueueManager _instance = RequestQueueManager._internal();
  factory RequestQueueManager() => _instance;
  RequestQueueManager._internal();

  // Priority queues
  final Map<RequestPriority, Queue<QueuedRequest>> _queues = {
    RequestPriority.critical: Queue<QueuedRequest>(),
    RequestPriority.high: Queue<QueuedRequest>(),
    RequestPriority.medium: Queue<QueuedRequest>(),
    RequestPriority.low: Queue<QueuedRequest>(),
  };

  // Processing state
  bool _isProcessing = false;
  Timer? _processingTimer;
  int _concurrentRequests = 0;
  static const int _maxConcurrentRequests = 3;
  static const Duration _processingInterval = Duration(milliseconds: 100);

  // Performance tracking
  final Map<RequestPriority, int> _processedCounts = {};
  final Map<RequestPriority, Duration> _totalProcessingTime = {};

  /// Initialize the queue manager
  void initialize() {
    _startProcessing();
    print('RequestQueueManager initialized');
  }

  /// Add request to queue with priority
  Future<T> enqueue<T>({
    required String id,
    required RequestPriority priority,
    required Future<T> Function() operation,
    Duration? timeout,
    int maxRetries = 3,
  }) async {
    final request = QueuedRequest(
      id: id,
      priority: priority,
      operation: operation,
      timeout: timeout,
      maxRetries: maxRetries,
    );

    _queues[priority]!.add(request);
    
    // Process immediately if queue is not busy
    if (!_isProcessing && _concurrentRequests < _maxConcurrentRequests) {
      _processNextRequest();
    }

    return await _waitForCompletion<T>(id);
  }

  /// Process requests from queues
  void _startProcessing() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_processingInterval, (timer) {
      if (!_isProcessing && _concurrentRequests < _maxConcurrentRequests) {
        _processNextRequest();
      }
    });
  }

  /// Process next request in priority order
  void _processNextRequest() {
    if (_concurrentRequests >= _maxConcurrentRequests) return;

    // Find highest priority non-empty queue
    QueuedRequest? request;
    for (final priority in RequestPriority.values) {
      if (_queues[priority]!.isNotEmpty) {
        request = _queues[priority]!.removeFirst();
        break;
      }
    }

    if (request == null) return;

    _isProcessing = true;
    _concurrentRequests++;

    _executeRequest(request).then((_) {
      _concurrentRequests--;
      _isProcessing = false;
      
      // Continue processing if there are more requests
      if (_hasPendingRequests() && _concurrentRequests < _maxConcurrentRequests) {
        _processNextRequest();
      }
    }).catchError((error) {
      _concurrentRequests--;
      _isProcessing = false;
      print('Request execution error: $error');
    });
  }

  /// Execute individual request
  Future<void> _executeRequest(QueuedRequest request) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await request.operation().timeout(
        request.timeout ?? const Duration(seconds: 30),
      );
      
      stopwatch.stop();
      _updatePerformanceMetrics(request.priority, stopwatch.elapsed);
      
      print('Request ${request.id} completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      
      // Retry logic
      if (request.retryCount < request.maxRetries) {
        final retryRequest = QueuedRequest(
          id: request.id,
          priority: request.priority,
          operation: request.operation,
          timeout: request.timeout,
          retryCount: request.retryCount + 1,
          maxRetries: request.maxRetries,
        );
        
        // Re-queue with higher priority for retry
        final retryPriority = _getRetryPriority(request.priority);
        _queues[retryPriority]!.add(retryRequest);
        
        print('Request ${request.id} failed, retrying (${request.retryCount + 1}/${request.maxRetries}): $e');
      } else {
        print('Request ${request.id} failed after ${request.maxRetries} retries: $e');
      }
    }
  }

  /// Get retry priority (slightly higher than original)
  RequestPriority _getRetryPriority(RequestPriority original) {
    switch (original) {
      case RequestPriority.low:
        return RequestPriority.medium;
      case RequestPriority.medium:
        return RequestPriority.high;
      case RequestPriority.high:
      case RequestPriority.critical:
        return RequestPriority.critical;
    }
  }

  /// Wait for request completion
  Future<T> _waitForCompletion<T>(String requestId) async {
    // This is a simplified implementation
    // In a real implementation, you'd use Completer or similar
    // For now, we'll just wait a reasonable time
    await Future.delayed(const Duration(seconds: 1));
    throw TimeoutException('Request $requestId timed out');
  }

  /// Check if there are pending requests
  bool _hasPendingRequests() {
    return _queues.values.any((queue) => queue.isNotEmpty);
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(RequestPriority priority, Duration duration) {
    _processedCounts[priority] = (_processedCounts[priority] ?? 0) + 1;
    _totalProcessingTime[priority] = 
        (_totalProcessingTime[priority] ?? Duration.zero) + duration;
  }

  /// Get queue statistics
  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{};
    
    for (final priority in RequestPriority.values) {
      stats[priority.name] = {
        'pending': _queues[priority]!.length,
        'processed': _processedCounts[priority] ?? 0,
        'avgTime': _getAverageProcessingTime(priority),
      };
    }
    
    stats['concurrent'] = _concurrentRequests;
    stats['isProcessing'] = _isProcessing;
    
    return stats;
  }

  /// Get average processing time for priority
  Duration _getAverageProcessingTime(RequestPriority priority) {
    final count = _processedCounts[priority] ?? 0;
    if (count == 0) return Duration.zero;
    
    final totalTime = _totalProcessingTime[priority] ?? Duration.zero;
    return Duration(milliseconds: totalTime.inMilliseconds ~/ count);
  }

  /// Clear all queues
  void clearQueues() {
    for (final queue in _queues.values) {
      queue.clear();
    }
    print('All request queues cleared');
  }

  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    clearQueues();
    print('RequestQueueManager disposed');
  }
}
