import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  final testDate = DateTime(2026, 8, 16, 10);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockWakeOrchestrator orchestrator;
  late RelationshipAgentService service;

  AgentIdentityEntity identity() =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as AgentIdentityEntity;

  RelationshipEntry relationship() => RelationshipEntry(
    meta: Metadata(
      id: relationshipId,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: 'Anna',
      important: true,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    orchestrator = MockWakeOrchestrator();
    service = RelationshipAgentService(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
    );
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => syncService.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        agentId: any(named: 'agentId'),
      ),
    ).thenAnswer((_) async => identity());
    when(() => orchestrator.removeSubscriptions(any())).thenAnswer((_) {});
    when(() => orchestrator.addSubscription(any())).thenAnswer((_) {});
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
      ),
    ).thenReturn('manual-run-1');
  });

  group('ensureAgentForRelationship', () {
    test('creates identity, deterministic link, and the first cadence tick, '
        'then subscribes and queues one immediate €0 evaluation', () async {
      final created = await withClock(
        Clock.fixed(testDate),
        () => service.ensureAgentForRelationship(relationship()),
      );

      expect(created.agentId, agentId);
      verify(
        () => agentService.createAgent(
          kind: AgentKinds.relationshipAgent,
          displayName: 'Anna',
          config: any(named: 'config'),
          agentId: agentId,
        ),
      ).called(1);

      final link =
          verify(() => syncService.upsertLink(captureAny())).captured.single
              as AgentRelationshipLink;
      expect(link.id, relationshipAgentLinkId(agentId));
      expect(link.fromId, agentId);
      expect(link.toId, relationshipId);

      final wake =
          verify(() => syncService.upsertEntity(captureAny())).captured.single
              as ScheduledWakeEntity;
      expect(wake.workspaceKey, relationshipCadenceWorkspaceKey);

      final subscription =
          verify(
                () => orchestrator.addSubscription(captureAny()),
              ).captured.single
              as AgentSubscription;
      expect(subscription.id, relationshipSignalSubscriptionId(agentId));
      expect(subscription.matchEntityIds, {relationshipId});
      expect(
        subscription.drainImmediately,
        isTrue,
        reason: 'Phase A is €0 — a check-in evaluates immediately',
      );
      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: any(named: 'reason'),
        ),
      ).called(1);
    });

    test('is idempotent: an existing identity short-circuits creation but '
        'still refreshes the subscription and evaluation', () async {
      when(
        () => repository.getEntity(agentId),
      ).thenAnswer((_) async => identity());

      final returned = await withClock(
        Clock.fixed(testDate),
        () => service.ensureAgentForRelationship(relationship()),
      );

      expect(returned.agentId, agentId);
      verifyNever(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: any(named: 'agentId'),
        ),
      );
      verifyNever(() => syncService.upsertLink(any()));
      verifyNever(() => syncService.upsertEntity(any()));
      verify(() => orchestrator.addSubscription(any())).called(1);
      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: any(named: 'reason'),
        ),
      ).called(1);
    });
  });

  group('registerSubscription', () {
    test('resolves the relationship via the agent link when no id is '
        'passed, and replaces rather than accumulates', () async {
      when(
        () => repository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentRelationship,
        ),
      ).thenAnswer(
        (_) async => [
          AgentLink.agentRelationship(
            id: relationshipAgentLinkId(agentId),
            fromId: agentId,
            toId: relationshipId,
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );
      await service.registerSubscription(agentId);
      verifyInOrder([
        () => orchestrator.removeSubscriptions(agentId),
        () => orchestrator.addSubscription(any()),
      ]);
    });

    test('an agent with no link subscribes to nothing', () async {
      when(
        () => repository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentRelationship,
        ),
      ).thenAnswer((_) async => []);
      await service.registerSubscription(agentId);
      verifyNever(() => orchestrator.addSubscription(any()));
    });
  });

  group('handleRelationshipDeleted', () {
    test('destroys the agent, cancels its wakes, and unsubscribes — the '
        'cascade leg (ADR 0059 Decision 7)', () async {
      when(
        () => repository.getEntity(agentId),
      ).thenAnswer((_) async => identity());
      when(
        () => agentService.destroyAgent(agentId),
      ).thenAnswer((_) async => true);
      when(() => agentService.cancelPendingWake(agentId)).thenAnswer((_) {});
      when(() => agentService.abortRunningWake(agentId)).thenReturn(false);

      expect(await service.handleRelationshipDeleted(relationshipId), isTrue);
      verify(() => agentService.destroyAgent(agentId)).called(1);
      verify(() => agentService.cancelPendingWake(agentId)).called(1);
      verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
    });

    test(
      'a person who never had an agent is a no-op returning false',
      () async {
        expect(
          await service.handleRelationshipDeleted(relationshipId),
          isFalse,
        );
        verifyNever(() => agentService.destroyAgent(any()));
      },
    );
  });
}
