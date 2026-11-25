import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The record button the sticky action bars carry — the task page's and the
/// entry page's — so the app's lead-action mic has one look, one active state
/// and one accessibility story.
///
/// Idle it wears the accent as a ring and as the glyph's ink over the glass
/// fill: a peer of the bar's filled primary (Track time, Add a task) rather
/// than one of the quiet utilities beside it, outlined rather than filled so
/// a strip still holds only one filled shape. While a recording session
/// linked to [linkedId] is in flight — recording or paused — it takes the
/// alert fill with a white glyph and announces the recording in progress
/// instead of offering one. A session linked elsewhere leaves it idle.
///
/// It watches that one boolean of the recorder's state and nothing else, so
/// the level and progress updates streaming through `AudioRecorderState`
/// during a recording rebuild neither this button nor the bar around it.
///
/// When the recording strip takes the user back to [linkedId], the button
/// swells once and settles, so the eye finds the take it came back to. Not
/// under reduced motion.
class GlassRecordButton extends ConsumerStatefulWidget {
  const GlassRecordButton({
    required this.linkedId,
    required this.onPressed,
    super.key,
  });

  /// The task or entry whose recordings light this button up.
  final String linkedId;

  final VoidCallback onPressed;

  /// How long the arrival highlight runs.
  static const Duration arrivalDuration = MotionDurations.long2;

  @override
  ConsumerState<GlassRecordButton> createState() => _GlassRecordButtonState();
}

class _GlassRecordButtonState extends ConsumerState<GlassRecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: GlassRecordButton.arrivalDuration,
  );

  /// Up a fifth and back, with the motion tokens' easing.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.2), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1), weight: 1),
  ]).animate(CurvedAnimation(parent: _arrival, curve: MotionCurves.standard));

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkedId = widget.linkedId;
    ref.listen(recordingArrivalProvider, (_, arrival) {
      if (arrival?.subjectId == linkedId &&
          !MediaQuery.disableAnimationsOf(context)) {
        _arrival.forward(from: 0);
      }
    });
    final tokens = context.designTokens;
    final messages = context.messages;
    final isRecording = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.isActiveSessionFor(linkedId),
      ),
    );

    return ScaleTransition(
      scale: _scale,
      child: DsGlassRoundButton(
        icon: LottiIcons.mic,
        semanticLabel: isRecording
            ? messages.taskActionBarAudioRecordingActive
            : messages.taskFirstRunRecordAudio,
        onPressed: widget.onPressed,
        backgroundColor: isRecording
            ? tokens.colors.alert.error.defaultColor
            : null,
        outlineColor: isRecording ? null : tokens.colors.interactive.enabled,
        iconColor: isRecording
            ? Colors.white
            : tokens.colors.interactive.enabled,
      ),
    );
  }
}
