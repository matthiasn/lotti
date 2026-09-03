import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

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

FlyCameraController _controller() =>
    FlyCameraController(position: Vector3(0, 5, 0), yaw: 0);

void main() {
  group('keys and auto-walk', () {
    testWidgets('W walks forward along the view direction', (tester) async {
      final camera = _controller();
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(1);
      expect(camera.position.z, greaterThan(5)); // 12 m/s walk speed.
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      final zAfterWalk = camera.position.z;
      camera
        ..handleKeyEvent(_up(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW))
        ..update(1);
      expect(camera.position.z, zAfterWalk);
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
      expect(sprinter.position.z, greaterThan(walker.position.z));
      await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
    });

    test('a latched key without real hardware state stops the walk', () {
      // The regression: a key-up lost to a focus change left W latched and
      // the camera walking forever. The controller must reconcile with
      // HardwareKeyboard (which has no keys pressed here) and stand still.
      final camera = _controller()
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(1);
      expect(camera.position.z, 0);
    });

    test('space toggles auto-walk and clears held keys', () {
      final camera = _controller();
      final handled = camera.handleKeyEvent(
        _down(LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
      );
      expect(handled, isTrue);
      expect(camera.autoForward, 1);
      camera.update(1);
      expect(camera.position.z, greaterThan(0));

      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
      );
      expect(camera.autoForward, 0);
      final z = camera.position.z;
      camera.update(1);
      expect(camera.position.z, z);
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
  });

  group('look and pose', () {
    test('drag look yaws the camera and clamps pitch', () {
      final camera = _controller()..addLookDelta(0, -10000);
      // Pitch clamps well below straight up.
      final up = camera.camera() as PerspectiveCamera;
      expect(up.target.y - up.position.y, lessThan(10));

      camera.addLookDelta(0, 20000);
      final down = camera.camera() as PerspectiveCamera;
      expect(down.target.y - down.position.y, greaterThan(-10));
    });

    test('reset jumps to a new pose at eye height', () {
      final camera = _controller()
        ..reset(position: Vector3(10, 99, -4), yaw: 3.14)
        ..update(0.016);
      expect(camera.position.x, 10);
      expect(camera.position.z, -4);
      expect(camera.position.y, 5); // Eye height overrides the given y.
    });
  });

  group('overhead mode', () {
    test('blends the eye upward over time, never cutting', () {
      final camera = _controller();
      final groundY = (camera.camera() as PerspectiveCamera).position.y;

      camera
        ..toggleOverhead()
        ..update(0.1);
      final midY = (camera.camera() as PerspectiveCamera).position.y;
      expect(camera.overhead, isTrue);
      expect(midY, greaterThan(groundY));

      for (var i = 0; i < 60; i++) {
        camera.update(0.1);
      }
      final topY = (camera.camera() as PerspectiveCamera).position.y;
      expect(topY, greaterThan(midY));
      expect(topY, closeTo(90, 1)); // Overhead height.

      // Overhead looks down at the walker's spot.
      final overheadCam = camera.camera() as PerspectiveCamera;
      expect(overheadCam.target.y, lessThan(overheadCam.position.y));

      camera.toggleOverhead();
      expect(camera.overhead, isFalse);
      for (var i = 0; i < 60; i++) {
        camera.update(0.1);
      }
      expect(
        (camera.camera() as PerspectiveCamera).position.y,
        closeTo(groundY, 0.5),
      );
    });
  });
}
