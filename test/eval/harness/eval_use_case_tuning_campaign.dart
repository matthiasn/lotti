import 'eval_provenance.dart';
import 'eval_tuning_report_contract.dart';
import 'eval_tuning_report_source_check.dart';
import 'eval_use_case_experiment_plan.dart';
import 'eval_use_case_model_class_execution_coverage.dart';

abstract final class EvalUseCaseTuningCampaign {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseTuningCampaign';
  static final Expando<String> _verifiedSourceReplayDigests = Expando<String>(
    'evalUseCaseTuningCampaignSourceReplayDigest',
  );
  static const _allowedStatuses = {
    'invalid',
    'blockedPlan',
    'noPlannedBatches',
    'awaitingReports',
    'inProgress',
    'readyForMatrixRefresh',
    'evidenceCollected',
  };
  static const _allowedBatchStatuses = {
    'awaitingFollowUpReport',
    'blockedFollowUpEvidence',
    'partialFollowUpCoverage',
    'readyEvidenceCollected',
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

  static Map<String, dynamic> build({
    required Map<String, dynamic> experimentPlan,
    required List<Map<String, dynamic>> reports,
    Map<String, EvalTuningReportSourceCheckResult> sourceChecksByReportDigest =
        const {},
    bool requireSourceChecks = true,
    List<Map<String, dynamic>> modelClassExecutionCoverages = const [],
    List<Map<String, dynamic>> modelClassExecutionWorkOrders = const [],
    DateTime? generatedAt,
  }) {
    final planIssues = EvalUseCaseExperimentPlan.validate(experimentPlan);
    final planDigest = EvalProvenance.digestJson(experimentPlan);
    final batches = planIssues.isEmpty
        ? _mapList(experimentPlan['batches'])
        : const <Map<String, dynamic>>[];
    final snapshots = [
      for (final indexed in reports.indexed)
        _CampaignReportSnapshot.fromReport(
          index: indexed.$1,
          report: indexed.$2,
          sourceCheck:
              sourceChecksByReportDigest[EvalProvenance.digestJson(
                indexed.$2,
              )],
          requireSourceCheck: requireSourceChecks,
        ),
    ];
    final validSnapshots = [
      for (final snapshot in snapshots)
        if (snapshot.isValid) snapshot,
    ];
    final workOrdersByDigest = {
      for (final workOrder in modelClassExecutionWorkOrders)
        EvalProvenance.digestJson(workOrder): workOrder,
    };
    final coverageSnapshots = [
      for (final indexed in modelClassExecutionCoverages.indexed)
        _CampaignModelClassCoverageSnapshot.fromCoverage(
          index: indexed.$1,
          coverage: indexed.$2,
          workOrdersByDigest: workOrdersByDigest,
        ),
    ];
    final validCoverageSnapshots = [
      for (final snapshot in coverageSnapshots)
        if (snapshot.isValid) snapshot,
    ];
    final sourceMatrix = _map(experimentPlan['sourceMatrix']);
    final sourceMatrixDigest = _string(sourceMatrix['matrixDigest']);
    final batchProgress = [
      for (final batch in batches)
        _batchProgress(
          batch: batch,
          planDigest: planDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          reports: validSnapshots,
          coverageSnapshots: validCoverageSnapshots,
        ),
    ];
    final status = _campaignStatus(
      planIssues: planIssues,
      planStatus: _string(experimentPlan['status']),
      snapshots: snapshots,
      coverageSnapshots: coverageSnapshots,
      batches: batches,
      batchProgress: batchProgress,
    );
    final unmatchedReportRefs = _unmatchedReportRefs(
      validSnapshots: validSnapshots,
      batchProgress: batchProgress,
    );
    final blockedCodes = _blockedCodes(
      plan: experimentPlan,
      reports: snapshots,
      coverageSnapshots: coverageSnapshots,
      batchProgress: batchProgress,
    );

    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'campaignRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceExperimentPlan': <String, dynamic>{
        'kind': EvalUseCaseExperimentPlan.kind,
        'schemaVersion': EvalUseCaseExperimentPlan.schemaVersion,
        'status': _string(experimentPlan['status']).isEmpty
            ? 'unknown'
            : _string(experimentPlan['status']),
        'planDigest': planDigest,
        'contractIssueCount': planIssues.length,
        'batchCount': batches.length,
        'adversarialReviewTaskCount': _reviewTaskCount(experimentPlan),
      },
      'summary': <String, dynamic>{
        'inputReportCount': snapshots.length,
        'validReportCount': validSnapshots.length,
        'invalidReportCount': snapshots.length - validSnapshots.length,
        'inputModelClassCoverageCount': coverageSnapshots.length,
        'validModelClassCoverageCount': validCoverageSnapshots.length,
        'invalidModelClassCoverageCount':
            coverageSnapshots.length - validCoverageSnapshots.length,
        'plannedBatchCount': batches.length,
        'matchedBatchCount': _batchStatusCount(
          batchProgress,
          const {
            'blockedFollowUpEvidence',
            'readyEvidenceCollected',
          },
        ),
        'readyEvidenceBatchCount': _batchStatusCount(
          batchProgress,
          const {'readyEvidenceCollected'},
        ),
        'unmatchedReportCount': unmatchedReportRefs.length,
        'blockedReasonCount': blockedCodes.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'promotionClaimsCreated': false,
      },
      'limitations': <String, dynamic>{
        'consumesExperimentPlanReportsAndModelClassCoverageOnly': true,
        'tracesReRead':
            requireSourceChecks || sourceChecksByReportDigest.isNotEmpty,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'reviewCompletionClaimsCreated': false,
        'promotionClaimsCreated': false,
      },
      'blockedReasonCodes': blockedCodes,
      'inputReports': [
        for (final snapshot in snapshots) snapshot.toJson(),
      ],
      'inputModelClassExecutionCoverages': [
        for (final snapshot in coverageSnapshots) snapshot.toJson(),
      ],
      'batchProgress': batchProgress,
      'unmatchedReportRefs': unmatchedReportRefs,
      'adversarialReviewQueue': _adversarialReviewQueue(
        planDigest: planDigest,
        blockedCodes: blockedCodes,
        batchProgress: batchProgress,
      ),
      'recommendedCommands': _recommendedCommands(status),
    };
    artifact['campaignRef'] = campaignRef(artifact);
    assertValid(artifact);
    return artifact;
  }

  static String campaignRef(Map<String, dynamic> campaign) =>
      EvalProvenance.digestJson(_campaignSubject(campaign));

  static bool hasVerifiedSourceReplay(Map<String, dynamic> campaign) =>
      _verifiedSourceReplayDigests[campaign] ==
      EvalProvenance.digestJson(
        campaign,
      );

