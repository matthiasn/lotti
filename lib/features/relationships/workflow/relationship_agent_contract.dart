/// The relationship-agent contract: system prompt and tool surface
/// (Phase B of ADR 0054; behaviour per ADRs 0040/0055/0058/0059).
///
/// The constitution is code, never a template (ADR 0053 Decision 7 via
/// ADR 0059): what the agent may say and do ships with the build.
library;

import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';

/// Tool names of the relationship-agent surface.
/// Domain tools use `<verb>_relationship_<noun>`; the shared reply carrier
/// and deferred `create_and_link_task` keep their cross-feature names.
class RelationshipAgentToolNames {
  static const String replyToUser = AgentConversationToolNames.replyToUser;
  static const updateRelationshipReport = 'update_relationship_report';
  static const createRelationshipAd = 'create_relationship_ad';
  static const createAndLinkTask = 'create_and_link_task';
  static const snoozeRelationshipAd = 'snooze_relationship_ad';
}

/// Health-band vocabulary of the report tool — the
/// [RelationshipHealthBand] enum verbatim, so the contract and the parser
/// cannot drift.
final List<String> relationshipHealthBandNames = [
  for (final band in RelationshipHealthBand.values) band.name,
];

/// Banner presentation catalogs — the code-owned presets of ADR 0058,
/// derived from the real enums so the contract cannot drift.
final List<String> relationshipNudgeToneNames = [
  for (final value in NudgeTone.values) value.name,
];
final List<String> relationshipBannerAnimationNames = [
  for (final value in NudgeBannerAnimation.values) value.name,
];
final List<String> relationshipBannerAccentNames = [
  for (final value in NudgeBannerAccent.values) value.name,
];

/// The system prompt. Deliberately lean (the goal contract's hard-cap
/// discipline): every number and date the model needs arrives in the wake
/// FACTS block, not here. The honesty rules are ADR 0040 Decision 7; the
/// privacy boundary is ADR 0041 §5 — contact channels never reach this
/// context, so the model cannot leak what it never sees.
const relationshipAgentSystemPrompt = '''
You are the private relationship assistant for exactly one person the user
deliberately tracks — an executive briefer, not a general assistant. Discuss
only this relationship: its check-ins, cadence, linked tasks, briefing, and
banners. For an unrelated request, do not answer it; briefly restate this
purpose and redirect.

Each wake receives authoritative FACTS: the person, cadence state, recent
check-ins, linked tasks, the previous briefing, and banner state. Never
recompute, contradict, or invent them.
Honesty rules:
- Reference ONLY captured check-ins and linked tasks; when evidence is thin,
  say so instead of padding.
- Always state recency plainly ("last spoke five weeks ago") from FACTS.
- Sentiments are the user's own judgment; ground the health band in them
  first and treat narrative prose as secondary evidence.
- payAttentionTo/avoid guidance must trace to the check-ins that produced it.
- Health band names and ids are FIELD VALUES ONLY: never write one in prose.
  Write visible text in the user's language.
- Never invent contact details; none exist in FACTS by design.

Act in this order of precedence:
1. Unanswered user message: call reply_to_user exactly once first.
2. Briefing: when FACTS mark the briefing stale (a newer check-in, a lapsed
   cadence, or an explicit request), call update_relationship_report with
   the full briefing: how things stand, key topics from recent check-ins,
   sentiment trajectory, what to bring up, what to pay attention to, what
   to avoid. Pick the health band from the FACTS-grounded evidence.
3. Banners: with the cadence DUE and no fresh active banner, create_relationship_ad
   with a short warm nudge to reach out — reference what was discussed last
   ("Check in with Anna — it's been 5 weeks. Last time: her job search.").
   Never guilt-trip; the tone is a helpful aide, roast only when the user
   asked for it. Banners are app-rendered TEXT: headline, optional
   tagline/cta, fixed animation/accent presets. No images. No contact
   details, no health data, no third-party names beyond this person's.
   For an explicit temporary-hide request, call snooze_relationship_ad with
   the future instant.
4. Proposals: only an explicit commitment in a captured check-in justifies
   create_and_link_task. Quote the evidence in description and pass its
   sourceCheckInId as a structured argument. Queue at most three per wake.
   Never re-propose pending, confirmed or rejected proposals from FACTS,
   including paraphrases. Never derive a task from a contact channel.
   These tools only propose: user confirmation is required before any task
   exists. Never claim a proposal was already applied. Propose a dueDate
   only when the evidence supports it.
5. Nothing material changed: call no tools and write nothing.
''';

/// Header introducing the pending user message appended to an interactive
/// wake's FACTS block. Shared with the eval suite's wake-message composer,
/// so the evals measure the exact message shape the workflow sends.
const relationshipPendingUserMessageHeader = 'PENDING USER MESSAGE:';

/// Instruction appended to the FACTS block when the user explicitly
/// requested a fresh briefing. Shared with the eval suite for the same
/// reason as [relationshipPendingUserMessageHeader].
const relationshipReportRefreshInstruction =
    'USER EXPLICITLY REQUESTED A FRESH BRIEFING. Call '
    'update_relationship_report now with the full briefing from the '
    'authoritative FACTS.';

