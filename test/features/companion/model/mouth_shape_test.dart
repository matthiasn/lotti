import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';

void main() {
  test('blend ends on each shape and passes through the middle', () {
    final a = Viseme.x.shape;
    final d = Viseme.d.shape;
    expect(a.blend(d, 0).open, a.open);
    expect(a.blend(d, 1).open, d.open);
    expect(a.blend(d, 0.5).open, closeTo(d.open / 2, 1e-12));
    expect(
      a.blend(d, 0.5).halfWidth,
      closeTo((a.halfWidth + d.halfWidth) / 2, 1e-12),
    );
  });

  test('the closed shapes are shut and the vowels open', () {
    expect(Viseme.x.shape.open, 0);
    expect(Viseme.a.shape.open, 0);
    expect(Viseme.d.shape.open, greaterThan(Viseme.c.shape.open));
    expect(Viseme.c.shape.open, greaterThan(Viseme.b.shape.open));
  });

  test('only the right shapes pucker, bite or lift the tongue', () {
    expect(Viseme.f.shape.round, 1);
    expect(Viseme.g.shape.bite, 1);
    expect(Viseme.h.shape.tongueUp, 1);
    for (final v in Viseme.values) {
      if (v != Viseme.f && v != Viseme.e) expect(v.shape.round, 0);
      if (v != Viseme.g) expect(v.shape.bite, 0);
    }
  });
}
