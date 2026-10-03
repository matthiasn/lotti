import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
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
class GlassRecordButton extends ConsumerWidget {
  const GlassRecordButton({
    required this.linkedId,
    required this.onPressed,
    super.key,
  });

  /// The task or entry whose recordings light this button up.
  final String linkedId;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isRecording = ref.watch(
      audioRecorderControllerProvider.select(
        (state) => state.isActiveSessionFor(linkedId),
      ),
    );

    return DsGlassRoundButton(
      icon: LottiIcons.mic,
      semanticLabel: isRecording
          ? messages.taskActionBarAudioRecordingActive
          : messages.taskFirstRunRecordAudio,
      onPressed: onPressed,
      backgroundColor: isRecording
          ? tokens.colors.alert.error.defaultColor
          : null,
      outlineColor: isRecording ? null : tokens.colors.interactive.enabled,
      iconColor: isRecording ? Colors.white : tokens.colors.interactive.enabled,
    );
  }
}
