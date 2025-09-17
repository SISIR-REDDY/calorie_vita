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
    'fitness': [
      '🏃',
      '💪',
      '🏋️',
      '🚴',
      '🏊',
      '🤸',
      '🧘',
      '🏃‍♀️',
      '🏃‍♂️',
      '💪'
    ],
    'nutrition': ['🥗', '🍎', '🥕', '🥦', '🍇', '🥑', '🍌', '🥒', '🍅', '🥜'],
    'water': ['💧', '🚰', '🥤', '💦', '🌊', '💧', '🚰', '🥤', '💦', '🌊'],
    'sleep': ['😴', '🛌', '🌙', '💤', '😴', '🛌', '🌙', '💤', '😴', '🛌'],
    'work': ['💼', '💻', '📊', '📈', '📝', '📋', '💼', '💻', '📊', '📈'],
    'study': ['📚', '✏️', '📝', '🎓', '📖', '📚', '✏️', '📝', '🎓', '📖'],
    'cooking': [
      '👨‍🍳',
      '🍳',
      '🥘',
      '🍲',
      '👩‍🍳',
      '👨‍🍳',
      '🍳',
      '🥘',
      '🍲',
      '👩‍🍳'
    ],
    'shopping': ['🛒', '🛍️', '💳', '🏪', '🛒', '🛍️', '💳', '🏪', '🛒', '🛍️'],
    'cleaning': ['🧹', '🧽', '🧼', '✨', '🧹', '🧽', '🧼', '✨', '🧹', '🧽'],
    'social': ['👥', '🎉', '🎊', '👫', '👥', '🎉', '🎊', '👫', '👥', '🎉'],
    'travel': ['✈️', '🚗', '🚌', '🚂', '✈️', '🚗', '🚌', '🚂', '✈️', '🚗'],
    'entertainment': [
      '🎬',
      '🎵',
      '🎮',
      '📺',
      '🎬',
      '🎵',
      '🎮',
      '📺',
      '🎬',
      '🎵'
    ],
    'technology': ['📱', '💻', '⌚', '🔌', '📱', '💻', '⌚', '🔌', '📱', '💻'],
    'nature': ['🌱', '🌿', '🌳', '🌸', '🌱', '🌿', '🌳', '🌸', '🌱', '🌿'],
    'pets': ['🐕', '🐱', '🐰', '🐦', '🐕', '🐱', '🐰', '🐦', '🐕', '🐱'],
    'hobbies': ['🎨', '🎭', '🎪', '🎯', '🎨', '🎭', '🎪', '🎯', '🎨', '🎭'],
    'finance': ['💰', '💳', '📊', '💵', '💰', '💳', '📊', '💵', '💰', '💳'],
    'default': ['✅', '📋', '📝', '🎯', '⭐', '✅', '📋', '📝', '🎯', '⭐'],
  };

  // Enhanced keywords for each category with more comprehensive coverage
  final Map<String, List<String>> _categoryKeywords = {
    'health': [
      'health',
      'medical',
      'doctor',
      'hospital',
      'medicine',
      'pill',
      'vitamin',
      'supplement',
      'checkup',
      'examination',
      'treatment',
      'therapy',
      'recovery',
      'healing',
      'wellness',
      'blood',
      'pressure',
      'heart',
      'lung',
      'brain',
      'mental',
      'physical',
      'symptom',
      'diagnosis',
      'prescription',
      'pharmacy',
      'clinic',
      'nurse',
      'patient',
      'illness',
      'disease',
      'condition',
      'injury',
      'wound',
      'bandage',
      'injection',
      'vaccine'
    ],
    'fitness': [
      'exercise',
      'workout',
      'gym',
      'fitness',
      'training',
      'cardio',
      'strength',
      'muscle',
      'running',
      'jogging',
      'walking',
      'cycling',
      'swimming',
      'yoga',
      'pilates',
      'dance',
      'sports',
      'basketball',
      'football',
      'soccer',
      'tennis',
      'golf',
      'hiking',
      'climbing',
      'stretching',
      'flexibility',
      'endurance',
      'stamina',
      'energy',
      'active',
      'movement',
      'physical',
      'body',
      'muscle',
      'strength',
      'cardio',
      'aerobic',
      'anaerobic',
      'sprint',
      'marathon',
      'race',
      'competition',
      'athlete',
      'coach',
      'trainer',
      'fitness',
      'gym'
    ],
    'nutrition': [
      'food',
      'eat',
      'meal',
      'breakfast',
      'lunch',
      'dinner',
      'snack',
      'nutrition',
      'diet',
      'calorie',
      'protein',
      'carb',
      'fat',
      'vitamin',
      'mineral',
      'fiber',
      'sugar',
      'salt',
      'vegetable',
      'fruit',
      'meat',
      'fish',
      'chicken',
      'beef',
      'pork',
      'lamb',
      'seafood',
      'dairy',
      'milk',
      'cheese',
      'yogurt',
      'butter',
      'cream',
      'egg',
      'bread',
      'rice',
      'pasta',
      'noodle',
      'pizza',
      'burger',
      'sandwich',
      'salad',
      'soup',
      'stew',
      'curry',
      'healthy',
      'organic',
      'fresh',
      'raw',
      'cooked',
      'baked',
      'fried',
      'grilled',
      'boiled'
    ],
    'water': [
      'water',
      'drink',
      'hydrate',
      'thirsty',
      'liquid',
      'beverage',
      'juice',
      'soda',
      'coffee',
      'tea',
      'milk',
      'smoothie',
      'shake',
      'hydration',
      'dehydration',
      'fluid',
      'bottle',
      'glass',
      'cup',
      'mug',
      'tumbler',
      'flask',
      'canteen',
      'pitcher',
      'jug',
      'tank',
      'aqua',
      'h2o',
      'moisture',
      'wet',
      'damp',
      'soaked',
      'drenched',
      'saturated'
    ],
    'sleep': [
      'sleep',
      'bed',
      'rest',
      'nap',
      'dream',
      'night',
      'bedtime',
      'wake',
      'awake',
      'tired',
      'exhausted',
      'fatigue',
      'drowsy',
      'sleepy',
      'insomnia',
      'nightmare',
      'snore',
      'pillow',
      'blanket',
      'sheet',
      'mattress',
      'bedroom',
      'dark',
      'quiet',
      'peaceful',
      'relax',
      'recharge',
      'recover',
      'refresh',
      'energy',
      'morning',
      'evening',
      'midnight',
      'dawn'
    ],
    'work': [
      'work',
      'job',
      'office',
      'meeting',
      'project',
      'task',
      'deadline',
      'report',
      'presentation',
      'email',
      'phone',
      'call',
      'conference',
      'business',
      'career',
      'profession',
      'company',
      'colleague',
      'boss',
      'manager',
      'employee',
      'client',
      'customer',
      'contract',
      'deal',
      'proposal',
      'plan',
      'strategy',
      'goal',
      'target',
      'objective',
      'result',
      'outcome',
      'success',
      'achievement',
      'accomplishment',
      'progress',
      'development',
      'growth'
    ],
    'study': [
      'study',
      'learn',
      'education',
      'school',
      'university',
      'college',
      'course',
      'class',
      'lesson',
      'lecture',
      'tutorial',
      'book',
      'textbook',
      'note',
      'homework',
      'assignment',
      'exam',
      'test',
      'quiz',
      'grade',
      'score',
      'mark',
      'degree',
      'diploma',
      'certificate',
      'research',
      'thesis',
      'dissertation',
      'paper',
      'essay',
      'article',
      'document',
      'knowledge',
      'skill',
      'ability',
      'talent',
      'expertise',
      'mastery',
      'proficiency'
    ],
    'cooking': [
      'cook',
      'cooking',
      'recipe',
      'ingredient',
      'kitchen',
      'chef',
      'bake',
      'fry',
      'grill',
      'boil',
      'steam',
      'roast',
      'saute',
      'mix',
      'blend',
      'chop',
      'cut',
      'slice',
      'dice',
      'peel',
      'wash',
      'clean',
      'prep',
      'prepare',
      'season',
      'spice',
      'herb',
      'sauce',
      'soup',
      'stew',
      'curry',
      'pasta',
      'rice',
      'bread',
      'cake',
      'pie',
      'dessert',
      'meal'
    ],
    'shopping': [
      'shop',
      'shopping',
      'buy',
      'purchase',
      'store',
      'mall',
      'market',
      'supermarket',
      'grocery',
      'retail',
      'online',
      'cart',
      'basket',
      'checkout',
      'payment',
      'money',
      'price',
      'cost',
      'expensive',
      'cheap',
      'sale',
      'discount',
      'offer',
      'deal',
      'product',
      'item',
      'goods',
      'merchandise',
      'brand',
      'label',
      'tag',
      'receipt'
    ],
    'cleaning': [
      'clean',
      'cleaning',
      'wash',
      'wipe',
      'sweep',
      'mop',
      'vacuum',
      'dust',
      'polish',
      'scrub',
      'rinse',
      'soap',
      'detergent',
      'disinfect',
      'sanitize',
      'hygiene',
      'tidy',
      'organize',
      'arrange',
      'sort',
      'declutter',
      'neat',
      'spotless',
      'shiny',
      'fresh',
      'laundry',
      'clothes',
      'dishes',
      'floor',
      'window',
      'mirror',
      'bathroom',
      'kitchen'
    ],
    'social': [
      'social',
      'friend',
      'family',
      'party',
      'celebration',
      'event',
      'gathering',
      'meeting',
      'chat',
      'talk',
      'conversation',
      'discussion',
      'hangout',
      'visit',
      'invite',
      'guest',
      'host',
      'entertain',
      'fun',
      'enjoy',
      'laugh',
      'smile',
      'happy',
      'joy',
      'pleasure',
      'relationship',
      'connection',
      'bond',
      'community',
      'group',
      'team',
      'club',
      'society'
    ],
    'travel': [
      'travel',
      'trip',
      'journey',
      'vacation',
      'holiday',
      'flight',
      'plane',
      'airport',
      'hotel',
      'booking',
      'reservation',
      'ticket',
      'passport',
      'visa',
      'luggage',
      'bag',
      'suitcase',
      'backpack',
      'destination',
      'place',
      'country',
      'city',
      'town',
      'village',
      'explore',
      'discover',
      'adventure',
      'sightseeing',
      'tour',
      'guide',
      'map',
      'direction'
    ],
    'entertainment': [
      'entertainment',
      'fun',
      'game',
      'play',
      'movie',
      'film',
      'cinema',
      'theater',
      'show',
      'music',
      'song',
      'dance',
      'party',
      'celebration',
      'festival',
      'concert',
      'performance',
      'art',
      'painting',
      'drawing',
      'sculpture',
      'gallery',
      'museum',
      'exhibition',
      'display',
      'hobby',
      'leisure',
      'recreation',
      'relaxation',
      'enjoyment',
      'pleasure',
      'amusement'
    ],
    'technology': [
      'technology',
      'tech',
      'computer',
      'laptop',
      'phone',
      'mobile',
      'tablet',
      'device',
      'app',
      'software',
      'program',
      'code',
      'digital',
      'online',
      'internet',
      'website',
      'email',
      'message',
      'text',
      'call',
      'video',
      'camera',
      'photo',
      'picture',
      'image',
      'data',
      'file',
      'document',
      'folder',
      'download',
      'upload',
      'sync',
      'backup',
      'cloud'
    ],
    'nature': [
      'nature',
      'outdoor',
      'garden',
      'plant',
      'flower',
      'tree',
      'forest',
      'park',
      'mountain',
      'hill',
      'valley',
      'river',
      'lake',
      'ocean',
      'sea',
      'beach',
      'shore',
      'island',
      'hiking',
      'walking',
      'camping',
      'picnic',
      'fresh',
      'air',
      'sunshine',
      'rain',
      'snow',
      'environment',
      'green',
      'eco',
      'sustainable',
      'organic',
      'natural',
      'wild',
      'wildlife'
    ],
    'pets': [
      'pet',
      'dog',
      'cat',
      'animal',
      'veterinary',
      'vet',
      'walk',
      'feed',
      'care',
      'love',
      'play',
      'toy',
      'treat',
      'food',
      'water',
      'shelter',
      'home',
      'family',
      'companion',
      'friend',
      'loyal',
      'cute',
      'adorable',
      'friendly',
      'loving',
      'caring',
      'protective'
    ],
    'hobbies': [
      'hobby',
      'craft',
      'art',
      'music',
      'dance',
      'paint',
      'draw',
      'create',
      'make',
      'build',
      'design',
      'decorate',
      'collect',
      'gather',
      'hunt',
      'fish',
      'garden',
      'grow',
      'cultivate',
      'photography',
      'writing',
      'reading',
      'knitting',
      'sewing',
      'woodworking',
      'pottery'
    ],
    'finance': [
      'money',
      'budget',
      'save',
      'invest',
      'bank',
      'finance',
      'payment',
      'expense',
      'cost',
      'price',
      'value',
      'worth',
      'income',
      'salary',
      'wage',
      'profit',
      'loss',
      'gain',
      'account',
      'balance',
      'credit',
      'debit',
      'loan',
      'debt',
      'mortgage',
      'insurance',
      'tax',
      'refund',
      'pension',
      'retirement',
      'wealth',
      'rich',
      'poor',
      'afford'
    ],
  };

  // Context-aware keyword weights for better accuracy
  final Map<String, Map<String, int>> _keywordWeights = {
    'health': {
      'medical': 10,
      'doctor': 10,
      'hospital': 10,
      'medicine': 8,
      'pill': 8,
      'vitamin': 7,
      'checkup': 7,
      'therapy': 6,
      'recovery': 6,
      'wellness': 5
    },
    'fitness': {
      'exercise': 10,
      'workout': 10,
      'gym': 9,
      'running': 8,
      'cardio': 8,
      'strength': 7,
      'training': 7,
      'muscle': 6,
      'active': 5,
      'sports': 5
    },
    'nutrition': {
      'food': 10,
      'eat': 9,
      'meal': 8,
      'nutrition': 8,
      'diet': 7,
      'calorie': 7,
      'protein': 6,
      'vegetable': 6,
      'fruit': 6,
      'healthy': 5
    },
    'water': {
      'water': 10,
      'drink': 9,
      'hydrate': 8,
      'thirsty': 7,
      'liquid': 6,
      'beverage': 5,
      'hydration': 5,
      'fluid': 4,
      'aqua': 4,
      'h2o': 4
    },
    'sleep': {
      'sleep': 10,
      'bed': 9,
      'rest': 8,
      'nap': 7,
      'dream': 6,
      'night': 6,
      'bedtime': 6,
      'tired': 5,
      'exhausted': 5,
      'insomnia': 4
    },
    'work': {
      'work': 10,
      'job': 9,
      'office': 8,
      'meeting': 7,
      'project': 7,
      'task': 6,
      'deadline': 6,
      'business': 5,
      'career': 5,
      'company': 4
    },
    'study': {
      'study': 10,
      'learn': 9,
      'education': 8,
      'school': 7,
      'book': 6,
      'homework': 6,
      'exam': 5,
      'test': 5,
      'course': 4,
      'class': 4
    },
    'cooking': {
      'cook': 10,
      'cooking': 9,
      'recipe': 8,
      'kitchen': 7,
      'chef': 6,
      'bake': 5,
      'fry': 5,
      'ingredient': 4,
      'meal': 4,
      'food': 3
    },
    'shopping': {
      'shop': 10,
      'shopping': 9,
      'buy': 8,
      'purchase': 7,
      'store': 6,
      'mall': 5,
      'market': 5,
      'cart': 4,
      'basket': 4,
      'retail': 3
    },
    'cleaning': {
      'clean': 10,
      'cleaning': 9,
      'wash': 8,
      'wipe': 7,
      'sweep': 6,
      'mop': 6,
      'vacuum': 5,
      'dust': 5,
      'tidy': 4,
      'organize': 4
    },
    'social': {
      'social': 10,
      'friend': 9,
      'family': 8,
      'party': 7,
      'celebration': 6,
      'event': 5,
      'gathering': 5,
      'meeting': 4,
      'chat': 4,
      'talk': 3
    },
    'travel': {
      'travel': 10,
      'trip': 9,
      'journey': 8,
      'vacation': 7,
      'holiday': 6,
      'flight': 5,
      'hotel': 5,
      'destination': 4,
      'explore': 4,
      'adventure': 3
    },
    'entertainment': {
      'entertainment': 10,
      'fun': 9,
      'game': 8,
      'play': 7,
      'movie': 6,
      'music': 6,
      'dance': 5,
      'party': 4,
      'show': 4,
      'art': 3
    },
    'technology': {
      'technology': 10,
      'tech': 9,
      'computer': 8,
      'phone': 7,
      'digital': 6,
      'app': 5,
      'software': 5,
      'device': 4,
      'online': 4,
      'internet': 3
    },
    'nature': {
      'nature': 10,
      'outdoor': 9,
      'garden': 8,
      'plant': 7,
      'flower': 6,
      'tree': 6,
      'park': 5,
      'hiking': 5,
      'environment': 4,
      'green': 3
    },
    'pets': {
      'pet': 10,
      'dog': 9,
      'cat': 8,
      'animal': 7,
      'veterinary': 6,
      'vet': 6,
      'walk': 5,
      'feed': 5,
      'care': 4,
      'love': 3
    },
    'hobbies': {
      'hobby': 10,
      'craft': 9,
      'art': 8,
      'music': 7,
      'dance': 6,
      'paint': 6,
      'draw': 5,
      'create': 5,
      'make': 4,
      'build': 3
    },
    'finance': {
      'money': 10,
      'budget': 9,
      'save': 8,
      'invest': 7,
      'bank': 6,
      'finance': 6,
      'payment': 5,
      'expense': 5,
      'cost': 4,
      'price': 3
    }
  };

  /// Generate a dynamic icon based on the task prompt with improved accuracy
  String generateIcon(String taskPrompt) {
    final lowerPrompt = taskPrompt.toLowerCase().trim();

    // Handle empty or very short prompts
    if (lowerPrompt.isEmpty || lowerPrompt.length < 2) {
      return _getRandomIcon('default');
    }

    // Direct emoji mapping for common task patterns
    final directEmojiMap = {
      'workout': '💪',
      'exercise': '🏃',
      'run': '🏃',
      'gym': '🏋️',
      'yoga': '🧘',
      'swim': '🏊',
      'walk': '🚶',
      'bike': '🚴',
      'dance': '💃',
      'eat': '🍽️',
      'breakfast': '🍳',
      'lunch': '🥗',
      'dinner': '🍽️',
      'snack': '🍎',
      'drink': '🥤',
      'water': '💧',
      'coffee': '☕',
      'tea': '🍵',
      'sleep': '😴',
      'bed': '🛌',
      'nap': '😴',
      'study': '📚',
      'read': '📖',
      'learn': '🎓',
      'work': '💼',
      'meeting': '👥',
      'call': '📞',
      'email': '📧',
      'clean': '🧹',
      'wash': '🧽',
      'cook': '👨‍🍳',
      'bake': '🍰',
      'shop': '🛒',
      'buy': '🛍️',
      'travel': '✈️',
      'drive': '🚗',
      'fly': '✈️',
      'play': '🎮',
      'game': '🎯',
      'movie': '🎬',
      'music': '🎵',
      'art': '🎨',
      'paint': '🖌️',
      'draw': '✏️',
      'write': '✍️',
      'code': '💻',
      'phone': '📱',
      'computer': '💻',
      'garden': '🌱',
      'plant': '🌿',
      'dog': '🐕',
      'cat': '🐱',
      'pet': '🐾',
      'money': '💰',
      'pay': '💳',
      'save': '💵',
      'budget': '📊',
      'doctor': '👨‍⚕️',
      'medicine': '💊',
      'health': '❤️',
      'hospital': '🏥',
      'appointment': '📅',
      'meeting': '👥',
      'party': '🎉',
      'celebration': '🎊',
      'birthday': '🎂',
      'gift': '🎁',
      'book': '📚',
      'library': '📖',
      'school': '🏫',
      'university': '🎓',
      'homework': '📝',
      'exam': '📋',
      'test': '📝',
      'project': '📋',
      'task': '✅',
      'todo': '📝',
      'goal': '🎯',
      'target': '🎯',
      'plan': '📋',
      'schedule': '📅',
      'calendar': '📅',
      'reminder': '⏰',
      'alarm': '⏰',
      'time': '⏰',
      'urgent': '🚨',
      'important': '⭐',
      'priority': '🔴',
      'deadline': '⏰',
      'due': '📅',
    };

    // Check for direct matches first (most accurate)
    for (final entry in directEmojiMap.entries) {
      if (lowerPrompt.contains(entry.key)) {
        return entry.value;
      }
    }

    // Find the best matching category with weighted scoring
    String bestCategory = 'default';
    double maxScore = 0.0;

    for (final category in _categoryKeywords.keys) {
      final keywords = _categoryKeywords[category]!;
      final weights = _keywordWeights[category] ?? {};
      double categoryScore = 0.0;

      for (final keyword in keywords) {
        if (lowerPrompt.contains(keyword)) {
          // Use weighted scoring for better accuracy
          final weight = weights[keyword] ?? 1;
          categoryScore += weight;

          // Bonus for exact matches
          if (lowerPrompt == keyword) {
            categoryScore += 5;
          }
          // Bonus for word boundary matches
          else if (RegExp(r'\b' + RegExp.escape(keyword) + r'\b')
              .hasMatch(lowerPrompt)) {
            categoryScore += 2;
          }
        }
      }

      if (categoryScore > maxScore) {
        maxScore = categoryScore;
        bestCategory = category;
      }
    }

    // If no good match found, try partial matching
    if (maxScore < 2.0) {
      bestCategory = _findPartialMatch(lowerPrompt);
    }

    return _getRandomIcon(bestCategory);
  }

  /// Find partial matches for better coverage
  String _findPartialMatch(String prompt) {
    for (final category in _categoryKeywords.keys) {
      final keywords = _categoryKeywords[category]!;
      for (final keyword in keywords) {
        if (prompt.contains(keyword) || keyword.contains(prompt)) {
          return category;
        }
      }
    }
    return 'default';
  }

  /// Get a random icon from a specific category
  String _getRandomIcon(String category) {
    final categoryIcons =
        _iconCategories[category] ?? _iconCategories['default']!;
    final randomIndex = _random.nextInt(categoryIcons.length);
    return categoryIcons[randomIndex];
  }

  /// Generate multiple icons for variety with improved selection
  List<String> generateMultipleIcons(String taskPrompt, {int count = 3}) {
    final icons = <String>{};
    final lowerPrompt = taskPrompt.toLowerCase();

    // Find all matching categories with scores
    final categoryScores = <String, double>{};
    for (final category in _categoryKeywords.keys) {
      final keywords = _categoryKeywords[category]!;
      final weights = _keywordWeights[category] ?? {};
      double score = 0.0;

      for (final keyword in keywords) {
        if (lowerPrompt.contains(keyword)) {
          final weight = weights[keyword] ?? 1;
          score += weight;
        }
      }

      if (score > 0) {
        categoryScores[category] = score;
      }
    }

    // Sort categories by score
    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // If no specific matches, use default
    if (sortedCategories.isEmpty) {
      sortedCategories.add(const MapEntry('default', 1.0));
    }

    // Generate icons from top categories
    int generated = 0;
    for (final categoryEntry in sortedCategories) {
      if (generated >= count) break;

      final category = categoryEntry.key;
      final categoryIcons =
          _iconCategories[category] ?? _iconCategories['default']!;

      // Add 1-2 icons from this category
      final iconsToAdd = (categoryEntry.value > 5) ? 2 : 1;
      for (int i = 0; i < iconsToAdd && generated < count; i++) {
        final randomIcon = categoryIcons[_random.nextInt(categoryIcons.length)];
        if (icons.add(randomIcon)) {
          generated++;
        }
      }
    }

    // Fill remaining slots with default icons if needed
    while (icons.length < count) {
      final defaultIcon = _getRandomIcon('default');
      if (icons.add(defaultIcon)) {
        generated++;
      }
    }

    return icons.toList();
  }

  /// Get icon suggestions for a task prompt
  List<String> getIconSuggestions(String taskPrompt, {int count = 5}) {
    return generateMultipleIcons(taskPrompt, count: count);
  }

  /// Check if a task prompt matches a specific category with confidence score
  double getCategoryConfidence(String taskPrompt, String category) {
    final lowerPrompt = taskPrompt.toLowerCase();
    final keywords = _categoryKeywords[category] ?? [];
    final weights = _keywordWeights[category] ?? {};
    double totalScore = 0.0;
    int matches = 0;

    for (final keyword in keywords) {
      if (lowerPrompt.contains(keyword)) {
        final weight = weights[keyword] ?? 1;
        totalScore += weight;
        matches++;
      }
    }

    // Return confidence as percentage
    return matches > 0 ? (totalScore / keywords.length) * 100 : 0.0;
  }

  /// Check if a task prompt matches a specific category
  bool matchesCategory(String taskPrompt, String category) {
    return getCategoryConfidence(taskPrompt, category) > 20.0;
  }

  /// Get all available categories
  List<String> getAvailableCategories() {
    return _categoryKeywords.keys.toList();
  }

  /// Get keywords for a specific category
  List<String> getCategoryKeywords(String category) {
    return _categoryKeywords[category] ?? [];
  }

  /// Get the best matching category for a task prompt
  String getBestCategory(String taskPrompt) {
    final lowerPrompt = taskPrompt.toLowerCase();
    String bestCategory = 'default';
    double maxScore = 0.0;

    for (final category in _categoryKeywords.keys) {
      final score = getCategoryConfidence(lowerPrompt, category);
      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    }

    return bestCategory;
  }

  /// Get contextual icon suggestions based on time of day and user patterns
  List<String> getContextualIcons(String taskPrompt, {DateTime? timeOfDay}) {
    final baseIcons = generateMultipleIcons(taskPrompt, count: 3);
    final contextualIcons = <String>[];

    // Add time-based suggestions
    if (timeOfDay != null) {
      final hour = timeOfDay.hour;
      if (hour >= 6 && hour < 12) {
        // Morning suggestions
        contextualIcons.addAll(['☀️', '🌅', '☕', '🍳', '🏃']);
      } else if (hour >= 12 && hour < 18) {
        // Afternoon suggestions
        contextualIcons.addAll(['☀️', '🍽️', '💼', '📚', '🚗']);
      } else if (hour >= 18 && hour < 22) {
        // Evening suggestions
        contextualIcons.addAll(['🌆', '🍽️', '📺', '🎵', '👥']);
      } else {
        // Night suggestions
        contextualIcons.addAll(['🌙', '😴', '🛌', '📖', '🍵']);
      }
    }

    // Combine base icons with contextual icons
    final allIcons = [...baseIcons, ...contextualIcons];
    return allIcons.take(5).toList();
  }
}
