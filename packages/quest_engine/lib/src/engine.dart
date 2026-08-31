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
  /// Generates today's daily quest.
  ///
  /// Difficulty adapts on TWO axes:
  ///  - Long-term: level scales the WHO-anchored floor; streak adds up to
  ///    +25% pressure (the System expects more from consistent hunters).
  ///  - Short-term/PERSONAL: [recentAvgSteps], [recentAvgKcal] and
  ///    [questCompletionRate] bend targets toward what this hunter actually
  ///    does. Someone averaging 9k steps gets a 9.5k-class target, not a
  ///    generic 3k; someone completing under 50% of objectives gets eased
  ///    ~15% so quests stay motivating instead of demoralizing.
  /// Exercise anchors rotate daily; [hydrationGoalMl] plugs the user's own
  /// water goal in as a tracked objective.
  QuestSet generateDaily(
    Player p, {
    DateTime? now,
    int? hydrationGoalMl,
    double? recentAvgSteps,
    double? recentAvgKcal,
    double questCompletionRate = 0.5,
  }) {
    final t = now ?? DateTime.now();
    final expires = DateTime(t.year, t.month, t.day + 1); // midnight

    // Streak pressure: +1% per streak day, capped at +25%.
    final streakMult = 1.0 + (p.streakDays.clamp(0, 25)) / 100.0;

    // Achievement pressure: >80% recent completion pushes +10%,
    // <50% eases -15% (targets stay in the achievable-but-stretching band).
    final rate = questCompletionRate.clamp(0.0, 1.0);
    final adaptMult = rate > 0.8 ? 1.10 : (rate < 0.5 ? 0.85 : 1.0);

    final objectives = <Objective>[];

    // Steps: blend the level target with the personal 7-day average —
    // the personal average wins when it is meaningfully higher.
    final levelSteps = _clamp(3000.0 + 500 * (p.level - 1), 3000, 20000);
    double stepsTarget;
    if (recentAvgSteps != null && recentAvgSteps >= 1000) {
      final personal = recentAvgSteps * 1.05; // +5% stretch over your average
      stepsTarget = (personal > levelSteps ? personal : levelSteps) *
          streakMult *
          adaptMult;
    } else {
      stepsTarget = levelSteps * streakMult * adaptMult;
    }
    objectives.add(Objective(
      code: 'steps',
      label: 'Steps',
      target: _roundTo(stepsTarget.clamp(2000.0, 25000.0), 100),
      unit: 'steps',
      stat: Stat.agility,
      isAuto: true,
    ));

    // Active calories: personal 7-day average when known.
    final levelKcal = _clamp(100.0 + 30 * (p.level - 1), 100, 800);
    double kcalTarget;
    if (recentAvgKcal != null && recentAvgKcal >= 50) {
      kcalTarget = recentAvgKcal * 1.05 * adaptMult;
    } else {
      kcalTarget = levelKcal * streakMult * adaptMult;
    }
    objectives.add(Objective(
      code: 'activecalories',
      label: 'Active Calories',
      target: _roundTo(kcalTarget.clamp(80.0, 1200.0), 10),
      unit: 'kcal',
      stat: Stat.vitality,
      isAuto: true,
    ));

    // Distance: derived from the steps target via a ~0.72 m stride so steps
    // and distance stay mutually consistent.
    objectives.add(Objective(
      code: 'distance',
      label: 'Distance',
      target:
          (stepsTarget.clamp(2000.0, 25000.0) * 0.00072).clamp(1.0, 20.0),
      unit: 'km',
      stat: Stat.agility,
      isAuto: true,
    ));

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

    // Exercise objectives (manual tap) — rotate 2 of 3 daily for variety,
    // scaled by streak + achievement pressure.
    final daySeed = t.year * 366 + t.month * 31 + t.day;
    final rotated = [..._exerciseAnchors]
      ..shuffle(Random(daySeed));
    for (final a in rotated.take(2)) {
      final base = a.floor + a.perLevel * (p.level - 1);
      final target = base * streakMult * adaptMult;
      objectives.add(Objective(
        code: a.label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''),
        label: a.label,
        target: target.roundToDouble().clamp(a.floor, a.cap),
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

  /// Round [v] to the nearest [step] (e.g. step=100 → 3200, not 3247.13).
  double _roundTo(double v, int step) =>
      (v / step).roundToDouble() * step;

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
