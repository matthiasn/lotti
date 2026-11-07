part of 'agent_chat_view.dart';

typedef AgentChatMessageAttachmentBuilder =
    Widget? Function(BuildContext context, AgentChatMessage message);

/// Builds what separates [message] from [previous] — a day divider in a
/// thread that runs across days — or null for nothing. [previous] is null
/// for the first message.
typedef AgentChatMessageDividerBuilder =
    Widget? Function(
      BuildContext context,
      AgentChatMessage message,
      AgentChatMessage? previous,
    );

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
    this.onSendSpoken,
    this.hasFailedTurn = false,
    this.attachmentBuilder,
    this.dividerBuilder,
    this.history,
    this.emptyState,
    this.emptyMessage,
    this.composerHint,
    this.activity,
    this.pinnedActivity,
    this.sendingLabel,
    this.footer,
    this.composerEnabled = true,
    this.allowDraftWhileSending = false,
    this.scrollOnReplies = true,
    this.conversationId,
    this.groupAttachmentsWithReply = false,
    this.footerTrailingBuilder,
    this.composerShape = DesignSystemTextInputShape.rounded,
    this.replyTextStyle,
    this.onLinkTap,
    this.resolveTranscriptionTarget,
    this.correctTranscript,
    this.resolveDictionaryCategory,
    this.conversational = false,
    this.voiceFirst = false,
    this.leading,
    this.composerHeader,
    this.onThreadScrolled,
    super.key,
  });

  /// Her replies as unboxed prose and the user's words in a soft bubble,
  /// with no author-and-time line on each message — a conversation with
  /// someone rather than a log. The footer line stays only for what
  /// [footerTrailingBuilder] adds.
  final bool conversational;

  /// What was said goes out as recording stops — no second tap on send —
  /// through [onSendSpoken] when given; the stop control then reads as
  /// send, transcribing can always be cancelled, and on a desktop the field
  /// takes the keyboard at once. The composer is the same one field, mic at
  /// its end, as any chat's.
  final bool voiceFirst;

  /// Scrolls in above the first message, with the thread.
  final Widget? leading;

  /// Sits inside the composer, above its controls: what the question will
  /// be asked with (a scope), part of the asking rather than the thread.
  final Widget? composerHeader;

  /// Where the thread's list is, on each scroll and layout — its own list
  /// only, not a scroll inside a message or the composer.
  final ValueChanged<ScrollMetrics>? onThreadScrolled;

  final String agentId;
  final String agentName;
  final String draft;
  final bool isSending;
  final bool hasFailedTurn;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final VoidCallback onRetry;

  /// Sends a transcript a [voiceFirst] chat sends by itself, so the host
  /// knows the turn was spoken; [onSend] when not given.
  final VoidCallback? onSendSpoken;
  final AgentChatMessageAttachmentBuilder? attachmentBuilder;

  /// Builds what a bubble's footer line carries after the author and the
  /// time — a per-turn cost, say — on the same line, so a turn's metadata
  /// is one row. Null, or a builder returning null, leaves the footer as it
  /// is.
  final AgentChatMessageAttachmentBuilder? footerTrailingBuilder;

  /// Rendered above a message, between it and the one before — the front
  /// thread's day dividers. Null renders nothing between messages.
  final AgentChatMessageDividerBuilder? dividerBuilder;

  /// A scoped consumer can supply its own privacy-filtered chat projection.
  /// When present the agent-wide message log is never subscribed to.
  final AsyncValue<List<AgentChatMessage>>? history;
  final Widget? emptyState;

  /// The empty conversation's line, when the default one — which addresses
  /// [agentName] — would name the wrong party. A person's briefing agent is
  /// the one listening, not the person.
  final String? emptyMessage;

  /// The composer's hint, for the same reason as [emptyMessage].
  final String? composerHint;
  final Widget? activity;

  /// Optional persistent status above the composer for an active request.
  final Widget? pinnedActivity;

  /// Describes the consumer's current operation in the composer and the
  /// default activity bubble's accessibility label.
  final String? sendingLabel;
  final Widget? footer;
  final bool composerEnabled;

  /// Allow preparation of the next draft while Send remains disabled.
  final bool allowDraftWhileSending;

  final bool scrollOnReplies;
  final String? conversationId;

  /// Keeps supporting evidence inside the reply's surface and reading width.
  final bool groupAttachmentsWithReply;
  final DesignSystemTextInputShape composerShape;

  /// Consumer typography for assistant replies; other conversations use the
  /// standard body style when omitted.
  final TextStyle? replyTextStyle;

  /// Lets a host resolve a reply link against the message that contains it.
  /// Supplying this handler also exposes the rich reply and its links to
  /// assistive technology instead of announcing a flattened message label.
  final void Function(AgentChatMessage message, String url, String title)?
  onLinkTap;

  /// Resolves the host's explicit transcription setup before uploading audio.
  final ChatTranscriptionTargetResolver? resolveTranscriptionTarget;

  /// Post-processes the words that setup heard before they reach the draft.
  final ChatTranscriptCorrector? correctTranscript;

  /// Names the speech dictionary that setup's request carries.
  final ChatDictionaryCategoryResolver? resolveDictionaryCategory;

  @override
  ConsumerState<AgentChatView> createState() => _AgentChatViewState();
}

