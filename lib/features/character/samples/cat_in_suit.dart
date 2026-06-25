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

/// Builds the cat-in-a-suit [RigSpec].
RigSpec buildCatInSuitRig() {
  final bones = <Bone>[
    // Tail (behind the body), three segments for drag.
    // Tail: rises up-and-out from the right hip, then curls back over — three
    // segments so it reads as a smooth S, not a stick. Drawn behind the body.
    const Bone(
      id: CatBones.tail0,
      parent: CatBones.hips,
      pivotX: 18,
      pivotY: 6,
      z: 0,
      restRotation: -2.25,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 16,
        widthTip: 12,
        height: 38,
        dy: 17,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    const Bone(
      id: CatBones.tail1,
      parent: CatBones.tail0,
      pivotX: 0,
      pivotY: 36,
      z: 1,
      restRotation: -0.82,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 12,
        widthTip: 8,
        height: 32,
        dy: 14,
        color: _fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    const Bone(
      id: CatBones.tail2,
      parent: CatBones.tail1,
      pivotX: 0,
      pivotY: 30,
      z: 2,
      restRotation: -0.55,
      drawable: BoneDrawable(
        kind: BoneShapeKind.taperedCapsule,
        width: 9,
        widthTip: 3,
        height: 26,
        dy: 12,
        color: _furDark,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Far (right) leg, drawn behind.
    Bone(
      id: CatBones.legUpperR,
      parent: CatBones.hips,
      pivotX: 13,
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
        dx: 5,
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
      pivotX: -13,
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
        dx: 5,
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
        width: 52,
        height: 32,
        cornerRadius: 12,
        color: _trouser,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Far (right) arm.
    Bone(
      id: CatBones.armUpperR,
      parent: CatBones.torso,
      pivotX: 28,
      pivotY: -70,
      z: 10,
      restRotation: -0.12,
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

    // Torso (suit jacket).
    const Bone(
      id: CatBones.torso,
      parent: CatBones.hips,
      pivotX: 0,
      pivotY: -2,
      z: 13,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 58,
        height: 86,
        dy: -44,
        cornerRadius: 16,
        color: _suit,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Collar + tie over the jacket.
    const Bone(
      id: CatBones.tie,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -80,
      z: 14,
      drawable: BoneDrawable(
        kind: BoneShapeKind.capsule,
        width: 13,
        height: 52,
        dy: 28,
        color: _tie,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Near (left) arm.
    Bone(
      id: CatBones.armUpperL,
      parent: CatBones.torso,
      pivotX: -28,
      pivotY: -70,
      z: 16,
      restRotation: 0.12,
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
  static const _thighKeys = [
    Keyframe(p: 0, rotation: 0.42), // contact: leg reaches forward
    Keyframe(p: 0.25, rotation: 0.05), // midstance: under the hips
    Keyframe(p: 0.5, rotation: -0.42), // toe-off: swept back
    Keyframe(p: 0.72, rotation: -0.08), // swing: driving through, knee tucked
    Keyframe(p: 0.88, rotation: 0.5), // reach: stretches out for the next plant
    Keyframe(p: 1, rotation: 0.42),
  ];
  static const _shinKeys = [
    Keyframe(p: 0, rotation: -0.16), // contact: nearly straight
    Keyframe(p: 0.12, rotation: -0.46), // weight-accept: bends to absorb
    Keyframe(p: 0.3, rotation: -0.1), // midstance: straightens, carries weight
    Keyframe(p: 0.5, rotation: -0.6), // toe-off: starts to fold
    Keyframe(p: 0.7, rotation: -1.3), // swing: tucked hard so the foot clears
    Keyframe(p: 0.86, rotation: -0.32), // extends for contact
    Keyframe(p: 1, rotation: -0.16),
  ];
  static const _footKeys = [
    Keyframe(p: 0, rotation: 0.16), // contact: heel leads
    Keyframe(p: 0.25), // flat through stance
    Keyframe(p: 0.5, rotation: 0.5), // toe-off: pushes, points down
    Keyframe(p: 0.7, rotation: -0.25), // swing: lifts (dorsiflex) to clear
    Keyframe(p: 0.86), // levels for the plant
    Keyframe(p: 1, rotation: 0.16),
  ];

  static Clip get walk => const Clip(
    name: 'walk',
    duration: 1,
    locomotionSpeed: 64,
    root: SineRootChannel(
      // Weight drops on each footfall (twice per cycle) and rises at passing.
      // The bob is the *only* big body motion — sway/lean are kept tiny so the
      // torso stays contained and the legs carry the walk (a busy torso reads as
      // a seasick wobble, not weight).
      bobAmplitude: -6,
      bobPhase: 0.05,
      swayAmplitude: 1.5,
      leanAmplitude: 0.015,
    ),
    channels: {
      // --- Spine chain: the single biggest fix for the "cardboard plank". ---
      // Pelvis lists once per cycle (toward the swing leg); the torso
      // counter-rotates against it and the neck/head re-counter so the gaze
      // stays roughly level. The net effect is a body that articulates through
      // a soft S instead of riding as one rigid block.
      CatBones.hips: SineChannel(amplitude: 0.06),
      // Gentle counter-rotation only — no bone-scale squash here, since the
      // head/arms hang off the torso and any torso scale would distort them.
      CatBones.torso: SineChannel(amplitude: 0.07, phase: 0.5),
      // The head stays a near-steady anchor (a walking head barely moves); just
      // enough counter to keep the gaze level, not a bobble-head.
      CatBones.neck: SineChannel(amplitude: 0.035),
      CatBones.head: SineChannel(amplitude: 0.02, phase: 0.5),

      // --- Legs: a real keyframed step, not a pendulum. Left leg drives the
      // cycle; the right shares the same keys half a beat later (phase 0.5). ---
      CatBones.legUpperL: KeyframeChannel(_thighKeys),
      CatBones.legUpperR: KeyframeChannel(_thighKeys, phase: 0.5),
      CatBones.legLowerL: KeyframeChannel(_shinKeys),
      CatBones.legLowerR: KeyframeChannel(_shinKeys, phase: 0.5),
      CatBones.footL: KeyframeChannel(_footKeys),
      CatBones.footR: KeyframeChannel(_footKeys, phase: 0.5),

      // --- Arms: swing opposite the same-side leg, forearm drags a beat. ---
      CatBones.armUpperL: SineChannel(amplitude: 0.42, phase: 0.5),
      CatBones.armUpperR: SineChannel(amplitude: 0.4),
      CatBones.armLowerL: SineChannel(amplitude: 0.2, phase: 0.12, bias: 0.3),
      CatBones.armLowerR: SineChannel(amplitude: 0.2, phase: 0.62, bias: 0.3),

      // --- Secondary: tie + tail drag, amplitude grows and phase lags down the
      // chain (overlapping action) so they whip a beat behind the body. ---
      CatBones.tie: SineChannel(amplitude: 0.12, phase: 0.15),
      CatBones.tail0: SineChannel(amplitude: 0.18, bias: 0.1),
      CatBones.tail1: SineChannel(amplitude: 0.26, phase: 0.14),
      CatBones.tail2: SineChannel(amplitude: 0.34, phase: 0.28),
    },
  );

  static Clip get run => const Clip(
    name: 'run',
    duration: 0.62,
    locomotionSpeed: 168,
    root: SineRootChannel(
      // A run throws the body higher between strides and lands harder.
      bobAmplitude: -11,
      bobPhase: 0.05,
      swayAmplitude: 4,
      leanAmplitude: 0.05,
    ),
    channels: {
      // Spine chain, run-tuned: the pelvis drives harder, the chest pitches
      // forward into the run (bias) while counter-rotating, and the neck/head
      // poke up so the gaze leads instead of face-planting into the lean.
      CatBones.hips: SineChannel(amplitude: 0.1),
      CatBones.torso: SineChannel(amplitude: 0.13, phase: 0.5, bias: 0.26),
      CatBones.neck: SineChannel(amplitude: 0.09, bias: -0.18),
      CatBones.head: SineChannel(amplitude: 0.06, phase: 0.5, bias: -0.12),

      // Legs reach further with a hard knee snap (strong 2nd harmonic) and a
      // foot that plants then kicks back on toe-off.
      CatBones.legUpperL: SineChannel(amplitude: 0.82, bias: 0.15),
      CatBones.legUpperR: SineChannel(amplitude: 0.82, phase: 0.5, bias: 0.15),
      CatBones.legLowerL: SineChannel(
        amplitude: 0.68,
        phase: 0.1,
        bias: -0.62,
        harmonicAmplitude: 0.32,
        harmonicPhase: 0.08,
      ),
      CatBones.legLowerR: SineChannel(
        amplitude: 0.68,
        phase: 0.6,
        bias: -0.62,
        harmonicAmplitude: 0.32,
        harmonicPhase: 0.58,
      ),
      CatBones.footL: SineChannel(amplitude: 0.46, phase: 0.22, bias: 0.18),
      CatBones.footR: SineChannel(amplitude: 0.46, phase: 0.72, bias: 0.18),

      // Pumping arms, elbows well bent.
      CatBones.armUpperL: SineChannel(amplitude: 0.72, phase: 0.5, bias: 0.2),
      CatBones.armUpperR: SineChannel(amplitude: 0.72, bias: 0.2),
      CatBones.armLowerL: SineChannel(amplitude: 0.22, phase: 0.1, bias: 0.72),
      CatBones.armLowerR: SineChannel(
        amplitude: 0.22,
        phase: 0.6,
        bias: 0.72,
      ),

      // Tail streams back and whips with strong overlap.
      CatBones.tie: SineChannel(amplitude: 0.2, phase: 0.1, bias: 0.2),
      CatBones.tail0: SineChannel(amplitude: 0.22, bias: -0.22),
      CatBones.tail1: SineChannel(amplitude: 0.3, phase: 0.14),
      CatBones.tail2: SineChannel(amplitude: 0.4, phase: 0.28),
    },
  );

  static Clip get sit => const Clip(
    name: 'sit',
    duration: 1.4,
    loop: false,
    root: KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 0.55, dy: 34),
      RootKeyframe(p: 1, dy: 38),
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
        Keyframe(p: 0.46, rotation: -0.2),
        Keyframe(p: 0.78, rotation: 0.9),
        Keyframe(p: 1),
      ]),
      CatBones.legUpperR: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: 0.8),
        Keyframe(p: 0.46, rotation: -0.2),
        Keyframe(p: 0.78, rotation: 0.9),
        Keyframe(p: 1),
      ]),
      CatBones.legLowerL: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: -1.3),
        Keyframe(p: 0.46, rotation: -0.1),
        Keyframe(p: 0.78, rotation: -1.4),
        Keyframe(p: 1),
      ]),
      CatBones.legLowerR: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.22, rotation: -1.3),
        Keyframe(p: 0.46, rotation: -0.1),
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
      // A relaxed tail sway with gentle overlap down the segments.
      CatBones.tail0: SineChannel(amplitude: 0.13, bias: 0.1),
      CatBones.tail1: SineChannel(amplitude: 0.18, phase: 0.16),
      CatBones.tail2: SineChannel(amplitude: 0.26, phase: 0.32),
    },
  );

  static List<Clip> get all => [walk, run, sit, jump, idle];
}
