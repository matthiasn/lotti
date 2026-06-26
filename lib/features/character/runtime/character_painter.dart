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
  static const double _trioScaleFactor = 0.54;
  static const double _pairSpacing = 215;
  static const double _trioSpacing = 214;

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
    return index == 1 ? 1.11 : 0.91;
  }

  static double _roleFloorOffset(int index, int memberCount) {
    if (memberCount < 3) return 0;
    return index == 1 ? 6 : -18;
  }

  static ({double zoom, double dx, double dy}) _danceCamera(
    double timeSeconds,
    double duration,
  ) {
    final p = _cyclePhase(timeSeconds, duration);
    return (
      zoom: _smoothKeys(p, const [
        (p: 0, v: 1.0),
        (p: 1 / 8, v: 1.055),
        (p: 1 / 4, v: 1.105),
        (p: 1 / 2, v: 1.16),
        (p: 5 / 8, v: 1.19),
        (p: 3 / 4, v: 1.16),
        (p: 29 / 32, v: 1.07),
        (p: 1, v: 1.0),
      ]),
      dx: _smoothKeys(p, const [
        (p: 0, v: 0.0),
        (p: 1 / 8, v: -12.0),
        (p: 1 / 4, v: -28.0),
        (p: 1 / 2, v: 42.0),
        (p: 5 / 8, v: 48.0),
        (p: 3 / 4, v: 28.0),
        (p: 29 / 32, v: 8.0),
        (p: 1, v: 0.0),
      ]),
      dy: _smoothKeys(p, const [
        (p: 0, v: 0.0),
        (p: 1 / 4, v: -7.0),
        (p: 1 / 2, v: -12.0),
        (p: 5 / 8, v: -14.0),
        (p: 3 / 4, v: -9.0),
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
            (-22 - 6 * breathe - 10 * sideAnswer - 8 * wideV) *
            (1 - returnLock),
        dy:
            -8 +
            1.5 * callResponse -
            4 * leadCall -
            5 * sideAnswer -
            4 * wideV +
            3 * ensembleHit,
      ),
      1 => (
        dx: 2 * leadCall - 2 * ensembleHit,
        dy:
            9 -
            5 * leadCall -
            2 * blackSolo +
            4 * wideV +
            7 * centreFeature -
            3 * ensembleHit,
      ),
      2 => (
        dx:
            (22 + 6 * breathe + 9 * sideAnswer + 11 * blackSolo + 8 * wideV) *
            (1 - returnLock),
        dy:
            -8 -
            1.5 * callResponse -
            2 * leadCall -
            4 * sideAnswer +
            7 * blackSolo -
            4 * wideV +
            3 * ensembleHit,
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
        0 => (-0.48 * frame + 0.1 * frame * phraseDrift) * damping,
        1 => 0,
        2 => (0.48 * frame + 0.1 * frame * beatDrift) * damping,
        _ => (0.08 * frame * phraseDrift) * damping,
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
            const [Color(0x34FFFFFF), Color(0x185F7477)],
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
      final shadowW = (active ? 84 : 52) * scale * (1 - 0.35 * lift);
      final baseAlpha = (shadowColor.a * 255.0).round();
      final activeBoost = backdrop == CharacterBackdrop.waterfront ? 4.4 : 2.1;
      final shadowAlpha =
          (baseAlpha * (active ? activeBoost : 0.45) * (1 - 0.82 * lift))
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
                    (backdrop == CharacterBackdrop.waterfront ? 5.6 : 2.6) *
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
        (backdrop == CharacterBackdrop.waterfront ? 112 : 78) *
        scale *
        (1 - 0.45 * lift);
    final alphaBoost = backdrop == CharacterBackdrop.waterfront ? 2.35 : 1.0;
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
