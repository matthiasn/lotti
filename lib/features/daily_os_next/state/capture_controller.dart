import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/state/capture_dbfs.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/state/realtime_transcript_selection.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' as record;

export 'package:lotti/features/daily_os_next/state/capture_state.dart';

/// Drives the Capture screen's recording lifecycle.
///
/// A raw `record.AudioRecorder` always streams PCM through the shared durable
/// spool. A configured realtime backend may consume acknowledged frames for
/// live text; without one, the same finalized WAV is batch-transcribed at stop.
///
/// Test seam: inject any of the constructor parameters to keep tests
/// deterministic and off the real mic / cloud.
class CaptureController extends Notifier<CaptureState> {
  CaptureController({
    AudioTranscriptionService? transcriber,
    RealtimeTranscriptionService? realtimeService,
    record.AudioRecorder Function()? realtimeRecorderFactory,
    Future<JournalAudio?> Function(AudioNote)? persistAudio,
    DayProcessingOutboxRepository? processingOutbox,
    Directory Function()? docDir,
    DateTime Function()? now,
  }) : _transcriberOverride = transcriber,
       _realtimeServiceOverride = realtimeService,
       _realtimeRecorderFactory =
           realtimeRecorderFactory ?? record.AudioRecorder.new,
       _persistAudioOverride = persistAudio,
       _processingOutboxOverride = processingOutbox,
       _docDir = docDir ?? getDocumentsDirectory,
       _now = now ?? DateTime.now;

  final AudioTranscriptionService? _transcriberOverride;
  final RealtimeTranscriptionService? _realtimeServiceOverride;
  final record.AudioRecorder Function() _realtimeRecorderFactory;
  final Future<JournalAudio?> Function(AudioNote)? _persistAudioOverride;
  final DayProcessingOutboxRepository? _processingOutboxOverride;
  final Directory Function() _docDir;
  final DateTime Function() _now;

  /// Rolling-window size for the live waveform (~1.6s at 20ms cadence).
  static const _maxAmplitudeSamples = 80;

  late final AudioTranscriptionService _transcriber =
      _transcriberOverride ?? ref.read(audioTranscriptionServiceProvider);
  late final RealtimeTranscriptionService _realtimeService =
      _realtimeServiceOverride ??
      ref.read(realtimeTranscriptionServiceProvider);
  late final Future<JournalAudio?> Function(AudioNote) _persistAudio =
      _persistAudioOverride ?? SpeechRepository.createAudioEntry;
  DayProcessingOutboxRepository? get _processingOutbox =>
      _processingOutboxOverride ??
      (getIt.isRegistered<DayProcessingOutboxRepository>()
          ? getIt<DayProcessingOutboxRepository>()
          : null);

  /// Active realtime transcription config — captured at start time so
  /// the AudioTranscript persisted on the JournalAudio carries the
  /// provider + model that actually produced the text.
  ({AiConfigInferenceProvider provider, AiConfigModel model})?
  _activeRealtimeConfig;

  StreamSubscription<double>? _realtimeAmpSub;
  record.AudioRecorder? _realtimeRecorder;
  DurableRealtimeCapture? _realtimeCapture;

  // Pre-computed audio path data so we can build the AudioNote after
  // the realtime service writes the canonical WAV file.
  String? _realtimeOutputBasePath;
  String? _realtimeAudioDirectory;
  String? _realtimeAudioFile;

  DateTime? _recordingStartedAt;
  String? _activeDayId;
  DateTime? _activePlanDate;
  AudioCaptureIntent? _activeIntent;
  bool _verifyRealtimeTranscript = true;
  bool _realtimeTerminalActionInProgress = false;
  int _lifecycleEpoch = 0;
  bool _disposed = false;

  @override
  CaptureState build() {
    ref.onDispose(() {
      _disposed = true;
      _cleanupSync();
    });
    return const CaptureState.idle();
  }

  /// Drives the phase transitions. Voice-button tap triggers this.
  Future<void> toggle({
    DateTime? forDate,
    AudioCaptureIntent intent = AudioCaptureIntent.dayPlan,
  }) async {
    switch (state.phase) {
      case CapturePhase.idle:
      case CapturePhase.error:
        await _beginListening(forDate: forDate, intent: intent);
      case CapturePhase.listening:
        await _finishListening();
      case CapturePhase.transcribing:
        // Busy. Ignore presses while transcription is in flight.
        return;
      case CapturePhase.captured:
        reset();
    }
  }

