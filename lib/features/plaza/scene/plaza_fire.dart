import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:vector_math/vector_math.dart';

/// One overdue facade or billboard's flame bed, in world metres.
class PlazaFireSource {
  PlazaFireSource({
    required this.taskId,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.facing,
    this.height = 4,
  }) : phase = stableUnit(taskId, 'fire');

  final String taskId;
  final double x;
  final double y;
  final double z;
  final double width;
  final double height;
  final double facing;
  final double phase;
  double _distanceSquared = 0;
}

/// Finished/cancelled work never burns, even when its old due date has passed.
List<PlazaFireSource> fireSourcesFor(PlazaWorld world) => [
  for (final p in world.plan.placements.values)
    if (world.attention[p.taskId]!.overdue)
      PlazaFireSource(
        taskId: p.taskId,
        x: p.x + math.sin(p.facingRadians) * p.depth / 2,
        y: p.height,
        z: p.z + math.cos(p.facingRadians) * p.depth / 2,
        width:
            p.width *
            world.layout.billboardScaleFor(world.attention[p.taskId]!.task),
        facing: p.facingRadians,
      ),
  for (final assignment in [...world.builtBillboards, ...world.roofPanels])
    if (assignment.attention.overdue)
      PlazaFireSource(
        taskId: assignment.attention.task.id,
        x: assignment.slot.x,
        y: assignment.slot.bottom + assignment.slot.height,
        z: assignment.slot.z,
        width: assignment.slot.width,
        facing: assignment.slot.facingRadians,
      ),
];

/// Fixed storage for the nearest flame beds. Ranking is throttled; animation
/// rewrites scalar instance fields without creating particles or per-frame
/// lists. Distant tasks retain their status lanterns after flames leave LOD.
class PlazaFireBuffer {
  PlazaFireBuffer({
    required List<PlazaFireSource> sources,
    required this.data,
    this.maxSources = defaultMaxSources,
    this.particlesPerSource = defaultParticlesPerSource,
    this.maxDistance = 240,
  }) : _ranked = List.of(sources),
       assert(maxSources > 0, 'source budget must be positive'),
       assert(particlesPerSource >= 2, 'bounds need two instances') {
    if (data.length < count * BillboardGeometry.floatsPerInstance) {
      throw ArgumentError('instance buffer is smaller than its flame budget');
    }
  }

  final Float32List data;
  static const defaultMaxSources = 96;
  static const defaultParticlesPerSource = 8;
  final int maxSources;
  final int particlesPerSource;
  final double maxDistance;
  final List<PlazaFireSource> _ranked;
  double? _rankedAt;
  final Vector4 _warm = linearColor(
    dsTokensDark.colors.alert.warning.defaultColor,
  );
  final Vector4 _hot = linearColor(dsTokensDark.colors.alert.warning.pressed);

  int get count => math.min(maxSources, _ranked.length) * particlesPerSource;

  /// Reserves conservative bounds for every possible source once. Later
  /// nearest-source changes never require a geometry bounds refit.
  void reserveBounds(void Function(int) commit) {
    if (_ranked.isEmpty) {
      commit(0);
      return;
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final source in _ranked) {
      final pad = source.width + source.height * 2;
      minX = math.min(minX, source.x - pad);
      minY = math.min(minY, source.y - pad);
      minZ = math.min(minZ, source.z - pad);
      maxX = math.max(maxX, source.x + pad);
      maxY = math.max(maxY, source.y + pad);
      maxZ = math.max(maxZ, source.z + pad);
    }
    const stride = BillboardGeometry.floatsPerInstance;
    data[0] = minX;
    data[1] = minY;
    data[2] = minZ;
    data[stride] = maxX;
    data[stride + 1] = maxY;
    data[stride + 2] = maxZ;
    try {
      commit(count);
    } finally {
      data.fillRange(0, data.length, 0);
    }
  }

