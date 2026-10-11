import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_orb_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_levels.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The app's one recorder, shared by every surface that records — the
/// recording sheet a task's microphone opens, and the check-in composer and
/// page that record in place. A recorder that drew its own parts read as
/// another app's recorder however carefully it was spaced.
///
/// Composed as a studio recorder ([RecordingStage]): the status, the level
/// display the user chose on its lit pool, the running time, the level line
/// under it, and one red Stop between the two quiet controls.

/// The whole recorder, top to bottom: the status line (where the host has
/// none of its own), the level display, the time, the level line, the
/// [controls], and an optional [footer] — every gap a design-system step,
/// so each host reads the same.
class RecordingStage extends StatelessWidget {
  const RecordingStage({
    required this.state,
    required this.controls,
    this.showStatus = true,
    this.levelSemanticsLabel,
    this.announceLevel = false,
    this.clockSemanticsLabel,
    this.notice,
    this.footer,
    super.key,
  });

  final AudioRecorderState state;

  /// The transport row while a take runs, or the host's record button
  /// before one starts.
  final Widget controls;

  /// Whether to say *Recording* / *Paused* above the display — not where
  /// the host's own header already says so.
  final bool showStatus;

  /// What a screen reader hears for the level display and line, which are
  /// pictures; nothing when null.
  final String? levelSemanticsLabel;

  /// Whether that label is a live region — where nothing else on the
  /// surface announces the take starting.
  final bool announceLevel;
  final String? clockSemanticsLabel;

  /// A line under the time, such as a failure the host reports.
  final Widget? notice;

  /// What sits under the controls: an option, or a reassurance.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final live = state.status == AudioRecorderStatus.recording;
    final paused = state.status == AudioRecorderStatus.paused;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStatus && (live || paused))
          // Clear of a sheet's drag handle above; the orb's own margin is
          // the gap below.
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step4),
            child: RecordingStatus(paused: paused),
          ),
        Semantics(
          liveRegion: announceLevel,
          label: levelSemanticsLabel,
          child: ExcludeSemantics(
            child: RecordingLevelVisualizer(state: state),
          ),
        ),
        RecordingClock(
          progress: state.progress,
          semanticsLabel: clockSemanticsLabel,
        ),
        if (notice case final notice?) ...[
          SizedBox(height: tokens.spacing.step2),
          notice,
        ],
        SizedBox(height: tokens.spacing.step3),
        ExcludeSemantics(child: RecordingLevelLine(state: state)),
        SizedBox(height: tokens.spacing.step6),
        controls,
        if (footer case final footer?) ...[
          SizedBox(height: tokens.spacing.step6),
          footer,
        ],
      ],
    );
  }
}

