import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/service/task_due_date_wake.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 11, 12, 10);
  late MockAgentRepository repository;
  late MockJournalDb journalDb;
  late MockDomainLogger domainLogger;
  late List<AgentStateEntity> written;

  Task task({DateTime? due}) => Task(
    meta: Metadata(
      id: 'task-1',
      dateFrom: now,
      dateTo: now,
      createdAt: now,
      updatedAt: now,
    ),
    data: TaskData(
      status: TaskStatus.open(id: 'open', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Count all 37 emperor penguins',
      due: due,
    ),
  );

  AgentStateEntity state({String? taskId = 'task-1', DateTime? schedule}) =>
      makeTestState(
        slots: AgentSlots(activeTaskId: taskId),
        scheduledWakeAt: schedule,
      );

  Future<void> arm({
    required AgentStateEntity? agentState,
    JournalEntity? entity,
  }) async {
    when(
      () => repository.getAgentState(kTestAgentId),
    ).thenAnswer((_) async => agentState);
    when(
      () => journalDb.journalEntityById('task-1'),
    ).thenAnswer((_) async => entity);
    await withClock(
      Clock.fixed(now),
      () => armTaskDueDateWake(
        kTestAgentId,
        repository: repository,
        journalDb: journalDb,
        domainLogger: domainLogger,
      ),
    );
  }

  setUp(() {
    repository = MockAgentRepository();
    journalDb = MockJournalDb();
    domainLogger = MockDomainLogger();
    written = [];
    when(() => repository.upsertEntity(any())).thenAnswer(
      (invocation) async => written.add(
        invocation.positionalArguments.single as AgentStateEntity,
      ),
    );
  });

  test('a task due today is armed for the midnight it turns overdue', () async {
    await arm(
      agentState: state(),
      entity: task(due: DateTime(2026, 11, 12)),
    );

    final armed = written.single;
    expect(armed.scheduledWakeAt, DateTime(2026, 11, 13));
    // Device-local: the synced version is left as it was.
    expect(armed.updatedAt, state().updatedAt);
    expect(armed.vectorClock, state().vectorClock);
  });

  test('a wake that commits during the task lookup is not reverted', () async {
    final committed = state().copyWith(
      lastWakeAt: now,
      consecutiveFailureCount: 0,
    );
    var current = state().copyWith(consecutiveFailureCount: 3);
    when(
      () => repository.getAgentState(kTestAgentId),
    ).thenAnswer((_) async => current);
    when(() => journalDb.journalEntityById('task-1')).thenAnswer((_) async {
      current = committed;
      return task(due: DateTime(2026, 11, 12));
    });

    await withClock(
      Clock.fixed(now),
      () => armTaskDueDateWake(
        kTestAgentId,
        repository: repository,
        journalDb: journalDb,
        domainLogger: domainLogger,
      ),
    );

    expect(
      written.single,
      committed.copyWith(scheduledWakeAt: DateTime(2026, 11, 13)),
    );
  });

  test('a boundary a wake armed during the lookup is kept', () async {
    var current = state();
    when(
      () => repository.getAgentState(kTestAgentId),
    ).thenAnswer((_) async => current);
    when(() => journalDb.journalEntityById('task-1')).thenAnswer((_) async {
      // The task was moved to today and its wake armed tonight's boundary.
      current = state(schedule: DateTime(2026, 11, 13));
      return task(due: DateTime(2026, 11, 20));
    });

    await withClock(
      Clock.fixed(now),
      () => armTaskDueDateWake(
        kTestAgentId,
        repository: repository,
        journalDb: journalDb,
        domainLogger: domainLogger,
      ),
    );

    expect(written, isEmpty);
  });

  test('an already armed boundary is not written again', () async {
    await arm(
      agentState: state(schedule: DateTime(2026, 11, 13)),
      entity: task(due: DateTime(2026, 11, 12)),
    );

    expect(written, isEmpty);
  });

  test('nothing is armed without a boundary to arm', () async {
    // No due date, an overdue task, a missing entity, no task, no state.
    await arm(agentState: state(), entity: task());
    await arm(
      agentState: state(),
      entity: task(due: DateTime(2026, 11, 10)),
    );
    await arm(agentState: state());
    await arm(agentState: state(taskId: null));
    await arm(agentState: null);

    expect(written, isEmpty);
  });

  test('a failed read is logged, not thrown', () async {
    when(
      () => repository.getAgentState(kTestAgentId),
    ).thenThrow(StateError('db closed'));

    await armTaskDueDateWake(
      kTestAgentId,
      repository: repository,
      journalDb: journalDb,
      domainLogger: domainLogger,
    );

    verify(
      () => domainLogger.error(
        LogDomain.agentRuntime,
        any<Object>(that: isA<StateError>()),
        message: any(named: 'message', that: contains('due-date wake')),
        stackTrace: any(named: 'stackTrace', that: isNotNull),
      ),
    ).called(1);
    expect(written, isEmpty);
  });
}
