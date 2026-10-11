import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The app's one recorder anatomy, shared by every surface that records —
/// the recording sheet a task's microphone opens, and the check-in
/// composer and page that record in place: the level visualizer the user
/// chose, the running clock, and the transport row (discard ✕, pause ⏸,
/// the red Stop). A recorder that drew its own buttons read as another
/// app's recorder however carefully it was spaced.

/// The primary level visualizer, per the persisted [RecordingStyle]: the
/// voice orb for [RecordingStyle.modern], the analog VU meter otherwise —
/// including while the preference is still loading, so the meter never
/// flashes to the orb and back on the first frame.
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
    final style = ref.watch(recordingStyleProvider).asData?.value;
    if (style == RecordingStyle.modern) {
      final tokens = context.designTokens;
      return AiVoiceInputShader(
        key: const ValueKey('recording-visualizer-orb'),
        dbfs: state.dBFS,
        size: orbSize,
        intensity: 1,
        primaryColor: tokens.colors.interactive.enabled,
        secondaryColor: tokens.colors.text.highEmphasis,
        backgroundColor: Colors.transparent,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => AnalogVuMeter(
        key: const ValueKey('recording-visualizer-meter'),
        vu: state.vu,
        dBFS: state.dBFS,
        size: constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(0, meterWidth).toDouble()
            : meterWidth,
        colorScheme: Theme.of(context).colorScheme,
      ),
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
        base: tokens.typography.styles.heading.heading2.copyWith(
          fontWeight: tokens.typography.weight.regular,
        ),
        color: tokens.colors.interactive.enabled,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        SizedBox(width: tokens.spacing.step4),
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
        SizedBox(width: tokens.spacing.step4),
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
            height: tokens.spacing.step9,
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step7),
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
                Text(
                  label,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: red,
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
