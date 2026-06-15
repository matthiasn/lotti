import 'package:collection/collection.dart';

import 'eval_judge_calibration.dart';
import 'eval_models.dart';
import 'eval_pairwise_preference.dart';
import 'eval_provenance.dart';
import 'eval_reporter.dart';
import 'eval_run_verifier.dart';
import 'eval_statistics.dart';
import 'eval_tuning_readiness.dart';
import 'eval_tuning_report_contract.dart';
import 'trace_writer.dart';

enum EvalTuningReportSourceCheckStatus {
  sourceChecked,
  sourceInvalid,
  sourceMissing,
}

Map<String, dynamic> _immutableJsonMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries) entry.key: _immutableJson(entry.value),
    });

Object? _immutableJson(Object? value) {
  if (value is Map<String, dynamic>) return _immutableJsonMap(value);
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _immutableJson(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_immutableJson));
  }
  return value;
}

class EvalTuningReportSourceCheckResult {
  EvalTuningReportSourceCheckResult({
    required this.reportDigest,
    required this.sourceCheckStatus,
    required List<String> sourceIssueCodes,
    required Map<String, dynamic> sourceSummary,
    this.manifestDigest,
  }) : sourceIssueCodes = List.unmodifiable(sourceIssueCodes),
       sourceSummary = _immutableJsonMap(sourceSummary),
       _validatedSourceCheck = false;

  EvalTuningReportSourceCheckResult._validated({
    required this.reportDigest,
    required this.sourceCheckStatus,
    required List<String> sourceIssueCodes,
    required Map<String, dynamic> sourceSummary,
    this.manifestDigest,
  }) : sourceIssueCodes = List.unmodifiable(sourceIssueCodes),
       sourceSummary = _immutableJsonMap(sourceSummary),
       _validatedSourceCheck = true;

  factory EvalTuningReportSourceCheckResult.missing(
    Map<String, dynamic> report, {
    String issueCode = 'report.sourceRunMissing',
  }) {
    return EvalTuningReportSourceCheckResult(
      reportDigest: EvalProvenance.digestJson(report),
      sourceCheckStatus: EvalTuningReportSourceCheckStatus.sourceMissing,
      sourceIssueCodes: [issueCode],
      sourceSummary: const <String, dynamic>{},
    );
  }

  final String reportDigest;
  final String? manifestDigest;
  final EvalTuningReportSourceCheckStatus sourceCheckStatus;
  final List<String> sourceIssueCodes;
  final Map<String, dynamic> sourceSummary;
  final bool _validatedSourceCheck;

  bool get isSourceChecked =>
      _validatedSourceCheck &&
      sourceCheckStatus == EvalTuningReportSourceCheckStatus.sourceChecked &&
      sourceIssueCodes.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': 1,
    'kind': 'lotti.evalTuningReportSourceCheck',
    'reportDigest': reportDigest,
    if (manifestDigest != null) 'manifestDigest': manifestDigest,
    'sourceCheckStatus': sourceCheckStatus.name,
    'sourceIssueCount': sourceIssueCodes.length,
    'sourceIssueCodes': sourceIssueCodes,
    'sourceSummary': sourceSummary,
  };
}

