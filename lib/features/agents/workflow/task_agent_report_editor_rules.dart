part of 'task_agent_report_editor.dart';

// The pure text rules behind [TaskAgentReportEditor]: parsing, normalising and validating report sections.

void _addShapeAndAnchorIssues({
  required Set<TaskAgentReportRevisionIssue> issues,
  required Map<String, Object?> materialTaskState,
  required Map<String, dynamic> candidateReport,
  required String normalizedCandidate,
}) {
  if (TaskAgentReportDraft.fromJson(candidateReport) == null) {
    issues.add(TaskAgentReportRevisionIssue.invalidShape);
  }
  for (final MapEntry(:key, :value) in materialTaskState.entries) {
    if (_unstatedAnchorIssue(key, value, normalizedCandidate)
        case final issue?) {
      issues.add(issue);
    }
  }
}

/// The issue for an anchor [key] whose [value] the report does not state,
/// or `null` when it does or [key] is not an anchor.
TaskAgentReportRevisionIssue? _unstatedAnchorIssue(
  String key,
  Object? value,
  String normalizedReport,
) => switch ((key, value)) {
  ('priority', final String priority)
      when priority.trim().isNotEmpty &&
          !normalizedReport.contains(priority.toLowerCase()) =>
    TaskAgentReportRevisionIssue.missingPriority,
  ('dueDate', final String dueDate)
      when !_containsReportDate(normalizedReport, dueDate) =>
    TaskAgentReportRevisionIssue.missingDueDate,
  ('estimateMinutes', final num minutes)
      when !_containsReportEstimate(normalizedReport, minutes) =>
    TaskAgentReportRevisionIssue.missingEstimate,
  _ => null,
};

bool _hasKnownProcessNarration({
  required String normalizedCandidate,
  required bool hasNewChecklistItems,
}) {
  final assignsProgressToNewActions =
      hasNewChecklistItems &&
      RegExp(
        r'\b(these|those|diese[nmrs]?|estos?|estas?|ces)\b.{0,60}'
        r'\b(already\s+|bereits\s+)?'
        r'(marked|markiert|marcad\w*|coch\w*|označ\w*|bifat\w*)\b',
      ).hasMatch(normalizedCandidate);
  final describesNewActionsAsSetup =
      hasNewChecklistItems &&
      RegExp(
        r'\b(these|those|diese[nmrs]?|estos?|estas?|ces)\b.{0,30}'
        r'\b(points?|punkte|items?|actions?|aktionen|acciones)\b.{0,50}'
        r'\b(ready|ahead|pending|zur bearbeitung|pendientes?)\b',
      ).hasMatch(normalizedCandidate);
  final describesNewActionsAsProgress =
      hasNewChecklistItems &&
      RegExp(
        r'\b(work(?:ing)?|task|plan|workflow|actions?|steps?|implementation|'
        'investigation|rotation|migration|deployment|release|evaluation|'
        r'cleanup|fix|stabilisier\w*|export|arbeit(?:en)?|aufgabe|trabajo|'
        r'auftrag\w*|vorbereit\w*|activaci(?:ó|o)n\w*|tarea|travail|tâche|'
        r'muncă|sarcin)\b.{0,50}\b(underway|in progress|'
        'currently active|wurde aufgenommen|l(?:ä|ae)uft(?: aktuell)?|'
        'in bearbeitung|im gange|wird(?: aktuell)? repariert|en curso|'
        'en progreso|'
        r'en progrès|în curs|probíhá)\b',
      ).hasMatch(normalizedCandidate);
  final describesPendingInvestigationAsProgress =
      RegExp(
        r'\binvestigat\w*\b.{0,30}\b(underway|in progress|active)\b',
      ).hasMatch(normalizedCandidate) &&
      RegExp(
        r'\binvestigat\w*\b.{0,45}\b(needed|required|pending|next)\b',
      ).hasMatch(normalizedCandidate);
  final inventsGenericDownstreamFix = RegExp(
    r'\b(additional|further|more)\s+fix(?:es)?\b.{0,50}\b'
    r'(can|could|may|might|will|would)\s+be\s+'
    r'(applied|implemented|validated|deployed)\b',
  ).hasMatch(normalizedCandidate);
  final narratesNewActionsAsQueued =
      hasNewChecklistItems &&
      (RegExp(
            r'\b(workflow\s+items?|actions?|tasks?|steps?|schritte|items?)\b.{0,30}'
            r'\b(queued|queue|listed|captured|prepared|identified|extracted|'
            'defined|recorded|created|added|assembled|tracked|identifiziert|'
            r'erfasst)\b',
          ).hasMatch(normalizedCandidate) ||
          // The same narration with the verb first: "the full workflow is
          // captured as ordered checklist items", "now tracked as checklist
          // items". Measured on glm-5.3-flash, which wrote both; the
          // noun-first pattern above missed the verb-first one.
          RegExp(
            r'\b(queued|listed|captured|recorded|created|added|tracked)\s+'
            r'as\s+(?:\w+\s+){0,2}(items?|steps?|actions?|tasks?)\b',
          ).hasMatch(normalizedCandidate));
  final narratesNewActionsAsReady =
      hasNewChecklistItems &&
      RegExp(
        r'\b(workflow|plan|actions?|tasks?|steps?|work)\b.{0,35}'
        r'\b(?:is|are|looks?|seems?)?\s*ready\b',
      ).hasMatch(normalizedCandidate);
  return assignsProgressToNewActions ||
      describesNewActionsAsSetup ||
      describesNewActionsAsProgress ||
      describesPendingInvestigationAsProgress ||
      inventsGenericDownstreamFix ||
      narratesNewActionsAsQueued ||
      narratesNewActionsAsReady;
}

