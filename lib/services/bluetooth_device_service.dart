import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Bluetooth connections to fitness devices
class BluetoothDeviceService {
  static final BluetoothDeviceService _instance = BluetoothDeviceService._internal();
  factory BluetoothDeviceService() => _instance;
  BluetoothDeviceService._internal();

  // Stream controllers
  final StreamController<List<BluetoothDevice>> _connectedDevicesController = 
      StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<bool> _isScanningController = 
      StreamController<bool>.broadcast();
  final StreamController<String> _connectionStatusController = 
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _deviceDataController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // State
  List<BluetoothDevice> _connectedDevices = [];
  bool _isScanning = false;
  String _connectionStatus = 'Disconnected';
  Map<String, StreamSubscription> _deviceDataSubscriptions = {};
  Timer? _dataSyncTimer;

  // Getters
  Stream<List<BluetoothDevice>> get connectedDevicesStream => _connectedDevicesController.stream;
  Stream<bool> get isScanningStream => _isScanningController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get deviceDataStream => _deviceDataController.stream;
  List<BluetoothDevice> get connectedDevices => _connectedDevices;
  bool get isScanning => _isScanning;
  String get connectionStatus => _connectionStatus;

  /// Check and request Bluetooth permissions
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      // Check location permission for Bluetooth scanning
      final locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        final result = await Permission.locationWhenInUse.request();
        if (!result.isGranted) {
          return false;
        }
      }

      // Check Bluetooth permission
      final bluetoothStatus = await Permission.bluetoothScan.status;
      if (!bluetoothStatus.isGranted) {
        final result = await Permission.bluetoothScan.request();
        if (!result.isGranted) {
          return false;
        }
      }
    }
    return true;
  }

  /// Start scanning for fitness devices
  Future<void> startScanning() async {
    if (_isScanning) return;

    final hasPermissions = await _checkPermissions();
    if (!hasPermissions) {
      _updateConnectionStatus('Permissions required for Bluetooth scanning');
      return;
    }

    try {
      _isScanning = true;
      _isScanningController.add(true);
      _updateConnectionStatus('Scanning for devices...');

      // Start scanning with specific service UUIDs for fitness devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [
          Guid('0000180d-0000-1000-8000-00805f9b34fb'), // Heart Rate Service
          Guid('0000180f-0000-1000-8000-00805f9b34fb'), // Battery Service
          Guid('0000180a-0000-1000-8000-00805f9b34fb'), // Device Information Service
        ],
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          final deviceName = device.platformName.isNotEmpty 
              ? device.platformName 
              : device.remoteId.toString();

          // Filter for known fitness device brands
          if (isFitnessDevice(deviceName)) {
            _updateConnectionStatus('Found fitness device: $deviceName');
          }
        }
      });

      // Stop scanning after timeout
      Timer(const Duration(seconds: 10), () {
        stopScanning();
      });

    } catch (e) {
      _isScanning = false;
      _isScanningController.add(false);
      _updateConnectionStatus('Error scanning: $e');
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _isScanningController.add(false);
      _updateConnectionStatus('Scan stopped');
    } catch (e) {
      _updateConnectionStatus('Error stopping scan: $e');
    }
  }

  /// Check if device is a known fitness device
  bool isFitnessDevice(String deviceName) {
    final fitnessBrands = [
      'fitbit', 'apple watch', 'samsung galaxy watch', 'garmin', 'polar',
      'suunto', 'xiaomi', 'huawei', 'honor', 'amazfit', 'fossil',
      'skagen', 'misfit', 'jawbone', 'withings', 'nike', 'adidas'
    ];

    final lowerName = deviceName.toLowerCase();
    return fitnessBrands.any((brand) => lowerName.contains(brand));
  }

  /// Connect to a specific device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _updateConnectionStatus('Connecting to ${device.platformName}...');
      
      await device.connect(timeout: const Duration(seconds: 15));
      
      if (device.isConnected) {
        _connectedDevices.add(device);
        _connectedDevicesController.add(_connectedDevices);
        _updateConnectionStatus('Connected to ${device.platformName}');
        
        // Save connected device for persistence
        await _saveConnectedDevice(device);
        
        // Start real-time data streaming
        await _startDeviceDataStreaming(device);
        
        // Listen for disconnection
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            _disconnectDevice(device);
          }
        });
        
        return true;
      }
      return false;
    } catch (e) {
      _updateConnectionStatus('Failed to connect: $e');
      return false;
    }
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _disconnectDevice(device);
    } catch (e) {
      _updateConnectionStatus('Error disconnecting: $e');
    }
  }

  /// Remove device from connected list
  void _disconnectDevice(BluetoothDevice device) {
    _connectedDevices.remove(device);
    _connectedDevicesController.add(_connectedDevices);
    _updateConnectionStatus('Disconnected from ${device.platformName}');
    
    // Stop data streaming for this device
    _stopDeviceDataStreaming(device);
    
    // Remove from saved devices
    _removeConnectedDevice(device);
  }

  /// Start real-time data streaming from a connected device
  Future<void> _startDeviceDataStreaming(BluetoothDevice device) async {
    try {
      final deviceId = device.remoteId.toString();
      
      // Discover services
      final services = await device.discoverServices();
      
      // Look for fitness-related services
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase().contains('180D')) {
          // Heart Rate Service
          await _subscribeToHeartRateService(device, service);
        } else if (service.uuid.toString().toUpperCase().contains('180F')) {
          // Battery Service
          await _subscribeToBatteryService(device, service);
        } else if (service.uuid.toString().toUpperCase().contains('1810')) {
          // Blood Pressure Service
          await _subscribeToBloodPressureService(device, service);
        }
      }
      
      // Start periodic data sync
      _startPeriodicDataSync(device);
      
    } catch (e) {
      print('Error starting data streaming for ${device.platformName}: $e');
    }
  }

  /// Stop data streaming for a device
  void _stopDeviceDataStreaming(BluetoothDevice device) {
    final deviceId = device.remoteId.toString();
    _deviceDataSubscriptions[deviceId]?.cancel();
    _deviceDataSubscriptions.remove(deviceId);
  }

  /// Subscribe to Heart Rate Service
  Future<void> _subscribeToHeartRateService(BluetoothDevice device, BluetoothService service) async {
    try {
      final characteristics = service.characteristics;
      for (BluetoothCharacteristic characteristic in characteristics) {
        if (characteristic.uuid.toString().toUpperCase().contains('2A37')) {
          // Heart Rate Measurement Characteristic
          await characteristic.setNotifyValue(true);
          
          final deviceId = device.remoteId.toString();
          _deviceDataSubscriptions[deviceId] = characteristic.lastValueStream.listen((data) {
            if (data.isNotEmpty) {
              final heartRate = _parseHeartRateData(data);
              _emitDeviceData(device, 'heartRate', heartRate);
            }
          });
        }
      }
    } catch (e) {
      print('Error subscribing to heart rate service: $e');
    }
  }

  /// Subscribe to Battery Service
  Future<void> _subscribeToBatteryService(BluetoothDevice device, BluetoothService service) async {
    try {
      final characteristics = service.characteristics;
      for (BluetoothCharacteristic characteristic in characteristics) {
        if (characteristic.uuid.toString().toUpperCase().contains('2A19')) {
          // Battery Level Characteristic
          final data = await characteristic.read();
          if (data.isNotEmpty) {
            final batteryLevel = data[0];
            _emitDeviceData(device, 'batteryLevel', batteryLevel);
          }
        }
      }
    } catch (e) {
      print('Error reading battery level: $e');
    }
  }

  /// Subscribe to Blood Pressure Service
  Future<void> _subscribeToBloodPressureService(BluetoothDevice device, BluetoothService service) async {
    try {
      final characteristics = service.characteristics;
      for (BluetoothCharacteristic characteristic in characteristics) {
        if (characteristic.uuid.toString().toUpperCase().contains('2A35')) {
          // Blood Pressure Measurement Characteristic
          await characteristic.setNotifyValue(true);
          
          final deviceId = device.remoteId.toString();
          _deviceDataSubscriptions[deviceId] = characteristic.lastValueStream.listen((data) {
            if (data.isNotEmpty) {
              final bloodPressure = _parseBloodPressureData(data);
              _emitDeviceData(device, 'bloodPressure', bloodPressure);
            }
          });
        }
      }
    } catch (e) {
      print('Error subscribing to blood pressure service: $e');
    }
  }

  /// Parse heart rate data from BLE characteristic
  int _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return 0;
    
    // Heart Rate Measurement format: Flags (1 byte) + Heart Rate Value (1-2 bytes)
    int heartRate = data[1]; // Basic format, first byte after flags
    
    if (data.length > 2 && (data[0] & 0x01) != 0) {
      // 16-bit heart rate value
      heartRate = data[1] | (data[2] << 8);
    }
    
    return heartRate;
  }

  /// Parse blood pressure data from BLE characteristic
  Map<String, int> _parseBloodPressureData(List<int> data) {
    if (data.length < 7) return {'systolic': 0, 'diastolic': 0};
    
    // Blood Pressure Measurement format
    final systolic = data[1] | (data[2] << 8);
    final diastolic = data[3] | (data[4] << 8);
    
    return {
      'systolic': systolic,
      'diastolic': diastolic,
    };
  }

  /// Emit device data to stream
  void _emitDeviceData(BluetoothDevice device, String dataType, dynamic value) {
    final deviceData = {
      'deviceId': device.remoteId.toString(),
      'deviceName': device.platformName,
      'dataType': dataType,
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    _deviceDataController.add(deviceData);
  }

  /// Start periodic data synchronization
  void _startPeriodicDataSync(BluetoothDevice device) {
    _dataSyncTimer?.cancel();
    _dataSyncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncDeviceData(device);
    });
  }

  /// Sync device data periodically
  Future<void> _syncDeviceData(BluetoothDevice device) async {
    if (!device.isConnected) return;
    
    try {
      // Simulate step count and other fitness data
      final steps = _generateSimulatedSteps();
      final calories = _generateSimulatedCalories();
      final distance = _generateSimulatedDistance();
      
      _emitDeviceData(device, 'steps', steps);
      _emitDeviceData(device, 'calories', calories);
      _emitDeviceData(device, 'distance', distance);
      
    } catch (e) {
      print('Error syncing device data: $e');
    }
  }

  /// Generate simulated step count (in real app, this would come from device)
  int _generateSimulatedSteps() {
    return 1000 + (DateTime.now().millisecond % 5000);
  }

  /// Generate simulated calories burned
  int _generateSimulatedCalories() {
    return 200 + (DateTime.now().millisecond % 300);
  }

  /// Generate simulated distance
  double _generateSimulatedDistance() {
    return 1.5 + (DateTime.now().millisecond % 1000) / 1000.0;
  }

  /// Save connected device for persistence
  Future<void> _saveConnectedDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceData = {
        'id': device.remoteId.toString(),
        'name': device.platformName,
        'connectedAt': DateTime.now().millisecondsSinceEpoch,
      };
      
      final savedDevices = prefs.getStringList('connected_devices') ?? [];
      savedDevices.add(jsonEncode(deviceData));
      await prefs.setStringList('connected_devices', savedDevices);
    } catch (e) {
      print('Error saving connected device: $e');
    }
  }

  /// Remove connected device from persistence
  Future<void> _removeConnectedDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevices = prefs.getStringList('connected_devices') ?? [];
      final deviceId = device.remoteId.toString();
      
      savedDevices.removeWhere((deviceJson) {
        final deviceData = jsonDecode(deviceJson);
        return deviceData['id'] == deviceId;
      });
      
      await prefs.setStringList('connected_devices', savedDevices);
    } catch (e) {
      print('Error removing connected device: $e');
    }
  }

  /// Restore previously connected devices on app start
  Future<void> restoreConnectedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevices = prefs.getStringList('connected_devices') ?? [];
      
      for (String deviceJson in savedDevices) {
        final deviceData = jsonDecode(deviceJson);
        final deviceId = deviceData['id'];
        
        // Try to reconnect to saved devices
        final devices = await FlutterBluePlus.connectedDevices;
        final device = devices.firstWhere(
          (d) => d.remoteId.toString() == deviceId,
          orElse: () => throw StateError('Device not found'),
        );
        
        if (device.isConnected) {
          _connectedDevices.add(device);
          await _startDeviceDataStreaming(device);
        }
      }
      
      if (_connectedDevices.isNotEmpty) {
        _connectedDevicesController.add(_connectedDevices);
        _updateConnectionStatus('Restored ${_connectedDevices.length} connected devices');
      }
    } catch (e) {
      print('Error restoring connected devices: $e');
    }
  }

  /// Get device icon based on device name
  IconData getDeviceIcon(String deviceName) {
    final lowerName = deviceName.toLowerCase();
    
    if (lowerName.contains('fitbit')) {
      return Icons.fitness_center;
    } else if (lowerName.contains('apple') || lowerName.contains('watch')) {
      return Icons.watch;
    } else if (lowerName.contains('samsung') || lowerName.contains('galaxy')) {
      return Icons.watch;
    } else if (lowerName.contains('garmin')) {
      return Icons.sports;
    } else if (lowerName.contains('xiaomi') || lowerName.contains('mi band')) {
      return Icons.fitness_center;
    } else if (lowerName.contains('huawei') || lowerName.contains('honor')) {
      return Icons.watch;
    } else {
      return Icons.devices_other;
    }
  }

  /// Get device logo/color based on brand
  Color getDeviceColor(String deviceName) {
    final lowerName = deviceName.toLowerCase();
    
    if (lowerName.contains('fitbit')) {
      return const Color(0xFF00B0B9); // Fitbit blue
    } else if (lowerName.contains('apple')) {
      return const Color(0xFF007AFF); // Apple blue
    } else if (lowerName.contains('samsung')) {
      return const Color(0xFF1428A0); // Samsung blue
    } else if (lowerName.contains('garmin')) {
      return const Color(0xFF007CC3); // Garmin blue
    } else if (lowerName.contains('xiaomi')) {
      return const Color(0xFFFF6900); // Xiaomi orange
    } else if (lowerName.contains('huawei')) {
      return const Color(0xFFFF0000); // Huawei red
    } else {
      return const Color(0xFF6366F1); // Default purple
    }
  }

  /// Update connection status
  void _updateConnectionStatus(String status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }

  /// Dispose resources
  void dispose() {
    _dataSyncTimer?.cancel();
    _deviceDataSubscriptions.values.forEach((subscription) => subscription.cancel());
    _deviceDataSubscriptions.clear();
    
    _connectedDevicesController.close();
    _isScanningController.close();
    _connectionStatusController.close();
    _deviceDataController.close();
  }
}
