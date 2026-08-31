/// A solo-leveling "Player" character.
///
/// Mirrors the singleton `player` row from docs/03-data-model.md §2.4.
class Player {
  const Player({
    this.level = 1,
    this.xp = 0,
    this.unspentPoints = 0,
    this.strength = 5,
    this.agility = 5,
    this.vitality = 5,
    this.intelligence = 5,
    this.perception = 5,
    this.rank = Rank.e,
    this.streakDays = 0,
    this.bestStreak = 0,
    this.shields = 0,
  });

  final int level;
  final int xp;

  /// Free stat points waiting to be allocated after a level-up.
  final int unspentPoints;

  final int strength;
  final int agility;
  final int vitality;
  final int intelligence;
  final int perception;

  final Rank rank;
  final int streakDays;
  final int bestStreak;
  final int shields;

  Player copyWith({
    int? level,
    int? xp,
    int? unspentPoints,
    int? strength,
    int? agility,
    int? vitality,
    int? intelligence,
    int? perception,
    Rank? rank,
    int? streakDays,
    int? bestStreak,
    int? shields,
  }) {
    return Player(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      unspentPoints: unspentPoints ?? this.unspentPoints,
      strength: strength ?? this.strength,
      agility: agility ?? this.agility,
      vitality: vitality ?? this.vitality,
      intelligence: intelligence ?? this.intelligence,
      perception: perception ?? this.perception,
      rank: rank ?? this.rank,
      streakDays: streakDays ?? this.streakDays,
      bestStreak: bestStreak ?? this.bestStreak,
      shields: shields ?? this.shields,
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'xp': xp,
    'unspentPoints': unspentPoints,
    'strength': strength,
    'agility': agility,
    'vitality': vitality,
    'intelligence': intelligence,
    'perception': perception,
    'rank': rank.name,
    'streakDays': streakDays,
    'bestStreak': bestStreak,
    'shields': shields,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    level: json['level'] as int? ?? 1,
    xp: json['xp'] as int? ?? 0,
    unspentPoints: json['unspentPoints'] as int? ?? 0,
    strength: json['strength'] as int? ?? 5,
    agility: json['agility'] as int? ?? 5,
    vitality: json['vitality'] as int? ?? 5,
    intelligence: json['intelligence'] as int? ?? 5,
    perception: json['perception'] as int? ?? 5,
    rank: Rank.values.firstWhere(
      (r) => r.name == json['rank'],
      orElse: () => Rank.e,
    ),
    streakDays: json['streakDays'] as int? ?? 0,
    bestStreak: json['bestStreak'] as int? ?? 0,
    shields: json['shields'] as int? ?? 0,
  );
}

/// Hunter grades, E (weakest) to S (strongest).
enum Rank {
  e('E'),
  d('D'),
  c('C'),
  b('B'),
  a('A'),
  s('S');

  const Rank(this.label);

  final String label;

  static Rank fromIndex(int i) {
    return Rank.values[i.clamp(0, Rank.values.length - 1)];
  }

  int get rankIndex => Rank.values.indexOf(this);
}
