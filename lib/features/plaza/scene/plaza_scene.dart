import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/scenery.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_boxes.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:lotti/features/plaza/scene/plaza_scene_records.dart';
import 'package:lotti/features/plaza/scene/plaza_static_meshes.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/wall_textures.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

part 'plaza_walls.dart';
part 'plaza_ground.dart';
part 'plaza_furniture.dart';
part 'plaza_buildings.dart';
part 'plaza_billboards.dart';
part 'plaza_lights.dart';
part 'plaza_skyline.dart';

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
  final PlazaSceneBindings bindings = PlazaSceneBindings();
  late final _boxes = PlazaBoxes(
    cube: CuboidGeometry(Vector3.all(1)),
    shadedCube: shadedCuboid(Vector3.all(1)),
  );

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

  /// Side and back wall materials waiting for their window texture, by
  /// lantern state.
  final Map<(LanternState, int), List<UnlitMaterial>> _wallMaterials = {};

  /// Light pools: (material, full alpha). Their alpha fades with camera
  /// altitude so the overview is carried by lanterns, not discs.
  final List<(UnlitMaterial, double)> _pools = [];

  /// Ground surfaces that take the asphalt grain.
  final List<UnlitMaterial> _grainMaterials = [];
  final List<UnlitMaterial> _pavingMaterials = [];
  final Map<(LanternState, int), List<UnlitMaterial>> _shopfrontMaterials = {};

  /// Consolidates static opaque fixtures after sibling layers are attached.
  /// Dynamic visibility groups and pick targets retain their node identities.
  ({int meshes, int batches}) bakeStaticMeshes() =>
      PlazaStaticMeshes(
        cellSize: layout.groupLength * 2,
      ).bake(
        scene.root,
        preserveMaterials: {
          for (final billboard in bindings.billboards) ?billboard.back,
        },
        localGroups: [
          for (final building in bindings.buildings) ...[
            building.ring,
            building.neon,
          ],
          ...bindings.pickableBuildings.keys,
          ...bindings.pickableBillboards.keys,
        ],
        preserve: {
          ...bindings.pickableBuildings.keys,
          ...bindings.pickableBillboards.keys,
          ...bindings.markerAnchors.values,
          ..._mapRibbons,
          for (final building in bindings.buildings) ...[
            building.ring,
            building.neon,
            building.facadeAnchor,
            building.lanternAnchor,
          ],
          for (final billboard in bindings.billboards) billboard.anchor,
          ...bindings.lampAnchors,
          ...bindings.spireAnchors,
        },
      );

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
  bool? _mapVisible;

  /// What is left of a pool's alpha at the camera's height: 1 at eye
  /// level, [poolFloor] above [poolFadeTop]. The billboards' bloom fades
  /// by it too.
  double get poolFade => 1 - (1 - poolFloor) * (_lastFadeT ?? 0);

  /// Shows the map layer once [eye] is above [poolFadeStart], and fades
  /// the fog, pools and washes with its height.
  void updateForCamera(Vector3 eye) {
    // Road week markers are for the map: at street level the kerb sign
    // owns the week, and a label under your feet reads backwards.
    final mapVisible = eye.y >= poolFadeStart;
    if (mapVisible != _mapVisible) {
      _mapVisible = mapVisible;
      for (final anchor in bindings.markerAnchors.values) {
        anchor.visible = mapVisible;
      }
      for (final ribbon in _mapRibbons) {
        ribbon.visible = mapVisible;
      }
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

  /// Height of the shopfront band at the foot of every wall.
  static const shopfrontHeight = 4.0;

  /// A building at least this tall carries its screen above a street-level
  /// parade on the street face; a shorter one is all sign.
  static const paradeWallHeight = 12.0;

  /// The cornice band: the wall's own dark, a shade above the night.
  static final _corniceMaterial = UnlitMaterial()
    ..baseColorFactor = linearColor(const Color(0xFF141220));

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

  /// A soft glow quad behind an emitter: the faux bloom that makes neon
  /// and lightboxes read as lit rather than painted.
  /// Depth biases, world metres toward the eye, for the layers on a
  /// facade: the plate over the window wall, the neon glows and the focus
  /// ring over the plate; the widget surface (`widgetDepthBias`) over all.
  static const plateDepthBias = 0.05;
  static const glowDepthBias = 0.1;
}
