class CalorieService {
  static final Map<String, int> _foodCalories = {
    // Fruits
    'apple': 95,
    'banana': 105,
    'orange': 62,
    'strawberry': 4,
    'grape': 3,
    'watermelon': 30,
    'mango': 202,
    'pineapple': 83,
    'peach': 59,
    'pear': 102,
    
    // Vegetables
    'carrot': 25,
    'broccoli': 31,
    'spinach': 7,
    'lettuce': 5,
    'tomato': 22,
    'cucumber': 8,
    'onion': 44,
    'potato': 161,
    'sweet potato': 103,
    'corn': 88,
    
    // Proteins
    'chicken breast': 165,
    'salmon': 208,
    'tuna': 184,
    'beef': 250,
    'pork': 242,
    'eggs': 78,
    'tofu': 76,
    'beans': 127,
    'lentils': 116,
    'chickpeas': 164,
    
    // Grains
    'rice': 130,
    'bread': 79,
    'pasta': 131,
    'oatmeal': 150,
    'quinoa': 120,
    'wheat': 340,
    'cornmeal': 110,
    
    // Dairy
    'milk': 103,
    'cheese': 113,
    'yogurt': 59,
    'butter': 102,
    'cream': 52,
    
    // Nuts and Seeds
    'almonds': 164,
    'peanuts': 166,
    'walnuts': 185,
    'cashews': 157,
    'sunflower seeds': 164,
    'chia seeds': 58,
    
    // Common Dishes
    'pizza': 266,
    'burger': 354,
    'sandwich': 200,
    'salad': 100,
    'soup': 150,
    'pasta dish': 300,
    'rice dish': 250,
    'stir fry': 350,
    'curry': 400,
    'sushi': 200,
    'taco': 150,
    'burrito': 300,
    'lasagna': 350,
    'spaghetti': 250,
    'chicken curry': 450,
    'beef stew': 350,
    'fish and chips': 500,
    'chicken wings': 300,
    'steak': 400,
    'grilled chicken': 200,
    
    // Snacks
    'chips': 150,
    'popcorn': 31,
    'cookies': 150,
    'cake': 250,
    'ice cream': 137,
    'chocolate': 150,
    'candy': 100,
    'nuts': 160,
    'trail mix': 150,
    'granola bar': 120,
    
    // Beverages
    'coffee': 2,
    'tea': 1,
    'juice': 120,
    'soda': 150,
    'beer': 153,
    'wine': 125,
    'smoothie': 200,
    'milkshake': 300,
  };

  // Get calorie estimate for a food item
  static int getCalorieEstimate(String foodName) {
    final normalizedName = foodName.toLowerCase().trim();
    
    // Direct match
    if (_foodCalories.containsKey(normalizedName)) {
      return _foodCalories[normalizedName]!;
    }
    
    // Partial match
    for (final entry in _foodCalories.entries) {
      if (normalizedName.contains(entry.key) || entry.key.contains(normalizedName)) {
        return entry.value;
      }
    }
    
    // Default estimate based on food type
    if (normalizedName.contains('fruit') || normalizedName.contains('apple') || 
        normalizedName.contains('banana') || normalizedName.contains('orange')) {
      return 80;
    }
    
    if (normalizedName.contains('vegetable') || normalizedName.contains('salad') || 
        normalizedName.contains('carrot') || normalizedName.contains('broccoli')) {
      return 50;
    }
    
    if (normalizedName.contains('meat') || normalizedName.contains('chicken') || 
        normalizedName.contains('beef') || normalizedName.contains('fish')) {
      return 200;
    }
    
    if (normalizedName.contains('bread') || normalizedName.contains('pasta') || 
        normalizedName.contains('rice') || normalizedName.contains('grain')) {
      return 150;
    }
    
    if (normalizedName.contains('dessert') || normalizedName.contains('cake') || 
        normalizedName.contains('cookie') || normalizedName.contains('sweet')) {
      return 200;
    }
    
    // Default estimate
    return 150;
  }

  // Get all available food names
  static List<String> getAllFoodNames() {
    return _foodCalories.keys.toList()..sort();
  }

  // Search for foods by name
  static List<String> searchFoods(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    return _foodCalories.keys
        .where((food) => food.toLowerCase().contains(normalizedQuery))
        .toList();
  }
} 