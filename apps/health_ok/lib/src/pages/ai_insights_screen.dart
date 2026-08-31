import 'package:flutter/material.dart';
import 'package:health/health.dart' as health;
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:health_ok/src/theme/app_colors.dart';

/// AI-powered health insights — analyzes weekly trends and gives personalized advice.
class AiInsightsScreen extends StatefulWidget {
  final AiCoachService coachService;
  const AiInsightsScreen({super.key, required this.coachService});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  String _insight = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateInsights();
  }

  Future<void> _generateInsights() async {
    setState(() {
      _loading = true;
      _insight = '';
    });

    final h = health.Health();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    try {
      // This week
      final thisWeek = await h.getHealthDataFromTypes(
        types: [
          health.HealthDataType.STEPS,
          health.HealthDataType.DISTANCE_DELTA,
          health.HealthDataType.ACTIVE_ENERGY_BURNED,
        ],
        startTime: weekAgo,
        endTime: now,
      );

      // Last week
      final lastWeek = await h.getHealthDataFromTypes(
        types: [
          health.HealthDataType.STEPS,
          health.HealthDataType.DISTANCE_DELTA,
          health.HealthDataType.ACTIVE_ENERGY_BURNED,
        ],
        startTime: twoWeeksAgo,
        endTime: weekAgo,
      );

      double thisSteps = 0, thisDist = 0, thisCal = 0;
      double lastSteps = 0, lastDist = 0, lastCal = 0;

      for (final s in thisWeek) {
        if (s.value is! health.NumericHealthValue) continue;
        final v = (s.value as health.NumericHealthValue).numericValue.toDouble();
        if (s.type == health.HealthDataType.STEPS) thisSteps += v;
        if (s.type == health.HealthDataType.DISTANCE_DELTA) thisDist += v;
        if (s.type == health.HealthDataType.ACTIVE_ENERGY_BURNED) thisCal += v;
      }

      for (final s in lastWeek) {
        if (s.value is! health.NumericHealthValue) continue;
        final v = (s.value as health.NumericHealthValue).numericValue.toDouble();
        if (s.type == health.HealthDataType.STEPS) lastSteps += v;
        if (s.type == health.HealthDataType.DISTANCE_DELTA) lastDist += v;
        if (s.type == health.HealthDataType.ACTIVE_ENERGY_BURNED) lastCal += v;
      }

      final prompt = '''You are a health data analyst AI. Analyze this user's weekly health data and give 3-5 personalized insights and recommendations. Be specific with numbers.

THIS WEEK:
- Steps: ${thisSteps.toStringAsFixed(0)}
- Distance: ${thisDist.toStringAsFixed(2)} km
- Calories burned: ${thisCal.toStringAsFixed(0)} kcal

LAST WEEK:
- Steps: ${lastSteps.toStringAsFixed(0)}
- Distance: ${lastDist.toStringAsFixed(2)} km
- Calories burned: ${lastCal.toStringAsFixed(0)} kcal

TRENDS:
- Steps change: ${lastSteps > 0 ? (((thisSteps - lastSteps) / lastSteps) * 100).toStringAsFixed(1) : 'N/A'}%
- Distance change: ${lastDist > 0 ? (((thisDist - lastDist) / lastDist) * 100).toStringAsFixed(1) : 'N/A'}%
- Calorie change: ${lastCal > 0 ? (((thisCal - lastCal) / lastCal) * 100).toStringAsFixed(1) : 'N/A'}%

Give your analysis in a friendly but data-driven tone. Use emoji. End with one actionable recommendation.''';

      final response = await widget.coachService.sendAndWait(prompt);
      if (!mounted) return;
      setState(() {
        _insight = response;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _insight = '⚠️ Could not generate insights: $e\n\nMake sure the AI Coach model is loaded in the Coach tab first.';
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
            'AI Health Insights',
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
                      colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text('🧠', style: TextStyle(fontSize: 32)),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly AI Analysis',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Powered by your on-device AI',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _loading
                      ?  Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 16),
                              Text(
                                'Analyzing your data...',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.lightBorder),
                            ),
                            child: Text(
                              _insight,
                              style:  TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.5),
                            ),
                          ),
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