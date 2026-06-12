// Level 1 assertion library for the agent evaluation harness (ADR 0029).
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
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tools.dart';

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

const _taskAgentSingularizedProposalTools = <String>{
  TaskAgentToolNames.addChecklistItem,
  TaskAgentToolNames.updateChecklistItem,
  TaskAgentToolNames.assignTaskLabel,
  TaskAgentToolNames.migrateChecklistItem,
};

const _plannerDiffProposalTools = <String>{
  'move_block',
  'add_block',
  'drop_block',
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
  for (final item in output.parsedCaptureItems) {
    final id = item.matchedTaskId;
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

/// Scenario-authored raw tool-call argument expectations.
EvalCheck checkExpectedToolCalls(EvalScenario scenario, AgentRunOutput output) {
  final expected = scenario.expectations;
  if (expected.requiredToolCalls.isEmpty &&
      expected.forbiddenToolCalls.isEmpty) {
    return EvalCheck.pass(
      'expected_tool_calls',
      'no raw tool-call oracle set',
    );
  }

  final failures = <String>[];
  final required = expected.requiredToolCalls;
  if (!_hasDistinctMatcherGroups<ToolCallRecord, ExpectedToolCallState>(
    output.toolCalls,
    [
      for (final matcher in required) [matcher],
    ],
    _toolCallMatches,
  )) {
    failures.add(
      'missing distinct tool-call expectations: '
      '${_describeToolCallMatcherGroups(required)}',
    );
  }

  final forbiddenMatches = [
    for (final call in output.toolCalls)
      for (final matcher in expected.forbiddenToolCalls)
        if (_toolCallMatches(call, matcher))
          '${call.name} ${call.args} matched ${_describeToolCallMatcher(matcher)}',
  ];
  if (forbiddenMatches.isNotEmpty) {
    failures.add('forbidden tool call(s): ${forbiddenMatches.join('; ')}');
  }

  if (failures.isNotEmpty) {
    return EvalCheck.fail('expected_tool_calls', failures.join('; '));
  }
  return EvalCheck.pass('expected_tool_calls');
}

/// Every emitted tool name must be known to the scenario's agent kind.
EvalCheck checkKnownToolNames(EvalScenario scenario, AgentRunOutput output) {
  final known = _knownToolNamesFor(scenario.agentKind);
  final unknown = {
    for (final name in output.toolNames)
      if (!known.contains(name)) name,
  };
  if (unknown.isNotEmpty) {
    return EvalCheck.fail(
      'known_tools',
      'unknown ${scenario.agentKind.name} tool(s): ${unknown.join(', ')}',
    );
  }
  return EvalCheck.pass('known_tools');
}

/// Persisted proposal item names use a durable normalized namespace, which can
/// differ from raw model-facing tool names after batch tools are exploded.
EvalCheck checkKnownProposalToolNames(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final known = _knownProposalToolNamesFor(scenario.agentKind);
  final unknown = {
    for (final proposal in output.proposals)
      if (!known.contains(proposal.toolName)) proposal.toolName,
  };
  if (unknown.isNotEmpty) {
    return EvalCheck.fail(
      'known_proposal_tools',
      'unknown ${scenario.agentKind.name} proposal tool(s): '
          '${unknown.join(', ')}',
    );
  }
  return EvalCheck.pass('known_proposal_tools');
}

/// Tool calls that production rejected must remain visible to the eval.
EvalCheck checkToolResultsSucceeded(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final expected = scenario.expectations;
  final failures = [
    for (final result in output.toolResults)
      if (!result.success)
        '${result.name}: ${result.error ?? 'tool execution failed'}',
  ];
  final unexpectedFailures = [
    for (final result in output.toolResults)
      if (!result.success &&
          !expected.allowedFailedToolNames.contains(result.name))
        '${result.name}: ${result.error ?? 'tool execution failed'}',
  ];
  if (failures.length > expected.maxAllowedToolResultFailures) {
    return EvalCheck.fail(
      'tool_results_succeeded',
      'failed tool result count ${failures.length} > '
          '${expected.maxAllowedToolResultFailures}: ${failures.join('; ')}',
    );
  }
  if (unexpectedFailures.isNotEmpty) {
    return EvalCheck.fail(
      'tool_results_succeeded',
      unexpectedFailures.join('; '),
    );
  }
  if (failures.isNotEmpty) {
    return EvalCheck.pass(
      'tool_results_succeeded',
      'allowed recoverable failure(s): ${failures.join('; ')}',
    );
  }
  return EvalCheck.pass('tool_results_succeeded');
}

/// Scenario-specific durable-state oracle.
///
/// Generic checks catch unsafe shapes; this check lets a scenario define what
/// success means for its user goal while still allowing multiple valid outputs.
EvalCheck checkExpectedDurableState(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final expected = scenario.expectations.durableState;
  if (expected.isEmpty) {
    return EvalCheck.pass(
      'expected_durable_state',
      'no durable-state oracle set',
    );
  }

  final failures = <String>[];
  final proposalCount = expected.proposalCount;
  if (proposalCount != null && output.proposals.length != proposalCount) {
    failures.add(
      'proposal count ${output.proposals.length} != $proposalCount',
    );
  }
  final plannedBlockCount = expected.plannedBlockCount;
  if (plannedBlockCount != null &&
      output.plannedBlocks.length != plannedBlockCount) {
    failures.add(
      'planned block count ${output.plannedBlocks.length} '
      '!= $plannedBlockCount',
    );
  }
  final parsedCaptureItemCount = expected.parsedCaptureItemCount;
  if (parsedCaptureItemCount != null &&
      output.parsedCaptureItems.length != parsedCaptureItemCount) {
    failures.add(
      'parsed capture item count ${output.parsedCaptureItems.length} '
      '!= $parsedCaptureItemCount',
    );
  }
  final mutatedEntryCount = expected.mutatedEntryCount;
  if (mutatedEntryCount != null &&
      output.mutatedEntryIds.length != mutatedEntryCount) {
    failures.add(
      'mutated entry count ${output.mutatedEntryIds.length} '
      '!= $mutatedEntryCount',
    );
  }

  final reportText = _norm(
    [
      output.report?.oneLiner ?? '',
      output.report?.tldr ?? '',
      output.report?.content ?? '',
    ].join('\n'),
  );
  for (final needle in expected.reportContains) {
    if (!reportText.contains(_norm(needle))) {
      failures.add('report missing "$needle"');
    }
  }

  final observationText = _norm(output.observations.join('\n'));
  for (final needle in expected.observationContains) {
    if (!observationText.contains(_norm(needle))) {
      failures.add('observations missing "$needle"');
    }
  }

  final missingMutations = expected.requiredMutatedEntryIds.difference(
    output.mutatedEntryIds,
  );
  if (missingMutations.isNotEmpty) {
    failures.add('missing mutations: ${missingMutations.join(', ')}');
  }
  if (expected.allowedMutatedEntryIds.isNotEmpty) {
    final unexpectedMutations = output.mutatedEntryIds.difference(
      expected.allowedMutatedEntryIds,
    );
    if (unexpectedMutations.isNotEmpty) {
      failures.add('unexpected mutations: ${unexpectedMutations.join(', ')}');
    }
  }
  final forbiddenMutations = expected.forbiddenMutatedEntryIds.intersection(
    output.mutatedEntryIds,
  );
  if (forbiddenMutations.isNotEmpty) {
    failures.add('forbidden mutations: ${forbiddenMutations.join(', ')}');
  }

  if (!_hasDistinctMatcherGroups<ProposalRecord, ExpectedProposalState>(
    output.proposals,
    [
      for (final matcher in expected.requiredProposals) [matcher],
      for (final group in expected.requiredProposalAnyOf) group.anyOf,
    ],
    _proposalMatches,
  )) {
    failures.add(
      'missing distinct proposal expectations: '
      '${_describeProposalMatcherGroups(
        expected.requiredProposals,
        expected.requiredProposalAnyOf,
      )}',
    );
  }
  for (final count in expected.proposalCounts) {
    final actual = output.proposals
        .where((proposal) => _proposalMatches(proposal, count.matcher))
        .length;
    final failure = _countFailure(
      'proposal count for ${_describeProposalMatcher(count.matcher)}',
      actual: actual,
      min: count.minCount,
      max: count.maxCount,
      exact: count.exactCount,
    );
    if (failure != null) failures.add(failure);
  }
  for (final matcher in expected.forbiddenProposals) {
    final matched = output.proposals.where(
      (proposal) => _proposalMatches(proposal, matcher),
    );
    if (matched.isNotEmpty) {
      failures.add('forbidden proposal ${_describeProposalMatcher(matcher)}');
    }
  }

  if (!_hasDistinctMatcherGroups<PlannedBlockRecord, ExpectedPlannedBlockState>(
    output.plannedBlocks,
    [
      for (final matcher in expected.requiredPlannedBlocks) [matcher],
      for (final group in expected.requiredPlannedBlockAnyOf) group.anyOf,
    ],
    _blockMatches,
  )) {
    failures.add(
      'missing distinct planned-block expectations: '
      '${_describeBlockMatcherGroups(
        expected.requiredPlannedBlocks,
        expected.requiredPlannedBlockAnyOf,
      )}',
    );
  }
  for (final count in expected.plannedBlockCounts) {
    final actual = output.plannedBlocks
        .where((block) => _blockMatches(block, count.matcher))
        .length;
    final failure = _countFailure(
      'planned-block count for ${_describeBlockMatcher(count.matcher)}',
      actual: actual,
      min: count.minCount,
      max: count.maxCount,
      exact: count.exactCount,
    );
    if (failure != null) failures.add(failure);
  }
  for (final matcher in expected.forbiddenPlannedBlocks) {
    final matched = output.plannedBlocks.where(
      (block) => _blockMatches(block, matcher),
    );
    if (matched.isNotEmpty) {
      failures.add('forbidden planned block ${_describeBlockMatcher(matcher)}');
    }
  }

  if (!_hasDistinctMatcherGroups<
    ParsedCaptureItemRecord,
    ExpectedParsedCaptureState
  >(
    output.parsedCaptureItems,
    [
      for (final matcher in expected.requiredParsedCaptureItems) [matcher],
      for (final group in expected.requiredParsedCaptureAnyOf) group.anyOf,
    ],
    _parsedCaptureMatches,
  )) {
    failures.add(
      'missing distinct parsed-capture expectations: '
      '${_describeParsedCaptureMatcherGroups(
        expected.requiredParsedCaptureItems,
        expected.requiredParsedCaptureAnyOf,
      )}',
    );
  }
  for (final count in expected.parsedCaptureCounts) {
    final actual = output.parsedCaptureItems
        .where((item) => _parsedCaptureMatches(item, count.matcher))
        .length;
    final failure = _countFailure(
      'parsed-capture count for '
      '${_describeParsedCaptureMatcher(count.matcher)}',
      actual: actual,
      min: count.minCount,
      max: count.maxCount,
      exact: count.exactCount,
    );
    if (failure != null) failures.add(failure);
  }
  for (final matcher in expected.forbiddenParsedCaptureItems) {
    final matched = output.parsedCaptureItems.where(
      (item) => _parsedCaptureMatches(item, matcher),
    );
    if (matched.isNotEmpty) {
      failures.add(
        'forbidden parsed capture item '
        '${_describeParsedCaptureMatcher(matcher)}',
      );
    }
  }

  if (failures.isNotEmpty) {
    return EvalCheck.fail('expected_durable_state', failures.join('; '));
  }
  return EvalCheck.pass('expected_durable_state');
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

