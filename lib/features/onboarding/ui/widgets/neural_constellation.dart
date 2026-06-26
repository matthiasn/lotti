import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An ambient, looping "external brain" backdrop: glowing cell bodies drift on
/// gentle elliptical paths, curved tendrils connect into one branching organism,
/// and soft activation tips travel along those branches.
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
    this.compositionScale = 1,
    this.compositionOffset = Offset.zero,
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

  /// Scales the whole branching organism around the canvas centre. The welcome
  /// hero uses a larger value so the artwork owns the opening beat; background
  /// surfaces use a smaller value so the organism stays textural behind forms.
  final double compositionScale;

  /// Translates the scaled organism by a normalized canvas offset. The welcome
  /// hero shifts the organism slightly upward so it belongs to the modal's top
  /// surface; background surfaces keep the default.
  final Offset compositionOffset;

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
    if (count <= 0) return const [];

    final rng = math.Random(seed);
    final nodes = <NeuralNode>[];
    final root = Offset(0.18 + rng.nextDouble() * 0.08, 0.68);
    final canopy = Offset(0.78 + rng.nextDouble() * 0.06, 0.24);
    final spineCount = math.min(count, math.max(3, (count * 0.38).round()));

    for (var i = 0; i < count; i++) {
      final parentIndex = switch (i) {
        0 => null,
        _ when i < spineCount => i - 1,
        _ => rng.nextDouble() < 0.68 ? rng.nextInt(spineCount) : rng.nextInt(i),
      };

      Offset base;
      double growthAngle;
      if (i == 0) {
        base = root;
        growthAngle = -math.pi / 5;
      } else if (i < spineCount) {
        final p = spineCount == 1 ? 0.0 : i / (spineCount - 1);
        final wave = math.sin(p * math.pi * 2 + seed);
        base =
            Offset.lerp(root, canopy, p)! +
            Offset(
              wave * 0.08,
              math.cos(p * math.pi * 1.6 + seed) * 0.07,
            );
        base += Offset(
          (rng.nextDouble() - 0.5) * 0.05,
          (rng.nextDouble() - 0.5) * 0.05,
        );
        growthAngle = _angleBetween(nodes[parentIndex!].base, base);
      } else {
        final parent = nodes[parentIndex!];
        final spread =
            (rng.nextBool() ? -1 : 1) * (0.42 + rng.nextDouble() * 1.18);
        final reach = 0.08 + rng.nextDouble() * 0.15;
        growthAngle =
            parent.growthAngle + spread + (rng.nextDouble() - 0.5) * 0.38;
        base =
            parent.base +
            Offset(
              math.cos(growthAngle) * reach,
              math.sin(growthAngle) * reach,
            );

        if (!_insideGrowthBounds(base)) {
          final centerPull = Offset.lerp(base, const Offset(0.52, 0.52), 0.55)!;
          base =
              centerPull +
              Offset(
                (rng.nextDouble() - 0.5) * 0.04,
                (rng.nextDouble() - 0.5) * 0.04,
              );
          growthAngle = _angleBetween(parent.base, base);
        }
      }

      base = _clampBase(base);
      nodes.add(
        NeuralNode(
          base: base,
          parentIndex: parentIndex,
          growthAngle: growthAngle,
          generation: parentIndex == null
              ? 0
              : nodes[parentIndex].generation + 1,
          // Gentle elliptical drift, a few percent of the canvas.
          driftX: 0.01 + rng.nextDouble() * 0.026,
          driftY: 0.01 + rng.nextDouble() * 0.026,
          phase: rng.nextDouble() * math.pi * 2,
          // Integer cycles per loop keep each node seamless at the wrap while a
          // small spread (1..3 drift, 1..2 breath) preserves organic variety.
          driftCycles: 1 + rng.nextInt(3),
          breathCycles: 1 + rng.nextInt(2),
          radius: switch (i) {
            0 => 3.4,
            _ when i < spineCount => 1.9 + rng.nextDouble() * 1.9,
            _ => 0.8 + rng.nextDouble() * 1.7,
          },
        ),
      );
    }

    return nodes;
  }

  static bool _insideGrowthBounds(Offset p) =>
      p.dx >= 0.07 && p.dx <= 0.93 && p.dy >= 0.12 && p.dy <= 0.88;

  static Offset _clampBase(Offset p) => Offset(
    p.dx.clamp(0.06, 0.94),
    p.dy.clamp(0.12, 0.88),
  );

  static double _angleBetween(Offset from, Offset to) =>
      math.atan2(to.dy - from.dy, to.dx - from.dx);

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
              compositionScale: widget.compositionScale,
              compositionOffset: widget.compositionOffset,
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
    this.parentIndex,
    this.growthAngle = 0,
    this.generation = 0,
  });

  final Offset base; // normalized 0..1
  final int? parentIndex;
  final double growthAngle;
  final int generation;
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

