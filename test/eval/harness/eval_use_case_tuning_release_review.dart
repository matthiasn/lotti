import 'eval_provenance.dart';
import 'eval_use_case_tuning_release_plan.dart';

abstract final class EvalUseCaseTuningReleaseReview {
  static const packetSchemaVersion = 1;
  static const packetKind = 'lotti.evalUseCaseTuningReleaseReviewPacket';
  static const attestationSchemaVersion = 1;
  static const attestationKind =
      'lotti.evalUseCaseTuningReleaseReviewAttestation';
  static const bundleSchemaVersion = 1;
  static const bundleKind =
      'lotti.evalUseCaseTuningReleaseReviewAttestationBundle';
  static const _readyReleasePlanStatus = 'readyForReleaseReview';
  static const _allowedPacketStatuses = {
    'invalidReleasePlan',
    'blockedReleasePlan',
    'noReviewTasks',
    'readyForReview',
  };
  static const _allowedBundleStatuses = {
    'approved',
    'changesRequested',
    'invalid',
  };
  static const _allowedReviewCategories = {
    'roadmapIntegrityAudit',
    'runtimeBindingAudit',
    'rollbackAudit',
    'privacyAudit',
  };
  static const _allowedAttestationStatuses = {
    'pending',
    'approved',
    'rejected',
    'needsChanges',
  };
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=|file://)/(?:Users|home|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+|'
    r'EVAL_USE_CASE_[A-Z0-9_]+|EVAL_RELEASE_REVIEW_[A-Z0-9_]+)\b',
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

  static Map<String, dynamic> buildPacket({
    required Map<String, dynamic> releasePlan,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    DateTime? generatedAt,
  }) {
    final releasePlanIssues = sourceRoadmap == null
        ? EvalUseCaseTuningReleasePlan.validate(releasePlan)
        : EvalUseCaseTuningReleasePlan.validateAgainstSources(
            releasePlan,
            roadmap: sourceRoadmap,
            sourceDecisionLedgers: sourceDecisionLedgers,
            sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
            previousReleasePlan: previousReleasePlan,
            requireDecisionLedgerSourceReplay: sourceDecisionLedgers.isNotEmpty,
          );
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final queue = _map(releasePlan['releaseReviewQueue']);
    final sourceQueueDigest = EvalProvenance.digestJson(queue);
    final releasePlanStatus = _string(releasePlan['status']).isEmpty
        ? 'unknown'
        : _string(releasePlan['status']);
    final sourceReady =
        releasePlanIssues.isEmpty &&
        releasePlanStatus == _readyReleasePlanStatus;
    final tasks = releasePlanIssues.isEmpty
        ? _mapList(queue['tasks'])
        : const <Map<String, dynamic>>[];
    final reviewTasks = [
      for (final task in tasks)
        if (task['required'] == true)
          _reviewTask(
            releasePlanDigest: releasePlanDigest,
            sourceQueueDigest: sourceQueueDigest,
            task: task,
          ),
    ];
    final status = releasePlanIssues.isNotEmpty
        ? 'invalidReleasePlan'
        : !sourceReady
        ? 'blockedReleasePlan'
        : reviewTasks.isEmpty
        ? 'noReviewTasks'
        : 'readyForReview';
    final packet = <String, dynamic>{
      'schemaVersion': packetSchemaVersion,
      'kind': packetKind,
      'releaseReviewPacketRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceReleasePlan': <String, dynamic>{
        'kind': EvalUseCaseTuningReleasePlan.kind,
        'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
        'status': releasePlanStatus,
        'releasePlanRef': _string(releasePlan['releasePlanRef']),
        'sourceRoadmapDigest': _string(
          _map(releasePlan['sourceRoadmap'])['roadmapDigest'],
        ),
        'releasePlanDigest': releasePlanDigest,
        'sourceQueueDigest': sourceQueueDigest,
        'modelClassCoverageProofSummaryDigest': _string(
          _map(
            releasePlan['modelClassCoverageProofSummary'],
          )['proofSummaryDigest'],
        ),
        'contractIssueCount': releasePlanIssues.length,
        'assignmentCount': _mapList(releasePlan['runtimeAssignments']).length,
        'reviewTaskCount': tasks.length,
      },
      'summary': <String, dynamic>{
        'reviewTaskCount': reviewTasks.length,
        'attestationTemplateCount': sourceReady ? reviewTasks.length : 0,
        'releasePlanContractIssueCount': releasePlanIssues.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'localConfigIdsOmitted': true,
        'sourceArtifactPathsOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'reviewCompletionClaimsCreated': false,
      },
      'limitations': const <String, dynamic>{
        'consumesReleasePlanOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'attestationsApproved': false,
        'liveCommandsCreated': false,
        'runtimeConfigurationApplied': false,
        'aiConfigMutationsWritten': false,
      },
      'reviewTasks': reviewTasks,
      'attestationTemplates': [
        if (sourceReady)
          for (final task in reviewTasks)
            _attestationTemplate(
              sourceReleasePlanDigest: releasePlanDigest,
              sourceQueueDigest: sourceQueueDigest,
              sourceReleaseReviewPacketRef: '',
              task: task,
            ),
      ],
      'issues': [
        for (final issue in releasePlanIssues)
          <String, dynamic>{
            'code': 'releasePlan.contractInvalid',
            'severity': 'blocking',
            'message': issue,
          },
        if (releasePlanIssues.isEmpty && !sourceReady)
          <String, dynamic>{
            'code': 'releaseReview.sourceNotReady',
            'severity': 'blocking',
            'releasePlanStatus': releasePlanStatus,
          },
      ],
      'recommendedCommands': const [
        <String, dynamic>{
          'mode': 'release-review-packet',
          'command': 'eval/run_level2.sh release-review-packet',
        },
        <String, dynamic>{
          'mode': 'import-release-review',
          'command': 'eval/run_level2.sh import-release-review',
        },
        <String, dynamic>{
          'mode': 'release-plan',
          'command': 'eval/run_level2.sh release-plan',
        },
      ],
    };
    packet['releaseReviewPacketRef'] = releaseReviewPacketRef(packet);
    packet['sourceReleasePlan'] = <String, dynamic>{
      ..._map(packet['sourceReleasePlan']),
      'sourceReleaseReviewPacketRef': packet['releaseReviewPacketRef'],
    };
    packet['reviewTasks'] = [
      for (final task in _mapList(packet['reviewTasks']))
        <String, dynamic>{
          ...task,
          'sourceReleaseReviewPacketRef': packet['releaseReviewPacketRef'],
        },
    ];
    packet['attestationTemplates'] = [
      for (final template in _mapList(packet['attestationTemplates']))
        <String, dynamic>{
          ...template,
          'sourceReleaseReviewPacketRef': packet['releaseReviewPacketRef'],
        },
    ];
    assertValidPacket(packet);
    return packet;
  }

