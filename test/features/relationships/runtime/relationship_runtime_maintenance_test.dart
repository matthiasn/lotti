import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/sync/agent_replica_bench.dart';
import '../../agents/test_data/entity_factories.dart';

part 'relationship_agent_lifecycle_model_conformance.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  _registerRelationshipAgentLifecycleConformance();

  const agentId = 'relationship_agent:person-1';
  final testDate = DateTime(2026, 8, 1, 9);
  final now = DateTime(2026, 8, 16, 12);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockRelationshipAgentService relationshipAgentService;
  late MockRelationshipRepository relationshipRepository;
  late MockDomainLogger logger;
  late RelationshipRuntimeMaintenance maintenance;
  late int scanRequests;

  const relationshipId = 'person-1';

  RelationshipEntry person({DateTime? deletedAt}) => RelationshipEntry(
    meta: Metadata(
      id: relationshipId,
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
      deletedAt: deletedAt,
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
    relationshipRepository = MockRelationshipRepository();
    logger = MockDomainLogger();
    scanRequests = 0;
    maintenance = RelationshipRuntimeMaintenance(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      relationshipAgentService: relationshipAgentService,
      relationshipRepository: relationshipRepository,
      domainLogger: logger,
      onIdentityRestored: () => scanRequests++,
    );
    when(
      () => agentService.listAgents(lifecycle: AgentLifecycle.active),
    ).thenAnswer((_) async => [identity()]);
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => relationshipAgentService.registerSubscription(any()),
    ).thenAnswer((_) async {});
    when(
      () => relationshipAgentService.watchedRelationshipId(agentId),
    ).thenAnswer((_) async => relationshipId);
    when(
      () => relationshipAgentService.handleRelationshipDeleted(any()),
    ).thenAnswer((_) async => true);
    when(
      () => relationshipRepository.isRelationshipDeleted(relationshipId),
    ).thenAnswer((_) async => false);
    // The reconcile pass has no people to visit unless a test lists some.
    when(
      () => relationshipRepository.getAllRelationshipsUnfiltered(),
    ).thenAnswer((_) async => []);
    when(
      () => relationshipRepository.openConflictVersions(any()),
    ).thenAnswer((_) async => []);
    when(
      () => relationshipAgentService.reconcileAgent(
        any(),
        conflicting: any(named: 'conflicting'),
      ),
    ).thenAnswer((_) async {});
  });

  test('a stale failure count beside a newer completed wake is not backed '
      'off: the count is last-writer-wins across devices, the outcome '
      'watermarks are not (ADR 0115)', () async {
    final workspace = relationshipEscalationWorkspaceKey('2026-08-08');
    final retry =
        AgentDomainEntity.scheduledWake(
              id: scheduledWakeRecordId(agentId, workspaceKey: workspace),
              agentId: agentId,
              scheduledAt: now.add(const Duration(hours: 8)),
              status: ScheduledWakeStatus.pending,
              reason: WakeReason.scheduled.name,
              updatedAt: testDate,
              vectorClock: null,
              workspaceKey: workspace,
              triggerTokens: [workspace],
            )
            as ScheduledWakeEntity;
    when(() => repository.getAgentState(agentId)).thenAnswer(
      (_) async => makeTestState(
        agentId: agentId,
        lastWakeAt: now.subtract(const Duration(hours: 1)),
        lastWakeFailedAt: now.subtract(const Duration(hours: 2)),
        consecutiveFailureCount: 3,
      ),
    );
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'scheduledWake'),
    ).thenAnswer((_) async => [retry]);
    when(() => repository.getEntity(retry.id)).thenAnswer((_) async => retry);
    final subject = RelationshipRuntimeMaintenance(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      relationshipAgentService: relationshipAgentService,
      relationshipRepository: relationshipRepository,
      inferenceIsConfigured: (_) async => true,
    );

    await withClock(Clock.fixed(now), subject.beforeWakeScan);

    verifyNever(
      () => syncService.upsertEntity(
        any(
          that: isA<ScheduledWakeEntity>().having(
            (e) => e.id,
            'id',
            retry.id,
          ),
        ),
      ),
    );
  });

  test('a row written before the failed watermark existed — a count above '
      'zero, no failed stamp (1.1.35) — is still backed off: the repair '
      'brings its retry forward by the count, which only shortens a '
      'deadline (ADR 0115)', () async {
    final workspace = relationshipEscalationWorkspaceKey('2026-08-08');
    final retry =
        AgentDomainEntity.scheduledWake(
              id: scheduledWakeRecordId(agentId, workspaceKey: workspace),
              agentId: agentId,
              scheduledAt: now.add(const Duration(hours: 8)),
              status: ScheduledWakeStatus.pending,
              reason: WakeReason.scheduled.name,
              updatedAt: testDate,
              vectorClock: null,
              workspaceKey: workspace,
              triggerTokens: [workspace],
            )
            as ScheduledWakeEntity;
    // 1.1.35 stamped `lastWakeAt` either way and bumped the count; it never
    // wrote `lastWakeFailedAt`.
    when(() => repository.getAgentState(agentId)).thenAnswer(
      (_) async => makeTestState(
        agentId: agentId,
        lastWakeAt: now.subtract(const Duration(hours: 1)),
        consecutiveFailureCount: 2,
      ),
    );
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'scheduledWake'),
    ).thenAnswer((_) async => [retry]);
    when(() => repository.getEntity(retry.id)).thenAnswer((_) async => retry);
    final subject = RelationshipRuntimeMaintenance(
      agentService: agentService,
      repository: repository,
      syncService: syncService,
      relationshipAgentService: relationshipAgentService,
      relationshipRepository: relationshipRepository,
      inferenceIsConfigured: (_) async => true,
    );

    await withClock(Clock.fixed(now), subject.beforeWakeScan);

    final written =
        verify(
              () => syncService.upsertEntity(
                captureAny(
                  that: isA<ScheduledWakeEntity>().having(
                    (e) => e.id,
                    'id',
                    retry.id,
                  ),
                ),
              ),
            ).captured.single
            as ScheduledWakeEntity;
    expect(written.scheduledAt, now.toUtc());
    expect(written.status, ScheduledWakeStatus.pending);
    expect(written.triggerTokens, retry.triggerTokens);
  });

  test(
    'configured retry moves forward without losing episode tokens or lease election',
    () async {
      final workspace = relationshipEscalationWorkspaceKey('2026-08-08');
      var configured = false;
      final retry =
          AgentDomainEntity.scheduledWake(
                id: scheduledWakeRecordId(agentId, workspaceKey: workspace),
                agentId: agentId,
                scheduledAt: now.add(const Duration(hours: 8)),
                status: ScheduledWakeStatus.pending,
                reason: WakeReason.scheduled.name,
                updatedAt: testDate,
                vectorClock: null,
                workspaceKey: workspace,
                triggerTokens: [workspace, 'baseline'],
                leaseHostId: 'old-host',
                leaseUntil: now.add(const Duration(minutes: 5)),
              )
              as ScheduledWakeEntity;
      // Backed off: the last wake failed, by the outcome watermarks every
      // device agrees on — not by the failure count, which is
      // last-writer-wins with the row (ADR 0115).
      when(() => repository.getAgentState(agentId)).thenAnswer(
        (_) async => makeTestState(
          agentId: agentId,
          lastWakeAt: now.subtract(const Duration(hours: 2)),
          lastWakeFailedAt: now.subtract(const Duration(hours: 1)),
          consecutiveFailureCount: 3,
        ),
      );
      when(
        () => repository.getEntitiesByAgentId(agentId, type: 'scheduledWake'),
      ).thenAnswer((_) async => [retry]);
      var inTransaction = false;
      syncService.transactionDelegate = <T>(action) async {
        inTransaction = true;
        try {
          return await action();
        } finally {
          inTransaction = false;
        }
      };
      when(() => repository.getEntity(retry.id)).thenAnswer((_) async {
        expect(
          inTransaction,
          isTrue,
          reason: 'The consume check and reschedule must be atomic',
        );
        return retry;
      });
      final subject = RelationshipRuntimeMaintenance(
        agentService: agentService,
        repository: repository,
        syncService: syncService,
        relationshipAgentService: relationshipAgentService,
        relationshipRepository: relationshipRepository,
        inferenceIsConfigured: (_) async => configured,
      );
      await withClock(Clock.fixed(now), subject.beforeWakeScan);
      verifyNever(
        () => syncService.upsertEntity(
          any(
            that: isA<ScheduledWakeEntity>().having(
              (e) => e.id,
              'id',
              retry.id,
            ),
          ),
        ),
      );
      configured = true;
      await withClock(Clock.fixed(now), subject.beforeWakeScan);
      final written =
          verify(
                () => syncService.upsertEntity(
                  captureAny(
                    that: isA<ScheduledWakeEntity>().having(
                      (e) => e.id,
                      'id',
                      retry.id,
                    ),
                  ),
                ),
              ).captured.single
              as ScheduledWakeEntity;
      expect(written.scheduledAt, now.toUtc());
      expect(written.triggerTokens, retry.triggerTokens);
      expect(written.workspaceKey, workspace);
      expect(written.status, ScheduledWakeStatus.pending);
      expect(written.leaseHostId, isNull);
      expect(written.leaseUntil, isNull);
      // A peer consumed it while the route was resolving: never resurrect it.
      when(() => repository.getEntity(retry.id)).thenAnswer(
        (_) async => retry.copyWith(status: ScheduledWakeStatus.consumed),
      );
      await withClock(Clock.fixed(now), subject.beforeWakeScan);
      verifyNever(
        () => syncService.upsertEntity(
          any(
            that: isA<ScheduledWakeEntity>().having(
              (e) => e.id,
              'id',
              retry.id,
            ),
          ),
        ),
      );
    },
  );

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

  group('beforeWakeScan reaps an agent whose person is gone', () {
    test('a tombstoned relationship tears the agent down instead of '
        're-arming it — the orphan would otherwise wake forever', () async {
      when(
        () => relationshipRepository.isRelationshipDeleted(relationshipId),
      ).thenAnswer((_) async => true);

      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);

      verify(
        () => relationshipAgentService.handleRelationshipDeleted(
          relationshipId,
        ),
      ).called(1);
      // The heal below the reap must not run: re-arming the cadence is
      // exactly what kept the orphan alive.
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test(
      'a person that has not arrived yet is NOT reaped: the agent and its '
      'link sync apart from the journal, and reaping here destroyed the '
      'agent on every device (ADR 0111, NoReapOfLivePerson)',
      () async {
        // isRelationshipDeleted is false for a person with no row at all.
        await withClock(Clock.fixed(now), maintenance.beforeWakeScan);

        verifyNever(
          () => relationshipAgentService.handleRelationshipDeleted(any()),
        );
        verify(() => syncService.upsertEntity(any())).called(1);
      },
    );

    test('an agent whose link is not written yet is left alone — that is '
        'the creation race, not a deletion', () async {
      when(
        () => relationshipAgentService.watchedRelationshipId(agentId),
      ).thenAnswer((_) async => null);

      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);

      verifyNever(
        () => relationshipAgentService.handleRelationshipDeleted(any()),
      );
      verifyNever(
        () => relationshipRepository.isRelationshipDeleted(any()),
      );
      verify(() => syncService.upsertEntity(any())).called(1);
    });

    test(
      'a reap failure is contained and logged like any other repair',
      () async {
        when(
          () => relationshipRepository.isRelationshipDeleted(relationshipId),
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
      },
    );
  });

  group('beforeWakeScan reconciles every live person (ADR 0111)', () {
    RelationshipEntry another(String id, {bool private = false}) =>
        person().copyWith(
          meta: person().meta.copyWith(id: id, private: private),
        );

    test('each live person, private ones included, is reconciled with the '
        'versions it holds as open conflicts', () async {
      final anna = person();
      final ben = another('person-2', private: true);
      final annaConflict = another(relationshipId);
      when(
        () => relationshipRepository.getAllRelationshipsUnfiltered(),
      ).thenAnswer((_) async => [anna, ben]);
      when(
        () => relationshipRepository.openConflictVersions(relationshipId),
      ).thenAnswer((_) async => [annaConflict]);

      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);

      verify(
        () => relationshipAgentService.reconcileAgent(
          anna,
          conflicting: [annaConflict],
        ),
      ).called(1);
      verify(
        () => relationshipAgentService.reconcileAgent(ben, conflicting: []),
      ).called(1);
    });

    test('the reap runs before the reconcile pass, so a deleted person is '
        'never brought back in the same scan', () async {
      when(
        () => relationshipRepository.isRelationshipDeleted(relationshipId),
      ).thenAnswer((_) async => true);
      when(
        () => relationshipRepository.getAllRelationshipsUnfiltered(),
      ).thenAnswer((_) async => [person()]);

      await withClock(Clock.fixed(now), maintenance.beforeWakeScan);

      verifyInOrder([
        () => relationshipAgentService.handleRelationshipDeleted(
          relationshipId,
        ),
        () => relationshipAgentService.reconcileAgent(
          any(),
          conflicting: any(named: 'conflicting'),
        ),
      ]);
    });

    test(
      'one failing person is contained; the rest are still reconciled',
      () async {
        final ben = another('person-2');
        when(
          () => relationshipRepository.getAllRelationshipsUnfiltered(),
        ).thenAnswer((_) async => [person(), ben]);
        when(
          () => relationshipAgentService.reconcileAgent(
            person(),
            conflicting: any(named: 'conflicting'),
          ),
        ).thenThrow(StateError('broken'));

        await expectLater(maintenance.beforeWakeScan(), completes);

        verify(
          () => relationshipAgentService.reconcileAgent(ben, conflicting: []),
        ).called(1);
        verify(
          () => logger.error(
            any(),
            any<Object>(),
            message: any(named: 'message', that: contains('reconcile')),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test('a failure listing people is contained and logged', () async {
      when(
        () => relationshipRepository.getAllRelationshipsUnfiltered(),
      ).thenThrow(StateError('db closed'));

      await expectLater(maintenance.beforeWakeScan(), completes);

      verifyNever(
        () => relationshipAgentService.reconcileAgent(
          any(),
          conflicting: any(named: 'conflicting'),
        ),
      );
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          message: any(named: 'message', that: contains('reconcile')),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('onIdentityReceived', () {
    test('an active synced-in identity subscribes immediately — no restart '
        'needed', () async {
      await maintenance.onIdentityReceived(identity());
      expect(scanRequests, 1);
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
      expect(scanRequests, 0);
    });

    test('another kind is ignored entirely', () async {
      await maintenance.onIdentityReceived(
        identity(kind: AgentKinds.goalAgent),
      );
      verifyZeroInteractions(relationshipAgentService);
      expect(scanRequests, 0);
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