/// Persisted label-assignment proposals must be new, active, in-scope labels.
EvalCheck checkValidLabelProposals(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final labelsById = {
    for (final label in scenario.appState.labels) label.id: label,
  };
  final tasksById = {
    for (final task in scenario.appState.tasks) task.id: task,
  };
  for (final proposal in output.proposals) {
    if (proposal.status != 'pending') continue;
    if (proposal.toolName != 'assign_task_label') continue;

    final taskId = proposal.targetId;
    final task = tasksById[taskId];
    if (task == null) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label proposal ${proposal.changeSetId}:${proposal.itemIndex} '
            'targets unknown task $taskId',
      );
    }

    final labelId = proposal.args['id'];
    if (labelId is! String || labelId.trim().isEmpty) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label proposal ${proposal.changeSetId}:${proposal.itemIndex} '
            'has no label id',
      );
    }
    if (task.labelIds.contains(labelId)) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label $labelId is already assigned to task ${task.id}',
      );
    }
    if (task.aiSuppressedLabelIds.contains(labelId)) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label $labelId is suppressed for task ${task.id}',
      );
    }

    final label = labelsById[labelId];
    if (label == null) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label $labelId is not in scenario label definitions',
      );
    }
    if (label.deletedAt != null) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label $labelId is deleted',
      );
    }

    final applicable = label.applicableCategoryIds;
    final isGlobal = applicable == null || applicable.isEmpty;
    final inCategory =
        task.categoryId != null &&
        (applicable?.contains(task.categoryId) ?? false);
    if (!isGlobal && !inCategory) {
      return EvalCheck.fail(
        'valid_label_proposals',
        'label $labelId is not applicable to task category ${task.categoryId}',
      );
    }
  }
  return EvalCheck.pass('valid_label_proposals');
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

