import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/runtime/temporal_motion_analyzer.dart';
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
      var lockedVerticalDrift = 0.0;
      var rawVerticalDrift = 0.0;
      var lockedLateralDrift = 0.0;

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
          final locked = _supportPoint(
            scene,
            CatClips.dance,
            span.bone,
            p * CatClips.dance.duration,
          );
          final raw = _rawSupportPoint(
            scene,
            CatClips.dance,
            span.bone,
            p * CatClips.dance.duration,
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

    test(
      'dance keeps broad contact holds grounded and loop seam continuous',
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

          var verticalDrift = 0.0;
          var lateralDrift = 0.0;
          for (var i = 2; i <= 6; i++) {
            final p = span.start + spanLength * i / 8;
            final support = _supportPoint(
              scene,
              CatClips.dance,
              span.bone,
              p * CatClips.dance.duration,
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
          (seamBefore.y - seamAfter.y).abs(),
          lessThan(4.5),
          reason:
              'the loop-pickup support foot should stay vertically grounded '
              'instead of popping off the floor after the low hook',
        );
        final seamCarry = _supportPoint(
          scene,
          CatClips.dance,
          lastSpan.bone,
          CatClips.dance.duration / 16,
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
          clip: CatClips.dance,
          timeSeconds: p * CatClips.dance.duration,
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
        CatClips.dance,
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
          clip: CatClips.dance,
          timeSeconds: p * CatClips.dance.duration,
        );
        final hip = frame.world[CatBones.hips]!.origin;
        final supportPoint = _supportPoint(
          scene,
          CatClips.dance,
          support.footBoneId,
          p * CatClips.dance.duration,
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

    test('dance loads declared torso pockets over support frames', () {
      final scene = CharacterScene(buildCatInSuitRig());
      final phrase = CatClips.dancePhrase;

      for (final support in phrase.supports) {
        final p = support.loadFrame / phrase.frameCount;
        final frame = scene.frameAt(
          clip: CatClips.dance,
          timeSeconds: p * CatClips.dance.duration,
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

    test('dance keeps feet separated through second-half phrase accents', () {
      final scene = CharacterScene(buildCatInSuitRig());

      for (final frameIndex in [12, 15, 18]) {
        final timeSeconds = CatClips.dance.duration * frameIndex / 24;
        final left = _supportPoint(
          scene,
          CatClips.dance,
          CatBones.footL,
          timeSeconds,
        );
        final right = _supportPoint(
          scene,
          CatClips.dance,
          CatBones.footR,
          timeSeconds,
        );
        final separation = (left.x - right.x).abs();

        expect(
          separation,
          greaterThan(30),
          reason:
              '24-frame dance sample $frameIndex should keep the feet '
              'separated enough that the leg ribbons do not merge into one '
              'dark shape',
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

      for (final clip in [
        CatClips.walk,
        CatClips.kick,
        CatClips.dance,
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
          lessThan(0.12),
          reason: '${clip.name} head wobble should stay visually subtle',
        );
      }
    });

    test('dance keeps the head rigid while the torso squashes', () {
      final scene = CharacterScene(buildCatInSuitRig());
      const samples = 48;
      var minTorsoScaleY = double.infinity;
      var maxTorsoScaleY = double.negativeInfinity;
      var minHeadY = double.infinity;
      var maxHeadY = double.negativeInfinity;

      for (var i = 0; i < samples; i++) {
        final frame = scene.frameAt(
          clip: CatClips.dance,
          timeSeconds: CatClips.dance.duration * i / samples,
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
    });

    test('dance has no discontinuous frame-to-frame jumps', () {
      const samples = 96;
      const watchedBones = [
        CatBones.hips,
        CatBones.torso,
        CatBones.head,
        CatBones.handL,
        CatBones.handR,
        CatBones.footL,
        CatBones.footR,
        CatBones.tail6,
      ];

      final report =
          TemporalMotionAnalyzer(
            CharacterScene(buildCatInSuitRig()),
          ).analyze(
            clip: CatClips.dance,
            samples: samples,
            boneIds: watchedBones,
          );
      final worst = report.worstDisplacement;

      expect(
        worst.distance,
        lessThan(22),
        reason:
            'worst jump was ${worst.distance.toStringAsFixed(2)}px on '
            '${worst.boneId} from frame ${worst.fromFrame} to '
            '${worst.toFrame} '
            '(p ${worst.fromPhase.toStringAsFixed(3)} -> '
            '${worst.toPhase.toStringAsFixed(3)})',
      );
    });

    test('dance crew keeps hand accents continuous through section changes', () {
      const samples = 128;
      const watchedHands = [CatBones.handL, CatBones.handR];

      final analyzer = TemporalMotionAnalyzer(
        CharacterScene(buildCatInSuitRig()),
      );
      for (final clip in [
        CatClips.dance,
        CatClips.danceBackupLeft,
        CatClips.danceBackupRight,
      ]) {
        final report = analyzer.analyze(
          clip: clip,
          samples: samples,
          boneIds: watchedHands,
        );
        final worstDisplacement = report.worstDisplacement;
        final worstAcceleration = report.worstAcceleration;

        expect(
          worstDisplacement.distance,
          lessThan(12.5),
          reason:
              '${clip.name} hand accent should travel through section '
              'transitions, not snap ${worstDisplacement.boneId} from '
              'frame ${worstDisplacement.fromFrame} to '
              '${worstDisplacement.toFrame}',
        );
        expect(
          worstAcceleration.magnitude,
          lessThan(6.5),
          reason:
              '${clip.name} hand accent should ease through direction changes, '
              'not jerk ${worstAcceleration.boneId} across frames '
              '${worstAcceleration.fromFrame}->'
              '${worstAcceleration.throughFrame}->'
              '${worstAcceleration.toFrame}',
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
