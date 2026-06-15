import 'dart:convert';
import 'dart:io';

import '../scenarios/eval_scenario_catalog.dart';
import 'eval_harness.dart';
import 'eval_profile_config.dart';

final class EvalTuningSourceReplayConfig {
  const EvalTuningSourceReplayConfig({
    required this.runsRoot,
    required this.scenarioCatalogPath,
    required this.scenarioCatalogMode,
    required this.scenarioIds,
    required this.profileCatalogPath,
    required this.profileNames,
    required this.promptVariantCatalogPath,
    required this.promptVariantNames,
    required this.calibrationPath,
    required this.promotionPlanPath,
  });

  final String runsRoot;
  final String scenarioCatalogPath;
  final String scenarioCatalogMode;
  final String scenarioIds;
  final String profileCatalogPath;
  final String profileNames;
  final String promptVariantCatalogPath;
  final String promptVariantNames;
  final String calibrationPath;
  final String promotionPlanPath;
}

Future<Map<String, EvalTuningReportSourceCheckResult>>
evalSourceChecksForReports(
  List<Map<String, dynamic>> reports, {
  required EvalTuningSourceReplayConfig config,
}) async {
  final writer = TraceWriter(runsRoot: config.runsRoot);
  final catalog = _loadScenarioCatalog(config);
  final profiles = _loadProfiles(config);
  final promptVariants = _loadPromptVariants(config);
  final calibrationSet = _readCalibrationSet(config);
  final checks = <String, EvalTuningReportSourceCheckResult>{};
  for (final report in reports) {
    final reportDigest = EvalProvenance.digestJson(report);
    final runId = _string(_map(report['run'])['runId']);
    if (runId.isEmpty) {
      checks[reportDigest] = EvalTuningReportSourceCheckResult.missing(
        report,
        issueCode: 'report.sourceRunIdMissing',
      );
      continue;
    }
    try {
      final run = await writer.readRun(runId);
      final pairwise = await writer.readPairwisePreferenceArtifacts(
        runId,
        traces: run.traces,
      );
      final promotionPlan = _promotionPlanFromConfig(config);
      final promotionDecision = _promotionDecisionForReport(
        report: report,
        run: run,
        catalog: catalog,
        profiles: profiles,
        pairwiseVotes: pairwise.votes,
        pairwiseTraceRefsByKey: pairwise.traceRefsByKey,
        calibrationSet: calibrationSet,
        promotionPlan: promotionPlan,
      );
      checks[reportDigest] = EvalTuningReportSourceCheck.validateReport(
        report: report,
        sourceRun: run,
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
        scenarioCatalogEvidence: catalog.evidence,
        calibrationSet: calibrationSet,
        pairwisePreferenceVotes: pairwise.votes,
        pairwiseTraceRefsByKey: pairwise.traceRefsByKey,
        promotionPlan: promotionPlan,
        promotionDecision: promotionDecision,
      );
    } on Object {
      checks[reportDigest] = EvalTuningReportSourceCheckResult.missing(
        report,
        issueCode: 'report.sourceRunUnreadable',
      );
    }
  }
  return checks;
}

Future<List<EvalUseCaseModelClassExecutionRun>>
evalLoadModelClassExecutionRuns({
  required EvalTuningSourceReplayConfig config,
  required List<String> runIds,
}) async {
  final writer = TraceWriter(runsRoot: config.runsRoot);
  final catalog = _loadScenarioCatalog(config);
  final profiles = _loadProfiles(config);
  final promptVariants = _loadPromptVariants(config);
  final runs = <EvalUseCaseModelClassExecutionRun>[];
  for (final runId in runIds) {
    runs.add(
      EvalUseCaseModelClassExecutionRun(
        artifacts: await writer.readRun(runId),
        scenarios: catalog.scenarios,
        profiles: profiles,
        agentDirectiveVariants: promptVariants,
      ),
    );
  }
  return runs;
}

EvalScenarioCatalog _loadScenarioCatalog(EvalTuningSourceReplayConfig config) {
  return EvalScenarioCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefinePath: config.scenarioCatalogPath,
    dartDefineMode: config.scenarioCatalogMode,
    dartDefineScenarioIds: config.scenarioIds,
  );
}

List<EvalProfile> _loadProfiles(EvalTuningSourceReplayConfig config) {
  return EvalProfileCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: config.profileCatalogPath,
    dartDefineProfileNames: config.profileNames,
  ).profiles;
}

List<EvalAgentDirectiveVariant> _loadPromptVariants(
  EvalTuningSourceReplayConfig config,
) {
  return EvalAgentDirectiveVariantCatalogLoader.fromEnvironment(
    Platform.environment,
    dartDefineValue: config.promptVariantCatalogPath,
    dartDefineVariantNames: config.promptVariantNames,
  ).variants;
}

JudgeCalibrationSet? _readCalibrationSet(EvalTuningSourceReplayConfig config) {
  if (config.calibrationPath.trim().isEmpty) return null;
  final json = jsonDecode(File(config.calibrationPath).readAsStringSync());
  return JudgeCalibrationSet.fromJson(json as Map<String, dynamic>);
}

EvalPromotionPlan? _promotionPlanFromConfig(
  EvalTuningSourceReplayConfig config,
) {
  if (config.promotionPlanPath.trim().isEmpty) return null;
  return EvalPromotionPlan.fromJson(
    jsonDecode(File(config.promotionPlanPath).readAsStringSync())
        as Map<String, dynamic>,
  );
}

ProfilePromotionDecision? _promotionDecisionForReport({
  required Map<String, dynamic> report,
  required EvalRunArtifacts run,
  required EvalScenarioCatalog catalog,
  required List<EvalProfile> profiles,
  required List<EvalPairwisePreferenceVote> pairwiseVotes,
  required Map<String, EvalPairwiseTraceRef> pairwiseTraceRefsByKey,
  required JudgeCalibrationSet? calibrationSet,
  required EvalPromotionPlan? promotionPlan,
}) {
  final plan = promotionPlan;
  if (plan == null) return null;
  final policyPayload = _map(_map(report['policy'])['payload']);
  final readinessPolicy = EvalTuningPolicy.fromJson(policyPayload);
  final readiness = EvalTuningReadiness.assess(
    traces: run.traces,
    scenarios: catalog.scenarios,
    profiles: profiles,
    manifest: run.manifest,
    scenarioCatalogEvidence: catalog.evidence,
    policy: readinessPolicy,
    calibrationSet: calibrationSet,
    pairwisePreferenceVotes: pairwiseVotes,
    pairwiseTraceRefsByKey: pairwiseTraceRefsByKey,
  );
  return EvalReporter.evaluateProfilePromotion(
    traces: run.traces,
    policy: ProfilePromotionPolicy(
      candidateProfileName: plan.candidateProfileName,
      baselineProfileName: plan.baselineProfileName,
    ),
    readinessReport: readiness,
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _string(Object? value) => value is String ? value : '';
