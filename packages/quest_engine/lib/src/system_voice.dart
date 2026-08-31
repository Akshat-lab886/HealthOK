/// System Voice copy — terse, imperative, second person, reward-focused.
///
/// Tone guide: docs/05-quest-system.md §9. Strings start with `[`-bracketed
/// motifs; they are i18n keys by design but ship as literals in v1.
class SystemVoice {
  const SystemVoice._();

  static const dailyArrived = '[DAILY QUEST ARRIVED]';
  static const questComplete = '[QUEST COMPLETE]';
  static const levelUp = '[LEVEL UP!]';
  static const warning = '[WARNING]';
  static const restIssued = '[REST QUEST ISSUED]';

  static String complete(int xp) => 'You have earned $xp XP. Consistency acknowledged.';

  static String levelUpMessage(int from, int to) =>
      'Lv $from → $to. +3 stat points available. Your shadow grows stronger.';

  static String offerFor(String rankLabel) =>
      'The System has prepared your daily quest, $rankLabel-rank. Failure has consequences.';
}