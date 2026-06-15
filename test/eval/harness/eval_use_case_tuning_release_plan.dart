import 'eval_provenance.dart';
import 'eval_use_case_runtime_rollout_ledger.dart';
import 'eval_use_case_tuning_decision_ledger.dart';
import 'eval_use_case_tuning_roadmap.dart';

abstract final class EvalUseCaseTuningReleasePlan {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseTuningReleasePlan';
  static const _allowedStatuses = {
    'invalid',
    'blockedRoadmap',
    'blockedContinuity',
    'conflict',
    'rollbackRequired',
    'revalidateRequired',
    'empty',
    'readyForReleaseReview',
  };
  static const _allowedAssignmentStatuses = {
    'pendingReleaseReview',
    'unchanged',
    'supersedesPrevious',
  };
  static const _allowedContinuityStatuses = {
    'unchanged',
    'superseded',
    'rollbackRequired',
    'revalidateRequired',
  };
  static const _runtimeRolloutLedgerKind =
      'lotti.evalUseCaseRuntimeRolloutLedger';
  static const _runtimeRolloutLedgerSchemaVersion = 1;
  static const _allowedReviewCategories = {
    'roadmapIntegrityAudit',
    'runtimeBindingAudit',
    'rollbackAudit',
    'privacyAudit',
  };
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=)/(?:Users|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+|'
    r'EVAL_USE_CASE_[A-Z0-9_]+)\b',
  );
  static final _scenarioFieldTokenPattern = RegExp(
    r'\b(?:scenarioId|scenarioIds|[A-Za-z0-9_]*ScenarioIds)\b',
  );
  static final _profileFieldTokenPattern = RegExp(
    r'\b(?:profileName|profileNames|[A-Za-z0-9_]*ProfileNames)\b',
  );
  static final _liveRunLevel2CommandPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:\./)?eval/run_level2\.sh\s+'
    r'(?:plan|run|tune|all)(?=$|[^A-Za-z0-9_-])',
  );
  static final _dangerousCommandTokenPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:bash\s+-lc|fvm\s+flutter|'
    r'fvm\s+dart|dart\s+run|sqlite3|TaskAgentService\.updateAgentProfile|'
    r'AgentTemplateService\.(?:update|save)|AiConfigRepository\.(?:save|update))'
    r'(?=$|[^A-Za-z0-9_-])',
  );
  static final _publicTokenPattern = RegExp(r'^[A-Za-z0-9._:@+-]{1,96}$');
  static final Expando<String> _verifiedSourceReplayDigests = Expando<String>(
    'evalUseCaseTuningReleasePlanSourceReplayDigest',
  );

  static Map<String, dynamic> build({
    required Map<String, dynamic> roadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    bool requireDecisionLedgerSourceReplay = false,
    bool requirePreviousReleasePlanSourceReplay = false,
    DateTime? generatedAt,
  }) {
    final roadmapIssues = EvalUseCaseTuningRoadmap.validate(roadmap);
    final sourceLedgers = [
      for (final indexed in sourceDecisionLedgers.indexed)
        _SourceDecisionLedger.fromLedger(
          index: indexed.$1,
          ledger: indexed.$2,
          requireSourceReplay: requireDecisionLedgerSourceReplay,
        ),
    ];
    final sourceLedgerIssues = [
      for (final source in sourceLedgers)
        if (!source.valid)
          'sourceDecisionLedgers.${source.ledgerRef} contract invalid',
    ];
    final previousContractIssues = previousReleasePlan == null
        ? const <String>[]
        : validate(previousReleasePlan);
    final previousIssues = [
      ...previousContractIssues,
      if (previousReleasePlan != null &&
          requirePreviousReleasePlanSourceReplay &&
          previousContractIssues.isEmpty &&
          !hasVerifiedSourceReplay(previousReleasePlan))
        'previous release plan source replay must be verified',
    ];
    final previousReleasePlanDigest = previousReleasePlan == null
        ? ''
        : EvalProvenance.digestJson(previousReleasePlan);
    final sourceRuntimeLedgers = [
      for (final indexed in sourceRuntimeRolloutLedgers.indexed)
        _SourceRuntimeRolloutLedger.fromLedger(
          index: indexed.$1,
          ledger: indexed.$2,
        ),
    ];
    final sourceRuntimeLedgerIssues = _sourceRuntimeLedgerIssues(
      sources: sourceRuntimeLedgers,
      previousReleasePlanDigest: previousReleasePlanDigest,
      hasPreviousReleasePlan: previousReleasePlan != null,
    );
    final roadmapDigest = EvalProvenance.digestJson(roadmap);
    final roadmapStatus = _string(roadmap['status']).isEmpty
        ? 'unknown'
        : _string(roadmap['status']);
    final sourceLedgerEvidenceIssues = _sourceLedgerEvidenceIssues(
      roadmap: roadmap,
      roadmapStatus: roadmapStatus,
      sourceLedgers: sourceLedgers,
      requireDecisionLedgerSourceReplay: requireDecisionLedgerSourceReplay,
    );
    final roadmapAccepted =
        roadmapIssues.isEmpty && roadmapStatus == 'accepted';
    final assignments =
        roadmapAccepted &&
            sourceLedgerIssues.isEmpty &&
            sourceLedgerEvidenceIssues.isEmpty
        ? _assignments(
            roadmap: roadmap,
            roadmapDigest: roadmapDigest,
            previousReleasePlan: previousReleasePlan,
          )
        : const <_ReleaseAssignment>[];
    final continuity = previousReleasePlan == null
        ? const <Map<String, dynamic>>[]
        : _continuity(
            previousReleasePlan,
            assignments,
            _runtimeEvidenceByAssignmentRef(
              sources: sourceRuntimeLedgers,
              previousReleasePlanDigest: previousReleasePlanDigest,
            ),
          );
    final decisionLedgerContinuity = _decisionLedgerContinuity(sourceLedgers);
    final modelClassCoverageProofSummary = _modelClassCoverageProofSummary(
      assignments,
    );
    final modelClassCoverageProofSummaryDigest = _string(
      modelClassCoverageProofSummary['proofSummaryDigest'],
    );
    final reviewQueue = _reviewQueue(
      roadmapDigest: roadmapDigest,
      assignments: assignments,
      assignmentProofSummaryCount: _mapList(
        modelClassCoverageProofSummary['entries'],
      ).length,
      assignmentProofSummaryDigest: modelClassCoverageProofSummaryDigest,
      previousReleasePlan: previousReleasePlan,
      continuity: continuity,
      decisionLedgerContinuity: decisionLedgerContinuity,
    );
    final issues = _issues(
      roadmapIssues: roadmapIssues,
      sourceLedgerIssues: sourceLedgerIssues,
      sourceLedgerEvidenceIssues: sourceLedgerEvidenceIssues,
      sourceRuntimeLedgerIssues: sourceRuntimeLedgerIssues,
      previousIssues: previousIssues,
      roadmapStatus: roadmapStatus,
      assignments: assignments,
      continuity: continuity,
      decisionLedgerContinuity: decisionLedgerContinuity,
    );
    final blockedReasonCodes = _blockedReasonCodes(
      issues: issues,
      assignments: assignments,
      continuity: continuity,
      decisionLedgerContinuity: decisionLedgerContinuity,
      reviewQueue: reviewQueue,
    );
    final status = _status(
      roadmapIssues: roadmapIssues,
      sourceLedgerIssues: sourceLedgerIssues,
      sourceLedgerEvidenceIssues: sourceLedgerEvidenceIssues,
      sourceRuntimeLedgerIssues: sourceRuntimeLedgerIssues,
      previousIssues: previousIssues,
      roadmapStatus: roadmapStatus,
      assignments: assignments,
      continuity: continuity,
      decisionLedgerContinuity: decisionLedgerContinuity,
    );
    final releasePlan = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'releasePlanRef': '',
      'sourceRoadmap': <String, dynamic>{
        'kind': EvalUseCaseTuningRoadmap.kind,
        'schemaVersion': EvalUseCaseTuningRoadmap.schemaVersion,
        'status': roadmapStatus,
        'roadmapDigest': roadmapDigest,
        'contractIssueCount': roadmapIssues.length,
        'scopeCount': _map(roadmap['summary'])['scopeCount'] ?? 0,
        'acceptedScopeCount':
            _map(roadmap['summary'])['acceptedScopeCount'] ?? 0,
        'blockedReasonCodes': roadmapIssues.isEmpty
            ? _stringList(roadmap['blockedReasonCodes'])
            : const <String>[],
      },
      'sourceDecisionLedgers': [
        for (final source in sourceLedgers) source.toJson(),
      ],
      'sourceRuntimeRolloutLedgers': [
        for (final source in sourceRuntimeLedgers) source.toJson(),
      ],
      'summary': <String, dynamic>{
        'assignmentCount': assignments.length,
        'pendingReleaseReviewAssignmentCount': assignments
            .where((assignment) => assignment.status == 'pendingReleaseReview')
            .length,
        'unchangedAssignmentCount': assignments
            .where((assignment) => assignment.status == 'unchanged')
            .length,
        'supersedingAssignmentCount': assignments
            .where((assignment) => assignment.status == 'supersedesPrevious')
            .length,
        'previousAssignmentCount': continuity.length,
        'rollbackRequiredCount': _statusCount(
          continuity,
          'rollbackRequired',
        ),
        'revalidateRequiredCount': _statusCount(
          continuity,
          'revalidateRequired',
        ),
        'sourceDecisionLedgerCount': sourceLedgers.length,
        'sourceDecisionLedgerContinuityCount': decisionLedgerContinuity.length,
        'sourceRuntimeRolloutLedgerCount': sourceRuntimeLedgers.length,
        'runtimeAssignmentEvidenceCount': continuity
            .where((entry) => _string(entry['runtimeLedgerRef']).isNotEmpty)
            .length,
        'modelClassCoverageProofSummaryCount': _mapList(
          modelClassCoverageProofSummary['entries'],
        ).length,
        'releaseReviewTaskCount': _mapList(reviewQueue['tasks']).length,
        'blockedReasonCount': blockedReasonCodes.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'localConfigIdsOmitted': true,
        'privateRuntimeIdsOmitted': true,
        'sourceArtifactPathsOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesRoadmapAndOptionalEvidenceLedgersOnly': true,
        'acceptedRoadmapRequiresSourceDecisionLedgers': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'liveCommandsCreated': false,
        'runtimeConfigurationApplied': false,
        'aiConfigMutationsWritten': false,
      },
      'blockedReasonCodes': blockedReasonCodes,
      'runtimeAssignments': [
        for (final assignment in assignments) assignment.toJson(),
      ],
      'modelClassCoverageProofSummary': modelClassCoverageProofSummary,
      'previousAssignmentContinuity': continuity,
      'decisionLedgerContinuityEvidence': decisionLedgerContinuity,
      'releaseReviewQueue': reviewQueue,
      'issues': issues,
      'recommendedCommands': _recommendedCommands(status),
    };
    releasePlan['releasePlanRef'] = releasePlanRef(releasePlan);
    assertValid(releasePlan);
    return releasePlan;
  }

  static List<String> validate(Map<String, dynamic> releasePlan) {
    final issues = <String>[];
    _expectEquals(
      issues,
      releasePlan['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, releasePlan['kind'], kind, 'kind');
    _expectIsoDate(issues, releasePlan['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(
      issues,
      releasePlan['status'],
      'status',
    );
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    _expectDigest(issues, releasePlan['releasePlanRef'], 'releasePlanRef');
    final sourceRoadmap = _expectMap(
      issues,
      releasePlan['sourceRoadmap'],
      'sourceRoadmap',
    );
    _validateSourceRoadmap(issues, sourceRoadmap);
    final sourceDecisionLedgers = _expectList(
      issues,
      releasePlan['sourceDecisionLedgers'],
      'sourceDecisionLedgers',
    );
    _validateSourceDecisionLedgers(issues, sourceDecisionLedgers);
    final sourceRuntimeRolloutLedgers = _expectList(
      issues,
      releasePlan['sourceRuntimeRolloutLedgers'],
      'sourceRuntimeRolloutLedgers',
    );
    _validateSourceRuntimeRolloutLedgers(
      issues,
      sourceRuntimeRolloutLedgers,
    );
    final summary = _expectMap(issues, releasePlan['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(
      issues,
      _expectMap(issues, releasePlan['privacy'], 'privacy'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, releasePlan['limitations'], 'limitations'),
    );
    final blockedReasonCodes = _expectStringList(
      issues,
      releasePlan['blockedReasonCodes'],
      'blockedReasonCodes',
    );
    final assignments = _expectList(
      issues,
      releasePlan['runtimeAssignments'],
      'runtimeAssignments',
    );
    final sourceRoadmapDigest = _string(sourceRoadmap?['roadmapDigest']);
    _validateAssignments(
      issues,
      assignments,
      sourceRoadmapDigest: sourceRoadmapDigest,
    );
    final modelClassCoverageProofSummary = _expectMap(
      issues,
      releasePlan['modelClassCoverageProofSummary'],
      'modelClassCoverageProofSummary',
    );
    _validateModelClassCoverageProofSummary(
      issues,
      modelClassCoverageProofSummary,
      assignments: assignments,
    );
    final continuity = _expectList(
      issues,
      releasePlan['previousAssignmentContinuity'],
      'previousAssignmentContinuity',
    );
    _validateContinuity(issues, continuity);
    _validateContinuityInvariants(
      issues,
      continuity: continuity,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      assignments: assignments,
    );
    final decisionLedgerContinuity = _expectList(
      issues,
      releasePlan['decisionLedgerContinuityEvidence'],
      'decisionLedgerContinuityEvidence',
    );
    _validateDecisionLedgerContinuity(issues, decisionLedgerContinuity);
    _validateReleaseReviewQueue(
      issues,
      _expectMap(
        issues,
        releasePlan['releaseReviewQueue'],
        'releaseReviewQueue',
      ),
      expectedAssignmentRefs: _assignmentRefsFromJson(assignments),
      expectedProofSummaryCount: _mapList(
        modelClassCoverageProofSummary?['entries'],
      ).length,
      expectedProofSummaryDigest: _string(
        modelClassCoverageProofSummary?['proofSummaryDigest'],
      ),
    );
    _validateIssues(
      issues,
      _expectList(issues, releasePlan['issues'], 'issues'),
    );
    _validateCommands(
      issues,
      _expectList(
        issues,
        releasePlan['recommendedCommands'],
        'recommendedCommands',
      ),
      'recommendedCommands',
    );
    _validateSummaryInvariants(
      issues,
      summary: summary,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      assignments: assignments,
      continuity: continuity,
      decisionLedgerContinuity: decisionLedgerContinuity,
      blockedReasonCodes: blockedReasonCodes,
      releaseReviewQueue: _expectMap(
        issues,
        releasePlan['releaseReviewQueue'],
        'releaseReviewQueue',
      ),
      modelClassCoverageProofSummary: modelClassCoverageProofSummary,
    );
    _validateReleasePlanRef(
      issues,
      releasePlan,
    );
    _validateNoPrivatePayloads(issues, releasePlan, 'releasePlan');
    return issues;
  }

  static void assertValid(Map<String, dynamic> releasePlan) {
    final issues = validate(releasePlan);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning release plan:\n${issues.join('\n')}',
    );
  }

  static bool hasVerifiedSourceReplay(Map<String, dynamic> releasePlan) =>
      _verifiedSourceReplayDigests[releasePlan] ==
      EvalProvenance.digestJson(releasePlan);

  static List<String> validateAgainstSources(
    Map<String, dynamic> releasePlan, {
    required Map<String, dynamic> roadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    bool requireDecisionLedgerSourceReplay = false,
    bool requirePreviousReleasePlanSourceReplay = true,
  }) {
    final issues = validate(releasePlan);
    final expected = build(
      roadmap: roadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
      requireDecisionLedgerSourceReplay: requireDecisionLedgerSourceReplay,
      requirePreviousReleasePlanSourceReplay:
          previousReleasePlan != null && requirePreviousReleasePlanSourceReplay,
    );
    if (EvalProvenance.digestJson(_sourceBoundSubject(releasePlan)) !=
        EvalProvenance.digestJson(_sourceBoundSubject(expected))) {
      issues.add('release plan must match source roadmap and ledgers');
    }
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> releasePlan, {
    required Map<String, dynamic> roadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    bool requireDecisionLedgerSourceReplay = false,
    bool requirePreviousReleasePlanSourceReplay = true,
  }) {
    final issues = validateAgainstSources(
      releasePlan,
      roadmap: roadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
      requireDecisionLedgerSourceReplay: requireDecisionLedgerSourceReplay,
      requirePreviousReleasePlanSourceReplay:
          requirePreviousReleasePlanSourceReplay,
    );
    if (issues.isEmpty) {
      _verifiedSourceReplayDigests[releasePlan] = EvalProvenance.digestJson(
        releasePlan,
      );
      return;
    }
    throw StateError(
      'Invalid use-case tuning release plan source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static List<_ReleaseAssignment> _assignments({
    required Map<String, dynamic> roadmap,
    required String roadmapDigest,
    required Map<String, dynamic>? previousReleasePlan,
  }) {
    final previousByScope = {
      for (final assignment in _mapList(
        previousReleasePlan?['runtimeAssignments'],
      ))
        _string(assignment['scopeKey']): assignment,
    };
    final assignments = <_ReleaseAssignment>[];
    for (final scope in _mapList(roadmap['scopes'])) {
      if (_string(scope['status']) != 'accepted') continue;
      final choices = _mapList(scope['acceptedChoices']);
      if (choices.length != 1) continue;
      assignments.add(
        _ReleaseAssignment.fromScope(
          scope: scope,
          choice: choices.single,
          roadmapDigest: roadmapDigest,
          previous: previousByScope[_string(scope['scopeKey'])],
        ),
      );
    }
    return assignments
      ..sort((a, b) => a.assignmentRef.compareTo(b.assignmentRef));
  }

  static List<Map<String, dynamic>> _continuity(
    Map<String, dynamic> previousReleasePlan,
    List<_ReleaseAssignment> assignments,
    Map<String, _RuntimeAssignmentEvidence> runtimeEvidenceByAssignmentRef,
  ) {
    final currentByScope = {
      for (final assignment in assignments) assignment.scopeKey: assignment,
    };
    return [
      for (final previous in _mapList(
        previousReleasePlan['runtimeAssignments'],
      ))
        _continuityEntry(
          previous,
          currentByScope[_string(previous['scopeKey'])],
          runtimeEvidenceByAssignmentRef[_string(previous['assignmentRef'])],
        ),
    ]..sort(
      (a, b) => _string(a['scopeKey']).compareTo(_string(b['scopeKey'])),
    );
  }

  static Map<String, dynamic> _continuityEntry(
    Map<String, dynamic> previous,
    _ReleaseAssignment? current,
    _RuntimeAssignmentEvidence? runtimeEvidence,
  ) {
    final previousRef = _string(previous['assignmentRef']);
    final currentRef = current?.assignmentRef ?? '';
    final status = current == null
        ? 'rollbackRequired'
        : currentRef == previousRef
        ? runtimeEvidence != null && runtimeEvidence.runtimeVerified
              ? 'unchanged'
              : 'revalidateRequired'
        : 'superseded';
    return <String, dynamic>{
      'scopeKey': _string(previous['scopeKey']),
      'previousAssignmentRef': previousRef,
      'currentAssignmentRef': currentRef.isEmpty ? 'missing' : currentRef,
      'status': status,
      if (runtimeEvidence != null) ...runtimeEvidence.toContinuityJson(),
      'blockerCodes': [
        if (status == 'rollbackRequired') 'release.previousAssignmentMissing',
        if (status == 'superseded') 'release.assignmentChanged',
        if (status == 'revalidateRequired')
          ...runtimeEvidence?.blockerCodes ?? const ['runtime.evidenceMissing'],
      ],
    };
  }

  static List<Map<String, dynamic>> _decisionLedgerContinuity(
    List<_SourceDecisionLedger> sources,
  ) {
    final entries = <Map<String, dynamic>>[];
    for (final source in sources.where((source) => source.valid)) {
      for (final entry in _mapList(
        source.ledger['previousDecisionContinuity'],
      )) {
        final status = _string(entry['status']);
        if (status != 'rollbackRequired' &&
            status != 'revalidateRequired' &&
            status != 'unchanged') {
          continue;
        }
        entries.add(<String, dynamic>{
          'ledgerRef': source.ledgerRef,
          'ledgerDigest': source.ledgerDigest,
          'scopeKey': _string(entry['scopeKey']),
          'previousAcceptedCellKey': _string(entry['previousAcceptedCellKey']),
          'status': status,
          'blockerCodes': _stringList(entry['blockerCodes']),
        });
      }
    }
    return entries..sort(
      (a, b) =>
          [
                _string(a['scopeKey']),
                _string(a['ledgerRef']),
                _string(a['status']),
              ]
              .join(':')
              .compareTo(
                [
                  _string(b['scopeKey']),
                  _string(b['ledgerRef']),
                  _string(b['status']),
                ].join(':'),
              ),
    );
  }

  static List<Map<String, dynamic>> _sourceLedgerEvidenceIssues({
    required Map<String, dynamic> roadmap,
    required String roadmapStatus,
    required List<_SourceDecisionLedger> sourceLedgers,
    required bool requireDecisionLedgerSourceReplay,
  }) {
    if (roadmapStatus == 'accepted' && sourceLedgers.isEmpty) {
      return const <Map<String, dynamic>>[
        <String, dynamic>{
          'code': 'release.sourceDecisionLedgerEvidenceMissing',
          'severity': 'blocking',
        },
      ];
    }
    if (roadmapStatus != 'accepted' && sourceLedgers.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final providedByRef = {
      for (final source in sourceLedgers.where((source) => source.valid))
        source.ledgerRef: source.ledgerDigest,
    };
    final sourceBindingIssues = sourceLedgers.isEmpty
        ? const <String>[]
        : EvalUseCaseTuningRoadmap.validateAgainstDecisionLedgers(
            roadmap,
            ledgers: [for (final source in sourceLedgers) source.ledger],
            requireDecisionLedgerSourceReplay:
                requireDecisionLedgerSourceReplay,
          );
    return [
      if (sourceBindingIssues.contains(
        'roadmap must match source decision ledgers',
      ))
        const <String, dynamic>{
          'code': 'release.roadmapSourceDecisionLedgersMismatch',
          'severity': 'blocking',
        },
      for (final source in _mapList(roadmap['sourceLedgers']))
        if (!providedByRef.containsKey(_string(source['ledgerRef'])))
          <String, dynamic>{
            'code': 'release.sourceDecisionLedgerEvidenceMissing',
            'severity': 'blocking',
            'ledgerRef': _string(source['ledgerRef']),
          }
        else if (providedByRef[_string(source['ledgerRef'])] !=
            _string(source['ledgerDigest']))
          <String, dynamic>{
            'code': 'release.sourceDecisionLedgerEvidenceMismatch',
            'severity': 'blocking',
            'ledgerRef': _string(source['ledgerRef']),
          },
    ];
  }

  static List<String> _sourceRuntimeLedgerIssues({
    required List<_SourceRuntimeRolloutLedger> sources,
    required String previousReleasePlanDigest,
    required bool hasPreviousReleasePlan,
  }) {
    final issues = <String>[];
    if (sources.isNotEmpty && !hasPreviousReleasePlan) {
      issues.add(
        'sourceRuntimeRolloutLedgers require EVAL_USE_CASE_PREVIOUS_RELEASE_PLAN',
      );
    }
    final seenAssignmentRefs = <String>{};
    for (final source in sources) {
      if (!source.contractValid) {
        issues.add(
          'sourceRuntimeRolloutLedgers.${source.ledgerRef} contract invalid',
        );
        continue;
      }
      if (!source.sourceVerified) {
        issues.add(
          'sourceRuntimeRolloutLedgers.${source.ledgerRef} source artifacts not verified',
        );
        continue;
      }
      if (source.sourceReleasePlanDigest != previousReleasePlanDigest) {
        issues.add(
          'sourceRuntimeRolloutLedgers.${source.ledgerRef} source release plan digest mismatch',
        );
        continue;
      }
      for (final evidence in source.assignmentEvidence) {
        if (!seenAssignmentRefs.add(evidence.assignmentRef)) {
          issues.add(
            'sourceRuntimeRolloutLedgers duplicate assignment evidence for '
            '${evidence.assignmentRef}',
          );
        }
      }
    }
    return issues;
  }

  static Map<String, _RuntimeAssignmentEvidence>
  _runtimeEvidenceByAssignmentRef({
    required List<_SourceRuntimeRolloutLedger> sources,
    required String previousReleasePlanDigest,
  }) {
    final evidenceByRef = <String, _RuntimeAssignmentEvidence>{};
    for (final source in sources.where(
      (source) =>
          source.valid &&
          source.sourceReleasePlanDigest == previousReleasePlanDigest,
    )) {
      for (final evidence in source.assignmentEvidence) {
        evidenceByRef.putIfAbsent(evidence.assignmentRef, () => evidence);
      }
    }
    return evidenceByRef;
  }

  static Map<String, dynamic> _modelClassCoverageProofSummary(
    List<_ReleaseAssignment> assignments,
  ) {
    final entries = [
      for (final assignment in assignments) assignment.toProofSummaryJson(),
    ];
    return <String, dynamic>{
      'status': entries.isEmpty ? 'empty' : 'ready',
      'assignmentCount': assignments.length,
      'proofSummaryDigest': EvalProvenance.digestJson(entries),
      'entries': entries,
    };
  }

  static Map<String, dynamic> _reviewQueue({
    required String roadmapDigest,
    required List<_ReleaseAssignment> assignments,
    required int assignmentProofSummaryCount,
    required String assignmentProofSummaryDigest,
    required Map<String, dynamic>? previousReleasePlan,
    required List<Map<String, dynamic>> continuity,
    required List<Map<String, dynamic>> decisionLedgerContinuity,
  }) {
    final categories = <String>{
      'roadmapIntegrityAudit',
      'runtimeBindingAudit',
      'privacyAudit',
      if (previousReleasePlan != null ||
          continuity.any((entry) => _string(entry['status']) != 'unchanged') ||
          decisionLedgerContinuity.any(
            (entry) => _string(entry['status']) != 'unchanged',
          ))
        'rollbackAudit',
    };
    final assignmentRefs = [
      for (final assignment in assignments) assignment.assignmentRef,
    ];
    final tasks = [
      for (final category in _sortedStrings(categories))
        <String, dynamic>{
          'reviewRef': EvalProvenance.digestJson(<String, dynamic>{
            'sourceRoadmapDigest': roadmapDigest,
            'category': category,
            'assignmentRefs': assignmentRefs,
            'assignmentProofSummaryDigest': assignmentProofSummaryDigest,
            'modelClassCoverageProofSummaryDigest':
                assignmentProofSummaryDigest,
          }),
          'category': category,
          'required': true,
          'sourceRoadmapDigest': roadmapDigest,
          'assignmentRefs': assignmentRefs,
          'assignmentProofSummaryDigest': assignmentProofSummaryDigest,
          'modelClassCoverageProofSummaryDigest': assignmentProofSummaryDigest,
          'checklist': _reviewChecklist(category),
          'blockerCodes': _reviewBlockers(category),
        },
    ];
    return <String, dynamic>{
      'status': tasks.isEmpty ? 'empty' : 'pending',
      'sourceRoadmapDigest': roadmapDigest,
      'requiredReviewCount': tasks.length,
      'assignmentRefCount': assignmentRefs.length,
      'assignmentProofSummaryCount': assignmentProofSummaryCount,
      'assignmentProofSummaryDigest': assignmentProofSummaryDigest,
      'modelClassCoverageProofSummaryDigest': assignmentProofSummaryDigest,
      'tasks': tasks,
      'attestationTemplates': [
        for (final task in tasks)
          <String, dynamic>{
            'reviewRef': task['reviewRef'],
            'category': task['category'],
            'sourceRoadmapDigest': roadmapDigest,
            'assignmentProofSummaryDigest': assignmentProofSummaryDigest,
            'modelClassCoverageProofSummaryDigest':
                assignmentProofSummaryDigest,
            'status': 'pending',
            'evidenceDigest': '',
          },
      ],
    };
  }

  static List<String> _reviewChecklist(String category) => switch (category) {
    'roadmapIntegrityAudit' => const [
      'Confirm the source roadmap digest and accepted status match the release input.',
      'Confirm every assignment has one accepted choice and no conflict status.',
      'Confirm each assignment carries the accepted decision model-class coverage proof ref.',
      'Confirm the assignment proof-summary digest matches the accepted decision coverage proofs.',
    ],
    'runtimeBindingAudit' => const [
      'Map each public capability and agent kind to the intended app routing surface.',
      'Confirm model class and prompt variant are sufficient for a human config change.',
    ],
    'rollbackAudit' => const [
      'Confirm previous assignments are unchanged, superseded intentionally, or rolled back.',
      'Confirm no missing previous assignment is silently dropped.',
    ],
    _ => const [
      'Confirm the release plan contains no scenario ids, profile names, private paths, env values, or runtime secrets.',
      'Confirm the plan is non-executable and writes no AiConfig mutations.',
    ],
  };

  static List<String> _reviewBlockers(String category) => switch (category) {
    'roadmapIntegrityAudit' => const ['release.review.roadmapIntegrity'],
    'runtimeBindingAudit' => const ['release.review.runtimeBinding'],
    'rollbackAudit' => const ['release.review.rollback'],
    _ => const ['release.review.privacy'],
  };

  static List<Map<String, dynamic>> _issues({
    required List<String> roadmapIssues,
    required List<String> sourceLedgerIssues,
    required List<Map<String, dynamic>> sourceLedgerEvidenceIssues,
    required List<String> sourceRuntimeLedgerIssues,
    required List<String> previousIssues,
    required String roadmapStatus,
    required List<_ReleaseAssignment> assignments,
    required List<Map<String, dynamic>> continuity,
    required List<Map<String, dynamic>> decisionLedgerContinuity,
  }) {
    return [
      for (final issue in roadmapIssues)
        <String, dynamic>{
          'code': 'release.roadmapContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in sourceLedgerIssues)
        <String, dynamic>{
          'code': 'release.sourceDecisionLedgerContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      ...sourceLedgerEvidenceIssues,
      for (final issue in sourceRuntimeLedgerIssues)
        <String, dynamic>{
          'code': 'release.sourceRuntimeRolloutLedgerInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in previousIssues)
        <String, dynamic>{
          'code': 'release.previousPlanContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (roadmapIssues.isEmpty && roadmapStatus != 'accepted')
        <String, dynamic>{
          'code': 'release.roadmapNotAccepted',
          'severity': 'blocking',
          'roadmapStatus': roadmapStatus,
        },
      if (roadmapStatus == 'rollbackRequired' &&
          !decisionLedgerContinuity.any(
            (entry) => _string(entry['status']) == 'rollbackRequired',
          ))
        const <String, dynamic>{
          'code': 'release.rollbackEvidenceMissing',
          'severity': 'blocking',
        },
      if (roadmapStatus == 'revalidateRequired' &&
          !decisionLedgerContinuity.any(
            (entry) => _string(entry['status']) == 'revalidateRequired',
          ))
        const <String, dynamic>{
          'code': 'release.revalidationEvidenceMissing',
          'severity': 'blocking',
        },
      if (roadmapStatus == 'accepted' && assignments.isEmpty)
        const <String, dynamic>{
          'code': 'release.noAcceptedAssignments',
          'severity': 'blocking',
        },
      for (final entry in continuity)
        if (_string(entry['status']) == 'rollbackRequired')
          <String, dynamic>{
            'code': 'release.previousAssignmentMissing',
            'severity': 'blocking',
            'scopeKey': entry['scopeKey'],
          },
      for (final entry in continuity)
        if (_string(entry['status']) == 'revalidateRequired')
          <String, dynamic>{
            'code': 'release.previousRuntimeEvidenceBlocked',
            'severity': 'blocking',
            'scopeKey': entry['scopeKey'],
            'runtimeStatus': entry['runtimeStatus'],
          },
    ];
  }

  static List<String> _blockedReasonCodes({
    required List<Map<String, dynamic>> issues,
    required List<_ReleaseAssignment> assignments,
    required List<Map<String, dynamic>> continuity,
    required List<Map<String, dynamic>> decisionLedgerContinuity,
    required Map<String, dynamic> reviewQueue,
  }) {
    return _sortedStrings({
      for (final issue in issues) _string(issue['code']),
      for (final assignment in assignments) ...assignment.blockerCodes,
      for (final entry in continuity) ..._stringList(entry['blockerCodes']),
      for (final entry in decisionLedgerContinuity)
        ..._stringList(entry['blockerCodes']),
      for (final task in _mapList(reviewQueue['tasks']))
        ..._stringList(task['blockerCodes']),
    });
  }

  static String _status({
    required List<String> roadmapIssues,
    required List<String> sourceLedgerIssues,
    required List<Map<String, dynamic>> sourceLedgerEvidenceIssues,
    required List<String> sourceRuntimeLedgerIssues,
    required List<String> previousIssues,
    required String roadmapStatus,
    required List<_ReleaseAssignment> assignments,
    required List<Map<String, dynamic>> continuity,
    required List<Map<String, dynamic>> decisionLedgerContinuity,
  }) {
    if (roadmapIssues.isNotEmpty ||
        sourceLedgerIssues.isNotEmpty ||
        sourceLedgerEvidenceIssues.isNotEmpty ||
        sourceRuntimeLedgerIssues.isNotEmpty ||
        previousIssues.isNotEmpty) {
      return 'invalid';
    }
    if (roadmapStatus == 'conflict') return 'conflict';
    if (roadmapStatus == 'rollbackRequired') return 'rollbackRequired';
    if (roadmapStatus == 'revalidateRequired') return 'revalidateRequired';
    if (roadmapStatus != 'accepted') return 'blockedRoadmap';
    if (continuity.any(
      (entry) => _string(entry['status']) == 'rollbackRequired',
    )) {
      return 'blockedContinuity';
    }
    if (continuity.any(
      (entry) => _string(entry['status']) == 'revalidateRequired',
    )) {
      return 'revalidateRequired';
    }
    if (decisionLedgerContinuity.any(
      (entry) => _string(entry['status']) == 'rollbackRequired',
    )) {
      return 'rollbackRequired';
    }
    if (assignments.isEmpty) return 'empty';
    return 'readyForReleaseReview';
  }

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final modes = switch (status) {
      'blockedRoadmap' ||
      'blockedContinuity' ||
      'conflict' ||
      'rollbackRequired' => const [
        ('roadmap', 'eval/run_level2.sh roadmap'),
        ('release-plan', 'eval/run_level2.sh release-plan'),
      ],
      'revalidateRequired' => const [
        ('runtime-locator-packet', 'eval/run_level2.sh runtime-locator-packet'),
        ('observe-runtime-state', 'eval/run_level2.sh observe-runtime-state'),
        ('runtime-verify', 'eval/run_level2.sh runtime-verify'),
        ('runtime-ledger', 'eval/run_level2.sh runtime-ledger'),
        ('release-plan', 'eval/run_level2.sh release-plan'),
      ],
      _ => const [
        ('release-plan', 'eval/run_level2.sh release-plan'),
      ],
    };
    return [
      for (final command in modes)
        <String, dynamic>{
          'mode': command.$1,
          'command': command.$2,
        },
    ];
  }

  static void _validateSourceRoadmap(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseTuningRoadmap.kind,
      'sourceRoadmap.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseTuningRoadmap.schemaVersion,
      'sourceRoadmap.schemaVersion',
    );
    _expectNonEmptyString(issues, source['status'], 'sourceRoadmap.status');
    _expectDigest(
      issues,
      source['roadmapDigest'],
      'sourceRoadmap.roadmapDigest',
    );
    for (final field in const [
      'contractIssueCount',
      'scopeCount',
      'acceptedScopeCount',
    ]) {
      _expectNonNegativeInt(issues, source[field], 'sourceRoadmap.$field');
    }
    _expectStringList(
      issues,
      source['blockedReasonCodes'],
      'sourceRoadmap.blockedReasonCodes',
    );
  }

  static void _validateSourceDecisionLedgers(
    List<String> issues,
    List<dynamic>? sourceLedgers,
  ) {
    if (sourceLedgers == null) return;
    for (final (index, value) in sourceLedgers.indexed) {
      final source = _expectMap(issues, value, 'sourceDecisionLedgers[$index]');
      if (source == null) continue;
      _expectNonEmptyString(
        issues,
        source['ledgerRef'],
        'sourceDecisionLedgers[$index].ledgerRef',
      );
      _expectEquals(
        issues,
        source['kind'],
        EvalUseCaseTuningDecisionLedger.kind,
        'sourceDecisionLedgers[$index].kind',
      );
      _expectEquals(
        issues,
        source['schemaVersion'],
        EvalUseCaseTuningDecisionLedger.schemaVersion,
        'sourceDecisionLedgers[$index].schemaVersion',
      );
      _expectNonEmptyString(
        issues,
        source['status'],
        'sourceDecisionLedgers[$index].status',
      );
      _expectDigest(
        issues,
        source['ledgerDigest'],
        'sourceDecisionLedgers[$index].ledgerDigest',
      );
      for (final field in const [
        'contractIssueCount',
        'decisionCount',
        'previousDecisionContinuityCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          source[field],
          'sourceDecisionLedgers[$index].$field',
        );
      }
    }
  }

  static void _validateSourceRuntimeRolloutLedgers(
    List<String> issues,
    List<dynamic>? sourceLedgers,
  ) {
    if (sourceLedgers == null) return;
    for (final (index, value) in sourceLedgers.indexed) {
      final source = _expectMap(
        issues,
        value,
        'sourceRuntimeRolloutLedgers[$index]',
      );
      if (source == null) continue;
      _expectNonEmptyString(
        issues,
        source['ledgerRef'],
        'sourceRuntimeRolloutLedgers[$index].ledgerRef',
      );
      _expectEquals(
        issues,
        source['kind'],
        _runtimeRolloutLedgerKind,
        'sourceRuntimeRolloutLedgers[$index].kind',
      );
      _expectEquals(
        issues,
        source['schemaVersion'],
        _runtimeRolloutLedgerSchemaVersion,
        'sourceRuntimeRolloutLedgers[$index].schemaVersion',
      );
      _expectNonEmptyString(
        issues,
        source['status'],
        'sourceRuntimeRolloutLedgers[$index].status',
      );
      _expectBool(
        issues,
        source['sourceArtifactVerified'],
        'sourceRuntimeRolloutLedgers[$index].sourceArtifactVerified',
      );
      for (final field in const [
        'ledgerDigest',
        'sourceReleasePlanDigest',
      ]) {
        _expectDigest(
          issues,
          source[field],
          'sourceRuntimeRolloutLedgers[$index].$field',
        );
      }
      for (final field in const [
        'contractIssueCount',
        'assignmentCount',
        'blockedAssignmentCount',
        'runtimeVerificationCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          source[field],
          'sourceRuntimeRolloutLedgers[$index].$field',
        );
      }
    }
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'assignmentCount',
      'pendingReleaseReviewAssignmentCount',
      'unchangedAssignmentCount',
      'supersedingAssignmentCount',
      'previousAssignmentCount',
      'rollbackRequiredCount',
      'revalidateRequiredCount',
      'sourceDecisionLedgerCount',
      'sourceDecisionLedgerContinuityCount',
      'sourceRuntimeRolloutLedgerCount',
      'runtimeAssignmentEvidenceCount',
      'modelClassCoverageProofSummaryCount',
      'releaseReviewTaskCount',
      'blockedReasonCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validatePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'rawRunIdsOmitted': true,
      'profileNamesOmitted': true,
      'localConfigIdsOmitted': true,
      'privateRuntimeIdsOmitted': true,
      'sourceArtifactPathsOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        privacy[entry.key],
        entry.value,
        'privacy.${entry.key}',
      );
    }
  }

  static void _validateLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesRoadmapAndOptionalEvidenceLedgersOnly': true,
      'acceptedRoadmapRequiresSourceDecisionLedgers': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'liveCommandsCreated': false,
      'runtimeConfigurationApplied': false,
      'aiConfigMutationsWritten': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        limitations[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
  }

  static void _validateAssignments(
    List<String> issues,
    List<dynamic>? assignments, {
    required String sourceRoadmapDigest,
  }) {
    if (assignments == null) return;
    for (final (index, value) in assignments.indexed) {
      final assignment = _expectMap(
        issues,
        value,
        'runtimeAssignments[$index]',
      );
      if (assignment == null) continue;
      for (final field in const [
        'assignmentRef',
        'scopeKey',
        'compatibilityKey',
        'acceptedCellKey',
        'reportDigest',
        'modelClassCoverageProofRef',
        'modelClassCoverageRef',
        'modelClassCoverageClassRef',
        'workOrderBatchRef',
        'modelClassCoverageDigest',
        'sourceWorkOrderDigest',
        'evidenceDigest',
      ]) {
        _expectDigest(
          issues,
          assignment[field],
          'runtimeAssignments[$index].$field',
        );
      }
      final status = _expectNonEmptyString(
        issues,
        assignment['status'],
        'runtimeAssignments[$index].status',
      );
      if (status != null && !_allowedAssignmentStatuses.contains(status)) {
        issues.add('runtimeAssignments[$index].status must be supported');
      }
      for (final field in const [
        'primaryCapabilityId',
        'agentKind',
        'modelClass',
        'promptVariantName',
      ]) {
        _expectSafePublicToken(
          issues,
          assignment[field],
          'runtimeAssignments[$index].$field',
        );
      }
      for (final field in const [
        'targetSurface',
        'applyState',
      ]) {
        _expectNonEmptyString(
          issues,
          assignment[field],
          'runtimeAssignments[$index].$field',
        );
      }
      _expectStringList(
        issues,
        assignment['sourceLedgerRefs'],
        'runtimeAssignments[$index].sourceLedgerRefs',
      );
      _expectStringList(
        issues,
        assignment['blockerCodes'],
        'runtimeAssignments[$index].blockerCodes',
      );
      final expectedDigest = EvalProvenance.digestJson(
        _assignmentDigestSubject(
          assignment,
          sourceRoadmapDigest: sourceRoadmapDigest,
        ),
      );
      if (assignment['assignmentRef'] != expectedDigest) {
        issues.add(
          'runtimeAssignments[$index].assignmentRef must match proof-bound assignment digest',
        );
      }
      if (assignment['evidenceDigest'] != expectedDigest) {
        issues.add(
          'runtimeAssignments[$index].evidenceDigest must match proof-bound assignment digest',
        );
      }
    }
  }

  static void _validateModelClassCoverageProofSummary(
    List<String> issues,
    Map<String, dynamic>? summary, {
    required List<dynamic>? assignments,
  }) {
    if (summary == null) return;
    final status = _expectNonEmptyString(
      issues,
      summary['status'],
      'modelClassCoverageProofSummary.status',
    );
    if (status != null && !const {'empty', 'ready'}.contains(status)) {
      issues.add('modelClassCoverageProofSummary.status must be supported');
    }
    final count = _expectNonNegativeInt(
      issues,
      summary['assignmentCount'],
      'modelClassCoverageProofSummary.assignmentCount',
    );
    _expectDigest(
      issues,
      summary['proofSummaryDigest'],
      'modelClassCoverageProofSummary.proofSummaryDigest',
    );
    final entries = _expectList(
      issues,
      summary['entries'],
      'modelClassCoverageProofSummary.entries',
    );
    if (entries == null) return;
    if (count != null && count != entries.length) {
      issues.add(
        'modelClassCoverageProofSummary.assignmentCount must match entries length',
      );
    }
    final assignmentSummaries = [
      for (final assignment in _mapList(assignments))
        _assignmentProofSummaryFromJson(assignment),
    ];
    final expectedDigest = EvalProvenance.digestJson(assignmentSummaries);
    if (summary['proofSummaryDigest'] != expectedDigest) {
      issues.add(
        'modelClassCoverageProofSummary.proofSummaryDigest must match entries',
      );
    }
    if (entries.length != assignmentSummaries.length) {
      issues.add(
        'modelClassCoverageProofSummary.entries must match runtime assignments',
      );
    } else {
      for (final (index, entry) in entries.indexed) {
        if (entry is! Map<String, dynamic>) {
          issues.add(
            'modelClassCoverageProofSummary.entries[$index] must be a JSON object',
          );
          continue;
        }
        if (EvalProvenance.digestJson(entry) !=
            EvalProvenance.digestJson(assignmentSummaries[index])) {
          issues.add(
            'modelClassCoverageProofSummary.entries[$index] must match runtimeAssignments[$index] proof summary',
          );
        }
      }
    }
  }

  static void _validateContinuity(List<String> issues, List<dynamic>? entries) {
    if (entries == null) return;
    for (final (index, value) in entries.indexed) {
      final entry = _expectMap(
        issues,
        value,
        'previousAssignmentContinuity[$index]',
      );
      if (entry == null) continue;
      _expectDigest(
        issues,
        entry['scopeKey'],
        'previousAssignmentContinuity[$index].scopeKey',
      );
      _expectDigest(
        issues,
        entry['previousAssignmentRef'],
        'previousAssignmentContinuity[$index].previousAssignmentRef',
      );
      if (entry['currentAssignmentRef'] != 'missing') {
        _expectDigest(
          issues,
          entry['currentAssignmentRef'],
          'previousAssignmentContinuity[$index].currentAssignmentRef',
        );
      }
      final status = _expectNonEmptyString(
        issues,
        entry['status'],
        'previousAssignmentContinuity[$index].status',
      );
      if (status != null && !_allowedContinuityStatuses.contains(status)) {
        issues.add(
          'previousAssignmentContinuity[$index].status must be supported',
        );
      }
      _expectStringList(
        issues,
        entry['blockerCodes'],
        'previousAssignmentContinuity[$index].blockerCodes',
      );
      if (entry.containsKey('runtimeLedgerRef')) {
        _expectNonEmptyString(
          issues,
          entry['runtimeLedgerRef'],
          'previousAssignmentContinuity[$index].runtimeLedgerRef',
        );
      }
      if (entry.containsKey('runtimeLedgerDigest')) {
        _expectDigest(
          issues,
          entry['runtimeLedgerDigest'],
          'previousAssignmentContinuity[$index].runtimeLedgerDigest',
        );
      }
      if (entry.containsKey('runtimeStatus')) {
        _expectNonEmptyString(
          issues,
          entry['runtimeStatus'],
          'previousAssignmentContinuity[$index].runtimeStatus',
        );
      }
      if (entry.containsKey('runtimeVerificationRef')) {
        _expectDigest(
          issues,
          entry['runtimeVerificationRef'],
          'previousAssignmentContinuity[$index].runtimeVerificationRef',
        );
      }
    }
  }

  static void _validateContinuityInvariants(
    List<String> issues, {
    required List<dynamic>? continuity,
    required List<dynamic>? sourceRuntimeRolloutLedgers,
    required List<dynamic>? assignments,
  }) {
    if (continuity == null) return;
    final currentAssignmentRefs = {
      for (final assignment in _mapList(assignments))
        _string(assignment['assignmentRef']),
    };
    final sourceRuntimeLedgersByRef = {
      for (final source in _mapList(sourceRuntimeRolloutLedgers))
        _string(source['ledgerRef']): source,
    };
    for (final (index, entry) in _mapList(continuity).indexed) {
      final previousRef = _string(entry['previousAssignmentRef']);
      final currentRef = _string(entry['currentAssignmentRef']);
      final status = _string(entry['status']);
      final blockerCodes = _stringList(entry['blockerCodes']);
      final runtimeLedgerRef = _string(entry['runtimeLedgerRef']);
      final runtimeLedgerDigest = _string(entry['runtimeLedgerDigest']);
      final runtimeStatus = _string(entry['runtimeStatus']);
      final expectedStatus = currentRef == 'missing'
          ? 'rollbackRequired'
          : currentRef != previousRef
          ? 'superseded'
          : runtimeLedgerRef.isEmpty
          ? 'revalidateRequired'
          : runtimeStatus == 'runtimeVerified'
          ? 'unchanged'
          : 'revalidateRequired';
      if (status != expectedStatus) {
        issues.add(
          'previousAssignmentContinuity[$index].status must match continuity evidence',
        );
      }
      if (currentRef != 'missing' &&
          EvalProvenance.isDigest(currentRef) &&
          !currentAssignmentRefs.contains(currentRef)) {
        issues.add(
          'previousAssignmentContinuity[$index].currentAssignmentRef must reference runtimeAssignments',
        );
      }
      if (status == 'rollbackRequired' &&
          !blockerCodes.contains('release.previousAssignmentMissing')) {
        issues.add(
          'previousAssignmentContinuity[$index].blockerCodes must include release.previousAssignmentMissing',
        );
      }
      if (status == 'superseded' &&
          !blockerCodes.contains('release.assignmentChanged')) {
        issues.add(
          'previousAssignmentContinuity[$index].blockerCodes must include release.assignmentChanged',
        );
      }
      if (status == 'unchanged') {
        if (runtimeLedgerRef.isEmpty || runtimeLedgerDigest.isEmpty) {
          issues.add(
            'previousAssignmentContinuity[$index].unchanged status requires runtime ledger evidence',
          );
        }
        if (runtimeStatus != 'runtimeVerified') {
          issues.add(
            'previousAssignmentContinuity[$index].runtimeStatus must be runtimeVerified when unchanged',
          );
        }
        if (blockerCodes.isNotEmpty) {
          issues.add(
            'previousAssignmentContinuity[$index].blockerCodes must be empty when unchanged',
          );
        }
      }
      if (status == 'revalidateRequired') {
        final expectedBlocker = runtimeLedgerRef.isEmpty
            ? 'runtime.evidenceMissing'
            : runtimeStatus == 'runtimeVerified'
            ? 'runtime.revalidationRequired'
            : '';
        if (expectedBlocker.isNotEmpty &&
            !blockerCodes.contains(expectedBlocker)) {
          issues.add(
            'previousAssignmentContinuity[$index].blockerCodes must include $expectedBlocker',
          );
        }
        if (runtimeLedgerRef.isNotEmpty && blockerCodes.isEmpty) {
          issues.add(
            'previousAssignmentContinuity[$index].blockerCodes must include runtime blockers',
          );
        }
      }
      if (runtimeLedgerRef.isEmpty) continue;
      final source = sourceRuntimeLedgersByRef[runtimeLedgerRef];
      if (source == null) {
        issues.add(
          'previousAssignmentContinuity[$index].runtimeLedgerRef must reference sourceRuntimeRolloutLedgers',
        );
        continue;
      }
      if (_string(source['ledgerDigest']) != runtimeLedgerDigest) {
        issues.add(
          'previousAssignmentContinuity[$index].runtimeLedgerDigest must match sourceRuntimeRolloutLedgers',
        );
      }
    }
  }

  static void _validateDecisionLedgerContinuity(
    List<String> issues,
    List<dynamic>? entries,
  ) {
    if (entries == null) return;
    for (final (index, value) in entries.indexed) {
      final entry = _expectMap(
        issues,
        value,
        'decisionLedgerContinuityEvidence[$index]',
      );
      if (entry == null) continue;
      _expectNonEmptyString(
        issues,
        entry['ledgerRef'],
        'decisionLedgerContinuityEvidence[$index].ledgerRef',
      );
      _expectDigest(
        issues,
        entry['ledgerDigest'],
        'decisionLedgerContinuityEvidence[$index].ledgerDigest',
      );
      _expectDigest(
        issues,
        entry['scopeKey'],
        'decisionLedgerContinuityEvidence[$index].scopeKey',
      );
      _expectDigest(
        issues,
        entry['previousAcceptedCellKey'],
        'decisionLedgerContinuityEvidence[$index].previousAcceptedCellKey',
      );
      final status = _expectNonEmptyString(
        issues,
        entry['status'],
        'decisionLedgerContinuityEvidence[$index].status',
      );
      if (status != null && !_allowedContinuityStatuses.contains(status)) {
        issues.add(
          'decisionLedgerContinuityEvidence[$index].status must be supported',
        );
      }
      _expectStringList(
        issues,
        entry['blockerCodes'],
        'decisionLedgerContinuityEvidence[$index].blockerCodes',
      );
    }
  }

  static void _validateReleaseReviewQueue(
    List<String> issues,
    Map<String, dynamic>? queue, {
    required List<String> expectedAssignmentRefs,
    required int expectedProofSummaryCount,
    required String expectedProofSummaryDigest,
  }) {
    if (queue == null) return;
    _expectNonEmptyString(issues, queue['status'], 'releaseReviewQueue.status');
    _expectDigest(
      issues,
      queue['sourceRoadmapDigest'],
      'releaseReviewQueue.sourceRoadmapDigest',
    );
    _expectDigest(
      issues,
      queue['assignmentProofSummaryDigest'],
      'releaseReviewQueue.assignmentProofSummaryDigest',
    );
    _expectDigest(
      issues,
      queue['modelClassCoverageProofSummaryDigest'],
      'releaseReviewQueue.modelClassCoverageProofSummaryDigest',
    );
    for (final field in const [
      'requiredReviewCount',
      'assignmentRefCount',
      'assignmentProofSummaryCount',
    ]) {
      _expectNonNegativeInt(issues, queue[field], 'releaseReviewQueue.$field');
    }
    if (queue['assignmentRefCount'] is int &&
        queue['assignmentRefCount'] != expectedAssignmentRefs.length) {
      issues.add(
        'releaseReviewQueue.assignmentRefCount must match runtimeAssignments.length',
      );
    }
    if (queue['assignmentProofSummaryCount'] is int &&
        queue['assignmentProofSummaryCount'] != expectedProofSummaryCount) {
      issues.add(
        'releaseReviewQueue.assignmentProofSummaryCount must match model-class coverage proof summary',
      );
    }
    if (queue['assignmentProofSummaryDigest'] != expectedProofSummaryDigest) {
      issues.add(
        'releaseReviewQueue.assignmentProofSummaryDigest must match model-class coverage proof summary',
      );
    }
    if (queue['modelClassCoverageProofSummaryDigest'] !=
        expectedProofSummaryDigest) {
      issues.add(
        'releaseReviewQueue.modelClassCoverageProofSummaryDigest must match model-class coverage proof summary',
      );
    }
    final tasks = _expectList(
      issues,
      queue['tasks'],
      'releaseReviewQueue.tasks',
    );
    if (tasks != null) {
      for (final (index, value) in tasks.indexed) {
        final task = _expectMap(
          issues,
          value,
          'releaseReviewQueue.tasks[$index]',
        );
        if (task == null) continue;
        _expectDigest(
          issues,
          task['reviewRef'],
          'releaseReviewQueue.tasks[$index].reviewRef',
        );
        final category = _expectNonEmptyString(
          issues,
          task['category'],
          'releaseReviewQueue.tasks[$index].category',
        );
        if (category != null && !_allowedReviewCategories.contains(category)) {
          issues.add(
            'releaseReviewQueue.tasks[$index].category must be supported',
          );
        }
        _expectBool(
          issues,
          task['required'],
          'releaseReviewQueue.tasks[$index].required',
        );
        _expectDigest(
          issues,
          task['sourceRoadmapDigest'],
          'releaseReviewQueue.tasks[$index].sourceRoadmapDigest',
        );
        _expectStringList(
          issues,
          task['assignmentRefs'],
          'releaseReviewQueue.tasks[$index].assignmentRefs',
        );
        final assignmentRefs = _stringList(task['assignmentRefs']);
        if (EvalProvenance.digestJson(assignmentRefs) !=
            EvalProvenance.digestJson(expectedAssignmentRefs)) {
          issues.add(
            'releaseReviewQueue.tasks[$index].assignmentRefs must match runtimeAssignments',
          );
        }
        _expectDigest(
          issues,
          task['assignmentProofSummaryDigest'],
          'releaseReviewQueue.tasks[$index].assignmentProofSummaryDigest',
        );
        _expectDigest(
          issues,
          task['modelClassCoverageProofSummaryDigest'],
          'releaseReviewQueue.tasks[$index].modelClassCoverageProofSummaryDigest',
        );
        if (task['assignmentProofSummaryDigest'] !=
            expectedProofSummaryDigest) {
          issues.add(
            'releaseReviewQueue.tasks[$index].assignmentProofSummaryDigest must match model-class coverage proof summary',
          );
        }
        if (task['modelClassCoverageProofSummaryDigest'] !=
            expectedProofSummaryDigest) {
          issues.add(
            'releaseReviewQueue.tasks[$index].modelClassCoverageProofSummaryDigest must match model-class coverage proof summary',
          );
        }
        if (category != null) {
          final expectedReviewRef = EvalProvenance.digestJson(
            <String, dynamic>{
              'sourceRoadmapDigest': task['sourceRoadmapDigest'],
              'category': category,
              'assignmentRefs': assignmentRefs,
              'assignmentProofSummaryDigest':
                  task['assignmentProofSummaryDigest'],
              'modelClassCoverageProofSummaryDigest':
                  task['modelClassCoverageProofSummaryDigest'],
            },
          );
          if (task['reviewRef'] != expectedReviewRef) {
            issues.add(
              'releaseReviewQueue.tasks[$index].reviewRef must match review subject digest',
            );
          }
        }
        _expectStringList(
          issues,
          task['checklist'],
          'releaseReviewQueue.tasks[$index].checklist',
        );
        _expectStringList(
          issues,
          task['blockerCodes'],
          'releaseReviewQueue.tasks[$index].blockerCodes',
        );
        if (task.containsKey('command') || task.containsKey('env')) {
          issues.add('releaseReviewQueue.tasks[$index] must be non-executable');
        }
      }
    }
    final templates = _expectList(
      issues,
      queue['attestationTemplates'],
      'releaseReviewQueue.attestationTemplates',
    );
    if (templates != null) {
      for (final (index, value) in templates.indexed) {
        final template = _expectMap(
          issues,
          value,
          'releaseReviewQueue.attestationTemplates[$index]',
        );
        if (template == null) continue;
        _expectDigest(
          issues,
          template['reviewRef'],
          'releaseReviewQueue.attestationTemplates[$index].reviewRef',
        );
        _expectNonEmptyString(
          issues,
          template['category'],
          'releaseReviewQueue.attestationTemplates[$index].category',
        );
        _expectDigest(
          issues,
          template['sourceRoadmapDigest'],
          'releaseReviewQueue.attestationTemplates[$index].sourceRoadmapDigest',
        );
        _expectDigest(
          issues,
          template['assignmentProofSummaryDigest'],
          'releaseReviewQueue.attestationTemplates[$index].assignmentProofSummaryDigest',
        );
        _expectDigest(
          issues,
          template['modelClassCoverageProofSummaryDigest'],
          'releaseReviewQueue.attestationTemplates[$index].modelClassCoverageProofSummaryDigest',
        );
        if (template['assignmentProofSummaryDigest'] !=
            expectedProofSummaryDigest) {
          issues.add(
            'releaseReviewQueue.attestationTemplates[$index].assignmentProofSummaryDigest must match model-class coverage proof summary',
          );
        }
        if (template['modelClassCoverageProofSummaryDigest'] !=
            expectedProofSummaryDigest) {
          issues.add(
            'releaseReviewQueue.attestationTemplates[$index].modelClassCoverageProofSummaryDigest must match model-class coverage proof summary',
          );
        }
        _expectEquals(
          issues,
          template['status'],
          'pending',
          'releaseReviewQueue.attestationTemplates[$index].status',
        );
        _expectEquals(
          issues,
          template['evidenceDigest'],
          '',
          'releaseReviewQueue.attestationTemplates[$index].evidenceDigest',
        );
      }
    }
  }

  static void _validateIssues(List<String> issues, List<dynamic>? issueList) {
    if (issueList == null) return;
    for (final (index, value) in issueList.indexed) {
      final issue = _expectMap(issues, value, 'issues[$index]');
      if (issue == null) continue;
      _expectNonEmptyString(issues, issue['code'], 'issues[$index].code');
      _expectNonEmptyString(
        issues,
        issue['severity'],
        'issues[$index].severity',
      );
    }
  }

  static void _validateCommands(
    List<String> issues,
    List<dynamic>? commands,
    String path,
  ) {
    if (commands == null) return;
    for (final (index, value) in commands.indexed) {
      final command = _expectMap(issues, value, '$path[$index]');
      if (command == null) continue;
      _expectNonEmptyString(issues, command['mode'], '$path[$index].mode');
      final text = _expectNonEmptyString(
        issues,
        command['command'],
        '$path[$index].command',
      );
      if (text != null && _liveRunLevel2CommandPattern.hasMatch(text)) {
        issues.add(
          '$path[$index].command must not recommend live run commands',
        );
      }
      if (text != null && _dangerousCommandTokenPattern.hasMatch(text)) {
        issues.add(
          '$path[$index].command must not recommend mutation commands',
        );
      }
      if (command.containsKey('env')) {
        issues.add('$path[$index] must not contain env values');
      }
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? sourceDecisionLedgers,
    required List<dynamic>? sourceRuntimeRolloutLedgers,
    required List<dynamic>? assignments,
    required List<dynamic>? continuity,
    required List<dynamic>? decisionLedgerContinuity,
    required List<String>? blockedReasonCodes,
    required Map<String, dynamic>? releaseReviewQueue,
    required Map<String, dynamic>? modelClassCoverageProofSummary,
  }) {
    if (summary == null) return;
    if (assignments != null &&
        summary['assignmentCount'] is int &&
        summary['assignmentCount'] != assignments.length) {
      issues.add(
        'summary.assignmentCount must match runtimeAssignments.length',
      );
    }
    if (sourceDecisionLedgers != null &&
        summary['sourceDecisionLedgerCount'] is int &&
        summary['sourceDecisionLedgerCount'] != sourceDecisionLedgers.length) {
      issues.add(
        'summary.sourceDecisionLedgerCount must match sourceDecisionLedgers.length',
      );
    }
    if (sourceRuntimeRolloutLedgers != null &&
        summary['sourceRuntimeRolloutLedgerCount'] is int &&
        summary['sourceRuntimeRolloutLedgerCount'] !=
            sourceRuntimeRolloutLedgers.length) {
      issues.add(
        'summary.sourceRuntimeRolloutLedgerCount must match sourceRuntimeRolloutLedgers.length',
      );
    }
    if (continuity != null &&
        summary['previousAssignmentCount'] is int &&
        summary['previousAssignmentCount'] != continuity.length) {
      issues.add(
        'summary.previousAssignmentCount must match previousAssignmentContinuity.length',
      );
    }
    if (continuity != null &&
        summary['runtimeAssignmentEvidenceCount'] is int &&
        summary['runtimeAssignmentEvidenceCount'] !=
            continuity
                .where(
                  (entry) =>
                      entry is Map &&
                      _string(entry['runtimeLedgerRef']).isNotEmpty,
                )
                .length) {
      issues.add(
        'summary.runtimeAssignmentEvidenceCount must match runtime evidence continuity entries',
      );
    }
    if (decisionLedgerContinuity != null &&
        summary['sourceDecisionLedgerContinuityCount'] is int &&
        summary['sourceDecisionLedgerContinuityCount'] !=
            decisionLedgerContinuity.length) {
      issues.add(
        'summary.sourceDecisionLedgerContinuityCount must match decisionLedgerContinuityEvidence.length',
      );
    }
    if (blockedReasonCodes != null &&
        summary['blockedReasonCount'] is int &&
        summary['blockedReasonCount'] != blockedReasonCodes.length) {
      issues.add(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      );
    }
    final tasks = _mapList(releaseReviewQueue?['tasks']);
    if (summary['releaseReviewTaskCount'] is int &&
        summary['releaseReviewTaskCount'] != tasks.length) {
      issues.add(
        'summary.releaseReviewTaskCount must match releaseReviewQueue.tasks.length',
      );
    }
    final proofEntries = _mapList(modelClassCoverageProofSummary?['entries']);
    if (summary['modelClassCoverageProofSummaryCount'] is int &&
        summary['modelClassCoverageProofSummaryCount'] != proofEntries.length) {
      issues.add(
        'summary.modelClassCoverageProofSummaryCount must match modelClassCoverageProofSummary.entries.length',
      );
    }
  }

  static void _validateReleasePlanRef(
    List<String> issues,
    Map<String, dynamic> releasePlan,
  ) {
    final expectedRef = releasePlanRef(releasePlan);
    if (releasePlan['releasePlanRef'] != expectedRef) {
      issues.add('releasePlanRef must match release plan subject digest');
    }
  }

  static String releasePlanRef(Map<String, dynamic> releasePlan) {
    final sourceRoadmap = _map(releasePlan['sourceRoadmap']);
    final proofSummary = _map(releasePlan['modelClassCoverageProofSummary']);
    return EvalProvenance.digestJson(<String, dynamic>{
      'kind': kind,
      'schemaVersion': schemaVersion,
      'status': _string(releasePlan['status']),
      'sourceRoadmapDigest': _string(sourceRoadmap['roadmapDigest']),
      'sourceRoadmapSummaryDigest': EvalProvenance.digestJson(sourceRoadmap),
      'sourceDecisionLedgersDigest': EvalProvenance.digestJson(
        _mapList(releasePlan['sourceDecisionLedgers']),
      ),
      'assignmentRefs': _assignmentRefsFromJson(
        _mapList(releasePlan['runtimeAssignments']),
      ),
      'modelClassCoverageProofSummaryDigest': _string(
        proofSummary['proofSummaryDigest'],
      ),
      'sourceRuntimeRolloutLedgersDigest': EvalProvenance.digestJson(
        _mapList(releasePlan['sourceRuntimeRolloutLedgers']),
      ),
      'previousAssignmentContinuityDigest': EvalProvenance.digestJson(
        _mapList(releasePlan['previousAssignmentContinuity']),
      ),
      'blockedReasonCodes': _stringList(releasePlan['blockedReasonCodes']),
      'issuesDigest': EvalProvenance.digestJson(
        _mapList(releasePlan['issues']),
      ),
    });
  }

  static Map<String, dynamic> _sourceBoundSubject(
    Map<String, dynamic> releasePlan,
  ) => <String, dynamic>{
    'schemaVersion': releasePlan['schemaVersion'],
    'kind': releasePlan['kind'],
    'status': releasePlan['status'],
    'releasePlanRef': releasePlan['releasePlanRef'],
    'sourceRoadmap': releasePlan['sourceRoadmap'],
    'sourceDecisionLedgers': _mapList(releasePlan['sourceDecisionLedgers']),
    'sourceRuntimeRolloutLedgers': _mapList(
      releasePlan['sourceRuntimeRolloutLedgers'],
    ),
    'summary': releasePlan['summary'],
    'privacy': releasePlan['privacy'],
    'limitations': releasePlan['limitations'],
    'blockedReasonCodes': _stringList(releasePlan['blockedReasonCodes']),
    'runtimeAssignments': _mapList(releasePlan['runtimeAssignments']),
    'modelClassCoverageProofSummary':
        releasePlan['modelClassCoverageProofSummary'],
    'previousAssignmentContinuity': _mapList(
      releasePlan['previousAssignmentContinuity'],
    ),
    'decisionLedgerContinuityEvidence': _mapList(
      releasePlan['decisionLedgerContinuityEvidence'],
    ),
    'releaseReviewQueue': releasePlan['releaseReviewQueue'],
    'issues': _mapList(releasePlan['issues']),
    'recommendedCommands': _mapList(releasePlan['recommendedCommands']),
  };

  static List<String> _assignmentRefsFromJson(List<dynamic>? assignments) => [
    for (final assignment in _mapList(assignments))
      _string(assignment['assignmentRef']),
  ];

  static Map<String, dynamic> _assignmentDigestSubject(
    Map<String, dynamic> assignment, {
    required String sourceRoadmapDigest,
  }) => <String, dynamic>{
    'sourceRoadmapDigest': sourceRoadmapDigest,
    'scopeKey': _string(assignment['scopeKey']),
    'acceptedCellKey': _string(assignment['acceptedCellKey']),
    'reportDigest': _string(assignment['reportDigest']),
    'modelClassCoverageProofRef': _string(
      assignment['modelClassCoverageProofRef'],
    ),
    'workOrderBatchRef': _string(assignment['workOrderBatchRef']),
    'modelClassCoverageRef': _string(
      assignment['modelClassCoverageRef'],
    ),
    'modelClassCoverageClassRef': _string(
      assignment['modelClassCoverageClassRef'],
    ),
    'modelClassCoverageDigest': _string(
      assignment['modelClassCoverageDigest'],
    ),
    'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
    'modelClass': _string(assignment['modelClass']),
    'promptVariantName': _string(assignment['promptVariantName']),
  };

  static Map<String, dynamic> _assignmentProofSummaryFromJson(
    Map<String, dynamic> assignment,
  ) => <String, dynamic>{
    'assignmentRef': _string(assignment['assignmentRef']),
    'scopeKey': _string(assignment['scopeKey']),
    'primaryCapabilityId': _string(assignment['primaryCapabilityId']),
    'agentKind': _string(assignment['agentKind']),
    'modelClass': _string(assignment['modelClass']),
    'promptVariantName': _string(assignment['promptVariantName']),
    'acceptedCellKey': _string(assignment['acceptedCellKey']),
    'reportDigest': _string(assignment['reportDigest']),
    'modelClassCoverageProofRef': _string(
      assignment['modelClassCoverageProofRef'],
    ),
    'workOrderBatchRef': _string(assignment['workOrderBatchRef']),
    'modelClassCoverageRef': _string(
      assignment['modelClassCoverageRef'],
    ),
    'modelClassCoverageClassRef': _string(
      assignment['modelClassCoverageClassRef'],
    ),
    'modelClassCoverageDigest': _string(
      assignment['modelClassCoverageDigest'],
    ),
    'sourceWorkOrderDigest': _string(assignment['sourceWorkOrderDigest']),
  };

  static void _validateNoPrivatePayloads(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (_privateFieldReason(normalized) case final reason?) {
          issues.add('$path.$key must not expose $reason');
        }
        _validateNoPrivatePayloads(issues, entry.value, '$path.$key');
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoPrivatePayloads(issues, item, '$path[$index]');
      }
      return;
    }
    if (value is String) {
      if (_privatePathPattern.hasMatch(value)) {
        issues.add('$path must not contain private paths');
      }
      if (_privateEnvTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain private env value keys');
      }
      if (_liveRunLevel2CommandPattern.hasMatch(value)) {
        issues.add('$path must not contain live run commands');
      }
      if (_dangerousCommandTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain mutation commands');
      }
      if (value.contains('<redacted-scenario')) {
        issues.add('$path must not contain redacted scenario placeholders');
      }
      if (_scenarioFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain scenario id field names');
      }
      if (_profileFieldTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain profile selector field names');
      }
    }
  }

  static String? _privateFieldReason(String normalized) {
    if (normalized == 'scenarioid' ||
        normalized == 'scenarioids' ||
        normalized.endsWith('scenarioids')) {
      return 'scenario ids';
    }
    if (normalized == 'profilename' ||
        normalized == 'profilenames' ||
        normalized.endsWith('profilenames')) {
      return 'profile selectors';
    }
    if (normalized == 'runid' ||
        normalized == 'baserunid' ||
        normalized.endsWith('runid')) {
      return 'run ids';
    }
    if (normalized == 'localconfigid' ||
        normalized == 'modelconfigid' ||
        normalized == 'profileid' ||
        normalized == 'agentid' ||
        normalized == 'taskid' ||
        normalized == 'templateid' ||
        normalized == 'categoryid' ||
        normalized == 'providerid' ||
        normalized.endsWith('configid')) {
      return 'private runtime ids';
    }
    return null;
  }

  static Map<String, dynamic>? _expectMap(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map<String, dynamic>) return value;
    issues.add('$path must be a JSON object');
    return null;
  }

  static List<dynamic>? _expectList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is List<dynamic>) return value;
    issues.add('$path must be a list');
    return null;
  }

  static List<String>? _expectStringList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! List) {
      issues.add('$path must be a list');
      return null;
    }
    final strings = <String>[];
    for (final (index, item) in value.indexed) {
      if (item is String) {
        strings.add(item);
      } else {
        issues.add('$path[$index] must be a string');
      }
    }
    return strings;
  }

  static String? _expectNonEmptyString(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is String && value.trim().isNotEmpty) return value;
    issues.add('$path must be a non-empty string');
    return null;
  }

  static void _expectSafePublicToken(
    List<String> issues,
    Object? value,
    String path,
  ) {
    final text = _expectNonEmptyString(issues, value, path);
    if (text == null) return;
    if (!_publicTokenPattern.hasMatch(text)) {
      issues.add('$path must be a safe public token');
    }
    if (_liveRunLevel2CommandPattern.hasMatch(text) ||
        _dangerousCommandTokenPattern.hasMatch(text)) {
      issues.add('$path must not contain executable command text');
    }
  }

  static void _expectDigest(List<String> issues, Object? value, String path) {
    final digest = _expectNonEmptyString(issues, value, path);
    if (digest != null && !EvalProvenance.isDigest(digest)) {
      issues.add('$path must be a sha256 digest');
    }
  }

  static void _expectIsoDate(List<String> issues, Object? value, String path) {
    final text = _expectNonEmptyString(issues, value, path);
    if (text == null) return;
    try {
      DateTime.parse(text);
    } on FormatException {
      issues.add('$path must be an ISO-8601 timestamp');
    }
  }

  static int? _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is int && value >= 0) return value;
    issues.add('$path must be a non-negative integer');
    return null;
  }

  static void _expectBool(List<String> issues, Object? value, String path) {
    if (value is bool) return;
    issues.add('$path must be a boolean');
  }

  static void _expectEquals(
    List<String> issues,
    Object? value,
    Object? expected,
    String path,
  ) {
    if (value == expected) return;
    issues.add('$path must be $expected');
  }
}

