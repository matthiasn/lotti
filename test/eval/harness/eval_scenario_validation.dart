import 'eval_models.dart';
import 'eval_provenance.dart';

class EvalScenarioValidationIssue {
  const EvalScenarioValidationIssue({
    required this.scenarioId,
    required this.message,
  });

  final String scenarioId;
  final String message;

  @override
  String toString() => '$scenarioId: $message';
}

List<EvalScenarioValidationIssue> validateEvalScenarioCatalog(
  List<EvalScenario> scenarios,
) {
  final issues = <EvalScenarioValidationIssue>[];
  final ids = scenarios.map((scenario) => scenario.id).toList();
  for (final duplicate in _duplicates(ids)) {
    issues.add(
      EvalScenarioValidationIssue(
        scenarioId: duplicate,
        message: 'duplicate scenario id',
      ),
    );
  }
  for (final scenario in scenarios) {
    issues.addAll(validateEvalScenario(scenario));
  }
  return issues;
}

List<EvalScenarioValidationIssue> validateEvalScenario(EvalScenario scenario) {
  final issues = <EvalScenarioValidationIssue>[];

  void add(String message) {
    issues.add(
      EvalScenarioValidationIssue(
        scenarioId: scenario.id,
        message: message,
      ),
    );
  }

  if (scenario.id.trim().isEmpty) add('scenario id is empty');
  if (scenario.title.trim().isEmpty) add('scenario title is empty');
  if (scenario.userInput.triggerTokens.isEmpty) {
    add('scenario has no trigger tokens');
  }
  if (scenario.metadata.capabilityIds.isEmpty) {
    add('scenario has no capability ids');
  }
  for (final capabilityId in scenario.metadata.capabilityIds) {
    if (capabilityId.trim().isEmpty) {
      add('scenario has an empty capability id');
    }
  }
  if (scenario.metadata.isAdversarial &&
      scenario.metadata.source != EvalScenarioSource.adversarial &&
      !scenario.metadata.tags.contains('adversarial')) {
    add('adversarial scenario lacks adversarial source or tag');
  }
  if (scenario.metadata.isAdversarial &&
      scenario.metadata.tags
          .intersection(kDefaultAdversarialStressTags)
          .isEmpty) {
    add(
      'adversarial scenario lacks a default stress tag: '
      '${kDefaultAdversarialStressTags.join(', ')}',
    );
  }
  if (!scenario.metadata.isAdversarial &&
      scenario.metadata.source == EvalScenarioSource.adversarial) {
    add('scenario has adversarial source but isAdversarial is false');
  }
  if (!scenario.metadata.isAdversarial &&
      scenario.metadata.tags.contains('adversarial')) {
    add('scenario has adversarial tag but isAdversarial is false');
  }
  _validateScenarioReview(add, scenario);

  final state = scenario.appState;
  final taskIds = state.knownTaskIds;
  final captureIds = state.captures.map((capture) => capture.id).toSet();
  final parsedItemIdList = [
    for (final capture in state.captures)
      for (final item in capture.parsedItems) item.id,
  ];
  final parsedItemIds = parsedItemIdList.toSet();
  final proposalSetsById = {
    for (final set in state.proposalSets) set.id: set,
  };
  final categoryIds = {
    ...state.categoryIds,
    for (final category in state.categories) category.id,
  };
  final labelIds = state.labels.map((label) => label.id).toSet();

  _addDuplicateIssues(add, 'task id', state.tasks.map((task) => task.id));
  _addDuplicateIssues(
    add,
    'capture id',
    state.captures.map((capture) => capture.id),
  );
  _addDuplicateIssues(
    add,
    'parsed capture item id',
    parsedItemIdList,
  );
  _addDuplicateIssues(
    add,
    'proposal set id',
    state.proposalSets.map((set) => set.id),
  );
  _addDuplicateIssues(
    add,
    'category id',
    state.categories.map((category) => category.id),
  );
  _addDuplicateIssues(
    add,
    'label id',
    state.labels.map((label) => label.id),
  );

  for (final task in state.tasks) {
    final categoryId = task.categoryId;
    if (categoryId != null && !categoryIds.contains(categoryId)) {
      add('task ${task.id} references unknown category $categoryId');
    }
    for (final labelId in task.labelIds) {
      if (!labelIds.contains(labelId)) {
        add('task ${task.id} references unknown label $labelId');
      }
    }
    for (final labelId in task.aiSuppressedLabelIds) {
      if (!labelIds.contains(labelId)) {
        add('task ${task.id} suppresses unknown label $labelId');
      }
    }
  }

  for (final block in state.existingBlocks) {
    if (block.end.isBefore(block.start) ||
        block.end.isAtSameMomentAs(block.start)) {
      add('existing block ${block.id} has non-positive duration');
    }
    if (!categoryIds.contains(block.categoryId)) {
      add(
        'existing block ${block.id} references unknown category '
        '${block.categoryId}',
      );
    }
    final taskId = block.taskId;
    if (taskId != null && !taskIds.contains(taskId)) {
      add('existing block ${block.id} references unknown task $taskId');
    }
  }

  for (final capture in state.captures) {
    for (final item in capture.parsedItems) {
      if (!categoryIds.contains(item.categoryId)) {
        add(
          'parsed item ${item.id} references unknown category '
          '${item.categoryId}',
        );
      }
      final matchedTaskId = item.matchedTaskId;
      if (matchedTaskId != null && !taskIds.contains(matchedTaskId)) {
        add('parsed item ${item.id} references unknown task $matchedTaskId');
      }
      _validateConfidence(
        add,
        label: 'parsed item ${item.id}',
        confidence: item.confidence,
        score: item.confidenceScore,
      );
    }
  }

  for (final label in state.labels) {
    final applicable = label.applicableCategoryIds ?? const <String>[];
    for (final categoryId in applicable) {
      if (!categoryIds.contains(categoryId)) {
        add('label ${label.id} references unknown category $categoryId');
      }
    }
  }

  for (final set in state.proposalSets) {
    final targetId = set.targetId;
    if (targetId != null && !taskIds.contains(targetId)) {
      add('proposal set ${set.id} references unknown target $targetId');
    }
    if (set.items.isEmpty) {
      add('proposal set ${set.id} has no items');
    }
    for (final item in set.items) {
      if (item.toolName.trim().isEmpty) {
        add('proposal set ${set.id} has an item with empty toolName');
      }
      if (item.humanSummary.trim().isEmpty) {
        add('proposal set ${set.id} has an item with empty humanSummary');
      }
    }
  }

  for (final decision in state.proposalDecisions) {
    final set = proposalSetsById[decision.changeSetId];
    if (set == null) {
      add(
        'proposal decision ${decision.id} references unknown set '
        '${decision.changeSetId}',
      );
      continue;
    }
    if (decision.itemIndex < 0 || decision.itemIndex >= set.items.length) {
      add(
        'proposal decision ${decision.id} references missing item '
        '${decision.itemIndex} in ${decision.changeSetId}',
      );
      continue;
    }
    final item = set.items[decision.itemIndex];
    if (decision.toolName != item.toolName) {
      add(
        'proposal decision ${decision.id} tool ${decision.toolName} '
        'does not match proposal item tool ${item.toolName}',
      );
    }
    final targetId = decision.targetId;
    if (targetId != null && !taskIds.contains(targetId)) {
      add(
        'proposal decision ${decision.id} references unknown target '
        '$targetId',
      );
    }
  }

  for (final token in scenario.userInput.triggerTokens) {
    if (token.trim().isEmpty) {
      add('trigger token is empty');
    } else if (token.startsWith('decided_task:')) {
      final taskId = token.substring('decided_task:'.length);
      if (!taskIds.contains(taskId)) {
        add('trigger token references unknown task $taskId');
      }
    } else if (token.startsWith('capture_submitted:')) {
      final captureId = token.substring('capture_submitted:'.length);
      if (!captureIds.contains(captureId)) {
        add('trigger token references unknown capture $captureId');
      }
    } else if (token.startsWith('decided_capture_item:')) {
      final itemId = token.substring('decided_capture_item:'.length);
      if (!parsedItemIds.contains(itemId)) {
        add('trigger token references unknown parsed capture item $itemId');
      }
    }
  }

  _validateExpectations(add, scenario.expectations);
  _validateDurableStateExpectations(
    add,
    scenario.expectations.durableState,
    taskIds: taskIds,
    captureIds: captureIds,
    categoryIds: categoryIds,
  );

  return issues;
}

