import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';

enum CharacterBackdrop { none, waterfront }

/// Stands the character on the ground of a [size] canvas with its **feet** at
/// [feetFraction] of the height, horizontally at [centreX], facing right unless
/// [flip] (then mirrored), uniformly scaled by [scale]. [feetOffset] is the
/// rig's rest distance from origin to the feet (see
/// [CharacterScene.restFeetOffset]); the origin is lifted by it so the feet —
/// not the hips — land on the floor line.
Affine2D groundedBase(
  Size size, {
  required double centreX,
  double scale = 1,
  double feetFraction = 0.92,
  double feetOffset = 0,
  bool flip = false,
}) => Affine2D.translation(
  centreX,
  size.height * feetFraction - feetOffset * scale,
).multiply(Affine2D.scale(flip ? -scale : scale, scale));

/// A [CustomPainter] that resolves and draws one frame of a [CharacterScene].
///
/// Per the plan's perf guidance the live ticker lives in the widget `State`,
/// not in a provider; this painter just turns `(clip, time, expression)` into
/// pixels via the shared [CharacterRenderer].
class CharacterPainter extends CustomPainter {
  CharacterPainter({
    required this.scene,
    required this.clip,
    required this.timeSeconds,
    this.expression = Expression.neutral,
    this.scale = 1,
    this.eyeOpenScale = 1,
    this.feetFraction = 0.9,
    this.groundColor,
    this.shadowColor = const Color(0x33000000),
    this.backdrop = CharacterBackdrop.none,
    this.locomote = false,
    this.walkingPair = false,
    this.partnerScene,
    this.ensembleScenes = const [],
    this.ensembleExpressions = const [],
    this.ensembleClips = const [],
    this.synchronousEnsemble = false,
    CharacterRenderer? renderer,
  }) : _renderer = renderer ?? CharacterRenderer();

  final CharacterScene scene;

  /// Optional alternate rig/scene for the second cat in pair mode. When null,
  /// pair mode paints the primary [scene] twice (the historical walk behavior).
  final CharacterScene? partnerScene;

  /// Additional alternate scenes for ensemble mode. When provided, pair mode
  /// paints `[scene, ...ensembleScenes]` instead of the legacy two-cat pair.
  final List<CharacterScene> ensembleScenes;

  /// Optional per-member expressions. Index 0 applies to [scene]; subsequent
  /// entries apply to [ensembleScenes]. Missing entries fall back to
  /// [expression].
  final List<Expression> ensembleExpressions;

  /// Optional per-member clips. Index 0 applies to [scene]; subsequent entries
  /// apply to [ensembleScenes]. Missing entries fall back to [clip].
  final List<Clip> ensembleClips;

  /// When true, every ensemble member samples the clip at [timeSeconds]. When
  /// false, members get staggered phase offsets for a looser walk-showcase feel.
  final bool synchronousEnsemble;

  final Clip clip;
  final double timeSeconds;
  final Expression expression;
  final double scale;

  /// Manual eyelid multiplier (1 = no change) — drives the demo's blink.
  final double eyeOpenScale;

  /// Fraction of the canvas height at which the floor (and the feet) sit.
  final double feetFraction;

  /// When set, a floor band is filled from [feetFraction] to the bottom so the
  /// character has something to stand on instead of floating in the void.
  final Color? groundColor;

  /// Colour of the soft ground-contact shadow under the feet.
  final Color shadowColor;

  /// Optional animated environment painted behind the character.
  final CharacterBackdrop backdrop;

  /// When true (and the clip carries a [Clip.locomotionSpeed]) the character
  /// travels: it walks across the stage and ping-pongs at the edges (turning to
  /// face the direction of travel). Travelling is what makes the planted foot
  /// hold still in world space instead of skating in place.
  final bool locomote;

  /// When true, paints multiple copies side-by-side. The group shares one
  /// travelling centre, so they keep their lane spacing instead of ping-ponging
  /// into each other.
  final bool walkingPair;
  final CharacterRenderer _renderer;

