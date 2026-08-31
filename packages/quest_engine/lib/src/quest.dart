/// Quest domain objects for "The System".

enum QuestKind { daily, rest, boss, penalty, goalMilestone }

enum QuestStatus { offered, accepted, completed, failed, waived }

/// A single objective within a quest. Targets are scaled to the player's rank.
class Objective {
  const Objective({
    required this.code,
    required this.label,
    required this.target,
    required this.unit,
    this.stat = Stat.vitality,
    this.isAuto = false,
  });

  /// Stable template code, e.g. `steps`, `distance`.
  final String code;

  /// Human wording, e.g. "Steps", "Push-ups".
  final String label;

  final double target;

  /// Display unit, e.g. "reps", "km", "kcal".
  final String unit;

  /// Which stat this objective grows.
  final Stat stat;

  /// Whether this objective is auto-tracked from health data.
  final bool isAuto;

  Objective copyWith({double? target, bool? isAuto}) {
    return Objective(
      code: code,
      label: label,
      target: target ?? this.target,
      unit: unit,
      stat: stat,
      isAuto: isAuto ?? this.isAuto,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'target': target,
    'unit': unit,
    'stat': stat.name,
    'isAuto': isAuto,
  };

  factory Objective.fromJson(Map<String, dynamic> json) => Objective(
    code: json['code'] as String,
    label: json['label'] as String,
    target: (json['target'] as num).toDouble(),
    unit: json['unit'] as String,
    stat: Stat.values.firstWhere((s) => s.name == json['stat']),
    isAuto: json['isAuto'] as bool? ?? false,
  );
}

enum Stat {
  strength('STR', '💪'),
  agility('AGI', '🏃'),
  vitality('VIT', '❤️'),
  intelligence('INT', '🧠'),
  perception('PER', '👁️');

  const Stat(this.code, this.glyph);

  final String code;
  final String glyph;
}

/// A generated quest set: title + a list of objectives for the day.
class QuestSet {
  const QuestSet({
    required this.title,
    required this.objectives,
    this.kind = QuestKind.daily,
    required this.expiresAt,
  });

  final String title;
  final List<Objective> objectives;
  final QuestKind kind;
  final DateTime expiresAt;

  int get totalTarget => objectives.length;

  bool get isRest => kind == QuestKind.rest;

  QuestSet copyWith({
    String? title,
    List<Objective>? objectives,
    QuestKind? kind,
    DateTime? expiresAt,
  }) {
    return QuestSet(
      title: title ?? this.title,
      objectives: objectives ?? this.objectives,
      kind: kind ?? this.kind,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'objectives': objectives.map((o) => o.toJson()).toList(),
    'kind': kind.name,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory QuestSet.fromJson(Map<String, dynamic> json) => QuestSet(
    title: json['title'] as String,
    objectives: (json['objectives'] as List)
        .map((o) => Objective.fromJson(o as Map<String, dynamic>))
        .toList(),
    kind: QuestKind.values.firstWhere((k) => k.name == json['kind']),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}
