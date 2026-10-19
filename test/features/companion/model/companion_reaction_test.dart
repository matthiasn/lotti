import 'package:flutter_test/flutter_test.dart';
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
}
