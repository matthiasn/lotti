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
import 'package:lotti/features/character/model/dance_phrase.dart';
import 'package:lotti/features/character/model/easing.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

// Palette (ARGB). Kept local to the sample; real characters carry their own
// colours in the rig art (plan decision D6 — no design-system colour tokens).
const int _suit = 0xFF2E3A59; // navy jacket
const int _trouser = 0xFF26304A; // darker navy
const int _trouserRear = 0xFF202941; // slightly darker rear leg
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

const double kDanceLeadLegWidthScale = 1.48;
const double kDanceLeadArmWidthScale = 1.18;

/// Fur/face colours for a cat-in-suit rig variant.
///
/// The suit stays fixed so paired cats still read as the same act; the palette
/// only swaps the character fur and face markings.
class CatInSuitPalette {
  const CatInSuitPalette({
    required this.fur,
    required this.furDark,
    required this.innerEar,
    required this.muzzle,
    required this.nose,
    required this.whisker,
    required this.brow,
  });

  final int fur;
  final int furDark;
  final int innerEar;
  final int muzzle;
  final int nose;
  final int whisker;
  final int brow;

  static const orangeTabby = CatInSuitPalette(
    fur: _fur,
    furDark: _furDark,
    innerEar: _innerEar,
    muzzle: _muzzle,
    nose: _nose,
    whisker: _whisker,
    brow: _outline,
  );

  static const silverTabby = CatInSuitPalette(
    fur: 0xFFB8BBC8,
    furDark: 0xFF80869B,
    innerEar: 0xFFD8A7B4,
    muzzle: 0xFFEDE8DC,
    nose: 0xFFB56B7C,
    whisker: 0xFF6F7180,
    brow: _outline,
  );

  static const darkBrown = CatInSuitPalette(
    fur: 0xFF302820,
    furDark: 0xFF17110D,
    innerEar: 0xFF8E6A61,
    muzzle: 0xFFC9A77F,
    nose: 0xFF8F555C,
    whisker: 0xFFE7D7C0,
    brow: 0xFFF1E2C9,
  );
}

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
  static const armBicepL = 'arm_bicep.L';
  static const armLowerL = 'arm_lower.L';
  static const handL = 'hand.L';
  static const armUpperR = 'arm_upper.R';
  static const armBicepR = 'arm_bicep.R';
  static const armLowerR = 'arm_lower.R';
  static const handR = 'hand.R';
  static const legUpperL = 'leg_upper.L';
  static const legQuadL = 'leg_quad.L';
  static const legLowerL = 'leg_lower.L';
  static const legCalfL = 'leg_calf.L';
  static const footL = 'foot.L';
  static const legUpperR = 'leg_upper.R';
  static const legQuadR = 'leg_quad.R';
  static const legLowerR = 'leg_lower.R';
  static const legCalfR = 'leg_calf.R';
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
RigSpec buildCatInSuitRig({
  CatInSuitPalette palette = CatInSuitPalette.orangeTabby,
  double legWidthScale = 1,
  double armWidthScale = 1,
}) {
  final bones = <Bone>[
    // Tail controls: the visible tail is drawn as one soft ribbon below. These
    // short bones only provide the bending spine, so the tail can attach behind
    // the rump and sweep as one flexible shape instead of a stack of hinges.
    _tailSeg(
      CatBones.tail0,
      CatBones.hips,
      pivotX: 28,
      pivotY: 2,
      z: -7,
      restRotation: -1.58, // high rear-rump attachment, not a waist/hand spike

      w: 8,
      wTip: 7,
      h: 21,
      dy: 6.5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail1,
      CatBones.tail0,
      pivotY: 12,
      z: -6,
      restRotation: -0.18,
      w: 10,
      wTip: 9,
      h: 20,
      dy: 6,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail2,
      CatBones.tail1,
      pivotY: 11,
      z: -5,
      restRotation: -0.16,
      w: 9,
      wTip: 8,
      h: 19,
      dy: 5.5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail3,
      CatBones.tail2,
      pivotY: 10,
      z: -4,
      restRotation: -0.14,
      w: 8,
      wTip: 6,
      h: 18,
      dy: 5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail4,
      CatBones.tail3,
      pivotY: 9,
      z: -3,
      restRotation: -0.12,
      w: 6,
      wTip: 5,
      h: 17,
      dy: 4.5,
      color: palette.fur,
    ),
    _tailSeg(
      CatBones.tail5,
      CatBones.tail4,
      pivotY: 8,
      z: -2,
      restRotation: -0.1,
      w: 5,
      wTip: 3,
      h: 16,
      dy: 4,
      color: palette.furDark,
    ),
    _tailSeg(
      CatBones.tail6,
      CatBones.tail5,
      pivotY: 7,
      z: -1,
      restRotation: -0.06,
      w: 4,
      wTip: 2,
      h: 14,
      dy: 3,
      color: palette.furDark,
    ),

    // Far (right) leg controls, drawn behind. Their rigid drawables are hidden
    // by the leg ribbon below; keeping the drawables on the bones makes the
    // fallback path and bbox utilities still work.
    Bone(
      id: CatBones.legUpperR,
      parent: CatBones.hips,
      pivotX: 18,
      pivotY: 11,
      z: 3,
      drawable: _tapered(28, 22, 58, _trouserRear, dy: 24),
    ),
    const Bone(
      id: CatBones.legQuadR,
      parent: CatBones.legUpperR,
      pivotX: 2,
      pivotY: 31,
      z: 3,
    ),
    Bone(
      id: CatBones.legLowerR,
      parent: CatBones.legUpperR,
      pivotX: 0,
      pivotY: 55,
      z: 4,
      drawable: _tapered(24, 16, 56, _trouserRear, dy: 23),
    ),
    const Bone(
      id: CatBones.legCalfR,
      parent: CatBones.legLowerR,
      pivotX: 1.5,
      pivotY: 27,
      z: 4,
    ),
    const Bone(
      id: CatBones.footR,
      parent: CatBones.legLowerR,
      pivotX: 0,
      pivotY: 48,
      z: 5,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 29,
        height: 8,
        // Toe points -x (local), which — through the locomotion mirror — makes
        // the shoe LEAD the direction of travel instead of trailing it.
        dx: -9,
        dy: 5.5,
        cornerRadius: 4,
        color: _shoe,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Near (left) leg controls. The visible leg is a continuous ribbon that
    // starts inside the hip volume; the hip is drawn over the top so the leg
    // reads as part of the body, not a capsule bolted underneath.
    Bone(
      id: CatBones.legUpperL,
      parent: CatBones.hips,
      pivotX: -18,
      pivotY: 11,
      z: 6,
      drawable: _tapered(28, 22, 58, _trouser, dy: 24),
    ),
    const Bone(
      id: CatBones.legQuadL,
      parent: CatBones.legUpperL,
      pivotX: -2,
      pivotY: 31,
      z: 6,
    ),
    Bone(
      id: CatBones.legLowerL,
      parent: CatBones.legUpperL,
      pivotX: 0,
      pivotY: 55,
      z: 7,
      drawable: _tapered(24, 16, 56, _trouser, dy: 23),
    ),
    const Bone(
      id: CatBones.legCalfL,
      parent: CatBones.legLowerL,
      pivotX: -1.5,
      pivotY: 27,
      z: 7,
    ),
    const Bone(
      id: CatBones.footL,
      parent: CatBones.legLowerL,
      pivotX: 0,
      pivotY: 48,
      z: 8,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 29,
        height: 8,
        // Toe points -x (local) so the shoe leads travel — see footR.
        dx: -9,
        dy: 5.5,
        cornerRadius: 4,
        color: _shoe,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Pelvis / seat (root). A single low trouser volume sits behind the jacket
    // and over the thigh roots: enough glute/hip mass that the legs feel
    // attached to a body, but not the two rounded thigh caps that read as
    // separate butt cheeks.
    const Bone(
      id: CatBones.hips,
      parent: null,
      pivotX: 0,
      pivotY: 0,
      z: 9,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 54,
        height: 30,
        dy: 9,
        color: _trouser,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),

    // Far (right) arm controls. The ribbon renderer hides these rigid segments
    // and draws one bendy arm surface through shoulder→elbow→wrist.
    Bone(
      id: CatBones.armUpperR,
      parent: CatBones.torso,
      pivotX: 35,
      pivotY: -56,
      // Starts under the jacket shoulder instead of on top of it; the torso owns
      // the broad shoulder line, while the arm reads as a sleeve hanging from it.
      z: 15,
      restRotation: -0.06,
      drawable: _tapered(22, 17, 56, _suit, dy: 23),
    ),
    const Bone(
      id: CatBones.armBicepR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 22,
      z: 15,
    ),
    Bone(
      id: CatBones.armLowerR,
      parent: CatBones.armUpperR,
      pivotX: 0,
      pivotY: 48,
      z: 16,
      drawable: _tapered(18, 13, 50, _suit, dy: 20),
    ),
    Bone(
      id: CatBones.handR,
      parent: CatBones.armLowerR,
      pivotX: 0,
      pivotY: 41,
      z: 17,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 24,
        height: 24,
        dy: 6,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
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
        width: 64, // broad shoulder line for the suited athletic silhouette
        widthTip: 51, // jacket hem covers the pelvis and thigh roots
        height: 98,
        dy: -38,
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
      pivotX: -35,
      pivotY: -56,
      z: 16,
      restRotation: 0.06,
      drawable: _tapered(22, 17, 56, _suit, dy: 23),
    ),
    const Bone(
      id: CatBones.armBicepL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 22,
      z: 16,
    ),
    Bone(
      id: CatBones.armLowerL,
      parent: CatBones.armUpperL,
      pivotX: 0,
      pivotY: 48,
      z: 17,
      drawable: _tapered(18, 13, 50, _suit, dy: 20),
    ),
    Bone(
      id: CatBones.handL,
      parent: CatBones.armLowerL,
      pivotX: 0,
      pivotY: 41,
      z: 18,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 24,
        height: 24,
        dy: 6,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2.5,
      ),
    ),

    // Pointed ears (behind the head crown so only the tips show above it),
    // each with a smaller inner ear nested on top.
    Bone(
      id: CatBones.earL,
      parent: CatBones.head,
      pivotX: -24,
      pivotY: -52,
      z: 18,
      restRotation: -0.22,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 32,
        // Taller + lower base (dy -11) so the ear extends DEEP behind the head
        // (z18 < head z20): rotation slides the base around behind the crown
        // instead of swinging it out to expose a background gap.
        height: 54,
        dy: -11,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    Bone(
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
        color: palette.innerEar,
      ),
    ),
    Bone(
      id: CatBones.earR,
      parent: CatBones.head,
      pivotX: 24,
      pivotY: -52,
      z: 18,
      restRotation: 0.22,
      drawable: BoneDrawable(
        kind: BoneShapeKind.triangle,
        width: 32,
        height: 54, // deep base behind the head — see earL (no rotation gap)
        dy: -11,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    Bone(
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
        color: palette.innerEar,
      ),
    ),

    // Neck: visible bridge tucked behind the head and collar. Without this the
    // head reads pasted directly onto the jacket, especially when the torso
    // mesh jiggles under it.
    Bone(
      id: CatBones.neck,
      parent: CatBones.torso,
      pivotX: 0,
      pivotY: -84,
      z: 19,
      drawable: BoneDrawable(
        kind: BoneShapeKind.roundedRect,
        width: 24,
        height: 24,
        dy: -4,
        cornerRadius: 10,
        color: palette.furDark,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
    Bone(
      id: CatBones.head,
      parent: CatBones.neck,
      pivotX: 0,
      pivotY: -6,
      z: 20,
      drawable: BoneDrawable(
        kind: BoneShapeKind.ellipse,
        width: 72,
        height: 66,
        dy: -28,
        color: palette.fur,
        outlineColor: _outline,
        outlineWidth: 2,
      ),
    ),
  ];

  final face = FaceRig(
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
    browColor: palette.brow,
    mouthColor: _outline,
    muzzleWidth: 34,
    muzzleHeight: 24,
    muzzleColor: palette.muzzle,
    noseWidth: 10,
    noseHeight: 7,
    noseColor: palette.nose,
    whiskerColor: palette.whisker,
    whiskerLength: 22,
  );

  List<double> scaledLegWidths(List<double> widths) => [
    for (final width in widths) width * legWidthScale,
  ];
  List<double> scaledArmWidths(List<double> widths) => [
    for (final width in widths) width * armWidthScale,
  ];

  final ribbons = <LimbRibbonSpec>[
    LimbRibbonSpec(
      id: 'tail.ribbon',
      jointBoneIds: const [
        CatBones.tail0,
        CatBones.tail1,
        CatBones.tail2,
        CatBones.tail3,
        CatBones.tail4,
        CatBones.tail5,
        CatBones.tail6,
      ],
      hiddenBoneIds: const [
        CatBones.tail0,
        CatBones.tail1,
        CatBones.tail2,
        CatBones.tail3,
        CatBones.tail4,
        CatBones.tail5,
        CatBones.tail6,
      ],
      halfWidths: const [3.8, 3.7, 3.4, 3.0, 2.5, 1.9, 1.2],
      z: -7,
      color: palette.fur,
      outlineColor: _outline,
      outlineWidth: 2,
    ),
    LimbRibbonSpec(
      id: 'leg.R.ribbon',
      jointBoneIds: const [
        CatBones.legUpperR,
        CatBones.legQuadR,
        CatBones.legLowerR,
        CatBones.legCalfR,
        CatBones.footR,
      ],
      hiddenBoneIds: const [CatBones.legUpperR, CatBones.legLowerR],
      // Athletic leg profile: strong thigh under the hip, a knee pinch, then a
      // muscular calf bulge tapering to the ankle.
      halfWidths: scaledLegWidths(const [13, 12.4, 7.8, 9.6, 5.4]),
      z: 3,
      color: _trouserRear,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
    ),
    LimbRibbonSpec(
      id: 'leg.L.ribbon',
      jointBoneIds: const [
        CatBones.legUpperL,
        CatBones.legQuadL,
        CatBones.legLowerL,
        CatBones.legCalfL,
        CatBones.footL,
      ],
      hiddenBoneIds: const [CatBones.legUpperL, CatBones.legLowerL],
      halfWidths: scaledLegWidths(const [13, 12.4, 7.8, 9.6, 5.4]),
      z: 6,
      color: _trouser,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
    ),
    LimbRibbonSpec(
      id: 'arm.R.ribbon',
      jointBoneIds: const [
        CatBones.armUpperR,
        CatBones.armBicepR,
        CatBones.armLowerR,
        CatBones.handR,
      ],
      hiddenBoneIds: const [CatBones.armUpperR, CatBones.armLowerR],
      // Broad shoulder into a bicep swell, then a narrower forearm/wrist.
      halfWidths: scaledArmWidths(const [11.6, 12.2, 8.6, 5.5]),
      z: 15,
      color: _suit,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
    ),
    LimbRibbonSpec(
      id: 'arm.L.ribbon',
      jointBoneIds: const [
        CatBones.armUpperL,
        CatBones.armBicepL,
        CatBones.armLowerL,
        CatBones.handL,
      ],
      hiddenBoneIds: const [CatBones.armUpperL, CatBones.armLowerL],
      halfWidths: scaledArmWidths(const [11.6, 12.2, 8.6, 5.5]),
      z: 16,
      color: _suit,
      outlineColor: _outline,
      outlineWidth: 2,
      samplesPerSegment: 12,
    ),
  ];

  final meshes = <SkinnedMeshSpec>[
    SkinnedMeshSpec(
      id: 'hips.mesh',
      vertices: const [
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -22, y: 7, weight: 0.3),
          MeshInfluence(boneId: CatBones.hips, x: -22, y: 2, weight: 0.7),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -8, y: 11, weight: 0.24),
          MeshInfluence(boneId: CatBones.hips, x: -10, y: 6, weight: 0.76),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 8, y: 11, weight: 0.24),
          MeshInfluence(boneId: CatBones.hips, x: 10, y: 6, weight: 0.76),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 22, y: 7, weight: 0.3),
          MeshInfluence(boneId: CatBones.hips, x: 22, y: 2, weight: 0.7),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 25, y: 10, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 20, y: 21, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 10, y: 29, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: 0, y: 31, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: -10, y: 29, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: -20, y: 21, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.hips, x: -25, y: 10, weight: 1),
        ]),
      ],
      boundary: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      hiddenBoneIds: const [CatBones.hips],
      z: 9,
      color: _trouser,
      outlineColor: _outline,
      outlineWidth: 2,
    ),
    SkinnedMeshSpec(
      id: 'jacket.mesh',
      vertices: const [
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -28, y: -82, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -10, y: -88, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 10, y: -88, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 28, y: -82, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 47, y: -62, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 42, y: -38, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 28, y: -14, weight: 0.78),
          MeshInfluence(boneId: CatBones.hips, x: 28, y: -2, weight: 0.22),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 20, y: 10, weight: 0.5),
          MeshInfluence(boneId: CatBones.hips, x: 22, y: 8, weight: 0.5),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 8, y: 18, weight: 0.34),
          MeshInfluence(boneId: CatBones.hips, x: 10, y: 20, weight: 0.66),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: 0, y: 20, weight: 0.28),
          MeshInfluence(boneId: CatBones.hips, x: 0, y: 21, weight: 0.72),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -8, y: 18, weight: 0.34),
          MeshInfluence(boneId: CatBones.hips, x: -10, y: 20, weight: 0.66),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -20, y: 10, weight: 0.5),
          MeshInfluence(boneId: CatBones.hips, x: -22, y: 8, weight: 0.5),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -28, y: -14, weight: 0.78),
          MeshInfluence(boneId: CatBones.hips, x: -28, y: -2, weight: 0.22),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -42, y: -38, weight: 1),
        ]),
        SkinnedMeshVertex([
          MeshInfluence(boneId: CatBones.torso, x: -47, y: -62, weight: 1),
        ]),
      ],
      boundary: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
      hiddenBoneIds: const [CatBones.torso],
      z: 13,
      color: _suit,
      outlineColor: _outline,
      outlineWidth: 2,
    ),
  ];

  return RigSpec(
    name: 'cat_in_suit',
    bones: bones,
    ribbons: ribbons,
    meshes: meshes,
    face: face,
  );
}

