import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';

void main() {
  final now = DateTime(2026, 8, 12, 21, 12);
  final pages = MeasurableDataType(
    id: 'pages',
    createdAt: now,
    updatedAt: now,
    displayName: 'Pages read',
    description: '',
    unitName: 'pages',
    version: 1,
    vectorClock: null,
  );
  const linked = GoalCriterion.measurable(
    criterionId: 'reading',
    dataTypeId: 'pages',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.sum,
    target: 60,
  );

  test('offers one exact entry for an explicit linked quantity', () {
    final offer = parseGoalMeasurableRecordOffer(
      message: AgentChatMessage(
        id: 'message-1',
        role: AgentChatRole.user,
        text: 'I read 20 pages today.',
        createdAt: now,
      ),
      criteria: linked,
      measurables: [pages],
      reference: now,
      recentDayLabels: const {},
    );

    expect(offer, isNotNull);
    expect(offer!.sourceMessageId, 'message-1');
    expect(offer.dataTypeId, 'pages');
    expect(offer.items, hasLength(1));
    expect(offer.items.single.value, 20);
    expect(offer.items.single.day, DateTime.utc(2026, 8, 12));
    expect(offer.items.single.estimated, isFalse);
  });

  test('splits an ambiguous total across explicitly named days', () {
    final offer = parseGoalMeasurableRecordOffer(
      message: AgentChatMessage(
        id: 'message-2',
        role: AgentChatRole.user,
        text: 'I read 40 pages Tuesday and Wednesday total.',
        createdAt: now,
      ),
      criteria: linked,
      measurables: [pages],
      reference: now,
      recentDayLabels: {
        DateTime(2026, 8, 11): const ['Tue', 'Tuesday'],
        DateTime(2026, 8, 12): const ['Wed', 'Wednesday'],
      },
    );

    expect(offer, isNotNull);
    expect(offer!.items.map((item) => item.value), [20, 20]);
    expect(offer.items.every((item) => item.estimated), isTrue);
    expect(offer.items.map((item) => item.day), [
      DateTime.utc(2026, 8, 11),
      DateTime.utc(2026, 8, 12),
    ]);
  });

  test('does not infer from silence or an unlinked measurable', () {
    final message = AgentChatMessage(
      id: 'message-3',
      role: AgentChatRole.user,
      text: 'Reading went well.',
      createdAt: now,
    );
    expect(
      parseGoalMeasurableRecordOffer(
        message: message,
        criteria: linked,
        measurables: [pages],
        reference: now,
        recentDayLabels: const {},
      ),
      isNull,
    );
    expect(
      parseGoalMeasurableRecordOffer(
        message: AgentChatMessage(
          id: 'message-4',
          role: AgentChatRole.user,
          text: 'I read 20 pages.',
          createdAt: now,
        ),
        criteria: const GoalCriterion.habit(
          criterionId: 'walk',
          habitId: 'walk',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 4,
        ),
        measurables: [pages],
        reference: now,
        recentDayLabels: const {},
      ),
      isNull,
    );
  });

  test('declines two quantities for the same measurable', () {
    final offer = parseGoalMeasurableRecordOffer(
      message: AgentChatMessage(
        id: 'message-5',
        role: AgentChatRole.user,
        text: 'I read 10 pages Tuesday and 20 pages Wednesday.',
        createdAt: now,
      ),
      criteria: linked,
      measurables: [pages],
      reference: now,
      recentDayLabels: const {},
    );

    expect(offer, isNull);
  });

  test('declines an ambiguous unit shared by linked measurables', () {
    final journalPages = pages.copyWith(
      id: 'journal-pages',
      displayName: 'Journal pages',
    );
    const criteria = GoalCriterion.allOf(
      criterionId: 'reading-and-writing',
      criteria: [
        linked,
        GoalCriterion.measurable(
          criterionId: 'writing',
          dataTypeId: 'journal-pages',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          target: 30,
        ),
      ],
    );
    final offer = parseGoalMeasurableRecordOffer(
      message: AgentChatMessage(
        id: 'message-6',
        role: AgentChatRole.user,
        text: 'I did 20 pages today.',
        createdAt: now,
      ),
      criteria: criteria,
      measurables: [pages, journalPages],
      reference: now,
      recentDayLabels: const {},
    );

    expect(offer, isNull);
  });

  test('does not treat a unit prefix as the configured unit', () {
    final offer = parseGoalMeasurableRecordOffer(
      message: AgentChatMessage(
        id: 'message-7',
        role: AgentChatRole.user,
        text: 'I read 20 pagesworth today.',
        createdAt: now,
      ),
      criteria: linked,
      measurables: [pages],
      reference: now,
      recentDayLabels: const {},
    );

    expect(offer, isNull);
  });
}
