import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
    String? coverImagePath,
    List<String> mediaPaths = const [],
    GraphTaskStatus? status,
  }) => GraphNode(
    id: id,
    type: type,
    label: id,
    categoryId: category,
    createdAt: now.subtract(Duration(days: ageDays)),
    imagePath: imagePath,
    coverImagePath: coverImagePath,
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
      coverImagePath: '/cover.jpg',
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
    expect(media.aggregateCount, 2);
    expect(media.mediaPaths, ['/one.jpg', '/two.jpg']);
    expect(media.mediaPaths.length, media.aggregateCount);
    expect(
      collapsed.scenario.nodes.map((node) => node.id),
      isNot(contains('one')),
    );
    expect(
      collapsed.scenario.nodes.map((node) => node.id),
      isNot(contains('two')),
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

  test('keeps cover-only media on the focus instead of an empty aggregate', () {
    final focus = node(
      'task',
      GraphNodeType.task,
      coverImagePath: '/cover.jpg',
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

    expect(
      projection.scenario.nodes.where(
        (node) => node.type == GraphNodeType.mediaCollection,
      ),
      isEmpty,
    );
    expect(projection.scenario.nodes, [focus]);
    expect(projection.aggregateMembers, isEmpty);
    expect(projection.scenario.edges, isEmpty);
  });

  test('keeps an image node with no decodable path visible', () {
    final focus = node('task', GraphNodeType.task);
    final image = node('image', GraphNodeType.imageEntry);
    final projection = buildLocalGraphProjection(
      raw: GraphScenario(
        name: 'missing image file',
        seedId: focus.id,
        nodes: [focus, image],
        edges: const [
          GraphEdge(
            fromId: 'task',
            toId: 'image',
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

    expect(projection.scenario.nodes.map((node) => node.id), ['task', 'image']);
    expect(
      projection.scenario.nodes.where(
        (node) => node.type == GraphNodeType.mediaCollection,
      ),
      isEmpty,
    );
  });

  test('does not reintroduce task media excluded by active filters', () {
    final focus = node(
      'task',
      GraphNodeType.task,
      coverImagePath: '/cover.jpg',
      mediaPaths: const ['/cover.jpg', '/photo.jpg'],
    );
    final image = node(
      'image',
      GraphNodeType.imageEntry,
      imagePath: '/photo.jpg',
    );
    final raw = GraphScenario(
      name: 'filtered media',
      seedId: focus.id,
      nodes: [focus, image],
      edges: const [
        GraphEdge(
          fromId: 'task',
          toId: 'image',
          kind: GraphEdgeKind.association,
        ),
      ],
      now: now,
    );

    for (final filters in [
      const GraphProjectionFilters(edgeKinds: {GraphEdgeKind.blocks}),
      const GraphProjectionFilters(nodeTypes: {GraphNodeType.task}),
    ]) {
      final projection = buildLocalGraphProjection(
        raw: raw,
        focusId: focus.id,
        maxNodes: 24,
        clusterPreviewLimit: 5,
        clusterCollapseThreshold: 8,
        filters: filters,
      );

      expect(
        projection.scenario.nodes.where(
          (node) => node.type == GraphNodeType.mediaCollection,
        ),
        isEmpty,
      );
      expect(projection.scenario.nodes, [focus]);
    }
  });

  test('media collection contains only filtered direct image paths', () {
    final focus = node(
      'task',
      GraphNodeType.task,
      coverImagePath: '/cover.jpg',
      mediaPaths: const ['/cover.jpg', '/recent.jpg', '/old.jpg'],
    );
    final recent = node(
      'recent',
      GraphNodeType.imageEntry,
      imagePath: '/recent.jpg',
    );
    final old = node(
      'old',
      GraphNodeType.imageEntry,
      category: catWriting,
      ageDays: 90,
      imagePath: '/old.jpg',
    );
    final projection = buildLocalGraphProjection(
      raw: GraphScenario(
        name: 'filtered media paths',
        seedId: focus.id,
        nodes: [focus, recent, old],
        edges: const [
          GraphEdge(
            fromId: 'task',
            toId: 'recent',
            kind: GraphEdgeKind.association,
          ),
          GraphEdge(
            fromId: 'task',
            toId: 'old',
            kind: GraphEdgeKind.association,
          ),
        ],
        now: now,
      ),
      focusId: focus.id,
      maxNodes: 24,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
      filters: const GraphProjectionFilters(
        categoryIds: {catWork},
        maxAgeDays: 30,
      ),
    );

    final media = projection.scenario.nodes.singleWhere(
      (node) => node.type == GraphNodeType.mediaCollection,
    );
    expect(media.memberIds, ['recent']);
    // The preview shows exactly what the collection collapses. The focus's own
    // cover art is not one of its members, and counting it in would have made
    // the mosaic show more tiles than the "Photo · N" label promises.
    expect(media.mediaPaths, ['/recent.jpg']);
    expect(media.aggregateCount, 1);
    expect(
      media.mediaPaths.length,
      media.aggregateCount,
      reason: 'preview tiles and the displayed count come from one collection',
    );
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

  group('multi-edge neighbours', () {
    GraphProjection project(
      List<GraphNode> nodes,
      List<GraphEdge> edges, {
      int maxNodes = 24,
      GraphProjectionFilters filters = const GraphProjectionFilters(),
      Set<String> expandedAggregateIds = const {},
    }) => buildLocalGraphProjection(
      raw: GraphScenario(
        name: 'multi-edge',
        seedId: 'focus',
        nodes: nodes,
        edges: edges,
        now: now,
      ),
      focusId: 'focus',
      maxNodes: maxNodes,
      clusterPreviewLimit: 5,
      clusterCollapseThreshold: 8,
      filters: filters,
      expandedAggregateIds: expandedAggregateIds,
    );

    List<GraphEdge> reciprocal(String id, GraphEdgeKind kind) => [
      GraphEdge(fromId: 'focus', toId: id, kind: kind),
      GraphEdge(fromId: id, toId: 'focus', kind: kind),
    ];

    List<String> nodeIds(GraphProjection projection) =>
        projection.scenario.nodes.map((node) => node.id).toList();

    test('two typed relationships to one neighbour show it once and keep '
        'both edges', () {
      final projection = project(
        [node('focus', GraphNodeType.task), node('n', GraphNodeType.task)],
        const [
          GraphEdge(fromId: 'n', toId: 'focus', kind: GraphEdgeKind.blocks),
          GraphEdge(fromId: 'focus', toId: 'n', kind: GraphEdgeKind.followsUp),
        ],
      );

      expect(nodeIds(projection), ['focus', 'n']);
      expect(
        projection.scenario.edges.map((edge) => edge.kind),
        unorderedEquals([GraphEdgeKind.blocks, GraphEdgeKind.followsUp]),
      );
    });

    test('a crowded budget shows two of six doubly linked neighbours and '
        'collapses exactly the other four', () {
      final notes = [
        for (var i = 0; i < 6; i++)
          node('n$i', GraphNodeType.textEntry, ageDays: i),
      ];
      final projection = project(
        [node('focus', GraphNodeType.task), ...notes],
        [
          for (final note in notes)
            ...reciprocal(note.id, GraphEdgeKind.association),
        ],
        maxNodes: 4,
      );

      final aggregateId = graphAggregateId(
        focusId: 'focus',
        kind: GraphAggregateKind.relation,
        edgeKind: GraphEdgeKind.association,
        nodeType: GraphNodeType.textEntry,
      );
      expect(nodeIds(projection), ['focus', 'n0', 'n1', aggregateId]);
      expect(projection.aggregateMembers[aggregateId], [
        'n2',
        'n3',
        'n4',
        'n5',
      ]);
      expect(projection.scenario.nodes.last.aggregateCount, 4);
      expect(projection.visibleRawIds, {'focus', 'n0', 'n1'});
    });

    test('a neighbour in two relation groups belongs only to its highest '
        'priority one, whatever the edge order', () {
      final nodes = [
        node('focus', GraphNodeType.task),
        node('t', GraphNodeType.task),
        for (var i = 0; i < 9; i++) node('a$i', GraphNodeType.task, ageDays: i),
      ];
      final edges = [
        const GraphEdge(fromId: 't', toId: 'focus', kind: GraphEdgeKind.blocks),
        ...reciprocal('t', GraphEdgeKind.association),
        for (var i = 0; i < 9; i++)
          ...reciprocal('a$i', GraphEdgeKind.association),
      ];
      final aggregateId = graphAggregateId(
        focusId: 'focus',
        kind: GraphAggregateKind.relation,
        edgeKind: GraphEdgeKind.association,
        nodeType: GraphNodeType.task,
      );

      for (final order in [edges, edges.reversed.toList()]) {
        final projection = project(nodes, order);
        expect(nodeIds(projection), [
          'focus',
          't',
          'a0',
          'a1',
          'a2',
          'a3',
          'a4',
          aggregateId,
        ]);
        expect(projection.aggregateMembers[aggregateId], [
          'a5',
          'a6',
          'a7',
          'a8',
        ]);
        expect(projection.scenario.nodes.last.aggregateCount, 4);
      }
    });

    test('filtering out the stronger relationship still shows the neighbour '
        'through the remaining one', () {
      final projection = project(
        [node('focus', GraphNodeType.task), node('n', GraphNodeType.task)],
        const [
          GraphEdge(fromId: 'n', toId: 'focus', kind: GraphEdgeKind.blocks),
          GraphEdge(
            fromId: 'focus',
            toId: 'n',
            kind: GraphEdgeKind.association,
          ),
        ],
        filters: const GraphProjectionFilters(
          edgeKinds: {GraphEdgeKind.association},
        ),
      );

      expect(nodeIds(projection), ['focus', 'n']);
      expect(
        projection.scenario.edges.single.kind,
        GraphEdgeKind.association,
      );
    });

    test('a doubly linked photo is one collection member, and one node once '
        'the collection is expanded', () {
      final nodes = [
        node('focus', GraphNodeType.task),
        node('p', GraphNodeType.imageEntry, imagePath: '/p.jpg'),
        node('q', GraphNodeType.imageEntry, imagePath: '/q.jpg', ageDays: 1),
      ];
      final edges = [
        ...reciprocal('p', GraphEdgeKind.association),
        const GraphEdge(fromId: 'p', toId: 'focus', kind: GraphEdgeKind.fixes),
        ...reciprocal('q', GraphEdgeKind.association),
      ];
      final mediaId = graphAggregateId(
        focusId: 'focus',
        kind: GraphAggregateKind.photos,
      );

      final collapsed = project(nodes, edges);
      expect(collapsed.aggregateMembers[mediaId], ['p', 'q']);
      final collection = collapsed.scenario.nodes.singleWhere(
        (node) => node.id == mediaId,
      );
      expect(collection.aggregateCount, 2);
      expect(collection.mediaPaths, ['/p.jpg', '/q.jpg']);

      final expanded = project(nodes, edges, expandedAggregateIds: {mediaId});
      expect(nodeIds(expanded), ['focus', 'p', 'q']);
    });

    test('a collapsed neighbour does not resurface as second-hop context', () {
      final nodes = [
        node('focus', GraphNodeType.task),
        for (var i = 0; i < 10; i++)
          node('n$i', GraphNodeType.textEntry, ageDays: i),
      ];
      final projection = project(
        nodes,
        [
          for (var i = 0; i < 10; i++)
            GraphEdge(
              fromId: 'focus',
              toId: 'n$i',
              kind: GraphEdgeKind.association,
            ),
          // n9 is collapsed below, but a visible sibling links to it and the
          // budget still has room for second-hop context.
          const GraphEdge(
            fromId: 'n0',
            toId: 'n9',
            kind: GraphEdgeKind.association,
          ),
        ],
      );

      final hidden = projection.aggregateMembers.values.single;
      expect(hidden, ['n5', 'n6', 'n7', 'n8', 'n9']);
      expect(projection.visibleRawIds, {'focus', 'n0', 'n1', 'n2', 'n3', 'n4'});
    });
  });

  group('multi-edge neighbours — properties', () {
    const neighbourCount = 12;
    const kinds = [
      GraphEdgeKind.blocks,
      GraphEdgeKind.followsUp,
      GraphEdgeKind.association,
      GraphEdgeKind.provenance,
    ];
    const types = [
      GraphNodeType.task,
      GraphNodeType.textEntry,
      GraphNodeType.imageEntry,
    ];

    final nodes = [
      node('focus', GraphNodeType.task),
      for (var i = 0; i < neighbourCount; i++)
        node(
          'n$i',
          types[i % types.length],
          ageDays: i ~/ 2,
          imagePath: types[i % types.length] == GraphNodeType.imageEntry
              ? '/n$i.jpg'
              : null,
        ),
    ];

    /// Decodes one generated int into an edge: which neighbour, which kind,
    /// which direction, and whether its other end is the focus or a sibling.
    GraphEdge edgeFor(int code) {
      final neighbour = 'n${code % neighbourCount}';
      final kind = kinds[(code ~/ neighbourCount) % kinds.length];
      final other = (code ~/ 96).isEven
          ? 'focus'
          : 'n${(code + 5) % neighbourCount}';
      return (code ~/ 48).isEven
          ? GraphEdge(fromId: other, toId: neighbour, kind: kind)
          : GraphEdge(fromId: neighbour, toId: other, kind: kind);
    }

    GraphProjection project(List<GraphEdge> edges, int maxNodes) =>
        buildLocalGraphProjection(
          raw: GraphScenario(
            name: 'generated',
            seedId: 'focus',
            nodes: nodes,
            edges: edges,
            now: now,
          ),
          focusId: 'focus',
          maxNodes: maxNodes,
          clusterPreviewLimit: 3,
          clusterCollapseThreshold: 4,
        );

    Map<String, Set<String>> membership(GraphProjection projection) => {
      for (final entry in projection.aggregateMembers.entries)
        entry.key: entry.value.toSet(),
    };

    glados.Glados2(
      glados.any.listWithLengthInRange(1, 48, glados.any.intInRange(0, 192)),
      glados.any.intInRange(2, 16),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'every neighbour is shown or counted once, within budget, whatever '
      'the edge order',
      (codes, maxNodes) {
        final edges = codes.map(edgeFor).toList();
        final projection = project(edges, maxNodes);
        final shown = projection.scenario.nodes.map((node) => node.id).toList();
        final shownIds = shown.toSet();
        final hidden = [
          for (final ids in projection.aggregateMembers.values) ...ids,
        ];

        expect(shown.length, lessThanOrEqualTo(maxNodes));
        expect(shownIds, hasLength(shown.length));
        expect(hidden.toSet(), hasLength(hidden.length));
        expect(shownIds.intersection(hidden.toSet()), isEmpty);
        for (final aggregate in projection.scenario.nodes.where(
          (node) => node.isAggregate,
        )) {
          expect(aggregate.aggregateCount, aggregate.memberIds.length);
          expect(
            projection.aggregateMembers[aggregate.id],
            aggregate.memberIds,
          );
        }
        for (final edge in edges) {
          if (shownIds.contains(edge.fromId) && shownIds.contains(edge.toId)) {
            expect(projection.scenario.edges, contains(same(edge)));
          }
        }

        final reordered = project(edges.reversed.toList(), maxNodes);
        expect(
          reordered.scenario.nodes.map((node) => node.id).toSet(),
          shownIds,
        );
        expect(membership(reordered), membership(projection));
      },
      tags: 'glados',
    );
  });
}
