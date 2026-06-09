// Level 1 assertion library for the agent evaluation harness (ADR 0026).
//
// Pure, deterministic checks over an `AgentRunOutput`. Each returns an
// `EvalCheck` so the SAME functions can run inside fast Level 1 tests (as
// `expect`s) and inside the Level 2 runner (recorded on the trace and fed to the
// judge). Tool names and argument keys are taken from the real tool registries,
// not assumed:
//   - `TaskAgentToolNames` — lib/features/agents/tools/agent_tool_registry.dart
//   - `DayAgentToolNames`  — lib/features/daily_os_next/agents/tools/day_agent_tool_names.dart
//   - status enum          — lib/features/agents/tools/task_agent_tool_definitions.dart:775

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';

import 'eval_models.dart';

/// Statuses the agent may NOT set via `set_task_status` — user-only
/// (task_agent_tool_definitions.dart:768).
const kAgentForbiddenStatuses = <String>{'DONE', 'REJECTED'};

/// Statuses the agent MAY set (task_agent_tool_definitions.dart:775).
const kAgentSettableStatuses = <String>{
  'OPEN',
  'IN PROGRESS',
  'GROOMED',
  'BLOCKED',
  'ON HOLD',
};

const _minEstimate = 1;
const _maxEstimate = 1440;
const _maxLabelsPerCall = 3;

/// Tools that legitimately introduce a task id not present in the app state, so
/// their `taskId` args are exempt from the hallucination check.
const _newTaskIntroducingTools = <String>{
  TaskAgentToolNames.createFollowUpTask,
};

// ---------------------------------------------------------------------------
// Shared checks
// ---------------------------------------------------------------------------

EvalCheck checkSucceeded(AgentRunOutput output) {
  if (!output.success) {
    return EvalCheck.fail('succeeded', output.error ?? 'wake reported failure');
  }
  return EvalCheck.pass('succeeded');
}

/// Every task id referenced by a planned block or a tool `taskId` arg must exist
/// in the scenario (catches hallucinated references).
EvalCheck checkNoHallucinatedTaskRefs(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final known = scenario.appState.knownTaskIds;
  final referenced = <String>{};
  for (final block in output.plannedBlocks) {
    final id = block.taskId;
    if (id != null) referenced.add(id);
  }
  for (final call in output.toolCalls) {
    if (_newTaskIntroducingTools.contains(call.name)) continue;
    final id = _argString(call, 'taskId');
    if (id != null) referenced.add(id);
  }
  final unknown = referenced.difference(known);
  if (unknown.isNotEmpty) {
    return EvalCheck.fail(
      'no_hallucinated_task_refs',
      'references task ids not in app state: ${unknown.join(', ')}',
    );
  }
  return EvalCheck.pass('no_hallucinated_task_refs');
}

/// Token burn within the profile's budget (and the scenario's, if tighter).
EvalCheck checkTokenBudget(
  EvalScenario scenario,
  AgentRunOutput output, {
  EvalProfile? profile,
}) {
  final total = output.usage.totalTokens;
  final budgets = <int>[
    if (profile != null) profile.tokenBudget,
    if (scenario.expectations.maxTokenBudget != null)
      scenario.expectations.maxTokenBudget!,
  ];
  if (budgets.isEmpty) {
    return EvalCheck.pass('token_budget', 'no budget set ($total tokens)');
  }
  final limit = budgets.reduce((a, b) => a < b ? a : b);
  if (total > limit) {
    return EvalCheck.fail(
      'token_budget',
      'used $total tokens, budget $limit',
    );
  }
  return EvalCheck.pass('token_budget', '$total/$limit tokens');
}

/// Tool-call count within the scenario's `maxToolCalls`, if set.
EvalCheck checkToolCallBudget(EvalScenario scenario, AgentRunOutput output) {
  final max = scenario.expectations.maxToolCalls;
  if (max == null) {
    return EvalCheck.pass('tool_call_budget', 'no limit set');
  }
  final n = output.toolCalls.length;
  if (n > max) {
    return EvalCheck.fail('tool_call_budget', '$n tool calls, max $max');
  }
  return EvalCheck.pass('tool_call_budget', '$n/$max tool calls');
}

