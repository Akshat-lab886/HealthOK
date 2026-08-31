import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A single logged workout entry.
class WorkoutEntry {
  final String id;
  final DateTime time;
  final WorkoutType type;
  final int durationMinutes;
  final int caloriesBurned;
  final int intensity; // 1-5
  final String? notes;

  WorkoutEntry({
    required this.id,
    required this.time,
    required this.type,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.intensity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'type': type.name,
        'duration': durationMinutes,
        'calories': caloriesBurned,
        'intensity': intensity,
        'notes': notes,
      };

  factory WorkoutEntry.fromJson(Map<String, dynamic> j) => WorkoutEntry(
        id: j['id'] as String,
        time: DateTime.parse(j['time'] as String),
        type: WorkoutType.values.firstWhere((t) => t.name == j['type'],
            orElse: () => WorkoutType.other),
        durationMinutes: j['duration'] as int,
        caloriesBurned: j['calories'] as int,
        intensity: j['intensity'] as int,
        notes: j['notes'] as String?,
      );

  /// XP earned for completing this workout.
  int get xpEarned {
    int base = durationMinutes * 2;
    base += caloriesBurned ~/ 10;
    base *= intensity;
    return base;
  }
}

enum WorkoutType {
  run('🏃', 'Running', 'Cardio • 12 kcal/min'),
  walk('🚶', 'Walking', 'Cardio • 5 kcal/min'),
  bike('🚴', 'Cycling', 'Cardio • 9 kcal/min'),
  swim('🏊', 'Swimming', 'Full-body • 11 kcal/min'),
  weights('🏋️', 'Strength', 'Resistance • 7 kcal/min'),
  yoga('🧘', 'Yoga', 'Flexibility • 4 kcal/min'),
  hiit('⚡', 'HIIT', 'Burst • 14 kcal/min'),
  sports('⚽', 'Sports', 'Variable • 8 kcal/min'),
  other('💪', 'Other', 'Custom');

  final String emoji;
  final String label;
  final String hint;

  const WorkoutType(this.emoji, this.label, this.hint);

  /// Compendium of Physical Activities MET value (moderate effort).
  /// kcal/min = MET × 3.5 × weightKg / 200 — scales with the user's body.
  double get met {
    switch (this) {
      case WorkoutType.run:
        return 9.8;
      case WorkoutType.walk:
        return 3.5;
      case WorkoutType.bike:
        return 7.5;
      case WorkoutType.swim:
        return 8.3;
      case WorkoutType.weights:
        return 5.0;
      case WorkoutType.yoga:
        return 2.8;
      case WorkoutType.hiit:
        return 10.0;
      case WorkoutType.sports:
        return 6.0;
      case WorkoutType.other:
        return 4.0;
    }
  }

  /// Estimated kcal/min at [intensity] (1–5) for a given body weight.
  /// Kept for the UI hint text; prefer [estimateCalories] for logging.
  double kcalPerMinuteFor(double weightKg, int intensity) {
    final intensityFactor = 0.85 + 0.075 * intensity.clamp(1, 5); // 0.925–1.225
    return met * 3.5 * weightKg / 200 * intensityFactor;
  }
}

/// MET-based calorie estimation using the user's real body weight.
/// Replaces the old fixed kcal/min table (a 55 kg walker and a 95 kg walker
/// burn very different amounts).
int estimateWorkoutCalories({
  required WorkoutType type,
  required int durationMinutes,
  required int intensity,
  required double weightKg,
}) {
  final intensityFactor = 0.85 + 0.075 * intensity.clamp(1, 5); // 0.925–1.225
  final perMinute = type.met * 3.5 * weightKg / 200 * intensityFactor;
  return ((perMinute * durationMinutes).round()).clamp(1, 100000).toInt();
}

/// Persistent workout log.
class WorkoutService {
  static const _key = 'workout_log_v1';

  static Future<List<WorkoutEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => WorkoutEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(WorkoutEntry entry) async {
    final list = await getAll();
    list.add(entry);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<void> delete(String id) async {
    final list = await getAll();
    list.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// Workouts logged today.
  static Future<List<WorkoutEntry>> getToday() async {
    final list = await getAll();
    final now = DateTime.now();
    return list.where((w) =>
        w.time.year == now.year &&
        w.time.month == now.month &&
        w.time.day == now.day).toList();
  }

  /// Last 7 days.
  static Future<List<WorkoutEntry>> getLast7Days() async {
    final list = await getAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return list.where((w) => w.time.isAfter(cutoff)).toList();
  }

  /// Weekly summary: total minutes, calories, sessions, per-type breakdown.
  static Future<Map<String, dynamic>> weeklySummary() async {
    final week = await getLast7Days();
    int totalMinutes = 0;
    int totalCalories = 0;
    final byType = <WorkoutType, int>{};
    for (final w in week) {
      totalMinutes += w.durationMinutes;
      totalCalories += w.caloriesBurned;
      byType[w.type] = (byType[w.type] ?? 0) + w.durationMinutes;
    }
    return {
      'sessions': week.length,
      'minutes': totalMinutes,
      'calories': totalCalories,
      'byType': byType,
      'xp': week.fold<int>(0, (s, w) => s + w.xpEarned),
    };
  }

  /// Consecutive days (ending today or yesterday) with at least one workout.
  static Future<int> workoutStreak() async {
    final list = await getAll();
    if (list.isEmpty) return 0;
    final days = list
        .map((w) => DateTime(w.time.year, w.time.month, w.time.day))
        .toSet();
    int streak = 0;
    var cursor = DateTime.now();
    final today = DateTime(cursor.year, cursor.month, cursor.day);
    // Allow the streak to be "alive" if today has no workout yet
    if (!days.contains(today)) cursor = today.subtract(const Duration(days: 1));
    final today2 = DateTime(cursor.year, cursor.month, cursor.day);
    if (!days.contains(today2)) return 0;
    while (days.contains(DateTime(cursor.year, cursor.month, cursor.day))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Personal best: longest single workout per type (minutes).
  static Future<Map<WorkoutType, int>> personalBests() async {
    final list = await getAll();
    final bests = <WorkoutType, int>{};
    for (final w in list) {
      final cur = bests[w.type] ?? 0;
      if (w.durationMinutes > cur) bests[w.type] = w.durationMinutes;
    }
    return bests;
  }
}