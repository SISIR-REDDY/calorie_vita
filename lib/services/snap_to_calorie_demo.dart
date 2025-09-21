import 'dart:io';
import 'dart:convert';
import 'snap_to_calorie_service.dart';
import 'food_scanner_pipeline.dart';

/// Demo class showing how to use the snap-to-calorie pipeline
class SnapToCalorieDemo {
  /// Example usage of the snap-to-calorie service
  static Future<void> demonstrateSnapToCalorie(File imageFile) async {
    print('🍽️ Starting snap-to-calorie demonstration...');
    
    try {
      // Method 1: Direct snap-to-calorie processing with AI suggestions
      print('\n📸 Method 1: Direct snap-to-calorie processing with AI suggestions');
      final snapResult = await SnapToCalorieService.processFoodImage(
        imageFile,
        userProfile: 'Health-conscious individual',
        userGoals: {'goal': 'weight_management', 'target_calories': 2000},
        dietaryRestrictions: ['vegetarian'],
        includeSuggestions: true,
      );
      
      if (snapResult.isSuccessful) {
        print('✅ Success! Found ${snapResult.items.length} food item(s)');
        print('📊 Total calories: ${snapResult.totalCalories.toStringAsFixed(1)} kcal');
        print('🎯 Overall confidence: ${(snapResult.overallConfidence * 100).toStringAsFixed(1)}%');
        print('💡 Recommendation: ${snapResult.recommendedAction}');
        print('📝 Notes: ${snapResult.notes}');
        
        // Display AI suggestions if available
        if (snapResult.aiSuggestions != null) {
          print('\n🤖 AI Suggestions:');
          print('📋 Overall Recommendation: ${snapResult.aiSuggestions!.overallRecommendation}');
          print('🎯 Suggestion Confidence: ${(snapResult.aiSuggestions!.confidence * 100).toStringAsFixed(1)}%');
          
          if (snapResult.aiSuggestions!.healthSuggestions.isNotEmpty) {
            print('\n💚 Health Suggestions:');
            for (final suggestion in snapResult.aiSuggestions!.healthSuggestions) {
              print('   ${suggestion.icon} ${suggestion.title}: ${suggestion.description}');
            }
          }
          
          if (snapResult.aiSuggestions!.alternativeSuggestions.isNotEmpty) {
            print('\n🔄 Alternative Suggestions:');
            for (final alt in snapResult.aiSuggestions!.alternativeSuggestions) {
              print('   🥗 ${alt.name}: ${alt.description}');
              print('      💡 ${alt.preparationTip}');
            }
          }
          
          if (snapResult.aiSuggestions!.portionAdvice.isNotEmpty) {
            print('\n⚖️ Portion Advice:');
            for (final advice in snapResult.aiSuggestions!.portionAdvice) {
              print('   📏 ${advice.ingredient}: ${advice.recommendation}');
              print('      👀 Visual guide: ${advice.visualGuide}');
            }
          }
        }
        
        // Print detailed JSON output as specified
        print('\n📋 Structured JSON Output:');
        print(JsonEncoder.withIndent('  ').convert(snapResult.toJson()));
      } else {
        print('❌ Failed to process image: ${snapResult.notes}');
      }

      // Method 2: Using the integrated pipeline
      print('\n🔧 Method 2: Using integrated food scanner pipeline');
      final pipelineResult = await FoodScannerPipeline.processFoodImage(imageFile);
      
      if (pipelineResult.success) {
        print('✅ Pipeline success!');
        print('🍽️ Food: ${pipelineResult.recognitionResult?.foodName}');
        print('⚖️ Weight: ${pipelineResult.portionResult?.estimatedWeight.toStringAsFixed(1)}g');
        print('🔥 Calories: ${pipelineResult.nutritionInfo?.calories.toStringAsFixed(1)} kcal');
        
        // Access enhanced snap-to-calorie data
        if (pipelineResult.snapToCalorieResult != null) {
          print('🎯 Enhanced confidence: ${(pipelineResult.snapToCalorieResult!.overallConfidence * 100).toStringAsFixed(1)}%');
        }
      } else {
        print('❌ Pipeline failed: ${pipelineResult.error}');
      }

      // Method 3: Direct JSON output with AI suggestions
      print('\n📄 Method 3: Direct JSON output with AI suggestions');
      final jsonOutput = await FoodScannerPipeline.processSnapToCalorie(
        imageFile,
        userProfile: 'Fitness enthusiast',
        userGoals: {'goal': 'muscle_gain', 'target_calories': 2500},
        dietaryRestrictions: ['no_pork', 'low_sodium'],
        includeSuggestions: true,
      );
      
      if (jsonOutput != null) {
        print('✅ JSON output generated successfully');
        print('📊 Items found: ${jsonOutput['items']?.length ?? 0}');
        print('🎯 Overall confidence: ${((jsonOutput['overall_confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%');
        print('💡 Action: ${jsonOutput['recommended_action']}');
        
        // Check for AI suggestions in JSON
        if (jsonOutput['ai_suggestions'] != null) {
          final suggestions = jsonOutput['ai_suggestions'];
          print('🤖 AI Suggestions included:');
          print('   📋 Overall: ${suggestions['overall_recommendation']}');
          print('   💚 Health suggestions: ${suggestions['health_suggestions']?.length ?? 0}');
          print('   🔄 Alternatives: ${suggestions['alternative_suggestions']?.length ?? 0}');
          print('   ⚖️ Portion advice: ${suggestions['portion_advice']?.length ?? 0}');
        }
      } else {
        print('❌ Failed to generate JSON output');
      }

    } catch (e) {
      print('❌ Demo failed with error: $e');
    }
  }

  /// Test with comprehensive ingredient-level analysis
  static Future<void> testIngredientLevelAnalysis() async {
    print('🔍 Testing enhanced snap-to-calorie with ingredient-level analysis...');
    
    final testCases = [
      // Ingredient-Level Analysis Examples
      {
        'dish': 'Masala Dosa',
        'ingredients': [
          'Dosa crepe (rice flour batter)',
          'Potato filling (boiled potatoes)',
          'Onion pieces',
          'Cilantro leaves',
          'Coconut chutney',
          'Sambar (lentil soup)'
        ],
        'expected_total_calories': '250-300',
        'description': 'Each ingredient analyzed separately for accurate calorie count'
      },
      {
        'dish': 'Butter Chicken',
        'ingredients': [
          'Chicken pieces',
          'Tomato sauce',
          'Cream',
          'Butter/Ghee',
          'Onion pieces',
          'Cashews',
          'Spices'
        ],
        'expected_total_calories': '350-450',
        'description': 'Individual analysis of protein, sauce, and garnish components'
      },
      {
        'dish': 'Biryani',
        'ingredients': [
          'Rice grains',
          'Chicken pieces',
          'Onion slices',
          'Cashews',
          'Raisins',
          'Saffron',
          'Oil/Ghee',
          'Spices'
        ],
        'expected_total_calories': '400-500',
        'description': 'Each grain, protein piece, and garnish counted separately'
      },
      {
        'dish': 'Pizza Margherita',
        'ingredients': [
          'Bread base',
          'Tomato sauce',
          'Cheese',
          'Basil leaves',
          'Oil'
        ],
        'expected_total_calories': '250-350',
        'description': 'Base, sauce, toppings, and garnishes analyzed individually'
      },
      {
        'dish': 'Samosa',
        'ingredients': [
          'Pastry shell',
          'Potato filling',
          'Onion pieces',
          'Spices',
          'Oil (for frying)'
        ],
        'expected_total_calories': '200-250',
        'description': 'Shell, filling, and cooking oil analyzed separately'
      },
    ];

    for (final testCase in testCases) {
      print('\n🍽️ Dish: ${testCase['dish']}');
      print('📝 Description: ${testCase['description']}');
      print('🔥 Expected total calories: ${testCase['expected_total_calories']} kcal');
      print('');
      print('🔍 Ingredient-Level Analysis:');
      final ingredients = testCase['ingredients'] as List<String>;
      for (final ingredient in ingredients) {
        print('   • $ingredient');
      }
      print('');
      print('📊 Analysis Method:');
      print('   • Each ingredient identified and measured separately');
      print('   • Individual portion estimation for each component');
      print('   • Ingredient-specific nutrition values applied');
      print('   • Total calories = sum of all ingredient calories');
      print('   • Uncertainty: ±20-35% per ingredient');
    }
  }

  /// Show the complete pipeline flow
  static void showPipelineFlow() {
    print('🔄 Snap-to-Calorie Pipeline Flow:');
    print('');
    print('1️⃣ IDENTIFY:');
    print('   • OpenRouter AI vision analyzes image');
    print('   • Identifies visible food items');
    print('   • Returns primary + 2 alternatives with confidence');
    print('   • Focuses on Indian dishes and variants');
    print('');
    print('2️⃣ MEASURE:');
    print('   • Estimates volume (cm³) using:');
    print('     - Depth map (if available)');
    print('     - Reference object scaling');
    print('     - Monocular priors (fallback)');
    print('   • Converts to mass using density priors');
    print('   • Includes ± uncertainty');
    print('');
    print('3️⃣ CALORIE:');
    print('   • Maps food to nutrition DB (kcal/100g)');
    print('   • Calculates: (mass_g × kcal_per_100g / 100)');
    print('   • Propagates uncertainty');
    print('');
    print('4️⃣ OUTPUT:');
    print('   • Returns structured JSON format');
    print('   • Includes all measurements with uncertainties');
    print('   • Provides confidence and recommendations');
    print('   • Machine-readable for integration');
  }

  /// Show density priors used in calculations
  static void showDensityPriors() {
    print('⚖️ Food Density Priors (g/cm³):');
    print('');
    
    final densityPriors = {
      'Rice': 0.8,
      'Curry': 1.0,
      'Fried Snacks': 0.6,
      'Bread (Roti/Naan)': 0.3,
      'Meat/Chicken': 1.05,
      'Vegetables': 0.95,
      'Fruits': 0.9,
      'Dairy (Paneer)': 1.03,
      'Nuts': 0.7,
      'Oil': 0.92,
      'Soup': 1.0,
      'Dal': 1.05,
      'Default': 1.0,
    };

    for (final entry in densityPriors.entries) {
      print('   ${entry.key}: ${entry.value} g/cm³');
    }
    
    print('');
    print('💡 These priors are used to convert volume estimates to mass');
    print('📏 Volume × Density = Mass (grams)');
  }

  /// Show comprehensive nutrition database values
  static void showNutritionDatabase() {
    print('🥗 Enhanced Nutrition Database (kcal per 100g):');
    print('');
    
    final nutritionCategories = {
      'Rice & Grains': {
        'Rice': 130.0, 'Basmati': 130.0, 'Biryani': 140.0, 'Pulao': 135.0, 'Khichdi': 120.0
      },
      'Breads & Rotis': {
        'Roti': 297.0, 'Naan': 310.0, 'Paratha': 326.0, 'Puri': 364.0, 'Bhature': 348.0
      },
      'Dals & Legumes': {
        'Dal': 116.0, 'Dal Makhani': 180.0, 'Sambar': 85.0, 'Rajma': 127.0, 'Chole': 164.0
      },
      'Curries & Vegetables': {
        'Curry': 120.0, 'Paneer': 265.0, 'Butter Chicken': 350.0, 'Mixed Vegetables': 80.0
      },
      'South Indian': {
        'Dosa': 168.0, 'Masala Dosa': 250.0, 'Idli': 39.0, 'Vada': 217.0, 'Upma': 140.0
      },
      'Street Food': {
        'Samosa': 308.0, 'Pakora': 250.0, 'Pav Bhaji': 250.0, 'Vada Pav': 280.0
      },
      'Sweets': {
        'Gulab Jamun': 321.0, 'Rasgulla': 186.0, 'Barfi': 400.0, 'Kheer': 150.0
      },
      'International': {
        'Pizza': 266.0, 'Burger': 295.0, 'Pasta': 131.0, 'Sandwich': 250.0
      },
      'Fruits & Nuts': {
        'Apple': 52.0, 'Banana': 89.0, 'Almonds': 579.0, 'Cashews': 553.0
      },
    };

    for (final category in nutritionCategories.entries) {
      print('📂 ${category.key}:');
      for (final item in category.value.entries) {
        print('   ${item.key}: ${item.value.toStringAsFixed(0)} kcal/100g');
      }
      print('');
    }
    
    print('💡 Formula: Total Calories = (Mass_g × kcal_per_100g) / 100');
    print('🔍 Database includes ${nutritionCategories.values.fold(0, (sum, cat) => sum + cat.length)} food items');
    print('🌍 Covers Indian regional cuisines + International foods');
  }

  /// Demo AI suggestions feature
  static void demoAISuggestions() async {
    print('🤖 AI Suggestions Feature Demo:');
    print('');
    
    print('📋 Types of AI Suggestions Generated:');
    print('');
    
    print('💚 Health Suggestions:');
    print('   • Health benefits of ingredients');
    print('   • Potential health concerns');
    print('   • Nutrient balance analysis');
    print('   • Portion control recommendations');
    print('   • Meal timing advice');
    print('');
    
    print('🥗 Nutrition Advice:');
    print('   • Macronutrient balance (protein, carbs, fats)');
    print('   • Micronutrient content analysis');
    print('   • Fiber and vitamin content');
    print('   • Nutritional gaps identification');
    print('   • Supplement recommendations');
    print('');
    
    print('🔄 Alternative Suggestions:');
    print('   • Healthier versions of the same dish');
    print('   • Lower-calorie alternatives');
    print('   • More nutritious ingredient swaps');
    print('   • Vegetarian/vegan options');
    print('   • Traditional vs modern preparations');
    print('');
    
    print('⚖️ Portion Advice:');
    print('   • Current portion assessment');
    print('   • Ideal portion recommendations');
    print('   • Portion control techniques');
    print('   • Visual portion guides');
    print('   • Meal planning tips');
    print('');
    
    print('🍽️ Meal Balance Advice:');
    print('   • Current meal balance assessment');
    print('   • Missing food groups identification');
    print('   • Suggested additions for balance');
    print('   • Meal timing recommendations');
    print('   • Combination with other meals');
    print('');
    
    print('🎯 Personalization Features:');
    print('   • User profile consideration');
    print('   • Goal-based recommendations (weight loss/gain/maintenance)');
    print('   • Dietary restrictions compliance');
    print('   • Calorie target alignment');
    print('   • Health condition considerations');
    print('');
    
    print('📊 Example Suggestion Output:');
    print('   {');
    print('     "health_suggestions": [');
    print('       {');
    print('         "type": "benefit",');
    print('         "title": "High Protein Content",');
    print('         "description": "This meal provides excellent protein for muscle building",');
    print('         "priority": "high",');
    print('         "icon": "💪"');
    print('       }');
    print('     ],');
    print('     "alternative_suggestions": [');
    print('       {');
    print('         "type": "healthier",');
    print('         "name": "Grilled Chicken with Quinoa",');
    print('         "description": "Lower calorie, higher fiber alternative",');
    print('         "calorie_reduction": "150 kcal",');
    print('         "benefits": ["More fiber", "Lower fat", "Better protein ratio"]');
    print('       }');
    print('     ],');
    print('     "overall_recommendation": "Well-balanced meal with room for improvement"');
    print('   }');
  }

  /// Show enhanced capabilities summary
  static void showEnhancedCapabilities() {
    print('🚀 Enhanced Snap-to-Calorie Capabilities:');
    print('');
    
    print('🔍 INGREDIENT-LEVEL ANALYSIS:');
    print('   • Identifies EVERY visible ingredient separately');
    print('   • Breaks down complex dishes into individual components');
    print('   • Includes garnishes, sauces, and accompaniments');
    print('   • Analyzes proteins, carbs, vegetables, and condiments');
    print('   • Example: Biryani → rice + chicken + onions + cashews + oil');
    print('');
    
    print('📊 Comprehensive Database:');
    print('   • 150+ individual ingredients with specific nutrition values');
    print('   • 100+ complete dishes (fallback for complex items)');
    print('   • Proteins, carbs, vegetables, sauces, garnishes');
    print('   • Indian + International ingredient coverage');
    print('   • Regional name variations (pyaaz/onion, dhania/cilantro)');
    print('');
    
    print('🎯 Enhanced Recognition:');
    print('   • Ingredient-focused AI vision prompts');
    print('   • Separates main components from garnishes');
    print('   • Identifies cooking methods (fried, steamed, raw)');
    print('   • Multiple alternative identifications per ingredient');
    print('   • Confidence scoring for each ingredient');
    print('');
    
    print('⚖️ Precise Portion Estimation:');
    print('   • Ingredient-specific portion heuristics');
    print('   • Individual volume/mass calculation per component');
    print('   • Ingredient-specific density priors');
    print('   • Uncertainty propagation per ingredient');
    print('   • Total calories = sum of all ingredient calories');
    print('');
    
    print('🔍 Smart Ingredient Matching:');
    print('   • Prioritizes ingredient database over dish database');
    print('   • Fuzzy matching for ingredient name variations');
    print('   • Category-based fallbacks for unknown ingredients');
    print('   • Multi-pass matching (exact → contains → fuzzy → category)');
    print('   • Handles regional names and spelling variations');
    print('');
    
    print('📈 Expected Accuracy:');
    print('   • High confidence (0.8-0.9): Common ingredients');
    print('   • Medium confidence (0.7-0.8): Specialty ingredients');
    print('   • Good fallback: Category-based estimation');
    print('   • Uncertainty: ±20-35% per ingredient');
    print('   • More accurate totals through ingredient-level analysis');
    print('');
    
    print('🤖 AI SUGGESTIONS:');
    print('   • Personalized health and nutrition recommendations');
    print('   • Alternative food suggestions');
    print('   • Portion control advice');
    print('   • Meal balance recommendations');
    print('   • Goal-based customization');
    print('   • Dietary restriction compliance');
    print('   • Real-time contextual advice');
  }
}
