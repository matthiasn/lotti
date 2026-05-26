import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

final _asOf = DateTime(2026, 5, 25, 9);

void main() {
  group('RealDayAgent.summarizeRecentPatterns', () {
    late MockDayAgentCaptureService captureService;
    late MockDayAgentPlanService planService;
    late MockDayAgentService dayAgentService;
    late MockJournalDb journalDb;
    late RealDayAgent adapter;

    setUp(() {
      captureService = MockDayAgentCaptureService();
      planService = MockDayAgentPlanService();
      dayAgentService = MockDayAgentService();
      journalDb = MockJournalDb();
      adapter = RealDayAgent(
        captureService: captureService,
        planService: planService,
        dayAgentService: dayAgentService,
        journalDb: journalDb,
        mockFallback: MockDayAgent(),
      );
    });

    test(
      'returns an empty list when no day-agent exists for the date',
      () async {
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => null,
        );

        final cards = await adapter.summarizeRecentPatterns(asOf: _asOf);

        expect(cards, isEmpty);
        verifyNever(
          () => planService.summarizeRecentPatterns(
            agentId: any(named: 'agentId'),
            asOf: any(named: 'asOf'),
            lookbackDays: any(named: 'lookbackDays'),
          ),
        );
      },
    );

    test('projects backend cards onto UI LearningCard shape', () async {
      const agentId = 'day-agent-001';
      when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => planService.summarizeRecentPatterns(
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

      final cards = await adapter.summarizeRecentPatterns(asOf: _asOf);

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
      when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => planService.summarizeRecentPatterns(
          agentId: any(named: 'agentId'),
          asOf: any(named: 'asOf'),
          lookbackDays: any(named: 'lookbackDays'),
        ),
      ).thenAnswer((_) async => const <DayAgentLearningCard>[]);

      await adapter.summarizeRecentPatterns(asOf: _asOf, lookbackDays: 14);

      verify(
        () => planService.summarizeRecentPatterns(
          agentId: agentId,
          asOf: _asOf,
          lookbackDays: 14,
        ),
      ).called(1);
    });
  });

  group('RealDayAgent.draftDayPlan', () {
    late MockDayAgentCaptureService captureService;
    late MockDayAgentPlanService planService;
    late MockDayAgentService dayAgentService;
    late MockJournalDb journalDb;
    late RealDayAgent adapter;

    setUp(() {
      captureService = MockDayAgentCaptureService();
      planService = MockDayAgentPlanService();
      dayAgentService = MockDayAgentService();
      journalDb = MockJournalDb();
      adapter = RealDayAgent(
        captureService: captureService,
        planService: planService,
        dayAgentService: dayAgentService,
        journalDb: journalDb,
        mockFallback: MockDayAgent(),
      );
    });

    DayPlanEntity buildDayPlan({
      required String agentId,
      required String dayId,
      required DateTime updatedAt,
      List<PlannedBlock> blocks = const <PlannedBlock>[],
      int capacityMinutes = 480,
      int scheduledMinutes = 240,
    }) {
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
            createdAt: updatedAt,
            updatedAt: updatedAt,
            vectorClock: null,
          )
          as DayPlanEntity;
    }

    test(
      'enqueues the drafting wake, awaits the persisted plan, '
      'and projects it onto DraftPlan',
      () async {
        const agentId = 'day-agent-001';
        final dayId = dayAgentIdForDate(_asOf);
        final freshlyDraftedAt = _asOf.add(const Duration(seconds: 5));
        var draftPlanCalls = 0;

        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => planService.draftPlanForDay(
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
          () => dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final result = await withClock(Clock.fixed(_asOf), () async {
          return adapter.draftDayPlan(
            captureId: const CaptureId('cap_1'),
            decidedTaskIds: const ['t_1'],
            dayDate: _asOf,
          );
        });

        expect(result.blocks, hasLength(1));
        expect(result.blocks.single.title, 'Demo prep');
        expect(result.blocks.single.type, TimeBlockType.ai);
        expect(result.blocks.single.reason, 'High-energy window');
        expect(result.capacityMinutes, 480);
        expect(result.scheduledMinutes, 240);
        expect(result.state, DayState.drafted);

        // Standalone block (no taskId) still becomes one agenda item so
        // the Agenda surface mirrors the Day timeline.
        expect(result.agendaItems, hasLength(1));
        expect(result.agendaItems.single.title, 'Demo prep');
        expect(result.agendaItems.single.linkedBlockIds, ['block_1']);
        expect(result.agendaItems.single.taskId, isNull);

        verify(
          () => dayAgentService.enqueueDraftingWake(
            dayDate: _asOf,
            captureId: 'cap_1',
            decidedTaskIds: ['t_1'],
          ),
        ).called(1);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'falls back to the mock plan when no day-agent exists for the date',
      () async {
        when(
          () => dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        final result = await adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );

        // Mock returns a non-empty scripted plan.
        expect(result.blocks, isNotEmpty);
        verifyNever(
          () => dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
          ),
        );
      },
    );

    test(
      'falls back to the mock plan when enqueueDraftingWake reports no agent',
      () async {
        const agentId = 'day-agent-001';
        when(() => dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => dayAgentService.enqueueDraftingWake(
            dayDate: any(named: 'dayDate'),
            captureId: any(named: 'captureId'),
            decidedTaskIds: any(named: 'decidedTaskIds'),
          ),
        ).thenAnswer((_) async => false);

        final result = await adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );

        expect(result.blocks, isNotEmpty);
      },
    );
  });
}
