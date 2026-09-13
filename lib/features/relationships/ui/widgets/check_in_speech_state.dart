import 'package:flutter/foundation.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';

/// Where a spoken check-in is, rendered *in place of* the narrative text
/// (design 2026-09-13, options 1a–1f): the composer never leaves the thing
/// the user is writing, so the recorder, the transcript wait and both
/// failure cards are phases of the one field rather than separate surfaces.
///
/// A pure model, so the decisions the composer makes from it — what the
/// field shows, what the header says, why Save is held — are table-testable
/// without a recorder, a microphone or the inference stack.
@immutable
sealed class CheckInSpeechPhase {
  const CheckInSpeechPhase();
}

/// Typing, or nothing yet: the field is text with *Dictate* inside it.
class CheckInSpeechIdle extends CheckInSpeechPhase {
  const CheckInSpeechIdle();
}

/// The preflight — can anything transcribe, which category is the person
/// in — before the recorder appears.
class CheckInSpeechPreparing extends CheckInSpeechPhase {
  const CheckInSpeechPreparing();
}

/// The inline recorder has replaced the text (option 1b / 2b).
class CheckInSpeechRecording extends CheckInSpeechPhase {
  const CheckInSpeechRecording();
}

/// The recording is saved and its transcript is on its way (option 1c).
class CheckInSpeechTranscribing extends CheckInSpeechPhase {
  const CheckInSpeechTranscribing({
    required this.audioEntryId,
    required this.length,
    this.route,
  });

  /// The journal audio entry the words will land on.
  final String audioEntryId;

  /// How long the recording ran — what the saved-audio line quotes.
  final Duration length;

  /// `model · via provider`, when the transcription service could name it.
  final String? route;
}

/// The words landed as ordinary editable text (option 1d). Remembers what
/// was appended, and what the field held before, so *Re-record* can take
/// exactly that back out again — and only if nothing has been edited.
class CheckInSpeechReady extends CheckInSpeechPhase {
  const CheckInSpeechReady({
    required this.transcript,
    required this.textBefore,
    required this.length,
  });

  final String transcript;

  /// The field's text before the transcript was merged in.
  final String textBefore;
  final Duration length;
}

/// Something stopped the words from arriving; the card says what and
/// offers the way out (options 1e / 1f).
class CheckInSpeechFailed extends CheckInSpeechPhase {
  const CheckInSpeechFailed(this.failure);

  final CheckInSpeechFailure failure;
}

/// What went wrong, in the terms the user needs: whether anything was
/// recorded, and whether a retry means recording again or only asking for
/// the transcript again.
enum CheckInSpeechFailureKind {
  /// The OS refused the microphone. Nothing was recorded.
  microphoneDenied,

  /// The recorder could not start. Nothing was recorded.
  recordingFailed,

  /// The recorder ran but could not be stopped and saved. The take is lost.
  recordingNotSaved,

  /// The app-wide recorder is busy with a recording that is not this
  /// person's — started elsewhere, or for someone else. Nothing new was
  /// recorded; it has to be stopped from the recording indicator first.
  recorderBusy,

  /// No default inference profile carries a transcription slot. Nothing
  /// was recorded — the preflight stops before the microphone.
  transcriptionUnavailable,

  /// The recording is saved, the transcript never came. *Try again* asks
  /// for the transcript of the same recording.
  transcriptMissing,
}

/// A failed spoken check-in: the kind, and — when a recording exists — the
/// entry to retry against and the length the card quotes.
@immutable
class CheckInSpeechFailure {
  const CheckInSpeechFailure(
    this.kind, {
    this.audioEntryId,
    this.length,
    this.detail,
  }) : assert(
         kind != CheckInSpeechFailureKind.transcriptMissing ||
             audioEntryId != null,
         'a missing transcript needs the recording to retry against',
       );

  /// Maps the recorder's typed refusal onto the composer's vocabulary.
  /// [AudioRecordingFailure.busy] — another recording already running — is
  /// a start that did not happen, so it reads as a failed start.
  factory CheckInSpeechFailure.fromRecorder(AudioRecordingFailure failure) =>
      switch (failure) {
        AudioRecordingFailure.permissionDenied => const CheckInSpeechFailure(
          CheckInSpeechFailureKind.microphoneDenied,
        ),
        AudioRecordingFailure.startFailed ||
        AudioRecordingFailure.busy => const CheckInSpeechFailure(
          CheckInSpeechFailureKind.recordingFailed,
        ),
      };

  final CheckInSpeechFailureKind kind;
  final String? audioEntryId;
  final Duration? length;

  /// The provider's own words about the failure, when it left any.
  final String? detail;

