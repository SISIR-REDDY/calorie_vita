import 'dart:math';

/// Service for generating dynamic icons based on user prompts
class DynamicIconService {
  static final DynamicIconService _instance = DynamicIconService._internal();
  factory DynamicIconService() => _instance;
  DynamicIconService._internal();

  final Random _random = Random();

  // Icon categories with keywords and corresponding emojis
  final Map<String, List<String>> _iconCategories = {
    'health': ['💊', '🏥', '❤️', '🩺', '💉', '🦠', '🧬', '🩹', '💊', '🏥'],
    'fitness': ['🏃', '💪', '🏋️', '🚴', '🏊', '🤸', '🧘', '🏃‍♀️', '🏃‍♂️', '💪'],
    'nutrition': ['🥗', '🍎', '🥕', '🥦', '🍇', '🥑', '🍌', '🥒', '🍅', '🥜'],
    'water': ['💧', '🚰', '🥤', '💦', '🌊', '💧', '🚰', '🥤', '💦', '🌊'],
    'sleep': ['😴', '🛌', '🌙', '💤', '😴', '🛌', '🌙', '💤', '😴', '🛌'],
    'work': ['💼', '💻', '📊', '📈', '📝', '📋', '💼', '💻', '📊', '📈'],
    'study': ['📚', '✏️', '📝', '🎓', '📖', '📚', '✏️', '📝', '🎓', '📖'],
    'cooking': ['👨‍🍳', '🍳', '🥘', '🍲', '👩‍🍳', '👨‍🍳', '🍳', '🥘', '🍲', '👩‍🍳'],
    'shopping': ['🛒', '🛍️', '💳', '🏪', '🛒', '🛍️', '💳', '🏪', '🛒', '🛍️'],
    'cleaning': ['🧹', '🧽', '🧼', '✨', '🧹', '🧽', '🧼', '✨', '🧹', '🧽'],
    'social': ['👥', '🎉', '🎊', '👫', '👥', '🎉', '🎊', '👫', '👥', '🎉'],
    'travel': ['✈️', '🚗', '🚌', '🚂', '✈️', '🚗', '🚌', '🚂', '✈️', '🚗'],
    'entertainment': ['🎬', '🎵', '🎮', '📺', '🎬', '🎵', '🎮', '📺', '🎬', '🎵'],
    'technology': ['📱', '💻', '⌚', '🔌', '📱', '💻', '⌚', '🔌', '📱', '💻'],
    'nature': ['🌱', '🌿', '🌳', '🌸', '🌱', '🌿', '🌳', '🌸', '🌱', '🌿'],
    'pets': ['🐕', '🐱', '🐰', '🐦', '🐕', '🐱', '🐰', '🐦', '🐕', '🐱'],
    'hobbies': ['🎨', '🎭', '🎪', '🎯', '🎨', '🎭', '🎪', '🎯', '🎨', '🎭'],
    'finance': ['💰', '💳', '📊', '💵', '💰', '💳', '📊', '💵', '💰', '💳'],
    'default': ['✅', '📋', '📝', '🎯', '⭐', '✅', '📋', '📝', '🎯', '⭐'],
  };

