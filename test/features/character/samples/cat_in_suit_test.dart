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
      'backup dance clips keep footwork synced but answer with body canon',
      () {
        final lead = CatClips.dance;
        final left = CatClips.danceBackupLeft;
        final right = CatClips.danceBackupRight;
        const p = 7 / 12;

        expect(left.duration, lead.duration);
        expect(right.duration, lead.duration);
        expect(left.contactSpans, lead.contactSpans);
        expect(right.contactSpans, lead.contactSpans);
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
          closeTo(
            lead.channels[CatBones.hips]!.sample(p + 1 / 36).rotation,
            0.02,
          ),
        );
        expect(
          right.channels[CatBones.hips]!.sample(p).rotation,
          closeTo(
            lead.channels[CatBones.hips]!.sample(p + 1 / 36).rotation,
            0.02,
          ),
        );
        expect(
          left.channels[CatBones.armUpperL]!.sample(p).rotation,
          isNot(
            closeTo(
              lead.channels[CatBones.armUpperL]!.sample(p).rotation,
              1e-9,
            ),
          ),
        );
        expect(
          right.channels[CatBones.armUpperR]!.sample(p).rotation,
          isNot(
            closeTo(
              lead.channels[CatBones.armUpperR]!.sample(p).rotation,
              1e-9,
            ),
          ),
        );
      },
    );

    test('dance keeps body, feet, and hands alive between count hits', () {
      final channels = CatClips.dance.channels;
      final torso = channels[CatBones.torso]!;
      final foot = channels[CatBones.footL]!;
      final hand = channels[CatBones.armLowerL]!;

      final countStartTorso = torso.sample(0);
      final offBeatTorso = torso.sample(1 / 24);
      final countEndTorso = torso.sample(1 / 12);
      expect(offBeatTorso.scaleY, greaterThan(countStartTorso.scaleY + 0.03));
      expect(offBeatTorso.scaleY, greaterThan(countEndTorso.scaleY + 0.015));

      final countStartFoot = foot.sample(0).rotation;
      final offBeatFoot = foot.sample(1 / 24).rotation;
      final countEndFoot = foot.sample(1 / 12).rotation;
      expect(offBeatFoot, lessThan(countStartFoot - 0.1));
      expect(offBeatFoot, lessThan(countEndFoot - 0.1));

      final countStartHand = hand.sample(0).rotation;
      final offBeatHand = hand.sample(1 / 24).rotation;
      final countEndHand = hand.sample(1 / 12).rotation;
      expect(offBeatHand, greaterThan(countStartHand + 0.1));
      expect(offBeatHand, greaterThan(countEndHand + 0.3));
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
