import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Mood/energy check-in entry.
class MoodEntry {
  final DateTime date;
  final int mood; // 1-5
  final int energy; // 1-5
  final String? note;

  MoodEntry({required this.date, required this.mood, required this.energy, this.note});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'mood': mood,
        'energy': energy,
        'note': note,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> j) => MoodEntry(
        date: DateTime.parse(j['date'] as String),
        mood: j['mood'] as int,
        energy: j['energy'] as int,
        note: j['note'] as String?,
      );

  String get moodEmoji => ['😣', '😕', '😐', '🙂', '😄'][mood - 1];
  String get moodLabel => ['Terrible', 'Low', 'Okay', 'Good', 'Great'][mood - 1];
  String get energyEmoji => ['🪫', '🔋', '⚡', '💪', '🚀'][energy - 1];
  String get energyLabel => ['Drained', 'Low', 'Steady', 'High', 'Peak'][energy - 1];
}

class MoodService {
  static const _key = 'mood_log_v1';

  static Future<List<MoodEntry>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => MoodEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(MoodEntry entry) async {
    final list = await getAll();
    // Remove today's if exists
    list.removeWhere((e) => _isSameDay(e.date, entry.date));
    list.add(entry);
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<MoodEntry?> getToday() async {
    final list = await getAll();
    final now = DateTime.now();
    try {
      return list.firstWhere((e) => _isSameDay(e.date, now));
    } catch (_) {
      return null;
    }
  }

  static Future<List<MoodEntry>> getLast7Days() async {
    final list = await getAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return list.where((e) => e.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static Future<List<MoodEntry>> getLast30Days() async {
    final list = await getAll();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return list.where((e) => e.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Average mood across the provided entries (0.0 when empty).
  static double avgMood(List<MoodEntry> entries) {
    if (entries.isEmpty) return 0;
    double sum = 0;
    for (final e in entries) {
      sum += e.mood;
    }
    return sum / entries.length;
  }

  /// Average energy across the provided entries (0.0 when empty).
  static double avgEnergy(List<MoodEntry> entries) {
    if (entries.isEmpty) return 0;
    double sum = 0;
    for (final e in entries) {
      sum += e.energy;
    }
    return sum / entries.length;
  }

  /// Best day of week by mood (e.g. "Saturday") — needs ≥2 samples per day.
  static String? bestDayOfWeek(List<MoodEntry> entries) {
    if (entries.length < 7) return null;
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final e in entries) {
      final wd = e.date.weekday % 7; // 0=Mon..6=Sun after mod
      sums[wd] += e.mood;
      counts[wd]++;
    }
    int best = -1;
    double bestAvg = 0;
    for (int i = 0; i < 7; i++) {
      if (counts[i] < 2) continue;
      final avg = sums[i] / counts[i];
      if (avg > bestAvg) {
        bestAvg = avg;
        best = i;
      }
    }
    if (best == -1) return null;
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return names[best];
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}