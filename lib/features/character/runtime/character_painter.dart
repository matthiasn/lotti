import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:meta/meta.dart';

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

/// Backlight RIM pass(es), drawn behind each lit member as a blurred gel
/// silhouette. `sigmaFrac` is the blur sigma as a fraction of the canvas short
/// side; `alphaScale` scales the member's gel alpha; `offsetScale` displaces the
/// blurred silhouette toward the member's light source ([_kRimDirections]) as a
/// multiple of that pass' sigma. The offset puts the rim on the source edge, and
/// a `dstIn` gradient mask (in the paint loop) ERASES the shadow-side half so the
/// gel reads as a one-sided backlight, never a wrap-around glow. (A second soft
/// bloom pass used to wrap the silhouette; it was dropped as an outer-glow
/// sticker.) See [CharacterPainter.memberBacklights].
const List<({double sigmaFrac, double alphaScale, double offsetScale})>
_kBacklightPasses = [
  // A single thin directional RIM — no wrap. The soft outer bloom that used to
  // wrap the whole silhouette was removed: every craft lens read it as a
  // symmetric "outer-glow" sticker floating around the figure, and the user
  // called to drop it. What remains is one tight, hot kicker hugging the
  // source-facing contour and masked one-sided (below) — a crisp lit EDGE, not a
  // displaced haze column (a gaffer lens flagged the old wide offset as a "40px
  // amber fog slab"). The colour presence lives ON the fabric (the body key in
  // the grade) and on the deck (the floor pools), not in the air.
  (sigmaFrac: 0.005, alphaScale: 0.63, offsetScale: 1.4),
];

/// Cool, dark plate-blue the concert BODIES are lerped toward (`srcATop`) so the
/// flat cartoon fills SEAT into the blue-hour plate's exposure instead of
/// floating as a bright, saturated cutout. It cools the mid-grey suit toward the
/// backdrop's shadow floor and pulls the saturated tie/fur toward neutral — a
/// downward grade, the opposite of a lift. Kept DELIBERATELY LIGHT: it is a flat,
/// silhouette-wide wash, so any heavier and it compresses the baked cel-shade's
/// lit→shadow ramp back into "uniform flat grey" (a film panel's repeated cutout
/// complaint). The cel-shade's own cool core shadow already seats the figure's
/// dark side; this only needs to take a gentle bite out of the lit side's value.
/// Artistic value, not a design-system token: rendered scene grading, like the gels.
const Color _kBodySeat = Color(0x1C0A1626);

/// Cool blue-hour ambient BOUNCE that holds the body's shadow side at a low,
/// readable floor (the water/sky fill a real dancer catches at twilight) instead
/// of crushing it to a flat black void. Painted as the FAR stop of the gel
/// terminator (`srcATop`), so the side away from this lane's gel reads as cool
/// navy MATERIAL with form, not a silhouette hole — the lit side still carries
/// the warm gel. Pairs with [_kBodySeat]: seat the value down, then floor the
/// shadow so the suit stays a volume.
const Color _kBodyShadowFloor = Color(0x5426405E);

/// Companion to [_kBodySeat] for the FACE (above the collar). The bright, warm
/// muzzle is the single worst cutout offender on a film panel, so it gets pulled
/// toward the scene ambient — knocking value+saturation down enough to live in
/// the plate while staying a readable, likeable face. It is the MID stop of a
/// SOFT warm-key→cool-fill split (broad stops, low contrast) that stops the face
/// reading as a flat monochrome tan card WITHOUT a hard terminator that swims as
/// the head bobs (the earlier "face is all off" failure): [_kFaceKeySeat] keeps
/// the gel-key side warm, [_kFaceCoolFill] cools the shadow side.
const Color _kFaceSeat = Color(0x4414233B);

/// Key-side stop of the face split: a LIGHTER pull than [_kFaceSeat] so the side
/// facing this lane's gel keeps the warm muzzle tone the rim reads against.
const Color _kFaceKeySeat = Color(0x2814233B);

/// Shadow-side stop of the face split: a stronger, cooler blue-hour ambient fill
/// so the side away from the gel turns cool — the warm/cool break that kills the
/// flat-tan-sticker read.
const Color _kFaceCoolFill = Color(0x52223E5C);

/// Deep, cool floor occlusion pressed under each dancer's feet (a radial fading
/// to clear) so the trio is GROUNDED on the painted deck — a real contact shadow
/// the figure occludes the floor with — instead of floating over the additive
/// colour pools. Drawn under the figure, tight to the soles.
const Color _kContactShadow = Color(0xBE03060D);

/// Unit direction (screen space, +x right / +y down) from each dance lane toward
/// its rim-light source, i.e. the direction the gel halo is offset so the rim
/// lands on the source-facing edge. A fanned overhead back-key array: the
/// flankers are keyed from their outboard-upper corner, the hero from straight
/// above. Indexed by screen lane (0 = left, 1 = centre, 2 = right).
const List<Offset> _kRimDirections = [
  Offset(-0.90, -0.44), // left lane  → back-key raking the upper-LEFT contour
  Offset(-0.58, -0.81), // centre lane → hero 3/4 back-key, leaning camera-left
  Offset(0.90, -0.44), // right lane → back-key raking the upper-RIGHT contour
];

