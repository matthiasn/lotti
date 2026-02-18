import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' as rec;
import 'package:record/record.dart' show Amplitude;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recorder_controller.g.dart';

/// Interval in milliseconds for amplitude updates from the recorder.
const intervalMs = 20;

/// Default window size for VU meter RMS calculation in milliseconds
const defaultVuWindowMs = 300;

/// Reference level where 0 VU = -18 dBFS
const double vuReferenceLevelDbfs = -18;

/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for VU meter display
/// - Integration with audio player to pause playback during recording
/// - UI state management (modal visibility, indicator visibility)
///
/// The controller is kept alive to maintain recording state across navigation.
@Riverpod(keepAlive: true)
class AudioRecorderController extends _$AudioRecorderController {
  late final AudioRecorderRepository _recorderRepository;
  StreamSubscription<Amplitude>? _amplitudeSub;
  late final LoggingService _loggingService;
  String? _linkedId;
  String? _categoryId;
  AudioNote? _audioNote;
  bool _disposed = false;

  // Realtime transcription fields
  rec.AudioRecorder? _realtimeRecorder;
  StreamSubscription<double>? _realtimeAmplitudeSub;
  DateTime? _realtimeStartTime;
  String? _realtimeModelName;
  String? _realtimeProviderName;

  /// Circular buffer for storing dBFS samples for RMS calculation
  final Queue<double> _dbfsBuffer = Queue<double>();

  /// Number of samples to keep in the buffer
  int get _bufferSize => defaultVuWindowMs ~/ intervalMs;

  /// Initializes the controller with dependencies and sets up amplitude monitoring.
  ///
  /// This method:
  /// - Injects required dependencies (repository, services)
  /// - Sets up amplitude stream subscription for VU meter updates
  /// - Configures cleanup on disposal
  /// - Returns initial recording state
  @override
  AudioRecorderState build() {
    _recorderRepository = ref.watch(audioRecorderRepositoryProvider);
    _loggingService = getIt<LoggingService>();

    // Don't initialize AudioPlayerCubit here - it depends on MediaKit which might fail
    // We'll get it lazily when needed

    _amplitudeSub = _recorderRepository.amplitudeStream.listen((Amplitude amp) {
      final dBFS = amp.current;
      final vu = _calculateVu(dBFS);

      state = state.copyWith(
        progress: Duration(
          milliseconds: state.progress.inMilliseconds + intervalMs,
        ),
        dBFS: dBFS,
        vu: vu,
      );
    });

    ref.onDispose(() async {
      _disposed = true;
      await _amplitudeSub?.cancel();
      await _realtimeAmplitudeSub?.cancel();
      await _realtimeRecorder?.dispose();
    });

    // Initialize asynchronously to check permissions and transition to ready state
    // Schedule initialization for the next microtask to avoid state access during build
    Future.microtask(_initialize);

    // Start in stopped state - initialization is just for logging permissions
    return AudioRecorderState(
      status: AudioRecorderStatus.stopped,
      vu: -20,
      // Start at -20 VU (quiet)
      dBFS: -160,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
    );
  }

  /// Initialize the recorder and check permissions (for logging only)
  Future<void> _initialize() async {
    // Check if disposed before doing anything
    if (_disposed) return;

    try {
      // Check if we have permissions and log the result
      final hasPermissions = await _recorderRepository.hasPermission();

      // Check if disposed before logging
      if (_disposed) return;

      _loggingService.captureEvent(
        'Audio recorder initialization: hasPermissions=$hasPermissions',
        domain: 'recorder_controller',
        subDomain: 'initialize',
      );
    } catch (e, stackTrace) {
      // Check if disposed before logging
      if (_disposed) return;

      _loggingService.captureException(
        e,
        domain: 'recorder_controller',
        subDomain: 'initialize',
        stackTrace: stackTrace,
      );
    }
    // No state updates needed - we start in stopped state
  }