void _validateScenarioReview(
  void Function(String message) add,
  EvalScenario scenario,
) {
  final review = scenario.metadata.review;
  if (review == null) return;
  if (review.reviewer.trim().isEmpty) {
    add('scenario review reviewer is empty');
  }
  if (review.rationale.trim().isEmpty) {
    add('scenario review rationale is empty');
  }
  if (review.reviewedAt.trim().isEmpty) {
    add('scenario review reviewedAt is invalid');
  } else {
    try {
      DateTime.parse(review.reviewedAt);
    } on FormatException {
      add('scenario review reviewedAt is invalid');
    }
  }
  if (!EvalProvenance.isDigest(review.subjectDigest)) {
    add('scenario review subjectDigest is not a sha256 digest');
  } else {
    final expected = EvalProvenance.scenarioReviewSubjectDigest(scenario);
    if (review.subjectDigest != expected) {
      add(
        'scenario review subjectDigest is ${review.subjectDigest}, '
        'expected $expected',
      );
    }
  }
  final sourceDigest = review.sourceDigest;
  if (sourceDigest != null && !EvalProvenance.isDigest(sourceDigest)) {
    add('scenario review sourceDigest is not a sha256 digest');
  }
}

void _validateExpectations(
  void Function(String message) add,
  EvalExpectations expectations,
) {
  final maxAllowed = expectations.maxAllowedToolResultFailures;
  if (maxAllowed < 0) {
    add('maxAllowedToolResultFailures is negative');
  }
  if (maxAllowed > 0 && expectations.allowedFailedToolNames.isEmpty) {
    add(
      'maxAllowedToolResultFailures requires allowedFailedToolNames',
    );
  }
  if (maxAllowed == 0 && expectations.allowedFailedToolNames.isNotEmpty) {
    add(
      'allowedFailedToolNames requires maxAllowedToolResultFailures > 0',
    );
  }
  for (final toolName in expectations.allowedFailedToolNames) {
    if (toolName.trim().isEmpty) {
      add('allowedFailedToolNames contains an empty tool name');
    }
  }
}

