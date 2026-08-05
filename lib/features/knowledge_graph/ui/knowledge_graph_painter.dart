/// CustomPainter for the knowledge-graph explorer (ADR 0029 Decision 6).
///
/// Draws in screen space: world positions map through `world * scale + pan`,
/// while node radii / glyphs / labels stay at roughly constant pixel size so
/// zoom changes spacing, not legibility. The current `focusId` (the node the
/// user is "standing on") plus a BFS `hops` map drive an emphasis falloff: the
/// focus and its immediate neighborhood render bright and large; nodes farther
/// out in graph distance fade and shrink into faint horizon "stars", so a big
/// world reads as a local neighborhood you can walk through.
///
/// Encodes (reviewed by the expert panel to a 9/10 consensus on the ego view):
/// category → node hue; type → glyph; degree → size; recency → luminance within
/// the node's own hue; relation class → edge styling (containment = thick
/// near-white backbone; linked-task = dashed + arrow; note/log; checklist;
/// provenance = cyan dash; evaluation = pink dot-dash) with a gradient brighter
/// toward the focus and a depth falloff with graph distance. Atmosphere: radial
/// vignette + star-field, lit-sphere nodes with a glow, focus on a contact seat.
/// Labels go through a greedy collision pass (overlaps dropped; focus kept).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsProperties;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_label_layout.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_motion_controller.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';

class KnowledgeGraphPainter extends CustomPainter {
  KnowledgeGraphPainter({
    required this.scenario,
    required this.positions,
    required this.degrees,
    required this.scale,
    required this.pan,
    required this.focusId,
    required this.hops,
    required this.selectedId,
    required this.style,
    this.visualSpec,
    this.images = const {},
    this.nodeLabels = const {},
    this.reservedLabelRects = const [],
    this.labelMemory,
    this.textScaler = TextScaler.noScaling,
    this.textDirection = TextDirection.ltr,
    this.onNodeActivate,
    this.previousFocusId,
    this.walkPath = const [],
    this.wake = 0,
    this.labelMaxHop = 2,
    this.motion,
  }) : super(repaint: motion);

  /// Preloaded thumbnails for image nodes (node id → decoded image).
  final Map<String, ui.Image> images;

  final GraphScenario scenario;
  final Map<String, Offset> positions;
  final Map<String, int> degrees;
  final double scale;
  final Offset pan;

  /// The node the user is currently standing on (ego center).
  final String focusId;

  /// BFS graph distance from [focusId]; absent ⇒ unreachable/far.
  final Map<String, int> hops;
  final String? selectedId;
  final GraphStyle style;
  final GraphVisualSpec? visualSpec;
  final Map<String, String> nodeLabels;
  final List<Rect> reservedLabelRects;
  final GraphLabelLayoutMemory? labelMemory;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final ValueChanged<String>? onNodeActivate;

  /// The node walked from (rendered as a faint "you were here" ghost).
  final String? previousFocusId;

  /// Shortest path of node ids from [previousFocusId] to [focusId] — drawn as a
  /// persistent faint trail, brightened during the walk by [wake].
  final List<String> walkPath;

  /// 1 → 0 over the walk: brightens the trail to read the traversal as travel.
  final double wake;
  final int labelMaxHop;
  final GraphMotionController? motion;

  static const double _maxAgeDays = 180;

  Offset _world(String id) {
    final rest = positions[id]!;
    return motion?.displayPosition(id, rest) ?? rest;
  }

  Offset _screen(String id) => _world(id) * scale + pan;

  double _fade(GraphNode node) =>
      (scenario.ageDays(node) / _maxAgeDays).clamp(0.0, 1.0);

  double _degBoost(String id) => math.min(degrees[id] ?? 0, 10) / 10.0;

  /// Emphasis from graph distance: bright/near for the focus neighborhood,
  /// fading into faint horizon stars farther out.
  double emphasis(String id) {
    final h = hops[id];
    if (h == null) return 0.12;
    if (h <= 1) return 1;
    if (h == 2) return 0.82;
    if (h == 3) return 0.52;
    if (h == 4) return 0.3;
    return 0.16;
  }

