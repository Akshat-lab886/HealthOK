import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model_manager.dart';
import 'colibri_engine.dart';
import 'gemini_service.dart';
import 'app_settings.dart';
import 'mood_service.dart';
import 'body_service.dart';
import 'daily_stats_service.dart';

/// Health coach system prompt — expert, motivating, concise.
const _systemPrompt = '''You are HealthOK AI, an on-device health coach running locally on the user's phone. You are an expert in:

- Exercise science (cardio, strength training, flexibility)
- Nutrition (macronutrients, hydration, meal timing)
- Sleep optimization (circadian rhythm, sleep hygiene)
- Mental wellness (stress management, mindfulness)
- Recovery science (rest days, stretching, injury prevention)

You have access to the user's real-time health data from their phone (steps, distance, calories burned).

RULES:
- Keep responses concise (2-4 sentences max) unless asked for detail
- Be motivating but not cheesy — like a knowledgeable trainer
- Give actionable advice, not vague platitudes
- Reference their actual data when relevant
- If asked about medical conditions, always recommend consulting a doctor
- Use their health data to personalize responses
- Be warm but professional

Never say "as an AI" or "I'm not a doctor" disclaimers in every response. Just give good advice.''';

/// Engine mode — what's currently powering responses.
enum EngineMode { colibri, hybrid, gguf }

/// Manages the AI coach — uses Colibri (always available) + optional GGUF model.
class AiCoachService extends ChangeNotifier {
  LlamaEngine? _engine;
  bool _isGenerating = false;
  bool _isLoaded = false;
  String _currentResponse = '';
  String? _error;
  String? _loadingModelId;
  EngineMode _engineMode = EngineMode.colibri;
  ModelTier? _loadedTier;

  AiCoachService() {
    loadHistory();
  }

  bool get isGenerating => _isGenerating;
  bool get isLoaded => _isLoaded;
  String get currentResponse => _currentResponse;
  String? get error => _error;
  String? get loadingModelId => _loadingModelId;
  EngineMode get engineMode => _engineMode;
  bool get usesColibri => _engineMode == EngineMode.colibri;

  final List<Map<String, String>> _history = [];

  List<Map<String, String>> get history => _history;

