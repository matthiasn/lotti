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
      final frame = scene.frameAt(clip: CatClips.shaku, timeSeconds: 0.4);
      expect(frame.world.length, rig.bones.length);
      for (final bone in rig.bones) {
        expect(frame.world.containsKey(bone.id), isTrue);
      }
    });

    test('public character clips animate in place', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in CatClips.all) {
        final frame = scene.frameAt(clip: clip, timeSeconds: 2);
        expect(frame.locomotionX, 0, reason: '${clip.name} should not travel');
        expect(
          scene.locomotionOffset(clip, 2),
          0,
          reason: '${clip.name} should stay centred for the dance showcase',
        );
      }
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
      var lockedVerticalDrift = 0.0;
      var rawVerticalDrift = 0.0;
      var lockedLateralDrift = 0.0;

      for (final span in CatClips.shaku.contactSpans) {
        final mid = (span.start + span.end) / 2;
        final width = (span.end - span.start) / 3;
        final lockedAnchor = _supportPoint(
          scene,
          CatClips.shaku,
          span.bone,
          mid * CatClips.shaku.duration,
        );
        final rawAnchor = _rawSupportPoint(
          scene,
          CatClips.shaku,
          span.bone,
          mid * CatClips.shaku.duration,
        );

        for (var i = -3; i <= 3; i++) {
          final p = mid + width * i / 6;
          final locked = _supportPoint(
            scene,
            CatClips.shaku,
            span.bone,
            p * CatClips.shaku.duration,
          );
          final raw = _rawSupportPoint(
            scene,
            CatClips.shaku,
            span.bone,
            p * CatClips.shaku.duration,
          );
          lockedVerticalDrift = math.max(
            lockedVerticalDrift,
            (locked.y - lockedAnchor.y).abs(),
          );
          rawVerticalDrift = math.max(
            rawVerticalDrift,
            (raw.y - rawAnchor.y).abs(),
          );
          lockedLateralDrift = math.max(
            lockedLateralDrift,
            (locked.x - lockedAnchor.x).abs(),
          );
        }
      }

      expect(rawVerticalDrift, greaterThan(4));
      expect(
        lockedVerticalDrift,
        lessThan(rawVerticalDrift * 0.45),
        reason:
            'looped performance contact correction should visibly reduce '
            'vertical support-foot drift without hard-locking lateral groove',
      );
      expect(
        lockedVerticalDrift,
        lessThan(2.8),
        reason:
            'dance support feet should stay vertically grounded during the '
            'lower groove holds',
      );
      expect(
        lockedLateralDrift,
        lessThan(38),
        reason:
            'dance support feet may glide laterally with the groove, but not '
            'snap across the body',
      );
    });

    test('the opt-in support-foot world anchor plants the foot (low skate)', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const dur = 6.0;
      // Left foot supports bar 1 (grounded frames 0-16); sample its world-x
      // across mid-stance against the plant point.
      double driftOf(Clip clip) {
        final anchor = _supportPoint(scene, clip, CatBones.footL, 6 / 32 * dur);
        var drift = 0.0;
        for (final f in const [4, 6, 8, 10, 12]) {
          final p = _supportPoint(scene, clip, CatBones.footL, f / 32 * dur);
          drift = math.max(drift, (p.x - anchor.x).abs());
        }
        return drift;
      }

      // Shaku opts into the support-foot world anchor; with the deleted generic
      // dance baseline gone, this test only guards the shipped skate budget.
      expect(
        driftOf(CatClips.shaku),
        lessThan(20),
        reason: 'the planted support foot should barely drift laterally',
      );
    });

    test(
      'dance keeps broad contact holds grounded and loop seam continuous',
      () {
        final scene = CharacterScene(buildCatInSuitRig());

        for (final span in CatClips.shaku.contactSpans) {
          final spanLength = span.end - span.start;
          final anchorP = span.start + spanLength * 0.18;
          final anchor = _supportPoint(
            scene,
            CatClips.shaku,
            span.bone,
            anchorP * CatClips.shaku.duration,
          );

          var verticalDrift = 0.0;
          var lateralDrift = 0.0;
          for (var i = 2; i <= 6; i++) {
            final p = span.start + spanLength * i / 8;
            final support = _supportPoint(
              scene,
              CatClips.shaku,
              span.bone,
              p * CatClips.shaku.duration,
            );
            verticalDrift = math.max(
              verticalDrift,
              (support.y - anchor.y).abs(),
            );
            lateralDrift = math.max(
              lateralDrift,
              (support.x - anchor.x).abs(),
            );
          }

          expect(
            verticalDrift,
            lessThan(3.5),
            reason:
                '${span.bone} should stay vertically grounded through most '
                'of the lower dance beat before the next pickup',
          );
          expect(
            lateralDrift,
            lessThan(38),
            reason:
                '${span.bone} can travel laterally with the groove, but '
                'should not snap across the body during a contact hold',
          );
        }

        final lastSpan = CatClips.shaku.contactSpans.last;
        final seamBefore = _supportPoint(
          scene,
          CatClips.shaku,
          lastSpan.bone,
          CatClips.shaku.duration * 31 / 32,
        );
        final seamAfter = _supportPoint(
          scene,
          CatClips.shaku,
          lastSpan.bone,
          CatClips.shaku.duration,
        );
        expect(
          (seamBefore.y - seamAfter.y).abs(),
          lessThan(4.5),
          reason:
              'the loop-pickup support foot should stay vertically grounded '
              'instead of popping off the floor after the low hook',
        );
        final seamCarry = _supportPoint(
          scene,
          CatClips.shaku,
          lastSpan.bone,
          CatClips.shaku.duration / 16,
        );
        expect(
          (seamBefore.y - seamCarry.y).abs(),
          lessThan(4.5),
          reason:
              'matching first/last loop contacts should stay vertically '
              'continuous across the low-hook wrap',
        );
        expect(
          (seamBefore.x - seamCarry.x).abs(),
          lessThan(16),
          reason:
              'the low-hook wrap can carry a little lateral groove, but should '
              'not drag the support foot across the body',
        );
      },
    );

    test('dance keeps torso attached to hips across the full phrase', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (var frameIndex = 0; frameIndex < 32; frameIndex += 1) {
        final p = frameIndex / 32;
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: p * CatClips.shaku.duration,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final torso = frame.world[CatBones.torso]!.origin;

        expect(
          (torso.x - hip.x).abs(),
          lessThan(1.5),
          reason:
              'the torso and hips should stay visibly attached at dance '
              'frame $frameIndex',
        );
      }
    });

    test('dance keeps planted shoe orientation stable through support', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.shaku,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
        for (final span in clip.contactSpans) {
          final spanLength = span.end - span.start;
          final anchorFrame = scene.frameAt(
            clip: clip,
            timeSeconds: span.start * clip.duration,
          );
          final anchorRotation = _worldRotation(anchorFrame.world[span.bone]!);

          for (final localP in [0.35, 0.5, 0.65]) {
            final frame = scene.frameAt(
              clip: clip,
              timeSeconds: (span.start + spanLength * localP) * clip.duration,
            );
            final rotation = _worldRotation(frame.world[span.bone]!);

            expect(
              _angleDistance(rotation, anchorRotation),
              lessThan(0.32),
              reason:
                  '${clip.name} ${span.bone} should not visibly roll into a '
                  'hard flip while it bears weight',
            );
          }
        }
      }
    });

    test('dance keeps the pelvis visibly over the active support foot', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final phrase = CatClips.dancePhrase;

      for (var frameIndex = 0; frameIndex < 16; frameIndex++) {
        final p = frameIndex / 16;
        final support = phrase.supportAtPhase(p);
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: p * CatClips.shaku.duration,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final supportPoint = _supportPoint(
          scene,
          CatClips.shaku,
          support.footBoneId,
          p * CatClips.shaku.duration,
        );

        expect(
          (hip.x - supportPoint.x).abs(),
          lessThan(support.maxPelvisDistance),
          reason:
              'dance frame $frameIndex should visibly load the pelvis over '
              'the active support foot ${support.footBoneId}',
        );
      }
    });

    test('dance crew keeps the right-support groove under the hips', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.shaku,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
        for (final frameIndex in [19, 20, 21, 22, 23]) {
          final timeSeconds = CatClips.shaku.duration * frameIndex / 32;
          final frame = scene.frameAt(clip: clip, timeSeconds: timeSeconds);
          final hip = frame.world[CatBones.hips]!.origin;
          final support = _supportPoint(
            scene,
            clip,
            CatBones.footR,
            timeSeconds,
          );

          expect(
            (hip.x - support.x).abs(),
            lessThan(35),
            reason:
                '${clip.name} frame $frameIndex should keep the right-support '
                'groove visibly loaded under the hip, not sliding out from '
                'under the dancer',
          );
        }
      }
    });

    test('dance loads declared torso pockets over support frames', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final phrase = CatClips.dancePhrase;

      for (final support in phrase.supports) {
        final p = support.loadFrame / phrase.frameCount;
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: p * CatClips.shaku.duration,
        );
        final torsoScaleY = _axisScaleY(frame.world[CatBones.torso]!);

        expect(
          torsoScaleY,
          lessThanOrEqualTo(support.pocketScaleY + 0.025),
          reason:
              '${support.label} should visibly compress the torso at its '
              'declared load frame',
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
      final fa = a.frameAt(clip: CatClips.zanku, timeSeconds: 0.7);
      final fb = b.frameAt(clip: CatClips.zanku, timeSeconds: 0.7);
      expect(fa.world['head'], fb.world['head']);
      expect(fa.world['hand.L'], fb.world['hand.L']);
      expect(fa.face.eyeOpenLeft, fb.face.eyeOpenLeft);
    });

    test('performance clips keep the head stable over the moving torso', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final clip in [
        CatClips.shaku,
        CatClips.kick,
        CatClips.shaku,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
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
          lessThan(0.2),
          reason:
              '${clip.name} head should bank with the body as a damped slice '
              'of the lean (~10°), never a full rubber bobble',
        );
      }
    });

    test('dance keeps the head rigid while the torso squashes', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const samples = 120;
      var minTorsoScaleY = double.infinity;
      var maxTorsoScaleY = double.negativeInfinity;
      var minHeadY = double.infinity;
      var maxHeadY = double.negativeInfinity;
      var maxHeadStep = 0.0;
      ({double x, double y})? previousHeadOrigin;

      for (var i = 0; i < samples; i++) {
        final frame = scene.frameAt(
          clip: CatClips.shaku,
          timeSeconds: CatClips.shaku.duration * i / samples,
        );
        final head = frame.world[CatBones.head]!;
        final torso = frame.world[CatBones.torso]!;
        final headScaleX = _axisScaleX(head);
        final headScaleY = _axisScaleY(head);
        final torsoScaleY = _axisScaleY(torso);

        minTorsoScaleY = math.min(minTorsoScaleY, torsoScaleY);
        maxTorsoScaleY = math.max(maxTorsoScaleY, torsoScaleY);
        minHeadY = math.min(minHeadY, head.ty);
        maxHeadY = math.max(maxHeadY, head.ty);
        final headOrigin = (x: head.tx, y: head.ty);
        final previous = previousHeadOrigin;
        if (previous != null) {
          final dx = headOrigin.x - previous.x;
          final dy = headOrigin.y - previous.y;
          maxHeadStep = math.max(maxHeadStep, math.sqrt(dx * dx + dy * dy));
        }
        previousHeadOrigin = headOrigin;
        expect(
          headScaleX,
          closeTo(1, 1e-6),
          reason: 'frame $i should not squash/stretch the skull horizontally',
        );
        expect(
          headScaleY,
          closeTo(1, 1e-6),
          reason: 'frame $i should not squash/stretch the skull vertically',
        );
      }

      expect(
        maxTorsoScaleY - minTorsoScaleY,
        greaterThan(0.055),
        reason: 'the test should cover visible but non-rubbery torso squash',
      );
      expect(
        maxHeadY - minHeadY,
        lessThan(24),
        reason:
            'dance head travel should read like a rigid skull riding the body, '
            'not a rubber bobble',
      );
      expect(
        maxHeadStep,
        lessThan(9.8),
        reason:
            'the Shaku chest bite should not whip the rigid skull sideways '
            'between dense frame samples',
      );
    });

    test('limb targets solve hand goals in anchor-bone space', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const targetX = -88.0;
      const targetY = -12.0;
      const clip = Clip(
        name: 'left-hand-target',
        duration: 1,
        channels: {},
        limbTargets: [
          LimbIkTarget(
            upperBoneId: CatBones.armUpperL,
            lowerBoneId: CatBones.armLowerL,
            endBoneId: CatBones.handL,
            anchorBoneId: CatBones.torso,
            bendDirection: -1,
            channel: FixedIkTargetChannel(x: targetX, y: targetY),
          ),
        ],
      );

      final frame = scene.frameAt(clip: clip, timeSeconds: 0);
      final expected = frame.world[CatBones.torso]!.transformPoint(
        targetX,
        targetY,
      );
      final actual = frame.world[CatBones.handL]!.origin;

      expect(
        _distance(actual, expected),
        lessThan(1.5),
        reason:
            'IK should let choreography place a hand in torso space without '
            'manually solving shoulder and elbow rotations',
      );
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

double _axisScaleX(Affine2D transform) =>
    math.sqrt(transform.a * transform.a + transform.b * transform.b);

double _axisScaleY(Affine2D transform) =>
    math.sqrt(transform.c * transform.c + transform.d * transform.d);

double _angleDistance(double a, double b) =>
    math.atan2(math.sin(a - b), math.cos(a - b)).abs();

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
