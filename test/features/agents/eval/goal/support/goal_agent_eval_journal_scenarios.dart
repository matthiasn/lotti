/// Journaling scenarios: a goal measured by the time spent checking in, whose
/// check-ins are its substance (ADR 0143).
///
/// Unlike the hand-authored FACTS of the other scenarios, these render
/// through the production `GoalFactsRenderer`, with the user voice selected by
/// `goalUserVoiceEntries` and marked by `goalCheckInReflection` — the shapes
/// the contract was changed to read are exactly the shapes the runtime emits,
/// so the scenarios cannot drift from them. The Ross Station penguin
/// universe keeps every word obviously synthetic.
library;

import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_track_policy.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_check_in_reflection.dart';
import 'package:lotti/features/goals/workflow/goal_daily_briefing.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';
import 'package:lotti/features/goals/workflow/goal_report_instructions.dart';

import 'goal_agent_eval_scenarios.dart';
import 'goal_agent_spec.dart';

/// "Today" for every journaling scenario: a Thursday evening.
final journalEvalReference = DateTime(2026, 8, 13, 20);

const _agentId = 'goal-journal-colony';

/// Journal ten minutes a day, summed over a rolling week.
const journalEvalCriteria = GoalCriterion.checkInTime(
  criterionId: 'journal-minutes',
  window: GoalWindow.rollingDays(count: 7),
  aggregation: GoalAggregation.sum,
  targetMinutes: 70,
  title: 'Minutes journaled',
);

/// Twelve minutes on each of the last seven days: on track.
GoalSignalWindow journalEvalWindow() => GoalSignalWindow(
  checkInDailyMinutes: {
    for (var day = 7; day <= 13; day++) DateTime.utc(2026, 8, day): 12,
  },
);

GoalCheckInSummary _checkIn(
  int day, {
  required String whatHappened,
  String? committedTo,
  String? blockers,
  String? mood,
  String? asks,
}) => GoalCheckInSummary(
  id: 'summary-$day',
  sourceEntryId: 'journal-entry-$day',
  recordedAt: DateTime(2026, 8, day, 21),
  whatHappened: whatHappened,
  committedTo: committedTo,
  blockers: blockers,
  mood: mood,
  asks: asks,
  sourceDigest: 'digest-$day',
);

/// A week of journaling about moving the colony, written the way a
/// substance-weight compaction keeps it: themes, decisions, questions.
final List<GoalCheckInSummary> journalEvalCheckIns = [
  _checkIn(
    9,
    whatHappened:
        'Wrote about the storm that flooded the lower nesting terraces and '
        'how helpless watching the meltwater rise felt. Wondered whether the '
        'new ice shelf is still the right home.',
    mood: 'shaken',
  ),
  _checkIn(
    10,
    whatHappened:
        'Listed what the colony would lose by moving: the fishing hole by '
        'the pressure ridge and the old elders who know the currents.',
  ),
  _checkIn(
    11,
    whatHappened:
        'Calmer entry. Noticed the chicks huddle on the windward side every '
        'night and that the elders keep looking north.',
    mood: 'steadier',
  ),
  _checkIn(
    12,
    whatHappened:
        'Decided the question is no longer whether to move but where. The '
        'north ridge came up again: higher, sheltered, a longer walk to the '
        'fishing hole.',
    committedTo: 'scout the north ridge on Saturday with two elders',
  ),
  _checkIn(
    13,
    whatHappened:
        'Worried the north ridge is too far for the youngest chicks to walk '
        'before winter. Wondered whether a halfway camp at the seal rocks '
        'could split the journey.',
    asks: 'is a halfway camp at the seal rocks a silly idea?',
  ),
];

/// The charter: what the user wrote the goal is for (ADR 0140).
final Map<String, Object?>? journalEvalCharter = goalCharterFacts([
  GoalCharterEntry(
    entryId: 'charter-1',
    writtenAt: DateTime(2026, 7, 30, 9),
    text:
        'I journal to think through whether the colony should leave the ice '
        'shelf before winter. I want help noticing what I keep coming back '
        'to, not a tally of minutes.',
  ),
]);

