import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  final testDate = DateTime(2026, 8, 16, 10);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockWakeOrchestrator orchestrator;
  late MockRelationshipRepository people;
  late RelationshipAgentService service;

  AgentIdentityEntity identity({
    AgentLifecycle lifecycle = AgentLifecycle.active,
    DateTime? userStoppedAt,
    AgentLifecycle? userStopLifecycle,
  }) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: lifecycle,
            userStoppedAt: userStoppedAt,
            userStopLifecycle: userStopLifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(automaticUpdatesEnabled: true),
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as AgentIdentityEntity;

  RelationshipEntry relationship({
    String title = 'Anna',
    DateTime? importantSince,
  }) => RelationshipEntry(
    meta: Metadata(
      id: relationshipId,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: title,
      important: true,
      importantSince: importantSince,
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
    people = MockRelationshipRepository();
    service = RelationshipAgentService(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
      relationshipRepository: people,
    );
    when(
      () => people.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async => relationship());
    when(
      () => people.openConflictVersions(relationshipId),
    ).thenAnswer((_) async => []);
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => repository.deletedAgentAt(any())).thenAnswer((_) async => null);
    when(() => repository.forgetDeletedAgent(any())).thenAnswer((_) async {});
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

      expect(created!.agentId, agentId);
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

      expect(returned!.agentId, agentId);
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

    test('a renamed person is written through to the existing identity — '
        'the chat page titles itself from the stored displayName, so the '
        'fast path must not leave it stale', () async {
      when(
        () => repository.getEntity(agentId),
      ).thenAnswer((_) async => identity());

      final returned = await withClock(
        Clock.fixed(testDate),
        () => service.ensureAgentForRelationship(
          relationship(title: 'Anna Schmidt'),
        ),
      );

      expect(returned!.displayName, 'Anna Schmidt');
      final renamed = verify(
        () => syncService.upsertEntity(captureAny()),
      ).captured.whereType<AgentIdentityEntity>().single;
      expect(renamed.displayName, 'Anna Schmidt');
      expect(renamed.updatedAt, testDate);
      // Still the fast path: no re-creation, no duplicate link or tick.
      verifyNever(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: any(named: 'agentId'),
        ),
      );
      verifyNever(() => syncService.upsertLink(any()));
    });
  });

  group('an agent this device deleted (ADR 0111)', () {
    final deletedAt = testDate.subtract(const Duration(days: 1));

    void verifyNotCreated() => verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        agentId: any(named: 'agentId'),
      ),
    );

    setUp(() {
      when(
        () => repository.deletedAgentAt(agentId),
      ).thenAnswer((_) async => deletedAt);
    });

    test('is not created again by the background ensure while the stored '
        'mark is older than the delete', () async {
      when(
        () => people.getRelationshipByIdUnfiltered(relationshipId),
      ).thenAnswer(
        (_) async => relationship(
          importantSince: deletedAt.subtract(const Duration(hours: 1)),
        ),
      );

      final created = await service.ensureAgentForRelationship(
        relationship(),
      );

      expect(created, isNull);
      verifyNotCreated();
      verifyNever(() => repository.forgetDeletedAgent(any()));
      verifyNever(() => orchestrator.addSubscription(any()));
    });

    test('is created again by the background ensure for a mark newer than '
        'the delete, read from the stored person — the caller holds the '
        'copy from before the save stamped it', () async {
      when(
        () => people.getRelationshipByIdUnfiltered(relationshipId),
      ).thenAnswer(
        (_) async => relationship(
          importantSince: deletedAt.add(const Duration(hours: 1)),
        ),
      );

      final created = await service.ensureAgentForRelationship(
        relationship(),
      );

      expect(created, isNotNull);
      verifyInOrder([
        () => repository.forgetDeletedAgent(agentId),
        () => agentService.createAgent(
          kind: AgentKinds.relationshipAgent,
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: agentId,
        ),
      ]);
      // A mark outranks the delete's stop on every device by itself.
      verifyNever(
        () => agentService.resumeAgent(any(), byUser: any(named: 'byUser')),
      );
      verify(() => orchestrator.addSubscription(any())).called(1);
    });

    test('is not created again while the person has an open conflict, even '
        'for a newer mark', () async {
      final marked = relationship(
        importantSince: deletedAt.add(const Duration(hours: 1)),
      );
      when(
        () => people.getRelationshipByIdUnfiltered(relationshipId),
      ).thenAnswer((_) async => marked);
      when(
        () => people.openConflictVersions(relationshipId),
      ).thenAnswer((_) async => [marked]);

      expect(await service.ensureAgentForRelationship(marked), isNull);
      verifyNotCreated();
    });

    test("Brief me brings it back as the user's resume, so no device's pass "
        'stops it again, and queues the briefing', () async {
      when(
        () => agentService.resumeAgent(agentId, byUser: true),
      ).thenAnswer((_) async => true);
      when(
        () => orchestrator.enqueueManualWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
        ),
      ).thenReturn('brief-run-1');

      await service.requestBriefing(relationship());

      verifyInOrder([
        () => repository.forgetDeletedAgent(agentId),
        () => agentService.createAgent(
          kind: AgentKinds.relationshipAgent,
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: agentId,
        ),
        () => agentService.resumeAgent(agentId, byUser: true),
      ]);
      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: 'brief me',
          triggerTokens: {relationshipReportRefreshTriggerToken},
        ),
      ).called(1);
    });
  });

  group('reconcileAgent (ADR 0111)', () {
    final markedAt = testDate.subtract(const Duration(days: 2));

    void stubRuntimeStops() {
      when(() => agentService.cancelPendingWake(agentId)).thenAnswer((_) {});
      when(() => agentService.abortRunningWake(agentId)).thenReturn(false);
    }

    test('creates the agent a lost background ensure never wrote', () async {
      await service.reconcileAgent(relationship(importantSince: markedAt));

      verify(
        () => agentService.createAgent(
          kind: AgentKinds.relationshipAgent,
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: agentId,
        ),
      ).called(1);
      verify(() => orchestrator.addSubscription(any())).called(1);
    });

    test('creates it again over a delete older than the mark, forgetting '
        'the delete first so sync accepts the agent here again', () async {
      // The table forgets the delete, as the real one does.
      DateTime? deletedAt = markedAt.subtract(const Duration(hours: 1));
      when(
        () => repository.deletedAgentAt(agentId),
      ).thenAnswer((_) async => deletedAt);
      when(() => repository.forgetDeletedAgent(agentId)).thenAnswer((_) async {
        deletedAt = null;
      });

      when(
        () => people.getRelationshipByIdUnfiltered(relationshipId),
      ).thenAnswer((_) async => relationship(importantSince: markedAt));

      await service.reconcileAgent(relationship(importantSince: markedAt));

      verifyInOrder([
        () => repository.forgetDeletedAgent(agentId),
        () => agentService.createAgent(
          kind: AgentKinds.relationshipAgent,
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: agentId,
        ),
      ]);
    });

    test('leaves a delete newer than the mark alone', () async {
      when(() => repository.deletedAgentAt(agentId)).thenAnswer(
        (_) async => markedAt.add(const Duration(hours: 1)),
      );

      await service.reconcileAgent(relationship(importantSince: markedAt));

      verifyNever(() => repository.forgetDeletedAgent(any()));
      verifyNever(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          agentId: any(named: 'agentId'),
        ),
      );
    });

    test('brings back an agent the system destroyed — the reaper or the '
        'cascade — and puts it back on every wake path', () async {
      when(() => repository.getEntity(agentId)).thenAnswer(
        (_) async => identity(lifecycle: AgentLifecycle.destroyed),
      );
      when(
        () => agentService.resumeAgent(agentId),
      ).thenAnswer((_) async => true);

      await service.reconcileAgent(relationship(importantSince: markedAt));

      verify(() => agentService.resumeAgent(agentId)).called(1);
      verify(() => orchestrator.addSubscription(any())).called(1);
      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: any(named: 'reason'),
        ),
      ).called(1);
    });

    test("restores the user's destroy over a merge that left the agent "
        'active', () async {
      stubRuntimeStops();
      when(() => repository.getEntity(agentId)).thenAnswer(
        (_) async => identity(
          userStoppedAt: markedAt.add(const Duration(hours: 1)),
          userStopLifecycle: AgentLifecycle.destroyed,
        ),
      );
      when(
        () => agentService.destroyAgent(agentId),
      ).thenAnswer((_) async => true);

      await service.reconcileAgent(relationship(importantSince: markedAt));

      verify(() => agentService.destroyAgent(agentId)).called(1);
      verify(() => agentService.cancelPendingWake(agentId)).called(1);
      verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
    });

    test("restores the user's pause the same way", () async {
      stubRuntimeStops();
      when(() => repository.getEntity(agentId)).thenAnswer(
        (_) async => identity(
          userStoppedAt: markedAt.add(const Duration(hours: 1)),
          userStopLifecycle: AgentLifecycle.dormant,
        ),
      );
      when(
        () => agentService.pauseAgent(agentId),
      ).thenAnswer((_) async => true);

      await service.reconcileAgent(relationship(importantSince: markedAt));

      verify(() => agentService.pauseAgent(agentId)).called(1);
      verify(() => orchestrator.removeSubscriptions(agentId)).called(1);
    });

    test('an agent already where the user left it is not written', () async {
      when(
        () => repository.getEntity(agentId),
      ).thenAnswer((_) async => identity());

      await service.reconcileAgent(relationship(importantSince: markedAt));

      verifyNever(() => agentService.resumeAgent(any()));
      verifyNever(() => agentService.pauseAgent(any()));
      verifyNever(() => agentService.destroyAgent(any()));
    });

    test('an open conflict holds back a revive', () async {
      when(() => repository.getEntity(agentId)).thenAnswer(
        (_) async => identity(lifecycle: AgentLifecycle.destroyed),
      );

      await service.reconcileAgent(
        relationship(importantSince: markedAt),
        conflicting: [relationship(importantSince: markedAt)],
      );

      verifyNever(() => agentService.resumeAgent(any()));
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

  test('requestBriefing ensures the agent exists, then routes ONE manual '
      'wake through the LLM tier via the report-refresh token', () async {
    // The agent already exists: the ensure step is the fast path.
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => identity());
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn('brief-run-1');

    await withClock(
      Clock.fixed(testDate),
      () => service.requestBriefing(relationship()),
    );

    verifyNever(
      () => agentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        agentId: any(named: 'agentId'),
      ),
    );
    final captured = verify(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
        reason: any(named: 'reason'),
        triggerTokens: captureAny(named: 'triggerTokens'),
      ),
    ).captured;
    expect(
      captured.whereType<Set<String>>().where(
        (tokens) => tokens.contains(relationshipReportRefreshTriggerToken),
      ),
      hasLength(1),
      reason: 'exactly ONE wake carries the report-refresh token',
    );
  });

  group('ensureRelationshipAgentInBackground', () {
    final important = testRelationship.copyWith(
      data: testRelationship.data.copyWith(important: true),
    );

    test('logs a failure with its stack trace, naming only the sanitized '
        'relationship id', () async {
      final service = MockRelationshipAgentService();
      final logger = MockDomainLogger();
      when(
        () => service.ensureAgentForRelationship(important),
      ).thenThrow(StateError('agent db closed'));

      ensureRelationshipAgentInBackground(
        service,
        important,
        source: 'RelationshipFormModal',
        domainLogger: logger,
      );
      await pumpEventQueue();

      final message =
          verify(
                () => logger.error(
                  LogDomain.agentWorkflow,
                  any<Object>(that: isA<StateError>()),
                  stackTrace: any(named: 'stackTrace', that: isNotNull),
                  subDomain: 'RelationshipFormModal',
                  message: captureAny(named: 'message'),
                ),
              ).captured.single
              as String;
      expect(message, contains(DomainLogger.sanitizeId(important.id)));
      expect(message, isNot(contains(important.id)));
    });

    test('does nothing for a relationship that is not important', () async {
      final service = MockRelationshipAgentService();

      ensureRelationshipAgentInBackground(
        service,
        testRelationship,
        source: 'RelationshipFormModal',
        domainLogger: MockDomainLogger(),
      );
      await pumpEventQueue();

      verifyZeroInteractions(service);
    });
  });
}
