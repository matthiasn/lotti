import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

void main() {
  test('the prompt stays under the eval-enforced hard cap', () {
    // The payload lesson: long prompts get skimmed. The eval suite pins
    // the same bound; this pins it for the production import path.
    expect(goalAgentSystemPrompt.length, lessThan(3200));
    expect(
      goalAgentSystemPrompt,
      contains('explicitly asks for another ad'),
    );
    expect(goalAgentSystemPrompt, contains('not a general assistant'));
    expect(
      goalAgentSystemPrompt,
      contains(
        'For an unrelated request (coding, trivia, etc.), do not answer',
      ),
    );
    expect(
      goalAgentSystemPrompt,
      contains('`latest.todayStatus=completeOnTarget`'),
    );
    expect(goalAgentSystemPrompt, contains('latestChange'));
    expect(goalAgentSystemPrompt, contains('referenceIsCurrentDay'));
  });

  test('the tool surface includes the shared reply carrier and seven goal '
      'tools', () {
    expect(
      [for (final tool in goalAgentTools) tool.name],
      [
        GoalAgentToolNames.replyToUser,
        GoalAgentToolNames.updateGoalReport,
        GoalAgentToolNames.createGoalAd,
        GoalAgentToolNames.rerunGoalAd,
        GoalAgentToolNames.retireGoalAd,
        GoalAgentToolNames.snoozeGoalAd,
        GoalAgentToolNames.proposeGoalRevision,
        GoalAgentToolNames.recordGoalObservation,
      ],
    );
    for (final tool in goalAgentTools) {
      expect(
        tool.name,
        tool.name == GoalAgentToolNames.replyToUser
            ? AgentConversationToolNames.replyToUser
            : matches(RegExp(r'^[a-z]+_goal_[a-z0-9_]+$')),
      );
    }
    expect(
      GoalAgentToolNames.proposeGoalRevision,
      'propose_goal_revision_v2',
    );
    expect(
      GoalAgentToolNames.isGoalRevisionProposal(
        GoalAgentToolNames.legacyProposeGoalRevision,
      ),
      isTrue,
    );
    final reportTool = goalAgentTools.singleWhere(
      (tool) => tool.name == GoalAgentToolNames.updateGoalReport,
    );
    final properties =
        reportTool.parameters['properties'] as Map<String, dynamic>;
    final required = reportTool.parameters['required'] as List<dynamic>;
    final report = properties['report'] as Map<String, dynamic>;
    final reportProperties = report['properties'] as Map<String, dynamic>;
    expect(
      required,
      containsAll(['status', 'oneLiner', 'report']),
    );
    expect(
      report['required'],
      GoalReportSectionKeys.values,
    );
    expect(
      reportProperties.keys,
      containsAll(GoalReportSectionKeys.values),
    );
    expect(
      (reportProperties[GoalReportSectionKeys.currentPeriod]
          as Map<String, dynamic>)['description'],
      contains('todayGuidance'),
    );
    expect(
      (reportProperties[GoalReportSectionKeys.latestChange]
          as Map<String, dynamic>)['description'],
      contains('exact latest'),
    );
    expect(
      (reportProperties[GoalReportSectionKeys.nextActions]
          as Map<String, dynamic>)['type'],
      'object',
    );
    expect(
      (reportProperties[GoalReportSectionKeys.nextActions]
          as Map<String, dynamic>)['required'],
      GoalReportActionKeys.values,
    );
    final actionProperties =
        (reportProperties[GoalReportSectionKeys.nextActions]
                as Map<String, dynamic>)['properties']
            as Map<String, dynamic>;
    expect(
      ((actionProperties[GoalReportActionKeys.now]
              as Map<String, dynamic>)['items']
          as Map<String, dynamic>)['required'],
      ['criterionId', 'action'],
    );
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
