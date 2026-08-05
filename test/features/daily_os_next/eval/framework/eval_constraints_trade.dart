part of 'eval_constraints.dart';

/// An impossible day has to be named, not quietly absorbed.
///
/// Permitting omissions stops a planner being punished for dropping work it
/// cannot fit — but on its own it also lets one emit a single buffer block,
/// ignore twelve hours of requested work, and score clean. The prompt gives
/// two legitimate ways out: escalate via `raise_day_status`, or state the
/// trade in a block reason. Either satisfies this; silence does not.
EvalConstraintResult scoreSurfacedConflict(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.surfacedConflict;
  if (!outcome.inputs.requiresConflictSurfaced) {
    return const EvalConstraintResult.notApplicable(
      id,
      'the scenario is satisfiable as stated',
    );
  }
  // The tool accepts onTrack and dayClosed too, and attentionNeeded with
  // reasons like processingBlocked that say nothing about this conflict.
  // Matching the call by name alone would let any of those pass.
  final escalated = outcome.toolCalls.any((call) {
    if (!call.accepted || !call.name.contains('raise_day_status')) return false;
    if (call.arguments['status'] != 'attentionNeeded') return false;
    final reasons = switch (call.arguments['reasons']) {
      final List<Object?> list => list.map((r) => '$r').toSet(),
      _ => const <String>{},
    };
    return reasons.any(outcome.inputs.conflictEscalationReasons.contains);
  });
  if (escalated) {
    return const EvalConstraintResult(
      id: id,
      passed: true,
      detail: 'escalated through raise_day_status',
    );
  }
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  // The prompt asks for "which commitments collide and what trade would make
  // it fit", so a bare "Deferred" is not surfacing anything — it names no
  // casualty and gives the user nothing to act on. Require the text to
  // identify at least one piece of work that was actually left out or only
  // partially represented.
  final placed = _placedTaskIds(outcome);
  final shortenedTasks = {
    for (final entry in _estimatedTaskPlacements(outcome).entries)
      if (entry.value.allocatedMinutes < entry.value.estimateMinutes) entry.key,
  };
  final deferred = [
    for (final taskId in outcome.inputs.decidedTaskIds)
      if (!placed.contains(taskId) || shortenedTasks.contains(taskId)) taskId,
  ];
  if (deferred.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'nothing was left out or partially deferred, so there is no trade to name',
    );
  }
  final namedCasualties = [
    for (final taskId in deferred)
      if (_taskTradeIsNamed(outcome, taskId)) taskId,
  ];
  return EvalConstraintResult(
    id: id,
    passed: namedCasualties.isNotEmpty,
    detail: namedCasualties.isNotEmpty
        ? 'named deferred work: ${namedCasualties.join(', ')}'
        : 'absorbed an impossible day without naming a casualty — '
              '${deferred.length} decided task(s) dropped or partially '
              'deferred in silence',
  );
}

typedef _TradeDisclosureEvidence = ({
  Set<String> affirmative,
  Set<String> denied,
  bool retractsAll,
});

