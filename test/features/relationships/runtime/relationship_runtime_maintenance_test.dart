import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'relationship_agent:person-1';
  final testDate = DateTime(2026, 8, 1, 9);
  final now = DateTime(2026, 8, 16, 12);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockRelationshipAgentService relationshipAgentService;
  late MockDomainLogger logger;
  late RelationshipRuntimeMaintenance maintenance;

  AgentIdentityEntity identity({
    String kind = AgentKinds.relationshipAgent,
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: kind,
            displayName: 'Anna',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as AgentIdentityEntity;

  String cadenceRecordId() => scheduledWakeRecordId(
    agentId,
    workspaceKey: relationshipCadenceWorkspaceKey,
  );

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    relationshipAgentService = MockRelationshipAgentService();
    logger = MockDomainLogger();
    maintenance = RelationshipRuntimeMaintenance(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      relationshipAgentService: relationshipAgentService,
      domainLogger: logger,
    );
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity()]);
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => relationshipAgentService.registerSubscription(any()),
    ).thenAnswer((_) async {});
  });

  group('restoreSubscriptions', () {
    test('re-registers every active relationship agent and ignores other '
        'kinds', () async {
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer(
        (_) async => [identity(), identity(kind: AgentKinds.goalAgent)],
      );
      await maintenance.restoreSubscriptions();
      verify(
        () => relationshipAgentService.registerSubscription(agentId),
      ).called(1);
      verifyNoMoreInteractions(relationshipAgentService);
    });

    test('a listAgents failure is contained and logged', () async {
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenThrow(StateError('db closed'));
      await expectLater(maintenance.restoreSubscriptions(), completes);
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          message: any(
            named: 'message',
            that: contains('restoreSubscriptions'),
          ),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('one broken agent never takes the pass down', () async {
      when(
        () => relationshipAgentService.registerSubscription(agentId),
      ).thenThrow(StateError('broken'));
      await expectLater(maintenance.restoreSubscriptions(), completes);
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          message: any(
            named: 'message',
            that: contains('restoreSubscriptions'),
          ),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('beforeWakeScan self-heals the cadence record', () {
    test('a missing record is re-armed', () async {
      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);
      final written =
          verify(() => syncService.upsertEntity(captureAny())).captured.single
              as ScheduledWakeEntity;
      expect(written.id, cadenceRecordId());
      expect(written.status, ScheduledWakeStatus.pending);
    });

    test('a consumed record whose instant passed is re-armed; a healthy '
        'pending one is left alone', () async {
      final pending =
          relationshipCadenceWake(agentId, now) as ScheduledWakeEntity;
      when(
        () => repository.getEntity(cadenceRecordId()),
      ).thenAnswer((_) async => pending);
      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);
      verifyNever(() => syncService.upsertEntity(any()));

      when(() => repository.getEntity(cadenceRecordId())).thenAnswer(
        (_) async => pending.copyWith(
          status: ScheduledWakeStatus.consumed,
          scheduledAt: now.subtract(const Duration(hours: 2)),
        ),
      );
      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);
      verify(() => syncService.upsertEntity(any())).called(1);
    });

    test('a per-agent repair failure is contained and logged', () async {
      when(() => repository.getEntity(any())).thenThrow(StateError('broken'));
      await expectLater(maintenance.beforeWakeScan(), completes);
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          message: any(named: 'message', that: contains('beforeWakeScan')),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('a listAgents failure is contained and logged', () async {
      when(
        () => agentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenThrow(StateError('db closed'));
      await expectLater(maintenance.beforeWakeScan(), completes);
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          message: any(named: 'message', that: contains('beforeWakeScan')),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('onIdentityReceived', () {
    test('an active synced-in identity subscribes immediately — no restart '
        'needed', () async {
      await maintenance.onIdentityReceived(identity());
      verify(
        () => relationshipAgentService.registerSubscription(agentId),
      ).called(1);
    });

    test('a non-active identity is unsubscribed', () async {
      await maintenance.onIdentityReceived(
        identity(lifecycle: AgentLifecycle.destroyed),
      );
      verify(
        () => relationshipAgentService.removeSubscription(agentId),
      ).called(1);
      verifyNever(() => relationshipAgentService.registerSubscription(any()));
    });

    test('another kind is ignored entirely', () async {
      await maintenance.onIdentityReceived(
        identity(kind: AgentKinds.goalAgent),
      );
      verifyZeroInteractions(relationshipAgentService);
    });

    test('a subscription failure is contained — the sync apply loop must '
        'never stall on one agent', () async {
      when(
        () => relationshipAgentService.registerSubscription(agentId),
      ).thenThrow(StateError('broken'));
      await expectLater(maintenance.onIdentityReceived(identity()), completes);
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          message: any(named: 'message', that: contains('onIdentityReceived')),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