bool _hasCheckmarkCausality({
  required String languageCode,
  required String normalizedCandidate,
}) {
  final causalFragments = <String>{
    ...TaskAgentReportEditor._causalFragmentsByLanguage['en']!,
    ...?TaskAgentReportEditor._causalFragmentsByLanguage[languageCode],
  };
  if (causalFragments.any(normalizedCandidate.contains)) return true;

  final localizedCheckmarkPattern =
      TaskAgentReportEditor._checkmarkCausalityPatterns[languageCode];
  final checkmarkPatterns = <({String resolution, String checkmark})>{
    TaskAgentReportEditor._checkmarkCausalityPatterns['en']!,
    ?localizedCheckmarkPattern,
  };
  return checkmarkPatterns.any(
    (patterns) => _containsNearbyPatterns(
      normalizedCandidate,
      patterns.resolution,
      patterns.checkmark,
    ),
  );
}

bool _usesFormalRegister(String languageCode, String reportText) {
  return switch (languageCode) {
    'de' =>
      RegExp(r'\bIhr(?:e|en|er|em|es)?\b').hasMatch(reportText) ||
          RegExp(r'\bSie\b')
              .allMatches(reportText)
              .any(
                (match) => !_isSentenceInitial(reportText, match.start),
              ),
    'es' => RegExp(
      r'\b(usted|ustedes)\b',
      caseSensitive: false,
    ).hasMatch(reportText),
    'fr' => RegExp(
      r'\b(vous|votre|vos)\b',
      caseSensitive: false,
    ).hasMatch(reportText),
    _ => false,
  };
}

List<String> _extractExcludedDraftTerms(
  Map<String, dynamic> draftReport,
) {
  final draftText = _reportFieldText(draftReport);
  final terms = <String>{};
  for (final match in TaskAgentReportEditor._scopeClause.allMatches(
    draftText,
  )) {
    final segment = match.group(0)!;
    final markerMatch = TaskAgentReportEditor._excludedScopeMarker.firstMatch(
      segment,
    );
    if (markerMatch == null) continue;
    final beforeMarkerText = segment.substring(0, markerMatch.start);
    final lastComma = beforeMarkerText.lastIndexOf(',');
    final nearbyBeforeText = lastComma == -1
        ? beforeMarkerText
        : beforeMarkerText.substring(lastComma + 1);
    final nearbyBefore = _distinctiveScopeTerms(nearbyBeforeText);
    final afterMarker = _distinctiveScopeTerms(
      segment.substring(markerMatch.end),
    );
    if (nearbyBefore.isNotEmpty) {
      terms.addAll(nearbyBefore);
    } else if (afterMarker.isNotEmpty) {
      terms.addAll(afterMarker);
    } else if (lastComma != -1) {
      final previousComma = beforeMarkerText
          .substring(0, lastComma)
          .lastIndexOf(',');
      terms.addAll(
        _distinctiveScopeTerms(
          beforeMarkerText.substring(previousComma + 1, lastComma),
        ),
      );
    }
  }
  return terms.toList(growable: false)..sort();
}

String _repairInstruction(
  TaskAgentReportRevisionIssue issue,
  Map<String, Object?> materialTaskState,
) {
  if (issue == TaskAgentReportRevisionIssue.missingPriority) {
    final priority = materialTaskState['priority'];
    if (priority is String && priority.trim().isNotEmpty) {
      return 'Include the exact current task priority `${priority.trim()}` '
          'in the report.';
    }
  }
  return issue.correction;
}

