import 'package:flutter_test/flutter_test.dart';
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
        arguments: arguments ?? '{"items": "item1, item2, item3"}',
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
      test('should process array of items (preferred)', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": ["cheese", "tomatoes, sliced", "pepperoni"]}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(
            result.data['items'], ['cheese', 'tomatoes, sliced', 'pepperoni']);
      });

      test('should process valid comma-separated items', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "cheese, tomatoes, pepperoni"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.functionName, 'add_multiple_checklist_items');
        expect(result.data['items'], ['cheese', 'tomatoes', 'pepperoni']);
        expect(result.data['toolCallId'], 'tool-1');
        expect(result.data['taskId'], testTask.meta.id);
        expect(result.error, isNull);
      });

      test('should support quoted items with commas', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: r'{"items": "\"cheese, sliced\", tomatoes"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.data['items'], ['cheese, sliced', 'tomatoes']);
      });

      test('should support escaped commas', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: r'{"items": "cheese\\, sliced, tomatoes"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.data['items'], ['cheese, sliced', 'tomatoes']);
      });

      test('should not split commas inside parentheses', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "Start database (index cache, warm), Verify"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.data['items'],
            ['Start database (index cache, warm)', 'Verify']);
      });

      test('should trim whitespace from items', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": " cheese , tomatoes , pepperoni "}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.data['items'], ['cheese', 'tomatoes', 'pepperoni']);
      });

      test('should filter out empty items', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "cheese, , tomatoes, , pepperoni"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.data['items'], ['cheese', 'tomatoes', 'pepperoni']);
      });

      test('should handle single item', () {
        // Arrange
        final toolCall = TestDataFactory.createToolCall(
          arguments: '{"items": "cheese"}',
        );

        // Act
        final result = handler.processFunctionCall(toolCall);

        // Assert
        expect(result.success, true);
        expect(result.data['items'], ['cheese']);
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
        expect(result.error, 'Missing required field "items" or empty list');
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
        expect(result.error, 'Missing required field "items" or empty list');
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
            'items': ['cheese', 'tomatoes', 'pepperoni'],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        // Act
        final count = await handler.createBatchItems(result);

        // Assert
        expect(count, 3);
        expect(handler.successfulItems, ['cheese', 'tomatoes', 'pepperoni']);

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
            'items': ['cheese', 'tomatoes', 'pepperoni'],
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
        expect(handler.successfulItems, ['cheese', 'tomatoes', 'pepperoni']);

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
      });

      test('should prevent duplicate items using existingDescriptions',
          () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': ['cheese', 'tomatoes', 'pepperoni'],
            'taskId': testTask.meta.id,
          },
        );

        final existingDescriptions = {'cheese', 'tomatoes'};

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        // Act
        final count = await handler.createBatchItems(
          result,
          existingDescriptions: existingDescriptions,
        );

        // Assert
        expect(count, 1);
        expect(handler.successfulItems, ['pepperoni']);

        // Verify only pepperoni was created
        final capturedCall =
            verify(() => mockAutoChecklistService.autoCreateChecklist(
                  taskId: testTask.meta.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'TODOs',
                )).captured.single as List<ChecklistItemData>;

        expect(capturedCall.length, 1);
        expect(capturedCall.first.title, 'pepperoni');
      });

      test('should filter duplicates within the same batch', () async {
        // Arrange - batch contains "cheese", "Cheese", and "tomatoes"
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': ['cheese', 'Cheese', 'tomatoes'],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        // Act
        final count = await handler.createBatchItems(result);

        // Assert - only 2 items should be created (cheese and tomatoes)
        expect(count, 2);
        expect(handler.successfulItems, ['cheese', 'tomatoes']);

        // Verify only unique items were created
        final capturedCall =
            verify(() => mockAutoChecklistService.autoCreateChecklist(
                  taskId: testTask.meta.id,
                  suggestions: captureAny(named: 'suggestions'),
                  title: 'TODOs',
                )).captured.single as List<ChecklistItemData>;

        expect(capturedCall.length, 2);
        expect(capturedCall.map((item) => item.title).toList(),
            ['cheese', 'tomatoes']);
      });

      test('should handle case-insensitive duplicate detection', () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': ['Cheese', 'TOMATOES', 'Pepperoni'],
            'taskId': testTask.meta.id,
          },
        );

        final existingDescriptions = {'cheese', 'tomatoes'};

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        // Act
        final count = await handler.createBatchItems(
          result,
          existingDescriptions: existingDescriptions,
        );

        // Assert
        expect(count, 1);
        expect(handler.successfulItems, ['Pepperoni']);
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
            'items': ['cheese'],
            'taskId': testTask.meta.id,
          },
        );

        final refreshedTask = TestDataFactory.createTask(
          id: testTask.meta.id,
          checklistIds: ['new-checklist'],
        );

        var callCount = 0;
        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? testTask : refreshedTask;
        });

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.meta.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        // Act
        await handler.createBatchItems(result);

        // Assert
        expect(callbackInvoked, true);
        expect(updatedTask, refreshedTask);
        expect(handler.task, refreshedTask);
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
            'items': ['cheese']
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
            'items': ['cheese', 'tomatoes', 'pepperoni'],
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
      test('should create success response', () {
        // Arrange
        const result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': ['cheese', 'tomatoes'],
          },
        );

        // Act
        final response = handler.createToolResponse(result);

        // Assert
        expect(response, 'Ready to create 2 checklist items: cheese, tomatoes');
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
        expect(response, 'Error processing checklist items: Invalid format');
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
        expect(prompt, contains('{"items": "item1, item2, item3"}'));
        expect(
            prompt,
            contains(
                'You already successfully created these checklist items: cheese, tomatoes'));
        expect(prompt,
            contains('Do NOT recreate the items that were already successful'));
      });
    });

    group('reset', () {
      test('should clear all created items', () async {
        // Arrange
        final result = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': ['cheese', 'tomatoes'],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: any(named: 'taskId'),
              suggestions: any(named: 'suggestions'),
              title: any(named: 'title'),
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        await handler.createBatchItems(result);
        expect(handler.successfulItems, ['cheese', 'tomatoes']);

        // Act
        handler.reset();

        // Assert
        expect(handler.successfulItems, isEmpty);

        // Verify duplicate detection is also reset
        final newResult = FunctionCallResult(
          success: true,
          functionName: 'add_multiple_checklist_items',
          arguments: '',
          data: {
            'items': ['cheese'],
            'taskId': testTask.meta.id,
          },
        );

        when(() => mockJournalDb.journalEntityById(testTask.meta.id))
            .thenAnswer((_) async => testTask);

        final count = await handler.createBatchItems(newResult);
        expect(count, 1);
        expect(handler.successfulItems, ['cheese']);
      });
    });
  });
}
