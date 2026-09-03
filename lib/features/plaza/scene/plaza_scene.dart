import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Size;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
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

  static final Vector4 _ground = linearColor(const Color(0xFF20242E));
  static final Vector4 _road = linearColor(const Color(0xFF3F4450));
  static final Vector4 _gap = linearColor(const Color(0xFF32363F));
  static final Vector4 _plaza = linearColor(const Color(0xFF474D5D));
  static final Vector4 _post = linearColor(const Color(0xFF14171F));
  static final Vector4 _tower = linearColor(const Color(0xFF0E0B18));

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

    for (final segment in plan.segments) {
      final midAlong = segment.length / 2;
      final mid = Vector3(
        segment.startX + math.sin(segment.headingRadians) * midAlong,
        0,
        segment.startZ + math.cos(segment.headingRadians) * midAlong,
      );
      scene.add(
        Node(
          localTransform: Matrix4.translation(mid)
            ..rotateY(segment.headingRadians),
          mesh: Mesh(
            CuboidGeometry(
              Vector3(layout.roadWidth, 0.08, segment.length + 0.4),
            ),
            UnlitMaterial()..baseColorFactor = segment.isGap ? _gap : _road,
          ),
        ),
      );
      if (!segment.isGap) {
        const along = 4.0;
        final anchor = Node(
          localTransform:
              Matrix4.translation(
                  Vector3(
                    segment.startX + math.sin(segment.headingRadians) * along,
                    0.06,
                    segment.startZ + math.cos(segment.headingRadians) * along,
                  ),
                )
                ..rotateY(segment.headingRadians)
                ..rotateX(-math.pi / 2),
        );
        scene.add(anchor);
        markerAnchors[segment.bucketIndex] = anchor;
      }
    }

    final plaza = world.plaza;
    if (plaza != null) {
      scene.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(plaza.centerX, 0.01, plaza.centerZ),
          )..rotateY(plaza.headingRadians),
          mesh: Mesh(
            CuboidGeometry(Vector3(plaza.width, 0.1, plaza.depth)),
            UnlitMaterial()..baseColorFactor = _plaza,
          ),
        ),
      );
      // Home marker ring on the ground.
      scene.add(
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
          CuboidGeometry(Vector3(0.18, 5.2, 0.18)),
          UnlitMaterial()..baseColorFactor = _post,
        ),
      );
      final lantern = Node(
        localTransform: Matrix4.translation(Vector3(0, 2.75, 0)),
      );
      pole.add(lantern);
      lampAnchors.add(lantern);
      scene
        ..add(pole)
        ..add(
          Node(
            localTransform: Matrix4.translation(Vector3(x, 0.02, z)),
            mesh: Mesh(
              DiscGeometry(radius: 3.2, segments: 24),
              UnlitMaterial()
                ..baseColorFactor = linearColor(PlazaStyle.lamp, alpha: 0.12)
                ..alphaMode = AlphaMode.blend,
            ),
          ),
        );
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
      root.add(
        Node(
          localTransform: Matrix4.translation(Vector3(0, top - 0.2, 0)),
          mesh: Mesh(
            CuboidGeometry(Vector3(gantry.width + 0.5, 0.4, 0.5)),
            UnlitMaterial()..baseColorFactor = _post,
          ),
        ),
      );
      scene.add(root);
    }

    final jumbotron = world.jumbotron;
    if (jumbotron != null) {
      final root = Node(
        localTransform: Matrix4.translation(
          Vector3(jumbotron.x, 0, jumbotron.z),
        )..rotateY(jumbotron.facingRadians),
      );
      final towerH = jumbotron.bottom + jumbotron.height + 6;
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
    final hw = slot.width / 2 + 0.35;
    final hh = slot.height / 2 + 0.35;
    Vector3 at(double u, double v) => Vector3(
      slot.x + cosF * u + sinF * 0.12,
      slot.centerY + v,
      slot.z - sinF * u + cosF * 0.12,
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
    // Haze: close enough to soften the far rows, not to swallow the
    // overview.
    scene.fog
      ..enabled = true
      ..mode = FogMode.linear
      ..start = 60
      ..end = 700
      ..maxOpacity = 0.8
      ..color = linearColor(const Color(0xFF3A1F4A)).xyz;
  }

  void _buildBuilding(PlazaTask task, PlotPlacement placement) {
    final attention = world.attentionOf(task);
    final w = placement.width;
    final h = placement.height;
    final d = placement.depth;

    final node = Node(
      localTransform: Matrix4.translation(
        Vector3(placement.x, h / 2, placement.z),
      )..rotateY(placement.facingRadians),
      mesh: Mesh(
        CuboidGeometry(Vector3(w, h, d)),
        UnlitMaterial()
          ..baseColorFactor = linearColor(PlazaStyle.categoryWall(task)),
      ),
    );

    final facadeW = w * 0.92;
    final facadeH = h * 0.9;
    final facing = placement.facingRadians;
    final normal = Vector3(math.sin(facing), 0, math.cos(facing));

    // Far-tier surface: an always-present dark plate; the lantern carries
    // the state colour, the plate only says "there is a facade here".
    final plate = Node(
      localTransform: Matrix4.translation(Vector3(0, 0, d / 2 + 0.02)),
      mesh: Mesh(
        CuboidGeometry(Vector3(facadeW, facadeH, 0.02)),
        UnlitMaterial()..baseColorFactor = _panelBack,
      ),
    );
    // Roof: a thin darker slab so the top reads apart from the walls.
    node
      ..add(
        Node(
          localTransform: Matrix4.translation(Vector3(0, h / 2 + 0.02, 0)),
          mesh: Mesh(
            CuboidGeometry(Vector3(w + 0.04, 0.04, d + 0.04)),
            UnlitMaterial()
              ..baseColorFactor = linearColor(PlazaStyle.categoryRoof(task)),
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
    final neon = UnlitMaterial()
      ..baseColorFactor = linearColor(
        PlazaStyle.neon(PlazaStyle.categoryBright(task)),
        alpha: attention.lantern == LanternState.off ? 0.35 : 1,
      )
      ..alphaMode = attention.lantern == LanternState.off
          ? AlphaMode.blend
          : AlphaMode.opaque;
    const strip = 0.14;
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
    }
    // Light pool on the street in front of a lit facade: the wet-street
    // reflection, without a reflection.
    if (attention.lantern != LanternState.off) {
      scene.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(
              placement.x + normal.x * (d / 2 + facadeW * 0.3),
              0.025,
              placement.z + normal.z * (d / 2 + facadeW * 0.3),
            ),
          ),
          mesh: Mesh(
            DiscGeometry(radius: facadeW * 0.55, segments: 28),
            UnlitMaterial()
              ..baseColorFactor = linearColor(
                PlazaStyle.lantern(attention.lantern),
                alpha: 0.13,
              )
              ..alphaMode = AlphaMode.blend,
          ),
        ),
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
      for (final side in [-1.0, 1.0]) {
        root.add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(side * slot.width * 0.5, slot.bottom / 2, -0.2),
            ),
            mesh: Mesh(
              CuboidGeometry(Vector3(0.4, slot.bottom, 0.4)),
              UnlitMaterial()..baseColorFactor = _post,
            ),
          ),
        );
      }
      // Light pool on the ground in the state colour.
      root.add(
        Node(
          localTransform: Matrix4.translation(Vector3(0, 0.03, 4)),
          mesh: Mesh(
            DiscGeometry(radius: math.max(slot.width, 8) * 0.8, segments: 48),
            UnlitMaterial()
              ..baseColorFactor = linearColor(frame, alpha: 0.22)
              ..alphaMode = AlphaMode.blend,
          ),
        ),
      );
    }
    // Backing box: the panel body, with a rim in the state colour so the
    // billboard reads from the skyline before its widget surface exists.
    final backing = Node(
      localTransform: Matrix4.translation(Vector3(0, slot.centerY, -0.15)),
      mesh: Mesh(
        CuboidGeometry(Vector3(slot.width + 0.3, slot.height + 0.3, 0.3)),
        UnlitMaterial()..baseColorFactor = linearColor(frame),
      ),
    );
    root.add(backing);
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
