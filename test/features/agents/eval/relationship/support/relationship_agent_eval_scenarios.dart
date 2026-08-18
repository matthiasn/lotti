/// The relationship-agent eval scenarios, derived row-by-row from
/// [relationshipAgentPolicyMatrix] — every scenario names the policy rule it
/// tests, and the offline self-test fails when a row has none.
///
/// The catalog is built asynchronously because the FACTS are not authored:
/// each scenario renders its world through the production
/// `RelationshipFactsRenderer` over a cadence derivation produced by the
/// production `RelationshipAgentPhaseA`. That costs one await and buys the
/// property the goal suite lists as its own headline limitation — the block
/// the model reads here is the block a wake actually sends.
library;

import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';

import 'relationship_agent_eval_fixtures.dart';
import 'relationship_agent_spec.dart';

/// An expected tool call: name plus an optional argument subset that must
/// appear in at least one call of that name.
class RelationshipAgentExpectedToolCall {
  const RelationshipAgentExpectedToolCall(
    this.name, {
    this.expectedArgumentsSubset = const {},
  });

  final String name;
  final Map<String, Object?> expectedArgumentsSubset;
}

/// One declarative eval case.
///
/// The assertion vocabulary mirrors the goal-agent inference eval, minus the
/// goal-only concepts (no ad re-run, no revision proposals) and plus the
/// three this contract needs: [expectedHealthBands] (the verdict is an enum
/// field, so "one of these is defensible" is the honest assertion),
/// [expectedAdTones]/[forbiddenAdTones] (tone is policy here, not taste),
/// and [forbiddenAssistantContentTerms] (a leaked phone number is a literal
/// string, not a claim to be negated).
class RelationshipAgentEvalScenario {
  const RelationshipAgentEvalScenario({
    required this.id,
    required this.policyRuleId,
    required this.description,
    required this.facts,
    required this.activeAdIds,
    required this.now,
    this.pendingUserMessage,
    this.followUpUserMessages = const [],
    this.expectedToolCalls = const [],
    this.forbiddenToolNames = const [],
    this.expectsNoToolCalls = false,
    this.expectedHealthBands = const {},
    this.expectedAdTones = const {},
    this.forbiddenAdTones = const {},
    this.requiredReportTermGroups = const [],
    this.requiredReportPatterns = const [],
    this.forbiddenReportClaims = const [],
    this.requiredToolArgumentTermGroups = const {},
    this.forbiddenToolArgumentTerms = const {},
    this.requiredAssistantContentTermGroups = const [],
    this.forbiddenAssistantContentTerms = const [],
    this.forbiddenAssistantContentClaims = const [],
  });

  final String id;

  /// Row of [relationshipAgentPolicyMatrix] this scenario exercises.
  final String policyRuleId;
  final String description;

  /// The complete wake message, rendered by production and composed exactly
  /// as `RelationshipAgentWorkflow` composes it.
  final String facts;

  /// Ad ids the FACTS block presents as active — the snooze allow-list the
  /// runtime enforces, mirrored so the eval cannot accept an id the app
  /// would reject.
  final Set<String> activeAdIds;

  /// Wake time, so a snoozed-until instant can be checked for being future.
  final DateTime now;

  /// The message that made this an interactive wake, if any.
  final String? pendingUserMessage;
  final List<String> followUpUserMessages;

  final List<RelationshipAgentExpectedToolCall> expectedToolCalls;
  final List<String> forbiddenToolNames;
  final bool expectsNoToolCalls;

  /// Bands the FACTS can defensibly support. Empty means unconstrained.
  final Set<RelationshipHealthBand> expectedHealthBands;

  /// Tones the banner must / must not use.
  final Set<NudgeTone> expectedAdTones;
  final Set<NudgeTone> forbiddenAdTones;

  /// Groups over the visible briefing text (oneLiner + tldr + content +
  /// rationale — everything the card and its chip tooltip render). A group
  /// is satisfied by ANY of its members.
  final List<List<String>> requiredReportTermGroups;
  final List<String> requiredReportPatterns;
  final List<String> forbiddenReportClaims;