/// Voice-enabled composer for the agent chat. Reuses the shared
/// [chatRecorderControllerProvider] — the same recorder the evolution chat
/// uses — so transcription, error toasts, and the waveform are shared
/// infrastructure. Idle shows a text field with a mic/send trailing icon;
/// recording and transcribing show the one [ChatRecordingPill] every chat
/// and the companion's stage share, the streaming partial transcript above
/// it while transcribing.
///
/// Watches [chatRecorderControllerProvider] internally so the 10 Hz amplitude
/// stream rebuilds only this subtree, not the full message list above.
class _ChatComposer extends ConsumerWidget {
  const _ChatComposer({
    required this.availableHeight,
    required this.controller,
    required this.hintText,
    required this.isSending,
    required this.allowDraftWhileSending,
    required this.sendingLabel,
    required this.draft,
    required this.onDraftChanged,
    required this.onSend,
    required this.shape,
    this.voiceFirst = false,
    this.header,
    this.resolveTranscriptionTarget,
    this.correctTranscript,
    this.resolveDictionaryCategory,
  });

  final bool voiceFirst;

  /// Shown above the controls, inside the composer.
  final Widget? header;
  final double availableHeight;
  final TextEditingController controller;
  final String hintText;
  final bool isSending;
  final bool allowDraftWhileSending;
  final String sendingLabel;
  final String draft;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final DesignSystemTextInputShape shape;
  final ChatTranscriptionTargetResolver? resolveTranscriptionTarget;
  final ChatTranscriptCorrector? correctTranscript;
  final ChatDictionaryCategoryResolver? resolveDictionaryCategory;

  /// [header] over [controls]. The header brings its own gap below it, so
  /// a header that renders nothing leaves no blank band.
  Widget _withHeader(Widget controls) {
    final header = this.header;
    if (header == null) return controls;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [header, controls],
    );
  }

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
        child: _withHeader(switch (status) {
          ChatRecorderStatus.recording => ChatRecordingPill(
            processing: false,
            elapsed: recorderState.elapsed,
            // Voice first, what was said goes out as it stops: the stop
            // control reads as the send it is.
            sendsOnStop: voiceFirst,
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
            availableHeight: availableHeight,
            partialTranscript: recorderState.partialTranscript ?? '',
            // A stalled transcription always has its way out.
            onCancel: () =>
                ref.read(chatRecorderControllerProvider.notifier).cancel(),
          ),
          _ => () {
            void startRecording() => ref
                .read(chatRecorderControllerProvider.notifier)
                .start(
                  resolveTranscriptionTarget: resolveTranscriptionTarget,
                  correctTranscript: correctTranscript,
                  resolveDictionaryCategory: resolveDictionaryCategory,
                );
            return ChatComposerField(
              controller: controller,
              hintText: hintText,
              isSending: isSending,
              allowDraftWhileSending: allowDraftWhileSending,
              sendingLabel: sendingLabel,
              draft: draft,
              onDraftChanged: onDraftChanged,
              onSend: onSend,
              shape: shape,
              onStartRecording: startRecording,
              // Where there is a keyboard, it types at once; a phone keeps
              // its keyboard down until the field is tapped, so talking
              // stays one tap.
              autofocus: voiceFirst && isDesktopLayout(context),
            );
          }(),
        }),
      ),
    );
  }
}

/// The recording pill while transcribing, with the streaming words above
/// it — kept inspectable without letting them push the pill, and its
/// Cancel, out of the composer. The host height already accounts for its
/// header and keyboard.
class _TranscriptionProgress extends StatefulWidget {
  const _TranscriptionProgress({
    required this.availableHeight,
    required this.partialTranscript,
    required this.onCancel,
  });

  final double availableHeight;
  final String partialTranscript;
  final VoidCallback onCancel;

  @override
  State<_TranscriptionProgress> createState() => _TranscriptionProgressState();
}

