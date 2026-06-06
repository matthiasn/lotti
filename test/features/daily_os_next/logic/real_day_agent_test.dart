import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../categories/test_utils.dart';

final _asOf = DateTime(2026, 5, 25, 9);

DayPlanEntity buildDayPlan({
  required String agentId,
  required String dayId,
  DateTime? updatedAt,
  List<PlannedBlock> blocks = const <PlannedBlock>[],
  int capacityMinutes = 480,
  int scheduledMinutes = 0,
}) {
  final timestamp = updatedAt ?? _asOf;
  return AgentDomainEntity.dayPlan(
        id: 'day_agent_plan:$dayId',
        agentId: agentId,
        dayId: dayId,
        planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
        data: DayPlanData(
          planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
          status: const DayPlanStatus.draft(),
          plannedBlocks: blocks,
        ),
        capacityMinutes: capacityMinutes,
        scheduledMinutes: scheduledMinutes,
        createdAt: timestamp,
        updatedAt: timestamp,
        vectorClock: null,
      )
      as DayPlanEntity;
}

ChangeSetEntity buildChangeSet({
  required String agentId,
  String id = 'diff-001',
  List<ChangeItem> items = const <ChangeItem>[],
}) {
  return AgentDomainEntity.changeSet(
        id: id,
        agentId: agentId,
        taskId: 'day_agent_plan:${dayAgentIdForDate(_asOf)}',
        threadId: 'thread-001',
        runKey: 'run-001',
        status: ChangeSetStatus.pending,
        items: items,
        createdAt: _asOf,
        vectorClock: null,
      )
      as ChangeSetEntity;
}

PlanDiff buildDiff({String id = 'diff-001'}) => PlanDiff(
  id: id,
  transcript: 'move the gym',
  changes: const <PlanDiffChange>[],
  updatedPlan: DraftPlan(
    dayDate: _asOf,
    blocks: const <TimeBlock>[],
    bands: const <EnergyBand>[],
    capacityMinutes: 480,
    scheduledMinutes: 0,
  ),
);

/// Shared five-mock + adapter scaffolding used by every group in this file.
class _TestBench {
  _TestBench._({required this.fallback})
    : captureService = MockDayAgentCaptureService(),
      planService = MockDayAgentPlanService(),
      dayAgentService = MockDayAgentService(),
      journalDb = MockJournalDb();

  factory _TestBench.create({MockDayAgent? fallback}) =>
      _TestBench._(fallback: fallback ?? MockDayAgent());

  final MockDayAgentCaptureService captureService;
  final MockDayAgentPlanService planService;
  final MockDayAgentService dayAgentService;
  final MockJournalDb journalDb;
  final MockDayAgent fallback;

  late final RealDayAgent adapter = RealDayAgent(
    captureService: captureService,
    planService: planService,
    dayAgentService: dayAgentService,
    journalDb: journalDb,
    mockFallback: fallback,
  );
}

