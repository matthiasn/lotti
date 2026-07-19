import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/audio_recording_path.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/vu_meter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' as rec;
import 'package:record/record.dart' show Amplitude;

/// Interval in milliseconds for amplitude updates from the recorder.
const intervalMs = 20;

/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for VU meter display
/// - Integration with audio player to pause playback during recording
/// - UI state management (modal visibility, indicator visibility)
///
/// The controller is kept alive to maintain recording state across navigation.
final audioRecorderControllerProvider =
    NotifierProvider<AudioRecorderController, AudioRecorderState>(
      AudioRecorderController.new,
      name: 'audioRecorderControllerProvider',
    );

class AudioRecorderController extends Notifier<AudioRecorderState> {
  late final AudioRecorderRepository _recorderRepository;
  StreamSubscription<Amplitude>? _amplitudeSub;
  late final DomainLogger _loggingService;
  String? _linkedId;
  String? _categoryId;
  AudioNote? _audioNote;
  bool _disposed = false;
  bool _terminalActionInProgress = false;
  int _realtimeEpoch = 0;

  // Realtime transcription fields
  rec.AudioRecorder? _realtimeRecorder;
  RealtimeTranscriptionService? _activeRealtimeService;
  DurableRealtimeCapture? _realtimeCapture;
  StreamSubscription<double>? _realtimeAmplitudeSub;
  DateTime? _realtimeStartTime;
  String? _realtimeModelName;
  String? _realtimeProviderName;

  /// Sliding-window VU meter driving the live level display.
  final VuMeter _vuMeter = VuMeter(
    windowSamples: defaultVuWindowMs ~/ intervalMs,
  );

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
    _loggingService = getIt<DomainLogger>();

    // Don't initialize AudioPlayerCubit here - it depends on MediaKit which might fail
    // We'll get it lazily when needed

    _amplitudeSub = _recorderRepository.amplitudeStream.listen((Amplitude amp) {
      // While paused the recorder keeps polling amplitude, but the elapsed
      // timer and level meter must freeze so the displayed duration matches the
      // audio actually captured. Dropping these samples holds progress/vu/dBFS
      // at their pre-pause values until the recording resumes.
      if (state.status == AudioRecorderStatus.paused) return;

      final dBFS = amp.current;
      final vu = _vuMeter.addSample(dBFS);

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
      _realtimeEpoch += 1;
      await _amplitudeSub?.cancel();
      await _cleanupRealtime();
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

      _loggingService.log(
        LogDomain.speech,
        'Audio recorder initialization: hasPermissions=$hasPermissions',
        subDomain: 'initialize',
      );
    } catch (e, stackTrace) {
      // Check if disposed before logging
      if (_disposed) return;

      _loggingService.error(
        LogDomain.speech,
        e,
        stackTrace: stackTrace,
        subDomain: 'initialize',
      );
    }
    // No state updates needed - we start in stopped state
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
        _loggingService.log(
          LogDomain.speech,
          'No audio recording permission available. Flatpak=${PortalService.isRunningInFlatpak}',
          subDomain: 'record_permission_denied',
        );
        // User will see no recording starts - this is the expected behavior
        // The UI remains available for user interaction
      }
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'recorder_controller',
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
    if (_terminalActionInProgress) return null;

    _terminalActionInProgress = true;
    final note = _audioNote;
    final linkedTaskId = _linkedId;
    final categoryId = _categoryId;
    final duration = state.progress;
    _audioNote = null;
    _linkedId = null;

    try {
      await _recorderRepository.stopRecording();
      _vuMeter.reset();

      // Preserve the inference preferences before resetting state
      final enableSpeechRecognition = state.enableSpeechRecognition;

      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        dBFS: -160,
        vu: -20,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        // Preserve the inference preferences
        enableSpeechRecognition: enableSpeechRecognition,
      );

