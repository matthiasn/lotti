import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_orb_palette.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_levels.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/features/speech/ui/widgets/recording/live_waveform.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The app's one recorder anatomy, shared by every surface that records —
/// the recording sheet a task's microphone opens, and the check-in
/// composer and page that record in place: the level visualizer the user
/// chose, the running clock, and the transport row (discard ✕, pause ⏸,
/// the red Stop). A recorder that drew its own buttons read as another
/// app's recorder however carefully it was spaced.

/// The level display, per the persisted [RecordingStyle], as the pair the
/// user chose it from in onboarding: the voice orb over accent level bars
/// for [RecordingStyle.modern], the analog VU meter over neutral bars
/// otherwise — including while the preference is still loading, so the
/// meter never flashes to the orb and back on the first frame. The bars
/// keep a short history of the live level, so a take reads as speech over
/// time, not only as a level now; while paused they hold still.
class RecordingLevelVisualizer extends ConsumerStatefulWidget {
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

  /// How many level samples the bars keep — two per bar, so the strip
  /// moves smoothly without each 20 ms sample jolting it.
  static const int levelWindow = 56;

  final AudioRecorderState state;
  final double orbSize;

  /// The meter's width; it never grows past the space it is given.
  final double meterWidth;

  @override
  ConsumerState<RecordingLevelVisualizer> createState() =>
      _RecordingLevelVisualizerState();
}

class _RecordingLevelVisualizerState
    extends ConsumerState<RecordingLevelVisualizer> {
  List<double> _levels = const [];

  @override
  void didUpdateWidget(covariant RecordingLevelVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A sample per level change while the take runs; a paused take keeps
    // its last stretch on screen rather than draining to a flat line.
    if (widget.state.status == AudioRecorderStatus.recording &&
        widget.state.dBFS != oldWidget.state.dBFS) {
      final next = [..._levels, normaliseDbfs(widget.state.dBFS)];
      _levels = next.length > RecordingLevelVisualizer.levelWindow
          ? next.sublist(next.length - RecordingLevelVisualizer.levelWindow)
          : next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final style = ref.watch(recordingStyleProvider).asData?.value;
    final modern = style == RecordingStyle.modern;
    final Widget primary;
    if (modern) {
      primary = AiVoiceInputShader(
        key: const ValueKey('recording-visualizer-orb'),
        dbfs: widget.state.dBFS,
        size: widget.orbSize,
        intensity: 1,
        palette: AiVoiceOrbPalette.fromTokens(tokens),
      );
    } else {
      primary = LayoutBuilder(
        builder: (context, constraints) => AnalogVuMeter(
          key: const ValueKey('recording-visualizer-meter'),
          vu: widget.state.vu,
          dBFS: widget.state.dBFS,
          // Clamping an unbounded width lands on the meter's own.
          size: constraints.maxWidth.clamp(0, widget.meterWidth).toDouble(),
          colorScheme: Theme.of(context).colorScheme,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        primary,
        // The orb's canvas already holds its own air around the ring — the
        // shader crops well inside its square — so the bars sit straight
        // under it; the meter fills its box and takes a step.
        if (!modern) SizedBox(height: tokens.spacing.step4),
        // Onboarding's own pairing: the accent under the orb, the neutral
        // ink under the meter.
        LiveWaveform(
          key: const ValueKey('recording-visualizer-bars'),
          amplitudes: _levels,
          color: modern
              ? tokens.colors.interactive.enabled
              : tokens.colors.text.highEmphasis,
        ),
        // The clock that every host sets under the display reads as its own
        // line, not the bars' caption: a full step, as below the clock.
        SizedBox(height: tokens.spacing.step4),
      ],
    );
  }
}

/// The running time, `0:00:42`, in the accent's monospace — the recording
/// sheet's clock, so a glance from one recorder to another finds it in the
/// same face and colour.
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
      style: monoMetaStyle(
        tokens,
        tokens.colors,
        // A step under the page titles: the clock reads the take, it does
        // not headline the sheet over the orb.
        base: tokens.typography.styles.heading.heading3.copyWith(
          fontWeight: tokens.typography.weight.regular,
        ),
        // The accent on a dark sheet; on a light one the neutral ink, so
        // the teal is left to the live parts — the orb and its bars.
        color: AiVoiceOrbPalette.fromTokens(tokens).onLightSurface
            ? tokens.colors.text.highEmphasis
            : tokens.colors.interactive.enabled,
      ),
    );
  }
}

/// The transport row: discard ✕, pause ⏸ / resume ▶, and the red Stop
/// pill. Every action is inert while [busy] — a stop or discard already on
/// its way — and the host decides what each one means (whether discarding
/// asks first, where a stopped take goes).
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
    final pauseLabel = paused
        ? messages.audioRecordingResume
        : messages.audioRecordingPause;
    // Wraps rather than overflows: on a narrow phone or at a large text
    // size Stop takes a line of its own instead of leaving the screen.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step4,
      runSpacing: tokens.spacing.step3,
      children: [
        // Grey and round: the destructive act is the quiet one, so a
        // fumbled pause can never read as a discard.
        _RoundControl(
          key: discardKey,
          label: discardLabel ?? messages.audioRecordingCancel,
          icon: LottiIcons.close,
          ink: tokens.colors.text.mediumEmphasis,
          border: tokens.colors.decorative.level02,
          onTap: busy ? null : onDiscard,
        ),
        // Accent-tinted: a benign transport control.
        _RoundControl(
          key: pauseKey,
          label: pauseLabel,
          icon: paused ? LottiIcons.play : LottiIcons.pause,
          ink: tokens.colors.interactive.enabled,
          border: tokens.colors.interactive.enabled,
          fill: tokens.colors.surface.selected,
          onTap: busy ? null : onTogglePause,
        ),
        _StopPill(key: stopKey, onTap: busy ? null : onStop),
      ],
    );
  }
}

/// A 48px ring, the whole of it tappable.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.label,
    required this.icon,
    required this.ink,
    required this.border,
    required this.onTap,
    this.fill,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color ink;
  final Color border;
  final Color? fill;
  final VoidCallback? onTap;

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
            child: Container(
              width: tokens.spacing.step9,
              height: tokens.spacing.step9,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: AnimatedSwitcher(
                duration: MotionDurations.short4,
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: IconSizes.l,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The red Stop: the one way a take becomes an entry, so it is the row's
/// widest control, with the live dot inside it.
class _StopPill extends StatelessWidget {
  const _StopPill({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final red = tokens.colors.alert.error.defaultColor;
    final label = context.messages.audioRecordingStop;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : tokens.colors.text.lowEmphasis.a,
          duration: MotionDurations.short4,
          child: Container(
            // A floor, not a fixed height: a large text size grows the pill
            // rather than clipping its word.
            constraints: BoxConstraints(minHeight: tokens.spacing.step9),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step7,
              vertical: tokens.spacing.step2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              border: Border.all(color: red, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: tokens.spacing.step3,
                  height: tokens.spacing.step3,
                  decoration: BoxDecoration(color: red, shape: BoxShape.circle),
                ),
                SizedBox(width: tokens.spacing.step3),
                // Shrinks before it overflows, on a screen narrower than
                // the pill at its text size.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
