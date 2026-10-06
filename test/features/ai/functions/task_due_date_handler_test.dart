import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/functions/task_due_date_handler.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_utils/glados_generators.dart';

enum _GeneratedCurrentDueDateKind { none, same, different }

enum _GeneratedDueDateRequestShape {
  dateOnly,
  missing,
  empty,
  partial,
  fullIso,
}

class _GeneratedDueDateToolCallScenario {
  const _GeneratedDueDateToolCallScenario({
    required this.currentKind,
    required this.requestShape,
    required this.year,
    required this.month,
    required this.day,
    required this.repositorySucceeds,
    required this.seed,
  });

  final _GeneratedCurrentDueDateKind currentKind;
  final _GeneratedDueDateRequestShape requestShape;
  final int year;
  final int month;
  final int day;
  final bool repositorySucceeds;
  final int seed;

  String get dateOnly =>
      '${fourDigits(year)}-${twoDigits(month)}-${twoDigits(day)}';

  String? get rawDueDate {
    return switch (requestShape) {
      _GeneratedDueDateRequestShape.dateOnly => dateOnly,
      _GeneratedDueDateRequestShape.missing => null,
      _GeneratedDueDateRequestShape.empty => '',
      _GeneratedDueDateRequestShape.partial =>
        '${fourDigits(year)}-${twoDigits(month)}',
      _GeneratedDueDateRequestShape.fullIso => '${dateOnly}T10:30:00',
    };
  }

  DateTime? get parsedDate {
    if (requestShape != _GeneratedDueDateRequestShape.dateOnly) {
      return null;
    }
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > daysInMonth(year, month)) return null;
    return DateTime(year, month, day);
  }

  DateTime? get currentDue {
    final date = parsedDate;
    if (date == null || currentKind == _GeneratedCurrentDueDateKind.none) {
      return null;
    }
    if (currentKind == _GeneratedCurrentDueDateKind.same) {
      return date;
    }
    return date.add(const Duration(days: 1));
  }

  bool get isMissingOrEmpty =>
      requestShape == _GeneratedDueDateRequestShape.missing ||
      requestShape == _GeneratedDueDateRequestShape.empty;

  bool get isInvalid => parsedDate == null;

  bool get isNoOp =>
      parsedDate != null &&
      currentDue != null &&
      currentDue!.year == parsedDate!.year &&
      currentDue!.month == parsedDate!.month &&
      currentDue!.day == parsedDate!.day;

  bool get shouldAttemptWrite => !isInvalid && !isNoOp;

  bool get shouldWrite => shouldAttemptWrite && repositorySucceeds;

  Map<String, Object?> get arguments => {
    if (requestShape != _GeneratedDueDateRequestShape.missing)
      'dueDate': rawDueDate,
    'reason': 'Generated reason $seed',
    'confidence': seed.isEven ? 'high' : 'medium',
  };

  @override
  String toString() {
    return '_GeneratedDueDateToolCallScenario('
        'currentKind: $currentKind, '
        'requestShape: $requestShape, '
        'dateOnly: $dateOnly, '
        'repositorySucceeds: $repositorySucceeds, '
        'seed: $seed)';
  }
}

extension _AnyTaskDueDateHandlerScenario on glados.Any {
  glados.Generator<_GeneratedCurrentDueDateKind> get currentDueDateKind =>
      glados.AnyUtils(this).choose(_GeneratedCurrentDueDateKind.values);

  glados.Generator<_GeneratedDueDateRequestShape> get dueDateRequestShape =>
      glados.AnyUtils(this).choose(_GeneratedDueDateRequestShape.values);

  glados.Generator<_GeneratedDueDateToolCallScenario>
  get dueDateToolCallScenario => glados.CombinableAny(this).combine7(
    currentDueDateKind,
    dueDateRequestShape,
    glados.IntAnys(this).intInRange(2023, 2027),
    glados.IntAnys(this).intInRange(0, 15),
    glados.IntAnys(this).intInRange(0, 36),
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 10000),
    (
      _GeneratedCurrentDueDateKind currentKind,
      _GeneratedDueDateRequestShape requestShape,
      int year,
      int month,
      int day,
      bool repositorySucceeds,
      int seed,
    ) => _GeneratedDueDateToolCallScenario(
      currentKind: currentKind,
      requestShape: requestShape,
      year: year,
      month: month,
      day: day,
      repositorySucceeds: repositorySucceeds,
      seed: seed,
    ),
  );
}

