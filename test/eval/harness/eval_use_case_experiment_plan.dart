import 'eval_provenance.dart';
import 'eval_use_case_tuning_matrix.dart';

abstract final class EvalUseCaseExperimentPlan {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalUseCaseExperimentPlan';
  static const _allowedStatuses = {
    'invalid',
    'incompatible',
    'blocked',
    'noRunnableBatches',
    'ready',
  };
  static const _runnableMatrixStatuses = {
    'diagnosticOnly',
    'dataDeficient',
  };
  static const _allowedHandoffStatuses = {
    'readyForBatchExecution',
    'manualWorkRequired',
    'invalid',
  };
  static const _allowedReviewCategories = {
    'privacyAudit',
    'commandSafetyAudit',
    'selectorSafetyAudit',
    'evidenceSufficiencyAudit',
    'holdoutCatalogGovernanceAudit',
    'calibrationReliabilityAudit',
    'pairwiseReliabilityAudit',
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
    'env',
    'nextRunEnv',
    'recommendedCommands',
    'shell',
    'shellCommand',
  };
  static const _allowedTemplateModes = {
    'catalog',
    'template',
    'calibrate',
    'grade',
    'report',
    'use-case-matrix',
    'experiment-plan',
  };
  static const _liveCommandModes = {'plan', 'run', 'tune', 'all'};
  static const _allowedRecommendedCommandModes = {
    'experiment-plan',
    'next-run-work-order',
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
  };
  static final _safeSelectorPattern = RegExp(r'^[A-Za-z0-9_.:-]+$');
  static final _safeEnvKeyPattern = RegExp(r'^[A-Z][A-Z0-9_]*$');
  static final _opaqueFallbackPattern = RegExp(
    r'^(capability|agent|model|prompt|recommendation|blocker)-[0-9a-f]{12}$',
  );
  static final _liveRunLevel2CommandPattern = RegExp(
    r'(?:^|[^A-Za-z0-9_./-])(?:\./)?eval/run_level2\.sh\s+'
    r'(?:plan|run|tune|all)(?=$|[^A-Za-z0-9_-])',
  );
  static final _privatePathPattern = RegExp(
    r'(?:^|\s|=)/(?:Users|private|var|tmp|Volumes)/',
  );
  static final _privateEnvTokenPattern = RegExp(
    r'\b(?:EVAL_SCENARIO_IDS|EVAL_PROFILE_NAMES|EVAL_PROFILES|'
    'EVAL_SCENARIOS|EVAL_RUNS_ROOT|EVAL_CALIBRATION|'
    r'EVAL_CALIBRATION_TEMPLATE|EVAL_PAIRWISE_[A-Z0-9_]+)\b',
  );
  static final _profileFieldTokenPattern = RegExp(
    r'\b(?:profileName|profileNames|[A-Za-z0-9_]*ProfileNames)\b',
  );
  static final _scenarioFieldTokenPattern = RegExp(
    r'\b(?:scenarioId|scenarioIds|[A-Za-z0-9_]*ScenarioIds)\b',
  );

