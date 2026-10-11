import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_orb_palette.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_levels.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/celebration/celebration_preferences_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The app's one recorder, shared by every surface that records — the
/// recording sheet a task's microphone opens, and the check-in composer and
/// page that record in place. A recorder that drew its own parts read as
/// another app's recorder however carefully it was spaced.
///
/// Composed as a studio recorder ([RecordingStage]) on one centred axis:
/// the level display the user chose, the level line under it, the running
/// time inside the red Stop between the two quiet controls — the app's one
/// running-clock control, the pill a task's Track time wears — and a footer
/// in the recorder's small voice.

/// The one small voice every line of words on the recorder speaks in — an
/// option, a reassurance, a failure.
TextStyle recordingCaptionStyle(DsTokens tokens) =>
    tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

/// The whole recorder, top to bottom: the level display (left out when
/// [compact]), the level line, the [controls] — whose Stop carries the
/// running time — and an optional [footer], in one column no wider than
/// the level line, every gap a design-system step, so each host reads the
/// same.
class RecordingStage extends StatelessWidget {
  const RecordingStage({
    required this.state,
    required this.controls,
    this.compact = false,
    this.levelSemanticsLabel,
    this.announceLevel = false,
    this.notice,
    this.footer,
    super.key,
  });

  final AudioRecorderState state;

  /// The transport row while a take runs, or the host's record button
  /// before one starts.
  final Widget controls;

  /// Whether to leave the orb or meter out, for a host with no room for it:
  /// the level line is then the recorder's only meter.
  final bool compact;

  /// What a screen reader hears for the level display and line, which are
  /// pictures; nothing when null.
  final String? levelSemanticsLabel;

  /// Whether that label is a live region — where nothing else on the
  /// surface announces the take starting.
  final bool announceLevel;

  /// A line under the level line, such as a failure the host reports.
  final Widget? notice;

  /// What sits under the controls: an option, or a reassurance.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Between the pictures, the controls and the footer: a step tighter in
    // a dock, so its inner gaps never outgrow its edges.
    final groupGap = compact ? tokens.spacing.step4 : tokens.spacing.step6;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: RecordingLevelLine.maxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compact)
              // The line stands in for the pictures it would sit under.
              Semantics(
                liveRegion: announceLevel,
                label: levelSemanticsLabel,
                child: ExcludeSemantics(
                  child: RecordingLevelLine(state: state),
                ),
              )
            else ...[
              Semantics(
                liveRegion: announceLevel,
                label: levelSemanticsLabel,
                child: ExcludeSemantics(
                  child: RecordingLevelVisualizer(state: state),
                ),
              ),
              // No step of its own: the orb's canvas already keeps a margin
              // of glow below its ring, and that margin is the gap.
              ExcludeSemantics(child: RecordingLevelLine(state: state)),
            ],
            if (notice case final notice?) ...[
              SizedBox(height: tokens.spacing.step3),
              notice,
            ],
            SizedBox(height: groupGap),
            controls,
            if (footer case final footer?) ...[
              SizedBox(height: groupGap),
              footer,
            ],
          ],
        ),
      ),
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

/// The level over the last stretch of the take, as a thin line of bars
/// across the column that fades out towards its oldest end: the accent under the orb,
/// the neutral ink under the meter, as onboarding pairs them. It adds a
/// sample per recorder tick while the take runs — a steady level too, so
/// silence ages the loud bars out — holds still while paused, and starts
/// empty for each new take.
class RecordingLevelLine extends ConsumerStatefulWidget {
  const RecordingLevelLine({required this.state, super.key});

  /// How many level samples the line keeps — two per bar, each bar the
  /// louder of its pair, so it moves smoothly without each 20 ms sample
  /// jolting it.
  static const int levelWindow = 80;

  /// Bars across the line.
  static const int barCount = levelWindow ~/ 2;

  /// The recorder's column at its widest.
  static const double maxWidth = 400;

  /// The line's width under each look: the orb's diameter, or the meter's
  /// width — so the line, the look above it and the transport row below
  /// share one measure instead of three.
  static double widthFor({required bool modern}) => modern
      ? RecordingLevelVisualizer.defaultOrbSize
      : RecordingLevelVisualizer.defaultMeterWidth;

  /// The mask the line is drawn through: it fades in at the oldest end
  /// only, so the line reads as time passing towards *now*, the newest bars
  /// at full strength.
  static LinearGradient fadeOf(DsTokens tokens) => LinearGradient(
    colors: [
      tokens.colors.text.highEmphasis.withValues(alpha: 0),
      tokens.colors.text.highEmphasis,
    ],
    stops: const [0, 0.18],
  );

  /// The window as bars: each bar the louder of its two samples, paired
  /// from the newest back so the latest bar is always whole.
  static List<double> barsOf(List<double> levels) => [
    for (var end = levels.length; end > 0; end -= 2)
      levels.sublist(end < 2 ? 0 : end - 2, end).reduce(math.max),
  ].reversed.toList();

  final AudioRecorderState state;

  @override
  ConsumerState<RecordingLevelLine> createState() => _RecordingLevelLineState();
}

class _RecordingLevelLineState extends ConsumerState<RecordingLevelLine> {
  List<double> _levels = const [];

