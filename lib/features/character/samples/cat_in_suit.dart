/// A hand-authored "cat in a suit" rig + cycle library.
///
/// This is the Phase-1 stand-in for the offline AI rigging step: it exercises
/// the engine and the film-strip pipeline with a real, characterful skeleton
/// before any AI rig inference exists. Coordinates use Flutter's y-down space,
/// the hips at the origin, "up" toward negative y. Units are roughly pixels at
/// the authoring scale (~210 tall).
library;

import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/model/easing.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

// Palette (ARGB). Kept local to the sample; real characters carry their own
// colours in the rig art (plan decision D6 — no design-system colour tokens).
const int _suit = 0xFF2E3A59; // navy jacket
const int _trouser = 0xFF26304A; // darker navy
const int _fur = 0xFFE8A55A; // orange tabby
const int _furDark = 0xFFD08A3C; // tail tip / shading
const int _shirt = 0xFFF3EFE6; // collar
const int _tie = 0xFF7A2233; // maroon
const int _shoe = 0xFF15151F; // near-black
const int _outline = 0xFF1B1B2A;
const int _innerEar = 0xFFE7A39B; // soft pink ear
const int _muzzle = 0xFFF3DCB8; // lighter snout patch
const int _nose = 0xFFC8696B; // pink nose
const int _whisker = 0xFF8A765C; // muted whisker

/// Stable bone ids, also the keys clips animate.
class CatBones {
  static const hips = 'hips';
  static const torso = 'torso';
  static const tie = 'tie';
  static const tieLower = 'tie_lower';
  static const neck = 'neck';
  static const head = 'head';
  static const earL = 'ear.L';
  static const earR = 'ear.R';
  static const earInnerL = 'ear_inner.L';
  static const earInnerR = 'ear_inner.R';
  static const armUpperL = 'arm_upper.L';
  static const armLowerL = 'arm_lower.L';
  static const handL = 'hand.L';
  static const armUpperR = 'arm_upper.R';
  static const armLowerR = 'arm_lower.R';
  static const handR = 'hand.R';
  static const legUpperL = 'leg_upper.L';
  static const legLowerL = 'leg_lower.L';
  static const footL = 'foot.L';
  static const legUpperR = 'leg_upper.R';
  static const legLowerR = 'leg_lower.R';
  static const footR = 'foot.R';
  static const tail0 = 'tail_0';
  static const tail1 = 'tail_1';
  static const tail2 = 'tail_2';
  static const tail3 = 'tail_3';
  static const tail4 = 'tail_4';
  static const tail5 = 'tail_5';
  static const tail6 = 'tail_6';
}

/// A tapered limb segment: [w] wide at the joint (pivot) end, [wTip] at the far
/// end, so limbs read as wedged arms/legs with defined wrists/ankles instead of
/// constant-width sausages.
BoneDrawable _tapered(
  double w,
  double wTip,
  double h,
  int color, {
  double dy = 0,
  double outlineWidth = 2,
}) => BoneDrawable(
  kind: BoneShapeKind.taperedCapsule,
  width: w,
  widthTip: wTip,
  height: h,
  dy: dy,
  color: color,
  outlineColor: _outline,
  outlineWidth: outlineWidth,
);

/// A tail link — a short tapered segment in the drag chain. Kept as a helper so
/// the whole tail (length, taper, lift) is trivial to retune.
Bone _tailSeg(
  String id,
  String parent, {
  required double pivotY,
  required int z,
  required double restRotation,
  required double w,
  required double wTip,
  required double h,
  required double dy,
  double pivotX = 0,
  int color = _fur,
}) => Bone(
  id: id,
  parent: parent,
  pivotX: pivotX,
  pivotY: pivotY,
  z: z,
  restRotation: restRotation,
  drawable: BoneDrawable(
    kind: BoneShapeKind.taperedCapsule,
    width: w,
    widthTip: wTip,
    height: h,
    dy: dy,
    color: color,
    outlineColor: _outline,
    outlineWidth: 2,
  ),
);