  // Keep the cat this far from the stage edges as it walks back and forth.
  static const double _edgeMargin = 44;
  static const double _pairScaleFactor = 0.7;
  static const double _trioScaleFactor = 0.59;
  static const double _pairSpacing = 215;
  static const double _trioSpacing = 250;

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height * feetFraction;
    if (backdrop == CharacterBackdrop.waterfront) {
      _paintWaterfrontBackdrop(canvas, size, floorY, timeSeconds);
    } else if (groundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, floorY, size.width, size.height - floorY),
        Paint()..color = groundColor!,
      );
    }

    // Horizontal placement + facing: centred by default; ping-ponging across
    // the stage when locomotion is on, so the body travels over a planted foot.
    var centreX = size.width / 2;
    var flip = false;
    final memberCount = walkingPair
        ? (ensembleScenes.isEmpty ? 2 : ensembleScenes.length + 1)
        : 1;
    if (locomote && clip.locomotes) {
      final drawScale = walkingPair ? scale * _scaleFactor(memberCount) : scale;
      final travelPx =
          scene.locomotionOffset(clip, timeSeconds).abs() * drawScale;
      final groupHalfWidth = walkingPair
          ? _spacing(memberCount) * drawScale * (memberCount - 1) / 2
          : 0.0;
      final margin = _edgeMargin + groupHalfWidth;
      final band = (size.width - 2 * margin).clamp(1.0, size.width);
      final cyc = travelPx % (2 * band);
      final movingRight = cyc <= band;
      final pos = movingRight ? cyc : 2 * band - cyc; // triangle 0..band..0
      centreX = margin + pos;
      // Face the direction of travel. The authored cycle sweeps the planted
      // foot forward in body-space, so the character must be MIRRORED while it
      // walks in the +x direction for the foot to hold still on the floor (the
      // mirror cancels the foot's body-frame sweep against the body's travel).
      flip = movingRight;
    }

    if (walkingPair) {
      final baseMembers = ensembleScenes.isEmpty
          ? [scene, partnerScene ?? scene]
          : [scene, ...ensembleScenes];
      final baseExpressions = [
        for (final i in Iterable<int>.generate(baseMembers.length))
          _expressionAt(i),
      ];
      final baseClips = [
        for (final i in Iterable<int>.generate(baseMembers.length)) _clipAt(i),
      ];
      final leadCentreOrder = clip.name == 'dance' && baseMembers.length == 3;
      final order = leadCentreOrder ? const [1, 0, 2] : null;
      final members = order == null
          ? baseMembers
          : [for (final i in order) baseMembers[i]];
      final expressions = order == null
          ? baseExpressions
          : [for (final i in order) baseExpressions[i]];
      final clips = order == null
          ? baseClips
          : [for (final i in order) baseClips[i]];
      final drawScale = scale * _scaleFactor(members.length);
      final spacing = _spacing(members.length) * drawScale;
      final startX = centreX - spacing * (members.length - 1) / 2;
      final paintOrder = members.length >= 3
          ? const [0, 2, 1]
          : [for (final i in Iterable<int>.generate(members.length)) i];
      for (final i in paintOrder) {
        final memberScene = members[i];
        final memberClip = clips[i];
        final memberScale = drawScale * _roleScale(i, members.length);
        final phaseOffset = synchronousEnsemble
            ? _ensembleMicroTimingOffset(
                i,
                members.length,
                timeSeconds,
                memberClip.duration,
              )
            : memberClip.duration * i / members.length;
        _paintCharacterAt(
          memberScene,
          canvas,
          size,
          clip: memberClip,
          floorY: floorY,
          centreX: startX + spacing * i,
          flip: flip,
          timeSeconds: timeSeconds + phaseOffset,
          expression: expressions[i],
          scale: memberScale,
          feetFraction: feetFraction,
        );
      }
      return;
    }

    _paintCharacterAt(
      scene,
      canvas,
      size,
      clip: clip,
      floorY: floorY,
      centreX: centreX,
      flip: flip,
      timeSeconds: timeSeconds,
      expression: expression,
      scale: scale,
      feetFraction: feetFraction,
    );
  }

  static double _scaleFactor(int memberCount) =>
      memberCount >= 3 ? _trioScaleFactor : _pairScaleFactor;

  static double _spacing(int memberCount) =>
      memberCount >= 3 ? _trioSpacing : _pairSpacing;

  static double _roleScale(int index, int memberCount) {
    if (memberCount < 3) return 1;
    return index == 1 ? 1.06 : 0.96;
  }

  static double _ensembleMicroTimingOffset(
    int index,
    int memberCount,
    double timeSeconds,
    double duration,
  ) {
    if (duration <= 0) return 0;
    if (memberCount >= 3) {
      // Dance crews should breathe during transitions but land their accents
      // together. Side cats drift around the centre lead, then collapse back to
      // exact sync at the main hit phases.
      final p = _cyclePhase(timeSeconds, duration);
      final damping = _transitionDamping(p);
      return switch (index) {
        0 => 0.075 * damping,
        1 => 0,
        2 => -0.065 * damping,
        _ => 0.035 * damping,
      };
    }
    if (index == 0) return 0;
    final cycle = timeSeconds / duration;
    final p = cycle - cycle.floorToDouble();
    final beatWave = math.sin(p * math.pi * 24);
    final halfBeatWave = math.sin(p * math.pi * 48);
    return switch (index % 3) {
      1 => 0.014 * beatWave + 0.006 * halfBeatWave,
      2 => -0.012 * beatWave + 0.005 * halfBeatWave,
      _ => 0.006 * beatWave - 0.004 * halfBeatWave,
    };
  }

  static double _cyclePhase(double timeSeconds, double duration) {
    final cycle = timeSeconds / duration;
    final p = cycle - cycle.floorToDouble();
    return p < 0 ? p + 1 : p;
  }

  static double _transitionDamping(double p) {
    const accentPhases = [
      0.0,
      1 / 12,
      3 / 12,
      5 / 12,
      7 / 12,
      9 / 12,
      11 / 12,
    ];
    var nearest = 1.0;
    for (final accent in accentPhases) {
      final direct = (p - accent).abs();
      final wrapped = (1 - direct).abs();
      nearest = math.min(nearest, math.min(direct, wrapped));
    }
    const syncWindow = 1.5 / 72;
    const looseWindow = 4.0 / 72;
    if (nearest <= syncWindow) return 0;
    if (nearest >= looseWindow) return 1;
    return (nearest - syncWindow) / (looseWindow - syncWindow);
  }

  void _paintWaterfrontBackdrop(
    Canvas canvas,
    Size size,
    double floorY,
    double timeSeconds,
  ) {
    final w = size.width;
    final h = size.height;
    final horizonY = floorY * 0.48;
    final waterBottom = floorY + 2;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizonY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, horizonY),
          const [Color(0xFF95C9F1), Color(0xFFD8F0FF)],
        ),
    );

    _paintCloud(canvas, w * 0.14, h * 0.13, w * 0.08);
    _paintCloud(canvas, w * 0.82, h * 0.11, w * 0.06);
    _paintDistantSkyline(canvas, w, horizonY);

    canvas
      ..drawRect(
        Rect.fromLTWH(0, horizonY - 8, w, 14),
        Paint()..color = const Color(0x334B8065),
      )
      ..drawRect(
        Rect.fromLTRB(0, horizonY, w, waterBottom),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, horizonY),
            Offset(0, waterBottom),
            const [Color(0xFF55A6C9), Color(0xFF256D8E)],
          ),
      );
    _paintWaves(canvas, w, horizonY, waterBottom, timeSeconds);
    _paintBridge(canvas, w, horizonY, waterBottom);
    _paintYacht(
      canvas,
      w * (0.68 + 0.015 * math.sin(timeSeconds * 0.7)),
      horizonY + (waterBottom - horizonY) * 0.32,
      w * 0.12,
    );
    _paintPlane(
      canvas,
      size,
      timeSeconds,
      y: h * 0.18 + 7 * math.sin(timeSeconds * 1.1),
    );

    final deckTop = floorY - 16;
    canvas.drawRect(
      Rect.fromLTRB(0, deckTop, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, deckTop),
          Offset(0, h),
          const [Color(0xFFB8A986), Color(0xFF7D715D)],
        ),
    );
    for (var x = -30.0; x < w + 40; x += 72) {
      canvas.drawRect(
        Rect.fromLTWH(x, deckTop + 6, 46, 3),
        Paint()..color = const Color(0x665E5548),
      );
    }
    canvas.drawLine(
      Offset(0, deckTop),
      Offset(w, deckTop),
      Paint()
        ..color = const Color(0xAAE7D7B1)
        ..strokeWidth = 2,
    );
  }

  void _paintDistantSkyline(Canvas canvas, double width, double horizonY) {
    final paint = Paint()..color = const Color(0x66436772);
    final highlight = Paint()..color = const Color(0x33E6F4F7);
    final buildings = [
      (x: 0.08, width: 0.026, height: 0.16),
      (x: 0.12, width: 0.018, height: 0.11),
      (x: 0.17, width: 0.034, height: 0.2),
      (x: 0.24, width: 0.022, height: 0.14),
      (x: 0.31, width: 0.04, height: 0.24),
      (x: 0.38, width: 0.024, height: 0.13),
      (x: 0.48, width: 0.028, height: 0.19),
      (x: 0.54, width: 0.02, height: 0.3),
      (x: 0.61, width: 0.046, height: 0.22),
      (x: 0.69, width: 0.026, height: 0.15),
      (x: 0.76, width: 0.038, height: 0.26),
      (x: 0.84, width: 0.024, height: 0.18),
    ];

    for (final building in buildings) {
      final left = width * building.x;
      final buildingWidth = width * building.width;
      final buildingHeight = horizonY * building.height;
      final rect = Rect.fromLTWH(
        left,
        horizonY - buildingHeight,
        buildingWidth,
        buildingHeight + 5,
      );
      canvas
        ..drawRect(rect, paint)
        ..drawRect(
          Rect.fromLTWH(
            rect.left + buildingWidth * 0.18,
            rect.top + buildingHeight * 0.16,
            math.max(1, buildingWidth * 0.12),
            buildingHeight * 0.62,
          ),
          highlight,
        );
    }

    canvas
      ..drawCircle(
        Offset(width * 0.43, horizonY - horizonY * 0.1),
        width * 0.018,
        paint,
      )
      ..drawRect(
        Rect.fromLTWH(width * 0.405, horizonY - 3, width * 0.05, 7),
        paint,
      );
  }

  void _paintBridge(
    Canvas canvas,
    double width,
    double horizonY,
    double waterBottom,
  ) {
    final bridgeY = horizonY + (waterBottom - horizonY) * 0.18;
    final deckPaint = Paint()
      ..color = const Color(0xA04A686D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, width * 0.0045)
      ..strokeCap = StrokeCap.round;
    final railPaint = Paint()
      ..color = const Color(0x88D5ECEE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, width * 0.0016)
      ..strokeCap = StrokeCap.round;
    final pierPaint = Paint()
      ..color = const Color(0x804A686D)
      ..strokeWidth = math.max(1, width * 0.0018)
      ..strokeCap = StrokeCap.round;

    final deck = Path()
      ..moveTo(-width * 0.04, bridgeY + 12)
      ..cubicTo(
        width * 0.18,
        bridgeY + 2,
        width * 0.44,
        bridgeY - 7,
        width * 1.04,
        bridgeY - 3,
      );
    canvas.drawPath(deck, deckPaint);

    final rail = Path()
      ..moveTo(-width * 0.04, bridgeY + 7)
      ..cubicTo(
        width * 0.18,
        bridgeY - 3,
        width * 0.44,
        bridgeY - 12,
        width * 1.04,
        bridgeY - 8,
      );
    canvas.drawPath(rail, railPaint);

    for (var x = width * 0.04; x < width; x += width * 0.105) {
      final localCurve = math.sin((x / width) * math.pi);
      final top = bridgeY + 8 - localCurve * 12;
      canvas
        ..drawLine(
          Offset(x, top),
          Offset(x - width * 0.012, waterBottom - 12),
          pierPaint,
        )
        ..drawLine(
          Offset(x + width * 0.018, top + 1),
          Offset(x + width * 0.008, waterBottom - 10),
          pierPaint,
        );
    }
  }

  void _paintCloud(Canvas canvas, double x, double y, double r) {
    final paint = Paint()..color = const Color(0xCFFFFFFF);
    canvas
      ..drawCircle(Offset(x, y), r * 0.45, paint)
      ..drawCircle(Offset(x + r * 0.42, y - r * 0.08), r * 0.55, paint)
      ..drawCircle(Offset(x + r * 0.92, y + r * 0.06), r * 0.38, paint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - r * 0.4, y, r * 1.65, r * 0.48),
          Radius.circular(r * 0.24),
        ),
        paint,
      );
  }

  void _paintWaves(
    Canvas canvas,
    double width,
    double top,
    double bottom,
    double timeSeconds,
  ) {
    final wavePaint = Paint()
      ..color = const Color(0x6DD9F7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    const rows = 6;
    for (var row = 0; row < rows; row++) {
      final y = top + 18 + row * (bottom - top - 24) / rows;
      final phase = (timeSeconds * (18 + row * 2) + row * 31) % 48;
      for (var x = -60.0 - phase; x < width + 80; x += 64) {
        final path = Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 14, y - 5, x + 28, y)
          ..quadraticBezierTo(x + 42, y + 4, x + 56, y);
        canvas.drawPath(path, wavePaint);
      }
    }
  }

  void _paintYacht(Canvas canvas, double x, double y, double size) {
    final hull = Path()
      ..moveTo(x - size * 0.42, y + size * 0.14)
      ..lineTo(x + size * 0.44, y + size * 0.14)
      ..lineTo(x + size * 0.24, y + size * 0.32)
      ..lineTo(x - size * 0.28, y + size * 0.32)
      ..close();
    canvas
      ..drawPath(hull, Paint()..color = const Color(0xFFEFF4F7))
      ..drawPath(
        hull,
        Paint()
          ..color = const Color(0x882B4050)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    final mastPaint = Paint()
      ..color = const Color(0xFF6C5A48)
      ..strokeWidth = math.max(1, size * 0.025);
    canvas.drawLine(
      Offset(x - size * 0.05, y + size * 0.13),
      Offset(x - size * 0.05, y - size * 0.52),
      mastPaint,
    );

    final sail = Path()
      ..moveTo(x - size * 0.04, y - size * 0.48)
      ..lineTo(x - size * 0.04, y + size * 0.1)
      ..lineTo(x + size * 0.34, y + size * 0.08)
      ..close();
    canvas
      ..drawPath(sail, Paint()..color = const Color(0xFFE9FBFF))
      ..drawPath(
        sail,
        Paint()
          ..color = const Color(0x66588CA4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  void _paintPlane(
    Canvas canvas,
    Size size,
    double timeSeconds, {
    required double y,
  }) {
    final w = size.width;
    final scale = (w / 760).clamp(0.55, 1.0);
    final planeX = (timeSeconds * 38 + w * 0.52) % (w + 210) - 155;
    final planeY = y;
    final bodyPaint = Paint()..color = const Color(0xFFE9E2CD);
    final trimPaint = Paint()..color = const Color(0xFFBA6552);
    final linePaint = Paint()
      ..color = const Color(0xAA5D5147)
      ..strokeWidth = 1.1 * scale
      ..style = PaintingStyle.stroke;

    final sx = 46.0 * scale;
    final sy = 18.0 * scale;
    canvas
      ..save()
      ..translate(planeX, planeY)
      ..drawLine(
        Offset(-sx * 1.55, sy * 0.12),
        Offset(-sx * 0.55, sy * 0.08),
        Paint()
          ..color = const Color(0xAAE7D7C0)
          ..strokeWidth = 1.2 * scale,
      );
    _paintBanner(canvas, Offset(-sx * 2.18, sy * 0.23), scale);

    final fuselage = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: sx, height: sy),
      Radius.circular(sy * 0.45),
    );
    canvas
      ..drawRRect(fuselage, bodyPaint)
      ..drawRRect(fuselage, linePaint)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(sx * 0.04, 0),
          width: sx * 0.42,
          height: sy * 0.2,
        ),
        trimPaint,
      );

    final wing = Path()
      ..moveTo(-sx * 0.1, -sy * 0.08)
      ..lineTo(sx * 0.3, -sy * 1.15)
      ..lineTo(sx * 0.48, -sy * 1.05)
      ..lineTo(sx * 0.2, -sy * 0.04)
      ..close();
    canvas
      ..drawPath(wing, Paint()..color = const Color(0xFFEFE8D9))
      ..drawPath(wing, linePaint);

    final tail = Path()
      ..moveTo(-sx * 0.42, -sy * 0.08)
      ..lineTo(-sx * 0.66, -sy * 0.75)
      ..lineTo(-sx * 0.54, -sy * 0.06)
      ..close();
    canvas
      ..drawPath(tail, Paint()..color = const Color(0xFFDBD4C2))
      ..drawPath(tail, linePaint);

    final propX = sx * 0.54;
    canvas.drawCircle(Offset(propX, 0), 2.4 * scale, trimPaint);
    final propAngle = timeSeconds * math.pi * 10;
    canvas
      ..save()
      ..translate(propX + 4 * scale, 0)
      ..rotate(propAngle)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 4 * scale,
          height: 28 * scale,
        ),
        Paint()..color = const Color(0x99F7FAFF),
      )
      ..rotate(math.pi / 2)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 4 * scale,
          height: 28 * scale,
        ),
        Paint()..color = const Color(0x77F7FAFF),
      )
      ..restore()
      ..restore();
  }

  void _paintBanner(Canvas canvas, Offset origin, double scale) {
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy - 8 * scale,
      56 * scale,
      16 * scale,
    );
    final banner = RRect.fromRectAndRadius(rect, Radius.circular(3 * scale));
    canvas
      ..drawRRect(banner, Paint()..color = const Color(0xDFF8F0D7))
      ..drawRRect(
        banner,
        Paint()
          ..color = const Color(0x885E5548)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * scale,
      );
    TextPainter(
        text: TextSpan(
          text: 'Lotti',
          style: TextStyle(
            color: const Color(0xFF6D4B37),
            fontSize: 10 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: rect.width)
      ..paint(
        canvas,
        Offset(rect.left + 14 * scale, rect.top + 2 * scale),
      );
  }

  Expression _expressionAt(int index) => index < ensembleExpressions.length
      ? ensembleExpressions[index]
      : expression;

  Clip _clipAt(int index) =>
      index < ensembleClips.length ? ensembleClips[index] : clip;

  void _paintCharacterAt(
    CharacterScene drawScene,
    Canvas canvas,
    Size size, {
    required Clip clip,
    required double floorY,
    required double centreX,
    required bool flip,
    required double timeSeconds,
    required Expression expression,
    required double scale,
    required double feetFraction,
  }) {
    final base = groundedBase(
      size,
      centreX: centreX,
      scale: scale,
      feetFraction: feetFraction,
      feetOffset: drawScene.restFeetOffset,
      flip: flip,
    );
    final frame = drawScene.frameAt(
      clip: clip,
      timeSeconds: timeSeconds,
      expression: expression,
      base: base,
      eyeOpenScale: eyeOpenScale,
    );

    _paintContactShadows(
      canvas,
      floorY,
      centreX,
      scale,
      frame,
      timeSeconds,
      drawScene,
      clip,
    );

    _renderer.paint(canvas, drawScene.rig, frame.world, frame.face);
  }

  void _paintContactShadows(
    Canvas canvas,
    double floorY,
    double centreX,
    double scale,
    CharacterFrame frame,
    double timeSeconds,
    CharacterScene drawScene,
    Clip clip,
  ) {
    final contactBone = _activeGroundBone(clip, timeSeconds);
    if (contactBone == null) {
      _paintBodyShadow(canvas, floorY, centreX, scale, frame, drawScene);
      return;
    }

    final transform = frame.world[contactBone];
    final drawable = drawScene.rig.bone(contactBone)?.drawable;
    if (transform == null || drawable == null) return;
    final bottom = transform.transformPoint(
      drawable.dx,
      drawable.dy + drawable.height / 2,
    );
    final lift = ((floorY - bottom.y) / (90 * scale)).clamp(0.0, 1.0);
    final shadowW = 54 * scale * (1 - 0.35 * lift);
    final baseAlpha = (shadowColor.a * 255.0).round();
    final shadowAlpha = (baseAlpha * 1.2 * (1 - 0.75 * lift)).round().clamp(
      0,
      255,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bottom.x, floorY + 2),
        width: shadowW,
        height: shadowW * 0.16,
      ),
      Paint()..color = shadowColor.withAlpha(shadowAlpha),
    );
  }

  String? _activeGroundBone(Clip clip, double timeSeconds) {
    final spans = clip.contactSpans.isNotEmpty
        ? clip.contactSpans
        : clip.groundSpans;
    if (spans.isEmpty || clip.duration <= 0) return null;
    final raw = timeSeconds / clip.duration;
    final p = clip.loop ? raw - raw.floorToDouble() : raw.clamp(0.0, 1.0);
    for (final span in spans) {
      if (p >= span.start && p < span.end) return span.bone;
    }
    return spans.last.bone;
  }

  void _paintBodyShadow(
    Canvas canvas,
    double floorY,
    double centreX,
    double scale,
    CharacterFrame frame,
    CharacterScene drawScene,
  ) {
    final footY = drawScene.lowestDrawnY(frame.world);
    final lift = ((floorY - footY) / (90 * scale)).clamp(0.0, 1.0);
    final shadowW = 78 * scale * (1 - 0.45 * lift);
    final shadowAlpha = ((shadowColor.a * 255.0).round() * (1 - 0.7 * lift))
        .round()
        .clamp(0, 255);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centreX, floorY),
        width: shadowW,
        height: shadowW * 0.16,
      ),
      Paint()..color = shadowColor.withAlpha(shadowAlpha),
    );
  }

  @override
  bool shouldRepaint(CharacterPainter old) =>
      old.timeSeconds != timeSeconds ||
      old.clip != clip ||
      old.expression != expression ||
      old.scene != scene ||
      old.scale != scale ||
      old.eyeOpenScale != eyeOpenScale ||
      old.feetFraction != feetFraction ||
      old.groundColor != groundColor ||
      old.shadowColor != shadowColor ||
      old.backdrop != backdrop ||
      old.locomote != locomote ||
      old.walkingPair != walkingPair ||
      old.partnerScene != partnerScene ||
      old.ensembleScenes != ensembleScenes ||
      old.ensembleExpressions != ensembleExpressions ||
      old.ensembleClips != ensembleClips ||
      old.synchronousEnsemble != synchronousEnsemble ||
      old._renderer != _renderer;
}
