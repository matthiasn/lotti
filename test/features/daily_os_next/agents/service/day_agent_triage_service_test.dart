import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_triage_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_data/entity_factories.dart';

const _agentId = 'day-agent-001';
final _now = DateTime(2026, 5, 25, 9);

Task _task({
  required String id,
  required TaskStatus status,
  String? categoryId = 'work',
  DateTime? due,
}) {
  return JournalEntity.task(
        meta: Metadata(
          id: id,
          createdAt: DateTime(2026, 5, 20),
          updatedAt: DateTime(2026, 5, 20),
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          categoryId: categoryId,
        ),
        data: TaskData(
          status: status,
          statusHistory: [status],
          dateFrom: DateTime(2026, 5, 20),
          dateTo: DateTime(2026, 5, 20, 1),
          title: 'Task $id',
          due: due,
        ),
      )
      as Task;
}

TaskStatus _openStatus() => TaskStatus.open(
  id: 'status-open',
  createdAt: DateTime(2026, 5, 20),
  utcOffset: 120,
);

TaskStatus _blockedStatus() => TaskStatus.blocked(
  id: 'status-blocked',
  createdAt: DateTime(2026, 5, 20),
  utcOffset: 120,
  reason: 'waiting',
);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockJournalRepository journalRepository;
  late MockAgentRepository agentRepository;
  late List<String> notifications;

  DayAgentTriageService createService() => DayAgentTriageService(
    journalDb: journalDb,
    journalRepository: journalRepository,
    reads: DayAgentCaptureReads(agentRepository: agentRepository),
    onPersistedStateChanged: notifications.add,
  );

  /// The task as the triage reads it, and its stored row behind
  /// `JournalRepository.updateTask`, which a test may move on to model a
  /// write landing between the read and the triage's write.
  StubTaskRow stubTask(Task task) {
    when(
      () => journalDb.journalEntityById(task.id),
    ).thenAnswer((_) async => task);
    return stubTaskRow(journalRepository, task);
  }

  setUp(() {
    journalDb = MockJournalDb();
    journalRepository = MockJournalRepository();
    agentRepository = MockAgentRepository();
    notifications = <String>[];
    when(() => agentRepository.getEntity(_agentId)).thenAnswer(
      (_) async => makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        allowedCategoryIds: {'work'},
      ),
    );
  });

  test('done action appends a done status and notifies', () async {
    final row = stubTask(_task(id: 't1', status: _openStatus()));

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't1',
        action: 'done',
      );
      expect(updated.data.status, isA<TaskDone>());
      expect(
        updated.data.statusHistory.map((s) => s.toDbString),
        ['OPEN', 'DONE'],
      );
      expect(updated, row.writes.single);
    });

    expect(notifications, ['t1']);
  });

  for (final (action, dbString) in [
    ('doNow', 'IN PROGRESS'),
    ('do_now', 'IN PROGRESS'),
    ('drop', 'REJECTED'),
  ]) {
    test('$action action records $dbString in the history once', () async {
      final row = stubTask(_task(id: 't-$action', status: _openStatus()));

      await withClock(Clock.fixed(_now), () async {
        final updated = await createService().applyTriage(
          agentId: _agentId,
          taskId: 't-$action',
          action: action,
        );
        expect(updated.data.status.toDbString, dbString);
        expect(updated.data.status.createdAt, _now);
        expect(
          updated.data.statusHistory.map((s) => s.toDbString),
          ['OPEN', dbString],
        );
        expect(row.writes.single, updated);
      });
    });
  }

  test('done on a task stored as done meanwhile adds no history entry and '
      'writes nothing', () async {
    final read = _task(id: 't-done', status: _openStatus());
    final userDone = TaskStatus.done(
      id: 'status-user-done',
      createdAt: DateTime(2026, 5, 24),
      utcOffset: 120,
    );
    final row = stubTask(read)
      ..task = read.copyWith(
        data: read.data.copyWith(
          status: userDone,
          statusHistory: [...read.data.statusHistory, userDone],
        ),
      );
    final stored = row.task;

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't-done',
        action: 'done',
      );
      expect(updated, stored);
      expect(updated.data.status.id, 'status-user-done');
      expect(
        updated.data.statusHistory.map((s) => s.id),
        ['status-open', 'status-user-done'],
      );
    });
    expect(row.writes, isEmpty);
  });

  test('applies the triage on the task as stored: a field set since the '
      'read survives', () async {
    final read = _task(id: 't-kept', status: _openStatus());
    final row = stubTask(read)
      ..task = read.copyWith(
        data: read.data.copyWith(
          priority: TaskPriority.p0Urgent,
          title: 'Renamed meanwhile',
        ),
      );

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't-kept',
        action: 'defer',
        deferTo: DateTime(2026, 5, 28, 10),
      );
      expect(updated.data.due, DateTime(2026, 5, 28, 23, 59, 59, 999));
      expect(updated.data.priority, TaskPriority.p0Urgent);
      expect(updated.data.title, 'Renamed meanwhile');
      expect(row.writes.single, updated);
    });
  });

  test('a status set since the read is built on, not replaced', () async {
    final read = _task(id: 't-status', status: _openStatus());
    final userStatus = TaskStatus.groomed(
      id: 'status-user-groomed',
      createdAt: DateTime(2026, 5, 24),
      utcOffset: 120,
    );
    final row = stubTask(read)
      ..task = read.copyWith(
        data: read.data.copyWith(
          status: userStatus,
          statusHistory: [...read.data.statusHistory, userStatus],
        ),
      );

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't-status',
        action: 'done',
      );
      expect(
        updated.data.statusHistory.map((s) => s.toDbString),
        ['OPEN', 'GROOMED', 'DONE'],
      );
      expect(row.writes.single, updated);
    });
  });

  test('today action sets due to end of day for an open task', () async {
    stubTask(_task(id: 't2', status: _openStatus()));

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't2',
        action: 'today',
      );
      expect(updated.data.due, DateTime(2026, 5, 25, 23, 59, 59, 999));
      // An already-open task keeps its status (no reopen).
      expect(updated.data.status, isA<TaskOpen>());
    });
  });

  test('today action reopens a blocked task', () async {
    stubTask(_task(id: 't3', status: _blockedStatus()));

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't3',
        action: 'today',
      );
      expect(updated.data.status, isA<TaskOpen>());
      expect(
        updated.data.statusHistory.map((s) => s.toDbString),
        ['BLOCKED', 'OPEN'],
      );
    });
  });

  test('today reopens a task the user blocked since the read', () async {
    final read = _task(id: 't3b', status: _openStatus());
    final row = stubTask(read)
      ..task = read.copyWith(
        data: read.data.copyWith(
          status: _blockedStatus(),
          statusHistory: [...read.data.statusHistory, _blockedStatus()],
        ),
      );

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't3b',
        action: 'today',
      );
      expect(updated.data.status, isA<TaskOpen>());
      expect(
        updated.data.statusHistory.map((s) => s.toDbString),
        ['OPEN', 'BLOCKED', 'OPEN'],
      );
      expect(row.writes.single, updated);
    });
  });

  test('defer requires deferTo', () async {
    stubTask(_task(id: 't4', status: _openStatus()));

    await withClock(Clock.fixed(_now), () async {
      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 't4',
          action: 'defer',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  test('rejects a task outside the allowed categories', () async {
    stubTask(_task(id: 't5', status: _openStatus(), categoryId: 'life'));

    await expectLater(
      createService().applyTriage(
        agentId: _agentId,
        taskId: 't5',
        action: 'done',
      ),
      throwsA(isA<DayAgentCaptureException>()),
    );
    verifyNever(
      () => journalRepository.updateTask(
        any(),
        any(),
        onlyIf: any(named: 'onlyIf'),
      ),
    );
  });

  test('leaves a task moved outside the allowed categories since the read '
      'alone', () async {
    final read = _task(id: 't-moved', status: _openStatus());
    // Sync (or the user) files the task under a category the planner does
    // not own after the triage read it, before its write.
    final row = stubTask(read)
      ..task = read.copyWith(meta: read.meta.copyWith(categoryId: 'life'));

    await withClock(Clock.fixed(_now), () async {
      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 't-moved',
          action: 'done',
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (e) => e.message,
            'message',
            contains('outside the allowed categories'),
          ),
        ),
      );
    });
    expect(row.writes, isEmpty);
    expect(row.task.data.status, isA<TaskOpen>());
    expect(notifications, isEmpty);
  });

  test('throws an unknown-action error for an unrecognized action', () async {
    stubTask(_task(id: 't6', status: _openStatus()));

    await expectLater(
      createService().applyTriage(
        agentId: _agentId,
        taskId: 't6',
        action: 'frobnicate',
      ),
      throwsA(isA<DayAgentCaptureException>()),
    );
  });

  test('throws when the persistence update fails', () async {
    stubTask(_task(id: 't7', status: _openStatus()));
    when(
      () => journalRepository.updateTask(
        any(),
        any(),
        onlyIf: any(named: 'onlyIf'),
      ),
    ).thenAnswer((_) async => null);

    await withClock(Clock.fixed(_now), () async {
      await expectLater(
        createService().applyTriage(
          agentId: _agentId,
          taskId: 't7',
          action: 'done',
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
    expect(notifications, isEmpty);
  });
}