/// The Phase-1 clip library: walk, run, kick, dance, sit, jump, idle.
class CatClips {
  static const _dancePhrase = DancePhrase(
    frameCount: 32,
    supports: [
      DanceSupportSpan(
        footBoneId: CatBones.footL,
        freeFootBoneId: CatBones.footR,
        startFrame: 0,
        endFrame: 16,
        loadFrame: 4,
        releaseFrame: 8,
        maxPelvisDistance: 40,
        pocketScaleY: 0.918,
        label: 'left-foot Shaku low pocket',
      ),
      DanceSupportSpan(
        footBoneId: CatBones.footR,
        freeFootBoneId: CatBones.footL,
        startFrame: 16,
        endFrame: 30,
        loadFrame: 20,
        releaseFrame: 24,
        maxPelvisDistance: 40,
        pocketScaleY: 0.918,
        label: 'right-foot answer pocket',
      ),
      DanceSupportSpan(
        footBoneId: CatBones.footL,
        freeFootBoneId: CatBones.footR,
        startFrame: 30,
        endFrame: 32,
        loadFrame: 31,
        releaseFrame: 32,
        maxPelvisDistance: 32,
        pocketScaleY: 0.956,
        label: 'left-foot loop pickup',
      ),
    ],
    sections: [
      DancePhraseSection(
        name: 'Shaku pocket',
        startFrame: 0,
        endFrame: 8,
        intent: 'low left support with compact crossed-arm groove',
      ),
      DancePhraseSection(
        name: 'Shaku rebound',
        startFrame: 8,
        endFrame: 16,
        intent: 'rebound through the left support without standing tall',
      ),
      DancePhraseSection(
        name: 'answer pocket',
        startFrame: 16,
        endFrame: 24,
        intent: 'right support answer with free-left leg texture',
      ),
      DancePhraseSection(
        name: 'toe-flick release',
        startFrame: 24,
        endFrame: 30,
        intent: 'Gbese-flavoured toe-flick release into the loop',
      ),
      DancePhraseSection(
        name: 'loop pickup',
        startFrame: 30,
        endFrame: 32,
        intent: 'compact pickup that lands back into the first pocket',
      ),
    ],
    moves: [
      DanceMoveCue(
        name: 'lead Shaku pocket hit',
        startFrame: 0,
        endFrame: 8,
        accentFrame: 4,
        featuredDancer: 'lead',
        signature: 'low left support, crossed hands, right toe flick',
      ),
      DanceMoveCue(
        name: 'lead rebound shoulder scoop',
        startFrame: 8,
        endFrame: 12,
        accentFrame: 10,
        featuredDancer: 'lead',
        signature: 'compact chest-level scoop without standing tall',
      ),
      DanceMoveCue(
        name: 'right-side camera answer',
        startFrame: 12,
        endFrame: 16,
        accentFrame: 12,
        featuredDancer: 'right',
        signature: 'right dancer inside-arm lift during the camera pass',
      ),
      DanceMoveCue(
        name: 'right-foot groove pocket',
        startFrame: 16,
        endFrame: 24,
        accentFrame: 20,
        featuredDancer: 'lead',
        signature: 'lead settles over right support with lifted free-left toe',
      ),
      DanceMoveCue(
        name: 'left-side camera answer',
        startFrame: 24,
        endFrame: 28,
        accentFrame: 24,
        featuredDancer: 'left',
        signature: 'left dancer inside-arm answer during the camera pass',
      ),
      DanceMoveCue(
        name: 'toe-flick hook reset',
        startFrame: 28,
        endFrame: 32,
        accentFrame: 28,
        featuredDancer: 'lead',
        signature: 'free-left toe flick into compact hook reset',
      ),
    ],
  );
  static DancePhrase get dancePhrase => _dancePhrase;

  static const _danceLeadMoveSignatures = [
    DanceMoveSignature(
      moveName: 'lead Shaku pocket hit',
      ikTargetKeys: {
        CatBones.handL: [
          DanceIkTargetKey(6, x: -19.7, y: 30.4),
          // Frame 7 bridges the crossed pocket into the shoulder scoop. The
          // old path jumped straight out to the side here, which made the
          // section change read as a snap instead of a pickup.
          DanceIkTargetKey(7, x: -39.5, y: 30.8),
        ],
        CatBones.footR: [
          // Keep the free-right foot low enough to read as a toe tap, not a
          // tucked invisible lift under the suit.
          DanceIkTargetKey(1, x: 73.2, y: 88.6),
          DanceIkTargetKey(2, x: 77.4, y: 90.4),
          DanceIkTargetKey(3, x: 81.2, y: 91.6),
          DanceIkTargetKey(4, x: 83.8, y: 92.2),
          DanceIkTargetKey(5, x: 80.2, y: 93.1),
          DanceIkTargetKey(6, x: 72.4, y: 94.1),
          DanceIkTargetKey(7, x: 64.2, y: 94.2),
          DanceIkTargetKey(8, x: 57.8, y: 93.2),
        ],
      },
      jointKeys: {
        CatBones.footL: [
          DanceJointKey(4, rotation: -0.15),
          DanceJointKey(6, rotation: -0.04),
          DanceJointKey(8, rotation: -0.08),
        ],
        CatBones.footR: [
          DanceJointKey(2, rotation: 0.48),
          DanceJointKey(4, rotation: 0.62),
          DanceJointKey(6, rotation: 0.38),
          DanceJointKey(8, rotation: 0.2),
        ],
      },
    ),
    DanceMoveSignature(
      moveName: 'lead rebound shoulder scoop',
      bodyAccentOffsets: [
        DanceBodyAccentOffset(
          offsetFrames: 0,
          radiusFrames: 2,
          rootDy: 1.05,
          rootRotation: 0.001,
          pelvisRotation: -0.02,
          chestRotation: 0.045,
          chestScaleY: 0.975,
          chestScaleX: 1.026,
        ),
      ],
      ikTargetKeys: {
        CatBones.handL: [
          DanceIkTargetKey(8, x: -66.5, y: 15.2),
          DanceIkTargetKey(9, x: -69.6, y: -1.6),
          DanceIkTargetKey(10, x: -67.8, y: -12.4),
          DanceIkTargetKey(11, x: -56.4, y: 0.4),
          DanceIkTargetKey(12, x: -52.6, y: 22.2),
        ],
        CatBones.handR: [
          DanceIkTargetKey(8, x: 38.2, y: 26.8),
          DanceIkTargetKey(9, x: 54.8, y: 8.8),
          DanceIkTargetKey(10, x: 72.6, y: -8.2),
          DanceIkTargetKey(11, x: 65.8, y: 4.6),
          DanceIkTargetKey(12, x: 46.4, y: 25.2),
        ],
      },
      jointKeys: {
        CatBones.armUpperL: [
          DanceJointKey(9, rotation: 0.68),
          DanceJointKey(10, rotation: 0.72),
          DanceJointKey(11, rotation: 0.42),
          DanceJointKey(12, rotation: 0.08),
        ],
        CatBones.armLowerL: [
          DanceJointKey(9, rotation: 0.12),
          DanceJointKey(10),
          DanceJointKey(11, rotation: 0.18),
          DanceJointKey(12, rotation: 0.38),
        ],
        CatBones.armUpperR: [
          DanceJointKey(9, rotation: 0.1),
          DanceJointKey(10, rotation: 0.28),
          DanceJointKey(11, rotation: 0.08),
          DanceJointKey(12, rotation: -0.16),
        ],
        CatBones.armLowerR: [
          DanceJointKey(9, rotation: 0.62),
          DanceJointKey(10, rotation: 0.68),
          DanceJointKey(11, rotation: 0.56),
          DanceJointKey(12, rotation: 0.44),
        ],
      },
    ),
    DanceMoveSignature(
      moveName: 'right-side camera answer',
      ikTargetArcs: {
        CatBones.handR: [
          DanceIkTargetArc(
            name: 'right hand camera-answer lift',
            startFrame: 14,
            peakFrame: 16,
            endFrame: 18,
            startX: 54.4,
            startY: 29.2,
            peakX: 80.2,
            peakY: 14.6,
            endX: 72.8,
            endY: 23.2,
            controlPoints: [
              DanceIkTargetArcPoint(15, x: 70.2, y: 22.4),
              DanceIkTargetArcPoint(17, x: 78.6, y: 18.4),
            ],
          ),
        ],
      },
      ikTargetKeys: {
        CatBones.handL: [
          DanceIkTargetKey(12, x: -52.6, y: 22.2),
          DanceIkTargetKey(13, x: -59.2, y: 24.8),
          DanceIkTargetKey(14, x: -66.4, y: 26.1),
          DanceIkTargetKey(15, x: -59.6, y: 28),
          DanceIkTargetKey(16, x: -47, y: 31.5),
        ],
      },
      jointKeys: {
        CatBones.armUpperL: [
          DanceJointKey(12, rotation: 0.08),
          DanceJointKey(13, rotation: 0.16),
          DanceJointKey(14, rotation: 0.24),
          DanceJointKey(15, rotation: 0.18),
          DanceJointKey(16, rotation: 0.06),
        ],
        CatBones.armLowerL: [
          DanceJointKey(12, rotation: 0.38),
          DanceJointKey(13, rotation: 0.32),
          DanceJointKey(14, rotation: 0.24),
          DanceJointKey(15, rotation: 0.06),
          DanceJointKey(16, rotation: -0.16),
        ],
        CatBones.armUpperR: [
          DanceJointKey(14, rotation: -0.3),
          DanceJointKey(15, rotation: -0.44),
          DanceJointKey(16, rotation: -0.62),
          DanceJointKey(17, rotation: -0.58),
          DanceJointKey(18, rotation: -0.5),
        ],
        CatBones.armLowerR: [
          DanceJointKey(14, rotation: 0.34),
          DanceJointKey(15, rotation: 0.22),
          DanceJointKey(16, rotation: 0.04),
          DanceJointKey(17, rotation: 0.18),
          DanceJointKey(18, rotation: 0.34),
        ],
      },
    ),
    DanceMoveSignature(
      moveName: 'right-foot groove pocket',
      bodyAccentOffsets: [
        DanceBodyAccentOffset(
          offsetFrames: 0,
          radiusFrames: 2,
          rootDy: 0.85,
          rootRotation: -0.001,
          pelvisRotation: -0.026,
          chestRotation: 0.055,
          chestScaleY: 0.976,
          chestScaleX: 1.018,
        ),
      ],
      ikTargetKeys: {
        CatBones.handL: [
          DanceIkTargetKey(19, x: -44.2, y: 31.5),
          DanceIkTargetKey(20, x: -57.6, y: 25.6),
          DanceIkTargetKey(21, x: -46.8, y: 30.8),
        ],
        CatBones.handR: [
          DanceIkTargetKey(19, x: 62.8, y: 27.4),
          DanceIkTargetKey(20, x: 72.4, y: 20.4),
          DanceIkTargetKey(21, x: 65.2, y: 26.4),
        ],
        CatBones.footL: [
          DanceIkTargetKey(18, x: -40.4, y: 102.2),
          DanceIkTargetKey(19, x: -43.5, y: 100.7),
          DanceIkTargetKey(20, x: -50.4, y: 98.7),
          DanceIkTargetKey(21, x: -41.8, y: 100.6),
          DanceIkTargetKey(22, x: -28.2, y: 102.2),
        ],
      },
      jointKeys: {
        CatBones.armUpperL: [
          DanceJointKey(19, rotation: -0.06),
          DanceJointKey(20, rotation: 0.34),
          DanceJointKey(21, rotation: 0.12),
        ],
        CatBones.armLowerL: [
          DanceJointKey(19, rotation: 0.02),
          DanceJointKey(20, rotation: -0.12),
          DanceJointKey(21, rotation: -0.02),
        ],
        CatBones.armUpperR: [
          DanceJointKey(19, rotation: -0.48),
          DanceJointKey(20, rotation: -0.18),
          DanceJointKey(21, rotation: -0.36),
        ],
        CatBones.armLowerR: [
          DanceJointKey(19, rotation: 0.34),
          DanceJointKey(20, rotation: 0.56),
          DanceJointKey(21, rotation: 0.42),
        ],
        CatBones.footL: [
          DanceJointKey(20, rotation: 0.48),
          DanceJointKey(21, rotation: 0.36),
        ],
        CatBones.footR: [
          DanceJointKey(16, rotation: -0.12),
          DanceJointKey(17, rotation: 0.02),
          DanceJointKey(18, rotation: -0.02),
          DanceJointKey(19, rotation: -0.14),
          DanceJointKey(20, rotation: -0.08),
          DanceJointKey(21, rotation: -0.02),
          DanceJointKey(22, rotation: -0.08),
        ],
      },
    ),
    DanceMoveSignature(
      moveName: 'toe-flick hook reset',
      ikTargetKeys: {
        CatBones.handL: [
          DanceIkTargetKey(28, x: -82.4, y: 12.4),
          DanceIkTargetKey(29, x: -89.2, y: 7.2),
          DanceIkTargetKey(30, x: -84.4, y: 13.2),
          DanceIkTargetKey(31, x: -70.2, y: 23.4),
          DanceIkTargetKey(32, x: -56.1, y: 30.3),
        ],
        CatBones.handR: [
          DanceIkTargetKey(28, x: 51.2, y: 24.7),
          DanceIkTargetKey(29, x: 58.4, y: 22.6),
          DanceIkTargetKey(30, x: 60.2, y: 23.4),
          DanceIkTargetKey(31, x: 66.8, y: 25.2),
          DanceIkTargetKey(32, x: 54.4, y: 30.7),
        ],
        CatBones.footL: [
          DanceIkTargetKey(28, x: -27.4, y: 105),
          DanceIkTargetKey(29, x: -14.2, y: 100.2),
          DanceIkTargetKey(30, x: 5.4, y: 95.7),
          DanceIkTargetKey(31, x: 10.6, y: 94.2),
          DanceIkTargetKey(32, x: 9.6, y: 94.4),
        ],
      },
      jointKeys: {
        CatBones.armUpperL: [
          DanceJointKey(27, rotation: 0.32),
          DanceJointKey(28, rotation: 0.4),
          DanceJointKey(29, rotation: 0.54),
          DanceJointKey(30, rotation: 0.5),
          DanceJointKey(31, rotation: 0.32),
          DanceJointKey(32, rotation: 0.22),
        ],
        CatBones.armLowerL: [
          DanceJointKey(27, rotation: -0.12),
          DanceJointKey(28, rotation: 0.22),
          DanceJointKey(29, rotation: 0.42),
          DanceJointKey(30, rotation: 0.46),
          DanceJointKey(31, rotation: 0.18),
          DanceJointKey(32, rotation: -0.12),
        ],
        CatBones.armUpperR: [
          DanceJointKey(28, rotation: -0.46),
          DanceJointKey(29, rotation: -0.58),
          DanceJointKey(30, rotation: -0.54),
          DanceJointKey(31, rotation: -0.44),
          DanceJointKey(32, rotation: -0.24),
        ],
        CatBones.armLowerR: [
          DanceJointKey(28, rotation: 0.58),
          DanceJointKey(29, rotation: 0.68),
          DanceJointKey(30, rotation: 0.58),
          DanceJointKey(31, rotation: 0.22),
          DanceJointKey(32, rotation: 0.14),
        ],
        CatBones.footL: [
          DanceJointKey(28, rotation: 0.46),
          DanceJointKey(29, rotation: 0.32),
          DanceJointKey(30, rotation: 0.08),
          DanceJointKey(31, rotation: -0.04),
          DanceJointKey(32, rotation: -0.08),
        ],
      },
    ),
  ];

