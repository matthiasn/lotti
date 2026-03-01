import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  late MockJournalRepository mockJournalRepo;
  late Task task;

  setUp(() {
    mockJournalRepo = MockJournalRepository();
    // Create a fresh copy of testTask for each test so mutations don't leak.
    task = testTask.copyWith(
      data: testTask.data.copyWith(title: 'Original Title'),
    );
    registerFallbackValue(task as JournalEntity);
  });

  group('TaskTitleHandler', () {
    group('handle', () {
      test('updates title and returns success result with didWrite=true',
          () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('New Title');

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.wasNoOp, isFalse);
        expect(result.message, contains('New Title'));
        expect(result.requestedTitle, equals('New Title'));
        expect(result.updatedTask, isNotNull);
        expect(result.updatedTask!.data.title, equals('New Title'));
        expect(result.error, isNull);

        verify(() => mockJournalRepo.updateJournalEntity(any())).called(1);
      });

      test('trims whitespace from title before applying', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('  Trimmed Title  ');

        expect(result.success, isTrue);
        expect(result.requestedTitle, equals('Trimmed Title'));
        expect(result.updatedTask!.data.title, equals('Trimmed Title'));
      });

      test('rejects empty title and returns error without writing', () async {
        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('empty'));
        expect(result.updatedTask, isNull);

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('rejects whitespace-only title', () async {
        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('   ');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('empty'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('returns success no-op when title is unchanged', () async {
        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('Original Title');

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
        expect(result.message, contains('already'));
        expect(result.updatedTask, isNotNull);
        expect(result.requestedTitle, equals('Original Title'));

        verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
      });

      test('returns error when repository throws', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('DB write failed'));

        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('New Title');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('DB write failed'));
        expect(result.message, contains('Failed'));
        expect(result.requestedTitle, equals('New Title'));
      });

      test('returns error when repository returns false', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => false);

        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('New Title');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('repository returned false'));
        expect(result.requestedTitle, equals('New Title'));
        // Local task should NOT be updated on failure.
        expect(handler.task.data.title, equals('Original Title'));
      });

      test('updates local task field after successful write', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.title, equals('Original Title'));

        await handler.handle('Updated Title');

        expect(handler.task.data.title, equals('Updated Title'));
      });

      test('does not update local task field when write fails', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('fail'));

        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.handle('Should Not Stick');

        expect(handler.task.data.title, equals('Original Title'));
      });

      test('invokes onTaskUpdated callback on successful write', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

        Task? callbackTask;
        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (t) => callbackTask = t,
        );

        await handler.handle('Callback Title');

        expect(callbackTask, isNotNull);
        expect(callbackTask!.data.title, equals('Callback Title'));
      });

      test('does not invoke onTaskUpdated on no-op', () async {
        var callbackInvoked = false;
        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackInvoked = true,
        );

        await handler.handle('Original Title');

        expect(callbackInvoked, isFalse);
      });

      test('does not invoke onTaskUpdated when write fails', () async {
        when(() => mockJournalRepo.updateJournalEntity(any()))
            .thenThrow(Exception('fail'));

        var callbackInvoked = false;
        final handler = TaskTitleHandler(
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackInvoked = true,
        );

        await handler.handle('Should Fail');

        expect(callbackInvoked, isFalse);
      });
    });

    group('fromHandlerResult conversion', () {
      test('maps successful write result with entityId', () {
        final titleResult = TaskTitleResult(
          success: true,
          message: 'Title updated to "Foo".',
          updatedTask: task,
          requestedTitle: 'Foo',
          didWrite: true,
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: titleResult.success,
          message: titleResult.message,
          didWrite: titleResult.didWrite,
          error: titleResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.output, equals('Title updated to "Foo".'));
        expect(toolResult.mutatedEntityId, equals('ent-123'));
        expect(toolResult.errorMessage, isNull);
      });

      test('maps no-op result without entityId', () {
        final titleResult = TaskTitleResult(
          success: true,
          message: 'Title is already "Foo". No change needed.',
          updatedTask: task,
          requestedTitle: 'Foo',
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: titleResult.success,
          message: titleResult.message,
          didWrite: titleResult.didWrite,
          error: titleResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.mutatedEntityId, isNull);
      });

      test('maps error result with error message', () {
        const titleResult = TaskTitleResult(
          success: false,
          message: 'Invalid title: title must not be empty.',
          error: 'Invalid title: title must not be empty.',
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: titleResult.success,
          message: titleResult.message,
          didWrite: titleResult.didWrite,
          error: titleResult.error,
        );

        expect(toolResult.success, isFalse);
        expect(toolResult.errorMessage, contains('empty'));
        expect(toolResult.mutatedEntityId, isNull);
      });
    });

    group('TaskTitleResult', () {
      test('wasNoOp is true when success=true and didWrite=false', () {
        const result = TaskTitleResult(
          success: true,
          message: 'no-op',
        );
        expect(result.wasNoOp, isTrue);
      });

      test('wasNoOp is false when didWrite=true', () {
        const result = TaskTitleResult(
          success: true,
          message: 'wrote',
          didWrite: true,
        );
        expect(result.wasNoOp, isFalse);
      });

      test('wasNoOp is false when success=false', () {
        const result = TaskTitleResult(
          success: false,
          message: 'error',
        );
        expect(result.wasNoOp, isFalse);
      });
    });
  });
}
