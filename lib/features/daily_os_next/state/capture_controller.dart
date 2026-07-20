import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/transcript_attribution_coordinator.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_ids.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/state/capture_dbfs.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' as record;
import 'package:uuid/uuid.dart';

export 'package:lotti/features/daily_os_next/state/capture_state.dart';

/// Immutable per-recording session context, fixed before the microphone
/// starts so the selected planning day — not the wall clock at stop —
/// owns the recording.
class _CaptureSession {
  const _CaptureSession({
    required this.dayId,
    required this.planDate,
    required this.recordingSessionId,
    required this.activityEntryId,
    required this.intent,
    this.originHostId,
  });

  final String dayId;
  final DateTime planDate;
  final String recordingSessionId;
  final String activityEntryId;
  final AudioCaptureIntent intent;
  final String? originHostId;
}

/// Drives the Capture screen's recording lifecycle.
///
/// Batch-first: the platform recorder writes an `.m4a` file, and stop
/// follows a strict local-first commit order — persist the [JournalAudio]
/// with its [DayAudioContext] provenance, enqueue-and-claim the durable
/// transcription job, and only then run the foreground transcription
/// round-trip. A transcription or network failure never loses the
/// recording; the processing outbox owns retries.
///
/// Test seam: inject any of the constructor parameters to keep tests
/// deterministic and off the real mic / cloud.
class CaptureController extends Notifier<CaptureState> {
  CaptureController({
    AudioRecorderRepository? recorder,
    AudioTranscriptionService? transcriber,
    Future<JournalAudio?> Function(AudioNote)? persistAudio,
    DayProcessingOutboxRepository? processingOutbox,
    Directory Function()? docDir,
    String Function()? sessionIdFactory,
    Future<String?> Function()? originHostId,
    DateTime Function()? now,
  }) : _recorderOverride = recorder,
       _transcriberOverride = transcriber,
       _persistAudioOverride = persistAudio,
       _processingOutboxOverride = processingOutbox,
       _docDir = docDir ?? getDocumentsDirectory,
       _sessionIdFactory = sessionIdFactory ?? _newSessionId,
       _originHostIdOverride = originHostId,
       _now = now ?? DateTime.now;

  static String _newSessionId() => const Uuid().v4();

  final AudioRecorderRepository? _recorderOverride;
  final AudioTranscriptionService? _transcriberOverride;
  final Future<JournalAudio?> Function(AudioNote)? _persistAudioOverride;
  final DayProcessingOutboxRepository? _processingOutboxOverride;
  final Directory Function() _docDir;
  final String Function() _sessionIdFactory;
  final Future<String?> Function()? _originHostIdOverride;
  final DateTime Function() _now;

  /// Rolling-window size for the live waveform (~1.6s at 20ms cadence).
  static const _maxAmplitudeSamples = 80;

  late final AudioRecorderRepository _recorder =
      _recorderOverride ?? AudioRecorderRepository();
  late final AudioTranscriptionService _transcriber =
      _transcriberOverride ?? ref.read(audioTranscriptionServiceProvider);
  late final Future<JournalAudio?> Function(AudioNote) _persistAudio =
      _persistAudioOverride ?? SpeechRepository.createAudioEntry;
  DayProcessingOutboxRepository? get _processingOutbox =>
      _processingOutboxOverride ??
      (getIt.isRegistered<DayProcessingOutboxRepository>()
          ? getIt<DayProcessingOutboxRepository>()
          : null);
  TranscriptAttributionCoordinator? get _attributionCoordinator =>
      getIt.isRegistered<TranscriptAttributionCoordinator>()
      ? getIt<TranscriptAttributionCoordinator>()
      : null;

  Future<String?> _originHostId() {
    final override = _originHostIdOverride;
    if (override != null) return override();
    if (!getIt.isRegistered<VectorClockService>()) {
      return Future<String?>.value();
    }
    return getIt<VectorClockService>().getHost();
  }

