import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

// Mocks
class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSelectable<T> extends Mock implements Selectable<T> {}

const _uuid = Uuid();

// Test data factory
class TestDataFactory {
  static Task createTask({
    String? id,
    String? title,
    List<String>? checklistIds,
  }) {
    final taskId = id ?? _uuid.v4();
    return Task(
      meta: Metadata(
        id: taskId,
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
        dateFrom: DateTime(2024, 1, 15),
        dateTo: DateTime(2024, 1, 15),
        categoryId: 'test-category',
      ),
      data: TaskData(
        title: title ?? 'Test Task',
        checklistIds: checklistIds ?? [],
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime(2024, 1, 15),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime(2024, 1, 15),
        dateTo: DateTime(2024, 1, 15),
      ),
    );
  }

  static ChecklistItem createChecklistItem({
    String? id,
    String? title,
    bool isChecked = false,
    List<String>? linkedChecklists,
  }) {
    final itemId = id ?? _uuid.v4();
    return ChecklistItem(
      meta: Metadata(
        id: itemId,
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
        dateFrom: DateTime(2024, 1, 15),
        dateTo: DateTime(2024, 1, 15),
        categoryId: 'test-category',
      ),
      data: ChecklistItemData(
        title: title ?? 'Test Item',
        isChecked: isChecked,
        linkedChecklists: linkedChecklists ?? ['checklist-1'],
      ),
    );
  }

  static ChatCompletionMessageToolCall createToolCall({
    String? id,
    String? functionName,
    String? arguments,
  }) {
    return ChatCompletionMessageToolCall(
      id: id ?? 'tool-1',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: functionName ?? 'update_checklist_items',
        arguments:
            arguments ?? '{"items": [{"id": "item-1", "isChecked": true}]}',
      ),
    );
  }
}

