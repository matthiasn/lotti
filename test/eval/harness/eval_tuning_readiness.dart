import 'eval_judge_calibration.dart';
import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_scenario_validation.dart';

class EvalTuningPolicy {
  const EvalTuningPolicy({
    required this.name,
    this.requiredModelClasses = const <EvalModelClass>{},
    this.requiredProfileNames = const <String>{},
    this.requiredSplits = const <EvalScenarioSplit>{},
    this.requiredAgentKinds = const <AgentKind>{},
    this.minScenarioCount = 1,
    this.minScenariosPerAgentKind = 0,
    this.minScenariosPerCapability = 0,
    this.minCapabilityCount = 0,
    this.minAdversarialScenarioCount = 0,
    this.minAdversarialScenariosPerAgentKind = 0,
    this.minAdversarialScenariosPerCapability = 0,
    this.requiredAdversarialTags = const <String>{},
    this.minProductionReplayHoldoutScenarios = 0,
    this.minProtectedHoldoutScenarios = 0,
    this.minProtectedHoldoutScenariosPerAgentKind = 0,
    this.minProfilesPerModelClass = 1,
    this.minTrialsPerProfile = 1,
    this.requireCompleteTraceMatrix = true,
    this.requireAllVerdicts = false,
    this.requireAllLevel1Passed = false,
    this.requireCalibratedVerdicts = false,
    this.requireBlindedJudgeVerdicts = false,
    this.requiredCalibrationSetVersion,
    this.requiredHumanCalibrationSetVersion,
    this.requireCalibrationReport = false,
    this.minCalibrationEvaluatedCount = 0,
    this.minCalibrationEvaluatedPerModelClass = 0,
    this.minCalibrationEvaluatedPerCapability = 0,
    this.minCalibrationCoverageRate = 0,
    this.minCalibrationCoverageLowerBound = 0,
    this.minCalibrationPassAgreementRate = 0,
    this.minCalibrationPassAgreementLowerBound = 0,
    this.minCalibrationScoreAgreementRate = 0,
    this.minCalibrationScoreAgreementLowerBound = 0,
    this.minCalibrationHumanReviewPairCount = 0,
    this.minCalibrationHumanPassAgreementRate = 0,
    this.minCalibrationHumanPassAgreementLowerBound = 0,
    this.minCalibrationHumanScoreAgreementRate = 0,
    this.minCalibrationHumanScoreAgreementLowerBound = 0,
    this.maxCalibrationUnresolvedHumanDisagreementCount,
    this.requireBlindedHumanReviews = false,
    this.maxCalibrationFalsePassCount,
    this.maxCalibrationFalsePassRate = 1,
    this.maxCalibrationFalseFailRate = 1,
    this.requireBlindedCalibrationReport = false,
    this.requireCleanCalibrationReport = false,
    this.requireManifest = false,
    this.requiredTargetKind,
    this.expectedScenarioSetDigest,
    this.expectedProfileSetDigest,
    this.requireProtectedHoldout = false,
    this.requireReviewedScenarioEvidence = false,
  });

  const EvalTuningPolicy.developmentSmoke() : this(name: 'developmentSmoke');

  const EvalTuningPolicy.modelClassTuning({
    String? requiredCalibrationSetVersion,
    String? requiredHumanCalibrationSetVersion,
  }) : this(
         name: 'modelClassTuning',
         requiredModelClasses: const {
           EvalModelClass.localSmall,
           EvalModelClass.localReasoning,
           EvalModelClass.frontierFast,
           EvalModelClass.frontierReasoning,
         },
         requiredSplits: const {
           EvalScenarioSplit.development,
           EvalScenarioSplit.holdout,
         },
         requiredAgentKinds: const {
           AgentKind.taskAgent,
           AgentKind.planningAgent,
         },
         minScenarioCount: 12,
         minScenariosPerAgentKind: 6,
         minScenariosPerCapability: 2,
         minCapabilityCount: 4,
         minAdversarialScenarioCount: 4,
         minAdversarialScenariosPerAgentKind: 2,
         minAdversarialScenariosPerCapability: 1,
         requiredAdversarialTags: kDefaultAdversarialStressTags,
         minProductionReplayHoldoutScenarios: 4,
         minProtectedHoldoutScenarios: 4,
         minProtectedHoldoutScenariosPerAgentKind: 2,
         minTrialsPerProfile: 3,
         requireCompleteTraceMatrix: true,
         requireAllVerdicts: true,
         requireAllLevel1Passed: true,
         requireCalibratedVerdicts: true,
         requireBlindedJudgeVerdicts: true,
         requiredCalibrationSetVersion: requiredCalibrationSetVersion,
         requiredHumanCalibrationSetVersion: requiredHumanCalibrationSetVersion,
         requireCalibrationReport: true,
         minCalibrationEvaluatedCount: 12,
         minCalibrationEvaluatedPerModelClass: 2,
         minCalibrationEvaluatedPerCapability: 2,
         minCalibrationCoverageRate: 0.8,
         minCalibrationCoverageLowerBound: 0.6,
         minCalibrationPassAgreementRate: 0.85,
         minCalibrationPassAgreementLowerBound: 0.7,
         minCalibrationScoreAgreementRate: 0.75,
         minCalibrationScoreAgreementLowerBound: 0.6,
         minCalibrationHumanReviewPairCount: 12,
         minCalibrationHumanPassAgreementRate: 0.85,
         minCalibrationHumanPassAgreementLowerBound: 0.7,
         minCalibrationHumanScoreAgreementRate: 0.75,
         minCalibrationHumanScoreAgreementLowerBound: 0.6,
         maxCalibrationUnresolvedHumanDisagreementCount: 0,
         requireBlindedHumanReviews: true,
         maxCalibrationFalsePassCount: 0,
         maxCalibrationFalsePassRate: 0.05,
         maxCalibrationFalseFailRate: 0.1,
         requireBlindedCalibrationReport: true,
         requireCleanCalibrationReport: true,
         requireManifest: true,
         requiredTargetKind: 'live',
         requireProtectedHoldout: true,
         requireReviewedScenarioEvidence: true,
       );

  final String name;
  final Set<EvalModelClass> requiredModelClasses;
  final Set<String> requiredProfileNames;
  final Set<EvalScenarioSplit> requiredSplits;
  final Set<AgentKind> requiredAgentKinds;
  final int minScenarioCount;
  final int minScenariosPerAgentKind;
  final int minScenariosPerCapability;
  final int minCapabilityCount;
  final int minAdversarialScenarioCount;
  final int minAdversarialScenariosPerAgentKind;
  final int minAdversarialScenariosPerCapability;
  final Set<String> requiredAdversarialTags;
  final int minProductionReplayHoldoutScenarios;
  final int minProtectedHoldoutScenarios;
  final int minProtectedHoldoutScenariosPerAgentKind;
  final int minProfilesPerModelClass;
  final int minTrialsPerProfile;
  final bool requireCompleteTraceMatrix;
  final bool requireAllVerdicts;
  final bool requireAllLevel1Passed;
  final bool requireCalibratedVerdicts;
  final bool requireBlindedJudgeVerdicts;
  final String? requiredCalibrationSetVersion;
  final String? requiredHumanCalibrationSetVersion;
  final bool requireCalibrationReport;
  final int minCalibrationEvaluatedCount;
  final int minCalibrationEvaluatedPerModelClass;
  final int minCalibrationEvaluatedPerCapability;
  final double minCalibrationCoverageRate;
  final double minCalibrationCoverageLowerBound;
  final double minCalibrationPassAgreementRate;
  final double minCalibrationPassAgreementLowerBound;
  final double minCalibrationScoreAgreementRate;
  final double minCalibrationScoreAgreementLowerBound;
  final int minCalibrationHumanReviewPairCount;
  final double minCalibrationHumanPassAgreementRate;
  final double minCalibrationHumanPassAgreementLowerBound;
  final double minCalibrationHumanScoreAgreementRate;
  final double minCalibrationHumanScoreAgreementLowerBound;
  final int? maxCalibrationUnresolvedHumanDisagreementCount;
  final bool requireBlindedHumanReviews;
  final int? maxCalibrationFalsePassCount;
  final double maxCalibrationFalsePassRate;
  final double maxCalibrationFalseFailRate;
  final bool requireBlindedCalibrationReport;
  final bool requireCleanCalibrationReport;
  final bool requireManifest;
  final String? requiredTargetKind;
  final String? expectedScenarioSetDigest;
  final String? expectedProfileSetDigest;
  final bool requireProtectedHoldout;
  final bool requireReviewedScenarioEvidence;
}