/// *● Recording*, or *Paused* with the dot at rest: what the take is doing,
/// in words, for the host that has no status line of its own.
class RecordingStatus extends StatelessWidget {
  const RecordingStatus({required this.paused, super.key});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tokens.spacing.step3,
          height: tokens.spacing.step3,
          decoration: BoxDecoration(
            color: paused
                ? tokens.colors.text.lowEmphasis
                : tokens.colors.alert.error.defaultColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          paused
              ? messages.audioRecordingStatusPaused
              : messages.sidebarAudioRecordingStatusLabel,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

/// The level display, per the persisted [RecordingStyle]: the voice orb for
/// [RecordingStyle.modern], the analog VU meter otherwise — including while
/// the preference is still loading, so the meter never flashes to the orb
/// and back on the first frame. On a light surface the orb sits on a soft
/// lit pool, so its glints have something to glow against.
class RecordingLevelVisualizer extends ConsumerWidget {
  const RecordingLevelVisualizer({
    required this.state,
    this.orbSize = defaultOrbSize,
    this.meterWidth = defaultMeterWidth,
    super.key,
  });

  /// The recording sheet's orb.
  static const double defaultOrbSize = 220;

  /// The recording sheet's meter, at its widest.
  static const double defaultMeterWidth = 400;

  final AudioRecorderState state;
  final double orbSize;

  /// The meter's width; it never grows past the space it is given.
  final double meterWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final style = ref.watch(recordingStyleProvider).asData?.value;
    if (style != RecordingStyle.modern) {
      return LayoutBuilder(
        builder: (context, constraints) => AnalogVuMeter(
          key: const ValueKey('recording-visualizer-meter'),
          vu: state.vu,
          dBFS: state.dBFS,
          // Clamping an unbounded width lands on the meter's own.
          size: constraints.maxWidth.clamp(0, meterWidth).toDouble(),
          colorScheme: Theme.of(context).colorScheme,
        ),
      );
    }
    final palette = AiVoiceOrbPalette.fromTokens(tokens);
    final orb = AiVoiceInputShader(
      key: const ValueKey('recording-visualizer-orb'),
      dbfs: state.dBFS,
      size: orbSize,
      intensity: 1,
      palette: palette,
    );
    if (!palette.onLightSurface) return orb;
    // The lit pool: the brightest surface at the centre, the lit glint at
    // the ring's radius, fading out before the orb's own crop — a lens for
    // the glints, never a visible disc or a shadow.
    return DecoratedBox(
      key: const ValueKey('recording-visualizer-pool'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            tokens.colors.background.level01.withValues(alpha: 0.6),
            palette.glint.withValues(alpha: 0.16),
            palette.glint.withValues(alpha: 0),
          ],
          stops: const [0, 0.7, 1],
        ),
      ),
      child: orb,
    );
  }
}

/// The level over the last few seconds, as a thin line of bars across the
/// sheet that fades out at both ends: the accent under the orb, the
/// neutral ink under the meter, as onboarding pairs them. It adds a sample
/// per level change while the take runs and holds still while paused.
class RecordingLevelLine extends ConsumerStatefulWidget {
  const RecordingLevelLine({required this.state, super.key});

  /// How many level samples the line keeps — two per bar, so it moves
  /// smoothly without each 20 ms sample jolting it.
  static const int levelWindow = 80;

  /// Bars across the line.
  static const int barCount = levelWindow ~/ 2;

  /// The line at its widest.
  static const double maxWidth = 400;

  final AudioRecorderState state;

  @override
  ConsumerState<RecordingLevelLine> createState() => _RecordingLevelLineState();
}

class _RecordingLevelLineState extends ConsumerState<RecordingLevelLine> {
  List<double> _levels = const [];