final class _ReleaseAssignment {
  const _ReleaseAssignment({
    required this.assignmentRef,
    required this.status,
    required this.scopeKey,
    required this.compatibilityKey,
    required this.primaryCapabilityId,
    required this.agentKind,
    required this.modelClass,
    required this.promptVariantName,
    required this.acceptedCellKey,
    required this.reportDigest,
    required this.modelClassCoverageProofRef,
    required this.workOrderBatchRef,
    required this.modelClassCoverageRef,
    required this.modelClassCoverageClassRef,
    required this.modelClassCoverageDigest,
    required this.sourceWorkOrderDigest,
    required this.sourceLedgerRefs,
    required this.evidenceDigest,
    required this.blockerCodes,
  });

  factory _ReleaseAssignment.fromScope({
    required Map<String, dynamic> scope,
    required Map<String, dynamic> choice,
    required String roadmapDigest,
    required Map<String, dynamic>? previous,
  }) {
    final subject = <String, dynamic>{
      'sourceRoadmapDigest': roadmapDigest,
      'scopeKey': _string(scope['scopeKey']),
      'acceptedCellKey': _string(choice['acceptedCellKey']),
      'reportDigest': _string(choice['reportDigest']),
      'modelClassCoverageProofRef': _string(
        choice['modelClassCoverageProofRef'],
      ),
      'workOrderBatchRef': _string(choice['workOrderBatchRef']),
      'modelClassCoverageRef': _string(choice['modelClassCoverageRef']),
      'modelClassCoverageClassRef': _string(
        choice['modelClassCoverageClassRef'],
      ),
      'modelClassCoverageDigest': _string(choice['modelClassCoverageDigest']),
      'sourceWorkOrderDigest': _string(choice['sourceWorkOrderDigest']),
      'modelClass': _string(choice['modelClass']),
      'promptVariantName': _string(choice['promptVariantName']),
    };
    final assignmentRef = EvalProvenance.digestJson(subject);
    final previousRef = _string(previous?['assignmentRef']);
    final status = previous == null
        ? 'pendingReleaseReview'
        : previousRef == assignmentRef
        ? 'unchanged'
        : 'supersedesPrevious';
    return _ReleaseAssignment(
      assignmentRef: assignmentRef,
      status: status,
      scopeKey: _string(scope['scopeKey']),
      compatibilityKey: _string(scope['compatibilityKey']),
      primaryCapabilityId: _string(scope['primaryCapabilityId']),
      agentKind: _string(scope['agentKind']),
      modelClass: _string(choice['modelClass']),
      promptVariantName: _string(choice['promptVariantName']),
      acceptedCellKey: _string(choice['acceptedCellKey']),
      reportDigest: _string(choice['reportDigest']),
      modelClassCoverageProofRef: _string(choice['modelClassCoverageProofRef']),
      workOrderBatchRef: _string(choice['workOrderBatchRef']),
      modelClassCoverageRef: _string(choice['modelClassCoverageRef']),
      modelClassCoverageClassRef: _string(
        choice['modelClassCoverageClassRef'],
      ),
      modelClassCoverageDigest: _string(choice['modelClassCoverageDigest']),
      sourceWorkOrderDigest: _string(choice['sourceWorkOrderDigest']),
      sourceLedgerRefs: _stringList(choice['sourceLedgerRefs']),
      evidenceDigest: EvalProvenance.digestJson(subject),
      blockerCodes: [
        'release.reviewRequired',
        if (status == 'supersedesPrevious') 'release.assignmentChanged',
      ],
    );
  }

