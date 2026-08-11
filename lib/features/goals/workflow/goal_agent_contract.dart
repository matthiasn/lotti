/// The goal-agent contract: system prompt and tool surface (Phase B of
/// ADR 0054, behaviour per ADRs 0053/0055/0058).
///
/// GRADUATED from the eval harness (`test/features/agents/eval/goal/`):
/// the prompt and tools were evaluated model-against-model before this
/// runtime existed, and the eval suite still imports THIS file — the
/// contract the evals validated and the contract the runtime ships are
/// one artifact, so they cannot drift.
library;

import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tool names of the goal-agent surface, `<verb>_goal_<noun>` throughout —
/// uniform naming so models cannot "generalise" a wrong prefix (the
/// set_/update_ mix in the task-agent registry produced exactly that
/// failure; see `taskAgentToolAliases`).
class GoalAgentToolNames {
  static const String replyToUser = AgentConversationToolNames.replyToUser;
  static const updateGoalReport = 'update_goal_report';
  static const createGoalAd = 'create_goal_ad';
  static const rerunGoalAd = 'rerun_goal_ad';
  static const retireGoalAd = 'retire_goal_ad';
  static const snoozeGoalAd = 'snooze_goal_ad';
  static const proposeGoalRevision = 'propose_goal_revision';
  static const recordGoalObservation = 'record_goal_observation';
}

/// Track-status vocabulary of the report tool — the deterministic
/// [GoalTrackStatus] enum verbatim, so the evaluator, the agent contract and
/// the eval assertions cannot drift apart.
final List<String> goalTrackStatusNames = [
  for (final status in GoalTrackStatus.values) status.name,
];

/// The system prompt. Deliberately lean (hard-capped at 3.2k chars by
/// the offline test): the payload lesson from task-agent evals is that long
/// prompts get skimmed, and every number the model needs arrives in the
/// wake FACTS block, not here.
const goalAgentSystemPrompt = '''
You are the dedicated coach for exactly one user goal, not a general assistant.
Discuss only that goal, its evidence, progress, criteria, banners, and proposed
changes. For an unrelated request (coding, trivia, etc.), do not answer it;
briefly remind the user of this purpose and redirect to the goal.

Each wake receives authoritative FACTS: goal, criteria, attainment, status,
history, ad state, and pending messages. Never recompute or contradict them,
or invent missing values. For insufficientData, name the gap; do not chide.

Act in this order of precedence:
1. Unanswered user message: answer it first by calling reply_to_user exactly
   once. When asked, restate goal and criteria exactly as given in the FACTS.
2. Goal-change requests: restate the current goal, then call
   propose_goal_revision exactly once with the requested change. A vague
   musing is not a request — ask one clarifying question instead. Never
   change the goal any other way.
3. Ad bookkeeping: if FACTS mark an active ad stale (back on pace, quota
   completed, recovering), call retire_goal_ad. When no fresh active ad
   exists, an ad is REQUIRED in two cases:
   (a) trackStatus is offTrack — always run an ad, no further condition;
   (b) trackStatus is atRisk AND trendWorsening3PlusDays is true — use
   tone "nudge".
   If FACTS offer a fitting top-rated previous ad (reusableTopRated),
   call rerun_goal_ad with its adId instead of create_goal_ad — proven
   copy beats new copy.
   Dismissal cooldown blocks automatic ads. If the PENDING USER MESSAGE
   explicitly asks for another ad, that request overrides the cooldown.
   If its active ad has outcomeRecorded true, retire it before replacing it.
   If the pending user asks to hide the current banner temporarily, call
   snooze_goal_ad with the requested future instant. Snoozing keeps the same
   ad and automatically reveals it again at that instant; do not retire or
   replace it.
   For composite goals, the ad must SELL the failing criterion; the
   satisfied one may appear as contrast or punchline, never as the pitch.
   Tone: follow personaTone in FACTS. Use tone "roast" only when the user
   asked for it — sharp humor about the streak and the behavior, never
   about the person, their body, or their character.
   Requests about ad tone or style are preferences, not goal changes:
   record an observation, do not propose a revision.
   Copy is dry, teasing and vivid, never bland. Mock a stand-in or the
   behavior, never the user, their body, or their character. Even
   "encourage" may smirk; save softness for insufficientData/recovering.
   Ads are TEXT BANNERS the app renders: write headline (optional
   tagline, cta) and pick animation and accent presets from the fixed
   catalog; no images exist. Copy must contain zero personal data: no
   names, no user-life numbers, no locations, no health details.
4. Status reporting: when FACTS say the track status or period changed
   materially, call update_goal_report using the status from the FACTS.
5. Nothing material changed: call no tools and write nothing.

Use record_goal_observation only for durable, novel facts worth remembering
for years — not a progress log.
''';

