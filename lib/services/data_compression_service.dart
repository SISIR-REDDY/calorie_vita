import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:gzip/gzip.dart';

/// Service for compressing and optimizing data for faster transmission
class DataCompressionService {
  static final DataCompressionService _instance = DataCompressionService._internal();
  factory DataCompressionService() => _instance;
  DataCompressionService._internal();

  /// Compress JSON data using gzip
  static Uint8List compressJson(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);
      return gzip.encode(bytes);
    } catch (e) {
      print('JSON compression error: $e');
      return Uint8List(0);
    }
  }

  /// Decompress JSON data from gzip
  static Map<String, dynamic>? decompressJson(Uint8List compressedData) {
    try {
      final decompressedBytes = gzip.decode(compressedData);
      final jsonString = utf8.decode(decompressedBytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('JSON decompression error: $e');
      return null;
    }
  }

  /// Compress string data
  static Uint8List compressString(String data) {
    try {
      final bytes = utf8.encode(data);
      return gzip.encode(bytes);
    } catch (e) {
      print('String compression error: $e');
      return Uint8List(0);
    }
  }

  /// Decompress string data
  static String? decompressString(Uint8List compressedData) {
    try {
      final decompressedBytes = gzip.decode(compressedData);
      return utf8.decode(decompressedBytes);
    } catch (e) {
      print('String decompression error: $e');
      return null;
    }
  }

  /// Optimize Firebase document data by removing unnecessary fields
  static Map<String, dynamic> optimizeFirebaseData(Map<String, dynamic> data) {
    final optimized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip null values
      if (value == null) continue;
      
      // Skip empty strings
      if (value is String && value.isEmpty) continue;
      
      // Skip empty lists
      if (value is List && value.isEmpty) continue;
      
      // Skip empty maps
      if (value is Map && value.isEmpty) continue;
      
      // Optimize numbers (remove unnecessary decimal places)
      if (value is double) {
        if (value == value.toInt().toDouble()) {
          optimized[key] = value.toInt();
        } else {
          optimized[key] = double.parse(value.toStringAsFixed(2));
        }
      } else {
        optimized[key] = value;
      }
    }
    
    return optimized;
  }

  /// Calculate compression ratio
  static double getCompressionRatio(Uint8List original, Uint8List compressed) {
    if (original.isEmpty) return 0.0;
    return (1.0 - compressed.length / original.length) * 100;
  }

  /// Check if data should be compressed based on size
  static bool shouldCompress(Uint8List data, {int threshold = 1024}) {
    return data.length > threshold;
  }

  /// Batch compress multiple data items
  static Map<String, Uint8List> batchCompress(Map<String, Map<String, dynamic>> dataMap) {
    final compressedMap = <String, Uint8List>{};
    
    for (final entry in dataMap.entries) {
      final key = entry.key;
      final data = entry.value;
      
      final compressed = compressJson(data);
      if (compressed.isNotEmpty) {
        compressedMap[key] = compressed;
      }
    }
    
    return compressedMap;
  }

  /// Batch decompress multiple data items
  static Map<String, Map<String, dynamic>?> batchDecompress(Map<String, Uint8List> compressedMap) {
    final decompressedMap = <String, Map<String, dynamic>?>{};
    
    for (final entry in compressedMap.entries) {
      final key = entry.key;
      final compressedData = entry.value;
      
      decompressedMap[key] = decompressJson(compressedData);
    }
    
    return decompressedMap;
  }
}