  static final List<GroundSpan> _danceContactSpans = _dancePhrase
      .contactSpans();

  // --- Shared walk step cycle (phase 0 = left-foot contact). ---
  // The right leg reuses these exact keys at phase 0.5. The point of keyframes
  // (vs sines) is the two distinct phases a sine can't make: a STANCE leg that
  // plants, straightens and sweeps back under the body, and a SWING leg whose
  // knee tucks so the foot lifts clear of the floor, then reaches out to plant.
  // Smooth, not snappy: the walk reads as a continuous step, so segments ease
  // with easeOut/easeInOut. No `*Back` overshoot in a cycle — it reverses a
  // limb mid-move and reads as a jerk; overshoot/settle is for the one-shots.
  // NOTE: the leg channels are KeyframeChannel(smooth: true) — the Catmull-Rom
  // spline ignores `ease` ENTIRELY (it returns before k1.ease is read). So
  // constant-velocity stance is NOT an Ease.linear; it is encoded as evenly
  // SPACED keys carrying evenly STEPPED values — a straight line the spline can
  // only trace. The stance keys (0.42 -> -0.42, ~constant slope) keep the planted
  // foot's ground sweep linear so it stamps, not skates.
  //
  // Stance is HELD on the floor until the swing foot plants (toe-off at p0.58,
  // not p0.5): a walk by definition never leaves the ground, so the stance leg
  // must bridge into the next contact or the whole rig hops (a flight phase).
  // Mid-stance keys re-spaced so the FOOT's ground sweep (not the thigh angle)
  // is near-constant — footX = 60·sin(thigh)+50·sin(thigh+shin) is non-linear, so
  // a linear thigh raced the foot back early then stalled (a lurch-then-stall
  // travel). Holding the thigh more positive through passing evens the body rate.
  static const _thighKeys = [
    Keyframe(p: 0, rotation: 0.38), // contact: foot lands under the hip
    Keyframe(p: 0.14, rotation: 0.3), // stance
    Keyframe(
      p: 0.28,
      rotation: 0.17,
    ), // passing (held forward — even foot sweep)
    Keyframe(p: 0.42, rotation: -0.11), // late stance
    Keyframe(p: 0.5, rotation: -0.25), // weight rolls forward over the foot
    Keyframe(p: 0.58, rotation: -0.38), // toe-off — held until the swing plants
    Keyframe(p: 0.72, rotation: -0.06), // swing drive (knee leads forward)
    Keyframe(p: 0.88, rotation: 0.34), // reach for the plant
    Keyframe(p: 1, rotation: 0.38),
  ];
  // The knee ARTICULATES through stance to cancel the ankle's arc and hold floor
  // height (a rigid knee + rotating thigh lifts the ankle ~10-25px at midstance —
  // that arc is the hop). Bent at contact, deepest at weight-accept, then
  // progressively STRAIGHTENING (-0.12 -> +0.06 -> +0.22) as the thigh sweeps back
  // so the foot stays planted instead of lifting. Deep tuck only in swing.
  static const _shinKeys = [
    Keyframe(p: 0, rotation: -0.23), // contact: knee bent to set the foot down
    Keyframe(p: 0.14, rotation: -0.34), // weight-accept (deepest flex)
    Keyframe(p: 0.28, rotation: -0.33), // passing — still flexed under the hip
    Keyframe(p: 0.42, rotation: -0.14), // straightening to hold the ankle level
    Keyframe(p: 0.5, rotation: 0.08), // nearly straight — foot still down
    Keyframe(p: 0.58, rotation: 0.25), // extended push at toe-off
    Keyframe(p: 0.72, rotation: -0.78), // swing: knee-tuck clears the body
    Keyframe(p: 0.88, rotation: -0.18), // extends to plant
    Keyframe(p: 1, rotation: -0.23),
  ];
  // Foot tilt signs are negated relative to a naive "toe at +x" foot because the
  // shoe toe points -x (see footL/R dx) — heel-strike still lifts the toe, etc.
  // (ease is dead under the smooth spline.) Toe-off shifts to p0.58 to match the
  // thigh's held stance; the explicit p0.14 keeps the toe from stubbing the floor.
  static const _footKeys = [
    Keyframe(p: 0, rotation: -0.3), // heel strike: toe up, heel leads
    Keyframe(p: 0.14, rotation: -0.1), // rolls toward flat (no toe stub)
    Keyframe(p: 0.42, rotation: -0.03), // flat through stance
    Keyframe(p: 0.58, rotation: -0.44), // toe-off push (late, with the thigh)
    Keyframe(p: 0.7, rotation: 0.22), // swing: dorsiflex to clear
    Keyframe(p: 0.86, rotation: 0.16), // held lifted through swing
    Keyframe(p: 1, rotation: -0.3), // re-cock for heel strike
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

  // 32-frame / two-bar Afrobeats phrase. The support foot changes only on the
  // big count windows; the body keeps moving through compression/rebound so the
  // groove reads as pocket instead of pose swapping. The last bar deliberately
  // loads into frame 1: a clear prep-and-release sells the loop as choreography
  // instead of a reset.
  static const _danceLegUpperLKeys = [
    DanceJointKey(0, rotation: 0.18),
    DanceJointKey(2, rotation: 0.16),
    DanceJointKey(4, rotation: 0.08),
    DanceJointKey(6, rotation: 0.06),
    DanceJointKey(8, rotation: 0.34),
    DanceJointKey(10, rotation: 0.42),
    DanceJointKey(12, rotation: 0.48),
    DanceJointKey(14, rotation: 0.42),
    DanceJointKey(16, rotation: 0.66),
    DanceJointKey(18, rotation: 0.62),
    DanceJointKey(20, rotation: 0.58),
    DanceJointKey(22, rotation: 0.52),
    DanceJointKey(24, rotation: 0.56),
    DanceJointKey(26, rotation: 0.52),
    DanceJointKey(28, rotation: 0.48),
    DanceJointKey(29, rotation: 0.3),
    DanceJointKey(30, rotation: 0.18),
    DanceJointKey(32, rotation: 0.18),
  ];
  static const _danceLegUpperRKeys = [
    DanceJointKey(0, rotation: -0.18),
    DanceJointKey(2, rotation: -0.12),
    DanceJointKey(4, rotation: -0.04),
    DanceJointKey(6, rotation: -0.08),
    DanceJointKey(8, rotation: 0.02),
    DanceJointKey(10, rotation: 0.04),
    DanceJointKey(12, rotation: 0.1),
    DanceJointKey(14, rotation: 0.36),
    DanceJointKey(16, rotation: 0.68),
    DanceJointKey(18, rotation: 0.7),
    DanceJointKey(20, rotation: 0.72),
    DanceJointKey(22, rotation: 0.64),
    DanceJointKey(24, rotation: 0.55),
    DanceJointKey(26, rotation: 0.5),
    DanceJointKey(28, rotation: 0.42),
    DanceJointKey(30, rotation: -0.1),
    DanceJointKey(32, rotation: -0.18),
  ];
  static const _danceLegLowerLKeys = [
    DanceJointKey(0, rotation: -1.1),
    DanceJointKey(2, rotation: -1.12),
    DanceJointKey(4, rotation: -1.1),
    DanceJointKey(6, rotation: -1.08),
    DanceJointKey(8, rotation: -1.1),
    DanceJointKey(10, rotation: -1.12),
    DanceJointKey(12, rotation: -1.1),
    DanceJointKey(14, rotation: -1.08),
    DanceJointKey(16, rotation: -0.78),
    DanceJointKey(18, rotation: -0.82),
    DanceJointKey(20, rotation: -0.82),
    DanceJointKey(22, rotation: -0.94),
    DanceJointKey(24, rotation: -0.9),
    DanceJointKey(26, rotation: -0.86),
    DanceJointKey(28, rotation: -0.82),
    DanceJointKey(29, rotation: -1.08),
    DanceJointKey(30, rotation: -1.08),
    DanceJointKey(31, rotation: -1.1),
    DanceJointKey(32, rotation: -1.1),
  ];
  static const _danceLegLowerRKeys = [
    DanceJointKey(0, rotation: -0.96),
    DanceJointKey(2, rotation: -1.18),
    DanceJointKey(4, rotation: -1.22),
    DanceJointKey(6, rotation: -1.02),
    DanceJointKey(7, rotation: -0.86),
    DanceJointKey(8, rotation: -1.04),
    DanceJointKey(10, rotation: -0.86),
    DanceJointKey(12, rotation: -0.78),
    DanceJointKey(14, rotation: -0.82),
    DanceJointKey(15, rotation: -0.86),
    DanceJointKey(16, rotation: -0.94),
    DanceJointKey(18, rotation: -0.98),
    DanceJointKey(20, rotation: -0.96),
    DanceJointKey(22, rotation: -0.92),
    DanceJointKey(23, rotation: -0.9),
    DanceJointKey(24, rotation: -0.94),
    DanceJointKey(26, rotation: -0.9),
    DanceJointKey(28, rotation: -0.86),
    DanceJointKey(30, rotation: -0.84),
    DanceJointKey(32, rotation: -0.96),
  ];
  static const _danceFootLKeys = [
    DanceJointKey(0, rotation: -0.08),
    DanceJointKey(2, rotation: -0.08),
    DanceJointKey(4, rotation: -0.08),
    DanceJointKey(6, rotation: -0.08),
    DanceJointKey(8, rotation: -0.08),
    DanceJointKey(10, rotation: -0.08),
    DanceJointKey(12, rotation: -0.08),
    DanceJointKey(14, rotation: -0.08),
    DanceJointKey(16, rotation: 0.18),
    DanceJointKey(18, rotation: 0.4),
    DanceJointKey(20, rotation: 0.48),
    DanceJointKey(22, rotation: 0.26),
    DanceJointKey(24, rotation: 0.02),
    DanceJointKey(26, rotation: 0.34),
    DanceJointKey(28, rotation: 0.44),
    DanceJointKey(29, rotation: -0.06),
    DanceJointKey(30, rotation: -0.08),
    DanceJointKey(31, rotation: -0.08),
    DanceJointKey(32, rotation: -0.08),
  ];
  static final List<DanceJointKey> _danceFootLLeadKeys = _dancePhrase
      .mergeJointKeys(
        baseKeys: _danceFootLKeys,
        signatures: _danceLeadMoveSignatures,
        boneId: CatBones.footL,
      );
  static final List<DanceJointKey> _danceFootLAccentKeys = _dancePhrase
      .jointAccentKeys(
        const [
          DanceJointAccent(28, radiusFrames: 2, rotation: 0.055),
        ],
      );
  static const _danceFootRKeys = [
    DanceJointKey(0, rotation: 0.34),
    DanceJointKey(2, rotation: 0.52),
    DanceJointKey(4, rotation: 0.48),
    DanceJointKey(6, rotation: 0.32),
    DanceJointKey(7, rotation: 0.12),
    DanceJointKey(8, rotation: 0.18),
    DanceJointKey(10, rotation: 0.36),
    DanceJointKey(12, rotation: 0.24),
    DanceJointKey(14, rotation: 0.08),
    DanceJointKey(15, rotation: -0.02),
    DanceJointKey(16, rotation: -0.08),
    DanceJointKey(18, rotation: -0.08),
    DanceJointKey(20, rotation: -0.08),
    DanceJointKey(22, rotation: -0.08),
    DanceJointKey(23, rotation: -0.08),
    DanceJointKey(24, rotation: -0.08),
    DanceJointKey(26, rotation: -0.08),
    DanceJointKey(28, rotation: -0.08),
    DanceJointKey(30, rotation: -0.08),
    DanceJointKey(32, rotation: 0.34),
  ];
  static final List<DanceJointKey> _danceFootRLeadKeys = _dancePhrase
      .mergeJointKeys(
        baseKeys: _danceFootRKeys,
        signatures: _danceLeadMoveSignatures,
        boneId: CatBones.footR,
      );

  // Hip-space foot targets make lower-body choreography explicit: the thigh and
  // shin solve toward where the foot should live relative to the pelvis, while
  // the separate foot channels still own shoe roll/toe angle.
  static final List<DanceIkTargetKey> _danceFootLTargetKeys = _dancePhrase
      .mergeIkTargetKeys(
        baseKeys: [
          ...const [
            DanceIkTargetKey(0, x: 9.6, y: 94.4),
            DanceIkTargetKey(1, x: 10.2, y: 93.9),
            DanceIkTargetKey(2, x: 11.7, y: 93.1),
            DanceIkTargetKey(3, x: 14.7, y: 92.2),
            DanceIkTargetKey(4, x: 17.5, y: 91.4),
            DanceIkTargetKey(5, x: 20.3, y: 90.4),
            DanceIkTargetKey(6, x: 19.4, y: 91.1),
            DanceIkTargetKey(7, x: 8.1, y: 95.2),
            DanceIkTargetKey(8, x: -4.8, y: 97.9),
            DanceIkTargetKey(9, x: -8.9, y: 98),
            DanceIkTargetKey(10, x: -10.4, y: 98),
            DanceIkTargetKey(11, x: -13.9, y: 98.4),
            DanceIkTargetKey(12, x: -16.1, y: 98.8),
            DanceIkTargetKey(13, x: -10.7, y: 98.5),
            DanceIkTargetKey(14, x: -9.5, y: 99.3),
            DanceIkTargetKey(15, x: -24, y: 101.5),
            DanceIkTargetKey(16, x: -38, y: 102.1),
            DanceIkTargetKey(17, x: -42, y: 102.3),
            DanceIkTargetKey(18, x: -40.4, y: 102.8),
            DanceIkTargetKey(19, x: -38.9, y: 103.3),
            DanceIkTargetKey(20, x: -36.7, y: 103.6),
            DanceIkTargetKey(21, x: -30.6, y: 103.3),
            DanceIkTargetKey(22, x: -25.8, y: 102.6),
            DanceIkTargetKey(23, x: -27.9, y: 102.6),
          ],
          ..._dancePhrase.ikTargetArcKeys(
            const [
              DanceIkTargetArc(
                name: 'left foot toe-flick release',
                startFrame: 24,
                peakFrame: 28,
                endFrame: 32,
                startX: -31.2,
                startY: 102.9,
                peakX: -27.4,
                peakY: 105,
                endX: 9.6,
                endY: 94.4,
                controlPoints: [
                  DanceIkTargetArcPoint(25, x: -30.7, y: 103.4),
                  DanceIkTargetArcPoint(26, x: -29.3, y: 104),
                  DanceIkTargetArcPoint(27, x: -30.7, y: 104.7),
                  DanceIkTargetArcPoint(29, x: -0.5, y: 97.7),
                  DanceIkTargetArcPoint(30, x: 9.8, y: 94.9),
                  DanceIkTargetArcPoint(31, x: 10.8, y: 94),
                ],
              ),
            ],
          ),
        ],
        signatures: _danceLeadMoveSignatures,
        targetBoneId: CatBones.footL,
      );
  static final KeyframeIkTargetChannel _danceFootLTarget = _dancePhrase
      .ikTargetChannel(
        _danceFootLTargetKeys,
        smooth: true,
      );

  static final KeyframeIkTargetChannel _danceFootRTarget = _dancePhrase
      .ikTargetChannel(
        _dancePhrase.mergeIkTargetKeys(
          baseKeys: const [
            DanceIkTargetKey(0, x: 71.5, y: 85.2),
            DanceIkTargetKey(1, x: 72.1, y: 81.1),
            DanceIkTargetKey(2, x: 70.8, y: 78.4),
            DanceIkTargetKey(3, x: 68.3, y: 78.7),
            DanceIkTargetKey(4, x: 65.9, y: 80.6),
            DanceIkTargetKey(5, x: 66.1, y: 83.2),
            DanceIkTargetKey(6, x: 65.2, y: 87.6),
            DanceIkTargetKey(7, x: 57.3, y: 96),
            DanceIkTargetKey(8, x: 57.8, y: 91.1),
            DanceIkTargetKey(9, x: 54.8, y: 94.5),
            DanceIkTargetKey(10, x: 50.9, y: 98.7),
            DanceIkTargetKey(11, x: 47.7, y: 101),
            DanceIkTargetKey(12, x: 42.7, y: 103),
            DanceIkTargetKey(13, x: 32.5, y: 105),
            DanceIkTargetKey(14, x: 19.9, y: 105.5),
            DanceIkTargetKey(15, x: 5.3, y: 103.8),
            DanceIkTargetKey(16, x: -4.2, y: 100.2),
            DanceIkTargetKey(17, x: -5.3, y: 99.2),
            DanceIkTargetKey(18, x: -3.4, y: 99.6),
            DanceIkTargetKey(19, x: -4.9, y: 99.3),
            DanceIkTargetKey(20, x: -9.2, y: 99.5),
            DanceIkTargetKey(21, x: -4.1, y: 100.3),
            DanceIkTargetKey(22, x: -1, y: 101.5),
            DanceIkTargetKey(23, x: 1.9, y: 102.4),
            DanceIkTargetKey(24, x: 7.6, y: 102.3),
            DanceIkTargetKey(25, x: 8.9, y: 102.7),
            DanceIkTargetKey(26, x: 9.5, y: 103.3),
            DanceIkTargetKey(27, x: 8.9, y: 103.6),
            DanceIkTargetKey(28, x: 14.4, y: 104.4),
            DanceIkTargetKey(29, x: 39.5, y: 102.6),
            DanceIkTargetKey(30, x: 62.3, y: 94),
            DanceIkTargetKey(31, x: 69.5, y: 88.6),
            DanceIkTargetKey(32, x: 71.5, y: 85.2),
          ],
          signatures: _danceLeadMoveSignatures,
          targetBoneId: CatBones.footR,
        ),
        smooth: true,
      );

  // One synchronized table owns COM/root travel, pelvis groove, and chest
  // counter-motion. Root-only pickup frames keep the COM path shaped without
  // injecting fake pelvis/chest keys at those frames.
  static const _danceBodyGrooveKeys = [
    DanceBodyKey(
      0,
      rootDx: -12,
      rootDy: 18.2,
      rootRotation: -0.007,
      pelvisRotation: 0.3,
      chestRotation: -0.08,
      chestScaleY: 0.956,
      chestScaleX: 1.024,
    ),
    DanceBodyKey(
      2,
      rootDx: -14,
      rootDy: 15.6,
      rootRotation: -0.008,
      pelvisRotation: 0.36,
      chestRotation: -0.13,
      chestScaleY: 0.94,
      chestScaleX: 1.034,
    ),
    DanceBodyKey(
      4,
      rootDx: -13,
      rootDy: 16.4,
      rootRotation: -0.006,
      pelvisRotation: 0.43,
      chestRotation: -0.18,
      chestScaleY: 0.918,
      chestScaleX: 1.052,
    ),
    DanceBodyKey(
      6,
      rootDx: -6,
      rootDy: 14.6,
      rootRotation: -0.002,
      pelvisRotation: 0.34,
      chestRotation: -0.12,
      chestScaleY: 0.95,
      chestScaleX: 1.028,
    ),
    DanceBodyKey(7, rootDx: 1, rootDy: 15.8, rootRotation: 0.001),
    DanceBodyKey(
      8,
      rootDx: 12,
      rootDy: 18.2,
      rootRotation: 0.007,
      pelvisRotation: 0.2,
      chestRotation: -0.02,
      chestScaleY: 0.982,
      chestScaleX: 1.01,
    ),
    DanceBodyKey(
      10,
      rootDx: 17,
      rootDy: 15.6,
      rootRotation: 0.008,
      pelvisRotation: 0.08,
      chestRotation: 0.06,
      chestScaleY: 0.97,
      chestScaleX: 1.018,
    ),
    DanceBodyKey(
      12,
      rootDx: 18,
      rootDy: 16.4,
      rootRotation: 0.006,
      pelvisRotation: -0.08,
      chestRotation: 0.1,
      chestScaleY: 0.96,
      chestScaleX: 1.024,
    ),
    DanceBodyKey(
      13,
      rootDx: 12,
      rootDy: 15.6,
      rootRotation: 0.004,
      pelvisRotation: -0.16,
      chestRotation: 0.12,
      chestScaleY: 0.968,
      chestScaleX: 1.018,
    ),
    DanceBodyKey(
      14,
      rootDx: 5,
      rootDy: 15,
      rootRotation: 0.001,
      pelvisRotation: -0.24,
      chestRotation: 0.13,
      chestScaleY: 0.966,
      chestScaleX: 1.02,
    ),
    DanceBodyKey(
      15,
      rootDx: -4,
      rootDy: 16,
      rootRotation: -0.003,
      pelvisRotation: -0.3,
      chestRotation: 0.11,
      chestScaleY: 0.962,
      chestScaleX: 1.022,
    ),
    DanceBodyKey(
      16,
      rootDx: -12,
      rootDy: 18.2,
      rootRotation: -0.007,
      pelvisRotation: -0.36,
      chestRotation: 0.1,
      chestScaleY: 0.956,
      chestScaleX: 1.024,
    ),
    DanceBodyKey(
      18,
      rootDx: -14,
      rootDy: 15.6,
      rootRotation: -0.008,
      pelvisRotation: -0.36,
      chestRotation: 0.13,
      chestScaleY: 0.94,
      chestScaleX: 1.034,
    ),
    DanceBodyKey(
      20,
      rootDx: -13,
      rootDy: 16.4,
      rootRotation: -0.006,
      pelvisRotation: -0.43,
      chestRotation: 0.18,
      chestScaleY: 0.918,
      chestScaleX: 1.052,
    ),
    DanceBodyKey(
      22,
      rootDx: -5,
      rootDy: 14.6,
      rootRotation: -0.002,
      pelvisRotation: -0.34,
      chestRotation: 0.12,
      chestScaleY: 0.95,
      chestScaleX: 1.028,
    ),
    DanceBodyKey(23, rootDx: 2, rootDy: 15.8, rootRotation: 0.001),
    DanceBodyKey(
      24,
      rootDx: 12,
      rootDy: 18.2,
      rootRotation: 0.007,
      pelvisRotation: -0.2,
      chestRotation: 0.02,
      chestScaleY: 0.982,
      chestScaleX: 1.01,
    ),
    DanceBodyKey(
      26,
      rootDx: 14,
      rootDy: 15.6,
      rootRotation: 0.008,
      pelvisRotation: -0.08,
      chestRotation: -0.06,
      chestScaleY: 0.97,
      chestScaleX: 1.018,
    ),
    DanceBodyKey(
      28,
      rootDx: 12,
      rootDy: 16.4,
      rootRotation: 0.006,
      pelvisRotation: 0.04,
      chestRotation: -0.1,
      chestScaleY: 0.96,
      chestScaleX: 1.024,
    ),
    DanceBodyKey(29, rootDx: 4, rootDy: 15.8, rootRotation: 0.002),
    DanceBodyKey(
      30,
      rootDx: -6,
      rootDy: 17.8,
      rootRotation: -0.003,
      pelvisRotation: 0.2,
      chestRotation: -0.08,
      chestScaleY: 0.956,
      chestScaleX: 1.024,
    ),
    DanceBodyKey(
      31,
      rootDx: -11,
      rootDy: 18.2,
      rootRotation: -0.006,
      pelvisRotation: 0.28,
      chestRotation: -0.08,
      chestScaleY: 0.956,
      chestScaleX: 1.024,
    ),
    DanceBodyKey(
      32,
      rootDx: -12,
      rootDy: 18.2,
      rootRotation: -0.007,
      pelvisRotation: 0.3,
      chestRotation: -0.08,
      chestScaleY: 0.956,
      chestScaleX: 1.024,
    ),
  ];

  static const _danceBodyAccents = [
    DanceBodyAccent(
      4,
      radiusFrames: 2,
      rootDy: 1.4,
      rootRotation: -0.0015,
      pelvisRotation: 0.035,
      chestRotation: -0.02,
      chestScaleY: 0.988,
      chestScaleX: 1.01,
    ),
    DanceBodyAccent(
      12,
      radiusFrames: 2,
      rootDx: 1.2,
      rootDy: -0.8,
      rootRotation: 0.001,
      pelvisRotation: -0.025,
      chestRotation: 0.02,
      chestScaleY: 1.008,
      chestScaleX: 0.996,
    ),
    DanceBodyAccent(
      20,
      radiusFrames: 2,
      rootDy: 1.4,
      rootRotation: 0.0015,
      pelvisRotation: -0.035,
      chestRotation: 0.02,
      chestScaleY: 0.988,
      chestScaleX: 1.01,
    ),
    DanceBodyAccent(
      28,
      radiusFrames: 2,
      rootDx: -1.2,
      rootDy: -0.8,
      rootRotation: -0.001,
      pelvisRotation: 0.025,
      chestRotation: -0.02,
      chestScaleY: 1.008,
      chestScaleX: 0.996,
    ),
    DanceBodyAccent(
      30,
      radiusFrames: 2,
      rootDy: 0.9,
      rootRotation: -0.001,
      pelvisRotation: 0.03,
      chestRotation: -0.025,
      chestScaleY: 0.992,
      chestScaleX: 1.006,
    ),
  ];

  static final List<DanceBodyKey> _danceBodyAccentKeys = _dancePhrase
      .bodyAccentKeys([
        ..._danceBodyAccents,
        ..._dancePhrase.moveBodyAccents(_danceLeadMoveSignatures),
      ]);

  // Backup-dancer roles are configured as small additive style overlays below.
  // The shared base clip owns support timing and body mechanics.
  static const _danceNeckKeys = [
    Keyframe(p: 0, rotation: 0.004),
    Keyframe(p: 1 / 16, rotation: 0.003),
    Keyframe(p: 1 / 8, rotation: 0.002),
    Keyframe(p: 3 / 16, rotation: -0.001),
    Keyframe(p: 1 / 4, rotation: -0.004),
    Keyframe(p: 5 / 16, rotation: -0.003),
    Keyframe(p: 3 / 8, rotation: -0.001),
    Keyframe(p: 7 / 16, rotation: -0.002),
    Keyframe(p: 1 / 2, rotation: -0.004),
    Keyframe(p: 9 / 16, rotation: -0.003),
    Keyframe(p: 5 / 8, rotation: -0.002),
    Keyframe(p: 11 / 16, rotation: 0.001),
    Keyframe(p: 3 / 4, rotation: 0.004),
    Keyframe(p: 13 / 16, rotation: 0.003),
    Keyframe(p: 7 / 8, rotation: 0.002),
    Keyframe(p: 15 / 16, rotation: 0.002),
    Keyframe(p: 1, rotation: 0.004),
  ];
  static const _danceHeadKeys = [
    Keyframe(p: 0),
    Keyframe(p: 1 / 8, rotation: -0.0015),
    Keyframe(p: 1 / 4),
    Keyframe(p: 3 / 8, rotation: 0.0015),
    Keyframe(p: 1 / 2),
    Keyframe(p: 5 / 8, rotation: 0.0015),
    Keyframe(p: 3 / 4),
    Keyframe(p: 7 / 8, rotation: -0.0015),
    Keyframe(p: 1),
  ];
  static const _danceEarLKeys = [
    Keyframe(p: 0, rotation: 0.02, scaleX: 1.01, scaleY: 0.99),
    Keyframe(p: 1 / 16, rotation: -0.08, scaleX: 1.05, scaleY: 0.96),
    Keyframe(p: 1 / 8, rotation: -0.12, scaleX: 1.08, scaleY: 0.94),
    Keyframe(p: 3 / 16, rotation: 0.04, scaleX: 0.98, scaleY: 1.03),
    Keyframe(p: 1 / 4, rotation: 0.11, scaleX: 0.96, scaleY: 1.05),
    Keyframe(p: 3 / 8, rotation: 0.03, scaleX: 1.02, scaleY: 0.98),
    Keyframe(p: 7 / 16, rotation: -0.07, scaleX: 1.05, scaleY: 0.96),
    Keyframe(p: 1 / 2, rotation: -0.1, scaleX: 1.07, scaleY: 0.95),
    Keyframe(p: 5 / 8, rotation: -0.13, scaleX: 1.08, scaleY: 0.94),
    Keyframe(p: 11 / 16, rotation: 0.02),
    Keyframe(p: 3 / 4, rotation: 0.08, scaleX: 0.97, scaleY: 1.04),
    Keyframe(p: 13 / 16, rotation: 0.12, scaleX: 0.96, scaleY: 1.05),
    Keyframe(p: 7 / 8, rotation: 0.1, scaleX: 0.97, scaleY: 1.04),
    Keyframe(p: 15 / 16, rotation: 0.04, scaleX: 1.01, scaleY: 0.99),
    Keyframe(p: 1, rotation: 0.02, scaleX: 1.01, scaleY: 0.99),
  ];
  static const _danceEarRKeys = [
    Keyframe(p: 0, rotation: -0.018, scaleX: 0.99, scaleY: 1.01),
    Keyframe(p: 1 / 16, rotation: 0.05, scaleX: 0.97, scaleY: 1.04),
    Keyframe(p: 1 / 8, rotation: 0.115, scaleX: 0.95, scaleY: 1.06),
    Keyframe(p: 3 / 16, rotation: -0.03, scaleX: 1.02, scaleY: 0.98),
    Keyframe(p: 1 / 4, rotation: -0.13, scaleX: 1.08, scaleY: 0.94),
    Keyframe(p: 5 / 16, rotation: -0.06, scaleX: 1.04, scaleY: 0.97),
    Keyframe(p: 3 / 8, rotation: -0.03, scaleX: 1.01, scaleY: 0.99),
    Keyframe(p: 1 / 2, rotation: 0.08, scaleX: 0.97, scaleY: 1.04),
    Keyframe(p: 5 / 8, rotation: 0.12, scaleX: 0.95, scaleY: 1.06),
    Keyframe(p: 11 / 16, rotation: -0.02),
    Keyframe(p: 3 / 4, rotation: -0.075, scaleX: 1.04, scaleY: 0.97),
    Keyframe(p: 13 / 16, rotation: -0.11, scaleX: 1.07, scaleY: 0.95),
    Keyframe(p: 7 / 8, rotation: -0.09, scaleX: 1.04, scaleY: 0.97),
    Keyframe(p: 15 / 16, rotation: -0.035),
    Keyframe(p: 1, rotation: -0.018, scaleX: 0.99, scaleY: 1.01),
  ];
  static const _danceArmUpperLKeys = [
    DanceJointKey(0, rotation: 0.22),
    DanceJointKey(2, rotation: -0.12),
    DanceJointKey(4, rotation: -0.46),
    DanceJointKey(6, rotation: -0.08),
    DanceJointKey(7, rotation: 0.22),
    DanceJointKey(8, rotation: 0.52),
    DanceJointKey(9, rotation: 0.56),
    DanceJointKey(10, rotation: 0.46),
    DanceJointKey(11, rotation: 0.22),
    DanceJointKey(12, rotation: 0.02),
    DanceJointKey(13, rotation: 0.26),
    DanceJointKey(14, rotation: 0.38),
    DanceJointKey(15, rotation: 0.24),
    DanceJointKey(16, rotation: 0.06),
    DanceJointKey(17, rotation: -0.08),
    DanceJointKey(18, rotation: -0.18),
    DanceJointKey(20, rotation: 0.22),
    DanceJointKey(22, rotation: 0.26),
    DanceJointKey(23, rotation: 0.42),
    DanceJointKey(24, rotation: 0.58),
    DanceJointKey(25, rotation: 0.52),
    DanceJointKey(26, rotation: 0.32),
    DanceJointKey(28, rotation: 0.42),
    DanceJointKey(29, rotation: 0.64),
    DanceJointKey(30, rotation: 0.58),
    DanceJointKey(31, rotation: 0.32),
    DanceJointKey(32, rotation: 0.22),
  ];
  static const _danceArmLowerLKeys = [
    DanceJointKey(0, rotation: -0.12),
    DanceJointKey(2, rotation: 0.02),
    DanceJointKey(4, rotation: 0.38),
    DanceJointKey(6, rotation: -0.36),
    DanceJointKey(7, rotation: -0.02),
    DanceJointKey(8, rotation: 0.24),
    DanceJointKey(9, rotation: 0.22),
    DanceJointKey(10, rotation: 0.12),
    DanceJointKey(12, rotation: 0.38),
    DanceJointKey(14, rotation: 0.2),
    DanceJointKey(15, rotation: -0.04),
    DanceJointKey(16, rotation: -0.16),
    DanceJointKey(17, rotation: -0.08),
    DanceJointKey(18, rotation: 0.04),
    DanceJointKey(20, rotation: -0.22),
    DanceJointKey(22, rotation: -0.46),
    DanceJointKey(23, rotation: -0.52),
    DanceJointKey(24, rotation: -0.46),
    DanceJointKey(25, rotation: -0.52),
    DanceJointKey(26, rotation: -0.58),
    DanceJointKey(28, rotation: 0.42),
    DanceJointKey(29, rotation: 0.56),
    DanceJointKey(30, rotation: 0.54),
    DanceJointKey(31, rotation: 0.18),
    DanceJointKey(32, rotation: -0.12),
  ];
  static const _danceArmUpperRKeys = [
    DanceJointKey(0, rotation: -0.24),
    DanceJointKey(2, rotation: 0.05),
    DanceJointKey(4, rotation: 0.44),
    DanceJointKey(6, rotation: -0.02),
    DanceJointKey(7, rotation: 0.08),
    DanceJointKey(8, rotation: -0.08),
    DanceJointKey(10, rotation: -0.02),
    DanceJointKey(12, rotation: -0.24),
    DanceJointKey(14, rotation: -0.34),
    DanceJointKey(15, rotation: -0.46),
    DanceJointKey(16, rotation: -0.68),
    DanceJointKey(18, rotation: -0.54),
    DanceJointKey(20, rotation: -0.38),
    DanceJointKey(22, rotation: -0.5),
    DanceJointKey(23, rotation: -0.62),
    DanceJointKey(24, rotation: -0.56),
    DanceJointKey(25, rotation: -0.54),
    DanceJointKey(26, rotation: -0.58),
    DanceJointKey(28, rotation: -0.48),
    DanceJointKey(29, rotation: -0.68),
    DanceJointKey(30, rotation: -0.62),
    DanceJointKey(31, rotation: -0.48),
    DanceJointKey(32, rotation: -0.24),
  ];
  static const _danceArmLowerRKeys = [
    DanceJointKey(0, rotation: 0.14),
    DanceJointKey(2, rotation: 0.36),
    DanceJointKey(4, rotation: -0.26),
    DanceJointKey(6, rotation: 0.26),
    DanceJointKey(7, rotation: 0.32),
    DanceJointKey(8, rotation: 0.46),
    DanceJointKey(10, rotation: 0.42),
    DanceJointKey(12, rotation: 0.44),
    DanceJointKey(14, rotation: 0.36),
    DanceJointKey(15, rotation: 0.18),
    DanceJointKey(16, rotation: -0.02),
    DanceJointKey(17, rotation: 0.14),
    DanceJointKey(18, rotation: 0.36),
    DanceJointKey(20, rotation: 0.36),
    DanceJointKey(22, rotation: 0.24),
    DanceJointKey(23, rotation: 0.1),
    DanceJointKey(24, rotation: 0.34),
    DanceJointKey(26, rotation: 0.3),
    DanceJointKey(28, rotation: 0.78),
    DanceJointKey(29, rotation: 0.84),
    DanceJointKey(30, rotation: 0.72),
    DanceJointKey(31, rotation: 0.22),
    DanceJointKey(32, rotation: 0.14),
  ];
  static final List<DanceJointKey> _danceArmUpperLLeadKeys = _dancePhrase
      .mergeJointKeys(
        baseKeys: _danceArmUpperLKeys,
        signatures: _danceLeadMoveSignatures,
        boneId: CatBones.armUpperL,
      );
  static final List<DanceJointKey> _danceArmLowerLLeadKeys = _dancePhrase
      .mergeJointKeys(
        baseKeys: _danceArmLowerLKeys,
        signatures: _danceLeadMoveSignatures,
        boneId: CatBones.armLowerL,
      );
  static final List<DanceJointKey> _danceArmUpperRLeadKeys = _dancePhrase
      .mergeJointKeys(
        baseKeys: _danceArmUpperRKeys,
        signatures: _danceLeadMoveSignatures,
        boneId: CatBones.armUpperR,
      );
  static final List<DanceJointKey> _danceArmLowerRLeadKeys = _dancePhrase
      .mergeJointKeys(
        baseKeys: _danceArmLowerRKeys,
        signatures: _danceLeadMoveSignatures,
        boneId: CatBones.armLowerR,
      );

  // Torso-space hand paths seeded from the resolved dance phrase, then evened
  // at the abrupt section returns. The IK layer now owns hand placement; the FK
  // arm channels remain as elbow shape and fallback motion.
  static final List<DanceIkTargetKey> _danceHandLTargetKeys = _dancePhrase
      .mergeIkTargetKeys(
        baseKeys: [
          ...const [
            DanceIkTargetKey(0, x: -56.1, y: 30.3),
            DanceIkTargetKey(1, x: -41.1, y: 32.7),
            DanceIkTargetKey(2, x: -29.5, y: 32.8),
            DanceIkTargetKey(3, x: -22.8, y: 31.4),
            DanceIkTargetKey(4, x: -14.2, y: 28.8),
            DanceIkTargetKey(5, x: -12.8, y: 30.2),
            DanceIkTargetKey(6, x: -19.7, y: 30.4),
            DanceIkTargetKey(7, x: -57.2, y: 30.2),
            DanceIkTargetKey(8, x: -92.3, y: 11.3),
            DanceIkTargetKey(9, x: -93.1, y: 10.5),
            DanceIkTargetKey(10, x: -82.5, y: 19.1),
            DanceIkTargetKey(11, x: -70.8, y: 24.6),
            DanceIkTargetKey(12, x: -55.7, y: 28.9),
            DanceIkTargetKey(13, x: -75.2, y: 22.2),
            DanceIkTargetKey(14, x: -80.7, y: 19.7),
            DanceIkTargetKey(15, x: -66, y: 25.8),
            DanceIkTargetKey(16, x: -47, y: 31.5),
            DanceIkTargetKey(17, x: -29.7, y: 32.8),
            DanceIkTargetKey(18, x: -25, y: 32.4),
            DanceIkTargetKey(19, x: -40.7, y: 32.8),
            DanceIkTargetKey(20, x: -49.4, y: 31.3),
            DanceIkTargetKey(21, x: -48.5, y: 30.5),
            DanceIkTargetKey(22, x: -45.3, y: 30.3),
            DanceIkTargetKey(23, x: -53.9, y: 27.8),
          ],
          ..._dancePhrase.ikTargetArcKeys(
            const [
              DanceIkTargetArc(
                name: 'left hand count-8 hook',
                startFrame: 24,
                peakFrame: 29,
                endFrame: 32,
                startX: -72.2,
                startY: 22.2,
                peakX: -98,
                peakY: -3,
                endX: -56.1,
                endY: 30.3,
                controlPoints: [
                  DanceIkTargetArcPoint(25, x: -63.6, y: 25.4),
                  DanceIkTargetArcPoint(26, x: -43.7, y: 28.6),
                  DanceIkTargetArcPoint(27, x: -67.1, y: 26.9),
                  DanceIkTargetArcPoint(28, x: -88.2, y: 12.9),
                  DanceIkTargetArcPoint(30, x: -94, y: 4),
                  DanceIkTargetArcPoint(31, x: -75, y: 22),
                ],
              ),
            ],
          ),
        ],
        signatures: _danceLeadMoveSignatures,
        targetBoneId: CatBones.handL,
      );
  static final KeyframeIkTargetChannel _danceHandLTarget = _dancePhrase
      .ikTargetChannel(
        _danceHandLTargetKeys,
        smooth: true,
      );

  static final List<DanceIkTargetKey> _danceHandRTargetKeys = _dancePhrase
      .mergeIkTargetKeys(
        baseKeys: [
          ...const [
            DanceIkTargetKey(0, x: 54.4, y: 30.7),
            DanceIkTargetKey(1, x: 37.2, y: 31.9),
            DanceIkTargetKey(2, x: 22.3, y: 30.8),
            DanceIkTargetKey(3, x: 11.7, y: 29.9),
            DanceIkTargetKey(4, x: 13.6, y: 29.7),
            DanceIkTargetKey(5, x: 21.4, y: 31.9),
            DanceIkTargetKey(6, x: 30.5, y: 32),
            DanceIkTargetKey(7, x: 22, y: 31),
            DanceIkTargetKey(8, x: 27.5, y: 30.4),
            DanceIkTargetKey(9, x: 26.8, y: 30.2),
            DanceIkTargetKey(10, x: 26.1, y: 30.8),
            DanceIkTargetKey(11, x: 31.7, y: 30.8),
            DanceIkTargetKey(12, x: 44.8, y: 30.3),
            DanceIkTargetKey(13, x: 48.6, y: 30.2),
          ],
          ...const [
            DanceIkTargetKey(19, x: 61.4, y: 27.2),
            DanceIkTargetKey(20, x: 60, y: 27.9),
            DanceIkTargetKey(21, x: 63.5, y: 27.3),
            DanceIkTargetKey(22, x: 72.5, y: 23.9),
            DanceIkTargetKey(23, x: 89, y: 14.6),
            DanceIkTargetKey(24, x: 73, y: 23.1),
            DanceIkTargetKey(25, x: 74.1, y: 22.7),
            DanceIkTargetKey(26, x: 78.2, y: 20.8),
            DanceIkTargetKey(27, x: 61.8, y: 25.6),
            DanceIkTargetKey(28, x: 51.2, y: 24.7),
            DanceIkTargetKey(29, x: 63.1, y: 20.7),
            DanceIkTargetKey(30, x: 62.6, y: 22.3),
            DanceIkTargetKey(31, x: 74.1, y: 23.4),
            DanceIkTargetKey(32, x: 54.4, y: 30.7),
          ],
        ],
        signatures: _danceLeadMoveSignatures,
        targetBoneId: CatBones.handR,
      );
  static final KeyframeIkTargetChannel _danceHandRTarget = _dancePhrase
      .ikTargetChannel(
        _danceHandRTargetKeys,
        smooth: true,
      );

  static final KeyframeIkTargetChannel _danceHandLAccentOffset = _dancePhrase
      .ikTargetChannel(
        _dancePhrase.ikTargetAccentKeys(
          const [
            DanceIkTargetAccent(8, radiusFrames: 3, x: -2.5, y: -1.5),
          ],
        ),
        smooth: true,
      );

  static final KeyframeIkTargetChannel _danceHandRAccentOffset = _dancePhrase
      .ikTargetChannel(
        _dancePhrase.ikTargetAccentKeys(
          const [
            DanceIkTargetAccent(16, radiusFrames: 2, x: 5, y: -3),
            DanceIkTargetAccent(24, radiusFrames: 2, x: 4, y: -2.5),
          ],
        ),
        smooth: true,
      );

  static final IkTargetChannel _danceLeadHandLTarget = _layerDanceTarget(
    _danceHandLTarget,
    _danceHandLAccentOffset,
  );

  static final IkTargetChannel _danceLeadHandRTarget = _layerDanceTarget(
    _danceHandRTarget,
    _danceHandRAccentOffset,
  );

  static final List<LimbIkTarget> _danceLimbTargets =
      List<LimbIkTarget>.unmodifiable([
        LimbIkTarget(
          upperBoneId: CatBones.armUpperL,
          lowerBoneId: CatBones.armLowerL,
          endBoneId: CatBones.handL,
          anchorBoneId: CatBones.torso,
          channel: _danceLeadHandLTarget,
          bendDirection: -1,
        ),
        LimbIkTarget(
          upperBoneId: CatBones.armUpperR,
          lowerBoneId: CatBones.armLowerR,
          endBoneId: CatBones.handR,
          anchorBoneId: CatBones.torso,
          channel: _danceLeadHandRTarget,
        ),
        LimbIkTarget(
          upperBoneId: CatBones.legUpperL,
          lowerBoneId: CatBones.legLowerL,
          endBoneId: CatBones.footL,
          anchorBoneId: CatBones.hips,
          channel: _danceFootLTarget,
        ),
        LimbIkTarget(
          upperBoneId: CatBones.legUpperR,
          lowerBoneId: CatBones.legLowerR,
          endBoneId: CatBones.footR,
          anchorBoneId: CatBones.hips,
          channel: _danceFootRTarget,
        ),
      ]);

  static const _danceBackupLeftStyle = DanceRoleStyle(
    moveBodyAccents: [
      DanceMoveBodyAccent(
        moveName: 'lead Shaku pocket hit',
        offsetFrames: 0,
        // Low inside-shoulder echo on the lead's first Shaku pocket: enough
        // variation to read as backup choreography, not a competing solo.
        radiusFrames: 3,
        pelvisRotation: 0.035,
        chestRotation: -0.045,
        chestScaleY: 0.984,
        chestScaleX: 1.012,
      ),
      DanceMoveBodyAccent(
        moveName: 'right-side camera answer',
        offsetFrames: 0,
        radiusFrames: 3,
        // Camera is on the right-side dancer here; keep the left-side answer
        // alive but secondary.
        pelvisRotation: -0.012,
        chestRotation: 0.014,
        chestScaleY: 0.994,
        chestScaleX: 1.004,
      ),
      DanceMoveBodyAccent(
        moveName: 'left-side camera answer',
        offsetFrames: 0,
        // Left-side feature when the camera pans back across the crew.
        radiusFrames: 7,
        pelvisRotation: -0.09,
        chestRotation: 0.105,
        chestScaleY: 0.966,
        chestScaleX: 1.026,
      ),
    ],
    ikTargetAccents: {
      CatBones.handR: [
        DanceIkTargetAccent(4, radiusFrames: 3, x: -5.8, y: -3.2),
        DanceIkTargetAccent(12, radiusFrames: 3, x: -1.2, y: -0.9, weight: 0.4),
      ],
    },
    moveTargetOffsetArcs: [
      DanceMoveTargetOffsetArc(
        name: 'left backup inside-hand feature answer',
        moveName: 'left-side camera answer',
        targetBoneId: CatBones.handR,
        startOffsetFrames: -3,
        peakOffsetFrames: 0,
        endOffsetFrames: 4,
        peakX: -12,
        peakY: -7,
        controlPoints: [
          DanceMoveTargetOffsetArcPoint(
            -2,
            x: -4.4,
            y: -2.2,
            weight: 0.65,
          ),
          DanceMoveTargetOffsetArcPoint(-1, x: -9.2, y: -5.8),
          DanceMoveTargetOffsetArcPoint(1, x: -10.2, y: -5.4),
          DanceMoveTargetOffsetArcPoint(2, x: -5.4, y: -2.4, weight: 0.7),
        ],
      ),
    ],
    moveJointAccents: [
      DanceMoveJointAccent(
        moveName: 'lead Shaku pocket hit',
        boneId: CatBones.armUpperR,
        offsetFrames: 0,
        radiusFrames: 3,
        rotation: -0.12,
      ),
      DanceMoveJointAccent(
        moveName: 'right-side camera answer',
        boneId: CatBones.armUpperR,
        offsetFrames: 0,
        radiusFrames: 3,
        rotation: -0.035,
      ),
      DanceMoveJointAccent(
        moveName: 'left-side camera answer',
        boneId: CatBones.armUpperR,
        offsetFrames: 0,
        radiusFrames: 7,
        rotation: -0.26,
      ),
      DanceMoveJointAccent(
        moveName: 'lead Shaku pocket hit',
        boneId: CatBones.armLowerR,
        offsetFrames: 0,
        radiusFrames: 3,
        rotation: 0.16,
      ),
      DanceMoveJointAccent(
        moveName: 'right-side camera answer',
        boneId: CatBones.armLowerR,
        offsetFrames: 0,
        radiusFrames: 3,
        rotation: 0.035,
      ),
      DanceMoveJointAccent(
        moveName: 'left-side camera answer',
        boneId: CatBones.armLowerR,
        offsetFrames: 0,
        radiusFrames: 7,
        rotation: 0.3,
      ),
    ],
  );

  static const _danceBackupRightStyle = DanceRoleStyle(
    moveBodyAccents: [
      DanceMoveBodyAccent(
        moveName: 'right-side camera answer',
        offsetFrames: 0,
        // Right-side feature: this lands under the camera's first lateral pan.
        radiusFrames: 4,
        pelvisRotation: 0.07,
        chestRotation: -0.08,
        chestScaleY: 0.974,
        chestScaleX: 1.022,
      ),
      DanceMoveBodyAccent(
        moveName: 'right-foot groove pocket',
        offsetFrames: 0,
        // Secondary answer to the lead's right-foot groove: a small delayed
        // shoulder bite on the dark cat so the trio has call/response.
        radiusFrames: 4,
        pelvisRotation: -0.04,
        chestRotation: 0.052,
        chestScaleY: 0.982,
        chestScaleX: 1.014,
      ),
      DanceMoveBodyAccent(
        moveName: 'left-side camera answer',
        offsetFrames: 0,
        // Camera has moved left by this point; keep the right-side dancer from
        // competing with the featured left-side answer.
        radiusFrames: 6,
        pelvisRotation: 0.025,
        chestRotation: -0.03,
        chestScaleY: 0.99,
        chestScaleX: 1.008,
      ),
    ],
    ikTargetAccents: {
      CatBones.handL: [
        DanceIkTargetAccent(20, radiusFrames: 4, x: 6.4, y: -4.2),
      ],
    },
    moveTargetOffsetArcs: [
      DanceMoveTargetOffsetArc(
        name: 'right backup inside-hand camera answer',
        moveName: 'right-side camera answer',
        targetBoneId: CatBones.handL,
        startOffsetFrames: -3,
        peakOffsetFrames: 0,
        endOffsetFrames: 3,
        peakX: 9,
        peakY: -6,
        controlPoints: [
          DanceMoveTargetOffsetArcPoint(
            -2,
            x: 3.2,
            y: -1.8,
            weight: 0.7,
          ),
          DanceMoveTargetOffsetArcPoint(-1, x: 6.8, y: -4.6),
          DanceMoveTargetOffsetArcPoint(1, x: 7.4, y: -4.2),
          DanceMoveTargetOffsetArcPoint(2, x: 3.8, y: -2, weight: 0.7),
        ],
      ),
    ],
    moveJointAccents: [
      DanceMoveJointAccent(
        moveName: 'right-side camera answer',
        boneId: CatBones.armUpperL,
        offsetFrames: 0,
        radiusFrames: 4,
        rotation: 0.2,
      ),
      DanceMoveJointAccent(
        moveName: 'right-foot groove pocket',
        boneId: CatBones.armUpperL,
        offsetFrames: 0,
        radiusFrames: 4,
        rotation: 0.13,
      ),
      DanceMoveJointAccent(
        moveName: 'left-side camera answer',
        boneId: CatBones.armUpperL,
        offsetFrames: 0,
        radiusFrames: 6,
        rotation: 0.07,
      ),
      DanceMoveJointAccent(
        moveName: 'right-side camera answer',
        boneId: CatBones.armLowerL,
        offsetFrames: 0,
        radiusFrames: 4,
        rotation: 0.24,
      ),
      DanceMoveJointAccent(
        moveName: 'right-foot groove pocket',
        boneId: CatBones.armLowerL,
        offsetFrames: 0,
        radiusFrames: 4,
        rotation: 0.18,
      ),
      DanceMoveJointAccent(
        moveName: 'left-side camera answer',
        boneId: CatBones.armLowerL,
        offsetFrames: 0,
        radiusFrames: 6,
        rotation: 0.08,
      ),
    ],
  );

  static List<LimbIkTarget> _danceRoleLimbTargets(DanceRoleStyle style) =>
      List<LimbIkTarget>.unmodifiable([
        _danceLimbTargets[0].withChannel(
          _layerDanceTarget(
            _danceLeadHandLTarget,
            _danceRoleTargetOffset(style, CatBones.handL),
          ),
        ),
        _danceLimbTargets[1].withChannel(
          _layerDanceTarget(
            _danceLeadHandRTarget,
            _danceRoleTargetOffset(style, CatBones.handR),
          ),
        ),
        _danceLimbTargets[2],
        _danceLimbTargets[3],
      ]);

  static KeyframeIkTargetChannel _danceRoleTargetOffset(
    DanceRoleStyle style,
    String targetBoneId,
  ) => _dancePhrase.ikTargetChannel(
    style.ikTargetKeys(_dancePhrase, targetBoneId),
    smooth: true,
  );

  static IkTargetChannel _layerDanceTarget(
    IkTargetChannel base,
    IkTargetChannel? offset,
  ) => offset == null ? base : LayeredIkTargetChannel([base, offset]);

  static const _danceTieKeys = [
    Keyframe(p: 0, rotation: 0.02),
    Keyframe(p: 1 / 12, rotation: 0.05),
    Keyframe(p: 2 / 12, rotation: -0.02),
    Keyframe(p: 3 / 12, rotation: -0.05),
    Keyframe(p: 4 / 12, rotation: 0.02),
    Keyframe(p: 5 / 12, rotation: 0.05),
    Keyframe(p: 6 / 12, rotation: -0.02),
    Keyframe(p: 7 / 12, rotation: -0.05),
    Keyframe(p: 8 / 12, rotation: 0.02),
    Keyframe(p: 9 / 12, rotation: -0.07),
    Keyframe(p: 10 / 12, rotation: 0.03),
    Keyframe(p: 11 / 12, rotation: 0.07),
    Keyframe(p: 1, rotation: 0.02),
  ];
  static const _danceTieLowerKeys = [
    Keyframe(p: 0, rotation: 0.04),
    Keyframe(p: 1 / 12, rotation: 0.08),
    Keyframe(p: 2 / 12, rotation: 0.02),
    Keyframe(p: 3 / 12, rotation: -0.08),
    Keyframe(p: 4 / 12, rotation: -0.02),
    Keyframe(p: 5 / 12, rotation: 0.08),
    Keyframe(p: 6 / 12, rotation: 0.02),
    Keyframe(p: 7 / 12, rotation: -0.08),
    Keyframe(p: 8 / 12, rotation: -0.02),
    Keyframe(p: 9 / 12, rotation: -0.13),
    Keyframe(p: 10 / 12, rotation: 0.08),
    Keyframe(p: 11 / 12, rotation: 0.13),
    Keyframe(p: 1, rotation: 0.04),
  ];

  static Clip get walk => const Clip(
    name: 'walk',
    duration: 1,
    // FOOT-LOCKED locomotion: the body's travel is derived from the planted
    // foot's real leg-sweep. The stance foot is held to p0.58; the short
    // footR wrap span keeps the previous step planted through the double-support
    // handoff instead of swapping support too early at p0.50.
    groundSpans: [
      GroundSpan(CatBones.footR, 0, 0.06),
      GroundSpan(CatBones.footL, 0.06, 0.56),
      GroundSpan(CatBones.footR, 0.56, 1),
    ],
    root: SineRootChannel(
      // The COM drops onto each footfall (weight acceptance) and rises at
      // passing — the double-bounce that reads as carrying mass. ~5% of rig
      // height. bobPhase puts the lowest point on the contacts (p=0, 0.5).
      bobAmplitude:
          -3.2, // stronger load now that the stance foot sweep is tighter
      // Kept below the old hop-inducing range, but no longer so polite that the
      // torso looks pasted above the legs.
      bobPhase:
          0.36, // COM trough lands just after contact — sinks onto the plant
      swayAmplitude: 7.2,
      // Phase 0.5 puts the COM OVER the planted (stance) foot at midstance. The
      // previous default (0) lurched the body AWAY from the support foot — an
      // off-balance rock that read as a limp.
      swayPhase: 0.5,
      leanAmplitude: 0.04,
    ),
    channels: {
      // --- Line of action: a real pelvic list that propagates up a soft spine
      // and is re-leveled by the chest + neck/head so the face holds a steady
      // gaze instead of wobbling with every hip sway. The body still moves; the
      // head counter-rotates enough to avoid a bobble-head read.
      // Chest counter-phased against the pelvis (torso phase 0.5 vs hips phase 0)
      // so the spine forms a living S/contrapposto instead of a rigid C-lean.
      // A tiny torso scale pulse lands after foot contact to sell weight without
      // turning the head into a squashy bobble.
      CatBones.hips: SineChannel(amplitude: 0.12),
      CatBones.torso: SineChannel(
        amplitude: 0.09,
        phase: 0.5,
        // Subtle volume change on each footfall: the jacket compresses just
        // after contact and widens a hair, breaking the cardboard-slab read.
        scaleYAmplitude: -0.018,
        scaleYHarmonic: 2,
        scaleYPhase: 0.06,
        scaleXAmplitude: 0.012,
        scaleXHarmonic: 2,
        scaleXPhase: 0.06,
      ),
      CatBones.neck: SineChannel(amplitude: 0.026, phase: 0.5),
      CatBones.head: SineChannel(amplitude: 0.01, phase: 0.5),

      // --- Legs: a real keyframed step, not a pendulum. Left leg drives the
      // cycle; the right shares the same keys half a beat later (phase 0.5). ---
      CatBones.legUpperL: KeyframeChannel(_thighKeys, smooth: true),
      CatBones.legUpperR: KeyframeChannel(_thighKeys, phase: 0.5, smooth: true),
      CatBones.legLowerL: KeyframeChannel(_shinKeys, smooth: true),
      CatBones.legLowerR: KeyframeChannel(_shinKeys, phase: 0.5, smooth: true),
      CatBones.footL: KeyframeChannel(_footKeys, smooth: true),
      CatBones.footR: KeyframeChannel(_footKeys, phase: 0.5, smooth: true),

      // --- Arms: in this front-view rig, side-view arm swing becomes a weird
      // X/M silhouette. These are restrained sleeve lanes, but with enough
      // forearm drag that the hands no longer look asleep.
      CatBones.armUpperL: SineChannel(
        amplitude: 0.055,
        phase: 0.58,
        bias: 0.035,
      ),
      CatBones.armUpperR: SineChannel(
        amplitude: 0.05,
        phase: 0.08,
        bias: -0.035,
      ),
      CatBones.armLowerL: SineChannel(
        amplitude: 0.055,
        phase: 0.74,
        bias: 0.14,
        harmonicAmplitude: 0.012,
        harmonicPhase: 0.18,
      ),
      CatBones.armLowerR: SineChannel(
        amplitude: 0.05,
        phase: 0.24,
        bias: -0.14,
        harmonicAmplitude: 0.012,
        harmonicPhase: 0.68,
      ),

      // --- Ears flick a beat behind the head bob — the cheapest "alive" tell.
      // Asymmetric outer swing kept modest so the ear BASE stays tucked behind
      // the head crown (a bigger swing swings the base out and opens a gap). The
      // inner ear has NO channel of its own: it inherits the outer ear's rotation
      // rigidly, so the pink inner never splays away from the fur outer.
      CatBones.earL: SineChannel(amplitude: 0.045, phase: 0.52),
      CatBones.earR: SineChannel(amplitude: 0.05, phase: 0.58),

      // --- Tie: the blade follows the knot with only a shallow tip lag. Bigger
      // lower-link motion reads like a one-joint pendulum, so most swing lives
      // on the knot and the blade only softens the settle.
      CatBones.tie: SineChannel(amplitude: 0.07, phase: 0.38),
      CatBones.tieLower: SineChannel(
        amplitude: 0.055,
        phase: 0.4,
        harmonicAmplitude: 0.018,
        harmonicPhase: 0.5,
      ),

      // --- Tail: a real travelling wave. The amplitude ramps steeply and the
      // phase lags ~0.10 per link (total ~0.60 base->tip), so the whip visibly
      // travels down the chain; the last three links carry growing 2nd
      // harmonics so the tip cracks/overshoots instead of swinging as a blade.
      // Base bias pulls the whole chain UP/back (-0.12) so the orange tip clears
      // the right hand's height — same-fur-orange tail tip + hand were fusing into
      // one smudge. Mid-chain amps eased so the tip stays high behind the rump.
      CatBones.tail0: SineChannel(amplitude: 0.03, bias: -0.36),
      CatBones.tail1: SineChannel(amplitude: 0.075, phase: 0.1, bias: -0.06),
      CatBones.tail2: SineChannel(amplitude: 0.095, phase: 0.2, bias: -0.04),
      CatBones.tail3: SineChannel(amplitude: 0.14, phase: 0.3),
      CatBones.tail4: SineChannel(
        amplitude: 0.18,
        phase: 0.4,
        harmonicAmplitude: 0.05,
        harmonicPhase: 0.1,
      ),
      CatBones.tail5: SineChannel(
        amplitude: 0.21,
        phase: 0.5,
        harmonicAmplitude: 0.1,
        harmonicPhase: 0.2,
      ),
      CatBones.tail6: SineChannel(
        amplitude: 0.26,
        phase: 0.6,
        harmonicAmplitude: 0.12,
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
      // / gathers on recovery; neck/head mostly stabilize the gaze.
      CatBones.hips: SineChannel(amplitude: 0.1, bias: 0.14),
      CatBones.torso: SineChannel(
        amplitude: 0.16,
        phase: 0.5,
        bias: 0.3,
        harmonicAmplitude: 0.05,
      ),
      CatBones.neck: SineChannel(amplitude: 0.012, bias: -0.26),
      CatBones.head: SineChannel(amplitude: 0.004, phase: 0.5, bias: -0.16),
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

      // Tie streams with the chest instead of hinging as an independent blade.
      CatBones.tie: SineChannel(amplitude: 0.1, phase: 0.1, bias: 0.18),
      CatBones.tieLower: SineChannel(
        amplitude: 0.075,
        phase: 0.14,
        bias: 0.2,
        harmonicAmplitude: 0.018,
        harmonicPhase: 0.3,
      ),
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

  static Clip get kick => const Clip(
    name: 'kick',
    duration: 1,
    loop: false,
    contactSpans: [
      GroundSpan(CatBones.footL, 0, 1),
    ],
    // Anticipate down, chamber, snap a high side kick, then recoil and settle.
    // No locomotion: this is a stage move in place, so the support foot stays
    // readable while the silhouette carries the action.
    root: KeyframeRootChannel([
      RootKeyframe(p: 0),
      RootKeyframe(p: 0.1, dy: 16, dx: -7, rotation: 0.03, ease: Ease.easeOut),
      RootKeyframe(p: 0.22, dy: 12, dx: -14, rotation: -0.02),
      RootKeyframe(
        p: 0.3,
        dy: -11,
        dx: -19,
        rotation: -0.07,
        ease: Ease.easeOut,
      ),
      RootKeyframe(p: 0.4, dy: -10, dx: -19, rotation: -0.065),
      RootKeyframe(p: 0.52, dy: 8, dx: -12, rotation: 0.02, ease: Ease.easeIn),
      RootKeyframe(p: 0.68, dy: 4, dx: -5, rotation: 0.01, ease: Ease.easeOut),
      RootKeyframe(p: 0.82, dy: -2, dx: -1, rotation: -0.005),
      RootKeyframe(p: 1),
    ]),
    channels: {
      // Support leg loads visibly under the body so the kick has a base.
      CatBones.legUpperL: KeyframeChannel([
        Keyframe(p: 0, rotation: 0.04),
        Keyframe(p: 0.12, rotation: 0.44),
        Keyframe(p: 0.22, rotation: 0.56),
        Keyframe(p: 0.3, rotation: 0.48),
        Keyframe(p: 0.4, rotation: 0.46),
        Keyframe(p: 0.52, rotation: 0.24),
        Keyframe(p: 0.68, rotation: 0.12),
        Keyframe(p: 1, rotation: 0.04, ease: Ease.easeOutBack),
      ]),
      CatBones.legLowerL: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.12),
        Keyframe(p: 0.12, rotation: -0.82),
        Keyframe(p: 0.22, rotation: -0.96),
        Keyframe(p: 0.3, rotation: -0.78),
        Keyframe(p: 0.4, rotation: -0.72),
        Keyframe(p: 0.52, rotation: -0.42),
        Keyframe(p: 0.68, rotation: -0.24),
        Keyframe(p: 1, rotation: -0.12, ease: Ease.easeOutBack),
      ]),
      CatBones.footL: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.08),
        Keyframe(p: 0.12, rotation: -0.46),
        Keyframe(p: 0.22, rotation: -0.52),
        Keyframe(p: 0.3, rotation: -0.5),
        Keyframe(p: 0.4, rotation: -0.46),
        Keyframe(p: 0.52, rotation: -0.24),
        Keyframe(p: 0.68, rotation: -0.12),
        Keyframe(p: 1, rotation: -0.08),
      ]),

