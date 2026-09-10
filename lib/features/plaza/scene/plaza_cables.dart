import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/cable_path.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:lotti/features/plaza/scene/plaza_static_meshes.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:vector_math/vector_math.dart';

/// A continuous, six-sided tube swept along the sampled cable. Its triangles
/// face outwards, with vertices relative to [origin]; no camera-facing ribbons
/// or per-frame geometry are needed.
MeshData cableTubeMesh(
  CablePath path,
  double radius, {
  required Vector3 origin,
}) {
  const sides = 6;
  final count = path.distances.length;
  final positions = Float32List(count * sides * 3);
  final indices = <int>[];
  final source = path.positions;
  // Every span follows the same horizontal line. Keep its section vertical:
  // rotating rings with the tangent folds faces at a sharp support crest.
  final tangent = Vector3(
    source[source.length - 3] - source[0],
    0,
    source.last - source[2],
  );
  if (tangent.length2 == 0) tangent.y = 1;
  tangent.normalize();
  final normal = Vector3(-tangent.z, 0, tangent.x);
  if (normal.length2 == 0) normal.x = 1;
  normal.normalize();
  final binormal = tangent.cross(normal)..normalize();
  for (var i = 0; i < count; i++) {
    for (var side = 0; side < sides; side++) {
      final angle = side * math.pi * 2 / sides;
      final u = math.cos(angle) * radius;
      final v = math.sin(angle) * radius;
      final offset = (i * sides + side) * 3;
      for (var axis = 0; axis < 3; axis++) {
        positions[offset + axis] =
            source[i * 3 + axis] -
            origin[axis] +
            normal[axis] * u +
            binormal[axis] * v;
      }
      if (i + 1 < count) {
        final a = i * sides + side;
        final b = i * sides + (side + 1) % sides;
        indices.addAll([a, b, a + sides, b, b + sides, a + sides]);
      }
    }
  }
  return MeshData.build(positions: positions, indices: indices);
}

Geometry _uploadCableMesh(MeshData mesh) => MeshGeometry.fromMeshData(mesh);

/// Places the tube at its arc midpoint so static batching assigns it to the
/// cable's actual spatial cell. Keeping vertices local preserves world geometry
/// while preventing disconnected districts from merging at the scene origin.
Node cableTubeNode(
  CablePath path,
  double radius,
  UnlitMaterial material, {
  Geometry Function(MeshData) upload = _uploadCableMesh,
}) {
  final origin = Vector3.zero();
  path.writePosition(path.length / 2, origin.storage, 0);
  return Node(
      mesh: Mesh(upload(cableTubeMesh(path, radius, origin: origin)), material),
    )
    ..position = origin
    ..raycastable = false;
}

/// A single mast carries every attachment height at the same roof position.
/// Sharing it prevents a highly connected task from becoming a forest of poles.
List<CableSupport> cableSupportsFor(Iterable<CablePath> paths) {
  final supports = <(double, double, double), CableSupport>{};
  for (final path in paths) {
    for (final support in path.supports) {
      final key = (support.x, support.z, support.baseY);
      final existing = supports[key];
      if (existing == null || support.y > existing.y) supports[key] = support;
    }
  }
  return List.unmodifiable(supports.values);
}

/// Bounded light packets, ranked by selected-task incidence then camera
/// distance. Directional edges flow from source to destination; basic links
/// have opposing packets so they never imply a dependency.
class PlazaCableBuffer {
  PlazaCableBuffer({
    required List<CablePath> paths,
    required this.data,
    this.maxCables = 96,
    this.speed = 12,
    this.maxDistance = 600,
  }) : _ranked = [for (final path in paths) _CableLightSource(path)],
       assert(maxCables >= 0, 'light budget cannot be negative'),
       assert(speed > 0, 'packet speed must be positive') {
    if (data.length < count * BillboardGeometry.floatsPerInstance) {
      throw ArgumentError('instance buffer is smaller than its cable budget');
    }
  }

  final Float32List data;
  final int maxCables;
  final double speed;
  final double maxDistance;
  final List<_CableLightSource> _ranked;
  final Vector4 _white = emissiveColor(
    dsTokensDark.colors.text.highEmphasis,
    1.6,
  );
  final Vector4 _focus = emissiveColor(PlazaStyle.teal, 1.6);
  String? _focusedTask;
  double? _rankedAt;
  double? _lastSeconds;
  double _motionSeconds = 0;
  bool hasVisibleMotion = false;

