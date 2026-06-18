/// Host widget for the knowledge-graph POC (ADR 0029, Phase 0 / "Local Sky").
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
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/entry_detail_sidebar.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_painter.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/node_inspector_panel.dart';

class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    this.scenario,
    this.categoryColors,
    this.categoryNames = const {},
    this.initialFocusId,
    this.initialPreviousFocusId,
    this.showTitle = true,
    this.showLegend = true,
    this.showInspector = true,
    super.key,
  });

  final GraphScenario? scenario;

  /// Real category id → color (from `CategoryDefinition`s). When null the
  /// synthetic palette is used (the standalone POC scenarios).
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
  final bool showTitle;
  final bool showLegend;
  final bool showInspector;

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView>
    with TickerProviderStateMixin {
  late final GraphScenario _scenario;
  late final GraphLayout _layout;
  late final Map<String, int> _degrees;
  late final Map<String, List<String>> _adjacency;
  late final bool _world;
  late final AnimationController _cam;
  late final AnimationController _wakeCtl;

  late String _focusId;
  late Map<String, int> _hops;
  final List<String> _history = [];

  /// Whether the focused entry's full-details side panel is open (overlaying
  /// the navigational inspector).
  bool _detailsOpen = false;
  String? _previousFocusId;
  List<String> _walkPath = const [];
  Offset _focusWorld = Offset.zero;
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

  @override
  void initState() {
    super.initState();
    _scenario = widget.scenario ?? exploreWorldScenario();
    _world = _scenario.nodes.length > 40;
    _layout = _world
        ? computeWorldLayout(_scenario)
        : computeGraphLayout(_scenario);
    _degrees = degreeMap(_scenario.edges);
    _adjacency = {for (final n in _scenario.nodes) n.id: <String>[]};
    for (final e in _scenario.edges) {
      _adjacency[e.fromId]?.add(e.toId);
      _adjacency[e.toId]?.add(e.fromId);
    }
    _focusId =
        widget.initialFocusId != null &&
            _scenario.nodes.any((n) => n.id == widget.initialFocusId)
        ? widget.initialFocusId!
        : _scenario.seedId;
    _hops = _bfs(_focusId);
    _focusWorld = _layout.positions[_focusId] ?? Offset.zero;
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
    unawaited(_loadImages());
  }

  /// Decode image-entry thumbnails off the main work and repaint when ready.
  Future<void> _loadImages() async {
    final loaded = <String, ui.Image>{};
    for (final node in _scenario.nodes) {
      final path = node.imagePath;
      if (path == null || path.isEmpty) continue;
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        codec.dispose();
        if (!mounted) {
          // Disposed mid-decode — release what we decoded and bail. Only fires
          // when the view is torn down between async frames, which the test
          // harness can't trigger deterministically.
          // coverage:ignore-start
          frame.image.dispose();
          for (final image in loaded.values) {
            image.dispose();
          }
          return;
          // coverage:ignore-end
        }
        loaded[node.id] = frame.image;
      } on Object {
        // Missing/unreadable file — fall back to the type glyph.
      }
    }
    if (mounted && loaded.isNotEmpty) {
      // Reassign a fresh (unmodifiable) map instead of mutating in place, so
      // the painter's identity-based `shouldRepaint` (old.images != images)
      // detects the newly loaded thumbnails and actually repaints.
      setState(() {
        _images = Map<String, ui.Image>.unmodifiable({..._images, ...loaded});
      });
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    _wakeCtl.dispose();
    for (final image in _images.values) {
      image.dispose();
    }
    super.dispose();
  }

  Map<String, int> _bfs(String from) {
    final hops = <String, int>{from: 0};
    final queue = <String>[from];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      for (final nb in _adjacency[cur] ?? const <String>[]) {
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
      for (final nb in _adjacency[cur] ?? const <String>[]) {
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
    final region = _scenario.nodes
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

  void _walkTo(String id, {bool record = true}) {
    if (id == _focusId) return;
    if (record) _history.add(_focusId);
    _previousFocusId = _focusId;
    _walkPath = _path(_focusId, id);
    _focusId = id;
    _hops = _bfs(id);
    _focusWorld = _layout.positions[id] ?? Offset.zero;
    final (ts, tp) = _framedTransform(_lastSize, id);
    _fromScale = _scale;
    _fromPan = _pan;
    _toScale = ts;
    _toPan = tp;
    _cam.forward(from: 0);
    _wakeCtl.forward(from: 0);
    setState(() {});
  }

  void _back() {
    if (_history.isEmpty) return;
    _walkTo(_history.removeLast(), record: false);
  }

  void _recenter() {
    _focusWorld = _layout.positions[_focusId] ?? Offset.zero;
    final (ts, tp) = _framedTransform(_lastSize, _focusId);
    _fromScale = _scale;
    _fromPan = _pan;
    _toScale = ts;
    _toPan = tp;
    _cam.forward(from: 0);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _cam.stop();
    _fromScale = _scale;
    _fromPan = _pan;
    _gestureStartScale = _scale;
    _gestureStartPan = _pan;
    _gestureStartFocal = d.focalPoint;
  }

  double _gestureStartScale = 1;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final newScale = (_gestureStartScale * d.scale).clamp(0.25, 3.0);
    final worldUnderFocal =
        (_gestureStartFocal - _gestureStartPan) / _gestureStartScale;
    setState(() {
      _scale = newScale;
      _pan = d.focalPoint - worldUnderFocal * newScale;
    });
  }

  void _onTapUp(TapUpDetails d) {
    final local = d.localPosition;
    String? hit;
    var best = double.infinity;
    for (final node in _scenario.nodes) {
      final world = _layout.positions[node.id];
      if (world == null) continue;
      final screen = world * _scale + _pan;
      final dist = (local - screen).distance;
      if (dist <= 30 && dist < best) {
        best = dist;
        hit = node.id;
      }
    }
    if (hit != null) _walkTo(hit);
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
    final style = GraphStyle.fromTokens(
      tokens,
      categoryColors: widget.categoryColors,
    );
    // The host page reserves its floating header's height in this view's top
    // padding (status bar + header), so the phone-only title chip clears the
    // header instead of hiding under it. Zero in the standalone POC harness.
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
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onTapUp: _onTapUp,
                    child: CustomPaint(
                      painter: KnowledgeGraphPainter(
                        scenario: _scenario,
                        positions: _layout.positions,
                        degrees: _degrees,
                        scale: _scale,
                        pan: _pan,
                        focusId: _focusId,
                        hops: _hops,
                        selectedId: _focusId,
                        style: style,
                        images: _images,
                        previousFocusId: _previousFocusId,
                        walkPath: _walkPath,
                        wake: _wake,
                        labelMaxHop: _world ? 1 : 2,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
                if (widget.showTitle && !inspectorVisible)
                  Positioned(
                    left: tokens.spacing.step5,
                    top: topInset + tokens.spacing.step5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TitleCard(
                          focus: _scenario.nodeById(_focusId),
                          total: _scenario.nodes.length,
                          explorable: _world,
                          tokens: tokens,
                        ),
                        if (_world) ...[
                          SizedBox(height: tokens.spacing.step3),
                          _Controls(
                            canGoBack: _history.isNotEmpty,
                            onBack: _back,
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
                          _scenario.now.difference(
                            _scenario.nodeById(_focusId).createdAt,
                          ),
                        ),
                        categoryNames: widget.categoryNames,
                        style: style,
                        tokens: tokens,
                        onNeighborTap: _walkTo,
                        canGoBack: _history.isNotEmpty,
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
                      child: EntryDetailSidebar(
                        key: ValueKey(_focusId),
                        entryId: _focusId,
                        onClose: () => setState(() => _detailsOpen = false),
                        tokens: tokens,
                      ),
                    ),
                  ),
                if (widget.showLegend)
                  Positioned(
                    left: tokens.spacing.step5,
                    bottom: tokens.spacing.step5,
                    // Narrow, left-aligned block that wraps to multiple rows so
                    // it stays clear of the right-hand panel instead of spanning
                    // the full width under it.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: _LegendBar(
                        scenario: _scenario,
                        style: style,
                        categoryNames: widget.categoryNames,
                        tokens: tokens,
                      ),
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
            explorable ? 'Tap a node to walk · $total nodes' : '$total nodes',
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
              label: relStyleLabel(rel),
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
              label: categoryNames[cat] ?? cat,
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
            label: 'more links',
            tokens: tokens,
            swatch: _DotsSwatch(dots: [(7, channelColor), (13, channelColor)]),
          ),
          _LegendItem(
            label: 'recent → older',
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
    required this.onBack,
    required this.onRecenter,
    required this.tokens,
  });

  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onRecenter;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.arrow_back,
          enabled: canGoBack,
          onTap: onBack,
          tokens: tokens,
        ),
        SizedBox(width: tokens.spacing.step2),
        _CircleButton(
          icon: Icons.center_focus_strong,
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
    required this.enabled,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Material(
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