abstract final class EvalTuningReportSourceCheck {
  static EvalTuningReportSourceCheckResult validateReport({
    required Map<String, dynamic> report,
    required EvalRunArtifacts sourceRun,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required List<EvalAgentDirectiveVariant> agentDirectiveVariants,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    JudgeCalibrationSet? calibrationSet,
    List<EvalPairwisePreferenceVote>? pairwisePreferenceVotes,
    Map<String, EvalPairwiseTraceRef>? pairwiseTraceRefsByKey,
    EvalPromotionPlan? promotionPlan,
    ProfilePromotionDecision? promotionDecision,
  }) {
    final issueCodes = <String>{};
    void addIssue(String code) => issueCodes.add(code);

    final publicContractIssues = EvalTuningReportContract.validate(report);
    if (publicContractIssues.isNotEmpty) {
      addIssue('report.contractInvalid');
    }

    final sourceManifestDigest =
        sourceRun.manifest.manifestDigest ??
        EvalProvenance.manifestDigest(sourceRun.manifest);
    final run = _map(report['run']);
    _compareString(
      issueCodes,
      actual: _string(run['runId']),
      expected: sourceRun.manifest.runId,
      issueCode: 'report.sourceRunIdMismatch',
    );
    _compareString(
      issueCodes,
      actual: _string(run['manifestDigest']),
      expected: sourceManifestDigest,
      issueCode: 'report.sourceManifestDigestMismatch',
    );
    _compareString(
      issueCodes,
      actual: _string(run['targetKind']),
      expected: sourceRun.manifest.targetKind,
      issueCode: 'report.sourceTargetKindMismatch',
    );
    _compareString(
      issueCodes,
      actual: _string(run['scenarioSetDigest']),
      expected: sourceRun.manifest.scenarioSetDigest,
      issueCode: 'report.sourceScenarioSetDigestMismatch',
    );
    _compareString(
      issueCodes,
      actual: _string(run['profileSetDigest']),
      expected: sourceRun.manifest.profileSetDigest,
      issueCode: 'report.sourceProfileSetDigestMismatch',
    );
    _compareString(
      issueCodes,
      actual: _string(run['profileBindingSetDigest']),
      expected: sourceRun.manifest.profileBindingSetDigest,
      issueCode: 'report.sourceProfileBindingSetDigestMismatch',
    );
    _compareString(
      issueCodes,
      actual: _string(run['agentDirectiveVariantSetDigest']),
      expected: sourceRun.manifest.agentDirectiveVariantSetDigest,
      issueCode: 'report.sourcePromptVariantSetDigestMismatch',
    );

    EvalTuningPolicy? policy;
    final policyJson = _map(report['policy']);
    try {
      policy = EvalTuningPolicy.fromJson(_map(policyJson['payload']));
    } on FormatException {
      addIssue('report.sourcePolicyInvalid');
    }
    if (policy != null) {
      _compareString(
        issueCodes,
        actual: _string(policyJson['name']),
        expected: policy.name,
        issueCode: 'report.sourcePolicyNameMismatch',
      );
    }
    final reportPolicyDigest = _string(policyJson['digest']);
    if (policy != null && reportPolicyDigest != policy.policyDigest) {
      addIssue('report.sourcePolicyDigestMismatch');
    }
    final manifestPolicyEvidence =
        sourceRun.manifest.tuningReadinessPolicyEvidence;
    if (manifestPolicyEvidence == null) {
      addIssue('report.sourcePolicyEvidenceMissing');
    } else if (policy != null) {
      _compareString(
        issueCodes,
        actual: manifestPolicyEvidence.policyName,
        expected: policy.name,
        issueCode: 'report.sourcePolicyEvidenceMismatch',
      );
      _compareString(
        issueCodes,
        actual: manifestPolicyEvidence.policyDigest,
        expected: policy.policyDigest,
        issueCode: 'report.sourcePolicyEvidenceMismatch',
      );
    }

    final verification = EvalRunVerifier.verify(
      runId: sourceRun.manifest.runId,
      traces: sourceRun.traces,
      scenarios: scenarios,
      profiles: profiles,
      agentDirectiveVariants: agentDirectiveVariants,
      manifest: sourceRun.manifest,
      artifactNames: sourceRun.artifactNames,
      tuningPolicy: policy,
    );
    if (verification.errors.isNotEmpty) {
      addIssue('report.sourceRunVerificationFailed');
    }

    final artifactSnapshot = _tuningArtifactSnapshotJson(sourceRun);
    _compareJson(
      issueCodes,
      actual: _map(run['artifactSnapshot']),
      expected: artifactSnapshot,
      issueCode: 'report.sourceArtifactSnapshotMismatch',
    );

    final promotion = _map(report['promotion']);
    final reportPromotionStatus = _string(promotion['status']);
    final promotionClaimed =
        promotion['present'] == true ||
        (reportPromotionStatus.isNotEmpty &&
            reportPromotionStatus != 'notRequested');
    EvalTuningReadinessReport? readiness;
    ProfilePromotionDecision? sourcePromotionDecision;
    var sourceSlices = const <Map<String, dynamic>>[];
    if (policy != null) {
      final effectiveCatalogEvidence = _effectiveCatalogEvidence(
        manifestEvidence: sourceRun.manifest.scenarioCatalogEvidence,
        loadedEvidence: scenarioCatalogEvidence,
      );
      final protectedIdsRedacted =
          effectiveCatalogEvidence?.usesExternalCatalog ?? false;
      _compareJson(
        issueCodes,
        actual: _map(run['selectors']),
        expected: _sourceSelectorsJson(
          scenarios: scenarios,
          profiles: profiles,
          agentDirectiveVariants: agentDirectiveVariants,
          policy: policy,
          protectedIdsRedacted: protectedIdsRedacted,
        ),
        issueCode: 'report.sourceSelectorsMismatch',
      );
      _compareJson(
        issueCodes,
        actual: run['protectedIdsRedacted'] == true,
        expected: protectedIdsRedacted,
        issueCode: 'report.sourceProtectedIdsRedactedMismatch',
      );
      if (protectedIdsRedacted) {
        _compareJson(
          issueCodes,
          actual: _int(run['redactedScenarioIdCount']),
          expected: _redactedScenarioIdCount(
            scenarios: scenarios,
            catalogEvidence: effectiveCatalogEvidence,
          ),
          issueCode: 'report.sourceRedactedScenarioIdCountMismatch',
        );
      }
      final calibrationRequired =
          policy.requireCalibrationReport ||
          _map(report['calibration'])['present'] == true;
      if (calibrationRequired && calibrationSet == null) {
        addIssue('report.sourceCalibrationMissing');
      }
      final pairwiseRequired =
          policy.requiresBlindedPairwisePreferences ||
          _map(report['pairwise'])['present'] == true;
      if (pairwiseRequired && pairwisePreferenceVotes == null) {
        addIssue('report.sourcePairwiseMissing');
      }

      readiness = EvalTuningReadiness.assess(
        traces: sourceRun.traces,
        scenarios: scenarios,
        profiles: profiles,
        manifest: sourceRun.manifest,
        scenarioCatalogEvidence: effectiveCatalogEvidence,
        policy: policy,
        calibrationSet: calibrationSet,
        pairwisePreferenceVotes:
            pairwisePreferenceVotes ?? const <EvalPairwisePreferenceVote>[],
        pairwiseTraceRefsByKey:
            pairwiseTraceRefsByKey ?? const <String, EvalPairwiseTraceRef>{},
      );

      _compareJson(
        issueCodes,
        actual: _map(report['status']),
        expected: _statusJson(readiness),
        issueCode: 'report.sourceStatusMismatch',
      );
      _compareJson(
        issueCodes,
        actual: _coverageSummary(_map(report['coverage'])),
        expected: _coverageJson(
          readiness,
          promptVariantCount: agentDirectiveVariants.length,
        ),
        issueCode: 'report.sourceCoverageMismatch',
      );
      _compareJson(
        issueCodes,
        actual: _map(report['readiness']),
        expected: _readinessJson(readiness),
        issueCode: 'report.sourceReadinessMismatch',
      );

      sourceSlices = _tuningUseCaseSlices(
        traces: sourceRun.traces,
        policy: policy,
        catalogEvidence: effectiveCatalogEvidence,
      );
      if (promotionPlan != null) {
        final promotionPolicy = ProfilePromotionPolicy(
          candidateProfileName: promotionPlan.candidateProfileName,
          baselineProfileName: promotionPlan.baselineProfileName,
        );
        _validatePromotionPlanBinding(
          issueCodes: issueCodes,
          promotionPlan: promotionPlan,
          promotionPolicy: promotionPolicy,
          sourceRun: sourceRun,
          sourceManifestDigest: sourceManifestDigest,
        );
        sourcePromotionDecision = EvalReporter.evaluateProfilePromotion(
          traces: sourceRun.traces,
          policy: promotionPolicy,
          readinessReport: readiness,
        );
        if (promotionDecision != null) {
          _compareJson(
            issueCodes,
            actual: _promotionDecisionJson(promotionDecision),
            expected: _promotionDecisionJson(sourcePromotionDecision),
            issueCode: 'report.sourcePromotionDecisionMismatch',
          );
        }
      }
      _compareJson(
        issueCodes,
        actual: _mapList(report['useCaseModelSlices']),
        expected: sourceSlices,
        issueCode: 'report.sourceUseCaseModelSlicesMismatch',
      );
      _compareJson(
        issueCodes,
        actual: _blockedReasonCodes(report),
        expected: _sourceBlockedReasonCodes(
          readiness: readiness,
          sourceSlices: sourceSlices,
          promotionDecision: sourcePromotionDecision,
        ),
        issueCode: 'report.sourceBlockedReasonsMismatch',
      );
    }

    if (promotionClaimed && promotionPlan == null) {
      addIssue('report.sourcePromotionMissing');
      if (promotionDecision != null) {
        addIssue('report.sourcePromotionPlanMissing');
      }
    } else if (sourcePromotionDecision != null) {
      _compareJson(
        issueCodes,
        actual: promotion,
        expected: _promotionDecisionJson(sourcePromotionDecision),
        issueCode: 'report.sourcePromotionMismatch',
      );
    } else if (promotionClaimed) {
      addIssue('report.sourcePromotionMissing');
    }

    final sortedIssues = issueCodes.toList()..sort();
    return EvalTuningReportSourceCheckResult._validated(
      reportDigest: EvalProvenance.digestJson(report),
      manifestDigest: sourceManifestDigest,
      sourceCheckStatus: sortedIssues.isEmpty
          ? EvalTuningReportSourceCheckStatus.sourceChecked
          : EvalTuningReportSourceCheckStatus.sourceInvalid,
      sourceIssueCodes: sortedIssues,
      sourceSummary: <String, dynamic>{
        'manifestDigest': sourceManifestDigest,
        'scenarioSetDigest': sourceRun.manifest.scenarioSetDigest,
        'profileSetDigest': sourceRun.manifest.profileSetDigest,
        'agentDirectiveVariantSetDigest':
            sourceRun.manifest.agentDirectiveVariantSetDigest,
        'artifactSnapshotDigest': EvalProvenance.digestJson(artifactSnapshot),
        if (policy != null) 'policyDigest': policy.policyDigest,
        if (policy != null)
          'publicSelectors': _sourcePublicSelectorsJson(
            agentDirectiveVariants: agentDirectiveVariants,
            policy: policy,
          ),
        if (policy != null)
          'selectorDigest': EvalProvenance.digestJson(
            _sourceSelectorsJson(
              scenarios: scenarios,
              profiles: profiles,
              agentDirectiveVariants: agentDirectiveVariants,
              policy: policy,
              protectedIdsRedacted:
                  _effectiveCatalogEvidence(
                    manifestEvidence:
                        sourceRun.manifest.scenarioCatalogEvidence,
                    loadedEvidence: scenarioCatalogEvidence,
                  )?.usesExternalCatalog ??
                  false,
            ),
          ),
        'traceCount': sourceRun.traces.length,
        'judgedTraceCount': sourceRun.traces
            .where((trace) => trace.verdict != null)
            .length,
        if (readiness != null)
          'readinessDigest': EvalProvenance.digestJson(
            _readinessJson(readiness),
          ),
        if (sourceSlices.isNotEmpty)
          'useCaseModelSlicesDigest': EvalProvenance.digestJson(sourceSlices),
        if (sourcePromotionDecision != null)
          'promotionDigest': EvalProvenance.digestJson(
            _promotionDecisionJson(sourcePromotionDecision),
          ),
        if (sourceRun.manifest.useCaseWorkOrderLaunchEvidence != null)
          'workOrderLaunch': _workOrderLaunchSummary(
            sourceRun.manifest.useCaseWorkOrderLaunchEvidence!,
          ),
      },
    );
  }
}

