import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/chat_voice_controls.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/ai_chat/ui/widgets/chat_interface/chat_voice_controls.dart';

/// Chat composer: text field plus voice controls.
///
/// Swaps its body based on `ChatRecorderState.status` — text field when idle,
/// waveform + stop/cancel while recording, live-transcript view in realtime
/// mode, and a progress view during batch transcription. Listens to the
/// recorder via `listenManual`: a finished transcript is auto-sent when the
/// session can send, otherwise dropped into the text field for editing, then
/// cleared so it is not re-consumed. Recorder errors are shown with their
/// diagnostic detail in an error toast and consumed through the same clear
/// path. The trailing button cycles through send / settings / mic (with a
/// batch-vs-realtime toggle when realtime is available).
class InputArea extends ConsumerStatefulWidget {
  const InputArea({
    required this.controller,
    required this.scrollController,
    required this.isLoading,
    required this.canSend,
    required this.onSendMessage,
    required this.requiresModelSelection,
    required this.categoryId,
    super.key,
  });

  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isLoading;
  final bool canSend;
  final Future<bool> Function(String message) onSendMessage;
  final bool requiresModelSelection;
  final String categoryId;

  @override
  ConsumerState<InputArea> createState() => InputAreaState();
}

class InputAreaState extends ConsumerState<InputArea> {
  bool _hasText = false;
  late final ProviderSubscription<ChatRecorderState> _transcriptSubscription;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
    _transcriptSubscription = ref.listenManual<ChatRecorderState>(
      chatRecorderControllerProvider,
      (previous, next) {
        final error = _recorderErrorDescription(next);
        final previousError = previous == null
            ? null
            : _recorderErrorDescription(previous);
        if (error != null &&
            error.isNotEmpty &&
            error != previousError &&
            mounted) {
          final recordingSaved =
              next.errorType == ChatRecorderErrorType.recordingSavedForRecovery;
          context.showToast(
            tone: recordingSaved
                ? DesignSystemToastTone.warning
                : DesignSystemToastTone.error,
            title: recordingSaved ? error : context.messages.commonError,
            description: recordingSaved ? null : error,
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
            if (widget.canSend) {
              unawaited(_acceptVoiceTranscript(transcript));
            } else {
              widget.controller.text = transcript;
              widget.controller.selection = TextSelection.collapsed(
                offset: widget.controller.text.length,
              );
            }
          }
          ref.read(chatRecorderControllerProvider.notifier).clearResult();
        }
      },
    );
  }

  String? _recorderErrorDescription(ChatRecorderState recorderState) {
    return switch (recorderState.errorType) {
      ChatRecorderErrorType.recordingSavedForRecovery =>
        context.messages.chatInputRecordingSavedForRecovery,
      ChatRecorderErrorType.noAudioRecorded =>
        context.messages.chatInputNoAudioRecorded,
      _ => recorderState.error?.trim(),
    };
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _transcriptSubscription.close();
    super.dispose();
  }

  void _onTextChanged() {
    final v = widget.controller.text.trim().isNotEmpty;
    if (v != _hasText) {
      setState(() => _hasText = v);
    }
  }

  Future<void> _acceptVoiceTranscript(String transcript) async {
    final accepted = await _sendMessage(transcript);
    if (!mounted) return;
    if (accepted) {
      await ref
          .read(chatRecorderControllerProvider.notifier)
          .acknowledgeRealtimeTranscriptConsumed();
      return;
    }
    widget.controller.text = transcript;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
  }

  Future<bool> _sendMessage([String? text]) async {
    final message = text ?? widget.controller.text.trim();
    if (message.isEmpty || !widget.canSend) return false;

    final accepted = await widget.onSendMessage(message);
    if (!accepted || !mounted) return accepted;
    widget.controller.clear();

    // Scroll to the bottom once the frame containing the new message has
    // rendered. A post-frame callback is deterministic (clearing the
    // controller above already schedules a frame), unlike the arbitrary
    // delay this replaces.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          widget.scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(chatRecorderControllerProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: (recState.status == ChatRecorderStatus.recording)
            ? ChatVoiceControls(
                onCancel: () =>
                    ref.read(chatRecorderControllerProvider.notifier).cancel(),
                onStop: () => ref
                    .read(chatRecorderControllerProvider.notifier)
                    .stopAndTranscribe(),
              )
            : (recState.status == ChatRecorderStatus.realtimeRecording)
            ? _RealtimeRecordingView(
                partialTranscript: recState.partialTranscript,
                onCancel: () =>
                    ref.read(chatRecorderControllerProvider.notifier).cancel(),
                onStop: () => ref
                    .read(chatRecorderControllerProvider.notifier)
                    .stopRealtime(),
              )
            : (recState.status == ChatRecorderStatus.processing &&
                  recState.partialTranscript != null)
            ? _TranscriptionProgress(
                partialTranscript: recState.partialTranscript!,
              )
            : Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: TextField(
                        key: const ValueKey('chat_text_field'),
                        controller: widget.controller,
                        decoration: InputDecoration(
                          hintText: widget.requiresModelSelection
                              ? context.messages.chatInputHintSelectModel
                              : context.messages.chatInputHintDefault,
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.10,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: widget.canSend
                            ? (value) => unawaited(_sendMessage(value))
                            : null,
                        enabled:
                            recState.status != ChatRecorderStatus.processing &&
                            widget.canSend,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (recState.status != ChatRecorderStatus.recording)
                    _buildTrailingButtons(
                      recState: recState,
                      theme: theme,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTrailingButtons({
    required ChatRecorderState recState,
    required ThemeData theme,
  }) {
    final isProcessing = recState.status == ChatRecorderStatus.processing;

    // Processing or loading — show spinner
    if (isProcessing || widget.isLoading) {
      return IconButton.filled(
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        onPressed: null,
        tooltip: context.messages.chatInputProcessing,
      );
    }

    // Has text — show send button
    if (_hasText) {
      return IconButton.filled(
        icon: const Icon(Icons.send),
        onPressed: widget.canSend ? () => unawaited(_sendMessage()) : null,
        tooltip: widget.canSend
            ? context.messages.chatInputSendTooltip
            : context.messages.chatInputPleaseWait,
      );
    }

    // Requires model selection — show settings
    if (widget.requiresModelSelection) {
      return IconButton.filled(
        icon: const Icon(Icons.tune),
        onPressed: () {
          showDialog<void>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.7),
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: AssistantSettingsSheet(categoryId: widget.categoryId),
            ),
          );
        },
        tooltip: context.messages.chatInputConfigureModel,
      );
    }

    // Idle, no text — show mic button(s)
    final realtimeAsync = ref.watch(realtimeAvailableProvider);
    final realtimeAvailable = realtimeAsync.value ?? false;

    if (realtimeAvailable) {
      final useRealtime = recState.useRealtimeMode;
      // Both modes available — show mode toggle + mic button
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              useRealtime ? Icons.mic : Icons.graphic_eq,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => ref
                .read(chatRecorderControllerProvider.notifier)
                .toggleRealtimeMode(),
            tooltip: useRealtime
                ? context.messages.aiBatchToggleTooltip
                : context.messages.aiRealtimeToggleTooltip,
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
          ),
          IconButton.filled(
            icon: Icon(
              useRealtime ? Icons.graphic_eq : Icons.mic,
            ),
            onPressed: () {
              if (useRealtime) {
                ref
                    .read(chatRecorderControllerProvider.notifier)
                    .startRealtime();
              } else {
                ref.read(chatRecorderControllerProvider.notifier).start();
              }
            },
            tooltip: useRealtime
                ? context.messages.chatInputStartRealtime
                : context.messages.chatInputRecordVoice,
          ),
        ],
      );
    }

    // Only batch mode — show standard mic button
    return IconButton.filled(
      icon: const Icon(Icons.mic),
      onPressed: () =>
          ref.read(chatRecorderControllerProvider.notifier).start(),
      tooltip: context.messages.chatInputRecordVoice,
    );
  }
}

/// Shows live transcript text during real-time recording (no waveform).
class _RealtimeRecordingView extends StatelessWidget {
  const _RealtimeRecordingView({
    required this.partialTranscript,
    required this.onCancel,
    required this.onStop,
  });

  final String? partialTranscript;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = partialTranscript != null && partialTranscript!.isNotEmpty;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.85,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: hasText
                    ? SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          partialTranscript!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.messages.chatInputListening,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              icon: const Icon(Icons.close),
              tooltip: context.messages.chatInputCancelRealtime,
              onPressed: onCancel,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.stop),
              tooltip: context.messages.chatInputStopRealtime,
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows streaming transcription progress with the partial text
class _TranscriptionProgress extends StatelessWidget {
  const _TranscriptionProgress({
    required this.partialTranscript,
  });

  final String partialTranscript;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: 0.85,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: SingleChildScrollView(
              reverse: true, // Keep latest text visible
              child: Text(
                partialTranscript,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              Icon(
                Icons.transcribe,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
