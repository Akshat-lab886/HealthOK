import 'package:flutter/material.dart';
import 'package:health_ok/src/services/body_service.dart';
import 'package:health_ok/src/theme/app_colors.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key});

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  List<BodyMeasurement> _entries = [];
  bool _loading = true;
  UserProfile _profile = const UserProfile();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await BodyService.getAll();
    final profile = await BodyService.getProfile();
    if (!mounted) return;
    setState(() {
      _entries = all..sort((a, b) => b.date.compareTo(a.date));
      _profile = profile;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(profile: _profile),
    );
    if (result != null) {
      await BodyService.saveProfile(result);
      _load();
    }
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet<BodyMeasurement>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMeasurementSheet(),
    );
    if (result != null) {
      await BodyService.add(result);
      _load();
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
            'Body Measurements',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          backgroundColor: const Color(0xFF14B8A6),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Log Today',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    _ProfileCard(profile: _profile, onEdit: _editProfile),
                    const SizedBox(height: 16),
                    if (_entries.length >= 2)
                      _TrendChart(
                        entries: _entries.reversed.toList(),
                      ),
                    if (_entries.length >= 2) const SizedBox(height: 16),
                    ..._entries.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MeasurementCard(m: m),
                        )),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<BodyMeasurement> entries;
  const _TrendChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final weights = entries.map((e) => e.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).abs();
    final latest = entries.last.weightKg;
    final oldest = entries.first.weightKg;
    final delta = latest - oldest;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weight Trend',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: delta < 0
                      ? AppColors.success.withOpacity(0.12)
                      : delta > 0
                          ? const Color(0xFFFBBF24).withOpacity(0.18)
                          : AppColors.textMuted.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: delta < 0
                        ? AppColors.success
                        : delta > 0
                            ? const Color(0xFFFCD34D)
                            : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final norm = range == 0 ? 0.5 : (e.weightKg - minW) / range;
                final h = (30 + norm * 60).toDouble();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          e.weightKg.toStringAsFixed(1),
                          style:  TextStyle(fontSize: 8, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 12,
                          height: h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final BodyMeasurement m;
  const _MeasurementCard({required this.m});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(m.date),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Text(
                '${m.weightKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF14B8A6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (m.bodyFatPct != null) _Stat('Body fat', '${m.bodyFatPct!.toStringAsFixed(1)}%'),
              if (m.muscleKg != null) _Stat('Muscle', '${m.muscleKg!.toStringAsFixed(1)} kg'),
              if (m.waistCm != null) _Stat('Waist', '${m.waistCm!.toStringAsFixed(1)} cm'),
              if (m.chestCm != null) _Stat('Chest', '${m.chestCm!.toStringAsFixed(1)} cm'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style:  TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AddMeasurementSheet extends StatefulWidget {
  const _AddMeasurementSheet();

  @override
  State<_AddMeasurementSheet> createState() => _AddMeasurementSheetState();
}

class _AddMeasurementSheetState extends State<_AddMeasurementSheet> {
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _muscle = TextEditingController();
  final _waist = TextEditingController();
  final _chest = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    _fat.dispose();
    _muscle.dispose();
    _waist.dispose();
    _chest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration:  BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log Measurements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            _Field(controller: _weight, label: 'Weight (kg) *', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _Field(controller: _fat, label: 'Body fat (%)', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _Field(controller: _muscle, label: 'Muscle (kg)', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _Field(controller: _waist, label: 'Waist (cm)', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _Field(controller: _chest, label: 'Chest (cm)', keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final w = double.tryParse(_weight.text.trim());
                      if (w == null) return;
                      final entry = BodyMeasurement(
                        date: DateTime.now(),
                        weightKg: w,
                        bodyFatPct: double.tryParse(_fat.text.trim()),
                        muscleKg: double.tryParse(_muscle.text.trim()),
                        waistCm: double.tryParse(_waist.text.trim()),
                        chestCm: double.tryParse(_chest.text.trim()),
                      );
                      Navigator.pop(context, entry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;

  const _Field({required this.controller, required this.label, required this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
/// Personal profile card — shows derived metrics and opens the editor.
/// Everything here feeds personalization: stride → distance estimates,
/// BMR/TDEE → calorie context, weight → hydration + workout calories.
class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;

  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final filled = profile.heightCm != null || profile.ageYears != null;
    final stride = profile.strideLengthM();
    final bmr = profile.bmrKcal();
    final tdee = profile.tdeeKcal();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Personal Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(
                  filled ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          if (!filled)
            Text(
              'Set your height, age & activity — powers stride-based distance, calorie accuracy and personalized goals.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            )
          else ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _profileStat('Height',
                    profile.heightCm == null ? '—' : '${profile.heightCm!.round()} cm'),
                _profileStat('Age',
                    profile.ageYears == null ? '—' : '${profile.ageYears} yr'),
                _profileStat('Stride', '${stride.toStringAsFixed(2)} m'),
                _profileStat('TDEE', '${tdee.round()} kcal'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'BMR ${bmr.round()} kcal/day • distance auto-estimated from your stride',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileStat(String label, String value) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ],
      );
}

/// Bottom sheet editor for the personal profile.
class _ProfileSheet extends StatefulWidget {
  final UserProfile profile;
  const _ProfileSheet({required this.profile});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final TextEditingController _height;
  late final TextEditingController _age;
  late String? _sex;
  late String? _activity;

  static const _activities = {
    'sedentary': 'Sedentary — desk, little walking',
    'light': 'Light — some walking daily',
    'moderate': 'Moderate — regular walks/exercise',
    'active': 'Active — frequent training',
    'athlete': 'Athlete — daily hard training',
  };

  @override
  void initState() {
    super.initState();
    _height = TextEditingController(
        text: widget.profile.heightCm?.round().toString() ?? '');
    _age =
        TextEditingController(text: widget.profile.ageYears?.toString() ?? '');
    _sex = widget.profile.sex;
    _activity = widget.profile.activityLevel;
  }

  @override
  void dispose() {
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Profile',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 18)),
            const SizedBox(height: 4),
            Text(
                'Used to personalize distance estimates, calories, hydration and quest difficulty.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (years)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final s in const ['male', 'female', 'other'])
                  ChoiceChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: _sex == s,
                    onSelected: (_) => setState(() => _sex = s),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _activity,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Activity level',
                border: OutlineInputBorder(),
              ),
              items: _activities.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _activity = v),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final h = double.tryParse(_height.text.trim());
                  final a = int.tryParse(_age.text.trim());
                  Navigator.pop(
                    context,
                    UserProfile(
                      heightCm: (h != null && h >= 100 && h <= 230) ? h : null,
                      ageYears: (a != null && a >= 10 && a <= 100) ? a : null,
                      sex: _sex,
                      activityLevel: _activity,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Profile',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