  static List<String> validate(Map<String, dynamic> campaign) {
    final issues = <String>[];
    _expectEquals(
      issues,
      campaign['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, campaign['kind'], kind, 'kind');
    _expectDigest(issues, campaign['campaignRef'], 'campaignRef');
    _expectIsoDate(issues, campaign['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, campaign['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final sourcePlan = _expectMap(
      issues,
      campaign['sourceExperimentPlan'],
      'sourceExperimentPlan',
    );
    _validateSourcePlan(issues, sourcePlan);
    final summary = _expectMap(issues, campaign['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(
      issues,
      _expectMap(issues, campaign['privacy'], 'privacy'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, campaign['limitations'], 'limitations'),
    );
    final blockedCodes = _expectStringList(
      issues,
      campaign['blockedReasonCodes'],
      'blockedReasonCodes',
    );
    final inputReports = _expectList(
      issues,
      campaign['inputReports'],
      'inputReports',
    );
    _validateInputReports(issues, inputReports);
    final inputCoverages = _expectList(
      issues,
      campaign['inputModelClassExecutionCoverages'],
      'inputModelClassExecutionCoverages',
    );
    _validateInputModelClassCoverages(issues, inputCoverages);
    final batchProgress = _expectList(
      issues,
      campaign['batchProgress'],
      'batchProgress',
    );
    _validateBatchProgress(issues, batchProgress);
    final unmatchedReportRefs = _expectStringList(
      issues,
      campaign['unmatchedReportRefs'],
      'unmatchedReportRefs',
    );
    _validateAdversarialReviewQueue(
      issues,
      _expectMap(
        issues,
        campaign['adversarialReviewQueue'],
        'adversarialReviewQueue',
      ),
      sourceExperimentPlanDigest: _string(sourcePlan?['planDigest']),
      blockedReasonCodes: blockedCodes,
      batchProgress: _mapList(batchProgress),
    );
    final commands = _expectList(
      issues,
      campaign['recommendedCommands'],
      'recommendedCommands',
    );
    _validateCommands(issues, commands, 'recommendedCommands');
    _validateSummaryInvariants(
      issues,
      summary: summary,
      inputReports: inputReports,
      inputModelClassExecutionCoverages: inputCoverages,
      batchProgress: batchProgress,
      unmatchedReportRefs: unmatchedReportRefs,
      blockedReasonCodes: blockedCodes,
    );
    _validateCampaignRef(issues, campaign);
    _validateNoPrivatePayloads(issues, campaign, 'campaign');
    return issues;
  }

  static void assertValid(Map<String, dynamic> campaign) {
    final issues = validate(campaign);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case tuning campaign:\n${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstSources(
    Map<String, dynamic> campaign, {
    required Map<String, dynamic> experimentPlan,
    required List<Map<String, dynamic>> reports,
    Map<String, EvalTuningReportSourceCheckResult> sourceChecksByReportDigest =
        const {},
    bool requireSourceChecks = true,
    List<Map<String, dynamic>> modelClassExecutionCoverages = const [],
    List<Map<String, dynamic>> modelClassExecutionWorkOrders = const [],
  }) {
    final issues = validate(campaign);
    final generatedAt = DateTime.tryParse(_string(campaign['generatedAt']));
    if (generatedAt == null) {
      issues.add('generatedAt must be an ISO-8601 timestamp');
      return issues;
    }
    Map<String, dynamic> expected;
    try {
      expected = build(
        experimentPlan: experimentPlan,
        reports: reports,
        sourceChecksByReportDigest: sourceChecksByReportDigest,
        requireSourceChecks: requireSourceChecks,
        modelClassExecutionCoverages: modelClassExecutionCoverages,
        modelClassExecutionWorkOrders: modelClassExecutionWorkOrders,
        generatedAt: generatedAt,
      );
    } catch (error) {
      issues.add('source artifacts cannot build campaign: $error');
      return issues;
    }

    void expectMatches(String field) {
      if (EvalProvenance.digestJson(campaign[field]) ==
          EvalProvenance.digestJson(expected[field])) {
        return;
      }
      issues.add('$field must match campaign source artifacts');
    }

    const [
      'status',
      'sourceExperimentPlan',
      'summary',
      'privacy',
      'limitations',
      'blockedReasonCodes',
      'inputReports',
      'inputModelClassExecutionCoverages',
      'batchProgress',
      'unmatchedReportRefs',
      'adversarialReviewQueue',
      'recommendedCommands',
    ].forEach(expectMatches);
    if (_string(campaign['campaignRef']) != _string(expected['campaignRef'])) {
      issues.add('campaignRef must match campaign source artifacts');
    }
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> campaign, {
    required Map<String, dynamic> experimentPlan,
    required List<Map<String, dynamic>> reports,
    Map<String, EvalTuningReportSourceCheckResult> sourceChecksByReportDigest =
        const {},
    bool requireSourceChecks = true,
    List<Map<String, dynamic>> modelClassExecutionCoverages = const [],
    List<Map<String, dynamic>> modelClassExecutionWorkOrders = const [],
  }) {
    final issues = validateAgainstSources(
      campaign,
      experimentPlan: experimentPlan,
      reports: reports,
      sourceChecksByReportDigest: sourceChecksByReportDigest,
      requireSourceChecks: requireSourceChecks,
      modelClassExecutionCoverages: modelClassExecutionCoverages,
      modelClassExecutionWorkOrders: modelClassExecutionWorkOrders,
    );
    if (issues.isEmpty) {
      _verifiedSourceReplayDigests[campaign] = EvalProvenance.digestJson(
        campaign,
      );
      return;
    }
    throw StateError(
      'Invalid use-case tuning campaign source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static Map<String, dynamic> _batchProgress({
    required Map<String, dynamic> batch,
    required String planDigest,
    required String sourceMatrixDigest,
    required List<_CampaignReportSnapshot> reports,
    required List<_CampaignModelClassCoverageSnapshot> coverageSnapshots,
  }) {
    final selectors = _map(batch['safeSelectors']);
    final capabilities = _stringList(selectors['capabilities']);
    final promptVariantNames = _stringList(selectors['promptVariantNames']);
    final expectedWorkOrderBatchRef = _expectedWorkOrderBatchRef(
      batch: batch,
      planDigest: planDigest,
      sourceMatrixDigest: sourceMatrixDigest,
      capabilities: capabilities,
      promptVariantNames: promptVariantNames,
    );
    final matchedReports = [
      for (final report in reports)
        if (report.matchesBatch(
          compatibilityKey: _string(batch['compatibilityKey']),
          sourceExperimentPlanDigest: planDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          workOrderBatchRef: expectedWorkOrderBatchRef,
          capabilities: capabilities,
          promptVariantNames: promptVariantNames,
        ))
          report,
    ];
    final selectorMatchedReports = [
      for (final report in reports)
        if (report.overlapsSelectors(
          capabilities: capabilities,
          promptVariantNames: promptVariantNames,
        ))
          report,
    ];
    final readyReports = [
      for (final report in matchedReports)
        if (report.readyFor(
          sourceExperimentPlanDigest: planDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          workOrderBatchRef: expectedWorkOrderBatchRef,
          capabilities: capabilities,
          promptVariantNames: promptVariantNames,
        ))
          report,
    ];
    final compatibilityMismatchedReportRefs = _sortedStrings(
      selectorMatchedReports
          .where((report) => !matchedReports.contains(report))
          .map((report) => report.reportRef),
    );
    final coveredCapabilities = _sortedStrings(
      matchedReports.expand(
        (report) => report.coveredCapabilitiesFor(capabilities),
      ),
    );
    final coveredPromptVariantNames = _sortedStrings(
      matchedReports.expand(
        (report) => report.coveredPromptVariantsFor(promptVariantNames),
      ),
    );
    final readyCoveredCapabilities = _sortedStrings(
      readyReports.expand(
        (report) => report.readyCapabilitiesFor(capabilities),
      ),
    );
    final readyCoveredPromptVariantNames = _sortedStrings(
      readyReports.expand(
        (report) => report.readyPromptVariantsFor(promptVariantNames),
      ),
    );
    final plannedCoverageComplete =
        capabilities.every(coveredCapabilities.contains) &&
        promptVariantNames.every(coveredPromptVariantNames.contains);
    final readyCoverageComplete =
        capabilities.every(readyCoveredCapabilities.contains) &&
        promptVariantNames.every(readyCoveredPromptVariantNames.contains);
    final matchingCoverage = [
      for (final coverage in coverageSnapshots)
        if (coverage.matchesBatch(
          sourceExperimentPlanDigest: planDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          workOrderBatchRef: expectedWorkOrderBatchRef,
        ))
          coverage,
    ];
    final staleCoverageRefs = _sortedStrings(
      coverageSnapshots
          .where(
            (coverage) =>
                coverage.overlapsPlan(
                  sourceExperimentPlanDigest: planDigest,
                  sourceMatrixDigest: sourceMatrixDigest,
                ) &&
                !matchingCoverage.contains(coverage),
          )
          .map((coverage) => coverage.coverageRef),
    );
    final coveredCoverage = [
      for (final coverage in matchingCoverage)
        if (coverage.coveredBatchRefs.contains(expectedWorkOrderBatchRef))
          coverage,
    ];
    final modelClassCoverageComplete = coveredCoverage.isNotEmpty;
    final remainingBlockers = _remainingBlockers(
      readyReports: readyReports,
      matchedReports: matchedReports,
      matchingModelClassCoverages: matchingCoverage,
      staleModelClassCoverageRefs: staleCoverageRefs,
      modelClassCoverageComplete: modelClassCoverageComplete,
      batchBlockers: _stringList(batch['blockedReasonCodes']),
      plannedCoverageComplete: plannedCoverageComplete,
      readyCoverageComplete: readyCoverageComplete,
      compatibilityMismatchedReportRefs: compatibilityMismatchedReportRefs,
    );
    final status =
        readyReports.isNotEmpty &&
            readyCoverageComplete &&
            remainingBlockers.isEmpty
        ? 'readyEvidenceCollected'
        : matchedReports.isNotEmpty
        ? 'blockedFollowUpEvidence'
        : selectorMatchedReports.isNotEmpty
        ? 'partialFollowUpCoverage'
        : 'awaitingFollowUpReport';
    return <String, dynamic>{
      'batchRef': _string(batch['batchRef']),
      'compatibilityKey': _string(batch['compatibilityKey']),
      'status': status,
      'plannedSelectors': <String, dynamic>{
        'capabilities': capabilities,
        'promptVariantNames': promptVariantNames,
      },
      'coverage': <String, dynamic>{
        'plannedCapabilityCount': capabilities.length,
        'coveredCapabilityCount': coveredCapabilities.length,
        'plannedPromptVariantCount': promptVariantNames.length,
        'coveredPromptVariantCount': coveredPromptVariantNames.length,
        'plannedCoverageComplete': plannedCoverageComplete,
        'workOrderBatchRef': expectedWorkOrderBatchRef,
        'modelClassExecutionCoverageRequired': true,
        'modelClassExecutionCoverageComplete': modelClassCoverageComplete,
        'matchedModelClassCoverageRefs': [
          for (final coverage in matchingCoverage) coverage.coverageRef,
        ],
        'staleModelClassCoverageRefs': staleCoverageRefs,
        'readyEvidenceExists':
            readyReports.isNotEmpty &&
            readyCoverageComplete &&
            modelClassCoverageComplete &&
            remainingBlockers.isEmpty,
      },
      'sourceEvidenceStatuses': _stringList(batch['evidenceStatuses']),
      'sourceBlockedReasonCodes': _stringList(batch['blockedReasonCodes']),
      'matchedReportRefs': [
        for (final report in matchedReports) report.reportRef,
      ],
      'compatibilityMismatchedReportRefs': compatibilityMismatchedReportRefs,
      'readyReportRefs': [
        for (final report in readyReports) report.reportRef,
      ],
      'remainingBlockerCodes': remainingBlockers,
      'nextAction': switch (status) {
        'readyEvidenceCollected' => 'refreshUseCaseMatrix',
        'blockedFollowUpEvidence' => 'resolveFollowUpBlockers',
        _ => 'runFollowUpBatch',
      },
    };
  }

  static String _campaignStatus({
    required List<String> planIssues,
    required String planStatus,
    required List<_CampaignReportSnapshot> snapshots,
    required List<_CampaignModelClassCoverageSnapshot> coverageSnapshots,
    required List<Map<String, dynamic>> batches,
    required List<Map<String, dynamic>> batchProgress,
  }) {
    if (planIssues.isNotEmpty ||
        snapshots.any((snapshot) => !snapshot.isValid) ||
        coverageSnapshots.any((snapshot) => !snapshot.isValid)) {
      return 'invalid';
    }
    if (planStatus != 'ready') return 'blockedPlan';
    if (batches.isEmpty) return 'noPlannedBatches';
    if (snapshots.isEmpty) return 'awaitingReports';
    if (batchProgress.every(
      (batch) => batch['status'] == 'readyEvidenceCollected',
    )) {
      return 'evidenceCollected';
    }
    if (batchProgress.any(
      (batch) => _stringList(batch['matchedReportRefs']).isNotEmpty,
    )) {
      if (batchProgress.any(_hasModelClassCoverageBlocker)) {
        return 'inProgress';
      }
      return 'readyForMatrixRefresh';
    }
    return 'inProgress';
  }

  static bool _hasModelClassCoverageBlocker(Map<String, dynamic> batch) {
    return _stringList(batch['remainingBlockerCodes']).any(
      (code) => code.startsWith('campaign.modelClassExecutionCoverage'),
    );
  }

  static List<String> _unmatchedReportRefs({
    required List<_CampaignReportSnapshot> validSnapshots,
    required List<Map<String, dynamic>> batchProgress,
  }) {
    final matched = {
      for (final batch in batchProgress)
        ..._stringList(batch['matchedReportRefs']),
    };
    return [
      for (final snapshot in validSnapshots)
        if (!matched.contains(snapshot.reportRef)) snapshot.reportRef,
    ];
  }

  static List<String> _remainingBlockers({
    required List<_CampaignReportSnapshot> readyReports,
    required List<_CampaignReportSnapshot> matchedReports,
    required List<_CampaignModelClassCoverageSnapshot>
    matchingModelClassCoverages,
    required List<String> staleModelClassCoverageRefs,
    required bool modelClassCoverageComplete,
    required List<String> batchBlockers,
    required bool plannedCoverageComplete,
    required bool readyCoverageComplete,
    required List<String> compatibilityMismatchedReportRefs,
  }) {
    if (readyReports.isNotEmpty &&
        plannedCoverageComplete &&
        readyCoverageComplete &&
        modelClassCoverageComplete &&
        compatibilityMismatchedReportRefs.isEmpty) {
      return const <String>[];
    }
    return _sortedStrings({
      if (matchedReports.isEmpty) 'campaign.noMatchingReport',
      if (!plannedCoverageComplete) 'campaign.partialCoverage',
      if (plannedCoverageComplete && !readyCoverageComplete)
        'campaign.readyCoverageMissing',
      if (matchingModelClassCoverages.isEmpty)
        'campaign.modelClassExecutionCoverageMissing',
      if (matchingModelClassCoverages.isNotEmpty && !modelClassCoverageComplete)
        'campaign.modelClassExecutionCoverageIncomplete',
      if (staleModelClassCoverageRefs.isNotEmpty)
        'campaign.modelClassExecutionCoverageStale',
      if (compatibilityMismatchedReportRefs.isNotEmpty)
        'campaign.compatibilityMismatch',
      ...batchBlockers,
      for (final report in matchedReports) ...report.blockedReasonCodes,
    });
  }

  static List<String> _blockedCodes({
    required Map<String, dynamic> plan,
    required List<_CampaignReportSnapshot> reports,
    required List<_CampaignModelClassCoverageSnapshot> coverageSnapshots,
    required List<Map<String, dynamic>> batchProgress,
  }) {
    return _sortedStrings({
      ..._stringList(plan['blockedReasonCodes']),
      for (final report in reports) ...report.blockedReasonCodes,
      for (final report in reports)
        if (!report.isValid) 'report.contractInvalid',
      for (final coverage in coverageSnapshots)
        if (!coverage.isValid) 'modelClassCoverage.contractInvalid',
      for (final batch in batchProgress)
        ..._stringList(batch['remainingBlockerCodes']),
    });
  }

  static String _expectedWorkOrderBatchRef({
    required Map<String, dynamic> batch,
    required String planDigest,
    required String sourceMatrixDigest,
    required List<String> capabilities,
    required List<String> promptVariantNames,
  }) {
    return EvalProvenance.digestJson(<String, dynamic>{
      'planDigest': planDigest,
      'sourceMatrixDigest': sourceMatrixDigest,
      'sourcePlanBatchRef': _string(batch['batchRef']),
      'compatibilityKey': _string(batch['compatibilityKey']),
      'sourceCellKeys': _sortedStrings(_stringList(batch['sourceCellKeys'])),
      'publicEnv': <String, dynamic>{
        'EVAL_REQUIRED_CAPABILITIES': capabilities.join(','),
        'EVAL_PROMPT_VARIANT_NAMES': promptVariantNames.join(','),
      },
    });
  }

  static List<String> _sanitizeReportBlockerCodes(
    Map<String, dynamic> report,
    Iterable<String> codes,
  ) {
    final privateValues = _privateStringValues(report);
    return _sortedStrings(
      codes.map(
        (code) => _blockerContainsPrivatePayload(code, privateValues)
            ? 'protected-blocker.${EvalProvenance.digestText(code)}'
            : code,
      ),
    );
  }

  static Set<String> _privateStringValues(Object? value) {
    final values = <String>{};

    void collect(Object? node) {
      if (node is String && node.trim().length >= 3) {
        values.add(node.trim());
        return;
      }
      if (node is List) {
        node.forEach(collect);
        return;
      }
      if (node is Map) {
        node.values.forEach(collect);
      }
    }

    void visit(Object? node) {
      if (node is List) {
        node.forEach(visit);
        return;
      }
      if (node is! Map) return;
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_privateFieldReason(key) != null) {
          collect(entry.value);
        }
        visit(entry.value);
      }
    }

    visit(value);
    return values;
  }

  static bool _blockerContainsPrivatePayload(
    String code,
    Set<String> privateValues,
  ) {
    if (_privatePathPattern.hasMatch(code) ||
        _privateEnvTokenPattern.hasMatch(code) ||
        code.contains('<redacted-scenario') ||
        _scenarioFieldTokenPattern.hasMatch(code) ||
        _profileFieldTokenPattern.hasMatch(code)) {
      return true;
    }
    return privateValues.any(code.contains);
  }

  static int _batchStatusCount(
    List<Map<String, dynamic>> batchProgress,
    Set<String> statuses,
  ) {
    return batchProgress
        .where((batch) => statuses.contains(_string(batch['status'])))
        .length;
  }

  static int _reviewTaskCount(Map<String, dynamic> plan) {
    final queue = _map(plan['adversarialReviewQueue']);
    return _mapList(queue['tasks']).length;
  }

  static Map<String, dynamic> _adversarialReviewQueue({
    required String planDigest,
    required List<String> blockedCodes,
    required List<Map<String, dynamic>> batchProgress,
  }) {
    final categories = <String>{
      'privacyAudit',
      'reportLinkageAudit',
      if (blockedCodes.any((code) => code.contains('modelClass')) ||
          batchProgress.any(
            (batch) =>
                _map(
                  batch['coverage'],
                )['modelClassExecutionCoverageRequired'] ==
                true,
          ))
        'modelClassCoverageAudit',
      if (blockedCodes.isNotEmpty) 'blockerRegressionAudit',
    };
    final tasks =
        [
          for (final category in categories)
            <String, dynamic>{
              'reviewRef': EvalProvenance.digestJson(<String, dynamic>{
                'category': category,
                'planDigest': planDigest,
                'batchRefs': [
                  for (final batch in batchProgress) _string(batch['batchRef']),
                ],
                'blockedCodes': blockedCodes,
              }),
              'category': category,
              'status': 'pending',
              'required': true,
              'sourceRefs': <String, dynamic>{
                'sourceExperimentPlanDigest': planDigest,
                'batchRefs': [
                  for (final batch in batchProgress) _string(batch['batchRef']),
                ],
                'blockedReasonCodes': blockedCodes,
              },
              'mustCheck': _reviewChecklist(category),
              'privateValuesOmitted': true,
              'completionEvidenceOmitted': true,
            },
        ]..sort(
          (a, b) => _string(a['category']).compareTo(_string(b['category'])),
        );
    return <String, dynamic>{
      'status': 'pending',
      'completionClaimsCreated': false,
      'summary': <String, dynamic>{
        'taskCount': tasks.length,
        'pendingTaskCount': tasks.length,
        'completedTaskCount': 0,
      },
      'tasks': tasks,
    };
  }

  static List<String> _reviewChecklist(String category) {
    return switch (category) {
      'privacyAudit' => const [
        'campaign output contains only opaque report refs and digests',
        'private selectors, paths, env values, and raw run identifiers are omitted',
      ],
      'reportLinkageAudit' => const [
        'follow-up reports match planned public capability and prompt selectors',
        'unmatched reports are not used to close planned batches',
      ],
      'modelClassCoverageAudit' => const [
        'model-class execution coverage is covered for every planned work-order batch',
        'coverage digests match the source experiment plan and matrix digests',
      ],
      'blockerRegressionAudit' => const [
        'remaining blockers are carried forward until ready evidence exists',
        'matrix refresh is static and does not claim promotion',
      ],
      _ => const ['review campaign evidence for unsupported claims'],
    };
  }

  static List<Map<String, dynamic>> _recommendedCommands(String status) {
    final modes =
        status == 'readyForMatrixRefresh' || status == 'evidenceCollected'
        ? const [
            ('use-case-matrix', 'eval/run_level2.sh use-case-matrix'),
            ('experiment-plan', 'eval/run_level2.sh experiment-plan'),
          ]
        : const [
            ('campaign', 'eval/run_level2.sh campaign'),
          ];
    return [
      for (final command in modes)
        <String, dynamic>{
          'mode': command.$1,
          'command': command.$2,
        },
    ];
  }

  static void _validateSourcePlan(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseExperimentPlan.kind,
      'sourceExperimentPlan.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseExperimentPlan.schemaVersion,
      'sourceExperimentPlan.schemaVersion',
    );
    _expectNonEmptyString(
      issues,
      source['status'],
      'sourceExperimentPlan.status',
    );
    _expectDigest(
      issues,
      source['planDigest'],
      'sourceExperimentPlan.planDigest',
    );
    for (final field in const [
      'contractIssueCount',
      'batchCount',
      'adversarialReviewTaskCount',
    ]) {
      _expectNonNegativeInt(
        issues,
        source[field],
        'sourceExperimentPlan.$field',
      );
    }
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'inputReportCount',
      'validReportCount',
      'invalidReportCount',
      'inputModelClassCoverageCount',
      'validModelClassCoverageCount',
      'invalidModelClassCoverageCount',
      'plannedBatchCount',
      'matchedBatchCount',
      'readyEvidenceBatchCount',
      'unmatchedReportCount',
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
      'promotionClaimsCreated': false,
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
      'consumesExperimentPlanReportsAndModelClassCoverageOnly': true,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
      'reviewCompletionClaimsCreated': false,
      'promotionClaimsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        limitations[entry.key],
        entry.value,
        'limitations.${entry.key}',
      );
    }
    _expectBool(
      issues,
      limitations['tracesReRead'],
      'limitations.tracesReRead',
    );
  }

  static void _validateInputReports(
    List<String> issues,
    List<dynamic>? reports,
  ) {
    if (reports == null) return;
    for (final (index, value) in reports.indexed) {
      final report = _expectMap(issues, value, 'inputReports[$index]');
      if (report == null) continue;
      _expectNonEmptyString(
        issues,
        report['reportRef'],
        'inputReports[$index].reportRef',
      );
      _expectDigest(
        issues,
        report['reportDigest'],
        'inputReports[$index].reportDigest',
      );
      _expectDigest(
        issues,
        report['selectorDigest'],
        'inputReports[$index].selectorDigest',
      );
      _expectNonEmptyString(
        issues,
        report['contractStatus'],
        'inputReports[$index].contractStatus',
      );
      final sourceStatus = _expectNonEmptyString(
        issues,
        report['sourceCheckStatus'],
        'inputReports[$index].sourceCheckStatus',
      );
      if (sourceStatus != null &&
          !const {
            'notRequired',
            'sourceChecked',
            'sourceInvalid',
            'sourceMissing',
          }.contains(sourceStatus)) {
        issues.add('inputReports[$index].sourceCheckStatus is unsupported');
      }
      _expectNonNegativeInt(
        issues,
        report['sourceIssueCount'],
        'inputReports[$index].sourceIssueCount',
      );
      _expectStringList(
        issues,
        report['sourceIssueCodes'],
        'inputReports[$index].sourceIssueCodes',
      );
      _expectBool(issues, report['ready'], 'inputReports[$index].ready');
      _expectStringList(
        issues,
        report['blockedReasonCodes'],
        'inputReports[$index].blockedReasonCodes',
      );
      _expectNonNegativeInt(
        issues,
        report['contractIssueCount'],
        'inputReports[$index].contractIssueCount',
      );
    }
  }

  static void _validateInputModelClassCoverages(
    List<String> issues,
    List<dynamic>? coverages,
  ) {
    if (coverages == null) return;
    for (final (index, value) in coverages.indexed) {
      final coverage = _expectMap(
        issues,
        value,
        'inputModelClassExecutionCoverages[$index]',
      );
      if (coverage == null) continue;
      _expectNonEmptyString(
        issues,
        coverage['coverageRef'],
        'inputModelClassExecutionCoverages[$index].coverageRef',
      );
      _expectDigest(
        issues,
        coverage['coverageDigest'],
        'inputModelClassExecutionCoverages[$index].coverageDigest',
      );
      _expectNonEmptyString(
        issues,
        coverage['contractStatus'],
        'inputModelClassExecutionCoverages[$index].contractStatus',
      );
      _expectNonEmptyString(
        issues,
        coverage['status'],
        'inputModelClassExecutionCoverages[$index].status',
      );
      final contractStatus = _string(coverage['contractStatus']);
      if (contractStatus == 'valid') {
        for (final field in const [
          'sourceExperimentPlanDigest',
          'sourceMatrixDigest',
          'sourceWorkOrderDigest',
        ]) {
          _expectDigest(
            issues,
            coverage[field],
            'inputModelClassExecutionCoverages[$index].$field',
          );
        }
      }
      _expectNonNegativeInt(
        issues,
        coverage['contractIssueCount'],
        'inputModelClassExecutionCoverages[$index].contractIssueCount',
      );
      _expectStringList(
        issues,
        coverage['coveredWorkOrderBatchRefs'],
        'inputModelClassExecutionCoverages[$index].coveredWorkOrderBatchRefs',
      );
      final modelClassCoverageRefs = _expectList(
        issues,
        coverage['modelClassCoverageRefs'],
        'inputModelClassExecutionCoverages[$index].modelClassCoverageRefs',
      );
      _validateInputModelClassCoverageRefs(
        issues,
        modelClassCoverageRefs,
        'inputModelClassExecutionCoverages[$index].modelClassCoverageRefs',
      );
      final expectedRef =
          _CampaignModelClassCoverageSnapshot._coverageSnapshotRef(
            coverageDigest: _string(coverage['coverageDigest']),
            status: _string(coverage['status']),
            sourceExperimentPlanDigest: _string(
              coverage['sourceExperimentPlanDigest'],
            ),
            sourceMatrixDigest: _string(coverage['sourceMatrixDigest']),
            sourceWorkOrderDigest: _string(coverage['sourceWorkOrderDigest']),
            coveredBatchRefs: _stringList(
              coverage['coveredWorkOrderBatchRefs'],
            ),
            modelClassCoverageRefs: _mapList(
              coverage['modelClassCoverageRefs'],
            ),
          );
      if (coverage['coverageRef'] != expectedRef) {
        issues.add(
          'inputModelClassExecutionCoverages[$index].coverageRef must bind coverage source summary',
        );
      }
    }
  }

  static void _validateInputModelClassCoverageRefs(
    List<String> issues,
    List<dynamic>? refs,
    String path,
  ) {
    if (refs == null) return;
    final seenModelClasses = <String>{};
    for (final (index, value) in refs.indexed) {
      final ref = _expectMap(issues, value, '$path[$index]');
      if (ref == null) continue;
      final modelClass = _expectNonEmptyString(
        issues,
        ref['modelClass'],
        '$path[$index].modelClass',
      );
      if (modelClass != null && !seenModelClasses.add(modelClass)) {
        issues.add('$path[$index].modelClass must not be duplicated');
      }
      _expectNonEmptyString(
        issues,
        ref['status'],
        '$path[$index].status',
      );
      _expectDigest(issues, ref['coverageRef'], '$path[$index].coverageRef');
      _expectStringList(
        issues,
        ref['workOrderBatchRefs'],
        '$path[$index].workOrderBatchRefs',
      );
    }
  }

  static void _validateBatchProgress(
    List<String> issues,
    List<dynamic>? progress,
  ) {
    if (progress == null) return;
    for (final (index, value) in progress.indexed) {
      final batch = _expectMap(issues, value, 'batchProgress[$index]');
      if (batch == null) continue;
      _expectDigest(
        issues,
        batch['batchRef'],
        'batchProgress[$index].batchRef',
      );
      _expectDigest(
        issues,
        batch['compatibilityKey'],
        'batchProgress[$index].compatibilityKey',
      );
      final status = _expectNonEmptyString(
        issues,
        batch['status'],
        'batchProgress[$index].status',
      );
      if (status != null && !_allowedBatchStatuses.contains(status)) {
        issues.add(
          'batchProgress[$index].status must be one of '
          '${_allowedBatchStatuses.join(', ')}',
        );
      }
      _validateSelectorMap(
        issues,
        _expectMap(
          issues,
          batch['plannedSelectors'],
          'batchProgress[$index].plannedSelectors',
        ),
        'batchProgress[$index].plannedSelectors',
      );
      _validateCoverage(
        issues,
        _expectMap(
          issues,
          batch['coverage'],
          'batchProgress[$index].coverage',
        ),
        'batchProgress[$index].coverage',
      );
      final coverage = _map(batch['coverage']);
      for (final field in const [
        'sourceEvidenceStatuses',
        'sourceBlockedReasonCodes',
        'matchedReportRefs',
        'compatibilityMismatchedReportRefs',
        'readyReportRefs',
        'remainingBlockerCodes',
      ]) {
        _expectStringList(issues, batch[field], 'batchProgress[$index].$field');
      }
      _expectNonEmptyString(
        issues,
        batch['nextAction'],
        'batchProgress[$index].nextAction',
      );
      final readyReportRefs = _stringList(batch['readyReportRefs']);
      final remainingBlockers = _stringList(batch['remainingBlockerCodes']);
      final readyEvidenceExists = coverage['readyEvidenceExists'] == true;
      final modelClassCoverageComplete =
          coverage['modelClassExecutionCoverageComplete'] == true;
      if (readyEvidenceExists && readyReportRefs.isEmpty) {
        issues.add(
          'batchProgress[$index].coverage.readyEvidenceExists requires readyReportRefs',
        );
      }
      if (readyEvidenceExists && remainingBlockers.isNotEmpty) {
        issues.add(
          'batchProgress[$index].coverage.readyEvidenceExists requires empty remainingBlockerCodes',
        );
      }
      if (readyEvidenceExists && !modelClassCoverageComplete) {
        issues.add(
          'batchProgress[$index].coverage.readyEvidenceExists requires model-class execution coverage',
        );
      }
      if (status == 'readyEvidenceCollected' && !readyEvidenceExists) {
        issues.add(
          'batchProgress[$index].status readyEvidenceCollected requires readyEvidenceExists',
        );
      }
    }
  }

  static void _validateCoverage(
    List<String> issues,
    Map<String, dynamic>? coverage,
    String path,
  ) {
    if (coverage == null) return;
    for (final field in const [
      'plannedCapabilityCount',
      'coveredCapabilityCount',
      'plannedPromptVariantCount',
      'coveredPromptVariantCount',
    ]) {
      _expectNonNegativeInt(issues, coverage[field], '$path.$field');
    }
    _expectBool(
      issues,
      coverage['plannedCoverageComplete'],
      '$path.plannedCoverageComplete',
    );
    _expectDigest(
      issues,
      coverage['workOrderBatchRef'],
      '$path.workOrderBatchRef',
    );
    _expectBool(
      issues,
      coverage['modelClassExecutionCoverageRequired'],
      '$path.modelClassExecutionCoverageRequired',
    );
    _expectEquals(
      issues,
      coverage['modelClassExecutionCoverageRequired'],
      true,
      '$path.modelClassExecutionCoverageRequired',
    );
    _expectBool(
      issues,
      coverage['modelClassExecutionCoverageComplete'],
      '$path.modelClassExecutionCoverageComplete',
    );
    _expectStringList(
      issues,
      coverage['matchedModelClassCoverageRefs'],
      '$path.matchedModelClassCoverageRefs',
    );
    _expectStringList(
      issues,
      coverage['staleModelClassCoverageRefs'],
      '$path.staleModelClassCoverageRefs',
    );
    _expectBool(
      issues,
      coverage['readyEvidenceExists'],
      '$path.readyEvidenceExists',
    );
  }

  static void _validateSelectorMap(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    for (final field in const ['capabilities', 'promptVariantNames']) {
      _expectStringList(issues, selectors[field], '$path.$field');
    }
  }

  static void _validateAdversarialReviewQueue(
    List<String> issues,
    Map<String, dynamic>? queue, {
    required String sourceExperimentPlanDigest,
    required List<String>? blockedReasonCodes,
    required List<Map<String, dynamic>> batchProgress,
  }) {
    if (queue == null) return;
    _expectEquals(
      issues,
      queue['status'],
      'pending',
      'adversarialReviewQueue.status',
    );
    _expectEquals(
      issues,
      queue['completionClaimsCreated'],
      false,
      'adversarialReviewQueue.completionClaimsCreated',
    );
    final summary = _expectMap(
      issues,
      queue['summary'],
      'adversarialReviewQueue.summary',
    );
    for (final field in const [
      'taskCount',
      'pendingTaskCount',
      'completedTaskCount',
    ]) {
      _expectNonNegativeInt(
        issues,
        summary?[field],
        'adversarialReviewQueue.summary.$field',
      );
    }
    if (summary?['completedTaskCount'] != 0) {
      issues.add('adversarialReviewQueue.summary.completedTaskCount must be 0');
    }
    final tasks = _expectList(
      issues,
      queue['tasks'],
      'adversarialReviewQueue.tasks',
    );
    if (summary?['taskCount'] is int && tasks != null) {
      if (summary?['taskCount'] != tasks.length) {
        issues.add(
          'adversarialReviewQueue.summary.taskCount must match tasks.length',
        );
      }
      if (summary?['pendingTaskCount'] != tasks.length) {
        issues.add(
          'adversarialReviewQueue.summary.pendingTaskCount must match '
          'tasks.length',
        );
      }
    }
    if (tasks == null) return;
    final actualTasks = <Map<String, dynamic>>[];
    for (final (index, value) in tasks.indexed) {
      final task = _expectMap(
        issues,
        value,
        'adversarialReviewQueue.tasks[$index]',
      );
      if (task == null) continue;
      actualTasks.add(task);
      _expectDigest(
        issues,
        task['reviewRef'],
        'adversarialReviewQueue.tasks[$index].reviewRef',
      );
      final category = _expectNonEmptyString(
        issues,
        task['category'],
        'adversarialReviewQueue.tasks[$index].category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add(
          'adversarialReviewQueue.tasks[$index].category must be supported',
        );
      }
      _expectEquals(
        issues,
        task['status'],
        'pending',
        'adversarialReviewQueue.tasks[$index].status',
      );
      _expectEquals(
        issues,
        task['required'],
        true,
        'adversarialReviewQueue.tasks[$index].required',
      );
      _expectMap(
        issues,
        task['sourceRefs'],
        'adversarialReviewQueue.tasks[$index].sourceRefs',
      );
      final mustCheck = _expectStringList(
        issues,
        task['mustCheck'],
        'adversarialReviewQueue.tasks[$index].mustCheck',
      );
      if (mustCheck != null && mustCheck.isEmpty) {
        issues.add(
          'adversarialReviewQueue.tasks[$index].mustCheck must not be empty',
        );
      }
      _expectEquals(
        issues,
        task['privateValuesOmitted'],
        true,
        'adversarialReviewQueue.tasks[$index].privateValuesOmitted',
      );
      _expectEquals(
        issues,
        task['completionEvidenceOmitted'],
        true,
        'adversarialReviewQueue.tasks[$index].completionEvidenceOmitted',
      );
      for (final forbidden in const [
        'command',
        'env',
        'nextRunEnv',
        'recommendedCommands',
        'completionEvidence',
        'reviewedBy',
        'verdict',
        'passed',
      ]) {
        if (task.containsKey(forbidden)) {
          issues.add(
            'adversarialReviewQueue.tasks[$index] must not contain $forbidden',
          );
        }
      }
    }
    _validateReviewQueueSemantics(
      issues,
      sourceExperimentPlanDigest: sourceExperimentPlanDigest,
      blockedReasonCodes: blockedReasonCodes,
      batchProgress: batchProgress,
      tasks: actualTasks,
    );
  }

  static void _validateReviewQueueSemantics(
    List<String> issues, {
    required String sourceExperimentPlanDigest,
    required List<String>? blockedReasonCodes,
    required List<Map<String, dynamic>> batchProgress,
    required List<Map<String, dynamic>> tasks,
  }) {
    if (!EvalProvenance.isDigest(sourceExperimentPlanDigest) ||
        blockedReasonCodes == null) {
      return;
    }
    final expectedQueue = _adversarialReviewQueue(
      planDigest: sourceExperimentPlanDigest,
      blockedCodes: blockedReasonCodes,
      batchProgress: batchProgress,
    );
    final expectedTasks = _mapList(expectedQueue['tasks']);
    final expectedByCategory = {
      for (final task in expectedTasks) _string(task['category']): task,
    };
    final actualByCategory = {
      for (final task in tasks) _string(task['category']): task,
    };
    final rawActualCategories = [
      for (final task in tasks) _string(task['category']),
    ];
    final actualCategories = _sortedStrings(actualByCategory.keys);
    final expectedCategories = _sortedStrings(expectedByCategory.keys);
    if (rawActualCategories.length != actualCategories.length) {
      issues.add(
        'adversarialReviewQueue.tasks categories must not be duplicated',
      );
    }
    if (!_sameStrings(actualCategories, expectedCategories)) {
      issues.add(
        'adversarialReviewQueue.tasks categories must match campaign blockers and coverage requirements',
      );
    }
    for (final category in expectedCategories) {
      final actual = actualByCategory[category];
      final expected = expectedByCategory[category];
      if (actual == null || expected == null) continue;
      if (actual['reviewRef'] != expected['reviewRef']) {
        issues.add(
          'adversarialReviewQueue.tasks[$category].reviewRef must bind campaign review sources',
        );
      }
      if (EvalProvenance.digestJson(_map(actual['sourceRefs'])) !=
          EvalProvenance.digestJson(_map(expected['sourceRefs']))) {
        issues.add(
          'adversarialReviewQueue.tasks[$category].sourceRefs must match campaign review sources',
        );
      }
      if (!_sameStrings(
        _stringList(actual['mustCheck']),
        _stringList(expected['mustCheck']),
      )) {
        issues.add(
          'adversarialReviewQueue.tasks[$category].mustCheck must match campaign review checklist',
        );
      }
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
      if (text != null) {
        if (text.contains('EVAL_SCENARIO_IDS')) {
          issues.add(
            '$path[$index].command must not contain EVAL_SCENARIO_IDS',
          );
        }
        if (_liveRunLevel2CommandPattern.hasMatch(text)) {
          issues.add(
            '$path[$index].command must not recommend live run commands',
          );
        }
      }
      if (command.containsKey('env')) {
        issues.add('$path[$index] must not contain env values');
      }
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? inputReports,
    required List<dynamic>? inputModelClassExecutionCoverages,
    required List<dynamic>? batchProgress,
    required List<String>? unmatchedReportRefs,
    required List<String>? blockedReasonCodes,
  }) {
    if (summary == null) return;
    if (inputReports != null &&
        summary['inputReportCount'] is int &&
        summary['inputReportCount'] != inputReports.length) {
      issues.add('summary.inputReportCount must match inputReports.length');
    }
    if (inputModelClassExecutionCoverages != null &&
        summary['inputModelClassCoverageCount'] is int &&
        summary['inputModelClassCoverageCount'] !=
            inputModelClassExecutionCoverages.length) {
      issues.add(
        'summary.inputModelClassCoverageCount must match '
        'inputModelClassExecutionCoverages.length',
      );
    }
    if (batchProgress != null &&
        summary['plannedBatchCount'] is int &&
        summary['plannedBatchCount'] != batchProgress.length) {
      issues.add('summary.plannedBatchCount must match batchProgress.length');
    }
    if (unmatchedReportRefs != null &&
        summary['unmatchedReportCount'] is int &&
        summary['unmatchedReportCount'] != unmatchedReportRefs.length) {
      issues.add(
        'summary.unmatchedReportCount must match unmatchedReportRefs.length',
      );
    }
    if (blockedReasonCodes != null &&
        summary['blockedReasonCount'] is int &&
        summary['blockedReasonCount'] != blockedReasonCodes.length) {
      issues.add(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      );
    }
  }

  static void _validateCampaignRef(
    List<String> issues,
    Map<String, dynamic> campaign,
  ) {
    final expectedRef = campaignRef(campaign);
    if (campaign['campaignRef'] != expectedRef) {
      issues.add('campaignRef must match campaign subject digest');
    }
  }

  static Map<String, dynamic> _campaignSubject(
    Map<String, dynamic> campaign,
  ) => <String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': _string(campaign['status']),
    'sourceExperimentPlanDigest': _string(
      _map(campaign['sourceExperimentPlan'])['planDigest'],
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(campaign['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(campaign['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(campaign['limitations']),
    ),
    'blockedReasonCodesDigest': EvalProvenance.digestJson(
      _stringList(campaign['blockedReasonCodes']),
    ),
    'inputReportsDigest': EvalProvenance.digestJson(
      _mapList(campaign['inputReports']),
    ),
    'inputModelClassExecutionCoveragesDigest': EvalProvenance.digestJson(
      _mapList(campaign['inputModelClassExecutionCoverages']),
    ),
    'batchProgressDigest': EvalProvenance.digestJson(
      _mapList(campaign['batchProgress']),
    ),
    'unmatchedReportRefsDigest': EvalProvenance.digestJson(
      _stringList(campaign['unmatchedReportRefs']),
    ),
    'adversarialReviewQueueDigest': EvalProvenance.digestJson(
      _map(campaign['adversarialReviewQueue']),
    ),
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
}

final class _CampaignModelClassCoverageSnapshot {
  _CampaignModelClassCoverageSnapshot({
    required this.index,
    required this.coverage,
    required this.contractIssues,
  }) : coverageDigest = EvalProvenance.digestJson(coverage),
       status = _string(coverage['status']),
       sourceExperimentPlanDigest = _string(
         _map(coverage['sourceWorkOrder'])['sourceExperimentPlanDigest'],
       ),
       sourceMatrixDigest = _string(
         _map(coverage['sourceWorkOrder'])['sourceMatrixDigest'],
       ),
       sourceWorkOrderDigest = _string(
         _map(coverage['sourceWorkOrder'])['workOrderDigest'],
       ),
       coveredBatchRefs = _coveredBatchRefs(coverage),
       modelClassCoverageRefs = _modelClassCoverageRefs(coverage),
       coverageRef = _coverageSnapshotRef(
         coverageDigest: EvalProvenance.digestJson(coverage),
         status: _string(coverage['status']),
         sourceExperimentPlanDigest: _string(
           _map(coverage['sourceWorkOrder'])['sourceExperimentPlanDigest'],
         ),
         sourceMatrixDigest: _string(
           _map(coverage['sourceWorkOrder'])['sourceMatrixDigest'],
         ),
         sourceWorkOrderDigest: _string(
           _map(coverage['sourceWorkOrder'])['workOrderDigest'],
         ),
         coveredBatchRefs: _coveredBatchRefs(coverage),
         modelClassCoverageRefs: _modelClassCoverageRefs(coverage),
       );

  factory _CampaignModelClassCoverageSnapshot.fromCoverage({
    required int index,
    required Map<String, dynamic> coverage,
    Map<String, Map<String, dynamic>> workOrdersByDigest =
        const <String, Map<String, dynamic>>{},
  }) {
    final sourceWorkOrderDigest = _string(
      _map(coverage['sourceWorkOrder'])['workOrderDigest'],
    );
    final matchedWorkOrder = workOrdersByDigest[sourceWorkOrderDigest];
    final contractIssues = [
      if (workOrdersByDigest.isEmpty)
        'coverage source work order must be supplied',
      if (matchedWorkOrder == null)
        ...EvalUseCaseModelClassExecutionCoverage.validate(coverage),
      if (!EvalUseCaseModelClassExecutionCoverage.hasVerifiedConcreteSourceReplay(
        coverage,
      ))
        'coverage concrete source replay must be verified',
      if (workOrdersByDigest.isNotEmpty && matchedWorkOrder == null)
        'coverage sourceWorkOrder.workOrderDigest must be supplied',
      if (matchedWorkOrder != null)
        ...EvalUseCaseModelClassExecutionCoverage.validateAgainstWorkOrder(
          coverage,
          workOrder: matchedWorkOrder,
        ),
    ];
    return _CampaignModelClassCoverageSnapshot(
      index: index,
      coverage: coverage,
      contractIssues: contractIssues,
    );
  }

  final int index;
  final Map<String, dynamic> coverage;
  final List<String> contractIssues;
  final String coverageRef;
  final String coverageDigest;
  final String status;
  final String sourceExperimentPlanDigest;
  final String sourceMatrixDigest;
  final String sourceWorkOrderDigest;
  final List<String> coveredBatchRefs;
  final List<Map<String, dynamic>> modelClassCoverageRefs;

  bool get isValid => contractIssues.isEmpty;

  bool overlapsPlan({
    required String sourceExperimentPlanDigest,
    required String sourceMatrixDigest,
  }) {
    return this.sourceExperimentPlanDigest == sourceExperimentPlanDigest &&
        this.sourceMatrixDigest == sourceMatrixDigest;
  }

  bool matchesBatch({
    required String sourceExperimentPlanDigest,
    required String sourceMatrixDigest,
    required String workOrderBatchRef,
  }) {
    return overlapsPlan(
          sourceExperimentPlanDigest: sourceExperimentPlanDigest,
          sourceMatrixDigest: sourceMatrixDigest,
        ) &&
        coveredOrPartialBatchRefs.contains(workOrderBatchRef);
  }

  List<String> get coveredOrPartialBatchRefs => _sortedStrings(
    _mapList(coverage['coverageCells']).map(
      (cell) => _string(cell['workOrderBatchRef']),
    ),
  );

  static List<String> _coveredBatchRefs(Map<String, dynamic> coverage) {
    final cellsByBatchRef = <String, List<Map<String, dynamic>>>{};
    for (final cell in _mapList(coverage['coverageCells'])) {
      final batchRef = _string(cell['workOrderBatchRef']);
      if (batchRef.isEmpty) continue;
      cellsByBatchRef.putIfAbsent(batchRef, () => []).add(cell);
    }
    return _sortedStrings(
      cellsByBatchRef.entries
          .where(
            (entry) =>
                entry.value.isNotEmpty &&
                entry.value.every(
                  (cell) => _string(cell['status']) == 'covered',
                ),
          )
          .map((entry) => entry.key),
    );
  }

  static List<Map<String, dynamic>> _modelClassCoverageRefs(
    Map<String, dynamic> coverage,
  ) {
    final refs =
        [
          for (final row in _mapList(coverage['modelClassCoverage']))
            if (_string(row['modelClass']).isNotEmpty &&
                _string(row['coverageRef']).isNotEmpty)
              <String, dynamic>{
                'modelClass': _string(row['modelClass']),
                'status': _string(row['status']),
                'coverageRef': _string(row['coverageRef']),
                'workOrderBatchRefs': _stringList(row['workOrderBatchRefs']),
              },
        ]..sort((left, right) {
          final modelClass = _string(left['modelClass']).compareTo(
            _string(right['modelClass']),
          );
          if (modelClass != 0) return modelClass;
          return _string(left['coverageRef']).compareTo(
            _string(right['coverageRef']),
          );
        });
    return refs;
  }

  static String _coverageSnapshotRef({
    required String coverageDigest,
    required String status,
    required String sourceExperimentPlanDigest,
    required String sourceMatrixDigest,
    required String sourceWorkOrderDigest,
    required List<String> coveredBatchRefs,
    required List<Map<String, dynamic>> modelClassCoverageRefs,
  }) => EvalProvenance.digestJson(<String, dynamic>{
    'coverageDigest': coverageDigest,
    'status': status.isEmpty ? 'unknown' : status,
    'sourceExperimentPlanDigest': sourceExperimentPlanDigest,
    'sourceMatrixDigest': sourceMatrixDigest,
    'sourceWorkOrderDigest': sourceWorkOrderDigest,
    'coveredWorkOrderBatchRefs': coveredBatchRefs,
    'modelClassCoverageRefs': modelClassCoverageRefs,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'coverageRef': coverageRef,
      'coverageDigest': coverageDigest,
      'contractStatus': isValid ? 'valid' : 'invalid',
      'contractIssueCount': contractIssues.length,
      'status': status.isEmpty ? 'unknown' : status,
      'sourceExperimentPlanDigest': sourceExperimentPlanDigest,
      'sourceMatrixDigest': sourceMatrixDigest,
      'sourceWorkOrderDigest': sourceWorkOrderDigest,
      'coveredWorkOrderBatchRefs': coveredBatchRefs,
      'modelClassCoverageRefs': modelClassCoverageRefs,
    };
  }
}

final class _CampaignReportSnapshot {
  _CampaignReportSnapshot({
    required this.index,
    required this.report,
    required this.contractIssues,
    required this.sourceCheck,
    required this.requireSourceCheck,
  }) : reportRef = 'report-${index + 1}',
       reportDigest = EvalProvenance.digestJson(report),
       ready =
           _map(report['status'])['ready'] == true &&
           _map(report['readiness'])['ready'] == true,
       capabilities = _trustedCapabilities(report, sourceCheck),
       promptVariantNames = _trustedPromptVariantNames(report, sourceCheck),
       workOrderLaunch = _map(sourceCheck?.sourceSummary['workOrderLaunch']),
       blockedReasonCodes =
           EvalUseCaseTuningCampaign._sanitizeReportBlockerCodes(
             report,
             _blockedCodesFromReport(report),
           );

  factory _CampaignReportSnapshot.fromReport({
    required int index,
    required Map<String, dynamic> report,
    required EvalTuningReportSourceCheckResult? sourceCheck,
    required bool requireSourceCheck,
  }) {
    return _CampaignReportSnapshot(
      index: index,
      report: report,
      contractIssues: EvalTuningReportContract.validate(report),
      sourceCheck: sourceCheck,
      requireSourceCheck: requireSourceCheck,
    );
  }

  final int index;
  final Map<String, dynamic> report;
  final List<String> contractIssues;
  final EvalTuningReportSourceCheckResult? sourceCheck;
  final bool requireSourceCheck;
  final String reportRef;
  final String reportDigest;
  final bool ready;
  final List<String> capabilities;
  final List<String> promptVariantNames;
  final Map<String, dynamic> workOrderLaunch;
  final List<String> blockedReasonCodes;

  bool get isValid =>
      contractIssues.isEmpty &&
      sourceIssueCodes.isEmpty &&
      (!requireSourceCheck || sourceCheck?.isSourceChecked == true);

  String get sourceCheckStatus {
    final check = sourceCheck;
    if (check != null) return check.sourceCheckStatus.name;
    return requireSourceCheck ? 'sourceMissing' : 'notRequired';
  }

  List<String> get sourceIssueCodes {
    final check = sourceCheck;
    if (check == null) {
      return requireSourceCheck
          ? const ['report.sourceCheckMissing']
          : const <String>[];
    }
    final issues = <String>[
      if (check.reportDigest != reportDigest)
        'report.sourceCheckDigestMismatch',
      if (check.sourceCheckStatus ==
              EvalTuningReportSourceCheckStatus.sourceChecked &&
          !check.isSourceChecked)
        'report.sourceCheckUnvalidated',
      if (!check.isSourceChecked) ...check.sourceIssueCodes,
    ]..sort();
    return issues;
  }

  String get selectorDigest => EvalProvenance.digestJson(<String, dynamic>{
    'capabilities': capabilities,
    'promptVariantNames': promptVariantNames,
  });

  String get compatibilityKey => EvalProvenance.digestJson(<String, dynamic>{
    'targetKind': _string(_map(report['run'])['targetKind']),
    'scenarioSetDigest': _string(_map(report['run'])['scenarioSetDigest']),
    'policyDigest': _string(_map(report['policy'])['digest']),
    'requiredCapabilities': _publicRequiredCapabilities,
    'requiredCapabilitySetDigest': EvalProvenance.digestJson(
      _sortedStrings(
        _stringList(
          _map(
            _map(report['run'])['selectors'],
          )['requiredPrimaryCapabilityIds'],
        ),
      ),
    ),
    'protectedIdsRedacted': _map(report['run'])['protectedIdsRedacted'] == true,
  });

  List<String> get _publicRequiredCapabilities => _sortedStrings(
    _stringList(
      _map(_map(report['run'])['selectors'])['requiredPrimaryCapabilityIds'],
    ),
  );

  bool matchesBatch({
    required String compatibilityKey,
    required String sourceExperimentPlanDigest,
    required String sourceMatrixDigest,
    required String workOrderBatchRef,
    required List<String> capabilities,
    required List<String> promptVariantNames,
  }) {
    return this.compatibilityKey == compatibilityKey &&
        overlapsSelectors(
          capabilities: capabilities,
          promptVariantNames: promptVariantNames,
        ) &&
        matchesWorkOrderLaunch(
          sourceExperimentPlanDigest: sourceExperimentPlanDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          workOrderBatchRef: workOrderBatchRef,
          capabilities: capabilities,
          promptVariantNames: promptVariantNames,
        );
  }

  bool overlapsSelectors({
    required List<String> capabilities,
    required List<String> promptVariantNames,
  }) {
    return capabilities.any(sliceCapabilities.contains) &&
        promptVariantNames.any(this.promptVariantNames.contains);
  }

  bool readyFor({
    required String sourceExperimentPlanDigest,
    required String sourceMatrixDigest,
    required String workOrderBatchRef,
    required List<String> capabilities,
    required List<String> promptVariantNames,
  }) {
    return ready &&
        blockedReasonCodes.isEmpty &&
        capabilities.any(readySliceCapabilities.contains) &&
        promptVariantNames.any(this.promptVariantNames.contains) &&
        matchesWorkOrderLaunch(
          sourceExperimentPlanDigest: sourceExperimentPlanDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          workOrderBatchRef: workOrderBatchRef,
          capabilities: capabilities,
          promptVariantNames: promptVariantNames,
        );
  }

  bool matchesWorkOrderLaunch({
    required String sourceExperimentPlanDigest,
    required String sourceMatrixDigest,
    required String workOrderBatchRef,
    required List<String> capabilities,
    required List<String> promptVariantNames,
  }) {
    if (!requireSourceCheck && sourceCheck == null) return true;
    if (workOrderLaunch.isEmpty) return false;
    return _string(workOrderLaunch['sourceExperimentPlanDigest']) ==
            sourceExperimentPlanDigest &&
        _string(workOrderLaunch['sourceMatrixDigest']) == sourceMatrixDigest &&
        _stringList(workOrderLaunch['workOrderBatchRefs']).contains(
          workOrderBatchRef,
        ) &&
        _sameStrings(
          _sortedStrings(
            _stringList(workOrderLaunch['requiredPrimaryCapabilityIds']),
          ),
          _sortedStrings(capabilities),
        ) &&
        _sameStrings(
          _sortedStrings(_stringList(workOrderLaunch['promptVariantNames'])),
          _sortedStrings(promptVariantNames),
        );
  }

  List<String> coveredCapabilitiesFor(List<String> planned) {
    return [
      for (final capability in planned)
        if (sliceCapabilities.contains(capability)) capability,
    ];
  }

  List<String> readyCapabilitiesFor(List<String> planned) {
    return [
      for (final capability in planned)
        if (readySliceCapabilities.contains(capability)) capability,
    ];
  }

  List<String> coveredPromptVariantsFor(List<String> planned) {
    if (!planned.any(promptVariantNames.contains)) return const <String>[];
    return [
      for (final promptVariantName in planned)
        if (promptVariantNames.contains(promptVariantName)) promptVariantName,
    ];
  }

  List<String> readyPromptVariantsFor(List<String> planned) {
    if (readySliceCapabilities.isEmpty) return const <String>[];
    return coveredPromptVariantsFor(planned);
  }

  List<String> get sliceCapabilities => _sortedStrings({
    for (final slice in _mapList(report['useCaseModelSlices']))
      _string(slice['primaryCapabilityId']),
  });

  List<String> get readySliceCapabilities => _sortedStrings({
    if (ready && blockedReasonCodes.isEmpty)
      for (final slice in _mapList(report['useCaseModelSlices']))
        if (_stringList(slice['blockingReasons']).isEmpty &&
            _string(slice['recommendation']) == 'keep')
          _string(slice['primaryCapabilityId']),
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reportRef': reportRef,
      'reportDigest': reportDigest,
      'selectorDigest': selectorDigest,
      'contractStatus': isValid ? 'valid' : 'invalid',
      'contractIssueCount': contractIssues.length + sourceIssueCodes.length,
      'sourceCheckStatus': sourceCheckStatus,
      'sourceIssueCount': sourceIssueCodes.length,
      'sourceIssueCodes': sourceIssueCodes,
      'sourceWorkOrderBatchRefCount': _stringList(
        workOrderLaunch['workOrderBatchRefs'],
      ).length,
      if (_string(workOrderLaunch['workOrderBatchSetDigest']).isNotEmpty)
        'sourceWorkOrderBatchSetDigest': _string(
          workOrderLaunch['workOrderBatchSetDigest'],
        ),
      'ready': ready,
      'blockedReasonCodes': blockedReasonCodes,
    };
  }

  static List<String> _trustedCapabilities(
    Map<String, dynamic> report,
    EvalTuningReportSourceCheckResult? sourceCheck,
  ) {
    final sourceCapabilities = _stringList(
      _sourcePublicSelectors(sourceCheck)['requiredPrimaryCapabilityIds'],
    );
    if (sourceCapabilities.isNotEmpty) {
      return _sortedStrings(sourceCapabilities);
    }
    return _sortedStrings(
      _stringList(
        _map(
          _map(report['run'])['selectors'],
        )['requiredPrimaryCapabilityIds'],
      ),
    );
  }

  static List<String> _trustedPromptVariantNames(
    Map<String, dynamic> report,
    EvalTuningReportSourceCheckResult? sourceCheck,
  ) {
    final sourcePromptVariants = _stringList(
      _sourcePublicSelectors(sourceCheck)['promptVariantNames'],
    );
    if (sourcePromptVariants.isNotEmpty) {
      return _sortedStrings(sourcePromptVariants);
    }
    return _sortedStrings(
      _stringList(_map(_map(report['run'])['selectors'])['promptVariantNames']),
    );
  }

  static Map<String, dynamic> _sourcePublicSelectors(
    EvalTuningReportSourceCheckResult? sourceCheck,
  ) => _map(sourceCheck?.sourceSummary['publicSelectors']);

  static List<String> _blockedCodesFromReport(Map<String, dynamic> report) {
    return _sortedStrings({
      for (final reason in _mapList(report['blockedReasons']))
        _string(reason['code']),
      for (final gate in _mapList(report['gates']))
        _string(gate['blockerCode']),
      for (final failure in _stringList(_map(report['readiness'])['failures']))
        failure,
      ..._stringList(_map(report['nextExperimentPlan'])['blockedReasonCodes']),
    });
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

List<String> _sortedStrings(Iterable<String> values) {
  final sorted =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return sorted;
}

bool _sameStrings(List<String> left, List<String> right) =>
    left.length == right.length &&
    left.indexed.every((entry) => entry.$2 == right[entry.$1]);
