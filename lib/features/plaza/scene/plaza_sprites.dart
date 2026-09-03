import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// The screen-space layer of the skyline: roof lanterns and beacon dots.
///
/// Both are camera-facing sprites whose world size is recomputed every
/// frame from their distance, so a lantern never shrinks below a few pixels
/// from the overview pose and a beacon reads the same from across the
/// district as from up close. Anomalous lanterns and attention beacons
/// pulse on a fixed cycle.
class PlazaSprites {
  PlazaSprites({
    required this.scene,
    required this.world,
    required List<PlazaBuilding> buildings,
    List<Node> lampAnchors = const [],
    List<Node> spireAnchors = const [],
    Map<PlazaBillboard, List<Vector3>> chaseLightPoints = const {},
  }) {
    for (final anchor in lampAnchors) {
      final sprite = Sprite(color: linearColor(PlazaStyle.lamp));
      anchor.add(Node(mesh: sprite.mesh)..raycastable = false);
      _lamps.add(sprite);
    }
    for (final anchor in spireAnchors) {
      final sprite = Sprite(color: linearColor(PlazaStyle.warning));
      anchor.add(Node(mesh: sprite.mesh)..raycastable = false);
      _spireLights.add(sprite);
    }
    for (final entry in chaseLightPoints.entries) {
      final color = linearColor(
        PlazaStyle.lantern(entry.key.attention.lantern),
      );
      final run = <_ChaseLight>[];
      for (final point in entry.value) {
        final sprite = Sprite(color: color);
        scene.add(
          Node(localTransform: Matrix4.translation(point), mesh: sprite.mesh)
            ..raycastable = false,
        );
        run.add(_ChaseLight(sprite: sprite, position: point, color: color));
      }
      _chases.add(
        _Chase(
          lights: run,
          periodSeconds: entry.key.slot.pulseSeconds.clamp(1.2, 4.0),
        ),
      );
    }
    for (final building in buildings) {
      final color = PlazaStyle.lantern(building.attention.lantern);
      final sprite = Sprite(color: linearColor(color));
      final node = Node(mesh: sprite.mesh)..raycastable = false;
      building.lanternAnchor.add(node);
      _lanterns.add(
        _Lantern(
          sprite: sprite,
          node: node,
          worldPosition: Vector3(
            building.placement.x,
            building.placement.height + 0.7,
            building.placement.z,
          ),
          color: linearColor(color),
          pulses: building.attention.anomalous,
          lit: building.attention.lantern != LanternState.off,
        ),
      );
    }
    for (final beacon in world.beacons) {
      final teal = linearColor(PlazaStyle.teal);
      final dot = Sprite(color: teal);
      final dotNode = Node(
        localTransform: Matrix4.translation(
          Vector3(beacon.markerX, beacon.markerY, beacon.markerZ),
        ),
        mesh: dot.mesh,
      )..raycastable = false;
      scene.add(dotNode);
      Sprite? ring;
      Node? ringNode;
      if (beacon.kind == BeaconKind.attention) {
        ring = Sprite(color: Vector4(teal.x, teal.y, teal.z, 0.8));
        ringNode = Node(
          localTransform: Matrix4.translation(
            Vector3(beacon.markerX, beacon.markerY, beacon.markerZ),
          ),
          mesh: ring.mesh,
        )..raycastable = false;
        scene.add(ringNode);
      }
      _beacons.add(
        _BeaconSprite(
          beacon: beacon,
          dot: dot,
          dotNode: dotNode,
          ring: ring,
          ringNode: ringNode,
        ),
      );
    }
  }

  final Scene scene;
  final PlazaWorld world;
  final List<_Lantern> _lanterns = [];
  final List<_BeaconSprite> _beacons = [];
  final List<Sprite> _lamps = [];
  final List<Sprite> _spireLights = [];
  final List<_Chase> _chases = [];

  /// Glow texture shared by every sprite; a square dot until it loads.
  Texture2D? _glow;

  /// Paints a soft radial glow and uploads it once.
  Future<void> loadGlow() async {
    const size = 64;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..shader = ui.Gradient.radial(
        const ui.Offset(size / 2, size / 2),
        size / 2,
        const [
          ui.Color(0xFFFFFFFF),
          ui.Color(0xFFFFFFFF),
          ui.Color(0x80FFFFFF),
          ui.Color(0x00FFFFFF),
        ],
        const [0, 0.28, 0.5, 1],
      );
    canvas.drawCircle(const ui.Offset(size / 2, size / 2), size / 2, paint);
    final image = await recorder.endRecording().toImage(size, size);
    _glow = await Texture2D.fromImage(image);
    for (final l in _lanterns) {
      l.sprite.material.colorTexture = _glow;
    }
    for (final b in _beacons) {
      b.dot.material.colorTexture = _glow;
      b.ring?.material.colorTexture = _glow;
    }
    for (final l in _lamps) {
      l.material.colorTexture = _glow;
    }
    for (final l in _spireLights) {
      l.material.colorTexture = _glow;
    }
    for (final c in _chases) {
      for (final l in c.lights) {
        l.sprite.material.colorTexture = _glow;
      }
    }
  }