/// Whether [clip] is a centred-trio **concert dance** phrase — the lead clip
/// that turns on the whole stage act: the [_kRimDirections] rim/halo, the body
/// grade, hero staging, the dance formation, foot-anchor publishing, the dance
/// camera and the music head-bob. Both the original `dance` phrase and the
/// shipping `shaku` phrase (what the audio player actually dances) qualify —
/// gating on `'dance'` alone left every one of those dark/inert in the running
/// player, because it dances `shaku`.
bool _isTrioDanceClip(Clip clip) =>
    clip.name == 'dance' || clip.name == 'shaku';

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
    this.enableDanceCamera = true,
    this.danceCameraStrength = 1,
    this.locomote = false,
    this.walkingPair = false,
    this.partnerScene,
    this.ensembleScenes = const [],
    this.ensembleExpressions = const [],
    this.ensembleClips = const [],
    this.synchronousEnsemble = false,
    this.singingHeadMotion = false,
    this.cameraOverride,
    this.onDancerAnchors,
    this.memberBacklights = const [],
    this.bodyGrade,
    this.heroStaging = false,
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

  /// When true (dance clip only), the head bobs with the music: it sways on the
  /// dance phase and — for a member whose [Expression] is a singing one — dips
  /// forward/down with the vocal opening, so the singer's head rides the vocal
  /// instead of floating rigidly over a grooving body. Opt-in so non-singing
  /// uses of the painter are untouched.
  final bool singingHeadMotion;

  /// When set, replaces the built-in [_danceCamera] move with a caller-supplied
  /// shot `(zoom, dx, dy)` — applied verbatim (it owns the intensity, so
  /// [danceCameraStrength] is ignored). The dance-to-track demo's "virtual
  /// director" uses this to cut between section-aware, per-phrase-varied shots
  /// instead of looping one move. A jump in the value between frames reads as a
  /// hard cut; a smoothly-moving value reads as a continuous move.
  final ({double zoom, double dx, double dy})? cameraOverride;

  /// Optional per-frame report of each ensemble member's resolved on-screen
  /// anchor (foot point), normalized 0..1 to the canvas and ordered left→right
  /// by lane. Lets an overlay (e.g. stage lights) track the dancers without
  /// re-deriving the camera + formation maths. Only fired in three-member dance
  /// mode; never affects what is painted.
  final void Function(List<Offset> anchors)? onDancerAnchors;

  /// Optional per-member backlight (rim/halo) colours, ordered left→right to
  /// match the painted lane order. When an entry is non-transparent that member
  /// is drawn TWICE: first as a blurred, solid-colour silhouette behind itself
  /// (the gel halo hugging its outline), then normally on top — so the figure
  /// reads as a crisp shape ringed in coloured light. The alpha of each colour
  /// scales the halo strength. Only honored in three-member dance mode (where
  /// the lane order is stable); empty disables it and the painter is untouched.
  final List<Color> memberBacklights;

  /// Static "grade into the plate" for the concert dance trio, so the flat
  /// cartoon fills share the backdrop's twilight exposure instead of reading as
  /// stickers pasted on the painting. A vertical ambient wrap is composited
  /// (`srcATop`) onto each cat's own silhouette: `skyWrap` (cool sky light) up
  /// high, fading through clear, to `deckWrap` (warm deck/city bounce) down low.
  /// Its presence also strengthens the deck contact shadows so the trio is
  /// planted on the painted deck. The ambient fill + twilight wrap are STATIC;
  /// only the directional gel key carries a GENTLE, bounded beat breath (the
  /// stage light landing a touch harder on the fabric on the beat), kept well
  /// under the photosensitivity threshold — no full-figure luminance pulse. Only
  /// honored in three-member dance mode; null leaves the cats ungraded.
  final ({Color skyWrap, Color deckWrap})? bodyGrade;

  /// When true (concert dance only), stage the trio as a hero + backups: the
  /// lead renders a touch bigger and downstage, the flankers smaller and
  /// upstage, so the lead owns the frame with real depth. Opt-in and decoupled
  /// from [bodyGrade] so it only changes geometry where requested (the audio
  /// player); every other surface keeps its even trio.
  final bool heroStaging;

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

  /// Enables the music-video camera pass for the three-cat dance ensemble.
  /// Disable this for locked-camera choreography review.
  final bool enableDanceCamera;

  /// Scales the dance camera toward neutral: `1` = the full move, `0` = no
  /// zoom/pan. Lets a caller ramp the camera in/out smoothly instead of snapping
  /// it on the instant the dance starts.
  final double danceCameraStrength;

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
  static const double _trioScaleFactor = 0.48;
  static const double _pairSpacing = 215;
  static const double _trioSpacing = 238;

  // The dance camera's horizontal truck keyframes (_danceCamera.dx) are authored
  // in pixels of this reference stage (the 2560-wide art space), where the truck
  // across the side dancers keeps them in frame. Applied verbatim to a narrower
  // stage, the same pixel pan is a much larger FRACTION of the width and slides
  // the side cats off the edge (the "left cat disappears" bug). So the horizontal
  // pan is scaled by the stage width relative to this reference, keeping it the
  // same fraction — and the side dancers on screen — at any window size. The
  // virtual director's vertical lift (dy) is rescaled the same way against the
  // reference HEIGHT, so a negative dy frames the same FRACTION of the figure
  // (e.g. lifting the legwork to centre for the climax) at any window height. The
  // legacy built-in keyframes keep raw-px dy (their authored composition).
  static const double _danceCameraRefWidth = 2560;
  static const double _danceCameraRefHeight = 1440;

  /// Vertical position (fraction of stage height) of the zoom pivot — the point
  /// that stays put as the camera pushes in — for the **virtual director**'s
  /// shots ([cameraOverride]). Pinned right at the dancers' FEET/floor line so a
  /// push-in keeps the feet planted on the deck and grows the cast UPWARD into
  /// the open sky, instead of shoving the feet off the bottom edge and leaving
  /// dead sky above the cast. Height-relative, so the composition holds at any
  /// stage size.
  static const double _directorPivotFraction = 0.88;

  /// Zoom-pivot fraction for the built-in [_danceCamera] push-in when no
  /// [cameraOverride] is supplied. Its keyframes were authored around a
  /// head/torso-height pivot, so it keeps that pivot — the director's
  /// feet-planted pivot above is a property of the director's framing, not of
  /// this older move.
  static const double _builtInDancePivotFraction = 0.56;

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height * feetFraction;
    final memberCount = walkingPair
        ? (ensembleScenes.isEmpty ? 2 : ensembleScenes.length + 1)
        : 1;
    final ({double zoom, double dx, double dy}) sceneCamera;
    // The two camera sources are authored around different zoom pivots: the
    // director's shots plant the feet (feet-line pivot), the built-in push-in
    // frames the torso (head-height pivot). Pick the matching pivot per source.
    final double pivotFraction;
    if (cameraOverride != null) {
      // A caller (the dance-to-track "virtual director") supplies the whole shot
      // — varied per section/phrase, with cuts — so we apply it verbatim and let
      // it own the cinematography.
      sceneCamera = cameraOverride!;
      pivotFraction = _directorPivotFraction;
    } else {
      final rawCamera =
          enableDanceCamera &&
              walkingPair &&
              _isTrioDanceClip(clip) &&
              memberCount == 3
          ? _danceCamera(timeSeconds, clip.duration)
          : (zoom: 1.0, dx: 0.0, dy: 0.0);
      // Scale toward neutral so a caller can ramp the camera in/out smoothly.
      // Identity at strength 1 (the default) keeps existing renders bit-identical.
      sceneCamera = danceCameraStrength == 1
          ? rawCamera
          : (
              zoom: 1 + (rawCamera.zoom - 1) * danceCameraStrength,
              dx: rawCamera.dx * danceCameraStrength,
              dy: rawCamera.dy * danceCameraStrength,
            );
      pivotFraction = _builtInDancePivotFraction;
    }
    // Only the director's shots carry a height-rescaled dy (its legwork-climax
    // lift); the legacy keyframes keep their raw-px vertical framing.
    final scaleDy = cameraOverride != null;

    if (backdrop == CharacterBackdrop.waterfront) {
      canvas
        ..save()
        ..clipRect(Offset.zero & size);
      _applyParallaxCamera(
        canvas,
        size,
        sceneCamera,
        pivotFraction,
        scaleDy: scaleDy,
      );
      _paintWaterfrontBackdrop(
        canvas,
        size,
        floorY,
        timeSeconds,
        backdropImage,
        backdropCloudsImage,
        backdropWavesImage,
      );
      canvas.restore();
    }

    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    _applySceneCamera(
      canvas,
      size,
      sceneCamera,
      pivotFraction,
      scaleDy: scaleDy,
    );

    if (backdrop != CharacterBackdrop.waterfront && groundColor != null) {
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
      // Keep the lead cat in the CENTRE of the trio for EVERY clip, not just the
      // dance — so the front/centre cat never swaps between the calm intro (idle
      // clip) and the dance (continuity). Only the dance-specific behaviours
      // (formation, rim/pool lighting, foot anchors) stay gated on the dance clip
      // via [leadCentreOrder].
      final trioCentre = baseMembers.length == 3;
      final leadCentreOrder = _isTrioDanceClip(clip) && trioCentre;
      final order = trioCentre ? const [1, 0, 2] : null;
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
      // Optionally report each member's resolved on-screen foot anchor so an
      // overlay (stage lights) can track the dancers. Capture the live camera
      // transform once — the per-member transforms are pushed/popped inside
      // _paintCharacterAt, so this stays the scene-camera matrix.
      final reportAnchors = leadCentreOrder && onDancerAnchors != null;
      final cameraMatrix = reportAnchors ? canvas.getTransform() : null;
      final anchors = reportAnchors
          ? List<Offset>.filled(members.length, Offset.zero)
          : null;
      for (final i in paintOrder) {
        final memberScene = members[i];
        final memberClip = clips[i];
        final phaseOffset = synchronousEnsemble
            ? _ensembleMicroTimingOffset(
                i,
                members.length,
                timeSeconds,
                memberClip.duration,
              )
            : memberClip.duration * i / members.length;
        final formation = leadCentreOrder
            ? _danceFormation(
                i,
                members.length,
                timeSeconds,
                memberClip.duration,
              )
            : (dx: 0.0, dy: 0.0, scale: 1.0);
        // Opt-in hero staging (lead bigger/downstage, flankers smaller/upstage);
        // identity for every surface that doesn't request it. Decoupled from
        // [bodyGrade] (colour) so it only moves geometry when asked.
        final heroStage = (leadCentreOrder && heroStaging)
            ? _heroStaging(i, members.length)
            : (scale: 1.0, dy: 0.0, dx: 0.0);
        final memberScale =
            drawScale *
            _roleScale(i, members.length) *
            formation.scale *
            heroStage.scale;
        final memberHorizontalScale = _roleHorizontalScale(i, members.length);
        final memberFloorY =
            groupFloorY +
            (_roleFloorOffset(i, members.length) +
                    formation.dy +
                    heroStage.dy) *
                drawScale;
        final memberCentreX =
            startX + spacing * i + (formation.dx + heroStage.dx) * drawScale;
        if (anchors != null && cameraMatrix != null) {
          // Map the local foot point through the camera transform to screen,
          // normalized to the canvas (affine — ignore the perspective row).
          final sx =
              cameraMatrix[0] * memberCentreX +
              cameraMatrix[4] * memberFloorY +
              cameraMatrix[12];
          final sy =
              cameraMatrix[1] * memberCentreX +
              cameraMatrix[5] * memberFloorY +
              cameraMatrix[13];
          anchors[i] = Offset(sx / size.width, sy / size.height);
        }
        // GROUNDED contact shadow: a soft, dark elliptical occlusion pressed into
        // the deck right under this member's feet, drawn FIRST so the figure (and
        // the additive colour pool the overlay lays down later) sit OVER it.
        // Without it the trio floats above the pools; this is the cool, hard
        // occlusion a real dancer presses into the boards, anchoring the feet. A
        // radial gradient squashed to the foot ellipse (no MaskFilter blur) keeps
        // it cheap and soft-edged. Concert dance only.
        if (leadCentreOrder) {
          final footW = 98 * memberScale;
          final footH = 26 * memberScale;
          final footRect = Rect.fromCenter(
            center: Offset(memberCentreX, memberFloorY),
            width: footW,
            height: footH,
          );
          // Squash the circular radial into the foot ellipse: scale y about the
          // foot centre (column-major 4x4, so the gradient fades to clear exactly
          // at the oval edge instead of leaving a hard vertical seam).
          final sy = footH / footW;
          final cy = footRect.center.dy;
          final squash = Float64List(16)
            ..[0] = 1
            ..[5] = sy
            ..[10] = 1
            ..[15] = 1
            ..[13] = cy * (1 - sy);
          canvas.drawOval(
            footRect,
            Paint()
              ..shader = ui.Gradient.radial(
                footRect.center,
                footW / 2,
                const [_kContactShadow, Color(0x00000000)],
                const [0.0, 1.0],
                TileMode.clamp,
                squash,
              ),
          );
        }
        // Backlight (rim/halo): draw this member as a blurred, solid-gel
        // silhouette BEHIND itself first, so the real draw on top leaves a
        // coloured glow hugging the outline. Only when a colour is supplied for
        // this lane (the lead-centre dance order keeps lane index == screen
        // position left→right). Aligned for free — it reuses the member's exact
        // transform, so the halo tracks the dancer through any camera/formation.
        final glow = leadCentreOrder && i < memberBacklights.length
            ? memberBacklights[i]
            : null;
        // This lane's light-source direction, shared by the rim halo (below) and
        // the gel torso-modelling in the front-body grade (further down).
        final rimDir = i < _kRimDirections.length
            ? _kRimDirections[i]
            : Offset.zero;
        if (glow != null && glow.a > 0) {
          // A thin directional RIM (no wrap): flatten the member to a solid gel
          // silhouette, blur it, and OFFSET it toward this lane's light source
          // ([_kRimDirections]) before drawing it behind the real figure, so only
          // the slice protruding past the source-facing edge shows. The dstIn mask
          // below erases the retreating side, so it reads as a backlight catching
          // one edge. Aligned for free — it reuses the member's exact transform.
          for (final pass in _kBacklightPasses) {
            final sigma = size.shortestSide * pass.sigmaFrac;
            final off = rimDir * (sigma * pass.offsetScale);
            final pad = sigma * 4 + off.distance;
            // Isolate over the whole stage, not a tight member rectangle. At
            // deep camera zooms the flank dancers sit near the frame edges; a
            // tight saveLayer clips the blur into a visible vertical colour
            // wall over the backdrop and can appear to slice the cat. The
            // stage clip already limits the result to the viewport.
            final haloBounds = (Offset.zero & size).inflate(pad);
            final a = (glow.a * pass.alphaScale).clamp(0.0, 1.0);
            canvas
              ..saveLayer(
                haloBounds,
                Paint()
                  ..colorFilter = ColorFilter.mode(
                    glow.withValues(alpha: a),
                    BlendMode.srcIn,
                  )
                  ..imageFilter = ui.ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                  ),
              )
              ..save()
              ..translate(off.dx, off.dy);
            _paintCharacterAt(
              memberScene,
              canvas,
              size,
              clip: memberClip,
              floorY: memberFloorY,
              centreX: memberCentreX,
              flip: flip,
              timeSeconds: timeSeconds + phaseOffset,
              expression: expressions[i],
              scale: memberScale,
              feetFraction: feetFraction,
              horizontalScale: memberHorizontalScale,
            );
            canvas.restore();
            // ONE-SIDED rim. A `dstIn` linear gradient keeps the thin rim at full
            // strength on the lamp-facing side and ERASES it on the retreating
            // side, so it reads as a backlight catching one edge, never a wrap.
            // The split is biased toward the HORIZONTAL — [_kRimDirections] are
            // mostly vertical (lamps rake down from above), so masking along rimDir
            // would dim the whole lower body instead of one side.
            final maskVec = Offset(rimDir.dx, rimDir.dy * 0.28);
            final maskLen = maskVec.distance;
            final maskUnit = maskLen > 0
                ? maskVec / maskLen
                : const Offset(-1, 0);
            final rimMid = Offset(
              memberCentreX,
              memberFloorY - size.height * 0.42,
            );
            final rimReach = maskUnit * (size.height * 0.22);
            canvas
              ..drawRect(
                haloBounds,
                Paint()
                  ..blendMode = BlendMode.dstIn
                  ..shader = ui.Gradient.linear(
                    rimMid + rimReach, // lamp side — full-strength rim
                    rimMid - rimReach, // shadow side — erased
                    const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                    const [0.0, 1.0],
                  ),
              )
              ..restore();
          }
        }
        // Front body draw. In concert mode, render it into an isolation layer so
        // the cel-shade grade below can be masked to the cat's own silhouette
        // (`srcATop`) — see the cel-shade block for the form-shadow terminator
        // and twilight wrap. The rim passes above stay outside this layer, so the
        // gel edge stays pure.
        final grade = leadCentreOrder ? bodyGrade : null;
        // Full-stage isolation avoids internal crop edges in tight side shots.
        // The grade is still masked by srcATop to the just-drawn cat silhouette.
        final gradeBounds = Offset.zero & size;
        if (grade != null) canvas.saveLayer(gradeBounds, Paint());
        _paintCharacterAt(
          memberScene,
          canvas,
          size,
          clip: memberClip,
          floorY: memberFloorY,
          centreX: memberCentreX,
          flip: flip,
          timeSeconds: timeSeconds + phaseOffset,
          expression: expressions[i],
          scale: memberScale,
          feetFraction: feetFraction,
          horizontalScale: memberHorizontalScale,
        );
        if (grade != null) {
          // GRADE THE FLAT FILLS INTO THE PLATE. The cartoon cats are otherwise a
          // bright, saturated cutout over a deep blue-hour painting; these passes
          // (all masked `srcATop` to the just-drawn cat silhouette, so they touch
          // only the figure) seat the trio into the scene's exposure:
          //
          //  • FACE (above the collar) — a flat, uniform pull toward the scene
          //    ambient ([_kFaceSeat]); knocks the bright warm muzzle's value +
          //    saturation down so it stops reading as the brightest sticker on
          //    screen. FLAT, never a ramp — a directional gradient over the head
          //    swims as it bobs (the "face is all off" failure).
          //  • BODY (below the collar) — SEAT toward a dark plate-blue
          //    ([_kBodySeat]) so the mid-grey suit crushes to the backdrop's
          //    shadow floor and the saturated tie/fur go neutral, then a vertical
          //    TWILIGHT WRAP (cool sky light up high → warm deck/city bounce down
          //    low), then a directional GEL TERMINATOR that bleeds this lane's gel
          //    colour across the lit side of the now-seated fabric — modelling the
          //    form and carrying the stage colour ONTO the suit, not just an edge
          //    outline.
          //
          // The seats + wrap are static; only the gel key carries the gentle beat
          // breath (so no full-figure luminance pulse). The collar split is the
          // same line ([memberFloorY] − 0.20·height) the body wrap used before.
          final collarY = memberFloorY - size.height * 0.20;
          // FACE grade — above the collar. A SOFT warm-key→cool-fill split along
          // this lane's gel direction: the key side keeps the warm muzzle tone the
          // rim reads against, the shadow side cools toward the blue-hour ambient.
          // Broad stops + low contrast so the break never resolves into a hard
          // line that swims as the head bobs (the "face is all off" failure).
          final faceMid = Offset(
            memberCentreX,
            memberFloorY - size.height * 0.32,
          );
          final faceReach = rimDir * (size.height * 0.13);
          canvas
            ..save()
            ..clipRect(
              Rect.fromLTRB(
                gradeBounds.left,
                gradeBounds.top,
                gradeBounds.right,
                collarY,
              ),
            )
            ..drawRect(
              gradeBounds,
              Paint()
                ..blendMode = BlendMode.srcATop
                ..shader = ui.Gradient.linear(
                  faceMid + faceReach, // key side (toward the gel source)
                  faceMid - faceReach, // shadow side
                  const [_kFaceKeySeat, _kFaceSeat, _kFaceCoolFill],
                  const [0.0, 0.5, 1.0],
                ),
            )
            ..restore()
            // BODY seat + twilight wrap — below the collar.
            ..save()
            ..clipRect(
              Rect.fromLTRB(
                gradeBounds.left,
                collarY,
                gradeBounds.right,
                gradeBounds.bottom,
              ),
            )
            // Seat the body DOWN toward the plate's shadow floor (cool, desaturate,
            // crush) — the opposite of the old lift; the wrap + gel model a lit
            // side back onto the now-darker figure so it reads as volume, not a
            // flat black silhouette.
            ..drawRect(
              gradeBounds,
              Paint()
                ..blendMode = BlendMode.srcATop
                ..color = _kBodySeat,
            )
            ..drawRect(
              gradeBounds,
              Paint()
                ..blendMode = BlendMode.srcATop
                ..shader = ui.Gradient.linear(
                  Offset(memberCentreX, memberFloorY - size.height * 0.52),
                  Offset(memberCentreX, memberFloorY),
                  [grade.skyWrap, const Color(0x00000000), grade.deckWrap],
                  const [0.0, 0.52, 1.0],
                ),
            );
          if (glow != null && glow.a > 0) {
            final mid = Offset(
              memberCentreX,
              memberFloorY - size.height * 0.28,
            );
            final reach = rimDir * (size.height * 0.32);
            // GENTLE beat breath. The gel key is the SAME stage light that pulses
            // the rim halo, whose alpha already rides the beat via [glow.a], so
            // let it land a touch harder on the fabric on the beat instead of
            // pinning it flat. Compressed into a narrow band (~0.52 at rest →
            // ~0.62 at full beat for the hero) so it reads as a motivated swell,
            // not a strobe: only this small, terminator-edge gel term moves — the
            // seats + wrap stay STATIC — so the full-figure luminance never pulses
            // anywhere near the photosensitivity threshold.
            final gelKey = (0.82 + 0.20 * glow.a).clamp(0.82, 0.96);
            canvas
              ..drawRect(
                gradeBounds,
                Paint()
                  ..blendMode = BlendMode.srcATop
                  ..shader = ui.Gradient.linear(
                    mid + reach, // lit, source-facing side
                    mid - reach, // shadow side
                    [
                      glow.withValues(
                        alpha: gelKey,
                      ), // gel key kicks onto the fabric (gentle beat breath)
                      const Color(0x00000000),
                      _kBodyShadowFloor, // cool ambient bounce, NOT a black crush
                    ],
                    // DIRECTIONAL terminator: the gel KEY commits to the
                    // source-facing side only (~0.40 of the axis), then breaks to
                    // a clear cool shadow core (down from a 0.74 wash that lit most
                    // of the body and read as a symmetric "amber column" with no
                    // lit-side/shadow-side modelling — a gaffer lens's blocker).
                    // The lit side reads as warm-keyed fabric; the camera-right
                    // side falls onto the deeper cool ambient floor, so the torso
                    // models as a volume lit from one direction, not a flat cutout.
                    const [0.0, 0.4, 0.82],
                  ),
              )
              // INNER RIM. A tight, hot gel band hugging the lamp-facing edge
              // INSIDE the silhouette (`srcATop`), so the stage gel reads as light
              // landing ON the cloth — the panel's "make the gel wrap into the
              // material, not float around it". This on-body illumination is what
              // lets the outer halo come down without the cat going dark.
              ..drawRect(
                gradeBounds,
                Paint()
                  ..blendMode = BlendMode.srcATop
                  ..shader = ui.Gradient.linear(
                    mid + reach, // lit edge — hot
                    mid - reach, // shadow side — gone
                    [
                      glow.withValues(
                        alpha: (0.72 + 0.22 * glow.a).clamp(0.72, 0.94),
                      ),
                      const Color(0x00000000),
                    ],
                    const [0.0, 0.22], // concentrated on the lamp-facing edge
                  ),
              );
            // FLOOR-POOL BOUNCE: the saturated colour pool on the deck kicks back
            // UP onto the shins/feet, tying the figure to its own pool instead of
            // letting the pool read as a separate decorative disc below floating
            // legs. A short gel gradient rising from the soles, masked to the
            // figure (`srcATop`), riding the same beat as the pool via [glow.a].
            final bounce = (0.16 + 0.16 * glow.a).clamp(0.16, 0.34);
            canvas.drawRect(
              gradeBounds,
              Paint()
                ..blendMode = BlendMode.srcATop
                ..shader = ui.Gradient.linear(
                  Offset(memberCentreX, memberFloorY),
                  Offset(memberCentreX, memberFloorY - size.height * 0.20),
                  [glow.withValues(alpha: bounce), const Color(0x00000000)],
                  const [0.0, 1.0],
                ),
            );
          }
          canvas
            ..restore() // pop the body clip
            ..restore(); // pop the isolation layer
        }
      }
      if (anchors != null) onDancerAnchors!(anchors);
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
    double pivotFraction, {
    bool scaleDy = false,
  }) {
    if (camera.zoom == 1 && camera.dx == 0 && camera.dy == 0) return;
    final pivot = Offset(size.width / 2, size.height * pivotFraction);
    final maxDx = size.width * (camera.zoom - 1) / 2;
    final maxDy = size.height * (camera.zoom - 1) / 2;
    final dx = (camera.dx * size.width / _danceCameraRefWidth).clamp(
      -maxDx,
      maxDx,
    );
    // The virtual director authors dy in 1440-ref px so a negative dy frames the
    // same FRACTION of the figure at any height (the legwork-climax lift). The
    // legacy built-in keyframes author dy in raw px, so they are not rescaled.
    final rawDy = scaleDy
        ? camera.dy * size.height / _danceCameraRefHeight
        : camera.dy;
    final dy = rawDy.clamp(-maxDy, maxDy);
    canvas
      ..translate(pivot.dx + dx, pivot.dy + dy)
      ..scale(camera.zoom)
      ..translate(-pivot.dx, -pivot.dy);
  }

  static void _applyParallaxCamera(
    Canvas canvas,
    Size size,
    ({double zoom, double dx, double dy}) camera,
    double pivotFraction, {
    bool scaleDy = false,
  }) {
    _applySceneCamera(
      canvas,
      size,
      _parallaxCamera(camera),
      pivotFraction,
      scaleDy: scaleDy,
    );
  }

  /// Reduces a scene camera to the gentler backdrop parallax (it lags the
  /// foreground so the scene reads as deeper).
  static ({double zoom, double dx, double dy}) _parallaxCamera(
    ({double zoom, double dx, double dy}) camera,
  ) {
    return (
      zoom: 1 + (camera.zoom - 1) * 0.34,
      dx: camera.dx * 0.28,
      dy: camera.dy * 0.18,
    );
  }

  /// The reduced parallax transform a *separate* backdrop widget (e.g. the
  /// layered scenery backdrop drawn behind the dancers in a `Stack`) should
  /// apply so it drifts with the dance camera, matching the legacy in-painter
  /// waterfront parallax. Returns the identity matrix when the dance camera is
  /// inactive. [active] should mirror this painter's gate — the performing trio
  /// on the `dance` clip.
  static Matrix4 danceParallaxTransform({
    required double timeSeconds,
    required double clipDuration,
    required Size size,
    double danceCameraStrength = 1,
    bool active = true,
  }) {
    if (!active || clipDuration <= 0 || size.isEmpty) {
      return Matrix4.identity();
    }
    final raw = _danceCamera(timeSeconds, clipDuration);
    final scene = (
      zoom: 1 + (raw.zoom - 1) * danceCameraStrength,
      dx: raw.dx * danceCameraStrength,
      dy: raw.dy * danceCameraStrength,
    );
    return _parallaxMatrix(
      _parallaxCamera(scene),
      size,
      _builtInDancePivotFraction,
    );
  }

  /// The reduced parallax transform a *separate* backdrop widget should apply
  /// for an explicit virtual-director [shot]. The dance-to-track demo drives the
  /// dance camera from `dance_camera_director.dart` (per-section framings with
  /// cuts) rather than the built-in [_danceCamera] keyframes, and feeds the same
  /// shot here so the scenery lags the dancers exactly as it does under the
  /// in-painter parallax. Mirrors [_applySceneCamera] reduced by
  /// [_parallaxCamera]. Returns identity when [active] is false, the stage is
  /// empty, or the parallax is neutral.
  static Matrix4 danceParallaxTransformForShot({
    required ({double zoom, double dx, double dy}) shot,
    required Size size,
    bool active = true,
  }) {
    if (!active || size.isEmpty) return Matrix4.identity();
    return _parallaxMatrix(
      _parallaxCamera(shot),
      size,
      _directorPivotFraction,
      scaleDy: true,
    );
  }

  /// Builds the column-major backdrop matrix for an already-reduced [parallax]
  /// camera: a uniform scale about the [pivotFraction]-height pivot then a
  /// clamped pan, with `dx` rescaled from the 2560-ref width exactly like
  /// [_applySceneCamera]. Identity when the parallax is neutral.
  static Matrix4 _parallaxMatrix(
    ({double zoom, double dx, double dy}) parallax,
    Size size,
    double pivotFraction, {
    bool scaleDy = false,
  }) {
    if (parallax.zoom == 1 && parallax.dx == 0 && parallax.dy == 0) {
      return Matrix4.identity();
    }
    final pivot = Offset(size.width / 2, size.height * pivotFraction);
    final maxDx = size.width * (parallax.zoom - 1) / 2;
    final maxDy = size.height * (parallax.zoom - 1) / 2;
    final dx = (parallax.dx * size.width / _danceCameraRefWidth).clamp(
      -maxDx,
      maxDx,
    );
    final rawDy = scaleDy
        ? parallax.dy * size.height / _danceCameraRefHeight
        : parallax.dy;
    final dy = rawDy.clamp(-maxDy, maxDy);
    // Uniform scale about [pivot] then translate by (dx, dy), written directly
    // as a column-major matrix (avoids the deprecated Matrix4.translate/scale).
    final z = parallax.zoom;
    final tx = pivot.dx * (1 - z) + dx;
    final ty = pivot.dy * (1 - z) + dy;
    return Matrix4(
      z,
      0,
      0,
      0, //
      0,
      z,
      0,
      0, //
      0,
      0,
      1,
      0, //
      tx,
      ty,
      0,
      1,
    );
  }

  static double _scaleFactor(int memberCount) =>
      memberCount >= 3 ? _trioScaleFactor : _pairScaleFactor;

  static double _spacing(int memberCount) =>
      memberCount >= 3 ? _trioSpacing : _pairSpacing;

  static double _roleScale(int index, int memberCount) {
    if (memberCount < 3) return 1;
    return index == 1 ? 1.2 : 0.86;
  }

  static double _roleHorizontalScale(int index, int memberCount) {
    if (memberCount < 3) return 1;
    return index == 1 ? 1.08 : 1;
  }

  static double _roleFloorOffset(int index, int memberCount) {
    if (memberCount < 3) return 0;
    return index == 1 ? 28 : -44;
  }

  /// Extra HERO STAGING applied only to the layered-scene concert player (keyed
  /// off [bodyGrade] being present, not the shared trio). It pushes the lead a
  /// touch bigger and downstage and the flankers smaller and upstage, so the row
  /// reads with real depth and the lead owns the frame — a music-video hero
  /// composition. Kept out of [_roleScale] / [_danceFormation] so the main dance
  /// and the formation-depth tests (scale locked to 1, backup rows locked) are
  /// untouched. Constant per role (no time term) — depth must not animate without
  /// matching footwork.
  static ({double scale, double dy, double dx}) _heroStaging(
    int index,
    int memberCount,
  ) {
    if (memberCount < 3) return (scale: 1, dy: 0, dx: 0);
    // Lead: clearly bigger, owning the frame by SIZE. Only a small downstage dy
    // on top of the role's own floor offset — pushing it further down clipped the
    // hero's feet off the bottom edge once the dance camera tightened.
    if (index == 1) return (scale: 1.18, dy: 4, dx: 0);
    // Flankers: smaller and upstage (higher = further back), and pulled INWARD
    // toward the lead (left lane → right, right lane → left) so the three read
    // as a tight V-wedge with the hero at its point instead of an even row.
    final inward = index == 0 ? 1.0 : -1.0;
    return (scale: 0.8, dy: -28, dx: inward * 30);
  }

  static ({double zoom, double dx, double dy}) _danceCamera(
    double timeSeconds,
    double duration,
  ) {
    final p = _cyclePhase(timeSeconds, duration);
    return (
      // Shot plan: establish the trio, push into the lead's face/torso, truck
      // across the side dancers, then pull back. The easing keeps it on rails
      // rather than feeling like a fast handheld pan.
      zoom: _smoothKeys(p, const [
        (p: 0, v: 1.0),
        (p: 1 / 8, v: 1.18),
        (p: 1 / 4, v: 1.52),
        (p: 3 / 8, v: 1.78),
        (p: 1 / 2, v: 2.08),
        (p: 5 / 8, v: 1.82),
        (p: 3 / 4, v: 1.58),
        (p: 7 / 8, v: 1.22),
        (p: 1, v: 1.0),
      ]),
      dx: _smoothKeys(p, const [
        (p: 0, v: 0.0),
        (p: 1 / 8, v: -18.0),
        (p: 1 / 4, v: -86.0),
        (p: 3 / 8, v: -142.0),
        (p: 1 / 2, v: -112.0),
        (p: 5 / 8, v: 24.0),
        (p: 3 / 4, v: 142.0),
        (p: 7 / 8, v: 62.0),
        (p: 1, v: 0.0),
      ]),
      dy: _smoothKeys(p, const [
        (p: 0, v: 0.0),
        (p: 1 / 8, v: -18.0),
        (p: 1 / 4, v: -50.0),
        (p: 3 / 8, v: -82.0),
        (p: 1 / 2, v: -88.0),
        (p: 5 / 8, v: -76.0),
        (p: 3 / 4, v: -50.0),
        (p: 7 / 8, v: -18.0),
        (p: 1, v: 0.0),
      ]),
    );
  }

  static ({double dx, double dy, double scale}) _danceFormation(
    int index,
    int memberCount,
    double timeSeconds,
    double duration,
  ) {
    if (memberCount < 3) return (dx: 0, dy: 0, scale: 1);
    final p = _cyclePhase(timeSeconds, duration);
    final breathe = math.sin(2 * math.pi * (p * 3 + 0.15));
    final leadCall = _pulse(p, 1 / 16, 1 / 4);
    final rightFeature = _holdPulse(p, 3 / 32, 5 / 32, 7 / 32, 9 / 32);
    final greyFeature = _holdPulse(p, 8 / 32, 9 / 32, 11 / 32, 12 / 32);
    final sideAnswer = _pulse(p, 5 / 16, 1 / 2);
    final blackSolo = _pulse(p, 3 / 8, 1 / 2);
    final wideV = _pulse(p, 1 / 2, 3 / 4);
    final centreFeature = _pulse(p, 17 / 32, 23 / 32);
    final ensembleHit = _pulse(p, 23 / 32, 27 / 32);
    final finishTriangle = _holdPulse(p, 27 / 32, 29 / 32, 31 / 32, 1);
    // Stage depth is locked. The dancers' apparent foreground/background row
    // comes from _roleFloorOffset + _roleScale, not animated perspective motion
    // that their in-place legwork cannot physically earn.
    return switch (index) {
      0 => (
        dx:
            -34 -
            7 * breathe -
            14 * sideAnswer -
            13 * wideV +
            14 * greyFeature +
            6 * finishTriangle,
        dy: -17,
        scale: 1,
      ),
      1 => (
        dx: 3 * leadCall - 2 * greyFeature - 3 * ensembleHit,
        dy:
            20 -
            5 * leadCall -
            8 * rightFeature -
            4 * greyFeature -
            2 * blackSolo +
            2 * wideV +
            5 * centreFeature -
            3 * ensembleHit,
        scale: 1,
      ),
      2 => (
        dx:
            34 +
            7 * breathe +
            12 * rightFeature +
            12 * sideAnswer +
            12 * blackSolo +
            12 * wideV -
            8 * greyFeature -
            22 * finishTriangle,
        dy: -17,
        scale: 1,
      ),
      _ => (dx: 0, dy: 0, scale: 1),
    };
  }

  @visibleForTesting
  static ({double dx, double dy, double scale}) debugDanceFormation(
    int index,
    int memberCount,
    double timeSeconds,
    double duration,
  ) => _danceFormation(index, memberCount, timeSeconds, duration);

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

  static double _holdPulse(
    double p,
    double start,
    double holdStart,
    double holdEnd,
    double end,
  ) {
    if (p < start || p > end) return 0;
    if (p < holdStart) return _smoothUnit((p - start) / (holdStart - start));
    if (p <= holdEnd) return 1;
    return 1 - _smoothUnit((p - holdEnd) / (end - holdEnd));
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
      // together. Keep trio variance in pose, arms, faces, and formation; do
      // not offset the actual sampled time, because even sub-frame lead/trail
      // offsets cross support-foot handoffs at different moments and make side
      // dancers pop while the centre lead stays smooth.
      return switch (index) {
        0 => 0,
        1 => 0,
        2 => 0,
        _ => 0,
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
    double horizontalScale = 1,
  }) {
    final base = groundedBase(
      size,
      centreX: centreX,
      scale: scale,
      feetFraction: feetFraction,
      floorY: floorY,
      feetOffset: drawScene.restFeetOffset,
      flip: flip,
    ).multiply(Affine2D.scale(horizontalScale, 1));
    final frame = drawScene.frameAt(
      clip: clip,
      timeSeconds: timeSeconds,
      expression: expression,
      base: base,
      eyeOpenScale: eyeOpenScale,
    );
    final pinnedFrame = _floorPinnedPerformanceFrame(
      frame,
      drawScene,
      clip,
      timeSeconds,
      expression,
      base,
      floorY,
    );
    final groundedFrame = singingHeadMotion && _isTrioDanceClip(clip)
        ? _danceHeadMotion(
            pinnedFrame,
            drawScene.rig,
            open: expression.name == 'sing'
                ? expression.state.mouthOpen.clamp(0.0, 1.0)
                : 0.0,
            timeSeconds: timeSeconds,
            clipDuration: clip.duration,
            scale: scale,
          )
        : pinnedFrame;

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

  /// Rotates/translates the head subtree (head + its descendants; the face is
  /// anchored to the head, so it follows) to bob with the music. A continuous
  /// sway on the dance phase grooves every dancer; [open] adds a forward/down
  /// dip + lean for a singing member so the head rides the loud syllables. The
  /// rotation pivots at the neck joint (the head bone's origin) so nothing
  /// detaches; the dip is downward so the head overlaps (not gaps) the neck.
  CharacterFrame _danceHeadMotion(
    CharacterFrame frame,
    RigSpec rig, {
    required double open,
    required double timeSeconds,
    required double clipDuration,
    required double scale,
  }) {
    final headId = rig.face?.anchorBoneId;
    if (headId == null) return frame;
    final headWorld = frame.world[headId];
    if (headWorld == null) return frame;

    final phase = clipDuration > 0
        ? timeSeconds / clipDuration * 2 * math.pi * 3
        : 0.0;
    final tilt = math.sin(phase) * 0.028 + open * 0.03; // gentle sway + lean
    final dip = open * 6.5 * scale; // soft dip into the loud syllables
    if (tilt == 0 && dip == 0) return frame;

    final px = headWorld.tx;
    final py = headWorld.ty;
    final nod = Affine2D.translation(0, dip)
        .multiply(Affine2D.translation(px, py))
        .multiply(Affine2D.rotation(tilt))
        .multiply(Affine2D.translation(-px, -py));
    final subtree = _headSubtree(rig, headId);
    return CharacterFrame(
      world: {
        for (final e in frame.world.entries)
          e.key: subtree.contains(e.key) ? nod.multiply(e.value) : e.value,
      },
      face: frame.face,
      locomotionX: frame.locomotionX,
    );
  }

  /// The head bone plus every bone descended from it (so the whole head moves as
  /// a unit when the head nods).
  static Set<String> _headSubtree(RigSpec rig, String headId) {
    final out = {headId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final b in rig.bones) {
        final parent = b.parent;
        if (parent != null && out.contains(parent) && out.add(b.id)) {
          grew = true;
        }
      }
    }
    return out;
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
    if (clip.contactPinning == ContactPinning.lowestContact) {
      final visualBottom = _lowestContactVisualBottom(frame, drawScene, clip);
      if (visualBottom == null) return frame;
      final dy = floorY - visualBottom;
      if (dy.abs() < 0.2) return frame;
      final correction = Affine2D.translation(0, dy);
      return CharacterFrame(
        world: {
          for (final entry in frame.world.entries)
            entry.key: correction.multiply(entry.value),
        },
        face: frame.face,
        locomotionX: frame.locomotionX,
      );
    }
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

  double? _lowestContactVisualBottom(
    CharacterFrame frame,
    CharacterScene drawScene,
    Clip clip,
  ) {
    double? lowest;
    final seen = <String>{};
    for (final span in clip.contactSpans) {
      if (!seen.add(span.bone)) continue;
      final transform = frame.world[span.bone];
      final drawable = drawScene.rig.bone(span.bone)?.drawable;
      if (transform == null || drawable == null) continue;
      final bottom = _drawableVisualBottom(transform, drawable);
      lowest = lowest == null ? bottom : math.max(lowest, bottom);
    }
    return lowest;
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

  /// Whether the figure stands on a real painted deck and so needs the strong,
  /// planted contact shadows (rather than the faint default for a bare/no
  /// backdrop). True for the legacy waterfront plate AND the new layered scene
  /// (whose deck is painted by `LayeredBackdrop` below, with the painter drawing
  /// over `CharacterBackdrop.none`, so [bodyGrade] is the signal it is present).
  bool get _strongDeckShadows =>
      backdrop == CharacterBackdrop.waterfront || bodyGrade != null;

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
      final activeBoost = _strongDeckShadows ? 5.0 : 2.1;
      final shadowAlpha =
          (baseAlpha * (active ? activeBoost : 0.45) * (1 - 0.82 * lift))
              .round()
              .clamp(0, 255);
      _drawDeckShadowOval(
        canvas,
        center: Offset(bottom.x + _shadowSlantX(scale), floorY + 2),
        width: shadowW,
        height: shadowW * (active ? 0.15 : 0.12),
        color: _deckShadowColor(shadowAlpha),
        angle: _deckShadowAngle,
      );
      if (active) {
        final contactAlpha =
            (baseAlpha * (_strongDeckShadows ? 6.4 : 2.6) * (1 - 0.7 * lift))
                .round()
                .clamp(0, 255);
        _drawDeckShadowOval(
          canvas,
          center: Offset(bottom.x + _shadowSlantX(scale) * 0.45, floorY + 0.5),
          width: shadowW * 0.62,
          height: shadowW * 0.065,
          color: _deckShadowColor(contactAlpha),
          angle: _deckShadowAngle,
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
    _drawDeckShadowOval(
      canvas,
      center: Offset(
        centreX + (backdrop == CharacterBackdrop.waterfront ? 10 * scale : 0),
        floorY + (backdrop == CharacterBackdrop.waterfront ? 4 * scale : 0),
      ),
      width: shadowW * (backdrop == CharacterBackdrop.waterfront ? 1.14 : 1),
      height: shadowW * (backdrop == CharacterBackdrop.waterfront ? 0.2 : 0.16),
      color: _deckShadowColor(shadowAlpha),
      angle: _deckShadowAngle,
    );
  }

  static const double _deckShadowAngle = -0.08;

  double _shadowSlantX(double scale) =>
      backdrop == CharacterBackdrop.waterfront ? 5.5 * scale : 0;

  Color _deckShadowColor(int alpha) => backdrop == CharacterBackdrop.waterfront
      ? const Color(0xFF3A2518).withAlpha(alpha)
      : shadowColor.withAlpha(alpha);

  static void _drawDeckShadowOval(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required double angle,
  }) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        ),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
      )
      ..restore();
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
      old.enableDanceCamera != enableDanceCamera ||
      old.danceCameraStrength != danceCameraStrength ||
      old.locomote != locomote ||
      old.walkingPair != walkingPair ||
      old.partnerScene != partnerScene ||
      old.ensembleScenes != ensembleScenes ||
      old.ensembleExpressions != ensembleExpressions ||
      old.ensembleClips != ensembleClips ||
      old.synchronousEnsemble != synchronousEnsemble ||
      old.singingHeadMotion != singingHeadMotion ||
      old.cameraOverride != cameraOverride ||
      !listEquals(old.memberBacklights, memberBacklights) ||
      old.bodyGrade != bodyGrade ||
      old.heroStaging != heroStaging ||
      old._renderer != _renderer;
}