  /// Calculates VU value from dBFS using RMS over a sliding window
  double _calculateVu(double dBFS) {
    // Add new sample to buffer
    _dbfsBuffer.addLast(dBFS);

    // Remove old samples if buffer exceeds window size
    while (_dbfsBuffer.length > _bufferSize) {
      _dbfsBuffer.removeFirst();
    }

    // If buffer is empty or has very few samples, return a low VU value
    if (_dbfsBuffer.isEmpty) return -20;

    // Convert dBFS values to linear scale for RMS calculation
    double sumOfSquares = 0;
    for (final dbfs in _dbfsBuffer) {
      // Convert dBFS to linear amplitude (0 dBFS = 1.0)
      final linear = math.pow(10, dbfs / 20).toDouble();
      sumOfSquares += linear * linear;
    }

    // Calculate RMS
    final rms = math.sqrt(sumOfSquares / _dbfsBuffer.length);

    // Convert RMS back to dB
    // Formula: 20 * log10(rms) where math.log is natural log (ln)
    // So: 20 * ln(rms) / ln(10) = 20 * log10(rms)
    final rmsDb = 20 * (math.log(rms) / math.ln10);

    // Apply VU reference level: 0 VU = -18 dBFS
    // So VU in dB = dBFS - (-18) = dBFS + 18
    final vuDb = rmsDb - vuReferenceLevelDbfs;

    // Clamp to reasonable VU meter range (-20 to +3 VU)
    return vuDb.clamp(-20.0, 3.0);
  }

