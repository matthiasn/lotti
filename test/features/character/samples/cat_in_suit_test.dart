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

    test('a white shirt collar frames the neck under the tie', () {
      final shirtColor = rig.bone(CatBones.shirtV)?.drawable?.color;
      for (final id in [CatBones.collarL, CatBones.collarR]) {
        final collar = rig.bone(id);
        expect(collar?.parent, CatBones.torso);
        // Same off-white shirt fabric as the chest V, so the head reads as
        // rising out of a collar rather than pasted onto the jacket.
        expect(collar?.drawable?.color, shirtColor);
        // Flat-shaded so the key can't streak the small bright shape.
        expect(collar?.drawable?.celShade, isFalse);
      }
      // The two points mirror left/right about the centreline.
      expect(
        rig.bone(CatBones.collarL)!.pivotX,
        -rig.bone(CatBones.collarR)!.pivotX,
      );
    });

    test('hand-parented cuffs expose the wrists during crossed-arm poses', () {
      final shirtColor = rig.bone(CatBones.shirtV)?.drawable?.color;
      final cuffL = rig.bone(CatBones.wristCuffL);
      final cuffR = rig.bone(CatBones.wristCuffR);

      expect(cuffL?.parent, CatBones.handL);
      expect(cuffR?.parent, CatBones.handR);
      expect(cuffL?.drawable?.color, shirtColor);
      expect(cuffR?.drawable?.color, shirtColor);
      expect(cuffL?.z, lessThan(rig.bone(CatBones.handL)!.z));
      expect(cuffR?.z, lessThan(rig.bone(CatBones.handR)!.z));
    });

    test('shoes carry a subtle sole edge for footwork readability', () {
      expect(rig.bone(CatBones.shoeHighlightL)?.parent, CatBones.footL);
      expect(rig.bone(CatBones.shoeHighlightR)?.parent, CatBones.footR);
      expect(rig.bone(CatBones.shoeHighlightL)?.drawable?.width, 23);
      // A subtle sole edge, NOT a bright strip that reads as a skeletal mark in
      // the stage-lit shoe.
      expect(rig.bone(CatBones.shoeHighlightR)?.drawable?.color, 0xFF3C4058);
    });

    test('the sole edge never lowers the shoe contact point', () {
      // The contact/grounding solver keys off the lowest drawn point of the
      // foot; the sole-edge highlight must stay above the sole bottom so it
      // can't shift grounding or the support-foot lock.
      for (final pair in const [
        (CatBones.footR, CatBones.shoeHighlightR),
        (CatBones.footL, CatBones.shoeHighlightL),
      ]) {
        final shoe = rig.bone(pair.$1)!.drawable!;
        final welt = rig.bone(pair.$2)!.drawable!;
        expect(
          welt.dy + welt.height / 2,
          lessThan(shoe.dy + shoe.height / 2),
          reason: 'sole edge stays above the sole bottom',
        );
      }
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

      // Anatomical trouser profile: full thigh (13.5/13), a knee dip (11.5), a
      // calf bulge (12.5), then a narrow ankle (8) tapering into the shoe so the
      // trouser breaks over the foot, not past it.
      expect(baseLeg.halfWidths, const [13.5, 13, 11.5, 12.5, 8]);
      expect(
        leadLeg.halfWidths.first,
        closeTo(13.5 * kDanceLeadLegWidthScale, 0.001),
      );
      // The calf control (index 3) is fuller than the knee (index 2) — the bulge.
      expect(
        leadLeg.halfWidths[3],
        closeTo(12.5 * kDanceLeadLegWidthScale, 0.001),
      );
      expect(
        leadLeg.halfWidths[3],
        greaterThan(leadLeg.halfWidths[2]),
        reason: 'the calf must bulge past the knee dip',
      );
      expect(baseArm.halfWidths, const [11.0, 12.6, 7.6, 4.6]);
      expect(
        leadArm.halfWidths[1],
        closeTo(12.6 * kDanceLeadArmWidthScale, 0.001),
      );
      expect(leadTail.halfWidths, baseTail.halfWidths);
    });
  });

  group('CatClips', () {
    test('exposes the show-focused public motion set', () {
      expect(
        CatClips.all.map((c) => c.name).toSet(),
        {
          'kick',
          'shaku',
          'zanku',
          'azonto',
          'buga',
          'pouncingCat',
          'sekem',
          'idle',
        },
      );
    });

    test('cyclic clips loop and one-shots do not', () {
      expect(CatClips.shaku.loop, isTrue);
      expect(CatClips.zanku.loop, isTrue);
      expect(CatClips.azonto.loop, isTrue);
      expect(CatClips.buga.loop, isTrue);
      expect(CatClips.pouncingCat.loop, isTrue);
      expect(CatClips.sekem.loop, isTrue);
      expect(CatClips.idle.loop, isTrue);
      expect(CatClips.kick.loop, isFalse);
    });

    test('shaku drives both legs and both arms', () {
      final channels = CatClips.shaku.channels;
      expect(channels.containsKey(CatBones.legUpperL), isTrue);
      expect(channels.containsKey(CatBones.legUpperR), isTrue);
      expect(channels.containsKey(CatBones.armUpperL), isTrue);
      expect(channels.containsKey(CatBones.armUpperR), isTrue);
    });

    test('kick and shaku drive the expected performance bones', () {
      expect(CatClips.kick.channels.containsKey(CatBones.legUpperR), isTrue);
      expect(CatClips.kick.channels.containsKey(CatBones.armUpperL), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.legUpperL), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.armLowerR), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.tail6), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.earL), isTrue);
      expect(CatClips.shaku.channels.containsKey(CatBones.earR), isTrue);
      expect(
        CatClips.shaku.limbTargets.map((target) => target.endBoneId),
        [CatBones.handL, CatBones.handR, CatBones.footL, CatBones.footR],
      );
    });

    test('shaku ears flick independently while staying bounded', () {
      final earL = CatClips.shaku.channels[CatBones.earL]!;
      final earR = CatClips.shaku.channels[CatBones.earR]!;
      var minL = double.infinity;
      var maxL = double.negativeInfinity;
      var minR = double.infinity;
      var maxR = double.negativeInfinity;
      var maxPairDifference = 0.0;

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
      }

      expect(
        maxL - minL,
        greaterThan(0.02),
        reason: 'left ear should keep a subtle bounded flick',
      );
      expect(
        maxR - minR,
        greaterThan(0.02),
        reason: 'right ear should keep a subtle bounded flick',
      );
      expect(
        maxPairDifference,
        greaterThan(0.03),
        reason: 'ears should not move as a mirrored rigid head ornament',
      );
      expect(
        [minL.abs(), maxL.abs(), minR.abs(), maxR.abs()],
        everyElement(lessThan(0.16)),
        reason:
            'ear flicks must stay subtle enough that the deep bases remain '
            'hidden behind the crown',
      );
    });

    test(
      'backup dance clips remain public show-role clips',
      () {
        expect(CatClips.danceBackupLeft.name, 'danceBackupLeft');
        expect(CatClips.danceBackupRight.name, 'danceBackupRight');
        expect(CatClips.danceBackupLeft.duration, CatClips.shaku.duration);
        expect(CatClips.danceBackupRight.duration, CatClips.shaku.duration);
      },
    );

    test('dance holds broad Shaku supports across the phrase', () {
      final phrase = CatClips.dancePhrase;
      final spans = CatClips.shaku.contactSpans;
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

    test('shaku crosses wrists, opens elbows, and recovers as shaku', () {
      final phrase = CatClips.dancePhrase;
      final shaku = CatClips.shaku;
      final handL = _targetFor(shaku, CatBones.handL).channel;
      final handR = _targetFor(shaku, CatBones.handR).channel;

      final wristCrossLeft = handL.sample(17 / phrase.frameCount);
      final wristCrossRight = handR.sample(17 / phrase.frameCount);
      expect(wristCrossLeft.x, greaterThan(6));
      expect(wristCrossRight.x, lessThan(-6));
      expect(
        (wristCrossLeft.x - wristCrossRight.x).abs(),
        lessThan(32),
        reason:
            'Shaku should cross the wrists near the sternum, not fold both '
            'forearms back through the belly',
      );
      expect(
        wristCrossLeft.y,
        lessThan(-42),
        reason: 'the wrist-cross should live at chest height',
      );

      final openLeft = handL.sample(21 / phrase.frameCount);
      final openRight = handR.sample(21 / phrase.frameCount);
      expect(openLeft.x, lessThan(-42));
      expect(openRight.x, greaterThan(42));
      expect(
        openRight.x - openLeft.x,
        greaterThan(90),
        reason:
            'after the wrist-cross both elbows should open outward so the arms '
            'remain physically possible',
      );

      final sideHitLeft = handL.sample(22 / phrase.frameCount);
      final sideHitRight = handR.sample(22 / phrase.frameCount);
      expect(sideHitLeft.x, lessThan(-48));
      expect(sideHitRight.x, greaterThan(48));
      expect(
        sideHitRight.x - sideHitLeft.x,
        greaterThan(96),
        reason:
            'the Shaku release should be an outside sweep/hit rather than a '
            'held folded-arm pose',
      );

      final recoveryCrossLeft = handL.sample(29 / phrase.frameCount);
      final recoveryCrossRight = handR.sample(29 / phrase.frameCount);
      expect(
        recoveryCrossLeft.x,
        lessThan(-35),
        reason:
            'the final phrase should recover through shaku arm vocabulary, '
            'not a generic forward punch',
      );
      expect(recoveryCrossLeft.y, lessThan(-45));
      expect(
        recoveryCrossRight.x,
        greaterThan(35),
        reason:
            'the opposite paw should open as part of the shaku recovery, '
            'not stay parked at the chest',
      );
      expect(recoveryCrossRight.y, lessThan(-39));
      expect(
        recoveryCrossRight.x - recoveryCrossLeft.x,
        greaterThan(70),
        reason: 'the final recovery should keep a readable open arm silhouette',
      );

      expect(
        _targetDistance(handL, 28, 29),
        lessThan(36),
        reason:
            'the final shaku recovery should travel smoothly instead of '
            'snapping through the loop pickup',
      );

      final loopLeft = handL.sample(32 / phrase.frameCount);
      final loopRight = handR.sample(32 / phrase.frameCount);
      expect(loopLeft.x, lessThan(-25));
      expect(loopRight.x, greaterThan(25));
      expect(
        loopLeft.y,
        greaterThan(-36),
        reason: 'the next loop should recover to the low open-ready left hand',
      );
      expect(
        loopRight.y,
        greaterThan(-36),
        reason: 'the opposite hand should recover to the low open-ready guard',
      );
    });

    test(
      'buga keeps prep hands separated instead of folding arms through belly',
      () {
        final phrase = CatClips.dancePhrase;
        final buga = CatClips.buga;
        final handL = _targetFor(buga, CatBones.handL).channel;
        final handR = _targetFor(buga, CatBones.handR).channel;

        for (final frame in [0, 4, 8, 11, 16, 20, 24, 27]) {
          final p = frame / phrase.frameCount;
          final left = handL.sample(p);
          final right = handR.sample(p);

          expect(
            right.x - left.x,
            greaterThan(55),
            reason:
                'Buga prep frame $frame should keep hands as separated rib '
                'guards, not a centreline clasp that implies impossible elbows',
          );
          expect(
            left.y,
            lessThan(-25),
            reason: 'left hand should stay above the belt on prep frame $frame',
          );
          expect(
            right.y,
            lessThan(-25),
            reason:
                'right hand should stay above the belt on prep frame $frame',
          );
        }

        final rightPresentOffHand = handL.sample(12 / phrase.frameCount);
        expect(
          rightPresentOffHand.x,
          lessThan(-40),
          reason:
              'when the right arm presents, the left hand must drop outside/back '
              'instead of clasping at the belly',
        );
        expect(rightPresentOffHand.y, lessThan(-24));

        final leftPresentOffHand = handR.sample(28 / phrase.frameCount);
        expect(
          leftPresentOffHand.x,
          greaterThan(40),
          reason:
              'when the left arm presents, the right hand must drop outside/back '
              'instead of clasping at the belly',
        );
        expect(leftPresentOffHand.y, lessThan(-24));
      },
    );

    test('buga raises the presenting arm before the hit and holds it', () {
      final phrase = CatClips.dancePhrase;
      final buga = CatClips.buga;
      final handL = _targetFor(buga, CatBones.handL).channel;
      final handR = _targetFor(buga, CatBones.handR).channel;

      for (final frame in [10, 12, 15]) {
        final right = handR.sample(frame / phrase.frameCount);
        expect(
          right.x,
          greaterThan(68),
          reason: 'right Buga present should be visible by frame $frame',
        );
        expect(right.y, lessThan(-64));
      }

      for (final frame in [26, 28, 31]) {
        final left = handL.sample(frame / phrase.frameCount);
        expect(
          left.x,
          lessThan(-68),
          reason: 'left Buga present should be visible by frame $frame',
        );
        expect(left.y, lessThan(-64));
      }
    });

    test('pouncing cat keeps the cat flavor inside a compact groove', () {
      final phrase = CatClips.dancePhrase;
      final pounce = CatClips.pouncingCat;
      final handL = _targetFor(pounce, CatBones.handL).channel;
      final handR = _targetFor(pounce, CatBones.handR).channel;
      final footL = _targetFor(pounce, CatBones.footL).channel;
      final footR = _targetFor(pounce, CatBones.footR).channel;

      final lowPocket = pounce.root.sample(4 / phrase.frameCount);
      final rebound = pounce.root.sample(6 / phrase.frameCount);
      final rightSettle = pounce.root.sample(12 / phrase.frameCount);
      final secondLaunch = pounce.root.sample(24 / phrase.frameCount);

      expect(
        lowPocket.dy - rebound.dy,
        greaterThan(14),
        reason: 'the cat groove needs a visible down-up bounce, not a glide',
      );
      expect(
        rightSettle.dx,
        greaterThan(12),
        reason: 'the compact pounce should settle to the right side',
      );
      expect(
        secondLaunch.dx,
        lessThan(-12),
        reason: 'the mirrored pounce should spring back to the left side',
      );

      final launchLeft = handL.sample(8 / phrase.frameCount);
      final launchRight = handR.sample(8 / phrase.frameCount);
      expect(launchLeft.x, greaterThan(20));
      expect(launchRight.x, greaterThan(80));
      expect(launchLeft.y, lessThan(-55));
      expect(launchRight.y, lessThan(-42));

      for (final frame in [4, 12, 20, 28]) {
        final p = frame / phrase.frameCount;
        final leftFoot = footL.sample(p);
        final rightFoot = footR.sample(p);
        expect(
          rightFoot.x - leftFoot.x,
          greaterThan(58),
          reason: 'pounce frame $frame needs a stable stance, not crossed feet',
        );
        expect(
          leftFoot.y,
          greaterThan(97),
          reason: 'pounce frame $frame should stay grounded on the left foot',
        );
        expect(
          rightFoot.y,
          greaterThan(97),
          reason: 'pounce frame $frame should stay grounded on the right foot',
        );
      }
      expect(
        _targetDistance(handL, 12, 16),
        lessThan(90),
        reason:
            'pounce should rebound into groove rather than teleporting arms',
      );
    });

    test('show clips animate in place', () {
      expect(CatClips.kick.locomotes, isFalse);
      expect(CatClips.shaku.locomotes, isFalse);
      expect(CatClips.zanku.locomotes, isFalse);
      expect(CatClips.azonto.locomotes, isFalse);
      expect(CatClips.buga.locomotes, isFalse);
      expect(CatClips.pouncingCat.locomotes, isFalse);
      expect(CatClips.sekem.locomotes, isFalse);
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
