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
    this.vineCount = 1,
    this.entanglement = 0,
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

  /// Number of primary vine spines in the organism. The default single spine is
  /// used by background surfaces; the welcome hero can use a few interleaved
  /// spines so the structure reads closer to neural tissue.
  final int vineCount;

  /// Strength of faint cross-links between nearby, separate vine systems.
  /// Kept at zero for the normal single-vine backdrop.
  final double entanglement;

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
    _nodes = _buildNodes(widget.nodeCount, widget.seed, widget.vineCount);
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didUpdateWidget(NeuralConstellation oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Regenerate the seeded node field if the topology inputs change, so a
    // reused element doesn't keep painting the old configuration (matters most
    // under reduced motion, where `t01` is static and won't trigger a repaint).
    if (oldWidget.nodeCount != widget.nodeCount ||
        oldWidget.seed != widget.seed ||
        oldWidget.vineCount != widget.vineCount) {
      _nodes = _buildNodes(widget.nodeCount, widget.seed, widget.vineCount);
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

  static List<NeuralNode> _buildNodes(int count, int seed, int vineCount) {
    if (count <= 0) return const [];
    final activeVineCount = math.min(count, math.max(1, vineCount));
    if (activeVineCount > 1) {
      return _buildEntangledVines(count, seed, activeVineCount);
    }

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

  static List<NeuralNode> _buildEntangledVines(
    int count,
    int seed,
    int vineCount,
  ) {
    final rng = math.Random(seed);
    final nodes = <NeuralNode>[];
    const roots = [
      Offset(0.18, 0.66),
      Offset(0.23, 0.46),
      Offset(0.36, 0.62),
      Offset(0.16, 0.40),
    ];
    const canopies = [
      Offset(0.66, 0.34),
      Offset(0.68, 0.54),
      Offset(0.56, 0.24),
      Offset(0.64, 0.62),
    ];
    const convergence = [
      Offset(0.33, 0.46),
      Offset(0.44, 0.38),
      Offset(0.54, 0.52),
      Offset(0.40, 0.58),
    ];

    for (var vine = 0; vine < vineCount; vine++) {
      final remaining = count - nodes.length;
      final vinesLeft = vineCount - vine;
      final vineNodeCount = math.max(1, remaining ~/ vinesLeft);
      final startIndex = nodes.length;
      final root =
          roots[vine % roots.length] +
          Offset((rng.nextDouble() - 0.5) * 0.04, rng.nextDouble() * 0.04);
      final canopy =
          canopies[vine % canopies.length] +
          Offset(
            (rng.nextDouble() - 0.5) * 0.05,
            (rng.nextDouble() - 0.5) * 0.05,
          );
      final spineCount = math.min(
        vineNodeCount,
        math.max(4, (vineNodeCount * 0.42).round()),
      );

      for (var localIndex = 0; localIndex < vineNodeCount; localIndex++) {
        final globalIndex = nodes.length;
        final parentIndex = switch (localIndex) {
          0 => null,
          _ when localIndex < spineCount => globalIndex - 1,
          _ => _entangledParentIndex(
            rng,
            nodes,
            vine,
            startIndex,
            spineCount,
          ),
        };

        Offset base;
        double growthAngle;
        if (localIndex == 0) {
          base = root;
          growthAngle = -math.pi / 5 + vine * 0.34;
        } else if (localIndex < spineCount) {
          final p = spineCount == 1 ? 0.0 : localIndex / (spineCount - 1);
          final phase = seed * 0.03 + vine * math.pi * 0.42;
          base =
              Offset.lerp(root, canopy, p)! +
              Offset(
                math.sin(p * math.pi * 2.35 + phase) * 0.07,
                math.cos(p * math.pi * 1.75 + phase) * 0.06,
              );
          base += Offset(
            (rng.nextDouble() - 0.5) * 0.04,
            (rng.nextDouble() - 0.5) * 0.04,
          );
          growthAngle = _angleBetween(nodes[parentIndex!].base, base);
        } else {
          final parent = nodes[parentIndex!];
          final spread =
              (rng.nextBool() ? -1 : 1) * (0.34 + rng.nextDouble() * 1.06);
          final reach = 0.06 + rng.nextDouble() * 0.14;
          growthAngle =
              parent.growthAngle + spread + (rng.nextDouble() - 0.5) * 0.42;
          base =
              parent.base +
              Offset(
                math.cos(growthAngle) * reach,
                math.sin(growthAngle) * reach,
              );

          if (!_insideGrowthBounds(base)) {
            final pullTarget = Offset.lerp(root, canopy, 0.58)!;
            base =
                Offset.lerp(base, pullTarget, 0.62)! +
                Offset(
                  (rng.nextDouble() - 0.5) * 0.04,
                  (rng.nextDouble() - 0.5) * 0.04,
                );
            growthAngle = _angleBetween(parent.base, base);
          }

          if (rng.nextDouble() < 0.40) {
            final cluster =
                convergence[(vine + localIndex + parent.generation) %
                    convergence.length];
            base =
                Offset.lerp(base, cluster, 0.28)! +
                Offset(
                  (rng.nextDouble() - 0.5) * 0.045,
                  (rng.nextDouble() - 0.5) * 0.045,
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
            vineId: vine,
            generation: parentIndex == null
                ? 0
                : nodes[parentIndex].generation + 1,
            driftX: 0.004 + rng.nextDouble() * 0.012,
            driftY: 0.004 + rng.nextDouble() * 0.012,
            phase: rng.nextDouble() * math.pi * 2,
            driftCycles: 1 + rng.nextInt(3),
            breathCycles: 1 + rng.nextInt(2),
            radius: switch (localIndex) {
              0 => 2.8 + rng.nextDouble() * 0.8,
              _ when localIndex < spineCount => 1.5 + rng.nextDouble() * 1.7,
              _ => 0.7 + rng.nextDouble() * 1.5,
            },
          ),
        );
      }
    }

    return nodes;
  }

  static int _entangledParentIndex(
    math.Random rng,
    List<NeuralNode> nodes,
    int vine,
    int startIndex,
    int spineCount,
  ) {
    final ownSpineEnd = math.min(nodes.length, startIndex + spineCount);
    final useNeighborVine = startIndex > 0 && rng.nextDouble() < 0.28;
    if (useNeighborVine) {
      final candidateBase =
          nodes[startIndex + rng.nextInt(ownSpineEnd - startIndex)].base;
      return _nearestOtherVineIndex(candidateBase, nodes, vine) ??
          startIndex + rng.nextInt(ownSpineEnd - startIndex);
    }
    if (rng.nextDouble() < 0.72) {
      return startIndex + rng.nextInt(ownSpineEnd - startIndex);
    }
    return startIndex + rng.nextInt(nodes.length - startIndex);
  }

  static int? _nearestOtherVineIndex(
    Offset base,
    List<NeuralNode> nodes,
    int vine,
  ) {
    int? nearestIndex;
    var nearestDistance = double.infinity;
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].vineId == vine) continue;
      final distance = (nodes[i].base - base).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestDistance < 0.32 ? nearestIndex : null;
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
              entanglement: widget.entanglement,
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
    this.vineId = 0,
  });

  final Offset base; // normalized 0..1
  final int? parentIndex;
  final double growthAngle;
  final int generation;
  final int vineId;
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

/// The travelling-pulse envelope for pulse [index] at loop phase [t01], given
/// [pulseCycles] base travels per loop. Public for seam tests.
///
/// Each pulse runs an *integer* number of travels per loop (`pulseCycles +
/// index`), so its progress is identical at `t01 == 0` and `t01 == 1`. The
/// envelope keeps a low floor rather than fading to black, which makes the
/// activation feel like a continuous relay instead of a one-shot reveal that
/// finishes between nodes.
@visibleForTesting
double neuralPulseEnvAt(double t01, int pulseCycles, int index) {
  final phase = t01 * (pulseCycles + index);
  final progress = phase - phase.floorToDouble();
  final wave = 0.5 - 0.5 * math.cos(progress * math.pi * 2);
  return 0.18 + 0.82 * Curves.easeInOut.transform(wave);
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
    final nx = point.dx / size.width;
    final ny = point.dy / size.height;
    final lowerFade = 1 - ((ny - 0.68) / 0.24).clamp(0.0, 1.0) * 0.42;
    final rightFade = 1 - ((nx - 0.76) / 0.18).clamp(0.0, 1.0) * 0.34;
    final topEdgeFade = 1 - ((0.08 - ny) / 0.08).clamp(0.0, 1.0) * 0.32;
    return lowerFade * rightFade * topEdgeFade;
  }
}
