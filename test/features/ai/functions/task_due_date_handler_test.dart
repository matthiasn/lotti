import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

class MockConversationManager extends Mock implements ConversationManager {}

void main() {
  late MockJournalRepository mockJournalRepo;
  late MockConversationManager mockManager;

  // Fixed date for deterministic tests - per test/README.md policy
  final fixedDate = DateTime(2024, 1, 15);

  setUpAll(() {
    registerFallbackValue(
      Task(
        meta: Metadata(
          id: 'fallback',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
          categoryId: 'fallback-category',
        ),
        data: TaskData(
          title: 'fallback',
          status: TaskStatus.open(
            id: 'status-fallback',
            createdAt: DateTime(2024),
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024),
        ),
      ),
    );
  });

  setUp(() {
    mockJournalRepo = MockJournalRepository();
    mockManager = MockConversationManager();
  });

  /// Creates a task with optional due date.
  Task createTask({DateTime? due}) {
    return Task(
      meta: Metadata(
        id: 'test-task-id',
        createdAt: fixedDate,
        updatedAt: fixedDate,
        dateFrom: fixedDate,
        dateTo: fixedDate,
        categoryId: 'test-category',
      ),
      data: TaskData(
        title: 'Test Task',
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: fixedDate,
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: fixedDate,
        dateTo: fixedDate,
        due: due,
      ),
    );
  }

  /// Creates a tool call for update_task_due_date.
  ChatCompletionMessageToolCall createDueDateToolCall({
    required String dueDate,
    String? reason,
    String? confidence,
  }) {
    return ChatCompletionMessageToolCall(
      id: 'call_due_date_456',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_due_date',
        arguments: jsonEncode({
          'dueDate': dueDate,
          if (reason != null) 'reason': reason,
          if (confidence != null) 'confidence': confidence,
        }),
      ),
    );
  }

  group('TaskDueDateHandler', () {
    group('successful updates', () {
      test('should update due date when currently null', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(
          dueDate: '2024-01-19',
          reason: 'User said Friday',
          confidence: 'high',
        );

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        Task? capturedTask;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (t) => capturedTask = t,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedDate, DateTime(2024, 1, 19));
        expect(result.reason, 'User said Friday');
        expect(result.confidence, 'high');
        expect(result.updatedTask, isNotNull);
        expect(result.updatedTask!.data.due, DateTime(2024, 1, 19));
        expect(result.error, isNull);

        expect(capturedTask, isNotNull);
        expect(capturedTask!.data.due, DateTime(2024, 1, 19));

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_due_date_456',
            response: 'Task due date updated to 2024-01-19.',
          ),
        ).called(1);
      });

      test('should update handler task reference after success', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-02-01');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.due, isNull);

        await handler.processToolCall(toolCall, mockManager);

        expect(handler.task.data.due, DateTime(2024, 2));
      });

      test('should work without ConversationManager (for unit testing)',
          () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-03-15');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        // Call without manager
        final result = await handler.processToolCall(toolCall);

        expect(result.success, isTrue);
        expect(result.requestedDate, DateTime(2024, 3, 15));
        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        // Manager methods should not be called
        verifyNever(
          () => mockManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          ),
        );
      });

      test('should accept past due dates', () async {
        final task = createTask();
        // Date before fixedDate (2024-01-15)
        final toolCall = createDueDateToolCall(
          dueDate: '2024-01-10',
          reason: 'Task was due last week',
        );

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedDate, DateTime(2024, 1, 10));
        expect(result.updatedTask!.data.due, DateTime(2024, 1, 10));
      });
    });

    group('skipped updates (existing due date)', () {
      test('should skip when due date already exists', () async {
        final task = createTask(due: DateTime(2024, 1, 20));
        final toolCall = createDueDateToolCall(
          dueDate: '2024-01-25',
          reason: 'User mentioned next Friday',
          confidence: 'high',
        );

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isTrue);
        expect(result.requestedDate, DateTime(2024, 1, 25));
        expect(result.reason, 'User mentioned next Friday');
        expect(result.confidence, 'high');
        expect(result.error, isNull); // Not an error, just skipped
        expect(result.updatedTask, isNull);
        expect(result.message, contains('already set to 2024-01-20'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_due_date_456',
            response: 'Due date already set to 2024-01-20. Skipped.',
          ),
        ).called(1);
      });

      test('should not call onTaskUpdated when skipped', () async {
        final task = createTask(due: DateTime(2024, 1, 22));
        final toolCall = createDueDateToolCall(dueDate: '2024-01-30');

        var callbackCalled = false;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });
    });

    group('validation errors', () {
      test('should reject null dueDate', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_due_date_456',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_due_date',
            arguments: '{"reason": "Some reason"}',
          ),
        );

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('date string is required'));
        expect(result.requestedDate, isNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject empty dueDate string', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '');

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('date string is required'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_due_date_456',
            response: 'Invalid due date: date string is required.',
          ),
        ).called(1);
      });

      test('should reject invalid date format', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(
          dueDate: 'not-a-date',
          reason: 'Invalid format',
          confidence: 'low',
        );

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('YYYY-MM-DD'));
        expect(result.requestedDate, isNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject partial date format', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01');

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('YYYY-MM-DD'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should handle malformed JSON', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_due_date_456',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_due_date',
            arguments: 'not valid json',
          ),
        );

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_due_date_456',
            response: 'Error processing task due date update.',
          ),
        ).called(1);
      });
    });

    group('repository errors', () {
      test('should handle repository failure gracefully', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01-25');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database connection lost'));

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('Database connection lost'));
        expect(result.requestedDate, DateTime(2024, 1, 25));
        expect(result.updatedTask, isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_due_date_456',
            response:
                'Failed to set due date. Continuing without due date update.',
          ),
        ).called(1);
      });

      test('should not call onTaskUpdated when repository fails', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01-25');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database error'));

        var callbackCalled = false;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });

      test('should not update handler task reference when repository fails',
          () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01-25');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database error'));

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.processToolCall(toolCall);

        // Task should remain unchanged
        expect(handler.task.data.due, isNull);
      });
    });

    group('TaskDueDateResult', () {
      test('wasSkipped returns true for non-error failures', () {
        const result = TaskDueDateResult(
          success: false,
          message: 'Already set',
        );

        expect(result.wasSkipped, isTrue);
      });

      test('wasSkipped returns false when error is present', () {
        const result = TaskDueDateResult(
          success: false,
          message: 'Invalid input',
          error: 'date format invalid',
        );

        expect(result.wasSkipped, isFalse);
      });

      test('wasSkipped returns false when success is true', () {
        final result = TaskDueDateResult(
          success: true,
          message: 'Updated',
          requestedDate: DateTime(2024, 1, 25),
        );

        expect(result.wasSkipped, isFalse);
      });
    });

    group('date format variations', () {
      test('should reject full ISO 8601 datetime (requires date-only)',
          () async {
        final task = createTask();
        // Datetime format should be rejected - we require YYYY-MM-DD only
        final toolCall = createDueDateToolCall(dueDate: '2024-01-19T10:30:00');

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('YYYY-MM-DD'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject ISO 8601 with timezone (requires date-only)',
          () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01-19T10:30:00Z');

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('YYYY-MM-DD'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should handle date at year boundary', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-12-31');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedDate, DateTime(2024, 12, 31));
      });

      test('should handle leap year date', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-02-29');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedDate, DateTime(2024, 2, 29));
      });

      test('should normalize to midnight', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01-19');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        // Date should be normalized to midnight (00:00:00)
        expect(result.requestedDate, DateTime(2024, 1, 19));
        expect(result.requestedDate!.hour, 0);
        expect(result.requestedDate!.minute, 0);
        expect(result.requestedDate!.second, 0);
      });
    });

    group('edge cases', () {
      test('should preserve other task fields when updating due date',
          () async {
        final task = Task(
          meta: Metadata(
            id: 'test-task-id',
            createdAt: fixedDate,
            updatedAt: fixedDate,
            dateFrom: fixedDate,
            dateTo: fixedDate,
            categoryId: 'test-category',
          ),
          data: TaskData(
            title: 'Important Task',
            status: TaskStatus.inProgress(
              id: 'status-2',
              createdAt: fixedDate,
              utcOffset: 0,
            ),
            statusHistory: const [],
            dateFrom: fixedDate,
            dateTo: DateTime(2024, 1, 20),
            estimate: const Duration(minutes: 60),
            // due is null
          ),
        );
        final toolCall = createDueDateToolCall(dueDate: '2024-01-25');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        final updated = result.updatedTask!;
        expect(updated.data.title, 'Important Task');
        expect(updated.data.status.id, 'status-2');
        expect(updated.data.estimate, const Duration(minutes: 60));
        expect(updated.data.due, DateTime(2024, 1, 25));
        expect(updated.meta.id, 'test-task-id');
      });

      test('should handle date far in the future', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2030-12-31');

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedDate, DateTime(2030, 12, 31));
      });
    });
  });
}
