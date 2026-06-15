import 'eval_provenance.dart';
import 'eval_tuning_readiness.dart';

abstract final class EvalScenarioCatalogPreflight {
  static const schemaVersion = 1;
  static const kind = 'lotti.evalScenarioCatalogPreflight';
  static const nextExperimentPlanKind =
      'lotti.evalScenarioCatalogPreflightNextExperimentPlan';
  static const _allowedStatuses = {
    'catalogReady',
    'catalogBlocked',
    'inputInvalid',
    'policyInvalid',
  };
  static const _allowedTopLevelFields = {
    'schemaVersion',
    'kind',
    'generatedAt',
    'status',
    'policy',
    'source',
    'selection',
    'profiles',
    'coverage',
    'adversarial',
    'holdout',
    'reviews',
    'limitations',
    'issues',
    'nextExperimentPlan',
  };
  static const _allowedRecommendedCommandFields = {
    'mode',
    'commandTemplate',
    'valuesOmitted',
  };
  static const _allowedNextRunEnvKeys = {
    'EVAL_REQUIRED_CAPABILITIES',
    'EVAL_SCENARIOS_MODE',
  };
  static const _allowedCatalogModes = {'append', 'replace'};
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
    required EvalScenarioCatalogPreflightReport report,
    required String scenarioSetDigest,
    required String profileSetDigest,
    String catalogMode = 'append',
    bool selectedSubset = false,
    DateTime? generatedAt,
  }) {
    final issues = _issues(report);
    final blockedReasonCodes = _sortedStrings(
      issues.map((issue) => _string(issue['code'])),
    );
    final status = _status(report, issues);
    final protectedScenarioIdCount =
        report.catalogEvidence?.protectedScenarioIds.length ?? 0;
    final protectedHoldoutScenarioIdCount =
        report.catalogEvidence?.protectedHoldoutScenarioIds.length ?? 0;
    final protectedValues = _protectedValues(report);

    final artifact = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'generatedAt': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': status,
      'policy': _policyJson(report.policy, protectedValues),
      'source': _sourceJson(
        report: report,
        scenarioSetDigest: scenarioSetDigest,
        catalogMode: catalogMode,
        protectedValues: protectedValues,
      ),
      'selection': <String, dynamic>{
        'selectedSubset': selectedSubset,
        'selectedScenarioCount': selectedSubset ? report.scenarioCount : 0,
        'scenarioIdsOmitted': true,
        'reason':
            'scenario selectors are private catalog controls and are never '
            'emitted by catalog preflight reports',
      },
      'profiles': _profilesJson(
        report: report,
        profileSetDigest: profileSetDigest,
        protectedValues: protectedValues,
      ),
      'coverage': _coverageJson(report, protectedValues),
      'adversarial': _adversarialJson(report, protectedValues),
      'holdout': _holdoutJson(report, protectedValues),
      'reviews': _reviewsJson(report),
      'limitations': const <String, dynamic>{
        'tracesEvaluated': false,
        'judgeVerdictsEvaluated': false,
        'providerProvenanceEvaluated': false,
        'modelPerformanceEvaluated': false,
        'humanCalibrationEvaluated': false,
        'pairwisePreferenceEvaluated': false,
        'promotionReadinessEvaluated': false,
      },
      'issues': _sanitizeIssues(issues, protectedValues),
      'nextExperimentPlan': _nextExperimentPlan(
        status: status,
        blockedReasonCodes: blockedReasonCodes,
        report: report,
        selectedSubset: selectedSubset,
        catalogMode: catalogMode,
        protectedScenarioIdCount: protectedScenarioIdCount,
        protectedHoldoutScenarioIdCount: protectedHoldoutScenarioIdCount,
        protectedValues: protectedValues,
      ),
    };
    assertValid(artifact, protectedValues: protectedValues);
    return artifact;
  }

  static List<String> validate(
    Map<String, dynamic> preflight, {
    Iterable<String> protectedValues = const [],
  }) {
    final issues = <String>[];
    _expectEquals(
      issues,
      preflight['schemaVersion'],
      schemaVersion,
      'schemaVersion',
    );
    _validateAllowedKeys(
      issues,
      preflight,
      _allowedTopLevelFields,
      'preflight',
    );
    _expectEquals(issues, preflight['kind'], kind, 'kind');
    final status = _expectNonEmptyString(issues, preflight['status'], 'status');
    if (status != null && !_allowedStatuses.contains(status)) {
      issues.add('status must be one of ${_allowedStatuses.join(', ')}');
    }
    final generatedAt = _expectNonEmptyString(
      issues,
      preflight['generatedAt'],
      'generatedAt',
    );
    if (generatedAt != null) {
      try {
        DateTime.parse(generatedAt);
      } on FormatException {
        issues.add('generatedAt must be an ISO-8601 timestamp');
      }
    }
    _validatePolicy(
      issues,
      _expectMap(issues, preflight['policy'], 'policy'),
    );
    _validateSource(
      issues,
      _expectMap(issues, preflight['source'], 'source'),
    );
    _validateSelection(
      issues,
      _expectMap(issues, preflight['selection'], 'selection'),
    );
    _validateProfiles(
      issues,
      _expectMap(issues, preflight['profiles'], 'profiles'),
    );
    _validateCoverage(
      issues,
      _expectMap(issues, preflight['coverage'], 'coverage'),
    );
    _validateAdversarial(
      issues,
      _expectMap(issues, preflight['adversarial'], 'adversarial'),
    );
    _validateHoldout(
      issues,
      _expectMap(issues, preflight['holdout'], 'holdout'),
    );
    _validateReviews(
      issues,
      _expectMap(issues, preflight['reviews'], 'reviews'),
    );
    _validateLimitations(
      issues,
      _expectMap(issues, preflight['limitations'], 'limitations'),
    );
    _validateIssues(
      issues,
      _expectList(issues, preflight['issues'], 'issues'),
    );
    _validateNextPlan(
      issues,
      _expectMap(
        issues,
        preflight['nextExperimentPlan'],
        'nextExperimentPlan',
      ),
      status,
    );
    _validateNoScenarioIds(issues, preflight, 'preflight');
    _validateNoPrivatePayloads(issues, preflight, 'preflight');
    _validateNoProtectedValues(
      issues,
      preflight,
      'preflight',
      protectedValues.toSet(),
    );
    return issues;
  }

  static void assertValid(
    Map<String, dynamic> preflight, {
    Iterable<String> protectedValues = const [],
  }) {
    final issues = validate(preflight, protectedValues: protectedValues);
    if (issues.isNotEmpty) {
      throw StateError(
        'Invalid scenario catalog preflight report:\n${issues.join('\n')}',
      );
    }
  }

  static String _status(
    EvalScenarioCatalogPreflightReport report,
    List<Map<String, dynamic>> issues,
  ) {
    if (issues.any((issue) => _string(issue['category']) == 'policy')) {
      return 'policyInvalid';
    }
    if (issues.any((issue) => _string(issue['category']) == 'input')) {
      return 'inputInvalid';
    }
    return report.ready ? 'catalogReady' : 'catalogBlocked';
  }

  static Map<String, dynamic> _policyJson(
    EvalTuningPolicy policy,
    Set<String> protectedValues,
  ) {
    return <String, dynamic>{
      'name': policy.name,
      'digest': policy.policyDigest,
      'payloadDigest': EvalProvenance.digestJson(policy.toJson()),
      'requirements': <String, dynamic>{
        'minScenarioCount': policy.minScenarioCount,
        'minScenariosPerAgentKind': policy.minScenariosPerAgentKind,
        'minScenariosPerCapability': policy.minScenariosPerCapability,
        'minScenariosPerRequiredCapabilitySplit':
            policy.minScenariosPerRequiredCapabilitySplit,
        'minCapabilityCount': policy.minCapabilityCount,
        'requiredModelClasses': _sortedStrings(
          policy.requiredModelClasses.map((value) => value.name),
        ),
        'requiredPrimaryCapabilityIds': _publicStrings(
          policy.requiredPrimaryCapabilityIds,
          protectedValues,
        ),
        'requiredSplits': _sortedStrings(
          policy.requiredSplits.map((value) => value.name),
        ),
        'requiredAgentKinds': _sortedStrings(
          policy.requiredAgentKinds.map((value) => value.name),
        ),
        'minAdversarialScenarioCount': policy.minAdversarialScenarioCount,
        'minAdversarialScenariosPerAgentKind':
            policy.minAdversarialScenariosPerAgentKind,
        'minAdversarialScenariosPerCapability':
            policy.minAdversarialScenariosPerCapability,
        'requiredAdversarialTags': _publicStrings(
          policy.requiredAdversarialTags,
          protectedValues,
        ),
        'requireAdversarialTagCoveragePerAgentKind':
            policy.requireAdversarialTagCoveragePerAgentKind,
        'minProductionReplayHoldoutScenarios':
            policy.minProductionReplayHoldoutScenarios,
        'minProtectedHoldoutScenarios': policy.minProtectedHoldoutScenarios,
        'minProtectedHoldoutScenariosPerAgentKind':
            policy.minProtectedHoldoutScenariosPerAgentKind,
        'minProtectedHoldoutScenariosPerRequiredCapability':
            policy.minProtectedHoldoutScenariosPerRequiredCapability,
        'minProfilesPerModelClass': policy.minProfilesPerModelClass,
        'minTrialsPerProfile': policy.minTrialsPerProfile,
        'requireProtectedHoldout': policy.requireProtectedHoldout,
        'requireReviewedScenarioEvidence':
            policy.requireReviewedScenarioEvidence,
      },
    };
  }

  static Map<String, dynamic> _sourceJson({
    required EvalScenarioCatalogPreflightReport report,
    required String scenarioSetDigest,
    required String catalogMode,
    required Set<String> protectedValues,
  }) {
    final evidence = report.catalogEvidence;
    final externalCatalogId = evidence?.externalCatalogId;
    return <String, dynamic>{
      'scenarioSetDigest': evidence?.scenarioSetDigest ?? scenarioSetDigest,
      'catalogMode': catalogMode.isEmpty ? 'append' : catalogMode,
      'usesExternalCatalog': evidence?.usesExternalCatalog ?? false,
      'publicScenarioCount':
          evidence?.publicScenarioCount ?? report.scenarioCount,
      'externalScenarioCount': evidence?.externalScenarioCount ?? 0,
      if (evidence?.externalCatalogDigest != null)
        'externalCatalogDigest': evidence!.externalCatalogDigest,
      if (externalCatalogId != null &&
          !protectedValues.contains(externalCatalogId))
        'externalCatalogId': externalCatalogId,
      'protectedHoldout': evidence?.protectedHoldout ?? false,
      'protectedIdsOmitted': true,
    };
  }

  static Map<String, dynamic> _profilesJson({
    required EvalScenarioCatalogPreflightReport report,
    required String profileSetDigest,
    required Set<String> protectedValues,
  }) {
    return <String, dynamic>{
      'profileSetDigest': profileSetDigest,
      'profileCount': report.profileCount,
      'modelClassCounts': _enumCounts(report.evidence.profileCountByModelClass),
      'minObservedTrialCount': report.evidence.minObservedTrialCount,
      'maxObservedTrialCount': report.evidence.maxObservedTrialCount,
      'profilesBelowMinTrialCount': _opaqueProfileTrialCounts(
        report.evidence.profilesBelowMinTrialCount,
      ),
      'profilesBelowMinTrialCountProfileNamesOmitted': true,
    };
  }

  static Map<String, dynamic> _coverageJson(
    EvalScenarioCatalogPreflightReport report,
    Set<String> protectedValues,
  ) {
    return <String, dynamic>{
      'scenarioCount': report.scenarioCount,
      'agentKindCounts': _enumCounts(report.evidence.scenarioCountByAgentKind),
      'splitCounts': _enumCounts(report.evidence.scenarioCountBySplit),
      'primaryCapabilityCounts': _publicStringCounts(
        report.evidence.scenarioCountByPrimaryCapability,
        protectedValues,
      ),
      'primaryCapabilitySplitCounts': _publicStringCounts(
        report.evidence.scenarioCountByPrimaryCapabilitySplit,
        protectedValues,
      ),
      'requiredPrimaryCapabilityIds': _publicStrings(
        report.policy.requiredPrimaryCapabilityIds,
        protectedValues,
      ),
      'missingRequiredPrimaryCapabilityIds': _publicStrings(
        report.evidence.missingRequiredPrimaryCapabilityIds,
        protectedValues,
      ),
      'missingRequiredPrimaryCapabilityCount':
          report.evidence.missingRequiredPrimaryCapabilityIds.length,
      'missingRequiredCapabilitySplitCells': _publicStrings(
        report.evidence.missingRequiredCapabilitySplitCells,
        protectedValues,
      ),
      'missingRequiredCapabilitySplitCellCount':
          report.evidence.missingRequiredCapabilitySplitCells.length,
      'protectedPrimaryCapabilityValueOmittedCount':
          _protectedValueCount(
            report.evidence.scenarioCountByPrimaryCapability.keys,
            protectedValues,
          ) +
          _protectedValueCount(
            report.evidence.scenarioCountByPrimaryCapabilitySplit.keys,
            protectedValues,
          ) +
          _protectedValueCount(
            report.policy.requiredPrimaryCapabilityIds,
            protectedValues,
          ) +
          _protectedValueCount(
            report.evidence.missingRequiredPrimaryCapabilityIds,
            protectedValues,
          ),
    };
  }

  static Map<String, dynamic> _adversarialJson(
    EvalScenarioCatalogPreflightReport report,
    Set<String> protectedValues,
  ) {
    return <String, dynamic>{
      'scenarioCount': report.evidence.adversarialScenarioCount,
      'agentKindCounts': _enumCounts(
        report.evidence.adversarialScenarioCountByAgentKind,
      ),
      'primaryCapabilityCounts': _publicStringCounts(
        report.evidence.adversarialScenarioCountByPrimaryCapability,
        protectedValues,
      ),
      'stressTagAgentKindCounts': _publicStringCounts(
        report.evidence.adversarialStressTagCountByAgentKind,
        protectedValues,
      ),
      'tagsPresent': _publicStrings(
        report.evidence.adversarialTags,
        protectedValues,
      ),
      'missingTags': _publicStrings(
        report.evidence.missingAdversarialTags,
        protectedValues,
      ),
      'missingStressTagAgentKindCells': _publicStrings(
        report.evidence.missingAdversarialStressTagAgentKindCells,
        protectedValues,
      ),
      'missingStressTagAgentKindCellCount':
          report.evidence.missingAdversarialStressTagAgentKindCells.length,
      'protectedAdversarialValueOmittedCount':
          _protectedValueCount(
            report.evidence.adversarialScenarioCountByPrimaryCapability.keys,
            protectedValues,
          ) +
          _protectedValueCount(
            report.evidence.adversarialStressTagCountByAgentKind.keys,
            protectedValues,
          ) +
          _protectedValueCount(
            report.evidence.adversarialTags,
            protectedValues,
          ) +
          _protectedValueCount(
            report.evidence.missingAdversarialTags,
            protectedValues,
          ),
    };
  }

  static Map<String, dynamic> _holdoutJson(
    EvalScenarioCatalogPreflightReport report,
    Set<String> protectedValues,
  ) {
    return <String, dynamic>{
      'productionReplayHoldoutScenarioCount':
          report.evidence.productionReplayHoldoutScenarioCount,
      'protectedHoldoutScenarioCount':
          report.evidence.protectedHoldoutScenarioCount,
      'protectedHoldoutAgentKindCounts': _enumCounts(
        report.evidence.protectedHoldoutScenarioCountByAgentKind,
      ),
      'protectedHoldoutPrimaryCapabilityCounts': _publicStringCounts(
        report.evidence.protectedHoldoutScenarioCountByPrimaryCapability,
        protectedValues,
      ),
      'missingProtectedHoldoutPrimaryCapabilityIds': _publicStrings(
        report.evidence.missingProtectedHoldoutPrimaryCapabilityIds,
        protectedValues,
      ),
      'missingProtectedHoldoutPrimaryCapabilityCount':
          report.evidence.missingProtectedHoldoutPrimaryCapabilityIds.length,
      'duplicateProtectedHoldoutScenarioIdCount':
          report.evidence.duplicateProtectedHoldoutScenarioIds.length,
      'duplicateProtectedHoldoutSourceDigestCount':
          report.evidence.duplicateProtectedHoldoutSourceDigests.length,
    };
  }

  static Map<String, dynamic> _reviewsJson(
    EvalScenarioCatalogPreflightReport report,
  ) {
    return <String, dynamic>{
      'requiredCount': report.evidence.scenarioReviewRequiredCount,
      'completedCount': report.evidence.completedScenarioReviewCount,
      'missingCount': report.evidence.missingScenarioReviewIds.length,
      'incompleteCount': report.evidence.incompleteScenarioReviewIds.length,
      'invalidCount': report.evidence.invalidScenarioReviewIds.length,
      'staleCount': report.evidence.staleScenarioReviewIds.length,
      'missingSourceDigestCount':
          report.evidence.missingScenarioReviewSourceDigestIds.length,
    };
  }

  static List<Map<String, dynamic>> _issues(
    EvalScenarioCatalogPreflightReport report,
  ) {
    final evidence = report.evidence;
    final policy = report.policy;
    final issues = <Map<String, dynamic>>[];

    void add(
      String code, {
      String category = 'coverage',
      String severity = 'blocking',
      String? dimension,
      String? value,
      int? actual,
      int? required,
      int? count,
    }) {
      final issue = <String, dynamic>{
        'code': code,
        'severity': severity,
        'category': category,
      };
      if (dimension != null) issue['dimension'] = dimension;
      if (value != null) issue['value'] = value;
      if (actual != null) issue['actual'] = actual;
      if (required != null) issue['required'] = required;
      if (count != null) issue['count'] = count;
      issues.add(issue);
    }

    if (report.scenarioCount < policy.minScenarioCount) {
      add(
        'catalog.scenarioCountBelowMinimum',
        actual: report.scenarioCount,
        required: policy.minScenarioCount,
      );
    }
    for (final agentKind in policy.requiredAgentKinds) {
      final actual = evidence.scenarioCountByAgentKind[agentKind] ?? 0;
      if (actual < policy.minScenariosPerAgentKind) {
        add(
          'catalog.agentKindScenarioCountBelowMinimum',
          dimension: 'agentKind',
          value: agentKind.name,
          actual: actual,
          required: policy.minScenariosPerAgentKind,
        );
      }
    }
    for (final split in policy.requiredSplits) {
      final actual = evidence.scenarioCountBySplit[split] ?? 0;
      if (actual == 0) {
        add(
          'catalog.requiredSplitMissing',
          dimension: 'split',
          value: split.name,
          actual: actual,
          required: 1,
        );
      }
    }
    if (evidence.scenarioCountByPrimaryCapability.length <
        policy.minCapabilityCount) {
      add(
        'catalog.capabilityCountBelowMinimum',
        dimension: 'primaryCapability',
        actual: evidence.scenarioCountByPrimaryCapability.length,
        required: policy.minCapabilityCount,
      );
    }
    for (final capabilityId in evidence.missingRequiredPrimaryCapabilityIds) {
      add(
        'catalog.requiredPrimaryCapabilityMissing',
        dimension: 'primaryCapability',
        value: capabilityId,
        actual: 0,
        required: 1,
      );
    }
    if (policy.minScenariosPerCapability > 0) {
      for (final entry in evidence.scenarioCountByPrimaryCapability.entries) {
        if (entry.value < policy.minScenariosPerCapability) {
          add(
            'catalog.capabilityScenarioCountBelowMinimum',
            dimension: 'primaryCapability',
            value: entry.key,
            actual: entry.value,
            required: policy.minScenariosPerCapability,
          );
        }
      }
    }
    for (final cell in evidence.missingRequiredCapabilitySplitCells) {
      add(
        'catalog.requiredCapabilitySplitMissing',
        dimension: 'primaryCapabilitySplit',
        value: cell,
        actual: evidence.scenarioCountByPrimaryCapabilitySplit[cell] ?? 0,
        required: policy.minScenariosPerRequiredCapabilitySplit,
      );
    }
    if (evidence.adversarialScenarioCount <
        policy.minAdversarialScenarioCount) {
      add(
        'adversarial.scenarioCountBelowMinimum',
        category: 'adversarial',
        actual: evidence.adversarialScenarioCount,
        required: policy.minAdversarialScenarioCount,
      );
    }
    for (final agentKind in policy.requiredAgentKinds) {
      final actual =
          evidence.adversarialScenarioCountByAgentKind[agentKind] ?? 0;
      if (actual < policy.minAdversarialScenariosPerAgentKind) {
        add(
          'adversarial.agentKindCountBelowMinimum',
          category: 'adversarial',
          dimension: 'agentKind',
          value: agentKind.name,
          actual: actual,
          required: policy.minAdversarialScenariosPerAgentKind,
        );
      }
    }
    for (final capabilityId in evidence.scenarioCountByPrimaryCapability.keys) {
      final actual =
          evidence.adversarialScenarioCountByPrimaryCapability[capabilityId] ??
          0;
      if (actual < policy.minAdversarialScenariosPerCapability) {
        add(
          'adversarial.capabilityCountBelowMinimum',
          category: 'adversarial',
          dimension: 'primaryCapability',
          value: capabilityId,
          actual: actual,
          required: policy.minAdversarialScenariosPerCapability,
        );
      }
    }
    for (final tag in evidence.missingAdversarialTags) {
      add(
        'adversarial.requiredTagMissing',
        category: 'adversarial',
        dimension: 'tag',
        value: tag,
        actual: 0,
        required: 1,
      );
    }
    for (final cell in evidence.missingAdversarialStressTagAgentKindCells) {
      add(
        'adversarial.agentKindRequiredTagMissing',
        category: 'adversarial',
        dimension: 'agentKindTag',
        value: cell,
        actual: evidence.adversarialStressTagCountByAgentKind[cell] ?? 0,
        required: 1,
      );
    }
    if (evidence.productionReplayHoldoutScenarioCount <
        policy.minProductionReplayHoldoutScenarios) {
      add(
        'holdout.productionReplayCountBelowMinimum',
        category: 'holdout',
        actual: evidence.productionReplayHoldoutScenarioCount,
        required: policy.minProductionReplayHoldoutScenarios,
      );
    }
    if (policy.requireProtectedHoldout &&
        !(report.catalogEvidence?.hasProtectedHoldoutEvidence ?? false)) {
      add('holdout.protectedEvidenceMissing', category: 'holdout');
    }
    if (evidence.protectedHoldoutScenarioCount <
        policy.minProtectedHoldoutScenarios) {
      add(
        'holdout.protectedCountBelowMinimum',
        category: 'holdout',
        actual: evidence.protectedHoldoutScenarioCount,
        required: policy.minProtectedHoldoutScenarios,
      );
    }
    for (final agentKind in policy.requiredAgentKinds) {
      final actual =
          evidence.protectedHoldoutScenarioCountByAgentKind[agentKind] ?? 0;
      if (actual < policy.minProtectedHoldoutScenariosPerAgentKind) {
        add(
          'holdout.protectedAgentKindCountBelowMinimum',
          category: 'holdout',
          dimension: 'agentKind',
          value: agentKind.name,
          actual: actual,
          required: policy.minProtectedHoldoutScenariosPerAgentKind,
        );
      }
    }
    for (final capabilityId
        in evidence.missingProtectedHoldoutPrimaryCapabilityIds) {
      final actual =
          evidence
              .protectedHoldoutScenarioCountByPrimaryCapability[capabilityId] ??
          0;
      add(
        'holdout.protectedCapabilityCountBelowMinimum',
        category: 'holdout',
        dimension: 'primaryCapability',
        value: capabilityId,
        actual: actual,
        required: policy.minProtectedHoldoutScenariosPerRequiredCapability,
      );
    }
    if (evidence.duplicateProtectedHoldoutScenarioIds.isNotEmpty) {
      add(
        'holdout.duplicateProtectedEvidenceReference',
        category: 'holdout',
        count: evidence.duplicateProtectedHoldoutScenarioIds.length,
      );
    }
    if (evidence.duplicateProtectedHoldoutSourceDigests.isNotEmpty) {
      add(
        'holdout.duplicateProtectedSourceDigest',
        category: 'holdout',
        count: evidence.duplicateProtectedHoldoutSourceDigests.length,
      );
    }
    if (evidence.scenarioReviewRequiredCount >
        evidence.completedScenarioReviewCount) {
      final reviewCounts = <String, int>{
        'review.missing': evidence.missingScenarioReviewIds.length,
        'review.incomplete': evidence.incompleteScenarioReviewIds.length,
        'review.invalidMetadata': evidence.invalidScenarioReviewIds.length,
        'review.staleSubjectDigest': evidence.staleScenarioReviewIds.length,
        'review.missingSourceDigest':
            evidence.missingScenarioReviewSourceDigestIds.length,
      };
      for (final entry in reviewCounts.entries) {
        if (entry.value > 0) {
          add(entry.key, category: 'review', count: entry.value);
        }
      }
    }
    for (final modelClass in policy.requiredModelClasses) {
      final actual = evidence.profileCountByModelClass[modelClass] ?? 0;
      if (actual < policy.minProfilesPerModelClass) {
        add(
          'profiles.modelClassCountBelowMinimum',
          category: 'profiles',
          dimension: 'modelClass',
          value: modelClass.name,
          actual: actual,
          required: policy.minProfilesPerModelClass,
        );
      }
    }
    if (evidence.profilesBelowMinTrialCount.isNotEmpty) {
      add(
        'profiles.trialCountBelowMinimum',
        category: 'profiles',
        count: evidence.profilesBelowMinTrialCount.length,
      );
    }
    _addPatternIssues(report.failures, add);

    return _deduplicateIssues(issues);
  }

  static void _addPatternIssues(
    List<String> failures,
    void Function(
      String code, {
      String category,
      String severity,
      String? dimension,
      String? value,
      int? actual,
      int? required,
      int? count,
    })
    add,
  ) {
    final counts = <String, int>{};
    for (final failure in failures) {
      final code = _failureCode(failure);
      if (code == null) continue;
      counts.update(code.$1, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final entry in counts.entries) {
      final category = entry.key.startsWith('policy.')
          ? 'policy'
          : entry.key.startsWith('input.')
          ? 'input'
          : entry.key.startsWith('review.')
          ? 'review'
          : entry.key.startsWith('holdout.')
          ? 'holdout'
          : 'coverage';
      add(entry.key, category: category, count: entry.value);
    }
  }

  static (String, String)? _failureCode(String failure) {
    if (failure.startsWith('policy ')) return ('policy.invalid', 'policy');
    if (failure.startsWith('policy name')) {
      return ('policy.invalid', 'policy');
    }
    if (failure.startsWith('scenario catalog validation failed:')) {
      return ('input.scenarioCatalogInvalid', 'input');
    }
    if (failure.contains('protectedHoldout=false')) {
      return ('holdout.protectedFlagFalse', 'holdout');
    }
    if (failure.contains('references unknown scenario')) {
      return ('holdout.unknownProtectedReference', 'holdout');
    }
    if (failure.contains('references non-holdout scenario')) {
      return ('holdout.nonHoldoutProtectedReference', 'holdout');
    }
    if (failure.contains('references non-production-replay')) {
      return ('holdout.nonProductionReplayProtectedReference', 'holdout');
    }
    if (failure.contains('review sourceDigest is required')) {
      return ('review.missingSourceDigest', 'review');
    }
    if (failure.contains('review subjectDigest is stale')) {
      return ('review.staleSubjectDigest', 'review');
    }
    if (failure.contains('review metadata is invalid')) {
      return ('review.invalidMetadata', 'review');
    }
    if (failure.contains('review status is')) {
      return ('review.incomplete', 'review');
    }
    if (failure.contains('review is required')) {
      return ('review.missing', 'review');
    }
    return null;
  }

  static List<Map<String, dynamic>> _deduplicateIssues(
    List<Map<String, dynamic>> issues,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    for (final issue in issues) {
      final key = [
        issue['code'],
        issue['category'],
        issue['dimension'],
        issue['value'],
        issue['actual'],
        issue['required'],
      ].join('|');
      final existing = merged[key];
      if (existing == null) {
        merged[key] = Map<String, dynamic>.of(issue);
        continue;
      }
      final count =
          (existing['count'] as int? ?? 1) + (issue['count'] as int? ?? 1);
      existing['count'] = count;
    }
    final sorted = merged.values.toList()
      ..sort(
        (a, b) =>
            [
                  _string(a['code']),
                  _string(a['dimension']),
                  _string(a['value']),
                ]
                .join('|')
                .compareTo(
                  [
                    _string(b['code']),
                    _string(b['dimension']),
                    _string(b['value']),
                  ].join('|'),
                ),
      );
    return List.unmodifiable(sorted);
  }

  static Map<String, dynamic> _nextExperimentPlan({
    required String status,
    required List<String> blockedReasonCodes,
    required EvalScenarioCatalogPreflightReport report,
    required bool selectedSubset,
    required String catalogMode,
    required int protectedScenarioIdCount,
    required int protectedHoldoutScenarioIdCount,
    required Set<String> protectedValues,
  }) {
    final safeCapabilities = _safeSelectorValues({
      ...report.evidence.missingRequiredPrimaryCapabilityIds,
      ...report.policy.requiredPrimaryCapabilityIds,
    }, protectedValues);
    final safeTags = _safeSelectorValues({
      ...report.evidence.missingAdversarialTags,
      ...report.policy.requiredAdversarialTags,
    }, protectedValues);
    final nextRunEnv = <String, dynamic>{
      if (safeCapabilities.isNotEmpty)
        'EVAL_REQUIRED_CAPABILITIES': safeCapabilities.join(','),
      if (catalogMode.isNotEmpty) 'EVAL_SCENARIOS_MODE': catalogMode,
    };

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'kind': nextExperimentPlanKind,
      'status': status,
      'objective': _objective(status),
      'blockedReasonCodes': blockedReasonCodes,
      'evidenceNeeds': [
        for (final code in blockedReasonCodes)
          <String, dynamic>{
            'code': code,
            'action': _manualPrerequisiteAction(code),
          },
      ],
      'safeSelectors': <String, dynamic>{
        'capabilities': safeCapabilities,
        'adversarialTags': safeTags,
        'agentKinds': _safeSelectorValues(
          report.policy.requiredAgentKinds.map((value) => value.name),
          protectedValues,
        ),
        'modelClasses': _safeSelectorValues(
          report.policy.requiredModelClasses.map((value) => value.name),
          protectedValues,
        ),
      },
      'withheldSelectors': <String, dynamic>{
        'scenarioIdsOmitted': true,
        'selectedSubsetScenarioCount': selectedSubset
            ? report.scenarioCount
            : 0,
        'protectedScenarioReferenceCount': protectedScenarioIdCount,
        'protectedHoldoutReferenceCount': protectedHoldoutScenarioIdCount,
        'reason':
            'catalog preflight plans never expose scenario ids; select '
            'private scenarios from the source catalog',
      },
      'manualPrerequisites': [
        for (final code in blockedReasonCodes)
          <String, dynamic>{
            'code': code,
            'action': _manualPrerequisiteAction(code),
          },
      ],
      'nextRunEnv': nextRunEnv,
      'recommendedCommands': _recommendedCommands(
        status: status,
      ),
    };
  }

  static String _objective(String status) => switch (status) {
    'catalogReady' => 'runLiveEvalWithGovernedCatalog',
    'policyInvalid' => 'fixCatalogPreflightPolicy',
    'inputInvalid' => 'fixScenarioCatalogInput',
    _ => 'closeCatalogGovernanceGaps',
  };

  static String _manualPrerequisiteAction(String blockerCode) {
    if (blockerCode.startsWith('policy.') || blockerCode.startsWith('input.')) {
      return 'fixCatalogConfiguration';
    }
    if (blockerCode.startsWith('review.')) {
      return 'completeScenarioReviewMetadata';
    }
    if (blockerCode.startsWith('holdout.')) {
      return 'curateProtectedProductionReplayHoldout';
    }
    if (blockerCode.startsWith('adversarial.')) {
      return 'addAdversarialStressCoverage';
    }
    if (blockerCode.startsWith('profiles.')) {
      return 'addRequiredProfilesOrTrials';
    }
    if (blockerCode.contains('Capability')) return 'addCapabilityCoverage';
    return 'collectMissingCatalogEvidence';
  }

  static List<Map<String, dynamic>> _recommendedCommands({
    required String status,
  }) {
    final commands = status == 'catalogReady'
        ? const [
            ('catalog', 'eval/run_level2.sh catalog'),
            ('plan', 'eval/run_level2.sh plan <nextRunId>'),
            ('run', 'eval/run_level2.sh run <nextRunId>'),
            ('tune', 'eval/run_level2.sh tune <nextRunId>'),
          ]
        : const [
            ('catalog', 'eval/run_level2.sh catalog'),
          ];
    return [
      for (final command in commands)
        <String, dynamic>{
          'mode': command.$1,
          'commandTemplate': command.$2,
          'valuesOmitted': true,
        },
    ];
  }

  static Map<String, int> _enumCounts<K extends Enum>(Map<K, int> counts) {
    return <String, int>{
      for (final entry
          in counts.entries.toList()
            ..sort((a, b) => a.key.name.compareTo(b.key.name)))
        entry.key.name: entry.value,
    };
  }

  static Map<String, int> _stringCounts(Map<String, int> counts) {
    return <String, int>{
      for (final entry
          in counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        entry.key: entry.value,
    };
  }

  static Map<String, int> _publicStringCounts(
    Map<String, int> counts,
    Set<String> protectedValues,
  ) {
    return _stringCounts({
      for (final entry in counts.entries)
        if (!_containsProtectedValue(entry.key, protectedValues))
          entry.key: entry.value,
    });
  }

  static Map<String, int> _opaqueProfileTrialCounts(Map<String, int> counts) {
    return <String, int>{
      for (final (index, entry) in counts.entries.indexed)
        'profile-${(index + 1).toString().padLeft(3, '0')}': entry.value,
    };
  }

  static List<String> _safeSelectorValues(
    Iterable<String> values,
    Set<String> protectedValues,
  ) => _publicStrings(
    values.where(_safeSelectorPattern.hasMatch),
    protectedValues,
  );

  static List<String> _publicStrings(
    Iterable<String> values,
    Set<String> protectedValues,
  ) => _sortedStrings(
    values.where((value) => !_containsProtectedValue(value, protectedValues)),
  );

  static List<String> _sortedStrings(Iterable<String> values) {
    final sorted = values.where((value) => value.isNotEmpty).toSet().toList()
      ..sort();
    return List.unmodifiable(sorted);
  }

  static Set<String> _protectedValues(
    EvalScenarioCatalogPreflightReport report,
  ) {
    final evidence = report.catalogEvidence;
    if (evidence == null) return const <String>{};
    return {
      ...evidence.protectedScenarioIds,
      ...evidence.protectedHoldoutScenarioIds,
    }.where((value) => value.trim().isNotEmpty).toSet();
  }

  static int _protectedValueCount(
    Iterable<String> values,
    Set<String> protectedValues,
  ) {
    return values
        .where((value) => _containsProtectedValue(value, protectedValues))
        .length;
  }

  static bool _containsProtectedValue(
    String value,
    Set<String> protectedValues,
  ) {
    return protectedValues.any(value.contains);
  }

  static List<Map<String, dynamic>> _sanitizeIssues(
    List<Map<String, dynamic>> issues,
    Set<String> protectedValues,
  ) {
    if (protectedValues.isEmpty) return issues;
    return [
      for (final issue in issues)
        <String, dynamic>{
          for (final entry in issue.entries)
            if (!(entry.key == 'value' &&
                entry.value is String &&
                _containsProtectedValue(
                  entry.value as String,
                  protectedValues,
                )))
              entry.key: entry.value,
          if (issue['value'] case final String value
              when _containsProtectedValue(value, protectedValues))
            'valueOmitted': true,
        },
    ];
  }

  static String _string(Object? value) => value is String ? value : '';

  static void _validatePolicy(
    List<String> issues,
    Map<String, dynamic>? policy,
  ) {
    if (policy == null) return;
    _expectNonEmptyString(issues, policy['name'], 'policy.name');
    _expectDigest(issues, policy['digest'], 'policy.digest');
    _expectDigest(issues, policy['payloadDigest'], 'policy.payloadDigest');
    final requirements = _expectMap(
      issues,
      policy['requirements'],
      'policy.requirements',
    );
    if (requirements == null) return;
    for (final field in const [
      'minScenarioCount',
      'minScenariosPerAgentKind',
      'minScenariosPerCapability',
      'minScenariosPerRequiredCapabilitySplit',
      'minCapabilityCount',
      'minAdversarialScenarioCount',
      'minAdversarialScenariosPerAgentKind',
      'minAdversarialScenariosPerCapability',
      'minProductionReplayHoldoutScenarios',
      'minProtectedHoldoutScenarios',
      'minProtectedHoldoutScenariosPerAgentKind',
      'minProtectedHoldoutScenariosPerRequiredCapability',
      'minProfilesPerModelClass',
      'minTrialsPerProfile',
    ]) {
      _expectNonNegativeInt(
        issues,
        requirements[field],
        'policy.requirements.$field',
      );
    }
    for (final field in const [
      'requiredModelClasses',
      'requiredPrimaryCapabilityIds',
      'requiredSplits',
      'requiredAgentKinds',
      'requiredAdversarialTags',
    ]) {
      _expectStringList(
        issues,
        requirements[field],
        'policy.requirements.$field',
      );
    }
    _expectBool(
      issues,
      requirements['requireProtectedHoldout'],
      'policy.requirements.requireProtectedHoldout',
    );
    _expectBool(
      issues,
      requirements['requireAdversarialTagCoveragePerAgentKind'],
      'policy.requirements.requireAdversarialTagCoveragePerAgentKind',
    );
    _expectBool(
      issues,
      requirements['requireReviewedScenarioEvidence'],
      'policy.requirements.requireReviewedScenarioEvidence',
    );
  }

  static void _validateSource(
    List<String> issues,
    Map<String, dynamic>? source,
  ) {
    if (source == null) return;
    _expectDigest(
      issues,
      source['scenarioSetDigest'],
      'source.scenarioSetDigest',
    );
    final catalogMode = _expectNonEmptyString(
      issues,
      source['catalogMode'],
      'source.catalogMode',
    );
    if (catalogMode != null && !_allowedCatalogModes.contains(catalogMode)) {
      issues.add('source.catalogMode must be append or replace');
    }
    _expectBool(
      issues,
      source['usesExternalCatalog'],
      'source.usesExternalCatalog',
    );
    _expectNonNegativeInt(
      issues,
      source['publicScenarioCount'],
      'source.publicScenarioCount',
    );
    _expectNonNegativeInt(
      issues,
      source['externalScenarioCount'],
      'source.externalScenarioCount',
    );
    if (source.containsKey('externalCatalogDigest')) {
      _expectDigest(
        issues,
        source['externalCatalogDigest'],
        'source.externalCatalogDigest',
      );
    }
    if (source.containsKey('externalCatalogId')) {
      _expectNonEmptyString(
        issues,
        source['externalCatalogId'],
        'source.externalCatalogId',
      );
    }
    _expectBool(
      issues,
      source['protectedHoldout'],
      'source.protectedHoldout',
    );
    _expectBool(
      issues,
      source['protectedIdsOmitted'],
      'source.protectedIdsOmitted',
    );
    if (source['protectedIdsOmitted'] != true) {
      issues.add('source.protectedIdsOmitted must be true');
    }
  }

  static void _validateSelection(
    List<String> issues,
    Map<String, dynamic>? selection,
  ) {
    if (selection == null) return;
    _expectBool(
      issues,
      selection['selectedSubset'],
      'selection.selectedSubset',
    );
    _expectNonNegativeInt(
      issues,
      selection['selectedScenarioCount'],
      'selection.selectedScenarioCount',
    );
    _expectBool(
      issues,
      selection['scenarioIdsOmitted'],
      'selection.scenarioIdsOmitted',
    );
    if (selection['scenarioIdsOmitted'] != true) {
      issues.add('selection.scenarioIdsOmitted must be true');
    }
    _expectNonEmptyString(issues, selection['reason'], 'selection.reason');
  }

  static void _validateProfiles(
    List<String> issues,
    Map<String, dynamic>? profiles,
  ) {
    if (profiles == null) return;
    _expectDigest(
      issues,
      profiles['profileSetDigest'],
      'profiles.profileSetDigest',
    );
    _expectNonNegativeInt(
      issues,
      profiles['profileCount'],
      'profiles.profileCount',
    );
    _expectStringIntMap(
      issues,
      profiles['modelClassCounts'],
      'profiles.modelClassCounts',
    );
    _expectNonNegativeInt(
      issues,
      profiles['minObservedTrialCount'],
      'profiles.minObservedTrialCount',
    );
    _expectNonNegativeInt(
      issues,
      profiles['maxObservedTrialCount'],
      'profiles.maxObservedTrialCount',
    );
    _expectStringIntMap(
      issues,
      profiles['profilesBelowMinTrialCount'],
      'profiles.profilesBelowMinTrialCount',
    );
    _expectBool(
      issues,
      profiles['profilesBelowMinTrialCountProfileNamesOmitted'],
      'profiles.profilesBelowMinTrialCountProfileNamesOmitted',
    );
    if (profiles['profilesBelowMinTrialCountProfileNamesOmitted'] != true) {
      issues.add(
        'profiles.profilesBelowMinTrialCountProfileNamesOmitted must be true',
      );
    }
  }

  static void _validateCoverage(
    List<String> issues,
    Map<String, dynamic>? coverage,
  ) {
    if (coverage == null) return;
    _expectNonNegativeInt(
      issues,
      coverage['scenarioCount'],
      'coverage.scenarioCount',
    );
    for (final field in const [
      'agentKindCounts',
      'splitCounts',
      'primaryCapabilityCounts',
      'primaryCapabilitySplitCounts',
    ]) {
      _expectStringIntMap(issues, coverage[field], 'coverage.$field');
    }
    _expectStringList(
      issues,
      coverage['requiredPrimaryCapabilityIds'],
      'coverage.requiredPrimaryCapabilityIds',
    );
    _expectStringList(
      issues,
      coverage['missingRequiredPrimaryCapabilityIds'],
      'coverage.missingRequiredPrimaryCapabilityIds',
    );
    _expectNonNegativeInt(
      issues,
      coverage['missingRequiredPrimaryCapabilityCount'],
      'coverage.missingRequiredPrimaryCapabilityCount',
    );
    _expectStringList(
      issues,
      coverage['missingRequiredCapabilitySplitCells'],
      'coverage.missingRequiredCapabilitySplitCells',
    );
    _expectNonNegativeInt(
      issues,
      coverage['missingRequiredCapabilitySplitCellCount'],
      'coverage.missingRequiredCapabilitySplitCellCount',
    );
  }

  static void _validateAdversarial(
    List<String> issues,
    Map<String, dynamic>? adversarial,
  ) {
    if (adversarial == null) return;
    _expectNonNegativeInt(
      issues,
      adversarial['scenarioCount'],
      'adversarial.scenarioCount',
    );
    _expectStringIntMap(
      issues,
      adversarial['agentKindCounts'],
      'adversarial.agentKindCounts',
    );
    _expectStringIntMap(
      issues,
      adversarial['primaryCapabilityCounts'],
      'adversarial.primaryCapabilityCounts',
    );
    _expectStringIntMap(
      issues,
      adversarial['stressTagAgentKindCounts'],
      'adversarial.stressTagAgentKindCounts',
    );
    _expectStringList(
      issues,
      adversarial['tagsPresent'],
      'adversarial.tagsPresent',
    );
    _expectStringList(
      issues,
      adversarial['missingTags'],
      'adversarial.missingTags',
    );
    _expectStringList(
      issues,
      adversarial['missingStressTagAgentKindCells'],
      'adversarial.missingStressTagAgentKindCells',
    );
    _expectNonNegativeInt(
      issues,
      adversarial['missingStressTagAgentKindCellCount'],
      'adversarial.missingStressTagAgentKindCellCount',
    );
  }

  static void _validateHoldout(
    List<String> issues,
    Map<String, dynamic>? holdout,
  ) {
    if (holdout == null) return;
    for (final field in const [
      'productionReplayHoldoutScenarioCount',
      'protectedHoldoutScenarioCount',
      'duplicateProtectedHoldoutScenarioIdCount',
      'duplicateProtectedHoldoutSourceDigestCount',
    ]) {
      _expectNonNegativeInt(issues, holdout[field], 'holdout.$field');
    }
    _expectStringIntMap(
      issues,
      holdout['protectedHoldoutAgentKindCounts'],
      'holdout.protectedHoldoutAgentKindCounts',
    );
    _expectStringIntMap(
      issues,
      holdout['protectedHoldoutPrimaryCapabilityCounts'],
      'holdout.protectedHoldoutPrimaryCapabilityCounts',
    );
    _expectStringList(
      issues,
      holdout['missingProtectedHoldoutPrimaryCapabilityIds'],
      'holdout.missingProtectedHoldoutPrimaryCapabilityIds',
    );
    _expectNonNegativeInt(
      issues,
      holdout['missingProtectedHoldoutPrimaryCapabilityCount'],
      'holdout.missingProtectedHoldoutPrimaryCapabilityCount',
    );
  }

  static void _validateReviews(
    List<String> issues,
    Map<String, dynamic>? reviews,
  ) {
    if (reviews == null) return;
    for (final field in const [
      'requiredCount',
      'completedCount',
      'missingCount',
      'incompleteCount',
      'invalidCount',
      'staleCount',
      'missingSourceDigestCount',
    ]) {
      _expectNonNegativeInt(issues, reviews[field], 'reviews.$field');
    }
  }

  static void _validateLimitations(
    List<String> issues,
    Map<String, dynamic>? limitations,
  ) {
    if (limitations == null) return;
    for (final field in const [
      'tracesEvaluated',
      'judgeVerdictsEvaluated',
      'providerProvenanceEvaluated',
      'modelPerformanceEvaluated',
      'humanCalibrationEvaluated',
      'pairwisePreferenceEvaluated',
      'promotionReadinessEvaluated',
    ]) {
      _expectBool(issues, limitations[field], 'limitations.$field');
      if (limitations[field] != false) {
        issues.add('limitations.$field must be false');
      }
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
      _expectNonEmptyString(
        issues,
        issue['category'],
        'issues[$index].category',
      );
      if (issue.containsKey('dimension')) {
        _expectNonEmptyString(
          issues,
          issue['dimension'],
          'issues[$index].dimension',
        );
      }
      if (issue.containsKey('value')) {
        _expectNonEmptyString(
          issues,
          issue['value'],
          'issues[$index].value',
        );
      }
      for (final field in const ['actual', 'required', 'count']) {
        if (issue.containsKey(field)) {
          _expectNonNegativeInt(issues, issue[field], 'issues[$index].$field');
        }
      }
    }
  }

  static void _validateNextPlan(
    List<String> issues,
    Map<String, dynamic>? plan,
    String? status,
  ) {
    if (plan == null) return;
    _expectEquals(
      issues,
      plan['schemaVersion'],
      schemaVersion,
      'nextExperimentPlan.schemaVersion',
    );
    _expectEquals(
      issues,
      plan['kind'],
      nextExperimentPlanKind,
      'nextExperimentPlan.kind',
    );
    final planStatus = _expectNonEmptyString(
      issues,
      plan['status'],
      'nextExperimentPlan.status',
    );
    if (status != null && planStatus != null && planStatus != status) {
      issues.add('nextExperimentPlan.status must match preflight status');
    }
    _expectNonEmptyString(
      issues,
      plan['objective'],
      'nextExperimentPlan.objective',
    );
    _expectStringList(
      issues,
      plan['blockedReasonCodes'],
      'nextExperimentPlan.blockedReasonCodes',
    );
    _validatePlanRecords(
      issues,
      _expectList(
        issues,
        plan['evidenceNeeds'],
        'nextExperimentPlan.evidenceNeeds',
      ),
      'nextExperimentPlan.evidenceNeeds',
    );
    _validateSafeSelectors(
      issues,
      _expectMap(
        issues,
        plan['safeSelectors'],
        'nextExperimentPlan.safeSelectors',
      ),
      'nextExperimentPlan.safeSelectors',
    );
    _validateWithheldSelectors(
      issues,
      _expectMap(
        issues,
        plan['withheldSelectors'],
        'nextExperimentPlan.withheldSelectors',
      ),
    );
    _validatePlanRecords(
      issues,
      _expectList(
        issues,
        plan['manualPrerequisites'],
        'nextExperimentPlan.manualPrerequisites',
      ),
      'nextExperimentPlan.manualPrerequisites',
    );
    _validateEnvMap(
      issues,
      _expectMap(issues, plan['nextRunEnv'], 'nextExperimentPlan.nextRunEnv'),
      'nextExperimentPlan.nextRunEnv',
    );
    _validateRecommendedCommands(
      issues,
      _expectList(
        issues,
        plan['recommendedCommands'],
        'nextExperimentPlan.recommendedCommands',
      ),
      planStatus,
    );
  }

  static void _validatePlanRecords(
    List<String> issues,
    List<dynamic>? records,
    String path,
  ) {
    if (records == null) return;
    for (final (index, value) in records.indexed) {
      final record = _expectMap(issues, value, '$path[$index]');
      if (record == null) continue;
      _expectNonEmptyString(issues, record['code'], '$path[$index].code');
      _expectNonEmptyString(issues, record['action'], '$path[$index].action');
    }
  }

  static void _validateSafeSelectors(
    List<String> issues,
    Map<String, dynamic>? selectors,
    String path,
  ) {
    if (selectors == null) return;
    for (final field in const [
      'capabilities',
      'adversarialTags',
      'agentKinds',
      'modelClasses',
    ]) {
      final values = _expectStringList(
        issues,
        selectors[field],
        '$path.$field',
      );
      if (values == null) continue;
      for (final value in values) {
        if (!_safeSelectorPattern.hasMatch(value)) {
          issues.add('$path.$field contains unsafe selector "$value"');
        }
      }
    }
  }

  static void _validateWithheldSelectors(
    List<String> issues,
    Map<String, dynamic>? selectors,
  ) {
    if (selectors == null) return;
    _expectBool(
      issues,
      selectors['scenarioIdsOmitted'],
      'nextExperimentPlan.withheldSelectors.scenarioIdsOmitted',
    );
    if (selectors['scenarioIdsOmitted'] != true) {
      issues.add(
        'nextExperimentPlan.withheldSelectors.scenarioIdsOmitted must be true',
      );
    }
    for (final field in const [
      'selectedSubsetScenarioCount',
      'protectedScenarioReferenceCount',
      'protectedHoldoutReferenceCount',
    ]) {
      _expectNonNegativeInt(
        issues,
        selectors[field],
        'nextExperimentPlan.withheldSelectors.$field',
      );
    }
    _expectNonEmptyString(
      issues,
      selectors['reason'],
      'nextExperimentPlan.withheldSelectors.reason',
    );
  }

  static void _validateEnvMap(
    List<String> issues,
    Map<String, dynamic>? env,
    String path,
  ) {
    if (env == null) return;
    for (final entry in env.entries) {
      if (!_allowedNextRunEnvKeys.contains(entry.key)) {
        issues.add('$path must not contain ${entry.key}');
      }
      if (_privateValueEnvKeys.contains(entry.key)) {
        issues.add('$path must not contain value-bearing ${entry.key}');
      }
      if (!_safeSelectorPattern.hasMatch(entry.key)) {
        issues.add('$path contains unsafe env key "${entry.key}"');
      }
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) {
        issues.add('$path.${entry.key} must be a non-empty string');
      } else if (entry.key == 'EVAL_SCENARIOS_MODE' &&
          !_allowedCatalogModes.contains(value)) {
        issues.add('$path.EVAL_SCENARIOS_MODE must be append or replace');
      } else if (!_safeEnvValue(value)) {
        issues.add('$path.${entry.key} contains an unsafe value');
      }
    }
  }

  static void _validateRecommendedCommands(
    List<String> issues,
    List<dynamic>? commands,
    String? status,
  ) {
    if (commands == null) return;
    final expectedModes = status == 'catalogReady'
        ? const ['catalog', 'plan', 'run', 'tune']
        : const ['catalog'];
    final modes = <String>[];
    for (final (index, value) in commands.indexed) {
      final command = _expectMap(
        issues,
        value,
        'nextExperimentPlan.recommendedCommands[$index]',
      );
      if (command == null) continue;
      _validateAllowedKeys(
        issues,
        command,
        _allowedRecommendedCommandFields,
        'nextExperimentPlan.recommendedCommands[$index]',
      );
      final mode = _expectNonEmptyString(
        issues,
        command['mode'],
        'nextExperimentPlan.recommendedCommands[$index].mode',
      );
      final commandText = _expectNonEmptyString(
        issues,
        command['commandTemplate'],
        'nextExperimentPlan.recommendedCommands[$index].commandTemplate',
      );
      if (command.containsKey('env')) {
        issues.add(
          'nextExperimentPlan.recommendedCommands[$index] must not contain env values',
        );
      }
      if (command.containsKey('command')) {
        issues.add(
          'nextExperimentPlan.recommendedCommands[$index] must use commandTemplate only',
        );
      }
      if (mode != null) {
        modes.add(mode);
        if (!expectedModes.contains(mode)) {
          issues.add(
            'nextExperimentPlan.recommendedCommands[$index].mode must be supported',
          );
        }
      }
      if (mode != null && commandText != null) {
        final expected = mode == 'catalog'
            ? 'eval/run_level2.sh catalog'
            : 'eval/run_level2.sh $mode <nextRunId>';
        if (commandText != expected) {
          issues.add(
            'nextExperimentPlan.recommendedCommands[$index].commandTemplate must be $expected',
          );
        }
        if (_shellSmugglingPattern.hasMatch(commandText)) {
          issues.add(
            'nextExperimentPlan.recommendedCommands[$index].commandTemplate must not contain shell wrappers or inline env',
          );
        }
      }
      _expectEquals(
        issues,
        command['valuesOmitted'],
        true,
        'nextExperimentPlan.recommendedCommands[$index].valuesOmitted',
      );
    }
    if (modes.length != modes.toSet().length) {
      issues.add('nextExperimentPlan.recommendedCommands modes must be unique');
    }
    if (!_sameStrings(modes, expectedModes)) {
      issues.add(
        'nextExperimentPlan.recommendedCommands modes must match ${expectedModes.join(', ')}',
      );
    }
  }

  static bool _safeEnvValue(String value) =>
      value.split(',').every(_safeSelectorPattern.hasMatch);

  static bool _sameStrings(List<String> actual, List<String> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index += 1) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }

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

  static void _validateNoScenarioIds(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase();
        if (normalized == 'scenarioid' ||
            normalized == 'scenarioids' ||
            normalized.endsWith('scenarioids')) {
          issues.add('$path.$key must not expose scenario ids');
        }
        _validateNoScenarioIds(issues, entry.value, '$path.$key');
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoScenarioIds(issues, item, '$path[$index]');
      }
      return;
    }
    if (value is String) {
      if (value.contains('<protected-scenario>')) {
        issues.add('$path must not contain protected scenario placeholders');
      }
      if (value.contains('EVAL_SCENARIO_IDS')) {
        issues.add('$path must not contain EVAL_SCENARIO_IDS');
      }
    }
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
      if (_privateEnvTokenPattern.hasMatch(value)) {
        issues.add('$path must not contain private env value keys');
      }
    }
  }

  static String? _privateFieldReason(String normalized) {
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

  static void _validateNoProtectedValues(
    List<String> issues,
    Object? value,
    String path,
    Set<String> protectedValues,
  ) {
    if (protectedValues.isEmpty) return;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (protectedValues.contains(key)) {
          issues.add('$path.$key must not expose protected values');
        }
        _validateNoProtectedValues(
          issues,
          entry.value,
          '$path.$key',
          protectedValues,
        );
      }
      return;
    }
    if (value is List) {
      for (final (index, item) in value.indexed) {
        _validateNoProtectedValues(
          issues,
          item,
          '$path[$index]',
          protectedValues,
        );
      }
      return;
    }
    if (value is String && protectedValues.contains(value)) {
      issues.add('$path must not expose protected values');
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

  static void _expectStringIntMap(
    List<String> issues,
    Object? value,
    String path,
  ) {
    if (value is! Map<String, dynamic>) {
      issues.add('$path must be a JSON object');
      return;
    }
    for (final entry in value.entries) {
      if (entry.value is! int || (entry.value as int) < 0) {
        issues.add('$path.${entry.key} must be a non-negative integer');
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
