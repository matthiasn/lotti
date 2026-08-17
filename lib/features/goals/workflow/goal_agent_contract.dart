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
import 'package:lotti/classes/nudge_models.dart';
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

  /// Legacy unfenced proposal contract. New clients never emit or apply it;
  /// retaining the name lets them retract proposals synced from older builds.
  static const legacyProposeGoalRevision = 'propose_goal_revision';

  /// Versioned proposal contract whose persisted arguments include the goal
  /// spec version against which the proposal was authored.
  static const proposeGoalRevision = 'propose_goal_revision_v2';
  static const recordGoalObservation = 'record_goal_observation';

  static bool isGoalRevisionProposal(String toolName) =>
      toolName == proposeGoalRevision || toolName == legacyProposeGoalRevision;
}

/// Track-status vocabulary of the report tool — the deterministic
/// [GoalTrackStatus] enum verbatim, so the evaluator, the agent contract and
/// the eval assertions cannot drift apart.
final List<String> goalTrackStatusNames = [
  for (final status in GoalTrackStatus.values) status.name,
];

/// Stable keys of the structured standing-report payload. The strategy
/// renders these slots into the persisted user-visible summary in this order.
abstract final class GoalReportSectionKeys {
  /// The collapsed view of the report card, and the only slot that is not
  /// part of the full narrative. Everything below composes into the expanded
  /// body; this one has to stand alone above it.
  static const tldr = 'tldr';
  static const currentPeriod = 'currentPeriod';
  static const rollingWindow = 'rollingWindow';
  static const latestChange = 'latestChange';
  static const coverage = 'coverage';
  static const nextActions = 'nextActions';

  static const List<String> values = [
    tldr,
    currentPeriod,
    rollingWindow,
    latestChange,
    coverage,
    nextActions,
  ];
}

/// Provenance keys under which a goal report's structured sections are
/// persisted on the report entity.
///
/// The sections are model-authored sentences in the USER'S language, so the
/// composer cannot wrap them in headings without injecting English. Persisting
/// them separately lets the card render localized headings at display time,
/// which is also what makes the report re-render correctly when the app
/// language changes.
///
/// Same pattern the project agent uses for its health verdict: structured
/// facts ride on the report as provenance so the UI never reparses markdown.
abstract final class GoalReportProvenanceKeys {
  static const sections = 'goal_report_sections';
}

/// Keys that separate actions proven due in the evaluated period from later
/// focus areas. This prevents a lagging rolling habit from becoming a false
/// "do it today" instruction.
abstract final class GoalReportActionKeys {
  static const now = 'now';
  static const later = 'later';

  static const List<String> values = [now, later];
}

/// One model-authored action whose current-period visibility is gated by
/// deterministic FACTS before persistence.
class GoalReportCurrentAction {
  const GoalReportCurrentAction({
    required this.criterionId,
    required this.action,
  });

  final String criterionId;
  final String action;
}

/// Parsed form of the structured standing report shared by production and
/// the inference eval classifier, so provider schema compliance is tested
/// against the same completeness rules the runtime enforces.
class GoalStructuredReport {
  const GoalStructuredReport({
    required this.tldr,
    required this.currentPeriod,
    required this.rollingWindow,
    required this.latestChange,
    required this.coverage,
    required this.now,
    required this.later,
  });

  /// One or two sentences summarising the whole report, shown collapsed.
  final String tldr;
  final String currentPeriod;
  final String rollingWindow;
  final String latestChange;
  final String coverage;
  final List<GoalReportCurrentAction> now;
  final List<String> later;

  static GoalStructuredReport? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final tldr = _requiredReportString(value[GoalReportSectionKeys.tldr]);
    final currentPeriod = _requiredReportString(
      value[GoalReportSectionKeys.currentPeriod],
    );
    final rollingWindow = _requiredReportString(
      value[GoalReportSectionKeys.rollingWindow],
    );
    final latestChange = _optionalReportString(
      value[GoalReportSectionKeys.latestChange],
    );
    final coverage = _optionalReportString(
      value[GoalReportSectionKeys.coverage],
    );
    final actions = value[GoalReportSectionKeys.nextActions];
    if (tldr == null ||
        currentPeriod == null ||
        rollingWindow == null ||
        latestChange == null ||
        coverage == null ||
        actions is! Map<String, dynamic>) {
      return null;
    }

    final rawNow = actions[GoalReportActionKeys.now];
    final rawLater = actions[GoalReportActionKeys.later];
    if (rawNow is! List<dynamic> || rawLater is! List<dynamic>) return null;
    final now = <GoalReportCurrentAction>[];
    for (final item in rawNow) {
      if (item is! Map<String, dynamic>) return null;
      final criterionId = _requiredReportString(item['criterionId']);
      final action = _requiredReportString(item['action']);
      if (criterionId == null || action == null) return null;
      now.add(
        GoalReportCurrentAction(criterionId: criterionId, action: action),
      );
    }
    final later = <String>[];
    for (final item in rawLater) {
      final action = _requiredReportString(item);
      if (action == null) return null;
      later.add(action);
    }

