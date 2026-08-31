import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_ok/src/services/quest_service.dart';
import 'package:quest_engine/quest_engine.dart';

/// Simulated guild member for local comparison.
class GuildMember {
  final String name;
  final int level;
  final int stepsPerDay;
  final int streakDays;
  final String rank;
  final bool isPlayer;

  const GuildMember({
    required this.name,
    required this.level,
    required this.stepsPerDay,
    required this.streakDays,
    required this.rank,
    this.isPlayer = false,
  });
}

/// Provides a simulated guild leaderboard comparing player against AI bots.
class GuildService {
  // Bot archetypes: [name, levelOffsetFromPlayer, stepsBase, streakBase, rank]
  // Level offsets keep the guild competitive at any player level.
  static const _archetypes = [
    ('NightWalker', -2, 9200, 12, 'E'),
    ('IronPulse', 1, 14500, 30, 'D'),
    ('SwiftBlade', -4, 7800, 5, 'E'),
    ('ShadowVeil', 3, 16000, 45, 'C'),
    ('StormBreak', -6, 5500, 2, 'E'),
    ('CrystalFang', 0, 11000, 20, 'D'),
    ('NovaStar', 6, 18000, 60, 'B'),
  ];

  /// Bots are generated relative to the player's level so the leaderboard
  /// stays relevant: some rivals slightly ahead, some behind, all scaling.
  static List<GuildMember> _botsFor(int playerLevel) {
    return _archetypes.map((a) {
      final level = (playerLevel + a.$2).clamp(1, 60);
      final steps = (a.$3 * (0.8 + level * 0.04)).round();
      return GuildMember(
        name: a.$1,
        level: level,
        stepsPerDay: steps,
        streakDays: a.$4,
        rank: a.$5,
      );
    }).toList();
  }

  static Future<List<GuildMember>> getLeaderboard() async {
    final player = await QuestService.loadPlayer();
    final myMember = GuildMember(
      name: 'You',
      level: player.level,
      stepsPerDay: 0,
      streakDays: player.streakDays,
      rank: player.rank.name.toUpperCase(),
      isPlayer: true,
    );

    final board = [..._botsFor(player.level), myMember];
    board.sort((a, b) => b.level.compareTo(a.level) != 0
        ? b.level.compareTo(a.level)
        : b.stepsPerDay.compareTo(a.stepsPerDay));
    return board;
  }

  /// Player's current position (1-based). Null if data unavailable.
  static Future<int?> getPlayerPosition() async {
    final board = await getLeaderboard();
    for (int i = 0; i < board.length; i++) {
      if (board[i].isPlayer) return i + 1;
    }
    return null;
  }
}