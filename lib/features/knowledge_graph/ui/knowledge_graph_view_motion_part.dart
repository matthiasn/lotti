part of 'knowledge_graph_view.dart';

/// Graph traversal, navigation history, gestures and node motion for the knowledge graph. Members that write state stay in the State (the repo's extension-split rule).
extension _KnowledgeGraphMotion on _KnowledgeGraphViewState {
  Map<String, List<String>> _adjacencyFor(GraphScenario scenario) {
    final adjacency = {
      for (final node in scenario.nodes) node.id: <String>[],
    };
    for (final edge in scenario.edges) {
      adjacency[edge.fromId]?.add(edge.toId);
      adjacency[edge.toId]?.add(edge.fromId);
    }
    return adjacency;
  }

  Map<String, int> _bfs(String from) {
    final hops = <String, int>{from: 0};
    final queue = <String>[from];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      for (final nb in _displayAdjacency[cur] ?? const <String>[]) {
        if (!hops.containsKey(nb)) {
          hops[nb] = hops[cur]! + 1;
          queue.add(nb);
        }
      }
    }
    return hops;
  }

  /// Shortest path of node ids from [from] to [to] (inclusive).
  List<String> _path(String from, String to) {
    final parent = <String, String>{from: from};
    final queue = <String>[from];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      if (cur == to) break;
      for (final nb in _rawAdjacency[cur] ?? const <String>[]) {
        if (!parent.containsKey(nb)) {
          parent[nb] = cur;
          queue.add(nb);
        }
      }
    }
    if (!parent.containsKey(to)) return const [];
    final path = <String>[to];
    var cur = to;
    while (cur != from) {
      cur = parent[cur]!;
      path.add(cur);
    }
    return path.reversed.toList();
  }

  /// Whether the docked inspector panel is shown (desktop-width only).
  bool _inspectorVisible(Size size) =>
      widget.showInspector && size.width >= 720;

  /// Width of the docked inspector / detail panel — a fraction of the viewport,
  /// clamped to a comfortable range.
  double _inspectorWidth(double width) => (width * 0.30).clamp(320.0, 400.0);

  /// Rects the label solver must treat as occupied, and the camera must frame
  /// around. Falls back to the historical estimates only for the first frame,
  /// before the chrome has been measured.
  List<Rect> _chromeRects(Size size) => <Rect>[
    ?_toolbarRect,
    ?_titleRect,
    ?_legendRect,
    ?_minimapRect,
  ];

  void _back() {
    if (!_viewport.value.canGoBack) return;
    final fromId = _focusId;
    _viewport.goBack();
    _applyFocusChange(fromId);
  }

  void _forward() {
    if (!_viewport.value.canGoForward) return;
    final fromId = _focusId;
    _viewport.goForward();
    _applyFocusChange(fromId);
  }

  void _jumpTo(String id) {
    if (id == _focusId) return;
    final fromId = _focusId;
    _viewport.jumpTo(id);
    _applyFocusChange(fromId);
  }

  Offset? _displayWorldPosition(String id) {
    final rest = _layout.positions[id];
    if (rest == null) return null;
    return _motion.displayPosition(id, rest);
  }

  void _syncMotionWindow(String focusId) {
    final hops = _bfs(focusId);
    final ids = [..._displayScenario.nodes]
      ..sort((a, b) {
        final hop = (hops[a.id] ?? 99).compareTo(hops[b.id] ?? 99);
        if (hop != 0) return hop;
        return (_degrees[b.id] ?? 0).compareTo(_degrees[a.id] ?? 0);
      });
    _motion.configureForceIsland(
      restPositions: _layout.positions,
      edges: _displayScenario.edges,
      activeIds: ids
          .where((node) => (hops[node.id] ?? 99) <= 2)
          .take(_KnowledgeGraphViewState._maxMotionNodes)
          .map((node) => node.id),
    );
  }

  double _worldPixels(double px) => px / math.max(_scale, 0.45);

  void _kickWalkMotion(String fromId, String toId) {
    final from = _layout.positions[fromId];
    final to = _layout.positions[toId];
    final direction = from == null || to == null ? Offset.zero : to - from;
    _motion
      ..kick(
        toId,
        direction: direction,
        distance: _worldPixels(28),
        velocity: _worldPixels(260),
        dampingScale: 0.48,
      )
      ..kick(
        fromId,
        direction: -direction,
        distance: _worldPixels(7),
        velocity: _worldPixels(65),
      );
    _kickNeighborMotion(
      toId,
      exclude: {fromId, toId},
      distancePx: 6,
      velocityPx: 58,
    );
  }

  void _kickTouchMotion(
    String id, {
    Offset? localPosition,
    Offset? direction,
  }) {
    final rest = _layout.positions[id];
    if (rest == null) return;
    final screenCenter = (_displayWorldPosition(id) ?? rest) * _scale + _pan;
    final push =
        direction ??
        (localPosition == null ? Offset.zero : screenCenter - localPosition);
    _motion.kick(
      id,
      direction: push,
      distance: _worldPixels(10),
      velocity: _worldPixels(90),
    );
    _kickNeighborMotion(
      id,
      exclude: {id},
      distancePx: 3.5,
      velocityPx: 28,
    );
  }

  void _kickPanMotion(Offset screenVelocity) {
    if (screenVelocity.distance < 120) return;
    final strength = (screenVelocity.distance / 1400).clamp(0.25, 1).toDouble();
    _motion.kick(
      _focusId,
      direction: screenVelocity,
      distance: _worldPixels(6 * strength),
      velocity: _worldPixels(70 * strength),
    );
    _kickNeighborMotion(
      _focusId,
      exclude: {_focusId},
      distancePx: 2.5 * strength,
      velocityPx: 28 * strength,
    );
  }

  void _kickNeighborMotion(
    String id, {
    required Set<String> exclude,
    required double distancePx,
    required double velocityPx,
  }) {
    final origin = _layout.positions[id];
    if (origin == null) return;

    var count = 0;
    for (final neighborId in _displayAdjacency[id] ?? const <String>[]) {
      if (exclude.contains(neighborId)) continue;
      final neighbor = _layout.positions[neighborId];
      if (neighbor == null) continue;
      _motion.kick(
        neighborId,
        direction: neighbor - origin,
        distance: _worldPixels(distancePx),
        velocity: _worldPixels(velocityPx),
      );
      count++;
      if (count >= 16) break;
    }
  }

  void _onScaleStart(ScaleStartDetails d) {
    _userAdjustedCamera = true;
    _cam.stop();
    _fromScale = _scale;
    _fromPan = _pan;
    _gestureStartScale = _scale;
    _gestureStartPan = _pan;
    // LOCAL coordinates, never global: the painter's `world * scale + pan`
    // transform lives in the canvas's own space. In the real app the canvas
    // sits below/right of surrounding chrome (sidebar, header), so the global
    // focal is offset by a constant K — and anchoring on it makes the zoom
    // fixed point miss the cursor by K/scale, a scale-DEPENDENT error that
    // visibly slides the content under the cursor while zooming.
    _gestureStartFocal = d.localFocalPoint;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _kickPanMotion(d.velocity.pixelsPerSecond);
  }

  void _onTapUp(TapUpDetails d) {
    _graphFocusNode.requestFocus();
    final local = d.localPosition;
    String? hit;
    var best = double.infinity;
    for (final node in _displayScenario.nodes) {
      final world = _displayWorldPosition(node.id);
      if (world == null) continue;
      final screen = world * _scale + _pan;
      final dist = (local - screen).distance;
      final hitRadius = math.max(
        30,
        KnowledgeGraphPainter.nodeRadiusFor(
          node: node,
          scenario: _displayScenario,
          degrees: _degrees,
          focusId: _focusId,
          hops: _hops,
          scale: _scale,
          visualSpec: _visualSpec,
        ),
      );
      if (dist <= hitRadius && dist < best) {
        best = dist;
        hit = node.id;
      }
    }
    if (hit == null) return;
    _activateNode(hit, localPosition: local);
  }

  /// Direct neighbors of [id] (the other endpoint of every edge touching it),
  /// most-recent first — the inspector renders these as a tappable timeline of
  /// the focused node's linked entries.
  List<GraphNode> _neighborsOf(String id) {
    final byId = {for (final n in _scenario.nodes) n.id: n};
    final ids = <String>{};
    for (final e in _scenario.edges) {
      if (e.fromId == id) {
        ids.add(e.toId);
      } else if (e.toId == id) {
        ids.add(e.fromId);
      }
    }
    final list = [
      for (final nid in ids)
        if (byId[nid] != null) byId[nid]!,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// The label each displayed node is drawn with: aggregates read as
  /// `<kind> · <count>`, everything else by its own label.
  Map<String, String> _displayLabels(BuildContext context) => {
    for (final node in _displayScenario.nodes)
      node.id: switch (node.aggregateKind) {
        GraphAggregateKind.photos =>
          '${context.messages.knowledgeGraphNodeTypePhoto} · '
              '${node.aggregateCount}',
        GraphAggregateKind.relation =>
          '${context.messages.knowledgeGraphMoreLinks} · '
              '${node.aggregateCount}',
        null => node.label,
      },
  };

  /// Screen areas node labels must avoid: the inspector when it is
  /// visible, then the measured chrome, or an estimate of the legend and
  /// minimap on the first frame, before anything has been measured.
  List<Rect> _reservedLabelRects(
    BuildContext context,
    Size size, {
    required bool inspectorVisible,
  }) {
    final tokens = context.designTokens;
    final visualSpec = _visualSpec!;
    final measuredChrome = _chromeRects(size);
    return <Rect>[
      if (inspectorVisible)
        Rect.fromLTWH(
          size.width - _inspectorWidth(size.width) - tokens.spacing.step5 * 2,
          0,
          _inspectorWidth(size.width) + tokens.spacing.step5 * 2,
          size.height,
        ),
      // Real toolbar / title / legend / minimap rects once measured. The
      // estimate below only covers the very first frame: it assumed the
      // legend was exactly one minimap tall and ignored the toolbar
      // entirely, which is why callouts printed under the mode chips.
      ...measuredChrome,
      if (measuredChrome.isEmpty)
        Rect.fromLTWH(
          0,
          size.height -
              visualSpec.minimapHeight -
              tokens.spacing.step5 * 2 -
              (widget.showLegend ? visualSpec.minimapHeight : 0),
          math.max(
                visualSpec.minimapWidth,
                visualSpec.legendMaxWidth,
              ) +
              tokens.spacing.step5 * 2,
          visualSpec.minimapHeight * (widget.showLegend ? 2 : 1) +
              tokens.spacing.step5 * 2,
        ),
    ];
  }
}

/// Rebuilds the projected local graph around the focus: layout, degrees and display adjacency. It assigns fields but never calls setState; its callers do.
extension _KnowledgeGraphProjection on _KnowledgeGraphViewState {
  void _rebuildLocalGraph() {
    _projection = buildLocalGraphProjection(
      raw: _scenario,
      focusId: _focusId,
      maxNodes:
          _visualSpec?.nodeLimit(_viewport.value.density) ??
          GraphVisualSpec.defaultNodeLimit(_viewport.value.density),
      clusterPreviewLimit: GraphVisualSpec.defaultClusterPreviewLimit,
      clusterCollapseThreshold: GraphVisualSpec.defaultClusterCollapseThreshold,
      filters: _viewport.value.filters,
      expandedAggregateIds: _viewport.value.expandedAggregateIds,
    );
    _displayScenario = _projection.scenario;
    if (!_displayScenario.nodes.any(
      (node) => node.id == _viewport.value.selectedId,
    )) {
      _viewport.selectNode(_focusId);
    }
    _degrees = degreeMap(_displayScenario.edges);
    _displayAdjacency = _adjacencyFor(_displayScenario);
    final layoutHops = _bfs(_focusId);
    final collisionRadii = {
      for (final node in _displayScenario.nodes)
        node.id:
            KnowledgeGraphPainter.nodeRadiusFor(
              node: node,
              scenario: _displayScenario,
              degrees: _degrees,
              focusId: _focusId,
              hops: layoutHops,
              scale: _KnowledgeGraphViewState._minimumFramedScale,
              visualSpec: _visualSpec,
            ) /
            _KnowledgeGraphViewState._minimumFramedScale,
    };
    _layout = computeGraphLayout(
      _displayScenario,
      iterations: 140,
      collisionRadii: collisionRadii,
    );
  }
}
