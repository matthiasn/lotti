import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart'
    show kDroneShowCycleSeconds;
import 'package:lotti/features/scenery/model/scenery_assets.dart';

/// Duration of the distant 747 pass.
///
/// A ~60 second crossing keeps the 747 moving clearly in the opening minute
/// while still reading as a distant approach/departure, not a foreground flyby.
const double kDistantJetPassSeconds = 60;

/// Short blank lead-in so the aircraft is not visible on the first video frame.
const double kDistantJetStartDelaySeconds = 0.18;

/// Extra seconds the contrails remain after the aircraft has left the stage.
const double kDistantJetTrailHoldSeconds = 32;

/// FAA Part 25 anti-collision systems must flash at 40-100 cycles/minute.
/// Use a centered 60 cpm cadence so the distant jet reads as aviation lighting
/// without becoming a music-video strobe.
const double kAircraftAntiCollisionCyclesPerMinute = 60;

/// One pulse per second at [kAircraftAntiCollisionCyclesPerMinute].
const double kAircraftAntiCollisionPeriodSeconds =
    60 / kAircraftAntiCollisionCyclesPerMinute;

const _engineNozzles = [
  ui.Offset(0.36, 0.73),
  ui.Offset(0.43, 0.76),
  ui.Offset(0.54, 0.69),
  ui.Offset(0.61, 0.68),
];

/// Visible exhaust contrails usually begin after the hot plume has mixed and
/// cooled. NASA/LaRC references put typical formation at <=30 m behind the
/// engines; for a 747-sized aircraft that reads as roughly half a body length.
const double _contrailFormationAircraftLengths = 0.45;

/// Extra body lengths over which the first visible ice crystals fade in.
const double _contrailFadeInAircraftLengths = 0.24;

const double _contrailSampleStepSeconds = 0.14;

/// A small, distant Lufthansa 747 crossing the blue-hour sky right-to-left.
///
/// The aircraft itself is a generated transparent bitmap asset; this layer owns
/// only the timing, placement, haze/opacity, FAA-rate anti-collision lights, and
/// four engine-origin contrails. It is drawn behind the drone show as independent
/// background traffic, not as a collision/near-collision gag.
class DistantJetLayer implements BackdropLayer {
  const DistantJetLayer({
    this.passSeconds = kDistantJetPassSeconds,
    this.cycleSeconds = kDroneShowCycleSeconds,
  });

  /// Seconds spent crossing the frame in one loop.
  final double passSeconds;

  /// Scene-loop duration. Matches the drone show by default.
  final double cycleSeconds;

  @override
  void paint(ui.Canvas canvas, BackdropContext ctx) {
    if (ctx.reducedMotion) return;
    final image = ctx.images[SceneryAssets.lufthansa747];
    if (image == null) return;

    final sample = sampleDistantJet(
      ctx.timeSeconds,
      passSeconds: passSeconds,
      cycleSeconds: cycleSeconds,
    );
    if (sample == null) return;

    final stage = distantJetStageRect(ctx.size);
    final center = ui.Offset(
      stage.left + sample.position.dx * stage.width,
      stage.top + sample.position.dy * stage.height,
    );
    final width = stage.width * sample.widthFraction;
    final height = width * image.height / image.width;

    canvas
      ..save()
      ..clipRect(stage)
      ..saveLayer(stage, ui.Paint());
    _paintTrail(
      canvas,
      ctx,
      stage,
      image,
      passSeconds: passSeconds,
      cycleSeconds: cycleSeconds,
    );
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(sample.headingRadians);
    _paintJetBitmap(canvas, image, sample, width, height);
    _paintLights(canvas, ctx, sample, width, height);
    canvas
      ..restore()
      ..save()
      ..clipRect(stage);
    _cutSkylineOccluder(canvas, ctx);
    canvas
      ..restore()
      ..restore()
      ..restore();
  }
}

