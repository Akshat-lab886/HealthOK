import 'package:flutter/material.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:health_ok/src/services/quest_service.dart';
import 'package:health_ok/src/services/workout_service.dart';
import 'package:quest_engine/quest_engine.dart';

/// A bottom-sheet style card that uses the AI to suggest 3 new quest objectives.
class AiQuestSuggestionSheet extends StatefulWidget {
  final AiCoachService coachService;
  final Player player;
  final void Function(List<String> suggestions) onApply;

  const AiQuestSuggestionSheet({
    super.key,
    required this.coachService,
    required this.player,
    required this.onApply,
  });

  @override
  State<AiQuestSuggestionSheet> createState() => _AiQuestSuggestionSheetState();
}

class _AiQuestSuggestionSheetState extends State<AiQuestSuggestionSheet> {
  List<String> _suggestions = [];
  bool _generating = false;
  String? _error;
  final List<String> _selected = [];

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
      _suggestions = [];
      _selected.clear();
    });
    try {
      final state = await QuestService.loadAll();
      final week = await WorkoutService.getLast7Days();
      final recentData = {
        'streak': state.player.streakDays,
        'level': state.player.level,
        'workoutsThisWeek': week.length,
      };
      // NOTE: no clearHistory() — this sheet must not wipe the user's chat
      final suggestions = await widget.coachService.suggestDailyQuests(recentData);
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
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
    final suggestions = _suggestions;

    return Container(
      decoration:  BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('✨', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
               Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Quest Suggestions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Personalized for you',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_generating) _buildLoading()
          else if (_error != null) _buildError()
          else
            ...suggestions.map((s) => _buildSuggestion(s)),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
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
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            widget.onApply(_selected);
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Add ${_selected.length} Quest${_selected.length == 1 ? "" : "s"}'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          widget.coachService.currentResponse.isEmpty
              ? 'AI is crafting your quests...'
              : widget.coachService.currentResponse,
          style:  TextStyle(color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.energyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.energyColor, size: 20),
              SizedBox(width: 8),
              Text('Could not generate suggestions',
                  style: TextStyle(
                    color: AppColors.energyColor,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _error!,
            style:  TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestion(String text) {
    final isSelected = _selected.contains(text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selected.remove(text);
            } else if (_selected.length < 6) {
              _selected.add(text);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.08)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).dividerColor.withOpacity(0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
