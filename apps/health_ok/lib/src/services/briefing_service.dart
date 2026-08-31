import 'package:shared_preferences/shared_preferences.dart';
import 'ai_coach_service.dart';
import 'colibri_engine.dart';
import 'app_settings.dart';
import 'hydration_service.dart';
import 'quest_service.dart';
import 'mood_service.dart';

/// Daily "System briefing" — an AI-written morning plan built from the
/// hunter's real data: yesterday's activity, today's quest, hydration,
/// mood and streak.
///
/// Generation routes TinyLlama (on-device) → Gemini (cloud) → Colibri
/// (procedural fallback). The result is cached per-day so the briefing is
/// written once each morning and is identical across the app.
class BriefingService {
  static const _kBriefingCache = 'hok_briefing_cache'; // {'date': ..., 'text': ..., 'engine': ...}
  static const _kBriefingDate = 'hok_briefing_date';

  /// Cached briefing for TODAY, or null when none exists yet.
  static Future<({String text, String engine})?> getToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _dateKey(DateTime.now());
    if (prefs.getString(_kBriefingDate) != dateKey) return null;
    final text = prefs.getString(_kBriefingCache);
    final engine = prefs.getString('hok_briefing_engine') ?? 'Colibri';
    if (text == null || text.isEmpty) return null;
    return (text: text, engine: engine);
  }

  /// Generate today's briefing. Returns the cached copy when it already
  /// exists for today; otherwise collects data and generates fresh.
  static Future<({String text, String engine})> generate({
    required AiCoachService coach,
    Map<String, double>? healthData,
  }) async {
    // Already written today? Reuse it (identical everywhere in the app).
    final cached = await getToday();
    if (cached != null) return cached;

    final context = await _collectContext(healthData: healthData);
    final prompt = _buildPrompt(context);
    final systemPrompt =
        'You are The System from Solo Leveling, briefing a hunter each '
        'morning. You get their real health data. Reply with exactly: '
        'a one-line status, then a 3-item numbered plan for today. '
        'Be specific and reference their numbers. Max 80 words.';

    // Engine chain: TinyLlama → Gemini → Colibri
    final result = await coach.generateStandalone(
      prompt,
      systemPrompt: systemPrompt,
      maxTokens: 160,
    );

    final String text;
    final String engine;
    if (result != null) {
      text = result.text;
      engine = result.engine;
    } else {
      text = ColibriEngine.instance.respond(
        'briefing',
        healthData: healthData,
        personality: AppSettings.getCoachPersonality(),
      );
      engine = 'Colibri (offline)';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBriefingDate, _dateKey(DateTime.now()));
    await prefs.setString(_kBriefingCache, text);
    await prefs.setString('hok_briefing_engine', engine);

    return (text: text, engine: engine);
  }

  /// Clear the cached briefing (used by "regenerate").
  static Future<void> invalidate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBriefingDate);
    await prefs.remove(_kBriefingCache);
    await prefs.remove('hok_briefing_engine');
  }

  // ─── Internals ──────────────────────────────────────────────────

  static String _dateKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static Future<Map<String, dynamic>> _collectContext({
    Map<String, double>? healthData,
  }) async {
    final data = <String, dynamic>{};

    // Today's activity (from Health Connect merge, passed in by the caller)
    final steps = healthData?['steps']?.toInt() ?? 0;
    final dist = healthData?['distance'] ?? 0.0;
    final kcal = healthData?['activeEnergy']?.toInt() ?? 0;
    data['steps'] = steps;
    data['distanceKm'] = double.parse(dist.toStringAsFixed(2));
    data['activeKcal'] = kcal;

    // Hydration
    data['waterMl'] = await HydrationService.getTodayMl();
    data['waterGoalMl'] = await HydrationService.getGoalMl();

    // Quest progress
    try {
      final state = await QuestService.loadAll();
      final q = state.quest;
      final objectives = <Map<String, dynamic>>[];
      for (int i = 0; i < q.objectives.length; i++) {
        final o = q.objectives[i];
        objectives.add({
          'label': o.label,
          'target': o.target,
          'unit': o.unit,
          'done': state.completed.contains(i),
        });
      }
      data['questTitle'] = q.title;
      data['objectives'] = objectives;
      data['level'] = state.player.level;
      data['streak'] = state.player.streakDays;
    } catch (_) {}

    // Yesterday's mood (if logged)
    try {
      final moods = await MoodService.getLast7Days();
      if (moods.isNotEmpty) {
        final last = moods.last;
        data['lastMood'] = last.mood;
        data['lastEnergy'] = last.energy;
      }
    } catch (_) {}

    return data;
  }

  static String _buildPrompt(Map<String, dynamic> d) {
    final buf = StringBuffer();
    buf.write('Morning briefing for a level-${d['level'] ?? '?'} hunter '
        'with a ${d['streak'] ?? 0}-day streak.\n');
    buf.write('So far today: ${d['steps'] ?? 0} steps, '
        '${d['distanceKm'] ?? 0} km, ${d['activeKcal'] ?? 0} kcal burned, '
        '${d['waterMl'] ?? 0}ml water of ${d['waterGoalMl'] ?? 2000}ml goal.\n');

    final objectives = d['objectives'] as List<Map<String, dynamic>>? ?? [];
    if (objectives.isNotEmpty) {
      buf.write('Today\'s quest objectives:\n');
      for (final o in objectives) {
        buf.write('- ${o['label']}: target ${o['target']}${o['unit']} '
            '[${o['done'] == true ? 'DONE' : 'pending'}]\n');
      }
    }
    if (d['lastMood'] != null) {
      buf.write('Latest mood check-in: ${d['lastMood']}/5 mood, '
          '${d['lastEnergy']}/5 energy.\n');
    }

    buf.write('\nWrite the briefing.');
    return buf.toString();
  }
}
