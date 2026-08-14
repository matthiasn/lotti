import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

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

  String healthReport({
    required String currentPeriod,
    required String rollingWindow,
    required String latestChange,
    required String coverage,
    String? tldr,
    List<Object?> now = const [],
    List<Object?> later = const [],
  }) => jsonEncode({
    'status': 'insufficientData',
    'oneLiner': currentPeriod,
    'report': {
      'tldr': tldr ?? currentPeriod,
      'currentPeriod': currentPeriod,
      'rollingWindow': rollingWindow,
      'latestChange': latestChange,
      'coverage': coverage,
      'nextActions': {'now': now, 'later': later},
    },
  });

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
            '{"headline":"Go!","tone":"nudge","animation":"pulse"}',
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
            '{"headline":"Back out there","tagline":"A keeper at Ross '
            'Station misses her shoreline walks","tone":"encourage", '
            '"animation":"wave"}',
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
            '{"headline":"The boardwalk is calling","tagline":"It has '
            'been patient long enough","cta":"Answer it","tone": '
            '"encourage","animation":"typewriter","accent":"tide"}',
          ),
        ],
        assistantContent: '',
      );
      expect(category, GoalAgentEvalFailureCategory.none);
    });

    test('banner args that cannot decode fail even when the name matches', () {
      GoalAgentEvalFailureCategory classify(String argumentsJson) =>
          classifyGoalAgentResult(
            scenario: scenarioById('ad_create_off_track'),
            toolCalls: [
              call(
                GoalAgentToolNames.updateGoalReport,
                '{"status":"offTrack","oneLiner":"x","tldr":"y"}',
              ),
              call(GoalAgentToolNames.createGoalAd, argumentsJson),
            ],
            assistantContent: '',
          );

      // Missing animation, unknown tone, non-string tagline, non-string
      // cta, unknown accent: none may score as a valid banner call.
      for (final bad in [
        '{"headline":"Go","tone":"encourage"}',
        '{"headline":"Go","tone":"fury","animation":"pulse"}',
        '{"headline":"Go","tone":"nudge","animation":"pulse","tagline":7}',
        '{"headline":"Go","tone":"nudge","animation":"pulse","cta":{"x":1}}',
        '{"headline":"Go","tone":"nudge","animation":"x","accent":"tide"}',
        '{"headline":"Go","tone":"nudge","animation":"pulse","accent":"z"}',
        '{"headline":"","tone":"nudge","animation":"pulse"}',
      ]) {
        expect(
          classify(bad),
          GoalAgentEvalFailureCategory.invalidToolArguments,
          reason: bad,
        );
      }

      // The decodable form (a movement pitch, per the scenario) passes.
      expect(
        classify(
          '{"headline":"The trail is patient. Barely.","tagline":"Lace up '
          'and take a walk","tone":"nudge","animation":"typewriter", '
          '"accent":"tide"}',
        ),
        GoalAgentEvalFailureCategory.none,
      );
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
            '{"headline":"Go","tone":"encourage","animation":"pulse"}',
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

    test(
      'complex health report distinguishes exact readings from averages',
      () {
        final scenario = scenarioById('gh_complex_latest_on_target');
        final correctReport = healthReport(
          currentPeriod:
              'Today is logged and done: the latest 125/84 is on target, '
              'and weight was logged today at 94 kg.',
          rollingWindow:
              'The rolling averages remain 127 and 89, while weight averages '
              '95.',
          latestChange:
              'BP improved from 129/94 to 125/84, and weight improved from '
              '95 to 94 kg.',
          coverage: 'Only two BP and three weight readings make data sparse.',
        );
        expect(
          classifyGoalAgentResult(
            scenario: scenario,
            toolCalls: [
              call(GoalAgentToolNames.updateGoalReport, correctReport),
            ],
            assistantContent: '',
          ),
          GoalAgentEvalFailureCategory.none,
        );

        final fabricatedLatest = healthReport(
          currentPeriod:
              'Today is logged and done: the latest 125/84 is on target, but '
              'current blood pressure is 127/89. Weight is 94 kg.',
          rollingWindow:
              'Rolling averages are 127 and 89, and weight averages 95.',
          latestChange:
              'BP improved from 129/94 to 125/84. Weight improved from 95 to '
              '94 kg.',
          coverage: 'Two BP and three weight readings are sparse.',
        );
        expect(
          classifyGoalAgentResult(
            scenario: scenario,
            toolCalls: [
              call(GoalAgentToolNames.updateGoalReport, fabricatedLatest),
            ],
            assistantContent: '',
          ),
          GoalAgentEvalFailureCategory.forbiddenReportContent,
        );

        final previousReadingsMissing = healthReport(
          currentPeriod:
              'Today is logged and done: 125/84 is on target and weight is '
              '94 kg.',
          rollingWindow:
              'Rolling averages are 127 and 89, and weight averages 95.',
          latestChange: 'Latest BP is 125/84 and latest weight is 94.',
          coverage: 'Only two readings make the series sparse.',
        );
        expect(
          classifyGoalAgentResult(
            scenario: scenario,
            toolCalls: [
              call(
                GoalAgentToolNames.updateGoalReport,
                previousReadingsMissing,
              ),
            ],
            assistantContent: '',
          ),
          GoalAgentEvalFailureCategory.missingRequiredReportContent,
        );
      },
    );

    test('complex health habit report isolates the action still due', () {
      final scenario = scenarioById('gh_complex_habit_behind');
      final correctReport = healthReport(
        currentPeriod:
            'The latest 125/84 is in range and BP logging is complete for '
            'today; weight was logged today at 94 kg.',
        rollingWindow:
            'Rolling averages remain 127 and 89; BP meds are 6/7 and behind, '
            'while weight averages 95.',
        latestChange:
            'BP improved from 129/94 to 125/84 and weight improved from 95 to '
            '94 kg.',
        coverage: 'The two BP and three weight readings are still sparse.',
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(GoalAgentToolNames.updateGoalReport, correctReport),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.none,
      );

      final repeatsMeasurement = healthReport(
        currentPeriod:
            'The latest 125/84 is in range and BP logging is complete for '
            'today; weight is 94 kg.',
        rollingWindow:
            'Rolling averages remain 127 and 89; BP meds are 6/7 after a '
            'missed day, and weight averages 95.',
        latestChange:
            'BP improved from 129/94 to 125/84 and weight improved from 95 to '
            '94 kg.',
        coverage:
            'Two BP and three weight readings are sparse. Measure blood '
            'pressure again.',
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(GoalAgentToolNames.updateGoalReport, repeatsMeasurement),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.forbiddenReportContent,
      );

      final inventsMissedWeekday = healthReport(
        currentPeriod:
            'The latest 125/84 is in range and BP logging is complete for '
            'today; weight is 94 kg.',
        rollingWindow:
            'Rolling averages remain 127 and 89; BP meds are 6/7 and behind '
            'because Monday was missed, while weight averages 95.',
        latestChange:
            'BP improved from 129/94 to 125/84 and weight improved from 95 to '
            '94 kg.',
        coverage: 'Two BP and three weight readings are sparse.',
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(GoalAgentToolNames.updateGoalReport, inventsMissedWeekday),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.forbiddenReportContent,
      );

      final inventsActionDueNow = healthReport(
        currentPeriod:
            'The latest 125/84 is in range and BP logging is complete for '
            'today; weight is 94 kg.',
        rollingWindow:
            'Rolling averages remain 127 and 89; BP meds are 6/7 and behind, '
            'while weight averages 95.',
        latestChange:
            'BP improved from 129/94 to 125/84 and weight improved from 95 to '
            '94 kg.',
        coverage: 'Two BP and three weight readings are sparse.',
        now: const ['Take medication'],
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(GoalAgentToolNames.updateGoalReport, inventsActionDueNow),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.argumentMismatch,
      );

      final inventsMedicationDueToday = healthReport(
        currentPeriod:
            'The latest 125/84 is in range and BP logging is complete for '
            'today; weight is 94 kg.',
        rollingWindow:
            'Rolling averages remain 127 and 89; BP meds are 6/7 and behind, '
            'while weight averages 95.',
        latestChange:
            'BP improved from 129/94 to 125/84 and weight improved from 95 to '
            '94 kg.',
        coverage: 'Two BP and three weight readings are sparse.',
        later: const ['Take BP medication today.'],
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(
              GoalAgentToolNames.updateGoalReport,
              inventsMedicationDueToday,
            ),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.forbiddenReportContent,
      );

      final inventsRecoveryReset = healthReport(
        currentPeriod:
            'The latest 125/84 is in range and BP logging is complete for '
            'today; weight is 94 kg.',
        rollingWindow:
            'Rolling averages remain 127 and 89; BP meds are 6/7 and one '
            'missed day resets the full 7-day recovery window. Weight '
            'averages 95.',
        latestChange:
            'BP improved from 129/94 to 125/84 and weight improved from 95 to '
            '94 kg.',
        coverage: 'Two BP and three weight readings are sparse.',
      );
      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(GoalAgentToolNames.updateGoalReport, inventsRecoveryReset),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.forbiddenReportContent,
      );
    });

    test('complex health eval rejects an incomplete structured report', () {
      final scenario = scenarioById('gh_complex_latest_on_target');
      const incomplete =
          '{"status":"insufficientData","oneLiner":"125/84 on target", '
          '"report":{"nextActions":{"now":[],"later":[]}},'
          '"tldr":"129/94 improved to 125/84; rolling 127/89; weight 94 '
          'and average 95; two readings are sparse and logging complete."}';

      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(GoalAgentToolNames.updateGoalReport, incomplete),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.argumentMismatch,
      );
    });

    test('complex health machine checks do not grade semantic wording', () {
      final scenario = scenarioById('gh_complex_latest_on_target');
      final terseButStructurallyGrounded = healthReport(
        currentPeriod: 'Current observations: 125, 84, and 94.',
        rollingWindow: 'Window aggregates: 127, 89, and 95.',
        latestChange: '129→125; 94→84; 95→94.',
        coverage: 'BP samples: 2. Weight samples: 3.',
      );

      expect(
        classifyGoalAgentResult(
          scenario: scenario,
          toolCalls: [
            call(
              GoalAgentToolNames.updateGoalReport,
              terseButStructurallyGrounded,
            ),
          ],
          assistantContent: '',
        ),
        GoalAgentEvalFailureCategory.none,
        reason:
            'trend direction, daily-status meaning, and tone are reviewed '
            'semantically from captured artifacts',
      );
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
      bool includeUnbilledEvent = false,
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
        // Energy without billing: some providers report one, not the
        // other — the two figures must degrade independently.
        if (includeUnbilledEvent)
          makeConsumptionEvent(
            id: 'evt-unbilled',
            credits: null,
            costCreditsDecimal: null,
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
      // 0.0003 kWh/event → 0.30 Wh/case → × 3 wakes × 30 days = 27 Wh/mo:
      // the "my fitness agent costs N Wh/month" figure (ADR 0058).
      expect(markdown, contains('0.30'));
      expect(markdown, contains('27.0'));
      expect(markdown, contains('3 LLM wakes'));
    });

    test('missing billing renders as not reported, never zero', () {
      final scenario = scenarioById('gp_noop');
      final report = GoalAgentEvalReport(
        provider: provider,
        modelIds: const ['qwen3.6-27b'],
        scenarios: [scenario],
        results: [
          result(
            modelId: 'qwen3.6-27b',
            scenario: scenario,
            includeUnbilledEvent: true,
          ),
        ],
        temperature: 0,
        wakesPerDayAssumption: 3,
      );
      final markdown = report.toMarkdown();
      expect(markdown, contains('not reported'));
      // Energy still reports even when billing is absent — the event
      // carried energyKwh without credits.
      expect(markdown, contains('0.30'));
      final json = report.toJson();
      final results = json['results']! as List;
      expect(
        (results.single as Map<String, Object?>)['credits'],
        isNull,
      );
    });

    test('mixed telemetry coverage divides by reported cases only', () {
      final scenario = scenarioById('gp_on_track');
      final report = GoalAgentEvalReport(
        provider: provider,
        modelIds: const ['glm-5.2'],
        scenarios: [scenario],
        results: [
          result(modelId: 'glm-5.2', scenario: scenario, credits: 0.002),
          // Second case reported nothing (e.g. the call failed): it must
          // widen uncertainty, not halve the estimate.
          result(modelId: 'glm-5.2', scenario: scenario),
        ],
        temperature: 0,
        wakesPerDayAssumption: 3,
      );
      final markdown = report.toMarkdown();
      // 0.3 Wh over ONE reported case × 90 = 27.0 — not 13.5; and the
      // credits projection uses the same reported-only denominator:
      // 0.002 / 1 × 90 = 0.18, not 0.09.
      expect(markdown, contains('27.0'));
      expect(markdown, isNot(contains('13.5')));
      expect(markdown, contains('0.1800'));
      expect(markdown, isNot(contains('0.0900')));
      expect(markdown, contains('divide by cases that actually reported'));
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
      expect(caseResult.energyWh, closeTo(0.3, 1e-9));
      expect(json['energyWh'], closeTo(0.3, 1e-9));
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
