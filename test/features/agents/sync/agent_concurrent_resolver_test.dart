import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// A pair of genuinely-concurrent versions of one id, plus their timestamps.
///
/// Clocks are built so they are always concurrent and never equal — `local`
/// leads on `h0`, `incoming` leads on `h1` — which is exactly the situation in
/// which [resolveConcurrent] is consulted. By construction `localVc` is the
/// canonically-greater clock (it wins the `h0` comparison), so on equal
/// timestamps the local side is the deterministic winner.
class _Scenario {
  const _Scenario({
    required this.x,
    required this.y,
    required this.localSeconds,
    required this.incomingSeconds,
  });

  final int x;
  final int y;
  final int localSeconds;
  final int incomingSeconds;

  static final _base = DateTime(2024);

  VectorClock get localVc => VectorClock({'h0': x + 1, 'h1': y});
  VectorClock get incomingVc => VectorClock({'h0': x, 'h1': y + 1});
  DateTime get localUpdatedAt => _base.add(Duration(seconds: localSeconds));
  DateTime get incomingUpdatedAt =>
      _base.add(Duration(seconds: incomingSeconds));

  @override
  String toString() =>
      '_Scenario(x:$x, y:$y, localSec:$localSeconds, incSec:$incomingSeconds)';
}

extension _AnyResolver on glados.Any {
  glados.Generator<_Scenario> get resolverScenario =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 6),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        (x, y, localSeconds, incomingSeconds) => _Scenario(
          x: x,
          y: y,
          localSeconds: localSeconds,
          incomingSeconds: incomingSeconds,
        ),
      );

  glados.Generator<VectorClock> get smallVectorClock =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 4),
        (a, b, c) => VectorClock({'h0': a, 'h1': b, 'h2': c}),
      );

  glados.Generator<GCounter> get gCounter => glados.ListAnys(this)
      .listWithLengthInRange(
        0,
        5,
        glados.CombinableAny(this).combine2(
          glados.IntAnys(this).intInRange(0, 3),
          glados.IntAnys(this).intInRange(0, 20),
          (int host, int count) => MapEntry('h$host', count),
        ),
      )
      .map((entries) {
        final byHost = <String, int>{};
        for (final entry in entries) {
          byHost[entry.key] = (byHost[entry.key] ?? 0) + entry.value;
        }
        return GCounter(byHost);
      });
}

ConcurrentWinner _resolve(_Scenario s) => resolveConcurrent(
  localVc: s.localVc,
  incomingVc: s.incomingVc,
  localUpdatedAt: s.localUpdatedAt,
  incomingUpdatedAt: s.incomingUpdatedAt,
);

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

      expect(_resolve(s), expected, reason: '$s');
    }, tags: 'glados');

    glados.Glados(
      glados.any.resolverScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test('selects the same physical version regardless of arg order', (s) {
      // Device 1 holds the "local" version and receives "incoming".
      final winner1 = _resolve(s) == ConcurrentWinner.local
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
      glados.ExploreConfig(numRuns: 200),
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
}
