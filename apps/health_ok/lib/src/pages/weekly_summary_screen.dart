import 'package:flutter/material.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:storage/storage.dart';
import 'package:core_domain/core_domain.dart';

class WeeklySummaryScreen extends StatefulWidget {
  final AiCoachService coachService;

  const WeeklySummaryScreen({super.key, required this.coachService});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  Map<String, dynamic>? _weekData;
  String? _summary;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    final db = await AppDatabase.open();
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      int stepsTotal = 0;
      double distanceTotal = 0;
      int caloriesTotal = 0;
      int daysWithData = 0;
      int bestDay = 0;

      for (int i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final stepRows = await db.getSamplesForType(HealthDataType.steps, from: dayStart, to: dayEnd);
        final distRows = await db.getSamplesForType(HealthDataType.distance, from: dayStart, to: dayEnd);
        final calRows = await db.getSamplesForType(HealthDataType.activeEnergy, from: dayStart, to: dayEnd);

        final daySteps = stepRows.fold<int>(0, (s, r) => s + (r.value?.toInt() ?? 0));
        final dayDist = distRows.fold<double>(0, (s, r) => s + (r.value ?? 0.0));
        final dayCal = calRows.fold<double>(0, (s, r) => s + (r.value ?? 0.0));

        if (daySteps > 0 || dayDist > 0 || dayCal > 0) {
          daysWithData++;
        }
        stepsTotal += daySteps;
        distanceTotal += dayDist;
        caloriesTotal += dayCal.toInt();
        if (daySteps > bestDay) bestDay = daySteps;
      }

      if (!mounted) return;
      setState(() {
        _weekData = {
          'stepsTotal': stepsTotal,
          'distanceTotal': distanceTotal.toStringAsFixed(1),
          'caloriesTotal': caloriesTotal,
          'avgSteps': daysWithData > 0 ? (stepsTotal / daysWithData).round() : 0,
          'bestDay': bestDay,
        };
      });
    } catch (e) {
    }
  }

  Future<void> _generateSummary() async {
    if (_weekData == null) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      // History-free: works with ANY engine (TinyLlama, Gemini or the
      // procedural fallback). No model-required hard failure, no chat wipe.
      final result =
          await widget.coachService.generateWeeklySummary(_weekData!);
      if (!mounted) return;
      setState(() {
        _summary = result;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _generating = false;
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
            'Weekly Summary',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: _weekData == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatsCard(data: _weekData!),
                      const SizedBox(height: 20),
                      if (_summary == null && !_generating)
                        _GenerateButton(onTap: _generateSummary)
                      else if (_generating)
                        _GeneratingCard(progress: widget.coachService.currentResponse)
                      else if (_error != null)
                        _ErrorCard(error: _error!, onRetry: _generateSummary)
                      else if (_summary != null)
                        _SummaryCard(summary: _summary!),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📊', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text(
                'Past 7 Days',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                icon: '👟',
                label: 'Steps',
                value: '${data['stepsTotal']}',
                sub: 'avg ${data['avgSteps']}',
              ),
              _Stat(
                icon: '📍',
                label: 'Distance',
                value: '${data['distanceTotal']} km',
                sub: '',
              ),
              _Stat(
                icon: '🔥',
                label: 'Calories',
                value: '${data['caloriesTotal']}',
                sub: '',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String sub;
  const _Stat({required this.icon, required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GenerateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Generate AI Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratingCard extends StatelessWidget {
  final String progress;
  const _GeneratingCard({required this.progress});

  @override
  Widget build(BuildContext context) {
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
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
               Text(
                'AI is writing your summary...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (progress.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              progress,
              style:  TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.energyColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.energyColor),
              SizedBox(width: 8),
              Text(
                'Could not generate summary',
                style: TextStyle(
                  color: AppColors.energyColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style:  TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
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
            children: [
              Text('✨', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'AI Coach Says',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style:  TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
