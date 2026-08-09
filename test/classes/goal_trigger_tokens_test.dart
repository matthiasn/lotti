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

  test('the baseline token round-trips the pre-transition status', () {
    expect(goalEscalationBaselineToken('offTrack'), 'goal-baseline:offTrack');
    expect(
      goalEscalationBaselineFromTriggerTokens({
        'goal-escalation:2026-08-09',
        'goal-baseline:offTrack',
      }),
      'offTrack',
    );
    expect(
      goalEscalationBaselineFromTriggerTokens({'goal-escalation:2026-08-09'}),
      isNull,
    );
  });
}
