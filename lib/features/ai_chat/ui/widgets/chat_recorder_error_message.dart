import 'package:flutter/widgets.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_recorder_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The localized reason to show the user when a voice capture failed.
///
/// Every AI-assisted input surface shares one recorder, so they share this
/// mapping too: a denied microphone, a missing transcription model and a
/// failed request are three different problems with three different fixes,
/// and a single "Recording failed" toast for all of them tells the user
/// nothing they can act on. The diagnostic English in
/// [ChatRecorderState.error] stays in the log; this is what reaches the UI.
String chatRecorderErrorMessage(
  BuildContext context,
  ChatRecorderErrorKind? kind,
) {
  final messages = context.messages;
  return switch (kind) {
    ChatRecorderErrorKind.permissionDenied =>
      messages.chatInputRecordingNoMicPermission,
    ChatRecorderErrorKind.noAudioModel =>
      messages.chatInputRecordingNoAudioModel,
    ChatRecorderErrorKind.transcriptionFailed =>
      messages.chatInputTranscriptionFailed,
    ChatRecorderErrorKind.noAudioFile => messages.chatInputNoAudioRecorded,
    // Busy and start failures are transient: the generic retry line is the
    // honest thing to say about them.
    ChatRecorderErrorKind.busy ||
    ChatRecorderErrorKind.startFailed ||
    null => messages.chatInputRecordingFailed,
  };
}