Map<String, dynamic> _tuningArtifactSnapshotJson(EvalRunArtifacts run) {
  final traceSnapshots =
      [
        for (final trace in run.traces)
          <String, dynamic>{
            'scenarioDigest': trace.provenance.scenarioDigest,
            'profileDigest': trace.provenance.profileDigest,
            'agentDirectiveVariantDigest':
                trace.provenance.agentDirectiveVariantDigest,
            'trialIndex': trace.trialIndex,
            if (trace.cascadeWake != null)
              'cascadeWakeKey': trace.cascadeWake!.keySuffix,
            'hasVerdict': trace.verdict != null,
            'traceJsonDigest': EvalProvenance.digestJson(trace.toJson()),
          },
      ]..sort((a, b) {
        final scenario = (a['scenarioDigest'] as String).compareTo(
          b['scenarioDigest'] as String,
        );
        if (scenario != 0) return scenario;
        final profile = (a['profileDigest'] as String).compareTo(
          b['profileDigest'] as String,
        );
        if (profile != 0) return profile;
        final variant = (a['agentDirectiveVariantDigest'] as String).compareTo(
          b['agentDirectiveVariantDigest'] as String,
        );
        if (variant != 0) return variant;
        final trial = (a['trialIndex'] as int).compareTo(
          b['trialIndex'] as int,
        );
        if (trial != 0) return trial;
        return (a['cascadeWakeKey'] as String? ?? '').compareTo(
          b['cascadeWakeKey'] as String? ?? '',
        );
      });
  final manifestDigest =
      run.manifest.manifestDigest ??
      EvalProvenance.manifestDigest(run.manifest);
  final ownedArtifactRefs = <Map<String, dynamic>>[
    <String, dynamic>{
      'kind': 'manifest',
      'manifestDigest': manifestDigest,
    },
    for (final trace in traceSnapshots) ...[
      <String, dynamic>{
        'kind': 'trace',
        'scenarioDigest': trace['scenarioDigest'],
        'profileDigest': trace['profileDigest'],
        'agentDirectiveVariantDigest': trace['agentDirectiveVariantDigest'],
        'trialIndex': trace['trialIndex'],
        if (trace.containsKey('cascadeWakeKey'))
          'cascadeWakeKey': trace['cascadeWakeKey'],
      },
      if (trace['hasVerdict'] == true)
        <String, dynamic>{
          'kind': 'verdict',
          'scenarioDigest': trace['scenarioDigest'],
          'profileDigest': trace['profileDigest'],
          'agentDirectiveVariantDigest': trace['agentDirectiveVariantDigest'],
          'trialIndex': trace['trialIndex'],
          if (trace.containsKey('cascadeWakeKey'))
            'cascadeWakeKey': trace['cascadeWakeKey'],
        },
    ],
  ];

  return <String, dynamic>{
    'artifactCount': ownedArtifactRefs.length,
    'traceCount': run.traces.length,
    'judgedTraceCount': run.traces
        .where((trace) => trace.verdict != null)
        .length,
    'manifestDigest': manifestDigest,
    'ownedArtifactRefsDigest': EvalProvenance.digestJson(ownedArtifactRefs),
    'loadedTraceContentDigest': EvalProvenance.digestJson(traceSnapshots),
  };
}

