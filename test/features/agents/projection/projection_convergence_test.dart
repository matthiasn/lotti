import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'projection_test_fixtures.dart';

AgentEvent _ev(
  String id, {
  String host = 'h0',
  List<String> parents = const [],
}) => AgentEvent(
  id: id,
  hostId: host,
  kind: AgentEventKind.message,
  causalParents: parents,
  vectorClock: VectorClock({host: 1}),
);

/// Projects a device's view: canonical-order then fold. The thing two devices
/// must agree on once they hold the same event set.
AgentProjection _deviceView(List<AgentEvent> received) =>
    project(canonicalOrder(received));

void main() {
  group('two-device convergence', () {
    glados.Glados3(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'two devices holding the same set converge to one projection',
      (
        dag,
        seedA,
        seedB,
      ) {
        // Each device received the full set in its own arrival order.
        final deviceA = _deviceView(dag.shuffled(seedA));
        final deviceB = _deviceView(dag.shuffled(seedB));

        expect(deviceA, deviceB, reason: 'seedA=$seedA seedB=$seedB for $dag');
        // ...and both equal the build-order baseline.
        expect(deviceA, _deviceView(dag.events), reason: '$dag');
      },
      tags: 'glados',
    );
  });

  group('partially-overlapping device views', () {
    // Shared chain a -> b -> c -> d, plus a concurrent branch e off b.
    final a = _ev('a');
    final b = _ev('b', parents: ['a']);
    final c = _ev('c', parents: ['b']);
    final d = _ev('d', parents: ['c']);
    final e = _ev('e', host: 'h1', parents: ['b']);

    test('diverge while one device is missing events, then converge', () {
      // Device A is missing d and e; device B has everything.
      final deviceA = _deviceView([a, b, c]);
      final deviceB = _deviceView([a, b, c, d, e]);

      expect(deviceA.headIds, ['c']);
      expect(deviceB.headIds.toSet(), {'d', 'e'});
      expect(deviceA, isNot(deviceB));

      // After sync delivers d and e, A holds the same set as B and agrees.
      final deviceAAfterSync = _deviceView([a, b, c, d, e]);
      expect(deviceAAfterSync, deviceB);
    });

    test('disjoint partial views converge once unioned', () {
      // A started with the trunk; B started with the branch tip + a head.
      final deviceAStart = [a, b, c];
      final deviceBStart = [b, e, d, c];

      // The union is the same regardless of who contributed which event.
      final unionViaA = _deviceView([...deviceAStart, d, e]);
      final unionViaB = _deviceView([a, ...deviceBStart]);

      expect(unionViaA, unionViaB);
      expect(unionViaA.headIds.toSet(), {'d', 'e'});
    });
  });
}
