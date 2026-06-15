import 'eval_provenance.dart';
import 'eval_use_case_adversarial_review.dart';
import 'eval_use_case_tuning_campaign.dart';
import 'eval_use_case_tuning_matrix.dart';

abstract final class EvalUseCaseTuningDecisionLedger {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseTuningDecisionLedger';
  static const _allowedStatuses = {
    'invalid',
    'blockedCampaign',
    'staleMatrix',
    'blockedReview',
    'conflict',
    'accepted',
    'watchOnly',
    'blocked',
  };
  static const _allowedDecisionStatuses = {
    'accepted',
    'conflict',
    'reviewBlocked',
    'staleEvidence',
    'watch',
    'blocked',
  };
  static const _allowedContinuityStatuses = {
    'unchanged',
    'revalidateRequired',
    'rollbackRequired',
  };
  static const _allowedReviewCategories = {
    'privacyAudit',
    'reportLinkageAudit',
    'modelClassCoverageAudit',
    'blockerRegressionAudit',
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
  static final Expando<String> _verifiedSourceReplayDigests = Expando<String>(
    'evalUseCaseTuningDecisionLedgerSourceReplayDigest',
  );

  static Map<String, dynamic> build({
    required Map<String, dynamic> matrix,
    Map<String, dynamic>? campaign,
    Map<String, dynamic>? previousLedger,
    List<Map<String, dynamic>> reviewAttestations = const [],
    bool requireMatrixSourceReplay = false,
    bool requireCampaignSourceReplay = false,
    bool requirePreviousLedgerSourceReplay = false,
    DateTime? generatedAt,
  }) {
    final matrixContractIssues = EvalUseCaseTuningMatrix.validate(matrix);
    final matrixIssues = [
      ...matrixContractIssues,
      if (requireMatrixSourceReplay &&
          matrixContractIssues.isEmpty &&
          !EvalUseCaseTuningMatrix.hasVerifiedSourceReplay(matrix))
        'matrix source replay must be verified',
    ];
    final campaignContractIssues = campaign == null
        ? const <String>[]
        : EvalUseCaseTuningCampaign.validate(campaign);
    final campaignIssues = [
      ...campaignContractIssues,
      if (campaign != null &&
          requireCampaignSourceReplay &&
          campaignContractIssues.isEmpty &&
          !EvalUseCaseTuningCampaign.hasVerifiedSourceReplay(campaign))
        'campaign source replay must be verified',
    ];
    final previousContractIssues = previousLedger == null
        ? const <String>[]
        : validate(previousLedger);
    final previousIssues = [
      ...previousContractIssues,
      if (previousLedger != null &&
          requirePreviousLedgerSourceReplay &&
          previousContractIssues.isEmpty &&
          !hasVerifiedSourceReplay(previousLedger))
        'previous ledger source replay must be verified',
    ];
    final matrixDigest = EvalProvenance.digestJson(matrix);
    final campaignDigest = campaign == null
        ? ''
        : EvalProvenance.digestJson(campaign);
    final campaignRef = campaign == null
        ? ''
        : EvalUseCaseTuningCampaign.campaignRef(campaign);
    final campaignQueueDigest = campaign != null && campaignIssues.isEmpty
        ? EvalProvenance.digestJson(_map(campaign['adversarialReviewQueue']))
        : '';
    final matrixReports = matrixIssues.isEmpty
        ? _inputReportsByRef(matrix)
        : const <String, _InputReport>{};
    final campaignReports = campaign != null && campaignIssues.isEmpty
        ? _inputReportsByRef(campaign)
        : const <String, _InputReport>{};
    final campaignCoverages = campaign != null && campaignIssues.isEmpty
        ? _inputModelClassCoveragesByRef(campaign)
        : const <String, _InputModelClassCoverage>{};
    final readyCampaign = campaign != null && campaignIssues.isEmpty
        ? _readyCampaignEvidence(
            campaign,
            campaignReports,
            campaignCoverages,
          )
        : const <_CampaignEvidence>[];
    final matrixReportDigests = {
      for (final report in matrixReports.values) report.reportDigest,
    };
    final readyCampaignReportDigests = {
      for (final evidence in readyCampaign) ...evidence.readyReportDigests,
    };
    final sourceCheckedMatrixReportDigests = {
      for (final report in matrixReports.values)
        if (report.isSourceChecked) report.reportDigest,
    };
    final sourceCheckedReadyCampaignReportDigests = {
      for (final evidence in readyCampaign)
        ...evidence.sourceCheckedReadyReportDigests,
    };
    final readyCampaignCoverageDigests = {
      for (final evidence in readyCampaign)
        for (final coverage in evidence.modelClassCoverages)
          coverage.coverageDigest,
    };
    final missingCampaignReportDigests = _sortedStrings(
      readyCampaignReportDigests.where(
        (digest) => !matrixReportDigests.contains(digest),
      ),
    );
    final reviewRequirements = campaign != null && campaignIssues.isEmpty
        ? _reviewRequirements(
            sourceDigest: campaignDigest,
            sourceQueueDigest: campaignQueueDigest,
            queue: _map(campaign['adversarialReviewQueue']),
          )
        : const <_ReviewRequirement>[];
    final attestationIssues = _validateReviewAttestations(
      reviewAttestations,
      requirements: reviewRequirements,
    );
    final reviewStatus = _reviewStatus(
      requirements: reviewRequirements,
      attestations: reviewAttestations,
    );
    final artifactIssues = _artifactIssues(
      matrixIssues: matrixIssues,
      campaign: campaign,
      campaignIssues: campaignIssues,
      previousIssues: previousIssues,
      attestationIssues: attestationIssues,
      missingCampaignReportDigests: missingCampaignReportDigests,
      reviewStatus: reviewStatus,
    );
    final cells = matrixIssues.isEmpty
        ? _mapList(matrix['matrixCells'])
        : const <Map<String, dynamic>>[];
    final decisions = _decisions(
      cells: cells,
      matrixReports: matrixReports,
      campaignEvidence: readyCampaign,
      campaignPresent: campaign != null,
      campaignValid: campaignIssues.isEmpty,
      staleMatrix: missingCampaignReportDigests.isNotEmpty,
      reviewApproved: reviewStatus.approved && attestationIssues.isEmpty,
    );
    final continuity = previousLedger == null
        ? const <Map<String, dynamic>>[]
        : _continuity(previousLedger, decisions);
    final blockedCodes = _blockedReasonCodes(
      artifactIssues: artifactIssues,
      decisions: decisions,
      continuity: continuity,
    );
    final status = _status(
      artifactIssues: artifactIssues,
      campaign: campaign,
      campaignIssues: campaignIssues,
      missingCampaignReportDigests: missingCampaignReportDigests,
      reviewStatus: reviewStatus,
      decisions: decisions,
      continuity: continuity,
    );

    final ledger = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'decisionLedgerRef': '',
      'sourceMatrix': <String, dynamic>{
        'kind': EvalUseCaseTuningMatrix.kind,
        'schemaVersion': EvalUseCaseTuningMatrix.schemaVersion,
        'status': _string(matrix['status']).isEmpty
            ? 'unknown'
            : _string(matrix['status']),
        'matrixDigest': matrixDigest,
        'contractIssueCount': matrixIssues.length,
        'inputReportDigestCount': matrixReportDigests.length,
        'sourceCheckedInputReportDigestCount':
            sourceCheckedMatrixReportDigests.length,
      },
      'sourceCampaign': <String, dynamic>{
        'present': campaign != null,
        if (campaign != null) ...<String, dynamic>{
          'kind': EvalUseCaseTuningCampaign.kind,
          'schemaVersion': EvalUseCaseTuningCampaign.schemaVersion,
          'status': _string(campaign['status']).isEmpty
              ? 'unknown'
              : _string(campaign['status']),
          'campaignRef': campaignRef,
          'campaignDigest': campaignDigest,
          'contractIssueCount': campaignIssues.length,
          'readyReportDigestCount': readyCampaignReportDigests.length,
          'sourceCheckedReadyReportDigestCount':
              sourceCheckedReadyCampaignReportDigests.length,
          'readyModelClassCoverageDigestCount':
              readyCampaignCoverageDigests.length,
          'missingReadyReportDigestCount': missingCampaignReportDigests.length,
        },
      },
      'summary': <String, dynamic>{
        'decisionCount': decisions.length,
        'acceptedDecisionCount': _statusCount(decisions, 'accepted'),
        'conflictDecisionCount': _statusCount(decisions, 'conflict'),
        'watchDecisionCount': _statusCount(decisions, 'watch'),
        'blockedDecisionCount':
            _statusCount(decisions, 'blocked') +
            _statusCount(decisions, 'reviewBlocked') +
            _statusCount(decisions, 'staleEvidence'),
        'previousAcceptedDecisionCount': continuity.length,
        'rollbackRequiredCount': _statusCount(
          continuity,
          'rollbackRequired',
        ),
        'reviewRequirementCount': reviewRequirements.length,
        'missingReviewAttestationCount':
            reviewStatus.missingRequirements.length,
        'blockedReasonCount': blockedCodes.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'promotionClaimsRequireSourceEvidence': true,
      },
      'limitations': const <String, dynamic>{
        'consumesMatrixCampaignAndAttestationsOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'liveCommandsCreated': false,
      },
      'blockedReasonCodes': blockedCodes,
      'reviewGate': reviewStatus.toJson(),
      'matrixRefreshEvidence': <String, dynamic>{
        'readyCampaignReportDigestCount': readyCampaignReportDigests.length,
        'matrixReportDigestCount': matrixReportDigests.length,
        'missingReadyReportDigestCount': missingCampaignReportDigests.length,
        'missingReadyReportDigests': missingCampaignReportDigests,
      },
      'decisions': decisions,
      'previousDecisionContinuity': continuity,
      'issues': artifactIssues,
      'recommendedCommands': _recommendedCommands(status),
    };
    ledger['decisionLedgerRef'] = decisionLedgerRef(ledger);
    assertValid(ledger);
    return ledger;
  }

