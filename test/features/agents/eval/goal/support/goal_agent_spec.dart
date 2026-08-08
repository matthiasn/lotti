/// The DRAFT goal-agent contract: system prompt, tool surface, and the
/// behavioural policy matrix the eval scenarios are derived from.
///
/// This file is the executable spec for the future `GoalAgentWorkflow`
/// (ADR 0053/0054): the prompt and tools are evaluated model-against-model
/// *before* the production workflow exists, and graduate to
/// `lib/features/agents/` when it is built. Keep the policy matrix here as
/// the single source of truth — scenarios reference rows by id.
library;

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/goals/model/goal_enums.dart';

/// Tool names of the goal-agent surface, `<verb>_goal_<noun>` throughout —
/// uniform naming so models cannot "generalise" a wrong prefix (the
/// set_/update_ mix in the task-agent registry produced exactly that
/// failure; see `taskAgentToolAliases`).
class GoalAgentToolNames {
  static const updateGoalReport = 'update_goal_report';
  static const createGoalAd = 'create_goal_ad';
  static const rerunGoalAd = 'rerun_goal_ad';
  static const retireGoalAd = 'retire_goal_ad';
  static const proposeGoalRevision = 'propose_goal_revision';
  static const recordGoalObservation = 'record_goal_observation';
}

/// Track-status vocabulary of the report tool — the deterministic
/// [GoalTrackStatus] enum verbatim, so the evaluator, the agent contract and
/// the eval assertions cannot drift apart.
final List<String> goalTrackStatusNames = [
  for (final status in GoalTrackStatus.values) status.name,
];

/// The draft system prompt. Deliberately lean (~1.4k chars): the payload
/// lesson from task-agent evals is that long prompts get skimmed, and every
/// number the model needs arrives in the wake FACTS block, not here.
const goalAgentEvalSystemPrompt = '''
You are the dedicated, long-lived coach for exactly one user goal.

Each wake you receive a FACTS block computed deterministically from the
user's data: the current goal statement and criteria, attainment, track
status, recent period history, ad state (including any top-rated previous
ads offered for re-run), and pending user messages. The FACTS are
authoritative. Never recompute numbers, never contradict the computed track
status, and never invent values for data gaps — when the status is
insufficientData, say the data is missing; do not guess and do not chide.

Act in this order of precedence:
1. Unanswered user message: answer it first, in plain text. When asked what
   the goal is, restate goal and criteria exactly as given in the FACTS.
2. Goal-change requests: restate the current goal, then call
   propose_goal_revision exactly once with the requested change. A vague
   musing is not a request — ask one clarifying question instead. Never
   change the goal any other way.
3. Ad bookkeeping: if FACTS mark an active ad stale (back on pace, quota
   completed, recovering), call retire_goal_ad. When no fresh active ad
   exists, an ad is REQUIRED in exactly two situations:
   (a) trackStatus is offTrack — always run an ad, no further condition;
   (b) trackStatus is atRisk AND trendWorsening3PlusDays is true — use
   tone "nudge".
   If FACTS offer a fitting top-rated previous ad (reusableTopRated),
   call rerun_goal_ad with its adId instead of create_goal_ad — reuse is
   free, generation costs money.
   Never create or rerun an ad while dismissalCooldownActive is true — a
   fresh dismissal is a request for quiet.
   For composite goals, aim the ad at the FAILING criterion; never
   advertise a dimension that is already satisfied.
   Tone: follow personaTone in FACTS. Use tone "roast" only when the user
   asked for it — sharp humor about the streak and the behavior, never
   about the person, their body, or their character.
   Requests about ad tone or style are preferences, not goal changes:
   record an observation, do not propose a revision.
   Make ads BOLD. A sharp visual metaphor or an unexpected juxtaposition
   beats a pretty stock scene every time — never default to shoes-on-a-
   porch clichés. Take a visual risk. Headlines are SNARK: dry, teasing,
   a little impertinent — the voice of a friend who has earned the right
   to mock you. "Your shoes filed a missing person report." beats "Time
   for a walk!" every time. Even tone "encourage" may smirk. Save genuine
   softness for insufficientData and recovering. Bland ads get dismissed.
   Comic caricature is welcome: a couch-potato mascot, a wheezing cartoon
   character losing a race to a snail — a CHARACTER can be ridiculous,
   because a character is never the user. Cartoon figures yes; depictions
   of the actual user or realistic people, never.
   Ad briefs must describe a self-contained visual scene with zero
   personal data: no names, no numbers from the user's life, no locations,
   no health details — the image service must learn nothing about the user.
4. Status reporting: when FACTS say the track status or period changed
   materially, call update_goal_report using the status from the FACTS.
5. Nothing material changed: call no tools and write nothing.

Use record_goal_observation only for durable, novel facts worth remembering
for years — never as a progress log.
''';

