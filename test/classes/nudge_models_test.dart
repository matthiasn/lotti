import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';

void main() {
  group('NudgeBannerSnoozeDuration', () {
    test('the user-facing presets map to their exact durations', () {
      expect(
        NudgeBannerSnoozeDuration.oneHour.duration,
        const Duration(hours: 1),
      );
      expect(
        NudgeBannerSnoozeDuration.threeHours.duration,
        const Duration(hours: 3),
      );
      expect(
        NudgeBannerSnoozeDuration.sixHours.duration,
        const Duration(hours: 6),
      );
      expect(
        NudgeBannerSnoozeDuration.eightHours.duration,
        const Duration(hours: 8),
      );
      expect(NudgeBannerSnoozeDuration.custom.duration, isNull);
    });

    test('exact presets are recognized; arbitrary chat snoozes are custom', () {
      expect(
        nudgeBannerSnoozeDurationFor(const Duration(hours: 3)),
        NudgeBannerSnoozeDuration.threeHours,
      );
      expect(
        nudgeBannerSnoozeDurationFor(const Duration(minutes: 90)),
        NudgeBannerSnoozeDuration.custom,
      );
    });
  });

  group('NudgeSnooze', () {
    test('round-trips timing evidence and local offset', () {
      final event = NudgeSnooze(
        id: 'snooze-1',
        activation: 2,
        snoozedAt: DateTime.utc(2026, 8, 13, 10),
        snoozedUntil: DateTime.utc(2026, 8, 13, 13),
        duration: NudgeBannerSnoozeDuration.threeHours,
        durationMinutes: 180,
        utcOffsetMinutes: 120,
        returnUtcOffsetMinutes: 180,
      );

      final decoded = NudgeSnooze.fromJson(
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

    test('rejects invalid duration and timezone evidence', () {
      final valid = NudgeSnooze(
        id: 'snooze-1',
        activation: 1,
        snoozedAt: DateTime.utc(2026, 8, 13, 10),
        snoozedUntil: DateTime.utc(2026, 8, 13, 11),
        duration: NudgeBannerSnoozeDuration.oneHour,
        durationMinutes: 60,
        utcOffsetMinutes: 120,
      ).toJson();

      for (final invalid in [
        {...valid, 'durationMinutes': 0},
        {...valid, 'durationMinutes': 90.5},
        {...valid, 'utcOffsetMinutes': 841},
        {...valid, 'utcOffsetMinutes': -841},
        {...valid, 'returnUtcOffsetMinutes': 841},
      ]) {
        expect(
          () => NudgeSnooze.fromJson(invalid),
          throwsFormatException,
        );
      }
    });

    test('accepts the extreme legal UTC offsets (-14h .. +14h)', () {
      final valid = NudgeSnooze(
        id: 'snooze-1',
        activation: 1,
        snoozedAt: DateTime.utc(2026, 8, 13, 10),
        snoozedUntil: DateTime.utc(2026, 8, 13, 11),
        duration: NudgeBannerSnoozeDuration.oneHour,
        durationMinutes: 60,
        utcOffsetMinutes: 120,
      ).toJson();

      expect(
        NudgeSnooze.fromJson({
          ...valid,
          'utcOffsetMinutes': -840,
        }).utcOffsetMinutes,
        -840,
      );
      expect(
        NudgeSnooze.fromJson({
          ...valid,
          'utcOffsetMinutes': 840,
        }).utcOffsetMinutes,
        840,
      );
    });
  });

  group('nudgeSnoozeJsonIssues', () {
    Map<String, dynamic> valid() => <String, dynamic>{
      'snoozedAt': '2026-08-13T10:00:00Z',
      'snoozedUntil': '2026-08-13T13:00:00+00:00',
      'durationMinutes': 180,
    };

    test('a consistent payload has no issues', () {
      expect(nudgeSnoozeJsonIssues(valid()), isEmpty);
    });

    test('requires replica-stable timestamp offsets', () {
      for (final field in ['snoozedAt', 'snoozedUntil']) {
        expect(
          nudgeSnoozeJsonIssues({
            ...valid(),
            field: '2026-08-13T10:00:00',
          }).single,
          contains('explicit UTC offset'),
          reason: field,
        );
      }
    });

    test('rejects malformed offset-bearing timestamps', () {
      expect(
        nudgeSnoozeJsonIssues({
          'snoozedAt': 'not-a-dateZ',
          'snoozedUntil': 'still-not-a-dateZ',
        }),
        ['snooze timestamps must be valid ISO-8601 instants'],
      );
    });

    test('rejects an inverted or zero-length snooze interval', () {
      expect(
        nudgeSnoozeJsonIssues({
          ...valid(),
          'snoozedUntil': '2026-08-13T09:00:00Z',
        }).single,
        contains('must be after'),
      );
      expect(
        nudgeSnoozeJsonIssues({
          ...valid(),
          'snoozedUntil': '2026-08-13T10:00:00Z',
        }).single,
        contains('must be after'),
      );
    });

    test('rejects a durationMinutes that contradicts the interval', () {
      expect(
        nudgeSnoozeJsonIssues({...valid(), 'durationMinutes': 179}).single,
        contains('must match the snooze interval'),
      );
    });

    test('durationMinutes is checked against the ceiling of the interval', () {
      // 150 s rounds up to 3 minutes: a sub-minute tail still counts as a
      // started minute, mirroring how the write path records the choice.
      final payload = <String, dynamic>{
        'snoozedAt': '2026-08-13T10:00:00Z',
        'snoozedUntil': '2026-08-13T10:02:30Z',
        'durationMinutes': 3,
      };
      expect(nudgeSnoozeJsonIssues(payload), isEmpty);
      expect(
        nudgeSnoozeJsonIssues({...payload, 'durationMinutes': 2}).single,
        contains('must match the snooze interval'),
      );
    });

    test('a non-integer durationMinutes is left to the field decoder', () {
      // The cross-field helper only audits values the per-field converter
      // would accept; fractionals are rejected at decode, not here.
      expect(
        nudgeSnoozeJsonIssues({...valid(), 'durationMinutes': 180.5}),
        isEmpty,
      );
      expect(
        nudgeSnoozeJsonIssues({...valid()}..remove('durationMinutes')),
        isEmpty,
      );
    });
  });

  group('NudgeDayDismissal', () {
    test('round-trips local timing evidence', () {
      final event = NudgeDayDismissal(
        id: 'dismiss-1',
        activation: 2,
        dismissedAt: DateTime.utc(2026, 8, 13, 18),
        dismissedUntil: DateTime.utc(2026, 8, 13, 22),
        utcOffsetMinutes: 120,
      );

      final decoded = NudgeDayDismissal.fromJson(
        jsonDecode(jsonEncode(event)) as Map<String, dynamic>,
      );

      expect(decoded, event);
      expect(decoded.dismissedAtLocal, DateTime.utc(2026, 8, 13, 20));
    });
  });

  group('nudgeDayDismissalJsonIssues', () {
    Map<String, dynamic> valid() => <String, dynamic>{
      'dismissedAt': '2026-08-13T18:00:00Z',
      'dismissedUntil': '2026-08-13T22:00:00Z',
    };

    test('a consistent payload has no issues', () {
      expect(nudgeDayDismissalJsonIssues(valid()), isEmpty);
    });

    test('rejects ambiguous or inverted instants', () {
      expect(
        nudgeDayDismissalJsonIssues({
          ...valid(),
          'dismissedAt': '2026-08-13T18:00:00',
        }).single,
        contains('explicit UTC offset'),
      );
      expect(
        nudgeDayDismissalJsonIssues({
          ...valid(),
          'dismissedUntil': '2026-08-13T17:00:00Z',
        }).single,
        contains('must be after'),
      );
    });

    test('equal instants are inverted, not tolerated', () {
      expect(
        nudgeDayDismissalJsonIssues({
          ...valid(),
          'dismissedUntil': '2026-08-13T18:00:00Z',
        }).single,
        contains('must be after'),
      );
    });

    test('rejects malformed offset timestamps', () {
      expect(
        nudgeDayDismissalJsonIssues({
          'dismissedAt': 'not-a-dateZ',
          'dismissedUntil': 'still-not-a-dateZ',
        }),
        ['day-dismissal timestamps must be valid ISO-8601 instants'],
      );
    });
  });

  group('NudgeRating contract', () {
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
      final rating = NudgeRating.fromJson(json());
      expect(rating.rating, 4);
      expect(rating.activation, 1);
      expect(rating.skipped, isFalse);
    });

    test('a skipped outcome carries no rating — and decodes', () {
      final rating = NudgeRating.fromJson(
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
          () => NudgeRating.fromJson(json(rating: bad)),
          throwsFormatException,
          reason: 'rating $bad',
        );
      }
    });

    test('cross-field contradictions are named by the boundary helper', () {
      // Converters cannot see across fields; the decode gate in
      // AgentDbConversions calls this helper and refuses the payload.
      expect(
        nudgeRatingJsonIssues(json(skipped: true)).single,
        contains('must not carry a rating'),
      );
      expect(
        nudgeRatingJsonIssues(json(rating: null)).single,
        contains('must carry its rating'),
      );
      expect(nudgeRatingJsonIssues(json()), isEmpty);
      expect(
        nudgeRatingJsonIssues(json(rating: null, skipped: true)),
        isEmpty,
      );
    });

    test('activations are 1-based integers', () {
      for (final bad in [0, -3, 1.5, null, 'x']) {
        expect(
          () => NudgeRating.fromJson(json(activation: bad)),
          throwsFormatException,
          reason: 'activation $bad',
        );
      }
    });
  });

  group('NudgeBrief', () {
    test('round-trips through the string form', () {
      const brief = NudgeBrief(
        headline: 'Your shoes filed a missing person report.',
        tone: NudgeTone.roast,
        animation: NudgeBannerAnimation.glitch,
        accent: NudgeBannerAccent.neon,
        tagline: 'Case status: unsolved.',
        cta: 'Close the case',
      );
      final decoded = NudgeBrief.fromJson(
        jsonDecode(jsonEncode(brief)) as Map<String, dynamic>,
      );
      expect(decoded, brief);
    });

    test(
      'serializes to the exact wire form goal-typed rows were written in',
      () {
        // The generalization must not move a single byte: enum values keep
        // their identifiers and field names are unchanged, so rows written by
        // older peers under the goal-prefixed type names decode here as-is.
        const brief = NudgeBrief(
          headline: 'h',
          tone: NudgeTone.roast,
          animation: NudgeBannerAnimation.glitch,
          accent: NudgeBannerAccent.neon,
          tagline: 't',
          cta: 'c',
        );
        expect(brief.toJson(), {
          'headline': 'h',
          'tone': 'roast',
          'animation': 'glitch',
          'accent': 'neon',
          'tagline': 't',
          'cta': 'c',
        });
      },
    );

    test('a missing accent decodes to the calm default', () {
      final decoded = NudgeBrief.fromJson({
        'headline': 'h',
        'tone': 'encourage',
        'animation': 'steady',
      });
      expect(decoded.accent, NudgeBannerAccent.calm);
      expect(decoded.tagline, isNull);
      expect(decoded.cta, isNull);
    });

    test('every enum keeps its full catalog of serialized names', () {
      // The catalogs are code-owned contracts (ADR 0058): a removed or
      // renamed value would break decoding of synced rows on older peers.
      expect(
        NudgeTone.values.map((v) => v.name),
        ['encourage', 'nudge', 'celebrate', 'roast'],
      );
      expect(
        NudgeStatus.values.map((v) => v.name),
        [
          'draft',
          'ready',
          'active',
          'dismissed',
          'retired',
          'expired',
          'superseded',
          'failed',
        ],
      );
      expect(
        NudgeBannerAnimation.values.map((v) => v.name),
        ['steady', 'typewriter', 'pulse', 'wave', 'marquee', 'glitch'],
      );
      expect(
        NudgeBannerAccent.values.map((v) => v.name),
        ['calm', 'ember', 'tide', 'neon', 'aurora'],
      );
      expect(
        NudgeBannerSnoozeDuration.values.map((v) => v.name),
        ['oneHour', 'threeHours', 'sixHours', 'eightHours', 'custom'],
      );
    });
  });
}
