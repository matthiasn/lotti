import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_dictation_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  test("is the dictation of the goal's own journal entry", () {
    final goals = MockGoalRepository();
    when(() => goals.goalIdForAgent('agent-1')).thenReturn('goal-entry-1');
    final container = ProviderContainer(
      overrides: [goalRepositoryProvider.overrideWithValue(goals)],
    );
    addTearDown(container.dispose);

    // The goal's category is read off its journal entry, not the agent.
    expect(
      container.read(goalDictationProvider('agent-1')),
      same(container.read(subjectDictationProvider('goal-entry-1'))),
    );
  });

  test('is nothing without a goal repository to name the goal', () {
    final container = ProviderContainer(
      overrides: [goalRepositoryProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    expect(container.read(goalDictationProvider('agent-1')), isNull);
  });
}
