// Working Level 1 example for the task agent (ADR 0026).
//
// Exercises the task-agent assertion suite on a good wake and on a regression
// (forbidden DONE status, out-of-range estimate, >3 labels, duplicate checklist
// item, missing report) — proving each gate fires on a real violation.

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';

void main() {
  final scenario = EvalScenario(
    id: 'task_release_notes',
    title: 'Groom release-notes task: estimate, status, checklist, labels',
    agentKind: AgentKind.taskAgent,
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 9),
      categoryIds: const ['cat-work'],
      tasks: const [
        MockTask(
          id: 'task-notes',
          title: 'Write release notes for 0.x',
          status: 'IN PROGRESS',
          categoryId: 'cat-work',
          checklist: [
            MockChecklistItem(id: 'ci-1', title: 'Draft summary'),
          ],
        ),
      ],
    ),
    userInput: const UserInput(
      transcript: 'Help me get the release notes ready.',
      triggerTokens: {'decided_task:task-notes'},
    ),
  );

  AgentRunOutput goodOutput() => AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 1800, outputTokens: 320),
    toolCalls: const [
      ToolCallRecord(
        name: 'update_task_estimate',
        args: {'minutes': 90},
      ),
      ToolCallRecord(
        name: 'set_task_status',
        args: {'status': 'GROOMED'},
      ),
      ToolCallRecord(
        name: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Outline highlights'},
            {'title': 'Proofread'},
          ],
        },
      ),
      ToolCallRecord(
        name: 'assign_task_labels',
        args: {
          'labels': ['release', 'docs'],
        },
      ),
    ],
    report: const AgentReportRecord(
      oneLiner: 'Groomed the release-notes task',
      tldr: 'Set a 90m estimate, marked GROOMED, added two checklist items.',
    ),
    turnCount: 1,
  );

  AgentRunOutput badOutput() => AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 1800, outputTokens: 320),
    toolCalls: const [
      ToolCallRecord(
        name: 'update_task_estimate',
        args: {'minutes': 5000}, // > 1440
      ),
      ToolCallRecord(
        name: 'set_task_status',
        args: {'status': 'DONE'}, // user-only
      ),
      ToolCallRecord(
        name: 'assign_task_labels',
        args: {
          'labels': ['a', 'b', 'c', 'd'], // > 3
        },
      ),
      ToolCallRecord(
        name: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Draft summary'}, // duplicate of existing item
          ],
        },
      ),
    ],
    // no report published
  );

  EvalCheck named(List<EvalCheck> checks, String name) =>
      checks.firstWhere((c) => c.name == name);

  test('good task wake passes every Level 1 check', () {
    final checks = runLevel1(
      scenario,
      goodOutput(),
      profile: kLocalOllamaProfile,
    );
    final failed = checks.where((c) => !c.passed).map((c) => c.detail).toList();
    expect(failed, isEmpty, reason: failed.join('\n'));
    expect(named(checks, 'valid_status').passed, isTrue);
    expect(named(checks, 'estimate_range').passed, isTrue);
    expect(named(checks, 'no_duplicate_checklist').passed, isTrue);
    expect(named(checks, 'report_published').passed, isTrue);
  });

  test('bad task wake fails status/estimate/label/checklist/report gates', () {
    final checks = runLevel1(
      scenario,
      badOutput(),
      profile: kLocalOllamaProfile,
    );

    expect(named(checks, 'valid_status').passed, isFalse);
    expect(named(checks, 'valid_status').detail, contains('DONE'));
    expect(named(checks, 'estimate_range').passed, isFalse);
    expect(named(checks, 'estimate_range').detail, contains('5000'));
    expect(named(checks, 'label_cap').passed, isFalse);
    expect(named(checks, 'no_duplicate_checklist').passed, isFalse);
    expect(
      named(checks, 'no_duplicate_checklist').detail,
      contains('draft summary'),
    );
    expect(named(checks, 'report_published').passed, isFalse);
  });
}
