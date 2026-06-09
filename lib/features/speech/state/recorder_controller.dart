import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/state/vu_meter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/portals/portal_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:record/record.dart' as rec;
import 'package:record/record.dart' show Amplitude;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recorder_controller.g.dart';
part 'recorder_controller_realtime.dart';

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
@Riverpod(keepAlive: true)
class AudioRecorderController extends _$AudioRecorderController
    with _AudioRecorderRealtime {
  late final AudioRecorderRepository _recorderRepository;
  StreamSubscription<Amplitude>? _amplitudeSub;
  @override
  late final DomainLogger _loggingService;
  @override
  String? _linkedId;
  @override
  String? _categoryId;
  AudioNote? _audioNote;
  @override
  bool _disposed = false;

  // Realtime transcription fields
  @override
  rec.AudioRecorder? _realtimeRecorder;
  @override
  StreamSubscription<double>? _realtimeAmplitudeSub;
  @override
  // ignore: use_late_for_private_fields_and_variables
  DateTime? _realtimeStartTime;
  @override
  // ignore: use_late_for_private_fields_and_variables
  String? _realtimeModelName;
  @override
  // ignore: use_late_for_private_fields_and_variables
  String? _realtimeProviderName;

  /// Sliding-window VU meter driving the live level display.
  @override
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
    try {
      await _recorderRepository.stopRecording();
      _audioNote = _audioNote?.copyWith(duration: state.progress);
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
      if (_audioNote != null) {
        final journalAudio = await SpeechRepository.createAudioEntry(
          _audioNote!,
          linkedId: _linkedId,
          categoryId: _categoryId,
        );
        final linkedTaskId = _linkedId;
        _linkedId = null;
        final entryId = journalAudio?.meta.id;
        _audioNote = null; // Reset audio note after processing

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
}

/// Factory for creating [rec.AudioRecorder] instances for realtime recording.
/// Override in tests to inject a mock recorder.
final Provider<rec.AudioRecorder Function()> realtimeRecorderFactoryProvider =
    Provider<rec.AudioRecorder Function()>((ref) => rec.AudioRecorder.new);
