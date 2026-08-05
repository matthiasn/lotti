import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';

/// Filters applied before a raw graph is projected into the bounded local view.
class GraphProjectionFilters {
  const GraphProjectionFilters({
    this.edgeKinds = const {},
    this.nodeTypes = const {},
    this.categoryIds = const {},
    this.taskStatuses = const {},
    this.maxAgeDays,
    this.maxHops = 2,
  });

  final Set<GraphEdgeKind> edgeKinds;
  final Set<GraphNodeType> nodeTypes;
  final Set<String> categoryIds;
  final Set<GraphTaskStatus> taskStatuses;
  final int? maxAgeDays;
  final int maxHops;

  bool get isEmpty =>
      edgeKinds.isEmpty &&
      nodeTypes.isEmpty &&
      categoryIds.isEmpty &&
      taskStatuses.isEmpty &&
      maxAgeDays == null &&
      maxHops == 2;

  GraphProjectionFilters copyWith({
    Set<GraphEdgeKind>? edgeKinds,
    Set<GraphNodeType>? nodeTypes,
    Set<String>? categoryIds,
    Set<GraphTaskStatus>? taskStatuses,
    int? maxAgeDays,
    bool clearMaxAgeDays = false,
    int? maxHops,
  }) => GraphProjectionFilters(
    edgeKinds: edgeKinds ?? this.edgeKinds,
    nodeTypes: nodeTypes ?? this.nodeTypes,
    categoryIds: categoryIds ?? this.categoryIds,
    taskStatuses: taskStatuses ?? this.taskStatuses,
    maxAgeDays: clearMaxAgeDays ? null : maxAgeDays ?? this.maxAgeDays,
    maxHops: maxHops ?? this.maxHops,
  );
}

/// A bounded graph for the main canvas plus the raw membership of collapsed
/// display nodes.
class GraphProjection {
  const GraphProjection({
    required this.scenario,
    required this.aggregateMembers,
    required this.visibleRawIds,
  });

  final GraphScenario scenario;
  final Map<String, List<String>> aggregateMembers;
  final Set<String> visibleRawIds;
}

/// Stable id used by controls and expansion state for a collapsed group.
String graphAggregateId({
  required String focusId,
  required GraphAggregateKind kind,
  GraphEdgeKind? edgeKind,
  GraphNodeType? nodeType,
}) => [
  '_kg',
  focusId,
  kind.name,
  edgeKind?.name ?? 'none',
  nodeType?.name ?? 'none',
].join(':');

class _Neighbor {
  const _Neighbor(this.node, this.edge);

  final GraphNode node;
  final GraphEdge edge;
}

