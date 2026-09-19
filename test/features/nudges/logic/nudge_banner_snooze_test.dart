import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  // The reason survives the JSON round-trip sync puts it through, and an
  // unknown one from a newer client reads as none rather than failing.
  test('a snooze reason round-trips, and an unknown one reads as none', () {
    final event = NudgeEntityView.of(
      snoozeNudgeBannerEntity(
        nudge: makeNudgeView(),
        now: DateTime.utc(2026, 8, 11, 10),
        until: DateTime.utc(2026, 8, 11, 11),
        eventId: 'snooze-1',
        reason: NudgeSnoozeReason.opened,
      ),
    )!.snoozeHistory.single;

    final json = jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>;
    expect(NudgeSnooze.fromJson(json).reason, NudgeSnoozeReason.opened);
    expect(
      NudgeSnooze.fromJson({...json, 'reason': 'someFutureReason'}).reason,
      isNull,
    );
    expect(NudgeSnooze.fromJson({...json}..remove('reason')).reason, isNull);
  });

  // Codex review on #4356: concurrent snoozes keep the later deadline, not
  // the later event — the event in force is the one that set the deadline.
  group('nudgeBannerEffectiveSnooze', () {
    final now = DateTime.utc(2026, 8, 11, 10);

    NudgeEntityView snoozed(
      NudgeEntityView nudge,
      String id,
      Duration length,
      NudgeSnoozeReason? reason, {
      Duration after = Duration.zero,
    }) => NudgeEntityView.of(
      snoozeNudgeBannerEntity(
        nudge: nudge,
        now: now.add(after),
        until: now.add(after).add(length),
        eventId: id,
        reason: reason,
      ),
    )!;

    test('is the event whose return is the deadline in force', () {
      // An eight-hour snooze chosen first, then an opened one-hour pause
      // whose deadline lost the merge.
      final chosen = snoozed(
        makeNudgeView(),
        'chosen',
        const Duration(hours: 8),
        NudgeSnoozeReason.chosen,
      );
      final both = snoozed(
        chosen,
        'opened',
        const Duration(hours: 1),
        NudgeSnoozeReason.opened,
        after: const Duration(minutes: 5),
      );
      final merged = NudgeEntityView.of(
        both.copyWith(snoozedUntil: chosen.snoozedUntil),
      )!;

      expect(nudgeBannerEffectiveSnooze(merged)?.id, 'chosen');
      expect(nudgeBannerEffectiveSnooze(both)?.id, 'opened');
    });

    test('is none without a deadline, or when no event of this activation '
        'set it', () {
      expect(nudgeBannerEffectiveSnooze(makeNudgeView()), isNull);
      expect(
        nudgeBannerEffectiveSnooze(
          makeNudgeView(snoozedUntil: DateTime.utc(2026, 8, 11, 12)),
        ),
        isNull,
      );
    });
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

  group('properties', () {
    final base = DateTime.utc(2026);
    // Instants across the year, biased to the EU and US DST switch days.
    final instant = glados.any.oneOf([
      glados.any
          .intInRange(0, 366 * 24 * 60)
          .map((m) => base.add(Duration(minutes: m))),
      glados.any.combine2(
        glados.any.choose([
          DateTime.utc(2026, 3, 8),
          DateTime.utc(2026, 3, 28),
          DateTime.utc(2026, 3, 29),
          DateTime.utc(2026, 10, 24),
          DateTime.utc(2026, 10, 25),
          DateTime.utc(2026, 11),
        ]),
        glados.any.intInRange(0, 48 * 60 * 60),
        (DateTime day, int seconds) => day.add(Duration(seconds: seconds)),
      ),
    ]);
    // Up to a week ahead, in whole seconds; staleAt anywhere in ±10 days.
    final lead = glados.any.intInRange(1, 7 * 24 * 60 * 60);
    final staleOffsetHours = glados.any.intInRange(-240, 240);

    glados.Glados3(
      instant,
      lead,
      staleOffsetHours,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'a snooze hides the banner exactly until its deadline',
      (now, leadSeconds, staleHours) {
        final until = now.add(Duration(seconds: leadSeconds));
        final priorStaleAt = now.add(Duration(hours: staleHours));
        final nudge = makeNudgeView(staleAt: priorStaleAt);
        final snoozed = NudgeEntityView.of(
          snoozeNudgeBannerEntity(
            nudge: nudge,
            now: now,
            until: until,
            eventId: 'snooze-1',
          ),
        )!;

        for (final fraction in [0.0, 0.25, 0.5, 0.99]) {
          final t = now.add(
            Duration(seconds: (leadSeconds * fraction).floor()),
          );
          expect(nudgeBannerIsSnoozed(snoozed, t), isTrue, reason: '$t');
        }
        expect(
          nudgeBannerIsSnoozed(
            snoozed,
            until.subtract(const Duration(milliseconds: 1)),
          ),
          isTrue,
        );
        expect(nudgeBannerIsSnoozed(snoozed, until), isFalse);

        // staleAt never moves earlier, and outlives the quiet period.
        expect(snoozed.staleAt!.isBefore(priorStaleAt), isFalse);
        expect(
          snoozed.staleAt!.isBefore(until.add(nudgeBannerLifetime)),
          isFalse,
        );

        // Whole minutes, rounded up.
        final minutes = snoozed.snoozeHistory.single.durationMinutes;
        expect(minutes, (leadSeconds + 59) ~/ 60);
        expect(minutes * 60, greaterThanOrEqualTo(leadSeconds));
      },
      tags: 'glados',
    );

    glados.Glados3(
      instant,
      lead,
      lead,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'replaying a snooze event id changes nothing',
      (now, firstLead, secondLead) {
        final once = snoozeNudgeBannerEntity(
          nudge: makeNudgeView(),
          now: now,
          until: now.add(Duration(seconds: firstLead)),
          eventId: 'snooze-1',
        );
        final replayed = snoozeNudgeBannerEntity(
          nudge: NudgeEntityView.of(once)!,
          now: now.add(const Duration(minutes: 1)),
          until: now.add(Duration(seconds: secondLead + 60)),
          eventId: 'snooze-1',
        );
        expect(replayed, once);
      },
      tags: 'glados',
    );

    glados.Glados(instant, glados.ExploreConfig(numRuns: 300)).test(
      'the next local midnight is the start of the next calendar day',
      (now) {
        final local = now.toLocal();
        final midnight = nudgeBannerNextLocalMidnight(now);
        final tomorrow = DateTime(local.year, local.month, local.day + 1, 12);

        expect(midnight.isAfter(now), isTrue);
        expect(
          midnight.difference(now),
          lessThanOrEqualTo(const Duration(hours: 25)),
        );
        expect(
          (midnight.year, midnight.month, midnight.day),
          (tomorrow.year, tomorrow.month, tomorrow.day),
        );
        expect((midnight.hour, midnight.minute), (0, 0));
      },
      tags: 'glados',
    );
  });
}
