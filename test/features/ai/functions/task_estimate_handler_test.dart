import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/task_estimate_handler.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

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

  /// Creates a task with optional estimate.
  Task createTask({Duration? estimate}) {
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
        estimate: estimate,
      ),
    );
  }

  /// Creates a tool call for update_task_estimate.
  ChatCompletionMessageToolCall createEstimateToolCall({
    required int minutes,
    String? reason,
    String? confidence,
  }) {
    return ChatCompletionMessageToolCall(
      id: 'call_estimate_123',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_estimate',
        arguments: jsonEncode({
          'minutes': minutes,
          if (reason != null) 'reason': reason,
          if (confidence != null) 'confidence': confidence,
        }),
      ),
    );
  }

  group('TaskEstimateHandler', () {
    group('successful updates', () {
      test('should update estimate when currently null', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(
          minutes: 120,
          reason: 'User mentioned 2 hours',
          confidence: 'high',
        );

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        Task? capturedTask;
        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (t) => capturedTask = t,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 120);
        expect(result.reason, 'User mentioned 2 hours');
        expect(result.confidence, 'high');
        expect(result.updatedTask, isNotNull);
        expect(result.updatedTask!.data.estimate, const Duration(minutes: 120));
        expect(result.error, isNull);

        expect(capturedTask, isNotNull);
        expect(capturedTask!.data.estimate, const Duration(minutes: 120));

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_estimate_123',
            response: 'Task estimate updated to 120 minutes.',
          ),
        ).called(1);
      });

      test('should update estimate when currently zero (treat as not set)',
          () async {
        final task = createTask(estimate: Duration.zero);
        final toolCall = createEstimateToolCall(minutes: 60);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 60);
        expect(result.updatedTask!.data.estimate, const Duration(minutes: 60));

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('should update handler task reference after success', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 90);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.estimate, isNull);

        await handler.processToolCall(toolCall, mockManager);

        expect(handler.task.data.estimate, const Duration(minutes: 90));
      });

      test('should work without ConversationManager (for unit testing)',
          () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 45);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        // Call without manager
        final result = await handler.processToolCall(toolCall);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 45);
        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        // Manager methods should not be called
        verifyNever(
          () => mockManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          ),
        );
      });
    });

    group('skipped updates (existing estimate)', () {
      test('should skip when estimate already exists', () async {
        final task = createTask(estimate: const Duration(minutes: 60));
        final toolCall = createEstimateToolCall(
          minutes: 120,
          reason: 'User mentioned 2 hours',
          confidence: 'high',
        );

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isTrue);
        expect(result.requestedMinutes, 120);
        expect(result.reason, 'User mentioned 2 hours');
        expect(result.confidence, 'high');
        expect(result.error, isNull); // Not an error, just skipped
        expect(result.updatedTask, isNull);
        expect(result.message, contains('already set to 60 minutes'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_estimate_123',
            response: 'Estimate already set to 60 minutes. Skipped.',
          ),
        ).called(1);
      });

      test('should not call onTaskUpdated when skipped', () async {
        final task = createTask(estimate: const Duration(minutes: 30));
        final toolCall = createEstimateToolCall(minutes: 60);

        var callbackCalled = false;
        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });
    });

    group('validation errors', () {
      test('should reject null minutes', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_estimate_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_estimate',
            arguments: '{"reason": "Some reason"}',
          ),
        );

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('positive integer'));
        expect(result.requestedMinutes, isNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject zero minutes', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 0);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('positive integer'));
        expect(result.requestedMinutes, 0);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject negative minutes', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: -30);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('positive integer'));
        expect(result.requestedMinutes, -30);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should handle malformed JSON', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_estimate_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_estimate',
            arguments: 'not valid json',
          ),
        );

        final handler = TaskEstimateHandler(
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
            toolCallId: 'call_estimate_123',
            response: 'Error processing task estimate update.',
          ),
        ).called(1);
      });
    });

    group('repository errors', () {
      test('should handle repository failure gracefully', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 90);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database connection lost'));

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('Database connection lost'));
        expect(result.requestedMinutes, 90);
        expect(result.updatedTask, isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_estimate_123',
            response:
                'Failed to set estimate. Continuing without estimate update.',
          ),
        ).called(1);
      });

      test('should not call onTaskUpdated when repository fails', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 90);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database error'));

        var callbackCalled = false;
        final handler = TaskEstimateHandler(
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
        final toolCall = createEstimateToolCall(minutes: 90);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('Database error'));

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.processToolCall(toolCall);

        // Task should remain unchanged
        expect(handler.task.data.estimate, isNull);
      });
    });

    group('TaskEstimateResult', () {
      test('wasSkipped returns true for non-error failures', () {
        const result = TaskEstimateResult(
          success: false,
          message: 'Already set',
          requestedMinutes: 60,
        );

        expect(result.wasSkipped, isTrue);
      });

      test('wasSkipped returns false when error is present', () {
        const result = TaskEstimateResult(
          success: false,
          message: 'Invalid input',
          error: 'minutes must be positive',
        );

        expect(result.wasSkipped, isFalse);
      });

      test('wasSkipped returns false when success is true', () {
        const result = TaskEstimateResult(
          success: true,
          message: 'Updated',
          requestedMinutes: 60,
        );

        expect(result.wasSkipped, isFalse);
      });
    });

    group('edge cases', () {
      test('should handle large minute values', () async {
        final task = createTask();
        // 1 week in minutes
        final toolCall = createEstimateToolCall(minutes: 10080);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 10080);
        expect(
          result.updatedTask!.data.estimate,
          const Duration(minutes: 10080),
        );
      });

      test('should handle 1 minute estimate', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 1);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 1);
        expect(result.updatedTask!.data.estimate, const Duration(minutes: 1));
      });

      test('should preserve other task fields when updating estimate',
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
            due: DateTime(2024, 1, 25),
            // estimate is null
          ),
        );
        final toolCall = createEstimateToolCall(minutes: 60);

        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        final updated = result.updatedTask!;
        expect(updated.data.title, 'Important Task');
        expect(updated.data.status.id, 'status-2');
        expect(updated.data.due, DateTime(2024, 1, 25));
        expect(updated.data.estimate, const Duration(minutes: 60));
        expect(updated.meta.id, 'test-task-id');
      });
    });
  });
}
