import 'package:flutter/material.dart';
import '../services/google_fit_service.dart';
import '../services/google_fit_cache_service.dart';
import '../models/google_fit_data.dart';
import '../ui/app_colors.dart';
import 'enhanced_loading_widgets.dart';

/// Widget for displaying Google Fit integration
class GoogleFitWidget extends StatefulWidget {
  const GoogleFitWidget({super.key});

  @override
  State<GoogleFitWidget> createState() => _GoogleFitWidgetState();
}

class _GoogleFitWidgetState extends State<GoogleFitWidget> {
  final GoogleFitService _googleFitService = GoogleFitService();
  final GoogleFitCacheService _cacheService = GoogleFitCacheService();
  
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isRefreshing = false;
  GoogleFitData? _todayData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    setState(() {
      _isAuthenticated = _googleFitService.isAuthenticated;
    });
    
    if (_isAuthenticated) {
      await _loadTodayData();
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await _googleFitService.authenticate();
      if (success) {
        setState(() {
          _isAuthenticated = true;
        });
        await _loadTodayData();
      } else {
        setState(() {
          _error = 'Authentication failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error connecting to Google Fit: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTodayData() async {
    if (!_isAuthenticated) return;

    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      // Use cache service for faster loading
      final data = await _cacheService.getTodayData(forceRefresh: true);
      
      setState(() {
        _todayData = data;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load fitness data: ${e.toString()}';
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadTodayDataFallback() async {
    if (!_isAuthenticated) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final today = DateTime.now();
      final steps = await _googleFitService.getDailySteps(today);
      final calories = await _googleFitService.getDailyCaloriesBurned(today);
      final distance = await _googleFitService.getDailyDistance(today);
      final weight = await _googleFitService.getCurrentWeight();

      setState(() {
        _todayData = GoogleFitData(
          date: today,
          steps: steps,
          caloriesBurned: calories,
          distance: distance,
          weight: weight,
        );
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading fitness data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _googleFitService.signOut();
    setState(() {
      _isAuthenticated = false;
      _todayData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (_isLoading)
            _buildLoadingState()
          else if (_error != null)
            _buildErrorState()
          else if (!_isAuthenticated)
            _buildNotConnectedState()
          else if (_todayData != null)
            _buildFitnessData()
          else
            _buildNoDataState(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.fitness_center,
            color: Colors.blue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Google Fit Integration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ),
        if (_isAuthenticated)
          IconButton(
            onPressed: _signOut,
            icon: const Icon(
              Icons.logout,
              color: kTextSecondary,
              size: 18,
            ),
            tooltip: 'Disconnect Google Fit',
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _isRefreshing 
          ? GoogleFitShimmerCard(height: 100)
          : EnhancedLoadingWidget(
              text: 'Syncing with Google Fit...',
              color: AppColors.primary,
              size: 32,
            ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _authenticate,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_outlined,
            color: Colors.blue,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Connect to Google Fit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sync your fitness data to get a complete picture of your health journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _authenticate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Connect Google Fit'),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessData() {
    return SmoothDataTransition(
      isLoading: _isLoading || _isRefreshing,
      child: Column(
        children: [
          // Steps and Calories Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Steps',
                  _todayData!.formattedSteps,
                  Icons.directions_walk,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Calories Burned',
                  _todayData!.formattedCalories,
                  Icons.local_fire_department,
                  Colors.orange,
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        
        // Distance and Activity Level Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Distance',
                _todayData!.formattedDistance,
                Icons.straighten,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Activity Level',
                _todayData!.activityLevel,
                Icons.trending_up,
                _getActivityLevelColor(_todayData!.activityLevel),
              ),
            ),
          ],
        ),
        
        // Refresh button
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadTodayData,
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh Data'),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTextSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_outlined,
            color: kTextSecondary.withValues(alpha: 0.5),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'No fitness data available',
            style: TextStyle(
              fontSize: 14,
              color: kTextSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadTodayData,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Load Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getActivityLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'very active':
        return Colors.green;
      case 'active':
        return Colors.lightGreen;
      case 'moderate':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return kTextSecondary;
    }
  }
}
