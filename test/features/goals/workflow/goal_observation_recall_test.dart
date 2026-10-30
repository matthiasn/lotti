import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/goals/workflow/goal_observation_recall.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final start = DateTime(2026, 3, 14);

  /// [count] observations, newest first, the way
  /// `recallAgentObservations` returns them; indexes in [critical] are filed
  /// critical.
  List<RecalledObservation> recalled(
    int count, {
    Set<int> critical = const {},
    String Function(int index)? text,
  }) => [
    for (var i = 0; i < count; i++)
      (
        id: 'obs-$i',
        at: start.subtract(Duration(days: i)),
        text: text?.call(i) ?? 'Note $i.',
        priority: critical.contains(i)
            ? ObservationPriority.critical
            : ObservationPriority.routine,
        category: ObservationCategory.operational,
      ),
  ];

  group('goalObservationSelection', () {
    test('keeps the newest lookback in order, flagging the critical ones', () {
      final selected = goalObservationSelection(
        recalled(5, critical: {1}),
        lookback: 3,
      );

      expect(selected.map((o) => o.text), ['Note 0.', 'Note 1.', 'Note 2.']);
      expect(selected.map((o) => o.critical), [false, true, false]);
      expect(selected.first.recordedAt, start);
    });

    test('an old critical note outlives a dozen routine ones written since '
        'it; old routine notes do not', () {
      final selected = goalObservationSelection(
        recalled(30, critical: {20, 25}),
      );

      expect(selected, hasLength(goalObservationLookback + 2));
      expect(
        selected.skip(goalObservationLookback).map((o) => o.text),
        ['Note 20.', 'Note 25.'],
      );
      expect(
        selected.skip(goalObservationLookback).every((o) => o.critical),
        isTrue,
      );
    });

    test('older critical notes stop at the token budget, newest first', () {
      // Twenty words each, about 26 tokens: a budget of 60 holds two.
      final selected = goalObservationSelection(
        recalled(
          8,
          critical: {3, 4, 5, 6},
          text: (i) => 'Critical constraint $i:${' word' * 17}',
        ),
        lookback: 3,
        criticalBudget: 60,
      );

      expect(
        selected.skip(3).map((o) => o.text.split(':').first),
        ['Critical constraint 3', 'Critical constraint 4'],
      );
    });

    test('nothing recalled, nothing selected', () {
      expect(goalObservationSelection(const []), isEmpty);
    });
  });

  test('goalObservationFacts reads the critical window, not only the '
      'lookback', () async {
    final repository = MockAgentRepository();
    when(
      () => repository.getMessagesByKind(
        'agent-1',
        AgentMessageKind.observation,
        limit: goalCriticalObservationWindow,
      ),
    ).thenAnswer((_) async => const []);

    expect(await goalObservationFacts(repository, 'agent-1'), isEmpty);
    verify(
      () => repository.getMessagesByKind(
        'agent-1',
        AgentMessageKind.observation,
        limit: goalCriticalObservationWindow,
      ),
    ).called(1);
  });
}