void main() {
  group('RealDayAgent.summarizeRecentPatterns', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'returns an empty list when no day-agent exists for the date',
      () async {
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => null,
        );

        final cards = await bench.adapter.summarizeRecentPatterns(asOf: _asOf);

        expect(cards, isEmpty);
        verifyNever(
          () => bench.planService.summarizeRecentPatterns(
            agentId: any(named: 'agentId'),
            asOf: any(named: 'asOf'),
            lookbackDays: any(named: 'lookbackDays'),
          ),
        );
      },
    );

    test('projects backend cards onto UI LearningCard shape', () async {
      const agentId = 'day-agent-001';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.summarizeRecentPatterns(
          agentId: agentId,
          asOf: _asOf,
        ),
      ).thenAnswer(
        (_) async => [
          DayAgentLearningCard(
            id: 'yesterday',
            overline: 'Yesterday',
            summary: 'You drafted four blocks.',
            bullets: const [
              DayAgentLearningBullet(
                text: 'Carry forward the demo prep block.',
                tone: DayAgentLearningBulletTone.positive,
              ),
            ],
          ),
          DayAgentLearningCard(
            id: 'gentle_nudge',
            overline: 'Gentle nudge',
            summary: 'Protect a transition before piling on more work.',
            kind: 'nudge',
            bullets: const [
              DayAgentLearningBullet(
                text: 'Leave at least one buffer unassigned.',
                tone: DayAgentLearningBulletTone.warning,
              ),
            ],
          ),
        ],
      );

      final cards = await bench.adapter.summarizeRecentPatterns(asOf: _asOf);

      expect(cards, hasLength(2));
      expect(cards[0].id, 'yesterday');
      expect(cards[0].overline, 'Yesterday');
      expect(cards[0].summary, 'You drafted four blocks.');
      expect(cards[0].kind, LearningCardKind.standard);
      expect(cards[0].bullets, hasLength(1));
      expect(
        cards[0].bullets.single.text,
        'Carry forward the demo prep block.',
      );
      expect(cards[0].bullets.single.tone, LearningBulletTone.positive);

      expect(cards[1].id, 'gentle_nudge');
      expect(cards[1].kind, LearningCardKind.nudge);
      expect(cards[1].bullets.single.tone, LearningBulletTone.warning);
    });

    test('forwards a custom lookbackDays argument', () async {
      const agentId = 'day-agent-002';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.summarizeRecentPatterns(
          agentId: any(named: 'agentId'),
          asOf: any(named: 'asOf'),
          lookbackDays: any(named: 'lookbackDays'),
        ),
      ).thenAnswer((_) async => const <DayAgentLearningCard>[]);

      await bench.adapter.summarizeRecentPatterns(
        asOf: _asOf,
        lookbackDays: 14,
      );

      verify(
        () => bench.planService.summarizeRecentPatterns(
          agentId: agentId,
          asOf: _asOf,
          lookbackDays: 14,
        ),
      ).called(1);
    });
  });

  group('RealDayAgent.draftDayPlan', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'enqueues the drafting wake, awaits the persisted plan, '
      'and projects it onto DraftPlan',
      () {
        const agentId = 'day-agent-001';
        final dayId = dayAgentIdForDate(_asOf);
        final freshlyDraftedAt = _asOf.add(const Duration(seconds: 5));
        var draftPlanCalls = 0;

        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async {
          draftPlanCalls++;
          // First call is the baseline read before the wake fires.
          // Subsequent reads return the freshly drafted plan.
          if (draftPlanCalls == 1) return null;
          return buildDayPlan(
            agentId: agentId,
            dayId: dayId,
            updatedAt: freshlyDraftedAt,
            blocks: [
              PlannedBlock(
                id: 'block_1',
                categoryId: 'work',
                startTime: _asOf.add(const Duration(hours: 1)),
                endTime: _asOf.add(const Duration(hours: 2)),
                title: 'Demo prep',
                reason: 'High-energy window',
              ),
            ],
          );
        });
        when(
          () => bench.dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
            decidedCaptureItemIds: any(named: 'decidedCaptureItemIds'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        // Drive the 500 ms poll loop with fake time so the test takes
        // microseconds instead of a real poll interval (fake-time policy).
        late DraftPlan result;
        fakeAsync((async) {
          withClock(async.getClock(_asOf), () {
            bench.adapter
                .draftDayPlan(
                  captureId: const CaptureId('cap_1'),
                  decidedTaskIds: const ['t_1'],
                  decidedCaptureItemIds: const ['parsed_1'],
                  dayDate: _asOf,
                )
                .then((plan) => result = plan);
          });
          // Flush up to the first poll delay, elapse it, then let the
          // second draftPlanForDay read observe the fresh plan.
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 500))
            ..flushMicrotasks();
        });

        expect(result.blocks, hasLength(1));
        expect(result.blocks.single.title, 'Demo prep');
        expect(result.blocks.single.type, TimeBlockType.ai);
        expect(result.blocks.single.reason, 'High-energy window');
        expect(result.capacityMinutes, 480);
        expect(result.scheduledMinutes, 60);
        expect(result.state, DayState.drafted);

        // Standalone block (no taskId) still becomes one agenda item so
        // the Agenda surface mirrors the Day timeline.
        expect(result.agendaItems, hasLength(1));
        expect(result.agendaItems.single.title, 'Demo prep');
        expect(result.agendaItems.single.linkedBlockIds, ['block_1']);
        expect(result.agendaItems.single.taskId, isNull);

        verify(
          () => bench.dayAgentService.enqueueDraftingWake(
            dayDate: _asOf,
            captureId: 'cap_1',
            decidedTaskIds: ['t_1'],
            decidedCaptureItemIds: ['parsed_1'],
          ),
        ).called(1);
      },
    );

    test(
      'throws DayAgentInteractionException when no day-agent exists for '
      'the date',
      () async {
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.draftDayPlan(
            captureId: const CaptureId('cap_1'),
            decidedTaskIds: const [],
            dayDate: _asOf,
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
        verifyNever(
          () => bench.dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
            decidedCaptureItemIds: any(named: 'decidedCaptureItemIds'),
          ),
        );
      },
    );

    test(
      'throws DayAgentInteractionException when enqueueDraftingWake reports '
      'no agent',
      () async {
        const agentId = 'day-agent-001';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => bench.dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
            decidedCaptureItemIds: any(named: 'decidedCaptureItemIds'),
          ),
        ).thenAnswer((_) async => false);

        await expectLater(
          bench.adapter.draftDayPlan(
            captureId: const CaptureId('cap_1'),
            decidedTaskIds: const [],
            dayDate: _asOf,
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );
  });

  group('RealDayAgent.resolveDiffItems', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('acceptDiff forwards selected item indices', () async {
      const agentId = 'day-agent-001';
      final dayId = dayAgentIdForDate(_asOf);
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.acceptPlanDiff(
          agentId: any(named: 'agentId'),
          changeSetId: any(named: 'changeSetId'),
          itemIndices: any(named: 'itemIndices'),
        ),
      ).thenAnswer((_) async => buildChangeSet(agentId: agentId));
      when(
        () => bench.planService.draftPlanForDay(
          agentId: agentId,
          dayId: dayId,
        ),
      ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));

      final result = await bench.adapter.acceptDiff(
        buildDiff(),
        itemIndices: [1],
      );

      final captured =
          verify(
                () => bench.planService.acceptPlanDiff(
                  agentId: agentId,
                  changeSetId: 'diff-001',
                  itemIndices: captureAny(named: 'itemIndices'),
                ),
              ).captured.single
              as List<int>;
      expect(captured, [1]);
      expect(result.dayDate, _asOf);
    });

    test(
      'revertDiff forwards selected item indices and refetches the plan',
      () async {
        const agentId = 'day-agent-001';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.revertPlanDiff(
            agentId: any(named: 'agentId'),
            changeSetId: any(named: 'changeSetId'),
            itemIndices: any(named: 'itemIndices'),
          ),
        ).thenAnswer((_) async => buildChangeSet(agentId: agentId));
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));

        final result = await bench.adapter.revertDiff(
          diff: buildDiff(),
          originalPlan: buildDiff().updatedPlan,
          itemIndices: [0],
        );

        final captured =
            verify(
                  () => bench.planService.revertPlanDiff(
                    agentId: agentId,
                    changeSetId: 'diff-001',
                    itemIndices: captureAny(named: 'itemIndices'),
                  ),
                ).captured.single
                as List<int>;
        expect(captured, [0]);
        expect(result.dayDate, _asOf);
        verify(
          () =>
              bench.planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).called(1);
      },
    );
  });

  group('RealDayAgent.commitDay', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'calls commitDay on the plan service and projects the result',
      () async {
        const agentId = 'day-agent-001';
        final dayDate = DateTime(_asOf.year, _asOf.month, _asOf.day);
        final committedAt = dayDate.add(const Duration(hours: 9));
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.commitDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.dayPlan(
                    id: 'day_agent_plan:${dayAgentIdForDate(dayDate)}',
                    agentId: agentId,
                    dayId: dayAgentIdForDate(dayDate),
                    planDate: dayDate,
                    data: DayPlanData(
                      planDate: dayDate,
                      status: DayPlanStatus.committed(committedAt: committedAt),
                      plannedBlocks: [
                        PlannedBlock(
                          id: 'block_1',
                          categoryId: 'work',
                          startTime: dayDate.add(const Duration(hours: 9)),
                          endTime: dayDate.add(const Duration(hours: 10)),
                          title: 'Focus block',
                          state: PlannedBlockState.committed,
                        ),
                      ],
                    ),
                    scheduledMinutes: 60,
                    createdAt: dayDate,
                    updatedAt: committedAt,
                    vectorClock: null,
                  )
                  as DayPlanEntity,
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final plan = DraftPlan(
          dayDate: dayDate,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 60,
        );

        final result = await bench.adapter.commitDay(plan);

        expect(result.state, DayState.committed);
        expect(result.blocks, hasLength(1));
        expect(result.blocks.single.state, TimeBlockState.committed);
        verify(
          () => bench.planService.commitDay(
            agentId: agentId,
            dayId: dayAgentIdForDate(dayDate),
          ),
        ).called(1);
      },
    );

    test(
      'throws DayAgentInteractionException when no day-agent exists',
      () async {
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        final plan = DraftPlan(
          dayDate: _asOf,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 0,
        );

        await expectLater(
          bench.adapter.commitDay(plan),
          throwsA(isA<DayAgentInteractionException>()),
        );
        verifyNever(
          () => bench.planService.commitDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        );
      },
    );
  });

  group('RealDayAgent.submitCapture', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    CaptureEntity buildCapture(String id, String agentId) {
      return AgentDomainEntity.capture(
            id: id,
            agentId: agentId,
            transcript: 'hello world',
            capturedAt: _asOf,
            createdAt: _asOf,
            vectorClock: null,
          )
          as CaptureEntity;
    }

    test(
      'reuses an existing day-agent and forwards transcript + audioId',
      () async {
        const agentId = 'day-agent-A';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.submitCapture(
            agentId: any(named: 'agentId'),
            transcript: any(named: 'transcript'),
            capturedAt: any(named: 'capturedAt'),
            audioRef: any(named: 'audioRef'),
          ),
        ).thenAnswer((_) async => buildCapture('cap-1', agentId));

        final captureId = await bench.adapter.submitCapture(
          transcript: 'hello world',
          capturedAt: _asOf,
          audioId: 'audio-1',
        );

        expect(captureId.value, 'cap-1');
        verifyNever(
          () => bench.dayAgentService.createDayAgent(date: any(named: 'date')),
        );
        verify(
          () => bench.captureService.submitCapture(
            agentId: agentId,
            transcript: 'hello world',
            capturedAt: _asOf,
            audioRef: 'audio-1',
          ),
        ).called(1);
      },
    );

    test(
      'creates a fresh day-agent when none exists for the capture date',
      () async {
        const agentId = 'day-agent-B';
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);
        when(
          () => bench.dayAgentService.createDayAgent(date: any(named: 'date')),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.submitCapture(
            agentId: any(named: 'agentId'),
            transcript: any(named: 'transcript'),
            capturedAt: any(named: 'capturedAt'),
            audioRef: any(named: 'audioRef'),
          ),
        ).thenAnswer((_) async => buildCapture('cap-2', agentId));

        final captureId = await bench.adapter.submitCapture(
          transcript: 'first capture',
          capturedAt: _asOf,
        );

        expect(captureId.value, 'cap-2');
        verify(
          () => bench.dayAgentService.createDayAgent(date: _asOf),
        ).called(1);
      },
    );
  });

  group('RealDayAgent.currentPlanForDate / deletePlanForDate', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('currentPlanForDate returns null when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final plan = await bench.adapter.currentPlanForDate(_asOf);
      expect(plan, isNull);
      verifyNever(
        () => bench.planService.draftPlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test(
      'currentPlanForDate returns null when the plan service yields no plan',
      () async {
        const agentId = 'day-agent-C';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        final plan = await bench.adapter.currentPlanForDate(_asOf);
        expect(plan, isNull);
      },
    );

    test(
      'currentPlanForDate projects an existing plan onto DraftPlan',
      () async {
        const agentId = 'day-agent-D';
        final dayId = dayAgentIdForDate(_asOf);
        final dayDate = DateTime(_asOf.year, _asOf.month, _asOf.day);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.dayPlan(
                    id: 'day_agent_plan:$dayId',
                    agentId: agentId,
                    dayId: dayId,
                    planDate: dayDate,
                    data: DayPlanData(
                      planDate: dayDate,
                      status: const DayPlanStatus.draft(),
                    ),
                    createdAt: _asOf,
                    updatedAt: _asOf,
                    vectorClock: null,
                  )
                  as DayPlanEntity,
        );

        final plan = await bench.adapter.currentPlanForDate(_asOf);
        expect(plan, isNotNull);
        expect(plan!.dayDate, _asOf);
        expect(plan.state, DayState.drafted);
      },
    );

    test('deletePlanForDate returns false when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final removed = await bench.adapter.deletePlanForDate(_asOf);
      expect(removed, isFalse);
      verifyNever(
        () => bench.planService.deletePlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test('deletePlanForDate delegates to the plan service', () async {
      const agentId = 'day-agent-E';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.deletePlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer((_) async => true);

      final removed = await bench.adapter.deletePlanForDate(_asOf);
      expect(removed, isTrue);
      verify(
        () => bench.planService.deletePlanForDay(
          agentId: agentId,
          dayId: dayAgentIdForDate(_asOf),
        ),
      ).called(1);
    });
  });

  group('RealDayAgent.parseCaptureToItems / projection helpers', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    ParsedItemEntity buildParsedItem({
      String id = 'parsed-1',
      String? categoryId,
      String? matchedTaskId,
    }) {
      return AgentDomainEntity.parsedItem(
            id: id,
            agentId: 'agent',
            captureId: 'cap',
            kind: ParsedItemKind.newTask,
            title: 'Item title',
            categoryId: categoryId ?? '',
            confidence: ParsedItemConfidence.high,
            confidenceScore: 0.9,
            spokenPhrase: 'spoken',
            matchedTaskId: matchedTaskId,
            estimateMinutes: 30,
            timeAnchor: 'before 11am',
            proposedUpdate: 'finish soon',
            createdAt: _asOf,
            vectorClock: null,
          )
          as ParsedItemEntity;
    }

    test(
      'projects parsed entities and looks up matched task titles + categories',
      () async {
        final category = CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          name: 'Work',
          color: '#FFAA00',
        );
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [
            buildParsedItem(
              id: 'parsed-a',
              categoryId: 'cat-1',
              matchedTaskId: testTask.meta.id,
            ),
          ],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-1'),
        ).thenAnswer((_) async => category);
        when(
          () => bench.journalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => testTask);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items, hasLength(1));
        final item = items.single;
        expect(item.id, 'parsed-a');
        expect(item.matchedTaskTitle, testTask.data.title);
        expect(item.category.id, 'cat-1');
        expect(item.category.colorHex, 'FFAA00');
        expect(item.estimateMinutes, 30);
        expect(item.timeAnchor, 'before 11am');
        expect(item.proposedUpdate, 'finish soon');
      },
    );

    test(
      'falls back to the uncategorised category when categoryId is empty',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer((_) async => [buildParsedItem()]);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items.single.category.id, 'unknown');
        verifyNever(() => bench.journalDb.getCategoryById(any()));
      },
    );

    test(
      'falls back to the uncategorised id when the category row is missing',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [buildParsedItem(categoryId: 'cat-missing')],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-missing'),
        ).thenAnswer((_) async => null);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items.single.category.id, 'cat-missing');
        // Uncategorised fallback colour preserved.
        expect(items.single.category.colorHex, '5ED4B7');
      },
    );

    test(
      'caches resolved categories so repeated parses hit the DB once per id',
      () async {
        final category = CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          name: 'Work',
        );
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [
            buildParsedItem(id: 'p-1', categoryId: 'cat-1'),
            buildParsedItem(id: 'p-2', categoryId: 'cat-1'),
          ],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-1'),
        ).thenAnswer((_) async => category);

        await bench.adapter.parseCaptureToItems(const CaptureId('cap'));
        await bench.adapter.parseCaptureToItems(const CaptureId('cap'));

        verify(() => bench.journalDb.getCategoryById('cat-1')).called(1);
      },
    );

    test(
      'leaves matchedTaskTitle null when the linked entity is not a task',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [buildParsedItem(matchedTaskId: 'not-a-task')],
        );
        when(
          () => bench.journalDb.journalEntityById('not-a-task'),
        ).thenAnswer((_) async => null);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items.single.matchedTaskTitle, isNull);
      },
    );

    test(
      'trims a too-long colour string to 6 chars and replaces blanks',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [
            buildParsedItem(id: 'p-long', categoryId: 'cat-long'),
            buildParsedItem(id: 'p-empty', categoryId: 'cat-empty'),
          ],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-long'),
        ).thenAnswer(
          (_) async => CategoryTestUtils.createTestCategory(
            id: 'cat-long',
            name: 'Long',
            color: '#ABCDEF1234',
          ),
        );
        when(
          () => bench.journalDb.getCategoryById('cat-empty'),
        ).thenAnswer(
          (_) async => CategoryTestUtils.createTestCategory(
            id: 'cat-empty',
            name: 'Empty',
            color: '',
          ),
        );

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items[0].category.colorHex, 'ABCDEF');
        expect(items[1].category.colorHex, '5ED4B7');
      },
    );
  });

  group('RealDayAgent.surfacePendingDecisions', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('returns empty when no day-agent exists for the date', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final items = await bench.adapter.surfacePendingDecisions(forDate: _asOf);
      expect(items, isEmpty);
      verifyNever(
        () => bench.captureService.surfacePendingDecisions(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test(
      'projects all pending-kind enums into PendingItemReason values',
      () async {
        const agentId = 'agent-pending';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.surfacePendingDecisions(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async => [
            DayAgentPendingItem(
              taskId: 't-overdue',
              title: 'Overdue',
              kind: DayAgentPendingKind.overdue,
              status: 'OPEN',
              categoryId: null,
              due: _asOf.subtract(const Duration(days: 3)),
            ),
            const DayAgentPendingItem(
              taskId: 't-inprogress',
              title: 'In progress',
              kind: DayAgentPendingKind.inProgress,
              status: 'IN_PROGRESS',
              categoryId: null,
            ),
            const DayAgentPendingItem(
              taskId: 't-recurring',
              title: 'Recurring',
              kind: DayAgentPendingKind.missedRecurring,
              status: 'OPEN',
              categoryId: null,
            ),
            const DayAgentPendingItem(
              taskId: 't-today',
              title: 'Due today',
              kind: DayAgentPendingKind.dueToday,
              status: 'OPEN',
              categoryId: null,
            ),
          ],
        );

        final items = await withClock(Clock.fixed(_asOf), () {
          return bench.adapter.surfacePendingDecisions(forDate: _asOf);
        });
        expect(items.map((i) => i.reason), [
          PendingItemReason.overdue,
          PendingItemReason.inProgress,
          PendingItemReason.missedRecurring,
          PendingItemReason.dueToday,
        ]);
        // overdueByDays is only populated for the overdue reason with a
        // non-null due date.
        expect(items[0].overdueByDays, 3);
        expect(items[0].referenceDate, isNull);
        expect(items[1].overdueByDays, isNull);
        expect(items[3].overdueByDays, isNull);
      },
    );

    test(
      'computes overdue age and label reference from the selected plan date',
      () async {
        const agentId = 'agent-future-pending';
        final selectedDate = DateTime(2026, 5, 30, 9);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.surfacePendingDecisions(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async => [
            DayAgentPendingItem(
              taskId: 't-overdue',
              title: 'Overdue',
              kind: DayAgentPendingKind.overdue,
              status: 'OPEN',
              categoryId: null,
              due: DateTime(2026, 5, 25),
            ),
            const DayAgentPendingItem(
              taskId: 't-due',
              title: 'Due',
              kind: DayAgentPendingKind.dueToday,
              status: 'OPEN',
              categoryId: null,
            ),
          ],
        );

        final items = await withClock(Clock.fixed(_asOf), () {
          return bench.adapter.surfacePendingDecisions(forDate: selectedDate);
        });

        expect(items[0].overdueByDays, 5);
        expect(items[0].referenceDate, DateTime(2026, 5, 30));
        expect(items[1].referenceDate, DateTime(2026, 5, 30));
      },
    );

    test(
      'defaults forDate to clock.now and queries with that date',
      () async {
        const agentId = 'agent-default-date';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.surfacePendingDecisions(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => const <DayAgentPendingItem>[]);

        await bench.adapter.surfacePendingDecisions();

        verify(() => bench.dayAgentService.getDayAgentForDate(any())).called(1);
        verify(
          () => bench.captureService.surfacePendingDecisions(
            agentId: agentId,
            dayId: any(named: 'dayId'),
          ),
        ).called(1);
      },
    );
  });

  group(
    'RealDayAgent.applyTriage / linkCapturePhraseToTask / breakCaptureLink',
    () {
      late _TestBench bench;

      setUp(() => bench = _TestBench.create());

      test(
        'applyTriage forwards the action name and only includes deferTo when '
        'deferring',
        () async {
          when(
            () => bench.captureService.applyTriage(
              taskId: any(named: 'taskId'),
              action: any(named: 'action'),
              deferTo: any(named: 'deferTo'),
            ),
          ).thenAnswer((_) async => testTask);

          final immediate = await bench.adapter.applyTriage(
            taskId: 't-1',
            action: TriageAction.today,
          );
          expect(immediate.deferredTo, isNull);
          expect(immediate.action, TriageAction.today);
          verify(
            () => bench.captureService.applyTriage(
              taskId: 't-1',
              action: 'today',
            ),
          ).called(1);

          final deferred = await bench.adapter.applyTriage(
            taskId: 't-2',
            action: TriageAction.defer,
            deferTo: _asOf,
          );
          expect(deferred.deferredTo, _asOf);
          expect(deferred.action, TriageAction.defer);
          verify(
            () => bench.captureService.applyTriage(
              taskId: 't-2',
              action: 'defer',
              deferTo: _asOf,
            ),
          ).called(1);
        },
      );

      test(
        'linkCapturePhraseToTask projects the updated parsed item',
        () async {
          final updated =
              AgentDomainEntity.parsedItem(
                    id: 'parsed-z',
                    agentId: 'agent',
                    captureId: 'cap',
                    kind: ParsedItemKind.matched,
                    title: 'Title',
                    categoryId: 'cat-z',
                    confidence: ParsedItemConfidence.high,
                    confidenceScore: 0.9,
                    matchedTaskId: testTask.meta.id,
                    createdAt: _asOf,
                    vectorClock: null,
                  )
                  as ParsedItemEntity;
          when(
            () => bench.captureService.linkCapturePhraseToTask(
              captureItemId: any(named: 'captureItemId'),
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer((_) async => updated);
          when(
            () => bench.journalDb.getCategoryById('cat-z'),
          ).thenAnswer((_) async => null);
          when(
            () => bench.journalDb.journalEntityById(testTask.meta.id),
          ).thenAnswer((_) async => testTask);

          final item = await bench.adapter.linkCapturePhraseToTask(
            parsedItemId: 'parsed-z',
            taskId: testTask.meta.id,
          );
          expect(item.id, 'parsed-z');
          expect(item.kind, ParsedItemKind.matched);
          expect(item.matchedTaskTitle, testTask.data.title);
        },
      );

      test('breakCaptureLink projects the updated parsed item', () async {
        final updated =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-broken',
                  agentId: 'agent',
                  captureId: 'cap',
                  kind: ParsedItemKind.newTask,
                  title: 'Title',
                  categoryId: '',
                  confidence: ParsedItemConfidence.low,
                  confidenceScore: 0,
                  createdAt: _asOf,
                  vectorClock: null,
                )
                as ParsedItemEntity;
        when(
          () => bench.captureService.breakCaptureLink(any()),
        ).thenAnswer((_) async => updated);

        final item = await bench.adapter.breakCaptureLink('parsed-broken');
        expect(item.kind, ParsedItemKind.newTask);
        expect(item.matchedTaskId, isNull);
      });
    },
  );

  group('RealDayAgent.draftDayPlan poll timeout', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'throws DayAgentInteractionException when no new plan appears before '
      'the deadline',
      () async {
        const agentId = 'agent-timeout';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => bench.dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
            decidedCaptureItemIds: any(named: 'decidedCaptureItemIds'),
          ),
        ).thenAnswer((_) async => true);

        // Fake clock that jumps past the 60-second deadline on the first
        // post-enqueue check so the polling loop bails out without taking
        // real wall-clock time.
        var ticks = 0;
        final clock = Clock(() {
          ticks += 1;
          return ticks == 1 ? _asOf : _asOf.add(const Duration(seconds: 61));
        });

        await expectLater(
          withClock(
            clock,
            () => bench.adapter.draftDayPlan(
              captureId: const CaptureId('cap'),
              decidedTaskIds: const [],
              dayDate: _asOf,
            ),
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });

  group('RealDayAgent.proposePlanDiff', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    DraftPlan buildCurrentPlan() {
      return DraftPlan(
        dayDate: _asOf,
        blocks: [
          TimeBlock(
            id: 'block-existing',
            title: 'Existing',
            start: _asOf.add(const Duration(hours: 1)),
            end: _asOf.add(const Duration(hours: 2)),
            type: TimeBlockType.ai,
            state: TimeBlockState.drafted,
            category: const DayAgentCategory(
              id: 'cat-x',
              name: 'Cat',
              colorHex: 'ABCDEF',
            ),
          ),
        ],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 60,
      );
    }

    test(
      'throws when no day-agent exists for the plan date',
      () async {
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.proposePlanDiff(
            currentPlan: buildCurrentPlan(),
            voiceTranscript: 'move it',
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
        verifyNever(
          () => bench.dayAgentService.enqueueRefineWake(
            dayDate: any(named: 'dayDate'),
            transcript: any(named: 'transcript'),
          ),
        );
      },
    );

    test('throws when enqueueRefineWake reports no agent', () async {
      const agentId = 'agent-prop-1';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.pendingPlanDiffsForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer((_) async => const <ChangeSetEntity>[]);
      when(
        () => bench.dayAgentService.enqueueRefineWake(
          dayDate: any(named: 'dayDate'),
          transcript: any(named: 'transcript'),
        ),
      ).thenAnswer((_) async => false);

      await expectLater(
        bench.adapter.proposePlanDiff(
          currentPlan: buildCurrentPlan(),
          voiceTranscript: 'move it',
        ),
        throwsA(isA<DayAgentInteractionException>()),
      );
    });

    test(
      'returns a projected PlanDiff for the first new change set after enqueue',
      () {
        const agentId = 'agent-prop-2';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);
        // First call (baseline) returns no diffs, subsequent calls return
        // a fresh diff.
        var calls = 0;
        final newDiff = buildChangeSet(
          agentId: agentId,
          items: [
            ChangeItem(
              toolName: 'move_block',
              args: {
                'blockId': 'block-existing',
                'toStart': _asOf
                    .add(const Duration(hours: 3))
                    .toIso8601String(),
                'toEnd': _asOf.add(const Duration(hours: 4)).toIso8601String(),
                'reason': 'Open up morning focus.',
                'title': 'Existing',
              },
              humanSummary: 'Move Existing to 3pm',
            ),
            const ChangeItem(
              toolName: 'add_block',
              args: <String, dynamic>{
                'categoryId': '',
                'reason': 'Add a stretch slot.',
                'title': 'Stretch',
              },
              humanSummary: 'Add Stretch block',
            ),
            const ChangeItem(
              toolName: 'drop_block',
              args: <String, dynamic>{'blockId': 'block-existing'},
              humanSummary: 'Drop existing block',
            ),
            const ChangeItem(
              toolName: 'unknown_tool',
              args: <String, dynamic>{},
              humanSummary: 'Should be skipped',
            ),
          ],
        );
        when(
          () => bench.planService.pendingPlanDiffsForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async {
          calls += 1;
          return calls == 1 ? const <ChangeSetEntity>[] : [newDiff];
        });
        when(
          () => bench.dayAgentService.enqueueRefineWake(
            dayDate: any(named: 'dayDate'),
            transcript: any(named: 'transcript'),
          ),
        ).thenAnswer((_) async => true);

        // Drive the 500 ms refine poll loop with fake time so the test
        // takes microseconds instead of a real poll interval (fake-time
        // policy).
        late PlanDiff diff;
        fakeAsync((async) {
          withClock(async.getClock(_asOf), () {
            bench.adapter
                .proposePlanDiff(
                  currentPlan: buildCurrentPlan(),
                  voiceTranscript: 'reshape the morning',
                )
                .then((d) => diff = d);
          });
          // Flush up to the first poll delay, elapse it, then let the
          // second pendingPlanDiffsForDay read observe the fresh diff.
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 500))
            ..flushMicrotasks();
        });

        expect(diff.id, newDiff.id);
        expect(diff.transcript, 'reshape the morning');
        // unknown_tool was skipped; three valid changes survive.
        expect(diff.changes, hasLength(3));
        final move = diff.changes.firstWhere(
          (c) => c.kind == PlanDiffChangeKind.moved,
        );
        expect(move.toStart, isNotNull);
        expect(move.toEnd, isNotNull);
        expect(move.fromStart, isNotNull);
        final added = diff.changes.firstWhere(
          (c) => c.kind == PlanDiffChangeKind.added,
        );
        // Empty categoryId falls back to the uncategorised category.
        expect(added.category.id, 'unknown');
        final dropped = diff.changes.firstWhere(
          (c) => c.kind == PlanDiffChangeKind.dropped,
        );
        expect(dropped.affectedBlockId, 'block-existing');
      },
    );

    test(
      'throws on timeout when no new diff appears',
      () async {
        const agentId = 'agent-prop-timeout';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.pendingPlanDiffsForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => const <ChangeSetEntity>[]);
        when(
          () => bench.dayAgentService.enqueueRefineWake(
            dayDate: any(named: 'dayDate'),
            transcript: any(named: 'transcript'),
          ),
        ).thenAnswer((_) async => true);

        var ticks = 0;
        final clock = Clock(() {
          ticks += 1;
          return ticks == 1 ? _asOf : _asOf.add(const Duration(seconds: 61));
        });

        await expectLater(
          withClock(
            clock,
            () => bench.adapter.proposePlanDiff(
              currentPlan: buildCurrentPlan(),
              voiceTranscript: 'no change comes',
            ),
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });

  group('RealDayAgent.acceptDiff / revertDiff error branches', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('acceptDiff throws when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);
      await expectLater(
        bench.adapter.acceptDiff(buildDiff()),
        throwsA(isA<DayAgentInteractionException>()),
      );
    });

    test(
      'acceptDiff throws when the plan disappears after the accept',
      () async {
        const agentId = 'agent-accept';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.acceptPlanDiff(
            agentId: any(named: 'agentId'),
            changeSetId: any(named: 'changeSetId'),
            itemIndices: any(named: 'itemIndices'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.changeSet(
                    id: 'diff',
                    agentId: agentId,
                    taskId: 'day_agent_plan:${dayAgentIdForDate(_asOf)}',
                    threadId: 'th',
                    runKey: 'rk',
                    status: ChangeSetStatus.resolved,
                    items: const [],
                    createdAt: _asOf,
                    vectorClock: null,
                  )
                  as ChangeSetEntity,
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.acceptDiff(buildDiff()),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );

    test('revertDiff throws when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);
      await expectLater(
        bench.adapter.revertDiff(
          diff: buildDiff(),
          originalPlan: buildDiff().updatedPlan,
        ),
        throwsA(isA<DayAgentInteractionException>()),
      );
    });

    test(
      'revertDiff throws when the plan disappears after the revert',
      () async {
        const agentId = 'agent-revert';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.revertPlanDiff(
            agentId: any(named: 'agentId'),
            changeSetId: any(named: 'changeSetId'),
            itemIndices: any(named: 'itemIndices'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.changeSet(
                    id: 'diff',
                    agentId: agentId,
                    taskId: 'day_agent_plan:${dayAgentIdForDate(_asOf)}',
                    threadId: 'th',
                    runKey: 'rk',
                    status: ChangeSetStatus.resolved,
                    items: const [],
                    createdAt: _asOf,
                    vectorClock: null,
                  )
                  as ChangeSetEntity,
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.revertDiff(
            diff: buildDiff(),
            originalPlan: buildDiff().updatedPlan,
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );
  });

  group('RealDayAgent projection / agenda / state mapping', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    DayPlanEntity buildPlanEntity({
      required String agentId,
      required DayPlanStatus status,
      List<PlannedBlock> blocks = const [],
      List<DayAgentEnergyBand> bands = const [],
    }) {
      final dayId = dayAgentIdForDate(_asOf);
      return AgentDomainEntity.dayPlan(
            id: 'day_agent_plan:$dayId',
            agentId: agentId,
            dayId: dayId,
            planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
            data: DayPlanData(
              planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
              status: status,
              plannedBlocks: blocks,
            ),
            energyBands: bands,
            createdAt: _asOf,
            updatedAt: _asOf,
            vectorClock: null,
          )
          as DayPlanEntity;
    }

    test(
      'commitDay projects every block type/state + energy band and groups '
      'agenda items per taskId',
      () async {
        const agentId = 'agent-projection';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final blocks = [
          PlannedBlock(
            id: 'b-ai',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 1)),
            endTime: _asOf.add(const Duration(hours: 2)),
            title: 'AI block',
            taskId: 'task-1',
          ),
          PlannedBlock(
            id: 'b-cal',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 2)),
            endTime: _asOf.add(const Duration(hours: 3)),
            title: 'Cal block',
            type: PlannedBlockType.cal,
            state: PlannedBlockState.inProgress,
            taskId: 'task-1',
          ),
          PlannedBlock(
            id: 'b-buffer',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 3)),
            endTime: _asOf.add(const Duration(hours: 3, minutes: 15)),
            title: '',
            type: PlannedBlockType.buffer,
            state: PlannedBlockState.completed,
            taskId: 'task-1',
          ),
          PlannedBlock(
            id: 'b-manual',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 4)),
            endTime: _asOf.add(const Duration(hours: 5)),
            type: PlannedBlockType.manual,
            state: PlannedBlockState.committed,
          ),
          PlannedBlock(
            id: 'b-dropped',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 6)),
            endTime: _asOf.add(const Duration(hours: 7)),
            title: 'Dropped',
            state: PlannedBlockState.dropped,
            taskId: 'task-1',
          ),
        ];

        final entity = buildPlanEntity(
          agentId: agentId,
          status: DayPlanStatus.committed(committedAt: _asOf),
          blocks: blocks,
          bands: [
            DayAgentEnergyBand(
              start: _asOf,
              end: _asOf.add(const Duration(hours: 4)),
              level: DayAgentEnergyLevel.high,
              label: 'HIGH',
            ),
            DayAgentEnergyBand(
              start: _asOf.add(const Duration(hours: 4)),
              end: _asOf.add(const Duration(hours: 6)),
              level: DayAgentEnergyLevel.low,
              label: 'LOW',
            ),
            DayAgentEnergyBand(
              start: _asOf.add(const Duration(hours: 6)),
              end: _asOf.add(const Duration(hours: 9)),
              level: DayAgentEnergyLevel.secondWind,
              label: 'SECOND',
            ),
          ],
        );

        when(
          () => bench.planService.commitDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => entity);

        final plan = DraftPlan(
          dayDate: _asOf,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 0,
        );

        final result = await bench.adapter.commitDay(plan);

        expect(result.state, DayState.committed);
        expect(result.bands.map((b) => b.level), [
          EnergyLevel.high,
          EnergyLevel.low,
          EnergyLevel.secondWind,
        ]);
        expect(result.blocks.map((b) => b.type), [
          TimeBlockType.ai,
          TimeBlockType.cal,
          TimeBlockType.buffer,
          TimeBlockType.manual,
          TimeBlockType.ai,
        ]);
        expect(result.blocks.map((b) => b.state), [
          TimeBlockState.drafted,
          TimeBlockState.inProgress,
          TimeBlockState.completed,
          TimeBlockState.committed,
          TimeBlockState.dropped,
        ]);
        // Untitled fallback applied to the buffer with empty title.
        expect(result.blocks[2].title, 'Untitled');
        // Buffers still reserve day capacity; dropped blocks do not.
        expect(result.scheduledMinutes, 60 + 60 + 15 + 60);

        // Agenda: task-1 groups its non-buffer non-dropped blocks; the
        // standalone manual block becomes its own agenda item. The
        // in-progress block forces the task agenda item to inProgress.
        final taskAgenda = result.agendaItems.firstWhere(
          (a) => a.taskId == 'task-1',
        );
        expect(taskAgenda.linkedBlockIds, ['b-ai', 'b-cal']);
        expect(taskAgenda.state, AgendaItemState.inProgress);
        expect(taskAgenda.totalEstimateMinutes, 60 + 60);

        final manualAgenda = result.agendaItems.firstWhere(
          (a) => a.id == 'agenda_b-manual',
        );
        expect(manualAgenda.taskId, isNull);
        expect(manualAgenda.linkedBlockIds, ['b-manual']);
        // A committed block does not collapse to "done" — only `completed`
        // blocks do. Manual block remains open.
        expect(manualAgenda.state, AgendaItemState.open);
      },
    );

    test('legacy "agreed" status collapses to DayState.committed', () async {
      const agentId = 'agent-agreed';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.commitDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer(
        (_) async => buildPlanEntity(
          agentId: agentId,
          status: DayPlanStatus.agreed(agreedAt: _asOf),
        ),
      );

      final plan = DraftPlan(
        dayDate: _asOf,
        blocks: const [],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 0,
      );
      final result = await bench.adapter.commitDay(plan);
      expect(result.state, DayState.committed);
    });
  });

  group('RealDayAgent helpers + mocked delegations', () {
    late _TestBench bench;

    setUp(
      () => bench = _TestBench.create(
        fallback: MockDayAgent(
          parseLatency: Duration.zero,
          pendingLatency: Duration.zero,
          triageLatency: Duration.zero,
          draftLatency: Duration.zero,
          summarizeLatency: Duration.zero,
          clock: () => _asOf,
        ),
      ),
    );

    test(
      'mocked tools (shutdown / reflection / carryover / tomorrow / corpus) '
      'delegate to the fallback agent',
      () async {
        final forDate = _asOf;

        final shutdown = await bench.adapter.surfaceShutdownData(
          forDate: forDate,
        );
        expect(shutdown.completed, isA<List<CompletedItem>>());

        await bench.adapter.recordReflection(
          forDate: forDate,
          text: 'looked back',
          source: ReflectionSource.typed,
        );
        await bench.adapter.recordCarryoverDecision(
          taskId: 'task-x',
          action: CarryoverAction.tomorrow,
        );

        final note = await bench.adapter.generateTomorrowNote(forDate: forDate);
        expect(note.body, isNotEmpty);

        final corpus = await bench.adapter.surfaceTaskCorpus();
        expect(corpus, isA<List<TaskCorpusItem>>());
      },
    );

    test('DayAgentInteractionException stringifies with its message', () {
      const ex = DayAgentInteractionException('oops');
      expect(ex.toString(), contains('oops'));
      expect(ex.message, 'oops');
    });
  });

  group('RealDayAgent.draftDayPlan cancellation + baseline supersede', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    void stubIdentity(String agentId) {
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
    }

    void stubEnqueueOk() {
      when(
        () => bench.dayAgentService.enqueueDraftingWake(
          dayDate: any(named: 'dayDate'),
          captureId: any(named: 'captureId'),
          decidedTaskIds: any(named: 'decidedTaskIds'),
          decidedCaptureItemIds: any(named: 'decidedCaptureItemIds'),
        ),
      ).thenAnswer((_) async => true);
    }

    test(
      'throws immediately when isCancelled is true on the first poll check '
      'before any delay',
      () {
        const agentId = 'agent-cancel-1';
        stubIdentity(agentId);
        stubEnqueueOk();
        // Baseline read returns null; the loop should never reach a second
        // draftPlanForDay read because cancellation fires first.
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        Object? caught;
        fakeAsync((async) {
          final fakeClock = async.getClock(_asOf);
          withClock(fakeClock, () {
            unawaited(() async {
              try {
                await bench.adapter.draftDayPlan(
                  captureId: const CaptureId('cap'),
                  decidedTaskIds: const [],
                  dayDate: _asOf,
                  isCancelled: () => true,
                );
              } catch (e) {
                caught = e;
              }
            }());
          });
          async.flushMicrotasks();
        });

        expect(caught, isA<DayAgentInteractionException>());
        expect(
          (caught! as DayAgentInteractionException).message,
          contains('cancelled by caller'),
        );
        // Only the baseline read happened — cancellation short-circuited the
        // loop before the post-delay read.
        verify(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayAgentIdForDate(_asOf),
          ),
        ).called(1);
      },
    );

    test(
      'throws on the second poll check after the delay when cancellation '
      'arrives mid-poll',
      () {
        const agentId = 'agent-cancel-2';
        stubIdentity(agentId);
        stubEnqueueOk();
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        var checks = 0;
        Object? caught;
        fakeAsync((async) {
          final fakeClock = async.getClock(_asOf);
          withClock(fakeClock, () {
            unawaited(() async {
              try {
                await bench.adapter.draftDayPlan(
                  captureId: const CaptureId('cap'),
                  decidedTaskIds: const [],
                  dayDate: _asOf,
                  // false on the first (pre-delay) check, true on the second
                  // (post-delay) check.
                  isCancelled: () {
                    checks += 1;
                    return checks >= 2;
                  },
                );
              } catch (e) {
                caught = e;
              }
            }());
          });
          // Drive the 500ms poll delay so the second cancel check runs.
          async
            ..elapse(const Duration(milliseconds: 500))
            ..flushMicrotasks();
        });

        expect(checks, 2);
        expect(caught, isA<DayAgentInteractionException>());
        expect(
          (caught! as DayAgentInteractionException).message,
          contains('cancelled by caller'),
        );
      },
    );

    test(
      'returns the freshly drafted plan once a baseline is superseded by a '
      'newer updatedAt',
      () {
        const agentId = 'agent-baseline';
        final dayId = dayAgentIdForDate(_asOf);
        final baselineAt = _asOf;
        final supersededAt = _asOf.add(const Duration(seconds: 30));
        stubIdentity(agentId);
        stubEnqueueOk();
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        var reads = 0;
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async {
          reads += 1;
          // First read is the (non-null) baseline; later reads return a plan
          // with a strictly newer updatedAt so the supersede branch fires.
          return buildDayPlan(
            agentId: agentId,
            dayId: dayId,
            updatedAt: reads == 1 ? baselineAt : supersededAt,
            blocks: reads == 1
                ? const <PlannedBlock>[]
                : [
                    PlannedBlock(
                      id: 'block_fresh',
                      categoryId: 'work',
                      startTime: _asOf.add(const Duration(hours: 1)),
                      endTime: _asOf.add(const Duration(hours: 2)),
                      title: 'Fresh block',
                    ),
                  ],
          );
        });

        DraftPlan? result;
        fakeAsync((async) {
          final fakeClock = async.getClock(_asOf);
          withClock(fakeClock, () {
            bench.adapter
                .draftDayPlan(
                  captureId: const CaptureId('cap'),
                  decidedTaskIds: const [],
                  dayDate: _asOf,
                )
                .then((plan) => result = plan);
          });
          // One poll interval is enough to read the superseded plan.
          async
            ..elapse(const Duration(milliseconds: 500))
            ..flushMicrotasks();
        });

        expect(result, isNotNull);
        expect(result!.blocks, hasLength(1));
        expect(result!.blocks.single.title, 'Fresh block');
        // Baseline read + at least one post-delay read.
        expect(reads, greaterThanOrEqualTo(2));
      },
    );

    test(
      'a plan whose updatedAt equals the baseline does not supersede and '
      'the poll times out',
      () {
        const agentId = 'agent-equal-ts';
        final dayId = dayAgentIdForDate(_asOf);
        final baselineAt = _asOf;
        stubIdentity(agentId);
        stubEnqueueOk();
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        // Every read (baseline and all polls) returns the same updatedAt —
        // the guard is `isAfter`, so an equal timestamp must never satisfy
        // the supersede branch.
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async => buildDayPlan(
            agentId: agentId,
            dayId: dayId,
            updatedAt: baselineAt,
          ),
        );

        Object? error;
        fakeAsync((async) {
          final fakeClock = async.getClock(_asOf);
          withClock(fakeClock, () {
            bench.adapter
                .draftDayPlan(
                  captureId: const CaptureId('cap'),
                  decidedTaskIds: const [],
                  dayDate: _asOf,
                )
                .catchError((Object e) {
                  error = e;
                  return DraftPlan(
                    dayDate: _asOf,
                    blocks: const [],
                    bands: const [],
                    capacityMinutes: 0,
                    scheduledMinutes: 0,
                  );
                });
          });
          // Run past the 60s draft timeout.
          async
            ..elapse(const Duration(seconds: 61))
            ..flushMicrotasks();
        });

        expect(error, isA<DayAgentInteractionException>());
        expect(
          (error! as DayAgentInteractionException).message,
          contains('Timed out'),
        );
      },
    );
  });

  group('RealDayAgent.proposePlanDiff cancellation', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    DraftPlan buildCurrentPlan() => DraftPlan(
      dayDate: _asOf,
      blocks: const [],
      bands: const [],
      capacityMinutes: 480,
      scheduledMinutes: 0,
    );

    void stubReady(String agentId) {
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.pendingPlanDiffsForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer((_) async => const <ChangeSetEntity>[]);
      when(
        () => bench.dayAgentService.enqueueRefineWake(
          dayDate: any(named: 'dayDate'),
          transcript: any(named: 'transcript'),
        ),
      ).thenAnswer((_) async => true);
    }

    test('throws on the first poll check when isCancelled is true', () {
      const agentId = 'agent-prop-cancel-1';
      stubReady(agentId);

      Object? caught;
      fakeAsync((async) {
        final fakeClock = async.getClock(_asOf);
        withClock(fakeClock, () {
          unawaited(() async {
            try {
              await bench.adapter.proposePlanDiff(
                currentPlan: buildCurrentPlan(),
                voiceTranscript: 'move it',
                isCancelled: () => true,
              );
            } catch (e) {
              caught = e;
            }
          }());
        });
        async.flushMicrotasks();
      });

      expect(caught, isA<DayAgentInteractionException>());
      expect(
        (caught! as DayAgentInteractionException).message,
        contains('cancelled by caller'),
      );
      // Only the baseline diff read happened before cancellation.
      verify(
        () => bench.planService.pendingPlanDiffsForDay(
          agentId: agentId,
          dayId: dayAgentIdForDate(_asOf),
        ),
      ).called(1);
    });

    test('throws on the second poll check after the delay', () {
      const agentId = 'agent-prop-cancel-2';
      stubReady(agentId);

      var checks = 0;
      Object? caught;
      fakeAsync((async) {
        final fakeClock = async.getClock(_asOf);
        withClock(fakeClock, () {
          unawaited(() async {
            try {
              await bench.adapter.proposePlanDiff(
                currentPlan: buildCurrentPlan(),
                voiceTranscript: 'move it',
                isCancelled: () {
                  checks += 1;
                  return checks >= 2;
                },
              );
            } catch (e) {
              caught = e;
            }
          }());
        });
        async
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();
      });

      expect(checks, 2);
      expect(caught, isA<DayAgentInteractionException>());
      expect(
        (caught! as DayAgentInteractionException).message,
        contains('cancelled by caller'),
      );
    });
  });
}