      if (note != null) {
        final journalAudio = await SpeechRepository.createAudioEntry(
          note.copyWith(duration: duration),
          linkedId: linkedTaskId,
          categoryId: categoryId,
        );
        final entryId = journalAudio?.meta.id;

        // Trigger automatic prompts in the background via profile-driven automation
        if (entryId != null && linkedTaskId != null) {
          // Don't await - let it run in the background so the modal can close immediately
          unawaited(
            _triggerAutomaticPrompts(
              entryId,
              linkedTaskId: linkedTaskId,
            ),
          );
        }

        return entryId;
      }
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'recorder_controller',
      );
      // Ensure state is updated even if an error occurs during stop/save
      _vuMeter.reset();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
      );
    } finally {
      _terminalActionInProgress = false;
    }
    return null;
  }

  /// Cancels the current standard recording, discarding it entirely.
  ///
  /// In contrast to [stop], this method:
  /// - Stops the recorder and deletes the partially-recorded audio file
  /// - Creates **no** journal entry
  /// - Triggers **no** transcription, automatic prompts, or task-agent wake
  /// - Resets state to stopped (preserving inference preferences)
  ///
  /// The recording is gone as if it never happened — used by the modal's
  /// cancel (X) control so the user can back out of a recording without it
  /// turning into a transcript and task summary. The realtime flow has its
  /// own [cancelRealtime]; this handles the file-based standard flow.
  Future<void> cancel() async {
    if (_terminalActionInProgress) return;

    final note = _audioNote;
    // Nothing to discard. Also guards against a double-tap (or a stop racing a
    // cancel): once the note is claimed below, a second call exits here instead
    // of stopping/deleting a recording that is already being torn down.
    if (note == null) return;

    _terminalActionInProgress = true;
    // Claim the recording and clear the UI synchronously, before any await, so
    // concurrent calls can't re-run teardown and the recording indicator/modal
    // clear immediately rather than lingering through the async file deletion.
    _audioNote = null;
    _linkedId = null;
    _vuMeter.reset();

    // Preserve the inference preferences before resetting state.
    final enableSpeechRecognition = state.enableSpeechRecognition;
    state = AudioRecorderState(
      status: AudioRecorderStatus.stopped,
      dBFS: -160,
      vu: -20,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
      enableSpeechRecognition: enableSpeechRecognition,
    );

    try {
      await _recorderRepository.stopRecording();
      await _recorderRepository.deleteRecording(note);
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'cancel',
      );
    } finally {
      _loggingService.log(
        LogDomain.speech,
        'Recording cancelled and discarded',
        subDomain: 'cancel',
      );
      _terminalActionInProgress = false;
    }
  }

  /// Pauses the current recording.
  ///
  /// Updates the state to paused and drops the level meter to its resting
  /// (silent) values so the VU meter / orb visualizer reads as quiet rather
  /// than frozen mid-level — a frozen loud needle would look like the app
  /// hung. The elapsed [AudioRecorderState.progress] is intentionally left
  /// untouched so the timer holds; the amplitude listener in [build] then drops
  /// incoming samples until [resume] restarts metering.
  Future<void> pause() async {
    await _recorderRepository.pauseRecording();
    state = state.copyWith(
      status: AudioRecorderStatus.paused,
      vu: -20,
      dBFS: -160,
    );
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

  // ---------------------------------------------------------------
  // Realtime PCM-streaming transcription flow
  // ---------------------------------------------------------------

  /// Starts a realtime recording session using PCM streaming + WebSocket
  /// transcription via [RealtimeTranscriptionService].
  ///
  /// This bypasses [AudioRecorderRepository] — instead it creates a raw
  /// `AudioRecorder` and calls `startStream`
  /// at 16kHz PCM mono, the format required by the Mistral Voxtral API.
  Future<void> recordRealtime({String? linkedId}) async {
    final epoch = ++_realtimeEpoch;
    _linkedId = linkedId;

    try {
      // Pause any playing audio first
      await _pauseAudioPlayer();
      if (!_isCurrentRealtimeEpoch(epoch)) return;

      final service = ref.read(realtimeTranscriptionServiceProvider);
      final createdAt = DateTime.now();
      final capture = await service.prepareDefaultDurableCapture(
        assetRootDirectory: getDocumentsDirectory(),
        createdAt: createdAt,
        origin: AudioCaptureOrigin.journalAudio,
        intent: AudioCaptureIntent.journalEntry,
        metadata: linkedId == null
            ? const <String, String>{}
            : <String, String>{'linkedId': linkedId},
      );
      if (!_isCurrentRealtimeEpoch(epoch)) {
        await capture.discard();
        return;
      }
      _activeRealtimeService = service;
      _realtimeCapture = capture;

      final recorderFactory = ref.read(realtimeRecorderFactoryProvider);
      final recorder = recorderFactory();
      // Assign immediately so _cleanupRealtime() can dispose it if
      // any subsequent await (hasPermission, startStream) throws.
      _realtimeRecorder = recorder;

      final hasPerm = await recorder.hasPermission();
      if (!_isCurrentRealtimeEpoch(epoch)) {
        await recorder.dispose();
        await capture.discard();
        return;
      }
      if (!hasPerm) {
        await recorder.dispose();
        await capture.discard();
        _realtimeCapture = null;
        _realtimeRecorder = null;
        _loggingService.log(
          LogDomain.speech,
          'No audio recording permission for realtime',
          subDomain: 'recordRealtime_permission_denied',
        );
        return;
      }

      // Resolve backend metadata before starting the microphone so durable
      // PCM subscription is the first awaited operation after startStream.
      final config = await service.resolveRealtimeConfig();
      if (!_isCurrentRealtimeEpoch(epoch)) {
        await recorder.dispose();
        await capture.discard();
        return;
      }
      _realtimeModelName = config?.model.providerModelId;
      _realtimeProviderName = config?.provider.name;

      // Start PCM stream at 16kHz mono (required by Mistral realtime API)
      final pcmStream = await recorder.startStream(
        const rec.RecordConfig(
          encoder: rec.AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      if (!_isCurrentRealtimeEpoch(epoch)) {
        try {
          await recorder.stop();
        } catch (_) {}
        await recorder.dispose();
        await capture.discard();
        return;
      }
      _realtimeStartTime = createdAt;

      // Subscribe to amplitude stream for VU meter
      _realtimeAmplitudeSub = service.amplitudeStream.listen((dbfs) {
        if (!_isCurrentRealtimeEpoch(epoch)) return;
        final startTime = _realtimeStartTime;
        if (startTime == null) return;
        final vu = _vuMeter.addSample(dbfs);
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
        capture: capture,
        pcmStream: pcmStream,
        onDelta: (delta) {
          if (!_isCurrentRealtimeEpoch(epoch)) return;
          final current = state.partialTranscript ?? '';
          state = state.copyWith(partialTranscript: '$current$delta');
        },
        onCaptureFailure: (_, _) {
          if (!_isCurrentRealtimeEpoch(epoch) || !state.isRealtimeMode) return;
          unawaited(stopRealtime());
        },
        config: config,
        resolveConfigWhenAbsent: false,
      );
      if (!_isCurrentRealtimeEpoch(epoch)) {
        await service.stopAndRetainForRecovery(
          capture: capture,
          stopRecorder: () async {
            await recorder.stop();
          },
        );
        await recorder.dispose();
        return;
      }

      _loggingService.log(
        LogDomain.speech,
        'Realtime recording started',
        subDomain: 'recordRealtime',
      );
    } catch (exception, stackTrace) {
      if (!_isCurrentRealtimeEpoch(epoch)) return;
      // Clean up on failure
      await _cleanupRealtime();
      _realtimeCapture = null;
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        isRealtimeMode: false,
        partialTranscript: null,
      );
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'recordRealtime',
      );
    }
  }

  /// Stops the realtime recording session, creates a journal audio entry
  /// with the transcript, and triggers remaining automatic prompts.
  ///
  /// Returns the ID of the created journal entry, or null on error.
  Future<String?> stopRealtime() async {
    if (_terminalActionInProgress) return null;
    _terminalActionInProgress = true;
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

      // Build output path using the same directory structure as standard
      // recording.
      final created = _realtimeStartTime ?? DateTime.now();
      final recordingPath = AudioRecordingPath.forTimestamp(created);
      final relativePath = recordingPath.relativeDirectory;
      final directory = await createAssetDirectory(relativePath);
      final outputPath = recordingPath.outputPathIn(
        directory,
        recordingSessionId: _realtimeCapture!.recordingSessionId,
      );

      // Stop the service — this stops the recorder, sends endAudio,
      // waits for transcription.done, and finalizes the durable WAV
      final service = ref.read(realtimeTranscriptionServiceProvider);
      final recorder = _realtimeRecorder;
      final capture = _realtimeCapture!;
      final result = await service.stop(
        capture: capture,
        stopRecorder: () async {
          await recorder?.stop();
        },
        outputPath: outputPath,
      );
      if (result.recordingSessionId != capture.recordingSessionId) {
        throw StateError('Realtime stop result belongs to another capture');
      }

      // Dispose the recorder
      await recorder?.dispose();
      _realtimeRecorder = null;
      _activeRealtimeService = null;
      _realtimeStartTime = null;

      if (result.captureDisposition != RealtimeCaptureDisposition.complete) {
        _vuMeter.reset();
        state = state.copyWith(
          status: AudioRecorderStatus.stopped,
          progress: Duration.zero,
          dBFS: -160,
          vu: -20,
          isRealtimeMode: false,
          partialTranscript: null,
          lastSaveOutcome:
              result.captureDisposition == RealtimeCaptureDisposition.noAudio
              ? AudioRecorderSaveOutcome.noAudio
              : AudioRecorderSaveOutcome.savedPendingRecovery,
        );
        _realtimeCapture = null;
        return null;
      }

      // Only create an AudioNote when an actual audio file was produced.
      // audioFilePath is null when no PCM data was captured (e.g. very short
      // recording), and using a fabricated path would create a broken reference.
      final audioFilePath = result.audioFilePath;
      final audioNote = audioFilePath != null
          ? AudioNote(
              createdAt: created,
              audioFile: audioFilePath.split('/').last,
              audioDirectory: relativePath,
              duration: result.audioDuration ?? duration,
            )
          : null;
      if (audioNote == null) {
        _vuMeter.reset();
        state = state.copyWith(
          status: AudioRecorderStatus.stopped,
          progress: Duration.zero,
          dBFS: -160,
          vu: -20,
          isRealtimeMode: false,
          partialTranscript: null,
          lastSaveOutcome: AudioRecorderSaveOutcome.noAudio,
        );
        _realtimeCapture = null;
        return null;
      }

      // Preserve inference preferences before resetting state
      final enableSpeechRecognition = state.enableSpeechRecognition;

      _vuMeter.reset();
      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        dBFS: -160,
        vu: -20,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        enableSpeechRecognition: enableSpeechRecognition,
      );

      // Create the journal audio entry (only when we have an actual audio file)
      final journalAudio = await SpeechRepository.createAudioEntry(
        audioNote,
        linkedId: _linkedId,
        categoryId: _categoryId,
      );
      if (journalAudio == null) {
        state = state.copyWith(
          lastSaveOutcome: AudioRecorderSaveOutcome.savedPendingRecovery,
        );
        _realtimeCapture = null;
        return null;
      }
      var ownershipBound = true;
      try {
        await _realtimeCapture!.markCommitted(
          journalAudioId: journalAudio.meta.id,
        );
      } catch (error, stackTrace) {
        ownershipBound = false;
        _loggingService.error(
          LogDomain.speech,
          error,
          stackTrace: stackTrace,
          subDomain: 'stopRealtime.bindOwnership',
        );
      }
      if (!ownershipBound) {
        state = state.copyWith(
          lastSaveOutcome: AudioRecorderSaveOutcome.savedPendingRecovery,
        );
        _realtimeCapture = null;
        return null;
      }

      final linkedTaskId = _linkedId;
      _linkedId = null;
      final entryId = journalAudio.meta.id;

      final realtimeTranscript = result.transcript.trim();
      // Save only meaningful realtime text. Empty/whitespace results leave
      // automatic transcription enabled for the retained audio entry.
      if (realtimeTranscript.isNotEmpty) {
        await _saveRealtimeTranscript(
          journalAudio: journalAudio,
          transcript: realtimeTranscript,
          providerName: providerName ?? 'Mistral',
          modelId: modelName ?? 'voxtral-mini',
          detectedLanguage: result.detectedLanguage,
        );
      }

      // Trigger automatic prompts, but skip batch transcription
      if (linkedTaskId != null) {
        unawaited(
          _triggerAutomaticPrompts(
            entryId,
            linkedTaskId: linkedTaskId,
            realtimeTranscriptProvided: realtimeTranscript.isNotEmpty,
          ),
        );
      }

      _realtimeModelName = null;
      _realtimeProviderName = null;
      _realtimeCapture = null;
      state = state.copyWith(
        lastSaveOutcome: AudioRecorderSaveOutcome.saved,
      );

      _loggingService.log(
        LogDomain.speech,
        'Realtime recording stopped: '
        'transcriptLen=${result.transcript.length}, '
        'audioFile=${result.audioFilePath}, '
        'usedFallback=${result.usedTranscriptFallback}',
        subDomain: 'stopRealtime',
      );

      return entryId;
    } catch (exception, stackTrace) {
      final hasRecoverableAudio = (_realtimeCapture?.acceptedPcmBytes ?? 0) > 0;
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'stopRealtime',
      );
      _vuMeter.reset();
      await _cleanupRealtime();
      _realtimeCapture = null;
      ref.invalidate(realtimeTranscriptionServiceProvider);
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
        isRealtimeMode: false,
        partialTranscript: null,
        lastSaveOutcome: hasRecoverableAudio
            ? AudioRecorderSaveOutcome.savedPendingRecovery
            : AudioRecorderSaveOutcome.noAudio,
      );
    } finally {
      _terminalActionInProgress = false;
    }
    return null;
  }

  /// Cancels the realtime recording session without saving.
  Future<void> cancelRealtime() async {
    if (_terminalActionInProgress) return;
    _terminalActionInProgress = true;
    _realtimeEpoch += 1;
    try {
      final capture = _realtimeCapture;
      await _cleanupRealtime();

      // Dispose the service to tear down WebSocket and subscriptions,
      // then invalidate the provider so the next recordRealtime() gets
      // a fresh instance.
      await capture?.discard();
      _realtimeCapture = null;
      ref.invalidate(realtimeTranscriptionServiceProvider);

      _vuMeter.reset();
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
        vu: -20,
        isRealtimeMode: false,
        partialTranscript: null,
      );

      _loggingService.log(
        LogDomain.speech,
        'Realtime recording cancelled',
        subDomain: 'cancelRealtime',
      );
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'cancelRealtime',
      );
    } finally {
      _terminalActionInProgress = false;
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
    // Look up parent link so the parent task (if any) is notified.
    // This ensures agents subscribed to the task ID wake when ASR
    // adds or updates the transcript on a child audio entry.
    String? parentId;
    try {
      final db = getIt<JournalDb>();
      final links = await db.linksForEntryIds({journalAudio.meta.id});
      if (links.isNotEmpty) {
        parentId = links.first.fromId;
      }
    } catch (_) {
      // Non-fatal: notification will still include the audio entry's own ID.
    }

    await persistenceLogic.updateDbEntity(updated, linkedId: parentId);
  }

  /// Cleans up realtime recording resources.
  Future<void> _cleanupRealtime() async {
    try {
      await _realtimeAmplitudeSub?.cancel();
    } catch (_) {}
    _realtimeAmplitudeSub = null;
    try {
      final capture = _realtimeCapture;
      if (capture != null) {
        await _activeRealtimeService?.stopAndRetainForRecovery(
          capture: capture,
          stopRecorder: () async {
            await _realtimeRecorder?.stop();
          },
        );
      }
    } catch (_) {}
    try {
      await _realtimeRecorder?.dispose();
    } catch (_) {}
    _realtimeRecorder = null;
    _activeRealtimeService = null;
    _realtimeStartTime = null;
    _realtimeModelName = null;
    _realtimeProviderName = null;
  }

  bool _isCurrentRealtimeEpoch(int epoch) =>
      !_disposed && ref.mounted && epoch == _realtimeEpoch;

  /// Pauses any currently playing audio. Shared between `record` and
  /// [recordRealtime].
  ///
  /// Skips reading the provider if it hasn't been initialized yet — reading it
  /// would eagerly construct a media_kit `Player` (and its native mpv core
  /// thread) just to observe that nothing is playing. That makes every
  /// subsequent hot restart crash on macOS, since mpv's core thread outlives
  /// the Dart isolate teardown.
  Future<void> _pauseAudioPlayer() async {
    if (!ref.exists(audioPlayerControllerProvider)) {
      return;
    }
    try {
      final playerState = ref.read(audioPlayerControllerProvider);
      if (playerState.status == AudioPlayerStatus.playing) {
        await ref.read(audioPlayerControllerProvider.notifier).pause();
      }
    } catch (e) {
      _loggingService.log(
        LogDomain.speech,
        'Audio player not available, continuing without audio pause: $e',
        subDomain: 'pauseAudioPlayer',
      );
    }
  }

  /// Triggers automatic prompts based on category settings and user preferences
  Future<void> _triggerAutomaticPrompts(
    String entryId, {
    String? linkedTaskId,
    bool realtimeTranscriptProvided = false,
  }) async {
    final trigger = ref.read(automaticPromptTriggerProvider);
    await trigger.triggerAutomaticPrompts(
      entryId,
      state,
      linkedTaskId: linkedTaskId,
      realtimeTranscriptProvided: realtimeTranscriptProvided,
    );
  }
}

/// Factory for creating [rec.AudioRecorder] instances for realtime recording.
/// Override in tests to inject a mock recorder.
final Provider<rec.AudioRecorder Function()> realtimeRecorderFactoryProvider =
    Provider<rec.AudioRecorder Function()>((ref) => rec.AudioRecorder.new);
