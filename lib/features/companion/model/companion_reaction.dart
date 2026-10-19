import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';

/// How the companion stands for something: a mood for the face, and a
/// gesture she keeps up (`CompanionView.holding`) so it reads at a glance.
typedef CompanionCue = ({CompanionMood mood, GestureName? gesture});

/// How much sass she puts into a reaction. The user's choice, in time; for
/// now every host reacts [warm].
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