void _cutSkylineOccluder(ui.Canvas canvas, BackdropContext ctx) {
  final occluder = ctx.images[SceneryAssets.cityBridge];
  if (occluder == null) return;

  final src = ui.Rect.fromLTWH(
    0,
    0,
    occluder.width.toDouble(),
    occluder.height.toDouble(),
  );
  final dest = _coverRect(src.size, ctx.size);
  final paint = ui.Paint()
    ..blendMode = ui.BlendMode.dstOut
    ..filterQuality = ui.FilterQuality.medium;

  // A small pad removes bright aircraft pixels from antialiased skyline edges,
  // which otherwise read as a deregistered ghost mask in close camera crops.
  const offsets = [
    ui.Offset.zero,
    ui.Offset(-1.25, 0),
    ui.Offset(1.25, 0),
    ui.Offset(0, -1.25),
    ui.Offset(0, 1.25),
  ];
  for (final offset in offsets) {
    canvas.drawImageRect(occluder, src, dest.shift(offset), paint);
  }
}

ui.Rect _coverRect(ui.Size image, ui.Size viewport) {
  if (image.isEmpty || viewport.isEmpty) return ui.Rect.zero;
  final scale = math.max(
    viewport.width / image.width,
    viewport.height / image.height,
  );
  final width = image.width * scale;
  final height = image.height * scale;
  return ui.Rect.fromLTWH(
    (viewport.width - width) / 2,
    (viewport.height - height) / 2,
    width,
    height,
  );
}

/// Active 16:9 composition rect inside [viewport].
///
/// The dance demo letterboxes the stage to 16:9; this layer uses the same rect
/// so the aircraft never paints into side bars on wider desktop/export surfaces.
ui.Rect distantJetStageRect(ui.Size viewport) {
  if (viewport.isEmpty) return ui.Rect.zero;
  const aspect = 16 / 9;
  final viewportAspect = viewport.width / viewport.height;
  if (viewportAspect > aspect) {
    final width = viewport.height * aspect;
    return ui.Rect.fromLTWH(
      (viewport.width - width) / 2,
      0,
      width,
      viewport.height,
    );
  }
  final height = viewport.width / aspect;
  return ui.Rect.fromLTWH(
    0,
    (viewport.height - height) / 2,
    viewport.width,
    height,
  );
}

/// One normalized sample for the distant jet pass.
class DistantJetSample {
  const DistantJetSample({
    required this.position,
    required this.widthFraction,
    required this.opacity,
    required this.trailOpacity,
    required this.trailLengthScale,
    required this.headingRadians,
    required this.beacon,
    required this.strobe,
  });

  /// Normalized position in the active 16:9 stage coordinate space.
  final ui.Offset position;

  /// Plane width as a fraction of the active 16:9 stage width.
  final double widthFraction;

  /// Haze/edge visibility multiplier.
  final double opacity;

  /// Separate trail visibility multiplier.
  final double trailOpacity;

  /// Contrail length in aircraft-body widths.
  final double trailLengthScale;

  /// Direction of travel. Negative means a shallow climb to the right.
  final double headingRadians;

  /// Red anti-collision beacon intensity.
  final double beacon;

  /// White wingtip strobe intensity.
  final double strobe;
}

/// Samples the pass. Returns null outside the visible pass window.
DistantJetSample? sampleDistantJet(
  double timeSeconds, {
  double passSeconds = kDistantJetPassSeconds,
  double cycleSeconds = kDroneShowCycleSeconds,
}) {
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final safePass = passSeconds <= 0 ? kDistantJetPassSeconds : passSeconds;
  final local = _jetPassLocalSeconds(timeSeconds, safeCycle);
  if (local == null) return null;
  return _sampleDistantJetLocal(local, safePass);
}

double? _jetPassLocalSeconds(double timeSeconds, double safeCycle) {
  final local = _fraction(timeSeconds / safeCycle) * safeCycle;
  if (local < kDistantJetStartDelaySeconds) return null;
  return local - kDistantJetStartDelaySeconds;
}

