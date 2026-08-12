import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/waveform_bars.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

typedef AgentChatMessageAttachmentBuilder =
    Widget? Function(BuildContext context, AgentChatMessage message);

/// Reusable durable-agent conversation surface. Consumers own sending and
/// draft state; this component owns only projection, bubbles and composition.
class AgentChatView extends ConsumerStatefulWidget {
  const AgentChatView({
    required this.agentId,
    required this.agentName,
    required this.draft,
    required this.isSending,
    required this.onDraftChanged,
    required this.onSend,
    required this.onRetry,
    this.hasFailedTurn = false,
    this.attachmentBuilder,
    super.key,
  });

  final String agentId;
  final String agentName;
  final String draft;
  final bool isSending;
  final bool hasFailedTurn;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final VoidCallback onRetry;
  final AgentChatMessageAttachmentBuilder? attachmentBuilder;

  @override
  ConsumerState<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  late final TextEditingController _controller;
  final _scrollController = ScrollController();
  late final ProviderSubscription<ChatRecorderState> _recorderSubscription;
  String? _lastMessageId;
  bool _wasSending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft);
    _wasSending = widget.isSending;
    _recorderSubscription = ref.listenManual<ChatRecorderState>(
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
            widget.onDraftChanged(transcript);
          }
          ref.read(chatRecorderControllerProvider.notifier).clearResult();
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant AgentChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId) {
      _lastMessageId = null;
      _wasSending = widget.isSending;
    }
    if (_controller.text != widget.draft) {
      _controller
        ..text = widget.draft
        ..selection = TextSelection.collapsed(offset: widget.draft.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recorderSubscription.close();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final historyAsync = ref.watch(
      agentChatProjectionProvider(widget.agentId),
    );
    final messages = historyAsync.value;
    final latestMessageId = messages?.lastOrNull?.id;
    final shouldScroll =
        messages != null &&
        (_lastMessageId != latestMessageId ||
            (!_wasSending && widget.isSending));
    _lastMessageId = latestMessageId;
    _wasSending = widget.isSending;
    if (shouldScroll) _scrollToLatest();

    return Column(
      children: [
        Expanded(
          child: switch (messages) {
            null when historyAsync.hasError => Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step5),
                child: Text(
                  context.messages.goalChatHistoryError,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
              ),
            ),
            null => const Center(child: CircularProgressIndicator()),
            final history =>
              history.isEmpty && !widget.isSending
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(tokens.spacing.step5),
                        child: Text(
                          context.messages.goalChatEmpty(widget.agentName),
                          textAlign: TextAlign.center,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(tokens.spacing.step5),
                      itemCount: history.length + (widget.isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == history.length) {
                          return _ThinkingBubble(agentName: widget.agentName);
                        }
                        final message = history[index];
                        final attachment = widget.attachmentBuilder?.call(
                          context,
                          message,
                        );
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: tokens.spacing.cardItemSpacing,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MessageBubble(
                                key: ValueKey(
                                  'goal-chat-message-${message.id}',
                                ),
                                message: message,
                                agentName: widget.agentName,
                              ),
                              if (attachment != null) ...[
                                SizedBox(height: tokens.spacing.step2),
                                attachment,
                              ],
                            ],
                          ),
                        );
                      },
                    ),
          },
        ),
        if (widget.hasFailedTurn)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step5,
              vertical: tokens.spacing.step2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.messages.goalChatFailed,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.alert.error.ink,
                  ),
                ),
                SizedBox(width: tokens.spacing.step2),
                DesignSystemButton(
                  label: context.messages.aiInferenceErrorRetryButton,
                  onPressed: widget.onRetry,
                  variant: DesignSystemButtonVariant.dangerTertiary,
                  size: DesignSystemButtonSize.dense,
                ),
              ],
            ),
          ),
        _ChatComposer(
          controller: _controller,
          agentName: widget.agentName,
          isSending: widget.isSending,
          draft: widget.draft,
          onDraftChanged: widget.onDraftChanged,
          onSend: widget.onSend,
          recorderState: ref.watch(chatRecorderControllerProvider),
          onStartRecording: () =>
              ref.read(chatRecorderControllerProvider.notifier).start(),
          onCancelRecording: () =>
              ref.read(chatRecorderControllerProvider.notifier).cancel(),
          onStopRecording: () => ref
              .read(chatRecorderControllerProvider.notifier)
              .stopAndTranscribe(),
          normalizedAmplitudes: ref
              .read(chatRecorderControllerProvider.notifier)
              .getNormalizedAmplitudeHistory(),
        ),
      ],
    );
  }
}

/// Voice-enabled composer for the agent chat. Reuses the shared
/// [chatRecorderControllerProvider] — the same recorder the evolution chat
/// uses — so transcription, error toasts, and the waveform are shared
/// infrastructure. Idle shows a text field with a mic/send trailing icon;
/// recording shows the waveform with cancel/stop; processing shows the
/// streaming partial transcript.
class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.agentName,
    required this.isSending,
    required this.draft,
    required this.onDraftChanged,
    required this.onSend,
    required this.recorderState,
    required this.onStartRecording,
    required this.onCancelRecording,
    required this.onStopRecording,
    required this.normalizedAmplitudes,
  });

  final TextEditingController controller;
  final String agentName;
  final bool isSending;
  final String draft;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final ChatRecorderState recorderState;
  final VoidCallback onStartRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onStopRecording;
  final List<double> normalizedAmplitudes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final status = recorderState.status;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: switch (status) {
          ChatRecorderStatus.recording => _RecordingControls(
            amplitudes: normalizedAmplitudes,
            onCancel: onCancelRecording,
            onStop: onStopRecording,
          ),
          ChatRecorderStatus.processing => _TranscriptionProgress(
            partialTranscript: recorderState.partialTranscript ?? '',
          ),
          _ => _IdleComposer(
            controller: controller,
            agentName: agentName,
            isSending: isSending,
            draft: draft,
            onDraftChanged: onDraftChanged,
            onSend: onSend,
            onStartRecording: onStartRecording,
          ),
        },
      ),
    );
  }
}

