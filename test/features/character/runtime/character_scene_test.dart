import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  group('CharacterScene', () {
    test('frameAt resolves a world transform for every bone', () {
      final rig = buildCatInSuitRig();
      final scene = CharacterScene(rig);
      final frame = scene.frameAt(clip: CatClips.walk, timeSeconds: 0.4);
      expect(frame.world.length, rig.bones.length);
      for (final bone in rig.bones) {
        expect(frame.world.containsKey(bone.id), isTrue);
      }
    });

    test('locomotionX advances with a constant-speed clip (run)', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final frame = scene.frameAt(clip: CatClips.run, timeSeconds: 2);
      expect(
        frame.locomotionX,
        closeTo(CatClips.run.locomotionSpeed * 2, 1e-9),
      );
    });

    test('foot-locked walk travel advances one stride per cycle', () {
      final scene = CharacterScene(buildCatInSuitRig());
      // duration is 1s, so t=1 is one full cycle and t=2 two cycles; foot-lock
      // travel is periodic, so two cycles cover exactly twice the stride.
      final oneCycle = scene.locomotionOffset(CatClips.walk, 1);
      final twoCycles = scene.locomotionOffset(CatClips.walk, 2);
      expect(oneCycle, greaterThan(0));
      expect(twoCycles, closeTo(2 * oneCycle, 1e-6));
    });

    test('contact spans damp support-foot drift for one-shot clips', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final span in CatClips.kick.contactSpans) {
        final lockedAnchor = _supportPoint(
          scene,
          CatClips.kick,
          span.bone,
          span.start * CatClips.kick.duration,
        );
        final rawAnchor = _rawSupportPoint(
          scene,
          CatClips.kick,
          span.bone,
          span.start * CatClips.kick.duration,
        );

        var lockedDrift = 0.0;
        var rawDrift = 0.0;
        for (var i = 1; i <= 8; i++) {
          final p = span.start + (span.end - span.start) * i / 9;
          lockedDrift = math.max(
            lockedDrift,
            _distance(
              _supportPoint(
                scene,
                CatClips.kick,
                span.bone,
                p * CatClips.kick.duration,
              ),
              lockedAnchor,
            ),
          );
          rawDrift = math.max(
            rawDrift,
            _distance(
              _rawSupportPoint(
                scene,
                CatClips.kick,
                span.bone,
                p * CatClips.kick.duration,
              ),
              rawAnchor,
            ),
          );
        }

        expect(
          lockedDrift,
          lessThan(rawDrift * 0.45),
          reason:
              'kick support correction should visibly reduce '
              '${span.bone} slide without hard-locking into a pop',
        );
        expect(
          lockedDrift,
          lessThan(12),
          reason: 'kick support foot residual slide should stay subtle',
        );
      }
    });

    test('looping performance contact spans softly damp foot drift', () {
      final scene = CharacterScene(buildCatInSuitRig());
      var lockedDrift = 0.0;
      var rawDrift = 0.0;

      for (final span in CatClips.dance.contactSpans) {
        final mid = (span.start + span.end) / 2;
        final width = (span.end - span.start) / 3;
        final lockedAnchor = _supportPoint(
          scene,
          CatClips.dance,
          span.bone,
          mid * CatClips.dance.duration,
        );
        final rawAnchor = _rawSupportPoint(
          scene,
          CatClips.dance,
          span.bone,
          mid * CatClips.dance.duration,
        );

        for (var i = -3; i <= 3; i++) {
          final p = mid + width * i / 6;
          lockedDrift = math.max(
            lockedDrift,
            _distance(
              _supportPoint(
                scene,
                CatClips.dance,
                span.bone,
                p * CatClips.dance.duration,
              ),
              lockedAnchor,
            ),
          );
          rawDrift = math.max(
            rawDrift,
            _distance(
              _rawSupportPoint(
                scene,
                CatClips.dance,
                span.bone,
                p * CatClips.dance.duration,
              ),
              rawAnchor,
            ),
          );
        }
      }

      expect(rawDrift, greaterThan(6));
      expect(
        lockedDrift,
        lessThan(rawDrift * 0.7),
        reason:
            'looped performance contact correction should visibly reduce '
            'support-foot drift without hard-locking the whole cycle',
      );
      expect(
        lockedDrift,
        lessThan(3.2),
        reason:
            'dance support feet should stay close enough to read planted '
            'during the groove holds',
      );
    });

    test(
      'dance keeps broad contact holds and loop seam physically continuous',
      () {
        final scene = CharacterScene(buildCatInSuitRig());

        for (final span in CatClips.dance.contactSpans) {
          final spanLength = span.end - span.start;
          final anchorP = span.start + spanLength * 0.18;
          final anchor = _supportPoint(
            scene,
            CatClips.dance,
            span.bone,
            anchorP * CatClips.dance.duration,
          );

          var drift = 0.0;
          for (var i = 2; i <= 6; i++) {
            final p = span.start + spanLength * i / 8;
            drift = math.max(
              drift,
              _distance(
                _supportPoint(
                  scene,
                  CatClips.dance,
                  span.bone,
                  p * CatClips.dance.duration,
                ),
                anchor,
              ),
            );
          }

          expect(
            drift,
            lessThan(4.2),
            reason:
                '${span.bone} should hold a stable contact through most of '
                'the dance beat before the next pickup',
          );
        }

        final lastSpan = CatClips.dance.contactSpans.last;
        final seamBefore = _supportPoint(
          scene,
          CatClips.dance,
          lastSpan.bone,
          CatClips.dance.duration * 31 / 32,
        );
        final seamAfter = _supportPoint(
          scene,
          CatClips.dance,
          lastSpan.bone,
          CatClips.dance.duration,
        );
        expect(
          _distance(seamBefore, seamAfter),
          lessThan(4.2),
          reason:
              'the loop-pickup support foot should roll into frame 1 instead of '
              'visibly popping to a new floor point',
        );
        final seamCarry = _supportPoint(
          scene,
          CatClips.dance,
          lastSpan.bone,
          CatClips.dance.duration / 16,
        );
        expect(
          _distance(seamBefore, seamCarry),
          lessThan(4.2),
          reason:
              'matching first/last loop contacts should behave as one '
              'continuous support hold across the wrap',
        );
      },
    );

    test('dance shifts visible torso mass toward the active support foot', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final p in [1 / 8, 3 / 8, 5 / 8, 7 / 8]) {
        final span = _spanAt(CatClips.dance, p);
        final frame = scene.frameAt(
          clip: CatClips.dance,
          timeSeconds: p * CatClips.dance.duration,
        );
        final support = _supportPoint(
          scene,
          CatClips.dance,
          span.bone,
          p * CatClips.dance.duration,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final torso = frame.world[CatBones.torso]!.origin;

        expect(
          (torso.x - support.x).abs(),
          lessThan((hip.x - support.x).abs()),
          reason:
              'the visible torso mass should move toward ${span.bone} on '
              'dance support beat $p',
        );
      }
    });

    test('is deterministic: identical scenes resolve identical frames', () {
      final a = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(),
      );
      final b = CharacterScene(
        buildCatInSuitRig(),
        autonomic: AutonomicLayer(),
      );
      final fa = a.frameAt(clip: CatClips.run, timeSeconds: 0.7);
      final fb = b.frameAt(clip: CatClips.run, timeSeconds: 0.7);
      expect(fa.world['head'], fb.world['head']);
      expect(fa.world['hand.L'], fb.world['hand.L']);
      expect(fa.face.eyeOpenLeft, fb.face.eyeOpenLeft);
    });

    test('performance clips keep the head stable over the moving torso', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [CatClips.walk, CatClips.kick, CatClips.dance]) {
        final headStats = _rotationStats(scene, clip, CatBones.head);
        final torsoStats = _rotationStats(scene, clip, CatBones.torso);
        final headRange = headStats.max - headStats.min;
        final torsoRange = torsoStats.max - torsoStats.min;

        expect(
          headRange,
          lessThan(torsoRange * 0.55),
          reason:
              '${clip.name} should counter-rotate the head instead of letting '
              'the face wobble with the torso',
        );
        expect(
          headRange,
          lessThan(0.12),
          reason: '${clip.name} head wobble should stay visually subtle',
        );
      }
    });

    test('blink reaches the face via the autonomic layer', () {
      final scene = CharacterScene(buildCatInSuitRig());
      var minOpen = 1.0;
      for (var i = 0; i < 600; i++) {
        final f = scene.frameAt(clip: CatClips.idle, timeSeconds: i * 0.05);
        if (f.face.eyeOpenLeft < minOpen) minOpen = f.face.eyeOpenLeft;
      }
      expect(minOpen, lessThan(0.1));
    });
  });
}

