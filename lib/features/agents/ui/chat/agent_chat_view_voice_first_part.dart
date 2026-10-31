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
                  dimension: ControlSizes.avatarHero,
                  child: Icon(LottiIcons.mic, size: IconSizes.xl, color: ink),
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

/// The talk control while it is live, laid out exactly as at rest so
/// nothing moves: the same disc in the same place, one caption under it,
/// and in the slot "Type instead" held, one quiet Cancel. Listening, the
/// disc carries a stop mark and breathes with the voice ([_ListeningDisc]);
/// one tap sends what was said. Transcribing, it waits, and the Cancel slot
/// is kept empty so the composer keeps its height. Escape cancels.
class _VoiceFirstLive extends StatelessWidget {
  const _VoiceFirstLive({
    required this.processing,
    required this.dbfs,
    required this.onStop,
    required this.onCancel,
  });

  final bool processing;

  /// What it hears now, in dBFS.
  final double dbfs;
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
                child: processing
                    ? Material(
                        key: const Key('agent-chat-talk'),
                        color: tokens.colors.surface.enabled,
                        shape: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: ControlSizes.avatarHero,
                          child: Center(
                            child: SizedBox.square(
                              dimension: IconSizes.xl,
                              child: CircularProgressIndicator(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                            ),
                          ),
                        ),
                      )
                    : _ListeningDisc(dbfs: dbfs, onStop: onStop),
              ),
              SizedBox(height: tokens.spacing.step3),
              ExcludeSemantics(
                child: Text(
                  caption,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
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

/// The talk disc while it listens: the same teal disc as "Tap to talk", a
/// stop mark on it, and soft ripples rising from its edge — reaching
/// further and glowing brighter while the user speaks, a slow quiet pulse
/// in the pauses. Still when the platform asks for reduced motion.
class _ListeningDisc extends StatefulWidget {
  const _ListeningDisc({required this.dbfs, required this.onStop});

  final double dbfs;
  final VoidCallback onStop;

  /// Quieter than this is silence; louder than [_loud] is full voice.
  static const double _quiet = -60;
  static const double _loud = -15;

  /// One ripple's rise from the disc's edge to gone.
  static const Duration ripplePeriod = Duration(milliseconds: 2400);

  /// The voice level as a share of full voice.
  static double levelOf(double dbfs) =>
      ((dbfs - _quiet) / (_loud - _quiet)).clamp(0.0, 1.0);

  @override
  State<_ListeningDisc> createState() => _ListeningDiscState();
}

class _ListeningDiscState extends State<_ListeningDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _ListeningDisc.ripplePeriod,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final still = MediaQuery.disableAnimationsOf(context);
    // The level glides rather than jumps: words come in bursts.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _ListeningDisc.levelOf(widget.dbfs)),
      duration: MotionDurations.short4,
      curve: MotionCurves.standard,
      builder: (context, level, disc) => CustomPaint(
        key: const Key('agent-chat-talk-ripples'),
        painter: _RipplePainter(
          clock: _clock,
          level: level,
          still: still,
          color: tokens.colors.interactive.enabled,
          reach: tokens.spacing.step6,
        ),
        // The disc swells a touch with the voice.
        child: Transform.scale(scale: 1 + 0.05 * level, child: disc),
      ),
      child: Material(
        key: const Key('agent-chat-talk'),
        color: tokens.colors.interactive.enabled,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onStop,
          child: SizedBox.square(
            dimension: ControlSizes.avatarHero,
            // A filled stop mark: the one thing a tap does now.
            child: Center(
              child: SizedBox.square(
                key: const Key('agent-chat-talk-stop'),
                dimension: IconSizes.m,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.colors.text.onInteractiveAlert,
                    borderRadius: BorderRadius.circular(tokens.radii.xs),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the ripples behind the disc, past its edge: a few soft rings of
/// light in the disc's own hue, each rising and fading in turn, and a glow
/// hugging the edge that swells with the voice.
class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.clock,
    required this.level,
    required this.still,
    required this.color,
    required this.reach,
  }) : super(repaint: clock);

  static const int ripples = 3;

  final Animation<double> clock;

  /// The voice level, 0 (silence) to 1 (full voice).
  final double level;
  final bool still;
  final Color color;

  /// How far past the disc's edge a ripple rises at full voice.
  final double reach;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final edge = size.shortestSide / 2;
    // Soft light rather than a drawn line: every stroke is blurred.
    final blur = MaskFilter.blur(BlurStyle.normal, reach / 10);
    // The glow at the edge: there in a breath, full with the voice.
    canvas.drawCircle(
      centre,
      edge,
      Paint()
        ..color = color.withValues(
          alpha: SurfaceAlphas.washBorder * (0.3 + 0.7 * level),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, reach / 2),
    );
    if (still) return;
    // Silence keeps a quiet pulse; the voice brings them up bright.
    final strength =
        SurfaceAlphas.tint +
        (SurfaceAlphas.linework - SurfaceAlphas.tint) * level;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = reach / 8
      ..maskFilter = blur;
    for (var i = 0; i < ripples; i++) {
      final t = (clock.value + i / ripples) % 1;
      final rise = Curves.easeOut.transform(t);
      // A ripple rises further the louder the voice, never less than a
      // breath past the edge.
      final radius = edge + reach * rise * (0.4 + 0.6 * level);
      ring.color = color.withValues(alpha: strength * (1 - t) * (1 - t));
      canvas.drawCircle(centre, radius, ring);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.level != level ||
      old.still != still ||
      old.color != color ||
      old.reach != reach;
}

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
