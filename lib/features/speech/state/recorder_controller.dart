import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/portals/portal_service.dart';
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
/// - Language selection for transcription
///
/// The controller is kept alive to maintain recording state across navigation.
@Riverpod(keepAlive: true)
class AudioRecorderController extends _$AudioRecorderController {
  late final AudioRecorderRepository _recorderRepository;
  StreamSubscription<Amplitude>? _amplitudeSub;
  late final LoggingService _loggingService;
  AudioPlayerCubit? _audioPlayerCubit;
  String? _linkedId;
  String? _categoryId;
  String? _language;
  AudioNote? _audioNote;

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
      await _amplitudeSub?.cancel();
    });

    // Initialize asynchronously to check permissions and transition to ready state
    _initialize();

    return AudioRecorderState(
      status: AudioRecorderStatus.initializing,
      vu: -20, // Start at -20 VU (quiet)
      dBFS: -160,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
      language: '',
    );
  }

  /// Initialize the recorder and check permissions
  Future<void> _initialize() async {
    try {
      // Check if we have permissions and initialize
      final hasPermissions = await _recorderRepository.hasPermission();

      _loggingService.captureEvent(
        'Audio recorder initialization: hasPermissions=$hasPermissions',
        domain: 'recorder_controller',
        subDomain: 'initialize',
      );
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'recorder_controller',
        subDomain: 'initialize',
        stackTrace: stackTrace,
      );
    } finally {
      // Always transition to stopped (ready) state to show UI
      // Even if permissions are not available, user should see the UI
      // and get feedback when they try to record
      if (state.status == AudioRecorderStatus.initializing) {
        state = state.copyWith(status: AudioRecorderStatus.stopped);
      }
    }
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
      // Pause any playing audio first - but safely handle if MediaKit isn't available
      if (_audioPlayerCubit == null && getIt.isRegistered<AudioPlayerCubit>()) {
        try {
          _audioPlayerCubit = getIt<AudioPlayerCubit>();
        } catch (e) {
          // Audio player not available, continue without it
          _loggingService.captureEvent(
            'Audio player not available, continuing without audio pause: $e',
            domain: 'recorder_controller',
            subDomain: 'record',
          );
        }
      }

      if (_audioPlayerCubit?.state.status == AudioPlayerStatus.playing) {
        try {
          await _audioPlayerCubit!.pause();
        } catch (e) {
          _loggingService.captureEvent(
            'Failed to pause audio player: $e',
            domain: 'recorder_controller',
            subDomain: 'record',
          );
        }
      }

      if (await _recorderRepository.hasPermission()) {
        if (await _recorderRepository.isPaused()) {
          await resume();
        } else if (await _recorderRepository.isRecording()) {
          await stop();
        } else {
          _audioNote = await _recorderRepository.startRecording();
          if (_audioNote != null) {
            // Update state to recording, reset inference preferences for new recording
            state = state.copyWith(
              status: AudioRecorderStatus.recording,
              linkedId: linkedId,
              // Reset inference preferences for new recording (null by default)
              enableSpeechRecognition: null,
              enableTaskSummary: null,
              enableChecklistUpdates: null,
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
        language: '',
        // Preserve the inference preferences
        enableSpeechRecognition: enableSpeechRecognition,
        enableTaskSummary: enableTaskSummary,
        enableChecklistUpdates: enableChecklistUpdates,
      );
      if (_audioNote != null) {
        final journalAudio = await SpeechRepository.createAudioEntry(
          _audioNote!,
          language: _language,
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

  /// Sets the language for transcription.
  /// [language] Language code (e.g., 'en', 'de') or empty string for auto-detect.
  void setLanguage(String language) {
    _language = language;
    state = state.copyWith(language: language);
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

  /// Triggers automatic prompts based on category settings and user preferences
  Future<void> _triggerAutomaticPrompts(
    String entryId,
    String categoryId, {
    required bool isLinkedToTask,
    String? linkedTaskId,
  }) async {
    final trigger = ref.read(automaticPromptTriggerProvider);
    await trigger.triggerAutomaticPrompts(
      entryId,
      categoryId,
      state,
      isLinkedToTask: isLinkedToTask,
      linkedTaskId: linkedTaskId,
    );
  }
}
