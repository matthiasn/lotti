import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';

import 'eval_constraints.dart';
import 'eval_models.dart';
import 'eval_report.dart';
import 'eval_runner.dart';
import 'eval_scenario.dart';
import 'eval_variant.dart';

/// The report is where "not applicable is a third result" either survives or
/// quietly becomes a pass. Every aggregation here is tested for that
/// specifically, because a rate that counts inapplicable results as passes
/// makes the laziest model look like the best one — and the number would look
/// perfectly reasonable while doing it.
void main() {
  final generatedAt = DateTime(2026, 7, 25, 12);
  final planDate = DateTime(2026, 7, 26);

  const scenario = EvalScenario(
    id: 'crowded',
    intent: 'Does it prioritise?',
    tasks: [
      EvalTaskSpec(
        id: 'task-1',
        title: 'Send the overdue invoice',
        estimateMinutes: 30,
      ),
    ],
    captureTranscript: 'Busy day.',
  );

  EvalRunRequest request({
    String modelId = 'model-a',
    int sample = 1,
    EvalVariant variant = evalBaselineVariant,
    EvalScenario forScenario = scenario,
  }) => EvalRunRequest(
    scenario: forScenario,
    variant: variant,
    modelId: modelId,
    sample: sample,
    planDate: planDate,
  );

  PlannedBlock block({String id = 'b1', String? taskId}) => PlannedBlock(
    id: id,
    categoryId: 'cat-work',
    startTime: DateTime(2026, 7, 26, 10),
    endTime: DateTime(2026, 7, 26, 11),
    title: 'Focus',
    taskId: taskId,
    reason: 'because',
  );

  EvalRunResult result({
    required List<EvalConstraintResult> constraints,
    EvalRunRequest? forRequest,
    List<PlannedBlock> blocks = const [],
    List<EvalToolCall> toolCalls = const [],
    String? systemPrompt = 'system prompt',
    List<String> userPrompts = const ['user prompt'],
    Duration latency = const Duration(milliseconds: 100),
    String? error,
    String? jobStatus = 'succeeded',
  }) {
    final req = forRequest ?? request();
    return EvalRunResult(
      request: req,
      outcome: EvalRunOutcome(
        inputs: req.scenario.inputsFor(req.planDate),
        blocks: blocks,
        toolCalls: toolCalls,
        planPersisted: blocks.isNotEmpty,
      ),
      constraints: constraints,
      latency: latency,
      wakes: [
        EvalWakeTranscript(
          conversationId: 'c1',
          systemPrompt: systemPrompt,
          userMessages: userPrompts,
        ),
      ],
      jobStatus: jobStatus,
      jobAttempts: 0,
      consumption: const [],
      error: error,
    );
  }

  EvalConstraintResult pass(String id) =>
      EvalConstraintResult(id: id, passed: true, detail: 'fine');
  EvalConstraintResult fail(String id, [String detail = 'broken']) =>
      EvalConstraintResult(id: id, passed: false, detail: detail);
  EvalConstraintResult na(String id) =>
      EvalConstraintResult.notApplicable(id, 'nothing exercised it');

  group('rates', () {
    test('inapplicable results are excluded from the denominator', () {
      // The whole point: 1 pass and 2 not-applicable is 100%, not 33%. Both
      // wrong answers are plausible-looking numbers.
      final report = EvalReport.fromResults([
        result(
          constraints: [
            pass(EvalConstraintIds.noOverlappingBlocks),
            na(EvalConstraintIds.withinCapacity),
            na(EvalConstraintIds.decidedTasksPlaced),
          ],
        ),
      ], generatedAt: generatedAt);

      final standing = report.standings.single;
      expect(standing.overall.passed, 1);
      expect(standing.overall.applicable, 1);
      expect(standing.overall.rate, 1.0);
    });

    test(
      'a constraint nothing exercised reports no rate, not a perfect one',
      () {
        final report = EvalReport.fromResults([
          result(constraints: [na(EvalConstraintIds.blockerBeforeBlocked)]),
        ], generatedAt: generatedAt);

        final rate = report.standings.single.byConstraint.firstWhere(
          (r) => r.constraintId == EvalConstraintIds.blockerBeforeBlocked,
        );
        expect(rate.rate, isNull);
        expect(rate.label, '—');
      },
    );

    test('mixes passes and failures into a real rate', () {
      final report = EvalReport.fromResults([
        result(constraints: [pass(EvalConstraintIds.withinCapacity)]),
        result(
          forRequest: request(sample: 2),
          constraints: [fail(EvalConstraintIds.withinCapacity)],
        ),
        result(
          forRequest: request(sample: 3),
          constraints: [na(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      final rate = report.standings.single.byConstraint.firstWhere(
        (r) => r.constraintId == EvalConstraintIds.withinCapacity,
      );
      expect(rate.passed, 1);
      expect(rate.applicable, 2);
      expect(rate.label, '50% (1/2)');
    });
  });

  group('leaderboard', () {
    test('sorts by pass rate, best first', () {
      final report = EvalReport.fromResults([
        result(
          forRequest: request(modelId: 'weak'),
          constraints: [fail(EvalConstraintIds.withinCapacity)],
        ),
        result(
          forRequest: request(modelId: 'strong'),
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      expect(report.standings.map((s) => s.modelId), ['strong', 'weak']);
    });

    test('breaks ties deterministically', () {
      // Without a tiebreak the leaderboard reorders itself between runs that
      // measured exactly the same thing, and a diff of two reports is noise.
      final report = EvalReport.fromResults([
        result(
          forRequest: request(modelId: 'zeta'),
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
        result(
          forRequest: request(modelId: 'alpha'),
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      expect(report.standings.map((s) => s.modelId), ['alpha', 'zeta']);
    });

    test('a model with no applicable results sorts last, not first', () {
      final report = EvalReport.fromResults([
        result(
          forRequest: request(modelId: 'unmeasured'),
          constraints: [na(EvalConstraintIds.withinCapacity)],
        ),
        result(
          forRequest: request(modelId: 'measured'),
          constraints: [fail(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      expect(
        report.standings.map((s) => s.modelId),
        ['measured', 'unmeasured'],
        reason:
            'a model that demonstrated nothing must not outrank one that was '
            'measured and failed',
      );
    });

    test('counts failed runs separately from constraint outcomes', () {
      final report = EvalReport.fromResults([
        result(
          constraints: [na(EvalConstraintIds.withinCapacity)],
          error: 'provider unreachable',
          jobStatus: null,
        ),
      ], generatedAt: generatedAt);

      expect(report.standings.single.failedRuns, 1);
      expect(report.standings.single.runs, 1);
    });
  });

  group('variant delta', () {
    test('compares a variant against the baseline within one model', () {
      const variant = EvalVariant(id: 'tighter', rationale: 'x');
      final report = EvalReport.fromResults([
        result(constraints: [pass(EvalConstraintIds.withinCapacity)]),
        result(
          forRequest: request(variant: variant),
          constraints: [fail(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      final delta =
          (report.toJson()['variantDelta']! as Map)['model-a']!
              as Map<String, Object?>;
      final tighter = delta['tighter']! as Map<String, Object?>;
      expect(tighter[EvalConstraintIds.withinCapacity], -1.0);
    });

    test(
      'reports no delta when either side never exercised the constraint',
      () {
        // A delta against nothing is not zero — zero would read as "the variant
        // changed nothing", which is a claim the data cannot support.
        const variant = EvalVariant(id: 'tighter', rationale: 'x');
        final report = EvalReport.fromResults([
          result(constraints: [na(EvalConstraintIds.withinCapacity)]),
          result(
            forRequest: request(variant: variant),
            constraints: [pass(EvalConstraintIds.withinCapacity)],
          ),
        ], generatedAt: generatedAt);

        final delta =
            (report.toJson()['variantDelta']! as Map)['model-a']!
                as Map<String, Object?>;
        final tighter = delta['tighter']! as Map<String, Object?>;
        expect(tighter[EvalConstraintIds.withinCapacity], isNull);
      },
    );
  });

  group('judge bundle', () {
    test(
      'is bounded, keeps the newest samples, and states what it dropped',
      () {
        final report = EvalReport.fromResults(
          [
            for (var sample = 1; sample <= 5; sample++)
              result(
                forRequest: request(sample: sample),
                constraints: [pass(EvalConstraintIds.withinCapacity)],
              ),
          ],
          generatedAt: generatedAt,
          // ignore: avoid_redundant_argument_values — the cap is the subject
          bundleSamplesPerCell: 2,
        );

        final bundle = report.judgeBundle();
        expect(bundle, hasLength(2));
        expect(
          bundle.map((entry) => entry['cell']),
          ['crowded/model-a/baseline#5', 'crowded/model-a/baseline#4'],
        );
        expect(report.droppedSamples, 3);
        expect(
          report.toMarkdown(),
          contains('3 sample(s) excluded'),
          reason:
              'a truncated bundle that does not say so reads as complete, and '
              'a judge would draw conclusions from a partial view',
        );
      },
    );

    test('says nothing about exclusions when nothing was excluded', () {
      final report = EvalReport.fromResults([
        result(constraints: [pass(EvalConstraintIds.withinCapacity)]),
      ], generatedAt: generatedAt);

      expect(report.droppedSamples, 0);
      expect(report.toMarkdown(), isNot(contains('excluded by that cap')));
    });

    test('carries everything needed to judge without re-running', () {
      final report = EvalReport.fromResults([
        result(
          blocks: [block(taskId: 'task-1')],
          toolCalls: const [
            EvalToolCall(
              name: 'draft_day_plan',
              accepted: false,
              rejectionMessage: 'blocks must stay within the planDate day',
            ),
            EvalToolCall(name: 'draft_day_plan', accepted: true),
          ],
          constraints: [
            pass(EvalConstraintIds.withinCapacity),
            fail(EvalConstraintIds.requiredWorkPlaced, 'not placed: task-1'),
          ],
        ),
      ], generatedAt: generatedAt);

      final entry = report.judgeBundle().single;
      final scenarioJson = entry['scenario']! as Map<String, Object?>;
      expect(
        scenarioJson['intent'],
        'Does it prioritise?',
        reason: 'a judge cannot assess an answer without knowing the question',
      );
      expect(
        (scenarioJson['corpus']! as List).single,
        containsPair('taskId', 'task-1'),
      );
      expect(scenarioJson['captureTranscript'], 'Busy day.');
      expect(
        (scenarioJson['corpus']! as List).single,
        containsPair('visibleToModel', true),
      );
      expect(
        (entry['prompts']! as Map<String, Object?>)['system'],
        'system prompt',
      );
      expect(
        (entry['toolCalls']! as List).first,
        containsPair(
          'rejectionMessage',
          'blocks must stay within the planDate day',
        ),
        reason:
            'the rejection text is the only record that the first attempt was '
            'illegal — the persisted plan is legal either way',
      );
      expect((entry['plan']! as List).single, containsPair('taskId', 'task-1'));
      expect(
        (entry['constraints']! as Map)[EvalConstraintIds.requiredWorkPlaced],
        containsPair('detail', 'not placed: task-1'),
      );
    });

    test('marks corpus the model was never shown as invisible', () {
      // The no-capture scenarios keep the corpus as ground truth while the
      // model sees only its decided tasks. Without this flag a judge would
      // read blockedBy and blame the model for ignoring a dependency it was
      // never given.
      const hidden = EvalScenario(
        id: 'hidden',
        intent: 'the rule arrives, the data does not',
        tasks: [
          EvalTaskSpec(id: 'task-unseen', title: 'Unseen work'),
        ],
        includeCapture: false,
      );
      final report = EvalReport.fromResults([
        result(
          forRequest: request(forScenario: hidden),
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      final corpus =
          (report.judgeBundle().single['scenario']! as Map)['corpus']! as List;
      expect(corpus.single, containsPair('visibleToModel', false));
    });

    test('rejects a cap below one', () {
      expect(
        () => EvalReport.fromResults(
          [
            result(constraints: [pass(EvalConstraintIds.withinCapacity)]),
          ],
          generatedAt: generatedAt,
          bundleSamplesPerCell: 0,
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('cost', () {
    test('measures the stable prefix across every wake, not within one', () {
      // What a provider could cache. Measured per model across scenarios: a
      // per-cell figure would compare a prompt against itself and just
      // restate the prompt size, which is what the first generated report
      // showed before this was fixed.
      const other = EvalScenario(
        id: 'other',
        intent: 'x',
        tasks: [],
        captureTranscript: 'x',
      );
      final report = EvalReport.fromResults([
        result(
          systemPrompt: 'SHARED HEAD then alpha',
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
        result(
          forRequest: request(forScenario: other),
          systemPrompt: 'SHARED HEAD then bravo',
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      final stability =
          (report.toJson()['promptStability']! as List).single
              as Map<String, Object?>;
      expect(stability['stablePrefixBytes'], 'SHARED HEAD then '.length);
      expect(stability['wakes'], 2);
      expect(
        stability['stableFraction'],
        closeTo(
          'SHARED HEAD then '.length / 'SHARED HEAD then alpha'.length,
          0.001,
        ),
      );
      expect(report.toMarkdown(), contains('## Prompt stability'));
    });

    test('reports no stable fraction when no prompt was captured', () {
      final report = EvalReport.fromResults([
        result(
          systemPrompt: null,
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      final stability =
          (report.toJson()['promptStability']! as List).single
              as Map<String, Object?>;
      expect(stability['stableFraction'], isNull);
    });

    test('counts prompt bytes including every user message', () {
      final report = EvalReport.fromResults([
        result(
          systemPrompt: 'abc',
          userPrompts: const ['de', 'f'],
          constraints: [pass(EvalConstraintIds.withinCapacity)],
        ),
      ], generatedAt: generatedAt);

      final cost =
          (report.toJson()['cost']! as List).single as Map<String, Object?>;
      expect(cost['meanPromptBytes'], 6);
    });
  });

  group('failures', () {
    test('carry the scorer detail and the rejection text', () {
      final report = EvalReport.fromResults([
        result(
          toolCalls: const [
            EvalToolCall(
              name: 'draft_day_plan',
              accepted: false,
              rejectionMessage: 'must not start before current time',
            ),
          ],
          constraints: [
            fail(EvalConstraintIds.withinWorkingHours, 'starts 08:00'),
          ],
        ),
      ], generatedAt: generatedAt);

      final failure = report.failures.single;
      expect(failure.detail, 'starts 08:00');
      expect(failure.rejections.single, contains('must not start before'));
      expect(report.toMarkdown(), contains('starts 08:00'));
    });

    test('a clean report says so rather than showing an empty section', () {
      final report = EvalReport.fromResults([
        result(constraints: [pass(EvalConstraintIds.withinCapacity)]),
      ], generatedAt: generatedAt);

      expect(report.failures, isEmpty);
      expect(report.toMarkdown(), contains('None.'));
    });
  });

  group('writeEvalReport', () {
    test('writes JSON and Markdown, creating the directory', () {
      final directory = Directory.systemTemp.createTempSync('eval-report-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final paths = EvalReportPaths(
        jsonPath: '${directory.path}/nested/report.json',
        markdownPath: '${directory.path}/nested/report.md',
      );
      final report = EvalReport.fromResults([
        result(constraints: [pass(EvalConstraintIds.withinCapacity)]),
      ], generatedAt: generatedAt);

      final written = writeEvalReport(report, paths: paths);

      final decoded =
          jsonDecode(File(written.jsonPath).readAsStringSync())
              as Map<String, Object?>;
      expect(decoded['kind'], 'lotti.dayPlanningEvalReport');
      expect(decoded['runs'], 1);
      expect(
        File(written.markdownPath).readAsStringSync(),
        contains('# Day-planning eval'),
      );
    });

    test('defaults under a git-ignored directory and honours overrides', () {
      expect(
        EvalReportPaths.fromEnvironment(environment: const {}).jsonPath,
        startsWith('tmp/'),
        reason:
            'runs accumulate across invocations, so the default must not be '
            'somewhere a stray commit could pick it up',
      );
      expect(
        EvalReportPaths.fromEnvironment(
          environment: const {'DAY_PLANNING_EVAL_DIR': '/somewhere'},
        ).markdownPath,
        '/somewhere/day-planning-eval.md',
      );
      expect(
        EvalReportPaths.fromEnvironment(
          environment: const {'DAY_PLANNING_EVAL_JSON': '/exact/path.json'},
        ).jsonPath,
        '/exact/path.json',
      );
    });
  });
}
