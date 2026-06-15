import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';
import 'eval_profile_config.dart';

void main() {
  test('valid source-derived report passes source check', () {
    final fixture = _fixture();
    final verification = EvalRunVerifier.verify(
      runId: fixture.run.manifest.runId,
      traces: fixture.run.traces,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      manifest: fixture.run.manifest,
      artifactNames: fixture.run.artifactNames,
      tuningPolicy: const EvalTuningPolicy.developmentSmoke(),
    );
    expect(verification.errors, isEmpty);

    final result = EvalTuningReportSourceCheck.validateReport(
      report: fixture.report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(result.sourceIssueCodes, isEmpty);
    expect(result.isSourceChecked, isTrue);
    expect(result.manifestDigest, fixture.run.manifest.manifestDigest);
  });

  test('ready restamp fails source check', () {
    final fixture = _fixture(
      policy: const EvalTuningPolicy(
        name: 'strict-outcomes',
        minJudgePassRate: 1,
      ),
      verdictPass: false,
    );
    final report = _mutable(fixture.report);
    report['status'] = const <String, dynamic>{
      'ready': true,
      'label': 'tuning-ready',
      'failureCount': 0,
      'warningCount': 0,
    };
    final readiness = report['readiness'] as Map<String, dynamic>
      ..['ready'] = true
      ..['evidenceLabel'] = 'tuning-ready'
      ..['failures'] = const <String>[];
    final plan = report['nextExperimentPlan'] as Map<String, dynamic>
      ..['status'] = 'ready'
      ..['objective'] = 'readyForPromotionReview'
      ..['blockedReasonCodes'] = const <String>[];

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(result.isSourceChecked, isFalse);
    expect(result.sourceIssueCodes, contains('report.sourceStatusMismatch'));
    expect(result.sourceIssueCodes, contains('report.sourceReadinessMismatch'));
    expect(readiness['ready'], isTrue);
    expect(plan['status'], 'ready');
  });

  test('policy restamp fails source check', () {
    final fixture = _fixture(
      policy: const EvalTuningPolicy.modelClassTuning(
        requiredPrimaryCapabilityIds: {'task.grooming.basic'},
      ),
    );
    final report = _mutable(fixture.report);
    const forgedPolicy = EvalTuningPolicy.developmentSmoke();
    report['policy'] = <String, dynamic>{
      'name': forgedPolicy.name,
      'digest': forgedPolicy.policyDigest,
      'payload': forgedPolicy.toJson(),
    };

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourcePolicyEvidenceMismatch'),
    );
    expect(
      result.sourceIssueCodes,
      contains('report.sourceRunVerificationFailed'),
    );
  });

  test('selector restamp fails source check', () {
    final fixture = _fixture();
    final report = _mutable(fixture.report);
    final selectors =
        (report['run'] as Map<String, dynamic>)['selectors']
            as Map<String, dynamic>;
    selectors['promptVariantNames'] = const ['planned-batch-prompt'];

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourceSelectorsMismatch'),
    );
  });

  test('promotion restamp without source decision fails closed', () {
    final fixture = _fixture();
    final report = _mutable(fixture.report);
    report['promotion'] = const <String, dynamic>{
      'present': true,
      'status': 'promote',
      'candidateProfileName': 'frontier-candidate',
      'baselineProfileName': 'frontier-baseline',
      'evidencePlan': null,
      'failures': <String>[],
      'warnings': <String>[],
    };

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(result.sourceIssueCodes, contains('report.sourcePromotionMissing'));
  });

  test('promotion decision without source plan fails closed', () {
    final fixture = _fixture();
    final report = _mutable(fixture.report);
    report['promotion'] = const <String, dynamic>{
      'present': true,
      'status': 'promote',
      'candidateProfileName': 'frontier-candidate',
      'baselineProfileName': 'frontier-baseline',
      'evidencePlan': null,
      'failures': <String>[],
      'warnings': <String>[],
    };
    const decision = ProfilePromotionDecision(
      policy: ProfilePromotionPolicy(
        candidateProfileName: 'frontier-candidate',
        baselineProfileName: 'frontier-baseline',
      ),
      status: ProfilePromotionStatus.promote,
      comparison: null,
      failures: <String>[],
      warnings: <String>[],
    );

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
      promotionDecision: decision,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourcePromotionPlanMissing'),
    );
  });

  test('forged promotion decision is recomputed from source traces', () {
    final fixture = _fixture();
    const promotionPolicy = ProfilePromotionPolicy(
      candidateProfileName: 'frontier-source',
      baselineProfileName: 'frontier-baseline',
    );
    final draftPlan = EvalPromotionPlan(
      planId: 'source-check-promotion-plan',
      candidateProfileName: promotionPolicy.candidateProfileName,
      baselineProfileName: promotionPolicy.baselineProfileName,
      scenarioSetDigest: fixture.run.manifest.scenarioSetDigest,
      profileSetDigest: fixture.run.manifest.profileSetDigest,
      policyDigest: EvalProvenance.digestJson(
        EvalReporter.promotionPolicyJson(promotionPolicy),
      ),
    );
    final manifest = EvalProvenance.captureRunManifest(
      runId: fixture.run.manifest.runId,
      targetName: fixture.run.manifest.targetName,
      targetKind: fixture.run.manifest.targetKind,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      scenarioCatalogEvidence: fixture.catalogEvidence,
      promotionPlan: draftPlan,
      tuningReadinessPolicyEvidence:
          fixture.run.manifest.tuningReadinessPolicyEvidence,
      environment: const <String, String>{},
      createdAt: fixture.run.manifest.createdAt,
      command: fixture.run.manifest.command,
    );
    final sourceRun = EvalRunArtifacts(
      manifest: manifest,
      traces: fixture.run.traces,
      artifactNames: fixture.run.artifactNames,
    );
    final finalizedPlan = EvalPromotionPlan(
      planId: draftPlan.planId,
      candidateProfileName: draftPlan.candidateProfileName,
      baselineProfileName: draftPlan.baselineProfileName,
      scenarioSetDigest: draftPlan.scenarioSetDigest,
      profileSetDigest: draftPlan.profileSetDigest,
      policyDigest: draftPlan.policyDigest,
      manifestDigest: manifest.manifestDigest,
    );
    const forgedDecision = ProfilePromotionDecision(
      policy: promotionPolicy,
      status: ProfilePromotionStatus.promote,
      comparison: null,
      failures: <String>[],
      warnings: <String>[],
    );
    final report = _mutable(fixture.report);
    report['promotion'] = const <String, dynamic>{
      'present': true,
      'status': 'promote',
      'candidateProfileName': 'frontier-source',
      'baselineProfileName': 'frontier-baseline',
      'evidencePlan': null,
      'failures': <String>[],
      'warnings': <String>[],
    };

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: sourceRun,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
      promotionPlan: finalizedPlan,
      promotionDecision: forgedDecision,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourcePromotionDecisionMismatch'),
    );
    expect(
      result.sourceIssueCodes,
      contains('report.sourcePromotionMismatch'),
    );
  });

  test('slice recommendation restamp fails source check', () {
    final fixture = _fixture(
      policy: const EvalTuningPolicy(
        name: 'strict-outcomes',
        minJudgePassRate: 1,
      ),
      verdictPass: false,
    );
    final report = _mutable(fixture.report);
    final slices = report['useCaseModelSlices'] as List<dynamic>;
    (slices.single as Map<String, dynamic>)
      ..['blockingReasons'] = const <String>[]
      ..['recommendation'] = 'keep';

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourceUseCaseModelSlicesMismatch'),
    );
  });

  test('stale artifact snapshot fails source check', () {
    final fixture = _fixture();
    final report = _mutable(fixture.report);
    final run = report['run'] as Map<String, dynamic>;
    final snapshot = run['artifactSnapshot'] as Map<String, dynamic>;
    snapshot['loadedTraceContentDigest'] = EvalProvenance.digestText('stale');

    final result = EvalTuningReportSourceCheck.validateReport(
      report: report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourceArtifactSnapshotMismatch'),
    );
  });

  test('calibration-required report without source labels fails closed', () {
    final fixture = _fixture(
      policy: const EvalTuningPolicy(
        name: 'calibration-required',
        requireCalibrationReport: true,
      ),
    );

    final result = EvalTuningReportSourceCheck.validateReport(
      report: fixture.report,
      sourceRun: fixture.run,
      scenarios: fixture.scenarios,
      profiles: fixture.profiles,
      agentDirectiveVariants: fixture.promptVariants,
      scenarioCatalogEvidence: fixture.catalogEvidence,
    );

    expect(
      result.sourceIssueCodes,
      contains('report.sourceCalibrationMissing'),
    );
  });
}

