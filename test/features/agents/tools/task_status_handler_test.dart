import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_status_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

enum _GeneratedStatusSpelling {
  exact,
  lowercase,
  lowercaseWithWhitespace,
}

enum _GeneratedReasonShape {
  nullReason,
  empty,
  whitespace,
  padded,
  plain,
}

enum _GeneratedInvalidStatusKind { terminal, unknown }

class _GeneratedAllowedStatusScenario {
  const _GeneratedAllowedStatusScenario({
    required this.currentStatus,
    required this.targetStatus,
    required this.spelling,
    required this.reasonShape,
  });

  final String currentStatus;
  final String targetStatus;
  final _GeneratedStatusSpelling spelling;
  final _GeneratedReasonShape reasonShape;

  String get requestStatus {
    return switch (spelling) {
      _GeneratedStatusSpelling.exact => targetStatus,
      _GeneratedStatusSpelling.lowercase => targetStatus.toLowerCase(),
      _GeneratedStatusSpelling.lowercaseWithWhitespace =>
        '  ${targetStatus.toLowerCase()}  ',
    };
  }

  String? get reason {
    return switch (reasonShape) {
      _GeneratedReasonShape.nullReason => null,
      _GeneratedReasonShape.empty => '',
      _GeneratedReasonShape.whitespace => '   ',
      _GeneratedReasonShape.padded => '  Generated reason  ',
      _GeneratedReasonShape.plain => 'Generated reason',
    };
  }

  bool get requiresReason =>
      targetStatus == 'BLOCKED' || targetStatus == 'ON HOLD';

  bool get hasValidReason => reason != null && reason!.trim().isNotEmpty;

  bool get shouldWrite =>
      (!requiresReason || hasValidReason) && currentStatus != targetStatus;

  bool get shouldNoOp =>
      (!requiresReason || hasValidReason) && currentStatus == targetStatus;

  @override
  String toString() {
    return '_GeneratedAllowedStatusScenario('
        'currentStatus: $currentStatus, '
        'targetStatus: $targetStatus, '
        'spelling: $spelling, '
        'reasonShape: $reasonShape)';
  }
}

class _GeneratedInvalidStatusScenario {
  const _GeneratedInvalidStatusScenario({
    required this.kind,
    required this.spelling,
    required this.seed,
  });

  final _GeneratedInvalidStatusKind kind;
  final _GeneratedStatusSpelling spelling;
  final int seed;

  String get normalizedStatus {
    return switch (kind) {
      _GeneratedInvalidStatusKind.terminal => seed.isEven ? 'DONE' : 'REJECTED',
      _GeneratedInvalidStatusKind.unknown => 'UNKNOWN STATUS $seed',
    };
  }

  String get requestStatus {
    return switch (spelling) {
      _GeneratedStatusSpelling.exact => normalizedStatus,
      _GeneratedStatusSpelling.lowercase => normalizedStatus.toLowerCase(),
      _GeneratedStatusSpelling.lowercaseWithWhitespace =>
        '  ${normalizedStatus.toLowerCase()}  ',
    };
  }

  bool get isTerminal => kind == _GeneratedInvalidStatusKind.terminal;

  @override
  String toString() {
    return '_GeneratedInvalidStatusScenario('
        'kind: $kind, spelling: $spelling, seed: $seed)';
  }
}

extension _AnyTaskStatusHandlerScenario on glados.Any {
  glados.Generator<String> get allowedStatus =>
      glados.AnyUtils(this).choose(TaskStatusHandler.allowedStatuses.toList());

  glados.Generator<_GeneratedStatusSpelling> get statusSpelling =>
      glados.AnyUtils(this).choose(_GeneratedStatusSpelling.values);

  glados.Generator<_GeneratedReasonShape> get reasonShape =>
      glados.AnyUtils(this).choose(_GeneratedReasonShape.values);

  glados.Generator<_GeneratedInvalidStatusKind> get invalidStatusKind =>
      glados.AnyUtils(this).choose(_GeneratedInvalidStatusKind.values);

