import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';

void main() {
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

    test('cross-field contradictions fail construction', () {
      // Skipped-with-rating and unskipped-without-rating both violate the
      // invariant; the converters cannot see across fields, the assert can.
      expect(
        () => GoalNudgeRating.fromJson(json(skipped: true)),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => GoalNudgeRating.fromJson(json(rating: null)),
        throwsA(isA<AssertionError>()),
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

    test('construction asserts the same contract', () {
      expect(
        () => GoalNudgeRating(
          activation: 1,
          rating: 9,
          ratedAt: DateTime.utc(2026, 8, 8),
        ),
        throwsAssertionError,
      );
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
