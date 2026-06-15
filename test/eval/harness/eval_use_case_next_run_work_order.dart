import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_use_case_experiment_plan.dart';

abstract final class EvalUseCaseNextRunWorkOrder {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseNextRunWorkOrder';
  static const _allowedStatuses = {
    'invalidPlan',
    'blockedPlan',
    'noRunnableBatches',
    'ready',
  };
  static const _allowedBatchObjectives = {
    'collectData',
    'collectPromotionEvidence',
  };
  static const _allowedTopLevelFields = {
    'schemaVersion',
    'kind',
    'workOrderRef',
    'generatedAt',
    'status',
    'sourceExperimentPlan',
    'summary',
    'privacy',
    'limitations',
    'blockedReasonCodes',
    'runBatches',
    'commandTemplates',
    'adversarialReviewQueue',
  };
  static const _allowedCommandTemplateFields = {
    'ref',
    'mode',
    'commandTemplate',
    'allowedPublicEnvKeys',
    'privateInputsRequired',
    'valuesOmitted',
  };
  static const _allowedPublicEnvKeys = {
    'EVAL_REQUIRED_CAPABILITIES',
    'EVAL_PROMPT_VARIANT_NAMES',
  };
  static const _allowedTemplateRefs = {'plan', 'run', 'tune'};
  static const _allowedReviewCategories = {
    'privacyAudit',
    'publicEnvAllowlistAudit',
    'commandTemplateAudit',
    'evidenceObjectiveAudit',
  };
  static const _reviewCompletionClaimFields = {
    'approved',
    'completedAt',
    'complete',
    'findingCount',
    'findings',
    'outcome',
    'passed',
    'reviewedBy',
    'reviewer',
    'verdict',
  };
  static const _reviewExecutableFields = {
    'command',
    'commands',
    'commandTemplate',
    'commandTemplates',
    'env',
    'publicEnv',
    'recommendedCommands',
    'shell',
    'shellCommand',
  };
  static const _privateValueEnvKeys = {
    'EVAL_SCENARIO_IDS',
    'EVAL_PROFILE_NAMES',
    'EVAL_PROFILES',
    'EVAL_SCENARIOS',
    'EVAL_RUNS_ROOT',
    'EVAL_CALIBRATION',
    'EVAL_CALIBRATION_TEMPLATE',
    'EVAL_PAIRWISE_PAIRS',
    'EVAL_PAIRWISE_BLINDED_EXPORT',
    'EVAL_PAIRWISE_BLINDED_IMPORT',
    'EVAL_PROMPT_VARIANTS',
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
    r'EVAL_PROMPT_VARIANTS)\b',
  );
  static final _shellSmugglingPattern = RegExp(
    r'(?:^|\s)(?:bash|sh)\s+-lc\b|[;&|`]|(?:^|\s)(?:env\s+)?[A-Z][A-Z0-9_]*=',
  );

