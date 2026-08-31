import 'package:flutter/material.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:health_ok/src/services/model_manager.dart';

class ModelPickerScreen extends StatefulWidget {
  final ModelManager modelManager;
  final AiCoachService coachService;

  const ModelPickerScreen({
    super.key,
    required this.modelManager,
    required this.coachService,
  });

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen> {
  @override
  void initState() {
    super.initState();
    widget.modelManager.addListener(_onModelUpdate);
  }

  void _onModelUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.modelManager.removeListener(_onModelUpdate);
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
            'AI Coach Models',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('🧠', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'On-Device AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Runs 100% on your phone.\nNo data leaves your device.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                Text(
                  'Choose a Model',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick based on your phone\'s RAM',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),

                const SizedBox(height: 20),

                // Model cards
                ...AiModel.all.map((model) => _ModelCard(
                  model: model,
                  manager: widget.modelManager,
                  coachService: widget.coachService,
                )),

                const SizedBox(height: 20),

                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Models run locally using llama.cpp. '
                          'Your health data never leaves your phone.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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

class _ModelCard extends StatelessWidget {
  final AiModel model;
  final ModelManager manager;
  final AiCoachService coachService;

  const _ModelCard({
    required this.model,
    required this.manager,
    required this.coachService,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = manager.downloaded[model.id] ?? false;
    final progress = manager.downloadProgress[model.id];
    final isActive = manager.activeModelId == model.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? AppColors.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (model.tier == ModelTier.advanced
                      ? AppColors.primary
                      : AppColors.success)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    model.tier == ModelTier.advanced ? '⚡' : '📱',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.displayName,
                      style:  TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${model.estimatedSizeMb} MB • ${model.minRamMb ~/ 1000} GB+ RAM',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            model.description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(
                  model.tier == ModelTier.advanced ? AppColors.primary : AppColors.success,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloading... ${(progress * 100).toInt()}%',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ] else if (isDownloaded) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isActive ? null : () async {
                      manager.setActiveModel(model.id);
                      // Show loading state
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Loading ${model.displayName} into RAM...'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                      // Actually load the model into memory
                      try {
                        await coachService.loadModel(model);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${model.displayName} loaded ✓'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to load: $e'),
                            backgroundColor: AppColors.energyColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isActive ? Icons.check_circle : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(isActive ? 'Selected' : 'Use This Model'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Model?'),
                        content: Text('Remove ${model.displayName} from your device?'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await manager.deleteModel(model);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.energyColor, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.energyColor.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await manager.downloadModel(model);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${model.displayName} downloaded!'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Download failed: $e'),
                          backgroundColor: AppColors.energyColor,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text('Download ${model.estimatedSizeMb} MB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: model.tier == ModelTier.advanced
                      ? AppColors.primary
                      : AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
