/// Model for portion estimation results
class PortionEstimationResult {
  final double estimatedWeight; // in grams
  final double confidence; // 0.0 to 1.0
  final String method; // AR, Manual, Food type, etc.
  final String? notes;
  final String? error;

  PortionEstimationResult({
    required this.estimatedWeight,
    required this.confidence,
    required this.method,
    this.notes,
    this.error,
  });

  /// Check if the estimation was successful
  bool get isSuccessful => error == null && estimatedWeight > 0;

  /// Check if the confidence is high enough for reliable results
  bool get isHighConfidence => confidence >= 0.7;

  /// Check if the confidence is moderate
  bool get isModerateConfidence => confidence >= 0.4 && confidence < 0.7;

  /// Check if the confidence is low
  bool get isLowConfidence => confidence < 0.4;

  /// Get confidence as percentage
  int get confidencePercentage => (confidence * 100).round();

  /// Get weight in different units
  double get weightInKg => estimatedWeight / 1000.0;
  double get weightInOz => estimatedWeight * 0.035274;
  double get weightInLb => estimatedWeight * 0.002205;

  /// Get formatted weight string
  String get formattedWeight {
    if (estimatedWeight >= 1000) {
      return '${(estimatedWeight / 1000).toStringAsFixed(1)}kg';
    } else {
      return '${estimatedWeight.toStringAsFixed(0)}g';
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'estimatedWeight': estimatedWeight,
      'confidence': confidence,
      'method': method,
      'notes': notes,
      'error': error,
    };
  }

  /// Create from JSON
  factory PortionEstimationResult.fromJson(Map<String, dynamic> json) {
    return PortionEstimationResult(
      estimatedWeight: (json['estimatedWeight'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      method: json['method'] as String? ?? 'Unknown',
      notes: json['notes'] as String?,
      error: json['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'PortionEstimationResult(weight: $formattedWeight, confidence: $confidencePercentage%, method: $method)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PortionEstimationResult &&
        other.estimatedWeight == estimatedWeight &&
        other.confidence == confidence &&
        other.method == method &&
        other.notes == notes &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(estimatedWeight, confidence, method, notes, error);
  }
}