  double radiusFor(GraphNode node) {
    final base = switch (node.type) {
      GraphNodeType.project => 22.0,
      GraphNodeType.task => 18.0,
      GraphNodeType.checklist => 18.0,
      GraphNodeType.aiResponse => 16.0,
      GraphNodeType.rating => 15.0,
      GraphNodeType.textEntry ||
      GraphNodeType.audioEntry ||
      GraphNodeType.imageEntry => 14.0,
      GraphNodeType.checklistItem => 11.0,
      GraphNodeType.mediaCollection => 19.0,
      GraphNodeType.aggregate => 17.0,
    };
    final degBump = math.min(degrees[node.id] ?? 0, 10) * 0.95;
    final focusBump = node.id == focusId ? 12.0 : 0.0;
    final shrink = 1 - _fade(node) * 0.12;
    final zoom = scale.clamp(0.55, 1.15);
    final emph = 0.5 + 0.5 * emphasis(node.id);
    return (base + degBump + focusBump) * shrink * zoom * emph;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintBiomes(canvas);

    final nodeById = {for (final n in scenario.nodes) n.id: n};
    final focusCenter = _screen(focusId);

    // ---- Edges ----
    for (final e in scenario.edges) {
      final fromNode = nodeById[e.fromId];
      final toNode = nodeById[e.toId];
      if (fromNode == null || toNode == null) continue;
      // A tie recedes with its more-distant (lower-emphasis) endpoint.
      final edgeEmph = math.min(emphasis(e.fromId), emphasis(e.toId));
      if (edgeEmph < 0.14) continue; // far horizon: drop the line entirely
      _paintEdge(canvas, e, fromNode, toNode, focusCenter, edgeEmph);
    }

    // ---- Walk trail ----
    if (walkPath.length >= 2) _paintWake(canvas);

    // ---- Nodes ----
    for (final node in scenario.nodes) {
      _paintNode(canvas, node, emphasis(node.id));
    }

    // ---- Labels (collision-aware) ----
    _paintLabels(canvas, size);
  }

