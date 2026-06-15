import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'eval_judge_calibration.dart';
import 'eval_models.dart';
import 'eval_pairwise_preference.dart';
import 'eval_provenance.dart';
import 'eval_scenario_validation.dart';
import 'eval_statistics.dart';

enum EvalPairwiseReadinessPreferredOption {
  optionA,
  optionB;

  static EvalPairwiseReadinessPreferredOption fromName(String name) =>
      EvalPairwiseReadinessPreferredOption.values.firstWhere(
        (value) => value.name == name,
      );
}

enum EvalPairwiseReadinessOutcomeRequirement {
  mustWin,
  mustNotLose;

  static EvalPairwiseReadinessOutcomeRequirement fromName(String name) =>
      EvalPairwiseReadinessOutcomeRequirement.values.firstWhere(
        (value) => value.name == name,
      );
}

@immutable
class EvalPairwiseReadinessOutcomeExpectation {
  const EvalPairwiseReadinessOutcomeExpectation({
    required this.preferredOptionKey,
    required this.requirement,
  });

  factory EvalPairwiseReadinessOutcomeExpectation.fromJson(
    Map<String, dynamic> json,
  ) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessOutcomeExpectation',
      {'preferredOptionKey', 'requirement'},
    );
    return EvalPairwiseReadinessOutcomeExpectation(
      preferredOptionKey: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'preferredOptionKey',
      ),
      requirement: EvalPairwiseReadinessOutcomeRequirement.fromName(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'requirement'),
      ),
    );
  }

  final String preferredOptionKey;
  final EvalPairwiseReadinessOutcomeRequirement requirement;

  bool get allowsTie =>
      requirement == EvalPairwiseReadinessOutcomeRequirement.mustNotLose;

  bool isSatisfiedBy(EvalPairwisePreferenceSummary summary) {
    if (summary.status == EvalPairwisePreferenceStatus.tie) {
      return allowsTie;
    }
    final preferredTrace = summary.preferredTrace;
    if (preferredTrace == null) return false;
    return _pairwiseIntentOptionKeyForTraceRef(preferredTrace) ==
        preferredOptionKey;
  }

  String describe() =>
      '$preferredOptionKey ${requirement == EvalPairwiseReadinessOutcomeRequirement.mustWin ? 'must win' : 'must not lose'}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'preferredOptionKey': preferredOptionKey,
    'requirement': requirement.name,
  };

  List<String> validate() {
    if (preferredOptionKey.trim().isEmpty) {
      return ['preferredOptionKey must be non-empty'];
    }
    return const [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvalPairwiseReadinessOutcomeExpectation &&
          preferredOptionKey == other.preferredOptionKey &&
          requirement == other.requirement;

  @override
  int get hashCode => Object.hash(preferredOptionKey, requirement);
}

class EvalTuningPolicy {
  const EvalTuningPolicy({
    required this.name,
    this.requiredModelClasses = const <EvalModelClass>{},
    this.requiredProfileNames = const <String>{},
    this.requiredPrimaryCapabilityIds = const <String>{},
    this.requiredSplits = const <EvalScenarioSplit>{},
    this.requiredAgentKinds = const <AgentKind>{},
    this.minScenarioCount = 1,
    this.minScenariosPerAgentKind = 0,
    this.minScenariosPerCapability = 0,
    this.minScenariosPerRequiredCapabilitySplit = 0,
    this.minCapabilityCount = 0,
    this.minAdversarialScenarioCount = 0,
    this.minAdversarialScenariosPerAgentKind = 0,
    this.minAdversarialScenariosPerCapability = 0,
    this.requiredAdversarialTags = const <String>{},
    this.requireAdversarialTagCoveragePerAgentKind = false,
    this.minProductionReplayHoldoutScenarios = 0,
    this.minProtectedHoldoutScenarios = 0,
    this.minProtectedHoldoutScenariosPerAgentKind = 0,
    this.minProtectedHoldoutScenariosPerRequiredCapability = 0,
    this.minProfilesPerModelClass = 1,
    this.minTrialsPerProfile = 1,
    this.requireCompleteTraceMatrix = true,
    this.requireAllVerdicts = false,
    this.requireAllLevel1Passed = false,
    this.requireAllJudgePasses = false,
    this.requireOutcomeSliceThresholds = false,
    this.minOutcomeJudgedTraceCoverageRate = 0,
    this.minJudgePassRate = 0,
    this.minJudgePassRateLowerBound = 0,
    this.minMeanGoalAttainment = 0,
    this.minMeanQuality = 0,
    this.minMeanEfficiency = 0,
    this.maxMeanTokensPerTraceBudgetRatio,
    this.maxMeanWeightedCostPerTraceBudgetRatio,
    this.requireWeightedCostEvidence = false,
    this.requireCalibratedVerdicts = false,
    this.requireBlindedJudgeVerdicts = false,
    this.requiredCalibrationSetVersion,
    this.requiredHumanCalibrationSetVersion,
    this.requireCalibrationSourceRun = false,
    this.requireCalibrationTemplateSelection = false,
    this.requireCalibrationReport = false,
    this.minCalibrationEvaluatedCount = 0,
    this.minCalibrationEvaluatedPerModelClass = 0,
    this.minCalibrationEvaluatedPerCapability = 0,
    this.minCalibrationEvaluatedPerModelClassCapability = 0,
    this.minCalibrationEvaluatedPerPromptVariant = 0,
    this.minCalibrationEvaluatedPerModelClassPromptVariant = 0,
    this.requireProtectedCalibrationHoldout = false,
    this.minProtectedCalibrationEvaluatedCount = 0,
    this.minProtectedCalibrationEvaluatedPerModelClass = 0,
    this.minProtectedCalibrationEvaluatedPerCapability = 0,
    this.minProtectedCalibrationEvaluatedPerModelClassCapability = 0,
    this.minProtectedCalibrationEvaluatedPerPromptVariant = 0,
    this.minProtectedCalibrationEvaluatedPerModelClassPromptVariant = 0,
    this.minCalibrationCoverageRate = 0,
    this.minCalibrationCoverageLowerBound = 0,
    this.minCalibrationPassAgreementRate = 0,
    this.minCalibrationPassAgreementPerPromptVariant = 0,
    this.minCalibrationPassAgreementLowerBound = 0,
    this.minCalibrationScoreAgreementRate = 0,
    this.minCalibrationScoreAgreementPerPromptVariant = 0,
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
    this.requireManifestPolicyEvidence = false,
    this.minBlindedPairwisePreferenceDecisions = 0,
    this.requiredBlindedPairwisePreferenceComparisonKeys = const <String>{},
    this.requiredBlindedPairwisePreferenceIntentKeys = const <String>{},
    this.requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey =
        const <String, EvalPairwiseReadinessOutcomeExpectation>{},
    this.requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey =
        const <String, EvalPairwiseReadinessOutcomeExpectation>{},
    this.blindedPairwisePreferencePolicy = const EvalPairwisePreferencePolicy(
      requireProfileBlind: true,
      requireTraceOrderRandomized: true,
      requireBlindedImport: true,
    ),
  });

  const EvalTuningPolicy.developmentSmoke() : this(name: 'developmentSmoke');

  const EvalTuningPolicy.modelClassTuning({
    String? requiredCalibrationSetVersion,
    String? requiredHumanCalibrationSetVersion,
    Set<String> requiredPrimaryCapabilityIds = const <String>{},
    int minBlindedPairwisePreferenceDecisions = 0,
    Set<String> requiredBlindedPairwisePreferenceComparisonKeys =
        const <String>{},
    Set<String> requiredBlindedPairwisePreferenceIntentKeys = const <String>{},
    Map<String, EvalPairwiseReadinessOutcomeExpectation>
        requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey =
        const <String, EvalPairwiseReadinessOutcomeExpectation>{},
    Map<String, EvalPairwiseReadinessOutcomeExpectation>
        requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey =
        const <String, EvalPairwiseReadinessOutcomeExpectation>{},
    EvalPairwisePreferencePolicy blindedPairwisePreferencePolicy =
        const EvalPairwisePreferencePolicy(
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
  }) : this(
         name: 'modelClassTuning',
         requiredModelClasses: const {
           EvalModelClass.localSmall,
           EvalModelClass.localReasoning,
           EvalModelClass.frontierFast,
           EvalModelClass.frontierReasoning,
         },
         requiredPrimaryCapabilityIds: requiredPrimaryCapabilityIds,
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
         minScenariosPerRequiredCapabilitySplit: 1,
         minCapabilityCount: 4,
         minAdversarialScenarioCount: 4,
         minAdversarialScenariosPerAgentKind: 2,
         minAdversarialScenariosPerCapability: 1,
         requiredAdversarialTags: kDefaultAdversarialStressTags,
         requireAdversarialTagCoveragePerAgentKind: true,
         minProductionReplayHoldoutScenarios: 4,
         minProtectedHoldoutScenarios: 4,
         minProtectedHoldoutScenariosPerAgentKind: 2,
         minProtectedHoldoutScenariosPerRequiredCapability: 1,
         minTrialsPerProfile: 3,
         requireCompleteTraceMatrix: true,
         requireAllVerdicts: true,
         requireAllLevel1Passed: true,
         requireAllJudgePasses: true,
         requireOutcomeSliceThresholds: true,
         minOutcomeJudgedTraceCoverageRate: 1,
         minJudgePassRate: 1,
         minJudgePassRateLowerBound: 0.7,
         minMeanGoalAttainment: 4,
         minMeanQuality: 4,
         minMeanEfficiency: 3,
         maxMeanTokensPerTraceBudgetRatio: 1,
         maxMeanWeightedCostPerTraceBudgetRatio: 1,
         requireWeightedCostEvidence: true,
         requireCalibratedVerdicts: true,
         requireBlindedJudgeVerdicts: true,
         requiredCalibrationSetVersion: requiredCalibrationSetVersion,
         requiredHumanCalibrationSetVersion: requiredHumanCalibrationSetVersion,
         requireCalibrationSourceRun: true,
         requireCalibrationTemplateSelection: true,
         requireCalibrationReport: true,
         minCalibrationEvaluatedCount: 12,
         minCalibrationEvaluatedPerModelClass: 2,
         minCalibrationEvaluatedPerCapability: 2,
         minCalibrationEvaluatedPerModelClassCapability: 1,
         minCalibrationEvaluatedPerPromptVariant: 2,
         minCalibrationEvaluatedPerModelClassPromptVariant: 2,
         requireProtectedCalibrationHoldout: true,
         minProtectedCalibrationEvaluatedCount: 4,
         minProtectedCalibrationEvaluatedPerModelClass: 1,
         minProtectedCalibrationEvaluatedPerCapability: 1,
         minProtectedCalibrationEvaluatedPerModelClassCapability: 1,
         minProtectedCalibrationEvaluatedPerPromptVariant: 1,
         minProtectedCalibrationEvaluatedPerModelClassPromptVariant: 1,
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
         requireManifestPolicyEvidence: true,
         minBlindedPairwisePreferenceDecisions:
             minBlindedPairwisePreferenceDecisions,
         requiredBlindedPairwisePreferenceComparisonKeys:
             requiredBlindedPairwisePreferenceComparisonKeys,
         requiredBlindedPairwisePreferenceIntentKeys:
             requiredBlindedPairwisePreferenceIntentKeys,
         requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey:
             requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey,
         requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey:
             requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey,
         blindedPairwisePreferencePolicy: blindedPairwisePreferencePolicy,
       );

  factory EvalTuningPolicy.fromJson(Map<String, dynamic> json) {
    _rejectUnknownTuningPolicyFields(json);
    return EvalTuningPolicy(
      name: _requiredTuningPolicyString(json, 'name'),
      requiredModelClasses: _requiredTuningPolicyEnumSet(
        json,
        'requiredModelClasses',
        EvalModelClass.fromName,
      ),
      requiredProfileNames: _requiredTuningPolicyStringSet(
        json,
        'requiredProfileNames',
      ),
      requiredPrimaryCapabilityIds: _requiredTuningPolicyStringSet(
        json,
        'requiredPrimaryCapabilityIds',
      ),
      requiredSplits: _requiredTuningPolicyEnumSet(
        json,
        'requiredSplits',
        EvalScenarioSplit.fromName,
      ),
      requiredAgentKinds: _requiredTuningPolicyEnumSet(
        json,
        'requiredAgentKinds',
        AgentKind.fromName,
      ),
      minScenarioCount: _requiredTuningPolicyInt(json, 'minScenarioCount'),
      minScenariosPerAgentKind: _requiredTuningPolicyInt(
        json,
        'minScenariosPerAgentKind',
      ),
      minScenariosPerCapability: _requiredTuningPolicyInt(
        json,
        'minScenariosPerCapability',
      ),
      minScenariosPerRequiredCapabilitySplit: _requiredTuningPolicyInt(
        json,
        'minScenariosPerRequiredCapabilitySplit',
      ),
      minCapabilityCount: _requiredTuningPolicyInt(
        json,
        'minCapabilityCount',
      ),
      minAdversarialScenarioCount: _requiredTuningPolicyInt(
        json,
        'minAdversarialScenarioCount',
      ),
      minAdversarialScenariosPerAgentKind: _requiredTuningPolicyInt(
        json,
        'minAdversarialScenariosPerAgentKind',
      ),
      minAdversarialScenariosPerCapability: _requiredTuningPolicyInt(
        json,
        'minAdversarialScenariosPerCapability',
      ),
      requiredAdversarialTags: _requiredTuningPolicyStringSet(
        json,
        'requiredAdversarialTags',
      ),
      requireAdversarialTagCoveragePerAgentKind: _requiredTuningPolicyBool(
        json,
        'requireAdversarialTagCoveragePerAgentKind',
      ),
      minProductionReplayHoldoutScenarios: _requiredTuningPolicyInt(
        json,
        'minProductionReplayHoldoutScenarios',
      ),
      minProtectedHoldoutScenarios: _requiredTuningPolicyInt(
        json,
        'minProtectedHoldoutScenarios',
      ),
      minProtectedHoldoutScenariosPerAgentKind: _requiredTuningPolicyInt(
        json,
        'minProtectedHoldoutScenariosPerAgentKind',
      ),
      minProtectedHoldoutScenariosPerRequiredCapability:
          _requiredTuningPolicyInt(
            json,
            'minProtectedHoldoutScenariosPerRequiredCapability',
          ),
      minProfilesPerModelClass: _requiredTuningPolicyInt(
        json,
        'minProfilesPerModelClass',
      ),
      minTrialsPerProfile: _requiredTuningPolicyInt(
        json,
        'minTrialsPerProfile',
      ),
      requireCompleteTraceMatrix: _requiredTuningPolicyBool(
        json,
        'requireCompleteTraceMatrix',
      ),
      requireAllVerdicts: _requiredTuningPolicyBool(
        json,
        'requireAllVerdicts',
      ),
      requireAllLevel1Passed: _requiredTuningPolicyBool(
        json,
        'requireAllLevel1Passed',
      ),
      requireAllJudgePasses: _requiredTuningPolicyBool(
        json,
        'requireAllJudgePasses',
      ),
      requireOutcomeSliceThresholds: _requiredTuningPolicyBool(
        json,
        'requireOutcomeSliceThresholds',
      ),
      minOutcomeJudgedTraceCoverageRate: _requiredTuningPolicyDouble(
        json,
        'minOutcomeJudgedTraceCoverageRate',
      ),
      minJudgePassRate: _requiredTuningPolicyDouble(json, 'minJudgePassRate'),
      minJudgePassRateLowerBound: _requiredTuningPolicyDouble(
        json,
        'minJudgePassRateLowerBound',
      ),
      minMeanGoalAttainment: _requiredTuningPolicyDouble(
        json,
        'minMeanGoalAttainment',
      ),
      minMeanQuality: _requiredTuningPolicyDouble(json, 'minMeanQuality'),
      minMeanEfficiency: _requiredTuningPolicyDouble(
        json,
        'minMeanEfficiency',
      ),
      maxMeanTokensPerTraceBudgetRatio: _optionalTuningPolicyDouble(
        json,
        'maxMeanTokensPerTraceBudgetRatio',
      ),
      maxMeanWeightedCostPerTraceBudgetRatio: _optionalTuningPolicyDouble(
        json,
        'maxMeanWeightedCostPerTraceBudgetRatio',
      ),
      requireWeightedCostEvidence: _requiredTuningPolicyBool(
        json,
        'requireWeightedCostEvidence',
      ),
      requireCalibratedVerdicts: _requiredTuningPolicyBool(
        json,
        'requireCalibratedVerdicts',
      ),
      requireBlindedJudgeVerdicts: _requiredTuningPolicyBool(
        json,
        'requireBlindedJudgeVerdicts',
      ),
      requiredCalibrationSetVersion: _optionalTuningPolicyString(
        json,
        'requiredCalibrationSetVersion',
      ),
      requiredHumanCalibrationSetVersion: _optionalTuningPolicyString(
        json,
        'requiredHumanCalibrationSetVersion',
      ),
      requireCalibrationSourceRun:
          _optionalTuningPolicyBool(json, 'requireCalibrationSourceRun') ??
          false,
      requireCalibrationTemplateSelection:
          _optionalTuningPolicyBool(
            json,
            'requireCalibrationTemplateSelection',
          ) ??
          false,
      requireCalibrationReport: _requiredTuningPolicyBool(
        json,
        'requireCalibrationReport',
      ),
      minCalibrationEvaluatedCount: _requiredTuningPolicyInt(
        json,
        'minCalibrationEvaluatedCount',
      ),
      minCalibrationEvaluatedPerModelClass: _requiredTuningPolicyInt(
        json,
        'minCalibrationEvaluatedPerModelClass',
      ),
      minCalibrationEvaluatedPerCapability: _requiredTuningPolicyInt(
        json,
        'minCalibrationEvaluatedPerCapability',
      ),
      minCalibrationEvaluatedPerModelClassCapability:
          _optionalTuningPolicyInt(
            json,
            'minCalibrationEvaluatedPerModelClassCapability',
          ) ??
          0,
      minCalibrationEvaluatedPerPromptVariant: _requiredTuningPolicyInt(
        json,
        'minCalibrationEvaluatedPerPromptVariant',
      ),
      minCalibrationEvaluatedPerModelClassPromptVariant:
          _requiredTuningPolicyInt(
            json,
            'minCalibrationEvaluatedPerModelClassPromptVariant',
          ),
      requireProtectedCalibrationHoldout:
          _optionalTuningPolicyBool(
            json,
            'requireProtectedCalibrationHoldout',
          ) ??
          false,
      minProtectedCalibrationEvaluatedCount:
          _optionalTuningPolicyInt(
            json,
            'minProtectedCalibrationEvaluatedCount',
          ) ??
          0,
      minProtectedCalibrationEvaluatedPerModelClass:
          _optionalTuningPolicyInt(
            json,
            'minProtectedCalibrationEvaluatedPerModelClass',
          ) ??
          0,
      minProtectedCalibrationEvaluatedPerCapability:
          _optionalTuningPolicyInt(
            json,
            'minProtectedCalibrationEvaluatedPerCapability',
          ) ??
          0,
      minProtectedCalibrationEvaluatedPerModelClassCapability:
          _optionalTuningPolicyInt(
            json,
            'minProtectedCalibrationEvaluatedPerModelClassCapability',
          ) ??
          0,
      minProtectedCalibrationEvaluatedPerPromptVariant:
          _optionalTuningPolicyInt(
            json,
            'minProtectedCalibrationEvaluatedPerPromptVariant',
          ) ??
          0,
      minProtectedCalibrationEvaluatedPerModelClassPromptVariant:
          _optionalTuningPolicyInt(
            json,
            'minProtectedCalibrationEvaluatedPerModelClassPromptVariant',
          ) ??
          0,
      minCalibrationCoverageRate: _requiredTuningPolicyDouble(
        json,
        'minCalibrationCoverageRate',
      ),
      minCalibrationCoverageLowerBound: _requiredTuningPolicyDouble(
        json,
        'minCalibrationCoverageLowerBound',
      ),
      minCalibrationPassAgreementRate: _requiredTuningPolicyDouble(
        json,
        'minCalibrationPassAgreementRate',
      ),
      minCalibrationPassAgreementPerPromptVariant: _requiredTuningPolicyDouble(
        json,
        'minCalibrationPassAgreementPerPromptVariant',
      ),
      minCalibrationPassAgreementLowerBound: _requiredTuningPolicyDouble(
        json,
        'minCalibrationPassAgreementLowerBound',
      ),
      minCalibrationScoreAgreementRate: _requiredTuningPolicyDouble(
        json,
        'minCalibrationScoreAgreementRate',
      ),
      minCalibrationScoreAgreementPerPromptVariant: _requiredTuningPolicyDouble(
        json,
        'minCalibrationScoreAgreementPerPromptVariant',
      ),
      minCalibrationScoreAgreementLowerBound: _requiredTuningPolicyDouble(
        json,
        'minCalibrationScoreAgreementLowerBound',
      ),
      minCalibrationHumanReviewPairCount: _requiredTuningPolicyInt(
        json,
        'minCalibrationHumanReviewPairCount',
      ),
      minCalibrationHumanPassAgreementRate: _requiredTuningPolicyDouble(
        json,
        'minCalibrationHumanPassAgreementRate',
      ),
      minCalibrationHumanPassAgreementLowerBound: _requiredTuningPolicyDouble(
        json,
        'minCalibrationHumanPassAgreementLowerBound',
      ),
      minCalibrationHumanScoreAgreementRate: _requiredTuningPolicyDouble(
        json,
        'minCalibrationHumanScoreAgreementRate',
      ),
      minCalibrationHumanScoreAgreementLowerBound: _requiredTuningPolicyDouble(
        json,
        'minCalibrationHumanScoreAgreementLowerBound',
      ),
      maxCalibrationUnresolvedHumanDisagreementCount: _optionalTuningPolicyInt(
        json,
        'maxCalibrationUnresolvedHumanDisagreementCount',
      ),
      requireBlindedHumanReviews: _requiredTuningPolicyBool(
        json,
        'requireBlindedHumanReviews',
      ),
      maxCalibrationFalsePassCount: _optionalTuningPolicyInt(
        json,
        'maxCalibrationFalsePassCount',
      ),
      maxCalibrationFalsePassRate: _requiredTuningPolicyDouble(
        json,
        'maxCalibrationFalsePassRate',
      ),
      maxCalibrationFalseFailRate: _requiredTuningPolicyDouble(
        json,
        'maxCalibrationFalseFailRate',
      ),
      requireBlindedCalibrationReport: _requiredTuningPolicyBool(
        json,
        'requireBlindedCalibrationReport',
      ),
      requireCleanCalibrationReport: _requiredTuningPolicyBool(
        json,
        'requireCleanCalibrationReport',
      ),
      requireManifest: _requiredTuningPolicyBool(json, 'requireManifest'),
      requiredTargetKind: _optionalTuningPolicyString(
        json,
        'requiredTargetKind',
      ),
      expectedScenarioSetDigest: _optionalTuningPolicyString(
        json,
        'expectedScenarioSetDigest',
      ),
      expectedProfileSetDigest: _optionalTuningPolicyString(
        json,
        'expectedProfileSetDigest',
      ),
      requireProtectedHoldout: _requiredTuningPolicyBool(
        json,
        'requireProtectedHoldout',
      ),
      requireReviewedScenarioEvidence: _requiredTuningPolicyBool(
        json,
        'requireReviewedScenarioEvidence',
      ),
      requireManifestPolicyEvidence: _requiredTuningPolicyBool(
        json,
        'requireManifestPolicyEvidence',
      ),
      minBlindedPairwisePreferenceDecisions: _requiredTuningPolicyInt(
        json,
        'minBlindedPairwisePreferenceDecisions',
      ),
      requiredBlindedPairwisePreferenceComparisonKeys:
          _requiredTuningPolicyStringSet(
            json,
            'requiredBlindedPairwisePreferenceComparisonKeys',
          ),
      requiredBlindedPairwisePreferenceIntentKeys:
          _requiredTuningPolicyStringSet(
            json,
            'requiredBlindedPairwisePreferenceIntentKeys',
          ),
      requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey:
          _requiredTuningPolicyOutcomeExpectationMap(
            json,
            'requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey',
          ),
      requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey:
          _requiredTuningPolicyOutcomeExpectationMap(
            json,
            'requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey',
          ),
      blindedPairwisePreferencePolicy: EvalPairwisePreferencePolicy.fromJson(
        _requiredTuningPolicyObject(json, 'blindedPairwisePreferencePolicy'),
      ),
    );
  }

  final String name;
  final Set<EvalModelClass> requiredModelClasses;
  final Set<String> requiredProfileNames;
  final Set<String> requiredPrimaryCapabilityIds;
  final Set<EvalScenarioSplit> requiredSplits;
  final Set<AgentKind> requiredAgentKinds;
  final int minScenarioCount;
  final int minScenariosPerAgentKind;
  final int minScenariosPerCapability;
  final int minScenariosPerRequiredCapabilitySplit;
  final int minCapabilityCount;
  final int minAdversarialScenarioCount;
  final int minAdversarialScenariosPerAgentKind;
  final int minAdversarialScenariosPerCapability;
  final Set<String> requiredAdversarialTags;
  final bool requireAdversarialTagCoveragePerAgentKind;
  final int minProductionReplayHoldoutScenarios;
  final int minProtectedHoldoutScenarios;
  final int minProtectedHoldoutScenariosPerAgentKind;
  final int minProtectedHoldoutScenariosPerRequiredCapability;
  final int minProfilesPerModelClass;
  final int minTrialsPerProfile;
  final bool requireCompleteTraceMatrix;
  final bool requireAllVerdicts;
  final bool requireAllLevel1Passed;
  final bool requireAllJudgePasses;
  final bool requireOutcomeSliceThresholds;
  final double minOutcomeJudgedTraceCoverageRate;
  final double minJudgePassRate;
  final double minJudgePassRateLowerBound;
  final double minMeanGoalAttainment;
  final double minMeanQuality;
  final double minMeanEfficiency;
  final double? maxMeanTokensPerTraceBudgetRatio;
  final double? maxMeanWeightedCostPerTraceBudgetRatio;
  final bool requireWeightedCostEvidence;
  final bool requireCalibratedVerdicts;
  final bool requireBlindedJudgeVerdicts;
  final String? requiredCalibrationSetVersion;
  final String? requiredHumanCalibrationSetVersion;
  final bool requireCalibrationSourceRun;
  final bool requireCalibrationTemplateSelection;
  final bool requireCalibrationReport;
  final int minCalibrationEvaluatedCount;
  final int minCalibrationEvaluatedPerModelClass;
  final int minCalibrationEvaluatedPerCapability;
  final int minCalibrationEvaluatedPerModelClassCapability;
  final int minCalibrationEvaluatedPerPromptVariant;
  final int minCalibrationEvaluatedPerModelClassPromptVariant;
  final bool requireProtectedCalibrationHoldout;
  final int minProtectedCalibrationEvaluatedCount;
  final int minProtectedCalibrationEvaluatedPerModelClass;
  final int minProtectedCalibrationEvaluatedPerCapability;
  final int minProtectedCalibrationEvaluatedPerModelClassCapability;
  final int minProtectedCalibrationEvaluatedPerPromptVariant;
  final int minProtectedCalibrationEvaluatedPerModelClassPromptVariant;
  final double minCalibrationCoverageRate;
  final double minCalibrationCoverageLowerBound;
  final double minCalibrationPassAgreementRate;
  final double minCalibrationPassAgreementPerPromptVariant;
  final double minCalibrationPassAgreementLowerBound;
  final double minCalibrationScoreAgreementRate;
  final double minCalibrationScoreAgreementPerPromptVariant;
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
  final bool requireManifestPolicyEvidence;
  final int minBlindedPairwisePreferenceDecisions;
  final Set<String> requiredBlindedPairwisePreferenceComparisonKeys;
  final Set<String> requiredBlindedPairwisePreferenceIntentKeys;
  final Map<String, EvalPairwiseReadinessOutcomeExpectation>
  requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey;
  final Map<String, EvalPairwiseReadinessOutcomeExpectation>
  requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey;
  final EvalPairwisePreferencePolicy blindedPairwisePreferencePolicy;

  bool get requiresBlindedPairwisePreferences =>
      minBlindedPairwisePreferenceDecisions > 0 ||
      requiredBlindedPairwisePreferenceComparisonKeys.isNotEmpty ||
      requiredBlindedPairwisePreferenceIntentKeys.isNotEmpty ||
      requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey
          .isNotEmpty ||
      requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey
          .isNotEmpty;

  String get policyDigest => EvalProvenance.digestJson(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'requiredModelClasses':
        requiredModelClasses.map((value) => value.name).toList()..sort(),
    'requiredProfileNames': requiredProfileNames.toList()..sort(),
    'requiredPrimaryCapabilityIds': requiredPrimaryCapabilityIds.toList()
      ..sort(),
    'requiredSplits': requiredSplits.map((value) => value.name).toList()
      ..sort(),
    'requiredAgentKinds': requiredAgentKinds.map((value) => value.name).toList()
      ..sort(),
    'minScenarioCount': minScenarioCount,
    'minScenariosPerAgentKind': minScenariosPerAgentKind,
    'minScenariosPerCapability': minScenariosPerCapability,
    'minScenariosPerRequiredCapabilitySplit':
        minScenariosPerRequiredCapabilitySplit,
    'minCapabilityCount': minCapabilityCount,
    'minAdversarialScenarioCount': minAdversarialScenarioCount,
    'minAdversarialScenariosPerAgentKind': minAdversarialScenariosPerAgentKind,
    'minAdversarialScenariosPerCapability':
        minAdversarialScenariosPerCapability,
    'requiredAdversarialTags': requiredAdversarialTags.toList()..sort(),
    'requireAdversarialTagCoveragePerAgentKind':
        requireAdversarialTagCoveragePerAgentKind,
    'minProductionReplayHoldoutScenarios': minProductionReplayHoldoutScenarios,
    'minProtectedHoldoutScenarios': minProtectedHoldoutScenarios,
    'minProtectedHoldoutScenariosPerAgentKind':
        minProtectedHoldoutScenariosPerAgentKind,
    'minProtectedHoldoutScenariosPerRequiredCapability':
        minProtectedHoldoutScenariosPerRequiredCapability,
    'minProfilesPerModelClass': minProfilesPerModelClass,
    'minTrialsPerProfile': minTrialsPerProfile,
    'requireCompleteTraceMatrix': requireCompleteTraceMatrix,
    'requireAllVerdicts': requireAllVerdicts,
    'requireAllLevel1Passed': requireAllLevel1Passed,
    'requireAllJudgePasses': requireAllJudgePasses,
    'requireOutcomeSliceThresholds': requireOutcomeSliceThresholds,
    'minOutcomeJudgedTraceCoverageRate': minOutcomeJudgedTraceCoverageRate,
    'minJudgePassRate': minJudgePassRate,
    'minJudgePassRateLowerBound': minJudgePassRateLowerBound,
    'minMeanGoalAttainment': minMeanGoalAttainment,
    'minMeanQuality': minMeanQuality,
    'minMeanEfficiency': minMeanEfficiency,
    'maxMeanTokensPerTraceBudgetRatio': maxMeanTokensPerTraceBudgetRatio,
    'maxMeanWeightedCostPerTraceBudgetRatio':
        maxMeanWeightedCostPerTraceBudgetRatio,
    'requireWeightedCostEvidence': requireWeightedCostEvidence,
    'requireCalibratedVerdicts': requireCalibratedVerdicts,
    'requireBlindedJudgeVerdicts': requireBlindedJudgeVerdicts,
    'requiredCalibrationSetVersion': requiredCalibrationSetVersion,
    'requiredHumanCalibrationSetVersion': requiredHumanCalibrationSetVersion,
    'requireCalibrationSourceRun': requireCalibrationSourceRun,
    'requireCalibrationTemplateSelection': requireCalibrationTemplateSelection,
    'requireCalibrationReport': requireCalibrationReport,
    'minCalibrationEvaluatedCount': minCalibrationEvaluatedCount,
    'minCalibrationEvaluatedPerModelClass':
        minCalibrationEvaluatedPerModelClass,
    'minCalibrationEvaluatedPerCapability':
        minCalibrationEvaluatedPerCapability,
    'minCalibrationEvaluatedPerModelClassCapability':
        minCalibrationEvaluatedPerModelClassCapability,
    'minCalibrationEvaluatedPerPromptVariant':
        minCalibrationEvaluatedPerPromptVariant,
    'minCalibrationEvaluatedPerModelClassPromptVariant':
        minCalibrationEvaluatedPerModelClassPromptVariant,
    'requireProtectedCalibrationHoldout': requireProtectedCalibrationHoldout,
    'minProtectedCalibrationEvaluatedCount':
        minProtectedCalibrationEvaluatedCount,
    'minProtectedCalibrationEvaluatedPerModelClass':
        minProtectedCalibrationEvaluatedPerModelClass,
    'minProtectedCalibrationEvaluatedPerCapability':
        minProtectedCalibrationEvaluatedPerCapability,
    'minProtectedCalibrationEvaluatedPerModelClassCapability':
        minProtectedCalibrationEvaluatedPerModelClassCapability,
    'minProtectedCalibrationEvaluatedPerPromptVariant':
        minProtectedCalibrationEvaluatedPerPromptVariant,
    'minProtectedCalibrationEvaluatedPerModelClassPromptVariant':
        minProtectedCalibrationEvaluatedPerModelClassPromptVariant,
    'minCalibrationCoverageRate': minCalibrationCoverageRate,
    'minCalibrationCoverageLowerBound': minCalibrationCoverageLowerBound,
    'minCalibrationPassAgreementRate': minCalibrationPassAgreementRate,
    'minCalibrationPassAgreementPerPromptVariant':
        minCalibrationPassAgreementPerPromptVariant,
    'minCalibrationPassAgreementLowerBound':
        minCalibrationPassAgreementLowerBound,
    'minCalibrationScoreAgreementRate': minCalibrationScoreAgreementRate,
    'minCalibrationScoreAgreementPerPromptVariant':
        minCalibrationScoreAgreementPerPromptVariant,
    'minCalibrationScoreAgreementLowerBound':
        minCalibrationScoreAgreementLowerBound,
    'minCalibrationHumanReviewPairCount': minCalibrationHumanReviewPairCount,
    'minCalibrationHumanPassAgreementRate':
        minCalibrationHumanPassAgreementRate,
    'minCalibrationHumanPassAgreementLowerBound':
        minCalibrationHumanPassAgreementLowerBound,
    'minCalibrationHumanScoreAgreementRate':
        minCalibrationHumanScoreAgreementRate,
    'minCalibrationHumanScoreAgreementLowerBound':
        minCalibrationHumanScoreAgreementLowerBound,
    'maxCalibrationUnresolvedHumanDisagreementCount':
        maxCalibrationUnresolvedHumanDisagreementCount,
    'requireBlindedHumanReviews': requireBlindedHumanReviews,
    'maxCalibrationFalsePassCount': maxCalibrationFalsePassCount,
    'maxCalibrationFalsePassRate': maxCalibrationFalsePassRate,
    'maxCalibrationFalseFailRate': maxCalibrationFalseFailRate,
    'requireBlindedCalibrationReport': requireBlindedCalibrationReport,
    'requireCleanCalibrationReport': requireCleanCalibrationReport,
    'requireManifest': requireManifest,
    'requiredTargetKind': requiredTargetKind,
    'expectedScenarioSetDigest': expectedScenarioSetDigest,
    'expectedProfileSetDigest': expectedProfileSetDigest,
    'requireProtectedHoldout': requireProtectedHoldout,
    'requireReviewedScenarioEvidence': requireReviewedScenarioEvidence,
    'requireManifestPolicyEvidence': requireManifestPolicyEvidence,
    'minBlindedPairwisePreferenceDecisions':
        minBlindedPairwisePreferenceDecisions,
    'requiredBlindedPairwisePreferenceComparisonKeys':
        requiredBlindedPairwisePreferenceIntentKeys.isEmpty
        ? (requiredBlindedPairwisePreferenceComparisonKeys.toList()..sort())
        : const <String>[],
    'requiredBlindedPairwisePreferenceIntentKeys':
        requiredBlindedPairwisePreferenceIntentKeys.toList()..sort(),
    'requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey':
        requiredBlindedPairwisePreferenceIntentKeys.isEmpty
        ? _pairwiseOutcomeExpectationsJson(
            requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey,
          )
        : const <String, dynamic>{},
    'requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey':
        _pairwiseOutcomeExpectationsJson(
          requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey,
        ),
    'blindedPairwisePreferencePolicy': blindedPairwisePreferencePolicy.toJson(),
  };

  static Map<String, dynamic> _pairwiseOutcomeExpectationsJson(
    Map<String, EvalPairwiseReadinessOutcomeExpectation> expectations,
  ) => <String, dynamic>{
    for (final key in expectations.keys.toList()..sort())
      key: expectations[key]!.toJson(),
  };
}

void _rejectUnknownTuningPolicyFields(Map<String, dynamic> json) {
  final unknown = json.keys.where(
    (key) => !const {
      'name',
      'requiredModelClasses',
      'requiredProfileNames',
      'requiredPrimaryCapabilityIds',
      'requiredSplits',
      'requiredAgentKinds',
      'minScenarioCount',
      'minScenariosPerAgentKind',
      'minScenariosPerCapability',
      'minScenariosPerRequiredCapabilitySplit',
      'minCapabilityCount',
      'minAdversarialScenarioCount',
      'minAdversarialScenariosPerAgentKind',
      'minAdversarialScenariosPerCapability',
      'requiredAdversarialTags',
      'requireAdversarialTagCoveragePerAgentKind',
      'minProductionReplayHoldoutScenarios',
      'minProtectedHoldoutScenarios',
      'minProtectedHoldoutScenariosPerAgentKind',
      'minProtectedHoldoutScenariosPerRequiredCapability',
      'minProfilesPerModelClass',
      'minTrialsPerProfile',
      'requireCompleteTraceMatrix',
      'requireAllVerdicts',
      'requireAllLevel1Passed',
      'requireAllJudgePasses',
      'requireOutcomeSliceThresholds',
      'minOutcomeJudgedTraceCoverageRate',
      'minJudgePassRate',
      'minJudgePassRateLowerBound',
      'minMeanGoalAttainment',
      'minMeanQuality',
      'minMeanEfficiency',
      'maxMeanTokensPerTraceBudgetRatio',
      'maxMeanWeightedCostPerTraceBudgetRatio',
      'requireWeightedCostEvidence',
      'requireCalibratedVerdicts',
      'requireBlindedJudgeVerdicts',
      'requiredCalibrationSetVersion',
      'requiredHumanCalibrationSetVersion',
      'requireCalibrationSourceRun',
      'requireCalibrationTemplateSelection',
      'requireCalibrationReport',
      'minCalibrationEvaluatedCount',
      'minCalibrationEvaluatedPerModelClass',
      'minCalibrationEvaluatedPerCapability',
      'minCalibrationEvaluatedPerModelClassCapability',
      'minCalibrationEvaluatedPerPromptVariant',
      'minCalibrationEvaluatedPerModelClassPromptVariant',
      'requireProtectedCalibrationHoldout',
      'minProtectedCalibrationEvaluatedCount',
      'minProtectedCalibrationEvaluatedPerModelClass',
      'minProtectedCalibrationEvaluatedPerCapability',
      'minProtectedCalibrationEvaluatedPerModelClassCapability',
      'minProtectedCalibrationEvaluatedPerPromptVariant',
      'minProtectedCalibrationEvaluatedPerModelClassPromptVariant',
      'minCalibrationCoverageRate',
      'minCalibrationCoverageLowerBound',
      'minCalibrationPassAgreementRate',
      'minCalibrationPassAgreementPerPromptVariant',
      'minCalibrationPassAgreementLowerBound',
      'minCalibrationScoreAgreementRate',
      'minCalibrationScoreAgreementPerPromptVariant',
      'minCalibrationScoreAgreementLowerBound',
      'minCalibrationHumanReviewPairCount',
      'minCalibrationHumanPassAgreementRate',
      'minCalibrationHumanPassAgreementLowerBound',
      'minCalibrationHumanScoreAgreementRate',
      'minCalibrationHumanScoreAgreementLowerBound',
      'maxCalibrationUnresolvedHumanDisagreementCount',
      'requireBlindedHumanReviews',
      'maxCalibrationFalsePassCount',
      'maxCalibrationFalsePassRate',
      'maxCalibrationFalseFailRate',
      'requireBlindedCalibrationReport',
      'requireCleanCalibrationReport',
      'requireManifest',
      'requiredTargetKind',
      'expectedScenarioSetDigest',
      'expectedProfileSetDigest',
      'requireProtectedHoldout',
      'requireReviewedScenarioEvidence',
      'requireManifestPolicyEvidence',
      'minBlindedPairwisePreferenceDecisions',
      'requiredBlindedPairwisePreferenceComparisonKeys',
      'requiredBlindedPairwisePreferenceIntentKeys',
      'requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey',
      'requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey',
      'blindedPairwisePreferencePolicy',
    }.contains(key),
  );
  if (unknown.isNotEmpty) {
    throw FormatException(
      'EvalTuningPolicy has unsupported field ${unknown.first}',
    );
  }
}

String _requiredTuningPolicyString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

String? _optionalTuningPolicyString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

Map<String, dynamic> _requiredTuningPolicyObject(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw FormatException('$key must be an object');
}

int _requiredTuningPolicyInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

int? _optionalTuningPolicyInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('$key must be an integer');
}

double _requiredTuningPolicyDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key must be a finite number');
}