  /// Starts a new recording or toggles the current recording state.
  ///
  /// This method handles:
  /// - Pausing any currently playing audio
  /// - Checking recording permissions
  /// - Resume if paused, stop if recording, or start new recording
  /// - Setting the linked entry ID for the recording
  ///
  /// [linkedId] Optional ID to link this recording to an existing journal entry.
  Future<void> record({
    String? linkedId,
  }) async {
    _linkedId = linkedId;

    try {
      await _pauseAudioPlayer();

      if (await _recorderRepository.hasPermission()) {
        if (await _recorderRepository.isPaused()) {
          await resume();
        } else if (await _recorderRepository.isRecording()) {
          await stop();
        } else {
          _audioNote = await _recorderRepository.startRecording();
          if (_audioNote != null) {
            // Update state to recording while keeping existing inference preferences
            state = state.copyWith(
              status: AudioRecorderStatus.recording,
              linkedId: linkedId,
            );
          }
        }
      } else {
        _loggingService.captureEvent(
          'No audio recording permission available. Flatpak=${PortalService.isRunningInFlatpak}',
          domain: 'recorder_controller',
          subDomain: 'record_permission_denied',
        );
        // User will see no recording starts - this is the expected behavior
        // The UI remains available for user interaction
      }
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops the current recording and creates a journal entry.
  ///
  /// This method:
  /// - Stops the audio recording
  /// - Updates the audio note with final duration
  /// - Creates a journal entry via SpeechRepository
  /// - Resets the recording state
  ///
  /// Returns the ID of the created journal entry, or null if no recording exists.
  Future<String?> stop() async {
    try {
      await _recorderRepository.stopRecording();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
      _dbfsBuffer.clear(); // Clear the buffer when stopping

      // Preserve the inference preferences before resetting state
      final enableSpeechRecognition = state.enableSpeechRecognition;
      final enableTaskSummary = state.enableTaskSummary;
      final enableChecklistUpdates = state.enableChecklistUpdates;

      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        dBFS: -160,
        vu: -20,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        // Preserve the inference preferences
        enableSpeechRecognition: enableSpeechRecognition,
        enableTaskSummary: enableTaskSummary,
        enableChecklistUpdates: enableChecklistUpdates,
      );
      if (_audioNote != null) {
        final journalAudio = await SpeechRepository.createAudioEntry(
          _audioNote!,
          linkedId: _linkedId,
          categoryId: _categoryId,
        );
        final wasLinkedToTask = _linkedId != null;
        final linkedTaskId = _linkedId;
        _linkedId = null;
        final entryId = journalAudio?.meta.id;
        _audioNote = null; // Reset audio note after processing

        // Trigger automatic prompts in the background if configured for the category
        if (entryId != null && _categoryId != null) {
          // Don't await - let it run in the background so the modal can close immediately
          unawaited(
            _triggerAutomaticPrompts(
              entryId,
              _categoryId!,
              isLinkedToTask: wasLinkedToTask,
              linkedTaskId: linkedTaskId,
            ),
          );
        }

        return entryId;
      }
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        stackTrace: stackTrace,
      );
      // Ensure state is updated even if an error occurs during stop/save
      _dbfsBuffer.clear();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
      );
    }
    return null;
  }

  /// Pauses the current recording.
  /// Updates the state to reflect paused status.
  Future<void> pause() async {
    await _recorderRepository.pauseRecording();
    state = state.copyWith(status: AudioRecorderStatus.paused);
  }

  /// Resumes a paused recording.
  Future<void> resume() async {
    await _recorderRepository.resumeRecording();
    state = state.copyWith(status: AudioRecorderStatus.recording);
  }

  /// Controls visibility of the recording modal.
  /// Used to coordinate indicator display when modal is open/closed.
  /// [modalVisible] Whether the recording modal is currently visible.
  void setModalVisible({required bool modalVisible}) {
    state = state.copyWith(modalVisible: modalVisible);
  }

  /// Sets the category ID for the recording.
  /// [categoryId] Optional category to assign to the audio entry.
  void setCategoryId(String? categoryId) {
    if (categoryId != _categoryId) {
      _categoryId = categoryId;
    }
  }

  /// Sets whether to enable speech recognition for the recording.
  /// If null, uses category default settings.
  void setEnableSpeechRecognition({required bool? enable}) {
    state = state.copyWith(enableSpeechRecognition: enable);
  }

  /// Sets whether to enable task summary for the recording.
  /// If null, uses category default settings.
  void setEnableTaskSummary({required bool? enable}) {
    state = state.copyWith(enableTaskSummary: enable);
  }

  /// Sets whether to enable checklist updates for the recording.
  /// If null, uses category default settings.
  void setEnableChecklistUpdates({required bool? enable}) {
    state = state.copyWith(enableChecklistUpdates: enable);
  }

  /// Starts a realtime recording session using PCM streaming + WebSocket
  /// transcription via [RealtimeTranscriptionService].
  ///
  /// This bypasses [AudioRecorderRepository] — instead it creates a raw
  /// `AudioRecorder` and calls `startStream`
  /// at 16kHz PCM mono, the format required by the Mistral Voxtral API.
  Future<void> recordRealtime({String? linkedId}) async {
    _linkedId = linkedId;

    try {
      // Pause any playing audio first
      await _pauseAudioPlayer();

      final recorderFactory = ref.read(realtimeRecorderFactoryProvider);
      final recorder = recorderFactory();
      // Assign immediately so _cleanupRealtime() can dispose it if
      // any subsequent await (hasPermission, startStream) throws.
      _realtimeRecorder = recorder;

      final hasPerm = await recorder.hasPermission();
      if (!hasPerm) {
        await recorder.dispose();
        _realtimeRecorder = null;
        _loggingService.captureEvent(
          'No audio recording permission for realtime',
          domain: 'recorder_controller',
          subDomain: 'recordRealtime_permission_denied',
        );
        return;
      }

      // Start PCM stream at 16kHz mono (required by Mistral realtime API)
      final pcmStream = await recorder.startStream(
        const rec.RecordConfig(
          encoder: rec.AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _realtimeStartTime = DateTime.now();

      final service = ref.read(realtimeTranscriptionServiceProvider);

      // Resolve config to store model/provider names for transcript metadata
      final config = await service.resolveRealtimeConfig();
      _realtimeModelName = config?.model.providerModelId;
      _realtimeProviderName = config?.provider.name;

      // Subscribe to amplitude stream for VU meter
      _realtimeAmplitudeSub = service.amplitudeStream.listen((dbfs) {
        if (_disposed) return;
        final startTime = _realtimeStartTime;
        if (startTime == null) return;
        final vu = _calculateVu(dbfs);
        state = state.copyWith(
          progress: DateTime.now().difference(startTime),
          dBFS: dbfs,
          vu: vu,
        );
      });

      state = state.copyWith(
        status: AudioRecorderStatus.recording,
        isRealtimeMode: true,
        linkedId: linkedId,
        partialTranscript: null,
      );

      // Start realtime transcription — onDelta accumulates into partialTranscript
      await service.startRealtimeTranscription(
        pcmStream: pcmStream,
        onDelta: (delta) {
          if (_disposed) return;
          final current = state.partialTranscript ?? '';
          state = state.copyWith(partialTranscript: '$current$delta');
        },
      );

      _loggingService.captureEvent(
        'Realtime recording started',
        domain: 'recorder_controller',
        subDomain: 'recordRealtime',
      );
    } catch (exception, stackTrace) {
      // Clean up on failure
      await _cleanupRealtime();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        isRealtimeMode: false,
        partialTranscript: null,
      );
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        subDomain: 'recordRealtime',
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops the realtime recording session, creates a journal audio entry
  /// with the transcript, and triggers remaining automatic prompts.
  ///
  /// Returns the ID of the created journal entry, or null on error.
  Future<String?> stopRealtime() async {
    // Capture metadata in locals before any cleanup nulls them (#6).
    final modelName = _realtimeModelName;
    final providerName = _realtimeProviderName;

    try {
      // Cancel amplitude subscription
      await _realtimeAmplitudeSub?.cancel();
      _realtimeAmplitudeSub = null;

      final duration = _realtimeStartTime != null
          ? DateTime.now().difference(_realtimeStartTime!)
          : state.progress;

      // Build output path using the same directory structure as standard recording
      final created = _realtimeStartTime ?? DateTime.now();
      final fileName = DateFormat('yyyy-MM-dd_HH-mm-ss-S').format(created);
      final day = DateFormat('yyyy-MM-dd').format(created);
      final relativePath = '/audio/$day/';
      final directory = await createAssetDirectory(relativePath);
      final outputPath = '$directory$fileName';

      // Stop the service — this stops the recorder, sends endAudio,
      // waits for transcription.done, writes WAV, converts to M4A
      final service = ref.read(realtimeTranscriptionServiceProvider);
      final recorder = _realtimeRecorder;
      final result = await service.stop(
        stopRecorder: () async {
          await recorder?.stop();
        },
        outputPath: outputPath,
      );

      // Dispose the recorder
      await recorder?.dispose();
      _realtimeRecorder = null;
      _realtimeStartTime = null;

      // Determine actual file name from the result path
      final audioFilePath = result.audioFilePath;
      final actualFileName = audioFilePath != null
          ? audioFilePath.split('/').last
          : '$fileName.m4a';

      // Create AudioNote for the journal entry
      final audioNote = AudioNote(
        createdAt: created,
        audioFile: actualFileName,
        audioDirectory: relativePath,
        duration: duration,
      );

      // Preserve inference preferences before resetting state
      final enableSpeechRecognition = state.enableSpeechRecognition;
      final enableTaskSummary = state.enableTaskSummary;
      final enableChecklistUpdates = state.enableChecklistUpdates;

      _dbfsBuffer.clear();
      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        dBFS: -160,
        vu: -20,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        enableSpeechRecognition: enableSpeechRecognition,
        enableTaskSummary: enableTaskSummary,
        enableChecklistUpdates: enableChecklistUpdates,
      );

      // Create the journal audio entry
      final journalAudio = await SpeechRepository.createAudioEntry(
        audioNote,
        linkedId: _linkedId,
        categoryId: _categoryId,
      );

      final wasLinkedToTask = _linkedId != null;
      final linkedTaskId = _linkedId;
      _linkedId = null;
      final entryId = journalAudio?.meta.id;

      // Save the realtime transcript on the audio entry
      if (entryId != null &&
          result.transcript.isNotEmpty &&
          journalAudio != null) {
        await _saveRealtimeTranscript(
          journalAudio: journalAudio,
          transcript: result.transcript,
          providerName: providerName ?? 'Mistral',
          modelId: modelName ?? 'voxtral-mini',
          detectedLanguage: result.detectedLanguage,
        );
      }

      // Trigger automatic prompts, but skip batch transcription
      if (entryId != null && _categoryId != null) {
        unawaited(
          _triggerAutomaticPrompts(
            entryId,
            _categoryId!,
            isLinkedToTask: wasLinkedToTask,
            linkedTaskId: linkedTaskId,
            skipTranscription: true,
          ),
        );
      }

      _realtimeModelName = null;
      _realtimeProviderName = null;

      _loggingService.captureEvent(
        'Realtime recording stopped: '
        'transcriptLen=${result.transcript.length}, '
        'audioFile=${result.audioFilePath}, '
        'usedFallback=${result.usedTranscriptFallback}',
        domain: 'recorder_controller',
        subDomain: 'stopRealtime',
      );

      return entryId;
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        subDomain: 'stopRealtime',
        stackTrace: stackTrace,
      );
      _dbfsBuffer.clear();
      await _cleanupRealtime();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
        isRealtimeMode: false,
        partialTranscript: null,
      );
    }
    return null;
  }

  /// Cancels the realtime recording session without saving.
  Future<void> cancelRealtime() async {
    try {
      await _cleanupRealtime();

      // Invalidate the provider so the next recordRealtime() gets a fresh
      // instance. Using dispose() on the singleton would leave it in a
      // broken state (nulled subscriptions) while the provider still
      // holds the same reference.
      ref.invalidate(realtimeTranscriptionServiceProvider);

      _dbfsBuffer.clear();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
        isRealtimeMode: false,
        partialTranscript: null,
      );

      _loggingService.captureEvent(
        'Realtime recording cancelled',
        domain: 'recorder_controller',
        subDomain: 'cancelRealtime',
      );
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        subDomain: 'cancelRealtime',
        stackTrace: stackTrace,
      );
    }
  }

  /// Saves the realtime transcript as an [AudioTranscript] on the
  /// [JournalAudio] entry, making it searchable and visible.
  Future<void> _saveRealtimeTranscript({
    required JournalAudio journalAudio,
    required String transcript,
    required String providerName,
    required String modelId,
    String? detectedLanguage,
  }) async {
    final persistenceLogic = getIt<PersistenceLogic>();
    final audioTranscript = AudioTranscript(
      created: DateTime.now(),
      library: providerName,
      model: modelId,
      detectedLanguage: detectedLanguage ?? '-',
      transcript: transcript,
    );

    final existingTranscripts = journalAudio.data.transcripts ?? [];
    final updated = journalAudio.copyWith(
      meta: await persistenceLogic.updateMetadata(journalAudio.meta),
      data: journalAudio.data.copyWith(
        transcripts: [...existingTranscripts, audioTranscript],
      ),
      entryText: EntryText(
        plainText: transcript,
        markdown: transcript,
      ),
    );
    await persistenceLogic.updateDbEntity(updated);
  }

  /// Cleans up realtime recording resources.
  Future<void> _cleanupRealtime() async {
    try {
      await _realtimeAmplitudeSub?.cancel();
    } catch (_) {}
    _realtimeAmplitudeSub = null;
    try {
      await _realtimeRecorder?.stop();
    } catch (_) {}
    try {
      await _realtimeRecorder?.dispose();
    } catch (_) {}
    _realtimeRecorder = null;
    _realtimeStartTime = null;
    _realtimeModelName = null;
    _realtimeProviderName = null;
  }

  /// Pauses any currently playing audio. Shared between [record] and
  /// [recordRealtime].
  Future<void> _pauseAudioPlayer() async {
    try {
      final playerState = ref.read(audioPlayerControllerProvider);
      if (playerState.status == AudioPlayerStatus.playing) {
        await ref.read(audioPlayerControllerProvider.notifier).pause();
      }
    } catch (e) {
      _loggingService.captureEvent(
        'Audio player not available, continuing without audio pause: $e',
        domain: 'recorder_controller',
        subDomain: 'pauseAudioPlayer',
      );
    }
  }

  /// Triggers automatic prompts based on category settings and user preferences
  Future<void> _triggerAutomaticPrompts(
    String entryId,
    String categoryId, {
    required bool isLinkedToTask,
    String? linkedTaskId,
    bool skipTranscription = false,
  }) async {
    final trigger = ref.read(automaticPromptTriggerProvider);
    await trigger.triggerAutomaticPrompts(
      entryId,
      categoryId,
      state,
      isLinkedToTask: isLinkedToTask,
      linkedTaskId: linkedTaskId,
      skipTranscription: skipTranscription,
    );
  }
}

/// Factory for creating [rec.AudioRecorder] instances for realtime recording.
/// Override in tests to inject a mock recorder.
final Provider<rec.AudioRecorder Function()> realtimeRecorderFactoryProvider =
    Provider<rec.AudioRecorder Function()>((ref) => rec.AudioRecorder.new);
