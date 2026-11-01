part of 'agent_chat_view.dart';

/// Whether the user chose typing over talking: it holds for the session
/// (keep-alive), so a keyboard user is not asked again in every
/// conversation.
final NotifierProvider<AgentChatPrefersTyping, bool>
agentChatPrefersTypingProvider = NotifierProvider<AgentChatPrefersTyping, bool>(
  AgentChatPrefersTyping.new,
  name: 'agentChatPrefersTypingProvider',
);

class AgentChatPrefersTyping extends Notifier<bool> {
  @override
  bool build() => false;

  void prefer() => state = true;
}

/// The idle composer of a voice-first conversation: one large talk control
/// leads, with typing a tap away.
///
/// Tapping the control starts recording (the shared recorder; tap again to
/// stop and send what was said through the transcript). "Type instead"
/// swaps in the ordinary text composer, which is also shown whenever a
/// draft exists, so a half-typed message is never hidden behind the button.
class _VoiceFirstIdle extends ConsumerWidget {
  const _VoiceFirstIdle({
    required this.textComposer,
    required this.hasDraft,
    required this.canRecord,
    required this.onStartRecording,
  });

  /// The ordinary text composer, shown while typing.
  final Widget textComposer;
  final bool hasDraft;
  final bool canRecord;
  final VoidCallback onStartRecording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(agentChatPrefersTypingProvider) || hasDraft) {
      return textComposer;
    }
    final tokens = context.designTokens;
    final messages = context.messages;
    final ink = canRecord
        ? tokens.colors.text.onInteractiveAlert
        : tokens.colors.text.lowEmphasis;
    // The composer's full width, so its top border spans the surface.
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            enabled: canRecord,
            label: messages.chatInputTapToTalk,
            child: Material(
              key: const Key('agent-chat-talk'),
              color: canRecord
                  ? tokens.colors.interactive.enabled
                  : tokens.colors.surface.enabled,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: canRecord ? onStartRecording : null,
                child: SizedBox.square(
                  dimension: _talkSize(tokens),
                  child: Icon(LottiIcons.mic, size: IconSizes.l, color: ink),
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          ExcludeSemantics(
            child: Text(
              messages.chatInputTapToTalk,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          DesignSystemButton(
            key: const Key('agent-chat-type-instead'),
            label: messages.chatInputTypeInstead,
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.dense,
            leadingIcon: LottiIcons.keyboard,
            onPressed: () =>
                ref.read(agentChatPrefersTypingProvider.notifier).prefer(),
          ),
        ],
      ),
    );
  }
}

/// The talk control while it is live, laid out as at rest so nothing
/// else moves: the caption's line under it — empty while listening, the
/// waveform says that; "Transcribing" after — and in the slot "Type
/// instead" held, one quiet Cancel. Screen readers hear the state as the
/// pill's label. The disc stretches into a pill carrying what it hears
/// ([_ListeningPill]); one tap sends what was said. Transcribing, the pill
/// holds the words' shape and waits, and the Cancel slot is kept empty so
/// the composer keeps its height. Escape cancels.
class _VoiceFirstLive extends StatelessWidget {
  const _VoiceFirstLive({
    required this.processing,
    required this.amplitudes,
    required this.onStop,
    required this.onCancel,
  });

  final bool processing;

  /// What it heard, levels in `0..1`, oldest first.
  final List<double> amplitudes;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = processing
        ? messages.chatInputTranscribing
        : messages.chatInputListeningTapWhenDone;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: !processing,
                label: caption,
                child: _ListeningPill(
                  amplitudes: amplitudes,
                  processing: processing,
                  onStop: onStop,
                ),
              ),
              SizedBox(height: tokens.spacing.step3),
              // The moving waveform says it is listening; only the wait
              // after it needs words. The line keeps its place either way,
              // so nothing below moves.
              Visibility(
                visible: processing,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: ExcludeSemantics(
                  child: Text(
                    messages.chatInputTranscribing,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.step2),
              Visibility(
                visible: !processing,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: DesignSystemButton(
                  key: const Key('agent-chat-talk-cancel'),
                  label: messages.cancelButton,
                  variant: DesignSystemButtonVariant.quiet,
                  size: DesignSystemButtonSize.dense,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The talk disc, stretched: the same teal and height as "Tap to talk",
/// widening into a pill as listening starts, the voice scrolling across it
/// as bars — newest at the right, a dot for each quiet moment — up to the
/// stop mark at its end. Transcribing, the bars hold still and a spinner
/// takes the stop mark's place.
class _ListeningPill extends StatelessWidget {
  const _ListeningPill({
    required this.amplitudes,
    required this.processing,
    required this.onStop,
  });

  /// The widest the pill grows, in talk discs.
  static const double widthInDiscs = 4.4;

  final List<double> amplitudes;
  final bool processing;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ink = tokens.colors.text.onInteractiveAlert;
    final height = _talkSize(tokens);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (height * widthInDiscs).clamp(
          0.0,
          constraints.maxWidth,
        );
        // It opens from the disc it was.
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: height, end: width),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : MotionDurations.medium2,
          curve: MotionCurves.emphasizedDecelerate,
          builder: (context, grown, content) => Material(
            key: const Key('agent-chat-talk'),
            color: tokens.colors.interactive.enabled,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: processing ? null : onStop,
              child: SizedBox(width: grown, height: height, child: content),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
            child: Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: const Key('agent-chat-talk-waveform'),
                      size: Size(double.infinity, tokens.spacing.step8),
                      painter: WaveformBarsPainter(
                        amplitudes: amplitudes,
                        barWidth: tokens.spacing.step2,
                        barSpacing: tokens.spacing.step1,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step4),
                SizedBox.square(
                  dimension: IconSizes.m,
                  child: processing
                      ? CircularProgressIndicator(
                          key: const Key('agent-chat-talk-transcribing'),
                          strokeWidth: tokens.spacing.step1,
                          color: ink,
                        )
                      : DecoratedBox(
                          key: const Key('agent-chat-talk-stop'),
                          decoration: BoxDecoration(
                            color: ink,
                            borderRadius: BorderRadius.circular(
                              tokens.radii.xs,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The talk control's size: the disc's diameter, and the height of the
/// pill it stretches into while listening.
double _talkSize(DsTokens tokens) => tokens.spacing.step10;

/// How wide a bubble may grow: the reading width; in a conversation on a
/// narrow screen the user's words stop short of the far edge, so where a
/// message sits says who spoke, not only its fill.
double _bubbleWidth(BuildContext context, {required bool isUser}) {
  const userShare = 0.8;
  final width = MediaQuery.sizeOf(context).width;
  return isUser
      ? (width * userShare).clamp(0.0, kActionListContentMaxWidth)
      : kActionListContentMaxWidth;
}

/// Her turn while she is thinking: unboxed in a conversation, where her
/// words are unboxed too, so it never changes shape on answering.
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.label, this.conversational = false});

  final String label;
  final bool conversational;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: conversational ? null : tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.l),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: conversational ? 0 : tokens.spacing.step4,
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