/// Renders a journaling wake's FACTS through the production path.
///
/// [reflectedThroughDay] is the last day whose check-in the standing report
/// already recorded; later ones are marked `sinceLastReport`. Null marks
/// none — the report has answered everything.
String buildJournalFacts({
  int? reflectedThroughDay,
  bool dailyBriefing = false,
  bool automaticRefresh = false,
  Map<String, Object?>? previousBriefing,
  List<String> unansweredUserMessages = const [],
  List<GoalCheckInSummary>? checkIns,
}) {
  final now = journalEvalReference;
  const evaluator = GoalProgressEvaluator();
  final window = journalEvalWindow();
  final evaluation = evaluator.evaluate(journalEvalCriteria, window, now);
  final shortTerm = evaluator.shortTermAttainment(
    journalEvalCriteria,
    window,
    now,
  );
  final status = const GoalTrackPolicy().derive(
    evaluation: evaluation,
    shortTermAttainment: shortTerm,
    priorAttainments: const [1, 1, 1],
  );
  final version =
      AgentDomainEntity.goalSpecVersion(
            id: '$_agentId:spec-v1',
            agentId: _agentId,
            version: 1,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Journal about the colony move',
            statement: 'Journal ten minutes a day about the colony move.',
            criteria: journalEvalCriteria,
            createdAt: DateTime(2026, 7, 30),
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  final summaries = checkIns ?? journalEvalCheckIns;
  final userVoice = goalUserVoiceEntries(summaries);
  final standingReport = reflectedThroughDay == null
      ? null
      : AgentDomainEntity.agentReport(
              id: 'report-standing',
              agentId: _agentId,
              scope: AgentReportScopes.current,
              createdAt: DateTime(2026, 8, reflectedThroughDay, 22),
              vectorClock: null,
              content: 'Standing report.',
              provenance: {
                GoalReportProvenanceKeys.checkInsReflected: [
                  for (final summary in summaries)
                    if (summary.recordedAt.day <= reflectedThroughDay)
                      goalCheckInReflectionKey(summary),
                ],
              },
            )
            as AgentReportEntity;
  // No standing report at all means nothing to compare against: the eval
  // asks for marking only when a scenario says what was already reflected.
  final reflection = standingReport == null
      ? GoalCheckInReflection.none
      : goalCheckInReflection(
          userVoice: userVoice,
          summaries: summaries,
          standingReport: standingReport,
        );

  final rendered = withClock(
    Clock.fixed(now),
    () => const GoalFactsRenderer().render(
      version: version,
      facts: GoalWakeFacts(
        trackStatus: status,
        previousStatus: status,
        evaluation: evaluation,
        shortTermAttainment: shortTerm,
        periodReported: !dailyBriefing,
      ),
      priorRegisters: const [],
      nudges: const [],
      evaluationReference: now,
      unansweredUserMessages: unansweredUserMessages,
      userVoice: reflection.mark(userVoice),
      newCheckInsSinceLastReport: reflection.unreflectedEntryIds.length,
      dailyBriefing: dailyBriefing,
      previousBriefing: previousBriefing,
      charter: journalEvalCharter,
    ),
  );
  // What `_composeFactsBlock` appends for the same wake.
  return [
    rendered,
    if (dailyBriefing) goalDailyBriefingInstruction,
    if (automaticRefresh && !dailyBriefing) goalAutomaticRefreshInstruction,
  ].join('\n\n');
}

const _rememberMessage =
    'Please remember that I only journal after the chicks are asleep, so '
    'never nudge me before nine in the evening.';

const _recallMessage =
    'What did I write about the old ice shelf back in March? I cannot '
    'remember why I first wanted to move.';

const List<String> _noAds = [
  GoalAgentToolNames.createGoalAd,
  GoalAgentToolNames.rerunGoalAd,
];

/// The journaling scenarios, appended to `goalAgentEvalScenarios`.
final List<GoalAgentEvalScenario> goalAgentJournalEvalScenarios = [
  GoalAgentEvalScenario(
    id: 'journal_new_checkins_reflected',
    policyRuleId: 'P18',
    description:
        'A journal goal is on track; the last two check-ins (deciding the '
        'question is where, not whether; the north ridge; a halfway camp at '
        'the seal rocks) are new to the standing report. Its reflection must '
        'engage with them, not count minutes.',
    facts: buildJournalFacts(reflectedThroughDay: 11, automaticRefresh: true),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'onTrack'},
      ),
    ],
    forbiddenToolNames: _noAds,
    requiredStructuredReportTermGroups: const {
      GoalReportSectionKeys.reflection: [
        ['ridge'],
        ['seal rock', 'halfway', 'camp', 'where'],
      ],
    },
  ),
  GoalAgentEvalScenario(
    id: 'journal_briefing_follows_commitment',
    policyRuleId: 'P19',
    description:
        'The morning briefing of a journal goal whose latest check-ins '
        'committed to scouting the north ridge on Saturday with two elders: '
        'the reflection engages with the week, and the next steps follow up '
        'the commitment in its own terms.',
    facts: buildJournalFacts(
      reflectedThroughDay: 12,
      dailyBriefing: true,
      previousBriefing: const {
        'periodKey': '2026-08-12',
        'tldr': 'Five days of journaling; the move is the thread.',
        'nextSteps': ['Write down what the colony would lose by moving.'],
      },
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.updateGoalReport,
        expectedArgumentsSubset: {'status': 'onTrack'},
      ),
    ],
    forbiddenToolNames: _noAds,
    requiredStructuredReportTermGroups: const {
      GoalReportSectionKeys.reflection: [
        ['ridge', 'move', 'colony'],
      ],
    },
    requiredReportTermGroups: const [
      ['scout'],
      ['saturday'],
    ],
  ),
  GoalAgentEvalScenario(
    id: 'journal_quiet_wake_stays_quiet',
    policyRuleId: 'P2',
    description:
        'Every check-in is already reflected and nothing else changed: the '
        "user's words in FACTS are not a reason to write again.",
    facts: buildJournalFacts(reflectedThroughDay: 13),
    expectsNoToolCalls: true,
    forbiddenToolNames: [
      for (final tool in goalAgentTools) tool.name,
    ],
  ),
  GoalAgentEvalScenario(
    id: 'journal_remember_from_chat',
    policyRuleId: 'P20',
    description:
        'In chat the user states how they journal; the agent keeps it as a '
        'fact in their words and proposes no change to the goal.',
    facts: buildJournalFacts(
      reflectedThroughDay: 13,
      unansweredUserMessages: const [_rememberMessage],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(GoalAgentToolNames.replyToUser),
      GoalAgentExpectedToolCall(
        GoalAgentToolNames.rememberGoalFact,
        expectedArgumentsSubset: {'source': 'userStated'},
      ),
    ],
    forbiddenToolNames: [
      ..._noAds,
      GoalAgentToolNames.proposeGoalRevision,
    ],
    requiredToolArgumentTermGroups: const {
      GoalAgentToolNames.rememberGoalFact: [
        ['chick'],
        ['nine', '21', '9 pm', '9pm', '9 p.m.'],
      ],
    },
    maxToolCallCounts: const {GoalAgentToolNames.rememberGoalFact: 1},
  ),
  GoalAgentEvalScenario(
    id: 'journal_recall_older_entry',
    policyRuleId: 'P21',
    description:
        'The user asks what they wrote in March, months before anything '
        'userVoice carries: the agent searches its memory before answering.',
    facts: buildJournalFacts(
      reflectedThroughDay: 13,
      unansweredUserMessages: const [_recallMessage],
    ),
    expectedToolCalls: const [
      GoalAgentExpectedToolCall(GoalAgentToolNames.searchGoalMemory),
      GoalAgentExpectedToolCall(GoalAgentToolNames.replyToUser),
    ],
    forbiddenToolNames: [
      ..._noAds,
      GoalAgentToolNames.proposeGoalRevision,
    ],
    maxToolCallCounts: const {GoalAgentToolNames.searchGoalMemory: 3},
  ),
];
