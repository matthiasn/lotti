import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart'
    show PerspectiveCamera, PerspectiveProjection;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/flight.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/domain/street_network.dart';
import 'package:lotti/features/plaza/domain/walk_collider.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';

KeyDownEvent _down(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
      logicalKey: logical,
      physicalKey: physical,
      timeStamp: Duration.zero,
    );

KeyRepeatEvent _repeat(
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical,
) => KeyRepeatEvent(
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
      // One long step: the velocity blend has all but converged.
      expect(camera.pose.z, closeTo(FlyCameraController.walkSpeed, 0.05));
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
      expect(sprinter.pose.z, closeTo(walker.pose.z * 2.5, 0.05));
      await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
    });

    test('forward follows yaw and pitch', () {
      final c = _controller();
      expect(c.yaw, _origin.yaw);
      expect(c.pitch, 0);
      expect(c.forward.x, closeTo(math.sin(_origin.yaw), 1e-9));
      expect(c.forward.z, closeTo(math.cos(_origin.yaw), 1e-9));
      expect(c.forward.y, closeTo(0, 1e-9));
      c.pose = const CameraPose(x: 0, y: 2.2, z: 0, yaw: 0, pitch: math.pi / 2);
      expect(c.forward.y, closeTo(1, 1e-9));
      expect(c.forward.length, closeTo(1, 1e-9));
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
      final camera = _controller(collider: WalkCollider([wall.footprint]));
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      for (var i = 0; i < 30; i++) {
        camera.update(0.1);
      }
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      // Ten metres of walking would end inside the box; the collider
      // stops the walker at the facade plus the margin.
      expect(camera.pose.z, closeTo(8 - 3 - 0.6, 1e-6));
    });
  });

  group('walk feel', () {
    testWidgets('accelerates over the first steps and coasts to a stop', (
      tester,
    ) async {
      final camera = _controller();
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(0.05);
      final first = camera.pose.z;
      expect(first, greaterThan(0));
      expect(first, lessThan(FlyCameraController.walkSpeed * 0.05 * 0.6));
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _up(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(0.05);
      // Still moving right after the key-up, then settles.
      expect(camera.pose.z, greaterThan(first));
      for (var i = 0; i < 41; i++) {
        camera.update(0.05);
      }
      final settled = camera.pose.z;
      for (var i = 0; i < 5; i++) {
        camera.update(0.05);
      }
      expect(camera.pose.z, settled);
    });

    test('uses a 60° game-camera field of view', () {
      final cam = _controller().camera() as PerspectiveCamera;
      expect(
        (cam.projection as PerspectiveProjection).fovRadiansY,
        closeTo(60 * 3.141592653589793 / 180, 1e-9),
      );
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

    testWidgets('a set pose keeps its height; the first step lands first', (
      tester,
    ) async {
      final camera = _controller()
        ..pose = const CameraPose(x: 10, y: 99, z: -4, yaw: 3.14, pitch: 0.4)
        ..update(0.016);
      expect(camera.pose.x, 10);
      expect(camera.pose.z, -4);
      expect(camera.pose.y, 99); // The overview pose stays aloft.
      expect(camera.pitch, 0.4);

      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(0.1);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      // Not a one-frame drop: a landing flight straight down, level.
      expect(camera.flying, isTrue);
      expect(camera.pose.y, lessThan(99));
      expect(camera.pose.y, greaterThan(eyeHeight));
      // A 97 m descent takes a shade over four seconds on the S-curve.
      for (var i = 0; i < 80; i++) {
        camera.update(0.1);
      }
      expect(camera.flying, isFalse);
      expect(camera.pose.y, closeTo(eyeHeight, 1e-6));
      expect(camera.pose.x, 10);
      expect(camera.pose.z, -4);
      expect(camera.pitch, 0);
    });
  });

  group('flights', () {
    testWidgets('a flight discards walking momentum before overview arrival', (
      tester,
    ) async {
      final camera = _controller();
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(0.1);
      expect(camera.pose.z, greaterThan(0));
      const target = CameraPose(x: 20, y: 90, z: 40, yaw: 1);
      final flight = camera.flyTo(target);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(_up(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW))
        ..update(flight.duration.inMicroseconds / 1e6 + 0.01);
      expect(camera.pose.y, target.y);
      camera.update(1 / 60);
      expect(camera.pose.y, target.y);
      expect(camera.pose.x, target.x);
      expect(camera.pose.z, target.z);
      expect(camera.moving, isFalse);
    });

    for (final holding in [false, true]) {
      test('drag abandons a morning walk (holding: $holding)', () {
        final walk = MorningWalk([
          const WalkStop(
            pose: _origin,
            label: 'Home',
            hold: Duration(seconds: 1),
          ),
          const WalkStop(
            pose: _origin,
            label: 'Next',
            hold: Duration(seconds: 1),
          ),
        ]);
        final camera = _controller()..onMovement = walk.abandon;
        if (holding) {
          walk.arrived();
        } else {
          camera.flyTo(const CameraPose(x: 0, y: 30, z: 20, yaw: 0));
        }
        camera.addLookDelta(10, 0);
        expect(camera.flying, isFalse);
        expect(walk.finished, isTrue);
        expect(walk.tick(const Duration(seconds: 5)), isNull);
      });
    }

    test('flyTo moves the camera along the flight and lands exactly', () {
      var arrivals = 0;
      final camera = _controller()..onArrived = () => arrivals++;
      const target = CameraPose(x: 0, y: eyeHeight, z: 20, yaw: 1, pitch: 0.2);
      final flight = camera.flyTo(target);
      expect(camera.flying, isTrue);
      expect(camera.flight, same(flight));
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
      var moved = 0;
      final camera = _controller()
        ..onMovement = () {
          moved++;
        };
      // A ground-level hop (no arc): cancelling stops the camera in place.
      final flight = camera.flyTo(
        const CameraPose(x: 0, y: eyeHeight, z: 40, yaw: 0),
      );
      camera.update(flight.duration.inMicroseconds / 2e6);
      final midway = camera.pose.z;
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      expect(camera.flying, isFalse);
      expect(moved, 1);
      camera.update(1); // no hardware key → stands still
      expect(camera.pose.z, closeTo(midway, 1e-6));

      // An arc flight cancelled aloft lands first instead of dropping.
      final arc = camera.flyTo(
        const CameraPose(x: 0, y: eyeHeight, z: 300, yaw: 0),
      );
      camera.update(arc.duration.inMicroseconds / 2e6);
      expect(camera.pose.y, greaterThan(eyeHeight + 5));
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      expect(moved, 2);
      expect(camera.flying, isTrue); // the landing
      for (var i = 0; i < 40; i++) {
        camera.update(0.1);
      }
      expect(camera.pose.y, closeTo(eyeHeight, 1e-6));
    });

    test('a street flight cut short comes down before walking', () {
      // A routed flight cruises at street height with no arc at all; a
      // key mid-street must still land the camera, not drop it.
      final camera = FlyCameraController(
        pose: const CameraPose(x: 0, y: eyeHeight, z: 10, yaw: 0),
        network: StreetNetwork(const [(0, 0), (0, 200)]),
      );
      final flight = camera.flyTo(
        const CameraPose(x: 0, y: eyeHeight, z: 120, yaw: 0),
      );
      expect(flight.routed, isTrue);
      expect(flight.arc, 0);
      camera.update(flight.duration.inMicroseconds / 2e6);
      expect(camera.pose.y, closeTo(Flight.streetFlightHeight, 1e-6));
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      expect(camera.flying, isTrue); // the landing
      camera.update(0.05);
      expect(camera.pose.y, greaterThan(eyeHeight + 2));
      for (var i = 0; i < 40; i++) {
        camera.update(0.1);
      }
      expect(camera.flying, isFalse);
      expect(camera.pose.y, closeTo(eyeHeight, 1e-6));
    });

    test("a held key's repeats do not restart the landing", () {
      final camera = _controller()
        ..pose = const CameraPose(x: 0, y: 40, z: 0, yaw: 0)
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        );
      expect(camera.flying, isTrue);
      camera.update(0.1);
      // Repeats every tenth of a second, as a held key sends them: the
      // landing keeps its speed and finishes in its own time.
      var steps = 0;
      while (camera.flying && steps < 60) {
        camera
          ..handleKeyEvent(
            _repeat(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
          )
          ..update(0.1);
        steps++;
      }
      expect(camera.flying, isFalse);
      expect(camera.pose.y, closeTo(eyeHeight, 1e-6));
      // Under four seconds for a 38 m descent on the direct profile.
      expect(steps, lessThan(40));
    });

    test('drag look cancels a flight too, and pose set clears it', () {
      final camera = _controller()
        ..flyTo(const CameraPose(x: 0, y: eyeHeight, z: 100, yaw: 0))
        ..addLookDelta(5, 0);
      expect(camera.flying, isFalse);
      camera
        ..flyTo(const CameraPose(x: 0, y: eyeHeight, z: 100, yaw: 0))
        ..pose = _origin;
      expect(camera.flying, isFalse);
    });
  });

  group('over solids', () {
    const building = Solid(
      footprint: Footprint(x: 0, z: 25, facingRadians: 0, width: 10, depth: 10),
      top: 30,
    );

    test('a flight lifts over a building on its line', () {
      final camera = FlyCameraController(pose: _origin, solids: [building])
        ..flyTo(const CameraPose(x: 0, y: eyeHeight, z: 50, yaw: 0));
      var peak = 0.0;
      while (camera.flying) {
        camera.update(0.01);
        final p = camera.pose;
        expect(building.contains(p.x, p.y, p.z), isFalse, reason: '$p');
        peak = math.max(peak, p.y);
      }
      expect(peak, closeTo(30 + Flight.clearance, 1e-6));
      expect(camera.pose.z, 50);
      expect(camera.pose.y, closeTo(eyeHeight, 1e-9));
    });

    testWidgets('a landing from over a roof comes down beside the wall', (
      tester,
    ) async {
      final collider = WalkCollider([building.footprint]);
      final camera = FlyCameraController(
        pose: _origin,
        collider: collider,
        solids: const [building],
      )..pose = const CameraPose(x: 0, y: 60, z: 25, yaw: 0);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera.handleKeyEvent(
        _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
      );
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(camera.flying, isTrue);
      while (camera.flying) {
        camera.update(0.01);
        final p = camera.pose;
        expect(building.contains(p.x, p.y, p.z), isFalse, reason: '$p');
      }
      final p = camera.pose;
      expect(p.y, closeTo(eyeHeight, 1e-9));
      expect(collider.resolve(p.x, p.z), (p.x, p.z));
      // A margin past the wall, not on the roof and not in the building.
      final (_, v) = building.footprint.local(p.x, p.z);
      expect(v.abs(), closeTo(5 + solidClearance, 1e-9));
    });
  });

  group('routing', () {
    final network = StreetNetwork(const [(0, 0), (60, 0), (60, 60)]);

    test('between two stops on the ground the flight follows the street', () {
      final camera = FlyCameraController(
        pose: const CameraPose(x: 0, y: eyeHeight, z: -4, yaw: 0),
        network: network,
      );
      final f = camera.flyTo(
        const CameraPose(x: 64, y: eyeHeight, z: 60, yaw: 0),
      );
      expect(f.routed, isTrue);
      expect(f.legCount, 4);
      var turned = false;
      while (camera.flying) {
        camera.update(0.02);
        final p = camera.pose;
        if ((p.x - 60).abs() < 0.3 && (p.z - 0).abs() < 0.3) turned = true;
        expect(p.y, lessThanOrEqualTo(Flight.streetFlightHeight + 1e-9));
      }
      expect(turned, isTrue);
      expect(camera.pose.x, 64);
      expect(camera.pose.z, 60);
    });

    test('a climb or a dive takes the direct line', () {
      final camera = FlyCameraController(pose: _origin, network: network);
      final up = camera.flyTo(const CameraPose(x: 0, y: 140, z: -60, yaw: 0));
      expect(up.routed, isFalse);
      expect(up.legCount, 1);
      camera.pose = const CameraPose(x: 0, y: 140, z: -60, yaw: 0);
      final down = camera.flyTo(
        const CameraPose(x: 60, y: eyeHeight, z: 30, yaw: 0),
      );
      expect(down.routed, isFalse);
    });

    test('without a network every flight is direct', () {
      final camera = FlyCameraController(pose: _origin);
      expect(
        camera
            .flyTo(const CameraPose(x: 50, y: eyeHeight, z: 50, yaw: 0))
            .routed,
        isFalse,
      );
    });

    testWidgets('moving: a held key, and the coast after it', (tester) async {
      final camera = _controller();
      expect(camera.moving, isFalse);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(
          _down(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW),
        )
        ..update(0.1);
      expect(camera.moving, isTrue);
      await simulateKeyUpEvent(LogicalKeyboardKey.keyW);
      camera
        ..handleKeyEvent(_up(LogicalKeyboardKey.keyW, PhysicalKeyboardKey.keyW))
        ..update(0.05);
      // Still coasting.
      expect(camera.moving, isTrue);
      for (var i = 0; i < 40; i++) {
        camera.update(0.1);
      }
      expect(camera.moving, isFalse);
    });
  });
}
