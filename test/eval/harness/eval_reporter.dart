// Aggregates traces + verdicts into a per-profile summary (ADR 0029).
//
// Pure (no IO) so it is unit-testable. The `run_level2.sh` reporter step loads
// traces via `TraceWriter.readTraces` and passes them here.

import 'dart:math' as math;

import 'eval_models.dart';
import 'eval_provenance.dart';
import 'eval_statistics.dart';
import 'eval_tuning_readiness.dart';

/// Rolled-up numbers for one model profile across all scenarios in a run.
class ProfileSummary {
  const ProfileSummary({
    required this.profileName,
    required this.scenarioCount,
    required this.completeScenarioCount,
    required this.traceCount,
    required this.level1PassCount,
    required this.level1ReliableScenarioCount,
    required this.meanTotalTokens,
    required this.judgedCount,
    required this.judgePassCount,
    required this.judgeReliableScenarioCount,
    required this.meanGoalAttainment,
    required this.meanQuality,
    required this.meanEfficiency,
  });

  final String profileName;
  final int scenarioCount;
  final int completeScenarioCount;
  final int traceCount;
  final int level1PassCount;
  final int level1ReliableScenarioCount;
  final double meanTotalTokens;
  final int judgedCount;
  final int judgePassCount;
  final int judgeReliableScenarioCount;
  final double meanGoalAttainment;
  final double meanQuality;
  final double meanEfficiency;

  double get level1PassRate =>
      traceCount == 0 ? 0 : level1PassCount / traceCount;

  /// Diagnostic trace-level interval; repeated trials are not independent
  /// scenario evidence.
  RateEstimate get level1TracePassEstimate => RateEstimate.wilson(
    successes: level1PassCount,
    total: traceCount,
  );

  /// Tuning-facing interval clustered at the scenario level.
  RateEstimate get level1PassEstimate => level1ReliableScenarioEstimate;

  double get completeScenarioRate =>
      scenarioCount == 0 ? 0 : completeScenarioCount / scenarioCount;

  RateEstimate get completeScenarioEstimate => RateEstimate.wilson(
    successes: completeScenarioCount,
    total: scenarioCount,
  );

  /// Scenario-level reliability: every expected trial passed Level 1.
  double get level1ReliableScenarioRate =>
      scenarioCount == 0 ? 0 : level1ReliableScenarioCount / scenarioCount;

  RateEstimate get level1ReliableScenarioEstimate => RateEstimate.wilson(
    successes: level1ReliableScenarioCount,
    total: scenarioCount,
  );

  double get level1CompleteScenarioReliabilityRate => completeScenarioCount == 0
      ? 0
      : level1ReliableScenarioCount / completeScenarioCount;

  RateEstimate get level1CompleteScenarioReliabilityEstimate =>
      RateEstimate.wilson(
        successes: level1ReliableScenarioCount,
        total: completeScenarioCount,
      );

  double get judgePassRate =>
      judgedCount == 0 ? 0 : judgePassCount / judgedCount;

  /// Diagnostic trace-level interval; repeated trials are not independent
  /// scenario evidence.
  RateEstimate get judgeTracePassEstimate => RateEstimate.wilson(
    successes: judgePassCount,
    total: judgedCount,
  );

  /// Tuning-facing interval clustered at the scenario level.
  RateEstimate get judgePassEstimate => judgeReliableScenarioEstimate;

  /// Scenario-level judge reliability: every expected trial was judged pass.
  double get judgeReliableScenarioRate =>
      scenarioCount == 0 ? 0 : judgeReliableScenarioCount / scenarioCount;

  RateEstimate get judgeReliableScenarioEstimate => RateEstimate.wilson(
    successes: judgeReliableScenarioCount,
    total: scenarioCount,
  );

  double get judgeCompleteScenarioReliabilityRate => completeScenarioCount == 0
      ? 0
      : judgeReliableScenarioCount / completeScenarioCount;

  RateEstimate get judgeCompleteScenarioReliabilityEstimate =>
      RateEstimate.wilson(
        successes: judgeReliableScenarioCount,
        total: completeScenarioCount,
      );
}

/// Rolled-up numbers for one profile/capability pair.
class CapabilitySummary {
  const CapabilitySummary({
    required this.profileName,
    required this.capabilityId,
    required this.scenarioCount,
    required this.completeScenarioCount,
    required this.trialCount,
    required this.traceCount,
    required this.level1PassCount,
    required this.level1ReliableScenarioCount,
    required this.judgedCount,
    required this.judgePassCount,
    required this.judgeReliableScenarioCount,
    required this.meanTotalTokens,
  });

  final String profileName;
  final String capabilityId;
  final int scenarioCount;
  final int completeScenarioCount;
  final int trialCount;
  final int traceCount;
  final int level1PassCount;
  final int level1ReliableScenarioCount;
  final int judgedCount;
  final int judgePassCount;
  final int judgeReliableScenarioCount;
  final double meanTotalTokens;

  double get coverageRate => trialCount == 0 ? 0 : traceCount / trialCount;

  double get judgedTraceRate => traceCount == 0 ? 0 : judgedCount / traceCount;

  double get level1PassRate =>
      traceCount == 0 ? 0 : level1PassCount / traceCount;

  double get judgePassRate =>
      judgedCount == 0 ? 0 : judgePassCount / judgedCount;

  /// Diagnostic trace-level interval; repeated trials are not independent
  /// scenario evidence.
  RateEstimate get level1TracePassEstimate => RateEstimate.wilson(
    successes: level1PassCount,
    total: traceCount,
  );

  /// Tuning-facing interval clustered at the scenario level.
  RateEstimate get level1PassEstimate => level1ReliableScenarioEstimate;

  /// Diagnostic trace-level interval; repeated trials are not independent
  /// scenario evidence.
  RateEstimate get judgeTracePassEstimate => RateEstimate.wilson(
    successes: judgePassCount,
    total: judgedCount,
  );

  /// Tuning-facing interval clustered at the scenario level.
  RateEstimate get judgePassEstimate => judgeReliableScenarioEstimate;

  /// Scenario-level reliability: every expected trial passed Level 1.
  double get level1ReliableScenarioRate =>
      scenarioCount == 0 ? 0 : level1ReliableScenarioCount / scenarioCount;

  RateEstimate get level1ReliableScenarioEstimate => RateEstimate.wilson(
    successes: level1ReliableScenarioCount,
    total: scenarioCount,
  );

  /// Scenario-level judge reliability: every expected trial was judged pass.
  double get judgeReliableScenarioRate =>
      scenarioCount == 0 ? 0 : judgeReliableScenarioCount / scenarioCount;

  RateEstimate get judgeReliableScenarioEstimate => RateEstimate.wilson(
    successes: judgeReliableScenarioCount,
    total: scenarioCount,
  );
}

/// Rolled-up numbers for one split/model-class/primary-capability slice.
class SliceSummary {
  const SliceSummary({
    required this.split,
    required this.modelClass,
    required this.capabilityId,
    required this.profileCount,
    required this.scenarioCount,
    required this.scenarioProfileCount,
    required this.completeScenarioCount,
    required this.completeScenarioProfileCount,
    required this.trialCount,
    required this.traceCount,
    required this.level1PassCount,
    required this.level1ReliableScenarioProfileCount,
    required this.judgedTraceCount,
    required this.judgePassCount,
    required this.judgeReliableScenarioProfileCount,
    required this.meanTotalTokens,
  });

  final EvalScenarioSplit split;
  final EvalModelClass modelClass;
  final String capabilityId;
  final int profileCount;
  final int scenarioCount;
  final int scenarioProfileCount;
  final int completeScenarioCount;
  final int completeScenarioProfileCount;
  final int trialCount;
  final int traceCount;
  final int level1PassCount;
  final int level1ReliableScenarioProfileCount;
  final int judgedTraceCount;
  final int judgePassCount;
  final int judgeReliableScenarioProfileCount;
  final double meanTotalTokens;

  double get coverageRate => trialCount == 0 ? 0 : traceCount / trialCount;

  double get judgedTraceRate =>
      traceCount == 0 ? 0 : judgedTraceCount / traceCount;

  double get level1PassRate =>
      traceCount == 0 ? 0 : level1PassCount / traceCount;

  double get judgePassRate =>
      judgedTraceCount == 0 ? 0 : judgePassCount / judgedTraceCount;

  double get level1ReliableScenarioProfileRate => scenarioProfileCount == 0
      ? 0
      : level1ReliableScenarioProfileCount / scenarioProfileCount;

  double get judgeReliableScenarioProfileRate => scenarioProfileCount == 0
      ? 0
      : judgeReliableScenarioProfileCount / scenarioProfileCount;

  /// Diagnostic trace-level interval; repeated trials are not independent
  /// scenario evidence.
  RateEstimate get level1TracePassEstimate => RateEstimate.wilson(
    successes: level1PassCount,
    total: traceCount,
  );

  /// Tuning-facing interval clustered at the scenario-profile cell level.
  RateEstimate get level1PassEstimate => RateEstimate.wilson(
    successes: level1ReliableScenarioProfileCount,
    total: scenarioProfileCount,
  );

  /// Diagnostic trace-level interval; repeated trials are not independent
  /// scenario evidence.
  RateEstimate get judgeTracePassEstimate => RateEstimate.wilson(
    successes: judgePassCount,
    total: judgedTraceCount,
  );

  /// Tuning-facing interval clustered at the scenario-profile cell level.
  RateEstimate get judgePassEstimate => RateEstimate.wilson(
    successes: judgeReliableScenarioProfileCount,
    total: scenarioProfileCount,
  );
}

/// Request-shape evidence for one scenario/profile/provider turn.
///
/// This deliberately reports full-request fingerprint stability only. It does
/// not claim per-token prefix-cache attribution, because provider usage is
/// reported at the trace level.
class ProviderRequestStabilitySummary {
  const ProviderRequestStabilitySummary({
    required this.scenarioId,
    required this.profileName,
    required this.providerType,
    required this.providerModelId,
    required this.endpointKey,
    required this.invocationIndex,
    required this.requestIndex,
    required this.turnIndex,
    required this.expectedTrialCount,
    required this.traceCount,
    required this.requestCount,
    required this.uniqueMessageDigestCount,
    required this.uniqueToolSchemaDigestCount,
    required this.messageCounts,
    required this.toolCounts,
    required this.thoughtSignatureCounts,
  });

  final String scenarioId;
  final String profileName;
  final String providerType;
  final String providerModelId;
  final String endpointKey;
  final int invocationIndex;
  final int requestIndex;
  final int turnIndex;
  final int expectedTrialCount;
  final int traceCount;
  final int requestCount;
  final int uniqueMessageDigestCount;
  final int uniqueToolSchemaDigestCount;
  final List<int> messageCounts;
  final List<int> toolCounts;
  final List<int> thoughtSignatureCounts;

  int get missingTrialCount => expectedTrialCount - traceCount;

  bool get requestShapeStable =>
      uniqueMessageDigestCount == 1 &&
      uniqueToolSchemaDigestCount == 1 &&
      messageCounts.length == 1 &&
      toolCounts.length == 1 &&
      thoughtSignatureCounts.length == 1;
}

