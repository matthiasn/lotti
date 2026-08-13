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

  test('typed day dismissal does not masquerade as a legacy snooze', () {
    final nudge = makeGoalNudge(
      dismissedForDayAt: DateTime.utc(2026, 8, 11, 10),
      provenance: const {
        goalBannerSnoozedUntilKey: '2026-08-12T00:00:00.000Z',
      },
    );

    expect(goalBannerSnoozedUntil(nudge), isNull);
    expect(
      goalBannerIsSnoozed(nudge, DateTime.utc(2026, 8, 11, 11)),
      isFalse,
    );
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
    'snoozing appends timing evidence and dual-writes legacy visibility',
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
      expect(
        snoozed.snoozeHistory.single.returnUtcOffsetMinutes,
        until.timeZoneOffset.inMinutes,
      );
      expect(snoozed.staleAt, DateTime.utc(2026, 8, 14, 13));
      expect(snoozed.provenance, {
        'specVersionId': 'spec-1',
        goalBannerSnoozedUntilKey: until.toIso8601String(),
      });
    },
  );

  test('reapplying the same snooze event is idempotent', () {
    final now = DateTime.utc(2026, 8, 11, 10);
    final until = DateTime.utc(2026, 8, 11, 13);
    final first = snoozeGoalBannerEntity(
      nudge: makeGoalNudge(),
      now: now,
      until: until,
      eventId: 'snooze-1',
    );

    final repeated = snoozeGoalBannerEntity(
      nudge: first,
      now: now,
      until: until,
      eventId: 'snooze-1',
    );

    expect(repeated.snoozeHistory, first.snoozeHistory);
    expect(repeated.snoozeHistory, hasLength(1));
  });

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

  test('day dismissal appends evidence, dual-writes its deadline, and '
      'preserves visible lifetime', () {
    final now = DateTime(2026, 8, 13, 23, 30);
    final hiddenUntil = goalBannerNextLocalMidnight(now);
    final dismissed = dismissGoalBannerForDayEntity(
      nudge: makeGoalNudge(
        snoozedUntil: now.add(const Duration(hours: 1)),
        staleAt: now.add(const Duration(minutes: 10)),
        provenance: const {
          'snoozeReason': 'legacy',
          'specVersionId': 'spec-1',
        },
      ),
      now: now,
      eventId: 'dismiss-1',
    );

    expect(dismissed.snoozedUntil, isNull);
    expect(dismissed.dismissedForDayAt, now.toUtc());
    expect(dismissed.staleAt, hiddenUntil.toUtc().add(goalBannerLifetime));
    expect(dismissed.provenance, {
      'specVersionId': 'spec-1',
      goalBannerSnoozedUntilKey: hiddenUntil.toUtc().toIso8601String(),
    });
    final event = dismissed.dismissalHistory.single;
    expect(event.id, 'dismiss-1');
    expect(event.activation, 1);
    expect(event.dismissedAt, now.toUtc());
    expect(event.dismissedUntil, hiddenUntil.toUtc());
    expect(event.utcOffsetMinutes, now.timeZoneOffset.inMinutes);
  });
}
