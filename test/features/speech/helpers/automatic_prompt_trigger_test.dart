import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
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

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockPromptCapabilityFilter extends Mock
    implements PromptCapabilityFilter {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockCategoryRepository mockCategoryRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockPromptCapabilityFilter mockPromptCapabilityFilter;
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
    mockAiConfigRepository = MockAiConfigRepository();
    mockPromptCapabilityFilter = MockPromptCapabilityFilter();

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

    // Setup default mock behavior for prompt capability filter
    // By default, return the first prompt from any list (simulating all prompts are available)
    when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()))
        .thenAnswer((invocation) async {
      final promptIds = invocation.positionalArguments[0] as List<String>;
      if (promptIds.isEmpty) return null;
      final firstPromptId = promptIds.first;

      // Return a mock AiConfigPrompt for the first prompt
      return AiConfigPrompt(
        id: firstPromptId,
        name: 'Test Prompt',
        defaultModelId: 'test-model',
        modelIds: [],
        systemMessage: 'Test system message',
        userMessage: 'Test user message',
        requiredInputData: [],
        useReasoning: false,
        createdAt: DateTime.now(),
        aiResponseType: AiResponseType.audioTranscription,
      );
    });

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        promptCapabilityFilterProvider
            .overrideWithValue(mockPromptCapabilityFilter),
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

    group('User preference overrides', () {
      test(
          'should trigger transcription when user preference is true even without category config',
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

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: promptId,
              linkedEntityId: null,
            )).overrideWith((ref) async {
              inferenceTriggered = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true, // User explicitly wants transcription
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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

        verify(() => mockLoggingService.captureEvent(
              'Triggering audio transcription (user preference: true)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        testContainer.dispose();
      });

      test('should trigger checklist updates when user preference overrides',
          () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const checklistPromptId = 'checklist-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.checklistUpdates: [checklistPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var inferenceTriggered = false;

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              inferenceTriggered = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableChecklistUpdates: true, // User wants checklist updates
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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

        verify(() => mockLoggingService.captureEvent(
              any<String>(that: contains('Triggering checklist updates')),
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        testContainer.dispose();
      });
    });

    group('Sequential execution', () {
      test('should wait for transcription before checklist updates', () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const transcriptionPromptId = 'transcription-prompt';
        const checklistPromptId = 'checklist-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [transcriptionPromptId],
            AiResponseType.checklistUpdates: [checklistPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var transcriptionCompleted = false;
        var checklistTriggered = false;
        final transcriptionCompleter = Completer<void>();

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: transcriptionPromptId,
              linkedEntityId: taskId,
            )).overrideWith((ref) async {
              await Future<void>.delayed(Duration.zero);
              transcriptionCompleted = true;
              transcriptionCompleter.complete();
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              // Verify transcription completed before checklist
              expect(transcriptionCompleted, isTrue,
                  reason: 'Checklist updates should wait for transcription');
              checklistTriggered = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          enableChecklistUpdates: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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
        expect(transcriptionCompleted, isTrue);
        expect(checklistTriggered, isTrue);

        verify(() => mockLoggingService.captureEvent(
              'Waiting for transcription to complete before checklist updates',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        verify(() => mockLoggingService.captureEvent(
              'Transcription completed, now triggering checklist updates',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        testContainer.dispose();
      });

      test('should wait for checklist updates before task summary', () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const checklistPromptId = 'checklist-prompt';
        const taskSummaryPromptId = 'task-summary-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.checklistUpdates: [checklistPromptId],
            AiResponseType.taskSummary: [taskSummaryPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var checklistCompleted = false;
        var taskSummaryTriggered = false;
        final checklistCompleter = Completer<void>();

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              await Future<void>(() {});
              checklistCompleted = true;
              checklistCompleter.complete();
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: taskSummaryPromptId,
              linkedEntityId: null,
            )).overrideWith((ref) async {
              // Verify checklist completed before task summary
              expect(checklistCompleted, isTrue,
                  reason: 'Task summary should wait for checklist updates');
              taskSummaryTriggered = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableChecklistUpdates: true,
          enableTaskSummary: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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
        expect(checklistCompleted, isTrue);
        expect(taskSummaryTriggered, isTrue);

        verify(() => mockLoggingService.captureEvent(
              'Waiting for checklist updates to complete before task summary',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        verify(() => mockLoggingService.captureEvent(
              'Checklist updates completed, now triggering task summary',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        testContainer.dispose();
      });

      test('should execute all three prompts in correct sequence', () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const transcriptionPromptId = 'transcription-prompt';
        const checklistPromptId = 'checklist-prompt';
        const taskSummaryPromptId = 'task-summary-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [transcriptionPromptId],
            AiResponseType.checklistUpdates: [checklistPromptId],
            AiResponseType.taskSummary: [taskSummaryPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var transcriptionCompleted = false;
        var checklistCompleted = false;
        var taskSummaryCompleted = false;
        final executionOrder = <String>[];

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: transcriptionPromptId,
              linkedEntityId: taskId,
            )).overrideWith((ref) async {
              executionOrder.add('transcription-start');
              await Future<void>.delayed(Duration.zero);
              transcriptionCompleted = true;
              executionOrder.add('transcription-end');
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              executionOrder.add('checklist-start');
              expect(transcriptionCompleted, isTrue);
              await Future<void>.delayed(Duration.zero);
              checklistCompleted = true;
              executionOrder.add('checklist-end');
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: taskSummaryPromptId,
              linkedEntityId: null,
            )).overrideWith((ref) async {
              executionOrder.add('summary-start');
              expect(checklistCompleted, isTrue);
              await Future<void>.delayed(Duration.zero);
              taskSummaryCompleted = true;
              executionOrder.add('summary-end');
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          enableChecklistUpdates: true,
          enableTaskSummary: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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
        expect(transcriptionCompleted, isTrue);
        expect(checklistCompleted, isTrue);
        expect(taskSummaryCompleted, isTrue);

        // Verify execution order
        expect(executionOrder, [
          'transcription-start',
          'transcription-end',
          'checklist-start',
          'checklist-end',
          'summary-start',
          'summary-end',
        ]);

        testContainer.dispose();
      });
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
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: promptId,
              linkedEntityId: null,
            )).overrideWith((ref) async {
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
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: taskSummaryPromptId,
              linkedEntityId: null,
            )).overrideWith((ref) async {
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
              'Triggering task summary for task $taskId (user preference: null, transcription pending: false, checklist updates pending: false)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        // Clean up
        testContainer.dispose();
      });

      test('should not trigger checklist when user disables it', () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const checklistPromptId = 'checklist-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.checklistUpdates: [checklistPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        final trigger = container.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableChecklistUpdates: false, // User explicitly disabled
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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
        // Should not log checklist triggering
        verifyNever(() => mockLoggingService.captureEvent(
              any<String>(that: contains('Triggering checklist updates')),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
            ));
      });

      test('should properly log checklist updates without task summary',
          () async {
        // Arrange
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const checklistPromptId = 'checklist-prompt';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.checklistUpdates: [checklistPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        var checklistTriggered = false;

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              checklistTriggered = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableChecklistUpdates: true,
          enableTaskSummary: false, // No task summary
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
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
        expect(checklistTriggered, isTrue);

        verify(() => mockLoggingService.captureEvent(
              'Triggering checklist updates for task $taskId (transcription pending: false)',
              domain: 'automatic_prompt_trigger',
              subDomain: 'triggerAutomaticPrompts',
            )).called(1);

        testContainer.dispose();
      });
    });

    // Platform filtering scenarios
    group('Platform filtering fallback scenarios', () {
      test('logs unavailability when prompt filtered', () async {
        const categoryId = 'test-category';
        const entryId = 'test-entry';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: ['transcription-prompt'],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        // Simulate mobile filtering - return null for transcription prompt
        when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()))
            .thenAnswer((_) async => null);

        final trigger = container.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
        );

        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: false,
        );

        // Verify unavailability was logged
        verify(
          () => mockLoggingService.captureEvent(
            'No available audio transcription prompts for current platform',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);
      });

      test('awaits transcription when no subsequent prompts configured',
          () async {
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const transcriptionPromptId = 'transcription-prompt-id';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [transcriptionPromptId],
            // No checklist or task summary configured
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()))
            .thenAnswer((_) async {
          return AiConfigPrompt(
            id: transcriptionPromptId,
            name: 'Transcription',
            defaultModelId: 'test-model',
            modelIds: const [],
            systemMessage: 'Test',
            userMessage: 'Test',
            requiredInputData: const [],
            useReasoning: false,
            createdAt: DateTime.now(),
            aiResponseType: AiResponseType.audioTranscription,
          );
        });

        var transcriptionCompleted = false;
        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: transcriptionPromptId,
              linkedEntityId: taskId,
            )).overrideWith((ref) async {
              await Future<void>(() {});
              transcriptionCompleted = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
        );

        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: true,
          linkedTaskId: taskId,
        );

        // Should have waited for transcription to complete
        expect(transcriptionCompleted, isTrue);

        testContainer.dispose();
      });

      test('awaits checklist when task summary not configured', () async {
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const transcriptionPromptId = 'transcription-prompt-id';
        const checklistPromptId = 'checklist-prompt-id';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [transcriptionPromptId],
            AiResponseType.checklistUpdates: [checklistPromptId],
            // No task summary configured
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()))
            .thenAnswer((invocation) async {
          final promptIds = invocation.positionalArguments[0] as List<String>;
          if (promptIds.contains(transcriptionPromptId)) {
            return AiConfigPrompt(
              id: transcriptionPromptId,
              name: 'Transcription',
              defaultModelId: 'test-model',
              modelIds: const [],
              systemMessage: 'Test',
              userMessage: 'Test',
              requiredInputData: const [],
              useReasoning: false,
              createdAt: DateTime.now(),
              aiResponseType: AiResponseType.audioTranscription,
            );
          }
          if (promptIds.contains(checklistPromptId)) {
            return AiConfigPrompt(
              id: checklistPromptId,
              name: 'Checklist',
              defaultModelId: 'test-model',
              modelIds: const [],
              systemMessage: 'Test',
              userMessage: 'Test',
              requiredInputData: const [],
              useReasoning: false,
              createdAt: DateTime.now(),
              aiResponseType: AiResponseType.checklistUpdates,
            );
          }
          return null;
        });

        var transcriptionCompleted = false;
        var checklistCompleted = false;

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: transcriptionPromptId,
              linkedEntityId: taskId,
            )).overrideWith((ref) async {
              await Future<void>(() {});
              transcriptionCompleted = true;
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              await Future<void>(() {});
              checklistCompleted = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          enableChecklistUpdates: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
        );

        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: true,
          linkedTaskId: taskId,
        );

        // Should have waited for both to complete
        expect(transcriptionCompleted, isTrue);
        expect(checklistCompleted, isTrue);

        // Verify logging
        verify(
          () => mockLoggingService.captureEvent(
            'Waiting for transcription to complete before checklist updates',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);

        testContainer.dispose();
      });

      test('waits for checklist before task summary', () async {
        const categoryId = 'test-category';
        const entryId = 'test-entry';
        const taskId = 'test-task';
        const transcriptionPromptId = 'transcription-prompt-id';
        const checklistPromptId = 'checklist-prompt-id';
        const taskSummaryPromptId = 'task-summary-prompt-id';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            AiResponseType.audioTranscription: [transcriptionPromptId],
            AiResponseType.checklistUpdates: [checklistPromptId],
            AiResponseType.taskSummary: [taskSummaryPromptId],
          },
        );

        when(() => mockCategoryRepository.getCategoryById(categoryId))
            .thenAnswer((_) async => category);

        when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()))
            .thenAnswer((invocation) async {
          final promptIds = invocation.positionalArguments[0] as List<String>;
          if (promptIds.contains(transcriptionPromptId)) {
            return AiConfigPrompt(
              id: transcriptionPromptId,
              name: 'Transcription',
              defaultModelId: 'test-model',
              modelIds: const [],
              systemMessage: 'Test',
              userMessage: 'Test',
              requiredInputData: const [],
              useReasoning: false,
              createdAt: DateTime.now(),
              aiResponseType: AiResponseType.audioTranscription,
            );
          }
          if (promptIds.contains(checklistPromptId)) {
            return AiConfigPrompt(
              id: checklistPromptId,
              name: 'Checklist',
              defaultModelId: 'test-model',
              modelIds: const [],
              systemMessage: 'Test',
              userMessage: 'Test',
              requiredInputData: const [],
              useReasoning: false,
              createdAt: DateTime.now(),
              aiResponseType: AiResponseType.checklistUpdates,
            );
          }
          if (promptIds.contains(taskSummaryPromptId)) {
            return AiConfigPrompt(
              id: taskSummaryPromptId,
              name: 'Task Summary',
              defaultModelId: 'test-model',
              modelIds: const [],
              systemMessage: 'Test',
              userMessage: 'Test',
              requiredInputData: const [],
              useReasoning: false,
              createdAt: DateTime.now(),
              aiResponseType: AiResponseType.taskSummary,
            );
          }
          return null;
        });

        var checklistCompleted = false;
        var taskSummaryStarted = false;

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider
                .overrideWithValue(mockCategoryRepository),
            promptCapabilityFilterProvider
                .overrideWithValue(mockPromptCapabilityFilter),
            triggerNewInferenceProvider((
              entityId: entryId,
              promptId: transcriptionPromptId,
              linkedEntityId: taskId,
            )).overrideWith((ref) async {
              await Future<void>(() {});
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: checklistPromptId,
              linkedEntityId: entryId,
            )).overrideWith((ref) async {
              await Future<void>(() {});
              checklistCompleted = true;
            }),
            triggerNewInferenceProvider((
              entityId: taskId,
              promptId: taskSummaryPromptId,
              linkedEntityId: null,
            )).overrideWith((ref) async {
              // Task summary should only start after checklist completes
              expect(checklistCompleted, isTrue);
              taskSummaryStarted = true;
            }),
          ],
        );

        final trigger = testContainer.read(automaticPromptTriggerProvider);

        final state = AudioRecorderState(
          status: AudioRecorderStatus.stopped,
          enableSpeechRecognition: true,
          enableChecklistUpdates: true,
          enableTaskSummary: true,
          vu: 0,
          dBFS: -60,
          progress: Duration.zero,
          showIndicator: false,
          modalVisible: false,
        );

        await trigger.triggerAutomaticPrompts(
          entryId,
          categoryId,
          state,
          isLinkedToTask: true,
          linkedTaskId: taskId,
        );

        expect(taskSummaryStarted, isTrue);

        // Verify logging
        verify(
          () => mockLoggingService.captureEvent(
            'Waiting for checklist updates to complete before task summary',
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);

        testContainer.dispose();
      });
    });
  });
}
