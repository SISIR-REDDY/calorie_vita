import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/app_colors.dart';
import '../ui/theme_aware_colors.dart';
import '../models/food_history_entry.dart';
import '../models/user_goals.dart';
import '../services/food_history_service.dart';

/// Detailed view screen for food history entries
class FoodHistoryDetailScreen extends StatefulWidget {
  final FoodHistoryEntry entry;

  const FoodHistoryDetailScreen({
    super.key,
    required this.entry,
  });

  @override
  State<FoodHistoryDetailScreen> createState() => _FoodHistoryDetailScreenState();
}

class _FoodHistoryDetailScreenState extends State<FoodHistoryDetailScreen> {
  bool _isDeleting = false;
  UserGoals? _userGoals;
  bool _isLoadingGoals = true;

  @override
  void initState() {
    super.initState();
    _loadUserGoals();
  }

  Future<void> _loadUserGoals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final goalsDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('goals')
            .doc('current')
            .get();
        
        if (goalsDoc.exists && mounted) {
          setState(() {
            _userGoals = UserGoals.fromMap(goalsDoc.data()!);
            _isLoadingGoals = false;
          });
        } else if (mounted) {
          setState(() {
            _userGoals = const UserGoals(calorieGoal: 2000);
            _isLoadingGoals = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isLoadingGoals = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userGoals = const UserGoals(calorieGoal: 2000);
          _isLoadingGoals = false;
        });
      }
    }
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
          'Food Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red[400],
            ),
            onPressed: _isDeleting ? null : _showDeleteConfirmation,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Food Header Card
            _buildEnhancedFoodHeader(),
            
            const SizedBox(height: 12),
            
            // Quick Stats Row
            _buildQuickStatsRow(),
            
            const SizedBox(height: 12),
            
            // Nutrition Information with Visual Breakdown
            _buildEnhancedNutritionCard(),
            
            const SizedBox(height: 12),
            
            // Macro Breakdown Visualization
            _buildMacroBreakdownCard(),
            
            const SizedBox(height: 12),
            
            // Additional Information
            _buildEnhancedAdditionalInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFoodHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDarkMode
              ? [
                  kPrimaryColor.withValues(alpha: 0.2),
                  kPrimaryColor.withValues(alpha: 0.1),
                ]
              : [
                  AppColors.primaryColor.withOpacity(0.15),
                  AppColors.primaryColor.withOpacity(0.08),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kPrimaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getFoodIconColor().withOpacity(0.3),
                      _getFoodIconColor().withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getFoodIcon(),
                  color: _getFoodIconColor(),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.entry.formattedTimestamp,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Badges Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (widget.entry.category != null && widget.entry.category!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: kPrimaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category_rounded,
                        size: 12,
                        color: kPrimaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.entry.category!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getSourceColor(widget.entry.source).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _getSourceColor(widget.entry.source).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSourceIconData(widget.entry.source),
                      size: 12,
                      color: _getSourceColor(widget.entry.source),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.entry.sourceDisplayName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getSourceColor(widget.entry.source),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            'Calories',
            widget.entry.calories.toStringAsFixed(0),
            'kcal',
            kPrimaryColor,
            Icons.local_fire_department_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            'Weight',
            widget.entry.weightGrams.toStringAsFixed(0),
            'g',
            kInfoColor,
            Icons.scale_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String label, String value, String unit, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDarkMode ? kDarkSurfaceLight : kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedNutritionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? kDarkSurfaceLight : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode ? kDarkBorderColor : kBorderColor,
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: kPrimaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Nutrition Information',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Compact Grid Layout
          Row(
            children: [
              Expanded(
                child: _buildCompactNutritionItem(
                  'Protein',
                  widget.entry.protein,
                  kInfoColor,
                  Icons.egg_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactNutritionItem(
                  'Carbs',
                  widget.entry.carbs,
                  kAccentColor,
                  Icons.bakery_dining_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactNutritionItem(
                  'Fat',
                  widget.entry.fat,
                  kWarningColor,
                  Icons.water_drop_rounded,
                ),
              ),
            ],
          ),
          
          if (widget.entry.fiber > 0 || widget.entry.sugar > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.entry.fiber > 0) ...[
                  Expanded(
                    child: _buildCompactNutritionItem(
                      'Fiber',
                      widget.entry.fiber,
                      kAccentPurple,
                      Icons.eco_rounded,
                    ),
                  ),
                  if (widget.entry.sugar > 0) const SizedBox(width: 8),
                ],
                if (widget.entry.sugar > 0)
                  Expanded(
                    child: _buildCompactNutritionItem(
                      'Sugar',
                      widget.entry.sugar,
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

  Widget _buildCompactNutritionItem(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'g',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBreakdownCard() {
    final totalMacros = widget.entry.protein + widget.entry.carbs + widget.entry.fat;
    if (totalMacros == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? kDarkSurfaceLight : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode ? kDarkBorderColor : kBorderColor,
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: kPrimaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Macro Breakdown',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Progress bars for macros
          _buildMacroProgressBar('Protein', widget.entry.protein, totalMacros, kInfoColor, Icons.egg_rounded),
          const SizedBox(height: 10),
          _buildMacroProgressBar('Carbs', widget.entry.carbs, totalMacros, kAccentColor, Icons.bakery_dining_rounded),
          const SizedBox(height: 10),
          _buildMacroProgressBar('Fat', widget.entry.fat, totalMacros, kWarningColor, Icons.water_drop_rounded),
        ],
      ),
    );
  }

  Widget _buildMacroProgressBar(String label, double value, double total, Color color, IconData icon) {
    final percentage = total > 0 ? (value / total) * 100 : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '${value.toStringAsFixed(1)}g (${percentage.toStringAsFixed(1)}%)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }


  Widget _buildEnhancedAdditionalInfoCard() {
    // Calculate calorie density
    final calorieDensity = widget.entry.weightGrams > 0
        ? (widget.entry.calories / widget.entry.weightGrams * 100)
        : 0.0;
    
    // Determine meal time
    final mealTime = _getMealTime(widget.entry.timestamp);
    
    // Calculate daily goal contribution
    final calorieGoal = _userGoals?.calorieGoal ?? 2000;
    final calorieContribution = (widget.entry.calories / calorieGoal * 100);
    
    // Calculate health grade
    final healthGrade = _calculateHealthGrade();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? kDarkSurfaceLight : kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode ? kDarkBorderColor : kBorderColor,
          width: 1,
        ),
        boxShadow: context.isDarkMode ? kDarkCardShadow : kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: kPrimaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Additional Information',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Health Status (First)
          _buildHealthStatusChip(healthGrade),
          const SizedBox(height: 8),
          
          // Meal Time
          _buildInfoChip(
            Icons.access_time_rounded,
            'Meal Time',
            mealTime,
            kInfoColor,
          ),
          const SizedBox(height: 8),
          
          // Calorie Density
          _buildInfoChip(
            Icons.speed_rounded,
            'Calorie Density',
            '${calorieDensity.toStringAsFixed(1)} kcal/100g',
            kAccentColor,
          ),
          const SizedBox(height: 8),
          
          // Daily Goal Contribution
          _buildInfoChip(
            Icons.track_changes_rounded,
            'Daily Goal',
            '${calorieContribution.toStringAsFixed(1)}% of daily calories',
            kPrimaryColor,
          ),
          
          if (widget.entry.brand != null && widget.entry.brand!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoChip(
              Icons.branding_watermark_rounded,
              'Brand',
              widget.entry.brand!,
              kInfoColor,
            ),
          ],
          
          if (widget.entry.notes != null && widget.entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.note_rounded,
                  size: 16,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.entry.notes!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMealTime(DateTime timestamp) {
    final hour = timestamp.hour;
    if (hour >= 5 && hour < 11) {
      return 'Breakfast';
    } else if (hour >= 11 && hour < 15) {
      return 'Lunch';
    } else if (hour >= 15 && hour < 19) {
      return 'Snack';
    } else if (hour >= 19 && hour < 22) {
      return 'Dinner';
    } else {
      return 'Late Night';
    }
  }

  Map<String, dynamic> _calculateHealthGrade() {
    double score = 100.0; // Start with perfect score
    
    // Calculate per 100g values
    final weight = widget.entry.weightGrams > 0 ? widget.entry.weightGrams : 100.0;
    final caloriesPer100g = (widget.entry.calories / weight * 100);
    final proteinPer100g = (widget.entry.protein / weight * 100);
    final carbsPer100g = (widget.entry.carbs / weight * 100);
    final fatPer100g = (widget.entry.fat / weight * 100);
    final fiberPer100g = (widget.entry.fiber / weight * 100);
    final sugarPer100g = (widget.entry.sugar / weight * 100);
    
    // Calorie density penalty (high calorie density = less healthy)
    if (caloriesPer100g > 500) {
      score -= 20; // Very high calorie density
    } else if (caloriesPer100g > 400) {
      score -= 15;
    } else if (caloriesPer100g > 300) {
      score -= 10;
    } else if (caloriesPer100g < 50) {
      score += 5; // Very low calorie density is good
    }
    
    // Sugar penalty (high sugar = less healthy)
    if (sugarPer100g > 30) {
      score -= 25; // Very high sugar
    } else if (sugarPer100g > 20) {
      score -= 15;
    } else if (sugarPer100g > 10) {
      score -= 8;
    }
    
    // Fiber bonus (high fiber = healthier)
    if (fiberPer100g > 5) {
      score += 15; // High fiber
    } else if (fiberPer100g > 3) {
      score += 10;
    } else if (fiberPer100g > 1) {
      score += 5;
    }
    
    // Protein bonus (good protein content)
    if (proteinPer100g > 15) {
      score += 10; // High protein
    } else if (proteinPer100g > 10) {
      score += 5;
    }
    
    // Fat penalty (very high fat = less healthy, but some fat is okay)
    if (fatPer100g > 30) {
      score -= 15; // Very high fat
    } else if (fatPer100g > 20) {
      score -= 8;
    }
    
    // Sugar to carbs ratio (high ratio = less healthy)
    if (carbsPer100g > 0) {
      final sugarRatio = (sugarPer100g / carbsPer100g) * 100;
      if (sugarRatio > 50) {
        score -= 10; // More than 50% of carbs are sugar
      } else if (sugarRatio > 30) {
        score -= 5;
      }
    }
    
    // Determine grade
    String grade;
    String label;
    Color color;
    
    if (score >= 85) {
      grade = 'A';
      label = 'Excellent';
      color = kSuccessColor;
    } else if (score >= 70) {
      grade = 'B';
      label = 'Good';
      color = kInfoColor;
    } else if (score >= 55) {
      grade = 'C';
      label = 'Average';
      color = kWarningColor;
    } else if (score >= 40) {
      grade = 'D';
      label = 'Below Average';
      color = kAccentColor;
    } else {
      grade = 'E';
      label = 'Unhealthy';
      color = kErrorColor;
    }
    
    return {
      'grade': grade,
      'label': label,
      'color': color,
      'score': score,
    };
  }

  Widget _buildHealthStatusChip(Map<String, dynamic> healthData) {
    final grade = healthData['grade'] as String;
    final label = healthData['label'] as String;
    final color = healthData['color'] as Color;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                grade,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
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
                  'Health Status',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  IconData _getFoodIcon() {
    final category = widget.entry.category?.toLowerCase();
    final foodName = widget.entry.foodName.toLowerCase();
    
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
    if (category == null) return Icons.restaurant_menu_rounded;
    
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

  Color _getFoodIconColor() {
    final category = widget.entry.category?.toLowerCase();
    if (category == null) return kPrimaryColor;
    
    if (category.contains('fruit') || category.contains('apple') || category.contains('banana')) {
      return kErrorColor;
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return kSuccessColor;
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return kAccentColor;
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return kInfoColor;
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return kAccentColor;
    } else if (category.contains('drink') || category.contains('beverage')) {
      return kInfoColor;
    } else if (category.contains('snack') || category.contains('chip')) {
      return kAccentPurple;
    } else {
      return kPrimaryColor;
    }
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'camera_scan':
        return kInfoColor;
      case 'barcode_scan':
        return kSuccessColor;
      case 'manual_entry':
        return kAccentColor;
      default:
        return kPrimaryColor;
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Delete Food Entry',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${widget.entry.foodName}" from your history?',
            style: GoogleFonts.inter(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEntry();
              },
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: Colors.red[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEntry() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final success = await FoodHistoryService.deleteFoodEntry(widget.entry.id);
      
      if (success && mounted) {
        Navigator.of(context).pop(true); // Return true to indicate deletion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Food entry deleted successfully',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green[600],
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete food entry',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting food entry',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}

