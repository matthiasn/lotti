import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Size;

import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/scenery.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_boxes.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/wall_textures.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// An sRGB [Color] as the linear RGBA the unlit material expects.
Vector4 linearColor(Color color, {double? alpha}) {
  double lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return Vector4(lin(color.r), lin(color.g), lin(color.b), alpha ?? color.a);
}

/// A quad for a [WidgetComponent], wound counter-clockwise.
///
/// flutter_scene 0.23 flipped the engine's front-face convention to CCW and
/// regenerated its primitives, but `WidgetComponent`'s built-in quad still
/// winds CW (byte-identical to 0.20), so the default surface is back-face
/// culled and widget textures never show. Same vertex data as upstream's
/// quad, triangles reversed. Drop when the upstream quad is fixed.
Geometry ccwQuad(double width, double height) {
  final hw = width / 2;
  final hh = height / 2;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
    indices: [3, 1, 0, 2, 1, 3],
  );
}

/// A [ccwQuad] wound the other way: the same vertices and texture
/// coordinates facing -Z, so the picture on it is the front's seen from
/// behind, mirrored — the back of a translucent lightbox.
Geometry backQuad(double width, double height) {
  final hw = width / 2;
  final hh = height / 2;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
    indices: [0, 1, 3, 3, 1, 2],
  );
}

/// A [ccwQuad] whose two ends, each [fade] of its width, darken to black
/// through the vertex colour the unlit material multiplies in: a ticker
/// band's type fades into its housing instead of being sliced mid-glyph.
Geometry fadedQuad(double width, double height, {required double fade}) {
  final hw = width / 2;
  final hh = height / 2;
  // Columns from +X to -X, the way [ccwQuad] orders its vertices, each
  // with a bottom and a top vertex.
  final xs = [hw, hw - width * fade, -hw + width * fade, -hw];
  final us = [0.0, fade, 1 - fade, 1.0];
  final positions = <double>[];
  final texCoords = <double>[];
  final colors = <double>[];
  for (var c = 0; c < xs.length; c++) {
    final lit = c == 1 || c == 2 ? 1.0 : 0.0;
    for (final (y, v) in [(-hh, 1.0), (hh, 0.0)]) {
      positions.addAll([xs[c], y, 0]);
      texCoords.addAll([us[c], v]);
      colors.addAll([lit, lit, lit, 1]);
    }
  }
  final indices = <int>[];
  for (var c = 0; c + 1 < xs.length; c++) {
    final bottomA = 2 * c;
    final topA = bottomA + 1;
    final bottomB = bottomA + 2;
    final topB = bottomB + 1;
    indices.addAll([topA, bottomB, bottomA, topB, bottomB, topA]);
  }
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList(positions),
    texCoords: Float32List.fromList(texCoords),
    colors: Float32List.fromList(colors),
    indices: indices,
  );
}

/// A CCW quad whose texture coordinates repeat [uRepeat] × [vRepeat] times
/// (textures sample with wrap-around), offset by [uOffset] so tiled walls
/// do not all show the same windows.
Geometry tiledQuad(
  double width,
  double height, {
  required double uRepeat,
  required double vRepeat,
  double uOffset = 0,
  double vOffset = 0,
}) {
  final hw = width / 2;
  final hh = height / 2;
  final u0 = uOffset;
  final u1 = uOffset + uRepeat;
  final v0 = vOffset;
  final v1 = vOffset + vRepeat;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([u0, v1, u1, v1, u1, v0, u0, v0]),
    indices: [3, 1, 0, 2, 1, 3],
  );
}

/// A box whose faces carry their own tint in the vertex colour — the top
/// full, the front and back a little down, the sides further, the bottom
/// darkest — so an unlit box keeps its silhouette from every camera
/// height instead of collapsing to one flat patch. The material's base
/// colour multiplies the tint. Wound counter-clockwise, like the engine's
/// own primitives.
Geometry shadedCuboid(
  Vector3 size, {
  double top = 1.0,
  double front = 0.86,
  double side = 0.7,
  double bottom = 0.5,
}) {
  final x = size.x / 2;
  final y = size.y / 2;
  final z = size.z / 2;
  // Each face: four corners counter-clockwise seen from outside, its tint.
  final faces = <(List<List<double>>, double)>[
    (
      [
        [-x, -y, z],
        [x, -y, z],
        [x, y, z],
        [-x, y, z],
      ],
      front,
    ),
    (
      [
        [x, -y, -z],
        [-x, -y, -z],
        [-x, y, -z],
        [x, y, -z],
      ],
      front,
    ),
    (
      [
        [x, -y, z],
        [x, -y, -z],
        [x, y, -z],
        [x, y, z],
      ],
      side,
    ),
    (
      [
        [-x, -y, -z],
        [-x, -y, z],
        [-x, y, z],
        [-x, y, -z],
      ],
      side,
    ),
    (
      [
        [-x, y, z],
        [x, y, z],
        [x, y, -z],
        [-x, y, -z],
      ],
      top,
    ),
    (
      [
        [-x, -y, -z],
        [x, -y, -z],
        [x, -y, z],
        [-x, -y, z],
      ],
      bottom,
    ),
  ];
  final positions = Float32List(24 * 3);
  final colors = Float32List(24 * 4);
  final indices = <int>[];
  var v = 0;
  for (final (corners, tint) in faces) {
    final base = v;
    for (final c in corners) {
      positions[v * 3] = c[0];
      positions[v * 3 + 1] = c[1];
      positions[v * 3 + 2] = c[2];
      colors[v * 4] = tint;
      colors[v * 4 + 1] = tint;
      colors[v * 4 + 2] = tint;
      colors[v * 4 + 3] = 1;
      v++;
    }
    indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
  }
  return MeshGeometry.fromArrays(
    positions: positions,
    colors: colors,
    indices: indices,
  );
}

/// An emitter's colour pushed above display white by [boost], so the HDR
/// bloom pass picks it up: neon, chase heads, lit rooflines.
Vector4 emissiveColor(Color color, double boost, {double? alpha}) {
  final c = linearColor(color, alpha: alpha);
  return Vector4(c.x * boost, c.y * boost, c.z * boost, c.w);
}

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

/// The faces of a box in its own frame: front is +Z, right is +X.
enum _Face { front, back, right, left }

/// Builds and owns the plaza [Scene]: dusk sky, fog, ground, the folded
/// street, the frontier plaza with its pylons, and every building with its
/// far-tier plate, focus ring and lantern anchor.
///
/// Widget surfaces (facades, billboards, tickers, block markers) and the
/// screen-clamped sprites are attached by the other scene classes.
class PlazaSceneController {
  PlazaSceneController({required this.world, this.hidden = const {}})
    : pxPerMeter = world.layout.pxPerMeter {
    _build();
  }

  final PlazaWorld world;
  final double pxPerMeter;

  /// Dev-only: pieces left out of the scene (`gantry`, `jumbotron`,
  /// `fillers`, `skyline`, `pylons`, `walls`), to isolate what a
  /// screenshot is showing.
  final Set<String> hidden;
  bool _shown(String piece) => !hidden.contains(piece);
  final Scene scene = Scene();
  late final _boxes = PlazaBoxes(
    cube: CuboidGeometry(Vector3.all(1)),
    shadedCube: shadedCuboid(Vector3.all(1)),
  );
  final List<PlazaBuilding> buildings = [];
  final List<PlazaBillboard> billboards = [];

  /// Nodes a tap can land on, and what they belong to. Only the facade
  /// plate is pickable, not the whole box: a tap on a side wall or a roof
  /// does nothing, so idle clicks do not fling the camera about.
  final Map<Node, PlazaBuilding> pickableBuildings = {};
  final Map<Node, PlazaBillboard> pickableBillboards = {};

  /// Anchors for the block-marker widgets, keyed by bucket index.
  final Map<int, Node> markerAnchors = {};

  StreetLayout get layout => world.layout;
  StreetPlan get plan => world.plan;

  /// The ground plane, and the plaza slab flush with it: the paving
  /// joints set the square apart, not its colour.
  static final Vector4 _ground = linearColor(const Color(0xFF15131E));
  static final Vector4 _road = linearColor(const Color(0xFF1A1D2B));
  static final Vector4 _gap = linearColor(const Color(0xFF15171F));
  static final Vector4 _post = linearColor(const Color(0xFF14171F));
  static final Vector4 _tower = linearColor(const Color(0xFF0E0B18));

  /// The skyline ring's body: a shade above the fillers so distant
  /// silhouettes read against the sky instead of dissolving into it.
  static final Vector4 _skyline = linearColor(const Color(0xFF161428));
  static final Vector4 _pavement = linearColor(const Color(0xFF232532));
  static final Vector4 _kerb = linearColor(const Color(0xFF5A5E72));

  /// One material per solid colour, shared by every box in it: only the
  /// pools and washes are ever rewritten by [updateForCamera].
  static final _postMaterial = UnlitMaterial()..baseColorFactor = _post;
  static final _towerMaterial = UnlitMaterial()..baseColorFactor = _tower;
  static final _pavementMaterial = UnlitMaterial()..baseColorFactor = _pavement;
  static final _kerbMaterial = UnlitMaterial()..baseColorFactor = _kerb;

  /// The map layer: road ribbons shown from altitude, in the ticker teal.
  static final Vector4 _ribbon = linearColor(PlazaStyle.teal, alpha: 0.55);
  final List<Node> _mapRibbons = [];

