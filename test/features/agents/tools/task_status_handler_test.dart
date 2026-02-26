import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/task_status_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

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

  group('TaskStatusHandler', () {
    group('handle', () {
      test('transitions to IN PROGRESS with didWrite=true', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
          when(() => mockJournalRepo.updateJournalEntity(any()))
              .thenAnswer((_) async => true);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => false);

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('DB error'));

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
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.status.toDbString, 'OPEN');

        await handler.handle('IN PROGRESS');

        expect(handler.task.data.status.toDbString, 'IN PROGRESS');
      });

      test('does not update local task field when write fails', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('fail'));

        final handler = TaskStatusHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.handle('IN PROGRESS');

        expect(handler.task.data.status.toDbString, 'OPEN');
      });
    });

    group('toToolExecutionResult', () {
      test('maps successful write with entityId', () {
        final statusResult = TaskStatusResult(
          success: true,
          message: 'Task status changed from "OPEN" to "IN PROGRESS".',
          updatedTask: task,
          didWrite: true,
        );

        final toolResult = TaskStatusHandler.toToolExecutionResult(
          statusResult,
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

        final toolResult = TaskStatusHandler.toToolExecutionResult(
          statusResult,
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

        final toolResult =
            TaskStatusHandler.toToolExecutionResult(statusResult);

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
        final intersection = TaskStatusHandler.allowedStatuses
            .intersection(TaskStatusHandler.terminalStatuses);
        expect(intersection, isEmpty);
      });
    });
  });
}
