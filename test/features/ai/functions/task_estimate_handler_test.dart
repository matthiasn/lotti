import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/functions/task_estimate_handler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedCurrentEstimateKind { none, zero, same, different }

enum _GeneratedEstimateRequestShape {
  intValue,
  doubleValue,
  numericString,
  missing,
  zero,
  negative,
  tooHigh,
  nonNumericString,
}

class _GeneratedEstimateToolCallScenario {
  const _GeneratedEstimateToolCallScenario({
    required this.currentKind,
    required this.requestShape,
    required this.value,
    required this.repositorySucceeds,
    required this.seed,
  });

  final _GeneratedCurrentEstimateKind currentKind;
  final _GeneratedEstimateRequestShape requestShape;
  final int value;
  final bool repositorySucceeds;
  final int seed;

  int get validMinutes => (value % maxEstimateMinutes) + 1;

  Object? get rawMinutes {
    return switch (requestShape) {
      _GeneratedEstimateRequestShape.intValue => validMinutes,
      _GeneratedEstimateRequestShape.doubleValue => validMinutes + 0.25,
      _GeneratedEstimateRequestShape.numericString => '$validMinutes',
      _GeneratedEstimateRequestShape.missing => null,
      _GeneratedEstimateRequestShape.zero => 0,
      _GeneratedEstimateRequestShape.negative => -validMinutes,
      _GeneratedEstimateRequestShape.tooHigh =>
        maxEstimateMinutes + validMinutes,
      _GeneratedEstimateRequestShape.nonNumericString => 'two hours $seed',
    };
  }

  int? get parsedMinutes => switch (requestShape) {
    _GeneratedEstimateRequestShape.intValue => validMinutes,
    _GeneratedEstimateRequestShape.doubleValue => validMinutes,
    _GeneratedEstimateRequestShape.numericString => validMinutes,
    _ => null,
  };

  Duration? get currentEstimate {
    final parsed = parsedMinutes;
    return switch (currentKind) {
      _GeneratedCurrentEstimateKind.none => null,
      _GeneratedCurrentEstimateKind.zero => Duration.zero,
      _GeneratedCurrentEstimateKind.same when parsed != null => Duration(
        minutes: parsed,
      ),
      _GeneratedCurrentEstimateKind.same => null,
      _GeneratedCurrentEstimateKind.different when parsed != null => Duration(
        minutes: parsed == maxEstimateMinutes ? parsed - 1 : parsed + 1,
      ),
      _GeneratedCurrentEstimateKind.different => const Duration(minutes: 17),
    };
  }

  bool get isInvalid => parsedMinutes == null;

  bool get isNoOp =>
      parsedMinutes != null &&
      currentEstimate != null &&
      currentEstimate!.inMinutes == parsedMinutes;

  bool get shouldAttemptWrite => !isInvalid && !isNoOp;

  bool get shouldWrite => shouldAttemptWrite && repositorySucceeds;

  Map<String, Object?> get arguments => {
    if (requestShape != _GeneratedEstimateRequestShape.missing)
      'minutes': rawMinutes,
    'reason': 'Generated reason $seed',
    'confidence': seed.isEven ? 'high' : 'medium',
  };

  @override
  String toString() {
    return '_GeneratedEstimateToolCallScenario('
        'currentKind: $currentKind, '
        'requestShape: $requestShape, '
        'value: $value, '
        'repositorySucceeds: $repositorySucceeds, '
        'seed: $seed)';
  }
}

extension _AnyTaskEstimateHandlerScenario on glados.Any {
  glados.Generator<_GeneratedCurrentEstimateKind> get currentEstimateKind =>
      glados.AnyUtils(this).choose(_GeneratedCurrentEstimateKind.values);

  glados.Generator<_GeneratedEstimateRequestShape> get estimateRequestShape =>
      glados.AnyUtils(this).choose(_GeneratedEstimateRequestShape.values);

