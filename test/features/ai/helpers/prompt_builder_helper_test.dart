// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_link.dart'
    as agent_link_model;
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

// ---------------------------------------------------------------------------
// From prompt_builder_helper_current_task_summary_test.dart
// Agent repository that always returns empty links so the resolver falls back
// to legacy AI response entries.
// ---------------------------------------------------------------------------

class _EmptyAgentRepository extends Fake implements AgentRepository {
  @override
  Future<List<agent_link_model.AgentLink>> getLinksTo(
    String toId, {
    String? type,
  }) async => [];
}

/// File-level factory for the boilerplate-heavy [AiConfigPrompt] blocks.
/// Only the parts that vary between tests are parameters; everything else
/// is a fixed default.
AiConfigPrompt _makePromptConfig({
  String id = 'prompt',
  String name = 'Test Prompt',
  String systemMessage = 'System message',
  String userMessage = 'User message',
  String defaultModelId = 'model-1',
  List<String> modelIds = const ['model-1'],
  DateTime? createdAt,
  bool useReasoning = false,
  List<InputDataType> requiredInputData = const [],
  AiResponseType aiResponseType = AiResponseType.audioTranscription,
  String? preconfiguredPromptId,
  bool trackPreconfigured = false,
}) {
  return AiConfigPrompt(
    id: id,
    name: name,
    systemMessage: systemMessage,
    userMessage: userMessage,
    defaultModelId: defaultModelId,
    modelIds: modelIds,
    createdAt: createdAt ?? DateTime(2025),
    useReasoning: useReasoning,
    requiredInputData: requiredInputData,
    aiResponseType: aiResponseType,
    preconfiguredPromptId: preconfiguredPromptId,
    trackPreconfigured: trackPreconfigured,
  );
}

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
        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          createdAt: DateTime(2024, 3, 15),
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
        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          createdAt: DateTime(2024, 3, 15),
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
        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'Custom system message',
          userMessage: 'Custom user message',
          createdAt: DateTime(2024, 3, 15),
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
          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            systemMessage: 'Custom system message',
            userMessage: 'Custom user message',
            createdAt: DateTime(2024, 3, 15),
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            systemMessage: 'System',
            userMessage: 'Process this task: {{task}}',
            createdAt: DateTime(2024, 3, 15),
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            systemMessage: 'System',
            userMessage: 'Summarize this task',
            // No {{task}} placeholder
            defaultModelId: 'model-1',
            createdAt: DateTime(2024, 3, 15),
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

        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'System',
          userMessage: 'Simple prompt',
          createdAt: DateTime(2024, 3, 15),
          // No task data required
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

        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'System',
          userMessage: 'Process this task: {{task}}',
          createdAt: DateTime(2024, 3, 15),
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            systemMessage: 'Custom system',
            userMessage: 'Custom user message',
            createdAt: testDate,
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

        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'System',
          userMessage: 'Task: {{task}}\nLinked: {{linked_tasks}}',
          createdAt: testDate,
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            systemMessage: 'System',
            userMessage: 'Analyze this image',
            createdAt: DateTime(2024, 3, 15),
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

        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'System',
          userMessage: '',
          // Empty message
          defaultModelId: 'model-1',
          createdAt: DateTime(2024, 3, 15),
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

        final promptConfig = _makePromptConfig(
          id: 'test-prompt',
          systemMessage: 'System',
          userMessage: 'First: {{task}}, Second: {{task}}',
          createdAt: DateTime(2024, 3, 15),
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            systemMessage: 'System',
            userMessage: 'Analyze this image: {{task}}',
            createdAt: DateTime(2024, 3, 15),
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            name: 'Image Analysis with Context',
            systemMessage: 'System',
            userMessage: 'Analyze image with context: {{linked_tasks}}',
            createdAt: DateTime(2025, 1, 1),
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            name: 'Audio Transcription with Context',
            systemMessage: 'System',
            userMessage: 'Transcribe audio with context: {{linked_tasks}}',
            createdAt: DateTime(2025, 1, 1),
            requiredInputData: [InputDataType.audioFiles],
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

          final promptConfig = _makePromptConfig(
            id: 'test-prompt',
            name: 'Image Analysis',
            systemMessage: 'System',
            userMessage: 'Context: {{linked_tasks}}',
            createdAt: DateTime(2025, 1, 1),
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

        final config = _makePromptConfig(
          name: 'Image Analysis',
          systemMessage: 'System',
          userMessage: '{{languageCode}}\n\nAnalyze the image.',
          createdAt: DateTime(2025, 1, 1),
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

        final config = _makePromptConfig(
          name: 'Image Analysis',
          systemMessage: 'System',
          userMessage: '{{languageCode}}\n\nAnalyze the image.',
          createdAt: DateTime(2025, 1, 1),
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

          final config = _makePromptConfig(
            name: 'Image Analysis',
            systemMessage: 'System',
            userMessage: '{{languageCode}}\n\nAnalyze the image.',
            createdAt: DateTime(2025, 1, 1),
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

          final config = _makePromptConfig(
            name: 'Image Analysis',
            systemMessage: 'System',
            userMessage: '{{languageCode}}\n\nAnalyze the image.',
            createdAt: DateTime(2025, 1, 1),
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

        final config = _makePromptConfig(
          name: 'Image Analysis',
          systemMessage: 'System',
          userMessage: '{{languageCode}}\n\nAnalyze the image.',
          createdAt: DateTime(2025, 1, 1),
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
      AiConfigPrompt correctionExamplesConfig() => _makePromptConfig(
        id: 'transcription-prompt',
        name: 'Transcription',
        systemMessage: 'System',
        userMessage: 'Transcribe: {{correction_examples}}',
        createdAt: DateTime(2024, 3, 15),
        requiredInputData: const [InputDataType.audioFiles],
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

          final config = _makePromptConfig(
            id: 'audio-prompt',
            name: 'Audio Prompt',
            systemMessage: 'System',
            userMessage: 'Content: {{audioTranscript}}',
            createdAt: DateTime(2024, 3, 15),
            requiredInputData: const [InputDataType.audioFiles],
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

          final config = _makePromptConfig(
            id: 'audio-prompt',
            name: 'Audio Prompt',
            systemMessage: 'System',
            userMessage: 'Content: {{audioTranscript}}',
            createdAt: DateTime(2024, 3, 15),
            requiredInputData: const [InputDataType.audioFiles],
          );

          final result = await promptBuilder.buildPromptWithData(
            promptConfig: config,
            entity: audio,
          );

          expect(result, equals('Content: [No transcription available]'));
        },
      );
    });

    group('_logPlaceholderFailure on placeholder build error', () {
      // Exercises the catch block around _buildCorrectionExamplesPromptText
      // (the correction_examples injection) and the _logPlaceholderFailure
      // helper itself. The failure must originate OUTSIDE the inner try/catch
      // of _buildCorrectionExamplesPromptText so it propagates to the outer
      // catch in buildPromptWithData. _findLinkedTask (called before the inner
      // try) is the throwing point: it awaits journalRepository.getLinkedEntities.

      AiConfigPrompt correctionExamplesConfig() => _makePromptConfig(
        id: 'transcription-prompt',
        name: 'Transcription',
        systemMessage: 'System',
        userMessage: 'Transcribe: {{correction_examples}}',
        createdAt: DateTime(2024, 3, 15),
        requiredInputData: const [InputDataType.audioFiles],
      );

      JournalAudio audioEntity(String id) => JournalAudio(
        data: AudioData(
          audioFile: 'audio.m4a',
          audioDirectory: '/test',
          duration: const Duration(minutes: 1),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        meta: Metadata(
          id: id,
          createdAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
        ),
      );

      test(
        'replaces {{correction_examples}} with empty string and logs error '
        'via DomainLogger when building examples throws',
        () async {
          final mockLogger = MockDomainLogger();
          final mockJournalRepository = MockJournalRepository();

          // _findLinkedTask -> getLinkedEntities throws, propagating out of
          // _buildCorrectionExamplesPromptText to the outer catch (line ~186).
          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'audio-boom',
            ),
          ).thenThrow(Exception('linked lookup exploded'));

          await setUpTestGetIt(
            additionalSetup: () {
              // Override the real DomainLogger with a verifiable mock.
              getIt
                ..unregister<DomainLogger>()
                ..registerSingleton<DomainLogger>(mockLogger);
            },
          );
          addTearDown(tearDownTestGetIt);

          final builder = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          final result = await builder.buildPromptWithData(
            promptConfig: correctionExamplesConfig(),
            entity: audioEntity('audio-boom'),
          );

          // Placeholder replaced with '' despite the failure (graceful fallback).
          expect(result, equals('Transcribe: '));
          expect(result, isNot(contains('{{correction_examples}}')));

          // The error was routed through _logPlaceholderFailure -> DomainLogger.
          // The second positional arg is the formatted message built in
          // _logPlaceholderFailure; it names the placeholder, the entity id and
          // carries the original error (with no trailing context suffix).
          final captured = verify(
            () => mockLogger.error(
              LogDomain.ai,
              captureAny(),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'placeholder_injection',
            ),
          ).captured;
          expect(captured, hasLength(1));
          final message = captured.single as String;
          expect(
            message,
            equals(
              'Failed to inject {{correction_examples}} for '
              'entity=audio-boom: Exception: linked lookup exploded',
            ),
          );
        },
      );

      test(
        'does not crash and still injects empty string when DomainLogger is '
        'not registered',
        () async {
          // No GetIt setup at all -> _loggingService getter returns null, so
          // _logPlaceholderFailure must no-op on the null-aware call without
          // throwing. Confirms the placeholder is still replaced.
          final mockJournalRepository = MockJournalRepository();
          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: 'audio-no-logger',
            ),
          ).thenThrow(Exception('boom'));

          final builder = PromptBuilderHelper(
            aiInputRepository: mockAiInputRepository,
            journalRepository: mockJournalRepository,
            taskSummaryResolver: MockTaskSummaryResolver(),
          );

          final result = await builder.buildPromptWithData(
            promptConfig: correctionExamplesConfig(),
            entity: audioEntity('audio-no-logger'),
          );

          expect(result, equals('Transcribe: '));
        },
      );
    });
  });

  // ---------------------------------------------------------------------------
  // From prompt_builder_helper_audio_transcript_test.dart
  // ---------------------------------------------------------------------------

  group('PromptBuilderHelper - Audio Transcript Placeholder', () {
    late PromptBuilderHelper promptBuilderAT;
    late MockAiInputRepository mockAiInputRepositoryAT;
    late MockJournalRepository mockJournalRepositoryAT;
    late MockLabelsRepository mockLabelsRepositoryAT;
    late MockEntitiesCacheService mockEntitiesCacheServiceAT;

    final testTaskAT = Task(
      data: TaskData(
        title: 'Test Task',
        checklistIds: const [],
        status: TaskStatus.open(
          id: 'status',
          createdAt: DateTime(2025),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
      ),
      meta: Metadata(
        id: 'task-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
        categoryId: 'category-1',
      ),
    );

    final testAudioWithTranscript = JournalAudio(
      meta: Metadata(
        id: 'audio-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: AudioData(
        audioFile: 'test.m4a',
        audioDirectory: '/tmp',
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        duration: const Duration(seconds: 30),
        transcripts: [
          AudioTranscript(
            transcript: 'This is the original transcript from AI.',
            created: DateTime(2025),
            library: 'test',
            model: 'test-model',
            detectedLanguage: 'en',
          ),
        ],
      ),
    );

    final testAudioWithEditedText = JournalAudio(
      meta: Metadata(
        id: 'audio-2',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: AudioData(
        audioFile: 'test.m4a',
        audioDirectory: '/tmp',
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        duration: const Duration(seconds: 30),
        transcripts: [
          AudioTranscript(
            transcript: 'Original transcript.',
            created: DateTime(2025),
            library: 'test',
            model: 'test-model',
            detectedLanguage: 'en',
          ),
        ],
      ),
      entryText: const EntryText(
        plainText: 'User edited and corrected transcript.',
        markdown: 'User edited and corrected transcript.',
      ),
    );

    final testAudioWithoutTranscript = JournalAudio(
      meta: Metadata(
        id: 'audio-3',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: AudioData(
        audioFile: 'test.m4a',
        audioDirectory: '/tmp',
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        duration: const Duration(seconds: 30),
      ),
    );

    final testImageAT = JournalImage(
      meta: Metadata(
        id: 'image-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: ImageData(
        imageId: 'image-1',
        imageFile: 'test.jpg',
        imageDirectory: '/tmp',
        capturedAt: DateTime(2025),
      ),
    );

    setUp(() async {
      mockAiInputRepositoryAT = MockAiInputRepository();
      mockJournalRepositoryAT = MockJournalRepository();
      mockLabelsRepositoryAT = MockLabelsRepository();
      mockEntitiesCacheServiceAT = MockEntitiesCacheService();

      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EntitiesCacheService>(
            mockEntitiesCacheServiceAT,
          );
        },
      );

      // Default stubs
      when(
        () => mockLabelsRepositoryAT.getAllLabels(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLabelsRepositoryAT.getLabelUsageCounts(),
      ).thenAnswer((_) async => {});
      when(
        () => mockLabelsRepositoryAT.buildLabelTuples(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockAiInputRepositoryAT.buildTaskDetailsJson(
          id: any<String>(named: 'id'),
        ),
      ).thenAnswer((_) async => null);

      promptBuilderAT = PromptBuilderHelper(
        aiInputRepository: mockAiInputRepositoryAT,
        journalRepository: mockJournalRepositoryAT,
        taskSummaryResolver: MockTaskSummaryResolver(),
      );
    });

    tearDown(tearDownTestGetIt);

    group('buildPromptWithData - {{audioTranscript}}', () {
      test('injects original transcript for audio entry', () async {
        final config = _makePromptConfig(
          name: 'Generate Prompt',
          userMessage: 'Audio: {{audioTranscript}}\n\nGenerate a prompt.',
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilderAT.buildPromptWithData(
          promptConfig: config,
          entity: testAudioWithTranscript,
        );

        expect(result, isNotNull);
        expect(result, contains('This is the original transcript from AI.'));
        expect(result, contains('Generate a prompt.'));
        expect(result, isNot(contains('{{audioTranscript}}')));
      });

      test(
        'uses edited text over original transcript when available',
        () async {
          final config = _makePromptConfig(
            name: 'Generate Prompt',
            userMessage: 'Audio: {{audioTranscript}}',
            useReasoning: true,
            requiredInputData: const [InputDataType.audioFiles],
            aiResponseType: AiResponseType.promptGeneration,
          );

          final result = await promptBuilderAT.buildPromptWithData(
            promptConfig: config,
            entity: testAudioWithEditedText,
          );

          expect(result, isNotNull);
          // Should use edited text, not original transcript
          expect(result, contains('User edited and corrected transcript.'));
          expect(result, isNot(contains('Original transcript.')));
        },
      );

      test('returns fallback message when no transcript available', () async {
        final config = _makePromptConfig(
          name: 'Generate Prompt',
          userMessage: 'Audio: {{audioTranscript}}',
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilderAT.buildPromptWithData(
          promptConfig: config,
          entity: testAudioWithoutTranscript,
        );

        expect(result, isNotNull);
        expect(result, contains('[No transcription available]'));
      });

      test('returns error message for non-audio entity', () async {
        final config = _makePromptConfig(
          name: 'Generate Prompt',
          userMessage: 'Audio: {{audioTranscript}}',
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilderAT.buildPromptWithData(
          promptConfig: config,
          entity: testImageAT,
        );

        expect(result, isNotNull);
        expect(
          result,
          contains('[Audio entry expected but received JournalImage]'),
        );
      });

      test('returns error message for task entity', () async {
        final config = _makePromptConfig(
          name: 'Generate Prompt',
          userMessage: 'Audio: {{audioTranscript}}',
          useReasoning: true,
          requiredInputData: const [InputDataType.audioFiles],
          aiResponseType: AiResponseType.promptGeneration,
        );

        final result = await promptBuilderAT.buildPromptWithData(
          promptConfig: config,
          entity: testTaskAT,
        );

        expect(result, isNotNull);
        expect(result, contains('[Audio entry expected but received Task]'));
      });

      test(
        'leaves prompt unchanged if audioTranscript placeholder not present',
        () async {
          final config = _makePromptConfig(
            name: 'Image Analysis',
            userMessage: 'Analyze this image.',
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final result = await promptBuilderAT.buildPromptWithData(
            promptConfig: config,
            entity: testImageAT,
          );

          expect(result, isNotNull);
          expect(result, equals('Analyze this image.'));
          // No audioTranscript placeholder to replace
          expect(result, isNot(contains('{{audioTranscript}}')));
        },
      );
    });
  });

  // ---------------------------------------------------------------------------
  // From prompt_builder_helper_current_task_summary_test.dart
  // ---------------------------------------------------------------------------

  group('PromptBuilderHelper - Current Task Summary Placeholder', () {
    late PromptBuilderHelper promptBuilderCTS;
    late MockAiInputRepository mockAiInputRepositoryCTS;
    late MockJournalRepository mockJournalRepositoryCTS;
    late MockLabelsRepository mockLabelsRepositoryCTS;
    late MockEntitiesCacheService mockEntitiesCacheServiceCTS;

    final testTaskCTS = Task(
      data: TaskData(
        title: 'Test Task',
        checklistIds: const [],
        status: TaskStatus.open(
          id: 'status',
          createdAt: DateTime(2025),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
      ),
      meta: Metadata(
        id: 'task-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
        categoryId: 'category-1',
      ),
    );

    final testAudioCTS = JournalAudio(
      meta: Metadata(
        id: 'audio-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: AudioData(
        audioFile: 'test.m4a',
        audioDirectory: '/tmp',
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        duration: const Duration(seconds: 30),
        transcripts: [
          AudioTranscript(
            transcript: 'Test transcript',
            created: DateTime(2025),
            library: 'test',
            model: 'test-model',
            detectedLanguage: 'en',
          ),
        ],
      ),
    );

    final testImageCTS = JournalImage(
      meta: Metadata(
        id: 'image-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: ImageData(
        imageId: 'image-1',
        imageFile: 'test.jpg',
        imageDirectory: '/tmp',
        capturedAt: DateTime(2025),
      ),
    );

    AiResponseEntry buildTaskSummary({
      required String id,
      required String response,
      required DateTime dateFrom,
    }) {
      return AiResponseEntry(
        meta: Metadata(
          id: id,
          createdAt: dateFrom,
          dateFrom: dateFrom,
          dateTo: dateFrom,
          updatedAt: dateFrom,
        ),
        data: AiResponseData(
          response: response,
          // ignore: deprecated_member_use_from_same_package
          type: AiResponseType.taskSummary,
          model: 'test-model',
          systemMessage: 'System message',
          prompt: 'Test prompt',
          thoughts: '',
          promptId: 'prompt-1',
        ),
      );
    }

    setUp(() async {
      mockAiInputRepositoryCTS = MockAiInputRepository();
      mockJournalRepositoryCTS = MockJournalRepository();
      mockLabelsRepositoryCTS = MockLabelsRepository();
      mockEntitiesCacheServiceCTS = MockEntitiesCacheService();

      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EntitiesCacheService>(
            mockEntitiesCacheServiceCTS,
          );
        },
      );

      // Default stubs
      when(
        () => mockLabelsRepositoryCTS.getAllLabels(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLabelsRepositoryCTS.getLabelUsageCounts(),
      ).thenAnswer((_) async => {});
      when(
        () => mockLabelsRepositoryCTS.buildLabelTuples(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockAiInputRepositoryCTS.buildTaskDetailsJson(
          id: any<String>(named: 'id'),
        ),
      ).thenAnswer((_) async => null);

      promptBuilderCTS = PromptBuilderHelper(
        aiInputRepository: mockAiInputRepositoryCTS,
        journalRepository: mockJournalRepositoryCTS,
        taskSummaryResolver: TaskSummaryResolver(_EmptyAgentRepository()),
      );
    });

    tearDown(tearDownTestGetIt);

    group('buildPromptWithData - {{current_task_summary}}', () {
      test('injects latest task summary for task entity', () async {
        final summary1 = buildTaskSummary(
          id: 'summary-1',
          response: 'Old summary from yesterday',
          dateFrom: DateTime(2025),
        );
        final summary2 = buildTaskSummary(
          id: 'summary-2',
          response: 'Latest summary with learnings and annoyances',
          dateFrom: DateTime(2025, 1, 2),
        );

        when(
          () =>
              mockJournalRepositoryCTS.getLinkedToEntities(linkedTo: 'task-1'),
        ).thenAnswer((_) async => [summary1, summary2]);

        final config = _makePromptConfig(
          name: 'Generate Image',
          userMessage: 'Summary: {{current_task_summary}}\n\nGenerate image.',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testTaskCTS,
        );

        expect(result, isNotNull);
        expect(
          result,
          contains('Latest summary with learnings and annoyances'),
        );
        expect(result, isNot(contains('Old summary from yesterday')));
        expect(result, isNot(contains('{{current_task_summary}}')));
      });

      test('returns fallback when no task summary exists', () async {
        when(
          () =>
              mockJournalRepositoryCTS.getLinkedToEntities(linkedTo: 'task-1'),
        ).thenAnswer((_) async => []);

        final config = _makePromptConfig(
          name: 'Generate Image',
          userMessage: 'Summary: {{current_task_summary}}',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testTaskCTS,
        );

        expect(result, isNotNull);
        expect(result, contains('[No task summary available]'));
      });

      test(
        'finds linked task for audio entity and injects its summary',
        () async {
          final summary = buildTaskSummary(
            id: 'summary-1',
            response: 'Task summary for linked task',
            dateFrom: DateTime(2025),
          );

          // Audio links TO task-1 (via getLinkedEntities)
          when(
            () =>
                mockJournalRepositoryCTS.getLinkedEntities(linkedTo: 'audio-1'),
          ).thenAnswer((_) async => [testTaskCTS]);
          // Task-1 has linked summaries
          when(
            () => mockJournalRepositoryCTS.getLinkedToEntities(
              linkedTo: 'task-1',
            ),
          ).thenAnswer((_) async => [summary]);

          final config = _makePromptConfig(
            name: 'Generate Image',
            userMessage: 'Summary: {{current_task_summary}}',
            aiResponseType: AiResponseType.imageGeneration,
          );

          final result = await promptBuilderCTS.buildPromptWithData(
            promptConfig: config,
            entity: testAudioCTS,
          );

          expect(result, isNotNull);
          expect(result, contains('Task summary for linked task'));
        },
      );

      test(
        'falls back to getLinkedToEntities when getLinkedEntities has no task',
        () async {
          final summary = buildTaskSummary(
            id: 'summary-1',
            response: 'Summary via fallback direction',
            dateFrom: DateTime(2025),
          );

          // Audio does not link TO any task (preferred direction empty)...
          when(
            () =>
                mockJournalRepositoryCTS.getLinkedEntities(linkedTo: 'audio-1'),
          ).thenAnswer((_) async => []);
          // ...but the task links TO the audio (task → entry fallback).
          when(
            () => mockJournalRepositoryCTS.getLinkedToEntities(
              linkedTo: 'audio-1',
            ),
          ).thenAnswer((_) async => [testTaskCTS]);
          when(
            () => mockJournalRepositoryCTS.getLinkedToEntities(
              linkedTo: 'task-1',
            ),
          ).thenAnswer((_) async => [summary]);

          final config = _makePromptConfig(
            name: 'Generate Image',
            userMessage: 'Summary: {{current_task_summary}}',
            aiResponseType: AiResponseType.imageGeneration,
          );

          final result = await promptBuilderCTS.buildPromptWithData(
            promptConfig: config,
            entity: testAudioCTS,
          );

          expect(result, isNotNull);
          expect(result, contains('Summary via fallback direction'));
          verify(
            () => mockJournalRepositoryCTS.getLinkedToEntities(
              linkedTo: 'audio-1',
            ),
          ).called(1);
        },
      );

      test('returns fallback when audio not linked to any task', () async {
        // Audio doesn't link TO any task
        when(
          () => mockJournalRepositoryCTS.getLinkedEntities(linkedTo: 'audio-1'),
        ).thenAnswer((_) async => []);
        // Fallback: no tasks link TO audio either
        when(
          () =>
              mockJournalRepositoryCTS.getLinkedToEntities(linkedTo: 'audio-1'),
        ).thenAnswer((_) async => []);

        final config = _makePromptConfig(
          name: 'Generate Image',
          userMessage: 'Summary: {{current_task_summary}}',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testAudioCTS,
        );

        expect(result, isNotNull);
        expect(result, contains('[No task summary available]'));
      });

      test(
        'finds linked task for image entity and injects its summary',
        () async {
          final summary = buildTaskSummary(
            id: 'summary-1',
            response: 'Task summary via image',
            dateFrom: DateTime(2025),
          );

          // Image links TO task-1 (via getLinkedEntities)
          when(
            () =>
                mockJournalRepositoryCTS.getLinkedEntities(linkedTo: 'image-1'),
          ).thenAnswer((_) async => [testTaskCTS]);
          // Task-1 has linked summaries
          when(
            () => mockJournalRepositoryCTS.getLinkedToEntities(
              linkedTo: 'task-1',
            ),
          ).thenAnswer((_) async => [summary]);

          final config = _makePromptConfig(
            name: 'Generate Image',
            userMessage: 'Summary: {{current_task_summary}}',
            aiResponseType: AiResponseType.imageGeneration,
          );

          final result = await promptBuilderCTS.buildPromptWithData(
            promptConfig: config,
            entity: testImageCTS,
          );

          expect(result, isNotNull);
          expect(result, contains('Task summary via image'));
        },
      );

      test('ignores non-taskSummary AI responses', () async {
        // Create a different type of AI response
        final transcriptionResponse = AiResponseEntry(
          meta: Metadata(
            id: 'ai-response-1',
            createdAt: DateTime(2025, 1, 2),
            dateFrom: DateTime(2025, 1, 2),
            dateTo: DateTime(2025, 1, 2),
            updatedAt: DateTime(2025, 1, 2),
          ),
          data: const AiResponseData(
            response: 'This is a transcription, not a summary',
            type: AiResponseType.audioTranscription,
            model: 'test-model',
            systemMessage: 'System message',
            prompt: 'Transcription prompt',
            thoughts: '',
            promptId: 'prompt-1',
          ),
        );

        when(
          () =>
              mockJournalRepositoryCTS.getLinkedToEntities(linkedTo: 'task-1'),
        ).thenAnswer((_) async => [transcriptionResponse]);

        final config = _makePromptConfig(
          name: 'Generate Image',
          userMessage: 'Summary: {{current_task_summary}}',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testTaskCTS,
        );

        expect(result, isNotNull);
        // Should return fallback since no taskSummary type found
        expect(result, contains('[No task summary available]'));
      });

      test('selects most recent summary when multiple exist', () async {
        final oldSummary = buildTaskSummary(
          id: 'summary-old',
          response: 'Old summary',
          dateFrom: DateTime(2025),
        );
        final middleSummary = buildTaskSummary(
          id: 'summary-middle',
          response: 'Middle summary',
          dateFrom: DateTime(2025, 1, 5),
        );
        final newestSummary = buildTaskSummary(
          id: 'summary-newest',
          response: 'Newest summary',
          dateFrom: DateTime(2025, 1, 10),
        );

        // Return in mixed order to test sorting
        when(
          () =>
              mockJournalRepositoryCTS.getLinkedToEntities(linkedTo: 'task-1'),
        ).thenAnswer(
          (_) async => [middleSummary, oldSummary, newestSummary],
        );

        final config = _makePromptConfig(
          name: 'Generate Image',
          userMessage: 'Summary: {{current_task_summary}}',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testTaskCTS,
        );

        expect(result, isNotNull);
        expect(result, contains('Newest summary'));
        expect(result, isNot(contains('Old summary')));
        expect(result, isNot(contains('Middle summary')));
      });

      test('leaves prompt unchanged if placeholder not present', () async {
        final config = _makePromptConfig(
          name: 'Simple Prompt',
          userMessage: 'Generate something without task summary.',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testTaskCTS,
        );

        expect(result, isNotNull);
        expect(result, equals('Generate something without task summary.'));
        // Should not have called getLinkedToEntities since placeholder absent
        verifyNever(
          () => mockJournalRepositoryCTS.getLinkedToEntities(
            linkedTo: any(named: 'linkedTo'),
          ),
        );
      });

      test('handles error gracefully and returns fallback', () async {
        when(
          () =>
              mockJournalRepositoryCTS.getLinkedToEntities(linkedTo: 'task-1'),
        ).thenThrow(Exception('Database error'));

        final config = _makePromptConfig(
          name: 'Generate Image',
          userMessage: 'Summary: {{current_task_summary}}',
          aiResponseType: AiResponseType.imageGeneration,
        );

        final result = await promptBuilderCTS.buildPromptWithData(
          promptConfig: config,
          entity: testTaskCTS,
        );

        expect(result, isNotNull);
        expect(result, contains('[No task summary available]'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // From prompt_builder_helper_speech_dictionary_test.dart
  // ---------------------------------------------------------------------------

  group('PromptBuilderHelper - Speech Dictionary', () {
    late PromptBuilderHelper promptBuilderSD;
    late MockAiInputRepository mockAiInputRepositorySD;
    late MockJournalRepository mockJournalRepositorySD;
    late MockLabelsRepository mockLabelsRepositorySD;
    late MockEntitiesCacheService mockEntitiesCacheServiceSD;

    final testCategorySD = CategoryDefinition(
      id: 'category-1',
      name: 'Test Category',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
      vectorClock: null,
      private: false,
      active: true,
      color: '#FF0000',
      speechDictionary: ['macOS', 'iPhone', 'Kirkjubaejarklaustur'],
    );

    final testTaskSD = Task(
      data: TaskData(
        title: 'Test Task',
        checklistIds: const [],
        status: TaskStatus.open(
          id: 'status',
          createdAt: DateTime(2025),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
      ),
      meta: Metadata(
        id: 'task-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
        categoryId: 'category-1',
      ),
    );

    final testAudioSD = JournalAudio(
      meta: Metadata(
        id: 'audio-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: AudioData(
        audioFile: 'test.m4a',
        audioDirectory: '/tmp',
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        duration: const Duration(seconds: 30),
      ),
    );

    final testImageSD = JournalImage(
      meta: Metadata(
        id: 'image-1',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
      ),
      data: ImageData(
        imageId: 'image-1',
        imageFile: 'test.jpg',
        imageDirectory: '/tmp',
        capturedAt: DateTime(2025),
      ),
    );

    setUp(() async {
      mockAiInputRepositorySD = MockAiInputRepository();
      mockJournalRepositorySD = MockJournalRepository();
      mockLabelsRepositorySD = MockLabelsRepository();
      mockEntitiesCacheServiceSD = MockEntitiesCacheService();

      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EntitiesCacheService>(
            mockEntitiesCacheServiceSD,
          );
        },
      );

      // Default stubs
      when(
        () => mockLabelsRepositorySD.getAllLabels(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLabelsRepositorySD.getLabelUsageCounts(),
      ).thenAnswer((_) async => {});
      when(
        () => mockLabelsRepositorySD.buildLabelTuples(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockAiInputRepositorySD.buildTaskDetailsJson(
          id: any<String>(named: 'id'),
        ),
      ).thenAnswer((_) async => null);

      promptBuilderSD = PromptBuilderHelper(
        aiInputRepository: mockAiInputRepositorySD,
        journalRepository: mockJournalRepositorySD,
        taskSummaryResolver: MockTaskSummaryResolver(),
      );
    });

    tearDown(tearDownTestGetIt);

    group('buildSystemMessageWithData', () {
      // Note: {{speech_dictionary}} is intentionally NOT supported in system
      // messages to avoid token waste from duplication. Use it only in user
      // messages.

      test(
        'does not process speech_dictionary placeholder in system message',
        () async {
          // Speech dictionary is only supported in user messages for efficiency
          final config = _makePromptConfig(
            name: 'Audio Transcription',
            systemMessage:
                'You are a transcription assistant.\n\n{{speech_dictionary}}',
            userMessage: 'Transcribe the audio.',
            requiredInputData: const [InputDataType.audioFiles],
          );

          final result = await promptBuilderSD.buildSystemMessageWithData(
            promptConfig: config,
            entity: testTaskSD,
          );

          // Placeholder should remain unchanged - not processed in system messages
          expect(
            result,
            equals(
              'You are a transcription assistant.\n\n{{speech_dictionary}}',
            ),
          );
          // Cache service should NOT be called for system message placeholder
          verifyNever(() => mockEntitiesCacheServiceSD.getCategoryById(any()));
        },
      );

      test('returns system message unchanged', () async {
        final config = _makePromptConfig(
          name: 'Simple Prompt',
          systemMessage: 'You are a helpful assistant.',
          userMessage: 'Do something.',
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        final result = await promptBuilderSD.buildSystemMessageWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        expect(result, equals('You are a helpful assistant.'));
      });

      test('ignores the {{task}} placeholder and the entity', () async {
        // buildSystemMessageWithData delegates to getEffectiveMessage and
        // never resolves entity data, so {{task}} stays verbatim.
        final config = _makePromptConfig(
          name: 'Task Prompt',
          systemMessage: 'Context: {{task}}',
          userMessage: 'Summarize.',
          requiredInputData: const [InputDataType.task],
          // ignore: deprecated_member_use_from_same_package
          aiResponseType: AiResponseType.taskSummary,
        );

        final result = await promptBuilderSD.buildSystemMessageWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        expect(result, equals('Context: {{task}}'));
        verifyNever(
          () => mockAiInputRepositorySD.buildTaskDetailsJson(
            id: any<String>(named: 'id'),
          ),
        );
      });
    });

    group('buildPromptWithData - speech_dictionary in user message', () {
      test('injects speech dictionary into user message for task', () async {
        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenReturn(testCategorySD);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          userMessage: '{{speech_dictionary}}\n\nTranscribe this audio.',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        expect(result, isNotNull);
        expect(
          result,
          contains('IMPORTANT - SPEECH DICTIONARY (MUST USE)'),
        );
        expect(
          result,
          contains('["macOS", "iPhone", "Kirkjubaejarklaustur"]'),
        );
        expect(result, contains('Transcribe this audio.'));
      });

      test(
        'injects speech dictionary for audio entry linked to task',
        () async {
          when(
            () => mockJournalRepositorySD.getLinkedEntities(
              linkedTo: 'audio-1',
            ),
          ).thenAnswer((_) async => [testTaskSD]);
          when(
            () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
          ).thenReturn(testCategorySD);

          final config = _makePromptConfig(
            name: 'Audio Transcription',
            userMessage: '{{speech_dictionary}}\n\nTranscribe this audio.',
          );

          final result = await promptBuilderSD.buildPromptWithData(
            promptConfig: config,
            entity: testAudioSD,
          );

          expect(result, isNotNull);
          expect(
            result,
            contains('["macOS", "iPhone", "Kirkjubaejarklaustur"]'),
          );
        },
      );

      test(
        'injects speech dictionary for image entry linked to task',
        () async {
          when(
            () => mockJournalRepositorySD.getLinkedEntities(
              linkedTo: 'image-1',
            ),
          ).thenAnswer((_) async => [testTaskSD]);
          when(
            () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
          ).thenReturn(testCategorySD);

          final config = _makePromptConfig(
            name: 'Image Analysis',
            userMessage: '{{speech_dictionary}}\n\nAnalyze this image.',
            aiResponseType: AiResponseType.imageAnalysis,
          );

          final result = await promptBuilderSD.buildPromptWithData(
            promptConfig: config,
            entity: testImageSD,
          );

          expect(result, isNotNull);
          expect(
            result,
            contains('["macOS", "iPhone", "Kirkjubaejarklaustur"]'),
          );
        },
      );

      test('replaces with empty when getCategoryById throws exception', () async {
        // This tests the catch block in _buildSpeechDictionaryPromptText
        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenThrow(Exception('Cache service error'));

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        // Exception should be caught and placeholder replaced with empty string
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });

      test('replaces with empty when audio not linked to any task', () async {
        when(
          () => mockJournalRepositorySD.getLinkedEntities(
            linkedTo: 'audio-1',
          ),
        ).thenAnswer((_) async => []);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          userMessage: '{{speech_dictionary}}\n\nTranscribe this audio.',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testAudioSD,
        );

        expect(result, equals('\n\nTranscribe this audio.'));
      });

      test('replaces with empty when task has no categoryId', () async {
        // Task without a category ID
        final taskNoCategory = Task(
          data: testTaskSD.data,
          meta: Metadata(
            id: 'task-no-cat',
            createdAt: DateTime(2025),
            dateFrom: DateTime(2025),
            dateTo: DateTime(2025),
            updatedAt: DateTime(2025),
            // No categoryId
          ),
        );

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: taskNoCategory,
        );

        // Task without category should result in empty replacement
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });

      test('replaces with empty when category not found in cache', () async {
        // Category lookup returns null
        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenReturn(null);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        // Category not found should result in empty replacement
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });

      test('handles multiple dictionary terms correctly', () async {
        final categoryWithManyTerms = CategoryDefinition(
          id: 'category-many',
          name: 'Category with Many Terms',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: [
            'TensorFlow',
            'PyTorch',
            'scikit-learn',
            'NumPy',
            'pandas',
          ],
        );

        final taskWithManyTerms = Task(
          data: testTaskSD.data,
          meta: testTaskSD.meta.copyWith(categoryId: 'category-many'),
        );

        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-many'),
        ).thenReturn(categoryWithManyTerms);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: taskWithManyTerms,
        );

        expect(result, contains('TensorFlow'));
        expect(result, contains('PyTorch'));
        expect(result, contains('scikit-learn'));
        expect(result, contains('NumPy'));
        expect(result, contains('pandas'));
        expect(
          result,
          contains(
            '["TensorFlow", "PyTorch", "scikit-learn", "NumPy", "pandas"]',
          ),
        );
      });

      test('handles single dictionary term correctly', () async {
        final categoryWithOneTerm = CategoryDefinition(
          id: 'category-one',
          name: 'Category with One Term',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: ['Anthropic'],
        );

        final taskWithOneTerm = Task(
          data: testTaskSD.data,
          meta: testTaskSD.meta.copyWith(categoryId: 'category-one'),
        );

        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-one'),
        ).thenReturn(categoryWithOneTerm);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: taskWithOneTerm,
        );

        expect(result, contains('["Anthropic"]')); // Single term in JSON array
      });

      test('handles empty dictionary list', () async {
        final categoryWithEmptyList = CategoryDefinition(
          id: 'category-empty',
          name: 'Category with Empty List',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: [],
        );

        final taskWithEmptyList = Task(
          data: testTaskSD.data,
          meta: testTaskSD.meta.copyWith(categoryId: 'category-empty'),
        );

        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-empty'),
        ).thenReturn(categoryWithEmptyList);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}\n\nTranscribe.',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: taskWithEmptyList,
        );

        // Empty dictionary returns empty string replacement
        expect(result, equals('\n\nTranscribe.'));
        expect(result, isNot(contains('SPEECH DICTIONARY')));
      });
    });

    group('EntitiesCacheService not registered', () {
      test(
        'replaces with empty string when cache service not registered',
        () async {
          // Unregister the cache service
          if (getIt.isRegistered<EntitiesCacheService>()) {
            getIt.unregister<EntitiesCacheService>();
          }

          final config = _makePromptConfig(
            name: 'Audio Transcription',
            systemMessage: 'You are a transcription assistant.',
            userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          );

          final result = await promptBuilderSD.buildPromptWithData(
            promptConfig: config,
            entity: testTaskSD,
          );

          // When cache service is not registered, placeholder is replaced with empty
          expect(result, equals('\n\nTranscribe.'));
        },
      );
    });

    group('special character handling', () {
      test('escapes quotes in dictionary terms', () async {
        final categoryWithQuotes = CategoryDefinition(
          id: 'category-1',
          name: 'Test Category',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: ['Term with "quotes"', 'Normal term'],
        );

        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenReturn(categoryWithQuotes);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        // Verify quotes are escaped
        expect(result, contains(r'\"quotes\"'));
        expect(result, contains(r'["Term with \"quotes\"", "Normal term"]'));
      });

      test('escapes backslashes in dictionary terms', () async {
        final categoryWithBackslash = CategoryDefinition(
          id: 'category-1',
          name: 'Test Category',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: [r'Path\To\File', 'Normal'],
        );

        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenReturn(categoryWithBackslash);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        // Verify backslashes are escaped
        expect(result, contains(r'\\'));
      });

      test('escapes newlines in dictionary terms', () async {
        final categoryWithNewline = CategoryDefinition(
          id: 'category-1',
          name: 'Test Category',
          createdAt: DateTime(2025),
          updatedAt: DateTime(2025),
          vectorClock: null,
          private: false,
          active: true,
          color: '#FF0000',
          speechDictionary: ['Term with\nnewline', 'Normal'],
        );

        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenReturn(categoryWithNewline);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        // Verify newlines are escaped
        expect(result, contains(r'\n'));
        // Verify it doesn't contain actual newline in the term part
        expect(result, contains(r'Term with\nnewline'));
      });

      test('includes casing guidance in prompt', () async {
        when(
          () => mockEntitiesCacheServiceSD.getCategoryById('category-1'),
        ).thenReturn(testCategorySD);

        final config = _makePromptConfig(
          name: 'Audio Transcription',
          systemMessage: 'You are a transcription assistant.',
          userMessage: '{{speech_dictionary}}',
        );

        final result = await promptBuilderSD.buildPromptWithData(
          promptConfig: config,
          entity: testTaskSD,
        );

        // Verify casing guidance is included
        expect(result, contains('MUST use the exact spelling and casing'));
        expect(result, contains('macOS'));
      });
    });
  });

  group('placeholder escaping properties', () {
    late MockEntitiesCacheService cacheService;
    late PromptBuilderHelper builder;

    setUp(() async {
      cacheService = MockEntitiesCacheService();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<EntitiesCacheService>(cacheService);
        },
      );
      final aiInput = MockAiInputRepository();
      when(
        () => aiInput.buildTaskDetailsJson(id: any<String>(named: 'id')),
      ).thenAnswer((_) async => null);
      builder = PromptBuilderHelper(
        aiInputRepository: aiInput,
        journalRepository: MockJournalRepository(),
        taskSummaryResolver: MockTaskSummaryResolver(),
      );
    });

    tearDown(tearDownTestGetIt);

    Task taskWithCategory(String categoryId) => Task(
      data: TaskData(
        title: 'Escaping Task',
        checklistIds: const [],
        status: TaskStatus.open(
          id: 'status',
          createdAt: DateTime(2025),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
      ),
      meta: Metadata(
        id: 'task-escaping',
        createdAt: DateTime(2025),
        dateFrom: DateTime(2025),
        dateTo: DateTime(2025),
        updatedAt: DateTime(2025),
        categoryId: categoryId,
      ),
    );

    /// Deterministic string mixing quotes, backslashes, and newlines.
    String nastyString(int seed) {
      const fragments = [
        'plain',
        '"',
        r'\',
        '\n',
        'mixed "x"',
        r'pa\th',
        'multi\nline',
        'tail',
      ];
      final length = (seed % 3) + 1;
      final buffer = StringBuffer();
      var s = seed;
      for (var i = 0; i < length; i++) {
        buffer.write(fragments[s % fragments.length]);
        s = s ~/ fragments.length + 17 * i + 1;
      }
      return buffer.toString();
    }

    glados.Glados<List<int>>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        1,
        6,
        glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'speech dictionary terms survive escaping as parseable JSON',
      (seeds) async {
        final terms = [for (final s in seeds) nastyString(s)];
        when(() => cacheService.getCategoryById('cat-esc')).thenReturn(
          CategoryTestUtils.createTestCategory(
            id: 'cat-esc',
            name: 'Escaping',
            speechDictionary: terms,
          ),
        );

        final result = await builder.buildPromptWithData(
          promptConfig: _makePromptConfig(
            userMessage: '{{speech_dictionary}}\n\nTranscribe.',
          ),
          entity: taskWithCategory('cat-esc'),
        );

        // The injected list must be a single well-formed JSON array that
        // round-trips back to the exact input terms.
        final match = RegExp(
          r'Required spellings: (\[.*\])',
        ).firstMatch(result!);
        expect(match, isNotNull, reason: 'terms: $terms');
        final decoded = jsonDecode(match!.group(1)!) as List<dynamic>;
        expect(decoded, terms);
      },
      tags: 'glados',
    );

    glados.Glados<List<int>>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        1,
        5,
        glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'correction examples keep the line shape with quotes escaped',
      (seeds) async {
        // Correction-example escaping only handles double quotes, so the
        // generated before/after strings stay free of backslashes/newlines.
        String quoted(int seed) {
          const fragments = ['fix', '"', 'a "b"', 'said "hi"', 'tail'];
          return List.generate(
            (seed % 2) + 1,
            (i) => fragments[(seed >> (3 * i)) % fragments.length],
          ).join(' ');
        }

        final examples = [
          for (final (i, s) in seeds.indexed)
            ChecklistCorrectionExample(
              before: quoted(s),
              after: quoted(s >> 4),
              capturedAt: DateTime(2024, 1, 1 + i),
            ),
        ];
        when(() => cacheService.getCategoryById('cat-esc')).thenReturn(
          CategoryTestUtils.createTestCategory(
            id: 'cat-esc',
            name: 'Escaping',
            correctionExamples: examples,
          ),
        );

        final result = await builder.buildPromptWithData(
          promptConfig: _makePromptConfig(
            userMessage: 'Transcribe: {{correction_examples}}',
            requiredInputData: const [InputDataType.audioFiles],
          ),
          entity: taskWithCategory('cat-esc'),
        );

        // Every injected example line must keep the "- "before" → "after""
        // shape, and unescaping the quotes must recover the original pair.
        final lines = result!
            .split('\n')
            .where((l) => l.startsWith('- "'))
            .toList();
        expect(lines, hasLength(examples.length));
        final lineShape = RegExp(r'^- "(.*)" → "(.*)"$');
        final recovered = <(String, String)>[
          for (final line in lines)
            () {
              final m = lineShape.firstMatch(line);
              expect(m, isNotNull, reason: line);
              return (
                m!.group(1)!.replaceAll(r'\"', '"'),
                m.group(2)!.replaceAll(r'\"', '"'),
              );
            }(),
        ];
        expect(
          recovered.toSet(),
          {for (final e in examples) (e.before, e.after)},
        );
      },
      tags: 'glados',
    );
  });
}
