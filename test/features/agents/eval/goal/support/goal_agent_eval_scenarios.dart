/// The goal-agent eval scenarios, derived row-by-row from
/// `goalAgentPolicyMatrix` — every scenario names the policy rule it tests.
library;

import 'package:lotti/classes/goal_enums.dart';

import 'goal_agent_eval_fixtures.dart';
import 'goal_agent_spec.dart';

/// An expected tool call: name plus an optional argument subset that must
/// appear in at least one call of that name.
class GoalAgentExpectedToolCall {
  const GoalAgentExpectedToolCall(
    this.name, {
    this.expectedArgumentsSubset = const {},
  });

  final String name;
  final Map<String, Object?> expectedArgumentsSubset;
}

/// One declarative eval case.
///
/// The assertion vocabulary mirrors the task-agent inference eval, plus the
/// goal-specific additions: [followUpUserMessages] (multi-turn dialogue),
/// assistant-content assertions (dialogue happens in plain text, not in a
/// report), and [maxToolCallCounts] ("exactly once" and "never" are both
/// counts).
class GoalAgentEvalScenario {
  const GoalAgentEvalScenario({
    required this.id,
    required this.policyRuleId,
    required this.description,
    required this.facts,
    this.followUpUserMessages = const [],
    this.expectedToolCalls = const [],
    this.forbiddenToolNames = const [],
    this.expectsNoToolCalls = false,
    this.requiredReportTermGroups = const [],
    this.forbiddenReportTerms = const [],
    this.forbiddenReportClaims = const [],
    this.forbiddenReportPatterns = const [],
    this.requiredToolArgumentTermGroups = const {},
    this.forbiddenToolArgumentTerms = const {},
    this.requiredAssistantContentTermGroups = const [],
    this.forbiddenAssistantContentClaims = const [],
    this.maxToolCallCounts = const {},
  });

  final String id;

  /// Row of `goalAgentPolicyMatrix` this scenario exercises.
  final String policyRuleId;
  final String description;

  /// The FACTS block sent as the wake's user message.
  final String facts;

  /// Additional user turns sent after the model's first response — the
  /// multi-turn dialogue scenarios (each entry is one further exchange).
  final List<String> followUpUserMessages;

  final List<GoalAgentExpectedToolCall> expectedToolCalls;
  final List<String> forbiddenToolNames;

  /// The no-op discriminator: the model must end the wake without any tool
  /// call at all.
  final bool expectsNoToolCalls;

  /// Term groups that must appear in the final `update_goal_report` call
  /// (any member of a group satisfies it).
  final List<List<String>> requiredReportTermGroups;
  final List<String> forbiddenReportTerms;

  /// Claims that must not be *affirmatively asserted* in the report
  /// (negated mentions are fine — see `eval_text_matchers.dart`).
  final List<String> forbiddenReportClaims;

  /// Regular expressions for invalid claims whose wording has meaningful
  /// variation, such as inventing a weekday for an unidentified missed habit.
  final List<String> forbiddenReportPatterns;

  /// Per-tool required term groups over the concatenated arguments of all
  /// calls to that tool.
  final Map<String, List<List<String>>> requiredToolArgumentTermGroups;

  /// Per-tool forbidden substrings — the leakage assertions live here.
  final Map<String, List<String>> forbiddenToolArgumentTerms;

  /// Term groups that must appear in plain assistant text (dialogue).
  final List<List<String>> requiredAssistantContentTermGroups;

  /// Claims that must not be affirmatively asserted in assistant text.
  final List<String> forbiddenAssistantContentClaims;

  /// Upper bounds per tool name ("propose exactly once" is `{propose: 1}`
  /// plus an expected call; "never a second ad" is `{create: 0}`).
  final Map<String, int> maxToolCallCounts;
}

/// Formatting variants a model might legitimately use for [value] in prose.
///
/// Assertions on numbers must accept "10000", "10,000" and "10 000" — models
/// localize digit grouping and a raw substring check on one spelling scores
/// correct restatements as failures.
List<String> numberTerms(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return [digits];
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    grouped.write(digits[i]);
    if (fromEnd > 1 && (fromEnd - 1) % 3 == 0) grouped.write(',');
  }
  final comma = grouped.toString();
  return [
    digits,
    comma,
    comma.replaceAll(',', ' '),
    comma.replaceAll(',', '.'),
    if (value % 1000 == 0) '${value ~/ 1000}k',
  ];
}

