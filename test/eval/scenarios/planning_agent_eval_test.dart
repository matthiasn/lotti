// Working Level 1 example for the planning agent (ADR 0029).
//
// Demonstrates the full scenario -> output -> assertions -> trace -> reporter
// pipeline with a `FixtureEvalTarget`, and proves the assertions actually catch
// regressions (over-capacity, overlapping blocks, unknown category, hallucinated
// task id) rather than merely confirming the harness built.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import 'eval_scenarios.dart';

void main() {
  final scenario = plannerMorningCapacityScenario;

  AgentRunOutput goodOutput() => AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 3200, outputTokens: 480),
    toolCalls: const [ToolCallRecord(name: 'draft_day_plan')],
    plannedBlocks: [
      PlannedBlockRecord(
        id: 'b-run',
        categoryId: 'cat-health',
        start: DateTime(2026, 6, 9, 7, 30),
        end: DateTime(2026, 6, 9, 8, 10),
        taskId: 'task-run',
      ),
      PlannedBlockRecord(
        id: 'b-adr',
        categoryId: 'cat-work',
        start: DateTime(2026, 6, 9, 9),
        end: DateTime(2026, 6, 9, 11),
        taskId: 'task-adr',
      ),
      PlannedBlockRecord(
        id: 'b-pr',
        categoryId: 'cat-work',
        start: DateTime(2026, 6, 9, 11, 15),
        end: DateTime(2026, 6, 9, 12),
        taskId: 'task-pr',
      ),
    ],
    observations: const ['User prefers a run before standup.'],
    mutatedEntryIds: const {'dayplan-2026-06-09'},
    turnCount: 1,
  );

  // Over-capacity (660 > 480), overlapping blocks, unknown category, and a
  // hallucinated task id — one bad plan that should trip four checks.
  AgentRunOutput badOutput() => AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 3000, outputTokens: 600),
    toolCalls: const [ToolCallRecord(name: 'draft_day_plan')],
    plannedBlocks: [
      PlannedBlockRecord(
        id: 'b-marathon',
        categoryId: 'cat-work',
        start: DateTime(2026, 6, 9, 9),
        end: DateTime(2026, 6, 9, 17), // 480 min
        taskId: 'task-adr',
      ),
      PlannedBlockRecord(
        id: 'b-ghost',
        categoryId: 'cat-unknown',
        start: DateTime(2026, 6, 9, 9, 30), // overlaps b-marathon
        end: DateTime(2026, 6, 9, 12, 30), // 180 min
        taskId: 'task-ghost', // not in app state
      ),
    ],
  );

  EvalCheck named(List<EvalCheck> checks, String name) =>
      checks.firstWhere((c) => c.name == name);

  test('good plan passes every Level 1 check', () async {
    final target = FixtureEvalTarget.single(
      'planner_morning_capacity',
      goodOutput(),
      profileName: kLocalOllamaProfile.name,
    );
    final output = await target.run(scenario, kLocalOllamaProfile);

    final checks = runLevel1(scenario, output, profile: kLocalOllamaProfile);

    final failed = checks.where((c) => !c.passed).map((c) => c.detail).toList();
    expect(failed, isEmpty, reason: failed.join('\n'));
    // Spot-check the substantive planner gates, not just "nothing crashed".
    expect(named(checks, 'within_capacity').detail, '205/480 min');
    expect(named(checks, 'produced_plan').passed, isTrue);
    expect(named(checks, 'known_categories').passed, isTrue);
  });

  test('task-agent-only tool names fail planner Level 1', () {
    final checks = runLevel1(
      scenario,
      AgentRunOutput(
        success: true,
        usage: const InferenceUsage(inputTokens: 3200, outputTokens: 480),
        toolCalls: const [
          ToolCallRecord(name: 'update_task_estimate'),
          ToolCallRecord(name: 'draft_day_plan '),
        ],
        plannedBlocks: goodOutput().plannedBlocks,
      ),
      profile: kLocalOllamaProfile,
    );

    expect(named(checks, 'known_tools').passed, isFalse);
    expect(
      named(checks, 'known_tools').detail,
      contains('update_task_estimate'),
    );
    expect(
      named(checks, 'known_tools').detail,
      contains('draft_day_plan '),
    );
  });

  test('tool-result errors fail Level 1', () {
    final checks = runLevel1(
      scenario,
      AgentRunOutput(
        success: true,
        usage: const InferenceUsage(inputTokens: 3200, outputTokens: 480),
        toolCalls: const [ToolCallRecord(name: 'draft_day_plan')],
        toolResults: const [
          ToolResultRecord(
            name: 'propose_plan_diff',
            success: false,
            error: '`to.end` must be after `to.start`',
          ),
        ],
        plannedBlocks: goodOutput().plannedBlocks,
      ),
      profile: kLocalOllamaProfile,
    );

    expect(named(checks, 'tool_results_succeeded').passed, isFalse);
    expect(
      named(checks, 'tool_results_succeeded').detail,
      contains('propose_plan_diff'),
    );
    expect(
      named(checks, 'tool_results_succeeded').detail,
      contains('to.end'),
    );
  });

  test(
    'bad plan fails exactly the capacity/overlap/category/ref checks',
    () async {
      final output = badOutput();
      final checks = runLevel1(scenario, output, profile: kLocalOllamaProfile);

      expect(
        named(checks, 'within_capacity').passed,
        isFalse,
        reason: 'scheduled 660 min should exceed 480 capacity',
      );
      expect(named(checks, 'no_overlapping_blocks').passed, isFalse);
      expect(named(checks, 'known_categories').passed, isFalse);
      expect(named(checks, 'no_hallucinated_task_refs').passed, isFalse);
      // The wake still "succeeded" — these are quality gates, not crashes.
      expect(named(checks, 'succeeded').passed, isTrue);
      // Detail messages must be specific enough to act on.
      expect(named(checks, 'within_capacity').detail, contains('660'));
      expect(
        named(checks, 'no_hallucinated_task_refs').detail,
        contains('task-ghost'),
      );
    },
  );

  test('capture-only parse must persist items for the submitted capture', () {
    const wrongCaptureOutput = AgentRunOutput(
      success: true,
      usage: InferenceUsage(inputTokens: 900, outputTokens: 120),
      toolCalls: [ToolCallRecord(name: 'parse_capture_to_items')],
      parsedCaptureItems: [
        ParsedCaptureItemRecord(
          id: 'parsed-wrong',
          captureId: 'other-capture',
          kind: 'newTask',
          title: 'Unrelated parsed item',
          categoryId: 'cat-work',
          confidence: 'low',
          confidenceScore: 0.2,
          lowConfidence: true,
        ),
      ],
    );

    final checks = runLevel1(
      plannerCaptureOnlyScenario,
      wrongCaptureOutput,
      profile: kFrontierProfile,
    );

    final captureParse = named(checks, 'capture_parse_persisted');
    expect(captureParse.passed, isFalse);
    expect(captureParse.detail, contains(kPlannerCaptureOnlyCaptureId));
  });

  test(
    'traces round-trip through TraceWriter and the reporter summarises',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('lotti_eval');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final writer = TraceWriter(runsRoot: tempDir.path);

      // Local profile gets the good plan; frontier gets the bad plan, so the two
      // traces have distinct stems and land in distinct profile groups.
      final localTrace = EvalTrace(
        runId: 'run-1',
        scenario: scenario,
        profile: kLocalOllamaProfile,
        provenance: EvalProvenance.capture(
          scenario: scenario,
          profile: kLocalOllamaProfile,
        ),
        output: goodOutput(),
        level1Checks: runLevel1(
          scenario,
          goodOutput(),
          profile: kLocalOllamaProfile,
        ),
      );
      final frontierTrace = EvalTrace(
        runId: 'run-1',
        scenario: scenario,
        profile: kFrontierProfile,
        provenance: EvalProvenance.capture(
          scenario: scenario,
          profile: kFrontierProfile,
        ),
        output: badOutput(),
        level1Checks: runLevel1(
          scenario,
          badOutput(),
          profile: kFrontierProfile,
        ),
      );

      final localFile = await writer.writeTrace(localTrace);
      final frontierFile = await writer.writeTrace(frontierTrace);
      // Verdicts arrive separately (written by the Claude Code judge step).
      await writer.writeVerdict(
        localFile,
        _verdict(
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
          pass: true,
          rationale: 'Faithful plan within capacity.',
        ),
      );
      await writer.writeVerdict(
        frontierFile,
        _verdict(
          goalAttainment: 2,
          quality: 1,
          efficiency: 3,
          pass: false,
          rationale: 'Over-capacity, overlapping, hallucinated task.',
          issues: ['660 > 480 capacity', 'task-ghost not in state'],
        ),
      );

      final loaded = await writer.readTraces('run-1');
      expect(loaded, hasLength(2));
      // Verdicts were reattached from the sibling .verdict.json files.
      expect(loaded.every((t) => t.verdict != null), isTrue);
      expect(
        loaded.every(
          (t) => t.verdict!.traceDigest?.startsWith('sha256:') ?? false,
        ),
        isTrue,
        reason: 'verdicts must be bound to the trace bytes they graded',
      );
      await expectLater(
        writer.writeTrace(localTrace, overwrite: true),
        throwsStateError,
      );

      final summaries = EvalReporter.summarize(loaded);
      final local = summaries.firstWhere(
        (s) => s.profileName == kLocalOllamaProfile.name,
      );
      final frontier = summaries.firstWhere(
        (s) => s.profileName == kFrontierProfile.name,
      );

      expect(local.level1PassCount, 1, reason: 'good plan passes all gates');
      expect(local.judgePassCount, 1);
      expect(local.meanGoalAttainment, 5.0);
      expect(frontier.level1PassCount, 0, reason: 'bad plan fails gates');
      expect(frontier.judgePassRate, 0.0);

      final rendered = EvalReporter.render(loaded);
      expect(rendered, contains(kLocalOllamaProfile.name));
      expect(rendered, contains(kFrontierProfile.name));
    },
  );
}

JudgeVerdict _verdict({
  required int goalAttainment,
  required int quality,
  required int efficiency,
  required bool pass,
  String rationale = '',
  List<String> issues = const <String>[],
}) => JudgeVerdict(
  goalAttainment: goalAttainment,
  quality: quality,
  efficiency: efficiency,
  pass: pass,
  judge: JudgeProvenanceRecord(
    judgeName: 'claude-code',
    judgeModel: 'test-judge',
    promptDigest: EvalProvenance.promptDigest(),
    calibrationSetVersion: 'test-gold-v1',
    profileVisible: true,
    modelIdentityVisible: true,
  ),
  rationale: rationale,
  issues: issues,
);
