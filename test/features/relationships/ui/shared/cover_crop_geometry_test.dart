import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/ui/shared/cover_crop_geometry.dart';

/// Any picture a phone or a desktop could hand the picker, any square the
/// crop surface could be laid out in, any crop the model allows.
extension _AnyCrop on glados.Any {
  glados.Generator<Size> get pictureSize => glados.any.combine2<int, int, Size>(
    glados.IntAnys(this).intInRange(1, 4000),
    glados.IntAnys(this).intInRange(1, 4000),
    (w, h) => Size(w.toDouble(), h.toDouble()),
  );

  glados.Generator<double> get diameter =>
      glados.IntAnys(this).intInRange(1, 400).map((d) => d.toDouble());

  glados.Generator<Size> get viewportSize =>
      glados.any.combine2<int, int, Size>(
        glados.IntAnys(this).intInRange(1, 800),
        glados.IntAnys(this).intInRange(1, 400),
        (w, h) => Size(w.toDouble(), h.toDouble()),
      );

  glados.Generator<AvatarCrop> get crop =>
      glados.any.combine3<int, int, int, AvatarCrop>(
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        (x, y, s) => AvatarCrop(
          x: x / 1000,
          y: y / 1000,
          scale:
              minAvatarCropScale +
              (maxAvatarCropScale - minAvatarCropScale) * s / 1000,
        ),
      );
}