void _validateDurableStateExpectations(
  void Function(String message) add,
  ExpectedDurableState expected, {
  required Set<String> taskIds,
  required Set<String> captureIds,
  required Set<String> categoryIds,
}) {
  for (final entry in {
    'proposalCount': expected.proposalCount,
    'plannedBlockCount': expected.plannedBlockCount,
    'parsedCaptureItemCount': expected.parsedCaptureItemCount,
    'mutatedEntryCount': expected.mutatedEntryCount,
  }.entries) {
    final count = entry.value;
    if (count != null && count < 0) {
      add('durableState.${entry.key} is negative');
    }
  }

  for (final matcher in expected.requiredProposals) {
    _validateProposalMatcher(add, 'requiredProposals', matcher, taskIds);
  }
  for (final group in expected.requiredProposalAnyOf) {
    if (group.anyOf.isEmpty) {
      add('durableState.requiredProposalAnyOf has an empty anyOf group');
    }
    for (final matcher in group.anyOf) {
      _validateProposalMatcher(add, 'requiredProposalAnyOf', matcher, taskIds);
    }
  }
  for (final count in expected.proposalCounts) {
    _validateCount(
      add,
      'durableState.proposalCounts',
      minCount: count.minCount,
      maxCount: count.maxCount,
      exactCount: count.exactCount,
    );
    _validateProposalMatcher(
      add,
      'proposalCounts.matcher',
      count.matcher,
      taskIds,
    );
    if (count.matcher.status == null && count.matcher.changeSetStatus == null) {
      add(
        'durableState.proposalCounts matcher must specify status or '
        'changeSetStatus',
      );
    }
  }
  for (final matcher in expected.forbiddenProposals) {
    _validateProposalMatcher(add, 'forbiddenProposals', matcher, taskIds);
  }

  for (final matcher in expected.requiredPlannedBlocks) {
    _validateBlockMatcher(
      add,
      'requiredPlannedBlocks',
      matcher,
      taskIds,
      categoryIds,
    );
  }
  for (final group in expected.requiredPlannedBlockAnyOf) {
    if (group.anyOf.isEmpty) {
      add('durableState.requiredPlannedBlockAnyOf has an empty anyOf group');
    }
    for (final matcher in group.anyOf) {
      _validateBlockMatcher(
        add,
        'requiredPlannedBlockAnyOf',
        matcher,
        taskIds,
        categoryIds,
      );
    }
  }
  for (final count in expected.plannedBlockCounts) {
    _validateCount(
      add,
      'durableState.plannedBlockCounts',
      minCount: count.minCount,
      maxCount: count.maxCount,
      exactCount: count.exactCount,
    );
    _validateBlockMatcher(
      add,
      'plannedBlockCounts.matcher',
      count.matcher,
      taskIds,
      categoryIds,
    );
  }
  for (final matcher in expected.forbiddenPlannedBlocks) {
    _validateBlockMatcher(
      add,
      'forbiddenPlannedBlocks',
      matcher,
      taskIds,
      categoryIds,
    );
  }

  for (final matcher in expected.requiredParsedCaptureItems) {
    _validateParsedCaptureMatcher(
      add,
      'requiredParsedCaptureItems',
      matcher,
      taskIds,
      captureIds,
      categoryIds,
    );
  }
  for (final group in expected.requiredParsedCaptureAnyOf) {
    if (group.anyOf.isEmpty) {
      add('durableState.requiredParsedCaptureAnyOf has an empty anyOf group');
    }
    for (final matcher in group.anyOf) {
      _validateParsedCaptureMatcher(
        add,
        'requiredParsedCaptureAnyOf',
        matcher,
        taskIds,
        captureIds,
        categoryIds,
      );
    }
  }
  for (final count in expected.parsedCaptureCounts) {
    _validateCount(
      add,
      'durableState.parsedCaptureCounts',
      minCount: count.minCount,
      maxCount: count.maxCount,
      exactCount: count.exactCount,
    );
    _validateParsedCaptureMatcher(
      add,
      'parsedCaptureCounts.matcher',
      count.matcher,
      taskIds,
      captureIds,
      categoryIds,
    );
  }
  for (final matcher in expected.forbiddenParsedCaptureItems) {
    _validateParsedCaptureMatcher(
      add,
      'forbiddenParsedCaptureItems',
      matcher,
      taskIds,
      captureIds,
      categoryIds,
    );
  }
}

