import 'dart:convert';
import 'dart:isolate';
import 'package:logger/logger.dart';

/// Service for optimized JSON parsing using isolates for large responses
class JsonParsingService {
  static final Logger _logger = Logger();

  /// Parse large JSON response in isolate to prevent UI blocking
  static Future<Map<String, dynamic>> parseLargeJsonInIsolate(
      String jsonString) async {
    try {
      // If JSON is small (< 10KB), parse directly
      if (jsonString.length < 10000) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }

      // For large JSON, use isolate
      return await _parseInIsolate(jsonString);
    } catch (e) {
      _logger.e('Error parsing JSON: $e');
      rethrow;
    }
  }

  /// Parse JSON in isolate
  static Future<Map<String, dynamic>> _parseInIsolate(String jsonString) async {
    final receivePort = ReceivePort();
    
    try {
      await Isolate.spawn(
        _jsonParseIsolate,
        _JsonParseData(jsonString, receivePort.sendPort),
      );

      final result = await receivePort.first as Map<String, dynamic>;
      return result;
    } catch (e) {
      _logger.e('Isolate parsing failed: $e');
      // Fallback to direct parsing
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } finally {
      receivePort.close();
    }
  }

  /// Isolate entry point for JSON parsing
  static void _jsonParseIsolate(_JsonParseData data) {
    try {
      final result = jsonDecode(data.jsonString) as Map<String, dynamic>;
      data.sendPort.send(result);
    } catch (e) {
      data.sendPort.send({'error': e.toString()});
    }
  }

  /// Parse food analysis response with optimized parsing
  static Map<String, dynamic> parseFoodAnalysisResponse(String content) {
    try {
      // Clean the response
      String cleanedContent = content.trim();
      cleanedContent =
          cleanedContent.replaceAll('```json', '').replaceAll('```', '');

      // Find JSON object with better regex
      final jsonMatch =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanedContent);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!.trim();
        
        // Use isolate for large responses
        if (jsonStr.length > 5000) {
          return _parseLargeFoodResponse(jsonStr);
        } else {
          return _parseSmallFoodResponse(jsonStr);
        }
      }
    } catch (e) {
      _logger.e('Error parsing food analysis JSON: $e');
    }

    // Enhanced fallback with better text extraction
    return _extractFoodInfoFromText(content);
  }

  /// Parse small food response directly
  static Map<String, dynamic> _parseSmallFoodResponse(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    return _validateFoodResponse(parsed);
  }

  /// Parse large food response in isolate
  static Map<String, dynamic> _parseLargeFoodResponse(String jsonStr) {
    try {
      final receivePort = ReceivePort();
      
      Isolate.spawn(
        _foodParseIsolate,
        _FoodParseData(jsonStr, receivePort.sendPort),
      );

      final result = receivePort.first.then((data) {
        receivePort.close();
        return data as Map<String, dynamic>;
      });

      return result as Map<String, dynamic>;
    } catch (e) {
      _logger.e('Large food parsing failed: $e');
      return _parseSmallFoodResponse(jsonStr);
    }
  }

  /// Isolate entry point for food parsing
  static void _foodParseIsolate(_FoodParseData data) {
    try {
      final parsed = jsonDecode(data.jsonStr) as Map<String, dynamic>;
      final result = _validateFoodResponse(parsed);
      data.sendPort.send(result);
    } catch (e) {
      data.sendPort.send({'error': e.toString()});
    }
  }

  /// Validate and clean food response
  static Map<String, dynamic> _validateFoodResponse(Map<String, dynamic> parsed) {
    final calories = parseNumber(parsed['calories']);
    final confidence = parseNumber(parsed['confidence']) ?? 0.5;

    // Validate confidence
    final validatedConfidence = confidence.clamp(0.0, 1.0);

    return {
      'food': (parsed['food'] ?? 'Unknown Food').toString().trim(),
      'calories': calories ?? 0,
      'protein': formatMacro(parsed['protein']),
      'carbs': formatMacro(parsed['carbs']),
      'fat': formatMacro(parsed['fat']),
      'serving_size':
          (parsed['serving_size'] ?? '1 serving').toString().trim(),
      'confidence': validatedConfidence,
      'notes': parsed['notes']?.toString(),
      'breakdown': parsed['breakdown'],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Parse number from dynamic value
  static double? parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleanValue = value.replaceAll(RegExp(r'[^\d\.]'), '');
      return double.tryParse(cleanValue);
    }
    return null;
  }

  /// Format macro value properly
  static String formatMacro(dynamic value) {
    if (value == null) return '0g';
    if (value is String) {
      final cleanValue = value.toString().trim();
      if (cleanValue.isEmpty) return '0g';
      if (cleanValue.contains('g')) return cleanValue;
      return '${cleanValue}g';
    }
    if (value is num) {
      return '${value.toStringAsFixed(1)}g';
    }
    return '0g';
  }

  /// Extract food info from text when JSON parsing fails (enhanced)
  static Map<String, dynamic> _extractFoodInfoFromText(String text) {
    final result = {
      'food': 'Food detected',
      'calories': 0,
      'protein': '0g',
      'carbs': '0g',
      'fat': '0g',
      'serving_size': '1 serving',
      'confidence': 0.4,
      'note':
          'AI analysis completed but format was unclear. Manual verification recommended.',
    };

    // Enhanced calorie extraction
    final caloriePatterns = [
      RegExp(r'(\d+)\s*calories?', caseSensitive: false),
      RegExp(r'calorie[:\s]*(\d+)', caseSensitive: false),
      RegExp(r'kcal[:\s]*(\d+)', caseSensitive: false),
    ];

    for (final pattern in caloriePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['calories'] = int.tryParse(match.group(1)!) ?? 0;
        break;
      }
    }

    // Enhanced food name extraction
    final foodPatterns = [
      RegExp(r'(?:food|item|dish|meal)[:\s]*([^.]+)', caseSensitive: false),
      RegExp(r'"food":\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'food[:\s]*([a-zA-Z\s]+)', caseSensitive: false),
    ];

    for (final pattern in foodPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['food'] = match.group(1)!.trim();
        break;
      }
    }

    // Extract macros
    final proteinMatch =
        RegExp(r'protein[:\s]*([0-9.]+g?)', caseSensitive: false)
            .firstMatch(text);
    if (proteinMatch != null) {
      result['protein'] = proteinMatch.group(1)!;
    }

    final carbsMatch = RegExp(r'(?:carbs|carbohydrates)[:\s]*([0-9.]+g?)',
            caseSensitive: false)
        .firstMatch(text);
    if (carbsMatch != null) {
      result['carbs'] = carbsMatch.group(1)!;
    }

    final fatMatch =
        RegExp(r'fat[:\s]*([0-9.]+g?)', caseSensitive: false).firstMatch(text);
    if (fatMatch != null) {
      result['fat'] = fatMatch.group(1)!;
    }

    // Extract serving size
    final servingMatch =
        RegExp(r'(?:serving|portion)[:\s]*([^.]+)', caseSensitive: false)
            .firstMatch(text);
    if (servingMatch != null) {
      result['serving_size'] = servingMatch.group(1)!.trim();
    }

    return result;
  }
}

/// Data class for JSON parsing isolate
class _JsonParseData {
  final String jsonString;
  final SendPort sendPort;

  _JsonParseData(this.jsonString, this.sendPort);
}

/// Data class for food parsing isolate
class _FoodParseData {
  final String jsonStr;
  final SendPort sendPort;

  _FoodParseData(this.jsonStr, this.sendPort);
}
