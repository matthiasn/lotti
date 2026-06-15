import 'eval_provenance.dart';
import 'eval_use_case_tuning_release_plan.dart';
import 'eval_use_case_tuning_release_review.dart';

abstract final class EvalUseCaseTuningReleaseGate {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseTuningReleaseGate';
  static final Expando<String> _verifiedReleaseReviewSourceDigests =
      Expando<String>('evalUseCaseTuningReleaseGateReviewSourceDigest');
  static const _readyReleasePlanStatus = 'readyForReleaseReview';
  static const _allowedStatuses = {
    'approvedForManualApply',
    'blockedReleasePlan',
    'blockedReleaseReview',
    'invalid',
  };
  static const _allowedReviewCategories = {
    'roadmapIntegrityAudit',
    'runtimeBindingAudit',
    'rollbackAudit',
    'privacyAudit',
  };
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=|file://)/(?:Users|home|private|var|tmp|Volumes)/',
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

  static Map<String, dynamic> build({
    required Map<String, dynamic> releasePlan,
    List<Map<String, dynamic>> releaseReviewBundles = const [],
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    DateTime? generatedAt,
  }) {
    final releasePlanIssues = _releasePlanIssues(
      releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final queue = _map(releasePlan['releaseReviewQueue']);
    final sourceQueueDigest = EvalProvenance.digestJson(queue);
    final releasePlanStatus = _string(releasePlan['status']).isEmpty
        ? 'unknown'
        : _string(releasePlan['status']);
    final releasePlanReady =
        releasePlanIssues.isEmpty &&
        releasePlanStatus == _readyReleasePlanStatus;
    final sourceBundles = [
      for (final indexed in releaseReviewBundles.indexed)
        _SourceReviewBundle.fromBundle(
          index: indexed.$1,
          bundle: indexed.$2,
          releasePlan: releasePlan,
        ),
    ];
    final approvedAttestations = [
      for (final source in sourceBundles)
        if (source.approved)
          for (final attestation in _mapList(source.bundle['attestations']))
            if (attestation['status'] == 'approved') attestation,
    ];
    final requirements = releasePlanReady
        ? _reviewRequirementsFromReleasePlan(
            releasePlan,
            sourceRoadmap: sourceRoadmap,
            sourceDecisionLedgers: sourceDecisionLedgers,
            sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
            previousReleasePlan: previousReleasePlan,
          )
        : const <_ReviewRequirement>[];
    final reviewStatus = _reviewStatus(
      requirements: requirements,
      attestations: approvedAttestations,
    );
    final issues = _artifactIssues(
      releasePlanIssues: releasePlanIssues,
      releasePlanStatus: releasePlanStatus,
      releasePlanReady: releasePlanReady,
      sourceBundles: sourceBundles,
      reviewStatus: reviewStatus,
    );
    final status = _status(
      releasePlanIssues: releasePlanIssues,
      releasePlanReady: releasePlanReady,
      sourceBundles: sourceBundles,
      reviewStatus: reviewStatus,
    );
    final approved = status == 'approvedForManualApply';
    final assignmentRefs = [
      for (final assignment in _mapList(releasePlan['runtimeAssignments']))
        _string(assignment['assignmentRef']),
    ];
    final approvedAssignmentRefs = [
      if (approved)
        for (final assignment in _mapList(releasePlan['runtimeAssignments']))
          _string(assignment['assignmentRef']),
    ];
    final assignmentRefsDigest = EvalProvenance.digestJson(assignmentRefs);
    final sourceReviewBundleSummaries = [
      for (final source in sourceBundles) source.toJson(),
    ];
    final sourceReleasePlan = <String, dynamic>{
      'kind': EvalUseCaseTuningReleasePlan.kind,
      'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
      'status': releasePlanStatus,
      'releasePlanRef': _string(releasePlan['releasePlanRef']),
      'sourceRoadmapDigest': _string(
        _map(releasePlan['sourceRoadmap'])['roadmapDigest'],
      ),
      'releasePlanDigest': releasePlanDigest,
      'sourceQueueDigest': sourceQueueDigest,
      'assignmentRefsDigest': assignmentRefsDigest,
      'modelClassCoverageProofSummaryDigest': _string(
        _map(
          releasePlan['modelClassCoverageProofSummary'],
        )['proofSummaryDigest'],
      ),
      'contractIssueCount': releasePlanIssues.length,
      'assignmentCount': _mapList(releasePlan['runtimeAssignments']).length,
      'reviewTaskCount': _mapList(queue['tasks']).length,
    };
    final releaseGate = reviewStatus.toJson();
    final summary = <String, dynamic>{
      'assignmentCount': _mapList(releasePlan['runtimeAssignments']).length,
      'approvedAssignmentRefCount': approved
          ? _mapList(releasePlan['runtimeAssignments']).length
          : 0,
      'reviewBundleCount': sourceBundles.length,
      'validReviewBundleCount': sourceBundles
          .where((source) => source.valid)
          .length,
      'requiredReviewCount': requirements.length,
      'attestationCount': reviewStatus.attestationCount,
      'approvedAttestationCount': reviewStatus.approvedAttestationCount,
      'missingReviewAttestationCount': reviewStatus.missing.length,
      'duplicateApprovedAttestationCount': reviewStatus.duplicates.length,
      'unmatchedApprovedAttestationCount': reviewStatus.unmatched.length,
      'issueCount': issues.length,
    };
    final gate = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'releaseGateRef': EvalProvenance.digestJson(
        _releaseGateSubject(
          sourceReleasePlan: sourceReleasePlan,
          sourceReviewBundles: sourceReviewBundleSummaries,
          releaseGate: releaseGate,
          approvedAssignmentRefs: approvedAssignmentRefs,
          summary: summary,
        ),
      ),
      'sourceReleasePlan': sourceReleasePlan,
      'sourceReviewBundles': sourceReviewBundleSummaries,
      'summary': summary,
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'localConfigIdsOmitted': true,
        'sourceArtifactPathsOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesReleasePlanAndReviewAttestationsOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'liveCommandsCreated': false,
        'runtimeConfigurationApplied': false,
        'aiConfigMutationsWritten': false,
        'releaseApprovalAppliesConfig': false,
      },
      'releaseGate': releaseGate,
      'approvedAssignmentRefs': [
        for (final assignmentRef in approvedAssignmentRefs) assignmentRef,
      ],
      'issues': issues,
      'recommendedCommands': _recommendedCommands(status),
    };
    assertValid(gate);
    if (releaseReviewBundles.isNotEmpty) {
      _markVerifiedReleaseReviewSources(gate);
    }
    return gate;
  }

  static bool hasVerifiedReleaseReviewSources(Map<String, dynamic> gate) {
    return _verifiedReleaseReviewSourceDigests[gate] ==
        EvalProvenance.digestJson(gate);
  }

  static List<String> validate(Map<String, dynamic> gate) {
    final issues = <String>[];
    _expectEquals(
      issues,
      gate['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, gate['kind'], kind, 'kind');
    _expectIsoDate(issues, gate['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, gate['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    _expectDigest(issues, gate['releaseGateRef'], 'releaseGateRef');
    final sourceReleasePlan = _expectMap(
      issues,
      gate['sourceReleasePlan'],
      'sourceReleasePlan',
    );
    _validateSourceReleasePlan(issues, sourceReleasePlan);
    final sourceBundles = _expectList(
      issues,
      gate['sourceReviewBundles'],
      'sourceReviewBundles',
    );
    _validateSourceReviewBundles(issues, sourceBundles);
    final summary = _expectMap(issues, gate['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(issues, _expectMap(issues, gate['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, gate['limitations'], 'limitations'),
    );
    final releaseGate = _expectMap(issues, gate['releaseGate'], 'releaseGate');
    _validateReleaseGate(issues, releaseGate);
    final approvedAssignmentRefs = _expectList(
      issues,
      gate['approvedAssignmentRefs'],
      'approvedAssignmentRefs',
    );
    _expectDigestList(issues, approvedAssignmentRefs, 'approvedAssignmentRefs');
    final issueList = _expectList(issues, gate['issues'], 'issues');
    _validateIssues(issues, issueList);
    _validateCommands(
      issues,
      _expectList(issues, gate['recommendedCommands'], 'recommendedCommands'),
      'recommendedCommands',
    );
    _validateSummaryInvariants(
      issues,
      status: status,
      summary: summary,
      sourceReleasePlan: sourceReleasePlan,
      sourceBundles: sourceBundles,
      releaseGate: releaseGate,
      approvedAssignmentRefs: approvedAssignmentRefs,
      issueList: issueList,
    );
    _validateReleaseGateRef(
      issues,
      gate,
      sourceReleasePlan: sourceReleasePlan,
      sourceReviewBundles: sourceBundles,
      releaseGate: releaseGate,
      approvedAssignmentRefs: approvedAssignmentRefs,
      summary: summary,
    );
    _validateNoPrivatePayloads(issues, gate, 'releaseGate');
    return issues;
  }

  static void assertValid(Map<String, dynamic> gate) {
    final issues = validate(gate);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning release gate:\n${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstReleasePlan(
    Map<String, dynamic> gate, {
    required Map<String, dynamic> releasePlan,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validate(gate);
    final releasePlanIssues = _releasePlanIssues(
      releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    if (releasePlanIssues.isNotEmpty) {
      issues.add('source release plan contract is invalid');
      return issues;
    }
    final source = _map(gate['sourceReleasePlan']);
    final expected = _sourceReleasePlanFromReleasePlan(
      releasePlan,
      releasePlanIssues: releasePlanIssues,
    );
    for (final field in const [
      'status',
      'releasePlanRef',
      'sourceRoadmapDigest',
      'releasePlanDigest',
      'sourceQueueDigest',
      'assignmentRefsDigest',
      'modelClassCoverageProofSummaryDigest',
      'contractIssueCount',
      'assignmentCount',
      'reviewTaskCount',
    ]) {
      if (source[field] != expected[field]) {
        issues.add('sourceReleasePlan.$field must match releasePlan');
      }
    }
    final approved = _map(gate['releaseGate'])['approved'] == true;
    final approvedAssignmentRefs = _stringList(gate['approvedAssignmentRefs']);
    final expectedAssignmentRefs = _assignmentRefs(releasePlan);
    final expectedPacket = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
      generatedAt: DateTime.utc(2026),
    );
    final expectedPacketRef = _string(expectedPacket['releaseReviewPacketRef']);
    final expectedRequirements = _reviewRequirementsFromPacket(expectedPacket);
    final expectedRequirementKeys = _reviewRequirementKeys(
      expectedRequirements,
    );
    final releaseGate = _map(gate['releaseGate']);
    final actualRequirementKeys = _reviewRequirementKeys(
      [
        for (final requirement in _mapList(releaseGate['requirements']))
          _ReviewRequirement.fromJson(requirement),
      ],
    );
    if (EvalProvenance.digestJson(actualRequirementKeys) !=
        EvalProvenance.digestJson(expectedRequirementKeys)) {
      issues.add(
        'releaseGate.requirements must match releasePlan review tasks',
      );
    }
    final approvedReviewKeys = _stringList(
      releaseGate['approvedReviewKeys'],
    )..sort();
    if (approved &&
        EvalProvenance.digestJson(approvedReviewKeys) !=
            EvalProvenance.digestJson(expectedRequirementKeys)) {
      issues.add('releaseGate.approvedReviewKeys must match releasePlan');
    }
    if (approved &&
        expectedRequirements.isNotEmpty &&
        _mapList(gate['sourceReviewBundles']).isEmpty) {
      issues.add('sourceReviewBundles must include approved review evidence');
    }
    if (approved &&
        _intOrZero(releaseGate['approvedAttestationCount']) <
            expectedRequirements.length) {
      issues.add('releaseGate.approvedAttestationCount must cover releasePlan');
    }
    if (approved &&
        EvalProvenance.digestJson(approvedAssignmentRefs) !=
            EvalProvenance.digestJson(expectedAssignmentRefs)) {
      issues.add('approvedAssignmentRefs must match releasePlan assignments');
    }
    var approvedSourceBundleCount = 0;
    final expectedReviewTaskDigestsDigest = _reviewTaskDigestsDigest(
      expectedRequirements,
    );
    for (final (index, bundle) in _mapList(
      gate['sourceReviewBundles'],
    ).indexed) {
      if (_intOrZero(bundle['contractIssueCount']) > 0) continue;
      if (_string(bundle['status']) == 'approved') {
        approvedSourceBundleCount += 1;
      }
      if (_string(bundle['sourceReleasePlanDigest']) !=
          _string(expected['releasePlanDigest'])) {
        issues.add(
          'sourceReviewBundles[$index].sourceReleasePlanDigest must match releasePlan',
        );
      }
      if (_string(bundle['sourceQueueDigest']) !=
          _string(expected['sourceQueueDigest'])) {
        issues.add(
          'sourceReviewBundles[$index].sourceQueueDigest must match releasePlan',
        );
      }
      if (_string(bundle['modelClassCoverageProofSummaryDigest']) !=
          _string(expected['modelClassCoverageProofSummaryDigest'])) {
        issues.add(
          'sourceReviewBundles[$index].modelClassCoverageProofSummaryDigest must match releasePlan',
        );
      }
      if (_string(bundle['sourceReleaseReviewPacketRef']) !=
          expectedPacketRef) {
        issues.add(
          'sourceReviewBundles[$index].sourceReleaseReviewPacketRef must match releasePlan',
        );
      }
      if (_string(bundle['status']) == 'approved' &&
          _string(bundle['approvedReviewTaskDigestsDigest']) !=
              expectedReviewTaskDigestsDigest) {
        issues.add(
          'sourceReviewBundles[$index].approvedReviewTaskDigestsDigest must match releasePlan',
        );
      }
    }
    if (approved &&
        expectedRequirements.isNotEmpty &&
        approvedSourceBundleCount == 0) {
      issues.add('sourceReviewBundles must include approved review evidence');
    }
    return issues;
  }

  static List<String> validateAgainstSources(
    Map<String, dynamic> gate, {
    required Map<String, dynamic> releasePlan,
    required List<Map<String, dynamic>> releaseReviewBundles,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validateAgainstReleasePlan(
      gate,
      releasePlan: releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    final expectedSourceBundles = [
      for (final indexed in releaseReviewBundles.indexed)
        _SourceReviewBundle.fromBundle(
          index: indexed.$1,
          bundle: indexed.$2,
          releasePlan: releasePlan,
        ).toJson(),
    ];
    final actualSourceBundles = _mapList(gate['sourceReviewBundles']);
    if (EvalProvenance.digestJson(actualSourceBundles) !=
        EvalProvenance.digestJson(expectedSourceBundles)) {
      issues.add('sourceReviewBundles must match release review bundles');
    }
    return issues;
  }

  static void assertMatchesReleasePlan(
    Map<String, dynamic> gate, {
    required Map<String, dynamic> releasePlan,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validateAgainstReleasePlan(
      gate,
      releasePlan: releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning release gate source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static void assertMatchesSources(
    Map<String, dynamic> gate, {
    required Map<String, dynamic> releasePlan,
    required List<Map<String, dynamic>> releaseReviewBundles,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final issues = validateAgainstSources(
      gate,
      releasePlan: releasePlan,
      releaseReviewBundles: releaseReviewBundles,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    if (issues.isEmpty) {
      _markVerifiedReleaseReviewSources(gate);
      return;
    }
    throw StateError(
      'Invalid use-case tuning release gate source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static void _markVerifiedReleaseReviewSources(Map<String, dynamic> gate) {
    _verifiedReleaseReviewSourceDigests[gate] = EvalProvenance.digestJson(gate);
  }

  static List<_ReviewRequirement> _reviewRequirementsFromReleasePlan(
    Map<String, dynamic> releasePlan, {
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    final packet = EvalUseCaseTuningReleaseReview.buildPacket(
      releasePlan: releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
      generatedAt: DateTime.utc(2026),
    );
    return _reviewRequirementsFromPacket(packet);
  }

  static List<_ReviewRequirement> _reviewRequirementsFromPacket(
    Map<String, dynamic> packet,
  ) {
    return [
      for (final task in _mapList(packet['reviewTasks']))
        if (task['required'] == true)
          _ReviewRequirement(
            sourceReleasePlanDigest: _string(
              task['sourceReleasePlanDigest'],
            ),
            sourceQueueDigest: _string(task['sourceQueueDigest']),
            sourceReleaseReviewPacketRef: _string(
              task['sourceReleaseReviewPacketRef'],
            ),
            reviewRef: _string(task['reviewRef']),
            category: _string(task['category']),
            sourceReviewTaskDigest: _string(
              task['sourceReviewTaskDigest'],
            ),
            assignmentRefsDigest: _string(task['assignmentRefsDigest']),
            assignmentProofSummaryDigest: _string(
              task['assignmentProofSummaryDigest'],
            ),
            modelClassCoverageProofSummaryDigest: _string(
              task['modelClassCoverageProofSummaryDigest'],
            ),
          ),
    ];
  }

  static _ReviewStatus _reviewStatus({
    required List<_ReviewRequirement> requirements,
    required List<Map<String, dynamic>> attestations,
  }) {
    final requiredByKey = {
      for (final requirement in requirements) requirement.key: requirement,
    };
    final counts = <String, int>{};
    final unmatched = <_ReviewAttestationRef>[];
    for (final attestation in attestations) {
      final ref = _ReviewAttestationRef.fromAttestation(attestation);
      if (!requiredByKey.containsKey(ref.key)) {
        unmatched.add(ref);
        continue;
      }
      counts[ref.key] = (counts[ref.key] ?? 0) + 1;
    }
    final missing = [
      for (final requirement in requirements)
        if ((counts[requirement.key] ?? 0) == 0) requirement,
    ];
    final duplicates = [
      for (final requirement in requirements)
        if ((counts[requirement.key] ?? 0) > 1) requirement,
    ];
    return _ReviewStatus(
      requirements: requirements,
      missing: missing,
      duplicates: duplicates,
      unmatched: unmatched,
      attestationCount: attestations.length,
      approvedAttestationCount: attestations.length,
    );
  }

  static List<Map<String, dynamic>> _artifactIssues({
    required List<String> releasePlanIssues,
    required String releasePlanStatus,
    required bool releasePlanReady,
    required List<_SourceReviewBundle> sourceBundles,
    required _ReviewStatus reviewStatus,
  }) {
    return [
      for (final issue in releasePlanIssues)
        <String, dynamic>{
          'code': 'releaseGate.releasePlanContractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (releasePlanIssues.isEmpty && !releasePlanReady)
        <String, dynamic>{
          'code': 'releaseGate.sourceNotReady',
          'severity': 'blocking',
          'releasePlanStatus': releasePlanStatus,
        },
      for (final source in sourceBundles)
        if (!source.valid)
          <String, dynamic>{
            'code': 'releaseGate.reviewBundleContractInvalid',
            'severity': 'blocking',
            'bundleRef': source.bundleRef,
            'issueCount': source.contractIssueCount,
          },
      if (reviewStatus.missing.isNotEmpty)
        <String, dynamic>{
          'code': 'releaseGate.reviewAttestationMissing',
          'severity': 'blocking',
          'missingRequirementCount': reviewStatus.missing.length,
        },
      if (reviewStatus.duplicates.isNotEmpty)
        <String, dynamic>{
          'code': 'releaseGate.reviewAttestationDuplicate',
          'severity': 'blocking',
          'duplicateRequirementCount': reviewStatus.duplicates.length,
        },
      if (reviewStatus.unmatched.isNotEmpty)
        <String, dynamic>{
          'code': 'releaseGate.reviewAttestationUnmatched',
          'severity': 'blocking',
          'unmatchedAttestationCount': reviewStatus.unmatched.length,
        },
      for (final source in sourceBundles)
        if (source.valid && !source.approved)
          <String, dynamic>{
            'code': 'releaseGate.reviewBundleNotApproved',
            'severity': 'blocking',
            'bundleRef': source.bundleRef,
            'bundleStatus': source.status,
          },
    ];
  }

  static String _status({
    required List<String> releasePlanIssues,
    required bool releasePlanReady,
    required List<_SourceReviewBundle> sourceBundles,
    required _ReviewStatus reviewStatus,
  }) {
    if (releasePlanIssues.isNotEmpty ||
        sourceBundles.any((source) => !source.valid)) {
      return 'invalid';
    }
    if (!releasePlanReady) return 'blockedReleasePlan';
    if (!reviewStatus.approved ||
        sourceBundles.any((source) => source.valid && !source.approved)) {
      return 'blockedReleaseReview';
    }
    return 'approvedForManualApply';
  }

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final modes = switch (status) {
      'blockedReleasePlan' => const [
        ('release-plan', 'eval/run_level2.sh release-plan'),
      ],
      'blockedReleaseReview' => const [
        ('release-review-packet', 'eval/run_level2.sh release-review-packet'),
        ('import-release-review', 'eval/run_level2.sh import-release-review'),
        ('release-gate', 'eval/run_level2.sh release-gate'),
      ],
      _ => const [
        ('release-gate', 'eval/run_level2.sh release-gate'),
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

  static void _validateSourceReleasePlan(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseTuningReleasePlan.kind,
      'sourceReleasePlan.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseTuningReleasePlan.schemaVersion,
      'sourceReleasePlan.schemaVersion',
    );
    _expectNonEmptyString(issues, source['status'], 'sourceReleasePlan.status');
    for (final field in const [
      'releasePlanRef',
      'sourceRoadmapDigest',
      'releasePlanDigest',
      'sourceQueueDigest',
      'assignmentRefsDigest',
      'modelClassCoverageProofSummaryDigest',
    ]) {
      _expectDigest(issues, source[field], 'sourceReleasePlan.$field');
    }
    for (final field in const [
      'contractIssueCount',
      'assignmentCount',
      'reviewTaskCount',
    ]) {
      _expectNonNegativeInt(issues, source[field], 'sourceReleasePlan.$field');
    }
  }

  static void _validateSourceReviewBundles(
    List<String> issues,
    List<dynamic>? sourceBundles,
  ) {
    if (sourceBundles == null) return;
    for (final (index, value) in sourceBundles.indexed) {
      final bundle = _expectMap(issues, value, 'sourceReviewBundles[$index]');
      if (bundle == null) continue;
      _expectDigest(
        issues,
        bundle['bundleRef'],
        'sourceReviewBundles[$index].bundleRef',
      );
      _expectEquals(
        issues,
        bundle['kind'],
        EvalUseCaseTuningReleaseReview.bundleKind,
        'sourceReviewBundles[$index].kind',
      );
      _expectEquals(
        issues,
        bundle['schemaVersion'],
        EvalUseCaseTuningReleaseReview.bundleSchemaVersion,
        'sourceReviewBundles[$index].schemaVersion',
      );
      _expectNonEmptyString(
        issues,
        bundle['status'],
        'sourceReviewBundles[$index].status',
      );
      _expectDigest(
        issues,
        bundle['bundleDigest'],
        'sourceReviewBundles[$index].bundleDigest',
      );
      for (final field in const [
        'sourceReleasePlanDigest',
        'sourceQueueDigest',
        'sourceReleaseReviewPacketRef',
        'approvedReviewTaskDigestsDigest',
        'modelClassCoverageProofSummaryDigest',
      ]) {
        final value = bundle[field];
        if (value == 'omittedInvalid') continue;
        _expectDigest(issues, value, 'sourceReviewBundles[$index].$field');
      }
      for (final field in const [
        'contractIssueCount',
        'attestationCount',
        'approvedAttestationCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          bundle[field],
          'sourceReviewBundles[$index].$field',
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
      'approvedAssignmentRefCount',
      'reviewBundleCount',
      'validReviewBundleCount',
      'requiredReviewCount',
      'attestationCount',
      'approvedAttestationCount',
      'missingReviewAttestationCount',
      'duplicateApprovedAttestationCount',
      'unmatchedApprovedAttestationCount',
      'issueCount',
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
      'consumesReleasePlanAndReviewAttestationsOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'liveCommandsCreated': false,
      'runtimeConfigurationApplied': false,
      'aiConfigMutationsWritten': false,
      'releaseApprovalAppliesConfig': false,
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

  static void _validateReleaseGate(
    List<String> issues,
    Map<String, dynamic>? gate,
  ) {
    if (gate == null) return;
    _expectBool(issues, gate['approved'], 'releaseGate.approved');
    _expectStringList(
      issues,
      gate['approvedReviewKeys'],
      'releaseGate.approvedReviewKeys',
    );
    for (final field in const [
      'requiredReviewCount',
      'attestationCount',
      'approvedAttestationCount',
      'missingRequirementCount',
      'duplicateRequirementCount',
      'unmatchedAttestationCount',
    ]) {
      _expectNonNegativeInt(issues, gate[field], 'releaseGate.$field');
    }
    _validateReviewRequirements(
      issues,
      _expectList(issues, gate['requirements'], 'releaseGate.requirements'),
      'releaseGate.requirements',
    );
    _validateReviewRequirements(
      issues,
      _expectList(
        issues,
        gate['missingRequirements'],
        'releaseGate.missingRequirements',
      ),
      'releaseGate.missingRequirements',
    );
    _validateReviewRequirements(
      issues,
      _expectList(
        issues,
        gate['duplicateRequirements'],
        'releaseGate.duplicateRequirements',
      ),
      'releaseGate.duplicateRequirements',
    );
    _validateReviewAttestationRefs(
      issues,
      _expectList(
        issues,
        gate['unmatchedAttestations'],
        'releaseGate.unmatchedAttestations',
      ),
      'releaseGate.unmatchedAttestations',
    );
  }

  static void _validateReviewRequirements(
    List<String> issues,
    List<dynamic>? requirements,
    String path,
  ) {
    if (requirements == null) return;
    for (final (index, value) in requirements.indexed) {
      final requirement = _expectMap(issues, value, '$path[$index]');
      if (requirement == null) continue;
      for (final field in const [
        'sourceReleasePlanDigest',
        'sourceQueueDigest',
        'sourceReleaseReviewPacketRef',
        'reviewRef',
        'sourceReviewTaskDigest',
        'assignmentRefsDigest',
        'assignmentProofSummaryDigest',
        'modelClassCoverageProofSummaryDigest',
      ]) {
        _expectDigest(issues, requirement[field], '$path[$index].$field');
      }
      final category = _expectNonEmptyString(
        issues,
        requirement['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
      }
    }
  }

  static void _validateReviewAttestationRefs(
    List<String> issues,
    List<dynamic>? attestations,
    String path,
  ) {
    if (attestations == null) return;
    for (final (index, value) in attestations.indexed) {
      final attestation = _expectMap(issues, value, '$path[$index]');
      if (attestation == null) continue;
      for (final field in const [
        'sourceReleasePlanDigest',
        'sourceQueueDigest',
        'sourceReleaseReviewPacketRef',
        'reviewRef',
        'sourceReviewTaskDigest',
        'assignmentRefsDigest',
        'assignmentProofSummaryDigest',
        'modelClassCoverageProofSummaryDigest',
      ]) {
        _expectDigest(issues, attestation[field], '$path[$index].$field');
      }
      final category = _expectNonEmptyString(
        issues,
        attestation['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
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
    required String? status,
    required Map<String, dynamic>? summary,
    required Map<String, dynamic>? sourceReleasePlan,
    required List<dynamic>? sourceBundles,
    required Map<String, dynamic>? releaseGate,
    required List<dynamic>? approvedAssignmentRefs,
    required List<dynamic>? issueList,
  }) {
    if (summary == null) return;
    if (sourceBundles != null &&
        summary['reviewBundleCount'] is int &&
        summary['reviewBundleCount'] != sourceBundles.length) {
      issues.add(
        'summary.reviewBundleCount must match sourceReviewBundles.length',
      );
    }
    if (sourceReleasePlan != null &&
        summary['assignmentCount'] is int &&
        summary['assignmentCount'] !=
            _intOrZero(sourceReleasePlan['assignmentCount'])) {
      issues.add(
        'summary.assignmentCount must match sourceReleasePlan.assignmentCount',
      );
    }
    if (sourceBundles != null && summary['validReviewBundleCount'] is int) {
      final validCount = _mapList(
        sourceBundles,
      ).where((bundle) => _intOrZero(bundle['contractIssueCount']) == 0).length;
      if (summary['validReviewBundleCount'] != validCount) {
        issues.add(
          'summary.validReviewBundleCount must match valid source review bundles',
        );
      }
    }
    if (releaseGate != null) {
      for (final field in const [
        'requiredReviewCount',
        'attestationCount',
        'approvedAttestationCount',
      ]) {
        if (summary[field] is int && summary[field] != releaseGate[field]) {
          issues.add('summary.$field must match releaseGate.$field');
        }
      }
      final missing = _listLength(releaseGate['missingRequirements']);
      if (summary['missingReviewAttestationCount'] is int &&
          summary['missingReviewAttestationCount'] != missing) {
        issues.add(
          'summary.missingReviewAttestationCount must match releaseGate.missingRequirements.length',
        );
      }
      final duplicates = _listLength(releaseGate['duplicateRequirements']);
      if (summary['duplicateApprovedAttestationCount'] is int &&
          summary['duplicateApprovedAttestationCount'] != duplicates) {
        issues.add(
          'summary.duplicateApprovedAttestationCount must match releaseGate.duplicateRequirements.length',
        );
      }
      final unmatched = _listLength(releaseGate['unmatchedAttestations']);
      if (summary['unmatchedApprovedAttestationCount'] is int &&
          summary['unmatchedApprovedAttestationCount'] != unmatched) {
        issues.add(
          'summary.unmatchedApprovedAttestationCount must match releaseGate.unmatchedAttestations.length',
        );
      }
    }
    if (approvedAssignmentRefs != null &&
        summary['approvedAssignmentRefCount'] is int &&
        summary['approvedAssignmentRefCount'] !=
            approvedAssignmentRefs.length) {
      issues.add(
        'summary.approvedAssignmentRefCount must match approvedAssignmentRefs.length',
      );
    }
    if (releaseGate != null &&
        sourceReleasePlan != null &&
        sourceBundles != null &&
        approvedAssignmentRefs != null) {
      final approved = releaseGate['approved'] == true;
      final approvedRefsDigest = EvalProvenance.digestJson(
        _stringList(approvedAssignmentRefs),
      );
      if (approved &&
          approvedRefsDigest !=
              _string(sourceReleasePlan['assignmentRefsDigest'])) {
        issues.add(
          'approvedAssignmentRefs must match sourceReleasePlan.assignmentRefsDigest when releaseGate.approved is true',
        );
      }
      if (approved) {
        final requiredCount = _intOrZero(releaseGate['requiredReviewCount']);
        final approvedReviewKeyCount = _stringList(
          releaseGate['approvedReviewKeys'],
        ).length;
        if (requiredCount > 0 && _mapList(sourceBundles).isEmpty) {
          issues.add(
            'sourceReviewBundles must include approved review evidence',
          );
        }
        if (approvedReviewKeyCount != requiredCount) {
          issues.add(
            'releaseGate.approvedReviewKeys must cover every requirement when approved',
          );
        }
        if (_intOrZero(releaseGate['approvedAttestationCount']) <
            requiredCount) {
          issues.add(
            'releaseGate.approvedAttestationCount must cover every requirement when approved',
          );
        }
        if (_intOrZero(releaseGate['missingRequirementCount']) != 0 ||
            _intOrZero(releaseGate['duplicateRequirementCount']) != 0 ||
            _intOrZero(releaseGate['unmatchedAttestationCount']) != 0) {
          issues.add(
            'releaseGate approval must not have missing, duplicate, or unmatched review evidence',
          );
        }
      }
      if (!approved && approvedAssignmentRefs.isNotEmpty) {
        issues.add(
          'approvedAssignmentRefs must be empty unless releaseGate.approved is true',
        );
      }
    }
    if (status != null &&
        sourceReleasePlan != null &&
        sourceBundles != null &&
        releaseGate != null &&
        issueList != null) {
      final expectedStatus = _statusFromPublicFields(
        sourceReleasePlan: sourceReleasePlan,
        sourceBundles: sourceBundles,
        releaseGate: releaseGate,
        issueList: issueList,
      );
      if (status != expectedStatus) {
        issues.add('status must match release gate approval state');
      }
    }
    if (issueList != null &&
        summary['issueCount'] is int &&
        summary['issueCount'] != issueList.length) {
      issues.add('summary.issueCount must match issues.length');
    }
  }

  static String _statusFromPublicFields({
    required Map<String, dynamic> sourceReleasePlan,
    required List<dynamic> sourceBundles,
    required Map<String, dynamic> releaseGate,
    required List<dynamic> issueList,
  }) {
    final hasInvalidSource =
        _intOrZero(
              sourceReleasePlan['contractIssueCount'],
            ) >
            0 ||
        _mapList(sourceBundles).any(
          (bundle) => _intOrZero(bundle['contractIssueCount']) > 0,
        );
    if (hasInvalidSource) return 'invalid';
    if (_string(sourceReleasePlan['status']) != _readyReleasePlanStatus) {
      return 'blockedReleasePlan';
    }
    if (releaseGate['approved'] != true || issueList.isNotEmpty) {
      return 'blockedReleaseReview';
    }
    return 'approvedForManualApply';
  }

  static List<String> _releasePlanIssues(
    Map<String, dynamic> releasePlan, {
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
  }) {
    if (sourceRoadmap == null) {
      return EvalUseCaseTuningReleasePlan.validate(releasePlan);
    }
    return EvalUseCaseTuningReleasePlan.validateAgainstSources(
      releasePlan,
      roadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
      requireDecisionLedgerSourceReplay: sourceDecisionLedgers.isNotEmpty,
    );
  }

  static Map<String, dynamic> _sourceReleasePlanFromReleasePlan(
    Map<String, dynamic> releasePlan, {
    required List<String> releasePlanIssues,
  }) {
    final queue = _map(releasePlan['releaseReviewQueue']);
    return <String, dynamic>{
      'status': _string(releasePlan['status']).isEmpty
          ? 'unknown'
          : _string(releasePlan['status']),
      'releasePlanRef': _string(releasePlan['releasePlanRef']),
      'sourceRoadmapDigest': _string(
        _map(releasePlan['sourceRoadmap'])['roadmapDigest'],
      ),
      'releasePlanDigest': EvalProvenance.digestJson(releasePlan),
      'sourceQueueDigest': EvalProvenance.digestJson(queue),
      'assignmentRefsDigest': EvalProvenance.digestJson(
        _assignmentRefs(releasePlan),
      ),
      'modelClassCoverageProofSummaryDigest': _string(
        _map(
          releasePlan['modelClassCoverageProofSummary'],
        )['proofSummaryDigest'],
      ),
      'contractIssueCount': releasePlanIssues.length,
      'assignmentCount': _mapList(releasePlan['runtimeAssignments']).length,
      'reviewTaskCount': _mapList(queue['tasks']).length,
    };
  }

  static List<String> _assignmentRefs(Map<String, dynamic> releasePlan) => [
    for (final assignment in _mapList(releasePlan['runtimeAssignments']))
      _string(assignment['assignmentRef']),
  ];

  static void _validateReleaseGateRef(
    List<String> issues,
    Map<String, dynamic> artifact, {
    required Map<String, dynamic>? sourceReleasePlan,
    required List<dynamic>? sourceReviewBundles,
    required Map<String, dynamic>? releaseGate,
    required List<dynamic>? approvedAssignmentRefs,
    required Map<String, dynamic>? summary,
  }) {
    if (sourceReleasePlan == null ||
        sourceReviewBundles == null ||
        releaseGate == null ||
        approvedAssignmentRefs == null ||
        summary == null) {
      return;
    }
    final sourceReviewBundleSummaries = [
      for (final bundle in sourceReviewBundles)
        if (bundle is Map<String, dynamic>) bundle,
    ];
    final expectedRef = EvalProvenance.digestJson(
      _releaseGateSubject(
        sourceReleasePlan: sourceReleasePlan,
        sourceReviewBundles: sourceReviewBundleSummaries,
        releaseGate: releaseGate,
        approvedAssignmentRefs: _stringList(approvedAssignmentRefs),
        summary: summary,
      ),
    );
    if (artifact['releaseGateRef'] != expectedRef) {
      issues.add('releaseGateRef must match release gate subject digest');
    }
  }

  static Map<String, dynamic> _releaseGateSubject({
    required Map<String, dynamic> sourceReleasePlan,
    required List<Map<String, dynamic>> sourceReviewBundles,
    required Map<String, dynamic> releaseGate,
    required List<String> approvedAssignmentRefs,
    required Map<String, dynamic> summary,
  }) => <String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'sourceReleasePlanDigest': _string(
      sourceReleasePlan['releasePlanDigest'],
    ),
    'sourceQueueDigest': _string(sourceReleasePlan['sourceQueueDigest']),
    'assignmentRefsDigest': _string(
      sourceReleasePlan['assignmentRefsDigest'],
    ),
    'approvedReviewKeys': _stringList(releaseGate['approvedReviewKeys']),
    'sourceReviewBundlesDigest': EvalProvenance.digestJson(
      sourceReviewBundles,
    ),
    'summaryDigest': EvalProvenance.digestJson(summary),
    'approvedAssignmentRefsDigest': EvalProvenance.digestJson(
      approvedAssignmentRefs,
    ),
    'modelClassCoverageProofSummaryDigest': _string(
      sourceReleasePlan['modelClassCoverageProofSummaryDigest'],
    ),
    'approved': releaseGate['approved'] == true,
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

  static void _expectDigestList(
    List<String> issues,
    Object? value,
    String path,
  ) {
    final strings = _expectStringList(issues, value, path);
    if (strings == null) return;
    for (final (index, item) in strings.indexed) {
      if (!EvalProvenance.isDigest(item)) {
        issues.add('$path[$index] must be a sha256 digest');
      }
    }
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

final class _SourceReviewBundle {
  const _SourceReviewBundle({
    required this.bundle,
    required this.bundleRef,
    required this.bundleDigest,
    required this.issues,
  });

  factory _SourceReviewBundle.fromBundle({
    required int index,
    required Map<String, dynamic> bundle,
    Map<String, dynamic>? releasePlan,
  }) {
    final issues = releasePlan == null
        ? EvalUseCaseTuningReleaseReview.validateBundle(bundle)
        : EvalUseCaseTuningReleaseReview.validateBundleAgainstReleasePlan(
            bundle,
            releasePlan: releasePlan,
          );
    final digest = EvalProvenance.digestJson(bundle);
    final bundleRef = _string(bundle['attestationBundleRef']);
    return _SourceReviewBundle(
      bundle: bundle,
      bundleRef: EvalProvenance.isDigest(bundleRef)
          ? bundleRef
          : EvalProvenance.digestJson(<String, dynamic>{
              'index': index,
              'bundleDigest': digest,
            }),
      bundleDigest: digest,
      issues: issues,
    );
  }

  final Map<String, dynamic> bundle;
  final String bundleRef;
  final String bundleDigest;
  final List<String> issues;

  bool get valid => issues.isEmpty;
  String get status => valid ? _string(bundle['status']) : 'invalid';
  bool get approved => valid && status == 'approved';
  int get contractIssueCount => issues.length;

  Map<String, dynamic> toJson() {
    final source = _map(bundle['sourceReleasePlan']);
    final attestations = _mapList(bundle['attestations']);
    return <String, dynamic>{
      'bundleRef': bundleRef,
      'kind': EvalUseCaseTuningReleaseReview.bundleKind,
      'schemaVersion': EvalUseCaseTuningReleaseReview.bundleSchemaVersion,
      'status': status,
      'bundleDigest': bundleDigest,
      'sourceReleasePlanDigest': valid
          ? _string(source['releasePlanDigest'])
          : 'omittedInvalid',
      'sourceQueueDigest': valid
          ? _string(source['sourceQueueDigest'])
          : 'omittedInvalid',
      'sourceReleaseReviewPacketRef': valid
          ? _string(source['sourceReleaseReviewPacketRef'])
          : 'omittedInvalid',
      'approvedReviewTaskDigestsDigest': valid
          ? _approvedReviewTaskDigestsDigest(attestations)
          : 'omittedInvalid',
      'modelClassCoverageProofSummaryDigest': valid
          ? _string(source['modelClassCoverageProofSummaryDigest'])
          : 'omittedInvalid',
      'contractIssueCount': contractIssueCount,
      'attestationCount': valid ? attestations.length : 0,
      'approvedAttestationCount': valid
          ? attestations
                .where((attestation) => attestation['status'] == 'approved')
                .length
          : 0,
    };
  }
}

final class _ReviewRequirement {
  const _ReviewRequirement({
    required this.sourceReleasePlanDigest,
    required this.sourceQueueDigest,
    required this.sourceReleaseReviewPacketRef,
    required this.reviewRef,
    required this.category,
    required this.sourceReviewTaskDigest,
    required this.assignmentRefsDigest,
    required this.assignmentProofSummaryDigest,
    required this.modelClassCoverageProofSummaryDigest,
  });

  factory _ReviewRequirement.fromJson(Map<String, dynamic> value) {
    return _ReviewRequirement(
      sourceReleasePlanDigest: _string(value['sourceReleasePlanDigest']),
      sourceQueueDigest: _string(value['sourceQueueDigest']),
      sourceReleaseReviewPacketRef: _string(
        value['sourceReleaseReviewPacketRef'],
      ),
      reviewRef: _string(value['reviewRef']),
      category: _string(value['category']),
      sourceReviewTaskDigest: _string(value['sourceReviewTaskDigest']),
      assignmentRefsDigest: _string(value['assignmentRefsDigest']),
      assignmentProofSummaryDigest: _string(
        value['assignmentProofSummaryDigest'],
      ),
      modelClassCoverageProofSummaryDigest: _string(
        value['modelClassCoverageProofSummaryDigest'],
      ),
    );
  }

  final String sourceReleasePlanDigest;
  final String sourceQueueDigest;
  final String sourceReleaseReviewPacketRef;
  final String reviewRef;
  final String category;
  final String sourceReviewTaskDigest;
  final String assignmentRefsDigest;
  final String assignmentProofSummaryDigest;
  final String modelClassCoverageProofSummaryDigest;

  String get key => [
    sourceReleasePlanDigest,
    sourceQueueDigest,
    sourceReleaseReviewPacketRef,
    reviewRef,
    category,
    sourceReviewTaskDigest,
    assignmentRefsDigest,
    assignmentProofSummaryDigest,
    modelClassCoverageProofSummaryDigest,
  ].join(':');

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceReleasePlanDigest': sourceReleasePlanDigest,
    'sourceQueueDigest': sourceQueueDigest,
    'sourceReleaseReviewPacketRef': sourceReleaseReviewPacketRef,
    'reviewRef': reviewRef,
    'category': category,
    'sourceReviewTaskDigest': sourceReviewTaskDigest,
    'assignmentRefsDigest': assignmentRefsDigest,
    'assignmentProofSummaryDigest': assignmentProofSummaryDigest,
    'modelClassCoverageProofSummaryDigest':
        modelClassCoverageProofSummaryDigest,
  };
}

final class _ReviewAttestationRef {
  const _ReviewAttestationRef({
    required this.sourceReleasePlanDigest,
    required this.sourceQueueDigest,
    required this.sourceReleaseReviewPacketRef,
    required this.reviewRef,
    required this.category,
    required this.sourceReviewTaskDigest,
    required this.assignmentRefsDigest,
    required this.assignmentProofSummaryDigest,
    required this.modelClassCoverageProofSummaryDigest,
  });

  factory _ReviewAttestationRef.fromAttestation(
    Map<String, dynamic> attestation,
  ) {
    return _ReviewAttestationRef(
      sourceReleasePlanDigest: _string(
        attestation['sourceReleasePlanDigest'],
      ),
      sourceQueueDigest: _string(attestation['sourceQueueDigest']),
      sourceReleaseReviewPacketRef: _string(
        attestation['sourceReleaseReviewPacketRef'],
      ),
      reviewRef: _string(attestation['reviewRef']),
      category: _string(attestation['category']),
      sourceReviewTaskDigest: _string(attestation['sourceReviewTaskDigest']),
      assignmentRefsDigest: _string(attestation['assignmentRefsDigest']),
      assignmentProofSummaryDigest: _string(
        attestation['assignmentProofSummaryDigest'],
      ),
      modelClassCoverageProofSummaryDigest: _string(
        attestation['modelClassCoverageProofSummaryDigest'],
      ),
    );
  }

  final String sourceReleasePlanDigest;
  final String sourceQueueDigest;
  final String sourceReleaseReviewPacketRef;
  final String reviewRef;
  final String category;
  final String sourceReviewTaskDigest;
  final String assignmentRefsDigest;
  final String assignmentProofSummaryDigest;
  final String modelClassCoverageProofSummaryDigest;

  String get key => [
    sourceReleasePlanDigest,
    sourceQueueDigest,
    sourceReleaseReviewPacketRef,
    reviewRef,
    category,
    sourceReviewTaskDigest,
    assignmentRefsDigest,
    assignmentProofSummaryDigest,
    modelClassCoverageProofSummaryDigest,
  ].join(':');

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceReleasePlanDigest': sourceReleasePlanDigest,
    'sourceQueueDigest': sourceQueueDigest,
    'sourceReleaseReviewPacketRef': sourceReleaseReviewPacketRef,
    'reviewRef': reviewRef,
    'category': category,
    'sourceReviewTaskDigest': sourceReviewTaskDigest,
    'assignmentRefsDigest': assignmentRefsDigest,
    'assignmentProofSummaryDigest': assignmentProofSummaryDigest,
    'modelClassCoverageProofSummaryDigest':
        modelClassCoverageProofSummaryDigest,
  };
}

final class _ReviewStatus {
  const _ReviewStatus({
    required this.requirements,
    required this.missing,
    required this.duplicates,
    required this.unmatched,
    required this.attestationCount,
    required this.approvedAttestationCount,
  });

  final List<_ReviewRequirement> requirements;
  final List<_ReviewRequirement> missing;
  final List<_ReviewRequirement> duplicates;
  final List<_ReviewAttestationRef> unmatched;
  final int attestationCount;
  final int approvedAttestationCount;

  bool get approved =>
      missing.isEmpty && duplicates.isEmpty && unmatched.isEmpty;

  List<String> get approvedKeys =>
      requirements
          .where(
            (requirement) =>
                !missing.any((missing) => missing.key == requirement.key) &&
                !duplicates.any(
                  (duplicate) => duplicate.key == requirement.key,
                ),
          )
          .map((requirement) => requirement.key)
          .toList()
        ..sort();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'approved': approved,
    'approvedReviewKeys': approvedKeys,
    'requiredReviewCount': requirements.length,
    'attestationCount': attestationCount,
    'approvedAttestationCount': approvedAttestationCount,
    'missingRequirementCount': missing.length,
    'duplicateRequirementCount': duplicates.length,
    'unmatchedAttestationCount': unmatched.length,
    'requirements': [
      for (final requirement in requirements) requirement.toJson(),
    ],
    'missingRequirements': [
      for (final requirement in missing) requirement.toJson(),
    ],
    'duplicateRequirements': [
      for (final requirement in duplicates) requirement.toJson(),
    ],
    'unmatchedAttestations': [
      for (final attestation in unmatched) attestation.toJson(),
    ],
  };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<String> _reviewRequirementKeys(List<_ReviewRequirement> requirements) =>
    [for (final requirement in requirements) requirement.key]..sort();

String _reviewTaskDigestsDigest(List<_ReviewRequirement> requirements) {
  final taskDigests = [
    for (final requirement in requirements) requirement.sourceReviewTaskDigest,
  ]..sort();
  return EvalProvenance.digestJson(taskDigests);
}

String _approvedReviewTaskDigestsDigest(
  List<Map<String, dynamic>> attestations,
) {
  final taskDigests = [
    for (final attestation in attestations)
      if (attestation['status'] == 'approved')
        _string(attestation['sourceReviewTaskDigest']),
  ]..sort();
  return EvalProvenance.digestJson(taskDigests);
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String _string(Object? value) => value is String ? value : '';

int _intOrZero(Object? value) => value is int ? value : 0;

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}

int _listLength(Object? value) => value is List ? value.length : 0;
