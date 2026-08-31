import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'package:storage/storage.dart';
import 'package:core_domain/core_domain.dart';

/// Backs up and restores ALL user data (player, quests, health, hydration,
/// mood, body measurements, workouts, food log, achievements, settings).
class BackupService {
  static const _version = 2;

  /// All SharedPreferences keys that HealthOK uses.
  /// NOTE: 'gemini_api_key' is deliberately NOT backed up (secret material —
  /// backup files get shared via the share sheet).
  static const _prefKeys = [
    'hok_player',
    'hok_quest',
    'hok_quest_date',
    'hok_completed',
    'hok_hydration',
    'hok_hydration_date',
    'hok_hydration_goal_ml',
    'hok_mood_entries',
    'hok_body_measurements',
    'hok_workout_entries',
    'hok_food_entries',
    'hok_achievements_unlocked',
    'theme_mode',
    'coach_personality',
    'hydration_notifs',
    'streak_notifs',
    'voice_enabled',
    'briefing_enabled',
    'gemini_enabled',
    'onboarding_done',
  ];

  /// Export all user data to a JSON file and return the file path.
  static Future<String> exportToFile() async {
    final appDb = await AppDatabase.open();

    // Collect health samples from local DB
    final samples = <Map<String, dynamic>>[];
    for (final type in [
      HealthDataType.steps,
      HealthDataType.distance,
      HealthDataType.activeEnergy,
    ]) {
      final rows = await appDb.getSamplesForType(type);
      samples.addAll(rows.map((s) => {
        'id': s.id,
        'type': s.type.name,
        'value': s.value,
        'startAt': s.startAt.millisecondsSinceEpoch,
        'endAt': s.endAt.millisecondsSinceEpoch,
        'source': s.source.id,
        'createdAt': s.createdAt.millisecondsSinceEpoch,
      }));
    }

    // Collect all SharedPreferences data
    final prefs = await SharedPreferences.getInstance();
    final prefData = <String, dynamic>{};
    for (final key in _prefKeys) {
      final value = prefs.get(key);
      if (value != null) {
        prefData[key] = value;
      }
    }

    // Collect hydration history file if exists
    final dir = await getApplicationDocumentsDirectory();
    final hydrationFile = File(p.join(dir.path, 'hydration_history.txt'));
    if (hydrationFile.existsSync()) {
      prefData['hydration_history'] = await hydrationFile.readAsString();
    }

    // Collect food log photos directory
    final photosDir = Directory(p.join(dir.path, 'food_photos'));
    if (photosDir.existsSync()) {
      prefData['food_photo_count'] = photosDir.listSync().length;
    }

    final backup = {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'HealthOK',
      'data': {
        'preferences': prefData,
        'samples': samples,
      },
    };

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFile = File(p.join(dir.path, 'healthok-backup-$timestamp.json'));
    await backupFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
    );
    return backupFile.path;
  }

  /// List available backup files.
  static Future<List<File>> listAvailableBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('healthok-backup-') &&
            f.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Import data from a backup file. Returns true on success.
  static Future<bool> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final content = await file.readAsString();

    try {
      final backup = jsonDecode(content) as Map<String, dynamic>;
      if (backup['app'] != 'HealthOK') return false;

      final data = backup['data'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      // Import all preferences
      final prefData = data['preferences'] as Map<String, dynamic>?;
      if (prefData != null) {
        for (final entry in prefData.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key == 'hydration_history') {
            // Restore hydration history file
            final dir = await getApplicationDocumentsDirectory();
            final hydrationFile = File(p.join(dir.path, 'hydration_history.txt'));
            await hydrationFile.writeAsString(value as String);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is List) {
            await prefs.setStringList(
              key,
              value.map((e) => e.toString()).toList(),
            );
          }
        }
      }

      // Restore health samples (previously exported but never restored!)
      final sampleData = data['samples'] as List<dynamic>?;
      if (sampleData != null && sampleData.isNotEmpty) {
        final appDb = await AppDatabase.open();
        final restored = <Sample>[];
        for (final raw in sampleData) {
          try {
            final m = raw as Map<String, dynamic>;
            final typeName = m['type'] as String?;
            final type = HealthDataType.values
                .where((t) => t.name == typeName)
                .firstOrNull;
            if (type == null) continue;
            restored.add(Sample(
              id: (m['id'] as String?) ??
                  '${m['startAt']}_${type.name}_${m['source']}',
              type: type,
              startAt: DateTime.fromMillisecondsSinceEpoch(m['startAt'] as int),
              endAt: DateTime.fromMillisecondsSinceEpoch(m['endAt'] as int),
              value: (m['value'] as num?)?.toDouble(),
              source: (m['source'] == 'health_connect')
                  ? Source.healthConnect()
                  : Source.local(),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  (m['createdAt'] as int?) ?? (m['startAt'] as int)),
            ));
          } catch (_) {
            // Skip malformed rows — restore the rest
          }
        }
        if (restored.isNotEmpty) {
          await appDb.insertSamples(restored);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Share the exported backup file via system share sheet.
  static Future<void> shareBackup() async {
    final path = await exportToFile();
    await Share.shareXFiles(
      [XFile(path)],
      text: 'HealthOK Backup',
      subject: 'My HealthOK Data',
    );
  }

  /// Get a summary of what would be exported.
  static Future<BackupSummary> getSummary() async {
    final appDb = await AppDatabase.open();
    int sampleCount = 0;
    for (final type in [
      HealthDataType.steps,
      HealthDataType.distance,
      HealthDataType.activeEnergy,
    ]) {
      final rows = await appDb.getSamplesForType(type);
      sampleCount += rows.length;
    }
    final prefs = await SharedPreferences.getInstance();
    return BackupSummary(
      sampleCount: sampleCount,
      hasPlayer: prefs.getString('hok_player') != null,
      hasQuest: prefs.getString('hok_quest') != null,
      hasHydration: prefs.getString('hok_hydration') != null,
      hasMood: prefs.getString('hok_mood_entries') != null,
      hasBody: prefs.getString('hok_body_measurements') != null,
      hasWorkouts: prefs.getString('hok_workout_entries') != null,
      hasFood: prefs.getString('hok_food_entries') != null,
      hasAchievements: prefs.getString('hok_achievements_unlocked') != null,
    );
  }
}

class BackupSummary {
  final int sampleCount;
  final bool hasPlayer;
  final bool hasQuest;
  final bool hasHydration;
  final bool hasMood;
  final bool hasBody;
  final bool hasWorkouts;
  final bool hasFood;
  final bool hasAchievements;

  const BackupSummary({
    required this.sampleCount,
    required this.hasPlayer,
    required this.hasQuest,
    this.hasHydration = false,
    this.hasMood = false,
    this.hasBody = false,
    this.hasWorkouts = false,
    this.hasFood = false,
    this.hasAchievements = false,
  });

  int get totalCategories => [
    hasPlayer,
    hasQuest,
    hasHydration,
    hasMood,
    hasBody,
    hasWorkouts,
    hasFood,
    hasAchievements,
  ].where((b) => b).length;
}
