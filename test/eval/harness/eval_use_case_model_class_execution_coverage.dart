import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_use_case_model_class_execution_evidence.dart';
import 'eval_use_case_next_run_work_order.dart';

enum EvalUseCaseModelClassExecutionCoverageSourceCheckStatus {
  sourceChecked,
  sourceInvalid;

  static EvalUseCaseModelClassExecutionCoverageSourceCheckStatus fromName(
    String name,
  ) => EvalUseCaseModelClassExecutionCoverageSourceCheckStatus.values
      .firstWhere((status) => status.name == name);
}

final class EvalUseCaseModelClassExecutionCoverageSourceCheckProof {
  EvalUseCaseModelClassExecutionCoverageSourceCheckProof({
    required this.sourceCheckStatus,
    required this.workOrderDigest,
    required this.bundleSetDigest,
    required List<String> bundleDigests,
    required List<String> executionEvidenceRefs,
    required List<String> sourceWorkOrderDigests,
    required this.sourceRunCount,
    required this.sourceRunRefsDigest,
    required List<String> sourceIssueCodes,
  }) : bundleDigests = List.unmodifiable(bundleDigests),
       executionEvidenceRefs = List.unmodifiable(executionEvidenceRefs),
       sourceWorkOrderDigests = List.unmodifiable(sourceWorkOrderDigests),
       sourceIssueCodes = List.unmodifiable(sourceIssueCodes),
       _validatedSourceCheck = false,
       _verifiedConcreteSources = false;

  EvalUseCaseModelClassExecutionCoverageSourceCheckProof._validated({
    required this.sourceCheckStatus,
    required this.workOrderDigest,
    required this.bundleSetDigest,
    required List<String> bundleDigests,
    required List<String> executionEvidenceRefs,
    required List<String> sourceWorkOrderDigests,
    required this.sourceRunCount,
    required this.sourceRunRefsDigest,
    required List<String> sourceIssueCodes,
    required this._verifiedConcreteSources,
  }) : bundleDigests = List.unmodifiable(bundleDigests),
       executionEvidenceRefs = List.unmodifiable(executionEvidenceRefs),
       sourceWorkOrderDigests = List.unmodifiable(sourceWorkOrderDigests),
       sourceIssueCodes = List.unmodifiable(sourceIssueCodes),
       _validatedSourceCheck = true;

  factory EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromJson(
    Map<String, dynamic> json,
  ) {
    return EvalUseCaseModelClassExecutionCoverageSourceCheckProof(
      sourceCheckStatus:
          EvalUseCaseModelClassExecutionCoverageSourceCheckStatus.fromName(
            _string(
              json['sourceCheckStatus'],
            ),
          ),
      workOrderDigest: _string(
        json['workOrderDigest'],
      ),
      bundleSetDigest: _string(
        json['bundleSetDigest'],
      ),
      bundleDigests: _stringList(
        json['bundleDigests'],
      ),
      executionEvidenceRefs: _stringList(
        json['executionEvidenceRefs'],
      ),
      sourceWorkOrderDigests: _stringList(
        json['sourceWorkOrderDigests'],
      ),
      sourceRunCount: _int(
        json['sourceRunCount'],
      ),
      sourceRunRefsDigest: _string(
        json['sourceRunRefsDigest'],
      ),
      sourceIssueCodes: _stringList(
        json['sourceIssueCodes'],
      ),
    );
  }

  factory EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromValidatedEvidenceBundles({
    required Map<String, dynamic> workOrder,
    required List<Map<String, dynamic>> sourceExecutionEvidenceBundles,
  }) {
    return EvalUseCaseModelClassExecutionCoverageSourceCheckProof._fromEvidenceBundles(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: sourceExecutionEvidenceBundles,
      verifiedConcreteSources: false,
    );
  }

  factory EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources({
    required Map<String, dynamic> workOrder,
    required List<Map<String, dynamic>> sourceExecutionEvidenceBundles,
    required List<EvalUseCaseModelClassExecutionRun> runs,
    required Map<String, dynamic> sourceExperimentPlan,
  }) {
    final concreteSourceIssueCodes = <String>{
      if (runs.isEmpty) 'coverage.sourceCheckSourceRunsMissing',
      for (final bundle in sourceExecutionEvidenceBundles)
        if (EvalUseCaseModelClassExecutionEvidence.validateAgainstSources(
          bundle,
          workOrder: workOrder,
          runs: runs,
          sourceExperimentPlan: sourceExperimentPlan,
        ).isNotEmpty)
          'coverage.sourceCheckEvidenceSourceMismatch',
    };
    return EvalUseCaseModelClassExecutionCoverageSourceCheckProof._fromEvidenceBundles(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: sourceExecutionEvidenceBundles,
      verifiedConcreteSources: true,
      extraIssueCodes: concreteSourceIssueCodes,
    );
  }

  factory EvalUseCaseModelClassExecutionCoverageSourceCheckProof._fromEvidenceBundles({
    required Map<String, dynamic> workOrder,
    required List<Map<String, dynamic>> sourceExecutionEvidenceBundles,
    required bool verifiedConcreteSources,
    Iterable<String> extraIssueCodes = const <String>[],
  }) {
    final workOrderDigest = EvalProvenance.digestJson(workOrder);
    final bundleDigests = _sortedStrings(
      sourceExecutionEvidenceBundles.map(EvalProvenance.digestJson),
    );
    final executionEvidenceRefs = _sortedStrings(
      sourceExecutionEvidenceBundles.map(
        (bundle) => _string(
          bundle['executionEvidenceRef'],
        ),
      ),
    );
    final sourceWorkOrderDigests = _sortedStrings(
      sourceExecutionEvidenceBundles.map(
        (bundle) => _string(
          _map(
            bundle['sourceWorkOrder'],
          )['workOrderDigest'],
        ),
      ),
    );
    final sourceRunRefs = _sortedStrings(
      sourceExecutionEvidenceBundles.expand<String>(
        (bundle) =>
            _mapList(
              bundle['sourceRuns'],
            ).map<String>(
              (sourceRun) => _string(
                sourceRun['sourceRunRef'],
              ),
            ),
      ),
    );
    final issueCodes = <String>{
      ...extraIssueCodes,
      for (final bundle in sourceExecutionEvidenceBundles)
        if (EvalUseCaseModelClassExecutionEvidence.validate(bundle).isNotEmpty)
          'coverage.sourceCheckEvidenceContractInvalid',
      for (final bundle in sourceExecutionEvidenceBundles)
        if (_string(
              bundle['status'],
            ) !=
            'ready')
          'coverage.sourceCheckEvidenceNotReady',
      for (final digest in sourceWorkOrderDigests)
        if (digest != workOrderDigest) 'coverage.sourceCheckWorkOrderMismatch',
      if (sourceExecutionEvidenceBundles.isEmpty)
        'coverage.sourceCheckEvidenceMissing',
    };
    return EvalUseCaseModelClassExecutionCoverageSourceCheckProof._validated(
      sourceCheckStatus: issueCodes.isEmpty
          ? EvalUseCaseModelClassExecutionCoverageSourceCheckStatus
                .sourceChecked
          : EvalUseCaseModelClassExecutionCoverageSourceCheckStatus
                .sourceInvalid,
      workOrderDigest: workOrderDigest,
      bundleSetDigest: EvalProvenance.digestJson(bundleDigests),
      bundleDigests: bundleDigests,
      executionEvidenceRefs: executionEvidenceRefs,
      sourceWorkOrderDigests: sourceWorkOrderDigests,
      sourceRunCount: sourceRunRefs.length,
      sourceRunRefsDigest: EvalProvenance.digestJson(sourceRunRefs),
      sourceIssueCodes: _sortedStrings(
        issueCodes,
      ),
      verifiedConcreteSources: verifiedConcreteSources,
    );
  }

  final EvalUseCaseModelClassExecutionCoverageSourceCheckStatus
  sourceCheckStatus;
  final String workOrderDigest;
  final String bundleSetDigest;
  final List<String> bundleDigests;
  final List<String> executionEvidenceRefs;
  final List<String> sourceWorkOrderDigests;
  final int sourceRunCount;
  final String sourceRunRefsDigest;
  final List<String> sourceIssueCodes;
  final bool _validatedSourceCheck;
  final bool _verifiedConcreteSources;

  bool get isSourceChecked =>
      _validatedSourceCheck &&
      _verifiedConcreteSources &&
      sourceCheckStatus ==
          EvalUseCaseModelClassExecutionCoverageSourceCheckStatus
              .sourceChecked &&
      sourceIssueCodes.isEmpty;

  String get sourceCheckRef => EvalProvenance.digestJson(_subjectJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'kind': 'lotti.evalUseCaseModelClassExecutionCoverageSourceCheckProof',
    'sourceCheckRef': sourceCheckRef,
    'sourceCheckStatus': sourceCheckStatus.name,
    'workOrderDigest': workOrderDigest,
    'bundleSetDigest': bundleSetDigest,
    'bundleDigests': bundleDigests,
    'executionEvidenceRefs': executionEvidenceRefs,
    'sourceWorkOrderDigests': sourceWorkOrderDigests,
    'sourceRunCount': sourceRunCount,
    'sourceRunRefsDigest': sourceRunRefsDigest,
    'sourceIssueCount': sourceIssueCodes.length,
    'sourceIssueCodes': sourceIssueCodes,
  };

