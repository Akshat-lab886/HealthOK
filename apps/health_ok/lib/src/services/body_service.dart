import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BodyMeasurement {
  final DateTime date;
  final double weightKg;
  final double? bodyFatPct;
  final double? muscleKg;
  final double? waistCm;
  final double? chestCm;

  BodyMeasurement({
    required this.date,
    required this.weightKg,
    this.bodyFatPct,
    this.muscleKg,
    this.waistCm,
    this.chestCm,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weightKg,
        'fat': bodyFatPct,
        'muscle': muscleKg,
        'waist': waistCm,
        'chest': chestCm,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> j) => BodyMeasurement(
        date: DateTime.parse(j['date'] as String),
        weightKg: (j['weight'] as num).toDouble(),
        bodyFatPct: j['fat'] == null ? null : (j['fat'] as num).toDouble(),
        muscleKg: j['muscle'] == null ? null : (j['muscle'] as num).toDouble(),
        waistCm: j['waist'] == null ? null : (j['waist'] as num).toDouble(),
        chestCm: j['chest'] == null ? null : (j['chest'] as num).toDouble(),
      );
}

class BodyService {
  static const _key = 'body_log_v1';

  static Future<List<BodyMeasurement>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(BodyMeasurement m) async {
    final list = await getAll();
    list.add(m);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<void> delete(DateTime date) async {
    final list = await getAll();
    list.removeWhere((e) =>
        e.date.year == date.year && e.date.month == date.month && e.date.day == date.day);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<BodyMeasurement?> getLatest() async {
    final list = await getAll();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.date.compareTo(a.date));
    return list.first;
  }
}