/// When a target can read the persisted plan, its capacity must match the
/// scenario's capacity instead of silently falling back to production defaults.
EvalCheck checkPlanCapacityMatchesScenario(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  final actual = output.plannedCapacityMinutes;
  if (actual == null) {
    return EvalCheck.pass('plan_capacity_matches', 'target did not record it');
  }
  final expected = scenario.appState.capacityMinutes;
  if (actual != expected) {
    return EvalCheck.fail(
      'plan_capacity_matches',
      'persisted capacity $actual min != scenario capacity $expected min',
    );
  }
  return EvalCheck.pass('plan_capacity_matches', '$actual min');
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
  final known = scenario.appState.allowedCategoryIds;
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
  if (_isCaptureOnlyPlannerWake(scenario)) {
    return EvalCheck.pass('produced_plan', 'capture-only parse wake');
  }
  final hasCaptureEvidence =
      scenario.userInput.transcript.trim().isNotEmpty ||
      scenario.appState.captures.any(
        (capture) => capture.transcript.trim().isNotEmpty,
      );
  if (!hasCaptureEvidence) {
    return EvalCheck.pass('produced_plan', 'no capture to act on');
  }
  if (output.plannedBlocks.isEmpty) {
    return EvalCheck.fail(
      'produced_plan',
      'capture present but no planned blocks were produced',
    );
  }
  return EvalCheck.pass('produced_plan');
}

