// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

void main() {
  late PromptBuilderHelper promptBuilder;
  late MockAiInputRepository mockAiInputRepository;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    mockAiInputRepository = MockAiInputRepository();

    promptBuilder = PromptBuilderHelper(
      aiInputRepository: mockAiInputRepository,
      journalRepository: MockJournalRepository(),
      taskSummaryResolver: MockTaskSummaryResolver(),
    );

    // Default stub for task JSON calls
    when(
      () => mockAiInputRepository.buildTaskDetailsJson(
        id: any<String>(named: 'id'),
      ),
    ).thenAnswer((_) async => null);

    // Default stub for linked tasks JSON calls
    when(
      () => mockAiInputRepository.buildLinkedTasksJson(
        any<String>(),
      ),
    ).thenAnswer((_) async => '{"linked_from": [], "linked_to": []}');
  });

  tearDown(() {
    // Reset mocks to clear call history between tests
    reset(mockAiInputRepository);

    // Re-stub after reset
    when(
      () => mockAiInputRepository.buildTaskDetailsJson(
        id: any<String>(named: 'id'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => mockAiInputRepository.buildLinkedTasksJson(
        any<String>(),
      ),
    ).thenAnswer((_) async => '{"linked_from": [], "linked_to": []}');
  });

  group('PromptBuilderHelper', () {
    group('getEffectiveMessage', () {
      test('should return base message when tracking is disabled', () {
        // Arrange
        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
          preconfiguredPromptId: 'image_analysis',
        );

        // Act
        final systemMessage = promptBuilder.getEffectiveMessage(
          promptConfig: promptConfig,
          isSystemMessage: true,
        );
        final userMessage = promptBuilder.getEffectiveMessage(
          promptConfig: promptConfig,
          isSystemMessage: false,
        );

        // Assert
        expect(systemMessage, equals('Custom system message'));
        expect(userMessage, equals('Custom user message'));
      });

      test('should return preconfigured message when tracking is enabled', () {
        // Arrange
        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.imagePromptGeneration,
          trackPreconfigured: true,
          preconfiguredPromptId: 'image_prompt_generation',
        );

        // Act
        final systemMessage = promptBuilder.getEffectiveMessage(
          promptConfig: promptConfig,
          isSystemMessage: true,
        );
        final userMessage = promptBuilder.getEffectiveMessage(
          promptConfig: promptConfig,
          isSystemMessage: false,
        );

        // Assert
        final template = preconfiguredPrompts['image_prompt_generation']!;
        expect(systemMessage, equals(template.systemMessage));
        expect(userMessage, equals(template.userMessage));
      });

      test('should return base message when preconfiguredPromptId is null', () {
        // Arrange
        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
          trackPreconfigured: true,
        );

        // Act
        final systemMessage = promptBuilder.getEffectiveMessage(
          promptConfig: promptConfig,
          isSystemMessage: true,
        );

        // Assert
        expect(systemMessage, equals('Custom system message'));
      });

      test(
        'should return base message when preconfigured prompt not found',
        () {
          // Arrange
          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Test Prompt',
            systemMessage: 'Custom system message',
            userMessage: 'Custom user message',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: [InputDataType.task],
            // ignore: deprecated_member_use_from_same_package
            aiResponseType: AiResponseType.taskSummary,
            trackPreconfigured: true,
            preconfiguredPromptId: 'non_existent_id',
          );

          // Act
          final systemMessage = promptBuilder.getEffectiveMessage(
            promptConfig: promptConfig,
            isSystemMessage: true,
          );

          // Assert
          expect(systemMessage, equals('Custom system message'));
        },
      );
    });

    group('buildPromptWithData', () {
      test(
        'should replace {{task}} placeholder with task JSON for task entity',
        () async {
          // Arrange
          const taskId = 'task-123';
          final task = Task(
            data: TaskData(
              title: 'Test Task',
              status: TaskStatus.open(
                id: 'status_id',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: taskId,
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            entryText: const EntryText(plainText: 'Test task'),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Test Prompt',
            systemMessage: 'System',
            userMessage: 'Process this task: {{task}}',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: [InputDataType.task],
            // ignore: deprecated_member_use_from_same_package
            aiResponseType: AiResponseType.taskSummary,
          );

          const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
          when(
            () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
          ).thenAnswer((_) async => mockTaskJson);

          // Act
          final prompt = await promptBuilder.buildPromptWithData(
            promptConfig: promptConfig,
            entity: task,
          );

          // Assert
          expect(prompt, equals('Process this task: $mockTaskJson'));
          verify(
            () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
          ).called(1);
        },
      );

      test(
        'should handle missing {{task}} placeholder with legacy format',
        () async {
          // Arrange
          const taskId = 'task-123';
          final task = Task(
            data: TaskData(
              title: 'Test Task',
              status: TaskStatus.open(
                id: 'status_id',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: taskId,
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            entryText: const EntryText(plainText: 'Test task'),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Test Prompt',
            systemMessage: 'System',
            userMessage: 'Summarize this task', // No {{task}} placeholder
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: [InputDataType.task],
            // ignore: deprecated_member_use_from_same_package
            aiResponseType: AiResponseType.taskSummary,
          );

          const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
          when(
            () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
          ).thenAnswer((_) async => mockTaskJson);

          // Act
          final prompt = await promptBuilder.buildPromptWithData(
            promptConfig: promptConfig,
            entity: task,
          );

          // Assert
          expect(prompt, equals('Summarize this task \n $mockTaskJson'));
        },
      );

      test('should not append task data if not required', () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: 'Test task'),
        );

        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'Simple prompt',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [], // No task data required
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert
        expect(prompt, equals('Simple prompt'));
        verifyNever(
          () => mockAiInputRepository.buildTaskDetailsJson(
            id: any<String>(named: 'id'),
          ),
        );
      });

      test('should handle null task JSON gracefully', () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: 'Test task'),
        );

        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'Process this task: {{task}}',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        when(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).thenAnswer((_) async => null);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - placeholder remains when task JSON is null
        expect(prompt, equals('Process this task: {{task}}'));
      });

      test(
        'should use tracked template message when tracking is enabled',
        () async {
          // Arrange
          const taskId = 'task-123';
          final testDate = DateTime(2025, 12, 20, 14, 30);
          final task = Task(
            data: TaskData(
              title: 'Test Task',
              status: TaskStatus.open(
                id: 'status_id',
                createdAt: testDate,
                utcOffset: 0,
              ),
              statusHistory: [],
              dateFrom: testDate,
              dateTo: testDate,
            ),
            meta: Metadata(
              id: taskId,
              createdAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              updatedAt: testDate,
            ),
            entryText: const EntryText(plainText: 'Test task'),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Test Prompt',
            systemMessage: 'Custom system',
            userMessage: 'Custom user message',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: testDate,
            useReasoning: false,
            requiredInputData: [InputDataType.task],
            aiResponseType: AiResponseType.imagePromptGeneration,
            trackPreconfigured: true,
            preconfiguredPromptId: 'image_prompt_generation',
          );

          const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
          when(
            () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
          ).thenAnswer((_) async => mockTaskJson);

          // Act
          final prompt = await promptBuilder.buildPromptWithData(
            promptConfig: promptConfig,
            entity: task,
          );

          // Assert - should use template message, not custom message
          expect(prompt, isNotNull);
          // Verify it doesn't contain the custom message (template was used instead)
          expect(prompt, isNot(contains('Custom user message')));
          // Verify it uses the preconfigured image prompt generation template
          expect(
            prompt,
            contains('Transform this audio transcription or text entry'),
          );
        },
      );

      test('should handle error in buildLinkedTasksJson gracefully', () async {
        // Arrange
        const taskId = 'task-123';
        final testDate = DateTime(2025, 12, 20, 14, 30);
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: testDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: testDate,
            dateTo: testDate,
          ),
          meta: Metadata(
            id: taskId,
            createdAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            updatedAt: testDate,
          ),
          entryText: const EntryText(plainText: 'Test task'),
        );

        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'Task: {{task}}\nLinked: {{linked_tasks}}',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: testDate,
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).thenAnswer((_) async => mockTaskJson);
        // Make buildLinkedTasksJson throw an exception
        when(
          () => mockAiInputRepository.buildLinkedTasksJson(taskId),
        ).thenThrow(Exception('Database error'));

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - should use fallback empty JSON despite error
        expect(prompt, contains('{"linked_from": [], "linked_to": []}'));
        expect(prompt, contains(mockTaskJson));
      });

      test(
        'should handle non-task entities without task placeholder',
        () async {
          // Arrange
          final image = JournalImage(
            data: ImageData(
              imageId: 'image-123',
              imageFile: 'test.jpg',
              imageDirectory: '/test',
              capturedAt: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: 'image-123',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            entryText: const EntryText(plainText: 'Test image'),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Test Prompt',
            systemMessage: 'System',
            userMessage: 'Analyze this image',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          // Act
          final prompt = await promptBuilder.buildPromptWithData(
            promptConfig: promptConfig,
            entity: image,
          );

          // Assert
          expect(prompt, equals('Analyze this image'));
          verifyNever(
            () => mockAiInputRepository.buildTaskDetailsJson(
              id: any<String>(named: 'id'),
            ),
          );
        },
      );
    });

    group('Edge cases', () {
      test('should handle empty user message', () async {
        // Arrange
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: 'task-123',
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: 'Test task'),
        );

        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: '', // Empty message
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert
        expect(prompt, equals(''));
      });

      test('should handle multiple {{task}} placeholders', () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          entryText: const EntryText(plainText: 'Test task'),
        );

        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'First: {{task}}, Second: {{task}}',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime(2024, 3, 15),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        const mockTaskJson = '{"id": "task-123"}';
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).thenAnswer((_) async => mockTaskJson);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - all placeholders should be replaced
        expect(prompt, equals('First: $mockTaskJson, Second: $mockTaskJson'));
        // Should only call once even with multiple placeholders
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
      });
    });

    group('Image/Audio with linked tasks', () {
      test(
        'should find linked task for image entity with {{task}} placeholder',
        () async {
          // Arrange
          final image = JournalImage(
            data: ImageData(
              imageId: 'image-123',
              imageFile: 'test.jpg',
              imageDirectory: '/test',
              capturedAt: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: 'image-123',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            entryText: const EntryText(plainText: 'Test image'),
          );

          final linkedTask = Task(
            data: TaskData(
              title: 'Linked Task',
              status: TaskStatus.open(
                id: 'status_id',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 0,
              ),
              statusHistory: [],
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: 'task-456',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            entryText: const EntryText(plainText: 'Test task'),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Test Prompt',
            systemMessage: 'System',
            userMessage: 'Analyze this image: {{task}}',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          // Create a builder with journal repository
          final mockJournalRepository = MockJournalRepository();
          final builderWithJournal = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          when(
            () =>
                mockJournalRepository.getLinkedEntities(linkedTo: 'image-123'),
          ).thenAnswer((_) async => [linkedTask]);
          when(
            () => mockAiInputRepository.buildTaskDetailsJson(id: 'task-456'),
          ).thenAnswer(
            (_) async => '{"id": "task-456", "title": "Linked Task"}',
          );

          // Act
          final prompt = await builderWithJournal.buildPromptWithData(
            promptConfig: promptConfig,
            entity: image,
          );

          // Assert
          expect(
            prompt,
            equals(
              'Analyze this image: {"id": "task-456", "title": "Linked Task"}',
            ),
          );
          verify(
            () =>
                mockJournalRepository.getLinkedEntities(linkedTo: 'image-123'),
          ).called(1);
          verify(
            () => mockAiInputRepository.buildTaskDetailsJson(id: 'task-456'),
          ).called(1);
        },
      );

      test(
        'should find linked task for image entity with {{linked_tasks}} placeholder',
        () async {
          // Arrange
          final image = JournalImage(
            data: ImageData(
              imageId: 'image-linked-tasks',
              imageFile: 'test.jpg',
              imageDirectory: '/test',
              capturedAt: DateTime(2025, 1, 1),
            ),
            meta: Metadata(
              id: 'image-linked-tasks',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
            entryText: const EntryText(plainText: 'Test image'),
          );

          final linkedTask = Task(
            data: TaskData(
              title: 'Linked Task',
              checklistIds: const [],
              status: TaskStatus.inProgress(
                id: 'status-456',
                createdAt: DateTime(2025, 1, 1),
                utcOffset: 0,
              ),
              statusHistory: const [],
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
            ),
            meta: Metadata(
              id: 'task-456',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Image Analysis with Context',
            systemMessage: 'System',
            userMessage: 'Analyze image with context: {{linked_tasks}}',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2025, 1, 1),
            useReasoning: false,
            requiredInputData: [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          // Create a builder with journal repository
          final mockJournalRepository = MockJournalRepository();
          final builderWithJournal = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'image-linked-tasks',
            ),
          ).thenAnswer((_) async => [linkedTask]);
          when(
            () => mockAiInputRepository.buildLinkedTasksJson('task-456'),
          ).thenAnswer(
            (_) async =>
                '{"linked_from": [{"id": "child-1"}], "linked_to": []}',
          );

          // Act
          final prompt = await builderWithJournal.buildPromptWithData(
            promptConfig: promptConfig,
            entity: image,
          );

          // Assert - should contain the linked tasks with note added
          expect(prompt, contains('linked_from'));
          expect(prompt, contains('child-1'));
          expect(prompt, contains('note'));
          expect(prompt, contains('web search'));
          verify(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'image-linked-tasks',
            ),
          ).called(1);
          verify(
            () => mockAiInputRepository.buildLinkedTasksJson('task-456'),
          ).called(1);
        },
      );

      test(
        'should find linked task for audio entity with {{linked_tasks}} placeholder',
        () async {
          // Arrange
          final audio = JournalAudio(
            data: AudioData(
              audioFile: 'audio.m4a',
              audioDirectory: '/test',
              duration: const Duration(minutes: 5),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
            ),
            meta: Metadata(
              id: 'audio-linked-tasks',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
            entryText: const EntryText(plainText: 'Test audio'),
          );

          final linkedTask = Task(
            data: TaskData(
              title: 'Audio Task',
              checklistIds: const [],
              status: TaskStatus.done(
                id: 'status-789',
                createdAt: DateTime(2025, 1, 1),
                utcOffset: 0,
              ),
              statusHistory: const [],
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
            ),
            meta: Metadata(
              id: 'task-789',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Audio Transcription with Context',
            systemMessage: 'System',
            userMessage: 'Transcribe audio with context: {{linked_tasks}}',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2025, 1, 1),
            useReasoning: false,
            requiredInputData: [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          // Create a builder with journal repository
          final mockJournalRepository = MockJournalRepository();
          final builderWithJournal = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'audio-linked-tasks',
            ),
          ).thenAnswer((_) async => [linkedTask]);
          when(
            () => mockAiInputRepository.buildLinkedTasksJson('task-789'),
          ).thenAnswer(
            (_) async =>
                '{"linked_from": [], "linked_to": [{"id": "parent-1"}]}',
          );

          // Act
          final prompt = await builderWithJournal.buildPromptWithData(
            promptConfig: promptConfig,
            entity: audio,
          );

          // Assert - should contain the linked tasks with note added
          expect(prompt, contains('linked_to'));
          expect(prompt, contains('parent-1'));
          expect(prompt, contains('note'));
          expect(prompt, contains('web search'));
          verify(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'audio-linked-tasks',
            ),
          ).called(1);
          verify(
            () => mockAiInputRepository.buildLinkedTasksJson('task-789'),
          ).called(1);
        },
      );

      test(
        'should return empty linked tasks when image has no linked task',
        () async {
          // Arrange
          final image = JournalImage(
            data: ImageData(
              imageId: 'orphan-image',
              imageFile: 'test.jpg',
              imageDirectory: '/test',
              capturedAt: DateTime(2025, 1, 1),
            ),
            meta: Metadata(
              id: 'orphan-image',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
          );

          final promptConfig = AiConfigPrompt(
            id: 'test-prompt',
            name: 'Image Analysis',
            systemMessage: 'System',
            userMessage: 'Context: {{linked_tasks}}',
            defaultModelId: 'model-1',
            modelIds: ['model-1'],
            createdAt: DateTime(2025, 1, 1),
            useReasoning: false,
            requiredInputData: [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          // Create a builder with journal repository
          final mockJournalRepository = MockJournalRepository();
          final builderWithJournal = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          // No linked task found
          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'orphan-image',
            ),
          ).thenAnswer((_) async => []);

          // Act
          final prompt = await builderWithJournal.buildPromptWithData(
            promptConfig: promptConfig,
            entity: image,
          );

          // Assert - should return empty arrays (fallback)
          expect(prompt, contains('"linked_from": []'));
          expect(prompt, contains('"linked_to": []'));
          // No note since there are no linked tasks
          expect(prompt, isNot(contains('note')));
          verify(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'orphan-image',
            ),
          ).called(1);
          verifyNever(() => mockAiInputRepository.buildLinkedTasksJson(any()));
        },
      );
    });

    group('languageCode placeholder injection', () {
      test('injects language code from task entity', () async {
        final task = Task(
          data: TaskData(
            title: 'German Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2025, 1, 1),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            languageCode: 'de',
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Image Analysis',
          systemMessage: 'System',
          userMessage: '{{languageCode}}\n\nAnalyze the image.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        expect(result, equals('de\n\nAnalyze the image.'));
      });

      test('injects language code from linked task for image entity', () async {
        final image = JournalImage(
          data: ImageData(
            imageId: 'image-123',
            imageFile: 'test.jpg',
            imageDirectory: '/test',
            capturedAt: DateTime(2025, 1, 1),
          ),
          meta: Metadata(
            id: 'image-123',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        final linkedTask = Task(
          data: TaskData(
            title: 'French Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2025, 1, 1),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            languageCode: 'fr',
          ),
          meta: Metadata(
            id: 'task-456',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        final mockJournalRepository = MockJournalRepository();
        final builderWithJournal = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          journalRepository: mockJournalRepository,
          taskSummaryResolver: MockTaskSummaryResolver(),
        );

        when(
          () => mockJournalRepository.getLinkedEntities(linkedTo: 'image-123'),
        ).thenAnswer((_) async => [linkedTask]);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Image Analysis',
          systemMessage: 'System',
          userMessage: '{{languageCode}}\n\nAnalyze the image.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final result = await builderWithJournal.buildPromptWithData(
          promptConfig: config,
          entity: image,
        );

        expect(result, equals('fr\n\nAnalyze the image.'));
      });

      test(
        'replaces with empty string when no language code available',
        () async {
          final task = Task(
            data: TaskData(
              title: 'Task without language',
              checklistIds: const [],
              status: TaskStatus.open(
                id: 'status',
                createdAt: DateTime(2025, 1, 1),
                utcOffset: 0,
              ),
              statusHistory: const [],
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              // No languageCode set
            ),
            meta: Metadata(
              id: 'task-1',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
          );

          final config = AiConfigPrompt(
            id: 'prompt',
            name: 'Image Analysis',
            systemMessage: 'System',
            userMessage: '{{languageCode}}\n\nAnalyze the image.',
            defaultModelId: 'model-1',
            modelIds: const ['model-1'],
            createdAt: DateTime(2025, 1, 1),
            useReasoning: false,
            requiredInputData: const [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: task,
          );

          expect(result, equals('\n\nAnalyze the image.'));
        },
      );

      test(
        'replaces with empty string for image without linked task',
        () async {
          final image = JournalImage(
            data: ImageData(
              imageId: 'image-123',
              imageFile: 'test.jpg',
              imageDirectory: '/test',
              capturedAt: DateTime(2025, 1, 1),
            ),
            meta: Metadata(
              id: 'image-123',
              createdAt: DateTime(2025, 1, 1),
              dateFrom: DateTime(2025, 1, 1),
              dateTo: DateTime(2025, 1, 1),
              updatedAt: DateTime(2025, 1, 1),
            ),
          );

          final mockJournalRepository = MockJournalRepository();
          final builderWithJournal = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          // No linked task
          when(
            () =>
                mockJournalRepository.getLinkedEntities(linkedTo: 'image-123'),
          ).thenAnswer((_) async => []);

          final config = AiConfigPrompt(
            id: 'prompt',
            name: 'Image Analysis',
            systemMessage: 'System',
            userMessage: '{{languageCode}}\n\nAnalyze the image.',
            defaultModelId: 'model-1',
            modelIds: const ['model-1'],
            createdAt: DateTime(2025, 1, 1),
            useReasoning: false,
            requiredInputData: const [InputDataType.images],
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final result = await builderWithJournal.buildPromptWithData(
            promptConfig: config,
            entity: image,
          );

          expect(result, equals('\n\nAnalyze the image.'));
        },
      );
    });

    group('error handling for placeholder injection', () {
      test('handles error when languageCode fetch fails', () async {
        final image = JournalImage(
          data: ImageData(
            imageId: 'image-123',
            imageFile: 'test.jpg',
            imageDirectory: '/test',
            capturedAt: DateTime(2025, 1, 1),
          ),
          meta: Metadata(
            id: 'image-123',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        final mockJournalRepository = MockJournalRepository();
        final builderWithJournal = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          journalRepository: mockJournalRepository,
          taskSummaryResolver: MockTaskSummaryResolver(),
        );

        // Simulate an error when finding linked task
        when(
          () => mockJournalRepository.getLinkedEntities(linkedTo: 'image-123'),
        ).thenThrow(Exception('Database error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Image Analysis',
          systemMessage: 'System',
          userMessage: '{{languageCode}}\n\nAnalyze the image.',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        final result = await builderWithJournal.buildPromptWithData(
          promptConfig: config,
          entity: image,
        );

        // Should replace with empty string on error
        expect(result, equals('\n\nAnalyze the image.'));
      });
    });

    group('correction_examples placeholder injection', () {
      // These tests exercise _buildCorrectionExamplesPromptText which is only
      // reached when the user message contains {{correction_examples}} AND
      // promptConfig.aiResponseType == AiResponseType.audioTranscription.
      // They also require EntitiesCacheService to be registered in GetIt.

      // Helper that builds the standard audioTranscription promptConfig with
      // the {{correction_examples}} placeholder in the user message.
      AiConfigPrompt correctionExamplesConfig() => AiConfigPrompt(
        id: 'transcription-prompt',
        name: 'Transcription',
        systemMessage: 'System',
        userMessage: 'Transcribe: {{correction_examples}}',
        defaultModelId: 'model-1',
        modelIds: const ['model-1'],
        createdAt: DateTime(2024, 3, 15),
        useReasoning: false,
        requiredInputData: const [InputDataType.audioFiles],
        aiResponseType: AiResponseType.audioTranscription,
      );

      // Helper that builds a Task with the given categoryId set.
      Task taskWithCategory(String taskId, String categoryId) => Task(
        data: TaskData(
          title: 'My Task',
          checklistIds: const [],
          status: TaskStatus.open(
            id: 'status',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        meta: Metadata(
          id: taskId,
          createdAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          categoryId: categoryId,
        ),
      );

      test(
        'injects formatted correction examples when category has examples',
        () async {
          const categoryId = 'cat-1';
          final examples = [
            const ChecklistCorrectionExample(
              before: 'wrong',
              after: 'right',
              capturedAt: null,
            ),
            ChecklistCorrectionExample(
              before: 'old',
              after: 'new',
              capturedAt: DateTime(2024, 2, 1),
            ),
            ChecklistCorrectionExample(
              before: 'earlier',
              after: 'later',
              capturedAt: DateTime(2024, 3, 1),
            ),
          ];
          final category = CategoryTestUtils.createTestCategory(
            id: categoryId,
            name: 'Work',
            correctionExamples: examples,
          );

          final mockCache = MockEntitiesCacheService();
          when(
            () => mockCache.getCategoryById(categoryId),
          ).thenReturn(category);

          await setUpTestGetIt(
            additionalSetup: () {
              getIt.registerSingleton<EntitiesCacheService>(mockCache);
            },
          );
          addTearDown(tearDownTestGetIt);

          final task = taskWithCategory('task-1', categoryId);
          final config = correctionExamplesConfig();

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: task,
          );

          // The template header must be present
          expect(result, contains('USER-PROVIDED CORRECTION EXAMPLES'));
          // All examples must appear as "before" → "after" lines
          expect(result, contains('"wrong" → "right"'));
          expect(result, contains('"old" → "new"'));
          expect(result, contains('"earlier" → "later"'));
        },
      );

      test(
        'sorts examples by capturedAt descending (most recent first)',
        () async {
          const categoryId = 'cat-sort';
          final examples = [
            ChecklistCorrectionExample(
              before: 'alpha',
              after: 'A',
              capturedAt: DateTime(2024, 1, 1),
            ),
            ChecklistCorrectionExample(
              before: 'gamma',
              after: 'C',
              capturedAt: DateTime(2024, 3, 1),
            ),
            ChecklistCorrectionExample(
              before: 'beta',
              after: 'B',
              capturedAt: DateTime(2024, 2, 1),
            ),
          ];
          final category = CategoryTestUtils.createTestCategory(
            id: categoryId,
            correctionExamples: examples,
          );

          final mockCache = MockEntitiesCacheService();
          when(
            () => mockCache.getCategoryById(categoryId),
          ).thenReturn(category);

          await setUpTestGetIt(
            additionalSetup: () {
              getIt.registerSingleton<EntitiesCacheService>(mockCache);
            },
          );
          addTearDown(tearDownTestGetIt);

          final task = taskWithCategory('task-sort', categoryId);
          final config = correctionExamplesConfig();

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: task,
          );

          // gamma (2024-03-01) must appear before beta (2024-02-01) which must
          // appear before alpha (2024-01-01) in the output.
          final gammaIdx = result!.indexOf('"gamma"');
          final betaIdx = result.indexOf('"beta"');
          final alphaIdx = result.indexOf('"alpha"');
          expect(gammaIdx, lessThan(betaIdx));
          expect(betaIdx, lessThan(alphaIdx));
        },
      );

      test('caps examples at _kMaxCorrectionExamples (500)', () async {
        const categoryId = 'cat-cap';
        // Create 505 examples – only the first 500 (after sort) should appear.
        final examples = List.generate(
          505,
          (i) => ChecklistCorrectionExample(
            before: 'before_$i',
            after: 'after_$i',
            capturedAt: DateTime(2024, 1, i + 1 > 28 ? 28 : i + 1),
          ),
        );
        final category = CategoryTestUtils.createTestCategory(
          id: categoryId,
          correctionExamples: examples,
        );

        final mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(categoryId)).thenReturn(category);

        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<EntitiesCacheService>(mockCache);
          },
        );
        addTearDown(tearDownTestGetIt);

        final task = taskWithCategory('task-cap', categoryId);
        final config = correctionExamplesConfig();

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        // Count how many formatted lines are in the output
        final lineCount = RegExp('- ".*?" → ".*?"').allMatches(result!).length;
        expect(lineCount, equals(500));
      });

      test('returns empty string when task has no category', () async {
        await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);

        // Task without a categoryId
        final task = Task(
          data: TaskData(
            title: 'Uncategorised',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: 'task-nocat',
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            // no categoryId
          ),
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: correctionExamplesConfig(),
          entity: task,
        );

        // Placeholder must be replaced with '' (no header injected)
        expect(result, equals('Transcribe: '));
        expect(result, isNot(contains('USER-PROVIDED CORRECTION EXAMPLES')));
      });

      test('returns empty string when category not found in cache', () async {
        final mockCache = MockEntitiesCacheService();
        when(() => mockCache.getCategoryById(any())).thenReturn(null);

        await setUpTestGetIt(
          additionalSetup: () {
            getIt.registerSingleton<EntitiesCacheService>(mockCache);
          },
        );
        addTearDown(tearDownTestGetIt);

        final task = taskWithCategory('task-notfound', 'missing-cat');

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: correctionExamplesConfig(),
          entity: task,
        );

        expect(result, equals('Transcribe: '));
      });

      test(
        'returns empty string when category has no correction examples',
        () async {
          const categoryId = 'cat-empty';
          final category = CategoryTestUtils.createTestCategory(
            id: categoryId,
            correctionExamples: const [],
          );

          final mockCache = MockEntitiesCacheService();
          when(
            () => mockCache.getCategoryById(categoryId),
          ).thenReturn(category);

          await setUpTestGetIt(
            additionalSetup: () {
              getIt.registerSingleton<EntitiesCacheService>(mockCache);
            },
          );
          addTearDown(tearDownTestGetIt);

          final task = taskWithCategory('task-empty', categoryId);

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: correctionExamplesConfig(),
            entity: task,
          );

          expect(result, equals('Transcribe: '));
        },
      );

      test(
        'returns empty string and does not inject when entity is a '
        'non-task JournalAudio without a linked task',
        () async {
          final mockJournalRepository = MockJournalRepository();
          final builder = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          final audio = JournalAudio(
            data: AudioData(
              audioFile: 'audio.m4a',
              audioDirectory: '/test',
              duration: const Duration(minutes: 1),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: 'audio-no-task',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
          );

          // No linked task found in either direction
          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'audio-no-task',
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockJournalRepository.getLinkedToEntities(
              linkedTo: 'audio-no-task',
            ),
          ).thenAnswer((_) async => []);

          await setUpTestGetIt();
          addTearDown(tearDownTestGetIt);

          final result = await builder.buildPromptWithData(
            promptConfig: correctionExamplesConfig(),
            entity: audio,
          );

          expect(result, equals('Transcribe: '));
        },
      );

      test(
        'replaces placeholder with empty string and logs error when '
        'cache.getCategoryById throws',
        () async {
          final mockCache = MockEntitiesCacheService();
          when(
            () => mockCache.getCategoryById(any()),
          ).thenThrow(Exception('cache exploded'));

          await setUpTestGetIt(
            additionalSetup: () {
              getIt.registerSingleton<EntitiesCacheService>(mockCache);
            },
          );
          addTearDown(tearDownTestGetIt);

          final task = taskWithCategory('task-throw', 'cat-throw');

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: correctionExamplesConfig(),
            entity: task,
          );

          // Placeholder must be replaced with '' on error (not left in prompt)
          expect(result, equals('Transcribe: '));
          expect(result, isNot(contains('{{correction_examples}}')));
        },
      );

      test(
        'does NOT inject correction_examples when aiResponseType is not '
        'audioTranscription (placeholder left unchanged)',
        () async {
          const categoryId = 'cat-wrong-type';
          final category = CategoryTestUtils.createTestCategory(
            id: categoryId,
            correctionExamples: [
              const ChecklistCorrectionExample(
                before: 'x',
                after: 'y',
              ),
            ],
          );

          final mockCache = MockEntitiesCacheService();
          when(
            () => mockCache.getCategoryById(categoryId),
          ).thenReturn(category);

          await setUpTestGetIt(
            additionalSetup: () {
              getIt.registerSingleton<EntitiesCacheService>(mockCache);
            },
          );
          addTearDown(tearDownTestGetIt);

          final task = taskWithCategory('task-wrong-type', categoryId);

          // Same prompt but with a non-audioTranscription response type
          final config = AiConfigPrompt(
            id: 'other-prompt',
            name: 'Other',
            systemMessage: 'System',
            userMessage: 'Do something: {{correction_examples}}',
            defaultModelId: 'model-1',
            modelIds: const ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: const [InputDataType.task],
            aiResponseType: AiResponseType.imageAnalysis, // <-- wrong type
          );

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: task,
          );

          // Placeholder must NOT be replaced
          expect(result, contains('{{correction_examples}}'));
          expect(result, isNot(contains('"x" → "y"')));
        },
      );
    });

    group('_resolveEntryText audio transcript reduce path', () {
      // Exercises lines 583-585: when a JournalAudio has multiple transcripts,
      // the one with the latest `created` date is selected.

      test(
        'uses the most recent transcript when multiple transcripts exist',
        () async {
          // audioTranscript placeholder triggers _resolveAudioTranscript →
          // _resolveEntryText → reduce path.
          final audio = JournalAudio(
            data: AudioData(
              audioFile: 'multi.m4a',
              audioDirectory: '/test',
              duration: const Duration(minutes: 2),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              transcripts: [
                AudioTranscript(
                  created: DateTime(2024, 1, 1),
                  library: 'lib-a',
                  model: 'model-a',
                  detectedLanguage: 'en',
                  transcript: 'older transcript text',
                ),
                AudioTranscript(
                  created: DateTime(2024, 6, 1),
                  library: 'lib-b',
                  model: 'model-b',
                  detectedLanguage: 'en',
                  transcript: 'newest transcript text',
                ),
                AudioTranscript(
                  created: DateTime(2024, 3, 1),
                  library: 'lib-c',
                  model: 'model-c',
                  detectedLanguage: 'en',
                  transcript: 'middle transcript text',
                ),
              ],
            ),
            meta: Metadata(
              id: 'audio-multi',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            // No entryText so _resolveEntryText falls through to reduce path
          );

          final config = AiConfigPrompt(
            id: 'audio-prompt',
            name: 'Audio Prompt',
            systemMessage: 'System',
            userMessage: 'Content: {{audioTranscript}}',
            defaultModelId: 'model-1',
            modelIds: const ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: const [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: audio,
          );

          // Only the newest transcript (created 2024-06-01) should be injected
          expect(result, equals('Content: newest transcript text'));
          expect(result, isNot(contains('older transcript text')));
          expect(result, isNot(contains('middle transcript text')));
        },
      );

      test(
        'returns [No transcription available] when all transcripts are empty',
        () async {
          final audio = JournalAudio(
            data: AudioData(
              audioFile: 'empty.m4a',
              audioDirectory: '/test',
              duration: const Duration(minutes: 1),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              transcripts: [
                AudioTranscript(
                  created: DateTime(2024, 1, 1),
                  library: 'lib',
                  model: 'model',
                  detectedLanguage: 'en',
                  transcript: '   ', // whitespace only
                ),
              ],
            ),
            meta: Metadata(
              id: 'audio-empty-transcript',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
          );

          final config = AiConfigPrompt(
            id: 'audio-prompt',
            name: 'Audio Prompt',
            systemMessage: 'System',
            userMessage: 'Content: {{audioTranscript}}',
            defaultModelId: 'model-1',
            modelIds: const ['model-1'],
            createdAt: DateTime(2024, 3, 15),
            useReasoning: false,
            requiredInputData: const [InputDataType.audioFiles],
            aiResponseType: AiResponseType.audioTranscription,
          );

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: audio,
          );

          expect(result, equals('Content: [No transcription available]'));
        },
      );
    });
  });
}
