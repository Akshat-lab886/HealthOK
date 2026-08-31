import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// One day's merged activity totals (Health Connect + local, deduped).
class DailyStat {
  final String date; // yyyy-MM-dd
  final int steps;
  final double distanceKm;
  final int activeKcal;

  const DailyStat({
    required this.date,
    required this.steps,
    required this.distanceKm,
    required this.activeKcal,
  });

  Map<String, dynamic> toJson() => {
        'd': date,
        's': steps,
        'km': distanceKm,
        'kcal': activeKcal,
      };

  factory DailyStat.fromJson(Map<String, dynamic> j) => DailyStat(
        date: j['d'] as String,
        steps: (j['s'] as num?)?.toInt() ?? 0,
        distanceKm: (j['km'] as num?)?.toDouble() ?? 0,
        activeKcal: (j['kcal'] as num?)?.toInt() ?? 0,
      );
}

/// Rolling 30-day local activity history. This is what makes quests,
/// hydration goals and insights PERSONAL — targets adapt to what the user
/// actually does instead of fixed generic numbers.
class DailyStatsService {
  static const _kStats = 'hok_daily_stats';
  static const _kQuestOutcome = 'hok_quest_outcomes'; // date -> 'full'|'partial'|'miss'
  static const _maxDays = 30;

  static Future<Map<String, DailyStat>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStats);
    if (raw == null) return {};
    try {
      final list = json.decode(raw) as List;
      final map = <String, DailyStat>{};
      for (final e in list) {
        final stat = DailyStat.fromJson(e as Map<String, dynamic>);
        map[stat.date] = stat;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(Map<String, DailyStat> map) async {
    final prefs = await SharedPreferences.getInstance();
    // Keep the most recent 30 days
    final keys = map.keys.toList()..sort();
    final trimmed = <String, DailyStat>{};
    for (final k in keys.skip(keys.length > _maxDays ? keys.length - _maxDays : 0)) {
      trimmed[k] = map[k]!;
    }
    await prefs.setString(
        _kStats, json.encode(trimmed.values.map((e) => e.toJson()).toList()));
  }

  static String _key(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Record/overwrite today's totals (called after every successful sync).
  static Future<void> recordToday({
    required int steps,
    required double distanceKm,
    required int activeKcal,
  }) async {
    final map = await _load();
    map[_key(DateTime.now())] = DailyStat(
      date: _key(DateTime.now()),
      steps: steps,
      distanceKm: distanceKm,
      activeKcal: activeKcal,
    );
    await _save(map);
  }

  /// Today's stored totals (may lag behind live sync — callers prefer live).
  static Future<DailyStat?> getToday() async {
    final map = await _load();
    return map[_key(DateTime.now())];
  }

  /// Average steps across the last [days] days that have data.
  /// Returns null when there is no history yet.
  static Future<double?> avgSteps({int days = 7}) async => _avg(days, (s) => s.steps.toDouble());

  /// Average active kcal across the last [days] days with data.
  static Future<double?> avgActiveKcal({int days = 7}) async => _avg(days, (s) => s.activeKcal.toDouble());

  /// Average distance (km/day) across the last [days] days with data.
  static Future<double?> avgDistanceKm({int days = 7}) async => _avg(days, (s) => s.distanceKm);

  /// How many of the last [days] days actually have recorded data.
  static Future<int> daysWithData({int days = 7}) async {
    final map = await _load();
    final now = DateTime.now();
    int count = 0;
    for (int i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      if (map.containsKey(_key(d))) count++;
    }
    return count;
  }

  static Future<double?> _avg(int days, double Function(DailyStat) pick) async {
    final map = await _load();
    final now = DateTime.now();
    double sum = 0;
    int n = 0;
    for (int i = 1; i <= days; i++) {
      final stat = map[_key(now.subtract(Duration(days: i)))];
      if (stat == null) continue;
      sum += pick(stat);
      n++;
    }
    if (n == 0) return null;
    return sum / n;
  }

  // ─── Quest completion outcomes (drives adaptive difficulty) ─────────

  /// Record how today's quest went: fraction of objectives completed (0..1).
  static Future<void> recordQuestOutcome(double fraction) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQuestOutcome);
    final map = <String, double>{};
    if (raw != null) {
      try {
        (json.decode(raw) as Map<String, dynamic>).forEach((k, v) {
          map[k] = (v as num).toDouble();
        });
      } catch (_) {}
    }
    map[_key(DateTime.now())] = fraction.clamp(0.0, 1.0);
    // keep 30 days
    final keys = map.keys.toList()..sort();
    final trimmed = <String, double>{};
    for (final k in keys.skip(keys.length > _maxDays ? keys.length - _maxDays : 0)) {
      trimmed[k] = map[k]!;
    }
    await prefs.setString(_kQuestOutcome, json.encode(trimmed));
  }

  /// Completion rate over the stored window (0.5 default when no history).
  static Future<double> questCompletionRate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQuestOutcome);
    if (raw == null) return 0.5;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      if (map.isEmpty) return 0.5;
      final vals = map.values.map((v) => (v as num).toDouble()).toList();
      return vals.fold<double>(0, (s, v) => s + v) / vals.length;
    } catch (_) {
      return 0.5;
    }
  }
}
