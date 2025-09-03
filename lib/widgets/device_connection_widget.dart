import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bluetooth_device_service.dart';
import '../ui/app_colors.dart';

/// Widget for managing Bluetooth device connections
class DeviceConnectionWidget extends StatefulWidget {
  const DeviceConnectionWidget({super.key});

  @override
  State<DeviceConnectionWidget> createState() => _DeviceConnectionWidgetState();
}

class _DeviceConnectionWidgetState extends State<DeviceConnectionWidget> {
  final BluetoothDeviceService _bluetoothService = BluetoothDeviceService();
  List<BluetoothDevice> _availableDevices = [];
  bool _isScanning = false;
  String _connectionStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _bluetoothService.isScanningStream.listen((isScanning) {
      if (mounted) {
        setState(() {
          _isScanning = isScanning;
        });
      }
    });

    _bluetoothService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    });

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _availableDevices = results
              .map((result) => result.device)
              .where((device) => _bluetoothService.isFitnessDevice(
                  device.platformName.isNotEmpty 
                      ? device.platformName 
                      : device.remoteId.toString()))
              .toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bluetooth,
                    color: kAccentBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fitness Devices',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'Connect your smartwatch or fitness tracker',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Scan button
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScanning,
                  icon: _isScanning 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(
                    _isScanning ? 'Scanning...' : 'Scan',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Connection status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getStatusColor().withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _connectionStatus,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Connected devices
            StreamBuilder<List<BluetoothDevice>>(
              stream: _bluetoothService.connectedDevicesStream,
              builder: (context, snapshot) {
                final connectedDevices = snapshot.data ?? [];
                
                if (connectedDevices.isEmpty) {
                  return _buildNoDevicesState();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Devices',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...connectedDevices.map((device) => _buildConnectedDeviceCard(device)),
                  ],
                );
              },
            ),

            // Available devices
            if (_availableDevices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Available Devices',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 8),
              ..._availableDevices.map((device) => _buildAvailableDeviceCard(device)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoDevicesState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kTextSecondary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kTextSecondary.withOpacity(0.1),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.devices_other_outlined,
            size: 48,
            color: kTextSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No devices connected',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Scan" to find nearby fitness devices',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kTextSecondary.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceCard(BluetoothDevice device) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';
    final deviceIcon = _bluetoothService.getDeviceIcon(deviceName);
    final deviceColor = _bluetoothService.getDeviceColor(deviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: deviceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: deviceColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: deviceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              deviceIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
                Text(
                  'Connected',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kAccentGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _disconnectDevice(device),
            icon: const Icon(
              Icons.close,
              color: kErrorColor,
              size: 20,
            ),
            tooltip: 'Disconnect',
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeviceCard(BluetoothDevice device) {
    final deviceName = device.platformName.isNotEmpty 
        ? device.platformName 
        : 'Unknown Device';
    final deviceIcon = _bluetoothService.getDeviceIcon(deviceName);
    final deviceColor = _bluetoothService.getDeviceColor(deviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kTextSecondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: deviceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              deviceIcon,
              color: deviceColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
                Text(
                  'Available',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _connectToDevice(device),
            style: ElevatedButton.styleFrom(
              backgroundColor: deviceColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(
              'Connect',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_connectionStatus.contains('Connected')) {
      return kAccentGreen;
    } else if (_connectionStatus.contains('Scanning')) {
      return kAccentBlue;
    } else if (_connectionStatus.contains('Error')) {
      return kErrorColor;
    } else {
      return kTextSecondary;
    }
  }

  IconData _getStatusIcon() {
    if (_connectionStatus.contains('Connected')) {
      return Icons.check_circle;
    } else if (_connectionStatus.contains('Scanning')) {
      return Icons.search;
    } else if (_connectionStatus.contains('Error')) {
      return Icons.error;
    } else {
      return Icons.bluetooth_disabled;
    }
  }

  void _startScanning() {
    _bluetoothService.startScanning();
  }

  void _connectToDevice(BluetoothDevice device) async {
    final success = await _bluetoothService.connectToDevice(device);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.platformName}'),
          backgroundColor: kAccentGreen,
        ),
      );
    }
  }

  void _disconnectDevice(BluetoothDevice device) async {
    await _bluetoothService.disconnectDevice(device);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from ${device.platformName}'),
          backgroundColor: kTextSecondary,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
