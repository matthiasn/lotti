import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';

NudgeEntityView makeNudgeView({
  Map<String, String> provenance = const {},
  DateTime? snoozedUntil,
  DateTime? dismissedForDayAt,
  DateTime? staleAt,
  bool relationship = false,
}) => NudgeEntityView.of(
  relationship
      ? AgentDomainEntity.relationshipNudge(
          id: 'ad-1',
          agentId: 'relationship-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Check in.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
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
      : AgentDomainEntity.goalNudge(
          id: 'ad-1',
          agentId: 'goal-1',
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Move.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'digest',
          createdAt: DateTime.utc(2026, 8, 11),
          updatedAt: DateTime.utc(2026, 8, 11),
          vectorClock: null,
          provenance: provenance,
          snoozedUntil: snoozedUntil,
          dismissedForDayAt: dismissedForDayAt,
          staleAt: staleAt,
        ),
)!;

void main() {
  test(
    'parses a durable UTC deadline and reports only the active interval',
    () {
      final nudge = makeNudgeView(
        provenance: const {
          nudgeBannerSnoozedUntilKey: '2026-08-11T15:00:00.000Z',
        },
      );

      expect(
        nudgeBannerSnoozedUntil(nudge),
        DateTime.utc(2026, 8, 11, 15),
      );
      expect(
        nudgeBannerIsSnoozed(nudge, DateTime.utc(2026, 8, 11, 14, 59)),
        isTrue,
      );
      expect(
        nudgeBannerIsSnoozed(nudge, DateTime.utc(2026, 8, 11, 15)),
        isFalse,
      );
    },
  );

  test('malformed and absent deadlines are not treated as snoozed', () {
    expect(
      nudgeBannerIsSnoozed(
        makeNudgeView(
          provenance: const {nudgeBannerSnoozedUntilKey: 'later-ish'},
        ),
        DateTime.utc(2026, 8, 11),
      ),
      isFalse,
    );
    expect(
      nudgeBannerSnoozedUntil(makeNudgeView()),
      isNull,
    );
  });

  test('typed snooze state takes precedence over legacy provenance', () {
    final typed = DateTime.utc(2026, 8, 11, 18);
    final nudge = makeNudgeView(
      snoozedUntil: typed,
      provenance: const {
        nudgeBannerSnoozedUntilKey: '2026-08-11T15:00:00.000Z',
      },
    );

    expect(nudgeBannerSnoozedUntil(nudge), typed);
  });

  test('typed day dismissal does not masquerade as a legacy snooze', () {
    final nudge = makeNudgeView(
      dismissedForDayAt: DateTime.utc(2026, 8, 11, 10),
      provenance: const {
        nudgeBannerSnoozedUntilKey: '2026-08-12T00:00:00.000Z',
      },
    );

    expect(nudgeBannerSnoozedUntil(nudge), isNull);
    expect(
      nudgeBannerIsSnoozed(nudge, DateTime.utc(2026, 8, 11, 11)),
      isFalse,
    );
  });

  test('day dismissal is active only on the same local calendar day', () {
    final dismissedAt = DateTime(2026, 8, 11, 22).toUtc();
    final nudge = makeNudgeView(dismissedForDayAt: dismissedAt);

    expect(
      nudgeBannerIsDismissedForDay(nudge, DateTime(2026, 8, 11, 23, 59)),
      isTrue,
    );
    expect(
      nudgeBannerIsDismissedForDay(nudge, DateTime(2026, 8, 12)),
      isFalse,
    );
    expect(
      nudgeBannerNextLocalMidnight(DateTime(2026, 3, 29, 20)),
      DateTime(2026, 3, 30),
    );
  });

  test(
    'snoozing appends timing evidence and dual-writes legacy visibility',
    () {
      final now = DateTime.utc(2026, 8, 11, 10);
      final until = DateTime.utc(2026, 8, 11, 13);
      final snoozed = NudgeEntityView.of(
        snoozeNudgeBannerEntity(
          nudge: makeNudgeView(
            staleAt: DateTime.utc(2026, 8, 12),
            provenance: const {
              nudgeBannerSnoozedUntilKey: '2026-08-11T11:00:00.000Z',
              'snoozeReason': 'legacy',
              'snoozedAt': '2026-08-11T09:00:00.000Z',
              'specVersionId': 'spec-1',
            },
          ),
          now: now,
          until: until,
          eventId: 'snooze-1',
        ),
      )!;

      expect(snoozed.snoozedUntil, until);
      expect(snoozed.lastSnoozeDuration, NudgeBannerSnoozeDuration.threeHours);
      expect(snoozed.snoozeHistory.single.durationMinutes, 180);
      expect(
        snoozed.snoozeHistory.single.returnUtcOffsetMinutes,
        until.timeZoneOffset.inMinutes,
      );
      expect(snoozed.staleAt, DateTime.utc(2026, 8, 14, 13));
      expect(snoozed.provenance, {
        'specVersionId': 'spec-1',
        nudgeBannerSnoozedUntilKey: until.toIso8601String(),
      });
    },
  );

  test('reapplying the same snooze event is idempotent', () {
    final now = DateTime.utc(2026, 8, 11, 10);
    final until = DateTime.utc(2026, 8, 11, 13);
    final first = NudgeEntityView.of(
      snoozeNudgeBannerEntity(
        nudge: makeNudgeView(),
        now: now,
        until: until,
        eventId: 'snooze-1',
      ),
    )!;

    final repeated = NudgeEntityView.of(
      snoozeNudgeBannerEntity(
        nudge: first,
        now: now,
        until: until,
        eventId: 'snooze-1',
      ),
    )!;

    expect(repeated.snoozeHistory, first.snoozeHistory);
    expect(repeated.snoozeHistory, hasLength(1));
  });

  test('a zero or negative snooze interval is rejected', () {
    final now = DateTime.utc(2026, 8, 11, 10);
    for (final until in [now, now.subtract(const Duration(minutes: 1))]) {
      expect(
        () => snoozeNudgeBannerEntity(
          nudge: makeNudgeView(),
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
    final hiddenUntil = nudgeBannerNextLocalMidnight(now);
    final dismissed = NudgeEntityView.of(
      dismissNudgeBannerForDayEntity(
        nudge: makeNudgeView(
          snoozedUntil: now.add(const Duration(hours: 1)),
          staleAt: now.add(const Duration(minutes: 10)),
          provenance: const {
            'snoozeReason': 'legacy',
            'specVersionId': 'spec-1',
          },
        ),
        now: now,
        eventId: 'dismiss-1',
      ),
    )!;

    expect(dismissed.snoozedUntil, isNull);
    expect(dismissed.dismissedForDayAt, now.toUtc());
    expect(dismissed.staleAt, hiddenUntil.toUtc().add(nudgeBannerLifetime));
    expect(dismissed.provenance, {
      'specVersionId': 'spec-1',
      nudgeBannerSnoozedUntilKey: hiddenUntil.toUtc().toIso8601String(),
    });
    final event = dismissed.dismissalHistory.single;
    expect(event.id, 'dismiss-1');
    expect(event.activation, 1);
    expect(event.dismissedAt, now.toUtc());
    expect(event.dismissedUntil, hiddenUntil.toUtc());
    expect(event.utcOffsetMinutes, now.timeZoneOffset.inMinutes);
  });

  test('a dismissal never pulls an already-later staleAt backwards', () {
    final now = DateTime(2026, 8, 13, 23, 30);
    final farStale = DateTime.utc(2026, 9, 30);
    final dismissed = NudgeEntityView.of(
      dismissNudgeBannerForDayEntity(
        nudge: makeNudgeView(staleAt: farStale),
        now: now,
        eventId: 'dismiss-keep',
      ),
    )!;
    expect(dismissed.staleAt, farStale);
  });

  test('the write helpers preserve the relationship variant (ADR 0059)', () {
    final now = DateTime.utc(2026, 8, 11, 10);
    final snoozed = snoozeNudgeBannerEntity(
      nudge: makeNudgeView(relationship: true),
      now: now,
      until: now.add(const Duration(hours: 3)),
      eventId: 'snooze-r1',
    );
    expect(snoozed, isA<RelationshipNudgeEntity>());
    expect(
      NudgeEntityView.of(snoozed)!.lastSnoozeDuration,
      NudgeBannerSnoozeDuration.threeHours,
    );

    final dismissed = dismissNudgeBannerForDayEntity(
      nudge: makeNudgeView(relationship: true),
      now: now,
      eventId: 'dismiss-r1',
    );
    expect(dismissed, isA<RelationshipNudgeEntity>());
    expect(
      NudgeEntityView.of(dismissed)!.dismissalHistory.single.id,
      'dismiss-r1',
    );
  });
}