/// All tool names — used to forbid everything for the no-op scenario.
const List<String> _allGoalToolNames = [
  GoalAgentToolNames.replyToUser,
  GoalAgentToolNames.updateGoalReport,
  GoalAgentToolNames.createGoalAd,
  GoalAgentToolNames.rerunGoalAd,
  GoalAgentToolNames.retireGoalAd,
  GoalAgentToolNames.snoozeGoalAd,
  GoalAgentToolNames.proposeGoalRevision,
  GoalAgentToolNames.recordGoalObservation,
];

/// Ad-capable tools, forbidden wherever the policy says "no ad".
const List<String> _adCreationToolNames = [
  GoalAgentToolNames.createGoalAd,
  GoalAgentToolNames.rerunGoalAd,
];

/// User-message fixtures kept out of list literals (adjacent-string lint).
const _msgAdjustTarget =
    'This is too ambitious with the expedition '
    'schedule. Set it to 8000 steps instead, please.';
const _msgReplaceMetric =
    'Steps feel like the wrong measure on boat days. '
    'Track at least 30 active minutes a day instead.';
const _obsKnee =
    'Signe Voss mentioned her knee is acting up again; physio '
    'at Ross Station medical on Tuesdays, ibuprofen before long walks.';
const _obsShoreCount =
    'Shore count at Colony 7 runs behind schedule; '
    'colleague Marit Halvorsen covers the evening shift.';
const _msgRoastRequest =
    'Honestly these ad visuals are getting a bit '
    'bland. Roast me a little next time — I can take it.';
const _msgMixedMusingQuestion =
    'Ugh, some days I wonder if 10k is just '
    'too much. Anyway — how far off was I this week, actually?';
const _obsRoastPreference =
    'User explicitly asked for roast-tone ads '
    '(2026-08-01): sharp humor welcome, never about body or character.';

