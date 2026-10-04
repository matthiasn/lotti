import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

part 'neural_constellation_neural_constellation_state_part.dart';

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.nodes,
    required this.t01,
    required this.pulseCycles,
    required this.nodeColor,
    required this.lineColor,
    required this.pulseColor,
    required this.pulseCount,
    required this.glow,
    required this.compositionScale,
    required this.compositionOffset,
    required this.entanglement,
  });

  final List<NeuralNode> nodes;

  /// Normalized loop phase in 0..1.
  final double t01;

  /// Integer pulse travels per loop (base; pulse k runs `pulseCycles + k`).
  final int pulseCycles;
  final Color nodeColor;
  final Color lineColor;
  final Color pulseColor;
  final int pulseCount;
  final double glow;
  final double compositionScale;
  final Offset compositionOffset;
  final double entanglement;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [
      for (final n in nodes)
        _breathePoint(
          _offsetPoint(
            _scaleAroundCenter(n.positionAt(t01, size), size, compositionScale),
            size,
            compositionOffset,
          ),
          size,
        ),
    ];
    final branches = <_NeuralBranch>[];
    for (var i = 0; i < nodes.length; i++) {
      final parentIndex = nodes[i].parentIndex;
      if (parentIndex != null && parentIndex < nodes.length) {
        branches.add(_NeuralBranch(parentIndex, i));
      }
    }

    if (entanglement > 0) {
      _drawTissueBloom(canvas, positions, size);
      _drawEntanglement(canvas, positions, size);
    }

    for (var i = 0; i < branches.length; i++) {
      final branch = branches[i];
      final from = positions[branch.from];
      final to = positions[branch.to];
      final control = _controlPoint(
        from: from,
        to: to,
        phase: nodes[branch.to].phase,
        size: size,
      );
      final breath = nodes[branch.to].breathAt(t01);
      final generation = nodes[branch.to].generation;
      final branchWeight = math.max(0.36, 1 - generation * 0.13);
      final compositionWeight = _compositionWeight(
        _quadraticPoint(from, control, to, 0.58),
        size,
      );
      final entangledBranch = entanglement > 0;
      final trunkBoost = entangledBranch && generation <= 3 ? 1.34 : 1.0;
      final layerAlpha = entangledBranch
          ? 0.72 + ((branch.to + nodes[branch.to].vineId * 3) % 4) * 0.08
          : 1.0;
      _drawTendrilGlow(
        canvas,
        from: from,
        control: control,
        to: to,
        color: lineColor.withValues(
          alpha:
              lineColor.a *
              branchWeight *
              layerAlpha *
              (0.12 + 0.06 * breath) *
              compositionWeight,
        ),
        width:
            (5.8 + nodes[branch.from].radius * 0.52 * branchWeight) *
            trunkBoost,
      );
      if (entangledBranch && generation <= 6) {
        _drawTendrilBundle(
          canvas,
          from: from,
          control: control,
          to: to,
          color: lineColor.withValues(
            alpha:
                lineColor.a *
                branchWeight *
                layerAlpha *
                0.22 *
                compositionWeight,
          ),
          width: (0.58 + branchWeight * 0.34) * trunkBoost,
          size: size,
          phase: nodes[branch.to].phase,
        );
      }
      final branchColor = lineColor.withValues(
        alpha:
            lineColor.a *
            branchWeight *
            layerAlpha *
            (0.42 + 0.22 * breath) *
            compositionWeight,
      );
      final branchWidth =
          (1.12 + nodes[branch.from].radius * 0.25 * branchWeight) * trunkBoost;
      if (entangledBranch) {
        _drawTendrilPath(
          canvas,
          from: from,
          control: control,
          to: to,
          color: branchColor,
          width: branchWidth,
        );
      } else {
        _drawTendril(
          canvas,
          from: from,
          control: control,
          to: to,
          color: branchColor,
          width: branchWidth,
        );
      }

      if (generation > 1 && branch.to.isOdd) {
        _drawHairline(
          canvas,
          origin: _quadraticPoint(from, control, to, 0.68),
          angle:
              nodes[branch.to].growthAngle +
              (branch.to.isEven ? math.pi / 2.8 : -math.pi / 2.8),
          phase: nodes[branch.to].phase,
          size: size,
          color: lineColor.withValues(
            alpha: lineColor.a * 0.18 * branchWeight * compositionWeight,
          ),
        );
      }
    }

    for (var k = 0; k < pulseCount; k++) {
      for (var i = 0; i < branches.length; i++) {
        final entangledPulse = entanglement > 0;
        if ((i + k * 3) % (entangledPulse ? 3 : 4) != 0) continue;

        final progress = neuralBranchProgressAt(
          t01 + k / pulseCount,
          pulseCycles + k,
          i,
          branches.length,
        );
        final env = neuralPulseEnvAt(progress, 1, 0);

        final branch = branches[i];
        final from = positions[branch.from];
        final to = positions[branch.to];
        final control = _controlPoint(
          from: from,
          to: to,
          phase: nodes[branch.to].phase,
          size: size,
        );
        final eased = Curves.easeInOut.transform(progress);
        final head = _quadraticPoint(from, control, to, eased);
        final headWeight = _compositionWeight(head, size);
        final rightRelay =
            entangledPulse &&
            head.dx > size.width * 0.52 &&
            head.dx < size.width * 0.86 &&
            headWeight > 0.54 &&
            (branch.to + k).isEven;
        final mainRelay =
            entangledPulse &&
            nodes[branch.to].generation <= 6 &&
            headWeight > 0.58 &&
            (nodes[branch.to].generation <= 4 ||
                (branch.to + nodes[branch.to].vineId).isEven ||
                rightRelay);
        final tailLength = entangledPulse ? 0.28 : 0.20;
        final pulseBoost = entangledPulse ? (mainRelay ? 1.42 : 1.08) : 1.0;
        final tail = eased <= tailLength ? 0.0 : eased - tailLength;
        final tailFrom = _quadraticPoint(from, control, to, tail);
        final tailControl = _quadraticPoint(
          from,
          control,
          to,
          (tail + eased) / 2,
        );
        final pulseTailColor = pulseColor.withValues(
          alpha: (mainRelay ? 0.23 : 0.14) * env * pulseBoost * headWeight,
        );
        final pulseTailWidth =
            ((mainRelay ? 1.82 : 1.45) + env * 0.58) * pulseBoost;
        if (entangledPulse) {
          _drawTendrilPath(
            canvas,
            from: tailFrom,
            control: tailControl,
            to: head,
            color: pulseTailColor,
            width: pulseTailWidth,
          );
        } else {
          _drawTendril(
            canvas,
            from: tailFrom,
            control: tailControl,
            to: head,
            color: pulseTailColor,
            width: pulseTailWidth,
            segments: 6,
          );
        }
        canvas
          ..drawCircle(
            head,
            (mainRelay ? 6.4 : 4.8) * env * pulseBoost,
            Paint()
              ..color = pulseColor.withValues(
                alpha:
                    (mainRelay ? 0.18 : 0.12) * env * pulseBoost * headWeight,
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          )
          ..drawCircle(
            head,
            (mainRelay ? 1.65 : 1.18) + env * 0.58,
            Paint()
              ..color = pulseColor.withValues(
                alpha:
                    (mainRelay ? 0.68 : 0.42) * env * pulseBoost * headWeight,
              ),
          );
      }
    }

    // Nodes: a gentle, continuous breathing glow (no abrupt flares) so the
    // organism reads as alive but calm.
    for (var i = 0; i < positions.length; i++) {
      final tw = nodes[i].breathAt(t01);
      final isRoot = nodes[i].parentIndex == null;
      final generation = nodes[i].generation;
      final hierarchy = math.max(0.36, 1 - generation * 0.12);
      final entangledNode = entanglement > 0;
      final compositionWeight = _compositionWeight(positions[i], size);
      final coreAlpha = (isRoot ? 0.9 : 0.74) * hierarchy;
      final nodeRadius = nodes[i].radius;
      final activeCore = entangledNode && (isRoot || generation <= 1);
      final drawCore = entangledNode
          ? isRoot ||
                generation <= 1 ||
                nodeRadius > 2.25 ||
                (i + nodes[i].vineId) % 6 == 0
          : isRoot || generation <= 1 || nodeRadius > 1.85 || i.isOdd;
      if (!drawCore) {
        canvas.drawCircle(
          positions[i],
          nodeRadius * (entangledNode ? 0.32 : 0.56),
          Paint()
            ..color = nodeColor.withValues(
              alpha:
                  (entangledNode ? 0.10 : 0.24) * hierarchy * compositionWeight,
            ),
        );
        continue;
      }
      canvas
        ..drawCircle(
          positions[i],
          nodeRadius *
              (entangledNode ? (activeCore ? 4.72 : 4.05) : 3.9 + 0.8 * tw) *
              glow,
          Paint()
            ..color = nodeColor.withValues(
              alpha:
                  (entangledNode
                      ? (activeCore ? 0.145 : 0.10) + 0.05 * tw
                      : 0.13 + 0.07 * tw) *
                  hierarchy *
                  glow *
                  compositionWeight,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawCircle(
          positions[i],
          nodeRadius *
              (activeCore
                  ? 1.22
                  : isRoot
                  ? 1.16
                  : 1),
          Paint()
            ..color = nodeColor.withValues(
              alpha:
                  (entangledNode
                      ? coreAlpha * (activeCore ? 0.96 : 0.82)
                      : coreAlpha) *
                  compositionWeight,
            ),
        );
    }
  }

  Offset _controlPoint({
    required Offset from,
    required Offset to,
    required double phase,
    required Size size,
  }) {
    final delta = to - from;
    final dist = delta.distance;
    if (dist == 0) return from;

    final normal = Offset(-delta.dy / dist, delta.dx / dist);
    final bend = size.shortestSide * (0.035 + 0.025 * math.sin(phase).abs());
    final direction = math.sin(phase) >= 0 ? 1.0 : -1.0;
    return Offset.lerp(from, to, 0.52)! + normal * bend * direction;
  }

  void _drawTendril(
    Canvas canvas, {
    required Offset from,
    required Offset control,
    required Offset to,
    required Color color,
    required double width,
    int segments = 14,
  }) {
    var previous = from;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 1; i <= segments; i++) {
      final t = i / segments;
      final point = _quadraticPoint(from, control, to, t);
      final taper = 1 - t * 0.46;
      canvas.drawLine(
        previous,
        point,
        paint
          ..strokeWidth = width * taper
          ..color = color.withValues(alpha: color.a * taper),
      );
      previous = point;
    }
  }

  void _drawTendrilGlow(
    Canvas canvas, {
    required Offset from,
    required Offset control,
    required Offset to,
    required Color color,
    required double width,
  }) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  void _drawTendrilPath(
    Canvas canvas, {
    required Offset from,
    required Offset control,
    required Offset to,
    required Color color,
    required double width,
  }) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  void _drawTendrilBundle(
    Canvas canvas, {
    required Offset from,
    required Offset control,
    required Offset to,
    required Color color,
    required double width,
    required Size size,
    required double phase,
  }) {
    final delta = to - from;
    final dist = delta.distance;
    if (dist == 0) return;

    final normal = Offset(-delta.dy / dist, delta.dx / dist);
    final offsetBase = size.shortestSide * (0.0038 + 0.0018 * entanglement);
    for (final side in const [-1.0, 1.0]) {
      final offset =
          normal * offsetBase * side * (0.72 + 0.28 * math.sin(phase).abs());
      _drawTendrilPath(
        canvas,
        from: from + offset,
        control: control + offset * 1.45,
        to: to + offset * 0.82,
        color: color,
        width: width,
      );
    }
  }

  void _drawHairline(
    Canvas canvas, {
    required Offset origin,
    required double angle,
    required double phase,
    required Size size,
    required Color color,
  }) {
    final length = size.shortestSide * (0.055 + 0.025 * math.sin(phase).abs());
    final tip = origin + Offset(math.cos(angle), math.sin(angle)) * length;
    final control =
        Offset.lerp(origin, tip, 0.55)! +
        Offset(math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)) *
            length *
            0.20 *
            math.sin(phase);

    _drawTendril(
      canvas,
      from: origin,
      control: control,
      to: tip,
      color: color,
      width: 0.72,
      segments: 7,
    );
  }

  void _drawEntanglement(Canvas canvas, List<Offset> positions, Size size) {
    final maxDistance = size.shortestSide * (0.13 + 0.04 * entanglement);
    final maxLinks = math.min(
      nodes.length,
      (nodes.length * (0.36 + entanglement * 0.34)).round(),
    );
    var drawn = 0;

    for (var i = 0; i < positions.length && drawn < maxLinks; i++) {
      for (var j = i + 1; j < positions.length && drawn < maxLinks; j++) {
        if (nodes[i].vineId == nodes[j].vineId) continue;
        if (_areDirectlyConnected(i, j)) continue;
        if ((i * 29 + j * 43 + nodes.length) % 7 > 2) continue;

        final distance = (positions[i] - positions[j]).distance;
        if (distance <= 0 || distance > maxDistance) continue;

        final proximity = 1 - distance / maxDistance;
        final control = _controlPoint(
          from: positions[i],
          to: positions[j],
          phase: nodes[i].phase + nodes[j].phase,
          size: size,
        );
        _drawTendrilPath(
          canvas,
          from: positions[i],
          control: control,
          to: positions[j],
          color: lineColor.withValues(
            alpha:
                lineColor.a *
                entanglement *
                0.16 *
                proximity *
                _compositionWeight(
                  Offset.lerp(positions[i], positions[j], 0.5)!,
                  size,
                ),
          ),
          width: 0.62 + proximity * 0.38,
        );
        drawn++;
      }
    }
  }

  bool _areDirectlyConnected(int a, int b) {
    return nodes[a].parentIndex == b || nodes[b].parentIndex == a;
  }

  void _drawTissueBloom(Canvas canvas, List<Offset> positions, Size size) {
    var weightedCenter = Offset.zero;
    var totalWeight = 0.0;
    for (var i = 0; i < positions.length; i++) {
      final node = nodes[i];
      if (node.generation > 5 || positions[i].dx > size.width * 0.78) {
        continue;
      }
      final weight = math.max(0.2, 1.5 - node.generation * 0.18);
      weightedCenter += positions[i] * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) return;

    final center = weightedCenter / totalWeight;
    final paint = Paint()
      ..color = nodeColor.withValues(alpha: 0.055 * entanglement)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: center + Offset(size.width * 0.02, size.height * 0.01),
          width: size.shortestSide * 0.42,
          height: size.shortestSide * 0.24,
        ),
        paint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: center + Offset(size.width * 0.16, -size.height * 0.03),
          width: size.shortestSide * 0.32,
          height: size.shortestSide * 0.18,
        ),
        paint..color = nodeColor.withValues(alpha: 0.032 * entanglement),
      );
  }

  Offset _quadraticPoint(Offset from, Offset control, Offset to, double t) {
    final p0 = Offset.lerp(from, control, t)!;
    final p1 = Offset.lerp(control, to, t)!;
    return Offset.lerp(p0, p1, t)!;
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) =>
      oldDelegate.t01 != t01 ||
      oldDelegate.pulseCycles != pulseCycles ||
      oldDelegate.pulseCount != pulseCount ||
      // Identity, not just length: a seed change regenerates the node list
      // (often the same count), which must repaint even when t01 is frozen
      // under reduced motion.
      !identical(oldDelegate.nodes, nodes) ||
      oldDelegate.nodeColor != nodeColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pulseColor != pulseColor ||
      oldDelegate.compositionScale != compositionScale ||
      oldDelegate.compositionOffset != compositionOffset ||
      oldDelegate.entanglement != entanglement ||
      oldDelegate.glow != glow;

  Offset _scaleAroundCenter(Offset point, Size size, double scale) {
    if (scale == 1) return point;
    final center = Offset(size.width / 2, size.height / 2);
    return center + (point - center) * scale;
  }

  Offset _offsetPoint(Offset point, Size size, Offset offset) {
    if (offset == Offset.zero) return point;
    return point + Offset(size.width * offset.dx, size.height * offset.dy);
  }

  Offset _breathePoint(Offset point, Size size) {
    if (entanglement <= 0) return point;
    final phase = math.sin(2 * math.pi * t01);
    final center = Offset(size.width * 0.48, size.height * 0.48);
    final scale = 1 + phase * 0.018;
    return center + (point - center) * scale;
  }

  double _compositionWeight(Offset point, Size size) {
    if (entanglement <= 0) return 1;
    if (size.width <= 0 || size.height <= 0) return 0;
    final nx = point.dx / size.width;
    final ny = point.dy / size.height;
    final lowerFade = 1 - ((ny - 0.68) / 0.24).clamp(0.0, 1.0) * 0.42;
    final rightFade = 1 - ((nx - 0.76) / 0.18).clamp(0.0, 1.0) * 0.34;
    final topEdgeFade = 1 - ((0.08 - ny) / 0.08).clamp(0.0, 1.0) * 0.32;
    return lowerFade * rightFade * topEdgeFade;
  }
}