  int get count => math.min(maxCables, _ranked.length) * 2;

  /// Commits conservative bounds once for all possible ranked packets.
  void reserveBounds(void Function(int) commit) {
    if (count == 0) {
      commit(0);
      return;
    }
    final min = Vector3.all(double.infinity);
    final max = Vector3.all(double.negativeInfinity);
    for (final source in _ranked) {
      final points = source.path.positions;
      for (var i = 0; i < points.length; i += 3) {
        for (var axis = 0; axis < 3; axis++) {
          min[axis] = math.min(min[axis], points[i + axis] - 4);
          max[axis] = math.max(max[axis], points[i + axis] + 4);
        }
      }
    }
    for (var axis = 0; axis < 3; axis++) {
      data[axis] = min[axis];
      data[BillboardGeometry.floatsPerInstance + axis] = max[axis];
    }
    try {
      commit(count);
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  void update(
    double seconds,
    Vector3 eye, {
    String? focusedTask,
    bool animate = true,
  }) {
    if (animate && _lastSeconds != null) {
      _motionSeconds += math.max(0, seconds - _lastSeconds!);
    }
    _lastSeconds = seconds;
    if (_rankedAt == null ||
        seconds - _rankedAt! >= 0.25 ||
        _focusedTask != focusedTask) {
      for (final source in _ranked) {
        final points = source.path.positions;
        final mid = (points.length ~/ 6) * 3;
        final dx = points[mid] - eye.x;
        final dy = points[mid + 1] - eye.y;
        final dz = points[mid + 2] - eye.z;
        source.distanceSquared = dx * dx + dy * dy + dz * dz;
        source.focused =
            focusedTask != null &&
            source.path.connection.otherId(focusedTask) != null;
      }
      _ranked.sort(_nearestFirst);
      _rankedAt = seconds;
      _focusedTask = focusedTask;
    }
    hasVisibleMotion = false;
    for (var i = 0; i < count ~/ 2; i++) {
      final source = _ranked[i];
      final path = source.path;
      final visible =
          path.length > 0 &&
          source.distanceSquared <= maxDistance * maxDistance;
      if (visible && animate) hasVisibleMotion = true;
      final color = source.focused ? _focus : _white;
      for (var packet = 0; packet < 2; packet++) {
        final offset = (i * 2 + packet) * BillboardGeometry.floatsPerInstance;
        var fraction =
            (source.phase +
                packet / 2 +
                _motionSeconds * speed / math.max(path.length, 1)) %
            1;
        if (!path.connection.isDirected && packet == 1) fraction = 1 - fraction;
        path.writePosition(fraction * path.length, data, offset);
        data[offset + 3] = source.focused ? 3 : 2;
        data[offset + 4] = data[offset + 3];
        data[offset + 6] = color.x;
        data[offset + 7] = color.y;
        data[offset + 8] = color.z;
        data[offset + 9] = visible ? color.w : 0;
      }
    }
  }

  static int _nearestFirst(_CableLightSource a, _CableLightSource b) {
    if (a.focused != b.focused) return a.focused ? -1 : 1;
    final distance = a.distanceSquared.compareTo(b.distanceSquared);
    return distance == 0
        ? a.path.connection.id.compareTo(b.path.connection.id)
        : distance;
  }
}

class _CableLightSource {
  _CableLightSource(this.path)
    : phase = stableUnit(path.connection.id, 'light');
  final CablePath path;
  final double phase;
  double distanceSquared = 0;
  bool focused = false;
}

/// Allocates highlight geometry only when its connection is first selected.
/// Repeated focus changes reuse cached overlays; clearing focus hides them.
class PlazaCableSelection {
  PlazaCableSelection({
    required this.paths,
    required this.root,
    required this.create,
  });

  final List<CablePath> paths;
  final Node root;
  final Node Function(CablePath) create;
  final Map<CablePath, Node> _nodes = {};
  String? _focusedTask;

  void update(String? focusedTask) {
    if (_focusedTask == focusedTask) return;
    _focusedTask = focusedTask;
    for (final entry in _nodes.entries) {
      entry.value.visible =
          focusedTask != null &&
          entry.key.connection.otherId(focusedTask) != null;
    }
    if (focusedTask == null) return;
    for (final path in paths) {
      if (path.length == 0 || path.connection.otherId(focusedTask) == null) {
        continue;
      }
      if (!_nodes.containsKey(path)) {
        final node = create(path);
        _nodes[path] = node;
        root.add(node);
      }
    }
  }
}

/// Roof-mounted suspension cables. Static tubes, lamp collars and supports are
/// baked once; selection overlays are created on first use and reused. All
/// travelling packets use one instanced draw.
class PlazaCables {
  PlazaCables({
    required Scene scene,
    required PlazaWorld world,
    required TextureSource glowTexture,
    PlazaPalette palette = PlazaPalette.night,
  }) {
    // Cables read as dark catenaries against either sky; only how far
    // their travelling lights are pushed past white changes with the hour.
    final boost = palette.lights.emissiveBoost;
    scene.add(root);
    final stationary = Node()..raycastable = false;
    root.add(stationary);
    final body = UnlitMaterial()
      ..baseColorFactor = linearColor(palette.surfaces.cable);
    final lit = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        dsTokensDark.colors.text.highEmphasis,
        boost,
      );
    final selected = UnlitMaterial()
      ..baseColorFactor = emissiveColor(PlazaStyle.teal, boost);
    _selection = PlazaCableSelection(
      paths: world.cablePaths,
      root: root,
      create: (path) =>
          cableTubeNode(path, world.cables.radius * 1.7, selected),
    );
    final cube = CuboidGeometry(Vector3.all(1));
    final point = Float64List(3);
    for (final path in world.cablePaths) {
      if (path.length == 0) continue;
      stationary.add(cableTubeNode(path, world.cables.radius, body));
      final lamps = math.min(24, math.max(2, (path.length / 12).ceil()));
      for (var i = 1; i < lamps; i++) {
        path.writePosition(path.length * i / lamps, point, 0);
        stationary.add(
          Node(mesh: Mesh(cube, lit))
            ..position = Vector3(point[0], point[1], point[2])
            ..scale = Vector3.all(world.cables.radius * 2)
            ..raycastable = false,
        );
      }
    }
    for (final support in cableSupportsFor(world.cablePaths)) {
      final height = support.y - support.baseY;
      stationary
        ..add(
          Node(mesh: Mesh(cube, body))
            ..position = Vector3(
              support.x,
              support.baseY + height / 2,
              support.z,
            )
            ..scale = Vector3(
              world.cables.radius * 2,
              height,
              world.cables.radius * 2,
            )
            ..raycastable = false,
        )
        ..add(
          Node(mesh: Mesh(cube, lit))
            ..position = Vector3(support.x, support.y, support.z)
            ..scale = Vector3.all(world.cables.radius * 3)
            ..raycastable = false,
        );
    }
    final batches = PlazaStaticMeshes(
      cellSize: world.layout.groupLength * 2,
    ).bake(stationary, preserve: const {});
    meshCount = batches.meshes;
    batchCount = batches.batches;
    final capacity =
        math.min(world.cables.maxAnimatedCables, world.cablePaths.length) * 2;
    if (capacity == 0) return;
    final geometry = BillboardGeometry(capacity: capacity);
    final material = SpriteMaterial(colorTexture: glowTexture)
      ..blendMode = SpriteBlendMode.additive;
    _buffer = PlazaCableBuffer(
      paths: world.cablePaths,
      data: geometry.instanceData,
      maxCables: world.cables.maxAnimatedCables,
    )..reserveBounds(geometry.commit);
    root.add(Node(mesh: Mesh(geometry, material))..raycastable = false);
  }

  final Node root = Node()..raycastable = false;
  late final PlazaCableSelection _selection;
  PlazaCableBuffer? _buffer;
  int meshCount = 0;
  int batchCount = 0;

  bool get hasVisibleMotion =>
      root.visible && (_buffer?.hasVisibleMotion ?? false);

  void update(
    double seconds,
    Vector3 eye, {
    String? focusedTask,
    bool animate = true,
  }) {
    _selection.update(focusedTask);
    _buffer?.update(
      seconds,
      eye,
      focusedTask: focusedTask,
      animate: animate && root.visible,
    );
  }
}