_TradeDisclosureEvidence _tradeDisclosureEvidence(
  EvalRunOutcome outcome,
  String taskId,
  String prose,
) {
  final task = outcome.inputs.taskById(taskId);
  if (task == null) {
    return (
      affirmative: <String>{},
      denied: <String>{},
      retractsAll: false,
    );
  }
  final placement = _estimatedTaskPlacements(outcome)[taskId];
  final structuralRemainder = placement == null
      ? task.estimateMinutes
      : placement.estimateMinutes - placement.allocatedMinutes;
  final hasStructuralPartial =
      placement != null &&
      placement.allocatedMinutes > 0 &&
      placement.allocatedMinutes < placement.estimateMinutes;
  final affirmativeEvidence = <String>{};
  final deniedEvidence = <String>{};

  void record(String disposition, {required bool denied}) {
    (denied ? deniedEvidence : affirmativeEvidence).add(disposition);
  }

  void denyAttachedDispositions(Match evidence) {
    final range = _matchClauseRange(prose, evidence, boundaries: ',.;!?\n');
    for (final disposition in _partialTradeDispositionPattern.allMatches(
      prose,
    )) {
      if (disposition.start >= range.start && disposition.end <= range.end) {
        record(_tradeDispositionKey(disposition), denied: true);
      }
    }
  }

  bool belongsToTask(Match match) {
    if (_tradeEvidenceHasCoordinatedTaskSubject(
      prose,
      match,
      taskId: taskId,
      taskTitle: task.title,
      corpus: outcome.inputs.corpus,
    )) {
      return true;
    }
    if (_evidenceFallsInsideTaskReference(
          prose,
          match,
          taskId: taskId,
          taskTitle: task.title,
        ) ||
        _tradeEvidenceHasExplicitNonTaskSubject(
          prose,
          match,
          taskId: taskId,
          taskTitle: task.title,
          corpus: outcome.inputs.corpus,
        )) {
      return false;
    }
    return !_evidenceNamesAnotherTask(
      prose,
      match,
      taskId: taskId,
      taskTitle: task.title,
      corpus: outcome.inputs.corpus,
    );
  }

  bool clauseIsNegated(Match match) => _matchClauseIsNegated(
    prose,
    match,
    taskId: taskId,
    taskTitle: task.title,
    corpus: outcome.inputs.corpus,
  );

  for (final match in _partialMentionPattern.allMatches(prose)) {
    if (!hasStructuralPartial ||
        !belongsToTask(match) ||
        !_partialMentionDescribesPlacement(prose, match) ||
        _evidenceIsSpeculative(prose, match)) {
      continue;
    }
    if (_partialMentionIsNegated(
      prose,
      match,
      taskId: taskId,
      taskTitle: task.title,
    )) {
      record('partial', denied: true);
    } else {
      record('partial', denied: false);
    }
  }
  for (final match in _partialTradeDispositionPattern.allMatches(prose)) {
    if (!belongsToTask(match) ||
        outcome.inputs.now == null &&
            RegExp(
              r'\btomorrow\b',
              caseSensitive: false,
            ).hasMatch(match.group(0) ?? '') ||
        _evidenceHasHistoricalScope(prose, match) ||
        !_tradeEvidenceDescribesTaskOrWork(
          prose,
          match,
          taskId: taskId,
          taskTitle: task.title,
        ) ||
        !_evidenceActionIsAsserted(prose, match.start) ||
        _evidenceIsSpeculative(prose, match)) {
      continue;
    }
    if (clauseIsNegated(match)) {
      record(_tradeDispositionKey(match), denied: true);
    } else {
      record(_tradeDispositionKey(match), denied: false);
    }
  }
  for (final pattern in [
    _partialRemainingPattern,
    _partialLeadingRemainingPattern,
  ]) {
    for (final match in pattern.allMatches(prose)) {
      if (!belongsToTask(match) ||
          _remainderDescribesContinuity(prose, match) ||
          !_remainderIsRelatedToTask(prose, match) ||
          _evidenceIsSpeculative(prose, match) ||
          _unrelatedRemainderScopePattern.hasMatch(
            _matchClause(prose, match),
          )) {
        continue;
      }
      final declaredRemainder = int.tryParse(match.group(1) ?? '');
      if (declaredRemainder == null ||
          declaredRemainder <= 0 ||
          structuralRemainder != null &&
              declaredRemainder != structuralRemainder) {
        record('remainder', denied: true);
        denyAttachedDispositions(match);
        continue;
      }
      if (clauseIsNegated(match)) {
        record('remainder', denied: true);
        denyAttachedDispositions(match);
      } else {
        record('remainder', denied: false);
      }
    }
  }
  for (final match in _conflictTradePattern.allMatches(prose)) {
    if (!belongsToTask(match) ||
        _evidenceHasHistoricalScope(prose, match) ||
        _conflictEvidenceIsObject(prose, match) ||
        !_evidenceActionIsAsserted(prose, match.start) ||
        _evidenceIsSpeculative(prose, match)) {
      continue;
    }
    final matchedTrade = match.group(0) ?? '';
    final hasEmbeddedNegation = _negationWordPattern.hasMatch(matchedTrade);
    final negativeFitDisclosure =
        hasEmbeddedNegation &&
        RegExp(r'\bfit\b', caseSensitive: false).hasMatch(matchedTrade);
    final negativeSchedulingDisclosure =
        RegExp(
          r'\bschedul(?:e|ed|ing)\b',
          caseSensitive: false,
        ).hasMatch(matchedTrade) &&
        (hasEmbeddedNegation ||
            RegExp(
              r'\bunable\s+to\b',
              caseSensitive: false,
            ).hasMatch(matchedTrade));
    if (negativeFitDisclosure) {
      if (!_negativeFitEvidenceDescribesTaskOrWork(
        prose,
        match,
        taskId: taskId,
        taskTitle: task.title,
      )) {
        continue;
      }
      if (_negativeTradeDisclosureIsDenied(prose, match)) {
        record('negative-fit', denied: true);
      } else {
        record('negative-fit', denied: false);
      }
    } else if (negativeSchedulingDisclosure) {
      if (!_tradeEvidenceDescribesTaskOrWork(
        prose,
        match,
        taskId: taskId,
        taskTitle: task.title,
      )) {
        continue;
      }
      record(
        'not-scheduled',
        denied: _negativeTradeDisclosureIsDenied(prose, match),
      );
    } else if (!_tradeEvidenceDescribesTaskOrWork(
      prose,
      match,
      taskId: taskId,
      taskTitle: task.title,
    )) {
      continue;
    } else if (clauseIsNegated(match) ||
        _negativeTradeDisclosureIsDenied(prose, match)) {
      record(_tradeDispositionKey(match), denied: true);
    } else {
      record(_tradeDispositionKey(match), denied: false);
    }
  }
  return (
    affirmative: affirmativeEvidence,
    denied: deniedEvidence,
    retractsAll: _hasTaskBoundFullAllocationClaim(
      prose,
      taskId: taskId,
      taskTitle: task.title,
      corpus: outcome.inputs.corpus,
    ),
  );
}

