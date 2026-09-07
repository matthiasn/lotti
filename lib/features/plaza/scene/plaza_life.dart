import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:vector_math/vector_math.dart';

/// Small penguins follow safe lanes inside existing streets. Their paths and
/// phases are seeded once; no physics, task writes or per-frame particles.
class PlazaLifeBuffer {
  PlazaLifeBuffer({
    required StreetPlan plan,
    required double roadWidth,
    required int taskCount,
    required this.data,
    int maxCreatures = 24,
    this.speed = 1.8,
    this.visibleDistance = 100,
  }) {
    final roads = plan.segments.where((segment) => !segment.isGap).toList();
    final count = roads.isEmpty || taskCount == 0
        ? 0
        : math.min(maxCreatures, math.max(1, taskCount ~/ 3));
    if (count < 0 ||
        data.length < count * BillboardGeometry.floatsPerInstance) {
      throw ArgumentError('invalid creature budget or instance storage');
    }
    for (var i = 0; i < count; i++) {
      final road = roads[i * roads.length ~/ count];
      final lateral = roadWidth * (i.isEven ? 0.25 : -0.25);
      final start = frameToWorld(
        road.startX,
        road.startZ,
        road.headingRadians,
        lateral,
        2,
      );
      final end = frameToWorld(
        road.startX,
        road.startZ,
        road.headingRadians,
        lateral,
        math.max(2, road.length - 2),
      );
      _paths.add((
        start: start,
        end: end,
        length: math.max(1, road.length - 4),
        phase: stableUnit('$i', 'penguin'),
      ));
    }
  }

  final Float32List data;
  final double speed;
  final double visibleDistance;
  final List<
    ({
      (double, double) start,
      (double, double) end,
      double length,
      double phase,
    })
  >
  _paths = [];
  int get count => _paths.length;

  /// Whole-route bounds are fixed even while individual penguins move.
  void reserveBounds(void Function(Vector3 min, Vector3 max) setBounds) {
    if (_paths.isEmpty) return;
    var minX = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final path in _paths) {
      for (final point in [path.start, path.end]) {
        minX = math.min(minX, point.$1);
        minZ = math.min(minZ, point.$2);
        maxX = math.max(maxX, point.$1);
        maxZ = math.max(maxZ, point.$2);
      }
    }
    setBounds(Vector3(minX - 1, 0, minZ - 1), Vector3(maxX + 1, 2, maxZ + 1));
  }

  void update(double seconds, Vector3 eye) {
    const stride = BillboardGeometry.floatsPerInstance;
    final limit = visibleDistance * visibleDistance;
    for (var i = 0; i < _paths.length; i++) {
      final path = _paths[i];
      final phase = (seconds * speed / (2 * path.length) + path.phase) % 1;
      final along = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      final x = path.start.$1 + (path.end.$1 - path.start.$1) * along;
      final z = path.start.$2 + (path.end.$2 - path.start.$2) * along;
      final dx = eye.x - x;
      final dz = eye.z - z;
      final o = i * stride;
      data[o] = x;
      data[o + 1] = 0.75 + math.sin(seconds * 10 + path.phase).abs() * 0.06;
      data[o + 2] = z;
      data[o + 3] = 0.8;
      data[o + 4] = 1.2;
      data[o + 5] = math.sin(seconds * 5 + path.phase) * 0.08;
      data[o + 6] = 1;
      data[o + 7] = 1;
      data[o + 8] = 1;
      data[o + 9] = dx * dx + eye.y * eye.y + dz * dz <= limit ? 1 : 0;
    }
  }
}

/// One bounded instanced draw, with a shared procedural penguin texture.
class PlazaLife {
  PlazaLife({required Scene scene, required PlazaWorld world}) {
    if (world.tasks.isEmpty || world.ambientCreatures <= 0) return;
    final geometry = BillboardGeometry(capacity: world.ambientCreatures)
      ..facing = BillboardFacing.axisLocked;
    _buffer = PlazaLifeBuffer(
      plan: world.plan,
      roadWidth: world.layout.roadWidth,
      taskCount: world.tasks.length,
      data: geometry.instanceData,
      maxCreatures: world.ambientCreatures,
    );
    geometry.commit(_buffer!.count);
    _buffer!.reserveBounds(
      (min, max) => geometry.setLocalBounds(
        Aabb3.minMax(min, max),
        Sphere.centerRadius((min + max) * 0.5, min.distanceTo(max) * 0.5),
      ),
    );
    _material = SpriteMaterial();
    scene.add(Node(mesh: Mesh(geometry, _material!))..raycastable = false);
  }

  PlazaLifeBuffer? _buffer;
  SpriteMaterial? _material;
  void update(double seconds, Vector3 eye) => _buffer?.update(seconds, eye);

  Future<void> loadTexture() async {
    final material = _material;
    if (material == null) return;
    const size = 64;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(size.toDouble());
    final tokens = dsTokensDark.colors;
    final body = ui.Paint()..color = tokens.background.level01;
    final belly = ui.Paint()..color = tokens.text.highEmphasis;
    final feet = ui.Paint()..color = tokens.alert.warning.defaultColor;
    canvas
      ..drawOval(const ui.Rect.fromLTWH(0.18, 0.02, 0.64, 0.90), body)
      ..drawOval(const ui.Rect.fromLTWH(0.01, 0.36, 0.25, 0.43), body)
      ..drawOval(const ui.Rect.fromLTWH(0.74, 0.36, 0.25, 0.43), body)
      ..drawOval(const ui.Rect.fromLTWH(0.26, 0.38, 0.48, 0.45), belly)
      ..drawOval(const ui.Rect.fromLTWH(0.18, 0.86, 0.30, 0.12), feet)
      ..drawOval(const ui.Rect.fromLTWH(0.52, 0.86, 0.30, 0.12), feet)
      ..drawCircle(const ui.Offset(0.38, 0.24), 0.055, belly)
      ..drawCircle(const ui.Offset(0.62, 0.24), 0.055, belly)
      ..drawCircle(const ui.Offset(0.39, 0.25), 0.025, body)
      ..drawCircle(const ui.Offset(0.61, 0.25), 0.025, body)
      ..drawOval(const ui.Rect.fromLTWH(0.43, 0.29, 0.14, 0.10), feet);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(size, size);
      try {
        material.colorTexture = await Texture2D.fromImage(image);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}
