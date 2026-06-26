import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
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
      _paintTopSafeSky(canvas, size);
    }
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
            Color(0xFF3DB9E9),
            Color(0xCC47BFEA),
            Color(0x003DB9E9),
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
    return index == 1 ? 1.06 : 0.94;
  }

  static double _roleFloorOffset(int index, int memberCount) {
    if (memberCount < 3) return 0;
    return index == 1 ? -28 : -40;
  }

  static ({double zoom, double dx, double dy}) _danceCamera(
    double timeSeconds,
    double duration,
  ) {
    final p = _cyclePhase(timeSeconds, duration);
    final loopGate = math.sin(math.pi * p);
    final push = loopGate * loopGate;
    final track = math.sin(2 * math.pi * p) * loopGate;
    final accent = math.sin(2 * math.pi * p);
    return (
      zoom: 1.0 + 0.13 * push + 0.025 * accent * accent,
      dx: 118 * track + 10 * push,
      dy: -7 * push,
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
    final heroPulse = math.pow(math.sin(math.pi * p), 2).toDouble();
    return switch (index) {
      0 => (dx: -10 - 8 * breathe, dy: -6 + 3 * callResponse),
      1 => (dx: 0, dy: 8 + 6 * heroPulse),
      2 => (dx: 10 + 8 * breathe, dy: -6 - 3 * callResponse),
      _ => (dx: 0, dy: 0),
    };
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
      final phraseDrift = math.sin(2 * math.pi * (p * 3 + index * 0.37));
      final beatDrift = math.sin(2 * math.pi * (p * 12 + index * 0.19));
      return switch (index) {
        0 => (-0.052 + 0.018 * phraseDrift + 0.008 * beatDrift) * damping,
        1 => 0,
        2 => (0.04 + 0.016 * phraseDrift - 0.008 * beatDrift) * damping,
        _ => (0.03 * phraseDrift) * damping,
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
        Paint()..color = const Color(0x20E7F2F2),
      )
      ..drawRect(
        Rect.fromLTRB(0, deckTop, size.width, floorY + 18),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, deckTop),
            Offset(0, floorY + 18),
            const [Color(0x00FFFFFF), Color(0x143D2B1E)],
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
            const [Color(0x30FFE0A8), Color(0x00FFE0A8)],
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
              Color(0x00DDEFF5),
              Color(0x38DDEFF5),
              Color(0x54E8E0CF),
              Color(0x18DDEFF5),
              Color(0x00FFFFFF),
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
            const [Color(0x56E9E2D3), Color(0x00E9E2D3)],
          ),
      )
      ..drawRect(
        Rect.fromLTRB(0, waterFarY, size.width * 0.7, deckTop),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, waterFarY),
            Offset(0, deckTop),
            const [Color(0x28D9F2F6), Color(0x00D9F2F6)],
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
            const [Color(0x88FFFFFF), Color(0x44EAF8FF)],
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
              Color(0x8FFFFFFF),
              Color(0x4A9EF2FF),
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
              Color(0x3DEFFFFF),
              Color(0x2480E8FF),
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
      final shadowW = (active ? 62 : 46) * scale * (1 - 0.35 * lift);
      final baseAlpha = (shadowColor.a * 255.0).round();
      final shadowAlpha =
          (baseAlpha * (active ? 1.75 : 0.72) * (1 - 0.82 * lift))
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
