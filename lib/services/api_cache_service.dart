import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

/// Service for caching API responses to reduce repeated calls
class ApiCacheService {
  static final Logger _logger = Logger();
  static const String _cachePrefix = 'api_cache_';
  static const Duration _defaultCacheDuration = Duration(minutes: 20);
  static const Duration _criticalDataCacheDuration = Duration(minutes: 60);

  /// Cache a response with optional custom duration
  static Future<void> cacheResponse(
    String key,
    Map<String, dynamic> response, {
    Duration? duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': response,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiresAt': DateTime.now()
            .add(duration ?? _defaultCacheDuration)
            .millisecondsSinceEpoch,
      };
      
      await prefs.setString(
        '$_cachePrefix$key',
        jsonEncode(cacheData),
      );
      
      _logger.d('Cached response for key: $key');
    } catch (e) {
      _logger.e('Error caching response: $e');
    }
  }

  /// Get cached response if valid
  static Future<Map<String, dynamic>?> getCachedResponse(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('$_cachePrefix$key');
      
      if (cachedData == null) return null;
      
      final cacheData = jsonDecode(cachedData) as Map<String, dynamic>;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        cacheData['expiresAt'] as int,
      );
      
      if (DateTime.now().isAfter(expiresAt)) {
        // Cache expired, remove it
        await prefs.remove('$_cachePrefix$key');
        _logger.d('Cache expired for key: $key');
        return null;
      }
      
      _logger.d('Cache hit for key: $key');
      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Error getting cached response: $e');
      return null;
    }
  }

  /// Check if cache exists and is valid
  static Future<bool> isCacheValid(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('$_cachePrefix$key');
      
      if (cachedData == null) return false;
      
      final cacheData = jsonDecode(cachedData) as Map<String, dynamic>;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        cacheData['expiresAt'] as int,
      );
      
      return DateTime.now().isBefore(expiresAt);
    } catch (e) {
      _logger.e('Error checking cache validity: $e');
      return false;
    }
  }

  /// Clear specific cache entry
  static Future<void> clearCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$key');
      _logger.d('Cleared cache for key: $key');
    } catch (e) {
      _logger.e('Error clearing cache: $e');
    }
  }

  /// Clear all API cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }
      
      _logger.d('Cleared all API cache');
    } catch (e) {
      _logger.e('Error clearing all cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final cacheKeys = keys.where((key) => key.startsWith(_cachePrefix)).toList();
      
      int validEntries = 0;
      int expiredEntries = 0;
      
      for (final key in cacheKeys) {
        final cachedData = prefs.getString(key);
        if (cachedData != null) {
          try {
            final cacheData = jsonDecode(cachedData) as Map<String, dynamic>;
            final expiresAt = DateTime.fromMillisecondsSinceEpoch(
              cacheData['expiresAt'] as int,
            );
            
            if (DateTime.now().isBefore(expiresAt)) {
              validEntries++;
            } else {
              expiredEntries++;
            }
          } catch (e) {
            expiredEntries++;
          }
        }
      }
      
      return {
        'totalEntries': cacheKeys.length,
        'validEntries': validEntries,
        'expiredEntries': expiredEntries,
        'cacheSize': cacheKeys.length,
      };
    } catch (e) {
      _logger.e('Error getting cache stats: $e');
      return {
        'totalEntries': 0,
        'validEntries': 0,
        'expiredEntries': 0,
        'cacheSize': 0,
      };
    }
  }

  /// Clean up expired cache entries
  static Future<void> cleanupExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final cacheKeys = keys.where((key) => key.startsWith(_cachePrefix)).toList();
      
      int cleanedCount = 0;
      
      for (final key in cacheKeys) {
        final cachedData = prefs.getString(key);
        if (cachedData != null) {
          try {
            final cacheData = jsonDecode(cachedData) as Map<String, dynamic>;
            final expiresAt = DateTime.fromMillisecondsSinceEpoch(
              cacheData['expiresAt'] as int,
            );
            
            if (DateTime.now().isAfter(expiresAt)) {
              await prefs.remove(key);
              cleanedCount++;
            }
          } catch (e) {
            // Remove corrupted cache entries
            await prefs.remove(key);
            cleanedCount++;
          }
        }
      }
      
      _logger.d('Cleaned up $cleanedCount expired cache entries');
    } catch (e) {
      _logger.e('Error cleaning up expired cache: $e');
    }
  }
}