  List<String> _bindingIssues({
    required String workOrderDigest,
    required List<_SourceExecutionEvidenceBundle> sourceEvidenceBundles,
  }) {
    final issues = <String>[];
    final expectedBundleDigests = _sortedStrings(
      sourceEvidenceBundles.map((bundle) => bundle.bundleDigest),
    );
    final expectedExecutionRefs = _sortedStrings(
      sourceEvidenceBundles.map((bundle) => bundle.executionEvidenceRef),
    );
    final expectedWorkOrderDigests = _sortedStrings(
      sourceEvidenceBundles.map((bundle) => bundle.sourceWorkOrderDigest),
    );
    final expectedSourceRunRefs = _sortedStrings(
      sourceEvidenceBundles.expand<String>(
        (bundle) => bundle.sourceRunRefs,
      ),
    );
    void compare(String field, Object? actual, Object? expected) {
      if (EvalProvenance.digestJson(actual) ==
          EvalProvenance.digestJson(expected)) {
        return;
      }
      issues.add('sourceCheckProof.$field must match source evidence');
    }

    compare('workOrderDigest', this.workOrderDigest, workOrderDigest);
    compare(
      'bundleSetDigest',
      bundleSetDigest,
      EvalProvenance.digestJson(expectedBundleDigests),
    );
    compare('bundleDigests', bundleDigests, expectedBundleDigests);
    compare(
      'executionEvidenceRefs',
      executionEvidenceRefs,
      expectedExecutionRefs,
    );
    compare(
      'sourceWorkOrderDigests',
      sourceWorkOrderDigests,
      expectedWorkOrderDigests,
    );
    compare('sourceRunCount', sourceRunCount, expectedSourceRunRefs.length);
    compare(
      'sourceRunRefsDigest',
      sourceRunRefsDigest,
      EvalProvenance.digestJson(expectedSourceRunRefs),
    );
    if (!isSourceChecked) {
      issues.add(
        'sourceCheckProof must be concrete source-checked evidence',
      );
    }
    return issues;
  }

  Map<String, dynamic> _subjectJson() => <String, dynamic>{
    'sourceCheckStatus': sourceCheckStatus.name,
    'workOrderDigest': workOrderDigest,
    'bundleSetDigest': bundleSetDigest,
    'bundleDigests': bundleDigests,
    'executionEvidenceRefs': executionEvidenceRefs,
    'sourceWorkOrderDigests': sourceWorkOrderDigests,
    'sourceRunCount': sourceRunCount,
    'sourceRunRefsDigest': sourceRunRefsDigest,
    'sourceIssueCodes': sourceIssueCodes,
  };
}

