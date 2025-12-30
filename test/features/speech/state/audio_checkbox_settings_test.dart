import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPlayer extends Mock implements Player {}

class MockPlayerState extends Mock implements PlayerState {}

class MockPlayerStream extends Mock implements PlayerStream {}

class FakePlayable extends Fake implements Playable {}

void main() {
  late ProviderContainer container;
  late MockAudioRecorderRepository mockRecorderRepo;
  late MockLoggingService mockLoggingService;
  late MockPlayer mockPlayer;
  late MockPlayerState mockPlayerState;
  late MockPlayerStream mockPlayerStream;
  late StreamController<Duration> positionController;
  late StreamController<Duration> bufferController;
  late StreamController<bool> completedController;

  setUpAll(() {
    registerFallbackValue(FakePlayable());
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockRecorderRepo = MockAudioRecorderRepository();
    mockLoggingService = MockLoggingService();
    mockPlayer = MockPlayer();
    mockPlayerState = MockPlayerState();
    mockPlayerStream = MockPlayerStream();
    positionController = StreamController<Duration>.broadcast();
    bufferController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Setup mock player
    when(() => mockPlayer.state).thenReturn(mockPlayerState);
    when(() => mockPlayerState.duration).thenReturn(const Duration(minutes: 5));
    when(() => mockPlayer.stream).thenReturn(mockPlayerStream);
    when(() => mockPlayerStream.position)
        .thenAnswer((_) => positionController.stream);
    when(() => mockPlayerStream.buffer)
        .thenAnswer((_) => bufferController.stream);
    when(() => mockPlayerStream.completed)
        .thenAnswer((_) => completedController.stream);
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    when(() => mockPlayer.open(any(), play: any(named: 'play')))
        .thenAnswer((_) async {});
    when(() => mockPlayer.play()).thenAnswer((_) async {});
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

    // Set up default mock behavior
    when(() => mockRecorderRepo.amplitudeStream)
        .thenAnswer((_) => const Stream.empty());

    container = ProviderContainer(
      overrides: [
        audioRecorderRepositoryProvider.overrideWithValue(mockRecorderRepo),
        playerFactoryProvider.overrideWithValue(() => mockPlayer),
      ],
    );
  });

  tearDown(() async {
    await positionController.close();
    await bufferController.close();
    await completedController.close();
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

    test('checkbox states persist when starting new recording', () async {
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

      // Start new recording (checkbox states should remain as set)
      await controller.record();

      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);
    });

    test('state preserves other fields when updating checkboxes', () {
      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Set language

      var state = container.read(audioRecorderControllerProvider);

      // Update checkbox - language should remain
      controller.setEnableSpeechRecognition(enable: true);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);

      // Update another checkbox - both language and first checkbox should remain
      controller.setEnableTaskSummary(enable: false);
      state = container.read(audioRecorderControllerProvider);
      expect(state.enableSpeechRecognition, true);
      expect(state.enableTaskSummary, false);
    });
  });
}