double? _optionalTuningPolicyDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('$key must be a finite number');
}

bool _requiredTuningPolicyBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

bool? _optionalTuningPolicyBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

Set<String> _requiredTuningPolicyStringSet(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List<dynamic>) {
    throw FormatException('$key must be a list');
  }
  return {
    for (final item in value)
      if (item is String)
        item
      else
        throw FormatException(
          '$key must contain strings',
        ),
  };
}

Set<T> _requiredTuningPolicyEnumSet<T>(
  Map<String, dynamic> json,
  String key,
  T Function(String name) parse,
) {
  return {
    for (final item in _requiredTuningPolicyStringSet(json, key)) parse(item),
  };
}

Map<String, EvalPairwiseReadinessOutcomeExpectation>
_requiredTuningPolicyOutcomeExpectationMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return {
    for (final entry in value.entries)
      entry.key: EvalPairwiseReadinessOutcomeExpectation.fromJson(
        entry.value as Map<String, dynamic>,
      ),
  };
}

class EvalPairwiseReadinessPlan {
  const EvalPairwiseReadinessPlan({
    required this.planId,
    required this.baseReadinessPolicy,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.profileBindingSetDigest,
    required this.minBlindedPairwisePreferenceDecisions,
    required this.comparisons,
    required this.reviewProtocol,
    required this.importBinding,
    required this.minVotes,
    required this.quorumFraction,
    this.intent,
    this.manifestDigest,
    this.createdAt,
    this.notes,
  });

