import 'dart:async';

import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';

/// Stands in for the transcription service: answers the preflight probe,
/// names a route, and hands back a wait the test drives directly.
class StubCheckInTranscriptionService implements CheckInTranscriptionService {
  StubCheckInTranscriptionService({
    this.canTranscribeResult = true,
    this.transcript,
    this.gate,
    this.preflightGate,
    this.routeResult = (model: 'Whisper large v3', provider: 'Groq'),
  });

  final bool canTranscribeResult;
  final String? transcript;

  /// When set, the transcript wait resolves only when this completes.
  final Completer<String?>? gate;

  /// When set, the preflight answers only when this completes.
  final Completer<void>? preflightGate;
  final CheckInTranscriptionRoute? routeResult;

  int cancelCount = 0;
  final transcribeCalls = <String>[];

  @override
  Future<bool> canTranscribe() async {
    await preflightGate?.future;
    return canTranscribeResult;
  }

  @override
  Future<CheckInTranscriptionRoute?> route() async => routeResult;

  @override
  CheckInTranscriptWait transcribe({
    required String audioEntryId,
    Duration timeout = checkInTranscriptTimeout,
  }) {
    transcribeCalls.add(audioEntryId);
    final completer = gate ?? (Completer<String?>()..complete(transcript));
    return CheckInTranscriptWait.forTesting(
      result: completer.future,
      onCancel: () {
        cancelCount++;
        if (!completer.isCompleted) completer.complete(null);
      },
    );
  }
}

/// A scriptable stand-in for the app-wide recorder: records every call the
/// inline recorder makes, answers `record` with a chosen refusal, `stop`
/// with a chosen entry id, and lets a test drive the running time and the
/// level so the timer and the strip can be asserted on.
class FakeAudioRecorderController extends AudioRecorderController {
  FakeAudioRecorderController({
    this.recordFailure,
    this.stopResult = 'audio-1',
    this.stopThrows = false,
    this.enableSpeechRecognition,
  });

  /// What `record` answers; null is a successful start.
  AudioRecordingFailure? recordFailure;

  /// What `stop` answers; null is a recording that could not be saved.
  String? stopResult;
  bool stopThrows;
  final bool? enableSpeechRecognition;

  /// When set, `stop` waits for it before answering.
  Completer<void>? stopGate;

  final recordCalls = <({String? linkedId, bool handledByCaller})>[];
  final modalVisibleLog = <bool>[];
  final categoryIds = <String?>[];
  int stopCalls = 0;
  int cancelCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  AudioRecorderState build() => AudioRecorderState(
    status: AudioRecorderStatus.stopped,
    progress: Duration.zero,
    vu: -20,
    dBFS: -160,
    showIndicator: false,
    modalVisible: false,
    enableSpeechRecognition: enableSpeechRecognition,
  );

  @override
  Future<AudioRecordingFailure?> record({
    String? linkedId,
    bool transcriptionHandledByCaller = false,
    bool Function()? shouldCancel,
  }) async {
    recordCalls.add((
      linkedId: linkedId,
      handledByCaller: transcriptionHandledByCaller,
    ));
    if (recordFailure != null) return recordFailure;
    if (shouldCancel?.call() ?? false) return null;
    state = state.copyWith(
      status: AudioRecorderStatus.recording,
      linkedId: linkedId,
    );
    return null;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    await stopGate?.future;
    if (stopThrows) throw StateError('recorder gone');
    state = state.copyWith(
      status: AudioRecorderStatus.stopped,
      progress: Duration.zero,
    );
    return stopResult;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    state = state.copyWith(
      status: AudioRecorderStatus.stopped,
      progress: Duration.zero,
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    state = state.copyWith(status: AudioRecorderStatus.paused);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    state = state.copyWith(status: AudioRecorderStatus.recording);
  }

  @override
  void setModalVisible({required bool modalVisible}) {
    modalVisibleLog.add(modalVisible);
    state = state.copyWith(modalVisible: modalVisible);
  }

  @override
  void setCategoryId(String? categoryId) => categoryIds.add(categoryId);

  /// Moves the running time and the level, the way the amplitude stream
  /// would.
  void tick({required Duration progress, double dBFS = -160}) {
    state = state.copyWith(progress: progress, dBFS: dBFS);
  }
}
