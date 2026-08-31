import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Tracks daily hydration (water intake) with manual logging.
class HydrationService {
  static const _kKey = 'hok_hydration';
  static const _kDate = 'hok_hydration_date';
  static const _kGoal = 'hok_hydration_goal_ml';

  static int _today(DateTime now) =>
      now.year * 10000 + now.month * 100 + now.day;

  static Future<int> getTodayMl() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _today(DateTime.now());
    final storedDate = prefs.getInt(_kDate) ?? 0;
    if (storedDate != dateKey) {
      await prefs.setInt(_kDate, dateKey);
      await prefs.setInt(_kKey, 0);
      return 0;
    }
    return prefs.getInt(_kKey) ?? 0;
  }

  static Future<int> getGoalMl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kGoal) ?? 2000; // default 2L
  }

  /// Suggested goal: 33 ml/kg body weight + activity bonus (300–500 ml).
  /// [weightKg] defaults to 70 kg; [stepsToday] scales the activity bonus.
  static int suggestGoalMl({double? weightKg, int stepsToday = 0}) {
    final weight = (weightKg ?? 70).clamp(40.0, 150.0);
    int target = (weight * 33).round();
    if (stepsToday > 8000) {
      target += 500;
    } else if (stepsToday > 4000) {
      target += 300;
    }
    return (target ~/ 100) * 100; // round to nearest 100 ml
  }

  /// Weekly average intake in ml (0 when no history).
  static Future<int> weeklyAverageMl() async {
    final days = await getLast7Days();
    if (days.every((d) => d == 0)) return 0;
    final sum = days.fold<int>(0, (s, d) => s + d);
    return (sum / days.length).round();
  }

  static Future<void> setGoalMl(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGoal, goal);
  }

  static Future<int> addWater(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getTodayMl();
    final newValue = current + ml;
    await prefs.setInt(_kKey, newValue);
    return newValue;
  }

  static Future<int> removeWater(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getTodayMl();
    final newValue = (current - ml).clamp(0, 100000);
    await prefs.setInt(_kKey, newValue);
    return newValue;
  }

  static Future<List<int>> getLast7Days() async {
    // Read from a flat file if exists, otherwise just today
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'hydration_history.txt'));
    if (!file.existsSync()) return List.filled(7, 0);
    try {
      final lines = await file.readAsLines();
      final now = DateTime.now();
      final result = <int>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final key = _today(day);
        final lineIdx = lines.indexWhere((l) => l.startsWith('$key:'));
        if (lineIdx >= 0) {
          result.add(int.tryParse(lines[lineIdx].split(':')[1]) ?? 0);
        } else {
          result.add(0);
        }
      }
      return result;
    } catch (e) {
      return List.filled(7, 0);
    }
  }

  static Future<void> archiveToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = await getTodayMl();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'hydration_history.txt'));
    final key = _today(DateTime.now());
    final line = '$key:$today';
    try {
      List<String> lines = file.existsSync() ? await file.readAsLines() : [];
      lines.removeWhere((l) => l.startsWith('$key:'));
      lines.add(line);
      // Keep last 60 days
      if (lines.length > 60) {
        lines = lines.sublist(lines.length - 60);
      }
      await file.writeAsString(lines.join('\n'));
    } catch (e) {
    }
    await prefs.setInt(_kKey, 0);
  }
}