  factory EvalPairwiseReadinessPlan.fromJson(Map<String, dynamic> json) {
    _rejectUnknownFields(json, 'EvalPairwiseReadinessPlan', {
      'schemaVersion',
      'kind',
      'planId',
      'baseReadinessPolicy',
      'scenarioSetDigest',
      'profileSetDigest',
      'profileBindingSetDigest',
      'manifestDigest',
      'minBlindedPairwisePreferenceDecisions',
      'comparisons',
      'intent',
      'reviewProtocol',
      'importBinding',
      'blindedPairwisePreferencePolicy',
      'createdAt',
      'notes',
    });
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != schemaVersionValue) {
      throw FormatException(
        'Unsupported EvalPairwiseReadinessPlan schemaVersion $schemaVersion '
        '(expected $schemaVersionValue)',
      );
    }
    final kind = _nonEmptyString(json, 'kind');
    if (kind != kindValue) {
      throw FormatException(
        'Unsupported EvalPairwiseReadinessPlan kind "$kind" '
        '(expected $kindValue)',
      );
    }
    final policy = _requiredObject(json, 'blindedPairwisePreferencePolicy');
    _rejectUnknownFields(
      policy,
      'EvalPairwiseReadinessPreferencePolicy',
      {
        'minVotes',
        'quorumFraction',
        'requireModelIdentityBlind',
        'requireProfileBlind',
        'requirePeerVoteBlind',
        'requireTraceOrderRandomized',
        'requireBlindedImport',
      },
    );
    _requireTrue(policy, 'requireModelIdentityBlind');
    _requireTrue(policy, 'requireProfileBlind');
    _requireTrue(policy, 'requirePeerVoteBlind');
    _requireTrue(policy, 'requireTraceOrderRandomized');
    _requireTrue(policy, 'requireBlindedImport');
    final comparisons = _comparisons(json, 'comparisons');
    final minDecisions = _int(
      json,
      'minBlindedPairwisePreferenceDecisions',
    );
    final minVotes = _int(policy, 'minVotes');
    final quorumFraction = _double(policy, 'quorumFraction');
    final plan = EvalPairwiseReadinessPlan(
      planId: _nonEmptyString(json, 'planId'),
      baseReadinessPolicy: _nonEmptyString(json, 'baseReadinessPolicy'),
      scenarioSetDigest: _digest(json, 'scenarioSetDigest'),
      profileSetDigest: _digest(json, 'profileSetDigest'),
      profileBindingSetDigest: _digest(json, 'profileBindingSetDigest'),
      manifestDigest: _optionalDigest(json, 'manifestDigest'),
      minBlindedPairwisePreferenceDecisions: minDecisions,
      comparisons: comparisons,
      intent: json['intent'] == null
          ? null
          : EvalPairwiseReadinessIntent.fromJson(
              _requiredObject(json, 'intent'),
            ),
      reviewProtocol: EvalPairwiseReadinessReviewProtocol.fromJson(
        _requiredObject(json, 'reviewProtocol'),
      ),
      importBinding: EvalPairwiseReadinessImportBinding.fromJson(
        _requiredObject(json, 'importBinding'),
      ),
      minVotes: minVotes,
      quorumFraction: quorumFraction,
      createdAt: _optionalString(json, 'createdAt'),
      notes: _optionalString(json, 'notes'),
    );
    final failures = plan.validate();
    if (failures.isNotEmpty) {
      throw FormatException(failures.join('; '));
    }
    return plan;
  }

  static const schemaVersionValue = 1;
  static const kindValue = 'lotti.evalPairwiseReadinessPlan';

  final String planId;
  final String baseReadinessPolicy;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String profileBindingSetDigest;
  final String? manifestDigest;
  final int minBlindedPairwisePreferenceDecisions;
  final List<EvalPairwiseReadinessComparison> comparisons;
  final EvalPairwiseReadinessReviewProtocol reviewProtocol;
  final EvalPairwiseReadinessImportBinding importBinding;
  final int minVotes;
  final double quorumFraction;
  final EvalPairwiseReadinessIntent? intent;
  final String? createdAt;
  final String? notes;

  Set<String> get requiredComparisonKeys => Set.unmodifiable(
    comparisons.map((comparison) => comparison.comparisonKey),
  );

  Set<String> get requiredComparisonIntentKeys => Set.unmodifiable(
    comparisons.map((comparison) => comparison.intentKey),
  );

  Map<String, String> get reviewPayloadDigestsByComparisonKey =>
      Map.unmodifiable({
        for (final comparison in comparisons)
          comparison.comparisonKey: comparison.reviewPayloadDigest,
      });

  Map<String, EvalPairwiseReadinessComparison> get comparisonsByComparisonKey =>
      Map.unmodifiable({
        for (final comparison in comparisons)
          comparison.comparisonKey: comparison,
      });

  Map<String, EvalPairwiseReadinessOutcomeExpectation>
  get outcomeExpectationsByComparisonKey {
    final expectations = <String, EvalPairwiseReadinessOutcomeExpectation>{};
    for (final comparison in comparisons) {
      final expectation = comparison.outcomeExpectation;
      if (expectation != null) {
        expectations[comparison.comparisonKey] = expectation;
      }
    }
    return Map.unmodifiable(expectations);
  }

  Map<String, EvalPairwiseReadinessOutcomeExpectation>
  get outcomeExpectationsByIntentKey =>
      intent?.outcomeExpectationsByIntentKey ?? const {};

  EvalPairwisePreferencePolicy get preferencePolicy =>
      EvalPairwisePreferencePolicy(
        minVotes: minVotes,
        quorumFraction: quorumFraction,
        requireProfileBlind: true,
        requireTraceOrderRandomized: true,
        requireBlindedImport: true,
      );

  String get reviewProtocolFingerprint => reviewProtocol.fingerprint;

  EvalPairwiseReadinessPlanEvidence toManifestEvidence() =>
      EvalPairwiseReadinessPlanEvidence(
        planId: planId,
        baseReadinessPolicy: baseReadinessPolicy,
        scenarioSetDigest: scenarioSetDigest,
        profileSetDigest: profileSetDigest,
        profileBindingSetDigest: profileBindingSetDigest,
        minBlindedPairwisePreferenceDecisions:
            minBlindedPairwisePreferenceDecisions,
        comparisonCount: comparisons.length,
        pairwiseReadinessPlanSubjectDigest: EvalProvenance.digestJson(
          toIntentSubjectJson(),
        ),
      );

  List<String> validate() {
    final failures = <String>[];
    if (baseReadinessPolicy != 'modelClassTuning') {
      failures.add('baseReadinessPolicy must be modelClassTuning');
    }
    if (minBlindedPairwisePreferenceDecisions < 1) {
      failures.add(
        'minBlindedPairwisePreferenceDecisions must be at least 1',
      );
    }
    if (comparisons.isEmpty) {
      failures.add('comparisons must not be empty');
    }
    if (minBlindedPairwisePreferenceDecisions > comparisons.length) {
      failures.add(
        'minBlindedPairwisePreferenceDecisions cannot exceed '
        'comparisons length ${comparisons.length}',
      );
    }
    for (final issue in preferencePolicy.validate()) {
      failures.add('blindedPairwisePreferencePolicy $issue');
    }
    for (final issue in reviewProtocol.validate()) {
      failures.add('reviewProtocol $issue');
    }
    final comparisonKeys = <String>{};
    final comparisonIntentKeys = <String>{};
    for (final comparison in comparisons) {
      if (!comparisonKeys.add(comparison.comparisonKey)) {
        failures.add(
          'comparisons contains duplicate comparisonKey '
          '${comparison.comparisonKey}',
        );
      }
      if (!comparisonIntentKeys.add(comparison.intentKey)) {
        failures.add(
          'comparisons contains duplicate intentKey ${comparison.intentKey}',
        );
      }
    }
    failures.addAll(
      comparisons.expand((comparison) => comparison.validate()),
    );
    final intent = this.intent;
    if (intent != null) {
      if (intent.planId != planId) {
        failures.add('intent planId must match planId');
      }
      if (intent.baseReadinessPolicy != baseReadinessPolicy) {
        failures.add('intent baseReadinessPolicy must match plan');
      }
      if (intent.scenarioSetDigest != scenarioSetDigest) {
        failures.add('intent scenarioSetDigest must match plan');
      }
      if (intent.profileSetDigest != profileSetDigest) {
        failures.add('intent profileSetDigest must match plan');
      }
      if (intent.profileBindingSetDigest != profileBindingSetDigest) {
        failures.add('intent profileBindingSetDigest must match plan');
      }
      if (intent.minBlindedPairwisePreferenceDecisions !=
          minBlindedPairwisePreferenceDecisions) {
        failures.add(
          'intent minBlindedPairwisePreferenceDecisions must match plan',
        );
      }
      if (intent.reviewProtocol.fingerprint != reviewProtocol.fingerprint) {
        failures.add('intent reviewProtocol must match plan');
      }
      if (intent.minVotes != minVotes ||
          intent.quorumFraction != quorumFraction) {
        failures.add(
          'intent blindedPairwisePreferencePolicy must match plan',
        );
      }
      final intentKeys = intent.requiredComparisonIntentKeys;
      final planKeys = requiredComparisonIntentKeys;
      if (intentKeys.length != planKeys.length ||
          !intentKeys.containsAll(planKeys)) {
        failures.add('intent comparison keys must match plan comparisons');
      }
      final intentComparisons = intent.comparisonsByIntentKey;
      for (final comparison in comparisons) {
        final intentComparison = intentComparisons[comparison.intentKey];
        if (intentComparison == null) continue;
        if (comparison.outcomeExpectation !=
            intentComparison.outcomeExpectation) {
          failures.add(
            'comparison ${comparison.comparisonKey} outcomeExpectation must '
            'match intent ${comparison.intentKey}',
          );
        }
      }
    }
    return failures;
  }

  Map<String, dynamic> toIntentSubjectJson() {
    final intent = this.intent;
    if (intent != null) return intent.toSubjectJson();
    return <String, dynamic>{
      'schemaVersion': EvalPairwiseReadinessIntent.schemaVersionValue,
      'kind': EvalPairwiseReadinessIntent.kindValue,
      'planId': planId,
      'baseReadinessPolicy': baseReadinessPolicy,
      'scenarioSetDigest': scenarioSetDigest,
      'profileSetDigest': profileSetDigest,
      'profileBindingSetDigest': profileBindingSetDigest,
      'minBlindedPairwisePreferenceDecisions':
          minBlindedPairwisePreferenceDecisions,
      'comparisonIntentKeys': requiredComparisonIntentKeys.toList()..sort(),
      'reviewProtocol': reviewProtocol.toJson(),
      'blindedPairwisePreferencePolicy': <String, dynamic>{
        'minVotes': minVotes,
        'quorumFraction': quorumFraction,
        'requireModelIdentityBlind': true,
        'requireProfileBlind': true,
        'requirePeerVoteBlind': true,
        'requireTraceOrderRandomized': true,
        'requireBlindedImport': true,
      },
    };
  }

  Map<String, dynamic> toSubjectJson() => <String, dynamic>{
    'schemaVersion': schemaVersionValue,
    'kind': kindValue,
    'planId': planId,
    'baseReadinessPolicy': baseReadinessPolicy,
    'scenarioSetDigest': scenarioSetDigest,
    'profileSetDigest': profileSetDigest,
    'profileBindingSetDigest': profileBindingSetDigest,
    'minBlindedPairwisePreferenceDecisions':
        minBlindedPairwisePreferenceDecisions,
    'comparisons': [
      for (final comparison in [
        ...comparisons,
      ]..sort((a, b) => a.comparisonKey.compareTo(b.comparisonKey)))
        comparison.toJson(),
    ],
    if (intent != null) 'intent': intent!.toJson(),
    'reviewProtocol': reviewProtocol.toJson(),
    'importBinding': importBinding.toJson(),
    'blindedPairwisePreferencePolicy': <String, dynamic>{
      'minVotes': minVotes,
      'quorumFraction': quorumFraction,
      'requireModelIdentityBlind': true,
      'requireProfileBlind': true,
      'requirePeerVoteBlind': true,
      'requireTraceOrderRandomized': true,
      'requireBlindedImport': true,
    },
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...toSubjectJson(),
    if (manifestDigest != null) 'manifestDigest': manifestDigest,
    if (createdAt != null) 'createdAt': createdAt,
    if (notes != null) 'notes': notes,
  };

  static String _nonEmptyString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string');
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a non-empty string when present');
    }
    return value.trim();
  }

  static String _digest(Map<String, dynamic> json, String field) {
    final value = _nonEmptyString(json, field);
    if (!EvalProvenance.isDigest(value)) {
      throw FormatException('$field must be a sha256 digest');
    }
    return value;
  }

  static String? _optionalDigest(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return null;
    final digest = _nonEmptyString(json, field);
    if (!EvalProvenance.isDigest(digest)) {
      throw FormatException('$field must be a sha256 digest');
    }
    return digest;
  }

  static int _int(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw FormatException('$field must be an integer');
    }
    return value.toInt();
  }

  static double _double(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! num || !value.isFinite) {
      throw FormatException('$field must be a finite number');
    }
    return value.toDouble();
  }

  static Map<String, dynamic>? _object(
    Map<String, dynamic> json,
    String field,
  ) {
    final value = json[field];
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw FormatException('$field must be an object when present');
    }
    return value;
  }

  static Map<String, dynamic> _requiredObject(
    Map<String, dynamic> json,
    String field,
  ) {
    final value = _object(json, field);
    if (value == null) {
      throw FormatException('$field must be an object');
    }
    return value;
  }

  static void _requireTrue(Map<String, dynamic> json, String field) {
    if (json[field] != true) {
      throw FormatException('$field must be true');
    }
  }

  static List<EvalPairwiseReadinessComparison> _comparisons(
    Map<String, dynamic> json,
    String field,
  ) {
    final value = json[field];
    if (value is! List<dynamic>) {
      throw FormatException('$field must be a list of objects');
    }
    final keys = <String>{};
    final intentKeys = <String>{};
    final comparisons = <EvalPairwiseReadinessComparison>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$field must contain only objects');
      }
      final comparison = EvalPairwiseReadinessComparison.fromJson(item);
      if (!keys.add(comparison.comparisonKey)) {
        throw FormatException(
          '$field contains duplicate comparisonKey '
          '${comparison.comparisonKey}',
        );
      }
      if (!intentKeys.add(comparison.intentKey)) {
        throw FormatException(
          '$field contains duplicate intentKey ${comparison.intentKey}',
        );
      }
      comparisons.add(comparison);
    }
    return List.unmodifiable(comparisons);
  }

  static void _rejectUnknownFields(
    Map<String, dynamic> json,
    String objectName,
    Set<String> allowedFields,
  ) {
    for (final key in json.keys) {
      if (!allowedFields.contains(key)) {
        throw FormatException('$objectName contains unsupported field $key');
      }
    }
  }
}

class EvalPairwiseReadinessComparison {
  const EvalPairwiseReadinessComparison({
    required this.comparisonKey,
    required this.reviewPayloadDigest,
    required this.intentKey,
    this.outcomeExpectation,
  });

  factory EvalPairwiseReadinessComparison.fromJson(Map<String, dynamic> json) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessComparison',
      {
        'comparisonKey',
        'reviewPayloadDigest',
        'intentKey',
        'outcomeExpectation',
      },
    );
    final comparisonKey = EvalPairwiseReadinessPlan._nonEmptyString(
      json,
      'comparisonKey',
    );
    return EvalPairwiseReadinessComparison(
      comparisonKey: comparisonKey,
      reviewPayloadDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'reviewPayloadDigest',
      ),
      intentKey: json['intentKey'] == null
          ? comparisonKey
          : EvalPairwiseReadinessPlan._nonEmptyString(json, 'intentKey'),
      outcomeExpectation: json['outcomeExpectation'] == null
          ? null
          : EvalPairwiseReadinessOutcomeExpectation.fromJson(
              EvalPairwiseReadinessPlan._requiredObject(
                json,
                'outcomeExpectation',
              ),
            ),
    );
  }

  final String comparisonKey;
  final String reviewPayloadDigest;
  final String intentKey;
  final EvalPairwiseReadinessOutcomeExpectation? outcomeExpectation;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'comparisonKey': comparisonKey,
    'intentKey': intentKey,
    'reviewPayloadDigest': reviewPayloadDigest,
    if (outcomeExpectation != null)
      'outcomeExpectation': outcomeExpectation!.toJson(),
  };

  List<String> validate() {
    final failures = <String>[];
    if (comparisonKey.trim().isEmpty) {
      failures.add('comparisonKey must be non-empty');
    }
    if (intentKey.trim().isEmpty) {
      failures.add('intentKey must be non-empty');
    }
    if (!EvalProvenance.isDigest(reviewPayloadDigest)) {
      failures.add('reviewPayloadDigest must be a sha256 digest');
    }
    final outcomeExpectation = this.outcomeExpectation;
    if (outcomeExpectation != null) {
      for (final issue in outcomeExpectation.validate()) {
        failures.add('outcomeExpectation $issue');
      }
    }
    return failures;
  }
}

class EvalPairwiseReadinessReviewProtocol {
  const EvalPairwiseReadinessReviewProtocol({
    required this.reviewerKind,
    required this.reviewerModel,
    required this.promptDigest,
    required this.calibrationSetVersion,
    required this.profileVisible,
    required this.modelIdentityVisible,
    required this.peerVotesVisible,
    required this.traceOrderRandomized,
  });

