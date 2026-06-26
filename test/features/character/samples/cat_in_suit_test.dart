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
        const rightFeatureP = 3 / 8;
        const leftFeatureP = 3 / 4;

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
        final leadHandRFirstAnswer = _targetFor(
          lead,
          CatBones.handR,
        ).channel.sample(3 / 8);
        final leftHandRFirstAnswer = _targetFor(
          left,
          CatBones.handR,
        ).channel.sample(3 / 8);
        final leadHandLFirstAnswer = _targetFor(
          lead,
          CatBones.handL,
        ).channel.sample(3 / 8);
        final rightHandLFirstAnswer = _targetFor(
          right,
          CatBones.handL,
        ).channel.sample(3 / 8);
        expect(leftHandR.x, closeTo(leadHandR.x - 12, 0.001));
        expect(leftHandR.y, closeTo(leadHandR.y - 7, 0.001));
        expect(rightHandL.x, closeTo(leadHandL.x + 1.35, 0.001));
        expect(rightHandL.y, closeTo(leadHandL.y - 0.81, 0.001));
        expect(
          leftHandRFirstAnswer.x,
          closeTo(leadHandRFirstAnswer.x - 0.48, 0.001),
        );
        expect(
          leftHandRFirstAnswer.y,
          closeTo(leadHandRFirstAnswer.y - 0.36, 0.001),
        );
        expect(
          rightHandLFirstAnswer.x,
          closeTo(leadHandLFirstAnswer.x + 9, 0.001),
        );
        expect(
          rightHandLFirstAnswer.y,
          closeTo(leadHandLFirstAnswer.y - 6, 0.001),
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
            right.channels[CatBones.torso]!.sample(rightFeatureP).rotation -
            lead.channels[CatBones.torso]!.sample(rightFeatureP).rotation;
        final leftArmDelta =
            left.channels[CatBones.armUpperR]!.sample(leftFeatureP).rotation -
            lead.channels[CatBones.armUpperR]!.sample(leftFeatureP).rotation;
        final rightArmDelta =
            right.channels[CatBones.armUpperL]!.sample(rightFeatureP).rotation -
            lead.channels[CatBones.armUpperL]!.sample(rightFeatureP).rotation;
        expect(
          leftHipDelta.abs(),
          inInclusiveRange(0.04, 0.12),
          reason:
              'left backup should answer with a visible hip variation when '
              'the camera pans left',
        );
        expect(
          rightTorsoDelta.abs(),
          inInclusiveRange(0.03, 0.12),
          reason:
              'right backup should answer with a visible chest variation when '
              'the camera pans right',
        );
        expect(
          leftArmDelta.abs(),
          inInclusiveRange(0.08, 0.32),
          reason: 'left backup should feature its inside arm on the left pass',
        );
        expect(
          rightArmDelta.abs(),
          inInclusiveRange(0.08, 0.28),
          reason:
              'right backup should feature its inside arm on the right pass',
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

        final leftSupportFoot = footL.sample(0).rotation;
        final rightFreeFoot = footR.sample(1 / 8).rotation;
        final rightSupportFoot = footR.sample(5 / 8).rotation;
        final leftFreeFoot = footL.sample(5 / 8).rotation;
        final leftReleaseFoot = footL.sample(7 / 8).rotation;
        expect(leftSupportFoot, closeTo(-0.08, 0.001));
        expect(rightSupportFoot, closeTo(-0.08, 0.001));
        expect(rightFreeFoot, greaterThan(rightSupportFoot + 0.45));
        expect(
          leftFreeFoot,
          inInclusiveRange(leftSupportFoot + 0.35, leftSupportFoot + 0.56),
          reason:
              'the left toe accent should read as compact Afrobeats texture, '
              'not a large flick that pulls the foot across the body',
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

      final rightCueP = phrase.moveAtFrame(12).accentFrame / phrase.frameCount;
      final rightArmDelta =
          right.channels[CatBones.armUpperL]!.sample(rightCueP).rotation -
          leadChannels[CatBones.armUpperL]!.sample(rightCueP).rotation;
      final rightHandDelta =
          _targetFor(right, CatBones.handL).channel.sample(rightCueP).x -
          _targetFor(lead, CatBones.handL).channel.sample(rightCueP).x;
      expect(
        rightArmDelta,
        greaterThan(0.15),
        reason:
            'right-side camera cue should feature the right dancer inside arm',
      );
      expect(rightHandDelta, greaterThan(8));

      final rightFootCueP =
          phrase.moveAtFrame(20).accentFrame / phrase.frameCount;
      expect(
        leadChannels[CatBones.hips]!.sample(rightFootCueP).rotation,
        lessThan(-0.35),
        reason: 'right-foot groove cue should visibly load the opposite hip',
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

      final hookP = phrase.moveAtFrame(31).accentFrame / phrase.frameCount;
      final leftSupportFoot = leadChannels[CatBones.footL]!.sample(0).rotation;
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
