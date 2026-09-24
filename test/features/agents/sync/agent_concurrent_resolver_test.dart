import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'agent_concurrent_resolver_test_helpers.dart';

void main() {
  group('resolveConcurrent — properties', () {
    glados.Glados(
      glados.any.resolverScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('newer updatedAt wins; equal falls to the greater clock', (s) {
      // local is the canonically-greater clock, so it wins ties on updatedAt.
      final expected = s.incomingUpdatedAt.isAfter(s.localUpdatedAt)
          ? ConcurrentWinner.incoming
          : ConcurrentWinner.local;

      expect(hResolve(s), expected, reason: '$s');
    }, tags: 'glados');

    glados.Glados(
      glados.any.resolverScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('selects the same physical version regardless of arg order', (s) {
      // Device 1 holds the "local" version and receives "incoming".
      final winner1 = hResolve(s) == ConcurrentWinner.local
          ? 'localSide'
          : 'incomingSide';
      // Device 2 holds the "incoming" version and receives "local" (swapped).
      final swapped = resolveConcurrent(
        localVc: s.incomingVc,
        incomingVc: s.localVc,
        localUpdatedAt: s.incomingUpdatedAt,
        incomingUpdatedAt: s.localUpdatedAt,
      );
      final winner2 = swapped == ConcurrentWinner.local
          ? 'incomingSide'
          : 'localSide';

      expect(winner1, winner2, reason: 'must converge for $s');
    }, tags: 'glados');
  });

  group('resolveConcurrent — examples', () {
    final base = DateTime(2024);
    const vc = VectorClock({'h0': 1, 'h1': 1});

    test('strictly-newer incoming wins regardless of clocks', () {
      expect(
        resolveConcurrent(
          localVc: const VectorClock({'h0': 9}),
          incomingVc: vc,
          localUpdatedAt: base,
          incomingUpdatedAt: base.add(const Duration(seconds: 1)),
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('strictly-newer local wins regardless of clocks', () {
      expect(
        resolveConcurrent(
          localVc: vc,
          incomingVc: const VectorClock({'h0': 9}),
          localUpdatedAt: base.add(const Duration(seconds: 1)),
          incomingUpdatedAt: base,
        ),
        ConcurrentWinner.local,
      );
    });

    test('equal updatedAt → greater incoming clock wins', () {
      expect(
        resolveConcurrent(
          localVc: const VectorClock({'h0': 1, 'h1': 2}),
          incomingVc: const VectorClock({'h0': 2, 'h1': 1}),
          localUpdatedAt: base,
          incomingUpdatedAt: base,
        ),
        ConcurrentWinner.incoming,
      );
    });

    test('equal updatedAt → greater local clock wins', () {
      expect(
        resolveConcurrent(
          localVc: const VectorClock({'h0': 2, 'h1': 1}),
          incomingVc: const VectorClock({'h0': 1, 'h1': 2}),
          localUpdatedAt: base,
          incomingUpdatedAt: base,
        ),
        ConcurrentWinner.local,
      );
    });

    test('equal updatedAt and identical clocks → stable local fallback', () {
      expect(
        resolveConcurrent(
          localVc: vc,
          incomingVc: vc,
          localUpdatedAt: base,
          incomingUpdatedAt: base,
        ),
        ConcurrentWinner.local,
      );
    });
  });

  group('compareClocksCanonically', () {
    glados.Glados2(
      glados.any.smallVectorClock,
      glados.any.smallVectorClock,
      glados.ExploreConfig(numRuns: 150),
    ).test('is antisymmetric', (a, b) {
      expect(
        compareClocksCanonically(a, b),
        -compareClocksCanonically(b, a),
        reason: 'a=${a.vclock} b=${b.vclock}',
      );
    }, tags: 'glados');

    glados.Glados3(
      glados.any.smallVectorClock,
      glados.any.smallVectorClock,
      glados.any.smallVectorClock,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'is transitive (sort-comparator contract on the sync hot path)',
      (
        a,
        b,
        c,
      ) {
        final ab = compareClocksCanonically(a, b);
        final bc = compareClocksCanonically(b, c);
        final ac = compareClocksCanonically(a, c);
        if (ab > 0 && bc > 0) {
          expect(
            ac,
            greaterThan(0),
            reason: 'a=${a.vclock} b=${b.vclock} c=${c.vclock}',
          );
        }
        if (ab < 0 && bc < 0) {
          expect(
            ac,
            lessThan(0),
            reason: 'a=${a.vclock} b=${b.vclock} c=${c.vclock}',
          );
        }
        if (ab == 0 && bc == 0) {
          expect(
            ac,
            0,
            reason: 'a=${a.vclock} b=${b.vclock} c=${c.vclock}',
          );
        }
      },
      tags: 'glados',
    );

    test('orders by the first differing host counter', () {
      expect(
        compareClocksCanonically(
          const VectorClock({'h0': 2}),
          const VectorClock({'h0': 1}),
        ),
        1,
      );
      expect(
        compareClocksCanonically(
          const VectorClock({'h0': 1}),
          const VectorClock({'h0': 2}),
        ),
        -1,
      );
    });

    test('treats an absent host as counter 0', () {
      expect(
        compareClocksCanonically(
          const VectorClock({'h0': 1}),
          const VectorClock({'h1': 1}),
        ),
        1,
      );
    });

    test('returns 0 for identical and for empty clocks', () {
      expect(
        compareClocksCanonically(
          const VectorClock({'h0': 3, 'h1': 1}),
          const VectorClock({'h0': 3, 'h1': 1}),
        ),
        0,
      );
      expect(
        compareClocksCanonically(const VectorClock({}), const VectorClock({})),
        0,
      );
    });
  });

  group('mergeAgentStateCounters', () {
    AgentStateEntity stateWith({
      GCounter wakeCounter = const GCounter.empty(),
      GCounter totalSessions = const GCounter.empty(),
      int revision = 1,
      String? activeTaskId,
      DateTime? reportStaleAt,
      DateTime? reportFreshAt,
    }) {
      return AgentDomainEntity.agentState(
            id: 'state-1',
            agentId: 'agent-1',
            revision: revision,
            slots: AgentSlots(
              activeTaskId: activeTaskId,
              totalSessionsCompleted: totalSessions,
            ),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            wakeCounter: wakeCounter,
            reportStaleAt: reportStaleAt,
            reportFreshAt: reportFreshAt,
          )
          as AgentStateEntity;
    }

    test('joins counters element-wise and takes non-counter fields from the '
        'winner', () {
      final local = stateWith(
        wakeCounter: const GCounter({'h1': 5}),
        totalSessions: const GCounter({'h1': 1}),
        revision: 2,
        activeTaskId: 'task-local',
      );
      final incoming = stateWith(
        wakeCounter: const GCounter({'h2': 3}),
        totalSessions: const GCounter({'h2': 4}),
        revision: 9,
        activeTaskId: 'task-incoming',
      );

      final merged = mergeAgentStateCounters(
        winner: local,
        local: local,
        incoming: incoming,
      );

      // Counters: element-wise max of BOTH sides — nothing dropped.
      expect(merged.wakeCounter.byHost, {'h1': 5, 'h2': 3});
      expect(merged.wakeCounter.value, 8);
      expect(merged.slots.totalSessionsCompleted.byHost, {'h1': 1, 'h2': 4});
      // Non-counter fields: from the winner (local here).
      expect(merged.revision, 2);
      expect(merged.slots.activeTaskId, 'task-local');
    });

    test('joins report freshness watermarks by latest observed event', () {
      final staleEarlier = DateTime(2026, 7, 16, 9);
      final staleLater = DateTime(2026, 7, 16, 10);
      final freshEarlier = DateTime(2026, 7, 16, 8);
      final freshLater = DateTime(2026, 7, 16, 11);
      final local = stateWith(
        reportStaleAt: staleLater,
        reportFreshAt: freshEarlier,
        activeTaskId: 'local-winner',
      );
      final incoming = stateWith(
        reportStaleAt: staleEarlier,
        reportFreshAt: freshLater,
        activeTaskId: 'incoming-loser',
      );

      final merged = mergeAgentStateCounters(
        winner: local,
        local: local,
        incoming: incoming,
      );

      expect(merged.reportStaleAt, staleLater);
      expect(merged.reportFreshAt, freshLater);
      expect(merged.isReportStale, isFalse);
      expect(merged.slots.activeTaskId, 'local-winner');
    });

    test('counters are winner-independent; only non-counter fields follow the '
        'winner', () {
      final local = stateWith(
        wakeCounter: const GCounter({'h1': 5}),
        activeTaskId: 'L',
      );
      final incoming = stateWith(
        wakeCounter: const GCounter({'h2': 3}),
        activeTaskId: 'I',
      );

      final viaLocal = mergeAgentStateCounters(
        winner: local,
        local: local,
        incoming: incoming,
      );
      final viaIncoming = mergeAgentStateCounters(
        winner: incoming,
        local: local,
        incoming: incoming,
      );

      expect(viaLocal.slots.activeTaskId, 'L');
      expect(viaIncoming.slots.activeTaskId, 'I');
      // The merged counter is the same regardless of which side won the LWW.
      expect(viaLocal.wakeCounter, viaIncoming.wakeCounter);
      expect(viaLocal.wakeCounter.value, 8);
    });

    glados.Glados2(
      glados.any.gCounter,
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'join dominates both inputs per host, and merging a state with '
      'itself is a counter no-op (CRDT idempotence)',
      (a, b) {
        final local = stateWith(wakeCounter: a, totalSessions: b);
        final incoming = stateWith(wakeCounter: b, totalSessions: a);

        final merged = mergeAgentStateCounters(
          winner: local,
          local: local,
          incoming: incoming,
        );

        // Join is ≥ each input on every host, for both counters.
        final hosts = {...a.byHost.keys, ...b.byHost.keys};
        for (final host in hosts) {
          expect(
            merged.wakeCounter.byHost[host] ?? 0,
            greaterThanOrEqualTo(a.byHost[host] ?? 0),
          );
          expect(
            merged.wakeCounter.byHost[host] ?? 0,
            greaterThanOrEqualTo(b.byHost[host] ?? 0),
          );
          expect(
            merged.slots.totalSessionsCompleted.byHost[host] ?? 0,
            greaterThanOrEqualTo(a.byHost[host] ?? 0),
          );
          expect(
            merged.slots.totalSessionsCompleted.byHost[host] ?? 0,
            greaterThanOrEqualTo(b.byHost[host] ?? 0),
          );
        }

        // Idempotence: self-merge changes nothing.
        final selfMerged = mergeAgentStateCounters(
          winner: local,
          local: local,
          incoming: local,
        );
        expect(selfMerged.wakeCounter, a);
        expect(selfMerged.slots.totalSessionsCompleted, b);
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.gCounter,
      glados.any.gCounter,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'the merged counter equals the element-wise join of both sides, '
      'independent of winner order (partition + heal)',
      (a, b) {
        final local = stateWith(wakeCounter: a);
        final incoming = stateWith(wakeCounter: b);

        final viaLocal = mergeAgentStateCounters(
          winner: local,
          local: local,
          incoming: incoming,
        );
        final viaIncoming = mergeAgentStateCounters(
          winner: incoming,
          local: incoming,
          incoming: local,
        );

        expect(viaLocal.wakeCounter, a.merge(b), reason: '$a ⊔ $b');
        // Commutative: both devices converge to the same counter on heal.
        expect(viaLocal.wakeCounter, viaIncoming.wakeCounter);
      },
      tags: 'glados',
    );
  });

  group('resolveAgentEntityVersions — the receive path (ADR 0068)', () {
    AgentStateEntity state({
      required Map<String, int> vc,
      Map<String, int> counter = const {},
      int revision = 1,
      DateTime? updatedAt,
    }) =>
        AgentDomainEntity.agentState(
              id: 'state-1',
              agentId: 'agent-1',
              revision: revision,
              slots: const AgentSlots(),
              updatedAt: updatedAt ?? DateTime(2024, 3, 15),
              vectorClock: VectorClock(vc),
              wakeCounter: GCounter(counter),
            )
            as AgentStateEntity;

    PlannerKnowledgeEntity knowledge({
      required KnowledgeStatus status,
      required VectorClock? vc,
      DateTime? updatedAt,
      String statement = 'Never schedule deep work before 10:00.',
    }) =>
        AgentDomainEntity.plannerKnowledge(
              id: 'k1',
              agentId: 'a1',
              key: 'deep-work',
              hook: 'no deep work before 10',
              statementText: statement,
              source: KnowledgeSource.userStated,
              status: status,
              createdAt: DateTime(2026, 5, 20),
              updatedAt: updatedAt ?? DateTime(2026, 5, 20),
              vectorClock: vc,
            )
            as PlannerKnowledgeEntity;

    test('a causal successor still joins the G-counters of a merged row — '
        'AgentReplication OwnCountKept (CountersJoinAlways)', () {
      // B merged A's version into its own and kept its increment; A's next
      // write succeeds only A's version and never saw B's increment.
      final merged = state(vc: {'A': 1}, counter: {'A': 1, 'B': 1});
      final successor = state(vc: {'A': 2}, counter: {'A': 1}, revision: 2);

      final resolved = resolveAgentEntityVersions(
        local: merged,
        incoming: successor,
      );

      expect(resolved, isA<AgentStateEntity>());
      final row = resolved as AgentStateEntity;
      expect(row.wakeCounter, const GCounter({'A': 1, 'B': 1}));
      // Every other field — and the clock — is the successor's.
      expect(row.revision, 2);
      expect(row.vectorClock, successor.vectorClock);
    });

    test('keeps the local row itself when it dominates or equals', () {
      final local = state(vc: {'A': 2});
      expect(
        resolveAgentEntityVersions(
          local: local,
          incoming: state(vc: {'A': 1}, revision: 9),
        ),
        same(local),
      );
      expect(
        resolveAgentEntityVersions(
          local: local,
          incoming: state(vc: {'A': 2}),
        ),
        same(local),
      );
    });

    test('a merge that equals the local row keeps the local row itself', () {
      // Concurrent, local wins on updatedAt and already holds both counters.
      final local = state(
        vc: {'A': 1},
        counter: {'A': 1, 'B': 1},
        updatedAt: DateTime(2024, 3, 16),
      );
      final incoming = state(vc: {'B': 1}, counter: {'B': 1});
      expect(
        resolveAgentEntityVersions(local: local, incoming: incoming),
        same(local),
      );
    });

    test('applies the incoming version when either clock is missing', () {
      final incoming = state(vc: {'A': 1});
      final unclocked = AgentDomainEntity.agentState(
        id: 'state-1',
        agentId: 'agent-1',
        revision: 1,
        slots: const AgentSlots(),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );
      expect(
        resolveAgentEntityVersions(local: unclocked, incoming: incoming),
        same(incoming),
      );
      expect(
        resolveAgentEntityVersions(local: incoming, incoming: unclocked),
        same(unclocked),
      );
    });

    test('a known variant refines an unknown stub, but not its tombstone', () {
      const vc = VectorClock({'A': 3});
      final stub = AgentDomainEntity.unknown(
        id: 'k1',
        agentId: 'a1',
        createdAt: DateTime(2026),
        vectorClock: vc,
      );
      final live = knowledge(
        status: KnowledgeStatus.confirmed,
        vc: const VectorClock({'A': 1}),
      );
      expect(
        resolveAgentEntityVersions(local: stub, incoming: live),
        same(live),
      );

      final tombstone = AgentDomainEntity.unknown(
        id: 'k1',
        agentId: 'a1',
        createdAt: DateTime(2026),
        deletedAt: DateTime(2026, 2),
        vectorClock: vc,
      );
      // The stub's clock dominates, so the tombstone stands.
      expect(
        resolveAgentEntityVersions(local: tombstone, incoming: live),
        same(tombstone),
      );
    });

    test('a concurrent pair goes through the type override first', () {
      final retracted = knowledge(
        status: KnowledgeStatus.retracted,
        vc: const VectorClock({'A': 1}),
      );
      final newerEdit = knowledge(
        status: KnowledgeStatus.confirmed,
        vc: const VectorClock({'B': 1}),
        updatedAt: DateTime(2027),
      );
      expect(
        resolveAgentEntityVersions(local: retracted, incoming: newerEdit),
        same(retracted),
      );
      expect(
        resolveAgentEntityVersions(local: newerEdit, incoming: retracted),
        same(retracted),
      );
    });

    test('a malformed clock throws for the caller to handle', () {
      expect(
        () => resolveAgentEntityVersions(
          local: state(vc: {'A': -1}),
          incoming: state(vc: {'A': 1}),
        ),
        throwsA(isA<VclockException>()),
      );
    });
  });

  group(
    'resolveLocalAgentWrite — a local write succeeds its row (ADR 0068)',
    () {
      PlannerKnowledgeEntity knowledge({
        required KnowledgeStatus status,
        required VectorClock? vc,
        DateTime? updatedAt,
        String statement = 'Never schedule deep work before 10:00.',
      }) =>
          AgentDomainEntity.plannerKnowledge(
                id: 'k1',
                agentId: 'a1',
                key: 'deep-work',
                hook: 'no deep work before 10',
                statementText: statement,
                source: KnowledgeSource.userStated,
                status: status,
                createdAt: DateTime(2026, 5, 20),
                updatedAt: updatedAt ?? DateTime(2026, 5, 20),
                vectorClock: vc,
              )
              as PlannerKnowledgeEntity;

      AgentStateEntity state({
        required Map<String, int>? vc,
        Map<String, int> counter = const {},
        int revision = 1,
        DateTime? updatedAt,
        DateTime? reportStaleAt,
      }) =>
          AgentDomainEntity.agentState(
                id: 'state-1',
                agentId: 'agent-1',
                revision: revision,
                slots: const AgentSlots(),
                updatedAt: updatedAt ?? DateTime(2024, 3, 15),
                vectorClock: vc == null ? null : VectorClock(vc),
                wakeCounter: GCounter(counter),
                reportStaleAt: reportStaleAt,
              )
              as AgentStateEntity;

      test('a write built on a stale clock, or none, cannot revive a '
          'retraction it never saw — AgentReplication Converged '
          '(ResolveLocalWrites)', () {
        // A peer's retraction arrived after this device read the entry.
        final retracted = knowledge(
          status: KnowledgeStatus.retracted,
          vc: const VectorClock({'A': 1, 'B': 1}),
        );
        for (final base in [
          const VectorClock({'A': 1}),
          null,
        ]) {
          final staleEdit = knowledge(
            status: KnowledgeStatus.confirmed,
            vc: base,
            updatedAt: DateTime(2027),
            statement: 'edited',
          );
          final row = resolveLocalAgentWrite(
            persisted: retracted,
            write: staleEdit,
          );
          // Every peer holding the retraction resolves the pair the same way.
          expect(
            (row as PlannerKnowledgeEntity).status,
            KnowledgeStatus.retracted,
            reason: 'base $base',
          );
          expect(row.statementText, retracted.statementText);
        }
      });

      test(
        'a stale write that beats the row on updatedAt keeps its fields',
        () {
          final persisted = state(vc: {'A': 1, 'B': 1});
          final write = state(
            vc: {'A': 1},
            revision: 5,
            updatedAt: DateTime(2024, 4),
          );
          final row =
              resolveLocalAgentWrite(persisted: persisted, write: write)
                  as AgentStateEntity;
          expect(row.revision, 5);
        },
      );

      test('a write built on the row keeps its fields, and never lowers a '
          'G-counter or a report watermark', () {
        // A concurrent merge joined B's increment and a later watermark into
        // the row without moving its clock.
        final persisted = state(
          vc: {'A': 1},
          counter: {'A': 1, 'B': 1},
          reportStaleAt: DateTime(2024, 3, 14),
        );
        final write = state(
          vc: {'A': 1},
          counter: {'A': 2},
          revision: 2,
          updatedAt: DateTime(2024, 3, 16),
        );
        final row =
            resolveLocalAgentWrite(persisted: persisted, write: write)
                as AgentStateEntity;
        expect(row.revision, 2);
        expect(row.wakeCounter, const GCounter({'A': 2, 'B': 1}));
        expect(row.reportStaleAt, DateTime(2024, 3, 14));
      });

      test('updatedAt never moves backwards — AgentReplication NoLostSuccessor '
          '(ClampTimestamp)', () {
        // This device's clock runs behind the peer that wrote the row.
        final persisted = state(vc: {'B': 1}, updatedAt: DateTime(2024, 3, 20));
        final write = state(
          vc: {'B': 1},
          revision: 2,
          updatedAt: DateTime(2024, 3, 18),
        );
        final row = resolveLocalAgentWrite(persisted: persisted, write: write);
        expect(row.effectiveUpdatedAt, DateTime(2024, 3, 20));
        expect((row as AgentStateEntity).revision, 2);
      });

      test('a malformed clock is treated as a base that saw nothing', () {
        final persisted = state(vc: {'A': 1}, updatedAt: DateTime(2024, 3, 20));
        final write = state(vc: {'A': -1}, revision: 7);
        final row =
            resolveLocalAgentWrite(persisted: persisted, write: write)
                as AgentStateEntity;
        // Resolved as concurrent: the persisted row's newer timestamp wins.
        expect(row.revision, 1);
      });

      test('append-only variants, stubs and a different variant are written '
          'as given', () {
        final message = AgentDomainEntity.agentMessage(
          id: 'm1',
          agentId: 'a1',
          threadId: 't1',
          kind: AgentMessageKind.system,
          createdAt: DateTime(2024),
          vectorClock: null,
          metadata: const AgentMessageMetadata(),
        );
        expect(
          resolveLocalAgentWrite(
            persisted: message.copyWith(
              vectorClock: const VectorClock({'A': 3}),
            ),
            write: message,
          ),
          same(message),
        );

        final write = state(vc: null);
        final stub = AgentDomainEntity.unknown(
          id: 'state-1',
          agentId: 'agent-1',
          createdAt: DateTime(2030),
          vectorClock: const VectorClock({'A': 9}),
        );
        expect(
          resolveLocalAgentWrite(persisted: stub, write: write),
          same(write),
        );
        expect(
          resolveLocalAgentWrite(
            persisted: knowledge(
              status: KnowledgeStatus.confirmed,
              vc: const VectorClock({'A': 9}),
            ),
            write: write,
          ),
          same(write),
        );
      });
    },
  );
}
