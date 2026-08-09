import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

void main() {
  test('the prompt stays under the eval-enforced hard cap', () {
    // The payload lesson: long prompts get skimmed. The eval suite pins
    // the same bound; this pins it for the production import path.
    expect(goalAgentSystemPrompt.length, lessThan(3200));
  });

  test('the tool surface is the six-tool contract with uniform naming', () {
    expect(
      [for (final tool in goalAgentTools) tool.name],
      [
        GoalAgentToolNames.updateGoalReport,
        GoalAgentToolNames.createGoalAd,
        GoalAgentToolNames.rerunGoalAd,
        GoalAgentToolNames.retireGoalAd,
        GoalAgentToolNames.proposeGoalRevision,
        GoalAgentToolNames.recordGoalObservation,
      ],
    );
    for (final tool in goalAgentTools) {
      expect(tool.name, matches(RegExp('^[a-z]+_goal_[a-z_]+')));
    }
  });

  test('the enum vocabularies are derived from the real enums — the '
      'contract cannot drift from the model layer', () {
    expect(
      goalTrackStatusNames,
      [for (final v in GoalTrackStatus.values) v.name],
    );
    expect(
      goalBannerAnimationNames,
      [for (final v in GoalBannerAnimation.values) v.name],
    );
    expect(
      goalBannerAccentNames,
      [for (final v in GoalBannerAccent.values) v.name],
    );
    expect(
      goalNudgeToneNames,
      [for (final v in GoalNudgeTone.values) v.name],
    );
  });
}