/// Branch activation progress for a stable branch index. Branches are offset
/// across the organism, so sampled frames show activity moving through a grown
/// structure instead of unrelated bright dots.
@visibleForTesting
double neuralBranchProgressAt(
  double t01,
  int pulseCycles,
  int branchIndex,
  int branchCount,
) {
  final offset = branchIndex / math.max(1, branchCount);
  final phase = t01 * pulseCycles - offset;
  return phase - phase.floorToDouble();
}

class _NeuralBranch {
  const _NeuralBranch(this.from, this.to);

  final int from;
  final int to;
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
    required this.compositionScale,
    required this.compositionOffset,
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

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [
      for (final n in nodes)
        _offsetPoint(
          _scaleAroundCenter(n.positionAt(t01, size), size, compositionScale),
          size,
          compositionOffset,
        ),
    ];
    final branches = <_NeuralBranch>[];
    for (var i = 0; i < nodes.length; i++) {
      final parentIndex = nodes[i].parentIndex;
      if (parentIndex != null && parentIndex < nodes.length) {
        branches.add(_NeuralBranch(parentIndex, i));
      }
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
      _drawTendrilGlow(
        canvas,
        from: from,
        control: control,
        to: to,
        color: lineColor.withValues(
          alpha: lineColor.a * branchWeight * (0.10 + 0.05 * breath),
        ),
        width: 5.6 + nodes[branch.from].radius * 0.42 * branchWeight,
      );
      _drawTendril(
        canvas,
        from: from,
        control: control,
        to: to,
        color: lineColor.withValues(
          alpha: lineColor.a * branchWeight * (0.38 + 0.20 * breath),
        ),
        width: 1.1 + nodes[branch.from].radius * 0.22 * branchWeight,
      );

      if (generation > 1 && branch.to.isOdd) {
        _drawHairline(
          canvas,
          origin: _quadraticPoint(from, control, to, 0.68),
          angle:
              nodes[branch.to].growthAngle +
              (branch.to.isEven ? math.pi / 2.8 : -math.pi / 2.8),
          phase: nodes[branch.to].phase,
          size: size,
          color: lineColor.withValues(alpha: lineColor.a * 0.18 * branchWeight),
        );
      }
    }

    for (var k = 0; k < pulseCount; k++) {
      for (var i = 0; i < branches.length; i++) {
        if ((i + k * 3) % 4 != 0) continue;

        final progress = neuralBranchProgressAt(
          t01 + k / pulseCount,
          pulseCycles + k,
          i,
          branches.length,
        );
        final env = neuralPulseEnvAt(progress, 1, 0);
        if (env <= 0.30) continue;

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
        final tail = eased <= 0.20 ? 0.0 : eased - 0.20;
        _drawTendril(
          canvas,
          from: _quadraticPoint(from, control, to, tail),
          control: _quadraticPoint(from, control, to, (tail + eased) / 2),
          to: head,
          color: pulseColor.withValues(alpha: 0.20 * env),
          width: 1.8 + env * 0.8,
          segments: 6,
        );
        canvas
          ..drawCircle(
            head,
            5.8 * env,
            Paint()
              ..color = pulseColor.withValues(alpha: 0.18 * env)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          )
          ..drawCircle(
            head,
            1.4 + env * 0.58,
            Paint()..color = pulseColor.withValues(alpha: 0.62 * env),
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
      final coreAlpha = (isRoot ? 0.9 : 0.74) * hierarchy;
      final nodeRadius = nodes[i].radius;
      final drawCore =
          isRoot || generation <= 1 || nodeRadius > 1.85 || i.isOdd;
      if (!drawCore) {
        canvas.drawCircle(
          positions[i],
          nodeRadius * 0.56,
          Paint()..color = nodeColor.withValues(alpha: 0.24 * hierarchy),
        );
        continue;
      }
      canvas
        ..drawCircle(
          positions[i],
          nodeRadius * (3.9 + 0.8 * tw) * glow,
          Paint()
            ..color = nodeColor.withValues(
              alpha: (0.13 + 0.07 * tw) * hierarchy * glow,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        )
        ..drawCircle(
          positions[i],
          nodeRadius * (isRoot ? 1.16 : 1),
          Paint()..color = nodeColor.withValues(alpha: coreAlpha),
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
}
