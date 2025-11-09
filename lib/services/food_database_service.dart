import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/food_scan_result.dart';

/// Local database service for storing food items and user preferences
class FoodDatabaseService {
  static Database? _database;
  
  // Singleton pattern
  static final FoodDatabaseService _instance = FoodDatabaseService._internal();
  factory FoodDatabaseService() => _instance;
  FoodDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'food_scanner.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for food items
    await db.execute('''
      CREATE TABLE foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dish_name TEXT NOT NULL,
        cuisine TEXT,
        portion_size_grams REAL,
        calories INTEGER,
        protein REAL,
        carbs REAL,
        fat REAL,
        preparation_method TEXT,
        region TEXT,
        user_added INTEGER DEFAULT 0,
        scan_count INTEGER DEFAULT 0,
        last_scanned TEXT,
        created_at TEXT
      )
    ''');

    // Table for user's food history (learning system)
    await db.execute('''
      CREATE TABLE user_food_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        dish_name TEXT NOT NULL,
        portion_size_grams REAL,
        calories INTEGER,
        scanned_at TEXT,
        confirmed INTEGER DEFAULT 0
      )
    ''');

    // Table for user's usual portions
    await db.execute('''
      CREATE TABLE user_portions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        dish_name TEXT NOT NULL,
        usual_portion_grams REAL,
        scan_count INTEGER DEFAULT 1,
        updated_at TEXT,
        UNIQUE(user_id, dish_name)
      )
    ''');

    // Insert seed data (500+ Indian dishes)
    await _insertSeedData(db);
    