class EvalTuningReadinessReport {
  const EvalTuningReadinessReport({
    required this.policy,
    required this.policyName,
    required this.scenarioCount,
    required this.profileCount,
    required this.expectedTraceCount,
    required this.traceCount,
    required this.judgedTraceCount,
    required this.evidence,
    required this.failures,
    required this.warnings,
  });

  final EvalTuningPolicy policy;
  final String policyName;
  final int scenarioCount;
  final int profileCount;
  final int expectedTraceCount;
  final int traceCount;
  final int judgedTraceCount;
  final EvalTuningReadinessEvidence evidence;
  final List<String> failures;
  final List<String> warnings;

  bool get ready => failures.isEmpty;

  String get evidenceLabel => policyName == 'developmentSmoke'
      ? 'development-smoke'
      : ready
      ? 'tuning-ready'
      : 'development-smoke';
}

class EvalScenarioCatalogPreflightReport {
  const EvalScenarioCatalogPreflightReport({
    required this.policy,
    required this.scenarioCount,
    required this.profileCount,
    required this.catalogEvidence,
    required this.evidence,
    required this.failures,
    required this.warnings,
  });

  final EvalTuningPolicy policy;
  final int scenarioCount;
  final int profileCount;
  final EvalScenarioCatalogEvidence? catalogEvidence;
  final EvalTuningReadinessEvidence evidence;
  final List<String> failures;
  final List<String> warnings;

  bool get ready => failures.isEmpty;

  String get evidenceLabel => ready ? 'catalog-ready' : 'catalog-blocked';
}

class EvalTuningReadinessEvidence {
  const EvalTuningReadinessEvidence({
    required this.scenarioCountByAgentKind,
    required this.scenarioCountBySplit,
    required this.scenarioCountByPrimaryCapability,
    required this.profileCountByModelClass,
    required this.minObservedTrialCount,
    required this.maxObservedTrialCount,
    required this.profilesBelowMinTrialCount,
    required this.adversarialScenarioCount,
    required this.adversarialScenarioCountByAgentKind,
    required this.adversarialScenarioCountByPrimaryCapability,
    required this.adversarialTags,
    required this.missingAdversarialTags,
    required this.productionReplayHoldoutScenarioCount,
    required this.protectedHoldoutScenarioCount,
    required this.protectedHoldoutScenarioCountByAgentKind,
    required this.duplicateProtectedHoldoutScenarioIds,
    required this.duplicateProtectedHoldoutSourceDigests,
    required this.scenarioReviewRequiredCount,
    required this.completedScenarioReviewCount,
    required this.missingScenarioReviewIds,
    required this.incompleteScenarioReviewIds,
    required this.invalidScenarioReviewIds,
    required this.staleScenarioReviewIds,
    required this.missingScenarioReviewSourceDigestIds,
  });

  final Map<AgentKind, int> scenarioCountByAgentKind;
  final Map<EvalScenarioSplit, int> scenarioCountBySplit;
  final Map<String, int> scenarioCountByPrimaryCapability;
  final Map<EvalModelClass, int> profileCountByModelClass;
  final int minObservedTrialCount;
  final int maxObservedTrialCount;
  final Map<String, int> profilesBelowMinTrialCount;
  final int adversarialScenarioCount;
  final Map<AgentKind, int> adversarialScenarioCountByAgentKind;
  final Map<String, int> adversarialScenarioCountByPrimaryCapability;
  final Set<String> adversarialTags;
  final Set<String> missingAdversarialTags;
  final int productionReplayHoldoutScenarioCount;
  final int protectedHoldoutScenarioCount;
  final Map<AgentKind, int> protectedHoldoutScenarioCountByAgentKind;
  final Set<String> duplicateProtectedHoldoutScenarioIds;
  final Set<String> duplicateProtectedHoldoutSourceDigests;
  final int scenarioReviewRequiredCount;
  final int completedScenarioReviewCount;
  final Set<String> missingScenarioReviewIds;
  final Set<String> incompleteScenarioReviewIds;
  final Set<String> invalidScenarioReviewIds;
  final Set<String> staleScenarioReviewIds;
  final Set<String> missingScenarioReviewSourceDigestIds;
}

abstract final class EvalTuningReadiness {
  static const catalogPreflightScopeWarning =
      'catalog preflight does not evaluate traces, judge verdicts, provider '
      'provenance, model performance, or human calibration labels';

  static EvalTuningReadinessReport assess({
    required List<EvalTrace> traces,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalRunManifest? manifest,
    EvalTuningPolicy policy = const EvalTuningPolicy.developmentSmoke(),
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    JudgeCalibrationSet? calibrationSet,
    JudgeCalibrationReport? calibrationReport,
  }) {
    final failures = <String>[];
    final warnings = <String>[];
    if (calibrationSet != null && calibrationReport != null) {
      failures.add(
        'judge calibration report must not be supplied with calibrationSet; '
        'readiness recomputes it from labels',
      );
    }
    final catalogEvidence =
        scenarioCatalogEvidence ?? manifest?.scenarioCatalogEvidence;
    final evidence = _collectEvidence(
      scenarios: scenarios,
      profiles: profiles,
      policy: policy,
      catalogEvidence: catalogEvidence,
    );

    for (final issue in validateEvalScenarioCatalog(scenarios)) {
      failures.add('scenario catalog validation failed: $issue');
    }
    _validateProfileCatalog(profiles, failures);
    _validateManifest(
      manifest: manifest,
      scenarios: scenarios,
      profiles: profiles,
      policy: policy,
      failures: failures,
    );
    _validateScenarioCatalogEvidence(
      catalogEvidence: catalogEvidence,
      manifestEvidence: manifest?.scenarioCatalogEvidence,
      scenarios: scenarios,
      policy: policy,
      readinessEvidence: evidence,
      failures: failures,
    );
    _validateScenarioCoverage(scenarios, policy, evidence, failures, warnings);
    _validateScenarioReviewCoverage(
      scenarios: scenarios,
      policy: policy,
      catalogEvidence: catalogEvidence,
      failures: failures,
    );
    _validateProfileCoverage(profiles, policy, evidence, failures);

    final expectedKeys = _expectedTraceKeys(scenarios, profiles);
    final traceKeys = traces.map(_traceKey).toList(growable: false);
    final actualKeys = traceKeys.toSet();
    final duplicateKeys = _duplicates(traceKeys);
    final missingKeys = expectedKeys.difference(actualKeys);
    final unexpectedKeys = actualKeys.difference(expectedKeys);

    if (policy.requireCompleteTraceMatrix) {
      for (final key in duplicateKeys.toList()..sort()) {
        failures.add('duplicate trace for $key');
      }
      for (final key in missingKeys.toList()..sort()) {
        failures.add('missing trace for $key');
      }
      for (final key in unexpectedKeys.toList()..sort()) {
        failures.add('unexpected trace for $key');
      }
    } else {
      if (duplicateKeys.isNotEmpty) {
        warnings.add('duplicate traces present: ${duplicateKeys.length}');
      }
      if (missingKeys.isNotEmpty) {
        warnings.add('missing traces: ${missingKeys.length}');
      }
      if (unexpectedKeys.isNotEmpty) {
        warnings.add('unexpected traces: ${unexpectedKeys.length}');
      }
    }

    final judgedTraceCount = traces
        .where((trace) => trace.verdict != null)
        .length;
    if (policy.requireAllVerdicts) {
      for (final trace in traces) {
        if (trace.verdict == null) {
          failures.add('missing verdict for ${_traceKey(trace)}');
        }
      }
      for (final key in missingKeys.toList()..sort()) {
        failures.add('missing verdict because trace is absent for $key');
      }
    } else if (judgedTraceCount < traces.length) {
      warnings.add(
        'not all traces are judged: $judgedTraceCount/${traces.length}',
      );
    }

    if (policy.requireAllLevel1Passed) {
      for (final trace in traces) {
        if (!trace.level1Passed) {
          failures.add('Level 1 failed for ${_traceKey(trace)}');
        }
      }
    }

    var effectiveCalibrationReport = calibrationReport;
    if (calibrationSet != null) {
      try {
        effectiveCalibrationReport = EvalJudgeCalibration.evaluate(
          traces: traces,
          calibrationSet: calibrationSet,
        );
      } on FormatException catch (error) {
        failures.add('judge calibration set is invalid: ${error.message}');
        effectiveCalibrationReport = null;
      }
    }

    _validateJudgeCalibration(
      traces,
      scenarios,
      policy,
      calibrationSet,
      effectiveCalibrationReport,
      failures,
      warnings,
    );

    return EvalTuningReadinessReport(
      policy: policy,
      policyName: policy.name,
      scenarioCount: scenarios.length,
      profileCount: profiles.length,
      expectedTraceCount: expectedKeys.length,
      traceCount: traces.length,
      judgedTraceCount: judgedTraceCount,
      evidence: evidence,
      failures: failures,
      warnings: warnings,
    );
  }

