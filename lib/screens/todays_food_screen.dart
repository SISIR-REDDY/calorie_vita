import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';
import '../models/food_history_entry.dart';
import '../services/food_history_service.dart';
import 'food_history_detail_screen.dart';

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
            fontSize: MediaQuery.of(context).size.width < 360 ? 18 : 20,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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
            width: MediaQuery.of(context).size.width < 360 ? 100 : 120,
            height: MediaQuery.of(context).size.width < 360 ? 100 : 120,
            constraints: const BoxConstraints(
              minWidth: 80,
              maxWidth: 140,
              minHeight: 80,
              maxHeight: 140,
            ),
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
            'Start your healthy journey by\nadding food items',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDarkMode
              ? [
                  kPrimaryColor.withValues(alpha: 0.15),
                  kPrimaryColor.withValues(alpha: 0.05),
                ]
              : [
                  AppColors.primaryColor.withOpacity(0.1),
                  AppColors.primaryColor.withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        children: [
          // Compact Header with Calories
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor.withOpacity(0.2),
                      AppColors.primaryColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Calories',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_totalCalories',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'kcal',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Compact Macros Row
          Row(
            children: [
              Expanded(
                child: _buildCompactMacroCard(
                  'Protein',
                  _totalProtein,
                  kInfoColor,
                  Icons.egg_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMacroCard(
                  'Carbs',
                  _totalCarbs,
                  kAccentColor,
                  Icons.bakery_dining_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactMacroCard(
                  'Fat',
                  _totalFat,
                  kWarningColor,
                  Icons.water_drop_rounded,
                ),
              ),
            ],
          ),
          
          if (_totalFiber > 0 || _totalSugar > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (_totalFiber > 0) ...[
                  Expanded(
                    child: _buildCompactMacroCard(
                      'Fiber',
                      _totalFiber,
                      kAccentPurple,
                      Icons.eco_rounded,
                    ),
                  ),
                  if (_totalSugar > 0) const SizedBox(width: 8),
                ],
                if (_totalSugar > 0)
                  Expanded(
                    child: _buildCompactMacroCard(
                      'Sugar',
                      _totalSugar,
                      kErrorColor,
                      Icons.cookie_rounded,
                    ),
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

  Widget _buildCompactMacroCard(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'g',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodList(List<FoodHistoryEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildFoodItem(entry);
      },
    );
  }

  Widget _buildFoodItem(FoodHistoryEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToFoodDetail(entry),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.isDarkMode ? kDarkSurfaceLight : kSurfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.isDarkMode
                    ? kDarkBorderColor.withOpacity(0.2)
                    : kBorderColor,
                width: 1,
              ),
              boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact Header Row
                Row(
                  children: [
                    // Food Icon - Smaller
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getFoodIconColor(entry).withOpacity(0.2),
                            _getFoodIconColor(entry).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getFoodIcon(entry),
                        color: _getFoodIconColor(entry),
                        size: 22,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Food Name and Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Category Badge - Smaller
                              if (entry.category != null && entry.category!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kPrimaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    entry.category!,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                ),
                              if (entry.category != null && entry.category!.isNotEmpty)
                                const SizedBox(width: 4),
                              // Source Badge - Icon only
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getSourceColor(entry.source).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getSourceIconData(entry.source),
                                      size: 10,
                                      color: _getSourceColor(entry.source),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Calories Badge - Compact
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kPrimaryColor.withValues(alpha: 0.15),
                            kPrimaryColor.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: kPrimaryColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.calories.toStringAsFixed(0),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryColor,
                            ),
                          ),
                          Text(
                            'kcal',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Clickable indicator arrow
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: context.textSecondary.withOpacity(0.6),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Compact Macros Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.isDarkMode
                        ? kDarkSurfaceDark
                        : kSurfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCompactMacroChip('P', entry.protein, kInfoColor, Icons.egg_rounded),
                      Container(
                        width: 1,
                        height: 20,
                        color: context.isDarkMode
                            ? kDarkDividerColor
                            : kDividerColor,
                      ),
                      _buildCompactMacroChip('C', entry.carbs, kAccentColor, Icons.bakery_dining_rounded),
                      Container(
                        width: 1,
                        height: 20,
                        color: context.isDarkMode
                            ? kDarkDividerColor
                            : kDividerColor,
                      ),
                      _buildCompactMacroChip('F', entry.fat, kWarningColor, Icons.opacity_rounded),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Compact Footer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Portion Size
                    Row(
                      children: [
                        Icon(
                          Icons.scale_rounded,
                          size: 12,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.weightGrams.toStringAsFixed(0)}g',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.formattedTimestamp,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build compact macro chip for food entry
  Widget _buildCompactMacroChip(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${value.toStringAsFixed(1)}g',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ],
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
    final category = entry.category?.toLowerCase();
    final foodName = entry.foodName.toLowerCase();
    
    // Check food name first for better accuracy
    if (foodName.contains('apple') || foodName.contains('banana') || foodName.contains('orange')) {
      return Icons.apple_rounded;
    } else if (foodName.contains('chicken') || foodName.contains('meat') || foodName.contains('beef')) {
      return Icons.set_meal_rounded;
    } else if (foodName.contains('rice') || foodName.contains('bread') || foodName.contains('pasta')) {
      return Icons.bakery_dining_rounded;
    } else if (foodName.contains('milk') || foodName.contains('cheese') || foodName.contains('yogurt')) {
      return Icons.lunch_dining_rounded;
    } else if (foodName.contains('salad') || foodName.contains('vegetable')) {
      return Icons.eco_rounded;
    } else if (foodName.contains('drink') || foodName.contains('juice') || foodName.contains('coffee')) {
      return Icons.local_drink_rounded;
    } else if (foodName.contains('snack') || foodName.contains('chip') || foodName.contains('cookie')) {
      return Icons.cookie_rounded;
    }
    
    // Fallback to category
    if (category == null) return Icons.restaurant_rounded;
    
    if (category.contains('fruit')) {
      return Icons.apple_rounded;
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return Icons.eco_rounded;
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return Icons.set_meal_rounded;
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return Icons.lunch_dining_rounded;
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return Icons.bakery_dining_rounded;
    } else if (category.contains('drink') || category.contains('beverage')) {
      return Icons.local_drink_rounded;
    } else if (category.contains('snack') || category.contains('chip')) {
      return Icons.cookie_rounded;
    } else {
      return Icons.restaurant_menu_rounded;
    }
  }

  Color _getFoodIconColor(FoodHistoryEntry entry) {
    final category = entry.category?.toLowerCase();
    if (category == null) return kPrimaryColor;
    
    if (category.contains('fruit') || category.contains('apple') || category.contains('banana')) {
      return kErrorColor; // Red for fruits
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return kSuccessColor; // Green for vegetables
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return kAccentColor; // Orange/Amber for meat
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return kInfoColor; // Blue for dairy
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return kAccentColor; // Orange/Amber for grains
    } else if (category.contains('drink') || category.contains('beverage')) {
      return kInfoColor; // Blue for drinks
    } else if (category.contains('snack') || category.contains('chip')) {
      return kAccentPurple; // Purple for snacks
    } else {
      return kPrimaryColor;
    }
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'camera_scan':
        return kInfoColor; // Blue for camera
      case 'barcode_scan':
        return kSuccessColor; // Green for barcode
      case 'manual_entry':
        return kAccentColor; // Orange/Amber for manual
      default:
        return kPrimaryColor;
    }
  }

  String _getSourceIcon(String source) {
    switch (source) {
      case 'camera_scan':
        return '📷';
      case 'barcode_scan':
        return '📱';
      case 'manual_entry':
        return '✏️';
      default:
        return '❓';
    }
  }

  IconData _getSourceIconData(String source) {
    switch (source) {
      case 'camera_scan':
        return Icons.camera_alt_rounded;
      case 'barcode_scan':
        return Icons.qr_code_scanner_rounded;
      case 'manual_entry':
        return Icons.edit_rounded;
      default:
        return Icons.help_outline_rounded;
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
