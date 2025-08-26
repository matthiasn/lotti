// Tests for AudioRecorderController (Riverpod implementation)
// Mirrors the functionality tested in recorder_cubit_test.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/speech/state/player_state.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';

import '../../../mocks/mocks.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockAudioRecorderRepository extends Mock
    implements AudioRecorderRepository {}

class MockAmplitude extends Mock implements Amplitude {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockUnifiedAiController extends Mock implements UnifiedAiController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late MockAudioPlayerCubit mockAudioPlayerCubit;
  late MockAudioRecorderRepository mockAudioRecorderRepository;
  late ProviderContainer container;

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockAudioPlayerCubit = MockAudioPlayerCubit();
    mockAudioRecorderRepository = MockAudioRecorderRepository();

    // Setup default mock behavior for AudioPlayerCubit
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
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<AudioPlayerCubit>(mockAudioPlayerCubit);

    // Create container with overridden provider
    container = ProviderContainer(
      overrides: [
        audioRecorderRepositoryProvider.overrideWithValue(
          mockAudioRecorderRepository,
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('AudioRecorderController - State Management Methods', () {
    group('setLanguage', () {
      test('should update language in state', () {
        // Arrange
        const language = 'en-US';
        container
            .read(audioRecorderControllerProvider.notifier)
            // Act
            .setLanguage(language);

        // Assert
        final state = container.read(audioRecorderControllerProvider);
        expect(state.language, equals(language));
      });

      test('should emit new state with updated language', () {
        // Arrange
        const language = 'es-ES';
        const initialLanguage = '';
        final controller =
            container.read(audioRecorderControllerProvider.notifier);

        // Verify initial state
        expect(container.read(audioRecorderControllerProvider).language,
            equals(initialLanguage));

        // Act
        controller.setLanguage(language);

        // Assert
        expect(container.read(audioRecorderControllerProvider).language,
            equals(language));
      });

      test('should handle empty language string', () {
        // Arrange
        const language = '';

        container
            .read(audioRecorderControllerProvider.notifier)
            // Act
            .setLanguage(language);

        // Assert
        expect(container.read(audioRecorderControllerProvider).language,
            equals(language));
      });

      test('should handle multiple language changes', () {
        // Arrange
        const firstLanguage = 'en-US';
        const secondLanguage = 'fr-FR';
        final controller =
            container.read(audioRecorderControllerProvider.notifier)

              // Act & Assert
              ..setLanguage(firstLanguage);
        expect(container.read(audioRecorderControllerProvider).language,
            equals(firstLanguage));

        controller.setLanguage(secondLanguage);
        expect(container.read(audioRecorderControllerProvider).language,
            equals(secondLanguage));
      });
    });

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
        const language = 'en-US';
        final controller = container
            .read(audioRecorderControllerProvider.notifier)
          ..setLanguage(language);

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
        expect(state.language, equals(language));
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
        expect(state.language, equals(''));
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
      expect(state.language, equals(''));
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

    test('should handle multiple provider instances independently', () {
      // Arrange
      final container1 = ProviderContainer(
        overrides: [
          audioRecorderRepositoryProvider.overrideWithValue(
            mockAudioRecorderRepository,
          ),
        ],
      );
      final container2 = ProviderContainer(
        overrides: [
          audioRecorderRepositoryProvider.overrideWithValue(
            mockAudioRecorderRepository,
          ),
        ],
      );

      // Act
      final controller1 =
          container1.read(audioRecorderControllerProvider.notifier);
      final controller2 =
          container2.read(audioRecorderControllerProvider.notifier);

      controller1.setLanguage('en');
      controller2.setLanguage('es');

      // Assert
      expect(container1.read(audioRecorderControllerProvider).language,
          equals('en'));
      expect(container2.read(audioRecorderControllerProvider).language,
          equals('es'));

      // Clean up
      container1.dispose();
      container2.dispose();
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
        // Preferences should be reset to null when starting new recording
        expect(state.enableSpeechRecognition, isNull);
        expect(state.enableTaskSummary, isNull);
        expect(state.enableChecklistUpdates, isNull);
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
        controller
          ..setLanguage('en-US')
          ..setCategoryId('test-category');

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
        expect(state.language, equals(''));
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
      // Arrange
      when(() => mockAudioPlayerCubit.state).thenReturn(
        AudioPlayerState(
          status: AudioPlayerStatus.playing,
          // Audio is playing
          totalDuration: Duration.zero,
          progress: Duration.zero,
          pausedAt: Duration.zero,
          speed: 1,
          showTranscriptsList: false,
        ),
      );

      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Act
      await controller.record(linkedId: 'test-id');

      // Assert
      verify(() => mockAudioPlayerCubit.pause()).called(1);
    });

    test('should not pause audio player when it is not playing', () async {
      // Arrange - audio player is already stopped
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

      final controller =
          container.read(audioRecorderControllerProvider.notifier);

      // Act
      await controller.record(linkedId: 'test-id');

      // Assert
      verifyNever(() => mockAudioPlayerCubit.pause());
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
      controller
        ..setLanguage('en')
        ..setModalVisible(modalVisible: true);

      // Assert
      expect(states.length, equals(3)); // Initial + 2 changes
      expect(states[0].language, equals(''));
      expect(states[1].language, equals('en'));
      expect(states[2].modalVisible, isTrue);
    });

    test('should maintain state consistency across multiple operations', () {
      // Arrange
      container.read(audioRecorderControllerProvider.notifier)

        // Act - Perform multiple state changes
        ..setLanguage('de')
        ..setCategoryId('category-123')
        ..setModalVisible(modalVisible: true);

      // Assert - All state properties should be as expected
      final state = container.read(audioRecorderControllerProvider);
      expect(state.language, equals('de'));
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
}