  @override
  void didUpdateWidget(covariant RecordingLevelLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A stopped take is over: a host that stays up after a failed stop
    // starts its next take on an empty line, not on the last one's bars.
    if (widget.state.status == AudioRecorderStatus.stopped) {
      _levels = const [];
      return;
    }
    // The recorder advances progress on every sample it takes, so a
    // repeated level is still a sample.
    if (widget.state.status == AudioRecorderStatus.recording &&
        widget.state.progress != oldWidget.state.progress) {
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
    final bars = RecordingLevelLine.barsOf(_levels);
    return LayoutBuilder(
      builder: (context, constraints) => ShaderMask(
        // The line fades in at its oldest end only, so it reads as time
        // passing towards *now* — the newest bars at full strength.
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) =>
            RecordingLevelLine.fadeOf(tokens).createShader(bounds),
        child: LiveWaveform(
          key: const ValueKey('recording-visualizer-bars'),
          amplitudes: bars,
          barCount: RecordingLevelLine.barCount,
          width: constraints.maxWidth
              .clamp(0, RecordingLevelLine.widthFor(modern: modern))
              .toDouble(),
          height: tokens.spacing.step6,
          color: modern
              ? tokens.colors.interactive.enabled
              : tokens.colors.text.highEmphasis,
          baselineColor: tokens.colors.decorative.level02,
          // The rings' border weight: one hairline across the recorder.
          baselineWidth: tokens.spacing.step1 / 2,
        ),
      ),
    );
  }
}

/// An option under the recorder — its name in the recorder's caption
/// voice, then a small toggle, the whole row one tap — quiet enough that it
/// never competes with the take.
class RecordingOption extends StatelessWidget {
  const RecordingOption({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ExcludeSemantics(
              child: Text(label, style: recordingCaptionStyle(tokens)),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemToggle(
            value: value,
            onChanged: onChanged,
            semanticsLabel: label,
          ),
        ],
      ),
    );
  }
}

/// The transport row: discard ✕ and pause ⏸ / resume ▶ as quiet rings on
/// either side of the red Stop pill that carries the running time — the
/// only colour in the row, the one way a take becomes an entry. Every action is inert while [busy] — a
/// stop or discard already on its way — and the host decides what each one
/// means (whether discarding asks first, where a stopped take goes).
class RecordingTransportControls extends StatelessWidget {
  const RecordingTransportControls({
    required this.paused,
    required this.progress,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onStop,
    this.progressSemanticsLabel,
    this.busy = false,
    this.discardLabel,
    this.discardKey = const ValueKey('cancel_recording'),
    this.pauseKey = const ValueKey('pause_resume_button'),
    this.stopKey = const ValueKey('stop_recording'),
    super.key,
  });

  final bool paused;

  /// How long the take has run, shown in the Stop pill.
  final Duration progress;

  /// That time as a screen reader hears it, when the host has the words;
  /// the digits otherwise.
  final String? progressSemanticsLabel;
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
        _StopPill(
          key: stopKey,
          progress: progress,
          progressSemanticsLabel: progressSemanticsLabel,
          onTap: busy ? null : onStop,
        ),
        _RoundControl(
          key: pauseKey,
          label: paused
              ? messages.audioRecordingResume
              : messages.audioRecordingPause,
          icon: paused ? LottiIconsFilled.play : LottiIconsFilled.pause,
          onTap: busy ? null : onTogglePause,
        ),
      ],
    );
  }
}

/// [tap], felt as [haptic] first when the user has haptics on; null stays
/// null, so an inert control stays inert.
VoidCallback? _felt(
  WidgetRef ref,
  VoidCallback? tap,
  Future<void> Function() haptic,
) {
  if (tap == null) return null;
  return () {
    if (ref.read(celebrationPreferencesProvider).haptics) {
      // Best effort, and never in the tap's way: a device without a motor
      // has nothing to report.
      haptic().ignore();
    }
    tap();
  };
}

/// Fades a control to the design system's disabled alpha while it takes no
/// tap, and names it as one button.
class _Control extends ConsumerWidget {
  const _Control({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final tap = onTap;
    // The control's own node outermost, so it is one button by its name;
    // the tooltip only shows that name to a pointer.
    return Semantics(
      button: true,
      enabled: tap != null,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _felt(ref, tap, HapticFeedback.lightImpact),
          child: AnimatedOpacity(
            opacity: tap != null ? 1 : tokens.colors.text.lowEmphasis.a,
            duration: MotionDurations.short4,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A quiet 48px ring — a border, no fill — the whole of it tappable.
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

/// Stop: the app's running-clock pill, red with the elapsed time beside its
/// stop square — the element a task's Track time wears while it runs. Here
/// the whole pill stops the take, so it is one button, named *Stop*, whose
/// value is the time.
class _StopPill extends ConsumerWidget {
  const _StopPill({
    required this.progress,
    required this.progressSemanticsLabel,
    required this.onTap,
    super.key,
  });

  final Duration progress;
  final String? progressSemanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final stop = _felt(ref, onTap, HapticFeedback.mediumImpact);
    final time = DesignSystemTimerPill.formatElapsed(progress);
    final label = context.messages.audioRecordingStop;
    final value = progressSemanticsLabel ?? time;
    // The button node outermost, on the host's key, as the rings have it.
    return Semantics(
      button: true,
      enabled: stop != null,
      label: label,
      value: value,
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: stop != null ? 1 : tokens.colors.text.lowEmphasis.a,
        duration: MotionDurations.short4,
        child: DesignSystemTimerPill(
          running: true,
          label: time,
          // Room for the widest time under the hour, so the pill — and the
          // rings beside it — hold still as the minutes grow.
          widthLabel: DesignSystemTimerPill.elapsedWidthTemplate,
          semanticLabel: label,
          semanticValue: value,
          onTap: stop,
          onStop: stop,
        ),
      ),
    );
  }
}