void _validateCount(
  void Function(String message) add,
  String field, {
  required int? minCount,
  required int? maxCount,
  required int? exactCount,
}) {
  if (exactCount != null && (minCount != null || maxCount != null)) {
    add('$field cannot combine exactCount with minCount or maxCount');
  }
  for (final entry in {
    'minCount': minCount,
    'maxCount': maxCount,
    'exactCount': exactCount,
  }.entries) {
    final count = entry.value;
    if (count != null && count < 0) {
      add('$field has negative ${entry.key}');
    }
  }
  if (minCount != null && maxCount != null && minCount > maxCount) {
    add('$field has minCount > maxCount');
  }
  if (minCount == null && maxCount == null && exactCount == null) {
    add('$field must specify minCount, maxCount, or exactCount');
  }
}

void _validateProposalMatcher(
  void Function(String message) add,
  String field,
  ExpectedProposalState matcher,
  Set<String> taskIds,
) {
  final targetId = matcher.targetId;
  if (targetId != null && !taskIds.contains(targetId)) {
    add('durableState.$field references unknown target $targetId');
  }
}

void _validateBlockMatcher(
  void Function(String message) add,
  String field,
  ExpectedPlannedBlockState matcher,
  Set<String> taskIds,
  Set<String> categoryIds,
) {
  final taskId = matcher.taskId;
  if (taskId != null && !taskIds.contains(taskId)) {
    add('durableState.$field references unknown task $taskId');
  }
  final categoryId = matcher.categoryId;
  if (categoryId != null && !categoryIds.contains(categoryId)) {
    add('durableState.$field references unknown category $categoryId');
  }
  final min = matcher.minDurationMinutes;
  final max = matcher.maxDurationMinutes;
  if (min != null && min < 0) {
    add('durableState.$field has negative minDurationMinutes');
  }
  if (max != null && max < 0) {
    add('durableState.$field has negative maxDurationMinutes');
  }
  if (min != null && max != null && min > max) {
    add('durableState.$field has minDurationMinutes > maxDurationMinutes');
  }
  final startAtOrAfter = matcher.startAtOrAfter;
  final endAtOrBefore = matcher.endAtOrBefore;
  if (startAtOrAfter != null &&
      endAtOrBefore != null &&
      startAtOrAfter.isAfter(endAtOrBefore)) {
    add('durableState.$field has startAtOrAfter after endAtOrBefore');
  }
}

