import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:material_ui/material_ui.dart';

/// The recorder embedded in the check-in composer's narrative field, the
/// *Speak* sheet and the check-in page's action bar: the app's shared
/// [InlineRecorder] — the one a goal's check-in records with too — reporting
/// failures in the composer's own kinds, so each host can draw the right
/// card rather than a toast.
///
/// It starts recording the moment it is mounted — the user already pressed
/// *Dictate* — and never takes over a take running for someone else: that
/// comes back as [CheckInSpeechFailureKind.recorderBusy]. See
/// [InlineRecorder] for the recorder's contract, including what being
/// unmounted mid-take means.
class CheckInInlineRecorder extends StatelessWidget {
  const CheckInInlineRecorder({
    required this.linkedId,
    required this.onRecorded,
    required this.onDiscarded,
    required this.onFailed,
    this.categoryId,
    this.compact = false,
    this.showStatus = false,
    super.key,
  });

  /// The person the recording is linked to.
  final String linkedId;

  /// Their category, so the audio entry files where their other entries do.
  final String? categoryId;

  final void Function(String audioEntryId, Duration length) onRecorded;
  final VoidCallback onDiscarded;
  final void Function(CheckInSpeechFailureKind failure) onFailed;

  /// Whether to leave the orb or meter out, as the check-in page's dock
  /// does, so dictating never covers the check-in it adds to.
  final bool compact;

  /// Whether the recorder says *Recording* / *Paused* itself — the page's
  /// dock, which has no header of its own; the composer's header says it
  /// there.
  final bool showStatus;

  @override
  Widget build(BuildContext context) => InlineRecorder(
    linkedId: linkedId,
    categoryId: categoryId,
    compact: compact,
    showStatus: showStatus,
    onRecorded: onRecorded,
    onDiscarded: onDiscarded,
    onFailed: (failure) => onFailed(switch (failure) {
      InlineRecordingFailure.microphoneDenied =>
        CheckInSpeechFailureKind.microphoneDenied,
      InlineRecordingFailure.startFailed =>
        CheckInSpeechFailureKind.recordingFailed,
      InlineRecordingFailure.recorderBusy =>
        CheckInSpeechFailureKind.recorderBusy,
      InlineRecordingFailure.notSaved =>
        CheckInSpeechFailureKind.recordingNotSaved,
    }),
  );
}
