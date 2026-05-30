import 'dart:math';

import 'package:glados/glados.dart';
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Number of distinct authoring hosts the generators draw from. Small enough
/// that `(hostId, id)` tiebreaks are exercised, large enough for variety.
const _hostCount = 3;

/// One generated node before it becomes an [AgentEvent]. Parents are picked
/// from already-built earlier nodes, which is what keeps the DAG acyclic.
class _NodeSpec {
  const _NodeSpec({
    required this.hostSeed,
    required this.kindSeed,
    required this.wantParent1,
    required this.parent1Seed,
    required this.wantParent2,
    required this.parent2Seed,
  });

  final int hostSeed;
  final int kindSeed;
  final bool wantParent1;
  final int parent1Seed;
  final bool wantParent2;
  final int parent2Seed;
}

/// A randomly-generated, well-formed agent-event DAG for property tests.
///
/// Construction guarantees the kernel's preconditions hold for a *valid* log:
/// ids are unique (`e0`..`eN`), every parent edge points to an earlier node (so
/// the edge set is acyclic), and each event's vector clock strictly dominates
/// all of its parents (so a well-formed DAG yields zero diagnostics). Forks
/// (several nodes sharing one parent) and joins (one node with two parents)
/// both arise naturally from the seeds.
class GeneratedDag {
  /// Wraps a pre-built event list. Tests obtain instances from the
  /// [AnyProjectionFixtures.projectionDag] generator rather than calling this.
  const GeneratedDag(this.events);

  /// The events in build order (each event's parents precede it).
  final List<AgentEvent> events;

  /// A deterministic shuffle of [events] keyed by [seed] — models the same
  /// event set arriving on a device in a different order.
  List<AgentEvent> shuffled(int seed) => [...events]..shuffle(Random(seed));

  @override
  String toString() {
    final lines = events.map(
      (e) =>
          '${e.id}@${e.hostId} ${e.kind.name} '
          '<-[${e.causalParents.join(',')}] ${e.vectorClock.vclock}',
    );
    return 'GeneratedDag(\n  ${lines.join('\n  ')}\n)';
  }
}

List<AgentEvent> _buildEvents(List<_NodeSpec> specs) {
  final built = <AgentEvent>[];
  for (var i = 0; i < specs.length; i++) {
    final spec = specs[i];
    final hostId = 'h${spec.hostSeed % _hostCount}';
    final parents = <AgentEvent>[];
    if (i > 0 && spec.wantParent1) {
      parents.add(built[spec.parent1Seed % i]);
    }
    if (i > 0 && spec.wantParent2) {
      final candidate = built[spec.parent2Seed % i];
      if (!parents.contains(candidate)) parents.add(candidate);
    }
    built.add(
      AgentEvent(
        id: 'e$i',
        hostId: hostId,
        kind:
            AgentEventKind.values[spec.kindSeed % AgentEventKind.values.length],
        vectorClock: _clockDominating(parents, hostId),
        causalParents: [for (final parent in parents) parent.id],
      ),
    );
  }
  return built;
}

/// Builds a vector clock that strictly dominates every parent: the
/// element-wise max of the parents' clocks, then `+1` on the authoring host.
VectorClock _clockDominating(List<AgentEvent> parents, String hostId) {
  final merged = <String, int>{};
  for (final parent in parents) {
    parent.vectorClock.vclock.forEach((node, counter) {
      merged[node] = max(merged[node] ?? 0, counter);
    });
  }
  merged[hostId] = (merged[hostId] ?? 0) + 1;
  return VectorClock(merged);
}

/// One node of an [AnyProjectionFixtures.arbitraryEdgeGraph] — arbitrary parent
/// references (mapped to present nodes, self/forward refs, or absent ghosts).
class _EdgeNode {
  const _EdgeNode({required this.hostSeed, required this.parentRefs});

  final int hostSeed;
  final List<int> parentRefs;
}

List<AgentEvent> _buildArbitraryGraph(List<_EdgeNode> nodes) {
  final n = nodes.length;
  return [
    for (var i = 0; i < n; i++)
      AgentEvent(
        id: 'e$i',
        hostId: 'h${nodes[i].hostSeed % _hostCount}',
        kind: AgentEventKind.message,
        vectorClock: VectorClock({'h${nodes[i].hostSeed % _hostCount}': 1}),
        causalParents: [
          for (final ref in nodes[i].parentRefs)
            // Map into [0, n+2): < n is a present node (any node, so self- and
            // forward-refs → cycles); otherwise an absent ghost (→ dangling).
            (ref % (n + 2)) < n ? 'e${ref % (n + 2)}' : 'ghost$ref',
        ],
      ),
  ];
}

/// Every permutation of [items] — used for bounded exhaustive permutation
/// checks at small `n` (factorial growth means callers must keep `n` small).
List<List<T>> permutationsOf<T>(List<T> items) {
  if (items.length <= 1) return [List<T>.of(items)];
  final result = <List<T>>[];
  for (var i = 0; i < items.length; i++) {
    final rest = [...items.sublist(0, i), ...items.sublist(i + 1)];
    for (final permutation in permutationsOf(rest)) {
      result.add([items[i], ...permutation]);
    }
  }
  return result;
}

