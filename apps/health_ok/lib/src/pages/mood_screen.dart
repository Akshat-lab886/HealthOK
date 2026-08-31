import 'package:flutter/material.dart';
import 'package:health_ok/src/services/mood_service.dart';
import 'package:health_ok/src/theme/app_colors.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  int _mood = 3;
  int _energy = 3;
  final _note = TextEditingController();
  MoodEntry? _today;
  List<MoodEntry> _last7 = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = await MoodService.getToday();
    final last7 = await MoodService.getLast7Days();
    if (!mounted) return;
    setState(() {
      _today = today;
      if (today != null) {
        _mood = today.mood;
        _energy = today.energy;
        _note.text = today.note ?? '';
      }
      _last7 = last7;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final entry = MoodEntry(
      date: DateTime.now(),
      mood: _mood,
      energy: _energy,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    await MoodService.add(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Check-in saved ✓'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
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
            'Mood Check-in',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How are you feeling?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _today != null
                                ? 'Updated today at ${_today!.date.hour.toString().padLeft(2, '0')}:${_today!.date.minute.toString().padLeft(2, '0')}'
                                : 'Daily check-in helps spot patterns',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          const Text('Mood',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(5, (i) {
                              final value = i + 1;
                              final selected = value == _mood;
                              return GestureDetector(
                                onTap: () => setState(() => _mood = value),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Center(
                                    child: Text(
                                      ['😣', '😕', '😐', '🙂', '😄'][i],
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),
                          const Text('Energy',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(5, (i) {
                              final value = i + 1;
                              final selected = value == _energy;
                              return GestureDetector(
                                onTap: () => setState(() => _energy = value),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Center(
                                    child: Text(
                                      ['🪫', '🔋', '⚡', '💪', '🚀'][i],
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _note,
                            maxLines: 2,
                            maxLength: 120,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Optional note...',
                              hintStyle: const TextStyle(color: Colors.white60),
                              counterStyle: const TextStyle(color: Colors.white60),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFEC4899),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Save Check-in',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                     Text(
                      'Last 7 days',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    if (_last7.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:  Text(
                          'No check-ins yet. Tap an emoji above to log your first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    else
                      Column(
                        children: [
                          _MoodTrendChart(entries: _last7),
                          const SizedBox(height: 12),
                          _MoodInsightsCard(entries: _last7),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MoodTrendChart extends StatelessWidget {
  final List<MoodEntry> entries;
  const _MoodTrendChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mood & Energy Trend',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final day = DateTime.now().subtract(Duration(days: 6 - i));
                MoodEntry? entry;
                for (final e in entries) {
                  if (e.date.day == day.day &&
                      e.date.month == day.month &&
                      e.date.year == day.year) {
                    entry = e;
                    break;
                  }
                }
                final mood = entry?.mood ?? 0;
                final energy = entry?.energy ?? 0;
                final moodH = (mood * 24).toDouble();
                final energyH = (energy * 24).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (mood > 0)
                          Container(
                            width: 10,
                            height: moodH,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        const SizedBox(height: 2),
                        if (energy > 0)
                          Container(
                            width: 10,
                            height: energyH,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        if (mood == 0 && energy == 0)
                          Container(
                            width: 10,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.lightBorder,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1],
                          style:  TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(const Color(0xFFEC4899), 'Mood'),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFFFBBF24), 'Energy'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style:  TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
// ─── Mood insights card ──────────────────────────────────────────────────────

class _MoodInsightsCard extends StatelessWidget {
  final List<MoodEntry> entries;
  const _MoodInsightsCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final avgMood = MoodService.avgMood(entries);
    final avgEnergy = MoodService.avgEnergy(entries);
    final bestDay = MoodService.bestDayOfWeek(entries);

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
          Text('Your week in numbers',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              _item('😊', avgMood.toStringAsFixed(1), 'avg mood'),
              _item('⚡', avgEnergy.toStringAsFixed(1), 'avg energy'),
              if (bestDay != null) _item('📅', bestDay, 'best day', small: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(String emoji, String value, String label, {bool small = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: small ? 16 : 18)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: small ? 12 : 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
