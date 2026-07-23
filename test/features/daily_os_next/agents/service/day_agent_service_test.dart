import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

class _TransactionTrackingAgentSyncService extends MockAgentSyncService {
  final events = <String>[];
  bool inTransaction = false;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    events.add('transaction:start');
    inTransaction = true;
    try {
      return await action();
    } finally {
      inTransaction = false;
      events.add('transaction:end');
    }
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late _TransactionTrackingAgentSyncService syncService;
  late MockAgentTemplateService templateService;
  late MockDomainLogger domainLogger;
  late DayAgentService service;
  late List<String> changedTokens;

  const agentId = 'day-agent-1';
  final testDate = DateTime(2026, 5, 25, 9);
  const dayId = 'dayplan-2026-05-25';
  final now = DateTime(2026, 5, 25, 8);

  AgentIdentityEntity identity({
    String id = agentId,
    String kind = AgentKinds.dayAgent,
    AgentConfig config = const AgentConfig(),
    DateTime? createdAt,
  }) {
    return makeTestIdentity(
      id: id,
      agentId: id,
      kind: kind,
      displayName: 'Shepherd',
      currentStateId: 'state-$id',
      config: config,
      createdAt: createdAt ?? now,
      updatedAt: createdAt ?? now,
    );
  }

  AgentStateEntity state({
    String id = 'state-$agentId',
    String stateAgentId = agentId,
    String? activeDayId,
    DateTime? nextWakeAt,
  }) {
    return makeTestState(
      id: id,
      agentId: stateAgentId,
      revision: 0,
      slots: AgentSlots(activeDayId: activeDayId),
      nextWakeAt: nextWakeAt,
      updatedAt: now,
    );
  }

