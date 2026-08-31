import 'dart:math';

/// Colibri v2 — a data-driven procedural health coach.
/// Not templates — responses are algorithmically constructed from real data + conversation context.
class ColibriEngine {
  static final ColibriEngine instance = ColibriEngine._();
  ColibriEngine._();

  final Random _rand = Random();
  final List<String> _recentResponses = [];

  // ─── Conversation memory ────────────────────────────────────────
  final List<Map<String, String>> _conversationHistory = [];
  String _lastTopic = '';
  int _turnCount = 0;

  String respond(
    String userMessage, {
    Map<String, double>? healthData,
    String personality = 'motivational',
    int? lastMood, // 1-5 from the mood tracker; drives empathetic tone
  }) {
    _turnCount++;
    final msg = userMessage.toLowerCase().trim();
    final data = healthData ?? {};
    final steps = data['steps']?.toInt() ?? 0;
    final dist = data['distance'] ?? 0.0;
    final cal = data['activeEnergy']?.toInt() ?? 0;
    // Low mood from recent check-ins softens every response — the coach
    // adapts to how the hunter FEELS, not just what they did.
    final mood = lastMood;
    final lowMood = mood != null && mood <= 2;
    final highMood = mood != null && mood >= 4;

    // Detect topic
    final topic = _detectTopic(msg);
    final isFollowUp = topic == _lastTopic && _turnCount > 1;
    _lastTopic = topic;

    _conversationHistory.add({'role': 'user', 'content': msg});

    // Build response procedurally
    String response;
    switch (topic) {
      case 'briefing':
        response = _buildBriefingResponse(steps, dist, cal, personality);
        break;
      case 'steps':
        response = _buildStepsResponse(msg, steps, dist, cal, isFollowUp, personality);
        break;
      case 'calories':
        response = _buildCaloriesResponse(msg, steps, cal, dist, isFollowUp, personality);
        break;
      case 'distance':
        response = _buildDistanceResponse(msg, dist, steps, isFollowUp, personality);
        break;
      case 'sleep':
        response = _buildSleepResponse(msg, isFollowUp, personality);
        break;
      case 'hydration':
        response = _buildHydrationResponse(msg, steps, isFollowUp, personality);
        break;
      case 'workout':
        response = _buildWorkoutResponse(msg, steps, cal, isFollowUp, personality);
        break;
      case 'nutrition':
        response = _buildNutritionResponse(msg, cal, steps, isFollowUp, personality);
        break;
      case 'mental':
        response = _buildMentalResponse(msg, isFollowUp, personality);
        break;
      case 'recovery':
        response = _buildRecoveryResponse(msg, cal, isFollowUp, personality);
        break;
      case 'stats':
        response = _buildStatsResponse(msg, isFollowUp, personality);
        break;
      case 'quest':
        response = _buildQuestResponse(msg, isFollowUp, personality);
        break;
      case 'greeting':
        response = _buildGreetingResponse(steps, cal, personality);
        break;
      case 'thanks':
        response = _buildThanksResponse(personality);
        break;
      case 'help':
        response = _buildHelpResponse(personality);
        break;
      case 'progress':
        response = _buildProgressResponse(msg, steps, dist, cal, isFollowUp, personality);
        break;
      default:
        if (steps > 0 || cal > 0) {
          response = _buildContextualResponse(msg, steps, dist, cal, personality);
        } else {
          response = _buildGenericResponse(msg, isFollowUp, personality);
        }
    }

    // Mood adaptation: prepend empathy when the hunter is struggling,
    // acknowledge energy when they're thriving. Works across ALL topics.
    if (lowMood) {
      final prefix = [
        "I noticed today's mood check-in was low. Rest counts as training too.",
        "Hard day, hunter? Recovery is part of the grind — no shame in an easier pace.",
        "Low energy detected. Let's aim for small wins today, not records.",
      ][_turnCount % 3];
      response = '$prefix\n\n$response';
    } else if (highMood) {
      final prefix = [
        "Strong mood today — good time to push a little harder.",
        "Your energy is up. Capitalize on it while it lasts.",
      ][_turnCount % 2];
      response = '$prefix\n\n$response';
    }

    // Avoid exact repetition
    int attempts = 0;
    while (_recentResponses.contains(response) && attempts < 3) {
      attempts++;
      response = _appendVariation(response, topic, personality);
    }
    _recentResponses.add(response);
    if (_recentResponses.length > 20) _recentResponses.removeAt(0);

    _conversationHistory.add({'role': 'assistant', 'content': response});
    return response;
  }