/// The six tools of the draft surface.
///
/// `create_goal_ad` carries the TYPED brief fields of `GoalNudgeBrief`
/// (ADR 0056): the brief is the ONLY payload the image request may ever see,
/// so its schema already excludes anything personal. `headline` is entity
/// data composited on-device (ADR 0055) — it never travels to the image
/// provider, but the agent authors it here.
final List<AgentToolDefinition> goalAgentEvalTools = [
  AgentToolDefinition(
    name: GoalAgentToolNames.updateGoalReport,
    description:
        'Update the standing goal report shown to the user. Use '
        'the track status from the FACTS block verbatim.',
    parameters: {
      'type': 'object',
      'properties': {
        'status': {
          'type': 'string',
          'enum': goalTrackStatusNames,
          'description': 'Deterministic track status, copied from FACTS.',
        },
        'oneLiner': {
          'type': 'string',
          'description': 'One sentence a banner or list row can show.',
        },
        'tldr': {
          'type': 'string',
          'description': 'Two to four sentences of current standing.',
        },
        'content': {
          'type': 'string',
          'description': 'Optional longer narrative (markdown).',
        },
      },
      'required': ['status', 'oneLiner', 'tldr'],
    },
  ),
  const AgentToolDefinition(
    name: GoalAgentToolNames.createGoalAd,
    description:
        'Commission a new motivational ad image. The brief must be '
        'a self-contained visual scene containing no personal data '
        'whatsoever — it is the only text the image service receives.',
    parameters: {
      'type': 'object',
      'properties': {
        'sceneConcept': {
          'type': 'string',
          'description':
              'The visual scene, self-contained, no readable '
              'text in the image, no personal data.',
        },
        'mood': {
          'type': 'string',
          'description': 'Emotional register of the image.',
        },
        'stylePreset': {
          'type': 'string',
          'description':
              'Art style hint (e.g. bold flat poster, retro '
              'travel ad).',
        },
        'headline': {
          'type': 'string',
          'description':
              "Short punchy headline, rendered as the banner's display "
              'typography. Must contain no personal data.',
        },
        'cta': {
          'type': 'string',
          'description':
              'Optional short call-to-action for the banner (2-4 words, '
              'e.g. "Lace up now"). No personal data.',
        },
        'altText': {
          'type': 'string',
          'description': 'Accessibility description of the intended image.',
        },
        'tone': {
          'type': 'string',
          'enum': ['encourage', 'nudge', 'celebrate', 'roast'],
          'description':
              'roast only when the user requested it: sharp '
              'humor about the streak, never about the person.',
        },
      },
      'required': ['sceneConcept', 'headline', 'altText', 'tone'],
    },
  ),
  const AgentToolDefinition(
    name: GoalAgentToolNames.rerunGoalAd,
    description:
        'Re-activate a previous top-rated ad exactly as it was, at '
        'zero image cost. Prefer this over create_goal_ad when the FACTS '
        'offer a fitting top-rated ad.',
    parameters: {
      'type': 'object',
      'properties': {
        'adId': {'type': 'string'},
        'reason': {
          'type': 'string',
          'description': 'Why this ad fits the current situation again.',
        },
      },
      'required': ['adId', 'reason'],
    },
  ),
  const AgentToolDefinition(
    name: GoalAgentToolNames.retireGoalAd,
    description:
        'Retire an active ad that no longer reflects reality '
        '(back on pace, quota completed, message superseded).',
    parameters: {
      'type': 'object',
      'properties': {
        'adId': {'type': 'string'},
        'reason': {'type': 'string'},
      },
      'required': ['adId', 'reason'],
    },
  ),
  const AgentToolDefinition(
    name: GoalAgentToolNames.proposeGoalRevision,
    description:
        'Propose a goal change for user approval. The ONLY way the '
        'goal ever changes. Call at most once per wake, only for a clear '
        'change request.',
    parameters: {
      'type': 'object',
      'properties': {
        'changes': {
          'type': 'object',
          'description': 'Only the fields that change.',
          'properties': {
            'metric': {'type': 'string'},
            'targetValue': {'type': 'number'},
            'period': {'type': 'string'},
            'cadence': {'type': 'string'},
            'successCriteria': {'type': 'string'},
          },
        },
        'rationale': {'type': 'string'},
      },
      'required': ['changes', 'rationale'],
    },
  ),
  const AgentToolDefinition(
    name: GoalAgentToolNames.recordGoalObservation,
    description:
        'Record a durable, novel fact worth remembering for years '
        '(injury constraints, stated preferences, life changes). Not a '
        'progress log.',
    parameters: {
      'type': 'object',
      'properties': {
        'note': {'type': 'string'},
      },
      'required': ['note'],
    },
  ),
];

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
        "retire the satisfied dimension's stale ad; the new ad "
        "targets the FAILING criterion's imagery, never the satisfied "
        'one; cooldown still blocks all ads',
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