    return GoalStructuredReport(
      tldr: tldr,
      currentPeriod: currentPeriod,
      rollingWindow: rollingWindow,
      latestChange: latestChange,
      coverage: coverage,
      now: now,
      later: later,
    );
  }

  /// Composes the **expanded** report body from model-authored localized
  /// sentences, without injecting English headings. [tldr] is deliberately
  /// absent: it is the collapsed view shown above this, and repeating it as
  /// the first paragraph would make "Show more" open with what the reader
  /// just finished reading.
  ///
  /// Only explicitly authorized current actions are included.
  /// The sections as data, for persistence alongside the composed markdown.
  ///
  /// Ordered, and empty slots dropped: the card renders a heading for each
  /// entry present, so an empty one would render a heading with nothing under
  /// it.
  Map<String, Object?> toProvenance({
    required Set<String> allowedCurrentActionCriterionIds,
  }) => {
    GoalReportSectionKeys.currentPeriod: currentPeriod,
    GoalReportSectionKeys.rollingWindow: rollingWindow,
    if (latestChange.isNotEmpty)
      GoalReportSectionKeys.latestChange: latestChange,
    if (coverage.isNotEmpty) GoalReportSectionKeys.coverage: coverage,
    GoalReportSectionKeys.nextActions: [
      for (final item in now)
        if (allowedCurrentActionCriterionIds.contains(item.criterionId))
          item.action,
      ...later,
    ],
  };

  String visibleSummary({
    required Set<String> allowedCurrentActionCriterionIds,
  }) => [
    currentPeriod,
    rollingWindow,
    if (latestChange.isNotEmpty) latestChange,
    if (coverage.isNotEmpty) coverage,
    for (final item in now)
      if (allowedCurrentActionCriterionIds.contains(item.criterionId))
        item.action,
    ...later,
  ].join('\n\n');
}

