import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService agentService;
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late MockAgentSyncService syncService;
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
    DateTime? createdAt,
  }) {
    return makeTestIdentity(
      id: id,
      agentId: id,
      kind: kind,
      displayName: 'Shepherd',
      currentStateId: 'state-$id',
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
    syncService = MockAgentSyncService();
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
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => syncService.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        workspaceKey: any(named: 'workspaceKey'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn(null);
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

    service = DayAgentService(
      agentService: agentService,
      repository: repository,
      orchestrator: orchestrator,
      syncService: syncService,
      templateService: templateService,
      domainLogger: domainLogger,
      onPersistedStateChanged: changedTokens.add,
    );
  });

  group('DayAgentService', () {
    test('creates one day agent and schedules its creation wake', () async {
      const categoryIds = {'cat-focus'};
      final createdIdentity = identity();
      final initialState = state();
      final template = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
        modelId: 'models/day',
        profileId: 'profile-day',
      );

      when(
        () => repository.getEntity(dayAgentTemplateId),
      ).thenAnswer((_) async => template);
      when(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: categoryIds,
        ),
      ).thenAnswer((_) async => createdIdentity);
      when(
        () => repository.getAgentState(agentId),
      ).thenAnswer((_) async => initialState);

      final result = await withClock(
        Clock.fixed(now),
        () => service.createDayAgent(
          date: testDate,
          allowedCategoryIds: categoryIds,
        ),
      );

      expect(result, createdIdentity);
      final createCall = verify(
        () => agentService.createAgent(
          kind: captureAny(named: 'kind'),
          displayName: captureAny(named: 'displayName'),
          config: captureAny(named: 'config'),
          allowedCategoryIds: categoryIds,
        ),
      ).captured;
      expect(createCall[0], AgentKinds.dayAgent);
      expect(createCall[1], 'Shepherd 2026-05-25');
      expect(
        createCall[2],
        const AgentConfig(modelId: 'models/day', profileId: 'profile-day'),
      );

      final entities = verify(
        () => syncService.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final updatedState = entities.single as AgentStateEntity;
      expect(updatedState.slots.activeDayId, dayId);
      expect(updatedState.updatedAt, now);

      final links = verify(
        () => syncService.upsertLink(captureAny()),
      ).captured.cast<AgentLink>();
      expect(links, hasLength(2));
      final templateLink = links.whereType<TemplateAssignmentLink>().single;
      expect(templateLink.fromId, dayAgentTemplateId);
      expect(templateLink.toId, agentId);
      // Agent → day link so activeDayId is derivable from the synced log (B3).
      final dayLink = links.whereType<AgentDayLink>().single;
      expect(dayLink.fromId, agentId);
      expect(dayLink.toId, dayId);

      verify(
        () => orchestrator.enqueueManualWake(
          agentId: agentId,
          reason: WakeReason.creation.name,
          workspaceKey: dayAgentWorkspaceKey(dayId),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        ),
      ).called(1);
      expect(changedTokens, [agentId, dayId]);
    });

    test('rejects duplicate active day agent for the same date', () async {
      final existing = identity();
      when(
        () => repository.getActiveAgentByKindAndActiveDayId(
          kind: AgentKinds.dayAgent,
          activeDayId: dayId,
        ),
      ).thenAnswer(
        (_) async => existing,
      );

      await expectLater(
        service.createDayAgent(date: testDate),
        throwsA(isA<StateError>()),
      );

      verifyNever(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
        ),
      );
    });

    test(
      'rejects a duplicate discovered inside the create transaction',
      () async {
        final existing = identity(id: 'race-winner');
        var lookupCount = 0;
        when(
          () => repository.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          ),
        ).thenAnswer((_) async {
          lookupCount++;
          return lookupCount == 1 ? null : existing;
        });

        await expectLater(
          service.createDayAgent(date: testDate),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('race-winner'),
            ),
          ),
        );

        verifyNever(() => repository.getEntity(any()));
        verifyNever(
          () => agentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
          ),
        );
      },
    );

    test('rejects templates that are not active day-agent templates', () async {
      final projectTemplate = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.projectAgent,
      );
      when(
        () => repository.getEntity(dayAgentTemplateId),
      ).thenAnswer((_) async => projectTemplate);

      await expectLater(
        service.createDayAgent(date: testDate),
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
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
        ),
      );
    });

    test('throws when the newly created agent has no state entity', () async {
      final createdIdentity = identity();
      final template = makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
      );
      when(
        () => repository.getEntity(dayAgentTemplateId),
      ).thenAnswer((_) async => template);
      when(
        () => agentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).thenAnswer((_) async => createdIdentity);
      when(
        () => repository.getAgentState(agentId),
      ).thenAnswer((_) async => null);

      await expectLater(
        service.createDayAgent(date: testDate),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('has no state entity'),
          ),
        ),
      );

      verifyNever(() => syncService.upsertLink(any()));
      verifyNever(
        () => orchestrator.enqueueManualWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          workspaceKey: any(named: 'workspaceKey'),
          triggerTokens: any(named: 'triggerTokens'),
        ),
      );
    });

    test('getDayAgentForDate uses targeted active-day lookup', () async {
      final newer = identity(id: 'newer', createdAt: DateTime(2026, 5, 25));
      when(
        () => repository.getActiveAgentByKindAndActiveDayId(
          kind: AgentKinds.dayAgent,
          activeDayId: dayId,
        ),
      ).thenAnswer(
        (_) async => newer,
      );

      final result = await service.getDayAgentForDate(testDate);

      expect(result?.agentId, 'newer');
      verify(
        () => repository.getActiveAgentByKindAndActiveDayId(
          kind: AgentKinds.dayAgent,
          activeDayId: dayId,
        ),
      ).called(1);
      verifyNever(
        () => repository.getAgentStatesByAgentIds(any()),
      );
    });

    test(
      'restoreSubscriptions hydrates pending wakes for active day agents',
      () async {
        final dueAt = DateTime(2026, 5, 25, 6, 30);
        final dayAgent = identity();
        final taskAgent = identity(
          id: 'task-agent',
          kind: AgentKinds.taskAgent,
        );
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [taskAgent, dayAgent]);
        when(
          () => repository.getAgentState(agentId),
        ).thenAnswer((_) async => state(activeDayId: dayId, nextWakeAt: dueAt));

        await service.restoreSubscriptions();

        verify(
          () => orchestrator.restorePendingWake(agentId: agentId, dueAt: dueAt),
        ).called(1);
        verifyNever(() => repository.getAgentState('task-agent'));
      },
    );

    group('enqueueDraftingWake', () {
      test(
        'enqueues a drafting wake with the day-id token when an agent exists',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());

          final result = await service.enqueueDraftingWake(dayDate: testDate);

          expect(result, isTrue);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentDraftingReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentDraftingToken(dayId),
              },
            ),
          ).called(1);
        },
      );

      test(
        'adds the capture-submitted token when captureId is provided',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());

          final result = await service.enqueueDraftingWake(
            dayDate: testDate,
            captureId: '  capture-42  ',
          );

          expect(result, isTrue);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentDraftingReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentDraftingToken(dayId),
                dayAgentCaptureSubmittedToken('capture-42'),
              },
            ),
          ).called(1);
        },
      );

      test(
        'ignores a blank captureId and emits only the drafting token',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());

          final result = await service.enqueueDraftingWake(
            dayDate: testDate,
            captureId: '   ',
          );

          expect(result, isTrue);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentDraftingReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentDraftingToken(dayId),
              },
            ),
          ).called(1);
        },
      );

      test(
        'returns false and skips enqueue when no day agent exists',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => null);

          final result = await service.enqueueDraftingWake(dayDate: testDate);

          expect(result, isFalse);
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

      test('encodes decidedTaskIds as per-task trigger tokens', () async {
        when(
          () => repository.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          ),
        ).thenAnswer((_) async => identity());

        final result = await service.enqueueDraftingWake(
          dayDate: testDate,
          decidedTaskIds: const ['task-1', 'task-2'],
        );

        expect(result, isTrue);
        verify(
          () => orchestrator.enqueueManualWake(
            agentId: agentId,
            reason: dayAgentDraftingReason,
            workspaceKey: any(named: 'workspaceKey'),
            triggerTokens: {
              dayAgentPlanningDayToken(dayId),
              dayAgentDraftingToken(dayId),
              dayAgentDecidedTaskToken('task-1'),
              dayAgentDecidedTaskToken('task-2'),
            },
          ),
        ).called(1);
      });

      test(
        'encodes decidedCaptureItemIds as parsed-item trigger tokens',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());

          final result = await service.enqueueDraftingWake(
            dayDate: testDate,
            decidedCaptureItemIds: const ['parsed-1', 'parsed-2'],
          );

          expect(result, isTrue);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentDraftingReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentDraftingToken(dayId),
                dayAgentDecidedCaptureItemToken('parsed-1'),
                dayAgentDecidedCaptureItemToken('parsed-2'),
              },
            ),
          ).called(1);
        },
      );

      test(
        'merges drafting + capture + decided-task tokens in one wake',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());

          final result = await service.enqueueDraftingWake(
            dayDate: testDate,
            captureId: 'capture-99',
            decidedTaskIds: const ['task-7'],
          );

          expect(result, isTrue);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentDraftingReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentDraftingToken(dayId),
                dayAgentCaptureSubmittedToken('capture-99'),
                dayAgentDecidedTaskToken('task-7'),
              },
            ),
          ).called(1);
        },
      );

      test('skips blank decidedTaskIds entries', () async {
        when(
          () => repository.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          ),
        ).thenAnswer((_) async => identity());

        final result = await service.enqueueDraftingWake(
          dayDate: testDate,
          decidedTaskIds: const ['task-1', '', '   ', 'task-2'],
        );

        expect(result, isTrue);
        verify(
          () => orchestrator.enqueueManualWake(
            agentId: agentId,
            reason: dayAgentDraftingReason,
            workspaceKey: any(named: 'workspaceKey'),
            triggerTokens: {
              dayAgentPlanningDayToken(dayId),
              dayAgentDraftingToken(dayId),
              dayAgentDecidedTaskToken('task-1'),
              dayAgentDecidedTaskToken('task-2'),
            },
          ),
        ).called(1);
      });

      test(
        'dedupes duplicate decidedTaskIds via the trigger-token set',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());

          final result = await service.enqueueDraftingWake(
            dayDate: testDate,
            decidedTaskIds: const ['task-1', 'task-1', '  task-1  '],
          );

          expect(result, isTrue);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentDraftingReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentDraftingToken(dayId),
                dayAgentDecidedTaskToken('task-1'),
              },
            ),
          ).called(1);
        },
      );
    });

    group('enqueueRefineWake', () {
      DayPlanEntity seedPlan({
        String planAgentId = agentId,
        DateTime? deletedAt,
        DayPlanStatus status = const DayPlanStatus.draft(),
      }) {
        return AgentDomainEntity.dayPlan(
              id: dayAgentPlanEntityId(dayId),
              agentId: planAgentId,
              dayId: dayId,
              planDate: DateTime(2026, 5, 25),
              data: DayPlanData(
                planDate: DateTime(2026, 5, 25),
                status: status,
              ),
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
              deletedAt: deletedAt,
            )
            as DayPlanEntity;
      }

      void stubPlanLookup(DayPlanEntity? plan) {
        when(
          () => repository.getEntity(dayAgentPlanEntityId(dayId)),
        ).thenAnswer((_) async => plan);
      }

      test(
        'persists a refine capture and fires the wake with both tokens',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());
          stubPlanLookup(seedPlan());

          final result = await withClock(
            Clock.fixed(now),
            () => service.enqueueRefineWake(
              dayDate: testDate,
              transcript: 'move lunch to 1pm',
            ),
          );

          expect(result, isTrue);
          final captured = verify(
            () => syncService.upsertEntity(captureAny()),
          ).captured;
          final capture = captured.single as CaptureEntity;
          expect(capture.id, startsWith('refine_capture:'));
          expect(capture.transcript, 'move lunch to 1pm');
          expect(capture.capturedAt, now);
          expect(capture.dayId, dayId);
          expect(changedTokens, [capture.id]);

          final tokens =
              verify(
                    () => orchestrator.enqueueManualWake(
                      agentId: agentId,
                      reason: dayAgentRefineReason,
                      workspaceKey: any(named: 'workspaceKey'),
                      triggerTokens: captureAny(named: 'triggerTokens'),
                    ),
                  ).captured.single
                  as Set<String>;
          expect(tokens, {
            dayAgentPlanningDayToken(dayId),
            dayAgentRefineToken(dayId),
            dayAgentCaptureSubmittedToken(capture.id),
          });
        },
      );

      test(
        'a near-midnight refine stamps the PLAN day, not the capture-time day',
        () async {
          // Refining tomorrow's plan at 23:30 today: the capture must be
          // bucketed to the plan day (ADR 0022), not the calendar day the user
          // happened to speak on, so capturesForDateProvider surfaces it on the
          // right day.
          const planDayId = 'dayplan-2026-05-26';
          final planDate = DateTime(2026, 5, 26, 9);
          final lateNight = DateTime(2026, 5, 25, 23, 30);
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: planDayId,
            ),
          ).thenAnswer((_) async => identity());
          when(
            () => repository.getEntity(dayAgentPlanEntityId(planDayId)),
          ).thenAnswer(
            (_) async =>
                seedPlan().copyWith(id: dayAgentPlanEntityId(planDayId)),
          );

          await withClock(
            Clock.fixed(lateNight),
            () => service.enqueueRefineWake(
              dayDate: planDate,
              transcript: 'shift standup earlier',
            ),
          );

          final capture =
              verify(
                    () => syncService.upsertEntity(captureAny()),
                  ).captured.single
                  as CaptureEntity;
          expect(capture.capturedAt, lateNight);
          // Stamped with the plan day, not dayplan-2026-05-25.
          expect(capture.dayId, planDayId);
        },
      );

      test(
        'blank transcript skips capture and fires wake with only refine token',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());
          stubPlanLookup(seedPlan());

          final result = await service.enqueueRefineWake(
            dayDate: testDate,
            transcript: '   ',
          );

          expect(result, isTrue);
          verifyNever(() => syncService.upsertEntity(any()));
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId,
              reason: dayAgentRefineReason,
              workspaceKey: any(named: 'workspaceKey'),
              triggerTokens: {
                dayAgentPlanningDayToken(dayId),
                dayAgentRefineToken(dayId),
              },
            ),
          ).called(1);
        },
      );

      test(
        'returns false and skips enqueue when no day agent exists',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => null);

          final result = await service.enqueueRefineWake(
            dayDate: testDate,
            transcript: 'something',
          );

          expect(result, isFalse);
          verifyNever(() => syncService.upsertEntity(any()));
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

      test(
        'returns false and skips enqueue when no plan exists',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());
          stubPlanLookup(null);

          final result = await service.enqueueRefineWake(
            dayDate: testDate,
            transcript: 'something',
          );

          expect(result, isFalse);
          verifyNever(() => syncService.upsertEntity(any()));
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

      test(
        'returns false when the plan belongs to a different agent',
        () async {
          when(
            () => repository.getActiveAgentByKindAndActiveDayId(
              kind: AgentKinds.dayAgent,
              activeDayId: dayId,
            ),
          ).thenAnswer((_) async => identity());
          stubPlanLookup(seedPlan(planAgentId: 'other-agent'));

          final result = await service.enqueueRefineWake(
            dayDate: testDate,
            transcript: 'something',
          );

          expect(result, isFalse);
          verifyNever(() => syncService.upsertEntity(any()));
        },
      );

      test('returns false when the plan is soft-deleted', () async {
        when(
          () => repository.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          ),
        ).thenAnswer((_) async => identity());
        stubPlanLookup(seedPlan(deletedAt: DateTime(2026, 5, 25)));

        final result = await service.enqueueRefineWake(
          dayDate: testDate,
          transcript: 'something',
        );

        expect(result, isFalse);
        verifyNever(() => syncService.upsertEntity(any()));
      });

      test('enqueues refine wake for committed or agreed plans', () async {
        when(
          () => repository.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          ),
        ).thenAnswer((_) async => identity());

        final statuses = <DayPlanStatus>[
          DayPlanStatus.committed(committedAt: DateTime(2026, 5, 25, 11)),
          DayPlanStatus.agreed(agreedAt: DateTime(2026, 5, 25, 10)),
        ];
        for (final status in statuses) {
          stubPlanLookup(seedPlan(status: status));

          final result = await service.enqueueRefineWake(
            dayDate: testDate,
            transcript: '   ',
          );

          expect(result, isTrue);
        }
        verifyNever(() => syncService.upsertEntity(any()));
        verify(
          () => orchestrator.enqueueManualWake(
            agentId: agentId,
            reason: dayAgentRefineReason,
            workspaceKey: any(named: 'workspaceKey'),
            triggerTokens: {
              dayAgentPlanningDayToken(dayId),
              dayAgentRefineToken(dayId),
            },
          ),
        ).called(statuses.length);
      });
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
      'restoreSubscriptions logs and continues after a hydrate failure',
      () async {
        final dueAt = DateTime(2026, 5, 25, 6, 30);
        final failingDayAgent = identity(id: 'failing-day-agent');
        final healthyDayAgent = identity(id: 'healthy-day-agent');
        when(
          () => agentService.listAgents(lifecycle: AgentLifecycle.active),
        ).thenAnswer((_) async => [failingDayAgent, healthyDayAgent]);
        when(
          () => repository.getAgentState('failing-day-agent'),
        ).thenThrow(StateError('state read failed'));
        when(
          () => repository.getAgentState('healthy-day-agent'),
        ).thenAnswer(
          (_) async => state(
            id: 'state-healthy',
            stateAgentId: 'healthy-day-agent',
            activeDayId: dayId,
            nextWakeAt: dueAt,
          ),
        );

        await service.restoreSubscriptions();

        verify(
          () => orchestrator.restorePendingWake(
            agentId: 'healthy-day-agent',
            dueAt: dueAt,
          ),
        ).called(1);
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
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).captured;
        expect(createCall[0], AgentKinds.dayAgent);
        expect(createCall[1], dailyOsPlannerAgentId);

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
  });
}