String _tradeDispositionKey(Match match) {
  final wording = (match.group(0) ?? '').toLowerCase();
  if (wording.contains('partial') || wording.contains('partly')) {
    return 'partial';
  }
  if (wording.contains('defer') || wording.contains('postpon')) {
    return 'deferred';
  }
  if (wording.contains('unfinished')) return 'unfinished';
  if (wording.contains('unscheduled') ||
      wording.contains('omit') ||
      wording.contains('drop') ||
      wording.contains('left')) {
    return 'omitted';
  }
  if (wording.contains('conflict')) return 'conflict';
  if (wording.contains('shorten')) return 'shortened';
  if (wording.contains('roll')) return 'rolled-over';
  if (wording.contains('carr')) return 'carried-over';
  if (wording.contains('move')) return 'moved';
  if (wording.startsWith('for ')) return 'for-later';
  return wording;
}

bool _conflictEvidenceIsObject(String prose, Match match) {
  if (!RegExp(
    r'^conflicts$',
    caseSensitive: false,
  ).hasMatch(match.group(0) ?? '')) {
    return false;
  }
  final range = _matchClauseRange(prose, match, boundaries: ',.;!?\n');
  final prefix = prose.substring(range.start, match.start);
  return RegExp(
    r'\b(?:address(?:es|ed|ing)?|describe(?:s|d|ing)?|'
    'discuss(?:es|ed|ing)?|document(?:s|ed|ing)?|'
    'handle(?:s|d|ing)?|list(?:s|ed|ing)?|mention(?:s|ed|ing)?|'
    r'resolve(?:s|d|ing)?|review(?:s|ed|ing)?|track(?:s|ed|ing)?)\s*$',
    caseSensitive: false,
  ).hasMatch(prefix);
}