String? _requiredReportString(Object? value) {
  final trimmed = _optionalReportString(value);
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _optionalReportString(Object? value) =>
    value is String ? value.trim() : null;

/// The system prompt. Deliberately lean (hard-capped at 3.6k chars by
/// the offline test): the payload lesson from task-agent evals is that long
/// prompts get skimmed, and every number the model needs arrives in the
/// wake FACTS block, not here.
///
/// The ceiling is a discipline, not a model limit — it exists so growth is
/// argued rather than accreted. It moved from 3.2k when the standing-report
/// rule was added: the FACTS block can only carry a rule to the turns whose
/// English heuristic fires, so a rule that must hold in every language and
/// every turn belongs here.
const goalAgentSystemPrompt = '''
You are the dedicated coach for exactly one user goal, not a general assistant.
Discuss only its evidence, progress, criteria, banners, and proposed changes.
For an unrelated request (coding, trivia, etc.), do not answer it; briefly
remind the user of this purpose and redirect to the goal.

Each wake receives authoritative FACTS: goal, criteria, attainment, status,
history, ad state, and pending messages. Never recompute, contradict, or invent
them. For insufficientData, name the gap; do not chide.
Status names and criterionIds are FIELD VALUES ONLY: never write one in prose.
Name criteria by their title and describe states in the user's language.
Health checklist:
- `actual` = rolling aggregate, never latest, pre-rounded; quote as given.
  Cite exact observations for changes; never invent in-between values.
- `latest.todayStatus=completeOnTarget` means logging is complete for
  `evaluation.reference`. Use
  "today" only if `referenceIsCurrentDay`; otherwise name the date and infer
  nothing about the current day.
- `latestChange` is previous-to-latest only. `towardTarget` means improvement
  since the previous reading, not a stable trend.
- Put current instructions only in authorized nextActions.now;
  nextActions.later never says today/now.

Act in this order of precedence:
1. Unanswered user message: call reply_to_user exactly once first. When asked,
   restate goal and criteria exactly from FACTS.
2. Goal-change requests: restate the current goal, then call
   propose_goal_revision_v2 exactly once. For vague musings, ask one clarifying
   question. Never change the goal another way.
3. Ads: retire_goal_ad when FACTS mark the active ad stale (back on pace,
   quota completed, or recovering). With no fresh active ad, an ad is REQUIRED
   when: (a) offTrack; (b) atRisk with trendWorsening3PlusDays (tone "nudge");
   or (c) the first evaluation is atRisk, to welcome the new goal.
   Prefer rerun_goal_ad with reusableTopRated.adId over create_goal_ad.
   Dismissal cooldown and health gates block only automatic ads. If the
   PENDING USER MESSAGE explicitly asks for another ad, honor it at any status
   and reflect reality: celebrate onTrack, encourage recovering, or name an
   insufficientData gap. Retire an active ad with outcomeRecorded before
   replacing it.
   For an explicit temporary-hide request, call snooze_goal_ad with the future
   instant. It reveals the same ad then; do not retire or replace it.
   For composite goals, sell the failing criterion; a satisfied one is only
   contrast. Follow personaTone. Use "roast" only when requested: mock the
   streak or behavior, never the person, body, or character. Tone/style
   requests are preferences: record an observation, not a goal revision.
   Copy is dry, teasing, vivid, and reality-based. Encourage may smirk; be soft
   for insufficientData/recovering. Ads are app-rendered TEXT BANNERS: write a
   headline, optional tagline/cta, and fixed animation/accent presets. No
   images. Include no personal data: names, life numbers, locations, or health.
4. Status reporting: when FACTS say the track status or period changed
   materially, call update_goal_report with the FACTS status.
   The report is STORED: reply_to_user never changes it. When the user asks
   for the report itself to change (shorter, sectioned, less repetitive), call
   update_goal_report in the SAME turn with the full rewrite.
5. Nothing material changed: call no tools and write nothing.

Use record_goal_observation only for novel facts worth remembering for years,
not a progress log.
''';

/// The tools of the goal-agent surface.
///
/// `create_goal_ad` carries the TYPED fields of `NudgeBrief`
/// (ADR 0058): model-authored banner copy plus preset selections from the
/// code-owned catalogs. Copy fields are the only model text a surface
/// renders verbatim, so they are what the leakage evals police.
/// Banner presentation catalogs — the code-owned presets of ADR 0058,
/// derived from the real enums so the contract cannot drift.
final List<String> goalNudgeToneNames = [
  for (final value in NudgeTone.values) value.name,
];
final List<String> goalBannerAnimationNames = [
  for (final value in NudgeBannerAnimation.values) value.name,
];
final List<String> goalBannerAccentNames = [
  for (final value in NudgeBannerAccent.values) value.name,
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
        'userAskedForBanner': {
          'type': 'boolean',
          'description':
              'True only when the pending message explicitly asks for a '
              'banner or ad — in ANY language. Not for tone or style '
              'preferences, not for questions about the goal. This is how a '
              'request overrides the automatic banner rules, so a non-English '
              'request is honored exactly like an English one.',
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
        'report': {
          'type': 'object',
          'description':
              'Structured facts that the app assembles into the visible '
              'standing summary. Prose slots are facts only; put every '
              'instruction in nextActions. Keep each slot concise and do '
              'not repeat the same fact across slots. Return a JSON object, '
              'never an encoded JSON string.',
          'properties': {
            GoalReportSectionKeys.tldr: {
              'type': 'string',
              'description':
                  'One or two sentences summarising the whole report, shown '
                  'on its own before the reader expands the rest. Lead with '
                  'where the goal stands. Do not repeat it verbatim in any '
                  'other slot.',
            },
            GoalReportSectionKeys.currentPeriod: {
              'type': 'string',
              'description':
                  'One concise sentence: what is complete versus loggable for '
                  'evaluation.reference. Follow todayGuidance. For health, '
                  'include each latest same-day value and whether it is on '
                  'target. Say today only when referenceIsCurrentDay.',
            },
            GoalReportSectionKeys.rollingWindow: {
              'type': 'string',
              'description':
                  'One concise sentence with rolling or calendar standing: '
                  'aggregates, targets, and '
                  'habit quotas. Never present an aggregate as a latest '
                  'measurement.',
            },
            GoalReportSectionKeys.latestChange: {
              'type': 'string',
              'description':
                  'One concise sentence: for every comparable health series, '
                  'give exact latest and previous values plus latestChange. '
                  'Empty when no comparable change exists.',
            },
            GoalReportSectionKeys.coverage: {
              'type': 'string',
              'description':
                  'One concise sentence with sample counts, sparsity, or the '
                  'specific insufficientData gap. Empty when not applicable.',
            },
            GoalReportSectionKeys.nextActions: {
              'type': 'object',
              'description':
                  'Separate actions FACTS prove are due now from future or '
                  'ongoing focus. A rollingHabitCriterionIdsBehind entry '
                  'alone never proves an action is due today.',
              'properties': {
                GoalReportActionKeys.now: {
                  'type': 'array',
                  'description':
                      'Actions explicitly proven due at evaluation.reference. '
                      'criterionId must be copied from '
                      'healthLoggingNeededCriterionIds. Use an empty list '
                      'when FACTS do not identify one.',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'criterionId': {'type': 'string'},
                      'action': {'type': 'string'},
                    },
                    'required': ['criterionId', 'action'],
                  },
                },
                GoalReportActionKeys.later: {
                  'type': 'array',
                  'description':
                      'Future or ongoing focus, worded without claiming it is '
                      'missing today. Never say today or now, and never '
                      'instruct current-period completion.',
                  'items': {'type': 'string'},
                },
              },
              'required': GoalReportActionKeys.values,
            },
          },
          'required': GoalReportSectionKeys.values,
        },
        'content': {
          'type': 'string',
          'description':
              'Optional longer markdown only for material detail absent from '
              'report. Usually omit; never repeat the structured slots.',
        },
      },
      'required': ['status', 'oneLiner', 'report'],
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