  StreamSubscription<record.Amplitude>? _ampSub;
  TranscriptAttributionSession? _transcriptAttribution;
  AudioNote? _recordingNote;
  DateTime? _recordingStartedAt;
  _CaptureSession? _session;
  bool _terminalActionInProgress = false;
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
        // Busy. Ignore presses while the stop commit is in flight.
        return;
      case CapturePhase.captured:
        reset();
    }
  }

  /// Manual reset — used by the "Re-record" footer on Reconcile.
  void reset() {
    _cleanupSync();
    state = const CaptureState.idle();
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
    final sessionId = _sessionIdFactory();

    String? hostId;
    try {
      hostId = await _originHostId();
    } catch (_) {
      // Provenance host id is best-effort; the recording proceeds.
    }
    if (!_isCurrentLifecycle(epoch)) return;

    final permitted = await _recorder.hasPermission();
    if (!_isCurrentLifecycle(epoch)) return;
    if (!permitted) {
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.microphonePermissionDenied,
      );
      return;
    }

    final note = await _recorder.startRecording();
    if (!_isCurrentLifecycle(epoch)) {
      if (note != null) unawaited(_recorder.stopRecording());
      return;
    }
    if (note == null) {
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.recordingStartFailed,
      );
      return;
    }

    _session = _CaptureSession(
      dayId: dayPlanId(planDate),
      planDate: planDate.dateOnly,
      recordingSessionId: sessionId,
      activityEntryId: audioActivityEntryIdForSession(sessionId),
      intent: intent,
      originHostId: hostId,
    );
    _recordingNote = note;
    _recordingStartedAt = _now();
    state = const CaptureState(
      phase: CapturePhase.listening,
      transcript: '',
      amplitudes: <double>[],
    );
    _ampSub = _recorder.amplitudeStream.listen(
      _onAmplitude,
      onError: (Object _) {
        // Amplitude stream errors are non-fatal — keep recording.
      },
    );
  }

  void _onAmplitude(record.Amplitude amp) {
    if (state.phase != CapturePhase.listening) return;
    final next = [...state.amplitudes, normaliseDbfs(amp.current)];
    final clipped = next.length > _maxAmplitudeSamples
        ? next.sublist(next.length - _maxAmplitudeSamples)
        : next;
    state = state.copyWith(
      amplitudes: clipped,
      dbfs: sanitizeVisualDbfs(amp.current),
    );
  }

  Future<void> _finishListening() async {
    if (_terminalActionInProgress) return;
    _terminalActionInProgress = true;
    try {
      await _finishListeningOnce();
    } finally {
      _terminalActionInProgress = false;
    }
  }

  Future<void> _finishListeningOnce() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _recorder.stopRecording();

    final note = _recordingNote;
    final session = _session;
    final startedAt = _recordingStartedAt;
    if (note == null || session == null) {
      _clearSession();
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.noAudioRecorded,
      );
      return;
    }

    state = state.copyWith(phase: CapturePhase.transcribing);

    final docDir = _docDir();
    final fullPath = '${docDir.path}${note.audioDirectory}${note.audioFile}';
    final capturedAt = startedAt ?? _now();
    final duration = startedAt == null
        ? Duration.zero
        : _now().difference(startedAt);
    final dayContext = DayAudioContext(
      dayId: session.dayId,
      planDate: session.planDate,
      recordingSessionId: session.recordingSessionId,
      activityEntryId: session.activityEntryId,
      processingJobId: DayProcessingOutboxRepository.transcriptionJobId(
        session.recordingSessionId,
      ),
      capturedAt: capturedAt,
      intent: session.intent.name,
      originHostId: session.originHostId,
    );
    final noteWithContext = note.copyWith(
      duration: duration,
      dayContext: dayContext,
    );

    // 1. The journal row owns the recording before any network-dependent
    //    work; failure here leaves the finished m4a on disk untouched.
    JournalAudio? journalAudio;
    try {
      journalAudio = await _persistAudio(noteWithContext);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'while persisting the day recording');
    }
    if (journalAudio == null) {
      _clearSession();
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.audioPersistFailed,
      );
      return;
    }

    // 2. Durable transcription intent. Enqueue failure is tolerated:
    //    startup repair rebuilds the job from the persisted provenance.
    final outbox = _processingOutbox;
    DayProcessingClaim? claim;
    if (outbox != null) {
      try {
        claim = await outbox.enqueueAndClaimTranscription(
          dayId: dayContext.dayId,
          activityEntryId: dayContext.activityEntryId,
          recordingSessionId: dayContext.recordingSessionId,
          audioId: journalAudio.meta.id,
          audioPath: fullPath,
          capturedAt: dayContext.capturedAt,
        );
      } catch (error, stackTrace) {
        _reportError(error, stackTrace, 'while enqueueing day transcription');
      }
      if (claim == null) {
        _clearSession();
        state = CaptureState(
          phase: CapturePhase.error,
          transcript: '',
          amplitudes: const <double>[],
          audioId: journalAudio.meta.id,
          error: CaptureError.recordingSavedPendingTranscription,
        );
        return;
      }
    }

    // 3. Foreground transcription over the finished file, driven through
    //    the claimed job's state machine so a failure hands the retry to
    //    the background runtime instead of losing the recording.
    String transcript;
    try {
      final coordinator = _attributionCoordinator;
      if (coordinator != null) {
        _transcriptAttribution = await coordinator.begin(
          providerName: 'batch-transcribe',
          modelId: 'cloud-inference',
          providerType: InferenceProviderType.genericOpenAi,
          interactionKind: AiInteractionKind.audioTranscription,
        );
      }
      final attributionSession = _transcriptAttribution;
      transcript =
          (await (attributionSession == null
                  ? _transcriber.transcribe(fullPath)
                  : _transcriber.transcribe(
                      fullPath,
                      attributionSession: attributionSession.pending,
                      terminalizeAttributionFailure: false,
                    )))
              .trim();
      if (transcript.isEmpty) {
        // The provider answered, so usage evidence exists — record an
        // unusable output rather than a failed interaction.
        if (attributionSession != null && coordinator != null) {
          await coordinator.failOutput(
            session: attributionSession,
            errorCode: 'empty_transcript',
          );
          _transcriptAttribution = null;
        }
        throw TimeoutException('No transcript was produced');
      }
    } catch (error, stackTrace) {
      await _failTranscriptAttribution(error);
      _transcriptAttribution = null;
      _reportError(error, stackTrace, 'while transcribing the day recording');
      if (outbox != null && claim != null) {
        final failure = classifyDayProcessingFailure(error);
        try {
          await outbox.markFailure(
            jobId: claim.job.id,
            claimToken: claim.token,
            failureClass: failure.failureClass,
            error: error.toString(),
            retryAfter: failure.retryAfter,
          );
        } catch (_) {}
      }
      _clearSession();
      state = CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: const <double>[],
        audioId: journalAudio.meta.id,
        error: CaptureError.recordingSavedPendingTranscription,
      );
      return;
    }

    final attached = outbox != null && claim != null
        ? await _completeForegroundProcessing(
            outbox: outbox,
            claim: claim,
            journalAudio: journalAudio,
            transcript: transcript,
            attributionSession: _transcriptAttribution,
          )
        : await _attachTranscriptToJournalAudio(
            journalAudio: journalAudio,
            transcript: transcript,
            attributionSession: _transcriptAttribution,
          );
    _transcriptAttribution = null;
    if (!attached) {
      _clearSession();
      state = CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: const <double>[],
        audioId: journalAudio.meta.id,
        error: CaptureError.recordingSavedPendingTranscription,
      );
      return;
    }

    _clearSession();
    state = CaptureState(
      phase: CapturePhase.captured,
      transcript: transcript,
      amplitudes: const <double>[],
      audioId: journalAudio.meta.id,
    );
  }

  Future<bool> _completeForegroundProcessing({
    required DayProcessingOutboxRepository outbox,
    required DayProcessingClaim claim,
    required JournalAudio journalAudio,
    required String transcript,
    TranscriptAttributionSession? attributionSession,
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
        processingJobId: job.id,
        attributionSession: attributionSession,
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

  /// Persists [transcript] as an [AudioTranscript] on [journalAudio]
  /// and mirrors the text into [JournalAudio.entryText] so the audio
  /// entry shows up with searchable content in the journal.
  Future<bool> _attachTranscriptToJournalAudio({
    required JournalAudio journalAudio,
    required String transcript,
    String? processingJobId,
    TranscriptAttributionSession? attributionSession,
  }) async {
    final coordinator = _attributionCoordinator;
    try {
      final persistenceLogic = getIt<PersistenceLogic>();
      final prepared = coordinator == null || attributionSession == null
          ? null
          : await coordinator.prepareOutput(
              session: attributionSession,
              audioEntryId: journalAudio.id,
            );
      final audioTranscript = AudioTranscript(
        created: _now(),
        library: 'batch-transcribe',
        model: 'cloud-inference',
        detectedLanguage: '-',
        transcript: transcript,
        processingJobId: processingJobId,
        id: prepared?.transcriptId,
        aiAttribution: prepared?.attribution,
      );
      final existing = journalAudio.data.transcripts ?? <AudioTranscript>[];
      final updated = journalAudio.copyWith(
        meta: await persistenceLogic.updateMetadata(journalAudio.meta),
        data: journalAudio.data.copyWith(
          transcripts: [...existing, audioTranscript],
        ),
        entryText: EntryText(plainText: transcript, markdown: transcript),
      );
      final persisted = await persistenceLogic.updateDbEntity(updated) == true;
      if (persisted && prepared != null) {
        try {
          await coordinator!.finalize(prepared);
        } catch (_) {
          // The transcript carrier is authoritative. Leave the projection
          // unchanged instead of rewriting the persisted outcome as failed.
        }
      } else if (!persisted && prepared != null && attributionSession != null) {
        await coordinator!.failOutput(
          session: attributionSession,
          errorCode: 'transcript_persistence_failed',
        );
      }
      return persisted;
    } catch (_) {
      if (attributionSession != null && coordinator != null) {
        try {
          await coordinator.failOutput(
            session: attributionSession,
            errorCode: 'transcript_persistence_failed',
          );
        } catch (_) {
          // Attribution cleanup is best-effort on this error path.
        }
      }
      return false;
    }
  }

  Future<void> _failTranscriptAttribution(Object error) async {
    final attribution = _transcriptAttribution;
    final coordinator = _attributionCoordinator;
    if (attribution == null || coordinator == null) return;
    try {
      if (error case AttributedTranscriptionException(
        :final cause,
        :final evidenceState,
      )) {
        if (evidenceState == TranscriptionEvidenceState.recorded) {
          await coordinator.failOutput(
            session: attribution,
            errorCode: cause.runtimeType.toString(),
          );
        }
        return;
      }
      await coordinator.fail(session: attribution, error: error);
    } catch (_) {
      // Attribution cleanup is best-effort on this error path.
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'daily_os_next',
        context: ErrorDescription(context),
      ),
    );
  }

  void _clearSession() {
    _recordingNote = null;
    _recordingStartedAt = null;
    _session = null;
    _transcriptAttribution = null;
  }

  void _cleanupSync() {
    _lifecycleEpoch += 1;
    final ampSub = _ampSub;
    _ampSub = null;
    if (ampSub != null) {
      unawaited(ampSub.cancel());
    }
    if (_recordingNote != null) {
      // Stop the platform recorder; the finished m4a stays on disk.
      unawaited(_recorder.stopRecording());
    }
    _clearSession();
  }

  bool _isCurrentLifecycle(int epoch) =>
      !_disposed && ref.mounted && epoch == _lifecycleEpoch;
}

/// Creates a fresh controller per route entry so a re-entry into
/// Capture starts cleanly. The Reconcile screen reads the captured
/// transcript via the capture id handed off when navigating.
// ignore: specify_nonobvious_property_types
final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
