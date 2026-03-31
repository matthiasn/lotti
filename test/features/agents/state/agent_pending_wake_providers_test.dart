import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
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

  group('pendingWakeTargetTitleProvider', () {
    late MockJournalDb mockJournalDb;

    setUp(() {
      mockJournalDb = MockJournalDb();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockJournalDb),
        ],
      );
      addTearDown(container.dispose);
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
}
