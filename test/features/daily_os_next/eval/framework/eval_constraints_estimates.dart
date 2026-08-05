part of 'eval_constraints.dart';

/// A block for an estimated task must reflect that estimate.
///
/// The cheapest way to make an impossible day look feasible is to shrink the
/// work: four multi-hour tasks become four short blocks, capacity is
/// satisfied, and nothing surfaces the conflict the scenario was built to
/// provoke. Allows generous slack — the point is catching compression, not
/// policing estimation.
EvalConstraintResult scoreRespectsEstimates(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.respectsEstimates;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  // Summed per task, not per block: splitting a 180-minute task into 60 + 120
  // is a legitimate shape, and comparing each block against the whole estimate
  // would fail the first half of a correctly scheduled task.
  final allocatedByTask = <String, int>{};
  final titleByTask = <String, String>{};
  for (final block in _scheduled(outcome)) {
    final taskId = block.taskId;
    if (taskId == null) continue;
    allocatedByTask.update(
      taskId,
      (minutes) =>
          minutes + block.endTime.difference(block.startTime).inMinutes,
      ifAbsent: () => block.endTime.difference(block.startTime).inMinutes,
    );
    titleByTask.putIfAbsent(taskId, () => block.title ?? taskId);
  }
  // On a day that cannot hold the work, truncation is not compression — it is
  // the only honest plan, and the prompt explicitly asks for it ("place a task
  // for less than its estimate and say so"). Judging allocation against a full
  // estimate there fails a model for obeying, which is what it did: every
  // `lateStart` sample placed "Finish the database migration (partial — 60 of
  // 180 min)" and was marked down for the label it was told to write.
  //
  // The premise of this constraint is a day with room. `surfacedConflict`
  // carries the other half — whether the model *said* the day does not fit —
  // so nothing is lost by standing down here.
  final placedEstimate = allocatedByTask.keys.fold<int>(
    0,
    (sum, taskId) =>
        sum + (outcome.inputs.taskById(taskId)?.estimateMinutes ?? 0),
  );
  if (placedEstimate > outcome.inputs.plannableMinutes) {
    // Standing down entirely was wrong: it let a plan of one-minute tokens
    // score as clean as an honest partial one, since nothing else on an
    // impossible day objects to under-filling. So the question changes rather
    // than disappearing — not "did each task get its estimate", which is
    // impossible here, but "did the plan use the time it had".
    final allocated = allocatedByTask.values.fold<int>(0, (a, b) => a + b);
    final plannable = outcome.inputs.plannableMinutes;
    if (allocated * 2 < plannable) {
      return EvalConstraintResult(
        id: id,
        passed: false,
        detail:
            'the day cannot hold this work, but the plan only fills '
            '${allocated}min of $plannable plannable — shortening every '
            'task to a token is not a partial placement',
      );
    }
    // The aggregate is not enough on its own: one long task can supply the
    // fill while the work the scenario actually requires is reduced to
    // one-minute tokens, and nothing else objects — `requiredWorkPlaced` only
    // checks that the id appears. So required work keeps a per-task floor. It
    // is deliberately generous, since a genuinely partial placement is the
    // point here; it only catches a token.
    final tokenised = <String>[];
    for (final taskId in outcome.inputs.requiredTaskIds) {
      final minutes = allocatedByTask[taskId];
      if (minutes == null) continue;
      final estimate = outcome.inputs.taskById(taskId)?.estimateMinutes;
      if (estimate == null || estimate <= 0) continue;
      if (minutes * 10 < estimate) {
        tokenised.add(
          '"${titleByTask[taskId]}" got ${minutes}min of a ${estimate}min '
          'estimate',
        );
      }
    }
    if (tokenised.isNotEmpty) {
      return EvalConstraintResult(
        id: id,
        passed: false,
        detail:
            'the day cannot hold this work, but required work was reduced to '
            'a token: ${tokenised.join('; ')}',
      );
    }
    return EvalConstraintResult(
      id: id,
      passed: true,
      detail:
          'the day cannot hold this work ($placedEstimate min of estimates '
          'against $plannable plannable), and the plan fills ${allocated}min '
          'of it — a partial placement rather than a compressed one',
    );
  }
  final compressed = <String>[];
  var checked = 0;
  for (final entry in allocatedByTask.entries) {
    final estimate = outcome.inputs.taskById(entry.key)?.estimateMinutes;
    if (estimate == null || estimate <= 0) continue;
    checked++;
    if (entry.value * 2 < estimate) {
      compressed.add(
        '"${titleByTask[entry.key]}" allocated ${entry.value}min '
        'across its blocks against a ${estimate}min estimate',
      );
    }
  }
  if (checked == 0) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no placed task carries an estimate',
    );
  }
  return EvalConstraintResult(
    id: id,
    passed: compressed.isEmpty,
    detail: compressed.isEmpty
        ? '$checked estimated task(s) placed at a plausible length'
        : compressed.join('; '),
  );
}

/// Placed work must fit the day at its *estimated* length, except for an
/// explicitly auditable partial placement.
///
/// The per-task [scoreRespectsEstimates] check cannot catch a coordinated
/// shrink: 240/180/120/180-minute tasks written as 160/120/80/120 all clear a
/// per-task ratio while summing to exactly the 480-minute capacity. Summing
/// estimates instead makes the arithmetic honest — 720 minutes of work does
/// not fit in 480 however the blocks are labelled. A shortened task is charged
/// at its represented minutes only when its reason gives concrete minute
/// arithmetic that agrees with both the block duration and corpus estimate.
/// Notes remain audit evidence and can veto a reason with contradictory
/// arithmetic, but cannot earn partial credit; vague or contradictory partial
/// prose keeps the full-estimate charge.
EvalConstraintResult scoreWithinCapacityByEstimate(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.withinCapacityByEstimate;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final placements = _estimatedTaskPlacements(outcome);
  if (placements.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no placed task carries an estimate',
    );
  }
  final scheduledMinutes = _scheduled(outcome).fold(
    0,
    (total, block) => total + block.duration.inMinutes,
  );
  var fullEstimateMinutes = scheduledMinutes;
  var chargedMinutes = scheduledMinutes;
  final partials = <String>[];
  final undisclosedShortenings = <String>[];
  for (final entry in placements.entries) {
    final taskId = entry.key;
    final allocated = entry.value.allocatedMinutes;
    final estimate = entry.value.estimateMinutes;
    final estimateShortfall = estimate > allocated ? estimate - allocated : 0;
    fullEstimateMinutes += estimateShortfall;
    if (_isAuditedPartial(entry.value)) {
      partials.add(
        '$taskId ${allocated}min partial of ${estimate}min '
        '(${estimate - allocated}min remain)',
      );
    } else {
      chargedMinutes += estimateShortfall;
      if (allocated > 0 && allocated < estimate) {
        undisclosedShortenings.add(
          '$taskId allocated ${allocated}min of ${estimate}min',
        );
      }
    }
  }
  final capacity = outcome.inputs.plannableMinutes;
  final evidence = [
    if (partials.isNotEmpty) 'audited partials: ${partials.join(', ')}',
    if (undisclosedShortenings.isNotEmpty)
      'charged at full estimate without a matching concrete partial disclosure: ${undisclosedShortenings.join(', ')}',
  ];
  return EvalConstraintResult(
    id: id,
    passed: chargedMinutes <= capacity,
    heuristic: chargedMinutes <= capacity && fullEstimateMinutes > capacity,
    detail:
        '${placements.length} placed task(s) charged at ${chargedMinutes}min against '
        '${capacity}min capacity'
        '${chargedMinutes > capacity ? ' (over by ${chargedMinutes - capacity})' : ''}'
        '${evidence.isEmpty ? '' : '; ${evidence.join('; ')}'}',
  );
}

final _partialOfEstimatePattern = RegExp(
  r'(?<![\d.,+−-])\b(\d+)(?:\s*(?:m|mins?|minutes?))?\s+'
  r'(?:out\s+)?of\s+'
  r'(?:(?:an?|the)\s+)?(?:estimated\s+)?'
  r'(\d+)(?:\s+estimated)?\s*[-–—]?\s*(?:m|mins?|minutes?)\b',
  caseSensitive: false,
);