  final String assignmentRef;
  final String status;
  final String scopeKey;
  final String compatibilityKey;
  final String primaryCapabilityId;
  final String agentKind;
  final String modelClass;
  final String promptVariantName;
  final String acceptedCellKey;
  final String reportDigest;
  final String modelClassCoverageProofRef;
  final String workOrderBatchRef;
  final String modelClassCoverageRef;
  final String modelClassCoverageClassRef;
  final String modelClassCoverageDigest;
  final String sourceWorkOrderDigest;
  final List<String> sourceLedgerRefs;
  final String evidenceDigest;
  final List<String> blockerCodes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'assignmentRef': assignmentRef,
    'status': status,
    'scopeKey': scopeKey,
    'compatibilityKey': compatibilityKey,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
    'acceptedCellKey': acceptedCellKey,
    'reportDigest': reportDigest,
    'modelClassCoverageProofRef': modelClassCoverageProofRef,
    'workOrderBatchRef': workOrderBatchRef,
    'modelClassCoverageRef': modelClassCoverageRef,
    'modelClassCoverageClassRef': modelClassCoverageClassRef,
    'modelClassCoverageDigest': modelClassCoverageDigest,
    'sourceWorkOrderDigest': sourceWorkOrderDigest,
    'sourceLedgerRefs': sourceLedgerRefs,
    'evidenceDigest': evidenceDigest,
    'targetSurface': 'agentInferenceRouting',
    'applyState': 'notApplied',
    'blockerCodes': blockerCodes,
  };

  Map<String, dynamic> toProofSummaryJson() => <String, dynamic>{
    'assignmentRef': assignmentRef,
    'scopeKey': scopeKey,
    'primaryCapabilityId': primaryCapabilityId,
    'agentKind': agentKind,
    'modelClass': modelClass,
    'promptVariantName': promptVariantName,
    'acceptedCellKey': acceptedCellKey,
    'reportDigest': reportDigest,
    'modelClassCoverageProofRef': modelClassCoverageProofRef,
    'workOrderBatchRef': workOrderBatchRef,
    'modelClassCoverageRef': modelClassCoverageRef,
    'modelClassCoverageClassRef': modelClassCoverageClassRef,
    'modelClassCoverageDigest': modelClassCoverageDigest,
    'sourceWorkOrderDigest': sourceWorkOrderDigest,
  };
}

