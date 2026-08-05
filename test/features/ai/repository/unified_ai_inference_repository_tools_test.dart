// ignore_for_file: unawaited_futures, avoid_redundant_argument_values

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'unified_ai_inference_repository_test_helpers.dart';

final harness = UnifiedAiInferenceRepositoryTestHarness();

UnifiedAiInferenceRepository get repository => harness.repository;
set repository(UnifiedAiInferenceRepository value) =>
    harness.repository = value;
ProviderContainer get container => harness.container;
MockAiConfigRepository get mockAiConfigRepo => harness.mockAiConfigRepo;
MockAiInputRepository get mockAiInputRepo => harness.mockAiInputRepo;
MockCloudInferenceRepository get mockCloudInferenceRepo =>
    harness.mockCloudInferenceRepo;
MockJournalRepository get mockJournalRepo => harness.mockJournalRepo;
MockChecklistRepository get mockChecklistRepo => harness.mockChecklistRepo;
MockAutoChecklistService get mockAutoChecklistService =>
    harness.mockAutoChecklistService;
MockJournalDb get mockJournalDb => harness.mockJournalDb;
MockLabelsRepository get mockLabelsRepository => harness.mockLabelsRepository;
TestChecklistCompletionService get testChecklistCompletionService =>
    harness.testChecklistCompletionService;

