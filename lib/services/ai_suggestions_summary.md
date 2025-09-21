# AI Suggestions Feature - Post-Scan Recommendations

## 🤖 **Enhanced Snap-to-Calorie with AI-Powered Suggestions**

The snap-to-calorie pipeline now includes comprehensive AI-powered suggestions that provide personalized recommendations after food scanning, making it a complete nutrition analysis and guidance system.

## 🚀 **Key Features**

### 1. **Comprehensive Suggestion Types**

**💚 Health Suggestions**
- Health benefits of ingredients
- Potential health concerns
- Nutrient balance analysis
- Portion control recommendations
- Meal timing advice

**🥗 Nutrition Advice**
- Macronutrient balance (protein, carbs, fats)
- Micronutrient content analysis
- Fiber and vitamin content
- Nutritional gaps identification
- Supplement recommendations

**🔄 Alternative Suggestions**
- Healthier versions of the same dish
- Lower-calorie alternatives
- More nutritious ingredient swaps
- Vegetarian/vegan options
- Traditional vs modern preparations

**⚖️ Portion Advice**
- Current portion assessment
- Ideal portion recommendations
- Portion control techniques
- Visual portion guides (hand, cup, plate references)
- Meal planning tips

**🍽️ Meal Balance Advice**
- Current meal balance assessment
- Missing food groups identification
- Suggested additions for balance
- Meal timing recommendations
- Combination with other meals

### 2. **Personalization Features**

**User Profile Integration**
- Health-conscious individual
- Fitness enthusiast
- Weight management goals
- Muscle building targets
- General wellness

**Goal-Based Recommendations**
- Weight loss strategies
- Muscle gain optimization
- Weight maintenance
- Calorie target alignment
- Nutritional goal achievement

**Dietary Restrictions Compliance**
- Vegetarian/Vegan options
- Allergen considerations
- Low-sodium recommendations
- Gluten-free alternatives
- Religious dietary requirements

## 📊 **Enhanced JSON Output**

The JSON output now includes comprehensive AI suggestions:

```json
{
  "items": [
    {
      "id": "food_uuid",
      "name": "chicken_pieces",
      "mass_g": {"value": 120.0},
      "kcal_total": {"value": 198.0},
      "confidence": 0.85
    }
  ],
  "overall_confidence": 0.80,
  "recommended_action": "accept",
  "notes": "High confidence identification",
  "ai_suggestions": {
    "health_suggestions": [
      {
        "type": "benefit",
        "title": "High Protein Content",
        "description": "This meal provides excellent protein for muscle building and recovery",
        "priority": "high",
        "icon": "💪"
      }
    ],
    "nutrition_advice": [
      {
        "category": "macronutrients",
        "title": "Balanced Macronutrients",
        "description": "Good balance of protein, carbs, and healthy fats",
        "importance": "high",
        "suggestion": "Consider adding more vegetables for micronutrients"
      }
    ],
    "alternative_suggestions": [
      {
        "type": "healthier",
        "name": "Grilled Chicken with Quinoa",
        "description": "Lower calorie, higher fiber alternative with same protein content",
        "calorie_reduction": "150 kcal",
        "benefits": ["More fiber", "Lower fat", "Better protein ratio"],
        "preparation_tip": "Marinate chicken in herbs and grill instead of frying"
      }
    ],
    "portion_advice": [
      {
        "ingredient": "chicken_pieces",
        "current_assessment": "Just right",
        "recommendation": "120g portion is ideal for your goals",
        "technique": "Use palm-sized portion as visual guide",
        "visual_guide": "Size of your palm"
      }
    ],
    "meal_balance_advice": [
      {
        "category": "vegetables",
        "current_status": "deficient",
        "recommendation": "Add more vegetables for fiber and vitamins",
        "reason": "Current meal lacks sufficient vegetables for balanced nutrition",
        "examples": ["Steamed broccoli", "Mixed salad", "Grilled vegetables"]
      }
    ],
    "overall_recommendation": "Well-balanced meal with room for improvement. Consider adding more vegetables and reducing oil for optimal nutrition.",
    "confidence": 0.85
  }
}
```

## 🔧 **Technical Implementation**

### Enhanced Pipeline Flow
1. **IDENTIFY** - Ingredient-level food recognition
2. **MEASURE** - Individual portion estimation
3. **CALORIE** - Precise calorie calculation
4. **SUGGEST** - AI-powered recommendations ✨ **NEW**
5. **OUTPUT** - Complete analysis with suggestions

### AI Integration
- **OpenRouter API** for suggestion generation
- **Context-aware prompts** based on scan results
- **User profile integration** for personalization
- **Goal-based filtering** of recommendations
- **Dietary restriction compliance**

### Suggestion Generation Process
1. **Context Building** - Compile scan results + user profile
2. **Parallel Processing** - Generate all suggestion types simultaneously
3. **Quality Filtering** - Remove low-confidence suggestions
4. **Personalization** - Apply user goals and restrictions
5. **Ranking** - Prioritize suggestions by importance

## 🎯 **Usage Examples**

### Basic Usage with Suggestions
```dart
final result = await SnapToCalorieService.processFoodImage(
  imageFile,
  userProfile: 'Health-conscious individual',
  userGoals: {'goal': 'weight_management', 'target_calories': 2000},
  dietaryRestrictions: ['vegetarian'],
  includeSuggestions: true,
);

// Access suggestions
if (result.aiSuggestions != null) {
  final suggestions = result.aiSuggestions!;
  print('Overall: ${suggestions.overallRecommendation}');
  
  for (final healthSuggestion in suggestions.healthSuggestions) {
    print('${healthSuggestion.icon} ${healthSuggestion.title}');
  }
}
```

### Integrated Pipeline Usage
```dart
final pipelineResult = await FoodScannerPipeline.processFoodImage(
  imageFile,
  userProfile: userProfile,
  userGoals: userGoals,
);

// Suggestions automatically included
final snapResult = pipelineResult.snapToCalorieResult;
if (snapResult?.aiSuggestions != null) {
  // Display AI suggestions in UI
}
```

### Direct JSON Output
```dart
final jsonOutput = await FoodScannerPipeline.processSnapToCalorie(
  imageFile,
  userProfile: 'Fitness enthusiast',
  userGoals: {'goal': 'muscle_gain'},
  includeSuggestions: true,
);

// JSON includes complete analysis + suggestions
final suggestions = jsonOutput?['ai_suggestions'];
```

## 📈 **Benefits**

### For Users
1. **Personalized Guidance** - Tailored to individual goals and restrictions
2. **Educational Value** - Learn about nutrition and healthy eating
3. **Practical Advice** - Actionable suggestions for improvement
4. **Goal Achievement** - Aligned with weight management and fitness goals
5. **Dietary Compliance** - Respects dietary restrictions and preferences

### For Developers
1. **Rich Data** - Comprehensive analysis beyond just calories
2. **User Engagement** - Interactive and helpful recommendations
3. **Differentiation** - Advanced feature beyond basic calorie counting
4. **Scalability** - Easy to extend with new suggestion types
5. **Integration Ready** - Clean API for UI implementation

## 🔮 **Future Enhancements**

- **Recipe Suggestions** - Generate recipes based on scanned ingredients
- **Meal Planning** - Weekly meal plan recommendations
- **Progress Tracking** - Track nutrition goals over time
- **Social Features** - Share healthy meal suggestions
- **Integration** - Connect with fitness apps and health platforms

This AI suggestions feature transforms the snap-to-calorie pipeline from a simple calorie counter into a comprehensive nutrition analysis and guidance system, providing users with personalized, actionable recommendations for healthier eating habits.