final _partialRemainingPattern = RegExp(
  r'(?<![\d.,+−-])\b(\d+)\s*'
  r'(?:(?:more|additional)\s+)?(?:m|mins?|minutes?)\s+'
  r'(?:(?:of|for)\s+(?:this|the)\s+(?:task|work)\s+)?'
  r'(?:(?:still|yet)\s+)?'
  r'(?:(?:is|are|will(?:\s+be)?)\s+)?'
  r'(?:(?:still|yet)\s+)?(?:left|remain(?:s|ing)?)\b',
  caseSensitive: false,
);

final _partialLeadingRemainingPattern = RegExp(
  r'\b(?:remaining(?:\s+(?:task|work))?|remainder)\s*:?\s*'
  r'(?:(?:is|are)\s+)?'
  r'(\d+)\s*(?:(?:more|additional)\s+)?(?:m|mins?|minutes?)\b',
  caseSensitive: false,
);

final _partialMentionPattern = RegExp(
  r'\b(?:partial(?:ly)?|partly)\b',
  caseSensitive: false,
);

final _negationWordPattern = RegExp(
  r'\b(?:not|no|never|neither|nor|cannot|'
  '(?:isn|wasn|weren|aren|doesn|don|didn|can|couldn|'
  r'won|wouldn|shouldn|hasn|haven|hadn)[\x27’]?t)\b',
  caseSensitive: false,
);

final _outerFalsehoodPattern = RegExp(
  r'\b(?:not\s+(?:actually\s+)?true|false)\s+that\b',
  caseSensitive: false,
);

final _longNegatedComplementPattern = RegExp(
  r'^\s*(?:(?:actually|really)\s+)?'
  r'(?:get|gets|got|getting)\s+around\s+to\s*$',
  caseSensitive: false,
);

final _avoidanceComplementPattern = RegExp(
  r'\b(?:avoid(?:s|ed|ing)?(?:\s+(?:being|getting))?|'
  'prevent(?:s|ed|ing)?|'
  r'(?:(?:is|are|was|were|be|been|being)\s+)?'
  r'prevent(?:s|ed|ing)?(?:\s+[\w-]+){0,2}\s+from'
  r'(?:\s+(?:being|getting))?)\s*$',
  caseSensitive: false,
);

final _wordPattern = RegExp(r'\b\w+\b');

const _partialTradeDispositionSource =
    r'for\s+(?:later|tomorrow|another\s+day|a\s+(?:later|future)\s+day)|'
    r'(?:roll(?:s|ed|ing)?|move(?:s|d|ing)?|carr(?:y|ies|ied|ying))\s+'
    r'(?:over|to\s+(?:later|tomorrow|another\s+day|'
    r'a\s+(?:later|future)\s+day))\b|'
    r'defer(?:s|red|ring)?\b|postpon(?:e|es|ed|ing)\b|unscheduled\b';

final _partialTradeDispositionPattern = RegExp(
  r'\b(?:'
  '$_partialTradeDispositionSource'
  r')\b',
  caseSensitive: false,
);

final _partialRemainderDispositionPattern = RegExp(
  r'\b(?:(?:'
  '$_partialTradeDispositionSource'
  r')\b|'
  r'(?:of|for|in)\s+(?:this|the)\s+(?:task|work)\b)',
  caseSensitive: false,
);

const _placementActionSource =
    'schedul(?:e|es|ed|ing)|'
    'allocat(?:e|es|ed|ing)|'
    'complet(?:e|es|ed|ing)|'
    'plan(?:s|ned|ning)?|'
    'plac(?:e|es|ed|ing)';

final _taskAllocationActionPattern = RegExp(
  r'\b(?:'
  '$_placementActionSource|'
  r'fit(?:s|ting)?)\b',
  caseSensitive: false,
);

final _fullAllocationPattern = RegExp(
  r'\b(?:(?:fully|entirely|completely)\s+'
  '(?:$_placementActionSource)|'
  '(?:$_placementActionSource)\\s+'
  r'in\s+full)\b',
  caseSensitive: false,
);

final _omittedAllocationPattern = RegExp(
  r'\b(?:omit(?:s|ted|ting)?|drop(?:s|ped|ping)?|'
  r'defer(?:s|red|ring)?|unscheduled|left\s+out)\b',
  caseSensitive: false,
);

final _unrelatedRemainderScopePattern = RegExp(
  r'\b(?:in|during|for|before|until)\s+'
  r'(?:(?:the|a|an|my|our|their|your)\s+)?'
  r'(?:meeting|workday|calendar|appointment|break)\b',
  caseSensitive: false,
);

final _historicalAllocationScopePattern = RegExp(
  r'^\s*(?:yesterday|previously|earlier(?:\s+today)?|last\s+'
  '(?:week|month|year|(?:mon|tues|wednes|thurs|fri|satur|sun)day))'
  r'\s*(?=$|because\b|due\s+to\b|owing\s+to\b)',
  caseSensitive: false,
);

final _leadingHistoricalAllocationScopePattern = RegExp(
  r'(?:^|[.;!?\n])\s*'
  r'(?:yesterday|previously|earlier(?:\s+today)?|last\s+'
  '(?:week|month|year|(?:mon|tues|wednes|thurs|fri|satur|sun)day))'
  r'\s*,\s*$',
  caseSensitive: false,
);

final _futureAllocationScopePattern = RegExp(
  r'^\s*(?:next\s+(?:week|month|year)|'
  r'in\s+\d+\s+(?:days?|weeks?|months?|years?))'
  r'\s*(?=$|because\b|due\s+to\b|owing\s+to\b)',
  caseSensitive: false,
);

final _leadingFutureAllocationScopePattern = RegExp(
  r'(?:^|[.;!?\n])\s*'
  r'(?:next\s+(?:week|month|year)|'
  r'in\s+\d+\s+(?:days?|weeks?|months?|years?))'
  r'\s*,\s*$',
  caseSensitive: false,
);

final _tomorrowAllocationScopePattern = RegExp(
  r'^\s*tomorrow\s*(?=$|because\b|due\s+to\b|owing\s+to\b)',
  caseSensitive: false,
);

final _leadingTomorrowAllocationScopePattern = RegExp(
  r'(?:^|[.;!?\n])\s*tomorrow\s*,\s*$',
  caseSensitive: false,
);

final _tradeSubjectPrefixPattern = RegExp(
  r'^(.*?)\s+(?:(?:(?:is|are|was|were)(?:\s+being)?|'
  r'(?:has|have|had)\s+been(?:\s+being)?|will\s+be(?:\s+being)?)'
  r'(?:\s+(?:not|only|merely|just|still))?'
  '(?:\\s+(?:$_placementActionSource))?|'
  '(?:has|have|had|leave(?:s|d|ing)?|left)|'
  '(?:$_placementActionSource))\\s*\$',
  caseSensitive: false,
);

final _conflictTradePattern = RegExp(
  r'\b(?:omit(?:s|ted|ting)?|drop(?:s|ped|ping)?|'
  r'left\s+(?:(?:(?:some|the|this|that|its|our|my|your|their|remaining)\s+)*'
  r'(?:task|work|remainder|rest|portion|part)\s+)?'
  '(?:out|unfinished|incomplete|unscheduled)|'
  r'(?:(?:(?:is|are|was|were|be|been|being)\s+)?not|'
  r'(?:can|could|will|shall)\s+not(?:\s+be)?|'
  r'(?:cannot|can[\x27’]?t|couldn[\x27’]?t|won[\x27’]?t)'
  r'(?:\s+be)?|'
  r'(?:(?:is|are|was|were)\s+unable\s+to|'
  r'(?:isn|aren|wasn|weren)[\x27’]?t\s+able\s+to)'
  r'(?:\s+be)?)\s+'
  'schedul(?:e|ed|ing)|'
  r'(?:has|have|had)\s+(?:(?:a|the)\s+)?scheduling\s+conflict|'
  r'conflict(?:s|ed|ing)(?![-\s]+free\b)|'
  'shorten(?:s|ed|ing)?|'
  r'(?:(?:cannot|can[\x27’]?t|couldn[\x27’]?t|won[\x27’]?t)|'
  r'(?:do|does|did|will|shall)\s+not|'
  r'(?:don|doesn|didn)[\x27’]?t)\s+fit)\b',
  caseSensitive: false,
);