DistantJetSample? _sampleDistantJetLocal(double local, double safePass) {
  if (local > safePass + kDistantJetTrailHoldSeconds) return null;

  final progress = (local / safePass).clamp(0.0, 1.0);
  final eased = _smoothstep(progress);
  final afterPassSeconds = math.max(0, local - safePass);
  final trailAfterPassFade =
      1 - _smoothstep(afterPassSeconds / kDistantJetTrailHoldSeconds);
  // Start at the right edge, but lower in open sky. The earlier high path
  // entered under the foreground palm, making its lights read detached.
  final x = 0.98 - progress * 1.10;
  // Departing/climbing very gently high above the skyline. Keep it comfortably
  // in the open sky: too high/right gets hidden by the foreground palm canopy.
  final y = 0.295 - eased * 0.055 + math.sin(progress * math.pi) * 0.002;
  final edge = distantJetEdgeVisibility(x);
  if (edge <= 0) return null;

  return DistantJetSample(
    position: ui.Offset(x, y),
    widthFraction: 0.06 - progress * 0.0015,
    opacity: edge * (0.84 - progress * 0.10) * (afterPassSeconds > 0 ? 0 : 1),
    trailOpacity:
        edge *
        trailAfterPassFade *
        (0.48 + math.sin(progress * math.pi) * 0.12),
    trailLengthScale: math.min(7.2, math.max(0.28, local * 0.36)),
    headingRadians: -0.01,
    beacon: aircraftBeaconPulse(local),
    strobe: aircraftWingStrobe(local),
  );
}

/// Edge fade for the pass so the jet never pops on/off at the frame boundary.
double distantJetEdgeVisibility(double x) {
  final enter = 1 - _smoothstep((x - 1.12) / 0.08);
  final exit = _smoothstep((x + 0.18) / 0.12);
  return (enter * exit).clamp(0.0, 1.0);
}

/// Red anti-collision beacon pulse at 60 cycles/minute.
double aircraftBeaconPulse(double timeSeconds, {double phase = 0}) {
  final t = _fraction(
    (timeSeconds + phase) / kAircraftAntiCollisionPeriodSeconds,
  );
  const flashWidth = 0.11;
  if (t > flashWidth) return 0;
  return 1 - _smoothstep(t / flashWidth);
}

/// White anti-collision wingtip pulse, synchronized with the red beacon.
double aircraftWingStrobe(double timeSeconds, {double phase = 0}) {
  return aircraftBeaconPulse(timeSeconds, phase: phase);
}

void _paintJetBitmap(
  ui.Canvas canvas,
  ui.Image image,
  DistantJetSample sample,
  double width,
  double height,
) {
  final dst = ui.Rect.fromCenter(
    center: ui.Offset.zero,
    width: width,
    height: height,
  );
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    dst,
    ui.Paint()
      ..isAntiAlias = true
      ..filterQuality = ui.FilterQuality.medium
      ..color = const ui.Color(
        0xFFFFFFFF,
      ).withValues(alpha: sample.opacity),
  );
}

