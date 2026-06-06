import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

part 'chat_voice_controls.dart';

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
  final ValueChanged<String> onSendMessage;
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
        if (next.transcript != null &&
            next.transcript != previous?.transcript) {
          if (!mounted) return;
          final transcript = next.transcript!.trim();
          if (transcript.isNotEmpty) {
            if (widget.canSend) {
              _sendMessage(transcript);
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

  void _sendMessage([String? text]) {
    final message = text ?? widget.controller.text.trim();
    if (message.isEmpty || !widget.canSend) return;

    widget.onSendMessage(message);
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
                        onSubmitted: widget.canSend ? _sendMessage : null,
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
        onPressed: widget.canSend ? _sendMessage : null,
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