typedef _PlacementDisclosure = ({bool canQualify, String prose});

typedef _EstimatedTaskPlacement = ({
  List<EvalCorpusTask> corpus,
  int allocatedMinutes,
  List<_PlacementDisclosure> disclosures,
  int estimateMinutes,
  bool hasOverlappingBlocks,
  DateTime? now,
  String taskId,
  String taskTitle,
});

/// Estimated scheduled work grouped by task, with all disclosure prose.
///
/// Both capacity accounting and conflict surfacing use this view so a partial
/// cannot be credited by one constraint while its deferred remainder is
/// invisible to the other.
Map<String, _EstimatedTaskPlacement> _estimatedTaskPlacements(
  EvalRunOutcome outcome,
) {
  final allocatedByTask = <String, int>{};
  final blocksByTask = <String, List<PlannedBlock>>{};
  final disclosuresByTask = <String, List<_PlacementDisclosure>>{};

  void addDisclosure(
    String taskId, {
    required bool canQualify,
    required String prose,
  }) {
    disclosuresByTask.putIfAbsent(taskId, () => []).add((
      canQualify: canQualify,
      prose: prose,
    ));
  }

  for (final block in _scheduled(outcome)) {
    final isWorkBlock =
        block.type == PlannedBlockType.ai ||
        block.type == PlannedBlockType.manual;
    final reason = block.reason?.trim();
    if (reason != null && reason.isNotEmpty) {
      for (final task in outcome.inputs.corpus) {
        if ((!isWorkBlock || block.taskId != task.taskId) &&
            (_taskIdNamed(task.taskId, reason) ||
                _titleNamed(outcome, task.taskId, reason))) {
          addDisclosure(task.taskId, canQualify: false, prose: reason);
        }
      }
    }
    final note = block.note?.trim();
    final noteTaskIds = <String>{
      if (note != null && note.isNotEmpty)
        for (final task in outcome.inputs.corpus)
          if (_taskIdNamed(task.taskId, note) ||
              _titleNamed(outcome, task.taskId, note))
            task.taskId,
    };
    if (note != null && note.isNotEmpty) {
      for (final taskId in noteTaskIds) {
        addDisclosure(taskId, canQualify: false, prose: note);
      }
    }
    if (!isWorkBlock) continue;
    final taskId = block.taskId;
    if (taskId == null) continue;
    allocatedByTask.update(
      taskId,
      (minutes) =>
          minutes + block.endTime.difference(block.startTime).inMinutes,
      ifAbsent: () => block.endTime.difference(block.startTime).inMinutes,
    );
    blocksByTask.putIfAbsent(taskId, () => []).add(block);
    if (reason != null && reason.isNotEmpty) {
      addDisclosure(taskId, canQualify: true, prose: reason);
    }
    if (note != null && note.isNotEmpty && noteTaskIds.isEmpty) {
      addDisclosure(taskId, canQualify: false, prose: note);
    }
  }
  return {
    for (final entry in allocatedByTask.entries)
      if (outcome.inputs.taskById(entry.key) case EvalCorpusTask(
        :final taskId,
        title: final taskTitle,
        estimateMinutes: final int estimate,
      ) when estimate > 0)
        entry.key: (
          corpus: outcome.inputs.corpus,
          allocatedMinutes: entry.value,
          disclosures: disclosuresByTask[entry.key] ?? const [],
          estimateMinutes: estimate,
          hasOverlappingBlocks: _hasOverlappingIntervals(
            blocksByTask[entry.key] ?? const [],
          ),
          now: outcome.inputs.now,
          taskId: taskId,
          taskTitle: taskTitle,
        ),
  };
}

bool _hasOverlappingIntervals(List<PlannedBlock> blocks) {
  if (blocks.length < 2) return false;
  final ordered = [...blocks]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  var latestEnd = ordered.first.endTime;
  for (final block in ordered.skip(1)) {
    if (block.startTime.isBefore(latestEnd)) return true;
    if (block.endTime.isAfter(latestEnd)) latestEnd = block.endTime;
  }
  return false;
}

/// Whether a placement is substantial and its partial arithmetic is auditable.
///
/// The 10% floor matches the token-placement boundary used by
/// [scoreRespectsEstimates]. Keeping it here prevents capacity and conflict
/// scoring from treating a one-minute task marker as genuine partial work.
/// Overlapping blocks are likewise ineligible because summed intervals can
/// manufacture represented minutes without adding wall-clock work.
bool _isAuditedPartial(_EstimatedTaskPlacement placement) =>
    placement.allocatedMinutes > 0 &&
    placement.allocatedMinutes < placement.estimateMinutes &&
    placement.allocatedMinutes * 10 >= placement.estimateMinutes &&
    !placement.hasOverlappingBlocks &&
    _hasAuditablePartialDisclosure(
      disclosures: placement.disclosures,
      allocatedMinutes: placement.allocatedMinutes,
      estimateMinutes: placement.estimateMinutes,
      taskId: placement.taskId,
      taskTitle: placement.taskTitle,
      corpus: placement.corpus,
      now: placement.now,
    );

