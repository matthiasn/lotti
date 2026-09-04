import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

void main() {
  // Facing +X: the 8 m width runs along world Z, the 2 m depth along X.
  const wall = Solid(
    footprint: Footprint(
      x: 10,
      z: 0,
      facingRadians: math.pi / 2,
      width: 8,
      depth: 2,
    ),
    top: 12,
  );

  test('contains a point in the box, turned with the footprint', () {
    expect(wall.contains(10, 5, 3.9), isTrue);
    expect(wall.contains(10, 5, 4.1), isFalse);
    expect(wall.contains(10.9, 5, 0), isTrue);
    expect(wall.contains(11.1, 5, 0), isFalse);
    expect(wall.contains(10, 11.9, 0), isTrue);
    expect(wall.contains(10, 12.1, 0), isFalse);
    expect(wall.contains(10, -0.1, 0), isFalse);
  });

  test('clearance grows the box on every side', () {
    expect(wall.contains(10, 5, 4.4, clearance: 0.5), isTrue);
    expect(wall.contains(11.4, 5, 0, clearance: 0.5), isTrue);
    expect(wall.contains(10, 12.4, 0, clearance: 0.5), isTrue);
    expect(wall.contains(10, -0.4, 0, clearance: 0.5), isTrue);
    expect(wall.contains(10, 5, 4.6, clearance: 0.5), isFalse);
    expect(wall.contains(10, 12.6, 0, clearance: 0.5), isFalse);
  });

  test('a solid above eye level is for flights, not the walker', () {
    const footprint = Footprint(
      x: 0,
      z: 0,
      facingRadians: 0,
      width: 16,
      depth: 0.8,
    );
    const sign = Solid(footprint: footprint, bottom: 4.5, top: 13.5);
    expect(sign.atWalkHeight, isFalse);
    expect(sign.contains(0, eyeHeight, 0), isFalse);
    expect(sign.contains(0, 9, 0), isTrue);
    expect(wall.atWalkHeight, isTrue);
    const low = Solid(footprint: footprint, bottom: eyeHeight - 0.1, top: 3);
    expect(low.atWalkHeight, isTrue);
  });
}