/// Trace-level provider usage coverage for one scenario/profile pair.
///
/// Cached-token values are aggregate trace outcomes, not per-request
/// attributions. A missing cached-token field means the provider stream did not
/// report cache usage to the app, not that the provider cache was zero.
class ProviderUsageCacheSummary {
  const ProviderUsageCacheSummary({
    required this.scenarioId,
    required this.profileName,
    required this.expectedTrialCount,
    required this.traceCount,
    required this.inputTokenTraceCount,
    required this.cachedInputTokenTraceCount,
    required this.fullyReportedTraceCount,
    required this.reportedInputTokens,
    required this.reportedCachedInputTokens,
  });

  final String scenarioId;
  final String profileName;
  final int expectedTrialCount;
  final int traceCount;
  final int inputTokenTraceCount;
  final int cachedInputTokenTraceCount;
  final int fullyReportedTraceCount;
  final int reportedInputTokens;
  final int reportedCachedInputTokens;

  int get missingTrialCount => expectedTrialCount - traceCount;

  double? get reportedCacheRate {
    if (fullyReportedTraceCount == 0 || reportedInputTokens == 0) return null;
    return reportedCachedInputTokens / reportedInputTokens;
  }
}

class _ProviderRequestStabilityBucket {
  _ProviderRequestStabilityBucket({
    required this.scenarioId,
    required this.profileName,
    required this.providerType,
    required this.providerModelId,
    required this.endpointKey,
    required this.invocationIndex,
    required this.requestIndex,
    required this.turnIndex,
    required this.expectedTrialCount,
  });

  final String scenarioId;
  final String profileName;
  final String providerType;
  final String providerModelId;
  final String endpointKey;
  final int invocationIndex;
  final int requestIndex;
  final int turnIndex;
  final int expectedTrialCount;
  final _traceKeys = <String>{};
  final _messageDigests = <String>{};
  final _toolSchemaDigests = <String>{};
  final _messageCounts = <int>{};
  final _toolCounts = <int>{};
  final _thoughtSignatureCounts = <int>{};
  int requestCount = 0;

  void add(EvalTrace trace, ProviderRequestRecord request) {
    requestCount++;
    _traceKeys.add(_traceKey(trace));
    _messageDigests.add(request.messageDigest);
    _toolSchemaDigests.add(request.toolSchemaDigest);
    _messageCounts.add(request.messageCount);
    _toolCounts.add(request.toolCount);
    _thoughtSignatureCounts.add(request.thoughtSignatureCount);
  }

  ProviderRequestStabilitySummary toSummary() =>
      ProviderRequestStabilitySummary(
        scenarioId: scenarioId,
        profileName: profileName,
        providerType: providerType,
        providerModelId: providerModelId,
        endpointKey: endpointKey,
        invocationIndex: invocationIndex,
        requestIndex: requestIndex,
        turnIndex: turnIndex,
        expectedTrialCount: expectedTrialCount,
        traceCount: _traceKeys.length,
        requestCount: requestCount,
        uniqueMessageDigestCount: _messageDigests.length,
        uniqueToolSchemaDigestCount: _toolSchemaDigests.length,
        messageCounts: _sortedInts(_messageCounts),
        toolCounts: _sortedInts(_toolCounts),
        thoughtSignatureCounts: _sortedInts(_thoughtSignatureCounts),
      );
}

String _traceKey(EvalTrace trace) =>
    '${trace.runId}\n${trace.scenario.id}\n${trace.profile.name}\n'
    '${trace.trialIndex}';

List<int> _sortedInts(Set<int> values) {
  final sorted = values.toList()..sort();
  return sorted;
}

/// Optional context that lets reports use the expected run matrix instead of
/// only the matrix cells that happened to produce traces.
class EvalReportContext {
  const EvalReportContext({
    required this.scenarios,
    required this.profiles,
    this.manifest,
    this.allowProtectedScenarioIds = false,
  });

  final List<EvalScenario> scenarios;
  final List<EvalProfile> profiles;
  final EvalRunManifest? manifest;
  final bool allowProtectedScenarioIds;
}

class _ExpectedSliceMatrix {
  _ExpectedSliceMatrix({
    required this.split,
    required this.modelClass,
    required this.capabilityId,
  });

  final EvalScenarioSplit split;
  final EvalModelClass modelClass;
  final String capabilityId;
  final Map<String, EvalScenario> scenarios = {};
  final Map<String, EvalProfile> profiles = {};
}

/// Paired comparison for two profiles over common complete scenarios.
///
/// Only scenarios with complete trial sets for both profiles contribute to
/// paired pass deltas. Missing, profile-only, and incomplete/ambiguous scenario
/// groups are counted separately so callers do not mistake partial overlap for
/// a full head-to-head comparison.
class ProfilePairComparison {
  const ProfilePairComparison({
    required this.leftProfileName,
    required this.rightProfileName,
    required this.pairedScenarioCount,
    required this.leftOnlyScenarioCount,
    required this.rightOnlyScenarioCount,
    required this.incompleteScenarioCount,
    required this.level1LeftPassCount,
    required this.level1RightPassCount,
    required this.level1LeftOnlyPassCount,
    required this.level1RightOnlyPassCount,
    required this.level1SameOutcomeCount,
    required this.judgePairedScenarioCount,
    required this.judgeMissingScenarioCount,
    required this.judgeLeftPassCount,
    required this.judgeRightPassCount,
    required this.judgeLeftOnlyPassCount,
    required this.judgeRightOnlyPassCount,
    required this.judgeSameOutcomeCount,
    required this.meanGoalAttainmentDelta,
    required this.meanQualityDelta,
    required this.meanEfficiencyDelta,
    required this.meanTotalTokenDelta,
    required this.totalTokenRatio,
    required this.estimatedCostScenarioCount,
    required this.estimatedCostMissingScenarioCount,
    required this.meanEstimatedCostDelta,
    required this.estimatedCostRatio,
    required this.usesEstimatedCost,
    required this.leftUsesWeightedTokenCosts,
    required this.rightUsesWeightedTokenCosts,
  });

  final String leftProfileName;
  final String rightProfileName;
  final int pairedScenarioCount;
  final int leftOnlyScenarioCount;
  final int rightOnlyScenarioCount;
  final int incompleteScenarioCount;
  final int level1LeftPassCount;
  final int level1RightPassCount;
  final int level1LeftOnlyPassCount;
  final int level1RightOnlyPassCount;
  final int level1SameOutcomeCount;
  final int judgePairedScenarioCount;
  final int judgeMissingScenarioCount;
  final int judgeLeftPassCount;
  final int judgeRightPassCount;
  final int judgeLeftOnlyPassCount;
  final int judgeRightOnlyPassCount;
  final int judgeSameOutcomeCount;
  final double meanGoalAttainmentDelta;
  final double meanQualityDelta;
  final double meanEfficiencyDelta;
  final double meanTotalTokenDelta;
  final double totalTokenRatio;
  final int estimatedCostScenarioCount;
  final int estimatedCostMissingScenarioCount;
  final double meanEstimatedCostDelta;
  final double estimatedCostRatio;
  final bool usesEstimatedCost;
  final bool leftUsesWeightedTokenCosts;
  final bool rightUsesWeightedTokenCosts;

  double get level1LeftPassRate =>
      pairedScenarioCount == 0 ? 0 : level1LeftPassCount / pairedScenarioCount;

  double get level1RightPassRate =>
      pairedScenarioCount == 0 ? 0 : level1RightPassCount / pairedScenarioCount;

  double get level1PassDelta => level1LeftPassRate - level1RightPassRate;

  RateEstimate get level1LeftPassEstimate => RateEstimate.wilson(
    successes: level1LeftPassCount,
    total: pairedScenarioCount,
  );

  RateEstimate get level1RightPassEstimate => RateEstimate.wilson(
    successes: level1RightPassCount,
    total: pairedScenarioCount,
  );

  double get level1PassDeltaLowerBound =>
      level1LeftPassEstimate.lowerBound - level1RightPassEstimate.upperBound;

  double get judgeLeftPassRate => judgePairedScenarioCount == 0
      ? 0
      : judgeLeftPassCount / judgePairedScenarioCount;

  double get judgeRightPassRate => judgePairedScenarioCount == 0
      ? 0
      : judgeRightPassCount / judgePairedScenarioCount;

  double get judgePassDelta => judgeLeftPassRate - judgeRightPassRate;

  RateEstimate get judgeLeftPassEstimate => RateEstimate.wilson(
    successes: judgeLeftPassCount,
    total: judgePairedScenarioCount,
  );

  RateEstimate get judgeRightPassEstimate => RateEstimate.wilson(
    successes: judgeRightPassCount,
    total: judgePairedScenarioCount,
  );

  double get judgePassDeltaLowerBound =>
      judgeLeftPassEstimate.lowerBound - judgeRightPassEstimate.upperBound;

  int get judgeDiscordantScenarioCount =>
      judgeLeftOnlyPassCount + judgeRightOnlyPassCount;

  double get judgePairedSignTestPValue => _oneSidedSignTestPValue(
    successes: judgeLeftOnlyPassCount,
    total: judgeDiscordantScenarioCount,
  );

  bool get isComparable => pairedScenarioCount > 0;

  bool get isLowSample => pairedScenarioCount > 0 && pairedScenarioCount < 8;
}

enum ProfilePromotionStatus { promote, reject, inconclusive, blocked }

/// Policy for turning a paired profile comparison into a promotion decision.
class ProfilePromotionPolicy {
  const ProfilePromotionPolicy({
    required this.candidateProfileName,
    required this.baselineProfileName,
    this.requireTuningReadiness = true,
    this.requireNoMissingJudgeVerdicts = true,
    this.requireNoLevel1Regression = true,
    this.minPairedScenarioCount = 12,
    this.minJudgePairedScenarioCount = 12,
    this.minJudgeDiscordantScenarioCount = 6,
    this.minJudgePassDelta = 0.05,
    this.minJudgePassDeltaLowerBound = 0,
    this.minLevel1PassDelta = 0,
    this.minLevel1PassDeltaLowerBound = -1,
    this.minMeanGoalAttainmentDelta = 0,
    this.minMeanQualityDelta = 0,
    this.minMeanEfficiencyDelta = -0.25,
    this.maxTotalTokenRatio = 1.25,
    this.maxEstimatedCostRatio = 1.25,
    this.maxJudgePairedSignTestPValue = 0.10,
  });

  final String candidateProfileName;
  final String baselineProfileName;
  final bool requireTuningReadiness;
  final bool requireNoMissingJudgeVerdicts;
  final bool requireNoLevel1Regression;
  final int minPairedScenarioCount;
  final int minJudgePairedScenarioCount;
  final int minJudgeDiscordantScenarioCount;
  final double minJudgePassDelta;
  final double minJudgePassDeltaLowerBound;
  final double minLevel1PassDelta;
  final double minLevel1PassDeltaLowerBound;
  final double minMeanGoalAttainmentDelta;
  final double minMeanQualityDelta;
  final double minMeanEfficiencyDelta;
  final double maxTotalTokenRatio;
  final double maxEstimatedCostRatio;
  final double maxJudgePairedSignTestPValue;
}