/// Capture-submitted parse wakes must persist parsed capture items.
EvalCheck checkCaptureOnlyParsedItems(
  EvalScenario scenario,
  AgentRunOutput output,
) {
  if (!_isCaptureOnlyPlannerWake(scenario)) {
    return EvalCheck.pass('capture_parse_persisted', 'not capture-only');
  }
  final submittedCaptureIds = captureIdsFromTriggerTokens(
    scenario.userInput.triggerTokens,
  ).toSet();
  final parsedForSubmittedCapture = [
    for (final item in output.parsedCaptureItems)
      if (submittedCaptureIds.contains(item.captureId)) item,
  ];
  if (parsedForSubmittedCapture.isEmpty) {
    return EvalCheck.fail(
      'capture_parse_persisted',
      'capture-only wake persisted no parsed items for submitted captures '
          '${submittedCaptureIds.join(', ')}',
    );
  }
  return EvalCheck.pass(
    'capture_parse_persisted',
    '${parsedForSubmittedCapture.length} parsed item(s)',
  );
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
    checkExpectedToolCalls(scenario, output),
    checkKnownToolNames(scenario, output),
    checkKnownProposalToolNames(scenario, output),
    checkToolResultsSucceeded(scenario, output),
    checkExpectedDurableState(scenario, output),
  ];
  switch (scenario.agentKind) {
    case AgentKind.taskAgent:
      checks
        ..add(checkReportPublished(output))
        ..add(checkValidStatusTransitions(output))
        ..add(checkEstimateRange(output))
        ..add(checkLabelCap(output))
        ..add(checkValidLabelProposals(scenario, output))
        ..add(checkNoDuplicateChecklistTitles(scenario, output));
    case AgentKind.planningAgent:
      checks
        ..add(checkWithinCapacity(scenario, output))
        ..add(checkPlanCapacityMatchesScenario(scenario, output))
        ..add(checkNoOverlappingBlocks(output))
        ..add(checkBlocksUseKnownCategories(scenario, output))
        ..add(checkCaptureOnlyParsedItems(scenario, output))
        ..add(checkProducedPlanForCapture(scenario, output));
  }
  return checks;
}

