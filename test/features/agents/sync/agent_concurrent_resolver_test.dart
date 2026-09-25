import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../../../helpers/fallbacks.dart';
import '../agent_test_device.dart';
import '../test_utils.dart';
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

    test(
      "a new host's first write, which adds counter 0 to the clock it "
      'extends, replaces the row (ADR 0080)',
      () {
        // Every host an older build created starts at counter 0.
        final local = state(vc: {'A': 1});
        final edit = state(vc: {'A': 1, 'B': 0}, revision: 2);

        final resolved = resolveAgentEntityVersions(
          local: local,
          incoming: edit,
        );

        expect(resolved.vectorClock, edit.vectorClock);
        expect((resolved as AgentStateEntity).revision, 2);
      },
    );

    test(
      'two new hosts that each extended the row with counter 0 converge on '
      'one version at the same updatedAt (ADR 0080)',
      () {
        final fromB = state(vc: {'A': 1, 'B': 0}, revision: 2);
        final fromC = state(vc: {'A': 1, 'C': 0}, revision: 3);

        final onB = resolveAgentEntityVersions(local: fromB, incoming: fromC);
        final onC = resolveAgentEntityVersions(local: fromC, incoming: fromB);

        expect(onB.toJson(), onC.toJson());
        // B's clock ranks higher: C is absent there, below B's counter 0.
        expect((onB as AgentStateEntity).revision, 2);
      },
    );

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

      test('a row built afresh over a removal is a re-creation and keeps its '
          'fields — AgentReplication LocalWriteTakesEffect '
          '(RecreateKeepsFields)', () {
        // A day plan deleted on a device whose clock runs ahead, and drafted
        // again here: the writer read no row, so it could not build on the
        // tombstone. Resolved as concurrent, the removal's later instant won
        // and the redraft was handed back.
        final removal = state(
          vc: {'B': 2},
          updatedAt: DateTime(2024, 3, 20),
        ).copyWith(deletedAt: DateTime(2024, 3, 20));
        final redraft = state(
          vc: null,
          revision: 9,
          updatedAt: DateTime(2024, 3, 18),
        );

        final row =
            resolveLocalAgentWrite(persisted: removal, write: redraft)
                as AgentStateEntity;

        expect(row.revision, 9);
        expect(row.deletedAt, isNull);
        // It still sorts after the removal it replaces.
        expect(row.updatedAt, DateTime(2024, 3, 20));
      });

      test('an edit built on a snapshot from before a removal is resolved '
          'against it like any concurrent write', () {
        final removal = state(
          vc: {'A': 1, 'B': 1},
          updatedAt: DateTime(2024, 3, 15),
        ).copyWith(deletedAt: DateTime(2024, 3, 20));
        final staleEdit = state(
          vc: {'A': 1},
          revision: 4,
          updatedAt: DateTime(2024, 3, 18),
        );

        final row =
            resolveLocalAgentWrite(persisted: removal, write: staleEdit)
                as AgentStateEntity;

        // The removal happened later: it stands, as on every peer.
        expect(row.deletedAt, DateTime(2024, 3, 20));
        expect(row.revision, 1);
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

  group('the agent head is a register over the message DAG (ADR 0076)', () {
    // r ← a1 ← a2 on one branch, r ← b1 on the other.
    const parents = {
      'a1': {'r'},
      'a2': {'a1'},
      'b1': {'r'},
    };
    bool dag(String ancestorId, String descendantId) {
      final pending = [...?parents[descendantId]];
      while (pending.isNotEmpty) {
        final next = pending.removeLast();
        if (next == ancestorId) return true;
        pending.addAll(parents[next] ?? const {});
      }
      return false;
    }

    AgentStateEntity state({
      required String? head,
      required Map<String, int> vc,
      required DateTime updatedAt,
      int revision = 1,
    }) =>
        (AgentDomainEntity.agentState(
                  id: 'state-1',
                  agentId: 'agent-1',
                  revision: revision,
                  slots: const AgentSlots(),
                  updatedAt: updatedAt,
                  vectorClock: VectorClock(vc),
                )
                as AgentStateEntity)
            .copyWith(recentHeadMessageId: head);

    String? headOf(AgentDomainEntity entity) =>
        (entity as AgentStateEntity).recentHeadMessageId;

    test('mergeAgentHeads: the descendant wins in both directions', () {
      expect(
        mergeAgentHeads(local: 'a2', incoming: 'r', isAncestor: dag),
        'a2',
      );
      expect(
        mergeAgentHeads(local: 'r', incoming: 'a2', isAncestor: dag),
        'a2',
      );
    });

    test('mergeAgentHeads: an unset head never wins', () {
      expect(
        mergeAgentHeads(local: null, incoming: 'a1', isAncestor: dag),
        'a1',
      );
      expect(
        mergeAgentHeads(local: 'a1', incoming: null, isAncestor: dag),
        'a1',
      );
      expect(
        mergeAgentHeads(local: null, incoming: null, isAncestor: dag),
        isNull,
      );
    });

    test('mergeAgentHeads: a true fork, or an unknown order, goes by id — '
        'the same head whichever side receives', () {
      expect(
        mergeAgentHeads(local: 'a2', incoming: 'b1', isAncestor: dag),
        'b1',
      );
      expect(
        mergeAgentHeads(local: 'b1', incoming: 'a2', isAncestor: dag),
        'b1',
      );
      // Rows not synced yet: `r` descends from nothing known here.
      expect(
        mergeAgentHeads(
          local: 'r',
          incoming: 'a2',
          isAncestor: noKnownAncestry,
        ),
        'r',
      );
      expect(
        mergeAgentHeads(
          local: 'a2',
          incoming: 'r',
          isAncestor: noKnownAncestry,
        ),
        'r',
      );
    });

    test('mergeAgentHeads over every pair: symmetric, one of the two, never '
        'a known ancestor of the other (HeadNeverRegresses)', () {
      const heads = [null, 'r', 'a1', 'a2', 'b1'];
      for (final local in heads) {
        for (final incoming in heads) {
          final merged = mergeAgentHeads(
            local: local,
            incoming: incoming,
            isAncestor: dag,
          );
          final reason = 'local $local, incoming $incoming';
          expect(
            merged,
            mergeAgentHeads(local: incoming, incoming: local, isAncestor: dag),
            reason: reason,
          );
          expect([local, incoming], contains(merged), reason: reason);
          for (final other in [local, incoming]) {
            if (merged != null && other != null) {
              expect(dag(merged, other), isFalse, reason: reason);
            }
          }
        }
      }
    });

    test('a concurrent version that wins last-writer-wins with an ancestor '
        'of the local head keeps the local head (TLC: HeadNeverRegresses)', () {
      final local = state(
        head: 'a1',
        vc: {'local': 1},
        updatedAt: DateTime(2026, 9, 1, 9),
      );
      final incoming = state(
        head: 'r',
        vc: {'peer': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
        revision: 2,
      );

      final resolved =
          resolveAgentEntityVersions(
                local: local,
                incoming: incoming,
                isAncestor: dag,
              )
              as AgentStateEntity;

      expect(resolved.recentHeadMessageId, 'a1');
      // Every other field is still the last writer's.
      expect(resolved.revision, 2);
      expect(resolved.vectorClock, incoming.vectorClock);
    });

    test('a concurrent version that loses last-writer-wins still carries '
        'its head forward when that head descends from the local one', () {
      final local = state(
        head: 'r',
        vc: {'local': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
      );
      final incoming = state(
        head: 'a2',
        vc: {'peer': 1},
        updatedAt: DateTime(2026, 9, 1, 9),
        revision: 2,
      );

      final resolved =
          resolveAgentEntityVersions(
                local: local,
                incoming: incoming,
                isAncestor: dag,
              )
              as AgentStateEntity;

      expect(resolved.recentHeadMessageId, 'a2');
      expect(resolved.revision, 1);
      expect(resolved.vectorClock, local.vectorClock);
    });

    test('two replicas holding a concurrent pair settle on one head', () {
      final a = state(
        head: 'a2',
        vc: {'A': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
      );
      final b = state(
        head: 'b1',
        vc: {'B': 1},
        updatedAt: DateTime(2026, 9, 1, 9),
      );

      for (final isAncestor in [dag, noKnownAncestry]) {
        final onA = resolveAgentEntityVersions(
          local: a,
          incoming: b,
          isAncestor: isAncestor,
        );
        final onB = resolveAgentEntityVersions(
          local: b,
          incoming: a,
          isAncestor: isAncestor,
        );
        expect(headOf(onA), 'b1');
        expect(headOf(onB), headOf(onA));
      }
    });

    test('a dominating version keeps a local head known to descend from its '
        'own, or when it has none', () {
      final local = state(
        head: 'a2',
        vc: {'peer': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
      );
      for (final head in ['a1', null]) {
        final successor = state(
          head: head,
          vc: {'peer': 2},
          updatedAt: DateTime(2026, 9, 1, 13),
          revision: 2,
        );

        final resolved =
            resolveAgentEntityVersions(
                  local: local,
                  incoming: successor,
                  isAncestor: dag,
                )
                as AgentStateEntity;

        expect(resolved.recentHeadMessageId, 'a2', reason: 'head $head');
        expect(resolved.revision, 2);
        expect(resolved.vectorClock, successor.vectorClock);
      }
    });

    test('a dominating version otherwise brings its own head — a descendant, '
        'another branch, or one whose order is not known here', () {
      final local = state(
        head: 'a1',
        vc: {'peer': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
      );
      for (final (head, isAncestor) in [
        ('a2', dag),
        ('b1', dag),
        ('r', noKnownAncestry),
      ]) {
        final successor = state(
          head: head,
          vc: {'peer': 2},
          updatedAt: DateTime(2026, 9, 1, 13),
        );

        expect(
          headOf(
            resolveAgentEntityVersions(
              local: local,
              incoming: successor,
              isAncestor: isAncestor,
            ),
          ),
          head,
        );
      }
    });

    test('an unclocked version applies, but never moves the head back', () {
      final clocked = state(
        head: 'a2',
        vc: {'local': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
      );
      for (final head in ['a1', null]) {
        final legacy = state(
          head: head,
          vc: const {},
          updatedAt: DateTime(2026, 9, 1, 9),
          revision: 2,
        ).copyWith(vectorClock: null);

        final resolved =
            resolveAgentEntityVersions(
                  local: clocked,
                  incoming: legacy,
                  isAncestor: dag,
                )
                as AgentStateEntity;

        expect(resolved.recentHeadMessageId, 'a2', reason: 'head $head');
        // Every other field is still the unclocked version's.
        expect(resolved.revision, 2);
        expect(resolved.vectorClock, isNull);
      }

      // And an unclocked local row takes a descendant head with the
      // incoming version.
      final legacyLocal = state(
        head: 'a1',
        vc: const {},
        updatedAt: DateTime(2026, 9, 1, 9),
      ).copyWith(vectorClock: null);
      expect(
        headOf(
          resolveAgentEntityVersions(
            local: legacyLocal,
            incoming: clocked,
            isAncestor: dag,
          ),
        ),
        'a2',
      );
    });

    test('without an ancestry oracle a concurrent pair falls back to the id '
        'order', () {
      final local = state(
        head: 'a1',
        vc: {'local': 1},
        updatedAt: DateTime(2026, 9, 1, 9),
      );
      final incoming = state(
        head: 'r',
        vc: {'peer': 1},
        updatedAt: DateTime(2026, 9, 1, 12),
      );

      expect(
        headOf(resolveAgentEntityVersions(local: local, incoming: incoming)),
        'r',
      );
    });
  });

  group('evolution sessions: completed, then abandoned, then active '
      '(EvolutionSession.tla, ADR 0081)', () {
    final at = DateTime(2026, 9, 24, 9);

    EvolutionSessionEntity session(
      EvolutionSessionStatus status, {
      required Map<String, int> vc,
      required DateTime updatedAt,
    }) => makeTestEvolutionSession(
      id: 's',
      status: status,
      updatedAt: updatedAt,
      vectorClock: VectorClock(vc),
    );

    for (final (winner, loser) in [
      (EvolutionSessionStatus.completed, EvolutionSessionStatus.abandoned),
      (EvolutionSessionStatus.completed, EvolutionSessionStatus.active),
      (EvolutionSessionStatus.abandoned, EvolutionSessionStatus.active),
    ]) {
      test('${winner.name} beats a concurrent, later ${loser.name} on either '
          'side', () {
        final win = session(winner, vc: {'a': 2}, updatedAt: at);
        final lose = session(
          loser,
          vc: {'b': 2},
          updatedAt: at.add(const Duration(hours: 1)),
        );

        expect(
          resolveConcurrentAgentEntityOverride(local: win, incoming: lose),
          ConcurrentWinner.local,
        );
        expect(
          resolveConcurrentAgentEntityOverride(local: lose, incoming: win),
          ConcurrentWinner.incoming,
        );
        expect(resolveAgentEntityVersions(local: lose, incoming: win), win);
      });
    }

    test('the same status defers to last-writer-wins', () {
      final earlier = session(
        EvolutionSessionStatus.abandoned,
        vc: {'a': 2},
        updatedAt: at,
      );
      final later = session(
        EvolutionSessionStatus.abandoned,
        vc: {'b': 2},
        updatedAt: at.add(const Duration(minutes: 1)),
      );

      expect(
        resolveConcurrentAgentEntityOverride(local: earlier, incoming: later),
        isNull,
      );
      expect(
        resolveAgentEntityVersions(local: earlier, incoming: later),
        later,
      );
    });

    group('two devices, through AgentSyncService', () {
      late AgentTestDevice owner;
      late AgentTestDevice peer;

      setUpAll(registerAllFallbackValues);

      setUp(() async {
        owner = AgentTestDevice('host-a');
        peer = AgentTestDevice('host-b');
        addTearDown(owner.close);
        addTearDown(peer.close);
        await owner.sync.upsertEntity(
          makeTestEvolutionSession(id: 's', createdAt: at, updatedAt: at),
        );
        await peer.receiveEntity(owner.sentEntities.single);
      });

      Future<EvolutionSessionEntity> rowOf(AgentTestDevice device) async =>
          (await device.repository.getEntity('s'))! as EvolutionSessionEntity;

      Future<void> complete() async {
        final t = at.add(const Duration(minutes: 1));
        await owner.sync.upsertEntity(
          (await rowOf(owner)).copyWith(
            status: EvolutionSessionStatus.completed,
            proposedVersionId: 'v2',
            completedAt: t,
            updatedAt: t,
          ),
        );
      }

      /// `_abandonStaleActiveSessions`: the peer starts a session of its own
      /// and abandons every active one it reads, [read] included.
      Future<void> sweep(EvolutionSessionEntity read) async {
        final t = at.add(const Duration(minutes: 2));
        await peer.sync.upsertEntity(
          read.copyWith(
            status: EvolutionSessionStatus.abandoned,
            completedAt: t,
            updatedAt: t,
          ),
        );
      }

      Future<void> expectCompletedEverywhere() async {
        for (final device in [owner, peer]) {
          final row = await rowOf(device);
          expect(row.status, EvolutionSessionStatus.completed);
          expect(row.proposedVersionId, 'v2');
        }
      }

      test(
        'an approval and a later concurrent sweep converge on completed '
        '(TLC: AdoptionRecorded, CompletedStays)',
        () async {
          // The trace: the owner approves; the peer, not having heard, starts
          // a session a minute later and sweeps this one as stale. Last-
          // writer-wins kept the sweep: the adopted proposal read as
          // abandoned everywhere, a negative signal for the next ritual.
          await complete();
          await sweep(await rowOf(peer));

          await peer.receiveEntity(owner.sentEntities.last);
          await owner.receiveEntity(peer.sentEntities.last);

          await expectCompletedEverywhere();
        },
      );

      test(
        'a sweep built on a read the completion overtook keeps the completion',
        () async {
          final read = await rowOf(peer);
          await complete();
          await peer.receiveEntity(owner.sentEntities.last);
          await sweep(read);

          await owner.receiveEntity(peer.sentEntities.last);

          await expectCompletedEverywhere();
        },
      );
    });
  });

  group('resolveAgentLinkVersions — the link receive path (ADR 0081)', () {
    final at = DateTime(2026, 9, 24, 9);

    AgentLink link({
      required Map<String, int>? vc,
      DateTime? updatedAt,
      bool deleted = false,
    }) => AgentLink.basic(
      id: 'l',
      fromId: 'from',
      toId: 'to',
      createdAt: at,
      updatedAt: updatedAt ?? at,
      vectorClock: vc == null ? null : VectorClock(vc),
      deletedAt: deleted ? updatedAt ?? at : null,
    );

    test('a tombstone that dominates is kept against its live ancestor', () {
      final tombstone = link(vc: {'a': 2}, deleted: true);
      final ancestor = link(vc: {'a': 1});

      expect(
        resolveAgentLinkVersions(local: tombstone, incoming: ancestor),
        same(tombstone),
      );
    });

    test('an equal clock keeps the local version', () {
      final local = link(vc: {'a': 1});

      expect(
        resolveAgentLinkVersions(
          local: local,
          incoming: link(vc: {'a': 1}),
        ),
        same(local),
      );
    });

    test('a dominating incoming version applies', () {
      final incoming = link(vc: {'a': 1, 'b': 1}, deleted: true);

      expect(
        resolveAgentLinkVersions(
          local: link(vc: {'a': 1}),
          incoming: incoming,
        ),
        same(incoming),
      );
    });

    test('a concurrent pair goes to the later updatedAt, on either side', () {
      final older = link(vc: {'a': 1});
      final newer = link(
        vc: {'b': 1},
        updatedAt: at.add(const Duration(minutes: 1)),
        deleted: true,
      );

      expect(
        resolveAgentLinkVersions(local: older, incoming: newer),
        same(newer),
      );
      expect(
        resolveAgentLinkVersions(local: newer, incoming: older),
        same(newer),
      );
    });

    test('a concurrent pair at the same instant goes to the canonical '
        'clock order', () {
      final greater = link(vc: {'a': 1});
      final lesser = link(vc: {'b': 1});

      expect(
        resolveAgentLinkVersions(local: lesser, incoming: greater),
        same(greater),
      );
      expect(
        resolveAgentLinkVersions(local: greater, incoming: lesser),
        same(greater),
      );
    });

    test('a version without a clock carries no order and applies', () {
      final unclocked = link(vc: null);

      expect(
        resolveAgentLinkVersions(
          local: link(vc: {'a': 5}),
          incoming: unclocked,
        ),
        same(unclocked),
      );
      final incoming = link(vc: {'a': 1});
      expect(
        resolveAgentLinkVersions(local: unclocked, incoming: incoming),
        same(incoming),
      );
    });
  });
}