class _IdleComposer extends StatelessWidget {
  const _IdleComposer({
    required this.controller,
    required this.agentName,
    required this.isSending,
    required this.draft,
    required this.onDraftChanged,
    required this.onSend,
    required this.onStartRecording,
  });

  final TextEditingController controller;
  final String agentName;
  final bool isSending;
  final String draft;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;

  @override
  Widget build(BuildContext context) {
    final hasText = draft.trim().isNotEmpty;
    final canSend = hasText && !isSending;
    final canRecord = !isSending && !hasText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DesignSystemTextInput(
            controller: controller,
            hintText: context.messages.goalChatPlaceholder(agentName),
            helperText: isSending
                ? context.messages.goalChatResponding(agentName)
                : null,
            enabled: !isSending,
            textCapitalization: TextCapitalization.sentences,
            trailingIcon: hasText
                ? Icons.send_rounded
                : (canRecord ? Icons.mic_rounded : null),
            onTrailingIconTap: hasText
                ? (canSend ? onSend : null)
                : (canRecord ? onStartRecording : null),
            trailingIconTooltip: hasText
                ? context.messages.chatInputSendTooltip
                : (canRecord ? context.messages.chatInputRecordVoice : null),
            onChanged: onDraftChanged,
            onSubmitted: (_) {
              if (draft.trim().isNotEmpty) onSend();
            },
          ),
        ),
      ],
    );
  }
}

class _RecordingControls extends StatelessWidget {
  const _RecordingControls({
    required this.amplitudes,
    required this.onCancel,
    required this.onStop,
  });

  final List<double> amplitudes;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Expanded(
          child: WaveformBars(amplitudesNormalized: amplitudes),
        ),
        SizedBox(width: tokens.spacing.step3),
        _CircleIconButton(
          icon: Icons.close_rounded,
          onPressed: onCancel,
          tooltip: context.messages.chatInputCancelRecording,
        ),
        SizedBox(width: tokens.spacing.step2),
        _CircleIconButton(
          icon: Icons.stop_rounded,
          onPressed: onStop,
          tooltip: context.messages.chatInputStopTranscribe,
        ),
      ],
    );
  }
}

class _TranscriptionProgress extends StatelessWidget {
  const _TranscriptionProgress({required this.partialTranscript});

  final String partialTranscript;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            decoration: BoxDecoration(
              color: tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            constraints: BoxConstraints(maxHeight: tokens.spacing.step9),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                partialTranscript,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        SizedBox.square(
          dimension: tokens.spacing.step8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: tokens.spacing.step6,
                height: tokens.spacing.step6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.colors.interactive.enabled,
                ),
              ),
              Icon(
                Icons.mic_rounded,
                size: IconSizes.s,
                color: tokens.colors.interactive.enabled,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Container(
            width: tokens.spacing.step8,
            height: tokens.spacing.step8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.colors.interactive.enabled,
            ),
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(
                icon,
                size: IconSizes.s,
                color: tokens.colors.text.onInteractiveAlert,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.agentName,
    super.key,
  });

  final AgentChatMessage message;
  final String agentName;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const _collapsedMaxLines = 8;
  static const _longReplyCharacterThreshold = 360;
  static const _longReplyLineThreshold = 8;

  bool _expanded = false;

  bool get _canCollapse {
    final message = widget.message;
    if (message.role != AgentChatRole.agent) return false;
    final lineBreaks = '\n'.allMatches(message.text).length;
    return message.text.length > _longReplyCharacterThreshold ||
        lineBreaks >= _longReplyLineThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final message = widget.message;
    final isUser = message.role == AgentChatRole.user;
    final author = isUser ? context.messages.goalChatYou : widget.agentName;
    final time = DateFormat.jm(
      Localizations.localeOf(context).toString(),
    ).format(message.createdAt);
    final canCollapse = _canCollapse;
    return Semantics(
      container: true,
      explicitChildNodes: canCollapse,
      label: context.messages.goalChatMessageSemantics(
        author,
        time,
        message.text,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: kActionListContentMaxWidth,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser
                  ? tokens.colors.surface.selected
                  : tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    ExcludeSemantics(
                      child: Text(
                        message.text,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    )
                  else
                    ExcludeSemantics(
                      child: AgentMarkdownView(
                        message.text,
                        maxLines: canCollapse && !_expanded
                            ? _collapsedMaxLines
                            : null,
                        overflow: canCollapse && !_expanded
                            ? TextOverflow.ellipsis
                            : null,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    ),
                  if (canCollapse) ...[
                    SizedBox(height: tokens.spacing.step1),
                    DesignSystemButton(
                      label: _expanded
                          ? context.messages.aiResponseShowLess
                          : context.messages.aiResponseShowMore,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      variant: DesignSystemButtonVariant.tertiary,
                      size: DesignSystemButtonSize.dense,
                      trailingIcon: _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      alignsLabelToLeadingEdge: true,
                    ),
                  ],
                  SizedBox(height: tokens.spacing.step1),
                  ExcludeSemantics(
                    child: Text(
                      context.messages.goalChatMessageFooter(author, time),
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.agentName});

  final String agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: context.messages.goalChatResponding(agentName),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.l),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: Text(
              '•••',
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
