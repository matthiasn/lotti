import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// World metres a widget surface is pulled toward the eye in the depth
/// test (see [hostedSurface]).
const widgetDepthBias = 0.15;

/// A widget surface for the plaza: [child] laid out at [pxPerMeter] ×
/// [scale] logical pixels a metre on a [ccwQuad] of [width] × [height]
/// metres (or the [geometry] given, when the texture is not the quad's
/// size: a ticker's period on its band), over an [OpaqueSurface] — the
/// caller's [surface], when it keeps the material to drive it.
///
/// Every plaza surface is a [WidgetUpdatePolicy.manual] component: an
/// interval policy would make flutter_scene pump an engine frame on every
/// vsync, whatever the harness paints, so captures are requested from the
/// harness clock through [SurfaceCaptures]. [input] is manual unless the
/// surface takes pointer input (a live facade).
WidgetComponent hostedSurface({
  required Widget child,
  required double width,
  required double height,
  required double pxPerMeter,
  double scale = 1,
  WidgetInput input = WidgetInput.manual,
  Geometry? geometry,
  OpaqueSurface? surface,
}) {
  surface ??= OpaqueSurface();
  // Every widget surface hangs a few centimetres in front of something
  // (a facade's plate, a lightbox, a ticker's track): biased toward the
  // eye so it wins the depth test at any distance instead of fighting the
  // backing frame by frame as the camera flies.
  surface.material.depthBias = widgetDepthBias;
  return WidgetComponent(
    child: child,
    size: Size(width * pxPerMeter * scale, height * pxPerMeter * scale),
    geometry: geometry ?? ccwQuad(width, height),
    update: WidgetUpdatePolicy.manual,
    input: input,
    material: surface.material,
    bind: surface.bind,
  );
}

/// A surface captured on a [CaptureCadence]: its capture controller, the
/// node whose visibility gates it, and where it stands and faces, so a
/// capture the camera cannot see is not requested.
class TimedSurface {
  TimedSurface({
    required this.controller,
    required this.node,
    required this.center,
    required this.normal,
  });

  /// A vertical surface at [center] whose front faces [facingRadians]
  /// (the plaza's yaw convention: the front is at `+sin`, `+cos`).
  TimedSurface.facing({
    required WidgetTextureController controller,
    required Node node,
    required Vector3 center,
    required double facingRadians,
  }) : this(
         controller: controller,
         node: node,
         center: center,
         normal: Vector3(math.sin(facingRadians), 0, math.cos(facingRadians)),
       );

  /// A surface read off [node]'s world transform as it stands now: its
  /// translation is the centre and its local `+z` axis is the front, the
  /// way a [ccwQuad] faces. The node must be in its final pose.
  factory TimedSurface.posed(WidgetTextureController controller, Node node) {
    final transform = node.globalTransform;
    return TimedSurface(
      controller: controller,
      node: node,
      center: transform.getTranslation(),
      normal: Vector3(
        transform.entry(0, 2),
        transform.entry(1, 2),
        transform.entry(2, 2),
      )..normalize(),
    );
  }

  final WidgetTextureController controller;

  /// The node the surface hangs on: hidden nodes are not captured.
  final Node node;

  /// World position of the surface.
  final Vector3 center;

  /// Unit outward normal of the front.
  final Vector3 normal;

  /// Harness seconds of the last capture request; the first is free.
  double lastRequest = double.negativeInfinity;

  /// A surface whose centre has passed the eye by no more than this is
  /// still in view: a wide band overhead (the gantry) or one the walker
  /// is passing shows its near end after its centre has gone by.
  static const behindMargin = 4.0;

  /// Whether a camera at [eye] looking along [forward] can see the front:
  /// the surface is not behind the eye (by more than [behindMargin]), and
  /// the eye is not behind the surface. Scalar maths; nothing is
  /// allocated.
  bool seenFrom(Vector3 eye, Vector3 forward) {
    final dx = center.x - eye.x;
    final dy = center.y - eye.y;
    final dz = center.z - eye.z;
    return dx * forward.x + dy * forward.y + dz * forward.z >= -behindMargin &&
        dx * normal.x + dy * normal.y + dz * normal.z <= 0;
  }
}