  // ─── Persist chat history ──────────────────────────────────
  static const _kChatHistory = 'hok_chat_history';

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep last 50 messages max
    final toSave = _history.length > 50 ? _history.sublist(_history.length - 50) : _history;
    await prefs.setStringList(
      _kChatHistory,
      toSave.map((m) => jsonEncode(m)).toList(),
    );
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kChatHistory);
    if (saved != null && saved.isNotEmpty) {
      _history.clear();
      for (final s in saved) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          _history.add({
            'role': m['role'] as String,
            'content': m['content'] as String,
          });
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // ─── Load GGUF model (optional, graceful fallback) ─────────────
  Future<void> loadModel(AiModel model) async {
    try {
      _error = null;
      _isLoaded = false;
      _loadingModelId = model.id;
      _engineMode = EngineMode.hybrid;
      notifyListeners();

      // Dispose old engine if any
      await _engine?.dispose();

      final file = await model.localFile;
      if (!file.existsSync()) {
        throw Exception('Model file not found: ${file.path}');
      }

      // Check available memory before loading
      try {
        final info = await ProcessInfo.currentRss;
        final availableMb = 4096 - (info ~/ (1024 * 1024));
        if (model.minRamMb > availableMb) {
          throw Exception(
              'Not enough RAM ($availableMb MB free, need ${model.minRamMb} MB). '
              'Using Colibri (instant mode) instead.');
        }
      } catch (e) {
        if (!e.toString().contains('Not enough RAM')) {
        } else {
          rethrow;
        }
      }

      _engine = LlamaEngine(LlamaBackend());
      // Use minimal context for micro tier to save RAM
      final ctxSize = model.tier == ModelTier.micro ? 512 : (model.tier == ModelTier.lite ? 1024 : 2048);
      await _engine!.loadModel(
        file.path,
        modelParams: ModelParams(contextSize: ctxSize, gpuLayers: 0),
      );

      _history.clear();
      _isLoaded = true;
      _loadingModelId = null;
      _loadedTier = model.tier;
      _engineMode = EngineMode.hybrid;
      notifyListeners();
    } catch (e) {
      _error = null; // Don't show error — Colibri handles it
      _isLoaded = false;
      _loadingModelId = null;
      _engineMode = EngineMode.colibri; // Fallback to Colibri
      notifyListeners();
    }
  }

  // ─── Send message — routes to GGUF or Colibri ──────────────────
  Future<void> sendMessage(String userMessage,
      {Map<String, double>? healthData}) async {
    if (_isGenerating) return;

    _currentResponse = '';
    _error = null;
    _isGenerating = true;
    _history.add({'role': 'user', 'content': userMessage});
    notifyListeners();

    try {
      if (_isLoaded && _engine != null) {
        // Use GGUF model
        await _sendViaGguf(userMessage, healthData: healthData);
      } else if (GeminiService.isConfigured && GeminiService.isEnabled) {
        // Use cloud Gemini API (powerful, zero RAM)
        await _sendViaGemini(userMessage, healthData: healthData);
      } else {
        // Use Colibri (instant response)
        await _sendViaColibri(userMessage, healthData: healthData);
      }
    } catch (e) {
      // If GGUF fails, try Gemini, then Colibri
      if (_engineMode == EngineMode.hybrid) {
        _engineMode = EngineMode.colibri;
        _history.removeLast(); // Remove the failed user message
        _history.add({'role': 'user', 'content': userMessage});
        if (GeminiService.isConfigured && GeminiService.isEnabled) {
          try {
            await _sendViaGemini(userMessage, healthData: healthData);
          } catch (_) {
            await _sendViaColibri(userMessage, healthData: healthData);
          }
        } else {
          await _sendViaColibri(userMessage, healthData: healthData);
        }
      } else {
        _error = 'Error: $e';
        _isGenerating = false;
        _history.removeLast();
        notifyListeners();
      }
    }
  }

  Future<void> _sendViaGguf(String userMessage,
      {Map<String, double>? healthData}) async {
    // Compact system prompt for micro tier (TinyLlama only has 512 tokens)
    final isMicro = _loadedTier == ModelTier.micro;
    final sysPrompt = isMicro
        ? 'You are a health coach. Answer briefly about steps, sleep, exercise, nutrition. Use health data provided.'
        : _systemPrompt;

    // Build enriched message with health data + personal context
    String enrichedMessage = userMessage;
    final ctxParts = <String>[];
    if (healthData != null && healthData.isNotEmpty) {
      if ((healthData['steps'] ?? 0) > 0) {
        ctxParts.add('${healthData['steps']!.toInt()} steps today');
      }
      if ((healthData['distance'] ?? 0) > 0) {
        ctxParts.add('${healthData['distance']!.toStringAsFixed(1)}km today');
      }
      if ((healthData['activeEnergy'] ?? 0) > 0) {
        ctxParts.add('${healthData['activeEnergy']!.toInt()} kcal active today');
      }
    }
    // Personal context: mood check-in, weight, level, streak
    try {
      final mood = await MoodService.getToday();
      if (mood != null) {
        ctxParts.add('mood ${mood.mood}/5, energy ${mood.energy}/5');
      }
      final weight = await BodyService.effectiveWeightKg();
      ctxParts.add('weight ${weight.toStringAsFixed(0)}kg');
      final avgSteps = await DailyStatsService.avgSteps();
      if (avgSteps != null) {
        ctxParts.add('7-day avg ${avgSteps.toInt()} steps');
      }
    } catch (_) {}
    if (ctxParts.isNotEmpty) {
      enrichedMessage += ' [data: ${ctxParts.join(', ')}]';
    }

    // For micro tier: only keep last 2 messages to save context
    final historySlice = isMicro
        ? _history.length > 4
            ? _history.sublist(_history.length - 4)
            : _history
        : _history;

    // Send the ENRICHED last message (with health data appended) — the raw
    // user text is already in _history for persistence.
    final messages = <LlamaChatMessage>[
      LlamaChatMessage.fromText(
        role: LlamaChatRole.system,
        text: sysPrompt,
      ),
      ...historySlice.map((m) {
        final isLastUser =
            m == _history.last && m['role'] == 'user';
        return LlamaChatMessage.fromText(
          role: m['role'] == 'assistant'
              ? LlamaChatRole.assistant
              : LlamaChatRole.user,
          text: isLastUser ? enrichedMessage : m['content']!,
        );
      }),
    ];

    // Micro tier: shorter responses
    final maxTok = isMicro ? 128 : 384;

    await for (final chunk in _engine!.create(
      messages,
      params: GenerationParams(maxTokens: maxTok, temp: 0.7),
    )) {
      final text = chunk.choices.first.delta.content;
      if (text != null) {
        _currentResponse += text;
        notifyListeners();
      }
    }

    _history.add({'role': 'assistant', 'content': _currentResponse});
    _isGenerating = false;
    _saveHistory();
    notifyListeners();
  }

  // ─── Send via Google Gemini API (cloud) ──────────────────────
  Future<void> _sendViaGemini(String userMessage,
      {Map<String, double>? healthData}) async {
    // Build enriched message with health data
    String enrichedMessage = userMessage;
    if (healthData != null && healthData.isNotEmpty) {
      final parts = <String>[];
      if ((healthData['steps'] ?? 0) > 0) {
        parts.add('${healthData['steps']!.toInt()} steps');
      }
      if ((healthData['distance'] ?? 0) > 0) {
        parts.add('${healthData['distance']!.toStringAsFixed(1)}km');
      }
      if ((healthData['activeEnergy'] ?? 0) > 0) {
        parts.add('${healthData['activeEnergy']!.toInt()}kcal');
      }
      if (parts.isNotEmpty) {
        enrichedMessage += '\n\n[Health Data: ${parts.join(', ')}]';
      }
    }

    // Build message list for Gemini
    final geminiMessages = _history
        .where((m) => m != _history.last) // exclude the just-added user msg
        .toList()
      ..add({'role': 'user', 'content': enrichedMessage});

    final response = await GeminiService.sendAndWait(
      geminiMessages,
      systemPrompt: _systemPrompt,
    );

    // Simulate streaming for consistent UI
    for (int i = 0; i < response.length; i += 4) {
      final end = (i + 4).clamp(0, response.length);
      _currentResponse += response.substring(i, end);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 15));
    }
    _currentResponse = response;

    _history.add({'role': 'assistant', 'content': _currentResponse});
    _isGenerating = false;
    _saveHistory();
    notifyListeners();
  }

  Future<void> _sendViaColibri(String userMessage,
      {Map<String, double>? healthData}) async {
    // Simulate a small delay for UI consistency
    await Future.delayed(const Duration(milliseconds: 100));

    final personality = AppSettings.getCoachPersonality();
    // Personalize: today's mood check-in shapes the coach's tone.
    int? lastMood;
    try {
      lastMood = (await MoodService.getToday())?.mood;
    } catch (_) {}
    final response = ColibriEngine.instance.respond(
      userMessage,
      healthData: healthData,
      personality: personality,
      lastMood: lastMood,
    );

    // Simulate streaming for consistent UI
    for (int i = 0; i < response.length; i += 4) {
      final end = (i + 4).clamp(0, response.length);
      _currentResponse += response.substring(i, end);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 15));
    }
    _currentResponse = response;

    _history.add({'role': 'assistant', 'content': _currentResponse});
    _isGenerating = false;
    _saveHistory();
    notifyListeners();
  }

  // ─── Cancel generation ─────────────────────────────────────────
  void cancelGeneration() {
    _engine?.cancelGeneration();
    if (_currentResponse.isNotEmpty) {
      _history.add({'role': 'assistant', 'content': _currentResponse});
    }
    _isGenerating = false;
    _currentResponse = '';
    notifyListeners();
  }

  // ─── Clear chat history ────────────────────────────────────────
  void clearHistory() {
    _history.clear();
    _currentResponse = '';
    _saveHistory();
    notifyListeners();
  }

  // ─── Unload model (free RAM) ──────────────────────────────────
  Future<void> unloadModel() async {
    await _engine?.dispose();
    _engine = null;
    _isLoaded = false;
    _engineMode = EngineMode.colibri;
    _loadingModelId = null;
    notifyListeners();
  }

  // ─── Send and wait (for insights/reports) ─────────────────────
  Future<String> sendAndWait(String userMessage,
      {Map<String, double>? healthData}) async {
    await sendMessage(userMessage, healthData: healthData);
    while (_isGenerating) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _currentResponse;
  }

  /// Generate a standalone text (weekly reports, briefings) WITHOUT touching
  /// chat history. Routes GGUF → Gemini, returns null when neither is
  /// available so the caller can fall back to Colibri (procedural).
  /// The returned record reports which engine produced the text — honest UI.
  Future<({String text, String engine})?> generateStandalone(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 128,
  }) async {
    // 1) On-device GGUF model
    if (_isLoaded && _engine != null) {
      try {
        final isMicro = _loadedTier == ModelTier.micro;
        final buf = StringBuffer();
        final messages = <LlamaChatMessage>[
          LlamaChatMessage.fromText(
            role: LlamaChatRole.system,
            text: systemPrompt ??
                (isMicro
                    ? 'You are a health coach. Answer briefly using the data provided.'
                    : _systemPrompt),
          ),
          LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt),
        ];
        await for (final chunk in _engine!.create(
          messages,
          params: GenerationParams(
              maxTokens: isMicro ? maxTokens.clamp(0, 128) : maxTokens,
              temp: 0.8),
        )) {
          final t = chunk.choices.first.delta.content;
          if (t != null) buf.write(t);
        }
        final text = buf.toString().trim();
        if (text.isNotEmpty) {
          return (
            text: text,
            engine: 'TinyLlama (on-device)',
          );
        }
      } catch (_) {/* fall through */}
    }

    // 2) Cloud Gemini
    if (GeminiService.isConfigured && GeminiService.isEnabled) {
      try {
        final text = await GeminiService.sendAndWait(
          [
            {'role': 'user', 'content': prompt}
          ],
          systemPrompt: systemPrompt ?? _systemPrompt,
        );
        if (text.trim().isNotEmpty) {
          return (text: text.trim(), engine: 'Gemini (cloud)');
        }
      } catch (_) {/* fall through */}
    }

    // 3) Nothing generative available
    return null;
  }

  /// Generate weekly summary (for weekly summary screen).
  /// History-free: does NOT pollute the coach chat. Falls back to a
  /// procedural summary when no generative engine is available.
  /// Accepts both key spellings ('steps'/'stepsTotal', etc.).
  Future<String> generateWeeklySummary(Map<String, dynamic> weekData) async {
    final steps = (weekData['steps'] ?? weekData['stepsTotal']) ?? 0;
    final distance = weekData['distance'] ?? weekData['distanceTotal'] ?? '0';
    final calories =
        (weekData['calories'] ?? weekData['caloriesTotal']) ?? 0;
    final days = (weekData['days'] ??
            ((weekData['avgSteps'] != null && weekData['avgSteps'] != 0 &&
                    steps != 0)
                ? (steps / weekData['avgSteps']).round()
                : 0)) ??
        0;

    final prompt = '''Analyze this weekly health data and give a brief summary:

Steps: $steps
Distance: $distance
Calories burned: $calories
Days with data: $days

Give 2-3 bullet points highlighting trends and one recommendation.''';

    final result = await generateStandalone(prompt, maxTokens: 220);
    if (result != null) return result.text;

    // Procedural fallback — real numbers, no engine needed
    final stepsInt = (steps as num?)?.toInt() ?? 0;
    final kcal = (calories as num?)?.toInt() ?? 0;
    final daysInt = (days as num?)?.toInt() ?? 0;
    final avg = daysInt > 0 ? stepsInt ~/ daysInt : 0;
    final buf = StringBuffer();
    buf.writeln('• Weekly volume: $steps steps across $days synced days '
        '(~$avg/day).');
    buf.writeln('• Energy output: $kcal active kcal burned this week.');
    buf.writeln(avg >= 7000
        ? '• Trend: strong consistency — keep the daily average above 7k.'
        : '• Recommendation: add one 20-minute walk per day to lift the '
          'weekly average above 7k steps.');
    return buf.toString();
  }

  /// Suggest daily quests based on recent data.
  /// History-free; falls back to data-driven procedural suggestions.
  Future<List<String>> suggestDailyQuests(Map<String, dynamic> recentData) async {
    final workouts = (recentData['workoutsThisWeek'] as num?)?.toInt() ?? 0;
    final prompt = '''Suggest 3 simple daily quests for a health tracker user:
- Streak: ${recentData['streak']} days
- Level: ${recentData['level']}
- Workouts logged this week: $workouts

Return 3 short quest labels (like "Walk 8000 steps", "Drink 2L water", "Stretch for 10 min").''';

    final result = await generateStandalone(prompt, maxTokens: 120);
    if (result != null) {
      // Accept both quoted and plain numbered/bulleted lines
      final parsed = result.text
          .split('\n')
          .map((l) => l
              .replaceFirst(RegExp(r'^\s*(?:\d+[\.\)]|[-•*])\s*'), '')
              .replaceAll('"', '')
              .trim())
          .where((s) => s.isNotEmpty && s.length < 60)
          .take(3)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    // Procedural fallback — scale targets to the hunter
    final level = (recentData['level'] as num?)?.toInt() ?? 1;
    final streak = (recentData['streak'] as num?)?.toInt() ?? 0;
    final stepTarget = 3000 + 500 * (level - 1);
    final waterTarget = 2000;
    final pushTarget = 10 + 2 * (level - 1);
    return [
      'Walk ${stepTarget.clamp(3000, 20000)} steps',
      'Drink ${(waterTarget ~/ 100) * 100} ml of water',
      streak >= 3
          ? 'Keep the $streak-day streak alive'
          : 'Do $pushTarget push-ups',
    ];
  }
}