GroundSpan _spanAt(Clip clip, double p) {
  for (final span in clip.contactSpans) {
    if (p >= span.start && p < span.end) return span;
  }
  return clip.contactSpans.last;
}

({double min, double max}) _rotationStats(
  CharacterScene scene,
  Clip clip,
  String boneId,
) {
  const samples = 48;
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (var i = 0; i < samples; i++) {
    final frame = scene.frameAt(
      clip: clip,
      timeSeconds: clip.duration * i / samples,
    );
    final rotation = _worldRotation(frame.world[boneId]!);
    min = math.min(min, rotation);
    max = math.max(max, rotation);
  }
  return (min: min, max: max);
}

double _worldRotation(Affine2D transform) =>
    math.atan2(transform.b, transform.a);

({double x, double y}) _supportPoint(
  CharacterScene scene,
  Clip clip,
  String boneId,
  double timeSeconds,
) {
  final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
  final transform = frame.world[boneId]!;
  final drawable = scene.rig.bone(boneId)!.drawable!;
  return transform.transformPoint(
    drawable.dx,
    drawable.dy + drawable.height / 2,
  );
}

({double x, double y}) _rawSupportPoint(
  CharacterScene scene,
  Clip clip,
  String boneId,
  double timeSeconds,
) {
  final world = scene.solver.solve(scene.evaluator.evaluate(clip, timeSeconds));
  final transform = world[boneId]!;
  final drawable = scene.rig.bone(boneId)!.drawable!;
  return transform.transformPoint(
    drawable.dx,
    drawable.dy + drawable.height / 2,
  );
}

double _distance(({double x, double y}) a, ({double x, double y}) b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