abstract final class EvalUseCaseModelClassExecutionCoverage {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseModelClassExecutionCoverage';
  static final Expando<String> _verifiedConcreteSourceReplayDigests =
      Expando<String>(
        'evalUseCaseModelClassExecutionCoverageConcreteSourceReplayDigest',
      );
  static const _allowedStatuses = {
    'covered',
    'partialCoverage',
    'noCoverage',
    'invalidSource',
  };
  static const _allowedCoverageStatuses = {'covered', 'partial', 'missing'};
  static const _allowedWorkOrderStatuses = {
    'invalidPlan',
    'blockedPlan',
    'noRunnableBatches',
    'ready',
  };
  static const _allowedEvidenceStatuses = {
    'ready',
    'partial',
    'empty',
    'invalidSource',
  };
  static const _allowedObjectives = {
    'collectData',
    'collectPromotionEvidence',
  };
  static const _allowedCommandModes = {
    'model-class-coverage',
    'next-run-work-order',
  };
  static final _safeSelectorPattern = RegExp(r'^[A-Za-z0-9_.:-]+$');
  static final _opaqueFallbackPattern = RegExp(
    r'^(capability|agent|model|prompt|recommendation|blocker)-[0-9a-f]{12}$',
  );
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=|file://)/(?:Users|home|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+|'
    'EVAL_PROMPT_VARIANTS|EVAL_USE_CASE_RUN_WORK_ORDER|'
    r'OPENAI_API_KEY|ANTHROPIC_API_KEY)\b',
  );

  static Map<String, dynamic> build({
    required Map<String, dynamic> workOrder,
    List<Map<String, dynamic>> executionEvidence = const [],
    List<Map<String, dynamic>> sourceExecutionEvidenceBundles = const [],
    DateTime? generatedAt,
    List<EvalModelClass> requiredModelClasses = EvalModelClass.values,
    int minProfileSlotsPerClass = 1,
    bool requireResolvedModelEvidence = true,
    bool requireProviderRequestEvidence = true,
    bool sourceEvidenceSourceChecked = false,
    EvalUseCaseModelClassExecutionCoverageSourceCheckProof? sourceCheckProof,
  }) {
    final boundedMinProfileSlots = minProfileSlotsPerClass < 1
        ? 1
        : minProfileSlotsPerClass;
    final workOrderIssues = EvalUseCaseNextRunWorkOrder.validate(workOrder);
    final workOrderDigest = EvalProvenance.digestJson(workOrder);
    final sourceWorkOrder = _map(workOrder['sourceExperimentPlan']);
    final runBatches = workOrderIssues.isEmpty
        ? _mapList(workOrder['runBatches'])
        : const <Map<String, dynamic>>[];
    final runBatchRefs = _sortedStrings(
      runBatches.map((batch) => _string(batch['workOrderBatchRef'])),
    );
    final sourceEvidenceBundles = [
      for (final indexed in sourceExecutionEvidenceBundles.indexed)
        _SourceExecutionEvidenceBundle.fromJson(
          index: indexed.$1,
          json: indexed.$2,
        ),
    ];
    final sourceExecutionEvidenceSetDigest = EvalProvenance.digestJson(
      _sortedStrings(
        sourceEvidenceBundles.map((bundle) => bundle.bundleDigest),
      ),
    );
    final concreteSourceChecked = sourceCheckProof?.isSourceChecked == true;
    final sourceCheckProofJson = sourceCheckProof?.toJson();
    final sourceCheckProofEntry = sourceCheckProofJson == null
        ? null
        : <String, dynamic>{'sourceCheckProof': sourceCheckProofJson};
    final sourceCheckSetDigest = EvalProvenance.digestJson([
      if (sourceCheckProof != null) sourceCheckProof.sourceCheckRef,
    ]);
    final executionEvidenceRefs = _sortedStrings(
      sourceEvidenceBundles.map((bundle) => bundle.executionEvidenceRef),
    );
    final sourceRunRefs = _sortedStrings(
      sourceEvidenceBundles.expand<String>((bundle) => bundle.sourceRunRefs),
    );
    final inputEvidence = sourceEvidenceBundles.isEmpty
        ? executionEvidence
        : [
            for (final bundle in sourceEvidenceBundles) ...bundle.evidenceRows,
          ];
    final evidenceRows = [
      for (final indexed in inputEvidence.indexed)
        _ExecutionEvidence.fromJson(indexed.$1, indexed.$2),
    ];
    final publicPolicyClasses = _sortedStrings(
      requiredModelClasses.map((modelClass) => modelClass.name),
    );
    final sourceIssues = _sourceIssues(
      workOrderIssues: workOrderIssues,
      workOrderDigest: workOrderDigest,
      sourceEvidenceBundles: sourceEvidenceBundles,
      evidenceRows: evidenceRows,
      requiredModelClasses: publicPolicyClasses,
      sourceEvidenceSourceChecked: sourceEvidenceSourceChecked,
      sourceCheckProof: sourceCheckProof,
    );
    final coverageCells = [
      if (sourceIssues.isEmpty)
        for (final batch in runBatches)
          for (final modelClass in publicPolicyClasses)
            _coverageCell(
              workOrderDigest: workOrderDigest,
              sourceExecutionEvidenceSetDigest:
                  sourceExecutionEvidenceSetDigest,
              batch: batch,
              modelClass: modelClass,
              evidenceRows: evidenceRows,
              minProfileSlotsPerClass: boundedMinProfileSlots,
              requireResolvedModelEvidence: requireResolvedModelEvidence,
              requireProviderRequestEvidence: requireProviderRequestEvidence,
            ),
    ];
    final modelClassCoverage = [
      if (sourceIssues.isEmpty)
        for (final modelClass in publicPolicyClasses)
          _modelClassCoverage(
            workOrderDigest: workOrderDigest,
            sourceExecutionEvidenceSetDigest: sourceExecutionEvidenceSetDigest,
            modelClass: modelClass,
            runBatchCount: runBatches.length,
            minProfileSlotsPerClass: boundedMinProfileSlots,
            cells: coverageCells,
          ),
    ];
    final issues = _coverageIssues(sourceIssues, coverageCells);
    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'coverageArtifactRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': _status(
        sourceIssues: sourceIssues,
        coverageCells: coverageCells,
      ),
      'sourceWorkOrder': <String, dynamic>{
        'kind': EvalUseCaseNextRunWorkOrder.kind,
        'schemaVersion': EvalUseCaseNextRunWorkOrder.schemaVersion,
        'status': _string(workOrder['status']).isEmpty
            ? 'unknown'
            : _string(workOrder['status']),
        'workOrderRef': _string(workOrder['workOrderRef']),
        'workOrderDigest': workOrderDigest,
        'sourceExperimentPlanDigest': _string(sourceWorkOrder['planDigest']),
        'sourceMatrixDigest': _string(sourceWorkOrder['sourceMatrixDigest']),
        'runBatchCount': runBatches.length,
        'runBatchRefsDigest': EvalProvenance.digestJson(runBatchRefs),
        'contractIssueCount': workOrderIssues.length,
      },
      'sourceExecutionEvidence': <String, dynamic>{
        'kind': EvalUseCaseModelClassExecutionEvidence.kind,
        'schemaVersion': EvalUseCaseModelClassExecutionEvidence.schemaVersion,
        'present': sourceEvidenceBundles.isNotEmpty,
        'bundleCount': sourceEvidenceBundles.length,
        'bundleSetDigest': sourceExecutionEvidenceSetDigest,
        'concreteSourceChecked': concreteSourceChecked,
        'sourceCheckSetDigest': sourceCheckSetDigest,
        ...?sourceCheckProofEntry,
        'bundleDigests': [
          for (final bundle in sourceEvidenceBundles) bundle.bundleDigest,
        ],
        'executionEvidenceRefs': executionEvidenceRefs,
        'statuses': _sortedStrings(
          sourceEvidenceBundles.map((bundle) => bundle.status),
        ),
        'sourceWorkOrderDigests': _sortedStrings(
          sourceEvidenceBundles.map((bundle) => bundle.sourceWorkOrderDigest),
        ),
        'sourceRunCount': sourceRunRefs.length,
        'sourceRunRefsDigest': EvalProvenance.digestJson(sourceRunRefs),
        'contractIssueCount': sourceEvidenceBundles.fold<int>(
          0,
          (sum, bundle) => sum + bundle.contractIssues.length,
        ),
      },
      'coveragePolicy': <String, dynamic>{
        'requiredModelClasses': publicPolicyClasses,
        'minProfileSlotsPerClass': boundedMinProfileSlots,
        'requireResolvedModelEvidence': requireResolvedModelEvidence,
        'requireProviderRequestEvidence': requireProviderRequestEvidence,
      },
      'summary': <String, dynamic>{
        'requiredModelClassCount': publicPolicyClasses.length,
        'coveredModelClassCount': _statusCount(
          modelClassCoverage,
          'covered',
        ),
        'missingModelClassCount': _statusCount(
          modelClassCoverage,
          'missing',
        ),
        'expectedTraceCount': _sum(coverageCells, 'expectedTraceCount'),
        'observedTraceCount': _sum(coverageCells, 'observedTraceCount'),
        'verifiedResolvedModelTraceCount': _sum(
          coverageCells,
          'verifiedResolvedModelTraceCount',
        ),
        'issueCount': issues.length,
      },
      'modelClassCoverage': modelClassCoverage,
      'coverageCells': coverageCells,
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'rawRunIdsOmitted': true,
        'providerIdsOmitted': true,
        'providerModelIdsOmitted': true,
        'localConfigIdsOmitted': true,
        'providerEndpointsOmitted': true,
        'promptTextOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
      },
      'limitations': const <String, dynamic>{
        'consumesWorkOrderAndExecutionEvidenceOnly': true,
        'privateEvidenceAggregatedOnly': true,
        'tracesReRead': false,
        'liveModelCallsStarted': false,
        'runtimeConfigurationApplied': false,
      },
      'issues': issues,
      'recommendedCommands': _recommendedCommands(),
    };
    artifact['coverageArtifactRef'] = coverageArtifactRef(artifact);
    assertValid(artifact);
    return artifact;
  }

  static bool hasVerifiedConcreteSourceReplay(
    Map<String, dynamic> coverage,
  ) {
    return _verifiedConcreteSourceReplayDigests[coverage] ==
        EvalProvenance.digestJson(coverage);
  }

  static String coverageArtifactRef(Map<String, dynamic> coverage) =>
      EvalProvenance.digestJson(_coverageArtifactSubject(coverage));

  static List<String> validate(Map<String, dynamic> coverage) {
    final issues = <String>[];
    _expectEquals(
      issues,
      coverage['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, coverage['kind'], kind, 'kind');
    _expectDigest(
      issues,
      coverage['coverageArtifactRef'],
      'coverageArtifactRef',
    );
    _expectIsoDate(issues, coverage['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, coverage['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final sourceWorkOrder = _expectMap(
      issues,
      coverage['sourceWorkOrder'],
      'sourceWorkOrder',
    );
    _validateSourceWorkOrder(issues, sourceWorkOrder);
    final sourceExecutionEvidence = _expectMap(
      issues,
      coverage['sourceExecutionEvidence'],
      'sourceExecutionEvidence',
    );
    _validateSourceExecutionEvidence(
      issues,
      sourceExecutionEvidence,
    );
    final policy = _expectMap(
      issues,
      coverage['coveragePolicy'],
      'coveragePolicy',
    );
    _validatePolicy(issues, policy);
    final summary = _expectMap(issues, coverage['summary'], 'summary');
    _validateSummary(issues, summary);
    final modelClassCoverage = _expectList(
      issues,
      coverage['modelClassCoverage'],
      'modelClassCoverage',
    );
    _validateModelClassCoverage(
      issues,
      modelClassCoverage,
      workOrderDigest: _string(sourceWorkOrder?['workOrderDigest']),
      sourceExecutionEvidenceSetDigest: _string(
        sourceExecutionEvidence?['bundleSetDigest'],
      ),
    );
    final coverageCells = _expectList(
      issues,
      coverage['coverageCells'],
      'coverageCells',
    );
    _validateCoverageCells(
      issues,
      coverageCells,
      workOrderDigest: _string(sourceWorkOrder?['workOrderDigest']),
      sourceExecutionEvidenceSetDigest: _string(
        sourceExecutionEvidence?['bundleSetDigest'],
      ),
    );
    _validatePrivacy(
      issues,
      _expectMap(issues, coverage['privacy'], 'privacy'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, coverage['limitations'], 'limitations'),
    );
    final artifactIssues = _expectList(
      issues,
      coverage['issues'],
      'issues',
    );
    _validateIssues(issues, artifactIssues);
    _validateSourceEvidenceWorkOrderBinding(
      issues,
      sourceExecutionEvidence: sourceExecutionEvidence,
      sourceWorkOrder: sourceWorkOrder,
      artifactIssues: artifactIssues,
    );
    _validateCommands(
      issues,
      _expectList(
        issues,
        coverage['recommendedCommands'],
        'recommendedCommands',
      ),
    );
    _validateSummaryInvariants(
      issues,
      summary: summary,
      policy: policy,
      modelClassCoverage: modelClassCoverage,
      coverageCells: coverageCells,
      artifactIssues: artifactIssues,
    );
    _validateStatusInvariants(
      issues,
      status: status,
      sourceExecutionEvidence: sourceExecutionEvidence,
      coverageCells: coverageCells,
      artifactIssues: artifactIssues,
    );
    _validateCoverageArtifactRef(issues, coverage);
    _validateNoPrivatePayloads(issues, coverage, 'coverage');
    return issues;
  }

  static void assertValid(Map<String, dynamic> coverage) {
    final issues = validate(coverage);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case model-class execution coverage:\n'
      '${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstWorkOrder(
    Map<String, dynamic> coverage, {
    required Map<String, dynamic> workOrder,
  }) {
    final issues = validate(coverage);
    final workOrderIssues = EvalUseCaseNextRunWorkOrder.validate(workOrder);
    if (workOrderIssues.isNotEmpty) {
      issues.add('source work order contract is invalid');
      return issues;
    }
    final source = _map(coverage['sourceWorkOrder']);
    final workOrderSource = _map(workOrder['sourceExperimentPlan']);
    final expectedWorkOrderDigest = EvalProvenance.digestJson(workOrder);
    if (_string(source['workOrderDigest']) != expectedWorkOrderDigest) {
      issues.add('sourceWorkOrder.workOrderDigest must match workOrder');
    }
    if (_string(source['workOrderRef']) != _string(workOrder['workOrderRef'])) {
      issues.add('sourceWorkOrder.workOrderRef must match workOrder');
    }
    if (_string(source['sourceExperimentPlanDigest']) !=
        _string(workOrderSource['planDigest'])) {
      issues.add(
        'sourceWorkOrder.sourceExperimentPlanDigest must match workOrder',
      );
    }
    if (_string(source['sourceMatrixDigest']) !=
        _string(workOrderSource['sourceMatrixDigest'])) {
      issues.add('sourceWorkOrder.sourceMatrixDigest must match workOrder');
    }
    if (_int(source['runBatchCount']) !=
        _mapList(workOrder['runBatches']).length) {
      issues.add('sourceWorkOrder.runBatchCount must match workOrder');
    }
    final expectedRunBatchRefsDigest = EvalProvenance.digestJson(
      _sortedStrings(
        _mapList(
          workOrder['runBatches'],
        ).map((batch) => _string(batch['workOrderBatchRef'])),
      ),
    );
    if (_string(source['runBatchRefsDigest']) != expectedRunBatchRefsDigest) {
      issues.add('sourceWorkOrder.runBatchRefsDigest must match workOrder');
    }
    return issues;
  }

  static void assertMatchesWorkOrder(
    Map<String, dynamic> coverage, {
    required Map<String, dynamic> workOrder,
  }) {
    final issues = validateAgainstWorkOrder(coverage, workOrder: workOrder);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case model-class execution coverage source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstSources(
    Map<String, dynamic> coverage, {
    required Map<String, dynamic> workOrder,
    required List<Map<String, dynamic>> sourceExecutionEvidenceBundles,
    required List<EvalUseCaseModelClassExecutionRun> runs,
    required Map<String, dynamic> sourceExperimentPlan,
  }) {
    final issues = validate(coverage);
    final workOrderIssues =
        EvalUseCaseNextRunWorkOrder.validateAgainstExperimentPlan(
          workOrder,
          experimentPlan: sourceExperimentPlan,
        );
    if (workOrderIssues.isNotEmpty) {
      issues.add('source work order contract is invalid');
    }
    for (final indexed in sourceExecutionEvidenceBundles.indexed) {
      final bundleIssues =
          EvalUseCaseModelClassExecutionEvidence.validateAgainstSources(
            indexed.$2,
            workOrder: workOrder,
            runs: runs,
            sourceExperimentPlan: sourceExperimentPlan,
          );
      if (bundleIssues.isNotEmpty) {
        issues.add(
          'sourceExecutionEvidenceBundles[${indexed.$1}] must match source '
          'work order and runs',
        );
      }
    }
    final generatedAt = DateTime.tryParse(_string(coverage['generatedAt']));
    final expected = build(
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: sourceExecutionEvidenceBundles,
      generatedAt: generatedAt,
      sourceCheckProof:
          EvalUseCaseModelClassExecutionCoverageSourceCheckProof.fromVerifiedSources(
            workOrder: workOrder,
            sourceExecutionEvidenceBundles: sourceExecutionEvidenceBundles,
            runs: runs,
            sourceExperimentPlan: sourceExperimentPlan,
          ),
    );

    void expectMatches(String field) {
      if (EvalProvenance.digestJson(coverage[field]) !=
          EvalProvenance.digestJson(expected[field])) {
        issues.add('$field must match source work order, evidence, and runs');
      }
    }

    const [
      'status',
      'sourceWorkOrder',
      'sourceExecutionEvidence',
      'coveragePolicy',
      'summary',
      'modelClassCoverage',
      'coverageCells',
      'privacy',
      'limitations',
      'issues',
      'recommendedCommands',
    ].forEach(expectMatches);
    if (_string(coverage['coverageArtifactRef']) !=
        _string(expected['coverageArtifactRef'])) {
      issues.add(
        'coverageArtifactRef must match source work order, evidence, and runs',
      );
    }
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> coverage, {
    required Map<String, dynamic> workOrder,
    required List<Map<String, dynamic>> sourceExecutionEvidenceBundles,
    required List<EvalUseCaseModelClassExecutionRun> runs,
    required Map<String, dynamic> sourceExperimentPlan,
  }) {
    final issues = validateAgainstSources(
      coverage,
      workOrder: workOrder,
      sourceExecutionEvidenceBundles: sourceExecutionEvidenceBundles,
      runs: runs,
      sourceExperimentPlan: sourceExperimentPlan,
    );
    if (issues.isEmpty) {
      _markVerifiedConcreteSourceReplay(coverage);
      return;
    }
    throw StateError(
      'Invalid use-case model-class execution coverage source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static void _markVerifiedConcreteSourceReplay(
    Map<String, dynamic> coverage,
  ) {
    _verifiedConcreteSourceReplayDigests[coverage] = EvalProvenance.digestJson(
      coverage,
    );
  }

  static List<Map<String, dynamic>> _sourceIssues({
    required List<String> workOrderIssues,
    required String workOrderDigest,
    required List<_SourceExecutionEvidenceBundle> sourceEvidenceBundles,
    required List<_ExecutionEvidence> evidenceRows,
    required List<String> requiredModelClasses,
    required bool sourceEvidenceSourceChecked,
    required EvalUseCaseModelClassExecutionCoverageSourceCheckProof?
    sourceCheckProof,
  }) {
    return [
      if (workOrderIssues.isNotEmpty)
        <String, dynamic>{
          'code': 'coverage.workOrderContractInvalid',
          'severity': 'blocking',
          'contractIssueCount': workOrderIssues.length,
        },
      if (sourceEvidenceBundles.isEmpty)
        const <String, dynamic>{
          'code': 'coverage.executionEvidenceBundleMissing',
          'severity': 'blocking',
        },
      if (sourceEvidenceBundles.isNotEmpty && sourceCheckProof == null)
        const <String, dynamic>{
          'code': 'coverage.executionEvidenceSourceNotChecked',
          'severity': 'blocking',
        },
      if (sourceEvidenceBundles.isNotEmpty &&
          sourceEvidenceSourceChecked &&
          sourceCheckProof == null)
        const <String, dynamic>{
          'code': 'coverage.executionEvidenceSourceCheckProofMissing',
          'severity': 'blocking',
        },
      if (sourceEvidenceBundles.isNotEmpty && sourceCheckProof != null)
        for (final issue in sourceCheckProof._bindingIssues(
          workOrderDigest: workOrderDigest,
          sourceEvidenceBundles: sourceEvidenceBundles,
        ))
          <String, dynamic>{
            'code': 'coverage.executionEvidenceSourceCheckProofInvalid',
            'severity': 'blocking',
            'message': issue,
          },
      for (final bundle in sourceEvidenceBundles)
        ...bundle.issues(
          expectedWorkOrderDigest: workOrderDigest,
        ),
      for (final modelClass in requiredModelClasses)
        if (!_isEnumModelClass(modelClass))
          <String, dynamic>{
            'code': 'coverage.policyModelClassInvalid',
            'severity': 'blocking',
          },
      for (final row in evidenceRows) ...row.issues,
    ];
  }

  static Map<String, dynamic> _coverageCell({
    required String workOrderDigest,
    required String sourceExecutionEvidenceSetDigest,
    required Map<String, dynamic> batch,
    required String modelClass,
    required List<_ExecutionEvidence> evidenceRows,
    required int minProfileSlotsPerClass,
    required bool requireResolvedModelEvidence,
    required bool requireProviderRequestEvidence,
  }) {
    final workOrderBatchRef = _string(batch['workOrderBatchRef']);
    final selectors = _map(batch['publicSelectors']);
    final matchingRows = [
      for (final row in evidenceRows)
        if (row.modelClass == modelClass &&
            row.workOrderBatchRef == workOrderBatchRef)
          row,
    ];
    final expectedTraceCount = matchingRows.fold<int>(
      0,
      (sum, row) => sum + row.expectedTraceCount,
    );
    final observedTraceCount = matchingRows.fold<int>(
      0,
      (sum, row) => sum + row.observedTraceCount,
    );
    final verifiedResolvedModelTraceCount = matchingRows.fold<int>(
      0,
      (sum, row) => sum + row.verifiedResolvedModelTraceCount,
    );
    final observedProfileSlotCount = {
      for (final row in matchingRows) row.profileSlotRef,
    }.where((value) => value.isNotEmpty).length;
    final issueCodes = _cellIssueCodes(
      expectedTraceCount: expectedTraceCount,
      observedTraceCount: observedTraceCount,
      verifiedResolvedModelTraceCount: verifiedResolvedModelTraceCount,
      observedProfileSlotCount: observedProfileSlotCount,
      minProfileSlotsPerClass: minProfileSlotsPerClass,
      requireResolvedModelEvidence: requireResolvedModelEvidence,
      requireProviderRequestEvidence: requireProviderRequestEvidence,
      evidenceRows: matchingRows,
    );
    final status = _coverageStatus(issueCodes);
    final source = <String, dynamic>{
      'workOrderDigest': workOrderDigest,
      'sourceExecutionEvidenceSetDigest': sourceExecutionEvidenceSetDigest,
      'workOrderBatchRef': workOrderBatchRef,
      'modelClass': modelClass,
      'publicSelectors': selectors,
      'objective': _string(batch['objective']),
      'expectedTraceCount': expectedTraceCount,
      'observedTraceCount': observedTraceCount,
      'verifiedResolvedModelTraceCount': verifiedResolvedModelTraceCount,
      'status': status,
      'issueCodes': issueCodes,
    };
    return <String, dynamic>{
      'coverageCellRef': EvalProvenance.digestJson(source),
      'workOrderBatchRef': workOrderBatchRef,
      'modelClass': modelClass,
      'publicSelectors': selectors,
      'objective': _string(batch['objective']),
      'expectedTraceCount': expectedTraceCount,
      'observedTraceCount': observedTraceCount,
      'verifiedResolvedModelTraceCount': verifiedResolvedModelTraceCount,
      'status': status,
      'issueCodes': issueCodes,
    };
  }

  static Map<String, dynamic> _modelClassCoverage({
    required String workOrderDigest,
    required String sourceExecutionEvidenceSetDigest,
    required String modelClass,
    required int runBatchCount,
    required int minProfileSlotsPerClass,
    required List<Map<String, dynamic>> cells,
  }) {
    final classCells = [
      for (final cell in cells)
        if (cell['modelClass'] == modelClass) cell,
    ];
    final status =
        classCells.isEmpty ||
            classCells.any((cell) => cell['status'] == 'missing')
        ? 'missing'
        : classCells.any((cell) => cell['status'] == 'partial')
        ? 'partial'
        : 'covered';
    final workOrderBatchRefs = _sortedStrings(
      classCells.map((cell) => _string(cell['workOrderBatchRef'])),
    );
    final expectedProfileSlotCount = runBatchCount * minProfileSlotsPerClass;
    final observedProfileSlotCount = classCells.fold<int>(
      0,
      (sum, cell) => sum + (_string(cell['status']) == 'missing' ? 0 : 1),
    );
    final source = <String, dynamic>{
      'workOrderDigest': workOrderDigest,
      'sourceExecutionEvidenceSetDigest': sourceExecutionEvidenceSetDigest,
      'modelClass': modelClass,
      'status': status,
      'expectedProfileSlotCount': expectedProfileSlotCount,
      'observedProfileSlotCount': observedProfileSlotCount,
      'expectedTraceCount': _sum(classCells, 'expectedTraceCount'),
      'observedTraceCount': _sum(classCells, 'observedTraceCount'),
      'verifiedResolvedModelTraceCount': _sum(
        classCells,
        'verifiedResolvedModelTraceCount',
      ),
      'workOrderBatchRefs': workOrderBatchRefs,
    };
    return <String, dynamic>{
      ...source,
      'coverageRef': EvalProvenance.digestJson(source),
    };
  }

  static List<String> _cellIssueCodes({
    required int expectedTraceCount,
    required int observedTraceCount,
    required int verifiedResolvedModelTraceCount,
    required int observedProfileSlotCount,
    required int minProfileSlotsPerClass,
    required bool requireResolvedModelEvidence,
    required bool requireProviderRequestEvidence,
    required List<_ExecutionEvidence> evidenceRows,
  }) {
    return _sortedStrings({
      if (evidenceRows.isEmpty) 'coverage.modelClassMissing',
      if (observedProfileSlotCount < minProfileSlotsPerClass)
        'coverage.profileSlotMissing',
      if (expectedTraceCount == 0) 'coverage.expectedTraceCountMissing',
      if (observedTraceCount < expectedTraceCount)
        'coverage.observedTraceCountIncomplete',
      if (requireResolvedModelEvidence &&
          verifiedResolvedModelTraceCount < observedTraceCount)
        'coverage.resolvedModelEvidenceIncomplete',
      if (requireProviderRequestEvidence &&
          evidenceRows.any((row) => !row.providerRequestEvidence))
        'coverage.providerRequestEvidenceMissing',
    });
  }

  static String _coverageStatus(List<String> issueCodes) {
    if (issueCodes.contains('coverage.modelClassMissing')) return 'missing';
    if (issueCodes.isNotEmpty) return 'partial';
    return 'covered';
  }

  static List<Map<String, dynamic>> _coverageIssues(
    List<Map<String, dynamic>> sourceIssues,
    List<Map<String, dynamic>> coverageCells,
  ) {
    return [
      ...sourceIssues,
      for (final cell in coverageCells)
        for (final code in _stringList(cell['issueCodes']))
          <String, dynamic>{
            'code': code,
            'severity': code.endsWith('Missing') ? 'blocking' : 'warning',
            'coverageCellRef': cell['coverageCellRef'],
            'workOrderBatchRef': cell['workOrderBatchRef'],
            'modelClass': cell['modelClass'],
          },
    ];
  }

  static String _status({
    required List<Map<String, dynamic>> sourceIssues,
    required List<Map<String, dynamic>> coverageCells,
  }) {
    if (sourceIssues.isNotEmpty) return 'invalidSource';
    if (coverageCells.isEmpty ||
        coverageCells.every((cell) => cell['status'] == 'missing')) {
      return 'noCoverage';
    }
    if (coverageCells.every((cell) => cell['status'] == 'covered')) {
      return 'covered';
    }
    return 'partialCoverage';
  }

  static List<Map<String, dynamic>> _recommendedCommands() {
    return const [
      <String, dynamic>{
        'mode': 'model-class-coverage',
        'command': 'eval/run_level2.sh model-class-coverage',
        'valuesOmitted': true,
      },
      <String, dynamic>{
        'mode': 'next-run-work-order',
        'command': 'eval/run_level2.sh next-run-work-order',
        'valuesOmitted': true,
      },
    ];
  }

  static void _validateSourceWorkOrder(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseNextRunWorkOrder.kind,
      'sourceWorkOrder.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseNextRunWorkOrder.schemaVersion,
      'sourceWorkOrder.schemaVersion',
    );
    final status = _expectNonEmptyString(
      issues,
      source['status'],
      'sourceWorkOrder.status',
    );
    if (status != null && !_allowedWorkOrderStatuses.contains(status)) {
      issues.add('sourceWorkOrder.status must be a work-order status');
    }
    for (final field in const [
      'workOrderRef',
      'workOrderDigest',
      'sourceExperimentPlanDigest',
      'sourceMatrixDigest',
    ]) {
      _expectDigest(issues, source[field], 'sourceWorkOrder.$field');
    }
    _expectNonNegativeInt(
      issues,
      source['runBatchCount'],
      'sourceWorkOrder.runBatchCount',
    );
    _expectDigest(
      issues,
      source['runBatchRefsDigest'],
      'sourceWorkOrder.runBatchRefsDigest',
    );
    _expectNonNegativeInt(
      issues,
      source['contractIssueCount'],
      'sourceWorkOrder.contractIssueCount',
    );
  }

  static void _validateSourceExecutionEvidence(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectEquals(
      issues,
      source['kind'],
      EvalUseCaseModelClassExecutionEvidence.kind,
      'sourceExecutionEvidence.kind',
    );
    _expectEquals(
      issues,
      source['schemaVersion'],
      EvalUseCaseModelClassExecutionEvidence.schemaVersion,
      'sourceExecutionEvidence.schemaVersion',
    );
    _expectBool(
      issues,
      source['present'],
      'sourceExecutionEvidence.present',
    );
    _expectNonNegativeInt(
      issues,
      source['bundleCount'],
      'sourceExecutionEvidence.bundleCount',
    );
    _expectDigest(
      issues,
      source['bundleSetDigest'],
      'sourceExecutionEvidence.bundleSetDigest',
    );
    _expectBool(
      issues,
      source['concreteSourceChecked'],
      'sourceExecutionEvidence.concreteSourceChecked',
    );
    _expectDigest(
      issues,
      source['sourceCheckSetDigest'],
      'sourceExecutionEvidence.sourceCheckSetDigest',
    );
    final statuses = _expectStringList(
      issues,
      source['statuses'],
      'sourceExecutionEvidence.statuses',
    );
    if (statuses != null) {
      for (final status in statuses) {
        if (!_allowedEvidenceStatuses.contains(status)) {
          issues.add(
            'sourceExecutionEvidence.statuses must contain evidence statuses',
          );
        }
      }
    }
    final bundleDigests = _expectStringList(
      issues,
      source['bundleDigests'],
      'sourceExecutionEvidence.bundleDigests',
    );
    if (bundleDigests != null) {
      for (final digest in bundleDigests) {
        if (!EvalProvenance.isDigest(digest)) {
          issues.add(
            'sourceExecutionEvidence.bundleDigests must contain sha256 digests',
          );
        }
      }
    }
    final executionEvidenceRefs = _expectStringList(
      issues,
      source['executionEvidenceRefs'],
      'sourceExecutionEvidence.executionEvidenceRefs',
    );
    if (executionEvidenceRefs != null) {
      for (final digest in executionEvidenceRefs) {
        if (!EvalProvenance.isDigest(digest)) {
          issues.add(
            'sourceExecutionEvidence.executionEvidenceRefs must contain sha256 digests',
          );
        }
      }
    }
    final workOrderDigests = _expectStringList(
      issues,
      source['sourceWorkOrderDigests'],
      'sourceExecutionEvidence.sourceWorkOrderDigests',
    );
    if (workOrderDigests != null) {
      for (final digest in workOrderDigests) {
        if (digest.isNotEmpty && !EvalProvenance.isDigest(digest)) {
          issues.add(
            'sourceExecutionEvidence.sourceWorkOrderDigests must contain sha256 digests',
          );
        }
      }
    }
    _expectNonNegativeInt(
      issues,
      source['contractIssueCount'],
      'sourceExecutionEvidence.contractIssueCount',
    );
    _expectNonNegativeInt(
      issues,
      source['sourceRunCount'],
      'sourceExecutionEvidence.sourceRunCount',
    );
    _expectDigest(
      issues,
      source['sourceRunRefsDigest'],
      'sourceExecutionEvidence.sourceRunRefsDigest',
    );
    final expectedDigest = EvalProvenance.digestJson(
      _sortedStrings(bundleDigests ?? const <String>[]),
    );
    if (source['bundleSetDigest'] != expectedDigest) {
      issues.add(
        'sourceExecutionEvidence.bundleSetDigest must bind bundleDigests',
      );
    }
    final proof = source['sourceCheckProof'];
    final proofRefs = <String>[];
    if (proof != null) {
      final proofMap = _expectMap(
        issues,
        proof,
        'sourceExecutionEvidence.sourceCheckProof',
      );
      if (proofMap != null) {
        _validateSourceCheckProof(
          issues,
          proofMap,
          'sourceExecutionEvidence.sourceCheckProof',
        );
        proofRefs.add(_string(proofMap['sourceCheckRef']));
      }
    }
    if (source['sourceCheckSetDigest'] !=
        EvalProvenance.digestJson(proofRefs)) {
      issues.add(
        'sourceExecutionEvidence.sourceCheckSetDigest must bind source check refs',
      );
    }
    if (source['concreteSourceChecked'] == true) {
      if (proof == null) {
        issues.add(
          'sourceExecutionEvidence.concreteSourceChecked=true requires sourceCheckProof',
        );
      } else if (proof is Map<String, dynamic>) {
        if (proof['sourceCheckStatus'] !=
            EvalUseCaseModelClassExecutionCoverageSourceCheckStatus
                .sourceChecked
                .name) {
          issues.add(
            'sourceExecutionEvidence.sourceCheckProof must be sourceChecked',
          );
        }
        if (proof['sourceIssueCount'] != 0 ||
            _stringList(proof['sourceIssueCodes']).isNotEmpty) {
          issues.add(
            'sourceExecutionEvidence.sourceCheckProof must have no source issues',
          );
        }
      }
    }
  }

  static void _validateSourceCheckProof(
    List<String> issues,
    Map<String, dynamic> proof,
    String path,
  ) {
    _expectEquals(issues, proof['schemaVersion'], 1, '$path.schemaVersion');
    _expectEquals(
      issues,
      proof['kind'],
      'lotti.evalUseCaseModelClassExecutionCoverageSourceCheckProof',
      '$path.kind',
    );
    _expectDigest(issues, proof['sourceCheckRef'], '$path.sourceCheckRef');
    final status = _expectNonEmptyString(
      issues,
      proof['sourceCheckStatus'],
      '$path.sourceCheckStatus',
    );
    if (status != null &&
        !EvalUseCaseModelClassExecutionCoverageSourceCheckStatus.values
            .map((value) => value.name)
            .contains(status)) {
      issues.add('$path.sourceCheckStatus must be a source-check status');
    }
    for (final field in const [
      'workOrderDigest',
      'bundleSetDigest',
      'sourceRunRefsDigest',
    ]) {
      _expectDigest(issues, proof[field], '$path.$field');
    }
    for (final field in const [
      'bundleDigests',
      'executionEvidenceRefs',
      'sourceWorkOrderDigests',
    ]) {
      final values = _expectStringList(issues, proof[field], '$path.$field');
      if (values == null) continue;
      for (final value in values) {
        if (!EvalProvenance.isDigest(value)) {
          issues.add('$path.$field must contain sha256 digests');
        }
      }
    }
    _expectNonNegativeInt(
      issues,
      proof['sourceRunCount'],
      '$path.sourceRunCount',
    );
    _expectNonNegativeInt(
      issues,
      proof['sourceIssueCount'],
      '$path.sourceIssueCount',
    );
    final sourceIssueCodes = _expectStringList(
      issues,
      proof['sourceIssueCodes'],
      '$path.sourceIssueCodes',
    );
    if (sourceIssueCodes != null &&
        proof['sourceIssueCount'] is int &&
        proof['sourceIssueCount'] != sourceIssueCodes.length) {
      issues.add('$path.sourceIssueCount must match sourceIssueCodes.length');
    }
    final expectedRef = EvalProvenance.digestJson(
      _sourceCheckProofSubjectJson(proof),
    );
    if (proof['sourceCheckRef'] != expectedRef) {
      issues.add('$path.sourceCheckRef must bind source-check proof fields');
    }
  }

  static Map<String, dynamic> _sourceCheckProofSubjectJson(
    Map<String, dynamic> proof,
  ) => <String, dynamic>{
    'sourceCheckStatus': _string(proof['sourceCheckStatus']),
    'workOrderDigest': _string(proof['workOrderDigest']),
    'bundleSetDigest': _string(proof['bundleSetDigest']),
    'bundleDigests': _stringList(proof['bundleDigests']),
    'executionEvidenceRefs': _stringList(proof['executionEvidenceRefs']),
    'sourceWorkOrderDigests': _stringList(proof['sourceWorkOrderDigests']),
    'sourceRunCount': _int(proof['sourceRunCount']),
    'sourceRunRefsDigest': _string(proof['sourceRunRefsDigest']),
    'sourceIssueCodes': _stringList(proof['sourceIssueCodes']),
  };

  static void _validatePolicy(
    List<String> issues,
    Map<String, dynamic>? policy,
  ) {
    if (policy == null) return;
    final classes = _expectStringList(
      issues,
      policy['requiredModelClasses'],
      'coveragePolicy.requiredModelClasses',
    );
    if (classes != null) {
      if (classes.isEmpty) {
        issues.add('coveragePolicy.requiredModelClasses must not be empty');
      }
      for (final modelClass in classes) {
        if (!_isEnumModelClass(modelClass)) {
          issues.add(
            'coveragePolicy.requiredModelClasses contains unsupported model class $modelClass',
          );
        }
      }
    }
    _expectNonNegativeInt(
      issues,
      policy['minProfileSlotsPerClass'],
      'coveragePolicy.minProfileSlotsPerClass',
    );
    _expectBool(
      issues,
      policy['requireResolvedModelEvidence'],
      'coveragePolicy.requireResolvedModelEvidence',
    );
    _expectBool(
      issues,
      policy['requireProviderRequestEvidence'],
      'coveragePolicy.requireProviderRequestEvidence',
    );
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'requiredModelClassCount',
      'coveredModelClassCount',
      'missingModelClassCount',
      'expectedTraceCount',
      'observedTraceCount',
      'verifiedResolvedModelTraceCount',
      'issueCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validateModelClassCoverage(
    List<String> issues,
    List<dynamic>? values, {
    required String workOrderDigest,
    required String sourceExecutionEvidenceSetDigest,
  }) {
    if (values == null) return;
    for (final (index, value) in values.indexed) {
      final path = 'modelClassCoverage[$index]';
      final coverage = _expectMap(issues, value, path);
      if (coverage == null) continue;
      final modelClass = _expectNonEmptyString(
        issues,
        coverage['modelClass'],
        '$path.modelClass',
      );
      if (modelClass != null && !_isEnumModelClass(modelClass)) {
        issues.add('$path.modelClass must be an EvalModelClass name');
      }
      final status = _expectNonEmptyString(
        issues,
        coverage['status'],
        '$path.status',
      );
      if (status != null && !_allowedCoverageStatuses.contains(status)) {
        issues.add('$path.status must be supported');
      }
      for (final field in const [
        'expectedProfileSlotCount',
        'observedProfileSlotCount',
        'expectedTraceCount',
        'observedTraceCount',
        'verifiedResolvedModelTraceCount',
      ]) {
        _expectNonNegativeInt(issues, coverage[field], '$path.$field');
      }
      _expectStringList(
        issues,
        coverage['workOrderBatchRefs'],
        '$path.workOrderBatchRefs',
      );
      _expectDigest(issues, coverage['coverageRef'], '$path.coverageRef');
      final expectedRef = EvalProvenance.digestJson(<String, dynamic>{
        'workOrderDigest': workOrderDigest,
        'sourceExecutionEvidenceSetDigest': sourceExecutionEvidenceSetDigest,
        'modelClass': _string(coverage['modelClass']),
        'status': _string(coverage['status']),
        'expectedProfileSlotCount': coverage['expectedProfileSlotCount'],
        'observedProfileSlotCount': coverage['observedProfileSlotCount'],
        'expectedTraceCount': coverage['expectedTraceCount'],
        'observedTraceCount': coverage['observedTraceCount'],
        'verifiedResolvedModelTraceCount':
            coverage['verifiedResolvedModelTraceCount'],
        'workOrderBatchRefs': _stringList(coverage['workOrderBatchRefs']),
      });
      if (coverage['coverageRef'] != expectedRef) {
        issues.add('$path.coverageRef must bind model-class coverage fields');
      }
    }
  }

  static void _validateCoverageCells(
    List<String> issues,
    List<dynamic>? cells, {
    required String workOrderDigest,
    required String sourceExecutionEvidenceSetDigest,
  }) {
    if (cells == null) return;
    for (final (index, value) in cells.indexed) {
      final path = 'coverageCells[$index]';
      final cell = _expectMap(issues, value, path);
      if (cell == null) continue;
      _expectDigest(issues, cell['coverageCellRef'], '$path.coverageCellRef');
      _expectDigest(
        issues,
        cell['workOrderBatchRef'],
        '$path.workOrderBatchRef',
      );
      final modelClass = _expectNonEmptyString(
        issues,
        cell['modelClass'],
        '$path.modelClass',
      );
      if (modelClass != null && !_isEnumModelClass(modelClass)) {
        issues.add('$path.modelClass must be an EvalModelClass name');
      }
      final selectors = _expectMap(
        issues,
        cell['publicSelectors'],
        '$path.publicSelectors',
      );
      _validateSelectorMap(issues, selectors, '$path.publicSelectors');
      final objective = _expectNonEmptyString(
        issues,
        cell['objective'],
        '$path.objective',
      );
      if (objective != null && !_allowedObjectives.contains(objective)) {
        issues.add('$path.objective must be supported');
      }
      for (final field in const [
        'expectedTraceCount',
        'observedTraceCount',
        'verifiedResolvedModelTraceCount',
      ]) {
        _expectNonNegativeInt(issues, cell[field], '$path.$field');
      }
      final status = _expectNonEmptyString(
        issues,
        cell['status'],
        '$path.status',
      );
      if (status != null && !_allowedCoverageStatuses.contains(status)) {
        issues.add('$path.status must be supported');
      }
      _expectStringList(issues, cell['issueCodes'], '$path.issueCodes');
      final expectedRef = EvalProvenance.digestJson(<String, dynamic>{
        'workOrderDigest': workOrderDigest,
        'sourceExecutionEvidenceSetDigest': sourceExecutionEvidenceSetDigest,
        'workOrderBatchRef': _string(cell['workOrderBatchRef']),
        'modelClass': _string(cell['modelClass']),
        'publicSelectors': selectors ?? const <String, dynamic>{},
        'objective': _string(cell['objective']),
        'expectedTraceCount': cell['expectedTraceCount'],
        'observedTraceCount': cell['observedTraceCount'],
        'verifiedResolvedModelTraceCount':
            cell['verifiedResolvedModelTraceCount'],
        'status': _string(cell['status']),
        'issueCodes': _stringList(cell['issueCodes']),
      });
      if (cell['coverageCellRef'] != expectedRef) {
        issues.add('$path.coverageCellRef must bind coverage cell fields');
      }
    }
  }

  static void _validateSelectorMap(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    for (final field in selectors.keys) {
      if (field != 'capabilities' && field != 'promptVariantNames') {
        issues.add('$path must not contain unsupported selector $field');
      }
    }
    for (final field in const ['capabilities', 'promptVariantNames']) {
      final values = _expectStringList(
        issues,
        selectors[field],
        '$path.$field',
      );
      if (values == null) continue;
      for (final value in values) {
        if (!_safeSelectorValue(value)) {
          issues.add('$path.$field contains unsafe selector values');
        }
      }
    }
  }

  static void _validatePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'rawRunIdsOmitted': true,
      'providerIdsOmitted': true,
      'providerModelIdsOmitted': true,
      'localConfigIdsOmitted': true,
      'providerEndpointsOmitted': true,
      'promptTextOmitted': true,
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
      'consumesWorkOrderAndExecutionEvidenceOnly': true,
      'privateEvidenceAggregatedOnly': true,
      'tracesReRead': false,
      'liveModelCallsStarted': false,
      'runtimeConfigurationApplied': false,
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

  static void _validateIssues(List<String> issues, List<dynamic>? values) {
    if (values == null) return;
    for (final (index, value) in values.indexed) {
      final issue = _expectMap(issues, value, 'issues[$index]');
      if (issue == null) continue;
      _expectNonEmptyString(issues, issue['code'], 'issues[$index].code');
      _expectNonEmptyString(
        issues,
        issue['severity'],
        'issues[$index].severity',
      );
      if (issue.containsKey('modelClass') &&
          !_isEnumModelClass(_string(issue['modelClass']))) {
        issues.add('issues[$index].modelClass must be an EvalModelClass name');
      }
    }
  }

  static void _validateSourceEvidenceWorkOrderBinding(
    List<String> issues, {
    required Map<String, dynamic>? sourceExecutionEvidence,
    required Map<String, dynamic>? sourceWorkOrder,
    required List<dynamic>? artifactIssues,
  }) {
    if (sourceExecutionEvidence == null ||
        sourceWorkOrder == null ||
        artifactIssues == null) {
      return;
    }
    final expectedWorkOrderDigest = _string(sourceWorkOrder['workOrderDigest']);
    if (expectedWorkOrderDigest.isEmpty) return;
    final uniqueWorkOrderDigests = _sortedStrings(
      _stringList(sourceExecutionEvidence['sourceWorkOrderDigests']),
    );
    final reportedInvalidSource = artifactIssues.any(
      (issue) =>
          issue is Map<String, dynamic> &&
          const {
            'coverage.executionEvidenceBundleMissing',
            'coverage.executionEvidenceBundleContractInvalid',
            'coverage.executionEvidenceSourceCheckProofInvalid',
            'coverage.executionEvidenceWorkOrderMismatch',
          }.contains(_string(issue['code'])),
    );
    if (reportedInvalidSource) return;
    final proof = _map(sourceExecutionEvidence['sourceCheckProof']);
    if (proof.isNotEmpty) {
      if (_string(proof['workOrderDigest']) != expectedWorkOrderDigest) {
        issues.add(
          'sourceExecutionEvidence.sourceCheckProof.workOrderDigest must match sourceWorkOrder.workOrderDigest',
        );
      }
      if (_string(proof['bundleSetDigest']) !=
          _string(sourceExecutionEvidence['bundleSetDigest'])) {
        issues.add(
          'sourceExecutionEvidence.sourceCheckProof.bundleSetDigest must match sourceExecutionEvidence.bundleSetDigest',
        );
      }
      if (EvalProvenance.digestJson(
            _sortedStrings(_stringList(proof['executionEvidenceRefs'])),
          ) !=
          EvalProvenance.digestJson(
            _sortedStrings(
              _stringList(sourceExecutionEvidence['executionEvidenceRefs']),
            ),
          )) {
        issues.add(
          'sourceExecutionEvidence.sourceCheckProof.executionEvidenceRefs must match sourceExecutionEvidence.executionEvidenceRefs',
        );
      }
      if (_int(proof['sourceRunCount']) !=
          _int(sourceExecutionEvidence['sourceRunCount'])) {
        issues.add(
          'sourceExecutionEvidence.sourceCheckProof.sourceRunCount must match sourceExecutionEvidence.sourceRunCount',
        );
      }
      if (_string(proof['sourceRunRefsDigest']) !=
          _string(sourceExecutionEvidence['sourceRunRefsDigest'])) {
        issues.add(
          'sourceExecutionEvidence.sourceCheckProof.sourceRunRefsDigest must match sourceExecutionEvidence.sourceRunRefsDigest',
        );
      }
      if (EvalProvenance.digestJson(
            _sortedStrings(_stringList(proof['bundleDigests'])),
          ) !=
          _string(sourceExecutionEvidence['bundleSetDigest'])) {
        issues.add(
          'sourceExecutionEvidence.sourceCheckProof.bundleDigests must match sourceExecutionEvidence.bundleSetDigest',
        );
      }
    }
    if (uniqueWorkOrderDigests.length == 1 &&
        uniqueWorkOrderDigests.single == expectedWorkOrderDigest) {
      return;
    }
    issues.add(
      'sourceExecutionEvidence.sourceWorkOrderDigests must match sourceWorkOrder.workOrderDigest',
    );
  }

  static void _validateCommands(List<String> issues, List<dynamic>? commands) {
    if (commands == null) return;
    if (EvalProvenance.digestJson(_mapList(commands)) !=
        EvalProvenance.digestJson(_recommendedCommands())) {
      issues.add(
        'recommendedCommands must match model-class coverage commands',
      );
    }
    for (final (index, value) in commands.indexed) {
      final command = _expectMap(issues, value, 'recommendedCommands[$index]');
      if (command == null) continue;
      final mode = _expectNonEmptyString(
        issues,
        command['mode'],
        'recommendedCommands[$index].mode',
      );
      if (mode != null && !_allowedCommandModes.contains(mode)) {
        issues.add('recommendedCommands[$index].mode must be artifact-only');
      }
      final text = _expectNonEmptyString(
        issues,
        command['command'],
        'recommendedCommands[$index].command',
      );
      if (text != null &&
          RegExp(r'(?:^|\s)(?:plan|run|tune|all)(?:\s|$)').hasMatch(text)) {
        issues.add('recommendedCommands[$index].command must not be live');
      }
      if (command.containsKey('env')) {
        issues.add('recommendedCommands[$index] must not contain env values');
      }
      _expectEquals(
        issues,
        command['valuesOmitted'],
        true,
        'recommendedCommands[$index].valuesOmitted',
      );
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required Map<String, dynamic>? policy,
    required List<dynamic>? modelClassCoverage,
    required List<dynamic>? coverageCells,
    required List<dynamic>? artifactIssues,
  }) {
    if (summary == null) return;
    final requiredClasses = _stringList(policy?['requiredModelClasses']);
    if (summary['requiredModelClassCount'] is int &&
        summary['requiredModelClassCount'] != requiredClasses.length) {
      issues.add(
        'summary.requiredModelClassCount must match requiredModelClasses.length',
      );
    }
    if (modelClassCoverage != null) {
      final covered = modelClassCoverage.where(
        (value) =>
            value is Map<String, dynamic> && value['status'] == 'covered',
      );
      final missing = modelClassCoverage.where(
        (value) =>
            value is Map<String, dynamic> && value['status'] == 'missing',
      );
      if (summary['coveredModelClassCount'] is int &&
          summary['coveredModelClassCount'] != covered.length) {
        issues.add(
          'summary.coveredModelClassCount must match covered model classes',
        );
      }
      if (summary['missingModelClassCount'] is int &&
          summary['missingModelClassCount'] != missing.length) {
        issues.add(
          'summary.missingModelClassCount must match missing model classes',
        );
      }
    }
    if (coverageCells != null) {
      for (final field in const [
        'expectedTraceCount',
        'observedTraceCount',
        'verifiedResolvedModelTraceCount',
      ]) {
        final total = coverageCells.whereType<Map<String, dynamic>>().fold<int>(
          0,
          (sum, cell) => sum + _int(cell[field]),
        );
        if (summary[field] is int && summary[field] != total) {
          issues.add('summary.$field must match coverage cell total');
        }
      }
    }
    if (artifactIssues != null &&
        summary['issueCount'] is int &&
        summary['issueCount'] != artifactIssues.length) {
      issues.add('summary.issueCount must match issues.length');
    }
  }

  static void _validateStatusInvariants(
    List<String> issues, {
    required String? status,
    required Map<String, dynamic>? sourceExecutionEvidence,
    required List<dynamic>? coverageCells,
    required List<dynamic>? artifactIssues,
  }) {
    if (status == null ||
        sourceExecutionEvidence == null ||
        coverageCells == null ||
        artifactIssues == null) {
      return;
    }
    final sourcePresent = sourceExecutionEvidence['present'] == true;
    final hasMissingBundleIssue = artifactIssues.any(
      (issue) =>
          issue is Map<String, dynamic> &&
          issue['code'] == 'coverage.executionEvidenceBundleMissing',
    );
    final hasUncheckedSourceIssue = artifactIssues.any(
      (issue) =>
          issue is Map<String, dynamic> &&
          issue['code'] == 'coverage.executionEvidenceSourceNotChecked',
    );
    final hasInvalidProofIssue = artifactIssues.any(
      (issue) =>
          issue is Map<String, dynamic> &&
          issue['code'] == 'coverage.executionEvidenceSourceCheckProofInvalid',
    );
    if (!sourcePresent && status != 'invalidSource') {
      issues.add(
        'sourceExecutionEvidence.present=false requires invalidSource status',
      );
    }
    if (!sourcePresent && !hasMissingBundleIssue) {
      issues.add(
        'sourceExecutionEvidence.present=false requires missing bundle issue',
      );
    }
    if (sourcePresent &&
        sourceExecutionEvidence['concreteSourceChecked'] != true &&
        !hasUncheckedSourceIssue &&
        !hasInvalidProofIssue) {
      issues.add(
        'sourceExecutionEvidence.concreteSourceChecked=false requires unchecked source or invalid proof issue',
      );
    }
    if (sourcePresent &&
        sourceExecutionEvidence['concreteSourceChecked'] != true &&
        status != 'invalidSource') {
      issues.add(
        'sourceExecutionEvidence.concreteSourceChecked=false requires invalidSource status',
      );
    }
    if (status == 'covered' && artifactIssues.isNotEmpty) {
      issues.add('covered status must not have issues');
    }
    if (status == 'noCoverage' &&
        coverageCells.any(
          (cell) => cell is Map<String, dynamic> && cell['status'] != 'missing',
        )) {
      issues.add('noCoverage status requires all cells to be missing');
    }
    if (status == 'partialCoverage' && artifactIssues.isEmpty) {
      issues.add('partialCoverage status must include issues');
    }
    if (status == 'invalidSource' &&
        !artifactIssues.any(
          (issue) =>
              issue is Map<String, dynamic> &&
              _string(issue['severity']) == 'blocking',
        )) {
      issues.add('invalidSource status must include blocking issues');
    }
  }

  static void _validateCoverageArtifactRef(
    List<String> issues,
    Map<String, dynamic> coverage,
  ) {
    final expectedRef = coverageArtifactRef(coverage);
    if (coverage['coverageArtifactRef'] != expectedRef) {
      issues.add(
        'coverageArtifactRef must match model-class coverage subject',
      );
    }
  }

  static Map<String, dynamic> _coverageArtifactSubject(
    Map<String, dynamic> coverage,
  ) => <String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': _string(coverage['status']),
    'sourceWorkOrderDigest': EvalProvenance.digestJson(
      _map(coverage['sourceWorkOrder']),
    ),
    'sourceExecutionEvidenceDigest': EvalProvenance.digestJson(
      _map(coverage['sourceExecutionEvidence']),
    ),
    'coveragePolicyDigest': EvalProvenance.digestJson(
      _map(coverage['coveragePolicy']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(coverage['summary'])),
    'modelClassCoverageDigest': EvalProvenance.digestJson(
      _mapList(coverage['modelClassCoverage']),
    ),
    'coverageCellsDigest': EvalProvenance.digestJson(
      _mapList(coverage['coverageCells']),
    ),
    'privacyDigest': EvalProvenance.digestJson(_map(coverage['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(coverage['limitations']),
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(coverage['issues'])),
    'recommendedCommandsDigest': EvalProvenance.digestJson(
      _mapList(coverage['recommendedCommands']),
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
        final reason = _privateFieldReason(normalized);
        if (reason != null) {
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
    if (normalized == 'providerid' ||
        normalized == 'providermodelid' ||
        normalized == 'modelid' ||
        normalized == 'modelconfigid' ||
        normalized == 'profileid' ||
        normalized == 'selectedproviderid' ||
        normalized == 'selectedprovidermodelid') {
      return 'provider or model ids';
    }
    if (normalized == 'providerendpointorigin' ||
        normalized == 'baseurl' ||
        normalized == 'apiurl' ||
        normalized == 'apikey') {
      return 'provider endpoints or secrets';
    }
    if (normalized == 'prompttext' ||
        normalized == 'systemprompt' ||
        normalized == 'developerprompt' ||
        normalized == 'rawprompt') {
      return 'prompt text';
    }
    if (normalized == 'path' || normalized.endsWith('path')) {
      return 'private paths';
    }
    return null;
  }

  static bool _safeSelectorValue(String value) {
    return value.trim().isNotEmpty &&
        _safeSelectorPattern.hasMatch(value) &&
        !_opaqueFallbackPattern.hasMatch(value);
  }

  static bool _isEnumModelClass(String value) {
    return EvalModelClass.values.any((modelClass) => modelClass.name == value);
  }

  static List<EvalModelClass> _modelClassesFromPolicy(
    Map<String, dynamic> policy,
  ) {
    final classes = _stringList(policy['requiredModelClasses']);
    if (classes.isEmpty) return EvalModelClass.values;
    final resolved = <EvalModelClass>[];
    for (final name in classes) {
      for (final modelClass in EvalModelClass.values) {
        if (modelClass.name == name) {
          resolved.add(modelClass);
          break;
        }
      }
    }
    return resolved.isEmpty ? EvalModelClass.values : resolved;
  }

  static int _sum(List<Map<String, dynamic>> values, String field) {
    return values.fold<int>(0, (sum, value) => sum + _int(value[field]));
  }

  static int _statusCount(List<Map<String, dynamic>> values, String status) {
    return values.where((value) => value['status'] == status).length;
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

  static void _expectNonNegativeInt(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is int && value >= 0) return;
    issues.add('$path must be a non-negative integer');
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

final class _SourceExecutionEvidenceBundle {
  _SourceExecutionEvidenceBundle._({
    required this.index,
    required this.bundleDigest,
    required this.executionEvidenceRef,
    required this.status,
    required this.sourceWorkOrderDigest,
    required this.sourceRunRefs,
    required this.contractIssues,
    required this.evidenceRows,
  });

  factory _SourceExecutionEvidenceBundle.fromJson({
    required int index,
    required Map<String, dynamic> json,
  }) {
    return _SourceExecutionEvidenceBundle._(
      index: index,
      bundleDigest: EvalProvenance.digestJson(json),
      executionEvidenceRef: _string(json['executionEvidenceRef']),
      status: _string(json['status']),
      sourceWorkOrderDigest: _string(
        _map(json['sourceWorkOrder'])['workOrderDigest'],
      ),
      sourceRunRefs: _sortedStrings(
        _mapList(json['sourceRuns']).map(
          (sourceRun) => _string(sourceRun['sourceRunRef']),
        ),
      ),
      contractIssues: EvalUseCaseModelClassExecutionEvidence.validate(json),
      evidenceRows: _mapList(json['evidenceRows']),
    );
  }

  final int index;
  final String bundleDigest;
  final String executionEvidenceRef;
  final String status;
  final String sourceWorkOrderDigest;
  final List<String> sourceRunRefs;
  final List<String> contractIssues;
  final List<Map<String, dynamic>> evidenceRows;

  List<Map<String, dynamic>> issues({
    required String expectedWorkOrderDigest,
  }) {
    return [
      if (contractIssues.isNotEmpty)
        <String, dynamic>{
          'code': 'coverage.executionEvidenceBundleContractInvalid',
          'severity': 'blocking',
          'bundleRef': 'execution-evidence-bundle-${index + 1}',
          'contractIssueCount': contractIssues.length,
        },
      if (contractIssues.isEmpty && status != 'ready')
        <String, dynamic>{
          'code': 'coverage.executionEvidenceBundleNotReady',
          'severity': 'blocking',
          'bundleRef': 'execution-evidence-bundle-${index + 1}',
        },
      if (contractIssues.isEmpty &&
          sourceWorkOrderDigest != expectedWorkOrderDigest)
        <String, dynamic>{
          'code': 'coverage.executionEvidenceWorkOrderMismatch',
          'severity': 'blocking',
          'bundleRef': 'execution-evidence-bundle-${index + 1}',
        },
    ];
  }
}

final class _ExecutionEvidence {
  _ExecutionEvidence._({
    required this.workOrderBatchRef,
    required this.modelClass,
    required this.profileSlotRef,
    required this.expectedTraceCount,
    required this.observedTraceCount,
    required this.verifiedResolvedModelTraceCount,
    required this.resolvedModelEvidence,
    required this.providerRequestEvidence,
    required this.issues,
  });

  factory _ExecutionEvidence.fromJson(int index, Map<String, dynamic> json) {
    final issues = <Map<String, dynamic>>[];
    final modelClass = _string(json['modelClass']);
    if (!EvalUseCaseModelClassExecutionCoverage._isEnumModelClass(modelClass)) {
      issues.add(
        <String, dynamic>{
          'code': 'coverage.executionEvidenceModelClassInvalid',
          'severity': 'blocking',
          'evidenceRef': 'execution-evidence-${index + 1}',
        },
      );
    }
    final privateIssues = <String>[];
    EvalUseCaseModelClassExecutionCoverage._validateNoPrivatePayloads(
      privateIssues,
      json,
      'executionEvidence[$index]',
    );
    if (privateIssues.isNotEmpty) {
      issues.add(
        <String, dynamic>{
          'code': 'coverage.executionEvidencePrivatePayload',
          'severity': 'blocking',
          'evidenceRef': 'execution-evidence-${index + 1}',
          'privateIssueCount': privateIssues.length,
        },
      );
    }
    final workOrderBatchRef = _string(json['workOrderBatchRef']);
    if (!EvalProvenance.isDigest(workOrderBatchRef)) {
      issues.add(
        <String, dynamic>{
          'code': 'coverage.executionEvidenceBatchRefInvalid',
          'severity': 'blocking',
          'evidenceRef': 'execution-evidence-${index + 1}',
        },
      );
    }
    final profileSlotRef = _string(json['profileSlotRef']);
    if (!EvalProvenance.isDigest(profileSlotRef)) {
      issues.add(
        <String, dynamic>{
          'code': 'coverage.executionEvidenceProfileSlotRefInvalid',
          'severity': 'blocking',
          'evidenceRef': 'execution-evidence-${index + 1}',
        },
      );
    }
    return _ExecutionEvidence._(
      workOrderBatchRef: workOrderBatchRef,
      modelClass: modelClass,
      profileSlotRef: profileSlotRef,
      expectedTraceCount: _int(json['expectedTraceCount']),
      observedTraceCount: _int(json['observedTraceCount']),
      verifiedResolvedModelTraceCount: _int(
        json['verifiedResolvedModelTraceCount'],
      ),
      resolvedModelEvidence: json['resolvedModelEvidence'] == true,
      providerRequestEvidence: json['providerRequestEvidence'] == true,
      issues: issues,
    );
  }

  final String workOrderBatchRef;
  final String modelClass;
  final String profileSlotRef;
  final int expectedTraceCount;
  final int observedTraceCount;
  final int verifiedResolvedModelTraceCount;
  final bool resolvedModelEvidence;
  final bool providerRequestEvidence;
  final List<Map<String, dynamic>> issues;
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

int _int(Object? value) => value is int ? value : 0;

List<String> _sortedStrings(Iterable<String> values) {
  final sorted =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return sorted;
}
