import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/audio_player_state.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/logic/repositories/speech_repository.dart';
import 'package:lotti/providers/audio_player_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:record/record.dart' show Amplitude;

/// Interval in milliseconds for amplitude updates from the recorder.
const intervalMs = 20;

/// A failed start is returned to the recording surface for localized feedback.
enum AudioRecordingFailure { permissionDenied, startFailed, busy }

/// Main controller for audio recording functionality.
///
/// This Riverpod controller manages the complete recording lifecycle including:
/// - Recording state (start, stop, pause, resume)
/// - Real-time audio level monitoring for the level line
/// - Integration with audio player to pause playback during recording
/// - Stopping the read-aloud voice, so the microphone never records it
/// - UI state management (modal visibility, indicator visibility)
///
/// The controller is kept alive to maintain recording state across navigation.
final audioRecorderControllerProvider =
    NotifierProvider<AudioRecorderController, AudioRecorderState>(
      AudioRecorderController.new,
      name: 'audioRecorderControllerProvider',
    );

/// Whether a take linked to the subject with this id is recording or
/// paused.
///
/// For a page that shows it — a goal's or a person's *Speak* pill turning to
/// the recording red — without standing the recorder up just to ask: a
/// recorder nobody has built is not recording. On a phone those pages slide
/// the navigation bar and its recording indicator away, so the pill is the
/// only sign on the screen that a take is still running.
final ProviderFamily<bool, String> subjectTakeLiveProvider = Provider
    .autoDispose
    .family<bool, String>(
      (ref, subjectId) =>
          ref.watch(audioRecorderControllerProvider.exists) &&
          ref.watch(
            audioRecorderControllerProvider.select(
              (state) => state.isActiveSessionFor(subjectId),
            ),
          ),
      name: 'subjectTakeLiveProvider',
    );

class AudioRecorderController extends Notifier<AudioRecorderState> {
  late final AudioRecorderRepository _recorderRepository;
  StreamSubscription<Amplitude>? _amplitudeSub;
  late final DomainLogger _loggingService;
  String? _linkedId;
  String? _categoryId;
  AudioNote? _audioNote;
  bool _transcriptionHandledByCaller = false;
  bool _terminalActionInProgress = false;
  bool _startInProgress = false;

  /// Whether a stop or cancel is in flight. Once either has claimed the
  /// take, the other returns at once without doing anything — so a host
  /// that would offer *Discard* while a stop is still saving must not: its
  /// `cancel` would be a no-op and the take would land anyway.
  bool get isFinishing => _terminalActionInProgress;

  /// Initializes the controller with dependencies and sets up amplitude monitoring.
  ///
  /// This method:
  /// - Injects required dependencies (repository, services)
  /// - Sets up amplitude stream subscription for level updates
  /// - Configures cleanup on disposal
  /// - Returns initial recording state
  ///
  /// It must not touch the microphone in any way — see the note in the body.
  @override
  AudioRecorderState build() {
    _recorderRepository = ref.watch(audioRecorderRepositoryProvider);
    _loggingService = ref.watch(domainLoggerProvider);

    // Don't initialize AudioPlayerCubit here - it depends on MediaKit which might fail
    // We'll get it lazily when needed

    _amplitudeSub = _recorderRepository.amplitudeStream.listen((Amplitude amp) {
      // While paused the recorder keeps polling amplitude, but the elapsed
      // timer and level meter must freeze so the displayed duration matches the
      // audio actually captured. Dropping these samples holds progress/dBFS
      // at their pre-pause values until the recording resumes.
      if (state.status == AudioRecorderStatus.paused) return;

      final dBFS = amp.current;

      state = state.copyWith(
        progress: Duration(
          milliseconds: state.progress.inMilliseconds + intervalMs,
        ),
        dBFS: dBFS,
      );
    });

    ref.onDispose(() async {
      await _amplitudeSub?.cancel();
    });

    // Deliberately no permission probe here. `hasPermission()` *requests* the
    // microphone permission on Android/iOS, and this controller is built by the
    // app shell (the recording-indicator strip) on startup — probing here would
    // pop the OS mic dialog before the user has asked to record anything.
    // Permission is requested lazily, in `record()`.
    return AudioRecorderState(
      status: AudioRecorderStatus.stopped,
      dBFS: -160,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
    );
  }