class ProfilePromotionEvidencePlan {
  const ProfilePromotionEvidencePlan({
    required this.currentPairedScenarioCount,
    required this.currentJudgePairedScenarioCount,
    required this.additionalPairedScenariosForMinCount,
    required this.additionalJudgeScenariosForMinCount,
    required this.additionalJudgeScenariosForLowerBound,
    required this.additionalJudgeScenariosForPairedSignTest,
    required this.projectedJudgePairedScenarioCount,
    required this.projectedJudgePassDeltaLowerBound,
    required this.projectedJudgePairedSignTestPValue,
    required this.assumedCandidateJudgePassRate,
    required this.assumedBaselineJudgePassRate,
    required this.blockers,
  });

  final int currentPairedScenarioCount;
  final int currentJudgePairedScenarioCount;
  final int additionalPairedScenariosForMinCount;
  final int additionalJudgeScenariosForMinCount;
  final int? additionalJudgeScenariosForLowerBound;
  final int? additionalJudgeScenariosForPairedSignTest;
  final int? projectedJudgePairedScenarioCount;
  final double? projectedJudgePassDeltaLowerBound;
  final double? projectedJudgePairedSignTestPValue;
  final double assumedCandidateJudgePassRate;
  final double assumedBaselineJudgePassRate;
  final List<String> blockers;

  int? get recommendedAdditionalJudgeScenarios {
    if (additionalJudgeScenariosForLowerBound == null ||
        additionalJudgeScenariosForPairedSignTest == null) {
      return null;
    }
    final candidates = <int>[
      additionalJudgeScenariosForMinCount,
      additionalJudgeScenariosForLowerBound!,
      additionalJudgeScenariosForPairedSignTest!,
    ];
    return candidates.reduce(_maxInt);
  }
}

const _maxPromotionPlanningPairedScenarios = 240;
const _logTwo = 0.6931471805599453;

int _maxInt(int left, int right) => left > right ? left : right;

double _oneSidedSignTestPValue({
  required int successes,
  required int total,
}) {
  if (total <= 0) return 1;
  if (successes <= 0) return 1;
  if (successes > total) return 0;

  var maxLogTerm = double.negativeInfinity;
  final logTerms = <double>[];
  for (var wins = successes; wins <= total; wins++) {
    final logTerm = _logCombination(total, wins) - total * _logTwo;
    logTerms.add(logTerm);
    if (logTerm > maxLogTerm) maxLogTerm = logTerm;
  }

  var scaledSum = 0.0;
  for (final logTerm in logTerms) {
    scaledSum += math.exp(logTerm - maxLogTerm);
  }
  final pValue = math.exp(maxLogTerm) * scaledSum;
  if (pValue < 0) return 0;
  return pValue > 1 ? 1 : pValue;
}

double _logCombination(int n, int k) {
  if (k < 0 || k > n) return double.negativeInfinity;
  final effectiveK = k > n - k ? n - k : k;
  var sum = 0.0;
  for (var i = 1; i <= effectiveK; i++) {
    sum += math.log(n - effectiveK + i) - math.log(i);
  }
  return sum;
}

String _pValue(double value) {
  if (value.isNaN) return 'nan';
  if (value <= 0) return '0.000';
  if (value < 0.001) return '<0.001';
  if (value >= 1) return '1.000';
  return value.toStringAsFixed(3);
}

class ProfilePromotionDecision {
  const ProfilePromotionDecision({
    required this.policy,
    required this.status,
    required this.comparison,
    required this.failures,
    required this.warnings,
    this.evidencePlan,
  });

  final ProfilePromotionPolicy policy;
  final ProfilePromotionStatus status;
  final ProfilePairComparison? comparison;
  final List<String> failures;
  final List<String> warnings;
  final ProfilePromotionEvidencePlan? evidencePlan;

  bool get promote => status == ProfilePromotionStatus.promote;

  List<String> get messages => [...failures, ...warnings];
}