class _TranscriptionProgressState extends State<_TranscriptionProgress> {
  final _scrollController = ScrollController();
  bool _expanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final hasPartial = widget.partialTranscript.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = (constraints.maxWidth - tokens.spacing.step4 * 2)
            .clamp(0.0, double.infinity);
        final painter = TextPainter(
          text: TextSpan(text: widget.partialTranscript, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.localeOf(context),
        );
        final lineHeight = painter.preferredLineHeight;
        // Up to six lines, using at most a quarter of the actual chat height.
        // On a short viewport expansion can keep the same height while making
        // the full text scrollable, rather than squeezing out the controls.
        final previewHeight = (widget.availableHeight / 4).clamp(
          lineHeight,
          lineHeight * 6,
        );
        final collapsedLines = (previewHeight / lineHeight).floor().clamp(1, 3);
        painter
          ..maxLines = collapsedLines
          ..layout(maxWidth: textWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPartial) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step3,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.l),
                ),
                child: _expanded && overflows
                    ? ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: previewHeight),
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            key: const ValueKey('chat-transcription-preview'),
                            controller: _scrollController,
                            primary: false,
                            child: Text(widget.partialTranscript, style: style),
                          ),
                        ),
                      )
                    : Text(
                        widget.partialTranscript,
                        style: style,
                        maxLines: collapsedLines,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              SizedBox(height: tokens.spacing.step1),
            ],
            if (hasPartial && overflows)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MergeSemantics(
                  child: Semantics(
                    expanded: _expanded,
                    child: DesignSystemButton(
                      label: _expanded
                          ? context.messages.aiResponseShowLess
                          : context.messages.aiResponseShowMore,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      variant: DesignSystemButtonVariant.tertiary,
                      size: DesignSystemButtonSize.dense,
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  ),
                ),
              ),
            if (hasPartial) SizedBox(height: tokens.spacing.step1),
            ChatRecordingPill(
              processing: true,
              amplitudes: const [],
              elapsed: Duration.zero,
              onCancel: widget.onCancel,
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.agentName,
    required this.measuredHeights,
    this.attachment,
    this.footerTrailing,
    this.replyTextStyle,
    this.onLinkTap,
    this.conversational = false,
    super.key,
  });

  final bool conversational;
  final AgentChatMessage message;
  final String agentName;
  final Widget? attachment;

  /// What follows the author and the time on the footer line.
  final Widget? footerTrailing;
  final TextStyle? replyTextStyle;
  final void Function(String url, String title)? onLinkTap;

  /// List-owned reply heights; see [_AgentChatViewState._measuredHeights].
  final Map<String, double> measuredHeights;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isUser = message.role == AgentChatRole.user;
    final author = isUser ? context.messages.goalChatYou : agentName;
    // `DateFormat.jm` is hard-wired to 12-hour for an English locale, so a
    // message sent at 19:08 read "7:08 PM" on a 24-hour phone.
    final time = deviceClockLabel(context, message.createdAt);
    return Semantics(
      container: true,
      explicitChildNodes: !isUser,
      label: !isUser && onLinkTap != null
          ? context.messages.goalChatMessageFooter(author, time)
          : context.messages.goalChatMessageSemantics(
              author,
              time,
              message.text,
            ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _bubbleWidth(
              context,
              isUser: isUser && conversational,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // In a conversation her words are unboxed prose; the user's
              // keep a soft bubble.
              color: isUser
                  ? tokens.colors.surface.selected
                  : conversational
                  ? null
                  : tokens.colors.background.level02,
              borderRadius: BorderRadius.circular(tokens.radii.l),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: conversational && !isUser
                    ? 0
                    : tokens.spacing.step4,
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
                      excluding: onLinkTap == null,
                      child: _CollapsibleAgentMarkdown(
                        onLinkTap: onLinkTap,
                        cacheKey: message.id,
                        measuredHeights: measuredHeights,
                        text: message.text,
                        style:
                            (replyTextStyle ??
                                    tokens.typography.styles.body.bodyMedium)
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                        fadeColor: conversational
                            ? tokens.colors.background.level01
                            : tokens.colors.background.level02,
                      ),
                    ),
                  if (attachment != null) ...[
                    SizedBox(height: tokens.spacing.step3),
                    Material(
                      type: MaterialType.transparency,
                      child: attachment,
                    ),
                  ],
                  if (!conversational || footerTrailing != null) ...[
                    SizedBox(height: tokens.spacing.step1),
                    ExcludeSemantics(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!conversational)
                            Text(
                              context.messages.goalChatMessageFooter(
                                author,
                                time,
                              ),
                              style: tokens.typography.styles.others.caption
                                  .copyWith(
                                    color: tokens.colors.text.lowEmphasis,
                                  ),
                            ),
                          ?footerTrailing,
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
