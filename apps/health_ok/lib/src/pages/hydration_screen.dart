import 'package:flutter/material.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/body_service.dart';
import 'package:health_ok/src/services/daily_stats_service.dart';
import 'package:health_ok/src/services/hydration_service.dart';

class HydrationScreen extends StatefulWidget {
  const HydrationScreen({super.key});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen> {
  int _todayMl = 0;
  int _goalMl = 2000;
  List<int> _weekData = List.filled(7, 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = await HydrationService.getTodayMl();
    final goal = await HydrationService.getGoalMl();
    final week = await HydrationService.getLast7Days();
    if (!mounted) return;
    setState(() {
      _todayMl = today;
      _goalMl = goal;
      _weekData = week;
      _loading = false;
    });
  }

  Future<void> _addWater(int ml) async {
    final newVal = await HydrationService.addWater(ml);
    setState(() {
      _todayMl = newVal;
      // Refresh week
      _refreshWeek();
    });
    if (newVal >= _goalMl && (newVal - ml) < _goalMl) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Daily hydration goal reached!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  Future<void> _refreshWeek() async {
    final week = await HydrationService.getLast7Days();
    if (mounted) setState(() => _weekData = week);
  }

  Future<void> _editGoal() async {
    // Smart suggestion uses the user's REAL weight + today's activity,
    // not the 70 kg default.
    int smart = 2000;
    try {
      final weight = await BodyService.effectiveWeightKg();
      final stats = await DailyStatsService.getToday();
      smart = HydrationService.suggestGoalMl(
        weightKg: weight,
        stepsToday: stats?.steps ?? 0,
      );
    } catch (_) {
      smart = HydrationService.suggestGoalMl();
    }
    final ctrl = TextEditingController(text: _goalMl.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: 'ml',
                hintText: 'e.g. 2000',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ctrl.text = smart.toString(),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text('Smart: $smart ml (33 ml/kg + activity)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await HydrationService.setGoalMl(result);
      if (mounted) setState(() => _goalMl = result);
    }
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
            'Hydration',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon:  Icon(Icons.flag_rounded, color: AppColors.textPrimary),
              onPressed: _editGoal,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _WaterBottle(progress: (_todayMl / _goalMl).clamp(0.0, 1.0)),
                      const SizedBox(height: 24),
                      Text(
                        '${_todayMl} / $_goalMl ml',
                        style:  TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Quick add buttons
                       Text(
                        'Quick Add',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _QuickAddBtn(label: '+250 ml', ml: 250, onTap: _addWater),
                          const SizedBox(width: 8),
                          _QuickAddBtn(label: '+500 ml', ml: 500, onTap: _addWater),
                          const SizedBox(width: 8),
                          _QuickAddBtn(label: '+750 ml', ml: 750, onTap: _addWater),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _QuickAddBtn(label: '+1 cup (240)', ml: 240, onTap: _addWater),
                          const SizedBox(width: 8),
                          _QuickAddBtn(label: '+1 bottle (500)', ml: 500, onTap: _addWater),
                          const SizedBox(width: 8),
                          _QuickAddBtn(label: '-250 ml', ml: -250, onTap: (m) => _addWater(m), negative: true),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _WeekChart(data: _weekData, goal: _goalMl),
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final active = _weekData.where((d) => d > 0).length;
                        if (active == 0) return const SizedBox.shrink();
                        final avg =
                            _weekData.fold<int>(0, (s, d) => s + d) ~/ active;
                        return Text(
                          '7-day avg: $avg ml/day across $active days',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        'Daily goal: $_goalMl ml',
                        style:  TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _WaterBottle extends StatelessWidget {
  final double progress;
  const _WaterBottle({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Background water tint
              Container(color: const Color(0xFFEFF6FF)),
              // Animated water
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Container(
                    height: 200 * value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.7),
                          AppColors.primary,
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Percentage label
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddBtn extends StatelessWidget {
  final String label;
  final int ml;
  final void Function(int) onTap;
  final bool negative;

  const _QuickAddBtn({
    required this.label,
    required this.ml,
    required this.onTap,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(ml),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: negative ? Colors.white : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: negative ? AppColors.border : AppColors.primary,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: negative ? AppColors.textMuted : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  final List<int> data;
  final int goal;
  const _WeekChart({required this.data, required this.goal});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<int>(0, (m, d) => d > m ? d : m).clamp(goal, 100000);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Last 7 Days',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((entry) {
                final i = entry.key;
                final v = entry.value;
                final h = (maxVal > 0 ? (v / maxVal * 70) + 4 : 4).toDouble();
                final isToday = i == data.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.primary.withOpacity(isToday ? 1.0 : 0.7),
                                    AppColors.primary.withOpacity(isToday ? 0.7 : 0.3),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dayLabel(i),
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? AppColors.primary : AppColors.textMuted,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _dayLabel(int daysAgo) {
    const days = ['6d', '5d', '4d', '3d', '2d', '1d', 'Today'];
    return days[daysAgo.clamp(0, 6)];
  }
}
