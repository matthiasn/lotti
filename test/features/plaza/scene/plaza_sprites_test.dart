import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/plaza_sprites.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test(
    'sprite sizing reruns only for a changed eye, viewport or projection',
    () {
      final view = PlazaSpriteView();
      final eye = Vector3(1, 2, 3);
      const size = Size(800, 600);
      const fov = math.pi / 3;
      expect(view.update(eye, size, fov), isTrue);
      final scale = view.metersPerPixel;
      expect(scale, closeTo(2 * math.tan(fov / 2) / 600, 1e-12));
      expect(view.update(Vector3.copy(eye), size, fov), isFalse);
      eye.x++;
      expect(view.update(eye, size, fov), isTrue);
      expect(view.update(eye, const Size(800, 1200), fov), isTrue);
      expect(view.metersPerPixel, closeTo(scale / 2, 1e-12));
      expect(view.update(eye, const Size(800, 1200), fov / 2), isTrue);
      expect(view.metersPerPixel, lessThan(scale / 2));
    },
  );

  const stride = BillboardGeometry.floatsPerInstance;

  test(
    'bulbs occupy separate records with copied world positions and colours',
    () {
      final data = Float32List(2 * stride);
      final bulbs = PlazaLightBuffer(data);
      final center = Vector3(10, 20, 30);
      final color = Vector4(1, 2, 3, 0.5);
      bulbs
        ..add(center, size: 0.25, color: color)
        ..add(Vector3(40, 50, 60), size: 0.5, color: Vector4.all(1));
      center.x = 99;
      color.y = 99;
      expect(bulbs.count, 2);
      expect(data.take(stride), [
        10,
        20,
        30,
        0.25,
        0.25,
        0,
        1,
        2,
        3,
        0.5,
        0,
        0,
        0,
        0,
      ]);
      expect(data.skip(stride), [
        40,
        50,
        60,
        0.5,
        0.5,
        0,
        1,
        1,
        1,
        1,
        0,
        0,
        0,
        0,
      ]);
    },
  );

  test('animation updates only its bulb size and HDR colour', () {
    final data = Float32List.fromList(
      List.generate(2 * stride, (i) => i.toDouble()),
    );
    final original = List<double>.of(data);
    PlazaLightBuffer(data).write(
      1,
      size: 0.5,
      color: Vector4(1, 2, 3, 1),
      alpha: 0.25,
      boost: 2,
    );
    final expected = [...original];
    expected[stride + 3] = 0.5;
    expected[stride + 4] = 0.5;
    expected[stride + 6] = 2;
    expected[stride + 7] = 4;
    expected[stride + 8] = 6;
    expected[stride + 9] = 0.25;
    expect(data, expected);
  });

  for (final failCommit in [false, true]) {
    test(
      'bounds cover maximum sizes and restore display sizes, failure=$failCommit',
      () {
        final data = Float32List(2 * stride);
        final bulbs = PlazaLightBuffer(data)
          ..add(Vector3(1, 2, 3), size: 0.25, color: Vector4.all(1))
          ..add(Vector3(4, 5, 6), size: 0.125, color: Vector4.all(0.5));
        final original = List<double>.of(data);
        var commits = 0;
        void commit() => bulbs.commitBounds((count) {
          commits++;
          expect(count, 2);
          for (var i = 0; i < count; i++) {
            expect(data[i * stride + 3], 0.5);
            expect(data[i * stride + 4], 0.5);
            expect(data[i * stride], original[i * stride]);
          }
          if (failCommit) throw StateError('upload failed');
        }, pad: 0.5);
        if (failCommit) {
          expect(commit, throwsStateError);
        } else {
          commit();
        }
        expect(commits, 1);
        expect(data, original);
      },
    );
  }

  test('empty buffer commits zero live instances', () {
    final bulbs = PlazaLightBuffer(Float32List(0));
    int? committed;
    bulbs.commitBounds((count) => committed = count, pad: 0.5);
    expect(committed, 0);
    expect(bulbs.count, 0);
  });
}
