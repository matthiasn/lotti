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
    this.pulseCount = 3,
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

  /// How many "thought" pulses travel the network at once.
  final int pulseCount;
  final int seed;

  @override
  State<NeuralConstellation> createState() => _NeuralConstellationState();
}

class _NeuralConstellationState extends State<NeuralConstellation>
    with SingleTickerProviderStateMixin {
  // One slow loop; node drift and the pulse cadence are derived from its phase.
  static const _loop = Duration(seconds: 24);

  late final AnimationController _controller;
  late List<_Node> _nodes;

  @override
  void initState() {
    super.initState();
    _nodes = _buildNodes(widget.nodeCount, widget.seed);
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didUpdateWidget(NeuralConstellation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Regenerate the seeded node field if the topology inputs change, so a
    // reused element doesn't keep painting the old configuration (matters most
    // under reduced motion, where `t` is static and won't trigger a repaint).
    if (oldWidget.nodeCount != widget.nodeCount ||
        oldWidget.seed != widget.seed) {
      _nodes = _buildNodes(widget.nodeCount, widget.seed);
    }
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
              pulseCount: widget.pulseCount,
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
    required this.pulseCount,
  });

  final List<_Node> nodes;
  final double t;
  final Color nodeColor;
  final Color lineColor;
  final Color pulseColor;
  final int pulseCount;

  // Connect nodes closer than this fraction of the canvas diagonal.
  static const _linkThreshold = 0.26;

  // Seconds one pulse takes to travel its edge; edges are visited in order.
  static const _pulsePeriod = 3.4;

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

    // Travelling "thought" pulses — several ride different edges, each easing
    // in and out (sine envelope) so they swell and fade smoothly rather than
    // popping on/off at the cycle boundary.
    if (edges.isNotEmpty) {
      for (var k = 0; k < pulseCount; k++) {
        final localT = t + k * (_pulsePeriod / pulseCount);
        final edgeIndex =
            ((localT / _pulsePeriod).floor() + k * 5) % edges.length;
        final progress = (localT % _pulsePeriod) / _pulsePeriod;
        final env = math.sin(progress * math.pi); // 0 → 1 → 0
        if (env <= 0.02) continue;
        final edge = edges[edgeIndex];
        final p = Offset.lerp(
          positions[edge[0]],
          positions[edge[1]],
          Curves.easeInOut.transform(progress),
        )!;
        canvas
          ..drawCircle(
            p,
            8 * env,
            Paint()
              ..color = pulseColor.withValues(alpha: 0.42 * env)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          )
          ..drawCircle(
            p,
            2.6 * env,
            Paint()..color = pulseColor.withValues(alpha: env),
          );
      }
    }

    // Nodes: a gentle, continuous breathing glow (no abrupt flares) so the
    // network reads as alive but calm.
    for (var i = 0; i < positions.length; i++) {
      // Slow, low-amplitude breath so a few nodes gently shimmer — a little
      // life, not a hectic twinkle.
      final tw = 0.5 + 0.5 * math.sin(t * 0.4 + nodes[i].phase);
      canvas
        ..drawCircle(
          positions[i],
          nodes[i].radius * (3.6 + 0.5 * tw),
          Paint()
            ..color = nodeColor.withValues(alpha: 0.2 + 0.08 * tw)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawCircle(
          positions[i],
          nodes[i].radius,
          Paint()..color = nodeColor.withValues(alpha: 0.95),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.pulseCount != pulseCount ||
      oldDelegate.nodes.length != nodes.length ||
      oldDelegate.nodeColor != nodeColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pulseColor != pulseColor;
}