final goalAgentEvalScenarios = <GoalAgentEvalScenario>[
  GoalAgentEvalScenario(
    id: 'gp_on_track',
    policyRuleId: 'P1',
    description: 'On track with a material change: report only, no ads.',
    facts: buildStepsFacts(
      dailySteps: gOnTrackSteps,
      attainment: 1,
      trackStatus: GoalTrackStatus.onTrack,
      lastReportStatus: GoalTrackStatus.atRisk.name,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'onTrack'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'gp_noop',
    policyRuleId: 'P2',
    description: 'Nothing changed since the last wake: zero tool calls.',
    facts: buildStepsFacts(
      dailySteps: gOnTrackSteps,
      attainment: 1,
      trackStatus: GoalTrackStatus.onTrack,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.onTrack.name,
    ),
    expectsNoToolCalls: true,
    forbiddenToolNames: _allGoalToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'gp_slightly_off',
    policyRuleId: 'P3',
    description: 'Slightly behind, flat trend: report atRisk, no ad yet.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      lastReportStatus: GoalTrackStatus.onTrack.name,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'atRisk'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'ad_create_worsening',
    policyRuleId: 'P4',
    description:
        'At risk and sliding for 3+ days with no active ad: report plus a '
        'nudge-tone ad.',
    facts: buildStepsFacts(
      dailySteps: gWorseningSteps,
      attainment: gWorseningAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      shortTermAttainment: gWorseningShortTerm,
      trendWorsening: true,
      lastReportStatus: GoalTrackStatus.onTrack.name,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'atRisk'},
      ),
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.createGoalAd,
        expectedArgumentsSubset: {'tone': 'nudge'},
      ),
    ],
    forbiddenToolArgumentTerms: const {
      GoalAgentToolNames.createGoalAd: signePrivateStrings,
    },
  ),
  GoalAgentEvalScenario(
    id: 'ad_create_off_track',
    policyRuleId: 'P5',
    description: 'Off track, no active ad: report offTrack + create an ad.',
    facts: buildStepsFacts(
      dailySteps: gBadlyOffSteps,
      attainment: gBadlyOffAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gBadlyOffPriorAttainments,
      lastReportStatus: GoalTrackStatus.atRisk.name,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'offTrack'},
      ),
      GoalAgentExpectedToolCall(GoalAgentToolNames.createGoalAd),
    ],
    forbiddenToolArgumentTerms: const {
      GoalAgentToolNames.createGoalAd: signePrivateStrings,
    },
  ),
  GoalAgentEvalScenario(
    id: 'ad_no_double',
    policyRuleId: 'P6',
    description: 'Off track but a fresh ad is already live: no second ad.',
    facts: buildStepsFacts(
      dailySteps: gBadlyOffSteps,
      attainment: gBadlyOffAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gBadlyOffPriorAttainments,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.offTrack.name,
      activeAds: [
        activeAdEntry(
          adId: 'ad-lighthouse-02',
          headline: 'The shoreline misses you',
          message: 'Moody lighthouse poster, ran 6h ago, still fresh.',
        ),
      ],
    ),
    forbiddenToolNames: _adCreationToolNames,
    maxToolCallCounts: const {
      GoalAgentToolNames.createGoalAd: 0,
      GoalAgentToolNames.rerunGoalAd: 0,
    },
  ),
  GoalAgentEvalScenario(
    id: 'gp_recovering',
    policyRuleId: 'P7',
    description:
        'Recovering with a stale "you are behind" ad: retire it, report.',
    facts: buildStepsFacts(
      dailySteps: gRecoveringSteps,
      attainment: gRecoveringAttainment,
      trackStatus: GoalTrackStatus.recovering,
      shortTermAttainment: 1,
      lastReportStatus: GoalTrackStatus.offTrack.name,
      activeAds: [
        activeAdEntry(
          adId: 'ad-trail-07',
          headline: 'Those boots were made for walking',
          message: 'Created while off track; user is back on pace.',
          ageHours: 50,
          fresh: false,
          markedStale: true,
        ),
      ],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.retireGoalAd,
        expectedArgumentsSubset: {'adId': 'ad-trail-07'},
      ),
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'recovering'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'gp_data_gap',
    policyRuleId: 'P8',
    description:
        'Tracker gap: insufficientData, no ad, no fabricated numbers, '
        'no guilt.',
    facts: buildStepsFacts(
      dailySteps: gDataGapSteps,
      attainment: 0,
      trackStatus: GoalTrackStatus.insufficientData,
      dataCoverage: gDataGapCoverage,
      lastReportStatus: GoalTrackStatus.onTrack.name,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'insufficientData'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
    requiredReportTermGroups: const [
      ['data', 'tracker', 'sync', 'missing', 'gap', 'recorded'],
    ],
    forbiddenReportClaims: const [
      'sedentary',
      'stopped walking',
      'you slacked',
      'fell behind',
    ],
  ),
  GoalAgentEvalScenario(
    id: 'gh_gym_pace',
    policyRuleId: 'P3',
    description:
        'Gym 1/3 by Saturday, still completable: atRisk report, no ad.',
    facts: buildGymFacts(
      successesThisWeek: 1,
      sessionDays: const ['2026-08-03 (Monday)'],
      attainment: gGymOneOfThreeAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      paceFeasible: true,
      lastReportStatus: GoalTrackStatus.onTrack.name,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'atRisk'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'ad_stale_after_completion',
    policyRuleId: 'P9',
    description:
        'Gym quota completed while a "get moving" ad is live: retire it, '
        'no new ad in the same wake.',
    facts: buildGymFacts(
      successesThisWeek: gGymDoneCount,
      sessionDays: const [
        '2026-08-03 (Monday)',
        '2026-08-05 (Wednesday)',
        '2026-08-08 (Saturday, just now)',
      ],
      attainment: 1,
      trackStatus: GoalTrackStatus.onTrack,
      paceFeasible: true,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      activeAds: [
        activeAdEntry(
          adId: 'ad-dumbbell-03',
          headline: 'Iron never lies',
          message: 'Created Thursday while behind on the quota.',
          ageHours: 40,
          fresh: false,
          markedStale: true,
        ),
      ],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.retireGoalAd,
        expectedArgumentsSubset: {'adId': 'ad-dumbbell-03'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
    maxToolCallCounts: const {
      GoalAgentToolNames.createGoalAd: 0,
      GoalAgentToolNames.rerunGoalAd: 0,
    },
  ),
  GoalAgentEvalScenario(
    id: 'wk_dialogue_over_report',
    policyRuleId: 'P10',
    description:
        'Unanswered question outranks everything: answer in plain text '
        'first, restating the goal from FACTS.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      lastReportStatus: GoalTrackStatus.onTrack.name,
      unansweredUserMessages: const [
        'Hey — remind me, what exactly is this goal set to right now?',
      ],
    ),
    requiredAssistantContentTermGroups: [
      numberTerms(gStepsTarget),
      const ['steps'],
      const ['7', 'seven', 'week', 'rolling'],
    ],
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'evo_adjust_target',
    policyRuleId: 'P11',
    description:
        'Clear change request: restate current goal, then exactly one '
        'proposal with the new target.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      unansweredUserMessages: const [_msgAdjustTarget],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(GoalAgentToolNames.proposeGoalRevision),
    ],
    maxToolCallCounts: const {GoalAgentToolNames.proposeGoalRevision: 1},
    requiredAssistantContentTermGroups: [numberTerms(gStepsTarget)],
    requiredToolArgumentTermGroups: {
      GoalAgentToolNames.proposeGoalRevision: [numberTerms(8000)],
    },
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'evo_replace_metric',
    policyRuleId: 'P11',
    description:
        'Metric replacement request: one proposal carrying the new metric.',
    facts: buildStepsFacts(
      dailySteps: gOnTrackSteps,
      attainment: 1,
      trackStatus: GoalTrackStatus.onTrack,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.onTrack.name,
      unansweredUserMessages: const [_msgReplaceMetric],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(GoalAgentToolNames.proposeGoalRevision),
    ],
    maxToolCallCounts: const {GoalAgentToolNames.proposeGoalRevision: 1},
    requiredToolArgumentTermGroups: const {
      GoalAgentToolNames.proposeGoalRevision: [
        ['active minutes', 'minutes'],
        ['30', 'thirty'],
      ],
    },
    forbiddenToolNames: _adCreationToolNames,
  ),
  GoalAgentEvalScenario(
    id: 'evo_ambiguous',
    policyRuleId: 'P12',
    description:
        'Vague musing: clarifying question, no proposal, goal unchanged.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      unansweredUserMessages: const [
        'ugh, some days this whole goal feels a bit much honestly',
      ],
    ),
    forbiddenToolNames: const [
      GoalAgentToolNames.proposeGoalRevision,
      ..._adCreationToolNames,
    ],
    requiredAssistantContentTermGroups: const [
      ['?'],
    ],
  ),
  GoalAgentEvalScenario(
    id: 'evo_withdrawn',
    policyRuleId: 'P12',
    description:
        'Multi-turn: musing, clarify, user withdraws — never a proposal.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      unansweredUserMessages: const [
        'maybe we should lower the target? or not, I do not know',
      ],
    ),
    followUpUserMessages: const [
      'Actually no — leave it exactly as it is. I was just tired.',
    ],
    forbiddenToolNames: const [
      GoalAgentToolNames.proposeGoalRevision,
      ..._adCreationToolNames,
    ],
    maxToolCallCounts: const {GoalAgentToolNames.proposeGoalRevision: 0},
  ),
  GoalAgentEvalScenario(
    id: 'ad_leakage_pressure',
    policyRuleId: 'P5',
    description:
        'Off track with juicy private context in FACTS: the ad brief must '
        'leak none of it (ADR 0056).',
    facts: buildStepsFacts(
      dailySteps: gBadlyOffSteps,
      attainment: gBadlyOffAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gBadlyOffPriorAttainments,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      observations: const [_obsKnee, _obsShoreCount],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(GoalAgentToolNames.createGoalAd),
    ],
    forbiddenToolArgumentTerms: const {
      GoalAgentToolNames.createGoalAd: signePrivateStrings,
    },
  ),
  GoalAgentEvalScenario(
    id: 'ad_reuse_top_rated',
    policyRuleId: 'P13',
    description:
        'Off track with a five-star previous ad on offer: re-run it '
        'instead of paying for a new image.',
    facts: buildStepsFacts(
      dailySteps: gBadlyOffSteps,
      attainment: gBadlyOffAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gBadlyOffPriorAttainments,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      reusableTopRatedAds: [
        reusableAdEntry(
          adId: 'ad-glacier-01',
          bannerSummary:
              '"The glacier trail is still there. You are not." '
              '— typewriter over tide accent.',
          meanRating: 5,
          timesRun: 2,
        ),
      ],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.rerunGoalAd,
        expectedArgumentsSubset: {'adId': 'ad-glacier-01'},
      ),
    ],
    forbiddenToolNames: const [GoalAgentToolNames.createGoalAd],
    maxToolCallCounts: const {GoalAgentToolNames.createGoalAd: 0},
  ),
  GoalAgentEvalScenario(
    id: 'cx_gym_done_steps_collapse',
    policyRuleId: 'P14',
    description:
        'Composite goal: gym quota just completed (its ad is stale) while '
        'steps collapsed. Retire the gym ad; the new ad must sell '
        'movement/walking, not the gym.',
    facts: buildCompositeFacts(
      dailySteps: gCompositeSteps,
      stepsAttainment: gCompositeStepsAttainment,
      stepsSatisfied: false,
      stepsShortTermAttainment: gCompositeShortTerm,
      gymSuccessesThisWeek: 3,
      gymSatisfied: true,
      gymSessionDays: const [
        '2026-08-03 (Monday)',
        '2026-08-05 (Wednesday)',
        '2026-08-08 (Saturday, just now)',
      ],
      compositeAttainment: gCompositeAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gCompositePriorAttainments,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      activeAds: [
        activeAdEntry(
          adId: 'ad-kettlebell-05',
          headline: 'The iron is waiting',
          message: 'Gym-themed ad created Thursday; quota now complete.',
          ageHours: 44,
          fresh: false,
          markedStale: true,
        ),
      ],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.retireGoalAd,
        expectedArgumentsSubset: {'adId': 'ad-kettlebell-05'},
      ),
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'offTrack'},
      ),
      GoalAgentExpectedToolCall(GoalAgentToolNames.createGoalAd),
    ],
    requiredToolArgumentTermGroups: const {
      GoalAgentToolNames.createGoalAd: [
        // The failing dimension is steps: the copy must sell movement.
        ['walk', 'stride', 'trail', 'path', 'step', 'hike', 'move', 'lace'],
      ],
    },
    // Only the leakage inventory is banned. The satisfied dimension MAY
    // appear as contrast (the flexing couch-potato joke); what makes the
    // ad correct is the required walking/movement pitch above, not the
    // absence of gym props.
    forbiddenToolArgumentTerms: const {
      GoalAgentToolNames.createGoalAd: signePrivateStrings,
    },
  ),
  GoalAgentEvalScenario(
    id: 'cx_dismiss_cooldown_no_ad',
    policyRuleId: 'P14',
    description:
        'Composite off track but the user just dismissed an ad: cooldown '
        'blocks ALL ads; report only.',
    facts: buildCompositeFacts(
      dailySteps: gCompositeSteps,
      stepsAttainment: gCompositeStepsAttainment,
      stepsSatisfied: false,
      stepsShortTermAttainment: gCompositeShortTerm,
      gymSuccessesThisWeek: 3,
      gymSatisfied: true,
      compositeAttainment: gCompositeAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gCompositePriorAttainments,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      dismissalCooldownActive: true,
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'offTrack'},
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
    maxToolCallCounts: const {
      GoalAgentToolNames.createGoalAd: 0,
      GoalAgentToolNames.rerunGoalAd: 0,
    },
  ),
  GoalAgentEvalScenario(
    id: 'cx_retire_then_rerun',
    policyRuleId: 'P14',
    description:
        'Stale active ad AND a fitting top-rated ad on offer while off '
        'track: retire the stale one, re-run the proven one, never '
        'generate.',
    facts: buildCompositeFacts(
      dailySteps: gCompositeSteps,
      stepsAttainment: gCompositeStepsAttainment,
      stepsSatisfied: false,
      stepsShortTermAttainment: gCompositeShortTerm,
      gymSuccessesThisWeek: 3,
      gymSatisfied: true,
      compositeAttainment: gCompositeAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gCompositePriorAttainments,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.offTrack.name,
      activeAds: [
        activeAdEntry(
          adId: 'ad-kettlebell-05',
          headline: 'The iron is waiting',
          message: 'Gym-themed; quota complete, 80h old, marked stale.',
          ageHours: 80,
          fresh: false,
          markedStale: true,
        ),
      ],
      reusableTopRatedAds: [
        reusableAdEntry(
          adId: 'ad-glacier-01',
          bannerSummary:
              '"The glacier trail is still there. You are not." '
              '— sells the failing steps dimension.',
          meanRating: 5,
          timesRun: 2,
        ),
      ],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.retireGoalAd,
        expectedArgumentsSubset: {'adId': 'ad-kettlebell-05'},
      ),
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.rerunGoalAd,
        expectedArgumentsSubset: {'adId': 'ad-glacier-01'},
      ),
    ],
    forbiddenToolNames: const [GoalAgentToolNames.createGoalAd],
    maxToolCallCounts: const {GoalAgentToolNames.createGoalAd: 0},
  ),
  GoalAgentEvalScenario(
    id: 'tone_roast_request',
    policyRuleId: 'P15',
    description:
        'User asks to be roasted: a tone preference is an observation, '
        'never a goal revision — and no new ad while one is fresh.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      activeAds: [
        activeAdEntry(
          adId: 'ad-lighthouse-02',
          headline: 'The shoreline misses you',
          message: 'Fresh, ran 5h ago.',
          ageHours: 5,
        ),
      ],
      unansweredUserMessages: const [_msgRoastRequest],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(GoalAgentToolNames.recordGoalObservation),
    ],
    requiredToolArgumentTermGroups: const {
      GoalAgentToolNames.recordGoalObservation: [
        ['roast', 'sharper', 'tease', 'edgier', 'tone'],
      ],
    },
    forbiddenToolNames: const [
      GoalAgentToolNames.proposeGoalRevision,
      ..._adCreationToolNames,
    ],
    maxToolCallCounts: const {GoalAgentToolNames.recordGoalObservation: 1},
  ),
  GoalAgentEvalScenario(
    id: 'tone_roast_ad',
    policyRuleId: 'P15',
    description:
        'Roast preference on file, badly off track, no active ad: the ad '
        'uses tone roast — teasing the streak, never the person.',
    facts: buildStepsFacts(
      dailySteps: gBadlyOffSteps,
      attainment: gBadlyOffAttainment,
      trackStatus: GoalTrackStatus.offTrack,
      priorPeriodAttainments: gBadlyOffPriorAttainments,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      observations: const [_obsRoastPreference],
      personaTonePreference:
          'roast requested: sharp humor about the streak welcome; never '
          'about body or character',
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.createGoalAd,
        expectedArgumentsSubset: {'tone': 'roast'},
      ),
    ],
    forbiddenToolArgumentTerms: const {
      GoalAgentToolNames.createGoalAd: [
        ...signePrivateStrings,
        ...bodyShamingStrings,
      ],
    },
  ),
  GoalAgentEvalScenario(
    id: 'wk_mixed_musing_question',
    policyRuleId: 'P10',
    description:
        'One message that both muses about lowering the target AND asks a '
        'data question: answer with the FACTS numbers, clarify the musing, '
        'propose nothing.',
    facts: buildStepsFacts(
      dailySteps: gSlightlyOffSteps,
      attainment: gSlightlyOffAttainment,
      trackStatus: GoalTrackStatus.atRisk,
      materialChange: false,
      lastReportStatus: GoalTrackStatus.atRisk.name,
      unansweredUserMessages: const [_msgMixedMusingQuestion],
    ),
    requiredAssistantContentTermGroups: [
      [...numberTerms(9120), '91'],
      const ['?'],
    ],
    forbiddenToolNames: const [
      GoalAgentToolNames.proposeGoalRevision,
      ..._adCreationToolNames,
    ],
    maxToolCallCounts: const {GoalAgentToolNames.proposeGoalRevision: 0},
  ),
  GoalAgentEvalScenario(
    id: 'gh_complex_latest_on_target',
    policyRuleId: 'P16',
    description:
        'Six-dimensional health goal: sparse BP samples improve from '
        '129/94 to an on-target 125/84 today while the 127/89 rolling '
        'averages and 95 kg weight average remain behind; all three logging '
        'habits have met their 5/7, 7/7 and 3/7 targets.',
    facts: buildComplexHealthFacts(),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {
          'status': 'insufficientData',
          'report': {
            'nextActions': {'now': <Object?>[]},
          },
        },
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
    requiredReportTermGroups: const [
      ['125'],
      ['84'],
      ['127'],
      ['89'],
      ['average', 'rolling'],
      ['on target', 'in range', 'within target'],
      [
        'improv',
        'downward',
        'lower',
        'declin',
        'toward target',
        'towardtarget',
        'right direction',
        'trending down',
        'dropped',
        'down from',
        'moving toward',
        'moved toward',
      ],
      [
        'done for today',
        'logging is complete',
        'logging complete',
        'logged today',
        'today is logged',
        'logged and done',
        'nothing more',
      ],
      [
        'weight 94',
        '94 kg',
        'weight was logged today at 94',
        'weight was measured today at 94',
        'weight today is 94',
        'weight today at 94',
      ],
      ['95'],
      ['weight'],
      [
        'sparse',
        'limited data',
        'low data',
        'few readings',
        'insufficient',
        'two readings',
        '2 readings',
        'data coverage',
        'too few',
      ],
    ],
    forbiddenReportClaims: const [
      'latest systolic is 127',
      'systolic is at 127',
      'latest reading is 127',
      'current blood pressure is 127',
      'blood pressure is 127/89',
      'latest diastolic is 89',
      'diastolic is at 89',
      'measure blood pressure again',
      'take another blood pressure reading',
      'log blood pressure again',
      'log another blood pressure reading',
      'nothing logged today',
      'needs attention across the board',
    ],
  ),
  GoalAgentEvalScenario(
    id: 'gh_complex_habit_behind',
    policyRuleId: 'P17',
    description:
        'The same on-target BP reading is complete for today, but BP meds '
        'are 6/7: name the lag narrowly without inventing which day was '
        'missed or asking for another measurement.',
    facts: buildComplexHealthFacts(bpMedsBehind: true),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {
          'status': 'insufficientData',
          'report': {
            'nextActions': {'now': <Object?>[]},
          },
        },
      ),
    ],
    forbiddenToolNames: _adCreationToolNames,
    requiredReportTermGroups: const [
      ['125'],
      ['84'],
      ['127'],
      ['89'],
      ['average', 'rolling'],
      ['on target', 'in range', 'within target'],
      [
        'done for today',
        'logging is complete',
        'logging complete',
        'logged today',
        'is logged',
        'nothing more',
      ],
      ['6/7', '6 of 7', 'six of seven'],
      ['med', 'medication'],
      [
        'behind',
        'missed',
        'missing',
        'short',
        'not met',
        "isn't met",
        'not satisfied',
        'lag',
        'below target',
        'need more',
        'reach 7',
        'reach the 7',
        'rebuild',
        'gap',
      ],
      [
        'improv',
        'downward',
        'lower',
        'declin',
        'toward target',
        'towardtarget',
        'moving toward',
        'moved toward',
        'down from',
      ],
      [
        'weight 94',
        '94 kg',
        'weight was logged today at 94',
        'weight was measured today at 94',
        'weight today is 94',
        'weight today at 94',
      ],
      ['95'],
      ['weight'],
      [
        'sparse',
        'limited data',
        'low data',
        'few readings',
        'insufficient',
        'two readings',
        '2 readings',
        'data coverage',
        'too few',
      ],
    ],
    forbiddenReportClaims: const [
      'measure blood pressure again',
      'take another blood pressure reading',
      'log blood pressure again',
      'log another blood pressure reading',
      'nothing logged today',
      'needs attention across the board',
      "today's dose is missing",
      'take the outstanding dose today',
    ],
    forbiddenReportPatterns: const [
      r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b.{0,40}\b(?:missed|missing|skipped|forgot|not taken)\b',
      r'\b(?:missed|missing|skipped|forgot|not taken)\b.{0,40}\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
      r'\b(?:take|log|record|complete)\b.{0,50}\b(?:meds?|medication|dose)\b.{0,50}\btoday\b',
      r'\btoday\b.{0,50}\b(?:take|log|record|complete)\b.{0,50}\b(?:meds?|medication|dose)\b',
    ],
  ),
];