void _paintTrail(
  ui.Canvas canvas,
  BackdropContext ctx,
  ui.Rect stage,
  ui.Image image, {
  required double passSeconds,
  required double cycleSeconds,
}) {
  final safeCycle = cycleSeconds <= 0 ? kDroneShowCycleSeconds : cycleSeconds;
  final safePass = passSeconds <= 0 ? kDistantJetPassSeconds : passSeconds;
  final local = _jetPassLocalSeconds(ctx.timeSeconds, safeCycle);
  if (local == null) return;
  final current = _sampleDistantJetLocal(local, safePass);
  if (current == null || current.trailOpacity <= 0) return;

  ui.Offset engineAt(DistantJetSample sample, ui.Offset normalizedNozzle) {
    final center = ui.Offset(
      stage.left + sample.position.dx * stage.width,
      stage.top + sample.position.dy * stage.height,
    );
    final width = stage.width * sample.widthFraction;
    final height = width * image.height / image.width;
    final localPoint = ui.Offset(
      (normalizedNozzle.dx - 0.5) * width,
      (normalizedNozzle.dy - 0.5) * height,
    );
    return center + _rotate(localPoint, sample.headingRadians);
  }

  ui.Offset windDrift(double ageSeconds) {
    final age = ageSeconds / kDistantJetTrailHoldSeconds;
    return ui.Offset(stage.width * 0.004 * age, -stage.height * 0.002 * age);
  }

  final stageSpeedPerSecond = 1.10 / safePass;
  final formationGapSeconds =
      current.widthFraction *
      _contrailFormationAircraftLengths /
      stageSpeedPerSecond;
  final formationFadeSeconds =
      current.widthFraction *
      _contrailFadeInAircraftLengths /
      stageSpeedPerSecond;
  final maxAge = math.min(local, kDistantJetTrailHoldSeconds);
  if (maxAge <= formationGapSeconds) return;

  for (final normalizedNozzle in _engineNozzles) {
    final points = <_TrailPoint>[];
    for (
      var age = formationGapSeconds;
      age <= maxAge;
      age += _contrailSampleStepSeconds
    ) {
      final emitted = _sampleDistantJetLocal(local - age, safePass);
      if (emitted == null || emitted.opacity <= 0) continue;

      points.add(
        _TrailPoint(engineAt(emitted, normalizedNozzle) + windDrift(age), age),
      );
    }
    if (points.length < 2) continue;

    _paintTrailRibbon(
      canvas,
      points,
      formationGapSeconds: formationGapSeconds,
      formationFadeSeconds: formationFadeSeconds,
      maxAge: maxAge,
      maxWidth: stage.height * 0.0042,
      widthStartFactor: 0.24,
      widthEndFactor: 1.35,
      shader: ui.Gradient.linear(
        points.first.position,
        points.last.position,
        [
          ctx.palette.cloudLit.withValues(alpha: 0),
          ctx.palette.cloudLit.withValues(alpha: current.trailOpacity * 0.11),
          ctx.palette.cloudBase.withValues(alpha: current.trailOpacity * 0.07),
          ctx.palette.cloudBase.withValues(alpha: 0),
        ],
        [0, 0.08, 0.62, 1],
      ),
    );
    _paintTrailRibbon(
      canvas,
      points,
      formationGapSeconds: formationGapSeconds,
      formationFadeSeconds: formationFadeSeconds,
      maxAge: maxAge,
      maxWidth: stage.height * 0.0011,
      widthStartFactor: 1,
      widthEndFactor: 0.18,
      shader: ui.Gradient.linear(
        points.first.position,
        points.last.position,
        [
          ctx.palette.cloudLit.withValues(alpha: 0),
          ctx.palette.cloudLit.withValues(alpha: current.trailOpacity * 0.46),
          ctx.palette.cloudBase.withValues(alpha: current.trailOpacity * 0.13),
          ctx.palette.cloudBase.withValues(alpha: 0),
        ],
        [0, 0.045, 0.34, 1],
      ),
    );
  }
}

