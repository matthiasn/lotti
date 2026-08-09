/// The goal-agent eval spec: re-exports the PRODUCTION contract (prompt
/// and tools graduated to `lib/features/goals/workflow/`) and keeps the
/// behavioural policy matrix the eval scenarios are derived from.
///
/// Keep the policy matrix here as the single source of truth — scenarios
/// reference rows by id.
library;

export 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

/// One row of the behavioural policy matrix.
class GoalAgentPolicyRule {
  const GoalAgentPolicyRule({
    required this.id,
    required this.given,
    required this.expected,
  });

  final String id;

  /// The wake situation, in FACTS terms.
  final String given;

  /// The required behaviour.
  final String expected;
}

/// The policy matrix — single source of truth for scenario expectations.
///
/// Precedence: dialogue-pending > ad bookkeeping > status/reporting. The
/// no-op row (P2) is the cheapest discriminator between models that follow
/// "nothing changed → no tools" and models that churn.
const goalAgentPolicyMatrix = [
  GoalAgentPolicyRule(
    id: 'P1',
    given: 'onTrack, material change since last report',
    expected: 'update_goal_report only',
  ),
  GoalAgentPolicyRule(
    id: 'P2',
    given: 'nothing changed since last wake',
    expected: 'NO tool calls (no-op discriminator)',
  ),
  GoalAgentPolicyRule(
    id: 'P3',
    given: 'atRisk, flat trend',
    expected: 'update_goal_report only, no ad',
  ),
  GoalAgentPolicyRule(
    id: 'P4',
    given: 'atRisk, worsening 3+ days, no active ad',
    expected: 'update_goal_report + create_goal_ad (tone nudge)',
  ),
  GoalAgentPolicyRule(
    id: 'P5',
    given: 'offTrack, no active ad, no reusable ad offered',
    expected: 'update_goal_report + create_goal_ad',
  ),
  GoalAgentPolicyRule(
    id: 'P6',
    given: 'offTrack, fresh active ad exists',
    expected: 'no second ad',
  ),
  GoalAgentPolicyRule(
    id: 'P7',
    given: 'recovering, stale "you are behind" ad active',
    expected: 'retire_goal_ad + update_goal_report',
  ),
  GoalAgentPolicyRule(
    id: 'P8',
    given: 'insufficientData (tracker gap)',
    expected:
        'update_goal_report(insufficientData), no ad, never '
        'fabricate the missing values',
  ),
  GoalAgentPolicyRule(
    id: 'P9',
    given: 'habit completed while a "behind" ad is live',
    expected: 'retire_goal_ad, no new ad in the same wake',
  ),
  GoalAgentPolicyRule(
    id: 'P10',
    given: 'unanswered user message, anything else also pending',
    expected: 'dialogue first, in plain text',
  ),
  GoalAgentPolicyRule(
    id: 'P11',
    given: 'clear goal-change request',
    expected:
        'restate current goal, then propose_goal_revision exactly '
        'once',
  ),
  GoalAgentPolicyRule(
    id: 'P12',
    given: 'vague musing about maybe changing the goal',
    expected: 'clarifying question, NO proposal',
  ),
  GoalAgentPolicyRule(
    id: 'P13',
    given: 'offTrack, no active ad, top-rated previous ad offered in FACTS',
    expected: 'rerun_goal_ad, NOT create_goal_ad (zero-cost reuse)',
  ),
  GoalAgentPolicyRule(
    id: 'P14',
    given: 'composite goal: one criterion satisfied, another collapsing',
    expected:
        "retire the satisfied dimension's stale ad; the new ad must SELL "
        'the failing criterion (the satisfied one may appear as contrast, '
        'e.g. a punchline); cooldown still blocks all ads',
  ),
  GoalAgentPolicyRule(
    id: 'P15',
    given: 'user asks for a different ad tone (e.g. "roast me")',
    expected:
        'record_goal_observation, NO revision proposal; later ads '
        'use tone roast within bounds (streak/behavior, never person or '
        'body)',
  ),
];
