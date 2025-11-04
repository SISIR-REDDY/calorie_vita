import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/app_colors.dart';
import '../models/food_history_entry.dart';
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
        padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Name Card
            _buildFoodNameCard(),
            
            const SizedBox(height: 20),
            
            // Nutrition Information
            _buildNutritionCard(),
            
            const SizedBox(height: 20),
            
            // Additional Information
            _buildAdditionalInfoCard(),
            
            const SizedBox(height: 20),
            
            // Scan Information
            _buildScanInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodNameCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.1),
            AppColors.secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFoodIcon(),
                  color: AppColors.primaryColor,
                  size: 24,
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
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.entry.formattedTimestamp,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (widget.entry.category != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.entry.category!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          
          // Calories (highlighted)
          _buildNutritionRow(
            'Calories',
            '${widget.entry.calories.toStringAsFixed(1)} kcal',
            AppColors.primaryColor,
            Icons.local_fire_department,
          ),
          
          const SizedBox(height: 12),
          
          // Macros
          _buildNutritionRow(
            'Protein',
            '${widget.entry.protein.toStringAsFixed(1)}g',
            Colors.blue[600]!,
            Icons.fitness_center,
          ),
          
          _buildNutritionRow(
            'Carbs',
            '${widget.entry.carbs.toStringAsFixed(1)}g',
            Colors.orange[600]!,
            Icons.grain,
          ),
          
          _buildNutritionRow(
            'Fat',
            '${widget.entry.fat.toStringAsFixed(1)}g',
            Colors.purple[600]!,
            Icons.opacity,
          ),
          
          _buildNutritionRow(
            'Fiber',
            '${widget.entry.fiber.toStringAsFixed(1)}g',
            Colors.green[600]!,
            Icons.eco,
          ),
          
          _buildNutritionRow(
            'Sugar',
            '${widget.entry.sugar.toStringAsFixed(1)}g',
            Colors.red[600]!,
            Icons.cake,
          ),
          
          const SizedBox(height: 16),
          
          // Weight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.scale,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Weight: ${widget.entry.weightGrams.toStringAsFixed(1)}g',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          
          if (widget.entry.brand != null) ...[
            _buildInfoRow('Brand', widget.entry.brand!),
            const SizedBox(height: 8),
          ],
          
          
          _buildInfoRow('Date Added', _formatDate(widget.entry.timestamp)),
          
          if (widget.entry.notes != null && widget.entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Notes',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.entry.notes!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanInfoCard() {
    if (widget.entry.scanData == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          
          if (widget.entry.scanData!['confidence'] != null) ...[
            _buildInfoRow(
              'Confidence', 
              '${(widget.entry.scanData!['confidence'] * 100).toStringAsFixed(1)}%'
            ),
            const SizedBox(height: 8),
          ],
          
          if (widget.entry.scanData!['overall_confidence'] != null) ...[
            _buildInfoRow(
              'Overall Confidence', 
              '${(widget.entry.scanData!['overall_confidence'] * 100).toStringAsFixed(1)}%'
            ),
            const SizedBox(height: 8),
          ],
          
          if (widget.entry.scanData!['recommended_action'] != null) ...[
            _buildInfoRow(
              'Recommended Action', 
              widget.entry.scanData!['recommended_action']
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFoodIcon() {
    final category = widget.entry.category?.toLowerCase();
    if (category == null) return Icons.restaurant;
    
    if (category.contains('fruit') || category.contains('apple') || category.contains('banana')) {
      return Icons.apple;
    } else if (category.contains('vegetable') || category.contains('salad')) {
      return Icons.eco;
    } else if (category.contains('meat') || category.contains('chicken') || category.contains('beef')) {
      return Icons.grass;
    } else if (category.contains('dairy') || category.contains('milk') || category.contains('cheese')) {
      return Icons.local_drink;
    } else if (category.contains('bread') || category.contains('grain') || category.contains('rice')) {
      return Icons.grain;
    } else if (category.contains('drink') || category.contains('beverage')) {
      return Icons.local_cafe;
    } else if (category.contains('snack') || category.contains('chip')) {
      return Icons.cookie;
    } else {
      return Icons.restaurant;
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
