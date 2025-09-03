import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';
import '../services/error_handling_service.dart';

/// Health integration widget for settings screen
class HealthIntegrationWidget extends StatefulWidget {
  const HealthIntegrationWidget({super.key});

  @override
  State<HealthIntegrationWidget> createState() => _HealthIntegrationWidgetState();
}

class _HealthIntegrationWidgetState extends State<HealthIntegrationWidget> {
  final HealthService _healthService = HealthService();
  final ErrorHandlingService _errorHandlingService = ErrorHandlingService();
  
  bool _isConnected = false;
  List<FitnessDevice> _connectedDevices = [];
  HealthData _healthData = HealthData.empty();
  List<FitnessPlatform> _availablePlatforms = [];

  @override
  void initState() {
    super.initState();
    _setupStreamListeners();
    _loadData();
  }

  void _setupStreamListeners() {
    _healthService.isConnectedStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });

    _healthService.connectedDevicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _connectedDevices = devices;
        });
      }
    });

    _healthService.healthDataStream.listen((healthData) {
      if (mounted) {
        setState(() {
          _healthData = healthData;
        });
      }
    });
  }

  void _loadData() {
    _isConnected = _healthService.isConnected;
    _connectedDevices = _healthService.connectedDevices;
    _healthData = _healthService.currentHealthData;
    _availablePlatforms = _healthService.getAvailablePlatforms();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Health & Fitness Integration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Connection Status
            _buildConnectionStatus(),
            const SizedBox(height: 16),
            
            // Connected Devices
            if (_connectedDevices.isNotEmpty) ...[
              _buildConnectedDevices(),
              const SizedBox(height: 16),
            ],
            
            // Health Data Summary
            if (_healthData.hasData) ...[
              _buildHealthDataSummary(),
              const SizedBox(height: 16),
            ],
            
            // Available Platforms
            _buildAvailablePlatforms(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isConnected ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.warning,
            color: _isConnected ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isConnected 
                  ? 'Connected to ${_connectedDevices.length} fitness platform${_connectedDevices.length > 1 ? 's' : ''}'
                  : 'No fitness platforms connected',
              style: TextStyle(
                color: _isConnected ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected Devices',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._connectedDevices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  Widget _buildDeviceCard(FitnessDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            _getDeviceIcon(device.platform),
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        title: Text(device.name),
        subtitle: Text(
          'Last sync: ${_formatDateTime(device.lastSync)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _disconnectDevice(device.platform),
        ),
        isThreeLine: false,
      ),
    );
  }

  Widget _buildHealthDataSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Health Data',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildHealthMetric(
                'Steps',
                '${_healthData.steps}',
                Icons.directions_walk,
                Colors.blue,
              ),
            ),
            Expanded(
              child: _buildHealthMetric(
                'Calories Burned',
                '${_healthData.caloriesBurned}',
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildHealthMetric(
                'Distance',
                '${_healthData.distance.toStringAsFixed(1)} km',
                Icons.straighten,
                Colors.green,
              ),
            ),
            Expanded(
              child: _buildHealthMetric(
                'Active Minutes',
                '${_healthData.activeMinutes}',
                Icons.timer,
                Colors.purple,
              ),
            ),
          ],
        ),
        if (_healthData.heartRate > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHealthMetric(
                  'Heart Rate',
                  '${_healthData.heartRate.toStringAsFixed(0)} BPM',
                  Icons.favorite,
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildHealthMetric(
                  'Sleep',
                  '${_healthData.sleepHours.toStringAsFixed(1)} hrs',
                  Icons.bedtime,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHealthMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePlatforms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect to Fitness Platforms',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._availablePlatforms.map((platform) => _buildPlatformCard(platform)),
      ],
    );
  }

  Widget _buildPlatformCard(FitnessPlatform platform) {
    final isConnected = _connectedDevices.any((device) => device.platform == platform.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected 
              ? Colors.green.withOpacity(0.1)
              : Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            _getPlatformIcon(platform.id),
            color: isConnected ? Colors.green : Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        title: Text(platform.name),
        subtitle: Text(platform.description),
        trailing: isConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: () => _connectToPlatform(platform.id),
                child: const Text('Connect'),
              ),
        isThreeLine: false,
      ),
    );
  }

  IconData _getDeviceIcon(String platform) {
    switch (platform) {
      case 'google_fit':
        return Icons.fitness_center;
      case 'apple_health':
        return Icons.health_and_safety;
      case 'fitbit':
        return Icons.watch;
      case 'samsung_health':
        return Icons.phone_android;
      default:
        return Icons.device_unknown;
    }
  }

  IconData _getPlatformIcon(String platformId) {
    switch (platformId) {
      case 'google_fit':
        return Icons.fitness_center;
      case 'apple_health':
        return Icons.health_and_safety;
      case 'fitbit':
        return Icons.watch;
      case 'samsung_health':
        return Icons.phone_android;
      default:
        return Icons.device_unknown;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _connectToPlatform(String platformId) async {
    try {
      bool success = false;
      
      switch (platformId) {
        case 'google_fit':
          success = await _healthService.connectToGoogleFit();
          break;
        case 'apple_health':
          success = await _healthService.connectToAppleHealth();
          break;
        case 'fitbit':
          success = await _healthService.connectToFitbit();
          break;
        case 'samsung_health':
          success = await _healthService.connectToSamsungHealth();
          break;
      }
      
      if (success) {
        _errorHandlingService.showSuccessSnackBar(
          context,
          'Successfully connected to ${_getPlatformName(platformId)}!',
        );
      } else {
        _errorHandlingService.showErrorSnackBar(
          context,
          'Failed to connect to ${_getPlatformName(platformId)}. Please try again.',
        );
      }
    } catch (e) {
      _errorHandlingService.showErrorSnackBar(
        context,
        'Error connecting to ${_getPlatformName(platformId)}: ${e.toString()}',
      );
    }
  }

  Future<void> _disconnectDevice(String platform) async {
    try {
      await _healthService.disconnectFromPlatform(platform);
      _errorHandlingService.showSuccessSnackBar(
        context,
        'Disconnected from ${_getPlatformName(platform)}',
      );
    } catch (e) {
      _errorHandlingService.showErrorSnackBar(
        context,
        'Error disconnecting: ${e.toString()}',
      );
    }
  }

  String _getPlatformName(String platformId) {
    switch (platformId) {
      case 'google_fit':
        return 'Google Fit';
      case 'apple_health':
        return 'Apple Health';
      case 'fitbit':
        return 'Fitbit';
      case 'samsung_health':
        return 'Samsung Health';
      default:
        return 'Unknown Platform';
    }
  }
}
