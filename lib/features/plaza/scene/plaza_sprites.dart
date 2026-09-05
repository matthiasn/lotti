import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:lotti/features/plaza/scene/plaza_scene_records.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// The screen-space layer of the skyline: roof lanterns and beacon dots.
///
/// Both are camera-facing sprites whose world size is recomputed every
/// frame from their distance, so a lantern never shrinks below a few pixels
/// from the overview pose and a beacon reads the same from across the
/// district as from up close. Anomalous lanterns and attention beacons
/// pulse on a fixed cycle. Lanterns, beacons and halos retain separate
/// sprites for depth sorting; the non-overlapping chase bulbs on each
/// billboard share one instanced draw with fixed bounds.
class PlazaSprites {
  PlazaSprites({
    required this.scene,
    required this.world,
    required PlazaSceneBindings bindings,
  }) {
    for (final anchor in bindings.lampAnchors) {
      final bulb = Sprite(
        color: linearColor(PlazaStyle.lamp),
        width: lampBulbSize,
        height: lampBulbSize,
      );
      final halo = Sprite(
        color: linearColor(PlazaStyle.lamp, alpha: 0.35),
        width: lampHaloSize,
        height: lampHaloSize,
      );
      anchor
        ..add(Node(mesh: bulb.mesh)..raycastable = false)
        ..add(Node(mesh: halo.mesh)..raycastable = false);
      // A lamp post never moves: its world position is read once, here,
      // so the anchor must already stand in its final pose.
      _lamps.add(
        _Lamp(
          bulb: bulb,
          halo: halo,
          worldPosition: anchor.globalTransform.getTranslation(),
        ),
      );
    }
    for (final anchor in bindings.spireAnchors) {
      final sprite = Sprite(
        color: linearColor(PlazaStyle.warning),
        width: spireLightSize,
        height: spireLightSize,
      );
      anchor.add(Node(mesh: sprite.mesh)..raycastable = false);
      _spireLights.add(sprite);
    }
    for (final entry in bindings.chaseLightPoints.entries) {
      // Warm-white bulbs read against any bezel colour; the tail goes
      // near-black so the chase is a chase.
      final color = linearColor(const Color(0xFFFFF1C8));
      final points = entry.value;
      if (points.isEmpty) continue;
      final geometry = BillboardGeometry(capacity: points.length);
      final material = SpriteMaterial();
      final instances = PlazaLightBuffer(geometry.instanceData);
      for (final point in points) {
        instances.add(point, size: 0.3, color: color);
      }
      instances.commitBounds(geometry.commit, pad: maxChaseBulbSize);
      scene.add(Node(mesh: Mesh(geometry, material))..raycastable = false);
      _chases.add(
        _Chase(
          instances: instances,
          material: material,
          color: color,
          periodSeconds: entry.key.slot.pulseSeconds.clamp(1.2, 4.0),
        ),
      );
    }
    for (final building in bindings.buildings) {
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
      final teal = linearColor(PlazaStyle.beaconColor(beacon, world));
      final position = Vector3(beacon.markerX, beacon.markerY, beacon.markerZ);
      final dot = Sprite(color: teal);
      final dotNode = Node(
        localTransform: Matrix4.translation(position),
        mesh: dot.mesh,
      )..raycastable = false;
      scene.add(dotNode);
      Sprite? ring;
      Node? ringNode;
      if (beacon.kind == BeaconKind.attention) {
        ring = Sprite(color: Vector4(teal.x, teal.y, teal.z, 0.8));
        ringNode = Node(
          localTransform: Matrix4.translation(position),
          mesh: ring.mesh,
        )..raycastable = false;
        scene.add(ringNode);
      }
      _beacons.add(
        _BeaconSprite(
          beacon: beacon,
          worldPosition: position,
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
  final List<_Lamp> _lamps = [];
  final List<Sprite> _spireLights = [];
  final List<_Chase> _chases = [];

  /// Two light vocabularies: a hard-edged bulb for fixtures (lamps, chase
  /// lights, spire lights) and a soft halo for glows (lanterns, beacons,
  /// lamp halos). Square dots until they load.
  Texture2D? _glow;
  Texture2D? _bulb;

  static Future<Texture2D> _radial(
    List<ui.Color> colors,
    List<double> stops,
  ) async {
    const size = 64;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..shader = ui.Gradient.radial(
        const ui.Offset(size / 2, size / 2),
        size / 2,
        colors,
        stops,
      );
    canvas.drawCircle(const ui.Offset(size / 2, size / 2), size / 2, paint);
    final image = await recorder.endRecording().toImage(size, size);
    return Texture2D.fromImage(image);
  }

  /// Paints and uploads both textures once.
  Future<void> loadGlow() async {
    _glow = await _radial(
      const [
        ui.Color(0xFFFFFFFF),
        ui.Color(0xFFFFFFFF),
        ui.Color(0x80FFFFFF),
        ui.Color(0x00FFFFFF),
      ],
      const [0, 0.28, 0.5, 1],
    );
    _bulb = await _radial(
      const [
        ui.Color(0xFFFFFFFF),
        ui.Color(0xFFFFFFFF),
        ui.Color(0x33FFFFFF),
        ui.Color(0x00FFFFFF),
      ],
      const [0, 0.6, 0.72, 1],
    );
    for (final l in _lanterns) {
      l.sprite.material.colorTexture = _glow;
    }
    for (final b in _beacons) {
      b.dot.material.colorTexture = _glow;
      b.ring?.material.colorTexture = _glow;
    }
    for (final l in _lamps) {
      l.bulb.material.colorTexture = _bulb;
      l.halo.material.colorTexture = _glow;
    }
    for (final l in _spireLights) {
      l.material.colorTexture = _bulb;
    }
    for (final chase in _chases) {
      chase.material.colorTexture = _bulb;
    }
  }

  /// Screen-space sizes of the dots, logical pixels.
  static const lanternMinPx = 5.0;
  static const lanternMaxPx = 22.0;
  static const lanternNominalPx = 9.0;

  /// Beacons stay small: they steer, the lanterns carry the health read.
  static const beaconPx = 8.0;

  /// Lamp halos fade out inside this distance so they never cover a
  /// facade the walker is reading.
  static const lampHaloFadeStart = 8.0;
  static const lampHaloFadeEnd = 30.0;

  /// World sizes of the fixed dots, set once at construction.
  static const lampBulbSize = 0.5;
  static const lampHaloSize = 2.0;
  static const spireLightSize = 2.4;

  /// The largest chase bulb, also the conservative padding of its batch.
  static const maxChaseBulbSize = 0.45;

  /// Below this a size or colour change is invisible and is not written:
  /// every [Sprite] setter re-commits its quad, and at rest most frames
  /// change nothing.
  static const _epsilon = 1e-6;

  /// Sets a square sprite's [size] when it moved.
  static void _resize(Sprite sprite, double size) {
    if ((sprite.width - size).abs() <= _epsilon &&
        (sprite.height - size).abs() <= _epsilon) {
      return;
    }
    sprite
      ..width = size
      ..height = size;
  }

  /// Sets a sprite's colour when a channel moved.
  static void _tint(Sprite sprite, double r, double g, double b, double a) {
    final c = sprite.color;
    if ((c.x - r).abs() <= _epsilon &&
        (c.y - g).abs() <= _epsilon &&
        (c.z - b).abs() <= _epsilon &&
        (c.w - a).abs() <= _epsilon) {
      return;
    }
    sprite.color = Vector4(r, g, b, a);
  }

  final _view = PlazaSpriteView();

  /// Camera-dependent sizes and fades update only when the view changes;
  /// time-dependent pulses continue at the rendered frame cadence.
  void update(Camera camera, ui.Size viewSize, double elapsedSeconds) {
    final eye = camera.position;
    final fov = switch (camera.projection) {
      final PerspectiveProjection p => p.fovRadiansY,
      _ => math.pi / 3,
    };
    // World metres per logical pixel at distance d.
    final viewChanged = _view.update(eye, viewSize, fov);
    final metersPerPxAtUnit = _view.metersPerPixel;

    final lanternPulse =
        0.35 + 0.65 * (0.5 + 0.5 * math.sin(elapsedSeconds * 2 * math.pi / 3));
    for (final l in _lanterns) {
      if (viewChanged) {
        final d = eye.distanceTo(l.worldPosition);
        final px = (lanternNominalPx * 60 / math.max(d, 1)).clamp(
          lanternMinPx,
          lanternMaxPx,
        );
        final size = px * d * metersPerPxAtUnit * (l.lit ? 2.2 : 1.2);
        _resize(l.sprite, size);
      }
      if (l.pulses) {
        _tint(l.sprite, l.color.x, l.color.y, l.color.z, lanternPulse);
      }
    }

    // Lamps: a hard bulb that reads at every range (its size is fixed),
    // and a halo that fades away as the walker comes close so it never
    // sits on a facade.
    if (viewChanged) {
      for (final l in _lamps) {
        final d = eye.distanceTo(l.worldPosition);
        final haloAlpha =
            ((d - lampHaloFadeStart) / (lampHaloFadeEnd - lampHaloFadeStart))
                .clamp(0.0, 1.0) *
            0.22;
        final c = l.halo.color;
        _tint(l.halo, c.x, c.y, c.z, haloAlpha);
      }
    }
    // Spire lights blink: on for a third of a 1.6 s cycle.
    final blink = (elapsedSeconds % 1.6) < 0.55 ? 1.0 : 0.12;
    for (final l in _spireLights) {
      _tint(l, l.color.x, l.color.y, l.color.z, blink);
    }
    // Chase lights run round each billboard frame: a bright head with a
    // fading tail, faster for the more agitated panels.
    for (final chase in _chases) {
      final n = chase.instances.count;
      final head = (elapsedSeconds / chase.periodSeconds * n) % n;
      for (var i = 0; i < n; i++) {
        final behind = (head - i + n) % n;
        // A five-bulb head over a near-dark tail, so the chase reads in a
        // still frame and not only in motion; the head goes past white for
        // the bloom.
        // A marquee, not a comet: every bulb stays lit at a third so the
        // run reads as a string of lamps, and the head is capped so it
        // never floats free of the bezel.
        final alpha = behind < 5 ? 1 - behind * 0.14 : 0.3;
        final boost = behind < 2 ? 1.6 : 1.0;
        final size = behind < 1
            ? maxChaseBulbSize
            : behind < 2
            ? 0.36
            : 0.3;
        chase.instances.write(
          i,
          size: size,
          color: chase.color,
          alpha: alpha,
          boost: boost,
        );
      }
    }

    final ringPhase = (elapsedSeconds % 2.2) / 2.2;
    for (final b in _beacons) {
      if (viewChanged) {
        final pos = b.worldPosition;
        final dx = pos.x - eye.x;
        final dz = pos.z - eye.z;
        final ground = math.sqrt(dx * dx + dz * dz);
        final range = b.beacon.visibleRange;
        final visible = ground <= range;
        b.dotNode.visible = visible;
        b.ringNode?.visible = visible;
        final d = eye.distanceTo(pos);
        // Shrinks gently with distance so a row of stops reads as a sequence
        // rather than one blob at the vanishing point.
        final px = beaconPx * (1 - 0.5 * (d / range).clamp(0.0, 1.0));
        b.size = px * d * metersPerPxAtUnit * 2.0;
        final alpha = 0.9 - 0.6 * (d / range).clamp(0.0, 1.0);
        _resize(b.dot, b.size);
        _tint(b.dot, b.dot.color.x, b.dot.color.y, b.dot.color.z, alpha);
      }
      if (!b.dotNode.visible) continue;
      final ring = b.ring;
      if (ring != null) {
        final scale = 0.5 + 1.9 * ringPhase;
        _resize(ring, b.size * scale);
        _tint(
          ring,
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
      final screen = camera.worldToScreen(b.worldPosition, viewSize);
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
    required this.worldPosition,
    required this.dot,
    required this.dotNode,
    required this.ring,
    required this.ringNode,
  });

  final Beacon beacon;
  double size = 0;
  final Vector3 worldPosition;
  final Sprite dot;
  final Node dotNode;
  final Sprite? ring;
  final Node? ringNode;
}

class _Lamp {
  _Lamp({
    required this.bulb,
    required this.halo,
    required this.worldPosition,
  });

  final Sprite bulb;
  final Sprite halo;
  final Vector3 worldPosition;
}

class _Chase {
  _Chase({
    required this.instances,
    required this.material,
    required this.color,
    required this.periodSeconds,
  });

  final PlazaLightBuffer instances;
  final SpriteMaterial material;
  final Vector4 color;
  final double periodSeconds;
}

/// CPU-side instance data for a fixed group of chase bulbs. Geometry uploads
/// this buffer on each draw; changing only size and colour needs no bounds
/// refit after [commitBounds] reserves the maximum bulb size.
class PlazaLightBuffer {
  PlazaLightBuffer(this.data);

  final Float32List data;
  int _count = 0;
  int get count => _count;

  /// Adds one stationary bulb, copying its position and colour into the
  /// billboard layout. The rest of the record remains at its zero defaults.
  void add(Vector3 center, {required double size, required Vector4 color}) {
    final offset = _count * BillboardGeometry.floatsPerInstance;
    data[offset] = center.x;
    data[offset + 1] = center.y;
    data[offset + 2] = center.z;
    write(_count, size: size, color: color, alpha: color.w);
    _count++;
  }

  /// Commits bounds with each bulb at its largest [pad], then restores the
  /// display sizes even if the geometry's commit fails.
  void commitBounds(void Function(int) commit, {required double pad}) {
    const stride = BillboardGeometry.floatsPerInstance;
    final sizes = Float32List(_count * 2);
    for (var i = 0; i < _count; i++) {
      sizes[2 * i] = data[i * stride + 3];
      sizes[2 * i + 1] = data[i * stride + 4];
      data[i * stride + 3] = pad;
      data[i * stride + 4] = pad;
    }
    try {
      commit(_count);
    } finally {
      for (var i = 0; i < _count; i++) {
        data[i * stride + 3] = sizes[2 * i];
        data[i * stride + 4] = sizes[2 * i + 1];
      }
    }
  }

  /// Updates the bulb's size and linear HDR colour while retaining its
  /// centre, rotation, flipbook frame and velocity.
  void write(
    int index, {
    required double size,
    required Vector4 color,
    required double alpha,
    double boost = 1,
  }) {
    final offset = index * BillboardGeometry.floatsPerInstance;
    data[offset + 3] = size;
    data[offset + 4] = size;
    data[offset + 6] = color.x * boost;
    data[offset + 7] = color.y * boost;
    data[offset + 8] = color.z * boost;
    data[offset + 9] = alpha;
  }
}

/// Last view used for sprite sizes: owns its eye copy so mutable cameras
/// cannot silently change the cached state between frames.
class PlazaSpriteView {
  final _eye = Vector3.zero();
  ui.Size? _size;
  double? _fov;
  double metersPerPixel = 0;

  bool update(Vector3 eye, ui.Size size, double fov) {
    if (_size == size && _fov == fov && _eye == eye) return false;
    _eye.setFrom(eye);
    _size = size;
    _fov = fov;
    metersPerPixel = 2 * math.tan(fov / 2) / size.height;
    return true;
  }
}
