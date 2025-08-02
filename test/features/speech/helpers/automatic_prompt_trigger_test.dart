import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockCategoryRepository mockCategoryRepository;
  late ProviderContainer container;

  // Helper to create a test category with all required fields
  CategoryDefinition createTestCategory({
    required String id,
    required String name,
    Map<AiResponseType, List<String>>? automaticPrompts,
  }) {
    return CategoryDefinition(
      id: id,
      name: name,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      color: '#FF0000',
      private: false,
      active: true,
      favorite: false,
      automaticPrompts: automaticPrompts,
    );
  }

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockCategoryRepository = MockCategoryRepository();

    // Register mocks with GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Setup default mock behavior for logging
    when(() => mockLoggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);

    when(() => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).thenReturn(null);

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('AutomaticPromptTrigger', () {
    test('should not trigger when category has no automatic prompts', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      // Should not log any triggering events
      verifyNever(() => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ));
    });

    test('should not trigger when category is null', () async {
      // Arrange
      const categoryId = 'non-existent';
      const entryId = 'test-entry';

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => null);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(() => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ));
    });

    test('should handle exceptions gracefully', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenThrow(Exception('Database error'));

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act - should not throw
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });

    test('should not trigger transcription when user explicitly disables it',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';
      const promptId = 'transcription-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.audioTranscription: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        enableSpeechRecognition: false, // User explicitly disabled
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      // Should not log triggering event
      verifyNever(() => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering audio transcription')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ));
    });

    test('should not trigger task summary when not linked to task', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';
      const taskSummaryPromptId = 'task-summary-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.taskSummary: [taskSummaryPromptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: false, // Not linked to task
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      // Should not log task summary triggering
      verifyNever(() => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering task summary')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ));
    });

    test('should not trigger task summary when user explicitly disables it',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';
      const taskId = 'test-task';
      const taskSummaryPromptId = 'task-summary-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.taskSummary: [taskSummaryPromptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        enableTaskSummary: false, // User explicitly disabled
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: true,
        linkedTaskId: taskId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      // Should not log task summary triggering
      verifyNever(() => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering task summary')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ));
    });

    test('should handle empty prompt lists', () async {
      // Arrange
      const categoryId = 'test-category';
      const entryId = 'test-entry';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.audioTranscription: [], // Empty list
          AiResponseType.taskSummary: [], // Empty list
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticPromptTriggerProvider);

      final state = AudioRecorderState(
        status: AudioRecorderStatus.stopped,
        vu: 0,
        dBFS: -60,
        progress: Duration.zero,
        showIndicator: false,
        modalVisible: false,
        language: 'en',
      );

      // Act
      await trigger.triggerAutomaticPrompts(
        entryId,
        categoryId,
        state,
        isLinkedToTask: true,
        linkedTaskId: 'task-id',
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      // Should not trigger anything for empty lists
      verifyNever(() => mockLoggingService.captureEvent(
            any<String>(that: contains('Triggering')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ));
    });

    group('Integration scenarios', () {
      // These tests now properly override the triggerNewInferenceProvider
      // instead of using try-catch blocks, based on Gemini feedback.
      // This provides more robust and deterministic testing by directly
      // verifying that the inference is triggered with the correct parameters.

      test('should trigger transcription when category has it configured',
          () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const promptId = 'transcription-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [promptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var inferenceTriggered = false;
        String? capturedEntityId;
        String? capturedPromptId;

        // Override the triggerNewInferenceProvider for this specific test
        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            triggerNewInferenceProvider(
              entityId: entryId,
              promptId: promptId,
            ).overrideWith((ref) async {
              inferenceTriggered = true;
              capturedEntityId = entryId;
              capturedPromptId = promptId;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
          language: 'en',
        );

        // Act
        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: false,
        );

        // Assert
        expect(inferenceTriggered, isTrue);
        expect(capturedEntityId, equals(entryId));
        expect(capturedPromptId, equals(promptId));

        // Also verify logging
        verify(() => mockLoggingService.captureEvent(
              'Triggering audio transcription (user preference: null)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        // Clean up
        testContainer.dispose();
      });

      test('should trigger task summary for linked tasks', () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const taskSummaryPromptId = 'task-summary-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.taskSummary: [taskSummaryPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var inferenceTriggered = false;
        String? capturedEntityId;
        String? capturedPromptId;

        // Override the triggerNewInferenceProvider for this specific test
        // Note: Task summary is triggered WITHOUT linkedEntityId parameter
        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            triggerNewInferenceProvider(
              entityId: taskId,
              promptId: taskSummaryPromptId,
            ).overrideWith((ref) async {
              inferenceTriggered = true;
              capturedEntityId = taskId;
              capturedPromptId = taskSummaryPromptId;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: false, // No transcription
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
          language: 'en',
        );

        // Act
        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: true,
          linkedTaskId: taskId,
        );

        // Assert
        expect(inferenceTriggered, isTrue);
        expect(capturedEntityId, equals(taskId));
        expect(capturedPromptId, equals(taskSummaryPromptId));

        // Also verify logging
        verify(() => mockLoggingService.captureEvent(
              'Triggering task summary for task $taskId (user preference: null, transcription pending: false)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        // Clean up
        testContainer.dispose();
      });
    });
  });
}
