import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_colors.dart';
import '../models/food_history_entry.dart';
import '../services/food_history_service.dart';
import 'food_history_detail_screen.dart';
import 'camera_screen.dart';

/// Today's Food screen showing all food items consumed today
class TodaysFoodScreen extends StatefulWidget {
  const TodaysFoodScreen({super.key});

  @override
  State<TodaysFoodScreen> createState() => _TodaysFoodScreenState();
}

class _TodaysFoodScreenState extends State<TodaysFoodScreen> {
  late Stream<List<FoodHistoryEntry>> _todaysFoodStream;
  int _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;
  double _totalFiber = 0;
  double _totalSugar = 0;

  @override
  void initState() {
    super.initState();
    _todaysFoodStream = FoodHistoryService.getTodaysFoodEntriesStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Today\'s Food',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<FoodHistoryEntry>>(
        stream: _todaysFoodStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final entries = snapshot.data ?? [];
          _calculateTotals(entries);

          if (entries.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Summary Card
              _buildSummaryCard(),
              
              // Food List
              Expanded(
                child: _buildFoodList(entries),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading today\'s food...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading food data',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 60,
              color: AppColors.primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No food logged today',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your healthy journey by\nscanning or adding food items',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToCamera(),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Food'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.1),
            AppColors.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.dashboard,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Summary',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Calories
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Calories',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalCalories kcal',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Macros
          Row(
            children: [
              Expanded(
                child: _buildMacroCard('Protein', '${_totalProtein.toStringAsFixed(1)}g', Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroCard('Carbs', '${_totalCarbs.toStringAsFixed(1)}g', Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroCard('Fat', '${_totalFat.toStringAsFixed(1)}g', Colors.red),
              ),
            ],
          ),
          
          if (_totalFiber > 0 || _totalSugar > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_totalFiber > 0) ...[
                  Expanded(
                    child: _buildMacroCard('Fiber', '${_totalFiber.toStringAsFixed(1)}g', Colors.purple),
                  ),
                  if (_totalSugar > 0) const SizedBox(width: 12),
                ],
                if (_totalSugar > 0)
                  Expanded(
                    child: _buildMacroCard('Sugar', '${_totalSugar.toStringAsFixed(1)}g', Colors.pink),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodList(List<FoodHistoryEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildFoodItem(entry);
      },
    );
  }

  Widget _buildFoodItem(FoodHistoryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToFoodDetail(entry),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Food icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getFoodIconColor(entry).withOpacity(0.2),
                        _getFoodIconColor(entry).withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getFoodIcon(entry),
                    color: _getFoodIconColor(entry),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Food details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.foodName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(entry.timestamp),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Calories
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.calories.toStringAsFixed(0)} kcal',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _calculateTotals(List<FoodHistoryEntry> entries) {
    _totalCalories = entries.fold<int>(0, (total, entry) => total + entry.calories.round());
    _totalProtein = entries.fold<double>(0, (total, entry) => total + entry.protein);
    _totalCarbs = entries.fold<double>(0, (total, entry) => total + entry.carbs);
    _totalFat = entries.fold<double>(0, (total, entry) => total + entry.fat);
    _totalFiber = entries.fold<double>(0, (total, entry) => total + entry.fiber);
    _totalSugar = entries.fold<double>(0, (total, entry) => total + entry.sugar);
  }

  void _navigateToFoodDetail(FoodHistoryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodHistoryDetailScreen(entry: entry),
      ),
    );
  }

  void _navigateToCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CameraScreen(),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getFoodIcon(FoodHistoryEntry entry) {
    // You can customize this based on food category or type
    if (entry.foodName.toLowerCase().contains('milk') || 
        entry.foodName.toLowerCase().contains('shake')) {
      return Icons.local_drink;
    } else if (entry.foodName.toLowerCase().contains('fruit')) {
      return Icons.apple;
    } else if (entry.foodName.toLowerCase().contains('vegetable')) {
      return Icons.eco;
    } else if (entry.foodName.toLowerCase().contains('meat') || 
               entry.foodName.toLowerCase().contains('chicken')) {
      return Icons.restaurant;
    } else {
      return Icons.restaurant_menu;
    }
  }

  Color _getFoodIconColor(FoodHistoryEntry entry) {
    if (entry.foodName.toLowerCase().contains('milk') || 
        entry.foodName.toLowerCase().contains('shake')) {
      return Colors.blue;
    } else if (entry.foodName.toLowerCase().contains('fruit')) {
      return Colors.green;
    } else if (entry.foodName.toLowerCase().contains('vegetable')) {
      return Colors.lightGreen;
    } else if (entry.foodName.toLowerCase().contains('meat') || 
               entry.foodName.toLowerCase().contains('chicken')) {
      return Colors.red;
    } else {
      return AppColors.primaryColor;
    }
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'camera_scan':
        return Colors.blue;
      case 'barcode_scan':
        return Colors.green;
      case 'manual_entry':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'camera_scan':
        return 'Camera';
      case 'barcode_scan':
        return 'Barcode';
      case 'manual_entry':
        return 'Manual';
      default:
        return 'Unknown';
    }
  }
}