void _validateParsedCaptureMatcher(
  void Function(String message) add,
  String field,
  ExpectedParsedCaptureState matcher,
  Set<String> taskIds,
  Set<String> captureIds,
  Set<String> categoryIds,
) {
  final captureId = matcher.captureId;
  if (captureId != null && !captureIds.contains(captureId)) {
    add('durableState.$field references unknown capture $captureId');
  }
  final categoryId = matcher.categoryId;
  if (categoryId != null && !categoryIds.contains(categoryId)) {
    add('durableState.$field references unknown category $categoryId');
  }
  final matchedTaskId = matcher.matchedTaskId;
  if (matchedTaskId != null && !taskIds.contains(matchedTaskId)) {
    add('durableState.$field references unknown task $matchedTaskId');
  }
  _validateConfidence(
    add,
    label: 'durableState.$field',
    confidence: matcher.confidence,
    minScore: matcher.minConfidenceScore,
    maxScore: matcher.maxConfidenceScore,
  );
}

void _validateConfidence(
  void Function(String message) add, {
  required String label,
  String? confidence,
  double? score,
  double? minScore,
  double? maxScore,
}) {
  const allowed = {'low', 'medium', 'high'};
  if (confidence != null && !allowed.contains(confidence)) {
    add('$label has unknown confidence $confidence');
  }
  if (score != null && (score < 0 || score > 1)) {
    add('$label has confidenceScore outside 0..1');
  }
  if (minScore != null && (minScore < 0 || minScore > 1)) {
    add('$label has minConfidenceScore outside 0..1');
  }
  if (maxScore != null && (maxScore < 0 || maxScore > 1)) {
    add('$label has maxConfidenceScore outside 0..1');
  }
  if (minScore != null && maxScore != null && minScore > maxScore) {
    add('$label has minConfidenceScore > maxConfidenceScore');
  }
}

void _addDuplicateIssues(
  void Function(String message) add,
  String label,
  Iterable<String> values,
) {
  for (final duplicate in _duplicates(values)) {
    add('duplicate $label $duplicate');
  }
}

Set<String> _duplicates(Iterable<String> values) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (!seen.add(value)) duplicates.add(value);
  }
  return duplicates;
}
