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
/// Draws an agent reply's body; see [AgentChatView.replyBodyBuilder].
typedef AgentReplyBodyBuilder =
    Widget? Function(
      BuildContext context,
      AgentChatMessage message,
      Widget Function(String markdown) prose,
    );

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
    this.draftSpoken,
    this.onDraftSpoken,
    this.hasFailedTurn = false,
    this.failedTurnLabel,
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
    this.composerHelper,
    this.mentionOptions = const [],
    this.replyTextStyle,
    this.onLinkTap,
    this.resolveTranscriptionTarget,
    this.correctTranscript,
    this.resolveDictionaryCategory,
    this.conversational = false,
    this.voiceFirst = false,
    this.contentMaxWidth,
    this.replyBodyBuilder,
    this.threadOverlay,
    this.threadBottomInset = 0,
    super.key,
  });

  /// Drawn over the thread's area — not over the composer — and taking
  /// touches only where it paints: the companion's floating card. Pair it
  /// with [threadBottomInset] so the end of the thread scrolls clear of it.
  final Widget? threadOverlay;

  /// Extra room after the last message, so it can scroll out from under
  /// whatever [threadOverlay] keeps at the bottom of the thread. Capped at
  /// half the thread's height, so the last message never scrolls out of
  /// view when the overlay is shown smaller than asked or fills the area.
  final double threadBottomInset;

  /// Her replies as unboxed prose and the user's words in a soft bubble,
  /// with no author-and-time line on each message — a conversation with
  /// someone rather than a log. The footer line stays only for what
  /// [footerTrailingBuilder] adds.
  final bool conversational;

  /// Talking leads: on a desktop the field takes the keyboard at once, and
  /// what was said — read and corrected in the field first, then sent — goes
  /// out through [onSendSpoken] when given, so the host knows the turn was
  /// spoken.
  final bool voiceFirst;

  /// The width of one reading column, centred, that the thread and the
  /// composer's controls share, so the field's edges line up with the
  /// messages above it; null lets both take the full width.
  final double? contentMaxWidth;

  /// Draws an agent reply's body in place of its Markdown, for a host whose
  /// replies carry more than words (the front agent's lists of tasks, as
  /// task rows). `prose` renders a stretch of Markdown as the view renders
  /// replies — style, links — so the host keeps her words as they are around
  /// what it draws. Returns null for a reply drawn as usual.
  final AgentReplyBodyBuilder? replyBodyBuilder;

  final String agentId;
  final String agentName;
  final String draft;
  final bool isSending;
  final bool hasFailedTurn;

  /// What the failed-turn line says, when the chat knows why the turn did
  /// not go through; the generic "that didn't send" otherwise.
  final String? failedTurnLabel;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final VoidCallback onRetry;

  /// Sends a draft that came from what was said (read, perhaps corrected),
  /// so the host knows the turn was spoken; [onSend] when not given.
  final VoidCallback? onSendSpoken;

  /// The host's record of whether [draft] came from what was said, when the
  /// host keeps one — two views editing one draft (the companion's stage
  /// over her chat) then send it the same way. Null keeps it in the view.
  final bool? draftSpoken;

  /// Told when what was said lands in the field, for a host that keeps
  /// [draftSpoken].
  final VoidCallback? onDraftSpoken;
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

  /// What the composer says under its field — only what this chat
  /// supports (that `@` names a category, say).
  final String? composerHelper;

  /// What `@` offers in the composer; none, no `@`.
  final List<DesignSystemChatInputMention> mentionOptions;

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

/// The agent chat's composer: the one [DesignSystemChatInput] every
/// conversation is asked through, driven by the shared
/// [chatRecorderControllerProvider] — the same recorder the evolution chat
/// and the companion's stage use — so transcription, error toasts and the
/// voice's levels are shared infrastructure.
///
/// Watches the recorder itself, so its 10 Hz levels rebuild only this
/// subtree, not the thread above.
class _ChatComposer extends ConsumerWidget {
  const _ChatComposer({
    required this.controller,
    required this.hintText,
    required this.isSending,
    required this.allowDraftWhileSending,
    required this.sendingLabel,
    required this.onSend,
    this.helperText,
    this.mentionOptions = const [],
    this.voiceFirst = false,
    this.contentMaxWidth,
    this.resolveTranscriptionTarget,
    this.correctTranscript,
    this.resolveDictionaryCategory,
  });

