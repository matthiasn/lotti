import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_scenarios.dart';

void main() {
  final now = DateTime(2026, 6, 18);

  GraphNode node(
    String id,
    GraphNodeType type, {
    String category = catWork,
    int ageDays = 0,
    String? imagePath,
    List<String> mediaPaths = const [],
    GraphTaskStatus? status,
  }) => GraphNode(
    id: id,
    type: type,
    label: id,
    categoryId: category,
    createdAt: now.subtract(Duration(days: ageDays)),
    imagePath: imagePath,
    mediaPaths: mediaPaths,
    taskStatus: status,
  );

  test('collapses busy direct groups and never exceeds the node budget', () {
    final projection = buildLocalGraphProjection(
      raw: busyTaskScenario(),
      focusId: 'b0',
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
    );

    expect(projection.scenario.nodes.length, lessThanOrEqualTo(24));
    final aggregates = projection.scenario.nodes.where(
      (node) => node.aggregateKind == GraphAggregateKind.relation,
    );
    expect(aggregates, isNotEmpty);
    for (final aggregate in aggregates) {
      expect(aggregate.aggregateCount, aggregate.memberIds.length);
      expect(projection.aggregateMembers[aggregate.id], aggregate.memberIds);
    }
  });

  test('uses one media collection until photos are explicitly expanded', () {
    final focus = node(
      'task',
      GraphNodeType.task,
      mediaPaths: const ['/cover.jpg', '/one.jpg', '/two.jpg'],
    );
    final first = node(
      'one',
      GraphNodeType.imageEntry,
      imagePath: '/one.jpg',
    );
    final second = node(
      'two',
      GraphNodeType.imageEntry,
      imagePath: '/two.jpg',
    );
    final raw = GraphScenario(
      name: 'media',
      seedId: focus.id,
      nodes: [focus, first, second],
      edges: const [
        GraphEdge(
          fromId: 'task',
          toId: 'one',
          kind: GraphEdgeKind.association,
        ),
        GraphEdge(
          fromId: 'task',
          toId: 'two',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );

    final collapsed = buildLocalGraphProjection(
      raw: raw,
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
    );
    final media = collapsed.scenario.nodes.singleWhere(
      (node) => node.aggregateKind == GraphAggregateKind.photos,
    );
    expect(media.aggregateCount, 3);
    expect(media.mediaPaths, ['/cover.jpg', '/one.jpg', '/two.jpg']);
    expect(
      collapsed.scenario.nodes.map((node) => node.id),
      isNot(contains('one')),
    );

    final expanded = buildLocalGraphProjection(
      raw: raw,
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
      expandedAggregateIds: {media.id},
    );
    expect(
      expanded.scenario.nodes.map((node) => node.id),
      containsAll(['one', 'two']),
    );
    expect(
      expanded.scenario.nodes.where(
        (node) => node.aggregateKind == GraphAggregateKind.photos,
      ),
      isEmpty,
    );
  });

  test('creates a media collection from focus-owned media only', () {
    final focus = node(
      'task',
      GraphNodeType.task,
      mediaPaths: const ['/cover.jpg'],
    );
    final projection = buildLocalGraphProjection(
      raw: GraphScenario(
        name: 'cover only',
        seedId: focus.id,
        nodes: [focus],
        edges: const [],
        now: now,
      ),
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
    );

    final media = projection.scenario.nodes.singleWhere(
      (node) => node.type == GraphNodeType.mediaCollection,
    );
    expect(media.createdAt, focus.createdAt);
    expect(media.aggregateCount, 1);
    expect(media.memberIds, isEmpty);
    expect(media.mediaPaths, ['/cover.jpg']);
    expect(projection.aggregateMembers[media.id], isEmpty);
    expect(projection.scenario.edges, hasLength(1));
    final mediaEdge = projection.scenario.edges.single;
    expect(mediaEdge.fromId, focus.id);
    expect(mediaEdge.toId, media.id);
    expect(mediaEdge.kind, GraphEdgeKind.association);
  });

  test('orders defensive synthetic node types after ordinary entries', () {
    final focus = node('focus', GraphNodeType.task);
    final note = node('note', GraphNodeType.textEntry);
    final media = node('media', GraphNodeType.mediaCollection);
    final aggregate = node('aggregate', GraphNodeType.aggregate);
    final projection = buildLocalGraphProjection(
      raw: GraphScenario(
        name: 'synthetic ordering',
        seedId: focus.id,
        nodes: [focus, aggregate, media, note],
        edges: const [
          GraphEdge(
            fromId: 'focus',
            toId: 'aggregate',
            kind: GraphEdgeKind.association,
          ),
          GraphEdge(
            fromId: 'focus',
            toId: 'media',
            kind: GraphEdgeKind.association,
          ),
          GraphEdge(
            fromId: 'focus',
            toId: 'note',
            kind: GraphEdgeKind.association,
          ),
        ],
        now: now,
      ),
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
    );

    expect(
      projection.scenario.nodes.map((node) => node.id),
      ['focus', 'note', 'media', 'aggregate'],
    );
  });

  test('applies relation, category, status, recency and hop filters', () {
    final focus = node('focus', GraphNodeType.task);
    final blocked = node(
      'blocked',
      GraphNodeType.task,
      status: GraphTaskStatus.blocked,
    );
    final oldDone = node(
      'old',
      GraphNodeType.task,
      category: catWriting,
      status: GraphTaskStatus.done,
      ageDays: 90,
    );
    final secondHop = node('second', GraphNodeType.textEntry);
    final raw = GraphScenario(
      name: 'filters',
      seedId: focus.id,
      nodes: [focus, blocked, oldDone, secondHop],
      edges: const [
        GraphEdge(
          fromId: 'blocked',
          toId: 'focus',
          kind: GraphEdgeKind.blocks,
        ),
        GraphEdge(
          fromId: 'focus',
          toId: 'old',
          kind: GraphEdgeKind.association,
        ),
        GraphEdge(
          fromId: 'blocked',
          toId: 'second',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );

    final projection = buildLocalGraphProjection(
      raw: raw,
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
      filters: const GraphProjectionFilters(
        edgeKinds: {GraphEdgeKind.blocks},
        nodeTypes: {GraphNodeType.task},
        categoryIds: {catWork},
        taskStatuses: {GraphTaskStatus.blocked},
        maxAgeDays: 30,
        maxHops: 1,
      ),
    );

    expect(
      projection.scenario.nodes.map((node) => node.id),
      ['focus', 'blocked'],
    );
    expect(projection.scenario.edges.single.kind, GraphEdgeKind.blocks);
  });

  test('does not retain excluded parallel edges between visible nodes', () {
    final focus = node('focus', GraphNodeType.task);
    final blocked = node('blocked', GraphNodeType.task);
    final raw = GraphScenario(
      name: 'parallel relations',
      seedId: focus.id,
      nodes: [focus, blocked],
      edges: const [
        GraphEdge(
          fromId: 'blocked',
          toId: 'focus',
          kind: GraphEdgeKind.blocks,
        ),
        GraphEdge(
          fromId: 'blocked',
          toId: 'focus',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );

    final projection = buildLocalGraphProjection(
      raw: raw,
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
      filters: const GraphProjectionFilters(
        edgeKinds: {GraphEdgeKind.blocks},
      ),
    );

    expect(projection.scenario.nodes.map((node) => node.id), [
      'focus',
      'blocked',
    ]);
    expect(projection.scenario.edges, hasLength(1));
    expect(projection.scenario.edges.single.kind, GraphEdgeKind.blocks);
  });
}
