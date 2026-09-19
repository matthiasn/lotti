import 'package:flutter/foundation.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Where the composer's recorder is (design 2026-09-13, options 1a–1f),
/// rendered *in place of* the narrative text while it records: the composer
/// never leaves the thing the user is writing.
///
/// What a finished recording is waiting for is not a phase of the field but
/// of the recording itself — a [CheckInTake] — because each recording is
/// its own entry of the check-in (ADR 0062) and the words land on it, not
/// in the note.
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

/// The recorder could not record; the card says why and offers the way out
/// (option 1f).
class CheckInSpeechFailed extends CheckInSpeechPhase {
  const CheckInSpeechFailed(this.failure);

  final CheckInSpeechFailure failure;
}

/// Why nothing was recorded, in the terms the user needs.
enum CheckInSpeechFailureKind {
  /// The OS refused the microphone.
  microphoneDenied,

  /// The recorder could not start.
  recordingFailed,

  /// The recorder ran but could not be stopped and saved. The take is lost.
  recordingNotSaved,

  /// The app-wide recorder is busy with a recording that is not this
  /// person's — started elsewhere, or for someone else. It has to be
  /// stopped from the recording indicator first.
  recorderBusy,

  /// No default inference profile carries a transcription slot — the
  /// preflight stops before the microphone.
  transcriptionUnavailable,
}

/// A recording that did not happen, and why.
@immutable
class CheckInSpeechFailure {
  const CheckInSpeechFailure(this.kind);

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

  @override
  bool operator ==(Object other) =>
      other is CheckInSpeechFailure && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}

/// Where a take's words are.
enum CheckInTakeWords {
  /// Asked for, not arrived. Saving does not wait: they land on the
  /// recording, and the check-in's briefing catches up when they do.
  transcribing,

  /// Arrived; the composer shows them as the take's preview.
  heard,

  /// The run ended without words. *Try again* asks for the same
  /// recording's words once more.
  missing,
}

/// One recording made in the composer. Saving the check-in makes it one
/// of the check-in's entries (ADR 0062); its words land on the recording,
/// never in the note, so the agent reads them once.
@immutable
class CheckInTake {
  const CheckInTake({
    required this.audioEntryId,
    required this.length,
    this.words = CheckInTakeWords.transcribing,
    this.transcript,
    this.route,
    this.detail,
  });

  /// The journal audio entry — what the check-in will hold.
  final String audioEntryId;

  /// How long the recording ran.
  final Duration length;
  final CheckInTakeWords words;

  /// The words, once [words] is [CheckInTakeWords.heard].
  final String? transcript;

  /// `model · via provider`, when the transcription service could name it.
  final String? route;

  /// The provider's own words about a missing transcript, when it left any.
  final String? detail;

  CheckInTake transcribing() =>
      CheckInTake(audioEntryId: audioEntryId, length: length, route: route);

  CheckInTake withRoute(String route) => CheckInTake(
    audioEntryId: audioEntryId,
    length: length,
    words: words,
    transcript: transcript,
    route: route,
    detail: detail,
  );

  CheckInTake heard(String transcript) => CheckInTake(
    audioEntryId: audioEntryId,
    length: length,
    words: CheckInTakeWords.heard,
    transcript: transcript,
    route: route,
  );

  CheckInTake missing(String? detail) => CheckInTake(
    audioEntryId: audioEntryId,
    length: length,
    words: CheckInTakeWords.missing,
    route: route,
    detail: detail,
  );

  @override
  bool operator ==(Object other) =>
      other is CheckInTake &&
      other.audioEntryId == audioEntryId &&
      other.length == length &&
      other.words == words &&
      other.transcript == transcript &&
      other.route == route &&
      other.detail == detail;

  @override
  int get hashCode =>
      Object.hash(audioEntryId, length, words, transcript, route, detail);
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

  /// Nothing to save yet: no words and no recording.
  emptyNarrative,

  /// A save is already in flight.
  saving,
}

/// The one rule for whether a check-in can be saved right now. A check-in
/// is user-authored (ADR 0038), and the composer's whole premise is that a
/// few words are enough — or a recording: its words may still be on their
/// way, and they are the recording's, not the save's, to wait for.
CheckInSaveBlock checkInSaveBlockOf({
  required CheckInSpeechPhase phase,
  required bool hasWords,
  required bool hasTakes,
  required bool saving,
}) {
  if (saving) return CheckInSaveBlock.saving;
  return switch (phase) {
    CheckInSpeechPreparing() => CheckInSaveBlock.preparing,
    CheckInSpeechRecording() => CheckInSaveBlock.recording,
    CheckInSpeechIdle() || CheckInSpeechFailed() =>
      hasWords || hasTakes
          ? CheckInSaveBlock.none
          : CheckInSaveBlock.emptyNarrative,
  };
}

/// Words in the narrative — whitespace-separated runs, so `"a  b\n c"` is
/// three and a field of spaces is none.
int checkInWordCount(String text) =>
    text.trim().isEmpty ? 0 : RegExp(r'\S+').allMatches(text).length;

/// `m:ss` under an hour and `h:mm:ss` from there — one clock shape for the
/// recorder's timer, the saved-audio line and the duration chip, so `0:23`
/// on the chip is the `0:23` the timer stopped on.
/// The same length in words, for assistive technology: `0:23` reads as
/// "zero colon twenty-three" and says nothing; "23 seconds" does.
String checkInSpokenClockLabel(AppLocalizations messages, Duration length) {
  final total = length.inSeconds.clamp(0, 1 << 31);
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return [
    if (minutes > 0) messages.checkInSpokenMinutes(minutes),
    if (seconds > 0 || minutes == 0) messages.checkInSpokenSeconds(seconds),
  ].join(' ');
}

String checkInClockLabel(Duration length) {
  final total = length.inSeconds.clamp(0, 1 << 31);
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$mm:$ss';
  return '$minutes:$ss';
}

/// What the composer's header says on its second line while speech is in
/// flight — the recorder's phase first, then the takes' words.
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

/// The header status for a [phase] and the [takes] made so far;
/// [recorderPaused] only matters while recording. The recorder speaks
/// first — it is what the user is doing now — then a take still waiting
/// for words, then one whose words never came.
CheckInComposerStatus checkInComposerStatusOf(
  CheckInSpeechPhase phase, {
  required bool recorderPaused,
  List<CheckInTake> takes = const [],
}) => switch (phase) {
  CheckInSpeechPreparing() => CheckInComposerStatus.preparing,
  CheckInSpeechRecording() =>
    recorderPaused
        ? CheckInComposerStatus.paused
        : CheckInComposerStatus.recording,
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
  },
  CheckInSpeechIdle() =>
    takes.any((t) => t.words == CheckInTakeWords.transcribing)
        ? CheckInComposerStatus.transcribing
        : takes.any((t) => t.words == CheckInTakeWords.missing)
        ? CheckInComposerStatus.transcriptMissing
        : CheckInComposerStatus.idle,
};
