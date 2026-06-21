import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An ambient, looping "external brain" backdrop: glowing nodes drift on gentle
/// elliptical paths, faint synapse lines connect near neighbours, and every few
/// seconds a bright "thought" pulse races along one edge and lights its
/// destination node.
///
/// Pure [CustomPainter] (no fragment shader) so it renders identically on every
/// platform and in offline goldens. The node layout is seeded and deterministic
/// — only the phase advances with time — so a captured frame is stable.
///
/// Under reduced motion the animation controller never runs and a single static
/// frame is painted.
class NeuralConstellation extends StatefulWidget {
  const NeuralConstellation({
    required this.nodeColor,
    required this.lineColor,
    required this.pulseColor,
    this.nodeCount = 24,
    this.seed = 7,
    super.key,
  });

  /// Core/glow colour of the drifting nodes.
  final Color nodeColor;

  /// Colour of the synapse lines (typically a low-alpha [nodeColor]).
  final Color lineColor;

  /// Colour of the travelling thought pulse (typically a brighter accent).
  final Color pulseColor;

  final int nodeCount;
  final int seed;

  @override
  State<NeuralConstellation> createState() => _NeuralConstellationState();
}

class _NeuralConstellationState extends State<NeuralConstellation>
    with SingleTickerProviderStateMixin {
  // One slow loop; node drift and the pulse cadence are derived from its phase.
  static const _loop = Duration(seconds: 24);

  late final AnimationController _controller;
  late final List<_Node> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes(widget.nodeCount, widget.seed);
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<_Node> _buildNodes(int count, int seed) {
    final rng = math.Random(seed);
    return List<_Node>.generate(count, (_) {
      return _Node(
        base: Offset(rng.nextDouble(), rng.nextDouble()),
        // Gentle elliptical drift, a few percent of the canvas.
        driftX: 0.015 + rng.nextDouble() * 0.04,
        driftY: 0.015 + rng.nextDouble() * 0.04,
        phase: rng.nextDouble() * math.pi * 2,
        speed: 0.4 + rng.nextDouble() * 0.6,
        radius: 1.4 + rng.nextDouble() * 2.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConstellationPainter(
              nodes: _nodes,
              t: _controller.value * _loop.inSeconds,
              nodeColor: widget.nodeColor,
              lineColor: widget.lineColor,
              pulseColor: widget.pulseColor,
            ),
          );
        },
      ),
    );
  }
}

class _Node {
  const _Node({
    required this.base,
    required this.driftX,
    required this.driftY,
    required this.phase,
    required this.speed,
    required this.radius,
  });

  final Offset base; // normalized 0..1
  final double driftX;
  final double driftY;
  final double phase;
  final double speed;
  final double radius;

  Offset positionAt(double t, Size size) {
    final dx = base.dx + math.cos(t * speed + phase) * driftX;
    final dy = base.dy + math.sin(t * speed + phase) * driftY;
    return Offset(dx * size.width, dy * size.height);
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter({
    required this.nodes,
    required this.t,
    required this.nodeColor,
    required this.lineColor,
    required this.pulseColor,
  });

  final List<_Node> nodes;
  final double t;
  final Color nodeColor;
  final Color lineColor;
  final Color pulseColor;

  // Connect nodes closer than this fraction of the canvas diagonal.
  static const _linkThreshold = 0.26;

  // Seconds one pulse takes to travel its edge; edges are visited in order.
  static const _pulsePeriod = 2.6;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [for (final n in nodes) n.positionAt(t, size)];
    final diag = size.shortestSide;
    final maxDist = diag * _linkThreshold;

    // Synapse lines, alpha fading with distance. Collect edges in a stable
    // order so the pulse can index into them deterministically.
    final edges = <List<int>>[];
    final linePaint = Paint()..strokeWidth = 1;
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        final dist = (positions[i] - positions[j]).distance;
        if (dist >= maxDist) continue;
        edges.add([i, j]);
        final proximity = 1 - dist / maxDist;
        canvas.drawLine(
          positions[i],
          positions[j],
          linePaint
            ..color = lineColor.withValues(alpha: lineColor.a * proximity),
        );
      }
    }

    // The travelling "thought" pulse rides one edge at a time.
    var pulsedTarget = -1;
    if (edges.isNotEmpty) {
      final edgeIndex = (t / _pulsePeriod).floor() % edges.length;
      final progress = (t % _pulsePeriod) / _pulsePeriod;
      final edge = edges[edgeIndex];
      final a = positions[edge[0]];
      final b = positions[edge[1]];
      final p = Offset.lerp(a, b, Curves.easeInOut.transform(progress))!;
      pulsedTarget = progress > 0.85 ? edge[1] : -1;

      canvas
        ..drawCircle(
          p,
          7,
          Paint()
            ..color = pulseColor.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        )
        ..drawCircle(p, 2.4, Paint()..color = pulseColor);
    }

    // Nodes: soft glow + crisp core. The pulse's destination flares briefly.
    for (var i = 0; i < positions.length; i++) {
      final flare = i == pulsedTarget;
      final core = flare ? pulseColor : nodeColor;
      canvas
        ..drawCircle(
          positions[i],
          nodes[i].radius * (flare ? 5 : 3.5),
          Paint()
            ..color = core.withValues(alpha: flare ? 0.5 : 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawCircle(
          positions[i],
          nodes[i].radius,
          Paint()..color = core.withValues(alpha: 0.95),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.nodeColor != nodeColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pulseColor != pulseColor;
}