final class _SourceDecisionLedger {
  _SourceDecisionLedger({
    required this.ledgerRef,
    required this.ledger,
    required this.ledgerDigest,
    required this.contractIssues,
  });

  factory _SourceDecisionLedger.fromLedger({
    required int index,
    required Map<String, dynamic> ledger,
    bool requireSourceReplay = false,
  }) {
    final ledgerContractIssues = EvalUseCaseTuningDecisionLedger.validate(
      ledger,
    );
    final contractIssues = [
      ...ledgerContractIssues,
      if (requireSourceReplay &&
          ledgerContractIssues.isEmpty &&
          !EvalUseCaseTuningDecisionLedger.hasVerifiedSourceReplay(ledger))
        'decision ledger source replay must be verified',
    ];
    final decisionLedgerRef = _string(ledger['decisionLedgerRef']);
    return _SourceDecisionLedger(
      ledgerRef:
          contractIssues.isEmpty && EvalProvenance.isDigest(decisionLedgerRef)
          ? decisionLedgerRef
          : 'ledger-${(index + 1).toString().padLeft(4, '0')}',
      ledger: ledger,
      ledgerDigest: EvalProvenance.digestJson(ledger),
      contractIssues: contractIssues,
    );
  }

  final String ledgerRef;
  final Map<String, dynamic> ledger;
  final String ledgerDigest;
  final List<String> contractIssues;

