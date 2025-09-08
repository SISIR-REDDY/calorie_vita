import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../services/health_data_service.dart';
import '../services/google_fit_service.dart';
import 'google_fit_integration_dialog.dart';

/// Health Integration Dialog for connecting to health data sources
class HealthIntegrationDialog extends StatefulWidget {
  final HealthDataService healthDataService;

  const HealthIntegrationDialog({
    super.key,
    required this.healthDataService,
  });

  @override
  State<HealthIntegrationDialog> createState() => _HealthIntegrationDialogState();
}

class _HealthIntegrationDialogState extends State<HealthIntegrationDialog> {
  late HealthDataService _healthDataService;
  late GoogleFitService _googleFitService;

  // State management
  bool _isLoading = false;
  Map<String, bool> _sourceStatus = {};

  @override
  void initState() {
    super.initState();
    _healthDataService = widget.healthDataService;
    _googleFitService = GoogleFitService();

    _initializeServices();
    _setupListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Initialize health services
  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);

    try {
      await _healthDataService.initialize();
      await _googleFitService.initialize();

      // Get available sources
      final sources = await _healthDataService.getAvailableSources();
      setState(() {
        _sourceStatus = sources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to initialize health services: $e');
    }
  }

  /// Set up listeners for health data updates
  void _setupListeners() {
    // Listen for health data updates if needed
  }

  /// Connect to Google Fit
  Future<void> _connectGoogleFit() async {
    // Show the new Google Fit integration dialog
    await showDialog(
      context: context,
      builder: (context) => GoogleFitIntegrationDialog(
        googleFitService: _googleFitService,
        onSuccess: () {
          _updateSourceStatus();
        },
      ),
    );
  }


  /// Update source status
  void _updateSourceStatus() {
    setState(() {
      _sourceStatus = {
        'Google Health': _googleFitService.isConnected,
      };
    });
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kSuccessColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kErrorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Connect to Google Health',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: kTextSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Description
                    Text(
                      'Sync your fitness data with Health Connect to automatically track your daily activity.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kTextSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Google Health Card
                    _buildGoogleHealthCard(),
                    
                    const SizedBox(height: 16),
                    
                    // Benefits
                    _buildBenefitsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Google Health card
  Widget _buildGoogleHealthCard() {
    final isConnected = _googleFitService.isConnected;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Google Fit Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      child: Image.asset(
                        'google-fit-png-logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Health',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sync steps, calories, and heart rate data',
                        style: GoogleFonts.poppins(
                          color: kTextSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (isConnected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34A853),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Connected',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isConnected ? null : _connectGoogleFit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.grey[300] : const Color(0xFF4285F4),
                  foregroundColor: isConnected ? Colors.grey[600] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: Text(
                  isConnected ? 'Connected' : 'Connect',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build benefits section
  Widget _buildBenefitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you\'ll get:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 8),
        _buildBenefitItem(Icons.directions_walk, 'Automatic step tracking'),
        _buildBenefitItem(Icons.local_fire_department, 'Calorie burn monitoring'),
        _buildBenefitItem(Icons.favorite, 'Heart rate data'),
        _buildBenefitItem(Icons.trending_up, 'Real-time activity updates'),
      ],
    );
  }

  /// Build individual benefit item
  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF34A853),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: kTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

}