/// Run Level 1 checks for one expected wake inside a cascade scenario.
///
/// The wake expectation is projected into a scenario-shaped view so the same
/// check implementations grade normal one-shot runs and cascade wakes.
List<EvalCheck> runCascadeWakeLevel1(
  EvalScenario scenario,
  AgentRunOutput output,
  ExpectedCascadeWakeState expectedWake, {
  EvalProfile? profile,
}) {
  final wakeScenario = EvalScenario(
    id: '${scenario.id}#wake-${expectedWake.wakeIndex}',
    title: '${scenario.title} wake ${expectedWake.wakeIndex}',
    agentKind: scenario.agentKind,
    appState: scenario.appState,
    userInput: scenario.userInput,
    metadata: scenario.metadata,
    expectations: expectedWake.toExpectations(),
  );
  return runLevel1(wakeScenario, output, profile: profile);
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

bool _hasDistinctMatcherGroups<T, M>(
  List<T> records,
  List<List<M>> matcherGroups,
  bool Function(T record, M matcher) matches,
) {
  if (matcherGroups.isEmpty) return true;
  if (matcherGroups.any((group) => group.isEmpty)) return false;
  if (records.length < matcherGroups.length) return false;
  final used = List<bool>.filled(records.length, false);

  bool search(int groupIndex) {
    if (groupIndex == matcherGroups.length) return true;
    final group = matcherGroups[groupIndex];
    for (var i = 0; i < records.length; i++) {
      if (used[i] || !group.any((matcher) => matches(records[i], matcher))) {
        continue;
      }
      used[i] = true;
      if (search(groupIndex + 1)) return true;
      used[i] = false;
    }
    return false;
  }

  return search(0);
}

String? _countFailure(
  String label, {
  required int actual,
  required int? min,
  required int? max,
  required int? exact,
}) {
  if (exact != null && actual != exact) {
    return '$label $actual != $exact';
  }
  if (min != null && actual < min) {
    return '$label $actual < $min';
  }
  if (max != null && actual > max) {
    return '$label $actual > $max';
  }
  return null;
}

bool _proposalMatches(
  ProposalRecord proposal,
  ExpectedProposalState matcher,
) {
  if (matcher.toolName != null && proposal.toolName != matcher.toolName) {
    return false;
  }
  if (matcher.targetId != null && proposal.targetId != matcher.targetId) {
    return false;
  }
  if (matcher.status != null && proposal.status != matcher.status) {
    return false;
  }
  if (matcher.changeSetStatus != null &&
      proposal.changeSetStatus != matcher.changeSetStatus) {
    return false;
  }
  for (final entry in matcher.argsContain.entries) {
    if (!proposal.args.containsKey(entry.key)) return false;
    if (!_jsonEquals(proposal.args[entry.key], entry.value)) return false;
  }
  final summary = _norm(proposal.humanSummary);
  for (final needle in matcher.humanSummaryContains) {
    if (!summary.contains(_norm(needle))) return false;
  }
  return true;
}

bool _toolCallMatches(
  ToolCallRecord call,
  ExpectedToolCallState matcher,
) {
  if (call.name != matcher.toolName) return false;
  for (final entry in matcher.argsContain.entries) {
    if (!call.args.containsKey(entry.key)) return false;
    if (!_jsonContains(call.args[entry.key], entry.value)) return false;
  }
  return true;
}

bool _blockMatches(
  PlannedBlockRecord block,
  ExpectedPlannedBlockState matcher,
) {
  if (matcher.id != null && block.id != matcher.id) return false;
  if (matcher.taskId != null && block.taskId != matcher.taskId) return false;
  if (matcher.categoryId != null && block.categoryId != matcher.categoryId) {
    return false;
  }
  final duration = block.durationMinutes;
  if (matcher.minDurationMinutes != null &&
      duration < matcher.minDurationMinutes!) {
    return false;
  }
  if (matcher.maxDurationMinutes != null &&
      duration > matcher.maxDurationMinutes!) {
    return false;
  }
  if (matcher.startAtOrAfter != null &&
      block.start.isBefore(matcher.startAtOrAfter!)) {
    return false;
  }
  if (matcher.endAtOrBefore != null &&
      block.end.isAfter(matcher.endAtOrBefore!)) {
    return false;
  }
  return true;
}

bool _parsedCaptureMatches(
  ParsedCaptureItemRecord item,
  ExpectedParsedCaptureState matcher,
) {
  if (matcher.id != null && item.id != matcher.id) return false;
  if (matcher.captureId != null && item.captureId != matcher.captureId) {
    return false;
  }
  if (matcher.kind != null && item.kind != matcher.kind) return false;
  if (matcher.titleContains != null &&
      !_norm(item.title).contains(_norm(matcher.titleContains!))) {
    return false;
  }
  if (matcher.categoryId != null && item.categoryId != matcher.categoryId) {
    return false;
  }
  if (matcher.matchedTaskId != null &&
      item.matchedTaskId != matcher.matchedTaskId) {
    return false;
  }
  if (matcher.confidence != null && item.confidence != matcher.confidence) {
    return false;
  }
  final score = item.confidenceScore;
  if (matcher.minConfidenceScore != null &&
      score < matcher.minConfidenceScore!) {
    return false;
  }
  if (matcher.maxConfidenceScore != null &&
      score > matcher.maxConfidenceScore!) {
    return false;
  }
  if (matcher.lowConfidence != null &&
      item.lowConfidence != matcher.lowConfidence) {
    return false;
  }
  return true;
}

bool _jsonEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is String || a is bool || a == null) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return false;
}

