import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';

void main() {
  // The deterministic clock the source pins every scenario to
  // (`final DateTime _now = DateTime(2026, 6, 18, 9);`). Asserting against this
  // constant guards the "never DateTime.now()" contract in the model.
  final expectedNow = DateTime(2026, 6, 18, 9);

  /// Validates the structural invariants that must hold for *every* scenario,
  /// regardless of its specific shape. Called by each scenario test (DRY) so
  /// scenario-specific tests only layer the distinctive assertions on top.
  void expectStructurallyValid(GraphScenario scenario) {
    final reason = 'scenario "${scenario.name}"';

    // Deterministic clock — never DateTime.now().
    expect(scenario.now, expectedNow, reason: 'now must be fixed for $reason');

    // Non-empty graph.
    expect(scenario.nodes, isNotEmpty, reason: 'nodes for $reason');

    // Node ids are unique within the scenario.
    final ids = scenario.nodes.map((n) => n.id).toList();
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'node ids must be unique in $reason',
    );

    // The seed corresponds to an existing node (nodeById must not throw).
    expect(
      () => scenario.nodeById(scenario.seedId),
      returnsNormally,
      reason: 'seedId "${scenario.seedId}" must exist in $reason',
    );
    expect(
      scenario.nodeById(scenario.seedId).id,
      scenario.seedId,
      reason: 'nodeById must round-trip the seed for $reason',
    );

    // Every edge endpoint references an existing node id (no dangling edges).
    final idSet = ids.toSet();
    for (final edge in scenario.edges) {
      expect(
        idSet,
        contains(edge.fromId),
        reason: 'dangling fromId "${edge.fromId}" in $reason',
      );
      expect(
        idSet,
        contains(edge.toId),
        reason: 'dangling toId "${edge.toId}" in $reason',
      );
    }

    // Every node createdAt is at or before `now`, so ageDays is never negative
    // (the recency-as-luminance encoding relies on this).
    for (final node in scenario.nodes) {
      expect(
        scenario.ageDays(node),
        greaterThanOrEqualTo(0),
        reason: 'node "${node.id}" age must be >= 0 in $reason',
      );
    }
  }

  /// Counts nodes of a given type in a scenario.
  int countType(GraphScenario s, GraphNodeType type) =>
      s.nodes.where((n) => n.type == type).length;

  /// Counts edges of a given kind in a scenario.
  int countKind(GraphScenario s, GraphEdgeKind kind) =>
      s.edges.where((e) => e.kind == kind).length;

  group('category constants', () {
    test('categoryOrder lists every canonical category exactly once', () {
      expect(categoryOrder, [
        catWork,
        catWriting,
        catHealth,
        catLearning,
        catHome,
        catAdmin,
      ]);
      expect(
        categoryOrder.toSet().length,
        categoryOrder.length,
        reason: 'categories must be distinct for stable color assignment',
      );
    });
  });

  group('taskEgoNetworkScenario', () {
    final scenario = taskEgoNetworkScenario();

    test('satisfies structural invariants', () {
      expectStructurallyValid(scenario);
    });

    test('is the headline ~20-node balanced ego-network', () {
      expect(scenario.name, 'Task ego-network');
      expect(scenario.seedId, 't0');
      // Documented as ~20 nodes; the hand-authored graph has exactly 18.
      expect(scenario.nodes.length, 18);
    });

    test('seed is a task contained by exactly one project', () {
      expect(scenario.nodeById('t0').type, GraphNodeType.task);

      final containment = scenario.edges
          .where((e) => e.kind == GraphEdgeKind.containment)
          .toList();
      expect(containment.length, 1);
      expect(containment.single.fromId, 'p0');
      expect(containment.single.toId, 't0');
      expect(scenario.nodeById('p0').type, GraphNodeType.project);
    });

    test('seed fans out to 3 linked tasks and 5 log entries', () {
      final assocFromSeed = scenario.edges
          .where(
            (e) => e.kind == GraphEdgeKind.association && e.fromId == 't0',
          )
          .map((e) => e.toId)
          .toSet();
      // 3 tasks + 5 logs + the checklist node = 9 outgoing associations.
      expect(assocFromSeed, containsAll(['t1', 't2', 't3']));
      expect(assocFromSeed, containsAll(['l1', 'l2', 'l3', 'l4', 'l5']));
      expect(assocFromSeed, contains('c1'));
      expect(assocFromSeed.length, 9);
    });

    test('carries AI provenance, a rating and a 4-item checklist', () {
      expect(countKind(scenario, GraphEdgeKind.provenance), 2);
      expect(countKind(scenario, GraphEdgeKind.evaluation), 1);

      // Checklist c1 owns exactly four checklist items.
      final checklistEdges = scenario.edges
          .where((e) => e.kind == GraphEdgeKind.checklist)
          .toList();
      expect(checklistEdges.length, 4);
      expect(checklistEdges.every((e) => e.fromId == 'c1'), isTrue);
      expect(countType(scenario, GraphNodeType.checklistItem), 4);
    });
  });

  group('busyTaskScenario', () {
    final scenario = busyTaskScenario();

    test('satisfies structural invariants', () {
      expectStructurallyValid(scenario);
    });

    test('is dense: 12 linked tasks + 12 logs + 6 checklist items', () {
      expect(scenario.name, 'Busy task');
      expect(scenario.seedId, 'b0');

      // 5 base nodes (task, project, rating, ai, checklist)
      // + 12 tasks + 12 logs + 6 checklist items = 35.
      expect(scenario.nodes.length, 35);

      // 12 linked workstream tasks (bt0..bt11) plus the seed task itself.
      expect(countType(scenario, GraphNodeType.task), 13);
      expect(countType(scenario, GraphNodeType.checklistItem), 6);
    });

    test('seed is the dense hub linking 12 tasks and 12 logs', () {
      final assocFromSeed = scenario.edges
          .where(
            (e) => e.kind == GraphEdgeKind.association && e.fromId == 'b0',
          )
          .toList();
      // 12 tasks + 12 logs + the checklist = 25 outgoing associations.
      expect(assocFromSeed.length, 25);
    });

    test('checklist bc owns the 6 checklist items', () {
      final checklistEdges = scenario.edges
          .where((e) => e.kind == GraphEdgeKind.checklist)
          .toList();
      expect(checklistEdges.length, 6);
      expect(checklistEdges.every((e) => e.fromId == 'bc'), isTrue);
    });

    test('linked workstream tasks cycle through five categories', () {
      const linkedTaskCats = [
        catWork,
        catWriting,
        catHealth,
        catLearning,
        catHome,
      ];
      for (var i = 0; i < 12; i++) {
        expect(
          scenario.nodeById('bt$i').categoryId,
          linkedTaskCats[i % linkedTaskCats.length],
          reason: 'workstream bt$i category',
        );
      }
    });
  });

  group('lightTaskScenario', () {
    final scenario = lightTaskScenario();

    test('satisfies structural invariants', () {
      expectStructurallyValid(scenario);
    });

    test('is the minimal 5-node graph that still looks populated', () {
      expect(scenario.name, 'Light task');
      expect(scenario.seedId, 's0');
      expect(scenario.nodes.length, 5);
      // One project containment + three associations off the seed.
      expect(countKind(scenario, GraphEdgeKind.containment), 1);
      expect(
        scenario.edges
            .where(
              (e) => e.kind == GraphEdgeKind.association && e.fromId == 's0',
            )
            .length,
        3,
      );
    });
  });

  group('exploreWorldScenario', () {
    final scenario = exploreWorldScenario();

    test('satisfies structural invariants', () {
      expectStructurallyValid(scenario);
    });

    test('is a large multi-project world (~120 nodes)', () {
      expect(scenario.name, 'Explore world');
      expect(scenario.seedId, 'P0T0');
      // Index-driven generation yields exactly 119 nodes ("~120").
      expect(scenario.nodes.length, 119);
    });

    test('has 5 projects, each containing 5 tasks', () {
      expect(countType(scenario, GraphNodeType.project), 5);
      // 5 projects * 5 tasks each.
      expect(countType(scenario, GraphNodeType.task), 25);
      // Each task is contained by its project.
      expect(countKind(scenario, GraphEdgeKind.containment), 25);
    });

    test('projects are cross-linked so clusters are reachable', () {
      // Five ring links (lastTask[p] -> firstTask[next]) plus two explicit
      // extra cross-project bridges (P0T2->P2T1, P1T3->P3T0).
      bool crosses(GraphEdge e) =>
          e.kind == GraphEdgeKind.association &&
          e.fromId.startsWith('P') &&
          e.toId.startsWith('P') &&
          e.fromId.substring(0, 2) != e.toId.substring(0, 2);

      final crossLinks = scenario.edges.where(crosses).toList();
      expect(
        crossLinks.length,
        greaterThanOrEqualTo(5),
        reason: 'at least the ring of cross-project links must exist',
      );

      // The two documented explicit bridges are present.
      expect(
        crossLinks.any((e) => e.fromId == 'P0T2' && e.toId == 'P2T1'),
        isTrue,
      );
      expect(
        crossLinks.any((e) => e.fromId == 'P1T3' && e.toId == 'P3T0'),
        isTrue,
      );
    });

    test('carries AI summaries, ratings and checklists across the world', () {
      expect(
        countType(scenario, GraphNodeType.aiResponse),
        greaterThan(0),
        reason: 'AI provenance nodes',
      );
      expect(
        countType(scenario, GraphNodeType.rating),
        greaterThan(0),
        reason: 'rating nodes',
      );
      // Exactly one checklist per project (created when t == 1), each with 4
      // items.
      expect(countType(scenario, GraphNodeType.checklist), 5);
      expect(countType(scenario, GraphNodeType.checklistItem), 20);
    });
  });

  group('aggregate scenario lists', () {
    test('allTaskScenarios is non-empty, headline-first, and structural', () {
      final list = allTaskScenarios();
      expect(list, isNotEmpty);
      expect(list.length, 3);
      expect(
        list.map((s) => s.name),
        ['Task ego-network', 'Busy task', 'Light task'],
      );
      list.forEach(expectStructurallyValid);
    });

    test(
      'allScenarios leads with the explorable world, then the task views',
      () {
        final list = allScenarios();
        expect(list, isNotEmpty);
        expect(list.length, 4);
        expect(list.first.name, 'Explore world');
        // The task scenarios are appended after the world.
        expect(
          list.skip(1).map((s) => s.name),
          ['Task ego-network', 'Busy task', 'Light task'],
        );
        list.forEach(expectStructurallyValid);
      },
    );

    test('scenario names are distinct across the full set', () {
      final names = allScenarios().map((s) => s.name).toList();
      expect(names.toSet().length, names.length);
    });
  });
}
