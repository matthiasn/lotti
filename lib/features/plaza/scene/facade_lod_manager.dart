import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/scene/plaza_scene_records.dart';
import 'package:lotti/features/plaza/scene/surface_captures.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// Surface tier of one facade: live = interactive widget captured every
/// 50 ms, sign = captured initially and after cover completion, far = the
/// plate and the lantern only.
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

  /// Hard cap on live (interactive) surfaces: the faced building and its
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

  /// One value captures every setting that can invalidate a tier ranking.
  _Budget _budget(bool flying) => (
    liveCap: liveCap,
    signCap: signCap,
    liveDistance: liveDistance,
    signDistance: signDistance,
    promotionsPerFrame: promotionsPerFrame,
    forceAllLive: forceAllLive,
    flying: flying,
  );
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
  _Surface(this.building);
  final PlazaBuilding building;
  double distance = 0;
  WidgetComponent? component;
  FacadeTier tier = FacadeTier.far;
}

/// The budget and the suspension a ranking was made under; a change to any
/// of them makes the ranking stale.
typedef _Budget = ({
  int liveCap,
  int signCap,
  double liveDistance,
  double signDistance,
  int promotionsPerFrame,
  bool forceAllLive,
  bool flying,
});

/// Builds the GPU surface separately from the tier and capture scheduling.
/// Tests supply a bind-only component to exercise promotions without a GPU.
typedef FacadeSurfaceBuilder =
    WidgetComponent Function({
      required Widget child,
      required double width,
      required double height,
      required double pxPerMeter,
      WidgetInput input,
      double pixelRatio,
    });

/// Assigns each facade a tier from camera distance with sticky
/// hysteresis, enforces the caps by construction, and schedules
/// promotions one per frame so walking into a busy block never spikes.
///
/// A nearby facade becomes live only after a tap, gets the focus ring,
/// and remains interactive until the walker leaves its range or view.
class FacadeLodManager {
  FacadeLodManager({
    required this.buildings,
    required this.config,
    required this.ticks,
    required this.onOpen,
    this.surfaceBuilder = hostedSurface,
  }) : _surfaces = [for (final building in buildings) _Surface(building)];

  final List<PlazaBuilding> buildings;
  final FacadeLodConfig config;
  final ChecklistTicks ticks;
  final void Function(PlazaBuilding building) onOpen;
  final FacadeSurfaceBuilder surfaceBuilder;
  final List<_Surface> _surfaces;
  final FacadeLodStats stats = FacadeLodStats();

  final SurfaceCaptures _captures = SurfaceCaptures();
  final CaptureCadence _live = CaptureCadence(liveInterval);

  /// Ranking references travel with their building and surface state.
  late final List<_Surface> _rankedSurfaces = List.of(_surfaces);

  /// What the last ranking was made for. It holds until the eye, the view
  /// direction, the budget or the suspension changes, or until it left
  /// work undone: a tier it changed (the hysteresis shifts) or a promotion
  /// it could not afford.
  final Vector3 _rankedEye = Vector3.zero();
  final Vector3 _rankedForward = Vector3.zero();
  bool _rankedWithForward = false;
  _Budget? _rankedBudget;
  bool _settled = false;
  int _rankings = 0;

  /// How many times the tiers have been ranked.
  @visibleForTesting
  int get rankings => _rankings;

  /// Sticky factor: a surface already at a tier ranks as if 15% closer.
  static const _hysteresis = 0.85;

