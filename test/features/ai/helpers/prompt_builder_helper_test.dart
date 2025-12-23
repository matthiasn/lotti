// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/prompt_builder_helper.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../labels/label_assignment_processor_test.dart' as label_test
    show MockLabelsRepository;

// Mocks
class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockRef extends Mock implements Ref {}

class MockTaskSummaryRefreshService extends Mock
    implements TaskSummaryRefreshService {}

void main() {
  late PromptBuilderHelper promptBuilder;
  late MockAiInputRepository mockAiInputRepository;
  late label_test.MockLabelsRepository mockLabelsRepository;

  setUpAll(() {
    registerFallbackValue(fallbackJournalEntity);
    mockAiInputRepository = MockAiInputRepository();
    mockLabelsRepository = label_test.MockLabelsRepository();

    // Stub labels repository to return empty lists by default
    when(() => mockLabelsRepository.getAllLabels()).thenAnswer((_) async => []);
    when(() => mockLabelsRepository.getLabelUsageCounts())
        .thenAnswer((_) async => {});
    when(() => mockLabelsRepository.buildLabelTuples(any()))
        .thenAnswer((_) async => []);

    promptBuilder = PromptBuilderHelper(
      aiInputRepository: mockAiInputRepository,
      checklistRepository: MockChecklistRepository(),
      journalRepository: MockJournalRepository(),
      labelsRepository: mockLabelsRepository,
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

  tearDown(() async {
    // Reset mocks to clear call history between tests
    reset(mockAiInputRepository);
    reset(mockLabelsRepository);

    // Re-stub after reset
    when(() => mockLabelsRepository.getAllLabels()).thenAnswer((_) async => []);
    when(() => mockLabelsRepository.getLabelUsageCounts())
        .thenAnswer((_) async => {});
    when(() => mockLabelsRepository.buildLabelTuples(any()))
        .thenAnswer((_) async => []);
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

    if (getIt.isRegistered<JournalDb>()) {
      final db = getIt<JournalDb>();
      await db.close();
      await getIt.reset();
    }
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

    group('current entry injection', () {
      test('injects JSON when linkedEntityId provided', () async {
        when(() => mockAiInputRepository.buildTaskDetailsJson(
            id: any<String>(named: 'id'))).thenAnswer((_) async => null);
        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final audioEntry = JournalAudio(
          meta: Metadata(
            id: 'audio-1',
            createdAt: DateTime(2025, 1, 2, 3, 4, 5),
            dateFrom: DateTime(2025, 1, 2, 3, 4, 5),
            dateTo: DateTime(2025, 1, 2, 3, 4, 5),
            updatedAt: DateTime(2025, 1, 2, 3, 4, 5),
          ),
          data: AudioData(
            audioFile: 'file.m4a',
            audioDirectory: '/tmp',
            dateFrom: DateTime(2025, 1, 2, 3, 4, 5),
            dateTo: DateTime(2025, 1, 2, 3, 4, 5),
            duration: const Duration(seconds: 5),
          ),
          entryText: const EntryText(plainText: 'Edited transcript'),
        );

        final mockJournalRepository = MockJournalRepository();
        final builderWithJournal = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: MockChecklistRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
        );

        when(() => mockJournalRepository.getJournalEntityById('audio-1'))
            .thenAnswer((_) async => audioEntry);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Entry: {{current_entry}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await builderWithJournal.buildPromptWithData(
          promptConfig: config,
          entity: task,
          linkedEntityId: 'audio-1',
        );

        expect(result, isNotNull);
        final jsonString = _extractFirstJsonObject(result!);
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        expect(decoded['id'], equals('audio-1'));
        expect(decoded['entryType'], equals('audio'));
        expect(decoded['text'], equals('Edited transcript'));
      });

      test('falls back to latest transcript when entry text missing', () async {
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(
            id: any<String>(named: 'id'),
          ),
        ).thenAnswer((_) async => null);

        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final audioEntry = JournalAudio(
          meta: Metadata(
            id: 'audio-2',
            createdAt: DateTime(2025, 1, 2, 3, 4, 5),
            dateFrom: DateTime(2025, 1, 2, 3, 4, 5),
            dateTo: DateTime(2025, 1, 2, 3, 4, 5),
            updatedAt: DateTime(2025, 1, 2, 3, 4, 5),
          ),
          data: AudioData(
            audioFile: 'file.m4a',
            audioDirectory: '/tmp',
            dateFrom: DateTime(2025, 1, 2, 3, 4, 5),
            dateTo: DateTime(2025, 1, 2, 3, 4, 5),
            duration: const Duration(seconds: 5),
            transcripts: [
              AudioTranscript(
                created: DateTime(2025, 1, 3),
                library: 'whisper',
                model: 'base',
                detectedLanguage: 'en',
                transcript: 'older transcript',
              ),
              AudioTranscript(
                created: DateTime(2025, 1, 4),
                library: 'whisper',
                model: 'base',
                detectedLanguage: 'en',
                transcript: ' latest transcript ',
              ),
            ],
          ),
        );

        final mockJournalRepository = MockJournalRepository();
        final builderWithJournal = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: MockChecklistRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
        );

        when(() => mockJournalRepository.getJournalEntityById('audio-2'))
            .thenAnswer((_) async => audioEntry);

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Entry: {{current_entry}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await builderWithJournal.buildPromptWithData(
          promptConfig: config,
          entity: task,
          linkedEntityId: 'audio-2',
        );

        expect(result, isNotNull);
        final jsonString = _extractFirstJsonObject(result!);
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        expect(decoded['text'], equals('latest transcript'));
      });

      test('replaces placeholder with empty string when no entry available',
          () async {
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(
            id: any<String>(named: 'id'),
          ),
        ).thenAnswer((_) async => null);
        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Entry: {{current_entry}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        expect(result, equals('Entry: '));
      });
    });

    group('deleted checklist items injection', () {
      late JournalDb journalDb;
      late Task task;
      late ChecklistRepository checklistRepository;

      setUp(() async {
        journalDb = JournalDb(inMemoryDatabase: true);
        getIt.registerSingleton<JournalDb>(journalDb);

        // Set up additional dependencies for ChecklistRepository
        final mockPersistenceLogic = MockPersistenceLogic();
        final mockLoggingService = MockLoggingService();
        final mockTaskSummaryRefreshService = MockTaskSummaryRefreshService();
        final mockRef = MockRef();

        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<LoggingService>(mockLoggingService);

        // Configure MockRef to return the mock TaskSummaryRefreshService
        when(() => mockRef.read(taskSummaryRefreshServiceProvider))
            .thenReturn(mockTaskSummaryRefreshService);

        // Set up default behavior for the triggerTaskSummaryRefreshForChecklist method
        when(
          () => mockTaskSummaryRefreshService
              .triggerTaskSummaryRefreshForChecklist(
            checklistId: any(named: 'checklistId'),
            callingDomain: any(named: 'callingDomain'),
          ),
        ).thenAnswer((_) async => {});

        // Create a real ChecklistRepository with the mocked dependencies
        checklistRepository = ChecklistRepository(mockRef);

        // Override the promptBuilder for this test group to use the real repository
        promptBuilder = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          checklistRepository: checklistRepository,
          journalRepository: MockJournalRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
        );

        task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const ['checklist-1'],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime.now(),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final checklist = Checklist(
          meta: Metadata(
            id: 'checklist-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
          ),
          data: const ChecklistData(
            title: 'Todo',
            linkedChecklistItems: [],
            linkedTasks: ['task-1'],
          ),
        );

        final deletedItem = ChecklistItem(
          meta: Metadata(
            id: 'item-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            deletedAt: DateTime.now(),
          ),
          data: const ChecklistItemData(
            title: 'Refine terminology',
            isChecked: false,
            linkedChecklists: ['checklist-1'],
          ),
        );

        await journalDb.upsertJournalDbEntity(toDbEntity(checklist));
        await journalDb.upsertJournalDbEntity(toDbEntity(deletedItem));
        await journalDb.upsertEntryLink(
          EntryLink.basic(
            id: 'link-1',
            fromId: 'checklist-1',
            toId: 'item-1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            vectorClock: null,
            hidden: false,
          ),
        );
      });

      test('injects deleted checklist items JSON', () async {
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(
            id: any<String>(named: 'id'),
          ),
        ).thenAnswer((_) async => null);
        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Deleted: {{deleted_checklist_items}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        expect(result, isNotNull);
        final jsonString =
            _extractFirstJsonArray(result!.split('Deleted:').last);
        final decoded = jsonDecode(jsonString) as List<dynamic>;
        expect(decoded.length, equals(1));
        final first = decoded.first as Map<String, dynamic>;
        expect(first['title'], equals('Refine terminology'));
        expect(first['deletedAt'], isNotEmpty);
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
        // The expected prompt should be the template's userMessage with placeholders replaced
        final expectedPrompt = template.userMessage
            .replaceAll('{{task}}', mockTaskJson)
            .replaceAll(
                '{{linked_tasks}}', '{"linked_from": [], "linked_to": []}');
        expect(prompt, equals(expectedPrompt));
        // Verify it doesn't contain the custom message
        expect(prompt, isNot(contains('Custom user message')));
      });

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
          aiResponseType: AiResponseType.taskSummary,
        );

        const mockTaskJson = '{"id": "task-123", "title": "Test Task"}';
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => mockTaskJson);
        // Make buildLinkedTasksJson throw an exception
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenThrow(Exception('Database error'));

        // Act
        final prompt = await promptBuilder.buildPromptWithData(
          promptConfig: promptConfig,
          entity: task,
        );

        // Assert - should use fallback empty JSON despite error
        expect(prompt, contains('{"linked_from": [], "linked_to": []}'));
        expect(prompt, contains(mockTaskJson));
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
        verifyNever(
          () => mockAiInputRepository.buildTaskDetailsJson(
            id: any<String>(named: 'id'),
          ),
        );
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
          checklistRepository: MockChecklistRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
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
          checklistRepository: MockChecklistRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
        );

        when(() => mockJournalRepository.getLinkedToEntities(
            linkedTo: 'image-123')).thenAnswer((_) async => [linkedTask]);

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

      test('replaces with empty string when no language code available',
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
      });

      test('replaces with empty string for image without linked task',
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
          checklistRepository: MockChecklistRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
        );

        // No linked task
        when(() => mockJournalRepository.getLinkedToEntities(
            linkedTo: 'image-123')).thenAnswer((_) async => []);

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
      });
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
          checklistRepository: MockChecklistRepository(),
          labelsRepository: label_test.MockLabelsRepository(),
        );

        // Simulate an error when finding linked task
        when(() => mockJournalRepository.getLinkedToEntities(
            linkedTo: 'image-123')).thenThrow(Exception('Database error'));

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

      test('handles error when current_entry fetch fails', () async {
        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2025, 1, 1),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
          ),
          meta: Metadata(
            id: 'task-1',
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
          checklistRepository: MockChecklistRepository(),
          labelsRepository: mockLabelsRepository,
        );

        // Simulate an error when fetching the entry
        when(() => mockJournalRepository.getJournalEntityById('entry-1'))
            .thenThrow(Exception('Database error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Entry: {{current_entry}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await builderWithJournal.buildPromptWithData(
          promptConfig: config,
          entity: task,
          linkedEntityId: 'entry-1',
        );

        // Should replace with empty string on error
        expect(result, equals('Entry: '));
      });

      test('handles error when assigned_labels fetch fails', () async {
        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2025, 1, 1),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
            labelIds: ['label-1'],
          ),
        );

        // Simulate error when building label tuples
        when(() => mockLabelsRepository.buildLabelTuples(['label-1']))
            .thenThrow(Exception('Label fetch error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Labels: {{assigned_labels}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        // Should replace with empty array on error
        expect(result, equals('Labels: []'));
      });

      test('handles error when suppressed_labels fetch fails', () async {
        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const [],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2025, 1, 1),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            aiSuppressedLabelIds: {'label-1'},
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        // Simulate error when building label tuples
        when(() => mockLabelsRepository.buildLabelTuples(['label-1']))
            .thenThrow(Exception('Label fetch error'));

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Suppressed: {{suppressed_labels}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await promptBuilder.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        // Should replace with empty array on error
        expect(result, equals('Suppressed: []'));
      });

      test('handles error when deleted_checklist_items fetch fails', () async {
        getIt.registerSingleton<JournalDb>(
          JournalDb(inMemoryDatabase: true),
        );

        final task = Task(
          data: TaskData(
            title: 'Task',
            checklistIds: const ['checklist-1'],
            status: TaskStatus.open(
              id: 'status',
              createdAt: DateTime(2025, 1, 1),
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
          ),
          meta: Metadata(
            id: 'task-1',
            createdAt: DateTime(2025, 1, 1),
            dateFrom: DateTime(2025, 1, 1),
            dateTo: DateTime(2025, 1, 1),
            updatedAt: DateTime(2025, 1, 1),
          ),
        );

        final mockChecklistRepo = MockChecklistRepository();
        when(() => mockChecklistRepo.getChecklistItemsForTask(
              task: task,
              deletedOnly: true,
            )).thenThrow(Exception('Checklist fetch error'));

        final builderWithChecklist = PromptBuilderHelper(
          aiInputRepository: mockAiInputRepository,
          journalRepository: MockJournalRepository(),
          checklistRepository: mockChecklistRepo,
          labelsRepository: mockLabelsRepository,
        );

        final config = AiConfigPrompt(
          id: 'prompt',
          name: 'Checklist',
          systemMessage: 'System',
          userMessage: 'Deleted: {{deleted_checklist_items}}',
          defaultModelId: 'model-1',
          modelIds: const ['model-1'],
          createdAt: DateTime(2025, 1, 1),
          useReasoning: false,
          requiredInputData: const [],
          aiResponseType: AiResponseType.checklistUpdates,
        );

        final result = await builderWithChecklist.buildPromptWithData(
          promptConfig: config,
          entity: task,
        );

        // Should replace with empty array on error
        expect(result, equals('Deleted: []'));
      });
    });
  });
}

String _extractFirstJsonObject(String text) {
  final start = text.indexOf('{');
  if (start == -1) return '';
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return text.substring(start, i + 1).trim();
      }
    }
  }
  return '';
}

String _extractFirstJsonArray(String text) {
  final start = text.indexOf('[');
  if (start == -1) return '[]';
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (char == '[') {
      depth++;
    } else if (char == ']') {
      depth--;
      if (depth == 0) {
        return text.substring(start, i + 1).trim();
      }
    }
  }
  return '[]';
}
