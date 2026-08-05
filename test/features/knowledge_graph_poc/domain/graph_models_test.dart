import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';

void main() {
  final now = DateTime(2026, 6, 15, 12);

  GraphNode node({
    String id = 'n',
    GraphNodeType type = GraphNodeType.task,
    String label = 'Label',
    String categoryId = 'cat',
    DateTime? createdAt,
    String? imagePath,
    String? coverImagePath,
    String? oneLiner,
    String? tldr,
  }) => GraphNode(
    id: id,
    type: type,
    label: label,
    categoryId: categoryId,
    createdAt: createdAt ?? now,
    imagePath: imagePath,
    coverImagePath: coverImagePath,
    oneLiner: oneLiner,
    tldr: tldr,
  );

  group('GraphNode', () {
    test('stores all constructor fields verbatim', () {
      final created = DateTime(2026, 6, 1, 8, 30);
      final n = GraphNode(
        id: 'task-1',
        type: GraphNodeType.imageEntry,
        label: 'Sunset',
        categoryId: 'photos',
        createdAt: created,
        imagePath: '/abs/sunset.jpg',
        coverImagePath: '/abs/cover.jpg',
        coverImageCropX: 0.72,
        oneLiner: 'Golden hour over the bay',
        tldr: 'A nice sunset',
        taskStatus: GraphTaskStatus.inProgress,
        aggregateKind: GraphAggregateKind.photos,
        aggregateEdgeKind: GraphEdgeKind.association,
        aggregateCount: 3,
        memberIds: const ['photo-1', 'photo-2', 'photo-3'],
        mediaPaths: const ['/abs/one.jpg', '/abs/two.jpg'],
      );

      expect(n.id, 'task-1');
      expect(n.type, GraphNodeType.imageEntry);
      expect(n.label, 'Sunset');
      expect(n.categoryId, 'photos');
      expect(n.createdAt, created);
      expect(n.imagePath, '/abs/sunset.jpg');
      expect(n.coverImagePath, '/abs/cover.jpg');
      expect(n.coverImageCropX, 0.72);
      expect(n.oneLiner, 'Golden hour over the bay');
      expect(n.tldr, 'A nice sunset');
      expect(n.taskStatus, GraphTaskStatus.inProgress);
      expect(n.aggregateKind, GraphAggregateKind.photos);
      expect(n.aggregateEdgeKind, GraphEdgeKind.association);
      expect(n.aggregateCount, 3);
      expect(n.memberIds, ['photo-1', 'photo-2', 'photo-3']);
      expect(n.mediaPaths, ['/abs/one.jpg', '/abs/two.jpg']);
      expect(n.isAggregate, isTrue);
    });

    test('optional fields default to null', () {
      final n = node();
      expect(n.imagePath, isNull);
      expect(n.coverImagePath, isNull);
      expect(n.oneLiner, isNull);
      expect(n.tldr, isNull);
      expect(n.coverImageCropX, 0.5);
      expect(n.taskStatus, isNull);
      expect(n.aggregateKind, isNull);
      expect(n.aggregateEdgeKind, isNull);
      expect(n.aggregateCount, 0);
      expect(n.memberIds, isEmpty);
      expect(n.mediaPaths, isEmpty);
      expect(n.isAggregate, isFalse);
    });
  });

  group('GraphNodeType', () {
    test('enumerates journal-entry and display-only variants', () {
      expect(GraphNodeType.values, [
        GraphNodeType.task,
        GraphNodeType.project,
        GraphNodeType.textEntry,
        GraphNodeType.audioEntry,
        GraphNodeType.imageEntry,
        GraphNodeType.aiResponse,
        GraphNodeType.checklist,
        GraphNodeType.checklistItem,
        GraphNodeType.rating,
        GraphNodeType.mediaCollection,
        GraphNodeType.aggregate,
      ]);
    });
  });

  group('GraphEdgeKind', () {
    test('includes structural and typed task relationship classes', () {
      expect(GraphEdgeKind.values, [
        GraphEdgeKind.containment,
        GraphEdgeKind.association,
        GraphEdgeKind.provenance,
        GraphEdgeKind.evaluation,
        GraphEdgeKind.checklist,
        GraphEdgeKind.blocks,
        GraphEdgeKind.followsUp,
        GraphEdgeKind.duplicates,
        GraphEdgeKind.fixes,
        GraphEdgeKind.supersedes,
      ]);
    });
  });

  group('GraphEdge', () {
    test('stores endpoints and kind verbatim', () {
      const e = GraphEdge(
        fromId: 'a',
        toId: 'b',
        kind: GraphEdgeKind.containment,
      );
      expect(e.fromId, 'a');
      expect(e.toId, 'b');
      expect(e.kind, GraphEdgeKind.containment);
    });
  });

  group('GraphScenario', () {
    final focus = node(id: 'focus', createdAt: DateTime(2026, 6, 14, 12));
    final child = node(id: 'child', createdAt: DateTime(2026, 6, 10, 12));
    const edge = GraphEdge(
      fromId: 'focus',
      toId: 'child',
      kind: GraphEdgeKind.association,
    );
    final scenario = GraphScenario(
      name: 'demo',
      seedId: 'focus',
      nodes: [focus, child],
      edges: const [edge],
      now: now,
    );

    test('stores all constructor fields verbatim', () {
      expect(scenario.name, 'demo');
      expect(scenario.seedId, 'focus');
      expect(scenario.nodes, [focus, child]);
      expect(scenario.edges, [edge]);
      expect(scenario.now, now);
    });

    group('nodeById', () {
      test('returns the node with the matching id', () {
        expect(scenario.nodeById('focus'), same(focus));
        expect(scenario.nodeById('child'), same(child));
      });

      test('throws StateError when no node matches', () {
        expect(() => scenario.nodeById('missing'), throwsStateError);
      });
    });

    group('ageDays', () {
      test('computes fractional age in days relative to now', () {
        // focus.createdAt is exactly 24h before now → 1.0 day.
        expect(scenario.ageDays(focus), closeTo(1, 1e-9));
        // child.createdAt is 5 days (120h) before now → 5.0 days.
        expect(scenario.ageDays(child), closeTo(5, 1e-9));
      });

      test('honors sub-day resolution from inHours', () {
        // 36h before now → 36/24 = 1.5 days.
        final n = node(createdAt: now.subtract(const Duration(hours: 36)));
        expect(scenario.ageDays(n), closeTo(1.5, 1e-9));
      });

      test('clamps a future-dated node to zero', () {
        final future = node(
          id: 'future',
          createdAt: now.add(const Duration(days: 3)),
        );
        expect(scenario.ageDays(future), 0);
      });

      test('returns zero for a node created exactly at now', () {
        final present = node(id: 'present', createdAt: now);
        expect(scenario.ageDays(present), 0);
      });

      test('clamps to zero for a small future offset', () {
        // Less than a full day in the future still floors via inHours but the
        // d < 0 branch must catch it.
        final slightlyFuture = node(
          id: 'slightly',
          createdAt: now.add(const Duration(hours: 5)),
        );
        expect(scenario.ageDays(slightlyFuture), 0);
      });
    });
  });

  group('degreeMap', () {
    test('returns an empty map for no edges', () {
      expect(degreeMap(const []), isEmpty);
    });

    test('counts each endpoint once per incident edge (undirected)', () {
      const edges = [
        GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        GraphEdge(fromId: 'a', toId: 'c', kind: GraphEdgeKind.containment),
        GraphEdge(fromId: 'b', toId: 'c', kind: GraphEdgeKind.checklist),
      ];

      expect(degreeMap(edges), {'a': 2, 'b': 2, 'c': 2});
    });

    test('a hub node accumulates degree from every incident edge', () {
      const edges = [
        GraphEdge(fromId: 'hub', toId: 'a', kind: GraphEdgeKind.association),
        GraphEdge(fromId: 'hub', toId: 'b', kind: GraphEdgeKind.association),
        GraphEdge(fromId: 'c', toId: 'hub', kind: GraphEdgeKind.association),
      ];

      final degrees = degreeMap(edges);
      expect(degrees['hub'], 3);
      expect(degrees['a'], 1);
      expect(degrees['b'], 1);
      expect(degrees['c'], 1);
    });

    test('counts a self-loop as degree two for the same node', () {
      const edges = [
        GraphEdge(fromId: 'x', toId: 'x', kind: GraphEdgeKind.association),
      ];
      expect(degreeMap(edges), {'x': 2});
    });

    test('accumulates parallel edges between the same pair', () {
      const edges = [
        GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.association),
        GraphEdge(fromId: 'a', toId: 'b', kind: GraphEdgeKind.provenance),
      ];
      expect(degreeMap(edges), {'a': 2, 'b': 2});
    });
  });
}
