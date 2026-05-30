import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'projection_test_fixtures.dart';

/// Concise event builder. Vector clocks default to a trivial `{host: 1}`
/// because `canonicalOrder` never reads them — ordering is edge-driven.
AgentEvent _ev(
  String id, {
  String host = 'h0',
  List<String> parents = const [],
  AgentEventKind kind = AgentEventKind.message,
}) => AgentEvent(
  id: id,
  hostId: host,
  kind: kind,
  causalParents: parents,
  vectorClock: VectorClock({host: 1}),
);

List<String> _ids(List<AgentEvent> events) => events.map((e) => e.id).toList();

void main() {
  group('canonicalOrder — properties', () {
    glados.Glados2(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 150),
    ).test('is permutation-invariant (sampled shuffles)', (dag, seed) {
      final baseline = canonicalOrder(dag.events);
      final fromShuffle = canonicalOrder(dag.shuffled(seed));

      expect(
        _ids(fromShuffle),
        _ids(baseline),
        reason: 'shuffle seed=$seed for $dag',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 120),
    ).test('places every causal parent before its child', (dag) {
      final ordered = canonicalOrder(dag.events);
      final position = {
        for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
      };

      for (final event in dag.events) {
        for (final parentId in event.causalParents) {
          expect(
            position[parentId]! < position[event.id]!,
            isTrue,
            reason: 'parent $parentId must precede ${event.id} in $dag',
          );
        }
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.independentEvents,
      glados.ExploreConfig(numRuns: 120),
    ).test('orders concurrent events by (hostId, id)', (events) {
      final expected = [...events]
        ..sort((a, b) {
          final byHost = a.hostId.compareTo(b.hostId);
          return byHost != 0 ? byHost : a.id.compareTo(b.id);
        });

      expect(_ids(canonicalOrder(events)), _ids(expected), reason: '$events');
    }, tags: 'glados');

    test('is invariant across all permutations of a small DAG', () {
      final events = [
        _ev('a'),
        _ev('b', host: 'h1', parents: ['a']),
        _ev('c', parents: ['a']),
        _ev('d', host: 'h2', parents: ['b', 'c']),
        _ev('e', parents: ['d']),
      ];
      const expected = ['a', 'c', 'b', 'd', 'e'];

      for (final permutation in permutationsOf(events)) {
        expect(
          _ids(canonicalOrder(permutation)),
          expected,
          reason: 'permutation ${_ids(permutation)}',
        );
      }
    });
  });

  group('canonicalOrder — shapes', () {
    test('empty input yields empty order', () {
      expect(canonicalOrder(const <AgentEvent>[]), isEmpty);
    });

    test('single event yields that event', () {
      expect(_ids(canonicalOrder([_ev('a')])), ['a']);
    });

    test('linear chain is ordered root-to-tip', () {
      final events = [
        _ev('c', parents: ['b']),
        _ev('a'),
        _ev('b', parents: ['a']),
      ];

      expect(_ids(canonicalOrder(events)), ['a', 'b', 'c']);
    });

    test('a fork orders both children by (hostId, id) after the root', () {
      final events = [
        _ev('root'),
        _ev('child-z', host: 'h1', parents: ['root']),
        _ev('child-a', parents: ['root']),
      ];

      // child-a (h0) precedes child-z (h1); both follow root.
      expect(_ids(canonicalOrder(events)), ['root', 'child-a', 'child-z']);
    });

    test('breaks ties by id when hosts are equal', () {
      final events = [_ev('e2'), _ev('e1'), _ev('e0')];

      expect(_ids(canonicalOrder(events)), ['e0', 'e1', 'e2']);
    });
  });

  group('canonicalOrder — dangling parents', () {
    test('treats an absent parent as a root and does not throw', () {
      final events = [
        _ev('a', parents: ['ghost']),
      ];

      expect(_ids(canonicalOrder(events)), ['a']);
    });

    test('orders present-vs-dangling-rooted events deterministically', () {
      final events = [
        _ev('b', host: 'h1', parents: ['missing']),
        _ev('a', parents: ['also-missing']),
      ];

      expect(_ids(canonicalOrder(events)), ['a', 'b']);
    });
  });

  group('canonicalOrder — duplicate ids', () {
    test('rejects two distinct events sharing an id', () {
      final events = [_ev('x'), _ev('x', host: 'h1')];

      expect(
        () => canonicalOrder(events),
        throwsA(
          isA<DuplicateEventIdException>().having(
            (e) => e.duplicateId,
            'duplicateId',
            'x',
          ),
        ),
      );
    });

    test('deduplicates a value-equal event appearing twice', () {
      final event = _ev('x');

      expect(_ids(canonicalOrder([event, _ev('x')])), ['x']);
    });

    test('treats parent-order-only differences as the same event', () {
      // The same logical node synced from two devices, parents listed in
      // different order, must dedupe — not be rejected as a duplicate id.
      final events = [
        _ev('a'),
        _ev('b'),
        _ev('x', parents: ['a', 'b']),
        _ev('x', parents: ['b', 'a']),
      ];

      expect(_ids(canonicalOrder(events)), ['a', 'b', 'x']);
    });

    test('DuplicateEventIdException stringifies the colliding id', () {
      expect(
        const DuplicateEventIdException('x').toString(),
        contains('"x"'),
      );
    });
  });

  group('canonicalOrder — cycles', () {
    test('throws on a two-node cycle, reporting the trapped ids', () {
      final events = [
        _ev('a', parents: ['b']),
        _ev('b', parents: ['a']),
      ];

      expect(
        () => canonicalOrder(events),
        throwsA(
          isA<ProjectionCycleException>().having(
            (e) => e.involvedIds,
            'involvedIds',
            ['a', 'b'],
          ),
        ),
      );
    });

    test('throws on a self-referential edge', () {
      final events = [
        _ev('a', parents: ['a']),
      ];

      expect(
        () => canonicalOrder(events),
        throwsA(
          isA<ProjectionCycleException>().having(
            (e) => e.involvedIds,
            'involvedIds',
            ['a'],
          ),
        ),
      );
    });

    test('emits the acyclic prefix and only traps the cycle', () {
      // root -> a -> b -> a (cycle between a and b); root is orderable.
      final events = [
        _ev('root'),
        _ev('a', parents: ['root', 'b']),
        _ev('b', parents: ['a']),
      ];

      expect(
        () => canonicalOrder(events),
        throwsA(
          isA<ProjectionCycleException>().having(
            (e) => e.involvedIds,
            'involvedIds',
            ['a', 'b'],
          ),
        ),
      );
    });

    test('ProjectionCycleException stringifies the involved ids', () {
      expect(
        const ProjectionCycleException(['a', 'b']).toString(),
        contains('a, b'),
      );
    });
  });
}
