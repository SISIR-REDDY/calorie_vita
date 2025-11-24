import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/food_scan_result.dart';
import '../services/food_database_service.dart';
import '../services/food_history_service.dart';
import '../models/food_history_entry.dart';

/// Screen to confirm and adjust scanned food before adding to diary
class FoodConfirmationScreen extends StatefulWidget {
  final FoodScanResult result;
  final String imagePath;

  const FoodConfirmationScreen({
    super.key,
    required this.result,
    required this.imagePath,
  });

  @override
  State<FoodConfirmationScreen> createState() => _FoodConfirmationScreenState();
}

class _FoodConfirmationScreenState extends State<FoodConfirmationScreen> {
  late FoodScanResult _currentResult;
  double _portionMultiplier = 1.0;
  String _selectedPortion = 'Medium';
  bool _isAdding = false;

  final _foodDatabaseService = FoodDatabaseService();

  // Portion presets
  final Map<String, double> _portionPresets = {
    'Small': 0.7,
    'Medium': 1.0,
    'Large': 1.3,
    'Extra Large': 1.6,
  };

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
    _checkUsualPortion();
  }

  Future<void> _checkUsualPortion() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final usualPortion = await _foodDatabaseService.getUsualPortion(
      userId,
      widget.result.dishName,
    );

    if (usualPortion != null && mounted) {
      final multiplier = usualPortion / widget.result.portionSizeGrams;
      setState(() {
        _portionMultiplier = multiplier;
        _currentResult = widget.result.copyWithPortion(usualPortion);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✨ Using your usual portion: ${usualPortion.toInt()}g',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _updatePortion(String portionName) {
    setState(() {
      _selectedPortion = portionName;
      _portionMultiplier = _portionPresets[portionName]!;
      final newPortionGrams =
          widget.result.portionSizeGrams * _portionMultiplier;
      _currentResult = widget.result.copyWithPortion(newPortionGrams);
    });
  }

  Future<void> _addToFoodDiary() async {
    setState(() {
      _isAdding = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Save to food history service
      final foodEntry = FoodHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        foodName: _currentResult.dishName,
        calories: _currentResult.nutrition.calories.toDouble(),
        protein: _currentResult.nutrition.protein,
        carbs: _currentResult.nutrition.carbs,
        fat: _currentResult.nutrition.fat,
        fiber: _currentResult.nutrition.fiber ?? 0.0,
        sugar: _currentResult.nutrition.sugar ?? 0.0,
        weightGrams: _currentResult.portionSizeGrams,
        source: 'ai_scan',
        timestamp: DateTime.now(),
        imagePath: widget.imagePath,
        category: _currentResult.cuisine,
        notes: 'Scanned with AI - ${_currentResult.preparationMethod ?? ""}',
        scanData: {
          'confidence': _currentResult.confidence,
          'region': _currentResult.region,
          'ingredients': _currentResult.ingredients
              .map((i) => {
                    'name': i.name,
                    'weight': i.weightGrams,
                    'calories': i.calories,
                  })
              .toList(),
        },
      );

      await FoodHistoryService.addFoodEntry(foodEntry);

      // Save to local database for learning
      await _foodDatabaseService.saveFoodHistory(
        userId,
        _currentResult,
        confirmed: true,
      );

      // Update usual portion
      await _foodDatabaseService.updateUsualPortion(
        userId,
        _currentResult.dishName,
        _currentResult.portionSizeGrams,
      );

      // Increment scan count
      await _foodDatabaseService.incrementScanCount(_currentResult.dishName);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Added ${_currentResult.dishName} to your diary!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error adding to diary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to diary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food image
                    _buildFoodImage(),
                    const SizedBox(height: 24),

                    // Food name and cuisine
                    _buildFoodInfo(),
                    const SizedBox(height: 24),

                    // Nutrition summary
                    _buildNutritionSummary(),
                    const SizedBox(height: 24),

                    // Portion selector
                    _buildPortionSelector(),
                    const SizedBox(height: 24),

                    // Detailed nutrition
                    _buildDetailedNutrition(),
                    const SizedBox(height: 24),

                    // Ingredients (if available)
                    if (_currentResult.ingredients.isNotEmpty)
                      _buildIngredients(),
                  ],
                ),
              ),
            ),

            // Add button
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          const Spacer(),
          Text(
            'Confirm Food',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }

  Widget _buildFoodImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(widget.imagePath),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildFoodInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _currentResult.dishName,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildConfidenceBadge(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildInfoChip(
              Icons.restaurant,
              _currentResult.cuisine,
              Colors.orange,
            ),
            const SizedBox(width: 8),
            if (_currentResult.region != null)
              _buildInfoChip(
                Icons.location_on,
                _currentResult.region!,
                Colors.blue,
              ),
            const SizedBox(width: 8),
            if (_currentResult.preparationMethod != null)
              _buildInfoChip(
                Icons.whatshot,
                _currentResult.preparationMethod!,
                Colors.red,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfidenceBadge() {
    final confidence = _currentResult.confidence;
    Color color;
    String text;

    if (confidence >= 0.8) {
      color = Colors.green;
      text = 'High';
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      text = 'Medium';
    } else {
      color = Colors.red;
      text = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        '$text Confidence',
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutritionItem(
            '🔥',
            '${_currentResult.nutrition.calories}',
            'Calories',
          ),
          _buildNutritionItem(
            '💪',
            '${_currentResult.nutrition.protein.toInt()}g',
            'Protein',
          ),
          _buildNutritionItem(
            '🍚',
            '${_currentResult.nutrition.carbs.toInt()}g',
            'Carbs',
          ),
          _buildNutritionItem(
            '🥑',
            '${_currentResult.nutrition.fat.toInt()}g',
            'Fat',
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPortionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adjust Portion Size',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _portionPresets.keys.map((portionName) {
            final isSelected = _selectedPortion == portionName;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => _updatePortion(portionName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.purple[600]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      portionName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '${_currentResult.portionSizeGrams.toInt()}g',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.purple[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedNutrition() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Breakdown',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildNutritionRow(
            'Calories',
            '${_currentResult.nutrition.calories} kcal',
            Icons.local_fire_department,
            Colors.orange,
          ),
          _buildNutritionRow(
            'Protein',
            '${_currentResult.nutrition.protein.toInt()}g',
            Icons.fitness_center,
            Colors.red,
          ),
          _buildNutritionRow(
            'Carbs',
            '${_currentResult.nutrition.carbs.toInt()}g',
            Icons.grass,
            Colors.green,
          ),
          _buildNutritionRow(
            'Fat',
            '${_currentResult.nutrition.fat.toInt()}g',
            Icons.opacity,
            Colors.blue,
          ),
          if (_currentResult.nutrition.fiber != null)
            _buildNutritionRow(
              'Fiber',
              '${_currentResult.nutrition.fiber!.toInt()}g',
              Icons.waves,
              Colors.teal,
            ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._currentResult.ingredients.map((ingredient) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ingredient.name} (${ingredient.weightGrams.toInt()}g)',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
                Text(
                  '${ingredient.calories} cal',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isAdding ? null : _addToFoodDiary,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple[600],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isAdding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Add to Food Diary',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