void main() {
  final square = CoverCropGeometry.circle(
    imageSize: const Size(400, 200),
    diameter: 100,
  );

  group('coveredSize', () {
    test('cover-fits: the short side meets the square, the long side '
        'overflows', () {
      expect(square.coveredSize, const Size(200, 100));
      final portrait = CoverCropGeometry.circle(
        imageSize: const Size(100, 300),
        diameter: 60,
      );
      expect(portrait.coveredSize, const Size(60, 180));
    });

    test('a square picture covers the square exactly', () {
      final g = CoverCropGeometry.circle(
        imageSize: const Size(50, 50),
        diameter: 80,
      );
      expect(g.coveredSize, const Size(80, 80));
      expect(g.overflow(1), Offset.zero);
    });

    test('a degenerate picture size is treated as the square rather than '
        'dividing by zero', () {
      final g = CoverCropGeometry.circle(imageSize: Size.zero, diameter: 80);
      expect(g.coveredSize, const Size(80, 80));
    });
  });

  group('overflow', () {
    test('is the room a drag has, per axis, and grows with the zoom', () {
      expect(square.overflow(1), const Offset(100, 0));
      expect(square.overflow(2), const Offset(300, 100));
    });
  });

  group('panBy', () {
    test('the picture follows the finger: dragging left shows more of the '
        'right', () {
      final moved = square.panBy(const AvatarCrop(), const Offset(-25, 0));
      // 25 px over 100 px of room is a quarter of the way to the right edge.
      expect(moved.x, closeTo(0.75, 1e-9));
      expect(moved.y, 0.5, reason: 'no vertical room at the widest zoom');
    });

    test('stops at the edge instead of showing past it', () {
      final moved = square.panBy(const AvatarCrop(), const Offset(-500, 0));
      expect(moved.x, 1);
    });

    test('an axis with no overflow is left alone, not snapped', () {
      final moved = square.panBy(
        const AvatarCrop(y: 0.2),
        const Offset(0, 40),
      );
      expect(moved.y, 0.2);
    });

    test('at a deeper zoom the same drag moves less, because there is more '
        'room', () {
      final wide = square.panBy(const AvatarCrop(), const Offset(-25, 0));
      final zoomed = square.panBy(
        const AvatarCrop(scale: 2),
        const Offset(-25, 0),
      );
      expect(zoomed.x - 0.5, lessThan(wide.x - 0.5));
      expect(zoomed.x, closeTo(0.5 + 25 / 300, 1e-9));
    });
  });

  group('zoomBy', () {
    test('multiplies the scale and keeps the alignment', () {
      const crop = AvatarCrop(x: 0.2, y: 0.9, scale: 1.5);
      final zoomed = CoverCropGeometry.zoomBy(crop, 2);
      expect(zoomed.scale, 3);
      expect(zoomed.x, 0.2);
      expect(zoomed.y, 0.9);
    });

    test('is clamped to the range the surface offers', () {
      expect(
        CoverCropGeometry.zoomBy(const AvatarCrop(scale: 3), 10).scale,
        maxAvatarCropScale,
      );
      expect(
        CoverCropGeometry.zoomBy(const AvatarCrop(scale: 1.2), 0.1).scale,
        minAvatarCropScale,
      );
    });
  });

  group('visibleFraction', () {
    test('centred at the widest zoom shows the middle of the long side and '
        'all of the short one', () {
      final seen = square.visibleFraction(const AvatarCrop());
      expect(seen.left, closeTo(0.25, 1e-9));
      expect(seen.right, closeTo(0.75, 1e-9));
      expect(seen.top, closeTo(0, 1e-9));
      expect(seen.bottom, closeTo(1, 1e-9));
    });

    test('the alignment slides the window along the long side', () {
      expect(square.visibleFraction(const AvatarCrop(x: 0)).left, 0);
      expect(square.visibleFraction(const AvatarCrop(x: 1)).right, 1);
    });

    test('zooming about a corner keeps that corner in view', () {
      final seen = square.visibleFraction(
        const AvatarCrop(x: 0, y: 0, scale: 4),
      );
      expect(seen.left, 0);
      expect(seen.top, 0);
      expect(seen.width, closeTo(0.5 / 4, 1e-9));
    });
  });

  group('a wide viewport — the banner strip', () {
    const strip = CoverCropGeometry(
      imageSize: Size(160, 160),
      viewport: Size(400, 100),
    );

    test('a square picture cover-fitted into a wide strip fills the width '
        'and overflows only vertically', () {
      expect(strip.coveredSize, const Size(400, 400));
      expect(strip.overflow(1), const Offset(0, 300));
    });

    test('only a picture wider than the strip has horizontal room, which is '
        'what a reposition drags against', () {
      const exact = CoverCropGeometry(
        imageSize: Size(1200, 300),
        viewport: Size(400, 100),
      );
      expect(exact.overflow(1), Offset.zero);
      const wide = CoverCropGeometry(
        imageSize: Size(1600, 300),
        viewport: Size(400, 100),
      );
      const room = 400 * 4 / 3 - 400;
      expect(wide.overflow(1).dx, closeTo(room, 1e-9));
      expect(wide.overflow(1).dy, 0);
      final moved = wide.panBy(const AvatarCrop(), const Offset(-40, 0));
      expect(moved.x, closeTo(0.5 + 40 / room, 1e-9));
      expect(moved.y, 0.5, reason: 'no vertical room');
    });

    test('the visible window is the middle of a tall picture at rest', () {
      final seen = strip.visibleFraction(const AvatarCrop());
      expect(seen.left, 0);
      expect(seen.right, 1);
      expect(seen.top, closeTo(0.375, 1e-9));
      expect(seen.bottom, closeTo(0.625, 1e-9));
    });
  });

  group('properties', () {
    glados.Glados3(
      glados.any.pictureSize,
      glados.any.viewportSize,
      glados.any.crop,
      glados.ExploreConfig(numRuns: 400),
    ).test('a rectangle is never empty either — the banner strip', (
      Size picture,
      Size viewport,
      AvatarCrop crop,
    ) {
      final seen = CoverCropGeometry(
        imageSize: picture,
        viewport: viewport,
      ).visibleFraction(crop);
      expect(seen.left, greaterThanOrEqualTo(-1e-6));
      expect(seen.top, greaterThanOrEqualTo(-1e-6));
      expect(seen.right, lessThanOrEqualTo(1 + 1e-6));
      expect(seen.bottom, lessThanOrEqualTo(1 + 1e-6));
    }, tags: 'glados');

    glados.Glados3(
      glados.any.pictureSize,
      glados.any.diameter,
      glados.any.crop,
      glados.ExploreConfig(numRuns: 400),
    ).test('the circle is never empty: every crop in range shows picture '
        'everywhere in the square, for any picture and any square', (
      Size picture,
      double diameter,
      AvatarCrop crop,
    ) {
      final g = CoverCropGeometry.circle(
        imageSize: picture,
        diameter: diameter,
      );
      final seen = g.visibleFraction(crop);
      const eps = 1e-6;
      expect(seen.left, greaterThanOrEqualTo(-eps));
      expect(seen.top, greaterThanOrEqualTo(-eps));
      expect(seen.right, lessThanOrEqualTo(1 + eps));
      expect(seen.bottom, lessThanOrEqualTo(1 + eps));
      expect(seen.width, greaterThan(0));
      expect(seen.height, greaterThan(0));
    }, tags: 'glados');

    glados.Glados3(
      glados.any.pictureSize,
      glados.any.diameter,
      glados.any.crop,
      glados.ExploreConfig(numRuns: 300),
    ).test('a drag never leaves the range, and dragging back returns home '
        'when it did not hit an edge', (picture, diameter, crop) {
      final g = CoverCropGeometry.circle(
        imageSize: picture,
        diameter: diameter,
      );
      const delta = Offset(7, -3);
      final there = g.panBy(crop, delta);
      expect(there.x, inInclusiveRange(0, 1));
      expect(there.y, inInclusiveRange(0, 1));
      final back = g.panBy(there, -delta);
      final room = g.overflow(crop.scale);
      // Only when neither leg was clamped is the round trip exact.
      final clampedX =
          room.dx > 0 &&
          (there.x == 0 || there.x == 1 || crop.x == 0 || crop.x == 1);
      final clampedY =
          room.dy > 0 &&
          (there.y == 0 || there.y == 1 || crop.y == 0 || crop.y == 1);
      if (!clampedX) expect(back.x, closeTo(crop.x, 1e-6));
      if (!clampedY) expect(back.y, closeTo(crop.y, 1e-6));
    }, tags: 'glados');

    glados.Glados2(
      glados.any.crop,
      glados.any.double,
      glados.ExploreConfig(numRuns: 300),
    ).test('zoom lands in range and never touches the alignment', (
      crop,
      factor,
    ) {
      final zoomed = CoverCropGeometry.zoomBy(crop, factor);
      expect(
        zoomed.scale,
        inInclusiveRange(minAvatarCropScale, maxAvatarCropScale),
      );
      expect(zoomed.x, crop.x);
      expect(zoomed.y, crop.y);
    }, tags: 'glados');
  });
}
