import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_title_handler.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

enum _GeneratedTitleRequestShape {
  empty,
  whitespace,
  same,
  samePadded,
  different,
  differentPadded,
}

class _GeneratedTaskTitleScenario {
  const _GeneratedTaskTitleScenario({
    required this.currentSeed,
    required this.requestSeed,
    required this.shape,
  });

  final int currentSeed;
  final int requestSeed;
  final _GeneratedTitleRequestShape shape;

  String get currentTitle => 'Generated title $currentSeed';

  String get differentTitle => 'Generated replacement $requestSeed';

  String get requestTitle {
    return switch (shape) {
      _GeneratedTitleRequestShape.empty => '',
      _GeneratedTitleRequestShape.whitespace => ' \n\t ',
      _GeneratedTitleRequestShape.same => currentTitle,
      _GeneratedTitleRequestShape.samePadded => '  $currentTitle  ',
      _GeneratedTitleRequestShape.different => differentTitle,
      _GeneratedTitleRequestShape.differentPadded => '\n $differentTitle \t',
    };
  }

  String get trimmedRequest => requestTitle.trim();

  bool get isInvalid => trimmedRequest.isEmpty;

  bool get isNoOp => !isInvalid && trimmedRequest == currentTitle;

  bool get shouldWrite => !isInvalid && !isNoOp;

  @override
  String toString() {
    return '_GeneratedTaskTitleScenario('
        'currentSeed: $currentSeed, '
        'requestSeed: $requestSeed, '
        'shape: $shape)';
  }
}

extension _AnyTaskTitleHandlerScenario on glados.Any {
  glados.Generator<_GeneratedTitleRequestShape> get titleRequestShape =>
      glados.AnyUtils(this).choose(_GeneratedTitleRequestShape.values);

