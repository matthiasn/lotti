import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/sync/g_counter.dart';

void main() {
  GoalNudgeEntity goalNudge({
    required GoalNudgeStatus status,
    String id = 'n1',
    List<GoalNudgeRating> ratings = const [],
    GCounter visibleMs = const GCounter.empty(),
    GCounter impressions = const GCounter.empty(),
    int activationCount = 1,
    DateTime? firstShownAt,
    DateTime? lastShownAt,
  }) =>
      AgentDomainEntity.goalNudge(
            id: id,
            agentId: 'a1',
            status: status,
            brief: const GoalNudgeBrief(
              headline: 'Your shoes filed a missing person report.',
              tone: GoalNudgeTone.nudge,
              animation: GoalBannerAnimation.pulse,
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

  group('goal nudge — dismissal is terminal', () {
    test('a concurrent dismissal beats any other status, both directions', () {
      final dismissed = goalNudge(status: GoalNudgeStatus.dismissed);
      for (final other in [
        goalNudge(status: GoalNudgeStatus.active),
        goalNudge(status: GoalNudgeStatus.retired),
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

    test('same-dismissal-state conflicts defer to LWW (null)', () {
      expect(
        resolveConcurrentAgentEntityOverride(
          local: goalNudge(status: GoalNudgeStatus.active),
          incoming: goalNudge(status: GoalNudgeStatus.retired),
        ),
        isNull,
      );
    });
  });

  group('mergeGoalNudgeAccumulators', () {
    GoalNudgeRating rating(
      int activation, {
      int? value,
      bool skipped = false,
    }) => GoalNudgeRating(
      activation: activation,
      ratedAt: DateTime(2026, 8, activation),
      rating: value,
      skipped: skipped,
    );

    test('joins exposure counters, unions ratings and widens watermarks — '
        "no device's outcome is ever lost", () {
      final local = goalNudge(
        status: GoalNudgeStatus.active,
        visibleMs: const GCounter({'phone': 4000}),
        impressions: const GCounter({'phone': 3}),
        ratings: [rating(1, value: 5)],
        activationCount: 2,
        firstShownAt: DateTime(2026, 8),
        lastShownAt: DateTime(2026, 8, 3),
      );
      final incoming = goalNudge(
        status: GoalNudgeStatus.active,
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

    test('is symmetric: swapping local/incoming converges on the same '
        'accumulators', () {
      final a = goalNudge(
        status: GoalNudgeStatus.active,
        visibleMs: const GCounter({'phone': 4000}),
        ratings: [rating(1, value: 3)],
      );
      final b = goalNudge(
        status: GoalNudgeStatus.retired,
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
  });
}