bool _jsonContains(Object? actual, Object? expected) {
  if (expected is Map) {
    if (actual is! Map) return false;
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) return false;
      if (!_jsonContains(actual[key], expected[key])) return false;
    }
    return true;
  }
  if (expected is List) {
    if (actual is! List || actual.length < expected.length) return false;
    final used = List<bool>.filled(actual.length, false);
    for (final expectedItem in expected) {
      var matched = false;
      for (var i = 0; i < actual.length; i++) {
        if (used[i] || !_jsonContains(actual[i], expectedItem)) continue;
        used[i] = true;
        matched = true;
        break;
      }
      if (!matched) return false;
    }
    return true;
  }
  return _jsonEquals(actual, expected);
}

String _describeToolCallMatcher(ExpectedToolCallState matcher) {
  final parts = <String>[
    'tool=${matcher.toolName}',
    if (matcher.argsContain.isNotEmpty) 'args~${matcher.argsContain}',
  ];
  return parts.join(',');
}

String _describeToolCallMatcherGroups(
  List<ExpectedToolCallState> required,
) {
  return _describeMatcherGroups<ExpectedToolCallState>(
    [
      for (final matcher in required) [matcher],
    ],
    _describeToolCallMatcher,
  );
}

String _describeProposalMatcher(ExpectedProposalState matcher) {
  final parts = <String>[
    if (matcher.toolName != null) 'tool=${matcher.toolName}',
    if (matcher.targetId != null) 'target=${matcher.targetId}',
    if (matcher.status != null) 'status=${matcher.status}',
    if (matcher.changeSetStatus != null) 'changeSet=${matcher.changeSetStatus}',
    if (matcher.argsContain.isNotEmpty) 'args=${matcher.argsContain}',
    if (matcher.humanSummaryContains.isNotEmpty)
      'summary~${matcher.humanSummaryContains.join('|')}',
  ];
  return parts.isEmpty ? '<any proposal>' : parts.join(',');
}

String _describeProposalMatcherGroups(
  List<ExpectedProposalState> required,
  List<ExpectedProposalStateAnyOf> anyOf,
) {
  return _describeMatcherGroups<ExpectedProposalState>(
    [
      for (final matcher in required) [matcher],
      for (final group in anyOf) group.anyOf,
    ],
    _describeProposalMatcher,
  );
}

