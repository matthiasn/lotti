import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/logic/goal_banner_snooze.dart';

GoalNudgeEntity makeGoalNudge({Map<String, String> provenance = const {}}) =>
    AgentDomainEntity.goalNudge(
          id: 'ad-1',
          agentId: 'goal-1',
          status: GoalNudgeStatus.active,
          brief: const GoalNudgeBrief(
            headline: 'Move.',
            tone: GoalNudgeTone.nudge,
            animation: GoalBannerAnimation.steady,
          ),
          briefDigest: 'digest',
          createdAt: DateTime.utc(2026, 8, 11),
          updatedAt: DateTime.utc(2026, 8, 11),
          vectorClock: null,
          provenance: provenance,
        )
        as GoalNudgeEntity;

void main() {
  test(
    'parses a durable UTC deadline and reports only the active interval',
    () {
      final nudge = makeGoalNudge(
        provenance: const {
          goalBannerSnoozedUntilKey: '2026-08-11T15:00:00.000Z',
        },
      );

      expect(
        goalBannerSnoozedUntil(nudge),
        DateTime.utc(2026, 8, 11, 15),
      );
      expect(
        goalBannerIsSnoozed(nudge, DateTime.utc(2026, 8, 11, 14, 59)),
        isTrue,
      );
      expect(
        goalBannerIsSnoozed(nudge, DateTime.utc(2026, 8, 11, 15)),
        isFalse,
      );
    },
  );

  test('malformed and absent deadlines are not treated as snoozed', () {
    expect(
      goalBannerIsSnoozed(
        makeGoalNudge(
          provenance: const {goalBannerSnoozedUntilKey: 'later-ish'},
        ),
        DateTime.utc(2026, 8, 11),
      ),
      isFalse,
    );
    expect(
      goalBannerSnoozedUntil(makeGoalNudge()),
      isNull,
    );
  });
}
