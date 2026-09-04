import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Size;

import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
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

/// A CCW quad whose texture coordinates repeat [uRepeat] × [vRepeat] times
/// (textures sample with wrap-around), offset by [uOffset] so tiled walls
/// do not all show the same windows.
Geometry tiledQuad(
  double width,
  double height, {
  required double uRepeat,
  required double vRepeat,
  double uOffset = 0,
}) {
  final hw = width / 2;
  final hh = height / 2;
  final u0 = uOffset;
  final u1 = uOffset + uRepeat;
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      hw, -hh, 0, //
      -hw, -hh, 0, //
      -hw, hh, 0, //
      hw, hh, 0, //
    ]),
    texCoords: Float32List.fromList([u0, vRepeat, u1, vRepeat, u1, 0, u0, 0]),
    indices: [3, 1, 0, 2, 1, 3],
  );
}

/// An opaque material for a widget surface plus the bind callback that
/// hands it each capture. Widget content here is fully opaque, and an
/// opaque surface depth-tests like geometry, whereas the default
/// alpha-blended surface sorts unreliably against other surfaces (a banner
/// sixty metres away drew over a pylon fourteen metres away).
class OpaqueSurface {
  OpaqueSurface() : material = UnlitMaterial()..alphaMode = AlphaMode.opaque;

  final UnlitMaterial material;

  void bind(gpu.Texture texture) {
    material.baseColorTexture = GpuTextureSource(texture);
  }
}

/// Deterministic 0..1 from a task id and a salt.
double _unit(String id, String salt) =>
    (stableHash('$id:$salt') & 0xFFFF) / 0xFFFF;

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
    required this.lanternAnchor,
    required this.facadeCenter,
    required this.facadeNormal,
    required this.facadeWorldWidth,
    required this.facadeWorldHeight,
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

  /// Where the roof lantern sprite hangs.
  final Node lanternAnchor;

  /// World-space centre of the facade, for camera-distance ranking.
  final Vector3 facadeCenter;

  /// Unit outward normal of the facade (toward the road).
  final Vector3 facadeNormal;

  final double facadeWorldWidth;
  final double facadeWorldHeight;
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
  });

  final BillboardSlot slot;
  final TaskAttention attention;
  final Node backing;
  final Node anchor;

  Vector3 get center => Vector3(slot.x, slot.centerY, slot.z);
}

/// Builds and owns the plaza [Scene]: dusk sky, fog, ground, the folded
/// street, the frontier plaza with its pylons, and every building with its
/// far-tier plate, focus ring and lantern anchor.
///
/// Widget surfaces (facades, billboards, tickers, block markers) and the
/// screen-clamped sprites are attached by the other scene classes.
class PlazaSceneController {
  PlazaSceneController({required this.world, double? pxPerMeter})
    : pxPerMeter = pxPerMeter ?? world.layout.pxPerMeter {
    _build();
  }

  final PlazaWorld world;
  final double pxPerMeter;
  final Scene scene = Scene();
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

  static final Vector4 _ground = linearColor(const Color(0xFF15131E));
  static final Vector4 _road = linearColor(const Color(0xFF232634));
  static final Vector4 _gap = linearColor(const Color(0xFF1C1E29));
  static final Vector4 _plaza = linearColor(const Color(0xFF2A2D3A));
  static final Vector4 _post = linearColor(const Color(0xFF14171F));
  static final Vector4 _tower = linearColor(const Color(0xFF0E0B18));
  static final Vector4 _pavement = linearColor(const Color(0xFF232532));
  static final Vector4 _kerb = linearColor(const Color(0xFF4A4E60));
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
  final Map<LanternState, List<UnlitMaterial>> _wallMaterials = {};

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

  /// Gives every windowed wall its texture once the tiles are uploaded,
  /// the pools their falloff and the ground its grain.
  void attachWallTextures(WallTextures textures) {
    for (final entry in _wallMaterials.entries) {
      for (final material in entry.value) {
        material
          ..baseColorTexture = textures[entry.key]
          ..baseColorFactor = Vector4(1, 1, 1, 1);
      }
    }
    for (final (material, _) in _pools) {
      material.baseColorTexture = textures.pool;
    }
    for (final material in _grainMaterials) {
      material.baseColorTexture = textures.grain;
    }
  }

  /// Fades every light pool with the camera's height above the street:
  /// full at eye level, gone by [poolFadeTop] metres up.
  static const poolFadeStart = 12.0;
  static const poolFadeTop = 70.0;
  void updateForCamera(Vector3 eye) {
    final k =
        1 -
        ((eye.y - poolFadeStart) / (poolFadeTop - poolFadeStart)).clamp(
          0.0,
          1.0,
        );
    for (final (material, alpha) in _pools) {
      material.baseColorFactor = Vector4(
        material.baseColorFactor.x,
        material.baseColorFactor.y,
        material.baseColorFactor.z,
        alpha * k,
      );
    }
  }