  /// Whether audio exists in the journal for this failure — the card then
  /// says so, because the check-in being cancelled does not delete it.
  bool get hasRecording => audioEntryId != null;

  @override
  bool operator ==(Object other) =>
      other is CheckInSpeechFailure &&
      other.kind == kind &&
      other.audioEntryId == audioEntryId &&
      other.length == length &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, audioEntryId, length, detail);
}

/// Why Save is held, so the action bar can say so instead of going quiet
/// (design 2026-09-13: "its disabled state says why").
enum CheckInSaveBlock {
  /// Save is allowed.
  none,

  /// The recorder preflight is running.
  preparing,

  /// The recorder is up; stop it first.
  recording,

  /// The transcript is in flight.
  transcribing,

  /// Nothing to save yet.
  emptyNarrative,

  /// Nothing to save yet, and a transcript retry is on offer.
  typeOrRetry,

  /// A save is already in flight.
  saving,
}

/// The one rule for whether a check-in can be saved right now. A check-in
/// is user-authored (ADR 0038), and the composer's whole premise is that a
/// few words are enough — so words are what it waits for, never a type or
/// a duration.
CheckInSaveBlock checkInSaveBlockOf({
  required CheckInSpeechPhase phase,
  required bool hasWords,
  required bool saving,
}) {
  if (saving) return CheckInSaveBlock.saving;
  return switch (phase) {
    CheckInSpeechPreparing() => CheckInSaveBlock.preparing,
    CheckInSpeechRecording() => CheckInSaveBlock.recording,
    CheckInSpeechTranscribing() => CheckInSaveBlock.transcribing,
    CheckInSpeechIdle() || CheckInSpeechReady() =>
      hasWords ? CheckInSaveBlock.none : CheckInSaveBlock.emptyNarrative,
    CheckInSpeechFailed(:final failure) => switch ((hasWords, failure.kind)) {
      (true, _) => CheckInSaveBlock.none,
      (false, CheckInSpeechFailureKind.transcriptMissing) =>
        CheckInSaveBlock.typeOrRetry,
      (false, _) => CheckInSaveBlock.emptyNarrative,
    },
  };
}

/// Words in the narrative — whitespace-separated runs, so `"a  b\n c"` is
/// three and a field of spaces is none.
int checkInWordCount(String text) =>
    text.trim().isEmpty ? 0 : RegExp(r'\S+').allMatches(text).length;

/// `h:mm:ss` for a recording's running time and `m:ss` for a finished
/// length under an hour — the tabular figures the recorder's timer and the
/// duration chip both use, so `0:23` on the chip is the `0:00:23` the timer
/// stopped on.
String checkInClockLabel(Duration length, {bool alwaysHours = false}) {
  final total = length.inSeconds.clamp(0, 1 << 31);
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0 || alwaysHours) return '$hours:$mm:$ss';
  return '$minutes:$ss';
}

/// What the composer's header says on its second line while speech is in
/// flight — the phase, sharpened by whether the recorder is paused.
enum CheckInComposerStatus {
  idle,
  preparing,
  recording,
  paused,
  transcribing,
  transcriptMissing,
  transcriptionUnavailable,
  microphoneDenied,
  recordingFailed,
  recordingNotSaved,
  recorderBusy,
}

/// The header status for a [phase]; [recorderPaused] only matters while
/// recording.
CheckInComposerStatus checkInComposerStatusOf(
  CheckInSpeechPhase phase, {
  required bool recorderPaused,
}) => switch (phase) {
  CheckInSpeechIdle() || CheckInSpeechReady() => CheckInComposerStatus.idle,
  CheckInSpeechPreparing() => CheckInComposerStatus.preparing,
  CheckInSpeechRecording() =>
    recorderPaused
        ? CheckInComposerStatus.paused
        : CheckInComposerStatus.recording,
  CheckInSpeechTranscribing() => CheckInComposerStatus.transcribing,
  CheckInSpeechFailed(:final failure) => switch (failure.kind) {
    CheckInSpeechFailureKind.microphoneDenied =>
      CheckInComposerStatus.microphoneDenied,
    CheckInSpeechFailureKind.recordingFailed =>
      CheckInComposerStatus.recordingFailed,
    CheckInSpeechFailureKind.recordingNotSaved =>
      CheckInComposerStatus.recordingNotSaved,
    CheckInSpeechFailureKind.recorderBusy => CheckInComposerStatus.recorderBusy,
    CheckInSpeechFailureKind.transcriptionUnavailable =>
      CheckInComposerStatus.transcriptionUnavailable,
    CheckInSpeechFailureKind.transcriptMissing =>
      CheckInComposerStatus.transcriptMissing,
  },
};
