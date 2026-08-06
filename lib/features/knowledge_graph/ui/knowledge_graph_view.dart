/// Host widget for the knowledge-graph explorer (ADR 0029).
///
/// Renders an explorable graph: the focus node (the one you're "standing on")
/// sits framed at center with its neighborhood; the rest of the world recedes
/// into faint horizon stars. Tapping a node "walks the link" — the camera glides
/// to it, it becomes the new focus, and its own neighbors come into view.
/// Pan / pinch-zoom free-look is always available.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_keyboard_navigation.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_label_layout.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_projection.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph/state/graph_image_cache.dart';
import 'package:lotti/features/knowledge_graph/state/graph_viewport_controller.dart';
import 'package:lotti/features/knowledge_graph/ui/entry_detail_sidebar.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_connections_view.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_motion_controller.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_workspace_toolbar.dart';
import 'package:lotti/features/knowledge_graph/ui/knowledge_graph_painter.dart';
import 'package:lotti/features/knowledge_graph/ui/node_inspector_panel.dart';
import 'package:lotti/features/knowledge_graph/ui/topology_minimap.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

typedef GraphImageLoader =
    Future<ui.Image> Function(String path, int targetExtent);

/// Decodes a graph thumbnail from local storage without retaining the full
/// source resolution.
Future<ui.Image> decodeGraphImageFile(String path, int targetExtent) async {
  if (targetExtent <= 0) {
    throw ArgumentError.value(targetExtent, 'targetExtent', 'must be positive');
  }
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final longestSide = math.max(descriptor.width, descriptor.height);
      final scale = math.min(1, targetExtent / longestSide);
      final targetWidth = math.max(1, (descriptor.width * scale).round());
      final targetHeight = math.max(1, (descriptor.height * scale).round());
      final codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    this.scenario,
    this.categoryColors,
    this.categoryNames = const {},
    this.initialFocusId,
    this.initialPreviousFocusId,
    this.layout,
    this.onTaskFocusChanged,
    this.showTitle = true,
    this.showLegend = true,
    this.showInspector = true,
    this.imageLoader,
    this.thumbnailCache,
    this.visualSpec,
    super.key,
  });

  final GraphScenario? scenario;

  /// Real category id → color (from `CategoryDefinition`s). When null the
  /// synthetic palette is used by the standalone preview scenarios.
  final Map<String, Color>? categoryColors;

  /// Real category id → display name (so the inspector/legend show names, not
  /// UUIDs). Falls back to the id when absent.
  final Map<String, String> categoryNames;

  /// Optional starting focus (defaults to the scenario seed) — lets a capture
  /// show a "walked-to" state deterministically.
  final String? initialFocusId;

  /// Optional node walked from — renders the persistent trail + ghost so a
  /// capture can show a mid-journey state.
  final String? initialPreviousFocusId;

  /// Pre-computed layout (e.g. relaxed off the main thread by
  /// `taskGraphProvider`). When null the view computes it synchronously in
  /// `initState` — fine for the small synthetic scenarios and tests.
  final GraphLayout? layout;

  /// Called after walk navigation lands on a task node. The page-level real-data
  /// host uses this to reload the graph around the newly focused task.
  final void Function(String taskId, String previousFocusId)?
  onTaskFocusChanged;

  final bool showTitle;
  final bool showLegend;
  final bool showInspector;

  /// Overrides local image decoding for deterministic tests.
  final GraphImageLoader? imageLoader;

  /// Long-lived store of decoded thumbnails. Hosts that remount this view on
  /// every data refresh (the task page keys it on the scenario) pass one cache
  /// so already-decoded node images paint on the remounted view's first frame
  /// instead of flashing away while they re-decode. When null the view owns a
  /// private cache with the pre-cache lifecycle (images die with the state).
  final GraphImageCache? thumbnailCache;

  /// Overrides graph geometry and styling for deterministic hosts and tests.
  final GraphVisualSpec? visualSpec;

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView>
    with TickerProviderStateMixin {
  static const int _maxMotionNodes = 52;

  late final GraphScenario _scenario;
  late final GraphLayout _topologyLayout;
  late GraphLayout _layout;
  late GraphProjection _projection;
  late GraphScenario _displayScenario;
  late Map<String, int> _degrees;
  late final Map<String, List<String>> _rawAdjacency;
  late Map<String, List<String>> _displayAdjacency;
  late final GraphViewportController _viewport;
  late final AnimationController _cam;
  late final AnimationController _wakeCtl;
  late final GraphMotionController _motion;
  GraphVisualSpec? _visualSpec;
  final GraphLabelLayoutMemory _labelMemory = GraphLabelLayoutMemory();
  final FocusNode _graphFocusNode = FocusNode(
    debugLabel: 'knowledge-graph-canvas',
  );

  late Map<String, int> _hops;

  /// Whether the focused entry's full-details side panel is open (overlaying
  /// the navigational inspector).
  bool _detailsOpen = false;
  bool _disableAnimations = false;
  int _requestedImageTargetExtent = 0;
  int _loadedImageTargetExtent = 0;
  bool _imageLoadActive = false;
  String? _previousFocusId;
  List<String> _walkPath = const [];
  Offset _focusWorld = Offset.zero;
  late final GraphImageCache _thumbnails;
  late final bool _ownsThumbnails;
  Map<String, ui.Image> _images = const {};

  double _scale = 1;
  Offset _pan = Offset.zero;
  bool _initialized = false;
  Size _lastSize = Size.zero;

  // Camera-glide endpoints.
  double _fromScale = 1;
  double _toScale = 1;
  Offset _fromPan = Offset.zero;
  Offset _toPan = Offset.zero;

  double get _wake => 1 - _wakeCtl.value;
  String get _focusId => _viewport.value.focusId;

  @override
  void initState() {
    super.initState();
    _scenario = widget.scenario ?? exploreWorldScenario();
    _visualSpec = widget.visualSpec;
    _thumbnails = widget.thumbnailCache ?? GraphImageCache();
    _ownsThumbnails = widget.thumbnailCache == null;
    // A shared cache carries thumbnails across host-driven remounts: prune
    // entries the new scenario no longer references, then paint whatever is
    // already decoded on the very first frame — a data refresh must never
    // flash established node images away while they re-decode.
    _thumbnails.retainOnly(_scenarioImagePaths());
    _images = _thumbnails.snapshot();
    _rawAdjacency = _adjacencyFor(_scenario);
    final initialFocusId =
        widget.initialFocusId != null &&
            _scenario.nodes.any((n) => n.id == widget.initialFocusId)
        ? widget.initialFocusId!
        : _scenario.seedId;
    _viewport = GraphViewportController(initialFocusId: initialFocusId);
    // The provider's full layout now belongs to the topology minimap. The main
    // canvas always receives a bounded, focus-centred projection.
    _topologyLayout = widget.layout ?? computeLayoutForScenario(_scenario);
    _rebuildLocalGraph();
    _hops = _bfs(_focusId);
    _focusWorld = _layout.positions[_focusId] ?? Offset.zero;
    _motion = GraphMotionController(vsync: this);
    _syncMotionWindow(_focusId);
    final prev = widget.initialPreviousFocusId;
    if (prev != null && _scenario.nodes.any((n) => n.id == prev)) {
      _previousFocusId = prev;
      _walkPath = _path(prev, _focusId);
    }
    _cam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..addListener(_tickCamera);
    // Idle at value 1 so the trail rests faint (wake == 0); a walk drives it
    // from 0 (bright) back to 1.
    _wakeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      value: 1,
    )..addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visualSpec =
        widget.visualSpec ??
        GraphVisualSpec.fromTokens(
          context.designTokens,
          categoryColors: widget.categoryColors,
          highContrast: MediaQuery.highContrastOf(context),
        );
    _visualSpec = visualSpec;
    _disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _motion.setReduceMotion(value: _disableAnimations);
    if (_disableAnimations) {
      _cam.stop();
      _wakeCtl
        ..stop()
        ..value = 1;
    }
    _requestImageLoad(visualSpec);
  }

  @override
  void didUpdateWidget(KnowledgeGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visualSpec == widget.visualSpec &&
        oldWidget.categoryColors == widget.categoryColors) {
      return;
    }
    _visualSpec =
        widget.visualSpec ??
        GraphVisualSpec.fromTokens(
          context.designTokens,
          categoryColors: widget.categoryColors,
          highContrast: MediaQuery.highContrastOf(context),
        );
    _requestImageLoad(_visualSpec!);
    _rebuildLocalGraph();
    _hops = _bfs(_focusId);
  }

  void _requestImageLoad(GraphVisualSpec visualSpec) {
    final targetExtent =
        (visualSpec.mediaDecodeLogicalExtent *
                MediaQuery.devicePixelRatioOf(context))
            .ceil();
    if (targetExtent <= _requestedImageTargetExtent) return;
    _requestedImageTargetExtent = targetExtent;
    if (!_imageLoadActive) {
      unawaited(_drainImageLoads());
    }
  }

  /// Decode task covers, entry images, and aggregate thumbnails off the main
  /// work. Larger requests are serialized and replace existing thumbnails only
  /// after the new batch is ready.
  Future<void> _drainImageLoads() async {
    _imageLoadActive = true;
    try {
      while (mounted &&
          _loadedImageTargetExtent < _requestedImageTargetExtent) {
        final targetExtent = _requestedImageTargetExtent;
        final loaded = await _loadImages(targetExtent);
        if (!mounted) {
          _disposeImages(loaded.images.values, retained: _images.values);
          return;
        }
        _installImages(
          loaded.images,
          loaded.signatures,
          loaded.evictions,
          targetExtent,
        );
        _loadedImageTargetExtent = targetExtent;
      }
    } finally {
      _imageLoadActive = false;
    }
  }

  Set<String> _scenarioImagePaths() => {
    for (final node in _scenario.nodes) ...[
      if (node.imagePath case final path? when path.isNotEmpty) path,
      if (node.coverImagePath case final path? when path.isNotEmpty) path,
      ...node.mediaPaths.where((path) => path.isNotEmpty),
    ],
  };

  /// Content signature (size + mtime) of the file at [path], or null when it
  /// cannot be stat'ed (missing file, synthetic test path). Media files are
  /// overwritten in place at deterministic paths (photo re-import, sync
  /// self-healing fetch), so cache validity must track the bytes on disk, not
  /// just the decode extent. Synchronous by design: `stat` metadata is cheap,
  /// and async real IO would stall the drain under widget-test fake async.
  static String? _fileSignatureOf(String path) {
    try {
      final stat = File(path).statSync();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    } on Object {
      return null;
    }
  }

  Future<
    ({
      Map<String, ui.Image> images,
      Map<String, String?> signatures,
      Set<String> evictions,
    })
  >
  _loadImages(int targetExtent) async {
    final loaded = <String, ui.Image>{};
    final signatures = <String, String?>{};
    final evictions = <String>{};
    final loadImage = widget.imageLoader ?? decodeGraphImageFile;
    for (final path in _scenarioImagePaths()) {
      // Cached thumbnails survive remounts via the shared cache — only decode
      // what is missing, too small for the current device-pixel target, or
      // whose source file changed since it was decoded. An unavailable
      // signature falls back to the extent-only check (test loaders use
      // synthetic paths), EXCEPT when the entry was decoded from a real file
      // (it has a signature) and that file is now gone — then the entry is
      // evicted so a deleted photo falls back to the type glyph instead of
      // rendering its stale thumbnail forever.
      final signature = _fileSignatureOf(path);
      if (signature == null && _thumbnails.signatureOf(path) != null) {
        evictions.add(path);
      } else {
        final cachedFresh =
            _thumbnails.decodedExtentOf(path) >= targetExtent &&
            (signature == null || signature == _thumbnails.signatureOf(path));
        if (cachedFresh) continue;
      }
      try {
        final image = await loadImage(path, targetExtent);
        if (!mounted) {
          // Disposed mid-decode — release what we decoded and bail.
          // coverage:ignore-start
          _disposeImages(
            [...loaded.values, image],
            retained: _images.values,
          );
          return (
            images: const <String, ui.Image>{},
            signatures: const <String, String?>{},
            evictions: const <String>{},
          );
          // coverage:ignore-end
        }
        loaded[path] = image;
        signatures[path] = signature;
      } on Object {
        // Missing/unreadable file — fall back to the type glyph.
      }
    }
    return (images: loaded, signatures: signatures, evictions: evictions);
  }

  void _installImages(
    Map<String, ui.Image> loaded,
    Map<String, String?> signatures,
    Set<String> evictions,
    int targetExtent,
  ) {
    if (loaded.isEmpty && evictions.isEmpty) return;
    final replaced = <ui.Image>[];
    // Apply evictions (deleted source files) before installs, so a path that
    // both evicted and successfully re-decoded ends up with the fresh image.
    for (final path in evictions) {
      final removed = _thumbnails.remove(path);
      if (removed != null) replaced.add(removed);
    }
    for (final MapEntry(:key, :value) in loaded.entries) {
      final displaced = _thumbnails.put(
        key,
        value,
        extent: targetExtent,
        signature: signatures[key],
      );
      if (displaced != null) replaced.add(displaced);
    }
    setState(() {
      // Snapshot is a fresh (unmodifiable) map so the painter's
      // identity-based `shouldRepaint` detects the completed thumbnail batch.
      _images = _thumbnails.snapshot();
    });
    // Displaced (lower-extent) images are disposed only after the painter's
    // map has been swapped, so a pending frame never paints a disposed image.
    _disposeImages(replaced, retained: _images.values);
  }

  void _disposeImages(
    Iterable<ui.Image> images, {
    Iterable<ui.Image> retained = const [],
  }) {
    final disposed = <ui.Image>[];
    for (final image in images) {
      final shouldDispose =
          !retained.any((candidate) => identical(candidate, image)) &&
          !disposed.any((candidate) => identical(candidate, image));
      if (shouldDispose) {
        image.dispose();
        disposed.add(image);
      }
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    _wakeCtl.dispose();
    _motion.dispose();
    _viewport.dispose();
    _graphFocusNode.dispose();
    // A host-provided cache outlives this state by design — the host disposes
    // it. Only a view-private cache dies with the state.
    if (_ownsThumbnails) {
      _thumbnails.dispose();
    }
    super.dispose();
  }

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
    _layout = computeGraphLayout(_displayScenario, iterations: 140);
    _degrees = degreeMap(_displayScenario.edges);
    _displayAdjacency = _adjacencyFor(_displayScenario);
  }

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

  void _tickCamera() {
    final v = _cam.value;
    // Smooth decelerating glide (no overshoot) — calmer than the emphasized
    // curve, still clearly non-linear.
    final t = Curves.fastOutSlowIn.transform(v);
    final baseScale = _fromScale + (_toScale - _fromScale) * t;
    final basePan = Offset.lerp(_fromPan, _toPan, t)!;
    // Very subtle travel "dolly", anchored on the focus so it reads as a gentle
    // lift rather than an elastic pull-back.
    final dip = math.sin(math.pi * t) * 0.04;
    final s = baseScale * (1 - dip);
    final screenFocus = _focusWorld * baseScale + basePan;
    setState(() {
      _scale = s;
      _pan = screenFocus - _focusWorld * s;
    });
  }

  /// Whether the docked inspector panel is shown (desktop-width only).
  bool _inspectorVisible(Size size) =>
      widget.showInspector && size.width >= 720;

  /// Width of the docked inspector / detail panel — a fraction of the viewport,
  /// clamped to a comfortable range.
  double _inspectorWidth(double width) => (width * 0.30).clamp(320.0, 400.0);

  /// Transform that frames [focusId]'s 2-hop neighborhood in [size].
  (double, Offset) _framedTransform(Size size, String focusId) {
    final hops = _bfs(focusId);
    final region = _displayScenario.nodes
        .where((n) => (hops[n.id] ?? 99) <= 2)
        .map((n) => _layout.positions[n.id])
        .whereType<Offset>()
        .toList();
    final focusPos = _layout.positions[focusId] ?? Offset.zero;
    if (region.isEmpty) return (1, Offset(size.width / 2, size.height / 2));

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in region) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    final bw = math.max(maxX - minX, 1);
    final bh = math.max(maxY - minY, 1);
    const margin = 60;
    final topReserve = widget.showTitle ? 84 : margin;
    final bottomReserve = widget.showLegend ? 104 : margin;
    // Reserve the inspector's footprint on the right (panel width + insets) so
    // the focus frames in the visible area rather than centred under the panel.
    final rightReserve = _inspectorVisible(size)
        ? _inspectorWidth(size.width) + 32
        : 0.0;
    final availW = math.max(size.width - margin * 2 - rightReserve, 80);
    final availH = math.max(size.height - topReserve - bottomReserve, 80);
    final scale = math.min(availW / bw, availH / bh).clamp(0.45, 1.5);
    // Center the focus a touch above middle so its neighbors fan below.
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2 * 0.4 + focusPos.dy * 0.6;
    final viewportCenter = Offset(margin + availW / 2, topReserve + availH / 2);
    final pan = viewportCenter - Offset(cx, cy) * scale;
    return (scale, pan);
  }

  void _walkTo(String id) {
    if (id == _focusId) return;
    final fromId = _focusId;
    _viewport.walkTo(id);
    _previousFocusId = fromId;
    _walkPath = _path(fromId, id);
    _rebuildLocalGraph();
    _hops = _bfs(id);
    _syncMotionWindow(id);
    _kickWalkMotion(fromId, id);
    if (_scenario.nodeById(id).type == GraphNodeType.task) {
      widget.onTaskFocusChanged?.call(id, fromId);
    }
    _focusWorld = _layout.positions[id] ?? Offset.zero;
    final (ts, tp) = _framedTransform(_lastSize, id);
    _fromScale = _scale;
    _fromPan = _pan;
    _toScale = ts;
    _toPan = tp;
    if (_disableAnimations) {
      _cam.stop();
      _wakeCtl
        ..stop()
        ..value = 1;
      setState(() {
        _scale = ts;
        _pan = tp;
      });
      return;
    }
    _cam.forward(from: 0);
    _wakeCtl.forward(from: 0);
    setState(() {});
  }

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

  void _applyFocusChange(String fromId) {
    _previousFocusId = fromId;
    _walkPath = _path(fromId, _focusId);
    _rebuildLocalGraph();
    _hops = _bfs(_focusId);
    _syncMotionWindow(_focusId);
    _kickWalkMotion(fromId, _focusId);
    if (_scenario.nodeById(_focusId).type == GraphNodeType.task) {
      widget.onTaskFocusChanged?.call(_focusId, fromId);
    }
    _focusWorld = _layout.positions[_focusId] ?? Offset.zero;
    final (ts, tp) = _framedTransform(_lastSize, _focusId);
    _fromScale = _scale;
    _fromPan = _pan;
    _toScale = ts;
    _toPan = tp;
    if (_disableAnimations) {
      _cam.stop();
      _wakeCtl
        ..stop()
        ..value = 1;
      setState(() {
        _scale = ts;
        _pan = tp;
      });
      return;
    }
    _cam.forward(from: 0);
    _wakeCtl.forward(from: 0);
    setState(() {});
  }

  void _recenter() {
    _focusWorld = _layout.positions[_focusId] ?? Offset.zero;
    final (ts, tp) = _framedTransform(_lastSize, _focusId);
    _fromScale = _scale;
    _fromPan = _pan;
    _toScale = ts;
    _toPan = tp;
    if (_disableAnimations) {
      _cam.stop();
      _wakeCtl
        ..stop()
        ..value = 1;
      setState(() {
        _scale = ts;
        _pan = tp;
      });
      return;
    }
    _cam.forward(from: 0);
  }

  void _setMode(GraphViewMode mode) {
    _viewport.setMode(mode);
    setState(() {});
  }

  void _setDensity(GraphDensity density) {
    _viewport.setDensity(density);
    setState(() {
      _rebuildLocalGraph();
      _hops = _bfs(_focusId);
      _syncMotionWindow(_focusId);
      final (nextScale, nextPan) = _framedTransform(_lastSize, _focusId);
      _scale = nextScale;
      _pan = nextPan;
    });
  }

  void _setFilters(GraphProjectionFilters filters) {
    _viewport.setFilters(filters);
    setState(() {
      _rebuildLocalGraph();
      _hops = _bfs(_focusId);
      _syncMotionWindow(_focusId);
      final (nextScale, nextPan) = _framedTransform(_lastSize, _focusId);
      _scale = nextScale;
      _pan = nextPan;
    });
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
          .take(_maxMotionNodes)
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

  double _gestureStartScale = 1;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final newScale = (_gestureStartScale * d.scale).clamp(0.25, 3.0);
    // Anchor-point zoom: the world point that sat under the gesture's start
    // focal must stay under the (current) focal. Trackpad scroll-zoom reports
    // a focal fixed at the cursor, so the content under the cursor holds
    // still; a moving touch/pinch focal additionally pans by its own delta.
    final worldUnderFocal =
        (_gestureStartFocal - _gestureStartPan) / _gestureStartScale;
    setState(() {
      _scale = newScale;
      _pan = d.localFocalPoint - worldUnderFocal * newScale;
    });
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

  KeyEventResult _onGraphKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _viewport.value.canGoBack) {
      _back();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _activateNode(_viewport.value.selectedId);
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -1),
      LogicalKeyboardKey.arrowDown => const Offset(0, 1),
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    final next = nearestGraphNodeInDirection(
      positions: _layout.positions,
      fromId: _viewport.value.selectedId,
      direction: direction,
    );
    if (next == null) return KeyEventResult.ignored;
    _viewport.selectNode(next);
    setState(() {});
    return KeyEventResult.handled;
  }

  void _activateNode(String id, {Offset? localPosition}) {
    if (id == _focusId) {
      _kickTouchMotion(id, localPosition: localPosition);
    } else if (_displayScenario.nodeById(id).isAggregate) {
      _viewport.toggleAggregate(id);
      setState(() {
        _rebuildLocalGraph();
        _hops = _bfs(_focusId);
        _syncMotionWindow(_focusId);
        final (nextScale, nextPan) = _framedTransform(_lastSize, _focusId);
        _scale = nextScale;
        _pan = nextPan;
      });
    } else {
      _walkTo(id);
    }
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final visualSpec = _visualSpec!;
    final style = visualSpec.style;
    // The host page reserves its floating header's height in this view's top
    // padding (status bar + header), so the phone-only title chip clears the
    // header instead of hiding under it. Zero in the standalone preview.
    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: style.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          _lastSize = size;
          // The inspector (desktop) already names the focus + carries its
          // detail, and the page AppBar names the view — so the floating title
          // chip is only shown when the inspector is absent (phone), avoiding a
          // redundant/contradictory second identity.
          final inspectorVisible = _inspectorVisible(size);
          final displayLabels = <String, String>{
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
          final reservedLabelRects = <Rect>[
            if (inspectorVisible)
              Rect.fromLTWH(
                size.width -
                    _inspectorWidth(size.width) -
                    tokens.spacing.step5 * 2,
                0,
                _inspectorWidth(size.width) + tokens.spacing.step5 * 2,
                size.height,
              ),
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
          if (!_initialized && size.isFinite && !size.isEmpty) {
            final (s, p) = _framedTransform(size, _focusId);
            _scale = s;
            _pan = p;
            _initialized = true;
          }

          // Transparent Material so overlay Text/IconButtons have a Material
          // ancestor (otherwise they render with debug yellow underlines).
          return Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                if (_viewport.value.mode == GraphViewMode.graph)
                  Positioned.fill(
                    child: Focus(
                      focusNode: _graphFocusNode,
                      onKeyEvent: _onGraphKeyEvent,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        trackpadScrollCausesScale: true,
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onScaleEnd: _onScaleEnd,
                        onTapUp: _onTapUp,
                        child: CustomPaint(
                          painter: KnowledgeGraphPainter(
                            scenario: _displayScenario,
                            positions: _layout.positions,
                            degrees: _degrees,
                            scale: _scale,
                            pan: _pan,
                            focusId: _focusId,
                            hops: _hops,
                            selectedId: _viewport.value.selectedId,
                            style: style,
                            visualSpec: visualSpec,
                            nodeLabels: displayLabels,
                            reservedLabelRects: reservedLabelRects,
                            labelMemory: _labelMemory,
                            textScaler: MediaQuery.textScalerOf(context),
                            textDirection: Directionality.of(context),
                            onNodeActivate: _activateNode,
                            images: _images,
                            previousFocusId: _previousFocusId,
                            walkPath: _walkPath,
                            wake: _wake,
                            motion: _motion,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: inspectorVisible
                        ? _inspectorWidth(size.width) + tokens.spacing.step10
                        : 0,
                    child: GraphConnectionsView(
                      scenario: _scenario,
                      focusId: _focusId,
                      filters: _viewport.value.filters,
                      categoryNames: widget.categoryNames,
                      onNodeTap: _walkTo,
                    ),
                  ),
                Positioned(
                  left: tokens.spacing.step5,
                  top: topInset + tokens.spacing.step5,
                  right: inspectorVisible
                      ? _inspectorWidth(size.width) + tokens.spacing.step10
                      : tokens.spacing.step5,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: GraphWorkspaceToolbar(
                      state: _viewport.value,
                      scenario: _scenario,
                      categoryNames: widget.categoryNames,
                      onModeChanged: _setMode,
                      onDensityChanged: _setDensity,
                      onFiltersChanged: _setFilters,
                    ),
                  ),
                ),
                if (widget.showTitle && !inspectorVisible)
                  Positioned(
                    left: tokens.spacing.step5,
                    top:
                        topInset + tokens.spacing.step13 + tokens.spacing.step8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TitleCard(
                          focus: _scenario.nodeById(_focusId),
                          total: _scenario.nodes.length,
                          explorable:
                              _scenario.nodes.length > kWorldScaleThreshold,
                          tokens: tokens,
                        ),
                        if (_scenario.nodes.length > kWorldScaleThreshold) ...[
                          SizedBox(height: tokens.spacing.step3),
                          _Controls(
                            canGoBack: _viewport.value.canGoBack,
                            canGoForward: _viewport.value.canGoForward,
                            onBack: _back,
                            onForward: _forward,
                            onRecenter: _recenter,
                            tokens: tokens,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (inspectorVisible)
                  Positioned(
                    top: tokens.spacing.step5,
                    bottom: tokens.spacing.step5,
                    right: tokens.spacing.step5,
                    child: SizedBox(
                      width: _inspectorWidth(size.width),
                      child: NodeInspectorPanel(
                        node: _scenario.nodeById(_focusId),
                        neighbors: _neighborsOf(_focusId),
                        now: _scenario.now,
                        createdLabel: relativeAge(
                          context.messages,
                          _scenario.now.difference(
                            _scenario.nodeById(_focusId).createdAt,
                          ),
                        ),
                        categoryNames: widget.categoryNames,
                        style: style,
                        tokens: tokens,
                        onNeighborTap: _walkTo,
                        canGoBack: _viewport.value.canGoBack,
                        onBack: _back,
                        onRecenter: _recenter,
                        onOpen: () => setState(() => _detailsOpen = true),
                      ),
                    ),
                  ),
                // Full-details overlay — renders above the inspector when an
                // entry is opened, tracking the current focus.
                if (inspectorVisible && _detailsOpen)
                  Positioned(
                    top: tokens.spacing.step5,
                    bottom: 0,
                    right: tokens.spacing.step5,
                    child: SizedBox(
                      width: (size.width * 0.34).clamp(360.0, 460.0),
                      child: _DeferredEntryDetailSidebar(
                        key: ValueKey(_focusId),
                        entryId: _focusId,
                        onClose: () => setState(() => _detailsOpen = false),
                        tokens: tokens,
                      ),
                    ),
                  ),
                if (widget.showLegend &&
                    _viewport.value.mode == GraphViewMode.graph)
                  Positioned(
                    left: tokens.spacing.step5,
                    bottom:
                        tokens.spacing.step5 +
                        visualSpec.minimapHeight +
                        tokens.spacing.step3,
                    // Narrow, left-aligned block that wraps to multiple rows so
                    // it stays clear of the right-hand panel instead of spanning
                    // the full width under it.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: visualSpec.legendMaxWidth,
                      ),
                      child: _LegendBar(
                        scenario: _displayScenario,
                        style: style,
                        categoryNames: widget.categoryNames,
                        tokens: tokens,
                      ),
                    ),
                  ),
                if (_viewport.value.mode == GraphViewMode.graph)
                  Positioned(
                    left: tokens.spacing.step5,
                    bottom: tokens.spacing.step5,
                    child: TopologyMiniMap(
                      scenario: _scenario,
                      layout: _topologyLayout,
                      focusId: _focusId,
                      visibleNodeIds: _projection.visibleRawIds,
                      spec: visualSpec,
                      semanticsLabel:
                          context.messages.knowledgeGraphTopologyOverview,
                      onJump: _jumpTo,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Defers the nested detail navigator until after the graph's layout callback.
///
/// [KnowledgeGraphView] builds its responsive workspace from a [LayoutBuilder].
/// [EntryDetailSidebar] activates a nested [Navigator] route through Flutter's
/// overlay portal. Activating that subtree while the layout builder is inside
/// `performLayout` can reattach one of the task page's own layout builders and
/// trip Flutter's render-object mutation guard. The first frame reserves the
/// panel slot; the post-frame rebuild activates the navigator in the normal
/// build phase.
class _DeferredEntryDetailSidebar extends StatefulWidget {
  const _DeferredEntryDetailSidebar({
    required this.entryId,
    required this.onClose,
    required this.tokens,
    super.key,
  });

  final String entryId;
  final VoidCallback onClose;
  final DsTokens tokens;

  @override
  State<_DeferredEntryDetailSidebar> createState() =>
      _DeferredEntryDetailSidebarState();
}

class _DeferredEntryDetailSidebarState
    extends State<_DeferredEntryDetailSidebar> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _active = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.expand();
    return EntryDetailSidebar(
      entryId: widget.entryId,
      onClose: widget.onClose,
      tokens: widget.tokens,
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.focus,
    required this.total,
    required this.explorable,
    required this.tokens,
  });

  final GraphNode focus;
  final int total;
  final bool explorable;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            focus.label,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step1),
          Text(
            explorable
                ? context.messages.knowledgeGraphWalkHint(total)
                : context.messages.knowledgeGraphNodeCount(total),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  const _LegendBar({
    required this.scenario,
    required this.style,
    required this.categoryNames,
    required this.tokens,
  });

  final GraphScenario scenario;
  final GraphStyle style;
  final Map<String, String> categoryNames;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final relations = relStylesIn(scenario);
    final categories = scenario.nodes.map((n) => n.categoryId).toSet().toList()
      ..sort(
        (a, b) => categoryOrder.indexOf(a).compareTo(categoryOrder.indexOf(b)),
      );
    final channelColor = tokens.colors.text.mediumEmphasis;
    final freshHsl = HSLColor.fromColor(style.focusRing);
    final agedDot = freshHsl
        .withLightness((freshHsl.lightness * 0.42).clamp(0.0, 1.0))
        .withSaturation((freshHsl.saturation * 0.7).clamp(0.0, 1.0))
        .toColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: Wrap(
        spacing: tokens.spacing.step5,
        runSpacing: tokens.spacing.step3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final rel in relations)
            _LegendItem(
              label: relStyleLabel(context.messages, rel),
              tokens: tokens,
              swatch: SizedBox(
                width: 24,
                height: 10,
                child: CustomPaint(
                  painter: _EdgeSwatchPainter(visual: style.edgeVisual(rel)),
                ),
              ),
            ),
          for (final cat in categories)
            _LegendItem(
              label: graphCategoryLabel(context.messages, categoryNames, cat),
              tokens: tokens,
              swatch: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: style.categoryColor(cat),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          _LegendItem(
            label: context.messages.knowledgeGraphMoreLinks,
            tokens: tokens,
            swatch: _DotsSwatch(dots: [(7, channelColor), (13, channelColor)]),
          ),
          _LegendItem(
            label: context.messages.knowledgeGraphRecentToOlder,
            tokens: tokens,
            swatch: _DotsSwatch(dots: [(11, style.focusRing), (11, agedDot)]),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.swatch,
    required this.tokens,
  });

  final String label;
  final Widget swatch;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        SizedBox(width: tokens.spacing.step2),
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

/// A row of circles of given (diameter, color) — keys the size and brightness
/// encodings in the legend.
class _DotsSwatch extends StatelessWidget {
  const _DotsSwatch({required this.dots});

  final List<(double, Color)> dots;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (diameter, color) in dots)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

/// Back + recenter controls for the walk (only shown in explorable worlds).
class _Controls extends StatelessWidget {
  const _Controls({
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onRecenter,
    required this.tokens,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRecenter;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.arrow_back,
          tooltip: context.messages.knowledgeGraphBack,
          enabled: canGoBack,
          onTap: onBack,
          tokens: tokens,
        ),
        SizedBox(width: tokens.spacing.step2),
        _CircleButton(
          icon: Icons.arrow_forward,
          tooltip: context.messages.knowledgeGraphForward,
          enabled: canGoForward,
          onTap: onForward,
          tokens: tokens,
        ),
        SizedBox(width: tokens.spacing.step2),
        _CircleButton(
          icon: Icons.center_focus_strong,
          tooltip: context.messages.knowledgeGraphRecenter,
          enabled: true,
          onTap: onRecenter,
          tokens: tokens,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: tokens.colors.background.level02.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step3),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? tokens.colors.text.highEmphasis
                  : tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeSwatchPainter extends CustomPainter {
  _EdgeSwatchPainter({required this.visual});

  final EdgeVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = visual.color
      ..strokeWidth = visual.width
      ..strokeCap = StrokeCap.round;
    final dash = visual.dash;
    if (dash != null) {
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dash[0], size.width), y),
          paint,
        );
        x += dash[0] + dash[1];
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_EdgeSwatchPainter old) => old.visual != visual;
}