String _describeBlockMatcher(ExpectedPlannedBlockState matcher) {
  final parts = <String>[
    if (matcher.id != null) 'id=${matcher.id}',
    if (matcher.taskId != null) 'task=${matcher.taskId}',
    if (matcher.categoryId != null) 'category=${matcher.categoryId}',
    if (matcher.minDurationMinutes != null) 'min=${matcher.minDurationMinutes}',
    if (matcher.maxDurationMinutes != null) 'max=${matcher.maxDurationMinutes}',
  ];
  return parts.isEmpty ? '<any block>' : parts.join(',');
}

String _describeBlockMatcherGroups(
  List<ExpectedPlannedBlockState> required,
  List<ExpectedPlannedBlockStateAnyOf> anyOf,
) {
  return _describeMatcherGroups<ExpectedPlannedBlockState>(
    [
      for (final matcher in required) [matcher],
      for (final group in anyOf) group.anyOf,
    ],
    _describeBlockMatcher,
  );
}

String _describeParsedCaptureMatcher(ExpectedParsedCaptureState matcher) {
  final parts = <String>[
    if (matcher.id != null) 'id=${matcher.id}',
    if (matcher.captureId != null) 'capture=${matcher.captureId}',
    if (matcher.kind != null) 'kind=${matcher.kind}',
    if (matcher.titleContains != null) 'title~${matcher.titleContains}',
    if (matcher.categoryId != null) 'category=${matcher.categoryId}',
    if (matcher.matchedTaskId != null) 'task=${matcher.matchedTaskId}',
    if (matcher.confidence != null) 'confidence=${matcher.confidence}',
    if (matcher.minConfidenceScore != null)
      'minConfidence=${matcher.minConfidenceScore}',
    if (matcher.maxConfidenceScore != null)
      'maxConfidence=${matcher.maxConfidenceScore}',
    if (matcher.lowConfidence != null) 'lowConfidence=${matcher.lowConfidence}',
  ];
  return parts.isEmpty ? '<any parsed item>' : parts.join(',');
}

String _describeParsedCaptureMatcherGroups(
  List<ExpectedParsedCaptureState> required,
  List<ExpectedParsedCaptureStateAnyOf> anyOf,
) {
  return _describeMatcherGroups<ExpectedParsedCaptureState>(
    [
      for (final matcher in required) [matcher],
      for (final group in anyOf) group.anyOf,
    ],
    _describeParsedCaptureMatcher,
  );
}

String _describeMatcherGroups<M>(
  List<List<M>> groups,
  String Function(M matcher) describe,
) {
  if (groups.isEmpty) return '<none>';
  return groups
      .map(
        (group) => group.length == 1
            ? describe(group.single)
            : 'anyOf(${group.map(describe).join(' OR ')})',
      )
      .join('; ');
}

bool _isCaptureOnlyPlannerWake(EvalScenario scenario) {
  final tokens = scenario.userInput.triggerTokens;
  final hasCapture = tokens.any(
    (token) => token.startsWith(dayAgentCaptureSubmittedPrefix),
  );
  final hasDrafting = tokens.any(
    (token) => token.startsWith(dayAgentDraftingPrefix),
  );
  final hasRefine = tokens.any(
    (token) => token.startsWith(dayAgentRefinePrefix),
  );
  return hasCapture && !hasDrafting && !hasRefine;
}

Set<String> _knownToolNamesFor(AgentKind agentKind) {
  return switch (agentKind) {
    AgentKind.taskAgent => {
      for (final tool in AgentToolRegistry.taskAgentTools) tool.name,
    },
    AgentKind.planningAgent => {
      for (final tool in dayAgentTools) tool.name,
    },
  };
}

Set<String> _knownProposalToolNamesFor(AgentKind agentKind) {
  return switch (agentKind) {
    AgentKind.taskAgent => {
      for (final tool in AgentToolRegistry.deferredTools)
        if (!AgentToolRegistry.explodedBatchTools.containsKey(tool)) tool,
      ..._taskAgentSingularizedProposalTools,
    },
    AgentKind.planningAgent => _plannerDiffProposalTools,
  };
}