  bool get valid => contractIssues.isEmpty;

  Map<String, dynamic> toJson() {
    final decisions = valid
        ? _mapList(ledger['decisions'])
        : const <Map<String, dynamic>>[];
    final continuity = valid
        ? _mapList(ledger['previousDecisionContinuity'])
        : const <Map<String, dynamic>>[];
    return <String, dynamic>{
      'ledgerRef': ledgerRef,
      'kind': EvalUseCaseTuningDecisionLedger.kind,
      'schemaVersion': EvalUseCaseTuningDecisionLedger.schemaVersion,
      'status': valid ? _string(ledger['status']) : 'invalid',
      'ledgerDigest': ledgerDigest,
      'contractIssueCount': contractIssues.length,
      'decisionCount': decisions.length,
      'previousDecisionContinuityCount': continuity.length,
    };
  }
}

final class _SourceRuntimeRolloutLedger {
  _SourceRuntimeRolloutLedger({
    required this.ledgerRef,
    required this.ledger,
    required this.ledgerDigest,
    required this.contractIssues,
    required this.sourceVerified,
  });

  factory _SourceRuntimeRolloutLedger.fromLedger({
    required int index,
    required Map<String, dynamic> ledger,
  }) {
    final rolloutLedgerRef = _string(ledger['rolloutLedgerRef']);
    return _SourceRuntimeRolloutLedger(
      ledgerRef: EvalProvenance.isDigest(rolloutLedgerRef)
          ? rolloutLedgerRef
          : 'runtime-ledger-${(index + 1).toString().padLeft(4, '0')}',
      ledger: ledger,
      ledgerDigest: EvalProvenance.digestJson(ledger),
      contractIssues: _runtimeRolloutLedgerContractIssues(ledger),
      sourceVerified: EvalUseCaseRuntimeRolloutLedger.hasVerifiedSources(
        ledger,
      ),
    );
  }

