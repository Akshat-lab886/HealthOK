import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quest_engine/quest_engine.dart';
import 'hydration_service.dart';
import 'daily_stats_service.dart';

/// Persists player state, daily quests, and completed objectives.
/// Handles auto-completion of health-data objectives.
class QuestService {
  static const _kPlayer = 'hok_player';
  static const _kQuest = 'hok_quest';
  static const _kCompleted = 'hok_completed';
  static const _kQuestDate = 'hok_quest_date';

  /// Load the persisted player, or return default.
  static Future<Player> loadPlayer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kPlayer);
      if (json != null) {
        return Player.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
    }
    return const Player();
  }

  /// Save the player to disk.
  static Future<void> savePlayer(Player player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlayer, jsonEncode(player.toJson()));
  }

  /// Load today's quest. Returns null if expired or missing.
  static Future<QuestSet?> loadQuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString(_kQuestDate);
      if (dateStr == null) return null;

      final questDate = DateTime.parse(dateStr);
      final now = DateTime.now();
      // Quest expired if it's from a previous day
      if (questDate.year != now.year ||
          questDate.month != now.month ||
          questDate.day != now.day) {
        return null;
      }

      final json = prefs.getString(_kQuest);
      if (json != null) {
        return QuestSet.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
    }
    return null;
  }

  /// Save quest + date to disk.
  static Future<void> saveQuest(QuestSet quest) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_kQuestDate,
        DateTime(now.year, now.month, now.day).toIso8601String());
    await prefs.setString(_kQuest, jsonEncode(quest.toJson()));
  }

  /// Load completed objective indices.
  static Future<Set<int>> loadCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kCompleted);
      if (list == null) return {};
      final dateStr = prefs.getString(_kQuestDate);
      if (dateStr == null) return {};
      final questDate = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (questDate.year != now.year ||
          questDate.month != now.month ||
          questDate.day != now.day) {
        return {};
      }
      return list.map(int.parse).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Save completed objective indices.
  static Future<void> saveCompleted(Set<int> completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kCompleted, completed.map((i) => i.toString()).toList());
  }

  /// Full load: player + today's quest + completed objectives.
  static Future<QuestState> loadAll() async {
    final player = await loadPlayer();
    var quest = await loadQuest();
    var completed = await loadCompleted();

    // Generate new quest when none stored OR the stored one expired
    // (expiresAt is midnight of the day it was generated for).
    // Targets are PERSONALIZED: they bend toward the user's real 7-day
    // averages and their recent quest-completion rate.
    final engine = const QuestEngine();
    final now = DateTime.now();
    final needsNew = quest == null || !quest.expiresAt.isAfter(now);
    if (needsNew) {
      final hydrationGoal = await HydrationService.getGoalMl();
      final avgSteps = await DailyStatsService.avgSteps();
      final avgKcal = await DailyStatsService.avgActiveKcal();
      final completionRate = await DailyStatsService.questCompletionRate();
      quest = engine.generateDaily(
        player,
        now: now,
        hydrationGoalMl: hydrationGoal,
        recentAvgSteps: avgSteps,
        recentAvgKcal: avgKcal,
        questCompletionRate: completionRate,
      );
      await saveQuest(quest);
      completed = {};
      await saveCompleted({});
    }

    return QuestState(player: player, quest: quest, completed: completed);
  }

  /// Save everything after auto-completion. Also records today's completion
  /// fraction so tomorrow's quest difficulty can adapt to the user's
  /// actual success rate (personalized difficulty).
  static Future<void> saveAll({
    required Player player,
    required QuestSet quest,
    required Set<int> completed,
  }) async {
    await savePlayer(player);
    await saveQuest(quest);
    await saveCompleted(completed);
    if (quest.objectives.isNotEmpty) {
      await DailyStatsService.recordQuestOutcome(
          completed.length / quest.objectives.length);
    }
  }
}

class QuestState {
  final Player player;
  final QuestSet quest;
  final Set<int> completed;

  const QuestState({
    required this.player,
    required this.quest,
    required this.completed,
  });
}
