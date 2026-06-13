import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai_chat/services/audio_transcription_service.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' as record;

export 'package:lotti/features/daily_os_next/state/capture_state.dart';

part 'capture_controller_cleanup.dart';

/// Drives the Capture screen's recording lifecycle.
///
/// Two transcription paths:
/// * **Realtime (primary)** — when [RealtimeTranscriptionService] can
///   resolve a config (MLX Qwen3 locally, or Mistral cloud), we stream
///   PCM frames through a raw `record.AudioRecorder` and let the
///   service surface transcript deltas live. The audio is converted to
///   `.m4a` at stop and persisted as a [JournalAudio].
/// * **Batch (fallback)** — when no realtime model is configured, we
///   fall back to a file-backed [AudioRecorderRepository] recording
///   plus a post-recording [AudioTranscriptionService.transcribe]
///   round-trip.
///
/// Test seam: inject any of the constructor parameters to keep tests
/// deterministic and off the real mic / cloud.
const _minDbfs = -45.0;
const double _minVisualDbfs = CaptureState.defaultDbfs;

class CaptureController extends Notifier<CaptureState>
    with _CaptureRealtimeCleanup {
  CaptureController({
    AudioRecorderRepository? recorder,
    AudioTranscriptionService? transcriber,
    RealtimeTranscriptionService? realtimeService,
    record.AudioRecorder Function()? realtimeRecorderFactory,
    Future<JournalAudio?> Function(AudioNote)? persistAudio,
    Directory Function()? docDir,
    DateTime Function()? now,
  }) : _recorderOverride = recorder,
       _transcriberOverride = transcriber,
       _realtimeServiceOverride = realtimeService,
       _realtimeRecorderFactory =
           realtimeRecorderFactory ?? record.AudioRecorder.new,
       _persistAudioOverride = persistAudio,
       _docDir = docDir ?? getDocumentsDirectory,
       _now = now ?? DateTime.now;

  final AudioRecorderRepository? _recorderOverride;
  final AudioTranscriptionService? _transcriberOverride;
  final RealtimeTranscriptionService? _realtimeServiceOverride;
  final record.AudioRecorder Function() _realtimeRecorderFactory;
  final Future<JournalAudio?> Function(AudioNote)? _persistAudioOverride;
  final Directory Function() _docDir;
  @override
  final DateTime Function() _now;

  /// Rolling-window size for the live waveform (~1.6s at 20ms cadence).
  static const _maxAmplitudeSamples = 80;

  /// dBFS floor used to normalise amplitudes into 0..1. Values below
  /// this clamp to 0; -45 keeps speech visible without amplifying room
  /// noise into oscillating full-height bars.

  /// Minimum extra characters the full-file batch transcript must have
  /// over the realtime `done` text before we prefer the batch result.
  /// Realtime and batch routinely differ by a few characters of
  /// punctuation/whitespace; this margin avoids swapping out a good
  /// realtime transcript for a near-identical batch one and only kicks
  /// in when batch is meaningfully longer (i.e. realtime truncated).

  late final AudioRecorderRepository _recorder =
      _recorderOverride ?? AudioRecorderRepository();
  @override
  late final AudioTranscriptionService _transcriber =
      _transcriberOverride ?? ref.read(audioTranscriptionServiceProvider);
  @override
  late final RealtimeTranscriptionService _realtimeService =
      _realtimeServiceOverride ??
      ref.read(realtimeTranscriptionServiceProvider);
  late final Future<JournalAudio?> Function(AudioNote) _persistAudio =
      _persistAudioOverride ?? SpeechRepository.createAudioEntry;

  /// Active realtime transcription config — captured at start time so
  /// the AudioTranscript persisted on the JournalAudio carries the
  /// provider + model that actually produced the text.
  ({AiConfigInferenceProvider provider, AiConfigModel model})?
  _activeRealtimeConfig;

  @override
  StreamSubscription<record.Amplitude>? _ampSub;
  @override
  StreamSubscription<double>? _realtimeAmpSub;
  @override
  record.AudioRecorder? _realtimeRecorder;

  // Pre-computed audio path data so we can build the AudioNote after
  // the realtime service writes the .m4a file.
  @override
  String? _realtimeOutputBasePath;
  @override
  String? _realtimeAudioDirectory;
  @override
  String? _realtimeAudioFile;

  // Batch fallback state.
  @override
  AudioNote? _recordingNote;
  @override
  DateTime? _recordingStartedAt;
  @override
  bool _verifyRealtimeTranscript = true;

  /// Marks whether the current session is using the realtime path.
  /// `null` outside of a session.
  @override
  bool? _activeIsRealtime;

  @override
  CaptureState build() {
    ref.onDispose(_cleanupSync);
    return const CaptureState.idle();
  }

  /// Drives the phase transitions. Voice-button tap triggers this.
  Future<void> toggle() async {
    switch (state.phase) {
      case CapturePhase.idle:
      case CapturePhase.error:
        await _beginListening();
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

  Future<void> _beginListening() async {
    // Mistral cloud realtime is preferred for interactive latency; MLX is the
    // automatic fallback when no Mistral realtime model is configured. The
    // ordering lives in `RealtimeTranscriptionService.resolveRealtimeConfig`
    // so every realtime caller shares the same preference.
    final realtimeConfig = await _realtimeService.resolveRealtimeConfig();
    _activeRealtimeConfig = realtimeConfig;
    if (realtimeConfig != null) {
      await _beginListeningRealtime();
    } else {
      await _beginListeningBatch();
    }
  }

  Future<void> _beginListeningRealtime() async {
    final recorder = _realtimeRecorderFactory();
    final hasPerm = await recorder.hasPermission();
    if (!hasPerm) {
      await recorder.dispose();
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.microphonePermissionDenied,
      );
      return;
    }

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
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.recordingStartFailed,
      );
      return;
    }

    _realtimeRecorder = recorder;
    _activeIsRealtime = true;
    _recordingStartedAt = _now();
    state = const CaptureState(
      phase: CapturePhase.listening,
      transcript: '',
      amplitudes: <double>[],
    );

    _realtimeAmpSub = _realtimeService.amplitudeStream.listen(
      (dbfs) {
        if (state.phase != CapturePhase.listening) return;
        final next = [...state.amplitudes, _normaliseDbfs(dbfs)];
        final clipped = next.length > _maxAmplitudeSamples
            ? next.sublist(next.length - _maxAmplitudeSamples)
            : next;
        state = state.copyWith(
          amplitudes: clipped,
          dbfs: _sanitizeVisualDbfs(dbfs),
        );
      },
      onError: (Object _) {
        // Amplitude stream errors are non-fatal — keep recording.
      },
    );

    // Pre-compute the on-disk path so the realtime service writes the
    // m4a inside `/audio/YYYY-MM-DD/`, matching the layout journal
    // audio entries use everywhere else.
    final now = _now();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(now);
    final day = DateFormat('yyyy-MM-dd').format(now);
    _realtimeAudioDirectory = '/audio/$day/';
    _realtimeAudioFile = '$timestamp.m4a';
    final docDir = _docDir();
    final absoluteDir = '${docDir.path}$_realtimeAudioDirectory';
    await Directory(absoluteDir).create(recursive: true);
    _realtimeOutputBasePath = '$absoluteDir$timestamp';

    try {
      await _realtimeService.startRealtimeTranscription(
        pcmStream: pcmStream,
        onDelta: _onRealtimeDelta,
        config: _activeRealtimeConfig,
      );
    } catch (error, stackTrace) {
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

  Future<void> _beginListeningBatch() async {
    final permitted = await _recorder.hasPermission();
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
    if (note == null) {
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.recordingStartFailed,
      );
      return;
    }
    _recordingNote = note;
    _recordingStartedAt = _now();
    _activeIsRealtime = false;
    state = const CaptureState(
      phase: CapturePhase.listening,
      transcript: '',
      amplitudes: <double>[],
    );
    _ampSub = _recorder.amplitudeStream.listen(
      _onBatchAmplitude,
      onError: (Object _) {
        // Amplitude stream errors are non-fatal — keep recording.
      },
    );
  }

  void _onBatchAmplitude(record.Amplitude amp) {
    if (state.phase != CapturePhase.listening) return;
    final next = [...state.amplitudes, _normaliseDbfs(amp.current)];
    final clipped = next.length > _maxAmplitudeSamples
        ? next.sublist(next.length - _maxAmplitudeSamples)
        : next;
    state = state.copyWith(
      amplitudes: clipped,
      dbfs: _sanitizeVisualDbfs(amp.current),
    );
  }

  Future<void> _finishListening() async {
    if (_activeIsRealtime == true) {
      await _finishListeningRealtime();
    } else {
      await _finishListeningBatch();
    }
  }

  /// Test-only seam for the realtime finish path: the
  /// `noActiveRealtimeSession` guard below is defensive (the public state
  /// machine always sets the session fields before reaching it), so tests
  /// invoke the method directly to pin the guard's behavior.
  @visibleForTesting
  Future<void> debugFinishListeningRealtime() => _finishListeningRealtime();

  Future<void> _finishListeningRealtime() async {
    final recorder = _realtimeRecorder;
    final outputBase = _realtimeOutputBasePath;
    final audioDir = _realtimeAudioDirectory;
    final audioFile = _realtimeAudioFile;
    final startedAt = _recordingStartedAt;
    if (recorder == null ||
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
        stopRecorder: () async {
          try {
            await recorder.stop();
          } catch (_) {}
        },
        outputPath: outputBase,
      );
    } catch (error, stackTrace) {
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
        error: CaptureError.realtimeTranscriptionFailed,
      );
      return;
    }

    // The service may have written `.wav` if m4a conversion failed.
    final resolvedAudioFile = result.audioFilePath != null
        ? result.audioFilePath!.split('/').last
        : audioFile;
    final duration = startedAt == null
        ? Duration.zero
        : _now().difference(startedAt);
    final note = AudioNote(
      createdAt: startedAt ?? _now(),
      audioFile: resolvedAudioFile,
      audioDirectory: audioDir,
      duration: duration,
    );

    JournalAudio? journalAudio;
    try {
      journalAudio = await _persistAudio(note);
    } catch (_) {
      // Persistence is best-effort — surface the transcript anyway.
    }

    final realtimeTranscript = result.transcript.trim();
    final finalTranscript = await _resolveRealtimeFinalTranscript(
      result: result,
      realtimeTranscript: realtimeTranscript,
    );
    if (journalAudio != null && finalTranscript.isNotEmpty) {
      final config = _activeRealtimeConfig;
      await _attachTranscriptToJournalAudio(
        journalAudio: journalAudio,
        transcript: finalTranscript,
        library: config?.provider.name ?? 'realtime',
        model: config?.model.providerModelId ?? 'unknown',
        detectedLanguage: result.detectedLanguage ?? '-',
      );
    }

    try {
      await recorder.dispose();
    } catch (_) {}
    _realtimeRecorder = null;
    _realtimeOutputBasePath = null;
    _realtimeAudioDirectory = null;
    _realtimeAudioFile = null;
    _recordingStartedAt = null;
    _activeIsRealtime = null;
    _activeRealtimeConfig = null;
    _verifyRealtimeTranscript = true;

    state = CaptureState(
      phase: CapturePhase.captured,
      transcript: finalTranscript,
      amplitudes: const <double>[],
      audioId: journalAudio?.meta.id,
    );
  }

  Future<void> _finishListeningBatch() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _recorder.stopRecording();
    final note = _recordingNote;
    final startedAt = _recordingStartedAt;
    if (note == null) {
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.noAudioRecorded,
      );
      _recordingStartedAt = null;
      _activeIsRealtime = null;
      return;
    }

    state = state.copyWith(phase: CapturePhase.transcribing);

    final docDir = _docDir();
    final fullPath = '${docDir.path}${note.audioDirectory}${note.audioFile}';
    final duration = startedAt == null
        ? Duration.zero
        : _now().difference(startedAt);
    final noteWithDuration = note.copyWith(duration: duration);

    String transcript;
    try {
      transcript = (await _transcriber.transcribe(fullPath)).trim();
    } catch (e) {
      state = const CaptureState(
        phase: CapturePhase.error,
        transcript: '',
        amplitudes: <double>[],
        error: CaptureError.transcriptionFailed,
      );
      _recordingNote = null;
      _recordingStartedAt = null;
      _activeIsRealtime = null;
      return;
    }

    JournalAudio? journalAudio;
    try {
      journalAudio = await _persistAudio(noteWithDuration);
    } catch (_) {
      // Persistence is best-effort — surface the transcript anyway.
    }

    if (journalAudio != null && transcript.isNotEmpty) {
      await _attachTranscriptToJournalAudio(
        journalAudio: journalAudio,
        transcript: transcript,
        library: 'batch-transcribe',
        model: 'cloud-inference',
        detectedLanguage: '-',
      );
    }

    _recordingNote = null;
    _recordingStartedAt = null;
    _activeIsRealtime = null;
    _activeRealtimeConfig = null;
    _verifyRealtimeTranscript = true;
    state = CaptureState(
      phase: CapturePhase.captured,
      transcript: transcript,
      amplitudes: const <double>[],
      audioId: journalAudio?.meta.id,
    );
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