void main() {
  late MockJournalRepository mockJournalRepo;
  late MockDomainLogger mockLogger;
  late MockConversationManager mockManager;

  // Fixed date for deterministic tests - per test/README.md policy
  final fixedDate = DateTime(2024, 1, 15);

  setUpAll(() {
    registerAllFallbackValues();
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
    mockLogger = MockDomainLogger();
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
          'reason': ?reason,
          'confidence': ?confidence,
        }),
      ),
    );
  }

  ChatCompletionMessageToolCall createDueDateToolCallFromArgs(
    Map<String, Object?> args,
  ) {
    return ChatCompletionMessageToolCall(
      id: 'call_due_date_generated',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_due_date',
        arguments: jsonEncode(args),
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

        stubTaskRow(mockJournalRepo, task);

        Task? capturedTask;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
          onTaskUpdated: (t) => capturedTask = t,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(handler.task.data.due, DateTime(2024, 1, 19));
        expect(result.error, isNull);

        expect(capturedTask, isNotNull);
        expect(capturedTask!.data.due, DateTime(2024, 1, 19));

        verify(() => mockJournalRepo.updateTask(any(), any())).called(1);
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

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        expect(handler.task.data.due, isNull);

        await handler.processToolCall(toolCall, mockManager);

        expect(handler.task.data.due, DateTime(2024, 2));
      });

      test(
        'should work without ConversationManager (for unit testing)',
        () async {
          final task = createTask();
          final toolCall = createDueDateToolCall(dueDate: '2024-03-15');

          stubTaskRow(mockJournalRepo, task);

          final handler = TaskDueDateHandler(
            task: task,
            journalRepository: mockJournalRepo,
            domainLogger: mockLogger,
          );

          // Call without manager
          final result = await handler.processToolCall(toolCall);

          expect(result.success, isTrue);
          expect(handler.task.data.due, DateTime(2024, 3, 15));
          verify(() => mockJournalRepo.updateTask(any(), any())).called(1);
          // Manager methods should not be called
          verifyNever(
            () => mockManager.addToolResponse(
              toolCallId: any(named: 'toolCallId'),
              response: any(named: 'response'),
            ),
          );
        },
      );

      test('should accept past due dates', () async {
        final task = createTask();
        // Date before fixedDate (2024-01-15)
        final toolCall = createDueDateToolCall(
          dueDate: '2024-01-10',
          reason: 'Task was due last week',
        );

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(handler.task.data.due, DateTime(2024, 1, 10));
        expect(handler.task.data.due, DateTime(2024, 1, 10));
      });
    });

    group('no-op when same due date', () {
      test('should no-op when requested date matches current', () async {
        final task = createTask(due: DateTime(2024, 1, 20));
        final toolCall = createDueDateToolCall(
          dueDate: '2024-01-20',
          reason: 'Confirming date',
          confidence: 'high',
        );

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(handler.task.data.due, DateTime(2024, 1, 20));
        expect(result.message, contains('No change needed'));

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
      });

      test('should not call onTaskUpdated when same date', () async {
        final task = createTask(due: DateTime(2024, 1, 22));
        final toolCall = createDueDateToolCall(dueDate: '2024-01-22');

        var callbackCalled = false;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });
    });

    group('updates existing due date to different value', () {
      test('should update when requested date differs from current', () async {
        final task = createTask(due: DateTime(2024, 1, 20));
        final toolCall = createDueDateToolCall(
          dueDate: '2024-01-25',
          reason: 'User mentioned next Friday',
          confidence: 'high',
        );

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(handler.task.data.due, DateTime(2024, 1, 25));
        expect(handler.task.data.due, DateTime(2024, 1, 25));

        verify(() => mockJournalRepo.updateTask(any(), any())).called(1);
      });
    });

    group('isValidDueDateWireValue', () {
      test('accepts exactly YYYY-MM-DD encoding a real calendar date', () {
        expect(isValidDueDateWireValue('2026-08-01'), isTrue);
        expect(isValidDueDateWireValue('2024-02-29'), isTrue); // leap day
      });

      test('rejects every other shape the handler rejects', () {
        // Shared with the render-time proposal summary: a value rejected here
        // must never be prettified into a plausible-looking date in a row.
        expect(isValidDueDateWireValue('2026-08-01T12:00:00'), isFalse);
        expect(isValidDueDateWireValue('01-08-2026'), isFalse);
        expect(isValidDueDateWireValue('next Tuesday'), isFalse);
        expect(isValidDueDateWireValue(''), isFalse);
        // Parseable overflow — DateTime rolls Feb 31 into March, but the
        // handler refuses it, so the round-trip check must too.
        expect(isValidDueDateWireValue('2026-02-31'), isFalse);
        expect(isValidDueDateWireValue('2023-02-29'), isFalse); // no leap day
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
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('date string is required'));
        expect(handler.task.data.due, isNull);

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
      });

      test('should reject empty dueDate string', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '');

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('date string is required'));

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
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
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('YYYY-MM-DD'));
        expect(handler.task.data.due, isNull);

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
      });

      test('should reject partial date format', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01');

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('YYYY-MM-DD'));

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
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
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
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

        when(
          () => mockJournalRepo.updateTask(any(), any()),
        ).thenThrow(Exception('Database connection lost'));

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('Database connection lost'));
        expect(handler.task, same(task));
        verify(
          () => mockLogger.error(
            LogDomain.ai,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'TaskDueDateHandler',
            message: 'Failed to update task due date',
          ),
        ).called(1);

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

        when(
          () => mockJournalRepo.updateTask(any(), any()),
        ).thenThrow(Exception('Database error'));

        var callbackCalled = false;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        await handler.processToolCall(toolCall, mockManager);

        expect(callbackCalled, isFalse);
      });

      test(
        'should not update handler task reference when repository fails',
        () async {
          final task = createTask();
          final toolCall = createDueDateToolCall(dueDate: '2024-01-25');

          when(
            () => mockJournalRepo.updateTask(any(), any()),
          ).thenThrow(Exception('Database error'));

          final handler = TaskDueDateHandler(
            task: task,
            journalRepository: mockJournalRepo,
            domainLogger: mockLogger,
          );

          await handler.processToolCall(toolCall);

          // Task should remain unchanged
          expect(handler.task.data.due, isNull);
        },
      );
    });

    glados.Glados(
      glados.any.dueDateToolCallScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated due-date validation, no-op, and repository semantics',
      (scenario) async {
        final repo = MockJournalRepository();
        final initialTask = createTask(due: scenario.currentDue);
        final row = stubTaskRow(repo, initialTask);
        if (!scenario.repositorySucceeds) {
          when(
            () => repo.updateTask(any(), any()),
          ).thenAnswer((_) async => null);
        }
        Task? callbackTask;
        final handler = TaskDueDateHandler(
          task: initialTask,
          journalRepository: repo,
          domainLogger: mockLogger,
          onTaskUpdated: (updatedTask) => callbackTask = updatedTask,
        );

        final result = await handler.processToolCall(
          createDueDateToolCallFromArgs(scenario.arguments),
        );

        if (scenario.isInvalid) {
          expect(result.success, isFalse, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(handler.task.data.due, isNull, reason: '$scenario');
          expect(
            result.error,
            scenario.isMissingOrEmpty
                ? contains('date string is required')
                : contains('YYYY-MM-DD'),
            reason: '$scenario',
          );
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          verifyNever(() => repo.updateTask(any(), any()));
          return;
        }

        if (scenario.isNoOp) {
          expect(result.success, isTrue, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          verifyNever(() => repo.updateTask(any(), any()));
          return;
        }

        expect(scenario.shouldAttemptWrite, isTrue, reason: '$scenario');
        final change =
            verify(
                  () => repo.updateTask(initialTask.id, captureAny()),
                ).captured.single
                as TaskData Function(TaskData);
        expect(
          change(initialTask.data).due,
          scenario.parsedDate,
          reason: '$scenario',
        );

        if (!scenario.repositorySucceeds) {
          expect(result.success, isFalse, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(result.error, contains('repository returned false'));
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          return;
        }

        final written = row.writes.single;
        expect(
          written.data,
          initialTask.data.copyWith(due: scenario.parsedDate),
          reason: '$scenario',
        );
        expect(result.success, isTrue, reason: '$scenario');
        expect(result.didWrite, isTrue, reason: '$scenario');
        expect(handler.task, written, reason: '$scenario');
        expect(callbackTask, written, reason: '$scenario');
      },
      tags: 'glados',
    );

    group('date format variations', () {
      test(
        'should reject full ISO 8601 datetime (requires date-only)',
        () async {
          final task = createTask();
          // Datetime format should be rejected - we require YYYY-MM-DD only
          final toolCall = createDueDateToolCall(
            dueDate: '2024-01-19T10:30:00',
          );

          final handler = TaskDueDateHandler(
            task: task,
            journalRepository: mockJournalRepo,
            domainLogger: mockLogger,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          expect(result.error, contains('YYYY-MM-DD'));

          verifyNever(() => mockJournalRepo.updateTask(any(), any()));
        },
      );

      test(
        'should reject ISO 8601 with timezone (requires date-only)',
        () async {
          final task = createTask();
          final toolCall = createDueDateToolCall(
            dueDate: '2024-01-19T10:30:00Z',
          );

          final handler = TaskDueDateHandler(
            task: task,
            journalRepository: mockJournalRepo,
            domainLogger: mockLogger,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          expect(result.error, contains('YYYY-MM-DD'));

          verifyNever(() => mockJournalRepo.updateTask(any(), any()));
        },
      );

      test('should handle date at year boundary', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-12-31');

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(handler.task.data.due, DateTime(2024, 12, 31));
      });

      test('should handle leap year date', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-02-29');

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(handler.task.data.due, DateTime(2024, 2, 29));
      });

      test('should normalize to midnight', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2024-01-19');

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        // Date should be normalized to midnight (00:00:00)
        expect(handler.task.data.due, DateTime(2024, 1, 19));
        expect(handler.task.data.due!.hour, 0);
        expect(handler.task.data.due!.minute, 0);
        expect(handler.task.data.due!.second, 0);
      });
    });

    group('field changed since the call read the task', () {
      test(
        'writes on the task as stored, keeping a field set meanwhile',
        () async {
          final task = createTask();
          final row = stubTaskRow(mockJournalRepo, task)
            ..task = task.copyWith(
              data: task.data.copyWith(priority: TaskPriority.p0Urgent),
            );
          Task? callbackTask;
          final handler = TaskDueDateHandler(
            task: task,
            journalRepository: mockJournalRepo,
            domainLogger: mockLogger,
            onTaskUpdated: (t) => callbackTask = t,
          );

          final result = await handler.processToolCall(
            createDueDateToolCall(dueDate: '2024-01-19'),
            mockManager,
          );

          expect(result.didWrite, isTrue);
          final written = row.writes.single;
          expect(written.data.due, DateTime(2024, 1, 19));
          expect(written.data.priority, TaskPriority.p0Urgent);
          expect(handler.task, written);
          expect(callbackTask, written);
        },
      );

      test('applies nothing when the stored due changed', () async {
        final task = createTask();
        final row = stubTaskRow(mockJournalRepo, task)
          ..task = task.copyWith(
            data: task.data.copyWith(due: DateTime(2024, 2)),
          );
        final stored = row.task;
        var callbackCalled = false;
        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
          onTaskUpdated: (_) => callbackCalled = true,
        );

        final result = await handler.processToolCall(
          createDueDateToolCall(dueDate: '2024-01-19'),
          mockManager,
        );

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.error, isNull);
        expect(result.message, startsWith('Nothing applied'));
        expect(row.writes, isEmpty);
        expect(row.task.data.due, DateTime(2024, 2));
        expect(handler.task, stored);
        expect(callbackCalled, isFalse);
        verify(
          () => mockManager.addToolResponse(
            toolCallId: 'call_due_date_456',
            response: result.message,
          ),
        ).called(1);
      });
    });

    group('edge cases', () {
      test(
        'should preserve other task fields when updating due date',
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

          stubTaskRow(mockJournalRepo, task);

          final handler = TaskDueDateHandler(
            task: task,
            journalRepository: mockJournalRepo,
            domainLogger: mockLogger,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          expect(result.success, isTrue);
          final updated = handler.task;
          expect(updated.data.title, 'Important Task');
          expect(updated.data.status.id, 'status-2');
          expect(updated.data.estimate, const Duration(minutes: 60));
          expect(updated.data.due, DateTime(2024, 1, 25));
          expect(updated.meta.id, 'test-task-id');
        },
      );

      test('should handle date far in the future', () async {
        final task = createTask();
        final toolCall = createDueDateToolCall(dueDate: '2030-12-31');

        stubTaskRow(mockJournalRepo, task);

        final handler = TaskDueDateHandler(
          task: task,
          journalRepository: mockJournalRepo,
          domainLogger: mockLogger,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(handler.task.data.due, DateTime(2030, 12, 31));
      });
    });
  });
}