/// Whether prose makes a shortened placement safe to charge as partial.
///
/// Block duration remains the authority. A reason earns partial accounting
/// only when its concrete minute arithmetic agrees with both that duration and
/// the corpus estimate. This accepts either an explicit `60m of 120m` split or
/// the prompt's `partial` plus a task-bound `60m remain for later` form. Vague
/// prose, `partial` used as an unrelated noun modifier, unrelated day-capacity
/// arithmetic, and contradictory numbers in either the reason or note keep the
/// conservative full-estimate charge. Notes are audit evidence only: they can
/// veto credit but cannot satisfy the prompt's reason-field disclosure contract.
bool _hasAuditablePartialDisclosure({
  required List<_PlacementDisclosure> disclosures,
  required int allocatedMinutes,
  required int estimateMinutes,
  required String taskId,
  required String taskTitle,
  required List<EvalCorpusTask> corpus,
  required DateTime? now,
}) {
  final remainingMinutes = estimateMinutes - allocatedMinutes;
  var hasMatchingSplit = false;
  var hasBoundPartialRemainder = false;
  for (final disclosure in disclosures) {
    final reason = disclosure.prose;
    if (_hasTaskBoundFullAllocationClaim(
          reason,
          taskId: taskId,
          taskTitle: taskTitle,
          corpus: corpus,
        ) ||
        _hasTaskBoundAllocationDenial(
          reason,
          taskId: taskId,
          taskTitle: taskTitle,
          corpus: corpus,
        )) {
      return false;
    }
    var reasonMentionsPartial = false;
    var reasonHasBoundRemainder = false;
    for (final match in _partialMentionPattern.allMatches(reason)) {
      if (_evidenceFallsInsideTaskReference(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          _tradeEvidenceHasExplicitNonTaskSubject(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          )) {
        continue;
      }
      if (_evidenceNamesAnotherTask(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      )) {
        continue;
      }
      if (!_partialMentionDescribesPlacement(reason, match)) continue;
      if (_evidenceIsSpeculative(reason, match)) continue;
      if (_partialMentionIsNegated(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
      )) {
        return false;
      }
      if (disclosure.canQualify) reasonMentionsPartial = true;
    }
    for (final match in _partialOfEstimatePattern.allMatches(reason)) {
      if (_evidenceFallsInsideTaskReference(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          _tradeEvidenceHasExplicitNonTaskSubject(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          !_splitIsTaskBound(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
            corpus: corpus,
            tomorrowIsFuture: now != null,
          )) {
        continue;
      }
      if (_matchClauseIsNegated(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      )) {
        return false;
      }
      final declaredAllocated = int.tryParse(match.group(1) ?? '');
      final declaredEstimate = int.tryParse(match.group(2) ?? '');
      if (declaredAllocated != allocatedMinutes ||
          declaredEstimate != estimateMinutes) {
        return false;
      }
      if (disclosure.canQualify) hasMatchingSplit = true;
    }
    for (final match in _partialRemainingPattern.allMatches(reason)) {
      if (_evidenceFallsInsideTaskReference(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          _tradeEvidenceHasExplicitNonTaskSubject(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          _remainderDescribesContinuity(reason, match) ||
          _evidenceIsSpeculative(reason, match)) {
        continue;
      }
      if (_evidenceNamesAnotherTask(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      )) {
        continue;
      }
      if (!_remainderIsRelatedToTask(reason, match)) continue;
      if (_matchClauseIsNegated(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      )) {
        return false;
      }
      final declaredRemaining = int.tryParse(match.group(1) ?? '');
      if (declaredRemaining != remainingMinutes) return false;
      if (disclosure.canQualify && _remainderIsTaskBound(reason, match)) {
        reasonHasBoundRemainder = true;
      }
    }
    for (final match in _partialLeadingRemainingPattern.allMatches(reason)) {
      if (_evidenceFallsInsideTaskReference(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          _tradeEvidenceHasExplicitNonTaskSubject(
            reason,
            match,
            taskId: taskId,
            taskTitle: taskTitle,
          ) ||
          _remainderDescribesContinuity(reason, match) ||
          _evidenceIsSpeculative(reason, match)) {
        continue;
      }
      if (_evidenceNamesAnotherTask(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      )) {
        continue;
      }
      if (!_remainderIsRelatedToTask(reason, match)) continue;
      if (_matchClauseIsNegated(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      )) {
        return false;
      }
      final declaredRemaining = int.tryParse(match.group(1) ?? '');
      if (declaredRemaining != remainingMinutes) return false;
      if (disclosure.canQualify && _remainderIsTaskBound(reason, match)) {
        reasonHasBoundRemainder = true;
      }
    }
    if (reasonMentionsPartial && reasonHasBoundRemainder) {
      hasBoundPartialRemainder = true;
    }
  }
  return hasMatchingSplit || hasBoundPartialRemainder;
}

bool _hasTaskBoundFullAllocationClaim(
  String prose, {
  required String taskId,
  required String taskTitle,
  required List<EvalCorpusTask> corpus,
}) {
  for (final match in _fullAllocationPattern.allMatches(prose)) {
    if (_evidenceFallsInsideTaskReference(
          prose,
          match,
          taskId: taskId,
          taskTitle: taskTitle,
        ) ||
        _tradeEvidenceHasExplicitNonTaskSubject(
          prose,
          match,
          taskId: taskId,
          taskTitle: taskTitle,
        ) ||
        _fullAllocationClaimHasExplicitNonTaskHead(prose, match) ||
        _evidenceNamesAnotherTask(
          prose,
          match,
          taskId: taskId,
          taskTitle: taskTitle,
          corpus: corpus,
        ) ||
        _evidenceHasNonCurrentAllocationScope(prose, match) ||
        !_evidenceActionIsAsserted(prose, match.start) ||
        _evidenceIsSpeculative(prose, match) ||
        _matchClauseIsNegated(
          prose,
          match,
          taskId: taskId,
          taskTitle: taskTitle,
          corpus: corpus,
        ) ||
        _negativeTradeDisclosureIsDenied(prose, match)) {
      continue;
    }
    return true;
  }
  return false;
}

bool _fullAllocationClaimHasExplicitNonTaskHead(
  String prose,
  Match match,
) {
  final range = _matchClauseRange(prose, match, boundaries: ',.;!?\n');
  final suffix = prose.substring(match.end, range.end);
  return RegExp(
    r'^\s+(?:(?:for|throughout)\s+)?'
    r'(?:(?:the|a|an|this|that|my|your|his|her|its|our|their)\s+)?'
    '(?:day|meeting|workday|calendar|appointment|break|event|agenda|'
    r'schedule|session)\b',
    caseSensitive: false,
  ).hasMatch(suffix);
}

bool _partialMentionIsNegated(
  String reason,
  Match match, {
  required String taskId,
  required String taskTitle,
}) {
  final range = _matchClauseRange(reason, match, boundaries: ',.;!?\n');
  final segment = reason.substring(range.start, range.end);
  for (final negation in _negationWordPattern.allMatches(segment)) {
    final negationStart = range.start + negation.start;
    final negationEnd = range.start + negation.end;
    if (negationEnd > match.start) continue;
    if (_rangeFallsInsideTaskReference(
      reason,
      start: negationStart,
      end: negationEnd,
      taskId: taskId,
      taskTitle: taskTitle,
    )) {
      continue;
    }
    final between = reason.substring(negationEnd, match.start);
    if (_negationQualifiesRatherThanNegates(negation, between)) {
      continue;
    }
    if (_wordPattern.allMatches(between).length <= 3) return true;
  }
  return false;
}

bool _partialMentionDescribesPlacement(String prose, Match match) {
  final wording = (match.group(0) ?? '').toLowerCase();
  final range = _matchClauseRange(prose, match, boundaries: ',.;!?\n');
  final prefix = prose.substring(range.start, match.start);
  final suffix = prose.substring(match.end, range.end);
  if (wording == 'partially' || wording == 'partly') {
    return RegExp(
      r'^\s+(?:'
      '$_placementActionSource|'
      r'fit(?:s|ting)?|defer(?:s|red|ring)?|done|unfinished)\b',
      caseSensitive: false,
    ).hasMatch(suffix);
  }

  final followsCopula = RegExp(
    r'\b(?:(?:is|are|was|were)(?:\s+being)?|'
    r'(?:has|have|had)\s+been(?:\s+being)?|will\s+be(?:\s+being)?)'
    r'(?:\s+(?:only|merely|just|still))?\s*$',
    caseSensitive: false,
  ).hasMatch(prefix);
  final modifiesPlacementNoun = RegExp(
    r'^\s+(?:task|work|placement|block|portion|part)\b',
    caseSensitive: false,
  ).hasMatch(suffix);
  final isStandaloneLabelOrExplanation = RegExp(
    r'^\s*(?:$|[:;,.\-–—!?]|(?:for|because|due\s+to|with|and)\b)',
    caseSensitive: false,
  ).hasMatch(suffix);
  return followsCopula ||
      modifiesPlacementNoun ||
      isStandaloneLabelOrExplanation;
}

bool _tradeEvidenceDescribesTaskOrWork(
  String prose,
  Match match, {
  required String taskId,
  required String taskTitle,
}) {
  final range = _matchClauseRange(prose, match, boundaries: ',.;!?\n');
  final wording = (match.group(0) ?? '').toLowerCase();
  if (wording.startsWith('for ')) {
    final prefix = prose.substring(range.start, match.start);
    if (!RegExp(
      r'\b(?:is|are|was|were|remain(?:s|ed|ing)?|left|'
      '$_placementActionSource|'
      'defer(?:s|red|ring)?|omit(?:s|ted|ting)?|'
      'drop(?:s|ped|ping)?|move(?:s|d|ing)?|'
      r'roll(?:s|ed|ing)?|carr(?:y|ies|ied|ying))\s*$',
      caseSensitive: false,
    ).hasMatch(prefix)) {
      return false;
    }
  }
  final suffix = prose.substring(match.end, range.end);
  if (!RegExp(r'^\s+\w').hasMatch(suffix)) return true;
  if (_subjectStartsWithPossessiveTaskReferenceToNonTaskHead(
    suffix.trimLeft(),
    taskId: taskId,
    taskTitle: taskTitle,
  )) {
    return false;
  }
  for (final pattern in _taskReferencePatterns(taskId, taskTitle)) {
    final reference = pattern.firstMatch(suffix);
    if (reference != null && reference.start == 0) return true;
  }
  return RegExp(
        r'^\s+(?:(?:the|this|that|their|our|my|your)\s+)?'
        r'(?:task|work|remainder|rest|portion|part)\b',
        caseSensitive: false,
      ).hasMatch(suffix) ||
      RegExp(
        r'^\s+(?:to|until|for|because|since|as|due\s+to|owing\s+to|after|'
        r'before|so|and|but|yet|with|against|over)\b',
        caseSensitive: false,
      ).hasMatch(suffix) ||
      RegExp(
        r'^\s+(?:entirely|completely|fully|actually|definitely|explicitly|'
        'ultimately|finally|temporarily)'
        r'(?:\s*$|\s+(?:to|until|for|because|since|as|due\s+to|owing\s+to|'
        r'after|before|so|and|but|yet|with|against|over)\b)',
        caseSensitive: false,
      ).hasMatch(suffix) ||
      RegExp(
        r'^\s+by\s+(?:'
        r'\d+(?:[.,]\d+)?\s*(?:%|percent|minutes?|hours?)|'
        r'(?:an?|half\s+an)\s+hour)\b',
        caseSensitive: false,
      ).hasMatch(suffix) ||
      RegExp(
        r'^\s+from\s+(?:(?:today[\x27’]s|the|this|our|my|your|their)\s+)?'
        r'(?:plan|schedule|day)\b',
        caseSensitive: false,
      ).hasMatch(suffix);
}

bool _negativeFitEvidenceDescribesTaskOrWork(
  String prose,
  Match match, {
  required String taskId,
  required String taskTitle,
}) {
  final range = _matchClauseRange(prose, match, boundaries: ',.;!?\n');
  final prefix = prose.substring(range.start, match.start).trimRight();
  for (final pattern in _taskReferencePatterns(taskId, taskTitle)) {
    for (final reference in pattern.allMatches(prefix)) {
      final separator = prefix.substring(reference.end);
      if (RegExp(r'^\s*(?:[:\-–—]\s*)?$').hasMatch(separator)) {
        return true;
      }
    }
  }
  return RegExp(
    r'\b(?:(?:the|this|that|its|our|my|your|their|full|remaining)\s+)*'
    r'(?:task|work|remainder|rest|portion|part|it)\s*$',
    caseSensitive: false,
  ).hasMatch(prefix);
}

bool _hasTaskBoundAllocationDenial(
  String prose, {
  required String taskId,
  required String taskTitle,
  required List<EvalCorpusTask> corpus,
}) {
  final placementActionPattern = RegExp(
    r'\b(?:'
    '$_placementActionSource'
    r')\b',
    caseSensitive: false,
  );
  for (final action in placementActionPattern.allMatches(prose)) {
    if (_evidenceHasNonCurrentAllocationScope(prose, action) ||
        !_allocationActionIsDirectlyDenied(
          prose,
          action,
          taskId: taskId,
          taskTitle: taskTitle,
        )) {
      continue;
    }
    if (_evidenceIsSpeculative(prose, action)) continue;
    if (_tradeEvidenceHasExplicitNonTaskSubject(
      prose,
      action,
      taskId: taskId,
      taskTitle: taskTitle,
    )) {
      continue;
    }
    final range = _matchClauseRange(prose, action, boundaries: ',.;!?\n');
    if (_nearestTaskReferenceDistance(
          prose,
          action,
          range: range,
          taskId: taskId,
          taskTitle: taskTitle,
        ) !=
        null) {
      return true;
    }
    final clause = prose.substring(range.start, range.end);
    final explicitlyNamesOtherTask = corpus
        .where((task) => task.taskId != taskId)
        .any(
          (task) => _taskReferencePatterns(
            task.taskId,
            task.title,
          ).any((pattern) => pattern.hasMatch(clause)),
        );
    if (explicitlyNamesOtherTask) continue;
    if (_evidenceNamesAnotherTask(
      prose,
      action,
      taskId: taskId,
      taskTitle: taskTitle,
      corpus: corpus,
    )) {
      continue;
    }
    return true;
  }
  final allocationFailurePattern = RegExp(
    r'\b(?:(?:(?:the|this|that)\s+)?'
    r'(?:allocation|placement|scheduling|completion)\s+'
    r'(?:(?:has|had)\s+)?fail(?:s|ed|ing)?|'
    r'fail(?:s|ed|ing)?\s+to\s+(?:be\s+)?'
    '(?:schedul(?:e|ed)|allocat(?:e|ed)|complet(?:e|ed)|'
    r'plan(?:ned)?|plac(?:e|ed)))\b',
    caseSensitive: false,
  );
  for (final failure in allocationFailurePattern.allMatches(prose)) {
    if (_evidenceHasNonCurrentAllocationScope(prose, failure) ||
        _evidenceIsSpeculative(prose, failure) ||
        _tradeEvidenceHasExplicitNonTaskSubject(
          prose,
          failure,
          taskId: taskId,
          taskTitle: taskTitle,
        ) ||
        _evidenceNamesAnotherTask(
          prose,
          failure,
          taskId: taskId,
          taskTitle: taskTitle,
          corpus: corpus,
        )) {
      continue;
    }
    final range = _matchClauseRange(
      prose,
      failure,
      boundaries: ',.;!?\n',
    );
    if (_allocationFailureHasExplicitNonTaskScope(prose, failure, range)) {
      continue;
    }
    final prefix = prose.substring(range.start, failure.start);
    if (RegExp(
      r'^\s*(?:(?:and|but|yet|so)\s+)?$',
      caseSensitive: false,
    ).hasMatch(prefix)) {
      return true;
    }
  }
  return false;
}

bool _allocationFailureHasExplicitNonTaskScope(
  String prose,
  Match failure,
  ({int start, int end}) range,
) {
  const nonTaskHead = '(?:meeting|workday|calendar|appointment|event|session)';
  final prefix = prose.substring(range.start, failure.start);
  if (RegExp(
    '$nonTaskHead\\s*\$',
    caseSensitive: false,
  ).hasMatch(prefix)) {
    return true;
  }
  final suffix = prose.substring(failure.end, range.end);
  return RegExp(
    r'^\s+for\s+(?:(?:the|this|that|a|an)\s+)?' + nonTaskHead + r'\b',
    caseSensitive: false,
  ).hasMatch(suffix);
}

bool _allocationActionIsDirectlyDenied(
  String prose,
  Match action, {
  required String taskId,
  required String taskTitle,
}) {
  final range = _matchClauseRange(prose, action, boundaries: ',.;!?\n');
  final clause = prose.substring(range.start, action.start);
  for (final negation in _negationWordPattern.allMatches(clause)) {
    if (_evidenceFallsInsideTaskReference(
      clause,
      negation,
      taskId: taskId,
      taskTitle: taskTitle,
    )) {
      continue;
    }
    final negationEnd = range.start + negation.end;
    final between = prose.substring(negationEnd, action.start);
    if (_negationQualifiesRatherThanNegates(negation, between)) continue;
    if (_wordPattern.allMatches(between).length <= 3) return true;
  }
  return false;
}

bool _evidenceIsSpeculative(String prose, Match match) {
  return _evidenceStartIsSpeculative(prose, match.start);
}

bool _evidenceStartIsSpeculative(String prose, int evidenceStart) {
  var clauseStart = 0;
  for (var i = evidenceStart - 1; i >= 0; i--) {
    if (',.;!?\n'.contains(prose[i])) {
      clauseStart = i + 1;
      break;
    }
  }
  final prefix = prose.substring(clauseStart, evidenceStart);
  for (final modal in RegExp(
    r'\b(?:might|may|could|would|should|can)\b',
    caseSensitive: false,
  ).allMatches(prefix)) {
    final complement = prefix.substring(modal.end);
    if (!RegExp(
      r'\b(?:so|therefore)\b|'
      r'\b(?:and|but|yet|while|although|though)\s+'
      r'(?:(?:the|this|that|a|an)\s+)?[\w-]+\s+'
      r'(?:is|are|was|were|has|have|had|will|does|do|did)\b',
      caseSensitive: false,
    ).hasMatch(complement)) {
      return true;
    }
  }
  return false;
}

bool _negationQualifiesRatherThanNegates(Match negation, String between) {
  final negator = (negation.group(0) ?? '').toLowerCase();
  if (negator == 'no') {
    return RegExp(
      r'^\s*(?:more\s+than|(?:choice|option|alternative)\s+but\s+to)\b',
      caseSensitive: false,
    ).hasMatch(between);
  }
  if (negator != 'not') return false;
  return RegExp(r'^\s*only\b', caseSensitive: false).hasMatch(between) ||
      RegExp(
        r'^\s*(?:fully|entirely|completely)\b',
        caseSensitive: false,
      ).hasMatch(between) ||
      RegExp(
        r'^\s*all\b.*\bfit(?:s|ting)?\b\s+'
        r'(?:so|therefore|thus|but)\s*$',
        caseSensitive: false,
      ).hasMatch(between);
}

bool _matchClauseIsNegated(
  String reason,
  Match match, {
  String? taskId,
  String? taskTitle,
  List<EvalCorpusTask> corpus = const [],
}) {
  final range = _matchClauseRange(reason, match, boundaries: ',.;!?\n');
  final prefix = reason.substring(range.start, match.start);
  if (_outerFalsehoodPattern.hasMatch(prefix)) {
    return true;
  }
  if (RegExp(
    r'\b(?:(?:without)(?:\s+any)?|free\s+of)\s*$',
    caseSensitive: false,
  ).hasMatch(prefix)) {
    return true;
  }
  if (_avoidanceComplementPattern.hasMatch(prefix)) {
    return true;
  }
  for (final negation in _negationWordPattern.allMatches(reason, range.start)) {
    if (negation.start >= range.end) break;
    final negationStart = negation.start;
    final negationEnd = negation.end;
    if (taskId != null &&
        taskTitle != null &&
        (_evidenceFallsInsideTaskReference(
              reason,
              negation,
              taskId: taskId,
              taskTitle: taskTitle,
            ) ||
            _evidenceNamesAnotherTask(
              reason,
              negation,
              taskId: taskId,
              taskTitle: taskTitle,
              corpus: corpus,
            ))) {
      continue;
    }
    final between = negationEnd <= match.start
        ? reason.substring(negationEnd, match.start)
        : negationStart >= match.end
        ? reason.substring(match.end, negationStart)
        : '';
    if (negationEnd <= match.start &&
        _negationQualifiesRatherThanNegates(negation, between)) {
      continue;
    }
    if (negationEnd <= match.start &&
        _negationEndsAtContrastiveTradePredicate(between)) {
      continue;
    }
    if (negationEnd <= match.start &&
        _longNegatedComplementPattern.hasMatch(between)) {
      return true;
    }
    if (negationStart >= match.end &&
        _followingNegationExplainsCapacityLimit(
          reason,
          negationStart: negationStart,
          clauseEnd: range.end,
        )) {
      continue;
    }
    if (negationStart >= match.end &&
        RegExp('[–—]').hasMatch(between) &&
        _wordPattern.hasMatch(between)) {
      continue;
    }
    if (negationStart >= match.end &&
        _taskAllocationActionPattern.hasMatch(between)) {
      continue;
    }
    if (_wordPattern.allMatches(between).length <= 3 ||
        negationEnd <= match.start &&
            _taskAllocationActionPattern.hasMatch(between)) {
      return true;
    }
  }
  return false;
}

bool _followingNegationExplainsCapacityLimit(
  String prose, {
  required int negationStart,
  required int clauseEnd,
}) {
  final suffix = prose.substring(negationStart, clauseEnd);
  return RegExp(
    r'^no\s+more'
    r'(?:\s+(?:of\s+(?:this|the)\s+)?(?:task|work))?\s+'
    r'(?:(?:can|will)\s+)?fit(?:s|ting)?\b',
    caseSensitive: false,
  ).hasMatch(suffix);
}

bool _negativeTradeDisclosureIsDenied(String prose, Match match) {
  final range = _matchClauseRange(prose, match, boundaries: ',.;!?\n');
  final prefix = prose.substring(range.start, match.start);
  if (_outerFalsehoodPattern.hasMatch(prefix)) {
    return true;
  }
  final clause = prose.substring(range.start, range.end);
  for (final negation in _negationWordPattern.allMatches(clause)) {
    final start = range.start + negation.start;
    final end = range.start + negation.end;
    if (start >= match.start && end <= match.end) continue;
    final between = end <= match.start
        ? prose.substring(end, match.start)
        : start >= match.end
        ? prose.substring(match.end, start)
        : '';
    if (end <= match.start &&
        _negationQualifiesRatherThanNegates(negation, between)) {
      continue;
    }
    if (end <= match.start &&
        _negationEndsAtContrastiveTradePredicate(between)) {
      continue;
    }
    if (start >= match.end &&
        RegExp(
          r'^\s*(?:because|since|as|due\s+to|owing\s+to)\s*$',
          caseSensitive: false,
        ).hasMatch(between)) {
      continue;
    }
    if (_wordPattern.allMatches(between).length <= 3) return true;
  }
  return false;
}

bool _negationEndsAtContrastiveTradePredicate(String between) {
  final contrast = RegExp(
    r'\bbut\s*$',
    caseSensitive: false,
  ).firstMatch(between);
  if (contrast == null) return false;
  final deniedPredicate = between.substring(0, contrast.start);
  return _partialTradeDispositionPattern.hasMatch(deniedPredicate) ||
      _conflictTradePattern.hasMatch(deniedPredicate);
}

bool _splitIsTaskBound(
  String reason,
  Match match, {
  required String taskId,
  required String taskTitle,
  required List<EvalCorpusTask> corpus,
  required bool tomorrowIsFuture,
}) {
  return !_evidenceHasExplicitNonTaskObject(reason, match) &&
      _splitHasAffirmativeAllocation(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
      ) &&
      !_splitHasUnrelatedScope(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        tomorrowIsFuture: tomorrowIsFuture,
      ) &&
      !_evidenceNamesAnotherTask(
        reason,
        match,
        taskId: taskId,
        taskTitle: taskTitle,
        corpus: corpus,
      );
}

bool _splitHasAffirmativeAllocation(
  String reason,
  Match match, {
  required String taskId,
  required String taskTitle,
}) {
  final action = _nearestAllocationActionMatch(
    reason,
    match,
    taskId: taskId,
    taskTitle: taskTitle,
  );
  if (action == null || !_evidenceActionIsAsserted(reason, action.start)) {
    return false;
  }
  final omission = _nearestPatternMatch(
    reason,
    match,
    _omittedAllocationPattern,
  );
  return omission == null || action.distance < omission.distance;
}

bool _evidenceActionIsAsserted(
  String prose,
  int actionStart,
) {
  if (RegExp(
    r'^\w+\s+unsuccessfully\b',
    caseSensitive: false,
  ).hasMatch(prose.substring(actionStart))) {
    return false;
  }
  var clauseStart = 0;
  for (var i = actionStart - 1; i >= 0; i--) {
    if (',.;!?\n'.contains(prose[i])) {
      clauseStart = i + 1;
      break;
    }
  }
  final prefix = prose.substring(clauseStart, actionStart);
  return !_evidenceClauseIsInterrogative(prose, actionStart) &&
      !_evidenceActionIsImperative(prose, actionStart, prefix) &&
      !_evidenceStartsInConditionalClause(prefix) &&
      !_evidenceStartIsSpeculative(prose, actionStart) &&
      !RegExp(
        r'\b(?:almost|nearly|not\s+quite|unsuccessfully|'
        r'(?:(?:is|are|was|were)\s+)?(?:likely|unlikely)\s+to'
        r'(?:\s+(?:be|being|get|getting))?|'
        r'(?:(?:is|are|was|were)\s+)?(?:supposed|meant|going)\s+to'
        r'(?:\s+(?:be|being|get|getting))?|'
        '(?:(?:intend(?:s|ed|ing)?|aim(?:s|ed|ing)?|'
        'hop(?:e|es|ed|ing)|want(?:s|ed|ing)?|expect(?:s|ed|ing)?|'
        'propos(?:e|es|ed|ing)|plan(?:s|ned|ning)?|'
        'consider(?:s|ed|ing)?|'
        'attempt(?:s|ed|ing)?|tr(?:y|ies|ied|ying)|'
        'fail(?:s|ed|ing)?|den(?:y|ies|ied|ying)|'
        'refus(?:e|es|ed|ing)|'
        r'declin(?:e|es|ed|ing))(?:\s+to)?'
        r'(?:\s+(?:be|being|get|getting))?))\s*$',
        caseSensitive: false,
      ).hasMatch(prefix) &&
      !RegExp(
        r'\b(?:must|need(?:s|ed)?\s+to|'
        r'(?:has|have|had)\s+to|(?:is|are|was|were)\s+required\s+to|'
        r'ought\s+to|requir(?:e|es|ed|ing)(?:\s+to)?)'
        r'(?:\s+(?:be|being|get|getting))?\s*$',
        caseSensitive: false,
      ).hasMatch(prefix) &&
      !RegExp(
        r'\b(?:(?:(?:is|are|was|were|be|been|being)\s+)?'
        r'(?:unable\s+to|not\s+able\s+to|incapable\s+of)|'
        r'(?:isn|aren|wasn|weren)[\x27’]?t\s+able\s+to)'
        r'(?:\s+(?:be|being|get|getting))?\s*$',
        caseSensitive: false,
      ).hasMatch(prefix) &&
      !_avoidanceComplementPattern.hasMatch(prefix);
}

bool _evidenceActionIsImperative(
  String prose,
  int actionStart,
  String prefix,
) =>
    RegExp(
      r'^\s*(?:please\s+)?$',
      caseSensitive: false,
    ).hasMatch(prefix) &&
    RegExp(
      '^(?:schedule|allocate|complete|plan|place|fit|omit|drop|defer|'
      r'postpone|shorten|roll|move|carry|leave)\b',
      caseSensitive: false,
    ).hasMatch(prose.substring(actionStart));

bool _evidenceStartsInConditionalClause(String prefix) =>
    RegExp(
      r'^\s*(?:(?:even\s+)?if|unless)\b',
      caseSensitive: false,
    ).hasMatch(prefix) ||
    RegExp(
      r'^\s*(?:were|had)\b',
      caseSensitive: false,
    ).hasMatch(prefix);

bool _evidenceClauseIsInterrogative(String prose, int evidenceStart) {
  for (var i = evidenceStart; i < prose.length; i++) {
    if (prose[i] == '?') return true;
    if (',.;!\n'.contains(prose[i])) return false;
  }
  return false;
}

bool _splitHasUnrelatedScope(
  String reason,
  Match evidence, {
  required String taskId,
  required String taskTitle,
  required bool tomorrowIsFuture,
}) {
  final evidenceAction = _nearestAllocationActionMatch(
    reason,
    evidence,
    taskId: taskId,
    taskTitle: taskTitle,
  );
  if (evidenceAction == null) return false;
  final range = _matchClauseRange(reason, evidence, boundaries: ',.;!?\n');
  final scopeEnd = evidence.end > evidenceAction.end
      ? evidence.end
      : evidenceAction.end;
  if (_evidenceHasNonCurrentAllocationScope(
    reason,
    evidence,
    evidenceEnd: scopeEnd,
    tomorrowIsFuture: tomorrowIsFuture,
  )) {
    return true;
  }
  final currentTaskDistance = _nearestTaskReferenceDistance(
    reason,
    evidence,
    range: range,
    taskId: taskId,
    taskTitle: taskTitle,
  );
  for (final scope in _unrelatedRemainderScopePattern.allMatches(reason)) {
    if (scope.start < range.start || scope.end > range.end) continue;
    final scopeAction = _nearestPatternMatch(
      reason,
      scope,
      _taskAllocationActionPattern,
    );
    if (scopeAction != null &&
        scopeAction.start == evidenceAction.start &&
        scopeAction.end == evidenceAction.end) {
      final explicitlyAllocatedToScope = RegExp(
        r'^for\b',
        caseSensitive: false,
      ).hasMatch(scope.group(0) ?? '');
      return currentTaskDistance == null || explicitlyAllocatedToScope;
    }
  }
  return false;
}

bool _evidenceHasHistoricalScope(
  String prose,
  Match evidence, {
  int? evidenceEnd,
}) {
  final range = _matchClauseRange(prose, evidence, boundaries: ',.;!?\n');
  if (_historicalAllocationScopePattern.hasMatch(
    prose.substring(evidenceEnd ?? evidence.end, range.end),
  )) {
    return true;
  }
  return _leadingHistoricalAllocationScopePattern.hasMatch(
    prose.substring(0, range.start),
  );
}

bool _evidenceHasNonCurrentAllocationScope(
  String prose,
  Match evidence, {
  int? evidenceEnd,
  bool tomorrowIsFuture = false,
}) {
  if (_evidenceHasHistoricalScope(
    prose,
    evidence,
    evidenceEnd: evidenceEnd,
  )) {
    return true;
  }
  final range = _matchClauseRange(prose, evidence, boundaries: ',.;!?\n');
  if (_futureAllocationScopePattern.hasMatch(
    prose.substring(evidenceEnd ?? evidence.end, range.end),
  )) {
    return true;
  }
  final leadingScope = prose.substring(0, range.start);
  if (_leadingFutureAllocationScopePattern.hasMatch(leadingScope)) {
    return true;
  }
  if (!tomorrowIsFuture) return false;
  return _tomorrowAllocationScopePattern.hasMatch(
        prose.substring(evidenceEnd ?? evidence.end, range.end),
      ) ||
      _leadingTomorrowAllocationScopePattern.hasMatch(leadingScope);
}

({int start, int end, int distance})? _nearestPatternMatch(
  String reason,
  Match evidence,
  RegExp pattern,
) {
  final range = _matchClauseRange(reason, evidence, boundaries: ',.;!?\n');
  final clause = reason.substring(range.start, range.end);
  ({int start, int end, int distance})? nearest;
  for (final match in pattern.allMatches(clause)) {
    final start = range.start + match.start;
    final end = range.start + match.end;
    final distance = end <= evidence.start
        ? evidence.start - end
        : start >= evidence.end
        ? start - evidence.end
        : 0;
    if (nearest == null || distance < nearest.distance) {
      nearest = (start: start, end: end, distance: distance);
    }
  }
  return nearest;
}

({int start, int end, int distance})? _nearestAllocationActionMatch(
  String reason,
  Match evidence, {
  required String taskId,
  required String taskTitle,
}) {
  final range = _matchClauseRange(reason, evidence, boundaries: ',.;!?\n');
  final clause = reason.substring(range.start, range.end);
  ({int start, int end, int distance})? nearest;
  for (final match in _taskAllocationActionPattern.allMatches(clause)) {
    final start = range.start + match.start;
    final end = range.start + match.end;
    if (_rangeFallsInsideTaskReference(
      reason,
      start: start,
      end: end,
      taskId: taskId,
      taskTitle: taskTitle,
    )) {
      continue;
    }
    if (end <= evidence.start) {
      if (!RegExp(
        r'^\s*(?:for\s+)?(?:(?:only|just|merely|about|approximately|roughly|'
        r'exactly|precisely)\s+)?$',
        caseSensitive: false,
      ).hasMatch(reason.substring(end, evidence.start))) {
        continue;
      }
    } else if (start >= evidence.end &&
        !RegExp(
          r'^\s*(?:(?:is|are|was|were|will|be|been|being|has|have|had|'
          'do|does|did|'
          'only|just|merely|already|actually|currently|now|'
          'estimate|estimated|successfully|explicitly|deliberately|'
          r'intentionally|firmly|definitively|concretely)\s+)*$',
          caseSensitive: false,
        ).hasMatch(reason.substring(evidence.end, start))) {
      continue;
    }
    final distance = end <= evidence.start
        ? evidence.start - end
        : start >= evidence.end
        ? start - evidence.end
        : 0;
    if (nearest == null || distance < nearest.distance) {
      nearest = (start: start, end: end, distance: distance);
    }
  }
  return nearest;
}

bool _evidenceNamesAnotherTask(
  String reason,
  Match evidence, {
  required String taskId,
  required String taskTitle,
  required List<EvalCorpusTask> corpus,
}) {
  final range = _matchClauseRange(reason, evidence, boundaries: '.;!?\n');
  final currentDistance = _nearestTaskReferenceDistance(
    reason,
    evidence,
    range: range,
    taskId: taskId,
    taskTitle: taskTitle,
  );
  int? nearestOtherDistance;
  for (final task in corpus) {
    if (task.taskId == taskId) continue;
    final distance = _nearestTaskReferenceDistance(
      reason,
      evidence,
      range: range,
      taskId: task.taskId,
      taskTitle: task.title,
    );
    if (distance != null &&
        (nearestOtherDistance == null || distance < nearestOtherDistance)) {
      nearestOtherDistance = distance;
    }
  }
  return nearestOtherDistance != null &&
      (currentDistance == null || nearestOtherDistance <= currentDistance);
}

int? _nearestTaskReferenceDistance(
  String reason,
  Match evidence, {
  required ({int start, int end}) range,
  required String taskId,
  required String taskTitle,
}) {
  final clause = reason.substring(range.start, range.end);
  int? nearest;
  for (final pattern in _taskReferencePatterns(taskId, taskTitle)) {
    for (final reference in pattern.allMatches(clause)) {
      final referenceStart = range.start + reference.start;
      final referenceEnd = range.start + reference.end;
      if (!_referenceAttributesEvidence(
        reason,
        evidence,
        referenceStart: referenceStart,
        referenceEnd: referenceEnd,
      )) {
        continue;
      }
      final distance = referenceEnd <= evidence.start
          ? evidence.start - referenceEnd
          : referenceStart >= evidence.end
          ? referenceStart - evidence.end
          : 0;
      if (nearest == null || distance < nearest) nearest = distance;
    }
  }
  return nearest;
}

List<RegExp> _taskReferencePatterns(String taskId, String taskTitle) {
  final title = taskTitle.trim();
  return [
    RegExp(
      r'(?:^|[^\w-])' + RegExp.escape(taskId) + r'(?=$|[^\w-])',
      caseSensitive: false,
    ),
    RegExp(
      r'\btask\s+' + RegExp.escape(title) + r'\b',
      caseSensitive: false,
    ),
    if (_allowsBareTaskTitle(title))
      RegExp(
        r'(?:^|[^\w-])' + RegExp.escape(title) + r'(?=$|[^\w-])',
        caseSensitive: false,
      ),
  ];
}

bool _allowsBareTaskTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized != 'a' && normalized != 'i';
}

bool _evidenceFallsInsideTaskReference(
  String prose,
  Match evidence, {
  required String taskId,
  required String taskTitle,
}) {
  return _rangeFallsInsideTaskReference(
    prose,
    start: evidence.start,
    end: evidence.end,
    taskId: taskId,
    taskTitle: taskTitle,
  );
}

bool _rangeFallsInsideTaskReference(
  String prose, {
  required int start,
  required int end,
  required String taskId,
  required String taskTitle,
}) {
  for (final pattern in _taskReferencePatterns(taskId, taskTitle)) {
    for (final reference in pattern.allMatches(prose)) {
      if (reference.start <= start && reference.end >= end) {
        return true;
      }
    }
  }
  return false;
}

bool _referenceAttributesEvidence(
  String reason,
  Match evidence, {
  required int referenceStart,
  required int referenceEnd,
}) {
  if (referenceEnd <= evidence.start) {
    final between = reason.substring(referenceEnd, evidence.start);
    final trimmed = between.trim();
    return trimmed.isEmpty ||
        _taskAllocationActionPattern.hasMatch(between) ||
        RegExp(
          r'^(?:is|are|was|were|has|have|had|will\s+be)(?:\s+not)?$',
          caseSensitive: false,
        ).hasMatch(trimmed) ||
        RegExp(r'^[\x27’]s$', caseSensitive: false).hasMatch(trimmed) ||
        RegExp(r'^[,:–—-]+$').hasMatch(trimmed);
  }
  if (referenceStart < evidence.end) return true;
  final between = reason.substring(evidence.end, referenceStart);
  final prepositionAttaches = RegExp(
    r'\b(?:for|of)\s*(?:the\s+)?$',
    caseSensitive: false,
  ).hasMatch(between);
  final allocationToAttaches =
      _taskAllocationActionPattern.hasMatch(between) &&
      RegExp(
        r'\bto\s*(?:the\s+)?$',
        caseSensitive: false,
      ).hasMatch(between);
  final labelAttaches = RegExp(r'^\s*[:–—-]\s*$').hasMatch(between);
  return prepositionAttaches || allocationToAttaches || labelAttaches;
}

bool _remainderIsTaskBound(String reason, Match match) {
  if (_evidenceHasExplicitNonTaskObject(reason, match) ||
      _remainderHasExplicitNonTaskSubject(reason, match)) {
    return false;
  }
  final clause = _matchClause(reason, match);
  if (_unrelatedRemainderScopePattern.hasMatch(clause)) return false;
  if (_partialRemainderDispositionPattern.hasMatch(clause)) return true;
  return _partialMentionPattern.hasMatch(reason);
}

bool _remainderIsRelatedToTask(String reason, Match match) {
  if (_evidenceHasExplicitNonTaskObject(reason, match) ||
      _remainderHasExplicitNonTaskSubject(reason, match)) {
    return false;
  }
  if (_remainderIsTaskBound(reason, match)) return true;
  return !_unrelatedRemainderScopePattern.hasMatch(_matchClause(reason, match));
}

bool _remainderHasExplicitNonTaskSubject(String reason, Match match) {
  final range = _matchClauseRange(reason, match, boundaries: ',.;!?\n');
  final prefix = reason.substring(range.start, match.start);
  return RegExp(
    r'^\s*(?:(?:and|but|yet|so)\s+)?'
    r'(?:(?:the|a|an|this|that|its)\s+)?'
    r'(?!(?:task|work|placement|block|remainder|remaining|rest|portion|part)\b)'
    r'[\w-]+(?:\s+[\w-]+){0,3}\s+'
    r'(?:shows?|reports?|displays?|reads?|has|have|had)\s*$',
    caseSensitive: false,
  ).hasMatch(prefix);
}

bool _evidenceHasExplicitNonTaskObject(String reason, Match match) {
  final range = _matchClauseRange(reason, match, boundaries: ',.;!?\n');
  final prefix = reason.substring(range.start, match.start);
  return RegExp(
    r'\b(?:a|an|the|this|that)\s+'
    r'(?!(?:task|work|placement|block|remainder|rest|portion|part)\b)'
    r'[\w-]+(?:\s+[\w-]+){0,3}\s+with\s*$',
    caseSensitive: false,
  ).hasMatch(prefix);
}

bool _remainderDescribesContinuity(String reason, Match match) {
  final range = _matchClauseRange(reason, match, boundaries: ',.;!?\n');
  final suffix = reason.substring(match.end, range.end);
  return RegExp(
    r'^\s+(?:(?:is|are|was|were|will\s+be)\s+)?'
    '(?:schedul(?:e|ed|ing)|allocat(?:e|ed|ing)|'
    'plan(?:ned|ning)?|plac(?:e|ed|ing)|book(?:ed|ing)|'
    r'unchanged|intact|available|open)\b',
    caseSensitive: false,
  ).hasMatch(suffix);
}

String _matchClause(
  String reason,
  Match match, {
  String boundaries = '.;!?\n',
}) {
  final range = _matchClauseRange(reason, match, boundaries: boundaries);
  return reason.substring(range.start, range.end);
}

({int start, int end}) _matchClauseRange(
  String reason,
  Match match, {
  required String boundaries,
}) {
  var clauseStart = 0;
  for (var i = match.start - 1; i >= 0; i--) {
    if (boundaries.contains(reason[i])) {
      clauseStart = i + 1;
      break;
    }
  }
  var clauseEnd = reason.length;
  for (var i = match.end; i < reason.length; i++) {
    if (boundaries.contains(reason[i])) {
      clauseEnd = i;
      break;
    }
  }
  return (start: clauseStart, end: clauseEnd);
}
