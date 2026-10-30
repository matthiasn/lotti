import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';

/// Provenance keys for banner words that may name what the user wrote.
///
/// A banner is seen outside its subject — on the day page, in the dock — so
/// its stored [NudgeBrief] holds words safe anywhere, and the words drawn from
/// the user's own entries ride beside it in provenance. Anything that reads
/// the brief without knowing this — history, ratings, an OS alert — shows the
/// safe words; only a banner rendered by [nudgeDisplayBrief] shows the rest.
const nudgePrivateHeadlineKey = 'privateHeadline';
const nudgePrivateTaglineKey = 'privateTagline';

/// The brief a banner shows: its private words while the user shows private
/// entries (the `private` config flag), its stored brief otherwise.
NudgeBrief nudgeDisplayBrief(
  NudgeEntityView nudge, {
  required bool showPrivate,
}) {
  final headline = nudge.provenance[nudgePrivateHeadlineKey];
  if (!showPrivate || headline == null || headline.trim().isEmpty) {
    return nudge.brief;
  }
  return nudge.brief.copyWith(
    headline: headline,
    tagline: nudge.provenance[nudgePrivateTaglineKey],
  );
}
