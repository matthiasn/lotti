import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_flourish.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';

/// Her smile for a cue, idle: the base 0.5, the mood's and the gesture's.
double _smile(CompanionCue cue) =>
    0.5 + cue.mood.smile + (cue.gesture?.gesture.smile ?? 0);

const Set<GestureName> _sassyGestures = {
  GestureName.handsOnHips,
  GestureName.fingerWag,
  GestureName.shrug,
  GestureName.facepalm,
  GestureName.slowClap,
  GestureName.eyeRoll,
};

void main() {
  test(
    'neutral approval is calm unless she is sassy, and gestures nothing',
    () {
      expect(companionReaction(0), (mood: CompanionMood.calm, gesture: null));
      expect(
        companionReaction(0, sass: CompanionSass.cheeky),
        (mood: CompanionMood.calm, gesture: null),
      );
      expect(
        companionReaction(0, sass: CompanionSass.sassy),
        (mood: CompanionMood.smug, gesture: null),
      );
    },
  );

  test('approval outside the scale is clamped to its ends', () {
    for (final sass in CompanionSass.values) {
      expect(
        companionReaction(99, sass: sass),
        companionReaction(maxApproval, sass: sass),
      );
      expect(
        companionReaction(-99, sass: sass),
        companionReaction(minApproval, sass: sass),
      );
    }
  });

  test('her smile never falls as approval rises, at any sass', () {
    for (final sass in CompanionSass.values) {
      for (var a = minApproval + 1; a <= maxApproval; a++) {
        expect(
          _smile(companionReaction(a, sass: sass)),
          greaterThanOrEqualTo(_smile(companionReaction(a - 1, sass: sass))),
          reason: '${sass.name} at $a',
        );
      }
    }
  });

  test('praise smiles and disapproval does not, at every sass', () {
    for (final sass in CompanionSass.values) {
      expect(
        _smile(companionReaction(maxApproval, sass: sass)),
        greaterThan(1),
      );
      expect(_smile(companionReaction(minApproval, sass: sass)), lessThan(0));
    }
  });

  test('warm never reaches for a sassy gesture or a sassy face', () {
    for (var a = minApproval; a <= maxApproval; a++) {
      final cue = companionReaction(a);
      expect(_sassyGestures, isNot(contains(cue.gesture)), reason: '$a');
      expect(
        [
          CompanionMood.smug,
          CompanionMood.skeptical,
          CompanionMood.unimpressed,
          CompanionMood.stern,
        ],
        isNot(contains(cue.mood)),
        reason: '$a',
      );
    }
  });

  test('every sassy gesture is reached at some sass and approval', () {
    final reached = {
      for (final sass in CompanionSass.values)
        for (var a = minApproval; a <= maxApproval; a++)
          companionReaction(a, sass: sass).gesture,
    };
    expect(reached, containsAll(_sassyGestures));
  });

  test('the sassier she is, the more of her reactions are lopsided or '
      'sassy', () {
    int sassiness(CompanionSass sass) =>
        [
              for (var a = minApproval; a <= maxApproval; a++)
                companionReaction(a, sass: sass),
            ]
            .where(
              (c) =>
                  _sassyGestures.contains(c.gesture) ||
                  c.mood.smileSkew != 0 ||
                  c.mood.browSkew != 0,
            )
            .length;
    expect(sassiness(CompanionSass.warm), 0);
    expect(
      sassiness(CompanionSass.cheeky),
      lessThan(sassiness(CompanionSass.sassy)),
    );
  });

  /// The faces that tease: never [CompanionSass.warm]'s.
  const teasing = {
    CompanionFlourish.sideEye,
    CompanionFlourish.narrow,
    CompanionFlourish.overTheGlasses,
  };

  group('companionBeat', () {
    test('warm only tilts her head or lifts her brows', () {
      for (final beat in SassBeat.values) {
        for (final a in [-2, null, 2]) {
          expect(
            companionBeat(beat, a),
            isIn([CompanionFlourish.headTilt, CompanionFlourish.browPop]),
            reason: '$beat at $a',
          );
        }
      }
    });

    test('good news said again is never scolded, at any sass', () {
      for (final sass in CompanionSass.values) {
        final face = companionBeat(SassBeat.again, 2, sass: sass);
        expect(teasing, isNot(contains(face)), reason: sass.name);
      }
    });

    test('a slip said again gets the look over the glasses, sassy', () {
      expect(
        companionBeat(SassBeat.again, -2, sass: CompanionSass.sassy),
        CompanionFlourish.overTheGlasses,
      );
      expect(
        companionBeat(SassBeat.again, -2, sass: CompanionSass.cheeky),
        CompanionFlourish.narrow,
      );
    });

    test('the catch gets the side-eye once she is cheeky', () {
      for (final sass in [CompanionSass.cheeky, CompanionSass.sassy]) {
        expect(
          companionBeat(SassBeat.turn, null, sass: sass),
          CompanionFlourish.sideEye,
        );
      }
    });

    test('praise exclaimed earns a wink at full sass, a smirk cheeky', () {
      expect(
        companionBeat(SassBeat.exclaim, 3, sass: CompanionSass.sassy),
        CompanionFlourish.wink,
      );
      expect(
        companionBeat(SassBeat.exclaim, 3, sass: CompanionSass.cheeky),
        CompanionFlourish.smirk,
      );
      expect(
        companionBeat(SassBeat.exclaim, null, sass: CompanionSass.sassy),
        CompanionFlourish.browPop,
      );
    });

    test('the sassier she is, the more of her beats tease', () {
      int teases(CompanionSass sass) => [
        for (final beat in SassBeat.values)
          for (final a in [-2, null, 2]) companionBeat(beat, a, sass: sass),
      ].where(teasing.contains).length;
      expect(teases(CompanionSass.warm), 0);
      expect(
        teases(CompanionSass.cheeky),
        lessThan(teases(CompanionSass.sassy)),
      );
    });
  });

  group('companionSignOff', () {
    test('words that read neither way leave her quiet', () {
      for (final sass in CompanionSass.values) {
        expect(companionSignOff(const [null, null], sass: sass), isNull);
        expect(companionSignOff(const [], sass: sass), isNull);
      }
    });

    test('all good news: a wink, or a smirk at full sass', () {
      expect(companionSignOff(const [null, 2]), CompanionFlourish.wink);
      expect(
        companionSignOff(const [2, 3], sass: CompanionSass.cheeky),
        CompanionFlourish.wink,
      );
      expect(
        companionSignOff(const [2], sass: CompanionSass.sassy),
        CompanionFlourish.smirk,
      );
    });

    test('only trouble: patient, a raised brow, the look over the glasses', () {
      expect(companionSignOff(const [-2]), CompanionFlourish.headTilt);
      expect(
        companionSignOff(const [-2], sass: CompanionSass.cheeky),
        CompanionFlourish.oneBrow,
      );
      expect(
        companionSignOff(const [-2], sass: CompanionSass.sassy),
        CompanionFlourish.overTheGlasses,
      );
    });

    test('both: the side-eye at full sass, never a tease when warm', () {
      const mixed = [2, null, -1];
      expect(companionSignOff(mixed), CompanionFlourish.headTilt);
      expect(
        companionSignOff(mixed, sass: CompanionSass.cheeky),
        CompanionFlourish.smirk,
      );
      expect(
        companionSignOff(mixed, sass: CompanionSass.sassy),
        CompanionFlourish.sideEye,
      );
    });
  });
}
