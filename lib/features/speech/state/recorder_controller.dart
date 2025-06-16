import 'dart:async';

import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recorder_controller.g.dart';

/// Interval in milliseconds for amplitude updates from the recorder.
const intervalMs = 100;

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
  late final AudioPlayerCubit _audioPlayerCubit;
  String? _linkedId;
  String? _categoryId;
  String? _language;
  AudioNote? _audioNote;

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
    _audioPlayerCubit = getIt<AudioPlayerCubit>();

    _amplitudeSub = _recorderRepository.amplitudeStream.listen((Amplitude amp) {
      state = state.copyWith(
        progress: Duration(
          milliseconds: state.progress.inMilliseconds + intervalMs,
        ),
        // The offset of 160 converts the amplitude to a positive decibel value
        // suitable for VU meter display (typical range: 0-200 dB)
        decibels: amp.current + 160,
      );
    });

    ref.onDispose(() async {
      await _amplitudeSub?.cancel();
    });

    return AudioRecorderState(
      status: AudioRecorderStatus.initializing,
      decibels: 0,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
      language: '',
    );
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
      // Pause any playing audio first
      if (_audioPlayerCubit.state.status == AudioPlayerStatus.playing) {
        await _audioPlayerCubit.pause();
      }

      if (await _recorderRepository.hasPermission()) {
        if (await _recorderRepository.isPaused()) {
          await resume();
        } else if (await _recorderRepository.isRecording()) {
          await stop();
        } else {
          _audioNote = await _recorderRepository.startRecording();
          if (_audioNote != null) {
            state = state.copyWith(
              status: AudioRecorderStatus.recording,
              linkedId: linkedId,
            );
          }
        }
      } else {
        _loggingService.captureEvent(
          'no audio recording permission',
          domain: 'recorder_controller',
        );
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
      state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        decibels: 0,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: '',
      );
      if (_audioNote != null) {
        final journalAudio = await SpeechRepository.createAudioEntry(
          _audioNote!,
          language: _language,
          linkedId: _linkedId,
          categoryId: _categoryId,
        );
        _linkedId = null;
        final entryId = journalAudio?.meta.id;
        _audioNote = null; // Reset audio note after processing
        return entryId;
      }
    } catch (exception, stackTrace) {
      _loggingService.captureException(
        exception,
        domain: 'recorder_controller',
        stackTrace: stackTrace,
      );
      // Ensure state is updated even if an error occurs during stop/save
      state = state.copyWith(
          status: AudioRecorderStatus.stopped,
          progress: Duration.zero,
          decibels: 0);
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

  /// Controls visibility of the floating recording indicator.
  /// [showIndicator] Whether to show the indicator when recording and modal is closed.
  void setIndicatorVisible({required bool showIndicator}) {
    state = state.copyWith(showIndicator: showIndicator);
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
}