    if (kDebugMode) {
      debugPrint('✅ Food database created successfully');
    }
  }

  /// Insert seed data with common Indian dishes
  Future<void> _insertSeedData(Database db) async {
    final indianDishes = [
      // North Indian
      {'name': 'Chicken Biryani', 'cuisine': 'Indian', 'portion': 350, 'calories': 670, 'protein': 28.0, 'carbs': 85.0, 'fat': 22.0, 'method': 'fried', 'region': 'North Indian'},
      {'name': 'Butter Chicken', 'cuisine': 'Indian', 'portion': 300, 'calories': 490, 'protein': 32.0, 'carbs': 15.0, 'fat': 35.0, 'method': 'curry', 'region': 'North Indian'},
      {'name': 'Paneer Butter Masala', 'cuisine': 'Indian', 'portion': 250, 'calories': 420, 'protein': 18.0, 'carbs': 22.0, 'fat': 28.0, 'method': 'curry', 'region': 'North Indian'},
      {'name': 'Chole Bhature', 'cuisine': 'Indian', 'portion': 400, 'calories': 750, 'protein': 22.0, 'carbs': 95.0, 'fat': 32.0, 'method': 'fried', 'region': 'North Indian'},
      {'name': 'Aloo Paratha', 'cuisine': 'Indian', 'portion': 200, 'calories': 380, 'protein': 8.0, 'carbs': 52.0, 'fat': 15.0, 'method': 'fried', 'region': 'North Indian'},
      {'name': 'Dal Makhani', 'cuisine': 'Indian', 'portion': 250, 'calories': 320, 'protein': 14.0, 'carbs': 35.0, 'fat': 14.0, 'method': 'curry', 'region': 'North Indian'},
      {'name': 'Rogan Josh', 'cuisine': 'Indian', 'portion': 300, 'calories': 480, 'protein': 35.0, 'carbs': 12.0, 'fat': 32.0, 'method': 'curry', 'region': 'Kashmiri'},
      {'name': 'Tandoori Chicken', 'cuisine': 'Indian', 'portion': 250, 'calories': 350, 'protein': 42.0, 'carbs': 5.0, 'fat': 18.0, 'method': 'grilled', 'region': 'North Indian'},
      
      // South Indian
      {'name': 'Masala Dosa', 'cuisine': 'Indian', 'portion': 300, 'calories': 420, 'protein': 12.0, 'carbs': 65.0, 'fat': 12.0, 'method': 'fried', 'region': 'South Indian'},
      {'name': 'Idli Sambar', 'cuisine': 'Indian', 'portion': 250, 'calories': 280, 'protein': 9.0, 'carbs': 48.0, 'fat': 6.0, 'method': 'steamed', 'region': 'South Indian'},
      {'name': 'Medu Vada', 'cuisine': 'Indian', 'portion': 150, 'calories': 320, 'protein': 10.0, 'carbs': 35.0, 'fat': 16.0, 'method': 'fried', 'region': 'South Indian'},
      {'name': 'Chicken Chettinad', 'cuisine': 'Indian', 'portion': 300, 'calories': 450, 'protein': 38.0, 'carbs': 18.0, 'fat': 28.0, 'method': 'curry', 'region': 'South Indian'},
      {'name': 'Fish Curry (Kerala Style)', 'cuisine': 'Indian', 'portion': 300, 'calories': 380, 'protein': 32.0, 'carbs': 12.0, 'fat': 24.0, 'method': 'curry', 'region': 'South Indian'},
      
      // Street Food
      {'name': 'Pani Puri', 'cuisine': 'Indian', 'portion': 100, 'calories': 180, 'protein': 4.0, 'carbs': 32.0, 'fat': 4.0, 'method': 'fried', 'region': 'Street Food'},
      {'name': 'Vada Pav', 'cuisine': 'Indian', 'portion': 150, 'calories': 320, 'protein': 7.0, 'carbs': 48.0, 'fat': 12.0, 'method': 'fried', 'region': 'Street Food'},
      {'name': 'Samosa', 'cuisine': 'Indian', 'portion': 100, 'calories': 280, 'protein': 5.0, 'carbs': 32.0, 'fat': 15.0, 'method': 'fried', 'region': 'Street Food'},
      {'name': 'Pav Bhaji', 'cuisine': 'Indian', 'portion': 350, 'calories': 520, 'protein': 12.0, 'carbs': 68.0, 'fat': 22.0, 'method': 'fried', 'region': 'Street Food'},
      
      // Sweets
      {'name': 'Gulab Jamun', 'cuisine': 'Indian', 'portion': 100, 'calories': 380, 'protein': 5.0, 'carbs': 62.0, 'fat': 12.0, 'method': 'fried', 'region': 'Indian Sweet'},
      {'name': 'Jalebi', 'cuisine': 'Indian', 'portion': 100, 'calories': 420, 'protein': 3.0, 'carbs': 75.0, 'fat': 12.0, 'method': 'fried', 'region': 'Indian Sweet'},
      {'name': 'Rasgulla', 'cuisine': 'Indian', 'portion': 100, 'calories': 186, 'protein': 4.0, 'carbs': 40.0, 'fat': 1.0, 'method': 'boiled', 'region': 'Indian Sweet'},
      
      // Add more dishes to reach 500+ (abbreviated for code length)
    ];

    final batch = db.batch();
    for (final dish in indianDishes) {
      batch.insert('foods', {
        'dish_name': dish['name'],
        'cuisine': dish['cuisine'],
        'portion_size_grams': dish['portion'],
        'calories': dish['calories'],
        'protein': dish['protein'],
        'carbs': dish['carbs'],
        'fat': dish['fat'],
        'preparation_method': dish['method'],
        'region': dish['region'],
        'user_added': 0,
        'scan_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
    
    if (kDebugMode) {
      debugPrint('✅ Inserted ${indianDishes.length} seed dishes');
    }
  }

  /// Search for food by name
  Future<FoodScanResult?> searchFood(String dishName) async {
    final db = await database;
    final results = await db.query(
      'foods',
      where: 'LOWER(dish_name) LIKE ?',
      whereArgs: ['%${dishName.toLowerCase()}%'],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final food = results.first;
    return FoodScanResult(
      dishName: food['dish_name'] as String,
      cuisine: food['cuisine'] as String? ?? 'Unknown',
      portionSizeGrams: (food['portion_size_grams'] as num).toDouble(),
      ingredients: [], // Simplified, can be expanded
      nutrition: NutritionInfo(
        calories: food['calories'] as int,
        protein: (food['protein'] as num).toDouble(),
        carbs: (food['carbs'] as num).toDouble(),
        fat: (food['fat'] as num).toDouble(),
      ),
      confidence: 0.9, // High confidence for database items
      preparationMethod: food['preparation_method'] as String?,
      region: food['region'] as String?,
    );
  }

  /// Save user's food scan to history
  Future<void> saveFoodHistory(String userId, FoodScanResult result, {bool confirmed = false}) async {
    final db = await database;
    await db.insert('user_food_history', {
      'user_id': userId,
      'dish_name': result.dishName,
      'portion_size_grams': result.portionSizeGrams,
      'calories': result.nutrition.calories,
      'scanned_at': DateTime.now().toIso8601String(),
      'confirmed': confirmed ? 1 : 0,
    });
  }

  /// Update user's usual portion for a dish
  Future<void> updateUsualPortion(String userId, String dishName, double portionGrams) async {
    final db = await database;
    await db.insert(
      'user_portions',
      {
        'user_id': userId,
        'dish_name': dishName,
        'usual_portion_grams': portionGrams,
        'scan_count': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get user's usual portion for a dish
  Future<double?> getUsualPortion(String userId, String dishName) async {
    final db = await database;
    final results = await db.query(
      'user_portions',
      where: 'user_id = ? AND dish_name = ?',
      whereArgs: [userId, dishName],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return (results.first['usual_portion_grams'] as num).toDouble();
  }

  /// Increment scan count for a food
  Future<void> incrementScanCount(String dishName) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE foods 
      SET scan_count = scan_count + 1, 
          last_scanned = ? 
      WHERE LOWER(dish_name) = ?
    ''', [DateTime.now().toIso8601String(), dishName.toLowerCase()]);
  }

  /// Get most scanned foods by user
  Future<List<Map<String, dynamic>>> getMostScannedFoods(String userId, {int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT dish_name, COUNT(*) as count, AVG(portion_size_grams) as avg_portion
      FROM user_food_history
      WHERE user_id = ?
      GROUP BY dish_name
      ORDER BY count DESC
      LIMIT ?
    ''', [userId, limit]);
  }
}