bool _inventsWaitingFromUnperformedRequest({
  required Map<String, Object?> materialTaskState,
  required String normalizedCandidate,
}) {
  final candidateAddsWaitingState = RegExp(
    r'\b(await\w*|wait\w*|wart\w*|esper\w*|attend\w*|aștept\w*|ček\w*)\b',
  ).hasMatch(normalizedCandidate);
  if (!candidateAddsWaitingState) return false;

  final checklistItems = _newChecklistItems(materialTaskState);
  for (final item in checklistItems) {
    final normalizedItem = item.trim().toLowerCase();
    if (!TaskAgentReportEditor._requestActionPrefix.hasMatch(normalizedItem)) {
      continue;
    }
    final subjectTerms = TaskAgentReportEditor._distinctiveWord
        .allMatches(normalizedItem)
        .map((match) => match.group(0)!)
        .where(
          (term) =>
              !TaskAgentReportEditor._requestActionStopWords.contains(term),
        );
    if (subjectTerms.any(normalizedCandidate.contains)) return true;
  }
  return false;
}

bool _hasUnperformedRequestItem(
  Map<String, Object?> materialTaskState,
) =>
    _newChecklistItems(
      materialTaskState,
    ).any(
      (item) => TaskAgentReportEditor._requestActionPrefix.hasMatch(
        item.trim().toLowerCase(),
      ),
    );

Iterable<String> _newChecklistItems(
  Map<String, Object?> materialTaskState,
) => switch (materialTaskState['newChecklistItems']) {
  final List<dynamic> items => items.whereType<String>(),
  _ => const Iterable<String>.empty(),
};

Map<String, dynamic> _withoutUngroundedStateClauses(
  Map<String, dynamic> report,
  Map<String, Object?> materialTaskState,
) {
  return {
    for (final field in const ['oneLiner', 'tldr', 'content'])
      field: TaskAgentReportEditor._scopeClause
          .allMatches(report[field] as String? ?? '')
          .map((match) => match.group(0)!)
          .where((clause) {
            final normalizedClause = clause.toLowerCase();
            return !_hasKnownProcessNarration(
                  normalizedCandidate: normalizedClause,
                  hasNewChecklistItems: true,
                ) &&
                !_inventsWaitingFromUnperformedRequest(
                  materialTaskState: materialTaskState,
                  normalizedCandidate: normalizedClause,
                );
          })
          .join()
          .trim(),
  };
}

Map<String, dynamic> _withoutCheckmarkCausalityClauses(
  Map<String, dynamic> report,
  String languageCode,
) {
  return {
    for (final field in const ['oneLiner', 'tldr', 'content'])
      field: TaskAgentReportEditor._scopeClause
          .allMatches(report[field] as String? ?? '')
          .map((match) => match.group(0)!)
          .where((clause) {
            final normalizedClause = clause.toLowerCase();
            return !_hasCheckmarkCausality(
                  languageCode: languageCode,
                  normalizedCandidate: normalizedClause,
                ) &&
                !TaskAgentReportEditor._unsupportedCheckmarkOutcome.hasMatch(
                  normalizedClause,
                ) &&
                !RegExp(r'\b(?:fix|patch)\b').hasMatch(normalizedClause);
          })
          .join()
          .trim(),
  };
}

bool _isSentenceInitial(String text, int wordStart) {
  var index = wordStart - 1;
  while (index >= 0 && (text[index] == ' ' || text[index] == '\t')) {
    index--;
  }
  return index < 0 || '.!?\n\r'.contains(text[index]);
}

List<String> _distinctiveScopeTerms(String text) {
  return TaskAgentReportEditor._distinctiveWord
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .where(
        (term) => !TaskAgentReportEditor._excludedScopeStopWords.contains(term),
      )
      .toList(growable: false);
}

Map<String, dynamic> _withoutExcludedDraftScope(
  Map<String, dynamic> draftReport,
) {
  return {
    for (final field in const ['oneLiner', 'tldr', 'content'])
      field: _withoutExcludedClauses(draftReport[field] as String? ?? ''),
  };
}

String _withoutExcludedClauses(String text) {
  final buffer = StringBuffer();
  for (final match in TaskAgentReportEditor._scopeClause.allMatches(text)) {
    final clause = match.group(0)!;
    if (!TaskAgentReportEditor._excludedScopeMarker.hasMatch(clause)) {
      buffer.write(clause);
    }
  }
  return buffer.toString().trim();
}

bool _containsNearbyPatterns(
  String text,
  String firstPattern,
  String secondPattern,
) {
  return RegExp(
    '(?:$firstPattern).{0,100}(?:$secondPattern)|'
    '(?:$secondPattern).{0,100}(?:$firstPattern)',
  ).hasMatch(text);
}
