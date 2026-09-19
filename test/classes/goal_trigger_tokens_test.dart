import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  test('report refresh is an explicit opt-in trigger', () {
    expect(
      goalReportRefreshRequested(const {goalReportRefreshTriggerToken}),
      isTrue,
    );
    expect(goalReportRefreshRequested(const {'gym-habit'}), isFalse);
  });

  test('deferred report refresh has its own Phase A arm token', () {
    expect(
      goalDeferredReportRefreshRequested(
        const {goalDeferredReportRefreshTriggerToken},
      ),
      isTrue,
    );
    expect(
      goalDeferredReportRefreshRequested(
        const {goalReportRefreshTriggerToken},
      ),
      isFalse,
    );
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

  group('token properties', () {
    glados.Glados3(
      glados.any.stringOf('0123456789-W:ab'),
      glados.any.nonEmptyLetters,
      glados.any.list(glados.any.lowercaseLetters),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'the escalation period and baseline read back out of any wake',
      (period, status, noise) {
        final key = goalEscalationWorkspaceKey(period);
        final tokens = {
          key,
          goalEscalationBaselineToken(status),
          goalCadenceWorkspaceKey,
          // Day-planner vocabulary may share a merged wake.
          'planning_day:dayplan-2026-08-08',
          'capture_submitted:$period',
          ...noise,
        };

        expect(isGoalEscalationWorkspace(key), isTrue);
        expect(
          isGoalEscalationWorkspace(goalEscalationBaselineToken(status)),
          isFalse,
        );
        expect(goalEscalationPeriodFromTriggerTokens(tokens), period);
        expect(goalEscalationBaselineFromTriggerTokens(tokens), status);
        expect(goalReportRefreshRequested(tokens), isFalse);
        expect(goalDeferredReportRefreshRequested(tokens), isFalse);
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.list(glados.any.lowercaseLetters),
      glados.IntAnys(glados.any).intInRange(0, 4),
    ).test(
      'the two refresh requests never stand in for each other',
      (noise, which) {
        final tokens = {
          ...noise,
          if (which & 1 != 0) goalReportRefreshTriggerToken,
          if (which & 2 != 0) goalDeferredReportRefreshTriggerToken,
        };

        expect(goalReportRefreshRequested(tokens), which & 1 != 0);
        expect(goalDeferredReportRefreshRequested(tokens), which & 2 != 0);
        expect(goalEscalationPeriodFromTriggerTokens(tokens), isNull);
        expect(goalEscalationBaselineFromTriggerTokens(tokens), isNull);
      },
      tags: 'glados',
    );
  });
}
