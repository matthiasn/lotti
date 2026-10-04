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
import 'package:material_ui/material_ui.dart';

part 'knowledge_graph_view_chrome_part.dart';
part 'knowledge_graph_view_images_part.dart';
part 'knowledge_graph_view_motion_part.dart';

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
  static const double _minimumFramedScale = 0.45;
  static const double _maximumFramedScale = 1.5;

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

  // Floating chrome is measured rather than estimated: the label solver must
  // know exactly which pixels are already spoken for (guessing let callouts
  // slide under the toolbar), and the camera framing must keep the focus
  // neighborhood clear of the legend/minimap column (a fixed 104px guess left
  // nodes hidden behind a legend more than twice that tall).
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'knowledge-graph-canvas');
  final GlobalKey _toolbarKey = GlobalKey(
    debugLabel: 'knowledge-graph-toolbar',
  );
  final GlobalKey _legendKey = GlobalKey(debugLabel: 'knowledge-graph-legend');
  final GlobalKey _minimapKey = GlobalKey(
    debugLabel: 'knowledge-graph-minimap',
  );
  final GlobalKey _titleKey = GlobalKey(debugLabel: 'knowledge-graph-title');

  Rect? _toolbarRect;
  Rect? _legendRect;
  Rect? _minimapRect;
  Rect? _titleRect;

  /// Whether the user has taken the camera over (gesture, walk, recenter).
  /// Until then the opening framing is re-derived when chrome measurements
  /// land, so the first paint's estimate is corrected in the next frame
  /// instead of leaving the graph framed under its own chrome.
  bool _userAdjustedCamera = false;

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

  /// Measures the floating chrome (toolbar, title card, legend, minimap) in the
  /// canvas's own coordinate space after a frame, and re-frames the opening
  /// camera once real sizes are known. Only writes state when a rect actually
  /// moved, so repeated post-frame passes converge instead of looping.
  void _measureChrome() {
    if (!mounted) return;
    final canvasObject = _canvasKey.currentContext?.findRenderObject();
    if (canvasObject is! RenderBox || !canvasObject.hasSize) return;
    final pad = _visualSpec == null ? 8.0 : context.designTokens.spacing.step3;

    Rect? rectOf(GlobalKey key) {
      final object = key.currentContext?.findRenderObject();
      if (object is! RenderBox || !object.hasSize) return null;
      final origin = canvasObject.globalToLocal(
        object.localToGlobal(
          Offset.zero,
        ),
      );
      return (origin & object.size).inflate(pad);
    }

    final toolbar = rectOf(_toolbarKey);
    final legend = rectOf(_legendKey);
    final minimap = rectOf(_minimapKey);
    final title = rectOf(_titleKey);

    bool changed(Rect? a, Rect? b) {
      if (a == null || b == null) return a != b;
      return (a.left - b.left).abs() > 0.5 ||
          (a.top - b.top).abs() > 0.5 ||
          (a.right - b.right).abs() > 0.5 ||
          (a.bottom - b.bottom).abs() > 0.5;
    }

    if (!changed(toolbar, _toolbarRect) &&
        !changed(legend, _legendRect) &&
        !changed(minimap, _minimapRect) &&
        !changed(title, _titleRect)) {
      return;
    }

    setState(() {
      _toolbarRect = toolbar;
      _legendRect = legend;
      _minimapRect = minimap;
      _titleRect = title;
      if (!_userAdjustedCamera && _initialized && !_lastSize.isEmpty) {
        final (scale, pan) = _framedTransform(_lastSize, _focusId);
        _scale = scale;
        _pan = pan;
      }
    });
  }

  /// Insets the framing keeps clear of floating chrome.
  ({double top, double bottom, double right}) _chromeReserve(Size size) {
    const fallbackMargin = 60.0;
    var top = widget.showTitle ? 84.0 : fallbackMargin;
    if (_toolbarRect != null) {
      top = math.max(fallbackMargin, _toolbarRect!.bottom);
    }
    if (_titleRect != null) {
      top = math.max(top, _titleRect!.bottom);
    }

    var bottom = widget.showLegend ? 104.0 : fallbackMargin;
    final bottomEdges = <double>[
      if (_legendRect != null) _legendRect!.top,
      if (_minimapRect != null) _minimapRect!.top,
    ];
    if (bottomEdges.isNotEmpty) {
      bottom = math.max(
        fallbackMargin,
        size.height - bottomEdges.reduce(math.min),
      );
    }

    // The inspector's footprint is derived from its own width rule, not a
    // guess, so it needs no measurement.
    final right = _inspectorVisible(size)
        ? _inspectorWidth(size.width) + 32
        : 0.0;
    return (top: top, bottom: bottom, right: right);
  }

  /// Transform that frames [focusId]'s 2-hop neighborhood in [size].
  (double, Offset) _framedTransform(Size size, String focusId) {
    final hops = _bfs(focusId);
    final regionNodes = _displayScenario.nodes
        .where(
          (n) => (hops[n.id] ?? 99) <= 2 && _layout.positions[n.id] != null,
        )
        .toList();
    final focusPos = _layout.positions[focusId] ?? Offset.zero;
    if (regionNodes.isEmpty) {
      return (1, Offset(size.width / 2, size.height / 2));
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final node in regionNodes) {
      final p = _layout.positions[node.id]!;
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    const margin = 60;
    // Measured chrome (see [_chromeReserve]) — the focus neighborhood frames
    // into what is actually visible, instead of into a fixed guess that let
    // the legend/minimap column cover real nodes.
    final reserve = _chromeReserve(size);
    final topReserve = reserve.top;
    final bottomReserve = reserve.bottom;
    final rightReserve = reserve.right;
    final availW = math.max(size.width - margin * 2 - rightReserve, 80);
    final availH = math.max(size.height - topReserve - bottomReserve, 80);

    // Nodes are CIRCLES, not points: framing their centres lets a body — up
    // to twice the ordinary diameter for media-backed nodes — hang past the
    // reserved edge and sit behind the toolbar or legend. Radius is a
    // screen-space function of the very scale being solved for, so take one
    // refinement pass: fit centres, measure the widest body at that scale,
    // convert it back to world units and refit with the bounds inflated.
    // `nodeRadiusFor` clamps its zoom factor, so one pass converges.
    double solveScale(double worldPad) {
      final bw = math.max(maxX - minX + worldPad * 2, 1);
      final bh = math.max(maxY - minY + worldPad * 2, 1);
      return math
          .min(availW / bw, availH / bh)
          .clamp(_minimumFramedScale, _maximumFramedScale);
    }

    final firstPass = solveScale(0);
    var widestBody = 0.0;
    for (final node in regionNodes) {
      widestBody = math.max(
        widestBody,
        KnowledgeGraphPainter.nodeRadiusFor(
          node: node,
          scenario: _displayScenario,
          degrees: _degrees,
          focusId: focusId,
          hops: hops,
          scale: firstPass,
          visualSpec: _visualSpec,
        ),
      );
    }
    final scale = solveScale(widestBody / firstPass);

    // Center the focus a touch above middle so its neighbors fan below.
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2 * 0.4 + focusPos.dy * 0.6;
    final viewportCenter = Offset(margin + availW / 2, topReserve + availH / 2);
    final pan = viewportCenter - Offset(cx, cy) * scale;
    return (scale, pan);
  }

  void _walkTo(String id) {
    if (id == _focusId) return;
    _userAdjustedCamera = true;
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

  void _applyFocusChange(String fromId) {
    _userAdjustedCamera = true;
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
    _userAdjustedCamera = true;
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
          final displayLabels = _displayLabels(context);
          final reservedLabelRects = _reservedLabelRects(
            context,
            size,
            inspectorVisible: inspectorVisible,
          );
          // Chrome sizes are content-dependent (the legend wraps, the toolbar
          // reflows), so re-measure after every frame; [_measureChrome] no-ops
          // unless something actually moved.
          WidgetsBinding.instance.addPostFrameCallback((_) => _measureChrome());
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
              key: _canvasKey,
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
                      key: _toolbarKey,
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
                      key: _titleKey,
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
                      key: _legendKey,
                      constraints: BoxConstraints(
                        maxWidth: visualSpec.legendMaxWidth,
                      ),
                      child: _LegendBar(
                        // Stable finder for tests asserting the legend's
                        // footprint is reserved (the measuring GlobalKey sits
                        // on the ConstrainedBox above and is private).
                        key: const ValueKey('knowledge-graph-legend'),
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
                      key: _minimapKey,
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