void _paintTrailRibbon(
  ui.Canvas canvas,
  List<_TrailPoint> points, {
  required double formationGapSeconds,
  required double formationFadeSeconds,
  required double maxAge,
  required double maxWidth,
  required double widthStartFactor,
  required double widthEndFactor,
  required ui.Shader shader,
}) {
  final left = <ui.Offset>[];
  final right = <ui.Offset>[];
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final tangent =
        points[math.min(i + 1, points.length - 1)].position -
        points[math.max(i - 1, 0)].position;
    final length = tangent.distance;
    if (length == 0) continue;

    final normal = ui.Offset(-tangent.dy / length, tangent.dx / length);
    final fadeIn = _smoothstep(
      (point.ageSeconds - formationGapSeconds) / formationFadeSeconds,
    );
    final mature = _smoothstep(
      (point.ageSeconds - formationGapSeconds) / 5,
    );
    final age01 =
        ((point.ageSeconds - formationGapSeconds) /
                math.max(0.001, maxAge - formationGapSeconds))
            .clamp(0.0, 1.0);
    final ageWidth = ui.lerpDouble(
      widthStartFactor,
      widthEndFactor,
      _smoothstep(age01),
    )!;
    final halfWidth = maxWidth * fadeIn * (0.82 + 0.18 * mature) * ageWidth / 2;
    left.add(point.position + normal * halfWidth);
    right.add(point.position - normal * halfWidth);
  }
  if (left.length < 2 || right.length < 2) return;

  final path = ui.Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();

  canvas.drawPath(
    path,
    ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.fill
      ..shader = shader,
  );
}

class _TrailPoint {
  const _TrailPoint(this.position, this.ageSeconds);

  final ui.Offset position;
  final double ageSeconds;
}

ui.Offset _rotate(ui.Offset p, double radians) {
  final c = math.cos(radians);
  final s = math.sin(radians);
  return ui.Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
}

void _paintLights(
  ui.Canvas canvas,
  BackdropContext ctx,
  DistantJetSample sample,
  double width,
  double height,
) {
  ui.Offset assetPoint(double x, double y) {
    return ui.Offset((x - 0.5) * width, (y - 0.5) * height);
  }

  void lamp(
    ui.Offset c,
    ui.Color color,
    double intensity,
    double radius, {
    double bloom = 4,
  }) {
    if (intensity <= 0) return;
    final alpha = sample.opacity * intensity;
    canvas
      ..drawCircle(
        c,
        radius * bloom,
        ui.Paint()
          ..blendMode = ui.BlendMode.plus
          ..shader = ui.Gradient.radial(
            c,
            radius * bloom,
            [
              color.withValues(alpha: alpha * 0.58),
              color.withValues(alpha: alpha * 0.13),
              color.withValues(alpha: 0),
            ],
            [0, 0.42, 1],
          ),
      )
      ..drawCircle(
        c,
        radius,
        ui.Paint()
          ..blendMode = ui.BlendMode.plus
          ..color = ui.Color.lerp(
            color,
            const ui.Color(0xFFFFFFFF),
            0.38,
          )!.withValues(alpha: alpha),
      );
  }

  final r = math.max(1.1, height * 0.05);
  final visibleWingtip = assetPoint(0.787, 0.322);
  final tailCone = assetPoint(0.982, 0.438);
  final topBeacon = assetPoint(0.438, 0.397);
  final bottomBeacon = assetPoint(0.438, 0.688);

  // Side-on left/profile bitmap: draw only the visible port wing position light
  // plus the rear white position light. The opposite green wingtip is hidden by
  // the fuselage/wing geometry at this angle.
  lamp(
    visibleWingtip,
    ctx.palette.shipPort,
    0.76,
    r * 0.82,
    bloom: 3.2,
  );
  lamp(
    tailCone,
    ctx.palette.shipMast,
    0.74,
    r * 0.86,
    bloom: 3.4,
  );

  // Anti-collision lights: one FAA-rate system pulse, aviation red on the
  // fuselage beacons and aviation white at the visible wingtip strobe.
  lamp(
    visibleWingtip.translate(0, -r * 0.7),
    ctx.palette.aircraftStrobe,
    sample.strobe,
    r * 1.2,
    bloom: 5.4,
  );
  lamp(
    topBeacon,
    ctx.palette.aircraftBeacon,
    sample.beacon,
    r,
    bloom: 4.4,
  );
  lamp(
    bottomBeacon,
    ctx.palette.aircraftBeacon,
    sample.beacon * 0.62,
    r * 0.8,
    bloom: 3.4,
  );
}

double _smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _fraction(double value) => value - value.floorToDouble();