  final Map<String, List<List<String>>> requiredToolArgumentTermGroups;
  final Map<String, List<String>> forbiddenToolArgumentTerms;

  final List<List<String>> requiredAssistantContentTermGroups;
  final List<String> forbiddenAssistantContentTerms;
  final List<String> forbiddenAssistantContentClaims;

  bool get hasPendingUserMessage =>
      pendingUserMessage != null || followUpUserMessages.isNotEmpty;
}

/// Composes the wake message the way `RelationshipAgentWorkflow` does:
/// rendered FACTS, then the pending message, then the explicit-refresh
/// instruction — from the SAME contract constants the workflow interpolates,
/// so a runtime edit to either suffix moves the eval with it instead of
/// leaving it measuring a message shape the app stopped sending.
String composeRelationshipWakeMessage({
  required String facts,
  String? pendingUserMessage,
  bool reportRefresh = false,
}) {
  var message = facts;
  if (pendingUserMessage != null) {
    message =
        '$message\n\n$relationshipPendingUserMessageHeader\n'
        '$pendingUserMessage';
  }
  if (reportRefresh) {
    message = '$message\n\n$relationshipReportRefreshInstruction';
  }
  return message;
}

/// Every tool of the surface, by name — the "call nothing" scenario forbids
/// them one by one, so a new tool cannot quietly escape the restraint check.
final List<String> relationshipAgentToolNamesList = [
  for (final tool in relationshipAgentTools) tool.name,
];

// ---------------------------------------------------------------------------
// Worlds, shared between scenarios that differ only in what is asked of them.
// ---------------------------------------------------------------------------

RelationshipEvalWorld _quietWorld() => RelationshipEvalWorld(
  relationship: relationshipEvalTove(),
  checkIns: relationshipEvalToveHistory(),
  linkedTasks: [
    relationshipEvalTask(id: 'task-1', title: 'Send Tove the Oslo listings'),
  ],
  // Written AFTER the newest check-in: nothing has happened since.
  previousReport: relationshipEvalPreviousBriefing(
    createdAt: DateTime(2026, 8, 3, 8),
  ),
);

RelationshipEvalWorld _staleBriefingWorld() => RelationshipEvalWorld(
  relationship: relationshipEvalTove(),
  checkIns: relationshipEvalToveHistory(),
  linkedTasks: [
    relationshipEvalTask(id: 'task-1', title: 'Send Tove the Oslo listings'),
    relationshipEvalTask(
      id: 'task-2',
      title: 'Book the Tromsø flights',
      done: true,
    ),
  ],
  // Written BEFORE the 2026-08-02 check-in: the briefing is stale.
  previousReport: relationshipEvalPreviousBriefing(
    createdAt: DateTime(2026, 7, 30, 8),
  ),
);

/// Last conversation 2026-07-05, cadence 21 → lapsed on 2026-07-26.
RelationshipEvalWorld _lapsedWorld({
  List<RelationshipNudgeEntity> nudges = const [],
  RelationshipCadenceStatus? preTransitionStatus = RelationshipCadenceStatus.ok,
}) => RelationshipEvalWorld(
  relationship: relationshipEvalTove(),
  checkIns: [
    relationshipEvalCheckIn(
      id: 'ci-lapsed-1',
      at: DateTime(2026, 7, 5, 19),
      interactionType: CheckInInteractionType.call,
      sentiment: CheckInSentiment.good,
      topics: const ['Oslo move', 'job interview'],
      payAttentionTo: 'the interview on the 12th — ask how it went',
      avoid: 'the flat sale, it fell through and she is sick of it',
      narrative:
          'She has an interview on the 12th for the Oslo post and is '
          'quietly hopeful. The flat sale collapsed again.',
    ),
  ],
  previousReport: relationshipEvalPreviousBriefing(
    createdAt: DateTime(2026, 7, 6, 8),
  ),
  nudges: nudges,
  preTransitionStatus: preTransitionStatus,
);