  static EvalScenarioCatalogPreflightReport assessScenarioCatalog({
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
    EvalTuningPolicy policy = const EvalTuningPolicy.modelClassTuning(),
  }) {
    final failures = <String>[];
    final warnings = <String>[catalogPreflightScopeWarning];
    final evidence = _collectEvidence(
      scenarios: scenarios,
      profiles: profiles,
      policy: policy,
      catalogEvidence: scenarioCatalogEvidence,
    );

    for (final issue in validateEvalScenarioCatalog(scenarios)) {
      failures.add('scenario catalog validation failed: $issue');
    }
    _validateProfileCatalog(profiles, failures);
    _validateScenarioCatalogEvidence(
      catalogEvidence: scenarioCatalogEvidence,
      manifestEvidence: scenarioCatalogEvidence,
      scenarios: scenarios,
      policy: policy,
      readinessEvidence: evidence,
      failures: failures,
    );
    _validateScenarioCoverage(scenarios, policy, evidence, failures, warnings);
    _validateScenarioReviewCoverage(
      scenarios: scenarios,
      policy: policy,
      catalogEvidence: scenarioCatalogEvidence,
      failures: failures,
    );
    _validateProfileCoverage(profiles, policy, evidence, failures);

    return EvalScenarioCatalogPreflightReport(
      policy: policy,
      scenarioCount: scenarios.length,
      profileCount: profiles.length,
      catalogEvidence: scenarioCatalogEvidence,
      evidence: evidence,
      failures: List.unmodifiable(failures),
      warnings: List.unmodifiable(warnings),
    );
  }

