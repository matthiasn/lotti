import 'package:flutter_test/flutter_test.dart';
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
    });

    test(
      'backup dance clips share support timing and add bounded arm style',
      () {
        final lead = CatClips.dance;
        final left = CatClips.danceBackupLeft;
        final right = CatClips.danceBackupRight;
        const p = 7 / 12;

        expect(left.duration, lead.duration);
        expect(right.duration, lead.duration);
        expect(left.contactSpans, lead.contactSpans);
        expect(right.contactSpans, lead.contactSpans);
        expect(left.contactPinning, lead.contactPinning);
        expect(right.contactPinning, lead.contactPinning);
        expect(
          left.channels[CatBones.legUpperL]!.sample(p).rotation,
          closeTo(lead.channels[CatBones.legUpperL]!.sample(p).rotation, 1e-9),
        );
        expect(
          right.channels[CatBones.legUpperR]!.sample(p).rotation,
          closeTo(lead.channels[CatBones.legUpperR]!.sample(p).rotation, 1e-9),
        );
        expect(
          left.channels[CatBones.hips]!.sample(p).rotation,
          closeTo(lead.channels[CatBones.hips]!.sample(p).rotation, 1e-9),
        );
        expect(
          right.channels[CatBones.torso]!.sample(p).rotation,
          closeTo(lead.channels[CatBones.torso]!.sample(p).rotation, 1e-9),
        );
        final leftArmDelta =
            left.channels[CatBones.armUpperR]!.sample(p).rotation -
            lead.channels[CatBones.armUpperR]!.sample(p).rotation;
        final rightArmDelta =
            right.channels[CatBones.armUpperL]!.sample(p).rotation -
            lead.channels[CatBones.armUpperL]!.sample(p).rotation;
        expect(
          leftArmDelta.abs(),
          inInclusiveRange(0.005, 0.08),
          reason: 'left backup should vary its inside arm only slightly',
        );
        expect(
          rightArmDelta.abs(),
          inInclusiveRange(0.005, 0.08),
          reason: 'right backup should vary its inside arm only slightly',
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

        final compressionTorso = torso.sample(0);
        final pickupTorso = torso.sample(1 / 16);
        final nextQuarterCatchTorso = torso.sample(1 / 4);
        expect(pickupTorso.scaleY, greaterThan(compressionTorso.scaleY + 0.05));
        expect(
          nextQuarterCatchTorso.scaleY,
          lessThan(pickupTorso.scaleY - 0.05),
        );
        expect(hips.sample(0).rotation, greaterThan(0.28));
        expect(hips.sample(1 / 4).rotation, lessThan(-0.27));
        expect(torso.sample(0).rotation, lessThan(-0.12));
        expect(torso.sample(1 / 4).rotation, greaterThan(0.13));

        final leftSupportFoot = footL.sample(0).rotation;
        final rightFreeFoot = footR.sample(1 / 8).rotation;
        final rightSupportFoot = footR.sample(1 / 4).rotation;
        final leftFreeFoot = footL.sample(3 / 8).rotation;
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

        expect(armUpperL.sample(0).rotation, closeTo(0.22, 0.001));
        expect(armUpperR.sample(0).rotation, closeTo(-0.24, 0.001));
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
          inInclusiveRange(0.38, 0.6),
          reason:
              'the count-2 accent should stay compact at chest level instead '
              'of snapping to a vertical boy-band punch',
        );
        expect(
          armUpperR.sample(1 / 4).rotation,
          inInclusiveRange(-0.1, 0.08),
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
          armLowerL.sample(1 / 4).rotation,
          greaterThan(0.1),
          reason: 'the softened count-2 accent still bends the lead elbow',
        );
        expect(armLowerR.sample(1 / 4).rotation, greaterThan(0.2));
      },
    );

    test('dance pins alternating support feet across the two-bar phrase', () {
      final spans = CatClips.dance.contactSpans;
      expect(spans.map((span) => span.bone), [
        CatBones.footL,
        CatBones.footR,
        CatBones.footL,
        CatBones.footR,
        CatBones.footL,
      ]);
      expect(spans.map((span) => span.start), [
        0,
        1 / 4,
        1 / 2,
        3 / 4,
        15 / 16,
      ]);
      expect(spans.map((span) => span.end), [1 / 4, 1 / 2, 3 / 4, 15 / 16, 1]);
      expect(
        spans.take(4).map((span) => span.end - span.start),
        everyElement(greaterThanOrEqualTo(3 / 16)),
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