_Fixture _fixture({
  EvalTuningPolicy policy = const EvalTuningPolicy.developmentSmoke(),
  bool verdictPass = true,
}) {
  const profile = EvalProfile(
    name: 'frontier-source',
    isLocal: false,
    modelClass: EvalModelClass.frontierReasoning,
    modelId: 'frontier-source-model',
    tokenBudget: 1000,
  );
  const promptVariants = [EvalAgentDirectiveVariant()];
  final scenarios = [taskReleaseNotesScenario];
  final profiles = [profile];
  final catalogEvidence = EvalScenarioCatalogEvidence(
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
    publicScenarioCount: scenarios.length,
    externalScenarioCount: 0,
    protectedHoldout: false,
    protectedScenarioIds: const [],
    protectedHoldoutScenarioIds: const [],
  );
  final policyEvidence = EvalTuningReadinessPolicyEvidence(
    policyName: policy.name,
    policyDigest: policy.policyDigest,
  );
  final manifest = EvalProvenance.captureRunManifest(
    runId: 'source-run',
    targetName: 'source-check-fixture',
    targetKind: 'fixture',
    scenarios: scenarios,
    profiles: profiles,
    scenarioCatalogEvidence: catalogEvidence,
    tuningReadinessPolicyEvidence: policyEvidence,
    environment: const <String, String>{},
    createdAt: DateTime.utc(2026, 6, 12, 8),
    command: 'eval source check fixture',
  );
  final provenance = EvalProvenance.capture(
    scenario: taskReleaseNotesScenario,
    profile: profile,
    manifestDigest: manifest.manifestDigest!,
  );
  final profileConfig = evalProfileConfig(profile);
  final output = AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 10, outputTokens: 10),
    report: const AgentReportRecord(
      oneLiner: 'Release notes are ready',
      tldr: 'The release-notes task is groomed.',
      content: 'The release-notes task has a status, estimate, and checklist.',
    ),
    resolvedModel: profileConfig.toResolvedModelRecord(
      wakeRunResolvedModelId: profileConfig.providerModelId,
      usageModelId: profileConfig.providerModelId,
    ),
    providerDecision: profileConfig.toProviderDecisionRecord(
      envPresence: const {'GEMINI_API_KEY': true},
    ),
  );
  final trace = EvalTrace(
    runId: manifest.runId,
    scenario: taskReleaseNotesScenario,
    profile: profile,
    provenance: provenance,
    output: output,
    level1Checks: runLevel1(
      taskReleaseNotesScenario,
      output,
      profile: profile,
    ),
    verdict: JudgeVerdict(
      traceDigest: EvalProvenance.digestText('trace'),
      goalAttainment: verdictPass ? 5 : 2,
      quality: verdictPass ? 5 : 2,
      efficiency: verdictPass ? 4 : 2,
      pass: verdictPass,
      issues: verdictPass ? const <String>[] : const ['fixture failure'],
      judge: JudgeProvenanceRecord(
        judgeName: 'fixture-judge',
        judgeModel: 'fixture-model',
        promptDigest: provenance.promptDigest,
        calibrationSetVersion: 'fixture-gold-v1',
        profileVisible: true,
        modelIdentityVisible: true,
      ),
    ),
  );
  final run = EvalRunArtifacts(
    manifest: manifest,
    traces: [trace],
    artifactNames: const <String>[],
  );
  final readiness = EvalTuningReadiness.assess(
    traces: run.traces,
    scenarios: scenarios,
    profiles: profiles,
    manifest: manifest,
    scenarioCatalogEvidence: catalogEvidence,
    policy: policy,
  );
  final slices = [_sliceJson(trace, policy)];
  final blockedReasonCodes = _blockedReasonCodes(
    readiness: readiness,
    slices: slices,
  );
  final report = <String, dynamic>{
    'schemaVersion': EvalTuningReportContract.schemaVersion,
    'kind': EvalTuningReportContract.kind,
    'generatedAt': DateTime.utc(2026, 6, 12, 9).toIso8601String(),
    'run': <String, dynamic>{
      'runId': manifest.runId,
      'targetKind': manifest.targetKind,
      'manifestDigest': manifest.manifestDigest,
      'createdAt': manifest.createdAt.toUtc().toIso8601String(),
      'scenarioSetDigest': manifest.scenarioSetDigest,
      'profileSetDigest': manifest.profileSetDigest,
      'profileBindingSetDigest': manifest.profileBindingSetDigest,
      'agentDirectiveVariantSetDigest': manifest.agentDirectiveVariantSetDigest,
      'selectors': <String, dynamic>{
        'scenarioIds': [taskReleaseNotesScenario.id],
        'profileNames': [profile.name],
        'promptVariantNames': const ['default'],
        'requiredPrimaryCapabilityIds': _sortedStrings(
          policy.requiredPrimaryCapabilityIds,
        ),
      },
      'protectedIdsRedacted': false,
      'artifactSnapshot': _artifactSnapshotJson(run),
    },
    'policy': <String, dynamic>{
      'name': readiness.policyName,
      'digest': readiness.policyDigest,
      'payload': policy.toJson(),
    },
    'status': <String, dynamic>{
      'ready': readiness.ready,
      'label': readiness.evidenceLabel,
      'failureCount': readiness.failures.length,
      'warningCount': readiness.warnings.length,
    },
    'gates': const <Map<String, dynamic>>[],
    'coverage': <String, dynamic>{
      'scenarioCount': readiness.scenarioCount,
      'profileCount': readiness.profileCount,
      'promptVariantCount': promptVariants.length,
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
    },
    'readiness': <String, dynamic>{
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
    },
    'outcomes': <String, dynamic>{
      'aggregate': const <String, dynamic>{},
      'slices': slices,
      'failingTraceCount': verdictPass ? 0 : 1,
    },
    'calibration': const <String, dynamic>{'present': false},
    'pairwise': const <String, dynamic>{'present': false},
    'promotion': const <String, dynamic>{
      'present': false,
      'status': 'notRequested',
      'evidencePlan': null,
    },
    'useCaseModelSlices': slices,
    'blockedReasons': [
      for (final code in blockedReasonCodes)
        <String, dynamic>{
          'code': code,
          'severity': 'blocking',
          'message': 'Fixture blocker $code.',
          'nextAction': 'inspectReadinessGate',
          'scope': const <String, dynamic>{},
        },
    ],
    'recommendations': const <Map<String, dynamic>>[],
    'nextExperimentPlan': <String, dynamic>{
      'schemaVersion': EvalTuningReportContract.schemaVersion,
      'kind': EvalTuningReportContract.nextExperimentPlanKind,
      'baseRunId': manifest.runId,
      'objective': readiness.ready
          ? 'readyForPromotionReview'
          : 'closeReadinessGaps',
      'status': readiness.ready ? 'ready' : 'blocked',
      'blockedReasonCodes': blockedReasonCodes,
      'requiredCapabilities': _sortedStrings(
        policy.requiredPrimaryCapabilityIds,
      ),
      'suggestedCapabilities': const <String>[],
      'suggestedScenarioIds': const <String>[],
      'suggestedProfileNames': const <String>[],
      'suggestedPromptVariantNames': const <String>[],
      'requiredPairwiseIntentKeys': const <String>[],
      'missingOrFailedPairwiseKeys': const <String>[],
      'nextRunEnv': const <String, dynamic>{},
      'recommendedCommands': const [
        <String, dynamic>{
          'mode': 'plan',
          'command': 'eval/run_level2.sh plan <nextRunId>',
        },
      ],
    },
  };
  expect(EvalTuningReportContract.validate(report), isEmpty);
  return _Fixture(
    run: run,
    scenarios: scenarios,
    profiles: profiles,
    promptVariants: promptVariants,
    catalogEvidence: catalogEvidence,
    report: report,
  );
}

