import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// An opaque material for a widget surface plus the bind callback that
/// hands it each capture. Widget content here is fully opaque, and an
/// opaque surface depth-tests like geometry, whereas the default
/// alpha-blended surface sorts unreliably against other surfaces (a banner
/// sixty metres away drew over a pylon fourteen metres away).
class OpaqueSurface {
  OpaqueSurface({this.shared = const []})
    : material = UnlitMaterial()..alphaMode = AlphaMode.opaque;

  final UnlitMaterial material;

  /// Other materials that show the same capture: the darker, mirrored back
  /// of a translucent lightbox.
  final List<UnlitMaterial> shared;

  void bind(gpu.Texture texture) {
    final source = GpuTextureSource(texture);
    material.baseColorTexture = source;
    for (final other in shared) {
      other.baseColorTexture = source;
    }
  }
}

/// One building in the plaza: geometry handles plus everything the facade
/// LOD manager, the picker and the sprite layer need.
class PlazaBuilding {
  PlazaBuilding({
    required this.task,
    required this.attention,
    required this.placement,
    required this.node,
    required this.facadeAnchor,
    required this.ring,
    required this.neon,
    required this.lanternAnchor,
    required this.facadeCenter,
    required this.facadeNormal,
    required this.facadeWorldWidth,
    required this.facadeWorldHeight,
    required this.liveRange,
    required this.pxPerMeter,
  });

  final PlazaTask task;
  final TaskAttention attention;
  final PlotPlacement placement;

  /// The building root (box mesh), attached to the scene.
  final Node node;

  /// Child node on the street-facing wall; the LOD manager attaches
  /// [WidgetComponent]s here.
  final Node facadeAnchor;

  /// The teal focus ring around the facade; visible only when faced.
  final Node ring;

  /// The neon edge strips and their glow; hidden while [ring] shows, so a
  /// faced facade has one frame.
  final Node neon;

  /// Where the roof lantern sprite hangs.
  final Node lanternAnchor;

  /// World-space centre of the facade, for camera-distance ranking.
  final Vector3 facadeCenter;

  /// Unit outward normal of the facade (toward the road).
  final Vector3 facadeNormal;

  final double facadeWorldWidth;
  final double facadeWorldHeight;

  /// The task pose's stand-off: standing there must earn the live wall,
  /// however tall the building.
  final double liveRange;
  final double pxPerMeter;

  /// Logical layout size for the facade widget subtree.
  Size get widgetSize =>
      Size(facadeWorldWidth * pxPerMeter, facadeWorldHeight * pxPerMeter);

  /// Horizontal distance from [eye] to the facade centre.
  double groundDistanceTo(Vector3 eye) {
    final dx = eye.x - facadeCenter.x;
    final dz = eye.z - facadeCenter.z;
    return math.sqrt(dx * dx + dz * dz);
  }

  /// True when [eye] is on the street side of the wall.
  bool facesEye(Vector3 eye) => (eye - facadeCenter).dot(facadeNormal) > 0;
}

/// A billboard panel in the scene: its slot, the task it shows, the backing
/// box (pickable) and the anchor the widget surface hangs on.
class PlazaBillboard {
  PlazaBillboard({
    required this.slot,
    required this.attention,
    required this.backing,
    required this.anchor,
    this.glow,
    this.back,
  });

  final BillboardSlot slot;
  final TaskAttention attention;
  final Node backing;
  final Node anchor;

  /// The lightbox's back, on a pylon or a roof: the panel's own capture,
  /// mirrored by the view and dimmed to [backTint], as light through a
  /// translucent box. Null on a wall or the jumbotron, which have no
  /// back to see.
  final UnlitMaterial? back;

  /// How much of the picture comes through the back.
  static const backTint = 0.42;

  /// The soft bloom behind the lightbox: an anomaly breathes by it. The
  /// jumbotron has none of its own here; its bloom is a pool of the scene.
  final UnlitMaterial? glow;

  /// The bloom's alpha at eye level, at the top of a breath.
  static const glowAlpha = 0.3;

  double _glowAlpha = glowAlpha;

  /// The bloom's current alpha; written to the material only when it
  /// moved, so a still billboard costs nothing per frame.
  double get currentGlow => _glowAlpha;
  set currentGlow(double value) {
    final glow = this.glow;
    if (glow == null || (value - _glowAlpha).abs() < 1e-3) return;
    _glowAlpha = value;
    final c = glow.baseColorFactor;
    glow.baseColorFactor = Vector4(c.x, c.y, c.z, value);
  }

  Vector3 get center => Vector3(slot.x, slot.centerY, slot.z);
}

/// Scene outputs shared directly with rendering, capture and picking layers.
class PlazaSceneBindings {
  final List<PlazaBuilding> buildings = [];

  final List<PlazaBillboard> billboards = [];

  /// Nodes a tap can land on, and what they belong to. Only the facade
  /// plate is pickable, not the whole box: a tap on a side wall or a roof
  /// does nothing, so idle clicks do not fling the camera about.
  final Map<Node, PlazaBuilding> pickableBuildings = {};

  final Map<Node, PlazaBillboard> pickableBillboards = {};

  /// Anchors for the block-marker widgets, keyed by bucket index.
  final Map<int, Node> markerAnchors = {};

  /// Anchors for the vertical banners, keyed by task id.
  final Map<String, Node> bannerAnchors = {};

  /// Where the jumbotron widget hangs, when the plaza has one.
  Node? jumbotronAnchor;

  /// Where the lamp lanterns and spire lights hang.
  final List<Node> lampAnchors = [];

  final List<Node> spireAnchors = [];

  /// Roof-edge and pylon-frame corner points for the chase lights, in
  /// world space, per billboard.
  final Map<PlazaBillboard, List<Vector3>> chaseLightPoints = {};

  /// Anchors for the eye-level week signs, keyed by bucket index.
  final Map<int, Node> weekSignAnchors = {};

  /// Big screens on the skyline towers facing the district: (anchor, width,
  /// height, index into the anomalies to show).
  final List<(Node, double, double, int)> skylineScreens = [];

  /// Vertical neon signs on the filler blocks: (anchor, width, height,
  /// task id whose category names the sign).
  final List<(Node, double, double, String)> fillerSigns = [];
}
