import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';

void main() {
  test('escalation workspace keys round-trip through the trigger-token '
      'parser', () {
    final key = goalEscalationWorkspaceKey('2026-08-09');
    expect(key, 'goal-escalation:2026-08-09');
    expect(isGoalEscalationWorkspace(key), isTrue);
    expect(
      goalEscalationPeriodFromTriggerTokens({'cumulative_step_count', key}),
      '2026-08-09',
    );
  });

  test('non-escalation wakes yield null — they must stay on the €0 tier', () {
    expect(
      goalEscalationPeriodFromTriggerTokens({
        goalCadenceWorkspaceKey,
        'gym-habit',
      }),
      isNull,
    );
    expect(goalEscalationPeriodFromTriggerTokens(const {}), isNull);
    expect(isGoalEscalationWorkspace(null), isFalse);
    expect(isGoalEscalationWorkspace(goalCadenceWorkspaceKey), isFalse);
  });
}