Map<String, dynamic> _sliceJson(EvalTrace trace, EvalTuningPolicy policy) {
  final verdict = trace.verdict;
  final passCount = verdict?.pass ?? false ? 1 : 0;
  final passRate = verdict == null ? 0.0 : passCount.toDouble();
  final passEstimate = RateEstimate.wilson(
    successes: passCount,
    total: verdict == null ? 0 : 1,
  );
  final tokenBudgetRatio =
      trace.output.usage.totalTokens / trace.profile.tokenBudget;
  final gates = [
    if (policy.minJudgePassRate > 0)
      _gateJson(
        id: 'outcome.slice.judge_pass_rate',
        status: passRate >= policy.minJudgePassRate ? 'pass' : 'fail',
        actual: passRate,
        required: policy.minJudgePassRate,
        comparator: '>=',
        blockerCode: 'outcome.passRateLow',
        scope: _sliceScope(trace),
      ),
  ];
  return <String, dynamic>{
    'sliceKey':
        '${trace.scenario.metadata.primaryCapabilityId}@'
        '${trace.scenario.agentKind.name}@'
        '${trace.profile.modelClass.name}@'
        '${trace.agentDirectiveVariant.name}',
    'primaryCapabilityId': trace.scenario.metadata.primaryCapabilityId,
    'agentKind': trace.scenario.agentKind.name,
    'modelClass': trace.profile.modelClass.name,
    'promptVariantName': trace.agentDirectiveVariant.name,
    'scenarioIds': [trace.scenario.id],
    'profileNames': [trace.profile.name],
    'traceCount': 1,
    'judgedTraceCount': verdict == null ? 0 : 1,
    'passCount': passCount,
    'level1PassCount': 1,
    'passRate': passRate,
    'passRateLowerBound': passEstimate.lowerBound,
    'meanGoalAttainment': (verdict?.goalAttainment ?? 0).toDouble(),
    'meanQuality': (verdict?.quality ?? 0).toDouble(),
    'meanEfficiency': (verdict?.efficiency ?? 0).toDouble(),
    'meanTokenBudgetRatio': tokenBudgetRatio,
    'weightedCostTraceCount': 1,
    'missingWeightedCostCount': 0,
    'meanWeightedCostBudgetRatio': tokenBudgetRatio,
    'recommendation': passRate < policy.minJudgePassRate
        ? 'improveOutcome'
        : 'keep',
    'blockingReasons': [
      for (final gate in gates)
        if (gate['status'] == 'fail') gate['blockerCode'] as String,
    ],
    'gates': gates,
  };
}

