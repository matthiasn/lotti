import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/features/sync/g_counter.dart';

void main() {
  final snooze = NudgeSnooze(
    id: 'snooze-1',
    activation: 2,
    snoozedAt: DateTime.utc(2026, 8, 13, 10),
    snoozedUntil: DateTime.utc(2026, 8, 13, 13),
    duration: NudgeBannerSnoozeDuration.threeHours,
    durationMinutes: 180,
    utcOffsetMinutes: 120,
  );
  final dismissal = NudgeDayDismissal(
    id: 'dismiss-1',
    activation: 2,
    dismissedAt: DateTime.utc(2026, 8, 13, 18),
    dismissedUntil: DateTime.utc(2026, 8, 13, 22),
    utcOffsetMinutes: 120,
  );
  final rating = NudgeRating(
    activation: 2,
    ratedAt: DateTime.utc(2026, 8, 13, 12),
    rating: 4,
  );

  GoalNudgeEntity goalNudge() =>
      AgentDomainEntity.goalNudge(
            id: 'g-1',
            agentId: 'goal-1',
            status: NudgeStatus.active,
            brief: const NudgeBrief(
              headline: 'Move.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'dg',
            createdAt: DateTime.utc(2026, 8, 12),
            updatedAt: DateTime.utc(2026, 8, 13),
            vectorClock: null,
            activatedAt: DateTime.utc(2026, 8, 12, 6),
            staleAt: DateTime.utc(2026, 8, 15),
            snoozedUntil: snooze.snoozedUntil,
            dismissedForDayAt: dismissal.dismissedAt,
            activationCount: 2,
            snoozeHistory: [snooze],
            dismissalHistory: [dismissal],
            ratings: [rating],
            totalVisibleMs: const GCounter({'phone': 500}),
            impressionCount: const GCounter({'phone': 2}),
            firstShownAt: DateTime.utc(2026, 8, 12, 7),
            provenance: const {'specVersionId': 'spec-1'},
          )
          as GoalNudgeEntity;

  RelationshipNudgeEntity relationshipNudge() =>
      AgentDomainEntity.relationshipNudge(
            id: 'r-1',
            agentId: 'relationship-1',
            status: NudgeStatus.ready,
            brief: const NudgeBrief(
              headline: 'Check in with Anna.',
              tone: NudgeTone.encourage,
              animation: NudgeBannerAnimation.typewriter,
            ),
            briefDigest: 'dr',
            createdAt: DateTime.utc(2026, 8, 12),
            updatedAt: DateTime.utc(2026, 8, 13),
            vectorClock: null,
            ratings: [rating],
          )
          as RelationshipNudgeEntity;

  test('of() wraps exactly the nudge variants and nothing else', () {
    expect(NudgeEntityView.of(goalNudge()), isNotNull);
    expect(NudgeEntityView.of(relationshipNudge()), isNotNull);
    expect(
      NudgeEntityView.of(
        AgentDomainEntity.unknown(
          id: 'x',
          agentId: 'a',
          createdAt: DateTime.utc(2026),
        ),
      ),
      isNull,
      reason: 'a non-nudge entity must never masquerade as a banner',
    );
  });

  test('getters read the same values from either variant', () {
    final goal = NudgeEntityView.of(goalNudge())!;
    expect(goal.id, 'g-1');
    expect(goal.agentId, 'goal-1');
    expect(goal.status, NudgeStatus.active);
    expect(goal.brief.headline, 'Move.');
    expect(goal.createdAt, DateTime.utc(2026, 8, 12));
    expect(goal.activatedAt, DateTime.utc(2026, 8, 12, 6));
    expect(goal.staleAt, DateTime.utc(2026, 8, 15));
    expect(goal.snoozedUntil, snooze.snoozedUntil);
    expect(goal.dismissedForDayAt, dismissal.dismissedAt);
    expect(goal.activationCount, 2);
    expect(goal.ratings, [rating]);
    expect(goal.snoozeHistory, [snooze]);
    expect(goal.dismissalHistory, [dismissal]);
    expect(goal.totalVisibleMs.value, 500);
    expect(goal.impressionCount.value, 2);
    expect(goal.firstShownAt, DateTime.utc(2026, 8, 12, 7));
    expect(goal.provenance, {'specVersionId': 'spec-1'});

    final relationship = NudgeEntityView.of(relationshipNudge())!;
    expect(relationship.id, 'r-1');
    expect(relationship.status, NudgeStatus.ready);
    expect(relationship.activationCount, 1);
    expect(relationship.ratings, [rating]);
    expect(relationship.activatedAt, isNull);
  });

  group('copyWith', () {
    test('writes through to the goal variant and preserves its type', () {
      final updated = NudgeEntityView.of(goalNudge())!.copyWith(
        staleAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 14),
        totalVisibleMs: const GCounter({'phone': 900}),
      );
      expect(updated, isA<GoalNudgeEntity>());
      final view = NudgeEntityView.of(updated)!;
      expect(view.staleAt, DateTime.utc(2026, 8, 20));
      expect(view.totalVisibleMs.value, 900);
      // Untouched fields survive.
      expect(view.snoozeHistory, [snooze]);
      expect(view.activationCount, 2);
    });

    test('writes through to the relationship variant and preserves its '
        'type', () {
      final updated = NudgeEntityView.of(relationshipNudge())!.copyWith(
        ratings: const [],
        firstShownAt: DateTime.utc(2026, 8, 13),
      );
      expect(updated, isA<RelationshipNudgeEntity>());
      final view = NudgeEntityView.of(updated)!;
      expect(view.ratings, isEmpty);
      expect(view.firstShownAt, DateTime.utc(2026, 8, 13));
    });

    test('an explicit null clears the quiet-state fields; omission keeps '
        'them', () {
      final view = NudgeEntityView.of(goalNudge())!;
      // Omitted: both quiet deadlines survive.
      final untouched = NudgeEntityView.of(
        view.copyWith(updatedAt: DateTime.utc(2026, 8, 14)),
      )!;
      expect(untouched.snoozedUntil, snooze.snoozedUntil);
      expect(untouched.dismissedForDayAt, dismissal.dismissedAt);
      // Explicit null: cleared — the snooze↔day-dismissal handover relies
      // on this distinction.
      final cleared = NudgeEntityView.of(
        view.copyWith(snoozedUntil: null, dismissedForDayAt: null),
      )!;
      expect(cleared.snoozedUntil, isNull);
      expect(cleared.dismissedForDayAt, isNull);
    });
  });
}
