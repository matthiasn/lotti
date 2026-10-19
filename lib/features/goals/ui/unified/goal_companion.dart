import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The utterance the companion speaks a goal agent's report under — on its
/// detail card and on her full-screen stage — so the read-aloud control and
/// her mouth follow the same playback, apart from any task's or day's.
String goalReportSpeechSourceId(String agentId) => 'goal-report:$agentId';

/// How the companion stands for a goal's track status, on her reaction scale
/// (`companionReaction`) at its warm end — the record without guilt: doing
/// well brightens her, a goal slipping gives her pause, one off track has
/// her say it is all right, never scold, and a goal with nothing to judge yet
/// has her listening for news.
///
/// The `gesture` carries the verdict at a glance: on a 40-pixel tile her
/// face's moods are a few pixels apart, while a raised thumb or a hand at
/// her ear reads at once. The `mood` layers the face on top.
///
/// Read from the deterministic `GoalTrackStatus` rather than the four-state
/// list pill, so a goal on its way back (`recovering`) reads differently
/// from one newly at risk though both wear the same "At risk" pill.
///
/// While the health is not [resolved] she stands calm and at ready, so she
/// never flashes a verdict the card has not reached.
CompanionCue goalCompanionPose(
  GoalTrackStatus? status, {
  required bool resolved,
}) {
  if (!resolved) return (mood: CompanionMood.calm, gesture: null);
  return switch (status) {
    GoalTrackStatus.achieved => companionReaction(3),
    GoalTrackStatus.onTrack => companionReaction(2),
    GoalTrackStatus.recovering => companionReaction(1),
    GoalTrackStatus.atRisk => companionReaction(-1),
    GoalTrackStatus.offTrack => companionReaction(-2),
    GoalTrackStatus.insufficientData || null => (
      mood: CompanionMood.sleepy,
      gesture: GestureName.listen,
    ),
  };
}

/// The companion's bust in the goal card's leading slot, in place of the
/// persona monogram: a [ControlSizes.avatarCompact] tile on the goal's
/// status wash, so the card keeps its status tint and gains a figure whose
/// pose says how the goal is going ([goalCompanionPose]).
///
/// Silent: goals have no read-aloud, so she is a [CompanionView] that
/// breathes, blinks and glances but never talks. [seed] keeps the cards of
/// one list from blinking in step. Decorative — the status pill beside her
/// carries the verdict in words.
class GoalCompanionBust extends StatelessWidget {
  const GoalCompanionBust({
    required this.pose,
    required this.fill,
    required this.seed,
    super.key,
  });

  final CompanionCue pose;

  /// The goal's status wash, as the persona chip wears it.
  final Color fill;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ExcludeSemantics(
      child: Container(
        width: ControlSizes.avatarCompact,
        height: ControlSizes.avatarCompact,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: CompanionView(
          framing: CompanionFraming.bust,
          mood: pose.mood,
          // Held, so the verdict never relaxes out of view; she picks no
          // talking gestures of her own, as she never talks here.
          holding: pose.gesture,
          autoGestures: false,
          seed: seed,
        ),
      ),
    );
  }
}