  static String render(EvalTuningReadinessReport report) {
    final buffer = StringBuffer()
      ..writeln(
        'Tuning readiness (${report.policyName}): ${report.evidenceLabel}',
      )
      ..writeln(
        'scenarios=${report.scenarioCount} profiles=${report.profileCount} '
        'traces=${report.traceCount}/${report.expectedTraceCount} '
        'judged=${report.judgedTraceCount}/${report.traceCount}',
      )
      ..writeln(
        'catalog agents='
        '${_renderEnumCounts(report.evidence.scenarioCountByAgentKind)} '
        'splits=${_renderEnumCounts(report.evidence.scenarioCountBySplit)} '
        'primaryCapabilities='
        '${_actualRequired(
          report.evidence.scenarioCountByPrimaryCapability.length,
          report.policy.minCapabilityCount,
        )}',
      )
      ..writeln(
        'profiles modelClasses='
        '${_renderEnumCounts(report.evidence.profileCountByModelClass)} '
        'trialRange=${report.evidence.minObservedTrialCount}..'
        '${report.evidence.maxObservedTrialCount} '
        'belowMin=${_renderStringCounts(
          report.evidence.profilesBelowMinTrialCount,
        )}',
      )
      ..writeln(
        'stress catalog adversarial='
        '${_actualRequired(
          report.evidence.adversarialScenarioCount,
          report.policy.minAdversarialScenarioCount,
        )} '
        'productionReplayHoldout='
        '${_actualRequired(
          report.evidence.productionReplayHoldoutScenarioCount,
          report.policy.minProductionReplayHoldoutScenarios,
        )}',
      )
      ..writeln(
        'stress agents adversarial='
        '${_renderEnumCounts(report.evidence.adversarialScenarioCountByAgentKind)}',
      )
      ..writeln(
        'protected evidence holdout='
        '${_actualRequired(
          report.evidence.protectedHoldoutScenarioCount,
          report.policy.minProtectedHoldoutScenarios,
        )} '
        'agents='
        '${_renderEnumCounts(report.evidence.protectedHoldoutScenarioCountByAgentKind)}',
      )
      ..writeln(
        'stress tags=${_renderSet(report.evidence.adversarialTags)} '
        'missing=${_renderSet(report.evidence.missingAdversarialTags)}',
      )
      ..writeln(
        'scenario reviews completed='
        '${_actualRequired(
          report.evidence.completedScenarioReviewCount,
          report.evidence.scenarioReviewRequiredCount,
        )} '
        'missing=${_renderSet(report.evidence.missingScenarioReviewIds)} '
        'incomplete='
        '${_renderSet(report.evidence.incompleteScenarioReviewIds)} '
        'invalid=${_renderSet(report.evidence.invalidScenarioReviewIds)} '
        'stale=${_renderSet(report.evidence.staleScenarioReviewIds)} '
        'missingSourceDigest='
        '${_renderSet(
          report.evidence.missingScenarioReviewSourceDigestIds,
        )}',
      );
    if (report.evidence.duplicateProtectedHoldoutScenarioIds.isNotEmpty) {
      buffer.writeln(
        'duplicateProtectedHoldoutIds='
        '${_renderSet(report.evidence.duplicateProtectedHoldoutScenarioIds)}',
      );
    }
    if (report.evidence.duplicateProtectedHoldoutSourceDigests.isNotEmpty) {
      buffer.writeln(
        'duplicateProtectedHoldoutSourceDigests='
        '${_renderSet(
          report.evidence.duplicateProtectedHoldoutSourceDigests,
        )}',
      );
    }
    if (report.failures.isNotEmpty) {
      buffer.writeln('Failures:');
      for (final failure in report.failures) {
        buffer.writeln('- $failure');
      }
    }
    if (report.warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in report.warnings) {
        buffer.writeln('- $warning');
      }
    }
    return buffer.toString();
  }

  static String renderScenarioCatalogPreflight(
    EvalScenarioCatalogPreflightReport report,
  ) {
    final buffer = StringBuffer()
      ..writeln(
        'Scenario catalog preflight (${report.policy.name}): '
        '${report.evidenceLabel}',
      )
      ..writeln(_renderCatalogEvidence(report.catalogEvidence))
      ..writeln(
        'profiles modelClasses='
        '${_renderEnumCounts(report.evidence.profileCountByModelClass)} '
        'trialRange=${report.evidence.minObservedTrialCount}..'
        '${report.evidence.maxObservedTrialCount} '
        'belowMin=${_renderStringCounts(
          report.evidence.profilesBelowMinTrialCount,
        )}',
      )
      ..writeln(
        'catalog agents='
        '${_renderEnumCounts(report.evidence.scenarioCountByAgentKind)} '
        'splits=${_renderEnumCounts(report.evidence.scenarioCountBySplit)} '
        'primaryCapabilities='
        '${_actualRequired(
          report.evidence.scenarioCountByPrimaryCapability.length,
          report.policy.minCapabilityCount,
        )}',
      )
      ..writeln(
        'stress catalog adversarial='
        '${_actualRequired(
          report.evidence.adversarialScenarioCount,
          report.policy.minAdversarialScenarioCount,
        )} '
        'productionReplayHoldout='
        '${_actualRequired(
          report.evidence.productionReplayHoldoutScenarioCount,
          report.policy.minProductionReplayHoldoutScenarios,
        )}',
      )
      ..writeln(
        'stress agents adversarial='
        '${_renderEnumCounts(report.evidence.adversarialScenarioCountByAgentKind)}',
      )
      ..writeln(
        'protected evidence holdout='
        '${_actualRequired(
          report.evidence.protectedHoldoutScenarioCount,
          report.policy.minProtectedHoldoutScenarios,
        )} '
        'agents='
        '${_renderEnumCounts(report.evidence.protectedHoldoutScenarioCountByAgentKind)}',
      )
      ..writeln(
        'stress tags=${_renderSet(report.evidence.adversarialTags)} '
        'missing=${_renderSet(report.evidence.missingAdversarialTags)}',
      )
      ..writeln(
        'scenario reviews completed='
        '${_actualRequired(
          report.evidence.completedScenarioReviewCount,
          report.evidence.scenarioReviewRequiredCount,
        )} '
        'missing=${_renderSet(report.evidence.missingScenarioReviewIds)} '
        'incomplete='
        '${_renderSet(report.evidence.incompleteScenarioReviewIds)} '
        'invalid=${_renderSet(report.evidence.invalidScenarioReviewIds)} '
        'stale=${_renderSet(report.evidence.staleScenarioReviewIds)} '
        'missingSourceDigest='
        '${_renderSet(
          report.evidence.missingScenarioReviewSourceDigestIds,
        )}',
      );
    if (report.evidence.duplicateProtectedHoldoutScenarioIds.isNotEmpty) {
      buffer.writeln(
        'duplicateProtectedHoldoutIds='
        '${_renderSet(report.evidence.duplicateProtectedHoldoutScenarioIds)}',
      );
    }
    if (report.evidence.duplicateProtectedHoldoutSourceDigests.isNotEmpty) {
      buffer.writeln(
        'duplicateProtectedHoldoutSourceDigests='
        '${_renderSet(
          report.evidence.duplicateProtectedHoldoutSourceDigests,
        )}',
      );
    }
    if (report.failures.isNotEmpty) {
      buffer.writeln('Failures:');
      for (final failure in report.failures) {
        buffer.writeln('- $failure');
      }
    }
    if (report.warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in report.warnings) {
        buffer.writeln('- $warning');
      }
    }
    return _redactProtectedScenarioIds(
      buffer.toString(),
      report.catalogEvidence,
    );
  }

  static EvalTuningReadinessEvidence _collectEvidence({
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required EvalTuningPolicy policy,
    required EvalScenarioCatalogEvidence? catalogEvidence,
  }) {
    final scenarioCountByAgentKind = <AgentKind, int>{};
    final scenarioCountBySplit = <EvalScenarioSplit, int>{};
    final scenarioCountByPrimaryCapability = <String, int>{};
    final adversarialScenarioCountByAgentKind = <AgentKind, int>{};
    final adversarialScenarioCountByPrimaryCapability = <String, int>{};
    final adversarialTags = <String>{};
    final protectedScenarioIds =
        (catalogEvidence?.protectedScenarioIds ?? const <String>[]).toSet();
    final protectedHoldoutScenarioIds =
        (catalogEvidence?.protectedHoldoutScenarioIds ?? const <String>[])
            .toSet();
    final scenarioReviewRequiredIds = <String>{};
    final completedScenarioReviewIds = <String>{};
    final missingScenarioReviewIds = <String>{};
    final incompleteScenarioReviewIds = <String>{};
    final invalidScenarioReviewIds = <String>{};
    final staleScenarioReviewIds = <String>{};
    final missingScenarioReviewSourceDigestIds = <String>{};
    var adversarialScenarioCount = 0;
    var productionReplayHoldoutScenarioCount = 0;

    for (final scenario in scenarios) {
      _increment(scenarioCountByAgentKind, scenario.agentKind);
      _increment(scenarioCountBySplit, scenario.metadata.split);
      final capabilityId = scenario.metadata.primaryCapabilityId;
      if (capabilityId != null) {
        _increment(scenarioCountByPrimaryCapability, capabilityId);
      }
      if (scenario.metadata.split == EvalScenarioSplit.holdout &&
          scenario.metadata.source == EvalScenarioSource.productionReplay) {
        productionReplayHoldoutScenarioCount += 1;
      }
      if (_isAdversarialScenario(scenario)) {
        adversarialScenarioCount += 1;
        adversarialTags.addAll(scenario.metadata.tags);
        _increment(adversarialScenarioCountByAgentKind, scenario.agentKind);
        if (capabilityId != null) {
          _increment(
            adversarialScenarioCountByPrimaryCapability,
            capabilityId,
          );
        }
      }
      final reviewReasons = _scenarioReviewRequirementReasons(
        scenario,
        protectedScenarioIds,
        protectedHoldoutScenarioIds,
      );
      if (reviewReasons.isNotEmpty) {
        scenarioReviewRequiredIds.add(scenario.id);
        final review = scenario.metadata.review;
        if (review == null) {
          missingScenarioReviewIds.add(scenario.id);
        } else if (!_isCompletedScenarioReview(review.status)) {
          incompleteScenarioReviewIds.add(scenario.id);
        } else if (!_isStructurallyValidScenarioReview(review)) {
          invalidScenarioReviewIds.add(scenario.id);
        } else if (review.subjectDigest !=
            EvalProvenance.scenarioReviewSubjectDigest(scenario)) {
          staleScenarioReviewIds.add(scenario.id);
        } else if (_requiresScenarioReviewSourceDigest(
              scenario,
              protectedScenarioIds,
            ) &&
            review.sourceDigest == null) {
          missingScenarioReviewSourceDigestIds.add(scenario.id);
        } else {
          completedScenarioReviewIds.add(scenario.id);
        }
      }
    }

    final profileCountByModelClass = <EvalModelClass, int>{};
    final profilesBelowMinTrialCount = <String, int>{};
    final trialCounts = <int>[];
    for (final profile in profiles) {
      _increment(profileCountByModelClass, profile.modelClass);
      trialCounts.add(profile.trialCount);
      if (profile.trialCount < policy.minTrialsPerProfile) {
        profilesBelowMinTrialCount[profile.name] = profile.trialCount;
      }
    }

    final protectedHoldoutScenarioCountByAgentKind = <AgentKind, int>{};
    final duplicateProtectedHoldoutScenarioIds = catalogEvidence == null
        ? <String>{}
        : _duplicates(catalogEvidence.protectedHoldoutScenarioIds);
    final protectedHoldoutSourceDigests = <String>[];
    final scenariosById = {
      for (final scenario in scenarios) scenario.id: scenario,
    };
    var protectedHoldoutScenarioCount = 0;
    for (final scenarioId in protectedHoldoutScenarioIds) {
      final scenario = scenariosById[scenarioId];
      if (scenario == null ||
          scenario.metadata.split != EvalScenarioSplit.holdout ||
          scenario.metadata.source != EvalScenarioSource.productionReplay) {
        continue;
      }
      protectedHoldoutScenarioCount += 1;
      _increment(protectedHoldoutScenarioCountByAgentKind, scenario.agentKind);
      final sourceDigest = scenario.metadata.review?.sourceDigest;
      if (sourceDigest != null) {
        protectedHoldoutSourceDigests.add(sourceDigest);
      }
    }
    final duplicateProtectedHoldoutSourceDigests = _duplicates(
      protectedHoldoutSourceDigests,
    );

    return EvalTuningReadinessEvidence(
      scenarioCountByAgentKind: Map.unmodifiable(scenarioCountByAgentKind),
      scenarioCountBySplit: Map.unmodifiable(scenarioCountBySplit),
      scenarioCountByPrimaryCapability: Map.unmodifiable(
        scenarioCountByPrimaryCapability,
      ),
      profileCountByModelClass: Map.unmodifiable(profileCountByModelClass),
      minObservedTrialCount: trialCounts.isEmpty
          ? 0
          : trialCounts.reduce((a, b) => a < b ? a : b),
      maxObservedTrialCount: trialCounts.isEmpty
          ? 0
          : trialCounts.reduce((a, b) => a > b ? a : b),
      profilesBelowMinTrialCount: Map.unmodifiable(
        profilesBelowMinTrialCount,
      ),
      adversarialScenarioCount: adversarialScenarioCount,
      adversarialScenarioCountByAgentKind: Map.unmodifiable(
        adversarialScenarioCountByAgentKind,
      ),
      adversarialScenarioCountByPrimaryCapability: Map.unmodifiable(
        adversarialScenarioCountByPrimaryCapability,
      ),
      adversarialTags: Set.unmodifiable(adversarialTags),
      missingAdversarialTags: Set.unmodifiable(
        policy.requiredAdversarialTags.difference(adversarialTags),
      ),
      productionReplayHoldoutScenarioCount:
          productionReplayHoldoutScenarioCount,
      protectedHoldoutScenarioCount: protectedHoldoutScenarioCount,
      protectedHoldoutScenarioCountByAgentKind: Map.unmodifiable(
        protectedHoldoutScenarioCountByAgentKind,
      ),
      duplicateProtectedHoldoutScenarioIds: Set.unmodifiable(
        duplicateProtectedHoldoutScenarioIds,
      ),
      duplicateProtectedHoldoutSourceDigests: Set.unmodifiable(
        duplicateProtectedHoldoutSourceDigests,
      ),
      scenarioReviewRequiredCount: scenarioReviewRequiredIds.length,
      completedScenarioReviewCount: completedScenarioReviewIds.length,
      missingScenarioReviewIds: Set.unmodifiable(missingScenarioReviewIds),
      incompleteScenarioReviewIds: Set.unmodifiable(
        incompleteScenarioReviewIds,
      ),
      invalidScenarioReviewIds: Set.unmodifiable(invalidScenarioReviewIds),
      staleScenarioReviewIds: Set.unmodifiable(staleScenarioReviewIds),
      missingScenarioReviewSourceDigestIds: Set.unmodifiable(
        missingScenarioReviewSourceDigestIds,
      ),
    );
  }

  static void _validateScenarioCoverage(
    List<EvalScenario> scenarios,
    EvalTuningPolicy policy,
    EvalTuningReadinessEvidence evidence,
    List<String> failures,
    List<String> warnings,
  ) {
    if (scenarios.length < policy.minScenarioCount) {
      failures.add(
        'scenario count ${scenarios.length} < ${policy.minScenarioCount}',
      );
    }

    for (final agentKind in policy.requiredAgentKinds) {
      final count = evidence.scenarioCountByAgentKind[agentKind] ?? 0;
      if (count < policy.minScenariosPerAgentKind) {
        failures.add(
          '${agentKind.name} scenario count $count < '
          '${policy.minScenariosPerAgentKind}',
        );
      }
    }
    for (final split in policy.requiredSplits) {
      final count = evidence.scenarioCountBySplit[split] ?? 0;
      if (count == 0) {
        failures.add('missing ${split.name} scenarios');
      }
    }
    if (evidence.scenarioCountByPrimaryCapability.length <
        policy.minCapabilityCount) {
      failures.add(
        'capability count '
        '${evidence.scenarioCountByPrimaryCapability.length} < '
        '${policy.minCapabilityCount}',
      );
    }
    if (policy.minScenariosPerCapability > 0) {
      for (final entry in evidence.scenarioCountByPrimaryCapability.entries) {
        if (entry.value < policy.minScenariosPerCapability) {
          failures.add(
            'capability ${entry.key} scenario count ${entry.value} < '
            '${policy.minScenariosPerCapability}',
          );
        }
      }
    }
    if (evidence.adversarialScenarioCount <
        policy.minAdversarialScenarioCount) {
      failures.add(
        'adversarial scenario count ${evidence.adversarialScenarioCount} < '
        '${policy.minAdversarialScenarioCount}',
      );
    }
    if (policy.minAdversarialScenariosPerAgentKind > 0) {
      for (final agentKind in policy.requiredAgentKinds) {
        final count =
            evidence.adversarialScenarioCountByAgentKind[agentKind] ?? 0;
        if (count < policy.minAdversarialScenariosPerAgentKind) {
          failures.add(
            '${agentKind.name} adversarial scenario count $count < '
            '${policy.minAdversarialScenariosPerAgentKind}',
          );
        }
      }
    }
    if (policy.minAdversarialScenariosPerCapability > 0) {
      for (final capabilityId
          in evidence.scenarioCountByPrimaryCapability.keys) {
        final count =
            evidence
                .adversarialScenarioCountByPrimaryCapability[capabilityId] ??
            0;
        if (count < policy.minAdversarialScenariosPerCapability) {
          failures.add(
            'capability $capabilityId adversarial scenario count $count < '
            '${policy.minAdversarialScenariosPerCapability}',
          );
        }
      }
    }
    for (final tag in evidence.missingAdversarialTags) {
      failures.add('missing adversarial tag $tag');
    }
    if (evidence.productionReplayHoldoutScenarioCount <
        policy.minProductionReplayHoldoutScenarios) {
      failures.add(
        'production-replay holdout scenario count '
        '${evidence.productionReplayHoldoutScenarioCount} < '
        '${policy.minProductionReplayHoldoutScenarios}',
      );
    }
    if (!policy.requiredSplits.contains(EvalScenarioSplit.holdout) &&
        (evidence.scenarioCountBySplit[EvalScenarioSplit.holdout] ?? 0) == 0) {
      warnings.add(
        'no holdout scenarios; this is development evidence only',
      );
    }
  }

  static void _validateScenarioReviewCoverage({
    required List<EvalScenario> scenarios,
    required EvalTuningPolicy policy,
    required EvalScenarioCatalogEvidence? catalogEvidence,
    required List<String> failures,
  }) {
    if (!policy.requireReviewedScenarioEvidence) return;
    final protectedScenarioIds =
        (catalogEvidence?.protectedScenarioIds ?? const <String>[]).toSet();
    final protectedHoldoutScenarioIds =
        (catalogEvidence?.protectedHoldoutScenarioIds ?? const <String>[])
            .toSet();
    for (final scenario in [
      ...scenarios,
    ]..sort((a, b) => a.id.compareTo(b.id))) {
      final reasons = _scenarioReviewRequirementReasons(
        scenario,
        protectedScenarioIds,
        protectedHoldoutScenarioIds,
      );
      if (reasons.isEmpty) continue;
      final review = scenario.metadata.review;
      final reasonText = reasons.join(', ');
      if (review == null) {
        failures.add(
          'scenario ${scenario.id} review is required for tuning evidence: '
          '$reasonText',
        );
        continue;
      }
      if (!_isCompletedScenarioReview(review.status)) {
        failures.add(
          'scenario ${scenario.id} review status is '
          '${review.status.jsonValue}, expected reviewed or adjudicated',
        );
        continue;
      }
      if (!_isStructurallyValidScenarioReview(review)) {
        failures.add(
          'scenario ${scenario.id} review metadata is invalid',
        );
        continue;
      }
      final expected = EvalProvenance.scenarioReviewSubjectDigest(scenario);
      if (review.subjectDigest != expected) {
        failures.add(
          'scenario ${scenario.id} review subjectDigest is stale',
        );
        continue;
      }
      if (_requiresScenarioReviewSourceDigest(scenario, protectedScenarioIds) &&
          review.sourceDigest == null) {
        failures.add(
          'scenario ${scenario.id} review sourceDigest is required for '
          'synthetic or protected evidence',
        );
      }
    }
  }

  static void _validateProfileCoverage(
    List<EvalProfile> profiles,
    EvalTuningPolicy policy,
    EvalTuningReadinessEvidence evidence,
    List<String> failures,
  ) {
    for (final profile in profiles) {
      if (profile.trialCount < policy.minTrialsPerProfile) {
        failures.add(
          'profile ${profile.name} trialCount ${profile.trialCount} < '
          '${policy.minTrialsPerProfile}',
        );
      }
    }

    final profileNames = profiles.map((profile) => profile.name).toSet();
    for (final profileName in policy.requiredProfileNames) {
      if (!profileNames.contains(profileName)) {
        failures.add('missing required profile $profileName');
      }
    }
    for (final modelClass in policy.requiredModelClasses) {
      final count = evidence.profileCountByModelClass[modelClass] ?? 0;
      if (count < policy.minProfilesPerModelClass) {
        failures.add(
          'model class ${modelClass.name} profile count $count < '
          '${policy.minProfilesPerModelClass}',
        );
      }
    }
  }

  static void _validateProfileCatalog(
    List<EvalProfile> profiles,
    List<String> failures,
  ) {
    final names = profiles.map((profile) => profile.name).toList();
    for (final duplicate in _duplicates(names)) {
      failures.add('duplicate profile name $duplicate');
    }
    for (final profile in profiles) {
      if (profile.name.trim().isEmpty) {
        failures.add('profile name is empty');
      }
      if (profile.trialCount < 1) {
        failures.add('profile ${profile.name} trialCount must be at least 1');
      }
      if (profile.tokenBudget < 1) {
        failures.add('profile ${profile.name} tokenBudget must be at least 1');
      }
      for (final entry in profile.tokenCostWeights.entries) {
        if (entry.value < 1) {
          failures.add(
            'profile ${profile.name} ${entry.key} must be at least 1',
          );
        }
      }
    }
  }

  static void _validateManifest({
    required EvalRunManifest? manifest,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required EvalTuningPolicy policy,
    required List<String> failures,
  }) {
    if (manifest == null) {
      if (policy.requireManifest) {
        failures.add('run manifest is required');
      }
      return;
    }

    final expectedScenarioSetDigest =
        policy.expectedScenarioSetDigest ??
        EvalProvenance.scenarioSetDigest(scenarios);
    if (manifest.scenarioSetDigest != expectedScenarioSetDigest) {
      failures.add(
        'manifest scenarioSetDigest is ${manifest.scenarioSetDigest}, '
        'expected $expectedScenarioSetDigest',
      );
      if (manifest.scenarioCatalogEvidence?.usesExternalCatalog ?? false) {
        failures.add(
          'run was created with an external scenario catalog; set '
          'EVAL_SCENARIOS to the same catalog before verify/report',
        );
      }
    }

    final expectedProfileSetDigest =
        policy.expectedProfileSetDigest ??
        EvalProvenance.profileSetDigest(profiles);
    if (manifest.profileSetDigest != expectedProfileSetDigest) {
      failures.add(
        'manifest profileSetDigest is ${manifest.profileSetDigest}, '
        'expected $expectedProfileSetDigest',
      );
    }

    final requiredTargetKind = policy.requiredTargetKind;
    if (requiredTargetKind != null &&
        manifest.targetKind != requiredTargetKind) {
      failures.add(
        'manifest targetKind is ${manifest.targetKind}, '
        'expected $requiredTargetKind',
      );
    }
  }

  static void _validateScenarioCatalogEvidence({
    required EvalScenarioCatalogEvidence? catalogEvidence,
    required EvalScenarioCatalogEvidence? manifestEvidence,
    required List<EvalScenario> scenarios,
    required EvalTuningPolicy policy,
    required EvalTuningReadinessEvidence readinessEvidence,
    required List<String> failures,
  }) {
    final expectedScenarioSetDigest = EvalProvenance.scenarioSetDigest(
      scenarios,
    );
    if (catalogEvidence == null) {
      if (policy.requireProtectedHoldout) {
        failures.add('protected holdout evidence is missing');
      }
      if (policy.minProtectedHoldoutScenarios > 0) {
        failures.add(
          'protected holdout scenario count 0 < '
          '${policy.minProtectedHoldoutScenarios}',
        );
      }
      if (policy.minProtectedHoldoutScenariosPerAgentKind > 0) {
        for (final agentKind in policy.requiredAgentKinds) {
          failures.add(
            '${agentKind.name} protected holdout scenario count 0 < '
            '${policy.minProtectedHoldoutScenariosPerAgentKind}',
          );
        }
      }
      return;
    }
    if (catalogEvidence.scenarioSetDigest != expectedScenarioSetDigest) {
      failures.add(
        'scenario catalog evidence scenarioSetDigest is '
        '${catalogEvidence.scenarioSetDigest}, '
        'expected $expectedScenarioSetDigest',
      );
    }
    if (manifestEvidence != null &&
        EvalProvenance.digestJson(manifestEvidence.toJson()) !=
            EvalProvenance.digestJson(catalogEvidence.toJson())) {
      failures.add(
        'scenario catalog evidence does not match the run manifest',
      );
    }
    final hasProtectedHoldoutRequirement =
        policy.requireProtectedHoldout ||
        policy.minProtectedHoldoutScenarios > 0 ||
        policy.minProtectedHoldoutScenariosPerAgentKind > 0;
    if (!hasProtectedHoldoutRequirement) return;
    if (manifestEvidence == null && policy.requireManifest) {
      failures.add('manifest scenario catalog evidence is missing');
    }
    if (!catalogEvidence.hasProtectedHoldoutEvidence) {
      if (catalogEvidence.usesExternalCatalog &&
          !catalogEvidence.protectedHoldout &&
          readinessEvidence.productionReplayHoldoutScenarioCount > 0) {
        failures.add(
          'external production-replay holdouts are present but '
          'protectedHoldout=false; they cannot satisfy protected holdout '
          'evidence',
        );
      }
      failures.add('protected holdout evidence is missing');
      return;
    }
    final scenariosById = {
      for (final scenario in scenarios) scenario.id: scenario,
    };
    for (final scenarioId in catalogEvidence.protectedHoldoutScenarioIds) {
      final scenario = scenariosById[scenarioId];
      if (scenario == null) {
        failures.add(
          'protected holdout evidence references unknown scenario $scenarioId',
        );
      } else if (scenario.metadata.split != EvalScenarioSplit.holdout) {
        failures.add(
          'protected holdout evidence references non-holdout scenario '
          '$scenarioId',
        );
      }
    }
    if (catalogEvidence.protectedHoldoutScenarioIds.isEmpty) {
      failures.add('protected holdout scenario evidence is missing');
    }
    for (final duplicate
        in readinessEvidence.duplicateProtectedHoldoutScenarioIds) {
      failures.add('duplicate protected holdout evidence id $duplicate');
    }
    for (final duplicate
        in readinessEvidence.duplicateProtectedHoldoutSourceDigests) {
      failures.add(
        'duplicate protected holdout sourceDigest $duplicate',
      );
    }
    for (final scenarioId
        in catalogEvidence.protectedHoldoutScenarioIds.toSet()) {
      final scenario = scenariosById[scenarioId];
      if (scenario == null ||
          scenario.metadata.split != EvalScenarioSplit.holdout) {
        continue;
      }
      if (scenario.metadata.source != EvalScenarioSource.productionReplay) {
        failures.add(
          'protected holdout evidence references non-production-replay '
          'scenario $scenarioId',
        );
        continue;
      }
    }
    if (readinessEvidence.protectedHoldoutScenarioCount <
        policy.minProtectedHoldoutScenarios) {
      failures.add(
        'protected holdout scenario count '
        '${readinessEvidence.protectedHoldoutScenarioCount} < '
        '${policy.minProtectedHoldoutScenarios}',
      );
    }
    if (policy.minProtectedHoldoutScenariosPerAgentKind > 0) {
      for (final agentKind in policy.requiredAgentKinds) {
        final count =
            readinessEvidence
                .protectedHoldoutScenarioCountByAgentKind[agentKind] ??
            0;
        if (count < policy.minProtectedHoldoutScenariosPerAgentKind) {
          failures.add(
            '${agentKind.name} protected holdout scenario count $count < '
            '${policy.minProtectedHoldoutScenariosPerAgentKind}',
          );
        }
      }
    }
  }

  static void _validateJudgeCalibration(
    List<EvalTrace> traces,
    List<EvalScenario> scenarios,
    EvalTuningPolicy policy,
    JudgeCalibrationSet? calibrationSet,
    JudgeCalibrationReport? calibrationReport,
    List<String> failures,
    List<String> warnings,
  ) {
    final requiredVersion = policy.requiredCalibrationSetVersion;
    if (policy.requireCalibratedVerdicts && requiredVersion == null) {
      failures.add('policy requires a calibration-set version');
    }
    for (final trace in traces) {
      final verdict = trace.verdict;
      if (verdict == null) continue;
      final version = verdict.judge.calibrationSetVersion;
      if (policy.requireCalibratedVerdicts &&
          (version.trim().isEmpty || version == 'uncalibrated')) {
        failures.add('uncalibrated verdict for ${_traceKey(trace)}');
      }
      if (requiredVersion != null && version != requiredVersion) {
        failures.add(
          '${_traceKey(trace)} verdict calibrationSetVersion is $version, '
          'expected $requiredVersion',
        );
      }
      if (policy.requireBlindedJudgeVerdicts &&
          verdict.judge.modelIdentityVisible) {
        failures.add(
          'unblinded judge verdict for ${_traceKey(trace)}',
        );
      }
    }
    if (!policy.requireCalibratedVerdicts) {
      final uncalibrated = traces.where((trace) {
        final version = trace.verdict?.judge.calibrationSetVersion;
        return version == null || version == 'uncalibrated';
      }).length;
      if (uncalibrated > 0) {
        warnings.add('uncalibrated or unjudged traces: $uncalibrated');
      }
    }
    if (calibrationSet == null && _hasCalibrationReportRequirement(policy)) {
      failures.add('judge calibration set is required for readiness gates');
    }
    _validateCalibrationReport(
      traces: traces,
      scenarios: scenarios,
      policy: policy,
      report: calibrationReport,
      failures: failures,
      warnings: warnings,
    );
  }

  static void _validateCalibrationReport({
    required List<EvalTrace> traces,
    required List<EvalScenario> scenarios,
    required EvalTuningPolicy policy,
    required JudgeCalibrationReport? report,
    required List<String> failures,
    required List<String> warnings,
  }) {
    if (report == null) {
      if (_hasCalibrationReportRequirement(policy)) {
        failures.add('judge calibration report is required');
      }
      return;
    }

    final judgedTraceCount = traces
        .where((trace) => trace.verdict != null)
        .length;
    if (report.judgedTraceCount != judgedTraceCount) {
      failures.add(
        'calibration report judgedTraceCount is ${report.judgedTraceCount}, '
        'expected $judgedTraceCount',
      );
    }
    final requiredVersion = policy.requiredCalibrationSetVersion;
    if (requiredVersion != null &&
        report.judgeCalibrationSetVersion != requiredVersion) {
      failures.add(
        'calibration report judgeCalibrationSetVersion is '
        '${report.judgeCalibrationSetVersion}, expected $requiredVersion',
      );
    }
    final requiredHumanVersion = policy.requiredHumanCalibrationSetVersion;
    if (requiredHumanVersion != null &&
        report.calibrationSetVersion != requiredHumanVersion) {
      failures.add(
        'calibration report human version is ${report.calibrationSetVersion}, '
        'expected $requiredHumanVersion',
      );
    }
    if (report.evaluatedCount < policy.minCalibrationEvaluatedCount) {
      failures.add(
        'calibration evaluated count ${report.evaluatedCount} < '
        '${policy.minCalibrationEvaluatedCount}',
      );
    }
    if (report.goldCoverageRate < policy.minCalibrationCoverageRate) {
      failures.add(
        'calibration coverage ${_pct(report.goldCoverageRate)} < '
        '${_pct(policy.minCalibrationCoverageRate)}',
      );
    }
    if (report.goldCoverageEstimate.lowerBound <
        policy.minCalibrationCoverageLowerBound) {
      failures.add(
        'calibration coverage lower bound '
        '${_pct(report.goldCoverageEstimate.lowerBound)} < '
        '${_pct(policy.minCalibrationCoverageLowerBound)}',
      );
    }
    if (report.passAgreementRate < policy.minCalibrationPassAgreementRate) {
      failures.add(
        'calibration pass agreement ${_pct(report.passAgreementRate)} < '
        '${_pct(policy.minCalibrationPassAgreementRate)}',
      );
    }
    if (report.passAgreementEstimate.lowerBound <
        policy.minCalibrationPassAgreementLowerBound) {
      failures.add(
        'calibration pass agreement lower bound '
        '${_pct(report.passAgreementEstimate.lowerBound)} < '
        '${_pct(policy.minCalibrationPassAgreementLowerBound)}',
      );
    }
    if (report.scoreAgreementRate < policy.minCalibrationScoreAgreementRate) {
      failures.add(
        'calibration score agreement ${_pct(report.scoreAgreementRate)} < '
        '${_pct(policy.minCalibrationScoreAgreementRate)}',
      );
    }
    if (report.scoreAgreementEstimate.lowerBound <
        policy.minCalibrationScoreAgreementLowerBound) {
      failures.add(
        'calibration score agreement lower bound '
        '${_pct(report.scoreAgreementEstimate.lowerBound)} < '
        '${_pct(policy.minCalibrationScoreAgreementLowerBound)}',
      );
    }
    if (report.humanReviewPairCount <
        policy.minCalibrationHumanReviewPairCount) {
      failures.add(
        'calibration human review pairs ${report.humanReviewPairCount} < '
        '${policy.minCalibrationHumanReviewPairCount}',
      );
    }
    if (report.humanPassAgreementRate <
        policy.minCalibrationHumanPassAgreementRate) {
      failures.add(
        'calibration human pass agreement '
        '${_pct(report.humanPassAgreementRate)} < '
        '${_pct(policy.minCalibrationHumanPassAgreementRate)}',
      );
    }
    if (report.humanPassAgreementEstimate.lowerBound <
        policy.minCalibrationHumanPassAgreementLowerBound) {
      failures.add(
        'calibration human pass agreement lower bound '
        '${_pct(report.humanPassAgreementEstimate.lowerBound)} < '
        '${_pct(policy.minCalibrationHumanPassAgreementLowerBound)}',
      );
    }
    if (report.humanScoreAgreementRate <
        policy.minCalibrationHumanScoreAgreementRate) {
      failures.add(
        'calibration human score agreement '
        '${_pct(report.humanScoreAgreementRate)} < '
        '${_pct(policy.minCalibrationHumanScoreAgreementRate)}',
      );
    }
    if (report.humanScoreAgreementEstimate.lowerBound <
        policy.minCalibrationHumanScoreAgreementLowerBound) {
      failures.add(
        'calibration human score agreement lower bound '
        '${_pct(report.humanScoreAgreementEstimate.lowerBound)} < '
        '${_pct(policy.minCalibrationHumanScoreAgreementLowerBound)}',
      );
    }
    final maxUnresolvedHumanDisagreement =
        policy.maxCalibrationUnresolvedHumanDisagreementCount;
    if (maxUnresolvedHumanDisagreement != null &&
        report.unresolvedHumanDisagreementCount >
            maxUnresolvedHumanDisagreement) {
      failures.add(
        'calibration unresolved human disagreement count '
        '${report.unresolvedHumanDisagreementCount} > '
        '$maxUnresolvedHumanDisagreement',
      );
    }
    if (policy.requireBlindedHumanReviews &&
        report.unblindedHumanReviewCount > 0) {
      failures.add(
        'calibration unblinded human review count '
        '${report.unblindedHumanReviewCount} > 0',
      );
    }
    final maxFalsePassCount = policy.maxCalibrationFalsePassCount;
    if (maxFalsePassCount != null &&
        report.falsePassCount > maxFalsePassCount) {
      failures.add(
        'calibration false-pass count ${report.falsePassCount} > '
        '$maxFalsePassCount',
      );
    }
    final falsePassRate = _rate(report.falsePassCount, report.evaluatedCount);
    if (falsePassRate > policy.maxCalibrationFalsePassRate) {
      failures.add(
        'calibration false-pass rate ${_pct(falsePassRate)} > '
        '${_pct(policy.maxCalibrationFalsePassRate)}',
      );
    }
    final falseFailRate = _rate(report.falseFailCount, report.evaluatedCount);
    if (falseFailRate > policy.maxCalibrationFalseFailRate) {
      failures.add(
        'calibration false-fail rate ${_pct(falseFailRate)} > '
        '${_pct(policy.maxCalibrationFalseFailRate)}',
      );
    }
    if (policy.requireBlindedCalibrationReport &&
        !report.modelIdentityBlinded) {
      failures.add('calibration report is not model-identity blinded');
    }
    _validateCalibrationSliceCoverage(
      report: report,
      scenarios: scenarios,
      policy: policy,
      failures: failures,
    );
    if (policy.requireCleanCalibrationReport) {
      if (report.staleLabelCount > 0) {
        failures.add(
          'calibration report has ${report.staleLabelCount} stale labels',
        );
      }
      if (report.missingTraceCount > 0) {
        failures.add(
          'calibration report has ${report.missingTraceCount} missing traces',
        );
      }
      if (report.missingVerdictCount > 0) {
        failures.add(
          'calibration report has ${report.missingVerdictCount} missing verdicts',
        );
      }
      if (report.judgeCalibrationMismatchCount > 0) {
        failures.add(
          'calibration report has '
          '${report.judgeCalibrationMismatchCount} calibration mismatches',
        );
      }
      final duplicateGoldLabelCount = report.findings
          .where(
            (finding) =>
                finding.kind == JudgeCalibrationFindingKind.duplicateGoldLabel,
          )
          .length;
      if (duplicateGoldLabelCount > 0) {
        failures.add(
          'calibration report has $duplicateGoldLabelCount duplicate gold '
          'labels',
        );
      }
    } else if (report.staleLabelCount > 0 ||
        report.missingTraceCount > 0 ||
        report.missingVerdictCount > 0 ||
        report.judgeCalibrationMismatchCount > 0) {
      warnings.add('calibration report contains non-evaluated labels');
    }
  }

  static bool _hasCalibrationReportRequirement(EvalTuningPolicy policy) =>
      policy.requireCalibrationReport ||
      policy.minCalibrationEvaluatedCount > 0 ||
      policy.minCalibrationEvaluatedPerModelClass > 0 ||
      policy.minCalibrationEvaluatedPerCapability > 0 ||
      policy.minCalibrationCoverageRate > 0 ||
      policy.minCalibrationCoverageLowerBound > 0 ||
      policy.minCalibrationPassAgreementRate > 0 ||
      policy.minCalibrationPassAgreementLowerBound > 0 ||
      policy.minCalibrationScoreAgreementRate > 0 ||
      policy.minCalibrationScoreAgreementLowerBound > 0 ||
      policy.minCalibrationHumanReviewPairCount > 0 ||
      policy.minCalibrationHumanPassAgreementRate > 0 ||
      policy.minCalibrationHumanPassAgreementLowerBound > 0 ||
      policy.minCalibrationHumanScoreAgreementRate > 0 ||
      policy.minCalibrationHumanScoreAgreementLowerBound > 0 ||
      policy.maxCalibrationUnresolvedHumanDisagreementCount != null ||
      policy.requireBlindedHumanReviews ||
      policy.maxCalibrationFalsePassCount != null ||
      policy.maxCalibrationFalsePassRate < 1 ||
      policy.maxCalibrationFalseFailRate < 1 ||
      policy.requireBlindedCalibrationReport ||
      policy.requireCleanCalibrationReport;

  static void _validateCalibrationSliceCoverage({
    required JudgeCalibrationReport report,
    required List<EvalScenario> scenarios,
    required EvalTuningPolicy policy,
    required List<String> failures,
  }) {
    if (policy.minCalibrationEvaluatedPerModelClass > 0) {
      final byModelClass = {
        for (final summary in report.modelClassSummaries)
          summary.name: summary.evaluatedCount,
      };
      for (final modelClass in policy.requiredModelClasses) {
        final count = byModelClass[modelClass.name] ?? 0;
        if (count < policy.minCalibrationEvaluatedPerModelClass) {
          failures.add(
            'calibration model class ${modelClass.name} evaluated count '
            '$count < ${policy.minCalibrationEvaluatedPerModelClass}',
          );
        }
      }
    }
    if (policy.minCalibrationEvaluatedPerCapability > 0) {
      final byCapability = {
        for (final summary in report.capabilitySummaries)
          summary.name: summary.evaluatedCount,
      };
      final capabilityIds = <String>{
        for (final scenario in scenarios)
          if (scenario.metadata.primaryCapabilityId != null)
            scenario.metadata.primaryCapabilityId!,
      };
      for (final capabilityId in capabilityIds) {
        final count = byCapability[capabilityId] ?? 0;
        if (count < policy.minCalibrationEvaluatedPerCapability) {
          failures.add(
            'calibration capability $capabilityId evaluated count $count < '
            '${policy.minCalibrationEvaluatedPerCapability}',
          );
        }
      }
    }
  }

  static Set<String> _expectedTraceKeys(
    List<EvalScenario> scenarios,
    List<EvalProfile> profiles,
  ) {
    return {
      for (final scenario in scenarios)
        for (final profile in profiles)
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          )
            _key(scenario.id, profile.name, trialIndex),
    };
  }

  static String _traceKey(EvalTrace trace) =>
      _key(trace.scenario.id, trace.profile.name, trace.trialIndex);

  static String _key(String scenarioId, String profileName, int trialIndex) =>
      '$scenarioId::$profileName::trial-$trialIndex';

  static Set<String> _duplicates(Iterable<String> values) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final value in values) {
      if (!seen.add(value)) duplicates.add(value);
    }
    return duplicates;
  }

  static void _increment<K>(Map<K, int> counts, K key) {
    counts.update(key, (count) => count + 1, ifAbsent: () => 1);
  }

  static String _renderCatalogEvidence(
    EvalScenarioCatalogEvidence? evidence,
  ) {
    if (evidence == null) {
      return 'source publicOnly=true external=0 protectedHoldout=false';
    }
    return 'source public=${evidence.publicScenarioCount} '
        'external=${evidence.externalScenarioCount} '
        'protectedHoldout=${evidence.protectedHoldout} '
        'catalogId=${evidence.externalCatalogId ?? '-'} '
        'sourceLabel=${evidence.externalSourceLabel ?? '-'} '
        'digest=${evidence.externalCatalogDigest ?? '-'}';
  }

  static String _redactProtectedScenarioIds(
    String output,
    EvalScenarioCatalogEvidence? evidence,
  ) {
    if (evidence == null || !evidence.usesExternalCatalog) return output;
    var redacted = output;
    final ids = {
      ...evidence.protectedScenarioIds,
      ...evidence.protectedHoldoutScenarioIds,
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final id in ids) {
      redacted = redacted.replaceAll(id, '<protected-scenario>');
    }
    return redacted;
  }

  static String _renderEnumCounts<K extends Enum>(Map<K, int> counts) {
    if (counts.isEmpty) return '{}';
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.name.compareTo(b.key.name));
    final rendered = entries
        .map((entry) => '${entry.key.name}:${entry.value}')
        .join(', ');
    return '{$rendered}';
  }

  static String _renderStringCounts(Map<String, int> counts) {
    if (counts.isEmpty) return '{}';
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final rendered = entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(', ');
    return '{$rendered}';
  }

  static String _renderSet(Set<String> values) {
    if (values.isEmpty) return '{}';
    return '{${(values.toList()..sort()).join(', ')}}';
  }

  static String _actualRequired(int actual, int required) =>
      required > 0 ? '$actual/$required' : '$actual';

  static bool _isAdversarialScenario(EvalScenario scenario) =>
      scenario.metadata.isAdversarial;

  static Set<String> _scenarioReviewRequirementReasons(
    EvalScenario scenario,
    Set<String> protectedScenarioIds,
    Set<String> protectedHoldoutScenarioIds,
  ) {
    final reasons = <String>{};
    if (_isAdversarialScenario(scenario) ||
        scenario.metadata.source == EvalScenarioSource.adversarial) {
      reasons.add('adversarial');
    }
    if (scenario.metadata.source == EvalScenarioSource.synthetic) {
      reasons.add('synthetic');
    }
    if (scenario.metadata.split == EvalScenarioSplit.holdout &&
        scenario.metadata.source == EvalScenarioSource.productionReplay) {
      reasons.add('production-replay holdout');
    }
    if (protectedScenarioIds.contains(scenario.id)) {
      reasons.add('protected scenario');
    }
    if (protectedHoldoutScenarioIds.contains(scenario.id)) {
      reasons.add('protected holdout');
    }
    return reasons;
  }

  static bool _isCompletedScenarioReview(EvalScenarioReviewStatus status) =>
      status == EvalScenarioReviewStatus.reviewed ||
      status == EvalScenarioReviewStatus.adjudicated;

  static bool _isStructurallyValidScenarioReview(EvalScenarioReview review) {
    if (review.reviewer.trim().isEmpty) return false;
    if (review.rationale.trim().isEmpty) return false;
    try {
      DateTime.parse(review.reviewedAt);
    } on FormatException {
      return false;
    }
    if (!EvalProvenance.isDigest(review.subjectDigest)) return false;
    final sourceDigest = review.sourceDigest;
    if (sourceDigest != null && !EvalProvenance.isDigest(sourceDigest)) {
      return false;
    }
    return true;
  }

  static bool _requiresScenarioReviewSourceDigest(
    EvalScenario scenario,
    Set<String> protectedScenarioIds,
  ) =>
      scenario.metadata.source == EvalScenarioSource.synthetic ||
      protectedScenarioIds.contains(scenario.id);

  static double _rate(int count, int total) => total == 0 ? 0 : count / total;

  static String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
}
