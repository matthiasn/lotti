import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Shows an error toast when the utterance [sourceId] fails.
///
/// The voice never throws to its caller: a failed synthesis or playback
/// turns the playback state to error. So a host that asks the voice to speak
/// calls this from its `build`, as it would `ref.listen`, and the toast
/// appears once per failure, only for its own utterance.
void listenForPlaybackFailure(
  WidgetRef ref,
  BuildContext context,
  String sourceId,
) {
  ref.listen(ttsPlaybackControllerProvider, (previous, next) {
    if (next.status == TtsPlaybackStatus.error &&
        next.sourceId == sourceId &&
        previous?.status != TtsPlaybackStatus.error) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.commonError,
        clearQueue: true,
      );
    }
  });
}
