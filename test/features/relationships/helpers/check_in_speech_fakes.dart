import 'dart:async';

import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';

/// Stands in for the transcription service: answers the preflight probe
/// and hands back a wait the test drives directly.
class StubCheckInTranscriptionService implements CheckInTranscriptionService {
  StubCheckInTranscriptionService({
    this.canTranscribeResult = true,
    this.transcript,
    this.gate,
    this.preflightGate,
  });

  /// Mutable, so a test can take the route away between two takes.
  bool canTranscribeResult;

  /// The words every take is heard as, unless [gate] is set. Mutable, so
  /// each take can be given its own.
  String? transcript;

  /// When set, the transcript wait resolves only when this completes.
  final Completer<String?>? gate;

  /// Per-recording gates, ahead of [gate]: a test can let two takes'
  /// words land in an order of its choosing.
  final Map<String, Completer<String?>> gatesByAudio = {};

  /// When set, the preflight answers only when this completes.
  final Completer<void>? preflightGate;

  int cancelCount = 0;
  final transcribeCalls = <String>[];

  /// The recordings whose transcript was asked to be summarized too.
  final summarizeCalls = <String>[];

  /// The person each transcript was asked for, in call order.
  final transcribePeople = <String>[];

  /// The person each `canTranscribe` probe was for, in call order.
  final probedPeople = <String>[];

  @override
  Future<bool> canTranscribe({required String relationshipId}) async {
    probedPeople.add(relationshipId);
    await preflightGate?.future;
    return canTranscribeResult;
  }

  @override
  CheckInTranscriptWait transcribe({
    required String audioEntryId,
    required String relationshipId,
    Duration timeout = checkInTranscriptTimeout,
    bool summarize = false,
  }) {
    transcribeCalls.add(audioEntryId);
    transcribePeople.add(relationshipId);
    if (summarize) summarizeCalls.add(audioEntryId);
    return _wait(audioEntryId);
  }

  /// The recordings listened to again without a request, in call order.
  final watchCalls = <String>[];

  @override
  CheckInTranscriptWait watch({
    required String audioEntryId,
    Duration timeout = checkInTranscriptTimeout,
  }) {
    watchCalls.add(audioEntryId);
    return _wait(audioEntryId);
  }

  /// One wait on the recording's words. Cancelling it ends this wait
  /// alone, as the real service's does — the words still land for a wait
  /// opened on them later.
  CheckInTranscriptWait _wait(String audioEntryId) {
    final words =
        gatesByAudio[audioEntryId] ??
        gate ??
        (Completer<String?>()..complete(transcript));
    final mine = Completer<String?>();
    unawaited(
      words.future.then((value) {
        if (!mine.isCompleted) mine.complete(value);
      }),
    );
    return CheckInTranscriptWait.forTesting(
      result: mine.future,
      onCancel: () {
        cancelCount++;
        if (!mine.isCompleted) mine.complete(null);
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
    this.runningFor,
  });

  /// What `record` answers; null is a successful start.
  AudioRecordingFailure? recordFailure;

  /// What `stop` answers; null is a recording that could not be saved.
  String? stopResult;
  bool stopThrows;
  final bool? enableSpeechRecognition;

  /// When set, the recorder starts out already recording for this entry —
  /// a take left running when an earlier sheet was dismissed.
  final String? runningFor;

  /// When set, `stop` waits for it before answering.
  Completer<void>? stopGate;

  /// When set, `record` waits for it before it starts the take — the
  /// microphone still starting up.
  Completer<void>? recordGate;

  final recordCalls = <({String? linkedId, bool handledByCaller})>[];

  /// The `origin` of every `record`, in order.
  final recordOrigins = <RecordingOrigin?>[];

  /// The `deferAutomation` of every `stop`, in order.
  final stopDeferrals = <bool>[];

  /// The ids handed to `commitAutomation` and `dropAutomation`, in order.
  final committedAutomation = <String>[];
  final droppedAutomation = <String>[];
  final inlineHostVisibleLog = <bool>[];
  final categoryIds = <String?>[];
  int stopCalls = 0;
  int cancelCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  AudioRecorderState build() => AudioRecorderState(
    status: runningFor == null
        ? AudioRecorderStatus.stopped
        : AudioRecorderStatus.recording,
    progress: Duration.zero,
    dBFS: -160,
    inlineHostVisible: false,
    linkedId: runningFor,
    enableSpeechRecognition: enableSpeechRecognition,
  );

  @override
  Future<AudioRecordingFailure?> record({
    String? linkedId,
    bool transcriptionHandledByCaller = false,
    bool Function()? shouldCancel,
    RecordingOrigin? origin,
  }) async {
    recordCalls.add((
      linkedId: linkedId,
      handledByCaller: transcriptionHandledByCaller,
    ));
    recordOrigins.add(origin);
    if (recordFailure != null) return recordFailure;
    // The microphone starting up: the real controller asks [shouldCancel]
    // only once it has.
    await recordGate?.future;
    if (shouldCancel?.call() ?? false) return null;
    state = state.copyWith(
      status: AudioRecorderStatus.recording,
      linkedId: linkedId,
      origin: origin,
    );
    return null;
  }

  @override
  Future<String?> stop({bool deferAutomation = false}) async {
    stopCalls++;
    stopDeferrals.add(deferAutomation);
    _finishing = true;
    try {
      await stopGate?.future;
      if (stopThrows) throw StateError('recorder gone');
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        origin: null,
      );
      return stopResult;
    } finally {
      _finishing = false;
    }
  }

  /// True while `stop` waits on [stopGate], as the real controller's
  /// terminal-action flag is while a stop saves.
  bool _finishing = false;

  @override
  bool get isFinishing => _finishing;

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
  void setInlineHostVisible({required bool visible}) {
    inlineHostVisibleLog.add(visible);
    state = state.copyWith(inlineHostVisible: visible);
  }

  @override
  void setCategoryId(String? categoryId) => categoryIds.add(categoryId);

  @override
  void commitAutomation(String entryId) => committedAutomation.add(entryId);

  @override
  void dropAutomation(String entryId) => droppedAutomation.add(entryId);

  /// Moves the running time and the level, the way the amplitude stream
  /// would.
  void tick({required Duration progress, double dBFS = -160}) {
    state = state.copyWith(progress: progress, dBFS: dBFS);
  }
}