  @override
  void didUpdateWidget(covariant RecordingLevelLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.status == AudioRecorderStatus.recording &&
        widget.state.dBFS != oldWidget.state.dBFS) {
      final next = [..._levels, normaliseDbfs(widget.state.dBFS)];
      _levels = next.length > RecordingLevelLine.levelWindow
          ? next.sublist(next.length - RecordingLevelLine.levelWindow)
          : next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final modern =
        ref.watch(recordingStyleProvider).asData?.value ==
        RecordingStyle.modern;
    return LayoutBuilder(
      builder: (context, constraints) => ShaderMask(
        // The line fades in and out at its ends, so it reads as a stretch
        // of time passing rather than a bar chart with edges.
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            tokens.colors.text.highEmphasis.withValues(alpha: 0),
            tokens.colors.text.highEmphasis,
            tokens.colors.text.highEmphasis,
            tokens.colors.text.highEmphasis.withValues(alpha: 0),
          ],
          stops: const [0, 0.18, 0.82, 1],
        ).createShader(bounds),
        child: LiveWaveform(
          key: const ValueKey('recording-visualizer-bars'),
          amplitudes: _levels,
          barCount: RecordingLevelLine.barCount,
          width: constraints.maxWidth
              .clamp(0, RecordingLevelLine.maxWidth)
              .toDouble(),
          height: tokens.spacing.step6,
          color: modern
              ? tokens.colors.interactive.enabled
              : tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}

/// The running time, `0:00:42`, in the UI face with tabular figures — the
/// digits never shift as they tick — in the neutral ink, so colour is left
/// to the live parts.
class RecordingClock extends StatelessWidget {
  const RecordingClock({
    required this.progress,
    this.semanticsLabel,
    super.key,
  });

  final Duration progress;

  /// What a screen reader hears instead of the digits, when the host has
  /// the words for it.
  final String? semanticsLabel;

  /// `h:mm:ss` — the duration's own rendering without its fraction.
  static String format(Duration progress) {
    final text = progress.toString();
    return text.substring(0, text.length - 7);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      format(progress),
      textAlign: TextAlign.center,
      semanticsLabel: semanticsLabel,
      style: tokens.typography.styles.heading.heading3.copyWith(
        fontWeight: tokens.typography.weight.regular,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: tokens.colors.text.highEmphasis,
      ),
    );
  }
}

/// The transport row: discard ✕ and pause ⏸ / resume ▶ as quiet rings on
/// either side of the one red Stop disc — the only colour in the row, the
/// one way a take becomes an entry. Every action is inert while [busy] — a
/// stop or discard already on its way — and the host decides what each one
/// means (whether discarding asks first, where a stopped take goes).
class RecordingTransportControls extends StatelessWidget {
  const RecordingTransportControls({
    required this.paused,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onStop,
    this.busy = false,
    this.discardLabel,
    this.discardKey = const ValueKey('cancel_recording'),
    this.pauseKey = const ValueKey('pause_resume_button'),
    this.stopKey = const ValueKey('stop_recording'),
    super.key,
  });

  final bool paused;
  final bool busy;
  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  /// The discard control's name; the recording sheet's *Cancel* by default.
  final String? discardLabel;
  final Key discardKey;
  final Key pauseKey;
  final Key stopKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Wraps rather than overflows on a very narrow screen at a large text
    // size; at any ordinary width it is one centred row.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step6,
      runSpacing: tokens.spacing.step3,
      children: [
        _RoundControl(
          key: discardKey,
          label: discardLabel ?? messages.audioRecordingCancel,
          icon: LottiIcons.close,
          onTap: busy ? null : onDiscard,
        ),
        _StopDisc(key: stopKey, onTap: busy ? null : onStop),
        _RoundControl(
          key: pauseKey,
          label: paused
              ? messages.audioRecordingResume
              : messages.audioRecordingPause,
          icon: paused ? LottiIcons.play : LottiIcons.pause,
          onTap: busy ? null : onTogglePause,
        ),
      ],
    );
  }
}

/// Fades a control to the design system's disabled alpha while it takes no
/// tap, and names it as one button.
class _Control extends StatelessWidget {
  const _Control({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final enabled = onTap != null;
    // The control's own node outermost, so it is one button by its name;
    // the tooltip only shows that name to a pointer.
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : tokens.colors.text.lowEmphasis.a,
            duration: MotionDurations.short4,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A quiet 48px ring, the whole of it tappable.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return _Control(
      label: label,
      onTap: onTap,
      child: Container(
        width: tokens.spacing.step9,
        height: tokens.spacing.step9,
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.colors.decorative.level02),
        ),
        child: AnimatedSwitcher(
          duration: MotionDurations.short4,
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: IconSizes.l,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}

/// The red Stop: a filled 64px disc with the stop square in the ink made
/// for alert fills.
class _StopDisc extends StatelessWidget {
  const _StopDisc({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return _Control(
      label: context.messages.audioRecordingStop,
      onTap: onTap,
      child: Container(
        width: tokens.spacing.step10,
        height: tokens.spacing.step10,
        decoration: BoxDecoration(
          color: tokens.colors.alert.error.defaultColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: tokens.spacing.step6,
          height: tokens.spacing.step6,
          decoration: BoxDecoration(
            color: tokens.colors.text.onInteractiveAlert,
            borderRadius: BorderRadius.circular(tokens.radii.xs),
          ),
        ),
      ),
    );
  }
}