/// The tools of the relationship-agent surface (plan v2 phase 5 item 1).
final List<AgentToolDefinition> relationshipAgentTools = [
  const AgentToolDefinition(
    name: RelationshipAgentToolNames.replyToUser,
    description:
        'Send the visible answer to the pending user message. Call exactly '
        'once when FACTS contain a PENDING USER MESSAGE; never use it for '
        'internal reasoning or scheduled briefing work.',
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
    name: RelationshipAgentToolNames.updateRelationshipReport,
    description:
        "Update the standing executive briefing shown on the person's "
        'page. Ground the health band in the user-set check-in sentiments '
        'first; prose is secondary evidence.',
    parameters: {
      'type': 'object',
      'properties': {
        'healthBand': {
          'type': 'string',
          'enum': relationshipHealthBandNames,
          'description':
              'The relationship health verdict, grounded in the FACTS.',
        },
        'healthRationale': {
          'type': 'string',
          'description':
              'One sentence tracing the band to specific check-in evidence.',
        },
        'healthConfidence': {
          'type': 'number',
          'description': 'Optional confidence in the band, 0..1.',
        },
        'oneLiner': {
          'type': 'string',
          'description': 'One sentence a list row or banner can show.',
        },
        'tldr': {
          'type': 'string',
          'description':
              'Two or three sentences: the state of the relationship at a '
              'glance, shown collapsed above the full briefing.',
        },
        'content': {
          'type': 'string',
          'description':
              'The full briefing as markdown: how things are going, key '
              'topics from recent check-ins, sentiment trajectory, '
              'suggested talking points, what to pay attention to, what '
              'to avoid. State recency; say when evidence is thin.',
        },
      },
      'required': [
        'healthBand',
        'healthRationale',
        'oneLiner',
        'tldr',
        'content',
      ],
    },
  ),
  AgentToolDefinition(
    name: RelationshipAgentToolNames.createRelationshipAd,
    description:
        'Create a new text-banner nudge to check in with this person. You '
        'write the copy and pick presentation presets; the app renders the '
        'banner procedurally — no image is ever generated (ADR 0058).',
    parameters: {
      'type': 'object',
      'properties': {
        'headline': {
          'type': 'string',
          'description':
              'Short warm headline — the banner IS this text. Name the '
              'person and the recency; no contact details or health data.',
        },
        'tagline': {
          'type': 'string',
          'description':
              'Optional supporting line, e.g. what was discussed last time.',
        },
        'cta': {
          'type': 'string',
          'description': 'Optional short call-to-action (2-4 words).',
        },
        'tone': {
          'type': 'string',
          'enum': relationshipNudgeToneNames,
          'description':
              'roast only when the user requested it: tease the silence, '
              'never the person.',
        },
        'animation': {
          'type': 'string',
          'enum': relationshipBannerAnimationNames,
          'description': 'Text animation preset from the fixed catalog.',
        },
        'accent': {
          'type': 'string',
          'enum': relationshipBannerAccentNames,
          'description': 'Background accent preset from the fixed catalog.',
        },
      },
      'required': ['headline', 'tone', 'animation'],
    },
  ),
  const AgentToolDefinition(
    name: RelationshipAgentToolNames.snoozeRelationshipAd,
    description:
        'Temporarily hide an active banner and automatically reveal the '
        'same banner again later. Use for explicit user snooze requests of '
        'any duration or future date/time.',
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
    name: RelationshipAgentToolNames.createAndLinkTask,
    description:
        'Propose a task from an explicit check-in commitment. '
        'Nothing is created until the user confirms.',
    parameters: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'title': {'type': 'string', 'description': 'Concise task title.'},
        'description': {
          'type': 'string',
          'description': 'Quote the commitment sentence from the check-in.',
        },
        'sourceCheckInId': {
          'type': 'string',
          'description': 'Exact checkInId from FACTS.',
        },
        'reason': {
          'type': 'string',
          'description': 'Why this commitment needs a task.',
        },
        'dueDate': {
          'type': 'string',
          'description': 'Optional evidence-supported due date, YYYY-MM-DD.',
        },
      },
      'required': ['title', 'description', 'sourceCheckInId', 'reason'],
    },
  ),
];

/// Mutations that are accumulated for user confirmation, never run by the LLM.
const Set<String> relationshipDeferredTools = {
  RelationshipAgentToolNames.createAndLinkTask,
};

/// Rejects malformed task proposals at both production and confirmation.
/// Calendar dates must round-trip: Dart otherwise normalizes February 30.
String? relationshipTaskProposalError(Map<String, dynamic> args) {
  for (final key in ['title', 'description', 'sourceCheckInId', 'reason']) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) {
      return '$key must be a non-empty string';
    }
  }
  final due = args['dueDate'];
  if (due != null) {
    final parsed = due is String ? DateTime.tryParse(due) : null;
    if (due is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(due) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != due) {
      return 'dueDate must be a valid YYYY-MM-DD calendar date';
    }
  }
  return null;
}
