import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_circle_button.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_realtime_view.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcription_progress.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_voice_controls.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/animations.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Bottom-anchored text input bar for the evolution chat.
///
/// Features a rounded text field with an animated send button that pulses
/// while the assistant is processing a response. Supports voice transcription
/// via the shared [chatRecorderControllerProvider].
class EvolutionMessageInput extends ConsumerStatefulWidget {
  const EvolutionMessageInput({
    required this.onSend,
    this.isWaiting = false,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onSend;
  final bool isWaiting;
  final bool enabled;

  @override
  ConsumerState<EvolutionMessageInput> createState() =>
      _EvolutionMessageInputState();
}

class _EvolutionMessageInputState extends ConsumerState<EvolutionMessageInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final ProviderSubscription<ChatRecorderState> _transcriptSubscription;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: GameyAnimations.pulse,
    );
    _pulseAnimation = Tween<double>(
      begin: GameyAnimations.pulseScaleMin,
      end: GameyAnimations.pulseScaleMax,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: GameyAnimations.symmetrical,
      ),
    );
    if (widget.isWaiting) {
      _pulseController.repeat(reverse: true);
    }

    _transcriptSubscription = ref.listenManual<ChatRecorderState>(
      chatRecorderControllerProvider,
      (previous, next) {
        if (next.transcript != null &&
            next.transcript != previous?.transcript) {
          if (!mounted) return;
          final transcript = next.transcript!.trim();
          if (transcript.isNotEmpty) {
            _controller.text = transcript;
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
          }
          ref.read(chatRecorderControllerProvider.notifier).clearResult();
        }
      },
    );
  }

  @override
  void didUpdateWidget(EvolutionMessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWaiting && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isWaiting && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _pulseController.dispose();
    _transcriptSubscription.close();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _controller.text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() => _hasText = newHasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isWaiting || !widget.enabled) return;
    widget.onSend(text);
    if (!mounted) return;
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(chatRecorderControllerProvider);
    final isRecording = recState.status == ChatRecorderStatus.recording;
    final isRealtimeRecording =
        recState.status == ChatRecorderStatus.realtimeRecording;
    final isProcessing = recState.status == ChatRecorderStatus.processing;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: GameyColors.surfaceDarkElevated.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: GameyColors.aiCyan.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: isRecording
            ? EvolutionVoiceControls(
                onCancel: () =>
                    ref.read(chatRecorderControllerProvider.notifier).cancel(),
                onStop: () => ref
                    .read(chatRecorderControllerProvider.notifier)
                    .stopAndTranscribe(),
              )
            : isRealtimeRecording
                ? EvolutionRealtimeView(
                    partialTranscript: recState.partialTranscript,
                    onCancel: () => ref
                        .read(chatRecorderControllerProvider.notifier)
                        .cancel(),
                    onStop: () => ref
                        .read(chatRecorderControllerProvider.notifier)
                        .stopRealtime(),
                  )
                : isProcessing && recState.partialTranscript != null
                    ? EvolutionTranscriptionProgress(
                        partialTranscript: recState.partialTranscript!,
                      )
                    : _buildIdleRow(recState),
      ),
    );
  }

  Widget _buildIdleRow(ChatRecorderState recState) {
    final canSend = _hasText && !widget.isWaiting && widget.enabled;
    final isProcessing = recState.status == ChatRecorderStatus.processing;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled && !widget.isWaiting && !isProcessing,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSend(),
            maxLines: 4,
            minLines: 1,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.messages.agentEvolutionChatPlaceholder,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: GameyColors.surfaceDark,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: GameyColors.aiCyan,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isProcessing)
          const EvolutionCircleButton(
            icon: Icons.hourglass_top_rounded,
          )
        else if (_hasText || widget.isWaiting)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = widget.isWaiting ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: EvolutionCircleButton(
              icon: widget.isWaiting
                  ? Icons.hourglass_top_rounded
                  : Icons.send_rounded,
              onPressed: canSend ? _handleSend : null,
              forceActive: widget.isWaiting,
            ),
          )
        else
          _buildMicButtons(recState),
      ],
    );
  }

  Widget _buildMicButtons(ChatRecorderState recState) {
    final realtimeAsync = ref.watch(realtimeAvailableProvider);
    final realtimeAvailable = realtimeAsync.value ?? false;

    if (realtimeAvailable) {
      final useRealtime = recState.useRealtimeMode;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EvolutionCircleButton(
            icon: useRealtime ? Icons.mic : Icons.graphic_eq,
            size: 32,
            iconSize: 16,
            onPressed: () => ref
                .read(chatRecorderControllerProvider.notifier)
                .toggleRealtimeMode(),
            tooltip: useRealtime
                ? context.messages.aiBatchToggleTooltip
                : context.messages.aiRealtimeToggleTooltip,
          ),
          const SizedBox(width: 4),
          EvolutionCircleButton(
            icon: useRealtime ? Icons.graphic_eq : Icons.mic,
            onPressed: useRealtime
                ? ref
                    .read(chatRecorderControllerProvider.notifier)
                    .startRealtime
                : ref.read(chatRecorderControllerProvider.notifier).start,
            tooltip: useRealtime
                ? context.messages.chatInputStartRealtime
                : context.messages.chatInputRecordVoice,
          ),
        ],
      );
    }

    return EvolutionCircleButton(
      icon: Icons.mic,
      onPressed: () =>
          ref.read(chatRecorderControllerProvider.notifier).start(),
      tooltip: context.messages.chatInputRecordVoice,
    );
  }
}