  /// Manual reset — used by the "Re-record" footer on Reconcile.
  void reset() {
    _cleanupSync();
    _verifyRealtimeTranscript = true;
    state = const CaptureState.idle();
  }

  /// Skips the full-audio verifier for the next realtime capture. Refine uses
  /// this so Mistral realtime text is not replaced by an MLX batch fallback
  /// before the user reviews the transcript.
  void skipRealtimeTranscriptVerificationForNextCapture() {
    _verifyRealtimeTranscript = false;
  }

  /// Opens the typed-capture path without touching the microphone.
  void startTyping() {
    _cleanupSync();
    state = const CaptureState(
      phase: CapturePhase.captured,
      transcript: '',
      amplitudes: <double>[],
    );
  }

  /// Edits the final transcript before it is handed to Reconcile.
  void updateTranscript(String transcript) {
    if (state.phase != CapturePhase.captured) return;
    state = state.copyWith(transcript: transcript);
  }

  Future<void> _beginListening({
    required AudioCaptureIntent intent,
    DateTime? forDate,
  }) async {
    final epoch = ++_lifecycleEpoch;
    final createdAt = _now();
    final planDate = forDate ?? createdAt;
    _activeDayId = dayPlanId(planDate);
    _activePlanDate = DateTime(planDate.year, planDate.month, planDate.day);
    _activeIntent = intent;
    final docDir = _docDir();
    DurableRealtimeCapture capture;
    try {
      capture = await _realtimeService.prepareDefaultDurableCapture(
        assetRootDirectory: docDir,
        createdAt: createdAt,
        origin: AudioCaptureOrigin.dailyOs,
        intent: intent,
        dayId: _activeDayId,
        planDate: planDate,
      );
      if (!_isCurrentLifecycle(epoch)) {
        await capture.discard();
        return;
      }
      _realtimeCapture = capture;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while preparing durable audio capture'),
        ),
      );
      if (_isCurrentLifecycle(epoch)) {
        state = const CaptureState(
          phase: CapturePhase.error,
          transcript: '',
          amplitudes: <double>[],
          error: CaptureError.recordingStartFailed,
        );
      }
      return;
    }

    // Mistral cloud realtime is preferred for interactive latency; MLX is the
    // automatic fallback when no Mistral realtime model is configured. The
    // ordering lives in `RealtimeTranscriptionService.resolveRealtimeConfig`
    // so every realtime caller shares the same preference.
    ({AiConfigInferenceProvider provider, AiConfigModel model})? realtimeConfig;
    try {
      realtimeConfig = await _realtimeService.resolveRealtimeConfig();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while resolving realtime audio config'),
        ),
      );
    }
    if (!_isCurrentLifecycle(epoch)) {
      await capture.discard();
      if (identical(_realtimeCapture, capture)) _realtimeCapture = null;
      return;
    }
    _activeRealtimeConfig = realtimeConfig;
    // The durable PCM spool is the single Daily OS microphone owner even when
    // no realtime backend is configured. A null config disables live
    // inference only; stop still finalizes the complete local WAV and runs the
    // normal batch transcription pass over that artifact.
    await _beginListeningRealtime(
      capture: capture,
      createdAt: createdAt,
      docDir: docDir,
      epoch: epoch,
    );
  }

  Future<void> _beginListeningRealtime({
    required DurableRealtimeCapture capture,
    required DateTime createdAt,
    required Directory docDir,
    required int epoch,
  }) async {
    final recorder = _realtimeRecorderFactory();
    final hasPerm = await recorder.hasPermission();
    if (!_isCurrentLifecycle(epoch)) {
      await recorder.dispose();
      await capture.discard();
      return;
    }
    if (!hasPerm) {
      await recorder.dispose();
      await capture.discard();
      _realtimeCapture = null;
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.microphonePermissionDenied,
      );
      return;
    }

    // Resolve the final asset destination before the microphone can emit a
    // frame. Once startStream returns, durable subscription is the next async
    // operation.
    final timestamp =
        '${DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(createdAt)}_'
        '${capture.recordingSessionId}';
    final day = DateFormat('yyyy-MM-dd').format(createdAt);
    _realtimeAudioDirectory = '/audio/$day/';
    _realtimeAudioFile = '$timestamp.wav';
    final absoluteDir = '${docDir.path}$_realtimeAudioDirectory';
    try {
      await Directory(absoluteDir).create(recursive: true);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while preparing the audio destination'),
        ),
      );
      await recorder.dispose();
      await capture.discard();
      _realtimeCapture = null;
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.recordingStartFailed,
      );
      return;
    }
    if (!_isCurrentLifecycle(epoch)) {
      await recorder.dispose();
      await capture.discard();
      return;
    }
    _realtimeOutputBasePath = '$absoluteDir$timestamp';

    final Stream<Uint8List> pcmStream;
    try {
      pcmStream = await recorder.startStream(
        const record.RecordConfig(
          encoder: record.AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while starting the realtime PCM stream'),
        ),
      );
      await recorder.dispose();
      await capture.discard();
      _realtimeCapture = null;
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.recordingStartFailed,
      );
      return;
    }
    if (!_isCurrentLifecycle(epoch)) {
      try {
        await recorder.stop();
      } catch (_) {}
      await recorder.dispose();
      await capture.discard();
      return;
    }

    _realtimeRecorder = recorder;
    _recordingStartedAt = createdAt;
    state = const CaptureState(
      phase: CapturePhase.listening,
      transcript: '',
      amplitudes: <double>[],
    );

    _realtimeAmpSub = _realtimeService.amplitudeStream.listen(
      (dbfs) {
        if (state.phase != CapturePhase.listening) return;
        final next = [...state.amplitudes, normaliseDbfs(dbfs)];
        final clipped = next.length > _maxAmplitudeSamples
            ? next.sublist(next.length - _maxAmplitudeSamples)
            : next;
        state = state.copyWith(
          amplitudes: clipped,
          dbfs: sanitizeVisualDbfs(dbfs),
        );
      },
      onError: (Object _) {
        // Amplitude stream errors are non-fatal — keep recording.
      },
    );

    try {
      await _realtimeService.startRealtimeTranscription(
        capture: capture,
        pcmStream: pcmStream,
        onDelta: _onRealtimeDelta,
        onCaptureFailure: _onRealtimeCaptureFailure,
        config: _activeRealtimeConfig,
        resolveConfigWhenAbsent: false,
      );
      if (!_isCurrentLifecycle(epoch)) {
        await _realtimeService.stopAndRetainForRecovery(
          capture: capture,
          stopRecorder: () async {
            try {
              await recorder.stop();
            } catch (_) {}
          },
        );
        await recorder.dispose();
      }
    } catch (error, stackTrace) {
      if (!_isCurrentLifecycle(epoch)) {
        try {
          await _realtimeService.stopAndRetainForRecovery(
            capture: capture,
            stopRecorder: () async {
              await recorder.stop();
            },
          );
        } catch (_) {}
        try {
          await recorder.dispose();
        } catch (_) {}
        return;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription(
            'while starting realtime transcription',
          ),
        ),
      );
      await _cleanupRealtime(disposeRecorder: true);
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.realtimeTranscriptionStartFailed,
      );
    }
  }

  void _onRealtimeDelta(String delta) {
    if (state.phase != CapturePhase.listening &&
        state.phase != CapturePhase.transcribing) {
      return;
    }
    state = state.copyWith(
      partialTranscript: '${state.partialTranscript}$delta',
    );
  }

  void _onRealtimeCaptureFailure(Object _, StackTrace _) {
    if (!ref.mounted || state.phase != CapturePhase.listening) {
      return;
    }
    unawaited(_finishListeningRealtime());
  }

  Future<void> _finishListening() => _finishListeningRealtime();

  /// Test-only seam for the realtime finish path: the
  /// `noActiveRealtimeSession` guard below is defensive (the public state
  /// machine always sets the session fields before reaching it), so tests
  /// invoke the method directly to pin the guard's behavior.
  @visibleForTesting
  Future<void> debugFinishListeningRealtime() => _finishListeningRealtime();

  Future<void> _finishListeningRealtime() async {
    if (_realtimeTerminalActionInProgress) return;
    _realtimeTerminalActionInProgress = true;
    try {
      await _finishListeningRealtimeOnce();
    } finally {
      _realtimeTerminalActionInProgress = false;
    }
  }

  Future<void> _finishListeningRealtimeOnce() async {
    final recorder = _realtimeRecorder;
    final outputBase = _realtimeOutputBasePath;
    final audioDir = _realtimeAudioDirectory;
    final audioFile = _realtimeAudioFile;
    final startedAt = _recordingStartedAt;
    final capture = _realtimeCapture;
    if (recorder == null ||
        capture == null ||
        outputBase == null ||
        audioDir == null ||
        audioFile == null) {
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.noActiveRealtimeSession,
      );
      return;
    }

    await _realtimeAmpSub?.cancel();
    _realtimeAmpSub = null;
    state = state.copyWith(phase: CapturePhase.transcribing);

    RealtimeStopResult result;
    try {
      result = await _realtimeService.stop(
        capture: capture,
        stopRecorder: () async {
          try {
            await recorder.stop();
          } catch (_) {}
        },
        outputPath: outputBase,
      );
      if (result.recordingSessionId != capture.recordingSessionId) {
        throw StateError('Realtime stop result belongs to another capture');
      }
    } catch (error, stackTrace) {
      final hasRecoverableAudio = capture.acceptedPcmBytes > 0;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription('while stopping realtime transcription'),
        ),
      );
      await _cleanupRealtime(disposeRecorder: true);
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.noAudioRecorded,
      );
      if (hasRecoverableAudio) {
        state = const CaptureState(
          phase: CapturePhase.error,
          transcript: '',
          amplitudes: <double>[],
          error: CaptureError.recordingRetainedForRecovery,
        );
      }
      return;
    }

    if (result.captureDisposition != RealtimeCaptureDisposition.complete) {
      await _cleanupRealtime(disposeRecorder: true, stopRecorder: false);
      state = CaptureState(
        phase: CapturePhase.error,
        transcript: result.transcript.trim(),
        amplitudes: const <double>[],
        error: result.captureDisposition == RealtimeCaptureDisposition.noAudio
            ? CaptureError.noAudioRecorded
            : CaptureError.recordingRetainedForRecovery,
      );
      return;
    }

    final audioFilePath = result.audioFilePath;
    if (audioFilePath == null) {
      await _cleanupRealtime(disposeRecorder: true, stopRecorder: false);
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.noAudioRecorded,
      );
      return;
    }
    final duration =
        result.audioDuration ??
        (startedAt == null ? Duration.zero : _now().difference(startedAt));
    final note = AudioNote(
      createdAt: startedAt ?? _now(),
      audioFile: audioFilePath.split('/').last,
      audioDirectory: audioDir,
      duration: duration,
      dayContext: _dayAudioContext(capture, startedAt ?? _now()),
    );

    JournalAudio? journalAudio;
    try {
      journalAudio = await _persistAudio(note);
    } catch (_) {
      // The durable spool remains available to startup recovery.
    }
    if (journalAudio == null) {
      await _cleanupRealtime(disposeRecorder: true, stopRecorder: false);
      state = CaptureState(
        phase: CapturePhase.error,
        transcript: result.transcript.trim(),
        amplitudes: const <double>[],
        error: CaptureError.recordingRetainedForRecovery,
      );
      return;
    }
    var ownershipBound = false;
    try {
      await capture.markCommitted(journalAudioId: journalAudio.meta.id);
      ownershipBound = true;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'daily_os_next',
          context: ErrorDescription(
            'while binding durable audio to its journal entry',
          ),
        ),
      );
    }
    if (!ownershipBound) {
      await _cleanupRealtime(disposeRecorder: true, stopRecorder: false);
      state = CaptureState(
        phase: CapturePhase.error,
        transcript: result.transcript.trim(),
        amplitudes: const <double>[],
        audioId: journalAudio.meta.id,
        error: CaptureError.recordingSavedPendingTranscription,
      );
      return;
    }

    final outbox = _processingOutbox;
    DayProcessingClaim? processingClaim;
    if (outbox != null) {
      final context = note.dayContext!;
      try {
        processingClaim = await outbox.enqueueAndClaimTranscription(
          dayId: context.dayId,
          activityEntryId: context.activityEntryId,
          recordingSessionId: context.recordingSessionId,
          audioId: journalAudio.meta.id,
          audioPath: audioFilePath,
          capturedAt: context.capturedAt,
        );
        if (processingClaim == null) {
          throw StateError('Day transcription job is not claimable');
        }
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'daily_os_next',
            context: ErrorDescription('while enqueueing day transcription'),
          ),
        );
        await _finishRecorderCleanup(recorder);
        state = CaptureState(
          phase: CapturePhase.error,
          transcript: result.transcript.trim(),
          amplitudes: const <double>[],
          audioId: journalAudio.meta.id,
          error: CaptureError.recordingSavedPendingTranscription,
        );
        return;
      }
    }

    final realtimeTranscript = result.transcript.trim();
    final finalTranscript = await _resolveRealtimeFinalTranscript(
      result: result,
      realtimeTranscript: realtimeTranscript,
    );
    if (finalTranscript.isEmpty) {
      if (processingClaim != null) {
        await outbox!.markFailure(
          jobId: processingClaim.job.id,
          claimToken: processingClaim.token,
          failureClass: DayProcessingFailureClass.timeout,
          error: 'No transcript was produced',
        );
      }
      await _finishRecorderCleanup(recorder);
      state = CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: const <double>[],
        audioId: journalAudio.meta.id,
        error: CaptureError.recordingSavedPendingTranscription,
      );
      return;
    }
    if (finalTranscript.isNotEmpty) {
      final config = _activeRealtimeConfig;
      final attached = processingClaim == null
          ? await () async {
              await _attachTranscriptToJournalAudio(
                journalAudio: journalAudio!,
                transcript: finalTranscript,
                library: config?.provider.name ?? 'realtime',
                model: config?.model.providerModelId ?? 'unknown',
                detectedLanguage: result.detectedLanguage ?? '-',
              );
              return true;
            }()
          : await _completeForegroundProcessing(
              outbox: outbox!,
              claim: processingClaim,
              journalAudio: journalAudio,
              transcript: finalTranscript,
              library: config?.provider.name ?? 'realtime',
              model: config?.model.providerModelId ?? 'unknown',
              detectedLanguage: result.detectedLanguage ?? '-',
            );
      if (!attached) {
        await _finishRecorderCleanup(recorder);
        state = CaptureState(
          phase: CapturePhase.error,
          transcript: finalTranscript,
          amplitudes: const <double>[],
          audioId: journalAudio.meta.id,
          error: CaptureError.recordingSavedPendingTranscription,
        );
        return;
      }
    }

    await _finishRecorderCleanup(recorder);

    state = CaptureState(
      phase: CapturePhase.captured,
      transcript: finalTranscript,
      amplitudes: const <double>[],
      audioId: journalAudio.meta.id,
    );
  }

  DayAudioContext _dayAudioContext(
    DurableRealtimeCapture capture,
    DateTime capturedAt,
  ) {
    final dayId = _activeDayId;
    final planDate = _activePlanDate;
    final intent = _activeIntent;
    if (dayId == null || planDate == null || intent == null) {
      throw StateError('Daily capture context is incomplete');
    }
    return DayAudioContext(
      dayId: dayId,
      planDate: planDate,
      recordingSessionId: capture.recordingSessionId,
      activityEntryId: capture.activityEntryId,
      processingJobId: DayProcessingOutboxRepository.transcriptionJobId(
        capture.recordingSessionId,
      ),
      capturedAt: capturedAt,
      intent: intent.name,
      originHostId: capture.originHostId,
      continuationOperationId: capture.continuationOperationId,
      baselineRevisionId: capture.baselineRevisionId,
    );
  }

  Future<bool> _completeForegroundProcessing({
    required DayProcessingOutboxRepository outbox,
    required DayProcessingClaim claim,
    required JournalAudio journalAudio,
    required String transcript,
    required String library,
    required String model,
    required String detectedLanguage,
  }) async {
    final job = claim.job;
    try {
      await outbox.markTranscriptReady(
        jobId: job.id,
        claimToken: claim.token,
        transcript: transcript,
      );
      final attached = await _attachTranscriptToJournalAudio(
        journalAudio: journalAudio,
        transcript: transcript,
        library: library,
        model: model,
        detectedLanguage: detectedLanguage,
        processingJobId: job.id,
      );
      if (!attached) {
        await outbox.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.local,
          error: 'Journal transcript commit was not accepted',
          retryDelay: const Duration(seconds: 1),
        );
        return false;
      }
      await outbox.markSucceeded(jobId: job.id, claimToken: claim.token);
      return true;
    } catch (error) {
      try {
        await outbox.markFailure(
          jobId: job.id,
          claimToken: claim.token,
          failureClass: DayProcessingFailureClass.local,
          error: error.toString(),
          retryDelay: const Duration(seconds: 1),
        );
      } catch (_) {}
      return false;
    }
  }

  Future<void> _finishRecorderCleanup(record.AudioRecorder recorder) async {
    try {
      await recorder.dispose();
    } catch (_) {}
    _realtimeRecorder = null;
    _realtimeCapture = null;
    _realtimeOutputBasePath = null;
    _realtimeAudioDirectory = null;
    _realtimeAudioFile = null;
    _recordingStartedAt = null;
    _activeRealtimeConfig = null;
    _verifyRealtimeTranscript = true;
    _activeDayId = null;
    _activePlanDate = null;
    _activeIntent = null;
  }

  /// Persists [transcript] as an [AudioTranscript] on [journalAudio]
  /// and mirrors the text into [JournalAudio.entryText] so the audio
  /// entry shows up with searchable content in the journal.
  Future<bool> _attachTranscriptToJournalAudio({
    required JournalAudio journalAudio,
    required String transcript,
    required String library,
    required String model,
    required String detectedLanguage,
    String? processingJobId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final audioTranscript = AudioTranscript(
        created: _now(),
        library: library,
        model: model,
        detectedLanguage: detectedLanguage,
        transcript: transcript,
        processingJobId: processingJobId,
      );
      final existing = journalAudio.data.transcripts ?? <AudioTranscript>[];
      final updated = journalAudio.copyWith(
        meta: await persistenceLogic.updateMetadata(journalAudio.meta),
        data: journalAudio.data.copyWith(
          transcripts: [...existing, audioTranscript],
        ),
        entryText: EntryText(plainText: transcript, markdown: transcript),
      );
      return await persistenceLogic.updateDbEntity(updated) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cleanupRealtime({
    required bool disposeRecorder,
    bool stopRecorder = true,
  }) async {
    final ampSub = _realtimeAmpSub;
    _realtimeAmpSub = null;
    if (ampSub != null) {
      await ampSub.cancel();
    }
    final recorder = _realtimeRecorder;
    if (disposeRecorder) _realtimeRecorder = null;
    try {
      final capture = _realtimeCapture;
      if (capture != null) {
        await _realtimeService.stopAndRetainForRecovery(
          capture: capture,
          stopRecorder: () async {
            if (disposeRecorder && stopRecorder && recorder != null) {
              await recorder.stop();
            }
          },
        );
      }
    } catch (_) {}
    if (disposeRecorder && recorder != null) {
      try {
        await recorder.dispose();
      } catch (_) {}
    }
    _realtimeOutputBasePath = null;
    _realtimeAudioDirectory = null;
    _realtimeAudioFile = null;
    _realtimeCapture = null;
    _recordingStartedAt = null;
    _activeDayId = null;
    _activePlanDate = null;
    _activeIntent = null;
  }

  void _cleanupSync() {
    _lifecycleEpoch += 1;
    final realtimeAmpSub = _realtimeAmpSub;
    _realtimeAmpSub = null;
    if (realtimeAmpSub != null) {
      unawaited(realtimeAmpSub.cancel());
    }
    final recorder = _realtimeRecorder;
    final capture = _realtimeCapture;
    _realtimeRecorder = null;
    unawaited(
      () async {
        try {
          if (capture != null) {
            await _realtimeService.stopAndRetainForRecovery(
              capture: capture,
              stopRecorder: () async {
                await recorder?.stop();
              },
            );
          }
        } catch (_) {}
        if (recorder != null) {
          try {
            await recorder.dispose();
          } catch (_) {}
        }
      }(),
    );
    _recordingStartedAt = null;
    _realtimeOutputBasePath = null;
    _realtimeAudioDirectory = null;
    _realtimeAudioFile = null;
    _realtimeCapture = null;
    _activeDayId = null;
    _activePlanDate = null;
    _activeIntent = null;
  }

  bool _isCurrentLifecycle(int epoch) =>
      !_disposed && ref.mounted && epoch == _lifecycleEpoch;

  /// Runs the optional full-file verification pass over the realtime
  /// transcript. The transcription round-trip and the verify gate are
  /// controller-coupled; the final string selection delegates to the pure
  /// [selectFinalTranscript].
  Future<String> _resolveRealtimeFinalTranscript({
    required RealtimeStopResult result,
    required String realtimeTranscript,
  }) async {
    if (!_verifyRealtimeTranscript) return realtimeTranscript;

    final audioFilePath = result.audioFilePath;
    if (audioFilePath == null || audioFilePath.isEmpty) {
      return realtimeTranscript;
    }

    try {
      final batchTranscript = (await _transcriber.transcribe(
        audioFilePath,
      )).trim();
      return selectFinalTranscript(
        realtimeTranscript: realtimeTranscript,
        batchTranscript: batchTranscript,
        usedTranscriptFallback: result.usedTranscriptFallback,
      );
    } catch (_) {
      // Final verification is best-effort. Realtime still gives the user an
      // editable transcript if the batch transcriber is unavailable.
      return realtimeTranscript;
    }
  }
}

/// Creates a fresh controller per route entry so a re-entry into
/// Capture starts cleanly. The Reconcile screen reads the captured
/// transcript via the capture id handed off when navigating.
// ignore: specify_nonobvious_property_types
final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