abstract final class EvalReporter {
  /// Canonical, non-secret payload used when binding promotion claims to a
  /// pre-registered policy digest.
  static Map<String, dynamic> promotionPolicyJson(
    ProfilePromotionPolicy policy,
  ) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'candidateProfileName': policy.candidateProfileName,
      'baselineProfileName': policy.baselineProfileName,
      'requireTuningReadiness': policy.requireTuningReadiness,
      'requireNoMissingJudgeVerdicts': policy.requireNoMissingJudgeVerdicts,
      'requireNoLevel1Regression': policy.requireNoLevel1Regression,
      'minPairedScenarioCount': policy.minPairedScenarioCount,
      'minJudgePairedScenarioCount': policy.minJudgePairedScenarioCount,
      'minJudgeDiscordantScenarioCount': policy.minJudgeDiscordantScenarioCount,
      'minJudgePassDelta': policy.minJudgePassDelta,
      'minJudgePassDeltaLowerBound': policy.minJudgePassDeltaLowerBound,
      'minLevel1PassDelta': policy.minLevel1PassDelta,
      'minLevel1PassDeltaLowerBound': policy.minLevel1PassDeltaLowerBound,
      'minMeanGoalAttainmentDelta': policy.minMeanGoalAttainmentDelta,
      'minMeanQualityDelta': policy.minMeanQualityDelta,
      'minMeanEfficiencyDelta': policy.minMeanEfficiencyDelta,
      'maxTotalTokenRatio': policy.maxTotalTokenRatio,
      'maxEstimatedCostRatio': policy.maxEstimatedCostRatio,
      'maxJudgePairedSignTestPValue': policy.maxJudgePairedSignTestPValue,
    };
  }

  /// One [ProfileSummary] per distinct profile, sorted by profile name.
  static List<ProfileSummary> summarize(List<EvalTrace> traces) {
    final byProfile = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      byProfile.putIfAbsent(trace.profile.name, () => <EvalTrace>[]).add(trace);
    }
    final summaries = <ProfileSummary>[];
    for (final entry in byProfile.entries) {
      final group = entry.value;
      final judged = group
          .where((t) => t.verdict != null)
          .toList(growable: false);
      final scenarioGroups = _byScenario(group);
      final completeScenarioCount = scenarioGroups.values
          .where(_complete)
          .length;
      summaries.add(
        ProfileSummary(
          profileName: entry.key,
          scenarioCount: scenarioGroups.length,
          completeScenarioCount: completeScenarioCount,
          traceCount: group.length,
          level1PassCount: group.where((t) => t.level1Passed).length,
          level1ReliableScenarioCount: scenarioGroups.values.where((trials) {
            return _complete(trials) && trials.every((t) => t.level1Passed);
          }).length,
          meanTotalTokens: _mean(
            group.map((t) => t.output.usage.totalTokens.toDouble()),
          ),
          judgedCount: judged.length,
          judgePassCount: judged.where((t) => t.verdict!.pass).length,
          judgeReliableScenarioCount: scenarioGroups.values.where((trials) {
            return _complete(trials) &&
                trials.every((t) => t.verdict?.pass ?? false);
          }).length,
          meanGoalAttainment: _mean(
            judged.map((t) => t.verdict!.goalAttainment.toDouble()),
          ),
          meanQuality: _mean(judged.map((t) => t.verdict!.quality.toDouble())),
          meanEfficiency: _mean(
            judged.map((t) => t.verdict!.efficiency.toDouble()),
          ),
        ),
      );
    }
    summaries.sort((a, b) => a.profileName.compareTo(b.profileName));
    return summaries;
  }

  /// Request fingerprint stability grouped by scenario/profile/provider turn.
  static List<ProviderRequestStabilitySummary>
  summarizeProviderRequestStability(List<EvalTrace> traces) {
    final byKey = <String, _ProviderRequestStabilityBucket>{};
    for (final trace in traces) {
      for (final request in trace.output.providerRequests) {
        final endpointKey =
            request.providerEndpointOrigin ??
            request.providerBaseUrlDigest ??
            'unknown';
        final key = [
          trace.scenario.id,
          trace.profile.name,
          request.providerType,
          request.providerModelId,
          endpointKey,
          request.invocationIndex,
          request.requestIndex,
          request.turnIndex,
        ].join('\n');
        byKey
            .putIfAbsent(
              key,
              () => _ProviderRequestStabilityBucket(
                scenarioId: trace.scenario.id,
                profileName: trace.profile.name,
                providerType: request.providerType,
                providerModelId: request.providerModelId,
                endpointKey: endpointKey,
                invocationIndex: request.invocationIndex,
                requestIndex: request.requestIndex,
                turnIndex: request.turnIndex,
                expectedTrialCount: trace.profile.trialCount,
              ),
            )
            .add(trace, request);
      }
    }

    final summaries = [
      for (final bucket in byKey.values) bucket.toSummary(),
    ]..sort(_compareProviderRequestStability);
    return summaries;
  }

  /// Aggregate provider usage coverage grouped by scenario/profile.
  static List<ProviderUsageCacheSummary> summarizeProviderUsageCache(
    List<EvalTrace> traces,
  ) {
    final byKey = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      if (trace.output.providerRequests.isEmpty) continue;
      byKey
          .putIfAbsent(
            _scenarioProfileKey(trace.scenario.id, trace.profile.name),
            () => <EvalTrace>[],
          )
          .add(trace);
    }

    final summaries = <ProviderUsageCacheSummary>[];
    for (final entry in byKey.entries) {
      final group = entry.value;
      final first = group.first;
      var inputTokenTraceCount = 0;
      var cachedInputTokenTraceCount = 0;
      var fullyReportedTraceCount = 0;
      var reportedInputTokens = 0;
      var reportedCachedInputTokens = 0;
      for (final trace in group) {
        final inputTokens = trace.output.usage.inputTokens;
        final cachedInputTokens = trace.output.usage.cachedInputTokens;
        if (inputTokens != null) {
          inputTokenTraceCount++;
        }
        if (cachedInputTokens != null) {
          cachedInputTokenTraceCount++;
        }
        if (inputTokens != null && cachedInputTokens != null) {
          fullyReportedTraceCount++;
          reportedInputTokens += inputTokens;
          reportedCachedInputTokens += cachedInputTokens;
        }
      }
      summaries.add(
        ProviderUsageCacheSummary(
          scenarioId: first.scenario.id,
          profileName: first.profile.name,
          expectedTrialCount: first.profile.trialCount,
          traceCount: group.length,
          inputTokenTraceCount: inputTokenTraceCount,
          cachedInputTokenTraceCount: cachedInputTokenTraceCount,
          fullyReportedTraceCount: fullyReportedTraceCount,
          reportedInputTokens: reportedInputTokens,
          reportedCachedInputTokens: reportedCachedInputTokens,
        ),
      );
    }
    summaries.sort((a, b) {
      final profileOrder = a.profileName.compareTo(b.profileName);
      if (profileOrder != 0) return profileOrder;
      return a.scenarioId.compareTo(b.scenarioId);
    });
    return summaries;
  }

  /// A human-readable summary table.
  static String render(
    List<EvalTrace> traces, {
    EvalReportContext? context,
  }) {
    final summaries = summarize(traces);
    final sliceSummaries = summarizeBySlice(traces, context: context);
    if (summaries.isEmpty && sliceSummaries.isEmpty) {
      return 'No traces to report.';
    }
    final buffer = StringBuffer()
      ..writeln('Eval summary (${traces.length} traces)')
      ..writeln(
        'profile           L1 pass   L1 pass^k  scn  complete  traces  '
        'mean tok   judged  judged%  judge pass  judge pass^k  '
        'goal / qual / eff',
      )
      ..writeln(
        '----------------  --------  ---------  ---  --------  ------  '
        '---------  ------  -------  ----------  ------------  '
        '-----------------',
      );
    for (final s in summaries) {
      buffer.writeln(
        '${s.profileName.padRight(16)}  '
        '${_pct(s.level1PassRate).padLeft(8)}  '
        '${_pct(s.level1ReliableScenarioRate).padLeft(9)}  '
        '${s.scenarioCount.toString().padLeft(3)}  '
        '${s.completeScenarioCount.toString().padLeft(8)}  '
        '${s.traceCount.toString().padLeft(6)}  '
        '${s.meanTotalTokens.round().toString().padLeft(9)}  '
        '${s.judgedCount.toString().padLeft(6)}  '
        '${_pct(s.traceCount == 0 ? 0 : s.judgedCount / s.traceCount).padLeft(7)}  '
        '${_pct(s.judgePassRate).padLeft(10)}   '
        '${_pct(s.judgeReliableScenarioRate).padLeft(11)}  '
        '${_one(s.meanGoalAttainment)} / ${_one(s.meanQuality)} / '
        '${_one(s.meanEfficiency)}',
      );
    }
    final requestSummaries = summarizeProviderRequestStability(traces);
    if (requestSummaries.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Provider request fingerprints')
        ..writeln(
          'profile           scenario                           provider  '
          'model             turn  req  traces  calls  msg dig  tool dig  '
          'msgs  tools  thoughts  stable',
        )
        ..writeln(
          '----------------  ---------------------------------  --------  '
          '----------------  ----  ---  ------  -----  -------  --------  '
          '----  -----  --------  ------',
        );
      for (final s in requestSummaries) {
        buffer.writeln(
          '${_clip(s.profileName, 16).padRight(16)}  '
          '${_clip(s.scenarioId, 33).padRight(33)}  '
          '${_clip(s.providerType, 8).padRight(8)}  '
          '${_clip(s.providerModelId, 16).padRight(16)}  '
          '${s.turnIndex.toString().padLeft(4)}  '
          '${s.requestIndex.toString().padLeft(3)}  '
          '${'${s.traceCount}/${s.expectedTrialCount}'.padLeft(6)}  '
          '${s.requestCount.toString().padLeft(5)}  '
          '${s.uniqueMessageDigestCount.toString().padLeft(7)}  '
          '${s.uniqueToolSchemaDigestCount.toString().padLeft(8)}  '
          '${_formatIntSet(s.messageCounts).padLeft(4)}  '
          '${_formatIntSet(s.toolCounts).padLeft(5)}  '
          '${_formatIntSet(s.thoughtSignatureCounts).padLeft(8)}  '
          '${s.requestShapeStable ? 'yes' : 'no'}',
        );
      }
      final tracesWithoutProviderRequests = traces
          .where((trace) => trace.output.providerRequests.isEmpty)
          .length;
      if (tracesWithoutProviderRequests > 0) {
        buffer.writeln(
          'traces without provider request evidence: '
          '$tracesWithoutProviderRequests',
        );
      }
    }
    final usageSummaries = summarizeProviderUsageCache(traces);
    if (usageSummaries.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Provider usage cache coverage')
        ..writeln(
          'profile           scenario                           traces  '
          'input  cached  full  cache tokens       cache%',
        )
        ..writeln(
          '----------------  ---------------------------------  ------  '
          '-----  ------  ----  -----------------  ------',
        );
      for (final s in usageSummaries) {
        final cacheRate = s.reportedCacheRate;
        final tokenText = s.fullyReportedTraceCount == 0
            ? 'unreported'
            : '${s.reportedCachedInputTokens}/${s.reportedInputTokens}';
        buffer.writeln(
          '${_clip(s.profileName, 16).padRight(16)}  '
          '${_clip(s.scenarioId, 33).padRight(33)}  '
          '${'${s.traceCount}/${s.expectedTrialCount}'.padLeft(6)}  '
          '${'${s.inputTokenTraceCount}/${s.traceCount}'.padLeft(5)}  '
          '${'${s.cachedInputTokenTraceCount}/${s.traceCount}'.padLeft(6)}  '
          '${'${s.fullyReportedTraceCount}/${s.traceCount}'.padLeft(4)}  '
          '${tokenText.padLeft(17)}  '
          '${cacheRate == null ? 'n/a' : _pct(cacheRate).padLeft(6)}',
        );
      }
    }
    final capabilitySummaries = summarizeByCapability(traces);
    if (capabilitySummaries.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Capability summary')
        ..writeln(
          'profile           capability                         L1 pass   '
          'L1 pass^k  scn  complete  traces  judged  coverage  judged%  '
          'judge pass  judge pass^k  mean tok',
        )
        ..writeln(
          '----------------  ---------------------------------  --------  '
          '---------  ---  --------  ------  ------  --------  -------  '
          '----------  ------------  --------',
        );
      for (final s in capabilitySummaries) {
        buffer.writeln(
          '${s.profileName.padRight(16)}  '
          '${_clip(s.capabilityId, 33).padRight(33)}  '
          '${_pct(s.level1PassRate).padLeft(8)}  '
          '${_pct(s.level1ReliableScenarioRate).padLeft(9)}  '
          '${s.scenarioCount.toString().padLeft(3)}  '
          '${s.completeScenarioCount.toString().padLeft(8)}  '
          '${s.traceCount.toString().padLeft(6)}  '
          '${s.judgedCount.toString().padLeft(6)}  '
          '${_pct(s.coverageRate).padLeft(8)}  '
          '${_pct(s.judgedTraceRate).padLeft(7)}  '
          '${_pct(s.judgePassRate).padLeft(10)}  '
          '${_pct(s.judgeReliableScenarioRate).padLeft(12)}  '
          '${s.meanTotalTokens.round().toString().padLeft(8)}',
        );
      }
    }
    if (sliceSummaries.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(
          'Split / model-class / capability summary '
          '(${context == null ? 'observed matrix' : 'expected matrix'})',
        )
        ..writeln(
          'split        model class        capability                         '
          'prof  scn  cells  complete  traces  judged  coverage',
        )
        ..writeln(
          '-----------  -----------------  ---------------------------------  '
          '----  ---  -----  --------  ------  ------  --------',
        );
      for (final s in sliceSummaries) {
        buffer.writeln(
          '${s.split.name.padRight(11)}  '
          '${s.modelClass.name.padRight(17)}  '
          '${_clip(s.capabilityId, 33).padRight(33)}  '
          '${s.profileCount.toString().padLeft(4)}  '
          '${s.scenarioCount.toString().padLeft(3)}  '
          '${s.scenarioProfileCount.toString().padLeft(5)}  '
          '${s.completeScenarioProfileCount.toString().padLeft(8)}  '
          '${s.traceCount.toString().padLeft(6)}  '
          '${s.judgedTraceCount.toString().padLeft(6)}  '
          '${_pct(s.coverageRate).padLeft(8)}',
        );
      }
    }
    final pairComparisons = compareProfiles(traces);
    if (pairComparisons.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Paired profile comparison')
        ..writeln(
          'left profile      right profile     paired  left-only  right-only  '
          'incomp  L1 delta  judge n  miss judge  judge delta  '
          'judge wins  sign p  goal / qual / eff delta  tok ratio  cost ratio  note',
        )
        ..writeln(
          '----------------  ----------------  ------  ---------  ----------  '
          '------  --------  -------  ----------  -----------  '
          '----------  ------  -----------------------  ---------  ----------  --------------',
        );
      for (final comparison in pairComparisons) {
        buffer.writeln(
          '${_clip(comparison.leftProfileName, 16).padRight(16)}  '
          '${_clip(comparison.rightProfileName, 16).padRight(16)}  '
          '${comparison.pairedScenarioCount.toString().padLeft(6)}  '
          '${comparison.leftOnlyScenarioCount.toString().padLeft(9)}  '
          '${comparison.rightOnlyScenarioCount.toString().padLeft(10)}  '
          '${comparison.incompleteScenarioCount.toString().padLeft(6)}  '
          '${_signedPct(comparison.level1PassDelta).padLeft(8)}  '
          '${comparison.judgePairedScenarioCount.toString().padLeft(7)}  '
          '${comparison.judgeMissingScenarioCount.toString().padLeft(10)}  '
          '${_signedPct(comparison.judgePassDelta).padLeft(11)}  '
          '${'${comparison.judgeLeftOnlyPassCount}/${comparison.judgeRightOnlyPassCount}'.padLeft(10)}  '
          '${_pValue(comparison.judgePairedSignTestPValue).padLeft(6)}  '
          '${_signedOne(comparison.meanGoalAttainmentDelta)} / '
          '${_signedOne(comparison.meanQualityDelta)} / '
          '${_signedOne(comparison.meanEfficiencyDelta)}  '
          '${_ratio(comparison.totalTokenRatio).padLeft(9)}  '
          '${_ratio(comparison.estimatedCostRatio).padLeft(10)}  '
          '${_comparisonNote(comparison)}',
        );
      }
    }
    return buffer.toString();
  }

  static ProfilePromotionDecision evaluateProfilePromotion({
    required List<EvalTrace> traces,
    required ProfilePromotionPolicy policy,
    EvalTuningReadinessReport? readinessReport,
  }) {
    final blocked = <String>[];
    final rejected = <String>[];
    final inconclusive = <String>[];
    final warnings = <String>[];
    if (policy.requireTuningReadiness) {
      if (readinessReport == null) {
        blocked.add('promotion blocked: tuning-readiness report is required');
      } else if (!readinessReport.ready) {
        blocked.add(
          'promotion blocked: tuning readiness is not ready',
        );
      }
    } else if (readinessReport != null && !readinessReport.ready) {
      warnings.add(
        'tuning-readiness report is ${readinessReport.evidenceLabel}',
      );
    }

    final byProfile = _byProfile(traces);
    final candidateScenarios = byProfile[policy.candidateProfileName];
    final baselineScenarios = byProfile[policy.baselineProfileName];
    if (candidateScenarios == null) {
      blocked.add(
        'promotion blocked: missing candidate profile '
        '${policy.candidateProfileName}',
      );
    }
    if (baselineScenarios == null) {
      blocked.add(
        'promotion blocked: missing baseline profile '
        '${policy.baselineProfileName}',
      );
    }
    if (candidateScenarios == null || baselineScenarios == null) {
      return ProfilePromotionDecision(
        policy: policy,
        status: ProfilePromotionStatus.blocked,
        comparison: null,
        failures: List.unmodifiable(blocked),
        warnings: List.unmodifiable(warnings),
      );
    }

    final comparison = _compareProfilePair(
      leftProfileName: policy.candidateProfileName,
      rightProfileName: policy.baselineProfileName,
      leftScenarios: _byScenario(candidateScenarios),
      rightScenarios: _byScenario(baselineScenarios),
    );
    if (comparison.pairedScenarioCount < policy.minPairedScenarioCount) {
      blocked.add(
        'promotion blocked: paired scenario count '
        '${comparison.pairedScenarioCount} < '
        '${policy.minPairedScenarioCount}',
      );
    }
    if (comparison.leftOnlyScenarioCount > 0) {
      blocked.add(
        'promotion blocked: candidate-only scenarios '
        '${comparison.leftOnlyScenarioCount} > 0',
      );
    }
    if (comparison.rightOnlyScenarioCount > 0) {
      blocked.add(
        'promotion blocked: baseline-only scenarios '
        '${comparison.rightOnlyScenarioCount} > 0',
      );
    }
    if (comparison.judgePairedScenarioCount <
        policy.minJudgePairedScenarioCount) {
      blocked.add(
        'promotion blocked: paired judge scenario count '
        '${comparison.judgePairedScenarioCount} < '
        '${policy.minJudgePairedScenarioCount}',
      );
    }
    if (policy.requireNoMissingJudgeVerdicts &&
        comparison.judgeMissingScenarioCount > 0) {
      blocked.add(
        'promotion blocked: paired scenarios with missing judge verdicts '
        '${comparison.judgeMissingScenarioCount} > 0',
      );
    }
    if (comparison.estimatedCostMissingScenarioCount > 0) {
      blocked.add(
        'promotion blocked: paired scenarios with missing token/cost evidence '
        '${comparison.estimatedCostMissingScenarioCount} > 0',
      );
    }
    if (comparison.incompleteScenarioCount > 0) {
      blocked.add(
        'promotion blocked: incomplete trial sets for '
        '${comparison.incompleteScenarioCount} shared scenarios',
      );
    }
    if (comparison.judgePassDelta < policy.minJudgePassDelta) {
      inconclusive.add(
        'promotion inconclusive: judge pass delta '
        '${_signedPct(comparison.judgePassDelta)} < '
        '${_signedPct(policy.minJudgePassDelta)}',
      );
    }
    if (comparison.judgePassDeltaLowerBound <
        policy.minJudgePassDeltaLowerBound) {
      inconclusive.add(
        'promotion inconclusive: judge pass delta lower bound '
        '${_signedPct(comparison.judgePassDeltaLowerBound)} < '
        '${_signedPct(policy.minJudgePassDeltaLowerBound)}',
      );
    }
    final canUsePairedJudgeWinEvidence =
        comparison.judgePairedScenarioCount > 0 &&
        comparison.incompleteScenarioCount == 0;
    if (canUsePairedJudgeWinEvidence) {
      if (comparison.judgeDiscordantScenarioCount == 0) {
        inconclusive.add(
          'promotion inconclusive: no discordant paired judge outcomes; '
          'candidate and baseline have the same pass/fail outcomes',
        );
      } else {
        if (comparison.judgeDiscordantScenarioCount <
            policy.minJudgeDiscordantScenarioCount) {
          inconclusive.add(
            'promotion inconclusive: paired judge discordant scenario count '
            '${comparison.judgeDiscordantScenarioCount} < '
            '${policy.minJudgeDiscordantScenarioCount}',
          );
        }
        if (comparison.judgePairedSignTestPValue >
            policy.maxJudgePairedSignTestPValue) {
          inconclusive.add(
            'promotion inconclusive: paired judge one-sided sign-test p-value '
            '${_pValue(comparison.judgePairedSignTestPValue)} > '
            '${_pValue(policy.maxJudgePairedSignTestPValue)} '
            '(candidateWins ${comparison.judgeLeftOnlyPassCount}, '
            'baselineWins ${comparison.judgeRightOnlyPassCount}, '
            'discordant ${comparison.judgeDiscordantScenarioCount})',
          );
        }
      }
    }
    if (policy.requireNoLevel1Regression &&
        comparison.level1PassDelta < policy.minLevel1PassDelta) {
      rejected.add(
        'promotion rejected: Level 1 pass delta '
        '${_signedPct(comparison.level1PassDelta)} < '
        '${_signedPct(policy.minLevel1PassDelta)}',
      );
    }
    if (comparison.level1PassDeltaLowerBound <
        policy.minLevel1PassDeltaLowerBound) {
      inconclusive.add(
        'promotion inconclusive: Level 1 pass delta lower bound '
        '${_signedPct(comparison.level1PassDeltaLowerBound)} < '
        '${_signedPct(policy.minLevel1PassDeltaLowerBound)}',
      );
    }
    if (comparison.meanGoalAttainmentDelta <
        policy.minMeanGoalAttainmentDelta) {
      rejected.add(
        'promotion rejected: mean goal-attainment delta '
        '${_signedOne(comparison.meanGoalAttainmentDelta)} < '
        '${_signedOne(policy.minMeanGoalAttainmentDelta)}',
      );
    }
    if (comparison.meanQualityDelta < policy.minMeanQualityDelta) {
      rejected.add(
        'promotion rejected: mean quality delta '
        '${_signedOne(comparison.meanQualityDelta)} < '
        '${_signedOne(policy.minMeanQualityDelta)}',
      );
    }
    if (comparison.meanEfficiencyDelta < policy.minMeanEfficiencyDelta) {
      rejected.add(
        'promotion rejected: mean efficiency delta '
        '${_signedOne(comparison.meanEfficiencyDelta)} < '
        '${_signedOne(policy.minMeanEfficiencyDelta)}',
      );
    }
    final usesEstimatedCostGate = comparison.usesEstimatedCost;
    final efficiencyRatio = usesEstimatedCostGate
        ? comparison.estimatedCostRatio
        : comparison.totalTokenRatio;
    final maxEfficiencyRatio = usesEstimatedCostGate
        ? policy.maxEstimatedCostRatio
        : policy.maxTotalTokenRatio;
    if (efficiencyRatio > maxEfficiencyRatio) {
      final label = usesEstimatedCostGate ? 'estimated cost' : 'token';
      rejected.add(
        'promotion rejected: mean $label regression '
        '${_signedPct(efficiencyRatio - 1)} > '
        '${_signedPct(maxEfficiencyRatio - 1)} '
        '(ratio ${_ratio(efficiencyRatio)} > '
        '${_ratio(maxEfficiencyRatio)})',
      );
    }
    final failures = [
      ...blocked,
      ...rejected,
      ...inconclusive,
    ];
    final status = switch ((
      blocked.isNotEmpty,
      rejected.isNotEmpty,
      inconclusive.isNotEmpty,
    )) {
      (true, _, _) => ProfilePromotionStatus.blocked,
      (false, true, _) => ProfilePromotionStatus.reject,
      (false, false, true) => ProfilePromotionStatus.inconclusive,
      (false, false, false) => ProfilePromotionStatus.promote,
    };
    return ProfilePromotionDecision(
      policy: policy,
      status: status,
      comparison: comparison,
      failures: List.unmodifiable(failures),
      warnings: List.unmodifiable(warnings),
      evidencePlan: _planPromotionEvidence(
        comparison: comparison,
        policy: policy,
        hasHardRejection: rejected.isNotEmpty,
      ),
    );
  }

  static ProfilePromotionEvidencePlan _planPromotionEvidence({
    required ProfilePairComparison comparison,
    required ProfilePromotionPolicy policy,
    required bool hasHardRejection,
  }) {
    final blockers = <String>[];
    final additionalPairedScenariosForMinCount = _maxInt(
      0,
      policy.minPairedScenarioCount - comparison.pairedScenarioCount,
    );
    final additionalJudgeScenariosForMinCount = _maxInt(
      0,
      policy.minJudgePairedScenarioCount - comparison.judgePairedScenarioCount,
    );

    int? additionalJudgeScenariosForLowerBound;
    int? additionalJudgeScenariosForPairedSignTest;
    int? projectedJudgePairedScenarioCount;
    double? projectedJudgePassDeltaLowerBound;
    double? projectedJudgePairedSignTestPValue;
    if (hasHardRejection) {
      blockers.add(
        'Level 1, quality, efficiency, or token/cost rejection remains; more '
        'samples alone cannot promote this candidate',
      );
    }
    if (comparison.judgePairedScenarioCount == 0) {
      blockers.add('no paired judge outcomes are available');
    } else if (comparison.judgeMissingScenarioCount > 0) {
      blockers.add(
        'paired judge verdicts are missing; complete verdicts before using '
        'lower-bound sample estimates',
      );
    } else if (comparison.incompleteScenarioCount > 0) {
      blockers.add(
        'shared scenarios have incomplete trial sets; complete the matrix '
        'before using lower-bound sample estimates',
      );
    } else if (hasHardRejection) {
      // Count gaps are still reported, but pass/fail sample planning would
      // distract from hard quality/cost gates that more samples cannot fix.
    } else if (comparison.judgePassDelta <= 0) {
      blockers.add(
        'observed judge pass delta is not positive '
        '(${_signedPct(comparison.judgePassDelta)})',
      );
    } else if (comparison.judgePassDelta < policy.minJudgePassDelta) {
      blockers.add(
        'observed judge pass delta ${_signedPct(comparison.judgePassDelta)} '
        'is below required ${_signedPct(policy.minJudgePassDelta)}',
      );
    } else if (comparison.judgePassDelta <=
        policy.minJudgePassDeltaLowerBound) {
      blockers.add(
        'observed judge pass delta ${_signedPct(comparison.judgePassDelta)} '
        'does not exceed lower-bound target '
        '${_signedPct(policy.minJudgePassDeltaLowerBound)}',
      );
    } else {
      final candidateRate = comparison.judgeLeftPassRate;
      final baselineRate = comparison.judgeRightPassRate;
      final candidateOnlyRate =
          comparison.judgeLeftOnlyPassCount /
          comparison.judgePairedScenarioCount;
      final baselineOnlyRate =
          comparison.judgeRightOnlyPassCount /
          comparison.judgePairedScenarioCount;
      final minProjectedPairs = _maxInt(
        comparison.judgePairedScenarioCount,
        policy.minJudgePairedScenarioCount,
      );
      for (
        var pairs = minProjectedPairs;
        pairs <= _maxPromotionPlanningPairedScenarios;
        pairs++
      ) {
        final candidatePasses = (candidateRate * pairs).floor();
        final baselinePasses = (baselineRate * pairs).ceil();
        final lowerBound =
            RateEstimate.wilson(
              successes: candidatePasses,
              total: pairs,
            ).lowerBound -
            RateEstimate.wilson(
              successes: baselinePasses,
              total: pairs,
            ).upperBound;
        if (lowerBound >= policy.minJudgePassDeltaLowerBound) {
          additionalJudgeScenariosForLowerBound =
              pairs - comparison.judgePairedScenarioCount;
          projectedJudgePairedScenarioCount = pairs;
          projectedJudgePassDeltaLowerBound = lowerBound;
          break;
        }
      }
      for (
        var pairs = minProjectedPairs;
        pairs <= _maxPromotionPlanningPairedScenarios;
        pairs++
      ) {
        final candidateOnlyWins = (candidateOnlyRate * pairs).floor();
        final baselineOnlyWins = (baselineOnlyRate * pairs).ceil();
        final signTestPValue = _oneSidedSignTestPValue(
          successes: candidateOnlyWins,
          total: candidateOnlyWins + baselineOnlyWins,
        );
        if (candidateOnlyWins + baselineOnlyWins >=
                policy.minJudgeDiscordantScenarioCount &&
            signTestPValue <= policy.maxJudgePairedSignTestPValue) {
          additionalJudgeScenariosForPairedSignTest =
              pairs - comparison.judgePairedScenarioCount;
          projectedJudgePairedSignTestPValue = signTestPValue;
          break;
        }
      }
      if (additionalJudgeScenariosForLowerBound == null) {
        blockers.add(
          'lower-bound target is not reached by '
          '$_maxPromotionPlanningPairedScenarios judged pairs under observed '
          'pass rates',
        );
      }
      if (additionalJudgeScenariosForPairedSignTest == null) {
        blockers.add(
          'paired discordant-count/sign-test target is not reached by '
          '$_maxPromotionPlanningPairedScenarios judged pairs under observed '
          'candidate-only/baseline-only win rates',
        );
      }
    }

    return ProfilePromotionEvidencePlan(
      currentPairedScenarioCount: comparison.pairedScenarioCount,
      currentJudgePairedScenarioCount: comparison.judgePairedScenarioCount,
      additionalPairedScenariosForMinCount:
          additionalPairedScenariosForMinCount,
      additionalJudgeScenariosForMinCount: additionalJudgeScenariosForMinCount,
      additionalJudgeScenariosForLowerBound:
          additionalJudgeScenariosForLowerBound,
      additionalJudgeScenariosForPairedSignTest:
          additionalJudgeScenariosForPairedSignTest,
      projectedJudgePairedScenarioCount: projectedJudgePairedScenarioCount,
      projectedJudgePassDeltaLowerBound: projectedJudgePassDeltaLowerBound,
      projectedJudgePairedSignTestPValue: projectedJudgePairedSignTestPValue,
      assumedCandidateJudgePassRate: comparison.judgeLeftPassRate,
      assumedBaselineJudgePassRate: comparison.judgeRightPassRate,
      blockers: List.unmodifiable(blockers),
    );
  }

  static String renderProfilePromotion(ProfilePromotionDecision decision) {
    final buffer = StringBuffer()
      ..writeln(
        'Profile promotion: '
        '${decision.policy.candidateProfileName} vs '
        '${decision.policy.baselineProfileName}: ${decision.status.name}',
      )
      ..writeln(
        'policy: requireReady=${decision.policy.requireTuningReadiness} '
        'minPaired=${decision.policy.minPairedScenarioCount} '
        'minJudgePaired=${decision.policy.minJudgePairedScenarioCount} '
        'minJudgeDiscordant='
        '${decision.policy.minJudgeDiscordantScenarioCount} '
        'minJudgeDelta=${_signedPct(decision.policy.minJudgePassDelta)} '
        'minJudgeDeltaLower='
        '${_signedPct(decision.policy.minJudgePassDeltaLowerBound)} '
        'maxJudgeSignP='
        '${_pValue(decision.policy.maxJudgePairedSignTestPValue)} '
        'minLevel1Delta=${_signedPct(decision.policy.minLevel1PassDelta)} '
        'minLevel1DeltaLower='
        '${_signedPct(decision.policy.minLevel1PassDeltaLowerBound)} '
        'minGoalDelta=${_signedOne(decision.policy.minMeanGoalAttainmentDelta)} '
        'minQualityDelta=${_signedOne(decision.policy.minMeanQualityDelta)} '
        'minEfficiencyDelta=${_signedOne(decision.policy.minMeanEfficiencyDelta)} '
        'maxTokenRatio=${_ratio(decision.policy.maxTotalTokenRatio)} '
        'maxCostRatio=${_ratio(decision.policy.maxEstimatedCostRatio)}',
      );
    final comparison = decision.comparison;
    if (comparison != null) {
      buffer.writeln(
        'paired=${comparison.pairedScenarioCount} '
        'leftOnly=${comparison.leftOnlyScenarioCount} '
        'rightOnly=${comparison.rightOnlyScenarioCount} '
        'incomplete=${comparison.incompleteScenarioCount} '
        'judgePaired=${comparison.judgePairedScenarioCount} '
        'judgeMissing=${comparison.judgeMissingScenarioCount} '
        'judgeDelta=${_signedPct(comparison.judgePassDelta)} '
        'judgeDeltaLower='
        '${_signedPct(comparison.judgePassDeltaLowerBound)} '
        'candidateWins=${comparison.judgeLeftOnlyPassCount} '
        'baselineWins=${comparison.judgeRightOnlyPassCount} '
        'discordant=${comparison.judgeDiscordantScenarioCount} '
        'candidateSignP=${_pValue(comparison.judgePairedSignTestPValue)} '
        'level1DeltaLower='
        '${_signedPct(comparison.level1PassDeltaLowerBound)} '
        'qualityDelta=${_signedOne(comparison.meanQualityDelta)} '
        'efficiencyDelta=${_signedOne(comparison.meanEfficiencyDelta)} '
        'tokenRatio=${_ratio(comparison.totalTokenRatio)} '
        'costRatio=${_ratio(comparison.estimatedCostRatio)} '
        'costMode=${comparison.usesEstimatedCost ? 'weighted' : 'token'} '
        'costEvidence=${comparison.estimatedCostScenarioCount}/'
        '${comparison.pairedScenarioCount} '
        'missingCost=${comparison.estimatedCostMissingScenarioCount} '
        'costProfiles=${comparison.leftUsesWeightedTokenCosts ? 'weighted' : 'default'}/'
        '${comparison.rightUsesWeightedTokenCosts ? 'weighted' : 'default'}',
      );
    }
    final evidencePlan = decision.evidencePlan;
    if (evidencePlan != null) {
      buffer
        ..writeln('Promotion evidence plan (planning only):')
        ..writeln(
          '- paired count gap: '
          '${evidencePlan.additionalPairedScenariosForMinCount} '
          '(current ${evidencePlan.currentPairedScenarioCount}, '
          'min ${decision.policy.minPairedScenarioCount})',
        )
        ..writeln(
          '- judged paired count gap: '
          '${evidencePlan.additionalJudgeScenariosForMinCount} '
          '(current ${evidencePlan.currentJudgePairedScenarioCount}, '
          'min ${decision.policy.minJudgePairedScenarioCount})',
        )
        ..writeln(
          '- assumed future judge pass rates: candidate='
          '${_pct(evidencePlan.assumedCandidateJudgePassRate)}, baseline='
          '${_pct(evidencePlan.assumedBaselineJudgePassRate)}',
        );
      final lowerBoundGap = evidencePlan.additionalJudgeScenariosForLowerBound;
      final signTestGap =
          evidencePlan.additionalJudgeScenariosForPairedSignTest;
      if (lowerBoundGap == null) {
        buffer.writeln('- lower-bound sample estimate unavailable');
      } else {
        buffer
          ..writeln(
            '- lower-bound sample gap: $lowerBoundGap '
            '(projected judged pairs '
            '${evidencePlan.projectedJudgePairedScenarioCount}, '
            'projected lower '
            '${_signedPct(evidencePlan.projectedJudgePassDeltaLowerBound!)})',
          )
          ..writeln(
            '- recommended additional judged pairs: '
            '${evidencePlan.recommendedAdditionalJudgeScenarios}',
          );
      }
      if (signTestGap == null) {
        buffer.writeln(
          '- paired discordant/sign-test sample estimate unavailable',
        );
      } else {
        buffer.writeln(
          '- paired discordant/sign-test sample gap: $signTestGap '
          '(projected p '
          '${_pValue(evidencePlan.projectedJudgePairedSignTestPValue!)})',
        );
      }
      if (evidencePlan.blockers.isNotEmpty) {
        for (final blocker in evidencePlan.blockers) {
          buffer.writeln('- planning caveat: $blocker');
        }
      }
    }
    if (decision.failures.isNotEmpty) {
      buffer.writeln('Failures:');
      for (final failure in decision.failures) {
        buffer.writeln('- $failure');
      }
    }
    if (decision.warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in decision.warnings) {
        buffer.writeln('- $warning');
      }
    }
    return buffer.toString();
  }

  /// Pairwise comparisons for every profile pair, sorted by profile name.
  static List<ProfilePairComparison> compareProfiles(List<EvalTrace> traces) {
    final byProfile = _byProfile(traces);
    final profileNames = byProfile.keys.toList()..sort();
    if (profileNames.length < 2) return const [];

    final scenariosByProfile = {
      for (final entry in byProfile.entries)
        entry.key: _byScenario(entry.value),
    };
    final comparisons = <ProfilePairComparison>[];
    for (var leftIndex = 0; leftIndex < profileNames.length; leftIndex++) {
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < profileNames.length;
        rightIndex++
      ) {
        comparisons.add(
          _compareProfilePair(
            leftProfileName: profileNames[leftIndex],
            rightProfileName: profileNames[rightIndex],
            leftScenarios: scenariosByProfile[profileNames[leftIndex]]!,
            rightScenarios: scenariosByProfile[profileNames[rightIndex]]!,
          ),
        );
      }
    }
    return comparisons;
  }

  /// One summary per profile/capability pair.
  static List<CapabilitySummary> summarizeByCapability(
    List<EvalTrace> traces,
  ) {
    final byKey = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      final capabilityId = trace.scenario.metadata.primaryCapabilityId;
      if (capabilityId == null) continue;
      byKey
          .putIfAbsent(
            '${trace.profile.name}\n$capabilityId',
            () => <EvalTrace>[],
          )
          .add(trace);
    }

    final summaries = <CapabilitySummary>[];
    for (final entry in byKey.entries) {
      final parts = entry.key.split('\n');
      final profileName = parts[0];
      final capabilityId = parts[1];
      final group = entry.value;
      final judged = group
          .where((trace) => trace.verdict != null)
          .toList(growable: false);
      final scenarioGroups = _byScenario(group);
      final profile = group.first.profile;
      summaries.add(
        CapabilitySummary(
          profileName: profileName,
          capabilityId: capabilityId,
          scenarioCount: scenarioGroups.length,
          completeScenarioCount: scenarioGroups.values.where(_complete).length,
          trialCount: scenarioGroups.length * profile.trialCount,
          traceCount: group.length,
          level1PassCount: group.where((trace) => trace.level1Passed).length,
          level1ReliableScenarioCount: scenarioGroups.values.where((trials) {
            return _complete(trials) &&
                trials.every((trace) => trace.level1Passed);
          }).length,
          judgedCount: judged.length,
          judgePassCount: judged.where((trace) => trace.verdict!.pass).length,
          judgeReliableScenarioCount: scenarioGroups.values.where((trials) {
            return _complete(trials) &&
                trials.every((trace) => trace.verdict?.pass ?? false);
          }).length,
          meanTotalTokens: _mean(
            group.map((trace) => trace.output.usage.totalTokens.toDouble()),
          ),
        ),
      );
    }
    summaries.sort((a, b) {
      final profileOrder = a.profileName.compareTo(b.profileName);
      if (profileOrder != 0) return profileOrder;
      return a.capabilityId.compareTo(b.capabilityId);
    });
    return summaries;
  }

  /// One summary per split/model-class/primary-capability tuple.
  static List<SliceSummary> summarizeBySlice(
    List<EvalTrace> traces, {
    EvalReportContext? context,
  }) {
    final byKey = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      final capabilityId = trace.scenario.metadata.primaryCapabilityId;
      if (capabilityId == null) continue;
      byKey
          .putIfAbsent(
            [
              trace.scenario.metadata.split.name,
              trace.profile.modelClass.name,
              capabilityId,
            ].join('\n'),
            () => <EvalTrace>[],
          )
          .add(trace);
    }

    final summaries = <SliceSummary>[];
    if (context != null) {
      _validateReportContext(context);
      final expectedMatrices = _expectedSliceMatrices(context);
      final keys = {...expectedMatrices.keys, ...byKey.keys}.toList()..sort();
      for (final key in keys) {
        final group = byKey[key] ?? const <EvalTrace>[];
        final expected = expectedMatrices[key];
        if (expected == null) {
          summaries.add(_observedSliceSummary(key: key, group: group));
        } else {
          summaries.add(
            _expectedSliceSummary(
              matrix: expected,
              group: group,
            ),
          );
        }
      }
      summaries.sort(_compareSliceSummaries);
      return summaries;
    }

    for (final entry in byKey.entries) {
      summaries.add(_observedSliceSummary(key: entry.key, group: entry.value));
    }
    summaries.sort(_compareSliceSummaries);
    return summaries;
  }

  static void _validateReportContext(EvalReportContext context) {
    final manifest = context.manifest;
    if (manifest == null) return;
    final manifestDigest = manifest.manifestDigest;
    if (manifestDigest == null) {
      throw StateError(
        'Eval report context manifest is missing manifestDigest',
      );
    }
    final actualManifestDigest = EvalProvenance.manifestDigest(manifest);
    if (manifestDigest != actualManifestDigest) {
      throw StateError(
        'Eval report context manifestDigest is $manifestDigest, '
        'expected $actualManifestDigest',
      );
    }
    final scenarioSetDigest = EvalProvenance.scenarioSetDigest(
      context.scenarios,
    );
    if (scenarioSetDigest != manifest.scenarioSetDigest) {
      throw StateError(
        'Eval report context scenarioSetDigest is $scenarioSetDigest, '
        'expected manifest ${manifest.scenarioSetDigest}',
      );
    }
    final profileSetDigest = EvalProvenance.profileSetDigest(context.profiles);
    if (profileSetDigest != manifest.profileSetDigest) {
      throw StateError(
        'Eval report context profileSetDigest is $profileSetDigest, '
        'expected manifest ${manifest.profileSetDigest}',
      );
    }
  }

  static Map<String, _ExpectedSliceMatrix> _expectedSliceMatrices(
    EvalReportContext context,
  ) {
    final matrices = <String, _ExpectedSliceMatrix>{};
    for (final scenario in context.scenarios) {
      final capabilityId = scenario.metadata.primaryCapabilityId;
      if (capabilityId == null) continue;
      for (final profile in context.profiles) {
        final key = _sliceKey(
          split: scenario.metadata.split,
          modelClass: profile.modelClass,
          capabilityId: capabilityId,
        );
        final matrix = matrices.putIfAbsent(
          key,
          () => _ExpectedSliceMatrix(
            split: scenario.metadata.split,
            modelClass: profile.modelClass,
            capabilityId: capabilityId,
          ),
        );
        matrix.scenarios[scenario.id] = scenario;
        matrix.profiles[profile.name] = profile;
      }
    }
    return matrices;
  }

  static SliceSummary _observedSliceSummary({
    required String key,
    required List<EvalTrace> group,
  }) {
    final parts = key.split('\n');
    final byScenario = _byScenario(group);
    final byProfile = _byProfile(group);
    final byScenarioProfile = _byScenarioProfile(group);
    final judged = group
        .where((trace) => trace.verdict != null)
        .toList(growable: false);
    final profiles = [
      for (final profileTraces in byProfile.values) profileTraces.first.profile,
    ];
    final scenarioProfileCount = byScenario.length * profiles.length;
    final trialCount =
        byScenario.length *
        profiles.fold<int>(
          0,
          (sum, profile) => sum + profile.trialCount,
        );

    return SliceSummary(
      split: EvalScenarioSplit.fromName(parts[0]),
      modelClass: EvalModelClass.fromName(parts[1]),
      capabilityId: parts[2],
      profileCount: byProfile.length,
      scenarioCount: byScenario.length,
      scenarioProfileCount: scenarioProfileCount,
      completeScenarioCount: byScenario.values.where((scenarioTraces) {
        final scenarioProfiles = _byProfile(scenarioTraces);
        return profiles.isNotEmpty &&
            scenarioProfiles.length == profiles.length &&
            scenarioProfiles.values.every(_complete);
      }).length,
      completeScenarioProfileCount: byScenarioProfile.values
          .where(_complete)
          .length,
      trialCount: trialCount,
      traceCount: group.length,
      level1PassCount: group.where((trace) => trace.level1Passed).length,
      level1ReliableScenarioProfileCount: byScenarioProfile.values.where((
        traces,
      ) {
        return _complete(traces) && traces.every((trace) => trace.level1Passed);
      }).length,
      judgedTraceCount: judged.length,
      judgePassCount: judged.where((trace) => trace.verdict!.pass).length,
      judgeReliableScenarioProfileCount: byScenarioProfile.values.where((
        traces,
      ) {
        return _complete(traces) &&
            traces.every((trace) => trace.verdict?.pass ?? false);
      }).length,
      meanTotalTokens: _mean(
        group.map((trace) => trace.output.usage.totalTokens.toDouble()),
      ),
    );
  }

  static SliceSummary _expectedSliceSummary({
    required _ExpectedSliceMatrix matrix,
    required List<EvalTrace> group,
  }) {
    final byScenarioProfile = _byScenarioProfile(group);
    final judged = group
        .where((trace) => trace.verdict != null)
        .toList(growable: false);
    var completeScenarioCount = 0;
    var completeScenarioProfileCount = 0;
    var level1ReliableScenarioProfileCount = 0;
    var judgeReliableScenarioProfileCount = 0;

    for (final scenario in matrix.scenarios.values) {
      var scenarioComplete = matrix.profiles.isNotEmpty;
      for (final profile in matrix.profiles.values) {
        final traces =
            byScenarioProfile[_scenarioProfileKey(scenario.id, profile.name)] ??
            const <EvalTrace>[];
        final complete = _completeForProfile(traces, profile);
        if (!complete) scenarioComplete = false;
        if (complete) {
          completeScenarioProfileCount++;
          if (traces.every((trace) => trace.level1Passed)) {
            level1ReliableScenarioProfileCount++;
          }
          if (traces.every((trace) => trace.verdict?.pass ?? false)) {
            judgeReliableScenarioProfileCount++;
          }
        }
      }
      if (scenarioComplete) completeScenarioCount++;
    }

    final trialCount =
        matrix.scenarios.length *
        matrix.profiles.values.fold<int>(
          0,
          (sum, profile) => sum + profile.trialCount,
        );
    return SliceSummary(
      split: matrix.split,
      modelClass: matrix.modelClass,
      capabilityId: matrix.capabilityId,
      profileCount: matrix.profiles.length,
      scenarioCount: matrix.scenarios.length,
      scenarioProfileCount: matrix.scenarios.length * matrix.profiles.length,
      completeScenarioCount: completeScenarioCount,
      completeScenarioProfileCount: completeScenarioProfileCount,
      trialCount: trialCount,
      traceCount: group.length,
      level1PassCount: group.where((trace) => trace.level1Passed).length,
      level1ReliableScenarioProfileCount: level1ReliableScenarioProfileCount,
      judgedTraceCount: judged.length,
      judgePassCount: judged.where((trace) => trace.verdict!.pass).length,
      judgeReliableScenarioProfileCount: judgeReliableScenarioProfileCount,
      meanTotalTokens: _mean(
        group.map((trace) => trace.output.usage.totalTokens.toDouble()),
      ),
    );
  }

  static int _compareSliceSummaries(SliceSummary a, SliceSummary b) {
    final splitOrder = a.split.name.compareTo(b.split.name);
    if (splitOrder != 0) return splitOrder;
    final classOrder = a.modelClass.name.compareTo(b.modelClass.name);
    if (classOrder != 0) return classOrder;
    return a.capabilityId.compareTo(b.capabilityId);
  }

  static Map<String, List<EvalTrace>> _byScenario(List<EvalTrace> traces) {
    final byScenario = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      byScenario.putIfAbsent(trace.scenario.id, () => <EvalTrace>[]).add(trace);
    }
    return byScenario;
  }

  static Map<String, List<EvalTrace>> _byProfile(List<EvalTrace> traces) {
    final byProfile = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      byProfile.putIfAbsent(trace.profile.name, () => <EvalTrace>[]).add(trace);
    }
    return byProfile;
  }

  static Map<String, List<EvalTrace>> _byScenarioProfile(
    List<EvalTrace> traces,
  ) {
    final byScenarioProfile = <String, List<EvalTrace>>{};
    for (final trace in traces) {
      byScenarioProfile
          .putIfAbsent(
            _scenarioProfileKey(trace.scenario.id, trace.profile.name),
            () => <EvalTrace>[],
          )
          .add(trace);
    }
    return byScenarioProfile;
  }

  static ProfilePairComparison _compareProfilePair({
    required String leftProfileName,
    required String rightProfileName,
    required Map<String, List<EvalTrace>> leftScenarios,
    required Map<String, List<EvalTrace>> rightScenarios,
  }) {
    final leftKeys = leftScenarios.keys.toSet();
    final rightKeys = rightScenarios.keys.toSet();
    final commonKeys = leftKeys.intersection(rightKeys).toList()..sort();

    var pairedScenarioCount = 0;
    var incompleteScenarioCount = 0;
    var level1LeftPassCount = 0;
    var level1RightPassCount = 0;
    var level1LeftOnlyPassCount = 0;
    var level1RightOnlyPassCount = 0;
    var level1SameOutcomeCount = 0;
    var judgePairedScenarioCount = 0;
    var judgeMissingScenarioCount = 0;
    var judgeLeftPassCount = 0;
    var judgeRightPassCount = 0;
    var judgeLeftOnlyPassCount = 0;
    var judgeRightOnlyPassCount = 0;
    var judgeSameOutcomeCount = 0;
    var goalDeltaSum = 0.0;
    var qualityDeltaSum = 0.0;
    var efficiencyDeltaSum = 0.0;
    var leftTotalTokenSum = 0.0;
    var rightTotalTokenSum = 0.0;
    var estimatedCostScenarioCount = 0;
    var estimatedCostMissingScenarioCount = 0;
    var leftEstimatedCostSum = 0.0;
    var rightEstimatedCostSum = 0.0;
    final leftProfile = _firstProfile(leftScenarios);
    final rightProfile = _firstProfile(rightScenarios);
    final leftUsesWeightedTokenCosts =
        leftProfile?.usesWeightedTokenCosts ?? false;
    final rightUsesWeightedTokenCosts =
        rightProfile?.usesWeightedTokenCosts ?? false;
    final usesEstimatedCost =
        leftUsesWeightedTokenCosts || rightUsesWeightedTokenCosts;

    for (final key in commonKeys) {
      final leftTraces = leftScenarios[key]!;
      final rightTraces = rightScenarios[key]!;
      if (!_complete(leftTraces) || !_complete(rightTraces)) {
        incompleteScenarioCount++;
        continue;
      }

      pairedScenarioCount++;
      final leftLevel1Pass = leftTraces.every((trace) => trace.level1Passed);
      final rightLevel1Pass = rightTraces.every((trace) => trace.level1Passed);
      if (leftLevel1Pass) level1LeftPassCount++;
      if (rightLevel1Pass) level1RightPassCount++;
      if (leftLevel1Pass == rightLevel1Pass) {
        level1SameOutcomeCount++;
      } else if (leftLevel1Pass) {
        level1LeftOnlyPassCount++;
      } else {
        level1RightOnlyPassCount++;
      }
      final leftMissingUsage = leftTraces.any(
        (trace) => trace.profile
            .missingEstimatedCostFields(
              trace.output.usage,
              requireCoreTokenCounts: true,
            )
            .isNotEmpty,
      );
      final rightMissingUsage = rightTraces.any(
        (trace) => trace.profile
            .missingEstimatedCostFields(
              trace.output.usage,
              requireCoreTokenCounts: true,
            )
            .isNotEmpty,
      );
      if (leftMissingUsage || rightMissingUsage) {
        estimatedCostMissingScenarioCount++;
      } else {
        final leftMeanTokens = _mean(
          leftTraces.map((trace) => trace.output.usage.totalTokens.toDouble()),
        );
        final rightMeanTokens = _mean(
          rightTraces.map((trace) => trace.output.usage.totalTokens.toDouble()),
        );
        leftTotalTokenSum += leftMeanTokens;
        rightTotalTokenSum += rightMeanTokens;
        if (!usesEstimatedCost) {
          estimatedCostScenarioCount++;
          leftEstimatedCostSum += leftMeanTokens;
          rightEstimatedCostSum += rightMeanTokens;
        }
      }
      if (usesEstimatedCost && !leftMissingUsage && !rightMissingUsage) {
        final leftCosts = [
          for (final trace in leftTraces)
            trace.profile.estimatedUsageCostMicrosOrNull(
              trace.output.usage,
              requireCoreTokenCounts: true,
            ),
        ];
        final rightCosts = [
          for (final trace in rightTraces)
            trace.profile.estimatedUsageCostMicrosOrNull(
              trace.output.usage,
              requireCoreTokenCounts: true,
            ),
        ];
        if (leftCosts.any((cost) => cost == null) ||
            rightCosts.any((cost) => cost == null)) {
          estimatedCostMissingScenarioCount++;
        } else {
          estimatedCostScenarioCount++;
          leftEstimatedCostSum += _mean(
            leftCosts.map((cost) => cost!.toDouble()),
          );
          rightEstimatedCostSum += _mean(
            rightCosts.map((cost) => cost!.toDouble()),
          );
        }
      }

      final leftVerdicts = [
        for (final trace in leftTraces)
          if (trace.verdict != null) trace.verdict!,
      ];
      final rightVerdicts = [
        for (final trace in rightTraces)
          if (trace.verdict != null) trace.verdict!,
      ];
      if (leftVerdicts.length != leftTraces.length ||
          rightVerdicts.length != rightTraces.length) {
        judgeMissingScenarioCount++;
        continue;
      }

      judgePairedScenarioCount++;
      final leftJudgePass = leftVerdicts.every((verdict) => verdict.pass);
      final rightJudgePass = rightVerdicts.every((verdict) => verdict.pass);
      if (leftJudgePass) judgeLeftPassCount++;
      if (rightJudgePass) judgeRightPassCount++;
      if (leftJudgePass == rightJudgePass) {
        judgeSameOutcomeCount++;
      } else if (leftJudgePass) {
        judgeLeftOnlyPassCount++;
      } else {
        judgeRightOnlyPassCount++;
      }
      goalDeltaSum +=
          _mean(
            leftVerdicts.map((verdict) => verdict.goalAttainment.toDouble()),
          ) -
          _mean(
            rightVerdicts.map((verdict) => verdict.goalAttainment.toDouble()),
          );
      qualityDeltaSum +=
          _mean(leftVerdicts.map((verdict) => verdict.quality.toDouble())) -
          _mean(rightVerdicts.map((verdict) => verdict.quality.toDouble()));
      efficiencyDeltaSum +=
          _mean(leftVerdicts.map((verdict) => verdict.efficiency.toDouble())) -
          _mean(rightVerdicts.map((verdict) => verdict.efficiency.toDouble()));
    }

    return ProfilePairComparison(
      leftProfileName: leftProfileName,
      rightProfileName: rightProfileName,
      pairedScenarioCount: pairedScenarioCount,
      leftOnlyScenarioCount: leftKeys.difference(rightKeys).length,
      rightOnlyScenarioCount: rightKeys.difference(leftKeys).length,
      incompleteScenarioCount: incompleteScenarioCount,
      level1LeftPassCount: level1LeftPassCount,
      level1RightPassCount: level1RightPassCount,
      level1LeftOnlyPassCount: level1LeftOnlyPassCount,
      level1RightOnlyPassCount: level1RightOnlyPassCount,
      level1SameOutcomeCount: level1SameOutcomeCount,
      judgePairedScenarioCount: judgePairedScenarioCount,
      judgeMissingScenarioCount: judgeMissingScenarioCount,
      judgeLeftPassCount: judgeLeftPassCount,
      judgeRightPassCount: judgeRightPassCount,
      judgeLeftOnlyPassCount: judgeLeftOnlyPassCount,
      judgeRightOnlyPassCount: judgeRightOnlyPassCount,
      judgeSameOutcomeCount: judgeSameOutcomeCount,
      meanGoalAttainmentDelta: _meanDelta(
        goalDeltaSum,
        judgePairedScenarioCount,
      ),
      meanQualityDelta: _meanDelta(qualityDeltaSum, judgePairedScenarioCount),
      meanEfficiencyDelta: _meanDelta(
        efficiencyDeltaSum,
        judgePairedScenarioCount,
      ),
      meanTotalTokenDelta: _meanDelta(
        leftTotalTokenSum - rightTotalTokenSum,
        pairedScenarioCount,
      ),
      totalTokenRatio: _ratioValue(
        numerator: leftTotalTokenSum,
        denominator: rightTotalTokenSum,
        emptyValue: pairedScenarioCount == 0 ? 0 : 1,
      ),
      estimatedCostScenarioCount: estimatedCostScenarioCount,
      estimatedCostMissingScenarioCount: estimatedCostMissingScenarioCount,
      meanEstimatedCostDelta: _meanDelta(
        leftEstimatedCostSum - rightEstimatedCostSum,
        estimatedCostScenarioCount,
      ),
      estimatedCostRatio: _ratioValue(
        numerator: leftEstimatedCostSum,
        denominator: rightEstimatedCostSum,
        emptyValue: estimatedCostScenarioCount == 0 ? 0 : 1,
      ),
      usesEstimatedCost: usesEstimatedCost,
      leftUsesWeightedTokenCosts: leftUsesWeightedTokenCosts,
      rightUsesWeightedTokenCosts: rightUsesWeightedTokenCosts,
    );
  }

  static EvalProfile? _firstProfile(
    Map<String, List<EvalTrace>> scenarioTraces,
  ) {
    for (final traces in scenarioTraces.values) {
      if (traces.isNotEmpty) return traces.first.profile;
    }
    return null;
  }

  static bool _complete(List<EvalTrace> traces) {
    if (traces.isEmpty) return false;
    return _completeForProfile(traces, traces.first.profile);
  }

  static bool _completeForProfile(List<EvalTrace> traces, EvalProfile profile) {
    if (traces.isEmpty) return false;
    final trialCount = profile.trialCount;
    final expected = {for (var i = 0; i < trialCount; i++) i};
    final actual = traces.map((trace) => trace.trialIndex).toSet();
    return traces.length == trialCount &&
        actual.length == expected.length &&
        actual.containsAll(expected);
  }

  static String _sliceKey({
    required EvalScenarioSplit split,
    required EvalModelClass modelClass,
    required String capabilityId,
  }) => [split.name, modelClass.name, capabilityId].join('\n');

  static String _scenarioProfileKey(String scenarioId, String profileName) =>
      '$scenarioId\n$profileName';

  static double _mean(Iterable<double> values) {
    final list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static double _meanDelta(double sum, int total) =>
      total == 0 ? 0 : sum / total;

  static String _pct(double ratio) => '${(ratio * 100).round()}%';

  static String _signedPct(double ratio) {
    final value = (ratio * 100).round();
    return value > 0 ? '+$value%' : '$value%';
  }

  static String _one(double value) => value.toStringAsFixed(1);

  static String _signedOne(double value) {
    final formatted = value.toStringAsFixed(1);
    return value > 0 ? '+$formatted' : formatted;
  }

  static double _ratioValue({
    required double numerator,
    required double denominator,
    required double emptyValue,
  }) {
    if (denominator == 0) return numerator == 0 ? emptyValue : double.infinity;
    return numerator / denominator;
  }

  static String _ratio(double value) {
    if (value.isInfinite) return 'inf';
    return '${value.toStringAsFixed(2)}x';
  }

  static String _comparisonNote(ProfilePairComparison comparison) {
    if (!comparison.isComparable) return 'not comparable';
    if (comparison.estimatedCostMissingScenarioCount > 0) return 'cost missing';
    if (comparison.isLowSample) return 'low n';
    return '';
  }

  static int _compareProviderRequestStability(
    ProviderRequestStabilitySummary left,
    ProviderRequestStabilitySummary right,
  ) {
    final profileOrder = left.profileName.compareTo(right.profileName);
    if (profileOrder != 0) return profileOrder;
    final scenarioOrder = left.scenarioId.compareTo(right.scenarioId);
    if (scenarioOrder != 0) return scenarioOrder;
    final providerOrder = left.providerType.compareTo(right.providerType);
    if (providerOrder != 0) return providerOrder;
    final modelOrder = left.providerModelId.compareTo(right.providerModelId);
    if (modelOrder != 0) return modelOrder;
    final endpointOrder = left.endpointKey.compareTo(right.endpointKey);
    if (endpointOrder != 0) return endpointOrder;
    final invocationOrder = left.invocationIndex.compareTo(
      right.invocationIndex,
    );
    if (invocationOrder != 0) return invocationOrder;
    final turnOrder = left.turnIndex.compareTo(right.turnIndex);
    if (turnOrder != 0) return turnOrder;
    return left.requestIndex.compareTo(right.requestIndex);
  }

  static String _formatIntSet(List<int> values) {
    if (values.isEmpty) return '-';
    return values.join(',');
  }

  static String _clip(String value, int width) {
    if (value.length <= width) return value;
    return value.substring(0, width - 1);
  }
}