  factory EvalPairwiseReadinessReviewProtocol.fromJson(
    Map<String, dynamic> json,
  ) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessReviewProtocol',
      {
        'reviewerKind',
        'reviewerModel',
        'promptDigest',
        'calibrationSetVersion',
        'profileVisible',
        'modelIdentityVisible',
        'peerVotesVisible',
        'traceOrderRandomized',
      },
    );
    final reviewerModelValue = json['reviewerModel'];
    if (reviewerModelValue != null &&
        (reviewerModelValue is! String || reviewerModelValue.trim().isEmpty)) {
      throw const FormatException(
        'reviewerModel must be null or a non-empty string',
      );
    }
    final reviewerModel = (reviewerModelValue as String?)?.trim();
    return EvalPairwiseReadinessReviewProtocol(
      reviewerKind: EvalPairwiseReviewerKind.fromName(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'reviewerKind'),
      ),
      reviewerModel: reviewerModel,
      promptDigest: EvalPairwiseReadinessPlan._digest(json, 'promptDigest'),
      calibrationSetVersion: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'calibrationSetVersion',
      ),
      profileVisible: _bool(json, 'profileVisible'),
      modelIdentityVisible: _bool(json, 'modelIdentityVisible'),
      peerVotesVisible: _bool(json, 'peerVotesVisible'),
      traceOrderRandomized: _bool(json, 'traceOrderRandomized'),
    );
  }

  final EvalPairwiseReviewerKind reviewerKind;
  final String? reviewerModel;
  final String promptDigest;
  final String calibrationSetVersion;
  final bool profileVisible;
  final bool modelIdentityVisible;
  final bool peerVotesVisible;
  final bool traceOrderRandomized;

  String get fingerprint => [
    'kind=${reviewerKind.name}',
    'model=${reviewerModel ?? ''}',
    'prompt=$promptDigest',
    'calibration=$calibrationSetVersion',
    'profileVisible=$profileVisible',
    'modelIdentityVisible=$modelIdentityVisible',
    'peerVotesVisible=$peerVotesVisible',
    'traceOrderRandomized=$traceOrderRandomized',
  ].join('|');

  List<String> validate() {
    final failures = <String>[];
    if (profileVisible) {
      failures.add('profileVisible must be false');
    }
    if (modelIdentityVisible) {
      failures.add('modelIdentityVisible must be false');
    }
    if (peerVotesVisible) {
      failures.add('peerVotesVisible must be false');
    }
    if (!traceOrderRandomized) {
      failures.add('traceOrderRandomized must be true');
    }
    return failures;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'reviewerKind': reviewerKind.name,
    'reviewerModel': reviewerModel,
    'promptDigest': promptDigest,
    'calibrationSetVersion': calibrationSetVersion,
    'profileVisible': profileVisible,
    'modelIdentityVisible': modelIdentityVisible,
    'peerVotesVisible': peerVotesVisible,
    'traceOrderRandomized': traceOrderRandomized,
  };

  static bool _bool(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is! bool) {
      throw FormatException('$field must be a boolean');
    }
    return value;
  }
}

class EvalPairwiseReadinessImportBinding {
  const EvalPairwiseReadinessImportBinding({
    required this.judgeManifestDigest,
    required this.privateKeyDigest,
  });

  factory EvalPairwiseReadinessImportBinding.fromJson(
    Map<String, dynamic> json,
  ) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessImportBinding',
      {'judgeManifestDigest', 'privateKeyDigest'},
    );
    return EvalPairwiseReadinessImportBinding(
      judgeManifestDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'judgeManifestDigest',
      ),
      privateKeyDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'privateKeyDigest',
      ),
    );
  }

  final String judgeManifestDigest;
  final String privateKeyDigest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'judgeManifestDigest': judgeManifestDigest,
    'privateKeyDigest': privateKeyDigest,
  };
}

class EvalPairwiseReadinessIntent {
  const EvalPairwiseReadinessIntent({
    required this.planId,
    required this.baseReadinessPolicy,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.profileBindingSetDigest,
    required this.agentDirectiveVariantSetDigest,
    required this.minBlindedPairwisePreferenceDecisions,
    required this.comparisons,
    required this.reviewProtocol,
    required this.minVotes,
    required this.quorumFraction,
    this.createdAt,
    this.notes,
  });

  factory EvalPairwiseReadinessIntent.fromJson(Map<String, dynamic> json) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessIntent',
      {
        'schemaVersion',
        'kind',
        'planId',
        'baseReadinessPolicy',
        'scenarioSetDigest',
        'profileSetDigest',
        'profileBindingSetDigest',
        'agentDirectiveVariantSetDigest',
        'minBlindedPairwisePreferenceDecisions',
        'comparisons',
        'reviewProtocol',
        'blindedPairwisePreferencePolicy',
        'createdAt',
        'notes',
      },
    );
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != schemaVersionValue) {
      throw FormatException(
        'Unsupported EvalPairwiseReadinessIntent schemaVersion '
        '$schemaVersion (expected $schemaVersionValue)',
      );
    }
    final kind = EvalPairwiseReadinessPlan._nonEmptyString(json, 'kind');
    if (kind != kindValue) {
      throw FormatException(
        'Unsupported EvalPairwiseReadinessIntent kind "$kind" '
        '(expected $kindValue)',
      );
    }
    final policy = EvalPairwiseReadinessPlan._requiredObject(
      json,
      'blindedPairwisePreferencePolicy',
    );
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      policy,
      'EvalPairwiseReadinessIntentPreferencePolicy',
      {
        'minVotes',
        'quorumFraction',
        'requireModelIdentityBlind',
        'requireProfileBlind',
        'requirePeerVoteBlind',
        'requireTraceOrderRandomized',
        'requireBlindedImport',
      },
    );
    EvalPairwiseReadinessPlan._requireTrue(
      policy,
      'requireModelIdentityBlind',
    );
    EvalPairwiseReadinessPlan._requireTrue(policy, 'requireProfileBlind');
    EvalPairwiseReadinessPlan._requireTrue(policy, 'requirePeerVoteBlind');
    EvalPairwiseReadinessPlan._requireTrue(
      policy,
      'requireTraceOrderRandomized',
    );
    EvalPairwiseReadinessPlan._requireTrue(policy, 'requireBlindedImport');
    final intent = EvalPairwiseReadinessIntent(
      planId: EvalPairwiseReadinessPlan._nonEmptyString(json, 'planId'),
      baseReadinessPolicy: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'baseReadinessPolicy',
      ),
      scenarioSetDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'scenarioSetDigest',
      ),
      profileSetDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'profileSetDigest',
      ),
      profileBindingSetDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'profileBindingSetDigest',
      ),
      agentDirectiveVariantSetDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'agentDirectiveVariantSetDigest',
      ),
      minBlindedPairwisePreferenceDecisions: EvalPairwiseReadinessPlan._int(
        json,
        'minBlindedPairwisePreferenceDecisions',
      ),
      comparisons: _comparisons(json),
      reviewProtocol: EvalPairwiseReadinessReviewProtocol.fromJson(
        EvalPairwiseReadinessPlan._requiredObject(json, 'reviewProtocol'),
      ),
      minVotes: EvalPairwiseReadinessPlan._int(policy, 'minVotes'),
      quorumFraction: EvalPairwiseReadinessPlan._double(
        policy,
        'quorumFraction',
      ),
      createdAt: EvalPairwiseReadinessPlan._optionalString(json, 'createdAt'),
      notes: EvalPairwiseReadinessPlan._optionalString(json, 'notes'),
    );
    final failures = intent.validate();
    if (failures.isNotEmpty) {
      throw FormatException(failures.join('; '));
    }
    return intent;
  }

  static const schemaVersionValue = 1;
  static const kindValue = 'lotti.evalPairwiseReadinessIntent';

  final String planId;
  final String baseReadinessPolicy;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String profileBindingSetDigest;
  final String agentDirectiveVariantSetDigest;
  final int minBlindedPairwisePreferenceDecisions;
  final List<EvalPairwiseReadinessIntentComparison> comparisons;
  final EvalPairwiseReadinessReviewProtocol reviewProtocol;
  final int minVotes;
  final double quorumFraction;
  final String? createdAt;
  final String? notes;

  Set<String> get requiredComparisonIntentKeys =>
      Set.unmodifiable(comparisons.map((comparison) => comparison.intentKey));

  Map<String, EvalPairwiseReadinessIntentComparison>
  get comparisonsByIntentKey => Map.unmodifiable({
    for (final comparison in comparisons) comparison.intentKey: comparison,
  });

  Map<String, EvalPairwiseReadinessOutcomeExpectation>
  get outcomeExpectationsByIntentKey => Map.unmodifiable({
    for (final comparison in comparisons)
      comparison.intentKey: comparison.outcomeExpectation,
  });

  EvalPairwisePreferencePolicy get preferencePolicy =>
      EvalPairwisePreferencePolicy(
        minVotes: minVotes,
        quorumFraction: quorumFraction,
        requireProfileBlind: true,
        requireTraceOrderRandomized: true,
        requireBlindedImport: true,
      );

  EvalPairwiseReadinessPlanEvidence toManifestEvidence() =>
      EvalPairwiseReadinessPlanEvidence(
        planId: planId,
        baseReadinessPolicy: baseReadinessPolicy,
        scenarioSetDigest: scenarioSetDigest,
        profileSetDigest: profileSetDigest,
        profileBindingSetDigest: profileBindingSetDigest,
        minBlindedPairwisePreferenceDecisions:
            minBlindedPairwisePreferenceDecisions,
        comparisonCount: comparisons.length,
        pairwiseReadinessPlanSubjectDigest: EvalProvenance.digestJson(
          toSubjectJson(),
        ),
      );

  List<String> validate() {
    final failures = <String>[];
    if (baseReadinessPolicy != 'modelClassTuning') {
      failures.add('baseReadinessPolicy must be modelClassTuning');
    }
    if (minBlindedPairwisePreferenceDecisions < 1) {
      failures.add(
        'minBlindedPairwisePreferenceDecisions must be at least 1',
      );
    }
    if (comparisons.isEmpty) {
      failures.add('comparisons must not be empty');
    }
    if (minBlindedPairwisePreferenceDecisions > comparisons.length) {
      failures.add(
        'minBlindedPairwisePreferenceDecisions cannot exceed '
        'comparisons length ${comparisons.length}',
      );
    }
    for (final issue in preferencePolicy.validate()) {
      failures.add('blindedPairwisePreferencePolicy $issue');
    }
    for (final issue in reviewProtocol.validate()) {
      failures.add('reviewProtocol $issue');
    }
    failures.addAll(
      comparisons.expand((comparison) => comparison.validate()),
    );
    final pairIds = <String>{};
    final optionPairKeys = <String>{};
    for (final comparison in comparisons) {
      if (!pairIds.add(comparison.pairId)) {
        failures.add(
          'comparisons contains duplicate pairId ${comparison.pairId}',
        );
      }
      if (!optionPairKeys.add(comparison.optionPairKey)) {
        failures.add(
          'comparisons contains duplicate option pair ${comparison.intentKey}',
        );
      }
    }
    return failures;
  }

  Map<String, dynamic> toSubjectJson() => <String, dynamic>{
    'schemaVersion': schemaVersionValue,
    'kind': kindValue,
    'planId': planId,
    'baseReadinessPolicy': baseReadinessPolicy,
    'scenarioSetDigest': scenarioSetDigest,
    'profileSetDigest': profileSetDigest,
    'profileBindingSetDigest': profileBindingSetDigest,
    'agentDirectiveVariantSetDigest': agentDirectiveVariantSetDigest,
    'minBlindedPairwisePreferenceDecisions':
        minBlindedPairwisePreferenceDecisions,
    'comparisons': [
      for (final comparison in [
        ...comparisons,
      ]..sort((a, b) => a.intentKey.compareTo(b.intentKey)))
        comparison.toJson(),
    ],
    'reviewProtocol': reviewProtocol.toJson(),
    'blindedPairwisePreferencePolicy': <String, dynamic>{
      'minVotes': minVotes,
      'quorumFraction': quorumFraction,
      'requireModelIdentityBlind': true,
      'requireProfileBlind': true,
      'requirePeerVoteBlind': true,
      'requireTraceOrderRandomized': true,
      'requireBlindedImport': true,
    },
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...toSubjectJson(),
    if (createdAt != null) 'createdAt': createdAt,
    if (notes != null) 'notes': notes,
  };

  static List<EvalPairwiseReadinessIntentComparison> _comparisons(
    Map<String, dynamic> json,
  ) {
    final value = json['comparisons'];
    if (value is! List<dynamic>) {
      throw const FormatException('comparisons must be a list');
    }
    final keys = <String>{};
    final comparisons = <EvalPairwiseReadinessIntentComparison>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('comparisons must contain only objects');
      }
      final comparison = EvalPairwiseReadinessIntentComparison.fromJson(item);
      if (!keys.add(comparison.intentKey)) {
        throw FormatException(
          'comparisons contains duplicate intentKey ${comparison.intentKey}',
        );
      }
      comparisons.add(comparison);
    }
    return List.unmodifiable(comparisons);
  }
}

class EvalPairwiseReadinessIntentComparison {
  const EvalPairwiseReadinessIntentComparison({
    required this.pairId,
    required this.intentKey,
    required this.axis,
    required this.scenarioId,
    required this.scenarioDigest,
    required this.agentKind,
    required this.capabilityId,
    required this.trialIndex,
    required this.optionA,
    required this.optionB,
    required this.preferredOption,
    required this.outcomeRequirement,
    this.cascadeWake,
  });

  factory EvalPairwiseReadinessIntentComparison.fromJson(
    Map<String, dynamic> json,
  ) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessIntentComparison',
      {
        'pairId',
        'intentKey',
        'axis',
        'scenarioId',
        'scenarioDigest',
        'agentKind',
        'capabilityId',
        'trialIndex',
        'cascadeWake',
        'optionA',
        'optionB',
        'preferredOption',
        'outcomeRequirement',
      },
    );
    return EvalPairwiseReadinessIntentComparison(
      pairId: EvalPairwiseReadinessPlan._nonEmptyString(json, 'pairId'),
      intentKey: EvalPairwiseReadinessPlan._nonEmptyString(json, 'intentKey'),
      axis: _axis(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'axis'),
      ),
      scenarioId: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'scenarioId',
      ),
      scenarioDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'scenarioDigest',
      ),
      agentKind: AgentKind.fromName(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'agentKind'),
      ),
      capabilityId: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'capabilityId',
      ),
      trialIndex: EvalPairwiseReadinessPlan._int(json, 'trialIndex'),
      cascadeWake: json['cascadeWake'] == null
          ? null
          : EvalTraceCascadeWake.fromJson(
              EvalPairwiseReadinessPlan._requiredObject(json, 'cascadeWake'),
            ),
      optionA: EvalPairwiseReadinessIntentOption.fromJson(
        EvalPairwiseReadinessPlan._requiredObject(json, 'optionA'),
      ),
      optionB: EvalPairwiseReadinessIntentOption.fromJson(
        EvalPairwiseReadinessPlan._requiredObject(json, 'optionB'),
      ),
      preferredOption: EvalPairwiseReadinessPreferredOption.fromName(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'preferredOption'),
      ),
      outcomeRequirement: EvalPairwiseReadinessOutcomeRequirement.fromName(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'outcomeRequirement'),
      ),
    );
  }

  final String pairId;
  final String intentKey;
  final EvalPairwiseComparisonAxis axis;
  final String scenarioId;
  final String scenarioDigest;
  final AgentKind agentKind;
  final String capabilityId;
  final int trialIndex;
  final EvalTraceCascadeWake? cascadeWake;
  final EvalPairwiseReadinessIntentOption optionA;
  final EvalPairwiseReadinessIntentOption optionB;
  final EvalPairwiseReadinessPreferredOption preferredOption;
  final EvalPairwiseReadinessOutcomeRequirement outcomeRequirement;

  EvalPairwiseReadinessIntentOption get preferredIntentOption =>
      preferredOption == EvalPairwiseReadinessPreferredOption.optionA
      ? optionA
      : optionB;

  EvalPairwiseReadinessOutcomeExpectation get outcomeExpectation =>
      EvalPairwiseReadinessOutcomeExpectation(
        preferredOptionKey: preferredIntentOption.intentKey,
        requirement: outcomeRequirement,
      );

  List<String> validate() {
    final failures = <String>[];
    final profileDiffers = optionA.profileName != optionB.profileName;
    final variantDiffers =
        optionA.agentDirectiveVariantName != optionB.agentDirectiveVariantName;
    final expectedAxis = profileDiffers && !variantDiffers
        ? EvalPairwiseComparisonAxis.profile
        : !profileDiffers && variantDiffers
        ? EvalPairwiseComparisonAxis.promptVariant
        : EvalPairwiseComparisonAxis.invalid;
    if (axis != expectedAxis || axis == EvalPairwiseComparisonAxis.invalid) {
      failures.add('comparison $intentKey has invalid axis ${axis.name}');
    }
    if (optionA.intentKey == optionB.intentKey) {
      failures.add('comparison $intentKey compares the same option twice');
    }
    failures.addAll(
      outcomeExpectation.validate().map(
        (issue) => 'comparison $intentKey outcomeExpectation $issue',
      ),
    );
    return failures;
  }

  String get optionPairKey {
    final optionKeys = [
      optionA.intentKey,
      optionB.intentKey,
    ]..sort();
    final wakeKey = cascadeWake == null
        ? ''
        : jsonEncode(cascadeWake!.toJson());
    return [
      axis.name,
      scenarioId,
      scenarioDigest,
      agentKind.name,
      capabilityId,
      trialIndex.toString(),
      wakeKey,
      ...optionKeys,
    ].join('|');
  }

  List<String> validateTraceRefs({
    required EvalPairwiseTraceRef optionA,
    required EvalPairwiseTraceRef optionB,
  }) {
    final failures = <String>[];
    final axis = _axisFromTraceRefs(optionA, optionB);
    if (axis != this.axis) {
      failures.add('axis ${axis.name} does not match intent ${this.axis.name}');
    }

    void checkShared(EvalPairwiseTraceRef ref, String label) {
      if (ref.scenarioId != scenarioId) {
        failures.add(
          '$label scenarioId ${ref.scenarioId} does not match intent',
        );
      }
      if (ref.scenarioDigest != scenarioDigest) {
        failures.add(
          '$label scenarioDigest ${ref.scenarioDigest} does not match intent',
        );
      }
      if (ref.agentKind != agentKind) {
        failures.add(
          '$label agentKind ${ref.agentKind.name} does not match intent',
        );
      }
      if (ref.capabilityId != capabilityId) {
        failures.add(
          '$label capabilityId ${ref.capabilityId} does not match intent',
        );
      }
      if (ref.trialIndex != trialIndex) {
        failures.add(
          '$label trialIndex ${ref.trialIndex} does not match intent',
        );
      }
      if (!_sameCascadeWake(ref.cascadeWake, cascadeWake)) {
        failures.add('$label cascadeWake does not match intent');
      }
    }

    checkShared(optionA, 'optionA');
    checkShared(optionB, 'optionB');
    final forward =
        this.optionA.matchesTraceRef(optionA) &&
        this.optionB.matchesTraceRef(optionB);
    final swapped =
        this.optionA.matchesTraceRef(optionB) &&
        this.optionB.matchesTraceRef(optionA);
    if (!forward && !swapped) {
      failures.add('options do not match intent');
    }
    return failures;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pairId': pairId,
    'intentKey': intentKey,
    'axis': axis.name,
    'scenarioId': scenarioId,
    'scenarioDigest': scenarioDigest,
    'agentKind': agentKind.name,
    'capabilityId': capabilityId,
    'trialIndex': trialIndex,
    if (cascadeWake != null) 'cascadeWake': cascadeWake!.toJson(),
    'optionA': optionA.toJson(),
    'optionB': optionB.toJson(),
    'preferredOption': preferredOption.name,
    'outcomeRequirement': outcomeRequirement.name,
  };

  static EvalPairwiseComparisonAxis _axis(String name) {
    for (final value in EvalPairwiseComparisonAxis.values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unsupported pairwise intent axis $name');
  }

  static EvalPairwiseComparisonAxis _axisFromTraceRefs(
    EvalPairwiseTraceRef optionA,
    EvalPairwiseTraceRef optionB,
  ) {
    final profileDiffers = optionA.profileName != optionB.profileName;
    final variantDiffers =
        optionA.agentDirectiveVariantName != optionB.agentDirectiveVariantName;
    if (profileDiffers && !variantDiffers) {
      return EvalPairwiseComparisonAxis.profile;
    }
    if (!profileDiffers && variantDiffers) {
      return EvalPairwiseComparisonAxis.promptVariant;
    }
    return EvalPairwiseComparisonAxis.invalid;
  }

  static bool _sameCascadeWake(
    EvalTraceCascadeWake? left,
    EvalTraceCascadeWake? right,
  ) {
    if (left == null || right == null) return left == null && right == null;
    return const DeepCollectionEquality().equals(left.toJson(), right.toJson());
  }
}

