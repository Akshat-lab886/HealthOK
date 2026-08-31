import 'dart:convert';
import 'dart:math';
import 'player.dart';
import 'quest.dart';
import 'system_voice.dart';

/// XP award for completing a single daily objective.
const int xpPerObjective = 15;

/// Bonus XP for a "perfect day" (all objectives).
const int perfectDayBonus = 10;

/// The arithmetic level curve from docs/05 §4:
/// `xpToNext(n) = 100 + 25·(n-1)`.
int xpToNext(int level) => 100 + 25 * (level - 1);

/// Result of awarding XP: the updated player plus any level-up that occurred.
class XpResult {
  const XpResult({required this.player, required this.levelsGained});

  final Player player;
  final int levelsGained;
}

/// WHO-anchored volume anchors from docs/05 §3.2.
class _Anchor {
  const _Anchor(this.label, this.unit, this.floor, this.perLevel, this.cap);
  final String label;
  final String unit;
  final double floor;
  final double perLevel;
  final double cap;
}

/// Health-data-driven anchors — these connect to real device sensors.
const _healthAnchors = <_Anchor>[
  _Anchor('Steps', 'steps', 3000, 500, 20000),
  _Anchor('Distance', 'km', 1.5, 0.25, 10),
  _Anchor('Active Calories', 'kcal', 100, 30, 800),
];

/// Manual/exercise anchors — user must tap to complete.
const _exerciseAnchors = <_Anchor>[
  _Anchor('Push-ups', 'reps', 10, 2, 100),
  _Anchor('Sit-ups', 'reps', 15, 3, 100),
  _Anchor('Squats', 'reps', 15, 3, 100),
];

/// Maps objective codes to health-data keys for auto-completion.
/// 'hydration' is fed from the local water log, not Health Connect.
const healthDataMap = <String, String>{
  'steps': 'steps',
  'distance': 'distance',
  'activecalories': 'activeEnergy',
  'hydration': 'waterMl',
};

/// A pure, deterministic engine for "The System".
class QuestEngine {
  const QuestEngine();

  /// Awards [amount] XP, applying level-ups and +3 free points per level.
  XpResult awardXp(Player p, int amount) {
    var level = p.level;
    var xp = p.xp + amount;
    var unspent = p.unspentPoints;
    var levels = 0;

    while (xp >= xpToNext(level)) {
      xp -= xpToNext(level);
      level += 1;
      unspent += 3;
      levels += 1;
    }

    return XpResult(
      player: p.copyWith(level: level, xp: xp, unspentPoints: unspent),
      levelsGained: levels,
    );
  }

  /// Generates today's daily quest with both health-data and exercise objectives.
  ///
  /// Difficulty adapts to the player:
  ///  - Level scales targets linearly (WHO-anchored floors/caps).
  ///  - Streak adds up to +25% target pressure (consistency tax — the System
  ///    expects more from hunters who never miss a day).
  ///  - Exercise anchors rotate daily so training varies instead of always
  ///    being push-ups / sit-ups / squats.
  /// [hydrationGoalMl] plugs the user's own water goal in as a tracked quest.
  QuestSet generateDaily(Player p, {DateTime? now, int? hydrationGoalMl}) {
    final t = now ?? DateTime.now();
    final expires = DateTime(t.year, t.month, t.day + 1); // midnight

    // Streak pressure: +1% per streak day, capped at +25%.
    final streakMult = 1.0 + (p.streakDays.clamp(0, 25)) / 100.0;

    final objectives = <Objective>[];

    // Health-data objectives (auto-tracked), scaled by level × streak
    for (final a in _healthAnchors) {
      final base = a.floor + a.perLevel * (p.level - 1);
      final target = _clamp(base * streakMult, a.floor, a.cap);
      objectives.add(Objective(
        code: a.label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''),
        label: a.label,
        target: target,
        unit: a.unit,
        stat: _statFor(a.label),
        isAuto: true,
      ));
    }

    // Hydration objective (auto-tracked from local water log)
    final waterTarget =
        _clamp((hydrationGoalMl ?? 2000).toDouble(), 1000, 5000);
    objectives.add(Objective(
      code: 'hydration',
      label: 'Hydration',
      target: waterTarget,
      unit: 'ml',
      stat: Stat.vitality,
      isAuto: true,
    ));

    // Exercise objectives (manual tap) — rotate 2 of 3 daily for variety
    final daySeed = t.year * 366 + t.month * 31 + t.day;
    final rotated = [..._exerciseAnchors]
      ..shuffle(Random(daySeed));
    for (final a in rotated.take(2)) {
      final base = a.floor + a.perLevel * (p.level - 1);
      final target = _clamp(base * streakMult, a.floor, a.cap);
      objectives.add(Objective(
        code: a.label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''),
        label: a.label,
        target: target,
        unit: a.unit,
        stat: _statFor(a.label),
        isAuto: false,
      ));
    }

    return QuestSet(
      title: '${SystemVoice.dailyArrived} ${SystemVoice.offerFor(p.rank.label)}',
      objectives: objectives,
      kind: QuestKind.daily,
      expiresAt: expires,
    );
  }

  /// Checks which auto objectives are met given today's health data.
  /// Returns a list of objective indices that should be auto-completed.
  List<int> checkHealthData({
    required QuestSet quest,
    required Map<String, double> healthData,
    required Set<int> alreadyCompleted,
  }) {
    final toComplete = <int>[];
    for (int i = 0; i < quest.objectives.length; i++) {
      if (alreadyCompleted.contains(i)) continue;
      final obj = quest.objectives[i];
      if (!obj.isAuto) continue;

      final dataKey = healthDataMap[obj.code];
      if (dataKey == null) continue;

      final currentValue = healthData[dataKey] ?? 0;
      if (currentValue >= obj.target) {
        toComplete.add(i);
      }
    }
    return toComplete;
  }

  /// Rank ladder with rolling completion-rate gates (docs/05 §6).
  Rank rankFor({
    required int level,
    required double completionRate, // 0..1
    required int bossClears,
  }) {
    if (level >= 40 && completionRate >= 0.85 && bossClears >= 10) return Rank.s;
    if (level >= 30 && completionRate >= 0.80 && bossClears >= 6) return Rank.a;
    if (level >= 20 && completionRate >= 0.75 && bossClears >= 3) return Rank.b;
    if (level >= 12 && completionRate >= 0.70 && bossClears >= 1) return Rank.c;
    if (level >= 5 && completionRate >= 0.70) return Rank.d;
    return Rank.e;
  }

  double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  Stat _statFor(String label) {
    switch (label) {
      case 'Push-ups':
      case 'Sit-ups':
      case 'Squats':
        return Stat.strength;
      case 'Steps':
      case 'Distance':
        return Stat.agility;
      case 'Active Calories':
        return Stat.vitality;
      default:
        return Stat.vitality;
    }
  }
}
