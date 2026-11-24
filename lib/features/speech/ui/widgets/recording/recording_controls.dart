import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_timer_pill.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_voice_waveform.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/entry_tools.dart';
import 'package:lotti/utils/recording_levels.dart';
import 'package:lotti/widgets/celebration/celebration_preferences_controller.dart';
import 'package:material_ui/material_ui.dart';

/// The app's one recorder, shared by every surface that records — the
/// recording strip's tray, and the check-in composer and page that record
/// in place. A recorder that drew its own parts read as
/// another app's recorder however carefully it was spaced.
///
/// Composed ([RecordingStage]) on one centred axis: the level line, the
/// running time inside the red Stop between the two quiet controls — the
/// app's one running-clock control, the pill a task's Track time wears —
/// and a footer in the recorder's small voice. Nothing else: the level line
/// is the only picture of the voice, here and in every dictation field.

/// The one small voice every line of words on the recorder speaks in — an
/// option, a failure.
TextStyle recordingCaptionStyle(DsTokens tokens) =>
    tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

/// The main line on the recording strip, its tray and its receipt — what a
/// take is for — one step above [recordingCaptionStyle].
TextStyle recordingTitleStyle(DsTokens tokens) =>
    tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

/// The whole recorder, top to bottom: the level line, the [controls] —
/// whose Stop carries the running time — and an optional [footer], in one
/// column as wide as the transport row, every gap a design-system step, so
/// each host reads the same.
class RecordingStage extends StatelessWidget {
  const RecordingStage({
    required this.state,
    required this.controls,
    this.levelSemanticsLabel,
    this.announceLevel = false,
    this.notice,
    this.footer,
    super.key,
  });

  final AudioRecorderState state;

  /// The transport row.
  final Widget controls;

  /// What a screen reader hears for the level line, which is a picture;
  /// nothing when null.
  final String? levelSemanticsLabel;

  /// Whether that label is a live region — where nothing else on the
  /// surface announces the take starting.
  final bool announceLevel;

  /// A line under the level line, such as the host's own status.
  final Widget? notice;

  /// What sits under the controls: an option.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.step5;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: announceLevel,
            label: levelSemanticsLabel,
            child: ExcludeSemantics(child: RecordingLevelLine(state: state)),
          ),
          if (notice case final notice?) ...[
            SizedBox(height: tokens.spacing.step3),
            notice,
          ],
          SizedBox(height: gap),
          controls,
          if (footer case final footer?) ...[
            SizedBox(height: gap),
            footer,
          ],
        ],
      ),
    );
  }
}

/// The level over the last stretch of the take: the app's one voice
/// waveform ([DesignSystemVoiceWaveform]) at the transport row's width, so
/// the line and the controls under it share their edges in every host. It
/// adds a level per recorder sample while the take runs — a steady level
/// too, so silence ages the loud bars out — holds still while paused, and
/// starts empty for each new take.
class RecordingLevelLine extends StatefulWidget {
  const RecordingLevelLine({required this.state, this.width, super.key});

  /// How many samples the line keeps: more than the transport row is ever
  /// wide.
  static const int levelWindow = 240;

  final AudioRecorderState state;

  /// How wide the line is drawn; the transport row's width when null. The
  /// recording strip gives it a short stretch of its own.
  final double? width;

  @override
  State<RecordingLevelLine> createState() => _RecordingLevelLineState();
}

class _RecordingLevelLineState extends State<RecordingLevelLine> {
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
    if (widget.state.status != AudioRecorderStatus.recording ||
        widget.state.progress == oldWidget.state.progress) {
      return;
    }
    final next = [..._levels, normaliseDbfs(widget.state.dBFS)];
    _levels = next.length > RecordingLevelLine.levelWindow
        ? next.sublist(next.length - RecordingLevelLine.levelWindow)
        : next;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('recording-visualizer-bars'),
    width: widget.width ?? RecordingTransportControls.rowWidth(context),
    child: DesignSystemVoiceWaveform(
      levels: _levels,
      sampleInterval: const Duration(milliseconds: intervalMs),
    ),
  );
}