  final String ledgerRef;
  final Map<String, dynamic> ledger;
  final String ledgerDigest;
  final List<String> contractIssues;
  final bool sourceVerified;

  bool get contractValid => contractIssues.isEmpty;
  bool get valid => contractValid && sourceVerified;

  String get sourceReleasePlanDigest {
    final digest = _string(
      _map(ledger['sourceReleasePlan'])['releasePlanDigest'],
    );
    return EvalProvenance.isDigest(digest) ? digest : ledgerDigest;
  }

  List<_RuntimeAssignmentEvidence> get assignmentEvidence {
    if (!valid) return const <_RuntimeAssignmentEvidence>[];
    return [
      for (final row in _mapList(ledger['assignments']))
        _RuntimeAssignmentEvidence.fromAssignment(
          source: this,
          assignment: row,
        ),
    ];
  }

  Map<String, dynamic> toJson() {
    final evidence = assignmentEvidence;
    return <String, dynamic>{
      'ledgerRef': ledgerRef,
      'kind': EvalUseCaseTuningReleasePlan._runtimeRolloutLedgerKind,
      'schemaVersion':
          EvalUseCaseTuningReleasePlan._runtimeRolloutLedgerSchemaVersion,
      'status': valid ? _string(ledger['status']) : 'invalid',
      'sourceArtifactVerified': sourceVerified,
      'ledgerDigest': ledgerDigest,
      'sourceReleasePlanDigest': sourceReleasePlanDigest,
      'contractIssueCount': contractIssues.length,
      'assignmentCount': evidence.length,
      'blockedAssignmentCount': evidence
          .where((assignment) => !assignment.runtimeVerified)
          .length,
      'runtimeVerificationCount': _runtimeVerificationCount(ledger),
    };
  }
}

