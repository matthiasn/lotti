import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_controller.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_recorder_error_message.dart';
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

  /// Laid-out reply heights, keyed by message id, owned by the LIST rather
  /// than by the item.
  ///
  /// `ListView.builder` disposes an item's State once it scrolls past the
  /// cache extent. A collapsible reply that lost its measurement renders at
  /// FULL height for the frame before the measurement lands, so every
  /// re-entry of a long reply grew the content above the viewport and the
  /// scroll machinery yanked the offset to compensate — the flashing and
  /// bouncing seen while scrolling a chat that contains a long reply.
  /// Surviving the item, the measurement lets a rebuilt reply lay out
  /// collapsed on its first frame.
  final _measuredHeights = <String, double>{};

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
            description: chatRecorderErrorMessage(context, next.errorKind),
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
                                measuredHeights: _measuredHeights,
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
///
/// Watches [chatRecorderControllerProvider] internally so the 10 Hz amplitude
/// stream rebuilds only this subtree, not the full message list above.
class _ChatComposer extends ConsumerWidget {
  const _ChatComposer({
    required this.controller,
    required this.agentName,
    required this.isSending,
    required this.draft,
    required this.onDraftChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final String agentName;
  final bool isSending;
  final String draft;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final recorderState = ref.watch(chatRecorderControllerProvider);
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
            amplitudes: ref
                .read(chatRecorderControllerProvider.notifier)
                .getNormalizedAmplitudeHistory(),
            onCancel: () =>
                ref.read(chatRecorderControllerProvider.notifier).cancel(),
            onStop: () => ref
                .read(chatRecorderControllerProvider.notifier)
                .stopAndTranscribe(),
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
            onStartRecording: () =>
                ref.read(chatRecorderControllerProvider.notifier).start(),
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
                ? LottiIcons.send
                : (canRecord ? LottiIcons.mic : null),
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Row(
          children: [
            Expanded(
              child: WaveformBars(amplitudesNormalized: amplitudes),
            ),
            SizedBox(width: tokens.spacing.step3),
            _CircleIconButton(
              icon: LottiIcons.close,
              onPressed: onCancel,
              tooltip: context.messages.chatInputCancelRecording,
            ),
            SizedBox(width: tokens.spacing.step2),
            _CircleIconButton(
              icon: LottiIcons.stop,
              onPressed: onStop,
              tooltip: context.messages.chatInputStopTranscribe,
            ),
          ],
        ),
      ),
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
                  strokeWidth: BorderWidths.emphasis,
                  color: tokens.colors.interactive.enabled,
                ),
              ),
              Icon(
                LottiIcons.mic,
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
            width: TapTargets.minimum,
            height: TapTargets.minimum,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.agentName,
    required this.measuredHeights,
    super.key,
  });

  final AgentChatMessage message;
  final String agentName;

  /// List-owned reply heights; see [_AgentChatViewState._measuredHeights].
  final Map<String, double> measuredHeights;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isUser = message.role == AgentChatRole.user;
    final author = isUser ? context.messages.goalChatYou : agentName;
    final time = DateFormat.jm(
      Localizations.localeOf(context).toString(),
    ).format(message.createdAt);
    return Semantics(
      container: true,
      explicitChildNodes: !isUser,
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
                      child: _CollapsibleAgentMarkdown(
                        cacheKey: message.id,
                        measuredHeights: measuredHeights,
                        text: message.text,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                        fadeColor: tokens.colors.background.level02,
                      ),
                    ),
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

/// Collapses a long agent reply to a bounded height with a bottom fade and a
/// Show more / Show less toggle.
///
/// The clamp is HEIGHT-based, not line-based: `GptMarkdown` renders block
/// elements (lists, headings, quotes) as `WidgetSpan`s that each count as a
/// single "line" of the outer `Text.rich`, so a `maxLines` clamp never bites
/// on markdown-heavy replies and the former toggle looked inert. Measuring
/// the laid-out height keeps the toggle honest: it appears exactly when the
/// content overflows the collapsed viewport.
class _CollapsibleAgentMarkdown extends StatefulWidget {
  const _CollapsibleAgentMarkdown({
    required this.cacheKey,
    required this.measuredHeights,
    required this.text,
    required this.style,
    required this.fadeColor,
  });

  /// Identifies this reply in [measuredHeights] — the message id, stable
  /// across the item's disposal and rebuild.
  final String cacheKey;

  /// List-owned measurements that outlive this item; see
  /// [_AgentChatViewState._measuredHeights].
  final Map<String, double> measuredHeights;

  final String text;
  final TextStyle style;

  /// The bubble surface color the bottom fade dissolves into.
  final Color fadeColor;

  @override
  State<_CollapsibleAgentMarkdown> createState() =>
      _CollapsibleAgentMarkdownState();
}

class _CollapsibleAgentMarkdownState extends State<_CollapsibleAgentMarkdown> {
  static const _collapsedLines = 8;

  bool _expanded = false;
  double? _contentHeight;

  @override
  void initState() {
    super.initState();
    // A rebuilt item starts from the height the list already knows, so its
    // first frame is the collapsed one. A stale value (the pane was resized
    // while this reply was off screen) is corrected by the next measurement
    // — one settling rebuild, never a repeating one.
    _contentHeight = widget.measuredHeights[widget.cacheKey];
  }

  double get _collapsedHeight {
    final fontSize = widget.style.fontSize ?? 14;
    return fontSize * (widget.style.height ?? 1.4) * _collapsedLines;
  }

  void _handleHeight(double height) {
    widget.measuredHeights[widget.cacheKey] = height;
    if (_contentHeight == height) return;
    // Reported during layout — defer the rebuild to the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _contentHeight != height) {
        setState(() => _contentHeight = height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final collapsedHeight = _collapsedHeight;
    final overflows = (_contentHeight ?? 0) > collapsedHeight + 1;
    final collapsed = overflows && !_expanded;
    // The child stays laid out at full height inside the OverflowBox while
    // collapsed, so the measurement keeps tracking content changes.
    final content = _MeasureHeight(
      onHeight: _handleHeight,
      child: AgentMarkdownView(widget.text, style: widget.style),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!collapsed)
          content
        else
          ClipRect(
            key: const ValueKey('agent-reply-collapse'),
            child: Stack(
              children: [
                SizedBox(
                  height: collapsedHeight,
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxHeight: double.infinity,
                    child: content,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: tokens.spacing.step6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.fadeColor.withValues(alpha: 0),
                          widget.fadeColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (overflows) ...[
          SizedBox(height: tokens.spacing.step1),
          DesignSystemButton(
            label: _expanded
                ? context.messages.aiResponseShowLess
                : context.messages.aiResponseShowMore,
            onPressed: () => setState(() => _expanded = !_expanded),
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            trailingIcon: _expanded ? LottiIcons.collapse : LottiIcons.expand,
            alignsLabelToLeadingEdge: true,
          ),
        ],
      ],
    );
  }
}

class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported != size.height) {
      _reported = size.height;
      onHeight(size.height);
    }
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