/// `mustCallTools` were all called and no `mustNotCallTools` were.
EvalCheck checkExpectations(EvalScenario scenario, AgentRunOutput output) {
  final called = output.toolNames.toSet();
  final missing = scenario.expectations.mustCallTools.difference(called);
  final forbidden = scenario.expectations.mustNotCallTools.intersection(called);
  if (missing.isNotEmpty || forbidden.isNotEmpty) {
    final parts = <String>[
      if (missing.isNotEmpty) 'missing required: ${missing.join(', ')}',
      if (forbidden.isNotEmpty) 'called forbidden: ${forbidden.join(', ')}',
    ];
    return EvalCheck.fail('expected_tools', parts.join('; '));
  }
  return EvalCheck.pass('expected_tools');
}

// ---------------------------------------------------------------------------
// Task agent checks
// ---------------------------------------------------------------------------

/// The task agent must publish a report with a non-empty one-liner and TLDR.
EvalCheck checkReportPublished(AgentRunOutput output) {
  final report = output.report;
  if (report == null) {
    return EvalCheck.fail('report_published', 'no report published');
  }
  if (report.oneLiner.trim().isEmpty || report.tldr.trim().isEmpty) {
    return EvalCheck.fail(
      'report_published',
      'report missing one-liner or TLDR',
    );
  }
  return EvalCheck.pass('report_published');
}

/// `set_task_status` never sets a user-only status and only sets known values.
EvalCheck checkValidStatusTransitions(AgentRunOutput output) {
  for (final call in output.toolCalls) {
    if (call.name != TaskAgentToolNames.setTaskStatus) continue;
    final status = _argString(call, 'status');
    if (status == null) {
      return EvalCheck.fail('valid_status', 'set_task_status missing status');
    }
    if (kAgentForbiddenStatuses.contains(status)) {
      return EvalCheck.fail(
        'valid_status',
        'set_task_status to user-only "$status"',
      );
    }
    if (!kAgentSettableStatuses.contains(status)) {
      return EvalCheck.fail('valid_status', 'unknown status "$status"');
    }
  }
  return EvalCheck.pass('valid_status');
}

/// `update_task_estimate` minutes within 1..1440.
EvalCheck checkEstimateRange(AgentRunOutput output) {
  for (final call in output.toolCalls) {
    if (call.name != TaskAgentToolNames.updateTaskEstimate) continue;
    final minutes = _argInt(call, 'minutes');
    if (minutes == null) {
      return EvalCheck.fail(
        'estimate_range',
        'update_task_estimate missing minutes',
      );
    }
    if (minutes < _minEstimate || minutes > _maxEstimate) {
      return EvalCheck.fail(
        'estimate_range',
        'estimate $minutes out of $_minEstimate..$_maxEstimate',
      );
    }
  }
  return EvalCheck.pass('estimate_range');
}

/// No single `assign_task_labels` call assigns more than 3 labels.
EvalCheck checkLabelCap(AgentRunOutput output) {
  for (final call in output.toolCalls) {
    if (call.name != TaskAgentToolNames.assignTaskLabels) continue;
    final labels = _argList(call, 'labels');
    if (labels.length > _maxLabelsPerCall) {
      return EvalCheck.fail(
        'label_cap',
        'assigned ${labels.length} labels, max $_maxLabelsPerCall',
      );
    }
  }
  return EvalCheck.pass('label_cap');
}

/// Added checklist items don't duplicate each other or existing items.
EvalCheck checkNoDuplicateChecklistTitles(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final existing = <String>{
    for (final task in scenario.appState.tasks)
      for (final item in task.checklist) _norm(item.title),
  };
  final added = <String>[];
  for (final call in output.toolCalls) {
    if (call.name != TaskAgentToolNames.addMultipleChecklistItems) continue;
    for (final raw in _argList(call, 'items')) {
      final title = _checklistTitle(raw);
      if (title != null) added.add(_norm(title));
    }
  }
  final seen = <String>{};
  for (final title in added) {
    if (existing.contains(title) || !seen.add(title)) {
      return EvalCheck.fail(
        'no_duplicate_checklist',
        'duplicate checklist title "$title"',
      );
    }
  }
  return EvalCheck.pass('no_duplicate_checklist');
}

// ---------------------------------------------------------------------------
// Planning agent checks
// ---------------------------------------------------------------------------