/// The transport row: discard ✕, pause ⏸ / resume ▶, then the red Stop pill
/// that carries the running time — the only colour in the row, the one way a
/// take becomes an entry, grey while the take is paused. Stop comes last, as
/// on the recording strip, so it is in the same place on every recorder.
/// Every action is inert while [busy] — a stop or discard already on its
/// way — and the host decides what each one means (whether discarding asks
/// first, where a stopped take goes).
///
/// Centred at [rowWidth] by default; [spread] across the host's width —
/// discard at the start, pause and Stop at the end, where the recording
/// strip keeps them — so the tray opened from the strip has its controls
/// where the strip had them.
class RecordingTransportControls extends StatelessWidget {
  const RecordingTransportControls({
    required this.paused,
    required this.progress,
    required this.onDiscard,
    required this.onTogglePause,
    required this.onStop,
    this.progressSemanticsLabel,
    this.busy = false,
    this.spread = false,
    super.key,
  });

  final bool paused;

  /// Across the host's whole width rather than centred.
  final bool spread;

  /// How long the take has run, shown in the Stop pill.
  final Duration progress;

  /// That time as a screen reader hears it, when the host has the words;
  /// the digits otherwise.
  final String? progressSemanticsLabel;
  final bool busy;
  final VoidCallback onDiscard;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  static const Key discardKey = ValueKey('cancel_recording');
  static const Key pauseKey = ValueKey('pause_resume_button');
  static const Key stopKey = ValueKey('stop_recording');

  /// The row's width on one line: two rings, the Stop pill at its held
  /// width, and the gaps between them — the recorder's one measure.
  static double rowWidth(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return spacing.step9 * 2 +
        spacing.step6 * 2 +
        DesignSystemTimerPill.heldWidth(
          context,
          DesignSystemTimerPill.elapsedWidthTemplate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final discard = RecordingRingButton(
      key: discardKey,
      label: messages.checkInDiscardRecording,
      icon: LottiIcons.close,
      onTap: busy ? null : onDiscard,
    );
    final pause = RecordingRingButton(
      key: pauseKey,
      emphasized: paused,
      label: paused
          ? messages.audioRecordingResume
          : messages.audioRecordingPause,
      icon: paused ? LottiIconsFilled.play : LottiIconsFilled.pause,
      solid: true,
      onTap: busy ? null : onTogglePause,
    );
    final stop = RecordingStopPill(
      key: stopKey,
      paused: paused,
      progress: progress,
      progressSemanticsLabel: progressSemanticsLabel,
      onTap: busy ? null : onStop,
    );
    if (spread) {
      return Row(
        children: [
          discard,
          const Spacer(),
          pause,
          SizedBox(width: tokens.spacing.step3),
          stop,
        ],
      );
    }
    // Wraps rather than overflows on a very narrow screen at a large text
    // size; at any ordinary width it is one centred row.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: tokens.spacing.step6,
      runSpacing: tokens.spacing.step3,
      children: [discard, pause, stop],
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

/// A quiet 48px ring — a border, no fill — the whole of it tappable: the
/// recorder's discard and pause, here and on the recording strip.
/// [emphasized], it is the accent disc instead: resume, while a take is
/// paused and Stop has stepped back, is the one thing to press.
class RecordingRingButton extends StatelessWidget {
  const RecordingRingButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.solid = false,
    this.emphasized = false,
    super.key,
  });

  /// Whether the ring is the filled accent disc rather than a quiet ring.
  final bool emphasized;

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  /// Whether [icon] is a filled glyph rather than a stroked one.
  final bool solid;

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
          color: emphasized ? tokens.colors.interactive.enabled : null,
          border: emphasized
              ? null
              : Border.all(color: tokens.colors.decorative.level02),
        ),
        child: AnimatedSwitcher(
          duration: MotionDurations.short4,
          child: Icon(
            icon,
            key: ValueKey(icon),
            // A solid glyph carries more ink than a stroked one at the same
            // size: a step smaller, the two rings weigh the same.
            size: solid ? IconSizes.m : IconSizes.l,
            color: emphasized
                ? tokens.colors.text.onInteractiveAlert
                : tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}

/// Stop: the app's running-clock pill, red with the elapsed time beside its
/// stop square — the element a task's Track time wears while it runs, grey
/// while the take is paused. Here the whole pill stops the take, so it is
/// one button, named *Stop*, whose value is the time.
class RecordingStopPill extends ConsumerWidget {
  const RecordingStopPill({
    required this.paused,
    required this.progress,
    required this.progressSemanticsLabel,
    required this.onTap,
    super.key,
  });

  final bool paused;
  final Duration progress;
  final String? progressSemanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final stop = _felt(ref, onTap, HapticFeedback.mediumImpact);
    final time = formatElapsed(progress);
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
          paused: paused,
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
