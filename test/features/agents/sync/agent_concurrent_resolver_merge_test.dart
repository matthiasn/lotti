import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  GoalNudgeEntity goalNudge({
    required NudgeStatus status,
    String id = 'n1',
    List<NudgeRating> ratings = const [],
    GCounter visibleMs = const GCounter.empty(),
    GCounter impressions = const GCounter.empty(),
    int activationCount = 1,
    DateTime? firstShownAt,
    DateTime? lastShownAt,
    DateTime? staleAt,
    DateTime? snoozedUntil,
    NudgeBannerSnoozeDuration? lastSnoozeDuration,
    List<NudgeSnooze> snoozeHistory = const [],
    DateTime? dismissedForDayAt,
    List<NudgeDayDismissal> dismissalHistory = const [],
  }) =>
      AgentDomainEntity.goalNudge(
            id: id,
            agentId: 'a1',
            status: status,
            brief: const NudgeBrief(
              headline: 'Your shoes filed a missing person report.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.pulse,
            ),
            briefDigest: 'digest-1',
            createdAt: DateTime(2026, 8),
            updatedAt: DateTime(2026, 8),
            vectorClock: null,
            ratings: ratings,
            totalVisibleMs: visibleMs,
            impressionCount: impressions,
            activationCount: activationCount,
            firstShownAt: firstShownAt,
            lastShownAt: lastShownAt,
            staleAt: staleAt,
            snoozedUntil: snoozedUntil,
            lastSnoozeDuration: lastSnoozeDuration,
            snoozeHistory: snoozeHistory,
            dismissedForDayAt: dismissedForDayAt,
            dismissalHistory: dismissalHistory,
          )
          as GoalNudgeEntity;

  group('resolveConcurrentAgentEntityOverride', () {
    PlannerKnowledgeEntity knowledge({
      required KnowledgeStatus status,
      String id = 'k1',
    }) =>
        AgentDomainEntity.plannerKnowledge(
              id: id,
              agentId: 'a1',
              key: 'deep-work',
              hook: 'no deep work before 10',
              statementText: 'Never schedule deep work before 10:00.',
              source: KnowledgeSource.userStated,
              status: status,
              createdAt: DateTime(2026, 5, 20),
              updatedAt: DateTime(2026, 5, 20),
              vectorClock: null,
            )
            as PlannerKnowledgeEntity;

    ScheduledWakeEntity wake({
      required DateTime scheduledAt,
      required ScheduledWakeStatus status,
      String id = 'w1',
    }) =>
        AgentDomainEntity.scheduledWake(
              id: id,
              agentId: 'a1',
              scheduledAt: scheduledAt,
              status: status,
              reason: 'scheduled',
              updatedAt: DateTime(2026, 5, 20),
              vectorClock: null,
              triggerTokens: const ['planning_day:dayplan-2026-05-25'],
            )
            as ScheduledWakeEntity;

    group('durable knowledge — retraction is terminal', () {
      test('a concurrent retract beats a concurrent edit, both directions', () {
        final retracted = knowledge(status: KnowledgeStatus.retracted);
        final confirmed = knowledge(status: KnowledgeStatus.confirmed);
        // Both replicas pick the retracted version → converge on retracted, so
        // a concurrent edit cannot revive deliberately-removed knowledge.
        expect(
          resolveConcurrentAgentEntityOverride(
            local: retracted,
            incoming: confirmed,
          ),
          ConcurrentWinner.local,
        );
        expect(
          resolveConcurrentAgentEntityOverride(
            local: confirmed,
            incoming: retracted,
          ),
          ConcurrentWinner.incoming,
        );
      });

      test('same-status conflicts defer to LWW (null)', () {
        expect(
          resolveConcurrentAgentEntityOverride(
            local: knowledge(status: KnowledgeStatus.confirmed),
            incoming: knowledge(status: KnowledgeStatus.confirmed, id: 'k2'),
          ),
          isNull,
        );
        expect(
          resolveConcurrentAgentEntityOverride(
            local: knowledge(status: KnowledgeStatus.retracted),
            incoming: knowledge(status: KnowledgeStatus.retracted, id: 'k2'),
          ),
          isNull,
        );
      });
    });

    group(
      'scheduled wake — later target wins, then consumption is terminal',
      () {
        final earlier = DateTime(2026, 5, 25, 9);
        final later = DateTime(2026, 5, 25, 18);

        test(
          'a pending re-arm to a later instant beats a consume of an earlier '
          'one, both directions',
          () {
            final rearm = wake(
              scheduledAt: later,
              status: ScheduledWakeStatus.pending,
            );
            final consumed = wake(
              scheduledAt: earlier,
              status: ScheduledWakeStatus.consumed,
            );
            expect(
              resolveConcurrentAgentEntityOverride(
                local: rearm,
                incoming: consumed,
              ),
              ConcurrentWinner.local,
            );
            expect(
              resolveConcurrentAgentEntityOverride(
                local: consumed,
                incoming: rearm,
              ),
              ConcurrentWinner.incoming,
            );
          },
        );

        test('consumption is terminal for one instant, both directions', () {
          // Deferring to LWW here was the bug this replaces: a peer that saw the
          // winning lease but missed the later `consumed` write can take over
          // past leaseUntil and stamp a fresh pending claim, whose younger
          // updatedAt would then defeat the completion — and it would bill a
          // second briefing for a window it already knew had finished.
          final pending = wake(
            scheduledAt: earlier,
            status: ScheduledWakeStatus.pending,
          );
          final consumed = wake(
            scheduledAt: earlier,
            status: ScheduledWakeStatus.consumed,
          );
          expect(
            resolveConcurrentAgentEntityOverride(
              local: pending,
              incoming: consumed,
            ),
            ConcurrentWinner.incoming,
          );
          expect(
            resolveConcurrentAgentEntityOverride(
              local: consumed,
              incoming: pending,
            ),
            ConcurrentWinner.local,
            reason: 'Both replicas must pick the consumed version to converge.',
          );
        });

        test('two same-status wakes at one instant still defer to LWW', () {
          expect(
            resolveConcurrentAgentEntityOverride(
              local: wake(
                scheduledAt: earlier,
                status: ScheduledWakeStatus.pending,
              ),
              incoming: wake(
                scheduledAt: earlier,
                status: ScheduledWakeStatus.pending,
                id: 'w2',
              ),
            ),
            isNull,
          );
        });
      },
    );

    test('defers to LWW for entity types without a monotonic rule', () {
      final state =
          AgentDomainEntity.agentState(
                id: 's1',
                agentId: 'a1',
                revision: 1,
                slots: const AgentSlots(),
                updatedAt: DateTime(2024),
                vectorClock: null,
              )
              as AgentStateEntity;
      expect(
        resolveConcurrentAgentEntityOverride(local: state, incoming: state),
        isNull,
      );
    });

    // Maps a winner verdict back to the physical entity it selects (or null).
    T? pick<T>(ConcurrentWinner? winner, T local, T incoming) => winner == null
        ? null
        : (winner == ConcurrentWinner.local ? local : incoming);

    glados.Glados2(
      glados.any.bool,
      glados.any.bool,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'knowledge: retraction is terminal and convergent regardless of arg '
      'order',
      (aRetracted, bRetracted) {
        final a = knowledge(
          status: aRetracted
              ? KnowledgeStatus.retracted
              : KnowledgeStatus.confirmed,
          id: 'a',
        );
        final b = knowledge(
          status: bRetracted
              ? KnowledgeStatus.retracted
              : KnowledgeStatus.confirmed,
          id: 'b',
        );
        // Both replicas (each holding one side as "local") must select the
        // SAME physical entry, or both defer — otherwise they diverge.
        final w1 = pick(
          resolveConcurrentAgentEntityOverride(local: a, incoming: b),
          a,
          b,
        );
        final w2 = pick(
          resolveConcurrentAgentEntityOverride(local: b, incoming: a),
          b,
          a,
        );
        expect(w1?.id, w2?.id, reason: 'must converge');
        if (aRetracted != bRetracted) {
          expect(w1?.id, (aRetracted ? a : b).id); // retracted side wins
        } else {
          expect(w1, isNull); // same status → defer to LWW
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(0, 8),
      glados.IntAnys(glados.any).intInRange(0, 8),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'scheduled wake: later scheduledAt wins, then consumed wins, convergent',
      (h1, h2) {
        final base = DateTime(2026, 5, 25);
        // Status differs deliberately: scheduledAt decides first, and status
        // only breaks a tie between the same instant.
        final a = wake(
          scheduledAt: base.add(Duration(hours: h1)),
          status: ScheduledWakeStatus.pending,
          id: 'a',
        );
        final b = wake(
          scheduledAt: base.add(Duration(hours: h2)),
          status: ScheduledWakeStatus.consumed,
          id: 'b',
        );
        final w1 = pick(
          resolveConcurrentAgentEntityOverride(local: a, incoming: b),
          a,
          b,
        );
        final w2 = pick(
          resolveConcurrentAgentEntityOverride(local: b, incoming: a),
          b,
          a,
        );
        expect(w1?.id, w2?.id, reason: 'must converge');
        if (h1 != h2) {
          expect(w1?.id, (h1 > h2 ? a : b).id); // later instant wins
        } else {
          // Same instant: `b` is the consumed one, and consumption is terminal
          // for a window — a late takeover claim must not revive it.
          expect(w1?.id, b.id);
        }
      },
      tags: 'glados',
    );

    group('day summary — earliest createdAt wins (testimony is canonical)', () {
      DaySummaryEntity summary({
        required DateTime createdAt,
        String id = 'day_agent_summary:dayplan-2026-06-08',
        String text = 'note',
      }) =>
          AgentDomainEntity.daySummary(
                id: id,
                agentId: 'a1',
                dayId: 'dayplan-2026-06-08',
                text: text,
                createdAt: createdAt,
                updatedAt: DateTime(2026, 6, 9),
                vectorClock: null,
              )
              as DaySummaryEntity;

      final contemporaneous = DateTime(2026, 6, 8, 22);
      final staleDevice = DateTime(2026, 6, 9, 9);

      test(
        'the earlier-created testimony beats a concurrent later rewrite, '
        'both directions',
        () {
          final original = summary(createdAt: contemporaneous);
          final lateRewrite = summary(createdAt: staleDevice, text: 'rewrite');
          expect(
            resolveConcurrentAgentEntityOverride(
              local: original,
              incoming: lateRewrite,
            ),
            ConcurrentWinner.local,
          );
          expect(
            resolveConcurrentAgentEntityOverride(
              local: lateRewrite,
              incoming: original,
            ),
            ConcurrentWinner.incoming,
          );
        },
      );

      test('a createdAt tie defers to LWW (null)', () {
        expect(
          resolveConcurrentAgentEntityOverride(
            local: summary(createdAt: contemporaneous),
            incoming: summary(createdAt: contemporaneous, text: 'other'),
          ),
          isNull,
        );
      });

      glados.Glados2(
        glados.IntAnys(glados.any).intInRange(0, 8),
        glados.IntAnys(glados.any).intInRange(0, 8),
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'earliest createdAt wins, convergent regardless of arg order; '
        'equal defers',
        (h1, h2) {
          final base = DateTime(2026, 6, 8, 12);
          final a = summary(
            createdAt: base.add(Duration(hours: h1)),
            id: 'a',
          );
          final b = summary(
            createdAt: base.add(Duration(hours: h2)),
            id: 'b',
          );
          final w1 = pick(
            resolveConcurrentAgentEntityOverride(local: a, incoming: b),
            a,
            b,
          );
          final w2 = pick(
            resolveConcurrentAgentEntityOverride(local: b, incoming: a),
            b,
            a,
          );
          expect(w1?.id, w2?.id, reason: 'must converge');
          if (h1 != h2) {
            expect(w1?.id, (h1 < h2 ? a : b).id);
          } else {
            expect(w1, isNull);
          }
        },
        tags: 'glados',
      );
    });
  });

  group('goal progress — the newer spec version wins the shared row', () {
    GoalProgressEntity register(String specVersionId) =>
        AgentDomainEntity.goalProgress(
              id: 'goal_progress:goal-1:2026-08-10',
              agentId: 'goal-1',
              periodKey: '2026-08-10',
              trackStatus: GoalTrackStatus.onTrack,
              attainment: 1,
              dataCoverage: 1,
              satisfied: true,
              specVersionId: specVersionId,
              createdAt: DateTime(2026, 8, 10),
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalProgressEntity;

    test('an offline v1 evaluation cannot replace the v2 row by LWW', () {
      final v1 = register('goal-1:spec-v1');
      final v2 = register('goal-1:spec-v2-9f2c1a08');
      expect(
        resolveConcurrentAgentEntityOverride(local: v2, incoming: v1),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(local: v1, incoming: v2),
        ConcurrentWinner.incoming,
      );
    });

    test('same-ordinal DIFFERENT ids pick a stable lexicographic winner — '
        'replicas agree, and the next tick recomputes under the real '
        'head', () {
      expect(
        resolveConcurrentAgentEntityOverride(
          local: register('goal-1:spec-v2-aa'),
          incoming: register('goal-1:spec-v2-bb'),
        ),
        ConcurrentWinner.incoming,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: register('goal-1:spec-v2-bb'),
          incoming: register('goal-1:spec-v2-aa'),
        ),
        ConcurrentWinner.local,
      );
    });

    test('identical spec ids defer to LWW (null)', () {
      expect(
        resolveConcurrentAgentEntityOverride(
          local: register('goal-1:spec-v2-aa'),
          incoming: register('goal-1:spec-v2-aa'),
        ),
        isNull,
      );
    });
  });

  group('goal spec head — owner intent wins same-version conflicts', () {
    GoalSpecHeadEntity head(String versionId) =>
        AgentDomainEntity.goalSpecHead(
              id: 'goal_spec_head:goal-1',
              agentId: 'goal-1',
              versionId: versionId,
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
            )
            as GoalSpecHeadEntity;

    test('an owner-authored v2 beats an agent-authored v2 both ways', () {
      final owner = head('goal-1:spec-v2-owner-aa');
      final agent = head('goal-1:spec-v2-bb');

      expect(
        resolveConcurrentAgentEntityOverride(local: owner, incoming: agent),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(local: agent, incoming: owner),
        ConcurrentWinner.incoming,
      );
    });

    test('a higher version still outranks an older owner revision', () {
      final ownerV2 = head('goal-1:spec-v2-owner-aa');
      final agentV3 = head('goal-1:spec-v3-bb');

      expect(
        resolveConcurrentAgentEntityOverride(
          local: ownerV2,
          incoming: agentV3,
        ),
        ConcurrentWinner.incoming,
      );
    });
  });

  group('goal nudge — dismissal is terminal', () {
    test('a concurrent dismissal beats any other status, both directions', () {
      final dismissed = goalNudge(status: NudgeStatus.dismissed);
      for (final other in [
        goalNudge(status: NudgeStatus.active),
        goalNudge(status: NudgeStatus.retired),
      ]) {
        expect(
          resolveConcurrentAgentEntityOverride(
            local: dismissed,
            incoming: other,
          ),
          ConcurrentWinner.local,
          reason: 'a re-activation must not revive a dismissed ad',
        );
        expect(
          resolveConcurrentAgentEntityOverride(
            local: other,
            incoming: dismissed,
          ),
          ConcurrentWinner.incoming,
        );
      }
    });

    test('a terminal status beats a concurrent NON-advancing live write — '
        'a stale exposure flush cannot revive a retired ad', () {
      for (final terminalStatus in [
        NudgeStatus.retired,
        NudgeStatus.expired,
        NudgeStatus.superseded,
        NudgeStatus.failed,
      ]) {
        final terminal = goalNudge(status: terminalStatus);
        final staleActive = goalNudge(status: NudgeStatus.active);
        expect(
          resolveConcurrentAgentEntityOverride(
            local: terminal,
            incoming: staleActive,
          ),
          ConcurrentWinner.local,
          reason: '$terminalStatus must dominate same-activation bookkeeping',
        );
        expect(
          resolveConcurrentAgentEntityOverride(
            local: staleActive,
            incoming: terminal,
          ),
          ConcurrentWinner.incoming,
        );
      }
    });

    test('a genuine reactivation — the activation count ADVANCED — beats a '
        'concurrent terminal write', () {
      final retired = goalNudge(status: NudgeStatus.retired);
      final rerun = goalNudge(
        status: NudgeStatus.active,
        activationCount: 2,
      );
      expect(
        resolveConcurrentAgentEntityOverride(local: retired, incoming: rerun),
        ConcurrentWinner.incoming,
      );
      expect(
        resolveConcurrentAgentEntityOverride(local: rerun, incoming: retired),
        ConcurrentWinner.local,
      );
    });

    test('two terminal (or two live) statuses defer to LWW (null)', () {
      expect(
        resolveConcurrentAgentEntityOverride(
          local: goalNudge(status: NudgeStatus.retired),
          incoming: goalNudge(status: NudgeStatus.expired),
        ),
        isNull,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: goalNudge(status: NudgeStatus.active),
          incoming: goalNudge(status: NudgeStatus.ready),
        ),
        isNull,
      );
    });

    test('supersession dominates a concurrent retirement — the revision '
        'sweep stays monotonic, the reuse library stays clean', () {
      final superseded = goalNudge(status: NudgeStatus.superseded);
      final retired = goalNudge(status: NudgeStatus.retired);
      expect(
        resolveConcurrentAgentEntityOverride(
          local: superseded,
          incoming: retired,
        ),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: retired,
          incoming: superseded,
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('supersession outranks even a HIGHER activation — an offline '
        'old-spec rerun cannot resurrect the banner beside the revised '
        'goal', () {
      final swept = goalNudge(status: NudgeStatus.superseded);
      final offlineRerun = goalNudge(
        status: NudgeStatus.active,
        activationCount: 3,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: swept,
          incoming: offlineRerun,
        ),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: offlineRerun,
          incoming: swept,
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('the higher activation wins whole-row selection — a bookkeeping '
        'write for the PREVIOUS run cannot stamp the rerun with its old '
        'deadline', () {
      final rerun = goalNudge(
        status: NudgeStatus.active,
        activationCount: 3,
      );
      final staleBookkeeping = goalNudge(
        status: NudgeStatus.active,
        activationCount: 2,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: rerun,
          incoming: staleBookkeeping,
        ),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: staleBookkeeping,
          incoming: rerun,
        ),
        ConcurrentWinner.incoming,
      );
    });
  });

  group('mergeGoalNudgeAccumulators', () {
    NudgeSnooze snooze(
      String id, {
      required int hour,
      required int durationHours,
    }) => NudgeSnooze(
      id: id,
      activation: 1,
      snoozedAt: DateTime.utc(2026, 8, 13, hour),
      snoozedUntil: DateTime.utc(
        2026,
        8,
        13,
        hour + durationHours,
      ),
      duration: nudgeBannerSnoozeDurationFor(
        Duration(hours: durationHours),
      ),
      durationMinutes: durationHours * 60,
      utcOffsetMinutes: 120,
    );

    NudgeRating rating(
      int activation, {
      int? value,
      bool skipped = false,
    }) => NudgeRating(
      activation: activation,
      ratedAt: DateTime(2026, 8, activation),
      rating: value,
      skipped: skipped,
    );

    NudgeDayDismissal dismissal(
      String id, {
      required int hour,
    }) => NudgeDayDismissal(
      id: id,
      activation: 1,
      dismissedAt: DateTime.utc(2026, 8, 13, hour),
      dismissedUntil: DateTime.utc(2026, 8, 13, 22),
      utcOffsetMinutes: 120,
    );

    test('joins exposure counters, unions ratings and widens watermarks — '
        "no device's outcome is ever lost", () {
      final local = goalNudge(
        status: NudgeStatus.active,
        visibleMs: const GCounter({'phone': 4000}),
        impressions: const GCounter({'phone': 3}),
        ratings: [rating(1, value: 5)],
        activationCount: 2,
        firstShownAt: DateTime(2026, 8),
        lastShownAt: DateTime(2026, 8, 3),
      );
      final incoming = goalNudge(
        status: NudgeStatus.active,
        visibleMs: const GCounter({'phone': 1000, 'desktop': 9000}),
        impressions: const GCounter({'desktop': 7}),
        ratings: [rating(1, value: 5), rating(2, skipped: true)],
        activationCount: 3,
        firstShownAt: DateTime(2026, 8, 2),
        lastShownAt: DateTime(2026, 8, 5),
      );

      final merged = mergeGoalNudgeAccumulators(
        winner: local,
        local: local,
        incoming: incoming,
      );
      expect(
        merged.totalVisibleMs.byHost,
        {'phone': 4000, 'desktop': 9000},
        reason: 'element-wise max — the CRDT join',
      );
      expect(merged.impressionCount.value, 10);
      expect(merged.ratings, [rating(1, value: 5), rating(2, skipped: true)]);
      expect(merged.activationCount, 3);
      expect(merged.firstShownAt, DateTime(2026, 8));
      expect(merged.lastShownAt, DateTime(2026, 8, 5));
    });

    test('concurrent outcomes for ONE activation collapse to a single '
        'deterministic entry on both replicas — a run is never counted '
        'twice', () {
      final skippedEntry = NudgeRating(
        activation: 1,
        ratedAt: DateTime(2026, 8, 2, 9),
        skipped: true,
      );
      final rated = NudgeRating(
        activation: 1,
        ratedAt: DateTime(2026, 8, 2, 10),
        rating: 3,
      );
      final a = goalNudge(status: NudgeStatus.active, ratings: [rated]);
      final b = goalNudge(
        status: NudgeStatus.active,
        ratings: [skippedEntry],
      );
      final ab = mergeGoalNudgeAccumulators(winner: a, local: a, incoming: b);
      final ba = mergeGoalNudgeAccumulators(winner: a, local: b, incoming: a);
      expect(
        ab.ratings,
        [skippedEntry],
        reason: 'the EARLIEST outcome wins — one per activation',
      );
      expect(ab.ratings, ba.ratings);

      // A full tie (same instant) breaks on the remaining total order:
      // skipped=false sorts first, then the lower rating value.
      final at = DateTime(2026, 8, 2, 9);
      final low = NudgeRating(activation: 2, ratedAt: at, rating: 2);
      final high = NudgeRating(activation: 2, ratedAt: at, rating: 5);
      final c = goalNudge(status: NudgeStatus.active, ratings: [low]);
      final d = goalNudge(status: NudgeStatus.active, ratings: [high]);
      final cd = mergeGoalNudgeAccumulators(winner: c, local: c, incoming: d);
      final dc = mergeGoalNudgeAccumulators(winner: c, local: d, incoming: c);
      expect(cd.ratings, [low]);
      expect(cd.ratings, dc.ratings);
    });

    test('is symmetric: swapping local/incoming converges on the same '
        'accumulators', () {
      final a = goalNudge(
        status: NudgeStatus.active,
        visibleMs: const GCounter({'phone': 4000}),
        ratings: [rating(1, value: 3)],
      );
      final b = goalNudge(
        status: NudgeStatus.retired,
        visibleMs: const GCounter({'desktop': 2000}),
        ratings: [rating(2, value: 5)],
        activationCount: 2,
        lastShownAt: DateTime(2026, 8, 4),
      );
      final ab = mergeGoalNudgeAccumulators(winner: a, local: a, incoming: b);
      final ba = mergeGoalNudgeAccumulators(winner: a, local: b, incoming: a);
      expect(ab.totalVisibleMs.byHost, ba.totalVisibleMs.byHost);
      expect(ab.ratings, ba.ratings);
      expect(ab.activationCount, ba.activationCount);
      expect(ab.lastShownAt, ba.lastShownAt);
    });

    test(
      'unions snooze history and keeps the later effective quiet deadline',
      () {
        final short = snooze('short', hour: 10, durationHours: 1);
        final long = snooze('long', hour: 9, durationHours: 8);
        final local = goalNudge(
          status: NudgeStatus.active,
          snoozedUntil: short.snoozedUntil,
          lastSnoozeDuration: short.duration,
          snoozeHistory: [short],
          staleAt: DateTime.utc(2026, 8, 14, 11),
        );
        final incoming = goalNudge(
          status: NudgeStatus.active,
          snoozedUntil: long.snoozedUntil,
          lastSnoozeDuration: long.duration,
          snoozeHistory: [long],
          dismissedForDayAt: DateTime.utc(2026, 8, 13, 11),
          staleAt: DateTime.utc(2026, 8, 16, 17),
        );

        final ab = mergeGoalNudgeAccumulators(
          winner: local,
          local: local,
          incoming: incoming,
        );
        final ba = mergeGoalNudgeAccumulators(
          winner: local,
          local: incoming,
          incoming: local,
        );

        expect(
          [for (final event in ab.snoozeHistory) event.id],
          ['long', 'short'],
        );
        expect(ab.snoozedUntil, long.snoozedUntil);
        expect(ab.lastSnoozeDuration, NudgeBannerSnoozeDuration.eightHours);
        expect(ab.dismissedForDayAt, DateTime.utc(2026, 8, 13, 11));
        expect(
          ab.staleAt,
          DateTime.utc(2026, 8, 16, 17),
          reason: 'the selected later reveal keeps its branch lifetime',
        );
        expect(ab.snoozeHistory, ba.snoozeHistory);
        expect(ab.snoozedUntil, ba.snoozedUntil);
      },
    );

    test('same-id snooze conflicts use every field as a deterministic '
        'tie-breaker', () {
      final baseline = snooze('same-id', hour: 10, durationHours: 3);

      NudgeSnooze selected(
        NudgeSnooze a,
        NudgeSnooze b,
      ) {
        final local = goalNudge(
          status: NudgeStatus.active,
          snoozeHistory: [a],
        );
        final incoming = goalNudge(
          status: NudgeStatus.active,
          snoozeHistory: [b],
        );
        return mergeGoalNudgeAccumulators(
          winner: local,
          local: local,
          incoming: incoming,
        ).snoozeHistory.single;
      }

      final earlierStart = baseline.copyWith(
        snoozedAt: baseline.snoozedAt.subtract(const Duration(minutes: 1)),
      );
      expect(selected(baseline, earlierStart), earlierStart);

      final earlierReturn = baseline.copyWith(
        snoozedUntil: baseline.snoozedUntil.subtract(
          const Duration(minutes: 1),
        ),
      );
      expect(selected(baseline, earlierReturn), earlierReturn);

      final laterActivation = baseline.copyWith(activation: 2);
      expect(selected(laterActivation, baseline), baseline);

      final laterPreset = baseline.copyWith(
        duration: NudgeBannerSnoozeDuration.sixHours,
      );
      expect(selected(laterPreset, baseline), baseline);

      final longerMinutes = baseline.copyWith(durationMinutes: 181);
      expect(selected(longerMinutes, baseline), baseline);

      final laterOffset = baseline.copyWith(utcOffsetMinutes: 180);
      expect(selected(laterOffset, baseline), baseline);

      final laterReturnOffset = baseline.copyWith(
        returnUtcOffsetMinutes: 180,
      );
      expect(selected(laterReturnOffset, baseline), laterReturnOffset);

      final explicitReturnOffset = baseline.copyWith(
        returnUtcOffsetMinutes: baseline.utcOffsetMinutes,
      );
      expect(
        selected(baseline, explicitReturnOffset),
        explicitReturnOffset,
        reason: 'explicit offset evidence must beat a legacy absent value',
      );

      expect(
        selected(laterReturnOffset, explicitReturnOffset),
        explicitReturnOffset,
        reason: 'two explicit offsets retain their numeric total order',
      );

      // Codex review on #4356: an older client re-serializes the event
      // without its reason; both replicas must keep the reasoned copy,
      // whichever side it arrives on.
      final opened = baseline.copyWith(reason: NudgeSnoozeReason.opened);
      expect(selected(baseline, opened), opened);
      expect(selected(opened, baseline), opened);
      final chosen = baseline.copyWith(reason: NudgeSnoozeReason.chosen);
      expect(selected(opened, chosen), chosen);
      expect(selected(chosen, opened), chosen);
    });

    test('unions day-dismissal history by id and converges on conflicting '
        'copies', () {
      final earlier = dismissal('same-id', hour: 10);
      final conflictingCopy = earlier.copyWith(
        dismissedAt: DateTime.utc(2026, 8, 13, 12),
      );
      final other = dismissal('other-id', hour: 11);
      final local = goalNudge(
        status: NudgeStatus.active,
        dismissalHistory: [earlier],
      );
      final incoming = goalNudge(
        status: NudgeStatus.active,
        dismissalHistory: [other, conflictingCopy],
      );

      final ab = mergeGoalNudgeAccumulators(
        winner: local,
        local: local,
        incoming: incoming,
      );
      final ba = mergeGoalNudgeAccumulators(
        winner: local,
        local: incoming,
        incoming: local,
      );

      expect(ab.dismissalHistory, [earlier, other]);
      expect(ba.dismissalHistory, ab.dismissalHistory);
    });
  });

  RelationshipNudgeEntity relationshipNudge({
    required NudgeStatus status,
    String id = 'rn1',
    List<NudgeRating> ratings = const [],
    GCounter visibleMs = const GCounter.empty(),
    GCounter impressions = const GCounter.empty(),
    int activationCount = 1,
    VectorClock? vectorClock,
    DateTime? firstShownAt,
    DateTime? lastShownAt,
    DateTime? staleAt,
    DateTime? snoozedUntil,
    NudgeBannerSnoozeDuration? lastSnoozeDuration,
    List<NudgeSnooze> snoozeHistory = const [],
    DateTime? dismissedForDayAt,
    List<NudgeDayDismissal> dismissalHistory = const [],
  }) =>
      AgentDomainEntity.relationshipNudge(
            id: id,
            agentId: 'ra1',
            status: status,
            brief: const NudgeBrief(
              headline: 'Check in with Anna — five weeks.',
              tone: NudgeTone.nudge,
              animation: NudgeBannerAnimation.steady,
            ),
            briefDigest: 'digest-r1',
            createdAt: DateTime(2026, 8),
            updatedAt: DateTime(2026, 8),
            vectorClock: vectorClock,
            ratings: ratings,
            totalVisibleMs: visibleMs,
            impressionCount: impressions,
            activationCount: activationCount,
            firstShownAt: firstShownAt,
            lastShownAt: lastShownAt,
            staleAt: staleAt,
            snoozedUntil: snoozedUntil,
            lastSnoozeDuration: lastSnoozeDuration,
            snoozeHistory: snoozeHistory,
            dismissedForDayAt: dismissedForDayAt,
            dismissalHistory: dismissalHistory,
          )
          as RelationshipNudgeEntity;

  group('relationship nudge — the shared lifecycle rules, applied '
      'per-variant (ADR 0059)', () {
    test('dismissal is terminal, both directions', () {
      final dismissed = relationshipNudge(status: NudgeStatus.dismissed);
      final active = relationshipNudge(status: NudgeStatus.active);
      expect(
        resolveConcurrentAgentEntityOverride(
          local: dismissed,
          incoming: active,
        ),
        ConcurrentWinner.local,
        reason: 'a re-activation must not revive a dismissed banner',
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: active,
          incoming: dismissed,
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('supersession outranks even a higher activation', () {
      final swept = relationshipNudge(status: NudgeStatus.superseded);
      final offlineRerun = relationshipNudge(
        status: NudgeStatus.active,
        activationCount: 3,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: swept,
          incoming: offlineRerun,
        ),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: offlineRerun,
          incoming: swept,
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('the higher activation wins whole-row selection', () {
      final rerun = relationshipNudge(
        status: NudgeStatus.active,
        activationCount: 2,
      );
      final staleBookkeeping = relationshipNudge(
        status: NudgeStatus.active,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: rerun,
          incoming: staleBookkeeping,
        ),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: staleBookkeeping,
          incoming: rerun,
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('a terminal status beats a same-activation live write; two live '
        'writes defer to LWW', () {
      final retired = relationshipNudge(status: NudgeStatus.retired);
      final active = relationshipNudge(status: NudgeStatus.active);
      expect(
        resolveConcurrentAgentEntityOverride(local: retired, incoming: active),
        ConcurrentWinner.local,
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: relationshipNudge(status: NudgeStatus.active),
          incoming: relationshipNudge(status: NudgeStatus.ready),
        ),
        isNull,
      );
    });

    test('a cross-variant id collision has no monotonic rule — defers to '
        'LWW (null)', () {
      // Same id, different nudge kinds: neither per-variant branch matches,
      // so the pair falls through to the generic path instead of one kind's
      // rules being misapplied to the other.
      final goal = goalNudge(status: NudgeStatus.dismissed, id: 'same-id');
      final relationship = relationshipNudge(
        status: NudgeStatus.active,
        id: 'same-id',
      );
      expect(
        resolveConcurrentAgentEntityOverride(
          local: goal,
          incoming: relationship,
        ),
        isNull,
      );
      // Both orders: each per-variant branch guards `local is X && incoming
      // is X`, so a half-written condition (`local is RelationshipNudge &&
      // incoming is GoalNudge`) would still satisfy a one-sided assertion.
      expect(
        resolveConcurrentAgentEntityOverride(
          local: relationship,
          incoming: goal,
        ),
        isNull,
      );
    });
  });

  group('mergeRelationshipNudgeAccumulators', () {
    test('projects every accumulator field through the shared merge and '
        'back — counters joined, histories unioned, watermarks widened, '
        'clocks joined', () {
      final snoozeEvent = NudgeSnooze(
        id: 'snooze-1',
        activation: 1,
        snoozedAt: DateTime.utc(2026, 8, 13, 10),
        snoozedUntil: DateTime.utc(2026, 8, 13, 13),
        duration: NudgeBannerSnoozeDuration.threeHours,
        durationMinutes: 180,
        utcOffsetMinutes: 120,
      );
      final dismissalEvent = NudgeDayDismissal(
        id: 'dismiss-1',
        activation: 1,
        dismissedAt: DateTime.utc(2026, 8, 13, 18),
        dismissedUntil: DateTime.utc(2026, 8, 13, 22),
        utcOffsetMinutes: 120,
      );
      final local = relationshipNudge(
        status: NudgeStatus.active,
        vectorClock: const VectorClock({'phone': 4}),
        visibleMs: const GCounter({'phone': 4000}),
        impressions: const GCounter({'phone': 3}),
        ratings: [
          NudgeRating(activation: 1, ratedAt: DateTime(2026, 8), rating: 5),
        ],
        snoozeHistory: [snoozeEvent],
        snoozedUntil: DateTime.utc(2026, 8, 13, 13),
        lastSnoozeDuration: NudgeBannerSnoozeDuration.threeHours,
        staleAt: DateTime(2026, 8, 4),
        firstShownAt: DateTime(2026, 8),
        lastShownAt: DateTime(2026, 8, 3),
      );
      final incoming = relationshipNudge(
        status: NudgeStatus.active,
        vectorClock: const VectorClock({'desktop': 2}),
        visibleMs: const GCounter({'phone': 1000, 'desktop': 9000}),
        impressions: const GCounter({'desktop': 7}),
        dismissalHistory: [dismissalEvent],
        dismissedForDayAt: DateTime.utc(2026, 8, 13, 18),
        staleAt: DateTime(2026, 8, 5),
        firstShownAt: DateTime(2026, 8, 2),
        lastShownAt: DateTime(2026, 8, 5),
      );

      final merged = mergeRelationshipNudgeAccumulators(
        winner: local,
        local: local,
        incoming: incoming,
      );

      expect(merged.totalVisibleMs.byHost, {'phone': 4000, 'desktop': 9000});
      expect(merged.impressionCount.value, 10);
      expect(merged.ratings.single.rating, 5);
      expect(merged.snoozeHistory, [snoozeEvent]);
      expect(merged.snoozedUntil, DateTime.utc(2026, 8, 13, 13));
      expect(
        merged.lastSnoozeDuration,
        NudgeBannerSnoozeDuration.threeHours,
      );
      expect(merged.dismissalHistory, [dismissalEvent]);
      expect(merged.dismissedForDayAt, DateTime.utc(2026, 8, 13, 18));
      expect(merged.staleAt, DateTime(2026, 8, 5));
      expect(merged.firstShownAt, DateTime(2026, 8));
      expect(merged.lastShownAt, DateTime(2026, 8, 5));
      expect(
        merged.vectorClock,
        const VectorClock({'phone': 4, 'desktop': 2}),
        reason: 'the merged row observed both branches — clock join',
      );
      // Non-accumulator fields stay the winner's.
      expect(merged.status, NudgeStatus.active);
      expect(merged.agentId, 'ra1');
    });

    test('is symmetric: swapping local/incoming converges', () {
      final a = relationshipNudge(
        status: NudgeStatus.active,
        visibleMs: const GCounter({'phone': 4000}),
        ratings: [
          NudgeRating(activation: 1, ratedAt: DateTime(2026, 8), rating: 3),
        ],
      );
      final b = relationshipNudge(
        status: NudgeStatus.retired,
        visibleMs: const GCounter({'desktop': 500}),
        ratings: [
          NudgeRating(
            activation: 1,
            ratedAt: DateTime(2026, 8, 2),
            skipped: true,
          ),
        ],
      );
      final ab = mergeRelationshipNudgeAccumulators(
        winner: b,
        local: a,
        incoming: b,
      );
      final ba = mergeRelationshipNudgeAccumulators(
        winner: b,
        local: b,
        incoming: a,
      );
      expect(ab.totalVisibleMs, ba.totalVisibleMs);
      expect(ab.ratings, ba.ratings);
      expect(ab.ratings.single.rating, 3, reason: 'earliest outcome wins');
    });
  });

  group('resolveIncomingChangeSet — item-level merge (ADR 0067)', () {
    const estimate = ChangeItem(
      toolName: 'update_task_estimate',
      args: {'minutes': 30},
      humanSummary: 'Set estimate',
    );
    const title = ChangeItem(
      toolName: 'set_task_title',
      args: {'title': 'T'},
      humanSummary: 'Set title',
    );
    final created = DateTime(2026, 9);

    ChangeSetEntity changeSet(
      List<ChangeItem> items,
      Map<String, int> clock, {
      ChangeSetStatus? status,
      DateTime? resolvedAt,
      DateTime? deletedAt,
    }) =>
        AgentDomainEntity.changeSet(
              id: 'cs',
              agentId: 'a1',
              taskId: 't1',
              threadId: 'th',
              runKey: 'rk',
              status: status ?? ChangeItem.deriveSetStatus(items),
              items: items,
              createdAt: created,
              vectorClock: VectorClock(clock),
              resolvedAt: resolvedAt,
              deletedAt: deletedAt,
            )
            as ChangeSetEntity;

    test(
      'decisions made concurrently on two devices both survive, on both',
      () {
        // Device A confirmed (and applied) the estimate while device B
        // rejected the title, both from the same pending set. A whole-row
        // winner dropped one of them: the applied estimate could read
        // pending again everywhere and be confirmed a second time.
        final onA = changeSet(
          [
            estimate.withStatus(ChangeItemStatus.confirmed),
            title,
          ],
          {'a': 2},
        );
        final onB = changeSet(
          [
            estimate,
            title.withStatus(ChangeItemStatus.rejected),
          ],
          {'a': 1, 'b': 1},
        );

        final atA = resolveIncomingChangeSet(local: onA, incoming: onB)!;
        final atB = resolveIncomingChangeSet(local: onB, incoming: onA)!;

        expect(atA.items.map((i) => i.status), [
          ChangeItemStatus.confirmed,
          ChangeItemStatus.rejected,
        ]);
        expect(atA.status, ChangeSetStatus.resolved);
        expect(atA.resolvedAt, created, reason: 'neither had resolved it');
        expect(atA.vectorClock, const VectorClock({'a': 2, 'b': 1}));
        expect(atB, atA, reason: 'both devices converge on one row');
      },
    );

    test('a confirm beats a concurrent rejection or retraction', () {
      for (final other in [
        ChangeItemStatus.rejected,
        ChangeItemStatus.retracted,
        ChangeItemStatus.pending,
      ]) {
        final confirmed = changeSet(
          [
            estimate.withStatus(ChangeItemStatus.confirmed),
          ],
          {'a': 2},
        );
        final decided = changeSet(
          [
            estimate.withStatus(other),
          ],
          {'a': 1, 'b': 1},
        );

        for (final merged in [
          resolveIncomingChangeSet(local: confirmed, incoming: decided),
          resolveIncomingChangeSet(local: decided, incoming: confirmed),
        ]) {
          expect(merged!.items.single.status, ChangeItemStatus.confirmed);
        }
      }
    });

    test(
      'the later revision wins: a revert beats the claim a peer carried',
      () {
        // A claimed the estimate (revision 1), B received that claim and then
        // rejected the title; meanwhile A's dispatch failed and reverted the
        // estimate (revision 2). The revert must win, or the estimate would
        // read confirmed although it never took effect.
        final onA = changeSet(
          [
            estimate
                .withStatus(ChangeItemStatus.confirmed)
                .withStatus(ChangeItemStatus.pending),
            title,
          ],
          {'a': 3},
        );
        final onB = changeSet(
          [
            estimate.withStatus(ChangeItemStatus.confirmed),
            title.withStatus(ChangeItemStatus.rejected),
          ],
          {'a': 2, 'b': 1},
        );

        final merged = resolveIncomingChangeSet(local: onA, incoming: onB)!;

        expect(merged.items[0].status, ChangeItemStatus.pending);
        expect(merged.items[0].revision, 2);
        expect(merged.items[1].status, ChangeItemStatus.rejected);
        expect(merged.status, ChangeSetStatus.partiallyResolved);
        expect(merged.resolvedAt, isNull);
      },
    );

    test(
      "a newer build's target rewrite survives an older build's untouched "
      'copy of the pending item',
      () {
        // Both versions leave the migration pending. The newer build
        // rewrote its target to the created task; the older build's copy,
        // without a revision, still names the placeholder. Whichever version
        // wins the whole row, the rewrite must survive, or the migration
        // stays blocked behind a placeholder whose task already exists.
        const migration = ChangeItem(
          toolName: 'migrate_checklist_item',
          args: {'id': 'c1', 'targetTaskId': 'placeholder'},
          humanSummary: 'Move item',
        );
        final rewritten = migration.withArgs({
          'id': 'c1',
          'targetTaskId': 'task-1',
        });
        // Clocks chosen so each side wins the whole-row order once.
        for (final (newerClock, olderClock) in [
          ({'new': 2}, {'new': 1, 'old': 1}),
          ({'a': 1, 'new': 1}, {'a': 2}),
        ]) {
          final onNewer = changeSet([rewritten], newerClock);
          final onOlder = changeSet([migration], olderClock);
          for (final merged in [
            resolveIncomingChangeSet(local: onNewer, incoming: onOlder)!,
            resolveIncomingChangeSet(local: onOlder, incoming: onNewer)!,
          ]) {
            expect(merged.items.single, rewritten);
          }
        }
      },
    );

    test(
      "an older build's confirm survives a newer build's later revision",
      () {
        // An older build drops `revision` when it rewrites the set. Here the
        // newer build rewrote the migration's target (revision 1, still
        // pending) while the older build confirmed and applied it: compared
        // as revision 0, the pending rewrite won and the applied migration
        // was open to be applied again. Without a revision on one side, the
        // status decides.
        const migration = ChangeItem(
          toolName: 'migrate_checklist_item',
          args: {'id': 'c1', 'targetTaskId': 'placeholder'},
          humanSummary: 'Move item',
        );
        final onNewer = changeSet(
          [
            migration.withArgs({'id': 'c1', 'targetTaskId': 'task-1'}),
          ],
          {'new': 2},
        );
        final onOlder = changeSet(
          [
            migration.copyWith(status: ChangeItemStatus.confirmed),
          ],
          {'new': 1, 'old': 1},
        );

        for (final merged in [
          resolveIncomingChangeSet(local: onNewer, incoming: onOlder)!,
          resolveIncomingChangeSet(local: onOlder, incoming: onNewer)!,
        ]) {
          expect(merged.items.single.status, ChangeItemStatus.confirmed);
          expect(merged.items.single.revision, isNull);
        }
      },
    );

    test('the migration target rewrite travels with its revision', () {
      final rewritten = estimate.withArgs({'minutes': 30, 'extra': true});
      final onA = changeSet([rewritten, title], {'a': 2});
      final onB = changeSet(
        [
          estimate,
          title.withStatus(ChangeItemStatus.confirmed),
        ],
        {'a': 1, 'b': 1},
      );

      final merged = resolveIncomingChangeSet(local: onB, incoming: onA)!;

      expect(merged.items[0].args, {'minutes': 30, 'extra': true});
      expect(merged.items[1].status, ChangeItemStatus.confirmed);
    });

    test('equal revision and status: the whole-row winner decides', () {
      final onA = changeSet(
        [
          estimate.withArgs({'minutes': 45}),
        ],
        {'a': 2},
      );
      final onB = changeSet(
        [
          estimate.withArgs({'minutes': 60}),
        ],
        {'a': 1, 'b': 1},
      );

      // The canonical clock order picks A (host a, counter 2 > 1).
      expect(
        resolveIncomingChangeSet(local: onA, incoming: onB)!.items.single.args,
        {'minutes': 45},
      );
      expect(
        resolveIncomingChangeSet(local: onB, incoming: onA)!.items.single.args,
        {'minutes': 45},
      );
    });

    test('keeps items only one version appended', () {
      final onA = changeSet(
        [
          estimate.withStatus(ChangeItemStatus.confirmed),
        ],
        {'a': 2},
      );
      final onB = changeSet([estimate, title], {'a': 1, 'b': 1});

      final merged = resolveIncomingChangeSet(local: onA, incoming: onB)!;

      expect(merged.items, [onA.items.single, title]);
      expect(merged.status, ChangeSetStatus.partiallyResolved);
    });

    test('two closed versions keep the winner status', () {
      // A row retired before retirement retracted its pending items must not
      // reopen by merging.
      final onA = changeSet(
        [estimate],
        {'a': 2},
        status: ChangeSetStatus.resolved,
        resolvedAt: DateTime(2026, 9, 2),
      );
      final onB = changeSet(
        [estimate],
        {'a': 1, 'b': 1},
        status: ChangeSetStatus.resolved,
        resolvedAt: DateTime(2026, 9, 3),
      );

      final merged = resolveIncomingChangeSet(local: onA, incoming: onB)!;

      expect(merged.status, ChangeSetStatus.resolved);
      expect(merged.resolvedAt, DateTime(2026, 9, 3), reason: 'the later');
    });

    test('causal order decides before any merge', () {
      final older = changeSet([estimate], {'a': 1});
      final newer = changeSet(
        [
          estimate.withStatus(ChangeItemStatus.confirmed),
        ],
        {'a': 2},
      );

      expect(resolveIncomingChangeSet(local: newer, incoming: older), isNull);
      expect(resolveIncomingChangeSet(local: newer, incoming: newer), isNull);
      expect(
        resolveIncomingChangeSet(local: older, incoming: newer),
        same(newer),
      );
    });

    test('a missing or invalid clock applies the incoming version', () {
      final local = changeSet([estimate], {'a': 1});
      final incoming = changeSet([estimate], {'b': 1});

      expect(
        resolveIncomingChangeSet(
          local: local.copyWith(vectorClock: null),
          incoming: incoming,
        ),
        same(incoming),
      );
      expect(
        resolveIncomingChangeSet(
          local: local.copyWith(vectorClock: const VectorClock({'a': -1})),
          incoming: incoming,
        ),
        same(incoming),
      );
    });

    test(
      'falls back to the whole-row winner when the versions do not align',
      () {
        // Different proposals at one index, or a tombstone: nothing to merge
        // item by item.
        final onA = changeSet([estimate], {'a': 2});
        final misaligned = changeSet([title], {'a': 1, 'b': 1});
        final deleted = changeSet(
          [estimate],
          {'a': 1, 'b': 1},
          deletedAt: DateTime(2026, 9, 4),
        );

        // A wins the canonical order: keep local, or apply A as incoming.
        expect(
          resolveIncomingChangeSet(local: onA, incoming: misaligned),
          isNull,
        );
        expect(
          resolveIncomingChangeSet(local: misaligned, incoming: onA),
          same(onA),
        );
        expect(resolveIncomingChangeSet(local: onA, incoming: deleted), isNull);
        expect(
          mergeConcurrentChangeSets(
            local: onA,
            incoming: deleted,
            winner: ConcurrentWinner.local,
          ),
          isNull,
        );
      },
    );

    glados.Glados2(
      glados.any.list(glados.any.intInRange(0, 6)),
      glados.any.list(glados.any.intInRange(0, 6)),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'merging concurrent histories converges and never loses a confirm the '
      'other side did not supersede',
      (opsA, opsB) {
        // Two devices apply generated status changes to one two-item set
        // from the same base; each op is (item, target status).
        final base = changeSet([estimate, title], {'base': 1});
        const statuses = [
          ChangeItemStatus.pending,
          ChangeItemStatus.confirmed,
          ChangeItemStatus.rejected,
        ];
        ChangeSetEntity run(List<int> ops, String host) {
          var set = base;
          var counter = 0;
          for (final op in ops) {
            final index = op % 2;
            final items = [...set.items];
            items[index] = items[index].withStatus(statuses[op ~/ 2]);
            counter++;
            set = changeSet(items, {'base': 1, host: counter});
          }
          return set;
        }

        final onA = run(opsA, 'a');
        final onB = run(opsB, 'b');
        final atA = resolveIncomingChangeSet(local: onA, incoming: onB) ?? onA;
        final atB = resolveIncomingChangeSet(local: onB, incoming: onA) ?? onB;

        expect(atA, atB, reason: 'converged');
        for (var i = 0; i < 2; i++) {
          final a = onA.items[i];
          final b = onB.items[i];
          final kept = atA.items[i];
          // The side that changed the item last wins it outright. An item
          // a side never touched carries no revision and is judged by
          // status.
          final ra = a.revision;
          final rb = b.revision;
          if (ra != null && rb != null && ra != rb) {
            expect(kept, ra > rb ? a : b);
          } else if (a.status == ChangeItemStatus.confirmed ||
              b.status == ChangeItemStatus.confirmed) {
            expect(kept.status, ChangeItemStatus.confirmed);
          }
        }
      },
      tags: 'glados',
    );
  });
}
