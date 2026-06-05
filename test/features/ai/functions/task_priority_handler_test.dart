import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/functions/task_priority_handler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedPriorityRequestShape {
  exact,
  lowercase,
  padded,
  invalidString,
  missing,
  nonString,
}

class _GeneratedPriorityToolCallScenario {
  const _GeneratedPriorityToolCallScenario({
    required this.currentPriority,
    required this.requestPriority,
    required this.requestShape,
    required this.repositorySucceeds,
    required this.seed,
  });

  final TaskPriority currentPriority;
  final TaskPriority requestPriority;
  final _GeneratedPriorityRequestShape requestShape;
  final bool repositorySucceeds;
  final int seed;

  Object? get rawPriority {
    return switch (requestShape) {
      _GeneratedPriorityRequestShape.exact => requestPriority.short,
      _GeneratedPriorityRequestShape.lowercase =>
        requestPriority.short.toLowerCase(),
      _GeneratedPriorityRequestShape.padded => '  ${requestPriority.short}  ',
      _GeneratedPriorityRequestShape.invalidString => 'P${4 + (seed % 5)}',
      _GeneratedPriorityRequestShape.missing => null,
      _GeneratedPriorityRequestShape.nonString => seed,
    };
  }

  TaskPriority? get parsedPriority {
    return TaskPriorityHandler.parsePriority(rawPriority);
  }

  bool get isInvalid => parsedPriority == null;

  bool get isNoOp => !isInvalid && parsedPriority == currentPriority;

  bool get shouldAttemptWrite => !isInvalid && !isNoOp;

  bool get shouldWrite => shouldAttemptWrite && repositorySucceeds;

  Map<String, Object?> get arguments => {
    if (requestShape != _GeneratedPriorityRequestShape.missing)
      'priority': rawPriority,
    'reason': 'Generated reason $seed',
    'confidence': seed.isEven ? 'high' : 'medium',
  };

  @override
  String toString() {
    return '_GeneratedPriorityToolCallScenario('
        'currentPriority: ${currentPriority.short}, '
        'requestPriority: ${requestPriority.short}, '
        'requestShape: $requestShape, '
        'repositorySucceeds: $repositorySucceeds, '
        'seed: $seed)';
  }
}

extension _AnyTaskPriorityHandlerScenario on glados.Any {
  glados.Generator<TaskPriority> get taskPriority =>
      glados.AnyUtils(this).choose(TaskPriority.values);

  glados.Generator<_GeneratedPriorityRequestShape> get priorityRequestShape =>
      glados.AnyUtils(this).choose(_GeneratedPriorityRequestShape.values);