  setUp(() {
    agentService = MockAgentService();
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    syncService = _TransactionTrackingAgentSyncService();
    templateService = MockAgentTemplateService();
    domainLogger = MockDomainLogger();
    changedTokens = [];

    when(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {
      syncService.events.add('write');
    });
    when(() => syncService.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        workspaceKey: any(named: 'workspaceKey'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn('run-key-stub');
    when(
      () => orchestrator.restorePendingWake(
        agentId: any(named: 'agentId'),
        dueAt: any(named: 'dueAt'),
      ),
    ).thenReturn(null);
    when(
      () => repository.getActiveAgentByKindAndActiveDayId(
        kind: any(named: 'kind'),
        activeDayId: any(named: 'activeDayId'),
      ),
    ).thenAnswer((_) async => null);
    // Default: no identity exists for arbitrary ids (ADR 0032 per-day agents
    // are created lazily), but the planner already exists (enqueue paths
    // resolve it via getDayAgentForDate → getAgent). Registration order
    // matters: the specific planner stub must come after the generic one so
    // it wins. Tests that exercise creation re-stub.
    when(() => agentService.getAgent(any())).thenAnswer((_) async => null);
    when(
      () => agentService.getAgent(dailyOsPlannerAgentId),
    ).thenAnswer((_) async => identity());
    when(
      () => agentService.listAgents(lifecycle: any(named: 'lifecycle')),
    ).thenAnswer((_) async => []);
    // Cutover-ownership probe defaults: no plan entity and no captures, so a
    // clean day would create a per-day agent unless a test stubs otherwise.
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getCaptureEventMetaByAgentId(any()),
    ).thenAnswer((_) async => []);

    service = DayAgentService(
      agentService: agentService,
      repository: repository,
      orchestrator: orchestrator,
      syncService: syncService,
      templateService: templateService,
      domainLogger: domainLogger,
      onPersistedStateChanged: (token) {
        syncService.events.add('notify');
        changedTokens.add(token);
      },
    );
  });

  group('DayAgentService', () {
    test(
      'getDayAgentForDate falls back to the planner when no per-day '
      'identity exists',
      () async {
        final planner = identity(id: dailyOsPlannerAgentId);
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => planner);

        final a = await service.getDayAgentForDate(DateTime(2026, 5, 25));
        final b = await service.getDayAgentForDate(DateTime(2026, 5, 26));

        // Pre-cutover days have no per-day identity, so ownership falls back
        // to the coordinator (ADR 0032).
        expect(a?.agentId, dailyOsPlannerAgentId);
        expect(b?.agentId, dailyOsPlannerAgentId);
      },
    );

    test(
      'getDayAgentForDate prefers the per-day identity when it exists',
      () async {
        final perDayId = perDayAgentId(dayId);
        when(
          () => agentService.getAgent(perDayId),
        ).thenAnswer((_) async => identity(id: perDayId));

        final resolved = await service.getDayAgentForDate(testDate);

        expect(resolved?.agentId, perDayId);
        // The planner lookup is short-circuited entirely.
        verifyNever(() => agentService.getAgent(dailyOsPlannerAgentId));
      },
    );

    test(
      'getDayAgentForDate returns null before any identity exists',
      () async {
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => null);

        expect(await service.getDayAgentForDate(DateTime(2026, 5, 25)), isNull);
      },
    );

    test(
      'restoreSubscriptions hydrates the planner and per-day agents and '
      'skips legacy day agents',
      () async {
        final dueAt = DateTime(2026, 5, 25, 6, 30);
        final perDayDueAt = DateTime(2026, 5, 25, 7, 15);
        final perDayId = perDayAgentId(dayId);
        final planner = identity(id: dailyOsPlannerAgentId);
        final perDayAgent = identity(id: perDayId);
        final taskAgent = identity(
          id: 'task-agent',
          kind: AgentKinds.taskAgent,
        );
        // A stray bare legacy per-day identity (e.g. synced from a peer still
        // on the pre-ADR-0022 build) must never be restored — only the
        // coordinator and ADR 0032 per-day agents.
        final strayDayAgent = identity(id: 'stray-day-agent');
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer(
          (_) async => [taskAgent, strayDayAgent, planner, perDayAgent],
        );
        when(
          () => repository.getAgentState(dailyOsPlannerAgentId),
        ).thenAnswer(
          (_) async =>
              state(stateAgentId: dailyOsPlannerAgentId, nextWakeAt: dueAt),
        );
        when(
          () => repository.getAgentState(perDayId),
        ).thenAnswer(
          (_) async => state(
            id: 'state-$perDayId',
            stateAgentId: perDayId,
            nextWakeAt: perDayDueAt,
          ),
        );

        await service.restoreSubscriptions();

        verify(
          () => orchestrator.restorePendingWake(
            agentId: dailyOsPlannerAgentId,
            dueAt: dueAt,
          ),
        ).called(1);
        verify(
          () => orchestrator.restorePendingWake(
            agentId: perDayId,
            dueAt: perDayDueAt,
          ),
        ).called(1);
        verifyNever(() => repository.getAgentState('task-agent'));
        verifyNever(() => repository.getAgentState('stray-day-agent'));
      },
    );

    group('persistRefineCapture', () {
      test(
        'persists a non-blank transcript as a refine capture and notifies',
        () async {
          final captureId = await withClock(
            Clock.fixed(now),
            () => service.persistRefineCapture(
              agentId: agentId,
              dayId: dayId,
              transcript: '  move lunch to 1pm  ',
            ),
          );

          expect(captureId, isNotNull);
          expect(captureId, startsWith('refine_capture:'));
          final captured = verify(
            () => syncService.upsertEntity(captureAny()),
          ).captured;
          final capture = captured.single as CaptureEntity;
          expect(capture.id, captureId);
          expect(capture.agentId, agentId);
          expect(capture.dayId, dayId);
          expect(capture.transcript, 'move lunch to 1pm');
          expect(capture.capturedAt, now);
          expect(changedTokens, [captureId]);
        },
      );

      test(
        'returns null and persists nothing for a blank transcript',
        () async {
          final captureId = await service.persistRefineCapture(
            agentId: agentId,
            dayId: dayId,
            transcript: '   ',
          );

          expect(captureId, isNull);
          verifyNever(() => syncService.upsertEntity(any()));
          expect(changedTokens, isEmpty);
        },
      );
    });

    test('triggerReanalysis enqueues a manual reanalysis wake', () {
      service.triggerReanalysis(agentId);

      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: WakeReason.reanalysis.name,
          workspaceKey: any(named: 'workspaceKey'),
        ),
      ).called(1);
      final logMessage =
          verify(
                () => domainLogger.log(
                  any(),
                  captureAny(),
                  subDomain: 'lifecycle',
                  level: any(named: 'level'),
                ),
              ).captured.single
              as String;
      expect(logMessage, contains('manual day-agent reanalysis'));
    });

    test('cancelScheduledWake delegates pending wake cancellation', () {
      service.cancelScheduledWake(agentId);

      verify(() => agentService.cancelPendingWake(agentId)).called(1);
      final logMessage =
          verify(
                () => domainLogger.log(
                  any(),
                  captureAny(),
                  subDomain: 'lifecycle',
                  level: any(named: 'level'),
                ),
              ).captured.single
              as String;
      expect(logMessage, contains('scheduled wake cancelled'));
    });

    test(
      'restoreSubscriptions logs and does not propagate a planner hydrate '
      'failure',
      () async {
        final planner = identity(id: dailyOsPlannerAgentId);
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [planner]);
        when(
          () => repository.getAgentState(dailyOsPlannerAgentId),
        ).thenThrow(StateError('state read failed'));

        // Must complete normally despite the failing state read.
        await service.restoreSubscriptions();

        final errorMessage =
            verify(
                  () => domainLogger.error(
                    any(),
                    any(),
                    message: captureAny(named: 'message'),
                    stackTrace: any(named: 'stackTrace'),
                    subDomain: any(named: 'subDomain'),
                  ),
                ).captured.single
                as String;
        expect(
          errorMessage,
          contains('failed to restore day-agent runtime state'),
        );
      },
    );

    group('coordinator digest bootstrap (ADR 0032 phase 3)', () {
      final digestRecordId = scheduledWakeRecordId(
        dailyOsPlannerAgentId,
        workspaceKey: coordinatorDigestWorkspaceKey,
      );

      List<ScheduledWakeEntity> upsertedWakes() {
        final captured = <ScheduledWakeEntity>[];
        final calls = verify(() => syncService.upsertEntity(captureAny()));
        for (final entity in calls.captured) {
          if (entity is ScheduledWakeEntity) captured.add(entity);
        }
        return captured;
      }

      Future<void> restoreWithPlanner({
        AgentDomainEntity? existingRecord,
      }) async {
        final planner = identity(id: dailyOsPlannerAgentId);
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [planner]);
        when(
          () => repository.getAgentState(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getEntity(digestRecordId),
        ).thenAnswer((_) async => existingRecord);
        // now = 2026-05-25 08:00, past the 06:00 digest hour.
        await withClock(Clock.fixed(now), service.restoreSubscriptions);
      }

      test(
        'schedules the first digest wake when no record exists',
        () async {
          await restoreWithPlanner();

          final record = upsertedWakes().single;
          expect(record.id, digestRecordId);
          expect(record.agentId, dailyOsPlannerAgentId);
          expect(record.status, ScheduledWakeStatus.pending);
          expect(record.workspaceKey, coordinatorDigestWorkspaceKey);
          expect(record.scheduledAt, DateTime(2026, 5, 26, 6));
          expect(
            record.triggerTokens,
            [dayAgentDigestToken('dayplan-2026-05-26')],
          );
        },
      );

      test('leaves an already-pending digest record alone', () async {
        await restoreWithPlanner(
          existingRecord: AgentDomainEntity.scheduledWake(
            id: digestRecordId,
            agentId: dailyOsPlannerAgentId,
            scheduledAt: DateTime(2026, 5, 26, 6),
            status: ScheduledWakeStatus.pending,
            reason: dayAgentDigestReason,
            updatedAt: now,
            vectorClock: null,
            triggerTokens: [dayAgentDigestToken('dayplan-2026-05-26')],
            workspaceKey: coordinatorDigestWorkspaceKey,
          ),
        );

        verifyNever(
          () => syncService.upsertEntity(any(that: isA<ScheduledWakeEntity>())),
        );
      });

      test('re-arms after a consumed digest record', () async {
        await restoreWithPlanner(
          existingRecord: AgentDomainEntity.scheduledWake(
            id: digestRecordId,
            agentId: dailyOsPlannerAgentId,
            scheduledAt: DateTime(2026, 5, 25, 6),
            status: ScheduledWakeStatus.consumed,
            reason: dayAgentDigestReason,
            updatedAt: now,
            vectorClock: null,
            triggerTokens: [dayAgentDigestToken('dayplan-2026-05-25')],
            workspaceKey: coordinatorDigestWorkspaceKey,
          ),
        );

        final record = upsertedWakes().single;
        expect(record.status, ScheduledWakeStatus.pending);
        expect(record.scheduledAt, DateTime(2026, 5, 26, 6));
      });

      test(
        'a bootstrap failure is logged and does not break the restore',
        () async {
          final planner = identity(id: dailyOsPlannerAgentId);
          when(
            () => agentService.listAgents(lifecycle: AgentLifecycle.active),
          ).thenAnswer((_) async => [planner]);
          when(
            () => repository.getAgentState(dailyOsPlannerAgentId),
          ).thenAnswer((_) async => null);
          when(
            () => repository.getEntity(digestRecordId),
          ).thenThrow(StateError('record store unavailable'));

          // Must complete normally despite the failing bootstrap read.
          await withClock(Clock.fixed(now), service.restoreSubscriptions);

          verify(
            () => domainLogger.error(
              any(),
              any(),
              message: 'failed to ensure coordinator digest wake',
              stackTrace: any(named: 'stackTrace'),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        },
      );

      test('does nothing when no coordinator identity is active', () async {
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer(
          (_) async => [identity(id: perDayAgentId(dayId))],
        );
        when(
          () => repository.getAgentState(any()),
        ).thenAnswer((_) async => null);

        await withClock(Clock.fixed(now), service.restoreSubscriptions);

        verifyNever(() => repository.getEntity(digestRecordId));
        verifyNever(
          () => syncService.upsertEntity(any(that: isA<ScheduledWakeEntity>())),
        );
      });
    });
  });

  group('getOrCreatePlannerAgent', () {
    final plannerTemplate = makeTestTemplate(
      id: dayAgentTemplateId,
      agentId: dayAgentTemplateId,
      kind: AgentTemplateKind.dayAgent,
      modelId: 'models/day',
      profileId: 'profile-day',
    );

    test('returns the existing planner without creating a new one', () async {
      final existing = identity(id: dailyOsPlannerAgentId);
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => existing);

      final result = await service.getOrCreatePlannerAgent();

      expect(result, existing);
      verifyNever(
        () => agentService.createAgent(
          agentId: any(named: 'agentId'),
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    test(
      'creates the planner with the deterministic id and no day slot',
      () async {
        final created = identity(id: dailyOsPlannerAgentId);
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getEntity(dayAgentTemplateId),
        ).thenAnswer((_) async => plannerTemplate);
        when(
          () => agentService.createAgent(
            agentId: any(named: 'agentId'),
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => created);

        final result = await withClock(
          Clock.fixed(now),
          service.getOrCreatePlannerAgent,
        );

        expect(result, created);
        // Mocktail records captured named args in signature-declaration
        // order (kind, then agentId), not call order.
        final createCall = verify(
          () => agentService.createAgent(
            agentId: captureAny(named: 'agentId'),
            kind: captureAny(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: captureAny(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).captured;
        expect(createCall[0], AgentKinds.dayAgent);
        final createdConfig = createCall[1] as AgentConfig;
        expect(createCall[2], dailyOsPlannerAgentId);
        expect(createdConfig.profileId, 'profile-day');
        expect(
          createdConfig.inferenceSetup,
          const AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.templateSnapshot,
            baseProfileId: 'profile-day',
            originEntityId: dayAgentTemplateId,
          ),
        );

        // The planner gets a template assignment but NO AgentDayLink: a day
        // is a workspace carried by wake tokens, not part of identity.
        final links = verify(
          () => syncService.upsertLink(captureAny()),
        ).captured.cast<AgentLink>();
        expect(links.whereType<AgentDayLink>(), isEmpty);
        final templateLink = links.whereType<TemplateAssignmentLink>().single;
        expect(templateLink.toId, dailyOsPlannerAgentId);
        verifyNever(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            workspaceKey: any(named: 'workspaceKey'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      },
    );

    test('is idempotent under a concurrent in-transaction create', () async {
      final existing = identity(id: dailyOsPlannerAgentId);
      // First lookup misses; the in-transaction recheck finds a peer's write.
      final responses = <AgentIdentityEntity?>[null, existing];
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => responses.removeAt(0));

      final result = await service.getOrCreatePlannerAgent();

      expect(result, existing);
      verifyNever(
        () => agentService.createAgent(
          agentId: any(named: 'agentId'),
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
      // No mutation happened, so no persisted-state notification fires.
      expect(changedTokens, isEmpty);
    });

    test(
      'rejects a template that is not an active day-agent template',
      () async {
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => null);
        final projectTemplate = makeTestTemplate(
          id: dayAgentTemplateId,
          agentId: dayAgentTemplateId,
          kind: AgentTemplateKind.projectAgent,
        );
        when(
          () => repository.getEntity(dayAgentTemplateId),
        ).thenAnswer((_) async => projectTemplate);

        await expectLater(
          service.getOrCreatePlannerAgent(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('not an active day-agent template'),
            ),
          ),
        );

        verifyNever(
          () => agentService.createAgent(
            agentId: any(named: 'agentId'),
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
        // A rejected creation makes no persisted-state notification.
        expect(changedTokens, isEmpty);
      },
    );

    group('legacy migration', () {
      final plannerTemplate = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
        modelId: 'models/day',
        profileId: 'profile-day',
      );

      void stubFreshPlannerCreation() {
        final created = identity(id: dailyOsPlannerAgentId);
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getEntity(dayAgentTemplateId),
        ).thenAnswer((_) async => plannerTemplate);
        when(
          () => agentService.createAgent(
            agentId: any(named: 'agentId'),
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => created);
      }

      test(
        'archives legacy day agents and re-parents their recent entities',
        () async {
          stubFreshPlannerCreation();
          final legacy = identity(id: 'legacy-day-1');
          when(
            () => agentService.listAgents(lifecycle: AgentLifecycle.active),
          ).thenAnswer(
            (_) async => [
              identity(id: dailyOsPlannerAgentId),
              legacy,
              // A task agent must be left untouched.
              identity(id: 'task-1', kind: AgentKinds.taskAgent),
            ],
          );
          when(
            () => repository.getAgentState('legacy-day-1'),
          ).thenAnswer(
            (_) async => makeTestState(
              id: 'state-legacy',
              agentId: 'legacy-day-1',
              slots: const AgentSlots(activeDayId: dayId),
              scheduledWakeAt: DateTime(2026, 5, 25, 6),
              updatedAt: now,
            ),
          );
          // makeTestDayPlan defaults dayId to dayplan-2026-05-25 (== dayId).
          final recentPlan = makeTestDayPlan(
            agentId: 'legacy-day-1',
            planDate: now.subtract(const Duration(days: 1)),
          );
          final oldPlan = makeTestDayPlan(
            id: 'day_agent_plan:dayplan-2026-02-10',
            agentId: 'legacy-day-1',
            dayId: 'dayplan-2026-02-10',
            planDate: DateTime(2026, 2, 10),
          );
          // A recent pending plan diff must follow its plan to the planner.
          final recentDiff =
              AgentDomainEntity.changeSet(
                    id: 'cs-recent',
                    agentId: 'legacy-day-1',
                    taskId: 'day_agent_plan:$dayId',
                    threadId: 'thread-1',
                    runKey: 'run-1',
                    status: ChangeSetStatus.pending,
                    items: const [],
                    createdAt: now.subtract(const Duration(days: 1)),
                    vectorClock: null,
                  )
                  as ChangeSetEntity;
          final recentCapture = makeTestCapture(
            id: 'cap-recent',
            agentId: 'legacy-day-1',
            capturedAt: now.subtract(const Duration(days: 1)),
            createdAt: now.subtract(const Duration(days: 1)),
          );
          final oldCapture = makeTestCapture(
            id: 'cap-old',
            agentId: 'legacy-day-1',
            capturedAt: DateTime(2026, 2, 10),
            createdAt: DateTime(2026, 2, 10),
          );
          ParsedItemEntity parsedItem(String id, DateTime createdAt) =>
              AgentDomainEntity.parsedItem(
                    id: id,
                    agentId: 'legacy-day-1',
                    captureId: 'cap-recent',
                    kind: ParsedItemKind.newTask,
                    title: 'parsed',
                    categoryId: 'cat',
                    confidence: ParsedItemConfidence.high,
                    confidenceScore: 0.9,
                    createdAt: createdAt,
                    vectorClock: null,
                  )
                  as ParsedItemEntity;
          final recentItem = parsedItem(
            'pi-recent',
            now.subtract(const Duration(days: 1)),
          );
          final oldItem = parsedItem('pi-old', DateTime(2026, 2, 10));
          when(
            () => repository.getEntitiesByAgentId('legacy-day-1'),
          ).thenAnswer(
            (_) async => [
              recentPlan,
              oldPlan,
              recentDiff,
              recentCapture,
              oldCapture,
              recentItem,
              oldItem,
            ],
          );

          await withClock(
            Clock.fixed(now),
            service.getOrCreatePlannerAgent,
          );

          final upserts = verify(
            () => syncService.upsertEntity(captureAny()),
          ).captured.cast<AgentDomainEntity>();

          // Legacy identity archived (dormant).
          final archived = upserts.whereType<AgentIdentityEntity>().firstWhere(
            (e) => e.agentId == 'legacy-day-1',
          );
          expect(archived.lifecycle, AgentLifecycle.dormant);

          // Its scheduledWakeAt was cleared so it stops being woken.
          final clearedState = upserts.whereType<AgentStateEntity>().firstWhere(
            (e) => e.agentId == 'legacy-day-1',
          );
          expect(clearedState.scheduledWakeAt, isNull);

          // The recent plan is re-parented; the old one is left in place.
          final reparented = upserts.whereType<DayPlanEntity>().toList();
          expect(reparented, hasLength(1));
          expect(reparented.single.agentId, dailyOsPlannerAgentId);
          expect(reparented.single.dayId, dayId);

          // The recent pending diff follows the plan to the planner.
          final reparentedDiff = upserts.whereType<ChangeSetEntity>().single;
          expect(reparentedDiff.id, 'cs-recent');
          expect(reparentedDiff.agentId, dailyOsPlannerAgentId);

          // Recent captures and parsed items are re-parented; old ones aren't.
          final reparentedCaptures = upserts
              .whereType<CaptureEntity>()
              .toList();
          expect(reparentedCaptures.map((e) => e.id), ['cap-recent']);
          expect(reparentedCaptures.single.agentId, dailyOsPlannerAgentId);
          final reparentedItems = upserts
              .whereType<ParsedItemEntity>()
              .toList();
          expect(reparentedItems.map((e) => e.id), ['pi-recent']);
          expect(reparentedItems.single.agentId, dailyOsPlannerAgentId);
        },
      );

      test(
        'migrates legacy agents even when the planner already exists',
        () async {
          // The planner is already present (no creation), yet a legacy day
          // agent that synced in afterwards must still be archived — migration
          // runs on every resolve, not only on first creation.
          when(
            () => agentService.getAgent(dailyOsPlannerAgentId),
          ).thenAnswer((_) async => identity(id: dailyOsPlannerAgentId));
          final legacy = identity(id: 'legacy-late');
          // An ADR 0032 per-day agent shares the kind but is NOT legacy: the
          // migration must never archive it.
          final perDayAgent = identity(id: perDayAgentId(dayId));
          when(
            () => agentService.listAgents(lifecycle: AgentLifecycle.active),
          ).thenAnswer(
            (_) async => [
              identity(id: dailyOsPlannerAgentId),
              legacy,
              perDayAgent,
            ],
          );
          when(() => repository.getAgentState('legacy-late')).thenAnswer(
            (_) async => makeTestState(
              id: 'state-legacy-late',
              agentId: 'legacy-late',
              slots: const AgentSlots(activeDayId: dayId),
              scheduledWakeAt: DateTime(2026, 5, 25, 6),
              updatedAt: now,
            ),
          );
          when(
            () => repository.getEntitiesByAgentId('legacy-late'),
          ).thenAnswer((_) async => const []);

          final result = await withClock(
            Clock.fixed(now),
            service.getOrCreatePlannerAgent,
          );

          expect(result.agentId, dailyOsPlannerAgentId);
          final upserts = verify(
            () => syncService.upsertEntity(captureAny()),
          ).captured.cast<AgentDomainEntity>();
          final archived = upserts.whereType<AgentIdentityEntity>().firstWhere(
            (e) => e.agentId == 'legacy-late',
          );
          expect(archived.lifecycle, AgentLifecycle.dormant);
          // The per-day agent was never touched — not archived, not read.
          expect(
            upserts.whereType<AgentIdentityEntity>().where(
              (e) => e.agentId == perDayAgentId(dayId),
            ),
            isEmpty,
          );
          verifyNever(() => repository.getAgentState(perDayAgentId(dayId)));
        },
      );

      test('continues migrating after one legacy agent fails', () async {
        // A per-agent failure must not strand later agents' scheduledWakeAt
        // (the migration never retries).
        stubFreshPlannerCreation();
        final bad = identity(id: 'legacy-bad');
        final good = identity(id: 'legacy-good');
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [bad, good]);
        when(
          () => repository.getAgentState('legacy-bad'),
        ).thenThrow(StateError('read failed'));
        when(
          () => repository.getAgentState('legacy-good'),
        ).thenAnswer(
          (_) async => makeTestState(
            id: 'state-good',
            agentId: 'legacy-good',
            scheduledWakeAt: DateTime(2026, 5, 25, 6),
            updatedAt: now,
          ),
        );
        when(
          () => repository.getEntitiesByAgentId('legacy-good'),
        ).thenAnswer((_) async => const []);

        await withClock(Clock.fixed(now), service.getOrCreatePlannerAgent);

        // The good agent was still archived despite the bad one throwing.
        final upserts = verify(
          () => syncService.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        final archivedGood = upserts
            .whereType<AgentIdentityEntity>()
            .firstWhere(
              (e) => e.agentId == 'legacy-good',
            );
        expect(archivedGood.lifecycle, AgentLifecycle.dormant);
      });

      test('migration failure does not block planner creation', () async {
        stubFreshPlannerCreation();
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenThrow(StateError('list failed'));

        final result = await service.getOrCreatePlannerAgent();

        // The planner is still returned even though migration threw.
        expect(result.agentId, dailyOsPlannerAgentId);
      });
    });
  });

  group('getOrCreateDayAgentForDate', () {
    const testDayId = dayId;
    final perDayId = perDayAgentId(dayId);
    final dayTemplate = makeTestTemplate(
      id: dayAgentTemplateId,
      agentId: dayAgentTemplateId,
      kind: AgentTemplateKind.dayAgent,
      modelId: 'models/day',
      profileId: 'profile-day',
    );

    void stubTemplateAndCreate({required String createdId}) {
      when(
        () => repository.getEntity(dayAgentTemplateId),
      ).thenAnswer((_) async => dayTemplate);
      when(
        () => agentService.createAgent(
          agentId: any(named: 'agentId'),
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => identity(id: createdId));
    }

    test(
      'returns an existing per-day identity without touching the planner',
      () async {
        final existing = identity(id: perDayId);
        when(
          () => agentService.getAgent(perDayId),
        ).thenAnswer((_) async => existing);

        final result = await service.getOrCreateDayAgentForDate(testDate);

        expect(result, existing);
        verifyNever(() => agentService.getAgent(dailyOsPlannerAgentId));
        verifyNever(
          () => agentService.createAgent(
            agentId: any(named: 'agentId'),
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    test(
      'creates the per-day identity for a clean day with template snapshot, '
      'inherited categories, and dual notification',
      () async {
        final planner = makeTestIdentity(
          id: dailyOsPlannerAgentId,
          agentId: dailyOsPlannerAgentId,
          kind: AgentKinds.dayAgent,
          displayName: 'Shepherd',
          allowedCategoryIds: const {'cat-work', 'cat-life'},
          currentStateId: 'state-planner',
          createdAt: now,
          updatedAt: now,
        );
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => planner);
        stubTemplateAndCreate(createdId: perDayId);

        final result = await withClock(
          Clock.fixed(now),
          () => service.getOrCreateDayAgentForDate(testDate),
        );

        expect(result.agentId, perDayId);
        // Mocktail records captured named args in signature-declaration
        // order (kind, displayName, config, allowedCategoryIds, agentId).
        final createCall = verify(
          () => agentService.createAgent(
            agentId: captureAny(named: 'agentId'),
            kind: captureAny(named: 'kind'),
            displayName: captureAny(named: 'displayName'),
            config: captureAny(named: 'config'),
            allowedCategoryIds: captureAny(named: 'allowedCategoryIds'),
          ),
        ).captured;
        expect(createCall[0], AgentKinds.dayAgent);
        expect(createCall[1], 'Shepherd · 2026-05-25');
        final createdConfig = createCall[2] as AgentConfig;
        expect(createCall[3], {'cat-work', 'cat-life'});
        expect(createCall[4], perDayId);
        expect(createdConfig.profileId, 'profile-day');
        expect(
          createdConfig.inferenceSetup,
          const AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.templateSnapshot,
            baseProfileId: 'profile-day',
            originEntityId: dayAgentTemplateId,
          ),
        );

        final links = verify(
          () => syncService.upsertLink(captureAny()),
        ).captured.cast<AgentLink>();
        final templateLink = links.whereType<TemplateAssignmentLink>().single;
        expect(templateLink.id, '$perDayId:template-assignment');
        expect(templateLink.fromId, dayAgentTemplateId);
        expect(templateLink.toId, perDayId);

        // Both the agent id (agent-keyed listeners) and the day id
        // (day-keyed providers) are notified.
        expect(changedTokens, containsAll([perDayId, testDayId]));
      },
    );

    test('returns the planner when it already owns the day plan', () async {
      final planner = identity(id: dailyOsPlannerAgentId);
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => planner);
      when(
        () => repository.getEntity(dayAgentPlanEntityId(testDayId)),
      ).thenAnswer(
        (_) async => makeTestDayPlan(
          agentId: dailyOsPlannerAgentId,
          planDate: DateTime(2026, 5, 25),
        ),
      );

      final result = await service.getOrCreateDayAgentForDate(testDate);

      expect(result, planner);
      verifyNever(
        () => agentService.createAgent(
          agentId: any(named: 'agentId'),
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    test('returns the planner when it has a capture on the day', () async {
      final planner = identity(id: dailyOsPlannerAgentId);
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => planner);
      when(
        () => repository.getCaptureEventMetaByAgentId(dailyOsPlannerAgentId),
      ).thenAnswer(
        (_) async => [
          (
            id: 'cap-1',
            dayId: testDayId,
            createdAt: now,
            capturedAt: now,
          ),
        ],
      );

      final result = await service.getOrCreateDayAgentForDate(testDate);

      expect(result, planner);
      verifyNever(
        () => agentService.createAgent(
          agentId: any(named: 'agentId'),
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
    });

    test(
      'a planner capture on a different day does not block creation',
      () async {
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => identity(id: dailyOsPlannerAgentId));
        when(
          () => repository.getCaptureEventMetaByAgentId(dailyOsPlannerAgentId),
        ).thenAnswer(
          (_) async => [
            (
              id: 'cap-other',
              dayId: 'dayplan-2026-05-24',
              createdAt: now,
              capturedAt: now,
            ),
          ],
        );
        stubTemplateAndCreate(createdId: perDayId);

        final result = await service.getOrCreateDayAgentForDate(testDate);

        expect(result.agentId, perDayId);
      },
    );

    test('is idempotent under a concurrent in-transaction create', () async {
      final existing = identity(id: perDayId);
      // First lookup misses; the in-transaction recheck finds a peer's write.
      final responses = <AgentIdentityEntity?>[null, existing];
      when(
        () => agentService.getAgent(perDayId),
      ).thenAnswer((_) async => responses.removeAt(0));

      final result = await service.getOrCreateDayAgentForDate(testDate);

      expect(result, existing);
      verifyNever(
        () => agentService.createAgent(
          agentId: any(named: 'agentId'),
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
      // No mutation happened, so no persisted-state notification fires.
      expect(changedTokens, isEmpty);
    });

    test(
      'rejects a template that is not an active day-agent template',
      () async {
        when(() => repository.getEntity(dayAgentTemplateId)).thenAnswer(
          (_) async => makeTestTemplate(
            id: dayAgentTemplateId,
            agentId: dayAgentTemplateId,
            kind: AgentTemplateKind.projectAgent,
          ),
        );

        await expectLater(
          service.getOrCreateDayAgentForDate(testDate),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('not an active day-agent template'),
            ),
          ),
        );
        expect(changedTokens, isEmpty);
      },
    );
  });

  group('Daily OS inference selection', () {
    final plannerTemplate = makeTestTemplate(
      id: dayAgentTemplateId,
      agentId: dayAgentTemplateId,
      kind: AgentTemplateKind.dayAgent,
      modelId: 'models/day',
      profileId: 'profile-old',
    );

    test('default profile updates a planner following the template', () async {
      final planner = identity(
        id: dailyOsPlannerAgentId,
        config: const AgentConfig(
          profileId: 'profile-old',
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.templateSnapshot,
            baseProfileId: 'profile-old',
            originEntityId: dayAgentTemplateId,
          ),
        ),
      );
      when(
        () => templateService.updateTemplate(
          templateId: dayAgentTemplateId,
          profileId: 'profile-new',
        ),
      ).thenAnswer(
        (_) async => plannerTemplate.copyWith(profileId: 'profile-new'),
      );
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => planner);

      await withClock(
        Clock.fixed(now),
        () => service.updateDefaultInferenceProfile('profile-new'),
      );

      final updated =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentIdentityEntity;
      expect(updated.config.profileId, 'profile-new');
      expect(updated.config.inferenceSetup?.baseProfileId, 'profile-new');
      expect(
        updated.config.inferenceSetup?.origin,
        AgentInferenceSetupOrigin.templateSnapshot,
      );
      expect(changedTokens, [dailyOsPlannerAgentId]);
    });

    test('default profile preserves a user-owned planner override', () async {
      final planner = identity(
        id: dailyOsPlannerAgentId,
        config: const AgentConfig(
          profileId: 'profile-old',
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
            baseProfileId: 'profile-old',
            thinkingModelOverrideId: 'model-user',
          ),
        ),
      );
      when(
        () => templateService.updateTemplate(
          templateId: dayAgentTemplateId,
          profileId: 'profile-new',
        ),
      ).thenAnswer(
        (_) async => plannerTemplate.copyWith(profileId: 'profile-new'),
      );
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async => planner);

      await service.updateDefaultInferenceProfile('profile-new');

      verifyNever(() => syncService.upsertEntity(any()));
      expect(changedTokens, isEmpty);
    });

    test('profile override is user-owned and clears a direct model', () async {
      final planner = identity(
        id: dailyOsPlannerAgentId,
        config: const AgentConfig(
          profileId: 'profile-old',
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
            baseProfileId: 'profile-old',
            thinkingModelOverrideId: 'model-old',
          ),
        ),
      );
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async {
        expect(syncService.inTransaction, isTrue);
        syncService.events.add('read:planner');
        return planner;
      });

      await service.updatePlannerProfileOverride('profile-instance');

      final updated =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentIdentityEntity;
      expect(updated.config.profileId, 'profile-instance');
      expect(updated.config.inferenceSetup?.baseProfileId, 'profile-instance');
      expect(updated.config.inferenceSetup?.thinkingModelOverrideId, isNull);
      expect(
        updated.config.inferenceSetup?.origin,
        AgentInferenceSetupOrigin.user,
      );
      expect(syncService.events, [
        'transaction:start',
        'read:planner',
        'write',
        'transaction:end',
        'notify',
      ]);
    });

    test(
      'model override keeps the planner profile override as its base',
      () async {
        final planner = identity(
          id: dailyOsPlannerAgentId,
          config: const AgentConfig(
            profileId: 'profile-instance',
            inferenceSetup: AgentInferenceSetup(
              mode: AgentInferenceSetupMode.configured,
              origin: AgentInferenceSetupOrigin.user,
              baseProfileId: 'profile-instance',
            ),
          ),
        );
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async {
          expect(syncService.inTransaction, isTrue);
          syncService.events.add('read:planner');
          return planner;
        });
        when(
          () => templateService.getTemplate(dayAgentTemplateId),
        ).thenAnswer((_) async {
          expect(syncService.inTransaction, isTrue);
          syncService.events.add('read:template');
          return plannerTemplate;
        });

        await service.updatePlannerThinkingModelOverride('model-user');

        final updated =
            verify(
                  () => syncService.upsertEntity(captureAny()),
                ).captured.single
                as AgentIdentityEntity;
        expect(
          updated.config.inferenceSetup?.baseProfileId,
          'profile-instance',
        );
        expect(
          updated.config.inferenceSetup?.thinkingModelOverrideId,
          'model-user',
        );
        expect(
          updated.config.inferenceSetup?.origin,
          AgentInferenceSetupOrigin.user,
        );
        expect(syncService.events, [
          'transaction:start',
          'read:planner',
          'read:template',
          'write',
          'transaction:end',
          'notify',
        ]);
      },
    );

    test('reset restores the template snapshot', () async {
      final planner = identity(id: dailyOsPlannerAgentId);
      when(
        () => agentService.getAgent(dailyOsPlannerAgentId),
      ).thenAnswer((_) async {
        expect(syncService.inTransaction, isTrue);
        syncService.events.add('read:planner');
        return planner;
      });
      when(
        () => templateService.getTemplate(dayAgentTemplateId),
      ).thenAnswer((_) async {
        expect(syncService.inTransaction, isTrue);
        syncService.events.add('read:template');
        return plannerTemplate;
      });

      await service.resetPlannerInferenceToDefault();

      final updated =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentIdentityEntity;
      expect(updated.config.inferenceSetup?.thinkingModelOverrideId, isNull);
      expect(
        updated.config.inferenceSetup?.origin,
        AgentInferenceSetupOrigin.templateSnapshot,
      );
      expect(syncService.events, [
        'transaction:start',
        'read:planner',
        'read:template',
        'write',
        'transaction:end',
        'notify',
      ]);
    });

    test(
      'profile override rejects a missing planner inside the transaction',
      () async {
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => null);

        await expectLater(
          service.updatePlannerProfileOverride('profile-instance'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Daily OS planner has not been created yet',
            ),
          ),
        );
        verifyNever(() => syncService.upsertEntity(any()));
      },
    );

    for (final validationCase in [
      (
        name: 'missing planner',
        planner: null,
        template: plannerTemplate,
        message: 'Daily OS planner has not been created yet',
      ),
      (
        name: 'missing template',
        planner: identity(id: dailyOsPlannerAgentId),
        template: null,
        message: 'Daily OS template $dayAgentTemplateId not found',
      ),
      (
        name: 'missing default profile',
        planner: identity(id: dailyOsPlannerAgentId),
        template: plannerTemplate.copyWith(profileId: null),
        message: 'Choose a Daily OS default profile first',
      ),
    ]) {
      test('model override rejects a ${validationCase.name}', () async {
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => validationCase.planner);
        when(
          () => templateService.getTemplate(dayAgentTemplateId),
        ).thenAnswer((_) async => validationCase.template);

        await expectLater(
          service.updatePlannerThinkingModelOverride('model-user'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              validationCase.message,
            ),
          ),
        );
        verifyNever(() => syncService.upsertEntity(any()));
      });

      test('reset rejects a ${validationCase.name}', () async {
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => validationCase.planner);
        when(
          () => templateService.getTemplate(dayAgentTemplateId),
        ).thenAnswer((_) async => validationCase.template);

        await expectLater(
          service.resetPlannerInferenceToDefault(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              validationCase.message,
            ),
          ),
        );
        verifyNever(() => syncService.upsertEntity(any()));
      });
    }

    for (final baseCase in [
      (
        name: 'planner profile',
        config: const AgentConfig(
          profileId: 'profile-planner',
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
          ),
        ),
        expected: 'profile-planner',
      ),
      (
        name: 'template profile',
        config: const AgentConfig(
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: AgentInferenceSetupOrigin.user,
          ),
        ),
        expected: 'profile-old',
      ),
      (
        name: 'disabled setup planner profile',
        config: const AgentConfig(
          profileId: 'profile-disabled',
          inferenceSetup: AgentInferenceSetup(
            mode: AgentInferenceSetupMode.disabled,
            origin: AgentInferenceSetupOrigin.user,
          ),
        ),
        expected: 'profile-disabled',
      ),
    ]) {
      test('model override resolves the ${baseCase.name}', () async {
        final planner = identity(
          id: dailyOsPlannerAgentId,
          config: baseCase.config,
        );
        when(
          () => agentService.getAgent(dailyOsPlannerAgentId),
        ).thenAnswer((_) async => planner);
        when(
          () => templateService.getTemplate(dayAgentTemplateId),
        ).thenAnswer((_) async => plannerTemplate);

        await service.updatePlannerThinkingModelOverride('model-user');

        final updated =
            verify(
                  () => syncService.upsertEntity(captureAny()),
                ).captured.single
                as AgentIdentityEntity;
        expect(updated.config.profileId, baseCase.expected);
        expect(
          updated.config.inferenceSetup?.baseProfileId,
          baseCase.expected,
        );
      });
    }
  });
}