  glados.Generator<_GeneratedAllowedStatusScenario> get allowedStatusScenario =>
      glados.CombinableAny(this).combine4(
        allowedStatus,
        allowedStatus,
        statusSpelling,
        reasonShape,
        (
          String currentStatus,
          String targetStatus,
          _GeneratedStatusSpelling spelling,
          _GeneratedReasonShape reasonShape,
        ) => _GeneratedAllowedStatusScenario(
          currentStatus: currentStatus,
          targetStatus: targetStatus,
          spelling: spelling,
          reasonShape: reasonShape,
        ),
      );

  glados.Generator<_GeneratedInvalidStatusScenario> get invalidStatusScenario =>
      glados.CombinableAny(this).combine3(
        invalidStatusKind,
        statusSpelling,
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedInvalidStatusKind kind,
          _GeneratedStatusSpelling spelling,
          int seed,
        ) => _GeneratedInvalidStatusScenario(
          kind: kind,
          spelling: spelling,
          seed: seed,
        ),
      );
}

void main() {
  late MockJournalRepository mockJournalRepo;
  late Task task;

  setUp(() {
    mockJournalRepo = MockJournalRepository();
    task = testTask.copyWith(
      data: testTask.data.copyWith(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 60,
        ),
        statusHistory: [
          TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 60,
          ),
        ],
      ),
    );
    registerFallbackValue(task as JournalEntity);
  });

  TaskStatus statusFor(String status) {
    final now = DateTime(2024, 3, 15);
    return switch (status) {
      'IN PROGRESS' => TaskStatus.inProgress(
        id: 'status-in-progress',
        createdAt: now,
        utcOffset: 60,
      ),
      'GROOMED' => TaskStatus.groomed(
        id: 'status-groomed',
        createdAt: now,
        utcOffset: 60,
      ),
      'BLOCKED' => TaskStatus.blocked(
        id: 'status-blocked',
        createdAt: now,
        utcOffset: 60,
        reason: 'Existing blocker',
      ),
      'ON HOLD' => TaskStatus.onHold(
        id: 'status-on-hold',
        createdAt: now,
        utcOffset: 60,
        reason: 'Existing hold',
      ),
      _ => TaskStatus.open(
        id: 'status-open',
        createdAt: now,
        utcOffset: 60,
      ),
    };
  }

  Task taskWithStatus(String status) {
    final taskStatus = statusFor(status);
    return task.copyWith(
      data: task.data.copyWith(
        status: taskStatus,
        statusHistory: [taskStatus],
      ),
    );
  }

  group('TaskStatusHandler', () {
    group('handle', () {
      test('transitions to IN PROGRESS with didWrite=true', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('IN PROGRESS');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.wasNoOp, isFalse);
        expect(result.message, contains('IN PROGRESS'));
        expect(result.message, contains('OPEN'));
        expect(result.updatedTask, isNotNull);
        expect(
          result.updatedTask!.data.status.toDbString,
          'IN PROGRESS',
        );
        expect(result.error, isNull);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('transitions to GROOMED', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('GROOMED');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.status.toDbString, 'GROOMED');
      });

      test('transitions to BLOCKED with reason', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle(
          'BLOCKED',
          reason: 'Waiting for API access',
        );

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.status.toDbString, 'BLOCKED');
        expect(
          (result.updatedTask!.data.status as TaskBlocked).reason,
          'Waiting for API access',
        );
      });

      test('transitions to ON HOLD with reason', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle(
          'ON HOLD',
          reason: 'Deprioritized until Q3',
        );

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.status.toDbString, 'ON HOLD');
        expect(
          (result.updatedTask!.data.status as TaskOnHold).reason,
          'Deprioritized until Q3',
        );
      });

      test('transitions back to OPEN from IN PROGRESS', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final inProgressTask = task.copyWith(
          data: task.data.copyWith(
            status: TaskStatus.inProgress(
              id: 'status-2',
              createdAt: DateTime(2024, 3, 16),
              utcOffset: 60,
            ),
          ),
        );

        final handler = TaskStatusHandler(
          task: inProgressTask,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('OPEN');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.status.toDbString, 'OPEN');
      });

      test('normalizes case for status string', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('  in progress  ');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.updatedTask!.data.status.toDbString, 'IN PROGRESS');
      });

      test('rejects DONE status (user-only)', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('DONE');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('user-only'));
        expect(result.error, contains('DONE'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('rejects REJECTED status (user-only)', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('REJECTED');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('user-only'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('rejects unknown status string', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('INVALID');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('Unknown status'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('requires reason for BLOCKED', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('BLOCKED');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('requires a reason'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('requires reason for ON HOLD', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('ON HOLD');

        expect(result.success, isFalse);
        expect(result.error, contains('requires a reason'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('rejects empty reason for BLOCKED', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('BLOCKED', reason: '  ');

        expect(result.success, isFalse);
        expect(result.error, contains('requires a reason'));
      });

      test('returns no-op when status is already the target', () async {
        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        // Task is already OPEN.
        final result = await handler.handle('OPEN');

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
        expect(result.message, contains('already'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('appends to statusHistory', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('IN PROGRESS');

        expect(result.success, isTrue);
        // Original had 1 entry, now should have 2.
        expect(result.updatedTask!.data.statusHistory, hasLength(2));
        expect(
          result.updatedTask!.data.statusHistory.last.toDbString,
          'IN PROGRESS',
        );
      });

      test('uses clock.now() for status createdAt', () async {
        final fixedTime = DateTime(2024, 6, 15, 10, 30);
        await withClock(Clock.fixed(fixedTime), () async {
          when(
            () => mockJournalRepo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final handler = TaskStatusHandler(
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.handle('GROOMED');

          expect(result.success, isTrue);
          expect(result.updatedTask!.data.status.createdAt, fixedTime);
        });
      });

      test('returns error when repository returns false', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => false);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('IN PROGRESS');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('repository returned false'));
      });

      test('returns error when repository throws', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('DB error'));

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('IN PROGRESS');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('DB error'));
      });

      test('updates local task field after successful write', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.status.toDbString, 'OPEN');

        await handler.handle('IN PROGRESS');

        expect(handler.task.data.status.toDbString, 'IN PROGRESS');
      });

      test('does not update local task field when write fails', () async {
        when(
          () => mockJournalRepo.updateJournalEntity(any()),
        ).thenThrow(Exception('fail'));

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.handle('IN PROGRESS');

        expect(handler.task.data.status.toDbString, 'OPEN');
      });

      glados.Glados(
        glados.any.allowedStatusScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated allowed-status transition semantics',
        (scenario) async {
          final repo = MockJournalRepository();
          when(
            () => repo.updateJournalEntity(any()),
          ).thenAnswer((_) async => true);

          final initialTask = taskWithStatus(scenario.currentStatus);
          final handler = TaskStatusHandler(
            task: initialTask,
            journalRepository: repo,
          );

          final result = await handler.handle(
            scenario.requestStatus,
            reason: scenario.reason,
          );

          if (scenario.requiresReason && !scenario.hasValidReason) {
            expect(result.success, isFalse, reason: '$scenario');
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(result.error, contains('requires a reason'));
            expect(handler.task, initialTask);
            verifyNever(() => repo.updateJournalEntity(any()));
            return;
          }

          expect(result.success, isTrue, reason: '$scenario');
          expect(result.error, isNull, reason: '$scenario');

          if (scenario.shouldNoOp) {
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(result.wasNoOp, isTrue, reason: '$scenario');
            expect(result.updatedTask, initialTask, reason: '$scenario');
            verifyNever(() => repo.updateJournalEntity(any()));
            return;
          }

          expect(scenario.shouldWrite, isTrue, reason: '$scenario');
          expect(result.didWrite, isTrue, reason: '$scenario');
          expect(result.wasNoOp, isFalse, reason: '$scenario');
          expect(
            result.updatedTask!.data.status.toDbString,
            scenario.targetStatus,
            reason: '$scenario',
          );
          expect(
            result.updatedTask!.data.statusHistory.map((s) => s.toDbString),
            [scenario.currentStatus, scenario.targetStatus],
            reason: '$scenario',
          );
          expect(handler.task, result.updatedTask, reason: '$scenario');

          if (scenario.requiresReason) {
            final status = result.updatedTask!.data.status;
            final actualReason = switch (status) {
              TaskBlocked(:final reason) => reason,
              TaskOnHold(:final reason) => reason,
              _ => throw StateError('Expected reason status for $scenario'),
            };
            expect(actualReason, scenario.reason!.trim(), reason: '$scenario');
          }

          final captured =
              verify(
                    () => repo.updateJournalEntity(captureAny()),
                  ).captured.single
                  as Task;
          expect(captured, result.updatedTask, reason: '$scenario');
        },
      );

      glados.Glados(
        glados.any.invalidStatusScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'rejects generated terminal and unknown statuses without writes',
        (scenario) async {
          final repo = MockJournalRepository();
          final handler = TaskStatusHandler(
            task: task,
            journalRepository: repo,
          );

          final result = await handler.handle(scenario.requestStatus);

          expect(result.success, isFalse, reason: '$scenario');
          expect(result.didWrite, isFalse, reason: '$scenario');
          expect(result.updatedTask, isNull, reason: '$scenario');
          expect(handler.task, task, reason: '$scenario');
          expect(
            result.error,
            scenario.isTerminal ? contains('user-only') : contains('Unknown'),
            reason: '$scenario',
          );
          verifyNever(() => repo.updateJournalEntity(any()));
        },
      );
    });

    group('fromHandlerResult conversion', () {
      test('maps successful write with entityId', () {
        final statusResult = TaskStatusResult(
          success: true,
          message: 'Task status changed from "OPEN" to "IN PROGRESS".',
          updatedTask: task,
          didWrite: true,
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: statusResult.success,
          message: statusResult.message,
          didWrite: statusResult.didWrite,
          error: statusResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.output, contains('IN PROGRESS'));
        expect(toolResult.mutatedEntityId, 'ent-123');
        expect(toolResult.errorMessage, isNull);
      });

      test('maps no-op result without entityId', () {
        final statusResult = TaskStatusResult(
          success: true,
          message: 'Task is already "OPEN". No change needed.',
          updatedTask: task,
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: statusResult.success,
          message: statusResult.message,
          didWrite: statusResult.didWrite,
          error: statusResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.mutatedEntityId, isNull);
      });

      test('maps error result with error message', () {
        const statusResult = TaskStatusResult(
          success: false,
          message: 'Cannot set status to "DONE".',
          error: 'Cannot set status to "DONE".',
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: statusResult.success,
          message: statusResult.message,
          didWrite: statusResult.didWrite,
          error: statusResult.error,
        );

        expect(toolResult.success, isFalse);
        expect(toolResult.errorMessage, contains('DONE'));
        expect(toolResult.mutatedEntityId, isNull);
      });
    });

    group('TaskStatusResult', () {
      test('wasNoOp is true when success=true and didWrite=false', () {
        const result = TaskStatusResult(
          success: true,
          message: 'no-op',
        );
        expect(result.wasNoOp, isTrue);
      });

      test('wasNoOp is false when didWrite=true', () {
        const result = TaskStatusResult(
          success: true,
          message: 'wrote',
          didWrite: true,
        );
        expect(result.wasNoOp, isFalse);
      });

      test('wasNoOp is false when success=false', () {
        const result = TaskStatusResult(
          success: false,
          message: 'error',
        );
        expect(result.wasNoOp, isFalse);
      });
    });

    group('allowedStatuses and terminalStatuses', () {
      test('allowedStatuses contains expected values', () {
        expect(
          TaskStatusHandler.allowedStatuses,
          containsAll(['OPEN', 'IN PROGRESS', 'GROOMED', 'BLOCKED', 'ON HOLD']),
        );
      });

      test('terminalStatuses contains DONE and REJECTED', () {
        expect(
          TaskStatusHandler.terminalStatuses,
          containsAll(['DONE', 'REJECTED']),
        );
      });

      test('no overlap between allowed and terminal', () {
        final intersection = TaskStatusHandler.allowedStatuses.intersection(
          TaskStatusHandler.terminalStatuses,
        );
        expect(intersection, isEmpty);
      });
    });
  });
}
