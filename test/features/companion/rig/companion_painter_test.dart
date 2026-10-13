import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';

import '../companion_test_utils.dart';

Future<Raster> _paint(CompanionPainter p, Size size) => Raster.of(
  size.width.round(),
  size.height.round(),
  (canvas) => p.paint(canvas, size),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fit', () {
    test('fits the window inside the size, centred', () {
      const size = Size(320, 970);
      final (scale, offset) = CompanionPainter.fit(size, CompanionFraming.full);
      final w = CompanionFraming.full.window;
      expect(scale, closeTo(1, 1e-9));
      final topLeft = Offset(w.left, w.top) * scale + offset;
      final bottomRight = Offset(w.right, w.bottom) * scale + offset;
      expect(topLeft.dx, closeTo(0, 1e-9));
      expect(bottomRight.dx, closeTo(320, 1e-9));
      expect(topLeft.dy + bottomRight.dy, closeTo(970, 1e-9));
    });

    test('the bust is square, so a square avatar uses all of it', () {
      final w = CompanionFraming.bust.window;
      expect(w.width, w.height);
    });
  });

  test('paints her head to toe, in the look it is given', () async {
    const look = CompanionLook.grandma;
    final r = await _paint(
      CompanionPainter(pose: const CompanionPose(), look: look),
      const Size(160, 240),
    );
    expect(r.count(look.palette.dress), greaterThan(500));
    expect(r.count(look.palette.shoe), greaterThan(10));
    expect(r.count(look.palette.hair, tolerance: 12), greaterThan(100));
  });

  test('the bust shows the face larger and leaves the shoes out', () async {
    const look = CompanionLook.grandma;
    const size = Size(200, 200);
    final full = await _paint(
      CompanionPainter(pose: const CompanionPose(), look: look),
      size,
    );
    final bust = await _paint(
      CompanionPainter(
        pose: const CompanionPose(),
        look: look,
        framing: CompanionFraming.bust,
      ),
      size,
    );
    expect(
      bust.count(look.palette.skin),
      greaterThan(full.count(look.palette.skin) * 2),
    );
    expect(bust.count(look.palette.shoe), 0);
  });

  test('a hand to the face draws over the face', () async {
    const look = CompanionLook.grandmaRock;
    const onFace = CompanionPose(
      right: ArmPose(wrist: Offset(40, -150), handAngle: -1.6),
      handInFrontOfFace: true,
    );
    final over = await _paint(
      CompanionPainter(
        pose: onFace,
        look: look,
        framing: CompanionFraming.bust,
      ),
      const Size(200, 200),
    );
    final under = await _paint(
      CompanionPainter(
        pose: const CompanionPose(
          right: ArmPose(wrist: Offset(40, -150), handAngle: -1.6),
        ),
        look: look,
        framing: CompanionFraming.bust,
      ),
      const Size(200, 200),
    );
    expect(
      over.count(look.palette.glove, tolerance: 2),
      greaterThan(under.count(look.palette.glove, tolerance: 2)),
    );
  });

  test(
    'the stage paints her ground; without it the view stays clear',
    () async {
      const size = Size(160, 240);
      final bare = await _paint(
        CompanionPainter(
          pose: const CompanionPose(),
          look: CompanionLook.grandma,
        ),
        size,
      );
      final staged = await _paint(
        CompanionPainter(
          pose: const CompanionPose(),
          look: CompanionLook.grandma,
          stage: true,
        ),
        size,
      );
      expect(bare.at(3, 3), const Color(0xFF000000));
      expect(staged.at(3, 3), isNot(const Color(0xFF000000)));
      // The navy ground: more blue than red.
      final c = staged.at(4, 120);
      expect(c.b, greaterThan(c.r));
    },
  );

  test('an empty size paints nothing and does not throw', () async {
    final r = await Raster.of(4, 4, (canvas) {
      CompanionPainter(
        pose: const CompanionPose(),
        look: CompanionLook.grandma,
      ).paint(canvas, Size.zero);
    });
    expect(r.at(1, 1), const Color(0xFF000000));
  });

  test('repaints only when the pose, look or framing changes', () {
    const pose = CompanionPose();
    final a = CompanionPainter(pose: pose, look: CompanionLook.grandma);
    expect(
      a.shouldRepaint(
        CompanionPainter(pose: pose, look: CompanionLook.grandma),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        CompanionPainter(
          pose: const CompanionPose(blink: 1),
          look: CompanionLook.grandma,
        ),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        CompanionPainter(pose: pose, look: CompanionLook.grandmaRock),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        CompanionPainter(
          pose: pose,
          look: CompanionLook.grandma,
          framing: CompanionFraming.bust,
        ),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        CompanionPainter(pose: pose, look: CompanionLook.grandma, stage: true),
      ),
      isTrue,
    );
  });
}