void main() {
  late MockChecklistRepository mockChecklistRepository;
  late MockJournalDb mockJournalDb;
  late LottiChecklistUpdateHandler handler;
  late Task testTask;

  setUpAll(() {
    registerFallbackValue(
      const ChecklistItemData(
        title: 'fallback',
        isChecked: false,
        linkedChecklists: [],
      ),
    );
  });

  setUp(() {
    mockChecklistRepository = MockChecklistRepository();
    mockJournalDb = MockJournalDb();

    // Set up getIt
    getIt.registerSingleton<JournalDb>(mockJournalDb);

    testTask = TestDataFactory.createTask(
      checklistIds: ['checklist-1'],
    );

    handler = LottiChecklistUpdateHandler(
      task: testTask,
      checklistRepository: mockChecklistRepository,
    );
  });

  tearDown(getIt.reset);

  group('LottiChecklistUpdateHandler', () {
    test('should have correct function name', () {
      expect(handler.functionName, 'update_checklist_items');
    });

    group('processFunctionCall', () {
      test('should process valid update with isChecked: true', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.length, 1);
        expect(items[0]['id'], 'item-1');
        expect(items[0]['isChecked'], true);
      });

      test('should process valid update with isChecked: false (unchecking)',
          () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "isChecked": false}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items[0]['isChecked'], false);
      });

      test('should process valid update with title only', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "title": "Updated title"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items[0]['title'], 'Updated title');
        expect(items[0].containsKey('isChecked'), false);
      });

      test('should process valid update with both isChecked and title', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments:
              '{"items": [{"id": "item-1", "isChecked": true, "title": "macOS settings"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items[0]['isChecked'], true);
        expect(items[0]['title'], 'macOS settings');
      });

      test('should normalize whitespace in title', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments:
              '{"items": [{"id": "item-1", "title": "  foo   bar  baz  "}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items[0]['title'], 'foo bar baz');
      });

      test('should trim id whitespace', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "  item-1  ", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items[0]['id'], 'item-1');
      });

      test('should reject empty items array', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": []}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Empty items array'));
      });

      test('should reject item without id', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('missing required "id" field'));
      });

      test('should reject item with empty id', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('missing required "id" field'));
      });

      test('should reject item with whitespace-only id', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "   ", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('missing required "id" field'));
      });

      test('should reject item without any update field', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('has no update fields'));
      });

      test('should reject title exceeding 400 chars after normalization', () {
        final longTitle = 'a' * 401;
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "title": "$longTitle"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('exceeding 400 characters'));
      });

      test('should accept title exactly 400 chars', () {
        final exactTitle = 'a' * 400;
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "title": "$exactTitle"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
      });

      test('should reject empty title after normalization', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "title": "   "}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('empty title after normalization'));
      });

      test('should reject invalid isChecked type', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "isChecked": "yes"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('invalid isChecked value'));
      });

      test('should reject invalid title type', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"id": "item-1", "title": 123}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('invalid title value'));
      });

      test('should reject non-object items', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": ["item-1", "item-2"]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('is not an object'));
      });

      test('should reject non-array items', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "item-1"}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Invalid or missing "items"'));
      });

      test('should reject missing items field', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"wrong": "value"}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Invalid or missing "items"'));
      });

      test('should reject batch exceeding max size (20)', () {
        final items = List.generate(
          21,
          (i) => '{"id": "item-$i", "isChecked": true}',
        ).join(', ');
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [$items]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Maximum batch size is 20'));
      });

      test('should accept exactly 20 items', () {
        final items = List.generate(
          20,
          (i) => '{"id": "item-$i", "isChecked": true}',
        ).join(', ');
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [$items]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final parsedItems =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(parsedItems.length, 20);
      });

      test('should reject invalid JSON', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: 'invalid json',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Invalid JSON'));
      });

      test('should reject function name mismatch', () {
        final toolCall = TestDataFactory.createToolCall(
          functionName: 'wrong_function',
          arguments: '{"items": [{"id": "item-1", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Function name mismatch'));
      });

      test('should process multiple items', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '''
            {"items": [
              {"id": "item-1", "isChecked": true},
              {"id": "item-2", "title": "Updated"},
              {"id": "item-3", "isChecked": false, "title": "Both updated"}
            ]}
          ''',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.length, 3);
      });
    });

    group('executeUpdates', () {
      test('should update item isChecked status', () async {
        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Buy groceries',
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => testTask);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true}
            ],
            'taskId': testTask.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 1);
        expect(handler.updatedItems.length, 1);
        expect(handler.updatedItems[0].id, 'item-1');
        expect(handler.updatedItems[0].isChecked, true);
        expect(handler.updatedItems[0].changes, contains('isChecked'));

        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).called(1);
      });

      test('should update item title', () async {
        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'mac OS settings',
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => testTask);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'title': 'macOS settings'}
            ],
            'taskId': testTask.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 1);
        expect(handler.updatedItems[0].title, 'macOS settings');
        expect(handler.updatedItems[0].changes, contains('title'));
      });

      test('should skip non-existent item', () async {
        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['missing-item']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => []);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'missing-item', 'isChecked': true}
            ],
            'taskId': testTask.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.length, 1);
        expect(handler.skippedItems[0].id, 'missing-item');
        expect(handler.skippedItems[0].reason, 'Item not found');

        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });

      test('should skip item not belonging to task', () async {
        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
          linkedChecklists: ['other-checklist'], // Not checklist-1
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true}
            ],
            'taskId': testTask.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems[0].reason,
            'Item does not belong to this task');
      });

      test('should skip item with no actual changes', () async {
        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Already correct',
          isChecked: true, // Already checked
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true} // Same as current
            ],
            'taskId': testTask.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems[0].reason, 'No changes detected');
      });

      test('should handle mixed valid and invalid items', () async {
        final validItem = TestDataFactory.createChecklistItem(
          id: 'valid-item',
          title: 'Valid',
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['valid-item', 'missing-item']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(validItem)],
        );
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => testTask);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'valid-item',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'valid-item', 'isChecked': true},
              {'id': 'missing-item', 'isChecked': true},
            ],
            'taskId': testTask.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 1);
        expect(handler.updatedItems.length, 1);
        expect(handler.skippedItems.length, 1);
      });

      test('should return 0 for unsuccessful result', () async {
        const result = FunctionCallResult(
          success: false,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {},
          error: 'Some error',
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
      });

      test('should skip all items if task has no checklists', () async {
        final taskWithoutChecklists = TestDataFactory.createTask(
          checklistIds: [],
        );

        handler = LottiChecklistUpdateHandler(
          task: taskWithoutChecklists,
          checklistRepository: mockChecklistRepository,
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true}
            ],
            'taskId': taskWithoutChecklists.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems[0].reason, 'Task has no checklists');
      });

      test('should invoke onTaskUpdated callback on success', () async {
        var callbackInvoked = false;
        Task? updatedTask;

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          onTaskUpdated: (task) {
            callbackInvoked = true;
            updatedTask = task;
          },
        );

        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
        );

        final refreshedTask = TestDataFactory.createTask(
          id: testTask.id,
          checklistIds: ['checklist-1'],
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => refreshedTask);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true}
            ],
            'taskId': testTask.id,
          },
        );

        await handler.executeUpdates(result);

        expect(callbackInvoked, true);
        expect(updatedTask, isA<Task>());
      });
    });

    group('normalizeWhitespace', () {
      test('should trim leading and trailing whitespace', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace('  hello  '),
          'hello',
        );
      });

      test('should collapse multiple internal spaces', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace('hello   world'),
          'hello world',
        );
      });

      test('should handle tabs and newlines', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace('hello\t\nworld'),
          'hello world',
        );
      });

      test('should handle mixed whitespace', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace(
              '  foo   bar  \t baz  '),
          'foo bar baz',
        );
      });
    });

    group('isDuplicate', () {
      test('should always return false', () {
        const result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true}
            ]
          },
        );

        expect(handler.isDuplicate(result), false);
      });
    });

    group('getDescription', () {
      test('should return item count for successful result', () {
        const result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true},
              {'id': 'item-2', 'title': 'Updated'}
            ]
          },
        );

        expect(handler.getDescription(result), '2 item(s) to update');
      });

      test('should return null for unsuccessful result', () {
        const result = FunctionCallResult(
          success: false,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {},
          error: 'Error',
        );

        expect(handler.getDescription(result), null);
      });

      test('should return null for empty items', () {
        const result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {'items': <Map<String, dynamic>>[]},
        );

        expect(handler.getDescription(result), null);
      });
    });

    group('createToolResponse', () {
      test('should create JSON response for success', () async {
        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Original',
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => testTask);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true, 'title': 'Updated'}
            ],
            'taskId': testTask.id,
          },
        );

        await handler.executeUpdates(result);

        final response = handler.createToolResponse(result);
        final decoded = jsonDecode(response) as Map<String, dynamic>;

        expect(decoded['updatedItems'], isA<List>());
        expect(decoded['skippedItems'], isA<List>());

        final updated = (decoded['updatedItems'] as List).first;
        expect(updated['id'], 'item-1');
        expect(updated['isChecked'], true);
        expect(updated['title'], 'Updated');
        expect(updated['changes'], contains('isChecked'));
        expect(updated['changes'], contains('title'));
      });

      test('should create error response for failure', () {
        const result = FunctionCallResult(
          success: false,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {},
          error: 'Invalid format',
        );

        final response = handler.createToolResponse(result);

        expect(response, 'Error updating checklist items: Invalid format');
      });
    });

    group('getRetryPrompt', () {
      test('should include error summary and format instructions', () {
        final failedItems = [
          const FunctionCallResult(
            success: false,
            functionName: 'update_checklist_items',
            arguments: '',
            data: {},
            error: 'Missing id field',
          ),
        ];

        final prompt = handler.getRetryPrompt(
          failedItems: failedItems,
          successfulDescriptions: ['item-1'],
        );

        expect(prompt, contains('Missing id field'));
        expect(prompt, contains('"id"'));
        expect(prompt, contains('"isChecked"'));
        expect(prompt, contains('"title"'));
      });
    });

    group('reset', () {
      test('should clear updated and skipped items', () async {
        final item = TestDataFactory.createChecklistItem(
          id: 'item-1',
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockJournalDb.entriesForIds(['item-1']))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer(
          (_) async => [_createDbEntity(item)],
        );
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => testTask);
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true}
            ],
            'taskId': testTask.id,
          },
        );

        await handler.executeUpdates(result);
        expect(handler.updatedItems, isNotEmpty);

        handler.reset();

        expect(handler.updatedItems, isEmpty);
        expect(handler.skippedItems, isEmpty);
      });
    });
  });
}

/// Helper to create a JournalDbEntity from a ChecklistItem for mocking.
JournalDbEntity _createDbEntity(ChecklistItem item) {
  return JournalDbEntity(
    id: item.id,
    createdAt: item.meta.createdAt,
    updatedAt: item.meta.updatedAt,
    dateFrom: item.meta.dateFrom,
    dateTo: item.meta.dateTo,
    type: 'ChecklistItem',
    serialized: jsonEncode({
      'runtimeType': 'checklistItem',
      'meta': {
        'id': item.meta.id,
        'createdAt': item.meta.createdAt.toIso8601String(),
        'updatedAt': item.meta.updatedAt.toIso8601String(),
        'dateFrom': item.meta.dateFrom.toIso8601String(),
        'dateTo': item.meta.dateTo.toIso8601String(),
        'categoryId': item.meta.categoryId,
      },
      'data': {
        'title': item.data.title,
        'isChecked': item.data.isChecked,
        'linkedChecklists': item.data.linkedChecklists,
      },
    }),
    schemaVersion: 1,
    deleted: false,
    private: false,
    starred: false,
    task: false,
    flag: 0,
    category: item.meta.categoryId ?? '',
  );
}
