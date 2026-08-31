import 'package:flutter/material.dart';
import 'package:health_ok/src/services/quest_service.dart';
import 'package:health_ok/src/services/body_service.dart';
import 'package:health_ok/src/services/workout_service.dart';
import 'package:health_ok/src/theme/app_colors.dart';
import 'package:quest_engine/quest_engine.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  List<WorkoutEntry> _entries = [];
  bool _loading = true;
  Map<String, dynamic>? _summary;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await WorkoutService.getAll();
    final summary = await WorkoutService.weeklySummary();
    final streak = await WorkoutService.workoutStreak();
    if (!mounted) return;
    setState(() {
      _entries = all..sort((a, b) => b.time.compareTo(a.time));
      _summary = summary;
      _streak = streak;
      _loading = false;
    });
  }

  Future<void> _addWorkout() async {
    final result = await showModalBottomSheet<WorkoutEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddWorkoutSheet(),
    );
    if (result != null) {
      await WorkoutService.add(result);
      await _awardXp(result.xpEarned);
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '+${result.xpEarned} XP for ${result.type.label} ${result.type.emoji}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<void> _awardXp(int xp) async {
    var player = await QuestService.loadPlayer();
    final result = const QuestEngine().awardXp(player, xp);
    await QuestService.savePlayer(result.player);
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
            'Workouts',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addWorkout,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Log Workout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _entries.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _entries.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return _WeeklyStatsCard(summary: _summary!, streak: _streak);
                        final w = _entries[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WorkoutCard(entry: w),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:  [
          Text('🏋️', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'No workouts logged yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Tap "Log Workout" to start earning stats',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutEntry entry;
  const _WorkoutCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.stepsColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(entry.type.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.type.label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${entry.xpEarned} XP',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _Stat(
                      icon: Icons.timer_outlined,
                      label: '${entry.durationMinutes}m',
                    ),
                    _Stat(
                      icon: Icons.local_fire_department_rounded,
                      label: '${entry.caloriesBurned} kcal',
                    ),
                    _Stat(
                      icon: Icons.bolt_rounded,
                      label: _intensityLabel(entry.intensity),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(entry.time),
                  style:  TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '"${entry.notes!}"',
                      style:  TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon:  Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
            onPressed: () async {
              await WorkoutService.delete(entry.id);
              (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _intensityLabel(int i) {
    return ['Very light', 'Light', 'Medium', 'Hard', 'Beast'][i - 1];
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style:  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _AddWorkoutSheet extends StatefulWidget {
  const _AddWorkoutSheet();

  @override
  State<_AddWorkoutSheet> createState() => _AddWorkoutSheetState();
}

class _AddWorkoutSheetState extends State<_AddWorkoutSheet> {
  WorkoutType _type = WorkoutType.run;
  int _duration = 30;
  int _intensity = 3;
  final _notes = TextEditingController();
  double _weightKg = 70; // replaced by the user's real weight in initState

  @override
  void initState() {
    super.initState();
    BodyService.effectiveWeightKg().then((w) {
      if (mounted) setState(() => _weightKg = w);
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// MET-based estimate scaled to the user's real body weight.
  int get _calories => estimateWorkoutCalories(
        type: _type,
        durationMinutes: _duration,
        intensity: _intensity,
        weightKg: _weightKg,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration:  BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log Workout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: WorkoutType.values.length,
                itemBuilder: (_, i) {
                  final t = WorkoutType.values[i];
                  final selected = t == _type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        width: 84,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(_type.hint,
                style:  TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            const Text('Duration',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _duration.toDouble(),
              min: 5,
              max: 180,
              divisions: 35,
              label: '$_duration min',
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _duration = v.toInt()),
            ),
            const SizedBox(height: 8),
            const Text('Intensity', style: TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _intensity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: ['Very light', 'Light', 'Medium', 'Hard', 'Beast'][_intensity - 1],
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _intensity = v.toInt()),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('🔥',
                      style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estimated: $_calories kcal • +${_duration * 2 + _calories ~/ 10 * _intensity} XP',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 120,
              decoration: const InputDecoration(
                hintText: 'Notes (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final entry = WorkoutEntry(
                        id: 'wo_${DateTime.now().millisecondsSinceEpoch}',
                        time: DateTime.now(),
                        type: _type,
                        durationMinutes: _duration,
                        caloriesBurned: _calories,
                        intensity: _intensity,
                        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                      );
                      Navigator.pop(context, entry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Save'),
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
// ─── Weekly stats card ───────────────────────────────────────────────────────

class _WeeklyStatsCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final int streak;
  const _WeeklyStatsCard({required this.summary, required this.streak});

  @override
  Widget build(BuildContext context) {
    final sessions = summary['sessions'] as int;
    final minutes = summary['minutes'] as int;
    final calories = summary['calories'] as int;
    final xp = summary['xp'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This Week',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              if (streak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('$streak day streak',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('$sessions', 'sessions'),
              _stat('$minutes', 'minutes'),
              _stat('$calories', 'kcal'),
              _stat('$xp', 'XP'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