  glados.Generator<_GeneratedPriorityToolCallScenario>
  get priorityToolCallScenario => glados.CombinableAny(this).combine5(
    taskPriority,
    taskPriority,
    priorityRequestShape,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 10000),
    (
      TaskPriority currentPriority,
      TaskPriority requestPriority,
      _GeneratedPriorityRequestShape requestShape,
      bool repositorySucceeds,
      int seed,
    ) => _GeneratedPriorityToolCallScenario(
      currentPriority: currentPriority,
      requestPriority: requestPriority,
      requestShape: requestShape,
      repositorySucceeds: repositorySucceeds,
      seed: seed,
    ),
  );
}

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

  /// Creates a task with optional priority.
  Task createTask({TaskPriority priority = TaskPriority.p2Medium}) {
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
        priority: priority,
      ),
    );
  }

  /// Creates a tool call for update_task_priority.
  ChatCompletionMessageToolCall createPriorityToolCall({
    required String priority,
    String? reason,
    String? confidence,
  }) {
    return ChatCompletionMessageToolCall(
      id: 'call_priority_123',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_priority',
        arguments: jsonEncode({
          'priority': priority,
          'reason': ?reason,
          'confidence': ?confidence,
        }),
      ),
    );
  }

  ChatCompletionMessageToolCall createPriorityToolCallFromArgs(
    Map<String, Object?> args,
  ) {
    return ChatCompletionMessageToolCall(
      id: 'call_priority_generated',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_priority',
        arguments: jsonEncode(args),
      ),
    );
  }

  group('parsePriority', () {
    test('should parse P0 to p0Urgent', () {
      expect(TaskPriorityHandler.parsePriority('P0'), TaskPriority.p0Urgent);
    });

    test('should parse P1 to p1High', () {
      expect(TaskPriorityHandler.parsePriority('P1'), TaskPriority.p1High);
    });

    test('should parse P2 to p2Medium', () {
      expect(TaskPriorityHandler.parsePriority('P2'), TaskPriority.p2Medium);
    });

    test('should parse P3 to p3Low', () {
      expect(TaskPriorityHandler.parsePriority('P3'), TaskPriority.p3Low);
    });

    test('should be case-insensitive', () {
      expect(TaskPriorityHandler.parsePriority('p0'), TaskPriority.p0Urgent);
      expect(TaskPriorityHandler.parsePriority('p1'), TaskPriority.p1High);
      expect(TaskPriorityHandler.parsePriority('p2'), TaskPriority.p2Medium);
      expect(TaskPriorityHandler.parsePriority('p3'), TaskPriority.p3Low);
    });

    test('should handle mixed case', () {
      expect(TaskPriorityHandler.parsePriority('P0'), TaskPriority.p0Urgent);
      expect(TaskPriorityHandler.parsePriority('p0'), TaskPriority.p0Urgent);
    });

    test('should trim whitespace', () {
      expect(
        TaskPriorityHandler.parsePriority('  P0  '),
        TaskPriority.p0Urgent,
      );
      expect(TaskPriorityHandler.parsePriority('\tP1\n'), TaskPriority.p1High);
    });

    test('should return null for invalid values', () {
      expect(TaskPriorityHandler.parsePriority(null), isNull);
      expect(TaskPriorityHandler.parsePriority(''), isNull);
      expect(TaskPriorityHandler.parsePriority('P4'), isNull);
      expect(TaskPriorityHandler.parsePriority('P-1'), isNull);
      expect(TaskPriorityHandler.parsePriority('urgent'), isNull);
      expect(TaskPriorityHandler.parsePriority('high'), isNull);
      expect(TaskPriorityHandler.parsePriority('0'), isNull);
      expect(TaskPriorityHandler.parsePriority('1'), isNull);
    });

    test('should return null for non-string values', () {
      expect(TaskPriorityHandler.parsePriority(0), isNull);
      expect(TaskPriorityHandler.parsePriority(1), isNull);
      expect(TaskPriorityHandler.parsePriority(true), isNull);
      expect(TaskPriorityHandler.parsePriority(['P0']), isNull);
    });
  });

  group('TaskPriorityHandler', () {
    group('successful updates', () {
      test(
        'should update priority when currently default (p2Medium)',
        () async {
          final task = createTask(); // default is p2Medium
          final toolCall = createPriorityToolCall(
            priority: 'P1',
            reason: 'User said high priority',
            confidence: 'high',
          );

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          Task? capturedTask;
          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
            onTaskUpdated: (t) => capturedTask = t,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          expect(result.success, isTrue);
          expect(result.requestedPriority, TaskPriority.p1High);
          expect(result.reason, 'User said high priority');
          expect(result.confidence, 'high');
          expect(result.updatedTask, isNotNull);
          expect(result.updatedTask!.data.priority, TaskPriority.p1High);
          expect(result.error, isNull);

          expect(capturedTask, isNotNull);
          expect(capturedTask!.data.priority, TaskPriority.p1High);

          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
          verify(
            () => mockManager.addToolResponse(
              toolCallId: 'call_priority_123',
              response: 'Task priority updated to P1.',
            ),
          ).called(1);
        },
      );

      test('should update to P0 (Urgent)', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(
          priority: 'P0',
          reason: 'User mentioned urgent',
          confidence: 'high',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedPriority, TaskPriority.p0Urgent);
        expect(result.updatedTask!.data.priority, TaskPriority.p0Urgent);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('should update to P3 (Low)', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(
          priority: 'P3',
          reason: 'User mentioned low priority',
          confidence: 'high',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedPriority, TaskPriority.p3Low);
        expect(result.updatedTask!.data.priority, TaskPriority.p3Low);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('should update handler task reference after success', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: 'P0');

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.priority, TaskPriority.p2Medium);

        await handler.processToolCall(toolCall, mockManager);

        expect(handler.task.data.priority, TaskPriority.p0Urgent);
      });

      test(
        'should work without ConversationManager (for unit testing)',
        () async {
          final task = createTask();
          final toolCall = createPriorityToolCall(priority: 'P1');

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          // Call without manager
          final result = await handler.processToolCall(toolCall);

          expect(result.success, isTrue);
          expect(result.requestedPriority, TaskPriority.p1High);
          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
          // Manager methods should not be called
          verifyNever(
            () => mockManager.addToolResponse(
              toolCallId: any(named: 'toolCallId'),
              response: any(named: 'response'),
            ),
          );
        },
      );

      test('should handle lowercase priority strings', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: 'p1');

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedPriority, TaskPriority.p1High);
      });
    });

    group('no-op when same priority', () {
      test('should no-op when requested priority matches current', () async {
        final task = createTask(priority: TaskPriority.p0Urgent);
        final toolCall = createPriorityToolCall(
          priority: 'P0',
          reason: 'Confirming priority',
          confidence: 'high',
        );

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.wasNoOp, isTrue);
        expect(result.requestedPriority, TaskPriority.p0Urgent);
        expect(result.message, contains('No change needed'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should not call onTaskUpdated when same priority', () async {
        final task = createTask(priority: TaskPriority.p1High);
        final toolCall = createPriorityToolCall(priority: 'P1');

        var callbackCalled = false;
        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });
    });

    group('updates existing priority to different value', () {
      test('should update from P0 to P1', () async {
        final task = createTask(priority: TaskPriority.p0Urgent);
        final toolCall = createPriorityToolCall(
          priority: 'P1',
          reason: 'User said high priority',
          confidence: 'high',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.requestedPriority, TaskPriority.p1High);
        expect(result.updatedTask!.data.priority, TaskPriority.p1High);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('should update from P3 to P0', () async {
        final task = createTask(priority: TaskPriority.p3Low);
        final toolCall = createPriorityToolCall(priority: 'P0');

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.priority, TaskPriority.p0Urgent);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });
    });

    group('validation errors', () {
      test('should reject null priority', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_priority_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_priority',
            arguments: '{"reason": "Some reason"}',
          ),
        );

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('must be P0, P1, P2, or P3'));
        expect(result.requestedPriority, isNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject invalid priority string', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: 'P4');

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('must be P0, P1, P2, or P3'));
        expect(result.error, contains('P4'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject text priority values', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: 'urgent');

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('urgent'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject empty priority string', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: '');

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test(
        'should handle non-string priority type (integer) gracefully',
        () async {
          // AI might send {"priority": 1} instead of {"priority": "P1"}
          final task = createTask();
          const toolCall = ChatCompletionMessageToolCall(
            id: 'call_priority_123',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_priority',
              arguments:
                  '{"priority": 1, "reason": "test", "confidence": "high"}',
            ),
          );

          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          // Should fail validation (1 != "P1") but not throw
          expect(result.success, isFalse);
          expect(result.wasSkipped, isFalse);
          expect(result.error, isNotNull);
          expect(result.error, contains('must be P0, P1, P2, or P3'));

          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test(
        'should handle non-string confidence/reason types gracefully',
        () async {
          // AI might send non-string values for optional fields
          final task = createTask();
          const toolCall = ChatCompletionMessageToolCall(
            id: 'call_priority_123',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'update_task_priority',
              arguments:
                  '{"priority": "P1", "reason": 123, "confidence": true}',
            ),
          );

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          // Should succeed - non-string values are converted via toString()
          expect(result.success, isTrue);
          expect(result.reason, '123');
          expect(result.confidence, 'true');

          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        },
      );

      test('should handle malformed JSON', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_priority_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_priority',
            arguments: 'not valid json',
          ),
        );

        final handler = TaskPriorityHandler(
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
            toolCallId: 'call_priority_123',
            response: 'Error processing task priority update.',
          ),
        ).called(1);
      });
    });

    group('repository errors', () {
      test('should handle repository failure gracefully', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: 'P1');

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('Database connection lost'));

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.wasSkipped, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('Database connection lost'));
        expect(result.requestedPriority, TaskPriority.p1High);
        expect(result.updatedTask, isNull);

        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_priority_123',
            response:
                'Failed to set priority. Continuing without priority update.',
          ),
        ).called(1);
      });

      test('should not call onTaskUpdated when repository fails', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: 'P1');

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('Database error'));

        var callbackCalled = false;
        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });

      test(
        'should not update handler task reference when repository fails',
        () async {
          final task = createTask();
          final toolCall = createPriorityToolCall(priority: 'P1');

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenThrow(Exception('Database error'));

          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          await handler.processToolCall(toolCall);

          // Task should remain unchanged
          expect(handler.task.data.priority, TaskPriority.p2Medium);
        },
      );
    });

    glados.Glados(
      glados.any.priorityToolCallScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated priority parsing, no-op, and repository semantics',
      (scenario) async {
        final repo = MockJournalRepository();
        when(
          () => repo.updateJournalEntity(any()),
        ).thenAnswer((_) async => scenario.repositorySucceeds);

        final initialTask = createTask(priority: scenario.currentPriority);
        Task? callbackTask;
        final handler = TaskPriorityHandler(
          task: initialTask,
          journalRepository: repo,
          onTaskUpdated: (updatedTask) => callbackTask = updatedTask,
        );

        final result = await handler.processToolCall(
          createPriorityToolCallFromArgs(scenario.arguments),
        );

        if (scenario.isInvalid) {
          expect(result.success, isFalse, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(result.requestedPriority, isNull, reason: '$scenario');
          expect(result.error, contains('must be P0'), reason: '$scenario');
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          verifyNever(() => repo.updateJournalEntity(any()));
          return;
        }

        expect(result.requestedPriority, scenario.parsedPriority);
        expect(result.reason, 'Generated reason ${scenario.seed}');
        expect(result.confidence, scenario.seed.isEven ? 'high' : 'medium');

        if (scenario.isNoOp) {
          expect(result.success, isTrue, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(result.wasNoOp, isTrue, reason: '$scenario');
          expect(result.updatedTask, initialTask, reason: '$scenario');
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          verifyNever(() => repo.updateJournalEntity(any()));
          return;
        }

        expect(scenario.shouldAttemptWrite, isTrue, reason: '$scenario');
        final captured =
            verify(
                  () => repo.updateJournalEntity(captureAny()),
                ).captured.single
                as Task;
        expect(
          captured.data.priority,
          scenario.parsedPriority,
          reason: '$scenario',
        );

        if (!scenario.repositorySucceeds) {
          expect(result.success, isFalse, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(result.error, contains('repository returned false'));
          expect(result.updatedTask, isNull, reason: '$scenario');
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          return;
        }

        expect(result.success, isTrue, reason: '$scenario');
        expect(result.didWrite, isTrue, reason: '$scenario');
        expect(result.wasNoOp, isFalse, reason: '$scenario');
        expect(result.updatedTask, captured, reason: '$scenario');
        expect(handler.task, captured, reason: '$scenario');
        expect(callbackTask, captured, reason: '$scenario');
      },
      tags: 'glados',
    );

    group('TaskPriorityResult', () {
      test('wasSkipped returns true for non-error failures', () {
        const result = TaskPriorityResult(
          success: false,
          message: 'Already set',
          requestedPriority: TaskPriority.p1High,
        );

        expect(result.wasSkipped, isTrue);
      });

      test('wasSkipped returns false when error is present', () {
        const result = TaskPriorityResult(
          success: false,
          message: 'Invalid input',
          error: 'priority must be P0, P1, P2, or P3',
        );

        expect(result.wasSkipped, isFalse);
      });

      test('wasSkipped returns false when success is true', () {
        const result = TaskPriorityResult(
          success: true,
          message: 'Updated',
          requestedPriority: TaskPriority.p1High,
        );

        expect(result.wasSkipped, isFalse);
      });
    });

    group('edge cases', () {
      test(
        'should preserve other task fields when updating priority',
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
              estimate: const Duration(minutes: 60),
              // priority is default p2Medium
            ),
          );
          final toolCall = createPriorityToolCall(priority: 'P0');

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final handler = TaskPriorityHandler(
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
          expect(updated.data.priority, TaskPriority.p0Urgent);
          expect(updated.meta.id, 'test-task-id');
        },
      );

      test('should handle priority with whitespace', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(priority: '  P1  ');

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedPriority, TaskPriority.p1High);
      });

      test(
        'should skip DB write when setting P2 on default P2 task (no-op optimization)',
        () async {
          // This is an edge case: user says "medium priority" and task is already p2Medium
          // We skip the DB write since nothing would actually change
          final task = createTask(); // default is p2Medium
          final toolCall = createPriorityToolCall(priority: 'P2');

          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          // Should succeed but NOT call updateJournalEntity (optimization)
          expect(result.success, isTrue);
          expect(result.requestedPriority, TaskPriority.p2Medium);
          expect(result.updatedTask!.data.priority, TaskPriority.p2Medium);
          expect(result.message, contains('No change needed'));

          // Verify no DB write occurred
          verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
        },
      );

      test('should handle all valid priority values sequentially', () async {
        for (final priorityStr in ['P0', 'P1', 'P2', 'P3']) {
          final task = createTask(); // fresh task with default priority
          final toolCall = createPriorityToolCall(priority: priorityStr);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final handler = TaskPriorityHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.processToolCall(toolCall);

          expect(result.success, isTrue, reason: 'Failed for $priorityStr');
          expect(
            result.requestedPriority,
            TaskPriorityHandler.parsePriority(priorityStr),
            reason: 'Failed for $priorityStr',
          );
        }
      });
    });

    group('confidence and reason handling', () {
      test('should capture high confidence', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(
          priority: 'P0',
          confidence: 'high',
          reason: 'User explicitly said P0',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.confidence, 'high');
        expect(result.reason, 'User explicitly said P0');
      });

      test('should capture medium confidence', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(
          priority: 'P1',
          confidence: 'medium',
          reason: 'User implied importance',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.confidence, 'medium');
        expect(result.reason, 'User implied importance');
      });

      test('should capture low confidence', () async {
        final task = createTask();
        final toolCall = createPriorityToolCall(
          priority: 'P3',
          confidence: 'low',
          reason: 'Uncertain about priority level',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.confidence, 'low');
        expect(result.reason, 'Uncertain about priority level');
      });

      test('should work without optional fields', () async {
        final task = createTask();
        // Only required field: priority
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_priority_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_priority',
            arguments: '{"priority": "P1"}',
          ),
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskPriorityHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.confidence, isNull);
        expect(result.reason, isNull);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Dedicated Glados property tests for parsePriority (pure function)
  // ---------------------------------------------------------------------------

  group('parsePriority — Glados properties', () {
    // Property 1: result is always within the 4-value set (or null).
    glados.Glados(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always a valid TaskPriority or null',
      (s) {
        final result = TaskPriorityHandler.parsePriority(s);
        if (result != null) {
          expect(
            TaskPriority.values,
            contains(result),
            reason: 'parsePriority($s) produced an unexpected value',
          );
        }
      },
      tags: 'glados',
    );

    // Property 2: round-trip idempotence — parse the short form of a result
    // and get the same result back.
    glados.Glados(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'parsePriority is idempotent on its own output short form',
      (s) {
        final first = TaskPriorityHandler.parsePriority(s);
        if (first != null) {
          final second = TaskPriorityHandler.parsePriority(first.short);
          expect(
            second,
            equals(first),
            reason:
                'parsePriority(first.short) must equal first for input $s',
          );
        }
      },
      tags: 'glados',
    );

    // Static worked examples — exact canonical inputs.
    group('parsePriority — static examples', () {
      for (final (input, expected) in [
        ('P0', TaskPriority.p0Urgent),
        ('P1', TaskPriority.p1High),
        ('P2', TaskPriority.p2Medium),
        ('P3', TaskPriority.p3Low),
        ('p0', TaskPriority.p0Urgent),
        ('p1', TaskPriority.p1High),
        ('p2', TaskPriority.p2Medium),
        ('p3', TaskPriority.p3Low),
        ('  P2  ', TaskPriority.p2Medium),
      ]) {
        test('parses "$input" to $expected', () {
          expect(
            TaskPriorityHandler.parsePriority(input),
            equals(expected),
            reason: 'input: "$input"',
          );
        });
      }

      for (final invalid in ['P4', 'P5', 'URGENT', '', 'high', '1']) {
        test('returns null for invalid input "$invalid"', () {
          expect(
            TaskPriorityHandler.parsePriority(invalid),
            isNull,
            reason: '"$invalid" must not parse to a priority',
          );
        });
      }

      test('returns null for null input', () {
        expect(TaskPriorityHandler.parsePriority(null), isNull);
      });

      test('returns null for non-string input (int)', () {
        expect(TaskPriorityHandler.parsePriority(42), isNull);
      });
    });
  });
}