  /// A grain overlay on a ground slab: a blended tiled quad just above it.
  void _addGrain(Node parent, double width, double depth, double y) {
    final material = UnlitMaterial()
      ..baseColorFactor = Vector4(1, 1, 1, 0.4)
      ..alphaMode = AlphaMode.blend;
    _grainMaterials.add(material);
    parent.add(
      Node(
        localTransform: Matrix4.translation(Vector3(0, y, 0))
          ..rotateX(-math.pi / 2),
        mesh: Mesh(
          tiledQuad(width, depth, uRepeat: width / 6, vRepeat: depth / 6),
          material,
        ),
      ),
    );
  }

  static final Vector4 _panelBack = linearColor(PlazaStyle.panel);

  void _build() {
    _buildSky();

    final center = _planCenter();
    scene.add(
      Node(
        localTransform: Matrix4.translation(Vector3(center.x, -0.06, center.z)),
        mesh: Mesh(
          CuboidGeometry(Vector3(6000, 0.1, 6000)),
          UnlitMaterial()..baseColorFactor = _ground,
        ),
      ),
    );
    _buildSkyline(center);

    for (final segment in plan.segments) {
      final midAlong = segment.length / 2;
      final mid = Vector3(
        segment.startX + math.sin(segment.headingRadians) * midAlong,
        0,
        segment.startZ + math.cos(segment.headingRadians) * midAlong,
      );
      final roadNode = Node(
        localTransform: Matrix4.translation(mid)
          ..rotateY(segment.headingRadians),
        mesh: Mesh(
          CuboidGeometry(
            Vector3(layout.roadWidth, 0.08, segment.length + 0.4),
          ),
          UnlitMaterial()..baseColorFactor = segment.isGap ? _gap : _road,
        ),
      );
      // Pavements with a kerb step on both sides, and a dashed centre
      // line: the street section that makes a slab read as a road.
      for (final side in [-1.0, 1.0]) {
        roadNode
          ..add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(side * (layout.roadWidth / 2 - 1.5), 0.05, 0),
              ),
              mesh: Mesh(
                CuboidGeometry(Vector3(3, 0.1, segment.length + 0.4)),
                UnlitMaterial()..baseColorFactor = _pavement,
              ),
            ),
          )
          ..add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(side * (layout.roadWidth / 2 - 3), 0.06, 0),
              ),
              mesh: Mesh(
                CuboidGeometry(Vector3(0.12, 0.12, segment.length + 0.4)),
                UnlitMaterial()..baseColorFactor = _kerb,
              ),
            ),
          );
      }
      if (!segment.isGap) {
        for (
          var along = -segment.length / 2 + 3;
          along < segment.length / 2 - 2;
          along += 6
        ) {
          roadNode.add(
            Node(
              localTransform: Matrix4.translation(Vector3(0, 0.045, along)),
              mesh: Mesh(
                CuboidGeometry(Vector3(0.18, 0.01, 2.2)),
                UnlitMaterial()..baseColorFactor = _centreLine,
              ),
            ),
          );
        }
      }
      _addGrain(roadNode, layout.roadWidth, segment.length + 0.4, 0.045);
      scene.add(roadNode);
      if (!segment.isGap) {
        const along = 9.0;
        final anchor = Node(
          localTransform:
              Matrix4.translation(
                  Vector3(
                    segment.startX + math.sin(segment.headingRadians) * along,
                    0.06,
                    segment.startZ + math.cos(segment.headingRadians) * along,
                  ),
                )
                ..rotateY(segment.headingRadians + math.pi)
                ..rotateX(-math.pi / 2),
        );
        scene.add(anchor);
        markerAnchors[segment.bucketIndex] = anchor;
      }
    }

    final plaza = world.plaza;
    if (plaza != null) {
      final slab = Node(
        localTransform: Matrix4.translation(
          Vector3(plaza.centerX, 0.01, plaza.centerZ),
        )..rotateY(plaza.headingRadians),
        mesh: Mesh(
          CuboidGeometry(Vector3(plaza.width, 0.1, plaza.depth)),
          UnlitMaterial()..baseColorFactor = _plaza,
        ),
      );
      _addGrain(slab, plaza.width, plaza.depth, 0.06);
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

    for (final (i, slot) in world.billboardSlots.indexed) {
      if (i >= world.billboards.length) break;
      _buildBillboard(slot, world.billboards[i]);
    }
    for (final (i, slot) in world.roofBillboards.indexed) {
      _buildBillboard(slot, world.roofBillboardTasks[i]);
    }
    _buildFillerBlocks();
    _buildStreetFurniture();
  }

  /// Lamp posts, the gantry over the street mouth, the jumbotron tower,
  /// banner anchors and spires: the set dressing that makes a street a
  /// place.
  void _buildStreetFurniture() {
    for (final (x, z) in world.lampPosts) {
      final pole = Node(
        localTransform: Matrix4.translation(Vector3(x, 2.6, z)),
        mesh: Mesh(
          CuboidGeometry(Vector3(0.16, 5.2, 0.16)),
          UnlitMaterial()..baseColorFactor = _post,
        ),
      );
      // Housing: a small dark head the bulb hangs under.
      final lantern = Node(
        localTransform: Matrix4.translation(Vector3(0, 2.45, 0)),
      );
      pole
        ..add(
          Node(
            localTransform: Matrix4.translation(Vector3(0, 2.7, 0)),
            mesh: Mesh(
              CuboidGeometry(Vector3(0.7, 0.28, 0.7)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        )
        ..add(lantern);
      lampAnchors.add(lantern);
      scene.add(pole);
      _addPool(
        Vector3(x, 0, z),
        radius: 3,
        color: const Color(0xFFFFE2B8),
        alpha: 0.2,
      );
    }

    for (final (bucket, x, z, facing) in world.weekSigns) {
      final post = Node(
        localTransform: Matrix4.translation(Vector3(x, 1.6, z)),
        mesh: Mesh(
          CuboidGeometry(Vector3(0.12, 3.2, 0.12)),
          UnlitMaterial()..baseColorFactor = _post,
        ),
      );
      scene.add(post);
      final anchor = Node(
        localTransform: Matrix4.translation(Vector3(x, 3, z))..rotateY(facing),
      );
      scene.add(anchor);
      weekSignAnchors[bucket] = anchor;
    }

    final gantry = world.gantry;
    if (gantry != null) {
      final root = Node(
        localTransform: Matrix4.translation(Vector3(gantry.x, 0, gantry.z))
          ..rotateY(gantry.facingRadians),
      );
      final top = gantry.bottom + gantry.height + 0.4;
      for (final side in [-1.0, 1.0]) {
        root.add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(side * gantry.width / 2, top / 2, 0),
            ),
            mesh: Mesh(
              CuboidGeometry(Vector3(0.5, top, 0.5)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        );
      }
      root
        ..add(
          Node(
            localTransform: Matrix4.translation(Vector3(0, top - 0.2, 0)),
            mesh: Mesh(
              CuboidGeometry(Vector3(gantry.width + 0.5, 0.4, 0.5)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        )
        ..add(
          _glowQuad(gantry.width + 2, gantry.height + 2.5, PlazaStyle.teal, 0.2)
            ..localTransform = Matrix4.translation(
              Vector3(0, gantry.bottom + gantry.height / 2, -0.3),
            ),
        );
      scene.add(root);
      _addPool(
        Vector3(gantry.x, 0, gantry.z),
        radius: gantry.width * 0.4,
        color: PlazaStyle.teal,
        alpha: 0.06,
      );
    }

    final jumbotron = world.jumbotron;
    if (jumbotron != null) {
      final root = Node(
        localTransform: Matrix4.translation(
          Vector3(jumbotron.x, 0, jumbotron.z),
        )..rotateY(jumbotron.facingRadians),
      );
      final towerH = jumbotron.bottom + jumbotron.height + 14;
      root.add(
        Node(
          localTransform: Matrix4.translation(Vector3(0, towerH / 2, -3.5)),
          mesh: Mesh(
            CuboidGeometry(Vector3(jumbotron.width + 4, towerH, 6)),
            UnlitMaterial()..baseColorFactor = _tower,
          ),
        ),
      );
      final backing = Node(
        localTransform: Matrix4.translation(
          Vector3(0, jumbotron.centerY, -0.2),
        ),
        mesh: Mesh(
          CuboidGeometry(
            Vector3(jumbotron.width + 0.6, jumbotron.height + 0.6, 0.4),
          ),
          UnlitMaterial()..baseColorFactor = linearColor(PlazaStyle.teal),
        ),
      );
      root.add(backing);
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
        Vector3(jumbotron.x + jsin * 10, 0, jumbotron.z + jcos * 10),
        radius: jumbotron.width * 0.5,
        color: PlazaStyle.teal,
        alpha: 0.07,
      );
      // The tower's own spire.
      final spire = Node(
        localTransform: Matrix4.translation(Vector3(0, towerH + 5, -3.5)),
        mesh: Mesh(
          CuboidGeometry(Vector3(0.5, 10, 0.5)),
          UnlitMaterial()..baseColorFactor = _post,
        ),
      );
      root.add(spire);
      final light = Node(
        localTransform: Matrix4.translation(Vector3(0, towerH + 10.4, -3.5)),
      );
      root.add(light);
      spireAnchors.add(light);
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
      final root = Node(
        localTransform: Matrix4.translation(
          Vector3(p.x, p.height + 4, p.z),
        ),
        mesh: Mesh(
          CuboidGeometry(Vector3(0.4, 8, 0.4)),
          UnlitMaterial()..baseColorFactor = _post,
        ),
      );
      scene.add(root);
      final light = Node(
        localTransform: Matrix4.translation(Vector3(p.x, p.height + 8.3, p.z)),
      );
      scene.add(light);
      spireAnchors.add(light);
    }
  }

  /// Points around a panel's frame, world space, for the chase lights:
  /// evenly along the perimeter.
  List<Vector3> _frameCorners(BillboardSlot slot, {int perSide = 5}) {
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
        zenithColor: linearColor(const Color(0xFF04030A)).xyz,
        horizonColor: linearColor(const Color(0xFF6B2A5E)).xyz,
        groundColor: linearColor(const Color(0xFF120C1C)).xyz,
        sunColor: Vector3.zero(),
      ),
    );
    // Ground-hugging haze in the horizon's own colour: the street dissolves
    // into the sky instead of hitting a seam, and it thins with altitude
    // so the overview still sees the district.
    scene.fog
      ..enabled = true
      ..mode = FogMode.exponential
      ..density = 0.0055
      ..start = 8
      ..height = 0
      ..heightFalloff = 0.028
      ..maxOpacity = 0.92
      ..color = linearColor(const Color(0xFF4A2250)).xyz;
  }

  void _buildBuilding(PlazaTask task, PlotPlacement placement) {
    final attention = world.attentionOf(task);
    final w = placement.width;
    final h = placement.height;
    // Massing: plots vary in depth (hashed, never moving) and the box is
    // anchored to the street side, so the row is not a picket fence.
    final d = placement.depth * (0.78 + 0.32 * _unit(task.id, 'depth'));
    final setback = (placement.depth - d) / 2;
    final facing = placement.facingRadians;
    final normal = Vector3(math.sin(facing), 0, math.cos(facing));

    final node = Node(
      localTransform: Matrix4.translation(
        Vector3(
          placement.x + normal.x * setback,
          h / 2,
          placement.z + normal.z * setback,
        ),
      )..rotateY(facing),
      mesh: Mesh(
        CuboidGeometry(Vector3(w, h, d)),
        UnlitMaterial()
          ..baseColorFactor = linearColor(PlazaStyle.categoryWall(task)),
      ),
    );

    // Side and back walls: window grids in the state's lit ratio, tiled
    // by the wall's size; a hashed tile offset per building.
    final wallTint = linearColor(
      Color.lerp(PlazaStyle.categoryWall(task), const Color(0xFF0B0A14), 0.5)!,
    );
    final offset = _unit(task.id, 'tile') * 3;
    // A quad's face is +Z before rotation: rotateY(-π/2) turns it to -X
    // for the left wall, rotateY(π/2) to +X for the right, π for the back.
    for (final (dx, dz, yaw, width) in [
      (-w / 2 - 0.02, 0.0, -math.pi / 2, d), // left side, faces -X
      (w / 2 + 0.02, 0.0, math.pi / 2, d), // right side, faces +X
      (0.0, -d / 2 - 0.02, math.pi, w), // back, faces -Z
    ]) {
      final material = UnlitMaterial()..baseColorFactor = wallTint;
      _wallMaterials.putIfAbsent(attention.lantern, () => []).add(material);
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(dx, 0, dz))..rotateY(yaw),
          mesh: Mesh(
            tiledQuad(
              width,
              h,
              uRepeat: width / WallTextures.tileWidth,
              vRepeat: h / WallTextures.tileHeight,
              uOffset: offset,
            ),
            material,
          ),
        ),
      );
    }

    // Contact band: a dark plinth so the box sits on the ground.
    node.add(
      Node(
        localTransform: Matrix4.translation(Vector3(0, -h / 2 + 0.35, 0)),
        mesh: Mesh(
          CuboidGeometry(Vector3(w + 0.1, 0.7, d + 0.1)),
          UnlitMaterial()
            ..baseColorFactor = linearColor(const Color(0xFF0A0910)),
        ),
      ),
    );

    // Tall buildings step back to an upper storey with its own roof.
    if (h >= 14) {
      final upperH = h * 0.22;
      node.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(0, h / 2 + upperH / 2, -d * 0.12),
          ),
          mesh: Mesh(
            CuboidGeometry(Vector3(w * 0.68, upperH, d * 0.7)),
            UnlitMaterial()
              ..baseColorFactor = linearColor(PlazaStyle.categoryRoof(task)),
          ),
        ),
      );
    }

    final facadeW = w * 0.92;
    final facadeH = h * 0.9;

    // Far-tier surface: an always-present dark plate; the lantern carries
    // the state colour, the plate only says "there is a facade here".
    final plate = Node(
      localTransform: Matrix4.translation(Vector3(0, 0, d / 2 + 0.02)),
      mesh: Mesh(
        CuboidGeometry(Vector3(facadeW, facadeH, 0.02)),
        UnlitMaterial()..baseColorFactor = _panelBack,
      ),
    );
    // Roof: a darker slab so the top reads apart from the walls.
    node
      ..add(
        Node(
          localTransform: Matrix4.translation(Vector3(0, h / 2 + 0.02, 0)),
          mesh: Mesh(
            CuboidGeometry(Vector3(w + 0.04, 0.04, d + 0.04)),
            UnlitMaterial()
              ..baseColorFactor = linearColor(
                Color.lerp(
                  PlazaStyle.categoryRoof(task),
                  const Color(0xFF07060D),
                  0.5,
                )!,
              ),
          ),
        ),
      )
      ..add(plate);

    // Progress light bar along the base, visible at every tier.
    final pct = task.state == PlazaTaskState.done
        ? 1.0
        : task.checklistItems > 0
        ? task.progress
        : task.state == PlazaTaskState.inProgress
        ? 0.35
        : 0.0;
    if (pct > 0) {
      node.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(
              -facadeW / 2 + facadeW * pct / 2,
              -facadeH / 2 + 0.15,
              d / 2 + 0.05,
            ),
          ),
          mesh: Mesh(
            CuboidGeometry(Vector3(facadeW * pct, 0.3, 0.02)),
            UnlitMaterial()
              ..baseColorFactor = linearColor(PlazaStyle.lightBar(attention)),
          ),
        ),
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
    final neonColor = Color.lerp(
      const Color(0xFF0B0A14),
      PlazaStyle.neon(PlazaStyle.categoryBright(task)),
      emissive,
    )!;
    final neon = UnlitMaterial()..baseColorFactor = linearColor(neonColor);
    const strip = 0.2;
    for (final (dx, dy, sw, sh) in [
      (-facadeW / 2 - 0.12, 0.0, strip, facadeH),
      (facadeW / 2 + 0.12, 0.0, strip, facadeH),
      (0.0, facadeH / 2 + 0.12, facadeW + 0.4, strip),
    ]) {
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(dx, dy, d / 2 + 0.04)),
          mesh: Mesh(CuboidGeometry(Vector3(sw, sh, strip)), neon),
        ),
      );
      if (emissive > 0.3) {
        node.add(
          _glowQuad(
              sw + 1.1,
              sh + 1.1,
              PlazaStyle.neon(PlazaStyle.categoryBright(task)),
              0.16 * emissive,
            )
            ..localTransform = Matrix4.translation(
              Vector3(dx, dy, d / 2 + 0.03),
            ),
        );
      }
    }
    // Roof outline: the top edge lit dimly on all four sides so height
    // reads from above.
    final roofTrim = UnlitMaterial()
      ..baseColorFactor = linearColor(
        Color.lerp(const Color(0xFF0B0A14), neonColor, 0.55)!,
      );
    for (final (dx, dz, sw, sd) in [
      (0.0, d / 2, w + 0.2, 0.14),
      (0.0, -d / 2, w + 0.2, 0.14),
      (w / 2, 0.0, 0.14, d + 0.2),
      (-w / 2, 0.0, 0.14, d + 0.2),
    ]) {
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(dx, h / 2 + 0.08, dz)),
          mesh: Mesh(CuboidGeometry(Vector3(sw, 0.14, sd)), roofTrim),
        ),
      );
    }
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
      localTransform: Matrix4.translation(Vector3(0, 0, d / 2 + 0.06)),
    )..visible = false;
    final ringMaterial = UnlitMaterial()
      ..baseColorFactor = linearColor(PlazaStyle.teal);
    const t = 0.12;
    const off = 0.25;
    for (final (dx, dy, sw, sh) in [
      (0.0, facadeH / 2 + off, facadeW + 2 * off + t, t),
      (0.0, -facadeH / 2 - off, facadeW + 2 * off + t, t),
      (-facadeW / 2 - off, 0.0, t, facadeH + 2 * off),
      (facadeW / 2 + off, 0.0, t, facadeH + 2 * off),
    ]) {
      ring.add(
        Node(
          localTransform: Matrix4.translation(Vector3(dx, dy, 0)),
          mesh: Mesh(CuboidGeometry(Vector3(sw, sh, t)), ringMaterial),
        ),
      );
    }
    node.add(ring);

    // Anchor for the live/sign widget surface, in front of the plate.
    final facadeAnchor = Node(
      localTransform: Matrix4.translation(Vector3(0, 0, d / 2 + 0.09)),
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
      lanternAnchor: lanternAnchor,
      facadeCenter: Vector3(
        placement.x + normal.x * (d / 2),
        h / 2,
        placement.z + normal.z * (d / 2),
      ),
      facadeNormal: normal,
      facadeWorldWidth: facadeW,
      facadeWorldHeight: facadeH,
      pxPerMeter: pxPerMeter,
    );
    buildings.add(building);
    pickableBuildings[plate] = building;
  }

  void _buildEmptyLot(PlotPlacement placement) {
    // Fenced empty lot: foundations visible, street never closes up.
    scene.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(placement.x, 0.25, placement.z),
        )..rotateY(placement.facingRadians),
        mesh: Mesh(
          CuboidGeometry(Vector3(placement.width, 0.5, placement.depth)),
          UnlitMaterial()
            ..baseColorFactor = linearColor(const Color(0xFF14161C)),
        ),
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
        root.add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(side * slot.width * 0.4, slot.bottom - 0.25, -0.3),
            ),
            mesh: Mesh(
              CuboidGeometry(Vector3(0.25, 0.5, 0.25)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        );
      }
    }
    if (slot.onPylon) {
      // Heavy steel: two braced posts on footings, a catwalk under the
      // panel.
      for (final side in [-1.0, 1.0]) {
        root
          ..add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(side * slot.width * 0.4, slot.bottom / 2, -0.6),
              ),
              mesh: Mesh(
                CuboidGeometry(Vector3(0.6, slot.bottom, 0.6)),
                UnlitMaterial()..baseColorFactor = _post,
              ),
            ),
          )
          ..add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(side * slot.width * 0.4, 0.3, -0.6),
              ),
              mesh: Mesh(
                CuboidGeometry(Vector3(1.6, 0.6, 1.6)),
                UnlitMaterial()..baseColorFactor = _post,
              ),
            ),
          );
      }
      root
        ..add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(0, slot.bottom * 0.55, -0.6),
            ),
            mesh: Mesh(
              CuboidGeometry(Vector3(slot.width * 0.8, 0.25, 0.25)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        )
        ..add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(0, slot.bottom - 0.3, 0.5),
            ),
            mesh: Mesh(
              CuboidGeometry(Vector3(slot.width + 0.8, 0.12, 1.2)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        );
      // Light pool on the ground in the state colour.
      final sinF = math.sin(slot.facingRadians);
      final cosF = math.cos(slot.facingRadians);
      _addPool(
        Vector3(slot.x + sinF * 4, 0, slot.z + cosF * 4),
        radius: math.max(slot.width, 8) * 0.8,
        color: frame,
        alpha: 0.26,
      );
    }
    // Backing box: a real lightbox with depth, dark body and a rim in the
    // state colour at its front edge, so the billboard reads from the
    // skyline before its widget surface exists and the chase lights have a
    // bezel to sit on.
    final depth = slot.mount == BillboardMount.roof ? 0.4 : 0.7;
    final backing = Node(
      localTransform: Matrix4.translation(
        Vector3(0, slot.centerY, -depth / 2 - 0.02),
      ),
      mesh: Mesh(
        CuboidGeometry(Vector3(slot.width + 0.5, slot.height + 0.5, depth)),
        UnlitMaterial()..baseColorFactor = _tower,
      ),
    );
    // Faux bloom: a wide soft glow behind the lightbox.
    root
      ..add(backing)
      ..add(
        _glowQuad(slot.width + 3, slot.height + 3, frame, 0.3)
          ..localTransform = Matrix4.translation(
            Vector3(0, slot.centerY, -depth - 0.06),
          ),
      );
    final rimMaterial = UnlitMaterial()..baseColorFactor = linearColor(frame);
    const rim = 0.16;
    for (final (dx, dy, sw, sh) in [
      (0.0, slot.height / 2 + 0.18, slot.width + 0.5, rim),
      (0.0, -slot.height / 2 - 0.18, slot.width + 0.5, rim),
      (-slot.width / 2 - 0.18, 0.0, rim, slot.height + 0.5),
      (slot.width / 2 + 0.18, 0.0, rim, slot.height + 0.5),
    ]) {
      root.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(dx, slot.centerY + dy, 0.02),
          ),
          mesh: Mesh(CuboidGeometry(Vector3(sw, sh, rim)), rimMaterial),
        ),
      );
    }
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

  /// A soft glow quad behind an emitter: the faux bloom that makes neon
  /// and lightboxes read as lit rather than painted.
  Node _glowQuad(double width, double height, Color color, double alpha) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend;
    _pools.add((material, alpha));
    return Node(mesh: Mesh(ccwQuad(width, height), material));
  }

  /// Seeded roof clutter: a parapet lip, one or two plant boxes, a water
  /// tank on some, an antenna mast on a third. Hashed from the task id so
  /// it never changes under the user's feet.
  void _addRoofKit(Node node, PlazaTask task, double w, double h, double d) {
    final dark = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF14121E));
    final top = h / 2;
    // Parapet lip.
    for (final (dx, dz, sw, sd) in [
      (0.0, d / 2 - 0.15, w, 0.3),
      (0.0, -d / 2 + 0.15, w, 0.3),
      (w / 2 - 0.15, 0.0, 0.3, d),
      (-w / 2 + 0.15, 0.0, 0.3, d),
    ]) {
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(dx, top + 0.25, dz)),
          mesh: Mesh(CuboidGeometry(Vector3(sw, 0.5, sd)), dark),
        ),
      );
    }
    final plantCount = 1 + (_unit(task.id, 'plant') < 0.5 ? 1 : 0);
    for (var i = 0; i < plantCount; i++) {
      final bw = math.min(w * 0.3, 2.4);
      final bd = math.min<double>(d * 0.3, 2);
      final bx = (_unit(task.id, 'px$i') - 0.5) * (w - bw - 1);
      final bz = (_unit(task.id, 'pz$i') - 0.5) * (d - bd - 1);
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(bx, top + 0.7, bz)),
          mesh: Mesh(CuboidGeometry(Vector3(bw, 1.4, bd)), dark),
        ),
      );
    }
    if (_unit(task.id, 'tank') < 0.4 && w > 5) {
      final tx = (_unit(task.id, 'tx') - 0.5) * (w - 3);
      final tz = (_unit(task.id, 'tz') - 0.5) * (d - 3);
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
    if (_unit(task.id, 'mast') < 0.33) {
      final mx = (_unit(task.id, 'mx') - 0.5) * (w - 1);
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(mx, top + 2.2, 0)),
          mesh: Mesh(CuboidGeometry(Vector3(0.12, 4.4, 0.12)), dark),
        ),
      );
    }
  }

  /// City fabric behind the plots: a second row of dark windowed blocks
  /// with alleys between them, so the street has a back and the overview
  /// has texture between the plots and the skyline. Seeded per bucket.
  void _buildFillerBlocks() {
    final lateralBase = layout.roadWidth / 2 + layout.plotDepth + 4;
    for (final segment in plan.segments) {
      if (segment.isGap) continue;
      final sinH = math.sin(segment.headingRadians);
      final cosH = math.cos(segment.headingRadians);
      for (final side in [-1.0, 1.0]) {
        var along = 2.0;
        var i = 0;
        while (along < segment.length - 4) {
          final id = 'filler-${segment.bucketIndex}-$side-$i';
          final bw = 7 + _unit(id, 'w') * 9;
          if (along + bw > segment.length - 1) break;
          final bd = 8 + _unit(id, 'd') * 8;
          final bh = 6 + _unit(id, 'h') * 16;
          final lateral = side * (lateralBase + bd / 2 + _unit(id, 'l') * 4);
          final cx = segment.startX + sinH * (along + bw / 2) + cosH * lateral;
          final cz = segment.startZ + cosH * (along + bw / 2) - sinH * lateral;
          final node = Node(
            localTransform: Matrix4.translation(Vector3(cx, bh / 2, cz))
              ..rotateY(segment.headingRadians),
            mesh: Mesh(
              CuboidGeometry(Vector3(bw, bh, bd)),
              UnlitMaterial()..baseColorFactor = _tower,
            ),
          );
          // One windowed face toward the street.
          final material = UnlitMaterial()..baseColorFactor = _tower;
          _wallMaterials.putIfAbsent(LanternState.off, () => []).add(material);
          node.add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(0, 0, -side * (bd / 2 + 0.02)),
              )..rotateY(side < 0 ? 0 : math.pi),
              mesh: Mesh(
                tiledQuad(
                  bw,
                  bh,
                  uRepeat: bw / WallTextures.tileWidth,
                  vRepeat: bh / WallTextures.tileHeight,
                  uOffset: _unit(id, 'tile') * 3,
                ),
                material,
              ),
            ),
          );
          if (_unit(id, 'sign') < 0.34) {
            // A neon sign down the street-facing corner, named after one
            // of the week's own tasks' category.
            final weekTasks =
                plan.placements.values
                    .where((p) => p.bucketIndex == segment.bucketIndex)
                    .map((p) => p.taskId)
                    .toList()
                  ..sort();
            if (weekTasks.isNotEmpty) {
              final pick = (_unit(id, 'pick') * weekTasks.length).floor().clamp(
                0,
                weekTasks.length - 1,
              );
              final anchor = Node(
                localTransform: Matrix4.translation(
                  Vector3(-bw / 2 + 1.2, bh * 0.15, -side * (bd / 2 + 0.08)),
                )..rotateY(side < 0 ? 0 : math.pi),
              );
              node.add(anchor);
              fillerSigns.add((anchor, 1.6, bh * 0.6, weekTasks[pick]));
            }
          }
          scene.add(node);
          along += bw + 2 + _unit(id, 'gap') * 4;
          i++;
        }
      }
    }
  }

  /// A ring of dark towers around the district so the street dissolves
  /// into a city instead of a black table. Seeded, never data.
  void _buildSkyline(Vector3 center) {
    final plaza = world.plaza;
    var radius = 0.0;
    for (final p in plan.placements.values) {
      final dx = p.x - center.x;
      final dz = p.z - center.z;
      radius = math.max(radius, math.sqrt(dx * dx + dz * dz));
    }
    if (plaza != null) {
      final dx = plaza.centerX - center.x;
      final dz = plaza.centerZ - center.z;
      radius = math.max(radius, math.sqrt(dx * dx + dz * dz) + 60);
    }
    radius += 95;
    const towers = 48;
    for (var i = 0; i < towers; i++) {
      final id = 'skyline-$i';
      final angle = i / towers * 2 * math.pi + _unit(id, 'a') * 0.1;
      final r = radius + _unit(id, 'r') * 90;
      final w = 16 + _unit(id, 'w') * 26;
      final h = 18 + _unit(id, 'h') * 46;
      final x = center.x + math.cos(angle) * r;
      final z = center.z + math.sin(angle) * r;
      final node = Node(
        localTransform: Matrix4.translation(Vector3(x, h / 2, z))
          ..rotateY(-angle),
        mesh: Mesh(
          CuboidGeometry(Vector3(w, h, w * 0.8)),
          UnlitMaterial()..baseColorFactor = _tower,
        ),
      );
      // Every fourth tower carries a big screen on its district-facing
      // face: the hi-rises behind Times Square are where the screens are.
      if (i % 4 == 1 && world.anomalies.isNotEmpty) {
        final sw = w * 0.82;
        final sh = sw * 0.5;
        final sy = h * 0.55;
        final rank = (i ~/ 4) % world.anomalies.length;
        final frame = PlazaStyle.lantern(world.anomalies[rank].lantern);
        node
          ..add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(0, sy - h / 2, w * 0.4 + 0.3),
              ),
              mesh: Mesh(
                CuboidGeometry(Vector3(sw + 0.8, sh + 0.8, 0.6)),
                UnlitMaterial()..baseColorFactor = linearColor(frame),
              ),
            ),
          )
          ..add(
            _glowQuad(sw + 6, sh + 6, frame, 0.25)
              ..localTransform = Matrix4.translation(
                Vector3(0, sy - h / 2, w * 0.4 + 0.2),
              ),
          );
        final anchor = Node(
          localTransform: Matrix4.translation(
            Vector3(0, sy - h / 2, w * 0.4 + 0.66),
          ),
        );
        node.add(anchor);
        skylineScreens.add((anchor, sw, sh, rank));
      }
      // Two windowed faces toward the district.
      for (final (dx, dz, yaw) in [
        (0.0, w * 0.4 + 0.02, 0.0),
        (-w / 2 - 0.02, 0.0, -math.pi / 2),
      ]) {
        final material = UnlitMaterial()..baseColorFactor = _tower;
        _wallMaterials.putIfAbsent(LanternState.off, () => []).add(material);
        node.add(
          Node(
            localTransform: Matrix4.translation(Vector3(dx, 0, dz))
              ..rotateY(yaw),
            mesh: Mesh(
              tiledQuad(
                w,
                h,
                uRepeat: w / WallTextures.tileWidth,
                vRepeat: h / WallTextures.tileHeight,
                uOffset: _unit(id, 'tile') * 3,
              ),
              material,
            ),
          ),
        );
      }
      scene.add(node);
    }
  }

  Vector3 _planCenter() {
    if (plan.segments.isEmpty) return Vector3.zero();
    var sumX = 0.0;
    var sumZ = 0.0;
    for (final s in plan.segments) {
      sumX += s.startX;
      sumZ += s.startZ;
    }
    return Vector3(sumX / plan.segments.length, 0, sumZ / plan.segments.length);
  }
}
