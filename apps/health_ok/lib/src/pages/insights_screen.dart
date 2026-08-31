import 'package:flutter/material.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:storage/storage.dart';
import 'package:core_domain/core_domain.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<DayStats> _weekData = [];
  bool _loading = true;
  int _selectedRange = 7; // 7 days

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = await AppDatabase.open();
    final now = DateTime.now();
    final days = <DayStats>[];

    for (int i = _selectedRange - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      int steps = 0;
      double distance = 0;
      int calories = 0;
      try {
        final stepRows =
            await db.getSamplesForType(HealthDataType.steps, from: dayStart, to: dayEnd);
        final distRows =
            await db.getSamplesForType(HealthDataType.distance, from: dayStart, to: dayEnd);
        final calRows =
            await db.getSamplesForType(HealthDataType.activeEnergy, from: dayStart, to: dayEnd);

        steps = stepRows.fold<int>(0, (s, r) => s + (r.value?.toInt() ?? 0));
        distance = distRows.fold<double>(0, (s, r) => s + (r.value ?? 0));
        calories = calRows.fold<int>(0, (s, r) => s + (r.value?.toInt() ?? 0));
      } catch (_) {}

      days.add(DayStats(
        date: day,
        steps: steps,
        distance: distance,
        calories: calories,
      ));
    }

    if (!mounted) return;
    setState(() {
      _weekData = days;
      _loading = false;
    });
  }

  void _changeRange(int days) {
    setState(() => _selectedRange = days);
    _loadData();
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
            'Insights',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Range selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            _RangeBtn(label: '7 days', days: 7, current: _selectedRange, onTap: _changeRange),
                            _RangeBtn(label: '14 days', days: 14, current: _selectedRange, onTap: _changeRange),
                            _RangeBtn(label: '30 days', days: 30, current: _selectedRange, onTap: _changeRange),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Summary cards
                      Row(
                        children: [
                          _SummaryCard(
                            icon: '👟',
                            label: 'Total Steps',
                            value: _totalSteps().toString(),
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            icon: '📍',
                            label: 'Distance',
                            value: '${_totalDistance().toStringAsFixed(1)} km',
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 12),
                          _SummaryCard(
                            icon: '🔥',
                            label: 'Calories',
                            value: '${_totalCalories()}',
                            color: AppColors.energyColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Steps chart
                      _ChartCard(
                        title: 'Daily Steps',
                        unit: 'steps',
                        data: _weekData,
                        valueGetter: (d) => d.steps.toDouble(),
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),

                      // Distance chart
                      _ChartCard(
                        title: 'Daily Distance',
                        unit: 'km',
                        data: _weekData,
                        valueGetter: (d) => d.distance,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 16),

                      // Calories chart
                      _ChartCard(
                        title: 'Daily Calories',
                        unit: 'kcal',
                        data: _weekData,
                        valueGetter: (d) => d.calories.toDouble(),
                        color: AppColors.energyColor,
                      ),
                      const SizedBox(height: 24),

                      // Trend insights
                      _TrendInsights(data: _weekData),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  int _totalSteps() => _weekData.fold(0, (s, d) => s + d.steps);
  double _totalDistance() => _weekData.fold<double>(0, (s, d) => s + d.distance);
  int _totalCalories() => _weekData.fold(0, (s, d) => s + d.calories);
}

class DayStats {
  final DateTime date;
  final int steps;
  final double distance;
  final int calories;

  DayStats({required this.date, required this.steps, required this.distance, required this.calories});
}

class _RangeBtn extends StatelessWidget {
  final String label;
  final int days;
  final int current;
  final ValueChanged<int> onTap;

  const _RangeBtn({required this.label, required this.days, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style:  TextStyle(fontSize: 10, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final List<DayStats> data;
  final double Function(DayStats) valueGetter;
  final Color color;

  const _ChartCard({
    required this.title,
    required this.unit,
    required this.data,
    required this.valueGetter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.fold<double>(0, (m, d) {
      final v = valueGetter(d);
      return v > m ? v : m;
    });
    final todayVal = data.isNotEmpty ? valueGetter(data.last) : 0.0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:  TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${todayVal.toInt()} $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final v = valueGetter(d);
                final h = (maxVal > 0 ? (v / maxVal * 80) + 6 : 6).toDouble();
                final isToday = d.date.day == DateTime.now().day;
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
                                    color.withOpacity(isToday ? 1.0 : 0.6),
                                    color.withOpacity(isToday ? 0.6 : 0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _dayLabel(d.date),
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday ? color : AppColors.textMuted,
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

  String _dayLabel(DateTime d) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[(d.weekday - 1) % 7];
  }
}

class _TrendInsights extends StatelessWidget {
  final List<DayStats> data;
  const _TrendInsights({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const SizedBox.shrink();
    }
    final recent = data.skip(data.length ~/ 2).toList();
    final earlier = data.take(data.length ~/ 2).toList();

    final recentAvg = recent.fold<int>(0, (s, d) => s + d.steps) / recent.length;
    final earlierAvg = earlier.fold<int>(0, (s, d) => s + d.steps) / earlier.length;
    final trend = recentAvg - earlierAvg;
    final trendPct = earlierAvg > 0 ? (trend / earlierAvg * 100).round() : 0;

    final bestDay = data.reduce((a, b) => a.steps > b.steps ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📈', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'Your Trends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InsightRow(
            icon: trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            text: trend >= 0
                ? '$trendPct% more active than the first half'
                : '${trendPct.abs()}% less active than the first half',
          ),
          const SizedBox(height: 8),
          _InsightRow(
            icon: Icons.star_rounded,
            text: 'Best day: ${_formatDay(bestDay.date)} (${bestDay.steps} steps)',
          ),
          const SizedBox(height: 8),
          _InsightRow(
            icon: Icons.local_fire_department_rounded,
            text: 'Average: ${recentAvg.round()} steps/day',
          ),
        ],
      ),
    );
  }

  String _formatDay(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d.weekday - 1) % 7];
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InsightRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
