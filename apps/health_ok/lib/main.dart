// HealthOK — M0 Sync Spike
// Proves the local data path end-to-end: Google Health Connect (this Galaxy
// Tab A9, Android 16) → `health` plugin → this app. No network. Ever.
// Architecture home: docs/02-architecture.md · platform rules: docs/06.

import 'package:flutter/material.dart';
import 'package:health/health.dart';

void main() => runApp(const HealthOKSpikeApp());

class HealthOKSpikeApp extends StatelessWidget {
  const HealthOKSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthOK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A33D), // System amber
          brightness: Brightness.dark,
        ),
      ),
      home: const SyncPage(),
    );
  }
}

enum SyncPhase { idle, requesting, syncing, done, error }

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final Health _health = Health();

  SyncPhase _phase = SyncPhase.idle;
  String _status = 'The System awaits your data.';
  int _todaySteps = 0;
  int _weekSteps = 0;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    // M0 spike: auto-sync on launch so the data path is provable headlessly.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => Future.delayed(const Duration(milliseconds: 1500), _syncNow),
    );
  }

  static final List<HealthDataType> _readTypes = [
    HealthDataType.STEPS, // narrow: see if the single type that matches the
    //   HC controller's literal "Steps" label also matches the SDK's enum.
    // HealthDataType.DISTANCE_WALKING_RUNNING,
    // HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<bool> _ensurePermissions() async {
    setState(() {
      _phase = SyncPhase.requesting;
      _status = 'Requesting Health Connect access…';
    });
    try {
      // Diagnostic: does the plugin think Health Connect is even available?
      final sdk = await _health.getHealthConnectSdkStatus();
      debugPrint('HOK_HC_SDK_STATUS=$sdk', wrapWidth: 400);
    } catch (e) {
      debugPrint('HOK_HC_SDK_STATUS_ERR=$e', wrapWidth: 400);
    }
    // Check existing grant first (recommended by the plugin docs).
    try {
      final have = await _health.hasPermissions(_readTypes);
      debugPrint('HOK_HAS_PERMS=$have types=$_readTypes', wrapWidth: 400);
    } catch (e) {
      debugPrint('HOK_HAS_PERMS_ERR=$e', wrapWidth: 400);
    }
    // health v13: authorization defaults to read access for the given types.
    final granted = await _health.requestAuthorization(_readTypes);
    debugPrint('HOK_SYNC_AUTH granted=$granted types=$_readTypes', wrapWidth: 400);
    return granted;
  }

  Future<void> _syncNow() async {
    debugPrint('HOK_SYNC_BEGIN', wrapWidth: 400);
    try {
      final granted = await _ensurePermissions();
      if (!mounted) return;
      if (!granted) {
        debugPrint('HOK_SYNC_DENIED', wrapWidth: 400);
        setState(() {
          _phase = SyncPhase.error;
          _errorDetail =
              'Authorization denied. Settings → Health Connect → App permissions.';
        });
        return;
      }

      setState(() {
        _phase = SyncPhase.syncing;
        _status = 'Pulling deltas from the local store…';
      });

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final weekAgo = now.subtract(const Duration(days: 7));

      final today = await _health.getTotalStepsInInterval(startOfToday, now);
      final week = await _health.getTotalStepsInInterval(weekAgo, now);

      // Headless-test evidence channel: adb logcat -s flutter
      debugPrint('HOK_SYNC_RESULT granted=true today=$today week=$week '
          'at=${now.toIso8601String()}', wrapWidth: 400);

      if (!mounted) return;
      setState(() {
        _todaySteps = today ?? 0;
        _weekSteps = week ?? 0;
        _phase = SyncPhase.done;
        _status = 'Data path verified. Zero bytes left this device.';
        _errorDetail = null;
      });
    } catch (e, st) {
      debugPrint('HOK_SYNC_ERROR $e', wrapWidth: 400);
      if (!mounted) return;
      setState(() {
        _phase = SyncPhase.error;
        _status = 'Sync failed.';
        _errorDetail = '$e\n\n$st';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('HEALTHOK',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: scheme.primary,
                      )),
              const SizedBox(height: 4),
              Text('M0 SYNC SPIKE · LOCAL-FIRST · OFFLINE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2,
                        color: scheme.outline,
                      )),
              const Spacer(),
              Center(
                child: Column(
                  children: [
                    Text('$_todaySteps',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    Text('steps today',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Text('$_weekSteps steps · trailing 7 days',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Spacer(),
              Card(
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorDetail != null
                        ? '$_status\n\n$_errorDetail'
                        : _status,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (_phase == SyncPhase.requesting ||
                        _phase == SyncPhase.syncing)
                    ? null
                    : _syncNow,
                icon: const Icon(Icons.sync),
                label: const Text('SYNC FROM HEALTH CONNECT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
