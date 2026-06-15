import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_run_verifier.dart';
import 'eval_use_case_next_run_work_order.dart';
import 'trace_writer.dart';

final class EvalUseCaseModelClassExecutionRun {
  const EvalUseCaseModelClassExecutionRun({
    required this.artifacts,
    required this.scenarios,
    required this.profiles,
    this.agentDirectiveVariants = const [EvalAgentDirectiveVariant()],
    this.requireVerdicts = false,
  });

  final EvalRunArtifacts artifacts;
  final List<EvalScenario> scenarios;
  final List<EvalProfile> profiles;
  final List<EvalAgentDirectiveVariant> agentDirectiveVariants;
  final bool requireVerdicts;
}

abstract final class EvalUseCaseModelClassExecutionEvidence {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseModelClassExecutionEvidence';
  static const _allowedStatuses = {
    'ready',
    'partial',
    'empty',
    'invalidSource',
  };
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
    required List<EvalUseCaseModelClassExecutionRun> runs,
    Map<String, dynamic>? sourceExperimentPlan,
    DateTime? generatedAt,
  }) {
    final workOrderIssues = sourceExperimentPlan == null
        ? EvalUseCaseNextRunWorkOrder.validate(workOrder)
        : EvalUseCaseNextRunWorkOrder.validateAgainstExperimentPlan(
            workOrder,
            experimentPlan: sourceExperimentPlan,
          );
    final workOrderDigest = EvalProvenance.digestJson(workOrder);
    final workOrderRef = _string(workOrder['workOrderRef']);
    final workOrderSource = _map(workOrder['sourceExperimentPlan']);
    final runBatches = workOrderIssues.isEmpty
        ? _mapList(workOrder['runBatches'])
        : const <Map<String, dynamic>>[];
    final issues = <Map<String, dynamic>>[
      if (workOrderIssues.isNotEmpty)
        <String, dynamic>{
          'code': 'execution.workOrderContractInvalid',
          'severity': 'blocking',
          'contractIssueCount': workOrderIssues.length,
        },
      if (runs.isEmpty)
        const <String, dynamic>{
          'code': 'execution.sourceRunsMissing',
          'severity': 'blocking',
        },
    ];
    final evidenceRows = <Map<String, dynamic>>[];
    final sourceRuns = <Map<String, dynamic>>[];
    final seenSourceRunRefs = <String>{};
    final launchedWorkOrderBatchRefs = <String>{};
    var validSourceRunCount = 0;

    for (final run in runs) {
      final sourceRun = _sourceRun(
        run,
        expectedWorkOrderDigest: workOrderDigest,
        expectedWorkOrderRef: workOrderRef,
        expectedSourceExperimentPlanDigest: _string(
          workOrderSource['planDigest'],
        ),
        expectedSourceMatrixDigest: _string(
          workOrderSource['sourceMatrixDigest'],
        ),
      );
      sourceRuns.add(sourceRun.toJson());
      if (!seenSourceRunRefs.add(sourceRun.sourceRunRef)) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.duplicateSourceRun',
            'severity': 'blocking',
            'sourceRunRef': sourceRun.sourceRunRef,
          },
        );
        continue;
      }
      issues.addAll(sourceRun.issues);
      final hasBlockingSourceRunIssues = _hasBlockingSourceRunIssues(
        sourceRun.issues,
      );
      if (workOrderIssues.isNotEmpty || hasBlockingSourceRunIssues) {
        continue;
      }
      validSourceRunCount++;
      launchedWorkOrderBatchRefs.addAll(sourceRun.workOrderBatchRefs);
      evidenceRows.addAll(
        _evidenceRowsForRun(
          run: run,
          sourceRunRef: sourceRun.sourceRunRef,
          workOrderDigest: workOrderDigest,
          runBatches: runBatches,
          issues: issues,
        ),
      );
    }
    if (workOrderIssues.isEmpty && validSourceRunCount > 0) {
      for (final batch in runBatches) {
        final batchRef = _string(batch['workOrderBatchRef']);
        if (launchedWorkOrderBatchRefs.contains(batchRef)) continue;
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderBatchLaunchEvidenceMissing',
            'severity': 'blocking',
            'workOrderBatchRef': batchRef,
          },
        );
      }
    }

    final duplicateRowKeys = _duplicates(
      evidenceRows.map(
        (row) => [
          row['workOrderBatchRef'],
          row['modelClass'],
          row['profileSlotRef'],
        ].join(':'),
      ),
    );
    if (duplicateRowKeys.isNotEmpty) {
      issues.add(
        <String, dynamic>{
          'code': 'execution.duplicateEvidenceRows',
          'severity': 'blocking',
          'duplicateRowCount': duplicateRowKeys.length,
        },
      );
    }

    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'executionEvidenceRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': _status(issues: issues, evidenceRows: evidenceRows),
      'sourceWorkOrder': <String, dynamic>{
        'kind': EvalUseCaseNextRunWorkOrder.kind,
        'schemaVersion': EvalUseCaseNextRunWorkOrder.schemaVersion,
        'status': _string(workOrder['status']).isEmpty
            ? 'unknown'
            : _string(workOrder['status']),
        'workOrderRef': workOrderRef,
        'workOrderDigest': workOrderDigest,
        'sourceExperimentPlanDigest': _string(workOrderSource['planDigest']),
        'sourceMatrixDigest': _string(workOrderSource['sourceMatrixDigest']),
        'runBatchCount': runBatches.length,
        'runBatchRefsDigest': EvalProvenance.digestJson(
          [
            for (final batch in runBatches) _string(batch['workOrderBatchRef']),
          ]..sort(),
        ),
        'contractIssueCount': workOrderIssues.length,
      },
      'summary': <String, dynamic>{
        'sourceRunCount': sourceRuns.length,
        'evidenceRowCount': evidenceRows.length,
        'expectedTraceCount': _sum(evidenceRows, 'expectedTraceCount'),
        'observedTraceCount': _sum(evidenceRows, 'observedTraceCount'),
        'verifiedResolvedModelTraceCount': _sum(
          evidenceRows,
          'verifiedResolvedModelTraceCount',
        ),
        'issueCount': issues.length,
      },
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
        'readsPrivateRunArtifacts': true,
        'readsPrivateExpectedCatalogs': true,
        'writesSanitizedEvidenceRowsOnly': true,
        'publicCoverageComputedElsewhere': true,
        'liveModelCallsStarted': false,
      },
      'sourceRuns': sourceRuns,
      'evidenceRows': evidenceRows,
      'issues': issues,
    };
    artifact['executionEvidenceRef'] = executionEvidenceRef(artifact);
    assertValid(artifact);
    return artifact;
  }

  static String executionEvidenceRef(Map<String, dynamic> artifact) =>
      EvalProvenance.digestJson(_executionEvidenceSubject(artifact));

  static List<String> validate(Map<String, dynamic> artifact) {
    final issues = <String>[];
    _expectEquals(
      issues,
      artifact['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, artifact['kind'], kind, 'kind');
    _expectDigest(
      issues,
      artifact['executionEvidenceRef'],
      'executionEvidenceRef',
    );
    _expectIsoDate(issues, artifact['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, artifact['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final source = _expectMap(
      issues,
      artifact['sourceWorkOrder'],
      'sourceWorkOrder',
    );
    _validateSourceWorkOrder(issues, source);
    final summary = _expectMap(issues, artifact['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(
      issues,
      _expectMap(issues, artifact['privacy'], 'privacy'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, artifact['limitations'], 'limitations'),
    );
    final sourceRuns = _expectList(
      issues,
      artifact['sourceRuns'],
      'sourceRuns',
    );
    _validateSourceRuns(issues, sourceRuns);
    final rows = _expectList(issues, artifact['evidenceRows'], 'evidenceRows');
    _validateEvidenceRows(issues, rows, sourceRuns: sourceRuns);
    final artifactIssues = _expectList(
      issues,
      artifact['issues'],
      'issues',
    );
    _validateIssues(issues, artifactIssues);
    _validateSummaryInvariants(
      issues,
      summary: summary,
      sourceRuns: sourceRuns,
      evidenceRows: rows,
      artifactIssues: artifactIssues,
    );
    _validateStatusInvariants(
      issues,
      status: status,
      sourceRuns: sourceRuns,
      evidenceRows: rows,
      artifactIssues: artifactIssues,
    );
    _validateExecutionEvidenceRef(issues, artifact);
    _validateNoPrivatePayloads(issues, artifact, 'evidence');
    return issues;
  }

  static void assertValid(Map<String, dynamic> artifact) {
    final issues = validate(artifact);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case model-class execution evidence:\n'
      '${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstSources(
    Map<String, dynamic> artifact, {
    required Map<String, dynamic> workOrder,
    required List<EvalUseCaseModelClassExecutionRun> runs,
    Map<String, dynamic>? sourceExperimentPlan,
  }) {
    final issues = validate(artifact);
    final workOrderIssues = sourceExperimentPlan == null
        ? EvalUseCaseNextRunWorkOrder.validate(workOrder)
        : EvalUseCaseNextRunWorkOrder.validateAgainstExperimentPlan(
            workOrder,
            experimentPlan: sourceExperimentPlan,
          );
    if (workOrderIssues.isNotEmpty) {
      issues.add('source work order contract is invalid');
    }
    final generatedAt = DateTime.tryParse(_string(artifact['generatedAt']));
    final expected = build(
      workOrder: workOrder,
      runs: runs,
      sourceExperimentPlan: sourceExperimentPlan,
      generatedAt: generatedAt,
    );

    void expectMatches(String field) {
      if (EvalProvenance.digestJson(artifact[field]) !=
          EvalProvenance.digestJson(expected[field])) {
        issues.add('$field must match source work order and runs');
      }
    }

    const [
      'status',
      'sourceWorkOrder',
      'summary',
      'privacy',
      'limitations',
      'sourceRuns',
      'evidenceRows',
      'issues',
    ].forEach(expectMatches);
    if (_string(artifact['executionEvidenceRef']) !=
        _string(expected['executionEvidenceRef'])) {
      issues.add(
        'executionEvidenceRef must match source work order and runs',
      );
    }
    return issues;
  }

  static void assertMatchesSources(
    Map<String, dynamic> artifact, {
    required Map<String, dynamic> workOrder,
    required List<EvalUseCaseModelClassExecutionRun> runs,
    Map<String, dynamic>? sourceExperimentPlan,
  }) {
    final issues = validateAgainstSources(
      artifact,
      workOrder: workOrder,
      runs: runs,
      sourceExperimentPlan: sourceExperimentPlan,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case model-class execution evidence source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static _SourceRun _sourceRun(
    EvalUseCaseModelClassExecutionRun run, {
    required String expectedWorkOrderDigest,
    required String expectedWorkOrderRef,
    required String expectedSourceExperimentPlanDigest,
    required String expectedSourceMatrixDigest,
  }) {
    final manifest = run.artifacts.manifest;
    final launchEvidence = manifest.useCaseWorkOrderLaunchEvidence;
    final actualDigest = EvalProvenance.manifestDigest(manifest);
    final manifestDigest = manifest.manifestDigest;
    final sourceRunFields = <String, dynamic>{
      'actualManifestDigest': actualDigest,
      'manifestDigest': manifestDigest ?? actualDigest,
      'workOrderLaunchSubjectDigest':
          launchEvidence?.workOrderLaunchSubjectDigest ?? '',
      'workOrderDigest': launchEvidence?.workOrderDigest ?? '',
      'workOrderRef': launchEvidence?.workOrderRef ?? '',
      'workOrderBatchSetDigest': launchEvidence?.workOrderBatchSetDigest ?? '',
      'profileBindingSetDigest': manifest.profileBindingSetDigest,
      'scenarioSetDigest': manifest.scenarioSetDigest,
      'profileSetDigest': manifest.profileSetDigest,
      'agentDirectiveVariantSetDigest': manifest.agentDirectiveVariantSetDigest,
      'readinessContractSubjectDigest':
          manifest
              .tuningReadinessContractEvidence
              ?.readinessContractSubjectDigest ??
          '',
    };
    final sourceRunRef = _sourceRunRef(sourceRunFields);
    final issues = <Map<String, dynamic>>[];
    if (manifestDigest == null) {
      issues.add(
        <String, dynamic>{
          'code': 'execution.manifestDigestMissing',
          'severity': 'blocking',
          'sourceRunRef': sourceRunRef,
        },
      );
    } else {
      if (actualDigest != manifestDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.manifestDigestStale',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
    }
    if (manifest.traceSchemaVersion != EvalTrace.schemaVersion) {
      issues.add(
        <String, dynamic>{
          'code': 'execution.traceSchemaVersionMismatch',
          'severity': 'blocking',
          'sourceRunRef': sourceRunRef,
        },
      );
    }
    if (manifest.profileExecutionBindings.isEmpty) {
      issues.add(
        <String, dynamic>{
          'code': 'execution.profileBindingsMissing',
          'severity': 'blocking',
          'sourceRunRef': sourceRunRef,
        },
      );
    }
    if (launchEvidence == null) {
      issues.add(
        <String, dynamic>{
          'code': 'execution.workOrderLaunchEvidenceMissing',
          'severity': 'blocking',
          'sourceRunRef': sourceRunRef,
        },
      );
    } else {
      final actualLaunchSubjectDigest =
          EvalProvenance.useCaseWorkOrderLaunchSubjectDigest(launchEvidence);
      if (launchEvidence.workOrderLaunchSubjectDigest !=
          actualLaunchSubjectDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderLaunchSubjectDigestStale',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
      if (launchEvidence.workOrderDigest != expectedWorkOrderDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderLaunchDigestMismatch',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
      if (launchEvidence.workOrderRef != expectedWorkOrderRef) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderLaunchRefMismatch',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
      if (launchEvidence.sourceExperimentPlanDigest !=
          expectedSourceExperimentPlanDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderLaunchSourcePlanDigestMismatch',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
      if (launchEvidence.sourceMatrixDigest != expectedSourceMatrixDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderLaunchSourceMatrixDigestMismatch',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
      final actualBatchSetDigest = EvalProvenance.digestJson(
        launchEvidence.workOrderBatchRefs,
      );
      if (launchEvidence.workOrderBatchSetDigest != actualBatchSetDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderLaunchBatchSetDigestStale',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
          },
        );
      }
    }
    final verification = EvalRunVerifier.verify(
      runId: manifest.runId,
      traces: run.artifacts.traces,
      scenarios: run.scenarios,
      profiles: run.profiles,
      agentDirectiveVariants: run.agentDirectiveVariants,
      manifest: manifest,
      artifactNames: run.artifacts.artifactNames,
      requireVerdicts: run.requireVerdicts,
    );
    if (!verification.passed) {
      issues.add(
        <String, dynamic>{
          'code': 'execution.verifierFailed',
          'severity': 'blocking',
          'sourceRunRef': sourceRunRef,
          'errorCount': verification.errors.length,
        },
      );
    }
    return _SourceRun(
      sourceRunRef: sourceRunRef,
      actualManifestDigest: actualDigest,
      manifestDigest: manifestDigest ?? actualDigest,
      workOrderLaunchSubjectDigest:
          launchEvidence?.workOrderLaunchSubjectDigest ?? '',
      workOrderDigest: launchEvidence?.workOrderDigest ?? '',
      workOrderRef: launchEvidence?.workOrderRef ?? '',
      workOrderBatchSetDigest: launchEvidence?.workOrderBatchSetDigest ?? '',
      workOrderBatchRefs: launchEvidence?.workOrderBatchRefs ?? const [],
      profileBindingSetDigest: manifest.profileBindingSetDigest,
      scenarioSetDigest: manifest.scenarioSetDigest,
      profileSetDigest: manifest.profileSetDigest,
      agentDirectiveVariantSetDigest: manifest.agentDirectiveVariantSetDigest,
      readinessContractSubjectDigest:
          manifest
              .tuningReadinessContractEvidence
              ?.readinessContractSubjectDigest ??
          '',
      traceCount: run.artifacts.traces.length,
      artifactCount: run.artifacts.artifactNames.length,
      profileBindingCount: manifest.profileExecutionBindings.length,
      verifierIssueCount: verification.errors.length,
      issues: issues,
    );
  }

  static List<Map<String, dynamic>> _evidenceRowsForRun({
    required EvalUseCaseModelClassExecutionRun run,
    required String sourceRunRef,
    required String workOrderDigest,
    required List<Map<String, dynamic>> runBatches,
    required List<Map<String, dynamic>> issues,
  }) {
    final rows = <Map<String, dynamic>>[];
    final manifest = run.artifacts.manifest;
    final launchedBatchRefs =
        manifest.useCaseWorkOrderLaunchEvidence?.workOrderBatchRefs.toSet() ??
        const <String>{};
    final profilesByName = {
      for (final profile in run.profiles) profile.name: profile,
    };
    final expectedVariantsByName = {
      for (final variant in run.agentDirectiveVariants) variant.name: variant,
    };
    for (final batch in runBatches) {
      final batchRef = _string(batch['workOrderBatchRef']);
      if (!launchedBatchRefs.contains(batchRef)) {
        continue;
      }
      final selectors = _map(batch['publicSelectors']);
      final capabilityIds = _stringList(selectors['capabilities']).toSet();
      final variantNames = _stringList(selectors['promptVariantNames']).toSet();
      _addPublicSelectorIssues(
        issues: issues,
        manifest: manifest,
        run: run,
        sourceRunRef: sourceRunRef,
        workOrderBatchRef: batchRef,
        requiredCapabilityIds: capabilityIds,
        requiredPromptVariantNames: variantNames,
      );
      final expectedScenarios = [
        for (final scenario in run.scenarios)
          if (capabilityIds.contains(scenario.metadata.primaryCapabilityId))
            scenario,
      ];
      final expectedVariants = [
        for (final name in variantNames)
          if (expectedVariantsByName.containsKey(name))
            expectedVariantsByName[name]!,
      ];
      for (final binding in manifest.profileExecutionBindings) {
        final profile = profilesByName[binding.profileName];
        final expectedTraceCount = profile == null
            ? 0
            : _expectedTraceCount(
                manifest: manifest,
                scenarios: expectedScenarios,
                variants: expectedVariants,
                profile: profile,
              );
        final matchingTraces = [
          for (final trace in run.artifacts.traces)
            if (trace.profile.name == binding.profileName &&
                capabilityIds.contains(
                  trace.scenario.metadata.primaryCapabilityId,
                ) &&
                variantNames.contains(trace.agentDirectiveVariant.name))
              trace,
        ];
        final verifiedResolvedModelTraceCount = matchingTraces
            .where((trace) => _hasResolvedModelEvidence(trace, binding))
            .length;
        final providerRequestEvidence =
            matchingTraces.isNotEmpty &&
            matchingTraces.every(
              (trace) => _hasProviderRequestEvidence(trace, binding),
            );
        if (matchingTraces.any(
          (trace) => !_hasResolvedModelEvidence(trace, binding),
        )) {
          issues.add(
            <String, dynamic>{
              'code': 'execution.resolvedModelEvidenceMissing',
              'severity': 'warning',
              'sourceRunRef': sourceRunRef,
              'workOrderBatchRef': batchRef,
              'modelClass': binding.modelClass.name,
            },
          );
        }
        if (matchingTraces.any(
          (trace) => !_hasProviderRequestEvidence(trace, binding),
        )) {
          issues.add(
            <String, dynamic>{
              'code': 'execution.providerRequestEvidenceMissing',
              'severity': 'warning',
              'sourceRunRef': sourceRunRef,
              'workOrderBatchRef': batchRef,
              'modelClass': binding.modelClass.name,
            },
          );
        }
        final row = <String, dynamic>{
          'evidenceRowRef': '',
          'sourceRunRef': sourceRunRef,
          'workOrderBatchRef': batchRef,
          'modelClass': binding.modelClass.name,
          'profileSlotRef': EvalProvenance.digestJson(<String, dynamic>{
            'workOrderDigest': workOrderDigest,
            'sourceRunRef': sourceRunRef,
            'profileBindingSetDigest': manifest.profileBindingSetDigest,
            'profileName': binding.profileName,
            'modelClass': binding.modelClass.name,
          }),
          'expectedTraceCount': expectedTraceCount,
          'observedTraceCount': matchingTraces.length,
          'verifiedResolvedModelTraceCount': verifiedResolvedModelTraceCount,
          'resolvedModelEvidence':
              matchingTraces.isNotEmpty &&
              verifiedResolvedModelTraceCount == matchingTraces.length,
          'providerRequestEvidence': providerRequestEvidence,
        };
        row['evidenceRowRef'] = evidenceRowRef(row);
        rows.add(row);
      }
    }
    return rows;
  }

  static void _addPublicSelectorIssues({
    required List<Map<String, dynamic>> issues,
    required EvalRunManifest manifest,
    required EvalUseCaseModelClassExecutionRun run,
    required String sourceRunRef,
    required String workOrderBatchRef,
    required Set<String> requiredCapabilityIds,
    required Set<String> requiredPromptVariantNames,
  }) {
    final readinessContract = manifest.tuningReadinessContractEvidence;
    if (requiredCapabilityIds.isNotEmpty) {
      final manifestCapabilities =
          readinessContract?.requiredPrimaryCapabilityIds ?? const <String>{};
      final missingCapabilities = requiredCapabilityIds.difference(
        manifestCapabilities,
      );
      if (readinessContract == null || missingCapabilities.isNotEmpty) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderCapabilityEvidenceMissing',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
            'workOrderBatchRef': workOrderBatchRef,
          },
        );
      }
      if (readinessContract != null &&
          readinessContract.scenarioSetDigest != manifest.scenarioSetDigest) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.readinessContractScenarioDigestMismatch',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
            'workOrderBatchRef': workOrderBatchRef,
          },
        );
      }
      final availableCapabilities = {
        for (final scenario in run.scenarios)
          scenario.metadata.primaryCapabilityId,
      };
      if (!availableCapabilities.containsAll(requiredCapabilityIds)) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderCapabilityCoverageMissing',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
            'workOrderBatchRef': workOrderBatchRef,
          },
        );
      }
    }
    if (requiredPromptVariantNames.isNotEmpty) {
      final availableVariants = {
        for (final variant in run.agentDirectiveVariants) variant.name,
      };
      if (!availableVariants.containsAll(requiredPromptVariantNames)) {
        issues.add(
          <String, dynamic>{
            'code': 'execution.workOrderPromptVariantEvidenceMissing',
            'severity': 'blocking',
            'sourceRunRef': sourceRunRef,
            'workOrderBatchRef': workOrderBatchRef,
          },
        );
      }
    }
  }

  static String evidenceRowRef(Map<String, dynamic> row) =>
      EvalProvenance.digestJson(_evidenceRowSubject(row));

  static int _expectedTraceCount({
    required EvalRunManifest manifest,
    required List<EvalScenario> scenarios,
    required List<EvalAgentDirectiveVariant> variants,
    required EvalProfile profile,
  }) {
    final topology = manifest.traceTopologyEvidence;
    var count = 0;
    for (final scenario in scenarios) {
      final wakeCount =
          topology?.cascadeWakeCountByScenarioId[scenario.id] ?? 1;
      count += wakeCount * variants.length * profile.trialCount;
    }
    return count;
  }

  static bool _hasResolvedModelEvidence(
    EvalTrace trace,
    EvalProfileExecutionBinding binding,
  ) {
    final resolved = trace.output.resolvedModel;
    if (resolved == null) return false;
    return resolved.profileId == binding.profileId &&
        resolved.modelConfigId == binding.modelConfigId &&
        resolved.providerModelId == binding.providerModelId &&
        resolved.providerId == binding.providerId &&
        resolved.providerType == binding.providerType &&
        _optionalEquals(
          resolved.providerEndpointOrigin,
          binding.providerEndpointOrigin,
        ) &&
        _optionalEquals(
          resolved.providerBaseUrlDigest,
          binding.providerBaseUrlDigest,
        );
  }

  static bool _hasProviderRequestEvidence(
    EvalTrace trace,
    EvalProfileExecutionBinding binding,
  ) {
    if (trace.output.providerRequests.isEmpty) return false;
    return trace.output.providerRequests.every(
      (request) =>
          request.providerModelId == binding.providerModelId &&
          request.providerId == binding.providerId &&
          request.providerType == binding.providerType &&
          _optionalEquals(
            request.providerEndpointOrigin,
            binding.providerEndpointOrigin,
          ) &&
          _optionalEquals(
            request.providerBaseUrlDigest,
            binding.providerBaseUrlDigest,
          ),
    );
  }

  static bool _optionalEquals(String? actual, String expected) =>
      expected.isEmpty || actual == expected;

  static String _status({
    required List<Map<String, dynamic>> issues,
    required List<Map<String, dynamic>> evidenceRows,
  }) {
    if (issues.any((issue) => issue['severity'] == 'blocking')) {
      return 'invalidSource';
    }
    if (evidenceRows.isEmpty) return 'empty';
    if (issues.isNotEmpty) return 'partial';
    return 'ready';
  }

  static bool _hasBlockingSourceRunIssues(
    List<Map<String, dynamic>> issues,
  ) => issues.any(
    (issue) =>
        issue['severity'] == 'blocking' &&
        issue['code'] != 'execution.verifierFailed',
  );

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
    _expectNonEmptyString(issues, source['status'], 'sourceWorkOrder.status');
    _expectDigest(
      issues,
      source['workOrderRef'],
      'sourceWorkOrder.workOrderRef',
    );
    _expectDigest(
      issues,
      source['workOrderDigest'],
      'sourceWorkOrder.workOrderDigest',
    );
    _expectDigest(
      issues,
      source['sourceExperimentPlanDigest'],
      'sourceWorkOrder.sourceExperimentPlanDigest',
    );
    _expectDigest(
      issues,
      source['sourceMatrixDigest'],
      'sourceWorkOrder.sourceMatrixDigest',
    );
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

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'sourceRunCount',
      'evidenceRowCount',
      'expectedTraceCount',
      'observedTraceCount',
      'verifiedResolvedModelTraceCount',
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
      'readsPrivateRunArtifacts': true,
      'readsPrivateExpectedCatalogs': true,
      'writesSanitizedEvidenceRowsOnly': true,
      'publicCoverageComputedElsewhere': true,
      'liveModelCallsStarted': false,
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

  static void _validateSourceRuns(List<String> issues, List<dynamic>? runs) {
    if (runs == null) return;
    for (final (index, value) in runs.indexed) {
      final path = 'sourceRuns[$index]';
      final run = _expectMap(issues, value, path);
      if (run == null) continue;
      _expectDigest(issues, run['sourceRunRef'], '$path.sourceRunRef');
      for (final field in const [
        'actualManifestDigest',
        'manifestDigest',
        'profileBindingSetDigest',
        'scenarioSetDigest',
        'profileSetDigest',
        'agentDirectiveVariantSetDigest',
      ]) {
        _expectDigest(issues, run[field], '$path.$field');
      }
      for (final field in const [
        'workOrderLaunchSubjectDigest',
        'workOrderDigest',
        'workOrderRef',
        'workOrderBatchSetDigest',
      ]) {
        final digest = _string(run[field]);
        if (digest.isNotEmpty && !EvalProvenance.isDigest(digest)) {
          issues.add('$path.$field must be a sha256 digest');
        }
      }
      final batchRefs = _expectList(
        issues,
        run['workOrderBatchRefs'],
        '$path.workOrderBatchRefs',
      );
      for (final (batchIndex, ref) in (batchRefs ?? const []).indexed) {
        _expectDigest(
          issues,
          ref,
          '$path.workOrderBatchRefs[$batchIndex]',
        );
      }
      if (batchRefs != null &&
          batchRefs.isNotEmpty &&
          run['workOrderBatchSetDigest'] !=
              EvalProvenance.digestJson(_stringList(batchRefs))) {
        issues.add('$path.workOrderBatchSetDigest must bind batch refs');
      }
      final readinessContractSubjectDigest = _string(
        run['readinessContractSubjectDigest'],
      );
      if (readinessContractSubjectDigest.isNotEmpty &&
          !EvalProvenance.isDigest(readinessContractSubjectDigest)) {
        issues.add(
          '$path.readinessContractSubjectDigest must be a sha256 digest',
        );
      }
      final expectedRef = _sourceRunRef(run);
      if (run['sourceRunRef'] != expectedRef) {
        issues.add('$path.sourceRunRef must bind source run digests');
      }
      for (final field in const [
        'traceCount',
        'artifactCount',
        'profileBindingCount',
        'verifierIssueCount',
      ]) {
        _expectNonNegativeInt(issues, run[field], '$path.$field');
      }
    }
  }

  static void _validateEvidenceRows(
    List<String> issues,
    List<dynamic>? rows, {
    required List<dynamic>? sourceRuns,
  }) {
    if (rows == null) return;
    final sourceRunRefs = {
      for (final run in _mapList(sourceRuns)) _string(run['sourceRunRef']),
    };
    for (final (index, value) in rows.indexed) {
      final path = 'evidenceRows[$index]';
      final row = _expectMap(issues, value, path);
      if (row == null) continue;
      _expectDigest(issues, row['evidenceRowRef'], '$path.evidenceRowRef');
      final sourceRunRef = _expectNonEmptyString(
        issues,
        row['sourceRunRef'],
        '$path.sourceRunRef',
      );
      if (sourceRunRef != null && !EvalProvenance.isDigest(sourceRunRef)) {
        issues.add('$path.sourceRunRef must be a sha256 digest');
      }
      if (sourceRunRef != null &&
          sourceRunRefs.isNotEmpty &&
          !sourceRunRefs.contains(sourceRunRef)) {
        issues.add('$path.sourceRunRef must reference sourceRuns');
      }
      _expectDigest(
        issues,
        row['workOrderBatchRef'],
        '$path.workOrderBatchRef',
      );
      _expectDigest(issues, row['profileSlotRef'], '$path.profileSlotRef');
      final modelClass = _expectNonEmptyString(
        issues,
        row['modelClass'],
        '$path.modelClass',
      );
      if (modelClass != null &&
          !EvalModelClass.values.any((value) => value.name == modelClass)) {
        issues.add('$path.modelClass must be an EvalModelClass name');
      }
      for (final field in const [
        'expectedTraceCount',
        'observedTraceCount',
        'verifiedResolvedModelTraceCount',
      ]) {
        _expectNonNegativeInt(issues, row[field], '$path.$field');
      }
      _expectBool(
        issues,
        row['resolvedModelEvidence'],
        '$path.resolvedModelEvidence',
      );
      _expectBool(
        issues,
        row['providerRequestEvidence'],
        '$path.providerRequestEvidence',
      );
      final expectedRef = evidenceRowRef(row);
      if (row['evidenceRowRef'] != expectedRef) {
        issues.add('$path.evidenceRowRef must bind evidence row fields');
      }
    }
  }

  static void _validateIssues(List<String> issues, List<dynamic>? values) {
    if (values == null) return;
    for (final (index, value) in values.indexed) {
      final path = 'issues[$index]';
      final issue = _expectMap(issues, value, path);
      if (issue == null) continue;
      _expectNonEmptyString(issues, issue['code'], '$path.code');
      _expectNonEmptyString(issues, issue['severity'], '$path.severity');
      if (issue.containsKey('sourceRunRef')) {
        _expectDigest(issues, issue['sourceRunRef'], '$path.sourceRunRef');
      }
      if (issue.containsKey('workOrderBatchRef')) {
        _expectDigest(
          issues,
          issue['workOrderBatchRef'],
          '$path.workOrderBatchRef',
        );
      }
      if (issue.containsKey('modelClass')) {
        final modelClass = _string(issue['modelClass']);
        if (!EvalModelClass.values.any((value) => value.name == modelClass)) {
          issues.add('$path.modelClass must be an EvalModelClass name');
        }
      }
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? sourceRuns,
    required List<dynamic>? evidenceRows,
    required List<dynamic>? artifactIssues,
  }) {
    if (summary == null) return;
    if (sourceRuns != null &&
        summary['sourceRunCount'] is int &&
        summary['sourceRunCount'] != sourceRuns.length) {
      issues.add('summary.sourceRunCount must match sourceRuns.length');
    }
    if (evidenceRows != null) {
      if (summary['evidenceRowCount'] is int &&
          summary['evidenceRowCount'] != evidenceRows.length) {
        issues.add('summary.evidenceRowCount must match evidenceRows.length');
      }
      for (final field in const [
        'expectedTraceCount',
        'observedTraceCount',
        'verifiedResolvedModelTraceCount',
      ]) {
        final total = evidenceRows.whereType<Map<String, dynamic>>().fold<int>(
          0,
          (sum, row) => sum + _int(row[field]),
        );
        if (summary[field] is int && summary[field] != total) {
          issues.add('summary.$field must match evidence row total');
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
    required List<dynamic>? sourceRuns,
    required List<dynamic>? evidenceRows,
    required List<dynamic>? artifactIssues,
  }) {
    if (status == null ||
        sourceRuns == null ||
        evidenceRows == null ||
        artifactIssues == null) {
      return;
    }
    final hasBlocking = artifactIssues.any(
      (issue) =>
          issue is Map<String, dynamic> && issue['severity'] == 'blocking',
    );
    if (status == 'invalidSource' && !hasBlocking) {
      issues.add('invalidSource status must include a blocking issue');
    }
    if (status == 'ready' && artifactIssues.isNotEmpty) {
      issues.add('ready status must not have issues');
    }
    if (status == 'ready' && sourceRuns.isEmpty) {
      issues.add('ready status requires sourceRuns');
    }
    if (evidenceRows.isNotEmpty && sourceRuns.isEmpty) {
      issues.add('evidenceRows require sourceRuns');
    }
    if (status == 'empty' && evidenceRows.isNotEmpty) {
      issues.add('empty status requires no evidence rows');
    }
  }

  static void _validateExecutionEvidenceRef(
    List<String> issues,
    Map<String, dynamic> artifact,
  ) {
    final expectedRef = executionEvidenceRef(artifact);
    if (artifact['executionEvidenceRef'] != expectedRef) {
      issues.add('executionEvidenceRef must match execution evidence subject');
    }
  }

  static Map<String, dynamic> _executionEvidenceSubject(
    Map<String, dynamic> artifact,
  ) => <String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': _string(artifact['status']),
    'sourceWorkOrderDigest': EvalProvenance.digestJson(
      _map(artifact['sourceWorkOrder']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(artifact['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(artifact['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(artifact['limitations']),
    ),
    'sourceRunsDigest': EvalProvenance.digestJson(
      _mapList(artifact['sourceRuns']),
    ),
    'evidenceRowsDigest': EvalProvenance.digestJson(
      _mapList(artifact['evidenceRows']),
    ),
    'issuesDigest': EvalProvenance.digestJson(_mapList(artifact['issues'])),
  };

  static Map<String, dynamic> _evidenceRowSubject(
    Map<String, dynamic> row,
  ) => <String, dynamic>{
    'sourceRunRef': _string(row['sourceRunRef']),
    'workOrderBatchRef': _string(row['workOrderBatchRef']),
    'modelClass': _string(row['modelClass']),
    'profileSlotRef': _string(row['profileSlotRef']),
    'expectedTraceCount': _int(row['expectedTraceCount']),
    'observedTraceCount': _int(row['observedTraceCount']),
    'verifiedResolvedModelTraceCount': _int(
      row['verifiedResolvedModelTraceCount'],
    ),
    'resolvedModelEvidence': row['resolvedModelEvidence'] == true,
    'providerRequestEvidence': row['providerRequestEvidence'] == true,
  };

  static void _validateNoPrivatePayloads(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final reason = _privateFieldReason(key.toLowerCase());
        if (reason != null) issues.add('$path.$key must not expose $reason');
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

final class _SourceRun {
  const _SourceRun({
    required this.sourceRunRef,
    required this.actualManifestDigest,
    required this.manifestDigest,
    required this.workOrderLaunchSubjectDigest,
    required this.workOrderDigest,
    required this.workOrderRef,
    required this.workOrderBatchSetDigest,
    required this.workOrderBatchRefs,
    required this.profileBindingSetDigest,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.agentDirectiveVariantSetDigest,
    required this.readinessContractSubjectDigest,
    required this.traceCount,
    required this.artifactCount,
    required this.profileBindingCount,
    required this.verifierIssueCount,
    required this.issues,
  });

  final String sourceRunRef;
  final String actualManifestDigest;
  final String manifestDigest;
  final String workOrderLaunchSubjectDigest;
  final String workOrderDigest;
  final String workOrderRef;
  final String workOrderBatchSetDigest;
  final List<String> workOrderBatchRefs;
  final String profileBindingSetDigest;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String agentDirectiveVariantSetDigest;
  final String readinessContractSubjectDigest;
  final int traceCount;
  final int artifactCount;
  final int profileBindingCount;
  final int verifierIssueCount;
  final List<Map<String, dynamic>> issues;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceRunRef': sourceRunRef,
    'actualManifestDigest': actualManifestDigest,
    'manifestDigest': manifestDigest,
    'workOrderLaunchSubjectDigest': workOrderLaunchSubjectDigest,
    'workOrderDigest': workOrderDigest,
    'workOrderRef': workOrderRef,
    'workOrderBatchSetDigest': workOrderBatchSetDigest,
    'workOrderBatchRefs': [...workOrderBatchRefs]..sort(),
    'profileBindingSetDigest': profileBindingSetDigest,
    'scenarioSetDigest': scenarioSetDigest,
    'profileSetDigest': profileSetDigest,
    'agentDirectiveVariantSetDigest': agentDirectiveVariantSetDigest,
    'readinessContractSubjectDigest': readinessContractSubjectDigest,
    'traceCount': traceCount,
    'artifactCount': artifactCount,
    'profileBindingCount': profileBindingCount,
    'verifierIssueCount': verifierIssueCount,
  };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _sourceRunRef(Map<String, dynamic> sourceRun) =>
    EvalProvenance.digestJson(<String, dynamic>{
      'actualManifestDigest': _string(sourceRun['actualManifestDigest']),
      'manifestDigest': _string(sourceRun['manifestDigest']),
      'workOrderLaunchSubjectDigest': _string(
        sourceRun['workOrderLaunchSubjectDigest'],
      ),
      'workOrderDigest': _string(sourceRun['workOrderDigest']),
      'workOrderRef': _string(sourceRun['workOrderRef']),
      'workOrderBatchSetDigest': _string(
        sourceRun['workOrderBatchSetDigest'],
      ),
      'profileBindingSetDigest': _string(
        sourceRun['profileBindingSetDigest'],
      ),
      'scenarioSetDigest': _string(sourceRun['scenarioSetDigest']),
      'profileSetDigest': _string(sourceRun['profileSetDigest']),
      'agentDirectiveVariantSetDigest': _string(
        sourceRun['agentDirectiveVariantSetDigest'],
      ),
      'readinessContractSubjectDigest': _string(
        sourceRun['readinessContractSubjectDigest'],
      ),
    });

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

int _sum(List<Map<String, dynamic>> values, String field) =>
    values.fold<int>(0, (sum, value) => sum + _int(value[field]));

Set<String> _duplicates(Iterable<String> values) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (!seen.add(value)) duplicates.add(value);
  }
  return duplicates;
}
