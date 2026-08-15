/// Goal-named aliases for the kind-agnostic nudge vocabulary.
///
/// The vocabulary lived here goal-typed until ADR 0059 generalized it into
/// `nudge_models.dart` so a second agent kind can speak through the banner
/// channel. These aliases keep the goal feature's call sites compiling
/// unchanged during the migration; new code imports the shared names
/// directly. The aliases are pure renames — same types, same serialized
/// form — pinned by `test/classes/goal_nudge_models_test.dart`.
library;

import 'package:lotti/classes/nudge_models.dart';

export 'package:lotti/classes/nudge_models.dart';

typedef GoalNudgeTone = NudgeTone;
typedef GoalNudgeStatus = NudgeStatus;
typedef GoalBannerAnimation = NudgeBannerAnimation;
typedef GoalBannerAccent = NudgeBannerAccent;
typedef GoalBannerSnoozeDuration = NudgeBannerSnoozeDuration;
typedef GoalNudgeBrief = NudgeBrief;
typedef GoalNudgeRating = NudgeRating;
typedef GoalNudgeSnooze = NudgeSnooze;
typedef GoalNudgeDayDismissal = NudgeDayDismissal;

const NudgeBannerSnoozeDuration Function(Duration duration)
goalBannerSnoozeDurationFor = nudgeBannerSnoozeDurationFor;
const List<String> Function(Map<String, dynamic> json)
goalNudgeRatingJsonIssues = nudgeRatingJsonIssues;
const List<String> Function(Map<String, dynamic> json)
goalNudgeSnoozeJsonIssues = nudgeSnoozeJsonIssues;
const List<String> Function(Map<String, dynamic> json)
goalNudgeDayDismissalJsonIssues = nudgeDayDismissalJsonIssues;