class EvalPairwiseReadinessIntentOption {
  const EvalPairwiseReadinessIntentOption({
    required this.profileName,
    required this.profileDigest,
    required this.modelClass,
    required this.agentDirectiveVariantName,
    required this.agentDirectiveVariantDigest,
  });

  factory EvalPairwiseReadinessIntentOption.fromJson(
    Map<String, dynamic> json,
  ) {
    EvalPairwiseReadinessPlan._rejectUnknownFields(
      json,
      'EvalPairwiseReadinessIntentOption',
      {
        'profileName',
        'profileDigest',
        'modelClass',
        'agentDirectiveVariantName',
        'agentDirectiveVariantDigest',
      },
    );
    return EvalPairwiseReadinessIntentOption(
      profileName: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'profileName',
      ),
      profileDigest: EvalPairwiseReadinessPlan._digest(json, 'profileDigest'),
      modelClass: EvalModelClass.fromName(
        EvalPairwiseReadinessPlan._nonEmptyString(json, 'modelClass'),
      ),
      agentDirectiveVariantName: EvalPairwiseReadinessPlan._nonEmptyString(
        json,
        'agentDirectiveVariantName',
      ),
      agentDirectiveVariantDigest: EvalPairwiseReadinessPlan._digest(
        json,
        'agentDirectiveVariantDigest',
      ),
    );
  }

  final String profileName;
  final String profileDigest;
  final EvalModelClass modelClass;
  final String agentDirectiveVariantName;
  final String agentDirectiveVariantDigest;

  String get intentKey =>
      '$profileName::$profileDigest::prompt-$agentDirectiveVariantName::'
      '$agentDirectiveVariantDigest';

  bool matchesTraceRef(EvalPairwiseTraceRef ref) =>
      profileName == ref.profileName &&
      profileDigest == ref.profileDigest &&
      modelClass == ref.modelClass &&
      agentDirectiveVariantName == ref.agentDirectiveVariantName &&
      agentDirectiveVariantDigest == ref.agentDirectiveVariantDigest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profileName': profileName,
    'profileDigest': profileDigest,
    'modelClass': modelClass.name,
    'agentDirectiveVariantName': agentDirectiveVariantName,
    'agentDirectiveVariantDigest': agentDirectiveVariantDigest,
  };
}

String _pairwiseIntentOptionKeyForTraceRef(EvalPairwiseTraceRef ref) =>
    '${ref.profileName}::${ref.profileDigest}::prompt-'
    '${ref.agentDirectiveVariantName}::${ref.agentDirectiveVariantDigest}';

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
    required this.outcomeQualityEvidence,
    required this.pairwisePreferenceEvidence,
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
  final EvalOutcomeQualityEvidence? outcomeQualityEvidence;
  final EvalPairwisePreferenceReadinessEvidence? pairwisePreferenceEvidence;
  final List<String> failures;
  final List<String> warnings;

  bool get ready => failures.isEmpty;

  String get policyDigest => policy.policyDigest;

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

  String get policyDigest => policy.policyDigest;

  String get evidenceLabel => ready ? 'catalog-ready' : 'catalog-blocked';
}

