import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';

enum CharacterBackdrop { none, waterfront }

const kCharacterWaterfrontBackdropAsset =
    'assets/images/character/lagos_waterfront.png';
const kCharacterWaterfrontCloudsAsset =
    'assets/images/character/lagos_clouds_alpha.png';
const kCharacterWaterfrontWavesAsset =
    'assets/images/character/lagos_wave_glints_alpha.png';

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
  double? floorY,
  double feetOffset = 0,
  bool flip = false,
}) => Affine2D.translation(
  centreX,
  (floorY ?? size.height * feetFraction) - feetOffset * scale,
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
    this.backdropImage,
    this.backdropCloudsImage,
    this.backdropWavesImage,
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

  /// Decoded image plate for [CharacterBackdrop.waterfront].
  final ui.Image? backdropImage;

  /// Transparent drifting cloud overlay for [CharacterBackdrop.waterfront].
  final ui.Image? backdropCloudsImage;

  /// Transparent lagoon shimmer overlay for [CharacterBackdrop.waterfront].
  final ui.Image? backdropWavesImage;

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
  static const double _trioScaleFactor = 0.49;
  static const double _pairSpacing = 215;
  static const double _trioSpacing = 236;

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height * feetFraction;
    final memberCount = walkingPair
        ? (ensembleScenes.isEmpty ? 2 : ensembleScenes.length + 1)
        : 1;
    final sceneCamera = walkingPair && clip.name == 'dance' && memberCount == 3
        ? _danceCamera(timeSeconds, clip.duration)
        : (zoom: 1.0, dx: 0.0, dy: 0.0);

    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    _applySceneCamera(canvas, size, sceneCamera);

    if (backdrop == CharacterBackdrop.waterfront) {
      _paintWaterfrontBackdrop(
        canvas,
        size,
        floorY,
        timeSeconds,
        backdropImage,
        backdropCloudsImage,
        backdropWavesImage,
      );
      _paintWaterfrontAtmosphere(canvas, size, floorY);
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
      final groupCentreX = centreX;
      final groupFloorY = floorY;
      final startX = groupCentreX - spacing * (members.length - 1) / 2;
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
        final formation = leadCentreOrder
            ? _danceFormationOffset(
                i,
                members.length,
                timeSeconds,
                memberClip.duration,
              )
            : (dx: 0.0, dy: 0.0);
        _paintCharacterAt(
          memberScene,
          canvas,
          size,
          clip: memberClip,
          floorY:
              groupFloorY +
              (_roleFloorOffset(i, members.length) + formation.dy) * drawScale,
          centreX: startX + spacing * i + formation.dx * drawScale,
          flip: flip,
          timeSeconds: timeSeconds + phaseOffset,
          expression: expressions[i],
          scale: memberScale,
          feetFraction: feetFraction,
        );
      }
      canvas.restore();
      if (backdrop == CharacterBackdrop.waterfront) {
        _paintWaterfrontDirtyGrade(canvas, size, floorY);
        _paintWaterfrontForegroundGrime(canvas, size, floorY, timeSeconds);
        _paintTopSafeSky(canvas, size);
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
    canvas.restore();
    if (backdrop == CharacterBackdrop.waterfront) {
      _paintWaterfrontDirtyGrade(canvas, size, floorY);
      _paintWaterfrontForegroundGrime(canvas, size, floorY, timeSeconds);
      _paintTopSafeSky(canvas, size);
    }
  }

  void _paintWaterfrontDirtyGrade(Canvas canvas, Size size, double floorY) {
    _paintDeckGrime(canvas, size, floorY);
    canvas
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.multiply
          ..color = const Color(0x6B263D3F),
      )
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.overlay
          ..color = const Color(0x2A1B1A16),
      )
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.color
          ..color = const Color(0x2420312F),
      )
      ..drawRect(
        Rect.fromLTRB(0, size.height * 0.52, size.width, size.height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, size.height * 0.52),
            Offset(0, size.height),
            const [Color(0x00211D18), Color(0x7A201B16)],
          ),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, floorY - size.height * 0.12),
          width: size.width * 1.18,
          height: size.height * 0.46,
        ),
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.5, floorY - size.height * 0.12),
            size.width * 0.58,
            const [Color(0x00191E20), Color(0x68131617)],
          ),
      );
  }

  void _paintWaterfrontForegroundGrime(
    Canvas canvas,
    Size size,
    double floorY,
    double timeSeconds,
  ) {
    final cablePaint = Paint()
      ..blendMode = BlendMode.multiply
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, size.width * 0.003)
      ..color = const Color(0x8A171512);
    final sway = math.sin(timeSeconds * 0.7) * size.height * 0.004;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.12 + i * 0.045) + sway * (i + 1);
      final path = Path()
        ..moveTo(-size.width * 0.05, y)
        ..quadraticBezierTo(
          size.width * (0.34 + i * 0.08),
          y + size.height * (0.026 + i * 0.008),
          size.width * 1.05,
          y - size.height * (0.018 - i * 0.004),
        );
      canvas.drawPath(path, cablePaint);
    }

    final postPaint = Paint()
      ..blendMode = BlendMode.multiply
      ..shader = ui.Gradient.linear(
        Offset(0, floorY - size.height * 0.28),
        Offset(0, size.height),
        const [Color(0xBE1B1711), Color(0xF0181511)],
      );
    for (final x in [
      -size.width * 0.025,
      size.width * 0.965,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            floorY - size.height * 0.24,
            size.width * 0.035,
            size.height * 0.38,
          ),
          Radius.circular(size.width * 0.008),
        ),
        postPaint,
      );
    }

    final puddlePaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, floorY + size.height * 0.07),
        size.width * 0.48,
        const [Color(0x2D546461), Color(0x00303A38)],
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, floorY + size.height * 0.07),
        width: size.width * 0.74,
        height: size.height * 0.12,
      ),
      puddlePaint,
    );

    final grainPaint = Paint()
      ..blendMode = BlendMode.multiply
      ..strokeWidth = 1
      ..color = const Color(0x1C15120F);
    for (var i = 0; i < 72; i++) {
      final x = size.width * ((i * 0.619 + 0.13) % 1);
      final y = size.height * ((i * 0.347 + 0.08) % 1);
      final len = size.width * (0.004 + 0.008 * ((i * 11) % 7) / 6);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + len, y + len * 0.28),
        grainPaint,
      );
    }
  }

  void _paintDeckGrime(Canvas canvas, Size size, double floorY) {
    final deckTop = size.height * 0.63;
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, deckTop, size.width, size.height));
    final stainPaint = Paint()
      ..blendMode = BlendMode.multiply
      ..color = const Color(0x24201713);
    for (var i = 0; i < 18; i++) {
      final x = size.width * ((i * 0.137 + 0.09) % 1);
      final y = deckTop + (floorY - deckTop) * ((i * 0.173 + 0.21) % 1);
      final w = size.width * (0.018 + 0.018 * ((i * 7) % 5) / 4);
      final h = size.height * (0.006 + 0.008 * ((i * 5 + 2) % 6) / 5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: w, height: h),
        stainPaint,
      );
    }

    final scratchPaint = Paint()
      ..blendMode = BlendMode.multiply
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.7, size.width * 0.001)
      ..color = const Color(0x34251B12);
    for (var i = 0; i < 26; i++) {
      final startX = size.width * ((i * 0.071 + 0.04) % 1);
      final y = deckTop + (size.height - deckTop) * ((i * 0.113 + 0.17) % 1);
      final length = size.width * (0.035 + 0.05 * ((i * 3) % 7) / 6);
      final drift = size.height * (0.003 + 0.009 * ((i * 11) % 5) / 4);
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + length, y + drift),
        scratchPaint,
      );
    }
    canvas.restore();
  }

  void _paintTopSafeSky(Canvas canvas, Size size) {
    final height = size.height * 0.085;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, height),
          const [
            Color(0xFF566A6F),
            Color(0xCC61757A),
            Color(0x00566A6F),
          ],
          const [0, 0.46, 1],
        ),
    );
  }

  static void _applySceneCamera(
    Canvas canvas,
    Size size,
    ({double zoom, double dx, double dy}) camera,
  ) {
    if (camera.zoom == 1 && camera.dx == 0 && camera.dy == 0) return;
    final pivot = Offset(size.width / 2, size.height * 0.56);
    final maxDx = size.width * (camera.zoom - 1) / 2;
    final maxDy = size.height * (camera.zoom - 1) / 2;
    final dx = camera.dx.clamp(-maxDx, maxDx);
    final dy = camera.dy.clamp(-maxDy, maxDy);
    canvas
      ..translate(pivot.dx + dx, pivot.dy + dy)
      ..scale(camera.zoom)
      ..translate(-pivot.dx, -pivot.dy);
  }

  static double _scaleFactor(int memberCount) =>
      memberCount >= 3 ? _trioScaleFactor : _pairScaleFactor;

  static double _spacing(int memberCount) =>
      memberCount >= 3 ? _trioSpacing : _pairSpacing;

  static double _roleScale(int index, int memberCount) {
    if (memberCount < 3) return 1;
    return index == 1 ? 1.12 : 0.9;
  }

  static double _roleFloorOffset(int index, int memberCount) {
    if (memberCount < 3) return 0;
    return index == 1 ? -16 : -48;
  }

  static ({double zoom, double dx, double dy}) _danceCamera(
    double timeSeconds,
    double duration,
  ) {
    final p = _cyclePhase(timeSeconds, duration);
    return (
      zoom: _smoothKeys(p, const [
        (p: 0, v: 1.0),
        (p: 1 / 8, v: 1.08),
        (p: 1 / 4, v: 1.13),
        (p: 1 / 2, v: 1.15),
        (p: 5 / 8, v: 1.18),
        (p: 3 / 4, v: 1.13),
        (p: 29 / 32, v: 1.035),
        (p: 1, v: 1.0),
      ]),
      dx: _smoothKeys(p, const [
        (p: 0, v: 0.0),
        (p: 1 / 8, v: -8.0),
        (p: 1 / 4, v: -18.0),
        (p: 1 / 2, v: 30.0),
        (p: 5 / 8, v: 24.0),
        (p: 3 / 4, v: 16.0),
        (p: 29 / 32, v: 4.0),
        (p: 1, v: 0.0),
      ]),
      dy: _smoothKeys(p, const [
        (p: 0, v: 0.0),
        (p: 1 / 4, v: -6.0),
        (p: 1 / 2, v: -10.0),
        (p: 5 / 8, v: -12.0),
        (p: 3 / 4, v: -7.0),
        (p: 29 / 32, v: 0.0),
        (p: 1, v: 0.0),
      ]),
    );
  }

  static ({double dx, double dy}) _danceFormationOffset(
    int index,
    int memberCount,
    double timeSeconds,
    double duration,
  ) {
    if (memberCount < 3) return (dx: 0, dy: 0);
    final p = _cyclePhase(timeSeconds, duration);
    final breathe = math.sin(2 * math.pi * (p * 3 + 0.15));
    final callResponse = math.sin(2 * math.pi * (p * 2 - 0.08));
    final leadCall = _pulse(p, 1 / 16, 1 / 4);
    final sideAnswer = _pulse(p, 5 / 16, 1 / 2);
    final blackSolo = _pulse(p, 3 / 8, 1 / 2);
    final wideV = _pulse(p, 1 / 2, 3 / 4);
    final centreFeature = _pulse(p, 17 / 32, 23 / 32);
    final ensembleHit = _pulse(p, 23 / 32, 27 / 32);
    final returnLock = _smoothUnit((p - 25 / 32) / (4 / 32));
    return switch (index) {
      0 => (
        dx:
            (-22 - 10 * breathe - 18 * sideAnswer - 16 * wideV) *
            (1 - returnLock),
        dy:
            -10 +
            3 * callResponse -
            8 * leadCall -
            12 * sideAnswer -
            9 * wideV +
            7 * ensembleHit,
      ),
      1 => (
        dx: 4 * leadCall - 4 * ensembleHit,
        dy:
            12 -
            12 * leadCall -
            5 * blackSolo +
            7 * wideV +
            12 * centreFeature -
            8 * ensembleHit,
      ),
      2 => (
        dx:
            (22 +
                10 * breathe +
                16 * sideAnswer +
                22 * blackSolo +
                16 * wideV) *
            (1 - returnLock),
        dy:
            -10 -
            3 * callResponse -
            5 * leadCall -
            10 * sideAnswer +
            18 * blackSolo -
            9 * wideV +
            7 * ensembleHit,
      ),
      _ => (dx: 0, dy: 0),
    };
  }

  static double _smoothKeys(
    double p,
    List<({double p, double v})> keys,
  ) {
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i];
      final b = keys[i + 1];
      if (p >= a.p && p <= b.p) {
        final t = _smoothUnit((p - a.p) / (b.p - a.p));
        return a.v + (b.v - a.v) * t;
      }
    }
    return keys.last.v;
  }

  static double _pulse(double p, double start, double end) {
    final mid = (start + end) / 2;
    if (p < start || p > end) return 0;
    if (p <= mid) return _smoothUnit((p - start) / (mid - start));
    return 1 - _smoothUnit((p - mid) / (end - mid));
  }

  static double _smoothUnit(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
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
      // together. Side cats drift around the centre lead, swap tiny lead/trail
      // moments inside the phrase, then collapse back to sync at the hits.
      final p = _cyclePhase(timeSeconds, duration);
      final damping = _transitionDamping(p);
      final frame = duration / 32;
      final phraseDrift = math.sin(2 * math.pi * (p * 2 + index * 0.37));
      final beatDrift = math.sin(2 * math.pi * (p * 8 + index * 0.19));
      return switch (index) {
        0 => (-0.45 * frame + 0.08 * frame * phraseDrift) * damping,
        1 => 0,
        2 => (0.45 * frame + 0.08 * frame * beatDrift) * damping,
        _ => (0.12 * frame * phraseDrift) * damping,
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
      1 / 8,
      1 / 4,
      3 / 8,
      1 / 2,
      5 / 8,
      3 / 4,
      7 / 8,
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
    ui.Image? backdropImage,
    ui.Image? backdropCloudsImage,
    ui.Image? backdropWavesImage,
  ) {
    if (backdropImage == null) return;
    _paintWaterfrontPlate(
      canvas,
      size,
      floorY,
      timeSeconds,
      backdropImage,
      backdropCloudsImage,
      backdropWavesImage,
    );
  }

  void _paintWaterfrontAtmosphere(Canvas canvas, Size size, double floorY) {
    final deckTop = size.height * 0.63;
    canvas
      ..drawRect(
        Rect.fromLTRB(0, 0, size.width, deckTop),
        Paint()..color = const Color(0x4F203639),
      )
      ..drawRect(
        Rect.fromLTRB(0, deckTop, size.width, floorY + 18),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, deckTop),
            Offset(0, floorY + 18),
            const [Color(0x001B1713), Color(0x7A1A1612)],
          ),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, floorY - size.height * 0.07),
          width: size.width * 0.86,
          height: size.height * 0.2,
        ),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.5, floorY - size.height * 0.07),
            size.width * 0.43,
            const [Color(0x30332621), Color(0x00312621)],
          ),
      );
    _paintDistanceHaze(canvas, size, deckTop);
  }

  void _paintDistanceHaze(Canvas canvas, Size size, double deckTop) {
    final horizonY = size.height * 0.43;
    final skylineTop = size.height * 0.24;
    final waterFarY = size.height * 0.52;
    final farSceneClip = Rect.fromLTRB(
      0,
      skylineTop,
      size.width * 0.74,
      deckTop,
    );

    canvas
      // Atmospheric perspective: far forms lose contrast/saturation and shift
      // toward cool sky colour, while humid city haze adds a warm gray smog band
      // near the horizon.
      ..drawRect(
        farSceneClip,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, skylineTop),
            Offset(0, deckTop),
            const [
              Color(0x00304042),
              Color(0x78647776),
              Color(0xA8645E55),
              Color(0x60475B5D),
              Color(0x001B2426),
            ],
            const [0, 0.3, 0.5, 0.74, 1],
          ),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.36, horizonY),
          width: size.width * 0.92,
          height: size.height * 0.24,
        ),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.36, horizonY),
            size.width * 0.46,
            const [Color(0xA4645C52), Color(0x00645C52)],
          ),
      )
      ..drawRect(
        Rect.fromLTRB(0, waterFarY, size.width * 0.7, deckTop),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, waterFarY),
            Offset(0, deckTop),
            const [Color(0x56506263), Color(0x00506263)],
          ),
      );
  }

  void _paintWaterfrontPlate(
    Canvas canvas,
    Size size,
    double floorY,
    double timeSeconds,
    ui.Image image,
    ui.Image? cloudsImage,
    ui.Image? wavesImage,
  ) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );

    if (cloudsImage != null) {
      _paintScrollingPlateMask(
        canvas,
        size,
        cloudsImage,
        clip: Rect.fromLTRB(
          size.width * 0.18,
          0,
          size.width * 0.78,
          size.height * 0.32,
        ),
        offsetX: timeSeconds * 7,
        fillPaintFor: (rect) => Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, 0),
            Offset(rect.right, size.height * 0.32),
            const [Color(0x6CC8C6B7), Color(0x365F7477)],
          ),
      );
    }

    if (wavesImage != null) {
      final waveClip = Rect.fromLTRB(
        0,
        size.height * 0.5,
        size.width * 0.6,
        size.height * 0.61,
      );
      _paintScrollingPlateMask(
        canvas,
        size,
        wavesImage,
        clip: waveClip,
        offsetX: timeSeconds * 42,
        fillPaintFor: (rect) => Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, waveClip.top),
            Offset(rect.right, waveClip.bottom),
            const [
              Color(0x00FFFFFF),
              Color(0x62D8D1BC),
              Color(0x385F9DA3),
              Color(0x00FFFFFF),
            ],
            const [0, 0.42, 0.68, 1],
          ),
      );
      _paintScrollingPlateMask(
        canvas,
        size,
        wavesImage,
        clip: waveClip,
        offsetX: timeSeconds * 27 + size.width * 0.36,
        offsetY: size.height * 0.012,
        fillPaintFor: (rect) => Paint()
          ..shader = ui.Gradient.linear(
            Offset(rect.left, waveClip.top),
            Offset(rect.right, waveClip.bottom),
            const [
              Color(0x00FFFFFF),
              Color(0x2ED8D0BE),
              Color(0x225C8589),
              Color(0x00FFFFFF),
            ],
            const [0, 0.48, 0.72, 1],
          ),
      );
    }
  }

  void _paintScrollingPlateMask(
    Canvas canvas,
    Size size,
    ui.Image mask, {
    required Rect clip,
    required double offsetX,
    required Paint Function(Rect rect) fillPaintFor,
    double offsetY = 0,
  }) {
    final phase = offsetX % size.width;
    canvas
      ..save()
      ..clipRect(clip);
    for (final left in [-phase, size.width - phase]) {
      final rect = Rect.fromLTWH(left, offsetY, size.width, size.height);
      canvas
        ..saveLayer(clip, Paint())
        ..drawRect(rect, fillPaintFor(rect))
        ..drawImageRect(
          mask,
          Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
          rect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..filterQuality = FilterQuality.high,
        )
        ..restore();
    }
    canvas.restore();
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
      floorY: floorY,
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
    final groundedFrame = _floorPinnedPerformanceFrame(
      frame,
      drawScene,
      clip,
      timeSeconds,
      expression,
      base,
      floorY,
    );

    _paintContactShadows(
      canvas,
      floorY,
      centreX,
      scale,
      groundedFrame,
      timeSeconds,
      drawScene,
      clip,
    );

    _renderer.paint(
      canvas,
      drawScene.rig,
      groundedFrame.world,
      groundedFrame.face,
    );
  }

  CharacterFrame _floorPinnedPerformanceFrame(
    CharacterFrame frame,
    CharacterScene drawScene,
    Clip clip,
    double timeSeconds,
    Expression expression,
    Affine2D base,
    double floorY,
  ) {
    if (clip.locomotes) return frame;
    final contactSpan = _activeGroundSpan(clip, timeSeconds);
    if (contactSpan == null) return frame;
    final transform = frame.world[contactSpan.bone];
    final drawable = drawScene.rig.bone(contactSpan.bone)?.drawable;
    if (transform == null || drawable == null) return frame;

    final targetFrame = drawScene.frameAt(
      clip: clip,
      timeSeconds: _spanStartTime(clip, timeSeconds, contactSpan.start),
      expression: expression,
      base: base,
      eyeOpenScale: eyeOpenScale,
    );
    final targetTransform = targetFrame.world[contactSpan.bone];
    final targetDrawable = drawScene.rig.bone(contactSpan.bone)?.drawable;
    final visualBottom = _drawableVisualBottom(transform, drawable);
    final currentContact = _drawableFootContact(transform, drawable);
    final targetContact = targetTransform == null || targetDrawable == null
        ? currentContact
        : _drawableFootContact(targetTransform, targetDrawable);
    final dx = targetContact.x - currentContact.x;
    final dy = floorY - visualBottom;
    if (dx.abs() < 0.2 && dy.abs() < 0.2) return frame;
    final correction = Affine2D.translation(dx, dy);
    return CharacterFrame(
      world: {
        for (final entry in frame.world.entries)
          entry.key: correction.multiply(entry.value),
      },
      face: frame.face,
      locomotionX: frame.locomotionX,
    );
  }

  static double _spanStartTime(Clip clip, double timeSeconds, double start) {
    if (clip.duration <= 0) return timeSeconds;
    if (!clip.loop) return start * clip.duration;
    final raw = timeSeconds / clip.duration;
    return (raw.floorToDouble() + start) * clip.duration;
  }

  static ({double x, double y}) _drawableFootContact(
    Affine2D transform,
    BoneDrawable drawable,
  ) => transform.transformPoint(
    drawable.dx,
    drawable.dy + drawable.height / 2,
  );

  static double _drawableVisualBottom(
    Affine2D transform,
    BoneDrawable drawable,
  ) {
    final left = drawable.dx - drawable.width / 2;
    final right = drawable.dx + drawable.width / 2;
    final top = drawable.dy - drawable.height / 2;
    final bottom = drawable.dy + drawable.height / 2;
    return math.max(
      math.max(
        transform.transformPoint(left, top).y,
        transform.transformPoint(right, top).y,
      ),
      math.max(
        transform.transformPoint(left, bottom).y,
        transform.transformPoint(right, bottom).y,
      ),
    );
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

    _paintBodyShadow(canvas, floorY, centreX, scale, frame, drawScene);
    for (final boneId in _shadowBones(clip)) {
      final transform = frame.world[boneId];
      final drawable = drawScene.rig.bone(boneId)?.drawable;
      if (transform == null || drawable == null) continue;

      final bottom = transform.transformPoint(
        drawable.dx,
        drawable.dy + drawable.height / 2,
      );
      final lift = ((floorY - bottom.y) / (90 * scale)).clamp(0.0, 1.0);
      final active = boneId == contactBone;
      final shadowW = (active ? 72 : 48) * scale * (1 - 0.35 * lift);
      final baseAlpha = (shadowColor.a * 255.0).round();
      final activeBoost = backdrop == CharacterBackdrop.waterfront ? 2.45 : 1.9;
      final shadowAlpha =
          (baseAlpha * (active ? activeBoost : 0.8) * (1 - 0.82 * lift))
              .round()
              .clamp(0, 255);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bottom.x, floorY + (active ? 1.5 : 2.5)),
          width: shadowW,
          height: shadowW * (active ? 0.15 : 0.12),
        ),
        Paint()..color = shadowColor.withAlpha(shadowAlpha),
      );
      if (active) {
        final contactAlpha =
            (baseAlpha *
                    (backdrop == CharacterBackdrop.waterfront ? 3.2 : 2.4) *
                    (1 - 0.7 * lift))
                .round()
                .clamp(0, 255);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(bottom.x, floorY + 0.5),
            width: shadowW * 0.62,
            height: shadowW * 0.065,
          ),
          Paint()..color = shadowColor.withAlpha(contactAlpha),
        );
      }
    }
  }

  List<String> _shadowBones(Clip clip) {
    final spans = clip.contactSpans.isNotEmpty
        ? clip.contactSpans
        : clip.groundSpans;
    final ids = <String>{};
    for (final span in spans) {
      ids.add(span.bone);
    }
    return ids.toList(growable: false);
  }

  String? _activeGroundBone(Clip clip, double timeSeconds) {
    return _activeGroundSpan(clip, timeSeconds)?.bone;
  }

  GroundSpan? _activeGroundSpan(Clip clip, double timeSeconds) {
    final spans = clip.contactSpans.isNotEmpty
        ? clip.contactSpans
        : clip.groundSpans;
    if (spans.isEmpty || clip.duration <= 0) return null;
    final raw = timeSeconds / clip.duration;
    final p = clip.loop ? raw - raw.floorToDouble() : raw.clamp(0.0, 1.0);
    for (final span in spans) {
      if (p >= span.start && p < span.end) return span;
    }
    return spans.last;
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
    final shadowW =
        (backdrop == CharacterBackdrop.waterfront ? 92 : 78) *
        scale *
        (1 - 0.45 * lift);
    final alphaBoost = backdrop == CharacterBackdrop.waterfront ? 1.75 : 1.0;
    final shadowAlpha =
        ((shadowColor.a * 255.0).round() * alphaBoost * (1 - 0.7 * lift))
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
      old.backdropImage != backdropImage ||
      old.backdropCloudsImage != backdropCloudsImage ||
      old.backdropWavesImage != backdropWavesImage ||
      old.locomote != locomote ||
      old.walkingPair != walkingPair ||
      old.partnerScene != partnerScene ||
      old.ensembleScenes != ensembleScenes ||
      old.ensembleExpressions != ensembleExpressions ||
      old.ensembleClips != ensembleClips ||
      old.synchronousEnsemble != synchronousEnsemble ||
      old._renderer != _renderer;
}