Map<String, dynamic> _sliceScope(EvalTrace trace) => <String, dynamic>{
  'capabilityId': trace.scenario.metadata.primaryCapabilityId,
  'agentKind': trace.scenario.agentKind.name,
  'modelClass': trace.profile.modelClass.name,
  'promptVariantName': trace.agentDirectiveVariant.name,
};

Map<String, dynamic> _gateJson({
  required String id,
  required String status,
  required Object actual,
  required Object required,
  required String comparator,
  required String blockerCode,
  required Map<String, dynamic> scope,
}) => <String, dynamic>{
  'id': id,
  'status': status,
  'scope': scope,
  'actual': actual,
  'required': required,
  'comparator': comparator,
  'evidenceRefs': const <String>[],
  'blockerCode': blockerCode,
};

List<String> _blockedReasonCodes({
  required EvalTuningReadinessReport readiness,
  required List<Map<String, dynamic>> slices,
}) {
  return _sortedStrings({
    for (final failure in readiness.failures) _blockedReasonCode(failure),
    for (final slice in slices)
      for (final code
          in (slice['blockingReasons'] as List<dynamic>).cast<String>())
        code,
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
  if (value.contains('calibration report') ||
      value.contains('calibration set')) {
    return 'calibration.reportMissing';
  }
  if (value.contains('calibration')) return 'calibration.gateFailed';
  if (value.contains('capability')) return 'coverage.capabilityMissing';
  if (value.contains('outcome')) return 'outcome.thresholdFailed';
  return 'readiness.failed';
}

Map<String, dynamic> _artifactSnapshotJson(EvalRunArtifacts run) {
  final trace = run.traces.single;
  final traceSnapshot = <String, dynamic>{
    'scenarioDigest': trace.provenance.scenarioDigest,
    'profileDigest': trace.provenance.profileDigest,
    'agentDirectiveVariantDigest': trace.provenance.agentDirectiveVariantDigest,
    'trialIndex': trace.trialIndex,
    'hasVerdict': trace.verdict != null,
    'traceJsonDigest': EvalProvenance.digestJson(trace.toJson()),
  };
  final manifestDigest = run.manifest.manifestDigest!;
  final ownedArtifactRefs = <Map<String, dynamic>>[
    <String, dynamic>{
      'kind': 'manifest',
      'manifestDigest': manifestDigest,
    },
    <String, dynamic>{
      'kind': 'trace',
      'scenarioDigest': traceSnapshot['scenarioDigest'],
      'profileDigest': traceSnapshot['profileDigest'],
      'agentDirectiveVariantDigest':
          traceSnapshot['agentDirectiveVariantDigest'],
      'trialIndex': traceSnapshot['trialIndex'],
    },
    <String, dynamic>{
      'kind': 'verdict',
      'scenarioDigest': traceSnapshot['scenarioDigest'],
      'profileDigest': traceSnapshot['profileDigest'],
      'agentDirectiveVariantDigest':
          traceSnapshot['agentDirectiveVariantDigest'],
      'trialIndex': traceSnapshot['trialIndex'],
    },
  ];
  return <String, dynamic>{
    'artifactCount': ownedArtifactRefs.length,
    'traceCount': 1,
    'judgedTraceCount': 1,
    'manifestDigest': manifestDigest,
    'ownedArtifactRefsDigest': EvalProvenance.digestJson(ownedArtifactRefs),
    'loadedTraceContentDigest': EvalProvenance.digestJson([traceSnapshot]),
  };
}

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

Map<String, dynamic> _mutable(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _Fixture {
  const _Fixture({
    required this.run,
    required this.scenarios,
    required this.profiles,
    required this.promptVariants,
    required this.catalogEvidence,
    required this.report,
  });

  final EvalRunArtifacts run;
  final List<EvalScenario> scenarios;
  final List<EvalProfile> profiles;
  final List<EvalAgentDirectiveVariant> promptVariants;
  final EvalScenarioCatalogEvidence catalogEvidence;
  final Map<String, dynamic> report;
}
