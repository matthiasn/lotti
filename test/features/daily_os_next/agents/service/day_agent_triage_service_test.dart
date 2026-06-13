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
  late List<JournalEntity> updates;

  DayAgentTriageService createService() => DayAgentTriageService(
    journalDb: journalDb,
    journalRepository: journalRepository,
    reads: DayAgentCaptureReads(agentRepository: agentRepository),
    onPersistedStateChanged: notifications.add,
  );

  void stubTask(Task task) {
    when(
      () => journalDb.journalEntityById(task.id),
    ).thenAnswer((_) async => task);
  }

  setUp(() {
    journalDb = MockJournalDb();
    journalRepository = MockJournalRepository();
    agentRepository = MockAgentRepository();
    notifications = <String>[];
    updates = <JournalEntity>[];
    when(() => agentRepository.getEntity(_agentId)).thenAnswer(
      (_) async => makeTestIdentity(
        id: _agentId,
        agentId: _agentId,
        allowedCategoryIds: {'work'},
      ),
    );
    when(() => journalRepository.updateJournalEntity(any())).thenAnswer((
      invocation,
    ) async {
      updates.add(invocation.positionalArguments.single as JournalEntity);
      return true;
    });
  });

  test('done action appends a done status and notifies', () async {
    stubTask(_task(id: 't1', status: _openStatus()));

    await withClock(Clock.fixed(_now), () async {
      final updated = await createService().applyTriage(
        agentId: _agentId,
        taskId: 't1',
        action: 'done',
      );
      expect(updated.data.status, isA<TaskDone>());
      expect(updated.data.statusHistory.last, isA<TaskDone>());
    });

    expect(notifications, ['t1']);
    expect(updates, hasLength(1));
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
    verifyNever(() => journalRepository.updateJournalEntity(any()));
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
      () => journalRepository.updateJournalEntity(any()),
    ).thenAnswer((_) async => false);

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
