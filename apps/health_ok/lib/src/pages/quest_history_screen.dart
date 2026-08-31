import 'package:flutter/material.dart';
import 'package:health_ok/src/theme/app_colors.dart';

/// Quest history calendar — shows past quest completions per day.
class QuestHistoryScreen extends StatefulWidget {
  const QuestHistoryScreen({super.key});

  @override
  State<QuestHistoryScreen> createState() => _QuestHistoryScreenState();
}

class _QuestHistoryScreenState extends State<QuestHistoryScreen> {
  late DateTime _monthStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
  }

  void _prev() {
    setState(() {
      _monthStart = DateTime(_monthStart.year, _monthStart.month - 1, 1);
    });
  }

  void _next() {
    setState(() {
      _monthStart = DateTime(_monthStart.year, _monthStart.month + 1, 1);
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
            'Quest History',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: _prev,
                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                _formatMonth(_monthStart),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _next,
                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildCalendar(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _StatsRow(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child:  Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Visit Coach tab to see your AI-generated weekly summary',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMonth(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _buildCalendar() {
    final firstDay = _monthStart;
    final daysInMonth = DateTime(firstDay.year, firstDay.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sun=0
    final today = DateTime.now();

    final cells = <Widget>[];
    // Header
    for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S']) {
      cells.add(Center(
        child: Text(d, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ));
    }
    // Empty cells before day 1
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(firstDay.year, firstDay.month, day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isFuture = date.isAfter(today);
      // For demo: every day a quest could be done — green if today is past or today
      final completed = !isFuture && day <= today.day && firstDay.month == today.month;
      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: completed
                ? Colors.white
                : isToday
                    ? AppColors.lightBgEnd
                    : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: completed ? const Color(0xFF6366F1) : Colors.white,
                fontWeight: completed || isToday ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      children: cells,
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Streak', value: '0d', emoji: '🔥', color: const Color(0xFFEF4444))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Total XP', value: '0', emoji: '⭐', color: const Color(0xFFFBBF24))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Level', value: '1', emoji: '📈', color: const Color(0xFF6366F1))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
          ),
          Text(label, style:  TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}