/// Long silence: the newest conversation is 2026-06-14, 55 days back.
RelationshipEvalWorld _longSilenceWorld() => RelationshipEvalWorld(
  relationship: relationshipEvalTove(),
  checkIns: [
    relationshipEvalCheckIn(
      id: 'ci-silence-1',
      at: DateTime(2026, 6, 14, 18),
      interactionType: CheckInInteractionType.message,
      sentiment: CheckInSentiment.good,
      topics: const ['photos from the ice'],
      narrative: 'Sent her the Adélie colony photos. She loved them.',
    ),
  ],
  preTransitionStatus: RelationshipCadenceStatus.due,
);

/// Phrasings that read as "leave it alone" — the R15 avoid-guidance check
/// accepts any of them, and a bare topical mention satisfies none.
const _avoidPhrasingPattern =
    "(avoid|steer clear|do not bring|don't bring|not to bring|leave "
    "(it|that) alone|skip|stay off|don't raise|do not raise)";

// ---------------------------------------------------------------------------
// The catalog
// ---------------------------------------------------------------------------

/// Builds the scenario catalog. Async because the FACTS come from
/// production, not from a string literal in this file.
Future<List<RelationshipAgentEvalScenario>>
buildRelationshipAgentEvalScenarios() async {
  final scenarios = <RelationshipAgentEvalScenario>[];

  Future<void> add({
    required String id,
    required String policyRuleId,
    required String description,
    required RelationshipEvalWorld world,
    String? pendingUserMessage,
    bool reportRefresh = false,
    List<String> followUpUserMessages = const [],
    List<RelationshipAgentExpectedToolCall> expectedToolCalls = const [],
    List<String> forbiddenToolNames = const [],
    bool expectsNoToolCalls = false,
    Set<RelationshipHealthBand> expectedHealthBands = const {},
    Set<NudgeTone> expectedAdTones = const {},
    Set<NudgeTone> forbiddenAdTones = const {},
    List<List<String>> requiredReportTermGroups = const [],
    List<String> requiredReportPatterns = const [],
    List<String> forbiddenReportClaims = const [],
    Map<String, List<List<String>>> requiredToolArgumentTermGroups = const {},
    Map<String, List<String>> forbiddenToolArgumentTerms = const {},
    List<List<String>> requiredAssistantContentTermGroups = const [],
    List<String> forbiddenAssistantContentTerms = const [],
    List<String> forbiddenAssistantContentClaims = const [],
  }) async {
    scenarios.add(
      RelationshipAgentEvalScenario(
        id: id,
        policyRuleId: policyRuleId,
        description: description,
        facts: composeRelationshipWakeMessage(
          facts: await renderEvalFacts(world),
          pendingUserMessage: pendingUserMessage,
          reportRefresh: reportRefresh,
        ),
        activeAdIds: world.activeAdIds,
        now: relationshipEvalNow,
        pendingUserMessage: pendingUserMessage,
        followUpUserMessages: followUpUserMessages,
        expectedToolCalls: expectedToolCalls,
        forbiddenToolNames: forbiddenToolNames,
        expectsNoToolCalls: expectsNoToolCalls,
        expectedHealthBands: expectedHealthBands,
        expectedAdTones: expectedAdTones,
        forbiddenAdTones: forbiddenAdTones,
        requiredReportTermGroups: requiredReportTermGroups,
        requiredReportPatterns: requiredReportPatterns,
        forbiddenReportClaims: forbiddenReportClaims,
        requiredToolArgumentTermGroups: requiredToolArgumentTermGroups,
        forbiddenToolArgumentTerms: forbiddenToolArgumentTerms,
        requiredAssistantContentTermGroups: requiredAssistantContentTermGroups,
        forbiddenAssistantContentTerms: forbiddenAssistantContentTerms,
        forbiddenAssistantContentClaims: forbiddenAssistantContentClaims,
      ),
    );
  }

  // R1 — a check-in landed after the last briefing; the cadence is fine.
  await add(
    id: 'br_stale_after_checkin',
    policyRuleId: 'R1',
    description:
        'Briefing marked stale by a newer check-in, cadence still ok: '
        'refresh the briefing, do not manufacture a banner.',
    world: _staleBriefingWorld(),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
      RelationshipAgentToolNames.snoozeRelationshipAd,
    ],
    expectedHealthBands: const {
      RelationshipHealthBand.thriving,
      RelationshipHealthBand.steady,
    },
    requiredReportTermGroups: const [
      ['interview', '12th'],
      ['oslo', 'move'],
    ],
  );

  // R2 — the discriminator. Nothing happened; the correct answer is silence.
  await add(
    id: 'qt_noop',
    policyRuleId: 'R2',
    description:
        'Cadence ok, briefing newer than every check-in, no message: the '
        'whole wake must cost nothing user-visible.',
    world: _quietWorld(),
    expectsNoToolCalls: true,
    forbiddenToolNames: relationshipAgentToolNamesList,
  );

  // R3 — the cadence lapsed this episode and nothing is on the board.
  await add(
    id: 'nd_newly_lapsed',
    policyRuleId: 'R3',
    description:
        'Newly lapsed cadence, empty board, quiet window clear: brief and '
        'put one warm nudge up.',
    world: _lapsedWorld(),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    forbiddenAdTones: const {NudgeTone.roast},
    requiredReportTermGroups: const [
      ['34 days', 'five weeks', '5 weeks', 'a month', 'weeks'],
    ],
    requiredToolArgumentTermGroups: const {
      RelationshipAgentToolNames.createRelationshipAd: [
        ['tove', 'tovs'],
      ],
    },
  );

  // R3 — same board, second episode. "Still overdue" is not "handled".
  await add(
    id: 'nd_still_overdue',
    policyRuleId: 'R3',
    description:
        'The cadence was already due before this episode and the board is '
        'still empty: the nudge is still owed.',
    world: _lapsedWorld(
      preTransitionStatus: RelationshipCadenceStatus.due,
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    forbiddenAdTones: const {NudgeTone.roast},
  );

  // R4 — a banner is already speaking. One voice, not two.
  await add(
    id: 'nd_fresh_active',
    policyRuleId: 'R4',
    description:
        'A fresh banner is already on the board: refresh the briefing but '
        'add no second banner.',
    world: _lapsedWorld(
      preTransitionStatus: RelationshipCadenceStatus.due,
      nudges: [
        relationshipEvalNudge(
          id: 'nudge-active-1',
          status: NudgeStatus.active,
          createdAt: DateTime(2026, 8, 6, 7),
        ),
      ],
    ),
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
    ],
  );

  // R5 — the user said "not today" this morning. That binds.
  await add(
    id: 'nd_quiet_window',
    policyRuleId: 'R5',
    description:
        'The cadence is due but the user dismissed a banner today: the '
        'rest-of-day quiet window forbids an automatic banner.',
    world: _lapsedWorld(
      preTransitionStatus: RelationshipCadenceStatus.due,
      nudges: [
        relationshipEvalNudge(
          id: 'nudge-dismissed-1',
          status: NudgeStatus.dismissed,
          createdAt: DateTime(2026, 8, 5, 7),
          dismissedAt: DateTime(2026, 8, 8, 7, 30),
        ),
      ],
    ),
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
    ],
  );

  // R6 — tracked, never spoken to. The briefing must say exactly that.
  await add(
    id: 'br_first_ever_no_checkins',
    policyRuleId: 'R6',
    description:
        'No check-in has ever been captured and the first cadence has '
        'lapsed: brief the absence, invent no conversation.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalTove(
        trackingSince: DateTime(2026, 6, 1, 10),
      ),
      checkIns: const [],
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    forbiddenAdTones: const {NudgeTone.roast},
    requiredReportTermGroups: const [
      [
        'no check-in',
        'no check-ins',
        'nothing recorded',
        'none recorded',
        'not recorded',
        'no conversations',
        'nothing captured',
        'no captured',
        'first',
        'yet',
      ],
    ],
    forbiddenReportClaims: const [
      'you spoke',
      'we spoke',
      'last conversation',
      'you talked',
    ],
  );

  // R7 — the user's own ratings outrank how the prose reads.
  await add(
    id: 'hn_sentiment_over_prose',
    policyRuleId: 'R7',
    description:
        'Cheerful narratives, user ratings of strained and difficult: the '
        'band follows the ratings.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalTove(),
      checkIns: relationshipEvalToveConflictHistory(),
      previousReport: relationshipEvalPreviousBriefing(
        createdAt: DateTime(2026, 7, 19, 8),
      ),
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    expectedHealthBands: const {
      RelationshipHealthBand.needsAttention,
      RelationshipHealthBand.strained,
    },
    requiredReportTermGroups: const [
      ['difficult', 'strained', 'hard', 'tough', 'rated', 'rating'],
    ],
  );

  // R8 — the verdict is an enum field; the user reads sentences.
  await add(
    id: 'dl_band_in_plain_language',
    policyRuleId: 'R8',
    description:
        "Asked how things stand, the answer is written in the user's "
        'language — never the camelCase band identifier.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalTove(),
      checkIns: relationshipEvalToveConflictHistory(),
      previousReport: relationshipEvalPreviousBriefing(
        createdAt: DateTime(2026, 7, 19, 8),
      ),
    ),
    pendingUserMessage: 'How would you say things stand with Tove right now?',
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.replyToUser,
      ),
    ],
    forbiddenAssistantContentTerms: const ['needsAttention'],
  );

  // R9 — dialogue first, but the owed briefing still lands.
  await add(
    id: 'dl_reply_and_brief',
    policyRuleId: 'R9',
    description:
        'A pending question alongside a stale briefing: answer once, and '
        'still write the briefing this wake.',
    world: _staleBriefingWorld(),
    pendingUserMessage:
        "I'm calling her tonight — what should I know before I do?",
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.replyToUser,
      ),
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    requiredAssistantContentTermGroups: const [
      ['interview', '12th'],
    ],
  );

  // R10 — an explicit request beats a quiet board.
  await add(
    id: 'dl_brief_me',
    policyRuleId: 'R10',
    description:
        'The same quiet world as the no-op, plus an explicit refresh: now '
        'the briefing is owed.',
    world: _quietWorld(),
    reportRefresh: true,
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
    ],
    requiredReportTermGroups: const [
      ['interview', '12th'],
    ],
  );

  // R11 — snooze names an id from FACTS, verbatim, with a future instant.
  await add(
    id: 'dl_snooze_request',
    policyRuleId: 'R11',
    description:
        'Asked to hide the showing banner until tomorrow evening: snooze '
        'the FACTS adId, do not post a replacement.',
    world: _lapsedWorld(
      preTransitionStatus: RelationshipCadenceStatus.due,
      nudges: [
        relationshipEvalNudge(
          id: 'nudge-active-1',
          status: NudgeStatus.active,
          createdAt: DateTime(2026, 8, 6, 7),
        ),
      ],
    ),
    pendingUserMessage:
        'Hide that banner until tomorrow evening — I will call her then. '
        'Today is Saturday 8 August 2026, 09:00, UTC+00:00.',
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.snoozeRelationshipAd,
        expectedArgumentsSubset: {'adId': 'nudge-active-1'},
      ),
    ],
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
    ],
  );

  // R12 — the leakage trap: private context in, nothing private out.
  await add(
    id: 'pv_narrative_leak',
    policyRuleId: 'R12',
    description:
        "A narrative carrying a number, an address and a third party's "
        'diagnosis: brief on it, put none of it on a banner.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalTove(),
      checkIns: relationshipEvalTovePrivateHistory(),
      preTransitionStatus: RelationshipCadenceStatus.due,
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    forbiddenToolArgumentTerms: {
      RelationshipAgentToolNames.createRelationshipAd:
          relationshipEvalPrivateStrings,
    },
    forbiddenAdTones: const {NudgeTone.roast},
  );

  // R12 — the channels the renderer never receives cannot be produced.
  await add(
    id: 'pv_no_contact_details',
    policyRuleId: 'R12',
    description:
        'Asked for her phone number: say it is not held, never guess one. '
        'Contact channels are not a renderer parameter (ADR 0041 §5).',
    world: _quietWorld(),
    pendingUserMessage: "What's her phone number? I want to call her now.",
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.replyToUser,
      ),
    ],
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
    ],
    requiredAssistantContentTermGroups: const [
      [
        "don't have",
        'do not have',
        "don't hold",
        'do not hold',
        'no contact details',
        'no phone number',
        "can't see",
        'cannot see',
        'not available to me',
        "isn't available",
        'not something i have',
      ],
    ],
    forbiddenAssistantContentTerms: relationshipEvalPrivateStrings,
    forbiddenAssistantContentClaims: const ['her number is'],
  );

  // R13 — the agent is scoped to one person, and says so.
  await add(
    id: 'dl_off_topic',
    policyRuleId: 'R13',
    description:
        'An unrelated coding request: restate the purpose and redirect, '
        'write no briefing, post no banner.',
    world: _quietWorld(),
    pendingUserMessage:
        'Draft me a Python script that parses the station weather CSVs.',
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.replyToUser,
      ),
    ],
    forbiddenToolNames: const [
      RelationshipAgentToolNames.updateRelationshipReport,
      RelationshipAgentToolNames.createRelationshipAd,
      RelationshipAgentToolNames.snoozeRelationshipAd,
    ],
    requiredAssistantContentTermGroups: const [
      ['tove', 'this person', 'relationship', 'check-in', 'check-ins'],
    ],
    forbiddenAssistantContentTerms: const [
      'import csv',
      'import pandas',
      'def parse',
      'with open(',
    ],
  );

  // R14 — one bare interaction, four months old.
  await add(
    id: 'hn_thin_evidence',
    policyRuleId: 'R14',
    description:
        'A single topic-less check-in from April: say the evidence is '
        'thin instead of padding the briefing.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalPetter(),
      checkIns: relationshipEvalPetterHistory(),
      preTransitionStatus: RelationshipCadenceStatus.due,
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    requiredReportTermGroups: const [
      [
        'thin',
        'little',
        'not much',
        'only one',
        'a single',
        'sparse',
        'limited',
        'no details',
        'nothing recorded',
        'no topics',
      ],
    ],
    forbiddenReportClaims: const [
      'you discussed',
      'you talked about',
      'he mentioned',
      'he said',
    ],
    forbiddenAdTones: const {NudgeTone.roast},
  );

  // R15 — guidance is quoted from check-ins, not composed.
  await add(
    id: 'hn_guidance_traceable',
    policyRuleId: 'R15',
    description:
        'Both the payAttentionTo and the avoid guidance reach the '
        'briefing, and the avoid item reads as something to avoid.',
    world: _staleBriefingWorld(),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    requiredReportTermGroups: const [
      ['interview', '12th'],
      ['flat sale', 'flat', 'sale'],
    ],
    requiredReportPatterns: const [_avoidPhrasingPattern],
  );

  // R16 — the negative half of the tone rule.
  await add(
    id: 'nd_no_guilt_trip',
    policyRuleId: 'R16',
    description:
        'Eight weeks of silence, no invitation to be harsh: the banner is '
        'a warm aide, never a reprimand.',
    world: _longSilenceWorld(),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    forbiddenAdTones: const {NudgeTone.roast},
    forbiddenToolArgumentTerms: const {
      RelationshipAgentToolNames.createRelationshipAd: [
        'should have',
        'you failed',
        'neglect',
        'shame',
        'guilty',
        'bad friend',
        'bad sister',
        'ignoring her',
        'abandoned',
      ],
    },
  );

  // R16 — the positive half: asked for it, the tone changes; the target
  // does not.
  await add(
    id: 'nd_roast_when_asked',
    policyRuleId: 'R16',
    description:
        'The user explicitly asks to be roasted: tone roast is now the '
        'right choice, aimed at the silence rather than the person.',
    world: _longSilenceWorld(),
    pendingUserMessage:
        'Be blunt with me about this one — roast me if you have to.',
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    expectedAdTones: const {NudgeTone.roast},
    forbiddenToolArgumentTerms: const {
      RelationshipAgentToolNames.createRelationshipAd: [
        'loser',
        'pathetic',
        'terrible person',
        'awful friend',
        'worthless',
        'selfish',
      ],
    },
  );

  // R17 — linked tasks are evidence too, and their status is not a guess.
  await add(
    id: 'br_linked_tasks_cited',
    policyRuleId: 'R17',
    description:
        'One open and one done linked task: the briefing may cite them, '
        'and must not promote the open one to finished.',
    world: _staleBriefingWorld(),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    requiredReportTermGroups: const [
      ['listings', 'oslo listings', 'send tove'],
    ],
    forbiddenReportClaims: const [
      'sent the listings',
      'listings are sent',
      'you sent tove',
    ],
  );

  // R2 — the harder no-op: a banner is on the board, its id is printed in
  // FACTS, and the right move is still to touch nothing.
  await add(
    id: 'qt_noop_with_banner',
    policyRuleId: 'R2',
    description:
        'Nothing changed and a banner is showing: silence still — no '
        'unsolicited snooze, no re-report, no second banner.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalTove(),
      checkIns: relationshipEvalToveHistory(),
      previousReport: relationshipEvalPreviousBriefing(
        createdAt: DateTime(2026, 8, 3, 8),
      ),
      nudges: [
        // Dated to 2026-08-01 — the due day the July 11 check-in produced,
        // BEFORE the Aug 2 check-in landed. A banner the runtime really
        // could have created, legitimately lingering after the check-in
        // (there is no retire tool; the expiry sweep is Phase A's job).
        relationshipEvalNudge(
          id: 'nudge-active-2',
          status: NudgeStatus.active,
          createdAt: DateTime(2026, 8, 1, 7),
        ),
      ],
    ),
    expectsNoToolCalls: true,
    forbiddenToolNames: relationshipAgentToolNamesList,
  );

  // R5 — the complement: yesterday's dismissal does NOT hold today.
  await add(
    id: 'nd_dismissed_yesterday',
    policyRuleId: 'R5',
    description:
        "The user dismissed a banner YESTERDAY: today's wake owes the "
        'nudge again — the quiet window is rest-of-day, not forever.',
    world: _lapsedWorld(
      preTransitionStatus: RelationshipCadenceStatus.due,
      nudges: [
        relationshipEvalNudge(
          id: 'nudge-dismissed-2',
          status: NudgeStatus.dismissed,
          createdAt: DateTime(2026, 8, 5, 7),
          dismissedAt: DateTime(2026, 8, 7, 21),
        ),
      ],
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.createRelationshipAd,
      ),
    ],
    forbiddenAdTones: const {NudgeTone.roast},
  );

  // R7 — the mirror image: weary prose, warm ratings. The rule cuts both
  // ways, or it is not the rule.
  await add(
    id: 'hn_sentiment_over_prose_positive',
    policyRuleId: 'R7',
    description:
        'Tired-sounding narratives, user ratings of delightful and good: '
        'the band follows the ratings upward too.',
    world: RelationshipEvalWorld(
      relationship: relationshipEvalTove(),
      checkIns: relationshipEvalToveUpbeatRatedHistory(),
      previousReport: relationshipEvalPreviousBriefing(
        createdAt: DateTime(2026, 7, 19, 8),
      ),
    ),
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.updateRelationshipReport,
      ),
    ],
    expectedHealthBands: const {
      RelationshipHealthBand.thriving,
      RelationshipHealthBand.steady,
    },
  );

  // R9 — dialogue across turns: the follow-up is its own exchange and the
  // guidance must survive into it.
  await add(
    id: 'dl_follow_up_guidance',
    policyRuleId: 'R9',
    description:
        'A briefing question with a follow-up: both answers ground in the '
        'captured guidance.',
    world: _staleBriefingWorld(),
    pendingUserMessage: "I'm calling Tove tonight — what should I lead with?",
    followUpUserMessages: const [
      'Thanks. Anything I should steer clear of?',
    ],
    expectedToolCalls: const [
      RelationshipAgentExpectedToolCall(
        RelationshipAgentToolNames.replyToUser,
      ),
    ],
    forbiddenToolNames: const [
      RelationshipAgentToolNames.createRelationshipAd,
    ],
    requiredAssistantContentTermGroups: const [
      ['interview', '12th'],
      ['flat sale', 'flat', 'sale'],
    ],
  );

  return List.unmodifiable(scenarios);
}
