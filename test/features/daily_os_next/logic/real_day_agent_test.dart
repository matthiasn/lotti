import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
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
}