bool _tradeEvidenceHasExplicitNonTaskSubject(
  String prose,
  Match evidence, {
  required String taskId,
  required String taskTitle,
  List<EvalCorpusTask> corpus = const [],
}) {
  final range = _matchClauseRange(prose, evidence, boundaries: '.;!?\n');
  final prefix = prose.substring(range.start, evidence.start).trim();
  if (RegExp(
    r'^not\s+only\s+(?:is|are|was|were)$',
    caseSensitive: false,
  ).hasMatch(prefix)) {
    return false;
  }
  if (_subjectStartsWithPossessiveTaskReferenceToNonTaskHead(
    prefix,
    taskId: taskId,
    taskTitle: taskTitle,
  )) {
    return true;
  }
  var rawSubject = prefix;
  for (final complementizer in RegExp(
    r'\bthat\s+',
    caseSensitive: false,
  ).allMatches(prefix)) {
    rawSubject = prefix.substring(complementizer.end).trim();
  }
  final subjectMatch = _tradeSubjectPrefixPattern.firstMatch(prefix);
  if (subjectMatch == null) {
    return _subjectStartsWithExplicitNonTaskHead(rawSubject);
  }
  final subject = subjectMatch.group(1)?.trim() ?? '';
  if (RegExp(
    r'^(?:(?:and|but|yet|so)\s+)?'
    r'(?:(?:the|this|that|its)\s+)?'
    r'(?:task|work|placement|block|remainder|remaining\s+(?:task|work)|'
    r'rest|portion|part|it)\b',
    caseSensitive: false,
  ).hasMatch(subject)) {
    return false;
  }
  if (_subjectStartsWithPossessiveTaskReferenceToNonTaskHead(
    subject,
    taskId: taskId,
    taskTitle: taskTitle,
  )) {
    return true;
  }
  if (_subjectIsOnlyCorpusTaskReferences(subject, corpus)) {
    return false;
  }
  return !_subjectStartsWithTaskReference(
    subject,
    taskId: taskId,
    taskTitle: taskTitle,
  );
}

bool _subjectStartsWithExplicitNonTaskHead(String subject) => RegExp(
  r'^(?:(?:and|but|yet|so)\s+)?'
  r'(?:(?:the|this|that|a|an|its|our|my|your|their)\s+)?'
  '(?:day|meeting|workday|calendar|appointment|break|event|agenda|'
  r'schedule|session)\b',
  caseSensitive: false,
).hasMatch(subject);

bool _tradeEvidenceHasCoordinatedTaskSubject(
  String prose,
  Match evidence, {
  required String taskId,
  required String taskTitle,
  required List<EvalCorpusTask> corpus,
}) {
  final range = _matchClauseRange(prose, evidence, boundaries: '.;!?\n');
  final prefix = prose.substring(range.start, evidence.start).trim();
  final subjectMatch = _tradeSubjectPrefixPattern.firstMatch(prefix);
  final subject = subjectMatch?.group(1)?.trim();
  if (subject == null || !_subjectIsOnlyCorpusTaskReferences(subject, corpus)) {
    return false;
  }
  return _subjectContainsTaskReference(
    subject,
    taskId: taskId,
    taskTitle: taskTitle,
  );
}

bool _subjectIsOnlyCorpusTaskReferences(
  String subject,
  List<EvalCorpusTask> corpus,
) {
  final conjuncts = subject.split(
    RegExp(
      r'\s*(?:,\s*(?:and\s+)?|\s+(?:and|&)\s+)',
      caseSensitive: false,
    ),
  );
  if (conjuncts.length < 2) return false;
  return conjuncts.every((conjunct) {
    return corpus.any(
      (task) => _subjectMatchesTaskReference(
        conjunct,
        taskId: task.taskId,
        taskTitle: task.title,
      ),
    );
  });
}