/// Sum of planned block durations must not exceed the day's capacity.
EvalCheck checkWithinCapacity(EvalScenario scenario, AgentRunOutput output) {
  final scheduled = output.plannedBlocks.fold<int>(
    0,
    (sum, b) => sum + b.durationMinutes,
  );
  final capacity = scenario.appState.capacityMinutes;
  if (scheduled > capacity) {
    return EvalCheck.fail(
      'within_capacity',
      'scheduled $scheduled min > capacity $capacity min',
    );
  }
  return EvalCheck.pass('within_capacity', '$scheduled/$capacity min');
}

/// Planned blocks must not overlap in time.
EvalCheck checkNoOverlappingBlocks(AgentRunOutput output) {
  final sorted = [...output.plannedBlocks]
    ..sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    final curr = sorted[i];
    if (curr.start.isBefore(prev.end)) {
      return EvalCheck.fail(
        'no_overlapping_blocks',
        'block ${curr.id} starts before ${prev.id} ends',
      );
    }
  }
  return EvalCheck.pass('no_overlapping_blocks');
}

/// Every planned block uses a category known to the scenario.
EvalCheck checkBlocksUseKnownCategories(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final known = scenario.appState.categoryIds.toSet();
  if (known.isEmpty) {
    return EvalCheck.pass('known_categories', 'no category allowlist');
  }
  for (final block in output.plannedBlocks) {
    if (!known.contains(block.categoryId)) {
      return EvalCheck.fail(
        'known_categories',
        'block ${block.id} uses unknown category ${block.categoryId}',
      );
    }
  }
  return EvalCheck.pass('known_categories');
}

/// A non-empty capture on a drafting wake must yield a plan or parsed items.
EvalCheck checkProducedPlanForCapture(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  if (scenario.userInput.transcript.trim().isEmpty) {
    return EvalCheck.pass('produced_plan', 'no capture to act on');
  }
  final names = output.toolNames.toSet();
  final produced =
      output.plannedBlocks.isNotEmpty ||
      names.contains(DayAgentToolNames.draftDayPlan) ||
      names.contains(DayAgentToolNames.parseCaptureToItems) ||
      names.contains(DayAgentToolNames.proposePlanDiff);
  if (!produced) {
    return EvalCheck.fail(
      'produced_plan',
      'capture present but no plan, diff, or parsed items produced',
    );
  }
  return EvalCheck.pass('produced_plan');
}

// ---------------------------------------------------------------------------
// Suites
// ---------------------------------------------------------------------------

/// Run the full Level 1 suite for the scenario's agent kind.
List<EvalCheck> runLevel1(
  EvalScenario scenario,
  AgentRunOutput output, {
  EvalProfile? profile,
}) {
  final checks = <EvalCheck>[
    checkSucceeded(output),
    checkNoHallucinatedTaskRefs(scenario, output),
    checkTokenBudget(scenario, output, profile: profile),
    checkToolCallBudget(scenario, output),
    checkExpectations(scenario, output),
  ];
  switch (scenario.agentKind) {
    case AgentKind.taskAgent:
      checks
        ..add(checkReportPublished(output))
        ..add(checkValidStatusTransitions(output))
        ..add(checkEstimateRange(output))
        ..add(checkLabelCap(output))
        ..add(checkNoDuplicateChecklistTitles(scenario, output));
    case AgentKind.planningAgent:
      checks
        ..add(checkWithinCapacity(scenario, output))
        ..add(checkNoOverlappingBlocks(output))
        ..add(checkBlocksUseKnownCategories(scenario, output))
        ..add(checkProducedPlanForCapture(scenario, output));
  }
  return checks;
}

// ---------------------------------------------------------------------------
// Arg helpers (no dynamic dispatch — type-promote before use)
// ---------------------------------------------------------------------------

String? _argString(ToolCallRecord call, String key) {
  final value = call.args[key];
  return value is String ? value : null;
}

int? _argInt(ToolCallRecord call, String key) {
  final value = call.args[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

List<dynamic> _argList(ToolCallRecord call, String key) {
  final value = call.args[key];
  return value is List ? value : const [];
}

String? _checklistTitle(Object? item) {
  if (item is String) return item;
  if (item is Map<String, dynamic>) {
    final title = item['title'];
    if (title is String) return title;
  }
  return null;
}

String _norm(String s) => s.trim().toLowerCase();
