import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/logic/goal_banner_snooze.dart';

GoalNudgeEntity makeGoalNudge({
  Map<String, String> provenance = const {},
  DateTime? snoozedUntil,
  DateTime? dismissedForDayAt,
  DateTime? staleAt,
}) =>
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
          snoozedUntil: snoozedUntil,
          dismissedForDayAt: dismissedForDayAt,
          staleAt: staleAt,
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

  test('typed snooze state takes precedence over legacy provenance', () {
    final typed = DateTime.utc(2026, 8, 11, 18);
    final nudge = makeGoalNudge(
      snoozedUntil: typed,
      provenance: const {
        goalBannerSnoozedUntilKey: '2026-08-11T15:00:00.000Z',
      },
    );

    expect(goalBannerSnoozedUntil(nudge), typed);
  });

  test('day dismissal is active only on the same local calendar day', () {
    final dismissedAt = DateTime(2026, 8, 11, 22).toUtc();
    final nudge = makeGoalNudge(dismissedForDayAt: dismissedAt);

    expect(
      goalBannerIsDismissedForDay(nudge, DateTime(2026, 8, 11, 23, 59)),
      isTrue,
    );
    expect(
      goalBannerIsDismissedForDay(nudge, DateTime(2026, 8, 12)),
      isFalse,
    );
    expect(
      goalBannerNextLocalMidnight(DateTime(2026, 3, 29, 20)),
      DateTime(2026, 3, 30),
    );
  });

  test(
    'snoozing appends timing evidence and removes legacy quiet metadata',
    () {
      final now = DateTime.utc(2026, 8, 11, 10);
      final until = DateTime.utc(2026, 8, 11, 13);
      final snoozed = snoozeGoalBannerEntity(
        nudge: makeGoalNudge(
          staleAt: DateTime.utc(2026, 8, 12),
          provenance: const {
            goalBannerSnoozedUntilKey: '2026-08-11T11:00:00.000Z',
            'snoozeReason': 'legacy',
            'snoozedAt': '2026-08-11T09:00:00.000Z',
            'specVersionId': 'spec-1',
          },
        ),
        now: now,
        until: until,
        eventId: 'snooze-1',
      );

      expect(snoozed.snoozedUntil, until);
      expect(snoozed.lastSnoozeDuration, GoalBannerSnoozeDuration.threeHours);
      expect(snoozed.snoozeHistory.single.durationMinutes, 180);
      expect(snoozed.staleAt, DateTime.utc(2026, 8, 14, 13));
      expect(snoozed.provenance, {'specVersionId': 'spec-1'});
    },
  );

  test('a zero or negative snooze interval is rejected', () {
    final now = DateTime.utc(2026, 8, 11, 10);
    for (final until in [now, now.subtract(const Duration(minutes: 1))]) {
      expect(
        () => snoozeGoalBannerEntity(
          nudge: makeGoalNudge(),
          now: now,
          until: until,
          eventId: 'invalid',
        ),
        throwsArgumentError,
      );
    }
  });
}
