import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/goals/workflow/goal_observation_recall.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

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

  group('goalObservationMemory', () {
    late MockAgentRepository repository;

    /// [count] stored observations, newest first; [critical] indexes filed
    /// critical.
    void stub(int count, {required int limit, Set<int> critical = const {}}) {
      final messages = [
        for (var i = 0; i < count; i++)
          makeTestMessage(
            id: 'obs-$i',
            agentId: 'agent-1',
            kind: AgentMessageKind.observation,
            createdAt: start.subtract(Duration(days: i)),
            contentEntryId: 'payload-$i',
          ),
      ];
      when(
        () => repository.getMessagesByKind(
          'agent-1',
          AgentMessageKind.observation,
          limit: limit,
        ),
      ).thenAnswer((_) async => messages);
      when(() => repository.getEntitiesByIds(any())).thenAnswer(
        (_) async => {
          for (var i = 0; i < count; i++)
            'payload-$i': makeTestMessagePayload(
              id: 'payload-$i',
              content: {
                'text': 'Note $i.',
                if (critical.contains(i)) 'priority': 'critical',
              },
            ),
        },
      );
    }

    setUp(() => repository = MockAgentRepository());

    test('without a digester it reads only the critical window', () async {
      stub(3, limit: goalCriticalObservationWindow);

      final memory = await goalObservationMemory(repository, 'agent-1');

      expect(memory.recent.map((o) => o.text), [
        'Note 0.',
        'Note 1.',
        'Note 2.',
      ]);
      expect(memory.digests, isEmpty);
    });

    test('a digester gets the wider window and what is shown verbatim, and '
        'its digests are the memory of the rest', () async {
      stub(20, limit: goalObservationMemoryWindow, critical: {16});
      List<RecalledObservation>? window;
      Set<String>? verbatim;
      const digest = (month: '2026-02', notes: 7, text: 'February, kept.');

      final memory = await goalObservationMemory(
        repository,
        'agent-1',
        digester: (recalled, shownVerbatim) async {
          window = recalled;
          verbatim = shownVerbatim;
          return [digest];
        },
      );

      expect(window, hasLength(20));
      // The newest dozen and the older critical note.
      expect(verbatim, {
        for (var i = 0; i < goalObservationLookback; i++) 'obs-$i',
        'obs-16',
      });
      expect(memory.recent, hasLength(goalObservationLookback + 1));
      expect(memory.recent.last.critical, isTrue);
      expect(memory.digests, [digest]);
    });
  });
}