  static String releaseReviewPacketRef(Map<String, dynamic> packet) =>
      EvalProvenance.digestJson(_releaseReviewPacketSubject(packet));

  static List<String> validatePacket(Map<String, dynamic> packet) {
    final issues = <String>[];
    _expectEquals(
      issues,
      packet['schemaVersion'],
      packetSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, packet['kind'], packetKind, 'kind');
    _expectDigest(
      issues,
      packet['releaseReviewPacketRef'],
      'releaseReviewPacketRef',
    );
    _expectIsoDate(issues, packet['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, packet['status'], 'status');
    if (status != null && !_allowedPacketStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedPacketStatuses.join(', ')}');
    }
    final sourceReleasePlan = _expectMap(
      issues,
      packet['sourceReleasePlan'],
      'sourceReleasePlan',
    );
    _validateSourceReleasePlan(issues, sourceReleasePlan);
    final summary = _expectMap(issues, packet['summary'], 'summary');
    _validatePacketSummary(issues, summary);
    _validatePacketPrivacy(
      issues,
      _expectMap(issues, packet['privacy'], 'privacy'),
    );
    _validatePacketLimitations(
      issues,
      _expectMap(issues, packet['limitations'], 'limitations'),
    );
    final tasks = _expectList(issues, packet['reviewTasks'], 'reviewTasks');
    _validateReviewTasks(
      issues,
      tasks,
      sourceReleasePlan: sourceReleasePlan,
    );
    final templates = _expectList(
      issues,
      packet['attestationTemplates'],
      'attestationTemplates',
    );
    _validateAttestations(
      issues,
      templates,
      path: 'attestationTemplates',
      requireApproved: false,
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseReviewPacketRef: _string(packet['releaseReviewPacketRef']),
    );
    _validateIssues(issues, _expectList(issues, packet['issues'], 'issues'));
    _validateCommands(
      issues,
      _expectList(issues, packet['recommendedCommands'], 'recommendedCommands'),
      'recommendedCommands',
    );
    _validatePacketSummaryInvariants(
      issues,
      summary: summary,
      tasks: tasks,
      templates: templates,
    );
    _validateReviewEvidenceCoverage(
      issues,
      tasks: tasks,
      evidence: templates,
      evidencePath: 'attestationTemplates',
    );
    _validateReleaseReviewPacketRef(issues, packet);
    _validateNoPrivatePayloads(issues, packet, 'packet');
    return issues;
  }

  static void assertValidPacket(Map<String, dynamic> packet) {
    final issues = validatePacket(packet);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning release review packet:\n${issues.join('\n')}',
    );
  }

