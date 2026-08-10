import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 8, 10, 12);
  final fixedClock = Clock.fixed(now);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late List<AgentDomainEntity> upserts;
  late GoalNudgeInteractions interactions;

  GoalNudgeEntity nudge({
    GoalNudgeStatus status = GoalNudgeStatus.active,
    List<GoalNudgeRating> ratings = const [],
    int activationCount = 1,
    GCounter visibleMs = const GCounter.empty(),
    DateTime? firstShownAt,
  }) =>
      AgentDomainEntity.goalNudge(
            id: 'ad-1',
            agentId: 'goal-1',
            status: status,
            brief: const GoalNudgeBrief(
              headline: 'Your shoes filed a missing person report.',
              tone: GoalNudgeTone.nudge,
              animation: GoalBannerAnimation.pulse,
            ),
            briefDigest: 'd',
            createdAt: DateTime(2026, 8, 9),
            updatedAt: DateTime(2026, 8, 9),
            vectorClock: null,
            ratings: ratings,
            activationCount: activationCount,
            totalVisibleMs: visibleMs,
            firstShownAt: firstShownAt,
          )
          as GoalNudgeEntity;

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    upserts = [];
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    interactions = GoalNudgeInteractions(
      repository: repository,
      syncService: syncService,
    );
  });

  group('dismiss', () {
    test('an active ad becomes dismissed with the timestamp that starts '
        'the quiet window', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => nudge());
      await withClock(fixedClock, () => interactions.dismiss('ad-1'));
      final written = upserts.whereType<GoalNudgeEntity>().single;
      expect(written.status, GoalNudgeStatus.dismissed);
      expect(written.dismissedAt, now);
    });

    test('non-active ads and unknown ids are no-ops', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => nudge(status: GoalNudgeStatus.retired),
      );
      await interactions.dismiss('ad-1');
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => null);
      await interactions.dismiss('ad-1');
      expect(upserts, isEmpty);
    });
  });

  group('recordRating', () {
    test('one outcome per activation: the first write lands, the second '
        'is refused — re-runs re-prompt via a higher activation', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => nudge());
      await withClock(
        fixedClock,
        () => interactions.recordRating('ad-1', rating: 5),
      );
      final written = upserts.whereType<GoalNudgeEntity>().single;
      expect(written.ratings.single.rating, 5);
      expect(written.ratings.single.activation, 1);

      when(
        () => repository.getEntity('ad-1'),
      ).thenAnswer((_) async => written);
      await withClock(
        fixedClock,
        () => interactions.recordRating('ad-1', rating: 1),
      );
      expect(upserts, hasLength(1), reason: 'no second outcome for run 1');

      // A re-run (activation 2) prompts anew.
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => nudge(
          ratings: written.ratings,
          activationCount: 2,
        ),
      );
      await withClock(
        fixedClock,
        () => interactions.recordRating('ad-1', skipped: true),
      );
      final rerun = upserts.whereType<GoalNudgeEntity>().last;
      expect(rerun.ratings, hasLength(2));
      expect(rerun.ratings.last.activation, 2);
      expect(rerun.ratings.last.skipped, isTrue);
    });

    test('out-of-contract ratings throw before any read', () async {
      expect(
        () => interactions.recordRating('ad-1', rating: 6),
        throwsArgumentError,
      );
      expect(upserts, isEmpty);
    });
  });

  group('recordExposure', () {
    test('accumulates visible time and impressions under this host and '
        'widens the shown-at watermarks', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => nudge(
          visibleMs: const GCounter({'host-B': 500}),
          firstShownAt: DateTime(2026, 8, 9, 8),
        ),
      );
      await withClock(
        fixedClock,
        () => interactions.recordExposure(
          'ad-1',
          visibleFor: const Duration(seconds: 3),
        ),
      );
      final written = upserts.whereType<GoalNudgeEntity>().single;
      expect(written.totalVisibleMs.byHost, {'host-B': 500, 'test-host': 3000});
      expect(written.impressionCount.byHost, {'test-host': 1});
      expect(
        written.firstShownAt,
        DateTime(2026, 8, 9, 8),
        reason: 'the first showing is never overwritten',
      );
      expect(written.lastShownAt, now);
    });

    test('zero or negative visibility writes nothing', () async {
      await interactions.recordExposure('ad-1', visibleFor: Duration.zero);
      expect(upserts, isEmpty);
    });

    test('overlapping writes serialize per nudge — the second read sees '
        'the first increment instead of a stale snapshot', () async {
      // The repository serves the LAST upserted row, so a serialized
      // second call reads the first call's counters. The gate holds the
      // first write open across the second call's start: unserialized,
      // the second read would see the seed row and the increments would
      // collapse to the last write.
      var current = nudge();
      final gate = Completer<void>();
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => current,
      );
      when(
        () => syncService.upsertEntity(any()),
      ).thenAnswer((invocation) async {
        await gate.future;
        current = invocation.positionalArguments.first as GoalNudgeEntity;
        upserts.add(current);
      });

      await withClock(fixedClock, () async {
        // Fire-and-forget, like the banner tracker's flushes.
        final first = interactions.recordExposure(
          'ad-1',
          visibleFor: const Duration(seconds: 2),
        );
        final second = interactions.recordExposure(
          'ad-1',
          visibleFor: const Duration(seconds: 3),
        );
        // Let both calls progress as far as the gate allows before it
        // opens — this is the window where a stale read would happen.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        await Future.wait([first, second]);
      });

      final written = upserts.whereType<GoalNudgeEntity>().last;
      expect(written.totalVisibleMs.byHost, {'test-host': 5000});
      expect(written.impressionCount.byHost, {'test-host': 2});
    });
  });

  test('ratingDue: due exactly while active with no outcome for the '
      'current activation', () {
    expect(GoalNudgeInteractions.ratingDue(nudge()), isTrue);
    expect(
      GoalNudgeInteractions.ratingDue(
        nudge(
          ratings: [
            GoalNudgeRating(activation: 1, ratedAt: now, skipped: true),
          ],
        ),
      ),
      isFalse,
      reason: 'a skip counts — never nag twice for the same run',
    );
    expect(
      GoalNudgeInteractions.ratingDue(
        nudge(
          ratings: [
            GoalNudgeRating(activation: 1, ratedAt: now, rating: 4),
          ],
          activationCount: 2,
        ),
      ),
      isTrue,
      reason: 'a re-run prompts anew',
    );
    expect(
      GoalNudgeInteractions.ratingDue(nudge(status: GoalNudgeStatus.retired)),
      isFalse,
    );
  });
}
