/// The geometric primitive used to draw a bone in Phase 1.
///
/// Phase 1 deliberately draws bones as simple vector shapes (capsules,
/// ellipses, rounded rectangles) instead of a pre-baked sprite atlas. The
/// engine and motion are identical either way; only the per-bone paint differs.
/// This lets us validate the skeleton, cycles and face *before* investing in
/// the offline rasterization + `drawAtlas` runtime described in the plan
/// (`docs/implementation_plans/2026-06-22_bones_animation_framework.md`).
enum BoneShapeKind {
  /// A stadium / pill shape — the default for limbs and torso segments.
  capsule,

  /// An axis-aligned ellipse — heads, eyes, paws.
  ellipse,

  /// A rounded rectangle — suit panels, feet.
  roundedRect,

  /// An upward-pointing triangle (apex at top-centre) — cat ears, noses.
  /// Corners are softened by the outline's round join.
  triangle,

  /// A capsule whose two ends have different widths — wide at the top (the
  /// joint near the pivot), narrow at the bottom (`widthTip`). Limbs taper from
  /// the parent joint toward the child joint instead of reading as a constant-
  /// width "sausage". Ends are rounded caps, so a tapered shin necks down into a
  /// real ankle.
  taperedCapsule,
}

/// How a single bone is drawn, expressed in the bone's local space (origin at
/// the bone pivot, before the world transform is applied).
class BoneDrawable {
  const BoneDrawable({
    required this.kind,
    required this.width,
    required this.height,
    required this.color,
    this.dx = 0,
    this.dy = 0,
    this.cornerRadius = 0,
    this.widthTip = -1,
    this.outlineColor,
    this.outlineWidth = 0,
  });

  final BoneShapeKind kind;

  /// Shape extents in local units.
  final double width;
  final double height;

  /// For [BoneShapeKind.taperedCapsule]: the width at the far (bottom) end.
  /// `width` is the near (pivot-side) end. -1 falls back to `width` (no taper).
  final double widthTip;

  /// Centre offset of the shape from the bone pivot, in local units. Limbs
  /// typically offset along +y so the shape hangs from the joint.
  final double dx;
  final double dy;

  /// Corner radius for the `roundedRect` shape kind.
  final double cornerRadius;

  /// Fill colour as a 32-bit ARGB value (kept as `int` so the model stays
  /// Flutter-free; the painter converts it to a `Color`).
  final int color;

  /// Optional outline colour (ARGB). When null, no outline is drawn.
  final int? outlineColor;
  final double outlineWidth;
}

/// A single rigid bone in the skeleton.
///
/// A bone rotates and scales about its pivot, expressed in its parent's local
/// coordinate space. The root bone's pivot is in world space. [restRotation]
/// and [restScaleX]/[restScaleY] define the rest pose; animation adds a
/// rotation delta and multiplies the scale (see `JointPose`).
class Bone {
  const Bone({
    required this.id,
    required this.parent,
    required this.pivotX,
    required this.pivotY,
    required this.z,
    this.restRotation = 0,
    this.restScaleX = 1,
    this.restScaleY = 1,
    this.drawable,
  });

  /// Stable identifier, also the key used by clips and poses.
  final String id;

  /// Parent bone id, or null for the root.
  final String? parent;

  /// Joint position in the parent's local space (world space for the root).
  final double pivotX;
  final double pivotY;

  /// Paint order; higher draws on top.
  final int z;

  final double restRotation;
  final double restScaleX;
  final double restScaleY;

  /// What to draw for this bone, or null for a control/transform-only bone
  /// (e.g. a hip or neck that only positions its children).
  final BoneDrawable? drawable;
}
