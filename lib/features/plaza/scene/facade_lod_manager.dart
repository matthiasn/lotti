import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// A facade quad for a [WidgetComponent], wound counter-clockwise.
///
/// flutter_scene 0.23 flipped the engine's front-face convention to CCW and
/// regenerated its primitives, but `WidgetComponent`'s built-in quad still
/// winds CW (byte-identical to 0.20), so the default surface is back-face
/// culled and widget textures never show. Same vertex data as upstream's
/// quad, triangles reversed. Drop when the upstream quad is fixed.
Geometry _facadeQuad(double width, double height) {
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

/// Surface tier of one facade (spec §9):
/// near = live interactive widget, mid = widget captured once (manual
/// policy, re-captured only on task change), far = color block only.
enum FacadeTier { far, mid, near }

/// Tuning knobs the debug overlay exposes while hunting the M0 ceiling.
class FacadeLodConfig {
  FacadeLodConfig({
    this.nearCap = 12,
    this.midCap = 60,
    this.nearDistance = 35,
    this.midDistance = 140,
    this.forceAllLive = false,
  });

  /// Hard cap on simultaneous live (every-frame) widget surfaces.
  int nearCap;

  /// Hard cap on hosted-but-static (manual-capture) widget surfaces.
  int midCap;

  double nearDistance;
  double midDistance;

  /// Stress mode: every facade becomes a live widget, caps ignored.
  /// This is the naive version whose ceiling M0 exists to find.
  bool forceAllLive;
}

/// Live counters for the debug overlay.
class FacadeLodStats {
  int near = 0;
  int mid = 0;
  int far = 0;
  int captures = 0;
  Duration lastCapture = Duration.zero;
  int promotions = 0;
}

class _FacadeSurface {
  WidgetComponent? component;
  FacadeTier tier = FacadeTier.far;
  bool captured = false;
}

/// Assigns each building facade a tier from camera distance, with sticky
/// hysteresis so surfaces don't thrash at tier boundaries, and hard caps
/// enforced by construction (evict by distance).
class FacadeLodManager {
  FacadeLodManager({required this.buildings, required this.config})
    : _surfaces = [for (final _ in buildings) _FacadeSurface()];

  final List<PlazaBuilding> buildings;
  final FacadeLodConfig config;
  final List<_FacadeSurface> _surfaces;
  final FacadeLodStats stats = FacadeLodStats();

  /// Sticky factor: a surface already at a tier ranks as if 15% closer.
  static const _hysteresis = 0.85;

  void update(Vector3 cameraPosition) {
    final n = buildings.length;
    final distances = List<double>.filled(n, 0);
    final order = List<int>.generate(n, (i) => i);
    for (var i = 0; i < n; i++) {
      final d = buildings[i].facadeCenter.distanceTo(cameraPosition);
      final tier = _surfaces[i].tier;
      distances[i] = tier == FacadeTier.far ? d : d * _hysteresis;
    }
    order.sort((a, b) => distances[a].compareTo(distances[b]));

    var nearLeft = config.forceAllLive ? n : config.nearCap;
    var midLeft = config.forceAllLive ? 0 : config.midCap;

    for (final i in order) {
      final d = distances[i];
      FacadeTier target;
      if (config.forceAllLive) {
        target = FacadeTier.near;
      } else if (nearLeft > 0 && d < config.nearDistance) {
        target = FacadeTier.near;
      } else if (midLeft > 0 && d < config.midDistance) {
        target = FacadeTier.mid;
      } else {
        target = FacadeTier.far;
      }
      if (target == FacadeTier.near) nearLeft--;
      if (target == FacadeTier.mid) midLeft--;
      _apply(i, target);
    }

    _refreshStats();
  }

  void _apply(int index, FacadeTier target) {
    final surface = _surfaces[index];
    if (surface.tier == target) {
      // Mid surfaces capture once; keep asking until the first capture
      // lands (the host attaches a frame after the component does).
      if (target == FacadeTier.mid && !surface.captured) {
        final controller = surface.component?.controller;
        if (controller != null) {
          if (controller.texture != null) {
            surface.captured = true;
          } else {
            controller.requestCapture();
          }
        }
      }
      return;
    }

    final building = buildings[index];
    final existing = surface.component;
    if (existing != null) {
      building.facadeAnchor.removeComponent(existing);
      surface.component = null;
    }

    if (target != FacadeTier.far) {
      final interactive = target == FacadeTier.near;
      final component = WidgetComponent(
        child: FacadeWidget(
          task: building.task,
          interactive: interactive,
        ),
        size: building.widgetSize,
        geometry: _facadeQuad(
          building.facadeWorldWidth,
          building.facadeWorldHeight,
        ),
        // Static facades re-capture on a slow interval rather than once:
        // negligible amortized cost, and late-arriving content (network
        // cover art) still shows up without change-tracking plumbing.
        update: interactive
            ? WidgetUpdatePolicy.everyFrame
            : const WidgetUpdatePolicy.interval(Duration(seconds: 3)),
      );
      building.facadeAnchor.addComponent(component);
      surface.component = component;
      stats.promotions++;
    }
    surface
      ..tier = target
      ..captured = false;
  }

  void _refreshStats() {
    var near = 0;
    var mid = 0;
    var captures = 0;
    var lastCapture = Duration.zero;
    for (final surface in _surfaces) {
      switch (surface.tier) {
        case FacadeTier.near:
          near++;
        case FacadeTier.mid:
          mid++;
        case FacadeTier.far:
          break;
      }
      final controller = surface.component?.controller;
      if (controller != null) {
        captures += controller.captureCount;
        if (controller.lastCaptureDuration > lastCapture) {
          lastCapture = controller.lastCaptureDuration;
        }
      }
    }
    stats
      ..near = near
      ..mid = mid
      ..far = buildings.length - near - mid
      ..captures = captures
      ..lastCapture = lastCapture;
  }

  /// Detaches every widget surface (used when tearing a scene down).
  void dispose() {
    for (var i = 0; i < buildings.length; i++) {
      final component = _surfaces[i].component;
      if (component != null) {
        buildings[i].facadeAnchor.removeComponent(component);
        _surfaces[i].component = null;
      }
    }
  }
}
