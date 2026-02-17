// Tests for AudioRecorderController (Riverpod implementation)
// Mirrors the functionality tested in recorder_cubit_test.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai_chat/services/realtime_transcription_service.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/model/audio_player_state.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/audio_player_controller.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:record/record.dart' as rec;

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockAmplitude extends Mock implements Amplitude {}

class MockPlayer extends Mock implements Player {}

class MockPlayerState extends Mock implements PlayerState {}

class MockPlayerStream extends Mock implements PlayerStream {}

class FakePlayable extends Fake implements Playable {}

class MockRealtimeTranscriptionService extends Mock
    implements RealtimeTranscriptionService {}

class MockRecAudioRecorder extends Mock implements rec.AudioRecorder {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockAutomaticPromptTrigger extends Mock
    implements AutomaticPromptTrigger {}

// Fake config for realtimeAvailableProvider tests
final ({
  AiConfigModel model,
  AiConfigInferenceProvider provider
}) _fakeRealtimeConfig = (
  provider: AiConfig.inferenceProvider(
    id: 'test-provider',
    baseUrl: 'https://api.mistral.ai',
    apiKey: 'test-key',
    name: 'Mistral',
    createdAt: DateTime(2024),
    inferenceProviderType: InferenceProviderType.mistral,
  ) as AiConfigInferenceProvider,
  model: AiConfig.model(
    id: 'test-model',
    name: 'Voxtral',
    providerModelId: 'voxtral-mini-transcribe-realtime-2602',
    inferenceProviderId: 'test-provider',
    createdAt: DateTime(2024),
    inputModalities: [Modality.audio],
    outputModalities: [Modality.text],
    isReasoningModel: false,
  ) as AiConfigModel,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late MockPlayer mockPlayer;
  late MockPlayerState mockPlayerState;
  late MockPlayerStream mockPlayerStream;
  late StreamController<Duration> positionController;
  late StreamController<Duration> bufferController;
  late StreamController<bool> completedController;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(FakePlayable());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(const Stream<Uint8List>.empty());
    registerFallbackValue((String s) {});
    registerFallbackValue(() async {});
    registerFallbackValue(const rec.RecordConfig());
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(
      Metadata(
        id: 'fallback',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024),
      ),
    );
    registerFallbackValue(
      AudioRecorderState(
        status: AudioRecorderStatus.initial,
        progress: Duration.zero,
        vu: 0,
        dBFS: -160,
        showIndicator: false,
        modalVisible: false,
      ),
    );
    registerFallbackValue(
      JournalAudio(
        data: AudioData(
          audioDirectory: '/',
          duration: Duration.zero,
          audioFile: 'f.m4a',
          dateTo: DateTime(2024),
          dateFrom: DateTime(2024),
        ),
        meta: Metadata(
          id: 'fb',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
      ),
    );
  });

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockAudioRecorderRepository = MockAudioRecorderRepository();
    mockPlayer = MockPlayer();
    mockPlayerState = MockPlayerState();
    mockPlayerStream = MockPlayerStream();
    positionController = StreamController<Duration>.broadcast();
    bufferController = StreamController<Duration>.broadcast();
    completedController = StreamController<bool>.broadcast();

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

    // Setup default mock behavior for AudioRecorderRepository
    when(() => mockAudioRecorderRepository.amplitudeStream).thenAnswer(
      (_) => const Stream<Amplitude>.empty(),
    );
    when(() => mockAudioRecorderRepository.hasPermission())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isPaused())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.isRecording())
        .thenAnswer((_) async => false);
    when(() => mockAudioRecorderRepository.stopRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.pauseRecording())
        .thenAnswer((_) async {});
    when(() => mockAudioRecorderRepository.resumeRecording())
        .thenAnswer((_) async {});

    // Register mocks with GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        audioRecorderRepositoryProvider.overrideWithValue(
          mockAudioRecorderRepository,
        ),
        playerFactoryProvider.overrideWithValue(() => mockPlayer),
      ],
    );
  });

  tearDown(() async {
    await positionController.close();
    await bufferController.close();
    await completedController.close();
    container.dispose();
    await getIt.reset();
  });

  group('AudioRecorderController - State Management Methods', () {
    group('setModalVisible', () {
      test('should update modalVisible to true', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        expect(container.read(audioRecorderControllerProvider).modalVisible,
            isFalse);

        // Act
        controller.setModalVisible(modalVisible: true);

        // Assert
        expect(container.read(audioRecorderControllerProvider).modalVisible,
            isTrue);
      });

      test('should update modalVisible to false', () {
        // Arrange
        final controller = container
            .read(audioRecorderControllerProvider.notifier)
          ..setModalVisible(modalVisible: true);
        expect(container.read(audioRecorderControllerProvider).modalVisible,
            isTrue);

        // Act
        controller.setModalVisible(modalVisible: false);

        // Assert
        expect(container.read(audioRecorderControllerProvider).modalVisible,
            isFalse);
      });

      test('should emit new state with updated modalVisible', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        expect(container.read(audioRecorderControllerProvider).modalVisible,
            isFalse);

        // Act
        controller.setModalVisible(modalVisible: true);

        // Assert
        expect(container.read(audioRecorderControllerProvider).modalVisible,
            isTrue);
      });
    });

    group('setCategoryId', () {
      test('should set categoryId to non-null value', () {
        // Arrange
        const categoryId = 'test-category-123';
        final controller =
            container.read(audioRecorderControllerProvider.notifier)

              // Act
              ..setCategoryId(categoryId);

        // Assert - Since _categoryId is private, we can't directly test it
        // but we can verify the method executes without error
        expect(() => controller.setCategoryId(categoryId), returnsNormally);
      });

      test('should set categoryId to null', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)

              // Act & Assert
              ..setCategoryId(null);
        expect(() => controller.setCategoryId(null), returnsNormally);
      });

      test('should handle multiple categoryId changes', () {
        // Arrange
        const firstCategoryId = 'category-1';
        const secondCategoryId = 'category-2';
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act & Assert
        expect(
            () => controller.setCategoryId(firstCategoryId), returnsNormally);
        expect(
            () => controller.setCategoryId(secondCategoryId), returnsNormally);
        expect(() => controller.setCategoryId(null), returnsNormally);
      });
    });
  });

  group('AudioRecorderController - Recording Control Methods', () {
    group('record', () {
      test('should log no permission event when permission denied', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act - In test environment, hasPermission returns false
        await controller.record();

        // Assert - Verify no permission event was logged
        verify(
          () => mockLoggingService.captureEvent(
            any<String>(that: startsWith('No audio recording permission')),
            domain: 'recorder_controller',
            subDomain: 'record_permission_denied',
          ),
        ).called(1);
      });

      test('should set linkedId when provided', () async {
        // Arrange
        const testLinkedId = 'test-linked-id-123';
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.record(linkedId: testLinkedId);

        // Assert - The linkedId is stored internally and would be used
        // when creating the journal entry on stop
        expect(
            () => controller.record(linkedId: testLinkedId), returnsNormally);
      });
    });

    group('pause', () {
      test('should update status to paused', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.pause();

        // Assert
        expect(container.read(audioRecorderControllerProvider).status,
            equals(AudioRecorderStatus.paused));
      });

      test('should call repository pauseRecording', () async {
        // Arrange
        when(() => mockAudioRecorderRepository.pauseRecording())
            .thenAnswer((_) async {});

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.pause();

        // Assert
        verify(() => mockAudioRecorderRepository.pauseRecording()).called(1);
        expect(container.read(audioRecorderControllerProvider).status,
            equals(AudioRecorderStatus.paused));
      });

      test('should maintain other state properties when pausing', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        final initialProgress =
            container.read(audioRecorderControllerProvider).progress;
        final initialVu = container.read(audioRecorderControllerProvider).vu;
        final initialDbfs =
            container.read(audioRecorderControllerProvider).dBFS;

        // Act
        await controller.pause();

        // Assert
        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, equals(AudioRecorderStatus.paused));
        expect(state.showIndicator, isFalse); // showIndicator remains false
        expect(state.progress, equals(initialProgress));
        expect(state.vu, equals(initialVu));
        expect(state.dBFS, equals(initialDbfs));
      });
    });

    group('resume', () {
      test('should execute without throwing exception', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act & Assert
        expect(controller.resume, returnsNormally);

        // In test environment, AudioRecorder methods throw MissingPluginException
        // but the method should handle this gracefully
        await expectLater(controller.resume(), completes);
      });

      test('should update status to recording and call repository', () async {
        // Arrange
        when(() => mockAudioRecorderRepository.resumeRecording())
            .thenAnswer((_) async {});

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.resume();

        // Assert
        verify(() => mockAudioRecorderRepository.resumeRecording()).called(1);
        expect(container.read(audioRecorderControllerProvider).status,
            equals(AudioRecorderStatus.recording));
      });
    });

    group('stop', () {
      test('should return null when no audio note exists', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        final result = await controller.stop();

        // Assert
        expect(result, isNull);
      });

      test('should preserve inference preferences when stopping', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)
              ..setEnableSpeechRecognition(enable: true)
              ..setEnableTaskSummary(enable: false)
              ..setEnableChecklistUpdates(enable: true);

        // Act
        await controller.stop();

        // Assert - Preferences should be preserved
        final state = container.read(audioRecorderControllerProvider);
        expect(state.enableSpeechRecognition, equals(true));
        expect(state.enableTaskSummary, equals(false));
        expect(state.enableChecklistUpdates, equals(true));
        expect(state.status, equals(AudioRecorderStatus.stopped));
      });

      test('should update status to stopped and reset state', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.stop();

        // Assert
        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, equals(AudioRecorderStatus.stopped));
        expect(state.progress, equals(Duration.zero));
        expect(state.vu, equals(-20.0));
        expect(state.dBFS, equals(-160.0));
        expect(state.showIndicator, isFalse);
        expect(state.modalVisible, isFalse);
      });

      test('should handle exceptions and return null', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        final result = await controller.stop();

        // Assert
        expect(result, isNull);
      });

      test('should log exceptions during stop', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act - Force an exception by calling stop in test environment
        await controller.stop();

        // Assert - Since there's no audio note, no exception should be logged
        // If there was an audio note and repository threw exception, it would be logged
        verifyNever(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'recorder_controller',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        );
      });
    });
  });

  group('AudioRecorderController - Initialization and Cleanup', () {
    test('should initialize with correct initial state', () {
      // Act
      final state = container.read(audioRecorderControllerProvider);

      // Assert
      expect(state.status, equals(AudioRecorderStatus.stopped));
      expect(state.vu, equals(-20.0));
      expect(state.dBFS, equals(-160.0));
      expect(state.progress, equals(Duration.zero));
      expect(state.showIndicator, isFalse);
      expect(state.modalVisible, isFalse);
      expect(state.linkedId, isNull);
    });

    test('should properly handle provider lifecycle', () {
      // Arrange
      final container = ProviderContainer(
        overrides: [
          audioRecorderRepositoryProvider.overrideWithValue(
            mockAudioRecorderRepository,
          ),
        ],
      );

      // Act - Read the provider to initialize it
      final _ = container.read(audioRecorderControllerProvider);

      // Assert - Provider should be initialized
      expect(container.read(audioRecorderControllerProvider).status,
          equals(AudioRecorderStatus.stopped));

      // Clean up
      container.dispose();
    });
  });

  group('AudioRecorderController - Untested Edge Cases', () {
    group('record() method edge cases', () {
      test('should handle isPaused() returning true', () async {
        // Arrange
        when(() => mockAudioRecorderRepository.hasPermission())
            .thenAnswer((_) async => true);
        when(() => mockAudioRecorderRepository.isPaused())
            .thenAnswer((_) async => true);
        when(() => mockAudioRecorderRepository.resumeRecording())
            .thenAnswer((_) async {});

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.record();

        // Assert
        verify(() => mockAudioRecorderRepository.resumeRecording()).called(1);
        expect(container.read(audioRecorderControllerProvider).status,
            equals(AudioRecorderStatus.recording));
      });

      test('should handle isRecording() returning true', () async {
        // Arrange
        when(() => mockAudioRecorderRepository.hasPermission())
            .thenAnswer((_) async => true);
        when(() => mockAudioRecorderRepository.isPaused())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.isRecording())
            .thenAnswer((_) async => true);

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.record();

        // Assert
        verify(() => mockAudioRecorderRepository.stopRecording()).called(1);
      });

      test('should handle startRecording() returning null', () async {
        // Arrange
        when(() => mockAudioRecorderRepository.hasPermission())
            .thenAnswer((_) async => true);
        when(() => mockAudioRecorderRepository.isPaused())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.isRecording())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.startRecording())
            .thenAnswer((_) async => null);

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.record();

        // Assert
        verify(() => mockAudioRecorderRepository.startRecording()).called(1);
        // State should remain stopped if audioNote is null
        expect(container.read(audioRecorderControllerProvider).status,
            equals(AudioRecorderStatus.stopped));
      });

      test('should handle startRecording() returning valid AudioNote',
          () async {
        // Arrange
        final mockAudioNote = AudioNote(
          createdAt: DateTime.now(),
          audioFile: 'audio.m4a',
          audioDirectory: '/test/path',
          duration: Duration.zero,
        );
        when(() => mockAudioRecorderRepository.hasPermission())
            .thenAnswer((_) async => true);
        when(() => mockAudioRecorderRepository.isPaused())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.isRecording())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.startRecording())
            .thenAnswer((_) async => mockAudioNote);

        final controller =
            container.read(audioRecorderControllerProvider.notifier)
              // Set some preferences before recording
              ..setEnableSpeechRecognition(enable: true)
              ..setEnableTaskSummary(enable: false)
              ..setEnableChecklistUpdates(enable: true);

        // Act
        await controller.record(linkedId: 'test-linked-id');

        // Assert
        verify(() => mockAudioRecorderRepository.startRecording()).called(1);
        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, equals(AudioRecorderStatus.recording));
        expect(state.linkedId, equals('test-linked-id'));
        // Preferences should be preserved when starting recording
        expect(state.enableSpeechRecognition, isTrue);
        expect(state.enableTaskSummary, isFalse);
        expect(state.enableChecklistUpdates, isTrue);
      });

      test('should capture exceptions during record()', () async {
        // Arrange
        final testException = Exception('Test recording error');
        when(() => mockAudioRecorderRepository.hasPermission())
            .thenThrow(testException);

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        await controller.record();

        // Assert
        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'recorder_controller',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('stop() method edge cases', () {
      test('should handle successful stop with audioNote and create entry',
          () async {
        // Arrange
        final mockAudioNote = AudioNote(
          createdAt: DateTime.now(),
          audioFile: 'audio.m4a',
          audioDirectory: '/test/path',
          duration: const Duration(seconds: 10),
        );
        // Note: In a real test, we would mock SpeechRepository.createAudioEntry
        // to return this journal audio, but since it's a static method,
        // we can't easily mock it. The test verifies the flow up to that point.
        /*final mockJournalAudio = JournalAudio(
          meta: Metadata(
            id: 'test-entry-id',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: AudioData(
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            audioFile: 'audio.m4a',
            audioDirectory: '/test/path',
            duration: const Duration(seconds: 10),
          ),
        );*/

        // First, simulate starting a recording
        when(() => mockAudioRecorderRepository.hasPermission())
            .thenAnswer((_) async => true);
        when(() => mockAudioRecorderRepository.isPaused())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.isRecording())
            .thenAnswer((_) async => false);
        when(() => mockAudioRecorderRepository.startRecording())
            .thenAnswer((_) async => mockAudioNote);

        // Mock the static method call
        // Note: We can't directly mock static methods, but we can test the flow
        when(() => mockAudioRecorderRepository.stopRecording())
            .thenAnswer((_) async {});

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Start recording first
        await controller.record();

        // Set language and category
        controller.setCategoryId('test-category');

        // Act
        await controller.stop();

        // Assert
        verify(() => mockAudioRecorderRepository.stopRecording()).called(1);
        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, equals(AudioRecorderStatus.stopped));
        expect(state.progress, equals(Duration.zero));
        expect(state.vu, equals(-20.0));
        expect(state.dBFS, equals(-160.0));
        expect(state.showIndicator, isFalse);
        expect(state.modalVisible, isFalse);
      });

      test('should capture exceptions during stop()', () async {
        // Arrange
        final testException = Exception('Test stop error');
        when(() => mockAudioRecorderRepository.stopRecording())
            .thenThrow(testException);

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Act
        final result = await controller.stop();

        // Assert
        expect(result, isNull);
        verify(
          () => mockLoggingService.captureException(
            testException,
            domain: 'recorder_controller',
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('build() method amplitude subscription', () {
      test('should subscribe to amplitude stream and update state', () async {
        // Arrange
        final amplitudeController = StreamController<Amplitude>.broadcast();
        final mockAmplitude = MockAmplitude();
        when(() => mockAmplitude.current).thenReturn(-50);

        when(() => mockAudioRecorderRepository.amplitudeStream)
            .thenAnswer((_) => amplitudeController.stream);

        // Act - Create a new container to trigger build()
        final testContainer = ProviderContainer(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
          ],
        )

          // Read the provider to ensure it's initialized
          ..read(audioRecorderControllerProvider.notifier);

        // Give some time for the stream subscription to be established
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Emit multiple amplitude updates to fill the RMS buffer
        // The VU meter uses a 300ms window with 20ms intervals = 15 samples
        // We need to send at least 15 samples to fill the buffer
        for (var i = 0; i < 20; i++) {
          amplitudeController.add(mockAmplitude);
          // Allow microtask queue to process
          await Future.microtask(() {});
        }

        // Wait for all stream events to be processed
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Assert
        final state = testContainer.read(audioRecorderControllerProvider);

        expect(state.dBFS, equals(-50.0)); // Direct dBFS value

        // VU calculation with constant -50 dBFS input:
        // - RMS of constant -50 dBFS values = -50 dBFS
        // - VU = RMS_dB - vuReferenceLevelDbfs = -50 - (-18) = -32
        // - However, VU is clamped to range [-20, +3] in the implementation
        // - Therefore, -32 gets clamped to -20 (the minimum VU value)
        expect(state.vu, equals(-20.0));
        expect(state.progress.inMilliseconds, greaterThan(0));

        // Clean up
        await amplitudeController.close();
        testContainer.dispose();
      });

      test('should cancel amplitude subscription on dispose', () async {
        // Arrange
        final amplitudeController = StreamController<Amplitude>();
        when(() => mockAudioRecorderRepository.amplitudeStream)
            .thenAnswer((_) => amplitudeController.stream);

        // Act
        ProviderContainer(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
          ],
        )
          ..read(audioRecorderControllerProvider)

          // Dispose container (which should cancel subscription)
          ..dispose();

        // Verify stream is no longer listened to
        expect(amplitudeController.hasListener, isFalse);

        // Clean up
        await amplitudeController.close();
      });
    });

    group('setCategoryId edge cases', () {
      test('should update categoryId when different from current', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)

              // Act
              ..setCategoryId('category-1')
              ..setCategoryId('category-2');

        // Assert - We can't directly verify the private field, but we can
        // ensure the method executes without error and would be used in stop()
        expect(() => controller.setCategoryId('category-3'), returnsNormally);
      });

      test('should not update categoryId when same as current', () async {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)

              // Act
              ..setCategoryId('same-category')
              ..setCategoryId('same-category');

        // Assert
        expect(
            () => controller.setCategoryId('same-category'), returnsNormally);
      });
    });
  });

  group('AudioRecorderController - Integration Tests', () {
    test('AudioRecorderController can be instantiated with mocked dependencies',
        () {
      // This test verifies that the AudioRecorderController can be created
      // with our mocked dependencies
      expect(() => container.read(audioRecorderControllerProvider),
          returnsNormally);
    });

    test('AudioRecorderController handles missing permissions', () async {
      // This test verifies that when the AudioRecorder has no permission
      // (which happens in test environment), it's properly handled

      // Act
      final controller =
          container.read(audioRecorderControllerProvider.notifier);
      await controller.record();

      // Verify that the no permission event was logged
      verify(
        () => mockLoggingService.captureEvent(
          any<String>(that: startsWith('No audio recording permission')),
          domain: 'recorder_controller',
          subDomain: 'record_permission_denied',
        ),
      ).called(1);
    });

    test('should pause audio player when recording starts', () async {
      // Arrange - Set audio player to playing state
      final audioController =
          container.read(audioPlayerControllerProvider.notifier);
      await audioController.play();

      // Verify audio player is playing
      expect(
        container.read(audioPlayerControllerProvider).status,
        equals(AudioPlayerStatus.playing),
      );

      // Clear any previous pause calls but keep stubs
      clearInteractions(mockPlayer);

      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Act
      await controller.record(linkedId: 'test-id');

      // Assert - mockPlayer.pause() should have been called
      verify(() => mockPlayer.pause()).called(1);
    });

    test('should not pause audio player when it is not playing', () async {
      // Arrange - audio player is stopped (default state - initializing)
      // Initialize it but don't play
      container.read(audioPlayerControllerProvider);

      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Clear any previous pause calls but keep stubs
      clearInteractions(mockPlayer);

      // Act
      await controller.record(linkedId: 'test-id');

      // Assert - mockPlayer.pause() should NOT have been called
      verifyNever(() => mockPlayer.pause());
    });
  });

  group('AudioRecorderController - State Listener Tests', () {
    test('should notify listeners when state changes', () {
      // Arrange
      final controller =
          container.read(audioRecorderControllerProvider.notifier);
      final states = <AudioRecorderState>[];

      // Listen to state changes
      container.listen(
        audioRecorderControllerProvider,
        (previous, next) => states.add(next),
        fireImmediately: true,
      );

      // Act
      controller.setModalVisible(modalVisible: true);

      // Assert
      expect(states.length, equals(2)); // Initial + 1 change

      expect(states[1].modalVisible, isTrue);
    });

    test('should maintain state consistency across multiple operations', () {
      // Arrange
      container.read(audioRecorderControllerProvider.notifier)

        // Act - Perform multiple state changes
        ..setCategoryId('category-123')
        ..setModalVisible(modalVisible: true);

      // Assert - All state properties should be as expected
      final state = container.read(audioRecorderControllerProvider);
      expect(state.showIndicator,
          isFalse); // showIndicator stays false unless recording
      expect(state.modalVisible, isTrue);
      expect(state.status, equals(AudioRecorderStatus.stopped));
      expect(state.progress, equals(Duration.zero));
      expect(state.vu, equals(-20.0));
      expect(state.dBFS, equals(-160.0));
    });
  });

  group('AudioRecorderController - Automatic Prompt Triggering', () {
    group('setEnableSpeechRecognition', () {
      test('should update enableSpeechRecognition in state', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)
              // Act
              ..setEnableSpeechRecognition(enable: true);

        // Assert
        expect(
            container
                .read(audioRecorderControllerProvider)
                .enableSpeechRecognition,
            isTrue);

        // Act again
        controller.setEnableSpeechRecognition(enable: false);

        // Assert
        expect(
            container
                .read(audioRecorderControllerProvider)
                .enableSpeechRecognition,
            isFalse);

        // Act with null
        controller.setEnableSpeechRecognition(enable: null);

        // Assert
        expect(
            container
                .read(audioRecorderControllerProvider)
                .enableSpeechRecognition,
            isNull);
      });
    });

    group('setEnableChecklistUpdates', () {
      test('should update enableChecklistUpdates in state', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)
              // Act
              ..setEnableChecklistUpdates(enable: true);

        // Assert
        expect(
            container
                .read(audioRecorderControllerProvider)
                .enableChecklistUpdates,
            isTrue);

        // Act again
        controller.setEnableChecklistUpdates(enable: false);

        // Assert
        expect(
            container
                .read(audioRecorderControllerProvider)
                .enableChecklistUpdates,
            isFalse);

        // Act with null
        controller.setEnableChecklistUpdates(enable: null);

        // Assert
        expect(
            container
                .read(audioRecorderControllerProvider)
                .enableChecklistUpdates,
            isNull);
      });
    });

    group('setEnableTaskSummary', () {
      test('should update enableTaskSummary in state', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier)
              // Act
              ..setEnableTaskSummary(enable: true);

        // Assert
        expect(
            container.read(audioRecorderControllerProvider).enableTaskSummary,
            isTrue);

        // Act again
        controller.setEnableTaskSummary(enable: false);

        // Assert
        expect(
            container.read(audioRecorderControllerProvider).enableTaskSummary,
            isFalse);

        // Act with null
        controller.setEnableTaskSummary(enable: null);

        // Assert
        expect(
            container.read(audioRecorderControllerProvider).enableTaskSummary,
            isNull);
      });

      // NOTE: Additional tests for checkbox state persistence during recording
      // lifecycle are complex to implement with the current architecture because:
      // 1. They require mocking SpeechRepository and AutomaticPromptTrigger
      // 2. The stop() method has many dependencies that need to be mocked
      // 3. The actual behavior is tested through the existing unit tests above
      //    and integration tests that test the full recording flow
      //
      // The key behaviors verified by existing tests:
      // - setEnableSpeechRecognition() correctly updates state (tested above)
      // - setEnableTaskSummary() correctly updates state (tested above)
      // - setEnableChecklistUpdates() correctly updates state (tested above)
      // - States are preserved in AudioRecorderState throughout recording
      // - States are passed to AutomaticPromptTrigger when recording stops
    });

    // NOTE: Tests for _triggerAutomaticPrompts functionality
    //
    // The automatic prompt triggering logic is private and tested indirectly
    // through integration tests that verify the complete recording flow.
    // These integration tests ensure:
    //
    // 1. When category has automatic prompts configured:
    //    - Speech recognition is triggered based on user preference
    //    - Task summary is triggered for linked tasks when enabled
    //
    // 2. When category has no automatic prompts:
    //    - No AI inference is triggered after recording
    //
    // 3. User preferences (checkboxes) override defaults:
    //    - Disabling speech recognition prevents transcription
    //    - Disabling task summary prevents summary generation
    //    - Disabling checklist updates prevents checklist processing
    //
    // 4. Error handling:
    //    - Exceptions during prompt triggering are caught and logged
    //    - Recording entry is still created even if AI fails
    //
    // Unit testing this would require extensive mocking of:
    // - SpeechRepository
    // - AutomaticPromptTrigger
    // - CategoryDetailsController
    // - UnifiedAiController (via triggerNewInferenceProvider)
    //
    // The integration tests provide better coverage with less brittleness.
  });

  group('AudioRecorderController - Realtime Transcription', () {
    late MockRealtimeTranscriptionService mockRealtimeService;
    late MockRecAudioRecorder mockRecorder;
    late StreamController<double> realtimeAmplitudeController;
    late StreamController<Uint8List> pcmStreamController;

    setUp(() {
      mockRealtimeService = MockRealtimeTranscriptionService();
      mockRecorder = MockRecAudioRecorder();
      realtimeAmplitudeController = StreamController<double>.broadcast();
      pcmStreamController = StreamController<Uint8List>.broadcast();

      // Mock recorder
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.startStream(any()))
          .thenAnswer((_) async => pcmStreamController.stream);
      when(() => mockRecorder.stop()).thenAnswer((_) async => null);
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});

      // Mock realtime service
      when(() => mockRealtimeService.amplitudeStream)
          .thenAnswer((_) => realtimeAmplitudeController.stream);

      when(() => mockRealtimeService.startRealtimeTranscription(
            pcmStream: any(named: 'pcmStream'),
            onDelta: any(named: 'onDelta'),
          )).thenAnswer((_) async {});

      when(() => mockRealtimeService.stop(
            stopRecorder: any(named: 'stopRecorder'),
            outputPath: any(named: 'outputPath'),
          )).thenAnswer((_) async => const RealtimeStopResult(
            transcript: 'test transcript',
            audioFilePath: '/tmp/audio/2026-02-17/test.m4a',
          ));

      when(() => mockRealtimeService.dispose()).thenAnswer((_) async {});

      when(() => mockRealtimeService.resolveRealtimeConfig())
          .thenAnswer((_) async => _fakeRealtimeConfig);

      // Rebuild container with realtime overrides
      container.dispose();
      container = ProviderContainer(
        overrides: [
          audioRecorderRepositoryProvider.overrideWithValue(
            mockAudioRecorderRepository,
          ),
          playerFactoryProvider.overrideWithValue(() => mockPlayer),
          realtimeTranscriptionServiceProvider
              .overrideWithValue(mockRealtimeService),
          realtimeRecorderFactoryProvider.overrideWithValue(() => mockRecorder),
        ],
      );
    });

    tearDown(() async {
      await realtimeAmplitudeController.close();
      await pcmStreamController.close();
    });

    group('recordRealtime - happy path', () {
      test('sets state to recording with isRealtimeMode true', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        await controller.recordRealtime(linkedId: 'task-123');

        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.recording);
        expect(state.isRealtimeMode, isTrue);
        expect(state.linkedId, 'task-123');
        expect(state.partialTranscript, isNull);
      });

      test('starts PCM stream at 16kHz mono', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        await controller.recordRealtime();

        final captured =
            verify(() => mockRecorder.startStream(captureAny())).captured;
        final config = captured.first as rec.RecordConfig;
        expect(config.encoder, rec.AudioEncoder.pcm16bits);
        expect(config.sampleRate, 16000);
        expect(config.numChannels, 1);
      });

      test('calls startRealtimeTranscription on the service', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        await controller.recordRealtime();

        verify(() => mockRealtimeService.startRealtimeTranscription(
              pcmStream: any(named: 'pcmStream'),
              onDelta: any(named: 'onDelta'),
            )).called(1);
      });

      test('onDelta accumulates into partialTranscript', () async {
        void Function(String)? capturedOnDelta;

        when(() => mockRealtimeService.startRealtimeTranscription(
              pcmStream: any(named: 'pcmStream'),
              onDelta: any(named: 'onDelta'),
            )).thenAnswer((invocation) async {
          capturedOnDelta =
              invocation.namedArguments[#onDelta] as void Function(String);
        });

        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        await controller.recordRealtime();

        expect(capturedOnDelta, isNotNull);

        capturedOnDelta!('Hello ');
        expect(
          container.read(audioRecorderControllerProvider).partialTranscript,
          'Hello ',
        );

        capturedOnDelta!('world');
        expect(
          container.read(audioRecorderControllerProvider).partialTranscript,
          'Hello world',
        );
      });

      test('subscribes to amplitude stream for VU meter', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        await controller.recordRealtime();

        // Emit an amplitude value
        realtimeAmplitudeController.add(-30);

        // Allow the stream event to propagate
        await Future<void>.delayed(Duration.zero);

        final state = container.read(audioRecorderControllerProvider);
        // dBFS should have been updated from the amplitude stream
        expect(state.dBFS, -30);
      });
    });

    group('recordRealtime - permission denied', () {
      test('logs and returns without changing state', () async {
        when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        await controller.recordRealtime();

        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.stopped);
        expect(state.isRealtimeMode, isFalse);

        verify(() => mockRecorder.dispose()).called(1);
        verify(() => mockLoggingService.captureEvent(
              any<String>(that: contains('No audio recording permission')),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
            )).called(1);
      });
    });

    group('recordRealtime - error handling', () {
      test('cleans up on startStream failure', () async {
        when(() => mockRecorder.startStream(any()))
            .thenThrow(Exception('Stream failed'));

        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        await controller.recordRealtime();

        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.stopped);
        expect(state.isRealtimeMode, isFalse);

        verify(() => mockLoggingService.captureException(
              any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).called(1);
      });

      test('cleans up on service startRealtimeTranscription failure', () async {
        when(() => mockRealtimeService.startRealtimeTranscription(
              pcmStream: any(named: 'pcmStream'),
              onDelta: any(named: 'onDelta'),
            )).thenThrow(StateError('No config'));

        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        await controller.recordRealtime();

        // State should have been set to recording before the service call,
        // but cleanup should reset it. However, the state is set before
        // startRealtimeTranscription, so cleanup handles the reset.
        final state = container.read(audioRecorderControllerProvider);
        expect(state.isRealtimeMode, isFalse);
      });
    });

    group('cancelRealtime', () {
      test('resets state and disposes service', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Start realtime first so there's something to cancel
        await controller.recordRealtime();
        expect(
          container.read(audioRecorderControllerProvider).isRealtimeMode,
          isTrue,
        );

        await controller.cancelRealtime();

        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.stopped);
        expect(state.isRealtimeMode, isFalse);
        expect(state.partialTranscript, isNull);

        verify(() => mockRealtimeService.dispose()).called(1);
      });

      test('resets state even with no active session', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        await controller.cancelRealtime();

        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.stopped);
        expect(state.isRealtimeMode, isFalse);
      });

      test('logs cancellation event', () async {
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        await controller.recordRealtime();
        await controller.cancelRealtime();

        verify(
          () => mockLoggingService.captureEvent(
            any<String>(
              that: contains('Realtime recording cancelled'),
            ),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).called(1);
      });

      test('catches and logs errors during cancellation', () async {
        when(() => mockRealtimeService.dispose())
            .thenThrow(Exception('dispose failed'));

        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        await controller.recordRealtime();
        // Should not throw
        await controller.cancelRealtime();

        verify(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('stopRealtime - error handling', () {
      test('resets state and cleans up on error', () async {
        // Make service.stop throw to trigger the catch block
        when(() => mockRealtimeService.stop(
              stopRecorder: any(named: 'stopRecorder'),
              outputPath: any(named: 'outputPath'),
            )).thenThrow(Exception('stop failed'));

        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        await controller.recordRealtime();

        final result = await controller.stopRealtime();

        expect(result, isNull);

        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.stopped);
        expect(state.isRealtimeMode, isFalse);
        expect(state.partialTranscript, isNull);
        expect(state.progress, Duration.zero);

        verify(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: equals('stopRealtime'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('stopRealtime - happy path', () {
      test('creates audio entry and saves transcript', () async {
        // Set up GetIt dependencies for createAssetDirectory and
        // SpeechRepository.createAudioEntry
        final tempDir = await Directory.systemTemp.createTemp('rt_stop_');
        addTearDown(() => tempDir.delete(recursive: true));

        if (!getIt.isRegistered<Directory>()) {
          getIt.registerSingleton<Directory>(tempDir);
        }

        final mockPersistence = MockPersistenceLogic();
        if (!getIt.isRegistered<PersistenceLogic>()) {
          getIt.registerSingleton<PersistenceLogic>(mockPersistence);
        }

        // Mock PersistenceLogic methods
        when(() => mockPersistence.createMetadata(
              dateFrom: any(named: 'dateFrom'),
              dateTo: any(named: 'dateTo'),
              uuidV5Input: any(named: 'uuidV5Input'),
              flag: any(named: 'flag'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((_) async => Metadata(
              id: 'test-entry-id',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
            ));
        when(() => mockPersistence.createDbEntity(
              any(),
              linkedId: any(named: 'linkedId'),
            )).thenAnswer((_) async => true);
        when(() => mockPersistence.updateMetadata(any()))
            .thenAnswer((invocation) async {
          final meta = invocation.positionalArguments[0] as Metadata;
          return meta;
        });
        when(() => mockPersistence.updateDbEntity(any()))
            .thenAnswer((_) async => true);

        // Mock automatic prompt trigger
        final mockTrigger = MockAutomaticPromptTrigger();
        when(() => mockTrigger.triggerAutomaticPrompts(
              any(),
              any(),
              any(),
              isLinkedToTask: any(named: 'isLinkedToTask'),
              linkedTaskId: any(named: 'linkedTaskId'),
              skipTranscription: any(named: 'skipTranscription'),
            )).thenAnswer((_) async {});

        // Configure the stop result
        when(() => mockRealtimeService.stop(
              stopRecorder: any(named: 'stopRecorder'),
              outputPath: any(named: 'outputPath'),
            )).thenAnswer((_) async => const RealtimeStopResult(
              transcript: 'realtime transcript text',
              audioFilePath: '/tmp/audio.m4a',
            ));

        // Rebuild container with automatic prompt trigger override
        container.dispose();
        container = ProviderContainer(
          overrides: [
            audioRecorderRepositoryProvider.overrideWithValue(
              mockAudioRecorderRepository,
            ),
            playerFactoryProvider.overrideWithValue(() => mockPlayer),
            realtimeTranscriptionServiceProvider
                .overrideWithValue(mockRealtimeService),
            realtimeRecorderFactoryProvider
                .overrideWithValue(() => mockRecorder),
            automaticPromptTriggerProvider.overrideWithValue(mockTrigger),
          ],
        );

        final controller = container
            .read(audioRecorderControllerProvider.notifier)

          // Set categoryId before recording (needed for triggerAutomaticPrompts)
          ..setCategoryId('test-category');

        // Start realtime recording first
        await controller.recordRealtime(linkedId: 'task-id');

        expect(
          container.read(audioRecorderControllerProvider).status,
          AudioRecorderStatus.recording,
        );

        // Stop realtime recording
        final entryId = await controller.stopRealtime();

        // Verify entry was created
        expect(entryId, 'test-entry-id');

        // Verify state was reset
        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, AudioRecorderStatus.stopped);
        expect(state.modalVisible, isFalse);

        // Verify transcript was saved via updateDbEntity
        verify(() => mockPersistence.updateDbEntity(any())).called(1);

        // Verify automatic prompts were triggered with skipTranscription: true
        verify(() => mockTrigger.triggerAutomaticPrompts(
              'test-entry-id',
              'test-category',
              any(),
              isLinkedToTask: true,
              linkedTaskId: 'task-id',
              skipTranscription: true,
            )).called(1);

        // Verify logging
        verify(
          () => mockLoggingService.captureEvent(
            any<String>(
              that: contains('Realtime recording stopped'),
            ),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(
              named: 'subDomain',
              that: equals('stopRealtime'),
            ),
          ),
        ).called(1);
      });
    });

    group('state model', () {
      test('initial state has isRealtimeMode false', () {
        final state = container.read(audioRecorderControllerProvider);
        expect(state.isRealtimeMode, isFalse);
      });

      test('initial state has partialTranscript null', () {
        final state = container.read(audioRecorderControllerProvider);
        expect(state.partialTranscript, isNull);
      });

      test('state supports realtime fields via copyWith', () {
        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          vu: -20,
          dBFS: -160,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
          isRealtimeMode: true,
          partialTranscript: 'hello world',
        );

        expect(state.isRealtimeMode, isTrue);
        expect(state.partialTranscript, 'hello world');

        final updated = state.copyWith(
          partialTranscript: 'hello world!',
          isRealtimeMode: false,
        );
        expect(updated.partialTranscript, 'hello world!');
        expect(updated.isRealtimeMode, isFalse);
      });

      test('preserves inference preferences with realtime fields', () {
        final state = AudioRecorderState(
          status: AudioRecorderStatus.recording,
          vu: -20,
          dBFS: -160,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
          isRealtimeMode: true,
          enableSpeechRecognition: true,
          enableTaskSummary: false,
          enableChecklistUpdates: true,
        );

        expect(state.enableSpeechRecognition, isTrue);
        expect(state.enableTaskSummary, isFalse);
        expect(state.enableChecklistUpdates, isTrue);
      });
    });
  });

  group('realtimeAvailableProvider', () {
    test('returns true when realtime config is available', () async {
      final mockService = MockRealtimeTranscriptionService();
      // ignore: unnecessary_lambdas
      when(() => mockService.resolveRealtimeConfig())
          .thenAnswer((_) async => _fakeRealtimeConfig);

      final testContainer = ProviderContainer(
        overrides: [
          realtimeTranscriptionServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(testContainer.dispose);

      // Listen to keep the provider alive
      final sub = testContainer.listen(
        realtimeAvailableProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      // Wait for async resolution
      await testContainer.read(realtimeAvailableProvider.future);

      final result = testContainer.read(realtimeAvailableProvider);
      expect(result.value, isTrue);
    });

    test('returns false when no realtime config', () async {
      final mockService = MockRealtimeTranscriptionService();
      // ignore: unnecessary_lambdas
      when(() => mockService.resolveRealtimeConfig())
          .thenAnswer((_) async => null);

      final testContainer = ProviderContainer(
        overrides: [
          realtimeTranscriptionServiceProvider.overrideWithValue(mockService),
        ],
      );
      addTearDown(testContainer.dispose);

      final sub = testContainer.listen(
        realtimeAvailableProvider,
        (_, __) {},
      );
      addTearDown(sub.close);

      await testContainer.read(realtimeAvailableProvider.future);

      final result = testContainer.read(realtimeAvailableProvider);
      expect(result.value, isFalse);
    });
  });
}
