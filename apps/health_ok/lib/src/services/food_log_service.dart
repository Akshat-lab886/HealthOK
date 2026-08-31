import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class FoodEntry {
  final String id;
  final DateTime time;
  final String name;
  final int estimatedCalories;
  final String? photoPath;
  final String mealType; // breakfast, lunch, dinner, snack

  FoodEntry({
    required this.id,
    required this.time,
    required this.name,
    required this.estimatedCalories,
    this.photoPath,
    required this.mealType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'name': name,
        'calories': estimatedCalories,
        'photo': photoPath,
        'meal': mealType,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id'] as String,
        time: DateTime.parse(j['time'] as String),
        name: j['name'] as String,
        estimatedCalories: j['calories'] as int,
        photoPath: j['photo'] as String?,
        mealType: j['meal'] as String,
      );

  String get mealEmoji {
    switch (mealType) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '☀️';
      case 'dinner':
        return '🌙';
      default:
        return '🍪';
    }
  }
}

class FoodLogService {
  static const _key = 'food_log_v1';

  static Future<List<FoodEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => FoodEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(FoodEntry entry) async {
    final list = await getAll();
    list.add(entry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final list = await getAll();
    list.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(list.map((e) => e.toJson()).toList()));
  }

  static Future<int> todayCalories() async {
    final list = await getAll();
    final now = DateTime.now();
    return list
        .where((e) =>
            e.time.year == now.year &&
            e.time.month == now.month &&
            e.time.day == now.day)
        .fold<int>(0, (s, e) => s + e.estimatedCalories);
  }

  static Future<List<FoodEntry>> getToday() async {
    final list = await getAll();
    final now = DateTime.now();
    return list
        .where((e) =>
            e.time.year == now.year &&
            e.time.month == now.month &&
            e.time.day == now.day)
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  /// Common foods with calorie estimates.
  static const commonFoods = [
    ('Apple', 95, '🍎'),
    ('Banana', 105, '🍌'),
    ('Orange', 62, '🍊'),
    ('Rice (1 cup)', 206, '🍚'),
    ('Chicken Breast', 165, '🍗'),
    ('Egg (boiled)', 78, '🥚'),
    ('Toast (2 slices)', 150, '🍞'),
    ('Salad', 20, '🥗'),
    ('Coffee (black)', 2, '☕'),
    ('Milk (1 cup)', 103, '🥛'),
    ('Pizza (1 slice)', 285, '🍕'),
    ('Burger', 354, '🍔'),
    ('Pasta (1 cup)', 220, '🍝'),
    ('Yogurt', 100, '🥛'),
    ('Sandwich', 300, '🥪'),
    ('Soup', 120, '🍜'),
    ('Steak', 271, '🥩'),
    ('Ice Cream', 207, '🍦'),
    ('Chocolate Bar', 230, '🍫'),
    ('Nuts (1 oz)', 173, '🥜'),
  ];
}