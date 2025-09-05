import 'package:cloud_firestore/cloud_firestore.dart';

/// Health data model for tracking fitness metrics
class HealthData {
  final DateTime date;
  final int steps;
  final double caloriesBurned;
  final double distance; // in kilometers
  final int activeMinutes;
  final double heartRate; // average BPM
  final double sleepHours;
  final double waterIntake; // in glasses
  final double weight; // in kg
  final String source; // Google Fit, Apple HealthKit, Bluetooth Device
  final DateTime lastUpdated;

  const HealthData({
    required this.date,
    required this.steps,
    required this.caloriesBurned,
    required this.distance,
    required this.activeMinutes,
    required this.heartRate,
    required this.sleepHours,
    required this.waterIntake,
    required this.weight,
    required this.source,
    required this.lastUpdated,
  });

  /// Create empty health data
  factory HealthData.empty() {
    final now = DateTime.now();
    return HealthData(
      date: DateTime(now.year, now.month, now.day),
      steps: 0,
      caloriesBurned: 0.0,
      distance: 0.0,
      activeMinutes: 0,
      heartRate: 0.0,
      sleepHours: 0.0,
      waterIntake: 0.0,
      weight: 0.0,
      source: 'Manual',
      lastUpdated: now,
    );
  }

  /// Create from Firestore document
  factory HealthData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthData(
      date: (data['date'] as Timestamp).toDate(),
      steps: data['steps'] ?? 0,
      caloriesBurned: (data['caloriesBurned'] ?? 0.0).toDouble(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      activeMinutes: data['activeMinutes'] ?? 0,
      heartRate: (data['heartRate'] ?? 0.0).toDouble(),
      sleepHours: (data['sleepHours'] ?? 0.0).toDouble(),
      waterIntake: (data['waterIntake'] ?? 0.0).toDouble(),
      weight: (data['weight'] ?? 0.0).toDouble(),
      source: data['source'] ?? 'Manual',
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  /// Create from map
  factory HealthData.fromMap(Map<String, dynamic> map) {
    return HealthData(
      date: (map['date'] as Timestamp).toDate(),
      steps: map['steps'] ?? 0,
      caloriesBurned: (map['caloriesBurned'] ?? 0.0).toDouble(),
      distance: (map['distance'] ?? 0.0).toDouble(),
      activeMinutes: map['activeMinutes'] ?? 0,
      heartRate: (map['heartRate'] ?? 0.0).toDouble(),
      sleepHours: (map['sleepHours'] ?? 0.0).toDouble(),
      waterIntake: (map['waterIntake'] ?? 0.0).toDouble(),
      weight: (map['weight'] ?? 0.0).toDouble(),
      source: map['source'] ?? 'Manual',
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'distance': distance,
      'activeMinutes': activeMinutes,
      'heartRate': heartRate,
      'sleepHours': sleepHours,
      'waterIntake': waterIntake,
      'weight': weight,
      'source': source,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch,
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'distance': distance,
      'activeMinutes': activeMinutes,
      'heartRate': heartRate,
      'sleepHours': sleepHours,
      'waterIntake': waterIntake,
      'weight': weight,
      'source': source,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory HealthData.fromJson(Map<String, dynamic> json) {
    return HealthData(
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      steps: json['steps'] ?? 0,
      caloriesBurned: (json['caloriesBurned'] ?? 0.0).toDouble(),
      distance: (json['distance'] ?? 0.0).toDouble(),
      activeMinutes: json['activeMinutes'] ?? 0,
      heartRate: (json['heartRate'] ?? 0.0).toDouble(),
      sleepHours: (json['sleepHours'] ?? 0.0).toDouble(),
      waterIntake: (json['waterIntake'] ?? 0.0).toDouble(),
      weight: (json['weight'] ?? 0.0).toDouble(),
      source: json['source'] ?? 'Manual',
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['lastUpdated']),
    );
  }

  /// Copy with new values
  HealthData copyWith({
    DateTime? date,
    int? steps,
    double? caloriesBurned,
    double? distance,
    int? activeMinutes,
    double? heartRate,
    double? sleepHours,
    double? waterIntake,
    double? weight,
    String? source,
    DateTime? lastUpdated,
  }) {
    return HealthData(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distance: distance ?? this.distance,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      heartRate: heartRate ?? this.heartRate,
      sleepHours: sleepHours ?? this.sleepHours,
      waterIntake: waterIntake ?? this.waterIntake,
      weight: weight ?? this.weight,
      source: source ?? this.source,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if health data is empty
  bool get isEmpty {
    return steps == 0 && 
           caloriesBurned == 0.0 && 
           distance == 0.0 && 
           activeMinutes == 0 && 
           heartRate == 0.0 && 
           sleepHours == 0.0 && 
           waterIntake == 0.0 &&
           weight == 0.0;
  }

  /// Check if health data has meaningful values
  bool get hasData {
    return steps > 0 || 
           caloriesBurned > 0.0 || 
           distance > 0.0 || 
           activeMinutes > 0 || 
           heartRate > 0.0 || 
           sleepHours > 0.0 || 
           waterIntake > 0.0 ||
           weight > 0.0;
  }

  @override
  String toString() {
    return 'HealthData(date: $date, steps: $steps, caloriesBurned: $caloriesBurned, distance: $distance, activeMinutes: $activeMinutes, heartRate: $heartRate, sleepHours: $sleepHours, waterIntake: $waterIntake, weight: $weight, source: $source, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HealthData &&
        other.date == date &&
        other.steps == steps &&
        other.caloriesBurned == caloriesBurned &&
        other.distance == distance &&
        other.activeMinutes == activeMinutes &&
        other.heartRate == heartRate &&
        other.sleepHours == sleepHours &&
        other.waterIntake == waterIntake &&
        other.weight == weight &&
        other.source == source &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode {
    return date.hashCode ^
        steps.hashCode ^
        caloriesBurned.hashCode ^
        distance.hashCode ^
        activeMinutes.hashCode ^
        heartRate.hashCode ^
        sleepHours.hashCode ^
        waterIntake.hashCode ^
        weight.hashCode ^
        source.hashCode ^
        lastUpdated.hashCode;
  }
}

/// Fitness device model
class FitnessDevice {
  final String id;
  final String name;
  final String platform;
  final bool isConnected;
  final DateTime lastSync;
  final List<String> capabilities;

  const FitnessDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.isConnected,
    required this.lastSync,
    required this.capabilities,
  });

  /// Create from map
  factory FitnessDevice.fromMap(Map<String, dynamic> map) {
    return FitnessDevice(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      platform: map['platform'] ?? '',
      isConnected: map['isConnected'] ?? false,
      lastSync: (map['lastSync'] as Timestamp).toDate(),
      capabilities: (map['capabilities'] as List?)?.cast<String>() ?? [],
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'isConnected': isConnected,
      'lastSync': Timestamp.fromDate(lastSync),
      'capabilities': capabilities,
    };
  }

  /// Copy with new values
  FitnessDevice copyWith({
    String? id,
    String? name,
    String? platform,
    bool? isConnected,
    DateTime? lastSync,
    List<String>? capabilities,
  }) {
    return FitnessDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      isConnected: isConnected ?? this.isConnected,
      lastSync: lastSync ?? this.lastSync,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  @override
  String toString() {
    return 'FitnessDevice(id: $id, name: $name, platform: $platform, isConnected: $isConnected, lastSync: $lastSync, capabilities: $capabilities)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FitnessDevice &&
        other.id == id &&
        other.name == name &&
        other.platform == platform &&
        other.isConnected == isConnected &&
        other.lastSync == lastSync &&
        other.capabilities.toString() == capabilities.toString();
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        platform.hashCode ^
        isConnected.hashCode ^
        lastSync.hashCode ^
        capabilities.hashCode;
  }
}

/// Fitness platform model
class FitnessPlatform {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isAvailable;

  const FitnessPlatform({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isAvailable,
  });

  /// Create from map
  factory FitnessPlatform.fromMap(Map<String, dynamic> map) {
    return FitnessPlatform(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '',
      isAvailable: map['isAvailable'] ?? false,
    );
  }

  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'isAvailable': isAvailable,
    };
  }

  @override
  String toString() {
    return 'FitnessPlatform(id: $id, name: $name, description: $description, icon: $icon, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FitnessPlatform &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.icon == icon &&
        other.isAvailable == isAvailable;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        icon.hashCode ^
        isAvailable.hashCode;
  }
}