/// Glados generators for projection-kernel property tests. Shared across the
/// four projection test files (the convergence harness this feeds is reused by
/// PRs 3–7 per the kernel plan).
extension AnyProjectionFixtures on Any {
  /// A well-formed DAG of 0..12 events. See [GeneratedDag].
  Generator<GeneratedDag> get projectionDag => ListAnys(this)
      .listWithLengthInRange(0, 12, _nodeSpec)
      .map((specs) => GeneratedDag(_buildEvents(specs)));

  /// A set of 0..9 parentless events (all concurrent). `canonicalOrder` must
  /// return these in `(hostId, id)` order, which makes this the clean test of
  /// the deterministic tiebreak.
  Generator<List<AgentEvent>> get independentEvents => ListAnys(this)
      .listWithLengthInRange(0, 9, IntAnys(this).intInRange(0, _hostCount * 3))
      .map(
        (hostSeeds) => [
          for (var i = 0; i < hostSeeds.length; i++)
            AgentEvent(
              id: 'e$i',
              hostId: 'h${hostSeeds[i] % _hostCount}',
              kind: AgentEventKind.message,
              vectorClock: VectorClock({'h${hostSeeds[i] % _hostCount}': 1}),
            ),
        ],
      );

  /// A non-negative seed for deterministic shuffles.
  Generator<int> get shuffleSeed => IntAnys(this).intInRange(0, 1 << 30);

  /// Events with **arbitrary** parent references — including self/forward refs
  /// (so the edge set may be **cyclic**) and absent ids (**dangling**). Ids are
  /// unique (`e0`..), so only a cycle can make `canonicalOrder` throw. Vector
  /// clocks are trivial (ordering is edge-driven). Use to property-test
  /// robustness on malformed graphs, not just well-formed DAGs.
  Generator<List<AgentEvent>> get arbitraryEdgeGraph => ListAnys(this)
      .listWithLengthInRange(0, 10, _edgeNode)
      .map(
        _buildArbitraryGraph,
      );

  /// A linear chain `e0 → e1 → … → e{n-1}` of 1..15 events (each event's parent
  /// is the previous one). Exactly one head: the last event. Guarantees the
  /// deep-chain topology is exercised rather than left to the RNG.
  Generator<List<AgentEvent>> get deepChainDag => IntAnys(this)
      .intInRange(1, 16)
      .map(
        (length) => [
          for (var i = 0; i < length; i++)
            AgentEvent(
              id: 'e$i',
              hostId: 'h0',
              kind: AgentEventKind.message,
              vectorClock: VectorClock({'h0': i + 1}), // dominates the previous
              causalParents: i == 0 ? const [] : ['e${i - 1}'],
            ),
        ],
      );

  /// A wide fork: a root `e0` with 1..15 children `e1..e{w}`, all parented to
  /// the root. Every child is a head; the root is not. Guarantees the
  /// wide-fork topology is exercised.
  Generator<List<AgentEvent>> get wideForkDag => IntAnys(this)
      .intInRange(1, 16)
      .map(
        (width) => [
          AgentEvent(
            id: 'e0',
            hostId: 'h0',
            kind: AgentEventKind.message,
            vectorClock: const VectorClock({'h0': 1}),
          ),
          for (var i = 1; i <= width; i++)
            AgentEvent(
              id: 'e$i',
              hostId: 'h0',
              kind: AgentEventKind.message,
              vectorClock: const VectorClock({'h0': 2}), // dominates the root
              causalParents: const ['e0'],
            ),
        ],
      );

  Generator<_EdgeNode> get _edgeNode => CombinableAny(this).combine2(
    IntAnys(this).intInRange(0, _hostCount * 3),
    ListAnys(this).listWithLengthInRange(
      0,
      3,
      IntAnys(this).intInRange(0, 1000),
    ),
    (hostSeed, parentRefs) =>
        _EdgeNode(hostSeed: hostSeed, parentRefs: parentRefs),
  );

  Generator<_NodeSpec> get _nodeSpec => CombinableAny(this).combine6(
    IntAnys(this).intInRange(0, 9),
    IntAnys(this).intInRange(0, AgentEventKind.values.length),
    AnyUtils(this).choose([true, false]),
    IntAnys(this).intInRange(0, 1000),
    AnyUtils(this).choose([true, false]),
    IntAnys(this).intInRange(0, 1000),
    (hostSeed, kindSeed, wantP1, p1Seed, wantP2, p2Seed) => _NodeSpec(
      hostSeed: hostSeed,
      kindSeed: kindSeed,
      wantParent1: wantP1,
      parent1Seed: p1Seed,
      wantParent2: wantP2,
      parent2Seed: p2Seed,
    ),
  );
}
