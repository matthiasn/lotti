// Tests for AudioRecorderController (Riverpod implementation)
// Mirrors the functionality tested in recorder_cubit_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLoggingService mockLoggingService;
  late ProviderContainer container;

  setUp(() {
    mockLoggingService = MockLoggingService();

    // Register mocks with GetIt
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    container = ProviderContainer();
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

    group('setIndicatorVisible', () {
      test('should update showIndicator to true', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        expect(container.read(audioRecorderControllerProvider).showIndicator,
            isFalse);

        // Act
        controller.setIndicatorVisible(showIndicator: true);

        // Assert
        expect(container.read(audioRecorderControllerProvider).showIndicator,
            isTrue);
      });

      test('should update showIndicator to false', () {
        // Arrange
        final controller = container
            .read(audioRecorderControllerProvider.notifier)
          ..setIndicatorVisible(showIndicator: true);
        expect(container.read(audioRecorderControllerProvider).showIndicator,
            isTrue);

        // Act
        controller.setIndicatorVisible(showIndicator: false);

        // Assert
        expect(container.read(audioRecorderControllerProvider).showIndicator,
            isFalse);
      });

      test('should emit new state with updated showIndicator', () {
        // Arrange
        final controller =
            container.read(audioRecorderControllerProvider.notifier);
        expect(container.read(audioRecorderControllerProvider).showIndicator,
            isFalse);

        // Act
        controller.setIndicatorVisible(showIndicator: true);

        // Assert
        expect(container.read(audioRecorderControllerProvider).showIndicator,
            isTrue);
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

      test('should maintain other state properties when pausing', () async {
        // Arrange
        const language = 'en-US';
        final controller =
            container.read(audioRecorderControllerProvider.notifier)
              ..setLanguage(language)
              ..setIndicatorVisible(showIndicator: true);

        final initialProgress =
            container.read(audioRecorderControllerProvider).progress;
        final initialDecibels =
            container.read(audioRecorderControllerProvider).decibels;

        // Act
        await controller.pause();

        // Assert
        final state = container.read(audioRecorderControllerProvider);
        expect(state.status, equals(AudioRecorderStatus.paused));
        expect(state.language, equals(language));
        expect(state.showIndicator, isTrue);
        expect(state.progress, equals(initialProgress));
        expect(state.decibels, equals(initialDecibels));
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
        expect(state.decibels, equals(0));
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
    });
  });

  group('AudioRecorderController - Initialization and Cleanup', () {
    test('should initialize with correct initial state', () {
      // Act
      final state = container.read(audioRecorderControllerProvider);

      // Assert
      expect(state.status, equals(AudioRecorderStatus.initializing));
      expect(state.decibels, equals(0));
      expect(state.progress, equals(Duration.zero));
      expect(state.showIndicator, isFalse);
      expect(state.modalVisible, isFalse);
      expect(state.language, equals(''));
      expect(state.linkedId, isNull);
    });

    test('should properly handle provider lifecycle', () {
      // Arrange
      final container = ProviderContainer();

      // Act - Read the provider to initialize it
      final _ = container.read(audioRecorderControllerProvider);

      // Assert - Provider should be initialized
      expect(container.read(audioRecorderControllerProvider).status,
          equals(AudioRecorderStatus.initializing));

      // Clean up
      container.dispose();
    });

    test('should handle multiple provider instances independently', () {
      // Arrange
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();

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

  group('AudioRecorderController - Integration Tests', () {
    test('AudioRecorderController can be instantiated with mocked dependencies',
        () {
      // This test verifies that the AudioRecorderController can be created
      // with our mocked dependencies
      expect(() => container.read(audioRecorderControllerProvider),
          returnsNormally);
    });

    test(
        'AudioRecorderController handles missing permissions',
        () async {
      // This test verifies that when the AudioRecorder has no permission
      // (which happens in test environment), it's properly handled

      // Act
      final controller =
          container.read(audioRecorderControllerProvider.notifier);
      await controller.record();

      // Verify that the no permission event was logged
      verify(
        () => mockLoggingService.captureEvent(
          'no audio recording permission',
          domain: 'recorder_controller',
        ),
      ).called(1);
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
        ..setIndicatorVisible(showIndicator: true)
        ..setModalVisible(modalVisible: true);

      // Assert
      expect(states.length, equals(4)); // Initial + 3 changes
      expect(states[0].language, equals(''));
      expect(states[1].language, equals('en'));
      expect(states[2].showIndicator, isTrue);
      expect(states[3].modalVisible, isTrue);
    });

    test('should maintain state consistency across multiple operations', () {
      // Arrange
      container.read(audioRecorderControllerProvider.notifier)

        // Act - Perform multiple state changes
        ..setLanguage('de')
        ..setIndicatorVisible(showIndicator: true)
        ..setCategoryId('category-123')
        ..setModalVisible(modalVisible: true);

      // Assert - All state properties should be as expected
      final state = container.read(audioRecorderControllerProvider);
      expect(state.language, equals('de'));
      expect(state.showIndicator, isTrue);
      expect(state.modalVisible, isTrue);
      expect(state.status, equals(AudioRecorderStatus.initializing));
      expect(state.progress, equals(Duration.zero));
      expect(state.decibels, equals(0));
    });
  });
}