  /// Soft category-tinted haze behind each cluster so distant regions read as
  /// "biomes" you can aim toward before you arrive.
  void _paintBiomes(Canvas canvas) {
    final byCat = <String, List<Offset>>{};
    for (final n in scenario.nodes) {
      final p = positions[n.id];
      if (p != null) byCat.putIfAbsent(n.categoryId, () => []).add(p);
    }
    byCat.forEach((cat, pts) {
      if (pts.length < 3) return;
      var cx = 0.0;
      var cy = 0.0;
      for (final p in pts) {
        cx += p.dx;
        cy += p.dy;
      }
      final centroid = Offset(cx / pts.length, cy / pts.length);
      var maxd = 1.0;
      for (final p in pts) {
        maxd = math.max(maxd, (p - centroid).distance);
      }
      final center = centroid * scale + pan;
      final radius = (maxd * 0.95 * scale).clamp(60.0, 1800.0);
      final color = style.categoryColor(cat);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.11),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    });
  }

  /// The path the user walked: a persistent faint trail, brightened by [wake].
  void _paintWake(Canvas canvas) {
    final alpha = (0.4 + 0.55 * wake).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 + 2 * wake
      ..strokeCap = StrokeCap.round
      ..color = style.focusRing.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (var i = 0; i < walkPath.length - 1; i++) {
      final a = positions[walkPath[i]] == null ? null : _screen(walkPath[i]);
      final b = positions[walkPath[i + 1]] == null
          ? null
          : _screen(walkPath[i + 1]);
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, paint);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: [style.vignetteLift, style.background, style.backgroundDeep],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Faint deterministic star-field so the void has atmosphere.
    final starRng = math.Random(99);
    for (var i = 0; i < 45; i++) {
      final x = starRng.nextDouble() * size.width;
      final y = starRng.nextDouble() * size.height;
      final rr = 0.5 + starRng.nextDouble() * 1.3;
      final a = 0.05 + starRng.nextDouble() * 0.13;
      canvas.drawCircle(
        Offset(x, y),
        rr,
        Paint()..color = style.starColor.withValues(alpha: a),
      );
    }
  }

  void _paintEdge(
    Canvas canvas,
    GraphEdge e,
    GraphNode fromNode,
    GraphNode toNode,
    Offset focusCenter,
    double edgeEmph,
  ) {
    final relStyle = relStyleFor(e.kind, toNode.type);
    final ev = style.edgeVisual(relStyle);

    final p1 = _screen(e.fromId);
    final p2 = _screen(e.toId);
    final raw = p2 - p1;
    final dist = raw.distance;
    if (dist < 1) return;
    final dir = raw / dist;
    final start = p1 + dir * radiusFor(fromNode);
    final end = p2 - dir * radiusFor(toNode);

    // Gentle curve so the hub fan "breathes" instead of stacking.
    final sign = (e.fromId.hashCode ^ e.toId.hashCode).isEven ? 1.0 : -1.0;
    final perp = Offset(-dir.dy, dir.dx);
    final control = (start + end) / 2 + perp * (dist * 0.08) * sign;
    final pts = _bezier(start, control, end, 18);

    final depthWidth = 0.8 + 0.2 * edgeEmph;
    final startNearer =
        (start - focusCenter).distance <= (end - focusCenter).distance;
    final near = ev.color.withValues(
      alpha: (0.95 * edgeEmph).clamp(0.16, 0.95),
    );
    final far = ev.color.withValues(
      alpha: (0.64 * edgeEmph).clamp(0.28, 0.64),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ev.width * depthWidth
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: startNearer ? [near, far] : [far, near],
      ).createShader(Rect.fromPoints(start, end));

    if (ev.dash != null) {
      _dashPoly(canvas, pts, paint, ev.dash![0], ev.dash![1]);
    } else {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }

    if (ev.directional && edgeEmph >= 0.4) {
      final tangent = pts.last - pts[pts.length - 2];
      final tdir = tangent.distance < 0.001 ? dir : tangent / tangent.distance;
      _arrowhead(canvas, end, tdir, ev.color.withValues(alpha: 0.95), ev.width);
    }
  }

  void _paintNode(Canvas canvas, GraphNode node, double emph) {
    final center = _screen(node.id);
    final r = radiusFor(node);
    final isFocus = node.id == focusId;
    final isSelected = node.id == selectedId;
    final fade = _fade(node);
    final cat = style.categoryColor(node.categoryId);

    // Recency: dim lightness/saturation but PRESERVE hue.
    final hsl = HSLColor.fromColor(cat);
    final lightness = (hsl.lightness * (1 - fade * 0.24)).clamp(0.0, 1.0);
    final saturation = (hsl.saturation * (1 - fade * 0.08)).clamp(0.0, 1.0);
    var fill = hsl
        .withLightness(lightness)
        .withSaturation(saturation)
        .toColor();
    // Emphasis fog: distant nodes recede toward the background.
    fill = Color.lerp(fill, style.background, (1 - emph) * 0.28) ?? fill;
    final rim = Color.lerp(fill, style.background, 0.42) ?? fill;
    final core =
        Color.lerp(fill, style.coreLift, 0.14 + _degBoost(node.id) * 0.14) ??
        fill;

    // Faint dark "seat" so the focus reads as the nearest body on top.
    if (isFocus) {
      canvas.drawCircle(
        center + Offset(0, r * 0.18),
        r * 1.5,
        Paint()
          ..color = style.backgroundDeep.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
      );
    }

    // Soft glow — restrained; dimmer for old and distant nodes.
    final glowAlpha =
        (isFocus ? 0.22 : 0.10 + _degBoost(node.id) * 0.08) *
        (1 - fade * 0.55) *
        emph;
    canvas.drawCircle(
      center,
      r * (isFocus ? 1.55 : 1.4),
      Paint()
        ..color = (isFocus ? style.focusRing : fill).withValues(
          alpha: glowAlpha,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
    );

    // Body: a real thumbnail for image entries and cover-backed task nodes,
    // otherwise a lit sphere. The focused task already receives the standard
    // focus size bump, so cover art adds context without another size scale.
    // Always topped with an opaque delineating ring (hides the edge/node seam).
    final rect = Rect.fromCircle(center: center, radius: r);
    ui.Image? coverThumb;
    if (node.type == GraphNodeType.task) {
      final coverImagePath = node.coverImagePath;
      if (coverImagePath != null) coverThumb = images[coverImagePath];
    }
    var thumb = coverThumb ?? images[node.id];
    if (thumb == null) {
      final imagePath = node.imagePath;
      if (imagePath != null) thumb = images[imagePath];
    }
    final thumbFocalX = coverThumb == null ? 0.5 : node.coverImageCropX;
    final mosaic = node.type == GraphNodeType.mediaCollection
        ? <ui.Image>{
            ...node.mediaPaths.map((path) => images[path]).nonNulls,
            ...node.memberIds.map((id) => images[id]).nonNulls,
          }.take(4).toList()
        : const <ui.Image>[];
    if (mosaic.isNotEmpty) {
      _paintMediaMosaic(canvas, rect, mosaic);
    } else if (thumb != null) {
      canvas
        ..save()
        ..clipPath(Path()..addOval(rect))
        ..drawImageRect(
          thumb,
          _coverSrc(
            thumb.width.toDouble(),
            thumb.height.toDouble(),
            rect,
            focalX: thumbFocalX,
          ),
          rect,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - fade * 0.4),
        )
        ..restore();
    } else {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.95,
            colors: [core, fill, rim],
            stops: const [0, 0.6, 1],
          ).createShader(rect),
      );
    }
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = (r * 0.09).clamp(0.8, 1.6),
    );

    if (isFocus) {
      canvas
        ..drawCircle(
          center,
          r + 3,
          Paint()
            ..color = style.focusRing
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        )
        ..drawCircle(
          center,
          r + 9,
          Paint()
            ..color = style.focusRing.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }
    if (isSelected && !isFocus) {
      canvas.drawCircle(
        center,
        r + 3,
        Paint()
          ..color = style.selectionRing
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
    // "You were here" ghost on the node we walked from.
    if (node.id == previousFocusId && !isFocus) {
      canvas.drawCircle(
        center,
        r + 5,
        Paint()
          ..color = style.focusRing.withValues(alpha: 0.55 + 0.3 * wake)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Far horizon stars are too small to carry a glyph; image nodes show the
    // photo itself instead of a glyph.
    if (thumb == null && mosaic.isEmpty && r >= 8) {
      _drawGlyph(canvas, center, r, node, fade, emph);
    }
  }

  void _paintMediaMosaic(Canvas canvas, Rect rect, List<ui.Image> mosaic) {
    final cells = mosaic.length == 1
        ? [rect]
        : [
            Rect.fromLTWH(rect.left, rect.top, rect.width / 2, rect.height / 2),
            Rect.fromLTWH(
              rect.center.dx,
              rect.top,
              rect.width / 2,
              rect.height / 2,
            ),
            Rect.fromLTWH(
              rect.left,
              rect.center.dy,
              rect.width / 2,
              rect.height / 2,
            ),
            Rect.fromLTWH(
              rect.center.dx,
              rect.center.dy,
              rect.width / 2,
              rect.height / 2,
            ),
          ];
    canvas
      ..save()
      ..clipPath(Path()..addOval(rect));
    for (var index = 0; index < mosaic.length; index++) {
      final image = mosaic[index];
      final cell = cells[index];
      canvas.drawImageRect(
        image,
        _coverSrc(
          image.width.toDouble(),
          image.height.toDouble(),
          cell,
        ),
        cell,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  void _drawGlyph(
    Canvas canvas,
    Offset center,
    double r,
    GraphNode node,
    double fade,
    double emph,
  ) {
    final icon = glyphForType(node.type);
    final size = (r * 1.0).clamp(11.0, 26.0);
    final base = HSLColor.fromColor(style.categoryColor(node.categoryId));
    final glyphColor =
        (base.lightness > 0.6 ? style.background : style.glyphColor).withValues(
          alpha: (1 - fade * 0.18) * emph,
        );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: glyphColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintLabels(Canvas canvas, Size size) {
    final ordered = [...scenario.nodes]
      ..sort((a, b) {
        // Keep the comparator reflexive (compare(x, x) == 0) so the sort obeys
        // strict weak ordering — returning -1 for an equal pair can crash or
        // misorder depending on the platform sort.
        if (a.id == b.id) return 0;
        if (a.id == focusId) return -1;
        if (b.id == focusId) return 1;
        final d = (degrees[b.id] ?? 0).compareTo(degrees[a.id] ?? 0);
        if (d != 0) return d;
        return scenario.ageDays(a).compareTo(scenario.ageDays(b));
      });

    final spec = visualSpec;
    final horizontalPadding = spec?.labelHorizontalPadding ?? 8;
    final verticalPadding = spec?.labelVerticalPadding ?? 5;
    final nodeObstacles = <String, Rect>{
      for (final node in scenario.nodes)
        node.id: Rect.fromCircle(
          center: _screen(node.id),
          radius: radiusFor(node),
        ),
    };
    final painters = <String, TextPainter>{};
    final candidates = <GraphLabelCandidate>[];

    for (final node in ordered) {
      final isFocus = node.id == focusId;
      final isSelected = node.id == selectedId;
      if (!isFocus && (hops[node.id] ?? 99) > labelMaxHop) continue;
      if (scale < 0.55 &&
          !isFocus &&
          !isSelected &&
          !node.isAggregate &&
          (degrees[node.id] ?? 0) < 2) {
        continue;
      }
      final center = _screen(node.id);
      final r = radiusFor(node);
      final fade = _fade(node);
      final textStyle =
          (isFocus
                  ? style.labelStyle.copyWith(fontWeight: FontWeight.w700)
                  : style.labelStyle)
              .copyWith(
                color: Color.lerp(
                  style.labelStyle.color,
                  style.fadeTarget,
                  fade * 0.4,
                ),
              );

      final tp =
          TextPainter(
            text: TextSpan(
              text: nodeLabels[node.id] ?? node.label,
              style: textStyle,
            ),
            textDirection: textDirection,
            textScaler: textScaler,
            maxLines: isFocus || isSelected ? null : 2,
            ellipsis: isFocus || isSelected ? null : '…',
          )..layout(
            maxWidth: isFocus || isSelected
                ? spec?.focusLabelMaxWidth ?? 280
                : spec?.nodeLabelMaxWidth ?? 210,
          );
      painters[node.id] = tp;
      candidates.add(
        GraphLabelCandidate(
          id: node.id,
          center: center,
          nodeRadius: r,
          labelSize: Size(
            tp.width + horizontalPadding * 2,
            tp.height + verticalPadding * 2,
          ),
          priority:
              (isFocus
                  ? 1000
                  : isSelected
                  ? 900
                  : node.isAggregate
                  ? 800
                  : (hops[node.id] ?? 2) == 1
                  ? 500
                  : 100) +
              (degrees[node.id] ?? 0),
          required: isFocus || isSelected,
        ),
      );
    }

    final placements = solveGraphLabelLayout(
      candidates: candidates,
      viewport: Offset.zero & size,
      nodeObstacles: nodeObstacles,
      reservedRects: reservedLabelRects,
      previous: labelMemory?.placements ?? const {},
      gap: spec?.labelGap ?? 6,
    );
    labelMemory?.remember(placements);

    for (final node in ordered) {
      final placement = placements[node.id];
      final tp = painters[node.id];
      if (placement == null || tp == null) continue;
      if (placement.needsLeader) {
        canvas.drawLine(
          placement.nodeCenter,
          placement.rect.center,
          Paint()
            ..color = style.labelStyle.color!.withValues(alpha: 0.42)
            ..strokeWidth = BorderWidths.hairline,
        );
      }
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            placement.rect,
            const Radius.circular(8),
          ),
          Paint()..color = style.labelPill.withValues(alpha: 0.94),
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            placement.rect,
            const Radius.circular(8),
          ),
          Paint()
            ..color = style.starColor.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = BorderWidths.hairline,
        );
      tp.paint(
        canvas,
        Offset(
          placement.rect.left + horizontalPadding,
          placement.rect.top + verticalPadding,
        ),
      );
    }
  }

  /// Crop the source so it covers the circular [dst] (`BoxFit.cover`), using
  /// [focalX] as the horizontal focal point for task cover art.
  Rect _coverSrc(
    double iw,
    double ih,
    Rect dst, {
    double focalX = 0.5,
  }) {
    final scale = math.max(dst.width / iw, dst.height / ih);
    final w = dst.width / scale;
    final h = dst.height / scale;
    final left = (iw - w) * focalX.clamp(0.0, 1.0);
    return Rect.fromLTWH(left, (ih - h) / 2, w, h);
  }

  List<Offset> _bezier(Offset p0, Offset c, Offset p2, int steps) {
    final out = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final u = 1 - t;
      out.add(p0 * (u * u) + c * (2 * u * t) + p2 * (t * t));
    }
    return out;
  }

  void _dashPoly(
    Canvas canvas,
    List<Offset> pts,
    Paint paint,
    double dash,
    double gap,
  ) {
    // Guard against a non-positive dash/gap, which would make the segment
    // walk below never advance and hang the UI thread.
    if (dash <= 0 || gap <= 0) return;
    var remaining = dash;
    var drawing = true;
    for (var i = 0; i < pts.length - 1; i++) {
      var a = pts[i];
      final b = pts[i + 1];
      var segLen = (b - a).distance;
      if (segLen < 0.001) continue;
      final d = (b - a) / segLen;
      while (segLen > 0) {
        final step = math.min(remaining, segLen);
        final next = a + d * step;
        if (drawing) canvas.drawLine(a, next, paint);
        a = next;
        segLen -= step;
        remaining -= step;
        if (remaining <= 0) {
          drawing = !drawing;
          remaining = drawing ? dash : gap;
        }
      }
    }
  }

  void _arrowhead(
    Canvas canvas,
    Offset tip,
    Offset dir,
    Color color,
    double w,
  ) {
    final len = math.max(9, w * 4.5).toDouble();
    const spread = 0.45;
    final angle = math.atan2(dir.dy, dir.dx);
    final p1 =
        tip - Offset(math.cos(angle - spread), math.sin(angle - spread)) * len;
    final p2 =
        tip - Offset(math.cos(angle + spread), math.sin(angle + spread)) * len;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final node in scenario.nodes)
          CustomPainterSemantics(
            rect: Rect.fromCenter(
              center: _screen(node.id),
              width: math.max(radiusFor(node) * 2, TapTargets.minimum),
              height: math.max(radiusFor(node) * 2, TapTargets.minimum),
            ),
            properties: SemanticsProperties(
              label: nodeLabels[node.id] ?? node.label,
              button: true,
              selected: node.id == selectedId,
              textDirection: textDirection,
              onTap: onNodeActivate == null
                  ? null
                  : () => onNodeActivate!(node.id),
            ),
          ),
      ];

  @override
  bool shouldRepaint(KnowledgeGraphPainter old) {
    return old.scenario != scenario ||
        old.positions != positions ||
        old.images != images ||
        old.scale != scale ||
        old.pan != pan ||
        old.focusId != focusId ||
        old.hops != hops ||
        old.selectedId != selectedId ||
        old.style != style ||
        old.visualSpec != visualSpec ||
        old.nodeLabels != nodeLabels ||
        old.reservedLabelRects != reservedLabelRects ||
        old.labelMemory != labelMemory ||
        old.textScaler != textScaler ||
        old.textDirection != textDirection ||
        old.onNodeActivate != onNodeActivate ||
        old.previousFocusId != previousFocusId ||
        old.walkPath != walkPath ||
        old.wake != wake ||
        old.labelMaxHop != labelMaxHop ||
        old.motion != motion;
  }
}
