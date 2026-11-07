import 'package:flutter/services.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the recording pill's controls.
abstract final class ChatRecordingPillKeys {
  static const Key pill = Key('chat-recording-pill');
  static const Key cancel = Key('chat-recording-cancel');
  static const Key stop = Key('chat-recording-stop');
  static const Key elapsed = Key('chat-recording-elapsed');
  static const Key waveform = Key('chat-recording-waveform');
  static const Key transcribing = Key('chat-recording-transcribing');
}

/// The composer while the microphone is live — in every agent chat, and on
/// the companion's stage.
///
/// It is the pill the text field is, at the field's height, fill and
/// corners, so nothing jumps as recording starts; its teal edge is the
/// field's focused one, saying the microphone is on. Cancel (×) leads; then
/// the elapsed time behind a recording dot and the voice scrolling across
/// as bars, newest at the right; at the end the round control that ends it
/// — the send arrow when stopping sends what was said ([sendsOnStop]), a
/// stop square when it only transcribes into the field.
///
/// While [processing] (transcribing) the time and bars give way to
/// *Transcribing…* and a quiet spinner takes the end control's place; the
/// teal edge, which says the microphone is on, goes, and cancel stays, so a
/// stalled turn always has its way out. Escape cancels too.
///
/// Teal is for what to do (the end control), red for live (the dot), and
/// the voice itself is quiet ink, so the send stays the one thing that
/// leads.
class ChatRecordingPill extends StatelessWidget {
  const ChatRecordingPill({
    required this.processing,
    required this.amplitudes,
    required this.elapsed,
    required this.onCancel,
    required this.onStop,
    this.sendsOnStop = false,
    this.showEndControl = true,
    super.key,
  });

  final bool processing;

  /// What it heard, levels in `0..1`, oldest first.
  final List<double> amplitudes;
  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  /// Whether stopping sends what was said: the end control is then the send
  /// arrow, as the text field's is.
  final bool sendsOnStop;

  /// Whether the pill carries the control that ends it. A host whose own
  /// control ends it — the companion's talk disc — leaves it out, so there
  /// is one send on screen; the slot keeps its width either way.
  final bool showEndControl;

  /// `m:ss`, the way a voice note's length reads.
  static String formatElapsed(Duration elapsed) =>
      '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // The text field's own height — a whole tap target, so each end of the
    // pill is one — and its send button's diameter.
    final height = tokens.spacing.step9;
    final disc = height - tokens.spacing.step2 * 2;
    final gap = SizedBox(width: tokens.spacing.step2);
    final quiet = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    final Widget end = !showEndControl
        ? SizedBox.square(dimension: height)
        : processing
        ? SizedBox.square(
            dimension: height,
            child: Center(
              // Quiet ink: a wait, not something to tap.
              child: DesignSystemSpinner(
                key: ChatRecordingPillKeys.transcribing,
                style: DesignSystemSpinnerStyle.plain,
                size: IconSizes.m,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          )
        : SizedBox.square(
            dimension: height,
            // Centred, so the slot's tight square leaves the disc its own
            // size inside the pill's edge.
            child: Center(
              child: IconButton(
                key: ChatRecordingPillKeys.stop,
                tooltip: sendsOnStop
                    ? messages.chatInputSendTooltip
                    : messages.chatInputStopTranscribe,
                style: IconButton.styleFrom(
                  backgroundColor: tokens.colors.interactive.enabled,
                  foregroundColor: tokens.colors.text.onInteractiveAlert,
                  fixedSize: Size.square(disc),
                  minimumSize: Size.square(disc),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  sendsOnStop ? LottiIcons.arrowUp : LottiIcons.stop,
                  size: IconSizes.s,
                ),
                onPressed: onStop,
              ),
            ),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onCancel,
      },
      child: Focus(
        autofocus: true,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: processing
              ? messages.timelineTranscribing
              : messages.chatInputListening,
          child: Container(
            key: ChatRecordingPillKeys.pill,
            height: height,
            decoration: BoxDecoration(
              color: tokens.colors.surface.enabled,
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
            ),
            // Painted over, not laid out: an edge inside the box would take
            // its width from the controls' whole tap targets.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              border: Border.all(
                color: designSystemFieldBorderColor(
                  tokens,
                  focused: !processing,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: height,
                  child: IconButton(
                    key: ChatRecordingPillKeys.cancel,
                    tooltip: messages.chatInputCancelRecording,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      LottiIcons.close,
                      size: IconSizes.s,
                      color: tokens.colors.text.highEmphasis,
                    ),
                    onPressed: onCancel,
                  ),
                ),
                gap,
                if (processing)
                  Expanded(
                    child: Text(
                      messages.timelineTranscribing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: quiet,
                    ),
                  )
                else ...[
                  // The recording dot: the microphone is on.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.colors.alert.error.defaultColor,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: tokens.spacing.step3),
                  ),
                  gap,
                  Text(
                    formatElapsed(elapsed),
                    key: ChatRecordingPillKeys.elapsed,
                    // The status line's one style, in either state.
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: ExcludeSemantics(
                      child: LayoutBuilder(
                        builder: (context, constraints) => CustomPaint(
                          key: ChatRecordingPillKeys.waveform,
                          size: Size(
                            constraints.maxWidth,
                            tokens.spacing.step6,
                          ),
                          painter: WaveformBarsPainter(
                            amplitudes: amplitudes,
                            barWidth: tokens.spacing.step1,
                            barSpacing: tokens.spacing.step1,
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(width: tokens.spacing.step3),
                end,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
