import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_circle_button.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_transcription_progress.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_voice_controls.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Bottom-anchored text input bar for the evolution chat.
///
/// Features a rounded text field with an animated send button that pulses
/// while the assistant is processing a response. Supports voice transcription
/// via the shared [chatRecorderControllerProvider], including a detailed error
/// toast when transcription fails.
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
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation =
        Tween<double>(
          begin: 0.98,
          end: 1.08,
        ).animate(
          CurvedAnimation(
            parent: _pulseController,
            curve: Curves.easeInOut,
          ),
        );
    if (widget.isWaiting) {
      _pulseController.repeat(reverse: true);
    }

    _transcriptSubscription = ref.listenManual<ChatRecorderState>(
      chatRecorderControllerProvider,
      (previous, next) {
        final error = next.error?.trim();
        if (error != null &&
            error.isNotEmpty &&
            error != previous?.error &&
            mounted) {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.commonError,
            description: error,
            duration: const Duration(seconds: 8),
            replaceCurrent: true,
          );
          Future.microtask(() {
            if (mounted) {
              ref.read(chatRecorderControllerProvider.notifier).clearResult();
            }
          });
          return;
        }
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
    final isProcessing = recState.status == ChatRecorderStatus.processing;
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.designTokens;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: isRecording
            ? EvolutionVoiceControls(
                onCancel: () =>
                    ref.read(chatRecorderControllerProvider.notifier).cancel(),
                onStop: () => ref
                    .read(chatRecorderControllerProvider.notifier)
                    .stopAndTranscribe(),
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
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.designTokens;

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
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: context.messages.agentEvolutionChatPlaceholder,
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radii.xl),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radii.xl),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(tokens.radii.xl),
                borderSide: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.8),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
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
    return EvolutionCircleButton(
      icon: Icons.mic,
      onPressed: () =>
          ref.read(chatRecorderControllerProvider.notifier).start(),
      tooltip: context.messages.chatInputRecordVoice,
    );
  }
}