/// The surfaces captured every [interval] seconds and the clock their
/// widgets read.
///
/// The clock is advanced to the harness time only when a capture is
/// requested ([SurfaceCaptures.requestDue]), so a hosted widget rebuilds
/// once per capture, in the frame of the request, instead of once per
/// painted frame with most of the work thrown away.
class CaptureCadence {
  CaptureCadence(this.interval);

  final double interval;
  final List<TimedSurface> surfaces = [];
  final ValueNotifier<double> _clock = ValueNotifier(0);

  /// Elapsed harness seconds as of this cadence's last capture request.
  ValueListenable<double> get clock => _clock;
}

/// Manual capture bookkeeping for a set of widget surfaces, shared by
/// `PlazaSurfaces` and `FacadeLodManager`: one-off captures re-requested
/// until they land, cadenced captures throttled per surface and skipped
/// while the camera cannot see them, and the counters the overlay shows.
class SurfaceCaptures {
  final Map<WidgetTextureController, int> _pendingOnce = {};
  final Set<WidgetTextureController> _tracked = {};

  /// A capture request is due once this much of the interval has passed:
  /// a frame landing a hair early still counts.
  static const _slack = 1e-6;

  /// Registers a surface captured once. The host attaches a frame after
  /// the component does, so [requestPending] keeps asking until the requested
  /// capture lands.
  void once(WidgetTextureController controller) {
    _tracked.add(controller);
    invalidate(controller);
  }

  /// Requests a fresh texture after content changes, even when the initial
  /// capture already landed. Forgotten surfaces ignore late image callbacks.
  void invalidate(WidgetTextureController controller) {
    if (!_tracked.contains(controller)) return;
    _pendingOnce[controller] = controller.captureCount + 1;
  }

  /// Registers [surface] on [cadence].
  void timed(CaptureCadence cadence, TimedSurface surface) {
    _tracked.add(surface.controller);
    cadence.surfaces.add(surface);
  }

  /// Drops a surface that was detached from its node: it is no longer
  /// requested or counted. [cadence] is the one it was registered on.
  void forget(WidgetTextureController controller, {CaptureCadence? cadence}) {
    _tracked.remove(controller);
    _pendingOnce.remove(controller);
    cadence?.surfaces.removeWhere((s) => s.controller == controller);
  }

  /// Re-requests every one-off capture that has not landed yet, and stops
  /// asking for those that have, so the list empties after the first
  /// frames.
  void requestPending() {
    _pendingOnce.removeWhere((controller, target) {
      if (controller.captureCount >= target) return true;
      controller.requestCapture();
      return false;
    });
  }

  /// Asks every visible surface of [cadence] for a capture once its
  /// interval is up at [seconds], advancing the cadence's clock to
  /// [seconds] immediately before each request so the widget rebuilds in
  /// the same frame. With [forward] (the camera's view direction) a
  /// surface behind the eye or facing away from it is skipped; without it
  /// nothing is culled.
  void requestDue(
    CaptureCadence cadence,
    Vector3 eye,
    double seconds, {
    Vector3? forward,
  }) {
    for (final surface in cadence.surfaces) {
      if (!surface.node.visible) continue;
      if (forward != null && !surface.seenFrom(eye, forward)) continue;
      if (seconds - surface.lastRequest < cadence.interval - _slack) continue;
      surface.lastRequest = seconds;
      cadence._clock.value = seconds;
      surface.controller.requestCapture();
    }
  }

  /// Total captures across every registered surface.
  int get captures {
    var n = 0;
    for (final controller in _tracked) {
      n += controller.captureCount;
    }
    return n;
  }

  /// The longest of the registered surfaces' most recent captures.
  Duration get lastCaptureDuration {
    var longest = Duration.zero;
    for (final controller in _tracked) {
      if (controller.lastCaptureDuration > longest) {
        longest = controller.lastCaptureDuration;
      }
    }
    return longest;
  }
}