/// Projects [raw] into a readable ego graph around [focusId].
///
/// Direct photo nodes are represented by one media collection. Large direct
/// relation/type groups keep a recent preview and collapse the exact remainder.
/// Remaining capacity is filled with second-hop context, never exceeding
/// [maxNodes]. The function is pure and deterministic.
GraphProjection buildLocalGraphProjection({
  required GraphScenario raw,
  required String focusId,
  required int maxNodes,
  required int clusterPreviewLimit,
  required int clusterCollapseThreshold,
  GraphProjectionFilters filters = const GraphProjectionFilters(),
  Set<String> expandedAggregateIds = const {},
}) {
  final byId = {for (final node in raw.nodes) node.id: node};
  final focus = byId[focusId] ?? raw.nodeById(raw.seedId);
  final actualFocusId = focus.id;
  final incident = <String, List<GraphEdge>>{
    for (final node in raw.nodes) node.id: <GraphEdge>[],
  };
  for (final edge in raw.edges) {
    incident[edge.fromId]?.add(edge);
    incident[edge.toId]?.add(edge);
  }

  bool edgeMatches(GraphEdge edge) =>
      filters.edgeKinds.isEmpty || filters.edgeKinds.contains(edge.kind);

  bool nodeMatches(GraphNode node) {
    if (filters.nodeTypes.isNotEmpty &&
        !filters.nodeTypes.contains(node.type)) {
      return false;
    }
    if (filters.categoryIds.isNotEmpty &&
        !filters.categoryIds.contains(node.categoryId)) {
      return false;
    }
    if (filters.taskStatuses.isNotEmpty &&
        (node.taskStatus == null ||
            !filters.taskStatuses.contains(node.taskStatus))) {
      return false;
    }
    final maxAgeDays = filters.maxAgeDays;
    if (maxAgeDays != null && raw.ageDays(node) > maxAgeDays) return false;
    return true;
  }

  GraphNode? otherEndpoint(GraphEdge edge, String id) {
    final otherId = edge.fromId == id ? edge.toId : edge.fromId;
    return byId[otherId];
  }

  final direct = <_Neighbor>[];
  for (final edge in incident[actualFocusId] ?? const <GraphEdge>[]) {
    if (!edgeMatches(edge)) continue;
    final node = otherEndpoint(edge, actualFocusId);
    if (node != null && nodeMatches(node)) direct.add(_Neighbor(node, edge));
  }
  direct.sort(_compareNeighbors);

  final visibleNodes = <GraphNode>[focus];
  final visibleRawIds = <String>{actualFocusId};
  final aggregateMembers = <String, List<String>>{};
  final aggregateEdges = <GraphEdge>[];
  var remaining = (maxNodes - 1).clamp(0, maxNodes);

  final directImages = direct
      .where((neighbor) => neighbor.node.type == GraphNodeType.imageEntry)
      .toList();
  final mediaPaths = <String>{
    ...focus.mediaPaths.where((path) => path.isNotEmpty),
    ...directImages.map((item) => item.node.imagePath).nonNulls,
  }.toList(growable: false);
  final mediaId = graphAggregateId(
    focusId: actualFocusId,
    kind: GraphAggregateKind.photos,
  );
  final mediaExpanded = expandedAggregateIds.contains(mediaId);
  if (mediaPaths.isNotEmpty && !mediaExpanded && remaining > 0) {
    final memberIds = directImages.map((item) => item.node.id).toList();
    visibleNodes.add(
      GraphNode(
        id: mediaId,
        type: GraphNodeType.mediaCollection,
        label: '',
        categoryId: focus.categoryId,
        createdAt: directImages.isEmpty
            ? focus.createdAt
            : directImages
                  .map((item) => item.node.createdAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b),
        aggregateKind: GraphAggregateKind.photos,
        aggregateCount: mediaPaths.length,
        memberIds: memberIds,
        mediaPaths: mediaPaths.take(4).toList(growable: false),
      ),
    );
    aggregateMembers[mediaId] = memberIds;
    aggregateEdges.add(
      GraphEdge(
        fromId: actualFocusId,
        toId: mediaId,
        kind: GraphEdgeKind.association,
      ),
    );
    remaining--;
  }

  final grouped = <(GraphEdgeKind, GraphNodeType), List<_Neighbor>>{};
  for (final neighbor in direct) {
    if (neighbor.node.type == GraphNodeType.imageEntry && !mediaExpanded) {
      continue;
    }
    grouped
        .putIfAbsent((neighbor.edge.kind, neighbor.node.type), () => [])
        .add(neighbor);
  }

  final groupKeys = grouped.keys.toList()
    ..sort((a, b) {
      final edge = _edgePriority(a.$1).compareTo(_edgePriority(b.$1));
      if (edge != 0) return edge;
      return _typePriority(a.$2).compareTo(_typePriority(b.$2));
    });

  for (final key in groupKeys) {
    if (remaining <= 0) break;
    final members = grouped[key]!..sort(_compareNeighbors);
    final aggregateId = graphAggregateId(
      focusId: actualFocusId,
      kind: GraphAggregateKind.relation,
      edgeKind: key.$1,
      nodeType: key.$2,
    );
    final expanded = expandedAggregateIds.contains(aggregateId);
    final shouldCollapse =
        !expanded && members.length > clusterCollapseThreshold;
    final requestedIndividuals = shouldCollapse
        ? clusterPreviewLimit
        : members.length;
    final needsAggregate = shouldCollapse || requestedIndividuals > remaining;
    final individualCapacity = needsAggregate
        ? (remaining - 1).clamp(0, requestedIndividuals)
        : remaining.clamp(0, requestedIndividuals);

    for (final member in members.take(individualCapacity)) {
      visibleNodes.add(member.node);
      visibleRawIds.add(member.node.id);
      remaining--;
    }

    final hidden = members.skip(individualCapacity).toList();
    if (hidden.isNotEmpty && remaining > 0) {
      final hiddenIds = hidden.map((item) => item.node.id).toList();
      final newest = hidden
          .map((item) => item.node.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      visibleNodes.add(
        GraphNode(
          id: aggregateId,
          type: GraphNodeType.aggregate,
          label: '',
          categoryId: hidden.first.node.categoryId,
          createdAt: newest,
          aggregateKind: GraphAggregateKind.relation,
          aggregateEdgeKind: key.$1,
          aggregateCount: hidden.length,
          memberIds: hiddenIds,
        ),
      );
      aggregateMembers[aggregateId] = hiddenIds;
      aggregateEdges.add(
        GraphEdge(
          fromId: actualFocusId,
          toId: aggregateId,
          kind: key.$1,
        ),
      );
      remaining--;
    }
  }

  if (filters.maxHops >= 2 && remaining > 0) {
    final secondHop = <_Neighbor>[];
    for (final parentId in visibleRawIds.where((id) => id != actualFocusId)) {
      for (final edge in incident[parentId] ?? const <GraphEdge>[]) {
        if (!edgeMatches(edge)) continue;
        final node = otherEndpoint(edge, parentId);
        if (node == null ||
            visibleRawIds.contains(node.id) ||
            node.id == actualFocusId ||
            node.type == GraphNodeType.imageEntry ||
            !nodeMatches(node)) {
          continue;
        }
        secondHop.add(_Neighbor(node, edge));
      }
    }
    secondHop.sort(_compareNeighbors);
    for (final neighbor in secondHop) {
      if (remaining <= 0) break;
      if (!visibleRawIds.add(neighbor.node.id)) continue;
      visibleNodes.add(neighbor.node);
      remaining--;
    }
  }

  final visibleIds = visibleNodes.map((node) => node.id).toSet();
  final visibleEdges = <GraphEdge>[
    for (final edge in raw.edges)
      if (visibleIds.contains(edge.fromId) && visibleIds.contains(edge.toId))
        edge,
    ...aggregateEdges,
  ];

  return GraphProjection(
    scenario: GraphScenario(
      name: raw.name,
      seedId: actualFocusId,
      nodes: visibleNodes,
      edges: visibleEdges,
      now: raw.now,
    ),
    aggregateMembers: aggregateMembers,
    visibleRawIds: visibleRawIds,
  );
}

int _compareNeighbors(_Neighbor a, _Neighbor b) {
  final edge = _edgePriority(a.edge.kind).compareTo(_edgePriority(b.edge.kind));
  if (edge != 0) return edge;
  final type = _typePriority(a.node.type).compareTo(_typePriority(b.node.type));
  if (type != 0) return type;
  final recent = b.node.createdAt.compareTo(a.node.createdAt);
  return recent != 0 ? recent : a.node.id.compareTo(b.node.id);
}

int _edgePriority(GraphEdgeKind kind) => switch (kind) {
  GraphEdgeKind.containment => 0,
  GraphEdgeKind.blocks => 1,
  GraphEdgeKind.followsUp => 2,
  GraphEdgeKind.fixes => 3,
  GraphEdgeKind.duplicates => 4,
  GraphEdgeKind.supersedes => 5,
  GraphEdgeKind.provenance => 6,
  GraphEdgeKind.evaluation => 7,
  GraphEdgeKind.checklist => 8,
  GraphEdgeKind.association => 9,
};

int _typePriority(GraphNodeType type) => switch (type) {
  GraphNodeType.project => 0,
  GraphNodeType.task => 1,
  GraphNodeType.aiResponse => 2,
  GraphNodeType.checklist => 3,
  GraphNodeType.rating => 4,
  GraphNodeType.textEntry => 5,
  GraphNodeType.audioEntry => 6,
  GraphNodeType.imageEntry => 7,
  GraphNodeType.checklistItem => 8,
  GraphNodeType.mediaCollection => 9,
  GraphNodeType.aggregate => 10,
};
