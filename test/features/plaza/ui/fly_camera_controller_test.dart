import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';

KeyDownEvent _down(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
      logicalKey: logical,
      physicalKey: physical,
      timeStamp: Duration.zero,
    );

KeyUpEvent _up(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
    KeyUpEvent(
      logicalKey: logical,
      physicalKey: physical,
      timeStamp: Duration.zero,
    );

const _origin = CameraPose(x: 0, y: eyeHeight, z: 0, yaw: 0);

FlyCameraController _controller({WalkCollider? collider}) =>
    FlyCameraController(pose: _origin, collider: collider);

void main() {
  group('walking', () {
    testWidgets('W walks forward along the view direction', (tester) async {
      final camera = _controller();
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(1);
      expect(camera.pose.z, closeTo(FlyCameraController.walkSpeed, 1e-9));
      expect(camera.pose.y, eyeHeight);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      final zAfterWalk = camera.pose.z;
      camera
        ..handleKeyEvent(_up(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW))
        ..update(1);
      expect(camera.pose.z, zAfterWalk);
    });

    testWidgets('shift sprints', (tester) async {
      final walker = _controller();
      final sprinter = _controller();
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      walker
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(1);
      await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      sprinter
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft),
        )
        ..update(1);
      expect(sprinter.pose.z, closeTo(walker.pose.z * 3, 1e-9));
      await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
    });

    test('a latched key without real hardware state stops the walk', () {
      final camera = _controller()
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(1);
      expect(camera.pose.z, 0);
    });

    test('untracked keys are not handled', () {
      final camera = _controller();
      expect(
        camera.handleKeyEvent(
          _down(LogicalKeyboardKey.keyQ, PhysicalKeyboardKey.keyQ),
        ),
        isFalse,
      );
    });

    testWidgets('the collider keeps the walker out of buildings', (
      tester,
    ) async {
      // A building straight ahead, its facade toward the walker.
      const wall = PlotPlacement(
        taskId: 'w',
        bucketIndex: 0,
        side: PlotSide.left,
        x: 0,
        z: 8,
        facingRadians: 3.141592653589793, // faces -Z, toward the origin
        width: 10,
        depth: 6,
        height: 5,
      );
      final camera = _controller(collider: WalkCollider([wall]));
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      for (var i = 0; i < 10; i++) {
        camera.update(0.1);
      }
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      // 12 m of walking would end inside the box; the collider stops the
      // walker at the facade plus the margin.
      expect(camera.pose.z, closeTo(8 - 3 - 0.6, 1e-6));
    });
  });

  group('look and pose', () {
    test('drag look yaws the camera and clamps pitch', () {
      final camera = _controller()..addLookDelta(0, -10000);
      final up = camera.camera() as PerspectiveCamera;
      expect(up.target.y - up.position.y, lessThan(10));
      camera.addLookDelta(0, 20000);
      final down = camera.camera() as PerspectiveCamera;
      expect(down.target.y - down.position.y, greaterThan(-10));
      expect(camera.pitch, -1.25);
    });

    test('setting the pose jumps, keeps eye height on the next update', () {
      final camera = _controller()
        ..pose = const CameraPose(x: 10, y: 99, z: -4, yaw: 3.14, pitch: 0.4)
        ..update(0.016);
      expect(camera.pose.x, 10);
      expect(camera.pose.z, -4);
      expect(camera.pose.y, eyeHeight);
      expect(camera.pitch, 0.4);
    });
  });

  group('flights', () {
    test('flyTo moves the camera along the flight and lands exactly', () {
      var arrivals = 0;
      final camera = _controller()..onArrived = () => arrivals++;
      const target = CameraPose(x: 0, y: eyeHeight, z: 20, yaw: 1, pitch: 0.2);
      final flight = camera.flyTo(target);
      expect(camera.flying, isTrue);
      camera.update(flight.duration.inMicroseconds / 2e6);
      expect(camera.pose.z, closeTo(10, 1e-6));
      expect(camera.flying, isTrue);
      camera.update(flight.duration.inMicroseconds / 2e6 + 0.01);
      expect(camera.flying, isFalse);
      expect(camera.pose.z, 20);
      expect(camera.pose.yaw, 1);
      expect(camera.pose.pitch, 0.2);
      expect(arrivals, 1);
    });

    test('movement input cancels a flight in place', () {
      var cancelled = 0;
      var moved = 0;
      final camera = _controller()
        ..onFlightCancelled = () => cancelled++
        ..onMovement = () => moved++;
      final flight = camera.flyTo(
        const CameraPose(x: 0, y: eyeHeight, z: 100, yaw: 0),
      );
      camera.update(flight.duration.inMicroseconds / 2e6);
      final midway = camera.pose.z;
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      expect(camera.flying, isFalse);
      expect(cancelled, 1);
      expect(moved, 1);
      camera.update(1); // no hardware key → stands still
      expect(camera.pose.z, closeTo(midway, 1e-6));
    });

    test('drag look cancels a flight too, and pose set clears it', () {
      var cancelled = 0;
      final camera = _controller()..onFlightCancelled = () => cancelled++;
      camera
        ..flyTo(const CameraPose(x: 0, y: eyeHeight, z: 100, yaw: 0))
        ..addLookDelta(5, 0);
      expect(camera.flying, isFalse);
      expect(cancelled, 1);
      camera
        ..flyTo(const CameraPose(x: 0, y: eyeHeight, z: 100, yaw: 0))
        ..pose = _origin;
      expect(camera.flying, isFalse);
      expect(cancelled, 1);
    });
  });
}