final class _RuntimeAssignmentEvidence {
  const _RuntimeAssignmentEvidence({
    required this.ledgerRef,
    required this.ledgerDigest,
    required this.assignmentRef,
    required this.runtimeStatus,
    required this.runtimeVerificationRef,
    required this.blockerCodes,
  });

  factory _RuntimeAssignmentEvidence.fromAssignment({
    required _SourceRuntimeRolloutLedger source,
    required Map<String, dynamic> assignment,
  }) {
    final runtimeStatus = _string(assignment['runtimeStatus']);
    final blockerCodes = _stringList(assignment['blockerCodes']);
    return _RuntimeAssignmentEvidence(
      ledgerRef: source.ledgerRef,
      ledgerDigest: source.ledgerDigest,
      assignmentRef: _string(assignment['assignmentRef']),
      runtimeStatus: runtimeStatus,
      runtimeVerificationRef: _string(assignment['runtimeVerificationRef']),
      blockerCodes: runtimeStatus == 'runtimeVerified'
          ? const <String>[]
          : blockerCodes.isEmpty
          ? const ['runtime.revalidationRequired']
          : blockerCodes,
    );
  }

  final String ledgerRef;
  final String ledgerDigest;
  final String assignmentRef;
  final String runtimeStatus;
  final String runtimeVerificationRef;
  final List<String> blockerCodes;

