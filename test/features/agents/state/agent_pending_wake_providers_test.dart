import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(<String>[]);
  });

  test(
    'batches agent state reads when building pending wake records',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final firstIdentity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'First',
      );
      final secondIdentity = makeTestIdentity(
        agentId: 'agent-b',
        displayName: 'Second',
      );
      final firstState = makeTestState(
        agentId: 'agent-a',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );
      final secondState = makeTestState(
        agentId: 'agent-b',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 15)),
        scheduledWakeAt: kAgentTestDate.add(const Duration(minutes: 10)),
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer((_) => Future.value([firstIdentity, secondIdentity]));
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer(
        (_) async => {
          'agent-a': firstState,
          'agent-b': secondState,
        },
      );

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, hasLength(3));
      expect(records.first.type, PendingWakeType.pending);
      expect(records.first.agent.agentId, 'agent-a');
      expect(records[1].type, PendingWakeType.scheduled);
      expect(records[1].agent.agentId, 'agent-b');
      expect(records[2].type, PendingWakeType.pending);
      expect(records[2].agent.agentId, 'agent-b');
      final capturedAgentIds =
          verify(
                () => mockRepository.getAgentStatesByAgentIds(captureAny()),
              ).captured.single
              as List<String>;
      expect(capturedAgentIds, ['agent-a', 'agent-b']);
      verifyNever(() => mockRepository.getAgentState(any()));
    },
  );

  test(
    'filters deleted and missing states when building pending wake records',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final activeIdentity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'Active',
      );
      final deletedIdentity = makeTestIdentity(
        agentId: 'agent-b',
        displayName: 'Deleted',
      );
      final missingIdentity = makeTestIdentity(
        agentId: 'agent-c',
        displayName: 'Missing',
      );
      final deletedState =
          makeTestState(
            agentId: 'agent-b',
            id: 'deleted-state',
            nextWakeAt: kAgentTestDate.add(const Duration(minutes: 15)),
          ).copyWith(
            deletedAt: kAgentTestDate,
          );
      final activeState = makeTestState(
        agentId: 'agent-a',
        nextWakeAt: kAgentTestDate.add(const Duration(minutes: 5)),
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer(
        (_) => Future.value([activeIdentity, deletedIdentity, missingIdentity]),
      );
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer(
        (_) async => {
          'agent-a': activeState,
          'agent-b': deletedState,
        },
      );

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, hasLength(1));
      expect(records.single.agent.agentId, 'agent-a');
    },
  );

  test(
    'omits agents whose states have no pending or scheduled wakes',
    () async {
      final mockAgentService = MockAgentService();
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();
      final identity = makeTestIdentity(
        agentId: 'agent-a',
        displayName: 'Idle Agent',
      );
      final state = makeTestState(
        agentId: 'agent-a',
      );

      when(
        mockAgentService.listAgents,
      ).thenAnswer((_) => Future.value([identity]));
      when(
        () => mockRepository.getAgentStatesByAgentIds(any()),
      ).thenAnswer((_) async => {'agent-a': state});

      final container = ProviderContainer(
        overrides: [
          agentServiceProvider.overrideWithValue(mockAgentService),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final records = await container.read(pendingWakeRecordsProvider.future);

      expect(records, isEmpty);
    },
  );

  group('ongoingWakeRecordsProvider', () {
    test('returns empty when nothing is running', () async {
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      final container = ProviderContainer(
        overrides: [wakeRunnerProvider.overrideWithValue(runner)],
      );
      addTearDown(container.dispose);

      final records = await container.read(
        ongoingWakeRecordsProvider.future,
      );
      expect(records, isEmpty);
    });

    test('uses linked task title when slots point at a task', () async {
      final fixed = DateTime(2026, 5, 5, 21);
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      final mockRepository = MockAgentRepository();
      final mockAgentService = MockAgentService();
      final mockJournalDb = MockJournalDb();
      final notifications = UpdateNotifications();
      addTearDown(notifications.dispose);

      when(
        () => mockRepository.getAgentState('agent-a'),
      ).thenAnswer(
        (_) async => makeTestState(
          agentId: 'agent-a',
          slots: const AgentSlots(activeTaskId: 'task-1'),
        ),
      );
      when(() => mockJournalDb.journalEntityById('task-1')).thenAnswer(
        (_) async => makeTestTask(id: 'task-1', title: 'Refine sidebar'),
      );

      await withClock(Clock.fixed(fixed), () async {
        await runner.tryAcquire('agent-a');
      });

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentServiceProvider.overrideWithValue(mockAgentService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final records = await container.read(
        ongoingWakeRecordsProvider.future,
      );
      expect(records, hasLength(1));
      expect(records.single.agentId, 'agent-a');
      expect(records.single.title, 'Refine sidebar');
      expect(records.single.startedAt, fixed);
      expect(records.single.id, 'ongoing:agent-a');
      verifyNever(() => mockAgentService.getAgent(any()));
    });

    test(
      'falls back to agent display name when no subject is linked',
      () async {
        final fixed = DateTime(2026, 5, 5, 21);
        final runner = WakeRunner();
        addTearDown(runner.dispose);
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        when(
          () => mockRepository.getAgentState('agent-z'),
        ).thenAnswer(
          (_) async => makeTestState(agentId: 'agent-z'),
        );
        when(
          () => mockAgentService.getAgent('agent-z'),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            agentId: 'agent-z',
            displayName: 'Improver',
          ),
        );

        await withClock(Clock.fixed(fixed), () async {
          await runner.tryAcquire('agent-z');
        });

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final records = await container.read(
          ongoingWakeRecordsProvider.future,
        );
        expect(records.single.title, 'Improver');
      },
    );

    test(
      'falls back to the agentId when neither subject nor identity is found',
      () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        when(
          () => mockRepository.getAgentState('agent-missing'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAgentService.getAgent('agent-missing'),
        ).thenAnswer((_) async => null);

        await runner.tryAcquire('agent-missing');

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final records = await container.read(
          ongoingWakeRecordsProvider.future,
        );
        expect(records.single.title, 'agent-missing');
      },
    );

    test(
      'swallows subject lookup errors and falls back to display name',
      () async {
        final runner = WakeRunner();
        addTearDown(runner.dispose);
        final mockRepository = MockAgentRepository();
        final mockAgentService = MockAgentService();
        final mockJournalDb = MockJournalDb();
        final notifications = UpdateNotifications();
        addTearDown(notifications.dispose);

        when(
          () => mockRepository.getAgentState('agent-err'),
        ).thenThrow(StateError('db boom'));
        when(
          () => mockAgentService.getAgent('agent-err'),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            agentId: 'agent-err',
            displayName: 'Backup name',
          ),
        );

        await runner.tryAcquire('agent-err');

        final container = ProviderContainer(
          overrides: [
            wakeRunnerProvider.overrideWithValue(runner),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentServiceProvider.overrideWithValue(mockAgentService),
            journalDbProvider.overrideWithValue(mockJournalDb),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );
        addTearDown(container.dispose);

        final records = await container.read(
          ongoingWakeRecordsProvider.future,
        );
        expect(records.single.title, 'Backup name');
      },
    );

    test('sorts results by startedAt ascending', () async {
      final earlier = DateTime(2026, 5, 5, 20);
      final later = DateTime(2026, 5, 5, 21);
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      final mockRepository = MockAgentRepository();
      final mockAgentService = MockAgentService();
      final mockJournalDb = MockJournalDb();
      final notifications = UpdateNotifications();
      addTearDown(notifications.dispose);

      for (final id in ['agent-late', 'agent-early']) {
        when(
          () => mockRepository.getAgentState(id),
        ).thenAnswer((_) async => makeTestState(agentId: id));
        when(() => mockAgentService.getAgent(id)).thenAnswer(
          (_) async => makeTestIdentity(agentId: id, displayName: id),
        );
      }

      await withClock(Clock.fixed(later), () async {
        await runner.tryAcquire('agent-late');
      });
      await withClock(Clock.fixed(earlier), () async {
        await runner.tryAcquire('agent-early');
      });

      final container = ProviderContainer(
        overrides: [
          wakeRunnerProvider.overrideWithValue(runner),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentServiceProvider.overrideWithValue(mockAgentService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final records = await container.read(
        ongoingWakeRecordsProvider.future,
      );
      expect(
        records.map((r) => r.agentId).toList(),
        ['agent-early', 'agent-late'],
      );
    });
  });

  group('pendingWakeTargetTitleProvider', () {
    late MockJournalDb mockJournalDb;

    setUp(() {
      mockJournalDb = MockJournalDb();
    });

    ProviderContainer createContainer() {
      final notifications = UpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });
      return container;
    }

    test('returns null for null or empty entry IDs', () async {
      final container = createContainer();

      expect(
        await container.read(pendingWakeTargetTitleProvider(null).future),
        isNull,
      );
      expect(
        await container.read(pendingWakeTargetTitleProvider('').future),
        isNull,
      );
      verifyNever(() => mockJournalDb.journalEntityById(any()));
    });

    test('returns task and project titles from journal entities', () async {
      when(
        () => mockJournalDb.journalEntityById('task-1'),
      ).thenAnswer(
        (_) async => makeTestTask(id: 'task-1', title: 'Fix wake loop'),
      );
      when(
        () => mockJournalDb.journalEntityById('project-1'),
      ).thenAnswer(
        (_) async =>
            makeTestProject(id: 'project-1', title: 'Platform Refresh'),
      );

      final container = createContainer();

      expect(
        await container.read(pendingWakeTargetTitleProvider('task-1').future),
        'Fix wake loop',
      );
      expect(
        await container.read(
          pendingWakeTargetTitleProvider('project-1').future,
        ),
        'Platform Refresh',
      );
    });

    test('returns null for unsupported journal entity types', () async {
      when(
        () => mockJournalDb.journalEntityById('entry-1'),
      ).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-1',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            dateFrom: kAgentTestDate,
            dateTo: kAgentTestDate,
          ),
        ),
      );

      final container = createContainer();

      expect(
        await container.read(pendingWakeTargetTitleProvider('entry-1').future),
        isNull,
      );
    });

    test(
      'returns null when no journal entity exists for the entry ID',
      () async {
        when(() => mockJournalDb.journalEntityById('missing')).thenAnswer(
          (_) async => null,
        );

        final container = createContainer();

        expect(
          await container.read(
            pendingWakeTargetTitleProvider('missing').future,
          ),
          isNull,
        );
      },
    );
  });

  group('hourlyWakeActivityProvider', () {
    test('groups wake runs by hour with reason breakdown', () async {
      final now = DateTime(2026, 4, 4, 14);
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();

      when(
        () => mockRepository.getWakeRunsInWindow(
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer(
        (_) async => [
          makeTestWakeRun(
            runKey: 'run-1',
            createdAt: DateTime(2026, 4, 4, 10, 5),
          ),
          makeTestWakeRun(
            runKey: 'run-2',
            createdAt: DateTime(2026, 4, 4, 10, 30),
          ),
          makeTestWakeRun(
            runKey: 'run-3',
            reason: 'creation',
            createdAt: DateTime(2026, 4, 4, 10, 45),
          ),
          makeTestWakeRun(
            runKey: 'run-4',
            createdAt: DateTime(2026, 4, 4, 12, 15),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final buckets = await withClock(
        Clock.fixed(now),
        () => container.read(hourlyWakeActivityProvider.future),
      );

      expect(buckets, hasLength(24));

      final hour10 = buckets.firstWhere(
        (b) => b.hour == DateTime(2026, 4, 4, 10),
      );
      expect(hour10.count, 3);
      expect(hour10.reasons['subscription'], 2);
      expect(hour10.reasons['creation'], 1);

      final hour12 = buckets.firstWhere(
        (b) => b.hour == DateTime(2026, 4, 4, 12),
      );
      expect(hour12.count, 1);
      expect(hour12.reasons['subscription'], 1);
    });

    test('returns empty buckets when no wake runs exist', () async {
      final now = DateTime(2026, 4, 4, 14);
      final mockRepository = MockAgentRepository();
      final notifications = UpdateNotifications();

      when(
        () => mockRepository.getWakeRunsInWindow(
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final buckets = await withClock(
        Clock.fixed(now),
        () => container.read(hourlyWakeActivityProvider.future),
      );

      expect(buckets, hasLength(24));
      expect(buckets.every((b) => b.count == 0), isTrue);
    });
  });
}
