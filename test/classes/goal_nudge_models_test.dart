import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';

/// The shim contract: every goal-prefixed name is a pure alias for its
/// kind-agnostic original (ADR 0059) — same type, same values, same
/// serialized form. Behavior of the vocabulary itself is covered by
/// `nudge_models_test.dart`; this file only pins that the aliases cannot
/// drift into separate types.
void main() {
  test('goal-prefixed enum aliases resolve to the shared enum values', () {
    // Type aliases share identity with the aliased type — an enum value
    // reached through the goal name IS the shared value, so switches,
    // maps, and serialized names can never diverge between the two names.
    expect(identical(GoalNudgeTone.roast, NudgeTone.roast), isTrue);
    expect(identical(GoalNudgeStatus.active, NudgeStatus.active), isTrue);
    expect(
      identical(GoalBannerAnimation.glitch, NudgeBannerAnimation.glitch),
      isTrue,
    );
    expect(identical(GoalBannerAccent.neon, NudgeBannerAccent.neon), isTrue);
    expect(
      identical(
        GoalBannerSnoozeDuration.threeHours,
        NudgeBannerSnoozeDuration.threeHours,
      ),
      isTrue,
    );
    expect(GoalNudgeTone.values, same(NudgeTone.values));
    expect(GoalNudgeStatus.values, same(NudgeStatus.values));
  });

  test('goal-prefixed helper aliases are the shared functions themselves', () {
    expect(
      identical(goalBannerSnoozeDurationFor, nudgeBannerSnoozeDurationFor),
      isTrue,
    );
    expect(
      identical(goalNudgeRatingJsonIssues, nudgeRatingJsonIssues),
      isTrue,
    );
    expect(
      identical(goalNudgeSnoozeJsonIssues, nudgeSnoozeJsonIssues),
      isTrue,
    );
    expect(
      identical(goalNudgeDayDismissalJsonIssues, nudgeDayDismissalJsonIssues),
      isTrue,
    );
  });

  test(
    'a goal-typed construction is the shared type on the same wire form',
    () {
      // A brief built through the old names must be indistinguishable from
      // one built through the new — including its exact serialized map, which
      // is what synced rows written before the extraction contain.
      const viaGoalNames = GoalNudgeBrief(
        headline: 'Your shoes filed a missing person report.',
        tone: GoalNudgeTone.roast,
        animation: GoalBannerAnimation.glitch,
        accent: GoalBannerAccent.neon,
      );
      const viaSharedNames = NudgeBrief(
        headline: 'Your shoes filed a missing person report.',
        tone: NudgeTone.roast,
        animation: NudgeBannerAnimation.glitch,
        accent: NudgeBannerAccent.neon,
      );

      expect(viaGoalNames, viaSharedNames);
      expect(viaGoalNames, isA<NudgeBrief>());
      expect(viaGoalNames.toJson(), viaSharedNames.toJson());
    },
  );

  test(
    'pre-extraction payloads decode through the goal-prefixed factories',
    () {
      // Captured from the goal-typed generator's output before the
      // extraction: the alias factories must keep decoding it verbatim.
      final snooze = GoalNudgeSnooze.fromJson(const {
        'id': 'snooze-1',
        'activation': 2,
        'snoozedAt': '2026-08-13T10:00:00.000Z',
        'snoozedUntil': '2026-08-13T13:00:00.000Z',
        'duration': 'threeHours',
        'durationMinutes': 180,
        'utcOffsetMinutes': 120,
        'returnUtcOffsetMinutes': null,
      });
      expect(snooze.duration, NudgeBannerSnoozeDuration.threeHours);
      expect(snooze.snoozedAtLocal, DateTime.utc(2026, 8, 13, 12));

      final dismissal = GoalNudgeDayDismissal.fromJson(const {
        'id': 'dismiss-1',
        'activation': 1,
        'dismissedAt': '2026-08-13T18:00:00.000Z',
        'dismissedUntil': '2026-08-13T22:00:00.000Z',
        'utcOffsetMinutes': 120,
      });
      expect(dismissal.dismissedAtLocal, DateTime.utc(2026, 8, 13, 20));

      final rating = GoalNudgeRating.fromJson(const {
        'activation': 1,
        'ratedAt': '2026-08-08T10:00:00.000',
        'rating': 4,
        'skipped': false,
      });
      expect(rating.rating, 4);
      expect(rating, isA<NudgeRating>());
    },
  );
}