  /// Washes fade to nothing with altitude, unlike the pools.
  final List<(UnlitMaterial, double)> _washes = [];
  static final Vector4 _centreLine = linearColor(const Color(0xFF7A7050));

  /// Top of the pavement; every ground light pool sits above this.
  static const _groundTop = 0.11;

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

  /// Side and back wall materials waiting for their window texture, by
  /// lantern state.
  final Map<(LanternState, int), List<UnlitMaterial>> _wallMaterials = {};

  /// Anchors for the eye-level week signs, keyed by bucket index.
  final Map<int, Node> weekSignAnchors = {};

  /// Big screens on the skyline towers facing the district: (anchor, width,
  /// height, index into the anomalies to show).
  final List<(Node, double, double, int)> skylineScreens = [];

  /// Vertical neon signs on the filler blocks: (anchor, width, height,
  /// task id whose category names the sign).
  final List<(Node, double, double, String)> fillerSigns = [];

  /// Light pools: (material, full alpha). Their alpha fades with camera
  /// altitude so the overview is carried by lanterns, not discs.
  final List<(UnlitMaterial, double)> _pools = [];

  /// Ground surfaces that take the asphalt grain.
  final List<UnlitMaterial> _grainMaterials = [];
  final List<UnlitMaterial> _pavingMaterials = [];
  final Map<(LanternState, int), List<UnlitMaterial>> _shopfrontMaterials = {};

  /// Gives every windowed wall its texture once the tiles are uploaded,
  /// the pools their falloff and the ground its grain.
  void attachWallTextures(WallTextures textures) {
    for (final MapEntry(key: (state, family), value: materials)
        in _wallMaterials.entries) {
      for (final material in materials) {
        material
          ..baseColorTexture = textures.window(state, family)
          ..baseColorFactor = Vector4(1, 1, 1, 1);
      }
    }
    for (final (material, _) in _pools) {
      material.baseColorTexture = textures.pool;
    }
    for (final material in _grainMaterials) {
      material.baseColorTexture = textures.grain;
    }
    for (final material in _pavingMaterials) {
      material.baseColorTexture = textures.paving;
    }
    for (final MapEntry(key: (state, variant), value: materials)
        in _shopfrontMaterials.entries) {
      for (final material in materials) {
        material
          ..baseColorTexture = textures.shopfront(state, variant)
          ..baseColorFactor = Vector4(1, 1, 1, 1);
      }
    }
  }

  /// Fades every light pool with the camera's height above the street:
  /// full at eye level, gone by [poolFadeTop] metres up.
  static const poolFadeStart = 12.0;
  static const poolFadeTop = 70.0;

  /// What is left of a pool above [poolFadeTop]: enough that the map shot
  /// still shows a lit street, not so much that the discs read as discs.
  static const poolFloor = 0.15;

  /// Fog at eye level and from the air: the street haze thins as the
  /// camera climbs, so the map shot sees a lit district instead of a
  /// purple wash.
  static const fogDensityLow = 0.0055;
  static const fogDensityHigh = 0.002;
  static const fogOpacityLow = 0.92;
  static const fogOpacityHigh = 0.6;

  /// HDR brightness above which a pixel blooms, and how much of the bloom
  /// is added back. Widget whites sit at 1.0, so screens bloom a little;
  /// neon and chase heads are pushed past it with [emissiveColor].
  static const bloomThreshold = 1.0;
  static const bloomIntensity = 0.3;

  /// How far past white the neon and the lit rooflines go.
  static const neonBoost = 1.6;

  /// The altitude fade last applied, so a camera that has not climbed
  /// does not rewrite every pool and wash material each frame.
  double? _lastFadeT;

  /// What is left of a pool's alpha at the camera's height: 1 at eye
  /// level, [poolFloor] above [poolFadeTop]. The billboards' bloom fades
  /// by it too.
  double get poolFade => 1 - (1 - poolFloor) * (_lastFadeT ?? 0);

  /// Shows the map layer once [eye] is above [poolFadeStart], and fades
  /// the fog, pools and washes with its height.
  void updateForCamera(Vector3 eye) {
    // Road week markers are for the map: at street level the kerb sign
    // owns the week, and a label under your feet reads backwards.
    for (final anchor in markerAnchors.values) {
      anchor.visible = eye.y >= poolFadeStart;
    }
    for (final ribbon in _mapRibbons) {
      ribbon.visible = eye.y >= poolFadeStart;
    }
    final t = ((eye.y - poolFadeStart) / (poolFadeTop - poolFadeStart)).clamp(
      0.0,
      1.0,
    );
    final last = _lastFadeT;
    if (last != null && (t - last).abs() < 1e-6) return;
    _lastFadeT = t;
    scene.fog
      ..density = fogDensityLow + (fogDensityHigh - fogDensityLow) * t
      ..maxOpacity = fogOpacityLow + (fogOpacityHigh - fogOpacityLow) * t;
    void fade(List<(UnlitMaterial, double)> materials, double factor) {
      for (final (material, alpha) in materials) {
        material.baseColorFactor = Vector4(
          material.baseColorFactor.x,
          material.baseColorFactor.y,
          material.baseColorFactor.z,
          alpha * factor,
        );
      }
    }

    fade(_pools, 1 - (1 - poolFloor) * t);
    // A streak is a reflection on wet paving: from the air there is none.
    fade(_washes, 1 - t);
  }

