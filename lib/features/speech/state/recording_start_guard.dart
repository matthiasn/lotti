import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';

/// Why a recorder has no recording to hand back.
enum InlineRecordingFailure {
  /// The OS refused the microphone.
  microphoneDenied,

  /// The recorder could not start.
  startFailed,

  /// The app-wide recorder is running a take that is not this subject's —
  /// started elsewhere, or for something else. It has to be stopped from the
  /// recording strip first.
  recorderBusy,

  /// The recorder ran but could not be stopped and saved. The take is lost.
  notSaved,
}

/// What a microphone press for a subject does to the app-wide recorder.
enum RecordingStartDecision {
  /// Nothing is recording: start a take for the subject.
  start,

  /// A take for this very subject is already running: attach to it rather
  /// than start another.
  attach,

  /// A take for something else holds the recorder. Starting would stop it
  /// and file it under this subject, so leave it alone.
  busy,
}

/// The one rule every way of starting a take applies — the recording
/// strip's session and the recorder a check-in draws in place.
///
/// The recorder's `record()` is a toggle: called while a take runs it stops
/// and saves that take, under whatever subject the caller just named. So a
/// take running for [linkedId] is attached to, and one running for anything
/// else is [RecordingStartDecision.busy].
RecordingStartDecision decideRecordingStart(
  AudioRecorderState running, {
  required String? linkedId,
}) {
  if (!running.isTakeActive) return RecordingStartDecision.start;
  return running.linkedId == linkedId
      ? RecordingStartDecision.attach
      : RecordingStartDecision.busy;
}

/// The failure a refused start reads as. `busy` here is a start or a stop
/// still in flight — a start that did not happen, so it reads as a failed
/// start.
InlineRecordingFailure failureOfStart(AudioRecordingFailure failure) =>
    switch (failure) {
      AudioRecordingFailure.permissionDenied =>
        InlineRecordingFailure.microphoneDenied,
      AudioRecordingFailure.startFailed ||
      AudioRecordingFailure.busy => InlineRecordingFailure.startFailed,
    };
