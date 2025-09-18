/// Model for food recognition results
class FoodRecognitionResult {
  final String foodName;
  final double confidence;
  final String category;
  final String cuisine;
  final Map<String, double>? boundingBox;
  final String? error;

  FoodRecognitionResult({
    required this.foodName,
    required this.confidence,
    required this.category,
    required this.cuisine,
    this.boundingBox,
    this.error,
  });

  /// Check if the recognition was successful
  bool get isSuccessful => error == null && confidence > 0.0;

  /// Check if the confidence is high enough for reliable results
  bool get isHighConfidence => confidence >= 0.7;

  /// Check if the confidence is moderate
  bool get isModerateConfidence => confidence >= 0.4 && confidence < 0.7;

  /// Check if the confidence is low
  bool get isLowConfidence => confidence < 0.4;

  /// Get confidence as percentage
  int get confidencePercentage => (confidence * 100).round();

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'foodName': foodName,
      'confidence': confidence,
      'category': category,
      'cuisine': cuisine,
      'boundingBox': boundingBox,
      'error': error,
    };
  }

  /// Create from JSON
  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionResult(
      foodName: json['foodName'] as String? ?? 'Unknown Food',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'Unknown',
      cuisine: json['cuisine'] as String? ?? 'Unknown',
      boundingBox: json['boundingBox'] != null 
          ? Map<String, double>.from(json['boundingBox'])
          : null,
      error: json['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'FoodRecognitionResult(foodName: $foodName, confidence: $confidence, category: $category, cuisine: $cuisine, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodRecognitionResult &&
        other.foodName == foodName &&
        other.confidence == confidence &&
        other.category == category &&
        other.cuisine == cuisine &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(foodName, confidence, category, cuisine, error);
  }
}