bool _subjectContainsTaskReference(
  String subject, {
  required String taskId,
  required String taskTitle,
}) {
  return subject
      .split(
        RegExp(
          r'\s*(?:,\s*(?:and\s+)?|\s+(?:and|&)\s+)',
          caseSensitive: false,
        ),
      )
      .any((conjunct) {
        return _subjectMatchesTaskReference(
          conjunct,
          taskId: taskId,
          taskTitle: taskTitle,
        );
      });
}

bool _subjectMatchesTaskReference(
  String subject, {
  required String taskId,
  required String taskTitle,
}) {
  final normalized = subject.trim();
  final title = taskTitle.trim();
  const prefix = r'^(?:(?:the|this|that|its)\s+)?';
  return RegExp(
        prefix + RegExp.escape(taskId) + r'$',
        caseSensitive: false,
      ).hasMatch(normalized) ||
      RegExp(
        prefix + r'task\s+' + RegExp.escape(title) + r'$',
        caseSensitive: false,
      ).hasMatch(normalized) ||
      _allowsBareTaskTitle(title) &&
          RegExp(
            prefix + RegExp.escape(title) + r'$',
            caseSensitive: false,
          ).hasMatch(normalized);
}

bool _subjectStartsWithPossessiveTaskReferenceToNonTaskHead(
  String subject, {
  required String taskId,
  required String taskTitle,
}) {
  final title = taskTitle.trim();
  final taskReferences = [
    RegExp.escape(taskId),
    r'task\s+' + RegExp.escape(title),
    if (_allowsBareTaskTitle(title)) RegExp.escape(title),
  ];
  for (final taskReference in taskReferences) {
    if (RegExp(
      r'^(?:(?:the|this|that|its)\s+)?'
      '$taskReference'
      r'[\x27’]s\s+'
      '(?:day|meeting|workday|calendar|appointment|break|event|'
      r'agenda|schedule|session)\b',
      caseSensitive: false,
    ).hasMatch(subject)) {
      return true;
    }
  }
  return false;
}

bool _subjectStartsWithTaskReference(
  String subject, {
  required String taskId,
  required String taskTitle,
}) {
  const prefix = r'^(?:(?:the|this|that|its)\s+)?';
  const suffix =
      r'(?=$|[\x27’]s\b|\s+(?:task|work|placement|block|remainder|rest|'
      r'portion|part)\b)';
  final title = taskTitle.trim();
  return RegExp(
        prefix + RegExp.escape(taskId) + suffix,
        caseSensitive: false,
      ).hasMatch(subject) ||
      RegExp(
        prefix + r'task\s+' + RegExp.escape(title) + suffix,
        caseSensitive: false,
      ).hasMatch(subject) ||
      RegExp(
        prefix + RegExp.escape(title) + suffix,
        caseSensitive: false,
      ).hasMatch(subject);
}

bool _taskTradeIsNamed(
  EvalRunOutcome outcome,
  String taskId,
) {
  final affirmativeNamedDispositions = <String>{};
  final deniedNamedDispositions = <String>{};
  var retractsAllDispositions = false;
  for (final block in outcome.blocks) {
    for (final disclosure in [block.reason, block.note]) {
      final prose = disclosure?.trim().toLowerCase();
      if (prose == null || prose.isEmpty) continue;
      final namesTask =
          _taskIdNamed(taskId, prose) || _titleNamed(outcome, taskId, prose);
      if (!namesTask) continue;
      final evidence = _tradeDisclosureEvidence(outcome, taskId, prose);
      affirmativeNamedDispositions.addAll(evidence.affirmative);
      deniedNamedDispositions.addAll(evidence.denied);
      retractsAllDispositions |= evidence.retractsAll;
    }
  }
  return !retractsAllDispositions &&
      affirmativeNamedDispositions
          .difference(deniedNamedDispositions)
          .isNotEmpty;
}
