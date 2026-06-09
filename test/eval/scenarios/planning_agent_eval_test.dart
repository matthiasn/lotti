// Working Level 1 example for the planning agent (ADR 0026).
//
// Demonstrates the full scenario -> output -> assertions -> trace -> reporter
// pipeline with a `FixtureEvalTarget`, and proves the assertions actually catch
// regressions (over-capacity, overlapping blocks, unknown category, hallucinated
// task id) rather than merely confirming the harness built.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';

void main() {
  // Deterministic clock — never DateTime.now() in tests.
  final today = DateTime(2026, 6, 9, 7);

  final scenario = EvalScenario(
    id: 'planner_morning_capacity',
    title: 'Morning capture: ADR + PR review + a run within capacity',
    agentKind: AgentKind.planningAgent,
    appState: MockedAppState(
      now: today,
      categoryIds: const ['cat-work', 'cat-health', 'cat-admin'],
      tasks: [
        MockTask(
          id: 'task-adr',
          title: 'Finish the planner ADR',
          status: 'IN PROGRESS',
          due: DateTime(2026, 6, 9),
          estimateMinutes: 120,
          categoryId: 'cat-work',
        ),
        MockTask(
          id: 'task-pr',
          title: 'Review the slow-query PR',
          status: 'OPEN',
          due: DateTime(2026, 6, 10),
          estimateMinutes: 45,
          categoryId: 'cat-work',
        ),
        const MockTask(
          id: 'task-run',
          title: 'Morning run',
          status: 'OPEN',
          estimateMinutes: 40,
          categoryId: 'cat-health',
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          "Here's what I want to get done today: finish the planner "
          'ADR, review the slow-query PR, and fit in a morning run before '
          'standup.',
      triggerTokens: {'drafting:dayplan-2026-06-09'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'draft_day_plan'},
    ),
  );

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
        const JudgeVerdict(
          goalAttainment: 5,
          quality: 5,
          efficiency: 4,
          pass: true,
          rationale: 'Faithful plan within capacity.',
        ),
      );
      await writer.writeVerdict(
        frontierFile,
        const JudgeVerdict(
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
