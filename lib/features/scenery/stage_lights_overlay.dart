import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';

/// The floor-pool pass for the dancing-cats concert lighting, drawn OVER the
/// dancers: a small hot pool of each dancer's gel colour on the deck under their
/// feet, so the light reads as landing on the boards. Painted additively
/// ([BlendMode.plus]) so it only adds light.
///
/// This is the *grounding* half of the rig. The saturated **rim/halo** that
/// hugs each cat is drawn by `CharacterPainter` (`memberBacklights`) using the
/// same gel colours, so the body glow and the floor pool always match. Keeping
/// the pool here (a screen-space overlay) lets it sit on top of the deck and
/// track the dancer's foot independently of the body draw.
///
/// When [dancerAnchors] are supplied (normalized 0..1 screen positions, one per
/// light, left→right) each pool tracks its dancer's foot — lazy on small moves,
/// catching up fast on a camera cut. Without them the rig's gentle sweep places
/// the pools. The owning player supplies the clock ([timeSeconds]) and the 0..1
/// [beat] envelope (brightness pulse + colour snap). Honors OS reduce-motion by
/// freezing to a calm static frame.
class StageLightsOverlay extends StatefulWidget {
  const StageLightsOverlay({
    required this.timeSeconds,
    this.beat = 0,
    this.rig = const StageLightRig(),
    this.dancerAnchors = const [],
    this.reducedMotion = false,
    super.key,
  });

  /// Smooth wall/scene clock driving the gentle sweep + the follow easing.
  final double timeSeconds;

  /// 0..1 musical-beat envelope; boosts brightness and (via the rig) the snap.
  final double beat;

  /// The light scheduler (count, colours, sweep, cadence).
  final StageLightRig rig;

  /// Live normalized dancer positions (dx,dy in 0..1) to track, left→right. When
  /// length matches [rig].count the pools follow them; otherwise the rig sweeps
  /// on its own.
  final List<Offset> dancerAnchors;

  /// Freeze to a static frame regardless of clock (test / explicit override).
  final bool reducedMotion;

  @override
  State<StageLightsOverlay> createState() => _StageLightsOverlayState();
}

class _StageLightsOverlayState extends State<StageLightsOverlay> {
  // The pool eases toward the live foot: lazy on small moves, snapping fast when
  // the camera cuts the cat to a new spot, so it never lags a hard cut.
  static const double _aimEase = 0.24;
  static const double _floorEase = 0.24;
  static const double _cutDistance = 0.18; // a jump this big reads as a cut
  static const double _cutEase = 0.5; // catch-up rate across a cut

  List<double>? _aimX;
  List<double>? _floorY;

  double _follow(double current, double target, double base) {
    final rate = (target - current).abs() > _cutDistance ? _cutEase : base;
    return current + (target - current) * rate;
  }

  void _track(List<Offset> targets, {required bool reducedMotion}) {
    final n = targets.length;
    if (_aimX == null || _aimX!.length != n) {
      _aimX = [for (final t in targets) t.dx];
      _floorY = [for (final t in targets) t.dy];
      return;
    }
    for (var i = 0; i < n; i++) {
      final tx = targets[i].dx;
      final ty = targets[i].dy;
      if (reducedMotion) {
        _aimX![i] = tx;
        _floorY![i] = ty;
      } else {
        _aimX![i] = _follow(_aimX![i], tx, _aimEase);
        _floorY![i] = _follow(_floorY![i], ty, _floorEase);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rm =
        widget.reducedMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final following = widget.dancerAnchors.length == widget.rig.count;
    if (following) {
      _track(widget.dancerAnchors, reducedMotion: rm);
    } else {
      _aimX = _floorY = null;
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: StageLightsPainter(
            time: widget.timeSeconds,
            beat: widget.beat,
            rig: widget.rig,
            reducedMotion: rm,
            aimX: following ? List<double>.of(_aimX!) : null,
            footY: following ? List<double>.of(_floorY!) : null,
          ),
        ),
      ),
    );
  }
}

/// Paints the [StageLightRig] samples as additive floor pools: for each light, a
/// soft spread of its gel on the deck with a tight hot core where the beam
/// strikes, grounding the cat in its colour. When [aimX]/[footY] are supplied
/// (one per light) they override the rig's swept position so the pool tracks the
/// dancer's foot. Exposed (not private) so it can be unit-tested against a
/// recording canvas.
class StageLightsPainter extends CustomPainter {
  const StageLightsPainter({
    required this.time,
    required this.beat,
    required this.rig,
    this.reducedMotion = false,
    this.aimX,
    this.footY,
    this.floorY = 0.82,
    this.poolRadius = 0.105,
  });

  /// Scene clock (seconds).
  final double time;

  /// 0..1 beat envelope.
  final double beat;

  /// Light scheduler.
  final StageLightRig rig;

  /// Static frame when true.
  final bool reducedMotion;

  /// Per-light pool x (normalized), overriding the rig's swept target.
  final List<double>? aimX;

  /// Per-light floor/feet y (normalized), overriding the global [floorY].
  final List<double>? footY;

  /// Normalized y the pools land on (the dance floor) when not overridden.
  final double floorY;

  /// Floor-pool radius as a fraction of width (a small, hot puddle).
  final double poolRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final lights = rig.sample(
      time: time,
      beat: beat,
      reducedMotion: reducedMotion,
    );
    final n = lights.length;
    for (var i = 0; i < n; i++) {
      final l = lights[i];
      final aim = (aimX != null && i < aimX!.length ? aimX![i] : l.targetX) * w;
      final fy = (footY != null && i < footY!.length ? footY![i] : floorY) * h;
      _paintPool(canvas, l, w, aim, fy);
    }
  }

  void _paintPool(
    Canvas canvas,
    StageLightSample l,
    double w,
    double aim,
    double fy,
  ) {
    final i = l.intensity;
    final rx = poolRadius * w;
    final ry = rx * 0.32; // flattened: light raking across the floor
    // Sit the puddle just below the feet so it spreads onto the deck planks in
    // front of the dancer, grounding the glow where it lands.
    final cy = fy + ry * 0.5;
    // Wide soft spread: the diffuse elliptical wash (≈ a body-width pool, not a
    // pinpoint) that grounds the rim on the boards.
    final spread = Rect.fromCenter(
      center: Offset(aim, cy),
      width: rx * 2,
      height: ry * 2,
    );
    canvas.drawOval(
      spread,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            l.color.withValues(alpha: 0.46 * i),
            l.color.withValues(alpha: 0.16 * i),
            l.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(spread),
    );
    // Hot core: a tight bright hotspot where the beam strikes the deck — fast
    // falloff, lightly white-clipped — so the pool reads as light landing.
    final hot = Color.lerp(l.color, const Color(0xFFFFFFFF), 0.16)!;
    final core = Rect.fromCenter(
      center: Offset(aim, cy),
      width: rx,
      height: ry,
    );
    canvas.drawOval(
      core,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            hot.withValues(alpha: 0.75 * i),
            l.color.withValues(alpha: 0.24 * i),
            l.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(core),
    );
  }

  @override
  bool shouldRepaint(StageLightsPainter old) =>
      old.time != time ||
      old.beat != beat ||
      old.rig != rig ||
      old.reducedMotion != reducedMotion ||
      !listEquals(old.aimX, aimX) ||
      !listEquals(old.footY, footY);
}