class EvalTuningReadinessEvidence {
  const EvalTuningReadinessEvidence({
    required this.scenarioCountByAgentKind,
    required this.scenarioCountBySplit,
    required this.scenarioCountByPrimaryCapability,
    required this.scenarioCountByPrimaryCapabilitySplit,
    required this.missingRequiredPrimaryCapabilityIds,
    required this.missingRequiredCapabilitySplitCells,
    required this.profileCountByModelClass,
    required this.minObservedTrialCount,
    required this.maxObservedTrialCount,
    required this.profilesBelowMinTrialCount,
    required this.adversarialScenarioCount,
    required this.adversarialScenarioCountByAgentKind,
    required this.adversarialScenarioCountByPrimaryCapability,
    required this.adversarialStressTagCountByAgentKind,
    required this.adversarialTags,
    required this.missingAdversarialTags,
    required this.missingAdversarialStressTagAgentKindCells,
    required this.productionReplayHoldoutScenarioCount,
    required this.protectedHoldoutScenarioCount,
    required this.protectedHoldoutScenarioCountByAgentKind,
    required this.protectedHoldoutScenarioCountByPrimaryCapability,
    required this.missingProtectedHoldoutPrimaryCapabilityIds,
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
  final Map<String, int> scenarioCountByPrimaryCapabilitySplit;
  final Set<String> missingRequiredPrimaryCapabilityIds;
  final Set<String> missingRequiredCapabilitySplitCells;
  final Map<EvalModelClass, int> profileCountByModelClass;
  final int minObservedTrialCount;
  final int maxObservedTrialCount;
  final Map<String, int> profilesBelowMinTrialCount;
  final int adversarialScenarioCount;
  final Map<AgentKind, int> adversarialScenarioCountByAgentKind;
  final Map<String, int> adversarialScenarioCountByPrimaryCapability;
  final Map<String, int> adversarialStressTagCountByAgentKind;
  final Set<String> adversarialTags;
  final Set<String> missingAdversarialTags;
  final Set<String> missingAdversarialStressTagAgentKindCells;
  final int productionReplayHoldoutScenarioCount;
  final int protectedHoldoutScenarioCount;
  final Map<AgentKind, int> protectedHoldoutScenarioCountByAgentKind;
  final Map<String, int> protectedHoldoutScenarioCountByPrimaryCapability;
  final Set<String> missingProtectedHoldoutPrimaryCapabilityIds;
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

class EvalOutcomeQualityEvidence {
  const EvalOutcomeQualityEvidence({
    required this.expectedTraceCount,
    required this.judgedTraceCount,
    required this.passTraceCount,
    required this.expectedSliceCount,
    required this.judgedSliceCount,
    required this.passRateEstimate,
    required this.meanGoalAttainment,
    required this.meanQuality,
    required this.meanEfficiency,
    required this.meanTokenBudgetRatio,
    required this.weightedCostTraceCount,
    required this.missingWeightedCostTraceCount,
    required this.meanWeightedCostBudgetRatio,
  });

  final int expectedTraceCount;
  final int judgedTraceCount;
  final int passTraceCount;
  final int expectedSliceCount;
  final int judgedSliceCount;
  final RateEstimate passRateEstimate;
  final double meanGoalAttainment;
  final double meanQuality;
  final double meanEfficiency;
  final double meanTokenBudgetRatio;
  final int weightedCostTraceCount;
  final int missingWeightedCostTraceCount;
  final double meanWeightedCostBudgetRatio;

  double get judgedTraceCoverageRate =>
      expectedTraceCount == 0 ? 0 : judgedTraceCount / expectedTraceCount;
}

class EvalPairwisePreferenceReadinessEvidence {
  const EvalPairwisePreferenceReadinessEvidence({
    required this.voteCount,
    required this.pairCount,
    required this.decisionCount,
    required this.invalidCount,
    required this.incompleteCount,
    required this.noConsensusCount,
    required this.outcomeExpectationCount,
    required this.satisfiedOutcomeCount,
    required this.failedOutcomeComparisonKeys,
    required this.requiredComparisonKeys,
    required this.missingRequiredComparisonKeys,
    required this.unregisteredComparisonKeys,
    required this.reviewProtocolKeys,
    required this.summaries,
  });

  final int voteCount;
  final int pairCount;
  final int decisionCount;
  final int invalidCount;
  final int incompleteCount;
  final int noConsensusCount;
  final int outcomeExpectationCount;
  final int satisfiedOutcomeCount;
  final Set<String> failedOutcomeComparisonKeys;
  final Set<String> requiredComparisonKeys;
  final Set<String> missingRequiredComparisonKeys;
  final Set<String> unregisteredComparisonKeys;
  final Set<String> reviewProtocolKeys;
  final List<EvalPairwisePreferenceSummary> summaries;
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
    List<EvalPairwisePreferenceVote> pairwisePreferenceVotes = const [],
    Map<String, EvalPairwiseTraceRef> pairwiseTraceRefsByKey = const {},
  }) {
    final failures = <String>[];
    final warnings = <String>[];
    _validatePolicy(policy, failures);
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
    final cascadeTraceCount = traces
        .where((trace) => trace.isCascadeWake)
        .length;
    if (cascadeTraceCount > 0) {
      failures.add(
        'cascade wake traces are not tuning-ready evidence: '
        '$cascadeTraceCount',
      );
    }

    final agentDirectiveVariants =
        manifest?.agentDirectiveVariants ??
        _agentDirectiveVariantsFromTraces(traces);
    final expectedKeys = _expectedTraceKeys(
      scenarios,
      profiles,
      agentDirectiveVariants,
    );
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

    final outcomeQualityEvidence = _validateOutcomeQuality(
      traces: traces,
      scenarios: scenarios,
      profiles: profiles,
      agentDirectiveVariants: agentDirectiveVariants,
      policy: policy,
      failures: failures,
    );

    var effectiveCalibrationReport = calibrationReport;
    if (calibrationSet != null) {
      try {
        effectiveCalibrationReport = EvalJudgeCalibration.evaluate(
          traces: traces,
          calibrationSet: calibrationSet,
          scenarioCatalogEvidence: catalogEvidence,
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
      manifest,
      catalogEvidence,
      failures,
      warnings,
    );
    final pairwisePreferenceEvidence = _validatePairwisePreferenceEvidence(
      votes: pairwisePreferenceVotes,
      policy: policy,
      manifest: manifest,
      traces: traces,
      pairwiseTraceRefsByKey: pairwiseTraceRefsByKey,
      failures: failures,
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
      outcomeQualityEvidence: outcomeQualityEvidence,
      pairwisePreferenceEvidence: pairwisePreferenceEvidence,
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
    _validatePolicy(policy, failures);
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
      ..writeln('policyDigest=${report.policyDigest}')
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
        )} '
        'requiredCapabilities='
        '${_renderSet(report.policy.requiredPrimaryCapabilityIds)} '
        'missingRequired='
        '${_renderSet(report.evidence.missingRequiredPrimaryCapabilityIds)}',
      )
      ..writeln(
        'catalog capabilitySplits='
        '${_renderStringCounts(report.evidence.scenarioCountByPrimaryCapabilitySplit)} '
        'missing='
        '${_renderSet(report.evidence.missingRequiredCapabilitySplitCells)}',
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
        'stress tag agents='
        '${_renderStringCounts(report.evidence.adversarialStressTagCountByAgentKind)} '
        'missing='
        '${_renderSet(report.evidence.missingAdversarialStressTagAgentKindCells)}',
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
        'protected capabilities='
        '${_renderStringCounts(report.evidence.protectedHoldoutScenarioCountByPrimaryCapability)} '
        'missing='
        '${_renderSet(report.evidence.missingProtectedHoldoutPrimaryCapabilityIds)}',
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
    final outcomeEvidence = report.outcomeQualityEvidence;
    if (outcomeEvidence != null) {
      buffer.writeln(
        'outcome quality judged='
        '${_actualRequired(
          outcomeEvidence.judgedTraceCount,
          outcomeEvidence.expectedTraceCount,
        )} '
        'slices='
        '${_actualRequired(
          outcomeEvidence.judgedSliceCount,
          outcomeEvidence.expectedSliceCount,
        )} '
        'judgePass=${_pct(outcomeEvidence.passRateEstimate.rate)} '
        'lower=${_pct(outcomeEvidence.passRateEstimate.lowerBound)} '
        'goal=${_oneDecimal(outcomeEvidence.meanGoalAttainment)} '
        'quality=${_oneDecimal(outcomeEvidence.meanQuality)} '
        'efficiency=${_oneDecimal(outcomeEvidence.meanEfficiency)} '
        'tokenBudgetRatio=${_ratio(
          outcomeEvidence.meanTokenBudgetRatio,
        )} '
        'weightedCostRatio=${_ratio(
          outcomeEvidence.meanWeightedCostBudgetRatio,
        )} '
        'weightedCostEvidence='
        '${outcomeEvidence.weightedCostTraceCount}/'
        '${outcomeEvidence.judgedTraceCount} '
        'missingWeightedCost='
        '${outcomeEvidence.missingWeightedCostTraceCount}',
      );
    }
    final pairwiseEvidence = report.pairwisePreferenceEvidence;
    if (pairwiseEvidence != null) {
      buffer.writeln(
        'pairwise preferences decisions='
        '${_actualRequired(
          pairwiseEvidence.decisionCount,
          report.policy.minBlindedPairwisePreferenceDecisions,
        )} '
        'pairs=${pairwiseEvidence.pairCount} '
        'votes=${pairwiseEvidence.voteCount} '
        'invalid=${pairwiseEvidence.invalidCount} '
        'incomplete=${pairwiseEvidence.incompleteCount} '
        'noConsensus=${pairwiseEvidence.noConsensusCount} '
        'satisfiedOutcomes='
        '${_actualRequired(
          pairwiseEvidence.satisfiedOutcomeCount,
          pairwiseEvidence.outcomeExpectationCount,
        )} '
        'failedOutcomes='
        '${_renderSet(pairwiseEvidence.failedOutcomeComparisonKeys)} '
        'missingRequired='
        '${_renderSet(pairwiseEvidence.missingRequiredComparisonKeys)} '
        'unregistered='
        '${_renderSet(pairwiseEvidence.unregisteredComparisonKeys)} '
        'protocols=${pairwiseEvidence.reviewProtocolKeys.length}',
      );
    }
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
      ..writeln('policyDigest=${report.policyDigest}')
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
        )} '
        'requiredCapabilities='
        '${_renderSet(report.policy.requiredPrimaryCapabilityIds)} '
        'missingRequired='
        '${_renderSet(report.evidence.missingRequiredPrimaryCapabilityIds)}',
      )
      ..writeln(
        'catalog capabilitySplits='
        '${_renderStringCounts(report.evidence.scenarioCountByPrimaryCapabilitySplit)} '
        'missing='
        '${_renderSet(report.evidence.missingRequiredCapabilitySplitCells)}',
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
        'stress tag agents='
        '${_renderStringCounts(report.evidence.adversarialStressTagCountByAgentKind)} '
        'missing='
        '${_renderSet(report.evidence.missingAdversarialStressTagAgentKindCells)}',
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
        'protected capabilities='
        '${_renderStringCounts(report.evidence.protectedHoldoutScenarioCountByPrimaryCapability)} '
        'missing='
        '${_renderSet(report.evidence.missingProtectedHoldoutPrimaryCapabilityIds)}',
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
    final scenarioCountByPrimaryCapabilitySplit = <String, int>{};
    final adversarialScenarioCountByAgentKind = <AgentKind, int>{};
    final adversarialScenarioCountByPrimaryCapability = <String, int>{};
    final adversarialStressTagCountByAgentKind = <String, int>{};
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
        _increment(
          scenarioCountByPrimaryCapabilitySplit,
          _capabilitySplitCellKey(capabilityId, scenario.metadata.split),
        );
      }
      if (scenario.metadata.split == EvalScenarioSplit.holdout &&
          scenario.metadata.source == EvalScenarioSource.productionReplay) {
        productionReplayHoldoutScenarioCount += 1;
      }
      if (_isAdversarialScenario(scenario)) {
        adversarialScenarioCount += 1;
        adversarialTags.addAll(scenario.metadata.tags);
        _increment(adversarialScenarioCountByAgentKind, scenario.agentKind);
        for (final tag in scenario.metadata.tags.intersection(
          kDefaultAdversarialStressTags,
        )) {
          _increment(
            adversarialStressTagCountByAgentKind,
            _adversarialStressTagAgentKindCellKey(scenario.agentKind, tag),
          );
        }
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
    final protectedHoldoutScenarioCountByPrimaryCapability = <String, int>{};
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
      final capabilityId = scenario.metadata.primaryCapabilityId;
      if (capabilityId != null) {
        _increment(
          protectedHoldoutScenarioCountByPrimaryCapability,
          capabilityId,
        );
      }
      final sourceDigest = scenario.metadata.review?.sourceDigest;
      if (sourceDigest != null) {
        protectedHoldoutSourceDigests.add(sourceDigest);
      }
    }
    final duplicateProtectedHoldoutSourceDigests = _duplicates(
      protectedHoldoutSourceDigests,
    );
    final missingRequiredCapabilitySplitCells = <String>{};
    if (policy.minScenariosPerRequiredCapabilitySplit > 0) {
      for (final capabilityId in policy.requiredPrimaryCapabilityIds) {
        for (final split in policy.requiredSplits) {
          final cellKey = _capabilitySplitCellKey(capabilityId, split);
          final count = scenarioCountByPrimaryCapabilitySplit[cellKey] ?? 0;
          if (count < policy.minScenariosPerRequiredCapabilitySplit) {
            missingRequiredCapabilitySplitCells.add(cellKey);
          }
        }
      }
    }
    final missingAdversarialStressTagAgentKindCells = <String>{};
    if (policy.requireAdversarialTagCoveragePerAgentKind) {
      for (final agentKind in policy.requiredAgentKinds) {
        for (final tag in policy.requiredAdversarialTags) {
          final cellKey = _adversarialStressTagAgentKindCellKey(
            agentKind,
            tag,
          );
          final count = adversarialStressTagCountByAgentKind[cellKey] ?? 0;
          if (count == 0) {
            missingAdversarialStressTagAgentKindCells.add(cellKey);
          }
        }
      }
    }
    final missingProtectedHoldoutPrimaryCapabilityIds = <String>{};
    if (policy.minProtectedHoldoutScenariosPerRequiredCapability > 0) {
      for (final capabilityId in policy.requiredPrimaryCapabilityIds) {
        final count =
            protectedHoldoutScenarioCountByPrimaryCapability[capabilityId] ?? 0;
        if (count < policy.minProtectedHoldoutScenariosPerRequiredCapability) {
          missingProtectedHoldoutPrimaryCapabilityIds.add(capabilityId);
        }
      }
    }

    return EvalTuningReadinessEvidence(
      scenarioCountByAgentKind: Map.unmodifiable(scenarioCountByAgentKind),
      scenarioCountBySplit: Map.unmodifiable(scenarioCountBySplit),
      scenarioCountByPrimaryCapability: Map.unmodifiable(
        scenarioCountByPrimaryCapability,
      ),
      scenarioCountByPrimaryCapabilitySplit: Map.unmodifiable(
        scenarioCountByPrimaryCapabilitySplit,
      ),
      missingRequiredPrimaryCapabilityIds: Set.unmodifiable(
        policy.requiredPrimaryCapabilityIds.difference(
          scenarioCountByPrimaryCapability.keys.toSet(),
        ),
      ),
      missingRequiredCapabilitySplitCells: Set.unmodifiable(
        missingRequiredCapabilitySplitCells,
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
      adversarialStressTagCountByAgentKind: Map.unmodifiable(
        adversarialStressTagCountByAgentKind,
      ),
      adversarialTags: Set.unmodifiable(adversarialTags),
      missingAdversarialTags: Set.unmodifiable(
        policy.requiredAdversarialTags.difference(adversarialTags),
      ),
      missingAdversarialStressTagAgentKindCells: Set.unmodifiable(
        missingAdversarialStressTagAgentKindCells,
      ),
      productionReplayHoldoutScenarioCount:
          productionReplayHoldoutScenarioCount,
      protectedHoldoutScenarioCount: protectedHoldoutScenarioCount,
      protectedHoldoutScenarioCountByAgentKind: Map.unmodifiable(
        protectedHoldoutScenarioCountByAgentKind,
      ),
      protectedHoldoutScenarioCountByPrimaryCapability: Map.unmodifiable(
        protectedHoldoutScenarioCountByPrimaryCapability,
      ),
      missingProtectedHoldoutPrimaryCapabilityIds: Set.unmodifiable(
        missingProtectedHoldoutPrimaryCapabilityIds,
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
    for (final capabilityId
        in evidence.missingRequiredPrimaryCapabilityIds.toList()..sort()) {
      failures.add('missing required primary capability $capabilityId');
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
    for (final cell
        in evidence.missingRequiredCapabilitySplitCells.toList()..sort()) {
      final count = evidence.scenarioCountByPrimaryCapabilitySplit[cell] ?? 0;
      failures.add(
        'required capability split $cell scenario count $count < '
        '${policy.minScenariosPerRequiredCapabilitySplit}',
      );
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
    for (final cell
        in evidence.missingAdversarialStressTagAgentKindCells.toList()
          ..sort()) {
      failures.add('missing adversarial stress tag agent-kind cell $cell');
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
    for (final capabilityId
        in evidence.missingProtectedHoldoutPrimaryCapabilityIds.toList()
          ..sort()) {
      final count =
          evidence
              .protectedHoldoutScenarioCountByPrimaryCapability[capabilityId] ??
          0;
      failures.add(
        'capability $capabilityId protected holdout scenario count $count < '
        '${policy.minProtectedHoldoutScenariosPerRequiredCapability}',
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

  static void _validatePolicy(
    EvalTuningPolicy policy,
    List<String> failures,
  ) {
    if (policy.name.trim().isEmpty) {
      failures.add('policy name must not be empty');
    }

    void nonNegativeInt(String field, int value) {
      if (value < 0) {
        failures.add('policy $field must be at least 0');
      }
    }

    void optionalNonNegativeInt(String field, int? value) {
      if (value == null) return;
      nonNegativeInt(field, value);
    }

    void rate(String field, double value) {
      if (!value.isFinite || value < 0 || value > 1) {
        failures.add('policy $field must be between 0 and 1');
      }
    }

    void score(String field, double value) {
      if (!value.isFinite || value < 0 || value > 5) {
        failures.add('policy $field must be between 0 and 5');
      }
    }

    void optionalPositiveRatio(String field, double? value) {
      if (value == null) return;
      if (!value.isFinite || value <= 0) {
        failures.add('policy $field must be greater than 0');
      }
    }

    void optionalNonEmptyString(String field, String? value) {
      if (value != null && value.trim().isEmpty) {
        failures.add('policy $field must not be empty');
      }
    }

    nonNegativeInt('minScenarioCount', policy.minScenarioCount);
    nonNegativeInt(
      'minScenariosPerAgentKind',
      policy.minScenariosPerAgentKind,
    );
    nonNegativeInt(
      'minScenariosPerCapability',
      policy.minScenariosPerCapability,
    );
    nonNegativeInt(
      'minScenariosPerRequiredCapabilitySplit',
      policy.minScenariosPerRequiredCapabilitySplit,
    );
    nonNegativeInt('minCapabilityCount', policy.minCapabilityCount);
    nonNegativeInt(
      'minAdversarialScenarioCount',
      policy.minAdversarialScenarioCount,
    );
    nonNegativeInt(
      'minAdversarialScenariosPerAgentKind',
      policy.minAdversarialScenariosPerAgentKind,
    );
    nonNegativeInt(
      'minAdversarialScenariosPerCapability',
      policy.minAdversarialScenariosPerCapability,
    );
    nonNegativeInt(
      'minProductionReplayHoldoutScenarios',
      policy.minProductionReplayHoldoutScenarios,
    );
    nonNegativeInt(
      'minProtectedHoldoutScenarios',
      policy.minProtectedHoldoutScenarios,
    );
    nonNegativeInt(
      'minProtectedHoldoutScenariosPerAgentKind',
      policy.minProtectedHoldoutScenariosPerAgentKind,
    );
    nonNegativeInt(
      'minProtectedHoldoutScenariosPerRequiredCapability',
      policy.minProtectedHoldoutScenariosPerRequiredCapability,
    );
    nonNegativeInt('minProfilesPerModelClass', policy.minProfilesPerModelClass);
    nonNegativeInt('minTrialsPerProfile', policy.minTrialsPerProfile);
    nonNegativeInt(
      'minCalibrationEvaluatedCount',
      policy.minCalibrationEvaluatedCount,
    );
    nonNegativeInt(
      'minCalibrationEvaluatedPerModelClass',
      policy.minCalibrationEvaluatedPerModelClass,
    );
    nonNegativeInt(
      'minCalibrationEvaluatedPerCapability',
      policy.minCalibrationEvaluatedPerCapability,
    );
    nonNegativeInt(
      'minCalibrationEvaluatedPerModelClassCapability',
      policy.minCalibrationEvaluatedPerModelClassCapability,
    );
    nonNegativeInt(
      'minCalibrationEvaluatedPerPromptVariant',
      policy.minCalibrationEvaluatedPerPromptVariant,
    );
    nonNegativeInt(
      'minCalibrationEvaluatedPerModelClassPromptVariant',
      policy.minCalibrationEvaluatedPerModelClassPromptVariant,
    );
    nonNegativeInt(
      'minProtectedCalibrationEvaluatedCount',
      policy.minProtectedCalibrationEvaluatedCount,
    );
    nonNegativeInt(
      'minProtectedCalibrationEvaluatedPerModelClass',
      policy.minProtectedCalibrationEvaluatedPerModelClass,
    );
    nonNegativeInt(
      'minProtectedCalibrationEvaluatedPerCapability',
      policy.minProtectedCalibrationEvaluatedPerCapability,
    );
    nonNegativeInt(
      'minProtectedCalibrationEvaluatedPerModelClassCapability',
      policy.minProtectedCalibrationEvaluatedPerModelClassCapability,
    );
    nonNegativeInt(
      'minProtectedCalibrationEvaluatedPerPromptVariant',
      policy.minProtectedCalibrationEvaluatedPerPromptVariant,
    );
    nonNegativeInt(
      'minProtectedCalibrationEvaluatedPerModelClassPromptVariant',
      policy.minProtectedCalibrationEvaluatedPerModelClassPromptVariant,
    );
    nonNegativeInt(
      'minCalibrationHumanReviewPairCount',
      policy.minCalibrationHumanReviewPairCount,
    );
    optionalNonNegativeInt(
      'maxCalibrationUnresolvedHumanDisagreementCount',
      policy.maxCalibrationUnresolvedHumanDisagreementCount,
    );
    optionalNonNegativeInt(
      'maxCalibrationFalsePassCount',
      policy.maxCalibrationFalsePassCount,
    );
    optionalNonEmptyString(
      'requiredCalibrationSetVersion',
      policy.requiredCalibrationSetVersion,
    );
    optionalNonEmptyString(
      'requiredHumanCalibrationSetVersion',
      policy.requiredHumanCalibrationSetVersion,
    );
    optionalNonEmptyString('requiredTargetKind', policy.requiredTargetKind);
    optionalNonEmptyString(
      'expectedScenarioSetDigest',
      policy.expectedScenarioSetDigest,
    );
    optionalNonEmptyString(
      'expectedProfileSetDigest',
      policy.expectedProfileSetDigest,
    );
    if (policy.requireCalibrationTemplateSelection &&
        !policy.requireCalibrationSourceRun) {
      failures.add(
        'policy requireCalibrationTemplateSelection requires '
        'requireCalibrationSourceRun',
      );
    }

    rate('minCalibrationCoverageRate', policy.minCalibrationCoverageRate);
    rate(
      'minCalibrationCoverageLowerBound',
      policy.minCalibrationCoverageLowerBound,
    );
    rate(
      'minOutcomeJudgedTraceCoverageRate',
      policy.minOutcomeJudgedTraceCoverageRate,
    );
    rate('minJudgePassRate', policy.minJudgePassRate);
    rate('minJudgePassRateLowerBound', policy.minJudgePassRateLowerBound);
    score('minMeanGoalAttainment', policy.minMeanGoalAttainment);
    score('minMeanQuality', policy.minMeanQuality);
    score('minMeanEfficiency', policy.minMeanEfficiency);
    optionalPositiveRatio(
      'maxMeanTokensPerTraceBudgetRatio',
      policy.maxMeanTokensPerTraceBudgetRatio,
    );
    optionalPositiveRatio(
      'maxMeanWeightedCostPerTraceBudgetRatio',
      policy.maxMeanWeightedCostPerTraceBudgetRatio,
    );
    rate(
      'minCalibrationPassAgreementRate',
      policy.minCalibrationPassAgreementRate,
    );
    rate(
      'minCalibrationPassAgreementPerPromptVariant',
      policy.minCalibrationPassAgreementPerPromptVariant,
    );
    rate(
      'minCalibrationPassAgreementLowerBound',
      policy.minCalibrationPassAgreementLowerBound,
    );
    rate(
      'minCalibrationScoreAgreementRate',
      policy.minCalibrationScoreAgreementRate,
    );
    rate(
      'minCalibrationScoreAgreementPerPromptVariant',
      policy.minCalibrationScoreAgreementPerPromptVariant,
    );
    rate(
      'minCalibrationScoreAgreementLowerBound',
      policy.minCalibrationScoreAgreementLowerBound,
    );
    rate(
      'minCalibrationHumanPassAgreementRate',
      policy.minCalibrationHumanPassAgreementRate,
    );
    rate(
      'minCalibrationHumanPassAgreementLowerBound',
      policy.minCalibrationHumanPassAgreementLowerBound,
    );
    rate(
      'minCalibrationHumanScoreAgreementRate',
      policy.minCalibrationHumanScoreAgreementRate,
    );
    rate(
      'minCalibrationHumanScoreAgreementLowerBound',
      policy.minCalibrationHumanScoreAgreementLowerBound,
    );
    rate('maxCalibrationFalsePassRate', policy.maxCalibrationFalsePassRate);
    rate('maxCalibrationFalseFailRate', policy.maxCalibrationFalseFailRate);
    nonNegativeInt(
      'minBlindedPairwisePreferenceDecisions',
      policy.minBlindedPairwisePreferenceDecisions,
    );
    for (final capabilityId in policy.requiredPrimaryCapabilityIds) {
      if (capabilityId.trim().isEmpty) {
        failures.add(
          'policy requiredPrimaryCapabilityIds must not contain empty ids',
        );
      }
    }
    for (final key in policy.requiredBlindedPairwisePreferenceComparisonKeys) {
      if (key.trim().isEmpty) {
        failures.add(
          'policy requiredBlindedPairwisePreferenceComparisonKeys must not '
          'contain empty keys',
        );
      }
    }
    for (final key in policy.requiredBlindedPairwisePreferenceIntentKeys) {
      if (key.trim().isEmpty) {
        failures.add(
          'policy requiredBlindedPairwisePreferenceIntentKeys must not contain '
          'empty keys',
        );
      }
    }
    void validateOutcomeExpectations(
      String field,
      Map<String, EvalPairwiseReadinessOutcomeExpectation> expectations,
      Set<String> requiredKeys,
    ) {
      for (final entry in expectations.entries) {
        if (entry.key.trim().isEmpty) {
          failures.add('policy $field must not contain empty keys');
        }
        if (!requiredKeys.contains(entry.key)) {
          failures.add(
            'policy $field key ${entry.key} is not registered',
          );
        }
        for (final issue in entry.value.validate()) {
          failures.add('policy $field ${entry.key} $issue');
        }
      }
    }

    validateOutcomeExpectations(
      'requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey',
      policy
          .requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey,
      policy.requiredBlindedPairwisePreferenceComparisonKeys,
    );
    validateOutcomeExpectations(
      'requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey',
      policy.requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey,
      policy.requiredBlindedPairwisePreferenceIntentKeys,
    );
    for (final issue in policy.blindedPairwisePreferencePolicy.validate()) {
      failures.add('policy blindedPairwisePreferencePolicy $issue');
    }
    if (policy.requiresBlindedPairwisePreferences) {
      final pairwisePolicy = policy.blindedPairwisePreferencePolicy;
      final registeredKeyCount =
          policy.requiredBlindedPairwisePreferenceComparisonKeys.isNotEmpty
          ? policy.requiredBlindedPairwisePreferenceComparisonKeys.length
          : policy.requiredBlindedPairwisePreferenceIntentKeys.length;
      if (policy
              .requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey
              .isNotEmpty &&
          policy.requiredBlindedPairwisePreferenceComparisonKeys.isNotEmpty) {
        final missingOutcomeKeys = policy
            .requiredBlindedPairwisePreferenceComparisonKeys
            .difference(
              policy
                  .requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey
                  .keys
                  .toSet(),
            );
        for (final key in missingOutcomeKeys.toList()..sort()) {
          failures.add(
            'policy requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey '
            'is missing registered key $key',
          );
        }
      }
      if (policy
              .requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey
              .isNotEmpty &&
          policy.requiredBlindedPairwisePreferenceIntentKeys.isNotEmpty) {
        final missingOutcomeKeys = policy
            .requiredBlindedPairwisePreferenceIntentKeys
            .difference(
              policy
                  .requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey
                  .keys
                  .toSet(),
            );
        for (final key in missingOutcomeKeys.toList()..sort()) {
          failures.add(
            'policy requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey '
            'is missing registered key $key',
          );
        }
      }
      if (registeredKeyCount == 0) {
        failures.add(
          'policy requiredBlindedPairwisePreferenceComparisonKeys must not be '
          'empty when blinded pairwise decisions are required without intent '
          'keys',
        );
      }
      if (policy.minBlindedPairwisePreferenceDecisions > registeredKeyCount) {
        failures.add(
          'policy minBlindedPairwisePreferenceDecisions cannot exceed '
          'registered pairwise key count $registeredKeyCount',
        );
      }
      if (!pairwisePolicy.requireBlindedImport) {
        failures.add(
          'policy blinded pairwise gates must require blinded import '
          'provenance',
        );
      }
      if (!pairwisePolicy.requireModelIdentityBlind) {
        failures.add(
          'policy blinded pairwise gates must hide exact model identity',
        );
      }
      if (!pairwisePolicy.requireProfileBlind) {
        failures.add(
          'policy blinded pairwise gates must hide profile identity',
        );
      }
      if (!pairwisePolicy.requirePeerVoteBlind) {
        failures.add('policy blinded pairwise gates must hide peer votes');
      }
      if (!pairwisePolicy.requireTraceOrderRandomized) {
        failures.add(
          'policy blinded pairwise gates must require randomized trace order',
        );
      }
    }
  }

  static EvalPairwisePreferenceReadinessEvidence?
  _validatePairwisePreferenceEvidence({
    required List<EvalPairwisePreferenceVote> votes,
    required EvalTuningPolicy policy,
    required EvalRunManifest? manifest,
    required List<EvalTrace> traces,
    required Map<String, EvalPairwiseTraceRef> pairwiseTraceRefsByKey,
    required List<String> failures,
  }) {
    if (!policy.requiresBlindedPairwisePreferences && votes.isEmpty) {
      return null;
    }
    if (policy.blindedPairwisePreferencePolicy.validate().isNotEmpty) {
      return null;
    }

    final summaries = EvalPairwisePreferenceReporter.summarize(
      votes,
      policy: policy.blindedPairwisePreferencePolicy,
    );
    final requiredKeys = policy.requiredBlindedPairwisePreferenceComparisonKeys;
    final outcomeExpectationsByKey = policy
        .requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey;
    final observedKeys = {
      for (final summary in summaries) summary.comparisonKey,
    };
    final missingKeys = requiredKeys.difference(observedKeys);
    final hasRegisteredPlan = requiredKeys.isNotEmpty;
    final unregisteredKeys = hasRegisteredPlan
        ? observedKeys.difference(requiredKeys)
        : <String>{};
    final enforceGate = policy.requiresBlindedPairwisePreferences;
    final countedSummaries = [
      for (final summary in summaries)
        if (!hasRegisteredPlan || requiredKeys.contains(summary.comparisonKey))
          summary,
    ];
    final countedComparisonKeys = {
      for (final summary in countedSummaries) summary.comparisonKey,
    };
    final countedVotes = [
      for (final vote in votes)
        if (!hasRegisteredPlan ||
            countedComparisonKeys.contains(vote.comparisonKey))
          vote,
    ];
    final reviewProtocolKeys = {
      for (final vote in countedVotes) vote.reviewProtocolFingerprint,
    };
    final failedOutcomeKeys = <String>{};
    var satisfiedOutcomeCount = 0;

    if (enforceGate) {
      if (manifest == null) {
        failures.add('run manifest is required for blinded pairwise gates');
      } else {
        final evidence = manifest.pairwiseReadinessPlanEvidence;
        if (evidence == null) {
          failures.add(
            'run manifest pairwiseReadinessPlanEvidence is required for '
            'blinded pairwise gates',
          );
        } else {
          if (evidence.baseReadinessPolicy != 'modelClassTuning') {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence '
              'baseReadinessPolicy is ${evidence.baseReadinessPolicy}, '
              'expected modelClassTuning',
            );
          }
          if (evidence.scenarioSetDigest != manifest.scenarioSetDigest) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence scenarioSetDigest '
              'is ${evidence.scenarioSetDigest}, expected '
              '${manifest.scenarioSetDigest}',
            );
          }
          if (evidence.profileSetDigest != manifest.profileSetDigest) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence profileSetDigest is '
              '${evidence.profileSetDigest}, expected '
              '${manifest.profileSetDigest}',
            );
          }
          if (evidence.profileBindingSetDigest !=
              manifest.profileBindingSetDigest) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence '
              'profileBindingSetDigest is ${evidence.profileBindingSetDigest}, '
              'expected ${manifest.profileBindingSetDigest}',
            );
          }
          if (!EvalProvenance.isDigest(evidence.scenarioSetDigest)) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence scenarioSetDigest '
              'is not a sha256 digest',
            );
          }
          if (!EvalProvenance.isDigest(evidence.profileSetDigest)) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence profileSetDigest '
              'is not a sha256 digest',
            );
          }
          if (!EvalProvenance.isDigest(evidence.profileBindingSetDigest)) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence '
              'profileBindingSetDigest is not a sha256 digest',
            );
          }
          if (!EvalProvenance.isDigest(
            evidence.pairwiseReadinessPlanSubjectDigest,
          )) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence '
              'pairwiseReadinessPlanSubjectDigest is not a sha256 digest',
            );
          }
          if (evidence.minBlindedPairwisePreferenceDecisions !=
              policy.minBlindedPairwisePreferenceDecisions) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence '
              'minBlindedPairwisePreferenceDecisions is '
              '${evidence.minBlindedPairwisePreferenceDecisions}, expected '
              '${policy.minBlindedPairwisePreferenceDecisions}',
            );
          }
          if (evidence.comparisonCount != requiredKeys.length) {
            failures.add(
              'run manifest pairwiseReadinessPlanEvidence comparisonCount is '
              '${evidence.comparisonCount}, expected registered comparison '
              'key count ${requiredKeys.length}',
            );
          }
        }
      }
      if (pairwiseTraceRefsByKey.isEmpty) {
        failures.add(
          'raw pairwise trace refs are required for blinded pairwise gates',
        );
      }
      final traceDigestsByKey = _traceDigestsByPairwiseKey(
        traces: traces,
        pairwiseTraceRefsByKey: pairwiseTraceRefsByKey,
        failures: failures,
      );
      for (final vote in votes) {
        for (final failure in _validatePairwiseTraceBinding(
          vote.optionA,
          traceDigestsByKey,
          'option A',
        )) {
          failures.add(
            'blinded pairwise preference ${vote.voteId} trace binding is '
            'invalid: $failure',
          );
        }
        for (final failure in _validatePairwiseTraceBinding(
          vote.optionB,
          traceDigestsByKey,
          'option B',
        )) {
          failures.add(
            'blinded pairwise preference ${vote.voteId} trace binding is '
            'invalid: $failure',
          );
        }
        for (final failure in _validateBlindedPairwiseImportProvenance(
          vote,
          manifest,
        )) {
          failures.add(
            'blinded pairwise preference ${vote.voteId} import provenance is '
            'invalid: $failure',
          );
        }
      }
      for (final summary in summaries) {
        final expectation = outcomeExpectationsByKey[summary.comparisonKey];
        switch (summary.status) {
          case EvalPairwisePreferenceStatus.optionAWins:
          case EvalPairwisePreferenceStatus.optionBWins:
          case EvalPairwisePreferenceStatus.tie:
            if (expectation != null) {
              if (expectation.isSatisfiedBy(summary)) {
                satisfiedOutcomeCount += 1;
              } else {
                failedOutcomeKeys.add(summary.comparisonKey);
                failures.add(
                  'blinded pairwise preference ${summary.comparisonKey} '
                  'outcome ${summary.status.name} does not satisfy '
                  '${expectation.describe()}',
                );
              }
            }
          case EvalPairwisePreferenceStatus.invalid:
            failures.add(
              'blinded pairwise preference ${summary.comparisonKey} is '
              'invalid: ${summary.findings.join('; ')}',
            );
          case EvalPairwisePreferenceStatus.incomplete:
            failures.add(
              'blinded pairwise preference ${summary.comparisonKey} is '
              'incomplete: ${summary.findings.join('; ')}',
            );
          case EvalPairwisePreferenceStatus.noConsensus:
            failures.add(
              'blinded pairwise preference ${summary.comparisonKey} has no '
              'consensus: ${summary.findings.join('; ')}',
            );
        }
      }
      for (final key in missingKeys.toList()..sort()) {
        failures.add('missing blinded pairwise preference comparison $key');
      }
      for (final key in unregisteredKeys.toList()..sort()) {
        failures.add(
          'unregistered blinded pairwise preference comparison $key',
        );
      }
      if (outcomeExpectationsByKey.isNotEmpty) {
        final missingOutcomeKeys = requiredKeys.difference(
          outcomeExpectationsByKey.keys.toSet(),
        );
        for (final key in missingOutcomeKeys.toList()..sort()) {
          failures.add(
            'missing blinded pairwise outcome expectation for comparison $key',
          );
        }
      }
      if (reviewProtocolKeys.length > 1) {
        failures.add(
          'blinded pairwise preference gate has mixed review protocols: '
          '${(reviewProtocolKeys.toList()..sort()).join(', ')}',
        );
      }
    }

    final decisionCount = countedSummaries
        .where((summary) => summary.hasDecision)
        .length;
    final gatedDecisionCount = outcomeExpectationsByKey.isEmpty
        ? decisionCount
        : satisfiedOutcomeCount;
    if (enforceGate &&
        gatedDecisionCount < policy.minBlindedPairwisePreferenceDecisions) {
      failures.add(
        'blinded pairwise preference decisions $gatedDecisionCount < '
        '${policy.minBlindedPairwisePreferenceDecisions}',
      );
    }

    return EvalPairwisePreferenceReadinessEvidence(
      voteCount: votes.length,
      pairCount: summaries.length,
      decisionCount: decisionCount,
      invalidCount: summaries
          .where(
            (summary) => summary.status == EvalPairwisePreferenceStatus.invalid,
          )
          .length,
      incompleteCount: summaries
          .where(
            (summary) =>
                summary.status == EvalPairwisePreferenceStatus.incomplete,
          )
          .length,
      noConsensusCount: summaries
          .where(
            (summary) =>
                summary.status == EvalPairwisePreferenceStatus.noConsensus,
          )
          .length,
      outcomeExpectationCount: outcomeExpectationsByKey.length,
      satisfiedOutcomeCount: satisfiedOutcomeCount,
      failedOutcomeComparisonKeys: Set.unmodifiable(failedOutcomeKeys),
      requiredComparisonKeys: Set.unmodifiable(requiredKeys),
      missingRequiredComparisonKeys: Set.unmodifiable(missingKeys),
      unregisteredComparisonKeys: Set.unmodifiable(unregisteredKeys),
      reviewProtocolKeys: Set.unmodifiable(reviewProtocolKeys),
      summaries: List.unmodifiable(summaries),
    );
  }

  static Map<String, String> _traceDigestsByPairwiseKey({
    required List<EvalTrace> traces,
    required Map<String, EvalPairwiseTraceRef> pairwiseTraceRefsByKey,
    required List<String> failures,
  }) {
    final fallbackRefsByKey = <String, EvalPairwiseTraceRef>{};
    for (final trace in traces) {
      final traceDigest =
          trace.verdict?.traceDigest ??
          EvalProvenance.digestJson(trace.toJson());
      final ref = EvalPairwiseTraceRef.fromTrace(
        trace,
        traceDigest: traceDigest,
      );
      fallbackRefsByKey[ref.traceKey] = ref;
    }
    if (pairwiseTraceRefsByKey.isEmpty) {
      return {
        for (final entry in fallbackRefsByKey.entries)
          entry.key: entry.value.traceDigest,
      };
    }

    final expectedKeys = fallbackRefsByKey.keys.toSet();
    final providedKeys = pairwiseTraceRefsByKey.keys.toSet();
    for (final key in expectedKeys.difference(providedKeys).toList()..sort()) {
      failures.add('pairwise trace refs missing trace $key');
    }
    for (final key in providedKeys.difference(expectedKeys).toList()..sort()) {
      failures.add('pairwise trace refs contain unexpected trace $key');
    }
    for (final key
        in expectedKeys.intersection(providedKeys).toList()..sort()) {
      final expected = fallbackRefsByKey[key]!;
      final provided = pairwiseTraceRefsByKey[key]!;
      final expectedJson = Map<String, dynamic>.from(expected.toJson())
        ..remove('traceDigest');
      final providedJson = Map<String, dynamic>.from(provided.toJson())
        ..remove('traceDigest');
      if (!const DeepCollectionEquality().equals(
        expectedJson,
        providedJson,
      )) {
        failures.add('pairwise trace refs metadata drift for $key');
      }
    }
    return {
      for (final entry in pairwiseTraceRefsByKey.entries)
        entry.key: entry.value.traceDigest,
    };
  }

  static List<String> _validatePairwiseTraceBinding(
    EvalPairwiseTraceRef ref,
    Map<String, String> traceDigestsByKey,
    String label,
  ) {
    final traceDigest = traceDigestsByKey[ref.traceKey];
    if (traceDigest == null) {
      return ['$label trace ${ref.traceKey} is not present'];
    }
    if (traceDigest != ref.traceDigest) {
      return [
        '$label traceDigest is ${ref.traceDigest}, expected $traceDigest',
      ];
    }
    return const <String>[];
  }

  static List<String> _validateBlindedPairwiseImportProvenance(
    EvalPairwisePreferenceVote vote,
    EvalRunManifest? manifest,
  ) {
    final provenance = vote.blindedImport;
    if (provenance == null) return const <String>[];
    final failures = <String>[];

    void requireDigest(String field, String value) {
      if (!EvalProvenance.isDigest(value)) {
        failures.add('$field is not a sha256 digest');
      }
    }

    requireDigest('reviewPayloadDigest', provenance.reviewPayloadDigest);
    requireDigest('judgeManifestDigest', provenance.judgeManifestDigest);
    requireDigest('privateKeyDigest', provenance.privateKeyDigest);
    requireDigest('sourceManifestDigest', provenance.sourceManifestDigest);
    requireDigest(
      'optionARawTraceDigest',
      provenance.optionARawTraceDigest,
    );
    requireDigest(
      'optionBRawTraceDigest',
      provenance.optionBRawTraceDigest,
    );
    if (provenance.optionARawTraceDigest != vote.optionA.traceDigest) {
      failures.add(
        'optionARawTraceDigest does not match option A traceDigest',
      );
    }
    if (provenance.optionBRawTraceDigest != vote.optionB.traceDigest) {
      failures.add(
        'optionBRawTraceDigest does not match option B traceDigest',
      );
    }
    if (manifest != null) {
      final manifestDigest = manifest.manifestDigest;
      if (manifestDigest == null) {
        failures.add('source manifest digest cannot be checked');
      } else if (provenance.sourceManifestDigest != manifestDigest) {
        failures.add(
          'sourceManifestDigest is ${provenance.sourceManifestDigest}, '
          'expected $manifestDigest',
        );
      }
    }
    return failures;
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

    final policyEvidence = manifest.tuningReadinessPolicyEvidence;
    if (policy.requireManifestPolicyEvidence && policyEvidence == null) {
      failures.add(
        'run manifest tuningReadinessPolicyEvidence is required for '
        '${policy.name}',
      );
    }
    if (policyEvidence != null) {
      if (policyEvidence.policyName != policy.name) {
        failures.add(
          'manifest tuningReadinessPolicyEvidence policyName is '
          '${policyEvidence.policyName}, expected ${policy.name}',
        );
      }
      if (policyEvidence.policyDigest != policy.policyDigest) {
        failures.add(
          'manifest tuningReadinessPolicyEvidence policyDigest is '
          '${policyEvidence.policyDigest}, expected ${policy.policyDigest}',
        );
      }
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
      if (policy.minProtectedHoldoutScenariosPerRequiredCapability > 0) {
        for (final capabilityId
            in policy.requiredPrimaryCapabilityIds.toList()..sort()) {
          failures.add(
            'capability $capabilityId protected holdout scenario count 0 < '
            '${policy.minProtectedHoldoutScenariosPerRequiredCapability}',
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
        policy.minProtectedHoldoutScenariosPerAgentKind > 0 ||
        policy.minProtectedHoldoutScenariosPerRequiredCapability > 0;
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
    EvalRunManifest? manifest,
    EvalScenarioCatalogEvidence? catalogEvidence,
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
      if (policy.requireBlindedJudgeVerdicts &&
          !verdict.judge.modelIdentityVisible) {
        for (final issue in _validateBlindedVerdictImportProvenance(
          trace,
          manifest,
        )) {
          failures.add(
            '${_traceKey(trace)} blinded judge verdict provenance: $issue',
          );
        }
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
    if (policy.requireCalibrationSourceRun) {
      final sourceRun = calibrationSet?.sourceRun;
      if (sourceRun == null) {
        failures.add('calibration sourceRun is required for readiness gates');
      } else {
        failures.addAll(sourceRun.validateManifestBinding(manifest));
      }
    }
    if (policy.requireCalibrationTemplateSelection &&
        calibrationSet != null &&
        calibrationReport != null) {
      final templateSelection = calibrationSet.templateSelection;
      final sampledByLabelCount =
          calibrationSet.labels.length < calibrationReport.judgedTraceCount;
      final sampledByProof = templateSelection?.sampled ?? false;
      if (templateSelection == null && sampledByLabelCount) {
        failures.add(
          'calibration template selection is required for sampled labels',
        );
      } else if (templateSelection != null &&
          (sampledByLabelCount || sampledByProof)) {
        for (final issue
            in EvalJudgeCalibration.validateTemplateSelectionBinding(
              traces: traces,
              calibrationSet: calibrationSet,
              scenarioCatalogEvidence: catalogEvidence,
            )) {
          failures.add('calibration template selection: $issue');
        }
      }
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

  static List<String> _validateBlindedVerdictImportProvenance(
    EvalTrace trace,
    EvalRunManifest? manifest,
  ) {
    final verdict = trace.verdict;
    final provenance = verdict?.blindedImport;
    if (verdict == null) return const <String>[];
    if (provenance == null) {
      return const <String>['missing blindedImport'];
    }
    final failures = <String>[];
    if (provenance.blindedTraceId.trim().isEmpty) {
      failures.add('blindedTraceId is empty');
    }
    void requireDigest(String field, String value) {
      if (!EvalProvenance.isDigest(value)) {
        failures.add('$field is not a sha256 digest');
      }
    }

    requireDigest('reviewPayloadDigest', provenance.reviewPayloadDigest);
    requireDigest('judgeManifestDigest', provenance.judgeManifestDigest);
    requireDigest('privateKeyDigest', provenance.privateKeyDigest);
    requireDigest('sourceManifestDigest', provenance.sourceManifestDigest);
    requireDigest('rawTraceDigest', provenance.rawTraceDigest);
    final manifestDigest = manifest?.manifestDigest;
    if (manifest == null) {
      failures.add('sourceManifestDigest cannot be checked without manifest');
    } else if (manifestDigest == null) {
      failures.add(
        'sourceManifestDigest cannot be checked without manifestDigest',
      );
    }
    final expectedSourceManifestDigest =
        manifestDigest ?? trace.provenance.manifestDigest;
    if (provenance.sourceManifestDigest != expectedSourceManifestDigest) {
      failures.add(
        'sourceManifestDigest is ${provenance.sourceManifestDigest}, '
        'expected $expectedSourceManifestDigest',
      );
    }
    final traceDigest = verdict.traceDigest;
    if (traceDigest == null) {
      failures.add('rawTraceDigest cannot be checked without traceDigest');
    } else if (provenance.rawTraceDigest != traceDigest) {
      failures.add(
        'rawTraceDigest is ${provenance.rawTraceDigest}, expected '
        '$traceDigest',
      );
    }
    return failures;
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
    _validateProtectedCalibrationHoldout(
      report: report,
      scenarios: scenarios,
      traces: traces,
      policy: policy,
      failures: failures,
    );
    _validateCalibrationSliceCoverage(
      report: report,
      scenarios: scenarios,
      traces: traces,
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
      if (report.unlabeledVerdictCount > 0) {
        failures.add(
          'calibration report has ${report.unlabeledVerdictCount} unlabeled '
          'verdicts',
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
      policy.minCalibrationEvaluatedPerModelClassCapability > 0 ||
      policy.minCalibrationEvaluatedPerPromptVariant > 0 ||
      policy.minCalibrationEvaluatedPerModelClassPromptVariant > 0 ||
      policy.requireCalibrationTemplateSelection ||
      policy.requireProtectedCalibrationHoldout ||
      policy.minProtectedCalibrationEvaluatedCount > 0 ||
      policy.minProtectedCalibrationEvaluatedPerModelClass > 0 ||
      policy.minProtectedCalibrationEvaluatedPerCapability > 0 ||
      policy.minProtectedCalibrationEvaluatedPerModelClassCapability > 0 ||
      policy.minProtectedCalibrationEvaluatedPerPromptVariant > 0 ||
      policy.minProtectedCalibrationEvaluatedPerModelClassPromptVariant > 0 ||
      policy.minCalibrationCoverageRate > 0 ||
      policy.minCalibrationCoverageLowerBound > 0 ||
      policy.minCalibrationPassAgreementRate > 0 ||
      policy.minCalibrationPassAgreementPerPromptVariant > 0 ||
      policy.minCalibrationPassAgreementLowerBound > 0 ||
      policy.minCalibrationScoreAgreementRate > 0 ||
      policy.minCalibrationScoreAgreementPerPromptVariant > 0 ||
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
      policy.requireCalibrationSourceRun ||
      policy.requireCleanCalibrationReport;

  static void _validateProtectedCalibrationHoldout({
    required JudgeCalibrationReport report,
    required List<EvalScenario> scenarios,
    required List<EvalTrace> traces,
    required EvalTuningPolicy policy,
    required List<String> failures,
  }) {
    if (policy.requireProtectedCalibrationHoldout &&
        report.protectedHoldoutLabelCount == 0) {
      failures.add('protected calibration holdout labels are missing');
    }
    if (report.protectedHoldoutEvaluatedCount <
        policy.minProtectedCalibrationEvaluatedCount) {
      failures.add(
        'protected calibration evaluated count '
        '${report.protectedHoldoutEvaluatedCount} < '
        '${policy.minProtectedCalibrationEvaluatedCount}',
      );
    }
    if (policy.minProtectedCalibrationEvaluatedPerModelClass > 0) {
      final byModelClass = {
        for (final summary in report.protectedHoldoutModelClassSummaries)
          summary.name: summary.evaluatedCount,
      };
      for (final modelClass in policy.requiredModelClasses) {
        final count = byModelClass[modelClass.name] ?? 0;
        if (count < policy.minProtectedCalibrationEvaluatedPerModelClass) {
          failures.add(
            'protected calibration model class ${modelClass.name} evaluated '
            'count $count < '
            '${policy.minProtectedCalibrationEvaluatedPerModelClass}',
          );
        }
      }
    }
    if (policy.minProtectedCalibrationEvaluatedPerCapability > 0) {
      final byCapability = {
        for (final summary in report.protectedHoldoutCapabilitySummaries)
          summary.name: summary.evaluatedCount,
      };
      final capabilityIds = <String>{
        for (final scenario in scenarios)
          if (scenario.metadata.primaryCapabilityId != null)
            scenario.metadata.primaryCapabilityId!,
      };
      for (final capabilityId in capabilityIds.toList()..sort()) {
        final count = byCapability[capabilityId] ?? 0;
        if (count < policy.minProtectedCalibrationEvaluatedPerCapability) {
          failures.add(
            'protected calibration capability $capabilityId evaluated count '
            '$count < '
            '${policy.minProtectedCalibrationEvaluatedPerCapability}',
          );
        }
      }
    }
    if (policy.minProtectedCalibrationEvaluatedPerModelClassCapability > 0) {
      final byModelClassCapability = {
        for (final summary
            in report.protectedHoldoutModelClassCapabilitySummaries)
          summary.name: summary.evaluatedCount,
      };
      final requiredModelClasses = policy.requiredModelClasses.isEmpty
          ? <EvalModelClass>{
              for (final profile in traces.map((trace) => trace.profile))
                profile.modelClass,
            }
          : policy.requiredModelClasses;
      final capabilityIds = <String>{
        for (final scenario in scenarios)
          if (scenario.metadata.primaryCapabilityId != null)
            scenario.metadata.primaryCapabilityId!,
      };
      for (final modelClass
          in requiredModelClasses.toList()
            ..sort((a, b) => a.name.compareTo(b.name))) {
        for (final capabilityId in capabilityIds.toList()..sort()) {
          final name = '${modelClass.name}@$capabilityId';
          final count = byModelClassCapability[name] ?? 0;
          if (count <
              policy.minProtectedCalibrationEvaluatedPerModelClassCapability) {
            failures.add(
              'protected calibration model class/capability $name evaluated '
              'count $count < '
              '${policy.minProtectedCalibrationEvaluatedPerModelClassCapability}',
            );
          }
        }
      }
    }
    if (policy.minProtectedCalibrationEvaluatedPerPromptVariant > 0) {
      final byPromptVariant = {
        for (final summary in report.protectedHoldoutPromptVariantSummaries)
          summary.name: summary.evaluatedCount,
      };
      final promptVariantNames = <String>{
        for (final trace in traces) trace.agentDirectiveVariant.name,
      };
      for (final promptVariantName in promptVariantNames.toList()..sort()) {
        final count = byPromptVariant[promptVariantName] ?? 0;
        if (count < policy.minProtectedCalibrationEvaluatedPerPromptVariant) {
          failures.add(
            'protected calibration prompt variant $promptVariantName evaluated '
            'count $count < '
            '${policy.minProtectedCalibrationEvaluatedPerPromptVariant}',
          );
        }
      }
    }
    if (policy.minProtectedCalibrationEvaluatedPerModelClassPromptVariant > 0) {
      final byModelClassPromptVariant = {
        for (final summary
            in report.protectedHoldoutModelClassPromptVariantSummaries)
          summary.name: summary.evaluatedCount,
      };
      final modelClassPromptVariants = <String>{
        for (final trace in traces)
          '${trace.profile.modelClass.name}@${trace.agentDirectiveVariant.name}',
      };
      for (final name in modelClassPromptVariants.toList()..sort()) {
        final count = byModelClassPromptVariant[name] ?? 0;
        if (count <
            policy.minProtectedCalibrationEvaluatedPerModelClassPromptVariant) {
          failures.add(
            'protected calibration model class/prompt variant $name evaluated '
            'count $count < '
            '${policy.minProtectedCalibrationEvaluatedPerModelClassPromptVariant}',
          );
        }
      }
    }
  }

  static void _validateCalibrationSliceCoverage({
    required JudgeCalibrationReport report,
    required List<EvalScenario> scenarios,
    required List<EvalTrace> traces,
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
    if (policy.minCalibrationEvaluatedPerModelClassCapability > 0) {
      final byModelClassCapability = {
        for (final summary in report.modelClassCapabilitySummaries)
          summary.name: summary.evaluatedCount,
      };
      final requiredModelClasses = policy.requiredModelClasses.isEmpty
          ? <EvalModelClass>{
              for (final profile in traces.map((trace) => trace.profile))
                profile.modelClass,
            }
          : policy.requiredModelClasses;
      final capabilityIds = <String>{
        for (final scenario in scenarios)
          if (scenario.metadata.primaryCapabilityId != null)
            scenario.metadata.primaryCapabilityId!,
      };
      for (final modelClass
          in requiredModelClasses.toList()
            ..sort((a, b) => a.name.compareTo(b.name))) {
        for (final capabilityId in capabilityIds.toList()..sort()) {
          final name = '${modelClass.name}@$capabilityId';
          final count = byModelClassCapability[name] ?? 0;
          if (count < policy.minCalibrationEvaluatedPerModelClassCapability) {
            failures.add(
              'calibration model class/capability $name evaluated count '
              '$count < '
              '${policy.minCalibrationEvaluatedPerModelClassCapability}',
            );
          }
        }
      }
    }
    if (policy.minCalibrationEvaluatedPerPromptVariant > 0) {
      final byPromptVariant = {
        for (final summary in report.promptVariantSummaries)
          summary.name: summary.evaluatedCount,
      };
      final promptVariantNames = <String>{
        for (final trace in traces) trace.agentDirectiveVariant.name,
      };
      for (final promptVariantName in promptVariantNames.toList()..sort()) {
        final count = byPromptVariant[promptVariantName] ?? 0;
        if (count < policy.minCalibrationEvaluatedPerPromptVariant) {
          failures.add(
            'calibration prompt variant $promptVariantName evaluated count '
            '$count < ${policy.minCalibrationEvaluatedPerPromptVariant}',
          );
        }
      }
    }
    if (policy.minCalibrationPassAgreementPerPromptVariant > 0 ||
        policy.minCalibrationScoreAgreementPerPromptVariant > 0) {
      final byPromptVariant = {
        for (final summary in report.promptVariantSummaries)
          summary.name: summary,
      };
      final promptVariantNames = <String>{
        for (final trace in traces) trace.agentDirectiveVariant.name,
      };
      for (final promptVariantName in promptVariantNames.toList()..sort()) {
        final summary =
            byPromptVariant[promptVariantName] ??
            JudgeCalibrationSliceSummary(
              name: promptVariantName,
              labelCount: 0,
              evaluatedCount: 0,
              staleLabelCount: 0,
              missingTraceCount: 0,
              missingVerdictCount: 0,
              falsePassCount: 0,
              falseFailCount: 0,
              judgeCalibrationMismatchCount: 0,
              passAgreementCount: 0,
              scoreAgreementCount: 0,
            );
        if (summary.passAgreementRate <
            policy.minCalibrationPassAgreementPerPromptVariant) {
          failures.add(
            'calibration prompt variant $promptVariantName pass agreement '
            '${_pct(summary.passAgreementRate)} < '
            '${_pct(policy.minCalibrationPassAgreementPerPromptVariant)}',
          );
        }
        if (summary.scoreAgreementRate <
            policy.minCalibrationScoreAgreementPerPromptVariant) {
          failures.add(
            'calibration prompt variant $promptVariantName score agreement '
            '${_pct(summary.scoreAgreementRate)} < '
            '${_pct(policy.minCalibrationScoreAgreementPerPromptVariant)}',
          );
        }
      }
    }
    if (policy.minCalibrationEvaluatedPerModelClassPromptVariant > 0) {
      final byModelClassPromptVariant = {
        for (final summary in report.modelClassPromptVariantSummaries)
          summary.name: summary.evaluatedCount,
      };
      final modelClassPromptVariants = <String>{
        for (final trace in traces)
          '${trace.profile.modelClass.name}@${trace.agentDirectiveVariant.name}',
      };
      for (final name in modelClassPromptVariants.toList()..sort()) {
        final count = byModelClassPromptVariant[name] ?? 0;
        if (count < policy.minCalibrationEvaluatedPerModelClassPromptVariant) {
          failures.add(
            'calibration model class/prompt variant $name evaluated count '
            '$count < '
            '${policy.minCalibrationEvaluatedPerModelClassPromptVariant}',
          );
        }
      }
    }
  }

  static EvalOutcomeQualityEvidence? _validateOutcomeQuality({
    required List<EvalTrace> traces,
    required List<EvalScenario> scenarios,
    required List<EvalProfile> profiles,
    required List<EvalAgentDirectiveVariant> agentDirectiveVariants,
    required EvalTuningPolicy policy,
    required List<String> failures,
  }) {
    if (!_hasOutcomeQualityRequirement(policy)) return null;

    final expectedSlices = <String, _OutcomeSliceStats>{};
    var expectedTraceCount = 0;
    for (final scenario in scenarios) {
      for (final profile in profiles) {
        for (final variant in agentDirectiveVariants) {
          final label = _outcomeSliceLabel(
            capabilityId: scenario.metadata.primaryCapabilityId,
            agentKind: scenario.agentKind,
            modelClass: profile.modelClass,
            promptVariantName: variant.name,
          );
          expectedSlices
                  .putIfAbsent(label, () => _OutcomeSliceStats(label: label))
                  .expectedTraceCount +=
              profile.trialCount;
          expectedTraceCount += profile.trialCount;
        }
      }
    }

    final observedSlices = {
      for (final entry in expectedSlices.entries) entry.key: entry.value,
    };
    final judgedVerdicts = <JudgeVerdict>[];
    final tokenBudgetRatios = <double>[];
    final weightedCostBudgetRatios = <double>[];
    var judgedTraceCount = 0;
    var passTraceCount = 0;
    var weightedCostTraceCount = 0;
    var missingWeightedCostTraceCount = 0;
    for (final trace in traces) {
      if (trace.isCascadeWake) continue;
      final label = _outcomeSliceLabel(
        capabilityId: trace.scenario.metadata.primaryCapabilityId,
        agentKind: trace.scenario.agentKind,
        modelClass: trace.profile.modelClass,
        promptVariantName: trace.agentDirectiveVariant.name,
      );
      final slice = observedSlices.putIfAbsent(
        label,
        () => _OutcomeSliceStats(label: label),
      );
      final verdict = trace.verdict;
      if (verdict == null) continue;
      judgedVerdicts.add(verdict);
      judgedTraceCount += 1;
      final tokenBudgetRatio = _rate(
        trace.output.usage.totalTokens,
        trace.profile.tokenBudget,
      );
      tokenBudgetRatios.add(tokenBudgetRatio);
      final weightedCost = trace.profile.estimatedUsageCostMicrosOrNull(
        trace.output.usage,
        requireCoreTokenCounts: trace.profile.usesWeightedTokenCosts,
      );
      double? weightedCostBudgetRatio;
      if (weightedCost == null) {
        if (trace.profile.usesWeightedTokenCosts) {
          missingWeightedCostTraceCount += 1;
        }
      } else {
        weightedCostTraceCount += 1;
        weightedCostBudgetRatio = _rate(
          weightedCost,
          trace.profile.tokenBudget,
        );
        weightedCostBudgetRatios.add(weightedCostBudgetRatio);
      }
      slice.addVerdict(
        traceKey: _traceKey(trace),
        verdict: verdict,
        tokenBudgetRatio: tokenBudgetRatio,
        weightedCostBudgetRatio: weightedCostBudgetRatio,
        weightedCostMissing:
            weightedCost == null && trace.profile.usesWeightedTokenCosts,
      );
      if (verdict.pass) {
        passTraceCount += 1;
      }
    }

    final aggregatePassEstimate = RateEstimate.wilson(
      successes: passTraceCount,
      total: judgedTraceCount,
    );
    final aggregateGoalAttainment = _mean(
      judgedVerdicts.map((verdict) => verdict.goalAttainment.toDouble()),
    );
    final aggregateQuality = _mean(
      judgedVerdicts.map((verdict) => verdict.quality.toDouble()),
    );
    final aggregateEfficiency = _mean(
      judgedVerdicts.map((verdict) => verdict.efficiency.toDouble()),
    );
    final aggregateTokenBudgetRatio = _mean(tokenBudgetRatios);
    final aggregateWeightedCostBudgetRatio = _mean(weightedCostBudgetRatios);
    final judgedCoverageRate = _rate(judgedTraceCount, expectedTraceCount);
    if (judgedCoverageRate < policy.minOutcomeJudgedTraceCoverageRate) {
      failures.add(
        'outcome judged trace coverage ${_pct(judgedCoverageRate)} < '
        '${_pct(policy.minOutcomeJudgedTraceCoverageRate)}',
      );
    }
    _validateOutcomeThresholds(
      label: 'all',
      passEstimate: aggregatePassEstimate,
      meanGoalAttainment: aggregateGoalAttainment,
      meanQuality: aggregateQuality,
      meanEfficiency: aggregateEfficiency,
      meanTokenBudgetRatio: aggregateTokenBudgetRatio,
      weightedCostTraceCount: weightedCostTraceCount,
      missingWeightedCostTraceCount: missingWeightedCostTraceCount,
      meanWeightedCostBudgetRatio: aggregateWeightedCostBudgetRatio,
      failingTraceKeys: [
        for (final trace in traces)
          if (!trace.isCascadeWake && trace.verdict != null)
            if (!trace.verdict!.pass) _traceKey(trace),
      ],
      policy: policy,
      failures: failures,
    );

    var judgedSliceCount = 0;
    if (policy.requireOutcomeSliceThresholds) {
      for (final slice
          in observedSlices.values.toList()
            ..sort((a, b) => a.label.compareTo(b.label))) {
        if (slice.judgedTraceCount > 0) {
          judgedSliceCount += 1;
        }
        final sliceCoverageRate = _rate(
          slice.judgedTraceCount,
          slice.expectedTraceCount,
        );
        if (sliceCoverageRate < policy.minOutcomeJudgedTraceCoverageRate) {
          failures.add(
            'outcome slice ${slice.label} judged trace coverage '
            '${_pct(sliceCoverageRate)} < '
            '${_pct(policy.minOutcomeJudgedTraceCoverageRate)}',
          );
        }
        _validateOutcomeThresholds(
          label: 'slice ${slice.label}',
          passEstimate: slice.passEstimate,
          meanGoalAttainment: slice.meanGoalAttainment,
          meanQuality: slice.meanQuality,
          meanEfficiency: slice.meanEfficiency,
          meanTokenBudgetRatio: slice.meanTokenBudgetRatio,
          weightedCostTraceCount: slice.weightedCostTraceCount,
          missingWeightedCostTraceCount: slice.missingWeightedCostTraceCount,
          meanWeightedCostBudgetRatio: slice.meanWeightedCostBudgetRatio,
          failingTraceKeys: slice.failingTraceKeys,
          policy: policy,
          failures: failures,
        );
      }
    } else {
      judgedSliceCount = observedSlices.values
          .where((slice) => slice.judgedTraceCount > 0)
          .length;
    }

    return EvalOutcomeQualityEvidence(
      expectedTraceCount: expectedTraceCount,
      judgedTraceCount: judgedTraceCount,
      passTraceCount: passTraceCount,
      expectedSliceCount: expectedSlices.length,
      judgedSliceCount: judgedSliceCount,
      passRateEstimate: aggregatePassEstimate,
      meanGoalAttainment: aggregateGoalAttainment,
      meanQuality: aggregateQuality,
      meanEfficiency: aggregateEfficiency,
      meanTokenBudgetRatio: aggregateTokenBudgetRatio,
      weightedCostTraceCount: weightedCostTraceCount,
      missingWeightedCostTraceCount: missingWeightedCostTraceCount,
      meanWeightedCostBudgetRatio: aggregateWeightedCostBudgetRatio,
    );
  }

  static bool _hasOutcomeQualityRequirement(EvalTuningPolicy policy) =>
      policy.requireAllJudgePasses ||
      policy.requireOutcomeSliceThresholds ||
      policy.minOutcomeJudgedTraceCoverageRate > 0 ||
      policy.minJudgePassRate > 0 ||
      policy.minJudgePassRateLowerBound > 0 ||
      policy.minMeanGoalAttainment > 0 ||
      policy.minMeanQuality > 0 ||
      policy.minMeanEfficiency > 0 ||
      policy.maxMeanTokensPerTraceBudgetRatio != null ||
      policy.maxMeanWeightedCostPerTraceBudgetRatio != null ||
      policy.requireWeightedCostEvidence;

  static void _validateOutcomeThresholds({
    required String label,
    required RateEstimate passEstimate,
    required double meanGoalAttainment,
    required double meanQuality,
    required double meanEfficiency,
    required double meanTokenBudgetRatio,
    required int weightedCostTraceCount,
    required int missingWeightedCostTraceCount,
    required double meanWeightedCostBudgetRatio,
    required List<String> failingTraceKeys,
    required EvalTuningPolicy policy,
    required List<String> failures,
  }) {
    if (passEstimate.rate < policy.minJudgePassRate) {
      failures.add(
        'outcome $label judge pass rate ${_pct(passEstimate.rate)} < '
        '${_pct(policy.minJudgePassRate)}',
      );
    }
    if (passEstimate.lowerBound < policy.minJudgePassRateLowerBound) {
      failures.add(
        'outcome $label judge pass lower bound '
        '${_pct(passEstimate.lowerBound)} < '
        '${_pct(policy.minJudgePassRateLowerBound)}',
      );
    }
    if (meanGoalAttainment < policy.minMeanGoalAttainment) {
      failures.add(
        'outcome $label mean goal attainment '
        '${_oneDecimal(meanGoalAttainment)} < '
        '${_oneDecimal(policy.minMeanGoalAttainment)}',
      );
    }
    if (meanQuality < policy.minMeanQuality) {
      failures.add(
        'outcome $label mean quality ${_oneDecimal(meanQuality)} < '
        '${_oneDecimal(policy.minMeanQuality)}',
      );
    }
    if (meanEfficiency < policy.minMeanEfficiency) {
      failures.add(
        'outcome $label mean efficiency ${_oneDecimal(meanEfficiency)} < '
        '${_oneDecimal(policy.minMeanEfficiency)}',
      );
    }
    if (policy.requireAllJudgePasses && failingTraceKeys.isNotEmpty) {
      failures.add(
        'outcome $label failing judge traces '
        '${_renderSet(failingTraceKeys.toSet())}',
      );
    }
    final maxTokenRatio = policy.maxMeanTokensPerTraceBudgetRatio;
    if (maxTokenRatio != null && meanTokenBudgetRatio > maxTokenRatio) {
      failures.add(
        'outcome $label mean token budget ratio '
        '${_ratio(meanTokenBudgetRatio)} > ${_ratio(maxTokenRatio)}',
      );
    }
    if (policy.requireWeightedCostEvidence &&
        missingWeightedCostTraceCount > 0) {
      failures.add(
        'outcome $label missing weighted cost evidence '
        '$missingWeightedCostTraceCount > 0',
      );
    }
    final maxWeightedCostRatio = policy.maxMeanWeightedCostPerTraceBudgetRatio;
    if (maxWeightedCostRatio != null &&
        weightedCostTraceCount > 0 &&
        meanWeightedCostBudgetRatio > maxWeightedCostRatio) {
      failures.add(
        'outcome $label mean weighted cost budget ratio '
        '${_ratio(meanWeightedCostBudgetRatio)} > '
        '${_ratio(maxWeightedCostRatio)}',
      );
    }
  }

  static String _outcomeSliceLabel({
    required String? capabilityId,
    required AgentKind agentKind,
    required EvalModelClass modelClass,
    required String promptVariantName,
  }) {
    return [
      capabilityId ?? 'uncategorized',
      agentKind.name,
      modelClass.name,
      promptVariantName,
    ].join('@');
  }

  static Set<String> _expectedTraceKeys(
    List<EvalScenario> scenarios,
    List<EvalProfile> profiles,
    List<EvalAgentDirectiveVariant> agentDirectiveVariants,
  ) {
    return {
      for (final scenario in scenarios)
        for (final profile in profiles)
          for (final variant in agentDirectiveVariants)
            for (
              var trialIndex = 0;
              trialIndex < profile.trialCount;
              trialIndex++
            )
              _key(scenario.id, profile.name, variant.name, trialIndex),
    };
  }

  static String _traceKey(EvalTrace trace) => _key(
    trace.scenario.id,
    trace.profile.name,
    trace.agentDirectiveVariant.name,
    trace.trialIndex,
    cascadeWake: trace.cascadeWake,
  );

  static String _key(
    String scenarioId,
    String profileName,
    String agentDirectiveVariantName,
    int trialIndex, {
    EvalTraceCascadeWake? cascadeWake,
  }) {
    final suffix = cascadeWake == null ? '' : '::${cascadeWake.keySuffix}';
    final variantSegment = agentDirectiveVariantName == 'default'
        ? ''
        : '::$agentDirectiveVariantName';
    return '$scenarioId::$profileName$variantSegment::trial-$trialIndex$suffix';
  }

  static List<EvalAgentDirectiveVariant> _agentDirectiveVariantsFromTraces(
    List<EvalTrace> traces,
  ) {
    if (traces.isEmpty) return const [EvalAgentDirectiveVariant()];
    final byName = <String, EvalAgentDirectiveVariant>{};
    for (final trace in traces) {
      byName[trace.agentDirectiveVariant.name] = trace.agentDirectiveVariant;
    }
    return [
      for (final name in byName.keys.toList()..sort()) byName[name]!,
    ];
  }

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

  static String _capabilitySplitCellKey(
    String capabilityId,
    EvalScenarioSplit split,
  ) => '${split.name}::$capabilityId';

  static String _adversarialStressTagAgentKindCellKey(
    AgentKind agentKind,
    String tag,
  ) => '${agentKind.name}::$tag';

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

  static double _mean(Iterable<double> values) {
    var count = 0;
    var sum = 0.0;
    for (final value in values) {
      count += 1;
      sum += value;
    }
    return count == 0 ? 0 : sum / count;
  }

  static double _rate(int count, int total) => total == 0 ? 0 : count / total;

  static String _oneDecimal(double value) => value.toStringAsFixed(1);

  static String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

  static String _ratio(double value) => '${value.toStringAsFixed(2)}x';
}

class _OutcomeSliceStats {
  _OutcomeSliceStats({required this.label});

  final String label;
  final verdicts = <JudgeVerdict>[];
  final failingTraceKeys = <String>[];
  final tokenBudgetRatios = <double>[];
  final weightedCostBudgetRatios = <double>[];
  int expectedTraceCount = 0;
  int missingWeightedCostTraceCount = 0;

  int get judgedTraceCount => verdicts.length;

  int get passTraceCount => verdicts.where((verdict) => verdict.pass).length;

  RateEstimate get passEstimate => RateEstimate.wilson(
    successes: passTraceCount,
    total: judgedTraceCount,
  );

  double get meanGoalAttainment => EvalTuningReadiness._mean(
    verdicts.map((verdict) => verdict.goalAttainment.toDouble()),
  );

  double get meanQuality => EvalTuningReadiness._mean(
    verdicts.map((verdict) => verdict.quality.toDouble()),
  );

  double get meanEfficiency => EvalTuningReadiness._mean(
    verdicts.map((verdict) => verdict.efficiency.toDouble()),
  );

  double get meanTokenBudgetRatio =>
      EvalTuningReadiness._mean(tokenBudgetRatios);

  int get weightedCostTraceCount => weightedCostBudgetRatios.length;

  double get meanWeightedCostBudgetRatio =>
      EvalTuningReadiness._mean(weightedCostBudgetRatios);

  void addVerdict({
    required String traceKey,
    required JudgeVerdict verdict,
    required double tokenBudgetRatio,
    required double? weightedCostBudgetRatio,
    required bool weightedCostMissing,
  }) {
    verdicts.add(verdict);
    tokenBudgetRatios.add(tokenBudgetRatio);
    if (weightedCostBudgetRatio != null) {
      weightedCostBudgetRatios.add(weightedCostBudgetRatio);
    }
    if (weightedCostMissing) {
      missingWeightedCostTraceCount += 1;
    }
    if (!verdict.pass) {
      failingTraceKeys.add(traceKey);
    }
  }
}
