import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioPlayerCubit extends Mock implements AudioPlayerCubit {}

void main() {
  late ProviderContainer container;
  late MockAudioRecorderRepository mockRecorderRepo;
  late MockLoggingService mockLoggingService;
  late MockAudioPlayerCubit mockAudioPlayerCubit;

  setUp(() {
    mockRecorderRepo = MockAudioRecorderRepository();
    mockLoggingService = MockLoggingService();
    mockAudioPlayerCubit = MockAudioPlayerCubit();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    if (getIt.isRegistered<AudioPlayerCubit>()) {
      getIt.unregister<AudioPlayerCubit>();
    }
    getIt.registerSingleton<AudioPlayerCubit>(mockAudioPlayerCubit);

    // Set up default mock behavior for AudioPlayerCubit
    when(() => mockAudioPlayerCubit.state).thenReturn(
      AudioPlayerState(
        status: AudioPlayerStatus.stopped,
        totalDuration: Duration.zero,
        progress: Duration.zero,
        pausedAt: Duration.zero,
        speed: 1,
        showTranscriptsList: false,
      ),
    );
    when(() => mockAudioPlayerCubit.pause()).thenAnswer((_) async {});

    // Set up default mock behavior
    when(() => mockRecorderRepo.amplitudeStream)
        .thenAnswer((_) => const Stream.empty());

    container = ProviderContainer(
      overrides: [
        audioRecorderRepositoryProvider.overrideWithValue(mockRecorderRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Audio Recording Checkbox Settings', () {
    test('initial state has null checkbox values', () {
      final state = container.read(audioRecorderControllerProvider);

      expect(state.enableSpeechRecognition, null);
      expect(state.enableTaskSummary, null);
    });

    test('setEnableSpeechRecognition updates state correctly', () {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Enable speech recognition
      // ignore_for_file: cascade_invocations
      controller.setEnableSpeechRecognition(enable: true);
      var state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);

      // Disable speech recognition
      controller.setEnableSpeechRecognition(enable: false);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, false);

      // Set to null (use category default)
      controller.setEnableSpeechRecognition(enable: null);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, null);
    });

    test('setEnableTaskSummary updates state correctly', () {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Enable task summary
      controller.setEnableTaskSummary(enable: true);
      var state = container.read(audioRecorderControllerProvider);
      expect(state.enableTaskSummary, true);

      // Disable task summary
      controller.setEnableTaskSummary(enable: false);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableTaskSummary, false);

      // Set to null (use category default)
      controller.setEnableTaskSummary(enable: null);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableTaskSummary, null);
    });

    test('checkbox states persist across multiple changes', () {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Set both checkboxes
      controller
        ..setEnableSpeechRecognition(enable: true)
        ..setEnableTaskSummary(enable: false);

      var state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);

      // Change only speech recognition
      controller.setEnableSpeechRecognition(enable: false);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, false);
      expect(state.enableTaskSummary, false); // Should remain unchanged

      // Change only task summary
      controller.setEnableTaskSummary(enable: true);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, false); // Should remain unchanged
      expect(state.enableTaskSummary, true);
    });

    test('checkbox states are preserved on stop', () async {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Set checkbox states
      controller
        ..setEnableSpeechRecognition(enable: true)
        ..setEnableTaskSummary(enable: false);

      var state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);

      // Mock stop recording behavior
      when(() => mockRecorderRepo.stopRecording()).thenAnswer((_) async {});

      // Stop recording (checkbox states should be preserved)
      await controller.stop();

      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);
    });

    test('checkbox states reset when starting new recording', () async {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Set checkbox states
      controller
        ..setEnableSpeechRecognition(enable: true)
        ..setEnableTaskSummary(enable: false);

      var state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);

      // Mock start recording behavior
      when(() => mockRecorderRepo.hasPermission())
          .thenAnswer((_) async => true);
      when(() => mockRecorderRepo.isRecording()).thenAnswer((_) async => false);
      when(() => mockRecorderRepo.isPaused()).thenAnswer((_) async => false);
      when(() => mockRecorderRepo.startRecording())
          .thenAnswer((_) async => AudioNote(
                createdAt: DateTime.now(),
                audioFile: 'test.aac',
                audioDirectory: '/test',
                duration: Duration.zero,
              ));

      // Start new recording (checkbox states should reset to null)
      await controller.record();

      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, null);
      expect(state.enableTaskSummary, null);
    });

    test('state preserves other fields when updating checkboxes', () {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Set language
      controller.setLanguage('en');
      var state = container.read(audioRecorderControllerProvider);
      expect(state.language, 'en');

      // Update checkbox - language should remain
      controller.setEnableSpeechRecognition(enable: true);
      state = container.read(audioRecorderControllerProvider);
      expect(state.language, 'en');
      expect(state.enableSpeechRecognition, true);

      // Update another checkbox - both language and first checkbox should remain
      controller.setEnableTaskSummary(enable: false);
      state = container.read(audioRecorderControllerProvider);
      expect(state.language, 'en');
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);
    });
  });
}