/// The tools of the goal-agent surface.
///
/// `create_goal_ad` carries the TYPED fields of `GoalNudgeBrief`
/// (ADR 0058): model-authored banner copy plus preset selections from the
/// code-owned catalogs. Copy fields are the only model text a surface
/// renders verbatim, so they are what the leakage evals police.
/// Banner presentation catalogs — the code-owned presets of ADR 0058,
/// derived from the real enums so the contract cannot drift.
final List<String> goalNudgeToneNames = [
  for (final value in GoalNudgeTone.values) value.name,
];
final List<String> goalBannerAnimationNames = [
  for (final value in GoalBannerAnimation.values) value.name,
];
final List<String> goalBannerAccentNames = [
  for (final value in GoalBannerAccent.values) value.name,
];

final List<AgentToolDefinition> goalAgentTools = [
  const AgentToolDefinition(
    name: GoalAgentToolNames.replyToUser,
    description:
        'Send the visible answer to the pending user message. Call exactly '
        'once when FACTS contain a PENDING USER MESSAGE; never use it for '
        'internal reasoning or scheduled status work.',
    parameters: {
      'type': 'object',
      'properties': {
        'message': {
          'type': 'string',
          'description': 'The complete concise reply shown to the user.',
        },
      },
      'required': ['message'],
    },
  ),
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
  AgentToolDefinition(
    name: GoalAgentToolNames.createGoalAd,
    description:
        'Create a new text-banner ad. You write the copy and pick '
        'presentation presets; the app renders the banner procedurally — '
        'no image is ever generated (ADR 0058).',
    parameters: {
      'type': 'object',
      'properties': {
        'headline': {
          'type': 'string',
          'description':
              'Short punchy headline — the banner IS this text. '
              'No personal data.',
        },
        'tagline': {
          'type': 'string',
          'description': 'Optional supporting line under the headline.',
        },
        'cta': {
          'type': 'string',
          'description':
              'Optional short call-to-action (2-4 words, e.g. "Lace up '
              'now"). No personal data.',
        },
        'tone': {
          'type': 'string',
          'enum': goalNudgeToneNames,
          'description':
              'roast only when the user requested it: sharp '
              'humor about the streak, never about the person.',
        },
        'animation': {
          'type': 'string',
          'enum': goalBannerAnimationNames,
          'description': 'Text animation preset from the fixed catalog.',
        },
        'accent': {
          'type': 'string',
          'enum': goalBannerAccentNames,
          'description': 'Background accent preset from the fixed catalog.',
        },
      },
      'required': ['headline', 'tone', 'animation'],
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
    name: GoalAgentToolNames.snoozeGoalAd,
    description:
        'Temporarily hide an active banner and automatically reveal the same '
        'banner again later. Use for explicit user snooze requests of any '
        'duration or future date/time.',
    parameters: {
      'type': 'object',
      'properties': {
        'adId': {'type': 'string'},
        'until': {
          'type': 'string',
          'format': 'date-time',
          'description': 'Requested future instant as ISO 8601 with offset.',
        },
        'reason': {'type': 'string'},
      },
      'required': ['adId', 'until', 'reason'],
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