      // Far/right leg performs a high side kick: knee chamber, clean extension,
      // brief hold, then a visible recoil. Negative thigh rotation points it out
      // to the cat's right; the shin stays nearly aligned for a clean strike.
      CatBones.legUpperR: KeyframeChannel([
        Keyframe(p: 0, rotation: 0.08),
        Keyframe(p: 0.12, rotation: 0.7, ease: Ease.easeIn),
        Keyframe(p: 0.22, rotation: 1.16),
        Keyframe(p: 0.3, rotation: -1.82, ease: Ease.easeOutBack),
        Keyframe(p: 0.4, rotation: -1.76),
        Keyframe(p: 0.52, rotation: 0.92, ease: Ease.easeIn),
        Keyframe(p: 0.68, rotation: 0.28),
        Keyframe(p: 1, rotation: 0.08, ease: Ease.easeOutBack),
      ]),
      CatBones.legLowerR: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.18),
        Keyframe(p: 0.12, rotation: -1.18, ease: Ease.easeIn),
        Keyframe(p: 0.22, rotation: -1.7),
        Keyframe(p: 0.3, rotation: 0.02, ease: Ease.easeOut),
        Keyframe(p: 0.4),
        Keyframe(p: 0.52, rotation: -1.5, ease: Ease.easeIn),
        Keyframe(p: 0.68, rotation: -0.66),
        Keyframe(p: 1, rotation: -0.18, ease: Ease.easeOutBack),
      ]),
      CatBones.footR: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.08),
        Keyframe(p: 0.22, rotation: 0.28),
        Keyframe(p: 0.3, rotation: 0.9),
        Keyframe(p: 0.4, rotation: 0.82),
        Keyframe(p: 0.52, rotation: 0.16),
        Keyframe(p: 0.68, rotation: -0.02),
        Keyframe(p: 1, rotation: -0.08, ease: Ease.easeOutBack),
      ]),

      CatBones.hips: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.12, rotation: 0.28),
        Keyframe(p: 0.22, rotation: 0.48),
        Keyframe(p: 0.3, rotation: 0.72),
        Keyframe(p: 0.4, rotation: 0.64),
        Keyframe(p: 0.58, rotation: -0.12),
        Keyframe(p: 0.72, rotation: 0.08),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.torso: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.12, rotation: -0.18, scaleY: 0.92, scaleX: 1.05),
        Keyframe(p: 0.22, rotation: -0.28, scaleY: 0.94, scaleX: 1.04),
        Keyframe(p: 0.3, rotation: -0.54, scaleY: 1.08, scaleX: 0.955),
        Keyframe(p: 0.4, rotation: -0.48, scaleY: 1.055, scaleX: 0.965),
        Keyframe(p: 0.58, rotation: 0.12),
        Keyframe(p: 0.72, rotation: -0.04),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.neck: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.12, rotation: -0.11),
        Keyframe(p: 0.22, rotation: -0.15),
        Keyframe(p: 0.3, rotation: -0.095),
        Keyframe(p: 0.4, rotation: -0.08),
        Keyframe(p: 0.58, rotation: -0.015),
        Keyframe(p: 0.72, rotation: -0.035),
        Keyframe(p: 1, ease: Ease.easeOut),
      ]),
      CatBones.head: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.12, rotation: -0.02),
        Keyframe(p: 0.22, rotation: -0.03),
        Keyframe(p: 0.3, rotation: -0.015),
        Keyframe(p: 0.4, rotation: -0.015),
        Keyframe(p: 0.58, rotation: -0.004),
        Keyframe(p: 0.72, rotation: -0.01),
        Keyframe(p: 1, ease: Ease.easeOut),
      ]),

      // Counterbalancing arms: one guards high while the other pulls back, so
      // the hands stop merging at the hips and the strike has intent.
      CatBones.armUpperL: KeyframeChannel([
        Keyframe(p: 0, rotation: 0.08),
        Keyframe(p: 0.16, rotation: 0.7),
        Keyframe(p: 0.32, rotation: 0.98),
        Keyframe(p: 0.42, rotation: 0.9),
        Keyframe(p: 0.66, rotation: 0.4),
        Keyframe(p: 1, rotation: 0.08, ease: Ease.easeOutBack),
      ]),
      CatBones.armLowerL: KeyframeChannel([
        Keyframe(p: 0, rotation: 0.08),
        Keyframe(p: 0.16, rotation: -0.45),
        Keyframe(p: 0.32, rotation: -0.72),
        Keyframe(p: 0.42, rotation: -0.62),
        Keyframe(p: 0.66, rotation: -0.24),
        Keyframe(p: 1, rotation: 0.08, ease: Ease.easeOutBack),
      ]),
      CatBones.armUpperR: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.08),
        Keyframe(p: 0.16, rotation: -0.34),
        Keyframe(p: 0.32, rotation: -0.68),
        Keyframe(p: 0.42, rotation: -0.6),
        Keyframe(p: 0.66, rotation: -0.14),
        Keyframe(p: 1, rotation: -0.08, ease: Ease.easeOutBack),
      ]),
      CatBones.armLowerR: KeyframeChannel([
        Keyframe(p: 0, rotation: -0.08),
        Keyframe(p: 0.16, rotation: 0.55),
        Keyframe(p: 0.32, rotation: 0.85),
        Keyframe(p: 0.42, rotation: 0.75),
        Keyframe(p: 0.66, rotation: 0.3),
        Keyframe(p: 1, rotation: -0.08, ease: Ease.easeOutBack),
      ]),

      // Costume and tail follow the snap.
      CatBones.tie: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.16, ease: Ease.easeOut),
        Keyframe(p: 0.42, rotation: 0.09),
        Keyframe(p: 0.6, rotation: -0.08, ease: Ease.easeIn),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tieLower: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.08, ease: Ease.easeOut),
        Keyframe(p: 0.42, rotation: 0.035),
        Keyframe(p: 0.6, rotation: -0.045, ease: Ease.easeIn),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail0: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.18),
        Keyframe(p: 0.42, rotation: 0.1),
        Keyframe(p: 0.6, rotation: -0.08),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail1: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.24),
        Keyframe(p: 0.42, rotation: 0.16),
        Keyframe(p: 0.6, rotation: -0.1),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail2: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.3),
        Keyframe(p: 0.42, rotation: 0.2),
        Keyframe(p: 0.6, rotation: -0.12),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail3: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.38),
        Keyframe(p: 0.42, rotation: 0.24),
        Keyframe(p: 0.6, rotation: -0.16),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail4: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.5),
        Keyframe(p: 0.42, rotation: 0.34),
        Keyframe(p: 0.6, rotation: -0.22),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail5: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.62),
        Keyframe(p: 0.42, rotation: 0.42),
        Keyframe(p: 0.6, rotation: -0.28),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
      CatBones.tail6: KeyframeChannel([
        Keyframe(p: 0),
        Keyframe(p: 0.3, rotation: 0.74),
        Keyframe(p: 0.42, rotation: 0.5),
        Keyframe(p: 0.6, rotation: -0.34),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
    },
  );

  static Clip get dance => Clip(
    name: 'dance',
    duration: 6,
    contactSpans: _danceContactSpans,
    contactPinning: ContactPinning.lowestContact,
    limbTargets: _danceLimbTargets,
    root: LayeredRootChannel([
      _dancePhrase.bodyRootChannel(_danceBodyGrooveKeys, smooth: true),
      _dancePhrase.bodyRootChannel(_danceBodyAccentKeys, smooth: true),
      const SineRootChannel(
        bobAmplitude: -0.055,
        bobPhase: 0.125,
        bobHarmonic: 8,
        leanAmplitude: 0.001,
        leanHarmonic: 8,
      ),
      const SineRootChannel(
        // Tiny double-time pulse keeps the torso alive between count hits
        // without lifting both feet off the deck.
        bobAmplitude: -0.008,
        bobPhase: 0.02,
        bobHarmonic: 16,
        leanAmplitude: 0.0001,
        leanPhase: 0.03,
        leanHarmonic: 16,
      ),
    ]),
    channels: {
      // A compact two-step groove: hips lead, chest counters, head stays
      // mostly locked to the viewer so the dance reads as body rhythm instead
      // of a wobbling face.
      CatBones.hips: LayeredJointChannel([
        _dancePhrase.bodyPelvisChannel(_danceBodyGrooveKeys),
        _dancePhrase.bodyPelvisChannel(_danceBodyAccentKeys, smooth: true),
        const SineChannel(
          harmonicAmplitude: 0.004,
          harmonicPhase: 0.015,
          harmonicMultiplier: 24,
          scaleXAmplitude: 0.0015,
          scaleXPhase: 0.015,
          scaleXHarmonic: 24,
          scaleYAmplitude: -0.0015,
          scaleYPhase: 0.015,
          scaleYHarmonic: 24,
        ),
      ]),
      CatBones.torso: LayeredJointChannel([
        _dancePhrase.bodyChestChannel(_danceBodyGrooveKeys),
        _dancePhrase.bodyChestChannel(_danceBodyAccentKeys, smooth: true),
        const SineChannel(
          harmonicAmplitude: 0.003,
          harmonicPhase: 0.04,
          harmonicMultiplier: 24,
          scaleXAmplitude: -0.002,
          scaleXPhase: 0.04,
          scaleXHarmonic: 24,
          scaleYAmplitude: 0.002,
          scaleYPhase: 0.04,
          scaleYHarmonic: 24,
        ),
      ]),
      CatBones.neck: const KeyframeChannel(_danceNeckKeys, smooth: true),
      CatBones.head: const KeyframeChannel(_danceHeadKeys, smooth: true),

      // Step-touch legs plus a 4-beat Gbese toe-flick bounce: right flick,
      // rebound, left flick, reset. The support foot stays opposite the flick.
      CatBones.legUpperL: _dancePhrase.jointChannel(
        _danceLegUpperLKeys,
        smooth: true,
      ),
      CatBones.legUpperR: _dancePhrase.jointChannel(
        _danceLegUpperRKeys,
        smooth: true,
      ),
      CatBones.legLowerL: _dancePhrase.jointChannel(
        _danceLegLowerLKeys,
        smooth: true,
      ),
      CatBones.legLowerR: _dancePhrase.jointChannel(
        _danceLegLowerRKeys,
        smooth: true,
      ),
      CatBones.footL: LayeredJointChannel([
        _dancePhrase.jointChannel(_danceFootLLeadKeys, smooth: true),
        _dancePhrase.jointChannel(_danceFootLAccentKeys, smooth: true),
      ]),
      CatBones.footR: _dancePhrase.jointChannel(
        _danceFootRLeadKeys,
        smooth: true,
      ),

      // Alternating groove arms for counts 1-8, then compact elbow pops for the
      // Gbese phrase so hands stay visible outside the belly silhouette.
      CatBones.armUpperL: LayeredJointChannel([
        _dancePhrase.jointChannel(_danceArmUpperLLeadKeys, smooth: true),
        const SineChannel(
          harmonicAmplitude: 0.018,
          harmonicPhase: 0.02,
          harmonicMultiplier: 12,
        ),
      ]),
      CatBones.armUpperR: LayeredJointChannel([
        _dancePhrase.jointChannel(_danceArmUpperRLeadKeys, smooth: true),
        const SineChannel(
          harmonicAmplitude: 0.018,
          harmonicPhase: 0.52,
          harmonicMultiplier: 12,
        ),
      ]),
      CatBones.armLowerL: LayeredJointChannel([
        _dancePhrase.jointChannel(_danceArmLowerLLeadKeys, smooth: true),
        const SineChannel(
          harmonicAmplitude: 0.022,
          harmonicPhase: 0.08,
          harmonicMultiplier: 12,
        ),
      ]),
      CatBones.armLowerR: LayeredJointChannel([
        _dancePhrase.jointChannel(_danceArmLowerRLeadKeys, smooth: true),
        const SineChannel(
          harmonicAmplitude: 0.022,
          harmonicPhase: 0.58,
          harmonicMultiplier: 12,
        ),
      ]),

      CatBones.tie: const KeyframeChannel(_danceTieKeys, smooth: true),
      CatBones.tieLower: const KeyframeChannel(
        _danceTieLowerKeys,
        smooth: true,
      ),
      CatBones.earL: const KeyframeChannel(_danceEarLKeys, smooth: true),
      CatBones.earR: const KeyframeChannel(_danceEarRKeys, smooth: true),
      CatBones.tail0: const SineChannel(amplitude: 0.055, bias: -0.34),
      CatBones.tail1: const SineChannel(
        amplitude: 0.09,
        phase: 0.08,
        bias: -0.06,
      ),
      CatBones.tail2: const SineChannel(
        amplitude: 0.12,
        phase: 0.16,
        bias: -0.04,
      ),
      CatBones.tail3: const SineChannel(amplitude: 0.17, phase: 0.24),
      CatBones.tail4: const SineChannel(amplitude: 0.22, phase: 0.32),
      CatBones.tail5: const SineChannel(amplitude: 0.18, phase: 0.4),
      CatBones.tail6: const SineChannel(
        amplitude: 0.21,
        phase: 0.48,
        harmonicAmplitude: 0.05,
        harmonicPhase: 0.12,
      ),
    },
  );

  static Clip get danceBackupLeft => _danceStyledRole(
    name: 'danceBackupLeft',
    style: _danceBackupLeftStyle,
  );

  static Clip get danceBackupRight => _danceStyledRole(
    name: 'danceBackupRight',
    style: _danceBackupRightStyle,
  );

  static Clip _danceStyledRole({
    required String name,
    required DanceRoleStyle style,
  }) {
    final base = dance;
    final bodyKeys = style.bodyKeys(_dancePhrase);
    return Clip(
      name: name,
      duration: base.duration,
      contactSpans: base.contactSpans,
      contactPinning: base.contactPinning,
      limbTargets: _danceRoleLimbTargets(style),
      root: LayeredRootChannel([
        base.root,
        _dancePhrase.bodyRootChannel(bodyKeys, smooth: true),
      ]),
      channels: {
        ...base.channels,
        CatBones.hips: LayeredJointChannel([
          base.channels[CatBones.hips]!,
          _dancePhrase.bodyPelvisChannel(bodyKeys, smooth: true),
          _danceRoleJointChannel(style, CatBones.hips),
        ]),
        CatBones.torso: LayeredJointChannel([
          base.channels[CatBones.torso]!,
          _dancePhrase.bodyChestChannel(bodyKeys, smooth: true),
          _danceRoleJointChannel(style, CatBones.torso),
        ]),
        CatBones.armUpperL: LayeredJointChannel([
          base.channels[CatBones.armUpperL]!,
          _danceRoleJointChannel(style, CatBones.armUpperL),
        ]),
        CatBones.armUpperR: LayeredJointChannel([
          base.channels[CatBones.armUpperR]!,
          _danceRoleJointChannel(style, CatBones.armUpperR),
        ]),
        CatBones.armLowerL: LayeredJointChannel([
          base.channels[CatBones.armLowerL]!,
          _danceRoleJointChannel(style, CatBones.armLowerL),
        ]),
        CatBones.armLowerR: LayeredJointChannel([
          base.channels[CatBones.armLowerR]!,
          _danceRoleJointChannel(style, CatBones.armLowerR),
        ]),
      },
    );
  }

  static JointChannel _danceRoleJointChannel(
    DanceRoleStyle style,
    String boneId,
  ) => _dancePhrase.jointChannel(
    style.jointKeys(_dancePhrase, boneId),
    smooth: true,
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
        Keyframe(p: 0.62, rotation: 0.07, ease: Ease.easeIn),
        Keyframe(p: 0.84, rotation: -0.025, ease: Ease.easeOut),
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
        Keyframe(p: 0.46, rotation: -0.08, ease: Ease.easeOut),
        Keyframe(p: 0.78, rotation: 0.09, ease: Ease.easeIn),
        Keyframe(p: 0.92, rotation: -0.035, ease: Ease.easeOut),
        Keyframe(p: 1, ease: Ease.easeOutBack),
      ]),
    },
  );

  static Clip get idle => const Clip(
    name: 'idle',
    duration: 3.6,
    // Breathing lives in the CHEST (scaleY), not a whole-body bob — a bob lifts
    // the planted feet off the floor and reads as floating/helium. A whisper of
    // bob (-1) is all that's left so the shoulders just barely rise on the breath.
    root: SineRootChannel(bobAmplitude: -1, bobHarmonic: 1),
    channels: {
      // Breathing: the chest expands (scaleY) and the spine sways a hair, so the
      // character is never a frozen frame even when standing still. The face's
      // autonomic blink + eye-darts layer on top for the rest of the "alive".
      CatBones.torso: SineChannel(amplitude: 0.01, scaleYAmplitude: 0.045),
      CatBones.hips: SineChannel(amplitude: 0.012, phase: 0.5),
      // A tiny, slow head settle — kept very tight so the head sits on the
      // shoulders instead of drifting/floating around.
      CatBones.neck: SineChannel(amplitude: 0.002, phase: 0.2),
      CatBones.head: SineChannel(amplitude: 0.0015, phase: 0.35),
      CatBones.armLowerL: SineChannel(amplitude: 0.03, bias: 0.18),
      CatBones.armLowerR: SineChannel(amplitude: 0.03, phase: 0.5, bias: 0.18),
      // Ears twitch slowly (listening) and the tail does a lazy travelling sway
      // down all 7 links — the "alive at rest" tell.
      CatBones.tie: SineChannel(amplitude: 0.015, phase: 0.2),
      CatBones.tieLower: SineChannel(
        amplitude: 0.012,
        phase: 0.23,
        bias: 0.025,
      ),
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

  static List<Clip> get all => [walk, run, kick, dance, sit, jump, idle];
}
