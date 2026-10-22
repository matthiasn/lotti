import 'package:lotti/features/companion/model/companion_flourish.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';

/// How the companion stands for something: a mood for the face, and a
/// gesture she keeps up (`CompanionView.holding`) so it reads at a glance.
typedef CompanionCue = ({CompanionMood mood, GestureName? gesture});

/// How much sass she puts into a reaction: the person's choice, in
/// Settings › Preferences › Companion (`CompanionCustomization.sass`).
enum CompanionSass {
  /// Encouraging whatever happened: praise is a thumbs up, a slip a calm
  /// "it is all right". No frown, no eye roll.
  warm,

  /// Teasing: a smirk for good work, a raised brow and a wagging finger
  /// for a slip.
  cheeky,

  /// Full grandma: hands on hips, slow claps and eye rolls.
  sassy,
}

/// The lowest and highest [companionReaction] approval.
const int minApproval = -3;
const int maxApproval = 3;

/// How she reacts to work rated [approval], from [minApproval] (far off) to
/// [maxApproval] (outstanding), 0 being neither, with [sass].
///
/// [approval] is clamped to the scale. Disapproval never goes past sass:
/// she may frown, roll her eyes or put her hands on her hips, but she is
/// never hurt and never sad at you.
CompanionCue companionReaction(
  int approval, {
  CompanionSass sass = CompanionSass.warm,
}) => _reactions[sass]![approval.clamp(minApproval, maxApproval) - minApproval];

/// One row per sass level, from [minApproval] to [maxApproval].
const Map<CompanionSass, List<CompanionCue>> _reactions = {
  CompanionSass.warm: [
    (mood: CompanionMood.disappointed, gesture: GestureName.chest),
    (mood: CompanionMood.frazzled, gesture: GestureName.palmsDown),
    (mood: CompanionMood.busy, gesture: GestureName.think),
    (mood: CompanionMood.calm, gesture: null),
    (mood: CompanionMood.calm, gesture: GestureName.clap),
    (mood: CompanionMood.bright, gesture: GestureName.thumbs),
    (mood: CompanionMood.bright, gesture: GestureName.celebrate),
  ],
  CompanionSass.cheeky: [
    (mood: CompanionMood.stern, gesture: GestureName.fingerWag),
    (mood: CompanionMood.unimpressed, gesture: GestureName.shrug),
    (mood: CompanionMood.skeptical, gesture: GestureName.think),
    (mood: CompanionMood.calm, gesture: null),
    (mood: CompanionMood.smug, gesture: GestureName.clap),
    (mood: CompanionMood.proud, gesture: GestureName.thumbs),
    (mood: CompanionMood.delighted, gesture: GestureName.horns),
  ],
  CompanionSass.sassy: [
    (mood: CompanionMood.stern, gesture: GestureName.facepalm),
    (mood: CompanionMood.unimpressed, gesture: GestureName.handsOnHips),
    (mood: CompanionMood.skeptical, gesture: GestureName.eyeRoll),
    (mood: CompanionMood.smug, gesture: null),
    (mood: CompanionMood.smug, gesture: GestureName.slowClap),
    (mood: CompanionMood.proud, gesture: GestureName.handsOnHips),
    (mood: CompanionMood.delighted, gesture: GestureName.celebrate),
  ],
};

/// What a sentence turns on, read from its words (`readTones`): the moments
/// she pulls a face mid-read, whatever its tone.
enum SassBeat {
  /// It ends in a question mark.
  question,

  /// It ends in an exclamation mark.
  exclaim,

  /// It turns on a "but", "however", "aber": here comes the catch.
  turn,

  /// "Again", "still", "schon wieder": the same thing once more.
  again,

  /// "Finally", "at last", "endlich": the wait is over.
  atLast,
}

/// The face she pulls on [beat] in a sentence of [approval] (null where it
/// reads neither way), with [sass], or null for none.
///
/// [CompanionSass.warm] only ever tilts her head or lifts her brows; the
/// side-eye, the narrowed eyes and the look over the glasses are for
/// [CompanionSass.cheeky] and [CompanionSass.sassy]. Good news said "again"
/// or "still" is never scolded: "still on track" earns a smirk at most.
CompanionFlourish? companionBeat(
  SassBeat beat,
  int? approval, {
  CompanionSass sass = CompanionSass.warm,
}) {
  final good = (approval ?? 0) > 0;
  return switch ((sass, beat)) {
    (CompanionSass.warm, SassBeat.exclaim || SassBeat.atLast) =>
      CompanionFlourish.browPop,
    (CompanionSass.warm, _) => CompanionFlourish.headTilt,
    (CompanionSass.cheeky, SassBeat.question) => CompanionFlourish.oneBrow,
    (CompanionSass.cheeky, SassBeat.exclaim) =>
      good ? CompanionFlourish.smirk : CompanionFlourish.browPop,
    (CompanionSass.cheeky, SassBeat.turn) => CompanionFlourish.sideEye,
    (CompanionSass.cheeky, SassBeat.again) =>
      good ? null : CompanionFlourish.narrow,
    (CompanionSass.cheeky, SassBeat.atLast) => CompanionFlourish.smirk,
    (CompanionSass.sassy, SassBeat.question) => CompanionFlourish.narrow,
    (CompanionSass.sassy, SassBeat.exclaim) =>
      good ? CompanionFlourish.wink : CompanionFlourish.browPop,
    (CompanionSass.sassy, SassBeat.turn) => CompanionFlourish.sideEye,
    (CompanionSass.sassy, SassBeat.again) =>
      good ? CompanionFlourish.smirk : CompanionFlourish.overTheGlasses,
    (CompanionSass.sassy, SassBeat.atLast) => CompanionFlourish.oneBrow,
  };
}

/// Her last word once she has read something whose sentences rated
/// [approvals] (null for those that read neither way), with [sass]: a face
/// held a moment after the voice stops, or null for none.
///
/// All good news gets a wink (a smirk, sassy); only trouble gets a patient
/// head tilt, warm, a raised brow, cheeky, and the look over the glasses,
/// sassy; both gets the side-eye at full sass. Words that read neither way
/// leave her quiet.
CompanionFlourish? companionSignOff(
  Iterable<int?> approvals, {
  CompanionSass sass = CompanionSass.warm,
}) {
  final good = approvals.any((a) => (a ?? 0) > 0);
  final bad = approvals.any((a) => (a ?? 0) < 0);
  return switch ((sass, good, bad)) {
    (_, false, false) => null,
    (CompanionSass.warm, true, false) => CompanionFlourish.wink,
    (CompanionSass.warm, _, _) => CompanionFlourish.headTilt,
    (CompanionSass.cheeky, true, false) => CompanionFlourish.wink,
    (CompanionSass.cheeky, false, true) => CompanionFlourish.oneBrow,
    (CompanionSass.cheeky, _, _) => CompanionFlourish.smirk,
    (CompanionSass.sassy, true, false) => CompanionFlourish.smirk,
    (CompanionSass.sassy, false, true) => CompanionFlourish.overTheGlasses,
    (CompanionSass.sassy, _, _) => CompanionFlourish.sideEye,
  };
}