  final bool voiceFirst;

  /// The reading column the input keeps to, centred; null for the full
  /// width.
  final double? contentMaxWidth;
  final TextEditingController controller;
  final String hintText;
  final String? helperText;
  final List<DesignSystemChatInputMention> mentionOptions;
  final bool isSending;
  final bool allowDraftWhileSending;
  final String sendingLabel;
  final VoidCallback onSend;
  final ChatTranscriptionTargetResolver? resolveTranscriptionTarget;
  final ChatTranscriptCorrector? correctTranscript;
  final ChatDictionaryCategoryResolver? resolveDictionaryCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final recorderState = ref.watch(chatRecorderControllerProvider);
    final recorder = ref.read(chatRecorderControllerProvider.notifier);
    // Sending blocks the next draft unless the host lets it be prepared;
    // then only Send waits.
    final blocked = isSending && !allowDraftWhileSending;
    final input = DesignSystemChatInput(
      controller: controller,
      hintText: hintText,
      helperText: helperText,
      mentionOptions: mentionOptions,
      busyText: blocked ? sendingLabel : null,
      phase: switch (recorderState.status) {
        ChatRecorderStatus.recording => DesignSystemChatInputPhase.recording,
        ChatRecorderStatus.processing =>
          DesignSystemChatInputPhase.transcribing,
        _ => DesignSystemChatInputPhase.compose,
      },
      levels: recorder.getNormalizedAmplitudeHistory(),
      elapsed: recorderState.elapsed,
      partialTranscript: recorderState.partialTranscript,
      onSend: isSending ? null : onSend,
      onStartRecording: () => recorder.start(
        resolveTranscriptionTarget: resolveTranscriptionTarget,
        correctTranscript: correctTranscript,
        resolveDictionaryCategory: resolveDictionaryCategory,
      ),
      // Done hands the take back: its words land in the field to be read.
      onFinishRecording: recorder.stopAndTranscribe,
      onCancelRecording: recorder.cancel,
      // Where there is a keyboard, it types at once; a phone keeps its
      // keyboard down until the field is tapped, so talking stays one tap.
      autofocus: voiceFirst && isDesktopLayout(context),
    );
    final maxWidth = contentMaxWidth;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: maxWidth == null
            ? input
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: input,
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
    this.attachment,
    this.footerTrailing,
    this.replyTextStyle,
    this.onLinkTap,
    this.conversational = false,
    this.replyBodyBuilder,
    super.key,
  });

  final bool conversational;
  final AgentReplyBodyBuilder? replyBodyBuilder;
  final AgentChatMessage message;
  final String agentName;
  final Widget? attachment;

  /// What follows the author and the time on the footer line.
  final Widget? footerTrailing;
  final TextStyle? replyTextStyle;
  final void Function(String url, String title)? onLinkTap;

  /// List-owned reply heights; see [_AgentChatViewState._measuredHeights].
  final Map<String, double> measuredHeights;

  /// Her words' style: the host's, else body text, high emphasis.
  TextStyle _replyStyle(DsTokens tokens) =>
      (replyTextStyle ?? tokens.typography.styles.body.bodyMedium).copyWith(
        color: tokens.colors.text.highEmphasis,
      );

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
                      child:
                          replyBodyBuilder?.call(
                            context,
                            message,
                            (markdown) => AgentMarkdownView(
                              markdown,
                              style: _replyStyle(tokens),
                              onLinkTap: onLinkTap,
                            ),
                          ) ??
                          _CollapsibleAgentMarkdown(
                            onLinkTap: onLinkTap,
                            cacheKey: message.id,
                            measuredHeights: measuredHeights,
                            text: message.text,
                            style: _replyStyle(tokens),
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