  glados.Generator<_GeneratedTaskTitleScenario> get taskTitleScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        titleRequestShape,
        (
          int currentSeed,
          int requestSeed,
          _GeneratedTitleRequestShape shape,
        ) => _GeneratedTaskTitleScenario(
          currentSeed: currentSeed,
          requestSeed: requestSeed,
          shape: shape,
        ),
      );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalRepository mockJournalRepo;
  late Task task;

  setUp(() {
    mockJournalRepo = MockJournalRepository();
    // Create a fresh copy of testTask for each test so mutations don't leak.
    task = testTask.copyWith(
      data: testTask.data.copyWith(title: 'Original Title'),
    );
  });

  group('TaskTitleHandler', () {
    group('handle', () {
      test(
        'updates title and returns success result with didWrite=true',
        () async {
          stubTaskRow(mockJournalRepo, task);

          final handler = TaskTitleHandler(
            domainLogger: MockDomainLogger(),
            task: task,
            journalRepository: mockJournalRepo,
          );

          final result = await handler.handle('New Title');

          expect(result.success, isTrue);
          expect(result.didWrite, isTrue);
          expect(result.message, contains('New Title'));
          expect(handler.task.data.title, equals('New Title'));
          expect(result.error, isNull);

          verify(() => mockJournalRepo.updateTask(any(), any())).called(1);
        },
      );

      test('trims whitespace from title before applying', () async {
        stubTaskRow(mockJournalRepo, task);

        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('  Trimmed Title  ');

        expect(result.success, isTrue);
        expect(handler.task.data.title, equals('Trimmed Title'));
      });

      test('rejects empty title and returns error without writing', () async {
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, isNotNull);
        expect(result.error, contains('empty'));
        expect(handler.task, same(task));

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
      });

      test('rejects whitespace-only title', () async {
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('   ');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('empty'));

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
      });

      test('returns success no-op when title is unchanged', () async {
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('Original Title');

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.message, contains('already'));
        expect(handler.task.data.title, equals('Original Title'));

        verifyNever(() => mockJournalRepo.updateTask(any(), any()));
      });

      test('returns error when repository throws', () async {
        final logger = MockDomainLogger();
        when(
          () => mockJournalRepo.updateTask(any(), any()),
        ).thenThrow(Exception('DB write failed'));

        final handler = TaskTitleHandler(
          domainLogger: logger,
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('New Title');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('DB write failed'));
        expect(result.message, contains('Failed'));
        expect(handler.task, same(task));
        expect(handler.task.data.title, equals('Original Title'));

        verify(
          () => logger.error(
            LogDomain.agentWorkflow,
            any(that: isA<Exception>()),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'TaskTitleHandler',
            message: 'Failed to update task title',
          ),
        ).called(1);
      });

      test('returns error when repository returns false', () async {
        when(
          () => mockJournalRepo.updateTask(any(), any()),
        ).thenAnswer((_) async => null);

        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        final result = await handler.handle('New Title');

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('repository returned false'));
        // Local task should NOT be updated on failure.
        expect(handler.task, same(task));
        expect(handler.task.data.title, equals('Original Title'));
      });

      test('updates local task field after successful write', () async {
        stubTaskRow(mockJournalRepo, task);

        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        expect(handler.task.data.title, equals('Original Title'));

        await handler.handle('Updated Title');

        expect(handler.task.data.title, equals('Updated Title'));
      });

      test('does not update local task field when write fails', () async {
        when(
          () => mockJournalRepo.updateTask(any(), any()),
        ).thenThrow(Exception('fail'));

        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
        );

        await handler.handle('Should Not Stick');

        expect(handler.task.data.title, equals('Original Title'));
      });

      test('invokes onTaskUpdated callback on successful write', () async {
        stubTaskRow(mockJournalRepo, task);

        Task? callbackTask;
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
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
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackInvoked = true,
        );

        await handler.handle('Original Title');

        expect(callbackInvoked, isFalse);
      });

      test('does not invoke onTaskUpdated when write fails', () async {
        when(
          () => mockJournalRepo.updateTask(any(), any()),
        ).thenThrow(Exception('fail'));

        var callbackInvoked = false;
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackInvoked = true,
        );

        await handler.handle('Should Fail');

        expect(callbackInvoked, isFalse);
      });

      test('writes the title on the task as stored, keeping a field set '
          'since the call read the task', () async {
        final row = stubTaskRow(mockJournalRepo, task)
          ..task = task.copyWith(
            data: task.data.copyWith(estimate: const Duration(hours: 2)),
          );
        Task? callbackTask;
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (t) => callbackTask = t,
        );

        final result = await handler.handle('New Title');

        expect(result.didWrite, isTrue);
        final written = row.writes.single;
        expect(written.data.title, 'New Title');
        expect(written.data.estimate, const Duration(hours: 2));
        expect(handler.task, written);
        expect(callbackTask, written);
      });

      test('applies nothing when the stored title changed since the call '
          'read the task', () async {
        final row = stubTaskRow(mockJournalRepo, task)
          ..task = task.copyWith(
            data: task.data.copyWith(title: 'Renamed by the user'),
          );
        final stored = row.task;
        var callbackInvoked = false;
        final handler = TaskTitleHandler(
          domainLogger: MockDomainLogger(),
          task: task,
          journalRepository: mockJournalRepo,
          onTaskUpdated: (_) => callbackInvoked = true,
        );

        final result = await handler.handle('Agent Title');

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.error, isNull);
        expect(result.message, startsWith('Nothing applied'));
        expect(row.writes, isEmpty);
        expect(row.task.data.title, 'Renamed by the user');
        expect(handler.task, stored);
        expect(callbackInvoked, isFalse);
      });

      glados.Glados(
        glados.any.taskTitleScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated title validation, no-op, and write semantics',
        (scenario) async {
          final repo = MockJournalRepository();
          final initialTask = task.copyWith(
            data: task.data.copyWith(title: scenario.currentTitle),
          );
          final row = stubTaskRow(repo, initialTask);
          Task? callbackTask;
          final handler = TaskTitleHandler(
            domainLogger: MockDomainLogger(),
            task: initialTask,
            journalRepository: repo,
            onTaskUpdated: (updatedTask) => callbackTask = updatedTask,
          );

          final result = await handler.handle(scenario.requestTitle);

          if (scenario.isInvalid) {
            expect(result.success, isFalse, reason: '$scenario');
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(result.error, contains('empty'), reason: '$scenario');
            expect(handler.task, initialTask, reason: '$scenario');
            expect(callbackTask, isNull, reason: '$scenario');
            verifyNever(() => repo.updateTask(any(), any()));
            return;
          }

          expect(result.success, isTrue, reason: '$scenario');
          expect(result.error, isNull, reason: '$scenario');
          if (scenario.isNoOp) {
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(handler.task, initialTask, reason: '$scenario');
            expect(callbackTask, isNull, reason: '$scenario');
            verifyNever(() => repo.updateTask(any(), any()));
            return;
          }

          expect(scenario.shouldWrite, isTrue, reason: '$scenario');
          expect(result.didWrite, isTrue, reason: '$scenario');
          expect(
            handler.task.data.title,
            scenario.trimmedRequest,
            reason: '$scenario',
          );
          expect(callbackTask, handler.task, reason: '$scenario');

          expect(row.writes, [handler.task], reason: '$scenario');
          expect(
            row.writes.single.data,
            initialTask.data.copyWith(title: scenario.trimmedRequest),
            reason: '$scenario',
          );
        },
        tags: 'glados',
      );
    });

    group('fromHandlerResult conversion', () {
      test('maps successful write result with entityId', () {
        const titleResult = TaskTitleResult(
          success: true,
          message: 'Title updated to "Foo".',
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
        const titleResult = TaskTitleResult(
          success: true,
          message: 'Title is already "Foo". No change needed.',
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
  });
}
