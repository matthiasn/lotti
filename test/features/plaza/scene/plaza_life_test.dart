import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_life.dart';
import 'package:vector_math/vector_math.dart';

import '../plaza_fixtures.dart';

void main() {
  final plan = StreetLayout(
    projectSeed: 1337,
  ).plan(syntheticPlazaTasks(count: 90));
  const stride = BillboardGeometry.floatsPerInstance;

  test('bounded penguins stay on roads and reuse storage while moving', () {
    final data = Float32List(5 * stride);
    final buffer = PlazaLifeBuffer(
      plan: plan,
      roadWidth: 18,
      taskCount: 90,
      data: data,
      maxCreatures: 5,
    );
    expect(buffer.count, 5);
    late Vector3 minimum;
    late Vector3 maximum;
    buffer
      ..reserveBounds((min, max) {
        minimum = min;
        maximum = max;
      })
      ..update(0, Vector3.zero());
    final before = Float32List.fromList(data);
    for (var frame = 1; frame <= 100; frame++) {
      buffer.update(frame.toDouble(), Vector3.zero());
      for (var i = 0; i < buffer.count; i++) {
        final x = data[i * stride];
        final z = data[i * stride + 2];
        expect(x, inInclusiveRange(minimum.x, maximum.x));
        expect(z, inInclusiveRange(minimum.z, maximum.z));
        expect(
          plan.segments.any((road) {
            if (road.isGap) return false;
            final (lateral, along) = worldToFrame(
              road.startX,
              road.startZ,
              road.headingRadians,
              x,
              z,
            );
            return lateral.abs() < 9 && along >= 0 && along <= road.length;
          }),
          isTrue,
        );
      }
    }
    expect(buffer.data, same(data));
    expect(data, isNot(orderedEquals(before)));
    buffer.update(0, Vector3.zero());
    expect(data, orderedEquals(before));
    buffer.update(0, Vector3.all(10000));
    expect([
      for (var i = 0; i < buffer.count; i++) data[i * stride + 9],
    ], everyElement(0));
  });

  test('empty worlds and a zero budget have no ambient work', () {
    final data = Float32List(0);
    for (final taskCount in [0, 90]) {
      final buffer = PlazaLifeBuffer(
        plan: plan,
        roadWidth: 18,
        taskCount: taskCount,
        data: data,
        maxCreatures: 0,
      )..update(20, Vector3.zero());
      expect(buffer.count, 0);
      expect(buffer.data, isEmpty);
    }
    expect(
      () =>
          PlazaLifeBuffer(plan: plan, roadWidth: 18, taskCount: 90, data: data),
      throwsArgumentError,
    );
  });
}
