import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';

void main() {
  group('GoalBannerSnoozeDuration', () {
    test('the user-facing presets map to their exact durations', () {
      expect(
        GoalBannerSnoozeDuration.oneHour.duration,
        const Duration(hours: 1),
      );
      expect(
        GoalBannerSnoozeDuration.threeHours.duration,
        const Duration(hours: 3),
      );
      expect(
        GoalBannerSnoozeDuration.sixHours.duration,
        const Duration(hours: 6),
      );
      expect(
        GoalBannerSnoozeDuration.eightHours.duration,
        const Duration(hours: 8),
      );
      expect(GoalBannerSnoozeDuration.custom.duration, isNull);
    });

    test('exact presets are recognized; arbitrary chat snoozes are custom', () {
      expect(
        goalBannerSnoozeDurationFor(const Duration(hours: 3)),
        GoalBannerSnoozeDuration.threeHours,
      );
      expect(
        goalBannerSnoozeDurationFor(const Duration(minutes: 90)),
        GoalBannerSnoozeDuration.custom,
      );
    });
  });

  test('GoalNudgeSnooze round-trips timing evidence and local offset', () {
    final event = GoalNudgeSnooze(
      id: 'snooze-1',
      activation: 2,
      snoozedAt: DateTime.utc(2026, 8, 13, 10),
      snoozedUntil: DateTime.utc(2026, 8, 13, 13),
      duration: GoalBannerSnoozeDuration.threeHours,
      durationMinutes: 180,
      utcOffsetMinutes: 120,
      returnUtcOffsetMinutes: 180,
    );

    final decoded = GoalNudgeSnooze.fromJson(
      jsonDecode(jsonEncode(event)) as Map<String, dynamic>,
    );

    expect(decoded, event);
    expect(decoded.snoozedAtLocal, DateTime.utc(2026, 8, 13, 12));
    expect(decoded.snoozedUntilLocal, DateTime.utc(2026, 8, 13, 16));
    expect(
      decoded.copyWith(returnUtcOffsetMinutes: null).snoozedUntilLocal,
      DateTime.utc(2026, 8, 13, 15),
      reason: 'older events retain their action-offset interpretation',
    );
  });

  test('GoalNudgeSnooze rejects invalid duration and timezone evidence', () {
    final valid = GoalNudgeSnooze(
      id: 'snooze-1',
      activation: 1,
      snoozedAt: DateTime.utc(2026, 8, 13, 10),
      snoozedUntil: DateTime.utc(2026, 8, 13, 11),
      duration: GoalBannerSnoozeDuration.oneHour,
      durationMinutes: 60,
      utcOffsetMinutes: 120,
    ).toJson();

    for (final invalid in [
      {...valid, 'durationMinutes': 0},
      {...valid, 'utcOffsetMinutes': 841},
    ]) {
      expect(
        () => GoalNudgeSnooze.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('snooze validation requires replica-stable timestamp offsets', () {
    final valid = <String, dynamic>{
      'snoozedAt': '2026-08-13T10:00:00Z',
      'snoozedUntil': '2026-08-13T13:00:00+00:00',
      'durationMinutes': 180,
    };
    expect(goalNudgeSnoozeJsonIssues(valid), isEmpty);
    for (final field in ['snoozedAt', 'snoozedUntil']) {
      expect(
        goalNudgeSnoozeJsonIssues({
          ...valid,
          field: '2026-08-13T10:00:00',
        }).single,
        contains('explicit UTC offset'),
        reason: field,
      );
    }
  });

  test('snooze validation rejects malformed offset-bearing timestamps', () {
    expect(
      goalNudgeSnoozeJsonIssues({
        'snoozedAt': 'not-a-dateZ',
        'snoozedUntil': 'still-not-a-dateZ',
      }),
      ['snooze timestamps must be valid ISO-8601 instants'],
    );
  });

  test('GoalNudgeDayDismissal round-trips local timing evidence', () {
    final event = GoalNudgeDayDismissal(
      id: 'dismiss-1',
      activation: 2,
      dismissedAt: DateTime.utc(2026, 8, 13, 18),
      dismissedUntil: DateTime.utc(2026, 8, 13, 22),
      utcOffsetMinutes: 120,
    );

    final decoded = GoalNudgeDayDismissal.fromJson(
      jsonDecode(jsonEncode(event)) as Map<String, dynamic>,
    );

    expect(decoded, event);
    expect(decoded.dismissedAtLocal, DateTime.utc(2026, 8, 13, 20));
  });

  test('day-dismissal validation rejects ambiguous or inverted instants', () {
    final valid = <String, dynamic>{
      'dismissedAt': '2026-08-13T18:00:00Z',
      'dismissedUntil': '2026-08-13T22:00:00Z',
    };
    expect(goalNudgeDayDismissalJsonIssues(valid), isEmpty);
    expect(
      goalNudgeDayDismissalJsonIssues({
        ...valid,
        'dismissedAt': '2026-08-13T18:00:00',
      }).single,
      contains('explicit UTC offset'),
    );
    expect(
      goalNudgeDayDismissalJsonIssues({
        ...valid,
        'dismissedUntil': '2026-08-13T17:00:00Z',
      }).single,
      contains('must be after'),
    );
  });

  test('day-dismissal validation rejects malformed offset timestamps', () {
    expect(
      goalNudgeDayDismissalJsonIssues({
        'dismissedAt': 'not-a-dateZ',
        'dismissedUntil': 'still-not-a-dateZ',
      }),
      ['day-dismissal timestamps must be valid ISO-8601 instants'],
    );
  });

  group('GoalNudgeRating contract', () {
    Map<String, dynamic> json({
      Object? rating = 4,
      Object? activation = 1,
      bool skipped = false,
    }) => {
      'activation': activation,
      'ratedAt': '2026-08-08T10:00:00.000',
      'rating': rating,
      'skipped': skipped,
    };

    test('a valid rated outcome decodes', () {
      final rating = GoalNudgeRating.fromJson(json());
      expect(rating.rating, 4);
      expect(rating.activation, 1);
      expect(rating.skipped, isFalse);
    });

    test('a skipped outcome carries no rating — and decodes', () {
      final rating = GoalNudgeRating.fromJson(
        json(rating: null, skipped: true),
      );
      expect(rating.skipped, isTrue);
      expect(rating.rating, isNull);
    });

    test('out-of-scale and fractional ratings are rejected, not truncated', () {
      // The generated decoder would turn 4.9 into 4 and store a lie in the
      // permanent history; the validating factory refuses instead.
      for (final bad in [0, 6, 4.9, -1]) {
        expect(
          () => GoalNudgeRating.fromJson(json(rating: bad)),
          throwsFormatException,
          reason: 'rating $bad',
        );
      }
    });

    test('cross-field contradictions are named by the boundary helper', () {
      // Converters cannot see across fields; the decode gate in
      // AgentDbConversions calls this helper and refuses the payload.
      expect(
        goalNudgeRatingJsonIssues(json(skipped: true)).single,
        contains('must not carry a rating'),
      );
      expect(
        goalNudgeRatingJsonIssues(json(rating: null)).single,
        contains('must carry its rating'),
      );
      expect(goalNudgeRatingJsonIssues(json()), isEmpty);
      expect(
        goalNudgeRatingJsonIssues(json(rating: null, skipped: true)),
        isEmpty,
      );
    });

    test('activations are 1-based integers', () {
      for (final bad in [0, -3, 1.5, null, 'x']) {
        expect(
          () => GoalNudgeRating.fromJson(json(activation: bad)),
          throwsFormatException,
          reason: 'activation $bad',
        );
      }
    });
  });

  test('GoalNudgeBrief round-trips through the string form', () {
    const brief = GoalNudgeBrief(
      headline: 'Your shoes filed a missing person report.',
      tone: GoalNudgeTone.roast,
      animation: GoalBannerAnimation.glitch,
      accent: GoalBannerAccent.neon,
      tagline: 'Case status: unsolved.',
      cta: 'Close the case',
    );
    final decoded = GoalNudgeBrief.fromJson(
      jsonDecode(jsonEncode(brief)) as Map<String, dynamic>,
    );
    expect(decoded, brief);
  });
}
