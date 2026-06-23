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
/// **Seamless loop.** Every time-driven oscillation (node drift, node breath,
/// the travelling pulses) is a function of the controller's normalized value
/// `t01` in `0..1` using an *integer* number of cycles per loop. Because an
/// integer number of cycles returns to its exact starting value at `t01 == 1`,
/// the frame at the end of the loop is identical to the frame at the start, so
/// the `repeat()` wrap is invisible — no snap. (Previously the painter advanced
/// `t` in seconds and used arbitrary per-node frequencies, none of which were
/// harmonics of the loop, so the whole field jumped at the seam.)
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
    this.glow = 1,
    this.loop = const Duration(seconds: 24),
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

  /// Scales the node *bloom* (the soft halo radius + alpha), not the crisp
  /// core dot. < 1 tames the brightest blooms so they don't out-shout
  /// foreground text — the welcome hero passes a value below 1 per the design
  /// panel; the dim working-step backdrop keeps the default.
  final double glow;

  /// Period of the drift/pulse loop. Shorter = livelier drift (the per-node
  /// cycle counts are fixed integers, so a shorter loop simply runs them
  /// faster). The welcome hero keeps the slow default; the working-step
  /// backdrop runs a bit faster so its motion is perceptible.
  final Duration loop;

  @override
  State<NeuralConstellation> createState() => _NeuralConstellationState();
}

/// Seconds one pulse nominally takes to travel its edge. Used only to derive an
/// integer number of pulse cycles per loop (so the pulses stay seamless).
const double _kPulsePeriodSeconds = 3.4;

/// Integer number of pulse travels per loop for [loop] — at least one. Keeping
/// it an integer is what makes the pulse phase land back on zero at the loop
/// wrap (so it fades fully out and back in, never teleporting).
int neuralPulseCyclesForLoop(Duration loop) =>
    math.max(1, (loop.inMilliseconds / 1000 / _kPulsePeriodSeconds).round());

class _NeuralConstellationState extends State<NeuralConstellation>
    with SingleTickerProviderStateMixin {
  Duration get _loop => widget.loop;

  late final AnimationController _controller;
  late List<NeuralNode> _nodes;

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
    // under reduced motion, where `t01` is static and won't trigger a repaint).
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

  static List<NeuralNode> _buildNodes(int count, int seed) {
    final rng = math.Random(seed);
    return List<NeuralNode>.generate(count, (_) {
      return NeuralNode(
        base: Offset(rng.nextDouble(), rng.nextDouble()),
        // Gentle elliptical drift, a few percent of the canvas.
        driftX: 0.015 + rng.nextDouble() * 0.04,
        driftY: 0.015 + rng.nextDouble() * 0.04,
        phase: rng.nextDouble() * math.pi * 2,
        // Integer cycles per loop keep each node seamless at the wrap while a
        // small spread (1..3 drift, 1..2 breath) preserves organic variety.
        driftCycles: 1 + rng.nextInt(3),
        breathCycles: 1 + rng.nextInt(2),
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
              t01: _controller.value,
              pulseCycles: neuralPulseCyclesForLoop(_loop),
              nodeColor: widget.nodeColor,
              lineColor: widget.lineColor,
              pulseColor: widget.pulseColor,
              pulseCount: widget.pulseCount,
              glow: widget.glow,
            ),
          );
        },
      ),
    );
  }
}

/// A single drifting node. Public for seam-continuity tests.
@visibleForTesting
class NeuralNode {
  const NeuralNode({
    required this.base,
    required this.driftX,
    required this.driftY,
    required this.phase,
    required this.driftCycles,
    required this.breathCycles,
    required this.radius,
  });

  final Offset base; // normalized 0..1
  final double driftX;
  final double driftY;
  final double phase;

  /// Whole drift ellipses completed per loop.
  final int driftCycles;

  /// Whole breath cycles per loop.
  final int breathCycles;
  final double radius;

  /// Position at normalized loop phase [t01] (0..1). Because [driftCycles] is an
  /// integer, the angle at `t01 == 1` equals the angle at `t01 == 0`, so the
  /// position is identical at the loop wrap (seamless).
  Offset positionAt(double t01, Size size) {
    final theta = 2 * math.pi * driftCycles * t01 + phase;
    final dx = base.dx + math.cos(theta) * driftX;
    final dy = base.dy + math.sin(theta) * driftY;
    return Offset(dx * size.width, dy * size.height);
  }

  /// Breath term in 0..1 at loop phase [t01]; seamless for the same reason.
  double breathAt(double t01) =>
      0.5 + 0.5 * math.sin(2 * math.pi * breathCycles * t01 + phase);
}

/// The travelling-pulse envelope (0 → 1 → 0) for pulse [index] at loop phase
/// [t01], given [pulseCycles] base travels per loop. Public for seam tests.
///
/// Each pulse runs an *integer* number of travels per loop (`pulseCycles +
/// index`), so its progress is exactly 0 at both `t01 == 0` and `t01 == 1` —
/// the envelope is 0 there, meaning every pulse has fully faded out at the seam
/// and the loop wrap shows no pulse jump.
@visibleForTesting
double neuralPulseEnvAt(double t01, int pulseCycles, int index) {
  final phase = t01 * (pulseCycles + index);
  final progress = phase - phase.floorToDouble();
  return math.sin(progress * math.pi);
}

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

  // Connect nodes closer than this fraction of the canvas diagonal.
  static const _linkThreshold = 0.26;

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [for (final n in nodes) n.positionAt(t01, size)];
    final diag = size.shortestSide;
    final maxDist = diag * _linkThreshold;

    // Synapse lines, alpha fading to zero with distance (so a link fades out
    // smoothly as nodes separate past the threshold — no hard pop). Collect
    // edges in a stable order so the pulse can index into them deterministically.
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

    // Travelling "thought" pulses — several ride different edges, each easing in
    // and out (sine envelope). Each runs an integer number of travels per loop,
    // so every pulse is fully faded out at the loop wrap (seamless).
    if (edges.isNotEmpty) {
      for (var k = 0; k < pulseCount; k++) {
        final cycles = pulseCycles + k;
        final phase = t01 * cycles;
        final progress = phase - phase.floorToDouble();
        final env = neuralPulseEnvAt(t01, pulseCycles, k);
        if (env <= 0.02) continue;
        final edgeIndex = (phase.floor() + k * 5) % edges.length;
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
      final tw = nodes[i].breathAt(t01);
      canvas
        ..drawCircle(
          positions[i],
          nodes[i].radius * (3.6 + 0.5 * tw) * glow,
          Paint()
            ..color = nodeColor.withValues(alpha: (0.2 + 0.08 * tw) * glow)
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
      oldDelegate.t01 != t01 ||
      oldDelegate.pulseCycles != pulseCycles ||
      oldDelegate.pulseCount != pulseCount ||
      oldDelegate.nodes.length != nodes.length ||
      oldDelegate.nodeColor != nodeColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.pulseColor != pulseColor ||
      oldDelegate.glow != glow;
}
