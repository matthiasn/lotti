import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/assistant_settings_sheet.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';

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

    Future.delayed(const Duration(milliseconds: 100), () {
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
                              ? 'Select a model to start chatting'
                              : 'Ask about your tasks and productivity...',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHigh
                              .withValues(alpha: 0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.10)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.10)),
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
                    IconButton.filled(
                      icon: _buildTrailingIcon(
                        isProcessing:
                            recState.status == ChatRecorderStatus.processing,
                      ),
                      onPressed: _buildTrailingOnPressed(
                        recState: recState,
                      ),
                      tooltip: _buildTrailingTooltip(recState: recState),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildTrailingIcon({required bool isProcessing}) {
    if (isProcessing || widget.isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final hasText = _hasText;
    final recState = ref.read(chatRecorderControllerProvider);
    if (recState.status == ChatRecorderStatus.recording) {
      return const Icon(Icons.stop);
    }
    if (hasText) return const Icon(Icons.send);
    if (widget.requiresModelSelection) return const Icon(Icons.tune);
    return const Icon(Icons.mic);
  }

  VoidCallback? _buildTrailingOnPressed({required ChatRecorderState recState}) {
    if (recState.status == ChatRecorderStatus.processing || widget.isLoading) {
      return null;
    }
    final hasText = _hasText;
    if (recState.status == ChatRecorderStatus.recording) {
      return () =>
          ref.read(chatRecorderControllerProvider.notifier).stopAndTranscribe();
    }
    if (hasText) {
      return widget.canSend ? _sendMessage : null;
    }
    if (widget.requiresModelSelection) {
      return () {
        showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: AssistantSettingsSheet(categoryId: widget.categoryId),
          ),
        );
      };
    }
    return () => ref.read(chatRecorderControllerProvider.notifier).start();
  }

  String _buildTrailingTooltip({required ChatRecorderState recState}) {
    if (recState.status == ChatRecorderStatus.processing || widget.isLoading) {
      return 'Processing...';
    }
    final hasText = _hasText;
    if (recState.status == ChatRecorderStatus.recording) {
      return 'Stop and transcribe';
    }
    if (hasText) return widget.canSend ? 'Send message' : 'Please wait...';
    return 'Record voice message';
  }
}

class ChatVoiceControls extends ConsumerWidget {
  const ChatVoiceControls({
    required this.onCancel,
    required this.onStop,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: WaveformBars(
                  key: const ValueKey('waveform_bars'),
                  amplitudesNormalized: ref
                      .watch(chatRecorderControllerProvider.notifier)
                      .getNormalizedAmplitudeHistory(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel recording (Esc)',
              onPressed: onCancel,
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.stop),
              tooltip: 'Stop and transcribe',
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}
