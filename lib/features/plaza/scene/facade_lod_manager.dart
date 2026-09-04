import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// Surface tier of one facade: live = interactive widget captured every
/// frame, sign = captured once, far = the plate and the lantern only.
enum FacadeTier { far, sign, live }

/// The tier budget. Defaults are the design's numbers; the debug overlay
/// can move them.
class FacadeLodConfig {
  FacadeLodConfig({
    this.liveCap = 4,
    this.signCap = 80,
    this.liveDistance = 26,
    this.signDistance = 140,
    this.promotionsPerFrame = 1,
    this.forceAllLive = false,
  });

  /// Hard cap on live (every-frame) surfaces: the faced building and its
  /// nearest neighbours.
  int liveCap;

  /// Hard cap on hosted sign surfaces.
  int signCap;
  double liveDistance;
  double signDistance;

  /// How many surfaces may be created per frame; demotions are free.
  int promotionsPerFrame;

  /// Stress mode: every facade becomes live, caps ignored.
  bool forceAllLive;
}

/// Live counters for the debug overlay.
class FacadeLodStats {
  int live = 0;
  int sign = 0;
  int far = 0;
  int captures = 0;
  Duration lastCapture = Duration.zero;
  int promotions = 0;
}

class _Surface {
  WidgetComponent? component;
  FacadeTier tier = FacadeTier.far;
  bool captured = false;
}

/// Assigns each facade a tier from camera distance with sticky
/// hysteresis, enforces the caps by construction, and schedules
/// promotions one per frame so walking into a busy block never spikes.
///
/// The faced building (nearest live facade the walker is in front of) gets
/// the focus ring and is the one whose checkboxes work.
class FacadeLodManager {
  FacadeLodManager({
    required this.buildings,
    required this.config,
    required this.ticks,
    required this.onOpen,
  }) : _surfaces = [for (final _ in buildings) _Surface()];

  final List<PlazaBuilding> buildings;
  final FacadeLodConfig config;
  final ChecklistTicks ticks;
  final void Function(PlazaBuilding building) onOpen;
  final List<_Surface> _surfaces;
  final FacadeLodStats stats = FacadeLodStats();

  /// Sticky factor: a surface already at a tier ranks as if 15% closer.
  static const _hysteresis = 0.85;

  /// While true (during flights) no surface is created except the one
  /// pre-captured by [prepare].
  bool suspended = false;

  PlazaBuilding? _focused;
  PlazaBuilding? get focused => _focused;

  /// Promotes [building] to the sign tier immediately, so the destination
  /// of a flight has a facade by the time the camera lands.
  void prepare(PlazaBuilding building) {
    final i = buildings.indexOf(building);
    if (i < 0) return;
    if (_surfaces[i].tier == FacadeTier.far) _apply(i, FacadeTier.sign);
  }

  void update(Vector3 eye) {
    final n = buildings.length;
    final distances = List<double>.filled(n, 0);
    final order = List<int>.generate(n, (i) => i);
    for (var i = 0; i < n; i++) {
      final d = buildings[i].groundDistanceTo(eye);
      distances[i] = _surfaces[i].tier == FacadeTier.far ? d : d * _hysteresis;
    }
    order.sort((a, b) => distances[a].compareTo(distances[b]));

    var liveLeft = config.forceAllLive ? n : config.liveCap;
    var signLeft = config.forceAllLive ? 0 : config.signCap;
    // The stress switch wants the steady state, not a five-second ramp:
    // it ignores the per-frame promotion budget.
    var promotionsLeft = suspended
        ? 0
        : config.forceAllLive
        ? n
        : config.promotionsPerFrame;
    PlazaBuilding? focused;

    for (final i in order) {
      final building = buildings[i];
      final d = distances[i];
      final inFront = building.facesEye(eye);
      FacadeTier target;
      if (config.forceAllLive) {
        target = FacadeTier.live;
      } else if (liveLeft > 0 &&
          d < math.max(config.liveDistance, building.liveRange) &&
          inFront) {
        target = FacadeTier.live;
      } else if (signLeft > 0 && d < config.signDistance) {
        target = FacadeTier.sign;
      } else {
        target = FacadeTier.far;
      }
      if (target == FacadeTier.live) {
        liveLeft--;
        focused ??= building;
      }
      if (target == FacadeTier.sign) signLeft--;

      final current = _surfaces[i].tier;
      if (target.index > current.index) {
        // Promotion: rate-limited.
        if (promotionsLeft > 0) {
          promotionsLeft--;
          _apply(i, target);
        }
      } else {
        _apply(i, target);
      }
    }

    if (focused != _focused) {
      _focused?.ring.visible = false;
      focused?.ring.visible = true;
      _focused = focused;
    }
    _refreshStats();
  }

  void _apply(int index, FacadeTier target) {
    final surface = _surfaces[index];
    if (surface.tier == target) {
      // Sign surfaces capture once; keep asking until the first capture
      // lands (the host attaches a frame after the component does).
      if (target == FacadeTier.sign && !surface.captured) {
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
      final live = target == FacadeTier.live;
      final surfaceMaterial = OpaqueSurface();
      final component = WidgetComponent(
        child: FacadeWidget(
          task: building.task,
          attention: building.attention,
          variant: live ? FacadeVariant.live : FacadeVariant.sign,
          widthMeters: building.facadeWorldWidth,
          pxPerMeter: building.pxPerMeter,
          ticks: live ? ticks : null,
          onOpen: live ? () => onOpen(building) : null,
        ),
        size: building.widgetSize,
        geometry: ccwQuad(
          building.facadeWorldWidth,
          building.facadeWorldHeight,
        ),
        update: live
            ? WidgetUpdatePolicy.everyFrame
            : WidgetUpdatePolicy.manual,
        input: live ? WidgetInput.automatic : WidgetInput.manual,
        material: surfaceMaterial.material,
        bind: surfaceMaterial.bind,
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
    var live = 0;
    var sign = 0;
    var captures = 0;
    var lastCapture = Duration.zero;
    for (final surface in _surfaces) {
      switch (surface.tier) {
        case FacadeTier.live:
          live++;
        case FacadeTier.sign:
          sign++;
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
      ..live = live
      ..sign = sign
      ..far = buildings.length - live - sign
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
