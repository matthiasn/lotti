import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/scenery/runtime/stage_lights.dart';

/// Horizontal shear applied to each floor pool per unit of normalized distance
/// from frame centre, so off-centre pools splay outward with depth and lie along
/// the deck's plank perspective (vanishing point up-centre) instead of facing
/// the lens as flat discs.
const double _kPoolLean = 0.34;

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
    this.poolRadius = 0.135,
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
      final hasLead = rig.leadGoldIndex != null;
      final isLead = hasLead && i == rig.leadGoldIndex;
      _paintPool(canvas, l, w, aim, fy, isLead: isLead, hasLead: hasLead);
    }
  }

  void _paintPool(
    Canvas canvas,
    StageLightSample l,
    double w,
    double aim,
    double fy, {
    required bool isLead,
    required bool hasLead,
  }) {
    // Focal hierarchy: when a lead is designated, its warm pool must be the
    // hottest + largest puddle on the deck. The backups are crushed (~58%
    // intensity, ~84% radius) and desaturated toward a cool grey so their
    // saturated magenta/violet stops out-glowing the lead (every craft lens
    // flagged the inverted focus — the backup pools were the most chromatic
    // objects in frame). With no designated lead, every pool renders at full gel.
    final demoted = hasLead && !isLead;
    // Lead pool core dropped from a 1.15 boost to 1.0 so the dark contact core
    // stays the darkest value under him (it was reading as a bright spotlight
    // decal that out-glowed its own AO). The lead still dominates via its larger
    // radius + longer forward run + warm gel, not raw luminance.
    final i = l.intensity * (isLead ? 1.0 : (demoted ? 0.46 : 1.0));
    // Backups: desaturate HARDER toward a cool blue-hour slate (was a neutral
    // grey) so the flanking pools stop advertising themselves as candy magenta/
    // violet and instead read as cool ambient spill supporting the warm lead.
    final col = demoted
        ? Color.lerp(l.color, const Color(0xFF42506E), 0.45)!
        : l.color;
    final rx = poolRadius * w * (isLead ? 1.18 : (demoted ? 0.84 : 1.0));
    final ry =
        rx * 0.42; // foreshortened, but with real forward (downstage) run
    // Lay the pool along the deck's perspective instead of stamping a flat disc:
    // anchor it at the foot (local origin) and let it RAKE FORWARD toward the
    // camera (down-frame), with a horizontal shear so off-centre pools splay
    // outward with depth — i.e. lie along the plank vanishing lines rather than
    // facing the lens. Drawn in this foot-local, sheared frame.
    final lean = ((aim / w) - 0.5) * _kPoolLean;
    final frame = Matrix4.identity()
      ..setEntry(0, 3, aim)
      ..setEntry(1, 3, fy)
      ..setEntry(0, 1, lean);
    canvas
      ..save()
      ..transform(frame.storage);
    // Hot at the foot contact, fading downstage: the gradient centre rides up
    // near the foot (Alignment y < 0) while the ellipse body extends forward.
    // The lead's pool runs LONGER down the boards (a raking key streak rather
    // than a circular spotlight decal) so it reads as light grazing the deck.
    final cy = ry * (isLead ? 1.45 : 1.15);
    final spread = Rect.fromCenter(
      center: Offset(0, cy),
      width: rx * 2,
      height: ry * (isLead ? 3.0 : 2.4),
    );
    canvas.drawOval(
      spread,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0, -0.45),
          colors: [
            col.withValues(alpha: 0.54 * i),
            col.withValues(alpha: 0.22 * i),
            col.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(spread),
    );
    // Hot core: a tight bright hotspot at the foot/deck contact — fast falloff,
    // only faintly white-clipped so the gel stays its own hue (not a blown white
    // puddle), reading as light landing rather than a sticker.
    final hot = Color.lerp(col, const Color(0xFFFFFFFF), 0.07)!;
    final core = Rect.fromCenter(
      center: Offset(0, ry * 0.45),
      width: rx,
      height: ry * 1.1,
    );
    canvas.drawOval(
      core,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          colors: [
            hot.withValues(alpha: 0.64 * i),
            col.withValues(alpha: 0.28 * i),
            col.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(core),
    );
    // CONTACT OCCLUSION. The additive spill above would otherwise blow out the
    // exact contact point into a bright puddle, so the cat reads as floating ON
    // the pool. A dancer actually OCCLUDES the floor light where they stand, so
    // punch a small, cool near-black shadow back into the pool's centre (normal
    // alpha-over, on top of the additive gel) hugging the sole: a hard contact
    // anchor under each cat, the gel spilling AROUND it instead of through it.
    // Beat-independent (grounding must not pulse) and tight (a foot-length) so it
    // never becomes a murky hole. This is the grounding the rim/pool alone can't
    // give — a real dark contact, not just coloured spill.
    // The lead's pool is the boosted/largest, so its warm spill most readily
    // reads as the cat FLOATING on a glowing decal. Give the lead a DENSER,
    // tighter contact core (the planted foot must read as weight on the deck);
    // the backups keep the lighter core they already had.
    const occBase = Color(0xFF060D18); // cool near-black
    final occDense = occBase.withValues(alpha: isLead ? 0.86 : 0.7);
    final occMid = occBase.withValues(alpha: isLead ? 0.46 : 0.4);
    final occ = Rect.fromCenter(
      center: Offset(0, ry * 0.12),
      width: rx * (isLead ? 0.9 : 0.86),
      height: ry * (isLead ? 1.15 : 1.05),
    );
    canvas
      ..drawOval(
        occ,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.1),
            colors: [occDense, occMid, occBase.withValues(alpha: 0)],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(occ),
      )
      ..restore();
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
