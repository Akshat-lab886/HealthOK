// HealthOK — Main app with bottom navigation
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart' as health;
import 'package:health_ok/src/pages/permission_manager.dart';
import 'package:health_ok/src/pages/character_screen.dart';
import 'package:health_ok/src/pages/ai_coach_screen.dart';
import 'package:health_ok/src/pages/backup_screen.dart';
import 'package:health_ok/src/pages/weekly_summary_screen.dart';
import 'package:health_ok/src/pages/insights_screen.dart';
import 'package:health_ok/src/pages/hydration_screen.dart';
import 'package:health_ok/src/services/hydration_service.dart';
import 'package:health_ok/src/pages/achievements_screen.dart';
import 'package:health_ok/src/pages/sleep_screen.dart';
import 'package:health_ok/src/pages/workout_screen.dart';
import 'package:health_ok/src/pages/body_measurements_screen.dart';
import 'package:health_ok/src/pages/mood_screen.dart';
import 'package:health_ok/src/pages/quest_history_screen.dart';
import 'package:health_ok/src/pages/ai_insights_screen.dart';
import 'package:health_ok/src/pages/weekly_report_screen.dart';
import 'package:health_ok/src/pages/guild_screen.dart';
import 'package:health_ok/src/pages/food_log_screen.dart';
import 'package:health_ok/src/services/quest_service.dart';
import 'package:health_ok/src/services/model_manager.dart';
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:health_ok/src/services/notification_service.dart';
import 'package:health_ok/src/services/achievement_service.dart';
import 'package:health_ok/src/services/app_settings.dart';
import 'package:health_ok/src/services/briefing_service.dart';
import 'package:health_ok/src/services/settings_notifier.dart';
import 'package:health_ok/src/theme/app_colors.dart';
import 'package:health_ok/src/pages/onboarding_screen.dart';
import 'package:quest_engine/quest_engine.dart';
import 'package:storage/storage.dart';
import 'package:core_domain/core_domain.dart';

// Re-export AppColors so other files using `show AppColors` still work.
export 'src/theme/app_colors.dart' show AppColors, buildLightTheme, buildDarkTheme, AppColorsExt;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await NotificationService.init();
  await NotificationService.scheduleDailyQuestReminder();
  // Schedule notifications based on user preferences
  await AppSettings.init();
  if (AppSettings.getHydrationNotifs()) {
    await NotificationService.scheduleHydrationReminders();
  }
  if (AppSettings.getBriefingEnabled()) {
    await NotificationService.scheduleBriefingReminder();
  }
  // Archive yesterday's hydration on app start
  await HydrationService.archiveToday();
  runApp(const HealthOKSpikeApp());
}

class HealthOKSpikeApp extends StatefulWidget {
  const HealthOKSpikeApp({super.key});

  @override
  State<HealthOKSpikeApp> createState() => _HealthOKSpikeAppState();
}

class _HealthOKSpikeAppState extends State<HealthOKSpikeApp>
    with WidgetsBindingObserver {
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = AppSettingsNotifier.instance.themeMode;
    _themeMode.value = AppSettings.getThemeMode();
    _syncBrightness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Keep AppColors static palette in sync with the resolved brightness so
  /// non-context `AppColors.*` usages adapt to the active theme.
  ///
  /// NOTE: must NOT use MediaQuery.platformBrightnessOf(context) here —
  /// inherited-widget lookups are illegal in initState and throw
  /// "dependOnInheritedWidgetOfExactType was called before initState()
  /// completed" (the red ErrorWidget screen). platformDispatcher is
  /// context-free and safe in initState/build alike.
  void _syncBrightness() {
    final mode = _themeMode.value;
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platform == Brightness.dark);
    AppColors.setBrightness(isDark ? Brightness.dark : Brightness.light);
  }

  @override
  void didChangePlatformBrightness() {
    _syncBrightness();
    if (mounted) setState(() {}); // rebuild so MaterialApp re-resolves
  }

  @override
  Widget build(BuildContext context) {
    _syncBrightness();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'HealthOK',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        home: AppSettings.isOnboardingDone()
            ? const MainScreen()
            : const OnboardingScreen(),
        routes: {
          '/permissions': (context) => const PermissionManagerPage(),
        },
      ),
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

enum SyncPhase { idle, requesting, syncing, done, error }

class SyncPage extends StatefulWidget {
  final VoidCallback? onSyncComplete;
  final AiCoachService? coachService;

  const SyncPage({super.key, this.onSyncComplete, this.coachService});

  @override
  State<SyncPage> createState() => SyncPageState();
}