Map<String, dynamic> _statusJson(EvalTuningReadinessReport readiness) =>
    <String, dynamic>{
      'ready': readiness.ready,
      'label': readiness.evidenceLabel,
      'failureCount': readiness.failures.length,
      'warningCount': readiness.warnings.length,
    };

Map<String, dynamic> _coverageJson(
  EvalTuningReadinessReport readiness, {
  required int promptVariantCount,
}) => <String, dynamic>{
  'scenarioCount': readiness.scenarioCount,
  'profileCount': readiness.profileCount,
  'promptVariantCount': promptVariantCount,
  'expectedTraceCount': readiness.expectedTraceCount,
  'traceCount': readiness.traceCount,
  'judgedTraceCount': readiness.judgedTraceCount,
  'scenarioCountByAgentKind': _enumIntMapJson(
    readiness.evidence.scenarioCountByAgentKind,
  ),
  'scenarioCountBySplit': _enumIntMapJson(
    readiness.evidence.scenarioCountBySplit,
  ),
  'scenarioCountByPrimaryCapability': _stringIntMapJson(
    readiness.evidence.scenarioCountByPrimaryCapability,
  ),
  'missingRequiredPrimaryCapabilityIds': _sortedStrings(
    readiness.evidence.missingRequiredPrimaryCapabilityIds,
  ),
};

Map<String, dynamic> _coverageSummary(Map<String, dynamic> coverage) =>
    <String, dynamic>{
      for (final key in const [
        'scenarioCount',
        'profileCount',
        'promptVariantCount',
        'expectedTraceCount',
        'traceCount',
        'judgedTraceCount',
        'scenarioCountByAgentKind',
        'scenarioCountBySplit',
        'scenarioCountByPrimaryCapability',
        'missingRequiredPrimaryCapabilityIds',
      ])
        key: coverage[key],
    };

Map<String, dynamic> _readinessJson(EvalTuningReadinessReport readiness) =>
    <String, dynamic>{
      'ready': readiness.ready,
      'evidenceLabel': readiness.evidenceLabel,
      'policyName': readiness.policyName,
      'policyDigest': readiness.policyDigest,
      'expectedTraceCount': readiness.expectedTraceCount,
      'traceCount': readiness.traceCount,
      'judgedTraceCount': readiness.judgedTraceCount,
      'failures': readiness.failures,
      'warnings': readiness.warnings,
      'missingRequiredPrimaryCapabilityIds': _sortedStrings(
        readiness.evidence.missingRequiredPrimaryCapabilityIds,
      ),
    };

EvalScenarioCatalogEvidence? _effectiveCatalogEvidence({
  required EvalScenarioCatalogEvidence? manifestEvidence,
  required EvalScenarioCatalogEvidence? loadedEvidence,
}) {
  if (loadedEvidence?.usesExternalCatalog ?? false) return loadedEvidence;
  if (manifestEvidence?.usesExternalCatalog ?? false) return manifestEvidence;
  return manifestEvidence ?? loadedEvidence;
}

Map<String, dynamic> _sourceSelectorsJson({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  required List<EvalAgentDirectiveVariant> agentDirectiveVariants,
  required EvalTuningPolicy policy,
  required bool protectedIdsRedacted,
}) => <String, dynamic>{
  'scenarioIds': protectedIdsRedacted
      ? const <String>[]
      : _sortedStrings(scenarios.map((scenario) => scenario.id)),
  'profileNames': _sortedStrings(profiles.map((profile) => profile.name)),
  'promptVariantNames': _sortedStrings(
    agentDirectiveVariants.map((variant) => variant.name),
  ),
  'requiredPrimaryCapabilityIds': _sortedStrings(
    policy.requiredPrimaryCapabilityIds,
  ),
};

Map<String, dynamic> _sourcePublicSelectorsJson({
  required List<EvalAgentDirectiveVariant> agentDirectiveVariants,
  required EvalTuningPolicy policy,
}) => <String, dynamic>{
  'promptVariantNames': _sortedStrings(
    agentDirectiveVariants.map((variant) => variant.name),
  ),
  'requiredPrimaryCapabilityIds': _sortedStrings(
    policy.requiredPrimaryCapabilityIds,
  ),
};

