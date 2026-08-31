import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_ok/main.dart' show AppColors;
import 'package:health_ok/src/services/ai_coach_service.dart';
import 'package:health_ok/src/services/model_manager.dart';
import 'package:health_ok/src/services/app_settings.dart';
import 'model_picker_screen.dart';

// Import speech_to_text only if available
// We'll use a simple try/catch approach
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiCoachScreen extends StatefulWidget {
  final AiCoachService coachService;
  final ModelManager modelManager;
  final Map<String, double> Function() getHealthData;

  const AiCoachScreen({
    super.key,
    required this.coachService,
    required this.modelManager,
    required this.getHealthData,
  });

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  stt.SpeechToText? _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    widget.coachService.addListener(_onUpdate);
    widget.modelManager.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
    // Auto-scroll to bottom on new content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    if (!AppSettings.getVoiceEnabled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enable voice in Settings → AI Coach Personality'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech?.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _speech ??= stt.SpeechToText();
    final available = await _speech!.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice error: ${e.errorMsg}')),
          );
        }
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available')),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await _speech!.listen(
      onResult: (result) {
        if (result.finalResult) {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
      },
      listenFor: const Duration(seconds: 30),
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    widget.coachService.removeListener(_onUpdate);
    widget.modelManager.removeListener(_onUpdate);
    // Unload model from RAM when leaving coach screen
    widget.coachService.unloadModel();
    _speech?.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final healthData = widget.getHealthData();
    widget.coachService.sendMessage(text, healthData: healthData);
  }

  @override
  Widget build(BuildContext context) {
    final coach = widget.coachService;
    final manager = widget.modelManager;
    final hasModel = manager.activeModelId != null;
    final isLoaded = coach.isLoaded;
    final isColibri = coach.usesColibri;

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
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: isColibri
                      ? null
                      : AppColors.primaryGradient,
                  color: isColibri ? const Color(0xFF10B981) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isColibri ? '🐦' : '🧠',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'AI Coach',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isLoaded
                        ? '● ${manager.activeModel?.displayName ?? "Ready"}'
                        : isColibri
                            ? '● Colibri — Instant mode'
                            : coach.engineMode == EngineMode.hybrid
                                ? '● Cloud AI (Gemini)'
                                : 'Loading model...',
                    style: TextStyle(
                      fontSize: 11,
                      color: (isLoaded || isColibri)
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (coach.history.isNotEmpty)
              IconButton(
                onPressed: () {
                  coach.clearHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Conversation cleared'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                },
                icon:  Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 22),
              ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ModelPickerScreen(modelManager: manager, coachService: widget.coachService),
                  ),
                );
              },
              icon:  Icon(Icons.settings_rounded, color: AppColors.textMuted, size: 22),
            ),
          ],
        ),
        body: Column(
          children: [
            // Chat area — always show chat (Colibri is always available)
            Expanded(
              child: !hasModel && !isColibri
                  ? _buildNoModelView()
                  : !isLoaded && coach.loadingModelId != null && !isColibri
                      ? _buildLoadingView()
                      : _buildChatView(coach),
            ),

            // Input area — always enabled since Colibri works instantly
            _buildInputBar(coach, true),
          ],
        ),
      ),
    );
  }

  Widget _buildNoModelView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🐦', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 24),
             Text(
              'Colibri Mode Active',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your instant health coach is ready.\n'
              'Ask about steps, workouts, sleep, nutrition, or your stats.\n\n'
              '💡 Want even smarter responses? Download a model below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ModelPickerScreen(modelManager: widget.modelManager, coachService: widget.coachService),
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Browse Models'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading AI model...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'First load takes a few seconds',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(AiCoachService coach) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: coach.history.length +
          (coach.isGenerating ? 1 : 0) +
          (coach.history.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // Welcome message
        if (coach.history.isEmpty && index == 0) {
          return _buildWelcomeMessage();
        }

        // Adjust index for welcome message
        final msgIndex = coach.history.isEmpty ? index - 1 : index;

        // Generating indicator
        if (coach.isGenerating && msgIndex == coach.history.length) {
          return _buildGeneratingBubble(coach.currentResponse);
        }

        final msg = coach.history[msgIndex];
        final isUser = msg['role'] == 'user';

        return _buildMessageBubble(
          text: msg['content']!,
          isUser: isUser,
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🧠', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 16),
           Text(
            'HealthOK AI Coach',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about health, fitness,\nnutrition, or recovery.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _QuickQuestion(
                text: 'How many steps should I walk?',
                onTap: (c) => _controller.text = 'How many steps should I walk daily?',
              ),
              _QuickQuestion(
                text: 'Tips for better sleep',
                onTap: (c) => _controller.text = 'Give me tips for better sleep.',
              ),
              _QuickQuestion(
                text: 'What should I eat post-workout?',
                onTap: (c) => _controller.text = 'What should I eat after a workout?',
              ),
              _QuickQuestion(
                text: 'How to stay hydrated?',
                onTap: (c) => _controller.text = 'How much water should I drink?',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('🧠', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.stepsColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratingBubble(String partialResponse) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('🧠', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: partialResponse.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Thinking...',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  : SelectableText(
                      partialResponse,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AiCoachService coach, bool enabled) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: enabled && !coach.isGenerating,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ask your AI coach...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Voice button
            GestureDetector(
              onTap: _toggleVoice,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isListening
                      ? const Color(0xFFEF4444)
                      : AppColors.textMuted.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 18,
                  color: _isListening ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: (enabled && !coach.isGenerating)
                    ? AppColors.primaryGradient
                    : null,
                color: (enabled && !coach.isGenerating)
                    ? null
                    : AppColors.textMuted.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: (enabled && !coach.isGenerating) ? _sendMessage : null,
                icon: coach.isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickQuestion extends StatelessWidget {
  final String text;
  final Function(BuildContext) onTap;

  const _QuickQuestion({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap(context);
        // Parent will handle sending
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