/// Builds the cat-in-a-suit [RigSpec].
RigSpec buildCatInSuitRig() {
  final bones = <Bone>[
    // Tail: 7 short, thin tapering links that overlap (z-order) into ONE
    // continuous tail held UP and OUT in a graceful arc — alive and energetic,
    // not the old scorpion tight-curl and not a limp droop. Base lifts it
    // out-and-up off the rump; each link adds a small lift so it arcs. Behind
    // the body (negative z). Channels add a travelling drag wave.
    _tailSeg(
      CatBones.tail0,
      CatBones.hips,
      pivotX: 14,
      pivotY: 16,
      z: -7,
      restRotation: -1.9,
      w: 11,
      wTip: 10,
      h: 21,
      dy: 6.5,
    ),
    _tailSeg(
      CatBones.tail1,
      CatBones.tail0,
      pivotY: 14,
      z: -6,
      restRotation: -0.18,
      w: 10,
      wTip: 9,
      h: 20,
      dy: 6,
    ),
    _tailSeg(
      CatBones.tail2,
      CatBones.tail1,
      pivotY: 13,
      z: -5,
      restRotation: -0.16,
      w: 9,
      wTip: 8,
      h: 19,
      dy: 5.5,
    ),
    _tailSeg(
      CatBones.tail3,
      CatBones.tail2,
      pivotY: 12,
      z: -4,
      restRotation: -0.14,
      w: 8,
      wTip: 6,
      h: 18,
      dy: 5,
    ),
    _tailSeg(
      CatBones.tail4,
      CatBones.tail3,
      pivotY: 11,
      z: -3,
      restRotation: -0.12,
      w: 6,
      wTip: 5,
      h: 17,
      dy: 4.5,
    ),
    _tailSeg(
      CatBones.tail5,
      CatBones.tail4,
      pivotY: 10,
      z: -2,
      restRotation: -0.1,
      w: 5,
      wTip: 3,
      h: 16,
      dy: 4,
      color: _furDark,
    ),
    _tailSeg(
      CatBones.tail6,
      CatBones.tail5,
      pivotY: 9,
      z: -1,
      restRotation: -0.06,
      w: 4,
      wTip: 2,
      h: 14,
      dy: 3,
      color: _furDark,
    ),

    // Far (right) leg, drawn behind.
    Bone(
      id: CatBones.legUpperR,
      parent: CatBones.hips,
      pivotX: 11,
      pivotY: 16,
      z: 3,
      drawable: _tapered(29, 22, 68, _trouser, dy: 28),
    ),
    Bone(
      id: CatBones.legLowerR,
      parent: CatBones.legUpperR,
      pivotX: 0,
      pivotY: 60,
      z: 4,
      drawable: _tapered(24, 16, 60, _trouser, dy: 24),
    ),
    const Bone(
      id: CatBones.footR,
      parent: CatBones.legLowerR,
      pivotX: 0,
      pivotY: 50,
      z: 5,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 30,
        height: 16,
        // Toe points -x (local), which — through the locomotion mirror — makes
        // the shoe LEAD the direction of travel instead of trailing it.
        dx: -5,
        dy: 8,
        cornerRadius: 6,
        color: _shoe,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Near (left) leg.
    Bone(
      id: CatBones.legUpperL,
      parent: CatBones.hips,
      pivotX: -11,
      pivotY: 16,
      z: 6,
      drawable: _tapered(29, 22, 68, _trouser, dy: 28),
    ),
    Bone(
      id: CatBones.legLowerL,
      parent: CatBones.legUpperL,
      pivotX: 0,
      pivotY: 60,
      z: 7,
      drawable: _tapered(24, 16, 60, _trouser, dy: 24),
    ),
    const Bone(
      id: CatBones.footL,
      parent: CatBones.legLowerL,
      pivotX: 0,
      pivotY: 50,
      z: 8,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 30,
        height: 16,
        // Toe points -x (local) so the shoe leads travel — see footR.
        dx: -5,
        dy: 8,
        cornerRadius: 6,
        color: _shoe,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Pelvis / hips (root).
    const Bone(
      id: CatBones.hips,
      parent: null,
      pivotX: 0,
      pivotY: 0,
      z: 9,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 66,
        height: 38,
        dy: 4,
        cornerRadius: 16,
        color: _trouser,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Far (right) arm.
    Bone(
      id: CatBones.armUpperR,
      parent: CatBones.torso,
      pivotX: 30,
      pivotY: -80,
      z: 10,
      restRotation: -0.22, // hangs out from the shoulder, clear of the body
      drawable: _tapered(25, 18, 60, _suit, dy: 25),
    ),
    Bone(
      id: CatBones.armLowerR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 52,
      z: 11,
      drawable: _tapered(20, 13, 54, _suit, dy: 22),
    ),
    const Bone(
      id: CatBones.handR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 44,
      z: 12,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 18,
        height: 18,
        dy: 6,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Torso (suit jacket): a tapered wedge — wide at the shoulders (top),
    // narrowing to the waist (bottom) — so it reads as a tailored jacket with a
    // shoulder line, not a barrel/box. The pelvis flares back out below it.
    const Bone(
      id: CatBones.torso,
      parent: CatBones.hips,
      pivotX: 0,
      pivotY: -2,
      z: 13,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 64, // shoulders (top)
        widthTip: 50, // waist (bottom)
        height: 86,
        dy: -44,
        color: _suit,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Tie: a 2-link cloth pendulum over the jacket. The knot is short and nearly
    // rigid at the collar; the blade hangs off it, lags, and tapers to a point
    // — so it reads as a tie and trails like fabric, not a rigid stick.
    const Bone(
      id: CatBones.tie,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -80,
      z: 14,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 16, // knot
        widthTip: 14,
        height: 24,
        dy: 11,
        color: _tie,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    const Bone(
      id: CatBones.tieLower,
      parent: CatBones.tie,
      pivotX: 0,
      pivotY: 20,
      z: 14,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 16, // blade: widest at the knot, tapering to the point
        widthTip: 4,
        height: 38,
        dy: 18,
        color: _tie,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Near (left) arm.
    Bone(
      id: CatBones.armUpperL,
      parent: CatBones.torso,
      pivotX: -30,
      pivotY: -80,
      z: 16,
      restRotation: 0.22, // hangs out from the shoulder, clear of the body
      drawable: _tapered(25, 18, 60, _suit, dy: 25),
    ),
    Bone(
      id: CatBones.armLowerL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 52,
      z: 17,
      drawable: _tapered(20, 13, 54, _suit, dy: 22),
    ),
    const Bone(
      id: CatBones.handL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 44,
      z: 18,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 18,
        height: 18,
        dy: 6,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Pointed ears (behind the head crown so only the tips show above it),
    // each with a smaller inner ear nested on top.
    const Bone(
      id: CatBones.earL,
      parent: CatBones.head,
      pivotX: -24,
      pivotY: -52,
      z: 18,
      restRotation: -0.22,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 30,
        height: 44,
        dy: -16,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    const Bone(
      id: CatBones.earInnerL,
      parent: CatBones.earL,
      pivotX: 0,
      pivotY: 0,
      z: 19,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 15,
        height: 24,
        dy: -19,
        color: _innerEar,
      ),
    ),
    const Bone(
      id: CatBones.earR,
      parent: CatBones.head,
      pivotX: 24,
      pivotY: -52,
      z: 18,
      restRotation: 0.22,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 30,
        height: 44,
        dy: -16,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    const Bone(
      id: CatBones.earInnerR,
      parent: CatBones.earR,
      pivotX: 0,
      pivotY: 0,
      z: 19,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 15,
        height: 24,
        dy: -19,
        color: _innerEar,
      ),
    ),

    // Neck (control) + head.
    const Bone(
      id: CatBones.neck,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -84,
      z: 19,
    ),
    const Bone(
      id: CatBones.head,
      parent: CatBones.neck,
      pivotX: 0,
      pivotY: -6,
      z: 20,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 78,
        height: 72,
        dy: -30,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
  ];

  const face = FaceRig(
    anchorBoneId: CatBones.head,
    eyeOffsetX: 15,
    eyeOffsetY: -34,
    eyeRadiusX: 9,
    eyeRadiusY: 11,
    pupilRadius: 4,
    browOffsetY: -48,
    browWidth: 16,
    mouthOffsetY: -12,
    mouthWidth: 22,
    mouthHeight: 11,
    eyeColor: _shirt,
    pupilColor: _outline,
    browColor: _outline,
    mouthColor: _outline,
    muzzleWidth: 34,
    muzzleHeight: 24,
    muzzleColor: _muzzle,
    noseWidth: 10,
    noseHeight: 7,
    noseColor: _nose,
    whiskerColor: _whisker,
    whiskerLength: 22,
  );

  return RigSpec(name: 'cat_in_suit', bones: bones, face: face);
}

/// The Phase-1 cycle library: walk, run, sit, jump, idle.
class CatClips {
  // --- Shared walk step cycle (phase 0 = left-foot contact). ---
  // The right leg reuses these exact keys at phase 0.5. The point of keyframes
  // (vs sines) is the two distinct phases a sine can't make: a STANCE leg that
  // plants, straightens and sweeps back under the body, and a SWING leg whose
  // knee tucks so the foot lifts clear of the floor, then reaches out to plant.
  // Smooth, not snappy: the walk reads as a continuous step, so segments ease
  // with easeOut/easeInOut. No `*Back` overshoot in a cycle — it reverses a
  // limb mid-move and reads as a jerk; overshoot/settle is for the one-shots.
  static const _thighKeys = [
    Keyframe(p: 0, rotation: 0.5), // contact: leg reaches forward
    // Stance (p 0..0.5) is LINEAR so the foot sweeps back at constant velocity,
    // matching the constant locomotion travel — that's what stops the planted
    // foot smearing (skating) under the body.
    Keyframe(p: 0.25, rotation: 0.02, ease: Ease.linear), // midstance
    Keyframe(p: 0.5, rotation: -0.46, ease: Ease.linear), // toe-off
    Keyframe(p: 0.72, rotation: -0.08), // swing drive (eased)
    Keyframe(
      p: 0.88,
      rotation: 0.52,
      ease: Ease.easeOut,
    ), // reach for the plant
    Keyframe(p: 1, rotation: 0.5),
  ];
  // The knee BUCKLES on weight-acceptance (catches the body's mass), then is
  // HELD flat through midstance so the planted ankle doesn't migrate (no foot
  // creep), unfolding only at toe-off; then tucks hard in swing for clearance.
  static const _shinKeys = [
    Keyframe(p: 0, rotation: -0.12), // contact: nearly straight to reach
    Keyframe(
      p: 0.14,
      rotation: -0.5,
      ease: Ease.easeOut,
    ), // weight-accept buckle
    Keyframe(p: 0.28, rotation: -0.45), // held low — the body sinks onto it
    Keyframe(
      p: 0.42,
      rotation: -0.45,
      ease: Ease.linear,
    ), // ankle pinned, no creep
    Keyframe(p: 0.5, rotation: -0.28, ease: Ease.linear), // unfolds at toe-off
    Keyframe(p: 0.7, rotation: -1.25), // swing: knee tucks, foot clears
    Keyframe(p: 0.88, rotation: -0.26, ease: Ease.easeOut), // extends to plant
    Keyframe(p: 1, rotation: -0.12),
  ];
  // Foot tilt signs are negated relative to a naive "toe at +x" foot because the
  // shoe toe points -x (see footL/R dx) — heel-strike still lifts the toe, etc.
  static const _footKeys = [
    Keyframe(p: 0, rotation: -0.28), // heel strike: toe up, heel leads
    Keyframe(p: 0.14, ease: Ease.easeOut), // rolls FLAT — the grounding beat
    Keyframe(p: 0.42, rotation: -0.05), // stays flat through stance
    Keyframe(p: 0.52, rotation: -0.5), // toe-off push
    Keyframe(
      p: 0.66,
      rotation: 0.25,
      ease: Ease.easeOut,
    ), // swing: dorsiflex to clear
    Keyframe(p: 0.86, rotation: 0.18), // held lifted through swing
    Keyframe(
      p: 1,
      rotation: -0.28,
      ease: Ease.easeOut,
    ), // re-cock for heel strike
  ];

  // --- Run step cycle (phase 0 = contact). A run has a SHORT stance (the foot
  // is on the ground only ~p 0..0.18, linear so it pins) and a long flight with
  // a deep knee tuck — so the foot plants briefly then flies, instead of pure
  // sines that never hold a contact. ---
  static const _runThighKeys = [
    Keyframe(
      p: 0,
      rotation: 0.42,
    ), // contact: land UNDER the hip (not over-reaching)
    Keyframe(
      p: 0.13,
      rotation: 0.05,
      ease: Ease.linear,
    ), // linear pinned stance
    Keyframe(
      p: 0.2,
      rotation: -0.28,
      ease: Ease.linear,
    ), // toe-off: end of stance
    Keyframe(p: 0.32, rotation: -0.7), // drive back HARD — propulsion
    Keyframe(p: 0.62, rotation: 0.1), // flight: knee leads forward
    Keyframe(
      p: 0.85,
      rotation: 0.5,
      ease: Ease.easeOut,
    ), // reach for next plant
    Keyframe(p: 1, rotation: 0.42),
  ];
  static const _runShinKeys = [
    Keyframe(p: 0, rotation: -0.22), // contact: near-straight to land
    Keyframe(
      p: 0.07,
      rotation: -0.78,
      ease: Ease.easeOut,
    ), // hard absorb (down-accent)
    Keyframe(
      p: 0.2,
      rotation: -0.08,
      ease: Ease.linear,
    ), // extend — propulsive push-off
    Keyframe(p: 0.32, rotation: -1.05), // fold for flight
    Keyframe(p: 0.52, rotation: -1.85), // DEEP flight tuck — heel to rump
    Keyframe(
      p: 0.85,
      rotation: -0.32,
      ease: Ease.easeOut,
    ), // whips out to reach
    Keyframe(p: 1, rotation: -0.22),
  ];
  static const _runFootKeys = [
    Keyframe(p: 0, rotation: -0.2), // heel contact
    Keyframe(p: 0.1, rotation: -0.12, ease: Ease.easeOut), // rolls toward flat
    Keyframe(p: 0.2, rotation: -0.34, ease: Ease.linear), // rolls onto the ball
    Keyframe(p: 0.32, rotation: -0.7, ease: Ease.easeIn), // hard toe-off
    Keyframe(p: 0.52, rotation: 0.34, ease: Ease.easeOut), // flight dorsiflex
    Keyframe(p: 0.85, rotation: 0.12),
    Keyframe(p: 1, rotation: -0.2),
  ];

  static Clip get walk => const Clip(
    name: 'walk',
    duration: 1,
    // Speed-matched to the stance foot's backward sweep so the planted foot
    // holds world-x as the body travels over it (no moonwalk / creep). Tuned
    // against the walk_travel onion until the footprints land as tight stamps.
    locomotionSpeed: 225,
    root: SineRootChannel(
      // The COM drops onto each footfall (weight acceptance) and rises at
      // passing — the double-bounce that reads as carrying mass. ~5% of rig
      // height. bobPhase puts the lowest point on the contacts (p=0, 0.5).
      bobAmplitude: -7,
      bobPhase:
          0.345, // COM trough lands just after contact — sinks onto the plant
      swayAmplitude: 6,
      // Phase 0.5 puts the COM OVER the planted (stance) foot at midstance. The
      // previous default (0) lurched the body AWAY from the support foot — an
      // off-balance rock that read as a limp.
      swayPhase: 0.5,
      leanAmplitude: 0.025,
    ),
    channels: {
      // --- Line of action: a real pelvic list that propagates up a soft spine
      // and is re-leveled at the neck so the gaze holds steady (not a bobble-
      // head). The pelvis lists ~8°; the chest carries some of it (trunk
      // articulates instead of staying a plank); the neck/head cancel it back
      // out so the eyeline barely moves.
      CatBones.hips: SineChannel(amplitude: 0.13),
      CatBones.torso: SineChannel(amplitude: 0.07),
      CatBones.neck: SineChannel(amplitude: 0.11, phase: 0.5),
      CatBones.head: SineChannel(amplitude: 0.04, phase: 0.5),

      // --- Legs: a real keyframed step, not a pendulum. Left leg drives the
      // cycle; the right shares the same keys half a beat later (phase 0.5). ---
      CatBones.legUpperL: KeyframeChannel(_thighKeys, smooth: true),
      CatBones.legUpperR: KeyframeChannel(_thighKeys, phase: 0.5, smooth: true),
      CatBones.legLowerL: KeyframeChannel(_shinKeys, smooth: true),
      CatBones.legLowerR: KeyframeChannel(_shinKeys, phase: 0.5, smooth: true),
      CatBones.footL: KeyframeChannel(_footKeys, smooth: true),
      CatBones.footR: KeyframeChannel(_footKeys, phase: 0.5, smooth: true),

      // --- Arms: broken L/R symmetry (so the silhouette is never a perfect
      // mirror — the "machine" tell) with a real bent elbow + forearm drag. ---
      // Subtle amplitude difference breaks the perfect-mirror "machine" tell,
      // but the resting bias is kept symmetric (0) — a biased rest tilted one
      // arm forward and one back, which read as a postural limp.
      CatBones.armUpperL: SineChannel(amplitude: 0.3, phase: 0.5),
      CatBones.armUpperR: SineChannel(amplitude: 0.28),
      // Forearm bend kept small + outward (bias 0.18) so the hands hang at the
      // outer thighs instead of swinging across into the body's centre.
      CatBones.armLowerL: SineChannel(amplitude: 0.16, phase: 0.18, bias: 0.18),
      CatBones.armLowerR: SineChannel(amplitude: 0.16, phase: 0.68, bias: 0.18),

      // --- Ears flick a beat behind the head bob — the cheapest "alive" tell,
      // and they were animated in nothing before. ---
      CatBones.earL: SineChannel(amplitude: 0.06, phase: 0.52),
      CatBones.earR: SineChannel(amplitude: 0.06, phase: 0.58),

      // --- Tie: knot barely moves; the blade lags far behind (0.43) and the
      // tip gets a harmonic so it overshoots — drapes, not hinges. ---
      CatBones.tie: SineChannel(amplitude: 0.07, phase: 0.18),
      CatBones.tieLower: SineChannel(
        amplitude: 0.2,
        phase: 0.43,
        harmonicAmplitude: 0.05,
        harmonicPhase: 0.5,
      ),

      // --- Tail: a real travelling wave. The amplitude ramps steeply and the
      // phase lags ~0.10 per link (total ~0.60 base->tip), so the whip visibly
      // travels down the chain; the last three links carry growing 2nd
      // harmonics so the tip cracks/overshoots instead of swinging as a blade.
      CatBones.tail0: SineChannel(amplitude: 0.03, bias: 0.05),
      CatBones.tail1: SineChannel(amplitude: 0.05, phase: 0.1),
      CatBones.tail2: SineChannel(amplitude: 0.08, phase: 0.2),
      CatBones.tail3: SineChannel(amplitude: 0.12, phase: 0.3),
      CatBones.tail4: SineChannel(
        amplitude: 0.18,
        phase: 0.4,
        harmonicAmplitude: 0.05,
        harmonicPhase: 0.1,
      ),
      CatBones.tail5: SineChannel(
        amplitude: 0.26,
        phase: 0.5,
        harmonicAmplitude: 0.1,
        harmonicPhase: 0.2,
      ),
      CatBones.tail6: SineChannel(
        amplitude: 0.34,
        phase: 0.6,
        harmonicAmplitude: 0.2,
        harmonicPhase: 0.3,
      ),
    },
  );

  static Clip get run => const Clip(
    name: 'run',
    duration: 0.62,
    // Speed-matched to the linear-stance foot sweep (shortened contact) so the
    // brief sprint contact pins; tuned in the 600-660 window against
    // run_travel.png until the shoes stamp instead of smear.
    locomotionSpeed: 640,
    root: SineRootChannel(
      // A run is BALLISTIC: throw the COM high into a flight arc (the sine's
      // zero-velocity apex is the natural hang) so it reads as a run, not a fast
      // walk. Trough (lowest) lands on each contact (p=0, 0.5).
      bobAmplitude: -14,
      bobPhase: 0.345,
      swayAmplitude: 4,
      leanAmplitude: 0.06,
    ),
    channels: {
      // Spine = a confident C-curve, pulsed (not a frozen plank): the pelvis
      // tucks under, the chest carries the forward lean and reaches on the drive
      // / gathers on recovery; neck/head poke up so the gaze leads.
      CatBones.hips: SineChannel(amplitude: 0.1, bias: 0.14),
      CatBones.torso: SineChannel(
        amplitude: 0.16,
        phase: 0.5,
        bias: 0.3,
        harmonicAmplitude: 0.05,
      ),
      CatBones.neck: SineChannel(amplitude: 0.09, bias: -0.26),
      CatBones.head: SineChannel(amplitude: 0.06, phase: 0.5, bias: -0.16),
      CatBones.earL: SineChannel(amplitude: 0.1, phase: 0.52),
      CatBones.earR: SineChannel(amplitude: 0.1, phase: 0.58),

      // Legs reach further with a hard knee snap (strong 2nd harmonic) and a
      // foot that plants then kicks back on toe-off.
      CatBones.legUpperL: KeyframeChannel(_runThighKeys, smooth: true),
      CatBones.legUpperR: KeyframeChannel(
        _runThighKeys,
        phase: 0.5,
        smooth: true,
      ),
      CatBones.legLowerL: KeyframeChannel(_runShinKeys, smooth: true),
      CatBones.legLowerR: KeyframeChannel(
        _runShinKeys,
        phase: 0.5,
        smooth: true,
      ),
      CatBones.footL: KeyframeChannel(_runFootKeys, smooth: true),
      CatBones.footR: KeyframeChannel(_runFootKeys, phase: 0.5, smooth: true),

      // Pumping arms, elbows well bent — broken L/R so they aren't matched
      // pistons.
      CatBones.armUpperL: SineChannel(amplitude: 0.6, phase: 0.5, bias: 0.18),
      CatBones.armUpperR: SineChannel(amplitude: 0.54, bias: 0.16),
      // Elbows bent up to run, but bias kept off the body centreline.
      CatBones.armLowerL: SineChannel(amplitude: 0.2, phase: 0.1, bias: 0.5),
      CatBones.armLowerR: SineChannel(amplitude: 0.2, phase: 0.6, bias: 0.5),

      // Tie + tail stream back and whip (7-link travelling wave, strong tip).
      CatBones.tie: SineChannel(amplitude: 0.12, phase: 0.1, bias: 0.18),
      CatBones.tieLower: SineChannel(amplitude: 0.24, phase: 0.26, bias: 0.3),
      CatBones.tail0: SineChannel(amplitude: 0.06, bias: -0.08),
      CatBones.tail1: SineChannel(amplitude: 0.1, phase: 0.06),
      CatBones.tail2: SineChannel(amplitude: 0.14, phase: 0.12),
      CatBones.tail3: SineChannel(amplitude: 0.18, phase: 0.18),
      CatBones.tail4: SineChannel(amplitude: 0.22, phase: 0.24),
      CatBones.tail5: SineChannel(amplitude: 0.27, phase: 0.3),
      CatBones.tail6: SineChannel(
        amplitude: 0.33,
        phase: 0.36,
        harmonicAmplitude: 0.16,
        harmonicPhase: 0.42,
      ),
    },
  );

  static Clip get sit => const Clip(
    name: 'sit',
    duration: 1.4,
    loop: false,
    // Anticipation (a small lift), then sink past the target and settle back up
    // (easeOutBack) so the body lands with weight instead of stopping dead.
    root: KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 0.12, dy: -4, ease: Ease.easeOut),
      RootKeyframe(p: 0.62, dy: 41, ease: Ease.easeIn),
      RootKeyframe(p: 1, dy: 38, ease: Ease.easeOutBack),
    ]),
    channels: {
      CatBones.legUpperL: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.55, rotation: 1.15),
        Keyframe(p: 1, rotation: 1.1),
      ]),
      CatBones.legUpperR: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.55, rotation: 1.15),
        Keyframe(p: 1, rotation: 1.1),
      ]),
      CatBones.legLowerL: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.55, rotation: -1.5),
        Keyframe(p: 1, rotation: -1.45),
      ]),
      CatBones.legLowerR: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.55, rotation: -1.5),
        Keyframe(p: 1, rotation: -1.45),
      ]),
      CatBones.torso: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.55, rotation: 0.12),
        Keyframe(p: 1, rotation: 0.08),
      ]),
      CatBones.armUpperL: KeyframeChannel([
        Keyframe(p: 0, rotation: 0.12),
        Keyframe(p: 1, rotation: 0.35),
      ]),
      CatBones.armUpperR: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.12),
        Keyframe(p: 1, rotation: -0.35),
      ]),
      // Cloth follow-through: as the body sinks and settles, the tail tip, tie
      // and ears swing past then settle back (easeOutBack) instead of freezing
      // dead the instant the body stops — the inertial settle.
      CatBones.tail4: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.62, rotation: 0.34, ease: Ease.easeIn),
        Keyframe(p: 0.82, rotation: -0.1, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail5: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.66, rotation: 0.46, ease: Ease.easeIn),
        Keyframe(p: 0.86, rotation: -0.16, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail6: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.7, rotation: 0.6, ease: Ease.easeIn),
        Keyframe(p: 0.9, rotation: -0.22, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tieLower: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.62, rotation: 0.22, ease: Ease.easeIn),
        Keyframe(p: 0.84, rotation: -0.08, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.earL: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.62, rotation: 0.1, ease: Ease.easeIn),
        Keyframe(p: 0.82, rotation: -0.04, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
    },
  );

  static Clip get jump => const Clip(
    name: 'jump',
    duration: 1,
    loop: false,
    root: KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 0.22, dy: 20, ease: Ease.easeOut),
      RootKeyframe(p: 0.46, dy: -64, ease: Ease.easeOut),
      RootKeyframe(p: 0.6, dy: -70),
      RootKeyframe(p: 0.78, dy: 16, ease: Ease.easeIn),
      RootKeyframe(p: 0.9, dy: 6, ease: Ease.easeOut),
      RootKeyframe(p: 1),
    ]),
    channels: {
      CatBones.legUpperL: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: 0.8),
        Keyframe(p: 0.46, rotation: 0.45), // apex: knees tuck up
        Keyframe(p: 0.78, rotation: 0.9),
        Keyframe(p: 1),
      ]),
      CatBones.legUpperR: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: 0.8),
        Keyframe(p: 0.46, rotation: 0.45), // apex: knees tuck up
        Keyframe(p: 0.78, rotation: 0.9),
        Keyframe(p: 1),
      ]),
      CatBones.legLowerL: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: -1.3),
        Keyframe(p: 0.46, rotation: -0.95), // apex: shins folded under
        Keyframe(p: 0.78, rotation: -1.4),
        Keyframe(p: 1),
      ]),
      CatBones.legLowerR: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: -1.3),
        Keyframe(p: 0.46, rotation: -0.95), // apex: shins folded under
        Keyframe(p: 0.78, rotation: -1.4),
        Keyframe(p: 1),
      ]),
      // Squash on crouch/land, stretch at launch — via torso scaleY.
      CatBones.torso: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, scaleY: 0.9),
        Keyframe(p: 0.46, scaleY: 1.12),
        Keyframe(p: 0.78, scaleY: 0.88),
        Keyframe(p: 1),
      ]),
      CatBones.armUpperL: KeyframeChannel([
        Keyframe(p: 0, rotation: 0.12),
        Keyframe(p: 0.22, rotation: -0.6),
        Keyframe(p: 0.46, rotation: -2.4),
        Keyframe(p: 0.78, rotation: -0.4),
        Keyframe(p: 1, rotation: 0.12),
      ]),
      CatBones.armUpperR: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.12),
        Keyframe(p: 0.22, rotation: 0.6),
        Keyframe(p: 0.46, rotation: 2.4),
        Keyframe(p: 0.78, rotation: 0.4),
        Keyframe(p: 1, rotation: -0.12),
      ]),
      // Cloth follow-through: the tail tip / tie fly up on the launch, whip down
      // on the landing, then overshoot and settle (easeOutBack) — not frozen.
      CatBones.tail4: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.46, rotation: -0.3, ease: Ease.easeOut),
        Keyframe(p: 0.78, rotation: 0.42, ease: Ease.easeIn),
        Keyframe(p: 0.92, rotation: -0.12, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail5: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.46, rotation: -0.42, ease: Ease.easeOut),
        Keyframe(p: 0.78, rotation: 0.54, ease: Ease.easeIn),
        Keyframe(p: 0.92, rotation: -0.18, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail6: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.46, rotation: -0.56, ease: Ease.easeOut),
        Keyframe(p: 0.78, rotation: 0.68, ease: Ease.easeIn),
        Keyframe(p: 0.92, rotation: -0.24, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tieLower: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.46, rotation: -0.26, ease: Ease.easeOut),
        Keyframe(p: 0.78, rotation: 0.32, ease: Ease.easeIn),
        Keyframe(p: 0.92, rotation: -0.1, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
    },
  );

  static Clip get idle => const Clip(
    name: 'idle',
    duration: 3.6,
    // One slow rise/fall per cycle — the body settling with each breath.
    root: SineRootChannel(bobAmplitude: -2, bobHarmonic: 1),
    channels: {
      // Breathing: the chest expands (scaleY) and the spine sways a hair, so the
      // character is never a frozen frame even when standing still. The face's
      // autonomic blink + eye-darts layer on top for the rest of the "alive".
      CatBones.torso: SineChannel(amplitude: 0.012, scaleYAmplitude: 0.03),
      CatBones.hips: SineChannel(amplitude: 0.015, phase: 0.5),
      // Slow head drift / settle (a calm look-around), offset from the breath.
      CatBones.neck: SineChannel(amplitude: 0.03, phase: 0.2),
      CatBones.head: SineChannel(amplitude: 0.025, phase: 0.35),
      CatBones.armLowerL: SineChannel(amplitude: 0.03, bias: 0.18),
      CatBones.armLowerR: SineChannel(amplitude: 0.03, phase: 0.5, bias: 0.18),
      // Ears twitch slowly (listening) and the tail does a lazy travelling sway
      // down all 7 links — the "alive at rest" tell.
      CatBones.tie: SineChannel(amplitude: 0.015, phase: 0.2),
      CatBones.tieLower: SineChannel(amplitude: 0.035, phase: 0.45, bias: 0.04),
      CatBones.earL: SineChannel(amplitude: 0.03, phase: 0.3),
      CatBones.earR: SineChannel(amplitude: 0.03, phase: 0.8),
      CatBones.tail0: SineChannel(amplitude: 0.04, bias: 0.05),
      CatBones.tail1: SineChannel(amplitude: 0.06, phase: 0.08),
      CatBones.tail2: SineChannel(amplitude: 0.08, phase: 0.16),
      CatBones.tail3: SineChannel(amplitude: 0.11, phase: 0.24),
      CatBones.tail4: SineChannel(amplitude: 0.14, phase: 0.32),
      CatBones.tail5: SineChannel(amplitude: 0.17, phase: 0.4),
      CatBones.tail6: SineChannel(
        amplitude: 0.21,
        phase: 0.48,
        harmonicAmplitude: 0.07,
        harmonicPhase: 0.5,
      ),
    },
  );

  static List<Clip> get all => [walk, run, sit, jump, idle];
}
