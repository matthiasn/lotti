import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/plaza/scene/surface_captures.dart';
import 'package:vector_math/vector_math.dart' show Matrix4, Vector3;

/// A capture controller with no host: counts the requests the scheduler
/// makes, and lands a capture when the test says so.
class _FakeController extends WidgetTextureController {
  int requests = 0;
  int landed = 0;
  Duration duration = Duration.zero;

  @override
  void requestCapture() => requests++;

  @override
  int get captureCount => landed;

  @override
  Duration get lastCaptureDuration => duration;
}

/// A vertical surface at the origin whose front faces +z.
TimedSurface _atOrigin(_FakeController controller, {Node? node}) =>
    TimedSurface.facing(
      controller: controller,
      node: node ?? Node(),
      center: Vector3.zero(),
      facingRadians: 0,
    );

/// An eye ten metres in front of the origin surface, looking at it.
final _inFront = Vector3(0, 1.7, 10);
final _towardsOrigin = Vector3(0, 0, -1);

void main() {
  group('requestDue', () {
    test('the first capture is free and the next waits for the interval', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final controller = _FakeController();
      captures.timed(cadence, _atOrigin(controller));
      expect(controller.requests, 0, reason: 'registering asks nothing');

      captures.requestDue(cadence, _inFront, 0.5);
      expect(controller.requests, 1, reason: 'the first capture is free');
      captures.requestDue(cadence, _inFront, 0.55);
      expect(controller.requests, 1);
      captures.requestDue(cadence, _inFront, 0.5999);
      expect(controller.requests, 1, reason: '0.0999 s is short of 0.1 s');
      captures.requestDue(cadence, _inFront, 0.5999995);
      expect(
        controller.requests,
        2,
        reason: 'a hair under the interval still counts',
      );
      captures.requestDue(cadence, _inFront, 0.6);
      expect(controller.requests, 2, reason: 'the last request was just made');
      captures.requestDue(cadence, _inFront, 0.7);
      expect(controller.requests, 3);
    });

    test('advances the cadence clock only when a capture is requested', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final controller = _FakeController();
      final node = Node();
      captures.timed(cadence, _atOrigin(controller, node: node));
      var notifications = 0;
      cadence.clock.addListener(() => notifications++);

      expect(cadence.clock.value, 0);
      captures.requestDue(cadence, _inFront, 1);
      expect(cadence.clock.value, 1);
      expect(notifications, 1);

      // Between captures the widgets are not rebuilt.
      captures.requestDue(cadence, _inFront, 1.05);
      expect(cadence.clock.value, 1);
      expect(notifications, 1);

      captures.requestDue(cadence, _inFront, 1.1);
      expect(cadence.clock.value, 1.1);
      expect(notifications, 2);
      expect(controller.requests, 2);

      // A hidden surface neither rebuilds nor captures.
      node.visible = false;
      captures.requestDue(cadence, _inFront, 5);
      expect(cadence.clock.value, 1.1);
      expect(controller.requests, 2);
    });

    test('a surface behind the eye is not captured', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final controller = _FakeController();
      captures.timed(cadence, _atOrigin(controller));
      expect(controller.requests, 0);

      // Standing in front of the panel but looking away from it.
      captures.requestDue(cadence, _inFront, 0, forward: Vector3(0, 0, 1));
      expect(controller.requests, 0);
      expect(cadence.clock.value, 0);

      // Turn round: it is ahead, so it is captured.
      captures.requestDue(cadence, _inFront, 0, forward: _towardsOrigin);
      expect(controller.requests, 1);
    });

    test('a wide band whose centre has just passed the eye is captured', () {
      // Under the gantry, looking down the street: the band's centre is
      // two metres behind the eye's plane and its near end still in view.
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final controller = _FakeController();
      captures.timed(cadence, _atOrigin(controller));
      final justPast = Vector3(0, 1.7, 2);
      captures.requestDue(cadence, justPast, 0, forward: Vector3(0, 0, 1));
      expect(controller.requests, 1);
      // Past the margin it is gone for good.
      final wellPast = Vector3(0, 1.7, TimedSurface.behindMargin + 1);
      captures.requestDue(cadence, wellPast, 1, forward: Vector3(0, 0, 1));
      expect(controller.requests, 1);
    });

    test('a surface whose front faces away from the eye is not captured', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final controller = _FakeController();
      captures.timed(cadence, _atOrigin(controller));

      // Behind the panel, looking at its back.
      final behind = Vector3(0, 1.7, -10);
      captures.requestDue(cadence, behind, 0, forward: Vector3(0, 0, 1));
      expect(controller.requests, 0);

      // Without a view direction nothing is culled.
      captures.requestDue(cadence, behind, 0);
      expect(controller.requests, 1);
    });

    test('a culled surface is captured as soon as it comes into view', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(3);
      final controller = _FakeController();
      captures.timed(cadence, _atOrigin(controller));
      expect(controller.requests, 0);

      captures.requestDue(cadence, _inFront, 0, forward: _towardsOrigin);
      expect(controller.requests, 1);
      // Looking away for a while does not restart the interval.
      captures.requestDue(cadence, _inFront, 4, forward: Vector3(0, 0, 1));
      expect(controller.requests, 1);
      captures.requestDue(cadence, _inFront, 4.5, forward: _towardsOrigin);
      expect(controller.requests, 2);
    });

    test('each surface keeps its own interval within a cadence', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final a = _FakeController();
      final b = _FakeController();
      final bNode = Node();
      captures
        ..timed(cadence, _atOrigin(a))
        ..timed(cadence, _atOrigin(b, node: bNode));

      bNode.visible = false;
      captures.requestDue(cadence, _inFront, 0);
      expect((a.requests, b.requests), (1, 0));
      bNode.visible = true;
      captures.requestDue(cadence, _inFront, 0.05);
      expect((a.requests, b.requests), (1, 1), reason: 'b was never asked');
      captures.requestDue(cadence, _inFront, 0.1);
      expect((a.requests, b.requests), (2, 1));
      captures.requestDue(cadence, _inFront, 0.15);
      expect((a.requests, b.requests), (2, 2));
    });
  });

  group('once', () {
    test('re-requested every frame until the capture lands, then dropped', () {
      final captures = SurfaceCaptures();
      final controller = _FakeController();
      captures.once(controller);
      expect(controller.requests, 0, reason: 'registering asks nothing');

      captures
        ..requestPending()
        ..requestPending()
        ..requestPending();
      expect(controller.requests, 3);

      controller.landed = 1;
      captures
        ..requestPending()
        ..requestPending();
      expect(
        controller.requests,
        3,
        reason: 'a landed capture is not re-asked',
      );
      expect(captures.captures, 1);
    });

    test('a landed surface leaves the pending list, others stay', () {
      final captures = SurfaceCaptures();
      final first = _FakeController();
      final second = _FakeController();
      captures
        ..once(first)
        ..once(second)
        ..requestPending();
      first.landed = 1;
      captures.requestPending();
      expect((first.requests, second.requests), (1, 2));
    });
  });

  group('counters', () {
    test('sum the captures and take the longest recent capture', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final once = _FakeController()
        ..landed = 2
        ..duration = const Duration(milliseconds: 3);
      final timed = _FakeController()
        ..landed = 5
        ..duration = const Duration(milliseconds: 7);
      captures
        ..once(once)
        ..timed(cadence, _atOrigin(timed));
      expect(captures.captures, 7);
      expect(captures.lastCaptureDuration, const Duration(milliseconds: 7));
    });

    test('a forgotten surface is neither counted nor requested again', () {
      final captures = SurfaceCaptures();
      final cadence = CaptureCadence(0.1);
      final timed = _FakeController()..landed = 4;
      final once = _FakeController();
      captures
        ..timed(cadence, _atOrigin(timed))
        ..once(once)
        ..forget(timed, cadence: cadence)
        ..forget(once);
      expect(captures.captures, 0);
      expect(cadence.surfaces, isEmpty);
      captures
        ..requestDue(cadence, _inFront, 1)
        ..requestPending();
      expect((timed.requests, once.requests), (0, 0));
    });
  });

  group('TimedSurface', () {
    test('posed reads the centre and the front from the node transform', () {
      final parent = Node(
        localTransform: Matrix4.translation(Vector3(10, 0, 20))
          ..rotateY(math.pi / 2),
      );
      final anchor = Node(
        localTransform: Matrix4.translation(Vector3(0, 5, 3)),
      );
      parent.add(anchor);
      final surface = TimedSurface.posed(_FakeController(), anchor);
      // Local +z under a quarter turn about y points along world +x.
      expect(surface.center.x, closeTo(13, 1e-6));
      expect(surface.center.y, closeTo(5, 1e-6));
      expect(surface.center.z, closeTo(20, 1e-6));
      expect(surface.normal.x, closeTo(1, 1e-6));
      expect(surface.normal.y, closeTo(0, 1e-6));
      expect(surface.normal.z, closeTo(0, 1e-6));
      // The front is seen from +x looking back, not from -x.
      expect(surface.seenFrom(Vector3(30, 5, 20), Vector3(-1, 0, 0)), isTrue);
      expect(surface.seenFrom(Vector3(0, 5, 20), Vector3(1, 0, 0)), isFalse);
    });

    glados.Glados3(
      glados.any.doubleInRange(-math.pi, math.pi),
      glados.any.doubleInRange(-1.2, 1.2),
      glados.any.doubleInRange(TimedSurface.behindMargin + 0.01, 500),
    ).test(
      'is seen straight ahead facing the eye, never behind or from its back',
      (yaw, pitch, distance) {
        final eye = Vector3(3, 1.7, -8);
        final forward = Vector3(
          math.sin(yaw) * math.cos(pitch),
          math.sin(pitch),
          math.cos(yaw) * math.cos(pitch),
        );
        final controller = _FakeController();
        final ahead = eye + forward * distance;
        final facingEye = TimedSurface(
          controller: controller,
          node: Node(),
          center: ahead,
          normal: -forward,
        );
        final backToEye = TimedSurface(
          controller: controller,
          node: Node(),
          center: ahead,
          normal: forward,
        );
        final behindEye = TimedSurface(
          controller: controller,
          node: Node(),
          center: eye - forward * distance,
          normal: -forward,
        );
        expect(facingEye.seenFrom(eye, forward), isTrue);
        expect(backToEye.seenFrom(eye, forward), isFalse);
        expect(behindEye.seenFrom(eye, forward), isFalse);
      },
      tags: ['glados'],
    );
  });
}
