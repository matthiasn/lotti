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

BoneDrawable _capsule(double w, double h, int color, {double dy = 0}) =>
    BoneDrawable(
      kind: BoneShapeKind.capsule,
      width: w,
      height: h,
      dy: dy,
      color: color,
      outlineColor: _outline,
      outlineWidth: 2,
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
        kind: BoneShapeKind.capsule,
        width: 15,
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
      restRotation: -0.55,
      drawable: BoneDrawable(
        kind: BoneShapeKind.capsule,
        width: 12,
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
        kind: BoneShapeKind.capsule,
        width: 9,
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
      drawable: _capsule(20, 52, _trouser, dy: 26),
    ),
    Bone(
      id: CatBones.legLowerR,
      parent: CatBones.legUpperR,
      pivotX: 0,
      pivotY: 52,
      z: 4,
      drawable: _capsule(17, 46, _trouser, dy: 23),
    ),
    const Bone(
      id: CatBones.footR,
      parent: CatBones.legLowerR,
      pivotX: 0,
      pivotY: 44,
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
      drawable: _capsule(20, 52, _trouser, dy: 26),
    ),
    Bone(
      id: CatBones.legLowerL,
      parent: CatBones.legUpperL,
      pivotX: 0,
      pivotY: 52,
      z: 7,
      drawable: _capsule(17, 46, _trouser, dy: 23),
    ),
    const Bone(
      id: CatBones.footL,
      parent: CatBones.legLowerL,
      pivotX: 0,
      pivotY: 44,
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
        width: 46,
        height: 30,
        cornerRadius: 10,
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
      drawable: _capsule(18, 46, _suit, dy: 23),
    ),
    Bone(
      id: CatBones.armLowerR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 46,
      z: 11,
      drawable: _capsule(15, 40, _suit, dy: 20),
    ),
    const Bone(
      id: CatBones.handR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 40,
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
      drawable: _capsule(18, 46, _suit, dy: 23),
    ),
    Bone(
      id: CatBones.armLowerL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 46,
      z: 17,
      drawable: _capsule(15, 40, _suit, dy: 20),
    ),
    const Bone(
      id: CatBones.handL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 40,
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
  static Clip get walk => const Clip(
    name: 'walk',
    duration: 1,
    locomotionSpeed: 64,
    root: SineRootChannel(
      bobAmplitude: -5,
      swayAmplitude: 3,
      leanAmplitude: 0.03,
    ),
    channels: {
      CatBones.legUpperL: SineChannel(amplitude: 0.55),
      CatBones.legUpperR: SineChannel(amplitude: 0.55, phase: 0.5),
      CatBones.legLowerL: SineChannel(amplitude: 0.4, phase: 0.12, bias: -0.35),
      CatBones.legLowerR: SineChannel(amplitude: 0.4, phase: 0.62, bias: -0.35),
      CatBones.footL: SineChannel(amplitude: 0.3, phase: 0.2),
      CatBones.footR: SineChannel(amplitude: 0.3, phase: 0.7),
      CatBones.armUpperL: SineChannel(amplitude: 0.4, phase: 0.5),
      CatBones.armUpperR: SineChannel(amplitude: 0.4),
      CatBones.armLowerL: SineChannel(amplitude: 0.18, bias: 0.25),
      CatBones.armLowerR: SineChannel(amplitude: 0.18, phase: 0.5, bias: 0.25),
      CatBones.torso: SineChannel(amplitude: 0.04, phase: 0.25),
      CatBones.tie: SineChannel(amplitude: 0.1, phase: 0.1),
      CatBones.tail0: SineChannel(amplitude: 0.16, bias: 0.1),
      CatBones.tail1: SineChannel(amplitude: 0.22, phase: 0.12),
      CatBones.tail2: SineChannel(amplitude: 0.3, phase: 0.24),
    },
  );

  static Clip get run => const Clip(
    name: 'run',
    duration: 0.62,
    locomotionSpeed: 168,
    root: SineRootChannel(
      bobAmplitude: -9,
      swayAmplitude: 4,
      leanAmplitude: 0.04,
    ),
    channels: {
      CatBones.legUpperL: SineChannel(amplitude: 0.8, bias: 0.15),
      CatBones.legUpperR: SineChannel(amplitude: 0.8, phase: 0.5, bias: 0.15),
      CatBones.legLowerL: SineChannel(amplitude: 0.7, phase: 0.1, bias: -0.6),
      CatBones.legLowerR: SineChannel(amplitude: 0.7, phase: 0.6, bias: -0.6),
      CatBones.footL: SineChannel(amplitude: 0.4, phase: 0.2),
      CatBones.footR: SineChannel(amplitude: 0.4, phase: 0.7),
      CatBones.armUpperL: SineChannel(amplitude: 0.7, phase: 0.5, bias: 0.2),
      CatBones.armUpperR: SineChannel(amplitude: 0.7, bias: 0.2),
      CatBones.armLowerL: SineChannel(amplitude: 0.2, bias: 0.7),
      CatBones.armLowerR: SineChannel(amplitude: 0.2, phase: 0.5, bias: 0.7),
      CatBones.torso: SineChannel(amplitude: 0.05, bias: 0.22),
      CatBones.tie: SineChannel(amplitude: 0.18, phase: 0.1, bias: 0.2),
      CatBones.tail0: SineChannel(amplitude: 0.2, bias: -0.2),
      CatBones.tail1: SineChannel(amplitude: 0.28, phase: 0.12),
      CatBones.tail2: SineChannel(amplitude: 0.36, phase: 0.24),
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
    root: SineRootChannel(bobAmplitude: -2, bobHarmonic: 1),
    channels: {
      CatBones.tail0: SineChannel(amplitude: 0.12, bias: 0.1),
      CatBones.tail1: SineChannel(amplitude: 0.16, phase: 0.15),
      CatBones.tail2: SineChannel(amplitude: 0.22, phase: 0.3),
    },
  );

  static List<Clip> get all => [walk, run, sit, jump, idle];
}
