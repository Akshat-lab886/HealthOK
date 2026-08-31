import 'package:flutter/material.dart';
import 'package:quest_engine/quest_engine.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/quest_service.dart';
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:health_ok/src/pages/ai_quest_sheet.dart';

class CharacterScreen extends StatefulWidget {
  final AiCoachService? coachService;

  const CharacterScreen({super.key, this.coachService});

  @override
  State<CharacterScreen> createState() => CharacterScreenState();
}

class CharacterScreenState extends State<CharacterScreen> {
  final QuestEngine _engine = const QuestEngine();
  Player _player = const Player();
  QuestSet _dailyQuest = QuestSet(
    title: '',
    objectives: const [],
    expiresAt: DateTime(2025),
  );
  final Set<int> _completedObjectives = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await QuestService.loadAll();
    if (!mounted) return;
    setState(() {
      _player = state.player;
      _dailyQuest = state.quest;
      _completedObjectives.clear();
      _completedObjectives.addAll(state.completed);
      _loading = false;
    });
  }

  /// Reload state from disk (called after sync auto-completes quests).
  Future<void> reloadState() async {
    final state = await QuestService.loadAll();
    if (!mounted) return;
    setState(() {
      _player = state.player;
      _dailyQuest = state.quest;
      _completedObjectives.clear();
      _completedObjectives.addAll(state.completed);
    });
  }

  /// Allocate unspent stat points to a stat.
  Future<void> allocateStatPoint(String stat, int amount) async {
    if (_player.unspentPoints < amount) return;

    final updated = switch (stat) {
      'STR' => _player.copyWith(
          strength: _player.strength + amount, unspentPoints: _player.unspentPoints - amount),
      'AGI' => _player.copyWith(
          agility: _player.agility + amount, unspentPoints: _player.unspentPoints - amount),
      'VIT' => _player.copyWith(
          vitality: _player.vitality + amount, unspentPoints: _player.unspentPoints - amount),
      'INT' => _player.copyWith(
          intelligence: _player.intelligence + amount, unspentPoints: _player.unspentPoints - amount),
      'PER' => _player.copyWith(
          perception: _player.perception + amount, unspentPoints: _player.unspentPoints - amount),
      _ => _player,
    };

    await QuestService.savePlayer(updated);
    if (!mounted) return;
    setState(() => _player = updated);
  }

  /// Update streak when a quest is completed perfectly.
  Future<void> updateStreakOnPerfectDay() async {
    final now = DateTime.now();
    final newStreak = _player.streakDays + 1;
    final newBest = newStreak > _player.bestStreak ? newStreak : _player.bestStreak;
    final updated = _player.copyWith(
      streakDays: newStreak,
      bestStreak: newBest,
    );
    await QuestService.savePlayer(updated);
    if (!mounted) return;
    setState(() => _player = updated);
  }

  /// Break the streak (used when daily quest is failed or app unused for a day).
  Future<void> breakStreak() async {
    if (_player.streakDays == 0) return;
    final updated = _player.copyWith(streakDays: 0);
    await QuestService.savePlayer(updated);
    if (!mounted) return;
    setState(() => _player = updated);
  }

  /// Use a shield to protect streak from breaking.
  Future<bool> useShield() async {
    if (_player.shields <= 0) return false;
    final updated = _player.copyWith(shields: _player.shields - 1);
    await QuestService.savePlayer(updated);
    if (!mounted) return true;
    setState(() => _player = updated);
    return true;
  }

  /// Called from MainScreen after health sync to auto-complete objectives.
  Future<void> checkAndAutoComplete(Map<String, double> healthData) async {
    final toComplete = _engine.checkHealthData(
      quest: _dailyQuest,
      healthData: healthData,
      alreadyCompleted: _completedObjectives,
    );

    if (toComplete.isEmpty) return;

    var player = _player;
    final newCompleted = Set<int>.from(_completedObjectives);

    for (final idx in toComplete) {
      final result = _engine.awardXp(player, xpPerObjective);
      player = result.player;
      newCompleted.add(idx);
    }

    // Check for perfect day
    if (newCompleted.length == _dailyQuest.objectives.length &&
        _dailyQuest.objectives.isNotEmpty) {
      final bonus = _engine.awardXp(player, perfectDayBonus);
      player = bonus.player;
      // Update streak
      final newStreak = _player.streakDays + 1;
      final newBest =
          newStreak > _player.bestStreak ? newStreak : _player.bestStreak;
      player = player.copyWith(streakDays: newStreak, bestStreak: newBest);
    }

    await QuestService.saveAll(
      player: player,
      quest: _dailyQuest,
      completed: newCompleted,
    );

    if (!mounted) return;
    setState(() {
      _player = player;
      _completedObjectives.addAll(newCompleted);
    });

    if (mounted) {
      final count = toComplete.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚡ $count objective${count > 1 ? 's' : ''} auto-completed! +${count * xpPerObjective} XP',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  void _completeObjective(int index) async {
    if (_completedObjectives.contains(index)) return;
    // Don't allow manual completion of auto objectives
    if (_dailyQuest.objectives[index].isAuto) return;

    final result = _engine.awardXp(_player, xpPerObjective);
    final newCompleted = Set<int>.from(_completedObjectives)..add(index);

    var player = result.player;

    // Check for perfect day
    if (newCompleted.length == _dailyQuest.objectives.length &&
        _dailyQuest.objectives.isNotEmpty) {
      final bonus = _engine.awardXp(player, perfectDayBonus);
      player = bonus.player;
      // Update streak
      final newStreak = _player.streakDays + 1;
      final newBest =
          newStreak > _player.bestStreak ? newStreak : _player.bestStreak;
      player = player.copyWith(streakDays: newStreak, bestStreak: newBest);
    }

    await QuestService.saveAll(
      player: player,
      quest: _dailyQuest,
      completed: newCompleted,
    );

    if (!mounted) return;
    setState(() {
      _player = player;
      _completedObjectives.add(index);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${SystemVoice.questComplete} ${SystemVoice.complete(xpPerObjective)}',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  /// Show the stat allocation dialog.
  void _showAllocateDialog() {
    if (_player.unspentPoints <= 0) return;
    showDialog(
      context: context,
      builder: (ctx) => _StatAllocationDialog(
        player: _player,
        onAllocate: allocateStatPoint,
      ),
    );
  }

  /// Show the AI quest suggestion bottom sheet.
  void _showAiSuggest() {
    if (widget.coachService == null) return;
    if (!widget.coachService!.isLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Load an AI model first in Coach tab'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AiQuestSuggestionSheet(
        coachService: widget.coachService!,
        player: _player,
        onApply: _applyAiSuggestions,
      ),
    );
  }

  /// Show the custom quest creation dialog.
  void _showCustomQuestDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:  Text('Add Custom Quest', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            hintText: 'e.g. Stretch for 10 minutes',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              _addCustomQuest(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Add a custom user-created quest objective.
  Future<void> _addCustomQuest(String label) async {
    if (_dailyQuest.objectives.length >= 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Max 6 quests per day'),
            backgroundColor: AppColors.energyColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final newObjective = Objective(
      code: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      target: 1,
      unit: 'rep',
      isAuto: false,
    );
    final updated = _dailyQuest.copyWith(
      objectives: [..._dailyQuest.objectives, newObjective],
    );
    await QuestService.saveQuest(updated);
    if (!mounted) return;
    setState(() {
      _dailyQuest = updated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Custom quest added: $label ✓'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Apply selected AI suggestions as new quest objectives.
  Future<void> _applyAiSuggestions(List<String> suggestions) async {
    if (suggestions.isEmpty) return;
    // Room for at most 6 objectives total — add only what fits and report
    // the real number (previously it silently dropped them all).
    const maxObjectives = 6;
    final room = (maxObjectives - _dailyQuest.objectives.length)
        .clamp(0, suggestions.length);
    if (room == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Quest board is full (6/6). Complete or wait for tomorrow\'s quest.'),
          backgroundColor: AppColors.energyColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final newObjectives = [
      ..._dailyQuest.objectives,
      ...suggestions.take(room).toList().asMap().entries.map((e) => Objective(
            code: 'ai_${stamp}_${e.key}',
            label: e.value,
            target: 1,
            unit: 'rep',
            isAuto: false,
          )),
    ];
    final updated = _dailyQuest.copyWith(objectives: newObjectives);
    await QuestService.saveQuest(updated);
    if (!mounted) return;
    setState(() {
      _dailyQuest = updated;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$room AI quest${room == 1 ? "" : "s"} added ✓'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration:  BoxDecoration(gradient: AppColors.bgGradient),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final nextLevelXp = xpToNext(_player.level);
    final progress = (_player.xp / nextLevelXp).clamp(0.0, 1.0);

    return Container(
      decoration:  BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Hunter',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HealthOK',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 30)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Hero Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _player.rank.label,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'RANK ${_player.rank.label}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            if (_player.unspentPoints > 0) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _showAllocateDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFBBF24)
                                            .withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded,
                                          color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '+${_player.unspentPoints} POINTS',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'LEVEL ${_player.level}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_player.xp} XP',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$nextLevelXp XP',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                minHeight: 12,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation(
                                    Colors.white),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Stats Grid ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatPill(
                              glyph: '⚔️',
                              label: 'STR',
                              value: _player.strength,
                              color: AppColors.energyColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              glyph: '💨',
                              label: 'AGI',
                              value: _player.agility,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              glyph: '❤️',
                              label: 'VIT',
                              value: _player.vitality,
                              color: const Color(0xFFEC4899),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _StatPill(
                              glyph: '🧠',
                              label: 'INT',
                              value: _player.intelligence,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              glyph: '👁️',
                              label: 'PER',
                              value: _player.perception,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatPill(
                              glyph: '🏆',
                              label: 'STREAK',
                              value: _player.streakDays,
                              color: AppColors.stepsColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Daily Quest ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's Quest",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              if (widget.coachService != null)
                                GestureDetector(
                                  onTap: _showAiSuggest,
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('✨', style: TextStyle(fontSize: 12)),
                                        SizedBox(width: 4),
                                        Text(
                                          'AI Suggest',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: _showCustomQuestDialog,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              if (_dailyQuest.objectives.isNotEmpty)
                                Text(
                                  '${_completedObjectives.length}/${_dailyQuest.objectives.length}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_dailyQuest.isRest)
                        _RestCard()
                      else
                        ..._dailyQuest.objectives.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final obj = entry.value;
                          final isComplete =
                              _completedObjectives.contains(idx);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ObjectiveCard(
                              objective: obj,
                              isComplete: isComplete,
                              current: isComplete ? obj.target : 0,
                              onTap: () => _completeObjective(idx),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              // ── System Voice ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('⬡',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _completedObjectives.length ==
                                    _dailyQuest.objectives.length
                                ? '[SYSTEM] All objectives cleared. The System acknowledges your resolve.'
                                : '[SYSTEM] ${SystemVoice.offerFor(_player.rank.label)}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom spacer ──
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Pill ───────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String glyph;
  final String label;
  final int value;
  final Color color;

  const _StatPill({
    required this.glyph,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(glyph, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Objective Card ──────────────────────────────────────────────────────────

class _ObjectiveCard extends StatelessWidget {
  final Objective objective;
  final bool isComplete;
  final double current;
  final VoidCallback onTap;

  const _ObjectiveCard({
    required this.objective,
    required this.isComplete,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = isComplete ? 1.0 : (current / objective.target).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: isComplete ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isComplete
                ? AppColors.success.withOpacity(0.3)
                : Theme.of(context).dividerColor.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: isComplete
                  ? AppColors.success.withOpacity(0.1)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: isComplete
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.success, size: 24)
                        : Text(objective.stat.glyph,
                            style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              objective.label,
                              style: TextStyle(
                                color: isComplete
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                decoration: isComplete
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (objective.isAuto)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AUTO',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${objective.target.toInt()} ${objective.unit}',
                        style:  TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // XP reward
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isComplete ? null : AppColors.primaryGradient,
                    color: isComplete ? Colors.transparent : null,
                    borderRadius: BorderRadius.circular(14),
                    border: isComplete
                        ? Border.all(color: AppColors.success)
                        : null,
                  ),
                  child: Text(
                    isComplete ? '✓' : '+$xpPerObjective',
                    style: TextStyle(
                      color: isComplete ? AppColors.success : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rest Card ───────────────────────────────────────────────────────────────

class _RestCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDDD6FE), Color(0xFFFBCFE8)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'REST DAY',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"Recovery is not retreating."',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Allocation Dialog ──────────────────────────────────────────────────

class _StatAllocationDialog extends StatefulWidget {
  final Player player;
  final Future<void> Function(String stat, int amount) onAllocate;

  const _StatAllocationDialog({required this.player, required this.onAllocate});

  @override
  State<_StatAllocationDialog> createState() => _StatAllocationDialogState();
}

class _StatAllocationDialogState extends State<_StatAllocationDialog> {
  final Map<String, int> _pending = {};

  @override
  Widget build(BuildContext context) {
    final totalPending = _pending.values.fold<int>(0, (s, v) => s + v);
    final remaining = widget.player.unspentPoints - totalPending;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Allocate Points',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'You have $remaining unspent point${remaining == 1 ? "" : "s"}',
                        style:  TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatRow('STR', '💪 Strength', widget.player.strength, const Color(0xFFEF4444)),
            _buildStatRow('AGI', '🏃 Agility', widget.player.agility, const Color(0xFF10B981)),
            _buildStatRow('VIT', '❤️ Vitality', widget.player.vitality, const Color(0xFFEC4899)),
            _buildStatRow('INT', '🧠 Intelligence', widget.player.intelligence, const Color(0xFF06B6D4)),
            _buildStatRow('PER', '👁️ Perception', widget.player.perception, const Color(0xFF8B5CF6)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: totalPending == 0
                        ? null
                        : () => setState(() => _pending.clear()),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: totalPending == 0
                        ? null
                        : () async {
                            for (final entry in _pending.entries) {
                              await widget.onAllocate(entry.key, entry.value);
                            }
                            if (mounted) Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Confirm (+$totalPending)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String code, String label, int currentValue, Color color) {
    final pending = _pending[code] ?? 0;
    final newValue = currentValue + pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label.split(' ').first,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  pending > 0
                      ? '$currentValue → $newValue'
                      : '$currentValue',
                  style: TextStyle(
                    fontSize: 11,
                    color: pending > 0 ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
            color: AppColors.textMuted,
            onPressed: pending == 0
                ? null
                : () => setState(() {
                      if (pending <= 1) {
                        _pending.remove(code);
                      } else {
                        _pending[code] = pending - 1;
                      }
                    }),
          ),
          Text(
            '+${pending}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: pending > 0 ? color : AppColors.textMuted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, size: 24),
            color: color,
            onPressed: () {
              final total = _pending.values.fold<int>(0, (s, v) => s + v);
              if (total >= widget.player.unspentPoints) return;
              setState(() => _pending[code] = pending + 1);
            },
          ),
        ],
      ),
    );
  }
}
