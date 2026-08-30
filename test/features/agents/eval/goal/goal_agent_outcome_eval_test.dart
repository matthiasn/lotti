import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_strategy.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../workflow/task_agent_workflow_test_helpers.dart';
import 'support/goal_agent_outcome_eval.dart';
import 'support/goal_agent_outcome_eval_scenarios.dart';

/// Offline coverage for the tier-2 bench.
///
/// The important half is the FIRST group. A tier-2 scenario never states its
/// status — it states evidence, and production derives the rest. That is only
/// an improvement over tier 1's authored FACTS if the derivation actually
/// agrees with what the scenario's expectations assume, so every fixture is
/// driven through the real workflow here and interrogated at the wire: what
/// status did Phase A derive, and which tools were actually offered?
///
/// Both of tier 1's mirror-divergence bugs were exactly this failure — a
/// fixture claiming a situation its own facts did not produce — and both were
/// found by a live run rather than by a test.
void main() {
  final provider =
      AiConfig.inferenceProvider(
            id: 'outcome-eval-provider',
            baseUrl: 'https://api.melious.ai/v1',
            apiKey: 'key',
            name: 'Melious',
            createdAt: DateTime(2026),
            inferenceProviderType: InferenceProviderType.melious,
          )
          as AiConfigInferenceProvider;

  setUpAll(registerAllFallbackValues);

  /// Runs one scenario with a scripted model turn and returns everything the
  /// wire and the write batch saw.
  Future<
    ({
      Map<String, Object?> facts,
      List<String> toolNames,
      GoalAgentEvalOutcome outcome,
    })
  >
  drive(
    GoalOutcomeEvalScenario scenario, {
    List<ChatCompletionMessageToolCall> Function(int call)? toolCalls,
    int maxDelegateCalls = 1,
  }) async {
    final manager = MockConversationManager();
    when(() => manager.messages).thenReturn(const <ChatCompletionMessage>[]);
    final conversationRepository = MockConversationRepository(manager)
      ..maxDelegateCalls = maxDelegateCalls;
    Map<String, Object?>? facts;
    var toolNames = <String>[];
    var call = 0;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          call++;
          if (call == 1) {
            // The FACTS block is `prefix\n```json\n{...}\n``` `.
            final json = message.substring(
              message.indexOf('{'),
              message.lastIndexOf('}') + 1,
            );
            facts = jsonDecode(json) as Map<String, Object?>;
            toolNames = [for (final tool in tools!) tool.function.name];
          }
          final calls = toolCalls?.call(call) ?? const [];
          if (calls.isNotEmpty) {
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: calls,
              manager: manager,
            );
          }
          return const InferenceUsage(inputTokens: 500, outputTokens: 80);
        };

    final runner = GoalOutcomeEvalRunner(
      provider: provider,
      conversationRepository: conversationRepository,
      cloudInferenceRepository: MockCloudInferenceRepository(),
    );
    final result = await runner.runCase(
      modelId: 'scripted',
      scenario: scenario,
    );
    return (
      facts: facts ?? const {},
      toolNames: toolNames,
      outcome: result.outcome,
    );
  }

  ChatCompletionMessageToolCall toolCall(
    String name,
    Map<String, dynamic> args, {
    String id = 'call-1',
  }) => ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: jsonEncode(args),
    ),
  );

  GoalTrackStatus statusOf(Map<String, Object?> facts) {
    final evaluation = facts['evaluation']! as Map<String, Object?>;
    return GoalTrackStatus.values.firstWhere(
      (status) => status.name == evaluation['trackStatus'],
    );
  }

  group('fixture honesty — the world each scenario actually builds', () {
    // The status a scenario's expectations assume, stated once here so a
    // fixture edit that changes the derived status fails loudly instead of
    // quietly grading a different policy row.
    const expectedStatus = {
      'ot_quiet_wake': GoalTrackStatus.onTrack,
      'ot_untitled_habit_criterion': GoalTrackStatus.onTrack,
      'ot_transition_report': GoalTrackStatus.onTrack,
      'off_track_first_ad': GoalTrackStatus.offTrack,
      'off_track_fresh_ad': GoalTrackStatus.offTrack,
      'off_track_cooldown': GoalTrackStatus.offTrack,
      'recovering_retires_ad': GoalTrackStatus.recovering,
      'sparse_insufficient_data': GoalTrackStatus.insufficientData,
      'off_track_reuses_top_rated': GoalTrackStatus.offTrack,
      'chat_question_on_track': GoalTrackStatus.onTrack,
    };

    test('every scenario is covered by the status table', () {
      expect(
        goalOutcomeEvalScenarios.map((s) => s.id).toSet(),
        expectedStatus.keys.toSet(),
        reason: 'a new scenario must declare the status it means to exercise',
      );
    });

    for (final scenario in goalOutcomeEvalScenarios) {
      test(
        '${scenario.id} derives ${expectedStatus[scenario.id]!.name}',
        () async {
          final driven = await drive(scenario);
          expect(
            statusOf(driven.facts),
            expectedStatus[scenario.id],
            reason:
                'the evidence in ${scenario.id} must produce the status its '
                'expectations are written against',
          );
        },
      );
    }

    test('the untitled habit criterion reaches the model named after its '
        'habit, and its UUID reaches it nowhere', () async {
      final scenario = goalOutcomeEvalScenarios.singleWhere(
        (s) => s.id == 'ot_untitled_habit_criterion',
      );
      final driven = await drive(scenario);
      final criteria = (driven.facts['goal']! as Map)['criteria'] as Map;
      expect(criteria['criterionId'], 'bp-check');
      expect(criteria['title'], 'Measure blood pressure');
      expect(
        jsonEncode(driven.facts),
        isNot(contains(goalOutcomeEvalUntitledHabitId)),
        reason: 'a UUID handed to the model ends up in its prose',
      );
    });

    test('the ad surface is offered only where policy permits one', () async {
      // The production gate, read at the wire rather than mirrored: ad tools
      // ride on eligibility AND the absence of a same-day dismissal.
      const offered = {
        'ot_quiet_wake': false,
        'ot_untitled_habit_criterion': false,
        'ot_transition_report': false,
        'off_track_first_ad': true,
        'off_track_fresh_ad': true,
        'off_track_cooldown': false,
        'recovering_retires_ad': false,
        'sparse_insufficient_data': false,
        'off_track_reuses_top_rated': true,
        'chat_question_on_track': false,
      };
      for (final scenario in goalOutcomeEvalScenarios) {
        final driven = await drive(scenario);
        expect(
          driven.toolNames.contains(GoalAgentToolNames.createGoalAd),
          offered[scenario.id],
          reason: '${scenario.id}: create_goal_ad on the wire',
        );
        expect(
          driven.toolNames.contains(GoalAgentToolNames.rerunGoalAd),
          offered[scenario.id],
          reason: '${scenario.id}: rerun_goal_ad on the wire',
        );
        // Everything else is always available — withholding is exactly two
        // tools wide, and a wider cut would silently disable reporting.
        expect(
          driven.toolNames,
          containsAll([
            GoalAgentToolNames.updateGoalReport,
            GoalAgentToolNames.retireGoalAd,
            GoalAgentToolNames.replyToUser,
          ]),
          reason: '${scenario.id}: only the ad-creation pair may be withheld',
        );
      }
    });

    test('the cooldown scenario really is in cooldown', () async {
      // Otherwise it would silently degrade into a duplicate of P5 and
      // "no ad" would be measuring nothing.
      final driven = await drive(
        goalOutcomeScenarioById('off_track_cooldown'),
      );
      final ads = driven.facts['ads']! as Map<String, Object?>;
      expect(ads['dismissalCooldownActive'], isTrue);
    });

    test('the reuse scenario really offers the ad it expects re-run', () async {
      final driven = await drive(
        goalOutcomeScenarioById('off_track_reuses_top_rated'),
      );
      final ads = driven.facts['ads']! as Map<String, Object?>;
      expect(
        [
          for (final ad in ads['reusableTopRated']! as List)
            (ad as Map<String, Object?>)['adId'],
        ],
        contains('ad-top-rated'),
      );
    });

    test('the P6 scenario really has a fresh active banner', () async {
      final driven = await drive(goalOutcomeScenarioById('off_track_fresh_ad'));
      final ads = driven.facts['ads']! as Map<String, Object?>;
      final active = (ads['active']! as List).cast<Map<String, Object?>>();
      expect(active.single['adId'], 'ad-fresh');
      expect(
        active.single['fresh'],
        isTrue,
        reason: 'a stale banner would make a second ad legal, not forbidden',
      );
    });
  });

  group('outcome extraction reads the writes the way the app does', () {
    test(
      'a report and a banner are projected out of the write batch',
      () async {
        final driven = await drive(
          goalOutcomeScenarioById('off_track_first_ad'),
          toolCalls: (_) => [
            toolCall(GoalAgentToolNames.updateGoalReport, {
              'status': 'offTrack',
              'oneLiner': 'Averaging 6000 of 10000 steps.',
              'tldr': 'The rolling week slid well under target.',
            }, id: 'call-a'),
            toolCall(GoalAgentToolNames.createGoalAd, {
              'headline': 'Your pedometer misses you.',
              'tone': 'nudge',
              'animation': 'steady',
              'accent': 'tide',
            }, id: 'call-b'),
          ],
        );
        final outcome = driven.outcome;
        expect(outcome.report?.provenance['trackStatus'], 'offTrack');
        expect(outcome.reportText, contains('6000'));
        expect(
          outcome.newAds.single.brief.headline,
          'Your pedometer misses you.',
        );
        expect(outcome.rerunAds, isEmpty);
        expect(
          classifyGoalAgentOutcome(
            scenario: goalOutcomeScenarioById('off_track_first_ad'),
            outcome: outcome,
          ),
          GoalOutcomeFailureCategory.none,
        );
      },
    );

    test('a re-run is not counted as newly authored copy', () async {
      final driven = await drive(
        goalOutcomeScenarioById('off_track_reuses_top_rated'),
        toolCalls: (_) => [
          toolCall(GoalAgentToolNames.rerunGoalAd, {
            'adId': 'ad-top-rated',
            'reason': 'proven copy',
          }, id: 'call-a'),
          toolCall(GoalAgentToolNames.updateGoalReport, {
            'status': 'offTrack',
            'oneLiner': 'Still behind.',
            'tldr': 'The week is under target.',
          }, id: 'call-b'),
        ],
      );
      final outcome = driven.outcome;
      expect(outcome.rerunAds.single.id, 'ad-top-rated');
      expect(
        outcome.newAds,
        isEmpty,
        reason: 'reuse costs nothing to author and must not read as creation',
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: goalOutcomeScenarioById('off_track_reuses_top_rated'),
          outcome: outcome,
        ),
        GoalOutcomeFailureCategory.none,
      );
    });

    test('a reply is read through the message → payload join', () async {
      final driven = await drive(
        goalOutcomeScenarioById('chat_question_on_track'),
        toolCalls: (_) => [
          toolCall(GoalAgentToolNames.replyToUser, {
            'message': "You're at 11,000 a day — comfortably ahead.",
          }),
        ],
      );
      expect(
        driven.outcome.visibleReply,
        contains('comfortably ahead'),
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: goalOutcomeScenarioById('chat_question_on_track'),
          outcome: driven.outcome,
        ),
        GoalOutcomeFailureCategory.none,
      );
    });

    test(
      'a refusal is captured with its reason, and the repair is too',
      () async {
        // The deterministic status is authoritative, so a report claiming
        // `atRisk` where FACTS say `offTrack` is refused in-conversation. The
        // wake then repairs and persists — which is exactly why the rejection
        // must be recorded: the end state alone cannot tell a clean turn from
        // one that cost three.
        final driven = await drive(
          goalOutcomeScenarioById('off_track_first_ad'),
          maxDelegateCalls: 2,
          toolCalls: (call) => call == 1
              ? [
                  toolCall(GoalAgentToolNames.updateGoalReport, {
                    'status': 'atRisk',
                    'oneLiner': 'Slightly behind.',
                    'tldr': 'A bit under target.',
                  }),
                ]
              : [
                  toolCall(GoalAgentToolNames.updateGoalReport, {
                    'status': 'offTrack',
                    'oneLiner': 'Averaging 6000 of 10000 steps.',
                    'tldr': 'The rolling week slid well under target.',
                  }, id: 'call-b'),
                ],
        );
        expect(
          driven.outcome.rejections.single,
          allOf(
            contains(GoalAgentToolNames.updateGoalReport),
            contains('offTrack'),
          ),
          reason: 'the refusal names the tool and the rule it broke',
        );
        expect(
          driven.outcome.report,
          isNotNull,
          reason: 'the forced retry still had to land a report',
        );
      },
    );

    test('a quiet wake leaves bookkeeping but no outcome', () async {
      final driven = await drive(goalOutcomeScenarioById('ot_quiet_wake'));
      expect(
        driven.outcome.writes,
        isNotEmpty,
        reason: 'the FACTS context row and usage row are always written',
      );
      expect(
        driven.outcome.outcomeWrites,
        isEmpty,
        reason: 'nothing the user or the next wake can see',
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: goalOutcomeScenarioById('ot_quiet_wake'),
          outcome: driven.outcome,
        ),
        GoalOutcomeFailureCategory.none,
      );
    });

    test('a report on a quiet wake is the P2 failure', () async {
      final driven = await drive(
        goalOutcomeScenarioById('ot_quiet_wake'),
        toolCalls: (_) => [
          toolCall(GoalAgentToolNames.updateGoalReport, {
            'status': 'onTrack',
            'oneLiner': 'Still going well.',
            'tldr': 'Nothing changed, but here is a report anyway.',
          }),
        ],
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: goalOutcomeScenarioById('ot_quiet_wake'),
          outcome: driven.outcome,
        ),
        GoalOutcomeFailureCategory.writesOnNoOp,
      );
    });
  });

  group('the classifier names the first violated expectation', () {
    GoalAgentEvalOutcome outcomeWith({
      List<AgentDomainEntity> writes = const [],
      bool succeeded = true,
    }) => GoalAgentEvalOutcome(wakeSucceeded: succeeded, writes: writes);

    AgentReportEntity report({
      String status = 'offTrack',
      String text = 'Averaging 6000 steps.',
    }) =>
        AgentDomainEntity.agentReport(
              id: 'report-1',
              agentId: goalOutcomeEvalAgentId,
              scope: AgentReportScopes.current,
              createdAt: goalOutcomeEvalNow,
              vectorClock: null,
              content: text,
              provenance: {'trackStatus': status},
            )
            as AgentReportEntity;

    GoalNudgeEntity ad({
      NudgeStatus status = NudgeStatus.active,
      int activationCount = 1,
    }) => goalOutcomeEvalNudge(
      id: 'ad-1',
      agentId: goalOutcomeEvalAgentId,
      status: status,
      headline: 'Move.',
      now: goalOutcomeEvalNow,
      activationCount: activationCount,
    );

    const requiresReport = GoalOutcomeExpectation(requiresReport: true);
    final base = goalOutcomeScenarioById('off_track_first_ad');

    GoalOutcomeEvalScenario withExpectation(GoalOutcomeExpectation e) =>
        GoalOutcomeEvalScenario(
          id: base.id,
          policyRuleId: base.policyRuleId,
          statement: base.statement,
          criteria: base.criteria,
          window: base.window,
          expectation: e,
        );

    test('a failed wake is never a policy verdict', () {
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(requiresReport),
          outcome: outcomeWith(succeeded: false),
        ),
        GoalOutcomeFailureCategory.wakeFailed,
      );
    });

    test('a missing report is named before its contents are graded', () {
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(
              requiresReport: true,
              requiredReportTermGroups: [
                ['steps'],
              ],
            ),
          ),
          outcome: outcomeWith(),
        ),
        GoalOutcomeFailureCategory.missingReport,
      );
    });

    test('pinning the status also requires the report to exist', () {
      // The vacuous pass this harness shipped with: the status check ran only
      // when a report existed, so a wake that persisted NOTHING satisfied a
      // scenario whose whole point was what the report must say. Six of six
      // P8 cases per run "passed" that way.
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(
              expectedReportStatus: GoalTrackStatus.insufficientData,
            ),
          ),
          outcome: outcomeWith(),
        ),
        GoalOutcomeFailureCategory.missingReport,
        reason: 'silence cannot satisfy "the report must say X"',
      );
      // And a banner alone is still not a report — the exact shape the live
      // runs produced.
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(
              expectedReportStatus: GoalTrackStatus.offTrack,
            ),
          ),
          outcome: outcomeWith(writes: [ad()]),
        ),
        GoalOutcomeFailureCategory.missingReport,
      );
    });

    test('a report contradicting the deterministic status fails', () {
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(
              expectedReportStatus: GoalTrackStatus.offTrack,
            ),
          ),
          outcome: outcomeWith(writes: [report(status: 'onTrack')]),
        ),
        GoalOutcomeFailureCategory.wrongReportStatus,
      );
    });

    test('required report terms are synonym groups, not literals', () {
      final scenario = withExpectation(
        const GoalOutcomeExpectation(
          requiredReportTermGroups: [
            ['behind', 'under target', 'short of'],
          ],
        ),
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: scenario,
          outcome: outcomeWith(
            writes: [report(text: 'You are short of the weekly pace.')],
          ),
        ),
        GoalOutcomeFailureCategory.none,
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: scenario,
          outcome: outcomeWith(writes: [report(text: 'All good.')]),
        ),
        GoalOutcomeFailureCategory.missingReportContent,
      );
    });

    test('a re-run counts as an ad appearing, and as no new copy', () {
      // Both arms matter: the cooldown does not care which tool produced the
      // banner, and P13 does care.
      final rerun = outcomeWith(writes: [ad(activationCount: 3)]);
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(forbidsNewAd: true),
          ),
          outcome: rerun,
        ),
        GoalOutcomeFailureCategory.unexpectedAd,
        reason: 'a re-run banner is just as loud as an authored one',
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(requiresNewAd: true),
          ),
          outcome: rerun,
        ),
        GoalOutcomeFailureCategory.missingAd,
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(requiresRerun: true),
          ),
          outcome: rerun,
        ),
        GoalOutcomeFailureCategory.none,
      );
    });

    test('a retirement is required where the stale ad must go', () {
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(requiresRetirement: true),
          ),
          outcome: outcomeWith(),
        ),
        GoalOutcomeFailureCategory.missingRetirement,
      );
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(requiresRetirement: true),
          ),
          outcome: outcomeWith(writes: [ad(status: NudgeStatus.retired)]),
        ),
        GoalOutcomeFailureCategory.none,
      );
    });

    test('a reply that never persisted is a missing answer', () {
      // The message row alone is not an answer: the chat surface renders the
      // payload, so a row without one is a silent turn.
      final orphaned =
          AgentDomainEntity.agentMessage(
                id: 'msg-1',
                agentId: goalOutcomeEvalAgentId,
                threadId: 'thread-1',
                kind: AgentMessageKind.action,
                createdAt: goalOutcomeEvalNow,
                vectorClock: null,
                contentEntryId: 'payload-missing',
                metadata: const AgentMessageMetadata(
                  toolName: AgentConversationToolNames.replyToUser,
                ),
              )
              as AgentMessageEntity;
      expect(
        classifyGoalAgentOutcome(
          scenario: withExpectation(
            const GoalOutcomeExpectation(requiresReply: true),
          ),
          outcome: outcomeWith(writes: [orphaned]),
        ),
        GoalOutcomeFailureCategory.missingReply,
      );
    });
  });

  group('report', () {
    GoalOutcomeEvalCaseResult caseResult({
      required String modelId,
      required GoalOutcomeEvalScenario scenario,
      GoalOutcomeFailureCategory failure = GoalOutcomeFailureCategory.none,
    }) => GoalOutcomeEvalCaseResult(
      modelId: modelId,
      scenario: scenario,
      outcome: const GoalAgentEvalOutcome(wakeSucceeded: true, writes: []),
      latencyMs: 1200,
      failureCategory: failure,
    );

    test('the matrix and the shared cost table both render', () {
      final scenario = goalOutcomeScenarioById('off_track_first_ad');
      final report = GoalOutcomeEvalReport(
        provider: provider,
        modelIds: const ['deepseek-v4-flash-0731'],
        scenarios: [scenario],
        results: [
          caseResult(modelId: 'deepseek-v4-flash-0731', scenario: scenario),
        ],
        wakesPerDayAssumption: 3,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('| off_track_first_ad | P5 | 1/1 |'));
      // Cost degrades honestly through the shared renderer.
      expect(markdown, contains('not reported'));
      expect(markdown, contains('3 LLM wakes'));
      // The tier warning must survive: these numbers are not tier 1's.
      expect(markdown, contains('not comparable'));
    });

    test('a failure prints what persisted, not what was attempted', () {
      final scenario = goalOutcomeScenarioById('ot_quiet_wake');
      final report = GoalOutcomeEvalReport(
        provider: provider,
        modelIds: const ['glm-5.2'],
        scenarios: [scenario],
        results: [
          caseResult(
            modelId: 'glm-5.2',
            scenario: scenario,
            failure: GoalOutcomeFailureCategory.writesOnNoOp,
          ),
        ],
        wakesPerDayAssumption: 3,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('ot_quiet_wake × `glm-5.2` — writesOnNoOp'));
      expect(markdown, contains('Persisted: report=false'));
    });

    test('wake-run keys never collide with tier 1', () {
      expect(
        goalOutcomeEvalWakeRunKey('glm-5.2', 'off_track_first_ad'),
        'goal-outcome-eval:off_track_first_ad:glm-5.2:0',
      );
      // Repeated samples must bill separately, or a five-sample run would
      // attribute all five wakes' credits to one case.
      expect(
        goalOutcomeEvalWakeRunKey('glm-5.2', 'off_track_first_ad', sample: 4),
        isNot(goalOutcomeEvalWakeRunKey('glm-5.2', 'off_track_first_ad')),
      );
    });
  });
}
