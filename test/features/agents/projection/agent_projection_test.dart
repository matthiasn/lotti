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
  AgentEventKind kind = AgentEventKind.message,
}) => AgentEvent(
  id: id,
  hostId: host,
  kind: kind,
  causalParents: parents,
  vectorClock: VectorClock({host: 1}),
);

AgentProjection _projectionOf(List<AgentEvent> events) =>
    project(canonicalOrder(events));

void main() {
  group('project — properties', () {
    glados.Glados2(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 150),
    ).test('is identical for any shuffle of the same event set', (dag, seed) {
      final baseline = _projectionOf(dag.events);
      final fromShuffle = _projectionOf(dag.shuffled(seed));

      expect(fromShuffle, baseline, reason: 'shuffle seed=$seed for $dag');
    }, tags: 'glados');

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 120),
    ).test('headIds are exactly the events no present event references', (dag) {
      final present = {for (final e in dag.events) e.id};
      final referenced = {
        for (final e in dag.events)
          for (final p in e.causalParents)
            if (present.contains(p)) p,
      };
      final expectedHeads = dag.events
          .map((e) => e.id)
          .where((id) => !referenced.contains(id));

      final headIds = _projectionOf(dag.events).headIds;

      expect(headIds.toSet(), expectedHeads.toSet(), reason: '$dag');
      // A non-empty DAG always has at least one tip.
      expect(headIds.isNotEmpty, dag.events.isNotEmpty, reason: '$dag');
    }, tags: 'glados');

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 120),
    ).test('latestReportId is the last report in canonical order', (dag) {
      final reports = canonicalOrder(
        dag.events,
      ).where((e) => e.kind == AgentEventKind.report).toList();
      final expected = reports.isEmpty ? null : reports.last.id;

      expect(
        _projectionOf(dag.events).latestReportId,
        expected,
        reason: '$dag',
      );
    }, tags: 'glados');

    glados.Glados2(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'a removed event surfaces as a dangling parent, never crashes',
      (
        dag,
        seed,
      ) {
        if (dag.events.isEmpty) return;
        // Drop one event but keep the rest: it becomes the only newly-absent id,
        // so it is dangling iff a surviving event still references it.
        final removed = dag.events[seed % dag.events.length];
        final remaining = [
          for (final e in dag.events)
            if (e.id != removed.id) e,
        ];

        final projection = project(canonicalOrder(remaining)); // must not throw
        final stillReferenced = remaining.any(
          (e) => e.causalParents.contains(removed.id),
        );

        expect(
          projection.danglingParentIds,
          stillReferenced ? [removed.id] : <String>[],
          reason: 'removed=${removed.id} in $dag',
        );
      },
      tags: 'glados',
    );
  });

  group('project — shapes', () {
    test('empty set yields an empty projection', () {
      expect(
        project(const <AgentEvent>[]),
        const AgentProjection(
          headIds: [],
          latestReportId: null,
          danglingParentIds: [],
        ),
      );
    });

    test('single event is the only head', () {
      final projection = _projectionOf([_ev('a')]);

      expect(projection.headIds, ['a']);
      expect(projection.latestReportId, isNull);
      expect(projection.danglingParentIds, isEmpty);
    });

    test('linear chain has a single head at the tip', () {
      final projection = _projectionOf([
        _ev('a'),
        _ev('b', parents: ['a']),
        _ev('c', parents: ['b']),
      ]);

      expect(projection.headIds, ['c']);
    });

    test('a fork yields two heads, in canonical order', () {
      final projection = _projectionOf([
        _ev('root'),
        _ev('child-z', host: 'h1', parents: ['root']),
        _ev('child-a', parents: ['root']),
      ]);

      expect(projection.headIds, ['child-a', 'child-z']);
    });

    test('a join collapses two branches back to one head', () {
      final projection = _projectionOf([
        _ev('a'),
        _ev('b', host: 'h1'),
        _ev('c', host: 'h2', parents: ['a', 'b']),
      ]);

      expect(projection.headIds, ['c']);
    });
  });

  group('project — latestReportId', () {
    test('is null when no report is present', () {
      expect(_projectionOf([_ev('a'), _ev('b')]).latestReportId, isNull);
    });

    test('is the last report in canonical order', () {
      final projection = _projectionOf([
        _ev('r1', kind: AgentEventKind.report),
        _ev('r2', kind: AgentEventKind.report, parents: ['r1']),
        _ev('m', parents: ['r2']),
      ]);

      expect(projection.latestReportId, 'r2');
    });

    test('ignores non-report kinds when picking the latest report', () {
      final projection = _projectionOf([
        _ev('r', kind: AgentEventKind.report),
        _ev('o', kind: AgentEventKind.observation, parents: ['r']),
        _ev('s', kind: AgentEventKind.summary, parents: ['o']),
      ]);

      expect(projection.latestReportId, 'r');
    });
  });

  group('project — dangling parents', () {
    test('surfaces absent parents, sorted and de-duplicated', () {
      final projection = _projectionOf([
        _ev('x', parents: ['z', 'a']),
        _ev('y', parents: ['a']),
      ]);

      expect(projection.danglingParentIds, ['a', 'z']);
      // Neither x nor y is referenced by a present event, so both are heads.
      expect(projection.headIds.toSet(), {'x', 'y'});
    });
  });

  group('project — shape families', () {
    glados.Glados(
      glados.any.deepChainDag,
      glados.ExploreConfig(numRuns: 60),
    ).test('a deep chain orders root-to-tip with a single head', (events) {
      final orderedIds = canonicalOrder(events).map((e) => e.id).toList();
      final expectedOrder = [for (var i = 0; i < events.length; i++) 'e$i'];

      expect(orderedIds, expectedOrder, reason: 'chain of ${events.length}');
      expect(
        project(canonicalOrder(events)).headIds,
        ['e${events.length - 1}'],
        reason: 'chain of ${events.length}',
      );
    }, tags: 'glados');

    glados.Glados(
      glados.any.wideForkDag,
      glados.ExploreConfig(numRuns: 60),
    ).test('a wide fork makes every child a head, never the root', (events) {
      final heads = project(canonicalOrder(events)).headIds.toSet();
      final children = {
        for (final e in events)
          if (e.id != 'e0') e.id,
      };

      expect(heads, children, reason: 'fork of ${events.length - 1}');
      expect(heads.contains('e0'), isFalse, reason: 'fork of ${events.length}');
    }, tags: 'glados');

    test('a diamond collapses to the single join head', () {
      final projection = _projectionOf([
        _ev('a'),
        _ev('b', parents: ['a']),
        _ev('c', parents: ['a']),
        _ev('d', parents: ['b', 'c']),
      ]);

      expect(projection.headIds, ['d']);
    });
  });
}
