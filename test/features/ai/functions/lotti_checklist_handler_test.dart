import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_handler.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  group('LottiChecklistItemHandler', () {
    late LottiChecklistItemHandler handler;
    late MockAutoChecklistService mockAutoChecklistService;
    late MockChecklistRepository mockChecklistRepository;
    late MockJournalDb mockJournalDb;
    late Task testTask;

    setUp(() {
      mockAutoChecklistService = MockAutoChecklistService();
      mockChecklistRepository = MockChecklistRepository();
      mockJournalDb = MockJournalDb();

      // Register mocks
      getIt.registerSingleton<JournalDb>(mockJournalDb);

      testTask = Task(
        meta: Metadata(
          id: 'task-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          categoryId: 'test-category',
        ),
        data: TaskData(
          title: 'Test Task',
          checklistIds: const [],
          status: TaskStatus.open(
            id: 'status-123',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
        ),
      );

      handler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );
    });

    tearDown(getIt.reset);

    group('processFunctionCall error messages', () {
      test('should show specific error for empty description', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'add_checklist_item',
            arguments: '{"actionItemDescription": "   "}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error,
            'Empty description provided. Please provide a meaningful description.');
      });

      test('should show error when wrong field name is used', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'add_checklist_item',
            arguments: '{"description": "Buy milk"}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error,
            'Found "description" instead of "actionItemDescription"');
        expect(result.data['attemptedItem'], 'Buy milk');
        expect(result.data['wrongFieldName'], 'description');
      });

      test('should show generic error when field is completely missing', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-3',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'add_checklist_item',
            arguments: '{}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error, 'Missing required field "actionItemDescription"');
        expect(result.data['attemptedItem'], '');
        expect(result.data['wrongFieldName'], null);
      });

      test('should detect empty string in attempted item', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-4',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'add_checklist_item',
            arguments: '{"wrongField": ""}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        // Since the attempted item is empty, it should show missing field error
        expect(result.error, 'Missing required field "actionItemDescription"');
      });

      test('should handle multiple wrong fields and pick first non-empty', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-5',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'add_checklist_item',
            arguments:
                '{"emptyField": "", "item": "Buy groceries", "task": "Shopping"}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error,
            contains('Found "item" instead of "actionItemDescription"'));
        expect(result.data['attemptedItem'], 'Buy groceries');
        expect(result.data['wrongFieldName'], 'item');
      });

      test('should reject function with wrong name', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-6',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'create_todo_item',
            arguments: '{"actionItemDescription": "Buy milk"}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error, contains('Function name mismatch'));
        expect(result.error, contains('expected "add_checklist_item"'));
        expect(result.error, contains('got "create_todo_item"'));
      });
    });

    group('createItem', () {
      test('should create checklist when none exists', () async {
        // Mock journalDb to return task without checklists first, then with checklist
        var callCount = 0;
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // First call: return task without checklists
            return testTask;
          } else {
            // Subsequent calls: return updated task with checklist
            return Task(
              meta: testTask.meta,
              data: testTask.data.copyWith(
                checklistIds: ['new-checklist'],
              ),
            );
          }
        });

        // Mock successful checklist creation
        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: true,
              checklistId: 'new-checklist',
              error: null,
            ));

        const result = FunctionCallResult(
          success: true,
          functionName: 'add_checklist_item',
          arguments: '',
          data: {'description': 'Buy milk'},
        );

        final created = await handler.createItem(result);

        expect(created, true);
        expect(handler.successfulItems, contains('Buy milk'));

        verify(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).called(1);
      });

      test('should add to existing checklist', () async {
        // Task with existing checklist
        final taskWithChecklist = Task(
          meta: testTask.meta,
          data: testTask.data.copyWith(
            checklistIds: ['existing-checklist'],
          ),
        );

        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => taskWithChecklist);

        // Mock successful item addition
        when(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'existing-checklist',
              title: 'Buy milk',
              isChecked: false,
              categoryId: testTask.meta.categoryId,
            )).thenAnswer((_) async => ChecklistItem(
              meta: Metadata(
                id: 'item-123',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                dateFrom: DateTime.now(),
                dateTo: DateTime.now(),
                categoryId: testTask.meta.categoryId,
              ),
              data: const ChecklistItemData(
                title: 'Buy milk',
                isChecked: false,
                linkedChecklists: ['existing-checklist'],
              ),
            ));

        const result = FunctionCallResult(
          success: true,
          functionName: 'add_checklist_item',
          arguments: '',
          data: {'description': 'Buy milk'},
        );

        final created = await handler.createItem(result);

        expect(created, true);
        expect(handler.successfulItems, contains('Buy milk'));

        verify(() => mockChecklistRepository.addItemToChecklist(
              checklistId: 'existing-checklist',
              title: 'Buy milk',
              isChecked: false,
              categoryId: testTask.meta.categoryId,
            )).called(1);
      });

      test('should return false on creation failure', () async {
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenAnswer((_) async => testTask);

        when(() => mockAutoChecklistService.autoCreateChecklist(
              taskId: testTask.id,
              suggestions: any(named: 'suggestions'),
              title: 'TODOs',
            )).thenAnswer((_) async => (
              success: false,
              checklistId: null,
              error: 'Creation failed',
            ));

        const result = FunctionCallResult(
          success: true,
          functionName: 'add_checklist_item',
          arguments: '',
          data: {'description': 'Buy milk'},
        );

        final created = await handler.createItem(result);

        expect(created, false);
        expect(handler.successfulItems, isEmpty);
      });

      test('should handle exceptions gracefully', () async {
        when(() => mockJournalDb.journalEntityById(testTask.id))
            .thenThrow(Exception('Database error'));

        const result = FunctionCallResult(
          success: true,
          functionName: 'add_checklist_item',
          arguments: '',
          data: {'description': 'Buy milk'},
        );

        final created = await handler.createItem(result);

        expect(created, false);
        expect(handler.successfulItems, isEmpty);
      });
    });

    group('getRetryPrompt', () {
      test('should include task-specific context in retry prompt', () {
        final failedResult = FunctionCallResult(
          success: false,
          functionName: 'add_checklist_item',
          arguments: '',
          data: {
            'attemptedItem': 'Buy milk',
            'wrongFieldName': 'item',
            'taskId': testTask.id,
          },
          error: 'Found "item" instead of "actionItemDescription"',
        );

        final prompt = handler.getRetryPrompt(
          failedItems: [failedResult],
          successfulDescriptions: ['Buy bread'],
        );

        // The prompt should contain the error message and attempted item
        expect(prompt,
            contains('Found "item" instead of "actionItemDescription"'));
        expect(prompt, contains('for "Buy milk"'));
        expect(prompt, contains('Buy bread')); // successful item
        expect(prompt, contains('Use the correct format'));
      });
    });
  });
}
