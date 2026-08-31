import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health_ok/src/services/food_log_service.dart';
import 'package:health_ok/src/theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';

/// Food logging screen with photo capture and calorie tracking.
class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key});

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  List<FoodEntry> _todayEntries = [];
  int _todayCalories = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await FoodLogService.getToday();
    final cal = await FoodLogService.todayCalories();
    if (!mounted) return;
    setState(() {
      _todayEntries = entries;
      _todayCalories = cal;
      _loading = false;
    });
  }

  Future<void> _addFromPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    final result = await showModalBottomSheet<_FoodResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodSheet(photoPath: photo.path),
    );
    if (result != null) {
      await FoodLogService.add(FoodEntry(
        id: 'food_${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: result.name,
        estimatedCalories: result.calories,
        photoPath: photo.path,
        mealType: result.mealType,
      ));
      _load();
    }
  }

  Future<void> _addQuick() async {
    final result = await showModalBottomSheet<_FoodResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFoodSheet(),
    );
    if (result != null) {
      await FoodLogService.add(FoodEntry(
        id: 'food_${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: result.name,
        estimatedCalories: result.calories,
        mealType: result.mealType,
      ));
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
            'Food Log',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'photo',
              onPressed: _addFromPhoto,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: 'quick',
              onPressed: _addQuick,
              backgroundColor: AppColors.success,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Quick Add',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  children: [
                    // Calorie summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$_todayCalories',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800),
                              ),
                              const Text(
                                'kcal today',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                          Column(
                            children: [
                              Text(
                                '${_todayEntries.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800),
                              ),
                              const Text(
                                'items logged',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_todayEntries.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child:  Column(
                          children: [
                            Text('🍽️', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text(
                              'No food logged today',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Use the camera or quick add button',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._todayEntries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FoodCard(entry: e),
                          )),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final FoodEntry entry;
  const _FoodCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          if (entry.photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(entry.photoPath!),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.surfaceMuted,
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.stepsColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(entry.mealEmoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${entry.mealType} • ${_formatTime(entry.time)}',
                  style:  TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.stepsColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${entry.estimatedCalories} kcal',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.stepsColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _FoodResult {
  final String name;
  final int calories;
  final String mealType;
  const _FoodResult(this.name, this.calories, this.mealType);
}

class _AddFoodSheet extends StatefulWidget {
  final String? photoPath;
  const _AddFoodSheet({this.photoPath});

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  String _selectedMealType = 'snack';
  String? _selectedPreset;
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration:  BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.lightBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Log Food',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            // Meal type chips
            Row(
              children: [
                _MealChip('🌅', 'Breakfast', _selectedMealType == 'breakfast', () => setState(() => _selectedMealType = 'breakfast')),
                const SizedBox(width: 6),
                _MealChip('☀️', 'Lunch', _selectedMealType == 'lunch', () => setState(() => _selectedMealType = 'lunch')),
                const SizedBox(width: 6),
                _MealChip('🌙', 'Dinner', _selectedMealType == 'dinner', () => setState(() => _selectedMealType = 'dinner')),
                const SizedBox(width: 6),
                _MealChip('🍪', 'Snack', _selectedMealType == 'snack', () => setState(() => _selectedMealType = 'snack')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Quick pick',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.65,
                ),
                itemCount: FoodLogService.commonFoods.length,
                itemBuilder: (_, i) {
                  final f = FoodLogService.commonFoods[i];
                  final selected = _selectedPreset == f.$1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPreset = f.$1;
                        _nameCtrl.text = f.$1;
                        _calCtrl.text = '${f.$2}';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected ? AppColors.primary : Colors.transparent),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f.$3, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                            f.$1,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Food name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated calories',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const Spacer(),
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
                      final name = _nameCtrl.text.trim();
                      final cal = int.tryParse(_calCtrl.text.trim()) ?? 0;
                      if (name.isEmpty) return;
                      Navigator.pop(context, _FoodResult(name, cal, _selectedMealType));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
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

class _MealChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MealChip(this.emoji, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}