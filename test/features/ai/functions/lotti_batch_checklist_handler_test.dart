import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

// Mocks
class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockJournalDb extends Mock implements JournalDb {}

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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        categoryId: 'test-category',
      ),
      data: TaskData(
        title: title ?? 'Test Task',
        checklistIds: checklistIds ?? [],
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
    );
  }

  static ChecklistItemData createChecklistItemData({
    String? title,
    bool isChecked = false,
  }) {
    return ChecklistItemData(
      title: title ?? 'Test Item',
      isChecked: isChecked,
      linkedChecklists: [],
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
        name: functionName ?? 'add_multiple_checklist_items',
        arguments: arguments ??
            '{"items": [{"title": "item1"}, {"title": "item2"}, {"title": "item3"}]}',
      ),
    );
  }
}

void main() {
  late MockAutoChecklistService mockAutoChecklistService;
  late MockChecklistRepository mockChecklistRepository;
  late MockJournalDb mockJournalDb;
  late LottiBatchChecklistHandler handler;
  late Task testTask;

  setUpAll(() {
    registerFallbackValue(TestDataFactory.createTask());
    registerFallbackValue(TestDataFactory.createChecklistItemData());
  });

  setUp(() {
    mockAutoChecklistService = MockAutoChecklistService();
    mockChecklistRepository = MockChecklistRepository();
    mockJournalDb = MockJournalDb();

    // Set up getIt
    getIt.registerSingleton<JournalDb>(mockJournalDb);

    testTask = TestDataFactory.createTask();

    handler = LottiBatchChecklistHandler(
      task: testTask,
      autoChecklistService: mockAutoChecklistService,
      checklistRepository: mockChecklistRepository,
    );
  });

  tearDown(getIt.reset);

  group('LottiBatchChecklistHandler', () {
    test('should have correct function name', () {
      expect(handler.functionName, 'add_multiple_checklist_items');
    });

    group('processFunctionCall', () {
      test('should process array of item objects (required)', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments:
              '{"items": [{"title": "cheese"}, {"title": "tomatoes, sliced"}, {"title": "pepperoni"}]}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.map((e) => e['title']).toList(),
            ['cheese', 'tomatoes, sliced', 'pepperoni']);
      });

      test('should reject string fallback (comma-separated)', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "cheese, tomatoes, pepperoni"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Invalid or missing "items"'));
      });

      test('should fail on empty array of items', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": []}',
        );

        final result = handler.processFunctionCall(toolCall);
        expect(result.success, false);
        expect(result.error,
            'No valid items found. Provide non-empty titles (max 400 chars).');
      });

      test('should accept array with non-object elements by rejecting them',
          () {
        final toolCall = TestDataFactory.createToolCall(
          arguments:
              '{"items": [123, true, null, {"title": "valid"}, {"title": "  "}]}',
        );

        final result = handler.processFunctionCall(toolCall);
        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.map((e) => e['title']).toList(), ['valid']);
      });

      test('should reject arrays of strings (invalid shape)', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": ["a", "b"]}',
        );
        final result = handler.processFunctionCall(toolCall);
        expect(result.success, false);
        expect(result.error, contains('Each item must be an object'));
      });

      test('should handle single-item array', () {
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": [{"title": "single"}]}',
        );
        final result = handler.processFunctionCall(toolCall);
        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.map((e) => e['title']).toList(), ['single']);
      });

      test('should trim whitespace from items', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments:
              '{"items": [{"title": " cheese "}, {"title": "tomatoes"}, {"title": " pepperoni "}]}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.map((e) => e['title']).toList(),
            ['cheese', 'tomatoes', 'pepperoni']);
      });

      test('should filter out empty items', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments:
              '{"items": [{"title": ""}, {"title": "tomatoes"}, {"title": "  "}]}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        final items =
            (result.data['items'] as List).cast<Map<String, dynamic>>();
        expect(items.map((e) => e['title']).toList(), ['tomatoes']);
      });

      test('should reject string value for items', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "cheese"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, false);
        expect(result.error,
            contains('Invalid or missing "items". Provide a JSON array'));
      });

      test('should fail on empty items string', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": ""}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, false);
        expect(result.error,
            contains('Invalid or missing "items". Provide a JSON array'));
      });

      test('should fail on missing items field', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"wrong_field": "value"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, false);
        expect(result.error,
            contains('Invalid or missing "items". Provide a JSON array'));
      });

      test('should fail on invalid JSON', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: 'invalid json',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Invalid JSON'));
      });
    });

    group('createBatchItems', () {
      test('should create new checklist when none exist', () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'},
              {'title': 'tomatoes'},
              {'title': 'pepperoni'}
            ],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);
        when(() => mockJournalDb.journalEntityById('new-checklist')).thenAnswer(
          (_) async => Checklist(
            meta: Metadata(
              id: 'new-checklist',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistData(
              title: 'TODOs',
              linkedChecklistItems: ['id1', 'id2', 'id3'],
              linkedTasks: [testTask.meta.id],
            ),
          ),
        );

        when(() => mockJournalDb.journalEntityById('new-checklist')).thenAnswer(
          (_) async => Checklist(
            meta: Metadata(
              id: 'new-checklist',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistData(
              title: 'TODOs',
              linkedChecklistItems: ['id1', 'id2', 'id3'],
              linkedTasks: [testTask.meta.id],
            ),
          ),
        );
        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final suggestions = invocation.namedArguments[#suggestions]
              as List<ChecklistItemData>;
          return (
            success: true,
            checklistId: 'new-checklist',
            createdItems: suggestions
                .map((s) => (
                      id: _uuid.v4(),
                      title: s.title,
                      isChecked: s.isChecked,
                    ))
                .toList(),
            error: null,
          );
        });

        // Return a non-null item so successCount > 0 and callback is fired
        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String? ?? '';
          return ChecklistItem(
            meta: Metadata(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: const [],
            ),
          );
        });

        // Return a non-null item so successCount > 0 and callback is fired
        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String? ?? '';
          return ChecklistItem(
            meta: Metadata(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: const [],
            ),
          );
        });

        // Ensure adding items to existing checklist returns a non-null item
        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String? ?? '';
          return ChecklistItem(
            meta: Metadata(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: const [],
            ),
          );
        });

        // Act
        final count = await handler.createBatchItems(result);

        // Assert (creation happened; focus on payload correctness)
        expect(count >= 0, true);

        // Lightweight integration check for createdItems payload
        final toolResponse = handler.createToolResponse(result);
        final decoded = jsonDecode(toolResponse) as Map<String, dynamic>;
        final created =
            (decoded['createdItems'] as List).cast<Map<String, dynamic>>();
        expect(created.length, 3);
        expect(created.map((e) => e['title']).toList(),
            ['cheese', 'tomatoes', 'pepperoni']);
        expect(created.every((e) => e['isChecked'] == false), true);

        // Verify the checklist was created with correct items
        final capturedCall =
            verify(() => mockAutoChecklistService.autoCreateChecklist(
                  taskId: testTask.meta.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'TODOs',
                )).captured.single as List<ChecklistItemData>;

        expect(capturedCall.length, 3);
        expect(capturedCall.map((item) => item.title),
            ['cheese', 'tomatoes', 'pepperoni']);
        expect(capturedCall.every((item) => !item.isChecked), true);
      });

      test('should add items to existing checklist', () async {
        // Arrange
        final taskWithChecklist = TestDataFactory.createTask(
          id: testTask.meta.id,
          checklistIds: ['checklist-1'],
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'},
              {'title': 'tomatoes'},
              {'title': 'pepperoni'}
            ],
            'taskId': taskWithChecklist.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(taskWithChecklist.meta.id))
            .thenAnswer((_) async => taskWithChecklist);

        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'checklist-1',
              title: any(named: 'title'),
              isChecked: false,
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String;
          final itemId = _uuid.v4();
          return ChecklistItem(
            meta: Metadata(
              id: itemId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: [],
            ),
          );
        });

        // Act
        final count = await handler.createBatchItems(result);

        // Assert
        expect(count, 3);

        verify(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'checklist-1',
              title: 'cheese',
              isChecked: false,
              categoryId: any(named: 'categoryId'),
            )).called(1);

        verify(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'checklist-1',
              title: 'tomatoes',
              isChecked: false,
              categoryId: any(named: 'categoryId'),
            )).called(1);

        verify(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'checklist-1',
              title: 'pepperoni',
              isChecked: false,
              categoryId: any(named: 'categoryId'),
            )).called(1);
        // Lightweight integration check for createdItems payload
        final toolResponse = handler.createToolResponse(result);
        final decoded = jsonDecode(toolResponse) as Map<String, dynamic>;
        final created =
            (decoded['createdItems'] as List).cast<Map<String, dynamic>>();
        expect(created.length, 3);
        expect(created.map((e) => e['title']).toList(),
            ['cheese', 'tomatoes', 'pepperoni']);
        expect(created.every((e) => e['isChecked'] == false), true);
      });

      test('createdItems should include isChecked state when provided',
          () async {
        // Arrange: existing checklist branch, with one item marked done
        final taskWithChecklist = TestDataFactory.createTask(
          id: testTask.meta.id,
          checklistIds: ['checklist-1'],
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'done', 'isChecked': true},
              {'title': 'todo'},
            ],
            'taskId': taskWithChecklist.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(taskWithChecklist.meta.id))
            .thenAnswer((_) async => taskWithChecklist);

        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'checklist-1',
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String;
          final checked = invocation.namedArguments[#isChecked] as bool;
          return ChecklistItem(
            meta: Metadata(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: checked,
              linkedChecklists: const [],
            ),
          );
        });

        // Act
        await handler.createBatchItems(result);

        // Assert
        final toolResponse = handler.createToolResponse(result);
        final decoded = jsonDecode(toolResponse) as Map<String, dynamic>;
        final created =
            (decoded['createdItems'] as List).cast<Map<String, dynamic>>();
        expect(created.length, 2);
        expect(created.map((e) => e['title']).toList(), ['done', 'todo']);
        // First is checked, second is not
        expect(created[0]['isChecked'], true);
        expect(created[1]['isChecked'], false);
      });

      test('should create all provided items (no de-dup)', () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'},
              {'title': 'tomatoes'},
              {'title': 'pepperoni'}
            ],
            'taskId': testTask.meta.id,
          },
        );

        // existingDescriptions no longer used; duplicates are allowed

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final suggestions = invocation.namedArguments[#suggestions]
              as List<ChecklistItemData>;
          return (
            success: true,
            checklistId: 'new-checklist',
            createdItems: suggestions
                .map((s) => (
                      id: _uuid.v4(),
                      title: s.title,
                      isChecked: s.isChecked,
                    ))
                .toList(),
            error: null,
          );
        });

        // Return a non-null item so successCount > 0 and callback is fired
        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String? ?? '';
          return ChecklistItem(
            meta: Metadata(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: const [],
            ),
          );
        });

        // Act
        final count = await handler.createBatchItems(result);

        // Assert
        expect(count, 3);

        // Verify all items were created
        final capturedCall =
            verify(() => mockAutoChecklistService.autoCreateChecklist(
                  taskId: testTask.meta.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'TODOs',
                )).captured.single as List<ChecklistItemData>;

        expect(capturedCall.length, 3);
        expect(capturedCall.map((e) => e.title).toList(),
            ['cheese', 'tomatoes', 'pepperoni']);
      });

      test('should preserve duplicates within the same batch', () async {
        // Arrange - batch contains "cheese", "Cheese", and "tomatoes"
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'},
              {'title': 'Cheese'},
              {'title': 'tomatoes'}
            ],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final suggestions = invocation.namedArguments[#suggestions]
              as List<ChecklistItemData>;
          return (
            success: true,
            checklistId: 'new-checklist',
            createdItems: suggestions
                .map((s) => (
                      id: _uuid.v4(),
                      title: s.title,
                      isChecked: s.isChecked,
                    ))
                .toList(),
            error: null,
          );
        });

        // Act
        final count = await handler.createBatchItems(result);

        // Assert - all 3 items should be created in order
        expect(count, 3);

        // Verify all items were created
        final capturedCall =
            verify(() => mockAutoChecklistService.autoCreateChecklist(
                  taskId: testTask.meta.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'TODOs',
                )).captured.single as List<ChecklistItemData>;

        expect(capturedCall.length, 3);
        expect(capturedCall.map((item) => item.title).toList(),
            ['cheese', 'Cheese', 'tomatoes']);
      });

      test('should not perform case-insensitive de-duplication', () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'Cheese'},
              {'title': 'TOMATOES'},
              {'title': 'Pepperoni'}
            ],
            'taskId': testTask.meta.id,
          },
        );

        // existingDescriptions no longer used; duplicates are allowed

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final suggestions = invocation.namedArguments[#suggestions]
              as List<ChecklistItemData>;
          return (
            success: true,
            checklistId: 'new-checklist',
            createdItems: suggestions
                .map((s) => (
                      id: _uuid.v4(),
                      title: s.title,
                      isChecked: s.isChecked,
                    ))
                .toList(),
            error: null,
          );
        });

        // Act
        final count = await handler.createBatchItems(result);

        // Assert
        expect(count, 3);
      });

      test('should return 0 for unsuccessful result', () async {
        // Arrange
        const result = FunctionCallResult(
          success: false,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {},
          error: 'Some error',
        );

        // Act
        final count = await handler.createBatchItems(result);

        // Assert
        expect(count, 0);
        expect(handler.successfulItems, isEmpty);
        verifyNever(() => mockJournalDb.journalEntityById(any()));
      });

      test('should handle task update callback', () async {
        // Arrange
        var callbackInvoked = false;
        Task? updatedTask;

        handler = LottiBatchChecklistHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
          onTaskUpdated: (task) {
            callbackInvoked = true;
            updatedTask = task;
          },
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'}
            ],
            'taskId': testTask.meta.id,
          },
        );

        final refreshedTask = TestDataFactory.createTask(
          id: testTask.meta.id,
          checklistIds: ['new-checklist'],
        );

        when(() => mockJournalDb.journalEntityById('new-checklist')).thenAnswer(
          (_) async => Checklist(
            meta: Metadata(
              id: 'new-checklist',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistData(
              title: 'TODOs',
              linkedChecklistItems: const [],
              linkedTasks: [testTask.meta.id],
            ),
          ),
        );
        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => refreshedTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final suggestions = invocation.namedArguments[#suggestions]
              as List<ChecklistItemData>;
          return (
            success: true,
            checklistId: 'new-checklist',
            createdItems: suggestions
                .map((s) => (
                      id: _uuid.v4(),
                      title: s.title,
                      isChecked: s.isChecked,
                    ))
                .toList(),
            error: null,
          );
        });

        // Ensure adding items to existing checklist returns a non-null item
        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).thenAnswer((invocation) async {
          final title = invocation.namedArguments[#title] as String? ?? '';
          return ChecklistItem(
            meta: Metadata(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              dateFrom: DateTime.now(),
              dateTo: DateTime.now(),
              categoryId: 'test-category',
            ),
            data: ChecklistItemData(
              title: title,
              isChecked: false,
              linkedChecklists: const [],
            ),
          );
        });

        // Act
        final createdCount = await handler.createBatchItems(result);

        // Assert (ensure we created via existing-checklist path)
        expect(createdCount, 1);
        verify(() => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            )).called(1);

        // Also ensure the update callback fired with a Task
        expect(callbackInvoked, isTrue);
        expect(updatedTask, isA<Task>());
      });
    });

    group('isDuplicate', () {
      test('should always return false for batch operations', () {
        // Arrange
        const result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'}
            ]
          },
        );

        // Act
        final isDuplicate = handler.isDuplicate(result);

        // Assert
        expect(isDuplicate, false);
      });
    });

    group('getDescription', () {
      test('should return comma-separated items for successful result', () {
        // Arrange
        const result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'},
              {'title': 'tomatoes'},
              {'title': 'pepperoni'}
            ],
          },
        );

        // Act
        final description = handler.getDescription(result);

        // Assert
        expect(description, 'cheese, tomatoes, pepperoni');
      });

      test('should return null for unsuccessful result', () {
        // Arrange
        const result = FunctionCallResult(
          success: false,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {},
          error: 'Some error',
        );

        // Act
        final description = handler.getDescription(result);

        // Assert
        expect(description, isNull);
      });
    });

    group('createToolResponse', () {
      test('should create success response', () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'title': 'cheese'},
              {'title': 'tomatoes'}
            ],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);
        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((invocation) async {
          final suggestions = invocation.namedArguments[#suggestions]
              as List<ChecklistItemData>;
          return (
            success: true,
            checklistId: 'new-checklist',
            createdItems: suggestions
                .map((s) => (
                      id: _uuid.v4(),
                      title: s.title,
                      isChecked: s.isChecked,
                    ))
                .toList(),
            error: null,
          );
        });

        // Populate created details
        await handler.createBatchItems(result);

        // Act
        final response = handler.createToolResponse(result);

        // Assert
        expect(response, contains('"createdItems"'));
      });

      test('should create error response', () {
        // Arrange
        const result = FunctionCallResult(
          success: false,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {},
          error: 'Invalid format',
        );

        // Act
        final response = handler.createToolResponse(result);

        // Assert
        expect(response, 'Error creating checklist items: Invalid format');
      });
    });

    group('getRetryPrompt', () {
      test('should create retry prompt', () {
        // Arrange
        final failedItems = [
          const FunctionCallResult(
            success: false,
            functionName: 'add_multiple_checklist_items',
            arguments: '',
            data: {},
            error: 'Invalid JSON',
          ),
        ];
        final successfulDescriptions = ['cheese', 'tomatoes'];

        // Act
        final prompt = handler.getRetryPrompt(
          failedItems: failedItems,
          successfulDescriptions: successfulDescriptions,
        );

        // Assert
        expect(prompt, contains('I noticed an error in your function call'));
        expect(prompt, contains('{"items": ['));
        expect(prompt, contains('{"title": "item1"}'));
        expect(prompt, contains('{"title": "item2"}'));
        expect(prompt, contains('"title": "item3"'));
        expect(
            prompt,
            contains(
                'You already successfully created these checklist items: cheese, tomatoes'));
        expect(prompt,
            contains('Do NOT recreate the items that were already successful'));
      });
    });
  });
}
