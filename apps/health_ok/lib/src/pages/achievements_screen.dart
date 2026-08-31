import 'package:flutter/material.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/achievement_service.dart';
import 'package:health_ok/src/services/quest_service.dart';
import 'package:storage/storage.dart';
import 'package:core_domain/core_domain.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Set<String> _unlocked = {};
  AchievementContext? _context;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final unlocked = await AchievementService.getUnlocked();
    final questState = await QuestService.loadAll();
    final player = questState.player;
    final db = await AppDatabase.open();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    int totalSteps = 0;
    double totalDist = 0;
    try {
      final stepRows = await db.getSamplesForType(HealthDataType.steps, from: weekAgo);
      final distRows = await db.getSamplesForType(HealthDataType.distance, from: weekAgo);
      totalSteps = stepRows.fold<int>(0, (s, r) => s + (r.value?.toInt() ?? 0));
      totalDist = distRows.fold<double>(0, (s, r) => s + (r.value ?? 0));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _unlocked = unlocked;
      _context = AchievementContext(
        level: player.level,
        streakDays: player.streakDays,
        bestStreak: player.bestStreak,
        totalXp: player.xp,
        unspentPoints: player.unspentPoints,
        strength: player.strength,
        agility: player.agility,
        vitality: player.vitality,
        intelligence: player.intelligence,
        perception: player.perception,
        totalStepsLast7Days: totalSteps,
        totalDistanceLast7Days: totalDist.toInt(),
        totalQuestsCompleted: 0,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:  BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon:  Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title:  Text(
            'Achievements',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _ProgressHeader(unlocked: _unlocked.length, total: AchievementService.all.length),
                    const SizedBox(height: 20),
                    ...AchievementService.all.map((ach) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AchievementCard(
                            achievement: ach,
                            isUnlocked: _unlocked.contains(ach.id),
                            progress: AchievementService.progress(ach, _context!),
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  const _ProgressHeader({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (unlocked / total) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Achievements Unlocked',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final double progress;

  const _AchievementCard({
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? const Color(0xFFFBBF24) : AppColors.border,
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? const Color(0xFFFEF3C7)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Opacity(
                opacity: isUnlocked ? 1.0 : 0.4,
                child: Text(achievement.icon, style: const TextStyle(fontSize: 28)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isUnlocked
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style:  TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