  /// The nearest [count] buildings with their tier, ground distance, live
  /// range and whether the eye is on their street side: the tour prints
  /// this so a capture can be explained without a debugger.
  String describeNearest(Vector3 eye, {int count = 5}) {
    final rows = [
      for (final surface in _surfaces)
        (
          surface.building.groundDistanceTo(eye),
          surface.building,
          surface.tier,
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return rows
        .take(count)
        .map(
          (r) =>
              '${r.$2.task.title.split(' ').take(3).join(' ')}: '
              '${r.$3.name} d=${r.$1.toStringAsFixed(1)} '
              'range=${r.$2.liveRange.toStringAsFixed(1)} '
              'front=${r.$2.facesEye(eye)}',
        )
        .join(' | ');
  }

  PlazaBuilding? _activated;

  /// Activates a nearby facade after a tap. A distant tap should navigate
  /// first. Only the selected wall is interactive; leaving its live range
  /// or turning away disarms it, so idle signs do not keep capturing.
  bool activate(PlazaBuilding building, Vector3 eye, {Vector3? forward}) {
    if (!buildings.contains(building) ||
        config.liveCap <= 0 ||
        building.groundDistanceTo(eye) >=
            math.max(config.liveDistance, building.liveRange) ||
        !_inView(building, eye, forward)) {
      return false;
    }
    if (_activated != building) {
      _activated = building;
      _settled = false;
    }
    return true;
  }

  PlazaBuilding? _focused;
  PlazaBuilding? get focused => _focused;

  /// Promotes [building] to the sign tier immediately, so the destination
  /// of a flight has a facade by the time the camera lands.
  void prepare(PlazaBuilding building) {
    final surface = _surfaces.where((s) => s.building == building).firstOrNull;
    if (surface == null) return;
    if (surface.tier == FacadeTier.far) {
      _apply(surface, FacadeTier.sign);
      _settled = false;
    }
  }

  /// How often a live wall is captured, seconds on the harness clock.
  static const liveInterval = 0.05;

  /// Once per painted frame: assigns the tiers for [eye] unless the last
  /// ranking still holds (same eye, [forward], budget and [flying], and
  /// nothing left undone), then asks every live wall for a capture once
  /// [liveInterval] has passed since its last, at [seconds] on the harness
  /// clock, and every sign for its one capture until it lands. [forward]
  /// is the camera's view direction: a wall behind the walker never takes
  /// a live slot, however near — standing 22 m from a landmark puts the
  /// opposite row 3 m behind your back. While [flying] no surface is
  /// created except the one pre-captured by [prepare].
  void update(
    Vector3 eye, {
    Vector3? forward,
    double seconds = 0,
    bool flying = false,
  }) {
    if (!_rankingHolds(eye, forward, flying)) _rank(eye, forward, flying);
    // No culling here: the ranking already demoted every wall the camera
    // cannot see.
    _captures
      ..requestDue(_live, eye, seconds)
      ..requestPending();
    _refreshStats();
  }

  bool _rankingHolds(Vector3 eye, Vector3? forward, bool flying) {
    if (!_settled || eye != _rankedEye) return false;
    if (forward == null) {
      if (_rankedWithForward) return false;
    } else if (!_rankedWithForward || forward != _rankedForward) {
      return false;
    }
    return _rankedBudget == config._budget(flying);
  }

  void _rank(Vector3 eye, Vector3? forward, bool flying) {
    _rankings++;
    final n = buildings.length;
    for (final surface in _surfaces) {
      final d = surface.building.groundDistanceTo(eye);
      surface.distance = surface.tier == FacadeTier.far ? d : d * _hysteresis;
    }
    _rankedSurfaces.sort((a, b) => a.distance.compareTo(b.distance));

    var liveLeft = config.forceAllLive ? n : config.liveCap;
    var signLeft = config.forceAllLive ? 0 : config.signCap;
    // The stress switch wants the steady state, not a five-second ramp:
    // it ignores the per-frame promotion budget.
    var promotionsLeft = flying
        ? 0
        : config.forceAllLive
        ? n
        : config.promotionsPerFrame;
    PlazaBuilding? focused;
    var changed = false;
    var waiting = false;

    for (final surface in _rankedSurfaces) {
      final building = surface.building;
      final d = surface.distance;
      FacadeTier target;
      if (config.forceAllLive) {
        target = FacadeTier.live;
      } else if (building == _activated &&
          liveLeft > 0 &&
          d < math.max(config.liveDistance, building.liveRange) &&
          _inView(building, eye, forward)) {
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

      final current = surface.tier;
      if (target == current) continue;
      if (target.index > current.index) {
        // Promotion: rate-limited.
        if (promotionsLeft > 0) {
          promotionsLeft--;
          _apply(surface, target);
          changed = true;
        } else {
          waiting = true;
        }
      } else {
        _apply(surface, target);
        changed = true;
      }
    }

    if (!config.forceAllLive && focused == null) _activated = null;

    if (focused != _focused) {
      _focused?.ring.visible = false;
      _focused?.neon.visible = true;
      focused?.ring.visible = true;
      focused?.neon.visible = false;
      _focused = focused;
    }

    _settled = !changed && !waiting;
    _rankedEye.setFrom(eye);
    _rankedWithForward = forward != null;
    if (forward != null) _rankedForward.setFrom(forward);
    _rankedBudget = config._budget(flying);
  }

  /// Whether the eye is on [building]'s street side and, given [forward],
  /// the wall is ahead of the camera. Scalar maths from one offset.
  static bool _inView(PlazaBuilding building, Vector3 eye, Vector3? forward) {
    final center = building.facadeCenter;
    final dx = eye.x - center.x;
    final dy = eye.y - center.y;
    final dz = eye.z - center.z;
    final normal = building.facadeNormal;
    if (dx * normal.x + dy * normal.y + dz * normal.z <= 0) return false;
    if (forward == null) return true;
    return dx * forward.x + dy * forward.y + dz * forward.z < 0;
  }

  void _apply(_Surface surface, FacadeTier target) {
    final building = surface.building;
    final existing = surface.component;
    if (existing != null) {
      building.facadeAnchor.removeComponent(existing);
      _captures.forget(existing.controller, cadence: _live);
      surface.component = null;
    }

    if (target != FacadeTier.far) {
      final live = target == FacadeTier.live;
      late final WidgetComponent component;
      component = surfaceBuilder(
        child: FacadeWidget(
          task: building.task,
          attention: building.attention,
          variant: live ? FacadeVariant.live : FacadeVariant.sign,
          widthMeters: building.facadeWorldWidth,
          pxPerMeter: building.pxPerMeter,
          ticks: live ? ticks : null,
          onCoverChanged: () => _captures.invalidate(component.controller),
          onOpen: live ? () => onOpen(building) : null,
        ),
        width: building.facadeWorldWidth,
        height: building.facadeWorldHeight,
        pxPerMeter: building.pxPerMeter,
        pixelRatio: live ? 1 : 0.5,
        // A live wall takes pointer input; a sign does not.
        input: live ? WidgetInput.automatic : WidgetInput.manual,
      );
      building.facadeAnchor.addComponent(component);
      surface.component = component;
      if (live) {
        _captures.timed(
          _live,
          TimedSurface(
            controller: component.controller,
            node: building.facadeAnchor,
            center: building.facadeCenter,
            normal: building.facadeNormal,
          ),
        );
      } else {
        _captures.once(component.controller);
      }
      stats.promotions++;
    }
    surface.tier = target;
  }

  void _refreshStats() {
    var live = 0;
    var sign = 0;
    for (final surface in _surfaces) {
      switch (surface.tier) {
        case FacadeTier.live:
          live++;
        case FacadeTier.sign:
          sign++;
        case FacadeTier.far:
          break;
      }
    }
    stats
      ..live = live
      ..sign = sign
      ..far = buildings.length - live - sign
      ..captures = _captures.captures
      ..lastCapture = _captures.lastCaptureDuration;
  }

  /// Detaches every widget surface (used when tearing a scene down).
  void dispose() {
    _activated = null;
    for (final surface in _surfaces) {
      final component = surface.component;
      if (component != null) {
        surface.building.facadeAnchor.removeComponent(component);
        _captures.forget(component.controller, cadence: _live);
        surface.component = null;
      }
    }
    _settled = false;
  }
}