  void update(double seconds, Vector3 eye) {
    if (_rankedAt == null || seconds - _rankedAt! >= 0.25) {
      for (final source in _ranked) {
        final dx = source.x - eye.x;
        final dy = source.y - eye.y;
        final dz = source.z - eye.z;
        source._distanceSquared = dx * dx + dy * dy + dz * dz;
      }
      _ranked.sort(_nearestFirst);
      _rankedAt = seconds;
    }
    const stride = BillboardGeometry.floatsPerInstance;
    final distanceSquared = maxDistance * maxDistance;
    for (var i = 0; i < math.min(maxSources, _ranked.length); i++) {
      final source = _ranked[i];
      final visible = source._distanceSquared <= distanceSquared;
      final sinF = math.sin(source.facing);
      final cosF = math.cos(source.facing);
      for (var j = 0; j < particlesPerSource; j++) {
        final offset = (i * particlesPerSource + j) * stride;
        final age = (seconds / 1.4 + source.phase + j / particlesPerSource) % 1;
        final flicker = math.sin(seconds * 5 + j * 2 + source.phase);
        final along =
            source.width * ((j + 0.5) / particlesPerSource - 0.5) +
            flicker * 0.2;
        data[offset] = source.x + along * cosF;
        data[offset + 1] = source.y + age * source.height;
        data[offset + 2] = source.z - along * sinF;
        data[offset + 3] =
            source.width / particlesPerSource * (1.3 + flicker * 0.2);
        data[offset + 4] = source.height * (1 - age * 0.5);
        data[offset + 6] = _warm.x + (_hot.x - _warm.x) * (1 - age);
        data[offset + 7] = _warm.y + (_hot.y - _warm.y) * (1 - age);
        data[offset + 8] = _warm.z + (_hot.z - _warm.z) * (1 - age);
        data[offset + 9] = visible ? math.sin(math.pi * age) : 0;
      }
    }
  }

  static int _nearestFirst(PlazaFireSource a, PlazaFireSource b) =>
      a._distanceSquared.compareTo(b._distanceSquared);
}

/// One instanced draw for overdue flames, sharing a single procedural texture.
class PlazaFire {
  PlazaFire({required Scene scene, required PlazaWorld world}) {
    final sources = fireSourcesFor(world);
    if (sources.isEmpty) return;
    final capacity =
        math.min(PlazaFireBuffer.defaultMaxSources, sources.length) *
        PlazaFireBuffer.defaultParticlesPerSource;
    final geometry = BillboardGeometry(capacity: capacity)
      ..facing = BillboardFacing.axisLocked;
    final material = SpriteMaterial();
    _material = material;
    _buffer = PlazaFireBuffer(sources: sources, data: geometry.instanceData)
      ..reserveBounds(geometry.commit);
    scene.add(Node(mesh: Mesh(geometry, material))..raycastable = false);
  }

  PlazaFireBuffer? _buffer;
  SpriteMaterial? _material;

  void update(double seconds, Vector3 eye) => _buffer?.update(seconds, eye);

  /// Tapered curling tongues, rather than circular particles. The texture is
  /// generated once; all motion and fading happens in the instance buffer.
  Future<void> loadTexture() async {
    final material = _material;
    if (material == null) return;
    const size = 64;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(size.toDouble());
    final path = ui.Path()
      ..moveTo(0.5, 1)
      ..cubicTo(0.03, 1, 0.05, 0.65, 0.26, 0.45)
      ..cubicTo(0.2, 0.68, 0.4, 0.48, 0.49, 0.02)
      ..cubicTo(0.8, 0.32, 0.65, 0.45, 0.82, 0.56)
      ..cubicTo(1, 0.85, 0.8, 1, 0.5, 1)
      ..close();
    final white = dsTokensDark.colors.text.highEmphasis;
    canvas.drawPath(
      path,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          const ui.Offset(0, 1),
          ui.Offset.zero,
          [white, white.withValues(alpha: 0)],
        ),
    );
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
