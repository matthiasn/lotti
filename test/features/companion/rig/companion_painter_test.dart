import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/companion_animator.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

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

    test("the aspect ratio is the window's width over its height", () {
      for (final framing in CompanionFraming.values) {
        final w = framing.window;
        expect(framing.aspectRatio, closeTo(w.width / w.height, 1e-12));
      }
      expect(CompanionFraming.bust.aspectRatio, 1);
    });
  });

  group('full framing', () {
    const full = CompanionFraming.full;

    test('keeps her feet in, down to the floor she stands on', () {
      // The floor is y = 0; her shoes rest on it.
      expect(full.window.bottom, greaterThan(0));
    });

    // A hand is drawn around its wrist; this is room for the palm and fingers.
    const handReach = 25.0;

    for (final gesture in <GestureName?>[null, ...GestureName.values]) {
      test(
        'keeps both hands in view ${gesture == null ? 'at rest' : 'in ${gesture.name}'}',
        () {
          final animator = CompanionAnimator(seed: 3);
          if (gesture != null) animator.play(gesture);
          // Six seconds covers every gesture's phases and its settle.
          for (var i = 0; i < 6 * 60; i++) {
            final pose = animator.step(1 / 60);
            final frame = RigFrame(pose);
            for (final (arm, side) in [(pose.left, -1), (pose.right, 1)]) {
              final wrist = frame.armSpine(arm, side).last;
              expect(
                full.window.deflate(handReach).contains(wrist),
                isTrue,
                reason: 'wrist $wrist at ${i / 60}s',
              );
            }
          }
        },
      );
    }
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

  test('paints an animal with its tail, behind the dress', () async {
    const look = CompanionLook.redPanda;
    final r = await _paint(
      CompanionPainter(pose: const CompanionPose(), look: look),
      const Size(160, 240),
    );
    expect(r.count(look.palette.tailRingColor, tolerance: 12), greaterThan(40));
    expect(r.count(look.palette.dress), greaterThan(500));
    expect(r.count(look.palette.shoe), 0);
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

  group('the stage', () {
    const size = Size(160, 240);
    const grey = Color(0xFF808080);

    test('she alone leaves the view clear, and casts her floor shadow on '
        'the stage', () async {
      Future<Raster> paint({required bool stage}) => Raster.of(
        160,
        240,
        background: grey,
        (canvas) => CompanionPainter(
          pose: const CompanionPose(),
          look: CompanionLook.grandma,
          stage: stage,
        ).paint(canvas, size),
      );
      final bare = await paint(stage: false);
      final staged = await paint(stage: true);
      // No ground and no vignette: those are the stage painters' job.
      expect(staged.at(3, 3), grey);
      expect(staged.at(156, 236), grey);
      // Beside her feet (the floor is at y ≈ 233 here, her centre x = 80).
      expect(bare.at(115, 234), grey);
      expect(staged.at(115, 234).r, lessThan(grey.r));
    });

    test('the ground fills the view, navy, behind her', () async {
      final r = await Raster.of(
        160,
        240,
        (canvas) => const CompanionStageGround().paint(canvas, size),
      );
      expect(r.at(3, 3), isNot(const Color(0xFF000000)));
      final c = r.at(4, 120);
      expect(c.b, greaterThan(c.r));
    });

    test('the vignette darkens the edges, never the centre', () async {
      final r = await Raster.of(
        160,
        240,
        background: grey,
        (canvas) => const CompanionStageVignette().paint(canvas, size),
      );
      expect(r.at(80, 120), grey);
      expect(r.at(1, 1).r, lessThan(grey.r));
    });

    test('an empty size paints no stage', () async {
      final r = await Raster.of(4, 4, (canvas) {
        const CompanionStageGround().paint(canvas, Size.zero);
        const CompanionStageVignette().paint(canvas, Size.zero);
      });
      expect(r.at(1, 1), const Color(0xFF000000));
    });

    test('the ground repaints only for a new framing; the vignette never', () {
      const ground = CompanionStageGround();
      expect(ground.shouldRepaint(const CompanionStageGround()), isFalse);
      expect(
        ground.shouldRepaint(
          const CompanionStageGround(framing: CompanionFraming.bust),
        ),
        isTrue,
      );
      expect(
        const CompanionStageVignette().shouldRepaint(
          const CompanionStageVignette(),
        ),
        isFalse,
      );
    });
  });

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