class SyncPageState extends State<SyncPage> with SingleTickerProviderStateMixin {
  final health.Health _health = health.Health();

  SyncPhase _phase = SyncPhase.idle;
  String _status = '';
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;
  int _weekSteps = 0;
  double _todayDistance = 0.0;
  double get todayDistance => _todayDistance;
  double _weekDistance = 0.0;
  double _todayEnergy = 0.0;
  double get todayEnergy => _todayEnergy;
  double _weekEnergy = 0.0;
  String? _errorDetail;

  // Morning briefing state
  String? _briefingText;
  String _briefingEngine = '';
  bool _briefingGenerating = false;
  int? _lastSyncedSteps;
  double? _lastSyncedDist;
  double? _lastSyncedEnergy;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _loadCachedBriefing();
        Future.delayed(const Duration(milliseconds: 800), _syncNow);
      },
    );
  }

  Future<void> _loadCachedBriefing() async {
    final cached = await BriefingService.getToday();
    if (cached == null || !mounted) return;
    setState(() {
      _briefingText = cached.text;
      _briefingEngine = cached.engine;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static final List<health.HealthDataType> _readTypes = [
    health.HealthDataType.STEPS,
    health.HealthDataType.DISTANCE_DELTA,
    health.HealthDataType.ACTIVE_ENERGY_BURNED,
    health.HealthDataType.SLEEP_SESSION,
    health.HealthDataType.SLEEP_ASLEEP,
  ];

  static final List<health.HealthDataAccess> _permissions =
      _readTypes.map((_) => health.HealthDataAccess.READ).toList();

  Future<bool> _ensurePermissions() async {
    setState(() {
      _phase = SyncPhase.requesting;
      _status = 'Requesting access…';
    });
    try {
      await _health.getHealthConnectSdkStatus();
    } catch (_) {}
    final granted = await _health.requestAuthorization(
      _readTypes,
      permissions: _permissions,
    );
    return granted;
  }

  Future<void> _syncNow() async {
    try {
      final granted = await _ensurePermissions();
      if (!mounted) return;
      if (!granted) {
        if (mounted) Navigator.pushNamed(context, '/permissions');
        setState(() {
          _phase = SyncPhase.error;
          _errorDetail = 'Health Connect access required.';
        });
        return;
      }

      setState(() {
        _phase = SyncPhase.syncing;
        _status = 'Syncing…';
      });

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));

      // Fetch from Health Connect
      int hcTodaySteps = 0;
      int hcWeekSteps = 0;
      double hcTodayDist = 0;
      double hcWeekDist = 0;
      double hcTodayEnergy = 0;
      double hcWeekEnergy = 0;

      try {
        hcTodaySteps = await _health.getTotalStepsInInterval(startOfToday, now) ?? 0;
        hcWeekSteps = await _health.getTotalStepsInInterval(weekAgo, now) ?? 0;
      } catch (_) {}

      try {
        final distToday = await _health.getHealthDataFromTypes(
          types: [health.HealthDataType.DISTANCE_DELTA],
          startTime: startOfToday,
          endTime: now,
        );
        final distWeek = await _health.getHealthDataFromTypes(
          types: [health.HealthDataType.DISTANCE_DELTA],
          startTime: weekAgo,
          endTime: now,
        );
        hcTodayDist = distToday.fold<double>(0.0, (s, p) => s + (p.value as double? ?? 0.0));
        hcWeekDist = distWeek.fold<double>(0.0, (s, p) => s + (p.value as double? ?? 0.0));
      } catch (_) {}

      try {
        final energyToday = await _health.getHealthDataFromTypes(
          types: [health.HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: startOfToday,
          endTime: now,
        );
        final energyWeek = await _health.getHealthDataFromTypes(
          types: [health.HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: weekAgo,
          endTime: now,
        );
        hcTodayEnergy = energyToday.fold<double>(0.0, (s, p) => s + (p.value as double? ?? 0.0));
        hcWeekEnergy = energyWeek.fold<double>(0.0, (s, p) => s + (p.value as double? ?? 0.0));
      } catch (_) {}

      // Also fetch from local DB to merge
      int localSteps = 0;
      double localDist = 0;
      double localEnergy = 0;
      try {
        final db = await AppDatabase.open();
        final todayLocal = await db.getTodayLocalSamples();
        for (final s in todayLocal) {
          final val = s.value ?? 0;
          if (s.type == HealthDataType.steps) localSteps += val.toInt();
          if (s.type == HealthDataType.distance) localDist += val;
          if (s.type == HealthDataType.activeEnergy) localEnergy += val;
        }
      } catch (_) {}

      final totalTodaySteps = hcTodaySteps + localSteps;
      final totalWeekSteps = hcWeekSteps + localSteps;
      final totalTodayDist = hcTodayDist + localDist;
      final totalWeekDist = hcWeekDist + localDist;
      final totalTodayEnergy = hcTodayEnergy + localEnergy;
      final totalWeekEnergy = hcWeekEnergy + localEnergy;

      if (!mounted) return;
      setState(() {
        _todaySteps = totalTodaySteps;
        _weekSteps = totalWeekSteps;
        _todayDistance = totalTodayDist;
        _weekDistance = totalWeekDist;
        _todayEnergy = totalTodayEnergy;
        _weekEnergy = totalWeekEnergy;
        _phase = SyncPhase.done;
        _status = 'Synced';
        _errorDetail = null;
      });

      // Auto-complete quest objectives from health data
      try {
        final healthData = <String, double>{
          'steps': totalTodaySteps.toDouble(),
          'distance': totalTodayDist,
          'activeEnergy': totalTodayEnergy,
        };
        await _checkQuests(healthData);
        widget.onSyncComplete?.call();
        // Morning briefing: generate once per day from fresh data
        _lastSyncedSteps = totalTodaySteps;
        _lastSyncedDist = totalTodayDist;
        _lastSyncedEnergy = totalTodayEnergy;
        if (AppSettings.getBriefingEnabled() &&
            widget.coachService != null) {
          _generateBriefing();
        }
      } catch (_) {}
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _phase = SyncPhase.error;
        _status = 'Sync failed';
        _errorDetail = '$e\n\n$st';
      });
    }
  }

  void refreshData() {
    _syncNow();
  }

  // ─── Morning briefing ─────────────────────────────────────────────
  Future<void> _generateBriefing({bool force = false}) async {
    final coach = widget.coachService;
    if (coach == null || _briefingGenerating) return;
    if (!force) {
      final cached = await BriefingService.getToday();
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _briefingText = cached.text;
          _briefingEngine = cached.engine;
        });
        return;
      }
    }
    if (force) await BriefingService.invalidate();

    setState(() => _briefingGenerating = true);
    try {
      final result = await BriefingService.generate(
        coach: coach,
        healthData: {
          'steps': (_lastSyncedSteps ?? _todaySteps).toDouble(),
          'distance': _lastSyncedDist ?? _todayDistance,
          'activeEnergy': _lastSyncedEnergy ?? _todayEnergy,
        },
      );
      if (!mounted) return;
      setState(() {
        _briefingText = result.text;
        _briefingEngine = result.engine;
      });
    } catch (_) {
      // Briefing is optional — silently skip on failure
    } finally {
      if (mounted) setState(() => _briefingGenerating = false);
    }
  }

  Future<void> _checkQuests(Map<String, double> healthData) async {
    final engine = const QuestEngine();
    final state = await QuestService.loadAll();

    // Include local hydration so the water objective auto-completes
    final dataWithWater = {
      ...healthData,
      'waterMl': (await HydrationService.getTodayMl()).toDouble(),
    };

    final toComplete = engine.checkHealthData(
      quest: state.quest,
      healthData: dataWithWater,
      alreadyCompleted: state.completed,
    );

    if (toComplete.isEmpty) return;

    var player = state.player;
    final newCompleted = Set<int>.from(state.completed);

    for (final idx in toComplete) {
      final result = engine.awardXp(player, xpPerObjective);
      player = result.player;
      newCompleted.add(idx);
    }

    if (newCompleted.length == state.quest.objectives.length &&
        state.quest.objectives.isNotEmpty) {
      final bonus = engine.awardXp(player, perfectDayBonus);
      player = bonus.player;
    }

    await QuestService.saveAll(
      player: player,
      quest: state.quest,
      completed: newCompleted,
    );

    // Check for newly unlocked achievements
    try {
      final db = await AppDatabase.open();
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      int totalSteps = 0;
      double totalDist = 0;
      final stepRows = await db.getSamplesForType(HealthDataType.steps, from: weekAgo);
      final distRows = await db.getSamplesForType(HealthDataType.distance, from: weekAgo);
      totalSteps = stepRows.fold<int>(0, (s, r) => s + (r.value?.toInt() ?? 0));
      totalDist = distRows.fold<double>(0, (s, r) => s + (r.value ?? 0));
      final achCtx = AchievementContext(
        level: player.level,
        streakDays: player.streakDays,
        bestStreak: player.bestStreak,
        totalXp: player.xp,
        unspentPoints: player.unspentPoints,
        strength: player.strength,
        agility: player.agility,
        vitality: player.vitality,
        intelligence: player.intelligence,
        perception: player.perception,
        totalStepsLast7Days: totalSteps,
        totalDistanceLast7Days: totalDist.toInt(),
        totalQuestsCompleted: newCompleted.length,
      );
      final newlyUnlocked = await AchievementService.checkAndUnlock(achCtx);
      for (final ach in newlyUnlocked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🏆 Achievement unlocked: ${ach.title}'),
              backgroundColor: const Color(0xFFFBBF24),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    } catch (e) {
    }

    // Show notifications
    for (final idx in toComplete) {
      final obj = state.quest.objectives[idx];
      NotificationService.showObjectiveCompleted(obj.label, xpPerObjective);
    }
    // Schedule streak-at-risk notification if streak > 0 and quest incomplete
    if (player.streakDays > 0 &&
        newCompleted.length < state.quest.objectives.length) {
      NotificationService.scheduleStreakAtRisk(player.streakDays);
    }
    if (newCompleted.length == state.quest.objectives.length &&
        state.quest.objectives.isNotEmpty) {
      NotificationService.showPerfectDay();
    }
    if (player.level > state.player.level) {
      NotificationService.showLevelUp(player.level);
    }
  }

  Future<void> _logAndRefresh(double value, HealthDataType type) async {
    final now = DateTime.now();
    final sample = Sample.create(
      type: type,
      startAt: now,
      endAt: now,
      value: value,
      source: Source.local(),
    );
    try {
      final db = await AppDatabase.open();
      await db.insertSample(sample);
      // Also write to Health Connect so it shows in user's wearable dashboard
      unawaited(_writeToHealthConnect(sample));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+$value ${type.name} logged ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
      await _syncNow();
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.energyColor),
        );
      }
    }
  }

  /// Write a single sample to Health Connect.
  /// Best-effort: silently no-ops on error so the local flow is not blocked.
  Future<void> _writeToHealthConnect(Sample sample) async {
    try {
      final hcType = _toHealthConnectType(sample.type);
      if (hcType == null) return;
      final v = sample.value;
      if (v == null) return;
      final start = sample.startAt;
      final end = sample.endAt;
      final success = await _health.writeHealthData(
        value: v,
        type: hcType,
        startTime: start,
        endTime: end,
      );
    } catch (e) {
    }
  }

  health.HealthDataType? _toHealthConnectType(HealthDataType t) {
    switch (t) {
      case HealthDataType.steps:
        return health.HealthDataType.STEPS;
      case HealthDataType.distance:
        return health.HealthDataType.DISTANCE_DELTA;
      case HealthDataType.activeEnergy:
        return health.HealthDataType.ACTIVE_ENERGY_BURNED;
      default:
        return null;
    }
  }

  /// Bulk-write today's local samples to Health Connect.
  /// Used by the user-tapped "Push to Health Connect" feature.
  /// Returns the number of samples written.
  Future<int> _pushTodayToHealthConnect() async {
    try {
      final db = await AppDatabase.open();
      final localSamples = await db.getTodayLocalSamples();
      int written = 0;
      for (final s in localSamples) {
        final hcType = _toHealthConnectType(s.type);
        if (hcType == null) continue;
        final v = s.value;
        if (v == null) continue;
        final success = await _health.writeHealthData(
          value: v,
          type: hcType,
          startTime: s.startAt,
          endTime: s.endAt,
        );
        if (success) written++;
      }
      return written;
    } catch (e) {
      return 0;
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();
    final dateStr = _formatDate(DateTime.now());
    final score = _calculateReadinessScore();

    return Container(
      decoration:  BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style:  TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'HealthOK',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                ).createShader(const Rect.fromLTWH(0, 0, 200, 30)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style:  TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/permissions'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Hero Score Circle ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Column(
                    children: [
                      Text(
                        'TODAY\'S READINESS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background ring
                            SizedBox(
                              width: 240,
                              height: 240,
                              child: CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 18,
                                strokeCap: StrokeCap.round,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                            // Progress ring
                            SizedBox(
                              width: 240,
                              height: 240,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: score),
                                duration: const Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 18,
                                    strokeCap: StrokeCap.round,
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.primary,
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Center text
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${score.round()}',
                                  style:  TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    score > 70
                                        ? 'Great'
                                        : score > 40
                                            ? 'Good'
                                            : 'Active',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatusPill(),
                    ],
                  ),
                ),
              ),

              // ── Morning Briefing ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _BriefingCard(
                    text: _briefingText,
                    engine: _briefingEngine,
                    generating: _briefingGenerating,
                    enabled: AppSettings.getBriefingEnabled(),
                    onGenerate: () => _generateBriefing(force: true),
                  ),
                ),
              ),

              // ── Metric Pills ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricPill(
                            icon: Icons.directions_walk_rounded,
                            value: '$_todaySteps',
                            unit: 'steps',
                            color: AppColors.stepsColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.textMuted.withOpacity(0.2),
                        ),
                        Expanded(
                          child: _MetricPill(
                            icon: Icons.route_rounded,
                            value: _todayDistance >= 1000
                                ? (_todayDistance / 1000).toStringAsFixed(1)
                                : _todayDistance.toStringAsFixed(0),
                            unit: _todayDistance >= 1000 ? 'km' : 'm',
                            color: AppColors.distanceColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.textMuted.withOpacity(0.2),
                        ),
                        Expanded(
                          child: _MetricPill(
                            icon: Icons.local_fire_department_rounded,
                            value: _todayEnergy.toStringAsFixed(0),
                            unit: 'kcal',
                            color: AppColors.energyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Weekly Chart ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly Steps',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$_weekSteps steps this week',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '7d',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 100,
                          child: _WeeklyChart(
                            currentWeekSteps: _weekSteps,
                            todaySteps: _todaySteps,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Action Buttons ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: (_phase == SyncPhase.requesting ||
                                  _phase == SyncPhase.syncing)
                              ? null
                              : _syncNow,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_phase == SyncPhase.syncing)
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  )
                                else
                                  Icon(Icons.sync_rounded,
                                      color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  _phase == SyncPhase.syncing
                                      ? 'Syncing...'
                                      : 'Sync Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: showQuickLogDialog,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom spacer ──
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  double _calculateReadinessScore() {
    // Simple composite score based on step progress to 10k goal
    final stepProgress = (_todaySteps / 10000).clamp(0.0, 1.0);
    final distanceProgress = (_todayDistance / 7000).clamp(0.0, 1.0);
    final energyProgress = (_todayEnergy / 500).clamp(0.0, 1.0);
    return ((stepProgress * 0.5 + distanceProgress * 0.25 + energyProgress * 0.25) * 100);
  }

  Widget _buildStatusPill() {
    Color pillColor;
    IconData pillIcon;
    switch (_phase) {
      case SyncPhase.requesting:
      case SyncPhase.syncing:
        pillColor = AppColors.primary;
        pillIcon = Icons.hourglass_top_rounded;
        break;
      case SyncPhase.done:
        pillColor = AppColors.success;
        pillIcon = Icons.check_circle_rounded;
        break;
      case SyncPhase.error:
        pillColor = AppColors.energyColor;
        pillIcon = Icons.error_rounded;
        break;
      default:
        pillColor = AppColors.textMuted;
        pillIcon = Icons.circle_outlined;
    }
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final opacity = _phase == SyncPhase.syncing || _phase == SyncPhase.requesting
            ? _pulseAnim.value
            : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pillColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(pillIcon, color: pillColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  _status.isEmpty ? 'Tap to sync' : _status,
                  style: TextStyle(
                    color: pillColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showQuickLogDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title:  Text('Quick Log', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Steps Section ──
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.stepsColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_walk_rounded, color: AppColors.stepsColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                   Text('Steps', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickStepChip(label: '1,000', onTap: () { Navigator.pop(context); _logAndRefresh(1000.0, HealthDataType.steps); }),
                  _QuickStepChip(label: '2,500', onTap: () { Navigator.pop(context); _logAndRefresh(2500.0, HealthDataType.steps); }),
                  _QuickStepChip(label: '5,000', onTap: () { Navigator.pop(context); _logAndRefresh(5000.0, HealthDataType.steps); }),
                  _QuickStepChip(label: '10,000', onTap: () { Navigator.pop(context); _logAndRefresh(10000.0, HealthDataType.steps); }),
                ],
              ),

              const SizedBox(height: 20),

              // ── Calories Section ──
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.energyColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: AppColors.energyColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                   Text('Calories (kcal)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickStepChip(label: '50', color: AppColors.energyColor, onTap: () { Navigator.pop(context); _logAndRefresh(50.0, HealthDataType.activeEnergy); }),
                  _QuickStepChip(label: '150', color: AppColors.energyColor, onTap: () { Navigator.pop(context); _logAndRefresh(150.0, HealthDataType.activeEnergy); }),
                  _QuickStepChip(label: '300', color: AppColors.energyColor, onTap: () { Navigator.pop(context); _logAndRefresh(300.0, HealthDataType.activeEnergy); }),
                  _QuickStepChip(label: '500', color: AppColors.energyColor, onTap: () { Navigator.pop(context); _logAndRefresh(500.0, HealthDataType.activeEnergy); }),
                ],
              ),

              const SizedBox(height: 20),

              // ── Distance Section ──
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.straighten_rounded, color: AppColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                   Text('Distance (km)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickStepChip(label: '0.5 km', color: AppColors.accent, onTap: () { Navigator.pop(context); _logAndRefresh(0.5, HealthDataType.distance); }),
                  _QuickStepChip(label: '1 km', color: AppColors.accent, onTap: () { Navigator.pop(context); _logAndRefresh(1.0, HealthDataType.distance); }),
                  _QuickStepChip(label: '2 km', color: AppColors.accent, onTap: () { Navigator.pop(context); _logAndRefresh(2.0, HealthDataType.distance); }),
                  _QuickStepChip(label: '5 km', color: AppColors.accent, onTap: () { Navigator.pop(context); _logAndRefresh(5.0, HealthDataType.distance); }),
                ],
              ),
            ],
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text('Close', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  /// Show the settings bottom sheet with backup, push to HC, and other actions.
  Future<void> showSettingsSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
               Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _SettingTile(
                icon: Icons.cloud_sync_rounded,
                title: 'Push to Health Connect',
                subtitle: 'Write today\'s local logs to Health Connect',
                color: AppColors.primary,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Writing to Health Connect...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  final written = await _pushTodayToHealthConnect();
                  if (written > 0) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Pushed $written entries to Health Connect ✓'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No local entries to push today'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.cloud_download_rounded,
                title: 'Backup & Restore',
                subtitle: 'Export your data to a JSON file',
                color: AppColors.accent,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BackupScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.calendar_view_week_rounded,
                title: 'Weekly AI Summary',
                subtitle: 'Get an AI insight on your week',
                color: AppColors.secondary,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WeeklySummaryScreen(
                        coachService: widget.coachService!,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.notifications_active_rounded,
                title: 'Daily Quest Reminder',
                subtitle: 'Reschedule the 8 AM quest reminder',
                color: const Color(0xFFFBBF24),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await NotificationService.cancelAll();
                  await NotificationService.scheduleDailyQuestReminder();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Daily reminder set for 8 AM ✓'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.insights_rounded,
                title: 'Insights & Charts',
                subtitle: 'See trends in your activity',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InsightsScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.water_drop_rounded,
                title: 'Hydration Tracker',
                subtitle: 'Log your daily water intake',
                color: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HydrationScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.emoji_events_rounded,
                title: 'Achievements',
                subtitle: 'Unlock badges for milestones',
                color: const Color(0xFFFBBF24),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.bedtime_rounded,
                title: 'Sleep Tracking',
                subtitle: 'View your sleep data',
                color: const Color(0xFF6366F1),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SleepScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.fitness_center_rounded,
                title: 'Workout Logger',
                subtitle: 'Log workouts and earn XP',
                color: const Color(0xFFF97316),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkoutScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.monitor_weight_rounded,
                title: 'Body Measurements',
                subtitle: 'Track weight, body fat, muscle',
                color: const Color(0xFF14B8A6),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BodyMeasurementsScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.mood_rounded,
                title: 'Mood Check-in',
                subtitle: 'Daily mood & energy logging',
                color: const Color(0xFFEC4899),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MoodScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.history_rounded,
                title: 'Quest History',
                subtitle: 'See your past quests',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuestHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.light_mode_rounded,
                title: 'Appearance',
                subtitle: 'Light, dark, or follow system',
                color: const Color(0xFFFCD34D),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showThemeSheet(context);
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.psychology_rounded,
                title: 'AI Coach Personality',
                subtitle: 'Tune how your coach talks',
                color: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showPersonalitySheet(context);
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle: 'Hydration & streak alerts',
                color: const Color(0xFFFBBF24),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showNotifSheet(context);
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.cloud_rounded,
                title: 'Cloud AI (Gemini)',
                subtitle: 'Free powerful AI for your coach',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showGeminiSheet(context);
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.psychology_rounded,
                title: 'AI Health Insights',
                subtitle: 'Analyze your weekly trends',
                color: const Color(0xFFEC4899),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiInsightsScreen(coachService: widget.coachService!),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.description_rounded,
                title: 'Weekly Report',
                subtitle: 'Generate & share your stats',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WeeklyReportScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.group_rounded,
                title: 'Guild Leaderboard',
                subtitle: 'Compete with other hunters',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GuildScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.restaurant_rounded,
                title: 'Food Log',
                subtitle: 'Track calories with photos',
                color: const Color(0xFFF97316),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FoodLogScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SettingTile(
                icon: Icons.tour_rounded,
                title: 'Replay Onboarding',
                subtitle: 'See the welcome screens again',
                color: AppColors.textSecondary,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await AppSettings.setOnboardingDone(false);
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const OnboardingScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
          ),
          ),
        );
      },
    );
  }

  // ─── Theme picker sheet ───────────────────────────────────────────────
  void _showThemeSheet(BuildContext rootContext) {
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
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
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Appearance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                ...ThemeMode.values.map((m) {
                  final labels = {
                    ThemeMode.system: ['🌓', 'System default', 'Follow your phone'],
                    ThemeMode.light: ['☀️', 'Light', 'Bright and airy'],
                    ThemeMode.dark: ['🌙', 'Dark', 'Easy on the eyes'],
                  };
                  final info = labels[m]!;
                  return RadioListTile<ThemeMode>(
                    value: m,
                    groupValue: AppSettings.getThemeMode(),
                    title: Row(
                      children: [
                        Text(info[0], style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(info[1],
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    subtitle: Text(info[2]),
                    onChanged: (v) async {
                      if (v == null) return;
                      await AppSettings.setThemeMode(v);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    activeColor: AppColors.primary,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Personality sheet ────────────────────────────────────────────────
  void _showPersonalitySheet(BuildContext rootContext) {
    final personalities = [
      ('motivational', '🔥', 'Motivational', 'High-energy, push you to win'),
      ('analytical', '📊', 'Analytical', 'Data-driven, calm advice'),
      ('tough', '🥊', 'Tough Love', 'No excuses, hard truths'),
      ('gentle', '🧘', 'Gentle', 'Compassionate, supportive'),
    ];
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
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
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'AI Coach Personality',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                 Text(
                  'How would you like your coach to talk to you?',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                ...personalities.map((p) {
                  final isSelected = AppSettings.getCoachPersonality() == p.$1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(p.$2, style: const TextStyle(fontSize: 28)),
                    title: Text(p.$3,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(p.$4),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () async {
                      await AppSettings.setCoachPersonality(p.$1);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (rootContext.mounted) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content: Text('Coach set to ${p.$3} ${p.$2}'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        );
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Notification sheet ───────────────────────────────────────────────
  void _showNotifSheet(BuildContext rootContext) {
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
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
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hydration reminders',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle:
                        const Text('Every 2 hours from 8 AM to 8 PM'),
                    value: AppSettings.getHydrationNotifs(),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      await AppSettings.setHydrationNotifs(v);
                      if (v) {
                        await NotificationService.scheduleHydrationReminders();
                      } else {
                        // cancelAll wipes every channel — reschedule the rest
                        await NotificationService.cancelAll();
                        await NotificationService.scheduleDailyQuestReminder();
                        if (AppSettings.getBriefingEnabled()) {
                          await NotificationService.scheduleBriefingReminder();
                        }
                      }
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Streak at-risk alerts',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle:
                        const Text('Get warned before midnight if streak is at risk'),
                    value: AppSettings.getStreakNotifs(),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      await AppSettings.setStreakNotifs(v);
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Morning briefing (7 AM)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle:
                        const Text('Daily AI plan written from your real data'),
                    value: AppSettings.getBriefingEnabled(),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      await AppSettings.setBriefingEnabled(v);
                      if (v) {
                        await NotificationService.scheduleBriefingReminder();
                      } else {
                        await NotificationService.cancelBriefingReminder();
                      }
                      setSheetState(() {});
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Voice input for Coach',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Enable microphone in AI Coach'),
                    value: AppSettings.getVoiceEnabled(),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      await AppSettings.setVoiceEnabled(v);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Gemini API settings sheet ────────────────────────────────
  void _showGeminiSheet(BuildContext rootContext) {
    final controller = TextEditingController(text: AppSettings.getGeminiApiKey());
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: Theme.of(rootContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Cloud AI (Gemini)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Get powerful AI responses from Google Gemini (free tier).\n'
                    'Your data stays private — only the chat message is sent.',
                    style: TextStyle(fontSize: 13, color: Theme.of(ctx).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Cloud AI',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      AppSettings.getGeminiEnabled() ? 'Gemini is active' : 'Uses Colibri (local)',
                      style: TextStyle(fontSize: 12, color: Theme.of(ctx).textTheme.bodySmall?.color),
                    ),
                    value: AppSettings.getGeminiEnabled(),
                    activeColor: AppColors.primary,
                    onChanged: (v) async {
                      await AppSettings.setGeminiEnabled(v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      hintText: 'AIza...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                    onChanged: (v) => AppSettings.setGeminiApiKey(v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get your free key at ai.google.dev',
                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:  TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:  TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
             Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── Metric Pill ─────────────────────────────────────────────────────────────

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style:  TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style:  TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Weekly Chart ────────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final int currentWeekSteps;
  final int todaySteps;

  const _WeeklyChart({
    required this.currentWeekSteps,
    required this.todaySteps,
  });

  @override
  Widget build(BuildContext context) {
    // Mock 7-day distribution based on current week
    final avgDaily = currentWeekSteps / 7;
    final values = List.generate(7, (i) {
      if (i < 6) return (avgDaily * (0.6 + (i % 3) * 0.2)).clamp(0, double.infinity).toDouble();
      return todaySteps.toDouble();
    });
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIndex = DateTime.now().weekday - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final ratio = maxVal > 0 ? values[i] / maxVal : 0.0;
        final isToday = i == todayIndex;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Container(
                          width: double.infinity,
                          height: value * 80,
                          decoration: BoxDecoration(
                            gradient: isToday
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [AppColors.secondary, AppColors.primary],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primary.withOpacity(0.3),
                                      AppColors.primary.withOpacity(0.15),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  days[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final _syncPageKey = GlobalKey<SyncPageState>();
  final _characterKey = GlobalKey<CharacterScreenState>();
  final _modelManager = ModelManager();
  final _coachService = AiCoachService();

  // Periodic hydration archiver — saves daily data every 30 minutes
  Timer? _hydrationTimer;

  @override
  void initState() {
    super.initState();
    // Archive hydration data every 30 minutes so day-change is captured
    _hydrationTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      HydrationService.archiveToday();
    });
  }

  @override
  void dispose() {
    _hydrationTimer?.cancel();
    super.dispose();
  }

  Map<String, double> _getHealthData() {
    final syncState = _syncPageKey.currentState;
    if (syncState == null) return {};
    return {
      'steps': syncState.todaySteps.toDouble(),
      'distance': syncState.todayDistance,
      'activeEnergy': syncState.todayEnergy,
    };
  }

  List<Widget> get _tabs => [
    SyncPage(
      key: _syncPageKey,
      onSyncComplete: () => _characterKey.currentState?.reloadState(),
      coachService: _coachService,
    ),
    CharacterScreen(key: _characterKey, coachService: _coachService),
  ];

  void _showQuickLogFromNav() {
    _syncPageKey.currentState?.showQuickLogDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient extends behind the nav
        Container(
          decoration:  BoxDecoration(gradient: AppColors.bgGradient),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: _selectedIndex,
            children: _tabs,
          ),
        ),
        // Floating bottom nav
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: SafeArea(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _navItem(0, Icons.home_rounded, 'Home'),
                  _navItem(1, Icons.bolt_rounded, 'Hunter'),
                  _navItem(2, Icons.psychology_rounded, 'Coach'),
                  _navItem(3, Icons.settings_rounded, 'Settings'),
                ],
              ),
            ),
          ),
        ),
        // FAB
        if (_selectedIndex == 0)
          Positioned(
            right: 24,
            bottom: 130,
            child: GestureDetector(
              onTap: _showQuickLogFromNav,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 2) {
            // Coach — push full-screen chat
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiCoachScreen(
                  coachService: _coachService,
                  modelManager: _modelManager,
                  getHealthData: _getHealthData,
                ),
              ),
            );
          } else if (index == 3) {
            // Settings — open modal
            _syncPageKey.currentState?.showSettingsSheet();
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: isActive
              ? BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Step Chip ─────────────────────────────────────────────────────────

class _QuickStepChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _QuickStepChip({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [chipColor, chipColor.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: chipColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ─── Morning briefing card ───────────────────────────────────────────────────

class _BriefingCard extends StatelessWidget {
  final String? text;
  final String engine;
  final bool generating;
  final bool enabled;
  final VoidCallback onGenerate;

  const _BriefingCard({
    required this.text,
    required this.engine,
    required this.generating,
    required this.enabled,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final body = !enabled
        ? 'Morning briefing is off. Enable it in Settings → Notifications.'
        : generating
            ? null
            : text;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('📡', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Today's Briefing",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (enabled && !generating)
                GestureDetector(
                  onTap: onGenerate,
                  child: Icon(Icons.refresh_rounded,
                      size: 20, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!enabled)
            Text(
              body!,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else if (generating)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text('The System is writing your briefing…',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            )
          else if (body != null && body.isNotEmpty)
            Text(
              body,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            )
          else
            Text(
              'Sync in progress — your briefing will appear when data lands.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          if (enabled && text != null && text!.isNotEmpty && !generating) ...[
            const SizedBox(height: 10),
            Text(
              engine,
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