  // Keywords for each category
  final Map<String, List<String>> _categoryKeywords = {
    'health': ['health', 'medicine', 'doctor', 'hospital', 'medical', 'wellness', 'cure', 'treatment', 'therapy', 'recovery'],
    'fitness': ['exercise', 'workout', 'gym', 'run', 'walk', 'jog', 'sport', 'training', 'cardio', 'strength', 'yoga', 'pilates'],
    'nutrition': ['eat', 'food', 'meal', 'diet', 'nutrition', 'calories', 'protein', 'vitamin', 'fruit', 'vegetable', 'healthy'],
    'water': ['water', 'drink', 'hydrate', 'thirst', 'liquid', 'beverage', 'glass', 'bottle'],
    'sleep': ['sleep', 'rest', 'bed', 'nap', 'dream', 'tired', 'exhausted', 'bedtime'],
    'work': ['work', 'job', 'office', 'meeting', 'project', 'deadline', 'business', 'career', 'professional'],
    'study': ['study', 'learn', 'read', 'book', 'education', 'school', 'university', 'course', 'exam', 'homework'],
    'cooking': ['cook', 'recipe', 'kitchen', 'bake', 'prepare', 'meal', 'dinner', 'lunch', 'breakfast'],
    'shopping': ['shop', 'buy', 'purchase', 'store', 'mall', 'grocery', 'shopping', 'retail'],
    'cleaning': ['clean', 'tidy', 'organize', 'wash', 'vacuum', 'dust', 'mop', 'housework'],
    'social': ['friend', 'family', 'party', 'social', 'meet', 'gather', 'celebrate', 'hangout'],
    'travel': ['travel', 'trip', 'vacation', 'journey', 'flight', 'hotel', 'destination', 'explore'],
    'entertainment': ['movie', 'music', 'game', 'fun', 'entertainment', 'show', 'concert', 'theater'],
    'technology': ['phone', 'computer', 'tech', 'digital', 'app', 'software', 'device', 'gadget'],
    'nature': ['garden', 'plant', 'outdoor', 'nature', 'park', 'hiking', 'camping', 'environment'],
    'pets': ['pet', 'dog', 'cat', 'animal', 'veterinary', 'walk', 'feed', 'care'],
    'hobbies': ['hobby', 'craft', 'art', 'music', 'dance', 'paint', 'draw', 'create'],
    'finance': ['money', 'budget', 'save', 'invest', 'bank', 'finance', 'payment', 'expense'],
  };

  /// Generate a dynamic icon based on the task prompt
  String generateIcon(String taskPrompt) {
    final lowerPrompt = taskPrompt.toLowerCase();
    
    // Find the best matching category
    String bestCategory = 'default';
    int maxMatches = 0;
    
    for (final category in _categoryKeywords.keys) {
      final keywords = _categoryKeywords[category]!;
      int matches = 0;
      
      for (final keyword in keywords) {
        if (lowerPrompt.contains(keyword)) {
          matches++;
        }
      }
      
      if (matches > maxMatches) {
        maxMatches = matches;
        bestCategory = category;
      }
    }
    
    // Get random icon from the best matching category
    final categoryIcons = _iconCategories[bestCategory] ?? _iconCategories['default']!;
    final randomIndex = _random.nextInt(categoryIcons.length);
    
    return categoryIcons[randomIndex];
  }

  /// Generate multiple icons for variety (useful for suggestions)
  List<String> generateMultipleIcons(String taskPrompt, {int count = 3}) {
    final icons = <String>{};
    final lowerPrompt = taskPrompt.toLowerCase();
    
    // Find all matching categories
    final matchingCategories = <String>[];
    for (final category in _categoryKeywords.keys) {
      final keywords = _categoryKeywords[category]!;
      for (final keyword in keywords) {
        if (lowerPrompt.contains(keyword)) {
          matchingCategories.add(category);
          break;
        }
      }
    }
    
    // If no specific matches, use default
    if (matchingCategories.isEmpty) {
      matchingCategories.add('default');
    }
    
    // Generate icons from matching categories
    while (icons.length < count) {
      final randomCategory = matchingCategories[_random.nextInt(matchingCategories.length)];
      final categoryIcons = _iconCategories[randomCategory] ?? _iconCategories['default']!;
      final randomIcon = categoryIcons[_random.nextInt(categoryIcons.length)];
      icons.add(randomIcon);
    }
    
    return icons.toList();
  }

  /// Get icon suggestions for a task prompt
  List<String> getIconSuggestions(String taskPrompt, {int count = 5}) {
    return generateMultipleIcons(taskPrompt, count: count);
  }

  /// Check if a task prompt matches a specific category
  bool matchesCategory(String taskPrompt, String category) {
    final lowerPrompt = taskPrompt.toLowerCase();
    final keywords = _categoryKeywords[category] ?? [];
    
    return keywords.any((keyword) => lowerPrompt.contains(keyword));
  }

  /// Get all available categories
  List<String> getAvailableCategories() {
    return _categoryKeywords.keys.toList();
  }

  /// Get keywords for a specific category
  List<String> getCategoryKeywords(String category) {
    return _categoryKeywords[category] ?? [];
  }
}