  static Map<String, dynamic> build({
    required Map<String, dynamic> matrix,
    DateTime? generatedAt,
    int maxBatches = 6,
    int maxCellsPerBatch = 1,
  }) {
    final boundedMaxBatches = maxBatches < 1 ? 0 : maxBatches;
    final boundedMaxCellsPerBatch = maxCellsPerBatch < 1 ? 0 : maxCellsPerBatch;
    final matrixIssues = EvalUseCaseTuningMatrix.validate(matrix);
    final groups = _mapList(matrix['compatibilityGroups']);
    final matrixStatus = _string(matrix['status']);
    final matrixDigest = EvalProvenance.digestJson(matrix);
    final batches = matrixIssues.isEmpty
        ? _batches(
            groups: groups,
            matrixStatus: matrixStatus,
            maxBatches: boundedMaxBatches,
            maxCellsPerBatch: boundedMaxCellsPerBatch,
          )
        : const <Map<String, dynamic>>[];
    final status = _status(
      matrixIssues: matrixIssues,
      matrixStatus: matrixStatus,
      groups: groups,
      batches: batches,
    );
    final blockedCodes = _blockedReasonCodes(
      matrix: matrix,
      matrixIssues: matrixIssues,
      groups: groups,
      batches: batches,
      status: status,
    );
    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'sourceMatrix': <String, dynamic>{
        'kind': EvalUseCaseTuningMatrix.kind,
        'schemaVersion': EvalUseCaseTuningMatrix.schemaVersion,
        'status': matrixStatus.isEmpty ? 'unknown' : matrixStatus,
        'matrixDigest': matrixDigest,
        'contractIssueCount': matrixIssues.length,
        'compatibilityGroupCount': groups.length,
      },
      'summary': <String, dynamic>{
        'batchCount': batches.length,
        'maxBatches': boundedMaxBatches,
        'maxCellsPerBatch': boundedMaxCellsPerBatch,
        'blockedReasonCount': blockedCodes.length,
      },
      'privacy': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'rawRunIdsOmitted': true,
        'promotionClaimsCreated': false,
        'matrixOnly': true,
      },
      'limitations': const <String, dynamic>{
        'consumesUseCaseMatrixOnly': true,
        'tracesReRead': false,
        'catalogGovernanceReRun': false,
        'humanLabelsCreated': false,
        'promotionClaimsCreated': false,
      },
      'blockedReasonCodes': blockedCodes,
      'manualPrerequisites': [
        for (final code in blockedCodes)
          <String, dynamic>{
            'code': code,
            'action': _manualAction(code),
          },
      ],
      'operatorHandoff': _operatorHandoff(
        status: status,
        blockedCodes: blockedCodes,
        batches: batches,
      ),
      'adversarialReviewQueue': _adversarialReviewQueue(
        status: status,
        matrixDigest: matrixDigest,
        blockedCodes: blockedCodes,
        batches: batches,
      ),
      'batches': batches,
      'recommendedCommands': _recommendedCommands(),
    };
    assertValid(artifact);
    return artifact;
  }

  static List<String> validate(Map<String, dynamic> plan) {
    final issues = <String>[];
    _expectEquals(
      issues,
      plan['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _expectEquals(issues, plan['kind'], kind, 'kind');
    _expectIsoDate(issues, plan['generatedAt'], 'generatedAt');
    final status = _expectNonEmptyString(issues, plan['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    _validateSourceMatrix(
      issues,
      _expectMap(issues, plan['sourceMatrix'], 'sourceMatrix'),
    );
    final summary = _expectMap(issues, plan['summary'], 'summary');
    _validateSummary(issues, summary);
    _validatePrivacy(issues, _expectMap(issues, plan['privacy'], 'privacy'));
    _validateLimitations(
      issues,
      _expectMap(issues, plan['limitations'], 'limitations'),
    );
    final blockedReasonCodes = _expectStringList(
      issues,
      plan['blockedReasonCodes'],
      'blockedReasonCodes',
    );
    _validatePlanItems(
      issues,
      _expectList(issues, plan['manualPrerequisites'], 'manualPrerequisites'),
      'manualPrerequisites',
    );
    final operatorHandoff = _expectMap(
      issues,
      plan['operatorHandoff'],
      'operatorHandoff',
    );
    _validateOperatorHandoff(issues, operatorHandoff);
    final adversarialReviewQueue = _expectMap(
      issues,
      plan['adversarialReviewQueue'],
      'adversarialReviewQueue',
    );
    _validateAdversarialReviewQueue(issues, adversarialReviewQueue);
    final batches = _expectList(issues, plan['batches'], 'batches');
    _validateBatches(issues, batches);
    final commands = _expectList(
      issues,
      plan['recommendedCommands'],
      'recommendedCommands',
    );
    _validateCommands(issues, commands, 'recommendedCommands');
    _validateSummaryInvariants(
      issues,
      summary: summary,
      blockedReasonCodes: blockedReasonCodes,
      batches: batches,
    );
    _validateStatusInvariants(
      issues,
      status: status,
      batches: batches,
      operatorHandoff: operatorHandoff,
    );
    _validateNoPrivatePayloads(issues, plan, 'plan');
    return issues;
  }

  static void assertValid(Map<String, dynamic> plan) {
    final issues = validate(plan);
    if (issues.isEmpty) return;
    throw StateError(
      'Invalid use-case experiment plan:\n${issues.join('\n')}',
    );
  }

  static String _status({
    required List<String> matrixIssues,
    required String matrixStatus,
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> batches,
  }) {
    if (matrixIssues.isNotEmpty || matrixStatus == 'invalid') return 'invalid';
    if (groups.length > 1 || matrixStatus == 'incompatible') {
      return 'incompatible';
    }
    if (!_runnableMatrixStatuses.contains(matrixStatus)) return 'blocked';
    if (batches.isEmpty) return 'noRunnableBatches';
    return 'ready';
  }

  static List<Map<String, dynamic>> _batches({
    required List<Map<String, dynamic>> groups,
    required String matrixStatus,
    required int maxBatches,
    required int maxCellsPerBatch,
  }) {
    if (groups.length != 1 || !_runnableMatrixStatuses.contains(matrixStatus)) {
      return const <Map<String, dynamic>>[];
    }
    if (maxBatches < 1 || maxCellsPerBatch < 1) {
      return const <Map<String, dynamic>>[];
    }
    final group = groups.single;
    final cells = [
      for (final cell in _mapList(group['matrixCells']))
        if (_runnableCell(cell)) cell,
    ];
    final selectedCells = _stratifiedRunnableCells(
      cells: cells,
      maxCells: maxBatches * maxCellsPerBatch,
    );
    final batches = <Map<String, dynamic>>[];
    for (
      var index = 0;
      index < selectedCells.length && batches.length < maxBatches;
    ) {
      final selected = selectedCells
          .skip(index)
          .take(maxCellsPerBatch)
          .toList();
      index += selected.length;
      if (selected.isEmpty) break;
      final batch = _batch(
        group: group,
        cells: selected,
        batchIndex: batches.length,
      );
      if (batch != null) batches.add(batch);
    }
    return batches;
  }

  static List<Map<String, dynamic>> _stratifiedRunnableCells({
    required List<Map<String, dynamic>> cells,
    required int maxCells,
  }) {
    final sorted = [...cells]
      ..sort((a, b) => _string(a['cellKey']).compareTo(_string(b['cellKey'])));
    if (maxCells >= sorted.length) return sorted;
    if (maxCells < 1) return const <Map<String, dynamic>>[];

    final requiredStrata = <String>{
      for (final cell in sorted) ..._selectionStrata(cell),
    };
    final selected = <Map<String, dynamic>>[];
    final selectedKeys = <String>{};
    final covered = <String>{};

    void addCell(Map<String, dynamic> cell) {
      selected.add(cell);
      selectedKeys.add(_string(cell['cellKey']));
      covered.addAll(_selectionStrata(cell));
    }

    while (selected.length < maxCells && !covered.containsAll(requiredStrata)) {
      final token = _nextSelectionStratum(requiredStrata.difference(covered));
      final eligible = [
        for (final cell in sorted)
          if (!selectedKeys.contains(_string(cell['cellKey'])) &&
              _selectionStrata(cell).contains(token))
            cell,
      ];
      if (eligible.isEmpty) break;
      eligible.sort((a, b) {
        final uncovered = requiredStrata.difference(covered);
        final aCoverage = _selectionStrata(a).intersection(uncovered).length;
        final bCoverage = _selectionStrata(b).intersection(uncovered).length;
        final byCoverage = bCoverage.compareTo(aCoverage);
        if (byCoverage != 0) return byCoverage;
        return _string(a['cellKey']).compareTo(_string(b['cellKey']));
      });
      addCell(eligible.first);
    }

    for (final cell in sorted) {
      if (selected.length >= maxCells) break;
      if (selectedKeys.contains(_string(cell['cellKey']))) continue;
      addCell(cell);
    }
    return selected;
  }

  static Set<String> _selectionStrata(Map<String, dynamic> cell) {
    final capability = _string(cell['primaryCapabilityId']);
    final agentKind = _string(cell['agentKind']);
    final modelClass = _string(cell['modelClass']);
    final promptVariant = _string(cell['promptVariantName']);
    final evidenceStatus = _string(cell['evidenceStatus']);
    final blockerFamilies = _stringList(cell['blockingReasonCodes']).isEmpty
        ? const {'none'}
        : {
            for (final code in _stringList(cell['blockingReasonCodes']))
              _blockerFamily(code),
          };
    return <String>{
      if (capability.isNotEmpty) 'primaryCapability:$capability',
      if (modelClass.isNotEmpty) 'modelClass:$modelClass',
      if (promptVariant.isNotEmpty) 'promptVariant:$promptVariant',
      if (evidenceStatus.isNotEmpty) 'evidenceStatus:$evidenceStatus',
      if (agentKind.isNotEmpty) 'agentKind:$agentKind',
      for (final blockerFamily in blockerFamilies)
        'blockerFamily:$blockerFamily',
      if (capability.isNotEmpty && evidenceStatus.isNotEmpty)
        'capabilityStatus:$capability@$evidenceStatus',
      if (modelClass.isNotEmpty && evidenceStatus.isNotEmpty)
        'modelClassStatus:$modelClass@$evidenceStatus',
      if (promptVariant.isNotEmpty && evidenceStatus.isNotEmpty)
        'promptVariantStatus:$promptVariant@$evidenceStatus',
      if (modelClass.isNotEmpty && capability.isNotEmpty)
        'modelClassCapability:$modelClass@$capability',
      if (modelClass.isNotEmpty && promptVariant.isNotEmpty)
        'modelClassPrompt:$modelClass@$promptVariant',
      if (capability.isNotEmpty && promptVariant.isNotEmpty)
        'capabilityPrompt:$capability@$promptVariant',
      for (final blockerFamily in blockerFamilies)
        if (capability.isNotEmpty)
          'capabilityBlocker:$capability@$blockerFamily',
    };
  }

  static String _nextSelectionStratum(Set<String> uncovered) {
    final ordered = uncovered.toList()
      ..sort((a, b) {
        final byPriority = _selectionStratumPriority(
          a,
        ).compareTo(_selectionStratumPriority(b));
        if (byPriority != 0) return byPriority;
        return a.compareTo(b);
      });
    return ordered.first;
  }

  static int _selectionStratumPriority(String stratum) {
    if (stratum.startsWith('primaryCapability:')) return 0;
    if (stratum.startsWith('modelClass:')) return 1;
    if (stratum.startsWith('promptVariant:')) return 2;
    if (stratum.startsWith('evidenceStatus:')) return 3;
    if (stratum.startsWith('blockerFamily:')) return 4;
    if (stratum.startsWith('agentKind:')) return 5;
    if (stratum.startsWith('capabilityStatus:')) return 6;
    if (stratum.startsWith('modelClassStatus:')) return 7;
    if (stratum.startsWith('promptVariantStatus:')) return 8;
    if (stratum.startsWith('modelClassCapability:')) return 9;
    if (stratum.startsWith('modelClassPrompt:')) return 10;
    if (stratum.startsWith('capabilityPrompt:')) return 11;
    if (stratum.startsWith('capabilityBlocker:')) return 12;
    return 13;
  }

  static String _blockerFamily(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('calibration') || normalized.contains('human')) {
      return 'calibration';
    }
    if (normalized.contains('pairwise')) return 'pairwise';
    if (normalized.contains('verdict') || normalized.contains('judge')) {
      return 'verdict';
    }
    if (normalized.contains('holdout') ||
        normalized.contains('catalog') ||
        normalized.contains('protected') ||
        normalized.contains('source')) {
      return 'catalog';
    }
    if (normalized.contains('review') ||
        normalized.contains('adversarial') ||
        normalized.contains('synthetic')) {
      return 'review';
    }
    if (normalized.contains('coverage') ||
        normalized.contains('capability') ||
        normalized.contains('scenario') ||
        normalized.contains('trial')) {
      return 'coverage';
    }
    final family = normalized.split('.').first;
    return family.isEmpty ? 'other' : family;
  }

  static bool _runnableCell(Map<String, dynamic> cell) {
    final status = _string(cell['evidenceStatus']);
    if (status != 'diagnosticOnly' && status != 'dataDeficient') return false;
    return _safeSelectorValue(_string(cell['primaryCapabilityId'])) &&
        _safeSelectorValue(_string(cell['promptVariantName']));
  }

  static Map<String, dynamic>? _batch({
    required Map<String, dynamic> group,
    required List<Map<String, dynamic>> cells,
    required int batchIndex,
  }) {
    final capabilities = _safeSelectorValues(
      cells.map((cell) => _string(cell['primaryCapabilityId'])),
    );
    final promptVariants = _safeSelectorValues(
      cells.map((cell) => _string(cell['promptVariantName'])),
    );
    if (capabilities.isEmpty || promptVariants.isEmpty) return null;
    final cellKeys = _sortedStrings(
      cells.map((cell) => _string(cell['cellKey'])),
    );
    final evidenceStatuses = _sortedStrings(
      cells.map((cell) => _string(cell['evidenceStatus'])),
    );
    final blockerCodes = _sortedStrings({
      for (final cell in cells) ..._stringList(cell['blockingReasonCodes']),
    });
    final env = <String, dynamic>{
      'EVAL_REQUIRED_CAPABILITIES': capabilities.join(','),
      'EVAL_PROMPT_VARIANT_NAMES': promptVariants.join(','),
    };
    final batchRef = EvalProvenance.digestJson(<String, dynamic>{
      'compatibilityKey': _string(group['compatibilityKey']),
      'cellKeys': cellKeys,
      'batchIndex': batchIndex,
    });
    final status = evidenceStatuses.contains('dataDeficient')
        ? 'collectData'
        : 'collectPromotionEvidence';
    return <String, dynamic>{
      'batchRef': batchRef,
      'compatibilityKey': _string(group['compatibilityKey']),
      'status': status,
      'sourceCellKeys': cellKeys,
      'sourceReportRefs': _sortedStrings(
        cells.map((cell) => _string(cell['reportRef'])),
      ),
      'evidenceStatuses': evidenceStatuses,
      'blockedReasonCodes': blockerCodes,
      'safeSelectors': <String, dynamic>{
        'capabilities': capabilities,
        'promptVariantNames': promptVariants,
      },
      'withheldSelectors': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'reason': 'scenario ids and profile names must be chosen privately',
      },
      'nextRunEnv': env,
      'manualPrerequisites': [
        for (final code in blockerCodes)
          <String, dynamic>{
            'code': code,
            'action': _manualAction(code),
          },
      ],
      'recommendedCommands': _recommendedCommands(),
    };
  }

  static List<String> _blockedReasonCodes({
    required Map<String, dynamic> matrix,
    required List<String> matrixIssues,
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> batches,
    required String status,
  }) {
    return _sortedStrings({
      if (matrixIssues.isNotEmpty) 'matrix.contractInvalid',
      if (status == 'incompatible') 'matrix.incompatible',
      if (status == 'noRunnableBatches') 'experiment.noSafeRunnableSelectors',
      ..._stringList(matrix['blockedReasonCodes']),
      ..._stringList(_map(matrix['nextExperimentPlan'])['blockedReasonCodes']),
      for (final group in groups)
        for (final gap in _mapList(group['evidenceGaps']))
          ..._stringList(gap['blockerCodes']),
      for (final group in groups)
        for (final cell in _mapList(group['matrixCells']))
          ..._stringList(cell['blockingReasonCodes']),
      for (final batch in batches) ..._stringList(batch['blockedReasonCodes']),
    });
  }

  static List<Map<String, dynamic>> _recommendedCommands() {
    return const [
      <String, dynamic>{
        'mode': 'experiment-plan',
        'command': 'eval/run_level2.sh experiment-plan',
      },
      <String, dynamic>{
        'mode': 'next-run-work-order',
        'command': 'eval/run_level2.sh next-run-work-order',
      },
    ];
  }

  static String _manualAction(String code) {
    final normalized = code.toLowerCase();
    if (normalized.contains('contract')) return 'regenerateMatrix';
    if (normalized.contains('compatibility')) return 'compareWithinGroup';
    if (normalized.contains('calibration') || normalized.contains('human')) {
      return 'completeHumanCalibration';
    }
    if (normalized.contains('pairwise')) return 'completePairwiseReview';
    if (normalized.contains('verdict') || normalized.contains('judge')) {
      return 'gradeMissingVerdicts';
    }
    if (normalized.contains('holdout') ||
        normalized.contains('catalog') ||
        normalized.contains('adversarial') ||
        normalized.contains('source')) {
      return 'runCatalogPreflight';
    }
    if (normalized.contains('review')) return 'completeScenarioReviewMetadata';
    if (normalized.contains('coverage') || normalized.contains('capability')) {
      return 'addRequiredCapabilityCoverage';
    }
    return 'collectMissingEvidence';
  }

  static Map<String, dynamic> _operatorHandoff({
    required String status,
    required List<String> blockedCodes,
    required List<Map<String, dynamic>> batches,
  }) {
    final actions = [
      for (final code in blockedCodes)
        <String, dynamic>{
          'code': code,
          'action': _manualAction(code),
          'requiresPrivateInput': true,
          'valuesOmitted': true,
          'commandTemplateRefs': _templateRefsForAction(_manualAction(code)),
        },
    ];
    final templateRefs = _sortedStrings({
      for (final action in actions)
        ..._stringList(action['commandTemplateRefs']),
      if (actions.isEmpty) 'experiment-plan',
    });
    final capabilities = _safeSelectorValues(
      batches.expand((batch) {
        final selectors = _map(batch['safeSelectors']);
        return _stringList(selectors['capabilities']);
      }),
    );
    final promptVariantNames = _safeSelectorValues(
      batches.expand((batch) {
        final selectors = _map(batch['safeSelectors']);
        return _stringList(selectors['promptVariantNames']);
      }),
    );
    return <String, dynamic>{
      'status': switch (status) {
        'ready' => 'readyForBatchExecution',
        'invalid' => 'invalid',
        _ => 'manualWorkRequired',
      },
      'safePublicSelectors': <String, dynamic>{
        'capabilities': capabilities,
        'promptVariantNames': promptVariantNames,
      },
      'privateInputs': const [
        <String, dynamic>{
          'kind': 'scenarioCatalogOrSelection',
          'required': true,
          'valueOmitted': true,
          'envKeys': ['EVAL_SCENARIOS', 'EVAL_SCENARIOS_MODE'],
        },
        <String, dynamic>{
          'kind': 'profileCatalogOrSelection',
          'required': true,
          'valueOmitted': true,
          'envKeys': ['EVAL_PROFILES', 'EVAL_PROFILE_NAMES'],
        },
        <String, dynamic>{
          'kind': 'runArtifactLocation',
          'required': true,
          'valueOmitted': true,
          'envKeys': ['EVAL_RUNS_ROOT'],
        },
      ],
      'actions': actions,
      'commandTemplates': [
        for (final ref in templateRefs) _commandTemplate(ref),
      ],
      'guards': const <String, dynamic>{
        'scenarioIdsOmitted': true,
        'profileNamesOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'liveRunCommandsOmitted': true,
        'promotionClaimsCreated': false,
      },
    };
  }

  static Map<String, dynamic> _adversarialReviewQueue({
    required String status,
    required String matrixDigest,
    required List<String> blockedCodes,
    required List<Map<String, dynamic>> batches,
  }) {
    final requiredBefore = status == 'ready'
        ? 'batchExecution'
        : 'manualPrerequisiteResolution';
    final categories = <String>{
      'privacyAudit',
      'commandSafetyAudit',
      'selectorSafetyAudit',
      'evidenceSufficiencyAudit',
      if (blockedCodes.any(_catalogGovernanceBlocker))
        'holdoutCatalogGovernanceAudit',
      if (blockedCodes.any(_calibrationBlocker)) 'calibrationReliabilityAudit',
      if (blockedCodes.any(_pairwiseBlocker)) 'pairwiseReliabilityAudit',
    };
    final tasks =
        [
          for (final category in categories)
            _adversarialReviewTask(
              category: category,
              requiredBefore: requiredBefore,
              matrixDigest: matrixDigest,
              blockedCodes: blockedCodes,
              batches: batches,
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
        'rawRunIdsOmitted': true,
        'profileNamesOmitted': true,
        'privatePathsOmitted': true,
        'envValuesOmitted': true,
        'reviewCompletionClaimsOmitted': true,
        'promotionClaimsCreated': false,
      },
    };
  }

  static Map<String, dynamic> _adversarialReviewTask({
    required String category,
    required String requiredBefore,
    required String matrixDigest,
    required List<String> blockedCodes,
    required List<Map<String, dynamic>> batches,
  }) {
    final batchRefs = _sortedStrings(
      batches.map((batch) => _string(batch['batchRef'])),
    );
    final source = <String, dynamic>{
      'category': category,
      'matrixDigest': matrixDigest,
      'blockedCodes': blockedCodes,
      'batchRefs': batchRefs,
      'requiredBefore': requiredBefore,
    };
    return <String, dynamic>{
      'reviewRef': EvalProvenance.digestJson(source),
      'category': category,
      'status': 'pending',
      'required': true,
      'requiredBefore': requiredBefore,
      'sourceRefs': <String, dynamic>{
        'sourceMatrixDigest': matrixDigest,
        'batchRefs': batchRefs,
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
        'no scenario ids, raw run ids, profile names, private paths, or env values',
        'protected selectors appear only as counts, digests, or omitted values',
      ],
      'commandSafetyAudit' => const [
        'non-ready plans do not include live plan, run, tune, or all commands',
        'ready batch commands contain only safe capability and prompt selectors',
      ],
      'selectorSafetyAudit' => const [
        'capability and prompt selectors are public-safe and non-opaque',
        'scenario and profile selectors remain private operator inputs',
      ],
      'evidenceSufficiencyAudit' => const [
        'data-deficient cells collect evidence rather than promotion claims',
        'promotion-ready status comes only from source promotion evidence',
      ],
      'holdoutCatalogGovernanceAudit' => const [
        'protected holdout or catalog blockers require catalog preflight',
        'scenario review metadata and source digests are completed privately',
      ],
      'calibrationReliabilityAudit' => const [
        'human calibration labels are completed before readiness claims',
        'judge calibration mismatches are resolved before promotion review',
      ],
      'pairwiseReliabilityAudit' => const [
        'pairwise review gaps are completed before promotion review',
        'blind pairwise evidence is regenerated after selector changes',
      ],
      _ => const ['review the plan for unsafe or unsupported claims'],
    };
  }

  static bool _catalogGovernanceBlocker(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('holdout') ||
        normalized.contains('catalog') ||
        normalized.contains('adversarial') ||
        normalized.contains('source') ||
        normalized.contains('review');
  }

  static bool _calibrationBlocker(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('calibration') || normalized.contains('human');
  }

  static bool _pairwiseBlocker(String code) {
    return code.toLowerCase().contains('pairwise');
  }

  static List<String> _templateRefsForAction(String action) {
    return switch (action) {
      'regenerateMatrix' => const ['use-case-matrix', 'experiment-plan'],
      'compareWithinGroup' => const ['use-case-matrix', 'experiment-plan'],
      'addRequiredCapabilityCoverage' => const [
        'catalog',
        'use-case-matrix',
        'experiment-plan',
      ],
      'completeHumanCalibration' => const [
        'template',
        'calibrate',
        'report',
        'use-case-matrix',
        'experiment-plan',
      ],
      'completePairwiseReview' => const [
        'report',
        'use-case-matrix',
        'experiment-plan',
      ],
      'gradeMissingVerdicts' => const [
        'grade',
        'report',
        'use-case-matrix',
        'experiment-plan',
      ],
      'runCatalogPreflight' => const [
        'catalog',
        'use-case-matrix',
        'experiment-plan',
      ],
      'completeScenarioReviewMetadata' => const [
        'catalog',
        'use-case-matrix',
        'experiment-plan',
      ],
      _ => const [
        'catalog',
        'report',
        'use-case-matrix',
        'experiment-plan',
      ],
    };
  }

  static Map<String, dynamic> _commandTemplate(String mode) {
    final (command, envKeys, privateInputsRequired) = switch (mode) {
      'catalog' => (
        'eval/run_level2.sh catalog',
        const ['EVAL_SCENARIOS', 'EVAL_SCENARIOS_MODE', 'EVAL_RUNS_ROOT'],
        true,
      ),
      'template' => (
        'eval/run_level2.sh template <runId>',
        const [
          'EVAL_CALIBRATION_TEMPLATE',
          'EVAL_CALIBRATION_TEMPLATE_MAX_ROWS',
        ],
        true,
      ),
      'calibrate' => (
        'eval/run_level2.sh calibrate <runId>',
        const ['EVAL_CALIBRATION', 'EVAL_RUNS_ROOT'],
        true,
      ),
      'grade' => (
        'eval/run_level2.sh grade <runId>',
        const ['EVAL_RUNS_ROOT'],
        true,
      ),
      'report' => (
        'eval/run_level2.sh report <runId>',
        const ['EVAL_CALIBRATION', 'EVAL_RUNS_ROOT'],
        true,
      ),
      'use-case-matrix' => (
        'eval/run_level2.sh use-case-matrix',
        const ['EVAL_TUNING_REPORTS', 'EVAL_USE_CASE_MATRIX_REPORT'],
        false,
      ),
      'experiment-plan' => (
        'eval/run_level2.sh experiment-plan',
        const [
          'EVAL_USE_CASE_MATRIX_INPUT',
          'EVAL_USE_CASE_EXPERIMENT_PLAN',
        ],
        false,
      ),
      _ => (
        'eval/run_level2.sh experiment-plan',
        const ['EVAL_USE_CASE_MATRIX_INPUT'],
        false,
      ),
    };
    return <String, dynamic>{
      'mode': mode,
      'command': command,
      'envKeys': envKeys,
      'privateInputsRequired': privateInputsRequired,
      'valuesOmitted': true,
    };
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
      source['compatibilityGroupCount'],
      'sourceMatrix.compatibilityGroupCount',
    );
  }

  static void _validateSummary(
    List<String> issues,
    Map<String, dynamic>? summary,
  ) {
    if (summary == null) return;
    for (final field in const [
      'batchCount',
      'maxBatches',
      'maxCellsPerBatch',
      'blockedReasonCount',
    ]) {
      _expectNonNegativeInt(issues, summary[field], 'summary.$field');
    }
  }

  static void _validateSummaryInvariants(
    List<String> issues, {
    required Map<String, dynamic>? summary,
    required List<String>? blockedReasonCodes,
    required List<dynamic>? batches,
  }) {
    if (summary == null) return;
    final batchCount = summary['batchCount'];
    if (batchCount is int && batches != null && batchCount != batches.length) {
      issues.add('summary.batchCount must match batches.length');
    }
    final blockedReasonCount = summary['blockedReasonCount'];
    if (blockedReasonCount is int &&
        blockedReasonCodes != null &&
        blockedReasonCount != blockedReasonCodes.length) {
      issues.add(
        'summary.blockedReasonCount must match blockedReasonCodes.length',
      );
    }
  }

  static void _validateStatusInvariants(
    List<String> issues, {
    required String? status,
    required List<dynamic>? batches,
    required Map<String, dynamic>? operatorHandoff,
  }) {
    if (status == null) return;
    if (status != 'ready' && batches != null && batches.isNotEmpty) {
      issues.add('batches must be empty when status is $status');
    }
    if (status == 'ready' && batches != null && batches.isEmpty) {
      issues.add('batches must not be empty when status is ready');
    }
    if (operatorHandoff == null) return;
    final expectedHandoffStatus = switch (status) {
      'ready' => 'readyForBatchExecution',
      'invalid' => 'invalid',
      _ => 'manualWorkRequired',
    };
    if (operatorHandoff['status'] != expectedHandoffStatus) {
      issues.add(
        'operatorHandoff.status must be $expectedHandoffStatus for $status',
      );
    }
  }

  static void _validatePrivacy(
    List<String> issues,
    Map<String, dynamic>? privacy,
  ) {
    if (privacy == null) return;
    for (final field in const [
      'scenarioIdsOmitted',
      'rawRunIdsOmitted',
      'promotionClaimsCreated',
      'matrixOnly',
    ]) {
      _expectBool(issues, privacy[field], 'privacy.$field');
    }
    if (privacy['scenarioIdsOmitted'] != true) {
      issues.add('privacy.scenarioIdsOmitted must be true');
    }
    if (privacy['rawRunIdsOmitted'] != true) {
      issues.add('privacy.rawRunIdsOmitted must be true');
    }
    if (privacy['promotionClaimsCreated'] != false) {
      issues.add('privacy.promotionClaimsCreated must be false');
    }
    if (privacy['matrixOnly'] != true) {
      issues.add('privacy.matrixOnly must be true');
    }
  }

  static void _validateLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    const expected = <String, Object>{
      'consumesUseCaseMatrixOnly': true,
      'tracesReRead': false,
      'catalogGovernanceReRun': false,
      'humanLabelsCreated': false,
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

  static void _validateBatches(List<String> issues, List<dynamic>? batches) {
    if (batches == null) return;
    for (final (index, value) in batches.indexed) {
      final batch = _expectMap(issues, value, 'batches[$index]');
      if (batch == null) continue;
      _expectDigest(issues, batch['batchRef'], 'batches[$index].batchRef');
      _expectDigest(
        issues,
        batch['compatibilityKey'],
        'batches[$index].compatibilityKey',
      );
      _expectNonEmptyString(issues, batch['status'], 'batches[$index].status');
      _expectStringList(
        issues,
        batch['sourceCellKeys'],
        'batches[$index].sourceCellKeys',
      );
      _expectStringList(
        issues,
        batch['sourceReportRefs'],
        'batches[$index].sourceReportRefs',
      );
      _expectStringList(
        issues,
        batch['evidenceStatuses'],
        'batches[$index].evidenceStatuses',
      );
      _expectStringList(
        issues,
        batch['blockedReasonCodes'],
        'batches[$index].blockedReasonCodes',
      );
      _validateSelectorMap(
        issues,
        _expectMap(
          issues,
          batch['safeSelectors'],
          'batches[$index].safeSelectors',
        ),
        'batches[$index].safeSelectors',
      );
      _validateWithheldSelectors(
        issues,
        _expectMap(
          issues,
          batch['withheldSelectors'],
          'batches[$index].withheldSelectors',
        ),
        'batches[$index].withheldSelectors',
      );
      _validateEnvMap(
        issues,
        _expectMap(issues, batch['nextRunEnv'], 'batches[$index].nextRunEnv'),
        'batches[$index].nextRunEnv',
      );
      _validatePlanItems(
        issues,
        _expectList(
          issues,
          batch['manualPrerequisites'],
          'batches[$index].manualPrerequisites',
        ),
        'batches[$index].manualPrerequisites',
      );
      _validateCommands(
        issues,
        _expectList(
          issues,
          batch['recommendedCommands'],
          'batches[$index].recommendedCommands',
        ),
        'batches[$index].recommendedCommands',
      );
    }
  }

  static void _validateOperatorHandoff(
    List<String> issues,
    Map<String, dynamic>? handoff,
  ) {
    if (handoff == null) return;
    final status = _expectNonEmptyString(
      issues,
      handoff['status'],
      'operatorHandoff.status',
    );
    if (status != null && !_allowedHandoffStatuses.contains(status)) {
      issues.add(
        'operatorHandoff.status must be one of '
        '${_allowedHandoffStatuses.join(', ')}',
      );
    }
    _validateSelectorMap(
      issues,
      _expectMap(
        issues,
        handoff['safePublicSelectors'],
        'operatorHandoff.safePublicSelectors',
      ),
      'operatorHandoff.safePublicSelectors',
    );
    _validatePrivateInputs(
      issues,
      _expectList(
        issues,
        handoff['privateInputs'],
        'operatorHandoff.privateInputs',
      ),
    );
    _validateHandoffActions(
      issues,
      _expectList(issues, handoff['actions'], 'operatorHandoff.actions'),
    );
    final templates = _expectList(
      issues,
      handoff['commandTemplates'],
      'operatorHandoff.commandTemplates',
    );
    _validateCommandTemplates(issues, templates);
    _validateNoLiveCommands(
      issues,
      templates,
      'operatorHandoff.commandTemplates',
    );
    _validateHandoffGuards(
      issues,
      _expectMap(issues, handoff['guards'], 'operatorHandoff.guards'),
    );
  }

  static void _validateAdversarialReviewQueue(
    List<String> issues,
    Map<String, dynamic>? queue,
  ) {
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
    _validateReviewTasks(issues, tasks);
    _validateReviewSummaryInvariants(
      issues,
      summary: summary,
      tasks: tasks,
    );
    _validateConditionalReviewTasks(issues, tasks);
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
        'adversarialReviewQueue.summary.pendingTaskCount must match '
        'tasks.length',
      );
    }
    if (summary['requiredTaskCount'] is int &&
        summary['requiredTaskCount'] != tasks.length) {
      issues.add(
        'adversarialReviewQueue.summary.requiredTaskCount must match '
        'tasks.length',
      );
    }
  }

  static void _validateReviewTasks(
    List<String> issues,
    List<dynamic>? tasks,
  ) {
    if (tasks == null) return;
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
        issues.add('$path.category must be a supported adversarial review');
      }
      _expectEquals(issues, task['status'], 'pending', '$path.status');
      _expectEquals(issues, task['required'], true, '$path.required');
      _expectNonEmptyString(
        issues,
        task['requiredBefore'],
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
    }
  }

  static void _validateConditionalReviewTasks(
    List<String> issues,
    List<dynamic>? tasks,
  ) {
    if (tasks == null) return;
    final categories = {
      for (final task in tasks)
        if (task is Map<String, dynamic>) _string(task['category']),
    };
    final blockedCodes = {
      for (final task in tasks)
        if (task is Map<String, dynamic>)
          ..._stringList(_map(task['sourceRefs'])['blockedReasonCodes']),
    };
    final needsHoldoutAudit = blockedCodes.any(_catalogGovernanceBlocker);
    final hasHoldoutAudit = categories.contains(
      'holdoutCatalogGovernanceAudit',
    );
    if (needsHoldoutAudit && !hasHoldoutAudit) {
      issues.add(
        'adversarialReviewQueue.tasks must include '
        'holdoutCatalogGovernanceAudit for catalog blockers',
      );
    }
    if (!needsHoldoutAudit && hasHoldoutAudit) {
      issues.add(
        'adversarialReviewQueue.tasks must not include '
        'holdoutCatalogGovernanceAudit without catalog blockers',
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
      refs['sourceMatrixDigest'],
      '$taskPath.sourceRefs.sourceMatrixDigest',
    );
    _expectStringList(
      issues,
      refs['batchRefs'],
      '$taskPath.sourceRefs.batchRefs',
    );
    _expectStringList(
      issues,
      refs['blockedReasonCodes'],
      '$taskPath.sourceRefs.blockedReasonCodes',
    );
  }

  static void _validateReviewGuards(
    List<String> issues,
    Map<String, dynamic>? guards,
  ) {
    if (guards == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'rawRunIdsOmitted': true,
      'profileNamesOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
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

  static void _validatePrivateInputs(
    List<String> issues,
    List<dynamic>? inputs,
  ) {
    if (inputs == null) return;
    for (final (index, value) in inputs.indexed) {
      final input = _expectMap(
        issues,
        value,
        'operatorHandoff.privateInputs[$index]',
      );
      if (input == null) continue;
      _expectNonEmptyString(
        issues,
        input['kind'],
        'operatorHandoff.privateInputs[$index].kind',
      );
      _expectBool(
        issues,
        input['required'],
        'operatorHandoff.privateInputs[$index].required',
      );
      _expectBool(
        issues,
        input['valueOmitted'],
        'operatorHandoff.privateInputs[$index].valueOmitted',
      );
      if (input['valueOmitted'] != true) {
        issues.add(
          'operatorHandoff.privateInputs[$index].valueOmitted must be true',
        );
      }
      _validateEnvKeys(
        issues,
        _expectStringList(
          issues,
          input['envKeys'],
          'operatorHandoff.privateInputs[$index].envKeys',
        ),
        'operatorHandoff.privateInputs[$index].envKeys',
      );
    }
  }

  static void _validateHandoffActions(
    List<String> issues,
    List<dynamic>? actions,
  ) {
    if (actions == null) return;
    for (final (index, value) in actions.indexed) {
      final action = _expectMap(
        issues,
        value,
        'operatorHandoff.actions[$index]',
      );
      if (action == null) continue;
      _expectNonEmptyString(
        issues,
        action['code'],
        'operatorHandoff.actions[$index].code',
      );
      _expectNonEmptyString(
        issues,
        action['action'],
        'operatorHandoff.actions[$index].action',
      );
      _expectBool(
        issues,
        action['requiresPrivateInput'],
        'operatorHandoff.actions[$index].requiresPrivateInput',
      );
      _expectBool(
        issues,
        action['valuesOmitted'],
        'operatorHandoff.actions[$index].valuesOmitted',
      );
      if (action['valuesOmitted'] != true) {
        issues.add(
          'operatorHandoff.actions[$index].valuesOmitted must be true',
        );
      }
      final refs = _expectStringList(
        issues,
        action['commandTemplateRefs'],
        'operatorHandoff.actions[$index].commandTemplateRefs',
      );
      if (refs == null) continue;
      for (final ref in refs) {
        if (!_allowedTemplateModes.contains(ref)) {
          issues.add(
            'operatorHandoff.actions[$index].commandTemplateRefs contains '
            'unknown template $ref',
          );
        }
      }
    }
  }

  static void _validateCommandTemplates(
    List<String> issues,
    List<dynamic>? templates,
  ) {
    if (templates == null) return;
    for (final (index, value) in templates.indexed) {
      final template = _expectMap(
        issues,
        value,
        'operatorHandoff.commandTemplates[$index]',
      );
      if (template == null) continue;
      final mode = _expectNonEmptyString(
        issues,
        template['mode'],
        'operatorHandoff.commandTemplates[$index].mode',
      );
      if (mode != null && !_allowedTemplateModes.contains(mode)) {
        issues.add(
          'operatorHandoff.commandTemplates[$index].mode is not a safe '
          'handoff mode',
        );
      }
      final command = _expectNonEmptyString(
        issues,
        template['command'],
        'operatorHandoff.commandTemplates[$index].command',
      );
      if (command != null && _privatePathPattern.hasMatch(command)) {
        issues.add(
          'operatorHandoff.commandTemplates[$index].command must not contain '
          'private paths',
        );
      }
      _validateEnvKeys(
        issues,
        _expectStringList(
          issues,
          template['envKeys'],
          'operatorHandoff.commandTemplates[$index].envKeys',
        ),
        'operatorHandoff.commandTemplates[$index].envKeys',
      );
      if (template.containsKey('env')) {
        issues.add(
          'operatorHandoff.commandTemplates[$index] must list envKeys, not '
          'env values',
        );
      }
      _expectBool(
        issues,
        template['privateInputsRequired'],
        'operatorHandoff.commandTemplates[$index].privateInputsRequired',
      );
      _expectBool(
        issues,
        template['valuesOmitted'],
        'operatorHandoff.commandTemplates[$index].valuesOmitted',
      );
      if (template['valuesOmitted'] != true) {
        issues.add(
          'operatorHandoff.commandTemplates[$index].valuesOmitted must be true',
        );
      }
    }
  }

  static void _validateHandoffGuards(
    List<String> issues,
    Map<String, dynamic>? guards,
  ) {
    if (guards == null) return;
    const expected = <String, Object>{
      'scenarioIdsOmitted': true,
      'profileNamesOmitted': true,
      'privatePathsOmitted': true,
      'envValuesOmitted': true,
      'liveRunCommandsOmitted': true,
      'promotionClaimsCreated': false,
    };
    for (final entry in expected.entries) {
      _expectEquals(
        issues,
        guards[entry.key],
        entry.value,
        'operatorHandoff.guards.${entry.key}',
      );
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
      for (final value in values) {
        if (!_safeSelectorValue(value)) {
          issues.add('$path.$field contains unsafe selector values');
        }
      }
    }
  }

  static void _validateWithheldSelectors(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    _expectBool(
      issues,
      selectors['scenarioIdsOmitted'],
      '$path.scenarioIdsOmitted',
    );
    if (selectors['scenarioIdsOmitted'] != true) {
      issues.add('$path.scenarioIdsOmitted must be true');
    }
    _expectBool(
      issues,
      selectors['profileNamesOmitted'],
      '$path.profileNamesOmitted',
    );
    if (selectors['profileNamesOmitted'] != true) {
      issues.add('$path.profileNamesOmitted must be true');
    }
    _expectNonEmptyString(issues, selectors['reason'], '$path.reason');
  }

  static void _validatePlanItems(
    List<String> issues,
    List<dynamic>? items,
    String path,
  ) {
    if (items == null) return;
    for (final (index, value) in items.indexed) {
      final item = _expectMap(issues, value, '$path[$index]');
      if (item == null) continue;
      _expectNonEmptyString(issues, item['code'], '$path[$index].code');
      _expectNonEmptyString(issues, item['action'], '$path[$index].action');
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
      final mode = _expectNonEmptyString(
        issues,
        command['mode'],
        '$path[$index].mode',
      );
      if (mode != null && !_allowedRecommendedCommandModes.contains(mode)) {
        issues.add('$path[$index].mode is unsupported');
      }
      final text = _expectNonEmptyString(
        issues,
        command['command'],
        '$path[$index].command',
      );
      if (text != null && text.contains('EVAL_SCENARIO_IDS')) {
        issues.add('$path[$index].command must not contain EVAL_SCENARIO_IDS');
      }
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

  static void _validateEnvMap(
    List<String> issues,
    Map<String, dynamic>? env,
    String path,
  ) {
    if (env == null) return;
    for (final entry in env.entries) {
      if (entry.key == 'EVAL_SCENARIO_IDS') {
        issues.add('$path must not contain EVAL_SCENARIO_IDS');
      }
      if (_privateValueEnvKeys.contains(entry.key)) {
        issues.add('$path must not contain value-bearing ${entry.key}');
      }
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) {
        issues.add('$path.${entry.key} must be a non-empty string');
      } else if (!_safeEnvValue(value)) {
        issues.add('$path.${entry.key} contains unsafe values');
      }
    }
  }

  static void _validateEnvKeys(
    List<String> issues,
    List<String>? keys,
    String path,
  ) {
    if (keys == null) return;
    for (final key in keys) {
      if (key == 'EVAL_SCENARIO_IDS') {
        issues.add('$path must not contain EVAL_SCENARIO_IDS');
      }
      if (!_safeEnvKeyPattern.hasMatch(key)) {
        issues.add('$path contains unsafe env key $key');
      }
    }
  }

  static void _validateNoLiveCommands(
    List<String> issues,
    List<dynamic>? commands,
    String path,
  ) {
    if (commands == null) return;
    for (final (index, value) in commands.indexed) {
      if (value is! Map<String, dynamic>) continue;
      final mode = _string(value['mode']);
      if (_liveCommandModes.contains(mode)) {
        issues.add('$path[$index] must not recommend live run commands');
      }
      final command = _string(value['command']);
      if (_liveRunLevel2CommandPattern.hasMatch(command)) {
        issues.add(
          '$path[$index].command must not recommend live run commands',
        );
      }
    }
  }

  static bool _safeEnvValue(String value) {
    return value.split(',').every(_safeSelectorValue);
  }

  static bool _safeSelectorValue(String value) {
    return value.trim().isNotEmpty &&
        _safeSelectorPattern.hasMatch(value) &&
        !_opaqueFallbackPattern.hasMatch(value);
  }

  static List<String> _safeSelectorValues(Iterable<String> values) {
    return _sortedStrings(values.where(_safeSelectorValue));
  }

  static void _validateNoPrivatePayloads(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (key == 'envKeys') {
          _validateEnvKeys(
            issues,
            _stringList(entry.value),
            '$path.$key',
          );
          continue;
        }
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
      if (value.contains('EVAL_SCENARIO_IDS')) {
        issues.add('$path must not contain EVAL_SCENARIO_IDS');
      }
      if (_privateEnvTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain private env value keys');
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
