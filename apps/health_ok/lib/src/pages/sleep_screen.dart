import 'package:flutter/material.dart';
import 'package:health/health.dart' as health;
import 'package:health_ok/main.dart' show AppColors;

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  List<_SleepNight> _lastNights = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final health_ = health.Health();
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final sleepData = await health_.getHealthDataFromTypes(
        types: const [
          health.HealthDataType.SLEEP_SESSION,
          health.HealthDataType.SLEEP_ASLEEP,
        ],
        startTime: weekAgo,
        endTime: now,
      );

      // Group by night
      final nights = <String, _SleepNight>{};
      for (final s in sleepData) {
        if (s.value is! health.HealthValue) continue;
        final start = s.dateFrom;
        final end = s.dateTo;
        final duration = end.difference(start);
        if (duration.isNegative) continue;
        final hours = duration.inMinutes / 60.0;
        if (hours < 1 || hours > 16) continue;
        final dayKey = '${start.year}-${start.month}-${start.day}';
        if (!nights.containsKey(dayKey)) {
          nights[dayKey] = _SleepNight(date: start, totalHours: 0, sessions: []);
        }
        nights[dayKey]!.totalHours += hours;
        nights[dayKey]!.sessions.add(_SleepSession(start: start, end: end, hours: hours));
      }

      final list = nights.values.toList()..sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _lastNights = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
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
            'Sleep',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('😴', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style:  TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _lastNights.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('😴', style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                 Text(
                                  'No sleep data yet',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                 Text(
                                  'Connect a sleep tracker on Health Connect',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              _SleepSummary(nights: _lastNights),
                              const SizedBox(height: 20),
                              ..._lastNights.map((n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SleepNightCard(night: n),
                                  )),
                            ],
                          ),
              ),
      ),
    );
  }
}

class _SleepNight {
  final DateTime date;
  double totalHours;
  final List<_SleepSession> sessions;

  _SleepNight({required this.date, required this.totalHours, required this.sessions});
}

class _SleepSession {
  final DateTime start;
  final DateTime end;
  final double hours;

  _SleepSession({required this.start, required this.end, required this.hours});
}

class _SleepSummary extends StatelessWidget {
  final List<_SleepNight> nights;
  const _SleepSummary({required this.nights});

  @override
  Widget build(BuildContext context) {
    final avgHours = nights.isEmpty
        ? 0.0
        : nights.fold<double>(0, (s, n) => s + n.totalHours) / nights.length;
    final bestNight = nights.isEmpty
        ? null
        : nights.reduce((a, b) => a.totalHours > b.totalHours ? a : b);
    final avgQuality = _quality(avgHours);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
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
              Text('🌙', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text(
                'Last 7 Nights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Avg', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      '${avgHours.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quality', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(
                      avgQuality,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (bestNight != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Best', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        '${bestNight.totalHours.toStringAsFixed(1)}h',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _quality(double hours) {
    if (hours >= 7.5) return '😴 Great';
    if (hours >= 6.5) return '🙂 Good';
    if (hours >= 5) return '😐 Low';
    return '😟 Poor';
  }
}

class _SleepNightCard extends StatelessWidget {
  final _SleepNight night;
  const _SleepNightCard({required this.night});

  @override
  Widget build(BuildContext context) {
    final hours = night.totalHours;
    final color = hours >= 7
        ? const Color(0xFF6366F1)
        : hours >= 6
            ? const Color(0xFF8B5CF6)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bedtime_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(night.date),
                      style:  TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${hours.toStringAsFixed(1)} hours • ${night.sessions.length} session${night.sessions.length == 1 ? "" : "s"}',
                      style:  TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _qualityBadge(hours),
            ],
          ),
          if (night.sessions.length > 1) ...[
            const SizedBox(height: 10),
            const Divider(),
            ...night.sessions.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.nights_stay_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatTime(s.start)} – ${_formatTime(s.end)}',
                        style:  TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${s.hours.toStringAsFixed(1)}h',
                        style:  TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _qualityBadge(double hours) {
    final color = hours >= 7
        ? AppColors.success
        : hours >= 6
            ? const Color(0xFFFBBF24)
            : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hours >= 7 ? 'Good' : hours >= 6 ? 'OK' : 'Low',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[(d.weekday - 1) % 7]}, ${d.month}/${d.day}';
  }

  String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