  /// Screen-space sizes of the dots, logical pixels.
  static const lanternMinPx = 5.0;
  static const lanternMaxPx = 22.0;
  static const lanternNominalPx = 9.0;
  static const beaconPx = 13.0;

  /// Per-frame update: sizes from distance, pulses from [elapsedSeconds].
  void update(Camera camera, ui.Size viewSize, double elapsedSeconds) {
    final eye = camera.position;
    final fov = switch (camera.projection) {
      final PerspectiveProjection p => p.fovRadiansY,
      _ => math.pi / 3,
    };
    // World metres per logical pixel at distance d.
    final metersPerPxAtUnit = 2 * math.tan(fov / 2) / viewSize.height;

    final lanternPulse =
        0.35 + 0.65 * (0.5 + 0.5 * math.sin(elapsedSeconds * 2 * math.pi / 3));
    for (final l in _lanterns) {
      final d = (l.worldPosition - eye).length;
      final px = (lanternNominalPx * 60 / math.max(d, 1)).clamp(
        lanternMinPx,
        lanternMaxPx,
      );
      final size = px * d * metersPerPxAtUnit * (l.lit ? 2.2 : 1.2);
      l.sprite
        ..width = size
        ..height = size;
      if (l.pulses) {
        l.sprite.color = Vector4(
          l.color.x,
          l.color.y,
          l.color.z,
          lanternPulse,
        );
      }
    }

    // Lamps: a fixed warm glow that reads at every range.
    for (final l in _lamps) {
      l
        ..width = 1.6
        ..height = 1.6;
    }
    // Spire lights blink: on for a third of a 1.6 s cycle.
    final blink = (elapsedSeconds % 1.6) < 0.55 ? 1.0 : 0.12;
    for (final l in _spireLights) {
      l
        ..width = 2.4
        ..height = 2.4
        ..color = Vector4(l.color.x, l.color.y, l.color.z, blink);
    }
    // Chase lights run round each billboard frame: a bright head with a
    // fading tail, faster for the more agitated panels.
    for (final chase in _chases) {
      final n = chase.lights.length;
      if (n == 0) continue;
      final head = (elapsedSeconds / chase.periodSeconds * n) % n;
      for (final (i, light) in chase.lights.indexed) {
        final behind = (head - i + n) % n;
        final alpha = behind < 3 ? 1 - behind * 0.28 : 0.18;
        light.sprite
          ..width = 0.7
          ..height = 0.7
          ..color = Vector4(light.color.x, light.color.y, light.color.z, alpha);
      }
    }

    final ringPhase = (elapsedSeconds % 2.2) / 2.2;
    for (final b in _beacons) {
      final pos = Vector3(b.beacon.markerX, b.beacon.markerY, b.beacon.markerZ);
      final dx = pos.x - eye.x;
      final dz = pos.z - eye.z;
      final ground = math.sqrt(dx * dx + dz * dz);
      final range = b.beacon.visibleRange;
      final visible = ground <= range;
      b.dotNode.visible = visible;
      b.ringNode?.visible = visible;
      if (!visible) continue;
      final d = (pos - eye).length;
      final size = beaconPx * d * metersPerPxAtUnit * 2.0;
      final alpha = ground > range * 0.7 ? 0.45 : 0.9;
      b.dot
        ..width = size
        ..height = size
        ..color = Vector4(b.dot.color.x, b.dot.color.y, b.dot.color.z, alpha);
      final ring = b.ring;
      if (ring != null) {
        final scale = 0.5 + 1.9 * ringPhase;
        ring
          ..width = size * scale
          ..height = size * scale
          ..color = Vector4(
            ring.color.x,
            ring.color.y,
            ring.color.z,
            0.8 * (1 - ringPhase),
          );
      }
    }
  }

  /// Beacons currently visible with their screen positions, for picking.
  Iterable<(Beacon, ui.Offset)> visibleBeaconScreenPositions(
    Camera camera,
    ui.Size viewSize,
  ) sync* {
    for (final b in _beacons) {
      if (!b.dotNode.visible) continue;
      final screen = camera.worldToScreen(
        Vector3(b.beacon.markerX, b.beacon.markerY, b.beacon.markerZ),
        viewSize,
      );
      if (screen != null) yield (b.beacon, screen);
    }
  }
}

class _Lantern {
  _Lantern({
    required this.sprite,
    required this.node,
    required this.worldPosition,
    required this.color,
    required this.pulses,
    required this.lit,
  });

  final Sprite sprite;
  final Node node;
  final Vector3 worldPosition;
  final Vector4 color;
  final bool pulses;
  final bool lit;
}

class _BeaconSprite {
  _BeaconSprite({
    required this.beacon,
    required this.dot,
    required this.dotNode,
    required this.ring,
    required this.ringNode,
  });

  final Beacon beacon;
  final Sprite dot;
  final Node dotNode;
  final Sprite? ring;
  final Node? ringNode;
}

class _ChaseLight {
  _ChaseLight({
    required this.sprite,
    required this.position,
    required this.color,
  });

  final Sprite sprite;
  final Vector3 position;
  final Vector4 color;
}

class _Chase {
  _Chase({required this.lights, required this.periodSeconds});

  final List<_ChaseLight> lights;
  final double periodSeconds;
}