  /// A blended tiled overlay just above a ground slab, one texture tile
  /// every [tileMeters]: the asphalt grain on a road, the paving joints
  /// on the plaza. [materials] collects it for [attachWallTextures]; a
  /// [fading] overlay dims with altitude like a pool.
  void _addTiledOverlay(
    Node parent, {
    required double width,
    required double depth,
    required double y,
    required double tileMeters,
    required List<UnlitMaterial> materials,
    bool fading = false,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = Vector4(1, 1, 1, 0.4)
      ..alphaMode = AlphaMode.blend;
    materials.add(material);
    if (fading) _pools.add((material, 0.4));
    parent.add(
      Node(
        localTransform: Matrix4.translation(Vector3(0, y, 0))
          ..rotateX(-math.pi / 2),
        mesh: Mesh(
          tiledQuad(
            width,
            depth,
            uRepeat: width / tileMeters,
            vRepeat: depth / tileMeters,
          ),
          material,
        ),
      ),
    );
  }

  /// Height of the shopfront band at the foot of every wall.
  static const shopfrontHeight = 4.0;

  /// A building at least this tall carries its screen above a street-level
  /// parade on the street face; a shorter one is all sign.
  static const paradeWallHeight = 12.0;

  /// A wall face: a shopfront band at the foot (the parade of shops,
  /// dressed for [shops], which defaults to [state]: trading, late,
  /// fitting out, shuttered, closed; [variant] picks the parade order;
  /// [family] the window tile's occupancy)
  /// under the window grid of [state]'s lit ratio, stacked in whole
  /// storeys from the band up with the remainder as a dark cornice, so no
  /// cut row ever sits on the fascia. The quad's face is +Z before [yaw];
  /// [dx], [dz] place it on the parent's box, whose centre sits at half
  /// [height].
  void _windowedWall(
    Node parent, {
    required double dx,
    required double dz,
    required double yaw,
    required double width,
    required double height,
    required LanternState state,
    required Vector4 tint,
    required double uOffset,
    LanternState? shops,
    int variant = 0,
    int family = 0,
  }) {
    final ground = math.min(shopfrontHeight, height * 0.45);
    final shop = UnlitMaterial()..baseColorFactor = tint;
    _shopfrontMaterials
        .putIfAbsent((shops ?? state, variant), () => [])
        .add(shop);
    parent.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(dx, -height / 2 + ground / 2, dz),
        )..rotateY(yaw),
        mesh: Mesh(
          tiledQuad(
            width,
            ground,
            uRepeat: width / WallTextures.shopfrontWidth,
            vRepeat: ground / WallTextures.shopfrontHeight,
            uOffset: uOffset,
          ),
          shop,
        ),
      ),
    );
    final upper = height - ground;
    if (upper <= 0.1) return;
    final floors = (upper / WallTextures.storeyHeight).floor();
    final storeys = floors * WallTextures.storeyHeight;
    final cornice = upper - storeys;
    if (floors > 0) {
      final windows = UnlitMaterial()..baseColorFactor = tint;
      _wallMaterials.putIfAbsent((state, family), () => []).add(windows);
      parent.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(dx, -height / 2 + ground + storeys / 2, dz),
          )..rotateY(yaw),
          mesh: Mesh(
            tiledQuad(
              width,
              storeys,
              uRepeat: width / WallTextures.tileWidth,
              vRepeat: floors / WallTextures.floors,
              uOffset: uOffset,
              // The tile's floor slabs sit at its own storey lines; start
              // at a whole tile so the first slab lands on the fascia.
              vOffset: 1 - floors / WallTextures.floors,
            ),
            windows,
          ),
        ),
      );
    }
    if (cornice > 0.05) {
      parent.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(dx, height / 2 - cornice / 2, dz),
          )..rotateY(yaw),
          mesh: Mesh(ccwQuad(width, cornice), _corniceMaterial),
        ),
      );
    }
  }

  /// The cornice band: the wall's own dark, a shade above the night.
  static final _corniceMaterial = UnlitMaterial()
    ..baseColorFactor = linearColor(const Color(0xFF141220));

  /// Windowed walls ([_windowedWall]) on [faces] of the [w] × [d] box
  /// under [parent], in that order, whose centre sits at half [height].
  /// Each face tiles from its own hashed offset so it starts at its own
  /// shop, unless [perFaceOffset] is off and every face shares one.
  void _windowedBox(
    Node parent, {
    required String id,
    required double w,
    required double d,
    required double height,
    required LanternState state,
    required Vector4 tint,
    List<_Face> faces = _Face.values,
    bool perFaceOffset = true,
    LanternState? shops,
    int variant = 0,
    int family = 0,
  }) {
    for (final face in faces) {
      // A quad's face is +Z before rotation: rotateY(-π/2) turns it to -X
      // for the left wall, rotateY(π/2) to +X for the right, π for the
      // back.
      final (dx, dz, yaw, width) = switch (face) {
        _Face.front => (0.0, d / 2 + 0.02, 0.0, w),
        _Face.back => (0.0, -d / 2 - 0.02, math.pi, w),
        _Face.right => (w / 2 + 0.02, 0.0, math.pi / 2, d),
        _Face.left => (-w / 2 - 0.02, 0.0, -math.pi / 2, d),
      };
      _windowedWall(
        parent,
        dx: dx,
        dz: dz,
        yaw: yaw,
        width: width,
        height: height,
        state: state,
        tint: tint,
        uOffset: stableUnit(id, perFaceOffset ? 'tile$yaw' : 'tile') * 3,
        shops: shops,
        variant: variant,
        family: family,
      );
    }
  }

  /// A shared unit box scaled to [size], with an unscaled anchor centred
  /// at [at] under [parent] so attached decorations retain their placement.
  Node _box(Node parent, Vector3 at, Vector3 size, UnlitMaterial material) {
    final node = _boxes.node(
      size,
      material,
      transform: Matrix4.translation(at),
    );
    parent.add(node);
    return node;
  }

  /// Four strips round the edge of a [w] × [d] rectangle at [y] under
  /// [parent]: [thickness] wide, [height] tall (default [thickness]),
  /// [inset] in from the edge (negative pushes them out) and running
  /// [overhang] longer than the side they lie along.
  void _rim(
    Node parent, {
    required double w,
    required double d,
    required double y,
    required double thickness,
    required UnlitMaterial material,
    double inset = 0,
    double overhang = 0,
    double? height,
  }) {
    for (final (dx, dz, sx, sz) in [
      (0.0, d / 2 - inset, w + overhang, thickness),
      (0.0, -d / 2 + inset, w + overhang, thickness),
      (w / 2 - inset, 0.0, thickness, d + overhang),
      (-w / 2 + inset, 0.0, thickness, d + overhang),
    ]) {
      _box(
        parent,
        Vector3(dx, y, dz),
        Vector3(sx, height ?? thickness, sz),
        material,
      );
    }
  }

  static final Vector4 _panelBack = linearColor(PlazaStyle.panel);

  void _build() {
    _buildSky();

    final (centerX, centerZ) = planCenterOf(plan);
    final buildSkyline = _shown('skyline');
    _box(
      scene.root,
      Vector3(centerX, -0.06, centerZ),
      Vector3(6000, 0.1, 6000),
      _boxes.solid(_ground),
    );
    if (buildSkyline) {
      _buildSkyline();
      _buildHeroTowers();
    }

    for (final segment in plan.segments) {
      final midAlong = segment.length / 2;
      final mid = Vector3(
        segment.startX + math.sin(segment.headingRadians) * midAlong,
        0,
        segment.startZ + math.cos(segment.headingRadians) * midAlong,
      );
      final roadNode = _boxes.node(
        Vector3(layout.roadWidth, 0.08, segment.length + 0.4),
        _boxes.solid(segment.isGap ? _gap : _road),
        transform: Matrix4.translation(mid)..rotateY(segment.headingRadians),
      );
      // Pavements with a kerb step on both sides, and a dashed centre
      // line: the street section that makes a slab read as a road.
      for (final side in [-1.0, 1.0]) {
        _box(
          roadNode,
          Vector3(side * (layout.roadWidth / 2 - 1.5), 0.05, 0),
          Vector3(3, 0.1, segment.length + 0.4),
          _pavementMaterial,
        );
        // A kerb you could stub a toe on: a raised stone edge between the
        // road and the pavement.
        _box(
          roadNode,
          Vector3(side * (layout.roadWidth / 2 - 3), 0.09, 0),
          Vector3(0.35, 0.18, segment.length + 0.4),
          _kerbMaterial,
        );
      }
      // The map layer: a teal ribbon down the axis of every segment,
      // connectors included, shown from the air so the overview reads
      // as a route and not a dark render.
      final ribbon = _box(
        roadNode,
        Vector3(0, 0.1, 0),
        Vector3(0.9, 0.02, segment.length + 0.4),
        _boxes.solid(_ribbon),
      )..visible = false;
      _mapRibbons.add(ribbon);
      if (!segment.isGap) {
        for (
          var along = -segment.length / 2 + 3;
          along < segment.length / 2 - 2;
          along += 6
        ) {
          _box(
            roadNode,
            Vector3(0, 0.045, along),
            Vector3(0.18, 0.01, 2.2),
            _boxes.solid(_centreLine),
          );
        }
      }
      _addTiledOverlay(
        roadNode,
        width: layout.roadWidth,
        depth: segment.length + 0.4,
        y: 0.045,
        tileMeters: 2,
        materials: _grainMaterials,
      );
      scene.add(roadNode);
      if (!segment.isGap) {
        const along = 9.0;
        final anchor = Node(
          localTransform:
              Matrix4.translation(
                  Vector3(
                    segment.startX + math.sin(segment.headingRadians) * along,
                    _groundTop + 0.02,
                    segment.startZ + math.cos(segment.headingRadians) * along,
                  ),
                )
                // Oriented to the map shot (the last row's heading), not
                // the row's own: on a folded row the label would be
                // upside down from the air, and the air is where it is
                // read.
                ..rotateY(
                  (plan.last?.headingRadians ?? segment.headingRadians) +
                      math.pi,
                )
                ..rotateX(-math.pi / 2),
        );
        scene.add(anchor);
        markerAnchors[segment.bucketIndex] = anchor;
      }
    }

    final plaza = world.plaza;
    if (plaza != null) {
      final slab = _boxes.node(
        Vector3(plaza.width, 0.1, plaza.depth),
        _boxes.solid(_ground),
        transform: Matrix4.translation(
          Vector3(plaza.centerX, 0.01, plaza.centerZ),
        )..rotateY(plaza.headingRadians),
      );
      _addTiledOverlay(
        slab,
        width: plaza.width,
        depth: plaza.depth,
        y: 0.06,
        tileMeters: 2,
        materials: _grainMaterials,
      );
      _addTiledOverlay(
        slab,
        width: plaza.width,
        depth: plaza.depth,
        y: 0.07,
        tileMeters: WallTextures.pavingMeters,
        materials: _pavingMaterials,
        fading: true,
      );
      // Home marker ring on the ground.
      scene
        ..add(slab)
        ..add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(plaza.home.x, 0.08, plaza.home.z),
            ),
            mesh: Mesh(
              RingGeometry(innerRadius: 3.2, outerRadius: 3.8),
              UnlitMaterial()
                ..baseColorFactor = linearColor(PlazaStyle.teal, alpha: 0.4)
                ..alphaMode = AlphaMode.blend,
            ),
          ),
        );
      // A soft warm pool under home, so the landing is a lit spot on a
      // square rather than a ring on a car park.
      _addPool(
        Vector3(plaza.home.x, 0, plaza.home.z),
        radius: 7,
        color: const Color(0xFFFFE2B8),
        alpha: 0.14,
      );
      _buildPlazaKerb(plaza);
      _buildPlazaFurniture();
    }

    final byId = {for (final t in world.tasks) t.id: t};
    for (final placement in plan.placements.values) {
      final task = byId[placement.taskId];
      if (task == null) continue;
      if (task.deleted) {
        _buildEmptyLot(placement);
      } else {
        _buildBuilding(task, placement);
      }
    }

    for (final (i, slot) in world.builtBillboardSlots.indexed) {
      if (slot.onPylon && !_shown('pylons')) continue;
      _buildBillboard(slot, world.billboards[i]);
    }
    for (final (i, slot) in world.roofBillboards.indexed) {
      _buildBillboard(slot, world.roofBillboardTasks[i]);
    }
    if (_shown('fillers')) _buildFillerBlocks();
    _buildStreetFurniture();
  }

  /// A raised kerb round the plaza's edge, open at the street mouth: a
  /// square with an edge, not a slab. Low enough to step over, so it is
  /// not a solid.
  void _buildPlazaKerb(FrontierPlaza plaza) {
    const kerbW = 0.35;
    const kerbH = 0.16;
    const mouth = 26.0;
    final root = Node(
      localTransform: Matrix4.translation(
        Vector3(plaza.centerX, kerbH / 2, plaza.centerZ),
      )..rotateY(plaza.headingRadians),
    );
    final hw = plaza.width / 2;
    final hd = plaza.depth / 2;
    for (final (dx, dz, sx, sz) in [
      (hw - kerbW / 2, 0.0, kerbW, plaza.depth),
      (-hw + kerbW / 2, 0.0, kerbW, plaza.depth),
      (0.0, hd - kerbW / 2, plaza.width, kerbW),
      // The mouth side, in two runs either side of the opening.
      ((hw + mouth / 2) / 2, -hd + kerbW / 2, hw - mouth / 2, kerbW),
      (-(hw + mouth / 2) / 2, -hd + kerbW / 2, hw - mouth / 2, kerbW),
    ]) {
      _box(root, Vector3(dx, 0, dz), Vector3(sx, kerbH, sz), _kerbMaterial);
    }
    // The threshold: a flush band across the opening, so the step from
    // street to square is a line on the ground you cross.
    _box(
      root,
      Vector3(0, -kerbH / 2 + 0.05, -hd),
      Vector3(mouth, 0.02, 0.7),
      _kerbMaterial,
    );
    scene.add(root);
  }

  /// Benches, planters and the kiosk from `Scenery.furniture`: the boxes
  /// are the collider's, the dressing is here.
  void _buildPlazaFurniture() {
    final seat = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF4A3A2E));
    final soil = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF1E1A1C));
    final leaves = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF1F3A28));
    for (final f in world.scenery.furniture) {
      final root = Node(
        localTransform: Matrix4.translation(Vector3(f.x, 0, f.z))
          ..rotateY(f.yawRadians),
      );
      switch (f.kind) {
        case FurnitureKind.bench:
          // Three slats on a dark frame, a back rail, two end frames.
          for (final dx in [-f.width * 0.34, 0.0, f.width * 0.34]) {
            _box(
              root,
              Vector3(dx, f.height * 0.5, 0),
              Vector3(f.width * 0.28, 0.06, f.depth),
              seat,
            );
          }
          _box(
            root,
            Vector3(0, f.height * 0.46, 0),
            Vector3(f.width * 0.9, 0.04, f.depth * 0.9),
            _postMaterial,
          );
          _box(
            root,
            Vector3(-f.width * 0.55, f.height * 0.75, 0),
            Vector3(0.06, f.height * 0.5, f.depth),
            seat,
          );
          for (final dz in [-f.depth * 0.4, f.depth * 0.4]) {
            _box(
              root,
              Vector3(0, f.height * 0.25, dz),
              Vector3(f.width * 0.9, f.height * 0.5, 0.08),
              _postMaterial,
            );
          }
        case FurnitureKind.planter:
          root.add(
            _boxes.node(
              Vector3(f.width, f.height, f.depth),
              _postMaterial,
              transform: Matrix4.translation(Vector3(0, f.height / 2, 0)),
              shaded: true,
            ),
          );
          _box(
            root,
            Vector3(0, f.height + 0.02, 0),
            Vector3(f.width - 0.2, 0.04, f.depth - 0.2),
            soil,
          );
          root.add(
            _boxes.node(
              Vector3(f.width * 0.72, 0.5, f.depth * 0.72),
              leaves,
              transform: Matrix4.translation(
                Vector3(0, f.height + 0.25, 0),
              ),
              shaded: true,
            ),
          );
          // A lit rim along the planter's top edge, in the parade's warm.
          _box(
            root,
            Vector3(0, f.height + 0.01, 0),
            Vector3(f.width + 0.06, 0.03, f.depth + 0.06),
            _boxes.solid(
              linearColor(
                const Color(0xFFFFC46B),
                alpha: 0.8,
              ),
            ),
          );
        case FurnitureKind.kiosk:
          final sign = UnlitMaterial()
            ..baseColorFactor = linearColor(const Color(0xFFFFC46B));
          final window = UnlitMaterial()
            ..baseColorFactor = linearColor(
              const Color(0xFFFFD08A),
              alpha: 0.75,
            )
            ..alphaMode = AlphaMode.blend;
          _pools.add((window, 0.75));
          root.add(
            _boxes.node(
              Vector3(f.width, f.height, f.depth),
              _towerMaterial,
              transform: Matrix4.translation(Vector3(0, f.height / 2, 0)),
              shaded: true,
            ),
          );
          // The lit sign along the front's top edge, and the hatch.
          _box(
            root,
            Vector3(0, f.height - 0.3, f.depth / 2 + 0.03),
            Vector3(f.width - 0.3, 0.4, 0.06),
            sign,
          );
          root.add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(0, f.height * 0.5, f.depth / 2 + 0.02),
              ),
              mesh: Mesh(ccwQuad(f.width - 0.8, f.height * 0.42), window),
            ),
          );
          _box(
            root,
            Vector3(0, f.height + 0.05, 0),
            Vector3(f.width + 0.4, 0.1, f.depth + 0.4),
            _postMaterial,
          );
          _addPool(
            Vector3(
              f.x + math.sin(f.yawRadians) * 2,
              0,
              f.z + math.cos(f.yawRadians) * 2,
            ),
            radius: 3,
            color: const Color(0xFFFFD08A),
            alpha: 0.16,
          );
      }
      scene.add(root);
    }
  }

  /// Lamp posts, the gantry over the street mouth, the jumbotron tower,
  /// banner anchors and spires: the set dressing that makes a street a
  /// place.
  void _buildStreetFurniture() {
    for (final (x, z) in world.lampPosts) {
      final pole = _box(
        scene.root,
        Vector3(x, lampPostHeight / 2, z),
        Vector3(lampPostSize, lampPostHeight, lampPostSize),
        _postMaterial,
      );
      // Housing: a small dark head the bulb hangs under.
      _box(pole, Vector3(0, 2.7, 0), Vector3(0.7, 0.28, 0.7), _postMaterial);
      final lantern = Node(
        localTransform: Matrix4.translation(Vector3(0, 2.45, 0)),
      );
      pole.add(lantern);
      lampAnchors.add(lantern);
      _addPool(
        Vector3(x, 0, z),
        radius: 5,
        color: const Color(0xFFFFE2B8),
        alpha: 0.3,
      );
    }
    // Every beacon dot stands on a slim post over a small pool in its own
    // colour, so a marker is a fixture in the street and not a stray orb.
    for (final beacon in world.beacons) {
      final colour = PlazaStyle.beaconColor(beacon, world);
      _box(
        scene.root,
        Vector3(beacon.markerX, beacon.markerY / 2, beacon.markerZ),
        Vector3(0.08, beacon.markerY, 0.08),
        _postMaterial,
      );
      _addPool(
        Vector3(beacon.markerX, 0, beacon.markerZ),
        radius: 1.6,
        color: colour,
        alpha: 0.18,
      );
    }

    // Week signs hang from the block-head lamp post: one fixture, not a
    // sign, a lamp and a screen crowding the same kerb.
    for (final (bucket, x, z, facing) in world.weekSigns) {
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(
            x + math.sin(facing) * 0.14,
            3.2,
            z + math.cos(facing) * 0.14,
          ),
        )..rotateY(facing),
      );
      scene.add(anchor);
      weekSignAnchors[bucket] = anchor;
    }

    final gantry = world.gantry;
    if (gantry != null && _shown('gantry')) {
      final root = Node(
        localTransform: Matrix4.translation(Vector3(gantry.x, 0, gantry.z))
          ..rotateY(gantry.facingRadians),
      );
      final top = gantryTopFor(gantry);
      for (final side in [-1.0, 1.0]) {
        _box(
          root,
          Vector3(side * gantry.width / 2, top / 2, 0),
          Vector3(gantryLegSize, top, gantryLegSize),
          _postMaterial,
        );
      }
      _box(
        root,
        Vector3(0, top - gantryBeamThickness / 2, 0),
        Vector3(
          gantry.width + gantryLegSize,
          gantryBeamThickness,
          gantryBeamDepth,
        ),
        _postMaterial,
      );
      root.add(
        _glowQuad(gantry.width + 2, gantry.height + 2.5, PlazaStyle.teal, 0.2)
          ..localTransform = Matrix4.translation(
            Vector3(0, gantry.bottom + gantry.height / 2, -0.3),
          ),
      );
      scene.add(root);
      _addPool(
        Vector3(gantry.x, 0, gantry.z),
        radius: gantry.width * 0.3,
        color: PlazaStyle.teal,
        alpha: 0.05,
      );
    }

    final jumbotron = world.jumbotron;
    if (jumbotron != null && _shown('jumbotron')) {
      final root = Node(
        localTransform: Matrix4.translation(
          Vector3(jumbotron.x, 0, jumbotron.z),
        )..rotateY(jumbotron.facingRadians),
      );
      final box = world.scenery.jumbotronTower!;
      final towerH = box.height;
      final towerW = box.width;
      final towerD = box.depth;
      // The tower is a building, not a slab: windowed on every face, a
      // lit crown, neon on its front corners. Its box is the scenery's,
      // so the collider knows it.
      final tower = _boxes.node(
        Vector3(towerW, towerH, towerD),
        _towerMaterial,
        transform: Matrix4.translation(
          Vector3(0, towerH / 2, -jumbotronTowerSetback),
        ),
        shaded: true,
      );
      _windowedBox(
        tower,
        id: 'jumbotron',
        w: towerW,
        d: towerD,
        height: towerH,
        state: LanternState.inProgress,
        tint: _tower,
      );
      // The corner strips and crown at a quarter, so the screen's own
      // border is the one teal frame on the tower.
      final corner = UnlitMaterial()
        ..baseColorFactor = linearColor(
          Color.lerp(const Color(0xFF0B0A14), PlazaStyle.teal, 0.3)!,
        );
      for (final side in [-1.0, 1.0]) {
        _box(
          tower,
          Vector3(side * (towerW / 2 + 0.1), 0, towerD / 2 + 0.1),
          Vector3(0.25, towerH, 0.25),
          corner,
        );
      }
      // The crown is four rim strips, not a lid.
      _rim(
        tower,
        w: towerW,
        d: towerD,
        y: towerH / 2 + 0.1,
        inset: -0.1,
        overhang: 0.4,
        thickness: 0.22,
        material: corner,
      );
      root.add(tower);
      final backing = _box(
        root,
        Vector3(0, jumbotron.centerY, -0.2),
        Vector3(jumbotron.width + 0.6, jumbotron.height + 0.6, 0.4),
        _boxes.solid(linearColor(PlazaStyle.teal)),
      );
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(0, jumbotron.centerY, 0.06),
        ),
      );
      root.add(anchor);
      jumbotronAnchor = anchor;
      root.add(
        _glowQuad(
            jumbotron.width + 8,
            jumbotron.height + 8,
            PlazaStyle.teal,
            0.22,
          )
          ..localTransform = Matrix4.translation(
            Vector3(0, jumbotron.centerY, -0.5),
          ),
      );
      final jsin = math.sin(jumbotron.facingRadians);
      final jcos = math.cos(jumbotron.facingRadians);
      _addPool(
        Vector3(jumbotron.x + jsin * 9, 0, jumbotron.z + jcos * 9),
        radius: jumbotron.width * 0.3,
        color: PlazaStyle.teal,
        alpha: 0.12,
      );
      _addWash(
        Vector3(jumbotron.x + jsin * 4, 0, jumbotron.z + jcos * 4),
        width: jumbotron.width * 0.7,
        length: jumbotron.width * 0.9,
        yaw: jumbotron.facingRadians,
        color: PlazaStyle.teal,
        alpha: 0.06,
      );
      // The tower's own spire.
      _spire(
        root,
        Vector3(0, towerH, -jumbotronTowerSetback),
        size: jumbotronSpireSize,
        height: jumbotronSpireHeight,
        lightAbove: 0.4,
      );
      scene.add(root);
      final billboard = PlazaBillboard(
        slot: jumbotron,
        attention: world.billboards.isEmpty
            ? world.attention.values.first
            : world.billboards.first,
        backing: backing,
        anchor: anchor,
      );
      chaseLightPoints[billboard] = _frameCorners(jumbotron);
    }

    for (final banner in world.banners) {
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(banner.x, banner.centerY, banner.z),
        )..rotateY(banner.facingRadians),
      );
      scene.add(anchor);
      bannerAnchors[banner.taskId] = anchor;
    }

    for (final p in world.spires) {
      _spire(
        scene.root,
        Vector3(p.x, p.height, p.z),
        size: plotSpireSize,
        height: plotSpireHeight,
        lightAbove: 0.3,
      );
    }
  }

  /// Points around a panel's frame, world space, for the chase lights:
  /// evenly along the perimeter.
  List<Vector3> _frameCorners(BillboardSlot slot) {
    const perSide = 5;
    final sinF = math.sin(slot.facingRadians);
    final cosF = math.cos(slot.facingRadians);
    final hw = slot.width / 2 + 0.18;
    final hh = slot.height / 2 + 0.18;
    Vector3 at(double u, double v) => Vector3(
      slot.x + cosF * u + sinF * 0.2,
      slot.centerY + v,
      slot.z - sinF * u + cosF * 0.2,
    );
    final points = <Vector3>[];
    for (var i = 0; i < perSide; i++) {
      final t = -1 + 2 * (i + 0.5) / perSide;
      points
        ..add(at(t * hw, hh))
        ..add(at(hw, -t * hh))
        ..add(at(-t * hw, -hh))
        ..add(at(-hw, t * hh));
    }
    // Order them clockwise around the frame so the chase runs round.
    final cx = slot.x;
    final cz = slot.z;
    points.sort((a, b) {
      double angle(Vector3 v) {
        final u = (v.x - cx) * cosF - (v.z - cz) * sinF;
        return math.atan2(v.y - slot.centerY, u);
      }

      return angle(a).compareTo(angle(b));
    });
    return points;
  }

  void _buildSky() {
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: linearColor(const Color(0xFF03030B)).xyz,
        horizonColor: linearColor(const Color(0xFF2A2446)).xyz,
        groundColor: linearColor(const Color(0xFF090A16)).xyz,
        sunColor: Vector3.zero(),
      ),
    );
    // Ground-hugging haze in the horizon's own colour: the street dissolves
    // into the sky instead of hitting a seam, and it thins with altitude
    // so the overview still sees the district. The night is a desaturated
    // indigo so amber signage sits warm against it; the magenta lives in
    // the hero towers' domes alone.
    // Real bloom: the emitters (neon, screens, chase heads, rooflines)
    // bleed into the night the way a lightbox does, and a soft vignette
    // pulls the eye to the centre of every frame.
    scene.postProcess.bloom
      ..enabled = true
      ..threshold = bloomThreshold
      ..intensity = bloomIntensity
      ..scatter = 0.6;
    scene.postProcess.vignette
      ..enabled = true
      ..intensity = 0.32
      ..radius = 0.82
      ..smoothness = 0.6;
    scene.fog
      ..enabled = true
      ..mode = FogMode.exponential
      ..density = fogDensityLow
      ..start = 8
      ..height = 0
      ..heightFalloff = 0.028
      ..maxOpacity = fogOpacityLow
      // Between the ground and the horizon: the haze never outshines the
      // paving the walker stands on.
      ..color = linearColor(const Color(0xFF181727)).xyz;
  }

  void _buildBuilding(PlazaTask task, PlotPlacement placement) {
    final attention = world.attentionOf(task);
    final w = placement.width;
    final h = placement.height;
    // Massing: plots vary in depth (hashed, never moving) and the box is
    // anchored to the street side, so the row is not a picket fence.
    final d = placement.depth * (0.78 + 0.32 * stableUnit(task.id, 'depth'));
    final setback = (placement.depth - d) / 2;
    final facing = placement.facingRadians;
    final normal = Vector3(math.sin(facing), 0, math.cos(facing));

    final node = _boxes.node(
      Vector3(w, h, d),
      _boxes.solid(linearColor(PlazaStyle.categoryWall(task))),
      transform: Matrix4.translation(
        Vector3(
          placement.x + normal.x * setback,
          h / 2,
          placement.z + normal.z * setback,
        ),
      )..rotateY(facing),
      shaded: true,
    );
    final parade = stableIndex(task.id, 'parade', WallTextures.paradeVariants);
    final kit = stableIndex(task.id, 'kit', WallTextures.tileFamilies);

    // A pavement apron round the plot, so the building stands on a street
    // and not on a speckled void.
    _box(
      node,
      Vector3(0, -h / 2 + 0.02, 0),
      Vector3(w + 3, 0.04, d + 3),
      _pavementMaterial,
    );
    // Side and back walls: window grids in the state's lit ratio over
    // the shopfront parade dressed for the state, tiled by the wall's
    // size; a hashed tile offset per wall so each starts at its own shop.
    final wallTint = linearColor(
      Color.lerp(PlazaStyle.categoryWall(task), const Color(0xFF0B0A14), 0.5)!,
    );
    if (_shown('walls')) {
      _windowedBox(
        node,
        id: task.id,
        w: w,
        d: d,
        height: h,
        faces: const [_Face.left, _Face.right, _Face.back],
        state: attention.lantern,
        tint: wallTint,
        variant: parade,
        family: kit,
      );
    }
    // An alarmed building spills its state colour onto the ground round
    // every wall: the coral or amber under the doors is what a walker
    // sees first.
    final alarm =
        attention.lantern == LanternState.blocked ||
        attention.lantern == LanternState.overdue;
    if (alarm) {
      final spill = PlazaStyle.lantern(attention.lantern);
      final sinF = math.sin(facing);
      final cosF = math.cos(facing);
      final cx = placement.x + normal.x * setback;
      final cz = placement.z + normal.z * setback;
      for (final (lx, lz, r) in [
        (0.0, d / 2 + 1.5, w * 0.45),
        (0.0, -d / 2 - 1.5, w * 0.45),
        (w / 2 + 1.5, 0.0, d * 0.45),
        (-w / 2 - 1.5, 0.0, d * 0.45),
      ]) {
        _addPool(
          Vector3(cx + lx * cosF + lz * sinF, 0, cz - lx * sinF + lz * cosF),
          radius: math.max(r, 3),
          color: spill,
          alpha: 0.14,
        );
      }
    }

    // Contact band: a dark plinth so the box sits on the ground.
    _box(
      node,
      Vector3(0, -h / 2 + 0.35, 0),
      Vector3(w + 0.1, 0.7, d + 0.1),
      _boxes.solid(linearColor(const Color(0xFF0A0910))),
    );

    // Tall buildings step back to an upper storey with its own roof.
    if (h >= 14) {
      final upperH = h * 0.22;
      node.add(
        _boxes.node(
          Vector3(w * 0.68, upperH, d * 0.7),
          _boxes.solid(linearColor(PlazaStyle.categoryRoof(task))),
          transform: Matrix4.translation(
            Vector3(0, h / 2 + upperH / 2, -d * 0.12),
          ),
          shaded: true,
        ),
      );
    }

    // A tall building's screen hangs above a street-level parade, a
    // storey of windows either side of it, so the wall owns the screen
    // instead of being one; a short one is all sign, as before.
    final hasParade = h >= paradeWallHeight;
    final facadeW = hasParade ? w * 0.8 : w * 0.92;
    final facadeH = hasParade ? h - shopfrontHeight - 1 : h * 0.9;
    final panelY = hasParade ? (shopfrontHeight + 0.4 - 0.6) / 2 : 0.0;
    if (hasParade) {
      _windowedWall(
        node,
        dx: 0,
        dz: d / 2 + 0.015,
        yaw: 0,
        width: w,
        height: h,
        state: attention.lantern,
        tint: wallTint,
        uOffset: stableUnit(task.id, 'tilefront') * 3,
        variant: stableIndex(
          task.id,
          'paradefront',
          WallTextures.paradeVariants,
        ),
        family: kit,
      );
    }

    // Roof: a darker slab so the top reads apart from the walls.
    _box(
      node,
      Vector3(0, h / 2 + 0.02, 0),
      Vector3(w + 0.04, 0.04, d + 0.04),
      _boxes.solid(
        linearColor(
          Color.lerp(
            PlazaStyle.categoryRoof(task),
            const Color(0xFF07060D),
            0.5,
          )!,
        ),
      ),
    );
    // Far-tier surface: an always-present dark plate; the lantern carries
    // the state colour, the plate only says "there is a facade here".
    // The plate, the neon glows and the widget surface stand 1–3 cm apart
    // along the wall's normal, which the depth buffer cannot separate a
    // few hundred metres out; each layer is biased toward the eye a
    // little more than the one behind it (`Material.depthBias`), so a
    // facade never flickers between its layers during a flight.
    final plate = _box(
      node,
      Vector3(0, panelY, d / 2 + 0.03),
      Vector3(facadeW, facadeH, 0.02),
      _boxes.solid(_panelBack, depthBias: plateDepthBias),
    );

    // Progress light bar along the base, visible at every tier.
    final pct = task.state == PlazaTaskState.done
        ? 1.0
        : task.checklistItems > 0
        ? task.progress
        : task.state == PlazaTaskState.inProgress
        ? 0.35
        : 0.0;
    // On the plinth, not the panel: a full-width track that reads against
    // the dark band, filled from the left, so the lit part is progress
    // along something rather than an orphan block on the wall.
    final plinthY = -h / 2 + 0.35;
    _box(
      node,
      Vector3(0, plinthY, d / 2 + 0.1),
      Vector3(facadeW, 0.28, 0.1),
      _boxes.solid(
        linearColor(
          Color.lerp(PlazaStyle.panel, PlazaStyle.textDim, 0.25)!,
        ),
      ),
    );
    // Seen from the street a +Z face's +X is the viewer's left (the
    // widget quads map their texture left edge to +X), so the bar fills
    // from +X toward -X: left to right for the walker.
    if (pct > 0) {
      _box(
        node,
        Vector3(facadeW / 2 - facadeW * pct / 2, plinthY, d / 2 + 0.12),
        Vector3(facadeW * pct, 0.28, 0.12),
        _boxes.solid(linearColor(PlazaStyle.lightBar(attention))),
      );
    }
    // Quarter ticks so the bar has a scale.
    for (final q in [0.25, 0.5, 0.75]) {
      _box(
        node,
        Vector3(facadeW / 2 - facadeW * q, plinthY, d / 2 + 0.16),
        Vector3(0.06, 0.28, 0.04),
        _boxes.solid(linearColor(const Color(0xFF07060D))),
      );
    }

    // Neon edge strips in the category's neon: two verticals and the
    // roofline, the Blade Runner outline that reads at every range.
    // Emissive level follows state: a finished shop is dark, an open one
    // glows, an anomaly burns; the category neon stays a secondary
    // register under the state colour. Each strip gets a soft glow quad
    // behind it — the faux bloom.
    final emissive = switch (attention.lantern) {
      LanternState.off => 0.22,
      LanternState.open => 0.7,
      _ => 1.0,
    };
    final categoryNeon = PlazaStyle.neon(PlazaStyle.categoryBright(task));
    final neonColor = Color.lerp(
      const Color(0xFF0B0A14),
      categoryNeon,
      emissive,
    )!;
    // One colour rule: on an anomaly the state owns the brightest register
    // (the two verticals and their glow burn in the lantern colour); the
    // category survives on the roofline at half power.
    final stateNeon = PlazaStyle.lantern(attention.lantern);
    // Lit neon goes past white so the bloom pass carries it; a dark shop's
    // strips stay under the threshold.
    final boost = emissive >= 0.7 ? neonBoost : 1.0;
    final vertical = UnlitMaterial()
      ..baseColorFactor = emissiveColor(alarm ? stateNeon : neonColor, boost);
    final roofline = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        alarm
            ? Color.lerp(const Color(0xFF0B0A14), categoryNeon, 0.5)!
            : neonColor,
        boost,
      );
    // The strips and their glow live in one group, hidden while the
    // focus ring is up: one frame per facade at a time.
    final neon = Node();
    node.add(neon);
    const strip = 0.2;
    for (final (dx, dy, sw, sh, isRoofline) in [
      (-facadeW / 2 - 0.12, 0.0, strip, facadeH, false),
      (facadeW / 2 + 0.12, 0.0, strip, facadeH, false),
      (0.0, facadeH / 2 + 0.12, facadeW + 0.4, strip, true),
    ]) {
      _box(
        neon,
        Vector3(dx, dy + panelY, d / 2 + 0.05),
        Vector3(sw, sh, strip),
        isRoofline ? roofline : vertical,
      );
      if (emissive > 0.3) {
        neon.add(
          _glowQuad(
              sw + 1.1,
              sh + 1.1,
              alarm && !isRoofline ? stateNeon : categoryNeon,
              (alarm && isRoofline ? 0.08 : 0.16) * emissive,
              depthBias: glowDepthBias,
            )
            ..localTransform = Matrix4.translation(
              Vector3(dx, dy + panelY, d / 2 + 0.04),
            ),
        );
      }
    }
    // What the lit facade throws on the street: a warm strip under a
    // trading parade, a streak of the state colour on an alarm.
    final trading = attention.lantern == LanternState.inProgress;
    if (trading || alarm) {
      _addWash(
        Vector3(
          placement.x + normal.x * (d / 2 + setback),
          0,
          placement.z + normal.z * (d / 2 + setback),
        ),
        width: facadeW * (alarm ? 0.8 : 1),
        length: alarm ? facadeH * 1.2 : 3,
        yaw: facing,
        color: alarm ? stateNeon : const Color(0xFFFFC46B),
        alpha: alarm ? 0.09 : 0.07,
      );
    }
    // Roof outline: the top edge lit dimly on all four sides so height
    // reads from above.
    final roofTrim = UnlitMaterial()
      ..baseColorFactor = linearColor(
        Color.lerp(const Color(0xFF0B0A14), neonColor, 0.55)!,
      );
    _rim(
      node,
      w: w,
      d: d,
      y: h / 2 + 0.08,
      overhang: 0.2,
      thickness: 0.14,
      material: roofTrim,
    );
    _addRoofKit(node, task, w, h, d);
    // Light pool on the street in front of a lit facade: the wet-street
    // reflection, without a reflection. Sits above the pavement so it
    // never fights the slab.
    if (attention.lantern != LanternState.off) {
      _addPool(
        Vector3(
          placement.x + normal.x * (placement.depth / 2 + facadeW * 0.3),
          0,
          placement.z + normal.z * (placement.depth / 2 + facadeW * 0.3),
        ),
        radius: facadeW * 0.55,
        color: PlazaStyle.lantern(attention.lantern),
        alpha: attention.lantern == LanternState.open ? 0.13 : 0.26,
      );
    }

    // Focus ring: four teal slats just outside the facade, hidden until
    // the walker faces this building.
    final ring = Node(
      localTransform: Matrix4.translation(Vector3(0, panelY, d / 2 + 0.07)),
    )..visible = false;
    // The ring burns in the state's own colour: the faced building keeps
    // the far-tier colour language on arrival.
    final ringMaterial = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        PlazaStyle.lantern(attention.lantern),
        neonBoost,
      )
      ..depthBias = glowDepthBias;
    const t = 0.12;
    const off = 0.25;
    for (final (dx, dy, sw, sh) in [
      (0.0, facadeH / 2 + off, facadeW + 2 * off + t, t),
      (0.0, -facadeH / 2 - off, facadeW + 2 * off + t, t),
      (-facadeW / 2 - off, 0.0, t, facadeH + 2 * off),
      (facadeW / 2 + off, 0.0, t, facadeH + 2 * off),
    ]) {
      _box(ring, Vector3(dx, dy, 0), Vector3(sw, sh, t), ringMaterial);
    }
    node.add(ring);

    // Anchor for the live/sign widget surface, in front of the plate.
    final facadeAnchor = Node(
      localTransform: Matrix4.translation(Vector3(0, panelY, d / 2 + 0.1)),
    );
    node.add(facadeAnchor);

    final lanternAnchor = Node(
      localTransform: Matrix4.translation(Vector3(0, h / 2 + 0.7, 0)),
    );
    node.add(lanternAnchor);

    scene.add(node);

    final building = PlazaBuilding(
      task: task,
      attention: attention,
      placement: placement,
      node: node,
      facadeAnchor: facadeAnchor,
      ring: ring,
      neon: neon,
      lanternAnchor: lanternAnchor,
      facadeCenter: Vector3(
        placement.x + normal.x * (d / 2),
        h / 2 + panelY,
        placement.z + normal.z * (d / 2),
      ),
      facadeNormal: normal,
      facadeWorldWidth: facadeW,
      facadeWorldHeight: facadeH,
      liveRange: taskStandOffFor(placement) + 2,
      pxPerMeter: pxPerMeter,
    );
    buildings.add(building);
    pickableBuildings[plate] = building;
  }

  void _buildEmptyLot(PlotPlacement placement) {
    // Fenced empty lot: foundations visible, street never closes up.
    scene.add(
      _boxes.node(
        Vector3(placement.width, 0.5, placement.depth),
        _boxes.solid(linearColor(const Color(0xFF14161C))),
        transform: Matrix4.translation(
          Vector3(placement.x, 0.25, placement.z),
        )..rotateY(placement.facingRadians),
      ),
    );
  }

  void _buildBillboard(BillboardSlot slot, TaskAttention attention) {
    final root = Node(
      localTransform: Matrix4.translation(Vector3(slot.x, 0, slot.z))
        ..rotateY(slot.facingRadians),
    );
    final frame = PlazaStyle.lantern(attention.lantern);
    if (slot.mount == BillboardMount.roof) {
      // Two short struts on the roof.
      for (final side in [-1.0, 1.0]) {
        _box(
          root,
          Vector3(side * slot.width * 0.4, slot.bottom - 0.25, -0.3),
          Vector3(0.25, 0.5, 0.25),
          _postMaterial,
        );
      }
    }
    if (slot.onPylon) {
      // Heavy steel: two braced posts on footings, a catwalk under the
      // panel.
      for (final side in [-1.0, 1.0]) {
        final px = side * slot.width * pylonPostSpread;
        _box(
          root,
          Vector3(px, slot.bottom / 2, -pylonPostSetback),
          Vector3(pylonPostSize, slot.bottom, pylonPostSize),
          _postMaterial,
        );
        _box(
          root,
          Vector3(px, 0.3, -pylonPostSetback),
          Vector3(pylonFootingSize, 0.6, pylonFootingSize),
          _postMaterial,
        );
      }
      _box(
        root,
        Vector3(0, slot.bottom * 0.55, -0.6),
        Vector3(slot.width * 0.8, 0.25, 0.25),
        _postMaterial,
      );
      _box(
        root,
        Vector3(0, slot.bottom - 0.3, 0.5),
        Vector3(slot.width + 0.8, 0.12, 1.2),
        _postMaterial,
      );
      // Light pool on the ground in the state colour, and a wide faint
      // wash in front of it so the panel connects to the paving.
      final sinF = math.sin(slot.facingRadians);
      final cosF = math.cos(slot.facingRadians);
      _addPool(
        Vector3(slot.x + sinF * 2.5, 0, slot.z + cosF * 2.5),
        radius: math.max(slot.width, 8) * 0.45,
        color: frame,
        alpha: 0.34,
      );
      _addPool(
        Vector3(
          slot.x + sinF * slot.width * 0.5,
          0,
          slot.z + cosF * slot.width * 0.5,
        ),
        radius: slot.width * 1.5,
        color: frame,
        alpha: 0.07,
      );
      // The panel's reflection: a streak on the paving toward the walker.
      _addWash(
        Vector3(slot.x + sinF * 1.2, 0, slot.z + cosF * 1.2),
        width: slot.width * 0.8,
        length: slot.height * 1.6,
        yaw: slot.facingRadians,
        color: frame,
        alpha: 0.09,
      );
    }
    // Backing box: a real lightbox with depth, dark body and a rim in the
    // state colour at its front edge, so the billboard reads from the
    // skyline before its widget surface exists and the chase lights have a
    // bezel to sit on.
    final depth = slot.mount == BillboardMount.roof ? 0.4 : 0.7;
    final backing = _box(
      root,
      Vector3(0, slot.centerY, -depth / 2 - 0.02),
      Vector3(slot.width + 0.5, slot.height + 0.5, depth),
      _towerMaterial,
    );
    // A pylon's or a roof panel's back is open to the street: the same
    // capture shows through, mirrored ([backQuad] keeps the front's UVs
    // and faces the other way, so the eye reads them backwards) and
    // dimmed, inside the box's rim.
    UnlitMaterial? back;
    if (slot.mount != BillboardMount.wall) {
      back = UnlitMaterial()
        ..baseColorFactor = Vector4(
          PlazaBillboard.backTint,
          PlazaBillboard.backTint,
          PlazaBillboard.backTint,
          1,
        )
        ..alphaMode = AlphaMode.opaque;
      root.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(0, slot.centerY, -depth - 0.03),
          ),
          mesh: Mesh(backQuad(slot.width, slot.height), back),
        ),
      );
    }
    // Faux bloom: a wide soft glow behind the lightbox. Not a pool: the
    // surfaces breathe it and fade it with [poolFade] themselves.
    final glow = UnlitMaterial()
      ..baseColorFactor = linearColor(frame, alpha: PlazaBillboard.glowAlpha)
      ..alphaMode = AlphaMode.blend;
    root.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(0, slot.centerY, -depth - 0.06),
        ),
        mesh: Mesh(ccwQuad(slot.width + 3, slot.height + 3), glow),
      ),
    );
    // The panel's own border is the one frame; the lightbox bezel and the
    // chase lights sit behind it.
    final anchor = Node(
      localTransform: Matrix4.translation(Vector3(0, slot.centerY, 0.06)),
    );
    root.add(anchor);
    scene.add(root);
    final billboard = PlazaBillboard(
      slot: slot,
      attention: attention,
      backing: backing,
      anchor: anchor,
      glow: glow,
      back: back,
    );
    billboards.add(billboard);
    pickableBillboards[backing] = billboard;
    chaseLightPoints[billboard] = _frameCorners(slot);
  }

  /// A light pool on the ground: one quad with a radial-falloff texture
  /// (hot core, long feathered skirt) in the light's colour, above the
  /// pavement top; fades with camera altitude in [updateForCamera].
  void _addPool(
    Vector3 at, {
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend;
    _pools.add((material, alpha));
    scene.add(
      Node(
        localTransform: Matrix4.translation(Vector3(at.x, _groundTop, at.z))
          ..rotateX(-math.pi / 2),
        mesh: Mesh(ccwQuad(radius * 2, radius * 2), material),
      ),
    );
  }

  /// A rectangular pool: the radial falloff stretched over [width] by
  /// [length] on the ground, its far edge at [at] and its length running
  /// out along [yaw]. The streak a lit panel leaves on wet paving, or the
  /// strip of light a parade throws on the pavement.
  void _addWash(
    Vector3 at, {
    required double width,
    required double length,
    required double yaw,
    required Color color,
    required double alpha,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend;
    _washes.add((material, alpha));
    scene.add(
      Node(
        localTransform:
            Matrix4.translation(
                Vector3(
                  at.x + math.sin(yaw) * length / 2,
                  _groundTop,
                  at.z + math.cos(yaw) * length / 2,
                ),
              )
              ..rotateY(yaw)
              ..rotateX(-math.pi / 2),
        mesh: Mesh(ccwQuad(width, length), material),
      ),
    );
  }

  /// A soft glow quad behind an emitter: the faux bloom that makes neon
  /// and lightboxes read as lit rather than painted.
  /// Depth biases, world metres toward the eye, for the layers on a
  /// facade: the plate over the window wall, the neon glows and the focus
  /// ring over the plate; the widget surface (`widgetDepthBias`) over all.
  static const plateDepthBias = 0.05;
  static const glowDepthBias = 0.1;

  Node _glowQuad(
    double width,
    double height,
    Color color,
    double alpha, {
    double depthBias = 0,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend
      ..depthBias = depthBias;
    _pools.add((material, alpha));
    return Node(mesh: Mesh(ccwQuad(width, height), material));
  }

  /// A spire [size] square and [height] tall standing on [base] under
  /// [parent], with the anchor for its blinking light [lightAbove] the
  /// tip. The jumbotron and hero towers hang theirs 0.4 up, a plot 0.3.
  void _spire(
    Node parent,
    Vector3 base, {
    required double size,
    required double height,
    required double lightAbove,
  }) {
    _box(
      parent,
      Vector3(base.x, base.y + height / 2, base.z),
      Vector3(size, height, size),
      _postMaterial,
    );
    final light = Node(
      localTransform: Matrix4.translation(
        Vector3(base.x, base.y + height + lightAbove, base.z),
      ),
    );
    parent.add(light);
    spireAnchors.add(light);
  }

  /// A big screen on a tower's district-facing wall under [parent]: a
  /// [width] × [height] backing in the [frame] colour at [y], standing
  /// [front] out from the parent's centre, a glow [glowMargin] wider
  /// behind it at [glowAlpha], and the anchor the widget for anomaly
  /// [rank] hangs on, appended to [skylineScreens].
  void _towerScreen(
    Node parent, {
    required double width,
    required double height,
    required double y,
    required double front,
    required Color frame,
    required double glowMargin,
    required double glowAlpha,
    required int rank,
  }) {
    _box(
      parent,
      Vector3(0, y, front + 0.3),
      Vector3(width + 0.8, height + 0.8, 0.6),
      _boxes.solid(linearColor(frame)),
    );
    parent.add(
      _glowQuad(width + glowMargin, height + glowMargin, frame, glowAlpha)
        ..localTransform = Matrix4.translation(Vector3(0, y, front + 0.2)),
    );
    final anchor = Node(
      localTransform: Matrix4.translation(Vector3(0, y, front + 0.66)),
    );
    parent.add(anchor);
    skylineScreens.add((anchor, width, height, rank));
  }

  /// Seeded roof clutter: a parapet lip, one or two plant boxes, a water
  /// tank on some, an antenna mast on a third. Hashed from the task id so
  /// it never changes under the user's feet.
  void _addRoofKit(Node node, PlazaTask task, double w, double h, double d) {
    final dark = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF14121E));
    final top = h / 2;
    // Parapet lip.
    _rim(
      node,
      w: w,
      d: d,
      y: top + 0.25,
      inset: 0.15,
      thickness: 0.3,
      height: 0.5,
      material: dark,
    );
    final plantCount = 1 + (stableUnit(task.id, 'plant') < 0.5 ? 1 : 0);
    for (var i = 0; i < plantCount; i++) {
      final bw = math.min(w * 0.3, 2.4);
      final bd = math.min<double>(d * 0.3, 2);
      final bx = (stableUnit(task.id, 'px$i') - 0.5) * (w - bw - 1);
      final bz = (stableUnit(task.id, 'pz$i') - 0.5) * (d - bd - 1);
      _box(node, Vector3(bx, top + 0.7, bz), Vector3(bw, 1.4, bd), dark);
    }
    if (stableUnit(task.id, 'tank') < 0.4 && w > 5) {
      final tx = (stableUnit(task.id, 'tx') - 0.5) * (w - 3);
      final tz = (stableUnit(task.id, 'tz') - 0.5) * (d - 3);
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(tx, top + 1.5, tz)),
          mesh: Mesh(
            CylinderGeometry(
              bottomRadius: 0.9,
              topRadius: 0.9,
              height: 2.2,
              radialSegments: 8,
            ),
            dark,
          ),
        ),
      );
    }
    if (stableUnit(task.id, 'mast') < 0.33) {
      final mx = (stableUnit(task.id, 'mx') - 0.5) * (w - 1);
      _box(
        node,
        Vector3(mx, top + roofKitHeight / 2, 0),
        Vector3(0.12, roofKitHeight, 0.12),
        dark,
      );
    }
  }

  /// City fabric behind the plots (`Scenery.fillers`): dark windowed
  /// blocks with alleys between them, so the street has a back and the
  /// overview has texture between the plots and the skyline.
  void _buildFillerBlocks() {
    for (final block in world.scenery.fillers) {
      final id = block.id;
      final side = block.side;
      final bw = block.depth; // frontage along the road
      final bd = block.width; // reach away from it
      final bh = block.height;
      // Local x is lateral, local z runs along the road: the block is
      // bw long along the street and bd deep away from it.
      final node = _boxes.node(
        Vector3(bd, bh, bw),
        _towerMaterial,
        transform: Matrix4.translation(Vector3(block.x, bh / 2, block.z))
          ..rotateY(block.yawRadians),
        shaded: true,
      );
      final parade = stableIndex(id, 'parade', WallTextures.paradeVariants);
      final kit = stableIndex(id, 'kit', WallTextures.tileFamilies);
      // Windows on every face: a filler is seen from the street, from
      // the plaza and from above.
      _windowedBox(
        node,
        id: id,
        w: bd,
        d: bw,
        height: bh,
        faces: const [_Face.right, _Face.left, _Face.front, _Face.back],
        state: LanternState.open,
        tint: _tower,
        // The fabric trades all night, whatever its flats are doing.
        shops: LanternState.inProgress,
        variant: parade,
        family: kit,
      );
      // The parade's light on the pavement, on the street side.
      {
        final yaw = block.yawRadians + (side < 0 ? math.pi / 2 : -math.pi / 2);
        _addWash(
          Vector3(
            block.x + math.sin(yaw) * bd / 2,
            0,
            block.z + math.cos(yaw) * bd / 2,
          ),
          width: bw,
          length: 2.5,
          yaw: yaw,
          color: const Color(0xFFFFC46B),
          alpha: 0.06,
        );
      }
      if (stableUnit(id, 'sign') < 0.34) {
        // A neon sign down the street-facing corner, named after one
        // of the week's own tasks' category.
        final weekTasks =
            plan.placements.values
                .where((p) => p.bucketIndex == block.bucketIndex)
                .map((p) => p.taskId)
                .toList()
              ..sort();
        if (weekTasks.isNotEmpty) {
          final pick = stableIndex(id, 'pick', weekTasks.length);
          final anchor = Node(
            localTransform: Matrix4.translation(
              Vector3(-side * (bd / 2 + 0.08), bh * 0.15, -bw / 2 + 1.2),
            )..rotateY(side < 0 ? math.pi / 2 : -math.pi / 2),
          );
          node.add(anchor);
          fillerSigns.add((anchor, 1.6, bh * 0.6, weekTasks[pick]));
        }
      }
      scene.add(node);
    }
  }

  /// One hero tower past the far end of every row that folds
  /// (`Scenery.heroTowers`), on the row's axis, with a screen toward the
  /// street and a warm light dome behind it: the horizon a walker walks
  /// toward. The last row's far end has the jumbotron instead.
  void _buildHeroTowers() {
    for (final tower in world.scenery.heroTowers) {
      final id = tower.id;
      final w = tower.width;
      final bd = tower.depth;
      final height = tower.height;
      // The root faces back down the row.
      final root = Node(
        localTransform: Matrix4.translation(Vector3(tower.x, 0, tower.z))
          ..rotateY(tower.yawRadians),
      );
      final box = _boxes.node(
        Vector3(w, height, bd),
        _towerMaterial,
        transform: Matrix4.translation(Vector3(0, height / 2, 0)),
        shaded: true,
      );
      final parade = stableIndex(id, 'parade', WallTextures.paradeVariants);
      root.add(box);
      _windowedBox(
        box,
        id: id,
        w: w,
        d: bd,
        height: height,
        state: LanternState.inProgress,
        tint: _tower,
        variant: parade,
      );
      // Crown: a lit trim and a spire with a blinking light.
      _box(
        root,
        Vector3(0, height + 0.1, 0),
        Vector3(w + 0.3, 0.2, bd + 0.3),
        _boxes.solid(linearColor(PlazaStyle.teal, alpha: 0.9)),
      );
      _spire(
        root,
        Vector3(0, height, 0),
        size: heroSpireSize,
        height: heroSpireHeight,
        lightAbove: 0.4,
      );
      // The screen, toward the street, and the dome of light behind the
      // tower that the row's vanishing point sits in.
      if (world.anomalies.isNotEmpty) {
        final sw = w * 0.9;
        final sh = sw * 0.62;
        final frame = PlazaStyle.lantern(world.anomalies.first.lantern);
        _towerScreen(
          root,
          width: sw,
          height: sh,
          y: height * 0.62,
          front: bd / 2,
          frame: frame,
          glowMargin: 8,
          glowAlpha: 0.28,
          rank: 0,
        );
        // The screen's wash on the ground before the tower.
        _addPool(
          Vector3(
            tower.x + math.sin(tower.yawRadians) * (bd / 2 + sw * 0.6),
            0,
            tower.z + math.cos(tower.yawRadians) * (bd / 2 + sw * 0.6),
          ),
          radius: sw * 1.2,
          color: frame,
          alpha: 0.06,
        );
      }
      root.add(
        _glowQuad(w * 9, height * 1.4, const Color(0xFFFF7A4A), 0.11)
          ..localTransform = Matrix4.translation(
            Vector3(0, height * 0.35, -bd / 2 - 24),
          ),
      );
      scene.add(root);
    }
  }

  /// A ring of dark towers around the district (`Scenery.skyline`) so the
  /// street dissolves into a city instead of a black table. Seeded, never
  /// data.
  void _buildSkyline() {
    for (final tower in world.scenery.skyline) {
      final id = tower.id;
      final i = tower.index;
      final w = tower.width;
      final h = tower.height;
      final node = _boxes.node(
        Vector3(w, h, tower.depth),
        _boxes.solid(_skyline),
        transform: Matrix4.translation(Vector3(tower.x, h / 2, tower.z))
          ..rotateY(tower.yawRadians),
        shaded: true,
      );
      // A lit roofline along the district-facing edge, warm and teal by
      // turns, so the ring is a glowing horizon and not a row of dots.
      final roofline = i.isEven ? const Color(0xFFFFC46B) : PlazaStyle.teal;
      _box(
        node,
        Vector3(0, h / 2 + 0.1, tower.depth / 2 - 0.1),
        Vector3(w + 0.2, 0.25, 0.25),
        _boxes.solid(emissiveColor(roofline, neonBoost, alpha: 0.95)),
      );
      node.add(
        _glowQuad(w + 4, 3, roofline, 0.16)
          ..localTransform = Matrix4.translation(
            Vector3(0, h / 2 + 0.6, tower.depth / 2 + 0.05),
          ),
      );
      // Every fourth tower carries a big screen on its district-facing
      // face: the hi-rises behind Times Square are where the screens are.
      if (i % 4 == 1 && world.anomalies.isNotEmpty) {
        final sw = w * 0.82;
        final sh = sw * 0.5;
        final sy = h * 0.55;
        final rank = (i ~/ 4) % world.anomalies.length;
        _towerScreen(
          node,
          width: sw,
          height: sh,
          y: sy - h / 2,
          front: tower.depth / 2,
          frame: PlazaStyle.lantern(world.anomalies[rank].lantern),
          glowMargin: 6,
          glowAlpha: 0.25,
          rank: rank,
        );
      }
      // Two windowed faces toward the district, tiled from one offset.
      _windowedBox(
        node,
        id: id,
        w: w,
        d: tower.depth,
        height: h,
        faces: const [_Face.front, _Face.left],
        state: LanternState.off,
        tint: _tower,
        perFaceOffset: false,
      );
      scene.add(node);
    }
  }
}
