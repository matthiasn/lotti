import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';
import 'package:lotti/features/goals/service/goal_measurable_capture_service.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// Runs agent-store transactions inline so writes land on the mock.
class _TransactionalSyncService extends MockAgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();
}

/// Runs journal transactions inline.
class _PassThroughJournalDb extends MockJournalDb {
  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) => action();
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('goalMeasurableCaptureServiceProvider', () {
    late _TransactionalSyncService syncService;
    late MockPersistenceLogic persistenceLogic;

    setUp(() async {
      syncService = _TransactionalSyncService();
      persistenceLogic = MockPersistenceLogic();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..unregister<JournalDb>()
            ..registerSingleton<JournalDb>(_PassThroughJournalDb())
            ..registerSingleton<PersistenceLogic>(persistenceLogic);
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('records through the agent store of the scope and the journal of '
        'the app', () async {
      final upserts = <AgentDomainEntity>[];
      when(() => syncService.upsertEntity(any())).thenAnswer(
        (invocation) async => upserts.add(
          invocation.positionalArguments.first as AgentDomainEntity,
        ),
      );
      when(
        () => persistenceLogic.createMeasurementEntry(
          data: any(named: 'data'),
          private: any(named: 'private'),
          comment: any(named: 'comment'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data]! as MeasurementData;
        return MeasurementEntry(
          meta: Metadata(
            id: 'measurement-krill',
            createdAt: data.dateFrom,
            updatedAt: data.dateFrom,
            dateFrom: data.dateFrom,
            dateTo: data.dateTo,
          ),
          data: data,
        );
      });
      final container = ProviderContainer(
        overrides: [agentSyncServiceProvider.overrideWithValue(syncService)],
      );
      addTearDown(container.dispose);

      final ids = await container
          .read(goalMeasurableCaptureServiceProvider)
          .record(
            agentId: 'goal-1',
            agentName: 'Pip',
            offer: const GoalMeasurableRecordOffer(
              sourceMessageId: 'source-krill',
              dataTypeId: 'krill-kg',
              measurableName: 'Krill sorted',
              unitName: 'kg',
              items: [],
            ),
            items: [
              GoalMeasurableRecordItem(
                day: DateTime(2026, 8, 11),
                value: 12,
                estimated: false,
              ),
            ],
            private: false,
            provenanceComment: 'Logged from a goal check-in',
          );

      expect(ids, ['measurement-krill']);
      expect(
        upserts.whereType<AgentMessageEntity>().single.metadata.toolName,
        GoalMeasurableCaptureToolNames.recorded,
      );
    });
  });

  test('the newest decision for a source message wins', () async {
    final repository = MockAgentRepository();
    final older = DateTime(2026, 8, 11, 9);
    final newer = DateTime(2026, 8, 11, 10);
    AgentMessageEntity action({
      required String id,
      required String payloadId,
      required String toolName,
      required DateTime createdAt,
    }) =>
        AgentDomainEntity.agentMessage(
              id: id,
              agentId: 'goal-1',
              threadId: 'thread-1',
              kind: AgentMessageKind.action,
              createdAt: createdAt,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: AgentMessageMetadata(toolName: toolName),
            )
            as AgentMessageEntity;
    final recorded = action(
      id: 'recorded',
      payloadId: 'payload-recorded',
      toolName: GoalMeasurableCaptureToolNames.recorded,
      createdAt: older,
    );
    final dismissed = action(
      id: 'dismissed',
      payloadId: 'payload-dismissed',
      toolName: GoalMeasurableCaptureToolNames.dismissed,
      createdAt: newer,
    );
    when(
      () => repository.getEntitiesByAgentId(
        'goal-1',
        type: AgentEntityTypes.agentMessage,
      ),
    ).thenAnswer((_) async => [dismissed, recorded]);
    when(() => repository.getEntitiesByIds(any())).thenAnswer(
      (_) async => {
        for (final id in ['payload-dismissed', 'payload-recorded'])
          id: AgentDomainEntity.agentMessagePayload(
            id: id,
            agentId: 'goal-1',
            createdAt: id == 'payload-dismissed' ? newer : older,
            vectorClock: null,
            content: {
              'sourceMessageId': 'source-1',
              if (id == 'payload-recorded') 'entryIds': ['measurement-1'],
            },
          ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(repository),
        agentUpdateStreamProvider(
          'goal-1',
        ).overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);

    final decisions = await container.read(
      goalMeasurableCaptureDecisionsProvider('goal-1').future,
    );

    expect(decisions['source-1']?.recorded, isFalse);
    expect(decisions['source-1']?.recordedAt, newer);
  });

  test('a recorded decision counts only the string entry ids it saved and '
      'keeps the agent name it was recorded under', () async {
    final repository = MockAgentRepository();
    final at = DateTime(2026, 8, 11, 9);
    final recorded =
        AgentDomainEntity.agentMessage(
              id: 'recorded',
              agentId: 'goal-1',
              threadId: 'thread-1',
              kind: AgentMessageKind.action,
              createdAt: at,
              vectorClock: null,
              contentEntryId: 'payload-recorded',
              metadata: const AgentMessageMetadata(
                toolName: GoalMeasurableCaptureToolNames.recorded,
              ),
            )
            as AgentMessageEntity;
    when(
      () => repository.getEntitiesByAgentId(
        'goal-1',
        type: AgentEntityTypes.agentMessage,
      ),
    ).thenAnswer((_) async => [recorded]);
    when(() => repository.getEntitiesByIds(any())).thenAnswer(
      (_) async => {
        'payload-recorded': AgentDomainEntity.agentMessagePayload(
          id: 'payload-recorded',
          agentId: 'goal-1',
          createdAt: at,
          vectorClock: null,
          content: {
            'sourceMessageId': 'source-1',
            'entryIds': ['measurement-1', 42, 'measurement-2'],
            'agentName': 'Juno',
          },
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(repository),
        agentUpdateStreamProvider(
          'goal-1',
        ).overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);

    final decisions = await container.read(
      goalMeasurableCaptureDecisionsProvider('goal-1').future,
    );

    final decision = decisions['source-1']!;
    expect(decision.recorded, isTrue);
    expect(decision.entryIds, ['measurement-1', 'measurement-2']);
    expect(decision.entryCount, 2);
    expect(decision.agentName, 'Juno');
    expect(decision.recordedAt, at);
  });
}