  static Map<String, dynamic> buildAttestationBundle({
    required Map<String, dynamic> releasePlan,
    required List<Map<String, dynamic>> attestations,
    Map<String, dynamic>? sourceRoadmap,
    List<Map<String, dynamic>> sourceDecisionLedgers = const [],
    List<Map<String, dynamic>> sourceRuntimeRolloutLedgers = const [],
    Map<String, dynamic>? previousReleasePlan,
    DateTime? generatedAt,
  }) {
    final releasePlanIssues = sourceRoadmap == null
        ? EvalUseCaseTuningReleasePlan.validate(releasePlan)
        : EvalUseCaseTuningReleasePlan.validateAgainstSources(
            releasePlan,
            roadmap: sourceRoadmap,
            sourceDecisionLedgers: sourceDecisionLedgers,
            sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
            previousReleasePlan: previousReleasePlan,
            requireDecisionLedgerSourceReplay: sourceDecisionLedgers.isNotEmpty,
          );
    final releasePlanDigest = EvalProvenance.digestJson(releasePlan);
    final expectedPacket = buildPacket(
      releasePlan: releasePlan,
      sourceRoadmap: sourceRoadmap,
      sourceDecisionLedgers: sourceDecisionLedgers,
      sourceRuntimeRolloutLedgers: sourceRuntimeRolloutLedgers,
      previousReleasePlan: previousReleasePlan,
    );
    final sourceReleaseReviewPacketRef = _string(
      expectedPacket['releaseReviewPacketRef'],
    );
    final queue = _map(releasePlan['releaseReviewQueue']);
    final sourceQueueDigest = EvalProvenance.digestJson(queue);
    final releasePlanStatus = _string(releasePlan['status']).isEmpty
        ? 'unknown'
        : _string(releasePlan['status']);
    final sourceReady =
        releasePlanIssues.isEmpty &&
        releasePlanStatus == _readyReleasePlanStatus;
    final tasks = releasePlanIssues.isEmpty && sourceReady
        ? _mapList(expectedPacket['reviewTasks'])
        : const <Map<String, dynamic>>[];
    final requiredTasks = [
      for (final task in tasks)
        if (task['required'] == true) task,
    ];
    final importIssues = _bundleImportIssues(
      requiredTasks: requiredTasks,
      attestations: attestations,
      releasePlanIssues: releasePlanIssues,
      releasePlanStatus: releasePlanStatus,
      sourceReady: sourceReady,
      sourceReleasePlanDigest: releasePlanDigest,
      sourceQueueDigest: sourceQueueDigest,
      sourceReleaseReviewPacketRef: sourceReleaseReviewPacketRef,
    );
    final approvedCount = attestations
        .where((attestation) => attestation['status'] == 'approved')
        .length;
    final rejectedCount = attestations
        .where(
          (attestation) =>
              attestation['status'] == 'rejected' ||
              attestation['status'] == 'needsChanges',
        )
        .length;
    final status = importIssues.isNotEmpty
        ? 'invalid'
        : rejectedCount > 0
        ? 'changesRequested'
        : 'approved';
    final bundle = <String, dynamic>{
      'schemaVersion': bundleSchemaVersion,
      'kind': bundleKind,
      'attestationBundleRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceReleasePlan': <String, dynamic>{
        'kind': EvalUseCaseTuningReleasePlan.kind,
        'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
        'status': releasePlanStatus,
        'releasePlanRef': _string(releasePlan['releasePlanRef']),
        'sourceRoadmapDigest': _string(
          _map(releasePlan['sourceRoadmap'])['roadmapDigest'],
        ),
        'releasePlanDigest': releasePlanDigest,
        'sourceQueueDigest': sourceQueueDigest,
        'sourceReleaseReviewPacketRef': sourceReleaseReviewPacketRef,
        'modelClassCoverageProofSummaryDigest': _string(
          _map(
            releasePlan['modelClassCoverageProofSummary'],
          )['proofSummaryDigest'],
        ),
        'contractIssueCount': releasePlanIssues.length,
        'assignmentCount': _mapList(releasePlan['runtimeAssignments']).length,
        'reviewTaskCount': _mapList(queue['tasks']).length,
      },
      'summary': <String, dynamic>{
        'requiredReviewTaskCount': requiredTasks.length,
        'attestationCount': attestations.length,
        'approvedAttestationCount': approvedCount,
        'rejectedAttestationCount': rejectedCount,
        'issueCount': importIssues.length,
      },
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
        'consumesReleasePlanAndReviewInputOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'commandsCreated': false,
        'runtimeConfigurationApplied': false,
        'aiConfigMutationsWritten': false,
      },
      'requiredReviewTasks': requiredTasks,
      'attestations': attestations,
      'issues': importIssues,
    };
    bundle['attestationBundleRef'] = attestationBundleRef(bundle);
    assertValidBundle(bundle);
    if (importIssues.isNotEmpty) {
      throw StateError(
        'Invalid use-case tuning release review attestation bundle:\n'
        '${importIssues.map((issue) => _string(issue['code'])).join('\n')}',
      );
    }
    return bundle;
  }

  static List<String> validateBundle(Map<String, dynamic> bundle) {
    final issues = <String>[];
    _expectEquals(
      issues,
      bundle['schemaVersion'],
      bundleSchemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, bundle['kind'], bundleKind, 'kind');
    _expectDigest(
      issues,
      bundle['attestationBundleRef'],
      'attestationBundleRef',
    );
    _expectIsoDate(issues, bundle['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, bundle['status'], 'status');
    if (status != null && !_allowedBundleStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedBundleStatuses.join(', ')}');
    }
    final sourceReleasePlan = _expectMap(
      issues,
      bundle['sourceReleasePlan'],
      'sourceReleasePlan',
    );
    _validateSourceReleasePlan(issues, sourceReleasePlan);
    final summary = _expectMap(issues, bundle['summary'], 'summary');
    _validateBundleSummary(issues, summary);
    _validateBundlePrivacy(
      issues,
      _expectMap(issues, bundle['privacy'], 'privacy'),
    );
    _validateBundleLimitations(
      issues,
      _expectMap(issues, bundle['limitations'], 'limitations'),
    );
    final requiredTasks = _expectList(
      issues,
      bundle['requiredReviewTasks'],
      'requiredReviewTasks',
    );
    _validateReviewTasks(
      issues,
      requiredTasks,
      path: 'requiredReviewTasks',
      sourceReleasePlan: sourceReleasePlan,
    );
    final attestations = _expectList(
      issues,
      bundle['attestations'],
      'attestations',
    );
    _validateAttestations(
      issues,
      attestations,
      path: 'attestations',
      requireApproved: false,
      sourceReleasePlan: sourceReleasePlan,
      sourceReleaseReviewPacketRef: _string(
        sourceReleasePlan?['sourceReleaseReviewPacketRef'],
      ),
    );
    final issueList = _expectList(issues, bundle['issues'], 'issues');
    _validateIssues(issues, issueList);
    _validateBundleSummaryInvariants(
      issues,
      summary: summary,
      requiredTasks: requiredTasks,
      attestations: attestations,
      issueList: issueList,
    );
    _validateReviewEvidenceCoverage(
      issues,
      tasks: requiredTasks,
      evidence: attestations,
      evidencePath: 'attestations',
    );
    _validateAttestationBundleRef(issues, bundle);
    _validateNoPrivatePayloads(issues, bundle, 'bundle');
    return issues;
  }

  static void assertValidBundle(Map<String, dynamic> bundle) {
    final issues = validateBundle(bundle);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning release review attestation bundle:\n'
      '${issues.join('\n')}',
    );
  }

  static List<String> validateBundleAgainstReleasePlan(
    Map<String, dynamic> bundle, {
    required Map<String, dynamic> releasePlan,
  }) {
    final issues = validateBundle(bundle);
    final releasePlanIssues = EvalUseCaseTuningReleasePlan.validate(
      releasePlan,
    );
    if (releasePlanIssues.isNotEmpty) {
      issues.add('source release plan contract is invalid');
      return issues;
    }
    final releasePlanStatus = _string(releasePlan['status']).isEmpty
        ? 'unknown'
        : _string(releasePlan['status']);
    if (releasePlanStatus != _readyReleasePlanStatus) {
      issues.add('sourceReleasePlan.status must match releasePlan');
      return issues;
    }
    final source = _map(bundle['sourceReleasePlan']);
    final queue = _map(releasePlan['releaseReviewQueue']);
    final expectedPacket = buildPacket(
      releasePlan: releasePlan,
      generatedAt: DateTime.utc(2026),
    );
    final expected = <String, dynamic>{
      'kind': EvalUseCaseTuningReleasePlan.kind,
      'schemaVersion': EvalUseCaseTuningReleasePlan.schemaVersion,
      'status': releasePlanStatus,
      'releasePlanRef': _string(releasePlan['releasePlanRef']),
      'sourceRoadmapDigest': _string(
        _map(releasePlan['sourceRoadmap'])['roadmapDigest'],
      ),
      'releasePlanDigest': EvalProvenance.digestJson(releasePlan),
      'sourceQueueDigest': EvalProvenance.digestJson(queue),
      'sourceReleaseReviewPacketRef': _string(
        expectedPacket['releaseReviewPacketRef'],
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
    for (final entry in expected.entries) {
      if (source[entry.key] != entry.value) {
        issues.add('sourceReleasePlan.${entry.key} must match releasePlan');
      }
    }
    return issues;
  }

  static void assertBundleMatchesReleasePlan(
    Map<String, dynamic> bundle, {
    required Map<String, dynamic> releasePlan,
  }) {
    final issues = validateBundleAgainstReleasePlan(
      bundle,
      releasePlan: releasePlan,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning release review bundle source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static List<Map<String, dynamic>> approvedAttestationsFromBundles(
    List<Map<String, dynamic>> bundles,
  ) {
    return [
      for (final bundle in bundles)
        if (validateBundle(bundle).isEmpty && bundle['status'] == 'approved')
          for (final attestation in _mapList(bundle['attestations']))
            if (attestation['status'] == 'approved') attestation,
    ];
  }

  static void assertBundlesValid(List<Map<String, dynamic>> bundles) {
    for (final (index, bundle) in bundles.indexed) {
      final issues = validateBundle(bundle);
      if (issues.isNotEmpty) {
        throw StateError(
          'Invalid use-case tuning release review attestation bundle '
          '$index:\n${issues.join('\n')}',
        );
      }
    }
  }

  static List<Map<String, dynamic>> approvedAttestationsFromValidBundles(
    List<Map<String, dynamic>> bundles,
  ) {
    assertBundlesValid(bundles);
    return [
      for (final bundle in bundles)
        if (bundle['status'] == 'approved')
          for (final attestation in _mapList(bundle['attestations']))
            if (attestation['status'] == 'approved') attestation,
    ];
  }

  static List<String> validateApprovedAttestations(
    List<Map<String, dynamic>> attestations,
  ) {
    final issues = <String>[];
    _validateAttestations(
      issues,
      attestations,
      path: 'releaseReviewAttestations',
      requireApproved: true,
    );
    return issues;
  }

  static String attestationBundleRef(Map<String, dynamic> bundle) =>
      EvalProvenance.digestJson(_attestationBundleSubject(bundle));

  static String attestationEvidenceDigest(Map<String, dynamic> attestation) =>
      EvalProvenance.digestJson(_attestationEvidenceSubject(attestation));

  static List<Map<String, dynamic>> _bundleImportIssues({
    required List<Map<String, dynamic>> requiredTasks,
    required List<Map<String, dynamic>> attestations,
    required List<String> releasePlanIssues,
    required String releasePlanStatus,
    required bool sourceReady,
    required String sourceReleasePlanDigest,
    required String sourceQueueDigest,
    required String sourceReleaseReviewPacketRef,
  }) {
    final issues = <Map<String, dynamic>>[
      for (final issue in releasePlanIssues)
        <String, dynamic>{
          'code': 'releasePlan.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (releasePlanIssues.isEmpty && !sourceReady)
        <String, dynamic>{
          'code': 'releaseReview.sourceNotReady',
          'severity': 'blocking',
          'releasePlanStatus': releasePlanStatus,
        },
    ];
    final attestationIssues = validateApprovedAttestations(
      attestations
          .where((attestation) => attestation['status'] == 'approved')
          .toList(),
    );
    final allAttestationIssues = <String>[];
    _validateAttestations(
      allAttestationIssues,
      attestations,
      path: 'attestations',
      requireApproved: false,
    );
    for (final issue in {...allAttestationIssues, ...attestationIssues}) {
      issues.add(
        <String, dynamic>{
          'code': 'releaseReviewAttestation.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      );
    }
    final requiredKeys = {
      for (final task in requiredTasks)
        _reviewKey(
          sourceReleasePlanDigest: sourceReleasePlanDigest,
          sourceQueueDigest: sourceQueueDigest,
          sourceReleaseReviewPacketRef: sourceReleaseReviewPacketRef,
          reviewRef: _string(task['reviewRef']),
          category: _string(task['category']),
          sourceReviewTaskDigest: _string(task['sourceReviewTaskDigest']),
          assignmentRefsDigest: _string(task['assignmentRefsDigest']),
          assignmentProofSummaryDigest: _string(
            task['assignmentProofSummaryDigest'],
          ),
          modelClassCoverageProofSummaryDigest: _string(
            task['modelClassCoverageProofSummaryDigest'],
          ),
        ): task,
    };
    final seen = <String, Map<String, dynamic>>{};
    for (final attestation in attestations) {
      final status = _string(attestation['status']);
      final key = _reviewKey(
        sourceReleasePlanDigest: _string(
          attestation['sourceReleasePlanDigest'],
        ),
        sourceQueueDigest: _string(attestation['sourceQueueDigest']),
        sourceReleaseReviewPacketRef: _string(
          attestation['sourceReleaseReviewPacketRef'],
        ),
        reviewRef: _string(attestation['reviewRef']),
        category: _string(attestation['category']),
        sourceReviewTaskDigest: _string(
          attestation['sourceReviewTaskDigest'],
        ),
        assignmentRefsDigest: _string(attestation['assignmentRefsDigest']),
        assignmentProofSummaryDigest: _string(
          attestation['assignmentProofSummaryDigest'],
        ),
        modelClassCoverageProofSummaryDigest: _string(
          attestation['modelClassCoverageProofSummaryDigest'],
        ),
      );
      if (status == 'pending') {
        issues.add(
          <String, dynamic>{
            'code': 'releaseReviewAttestation.pendingTask',
            'severity': 'blocking',
            'reviewRef': _string(attestation['reviewRef']),
            'category': _string(attestation['category']),
          },
        );
        continue;
      }
      if (_string(attestation['sourceReleasePlanDigest']) !=
          sourceReleasePlanDigest) {
        issues.add(
          const <String, dynamic>{
            'code': 'releaseReviewAttestation.sourceDigestMismatch',
            'severity': 'blocking',
          },
        );
      }
      if (_string(attestation['sourceQueueDigest']) != sourceQueueDigest) {
        issues.add(
          const <String, dynamic>{
            'code': 'releaseReviewAttestation.sourceQueueDigestMismatch',
            'severity': 'blocking',
          },
        );
      }
      if (_string(attestation['sourceReleaseReviewPacketRef']) !=
          sourceReleaseReviewPacketRef) {
        issues.add(
          const <String, dynamic>{
            'code': 'releaseReviewAttestation.sourcePacketMismatch',
            'severity': 'blocking',
          },
        );
      }
      if (!requiredKeys.containsKey(key)) {
        issues.add(
          <String, dynamic>{
            'code': 'releaseReviewAttestation.unmatchedTask',
            'severity': 'blocking',
            'reviewRef': _string(attestation['reviewRef']),
            'category': _string(attestation['category']),
          },
        );
      }
      if (seen.containsKey(key)) {
        issues.add(
          <String, dynamic>{
            'code': 'releaseReviewAttestation.duplicateTask',
            'severity': 'blocking',
            'reviewRef': _string(attestation['reviewRef']),
            'category': _string(attestation['category']),
          },
        );
      }
      seen[key] = attestation;
    }
    for (final key in requiredKeys.keys) {
      if (!seen.containsKey(key)) {
        final task = requiredKeys[key]!;
        issues.add(
          <String, dynamic>{
            'code': 'releaseReviewAttestation.missingTask',
            'severity': 'blocking',
            'reviewRef': _string(task['reviewRef']),
            'category': _string(task['category']),
          },
        );
      }
    }
    return issues;
  }

  static Map<String, dynamic> _reviewTask({
    required String releasePlanDigest,
    required String sourceQueueDigest,
    required Map<String, dynamic> task,
  }) {
    final subject = <String, dynamic>{
      'sourceReleasePlanDigest': releasePlanDigest,
      'sourceQueueDigest': sourceQueueDigest,
      'reviewRef': _string(task['reviewRef']),
      'category': _string(task['category']),
      'required': task['required'] == true,
      'sourceRoadmapDigest': _string(task['sourceRoadmapDigest']),
      'assignmentRefs': _stringList(task['assignmentRefs']),
      'assignmentRefsDigest': EvalProvenance.digestJson(
        _stringList(task['assignmentRefs']),
      ),
      'assignmentProofSummaryDigest': _string(
        task['assignmentProofSummaryDigest'],
      ),
      'modelClassCoverageProofSummaryDigest': _string(
        task['modelClassCoverageProofSummaryDigest'],
      ),
      'checklist': _stringList(task['checklist']),
      'blockerCodes': _stringList(task['blockerCodes']),
    };
    return <String, dynamic>{
      ...subject,
      'sourceReviewTaskDigest': _reviewTaskDigest(subject),
      'privateValuesOmitted': true,
      'commandsOmitted': true,
      'completionEvidenceOmitted': true,
    };
  }

  static Map<String, dynamic> _attestationTemplate({
    required String sourceReleasePlanDigest,
    required String sourceQueueDigest,
    required String sourceReleaseReviewPacketRef,
    required Map<String, dynamic> task,
  }) {
    return <String, dynamic>{
      'schemaVersion': attestationSchemaVersion,
      'kind': attestationKind,
      'sourceReleasePlanDigest': sourceReleasePlanDigest,
      'sourceQueueDigest': sourceQueueDigest,
      'sourceReleaseReviewPacketRef': sourceReleaseReviewPacketRef,
      'reviewRef': _string(task['reviewRef']),
      'category': _string(task['category']),
      'sourceReviewTaskDigest': _string(task['sourceReviewTaskDigest']),
      'assignmentRefsDigest': _string(task['assignmentRefsDigest']),
      'assignmentProofSummaryDigest': _string(
        task['assignmentProofSummaryDigest'],
      ),
      'modelClassCoverageProofSummaryDigest': _string(
        task['modelClassCoverageProofSummaryDigest'],
      ),
      'status': 'pending',
      'evidenceDigest': '',
      'privateValuesOmitted': true,
      'commandsOmitted': true,
      'reviewCompletionClaimsCreated': false,
    };
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
    _expectDigest(
      issues,
      source['releasePlanRef'],
      'sourceReleasePlan.releasePlanRef',
    );
    _expectDigest(
      issues,
      source['sourceRoadmapDigest'],
      'sourceReleasePlan.sourceRoadmapDigest',
    );
    _expectDigest(
      issues,
      source['releasePlanDigest'],
      'sourceReleasePlan.releasePlanDigest',
    );
    _expectDigest(
      issues,
      source['sourceQueueDigest'],
      'sourceReleasePlan.sourceQueueDigest',
    );
    _expectDigest(
      issues,
      source['sourceReleaseReviewPacketRef'],
      'sourceReleasePlan.sourceReleaseReviewPacketRef',
    );
    _expectDigest(
      issues,
      source['modelClassCoverageProofSummaryDigest'],
      'sourceReleasePlan.modelClassCoverageProofSummaryDigest',
    );
    for (final field in const [
      'contractIssueCount',
      'assignmentCount',
      'reviewTaskCount',
    ]) {
      _expectNonNegativeInt(issues, source[field], 'sourceReleasePlan.$field');
    }
  }

  static void _validatePacketSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'reviewTaskCount',
      'attestationTemplateCount',
      'releasePlanContractIssueCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validateBundleSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'requiredReviewTaskCount',
      'attestationCount',
      'approvedAttestationCount',
      'rejectedAttestationCount',
      'issueCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validatePacketPrivacy(
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
      'reviewCompletionClaimsCreated': false,
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

  static void _validateBundlePrivacy(
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

  static void _validatePacketLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesReleasePlanOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'attestationsApproved': false,
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

  static void _validateBundleLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesReleasePlanAndReviewInputOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'commandsCreated': false,
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

  static void _validateReviewTasks(
    List<String> issues,
    List<dynamic>? tasks, {
    String path = 'reviewTasks',
    Map<String, dynamic>? sourceReleasePlan,
  }) {
    if (tasks == null) return;
    for (final (index, value) in tasks.indexed) {
      final task = _expectMap(issues, value, '$path[$index]');
      if (task == null) continue;
      _expectDigest(
        issues,
        task['sourceReleasePlanDigest'],
        '$path[$index].sourceReleasePlanDigest',
      );
      _expectDigest(
        issues,
        task['sourceQueueDigest'],
        '$path[$index].sourceQueueDigest',
      );
      _expectDigest(
        issues,
        task['sourceReleaseReviewPacketRef'],
        '$path[$index].sourceReleaseReviewPacketRef',
      );
      _expectDigest(issues, task['reviewRef'], '$path[$index].reviewRef');
      _expectDigest(
        issues,
        task['sourceReviewTaskDigest'],
        '$path[$index].sourceReviewTaskDigest',
      );
      final category = _expectNonEmptyString(
        issues,
        task['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
      }
      _expectBool(issues, task['required'], '$path[$index].required');
      _expectDigest(
        issues,
        task['sourceRoadmapDigest'],
        '$path[$index].sourceRoadmapDigest',
      );
      _expectDigestList(
        issues,
        task['assignmentRefs'],
        '$path[$index].assignmentRefs',
      );
      _expectDigest(
        issues,
        task['assignmentRefsDigest'],
        '$path[$index].assignmentRefsDigest',
      );
      final expectedAssignmentRefsDigest = EvalProvenance.digestJson(
        _stringList(task['assignmentRefs']),
      );
      if (task['assignmentRefsDigest'] != expectedAssignmentRefsDigest) {
        issues.add(
          '$path[$index].assignmentRefsDigest must match assignmentRefs',
        );
      }
      _expectDigest(
        issues,
        task['assignmentProofSummaryDigest'],
        '$path[$index].assignmentProofSummaryDigest',
      );
      _expectDigest(
        issues,
        task['modelClassCoverageProofSummaryDigest'],
        '$path[$index].modelClassCoverageProofSummaryDigest',
      );
      if (task['modelClassCoverageProofSummaryDigest'] !=
          task['assignmentProofSummaryDigest']) {
        issues.add(
          '$path[$index].modelClassCoverageProofSummaryDigest must match assignmentProofSummaryDigest',
        );
      }
      if (task['reviewRef'] != _reviewRefFromTask(task)) {
        issues.add('$path[$index].reviewRef must match review subject digest');
      }
      if (task['sourceReviewTaskDigest'] != _reviewTaskDigest(task)) {
        issues.add(
          '$path[$index].sourceReviewTaskDigest must match review task subject digest',
        );
      }
      _validateReviewSourceDigests(
        issues,
        value: task,
        path: '$path[$index]',
        sourceReleasePlan: sourceReleasePlan,
      );
      final checklist = _expectStringList(
        issues,
        task['checklist'],
        '$path[$index].checklist',
      );
      if (checklist != null && checklist.isEmpty) {
        issues.add('$path[$index].checklist must not be empty');
      }
      _expectStringList(
        issues,
        task['blockerCodes'],
        '$path[$index].blockerCodes',
      );
      _expectEquals(
        issues,
        task['privateValuesOmitted'],
        true,
        '$path[$index].privateValuesOmitted',
      );
      _expectEquals(
        issues,
        task['commandsOmitted'],
        true,
        '$path[$index].commandsOmitted',
      );
      _expectEquals(
        issues,
        task['completionEvidenceOmitted'],
        true,
        '$path[$index].completionEvidenceOmitted',
      );
      if (task.containsKey('command') ||
          task.containsKey('commands') ||
          task.containsKey('env') ||
          task.containsKey('shell')) {
        issues.add('$path[$index] must be non-executable');
      }
    }
  }

  static void _validateAttestations(
    List<String> issues,
    List<dynamic>? attestations, {
    required String path,
    required bool requireApproved,
    Map<String, dynamic>? sourceReleasePlan,
    String? sourceReleaseReviewPacketRef,
  }) {
    if (attestations == null) return;
    for (final (index, value) in attestations.indexed) {
      final attestation = _expectMap(issues, value, '$path[$index]');
      if (attestation == null) continue;
      _expectEquals(
        issues,
        attestation['schemaVersion'],
        attestationSchemaVersion,
        '$path[$index].schemaVersion',
      );
      _expectEquals(
        issues,
        attestation['kind'],
        attestationKind,
        '$path[$index].kind',
      );
      _expectDigest(
        issues,
        attestation['sourceReleasePlanDigest'],
        '$path[$index].sourceReleasePlanDigest',
      );
      _expectDigest(
        issues,
        attestation['sourceQueueDigest'],
        '$path[$index].sourceQueueDigest',
      );
      _expectDigest(
        issues,
        attestation['sourceReleaseReviewPacketRef'],
        '$path[$index].sourceReleaseReviewPacketRef',
      );
      _expectDigest(
        issues,
        attestation['reviewRef'],
        '$path[$index].reviewRef',
      );
      _expectDigest(
        issues,
        attestation['sourceReviewTaskDigest'],
        '$path[$index].sourceReviewTaskDigest',
      );
      _expectDigest(
        issues,
        attestation['assignmentRefsDigest'],
        '$path[$index].assignmentRefsDigest',
      );
      _expectDigest(
        issues,
        attestation['assignmentProofSummaryDigest'],
        '$path[$index].assignmentProofSummaryDigest',
      );
      _expectDigest(
        issues,
        attestation['modelClassCoverageProofSummaryDigest'],
        '$path[$index].modelClassCoverageProofSummaryDigest',
      );
      if (attestation['modelClassCoverageProofSummaryDigest'] !=
          attestation['assignmentProofSummaryDigest']) {
        issues.add(
          '$path[$index].modelClassCoverageProofSummaryDigest must match assignmentProofSummaryDigest',
        );
      }
      _validateReviewSourceDigests(
        issues,
        value: attestation,
        path: '$path[$index]',
        sourceReleasePlan: sourceReleasePlan,
      );
      if (sourceReleaseReviewPacketRef != null &&
          _string(attestation['sourceReleaseReviewPacketRef']) !=
              sourceReleaseReviewPacketRef) {
        issues.add(
          '$path[$index].sourceReleaseReviewPacketRef must match releaseReviewPacketRef',
        );
      }
      final status = _expectNonEmptyString(
        issues,
        attestation['status'],
        '$path[$index].status',
      );
      if (status != null && !_allowedAttestationStatuses.contains(status)) {
        issues.add('$path[$index].status must be supported');
      }
      if (requireApproved && status != 'approved') {
        issues.add('$path[$index].status must be approved');
      }
      final evidenceDigest = attestation['evidenceDigest'];
      if (status == 'pending') {
        _expectEquals(
          issues,
          evidenceDigest,
          '',
          '$path[$index].evidenceDigest',
        );
      } else {
        _expectDigest(
          issues,
          evidenceDigest,
          '$path[$index].evidenceDigest',
        );
        if (evidenceDigest != attestationEvidenceDigest(attestation)) {
          issues.add(
            '$path[$index].evidenceDigest must match attestation evidence subject digest',
          );
        }
        _expectDigest(
          issues,
          attestation['reviewerRefDigest'],
          '$path[$index].reviewerRefDigest',
        );
        _expectIsoDate(
          issues,
          attestation['reviewedAt'],
          '$path[$index].reviewedAt',
        );
      }
      final category = _expectNonEmptyString(
        issues,
        attestation['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
      }
      _expectEquals(
        issues,
        attestation['privateValuesOmitted'],
        true,
        '$path[$index].privateValuesOmitted',
      );
      _expectEquals(
        issues,
        attestation['commandsOmitted'],
        true,
        '$path[$index].commandsOmitted',
      );
      _expectEquals(
        issues,
        attestation['reviewCompletionClaimsCreated'],
        false,
        '$path[$index].reviewCompletionClaimsCreated',
      );
      for (final forbidden in const [
        'command',
        'commands',
        'env',
        'nextRunEnv',
        'recommendedCommands',
        'shell',
        'shellCommand',
        'reviewedBy',
        'reviewer',
        'reviewerRef',
        'scenarioIds',
        'profileNames',
        'runId',
        'baseRunId',
        'completionEvidence',
        'localConfigId',
        'modelConfigId',
        'profileId',
        'agentId',
        'taskId',
        'templateId',
        'categoryId',
        'providerId',
      ]) {
        if (attestation.containsKey(forbidden)) {
          issues.add('$path[$index] must not contain $forbidden');
        }
      }
      _validateNoPrivatePayloads(issues, attestation, '$path[$index]');
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

  static void _validatePacketSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? tasks,
    required List<dynamic>? templates,
  }) {
    if (summary == null) return;
    if (tasks != null &&
        summary['reviewTaskCount'] is int &&
        summary['reviewTaskCount'] != tasks.length) {
      issues.add('summary.reviewTaskCount must match reviewTasks.length');
    }
    if (templates != null &&
        summary['attestationTemplateCount'] is int &&
        summary['attestationTemplateCount'] != templates.length) {
      issues.add(
        'summary.attestationTemplateCount must match templates.length',
      );
    }
  }

  static void _validateBundleSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? requiredTasks,
    required List<dynamic>? attestations,
    required List<dynamic>? issueList,
  }) {
    if (summary == null) return;
    if (requiredTasks != null &&
        summary['requiredReviewTaskCount'] is int &&
        summary['requiredReviewTaskCount'] != requiredTasks.length) {
      issues.add(
        'summary.requiredReviewTaskCount must match requiredReviewTasks.length',
      );
    }
    if (attestations != null &&
        summary['attestationCount'] is int &&
        summary['attestationCount'] != attestations.length) {
      issues.add('summary.attestationCount must match attestations.length');
    }
    if (issueList != null &&
        summary['issueCount'] is int &&
        summary['issueCount'] != issueList.length) {
      issues.add('summary.issueCount must match issues.length');
    }
  }

  static void _validateReviewSourceDigests(
    List<String> issues, {
    required Map<String, dynamic> value,
    required String path,
    required Map<String, dynamic>? sourceReleasePlan,
  }) {
    if (sourceReleasePlan == null) return;
    if (_string(value['sourceReleasePlanDigest']) !=
        _string(sourceReleasePlan['releasePlanDigest'])) {
      issues.add(
        '$path.sourceReleasePlanDigest must match sourceReleasePlan.releasePlanDigest',
      );
    }
    if (_string(value['sourceQueueDigest']) !=
        _string(sourceReleasePlan['sourceQueueDigest'])) {
      issues.add(
        '$path.sourceQueueDigest must match sourceReleasePlan.sourceQueueDigest',
      );
    }
    if (value.containsKey('sourceReleaseReviewPacketRef') &&
        _string(value['sourceReleaseReviewPacketRef']) !=
            _string(sourceReleasePlan['sourceReleaseReviewPacketRef'])) {
      issues.add(
        '$path.sourceReleaseReviewPacketRef must match sourceReleasePlan.sourceReleaseReviewPacketRef',
      );
    }
    if (value.containsKey('sourceRoadmapDigest') &&
        _string(value['sourceRoadmapDigest']) !=
            _string(sourceReleasePlan['sourceRoadmapDigest'])) {
      issues.add(
        '$path.sourceRoadmapDigest must match sourceReleasePlan.sourceRoadmapDigest',
      );
    }
    if (_string(value['modelClassCoverageProofSummaryDigest']) !=
        _string(sourceReleasePlan['modelClassCoverageProofSummaryDigest'])) {
      issues.add(
        '$path.modelClassCoverageProofSummaryDigest must match sourceReleasePlan.modelClassCoverageProofSummaryDigest',
      );
    }
  }

  static void _validateReviewEvidenceCoverage(
    List<String> issues, {
    required List<dynamic>? tasks,
    required List<dynamic>? evidence,
    required String evidencePath,
  }) {
    if (tasks == null || evidence == null) return;
    final taskKeys = {
      for (final task in _mapList(tasks)) _reviewKeyFromTask(task),
    };
    final seenEvidenceKeys = <String>{};
    for (final (index, item) in evidence.indexed) {
      if (item is! Map<String, dynamic>) continue;
      final key = _reviewKeyFromAttestation(item);
      if (!taskKeys.contains(key)) {
        issues.add('$evidencePath[$index] must match a review task');
      }
      if (!seenEvidenceKeys.add(key)) {
        issues.add('$evidencePath[$index] must not duplicate a review task');
      }
    }
    for (final key in taskKeys) {
      if (!seenEvidenceKeys.contains(key)) {
        issues.add('$evidencePath must include every review task');
      }
    }
  }

  static String _reviewKey({
    required String sourceReleasePlanDigest,
    required String sourceQueueDigest,
    required String sourceReleaseReviewPacketRef,
    required String reviewRef,
    required String category,
    required String sourceReviewTaskDigest,
    required String assignmentRefsDigest,
    required String assignmentProofSummaryDigest,
    required String modelClassCoverageProofSummaryDigest,
  }) => [
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

  static String _reviewKeyFromTask(Map<String, dynamic> task) => _reviewKey(
    sourceReleasePlanDigest: _string(task['sourceReleasePlanDigest']),
    sourceQueueDigest: _string(task['sourceQueueDigest']),
    sourceReleaseReviewPacketRef: _string(
      task['sourceReleaseReviewPacketRef'],
    ),
    reviewRef: _string(task['reviewRef']),
    category: _string(task['category']),
    sourceReviewTaskDigest: _string(task['sourceReviewTaskDigest']),
    assignmentRefsDigest: _string(task['assignmentRefsDigest']),
    assignmentProofSummaryDigest: _string(
      task['assignmentProofSummaryDigest'],
    ),
    modelClassCoverageProofSummaryDigest: _string(
      task['modelClassCoverageProofSummaryDigest'],
    ),
  );

  static String _reviewKeyFromAttestation(Map<String, dynamic> attestation) =>
      _reviewKey(
        sourceReleasePlanDigest: _string(
          attestation['sourceReleasePlanDigest'],
        ),
        sourceQueueDigest: _string(attestation['sourceQueueDigest']),
        sourceReleaseReviewPacketRef: _string(
          attestation['sourceReleaseReviewPacketRef'],
        ),
        reviewRef: _string(attestation['reviewRef']),
        category: _string(attestation['category']),
        sourceReviewTaskDigest: _string(
          attestation['sourceReviewTaskDigest'],
        ),
        assignmentRefsDigest: _string(attestation['assignmentRefsDigest']),
        assignmentProofSummaryDigest: _string(
          attestation['assignmentProofSummaryDigest'],
        ),
        modelClassCoverageProofSummaryDigest: _string(
          attestation['modelClassCoverageProofSummaryDigest'],
        ),
      );

  static void _validateReleaseReviewPacketRef(
    List<String> issues,
    Map<String, dynamic> packet,
  ) {
    final expectedRef = releaseReviewPacketRef(packet);
    if (packet['releaseReviewPacketRef'] != expectedRef) {
      issues.add(
        'releaseReviewPacketRef must match release review packet subject digest',
      );
    }
  }

  static void _validateAttestationBundleRef(
    List<String> issues,
    Map<String, dynamic> bundle,
  ) {
    final expectedRef = attestationBundleRef(bundle);
    if (bundle['attestationBundleRef'] != expectedRef) {
      issues.add(
        'attestationBundleRef must match release review bundle subject digest',
      );
    }
  }

  static Map<String, dynamic> _releaseReviewPacketSubject(
    Map<String, dynamic> packet,
  ) => <String, dynamic>{
    'kind': packetKind,
    'schemaVersion': packetSchemaVersion,
    'status': _string(packet['status']),
    'sourceReleasePlanDigest': EvalProvenance.digestJson(
      _packetSourceReleasePlanSubject(_map(packet['sourceReleasePlan'])),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(packet['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(packet['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(packet['limitations']),
    ),
    'reviewTasksDigest': EvalProvenance.digestJson(
      [
        for (final task in _mapList(packet['reviewTasks']))
          _packetReviewTaskSubject(task),
      ],
    ),
    'attestationTemplatesDigest': EvalProvenance.digestJson(
      [
        for (final template in _mapList(packet['attestationTemplates']))
          _packetAttestationTemplateSubject(template),
      ],
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(packet['issues'])),
    'recommendedCommandsDigest': EvalProvenance.digestJson(
      _mapList(packet['recommendedCommands']),
    ),
  };

  static Map<String, dynamic> _packetSourceReleasePlanSubject(
    Map<String, dynamic> sourceReleasePlan,
  ) => <String, dynamic>{
    for (final entry in sourceReleasePlan.entries)
      if (entry.key != 'sourceReleaseReviewPacketRef') entry.key: entry.value,
  };

  static Map<String, dynamic> _packetAttestationTemplateSubject(
    Map<String, dynamic> template,
  ) => <String, dynamic>{
    for (final entry in template.entries)
      if (entry.key != 'sourceReleaseReviewPacketRef') entry.key: entry.value,
  };

  static Map<String, dynamic> _packetReviewTaskSubject(
    Map<String, dynamic> task,
  ) => <String, dynamic>{
    for (final entry in task.entries)
      if (entry.key != 'sourceReleaseReviewPacketRef') entry.key: entry.value,
  };

  static Map<String, dynamic> _attestationBundleSubject(
    Map<String, dynamic> bundle,
  ) => <String, dynamic>{
    'kind': bundleKind,
    'schemaVersion': bundleSchemaVersion,
    'status': _string(bundle['status']),
    'sourceReleasePlanDigest': EvalProvenance.digestJson(
      _map(bundle['sourceReleasePlan']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(bundle['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(bundle['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(bundle['limitations']),
    ),
    'requiredReviewTasksDigest': EvalProvenance.digestJson(
      _mapList(bundle['requiredReviewTasks']),
    ),
    'attestationsDigest': EvalProvenance.digestJson(
      _mapList(bundle['attestations']),
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(bundle['issues'])),
  };

  static String _reviewRefFromTask(Map<String, dynamic> task) =>
      EvalProvenance.digestJson(<String, dynamic>{
        'sourceRoadmapDigest': _string(task['sourceRoadmapDigest']),
        'category': _string(task['category']),
        'assignmentRefs': _stringList(task['assignmentRefs']),
        'assignmentProofSummaryDigest': _string(
          task['assignmentProofSummaryDigest'],
        ),
        'modelClassCoverageProofSummaryDigest': _string(
          task['modelClassCoverageProofSummaryDigest'],
        ),
      });

  static String _reviewTaskDigest(Map<String, dynamic> task) =>
      EvalProvenance.digestJson(_reviewTaskSubject(task));

  static Map<String, dynamic> _reviewTaskSubject(Map<String, dynamic> task) =>
      <String, dynamic>{
        'sourceReleasePlanDigest': _string(task['sourceReleasePlanDigest']),
        'sourceQueueDigest': _string(task['sourceQueueDigest']),
        'reviewRef': _string(task['reviewRef']),
        'category': _string(task['category']),
        'required': task['required'] == true,
        'sourceRoadmapDigest': _string(task['sourceRoadmapDigest']),
        'assignmentRefs': _stringList(task['assignmentRefs']),
        'assignmentRefsDigest': _string(task['assignmentRefsDigest']),
        'assignmentProofSummaryDigest': _string(
          task['assignmentProofSummaryDigest'],
        ),
        'modelClassCoverageProofSummaryDigest': _string(
          task['modelClassCoverageProofSummaryDigest'],
        ),
        'checklist': _stringList(task['checklist']),
        'blockerCodes': _stringList(task['blockerCodes']),
      };

  static Map<String, dynamic> _attestationEvidenceSubject(
    Map<String, dynamic> attestation,
  ) => <String, dynamic>{
    'kind': attestationKind,
    'schemaVersion': attestationSchemaVersion,
    'sourceReleasePlanDigest': _string(
      attestation['sourceReleasePlanDigest'],
    ),
    'sourceQueueDigest': _string(attestation['sourceQueueDigest']),
    'sourceReleaseReviewPacketRef': _string(
      attestation['sourceReleaseReviewPacketRef'],
    ),
    'reviewRef': _string(attestation['reviewRef']),
    'category': _string(attestation['category']),
    'sourceReviewTaskDigest': _string(
      attestation['sourceReviewTaskDigest'],
    ),
    'assignmentRefsDigest': _string(attestation['assignmentRefsDigest']),
    'assignmentProofSummaryDigest': _string(
      attestation['assignmentProofSummaryDigest'],
    ),
    'modelClassCoverageProofSummaryDigest': _string(
      attestation['modelClassCoverageProofSummaryDigest'],
    ),
    'status': _string(attestation['status']),
    'reviewerRefDigest': _string(attestation['reviewerRefDigest']),
    'reviewedAt': _string(attestation['reviewedAt']),
    'privateValuesOmitted': attestation['privateValuesOmitted'] == true,
    'commandsOmitted': attestation['commandsOmitted'] == true,
    'reviewCompletionClaimsCreated':
        attestation['reviewCompletionClaimsCreated'] == true,
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

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) item,
  ];
}

String _string(Object? value) => value is String ? value : '';

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}