  // ─── Topic detection ────────────────────────────────────────────
  String _detectTopic(String msg) {
    if (_any(msg, ['briefing', 'plan my day', 'morning report', 'daily plan', 'overview of today'])) return 'briefing';
    if (_any(msg, ['step', 'walk', 'pedometer', '10k', '10000'])) return 'steps';
    if (_any(msg, ['calori', 'kcal', 'burn', 'energy', 'tdee'])) return 'calories';
    if (_any(msg, ['distance', 'km', 'kilometer', 'mile', 'far'])) return 'distance';
    if (_any(msg, ['sleep', 'rest', 'tired', 'exhaust', 'bed', 'insomnia', 'nap'])) return 'sleep';
    if (_any(msg, ['water', 'hydrat', 'drink', 'thirsty', 'fluid'])) return 'hydration';
    if (_any(msg, ['workout', 'exercise', 'gym', 'strength', 'muscle', 'lift', 'pushup', 'squat', 'cardio', 'training', 'run', 'jog'])) return 'workout';
    if (_any(msg, ['protein', 'carb', 'fat', 'vitamin', 'supplement', 'creatine', 'nutrition', 'food', 'eat', 'meal', 'diet', 'weight loss', 'obesity'])) return 'nutrition';
    if (_any(msg, ['stress', 'anxiety', 'mental', 'depress', 'mood', 'happy', 'sad', 'angry', 'overwhelm', 'burnout', 'lonely', 'motivation', 'discipline'])) return 'mental';
    if (_any(msg, ['sore', 'recovery', 'pain', 'injur', 'stretch', 'flexib', 'rest day', 'heal', 'ic'])) return 'recovery';
    if (_any(msg, ['level', 'xp', 'rank', 'stat', 'strength', 'agility', 'vitality', 'intelligence', 'perception', 'point', 'upgrade'])) return 'stats';
    if (_any(msg, ['quest', 'mission', 'objective', 'daily', 'challenge', 'task'])) return 'quest';
    if (_any(msg, ['hello', 'hi', 'hey', 'sup', 'how are you', 'greetings', 'good morning', 'good evening', 'good night'])) return 'greeting';
    if (_any(msg, ['thank', 'thanks', 'thx', 'appreciate', 'helpful'])) return 'thanks';
    if (_any(msg, ['help', 'what can you', 'how do', 'how to', 'guide', 'tutorial', 'what do you'])) return 'help';
    if (_any(msg, ['progress', 'trend', 'improve', 'compare', 'better', 'worse', 'average'])) return 'progress';
    return 'unknown';
  }

  bool _any(String msg, List<String> keywords) => keywords.any((k) => msg.contains(k));

  // ─── STEP RESPONSES ─────────────────────────────────────────────
  String _buildStepsResponse(String msg, int steps, double dist, int cal, bool followUp, String p) {
    final goal = 10000;
    final pct = goal > 0 ? (steps / goal * 100).toInt().clamp(0, 999) : 0;
    final remaining = (goal - steps).clamp(0, goal);
    final hoursLeft = 16 - DateTime.now().hour; // hours left in day

    String analysis;
    if (steps == 0) {
      analysis = "You haven't logged any steps yet today. Your phone's accelerometer will pick up movement automatically once you start walking.";
    } else if (steps < 2000) {
      analysis = "With $steps steps, you're at ${pct}% of your daily goal — still early in the day. A ${_estimateWalkTime(remaining)} walk would close the gap.";
    } else if (steps < 5000) {
      analysis = "$steps steps is ${pct}% of your 10K target. You're building momentum — the middle stretch is where discipline matters most.";
    } else if (steps < 8000) {
      analysis = "$steps steps puts you at ${pct}% — solid ground. You're ${remaining} steps from a complete quest. That's about a ${_estimateWalkTime(remaining)} walk.";
    } else if (steps < 10000) {
      analysis = "$steps steps — you're ${remaining} steps away from the 10K goal. That's literally a ${_estimateWalkTime(remaining)} walk. Finish strong.";
    } else {
      analysis = "$steps steps — you've ${steps >= 15000 ? 'smashed' : 'crushed'} the 10K goal at ${pct}%. $dist km covered, roughly ${cal} kcal burned from movement alone.";
    }

    String pace;
    if (hoursLeft > 0 && steps > 0) {
      final currentRate = steps / DateTime.now().hour;
      final projected = (currentRate * 16).toInt();
      if (projected >= goal) {
        pace = "At your current pace of ~${currentRate.toInt()} steps/hour, you'll hit ~$projected by end of day — above target.";
      } else {
        final needed = (goal / 16).toInt();
        pace = "You need ~$needed steps/hour to finish at 10K. You're currently at ~${currentRate.toInt()}/hour.";
      }
    } else {
      pace = "";
    }

    final followUpQ = followUp
      ? ""
      : _pick([
          "\n\nWant me to suggest a route or workout to hit your target?",
          "\n\nHow does your current pace compare to yesterday?",
          "\n\nShould I set a step goal reminder?",
          "\n\nWant tips on increasing your daily average?",
        ]);

    return _wrap(p, '🏃', analysis + (pace.isNotEmpty ? "\n\n$pace" : "") + followUpQ);
  }