  bool get runtimeVerified => runtimeStatus == 'runtimeVerified';

  Map<String, dynamic> toContinuityJson() => <String, dynamic>{
    'runtimeLedgerRef': ledgerRef,
    'runtimeLedgerDigest': ledgerDigest,
    'runtimeStatus': runtimeStatus,
    'runtimeVerificationRef': runtimeVerificationRef,
  };
}

List<String> _runtimeRolloutLedgerContractIssues(
  Map<String, dynamic> ledger,
) {
  final issues = EvalUseCaseRuntimeRolloutLedger.validate(ledger);
  if (ledger['schemaVersion'] !=
      EvalUseCaseTuningReleasePlan._runtimeRolloutLedgerSchemaVersion) {
    issues.add('schemaVersion must match runtime rollout ledger schema');
  }
  if (ledger['kind'] !=
      EvalUseCaseTuningReleasePlan._runtimeRolloutLedgerKind) {
    issues.add('kind must be runtime rollout ledger');
  }
  final status = _string(ledger['status']);
  if (status != 'verified' && status != 'blocked') {
    issues.add('status must be verified or blocked');
  }
  final sourceReleasePlan = _map(ledger['sourceReleasePlan']);
  final sourceReleasePlanDigest = _string(
    sourceReleasePlan['releasePlanDigest'],
  );
  if (!EvalProvenance.isDigest(sourceReleasePlanDigest)) {
    issues.add('sourceReleasePlan.releasePlanDigest must be a sha256 digest');
  }
  final assignments = _mapList(ledger['assignments']);
  if (assignments.isEmpty) {
    issues.add('assignments must contain runtime evidence');
  }
  final seenAssignmentRefs = <String>{};
  for (final (index, assignment) in assignments.indexed) {
    final assignmentRef = _string(assignment['assignmentRef']);
    if (!EvalProvenance.isDigest(assignmentRef)) {
      issues.add('assignments[$index].assignmentRef must be a sha256 digest');
    } else if (!seenAssignmentRefs.add(assignmentRef)) {
      issues.add('assignments[$index].assignmentRef must be unique');
    }
    final runtimeStatus = _string(assignment['runtimeStatus']);
    if (runtimeStatus != 'runtimeVerified' &&
        runtimeStatus != 'notApplied' &&
        runtimeStatus != 'drift' &&
        runtimeStatus != 'invalid') {
      issues.add('assignments[$index].runtimeStatus must be supported');
    }
    if (!EvalProvenance.isDigest(
      _string(assignment['runtimeVerificationRef']),
    )) {
      issues.add(
        'assignments[$index].runtimeVerificationRef must be a sha256 digest',
      );
    }
    if (assignment['blockerCodes'] is! List) {
      issues.add('assignments[$index].blockerCodes must be a list');
    }
  }
  EvalUseCaseTuningReleasePlan._validateNoPrivatePayloads(
    issues,
    ledger,
    'sourceRuntimeRolloutLedger',
  );
  return issues;
}

int _runtimeVerificationCount(Map<String, dynamic> ledger) {
  final count = _map(ledger['summary'])['runtimeVerificationCount'];
  if (count is int && count >= 0) return count;
  return _mapList(ledger['runtimeVerificationSources']).length;
}

int _statusCount(List<Map<String, dynamic>> entries, String status) =>
    entries.where((entry) => entry['status'] == status).length;

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map<String, dynamic>) item,
      ]
    : const <Map<String, dynamic>>[];

List<String> _stringList(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      ]
    : const <String>[];

String _string(Object? value) => value is String ? value : '';

List<String> _sortedStrings(Iterable<String> values) =>
    values.where((value) => value.isNotEmpty).toSet().toList()..sort();
