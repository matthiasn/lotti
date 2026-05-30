import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/agents/projection/projection_diagnostics.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'projection_test_fixtures.dart';

AgentEvent _ev(
  String id, {
  String host = 'h0',
  List<String> parents = const [],
  Map<String, int>? vclock,
  AgentEventKind kind = AgentEventKind.message,
}) => AgentEvent(
  id: id,
  hostId: host,
  kind: kind,
  causalParents: parents,
  vectorClock: VectorClock(vclock ?? {host: 1}),
);

void main() {
  group('diagnoseVectorClocks — property', () {
    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 150),
    ).test('a well-formed DAG has no VC or dangling-parent diagnostics', (dag) {
      expect(diagnoseVectorClocks(dag.events), isEmpty, reason: '$dag');
      expect(
        project(canonicalOrder(dag.events)).danglingParentIds,
        isEmpty,
        reason: '$dag',
      );
    }, tags: 'glados');
  });

  group('diagnoseVectorClocks — single edge', () {
    test('a strictly-dominating child is consistent', () {
      final events = [
        _ev('p', vclock: {'h0': 1}),
        _ev('c', vclock: {'h0': 2}, parents: ['p']),
      ];

      expect(diagnoseVectorClocks(events), isEmpty);
    });

    test('an equal clock is flagged as equal', () {
      final events = [
        _ev('p', vclock: {'h0': 1}),
        _ev('c', vclock: {'h0': 1}, parents: ['p']),
      ];

      expect(diagnoseVectorClocks(events), [
        const VcInconsistency(
          childId: 'c',
          parentId: 'p',
          status: VclockStatus.equal,
        ),
      ]);
    });

    test('a child dominated by its parent is flagged b_gt_a', () {
      final events = [
        _ev('p', vclock: {'h0': 2}),
        _ev('c', vclock: {'h0': 1}, parents: ['p']),
      ];

      expect(diagnoseVectorClocks(events).single.status, VclockStatus.b_gt_a);
    });

    test('a concurrent clock is flagged concurrent', () {
      final events = [
        _ev('p', vclock: {'h1': 1}),
        _ev('c', vclock: {'h0': 1}, parents: ['p']),
      ];

      expect(
        diagnoseVectorClocks(events).single.status,
        VclockStatus.concurrent,
      );
    });
  });

  group('diagnoseVectorClocks — dangling and ordering', () {
    test('skips edges whose parent is absent from the set', () {
      final events = [
        _ev('c', parents: ['ghost']),
      ];

      expect(diagnoseVectorClocks(events), isEmpty);
      // The dangling reference still surfaces structurally.
      expect(
        project(canonicalOrder(events)).danglingParentIds,
        ['ghost'],
      );
    });

    test('sorts diagnostics by (childId, parentId)', () {
      final events = [
        _ev('pa', host: 'h1', vclock: {'h1': 1}),
        _ev('pb', host: 'h2', vclock: {'h2': 1}),
        _ev('c', vclock: {'h0': 1}, parents: ['pb', 'pa']),
        _ev('d', vclock: {'h0': 1}, parents: ['c']),
      ];

      expect(diagnoseVectorClocks(events), const [
        VcInconsistency(
          childId: 'c',
          parentId: 'pa',
          status: VclockStatus.concurrent,
        ),
        VcInconsistency(
          childId: 'c',
          parentId: 'pb',
          status: VclockStatus.concurrent,
        ),
        VcInconsistency(
          childId: 'd',
          parentId: 'c',
          status: VclockStatus.equal,
        ),
      ]);
    });
  });

  group('VcInconsistency', () {
    test('values are equal by field', () {
      expect(
        const VcInconsistency(
          childId: 'c',
          parentId: 'p',
          status: VclockStatus.equal,
        ),
        const VcInconsistency(
          childId: 'c',
          parentId: 'p',
          status: VclockStatus.equal,
        ),
      );
    });

    test('stringifies child, parent, and status', () {
      const inconsistency = VcInconsistency(
        childId: 'c',
        parentId: 'p',
        status: VclockStatus.concurrent,
      );

      expect(inconsistency.toString(), 'VcInconsistency(c -> p: concurrent)');
    });
  });
}