  static String decisionLedgerRef(Map<String, dynamic> ledger) =>
      EvalProvenance.digestJson(_decisionLedgerSubject(ledger));

  static bool hasVerifiedSourceReplay(Map<String, dynamic> ledger) =>
      _verifiedSourceReplayDigests[ledger] == EvalProvenance.digestJson(ledger);

  static List<String> validate(Map<String, dynamic> ledger) {
    final issues = <String>[];
    _expectEquals(
      issues,
      ledger['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, ledger['kind'], kind, 'kind');
    _expectIsoDate(issues, ledger['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, ledger['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    _expectDigest(issues, ledger['decisionLedgerRef'], 'decisionLedgerRef');
    _validateSourceMatrix(
      issues,
      _expectMap(issues, ledger['sourceMatrix'], 'sourceMatrix'),
    );
    final sourceCampaign = _expectMap(
      issues,
      ledger['sourceCampaign'],
      'sourceCampaign',
    );
    _validateSourceCampaign(issues, sourceCampaign);
    final summary = _expectMap(issues, ledger['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(issues, _expectMap(issues, ledger['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, ledger['limitations'], 'limitations'),
    );
    final blockedReasonCodes = _expectStringList(
      issues,
      ledger['blockedReasonCodes'],
      'blockedReasonCodes',
    );
    final reviewGate = _expectMap(
      issues,
      ledger['reviewGate'],
      'reviewGate',
    );
    _validateReviewGate(issues, reviewGate);
    _validateReviewGateInvariants(issues, reviewGate);
    final matrixRefreshEvidence = _expectMap(
      issues,
      ledger['matrixRefreshEvidence'],
      'matrixRefreshEvidence',
    );
    _validateMatrixRefreshEvidence(
      issues,
      matrixRefreshEvidence,
    );
    final decisions = _expectList(issues, ledger['decisions'], 'decisions');
    _validateDecisions(issues, decisions);
    final continuity = _expectList(
      issues,
      ledger['previousDecisionContinuity'],
      'previousDecisionContinuity',
    );
    _validateContinuity(issues, continuity);
    final issueList = _expectList(issues, ledger['issues'], 'issues');
    _validateIssues(issues, issueList);
    final commands = _expectList(
      issues,
      ledger['recommendedCommands'],
      'recommendedCommands',
    );
    _validateCommands(issues, commands, 'recommendedCommands');
    _validateSummaryInvariants(
      issues,
      summary: summary,
      sourceCampaign: sourceCampaign,
      matrixRefreshEvidence: matrixRefreshEvidence,
      reviewGate: reviewGate,
      decisions: decisions,
      continuity: continuity,
      issueList: issueList,
      blockedReasonCodes: blockedReasonCodes,
    );
    _validateStatusInvariant(
      issues,
      ledger,
      sourceCampaign: sourceCampaign,
      matrixRefreshEvidence: matrixRefreshEvidence,
      reviewGate: reviewGate,
      decisions: decisions,
      continuity: continuity,
      issueList: issueList,
    );
    _validateDecisionLedgerRef(issues, ledger);
    _validateNoPrivatePayloads(issues, ledger, 'ledger');
    return issues;
  }

  static void assertValid(Map<String, dynamic> ledger) {
    final issues = validate(ledger);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning decision ledger:\n${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstSources(
    Map<String, dynamic> ledger, {
    required Map<String, dynamic> matrix,
    Map<String, dynamic>? campaign,
    Map<String, dynamic>? previousLedger,
    List<Map<String, dynamic>> reviewAttestations = const [],
    bool requireMatrixSourceReplay = true,
    bool requireCampaignSourceReplay = true,
    bool requirePreviousLedgerSourceReplay = true,
  }) {
    final issues = validate(ledger);
    final generatedAt = DateTime.tryParse(_string(ledger['generatedAt']));
    if (generatedAt == null) {
      issues.add('generatedAt must be an ISO-8601 timestamp');
      return issues;
    }
    Map<String, dynamic> expected;
    try {
      expected = build(
        matrix: matrix,
        campaign: campaign,
        previousLedger: previousLedger,
        reviewAttestations: reviewAttestations,
        requireMatrixSourceReplay: requireMatrixSourceReplay,
        requireCampaignSourceReplay:
            campaign != null && requireCampaignSourceReplay,
        requirePreviousLedgerSourceReplay:
            previousLedger != null && requirePreviousLedgerSourceReplay,
        generatedAt: generatedAt,
      );
    } catch (error) {
      issues.add('source artifacts cannot build decision ledger: $error');
      return issues;
    }

    void expectMatches(String field) {
      if (EvalProvenance.digestJson(ledger[field]) ==
          EvalProvenance.digestJson(expected[field])) {
        return;
      }
      issues.add('$field must match decision ledger source artifacts');
    }

    const [
      'status',
      'sourceMatrix',
      'sourceCampaign',
      'summary',
      'privacy',
      'limitations',
      'blockedReasonCodes',
      'reviewGate',
      'matrixRefreshEvidence',
      'decisions',
      'previousDecisionContinuity',
      'issues',
      'recommendedCommands',
    ].forEach(expectMatches);
    if (_string(ledger['decisionLedgerRef']) !=
        _string(expected['decisionLedgerRef'])) {
      issues.add(
        'decisionLedgerRef must match decision ledger source artifacts',
      );
    }
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> ledger, {
    required Map<String, dynamic> matrix,
    Map<String, dynamic>? campaign,
    Map<String, dynamic>? previousLedger,
    List<Map<String, dynamic>> reviewAttestations = const [],
    bool requireMatrixSourceReplay = true,
    bool requireCampaignSourceReplay = true,
    bool requirePreviousLedgerSourceReplay = true,
  }) {
    final issues = validateAgainstSources(
      ledger,
      matrix: matrix,
      campaign: campaign,
      previousLedger: previousLedger,
      reviewAttestations: reviewAttestations,
      requireMatrixSourceReplay: requireMatrixSourceReplay,
      requireCampaignSourceReplay: requireCampaignSourceReplay,
      requirePreviousLedgerSourceReplay: requirePreviousLedgerSourceReplay,
    );
    if (issues.isEmpty) {
      _verifiedSourceReplayDigests[ledger] = EvalProvenance.digestJson(ledger);
      return;
    }
    throw StateError(
      'Invalid use-case tuning decision ledger source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static List<String> _validateReviewAttestations(
    List<Map<String, dynamic>> attestations, {
    required List<_ReviewRequirement> requirements,
  }) {
    final issues = [
      ...EvalUseCaseAdversarialReview.validateApprovedAttestations(
        attestations,
      ),
    ];
    final requiredKeys = {
      for (final requirement in requirements) requirement.key,
    };
    final seen = <String>{};
    for (final (index, attestation) in attestations.indexed) {
      final key = [
        _string(attestation['sourceArtifactDigest']),
        _string(attestation['sourceQueueDigest']),
        _string(attestation['reviewRef']),
        _string(attestation['category']),
      ].join(':');
      if (!requiredKeys.contains(key)) {
        issues.add(
          'reviewAttestations[$index] must match a campaign review requirement',
        );
      }
      if (!seen.add(key)) {
        issues.add(
          'reviewAttestations[$index] must not duplicate a review requirement',
        );
      }
    }
    return issues;
  }

  static Map<String, _InputReport> _inputReportsByRef(
    Map<String, dynamic> artifact,
  ) {
    return {
      for (final report in _mapList(artifact['inputReports']))
        if (_string(report['reportRef']).isNotEmpty &&
            _string(report['reportDigest']).isNotEmpty)
          _string(report['reportRef']): _InputReport(
            reportRef: _string(report['reportRef']),
            reportDigest: _string(report['reportDigest']),
            sourceCheckStatus: _string(report['sourceCheckStatus']),
            sourceIssueCount: _int(report['sourceIssueCount']),
            sourceIssueCodes: _stringList(report['sourceIssueCodes']),
          ),
    };
  }

  static Map<String, _InputModelClassCoverage> _inputModelClassCoveragesByRef(
    Map<String, dynamic> campaign,
  ) {
    return {
      for (final coverage in _mapList(
        campaign['inputModelClassExecutionCoverages'],
      ))
        if (_string(coverage['coverageRef']).isNotEmpty &&
            _string(coverage['coverageDigest']).isNotEmpty)
          _string(coverage['coverageRef']): _InputModelClassCoverage(
            coverageRef: _string(coverage['coverageRef']),
            coverageDigest: _string(coverage['coverageDigest']),
            contractStatus: _string(coverage['contractStatus']),
            status: _string(coverage['status']),
            contractIssueCount: _int(coverage['contractIssueCount']),
            sourceExperimentPlanDigest: _string(
              coverage['sourceExperimentPlanDigest'],
            ),
            sourceMatrixDigest: _string(coverage['sourceMatrixDigest']),
            sourceWorkOrderDigest: _string(
              coverage['sourceWorkOrderDigest'],
            ),
            coveredWorkOrderBatchRefs: _stringList(
              coverage['coveredWorkOrderBatchRefs'],
            ),
            modelClassCoverageRefs: [
              for (final row in _mapList(coverage['modelClassCoverageRefs']))
                _InputModelClassCoverageRef(
                  modelClass: _string(row['modelClass']),
                  status: _string(row['status']),
                  coverageRef: _string(row['coverageRef']),
                  workOrderBatchRefs: _stringList(row['workOrderBatchRefs']),
                ),
            ],
          ),
    };
  }

  static List<_CampaignEvidence> _readyCampaignEvidence(
    Map<String, dynamic> campaign,
    Map<String, _InputReport> reports,
    Map<String, _InputModelClassCoverage> coverages,
  ) {
    return [
      for (final progress in _mapList(campaign['batchProgress']))
        if ((_map(progress['coverage'])['readyEvidenceExists'] == true) &&
            _stringList(progress['readyReportRefs']).isNotEmpty &&
            _usableModelClassCoverages(progress, coverages).isNotEmpty)
          _CampaignEvidence(
            compatibilityKey: _string(progress['compatibilityKey']),
            capabilities: _stringList(
              _map(progress['plannedSelectors'])['capabilities'],
            ),
            promptVariantNames: _stringList(
              _map(progress['plannedSelectors'])['promptVariantNames'],
            ),
            readyReportDigests: _sortedStrings(
              _stringList(
                progress['readyReportRefs'],
              ).map((ref) => reports[ref]?.reportDigest ?? ''),
            ),
            sourceCheckedReadyReportDigests: _sortedStrings(
              _stringList(progress['readyReportRefs']).map((ref) {
                final report = reports[ref];
                return report?.isSourceChecked == true
                    ? report?.reportDigest ?? ''
                    : '';
              }),
            ),
            modelClassCoverages: _usableModelClassCoverages(
              progress,
              coverages,
            ),
          ),
    ];
  }

  static List<_InputModelClassCoverage> _usableModelClassCoverages(
    Map<String, dynamic> progress,
    Map<String, _InputModelClassCoverage> coverages,
  ) {
    final coverageProgress = _map(progress['coverage']);
    final batchRef = _string(coverageProgress['workOrderBatchRef']);
    final resolved = [
      for (final ref in _stringList(
        coverageProgress['matchedModelClassCoverageRefs'],
      ))
        if (coverages[ref] case final coverage?)
          if (coverage.isUsableForBatch(batchRef)) coverage,
    ]..sort((a, b) => a.coverageRef.compareTo(b.coverageRef));
    return resolved;
  }

  static List<_ReviewRequirement> _reviewRequirements({
    required String sourceDigest,
    required String sourceQueueDigest,
    required Map<String, dynamic> queue,
  }) {
    return [
      for (final task in _mapList(queue['tasks']))
        if (task['required'] == true)
          _ReviewRequirement(
            sourceDigest: sourceDigest,
            sourceQueueDigest: sourceQueueDigest,
            reviewRef: _string(task['reviewRef']),
            category: _string(task['category']),
          ),
    ];
  }

  static _ReviewStatus _reviewStatus({
    required List<_ReviewRequirement> requirements,
    required List<Map<String, dynamic>> attestations,
  }) {
    final requirementKeys = {
      for (final requirement in requirements) requirement.key,
    };
    final approvedEvidenceByKey = <String, _ReviewEvidenceRef>{};
    for (final attestation in attestations) {
      if (_string(attestation['status']) != 'approved') continue;
      final evidence = _ReviewEvidenceRef(
        sourceDigest: _string(attestation['sourceArtifactDigest']),
        sourceQueueDigest: _string(attestation['sourceQueueDigest']),
        reviewRef: _string(attestation['reviewRef']),
        category: _string(attestation['category']),
        evidenceDigest: _string(attestation['evidenceDigest']),
      );
      if (requirementKeys.contains(evidence.key)) {
        approvedEvidenceByKey.putIfAbsent(evidence.key, () => evidence);
      }
    }
    final approvedEvidence = approvedEvidenceByKey.values.toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final approvedKeys = {
      for (final evidence in approvedEvidence) evidence.key,
    };
    final missing = [
      for (final requirement in requirements)
        if (!approvedKeys.contains(requirement.key)) requirement,
    ];
    return _ReviewStatus(
      requirements: requirements,
      missingRequirements: missing,
      attestationCount: attestations.length,
      approvedEvidence: approvedEvidence,
    );
  }

  static List<Map<String, dynamic>> _artifactIssues({
    required List<String> matrixIssues,
    required Map<String, dynamic>? campaign,
    required List<String> campaignIssues,
    required List<String> previousIssues,
    required List<String> attestationIssues,
    required List<String> missingCampaignReportDigests,
    required _ReviewStatus reviewStatus,
  }) {
    return [
      for (final issue in matrixIssues)
        <String, dynamic>{
          'code': 'matrix.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (campaign == null)
        const <String, dynamic>{
          'code': 'decision.campaignMissing',
          'severity': 'blocking',
          'message': 'Decision ledger requires a campaign for acceptance.',
        },
      for (final issue in campaignIssues)
        <String, dynamic>{
          'code': 'campaign.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in previousIssues)
        <String, dynamic>{
          'code': 'previousLedger.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      for (final issue in attestationIssues)
        <String, dynamic>{
          'code': 'reviewAttestation.contractInvalid',
          'severity': 'blocking',
          'message': issue,
        },
      if (missingCampaignReportDigests.isNotEmpty)
        <String, dynamic>{
          'code': 'decision.matrixMissingCampaignEvidence',
          'severity': 'blocking',
          'missingDigestCount': missingCampaignReportDigests.length,
        },
      if (reviewStatus.missingRequirements.isNotEmpty)
        <String, dynamic>{
          'code': 'decision.reviewAttestationMissing',
          'severity': 'blocking',
          'missingRequirementCount': reviewStatus.missingRequirements.length,
        },
    ];
  }

  static List<Map<String, dynamic>> _decisions({
    required List<Map<String, dynamic>> cells,
    required Map<String, _InputReport> matrixReports,
    required List<_CampaignEvidence> campaignEvidence,
    required bool campaignPresent,
    required bool campaignValid,
    required bool staleMatrix,
    required bool reviewApproved,
  }) {
    final byScope = <String, List<Map<String, dynamic>>>{};
    for (final cell in cells) {
      byScope.putIfAbsent(_scopeKey(cell), () => []).add(cell);
    }
    final decisions = [
      for (final entry in byScope.entries)
        _decision(
          scopeKey: entry.key,
          cells: entry.value,
          matrixReports: matrixReports,
          campaignEvidence: campaignEvidence,
          campaignPresent: campaignPresent,
          campaignValid: campaignValid,
          staleMatrix: staleMatrix,
          reviewApproved: reviewApproved,
        ),
    ]..sort((a, b) => _string(a['scopeKey']).compareTo(_string(b['scopeKey'])));
    return decisions;
  }

  static Map<String, dynamic> _decision({
    required String scopeKey,
    required List<Map<String, dynamic>> cells,
    required Map<String, _InputReport> matrixReports,
    required List<_CampaignEvidence> campaignEvidence,
    required bool campaignPresent,
    required bool campaignValid,
    required bool staleMatrix,
    required bool reviewApproved,
  }) {
    final sortedCells = cells.toList()
      ..sort((a, b) => _string(a['cellKey']).compareTo(_string(b['cellKey'])));
    final first = sortedCells.first;
    final candidates = [
      for (final cell in sortedCells)
        _candidate(
          cell,
          matrixReports[_string(cell['reportRef'])],
        ),
    ];
    final promotionCandidates = [
      for (final candidate in candidates)
        if (candidate['evidenceStatus'] == 'promotionReady' &&
            candidate['promotionEvidence'] == true &&
            candidate['reportReady'] == true &&
            candidate['sourcePromotionStatus'] == 'promote' &&
            _stringList(candidate['blockingReasonCodes']).isEmpty)
          candidate,
    ];
    final campaignReadyCandidates = [
      for (final candidate in promotionCandidates)
        if (_campaignProofForCandidate(candidate, campaignEvidence)
            case final proof?)
          <String, dynamic>{
            ...candidate,
            'modelClassCoverageProof': proof,
          },
    ];
    final matrixReportSourceUnchecked = promotionCandidates.any(
      (candidate) => candidate['sourceChecked'] != true,
    );
    final campaignReportSourceUnchecked = promotionCandidates.any(
      (candidate) =>
          _hasCampaignReadyReportDigest(
            candidate,
            campaignEvidence: campaignEvidence,
            requireSourceChecked: false,
          ) &&
          !_hasCampaignReadyReportDigest(
            candidate,
            campaignEvidence: campaignEvidence,
            requireSourceChecked: true,
          ),
    );
    final hasPromotionConflict = promotionCandidates.length > 1;
    final eligibleCandidates = [
      if (campaignPresent &&
          campaignValid &&
          !staleMatrix &&
          reviewApproved &&
          !matrixReportSourceUnchecked &&
          !campaignReportSourceUnchecked &&
          !hasPromotionConflict)
        ...campaignReadyCandidates,
    ];
    final blockers = _decisionBlockers(
      promotionCandidates: promotionCandidates,
      campaignReadyCandidates: campaignReadyCandidates,
      cells: sortedCells,
      campaignPresent: campaignPresent,
      campaignValid: campaignValid,
      staleMatrix: staleMatrix,
      reviewApproved: reviewApproved,
      matrixReportSourceUnchecked: matrixReportSourceUnchecked,
      campaignReportSourceUnchecked: campaignReportSourceUnchecked,
    );
    final status = hasPromotionConflict
        ? 'conflict'
        : eligibleCandidates.length == 1
        ? 'accepted'
        : promotionCandidates.isNotEmpty && !reviewApproved
        ? 'reviewBlocked'
        : promotionCandidates.isNotEmpty &&
              (staleMatrix ||
                  !campaignPresent ||
                  !campaignValid ||
                  campaignReadyCandidates.isEmpty ||
                  matrixReportSourceUnchecked ||
                  campaignReportSourceUnchecked)
        ? 'staleEvidence'
        : candidates.any(
            (candidate) => candidate['evidenceStatus'] == 'diagnosticOnly',
          )
        ? 'watch'
        : 'blocked';
    return <String, dynamic>{
      'scopeKey': scopeKey,
      'compatibilityKey': _string(first['compatibilityKey']),
      'primaryCapabilityId': _string(first['primaryCapabilityId']),
      'agentKind': _string(first['agentKind']),
      'status': status,
      'candidateCount': candidates.length,
      'promotionCandidateCount': promotionCandidates.length,
      'campaignReadyCandidateCount': campaignReadyCandidates.length,
      if (eligibleCandidates.length == 1)
        'acceptedCellKey': _string(eligibleCandidates.single['cellKey']),
      if (eligibleCandidates.length == 1)
        'acceptedCandidate': eligibleCandidates.single,
      'candidates': candidates,
      'blockerCodes': blockers,
      'nextAction': _decisionNextAction(status),
    };
  }

  static Map<String, dynamic> _candidate(
    Map<String, dynamic> cell,
    _InputReport? report,
  ) {
    return <String, dynamic>{
      'cellKey': _string(cell['cellKey']),
      'compatibilityKey': _string(cell['compatibilityKey']),
      'sourceReportRef': _string(cell['reportRef']),
      'reportDigest': report?.reportDigest ?? '',
      'sourceChecked': report?.isSourceChecked == true,
      'primaryCapabilityId': _string(cell['primaryCapabilityId']),
      'agentKind': _string(cell['agentKind']),
      'modelClass': _string(cell['modelClass']),
      'promptVariantName': _string(cell['promptVariantName']),
      'evidenceStatus': _string(cell['evidenceStatus']),
      'promotionEvidence': cell['promotionEvidence'] == true,
      'reportReady': cell['reportReady'] == true,
      'sourcePromotionStatus': _string(cell['sourcePromotionStatus']),
      'recommendation': _string(cell['recommendation']),
      'blockingReasonCodes': _stringList(cell['blockingReasonCodes']),
    };
  }

  static Map<String, dynamic>? _campaignProofForCandidate(
    Map<String, dynamic> candidate,
    List<_CampaignEvidence> campaignEvidence,
  ) {
    for (final evidence in campaignEvidence) {
      final matches =
          evidence.compatibilityKey == _string(candidate['compatibilityKey']) &&
          evidence.sourceCheckedReadyReportDigests.contains(
            _string(candidate['reportDigest']),
          ) &&
          evidence.capabilities.contains(
            _string(candidate['primaryCapabilityId']),
          ) &&
          evidence.promptVariantNames.contains(
            _string(candidate['promptVariantName']),
          );
      if (!matches || evidence.modelClassCoverages.isEmpty) continue;
      final candidateModelClass = _string(candidate['modelClass']);
      _InputModelClassCoverage? coverage;
      _InputModelClassCoverageRef? classCoverage;
      for (final candidateCoverage in evidence.modelClassCoverages) {
        final candidateClassCoverage = candidateCoverage.classCoverageFor(
          modelClass: candidateModelClass,
          workOrderBatchRef: candidateCoverage.provenWorkOrderBatchRef,
        );
        if (candidateClassCoverage == null) continue;
        coverage = candidateCoverage;
        classCoverage = candidateClassCoverage;
        break;
      }
      if (coverage == null || classCoverage == null) continue;
      final proofSource = <String, dynamic>{
        'compatibilityKey': evidence.compatibilityKey,
        'primaryCapabilityId': _string(candidate['primaryCapabilityId']),
        'modelClass': candidateModelClass,
        'promptVariantName': _string(candidate['promptVariantName']),
        'reportDigest': _string(candidate['reportDigest']),
        'workOrderBatchRef': coverage.provenWorkOrderBatchRef,
        'modelClassCoverageRef': coverage.coverageRef,
        'modelClassCoverageClassRef': classCoverage.coverageRef,
        'modelClassCoverageDigest': coverage.coverageDigest,
        'sourceWorkOrderDigest': coverage.sourceWorkOrderDigest,
      };
      return <String, dynamic>{
        ...proofSource,
        'proofRef': EvalProvenance.digestJson(proofSource),
      };
    }
    return null;
  }

  static bool _hasCampaignReadyReportDigest(
    Map<String, dynamic> candidate, {
    required List<_CampaignEvidence> campaignEvidence,
    required bool requireSourceChecked,
  }) {
    for (final evidence in campaignEvidence) {
      if (evidence.compatibilityKey != _string(candidate['compatibilityKey']) ||
          !evidence.capabilities.contains(
            _string(candidate['primaryCapabilityId']),
          ) ||
          !evidence.promptVariantNames.contains(
            _string(candidate['promptVariantName']),
          )) {
        continue;
      }
      final digests = requireSourceChecked
          ? evidence.sourceCheckedReadyReportDigests
          : evidence.readyReportDigests;
      if (digests.contains(_string(candidate['reportDigest']))) return true;
    }
    return false;
  }

  static List<String> _decisionBlockers({
    required List<Map<String, dynamic>> promotionCandidates,
    required List<Map<String, dynamic>> campaignReadyCandidates,
    required List<Map<String, dynamic>> cells,
    required bool campaignPresent,
    required bool campaignValid,
    required bool staleMatrix,
    required bool reviewApproved,
    required bool matrixReportSourceUnchecked,
    required bool campaignReportSourceUnchecked,
  }) {
    return _sortedStrings({
      for (final cell in cells) ..._stringList(cell['blockingReasonCodes']),
      if (promotionCandidates.isEmpty) 'decision.noPromotionReadyCandidate',
      if (!campaignPresent) 'decision.campaignMissing',
      if (campaignPresent && !campaignValid) 'decision.campaignInvalid',
      if (staleMatrix) 'decision.matrixMissingCampaignEvidence',
      if (matrixReportSourceUnchecked) 'decision.matrixReportSourceUnchecked',
      if (campaignReportSourceUnchecked)
        'decision.campaignReportSourceUnchecked',
      if (promotionCandidates.isNotEmpty &&
          campaignReadyCandidates.isEmpty &&
          !campaignReportSourceUnchecked)
        'decision.campaignEvidenceMissing',
      if (!reviewApproved) 'decision.reviewAttestationMissing',
      if (promotionCandidates.length > 1) 'decision.promotionConflict',
    });
  }

  static String _decisionNextAction(String status) => switch (status) {
    'accepted' => 'applyAcceptedUseCaseChoiceAfterReleaseReview',
    'conflict' => 'resolvePromotionCandidateConflict',
    'reviewBlocked' => 'completeAdversarialReviewAttestations',
    'staleEvidence' => 'refreshMatrixFromCampaignEvidence',
    'watch' => 'collectPromotionEvidenceBeforeDecision',
    _ => 'continueEvidenceCollection',
  };

  static List<Map<String, dynamic>> _continuity(
    Map<String, dynamic> previousLedger,
    List<Map<String, dynamic>> decisions,
  ) {
    final currentByScope = {
      for (final decision in decisions) _string(decision['scopeKey']): decision,
    };
    return [
      for (final previous in _mapList(previousLedger['decisions']))
        if (_string(previous['status']) == 'accepted')
          _continuityEntry(
            previous,
            currentByScope[_string(previous['scopeKey'])],
          ),
    ];
  }

  static Map<String, dynamic> _continuityEntry(
    Map<String, dynamic> previous,
    Map<String, dynamic>? current,
  ) {
    final currentStatus = _string(current?['status']);
    final previousCellKey = _string(previous['acceptedCellKey']);
    final unchanged =
        currentStatus == 'accepted' &&
        _string(current?['acceptedCellKey']) == previousCellKey;
    final status = unchanged
        ? 'unchanged'
        : currentStatus == 'accepted'
        ? 'revalidateRequired'
        : 'rollbackRequired';
    return <String, dynamic>{
      'scopeKey': _string(previous['scopeKey']),
      'previousAcceptedCellKey': previousCellKey,
      'currentDecisionStatus': currentStatus.isEmpty
          ? 'missing'
          : currentStatus,
      'status': status,
      'blockerCodes': [
        if (status == 'rollbackRequired') 'decision.previousAcceptedBlocked',
        if (status == 'revalidateRequired') 'decision.acceptedChoiceChanged',
      ],
    };
  }

  static List<String> _blockedReasonCodes({
    required List<Map<String, dynamic>> artifactIssues,
    required List<Map<String, dynamic>> decisions,
    required List<Map<String, dynamic>> continuity,
  }) {
    return _sortedStrings({
      for (final issue in artifactIssues) _string(issue['code']),
      for (final decision in decisions)
        ..._stringList(decision['blockerCodes']),
      for (final entry in continuity) ..._stringList(entry['blockerCodes']),
    });
  }

  static String _status({
    required List<Map<String, dynamic>> artifactIssues,
    required Map<String, dynamic>? campaign,
    required List<String> campaignIssues,
    required List<String> missingCampaignReportDigests,
    required _ReviewStatus reviewStatus,
    required List<Map<String, dynamic>> decisions,
    required List<Map<String, dynamic>> continuity,
  }) {
    if (artifactIssues.any(
      (issue) => _string(issue['code']).endsWith('contractInvalid'),
    )) {
      return 'invalid';
    }
    if (missingCampaignReportDigests.isNotEmpty) return 'staleMatrix';
    if (campaign == null || campaignIssues.isNotEmpty) return 'blockedCampaign';
    if (reviewStatus.missingRequirements.isNotEmpty) return 'blockedReview';
    if (_statusCount(decisions, 'conflict') > 0) return 'conflict';
    if (_statusCount(continuity, 'rollbackRequired') > 0) return 'blocked';
    if (_statusCount(decisions, 'accepted') > 0) return 'accepted';
    if (decisions.isNotEmpty &&
        decisions.every((decision) => decision['status'] == 'watch')) {
      return 'watchOnly';
    }
    return 'blocked';
  }

  static String _scopeKey(Map<String, dynamic> cell) =>
      EvalProvenance.digestJson(<String, dynamic>{
        'compatibilityKey': _string(cell['compatibilityKey']),
        'primaryCapabilityId': _string(cell['primaryCapabilityId']),
        'agentKind': _string(cell['agentKind']),
      });

  static int _statusCount(List<Map<String, dynamic>> items, String status) =>
      items.where((item) => item['status'] == status).length;

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final modes = switch (status) {
      'staleMatrix' => const [
        ('use-case-matrix', 'eval/run_level2.sh use-case-matrix'),
        ('decision-gate', 'eval/run_level2.sh decision-gate'),
      ],
      'blockedCampaign' => const [
        ('campaign', 'eval/run_level2.sh campaign'),
        ('decision-gate', 'eval/run_level2.sh decision-gate'),
      ],
      _ => const [
        ('decision-gate', 'eval/run_level2.sh decision-gate'),
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

  static void _validateSourceMatrix(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseTuningMatrix.kind,
      'sourceMatrix.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseTuningMatrix.schemaVersion,
      'sourceMatrix.schemaVersion',
    );
    _expectNonEmptyString(issues, source['status'], 'sourceMatrix.status');
    _expectDigest(issues, source['matrixDigest'], 'sourceMatrix.matrixDigest');
    _expectNonNegativeInt(
      issues,
      source['contractIssueCount'],
      'sourceMatrix.contractIssueCount',
    );
    _expectNonNegativeInt(
      issues,
      source['inputReportDigestCount'],
      'sourceMatrix.inputReportDigestCount',
    );
    _expectNonNegativeInt(
      issues,
      source['sourceCheckedInputReportDigestCount'],
      'sourceMatrix.sourceCheckedInputReportDigestCount',
    );
  }

  static void _validateSourceCampaign(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectBool(issues, source['present'], 'sourceCampaign.present');
    if (source['present'] != true) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseTuningCampaign.kind,
      'sourceCampaign.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseTuningCampaign.schemaVersion,
      'sourceCampaign.schemaVersion',
    );
    _expectNonEmptyString(issues, source['status'], 'sourceCampaign.status');
    _expectDigest(
      issues,
      source['campaignRef'],
      'sourceCampaign.campaignRef',
    );
    _expectDigest(
      issues,
      source['campaignDigest'],
      'sourceCampaign.campaignDigest',
    );
    for (final field in const [
      'contractIssueCount',
      'readyReportDigestCount',
      'sourceCheckedReadyReportDigestCount',
      'readyModelClassCoverageDigestCount',
      'missingReadyReportDigestCount',
    ]) {
      _expectNonNegativeInt(issues, source[field], 'sourceCampaign.$field');
    }
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'decisionCount',
      'acceptedDecisionCount',
      'conflictDecisionCount',
      'watchDecisionCount',
      'blockedDecisionCount',
      'previousAcceptedDecisionCount',
      'rollbackRequiredCount',
      'reviewRequirementCount',
      'missingReviewAttestationCount',
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
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
      'promotionClaimsRequireSourceEvidence': true,
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
      'consumesMatrixCampaignAndAttestationsOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'liveCommandsCreated': false,
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

  static void _validateReviewGate(
    List<String> issues,
    Map<String, dynamic>? gate,
  ) {
    if (gate == null) return;
    _expectBool(issues, gate['approved'], 'reviewGate.approved');
    for (final field in const [
      'requiredReviewCount',
      'attestationCount',
      'missingRequirementCount',
    ]) {
      _expectNonNegativeInt(issues, gate[field], 'reviewGate.$field');
    }
    _validateReviewRequirements(
      issues,
      _expectList(issues, gate['requirements'], 'reviewGate.requirements'),
      'reviewGate.requirements',
    );
    _validateReviewRequirements(
      issues,
      _expectList(
        issues,
        gate['missingRequirements'],
        'reviewGate.missingRequirements',
      ),
      'reviewGate.missingRequirements',
    );
    _validateReviewEvidenceRefs(
      issues,
      _expectList(
        issues,
        gate['approvedAttestationEvidence'],
        'reviewGate.approvedAttestationEvidence',
      ),
      'reviewGate.approvedAttestationEvidence',
    );
  }

  static void _validateReviewGateInvariants(
    List<String> issues,
    Map<String, dynamic>? gate,
  ) {
    if (gate == null) return;
    final requirements = _mapList(gate['requirements']);
    final missing = _mapList(gate['missingRequirements']);
    final approvedEvidence = _mapList(gate['approvedAttestationEvidence']);
    if (gate['requiredReviewCount'] is int &&
        gate['requiredReviewCount'] != requirements.length) {
      issues.add(
        'reviewGate.requiredReviewCount must match requirements.length',
      );
    }
    if (gate['missingRequirementCount'] is int &&
        gate['missingRequirementCount'] != missing.length) {
      issues.add(
        'reviewGate.missingRequirementCount must match missingRequirements.length',
      );
    }
    if (gate['approved'] is bool && gate['approved'] != missing.isEmpty) {
      issues.add(
        'reviewGate.approved must match missingRequirements emptiness',
      );
    }
    final attestationCount = gate['attestationCount'];
    if (attestationCount is int && attestationCount < approvedEvidence.length) {
      issues.add(
        'reviewGate.attestationCount must cover approvedAttestationEvidence',
      );
    }
    final requirementKeys = {
      for (final requirement in requirements)
        _reviewEvidenceKey(
          sourceArtifactDigest: _string(requirement['sourceArtifactDigest']),
          sourceQueueDigest: _string(requirement['sourceQueueDigest']),
          reviewRef: _string(requirement['reviewRef']),
          category: _string(requirement['category']),
        ),
    };
    final missingKeys = {
      for (final requirement in missing)
        _reviewEvidenceKey(
          sourceArtifactDigest: _string(requirement['sourceArtifactDigest']),
          sourceQueueDigest: _string(requirement['sourceQueueDigest']),
          reviewRef: _string(requirement['reviewRef']),
          category: _string(requirement['category']),
        ),
    };
    final approvedKeys = <String>{};
    for (final (index, evidence) in approvedEvidence.indexed) {
      final key = _reviewEvidenceKey(
        sourceArtifactDigest: _string(evidence['sourceArtifactDigest']),
        sourceQueueDigest: _string(evidence['sourceQueueDigest']),
        reviewRef: _string(evidence['reviewRef']),
        category: _string(evidence['category']),
      );
      if (!requirementKeys.contains(key)) {
        issues.add(
          'reviewGate.approvedAttestationEvidence[$index] must match a review requirement',
        );
      }
      if (!approvedKeys.add(key)) {
        issues.add(
          'reviewGate.approvedAttestationEvidence[$index] must not duplicate a review requirement',
        );
      }
      if (missingKeys.contains(key)) {
        issues.add(
          'reviewGate.approvedAttestationEvidence[$index] must not also be missing',
        );
      }
    }
    if (gate['approved'] == true &&
        !_setEquals(approvedKeys, requirementKeys)) {
      issues.add(
        'reviewGate.approvedAttestationEvidence must cover every requirement when approved',
      );
    }
  }

  static void _validateReviewEvidenceRefs(
    List<String> issues,
    List<dynamic>? evidenceRefs,
    String path,
  ) {
    if (evidenceRefs == null) return;
    for (final (index, value) in evidenceRefs.indexed) {
      final evidence = _expectMap(issues, value, '$path[$index]');
      if (evidence == null) continue;
      _expectDigest(
        issues,
        evidence['sourceArtifactDigest'],
        '$path[$index].sourceArtifactDigest',
      );
      _expectDigest(
        issues,
        evidence['sourceQueueDigest'],
        '$path[$index].sourceQueueDigest',
      );
      _expectDigest(issues, evidence['reviewRef'], '$path[$index].reviewRef');
      final category = _expectNonEmptyString(
        issues,
        evidence['category'],
        '$path[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path[$index].category must be supported');
      }
      _expectDigest(
        issues,
        evidence['evidenceDigest'],
        '$path[$index].evidenceDigest',
      );
    }
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
      _expectDigest(
        issues,
        requirement['sourceArtifactDigest'],
        '$path[$index].sourceArtifactDigest',
      );
      _expectDigest(
        issues,
        requirement['sourceQueueDigest'],
        '$path[$index].sourceQueueDigest',
      );
      _expectDigest(
        issues,
        requirement['reviewRef'],
        '$path[$index].reviewRef',
      );
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

  static void _validateMatrixRefreshEvidence(
    List<String> issues,
    Map<String, dynamic>? evidence,
  ) {
    if (evidence == null) return;
    for (final field in const [
      'readyCampaignReportDigestCount',
      'matrixReportDigestCount',
      'missingReadyReportDigestCount',
    ]) {
      _expectNonNegativeInt(
        issues,
        evidence[field],
        'matrixRefreshEvidence.$field',
      );
    }
    _expectStringList(
      issues,
      evidence['missingReadyReportDigests'],
      'matrixRefreshEvidence.missingReadyReportDigests',
    );
  }

  static void _validateDecisions(
    List<String> issues,
    List<dynamic>? decisions,
  ) {
    if (decisions == null) return;
    for (final (index, value) in decisions.indexed) {
      final decision = _expectMap(issues, value, 'decisions[$index]');
      if (decision == null) continue;
      _expectDigest(issues, decision['scopeKey'], 'decisions[$index].scopeKey');
      _expectDigest(
        issues,
        decision['compatibilityKey'],
        'decisions[$index].compatibilityKey',
      );
      for (final field in const ['primaryCapabilityId', 'agentKind']) {
        _expectNonEmptyString(
          issues,
          decision[field],
          'decisions[$index].$field',
        );
      }
      final status = _expectNonEmptyString(
        issues,
        decision['status'],
        'decisions[$index].status',
      );
      if (status != null && !_allowedDecisionStatuses.contains(status)) {
        issues.add('decisions[$index].status must be supported');
      }
      for (final field in const [
        'candidateCount',
        'promotionCandidateCount',
        'campaignReadyCandidateCount',
      ]) {
        _expectNonNegativeInt(
          issues,
          decision[field],
          'decisions[$index].$field',
        );
      }
      Map<String, dynamic>? acceptedCandidate;
      if (status == 'accepted') {
        _expectDigest(
          issues,
          decision['acceptedCellKey'],
          'decisions[$index].acceptedCellKey',
        );
        acceptedCandidate = _expectMap(
          issues,
          decision['acceptedCandidate'],
          'decisions[$index].acceptedCandidate',
        );
        _validateCandidate(
          issues,
          acceptedCandidate,
          'decisions[$index].acceptedCandidate',
        );
        _validateAcceptedCandidate(
          issues,
          decision,
          acceptedCandidate,
          'decisions[$index]',
        );
        _validateModelClassCoverageProof(
          issues,
          _expectMap(
            issues,
            _map(acceptedCandidate)['modelClassCoverageProof'],
            'decisions[$index].acceptedCandidate.modelClassCoverageProof',
          ),
          'decisions[$index].acceptedCandidate.modelClassCoverageProof',
          candidate: _map(acceptedCandidate),
        );
      }
      final candidates = _expectList(
        issues,
        decision['candidates'],
        'decisions[$index].candidates',
      );
      if (candidates != null) {
        for (final (candidateIndex, candidate) in candidates.indexed) {
          _validateCandidate(
            issues,
            _expectMap(
              issues,
              candidate,
              'decisions[$index].candidates[$candidateIndex]',
            ),
            'decisions[$index].candidates[$candidateIndex]',
          );
        }
      }
      if (status == 'accepted' &&
          acceptedCandidate != null &&
          candidates != null &&
          !candidates.whereType<Map<String, dynamic>>().any(
            (candidate) => _sameCandidate(candidate, acceptedCandidate!),
          )) {
        issues.add(
          'decisions[$index].acceptedCandidate must match one candidates entry',
        );
      }
      _expectStringList(
        issues,
        decision['blockerCodes'],
        'decisions[$index].blockerCodes',
      );
      _expectNonEmptyString(
        issues,
        decision['nextAction'],
        'decisions[$index].nextAction',
      );
    }
  }

  static void _validateCandidate(
    List<String> issues,
    Map<String, dynamic>? candidate,
    String path,
  ) {
    if (candidate == null) return;
    for (final field in const [
      'cellKey',
      'compatibilityKey',
      'reportDigest',
    ]) {
      _expectDigest(issues, candidate[field], '$path.$field');
    }
    for (final field in const [
      'sourceReportRef',
      'primaryCapabilityId',
      'agentKind',
      'modelClass',
      'promptVariantName',
      'evidenceStatus',
      'sourcePromotionStatus',
      'recommendation',
    ]) {
      _expectNonEmptyString(issues, candidate[field], '$path.$field');
    }
    _expectBool(
      issues,
      candidate['promotionEvidence'],
      '$path.promotionEvidence',
    );
    _expectBool(issues, candidate['reportReady'], '$path.reportReady');
    _expectBool(issues, candidate['sourceChecked'], '$path.sourceChecked');
    _expectStringList(
      issues,
      candidate['blockingReasonCodes'],
      '$path.blockingReasonCodes',
    );
    if (candidate.containsKey('modelClassCoverageProof')) {
      _validateModelClassCoverageProof(
        issues,
        _expectMap(
          issues,
          candidate['modelClassCoverageProof'],
          '$path.modelClassCoverageProof',
        ),
        '$path.modelClassCoverageProof',
        candidate: candidate,
      );
    }
  }

  static void _validateAcceptedCandidate(
    List<String> issues,
    Map<String, dynamic> decision,
    Map<String, dynamic>? candidate,
    String decisionPath,
  ) {
    if (candidate == null) return;
    if (candidate['sourceChecked'] != true) {
      issues.add('$decisionPath.acceptedCandidate.sourceChecked must be true');
    }
    if (_string(candidate['evidenceStatus']) != 'promotionReady') {
      issues.add(
        '$decisionPath.acceptedCandidate.evidenceStatus must be promotionReady',
      );
    }
    if (candidate['promotionEvidence'] != true) {
      issues.add(
        '$decisionPath.acceptedCandidate.promotionEvidence must be true',
      );
    }
    if (candidate['reportReady'] != true) {
      issues.add('$decisionPath.acceptedCandidate.reportReady must be true');
    }
    if (_string(candidate['sourcePromotionStatus']) != 'promote') {
      issues.add(
        '$decisionPath.acceptedCandidate.sourcePromotionStatus must be promote',
      );
    }
    if (_stringList(candidate['blockingReasonCodes']).isNotEmpty) {
      issues.add(
        '$decisionPath.acceptedCandidate.blockingReasonCodes must be empty',
      );
    }
    if (_string(decision['acceptedCellKey']) != _string(candidate['cellKey'])) {
      issues.add(
        '$decisionPath.acceptedCellKey must match acceptedCandidate.cellKey',
      );
    }
  }

  static bool _sameCandidate(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    for (final field in const [
      'cellKey',
      'compatibilityKey',
      'sourceReportRef',
      'reportDigest',
      'primaryCapabilityId',
      'agentKind',
      'modelClass',
      'promptVariantName',
      'evidenceStatus',
      'sourcePromotionStatus',
      'recommendation',
    ]) {
      if (_string(left[field]) != _string(right[field])) return false;
    }
    return left['promotionEvidence'] == right['promotionEvidence'] &&
        left['reportReady'] == right['reportReady'] &&
        left['sourceChecked'] == right['sourceChecked'] &&
        _listEquals(
          _stringList(left['blockingReasonCodes']),
          _stringList(right['blockingReasonCodes']),
        );
  }

  static void _validateModelClassCoverageProof(
    List<String> issues,
    Map<String, dynamic>? proof,
    String path, {
    required Map<String, dynamic> candidate,
  }) {
    if (proof == null) return;
    _expectOnlyKeys(issues, proof, _allowedModelClassCoverageProofKeys, path);
    _expectDigest(issues, proof['proofRef'], '$path.proofRef');
    _expectDigest(
      issues,
      proof['compatibilityKey'],
      '$path.compatibilityKey',
    );
    _expectNonEmptyString(
      issues,
      proof['primaryCapabilityId'],
      '$path.primaryCapabilityId',
    );
    _expectNonEmptyString(
      issues,
      proof['modelClass'],
      '$path.modelClass',
    );
    _expectNonEmptyString(
      issues,
      proof['promptVariantName'],
      '$path.promptVariantName',
    );
    _expectDigest(issues, proof['reportDigest'], '$path.reportDigest');
    _expectDigest(
      issues,
      proof['workOrderBatchRef'],
      '$path.workOrderBatchRef',
    );
    _expectDigest(
      issues,
      proof['modelClassCoverageRef'],
      '$path.modelClassCoverageRef',
    );
    _expectDigest(
      issues,
      proof['modelClassCoverageClassRef'],
      '$path.modelClassCoverageClassRef',
    );
    _expectDigest(
      issues,
      proof['modelClassCoverageDigest'],
      '$path.modelClassCoverageDigest',
    );
    _expectDigest(
      issues,
      proof['sourceWorkOrderDigest'],
      '$path.sourceWorkOrderDigest',
    );
    if (proof['compatibilityKey'] != candidate['compatibilityKey']) {
      issues.add('$path.compatibilityKey must match candidate');
    }
    if (proof['primaryCapabilityId'] != candidate['primaryCapabilityId']) {
      issues.add('$path.primaryCapabilityId must match candidate');
    }
    if (proof['modelClass'] != candidate['modelClass']) {
      issues.add('$path.modelClass must match candidate');
    }
    if (proof['promptVariantName'] != candidate['promptVariantName']) {
      issues.add('$path.promptVariantName must match candidate');
    }
    if (proof['reportDigest'] != candidate['reportDigest']) {
      issues.add('$path.reportDigest must match candidate');
    }
    if (_string(proof['workOrderBatchRef']).isEmpty) {
      issues.add('$path.workOrderBatchRef must not be empty');
    }
    final expectedRef = EvalProvenance.digestJson(<String, dynamic>{
      'compatibilityKey': _string(proof['compatibilityKey']),
      'primaryCapabilityId': _string(proof['primaryCapabilityId']),
      'modelClass': _string(proof['modelClass']),
      'promptVariantName': _string(proof['promptVariantName']),
      'reportDigest': _string(proof['reportDigest']),
      'workOrderBatchRef': _string(proof['workOrderBatchRef']),
      'modelClassCoverageRef': _string(proof['modelClassCoverageRef']),
      'modelClassCoverageClassRef': _string(
        proof['modelClassCoverageClassRef'],
      ),
      'modelClassCoverageDigest': _string(proof['modelClassCoverageDigest']),
      'sourceWorkOrderDigest': _string(proof['sourceWorkOrderDigest']),
    });
    if (proof['proofRef'] != expectedRef) {
      issues.add('$path.proofRef must bind model-class coverage proof');
    }
  }

  static void _validateContinuity(List<String> issues, List<dynamic>? entries) {
    if (entries == null) return;
    for (final (index, value) in entries.indexed) {
      final entry = _expectMap(
        issues,
        value,
        'previousDecisionContinuity[$index]',
      );
      if (entry == null) continue;
      _expectDigest(
        issues,
        entry['scopeKey'],
        'previousDecisionContinuity[$index].scopeKey',
      );
      _expectDigest(
        issues,
        entry['previousAcceptedCellKey'],
        'previousDecisionContinuity[$index].previousAcceptedCellKey',
      );
      _expectNonEmptyString(
        issues,
        entry['currentDecisionStatus'],
        'previousDecisionContinuity[$index].currentDecisionStatus',
      );
      final status = _expectNonEmptyString(
        issues,
        entry['status'],
        'previousDecisionContinuity[$index].status',
      );
      if (status != null && !_allowedContinuityStatuses.contains(status)) {
        issues.add(
          'previousDecisionContinuity[$index].status must be supported',
        );
      }
      _expectStringList(
        issues,
        entry['blockerCodes'],
        'previousDecisionContinuity[$index].blockerCodes',
      );
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
      if (command.containsKey('env')) {
        issues.add('$path[$index] must not contain env values');
      }
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required Map<String, dynamic>? sourceCampaign,
    required Map<String, dynamic>? matrixRefreshEvidence,
    required Map<String, dynamic>? reviewGate,
    required List<dynamic>? decisions,
    required List<dynamic>? continuity,
    required List<dynamic>? issueList,
    required List<String>? blockedReasonCodes,
  }) {
    if (summary == null) return;
    if (decisions != null &&
        summary['decisionCount'] is int &&
        summary['decisionCount'] != decisions.length) {
      issues.add('summary.decisionCount must match decisions.length');
    }
    if (decisions != null) {
      final acceptedCount = _jsonStatusCount(decisions, 'accepted');
      if (summary['acceptedDecisionCount'] is int &&
          summary['acceptedDecisionCount'] != acceptedCount) {
        issues.add(
          'summary.acceptedDecisionCount must match accepted decisions',
        );
      }
      final conflictCount = _jsonStatusCount(decisions, 'conflict');
      if (summary['conflictDecisionCount'] is int &&
          summary['conflictDecisionCount'] != conflictCount) {
        issues.add(
          'summary.conflictDecisionCount must match conflict decisions',
        );
      }
      final watchCount = _jsonStatusCount(decisions, 'watch');
      if (summary['watchDecisionCount'] is int &&
          summary['watchDecisionCount'] != watchCount) {
        issues.add('summary.watchDecisionCount must match watch decisions');
      }
      final blockedCount =
          _jsonStatusCount(decisions, 'blocked') +
          _jsonStatusCount(decisions, 'reviewBlocked') +
          _jsonStatusCount(decisions, 'staleEvidence');
      if (summary['blockedDecisionCount'] is int &&
          summary['blockedDecisionCount'] != blockedCount) {
        issues.add(
          'summary.blockedDecisionCount must match blocked decisions',
        );
      }
    }
    if (continuity != null &&
        summary['previousAcceptedDecisionCount'] is int &&
        summary['previousAcceptedDecisionCount'] != continuity.length) {
      issues.add(
        'summary.previousAcceptedDecisionCount must match continuity length',
      );
    }
    if (continuity != null &&
        summary['rollbackRequiredCount'] is int &&
        summary['rollbackRequiredCount'] !=
            _jsonStatusCount(continuity, 'rollbackRequired')) {
      issues.add(
        'summary.rollbackRequiredCount must match rollback continuity',
      );
    }
    if (reviewGate != null) {
      final requirements = _mapList(reviewGate['requirements']);
      if (summary['reviewRequirementCount'] is int &&
          summary['reviewRequirementCount'] != requirements.length) {
        issues.add(
          'summary.reviewRequirementCount must match reviewGate requirements',
        );
      }
      final missing = _mapList(reviewGate['missingRequirements']);
      if (summary['missingReviewAttestationCount'] is int &&
          summary['missingReviewAttestationCount'] != missing.length) {
        issues.add(
          'summary.missingReviewAttestationCount must match missing review requirements',
        );
      }
    }
    if (blockedReasonCodes != null &&
        summary['blockedReasonCount'] is int &&
        summary['blockedReasonCount'] != blockedReasonCodes.length) {
      issues.add(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      );
    }
    if (blockedReasonCodes != null &&
        decisions != null &&
        continuity != null &&
        issueList != null) {
      final expectedBlockers = _blockedReasonCodes(
        artifactIssues: _mapList(issueList),
        decisions: _mapList(decisions),
        continuity: _mapList(continuity),
      );
      if (!_listEquals(blockedReasonCodes, expectedBlockers)) {
        issues.add(
          'blockedReasonCodes must match issues, decisions, and continuity blockers',
        );
      }
    }
    if (sourceCampaign != null &&
        summary['reviewRequirementCount'] is int &&
        sourceCampaign['present'] != true &&
        summary['reviewRequirementCount'] != 0) {
      issues.add(
        'summary.reviewRequirementCount must be zero without a campaign',
      );
    }
    if (matrixRefreshEvidence != null &&
        summary['missingReviewAttestationCount'] is int &&
        _int(matrixRefreshEvidence['missingReadyReportDigestCount']) > 0 &&
        summary['missingReviewAttestationCount'] != 0) {
      issues.add(
        'summary.missingReviewAttestationCount must be zero for stale matrix gates',
      );
    }
  }

  static int _jsonStatusCount(List<dynamic> items, String status) => items
      .whereType<Map<String, dynamic>>()
      .where((item) => item['status'] == status)
      .length;

  static String _reviewEvidenceKey({
    required String sourceArtifactDigest,
    required String sourceQueueDigest,
    required String reviewRef,
    required String category,
  }) => [
    sourceArtifactDigest,
    sourceQueueDigest,
    reviewRef,
    category,
  ].join(':');

  static void _validateStatusInvariant(
    List<String> issues,
    Map<String, dynamic> ledger, {
    required Map<String, dynamic>? sourceCampaign,
    required Map<String, dynamic>? matrixRefreshEvidence,
    required Map<String, dynamic>? reviewGate,
    required List<dynamic>? decisions,
    required List<dynamic>? continuity,
    required List<dynamic>? issueList,
  }) {
    if (sourceCampaign == null ||
        matrixRefreshEvidence == null ||
        reviewGate == null ||
        decisions == null ||
        continuity == null ||
        issueList == null) {
      return;
    }
    final expectedStatus = _expectedStatus(
      sourceCampaign: sourceCampaign,
      matrixRefreshEvidence: matrixRefreshEvidence,
      reviewGate: reviewGate,
      decisions: _mapList(decisions),
      continuity: _mapList(continuity),
      issues: _mapList(issueList),
    );
    if (ledger['status'] != expectedStatus) {
      issues.add('status must match ledger-derived state');
    }
  }

  static String _expectedStatus({
    required Map<String, dynamic> sourceCampaign,
    required Map<String, dynamic> matrixRefreshEvidence,
    required Map<String, dynamic> reviewGate,
    required List<Map<String, dynamic>> decisions,
    required List<Map<String, dynamic>> continuity,
    required List<Map<String, dynamic>> issues,
  }) {
    if (issues.any(
      (issue) => _string(issue['code']).endsWith('contractInvalid'),
    )) {
      return 'invalid';
    }
    if (_stringList(
          matrixRefreshEvidence['missingReadyReportDigests'],
        ).isNotEmpty ||
        _int(matrixRefreshEvidence['missingReadyReportDigestCount']) > 0) {
      return 'staleMatrix';
    }
    if (sourceCampaign['present'] != true ||
        _int(sourceCampaign['contractIssueCount']) > 0) {
      return 'blockedCampaign';
    }
    if (_mapList(reviewGate['missingRequirements']).isNotEmpty ||
        _int(reviewGate['missingRequirementCount']) > 0 ||
        reviewGate['approved'] != true) {
      return 'blockedReview';
    }
    if (_jsonStatusCount(decisions, 'conflict') > 0) return 'conflict';
    if (_jsonStatusCount(continuity, 'rollbackRequired') > 0) {
      return 'blocked';
    }
    if (_jsonStatusCount(decisions, 'accepted') > 0) return 'accepted';
    if (decisions.isNotEmpty &&
        decisions.every((decision) => decision['status'] == 'watch')) {
      return 'watchOnly';
    }
    return 'blocked';
  }

  static void _validateDecisionLedgerRef(
    List<String> issues,
    Map<String, dynamic> ledger,
  ) {
    final expectedRef = decisionLedgerRef(ledger);
    if (ledger['decisionLedgerRef'] != expectedRef) {
      issues.add('decisionLedgerRef must match decision ledger subject digest');
    }
  }

  static Map<String, dynamic> _decisionLedgerSubject(
    Map<String, dynamic> ledger,
  ) => <String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': _string(ledger['status']),
    'sourceMatrixDigest': _string(_map(ledger['sourceMatrix'])['matrixDigest']),
    'sourceCampaignDigest': _string(
      _map(ledger['sourceCampaign'])['campaignDigest'],
    ),
    'sourceCampaignRef': _string(
      _map(ledger['sourceCampaign'])['campaignRef'],
    ),
    'sourceCampaignPresent': _map(ledger['sourceCampaign'])['present'] == true,
    'summaryDigest': EvalProvenance.digestJson(_map(ledger['summary'])),
    'blockedReasonCodesDigest': EvalProvenance.digestJson(
      _stringList(ledger['blockedReasonCodes']),
    ),
    'reviewGateDigest': EvalProvenance.digestJson(_map(ledger['reviewGate'])),
    'matrixRefreshEvidenceDigest': EvalProvenance.digestJson(
      _map(ledger['matrixRefreshEvidence']),
    ),
    'decisionsDigest': EvalProvenance.digestJson(_mapList(ledger['decisions'])),
    'previousDecisionContinuityDigest': EvalProvenance.digestJson(
      _mapList(ledger['previousDecisionContinuity']),
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(ledger['issues'])),
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

  static void _expectOnlyKeys(
    List<String> issues,
    Map<String, dynamic> value,
    Set<String> allowedKeys,
    String path,
  ) {
    for (final key in _sortedStrings(value.keys)) {
      if (!allowedKeys.contains(key)) {
        issues.add('$path.$key must not be present');
      }
    }
  }

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static bool _setEquals(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);
}

const _allowedModelClassCoverageProofKeys = {
  'proofRef',
  'compatibilityKey',
  'primaryCapabilityId',
  'modelClass',
  'promptVariantName',
  'reportDigest',
  'workOrderBatchRef',
  'modelClassCoverageRef',
  'modelClassCoverageClassRef',
  'modelClassCoverageDigest',
  'sourceWorkOrderDigest',
};

final class _InputReport {
  const _InputReport({
    required this.reportRef,
    required this.reportDigest,
    required this.sourceCheckStatus,
    required this.sourceIssueCount,
    required this.sourceIssueCodes,
  });

  final String reportRef;
  final String reportDigest;
  final String sourceCheckStatus;
  final int sourceIssueCount;
  final List<String> sourceIssueCodes;

  bool get isSourceChecked =>
      sourceCheckStatus == 'sourceChecked' &&
      sourceIssueCount == 0 &&
      sourceIssueCodes.isEmpty;
}

final class _InputModelClassCoverage {
  const _InputModelClassCoverage({
    required this.coverageRef,
    required this.coverageDigest,
    required this.contractStatus,
    required this.status,
    required this.contractIssueCount,
    required this.sourceExperimentPlanDigest,
    required this.sourceMatrixDigest,
    required this.sourceWorkOrderDigest,
    required this.coveredWorkOrderBatchRefs,
    required this.modelClassCoverageRefs,
  });

  final String coverageRef;
  final String coverageDigest;
  final String contractStatus;
  final String status;
  final int contractIssueCount;
  final String sourceExperimentPlanDigest;
  final String sourceMatrixDigest;
  final String sourceWorkOrderDigest;
  final List<String> coveredWorkOrderBatchRefs;
  final List<_InputModelClassCoverageRef> modelClassCoverageRefs;

  String get provenWorkOrderBatchRef => coveredWorkOrderBatchRefs.single;

  bool isUsableForBatch(String workOrderBatchRef) {
    return contractStatus == 'valid' &&
        status == 'covered' &&
        contractIssueCount == 0 &&
        coveredWorkOrderBatchRefs.length == 1 &&
        coveredWorkOrderBatchRefs.contains(workOrderBatchRef);
  }

  _InputModelClassCoverageRef? classCoverageFor({
    required String modelClass,
    required String workOrderBatchRef,
  }) {
    for (final ref in modelClassCoverageRefs) {
      if (ref.isCoveredFor(
        modelClass: modelClass,
        workOrderBatchRef: workOrderBatchRef,
      )) {
        return ref;
      }
    }
    return null;
  }
}

final class _InputModelClassCoverageRef {
  const _InputModelClassCoverageRef({
    required this.modelClass,
    required this.status,
    required this.coverageRef,
    required this.workOrderBatchRefs,
  });

  final String modelClass;
  final String status;
  final String coverageRef;
  final List<String> workOrderBatchRefs;

  bool isCoveredFor({
    required String modelClass,
    required String workOrderBatchRef,
  }) =>
      this.modelClass == modelClass &&
      status == 'covered' &&
      EvalProvenance.isDigest(coverageRef) &&
      workOrderBatchRefs.contains(workOrderBatchRef);
}

final class _CampaignEvidence {
  const _CampaignEvidence({
    required this.compatibilityKey,
    required this.capabilities,
    required this.promptVariantNames,
    required this.readyReportDigests,
    required this.sourceCheckedReadyReportDigests,
    required this.modelClassCoverages,
  });

  final String compatibilityKey;
  final List<String> capabilities;
  final List<String> promptVariantNames;
  final List<String> readyReportDigests;
  final List<String> sourceCheckedReadyReportDigests;
  final List<_InputModelClassCoverage> modelClassCoverages;
}

final class _ReviewRequirement {
  const _ReviewRequirement({
    required this.sourceDigest,
    required this.sourceQueueDigest,
    required this.reviewRef,
    required this.category,
  });

  final String sourceDigest;
  final String sourceQueueDigest;
  final String reviewRef;
  final String category;

  String get key =>
      [sourceDigest, sourceQueueDigest, reviewRef, category].join(':');

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceArtifactDigest': sourceDigest,
    'sourceQueueDigest': sourceQueueDigest,
    'reviewRef': reviewRef,
    'category': category,
  };
}

final class _ReviewEvidenceRef {
  const _ReviewEvidenceRef({
    required this.sourceDigest,
    required this.sourceQueueDigest,
    required this.reviewRef,
    required this.category,
    required this.evidenceDigest,
  });

  final String sourceDigest;
  final String sourceQueueDigest;
  final String reviewRef;
  final String category;
  final String evidenceDigest;

  String get key =>
      [sourceDigest, sourceQueueDigest, reviewRef, category].join(':');

  String get sortKey => '$key:$evidenceDigest';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceArtifactDigest': sourceDigest,
    'sourceQueueDigest': sourceQueueDigest,
    'reviewRef': reviewRef,
    'category': category,
    'evidenceDigest': evidenceDigest,
  };
}

final class _ReviewStatus {
  const _ReviewStatus({
    required this.requirements,
    required this.missingRequirements,
    required this.attestationCount,
    required this.approvedEvidence,
  });

  final List<_ReviewRequirement> requirements;
  final List<_ReviewRequirement> missingRequirements;
  final int attestationCount;
  final List<_ReviewEvidenceRef> approvedEvidence;

  bool get approved => missingRequirements.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'approved': approved,
    'requiredReviewCount': requirements.length,
    'attestationCount': attestationCount,
    'missingRequirementCount': missingRequirements.length,
    'requirements': [
      for (final requirement in requirements) requirement.toJson(),
    ],
    'missingRequirements': [
      for (final requirement in missingRequirements) requirement.toJson(),
    ],
    'approvedAttestationEvidence': [
      for (final evidence in approvedEvidence) evidence.toJson(),
    ],
  };
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

int _int(Object? value) => value is int ? value : 0;

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ];
}

List<String> _sortedStrings(Iterable<String> values) {
  final sorted =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return sorted;
}
