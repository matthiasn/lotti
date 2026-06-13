import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';

void main() {
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

    group('scheduled wake — future reschedule beats past consume', () {
      final earlier = DateTime(2026, 5, 25, 9);
      final later = DateTime(2026, 5, 25, 18);

      test('a pending re-arm to a later instant beats a consume of an earlier '
          'one, both directions', () {
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
      });

      test('a same-instant conflict defers to LWW so a fired wake is never '
          'resurrected (null → no double-fire)', () {
        expect(
          resolveConcurrentAgentEntityOverride(
            local: wake(
              scheduledAt: earlier,
              status: ScheduledWakeStatus.pending,
            ),
            incoming: wake(
              scheduledAt: earlier,
              status: ScheduledWakeStatus.consumed,
            ),
          ),
          isNull,
        );
      });
    });

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
      'scheduled wake: the later scheduledAt wins, convergent; equal defers',
      (h1, h2) {
        final base = DateTime(2026, 5, 25);
        // Status differs deliberately — the rule keys on scheduledAt only.
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
          expect(w1, isNull); // same instant → defer to LWW (no double-fire)
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
}
