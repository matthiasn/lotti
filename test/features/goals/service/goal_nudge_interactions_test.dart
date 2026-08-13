import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/logic/goal_banner_snooze.dart';
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
      newId: () => 'snooze-event-1',
    );
  });

  group('snooze', () {
    test('records current state and append-only timing evidence', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => nudge());
      final savedUntil = await withClock(
        fixedClock,
        () => interactions.snooze(
          'ad-1',
          duration: GoalBannerSnoozeDuration.threeHours,
        ),
      );
      final written = upserts.whereType<GoalNudgeEntity>().single;
      expect(savedUntil, now.add(const Duration(hours: 3)).toUtc());
      expect(written.status, GoalNudgeStatus.active);
      expect(written.snoozedUntil, now.add(const Duration(hours: 3)).toUtc());
      expect(
        written.lastSnoozeDuration,
        GoalBannerSnoozeDuration.threeHours,
      );
      final event = written.snoozeHistory.single;
      expect(event.id, 'snooze-event-1');
      expect(event.activation, 1);
      expect(event.snoozedAt, now.toUtc());
      expect(event.durationMinutes, 180);
      expect(event.utcOffsetMinutes, now.timeZoneOffset.inMinutes);
      expect(
        written.staleAt,
        event.snoozedUntil.add(const Duration(hours: 72)),
        reason: 'quiet time does not consume the banner lifetime',
      );
    });

    test('a snooze for a superseded activation is discarded — the tap '
        'targeted a banner sync has already re-run', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => nudge(activationCount: 3),
      );
      final staleResult = await interactions.snooze(
        'ad-1',
        duration: GoalBannerSnoozeDuration.oneHour,
        forActivation: 2,
      );
      expect(staleResult, isNull);
      expect(upserts, isEmpty);

      final currentResult = await withClock(
        fixedClock,
        () => interactions.snooze(
          'ad-1',
          duration: GoalBannerSnoozeDuration.oneHour,
          forActivation: 3,
        ),
      );
      expect(currentResult, now.add(const Duration(hours: 1)).toUtc());
      expect(
        upserts
            .whereType<GoalNudgeEntity>()
            .single
            .snoozeHistory
            .single
            .activation,
        3,
      );
    });

    test('a durable snooze survives a failed sync enqueue without asking the '
        'user to retry', () async {
      var persisted = nudge();
      final throwing = _CommitThenThrowSyncService();
      when(() => throwing.upsertEntity(any())).thenAnswer((invocation) async {
        persisted = invocation.positionalArguments.first as GoalNudgeEntity;
      });
      when(
        () => repository.getEntity('ad-1'),
      ).thenAnswer((_) async => persisted);
      final reconciling = GoalNudgeInteractions(
        repository: repository,
        syncService: throwing,
        newId: () => 'durable-snooze',
      );

      final saved = await withClock(
        fixedClock,
        () => reconciling.snooze(
          'ad-1',
          duration: GoalBannerSnoozeDuration.oneHour,
        ),
      );

      expect(saved, now.add(const Duration(hours: 1)).toUtc());
      expect(persisted.snoozeHistory.single.id, 'durable-snooze');
      expect(persisted.snoozedUntil, now.add(const Duration(hours: 1)).toUtc());
    });
  });

  group('dismissForDay', () {
    test('keeps the banner active and records the local-day gate', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => nudge());
      final savedUntil = await withClock(
        fixedClock,
        () => interactions.dismissForDay('ad-1'),
      );
      final written = upserts.whereType<GoalNudgeEntity>().single;
      final expectedUntil = goalBannerNextLocalMidnight(now).toUtc();
      expect(savedUntil, expectedUntil);
      expect(written.status, GoalNudgeStatus.active);
      expect(written.dismissedForDayAt, now.toUtc());
      expect(written.dismissedAt, isNull);
      final event = written.dismissalHistory.single;
      expect(event.id, 'snooze-event-1');
      expect(event.dismissedAt, now.toUtc());
      expect(event.dismissedUntil, expectedUntil);
      expect(written.staleAt, expectedUntil.add(goalBannerLifetime));
      expect(
        written.provenance[goalBannerSnoozedUntilKey],
        expectedUntil.toIso8601String(),
      );
    });

    test('non-active ads and unknown ids are no-ops', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => nudge(status: GoalNudgeStatus.retired),
      );
      expect(await interactions.dismissForDay('ad-1'), isNull);
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => null);
      expect(await interactions.dismissForDay('ad-1'), isNull);
      expect(upserts, isEmpty);
    });

    test('a durable day dismissal survives a failed sync enqueue without '
        'asking the user to retry', () async {
      var persisted = nudge();
      final throwing = _CommitThenThrowSyncService();
      when(() => throwing.upsertEntity(any())).thenAnswer((invocation) async {
        persisted = invocation.positionalArguments.first as GoalNudgeEntity;
      });
      when(
        () => repository.getEntity('ad-1'),
      ).thenAnswer((_) async => persisted);
      final reconciling = GoalNudgeInteractions(
        repository: repository,
        syncService: throwing,
        newId: () => 'durable-dismissal',
      );

      final saved = await withClock(
        fixedClock,
        () => reconciling.dismissForDay('ad-1'),
      );

      expect(saved, goalBannerNextLocalMidnight(now).toUtc());
      expect(persisted.dismissedForDayAt, now.toUtc());
      expect(persisted.dismissalHistory.single.id, 'durable-dismissal');
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

    test('a rating whose commit was durable but whose sync enqueue threw '
        'is reported as SUCCESS — no misleading retry notice', () async {
      var persisted = nudge();
      final throwing = _CommitThenThrowSyncService();
      when(() => throwing.upsertEntity(any())).thenAnswer((invocation) async {
        persisted = invocation.positionalArguments.first as GoalNudgeEntity;
      });
      when(
        () => repository.getEntity('ad-1'),
      ).thenAnswer((_) async => persisted);
      final reconciling = GoalNudgeInteractions(
        repository: repository,
        syncService: throwing,
      );
      await withClock(
        fixedClock,
        () => reconciling.recordRating('ad-1', rating: 4, forActivation: 1),
      );
      expect(persisted.ratings.single.rating, 4);
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
      expect(written.lastShownAt, now.toUtc());
    });

    test('an unset firstShownAt is stamped with the episode START, not '
        'the flush instant', () async {
      when(() => repository.getEntity('ad-1')).thenAnswer((_) async => nudge());
      await withClock(
        fixedClock,
        () => interactions.recordExposure(
          'ad-1',
          visibleFor: const Duration(seconds: 30),
        ),
      );
      final written = upserts.whereType<GoalNudgeEntity>().single;
      expect(
        written.firstShownAt,
        now.subtract(const Duration(seconds: 30)).toUtc(),
        reason:
            'a flush racing a dismissal must not place firstShownAt '
            'after dismissedAt',
      );
      expect(written.lastShownAt, now.toUtc());
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
      final firstWriteAtGate = Completer<void>();
      when(() => repository.getEntity('ad-1')).thenAnswer(
        (_) async => current,
      );
      when(
        () => syncService.upsertEntity(any()),
      ).thenAnswer((invocation) async {
        if (!firstWriteAtGate.isCompleted) firstWriteAtGate.complete();
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
        // Wait until the first write is held at the gate — the window in
        // which an unserialized second call reads the stale seed row —
        // then open it.
        await firstWriteAtGate.future;
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

/// Runs the transaction body (writes land) and THEN throws — the durable
/// commit + failed outbox flush shape.
class _CommitThenThrowSyncService extends MockAgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    await action();
    throw StateError('outbox flush failed');
  }
}