  // ─── CALORIES RESPONSES ────────────────────────────────────────
  // ─── BRIEFING RESPONSE ──────────────────────────────────────────
  /// Procedural morning briefing assembled from real data. Used when no
  /// generative engine (GGUF/Gemini) is available — still data-driven.
  String _buildBriefingResponse(int steps, double dist, int cal, String p) {
    final parts = <String>[];
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');

    parts.add('$greeting, hunter.');

    if (steps > 0) {
      parts.add('So far today: $steps steps'
          '${dist > 0 ? ', ${dist.toStringAsFixed(1)} km' : ''}'
          '${cal > 0 ? ', $cal kcal burned' : ''}.');
    } else {
      parts.add('No movement logged yet today — the first walk is always the hardest.');
    }

    // Activity-based focus line
    if (steps >= 8000) {
      parts.add('You are already ahead of the curve — protect the streak with light movement.');
    } else if (steps >= 4000) {
      parts.add('Focus: add a 15-minute walk to close the gap to 8000 steps.');
    } else {
      parts.add('Focus: hit 4000 steps before evening. Small bursts count.');
    }

    parts.add(_wrap(p, '📋',
        'The System will re-evaluate at your next sync. Stay consistent.'));

    return parts.join('\n\n');
  }

  String _buildCaloriesResponse(String msg, int steps, int cal, double dist, bool followUp, String p) {
    final bmr = 1800; // average BMR estimate
    final total = bmr + cal;
    final fromSteps = (steps * 0.04).toInt(); // ~0.04 kcal per step

    String analysis;
    if (cal == 0 && steps == 0) {
      analysis = "No activity data yet today. Once you move, I'll track your active calorie burn in real-time. Your basal metabolic rate (BMR) is burning roughly ~$bmr kcal just existing.";
    } else {
      analysis = "Active burn today: **$cal kcal** from movement. "
          "${steps > 0 ? 'Of that, ~$fromSteps kcal came from your $steps steps.' : ''} "
          "Combined with your resting metabolism (~$bmr kcal/day), your estimated total expenditure today is ~$total kcal.";
    }

    String context;
    if (cal > 500) {
      context = "That's equivalent to burning off a full meal — impressive output.";
    } else if (cal > 200) {
      context = "Decent active burn. To put it in perspective: a banana is ~105 kcal, so you've burned the equivalent of ~${(cal / 105).toStringAsFixed(1)} bananas worth of energy.";
    } else if (cal > 50) {
      context = "Every calorie counts — even light movement adds up over the week.";
    } else {
      context = "The burn will ramp up as you get moving. Even a 15-minute walk adds ~60-80 kcal.";
    }

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant to know what exercises burn the most per minute?",
      "\n\nShould I track your nutrition intake alongside burn?",
      "\n\nWant to see how this compares to your weekly average?",
    ]);

    return _wrap(p, '🔥', "$analysis\n\n$context$followUpQ");
  }

  // ─── DISTANCE RESPONSES ────────────────────────────────────────
  String _buildDistanceResponse(String msg, double dist, int steps, bool followUp, String p) {
    final goalKm = 8.0;
    final pct = (dist / goalKm * 100).toInt().clamp(0, 999);
    final kmRemaining = (goalKm - dist).clamp(0.0, goalKm);

    String analysis;
    if (dist == 0) {
      analysis = "No distance data yet. Once you start walking, your phone's GPS or accelerometer will track distance automatically.";
    } else {
      analysis = "You've covered **${dist.toStringAsFixed(1)} km** today — ${pct}% of an 8 km daily target.";
      if (dist < 1) {
        analysis += " That's roughly ${_kmToMinWalk(dist)} minutes of walking at a casual pace.";
      } else if (dist < 5) {
        analysis += " That's like walking from one end of a small town to the other.";
      } else if (dist < 10) {
        analysis += " Great distance — that's a solid commute-by-foot territory.";
      } else {
        analysis += " Impressive — that's over a 10K race distance.";
      }
    }

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant me to compare this to your weekly average?",
      "\n\nShould I suggest a walking route to hit your target?",
      "\n\nHow does your walking distance affect your overall health score?",
    ]);

    return _wrap(p, '📏', "$analysis\n\n${kmRemaining > 0 ? '${kmRemaining.toStringAsFixed(1)} km remaining to your daily target.' : 'Target smashed!'}$followUpQ");
  }

  // ─── SLEEP RESPONSES ───────────────────────────────────────────
  String _buildSleepResponse(String msg, bool followUp, String p) {
    final hour = DateTime.now().hour;
    String timeAdvice;
    if (hour >= 22 || hour < 5) {
      timeAdvice = "It's late — if you're going to sleep soon, your body will thank you for a consistent bedtime. The first 90 minutes of sleep are the deepest and most restorative.";
    } else if (hour >= 5 && hour < 12) {
      timeAdvice = "Good morning! Sleep quality starts the night before — consistent wake times train your circadian clock to wake you naturally.";
    } else {
      timeAdvice = "Your sleep tonight starts with what you do today: get sunlight in the morning, limit caffeine after 2 PM, and avoid screens 1 hour before bed.";
    }

    final tips = [
      "Sleep architecture breakdown:",
      "• Stage 1 (N1): Light transition — 5% of night",
      "• Stage 2 (N2): Body temperature drops — 45% of night",
      "• Stage 3 (N3): Deep sleep, muscle repair — 25% of night",
      "• REM: Memory consolidation, dreaming — 25% of night",
      "",
      "The key insight: it's not just hours — it's cycles. Each cycle is ~90 minutes, so sleeping 7.5 hours (5 cycles) is often better than 8 hours (waking mid-cycle).",
    ];

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant a wind-down routine tailored to your schedule?",
      "\n\nShould I track your sleep and correlate it with next-day performance?",
      "\n\nWant tips on beating specific sleep problems?",
    ]);

    return _wrap(p, '😴', "$timeAdvice\n\n${_join(tips)}$followUpQ");
  }

  // ─── HYDRATION RESPONSES ───────────────────────────────────────
  String _buildHydrationResponse(String msg, int steps, bool followUp, String p) {
    final weight = 70; // estimated
    final baseNeed = (weight * 0.033).toInt(); // 33ml per kg
    final activityBonus = steps > 5000 ? 500 : steps > 2000 ? 300 : 0;
    final totalNeed = baseNeed + activityBonus;

    String analysis = "For a ~${weight}kg person";
    if (steps > 0) {
      analysis += " with $steps steps today, you need roughly **${(totalNeed / 1000).toStringAsFixed(1)}L** of water.";
    } else {
      analysis += " at rest, you need ~**${(baseNeed / 1000).toStringAsFixed(1)}L** minimum.";
    }

    final science = [
      "Why hydration matters more than you think:",
      "• Every cell in your body needs water to function",
      "• 2% dehydration = 20% cognitive decline",
      "• Dehydration mimics hunger — you might eat when you're actually thirsty",
      "• Athletes lose 1-2L per hour of exercise",
      "• Your brain is 75% water — even mild dehydration shrinks it temporarily",
    ];

    final practical = [
      "Practical hydration system:",
      "• Start your day with 500ml immediately upon waking",
      "• Drink a glass before every meal (also reduces overeating)",
      "• Set a bottle on your desk — visibility = consumption",
      "• Urine check: pale yellow = good, dark = drink more, clear = you might be overhydrating",
    ];

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant me to set hydration reminders throughout the day?",
      "\n\nShould I factor weather and activity into your water goal?",
      "\n\nWant to know about electrolytes vs plain water?",
    ]);

    return _wrap(p, '💧', "$analysis\n\n${_join(science)}\n\n${_join(practical)}$followUpQ");
  }

  // ─── WORKOUT RESPONSES ─────────────────────────────────────────
  String _buildWorkoutResponse(String msg, int steps, int cal, bool followUp, String p) {
    final hour = DateTime.now().hour;
    final isMorning = hour < 10;
    final isAfternoon = hour >= 12 && hour < 17;
    final isEvening = hour >= 17;

    String recommendation;
    if (isMorning) {
      recommendation = "Morning workouts are excellent — cortisol is naturally high, boosting alertness. Start with a 5-min dynamic warmup, then hit your main workout.";
    } else if (isAfternoon) {
      recommendation = "Afternoon is actually when your body peaks physically: body temperature is highest, reaction time is fastest, and strength output is 5-10% greater than morning.";
    } else {
      recommendation = "Evening workouts work well, but finish at least 2 hours before bed — core temperature needs to drop for quality sleep. Focus on moderate intensity rather than max effort.";
    }

    final workout = _pickWorkout(steps, cal);
    final followUpQ = followUp ? "" : _pick([
      "\n\nWant me to build a full weekly training schedule?",
      "\n\nShould I adjust based on your current recovery status?",
      "\n\nWant specific sets/reps for any of these exercises?",
    ]);

    return _wrap(p, '💪', "$recommendation\n\n$workout$followUpQ");
  }

  // ─── NUTRITION RESPONSES ───────────────────────────────────────
  String _buildNutritionResponse(String msg, int cal, int steps, bool followUp, String p) {
    final estimatedTdee = 2200;
    final activityCal = cal;
    final recommended = estimatedTdee + activityCal;

    String analysis;
    if (_any(msg, ['protein'])) {
      analysis = "Protein is the most critical macronutrient for an active person:\n"
          "• Target: 1.6-2.2g per kg of body weight\n"
          "• For a 70kg person: 112-154g protein/day\n"
          "• Spread across 3-4 meals (30-40g each) for optimal muscle protein synthesis\n"
          "• Post-workout: 20-40g within 2 hours\n"
          "• Best sources: chicken breast (31g/100g), eggs (6g each), Greek yogurt (10g/100g), lentils (9g/100g)";
    } else if (_any(msg, ['carb', 'carbs'])) {
      analysis = "Carbs are fuel, not the enemy:\n"
          "• Active people need 3-5g per kg body weight\n"
          "• Complex carbs (oats, rice, sweet potato) provide sustained energy\n"
          "• Simple carbs (fruit, honey) are great around workouts\n"
          "• Timing matters: eat carbs 2-3 hours before exercise, and within 30min after for recovery\n"
          "• Low carb = low intensity. Your brain alone uses 120g glucose/day.";
    } else if (_any(msg, ['fat', 'fats'])) {
      analysis = "Healthy fats are essential for hormones and brain function:\n"
          "• Target: 0.8-1.2g per kg body weight\n"
          "• Omega-3s (fish, walnuts, flax): anti-inflammatory, heart health\n"
          "• Monounsaturated (olive oil, avocado): hormone production\n"
          "• Don't fear saturated fat in moderation — your body needs cholesterol for testosterone\n"
          "• Avoid trans fats entirely.";
    } else {
      analysis = "Today's activity burn: ~$activityCal kcal. Combined with your basal metabolism (~$estimatedTdee kcal), your total need is ~$recommended kcal.\n\n"
          "Macro split for active individuals:\n"
          "• Protein: 30% (~${(recommended * 0.30 / 4).toInt()}g) — muscle repair\n"
          "• Carbs: 45% (~${(recommended * 0.45 / 4).toInt()}g) — energy\n"
          "• Fat: 25% (~${(recommended * 0.25 / 9).toInt()}g) — hormones & satiety";
    }

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant a meal plan template based on your activity level?",
      "\n\nShould I track your calories alongside your exercise burn?",
      "\n\nWant supplement recommendations?",
    ]);

    return _wrap(p, '🥗', "$analysis$followUpQ");
  }

  // ─── MENTAL HEALTH RESPONSES ───────────────────────────────────
  String _buildMentalResponse(String msg, bool followUp, String p) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;

    String opening;
    if (_any(msg, ['stress', 'anxiety', 'overwhelm', 'burnout'])) {
      opening = "Stress isn't the enemy — unmanaged stress is. Here's your immediate intervention toolkit:";
    } else if (_any(msg, ['depress', 'sad', 'lonely'])) {
      opening = "I hear you. Low moods are part of being human — they don't define you. Here are evidence-based tools that actually work:";
    } else if (_any(msg, ['angry', 'frustrat'])) {
      opening = "Anger is energy — it's telling you something needs to change. Here's how to channel it productively:";
    } else if (_any(msg, ['motivation', 'discipline'])) {
      opening = "Motivation is unreliable — it comes and goes. Systems beat motivation every time. Here's how to build one:";
    } else {
      opening = "Mental health is the foundation everything else is built on. Here are practices backed by neuroscience:";
    }

    final techniques = _any(msg, ['motivation', 'discipline'])
        ? [
            "The discipline framework:",
            "• Never rely on motivation — build habits instead",
            "• The 2-minute rule: if it takes <2min, do it now",
            "• Stack habits: attach new habits to existing ones",
            "• Track streaks — visual progress is addictive",
            "• Start embarrassingly small — consistency > intensity",
            "• Environment design > willpower (remove friction)",
          ]
        : [
            "Immediate tools (evidence-based):",
            "• Box breathing: 4s in → 4s hold → 4s out → 4s hold (2 min resets cortisol)",
            "• 5-4-3-2-1 grounding: name 5 things you see, 4 hear, 3 touch, 2 smell, 1 taste",
            "• Cold water on wrists/face: activates the dive reflex, drops heart rate in 30 seconds",
            "• 20-minute walk outside: proven to reduce anxiety as effectively as medication for mild cases",
            "• Write 3 specific things you're grateful for (specificity matters)",
            "• Call someone — social connection is the #1 predictor of resilience",
          ];

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant me to build a daily mental wellness routine?",
      "\n\nShould I correlate your mood with your activity and sleep data?",
      "\n\nWant to talk about a specific challenge you're facing?",
    ]);

    return _wrap(p, '🧠', "$opening\n\n${_join(techniques)}$followUpQ");
  }

  // ─── RECOVERY RESPONSES ────────────────────────────────────────
  String _buildRecoveryResponse(String msg, int cal, bool followUp, String p) {
    final recovery = [
      "Recovery is where growth happens — training is just the stimulus.",
      "",
      "The 4 pillars of recovery:",
      "1. **Sleep** (7-9 hrs): Growth hormone peaks during deep sleep. One bad night can reduce testosterone by 15%.",
      "2. **Nutrition**: Protein within 2hrs of training. Anti-inflammatory foods: berries, fatty fish, turmeric, dark chocolate.",
      "3. **Active recovery**: Light movement (walking, swimming) promotes blood flow without stressing muscles. 30 min of easy walking beats sitting on the couch.",
      "4. **Stress management**: Mental stress delays physical recovery. Cortisol directly competes with testosterone.",
      "",
      "Timeline: DOMS (delayed onset muscle soreness) peaks 24-72 hours post-exercise. If you're still sore, your body isn't ready for the same stimulus again.",
    ];

    final followUpQ = followUp ? "" : _pick([
      "\n\nWant a foam rolling routine?",
      "\n\nShould I check if you're overtraining based on your recent activity?",
      "\n\nWant cold/heat therapy guidelines?",
    ]);

    return _wrap(p, '🔄', "${_join(recovery)}$followUpQ");
  }

  // ─── STATS RESPONSES ───────────────────────────────────────────
  String _buildStatsResponse(String msg, bool followUp, String p) {
    final builds = {
      '🏃 Runner': 'STR 3 / AGI 5 / VIT 4 / INT 2 / PER 3 — Maximizes endurance and speed. High AGI improves running economy.',
      '🏋️ Lifter': 'STR 5 / AGI 2 / VIT 4 / INT 2 / PER 3 — Raw power focus. High STR increases load capacity and reduces fatigue.',
      '🧘 Yogi': 'STR 2 / AGI 3 / VIT 3 / INT 5 / PER 5 — Mind-body connection. INT improves focus during meditation.',
      '⚔️ Balanced': 'STR 3 / AGI 3 / VIT 3 / INT 3 / PER 3 — Jack of all trades. Safe choice, adapts to any challenge.',
      '🧠 Scholar': 'STR 1 / AGI 2 / VIT 3 / INT 5 / PER 4 — Cognitive focus. Better sleep quality and stress management.',
    };

    final selected = _pickBuild(builds);
    final followUpQ = followUp ? "" : _pick([
      "\n\nWant me to explain how each stat affects real-world performance?",
      "\n\nShould I recommend a build based on your activity patterns?",
      "\n\nWant to know when you'll reach the next level?",
    ]);

    return _wrap(p, '⚔️', "$selected\n\n💡 Each level grants +3 stat points. XP needed to level: 100 + 25 × (current level - 1).$followUpQ");
  }

  // ─── QUEST RESPONSES ───────────────────────────────────────────
  String _buildQuestResponse(String msg, bool followUp, String p) {
    final response = "Your daily quest system works like this:\n\n"
        "• **Auto-generated** from your Health Connect data each morning\n"
        "• **Manual objectives** can be added via the + button on the Hunter screen\n"
        "• **AI suggestions** available via the ✨ AI Suggest button\n"
        "• **XP reward**: 15 XP per completed objective\n"
        "• **Perfect Day bonus**: complete ALL objectives for bonus XP\n"
        "• **Streak multiplier**: consecutive perfect days amplify rewards\n\n"
        "The system adapts: if you consistently crush your quests, the difficulty scales up. If you're falling behind, it adjusts to keep you motivated.\n\n"
        "💡 Pro tip: Complete quests before midnight to maintain your streak.";

    return _wrap(p, '⚔️', response);
  }

  // ─── GREETING RESPONSES ────────────────────────────────────────
  String _buildGreetingResponse(int steps, int cal, String p) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : hour < 21 ? 'Good evening' : 'Burning the midnight oil';

    final status = steps > 0
        ? "You're at $steps steps and $cal kcal burned today."
        : "No activity logged yet today.";

    final prompt = _pick([
      "What are we working on today?",
      "What do you need help with?",
      "Ready to level up?",
      "How can I help you crush today's goals?",
    ]);

    return _wrap(p, '👋', "$greeting, hunter. $status\n\n$prompt");
  }

  // ─── THANKS RESPONSES ──────────────────────────────────────────
  String _buildThanksResponse(String p) {
    return _wrap(p, '🙏', _pick([
      "Anytime. That's what your coach is here for.",
      "You're doing the hard part — I'm just pointing the way.",
      "The fact that you're asking means you're already ahead of most people.",
      "Keep showing up. Consistency is the only secret.",
    ]));
  }

  // ─── HELP RESPONSES ────────────────────────────────────────────
  String _buildHelpResponse(String p) {
    return _wrap(p, '🤖', "I'm your data-driven health coach. Everything I say is based on sports science and your actual health data.\n\n"
        "Ask me about:\n"
        "• **Steps & distance** — progress, pace, goals\n"
        "• **Calories** — burn analysis, TDEE, deficits\n"
        "• **Workouts** — programming, timing, technique\n"
        "• **Sleep** — optimization, architecture, routines\n"
        "• **Hydration** — personalized targets, electrolytes\n"
        "• **Nutrition** — macros, meal timing, supplements\n"
        "• **Mental health** — stress, motivation, mindfulness\n"
        "• **Recovery** — soreness, rest, injury prevention\n"
        "• **Stats** — stat allocation, level progression\n"
        "• **Quests** — how the daily system works\n\n"
        "I reference your real Health Connect data, so specific questions get specific answers.");
  }

  // ─── PROGRESS RESPONSES ────────────────────────────────────────
  String _buildProgressResponse(String msg, int steps, double dist, int cal, bool followUp, String p) {
    final response = "Here's your data snapshot:\n\n"
        "📊 **Today:** $steps steps • ${dist.toStringAsFixed(1)} km • $cal kcal\n"
        "🎯 **10K goal:** ${(steps / 100).toInt()}% complete\n"
        "📏 **Distance:** ${(dist / 8 * 100).toInt()}% of 8km daily target\n\n"
        "To see detailed trend charts, check the **Insights & Charts** section in Settings — it shows 7/14/30 day comparisons with bar charts and trend indicators.";

    final followUpQ = followUp ? "" : "\n\nWant me to analyze specific patterns in your data?";

    return _wrap(p, '📊', "$response$followUpQ");
  }

  // ─── CONTEXTUAL RESPONSES (have data) ──────────────────────────
  String _buildContextualResponse(String msg, int steps, double dist, int cal, String p) {
    final dataPoints = <String>[];
    if (steps > 0) dataPoints.add("$steps steps");
    if (dist > 0) dataPoints.add("${dist.toStringAsFixed(1)} km");
    if (cal > 0) dataPoints.add("$cal kcal burned");

    return _wrap(p, '📊', "Based on your current data (${dataPoints.join(', ')}):\n\n"
        "I can give you specific advice on any of these topics: steps, distance, calories, workouts, sleep, hydration, nutrition, mental health, or recovery.\n\n"
        "What would you like to dive into?");
  }

  // ─── GENERIC RESPONSES (no data) ───────────────────────────────
  String _buildGenericResponse(String msg, bool followUp, String p) {
    final responses = [
      "I'm built to help with health, fitness, nutrition, and recovery — all grounded in sports science. Try asking about a specific topic and I'll give you detailed, actionable advice.",
      "I work best with specific questions about your health data. Ask me about steps, sleep, workouts, nutrition, or how your stats work.",
      "For the most useful responses, try asking about something specific: 'How many steps should I walk?' or 'What should I eat after a workout?' — I'll use your real data to give personalized advice.",
    ];
    return _wrap(p, '💡', _pick(responses));
  }

  // ─── HELPER: PROSE CONSTRUCTION ────────────────────────────────
  String _pick(List<String> options) => options[_rand.nextInt(options.length)];

  String _join(List<String> lines) => lines.where((l) => l.isNotEmpty).join('\n');

  String _wrap(String personality, String emoji, String content) {
    final prefix = _getPrefix(personality);
    return '$emoji $prefix\n\n$content';
  }

  String _getPrefix(String personality) {
    switch (personality) {
      case 'analytical':
        return _pick([
          "Data analysis:",
          "Here's what the numbers say:",
          "Breaking down the metrics:",
          "Statistical assessment:",
        ]);
      case 'tough':
        return _pick([
          "Listen up:",
          "No sugar coating:",
          "Here's the truth:",
          "Real talk:",
        ]);
      case 'gentle':
        return _pick([
          "Here's something to think about:",
          "I noticed this in your data:",
          "Gentle reminder:",
          "For your consideration:",
        ]);
      default: // motivational
        return _pick([
          "Let me break this down:",
          "Here's what I see:",
          "Check this out:",
          "Looking at your data:",
        ]);
    }
  }

  String _estimateWalkTime(int steps) {
    final minutes = (steps / 100).toInt(); // ~100 steps/min walking
    if (minutes < 5) return "quick $minutes-min";
    if (minutes < 30) return "$minutes-min";
    if (minutes < 60) return "${minutes ~/ 60}h ${minutes % 60}min";
    return "${minutes ~/ 60} hours";
  }

  String _kmToMinWalk(double km) => "${(km * 12).toInt()}"; // ~5km/h = 12min/km

  String _pickWorkout(int steps, int cal) {
    if (steps > 8000) {
      return "You've already moved a lot today. Focus on recovery activities:\n• 15 min stretching or yoga\n• Foam rolling (10 min)\n• Light walk if you feel stiff";
    } else if (steps > 4000) {
      return "Good activity base today. Add intensity with:\n• 3 sets of 15 bodyweight squats\n• 3 sets of 10 push-ups\n• 2-min plank hold\n• 20 jumping jacks between sets";
    } else {
      return "Room for more activity. Try:\n• 20-min brisk walk (~2000 steps)\n• OR 15-min HIIT circuit\n• OR 30-min bike ride\n• OR simple: walk to a nearby errand instead of driving";
    }
  }

  String _pickBuild(Map<String, String> builds) {
    final keys = builds.keys.toList();
    final key = keys[_rand.nextInt(keys.length)];
    return "**$key build:**\n${builds[key]}";
  }

  String _appendVariation(String response, String topic, String personality) {
    // Add a random data point or tip to make it different
    final additions = [
      "\n\n💡 Quick tip: Consistency beats intensity every time.",
      "\n\n📌 Remember: Small daily improvements compound into massive results.",
      "\n\n🎯 Your body adapts to what you consistently do.",
    ];
    return response + _pick(additions);
  }
}
