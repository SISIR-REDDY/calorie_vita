import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../services/google_fit_service.dart';

/// User-friendly dialog for Google Fit integration with proper error handling
class GoogleFitIntegrationDialog extends StatefulWidget {
  final GoogleFitService googleFitService;
  final VoidCallback? onSuccess;

  const GoogleFitIntegrationDialog({
    super.key,
    required this.googleFitService,
    this.onSuccess,
  });

  @override
  State<GoogleFitIntegrationDialog> createState() => _GoogleFitIntegrationDialogState();
}

class _GoogleFitIntegrationDialogState extends State<GoogleFitIntegrationDialog> {
  bool _isLoading = false;
  bool _isConnected = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connectToGoogleFit();
  }

  /// Connect to Google Fit
  Future<void> _connectToGoogleFit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First check availability
      final isAvailable = await widget.googleFitService.checkGoogleFitAvailability();
      if (!isAvailable) {
        final error = widget.googleFitService.lastError ?? 'Health Connect is not available';
        setState(() {
          _isConnected = false;
          _errorMessage = error;
        });
        return;
      }

      // Try to connect
      final success = await widget.googleFitService.connect();
      
      if (success) {
        setState(() {
          _isConnected = true;
          _errorMessage = null;
        });
        
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
        
        // Close dialog after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        final error = widget.googleFitService.lastError ?? 'Failed to connect to Health Connect';
        setState(() {
          _isConnected = false;
          _errorMessage = error;
        });
      }
    } catch (e) {
      final error = widget.googleFitService.lastError ?? 'Failed to connect to Health Connect: $e';
      setState(() {
        _isConnected = false;
        _errorMessage = error;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Center(
              child: Text(
                'Connect to Google Health...',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Content
            if (_isLoading)
              _buildLoadingContent()
            else if (_isConnected)
              _buildSuccessContent()
            else if (_errorMessage != null)
              _buildWarningContent()
            else
              _buildInitialContent(),
            
            const SizedBox(height: 24),
            
            // Action button
            _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      children: [
        const CircularProgressIndicator(color: kAccentBlue),
        const SizedBox(height: 16),
        Text(
          'Connecting to Google Fit...',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: kTextDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          color: kSuccessColor,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'Connected Successfully!',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kSuccessColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your fitness data will now be automatically synced.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWarningContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Google Fit Logo
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'google-fit-png-logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Warning Title
        Text(
          'Health Connect Setup Required',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        
        // Error message
        Text(
          _errorMessage ?? 'Please install Health Connect and connect your fitness tracker',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        
        // Setup steps in a compact format
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            children: [
              _buildCompactStep('1', 'Install Health Connect from Play Store'),
              const SizedBox(height: 8),
              _buildCompactStep('2', 'Connect your smart watch or Fitbit'),
              const SizedBox(height: 8),
              _buildCompactStep('3', 'Allow health data permissions'),
              const SizedBox(height: 8),
              _buildCompactStep('4', 'Try connecting again'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.orange[700],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialContent() {
    return Column(
      children: [
        Text(
          'Sync your fitness data with Health Connect to automatically track your daily activity.',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_isConnected) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: kSuccessColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Done',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Open Google Fit in Play Store
                await widget.googleFitService.openGoogleFitInPlayStore();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.shop),
              label: const Text('Got it, I\'ll set it up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    // Show debug info
                    final status = await widget.googleFitService.getHealthConnectStatus();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Debug Info'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: status.entries.map((entry) => 
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('${entry.key}: ${entry.value}'),
                              )
                            ).toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text(
                    'Debug Info',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Maybe later',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _connectToGoogleFit,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Connect',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
