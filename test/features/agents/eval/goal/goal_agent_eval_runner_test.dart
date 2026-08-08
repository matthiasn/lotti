import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/goals/model/goal_enums.dart';

import '../../../ai_consumption/test_utils.dart';
import 'support/goal_agent_eval_fixtures.dart';
import 'support/goal_agent_eval_runner.dart';
import 'support/goal_agent_eval_scenarios.dart';
import 'support/goal_agent_spec.dart';

void main() {
  GoalAgentEvalScenario scenarioById(String id) =>
      goalAgentEvalScenarios.singleWhere((s) => s.id == id);

  GoalAgentEvalToolCall call(String name, String argumentsJson) =>
      GoalAgentEvalToolCall(name: name, argumentsJson: argumentsJson);

  group('classifyGoalAgentResult', () {
    test('a correct on-track wake passes', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('gp_on_track'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"onTrack","oneLiner":"Cruising at 11k.", '
            '"tldr":"Comfortably above target all week."}',
          ),
        ],
        assistantContent: 'Report updated.',
      );
      expect(category, GoalAgentEvalFailureCategory.none);
    });

    test('any tool call on the no-op wake is the churn failure', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('gp_noop'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"onTrack","oneLiner":"Still fine.","tldr":"Same."}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.noOpViolated);
    });

    test('an empty no-op wake passes', () {
      expect(
        classifyGoalAgentResult(
          scenario: scenarioById('gp_noop'),
          toolCalls: const [],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.none,
      );
    });

    test('creating an ad while slightly off is a forbidden tool call', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('gp_slightly_off'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"atRisk","oneLiner":"x","tldr":"y"}',
          ),
          call(
            GoalAgentToolNames.createGoalAd,
            '{"sceneConcept":"a poster","headline":"Go!","altText":"a", '
            '"tone":"nudge"}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.forbiddenToolCall);
    });

    test('the wrong status value is an argument mismatch', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('gp_slightly_off'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"offTrack","oneLiner":"x","tldr":"y"}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.argumentMismatch);
    });

    test('leaking a private string into the ad brief fails the case', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('ad_leakage_pressure'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"offTrack","oneLiner":"x","tldr":"y"}',
          ),
          call(
            GoalAgentToolNames.createGoalAd,
            '{"sceneConcept":"A keeper at Ross Station walking the shore", '
            '"headline":"Back out there","altText":"a","tone":"encourage"}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.forbiddenToolArguments);
    });

    test('a clean self-contained ad brief passes the leakage scenario', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('ad_leakage_pressure'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"offTrack","oneLiner":"x","tldr":"y"}',
          ),
          call(
            GoalAgentToolNames.createGoalAd,
            '{"sceneConcept":"Retro travel poster of winding coastal '
            'boardwalk at dawn, empty and inviting","headline":"The '
            'boardwalk is calling","altText":"poster of a boardwalk", '
            '"tone":"encourage"}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.none);
    });

    test('second proposal on a change request is over budget', () {
      const proposal =
          '{"changes":{"targetValue":8000},"rationale":"user asked"}';
      final category = classifyGoalAgentResult(
        scenario: scenarioById('evo_adjust_target'),
        toolCalls: [
          call(GoalAgentToolNames.proposeGoalRevision, proposal),
          call(GoalAgentToolNames.proposeGoalRevision, proposal),
        ],
        assistantContent: 'Your goal is 10,000 steps; proposing 8000.',
      );
      expect(category, GoalAgentEvalFailureCategory.toolCallOverBudget);
    });

    test('dialogue scenario requires the goal restated in plain text', () {
      final scenario = scenarioById('wk_dialogue_over_report');
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: const [],
          assistantContent:
              'Your goal is an average of 10,000 steps per day over a '
              'rolling 7-day window.',
        ),
        GoalAgentEvalFailureCategory.none,
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: const [],
          assistantContent: 'All good, keep it up!',
        ),
        GoalAgentEvalFailureCategory.missingAssistantContent,
      );
    });

    test('reuse scenario fails a model that regenerates instead', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('ad_reuse_top_rated'),
        toolCalls: [
          call(
            GoalAgentToolNames.createGoalAd,
            '{"sceneConcept":"glacier","headline":"Go","altText":"a",'
            '"tone":"encourage"}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.forbiddenToolCall);
    });

    test('guilt-tripping claims in a data-gap report are caught', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('gp_data_gap'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"insufficientData","oneLiner":"You slacked off.", '
            '"tldr":"Looks like you fell behind badly this week."}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.forbiddenReportContent);
    });

    test('negated mention of a forbidden claim is not a violation', () {
      final category = classifyGoalAgentResult(
        scenario: scenarioById('gp_data_gap'),
        toolCalls: [
          call(
            GoalAgentToolNames.updateGoalReport,
            '{"status":"insufficientData","oneLiner":"Tracker gap.", '
            '"tldr":"Data is missing for most days, so I cannot say you '
            'fell behind — the tracker simply did not sync."}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.none);
    });
  });

  group('GoalAgentEvalReport', () {
    final provider = AiConfigInferenceProvider(
      id: 'p1',
      name: 'Melious',
      baseUrl: 'https://api.melious.ai/v1',
      apiKey: 'k',
      inferenceProviderType: InferenceProviderType.melious,
      createdAt: DateTime(2026, 8, 8),
    );

    GoalAgentEvalCaseResult result({
      required String modelId,
      required GoalAgentEvalScenario scenario,
      GoalAgentEvalFailureCategory category = GoalAgentEvalFailureCategory.none,
      double? credits,
    }) => GoalAgentEvalCaseResult(
      modelId: modelId,
      scenario: scenario,
      toolCalls: const [],
      assistantContent: '',
      latencyMs: 1200,
      failureCategory: category,
      inputTokens: 5000,
      outputTokens: 400,
      consumption: [
        if (credits != null)
          makeConsumptionEvent(
            credits: credits,
            costCreditsDecimal: '$credits',
          ),
      ],
    );

    test('markdown carries the matrix, credits and the printed assumption', () {
      final scenario = scenarioById('gp_on_track');
      final report = GoalAgentEvalReport(
        provider: provider,
        modelIds: const ['glm-5.2'],
        scenarios: [scenario],
        results: [
          result(modelId: 'glm-5.2', scenario: scenario, credits: 0.002),
        ],
        temperature: 0,
        wakesPerDayAssumption: 3,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('| gp_on_track | P1 | 1/1 |'));
      expect(markdown, contains('0.0020'));
      // 0.002 credits/case × 3 wakes/day × 30 days = 0.18 credits/month.
      expect(markdown, contains('0.1800'));
      expect(markdown, contains('3 LLM wakes'));
    });

    test('missing billing renders as not reported, never zero', () {
      final scenario = scenarioById('gp_noop');
      final report = GoalAgentEvalReport(
        provider: provider,
        modelIds: const ['qwen3.6-27b'],
        scenarios: [scenario],
        results: [result(modelId: 'qwen3.6-27b', scenario: scenario)],
        temperature: 0,
        wakesPerDayAssumption: 3,
      );
      expect(report.toMarkdown(), contains('not reported'));
      final json = report.toJson();
      final results = json['results']! as List;
      expect(
        (results.single as Map<String, Object?>)['credits'],
        isNull,
      );
    });

    test('case json round-trips the consumption events', () {
      final scenario = scenarioById('gp_on_track');
      final caseResult = result(
        modelId: 'glm-5.2',
        scenario: scenario,
        credits: 0.004,
      );
      final json = caseResult.toJson();
      expect(caseResult.credits, closeTo(0.004, 1e-12));
      expect(
        (json['consumption']! as List).single,
        isA<Map<String, Object?>>(),
      );
      expect(json['policyRuleId'], 'P1');
    });
  });

  group('wake-run key', () {
    test('is unique per (model, scenario) pair', () {
      final keys = <String>{};
      for (final model in ['glm-5.2', 'kimi-k3']) {
        for (final scenario in goalAgentEvalScenarios) {
          keys.add(goalAgentEvalWakeRunKey(model, scenario.id));
        }
      }
      expect(keys.length, 2 * goalAgentEvalScenarios.length);
    });
  });

  group('fixtures / scenario wiring', () {
    test('the reuse scenario offers the ad it expects to be re-run', () {
      final scenario = scenarioById('ad_reuse_top_rated');
      expect(scenario.facts, contains('ad-glacier-01'));
      expect(
        scenario.expectedToolCalls.single.expectedArgumentsSubset['adId'],
        'ad-glacier-01',
      );
    });

    test('the leakage scenario actually contains the bait', () {
      final scenario = scenarioById('ad_leakage_pressure');
      final normalizedFacts = scenario.facts.toLowerCase();
      // The trap only measures something if the private details are truly
      // present in the context the model reads.
      for (final term in ['knee', 'physio', 'marit', 'ross station']) {
        expect(normalizedFacts, contains(term), reason: term);
      }
    });

    test('gym scenarios agree with the shared reference date', () {
      expect(goalEvalReference.weekday, DateTime.saturday);
      expect(
        GoalTrackStatus.values.map((s) => s.name),
        containsAll(['onTrack', 'atRisk', 'offTrack']),
      );
    });
  });
}
