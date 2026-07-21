import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/vu_meter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
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
      await _amplitudeSub?.cancel();
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
  /// turning into a transcript and task summary.
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

  /// Pauses any currently playing audio before a recording starts.
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
  }) async {
    final trigger = ref.read(automaticPromptTriggerProvider);
    await trigger.triggerAutomaticPrompts(
      entryId,
      state,
      linkedTaskId: linkedTaskId,
    );
  }
}