  /// Starts a new recording or toggles the current recording state.
  ///
  /// This method handles:
  /// - Pausing any currently playing audio
  /// - Stopping the read-aloud voice (summaries, answers, the companion)
  /// - Checking recording permissions
  /// - Resume if paused, stop if recording, or start new recording
  /// - Setting the linked entry ID for the recording
  ///
  /// Returns null after a successful action, or a typed failure the caller
  /// can display. Overlapping starts are refused before changing the subject.
  /// [transcriptionHandledByCaller] suppresses automation for this recording,
  /// including when it is stopped after its original sheet is dismissed.
  /// [shouldCancel] lets a dismissed caller abort pending startup; any file
  /// returned by a late platform start is stopped and discarded.
  /// [linkedId] Optional ID to link this recording to an existing journal entry.
  Future<AudioRecordingFailure?> record({
    String? linkedId,
    bool transcriptionHandledByCaller = false,
    bool Function()? shouldCancel,
  }) async {
    if (_startInProgress || _terminalActionInProgress) {
      return AudioRecordingFailure.busy;
    }
    _startInProgress = true;
    _linkedId = linkedId;

    try {
      await _pauseAudioPlayer();
      await stopReadAloudForRecording(ref);
      if (shouldCancel?.call() ?? false) return null;

      if (await _recorderRepository.hasPermission()) {
        final isPaused = await _recorderRepository.isPaused();
        final isRecording =
            !isPaused && await _recorderRepository.isRecording();
        if (shouldCancel?.call() ?? false) return null;
        if (isPaused) {
          await resume();
        } else if (isRecording) {
          await stop();
        } else {
          _audioNote = await _recorderRepository.startRecording();
          if (_audioNote == null) return AudioRecordingFailure.startFailed;
          if (shouldCancel?.call() ?? false) {
            await cancel();
            return null;
          }
          _transcriptionHandledByCaller = transcriptionHandledByCaller;
          if (ref.mounted) {
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
        return AudioRecordingFailure.permissionDenied;
      }
    } catch (exception, stackTrace) {
      _loggingService.error(
        LogDomain.speech,
        exception,
        stackTrace: stackTrace,
        subDomain: 'recorder_controller',
      );
      return AudioRecordingFailure.startFailed;
    } finally {
      _startInProgress = false;
    }
    return null;
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
    final linkedSubjectId = _linkedId;
    final transcriptionHandledByCaller = _transcriptionHandledByCaller;
    final categoryId = _categoryId;
    final duration = state.progress;
    _audioNote = null;
    _linkedId = null;
    _transcriptionHandledByCaller = false;

    try {
      await _recorderRepository.stopRecording();

      // Preserve the inference preferences before resetting state
      final enableSpeechRecognition = state.enableSpeechRecognition;

      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        dBFS: -160,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        // Preserve the inference preferences
        enableSpeechRecognition: enableSpeechRecognition,
      );

      if (note != null) {
        final journalAudio = await ref
            .read(speechRepositoryProvider)
            .createAudioEntry(
              note.copyWith(duration: duration),
              linkedId: linkedSubjectId,
              categoryId: categoryId,
            );
        final entryId = journalAudio?.meta.id;

        // Trigger automatic prompts in the background via profile-driven automation
        if (entryId != null &&
            linkedSubjectId != null &&
            !transcriptionHandledByCaller) {
          // Don't await - let it run in the background so the modal can close immediately
          unawaited(
            _triggerAutomaticPrompts(
              entryId,
              linkedSubjectId: linkedSubjectId,
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
      state = state.copyWith(
        status: AudioRecorderStatus.stopped,
        progress: Duration.zero,
        dBFS: -160,
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
    _transcriptionHandledByCaller = false;

    // Preserve the inference preferences before resetting state.
    final enableSpeechRecognition = state.enableSpeechRecognition;
    state = AudioRecorderState(
      status: AudioRecorderStatus.stopped,
      dBFS: -160,
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
  /// (silent) values so the level line reads as quiet rather
  /// than frozen mid-level — a frozen loud needle would look like the app
  /// hung. The elapsed [AudioRecorderState.progress] is intentionally left
  /// untouched so the timer holds; the amplitude listener in [build] then drops
  /// incoming samples until [resume] restarts metering.
  Future<void> pause() async {
    await _recorderRepository.pauseRecording();
    state = state.copyWith(
      status: AudioRecorderStatus.paused,
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
    if (!ref.read(audioPlayerControllerProvider.exists)) {
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
    String? linkedSubjectId,
  }) async {
    final trigger = ref.read(automaticPromptTriggerProvider);
    await trigger.triggerAutomaticPrompts(
      entryId,
      state,
      linkedSubjectId: linkedSubjectId,
    );
  }
}
