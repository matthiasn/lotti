import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';

// Mocks
class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  late PromptBuilderHelper promptBuilder;
  late MockAiInputRepository mockAiInputRepository;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
  });

  setUp(() {
    mockAiInputRepository = MockAiInputRepository();
    promptBuilder = PromptBuilderHelper(
      aiInputRepository: mockAiInputRepository,
    );
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
          preconfiguredPromptId: 'task_summary',
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
          trackPreconfigured: true,
          preconfiguredPromptId: 'task_summary',
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
        final template = preconfiguredPrompts['task_summary']!;
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
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

      test('should return base message when preconfigured prompt not found',
          () {
        // Arrange
        final promptConfig = AiConfigPrompt(
          id: 'test-prompt',
          name: 'Test Prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
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
      });
    });

    group('buildPromptWithData', () {
      test('should replace {{task}} placeholder with task JSON for task entity',
          () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => mockTaskJson);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert
        expect(prompt, equals('Process this task: $mockTaskJson'));
        verify(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .called(1);
      });

      test('should handle missing {{task}} placeholder with legacy format',
          () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => mockTaskJson);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert
        expect(prompt, equals('Summarize this task \n $mockTaskJson'));
      });

      test('should not append task data if not required', () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [], // No task data required
          aiResponseType: AiResponseType.taskSummary,
        );

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert
        expect(prompt, equals('Simple prompt'));
        verifyNever(() =>
            mockAiInputRepository.buildTaskDetailsJson(id: any(named: 'id')));
      });

      test('should handle null task JSON gracefully', () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => null);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - placeholder remains when task JSON is null
        expect(prompt, equals('Process this task: {{task}}'));
      });

      test('should use tracked template message when tracking is enabled',
          () async {
        // Arrange
        const taskId = 'task-123';
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
          trackPreconfigured: true,
          preconfiguredPromptId: 'task_summary',
        );

        const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => mockTaskJson);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - should use template message, not custom message
        final template = preconfiguredPrompts['task_summary']!;
        // The expected prompt should be the template's userMessage with {{task}} replaced
        final expectedPrompt =
            template.userMessage.replaceAll('{{task}}', mockTaskJson);
        expect(prompt, equals(expectedPrompt));
        // Verify it doesn't contain the custom message
        expect(prompt, isNot(contains('Custom user message')));
      });

      test('should handle non-task entities without task placeholder',
          () async {
        // Arrange
        final image = JournalImage(
          data: ImageData(
            imageId: 'image-123',
            imageFile: 'test.jpg',
            imageDirectory: '/test',
            capturedAt: DateTime.now(),
          ),
          meta: Metadata(
            id: 'image-123',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
        verifyNever(() =>
            mockAiInputRepository.buildTaskDetailsJson(id: any(named: 'id')));
      });
    });

    group('Edge cases', () {
      test('should handle empty user message', () async {
        // Arrange
        final task = Task(
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: 'task-123',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [],
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
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        );

        const mockTaskJson = '{"id": "task-123"}';
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => mockTaskJson);

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - all placeholders should be replaced
        expect(prompt, equals('First: $mockTaskJson, Second: $mockTaskJson'));
        // Should only call once even with multiple placeholders
        verify(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .called(1);
      });
    });

    group('Image/Audio with linked tasks', () {
      test('should find linked task for image entity with {{task}} placeholder',
          () async {
        // Arrange
        final image = JournalImage(
          data: ImageData(
            imageId: 'image-123',
            imageFile: 'test.jpg',
            imageDirectory: '/test',
            capturedAt: DateTime.now(),
          ),
          meta: Metadata(
            id: 'image-123',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          entryText: const EntryText(plainText: 'Test image'),
        );

        final linkedTask = Task(
          data: TaskData(
            title: 'Linked Task',
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: 'task-456',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.images],
          aiResponseType: AiResponseType.imageAnalysis,
        );

        // Create a builder with journal repository
        final mockJournalRepository = MockJournalRepository();
        final builderWithJournal = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          journalRepository: mockJournalRepository,
        );

        when(() => mockJournalRepository.getLinkedToEntities(
            linkedTo: 'image-123')).thenAnswer((_) async => [linkedTask]);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: 'task-456'))
            .thenAnswer(
                (_) async => '{"id": "task-456", "title": "Linked Task"}');

        // Act
        final prompt = await builderWithJournal.buildPromptWithData(
          promptConfig: promptConfig,
          entity: image,
        );

        // Assert
        expect(
            prompt,
            equals(
                'Analyze this image: {"id": "task-456", "title": "Linked Task"}'));
        verify(() => mockJournalRepository.getLinkedToEntities(
            linkedTo: 'image-123')).called(1);
        verify(() => mockAiInputRepository.buildTaskDetailsJson(id: 'task-456'))
            .called(1);
      });
    });
  });
}