  glados.Generator<_GeneratedEstimateToolCallScenario>
  get estimateToolCallScenario => glados.CombinableAny(this).combine5(
    currentEstimateKind,
    estimateRequestShape,
    glados.IntAnys(this).intInRange(0, 10000),
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 10000),
    (
      _GeneratedCurrentEstimateKind currentKind,
      _GeneratedEstimateRequestShape requestShape,
      int value,
      bool repositorySucceeds,
      int seed,
    ) => _GeneratedEstimateToolCallScenario(
      currentKind: currentKind,
      requestShape: requestShape,
      value: value,
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
          'reason': ?reason,
          'confidence': ?confidence,
        }),
      ),
    );
  }

  ChatCompletionMessageToolCall createEstimateToolCallFromArgs(
    Map<String, Object?> args,
  ) {
    return ChatCompletionMessageToolCall(
      id: 'call_estimate_generated',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'update_task_estimate',
        arguments: jsonEncode(args),
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

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

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

      test(
        'should update estimate when currently zero (treat as not set)',
        () async {
          final task = createTask(estimate: Duration.zero);
          final toolCall = createEstimateToolCall(minutes: 60);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final handler = TaskEstimateHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.processToolCall(toolCall, mockManager);

          expect(result.success, isTrue);
          expect(result.requestedMinutes, 60);
          expect(
            result.updatedTask!.data.estimate,
            const Duration(minutes: 60),
          );

          verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
        },
      );

      test('should update handler task reference after success', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 90);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.estimate, isNull);

        await handler.processToolCall(toolCall, mockManager);

        expect(handler.task.data.estimate, const Duration(minutes: 90));
      });

      test(
        'should work without ConversationManager (for unit testing)',
        () async {
          final task = createTask();
          final toolCall = createEstimateToolCall(minutes: 45);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

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
        },
      );
    });

    group('no-op when same estimate', () {
      test('should no-op when requested minutes match current', () async {
        final task = createTask(estimate: const Duration(minutes: 60));
        final toolCall = createEstimateToolCall(
          minutes: 60,
          reason: 'Confirming estimate',
          confidence: 'high',
        );

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.wasNoOp, isTrue);
        expect(result.requestedMinutes, 60);
        expect(result.message, contains('No change needed'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should not call onTaskUpdated when same estimate', () async {
        final task = createTask(estimate: const Duration(minutes: 30));
        final toolCall = createEstimateToolCall(minutes: 30);

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

    group('updates existing estimate to different value', () {
      test('should update when requested minutes differ', () async {
        final task = createTask(estimate: const Duration(minutes: 60));
        final toolCall = createEstimateToolCall(
          minutes: 120,
          reason: 'User mentioned 2 hours',
          confidence: 'high',
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.requestedMinutes, 120);
        expect(
          result.updatedTask!.data.estimate,
          const Duration(minutes: 120),
        );

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
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

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('should reject minutes exceeding max bound', () async {
        final task = createTask();
        // Create tool call with minutes > maxEstimateMinutes (1440)
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_estimate_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_estimate',
            arguments: '{"minutes": 999999}',
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
        expect(result.error, contains('1440'));

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

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('Database connection lost'));

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

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('Database error'));

        var callbackCalled = false;
        final handler = TaskEstimateHandler(
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
          final toolCall = createEstimateToolCall(minutes: 90);

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenThrow(Exception('Database error'));

          final handler = TaskEstimateHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          await handler.processToolCall(toolCall);

          // Task should remain unchanged
          expect(handler.task.data.estimate, isNull);
        },
      );
    });

    glados.Glados(
      glados.any.estimateToolCallScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated estimate validation, no-op, and repository semantics',
      (scenario) async {
        final repo = MockJournalRepository();
        when(
          () => repo.updateJournalEntity(any()),
        ).thenAnswer((_) async => scenario.repositorySucceeds);

        final initialTask = createTask(estimate: scenario.currentEstimate);
        Task? callbackTask;
        final handler = TaskEstimateHandler(
          task: initialTask,
          journalRepository: repo,
          onTaskUpdated: (updatedTask) => callbackTask = updatedTask,
        );

        final result = await handler.processToolCall(
          createEstimateToolCallFromArgs(scenario.arguments),
        );

        if (scenario.isInvalid) {
          expect(result.success, isFalse, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(
            result.requestedMinutes,
            scenario.rawMinutes is int ? scenario.rawMinutes : null,
            reason: '$scenario',
          );
          expect(
            result.error,
            contains('positive integer'),
            reason: '$scenario',
          );
          expect(handler.task, initialTask, reason: '$scenario');
          expect(callbackTask, isNull, reason: '$scenario');
          verifyNever(() => repo.updateJournalEntity(any()));
          return;
        }

        expect(result.requestedMinutes, scenario.parsedMinutes);
        expect(result.reason, 'Generated reason ${scenario.seed}');
        expect(result.confidence, scenario.seed.isEven ? 'high' : 'medium');

        if (scenario.isNoOp) {
          expect(result.success, isTrue, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(result.wasNoOp, isTrue, reason: '$scenario');
          expect(result.updatedTask, isNull, reason: '$scenario');
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
          captured.data.estimate,
          Duration(minutes: scenario.parsedMinutes!),
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
      test('should handle max allowed minute value (24 hours)', () async {
        final task = createTask();
        // 24 hours in minutes (max allowed)
        final toolCall = createEstimateToolCall(minutes: 1440);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 1440);
        expect(
          result.updatedTask!.data.estimate,
          const Duration(minutes: 1440),
        );
      });

      test('should handle 1 minute estimate', () async {
        final task = createTask();
        final toolCall = createEstimateToolCall(minutes: 1);

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 1);
        expect(result.updatedTask!.data.estimate, const Duration(minutes: 1));
      });

      test(
        'should preserve other task fields when updating estimate',
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

          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

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
        },
      );

      test('should accept double minutes (rounded)', () async {
        final task = createTask();
        // AI might send 120.0 instead of 120
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_estimate_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_estimate',
            arguments: '{"minutes": 120.5}',
          ),
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 121); // rounded from 120.5
        expect(
          result.updatedTask!.data.estimate,
          const Duration(minutes: 121),
        );
      });

      test('should accept string minutes', () async {
        final task = createTask();
        // AI might send "90" as a string
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_estimate_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_estimate',
            arguments: '{"minutes": "90"}',
          ),
        );

        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isTrue);
        expect(result.requestedMinutes, 90);
        expect(result.updatedTask!.data.estimate, const Duration(minutes: 90));
      });

      test('should reject non-numeric string minutes', () async {
        final task = createTask();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call_estimate_123',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'update_task_estimate',
            arguments: '{"minutes": "two hours"}',
          ),
        );

        final handler = TaskEstimateHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.processToolCall(toolCall, mockManager);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('two hours'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Dedicated Glados property tests for parseMinutes (pure function)
  // ---------------------------------------------------------------------------

  group('parseMinutes — Glados properties', () {
    // Property 1: valid int in [1, maxEstimateMinutes] round-trips unchanged.
    glados.Glados(
      glados.any.intInRange(1, maxEstimateMinutes),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'int value in valid range is returned as-is',
      (v) {
        expect(
          parseMinutes(v),
          equals(v),
          reason: 'valid int $v must parse to itself',
        );
      },
      tags: 'glados',
    );

    // Property 2: double whose round() is in range is accepted and rounded.
    glados.Glados(
      glados.any.intInRange(1, maxEstimateMinutes),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'double value whose round() is in valid range is accepted and rounded',
      (v) {
        // Use v + 0.25 so the double rounds down to v — still in range.
        final d = v + 0.25;
        expect(
          parseMinutes(d),
          equals(v),
          reason: 'double $d must round to $v',
        );
      },
      tags: 'glados',
    );

    // Property 3: numeric string in valid range is accepted.
    glados.Glados(
      glados.any.intInRange(1, maxEstimateMinutes),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'numeric string in valid range is accepted',
      (v) {
        expect(
          parseMinutes('$v'),
          equals(v),
          reason: 'numeric string "$v" must parse to $v',
        );
      },
      tags: 'glados',
    );

    // Property 4: any value <= 0 is rejected (returns null).
    glados.Glados(
      glados.any.intInRange(-1000, 0),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'non-positive int is rejected',
      (v) {
        expect(
          parseMinutes(v),
          isNull,
          reason: 'non-positive value $v must return null',
        );
      },
      tags: 'glados',
    );

    // Property 5: any value > maxEstimateMinutes is rejected.
    glados.Glados(
      glados.any.intInRange(maxEstimateMinutes + 1, maxEstimateMinutes + 5000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'int above maxEstimateMinutes is rejected',
      (v) {
        expect(
          parseMinutes(v),
          isNull,
          reason: 'out-of-range value $v must return null',
        );
      },
      tags: 'glados',
    );

    // Property 6: null input always returns null.
    test('null input returns null', () {
      expect(parseMinutes(null), isNull);
    });

    // Property 7: returned value, when non-null, is always in [1, maxEstimateMinutes].
    glados.Glados(
      glados.any.intInRange(1, maxEstimateMinutes),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is always in bounds when non-null',
      (v) {
        final result = parseMinutes(v);
        if (result != null) {
          expect(result, greaterThanOrEqualTo(1));
          expect(result, lessThanOrEqualTo(maxEstimateMinutes));
        }
      },
      tags: 'glados',
    );
  });
}
