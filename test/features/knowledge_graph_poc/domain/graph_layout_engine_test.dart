import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12);

  GraphNode node({
    required String id,
    GraphNodeType type = GraphNodeType.textEntry,
    String label = 'Label',
    String categoryId = 'cat',
    DateTime? createdAt,
  }) => GraphNode(
    id: id,
    type: type,
    label: label,
    categoryId: categoryId,
    createdAt: createdAt ?? now,
  );

  GraphScenario scenario({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    String seedId = 'focus',
  }) => GraphScenario(
    name: 'test',
    seedId: seedId,
    nodes: nodes,
    edges: edges,
    now: now,
  );

  double dist(Offset a, Offset b) => (a - b).distance;

  group('GraphLayout', () {
    test('exposes the positions map it was constructed with', () {
      const positions = {'a': Offset(1, 2), 'b': Offset(3, 4)};
      const layout = GraphLayout(positions);
      expect(layout.positions, positions);
    });
  });

  group('computeGraphLayout', () {
    test('pins the focus node at the origin', () {
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'a'),
          node(id: 'b'),
        ],
        edges: const [
          GraphEdge(
            fromId: 'focus',
            toId: 'a',
            kind: GraphEdgeKind.association,
          ),
          GraphEdge(
            fromId: 'focus',
            toId: 'b',
            kind: GraphEdgeKind.containment,
          ),
        ],
      );

      final layout = computeGraphLayout(s);
      expect(layout.positions['focus'], Offset.zero);
    });

    test('assigns a position to every node id', () {
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'a'),
          node(id: 'b'),
          node(id: 'c'),
        ],
        edges: const [
          GraphEdge(
            fromId: 'focus',
            toId: 'a',
            kind: GraphEdgeKind.association,
          ),
          GraphEdge(
            fromId: 'focus',
            toId: 'b',
            kind: GraphEdgeKind.containment,
          ),
        ],
      );

      final layout = computeGraphLayout(s);
      expect(
        layout.positions.keys.toSet(),
        {'focus', 'a', 'b', 'c'},
      );
      for (final p in layout.positions.values) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    test(
      'is deterministic: same seed and iterations → identical positions',
      () {
        final s = scenario(
          nodes: [
            node(id: 'focus', type: GraphNodeType.task),
            node(id: 'a'),
            node(id: 'b'),
            node(id: 'c'),
          ],
          edges: const [
            GraphEdge(
              fromId: 'focus',
              toId: 'a',
              kind: GraphEdgeKind.containment,
            ),
            GraphEdge(
              fromId: 'focus',
              toId: 'b',
              kind: GraphEdgeKind.association,
            ),
            GraphEdge(
              fromId: 'a',
              toId: 'c',
              kind: GraphEdgeKind.checklist,
            ),
          ],
        );

        final first = computeGraphLayout(s);
        final second = computeGraphLayout(s);

        expect(first.positions.keys.toSet(), second.positions.keys.toSet());
        for (final id in first.positions.keys) {
          expect(first.positions[id], second.positions[id]);
        }
      },
    );

    test('different seeds can produce different layouts', () {
      // A disconnected node uses the seed-driven jitter fallback, so different
      // seeds yield different positions for it.
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'lonely'),
        ],
        edges: const [],
      );

      final a = computeGraphLayout(s, seed: 1);
      final b = computeGraphLayout(s, seed: 2);
      expect(a.positions['lonely'], isNot(b.positions['lonely']));
    });

    test('a fully disconnected node lands within the jitter envelope before '
        'relaxation pushes it out', () {
      // With only the focus + one disconnected node, repulsion pushes the
      // straggler away from the origin, but it must still receive a finite
      // position distinct from the pinned origin.
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'lonely'),
        ],
        edges: const [],
        // No edge touches the seed, so BFS only reaches the focus itself.
      );

      final layout = computeGraphLayout(s);
      expect(layout.positions['focus'], Offset.zero);
      final lonely = layout.positions['lonely']!;
      expect(lonely.dx.isFinite, isTrue);
      expect(lonely.dy.isFinite, isTrue);
      // Repulsion from the pinned focus moves it off the origin.
      expect(lonely, isNot(Offset.zero));
    });

    test('seeds containment neighbor toward the top sector (negative y)', () {
      // A single containment neighbor sits in the top sector (base = -pi/2),
      // n == 1 → t == 0 → angle == base, so before relaxation it is at
      // (cos(-pi/2), sin(-pi/2)) * ring = (~0, -ring). With zero iterations no
      // relaxation runs, so we can assert the seeded sector exactly.
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'project', type: GraphNodeType.project),
        ],
        edges: const [
          GraphEdge(
            fromId: 'project',
            toId: 'focus',
            kind: GraphEdgeKind.containment,
          ),
        ],
      );

      final layout = computeGraphLayout(s, iterations: 0);
      final p = layout.positions['project']!;
      // Top sector: dy strongly negative, dx ~ 0.
      expect(p.dy, lessThan(-200));
      expect(p.dx.abs(), lessThan(1));
      // Seeded onto the 1-hop ring (radius 225).
      expect(dist(p, Offset.zero), closeTo(225, 1e-6));
    });

    test('seeds the four directional sectors into distinct regions '
        '(no relaxation)', () {
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'project', type: GraphNodeType.project),
          node(id: 'ai', type: GraphNodeType.aiResponse),
          node(id: 'rating', type: GraphNodeType.rating),
          node(id: 'checklist', type: GraphNodeType.checklist),
          node(id: 'linkedTask', type: GraphNodeType.task),
          node(id: 'log'),
        ],
        edges: const [
          // containment → top
          GraphEdge(
            fromId: 'project',
            toId: 'focus',
            kind: GraphEdgeKind.containment,
          ),
          // provenance → upper-left
          GraphEdge(
            fromId: 'ai',
            toId: 'focus',
            kind: GraphEdgeKind.provenance,
          ),
          // evaluation → upper-right
          GraphEdge(
            fromId: 'rating',
            toId: 'focus',
            kind: GraphEdgeKind.evaluation,
          ),
          // checklist relation → lower-right
          GraphEdge(
            fromId: 'focus',
            toId: 'checklist',
            kind: GraphEdgeKind.checklist,
          ),
          // association + task type → right
          GraphEdge(
            fromId: 'focus',
            toId: 'linkedTask',
            kind: GraphEdgeKind.association,
          ),
          // association + non-task/checklist type → bottom
          GraphEdge(
            fromId: 'focus',
            toId: 'log',
            kind: GraphEdgeKind.association,
          ),
        ],
      );

      final layout = computeGraphLayout(s, iterations: 0);
      final project = layout.positions['project']!;
      final ai = layout.positions['ai']!;
      final rating = layout.positions['rating']!;
      final checklist = layout.positions['checklist']!;
      final linkedTask = layout.positions['linkedTask']!;
      final log = layout.positions['log']!;

      // top
      expect(project.dy, lessThan(0));
      expect(project.dx.abs(), lessThan(10));
      // upper-left
      expect(ai.dx, lessThan(0));
      expect(ai.dy, lessThan(0));
      // upper-right
      expect(rating.dx, greaterThan(0));
      expect(rating.dy, lessThan(0));
      // lower-right (checklist sector, angle 0.95)
      expect(checklist.dx, greaterThan(0));
      expect(checklist.dy, greaterThan(0));
      // right (linked task, angle 0.15)
      expect(linkedTask.dx, greaterThan(0));
      expect(linkedTask.dy.abs(), lessThan(linkedTask.dx));
      // bottom (log entry, angle ~ pi/2 + 0.25)
      expect(log.dy, greaterThan(0));

      // Each directional neighbor is on the 1-hop ring.
      for (final p in [project, ai, rating, checklist, linkedTask, log]) {
        expect(dist(p, Offset.zero), closeTo(225, 1e-6));
      }
    });

    test(
      'a checklist node reached by association (non-checklist edge) uses the '
      'checklist node-type sector',
      () {
        // The association branch with node.type == checklist returns 0.95
        // (lower-right) — distinct from the textEntry default bottom sector.
        final s = scenario(
          nodes: [
            node(id: 'focus', type: GraphNodeType.task),
            node(id: 'cl', type: GraphNodeType.checklist),
          ],
          edges: const [
            GraphEdge(
              fromId: 'focus',
              toId: 'cl',
              kind: GraphEdgeKind.association,
            ),
          ],
        );

        final layout = computeGraphLayout(s, iterations: 0);
        final p = layout.positions['cl']!;
        // angle 0.95 → lower-right quadrant.
        expect(p.dx, greaterThan(0));
        expect(p.dy, greaterThan(0));
      },
    );

    test(
      'an association edge to a default-typed node uses the bottom sector',
      () {
        // 'mid' is one hop from the focus via an association edge, and its type
        // (textEntry) hits neither the task nor checklist case, so _baseSector
        // returns the default bottom sector (pi/2 + 0.25).
        final s = scenario(
          nodes: [
            node(id: 'focus', type: GraphNodeType.task),
            node(id: 'mid'),
          ],
          edges: const [
            GraphEdge(
              fromId: 'focus',
              toId: 'mid',
              kind: GraphEdgeKind.association,
            ),
          ],
        );

        final layout = computeGraphLayout(s, iterations: 0);
        final p = layout.positions['mid']!;
        // Default (textEntry, association) → bottom sector.
        expect(p.dy, greaterThan(0));
      },
    );

    test('fans out multiple neighbors sharing the same sector', () {
      // Two log entries share the bottom sector; the fan spreads them apart so
      // they do not coincide (n == 2 → t in {-1, 1}).
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'log1'),
          node(id: 'log2'),
        ],
        edges: const [
          GraphEdge(
            fromId: 'focus',
            toId: 'log1',
            kind: GraphEdgeKind.association,
          ),
          GraphEdge(
            fromId: 'focus',
            toId: 'log2',
            kind: GraphEdgeKind.association,
          ),
        ],
      );

      final layout = computeGraphLayout(s, iterations: 0);
      final p1 = layout.positions['log1']!;
      final p2 = layout.positions['log2']!;
      expect(p1, isNot(p2));
      // Both still on the ring.
      expect(dist(p1, Offset.zero), closeTo(225, 1e-6));
      expect(dist(p2, Offset.zero), closeTo(225, 1e-6));
    });

    test('seeds a depth-2 node around its parent on the inner ring', () {
      // focus → checklist (hop 1) → item (hop 2). The item is seeded at
      // parent + ring2 along the outward direction. With a single child
      // (n == 1 → t == 0) angle == outward, so dist(item, parent) == ring2.
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'checklist', type: GraphNodeType.checklist),
          node(id: 'item', type: GraphNodeType.checklistItem),
        ],
        edges: const [
          GraphEdge(
            fromId: 'focus',
            toId: 'checklist',
            kind: GraphEdgeKind.checklist,
          ),
          GraphEdge(
            fromId: 'checklist',
            toId: 'item',
            kind: GraphEdgeKind.checklist,
          ),
        ],
      );

      final layout = computeGraphLayout(s, iterations: 0);
      final parent = layout.positions['checklist']!;
      final item = layout.positions['item']!;
      expect(dist(item, parent), closeTo(104, 1e-6));
      // The depth-2 node sits further from the origin than its parent
      // (fanned outward).
      expect(dist(item, Offset.zero), greaterThan(dist(parent, Offset.zero)));
    });

    test(
      'relaxation keeps the pinned focus at the origin while moving others',
      () {
        final s = scenario(
          nodes: [
            node(id: 'focus', type: GraphNodeType.task),
            node(id: 'a'),
            node(id: 'b'),
            node(id: 'c'),
            node(id: 'd'),
          ],
          edges: const [
            GraphEdge(
              fromId: 'focus',
              toId: 'a',
              kind: GraphEdgeKind.containment,
            ),
            GraphEdge(
              fromId: 'focus',
              toId: 'b',
              kind: GraphEdgeKind.association,
            ),
            GraphEdge(
              fromId: 'focus',
              toId: 'c',
              kind: GraphEdgeKind.provenance,
            ),
            GraphEdge(
              fromId: 'focus',
              toId: 'd',
              kind: GraphEdgeKind.evaluation,
            ),
          ],
        );

        final seeded = computeGraphLayout(s, iterations: 0);
        final relaxed = computeGraphLayout(s);

        // Pinned focus unmoved by relaxation.
        expect(relaxed.positions['focus'], Offset.zero);
        // At least one non-pinned node moved during the relaxation pass.
        final moved = ['a', 'b', 'c', 'd'].any(
          (id) => seeded.positions[id] != relaxed.positions[id],
        );
        expect(moved, isTrue);
      },
    );

    test('handles a scenario with only the focus node', () {
      final s = scenario(
        nodes: [node(id: 'focus', type: GraphNodeType.task)],
        edges: const [],
      );

      final layout = computeGraphLayout(s);
      expect(layout.positions, {'focus': Offset.zero});
    });

    test('separates coincident nodes via the repulsion jitter branch', () {
      // Two disconnected nodes both start near the origin (the focus is at
      // origin and disconnected jitter is small). The dist < 0.01 repulsion
      // jitter branch ensures they never sit exactly on top of each other.
      final s = scenario(
        nodes: [
          node(id: 'focus', type: GraphNodeType.task),
          node(id: 'x'),
          node(id: 'y'),
        ],
        edges: const [],
      );

      final layout = computeGraphLayout(s);
      expect(layout.positions['x'], isNot(layout.positions['y']));
    });
  });

  group('computeWorldLayout', () {
    GraphScenario world() => scenario(
      nodes: [
        node(id: 'n0', type: GraphNodeType.task),
        node(id: 'n1'),
        node(id: 'n2'),
        node(id: 'n3'),
        node(id: 'n4'),
        node(id: 'n5'),
      ],
      edges: const [
        GraphEdge(
          fromId: 'n0',
          toId: 'n1',
          kind: GraphEdgeKind.containment,
        ),
        GraphEdge(
          fromId: 'n1',
          toId: 'n2',
          kind: GraphEdgeKind.association,
        ),
        GraphEdge(
          fromId: 'n2',
          toId: 'n3',
          kind: GraphEdgeKind.provenance,
        ),
        GraphEdge(
          fromId: 'n3',
          toId: 'n4',
          kind: GraphEdgeKind.evaluation,
        ),
        GraphEdge(
          fromId: 'n4',
          toId: 'n5',
          kind: GraphEdgeKind.checklist,
        ),
      ],
    );

    test('assigns a finite position to every node id', () {
      final layout = computeWorldLayout(world());
      expect(layout.positions.keys.toSet(), {
        'n0',
        'n1',
        'n2',
        'n3',
        'n4',
        'n5',
      });
      for (final p in layout.positions.values) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    test('does NOT pin any node at the origin', () {
      // World layout has no pinned focus; with a seeded PRNG no node coincides
      // with the exact origin.
      final layout = computeWorldLayout(world());
      expect(
        layout.positions.values.any((p) => p == Offset.zero),
        isFalse,
      );
    });

    test('is deterministic for the same seed', () {
      final a = computeWorldLayout(world());
      final b = computeWorldLayout(world());
      for (final id in a.positions.keys) {
        expect(a.positions[id], b.positions[id]);
      }
    });

    test('different seeds give different layouts', () {
      final a = computeWorldLayout(world());
      final b = computeWorldLayout(world(), seed: 99);
      final differs = a.positions.keys.any(
        (id) => a.positions[id] != b.positions[id],
      );
      expect(differs, isTrue);
    });

    test('linked nodes settle near each others ideal spring length', () {
      // After a long relaxation, an edge's endpoints should be roughly within a
      // small multiple of the ideal length for its kind (not flung to the
      // spread extremes). We assert the containment edge n0—n1 is reasonably
      // compact rather than at opposite ends of the world.
      final layout = computeWorldLayout(world());
      final n0 = layout.positions['n0']!;
      final n1 = layout.positions['n1']!;
      // Containment ideal length is 165; allow generous slack for the force
      // balance but ensure they are not pushed apart by the full spread.
      const spread = 150.0 * 6;
      expect(dist(n0, n1), lessThan(spread));
      expect(dist(n0, n1), greaterThan(0));
    });

    test(
      'respects a custom iteration count (fewer iterations still valid)',
      () {
        final layout = computeWorldLayout(world(), iterations: 5);
        expect(layout.positions.length, 6);
        for (final p in layout.positions.values) {
          expect(p.dx.isFinite, isTrue);
          expect(p.dy.isFinite, isTrue);
        }
      },
    );

    test('handles a single-node world without dividing by zero', () {
      final s = scenario(
        nodes: [node(id: 'solo', type: GraphNodeType.task)],
        edges: const [],
      );
      final layout = computeWorldLayout(s);
      final p = layout.positions['solo']!;
      expect(p.dx.isFinite, isTrue);
      expect(p.dy.isFinite, isTrue);
    });

    test(
      'coincident world nodes are separated by the repulsion jitter branch',
      () {
        // A larger node count exercises the O(n^2) repulsion loop. Even if two
        // nodes happened to coincide, the dist < 0.01 jitter branch keeps the
        // layout finite and distinct.
        final s = scenario(
          nodes: List.generate(
            8,
            (i) => node(id: 'w$i'),
          ),
          edges: const [
            GraphEdge(
              fromId: 'w0',
              toId: 'w1',
              kind: GraphEdgeKind.association,
            ),
            GraphEdge(
              fromId: 'w0',
              toId: 'w2',
              kind: GraphEdgeKind.association,
            ),
            GraphEdge(
              fromId: 'w0',
              toId: 'w3',
              kind: GraphEdgeKind.association,
            ),
          ],
        );
        final layout = computeWorldLayout(s);
        final positions = layout.positions.values.toList();
        // No two nodes share an identical position.
        for (var i = 0; i < positions.length; i++) {
          for (var j = i + 1; j < positions.length; j++) {
            expect(
              positions[i],
              isNot(positions[j]),
              reason: 'nodes $i and $j coincide',
            );
          }
        }
      },
    );
  });
}
