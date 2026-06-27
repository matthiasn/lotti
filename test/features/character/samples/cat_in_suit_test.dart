import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  group('buildCatInSuitRig', () {
    final rig = buildCatInSuitRig();

    test('builds a valid skeleton with a face', () {
      expect(rig.name, 'cat_in_suit');
      expect(rig.face, isNotNull);
      expect(rig.face!.anchorBoneId, CatBones.head);
      // Topological order covers every bone (no missing parents thrown).
      expect(rig.topoOrder.length, rig.bones.length);
    });

    test('the head and neck carry drawables and the head anchors the face', () {
      expect(rig.bone(CatBones.head)?.drawable, isNotNull);
      expect(rig.bone(CatBones.neck)?.drawable, isNotNull);
    });

    test('hips are the single root', () {
      final roots = rig.bones.where((b) => b.parent == null).toList();
      expect(roots.length, 1);
      expect(roots.single.id, CatBones.hips);
    });

    test('uses soft surfaces for limbs, tail, jacket, and hips', () {
      expect(
        rig.ribbons.map((r) => r.id),
        containsAll([
          'tail.ribbon',
          'leg.L.ribbon',
          'leg.R.ribbon',
          'arm.L.ribbon',
          'arm.R.ribbon',
        ]),
      );
      expect(
        rig.meshes.map((m) => m.id),
        containsAll([
          'jacket.mesh',
          'hips.mesh',
        ]),
      );
      expect(rig.ribbonHiddenBoneIds, contains(CatBones.tail3));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.legLowerL));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.torso));
      expect(rig.hiddenDrawableBoneIds, contains(CatBones.hips));
    });

    test('can build a distinct fur palette for paired cats', () {
      final rig = buildCatInSuitRig(palette: CatInSuitPalette.silverTabby);

      expect(
        rig.bone(CatBones.head)?.drawable?.color,
        CatInSuitPalette.silverTabby.fur,
      );
      expect(
        rig.bone(CatBones.handL)?.drawable?.color,
        CatInSuitPalette.silverTabby.fur,
      );
      expect(
        rig.ribbons.singleWhere((r) => r.id == 'tail.ribbon').color,
        CatInSuitPalette.silverTabby.fur,
      );
      expect(rig.face?.muzzleColor, CatInSuitPalette.silverTabby.muzzle);
    });

    test('dark brown palette reads near black', () {
      final rig = buildCatInSuitRig(palette: CatInSuitPalette.darkBrown);

      expect(
        rig.bone(CatBones.head)?.drawable?.color,
        CatInSuitPalette.darkBrown.fur,
      );
      expect(CatInSuitPalette.darkBrown.fur, 0xFF302820);
      expect(CatInSuitPalette.darkBrown.furDark, 0xFF17110D);
      expect(rig.face?.browColor, CatInSuitPalette.darkBrown.brow);
      expect(CatInSuitPalette.darkBrown.brow, 0xFFF1E2C9);
    });

    test('can build a lead variant with stronger limbs', () {
      final base = buildCatInSuitRig();
      final lead = buildCatInSuitRig(
        legWidthScale: kDanceLeadLegWidthScale,
        armWidthScale: kDanceLeadArmWidthScale,
      );

      final baseLeg = base.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      final leadLeg = lead.ribbons.singleWhere((r) => r.id == 'leg.L.ribbon');
      final baseArm = base.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final leadArm = lead.ribbons.singleWhere((r) => r.id == 'arm.L.ribbon');
      final baseTail = base.ribbons.singleWhere((r) => r.id == 'tail.ribbon');
      final leadTail = lead.ribbons.singleWhere((r) => r.id == 'tail.ribbon');

      expect(baseLeg.halfWidths, const [13, 12.4, 7.8, 9.6, 5.4]);
      expect(
        leadLeg.halfWidths.first,
        closeTo(13 * kDanceLeadLegWidthScale, 0.001),
      );
      expect(
        leadLeg.halfWidths[3],
        closeTo(9.6 * kDanceLeadLegWidthScale, 0.001),
      );
      expect(baseArm.halfWidths, const [11.6, 12.2, 8.6, 5.5]);
      expect(
        leadArm.halfWidths[1],
        closeTo(12.2 * kDanceLeadArmWidthScale, 0.001),
      );
      expect(leadTail.halfWidths, baseTail.halfWidths);
    });
  });

  group('CatClips', () {
    test('exposes the Phase-1 motion set', () {
      expect(
        CatClips.all.map((c) => c.name).toSet(),
        {'walk', 'run', 'kick', 'dance', 'sit', 'jump', 'idle'},
      );
    });

    test('cyclic clips loop and one-shots do not', () {
      expect(CatClips.walk.loop, isTrue);
      expect(CatClips.run.loop, isTrue);
      expect(CatClips.dance.loop, isTrue);
      expect(CatClips.idle.loop, isTrue);
      expect(CatClips.kick.loop, isFalse);
      expect(CatClips.sit.loop, isFalse);
      expect(CatClips.jump.loop, isFalse);
    });

    test('walk drives both legs and both arms', () {
      final channels = CatClips.walk.channels;
      expect(channels.containsKey(CatBones.legUpperL), isTrue);
      expect(channels.containsKey(CatBones.legUpperR), isTrue);
      expect(channels.containsKey(CatBones.armUpperL), isTrue);
      expect(channels.containsKey(CatBones.armUpperR), isTrue);
    });

    test('kick and dance drive the expected performance bones', () {
      expect(CatClips.kick.channels.containsKey(CatBones.legUpperR), isTrue);
      expect(CatClips.kick.channels.containsKey(CatBones.armUpperL), isTrue);
      expect(CatClips.dance.channels.containsKey(CatBones.legUpperL), isTrue);
      expect(CatClips.dance.channels.containsKey(CatBones.armLowerR), isTrue);
      expect(CatClips.dance.channels.containsKey(CatBones.tail6), isTrue);
      expect(CatClips.dance.channels.containsKey(CatBones.earL), isTrue);
      expect(CatClips.dance.channels.containsKey(CatBones.earR), isTrue);
      expect(
        CatClips.dance.limbTargets.map((target) => target.endBoneId),
        [CatBones.handL, CatBones.handR, CatBones.footL, CatBones.footR],
      );
    });

    test('dance ears flick independently while staying bounded', () {
      final earL = CatClips.dance.channels[CatBones.earL]!;
      final earR = CatClips.dance.channels[CatBones.earR]!;
      var minL = double.infinity;
      var maxL = double.negativeInfinity;
      var minR = double.infinity;
      var maxR = double.negativeInfinity;
      var maxPairDifference = 0.0;
      var minScaleY = double.infinity;
      var maxScaleY = double.negativeInfinity;

      for (var i = 0; i <= 32; i++) {
        final p = i / 32;
        final leftPose = earL.sample(p);
        final rightPose = earR.sample(p);
        final l = leftPose.rotation;
        final r = rightPose.rotation;
        minL = math.min(minL, l);
        maxL = math.max(maxL, l);
        minR = math.min(minR, r);
        maxR = math.max(maxR, r);
        maxPairDifference = math.max(maxPairDifference, (l - r).abs());
        minScaleY = math.min(
          minScaleY,
          math.min(leftPose.scaleY, rightPose.scaleY),
        );
        maxScaleY = math.max(
          maxScaleY,
          math.max(leftPose.scaleY, rightPose.scaleY),
        );
      }

      expect(
        maxL - minL,
        greaterThan(0.22),
        reason: 'left ear should visibly flick instead of reading static',
      );
      expect(
        maxR - minR,
        greaterThan(0.22),
        reason: 'right ear should visibly flick instead of reading static',
      );
      expect(
        maxPairDifference,
        greaterThan(0.2),
        reason: 'ears should not move as a mirrored rigid head ornament',
      );
      expect(
        [minL.abs(), maxL.abs(), minR.abs(), maxR.abs()],
        everyElement(lessThan(0.16)),
        reason:
            'ear flicks must stay subtle enough that the deep bases remain '
            'hidden behind the crown',
      );
      expect(
        maxScaleY - minScaleY,
        greaterThan(0.08),
        reason:
            'ear motion should include a little squash/stretch so the ears do '
            'not read as rigid triangles',
      );
    });

    test(
      'backup dance clips share support timing and add bounded body style',
      () {
        final lead = CatClips.dance;
        final left = CatClips.danceBackupLeft;
        final right = CatClips.danceBackupRight;
        const supportCheckP = 7 / 12;
        const firstEchoP = 1 / 8;
        const rightEarlyEchoP = 5 / 32;
        const leftDelayedEchoP = 6 / 32;
        const silverAnswerP = 10 / 32;
        const darkAnswerP = 13 / 32;
        const delayedEchoP = 5 / 8;
        const leftFeatureP = 3 / 4;
        const delayedStepTapEchoP = 25 / 32;
        const rightAnswerSettleP = 17 / 32;
        const leftFeatureSettleP = 28 / 32;
        const leftHookPickupP = 30 / 32;
        const rightHookPickupP = 31 / 32;
        const rightToePickupP = 21 / 32;

        expect(left.duration, lead.duration);
        expect(right.duration, lead.duration);
        expect(left.contactSpans, lead.contactSpans);
        expect(right.contactSpans, lead.contactSpans);
        expect(left.contactPinning, lead.contactPinning);
        expect(right.contactPinning, lead.contactPinning);
        expect(
          left.limbTargets.map((target) => target.endBoneId),
          lead.limbTargets.map((target) => target.endBoneId),
        );
        expect(
          right.limbTargets.map((target) => target.endBoneId),
          lead.limbTargets.map((target) => target.endBoneId),
        );
        final leadHandR = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(3 / 4);
        final leftHandR = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(3 / 4);
        final leadHandL = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(3 / 4);
        final rightHandL = _targetFor(right, CatBones.handL).channel.sample(
          3 / 4,
        );
        final leadHandRSilverAnswer = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(silverAnswerP);
        final leftHandRSilverAnswer = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(silverAnswerP);
        final leadHandLDarkAnswer = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(darkAnswerP);
        final rightHandLDarkAnswer = _targetFor(
          right,
          CatBones.handL,
        ).channel.sample(darkAnswerP);
        final leadHandRFirstEcho = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(firstEchoP);
        final leftHandRFirstEcho = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(firstEchoP);
        final rightHandRFirstEcho = _targetFor(
          right,
          CatBones.handR,
        ).channel.sample(firstEchoP);
        final leadHandLEarlyEcho = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(rightEarlyEchoP);
        final rightHandLEarlyEcho = _targetFor(
          right,
          CatBones.handL,
        ).channel.sample(rightEarlyEchoP);
        final leadHandRDelayedEcho = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(leftDelayedEchoP);
        final leftHandRDelayedEcho = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(leftDelayedEchoP);
        final leadFootRFirstEcho = _targetFor(
          lead,
          CatBones.footR,
        ).channel.sample(firstEchoP);
        final leftFootRFirstEcho = _targetFor(
          left,
          CatBones.footR,
        ).channel.sample(firstEchoP);
        final rightFootRFirstEcho = _targetFor(
          right,
          CatBones.footR,
        ).channel.sample(firstEchoP);
        final leadHandLDelayedEcho = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(delayedEchoP);
        final leftHandLDelayedEcho = _targetFor(
          left,
          CatBones.handL,
        ).channel.sample(delayedEchoP);
        final rightHandLDelayedEcho = _targetFor(
          right,
          CatBones.handL,
        ).channel.sample(delayedEchoP);
        final leadFootLRightPickup = _targetFor(
          lead,
          CatBones.footL,
        ).channel.sample(rightToePickupP);
        final leftFootLRightPickup = _targetFor(
          left,
          CatBones.footL,
        ).channel.sample(rightToePickupP);
        final rightFootLRightPickup = _targetFor(
          right,
          CatBones.footL,
        ).channel.sample(rightToePickupP);
        final leadHandLRightAnswerSettle = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(rightAnswerSettleP);
        final rightHandLRightAnswerSettle = _targetFor(
          right,
          CatBones.handL,
        ).channel.sample(rightAnswerSettleP);
        final leadHandRLeftFeatureSettle = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(leftFeatureSettleP);
        final leftHandRLeftFeatureSettle = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(leftFeatureSettleP);
        final leadHandRHookPickup = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(leftHookPickupP);
        final leftHandRHookPickup = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(leftHookPickupP);
        final leadHandLHookPickup = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(rightHookPickupP);
        final rightHandLHookPickup = _targetFor(
          right,
          CatBones.handL,
        ).channel.sample(rightHookPickupP);
        expect(leftHandR.x, closeTo(leadHandR.x - 12, 0.001));
        expect(leftHandR.y, closeTo(leadHandR.y - 7, 0.001));
        expect(
          rightHandL.x,
          closeTo(leadHandL.x, 0.001),
          reason:
              'right backup should stay neutral while the left-side dancer '
              'owns the later feature',
        );
        expect(rightHandL.y, closeTo(leadHandL.y, 0.001));
        expect(
          leftHandRSilverAnswer.x,
          lessThan(leadHandRSilverAnswer.x - 17),
          reason:
              'the silver cat should answer early around frame 10 after '
              'marking the lead call, not hit in lockstep with the dark cat',
        );
        expect(
          leftHandRSilverAnswer.y,
          lessThan(leadHandRSilverAnswer.y - 12),
        );
        expect(
          rightHandLDarkAnswer.x,
          greaterThan(leadHandLDarkAnswer.x + 17),
          reason:
              'the dark cat should answer later around frame 13 with its '
              'inside hand, creating a readable crew ripple',
        );
        expect(
          rightHandLDarkAnswer.y,
          lessThan(leadHandLDarkAnswer.y - 12),
        );
        expect(
          rightHandLRightAnswerSettle.x,
          closeTo(leadHandLRightAnswerSettle.x, 0.25),
          reason:
              'right backup inside-hand arc should settle back to neutral '
              'within sub-pixel tolerance before the next phrase answer',
        );
        expect(
          rightHandLRightAnswerSettle.y,
          closeTo(leadHandLRightAnswerSettle.y, 0.25),
        );
        expect(
          leftHandRFirstEcho.x,
          closeTo(leadHandRFirstEcho.x, 0.001),
          reason:
              'the lead should own the first Shaku hand hit before the silver '
              'backup answers two frames later',
        );
        expect(
          leftHandRFirstEcho.y,
          closeTo(leadHandRFirstEcho.y, 0.001),
        );
        expect(
          rightHandLEarlyEcho.x,
          closeTo(leadHandLEarlyEcho.x, 0.001),
          reason:
              'the dark backup should mark the lead call without stealing the '
              'first inside-hand answer',
        );
        expect(
          rightHandLEarlyEcho.y,
          closeTo(leadHandLEarlyEcho.y, 0.001),
        );
        expect(
          leftHandRDelayedEcho.x,
          closeTo(leadHandRDelayedEcho.x, 0.001),
          reason:
              'the silver backup should also hold the lead call restrained; '
              'the visible answer belongs to frames 9-16',
        );
        expect(
          leftHandRDelayedEcho.y,
          closeTo(leadHandRDelayedEcho.y, 0.001),
        );
        expect(
          rightHandRFirstEcho.x,
          closeTo(leadHandRFirstEcho.x, 0.001),
          reason:
              'right backup should not mirror the left echo on the same beat',
        );
        expect(
          leftFootRFirstEcho.x,
          closeTo(leadFootRFirstEcho.x - 9.6, 0.001),
          reason:
              'left backup should answer the first pocket with a distinct '
              'low right-toe variation',
        );
        expect(
          leftFootRFirstEcho.y,
          closeTo(leadFootRFirstEcho.y + 2.1, 0.001),
        );
        expect(
          rightFootRFirstEcho.x,
          closeTo(leadFootRFirstEcho.x, 0.001),
          reason:
              'right backup should leave the first low toe answer to the left '
              'dancer',
        );
        expect(rightFootRFirstEcho.y, closeTo(leadFootRFirstEcho.y, 0.001));
        expect(
          rightHandLDelayedEcho.x,
          closeTo(leadHandLDelayedEcho.x + 6.4, 0.001),
          reason:
              'right backup should answer later on the lead right-foot groove',
        );
        expect(
          rightHandLDelayedEcho.y,
          closeTo(leadHandLDelayedEcho.y - 4.2, 0.001),
        );
        expect(
          leftHandLDelayedEcho.x,
          closeTo(leadHandLDelayedEcho.x, 0.001),
          reason:
              'left backup should leave the delayed answer to the right dancer',
        );
        expect(
          rightFootLRightPickup.x,
          closeTo(leadFootLRightPickup.x + 9.2, 0.001),
          reason:
              'right backup should answer the second pocket with a delayed '
              'left-toe pickup',
        );
        expect(
          rightFootLRightPickup.y,
          closeTo(leadFootLRightPickup.y - 5.2, 0.001),
        );
        expect(
          leftFootLRightPickup.x,
          closeTo(leadFootLRightPickup.x, 0.001),
          reason:
              'left backup should not copy the right dancer delayed toe '
              'pickup',
        );
        expect(leftFootLRightPickup.y, closeTo(leadFootLRightPickup.y, 0.001));
        expect(
          leftHandRLeftFeatureSettle.x,
          closeTo(leadHandRLeftFeatureSettle.x, 0.001),
          reason:
              'left backup feature arc should not keep pulling the hand after '
              'the side feature has settled',
        );
        expect(
          leftHandRLeftFeatureSettle.y,
          closeTo(leadHandRLeftFeatureSettle.y, 0.001),
        );
        expect(
          leftHandRHookPickup.x,
          closeTo(leadHandRHookPickup.x - 5.4, 0.001),
          reason:
              'left backup should pick up the lead hook reset after the '
              'side-feature has settled',
        );
        expect(
          leftHandRHookPickup.y,
          closeTo(leadHandRHookPickup.y - 4.2, 0.001),
        );
        expect(
          rightHandLHookPickup.x,
          closeTo(leadHandLHookPickup.x + 4.4, 0.001),
          reason:
              'right backup should answer the loop pickup without copying the '
              'left backup on the same frame',
        );
        expect(
          rightHandLHookPickup.y,
          closeTo(leadHandLHookPickup.y - 3.2, 0.001),
        );
        expect(
          left.channels[CatBones.legUpperL]!.sample(supportCheckP).rotation,
          closeTo(
            lead.channels[CatBones.legUpperL]!.sample(supportCheckP).rotation,
            1e-9,
          ),
        );
        expect(
          right.channels[CatBones.legUpperR]!.sample(supportCheckP).rotation,
          closeTo(
            lead.channels[CatBones.legUpperR]!.sample(supportCheckP).rotation,
            1e-9,
          ),
        );
        final leftHipDelta =
            left.channels[CatBones.hips]!.sample(leftFeatureP).rotation -
            lead.channels[CatBones.hips]!.sample(leftFeatureP).rotation;
        final rightTorsoDelta =
            right.channels[CatBones.torso]!.sample(darkAnswerP).rotation -
            lead.channels[CatBones.torso]!.sample(darkAnswerP).rotation;
        final leftStepTapEchoHipDelta =
            left.channels[CatBones.hips]!.sample(delayedStepTapEchoP).rotation -
            lead.channels[CatBones.hips]!.sample(delayedStepTapEchoP).rotation;
        final rightStepTapEchoTorsoDelta =
            right.channels[CatBones.torso]!
                .sample(delayedStepTapEchoP)
                .rotation -
            lead.channels[CatBones.torso]!.sample(delayedStepTapEchoP).rotation;
        final leftFirstEchoTorsoDelta =
            left.channels[CatBones.torso]!.sample(firstEchoP).rotation -
            lead.channels[CatBones.torso]!.sample(firstEchoP).rotation;
        final rightDelayedEchoTorsoDelta =
            right.channels[CatBones.torso]!.sample(delayedEchoP).rotation -
            lead.channels[CatBones.torso]!.sample(delayedEchoP).rotation;
        final leftHookTorsoDelta =
            left.channels[CatBones.torso]!.sample(leftHookPickupP).rotation -
            lead.channels[CatBones.torso]!.sample(leftHookPickupP).rotation;
        final rightHookTorsoDelta =
            right.channels[CatBones.torso]!.sample(rightHookPickupP).rotation -
            lead.channels[CatBones.torso]!.sample(rightHookPickupP).rotation;
        final leftArmDelta =
            left.channels[CatBones.armUpperR]!.sample(leftFeatureP).rotation -
            lead.channels[CatBones.armUpperR]!.sample(leftFeatureP).rotation;
        final rightArmDelta =
            right.channels[CatBones.armUpperL]!.sample(darkAnswerP).rotation -
            lead.channels[CatBones.armUpperL]!.sample(darkAnswerP).rotation;
        final leftHookArmDelta =
            left.channels[CatBones.armUpperR]!
                .sample(leftHookPickupP)
                .rotation -
            lead.channels[CatBones.armUpperR]!.sample(leftHookPickupP).rotation;
        final rightHookArmDelta =
            right.channels[CatBones.armUpperL]!
                .sample(rightHookPickupP)
                .rotation -
            lead.channels[CatBones.armUpperL]!
                .sample(rightHookPickupP)
                .rotation;
        expect(
          leftHipDelta.abs(),
          inInclusiveRange(0.04, 0.18),
          reason:
              'left backup should answer with a visible hip variation when '
              'the camera pans left',
        );
        expect(
          rightTorsoDelta.abs(),
          inInclusiveRange(0.03, 0.22),
          reason:
              'right backup should answer with a visible chest variation when '
              'the camera pans right',
        );
        expect(
          leftStepTapEchoHipDelta.abs(),
          inInclusiveRange(0.01, 0.16),
          reason:
              'left backup should echo the F24 step-tap one frame later, not '
              'move in exact lockstep with the lead',
        );
        expect(
          rightStepTapEchoTorsoDelta.abs(),
          inInclusiveRange(0.01, 0.12),
          reason:
              'right backup should carry a smaller delayed shoulder answer on '
              'the step-tap release',
        );
        expect(
          leftArmDelta.abs(),
          inInclusiveRange(0.08, 0.32),
          reason: 'left backup should feature its inside arm on the left pass',
        );
        expect(
          rightArmDelta.abs(),
          inInclusiveRange(0.08, 0.65),
          reason:
              'right backup should feature its inside arm on the right pass',
        );
        expect(
          leftFirstEchoTorsoDelta.abs(),
          inInclusiveRange(0.008, 0.04),
          reason:
              'left backup should only mark the first-pocket shoulder so the '
              'lead owns the call',
        );
        expect(
          rightDelayedEchoTorsoDelta.abs(),
          inInclusiveRange(0.03, 0.1),
          reason:
              'right backup should answer on the later right-foot groove '
              'without becoming the lead',
        );
        expect(
          leftHookTorsoDelta.abs(),
          inInclusiveRange(0.025, 0.08),
          reason: 'left backup should visibly join the loop pickup',
        );
        expect(
          rightHookTorsoDelta.abs(),
          inInclusiveRange(0.02, 0.045),
          reason:
              'right backup should join the loop pickup as a smaller delayed '
              'answer',
        );
        expect(
          leftHookArmDelta,
          lessThan(-0.07),
          reason: 'left backup should mark the pickup with its inside arm',
        );
        expect(
          rightHookArmDelta,
          greaterThan(0.05),
          reason: 'right backup should answer the pickup with its inside arm',
        );
        final rightOffCameraArmDelta =
            right.channels[CatBones.armUpperL]!.sample(leftFeatureP).rotation -
            lead.channels[CatBones.armUpperL]!.sample(leftFeatureP).rotation;
        expect(
          rightOffCameraArmDelta.abs(),
          lessThan(leftArmDelta.abs() * 0.45),
          reason:
              'right backup should not compete with the left-side camera '
              'feature later in the phrase',
        );
      },
    );

    test(
      'dance compresses into a soft pocket, rebounds, and lifts free feet',
      () {
        final channels = CatClips.dance.channels;
        final root = CatClips.dance.root;
        final hips = channels[CatBones.hips]!;
        final torso = channels[CatBones.torso]!;
        final footL = channels[CatBones.footL]!;
        final footR = channels[CatBones.footR]!;
        final armUpperL = channels[CatBones.armUpperL]!;
        final armUpperR = channels[CatBones.armUpperR]!;
        final armLowerL = channels[CatBones.armLowerL]!;
        final armLowerR = channels[CatBones.armLowerR]!;

        final contactTorso = torso.sample(0);
        final pocketTorso = torso.sample(1 / 8);
        final reboundTorso = torso.sample(1 / 4);
        expect(
          pocketTorso.scaleY,
          lessThan(contactTorso.scaleY - 0.03),
          reason: 'Shaku count 1 should settle into a low shoulder pocket',
        );
        expect(
          reboundTorso.scaleY,
          greaterThan(pocketTorso.scaleY + 0.05),
          reason:
              'count 2 should rebound from the pocket without standing tall',
        );
        expect(hips.sample(1 / 8).rotation, greaterThan(0.35));
        expect(hips.sample(5 / 8).rotation, lessThan(-0.35));
        expect(torso.sample(1 / 8).rotation, lessThan(-0.15));
        expect(torso.sample(5 / 8).rotation, greaterThan(0.15));
        final bridgeRoot = [
          root.sample(12 / 32).dx,
          root.sample(13 / 32).dx,
          root.sample(14 / 32).dx,
          root.sample(15 / 32).dx,
          root.sample(16 / 32).dx,
        ];
        expect(
          bridgeRoot,
          orderedEquals(bridgeRoot.toList()..sort((a, b) => b.compareTo(a))),
          reason:
              'frames 12-16 should bridge the weight transfer monotonically '
              'instead of popping from one side to the other',
        );
        for (var i = 0; i < bridgeRoot.length - 1; i++) {
          expect(
            (bridgeRoot[i] - bridgeRoot[i + 1]).abs(),
            lessThan(11),
            reason:
                'frame ${12 + i}->${13 + i} should not jump more than the '
                'authored support-transfer step',
          );
        }
        expect(hips.sample(14 / 32).rotation, lessThan(-0.2));
        expect(torso.sample(14 / 32).rotation, greaterThan(0.1));

        final leftSupportFoot = footL.sample(0).rotation;
        final rightFreeFoot = footR.sample(1 / 8).rotation;
        final rightSupportFoot = footR.sample(5 / 8).rotation;
        final leftFreeFoot = footL.sample(5 / 8).rotation;
        final leftReleaseFoot = footL.sample(7 / 8).rotation;
        expect(leftSupportFoot, closeTo(-0.08, 0.001));
        expect(rightSupportFoot, closeTo(-0.08, 0.001));
        expect(
          footL.sample(1 / 8).rotation,
          lessThan(leftSupportFoot - 0.04),
          reason:
              'the planted left foot should roll into the Shaku pocket instead '
              'of staying perfectly flat while the body loads it',
        );
        expect(rightFreeFoot, greaterThan(rightSupportFoot + 0.45));
        final shakuToeTap = _targetFor(
          CatClips.dance,
          CatBones.footR,
        ).channel.sample(1 / 8);
        expect(
          shakuToeTap.x,
          greaterThan(84),
          reason:
              'the first pocket should show a low outward free-foot toe tap',
        );
        expect(
          shakuToeTap.y,
          greaterThan(92),
          reason:
              'the free-right foot should stay low enough to read as footwork',
        );
        expect(
          footR.sample(17 / 32).rotation,
          greaterThan(rightSupportFoot + 0.08),
          reason:
              'the right-foot pocket should show a heel-lift before settling',
        );
        expect(
          footR.sample(19 / 32).rotation,
          lessThan(rightSupportFoot - 0.04),
          reason:
              'the right-foot pocket should answer with a toe-down plant, not '
              'a flat support throughout',
        );
        expect(
          leftFreeFoot,
          inInclusiveRange(leftSupportFoot + 0.35, leftSupportFoot + 0.7),
          reason:
              'the left toe accent should read as defined Afrobeats texture '
              'without pulling the foot across the body',
        );
        expect(
          leftReleaseFoot,
          inInclusiveRange(leftSupportFoot + 0.48, leftSupportFoot + 0.64),
          reason:
              'the count-8 toe release should be an authored footwork accent, '
              'not just the raw IK target sliding across the deck',
        );

        expect(armUpperL.sample(0).rotation, inInclusiveRange(0.2, 0.25));
        expect(armUpperR.sample(0).rotation, inInclusiveRange(-0.26, -0.21));
        expect(
          armUpperL.sample(1 / 8).rotation,
          lessThan(-0.35),
          reason:
              'the lead arm should cross into the groove without a huge '
              'stage-sweep',
        );
        expect(
          armUpperR.sample(1 / 8).rotation,
          inInclusiveRange(0.32, 0.55),
          reason:
              'the opposite arm should mark the chest-level groove without '
              'whipping through a boy-band sweep',
        );
        expect(
          armUpperL.sample(1 / 4).rotation,
          inInclusiveRange(0.5, 0.75),
          reason:
              'the count-2 accent should stay compact at chest level instead '
              'of snapping to a vertical boy-band punch',
        );
        expect(
          armUpperR.sample(1 / 4).rotation,
          inInclusiveRange(-0.12, 0.02),
          reason:
              'the opposite arm should counter the lead scoop instead of '
              'matching its height',
        );
        expect(
          armUpperL.sample(15 / 16).rotation,
          inInclusiveRange(0.42, 0.62),
          reason: 'count-8 hook should bend the left arm in a compact groove',
        );
        expect(
          armUpperR.sample(15 / 16).rotation,
          lessThan(-0.45),
          reason: 'count-8 hook should keep the opposite arm open but compact',
        );
        expect(
          armLowerL.sample(15 / 16).rotation,
          greaterThan(0.35),
          reason:
              'count-8 hook should visibly bend the lead elbow without '
              'snapping out at the loop seam',
        );
        expect(
          armLowerR.sample(15 / 16).rotation,
          greaterThan(0.55),
          reason: 'count-8 hook should visibly bend the opposite elbow',
        );
        expect(
          hips.sample(15 / 16).rotation,
          greaterThan(0.21),
          reason: 'count-8 hook should keep a small hip pickup under the arms',
        );
        expect(
          torso.sample(15 / 16).rotation,
          lessThan(-0.09),
          reason:
              'count-8 hook should carry a counter-shoulder pickup, not only '
              'arm motion',
        );
        expect(
          torso.sample(15 / 16).scaleY,
          lessThan(0.96),
          reason: 'count-8 hook should stay in the groove pocket',
        );
        expect(
          armLowerL.sample(1 / 4).rotation,
          greaterThan(0.1),
          reason: 'the softened count-2 accent still bends the lead elbow',
        );
        expect(armLowerR.sample(1 / 4).rotation, greaterThan(0.2));
      },
    );

    test('dance holds broad Shaku supports across the phrase', () {
      final phrase = CatClips.dancePhrase;
      final spans = CatClips.dance.contactSpans;
      expect(phrase.frameCount, 32);
      expect(spans.map((span) => span.bone), [
        CatBones.footL,
        CatBones.footR,
        CatBones.footL,
      ]);
      expect(spans.map((span) => span.start), [0, 1 / 2, 15 / 16]);
      expect(spans.map((span) => span.end), [1 / 2, 15 / 16, 1]);
      expect(
        spans.take(2).map((span) => span.end - span.start),
        everyElement(greaterThanOrEqualTo(7 / 16)),
      );
      expect(phrase.supports.map((support) => support.label), [
        'left-foot Shaku low pocket',
        'right-foot answer pocket',
        'left-foot loop pickup',
      ]);
      expect(phrase.supportAtFrame(4).freeFootBoneId, CatBones.footR);
      expect(phrase.supportAtFrame(20).freeFootBoneId, CatBones.footL);
      expect(phrase.supportAtFrame(32).footBoneId, CatBones.footL);
      expect(phrase.supports.map((support) => support.loadFrame), [4, 20, 31]);
      expect(phrase.supports.map((support) => support.releaseFrame), [
        8,
        24,
        32,
      ]);
      expect(phrase.sections.map((section) => section.name), [
        'Shaku pocket',
        'Shaku rebound',
        'answer pocket',
        'toe-flick release',
        'loop pickup',
      ]);
      expect(phrase.moves.map((move) => move.name), [
        'lead Shaku pocket hit',
        'lead rebound shoulder scoop',
        'right-side camera answer',
        'right-foot groove pocket',
        'left-side camera answer',
        'toe-flick hook reset',
      ]);
      expect(phrase.sectionAtFrame(4).name, 'Shaku pocket');
      expect(phrase.sectionAtFrame(20).name, 'answer pocket');
      expect(phrase.sectionAtFrame(31).name, 'loop pickup');
      expect(phrase.moveAtFrame(4).featuredDancer, 'lead');
      expect(phrase.moveAtFrame(12).name, 'right-side camera answer');
      expect(phrase.moveAtFrame(20).name, 'right-foot groove pocket');
      expect(phrase.moveAtFrame(24).featuredDancer, 'left');
      expect(phrase.moveAtFrame(31).name, 'toe-flick hook reset');
    });

    test('dance move cues map to visible body, arm, and foot signatures', () {
      final phrase = CatClips.dancePhrase;
      final lead = CatClips.dance;
      final left = CatClips.danceBackupLeft;
      final right = CatClips.danceBackupRight;
      final leadChannels = lead.channels;
      final leadFootLTarget = _targetFor(lead, CatBones.footL).channel;
      final leadFootRTarget = _targetFor(lead, CatBones.footR).channel;

      final shakuP = phrase.moveAtFrame(4).accentFrame / phrase.frameCount;
      expect(
        leadChannels[CatBones.torso]!.sample(shakuP).scaleY,
        lessThan(0.94),
        reason: 'lead Shaku cue should visibly drop into the pocket',
      );
      expect(
        leadChannels[CatBones.armUpperL]!.sample(shakuP).rotation,
        lessThan(-0.35),
        reason: 'lead Shaku cue should read as crossed-arm groove',
      );
      final shakuHit = lead.root.sample(4 / phrase.frameCount);
      final shakuSink = lead.root.sample(6 / phrase.frameCount);
      final shakuRebound = lead.root.sample(8 / phrase.frameCount);
      final openingPlant = lead.root.sample(0);
      final openingAndOne = lead.root.sample(1 / phrase.frameCount);
      final openingDownbeat = lead.root.sample(2 / phrase.frameCount);
      final openingAndTwo = lead.root.sample(3 / phrase.frameCount);
      final openingSupportXs = [
        for (final frame in [0, 1, 2, 3, 4, 5, 6])
          leadFootLTarget.sample(frame / phrase.frameCount).x,
      ];
      final openingFreeRightStart = leadFootRTarget.sample(0);
      final openingFreeRightStep = leadFootRTarget.sample(
        4 / phrase.frameCount,
      );
      final openingFreeRightRecoil = leadFootRTarget.sample(
        6 / phrase.frameCount,
      );
      final openingRightToeIn = leadChannels[CatBones.footR]!.sample(
        3 / phrase.frameCount,
      );
      final openingRightToeOut = leadChannels[CatBones.footR]!.sample(
        4 / phrase.frameCount,
      );
      final openingStepRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(4 / phrase.frameCount);
      final openingStepLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(4 / phrase.frameCount);
      final openingStepShoulder = leadChannels[CatBones.torso]!.sample(
        4 / phrase.frameCount,
      );
      final openingDelayedShoulder = leadChannels[CatBones.torso]!.sample(
        5 / phrase.frameCount,
      );
      final rightBackupEarlyAnswerP = 5 / phrase.frameCount;
      final leftBackupDelayedAnswerP = 6 / phrase.frameCount;
      final rightBackupEarlyShoulder = right.channels[CatBones.torso]!.sample(
        rightBackupEarlyAnswerP,
      );
      final leftBackupDelayedShoulder = left.channels[CatBones.torso]!.sample(
        leftBackupDelayedAnswerP,
      );
      final rightBackupEarlyHand = _targetFor(
        right,
        CatBones.handL,
      ).channel.sample(rightBackupEarlyAnswerP);
      final rightLeadEarlyHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(rightBackupEarlyAnswerP);
      final leftBackupDelayedHand = _targetFor(
        left,
        CatBones.handR,
      ).channel.sample(leftBackupDelayedAnswerP);
      final leftLeadDelayedHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(leftBackupDelayedAnswerP);
      expect(
        openingDownbeat.dy,
        greaterThan(openingPlant.dy + 0.4),
        reason:
            'F2 should visibly compress into the opening support foot so the '
            'loop lands as a downbeat instead of resetting to neutral',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(2 / phrase.frameCount).scaleY,
        lessThan(leadChannels[CatBones.torso]!.sample(0).scaleY - 0.008),
        reason:
            'the opening downbeat needs torso squash to sell foot pressure, '
            'not just a sideways sway',
      );
      expect(
        openingAndOne.dy,
        greaterThan(openingPlant.dy + 2.6),
        reason:
            'the first half-beat should already drop into a grounded bounce; '
            'otherwise frames 1-8 read like a held pose',
      );
      expect(
        openingAndTwo.dy,
        greaterThan(openingDownbeat.dy + 1),
        reason:
            'the opening Shaku phrase needs a 1-and-2-and knee pulse, not just '
            'one polite downbeat',
      );
      expect(
        openingSupportXs.reduce(math.max) - openingSupportXs.reduce(math.min),
        lessThan(4),
        reason:
            'the opening Shaku/Gbese pocket needs a planted left support foot; '
            'if it drifts, the footwork reads as body slide',
      );
      expect(
        openingFreeRightStep.x,
        greaterThan(openingFreeRightStart.x + 20),
        reason:
            'the free right foot should drive the opening phrase with a clear '
            'step-out before the torso/arms sell the groove',
      );
      expect(
        openingFreeRightStep.y,
        greaterThan(92),
        reason:
            'the free right step should stay low enough to read as floor '
            'footwork, not a knee lift',
      );
      expect(
        openingFreeRightRecoil.x,
        lessThan(openingFreeRightStep.x - 16),
        reason:
            'after the step-out, the free right foot should recoil through the '
            'floor instead of freezing at the side',
      );
      expect(
        openingRightToeOut.rotation - openingRightToeIn.rotation,
        greaterThan(0.25),
        reason:
            'the free right foot should visibly toe-in/toe-out on the opening '
            'legwork instead of sliding as a rigid shoe',
      );
      expect(
        openingStepRightHand.y,
        lessThan(openingStepLeftHand.y - 6),
        reason:
            'the opening groove should have a loose opposite-side elbow lift, '
            'not two mirrored hands at belly height',
      );
      expect(
        openingStepRightHand.x - openingStepLeftHand.x,
        greaterThan(65),
        reason:
            'the opening arms should break symmetry into a relaxed Lagos-party '
            'shape after the foot hits',
      );
      expect(
        openingDelayedShoulder.rotation,
        lessThan(openingStepShoulder.rotation - 0.04),
        reason:
            'the opening shoulder should answer one frame after the foot hit; '
            'if shoulder and foot land together, the phrase reads robotic',
      );
      expect(
        rightBackupEarlyShoulder.rotation,
        closeTo(
          leadChannels[CatBones.torso]!
              .sample(rightBackupEarlyAnswerP)
              .rotation,
          0.025,
        ),
        reason:
            'the dark cat should mark the lead call with restrained pocket '
            'motion; the clear flanker answer comes after frame 8',
      );
      expect(
        leftBackupDelayedShoulder.rotation,
        closeTo(
          leadChannels[CatBones.torso]!
              .sample(leftBackupDelayedAnswerP)
              .rotation,
          0.03,
        ),
        reason:
            'the silver cat should also hold back during the lead call instead '
            'of creating simultaneous action',
      );
      expect(
        (rightBackupEarlyHand.x - rightLeadEarlyHand.x).abs(),
        lessThan(0.001),
        reason:
            'the dark cat inside hand should not steal the opening lead call',
      );
      expect(
        (leftBackupDelayedHand.x - leftLeadDelayedHand.x).abs(),
        lessThan(0.001),
        reason:
            'the silver cat inside hand should wait for the response window',
      );
      expect(
        (shakuSink.dx - shakuHit.dx).abs(),
        lessThan(6),
        reason:
            'the Shaku sink should hold over the left support before '
            'travelling, not drift sideways through the weight transfer',
      );
      expect(
        shakuSink.dy,
        greaterThan(shakuRebound.dy + 1),
        reason:
            'frame 6 should visibly sink before the frame 8 rebound, so the '
            'beat reads step/sink/rebound instead of a flat slide',
      );
      expect(
        shakuRebound.dx,
        greaterThan(shakuSink.dx + 12),
        reason:
            'the Shaku rebound should travel across after the sink has landed',
      );
      final shakuToeTap = _targetFor(
        lead,
        CatBones.footR,
      ).channel.sample(6 / phrase.frameCount);
      expect(
        shakuToeTap.y,
        greaterThan(95),
        reason:
            'the free right foot should stay low enough to read as a toe tap '
            'on the Shaku sink',
      );

      final reboundP = phrase.moveAtFrame(10).accentFrame / phrase.frameCount;
      expect(phrase.moveAtFrame(10).name, 'lead rebound shoulder scoop');
      expect(
        leadChannels[CatBones.torso]!.sample(reboundP).scaleY,
        lessThan(0.972),
        reason: 'the lead should keep a soft pocket while the flankers answer',
      );
      final reboundLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(reboundP);
      final reboundRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(reboundP);
      expect(
        reboundLeftHand.y,
        greaterThan(4),
        reason:
            'the lead hand should stay lower during the flanker answer instead '
            'of reclaiming the whole 9-16 window',
      );
      expect(
        reboundRightHand.y,
        greaterThan(4),
        reason:
            'the lead right hand should also stay in the pocket while the side '
            'cats answer',
      );
      expect(
        reboundRightHand.x - reboundLeftHand.x,
        lessThan(120),
        reason:
            'frames 9-16 should avoid a broad lead boy-band arm shape; the '
            'side cats own the larger answer',
      );
      final delayedRollP = 12 / phrase.frameCount;
      expect(
        leadChannels[CatBones.torso]!.sample(delayedRollP).rotation,
        lessThan(0.04),
        reason:
            'the shoulder scoop should roll through delayed chest opposition '
            'instead of staying upright and symmetrical through frames 9-14',
      );
      expect(
        leadChannels[CatBones.hips]!.sample(delayedRollP).rotation,
        lessThan(0),
        reason:
            'the delayed shoulder roll should keep the hip loaded under it, '
            'not turn into an ungrounded upper-body flourish',
      );
      expect(
        leadChannels[CatBones.armUpperL]!.sample(reboundP).rotation,
        lessThan(0.55),
        reason:
            'the lead shoulder should stay compact in the flanker-answer window',
      );
      expect(
        leadChannels[CatBones.armUpperR]!.sample(reboundP).rotation,
        greaterThan(0.18),
        reason:
            'right shoulder should still mark the pocket without dominating it',
      );
      expect(
        leadChannels[CatBones.armLowerR]!.sample(reboundP).rotation,
        greaterThan(0.4),
        reason: 'right forearm should carve a restrained pocket answer',
      );

      final ribRollEntryP = 11 / phrase.frameCount;
      final ribRollPeakP = 14 / phrase.frameCount;
      final leadRibRollEntry = leadChannels[CatBones.torso]!.sample(
        ribRollEntryP,
      );
      final leadRibRollPeak = leadChannels[CatBones.torso]!.sample(
        ribRollPeakP,
      );
      final leadHipRollPeak = leadChannels[CatBones.hips]!.sample(
        ribRollPeakP,
      );
      final leadLowCarve = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(ribRollPeakP);
      expect(
        leadRibRollPeak.rotation - leadRibRollEntry.rotation,
        greaterThan(0.14),
        reason:
            'frames 11-14 should read as a real rib roll into the camera '
            'answer, not a neutral bridge between poses',
      );
      expect(
        leadRibRollPeak.rotation - leadHipRollPeak.rotation,
        greaterThan(0.45),
        reason:
            'the camera-answer rib roll should keep chest and hips in '
            'opposition instead of swinging the whole body as one block',
      );
      expect(
        leadLowCarve.x,
        lessThan(-60),
        reason:
            'the lead left hand should stay outside the belly silhouette during '
            'the side-cat answer without stealing the whole feature',
      );
      expect(leadLowCarve.y, greaterThan(26));
      final answerCrossLeft = leadFootLTarget.sample(13 / phrase.frameCount);
      final answerCrossRight = leadFootRTarget.sample(13 / phrase.frameCount);
      final answerSinkLeft = leadFootLTarget.sample(14 / phrase.frameCount);
      final answerSinkRight = leadFootRTarget.sample(14 / phrase.frameCount);
      final answerUncrossLeft = leadFootLTarget.sample(15 / phrase.frameCount);
      final answerUncrossRight = leadFootRTarget.sample(15 / phrase.frameCount);
      final zankuLiftLeftFoot = leadChannels[CatBones.footL]!.sample(
        13 / phrase.frameCount,
      );
      final zankuStampLeftFoot = leadChannels[CatBones.footL]!.sample(
        14 / phrase.frameCount,
      );
      final zankuFlickRightFoot = leadChannels[CatBones.footR]!.sample(
        13 / phrase.frameCount,
      );
      final zankuStampRightFoot = leadChannels[CatBones.footR]!.sample(
        14 / phrase.frameCount,
      );
      expect(
        answerSinkLeft.y,
        greaterThan(answerCrossLeft.y + 4),
        reason:
            'F14 should be the visible low cross-beat, not another floating '
            'slide through the camera answer',
      );
      expect(
        answerUncrossLeft.x,
        lessThan(answerSinkLeft.x - 18),
        reason:
            'F15 should uncross the lead left foot outward after the F14 sink',
      );
      expect(
        answerUncrossRight.x - answerUncrossLeft.x,
        greaterThan(answerSinkRight.x - answerSinkLeft.x + 8),
        reason: 'the F15 uncross needs a wider foot shape than the F14 cross',
      );
      expect(
        answerCrossRight.y,
        greaterThan(104),
        reason:
            'the crossing right foot should stay low enough to read as '
            'footwork instead of a hidden knee lift',
      );
      expect(
        zankuLiftLeftFoot.rotation,
        greaterThan(zankuStampLeftFoot.rotation + 0.25),
        reason:
            'F13 should show the lifted-knee/toe accent before the F14 stamp, '
            'so the camera-answer beat reads zanku-inspired rather than a '
            'plain side sway',
      );
      expect(
        zankuFlickRightFoot.rotation,
        lessThan(zankuStampRightFoot.rotation - 0.12),
        reason:
            'the opposite foot should heel-flick during the F13 lift before '
            'both feet settle into the stamp',
      );
      const silverFlankerP = 10 / 32;
      const darkFlankerP = 13 / 32;
      final rightArmDelta =
          right.channels[CatBones.armUpperL]!.sample(darkFlankerP).rotation -
          leadChannels[CatBones.armUpperL]!.sample(darkFlankerP).rotation;
      final rightHandDelta =
          _targetFor(right, CatBones.handL).channel.sample(darkFlankerP).x -
          _targetFor(lead, CatBones.handL).channel.sample(darkFlankerP).x;
      final leftArmDeltaAtRightCue =
          left.channels[CatBones.armUpperR]!.sample(silverFlankerP).rotation -
          leadChannels[CatBones.armUpperR]!.sample(silverFlankerP).rotation;
      final leftHandDeltaAtRightCue =
          _targetFor(left, CatBones.handR).channel.sample(silverFlankerP).x -
          _targetFor(lead, CatBones.handR).channel.sample(silverFlankerP).x;
      expect(
        rightArmDelta,
        greaterThan(0.3),
        reason:
            'right-side answer should clearly feature the dark cat inside arm',
      );
      expect(rightHandDelta, greaterThan(16));
      expect(
        leftArmDeltaAtRightCue,
        lessThan(-0.22),
        reason:
            'the silver cat should answer earlier with its inside arm instead '
            'of matching the dark cat on the same frame',
      );
      expect(leftHandDeltaAtRightCue, lessThan(-15));

      final lungeAnticipation = lead.root.sample(13 / phrase.frameCount);
      final lungePeak = lead.root.sample(14 / phrase.frameCount);
      final lungeRecovery = lead.root.sample(15 / phrase.frameCount);
      final lungeSettle = lead.root.sample(17 / phrase.frameCount);
      expect(
        lungePeak.dy,
        greaterThan(lungeAnticipation.dy + 2),
        reason:
            'the right-side feature should compress into a real lunge instead '
            'of drifting through the camera move',
      );
      expect(
        lungePeak.dy,
        greaterThan(lungeRecovery.dy + 0.4),
        reason: 'the lunge should rebound through a visible recovery frame',
      );
      expect(
        lungeRecovery.dx,
        lessThan(lungeAnticipation.dx),
        reason:
            'the recovery should keep travelling across the lunge arc instead '
            'of snapping back to the anticipation side',
      );
      expect(
        lungeSettle.dx,
        lessThan(lungeRecovery.dx),
        reason: 'the lunge should settle over several frames, not teleport',
      );

      final rightFootCueP =
          phrase.moveAtFrame(20).accentFrame / phrase.frameCount;
      final rightSupportXs = [
        for (final frame in [16, 17, 18, 19, 20, 21, 22])
          leadFootRTarget.sample(frame / phrase.frameCount).x,
      ];
      expect(
        phrase.moveAtFrame(20).signature,
        contains('lifted free-left toe'),
      );
      expect(
        phrase.moveAtFrame(20).signature,
        contains('komole'),
      );
      expect(
        rightSupportXs.reduce(math.max) - rightSupportXs.reduce(math.min),
        lessThan(5),
        reason:
            'the right foot is the support during the answer pocket; it should '
            'hold while the free-left toe flicks instead of sliding backward',
      );
      expect(
        leadChannels[CatBones.hips]!.sample(rightFootCueP).rotation,
        lessThan(-0.42),
        reason: 'right-foot groove cue should visibly load the opposite hip',
      );
      final freeLeftFoot = _targetFor(
        lead,
        CatBones.footL,
      ).channel.sample(rightFootCueP);
      final grooveLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(rightFootCueP);
      final grooveRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(rightFootCueP);
      final centerSweepLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(19 / phrase.frameCount);
      final centerRollLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(22 / phrase.frameCount);
      final centerRollRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(22 / phrase.frameCount);
      final compactLegworkLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(21 / phrase.frameCount);
      final compactLegworkRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(21 / phrase.frameCount);
      final grooveToeIn = leadChannels[CatBones.footL]!.sample(
        20 / phrase.frameCount,
      );
      final grooveToeOut = leadChannels[CatBones.footL]!.sample(
        21 / phrase.frameCount,
      );
      final grooveRollReleaseP = 22 / phrase.frameCount;
      expect(
        freeLeftFoot.x,
        lessThan(-53),
        reason: 'free-left foot should flick outward in the right-foot groove',
      );
      expect(
        freeLeftFoot.y,
        lessThan(99),
        reason: 'free-left foot should lift instead of dragging at frame 20',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(rightFootCueP).rotation,
        greaterThan(0.23),
        reason:
            'right-foot groove should include a shoulder bite, not just a '
            'foot target',
      );
      expect(
        grooveLeftHand.x,
        lessThan(-55),
        reason:
            'left hand should punctuate the right-foot groove outside the '
            'belly silhouette',
      );
      expect(grooveLeftHand.y, lessThan(27));
      expect(
        grooveRightHand.x,
        greaterThan(70),
        reason:
            'right hand should answer the shoulder bite with a visible outward '
            'punctuation',
      );
      expect(grooveRightHand.y, lessThan(22));
      expect(
        centerSweepLeftHand.y,
        lessThan(18),
        reason:
            'the center close-up needs a visible chest-level hand sweep, not a '
            'left hand hovering down around the belly',
      );
      expect(
        centerRollLeftHand.y,
        lessThan(20),
        reason:
            'the shoulder-roll release should keep the left hand high enough '
            'to read in the torso close-up',
      );
      expect(
        centerRollRightHand.y,
        lessThan(18),
        reason:
            'the right hand should answer the center roll at chest level, not '
            'drop back to a low mascot pose',
      );
      expect(
        compactLegworkRightHand.x - compactLegworkLeftHand.x,
        lessThan(135),
        reason:
            'the legwork phrase should keep the hands compact near the ribs '
            'between big hits, not hold a generic boy-band wide arm shape',
      );
      expect(
        grooveToeOut.rotation - grooveToeIn.rotation,
        greaterThan(0.2),
        reason:
            'the right-foot groove should show free-left toe pivot texture, '
            'not just a foot target moving across the floor',
      );
      final groovePopP = 16 / phrase.frameCount;
      final grooveRecoilP = 17 / phrase.frameCount;
      final grooveStopP = 18 / phrase.frameCount;
      final grooveLoad = lead.root.sample(rightFootCueP);
      final komoleLowP = 21 / phrase.frameCount;
      final komoleLow = lead.root.sample(komoleLowP);
      final grooveRelease = lead.root.sample(22 / phrase.frameCount);
      expect(
        grooveLoad.dy,
        greaterThan(grooveRelease.dy + 2),
        reason:
            'F20 should visibly load into the planted right foot before the '
            'phrase rebounds; otherwise the footwork stays decorative',
      );
      expect(
        komoleLow.dy,
        greaterThan(grooveRelease.dy + 3),
        reason:
            'F21 should extend the right-foot groove into a real low komole '
            'dip before the F22 rebound',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(komoleLowP).scaleY,
        lessThan(0.915),
        reason:
            'the F21 komole dip needs a visibly compressed torso, not only a '
            'foot target or hand pose',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(grooveRollReleaseP).rotation,
        lessThan(
          leadChannels[CatBones.torso]!.sample(komoleLowP).rotation - 0.22,
        ),
        reason:
            'F22 should rebound out of the low komole dip with a clear chest '
            'pop in the opposite direction',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(groovePopP).rotation,
        greaterThan(
          leadChannels[CatBones.torso]!.sample(grooveRecoilP).rotation + 0.05,
        ),
        reason:
            'F16 should read as a chest pop before the frame-17 recoil, not '
            'one constant torso lean',
      );
      expect(
        lead.root.sample(grooveStopP).dy,
        greaterThan(lead.root.sample(grooveRecoilP).dy + 1),
        reason:
            'F18 should stop into a knee/hand hit after the recoil instead of '
            'floating into the groove pocket',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(grooveRollReleaseP).rotation,
        lessThan(
          leadChannels[CatBones.torso]!.sample(rightFootCueP).rotation - 0.14,
        ),
        reason:
            'after the F20 load, the close-up phrase should roll the chest back '
            'the other way instead of holding one long lean',
      );
      final grooveStopLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(grooveStopP);
      final grooveStopRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(grooveStopP);
      expect(
        grooveStopLeftHand.x,
        lessThan(-50),
        reason: 'the F18 stop needs the left hand outside the belly silhouette',
      );
      expect(
        grooveStopRightHand.x,
        greaterThan(70),
        reason:
            'the F18 stop needs a matching right-hand punctuation, not a '
            'single-arm pose',
      );
      final grooveHitLeftHand = _targetFor(
        lead,
        CatBones.handL,
      ).channel.sample(23 / phrase.frameCount);
      final grooveHitRightHand = _targetFor(
        lead,
        CatBones.handR,
      ).channel.sample(23 / phrase.frameCount);
      expect(
        grooveHitRightHand.x - grooveHitLeftHand.x,
        greaterThan(175),
        reason:
            'F23 should land as an all-crew outward hit before the left-side '
            'answer, not a hidden transition pose',
      );
      expect(
        grooveHitLeftHand.y,
        lessThan(13),
        reason:
            'the F23 outward hit should finish high in the close-up frame, not '
            'collapse back to waist height',
      );

      final leftCueP = phrase.moveAtFrame(24).accentFrame / phrase.frameCount;
      final leftArmDelta =
          left.channels[CatBones.armUpperR]!.sample(leftCueP).rotation -
          leadChannels[CatBones.armUpperR]!.sample(leftCueP).rotation;
      final leftHandDelta =
          _targetFor(left, CatBones.handR).channel.sample(leftCueP).x -
          _targetFor(lead, CatBones.handR).channel.sample(leftCueP).x;
      expect(
        leftArmDelta,
        lessThan(-0.2),
        reason:
            'left-side camera cue should feature the left dancer inside arm',
      );
      expect(leftHandDelta, lessThan(-10));
      expect(
        leadChannels[CatBones.hips]!.sample(leftCueP).rotation,
        lessThan(-0.22),
        reason:
            'left-side camera cue should also load the lead hip instead of '
            'becoming a backup-only arm feature',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(leftCueP).rotation,
        greaterThan(0.06),
        reason: 'lead chest should answer the loaded hip at the left-side cue',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(leftCueP).scaleY,
        lessThan(0.98),
        reason: 'left-side cue should stay in the pocket before the hook reset',
      );
      final stepTapDownbeat = lead.root.sample(24 / phrase.frameCount);
      final stepTapPushOff = lead.root.sample(26 / phrase.frameCount);
      expect(
        stepTapDownbeat.dy,
        greaterThan(stepTapPushOff.dy + 2.5),
        reason:
            'F24-F26 should read as downbeat settle then push-off, not an '
            'even floating glide into the hook reset',
      );
      final stepTapOut = leadFootLTarget.sample(25 / phrase.frameCount);
      final stepTapReturn = leadFootLTarget.sample(26 / phrase.frameCount);
      expect(
        stepTapOut.x,
        lessThan(-38),
        reason:
            'the F25 free-left step should travel visibly outward before the '
            'toe-flick release',
      );
      expect(
        stepTapReturn.y,
        greaterThan(104),
        reason:
            'the F26 free-left return should stay low enough to read as a '
            'tap/push-off rather than a hidden knee lift',
      );
      final supportX = [
        leadFootRTarget.sample(24 / phrase.frameCount).x,
        leadFootRTarget.sample(25 / phrase.frameCount).x,
        leadFootRTarget.sample(26 / phrase.frameCount).x,
        leadFootRTarget.sample(27 / phrase.frameCount).x,
        leadFootRTarget.sample(28 / phrase.frameCount).x,
      ];
      expect(
        supportX.reduce(math.max) - supportX.reduce(math.min),
        lessThan(8),
        reason:
            'right support should stay pinned through the step-tap downbeat '
            'before it releases into the loop pickup',
      );

      final hookP = phrase.moveAtFrame(31).accentFrame / phrase.frameCount;
      final leftSupportFoot = leadChannels[CatBones.footL]!.sample(0).rotation;
      final loopHome = lead.root.sample(0);
      expect(
        leadChannels[CatBones.footL]!.sample(hookP).rotation,
        greaterThan(leftSupportFoot + 0.28),
        reason: 'hook reset should retain a visible free-left toe flick',
      );
      expect(
        leadChannels[CatBones.armUpperL]!.sample(hookP).rotation,
        greaterThan(0.25),
        reason: 'hook reset should close back into a compact arm shape',
      );
      final hookPickupP = 31 / phrase.frameCount;
      final hookFreeze = lead.root.sample(hookPickupP);
      expect(
        leadChannels[CatBones.hips]!.sample(hookPickupP).rotation,
        greaterThan(0.28),
        reason:
            'hook reset should keep a hip pickup under the arms instead of '
            'ending as a neutral pose',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(hookPickupP).rotation,
        lessThan(-0.13),
        reason:
            'hook reset should finish with a counter-shoulder pickup, not a '
            'relaxed upper body before the loop',
      );
      expect(
        leadChannels[CatBones.hips]!.sample(hookPickupP).rotation -
            leadChannels[CatBones.hips]!
                .sample(30 / phrase.frameCount)
                .rotation,
        greaterThan(0.07),
        reason:
            'frame 31 should add a clear hip pickup after the frame 30 toe '
            'flick instead of flattening into the loop seam',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(hookPickupP).rotation -
            leadChannels[CatBones.torso]!
                .sample(30 / phrase.frameCount)
                .rotation,
        lessThan(-0.05),
        reason:
            'frame 31 should answer the hip pickup with stronger chest '
            'opposition, not a neutral reset',
      );
      expect(
        leadChannels[CatBones.torso]!.sample(hookPickupP).scaleY,
        lessThan(0.945),
        reason: 'hook reset should stay pocketed through the loop pickup',
      );
      expect(
        hookFreeze.dy,
        greaterThan(loopHome.dy + 1.2),
        reason:
            'the final hook should finish as a low freeze before the loop '
            'returns home, not fade into a neutral reset',
      );
    });

    test('dance keeps major phrase handoffs in continuous hand paths', () {
      final lead = CatClips.dance;
      final handL = _targetFor(lead, CatBones.handL).channel;
      final handR = _targetFor(lead, CatBones.handR).channel;
      final footL = _targetFor(lead, CatBones.footL).channel;

      expect(
        _targetDistance(handL, 12, 13),
        lessThan(9),
        reason:
            'the lead left hand should bridge the right-side answer instead of '
            'snapping back out after the rebound scoop',
      );
      expect(
        _targetDistance(handR, 15, 16),
        lessThan(20),
        reason:
            'the right-hand lift answer should hit as a pickup, not a teleport',
      );
      expect(
        _targetDistance(handL, 19, 20),
        lessThan(16),
        reason:
            'the right-foot groove shoulder bite should pull the left hand '
            'through a compact accent, not a jump',
      );
      expect(
        _targetDistance(handR, 19, 20),
        lessThan(13),
        reason:
            'the right-hand punctuation should be a readable wrist/shoulder '
            'hit without throwing the arm across the frame',
      );
      expect(
        _targetDistance(handR, 3, 4),
        lessThan(8),
        reason:
            'the opening right elbow lift should travel into the Shaku hit '
            'instead of popping from the base belly-height key',
      );
      expect(
        _targetDistance(handL, 28, 29),
        lessThan(10),
        reason: 'the hook reset should close in a readable hand arc',
      );
      expect(
        _targetDistance(handL, 31, 32),
        lessThan(11),
        reason:
            'the loop seam should bring the hand home without a one-frame jump',
      );
      expect(
        _targetDistance(handR, 31, 32),
        lessThan(9),
        reason:
            'the right hand should also close into F0 through a compact seam, '
            'not a visible reset',
      );
      expect(
        _targetDistance(footL, 28, 29),
        lessThan(15),
        reason: 'the toe-flick release should travel home over multiple frames',
      );
    });

    test('walk and run carry forward locomotion, stage moves do not', () {
      // The walk uses foot-locked locomotion (ground spans, no speed); the run
      // still uses a constant speed; kick/dance/idle animate in place.
      expect(CatClips.walk.locomotes, isTrue);
      expect(CatClips.walk.groundSpans, isNotEmpty);
      expect(CatClips.run.locomotionSpeed, greaterThan(0));
      expect(CatClips.run.locomotes, isTrue);
      expect(CatClips.kick.locomotes, isFalse);
      expect(CatClips.dance.locomotes, isFalse);
      expect(CatClips.idle.locomotes, isFalse);
    });
  });
}

LimbIkTarget _targetFor(Clip clip, String endBoneId) =>
    clip.limbTargets.singleWhere((target) => target.endBoneId == endBoneId);

double _targetDistance(IkTargetChannel channel, int fromFrame, int toFrame) {
  final from = channel.sample(fromFrame / CatClips.dancePhrase.frameCount);
  final to = channel.sample(toFrame / CatClips.dancePhrase.frameCount);
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  return math.sqrt(dx * dx + dy * dy);
}