void main() {
  setUpAll(harness.setUpAll);
  setUp(harness.setUp);
  tearDown(harness.tearDown);
  tearDownAll(harness.tearDownAll);

  group('UnifiedAiInferenceRepository', () {
    test('assign_task_labels no-op when all candidates suppressed', () async {
      // Arrange task with suppressed X and Y
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          aiSuppressedLabelIds: const {'X', 'Y'},
        ),
      );

      final promptConfig = createPrompt(
        id: 'checklist-updates',
        name: 'Checklist Updates',
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(
        () => mockAiInputRepo.getEntity('test-id'),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'),
      ).thenAnswer((_) async => '{"task":"details"}');

      // Shadow flag
      when(
        () => mockJournalDb.getConfigFlag('ai_label_assignment_shadow'),
      ).thenAnswer((_) async => false);

      // Stream a single assign_task_labels tool call for X and Y
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'tool-1',
                  functionName: 'assign_task_labels',
                  arguments: '{"labelIds":["X","Y"]}',
                ),
              ]),
            )
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      // Act
      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Assert: no persistence because both candidates suppressed
      verifyNever(
        () => mockLabelsRepository.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      );
    });

    test('processToolCalls updates checklist items', () async {
      final taskEntity = Task(
        meta: createMetadata(id: 'task-1'),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: const [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: const ['checklist-1'],
        ),
      );

      // Mock the database query for items - return empty so items are skipped
      // (detailed update behavior is tested in LottiChecklistUpdateHandler tests)
      final mockSelectable = MockSelectableSimple<JournalDbEntity>();
      when(mockSelectable.get).thenAnswer((_) async => []);
      when(() => mockJournalDb.entriesForIds(any())).thenReturn(mockSelectable);

      final toolCalls = [
        createMockMessageToolCall(
          id: 'tool-update',
          functionName: 'update_checklist_items',
          arguments:
              '{"items":[{"id":"item-1","isChecked":true},{"id":"item-2","isChecked":true}]}',
        ),
      ];

      // Should not throw - the handler will process but skip items not found
      await repository.processToolCalls(
        toolCalls: toolCalls,
        task: taskEntity,
      );

      // Verify DB was queried for the items
      verify(() => mockJournalDb.entriesForIds(['item-1', 'item-2'])).called(1);
    });
  });
  group('Batch checklist items parsing in unified repository', () {
    test('parses string fallback with grouping and creates items', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: [],
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      // Stream with one tool call using array-of-objects; grouped comma stays within title
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'add_multiple_checklist_items',
                  arguments:
                      '{"items": [{"title": "Start database (index cache, warm)"}, {"title": "Verify"}]}',
                ),
              ]),
            )
            ..add(createStreamChunk('Done'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      when(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: any(named: 'title'),
        ),
      ).thenAnswer(
        (_) async => (
          success: true,
          checklistId: 'new-checklist',
          createdItems: <({String id, String title, bool isChecked})>[],
          error: null,
        ),
      );

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      final captured = verify(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: captureAny(named: 'suggestions'),
          title: 'Todos',
        ),
      ).captured;

      // Ensure at least one call with the first parsed item
      expect(captured.length, greaterThanOrEqualTo(1));
      final first = captured.first as List<ChecklistItemData>;
      expect(
        first.any((i) => i.title == 'Start database (index cache, warm)'),
        isTrue,
      );
    });
  });

  group('Add checklist item tool calls', () {
    test('creates new checklist when none exists', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: [], // No existing checklists
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      // Mock auto checklist creation
      when(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: 'Todos',
        ),
      ).thenAnswer(
        (_) async => (
          success: true,
          checklistId: 'new-checklist-id',
          createdItems: <({String id, String title, bool isChecked})>[],
          error: null,
        ),
      );

      // Create stream with add_multiple_checklist_items tool call
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'add_multiple_checklist_items',
                  arguments: '{"items": [{"title": "Review documentation"}]}',
                ),
              ]),
            )
            ..add(createStreamChunk('Task analysis complete'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify auto checklist creation was called
      verify(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: 'Todos',
        ),
      ).called(1);
    });

    test('adds item to existing checklist', () async {
      const existingChecklistId = 'existing-checklist-id';
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: [existingChecklistId], // Has existing checklist
        ),
      );

      final existingChecklist = Checklist(
        meta: createMetadata(id: existingChecklistId),
        data: ChecklistData(
          title: 'Existing Checklist',
          linkedChecklistItems: ['item-1', 'item-2'],
          linkedTasks: [taskEntity.id],
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      // Mock journal repository for fetching existing checklist
      when(
        () => mockJournalRepo.getJournalEntityById(existingChecklistId),
      ).thenAnswer((_) async => existingChecklist);

      // Mock checklist repository for creating item
      final newChecklistItem = ChecklistItem(
        meta: createMetadata(id: 'new-item-id'),
        data: const ChecklistItemData(
          title: 'New checklist item',
          isChecked: false,
          linkedChecklists: [existingChecklistId],
        ),
      );

      when(
        () => mockChecklistRepo.addItemToChecklist(
          checklistId: existingChecklistId,
          title: 'New checklist item',
          isChecked: false,
          categoryId: taskEntity.meta.categoryId,
          checkedBy: ChangeSource.agent,
        ),
      ).thenAnswer((_) async => newChecklistItem);

      // Create stream with add_multiple_checklist_items tool call
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'add_multiple_checklist_items',
                  arguments: '{"items": [{"title": "New checklist item"}]}',
                ),
              ]),
            )
            ..add(createStreamChunk('Task analysis complete'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify item was created using atomic method with agent provenance
      verify(
        () => mockChecklistRepo.addItemToChecklist(
          checklistId: existingChecklistId,
          title: 'New checklist item',
          isChecked: false,
          categoryId: taskEntity.meta.categoryId,
          checkedBy: ChangeSource.agent,
        ),
      ).called(1);
    });

    test(
      'creates only one checklist when processing a single batch multi-item call',
      () async {
        final taskEntity = Task(
          meta: createMetadata(),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-1',
              createdAt: DateTime(2024, 3, 15, 10, 30),
              utcOffset: 0,
            ),
            title: 'Test Task',
            statusHistory: [],
            dateFrom: DateTime(2024, 3, 15, 10, 30),
            dateTo: DateTime(2024, 3, 15, 10, 30),
            checklistIds: [], // No existing checklists
          ),
        );

        final promptConfig = createPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          requiredInputData: [InputDataType.task],
        );

        final model = createModel(
          id: 'model-1',
          inferenceProviderId: 'provider-1',
          providerModelId: 'gpt-4',
        ).copyWith(supportsFunctionCalling: true);

        final provider = createProvider(
          id: 'provider-1',
          inferenceProviderType: InferenceProviderType.openRouter,
        );

        when(
          () => mockAiInputRepo.getEntity(taskEntity.id),
        ).thenAnswer((_) async => taskEntity);
        when(
          () => mockAiConfigRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model);
        when(
          () => mockAiConfigRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider);
        when(
          () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
        ).thenAnswer((_) async => '{"task": "details"}');

        // Mock auto checklist creation
        const newChecklistId = 'new-checklist-id';
        when(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: taskEntity.id,
            suggestions: any(named: 'suggestions'),
            title: 'Todos',
          ),
        ).thenAnswer(
          (_) async => (
            success: true,
            checklistId: newChecklistId,
            createdItems: <({String id, String title, bool isChecked})>[],
            error: null,
          ),
        );

        // Mock the task refresh after checklist creation
        final updatedTaskEntity = Task(
          meta: taskEntity.meta,
          data: taskEntity.data.copyWith(checklistIds: [newChecklistId]),
        );
        when(
          () => mockJournalDb.journalEntityById(taskEntity.id),
        ).thenAnswer((_) async => updatedTaskEntity);

        // Mock adding items to the newly created checklist
        when(
          () => mockChecklistRepo.addItemToChecklist(
            checklistId: newChecklistId,
            title: any(named: 'title'),
            isChecked: false,
            categoryId: any(named: 'categoryId'),
            checkedBy: ChangeSource.agent,
          ),
        ).thenAnswer(
          (_) async => ChecklistItem(
            meta: createMetadata(id: 'item-new'),
            data: const ChecklistItemData(
              title: 'Test Item',
              isChecked: false,
              linkedChecklists: [newChecklistId],
              checkedBy: ChangeSource.agent,
            ),
          ),
        );

        // Create stream with a single add_multiple_checklist_items tool call containing multiple items
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>()
              ..add(
                createStreamChunkWithToolCalls([
                  createMockToolCall(
                    index: 0,
                    id: 'call-1',
                    functionName: 'add_multiple_checklist_items',
                    arguments:
                        '{"items": [{"title": "First item"}, {"title": "Second item"}, {"title": "Third item"}]}',
                  ),
                  createMockToolCall(
                    index: 1,
                    id: 'call-2',
                    functionName: 'add_multiple_checklist_items',
                    arguments: '{"items": [{"title": "noop"}]}',
                  ),
                  createMockToolCall(
                    index: 2,
                    id: 'call-3',
                    functionName: 'add_multiple_checklist_items',
                    arguments: '{"items": [{"title": "noop2"}]}',
                  ),
                ]),
              )
              ..add(createStreamChunk('Task analysis complete'))
              ..close();

        stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

        await repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        );

        // Verify that checklist creation was called only once
        verify(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: taskEntity.id,
            suggestions: any(named: 'suggestions'),
            title: 'Todos',
          ),
        ).called(1);

        // Verify that the task was refreshed after checklist creation
        verify(() => mockJournalDb.journalEntityById(taskEntity.id)).called(1);

        // Verify that subsequent items were added to the existing checklist
        verify(
          () => mockChecklistRepo.addItemToChecklist(
            checklistId: newChecklistId,
            title: 'Second item',
            isChecked: false,
            categoryId: taskEntity.meta.categoryId,
            checkedBy: ChangeSource.agent,
          ),
        ).called(1);

        verify(
          () => mockChecklistRepo.addItemToChecklist(
            checklistId: newChecklistId,
            title: 'Third item',
            isChecked: false,
            categoryId: taskEntity.meta.categoryId,
            checkedBy: ChangeSource.agent,
          ),
        ).called(1);
      },
    );
  });

  group('Auto-check high confidence suggestions', () {
    final autoCheckTime = DateTime(2026, 2, 28, 23);

    test('automatically checks items with high confidence', () async {
      // Recreate with deterministic clock for checkedAt assertion
      final ref = container.read(testRefProvider);
      repository = UnifiedAiInferenceRepository(ref, clock: () => autoCheckTime)
        ..autoChecklistServiceForTesting = mockAutoChecklistService;
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2025),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          checklistIds: ['checklist-1'],
        ),
      );

      final checklistItem = ChecklistItem(
        meta: createMetadata(id: 'item-1'),
        data: const ChecklistItemData(
          title: 'Test item',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
          // Agent-owned so auto-check is allowed by sovereignty guard
          checkedBy: ChangeSource.agent,
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      // Mock getting the checklist item
      when(
        () => mockJournalRepo.getJournalEntityById('item-1'),
      ).thenAnswer((_) async => checklistItem);

      // Mock updating the checklist item
      when(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: 'item-1',
          data: any(named: 'data'),
          taskId: taskEntity.id,
        ),
      ).thenAnswer((_) async => true);

      // Create stream with high confidence suggestion
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-1","reason":"Task completed","confidence":"high"}',
                ),
              ]),
            )
            ..add(createStreamChunk('Task analysis complete'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify the item was updated to be checked with agent provenance
      verify(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: 'item-1',
          data: any(
            named: 'data',
            that: isA<ChecklistItemData>()
                .having((d) => d.isChecked, 'isChecked', true)
                .having((d) => d.checkedBy, 'checkedBy', ChangeSource.agent)
                .having((d) => d.checkedAt, 'checkedAt', autoCheckTime),
          ),
          taskId: taskEntity.id,
        ),
      ).called(1);
    });

    test('does not auto-check items with medium or low confidence', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: ['checklist-1'],
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      // Create stream with medium confidence suggestion
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-2","reason":"Might be done","confidence":"medium"}',
                ),
              ]),
            )
            ..add(createStreamChunk('Task analysis complete'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify no update was made
      verifyNever(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('does not update already checked items', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
          checklistIds: ['checklist-1'],
        ),
      );

      final alreadyCheckedItem = ChecklistItem(
        meta: createMetadata(id: 'item-3'),
        data: const ChecklistItemData(
          title: 'Already checked item',
          isChecked: true, // Already checked
          linkedChecklists: ['checklist-1'],
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      // Mock getting the already checked item
      when(
        () => mockJournalRepo.getJournalEntityById('item-3'),
      ).thenAnswer((_) async => alreadyCheckedItem);

      // Create stream with high confidence suggestion for already checked item
      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-3","reason":"Task completed","confidence":"high"}',
                ),
              ]),
            )
            ..add(createStreamChunk('Task analysis complete'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify no update was made since item was already checked
      verifyNever(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('does not auto-check user-owned items (sovereignty guard)', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2025),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          checklistIds: ['checklist-1'],
        ),
      );

      // User-owned unchecked item — sovereignty guard should block auto-check
      final userOwnedItem = ChecklistItem(
        meta: createMetadata(id: 'item-user'),
        data: const ChecklistItemData(
          title: 'User unchecked item',
          isChecked: false,
          linkedChecklists: ['checklist-1'],
          checkedBy: ChangeSource.user,
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      ).copyWith(supportsFunctionCalling: true);

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openRouter,
      );

      when(
        () => mockAiInputRepo.getEntity(taskEntity.id),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => provider);
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: taskEntity.id),
      ).thenAnswer((_) async => '{"task": "details"}');

      when(
        () => mockJournalRepo.getJournalEntityById('item-user'),
      ).thenAnswer((_) async => userOwnedItem);

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>()
            ..add(
              createStreamChunkWithToolCalls([
                createMockToolCall(
                  index: 0,
                  id: 'call-1',
                  functionName: 'suggest_checklist_completion',
                  arguments:
                      '{"checklistItemId":"item-user","reason":"Completed","confidence":"high"}',
                ),
              ]),
            )
            ..add(createStreamChunk('Task analysis complete'))
            ..close();

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify NO update was made — sovereignty guard blocks user-owned items
      verifyNever(
        () => mockChecklistRepo.updateChecklistItem(
          checklistItemId: any(named: 'checklistItemId'),
          data: any(named: 'data'),
          taskId: any(named: 'taskId'),
        ),
      );
    });
  });

  group('Additional coverage tests', () {
    late Task taskEntity;
    late AiConfigInferenceProvider aiProvider;
    late AiConfigModel model;

    setUp(() {
      taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime(2024, 3, 15, 10, 30),
          dateTo: DateTime(2024, 3, 15, 10, 30),
        ),
      );

      aiProvider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
        baseUrl: 'https://api.test.com',
        apiKey: 'test-key',
      );

      model = createModel(
        id: 'model-1',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider-1',
      );
    });
    test(
      'uses the auto-checklist service injected through the test seam',
      () async {
        final injectedService = MockAutoChecklistService();
        when(
          () => injectedService.autoCreateChecklist(
            taskId: taskEntity.id,
            suggestions: any(named: 'suggestions'),
            title: 'Todos',
          ),
        ).thenAnswer(
          (_) async => (
            success: false,
            checklistId: null,
            createdItems: null,
            error: 'expected test stop',
          ),
        );
        repository.autoChecklistServiceForTesting = injectedService;

        await repository.processToolCalls(
          toolCalls: [
            createMockMessageToolCall(
              id: 'injected-service-call',
              functionName: 'add_multiple_checklist_items',
              arguments: '{"items":[{"title":"Injected item"}]}',
            ),
          ],
          task: taskEntity,
        );

        verify(
          () => injectedService.autoCreateChecklist(
            taskId: taskEntity.id,
            suggestions: any(named: 'suggestions'),
            title: 'Todos',
          ),
        ).called(1);
        verifyNever(
          () => mockAutoChecklistService.autoCreateChecklist(
            taskId: any(named: 'taskId'),
            suggestions: any(named: 'suggestions'),
            title: any(named: 'title'),
          ),
        );
      },
    );

    test('handles model not found error', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'non-existent-model',
        modelIds: ['non-existent-model'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('non-existent-model'),
      ).thenAnswer((_) async => null);

      await expectLater(
        repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Model not found: non-existent-model'),
          ),
        ),
      );
    });

    test('handles tool calls with empty IDs and fallback to index', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'Update checklist',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => aiProvider);
      when(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: 'Todos',
        ),
      ).thenAnswer(
        (_) async => (
          success: false,
          checklistId: null,
          createdItems: null,
          error: 'expected test stop',
        ),
      );

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      final inferenceFuture = repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add chunks with empty tool call IDs and continuation by index
      streamController
        ..add(
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: '', // Empty ID - should generate tool_0
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: 'add_multiple_checklist_items',
                        arguments: '{"items":[{"title":',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        )
        // Continue by index without ID
        ..add(
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0, // Same index, no ID
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
                      function: ChatCompletionStreamMessageFunctionCall(
                        arguments: '"Test item"}]}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created:
                DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
          ),
        );

      await streamController.close();
      await inferenceFuture;

      final capturedSuggestions =
          verify(
                () => mockAutoChecklistService.autoCreateChecklist(
                  taskId: taskEntity.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'Todos',
                ),
              ).captured.single
              as List<ChecklistItemData>;
      expect(capturedSuggestions.map((item) => item.title), ['Test item']);
    });

    test('handles tool call with no ID but with function name', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'Update checklist',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfigRepo.getConfigById('provider-1'),
      ).thenAnswer((_) async => aiProvider);
      when(
        () => mockAutoChecklistService.autoCreateChecklist(
          taskId: taskEntity.id,
          suggestions: any(named: 'suggestions'),
          title: 'Todos',
        ),
      ).thenAnswer(
        (_) async => (
          success: false,
          checklistId: null,
          createdItems: null,
          error: 'expected test stop',
        ),
      );

      stubGenerate(mockCloudInferenceRepo, stream: streamController.stream);

      // Clear any captured suggestions from previous tests
      testChecklistCompletionService.capturedSuggestions.clear();
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      final inferenceFuture = repository.runInference(
        entityId: taskEntity.id,
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add chunk with no ID but with function name - should create new tool call
      streamController.add(
        CreateChatCompletionStreamResponse(
          id: 'response-1',
          choices: [
            const ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(
                toolCalls: [
                  ChatCompletionStreamMessageToolCallChunk(
                    index: 0,
                    // No ID field
                    type: ChatCompletionStreamMessageToolCallChunkType.function,
                    function: ChatCompletionStreamMessageFunctionCall(
                      name:
                          'add_multiple_checklist_items', // Has name - indicates new tool call
                      arguments:
                          '{"items":[{"title":"Item with name but no ID"}]}',
                    ),
                  ),
                ],
              ),
            ),
          ],
          object: 'chat.completion.chunk',
          created: DateTime(2024, 3, 15, 10, 30).millisecondsSinceEpoch ~/ 1000,
        ),
      );

      await streamController.close();
      await inferenceFuture;

      final capturedSuggestions =
          verify(
                () => mockAutoChecklistService.autoCreateChecklist(
                  taskId: taskEntity.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'Todos',
                ),
              ).captured.single
              as List<ChecklistItemData>;
      expect(capturedSuggestions.map((item) => item.title), [
        'Item with name but no ID',
      ]);
    });

    test('handles provider not found error properly', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'Test message',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime(2024, 3, 15, 10, 30),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.imageAnalysis,
      );

      final modelWithBadProvider = AiConfigModel(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'test-model',
        inferenceProviderId: 'non-existent-provider',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      when(
        () => mockAiInputRepo.getEntity(any()),
      ).thenAnswer((_) async => taskEntity);
      when(
        () => mockAiConfigRepo.getConfigById('model-1'),
      ).thenAnswer((_) async => modelWithBadProvider);
      when(
        () => mockAiConfigRepo.getConfigById('non-existent-provider'),
      ).thenAnswer((_) async => null); // Provider not found
      when(() => mockAiInputRepo.generate(any())).thenAnswer(
        (_) async => AiInputTaskObject(
          title: 'Test Task',
          status: 'In Progress',
          priority: 'P2',
          estimatedDuration: '1 hour',
          timeSpent: '30 minutes',
          creationDate: DateTime(2024, 3, 15),
          actionItems: [],
          logEntries: [],
        ),
      );
      when(
        () => mockAiInputRepo.buildTaskDetailsJson(id: any(named: 'id')),
      ).thenAnswer((_) async => '{"title": "Test Task"}');

      await expectLater(
        repository.runInference(
          entityId: taskEntity.id,
          promptConfig: promptConfig,
          onProgress: (_) {},
          onStatusChange: (_) {},
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Provider not found: non-existent-provider'),
          ),
        ),
      );
    });
  });
}
