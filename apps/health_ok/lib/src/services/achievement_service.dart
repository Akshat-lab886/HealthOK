import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an achievement that can be unlocked.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool Function(AchievementContext ctx) isUnlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

/// Context passed to check whether an achievement is unlocked.
class AchievementContext {
  final int level;
  final int streakDays;
  final int bestStreak;
  final int totalXp;
  final int unspentPoints;
  final int strength;
  final int agility;
  final int vitality;
  final int intelligence;
  final int perception;
  final int totalStepsLast7Days;
  final int totalDistanceLast7Days;
  final int totalQuestsCompleted;

  AchievementContext({
    required this.level,
    required this.streakDays,
    required this.bestStreak,
    required this.totalXp,
    required this.unspentPoints,
    required this.strength,
    required this.agility,
    required this.vitality,
    required this.intelligence,
    required this.perception,
    required this.totalStepsLast7Days,
    required this.totalDistanceLast7Days,
    required this.totalQuestsCompleted,
  });
}

class AchievementService {
  static const _kUnlocked = 'hok_achievements_unlocked';

  /// All achievements in the game.
  static final List<Achievement> all = [
    // Milestones
    Achievement(
      id: 'first_step',
      title: 'First Step',
      description: 'Complete your first quest',
      icon: '👣',
      isUnlocked: (ctx) => ctx.totalQuestsCompleted >= 1,
    ),
    Achievement(
      id: 'rising_hunter',
      title: 'Rising Hunter',
      description: 'Reach level 5',
      icon: '⬆️',
      isUnlocked: (ctx) => ctx.level >= 5,
    ),
    Achievement(
      id: 'veteran',
      title: 'Veteran',
      description: 'Reach level 10',
      icon: '🎖️',
      isUnlocked: (ctx) => ctx.level >= 10,
    ),
    // Streaks
    Achievement(
      id: 'streak_3',
      title: 'On a Roll',
      description: '3-day perfect streak',
      icon: '🔥',
      isUnlocked: (ctx) => ctx.bestStreak >= 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Week Warrior',
      description: '7-day perfect streak',
      icon: '⚡',
      isUnlocked: (ctx) => ctx.bestStreak >= 7,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Iron Discipline',
      description: '30-day perfect streak',
      icon: '🏆',
      isUnlocked: (ctx) => ctx.bestStreak >= 30,
    ),
    // Activity
    Achievement(
      id: 'walker',
      title: 'Walker',
      description: 'Walk 50,000 steps in a week',
      icon: '🚶',
      isUnlocked: (ctx) => ctx.totalStepsLast7Days >= 50000,
    ),
    Achievement(
      id: 'marathoner',
      title: 'Marathoner',
      description: 'Walk 100,000 steps in a week',
      icon: '🏃',
      isUnlocked: (ctx) => ctx.totalStepsLast7Days >= 100000,
    ),
    Achievement(
      id: 'explorer',
      title: 'Explorer',
      description: 'Travel 30 km in a week',
      icon: '🗺️',
      isUnlocked: (ctx) => ctx.totalDistanceLast7Days >= 30,
    ),
    // Stats
    Achievement(
      id: 'stat_max',
      title: 'Stat Master',
      description: 'Reach 20 in any stat',
      icon: '💪',
      isUnlocked: (ctx) =>
          ctx.strength >= 20 ||
          ctx.agility >= 20 ||
          ctx.vitality >= 20 ||
          ctx.intelligence >= 20 ||
          ctx.perception >= 20,
    ),
  ];

  /// Get the set of unlocked achievement IDs.
  static Future<Set<String>> getUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kUnlocked) ?? []).toSet();
  }

  /// Save the unlocked achievements.
  static Future<void> saveUnlocked(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kUnlocked, ids.toList());
  }

  /// Check all achievements and return newly unlocked ones.
  static Future<List<Achievement>> checkAndUnlock(AchievementContext ctx) async {
    final unlocked = await getUnlocked();
    final newlyUnlocked = <Achievement>[];
    for (final ach in all) {
      if (!unlocked.contains(ach.id) && ach.isUnlocked(ctx)) {
        unlocked.add(ach.id);
        newlyUnlocked.add(ach);
      }
    }
    if (newlyUnlocked.isNotEmpty) {
      await saveUnlocked(unlocked);
    }
    return newlyUnlocked;
  }

  /// Get progress (0.0 to 1.0) for each achievement.
  static double progress(Achievement ach, AchievementContext ctx) {
    if (ach.isUnlocked(ctx)) return 1.0;
    // Provide rough progress estimates for locked achievements
    switch (ach.id) {
      case 'first_step':
        return (ctx.totalQuestsCompleted / 1).clamp(0.0, 1.0);
      case 'rising_hunter':
        return (ctx.level / 5).clamp(0.0, 1.0);
      case 'veteran':
        return (ctx.level / 10).clamp(0.0, 1.0);
      case 'streak_3':
        return (ctx.bestStreak / 3).clamp(0.0, 1.0);
      case 'streak_7':
        return (ctx.bestStreak / 7).clamp(0.0, 1.0);
      case 'streak_30':
        return (ctx.bestStreak / 30).clamp(0.0, 1.0);
      case 'walker':
        return (ctx.totalStepsLast7Days / 50000).clamp(0.0, 1.0);
      case 'marathoner':
        return (ctx.totalStepsLast7Days / 100000).clamp(0.0, 1.0);
      case 'explorer':
        return (ctx.totalDistanceLast7Days / 30).clamp(0.0, 1.0);
      case 'stat_max':
        final max = [
          ctx.strength,
          ctx.agility,
          ctx.vitality,
          ctx.intelligence,
          ctx.perception,
        ].reduce((a, b) => a > b ? a : b);
        return (max / 20).clamp(0.0, 1.0);
      default:
        return 0.0;
    }
  }
}