  static Map<String, dynamic> build({
    required Map<String, dynamic> experimentPlan,
    DateTime? generatedAt,
    int maxRunBatches = 6,
  }) {
    final boundedMaxRunBatches = maxRunBatches < 1 ? 0 : maxRunBatches;
    final planIssues = EvalUseCaseExperimentPlan.validate(experimentPlan);
    final planDigest = EvalProvenance.digestJson(experimentPlan);
    final sourceMatrix = _map(experimentPlan['sourceMatrix']);
    final sourceMatrixDigest = _string(sourceMatrix['matrixDigest']);
    final planStatus = _string(experimentPlan['status']);
    final sourceBatches = planIssues.isEmpty
        ? _mapList(experimentPlan['batches'])
        : const <Map<String, dynamic>>[];
    final runBatches = planIssues.isEmpty && planStatus == 'ready'
        ? [
            for (final batch in sourceBatches.take(boundedMaxRunBatches))
              _runBatch(
                planDigest: planDigest,
                sourceMatrixDigest: sourceMatrixDigest,
                batch: batch,
              ),
          ]
        : const <Map<String, dynamic>>[];
    final status = _status(
      planIssues: planIssues,
      planStatus: planStatus,
      sourceBatches: sourceBatches,
      runBatches: runBatches,
    );
    final blockedCodes = _blockedReasonCodes(
      plan: experimentPlan,
      planIssues: planIssues,
      planStatus: planStatus,
      sourceBatches: sourceBatches,
      runBatches: runBatches,
      status: status,
    );
    final commandTemplates = _commandTemplates();

    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'workOrderRef': '',
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceExperimentPlan': <String, dynamic>{
        'kind': EvalUseCaseExperimentPlan.kind,
        'schemaVersion': EvalUseCaseExperimentPlan.schemaVersion,
        'status': planStatus.isEmpty ? 'unknown' : planStatus,
        'planDigest': planDigest,
        'sourceMatrixDigest': sourceMatrixDigest,
        'sourceBatchCount': sourceBatches.length,
        'contractIssueCount': planIssues.length,
      },
      'summary': <String, dynamic>{
        'sourceBatchCount': sourceBatches.length,
        'runBatchCount': runBatches.length,
        'maxRunBatches': boundedMaxRunBatches,
        'blockedReasonCount': blockedCodes.length,
        'commandTemplateCount': commandTemplates.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'rawRunIdsOmitted': true,
        'privatePathsOmitted': true,
        'concretePrivateEnvValuesOmitted': true,
        'providerModelIdsOmitted': true,
        'promptTextOmitted': true,
        'promotionClaimsCreated': false,
      },
      'limitations': const <String, dynamic>{
        'consumesExperimentPlanOnly': true,
        'tracesReRead': false,
        'privateCatalogsRead': false,
        'liveModelCallsStarted': false,
        'modelClassSelectorsOmitted': true,
        'profileSelectorsRequiredPrivately': true,
        'promotionClaimsCreated': false,
      },
      'blockedReasonCodes': blockedCodes,
      'runBatches': runBatches,
      'commandTemplates': commandTemplates,
      'adversarialReviewQueue': _adversarialReviewQueue(
        sourcePlanDigest: planDigest,
        sourceMatrixDigest: sourceMatrixDigest,
        blockedCodes: blockedCodes,
        runBatches: runBatches,
      ),
    };
    artifact['workOrderRef'] = workOrderRef(artifact);
    assertValid(artifact);
    return artifact;
  }

  static String workOrderRef(Map<String, dynamic> workOrder) =>
      EvalProvenance.digestJson(_workOrderSubject(workOrder));

  static List<String> validate(Map<String, dynamic> workOrder) {
    final issues = <String>[];
    _expectEquals(
      issues,
      workOrder['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _validateAllowedKeys(
      issues,
      workOrder,
      _allowedTopLevelFields,
      'workOrder',
    );
    _expectEquals(issues, workOrder['kind'], kind, 'kind');
    _expectDigest(issues, workOrder['workOrderRef'], 'workOrderRef');
    _expectIsoDate(issues, workOrder['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(
      issues,
      workOrder['status'],
      'status',
    );
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final sourcePlan = _expectMap(
      issues,
      workOrder['sourceExperimentPlan'],
      'sourceExperimentPlan',
    );
    _validateSourcePlan(issues, sourcePlan);
    final summary = _expectMap(issues, workOrder['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(
      issues,
      _expectMap(issues, workOrder['privacy'], 'privacy'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, workOrder['limitations'], 'limitations'),
    );
    final blockedCodes = _expectStringList(
      issues,
      workOrder['blockedReasonCodes'],
      'blockedReasonCodes',
    );
    final runBatches = _expectList(
      issues,
      workOrder['runBatches'],
      'runBatches',
    );
    _validateRunBatches(
      issues,
      runBatches,
      sourcePlan: _map(workOrder['sourceExperimentPlan']),
    );
    final commandTemplates = _expectList(
      issues,
      workOrder['commandTemplates'],
      'commandTemplates',
    );
    _validateCommandTemplates(issues, commandTemplates);
    _validateAdversarialReviewQueue(
      issues,
      _expectMap(
        issues,
        workOrder['adversarialReviewQueue'],
        'adversarialReviewQueue',
      ),
      sourcePlan: sourcePlan,
      blockedCodes: blockedCodes,
      runBatches: runBatches,
    );
    _validateSummaryInvariants(
      issues,
      summary: summary,
      blockedCodes: blockedCodes,
      runBatches: runBatches,
      commandTemplates: commandTemplates,
    );
    _validateStatusInvariants(
      issues,
      status: status,
      summary: summary,
      sourcePlan: sourcePlan,
      runBatches: runBatches,
    );
    _validateWorkOrderRef(issues, workOrder);
    _validateNoPrivatePayloads(issues, workOrder, 'workOrder');
    return issues;
  }

  static void assertValid(Map<String, dynamic> workOrder) {
    final issues = validate(workOrder);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case next-run work order:\n${issues.join('\n')}',
    );
  }

  static List<String> validateAgainstExperimentPlan(
    Map<String, dynamic> workOrder, {
    required Map<String, dynamic> experimentPlan,
  }) {
    final issues = validate(workOrder);
    final planIssues = EvalUseCaseExperimentPlan.validate(experimentPlan);
    if (planIssues.isNotEmpty) {
      issues.add('source experiment plan contract is invalid');
      return issues;
    }
    final sourcePlan = _map(workOrder['sourceExperimentPlan']);
    final expectedPlanDigest = EvalProvenance.digestJson(experimentPlan);
    final expectedMatrixDigest = _string(
      _map(experimentPlan['sourceMatrix'])['matrixDigest'],
    );
    if (_string(sourcePlan['planDigest']) != expectedPlanDigest) {
      issues.add('sourceExperimentPlan.planDigest must match experimentPlan');
    }
    if (_string(sourcePlan['sourceMatrixDigest']) != expectedMatrixDigest) {
      issues.add(
        'sourceExperimentPlan.sourceMatrixDigest must match experimentPlan',
      );
    }
    if (_intOrZero(sourcePlan['sourceBatchCount']) !=
        _mapList(experimentPlan['batches']).length) {
      issues.add(
        'sourceExperimentPlan.sourceBatchCount must match experimentPlan',
      );
    }
    if (_string(sourcePlan['status']) != _string(experimentPlan['status'])) {
      issues.add('sourceExperimentPlan.status must match experimentPlan');
    }
    return issues;
  }

  static void assertMatchesExperimentPlan(
    Map<String, dynamic> workOrder, {
    required Map<String, dynamic> experimentPlan,
  }) {
    final issues = validateAgainstExperimentPlan(
      workOrder,
      experimentPlan: experimentPlan,
    );
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case next-run work order source binding:\n'
      '${issues.join('\n')}',
    );
  }

  static EvalUseCaseWorkOrderLaunchEvidence launchEvidenceForRun({
    required Map<String, dynamic> workOrder,
    required Set<String> requiredPrimaryCapabilityIds,
    required List<String> promptVariantNames,
    Iterable<String> workOrderBatchRefs = const <String>[],
  }) {
    assertValid(workOrder);
    if (_string(workOrder['status']) != 'ready') {
      throw StateError(
        'Use-case work-order launch evidence requires a ready '
        'work order.',
      );
    }
    final selectedCapabilities = _sortedStrings(requiredPrimaryCapabilityIds);
    final selectedPromptVariants = _sortedStrings(promptVariantNames);
    if (selectedCapabilities.isEmpty) {
      throw StateError(
        'Use-case work-order launch evidence requires '
        'EVAL_REQUIRED_CAPABILITIES.',
      );
    }
    if (selectedPromptVariants.isEmpty) {
      throw StateError(
        'Use-case work-order launch evidence requires '
        'EVAL_PROMPT_VARIANT_NAMES or the default prompt variant.',
      );
    }
    final runBatches = _mapList(workOrder['runBatches']);
    final publicEnv = _publicEnv(
      capabilities: selectedCapabilities,
      promptVariantNames: selectedPromptVariants,
    );
    final explicitBatchRefs = _sortedStrings(workOrderBatchRefs);
    final selectedBatches = explicitBatchRefs.isEmpty
        ? [
            for (final batch in runBatches)
              if (_sameJson(_map(batch['publicEnv']), publicEnv)) batch,
          ]
        : [
            for (final ref in explicitBatchRefs)
              _batchForRef(runBatches, ref) ??
                  (throw StateError(
                    'Unknown EVAL_USE_CASE_RUN_WORK_ORDER_BATCH_REFS entry '
                    '$ref.',
                  )),
          ];
    if (selectedBatches.isEmpty) {
      throw StateError(
        'No work-order run batch matches the selected public '
        'capabilities and prompt variants.',
      );
    }
    for (final batch in selectedBatches) {
      final batchRef = _string(batch['workOrderBatchRef']);
      if (!_sameJson(_map(batch['publicEnv']), publicEnv)) {
        throw StateError(
          'Work-order batch $batchRef does not match the '
          'selected public capabilities and prompt variants.',
        );
      }
    }
    final batchRefs = _sortedStrings(
      selectedBatches.map((batch) => _string(batch['workOrderBatchRef'])),
    );
    final sourcePlan = _map(workOrder['sourceExperimentPlan']);
    final batchSetDigest = EvalProvenance.digestJson(batchRefs);
    final subject = EvalUseCaseWorkOrderLaunchEvidence.subjectJson(
      workOrderRef: _string(workOrder['workOrderRef']),
      workOrderDigest: EvalProvenance.digestJson(workOrder),
      sourceExperimentPlanDigest: _string(sourcePlan['planDigest']),
      sourceMatrixDigest: _string(sourcePlan['sourceMatrixDigest']),
      workOrderBatchRefs: batchRefs,
      workOrderBatchSetDigest: batchSetDigest,
      requiredPrimaryCapabilityIds: selectedCapabilities.toSet(),
      promptVariantNames: selectedPromptVariants,
    );
    return EvalUseCaseWorkOrderLaunchEvidence(
      workOrderRef: _string(workOrder['workOrderRef']),
      workOrderDigest: EvalProvenance.digestJson(workOrder),
      sourceExperimentPlanDigest: _string(sourcePlan['planDigest']),
      sourceMatrixDigest: _string(sourcePlan['sourceMatrixDigest']),
      workOrderBatchRefs: batchRefs,
      workOrderBatchSetDigest: batchSetDigest,
      requiredPrimaryCapabilityIds: Set.unmodifiable(selectedCapabilities),
      promptVariantNames: List.unmodifiable(selectedPromptVariants),
      workOrderLaunchSubjectDigest: EvalProvenance.digestJson(subject),
    );
  }

  static String _status({
    required List<String> planIssues,
    required String planStatus,
    required List<Map<String, dynamic>> sourceBatches,
    required List<Map<String, dynamic>> runBatches,
  }) {
    if (planIssues.isNotEmpty || planStatus == 'invalid') return 'invalidPlan';
    if (planStatus == 'noRunnableBatches') return 'noRunnableBatches';
    if (planStatus != 'ready') return 'blockedPlan';
    if (sourceBatches.isEmpty || runBatches.isEmpty) return 'noRunnableBatches';
    return 'ready';
  }

  static Map<String, dynamic> _runBatch({
    required String planDigest,
    required String sourceMatrixDigest,
    required Map<String, dynamic> batch,
  }) {
    final selectors = _map(batch['safeSelectors']);
    final capabilities = _safeSelectorValues(
      _stringList(selectors['capabilities']),
    );
    final promptVariantNames = _safeSelectorValues(
      _stringList(selectors['promptVariantNames']),
    );
    final publicEnv = <String, dynamic>{
      'EVAL_REQUIRED_CAPABILITIES': capabilities.join(','),
      'EVAL_PROMPT_VARIANT_NAMES': promptVariantNames.join(','),
    };
    final sourcePlanBatchRef = _string(batch['batchRef']);
    final compatibilityKey = _string(batch['compatibilityKey']);
    final sourceCellKeys = _sortedStrings(_stringList(batch['sourceCellKeys']));
    final sourceEvidenceStatuses = _sortedStrings(
      _stringList(batch['evidenceStatuses']),
    );
    final workOrderBatchRef = _workOrderBatchRef(
      planDigest: planDigest,
      sourceMatrixDigest: sourceMatrixDigest,
      sourcePlanBatchRef: sourcePlanBatchRef,
      compatibilityKey: compatibilityKey,
      sourceCellKeys: sourceCellKeys,
      publicEnv: publicEnv,
    );
    return <String, dynamic>{
      'workOrderBatchRef': workOrderBatchRef,
      'sourcePlanBatchRef': sourcePlanBatchRef,
      'compatibilityKey': compatibilityKey,
      'sourceCellKeys': sourceCellKeys,
      'sourceEvidenceStatuses': sourceEvidenceStatuses,
      'objective': _objective(_string(batch['status'])),
      'publicSelectors': <String, dynamic>{
        'capabilities': capabilities,
        'promptVariantNames': promptVariantNames,
      },
      'publicEnv': publicEnv,
      'withheldInputs': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'rawRunIdsOmitted': true,
        'privatePathsOmitted': true,
        'concretePrivateEnvValuesOmitted': true,
      },
      'commandTemplateRefs': const ['plan', 'run', 'tune'],
      'blockedReasonCodes': _sortedStrings(
        _stringList(batch['blockedReasonCodes']),
      ),
    };
  }

  static String _workOrderBatchRef({
    required String planDigest,
    required String sourceMatrixDigest,
    required String sourcePlanBatchRef,
    required String compatibilityKey,
    required List<String> sourceCellKeys,
    required Map<String, dynamic> publicEnv,
  }) {
    return EvalProvenance.digestJson(<String, dynamic>{
      'planDigest': planDigest,
      'sourceMatrixDigest': sourceMatrixDigest,
      'sourcePlanBatchRef': sourcePlanBatchRef,
      'compatibilityKey': compatibilityKey,
      'sourceCellKeys': sourceCellKeys,
      'publicEnv': publicEnv,
    });
  }

  static Map<String, dynamic> _publicEnv({
    required List<String> capabilities,
    required List<String> promptVariantNames,
  }) {
    return <String, dynamic>{
      'EVAL_REQUIRED_CAPABILITIES': capabilities.join(','),
      'EVAL_PROMPT_VARIANT_NAMES': promptVariantNames.join(','),
    };
  }

  static Map<String, dynamic>? _batchForRef(
    List<Map<String, dynamic>> batches,
    String ref,
  ) {
    for (final batch in batches) {
      if (_string(batch['workOrderBatchRef']) == ref) return batch;
    }
    return null;
  }

  static bool _sameJson(Object? left, Object? right) =>
      EvalProvenance.digestJson(left) == EvalProvenance.digestJson(right);

  static String _objective(String batchStatus) {
    return switch (batchStatus) {
      'collectData' => 'collectData',
      _ => 'collectPromotionEvidence',
    };
  }

  static List<String> _blockedReasonCodes({
    required Map<String, dynamic> plan,
    required List<String> planIssues,
    required String planStatus,
    required List<Map<String, dynamic>> sourceBatches,
    required List<Map<String, dynamic>> runBatches,
    required String status,
  }) {
    return _sortedStrings({
      if (planIssues.isNotEmpty) 'experimentPlan.contractInvalid',
      if (planIssues.isEmpty && planStatus != 'ready') 'workOrder.planNotReady',
      if (planIssues.isEmpty &&
          planStatus == 'ready' &&
          (sourceBatches.isEmpty || runBatches.isEmpty))
        'workOrder.noRunnableBatches',
      ..._stringList(plan['blockedReasonCodes']),
      for (final batch in sourceBatches)
        ..._stringList(batch['blockedReasonCodes']),
      if (status == 'blockedPlan' &&
          _stringList(plan['blockedReasonCodes']).isEmpty)
        'workOrder.blockedPlan',
    });
  }

  static List<Map<String, dynamic>> _commandTemplates() {
    return const [
      <String, dynamic>{
        'ref': 'plan',
        'mode': 'plan',
        'commandTemplate': 'eval/run_level2.sh plan <nextRunId>',
        'allowedPublicEnvKeys': [
          'EVAL_REQUIRED_CAPABILITIES',
          'EVAL_PROMPT_VARIANT_NAMES',
        ],
        'privateInputsRequired': true,
        'valuesOmitted': true,
      },
      <String, dynamic>{
        'ref': 'run',
        'mode': 'run',
        'commandTemplate': 'eval/run_level2.sh run <nextRunId>',
        'allowedPublicEnvKeys': [
          'EVAL_REQUIRED_CAPABILITIES',
          'EVAL_PROMPT_VARIANT_NAMES',
        ],
        'privateInputsRequired': true,
        'valuesOmitted': true,
      },
      <String, dynamic>{
        'ref': 'tune',
        'mode': 'tune',
        'commandTemplate': 'eval/run_level2.sh tune <nextRunId>',
        'allowedPublicEnvKeys': [
          'EVAL_REQUIRED_CAPABILITIES',
          'EVAL_PROMPT_VARIANT_NAMES',
        ],
        'privateInputsRequired': true,
        'valuesOmitted': true,
      },
    ];
  }

  static Map<String, dynamic> _adversarialReviewQueue({
    required String sourcePlanDigest,
    required String sourceMatrixDigest,
    required List<String> blockedCodes,
    required List<Map<String, dynamic>> runBatches,
  }) {
    final tasks =
        [
          for (final category in _allowedReviewCategories)
            _adversarialReviewTask(
              category: category,
              sourcePlanDigest: sourcePlanDigest,
              sourceMatrixDigest: sourceMatrixDigest,
              blockedCodes: blockedCodes,
              runBatches: runBatches,
            ),
        ]..sort(
          (a, b) => _string(a['category']).compareTo(_string(b['category'])),
        );
    return <String, dynamic>{
      'status': 'pending',
      'completionClaimsCreated': false,
      'summary': <String, dynamic>{
        'taskCount': tasks.length,
        'pendingTaskCount': tasks.length,
        'requiredTaskCount': tasks.length,
        'completedTaskCount': 0,
      },
      'tasks': tasks,
      'guards': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'rawRunIdsOmitted': true,
        'privatePathsOmitted': true,
        'concretePrivateEnvValuesOmitted': true,
        'reviewCompletionClaimsOmitted': true,
        'promotionClaimsCreated': false,
      },
    };
  }

  static Map<String, dynamic> _adversarialReviewTask({
    required String category,
    required String sourcePlanDigest,
    required String sourceMatrixDigest,
    required List<String> blockedCodes,
    required List<Map<String, dynamic>> runBatches,
  }) {
    final batchRefs = _sortedStrings(
      runBatches.map((batch) => _string(batch['workOrderBatchRef'])),
    );
    final source = <String, dynamic>{
      'category': category,
      'sourcePlanDigest': sourcePlanDigest,
      'sourceMatrixDigest': sourceMatrixDigest,
      'blockedCodes': blockedCodes,
      'batchRefs': batchRefs,
    };
    return <String, dynamic>{
      'reviewRef': EvalProvenance.digestJson(source),
      'category': category,
      'status': 'pending',
      'required': true,
      'requiredBefore': 'runExecution',
      'sourceRefs': <String, dynamic>{
        'sourcePlanDigest': sourcePlanDigest,
        'sourceMatrixDigest': sourceMatrixDigest,
        'workOrderBatchRefs': batchRefs,
        'blockedReasonCodes': blockedCodes,
      },
      'mustCheck': _reviewChecklist(category),
      'privateValuesOmitted': true,
      'completionEvidenceOmitted': true,
    };
  }

  static List<String> _reviewChecklist(String category) {
    return switch (category) {
      'privacyAudit' => const [
        'no scenario ids, profile names, raw run ids, private paths, provider model ids, or prompt text',
        'private operator inputs are represented only by omitted-value guards',
      ],
      'publicEnvAllowlistAudit' => const [
        'public env contains only EVAL_REQUIRED_CAPABILITIES and EVAL_PROMPT_VARIANT_NAMES',
        'public env values are safe selectors and not opaque fallback ids',
      ],
      'commandTemplateAudit' => const [
        'templates are exact eval/run_level2.sh plan, run, or tune placeholders',
        'templates contain no inline env assignments, shell wrappers, pipes, or separators',
      ],
      'evidenceObjectiveAudit' => const [
        'collectData batches are not described as promotion evidence',
        'run batches preserve source plan batch refs, cell keys, and evidence statuses',
      ],
      _ => const ['review the work order for unsafe executable content'],
    };
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
    _expectDigest(
      issues,
      source['sourceMatrixDigest'],
      'sourceExperimentPlan.sourceMatrixDigest',
    );
    _expectNonNegativeInt(
      issues,
      source['sourceBatchCount'],
      'sourceExperimentPlan.sourceBatchCount',
    );
    _expectNonNegativeInt(
      issues,
      source['contractIssueCount'],
      'sourceExperimentPlan.contractIssueCount',
    );
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'sourceBatchCount',
      'runBatchCount',
      'maxRunBatches',
      'blockedReasonCount',
      'commandTemplateCount',
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
      'privatePathsOmitted': true,
      'concretePrivateEnvValuesOmitted': true,
      'providerModelIdsOmitted': true,
      'promptTextOmitted': true,
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
      'consumesExperimentPlanOnly': true,
      'tracesReRead': false,
      'privateCatalogsRead': false,
      'liveModelCallsStarted': false,
      'modelClassSelectorsOmitted': true,
      'profileSelectorsRequiredPrivately': true,
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
  }

  static void _validateRunBatches(
    List<String> issues,
    List<dynamic>? batches, {
    required Map<String, dynamic> sourcePlan,
  }) {
    if (batches == null) return;
    final planDigest = _string(sourcePlan['planDigest']);
    final sourceMatrixDigest = _string(sourcePlan['sourceMatrixDigest']);
    for (final (index, value) in batches.indexed) {
      final batch = _expectMap(issues, value, 'runBatches[$index]');
      if (batch == null) continue;
      _expectDigest(
        issues,
        batch['workOrderBatchRef'],
        'runBatches[$index].workOrderBatchRef',
      );
      _expectDigest(
        issues,
        batch['sourcePlanBatchRef'],
        'runBatches[$index].sourcePlanBatchRef',
      );
      _expectDigest(
        issues,
        batch['compatibilityKey'],
        'runBatches[$index].compatibilityKey',
      );
      final cellKeys = _expectStringList(
        issues,
        batch['sourceCellKeys'],
        'runBatches[$index].sourceCellKeys',
      );
      if (cellKeys != null) {
        for (final (cellIndex, cellKey) in cellKeys.indexed) {
          if (!EvalProvenance.isDigest(cellKey)) {
            issues.add(
              'runBatches[$index].sourceCellKeys[$cellIndex] must be a sha256 digest',
            );
          }
        }
      }
      final evidenceStatuses = _expectStringList(
        issues,
        batch['sourceEvidenceStatuses'],
        'runBatches[$index].sourceEvidenceStatuses',
      );
      if (evidenceStatuses != null && evidenceStatuses.isEmpty) {
        issues.add(
          'runBatches[$index].sourceEvidenceStatuses must not be empty',
        );
      }
      final objective = _expectNonEmptyString(
        issues,
        batch['objective'],
        'runBatches[$index].objective',
      );
      if (objective != null && !_allowedBatchObjectives.contains(objective)) {
        issues.add('runBatches[$index].objective must be supported');
      }
      _validateSelectorMap(
        issues,
        _expectMap(
          issues,
          batch['publicSelectors'],
          'runBatches[$index].publicSelectors',
        ),
        'runBatches[$index].publicSelectors',
      );
      final env = _expectMap(
        issues,
        batch['publicEnv'],
        'runBatches[$index].publicEnv',
      );
      _validatePublicEnv(issues, env, 'runBatches[$index].publicEnv');
      _validateWithheldInputs(
        issues,
        _expectMap(
          issues,
          batch['withheldInputs'],
          'runBatches[$index].withheldInputs',
        ),
        'runBatches[$index].withheldInputs',
      );
      _validateTemplateRefs(
        issues,
        _expectStringList(
          issues,
          batch['commandTemplateRefs'],
          'runBatches[$index].commandTemplateRefs',
        ),
        'runBatches[$index].commandTemplateRefs',
      );
      _expectStringList(
        issues,
        batch['blockedReasonCodes'],
        'runBatches[$index].blockedReasonCodes',
      );
      if (env != null && cellKeys != null) {
        final expectedRef = _workOrderBatchRef(
          planDigest: planDigest,
          sourceMatrixDigest: sourceMatrixDigest,
          sourcePlanBatchRef: _string(batch['sourcePlanBatchRef']),
          compatibilityKey: _string(batch['compatibilityKey']),
          sourceCellKeys: _sortedStrings(cellKeys),
          publicEnv: env,
        );
        if (batch['workOrderBatchRef'] != expectedRef) {
          issues.add(
            'runBatches[$index].workOrderBatchRef must bind source refs and public env',
          );
        }
      }
    }
  }

  static void _validateSelectorMap(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    for (final field in const ['capabilities', 'promptVariantNames']) {
      final values = _expectStringList(
        issues,
        selectors[field],
        '$path.$field',
      );
      if (values == null) continue;
      if (values.isEmpty) {
        issues.add('$path.$field must not be empty');
      }
      for (final value in values) {
        if (!_safeSelectorValue(value)) {
          issues.add('$path.$field contains unsafe selector values');
        }
      }
    }
    for (final field in selectors.keys) {
      if (field != 'capabilities' && field != 'promptVariantNames') {
        issues.add('$path must not contain unsupported selector $field');
      }
    }
  }

  static void _validatePublicEnv(
    List<String> issues,
    Map<String, dynamic>? env,
    String path,
  ) {
    if (env == null) return;
    for (final key in const [
      'EVAL_REQUIRED_CAPABILITIES',
      'EVAL_PROMPT_VARIANT_NAMES',
    ]) {
      if (!env.containsKey(key)) {
        issues.add('$path must contain $key');
      }
    }
    for (final entry in env.entries) {
      if (!_allowedPublicEnvKeys.contains(entry.key)) {
        issues.add('$path must not contain ${entry.key}');
      }
      if (_privateValueEnvKeys.contains(entry.key)) {
        issues.add('$path must not contain value-bearing ${entry.key}');
      }
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) {
        issues.add('$path.${entry.key} must be a non-empty string');
      } else if (!value.split(',').every(_safeSelectorValue)) {
        issues.add('$path.${entry.key} contains unsafe selector values');
      }
    }
  }

  static void _validateWithheldInputs(
    List<String> issues,
    Map<String, dynamic>? inputs,
    String path,
  ) {
    if (inputs == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'rawRunIdsOmitted': true,
      'privatePathsOmitted': true,
      'concretePrivateEnvValuesOmitted': true,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        inputs[entry.key],
        entry.value,
        '$path.${entry.key}',
      );
    }
  }

  static void _validateTemplateRefs(
    List<String> issues,
    List<String>? refs,
    String path,
  ) {
    if (refs == null) return;
    if (refs.isEmpty) issues.add('$path must not be empty');
    for (final ref in refs) {
      if (!_allowedTemplateRefs.contains(ref)) {
        issues.add('$path contains unsupported template ref $ref');
      }
    }
    if (!_sameStrings(refs, const ['plan', 'run', 'tune'])) {
      issues.add('$path must be exactly plan, run, tune');
    }
  }

  static void _validateCommandTemplates(
    List<String> issues,
    List<dynamic>? templates,
  ) {
    if (templates == null) return;
    final refs = <String>[];
    for (final (index, value) in templates.indexed) {
      final template = _expectMap(issues, value, 'commandTemplates[$index]');
      if (template == null) continue;
      _validateAllowedKeys(
        issues,
        template,
        _allowedCommandTemplateFields,
        'commandTemplates[$index]',
      );
      final ref = _expectNonEmptyString(
        issues,
        template['ref'],
        'commandTemplates[$index].ref',
      );
      if (ref != null && !_allowedTemplateRefs.contains(ref)) {
        issues.add('commandTemplates[$index].ref must be supported');
      }
      if (ref != null) refs.add(ref);
      final mode = _expectNonEmptyString(
        issues,
        template['mode'],
        'commandTemplates[$index].mode',
      );
      if (ref != null && mode != null && ref != mode) {
        issues.add('commandTemplates[$index].mode must match ref');
      }
      final commandTemplate = _expectNonEmptyString(
        issues,
        template['commandTemplate'],
        'commandTemplates[$index].commandTemplate',
      );
      if (ref != null && commandTemplate != null) {
        final expected = 'eval/run_level2.sh $ref <nextRunId>';
        if (commandTemplate != expected) {
          issues.add(
            'commandTemplates[$index].commandTemplate must be $expected',
          );
        }
        if (_shellSmugglingPattern.hasMatch(commandTemplate)) {
          issues.add(
            'commandTemplates[$index].commandTemplate must not contain shell wrappers or inline env',
          );
        }
      }
      final keys = _expectStringList(
        issues,
        template['allowedPublicEnvKeys'],
        'commandTemplates[$index].allowedPublicEnvKeys',
      );
      if (keys != null) {
        for (final key in keys) {
          if (!_allowedPublicEnvKeys.contains(key)) {
            issues.add(
              'commandTemplates[$index].allowedPublicEnvKeys contains unsupported key $key',
            );
          }
        }
      }
      if (template.containsKey('env')) {
        issues.add('commandTemplates[$index] must not contain env values');
      }
      if (template.containsKey('command')) {
        issues.add('commandTemplates[$index] must use commandTemplate only');
      }
      _expectEquals(
        issues,
        template['privateInputsRequired'],
        true,
        'commandTemplates[$index].privateInputsRequired',
      );
      _expectEquals(
        issues,
        template['valuesOmitted'],
        true,
        'commandTemplates[$index].valuesOmitted',
      );
    }
    if (refs.length != refs.toSet().length) {
      issues.add('commandTemplates refs must be unique');
    }
    if (!_sameStrings(refs, const ['plan', 'run', 'tune'])) {
      issues.add('commandTemplates refs must be exactly plan, run, tune');
    }
  }

  static void _validateAdversarialReviewQueue(
    List<String> issues,
    Map<String, dynamic>? queue, {
    required Map<String, dynamic>? sourcePlan,
    required List<String>? blockedCodes,
    required List<dynamic>? runBatches,
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
    _validateReviewSummary(issues, summary);
    final tasks = _expectList(
      issues,
      queue['tasks'],
      'adversarialReviewQueue.tasks',
    );
    _validateReviewTasks(
      issues,
      tasks,
      sourcePlan: sourcePlan,
      blockedCodes: blockedCodes,
      runBatches: runBatches,
    );
    _validateReviewSummaryInvariants(
      issues,
      summary: summary,
      tasks: tasks,
    );
    _validateReviewGuards(
      issues,
      _expectMap(issues, queue['guards'], 'adversarialReviewQueue.guards'),
    );
  }

  static void _validateReviewSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'taskCount',
      'pendingTaskCount',
      'requiredTaskCount',
      'completedTaskCount',
    ]) {
      _expectNonNegativeInt(
        issues,
        summary[field],
        'adversarialReviewQueue.summary.$field',
      );
    }
    if (summary['completedTaskCount'] != 0) {
      issues.add(
        'adversarialReviewQueue.summary.completedTaskCount must be 0',
      );
    }
  }

  static void _validateReviewSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<dynamic>? tasks,
  }) {
    if (summary == null || tasks == null) return;
    if (summary['taskCount'] is int && summary['taskCount'] != tasks.length) {
      issues.add(
        'adversarialReviewQueue.summary.taskCount must match tasks.length',
      );
    }
    if (summary['pendingTaskCount'] is int &&
        summary['pendingTaskCount'] != tasks.length) {
      issues.add(
        'adversarialReviewQueue.summary.pendingTaskCount must match tasks.length',
      );
    }
    if (summary['requiredTaskCount'] is int &&
        summary['requiredTaskCount'] != tasks.length) {
      issues.add(
        'adversarialReviewQueue.summary.requiredTaskCount must match tasks.length',
      );
    }
  }

  static void _validateReviewTasks(
    List<String> issues,
    List<dynamic>? tasks, {
    required Map<String, dynamic>? sourcePlan,
    required List<String>? blockedCodes,
    required List<dynamic>? runBatches,
  }) {
    if (tasks == null) return;
    final expectedTasks = _expectedReviewTasks(
      sourcePlan: sourcePlan,
      blockedCodes: blockedCodes,
      runBatches: runBatches,
    );
    final seenCategories = <String>{};
    for (final (index, value) in tasks.indexed) {
      final path = 'adversarialReviewQueue.tasks[$index]';
      final task = _expectMap(issues, value, path);
      if (task == null) continue;
      _expectDigest(issues, task['reviewRef'], '$path.reviewRef');
      final category = _expectNonEmptyString(
        issues,
        task['category'],
        '$path.category',
      );
      if (category != null && !_allowedReviewCategories.contains(category)) {
        issues.add('$path.category must be supported');
      }
      if (category != null && !seenCategories.add(category)) {
        issues.add('adversarialReviewQueue.tasks categories must be unique');
      }
      _expectEquals(issues, task['status'], 'pending', '$path.status');
      _expectEquals(issues, task['required'], true, '$path.required');
      _expectEquals(
        issues,
        task['requiredBefore'],
        'runExecution',
        '$path.requiredBefore',
      );
      _validateReviewSourceRefs(
        issues,
        _expectMap(issues, task['sourceRefs'], '$path.sourceRefs'),
        path,
      );
      final mustCheck = _expectStringList(
        issues,
        task['mustCheck'],
        '$path.mustCheck',
      );
      if (mustCheck != null && mustCheck.isEmpty) {
        issues.add('$path.mustCheck must not be empty');
      }
      _expectEquals(
        issues,
        task['privateValuesOmitted'],
        true,
        '$path.privateValuesOmitted',
      );
      _expectEquals(
        issues,
        task['completionEvidenceOmitted'],
        true,
        '$path.completionEvidenceOmitted',
      );
      for (final field in _reviewExecutableFields) {
        if (task.containsKey(field)) {
          issues.add('$path must not contain executable field $field');
        }
      }
      if (task.containsKey('completionEvidence')) {
        issues.add('$path must not contain completionEvidence');
      }
      for (final field in _reviewCompletionClaimFields) {
        if (task.containsKey(field)) {
          issues.add('$path must not claim review completion via $field');
        }
      }
      final expected = category == null ? null : expectedTasks[category];
      if (expected != null) {
        if (task['reviewRef'] != expected['reviewRef']) {
          issues.add('$path.reviewRef must bind work-order review sources');
        }
        if (!_sameJsonMaps(
          _map(task['sourceRefs']),
          _map(expected['sourceRefs']),
        )) {
          issues.add('$path.sourceRefs must match work-order review sources');
        }
        if (!_sameStrings(
          _stringList(task['mustCheck']),
          _stringList(expected['mustCheck']),
        )) {
          issues.add('$path.mustCheck must match work-order review checklist');
        }
      }
    }
    if (!_sameStrings(
      seenCategories.toList()..sort(),
      _allowedReviewCategories.toList()..sort(),
    )) {
      issues.add(
        'adversarialReviewQueue.tasks categories must match required audits',
      );
    }
  }

  static void _validateReviewSourceRefs(
    List<String> issues,
    Map<String, dynamic>? refs,
    String taskPath,
  ) {
    if (refs == null) return;
    _expectDigest(
      issues,
      refs['sourcePlanDigest'],
      '$taskPath.sourceRefs.sourcePlanDigest',
    );
    _expectDigest(
      issues,
      refs['sourceMatrixDigest'],
      '$taskPath.sourceRefs.sourceMatrixDigest',
    );
    _expectStringList(
      issues,
      refs['workOrderBatchRefs'],
      '$taskPath.sourceRefs.workOrderBatchRefs',
    );
    _expectStringList(
      issues,
      refs['blockedReasonCodes'],
      '$taskPath.sourceRefs.blockedReasonCodes',
    );
  }

  static Map<String, Map<String, dynamic>> _expectedReviewTasks({
    required Map<String, dynamic>? sourcePlan,
    required List<String>? blockedCodes,
    required List<dynamic>? runBatches,
  }) {
    if (sourcePlan == null || blockedCodes == null || runBatches == null) {
      return const {};
    }
    final tasks =
        [
          for (final category in _allowedReviewCategories)
            _adversarialReviewTask(
              category: category,
              sourcePlanDigest: _string(sourcePlan['planDigest']),
              sourceMatrixDigest: _string(sourcePlan['sourceMatrixDigest']),
              blockedCodes: _sortedStrings(blockedCodes),
              runBatches: _mapList(runBatches),
            ),
        ]..sort(
          (a, b) => _string(a['category']).compareTo(_string(b['category'])),
        );
    return {
      for (final task in tasks) _string(task['category']): task,
    };
  }

  static void _validateReviewGuards(
    List<String> issues,
    Map<String, dynamic>? guards,
  ) {
    if (guards == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'rawRunIdsOmitted': true,
      'privatePathsOmitted': true,
      'concretePrivateEnvValuesOmitted': true,
      'reviewCompletionClaimsOmitted': true,
      'promotionClaimsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        guards[entry.key],
        entry.value,
        'adversarialReviewQueue.guards.${entry.key}',
      );
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<String>? blockedCodes,
    required List<dynamic>? runBatches,
    required List<dynamic>? commandTemplates,
  }) {
    if (summary == null) return;
    if (runBatches != null &&
        summary['runBatchCount'] is int &&
        summary['runBatchCount'] != runBatches.length) {
      issues.add('summary.runBatchCount must match runBatches.length');
    }
    if (blockedCodes != null &&
        summary['blockedReasonCount'] is int &&
        summary['blockedReasonCount'] != blockedCodes.length) {
      issues.add(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      );
    }
    if (commandTemplates != null &&
        summary['commandTemplateCount'] is int &&
        summary['commandTemplateCount'] != commandTemplates.length) {
      issues.add(
        'summary.commandTemplateCount must match commandTemplates.length',
      );
    }
  }

  static void _validateStatusInvariants(
    List<String> issues, {
    required String? status,
    required Map<String, dynamic>? summary,
    required Map<String, dynamic>? sourcePlan,
    required List<dynamic>? runBatches,
  }) {
    if (status == null || runBatches == null) return;
    if (status == 'ready' && runBatches.isEmpty) {
      issues.add('runBatches must not be empty when status is ready');
    }
    if (status != 'ready' && runBatches.isNotEmpty) {
      issues.add('runBatches must be empty when status is $status');
    }
    final derivedStatus = _derivedStatus(
      sourcePlan: sourcePlan,
      runBatchCount: runBatches.length,
    );
    if (derivedStatus != null && status != derivedStatus) {
      issues.add('status must match source experiment plan and run batches');
    }
    if (summary != null &&
        sourcePlan != null &&
        summary['sourceBatchCount'] is int &&
        summary['sourceBatchCount'] != sourcePlan['sourceBatchCount']) {
      issues.add(
        'summary.sourceBatchCount must match sourceExperimentPlan.sourceBatchCount',
      );
    }
  }

  static String? _derivedStatus({
    required Map<String, dynamic>? sourcePlan,
    required int runBatchCount,
  }) {
    if (sourcePlan == null) return null;
    final contractIssueCount = _intOrZero(sourcePlan['contractIssueCount']);
    final planStatus = _string(sourcePlan['status']);
    final sourceBatchCount = _intOrZero(sourcePlan['sourceBatchCount']);
    if (contractIssueCount > 0 || planStatus == 'invalid') {
      return 'invalidPlan';
    }
    if (planStatus == 'noRunnableBatches') return 'noRunnableBatches';
    if (planStatus != 'ready') return 'blockedPlan';
    if (sourceBatchCount == 0 || runBatchCount == 0) {
      return 'noRunnableBatches';
    }
    return 'ready';
  }

  static void _validateWorkOrderRef(
    List<String> issues,
    Map<String, dynamic> workOrder,
  ) {
    final expectedRef = workOrderRef(workOrder);
    if (workOrder['workOrderRef'] != expectedRef) {
      issues.add('workOrderRef must match next-run work-order subject');
    }
  }

  static Map<String, dynamic> _workOrderSubject(
    Map<String, dynamic> workOrder,
  ) => <String, dynamic>{
    'kind': kind,
    'schemaVersion': schemaVersion,
    'status': _string(workOrder['status']),
    'sourceExperimentPlanDigest': EvalProvenance.digestJson(
      _map(workOrder['sourceExperimentPlan']),
    ),
    'summaryDigest': EvalProvenance.digestJson(_map(workOrder['summary'])),
    'privacyDigest': EvalProvenance.digestJson(_map(workOrder['privacy'])),
    'limitationsDigest': EvalProvenance.digestJson(
      _map(workOrder['limitations']),
    ),
    'blockedReasonCodesDigest': EvalProvenance.digestJson(
      _stringList(workOrder['blockedReasonCodes']),
    ),
    'runBatchesDigest': EvalProvenance.digestJson(
      _mapList(workOrder['runBatches']),
    ),
    'commandTemplatesDigest': EvalProvenance.digestJson(
      _mapList(workOrder['commandTemplates']),
    ),
    'adversarialReviewQueueDigest': EvalProvenance.digestJson(
      _map(workOrder['adversarialReviewQueue']),
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
        if (_privateValueEnvKeys.contains(key)) {
          issues.add('$path.$key must not expose private env values');
        }
        final privateFieldReason = _privateFieldReason(normalized);
        if (privateFieldReason != null) {
          issues.add('$path.$key must not expose $privateFieldReason');
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
      if (value.contains('<redacted-scenario')) {
        issues.add('$path must not contain redacted scenario placeholders');
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
    if (normalized == 'path' ||
        normalized.endsWith('path') ||
        normalized.contains('tracepath') ||
        normalized.contains('verdictpath')) {
      return 'private paths';
    }
    if (normalized == 'prompttext' ||
        normalized == 'systemprompt' ||
        normalized == 'developerprompt' ||
        normalized == 'directivetext' ||
        normalized == 'rawprompt') {
      return 'raw prompt text';
    }
    if (normalized == 'providerid' ||
        normalized == 'providermodelid' ||
        normalized == 'modelid' ||
        normalized == 'apiurl' ||
        normalized == 'baseurl' ||
        normalized == 'apibaseurl' ||
        normalized == 'apikey') {
      return 'provider or model ids';
    }
    return null;
  }

  static bool _safeSelectorValue(String value) {
    return value.trim().isNotEmpty &&
        _safeSelectorPattern.hasMatch(value) &&
        !_opaqueFallbackPattern.hasMatch(value);
  }

  static List<String> _safeSelectorValues(Iterable<String> values) {
    return _sortedStrings(values.where(_safeSelectorValue));
  }

  static bool _sameStrings(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index += 1) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }

  static bool _sameJsonMaps(
    Map<String, dynamic> actual,
    Map<String, dynamic> expected,
  ) => EvalProvenance.digestJson(actual) == EvalProvenance.digestJson(expected);

  static int _intOrZero(Object? value) => value is int ? value : 0;

  static void _validateAllowedKeys(
    List<String> issues,
    Map<String, dynamic> value,
    Set<String> allowedKeys,
    String path,
  ) {
    for (final key in value.keys) {
      if (!allowedKeys.contains(key)) {
        issues.add('$path must not contain unsupported field $key');
      }
    }
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

List<String> _sortedStrings(Iterable<String> values) {
  final sorted =
      values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();
  return sorted;
}