int _redactedScenarioIdCount({
  required List<EvalScenario> scenarios,
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  if (catalogEvidence == null || !catalogEvidence.usesExternalCatalog) {
    return 0;
  }
  return _sortedStrings({
    ...catalogEvidence.protectedScenarioIds,
    ...catalogEvidence.protectedHoldoutScenarioIds,
    for (final scenario in scenarios) scenario.id,
  }).length;
}

List<Map<String, dynamic>> _tuningUseCaseSlices({
  required List<EvalTrace> traces,
  required EvalTuningPolicy policy,
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  final accumulators = <String, _TuningSliceAccumulator>{};
  for (final trace in traces) {
    if (trace.cascadeWake != null) continue;
    final capabilityId =
        trace.scenario.metadata.primaryCapabilityId ?? 'uncategorized';
    final key = [
      capabilityId,
      trace.scenario.agentKind.name,
      trace.profile.modelClass.name,
      trace.agentDirectiveVariant.name,
    ].join('|');
    accumulators
        .putIfAbsent(
          key,
          () => _TuningSliceAccumulator(
            primaryCapabilityId: capabilityId,
            agentKind: trace.scenario.agentKind.name,
            modelClass: trace.profile.modelClass.name,
            promptVariantName: trace.agentDirectiveVariant.name,
          ),
        )
        .add(
          trace,
          scenarioId: _scenarioIdForTuningReport(
            trace.scenario,
            catalogEvidence: catalogEvidence,
          ),
        );
  }
  return [
    for (final accumulator in accumulators.values) accumulator.toJson(policy),
  ]..sort(
    (a, b) => (a['sliceKey'] as String).compareTo(b['sliceKey'] as String),
  );
}

String _scenarioIdForTuningReport(
  EvalScenario scenario, {
  required EvalScenarioCatalogEvidence? catalogEvidence,
}) {
  if (catalogEvidence == null || !catalogEvidence.usesExternalCatalog) {
    return scenario.id;
  }
  return '<external-scenario>';
}

List<Map<String, dynamic>> _coverageGateJson(
  EvalTuningReadinessReport readiness,
) {
  final policy = readiness.policy;
  return [
    if (policy.requireCompleteTraceMatrix)
      _gateJson(
        id: 'coverage.trace_matrix.complete',
        status: readiness.traceCount == readiness.expectedTraceCount
            ? 'pass'
            : 'fail',
        actual: readiness.traceCount,
        required: readiness.expectedTraceCount,
        comparator: '==',
        blockerCode: 'coverage.traceMatrixIncomplete',
      ),
    if (policy.requireAllVerdicts)
      _gateJson(
        id: 'coverage.verdicts.complete',
        status: readiness.judgedTraceCount == readiness.traceCount
            ? 'pass'
            : 'fail',
        actual: readiness.judgedTraceCount,
        required: readiness.traceCount,
        comparator: '==',
        blockerCode: 'verdict.missing',
      ),
    if (policy.requiredPrimaryCapabilityIds.isNotEmpty)
      _gateJson(
        id: 'coverage.required_capabilities.present',
        status: readiness.evidence.missingRequiredPrimaryCapabilityIds.isEmpty
            ? 'pass'
            : 'fail',
        actual:
            policy.requiredPrimaryCapabilityIds.length -
            readiness.evidence.missingRequiredPrimaryCapabilityIds.length,
        required: policy.requiredPrimaryCapabilityIds.length,
        comparator: '==',
        blockerCode: 'coverage.capabilityMissing',
        scope: <String, dynamic>{
          'missingCapabilityIds': _sortedStrings(
            readiness.evidence.missingRequiredPrimaryCapabilityIds,
          ),
        },
      ),
  ];
}

Map<String, dynamic> _gateJson({
  required String id,
  required String status,
  required Object? actual,
  required Object? required,
  required String comparator,
  required String blockerCode,
  Map<String, dynamic> scope = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'id': id,
    'status': status,
    'scope': scope,
    if (actual != null) 'actual': _jsonMetricValue(actual),
    if (required != null) 'required': _jsonMetricValue(required),
    'comparator': comparator,
    'evidenceRefs': const <String>[],
    'blockerCode': blockerCode,
  };
}

String _passAtLeast(num actual, num required) =>
    actual >= required ? 'pass' : 'fail';

Object _jsonMetricValue(Object value) {
  if (value case final double number) {
    if (!number.isFinite) {
      throw StateError('Tuning report metric must be finite: $number');
    }
    return number;
  }
  return value;
}

List<String> _sourceBlockedReasonCodes({
  required EvalTuningReadinessReport readiness,
  required List<Map<String, dynamic>> sourceSlices,
  required ProfilePromotionDecision? promotionDecision,
}) {
  return _sortedStrings({
    for (final gate in _coverageGateJson(readiness))
      if (gate['status'] == 'fail') gate['blockerCode'] as String,
    for (final failure in readiness.failures) _blockedReasonCode(failure),
    for (final slice in sourceSlices)
      for (final code in _stringList(slice['blockingReasons'])) code,
    if (promotionDecision != null && !promotionDecision.promote)
      'promotion.blocked',
    if (promotionDecision != null)
      for (final failure in promotionDecision.failures)
        _blockedReasonCode(failure),
  });
}

List<String> _blockedReasonCodes(Map<String, dynamic> report) {
  return _sortedStrings({
    for (final reason in _mapList(report['blockedReasons']))
      _string(reason['code']),
  });
}

String _blockedReasonCode(String message) {
  final value = message.toLowerCase();
  if (value.contains('missing judge verdict') ||
      value.contains('all verdicts') ||
      value.contains('verdict')) {
    return 'verdict.missing';
  }
  if (value.contains('level 1') || value.contains('level1')) {
    return 'level1.failed';
  }
  if (value.contains('pairwise readiness plan')) {
    return 'pairwise.planMissing';
  }
  if (value.contains('pairwise')) return 'pairwise.gateFailed';
  if (value.contains('calibration report') ||
      value.contains('calibration set')) {
    return 'calibration.reportMissing';
  }
  if (value.contains('calibration')) return 'calibration.gateFailed';
  if (value.contains('protected holdout')) {
    return 'coverage.protectedHoldoutMissing';
  }
  if (value.contains('capability')) return 'coverage.capabilityMissing';
  if (value.contains('promotion')) return 'promotion.blocked';
  if (value.contains('policydigest') || value.contains('policy digest')) {
    return 'policy.digestDrift';
  }
  if (value.contains('manifest') || value.contains('digest')) {
    return 'provenance.bindingInvalid';
  }
  if (value.contains('outcome')) return 'outcome.thresholdFailed';
  return 'readiness.failed';
}

Map<String, dynamic> _promotionDecisionJson(
  ProfilePromotionDecision decision,
) => <String, dynamic>{
  'present': true,
  'status': decision.status.name,
  'candidateProfileName': decision.policy.candidateProfileName,
  'baselineProfileName': decision.policy.baselineProfileName,
  'evidencePlan': decision.evidencePlan == null
      ? null
      : _promotionEvidencePlanJson(decision.evidencePlan!),
  'failures': decision.failures,
  'warnings': decision.warnings,
  if (decision.comparison != null)
    'comparison': <String, dynamic>{
      'pairedScenarioCount': decision.comparison!.pairedScenarioCount,
      'judgePassDelta': decision.comparison!.judgePassDelta,
      'judgePassDeltaLowerBound': decision.comparison!.judgePassDeltaLowerBound,
      'meanQualityDelta': decision.comparison!.meanQualityDelta,
      'meanEfficiencyDelta': decision.comparison!.meanEfficiencyDelta,
      'totalTokenRatio': decision.comparison!.totalTokenRatio,
      'estimatedCostRatio': decision.comparison!.estimatedCostRatio,
    },
};

Map<String, dynamic> _promotionEvidencePlanJson(
  ProfilePromotionEvidencePlan plan,
) => <String, dynamic>{
  'currentPairedScenarioCount': plan.currentPairedScenarioCount,
  'currentJudgePairedScenarioCount': plan.currentJudgePairedScenarioCount,
  'additionalPairedScenariosForMinCount':
      plan.additionalPairedScenariosForMinCount,
  'additionalJudgeScenariosForMinCount':
      plan.additionalJudgeScenariosForMinCount,
  'additionalJudgeScenariosForLowerBound':
      plan.additionalJudgeScenariosForLowerBound,
  'additionalJudgeScenariosForPairedSignTest':
      plan.additionalJudgeScenariosForPairedSignTest,
  'projectedJudgePairedScenarioCount': plan.projectedJudgePairedScenarioCount,
  'projectedJudgePassDeltaLowerBound': plan.projectedJudgePassDeltaLowerBound,
  'projectedJudgePairedSignTestPValue': plan.projectedJudgePairedSignTestPValue,
  'assumedCandidateJudgePassRate': plan.assumedCandidateJudgePassRate,
  'assumedBaselineJudgePassRate': plan.assumedBaselineJudgePassRate,
  'recommendedAdditionalJudgeScenarios':
      plan.recommendedAdditionalJudgeScenarios,
  'blockers': plan.blockers,
};

void _validatePromotionPlanBinding({
  required Set<String> issueCodes,
  required EvalPromotionPlan? promotionPlan,
  required ProfilePromotionPolicy promotionPolicy,
  required EvalRunArtifacts sourceRun,
  required String sourceManifestDigest,
}) {
  final plan = promotionPlan;
  if (plan == null) {
    issueCodes.add('report.sourcePromotionPlanMissing');
    return;
  }
  _compareString(
    issueCodes,
    actual: plan.scenarioSetDigest,
    expected: sourceRun.manifest.scenarioSetDigest,
    issueCode: 'report.sourcePromotionPlanMismatch',
  );
  _compareString(
    issueCodes,
    actual: plan.profileSetDigest,
    expected: sourceRun.manifest.profileSetDigest,
    issueCode: 'report.sourcePromotionPlanMismatch',
  );
  _compareString(
    issueCodes,
    actual: plan.policyDigest,
    expected: _promotionPolicyDigest(promotionPolicy),
    issueCode: 'report.sourcePromotionPlanMismatch',
  );
  final planManifestDigest = plan.manifestDigest;
  if (planManifestDigest == null) {
    issueCodes.add('report.sourcePromotionPlanManifestDigestMissing');
  } else {
    _compareString(
      issueCodes,
      actual: planManifestDigest,
      expected: sourceManifestDigest,
      issueCode: 'report.sourcePromotionPlanManifestDigestMismatch',
    );
  }

  final evidence = sourceRun.manifest.promotionPlanEvidence;
  if (evidence == null) {
    issueCodes.add('report.sourcePromotionPlanEvidenceMissing');
    return;
  }
  _compareString(
    issueCodes,
    actual: evidence.planId,
    expected: plan.planId,
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
  _compareString(
    issueCodes,
    actual: evidence.candidateProfileName,
    expected: plan.candidateProfileName,
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
  _compareString(
    issueCodes,
    actual: evidence.baselineProfileName,
    expected: plan.baselineProfileName,
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
  _compareString(
    issueCodes,
    actual: evidence.scenarioSetDigest,
    expected: plan.scenarioSetDigest,
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
  _compareString(
    issueCodes,
    actual: evidence.profileSetDigest,
    expected: plan.profileSetDigest,
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
  _compareString(
    issueCodes,
    actual: evidence.policyDigest,
    expected: plan.policyDigest,
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
  _compareString(
    issueCodes,
    actual: evidence.promotionPlanSubjectDigest,
    expected: EvalProvenance.promotionPlanSubjectDigest(plan),
    issueCode: 'report.sourcePromotionPlanEvidenceMismatch',
  );
}

String _promotionPolicyDigest(ProfilePromotionPolicy policy) =>
    EvalProvenance.digestJson(EvalReporter.promotionPolicyJson(policy));

Map<String, dynamic> _workOrderLaunchSummary(
  EvalUseCaseWorkOrderLaunchEvidence evidence,
) => <String, dynamic>{
  'workOrderRef': evidence.workOrderRef,
  'workOrderDigest': evidence.workOrderDigest,
  'sourceExperimentPlanDigest': evidence.sourceExperimentPlanDigest,
  'sourceMatrixDigest': evidence.sourceMatrixDigest,
  'workOrderBatchRefs': evidence.workOrderBatchRefs,
  'workOrderBatchSetDigest': evidence.workOrderBatchSetDigest,
  'requiredPrimaryCapabilityIds': _sortedStrings(
    evidence.requiredPrimaryCapabilityIds,
  ),
  'promptVariantNames': _sortedStrings(evidence.promptVariantNames),
  'workOrderLaunchSubjectDigest': evidence.workOrderLaunchSubjectDigest,
};

Map<String, int> _stringIntMapJson(Map<String, int> values) => <String, int>{
  for (final key in values.keys.toList()..sort()) key: values[key]!,
};

Map<String, int> _enumIntMapJson<K extends Enum>(Map<K, int> values) =>
    <String, int>{
      for (final key
          in values.keys.toList()..sort((a, b) => a.name.compareTo(b.name)))
        key.name: values[key]!,
    };

List<String> _sortedStrings(Iterable<String> values) =>
    values.where((value) => value.trim().isNotEmpty).toSet().toList()..sort();

double _finiteDouble(double value) {
  if (!value.isFinite) {
    throw StateError('Tuning report metric must be finite: $value');
  }
  return value;
}

class _TuningSliceAccumulator {
  _TuningSliceAccumulator({
    required this.primaryCapabilityId,
    required this.agentKind,
    required this.modelClass,
    required this.promptVariantName,
  });

  final String primaryCapabilityId;
  final String agentKind;
  final String modelClass;
  final String promptVariantName;
  final scenarioIds = <String>{};
  final profileNames = <String>{};
  final verdicts = <JudgeVerdict>[];
  final tokenBudgetRatios = <double>[];
  final weightedCostBudgetRatios = <double>[];
  int traceCount = 0;
  int level1PassCount = 0;
  int missingWeightedCostCount = 0;

  String get sliceKey =>
      '$primaryCapabilityId@$agentKind@$modelClass@$promptVariantName';

  int get judgedTraceCount => verdicts.length;

  int get passCount => verdicts.where((verdict) => verdict.pass).length;

  RateEstimate get passEstimate => RateEstimate.wilson(
    successes: passCount,
    total: judgedTraceCount,
  );

  double get passRate => _rate(passCount, judgedTraceCount);

  double get meanGoalAttainment => _mean(
    verdicts.map((verdict) => verdict.goalAttainment.toDouble()),
  );

  double get meanQuality => _mean(
    verdicts.map((verdict) => verdict.quality.toDouble()),
  );

  double get meanEfficiency => _mean(
    verdicts.map((verdict) => verdict.efficiency.toDouble()),
  );

  double get meanTokenBudgetRatio => _mean(tokenBudgetRatios);

  double get meanWeightedCostBudgetRatio => _mean(weightedCostBudgetRatios);

  void add(EvalTrace trace, {required String scenarioId}) {
    scenarioIds.add(scenarioId);
    profileNames.add(trace.profile.name);
    traceCount += 1;
    if (trace.level1Passed) {
      level1PassCount += 1;
    }
    final verdict = trace.verdict;
    if (verdict == null) return;
    verdicts.add(verdict);
    tokenBudgetRatios.add(
      _rate(trace.output.usage.totalTokens, trace.profile.tokenBudget),
    );
    final weightedCost = trace.profile.estimatedUsageCostMicrosOrNull(
      trace.output.usage,
      requireCoreTokenCounts: trace.profile.usesWeightedTokenCosts,
    );
    if (weightedCost == null) {
      if (trace.profile.usesWeightedTokenCosts) {
        missingWeightedCostCount += 1;
      }
      return;
    }
    weightedCostBudgetRatios.add(
      _rate(weightedCost, trace.profile.tokenBudget),
    );
  }

  Map<String, dynamic> toJson(EvalTuningPolicy policy) {
    final gates = _gates(policy);
    return <String, dynamic>{
      'sliceKey': sliceKey,
      'primaryCapabilityId': primaryCapabilityId,
      'agentKind': agentKind,
      'modelClass': modelClass,
      'promptVariantName': promptVariantName,
      'scenarioIds': _sortedStrings(scenarioIds),
      'profileNames': _sortedStrings(profileNames),
      'traceCount': traceCount,
      'judgedTraceCount': judgedTraceCount,
      'passCount': passCount,
      'level1PassCount': level1PassCount,
      'passRate': _finiteDouble(passRate),
      'passRateLowerBound': _finiteDouble(passEstimate.lowerBound),
      'meanGoalAttainment': _finiteDouble(meanGoalAttainment),
      'meanQuality': _finiteDouble(meanQuality),
      'meanEfficiency': _finiteDouble(meanEfficiency),
      'meanTokenBudgetRatio': _finiteDouble(meanTokenBudgetRatio),
      'weightedCostTraceCount': weightedCostBudgetRatios.length,
      'missingWeightedCostCount': missingWeightedCostCount,
      'meanWeightedCostBudgetRatio': _finiteDouble(
        meanWeightedCostBudgetRatio,
      ),
      'recommendation': _recommendation(policy),
      'blockingReasons': [
        for (final gate in gates)
          if (gate['status'] == 'fail') gate['blockerCode'] as String,
      ],
      'gates': gates,
    };
  }

  List<Map<String, dynamic>> _gates(EvalTuningPolicy policy) {
    final scope = <String, dynamic>{
      'capabilityId': primaryCapabilityId,
      'agentKind': agentKind,
      'modelClass': modelClass,
      'promptVariantName': promptVariantName,
    };
    return [
      if (policy.requireAllVerdicts)
        _gateJson(
          id: 'outcome.slice.verdict_coverage',
          status: judgedTraceCount == traceCount ? 'pass' : 'fail',
          actual: judgedTraceCount,
          required: traceCount,
          comparator: '==',
          blockerCode: 'verdict.missing',
          scope: scope,
        ),
      if (policy.requireAllLevel1Passed)
        _gateJson(
          id: 'outcome.slice.level1_all_passed',
          status: level1PassCount == traceCount ? 'pass' : 'fail',
          actual: level1PassCount,
          required: traceCount,
          comparator: '==',
          blockerCode: 'level1.failed',
          scope: scope,
        ),
      if (policy.minJudgePassRate > 0)
        _gateJson(
          id: 'outcome.slice.judge_pass_rate',
          status: _passAtLeast(passRate, policy.minJudgePassRate),
          actual: passRate,
          required: policy.minJudgePassRate,
          comparator: '>=',
          blockerCode: 'outcome.passRateLow',
          scope: scope,
        ),
      if (policy.minJudgePassRateLowerBound > 0)
        _gateJson(
          id: 'outcome.slice.judge_pass_lower_bound',
          status: _passAtLeast(
            passEstimate.lowerBound,
            policy.minJudgePassRateLowerBound,
          ),
          actual: passEstimate.lowerBound,
          required: policy.minJudgePassRateLowerBound,
          comparator: '>=',
          blockerCode: 'outcome.passLowerBoundLow',
          scope: scope,
        ),
      if (policy.minMeanGoalAttainment > 0)
        _gateJson(
          id: 'outcome.slice.mean_goal_attainment',
          status: _passAtLeast(
            meanGoalAttainment,
            policy.minMeanGoalAttainment,
          ),
          actual: meanGoalAttainment,
          required: policy.minMeanGoalAttainment,
          comparator: '>=',
          blockerCode: 'outcome.goalAttainmentLow',
          scope: scope,
        ),
      if (policy.minMeanQuality > 0)
        _gateJson(
          id: 'outcome.slice.mean_quality',
          status: _passAtLeast(meanQuality, policy.minMeanQuality),
          actual: meanQuality,
          required: policy.minMeanQuality,
          comparator: '>=',
          blockerCode: 'outcome.qualityLow',
          scope: scope,
        ),
      if (policy.minMeanEfficiency > 0)
        _gateJson(
          id: 'outcome.slice.mean_efficiency',
          status: _passAtLeast(meanEfficiency, policy.minMeanEfficiency),
          actual: meanEfficiency,
          required: policy.minMeanEfficiency,
          comparator: '>=',
          blockerCode: 'outcome.efficiencyLow',
          scope: scope,
        ),
      if (policy.maxMeanTokensPerTraceBudgetRatio case final maxTokens?)
        _gateJson(
          id: 'outcome.slice.mean_token_budget_ratio',
          status: meanTokenBudgetRatio <= maxTokens ? 'pass' : 'fail',
          actual: meanTokenBudgetRatio,
          required: maxTokens,
          comparator: '<=',
          blockerCode: 'outcome.tokenBudgetHigh',
          scope: scope,
        ),
      if (policy.requireWeightedCostEvidence)
        _gateJson(
          id: 'outcome.slice.weighted_cost_evidence',
          status: missingWeightedCostCount == 0 ? 'pass' : 'fail',
          actual: missingWeightedCostCount,
          required: 0,
          comparator: '==',
          blockerCode: 'outcome.weightedCostMissing',
          scope: scope,
        ),
      if (policy.maxMeanWeightedCostPerTraceBudgetRatio case final maxCost?)
        _gateJson(
          id: 'outcome.slice.mean_weighted_cost_budget_ratio',
          status: meanWeightedCostBudgetRatio <= maxCost ? 'pass' : 'fail',
          actual: meanWeightedCostBudgetRatio,
          required: maxCost,
          comparator: '<=',
          blockerCode: 'outcome.weightedCostBudgetHigh',
          scope: scope,
        ),
    ];
  }

  String _recommendation(EvalTuningPolicy policy) {
    if (policy.requireAllVerdicts && judgedTraceCount < traceCount) {
      return 'gradeVerdicts';
    }
    if (policy.requireAllLevel1Passed && level1PassCount < traceCount) {
      return 'repairLevel1';
    }
    if ((policy.requireAllJudgePasses && passCount < judgedTraceCount) ||
        passRate < policy.minJudgePassRate ||
        passEstimate.lowerBound < policy.minJudgePassRateLowerBound ||
        meanGoalAttainment < policy.minMeanGoalAttainment) {
      return 'improveOutcome';
    }
    if (meanQuality < policy.minMeanQuality) return 'improveQuality';
    if (meanEfficiency < policy.minMeanEfficiency) return 'improveEfficiency';
    final maxTokens = policy.maxMeanTokensPerTraceBudgetRatio;
    if (maxTokens != null && meanTokenBudgetRatio > maxTokens) {
      return 'reduceTokenBudget';
    }
    if (policy.requireWeightedCostEvidence && missingWeightedCostCount > 0) {
      return 'addCostEvidence';
    }
    final maxCost = policy.maxMeanWeightedCostPerTraceBudgetRatio;
    if (maxCost != null && meanWeightedCostBudgetRatio > maxCost) {
      return 'reduceWeightedCost';
    }
    return 'keep';
  }
}

double _rate(int count, int total) => total == 0 ? 0 : count / total;

double _mean(Iterable<double> values) {
  var count = 0;
  var sum = 0.0;
  for (final value in values) {
    count += 1;
    sum += value;
  }
  return count == 0 ? 0 : sum / count;
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

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item,
  ]..sort();
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) => value is int ? value : -1;

void _compareString(
  Set<String> issueCodes, {
  required String actual,
  required String expected,
  required String issueCode,
}) {
  if (actual != expected) issueCodes.add(issueCode);
}

void _compareJson(
  Set<String> issueCodes, {
  required Object? actual,
  required Object? expected,
  required String issueCode,
}) {
  if (const DeepCollectionEquality().equals(actual, expected)) return;
  issueCodes.add(issueCode);
}
