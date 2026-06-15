import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';
import 'eval_profile_config.dart';

void main() {
  const localSmall = EvalProfile(
    name: 'local-small-test',
    isLocal: true,
    modelClass: EvalModelClass.localSmall,
    modelId: 'local-small-model',
    tokenBudget: 6000,
    trialCount: 2,
  );
  const frontierFast = EvalProfile(
    name: 'frontier-fast-test',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'frontier-fast-model',
    tokenBudget: 60000,
    trialCount: 2,
  );

  test('rejects non-positive profile cost weights', () {
    const badProfile = EvalProfile(
      name: 'bad-cost-profile',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'bad-cost-model',
      tokenBudget: 10000,
      outputTokenCostMicros: 0,
    );

    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: const [],
      profiles: const [badProfile],
    );

    expect(
      report.failures,
      contains(
        'profile bad-cost-profile outputTokenCostMicros must be at least 1',
      ),
    );
  });

  test('rejects invalid tuning policy gates', () {
    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: const [],
      profiles: const [],
      policy: const EvalTuningPolicy(
        name: '',
        minScenarioCount: -1,
        minCalibrationEvaluatedPerPromptVariant: -1,
        minCalibrationEvaluatedPerModelClassPromptVariant: -1,
        minProtectedCalibrationEvaluatedPerModelClassPromptVariant: -1,
        minCalibrationPassAgreementPerPromptVariant: 1.1,
        minCalibrationScoreAgreementPerPromptVariant: -0.1,
        minCalibrationScoreAgreementLowerBound: double.nan,
        minOutcomeJudgedTraceCoverageRate: -0.1,
        minJudgePassRate: 1.1,
        minJudgePassRateLowerBound: double.nan,
        minMeanQuality: 6,
        maxMeanTokensPerTraceBudgetRatio: 0,
        maxMeanWeightedCostPerTraceBudgetRatio: double.nan,
        requiredCalibrationSetVersion: ' ',
        requireCalibrationTemplateSelection: true,
        maxCalibrationFalsePassCount: -1,
        maxCalibrationFalsePassRate: 1.01,
        maxCalibrationFalseFailRate: -0.01,
        requiredPrimaryCapabilityIds: {''},
        minBlindedPairwisePreferenceDecisions: -1,
        requiredBlindedPairwisePreferenceComparisonKeys: {''},
        blindedPairwisePreferencePolicy: EvalPairwisePreferencePolicy(
          minVotes: 0,
          quorumFraction: double.nan,
          requireModelIdentityBlind: false,
          requirePeerVoteBlind: false,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(report.failures, contains('policy name must not be empty'));
    expect(
      report.failures,
      contains('policy minScenarioCount must be at least 0'),
    );
    expect(
      report.failures,
      contains(
        'policy minCalibrationEvaluatedPerPromptVariant must be at least 0',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minCalibrationPassAgreementPerPromptVariant must be between '
        '0 and 1',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minCalibrationEvaluatedPerModelClassPromptVariant must be at '
        'least 0',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minProtectedCalibrationEvaluatedPerModelClassPromptVariant '
        'must be at least 0',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minCalibrationScoreAgreementPerPromptVariant must be between '
        '0 and 1',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minCalibrationScoreAgreementLowerBound must be between 0 and 1',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minOutcomeJudgedTraceCoverageRate must be between 0 and 1',
      ),
    );
    expect(
      report.failures,
      contains('policy minJudgePassRate must be between 0 and 1'),
    );
    expect(
      report.failures,
      contains('policy minJudgePassRateLowerBound must be between 0 and 1'),
    );
    expect(
      report.failures,
      contains('policy minMeanQuality must be between 0 and 5'),
    );
    expect(
      report.failures,
      contains(
        'policy maxMeanTokensPerTraceBudgetRatio must be greater than 0',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy maxMeanWeightedCostPerTraceBudgetRatio must be greater than 0',
      ),
    );
    expect(
      report.failures,
      contains('policy requiredCalibrationSetVersion must not be empty'),
    );
    expect(
      report.failures,
      contains(
        'policy requireCalibrationTemplateSelection requires '
        'requireCalibrationSourceRun',
      ),
    );
    expect(
      report.failures,
      contains('policy maxCalibrationFalsePassCount must be at least 0'),
    );
    expect(
      report.failures,
      contains('policy maxCalibrationFalsePassRate must be between 0 and 1'),
    );
    expect(
      report.failures,
      contains('policy maxCalibrationFalseFailRate must be between 0 and 1'),
    );
    expect(
      report.failures,
      contains(
        'policy requiredPrimaryCapabilityIds must not contain empty ids',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy minBlindedPairwisePreferenceDecisions must be at least 0',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy requiredBlindedPairwisePreferenceComparisonKeys must not '
        'contain empty keys',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy blindedPairwisePreferencePolicy minVotes must be at least 1',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy blindedPairwisePreferencePolicy quorumFraction must be finite '
        'and in (0, 1]',
      ),
    );
    expect(
      report.failures,
      contains(
        'policy blinded pairwise gates must require blinded import provenance',
      ),
    );
    expect(
      report.failures,
      contains('policy blinded pairwise gates must hide exact model identity'),
    );
    expect(
      report.failures,
      contains('policy blinded pairwise gates must hide profile identity'),
    );
    expect(
      report.failures,
      contains('policy blinded pairwise gates must hide peer votes'),
    );
    expect(
      report.failures,
      contains(
        'policy blinded pairwise gates must require randomized trace order',
      ),
    );
  });

  test('policy digest fingerprints model-class tuning gates', () {
    const baseline = EvalTuningPolicy.modelClassTuning(
      requiredPrimaryCapabilityIds: {'task.grooming.basic'},
    );
    const changedCapabilityContract = EvalTuningPolicy.modelClassTuning(
      requiredPrimaryCapabilityIds: {'task.grooming.labels'},
    );
    const changedPairwisePolicy = EvalTuningPolicy.modelClassTuning(
      requiredPrimaryCapabilityIds: {'task.grooming.basic'},
      minBlindedPairwisePreferenceDecisions: 4,
      blindedPairwisePreferencePolicy: EvalPairwisePreferencePolicy(
        minVotes: 2,
        quorumFraction: 1,
        requireProfileBlind: true,
        requireTraceOrderRandomized: true,
        requireBlindedImport: true,
      ),
    );
    const optionalPolicyEvidence = EvalTuningPolicy(
      name: 'manifestEvidenceGate',
      requireManifest: true,
    );
    const requiredPolicyEvidence = EvalTuningPolicy(
      name: 'manifestEvidenceGate',
      requireManifest: true,
      requireManifestPolicyEvidence: true,
    );

    expect(baseline.policyDigest, startsWith('sha256:'));
    expect(
      baseline.toJson()['requiredModelClasses'],
      [
        EvalModelClass.frontierFast.name,
        EvalModelClass.frontierReasoning.name,
        EvalModelClass.localReasoning.name,
        EvalModelClass.localSmall.name,
      ],
    );
    expect(
      baseline.toJson()['blindedPairwisePreferencePolicy'],
      containsPair('requireBlindedImport', true),
    );
    expect(baseline.toJson(), containsPair('requireAllJudgePasses', true));
    expect(
      baseline.toJson(),
      containsPair('requireOutcomeSliceThresholds', true),
    );
    expect(baseline.toJson(), containsPair('minJudgePassRate', 1.0));
    expect(
      baseline.toJson(),
      containsPair('minJudgePassRateLowerBound', 0.7),
    );
    expect(baseline.toJson(), containsPair('minMeanQuality', 4.0));
    expect(
      baseline.toJson(),
      containsPair('maxMeanTokensPerTraceBudgetRatio', 1.0),
    );
    expect(
      baseline.toJson(),
      containsPair('maxMeanWeightedCostPerTraceBudgetRatio', 1.0),
    );
    expect(
      baseline.toJson(),
      containsPair('requireWeightedCostEvidence', true),
    );
    expect(baseline.requireCalibrationSourceRun, isTrue);
    expect(
      baseline.toJson(),
      containsPair('requireCalibrationSourceRun', true),
    );
    expect(baseline.requireManifestPolicyEvidence, isTrue);
    expect(
      baseline.toJson(),
      containsPair('requireManifestPolicyEvidence', true),
    );
    expect(
      baseline.toJson(),
      containsPair('minScenariosPerRequiredCapabilitySplit', 1),
    );
    expect(
      baseline.toJson(),
      containsPair('requireAdversarialTagCoveragePerAgentKind', true),
    );
    expect(
      baseline.toJson(),
      containsPair('minProtectedHoldoutScenariosPerRequiredCapability', 1),
    );
    expect(
      baseline.toJson(),
      containsPair('minCalibrationEvaluatedPerModelClassCapability', 1),
    );
    expect(baseline.requireProtectedCalibrationHoldout, isTrue);
    expect(
      baseline.toJson(),
      containsPair('requireProtectedCalibrationHoldout', true),
    );
    expect(
      baseline.toJson(),
      containsPair('minProtectedCalibrationEvaluatedCount', 4),
    );
    expect(
      baseline.toJson(),
      containsPair('minProtectedCalibrationEvaluatedPerModelClass', 1),
    );
    expect(
      baseline.toJson(),
      containsPair('minProtectedCalibrationEvaluatedPerCapability', 1),
    );
    expect(
      baseline.toJson(),
      containsPair(
        'minProtectedCalibrationEvaluatedPerModelClassCapability',
        1,
      ),
    );
    expect(
      changedCapabilityContract.policyDigest,
      isNot(baseline.policyDigest),
    );
    expect(changedPairwisePolicy.policyDigest, isNot(baseline.policyDigest));
    expect(
      requiredPolicyEvidence.policyDigest,
      isNot(optionalPolicyEvidence.policyDigest),
    );
  });

  test('development smoke policy passes a complete unjudged smoke run', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: localSmall,
        judged: false,
      ),
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: localSmall,
        trialIndex: 1,
        judged: false,
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [localSmall],
    );

    expect(report.ready, isTrue);
    expect(report.evidenceLabel, 'development-smoke');
    expect(report.warnings, contains('not all traces are judged: 0/2'));
    expect(
      EvalTuningReadiness.render(report),
      contains('Tuning readiness (developmentSmoke): development-smoke'),
    );
    expect(
      EvalTuningReadiness.render(report),
      contains('policyDigest=sha256:'),
    );
  });

  test('default readiness keeps pairwise votes diagnostic only', () {
    const baseline = EvalProfile(
      name: 'pairwise-local-test',
      isLocal: true,
      modelClass: EvalModelClass.localSmall,
      modelId: 'pairwise-local-model',
      tokenBudget: 6000,
    );
    const candidate = EvalProfile(
      name: 'pairwise-frontier-test',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'pairwise-frontier-model',
      tokenBudget: 60000,
    );
    final scenario = _scenarioWith(
      taskReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.pairwise.diagnostic',
    );
    final baselineTrace = _trace(scenario: scenario, profile: baseline);
    final candidateTrace = _trace(scenario: scenario, profile: candidate);
    final report = EvalTuningReadiness.assess(
      traces: [baselineTrace, candidateTrace],
      scenarios: [scenario],
      profiles: const [baseline, candidate],
      pairwisePreferenceVotes: [
        _pairwiseVote(
          optionA: _pairwiseRef(baselineTrace),
          optionB: _pairwiseRef(candidateTrace),
          profileVisible: true,
          modelIdentityVisible: true,
          peerVotesVisible: true,
          traceOrderRandomized: false,
        ),
      ],
      policy: const EvalTuningPolicy(name: 'diagnosticPairwise'),
    );

    expect(report.ready, isTrue);
    expect(report.failures, isEmpty);
    expect(report.pairwisePreferenceEvidence?.invalidCount, 1);
    expect(
      EvalTuningReadiness.render(report),
      contains('pairwise preferences decisions=0 pairs=1 votes=1 invalid=1'),
    );
  });

  test('blinded pairwise gate requires enough imported decisions', () {
    final scenario = _scenarioWith(
      taskReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.pairwise.required',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );

    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      policy: const EvalTuningPolicy(
        name: 'pairwiseRequired',
        requireCompleteTraceMatrix: false,
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {
          'profile::registered-but-missing',
        },
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains('blinded pairwise preference decisions 0 < 1'),
    );
    expect(report.pairwisePreferenceEvidence?.decisionCount, 0);
    expect(
      EvalTuningReadiness.render(report),
      contains('pairwise preferences decisions=0/1 pairs=0 votes=0'),
    );
  });

  test('blinded pairwise gates require explicit registrations', () {
    final scenario = _scenarioWith(
      taskReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.pairwise.registration',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );

    final noRegistration = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      policy: const EvalTuningPolicy(
        name: 'pairwiseNoRegistration',
        requireCompleteTraceMatrix: false,
        minBlindedPairwisePreferenceDecisions: 1,
      ),
    );
    final impossibleMinimum = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      policy: const EvalTuningPolicy(
        name: 'pairwiseImpossibleMinimum',
        requireCompleteTraceMatrix: false,
        minBlindedPairwisePreferenceDecisions: 2,
        requiredBlindedPairwisePreferenceComparisonKeys: {
          'profile::only-registered-key',
        },
      ),
    );

    expect(
      noRegistration.failures,
      contains(
        'policy requiredBlindedPairwisePreferenceComparisonKeys must not be '
        'empty when blinded pairwise decisions are required without intent keys',
      ),
    );
    expect(
      impossibleMinimum.failures,
      contains(
        'policy minBlindedPairwisePreferenceDecisions cannot exceed '
        'registered pairwise key count 1',
      ),
    );
  });

  test('pairwise readiness policy serializes intent keys separately', () {
    const expectation = EvalPairwiseReadinessOutcomeExpectation(
      preferredOptionKey: 'candidate-option',
      requirement: EvalPairwiseReadinessOutcomeRequirement.mustNotLose,
    );
    const policy = EvalTuningPolicy.modelClassTuning(
      minBlindedPairwisePreferenceDecisions: 1,
      requiredBlindedPairwisePreferenceComparisonKeys: {
        'profile::post-run-comparison-key',
      },
      requiredBlindedPairwisePreferenceIntentKeys: {
        'profile::pre-run-intent-key',
      },
      requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey: {
        'profile::post-run-comparison-key': expectation,
      },
      requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey: {
        'profile::pre-run-intent-key': expectation,
      },
      blindedPairwisePreferencePolicy: EvalPairwisePreferencePolicy(
        minVotes: 1,
        quorumFraction: 1,
        requireProfileBlind: true,
        requireTraceOrderRandomized: true,
        requireBlindedImport: true,
      ),
    );

    expect(policy.requiresBlindedPairwisePreferences, isTrue);
    expect(
      policy.toJson()['requiredBlindedPairwisePreferenceComparisonKeys'],
      isEmpty,
    );
    expect(
      policy.toJson()['requiredBlindedPairwisePreferenceIntentKeys'],
      ['profile::pre-run-intent-key'],
    );
    expect(
      policy
          .toJson()['requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey'],
      isEmpty,
    );
    expect(
      policy
          .toJson()['requiredBlindedPairwisePreferenceOutcomeExpectationsByIntentKey'],
      {
        'profile::pre-run-intent-key': expectation.toJson(),
      },
    );
    expect(policy.policyDigest, startsWith('sha256:'));
  });

  test('blinded pairwise gate rejects self-attested blinding', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseImportRequired',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(report.pairwisePreferenceEvidence?.invalidCount, 1);
    expect(
      report.failures.any(
        (failure) =>
            failure.startsWith('blinded pairwise preference ') &&
            failure.contains('missing blinded pairwise import provenance'),
      ),
      isTrue,
    );
  });

  test('blinded pairwise gate rejects no-consensus quorums', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final sourceManifestDigest = manifest.manifestDigest!;
    final optionA = bench.optionA;
    final optionB = bench.optionB;
    final voteA = _pairwiseVote(
      voteId: 'pairwise-vote-a',
      reviewerId: 'pairwise-reviewer-a',
      optionA: optionA,
      optionB: optionB,
      imported: true,
      sourceManifestDigest: sourceManifestDigest,
    );
    final voteB = _pairwiseVote(
      voteId: 'pairwise-vote-b',
      reviewerId: 'pairwise-reviewer-b',
      optionA: optionA,
      optionB: optionB,
      choice: EvalPairwisePreferenceChoice.optionB,
      imported: true,
      sourceManifestDigest: sourceManifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [voteA, voteB],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([optionA, optionB]),
      policy: EvalTuningPolicy(
        name: 'pairwiseConsensusRequired',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {voteA.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 2,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(report.pairwisePreferenceEvidence?.noConsensusCount, 1);
    expect(
      report.failures.any(
        (failure) =>
            failure.startsWith('blinded pairwise preference ') &&
            failure.contains('has no consensus') &&
            failure.contains('no choice reached quorum'),
      ),
      isTrue,
    );
  });

  test('blinded pairwise gate rejects forged import provenance', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      blindedImport: BlindedPairwisePreferenceImportRecord(
        blindedPairId: 'pair-0001',
        reviewPayloadDigest: EvalProvenance.digestText('review'),
        judgeManifestDigest: EvalProvenance.digestText('judge'),
        privateKeyDigest: EvalProvenance.digestText('key'),
        sourceManifestDigest: EvalProvenance.digestText('wrong-run'),
        optionARawTraceDigest: EvalProvenance.digestText('wrong-option-a'),
        optionBRawTraceDigest: bench.optionB.traceDigest,
      ),
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseImportProvenance',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures.any(
        (failure) => failure.contains(
          'optionARawTraceDigest does not match option A traceDigest',
        ),
      ),
      isTrue,
    );
    expect(
      report.failures.any(
        (failure) => failure.contains('sourceManifestDigest is '),
      ),
      isTrue,
    );
  });

  test('blinded pairwise gate rejects stale trace bindings', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final staleOptionA = _pairwiseRefWithTraceDigest(
      bench.optionA,
      EvalProvenance.digestText('stale-option-a-trace'),
    );
    final vote = _pairwiseVote(
      optionA: staleOptionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseTraceBinding',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures.any(
        (failure) =>
            failure.startsWith(
              'blinded pairwise preference pairwise-vote-1 trace binding is '
              'invalid',
            ) &&
            failure.contains('option A traceDigest is '),
      ),
      isTrue,
    );
  });

  test('blinded pairwise gate requires raw trace refs', () {
    final bench = _pairwiseBench();
    final draftVote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
    );
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
      pairwiseReadinessPlanEvidence: _pairwiseReadinessPlanEvidenceFor(
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        comparisonKeys: {draftVote.comparisonKey},
      ),
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      policy: EvalTuningPolicy(
        name: 'pairwiseRawRefsRequired',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'raw pairwise trace refs are required for blinded pairwise gates',
      ),
    );
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
  });

  test('blinded pairwise gate rejects in-memory trace digests', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final forgedOptionA = _pairwiseRefWithTraceDigest(
      bench.optionA,
      EvalProvenance.digestJson(bench.traces.first.toJson()),
    );
    final vote = _pairwiseVote(
      optionA: forgedOptionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    expect(forgedOptionA.traceDigest, isNot(bench.optionA.traceDigest));

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseCanonicalJsonForgery',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures.any(
        (failure) =>
            failure.contains('option A traceDigest is ') &&
            failure.contains('expected ${bench.optionA.traceDigest}'),
      ),
      isTrue,
    );
  });

  test('blinded pairwise gate requires manifest-bound plan evidence', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseSidecarOnly',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'run manifest pairwiseReadinessPlanEvidence is required for '
        'blinded pairwise gates',
      ),
    );
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
  });

  test('blinded pairwise gate rejects plan digest drift', () {
    final bench = _pairwiseBench();
    final draftVote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
    );
    final driftedEvidence = EvalPairwiseReadinessPlanEvidence(
      planId: 'readiness-pairwise-plan',
      baseReadinessPolicy: 'modelClassTuning',
      scenarioSetDigest: EvalProvenance.digestText('other-scenarios'),
      profileSetDigest: EvalProvenance.digestText('other-profiles'),
      profileBindingSetDigest: EvalProvenance.digestText('other-bindings'),
      minBlindedPairwisePreferenceDecisions: 1,
      comparisonCount: 1,
      pairwiseReadinessPlanSubjectDigest: EvalProvenance.digestJson({
        'planId': 'readiness-pairwise-plan',
        'comparisonKeys': [draftVote.comparisonKey],
      }),
    );
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
      pairwiseReadinessPlanEvidence: driftedEvidence,
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwisePlanDigestBinding',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'run manifest pairwiseReadinessPlanEvidence scenarioSetDigest is '
        '${driftedEvidence.scenarioSetDigest}, expected '
        '${manifest.scenarioSetDigest}',
      ),
    );
    expect(
      report.failures,
      contains(
        'run manifest pairwiseReadinessPlanEvidence profileSetDigest is '
        '${driftedEvidence.profileSetDigest}, expected '
        '${manifest.profileSetDigest}',
      ),
    );
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
  });

  test('blinded pairwise gate accepts pre-registered imported decisions', () {
    final bench = _pairwiseBench();
    final draftVote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      choice: EvalPairwisePreferenceChoice.optionB,
      imported: true,
    );
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
      pairwiseReadinessPlanEvidence: _pairwiseReadinessPlanEvidenceFor(
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        comparisonKeys: {draftVote.comparisonKey},
      ),
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      choice: EvalPairwisePreferenceChoice.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseGate',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {vote.comparisonKey},
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isTrue);
    expect(report.evidenceLabel, 'tuning-ready');
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
    expect(
      report.pairwisePreferenceEvidence?.missingRequiredComparisonKeys,
      isEmpty,
    );
    expect(
      report.pairwisePreferenceEvidence?.summaries.single.hasDecision,
      isTrue,
    );
    expect(
      EvalTuningReadiness.render(report),
      contains('pairwise preferences decisions=1/1 pairs=1 votes=1'),
    );
  });

  test('blinded pairwise outcome gate rejects candidate losses', () {
    final bench = _pairwiseBench();
    final draftVote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
    );
    final candidateExpectation = EvalPairwiseReadinessOutcomeExpectation(
      preferredOptionKey: _pairwiseIntentOptionKey(bench.optionB),
      requirement: EvalPairwiseReadinessOutcomeRequirement.mustNotLose,
    );
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
      pairwiseReadinessPlanEvidence: _pairwiseReadinessPlanEvidenceFor(
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        comparisonKeys: {draftVote.comparisonKey},
      ),
    );
    final baselineWin = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [baselineWin],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseCandidateMustNotLose',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {
          baselineWin.comparisonKey,
        },
        requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey: {
          baselineWin.comparisonKey: candidateExpectation,
        },
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
    expect(report.pairwisePreferenceEvidence?.satisfiedOutcomeCount, 0);
    expect(report.pairwisePreferenceEvidence?.failedOutcomeComparisonKeys, {
      baselineWin.comparisonKey,
    });
    expect(
      report.failures,
      contains(
        'blinded pairwise preference ${baselineWin.comparisonKey} outcome '
        'optionBWins does not satisfy ${candidateExpectation.describe()}',
      ),
    );
    expect(
      report.failures,
      contains('blinded pairwise preference decisions 0 < 1'),
    );
  });

  test('blinded pairwise outcome gate handles ties explicitly', () {
    final bench = _pairwiseBench();
    final draftVote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
    );
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
      pairwiseReadinessPlanEvidence: _pairwiseReadinessPlanEvidenceFor(
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        comparisonKeys: {draftVote.comparisonKey},
      ),
    );
    final tieVote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      choice: EvalPairwisePreferenceChoice.tie,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    EvalTuningReadinessReport assessWith(
      EvalPairwiseReadinessOutcomeRequirement requirement,
    ) {
      final expectation = EvalPairwiseReadinessOutcomeExpectation(
        preferredOptionKey: _pairwiseIntentOptionKey(bench.optionB),
        requirement: requirement,
      );
      return EvalTuningReadiness.assess(
        traces: bench.traces,
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        manifest: manifest,
        pairwisePreferenceVotes: [tieVote],
        pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
          bench.optionA,
          bench.optionB,
        ]),
        policy: EvalTuningPolicy(
          name: 'pairwiseTieSemantics',
          minBlindedPairwisePreferenceDecisions: 1,
          requiredBlindedPairwisePreferenceComparisonKeys: {
            tieVote.comparisonKey,
          },
          requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey: {
            tieVote.comparisonKey: expectation,
          },
          blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
            minVotes: 1,
            quorumFraction: 1,
            requireProfileBlind: true,
            requireTraceOrderRandomized: true,
            requireBlindedImport: true,
          ),
        ),
      );
    }

    final noLossReport = assessWith(
      EvalPairwiseReadinessOutcomeRequirement.mustNotLose,
    );
    final mustWinReport = assessWith(
      EvalPairwiseReadinessOutcomeRequirement.mustWin,
    );

    expect(noLossReport.ready, isTrue);
    expect(noLossReport.pairwisePreferenceEvidence?.satisfiedOutcomeCount, 1);
    expect(mustWinReport.ready, isFalse);
    expect(mustWinReport.pairwisePreferenceEvidence?.satisfiedOutcomeCount, 0);
    expect(
      mustWinReport.failures.any(
        (failure) =>
            failure.contains('outcome tie does not satisfy') &&
            failure.contains('must win'),
      ),
      isTrue,
    );
  });

  test('blinded pairwise outcome gate survives randomized option order', () {
    final bench = _pairwiseBench();
    final draftVote = _pairwiseVote(
      optionA: bench.optionB,
      optionB: bench.optionA,
      imported: true,
    );
    final candidateExpectation = EvalPairwiseReadinessOutcomeExpectation(
      preferredOptionKey: _pairwiseIntentOptionKey(bench.optionB),
      requirement: EvalPairwiseReadinessOutcomeRequirement.mustWin,
    );
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
      pairwiseReadinessPlanEvidence: _pairwiseReadinessPlanEvidenceFor(
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        comparisonKeys: {draftVote.comparisonKey},
      ),
    );
    final candidateWin = _pairwiseVote(
      optionA: bench.optionB,
      optionB: bench.optionA,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [candidateWin],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseCandidateWinRandomizedOrder',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {
          candidateWin.comparisonKey,
        },
        requiredBlindedPairwisePreferenceOutcomeExpectationsByComparisonKey: {
          candidateWin.comparisonKey: candidateExpectation,
        },
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isTrue);
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
    expect(report.pairwisePreferenceEvidence?.satisfiedOutcomeCount, 1);
    expect(
      report.pairwisePreferenceEvidence?.failedOutcomeComparisonKeys,
      isEmpty,
    );
  });

  test('blinded pairwise gate rejects unregistered comparisons', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final sourceManifestDigest = manifest.manifestDigest!;
    const tunedVariant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final tunedTrace = _trace(
      scenario: bench.scenario,
      profile: bench.profiles.first,
      agentDirectiveVariant: tunedVariant,
    );
    final registeredVote = _pairwiseVote(
      voteId: 'registered-profile-vote',
      reviewerId: 'registered-profile-reviewer',
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: sourceManifestDigest,
    );
    final extraVote = _pairwiseVote(
      voteId: 'unregistered-prompt-variant-vote',
      reviewerId: 'unregistered-prompt-variant-reviewer',
      optionA: _pairwiseRef(bench.traces.first),
      optionB: _pairwiseRef(tunedTrace),
      imported: true,
      sourceManifestDigest: sourceManifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: [...bench.traces, tunedTrace],
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [registeredVote, extraVote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
        _pairwiseRef(tunedTrace),
      ]),
      policy: EvalTuningPolicy(
        name: 'pairwiseRegisteredPlan',
        requireCompleteTraceMatrix: false,
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {
          registeredVote.comparisonKey,
        },
        blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(report.pairwisePreferenceEvidence?.decisionCount, 1);
    expect(report.pairwisePreferenceEvidence?.unregisteredComparisonKeys, {
      extraVote.comparisonKey,
    });
    expect(
      report.failures,
      contains(
        'unregistered blinded pairwise preference comparison '
        '${extraVote.comparisonKey}',
      ),
    );
  });

  test(
    'blinded pairwise gate rejects mixed protocols across registered keys',
    () {
      final bench = _pairwiseBench();
      final manifest = _manifestFor(
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        targetKind: 'live',
      );
      final sourceManifestDigest = manifest.manifestDigest!;
      const tunedVariant = EvalAgentDirectiveVariant(
        name: 'metadata-first-v2',
        generalDirective: 'Write durable metadata before summaries.',
      );
      final tunedTrace = _trace(
        scenario: bench.scenario,
        profile: bench.profiles.first,
        agentDirectiveVariant: tunedVariant,
      );
      final profileVote = _pairwiseVote(
        voteId: 'profile-protocol-vote',
        reviewerId: 'profile-protocol-reviewer',
        optionA: bench.optionA,
        optionB: bench.optionB,
        imported: true,
        sourceManifestDigest: sourceManifestDigest,
      );
      final differentPromptDigest = EvalProvenance.digestText(
        'different-pairwise-prompt',
      );
      final promptVariantVote = _pairwiseVote(
        voteId: 'variant-protocol-vote',
        reviewerId: 'variant-protocol-reviewer',
        optionA: _pairwiseRef(bench.traces.first),
        optionB: _pairwiseRef(tunedTrace),
        imported: true,
        promptDigest: differentPromptDigest,
        sourceManifestDigest: sourceManifestDigest,
      );

      final report = EvalTuningReadiness.assess(
        traces: [...bench.traces, tunedTrace],
        scenarios: [bench.scenario],
        profiles: bench.profiles,
        manifest: manifest,
        pairwisePreferenceVotes: [profileVote, promptVariantVote],
        pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
          bench.optionA,
          bench.optionB,
          _pairwiseRef(tunedTrace),
        ]),
        policy: EvalTuningPolicy(
          name: 'pairwiseUniformProtocol',
          requireCompleteTraceMatrix: false,
          minBlindedPairwisePreferenceDecisions: 2,
          requiredBlindedPairwisePreferenceComparisonKeys: {
            profileVote.comparisonKey,
            promptVariantVote.comparisonKey,
          },
          blindedPairwisePreferencePolicy: const EvalPairwisePreferencePolicy(
            minVotes: 1,
            quorumFraction: 1,
            requireProfileBlind: true,
            requireTraceOrderRandomized: true,
            requireBlindedImport: true,
          ),
        ),
      );

      expect(report.ready, isFalse);
      expect(report.pairwisePreferenceEvidence?.decisionCount, 2);
      expect(
        report.pairwisePreferenceEvidence?.reviewProtocolKeys,
        hasLength(2),
      );
      expect(
        report.failures.any(
          (failure) =>
              failure.startsWith(
                'blinded pairwise preference gate has mixed review protocols',
              ) &&
              failure.contains(differentPromptDigest),
        ),
        isTrue,
      );
    },
  );

  test('blinded pairwise gate requires registered comparison keys', () {
    final bench = _pairwiseBench();
    final manifest = _manifestFor(
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      targetKind: 'live',
    );
    final vote = _pairwiseVote(
      optionA: bench.optionA,
      optionB: bench.optionB,
      imported: true,
      sourceManifestDigest: manifest.manifestDigest,
    );

    final report = EvalTuningReadiness.assess(
      traces: bench.traces,
      scenarios: [bench.scenario],
      profiles: bench.profiles,
      manifest: manifest,
      pairwisePreferenceVotes: [vote],
      pairwiseTraceRefsByKey: _pairwiseTraceRefsByKey([
        bench.optionA,
        bench.optionB,
      ]),
      policy: const EvalTuningPolicy(
        name: 'pairwiseKeyGate',
        minBlindedPairwisePreferenceDecisions: 1,
        requiredBlindedPairwisePreferenceComparisonKeys: {
          'profile::pre-registered-missing-key',
        },
        blindedPairwisePreferencePolicy: EvalPairwisePreferencePolicy(
          minVotes: 1,
          quorumFraction: 1,
          requireProfileBlind: true,
          requireTraceOrderRandomized: true,
          requireBlindedImport: true,
        ),
      ),
    );

    expect(report.ready, isFalse);
    expect(report.pairwisePreferenceEvidence?.decisionCount, 0);
    expect(report.pairwisePreferenceEvidence?.missingRequiredComparisonKeys, {
      'profile::pre-registered-missing-key',
    });
    expect(report.pairwisePreferenceEvidence?.unregisteredComparisonKeys, {
      vote.comparisonKey,
    });
    expect(
      report.failures,
      contains(
        'missing blinded pairwise preference comparison '
        'profile::pre-registered-missing-key',
      ),
    );
    expect(
      report.failures,
      contains(
        'unregistered blinded pairwise preference comparison '
        '${vote.comparisonKey}',
      ),
    );
  });

  test('rejects cascade wake traces as tuning-ready evidence', () {
    final scenario = taskWorkflowChecklistTranscriptCascadeScenario;
    final report = EvalTuningReadiness.assess(
      traces: [
        _trace(
          scenario: scenario,
          profile: localSmall,
          judged: false,
          cascadeWake: EvalTraceCascadeWake(
            cascadeId: EvalTraceCascadeWake.taskLogCascadeId,
            wakeIndex: 0,
            wakeCount: scenario.appState.taskLogEntries.length,
          ),
        ),
      ],
      scenarios: [scenario],
      profiles: const [localSmall],
    );

    expect(
      report.failures,
      contains('cascade wake traces are not tuning-ready evidence: 1'),
    );
  });

  test('model-class tuning policy rejects cherry-picked evidence', () {
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      policy: const EvalTuningPolicy.modelClassTuning(
        requiredCalibrationSetVersion: 'gold-v1',
      ),
    );

    expect(report.ready, isFalse);
    expect(report.evidenceLabel, 'development-smoke');
    expect(report.failures, contains('run manifest is required'));
    expect(
      report.failures,
      contains('protected holdout evidence is missing'),
    );
    expect(report.failures, contains('scenario count 1 < 12'));
    expect(report.failures, contains('adversarial scenario count 0 < 4'));
    expect(
      report.failures,
      contains('production-replay holdout scenario count 0 < 4'),
    );
    expect(
      report.failures,
      contains('protected holdout scenario count 0 < 4'),
    );
    expect(
      report.failures,
      contains('taskAgent protected holdout scenario count 0 < 2'),
    );
    expect(report.failures, contains('missing adversarial tag stale-state'));
    expect(
      report.failures,
      contains('model class localSmall profile count 0 < 1'),
    );
    expect(report.failures, contains('missing holdout scenarios'));
    expect(
      report.failures,
      contains('profile frontier-fast-test trialCount 2 < 3'),
    );
    expect(
      report.failures,
      contains(
        'missing trace for task_release_notes::frontier-fast-test::trial-1',
      ),
    );
    expect(report.failures, contains('judge calibration report is required'));
  });

  test('manifest target and digest gates reject subset evidence', () {
    final canonicalScenarios = [
      taskReleaseNotesScenario,
      plannerCaptureOnlyScenario,
    ];
    final traces = [
      _trace(
        scenario: taskReleaseNotesScenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
    ];
    final subsetManifest = _manifestFor(
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      targetKind: 'scripted',
    );

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: canonicalScenarios,
      profiles: const [frontierFast],
      manifest: subsetManifest,
      policy: EvalTuningPolicy(
        name: 'officialSubsetGuard',
        minScenarioCount: 2,
        requireManifest: true,
        requiredTargetKind: 'live',
        expectedScenarioSetDigest: EvalProvenance.scenarioSetDigest(
          canonicalScenarios,
        ),
        expectedProfileSetDigest: EvalProvenance.profileSetDigest(
          [frontierFast],
        ),
        requireAllVerdicts: true,
      ),
    );

    expect(
      report.failures.any(
        (failure) => failure.startsWith('manifest scenarioSetDigest is '),
      ),
      isTrue,
    );
    expect(
      report.failures,
      contains('manifest targetKind is scripted, expected live'),
    );
    expect(
      report.failures,
      contains(
        'missing trace for '
        'planner_capture_only_parse::frontier-fast-test::trial-0',
      ),
    );
  });

  test('model-class tuning requires manifest-bound policy evidence', () {
    const policy = EvalTuningPolicy.modelClassTuning(
      requiredCalibrationSetVersion: 'gold-v1',
    );
    final missingEvidenceManifest = _manifestFor(
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );
    final boundEvidenceManifest = _manifestFor(
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      targetKind: 'live',
      tuningReadinessPolicyEvidence: EvalTuningReadinessPolicyEvidence(
        policyName: policy.name,
        policyDigest: policy.policyDigest,
      ),
    );
    final driftedEvidenceManifest = _manifestFor(
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      targetKind: 'live',
      tuningReadinessPolicyEvidence: EvalTuningReadinessPolicyEvidence(
        policyName: policy.name,
        policyDigest: EvalProvenance.digestText('stale-policy'),
      ),
    );

    final missingEvidenceReport = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      manifest: missingEvidenceManifest,
      policy: policy,
    );
    final boundEvidenceReport = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      manifest: boundEvidenceManifest,
      policy: policy,
    );
    final driftedEvidenceReport = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      manifest: driftedEvidenceManifest,
      policy: policy,
    );
    final smokeReport = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      manifest: missingEvidenceManifest,
    );
    final diagnosticReport = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [frontierFast],
      manifest: missingEvidenceManifest,
      policy: const EvalTuningPolicy(
        name: 'diagnosticPolicy',
        requireManifest: true,
      ),
    );

    expect(
      missingEvidenceReport.failures,
      contains(
        'run manifest tuningReadinessPolicyEvidence is required for '
        'modelClassTuning',
      ),
    );
    expect(
      boundEvidenceReport.failures,
      isNot(
        contains(
          'run manifest tuningReadinessPolicyEvidence is required for '
          'modelClassTuning',
        ),
      ),
    );
    expect(
      driftedEvidenceReport.failures,
      contains(
        'manifest tuningReadinessPolicyEvidence policyDigest is '
        '${EvalProvenance.digestText('stale-policy')}, expected '
        '${policy.policyDigest}',
      ),
    );
    expect(
      smokeReport.failures,
      isNot(
        contains(
          'run manifest tuningReadinessPolicyEvidence is required for '
          'developmentSmoke',
        ),
      ),
    );
    expect(
      diagnosticReport.failures,
      isNot(
        contains(
          'run manifest tuningReadinessPolicyEvidence is required for '
          'diagnosticPolicy',
        ),
      ),
    );
  });

  test('tuning policy rejects model-identity-visible judge verdicts', () {
    const singleTrialProfile = EvalProfile(
      name: 'frontier-blind-test',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-blind-model',
      tokenBudget: 60000,
    );
    final trace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: singleTrialProfile,
      calibrationSetVersion: 'gold-v1',
      modelIdentityVisible: true,
    );

    final report = EvalTuningReadiness.assess(
      traces: [trace],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [singleTrialProfile],
      policy: const EvalTuningPolicy(
        name: 'blindJudgeVerdicts',
        requireAllVerdicts: true,
        requireBlindedJudgeVerdicts: true,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'unblinded judge verdict for '
        'task_release_notes::frontier-blind-test::trial-0',
      ),
    );
  });

  test('tuning policy rejects forged blinded judge verdict provenance', () {
    const singleTrialProfile = EvalProfile(
      name: 'frontier-forged-blind-test',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-blind-model',
      tokenBudget: 60000,
    );
    final manifest = _manifestFor(
      scenarios: [taskReleaseNotesScenario],
      profiles: const [singleTrialProfile],
      targetKind: 'live',
    );
    final missingImportTrace = _trace(
      scenario: taskReleaseNotesScenario,
      profile: singleTrialProfile,
      calibrationSetVersion: 'gold-v1',
      includeBlindedImport: false,
      manifestDigest: manifest.manifestDigest,
    );
    final staleImportTrace = missingImportTrace.withVerdict(
      missingImportTrace.verdict!.withBlindedImport(
        BlindedVerdictImportRecord(
          blindedTraceId: 'blind-0001',
          reviewPayloadDigest: EvalProvenance.digestText('review-payload'),
          judgeManifestDigest: EvalProvenance.digestText('judge-manifest'),
          privateKeyDigest: EvalProvenance.digestText('private-key'),
          sourceManifestDigest: EvalProvenance.digestText('wrong-manifest'),
          rawTraceDigest: EvalProvenance.digestText('wrong-raw-trace'),
        ),
      ),
    );

    final missingImportReport = EvalTuningReadiness.assess(
      traces: [missingImportTrace],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [singleTrialProfile],
      manifest: manifest,
      policy: const EvalTuningPolicy(
        name: 'blindJudgeVerdicts',
        requireAllVerdicts: true,
        requireBlindedJudgeVerdicts: true,
      ),
    );
    final staleImportReport = EvalTuningReadiness.assess(
      traces: [staleImportTrace],
      scenarios: [taskReleaseNotesScenario],
      profiles: const [singleTrialProfile],
      manifest: manifest,
      policy: const EvalTuningPolicy(
        name: 'blindJudgeVerdicts',
        requireAllVerdicts: true,
        requireBlindedJudgeVerdicts: true,
      ),
    );

    expect(missingImportReport.ready, isFalse);
    expect(
      missingImportReport.failures,
      contains(
        'task_release_notes::frontier-forged-blind-test::trial-0 '
        'blinded judge verdict provenance: missing blindedImport',
      ),
    );
    expect(staleImportReport.ready, isFalse);
    expect(
      staleImportReport.failures,
      contains(
        'task_release_notes::frontier-forged-blind-test::trial-0 '
        'blinded judge verdict provenance: sourceManifestDigest is '
        '${EvalProvenance.digestText('wrong-manifest')}, expected '
        '${manifest.manifestDigest}',
      ),
    );
    expect(
      staleImportReport.failures,
      contains(
        'task_release_notes::frontier-forged-blind-test::trial-0 '
        'blinded judge verdict provenance: rawTraceDigest is '
        '${EvalProvenance.digestText('wrong-raw-trace')}, expected '
        '${missingImportTrace.verdict!.traceDigest}',
      ),
    );
  });

  test('custom tuning policy passes a complete judged calibrated matrix', () {
    final taskScenario = _reviewedScenario(
      _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        split: EvalScenarioSplit.development,
        capabilityId: 'task.tuning.ready',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {
          'adversarial',
          'ambiguous-reference',
          'scope-boundary',
        },
      ),
    );
    final plannerScenario = _reviewedScenario(
      _scenarioWith(
        plannerCaptureOnlyScenario,
        split: EvalScenarioSplit.holdout,
        capabilityId: 'planner.tuning.ready',
        source: EvalScenarioSource.productionReplay,
        tags: {'production-replay'},
      ),
    );
    const profiles = [localSmall, frontierFast];
    final scenarios = [taskScenario, plannerScenario];
    final manifest = _manifestFor(
      scenarios: scenarios,
      profiles: profiles,
      targetKind: 'live',
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: scenarios,
        protectedHoldoutScenarioIds: [plannerScenario.id],
      ),
    );
    final traces = [
      for (final scenario in scenarios)
        for (final profile in profiles)
          for (
            var trialIndex = 0;
            trialIndex < profile.trialCount;
            trialIndex++
          )
            _trace(
              scenario: scenario,
              profile: profile,
              trialIndex: trialIndex,
              calibrationSetVersion: 'gold-v1',
            ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: scenarios,
      profiles: profiles,
      manifest: manifest,
      scenarioCatalogEvidence: manifest.scenarioCatalogEvidence,
      calibrationSet: _calibrationSetFor(traces),
      policy: EvalTuningPolicy(
        name: 'customTuning',
        requiredModelClasses: const {
          EvalModelClass.localSmall,
          EvalModelClass.frontierFast,
        },
        requiredProfileNames: const {
          'local-small-test',
          'frontier-fast-test',
        },
        requiredPrimaryCapabilityIds: const {
          'task.tuning.ready',
          'planner.tuning.ready',
        },
        requiredSplits: const {
          EvalScenarioSplit.development,
          EvalScenarioSplit.holdout,
        },
        requiredAgentKinds: const {
          AgentKind.taskAgent,
          AgentKind.planningAgent,
        },
        minScenarioCount: 2,
        minScenariosPerAgentKind: 1,
        minScenariosPerCapability: 1,
        minCapabilityCount: 2,
        minAdversarialScenarioCount: 1,
        requiredAdversarialTags: {
          'ambiguous-reference',
          'scope-boundary',
        },
        minProductionReplayHoldoutScenarios: 1,
        minProtectedHoldoutScenarios: 1,
        minTrialsPerProfile: 2,
        requireAllVerdicts: true,
        requireAllLevel1Passed: true,
        requireCalibratedVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requiredHumanCalibrationSetVersion: 'human-gold-v1',
        requireCalibrationReport: true,
        requireProtectedCalibrationHoldout: true,
        minProtectedCalibrationEvaluatedCount: 1,
        minCalibrationEvaluatedCount: 8,
        minCalibrationCoverageRate: 1,
        minCalibrationPassAgreementRate: 1,
        minCalibrationScoreAgreementRate: 1,
        maxCalibrationFalsePassRate: 0,
        maxCalibrationFalseFailRate: 0,
        requireBlindedCalibrationReport: true,
        requireCleanCalibrationReport: true,
        requireManifest: true,
        requiredTargetKind: 'live',
        expectedScenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
        expectedProfileSetDigest: EvalProvenance.profileSetDigest(profiles),
        requireProtectedHoldout: true,
        requireReviewedScenarioEvidence: true,
      ),
    );

    expect(report.ready, isTrue, reason: report.failures.join('\n'));
    expect(report.failures, isEmpty);
    expect(report.expectedTraceCount, 8);
    expect(report.traceCount, 8);
    expect(report.judgedTraceCount, 8);
    expect(report.evidence.adversarialScenarioCount, 1);
    expect(report.evidence.productionReplayHoldoutScenarioCount, 1);
    expect(report.evidence.protectedHoldoutScenarioCount, 1);
    expect(report.evidence.scenarioReviewRequiredCount, 2);
    expect(report.evidence.completedScenarioReviewCount, 2);
    expect(report.evidence.missingAdversarialTags, isEmpty);
    expect(report.evidence.missingRequiredPrimaryCapabilityIds, isEmpty);
    final rendered = EvalTuningReadiness.render(report);
    expect(
      rendered,
      contains(
        'requiredCapabilities={planner.tuning.ready, task.tuning.ready} '
        'missingRequired={}',
      ),
    );
    expect(
      rendered,
      contains(
        'stress catalog adversarial=1/1 productionReplayHoldout=1/1',
      ),
    );
    expect(
      rendered,
      contains(
        'protected evidence holdout=1/1 agents={planningAgent:1}',
      ),
    );
    expect(
      rendered,
      contains(
        'stress tags={adversarial, ambiguous-reference, scope-boundary} '
        'missing={}',
      ),
    );
    expect(
      rendered,
      contains('scenario reviews completed=2/2 missing={}'),
    );
  });

  test(
    'use-case capability contract rejects missing required capabilities',
    () {
      final scenarios = [
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          split: EvalScenarioSplit.development,
          capabilityId: 'task.tuning.ready',
        ),
        _scenarioWith(
          plannerCaptureOnlyScenario,
          split: EvalScenarioSplit.development,
          capabilityId: 'planner.tuning.ready',
        ),
      ];

      final report = EvalTuningReadiness.assess(
        traces: const [],
        scenarios: scenarios,
        profiles: const [localSmall],
        policy: const EvalTuningPolicy(
          name: 'useCaseContract',
          requiredPrimaryCapabilityIds: {
            'task.tuning.ready',
            'planner.tuning.ready',
            'calendar.tuning.absent',
          },
          minScenarioCount: 2,
          minCapabilityCount: 2,
          minScenariosPerCapability: 1,
          requireCompleteTraceMatrix: false,
        ),
      );
      final rendered = EvalTuningReadiness.render(report);

      expect(report.ready, isFalse);
      expect(
        report.evidence.missingRequiredPrimaryCapabilityIds,
        {'calendar.tuning.absent'},
      );
      expect(
        report.failures,
        contains('missing required primary capability calendar.tuning.absent'),
      );
      expect(rendered, contains('missingRequired={calendar.tuning.absent}'));
    },
  );

  test('fabricated calibration report cannot satisfy readiness gates', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      calibrationReport: _calibrationReport(
        judgedTraceCount: traces.length,
        evaluatedCount: traces.length,
        passAgreementCount: traces.length,
        scoreAgreementCount: traces.length,
      ),
      policy: const EvalTuningPolicy(
        name: 'rawCalibrationRequired',
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
        minCalibrationCoverageRate: 1,
        minCalibrationPassAgreementRate: 1,
        minCalibrationScoreAgreementRate: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains('judge calibration set is required for readiness gates'),
    );
  });

  test(
    'review gate rejects unreviewed, incomplete, invalid, and stale evidence',
    () {
      final unreviewed = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        split: EvalScenarioSplit.development,
        capabilityId: 'task.review.missing',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {'adversarial', 'tool-recovery'},
      );
      final incomplete = _reviewedScenario(
        _scenarioWith(
          taskReleaseNotesScenario,
          split: EvalScenarioSplit.development,
          capabilityId: 'task.review.incomplete',
          source: EvalScenarioSource.synthetic,
        ),
        status: EvalScenarioReviewStatus.needsReview,
      );
      final invalidBase = _scenarioWith(
        taskWorkflowPendingProposalMergeScenario,
        split: EvalScenarioSplit.development,
        capabilityId: 'task.review.invalid',
        source: EvalScenarioSource.synthetic,
      );
      final invalidJson = invalidBase.toJson();
      invalidJson['metadata'] = <String, dynamic>{
        ...(invalidJson['metadata'] as Map<String, dynamic>),
        'review': EvalScenarioReview(
          status: EvalScenarioReviewStatus.reviewed,
          reviewer: '',
          reviewedAt: '2026-06-10T12:00:00.000Z',
          subjectDigest: EvalProvenance.scenarioReviewSubjectDigest(
            invalidBase,
          ),
          rationale: 'Has a matching digest but invalid reviewer.',
          sourceDigest: EvalProvenance.digestText('invalid synthetic source'),
        ).toJson(),
      };
      final invalid = EvalScenario.fromJson(invalidJson);
      final reviewedProtected = _reviewedScenario(
        _scenarioWith(
          plannerCaptureOnlyScenario,
          split: EvalScenarioSplit.holdout,
          capabilityId: 'planner.review.stale',
          source: EvalScenarioSource.productionReplay,
        ),
      );
      final staleJson = reviewedProtected.toJson()
        ..['title'] = 'Mutated after review';
      final stale = EvalScenario.fromJson(staleJson);
      final scenarios = [unreviewed, incomplete, invalid, stale];

      final report = EvalTuningReadiness.assess(
        traces: const [],
        scenarios: scenarios,
        profiles: const [frontierFast],
        scenarioCatalogEvidence: _protectedEvidence(
          scenarios: scenarios,
          protectedHoldoutScenarioIds: [stale.id],
        ),
        policy: const EvalTuningPolicy(
          name: 'reviewGate',
          requireReviewedScenarioEvidence: true,
          requireCompleteTraceMatrix: false,
        ),
      );

      expect(report.ready, isFalse);
      expect(report.evidence.scenarioReviewRequiredCount, 4);
      expect(report.evidence.completedScenarioReviewCount, 0);
      expect(report.evidence.missingScenarioReviewIds, {unreviewed.id});
      expect(report.evidence.incompleteScenarioReviewIds, {incomplete.id});
      expect(report.evidence.invalidScenarioReviewIds, {invalid.id});
      expect(report.evidence.staleScenarioReviewIds, {stale.id});
      expect(report.evidence.missingScenarioReviewSourceDigestIds, isEmpty);
      expect(
        report.failures,
        contains(
          'scenario ${unreviewed.id} review is required for tuning evidence: '
          'adversarial',
        ),
      );
      expect(
        report.failures,
        contains(
          'scenario ${incomplete.id} review status is needs_review, expected '
          'reviewed or adjudicated',
        ),
      );
      expect(
        report.failures,
        contains('scenario ${invalid.id} review metadata is invalid'),
      );
      expect(
        report.failures,
        contains('scenario ${stale.id} review subjectDigest is stale'),
      );
      expect(
        report.failures.any(
          (failure) =>
              failure.startsWith(
                'scenario catalog validation failed: ${stale.id}: '
                'scenario review subjectDigest is ',
              ) &&
              failure.contains(', expected '),
        ),
        isTrue,
      );
      expect(
        EvalTuningReadiness.render(report),
        contains(
          'scenario reviews completed=0/4 missing={${unreviewed.id}} '
          'incomplete={${incomplete.id}} invalid={${invalid.id}} '
          'stale={${stale.id}} missingSourceDigest={}',
        ),
      );
    },
  );

  test('review gate covers protected non-holdout scenarios', () {
    final protectedDevelopment = _scenarioWith(
      taskReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.protected.development',
    );
    final protectedHoldout = _reviewedScenario(
      _scenarioWith(
        plannerCaptureOnlyScenario,
        split: EvalScenarioSplit.holdout,
        capabilityId: 'planner.protected.holdout',
        source: EvalScenarioSource.productionReplay,
      ),
    );
    final scenarios = [protectedDevelopment, protectedHoldout];

    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: scenarios,
      profiles: const [frontierFast],
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: scenarios,
        protectedScenarioIds: [
          protectedDevelopment.id,
          protectedHoldout.id,
        ],
        protectedHoldoutScenarioIds: [protectedHoldout.id],
      ),
      policy: const EvalTuningPolicy(
        name: 'protectedReviewGate',
        requireReviewedScenarioEvidence: true,
        requireCompleteTraceMatrix: false,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.evidence.missingScenarioReviewIds,
      {protectedDevelopment.id},
    );
    expect(
      report.failures,
      contains(
        'scenario ${protectedDevelopment.id} review is required for tuning '
        'evidence: protected scenario',
      ),
    );
  });

  test('review gate requires source digest for synthetic evidence', () {
    final synthetic = _reviewedScenario(
      _scenarioWith(
        taskReleaseNotesScenario,
        split: EvalScenarioSplit.development,
        capabilityId: 'task.synthetic.review',
        source: EvalScenarioSource.synthetic,
      ),
      includeSourceDigest: false,
    );

    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [synthetic],
      profiles: const [frontierFast],
      policy: const EvalTuningPolicy(
        name: 'sourceDigestGate',
        requireReviewedScenarioEvidence: true,
        requireCompleteTraceMatrix: false,
      ),
    );

    expect(report.ready, isFalse);
    expect(report.evidence.completedScenarioReviewCount, 0);
    expect(
      report.evidence.missingScenarioReviewSourceDigestIds,
      {synthetic.id},
    );
    expect(
      report.failures,
      contains(
        'scenario ${synthetic.id} review sourceDigest is required for '
        'synthetic or protected evidence',
      ),
    );
  });

  test('raw calibration set and aggregate report cannot both be supplied', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      calibrationSet: _calibrationSetFor(traces),
      calibrationReport: _calibrationReport(
        judgedTraceCount: traces.length,
        evaluatedCount: traces.length,
        passAgreementCount: traces.length,
        scoreAgreementCount: traces.length,
      ),
      policy: const EvalTuningPolicy(
        name: 'noMixedCalibrationInputs',
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'judge calibration report must not be supplied with calibrationSet; '
        'readiness recomputes it from labels',
      ),
    );
  });

  test('rejects protected evidence that is not manifest-bound', () {
    final taskScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final plannerScenario = _scenarioWith(
      plannerCaptureOnlyScenario,
      split: EvalScenarioSplit.holdout,
      capabilityId: 'planner.tuning.ready',
      source: EvalScenarioSource.productionReplay,
    );
    const profiles = [frontierFast];
    final scenarios = [taskScenario, plannerScenario];
    final manifest = _manifestFor(
      scenarios: scenarios,
      profiles: profiles,
      targetKind: 'live',
    );
    final traces = [
      for (final scenario in scenarios)
        for (
          var trialIndex = 0;
          trialIndex < frontierFast.trialCount;
          trialIndex++
        )
          _trace(
            scenario: scenario,
            profile: frontierFast,
            trialIndex: trialIndex,
            calibrationSetVersion: 'gold-v1',
          ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: scenarios,
      profiles: profiles,
      manifest: manifest,
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: scenarios,
        protectedHoldoutScenarioIds: [plannerScenario.id],
      ),
      policy: const EvalTuningPolicy(
        name: 'customTuning',
        requireManifest: true,
        requiredTargetKind: 'live',
        requireProtectedHoldout: true,
        requireAllVerdicts: true,
        requireCalibratedVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        minTrialsPerProfile: 2,
      ),
    );

    expect(
      report.failures,
      contains('scenario catalog evidence does not match the run manifest'),
    );
  });

  test('calibration quality gates reject weak human agreement evidence', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: scenario,
        profile: frontierFast,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      calibrationReport: _calibrationReport(
        judgedTraceCount: traces.length,
        evaluatedCount: 1,
        passAgreementCount: 0,
        scoreAgreementCount: 0,
        falsePassCount: 1,
        falseFailCount: 1,
        unblindedVerdictCount: 1,
        staleLabelCount: 1,
        missingTraceCount: 1,
        missingVerdictCount: 1,
        judgeCalibrationMismatchCount: 1,
        judgeCalibrationSetVersion: 'wrong-gold',
        calibrationSetVersion: 'wrong-human',
        humanReviewPairCount: 1,
        unresolvedHumanDisagreementCount: 1,
        unblindedHumanReviewCount: 1,
      ),
      policy: const EvalTuningPolicy(
        name: 'calibrationQuality',
        requiredModelClasses: {
          EvalModelClass.frontierFast,
        },
        requireAllVerdicts: true,
        requireCalibratedVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requiredHumanCalibrationSetVersion: 'human-gold-v1',
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 2,
        minCalibrationEvaluatedPerModelClass: 2,
        minCalibrationEvaluatedPerCapability: 2,
        minCalibrationEvaluatedPerModelClassCapability: 2,
        minCalibrationEvaluatedPerPromptVariant: 2,
        minCalibrationEvaluatedPerModelClassPromptVariant: 2,
        minCalibrationCoverageRate: 0.75,
        minCalibrationPassAgreementRate: 0.8,
        minCalibrationScoreAgreementRate: 0.8,
        minCalibrationHumanReviewPairCount: 2,
        minCalibrationHumanPassAgreementRate: 0.8,
        minCalibrationHumanPassAgreementLowerBound: 0.5,
        minCalibrationHumanScoreAgreementRate: 0.8,
        minCalibrationHumanScoreAgreementLowerBound: 0.5,
        maxCalibrationUnresolvedHumanDisagreementCount: 0,
        requireBlindedHumanReviews: true,
        maxCalibrationFalsePassRate: 0.1,
        maxCalibrationFalseFailRate: 0.1,
        requireBlindedCalibrationReport: true,
        requireCleanCalibrationReport: true,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains('judge calibration set is required for readiness gates'),
    );
    expect(
      report.failures,
      contains(
        'calibration report judgeCalibrationSetVersion is wrong-gold, '
        'expected gold-v1',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration report human version is wrong-human, '
        'expected human-gold-v1',
      ),
    );
    expect(report.failures, contains('calibration evaluated count 1 < 2'));
    expect(
      report.failures,
      contains(
        'calibration model class frontierFast evaluated count 0 < 2',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration capability task.tuning.ready evaluated count 0 < 2',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration model class/capability frontierFast@task.tuning.ready evaluated count 0 < 2',
      ),
    );
    expect(
      report.failures,
      contains('calibration prompt variant default evaluated count 0 < 2'),
    );
    expect(
      report.failures,
      contains(
        'calibration model class/prompt variant frontierFast@default '
        'evaluated count 0 < 2',
      ),
    );
    expect(report.failures, contains('calibration coverage 50.0% < 75.0%'));
    expect(
      report.failures,
      contains('calibration pass agreement 0.0% < 80.0%'),
    );
    expect(
      report.failures,
      contains('calibration score agreement 0.0% < 80.0%'),
    );
    expect(
      report.failures,
      contains('calibration human review pairs 1 < 2'),
    );
    expect(
      report.failures,
      contains('calibration human pass agreement 0.0% < 80.0%'),
    );
    expect(
      report.failures,
      contains('calibration human pass agreement lower bound 0.0% < 50.0%'),
    );
    expect(
      report.failures,
      contains('calibration human score agreement 0.0% < 80.0%'),
    );
    expect(
      report.failures,
      contains('calibration human score agreement lower bound 0.0% < 50.0%'),
    );
    expect(
      report.failures,
      contains('calibration unresolved human disagreement count 1 > 0'),
    );
    expect(
      report.failures,
      contains('calibration unblinded human review count 1 > 0'),
    );
    expect(
      report.failures,
      contains('calibration false-pass rate 100.0% > 10.0%'),
    );
    expect(
      report.failures,
      contains('calibration false-fail rate 100.0% > 10.0%'),
    );
    expect(
      report.failures,
      contains('calibration report is not model-identity blinded'),
    );
    expect(report.failures, contains('calibration report has 1 stale labels'));
    expect(
      report.failures,
      contains('calibration report has 1 missing traces'),
    );
    expect(
      report.failures,
      contains('calibration report has 1 missing verdicts'),
    );
    expect(
      report.failures,
      contains('calibration report has 1 unlabeled verdicts'),
    );
    expect(
      report.failures,
      contains('calibration report has 1 calibration mismatches'),
    );
  });

  test('calibration cross-cell gate rejects aggregate-only coverage', () {
    final taskScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.cross.cell',
    );
    final plannerScenario = _scenarioWith(
      plannerCaptureOnlyScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'planner.cross.cell',
    );
    final traces = [
      _trace(
        scenario: taskScenario,
        profile: localSmall,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: plannerScenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [taskScenario, plannerScenario],
      profiles: const [localSmall, frontierFast],
      calibrationSet: _calibrationSetFor(traces),
      policy: const EvalTuningPolicy(
        name: 'calibrationCrossCell',
        requiredModelClasses: {
          EvalModelClass.localSmall,
          EvalModelClass.frontierFast,
        },
        requireCompleteTraceMatrix: false,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationReport: true,
        minCalibrationEvaluatedPerModelClass: 1,
        minCalibrationEvaluatedPerCapability: 1,
        minCalibrationEvaluatedPerModelClassCapability: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      isNot(
        contains(
          'calibration model class localSmall evaluated count 0 < 1',
        ),
      ),
    );
    expect(
      report.failures,
      isNot(
        contains(
          'calibration capability task.cross.cell evaluated count 0 < 1',
        ),
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration model class/capability frontierFast@task.cross.cell '
        'evaluated count 0 < 1',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration model class/capability localSmall@planner.cross.cell '
        'evaluated count 0 < 1',
      ),
    );
  });

  test('calibration slice gates require each prompt variant', () {
    const tunedVariant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final defaultTrace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
    );
    final tunedTrace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
      agentDirectiveVariant: tunedVariant,
    );

    final report = EvalTuningReadiness.assess(
      traces: [defaultTrace, tunedTrace],
      scenarios: [scenario],
      profiles: const [frontierFast],
      calibrationSet: _calibrationSetFor([defaultTrace]),
      policy: const EvalTuningPolicy(
        name: 'promptVariantCalibration',
        requireCompleteTraceMatrix: false,
        requireAllVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
        minCalibrationEvaluatedPerPromptVariant: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'calibration prompt variant metadata-first-v2 evaluated count 0 < 1',
      ),
    );
    expect(
      report.failures,
      isNot(
        contains('calibration prompt variant default evaluated count 0 < 1'),
      ),
    );
  });

  test('calibration slice gates require each model class prompt variant pair', () {
    const tunedVariant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final localTunedTrace = _trace(
      scenario: scenario,
      profile: localSmall,
      calibrationSetVersion: 'gold-v1',
      agentDirectiveVariant: tunedVariant,
    );
    final frontierTunedTrace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
      agentDirectiveVariant: tunedVariant,
    );

    final report = EvalTuningReadiness.assess(
      traces: [localTunedTrace, frontierTunedTrace],
      scenarios: [scenario],
      profiles: const [localSmall, frontierFast],
      calibrationSet: _calibrationSetFor([localTunedTrace]),
      policy: const EvalTuningPolicy(
        name: 'promptVariantModelClassCalibration',
        requireCompleteTraceMatrix: false,
        requireAllVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationReport: true,
        minCalibrationEvaluatedPerPromptVariant: 1,
        minCalibrationEvaluatedPerModelClassPromptVariant: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      isNot(
        contains(
          'calibration prompt variant metadata-first-v2 evaluated count 0 < 1',
        ),
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration model class/prompt variant frontierFast@metadata-first-v2 '
        'evaluated count 0 < 1',
      ),
    );
  });

  test('protected calibration gate rejects development-only labels', () {
    final developmentScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.protected.calibration',
    );
    final protectedScenario = _reviewedScenario(
      _scenarioWith(
        taskReleaseNotesScenario,
        id: 'task_protected_calibration_holdout',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.protected.calibration',
        source: EvalScenarioSource.productionReplay,
      ),
    );
    final developmentTrace = _trace(
      scenario: developmentScenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
    );
    final protectedTrace = _trace(
      scenario: protectedScenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
    );
    final scenarios = [developmentScenario, protectedScenario];
    final report = EvalTuningReadiness.assess(
      traces: [developmentTrace, protectedTrace],
      scenarios: scenarios,
      profiles: const [frontierFast],
      manifest: _manifestFor(
        scenarios: scenarios,
        profiles: const [frontierFast],
        targetKind: 'live',
        scenarioCatalogEvidence: _protectedEvidence(
          scenarios: scenarios,
          protectedHoldoutScenarioIds: [protectedScenario.id],
        ),
      ),
      calibrationSet: _calibrationSetFor([developmentTrace]),
      policy: const EvalTuningPolicy(
        name: 'protectedCalibrationRequired',
        requiredModelClasses: {EvalModelClass.frontierFast},
        requireCompleteTraceMatrix: false,
        requireAllVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationReport: true,
        requireProtectedCalibrationHoldout: true,
        minProtectedCalibrationEvaluatedCount: 1,
        minProtectedCalibrationEvaluatedPerCapability: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains('protected calibration holdout labels are missing'),
    );
    expect(
      report.failures,
      contains('protected calibration evaluated count 0 < 1'),
    );
    expect(
      report.failures,
      contains(
        'protected calibration capability task.protected.calibration '
        'evaluated count 0 < 1',
      ),
    );
  });

  test('protected calibration gate accepts manifest-bound holdout labels', () {
    final protectedScenario = _reviewedScenario(
      _scenarioWith(
        taskReleaseNotesScenario,
        id: 'task_protected_calibration_ready',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.protected.calibration.ready',
        source: EvalScenarioSource.productionReplay,
      ),
    );
    final traces = [
      for (
        var trialIndex = 0;
        trialIndex < frontierFast.trialCount;
        trialIndex++
      )
        _trace(
          scenario: protectedScenario,
          profile: frontierFast,
          trialIndex: trialIndex,
          calibrationSetVersion: 'gold-v1',
        ),
    ];
    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [protectedScenario],
      profiles: const [frontierFast],
      manifest: _manifestFor(
        scenarios: [protectedScenario],
        profiles: const [frontierFast],
        targetKind: 'live',
        scenarioCatalogEvidence: _protectedEvidence(
          scenarios: [protectedScenario],
          protectedHoldoutScenarioIds: [protectedScenario.id],
        ),
      ),
      calibrationSet: _calibrationSetFor(traces),
      policy: const EvalTuningPolicy(
        name: 'protectedCalibrationReady',
        requiredModelClasses: {EvalModelClass.frontierFast},
        requireCompleteTraceMatrix: false,
        requireAllVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationReport: true,
        requireProtectedCalibrationHoldout: true,
        minProtectedCalibrationEvaluatedCount: 1,
        minProtectedCalibrationEvaluatedPerModelClass: 1,
        minProtectedCalibrationEvaluatedPerCapability: 1,
        minProtectedCalibrationEvaluatedPerModelClassCapability: 1,
        minProtectedCalibrationEvaluatedPerPromptVariant: 1,
        minProtectedCalibrationEvaluatedPerModelClassPromptVariant: 1,
      ),
    );

    expect(report.ready, isTrue, reason: report.failures.join('\n'));
  });

  test('outcome quality gates inspect each use-case model slice', () {
    const budgetProfile = EvalProfile(
      name: 'frontier-fast-budget-test',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-fast-model',
      tokenBudget: 100,
      trialCount: 2,
    );
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.outcome.quality',
    );
    final passingTrace = _trace(
      scenario: scenario,
      profile: budgetProfile,
      calibrationSetVersion: 'gold-v1',
    );
    final failingTrace = _trace(
      scenario: scenario,
      profile: budgetProfile,
      trialIndex: 1,
      calibrationSetVersion: 'gold-v1',
      judgePass: false,
      goalAttainment: 2,
      quality: 2,
      efficiency: 2,
    );

    final report = EvalTuningReadiness.assess(
      traces: [passingTrace, failingTrace],
      scenarios: [scenario],
      profiles: const [budgetProfile],
      policy: const EvalTuningPolicy(
        name: 'outcomeQuality',
        requireAllVerdicts: true,
        requireAllJudgePasses: true,
        requireOutcomeSliceThresholds: true,
        minOutcomeJudgedTraceCoverageRate: 1,
        minJudgePassRate: 1,
        minJudgePassRateLowerBound: 0.5,
        minMeanGoalAttainment: 4,
        minMeanQuality: 4,
        minMeanEfficiency: 3,
        maxMeanTokensPerTraceBudgetRatio: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(report.outcomeQualityEvidence?.judgedTraceCount, 2);
    expect(report.outcomeQualityEvidence?.passTraceCount, 1);
    expect(
      report.failures,
      contains('outcome all judge pass rate 50.0% < 100.0%'),
    );
    expect(
      report.failures.any(
        (failure) =>
            failure.startsWith('outcome all judge pass lower bound ') &&
            failure.endsWith('< 50.0%'),
      ),
      isTrue,
    );
    expect(
      report.failures,
      contains(
        'outcome slice task.outcome.quality@taskAgent@frontierFast@default '
        'mean quality 3.5 < 4.0',
      ),
    );
    expect(
      report.failures,
      contains('outcome all mean token budget ratio 1.50x > 1.00x'),
    );
    expect(
      report.failures.any(
        (failure) =>
            failure.startsWith('outcome slice ') &&
            failure.contains('failing judge traces') &&
            failure.contains('task_workflow_release_notes_development'),
      ),
      isTrue,
    );
    expect(
      EvalTuningReadiness.render(report),
      contains(
        'outcome quality judged=2/2 slices=1/1 judgePass=50.0%',
      ),
    );
  });

  test('outcome slice gates reject failures hidden by aggregate means', () {
    const profile = EvalProfile(
      name: 'frontier-fast-slice-test',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-fast-model',
      tokenBudget: 60000,
      trialCount: 2,
    );
    final weakScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.outcome.weak',
    );
    final strongScenario = _scenarioWith(
      plannerCaptureOnlyScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'planner.outcome.strong',
    );
    final traces = [
      _trace(
        scenario: weakScenario,
        profile: profile,
        calibrationSetVersion: 'gold-v1',
        quality: 3,
      ),
      _trace(
        scenario: weakScenario,
        profile: profile,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
        quality: 3,
      ),
      _trace(
        scenario: strongScenario,
        profile: profile,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: strongScenario,
        profile: profile,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [weakScenario, strongScenario],
      profiles: const [profile],
      policy: const EvalTuningPolicy(
        name: 'sliceOutcomeQuality',
        requireAllVerdicts: true,
        requireOutcomeSliceThresholds: true,
        minMeanQuality: 4,
      ),
    );

    expect(report.ready, isFalse);
    expect(report.outcomeQualityEvidence?.meanQuality, 4);
    expect(
      report.failures,
      isNot(contains('outcome all mean quality 4.0 < 4.0')),
    );
    expect(
      report.failures,
      contains(
        'outcome slice task.outcome.weak@taskAgent@frontierFast@default '
        'mean quality 3.0 < 4.0',
      ),
    );
  });

  test('outcome quality gates enforce measured weighted cost evidence', () {
    const weightedProfile = EvalProfile(
      name: 'frontier-weighted-budget-test',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'frontier-weighted-model',
      tokenBudget: 1000,
      trialCount: 2,
      outputTokenCostMicros: 10,
      thoughtsTokenCostMicros: 10,
    );
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.outcome.cost',
    );
    final missingCostTrace = _trace(
      scenario: scenario,
      profile: weightedProfile,
      calibrationSetVersion: 'gold-v1',
      usage: const InferenceUsage(inputTokens: 100),
    );
    final costlyTrace = _trace(
      scenario: scenario,
      profile: weightedProfile,
      trialIndex: 1,
      calibrationSetVersion: 'gold-v1',
      usage: const InferenceUsage(inputTokens: 100, outputTokens: 200),
    );

    final report = EvalTuningReadiness.assess(
      traces: [missingCostTrace, costlyTrace],
      scenarios: [scenario],
      profiles: const [weightedProfile],
      policy: const EvalTuningPolicy(
        name: 'weightedCostOutcome',
        requireAllVerdicts: true,
        requireOutcomeSliceThresholds: true,
        requireWeightedCostEvidence: true,
        maxMeanWeightedCostPerTraceBudgetRatio: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(report.outcomeQualityEvidence?.weightedCostTraceCount, 1);
    expect(report.outcomeQualityEvidence?.missingWeightedCostTraceCount, 1);
    expect(
      report.failures,
      contains('outcome all missing weighted cost evidence 1 > 0'),
    );
    expect(
      report.failures,
      contains('outcome all mean weighted cost budget ratio 2.10x > 1.00x'),
    );
    expect(
      report.failures,
      contains(
        'outcome slice task.outcome.cost@taskAgent@frontierReasoning@default '
        'missing weighted cost evidence 1 > 0',
      ),
    );
  });

  test('calibration agreement gates inspect prompt variants', () {
    const tunedVariant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Write durable metadata before summaries.',
    );
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final defaultTrace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
    );
    final tunedTrace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
      agentDirectiveVariant: tunedVariant,
    );

    final report = EvalTuningReadiness.assess(
      traces: [defaultTrace, tunedTrace],
      scenarios: [scenario],
      profiles: const [frontierFast],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        judgeCalibrationSetVersion: 'gold-v1',
        labels: [
          _calibrationLabelForTrace(defaultTrace),
          _calibrationLabelForTrace(
            tunedTrace,
            expectedPass: false,
            goalAttainment: 1,
            quality: 1,
            efficiency: 1,
          ),
        ],
      ),
      policy: const EvalTuningPolicy(
        name: 'promptVariantAgreement',
        requireCompleteTraceMatrix: false,
        requireAllVerdicts: true,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationReport: true,
        minCalibrationEvaluatedPerPromptVariant: 1,
        minCalibrationPassAgreementPerPromptVariant: 0.8,
        minCalibrationScoreAgreementPerPromptVariant: 0.8,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'calibration prompt variant metadata-first-v2 pass agreement '
        '0.0% < 80.0%',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration prompt variant metadata-first-v2 score agreement '
        '0.0% < 80.0%',
      ),
    );
    expect(
      report.failures,
      isNot(
        contains(
          'calibration prompt variant default pass agreement 0.0% < 80.0%',
        ),
      ),
    );
  });

  test('clean calibration readiness rejects duplicate gold labels', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final trace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
    );
    final label = _calibrationSetFor([trace]).labels.single;

    final report = EvalTuningReadiness.assess(
      traces: [trace],
      scenarios: [scenario],
      profiles: const [frontierFast],
      calibrationSet: JudgeCalibrationSet(
        version: 'human-gold-v1',
        judgeCalibrationSetVersion: 'gold-v1',
        labels: [label, label],
      ),
      policy: const EvalTuningPolicy(
        name: 'duplicateGoldLabelGuard',
        requireAllVerdicts: true,
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
        minCalibrationCoverageRate: 1,
        minCalibrationPassAgreementRate: 1,
        minCalibrationScoreAgreementRate: 1,
        requireCleanCalibrationReport: true,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains('calibration report has 1 duplicate gold labels'),
    );
  });

  test('calibration sourceRun gate binds completed labels to manifest', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );
    final trace = _trace(
      scenario: scenario,
      profile: frontierFast,
      calibrationSetVersion: 'gold-v1',
      manifestDigest: manifest.manifestDigest,
    );
    const policy = EvalTuningPolicy(
      name: 'sourceRunCalibrationGate',
      requireCompleteTraceMatrix: false,
      requiredCalibrationSetVersion: 'gold-v1',
      requireCalibrationSourceRun: true,
      requireCalibrationReport: true,
      minCalibrationEvaluatedCount: 1,
      minCalibrationPassAgreementRate: 1,
      minCalibrationScoreAgreementRate: 1,
    );

    final missingSourceRun = EvalTuningReadiness.assess(
      traces: [trace],
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: _calibrationSetFor([trace]),
      policy: policy,
    );
    final driftedSourceRun = EvalTuningReadiness.assess(
      traces: [trace],
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: _calibrationSetFor(
        [trace],
        sourceRun: JudgeCalibrationSourceRun.fromManifest(
          manifest.withManifestDigest(
            EvalProvenance.digestText('old-manifest'),
          ),
        ),
      ),
      policy: policy,
    );
    final boundSourceRun = EvalTuningReadiness.assess(
      traces: [trace],
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: _calibrationSetFor(
        [trace],
        sourceRun: JudgeCalibrationSourceRun.fromManifest(manifest),
      ),
      policy: policy,
    );

    expect(
      missingSourceRun.failures,
      contains('calibration sourceRun is required for readiness gates'),
    );
    expect(
      driftedSourceRun.failures,
      contains(
        startsWith('calibration sourceRun manifestDigest is sha256:'),
      ),
    );
    expect(
      boundSourceRun.failures.where(
        (failure) => failure.contains('calibration sourceRun'),
      ),
      isEmpty,
    );
    expect(boundSourceRun.failures, isEmpty);
    expect(boundSourceRun.ready, isTrue);
  });

  test('sampled calibration labels require template selection proof', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: scenario,
        profile: frontierFast,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
      ),
    ];
    const policy = EvalTuningPolicy(
      name: 'sampledCalibrationTemplateProof',
      requireCompleteTraceMatrix: false,
      requiredCalibrationSetVersion: 'gold-v1',
      requireCalibrationSourceRun: true,
      requireCalibrationTemplateSelection: true,
      requireCalibrationReport: true,
      minCalibrationEvaluatedCount: 1,
      minCalibrationPassAgreementRate: 1,
      minCalibrationScoreAgreementRate: 1,
    );

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: _calibrationSetFor(
        [traces.first],
        sourceRun: JudgeCalibrationSourceRun.fromManifest(manifest),
      ),
      policy: policy,
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'calibration template selection is required for sampled labels',
      ),
    );
  });

  test(
    'sampled calibration labels accept replayed template selection proof',
    () {
      final scenario = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        split: EvalScenarioSplit.development,
        capabilityId: 'task.tuning.ready',
      );
      final manifest = _manifestFor(
        scenarios: [scenario],
        profiles: const [frontierFast],
        targetKind: 'live',
      );
      final traces = [
        _trace(
          scenario: scenario,
          profile: frontierFast,
          calibrationSetVersion: 'gold-v1',
        ),
        _trace(
          scenario: scenario,
          profile: frontierFast,
          trialIndex: 1,
          calibrationSetVersion: 'gold-v1',
        ),
      ];

      final report = EvalTuningReadiness.assess(
        traces: traces,
        scenarios: [scenario],
        profiles: const [frontierFast],
        manifest: manifest,
        calibrationSet: _sampledCalibrationSetFromTemplate(
          traces: traces,
          manifest: manifest,
          maxRows: 1,
        ),
        policy: const EvalTuningPolicy(
          name: 'sampledCalibrationTemplateProof',
          requireCompleteTraceMatrix: false,
          requiredCalibrationSetVersion: 'gold-v1',
          requireCalibrationSourceRun: true,
          requireCalibrationTemplateSelection: true,
          requireCalibrationReport: true,
          minCalibrationEvaluatedCount: 1,
          minCalibrationPassAgreementRate: 1,
          minCalibrationScoreAgreementRate: 1,
        ),
      );

      expect(
        report.failures.where(
          (failure) => failure.contains('calibration template selection'),
        ),
        isEmpty,
      );
      expect(report.failures, isEmpty);
      expect(report.ready, isTrue);
    },
  );

  test('sampled calibration proof rejects cherry-picked label keys', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: scenario,
        profile: frontierFast,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: _sampledCalibrationSetFromTemplate(
        traces: traces,
        manifest: manifest,
        maxRows: 1,
        mutateSelection: (selection) => {
          ...selection,
          'selectedKeyDigest': EvalProvenance.digestText(
            'forged-selected-keys',
          ),
        },
      ),
      policy: const EvalTuningPolicy(
        name: 'sampledCalibrationTemplateProof',
        requireCompleteTraceMatrix: false,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationSourceRun: true,
        requireCalibrationTemplateSelection: true,
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
        minCalibrationPassAgreementRate: 1,
        minCalibrationScoreAgreementRate: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'calibration template selection: calibration template '
        'selectedKeyDigest does not match completed label keys',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration template selection: calibration template selection '
        'evidence does not match current stratified template',
      ),
    );
  });

  test('sampled calibration proof rejects padded omitted labels', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: scenario,
        profile: frontierFast,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
      ),
    ];
    final sampled = _sampledCalibrationSetFromTemplate(
      traces: traces,
      manifest: manifest,
      maxRows: 1,
    );

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: JudgeCalibrationSet(
        version: sampled.version,
        judgeCalibrationSetVersion: sampled.judgeCalibrationSetVersion,
        sourceRun: sampled.sourceRun,
        templateSelection: sampled.templateSelection,
        labels: [
          ...sampled.labels,
          _calibrationLabelForTrace(traces.last),
        ],
      ),
      policy: const EvalTuningPolicy(
        name: 'sampledCalibrationTemplateProof',
        requireCompleteTraceMatrix: false,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationSourceRun: true,
        requireCalibrationTemplateSelection: true,
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
        minCalibrationPassAgreementRate: 1,
        minCalibrationScoreAgreementRate: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'calibration template selection: calibration template '
        'selectedKeyDigest does not match completed label keys',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration template selection: calibration template '
        'selectedTraceCount 1 != completed label count 2',
      ),
    );
  });

  test('sampled calibration proof rejects forged source run binding', () {
    final scenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: const [frontierFast],
      targetKind: 'live',
    );
    final traces = [
      _trace(
        scenario: scenario,
        profile: frontierFast,
        calibrationSetVersion: 'gold-v1',
      ),
      _trace(
        scenario: scenario,
        profile: frontierFast,
        trialIndex: 1,
        calibrationSetVersion: 'gold-v1',
      ),
    ];

    final report = EvalTuningReadiness.assess(
      traces: traces,
      scenarios: [scenario],
      profiles: const [frontierFast],
      manifest: manifest,
      calibrationSet: _sampledCalibrationSetFromTemplate(
        traces: traces,
        manifest: manifest,
        maxRows: 1,
        mutateSelection: (selection) => {
          ...selection,
          'sourceRunDigest': EvalProvenance.digestText('forged-source-run'),
        },
      ),
      policy: const EvalTuningPolicy(
        name: 'sampledCalibrationTemplateProof',
        requireCompleteTraceMatrix: false,
        requiredCalibrationSetVersion: 'gold-v1',
        requireCalibrationSourceRun: true,
        requireCalibrationTemplateSelection: true,
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
        minCalibrationPassAgreementRate: 1,
        minCalibrationScoreAgreementRate: 1,
      ),
    );

    expect(report.ready, isFalse);
    expect(
      report.failures,
      contains(
        'calibration template selection: calibration template '
        'sourceRunDigest does not match sourceRun',
      ),
    );
    expect(
      report.failures,
      contains(
        'calibration template selection: calibration template selection '
        'evidence does not match current stratified template',
      ),
    );
  });

  test('corpus stress gates reject sanitized tuning evidence', () {
    final taskScenario = _scenarioWith(
      taskWorkflowReleaseNotesScenario,
      split: EvalScenarioSplit.development,
      capabilityId: 'task.tuning.ready',
    );
    final plannerScenario = _scenarioWith(
      plannerCaptureOnlyScenario,
      split: EvalScenarioSplit.holdout,
      capabilityId: 'planner.tuning.ready',
    );

    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [taskScenario, plannerScenario],
      profiles: const [frontierFast],
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: [taskScenario, plannerScenario],
        protectedHoldoutScenarioIds: [plannerScenario.id],
      ),
      policy: const EvalTuningPolicy(
        name: 'stressCorpus',
        requiredAgentKinds: {
          AgentKind.taskAgent,
          AgentKind.planningAgent,
        },
        minAdversarialScenarioCount: 2,
        minAdversarialScenariosPerAgentKind: 1,
        minAdversarialScenariosPerCapability: 1,
        requiredAdversarialTags: {
          'ambiguous-reference',
          'tool-recovery',
        },
        minProductionReplayHoldoutScenarios: 1,
        minProtectedHoldoutScenarios: 1,
        minProtectedHoldoutScenariosPerAgentKind: 1,
        requireProtectedHoldout: true,
        requireCompleteTraceMatrix: false,
      ),
    );

    expect(report.ready, isFalse);
    expect(report.failures, contains('adversarial scenario count 0 < 2'));
    expect(
      report.failures,
      contains('taskAgent adversarial scenario count 0 < 1'),
    );
    expect(
      report.failures,
      contains('planningAgent adversarial scenario count 0 < 1'),
    );
    expect(
      report.failures,
      contains(
        'capability task.tuning.ready adversarial scenario count 0 < 1',
      ),
    );
    expect(
      report.failures,
      contains('missing adversarial tag ambiguous-reference'),
    );
    expect(
      report.failures,
      contains('production-replay holdout scenario count 0 < 1'),
    );
    expect(
      report.failures,
      contains(
        'protected holdout evidence references non-production-replay '
        'scenario ${plannerScenario.id}',
      ),
    );
    expect(
      report.failures,
      contains('protected holdout scenario count 0 < 1'),
    );
    expect(
      report.failures,
      contains('taskAgent protected holdout scenario count 0 < 1'),
    );
    expect(
      report.failures,
      contains('planningAgent protected holdout scenario count 0 < 1'),
    );
  });

  test('public production-replay holdout is not protected evidence', () {
    final scenario = _scenarioWith(
      plannerCaptureOnlyScenario,
      split: EvalScenarioSplit.holdout,
      capabilityId: 'planner.tuning.ready',
      source: EvalScenarioSource.productionReplay,
    );

    final report = EvalTuningReadiness.assess(
      traces: const [],
      scenarios: [scenario],
      profiles: const [frontierFast],
      policy: const EvalTuningPolicy(
        name: 'protectedSeparation',
        minProductionReplayHoldoutScenarios: 1,
        minProtectedHoldoutScenarios: 1,
        requireCompleteTraceMatrix: false,
      ),
    );

    expect(report.evidence.productionReplayHoldoutScenarioCount, 1);
    expect(report.evidence.protectedHoldoutScenarioCount, 0);
    expect(
      report.failures,
      contains('protected holdout scenario count 0 < 1'),
    );
    final rendered = EvalTuningReadiness.render(report);
    expect(
      rendered,
      contains('stress catalog adversarial=0 productionReplayHoldout=1/1'),
    );
    expect(
      rendered,
      contains('protected evidence holdout=0/1 agents={}'),
    );
  });

  test('protected holdout source digests must be unique', () {
    final duplicateSourceDigest = EvalProvenance.digestText(
      'same-production-replay-record',
    );
    final first = _reviewedScenario(
      _scenarioWith(
        taskReleaseNotesScenario,
        id: 'private_task_holdout_a',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.private.holdout',
        source: EvalScenarioSource.productionReplay,
      ),
      sourceDigest: duplicateSourceDigest,
    );
    final second = _reviewedScenario(
      _scenarioWith(
        plannerCaptureOnlyScenario,
        id: 'private_planner_holdout_b',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'planner.private.holdout',
        source: EvalScenarioSource.productionReplay,
      ),
      sourceDigest: duplicateSourceDigest,
    );

    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: [first, second],
      profiles: kDefaultProfiles,
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: [first, second],
        protectedHoldoutScenarioIds: [first.id, second.id],
      ),
      policy: const EvalTuningPolicy(
        name: 'uniqueProtectedSources',
        minProtectedHoldoutScenarios: 2,
        requireProtectedHoldout: true,
        requireReviewedScenarioEvidence: true,
      ),
    );

    expect(report.evidence.protectedHoldoutScenarioCount, 2);
    expect(
      report.evidence.duplicateProtectedHoldoutSourceDigests,
      {duplicateSourceDigest},
    );
    expect(
      report.failures,
      contains(
        'duplicate protected holdout sourceDigest $duplicateSourceDigest',
      ),
    );
    final rendered = EvalTuningReadiness.renderScenarioCatalogPreflight(
      report,
    );
    expect(rendered, contains('duplicateProtectedHoldoutSourceDigests'));
    expect(rendered, isNot(contains(first.id)));
    expect(rendered, isNot(contains(second.id)));
  });

  test(
    'stress gates require canonical adversarial and unique protected ids',
    () {
      final tagOnlyScenario = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        split: EvalScenarioSplit.development,
        capabilityId: 'task.tuning.ready',
        source: EvalScenarioSource.adversarial,
        tags: {'adversarial', 'ambiguous-reference'},
      );
      final protectedScenario = _scenarioWith(
        plannerCaptureOnlyScenario,
        split: EvalScenarioSplit.holdout,
        capabilityId: 'planner.tuning.ready',
        source: EvalScenarioSource.productionReplay,
      );

      final report = EvalTuningReadiness.assess(
        traces: const [],
        scenarios: [tagOnlyScenario, protectedScenario],
        profiles: const [frontierFast],
        scenarioCatalogEvidence: _protectedEvidence(
          scenarios: [tagOnlyScenario, protectedScenario],
          protectedHoldoutScenarioIds: [
            protectedScenario.id,
            protectedScenario.id,
          ],
        ),
        policy: const EvalTuningPolicy(
          name: 'strictStressCorpus',
          minAdversarialScenarioCount: 1,
          minProtectedHoldoutScenarios: 2,
          requireCompleteTraceMatrix: false,
        ),
      );

      expect(report.ready, isFalse);
      expect(
        report.failures,
        contains(
          'scenario catalog validation failed: '
          '${tagOnlyScenario.id}: scenario has adversarial source but '
          'isAdversarial is false',
        ),
      );
      expect(
        report.failures,
        contains(
          'scenario catalog validation failed: '
          '${tagOnlyScenario.id}: scenario has adversarial tag but '
          'isAdversarial is false',
        ),
      );
      expect(report.failures, contains('adversarial scenario count 0 < 1'));
      expect(report.evidence.adversarialScenarioCount, 0);
      expect(report.evidence.protectedHoldoutScenarioCount, 1);
      expect(
        report.evidence.duplicateProtectedHoldoutScenarioIds,
        {protectedScenario.id},
      );
      expect(
        report.failures,
        contains(
          'duplicate protected holdout evidence id ${protectedScenario.id}',
        ),
      );
      expect(
        report.failures,
        contains('protected holdout scenario count 1 < 2'),
      );
      final rendered = EvalTuningReadiness.render(report);
      expect(
        rendered,
        contains(
          'stress catalog adversarial=0/1 productionReplayHoldout=1',
        ),
      );
      expect(
        rendered,
        contains(
          'protected evidence holdout=1/2 agents={planningAgent:1}',
        ),
      );
      expect(
        rendered,
        contains(
          'duplicateProtectedHoldoutIds={${protectedScenario.id}}',
        ),
      );
    },
  );

  test(
    'corpus governance requires protected holdouts per required capability',
    () {
      final taskDevelopment = _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        id: 'governance_task_required_development',
        split: EvalScenarioSplit.development,
        capabilityId: 'task.governance.required',
      );
      final taskHoldout = _reviewedScenario(
        _scenarioWith(
          taskWorkflowReleaseNotesScenario,
          id: 'governance_task_required_holdout',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'task.governance.required',
          source: EvalScenarioSource.productionReplay,
        ),
      );
      final plannerDevelopment = _scenarioWith(
        plannerCaptureOnlyScenario,
        id: 'governance_planner_required_development',
        split: EvalScenarioSplit.development,
        capabilityId: 'planner.governance.required',
      );
      final plannerOtherHoldout = _reviewedScenario(
        _scenarioWith(
          plannerCaptureOnlyScenario,
          id: 'governance_planner_other_holdout',
          split: EvalScenarioSplit.holdout,
          capabilityId: 'planner.governance.other',
          source: EvalScenarioSource.productionReplay,
        ),
      );
      final scenarios = [
        taskDevelopment,
        taskHoldout,
        plannerDevelopment,
        plannerOtherHoldout,
      ];

      final report = EvalTuningReadiness.assessScenarioCatalog(
        scenarios: scenarios,
        profiles: kDefaultProfiles,
        scenarioCatalogEvidence: _protectedEvidence(
          scenarios: scenarios,
          protectedHoldoutScenarioIds: [
            taskHoldout.id,
            plannerOtherHoldout.id,
          ],
        ),
        policy: const EvalTuningPolicy(
          name: 'capabilityProtectedHoldoutContract',
          requiredPrimaryCapabilityIds: {
            'task.governance.required',
            'planner.governance.required',
          },
          requiredSplits: {
            EvalScenarioSplit.development,
            EvalScenarioSplit.holdout,
          },
          requiredAgentKinds: {
            AgentKind.taskAgent,
            AgentKind.planningAgent,
          },
          minScenarioCount: 4,
          minScenariosPerAgentKind: 2,
          minScenariosPerRequiredCapabilitySplit: 1,
          minProtectedHoldoutScenarios: 2,
          minProtectedHoldoutScenariosPerAgentKind: 1,
          minProtectedHoldoutScenariosPerRequiredCapability: 1,
          requireProtectedHoldout: true,
          requireReviewedScenarioEvidence: true,
        ),
      );

      expect(report.ready, isFalse);
      expect(report.evidence.protectedHoldoutScenarioCount, 2);
      expect(
        report.evidence.protectedHoldoutScenarioCountByAgentKind,
        {
          AgentKind.taskAgent: 1,
          AgentKind.planningAgent: 1,
        },
      );
      expect(
        report.evidence.missingRequiredCapabilitySplitCells,
        {'holdout::planner.governance.required'},
      );
      expect(
        report.evidence.missingProtectedHoldoutPrimaryCapabilityIds,
        {'planner.governance.required'},
      );
      expect(
        report.failures,
        contains(
          'required capability split holdout::planner.governance.required '
          'scenario count 0 < 1',
        ),
      );
      expect(
        report.failures,
        contains(
          'capability planner.governance.required protected holdout '
          'scenario count 0 < 1',
        ),
      );
    },
  );

  test('corpus governance requires stress tags per required agent kind', () {
    final taskScenario = _reviewedScenario(
      _scenarioWith(
        taskWorkflowReportRecoveryScenario,
        id: 'governance_task_stale_adversarial',
        split: EvalScenarioSplit.development,
        capabilityId: 'task.governance.adversarial',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {'adversarial', 'stale-state'},
      ),
    );
    final plannerScenario = _reviewedScenario(
      _scenarioWith(
        plannerWorkflowFocusBoundaryScenario,
        id: 'governance_planner_scope_adversarial',
        split: EvalScenarioSplit.development,
        capabilityId: 'planner.governance.adversarial',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {'adversarial', 'scope-boundary'},
      ),
    );

    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: [taskScenario, plannerScenario],
      profiles: kDefaultProfiles,
      policy: const EvalTuningPolicy(
        name: 'agentStressTagContract',
        requiredAgentKinds: {
          AgentKind.taskAgent,
          AgentKind.planningAgent,
        },
        minScenarioCount: 2,
        minAdversarialScenarioCount: 2,
        minAdversarialScenariosPerAgentKind: 1,
        requiredAdversarialTags: {
          'scope-boundary',
          'stale-state',
        },
        requireAdversarialTagCoveragePerAgentKind: true,
        requireReviewedScenarioEvidence: true,
      ),
    );

    expect(report.ready, isFalse);
    expect(report.evidence.missingAdversarialTags, isEmpty);
    expect(
      report.evidence.missingAdversarialStressTagAgentKindCells,
      {
        'planningAgent::stale-state',
        'taskAgent::scope-boundary',
      },
    );
    expect(
      report.failures,
      contains(
        'missing adversarial stress tag agent-kind cell '
        'planningAgent::stale-state',
      ),
    );
    expect(
      report.failures,
      contains(
        'missing adversarial stress tag agent-kind cell '
        'taskAgent::scope-boundary',
      ),
    );
  });

  test(
    'scenario catalog preflight isolates catalog failures from run gates',
    () {
      final scenario = _scenarioWith(
        taskReleaseNotesScenario,
        id: 'catalog_preflight_public_only',
        split: EvalScenarioSplit.development,
        capabilityId: 'task.catalog.preflight',
      );

      final report = EvalTuningReadiness.assessScenarioCatalog(
        scenarios: [scenario],
        profiles: const [frontierFast],
      );

      expect(report.ready, isFalse);
      expect(report.evidenceLabel, 'catalog-blocked');
      expect(
        report.failures,
        contains('protected holdout evidence is missing'),
      );
      expect(
        report.failures,
        contains('scenario count 1 < 12'),
      );
      expect(
        report.failures.any((failure) => failure.contains('missing trace')),
        isFalse,
      );
      expect(
        report.failures.any((failure) => failure.contains('calibration')),
        isFalse,
      );
      final rendered = EvalTuningReadiness.renderScenarioCatalogPreflight(
        report,
      );
      expect(
        rendered,
        contains(
          'Scenario catalog preflight (modelClassTuning): catalog-blocked',
        ),
      );
      expect(
        rendered,
        contains(
          'catalog preflight does not evaluate traces, judge verdicts, '
          'provider provenance, model performance, or human calibration labels',
        ),
      );
    },
  );

  test('scenario catalog preflight passes reviewed protected evidence', () {
    final scenarios = _catalogPreflightReadyScenarios();
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: scenarios,
      profiles: kDefaultProfiles,
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: scenarios,
        protectedHoldoutScenarioIds: [
          'catalog_private_task_holdout_0',
          'catalog_private_task_holdout_1',
          'catalog_private_planner_holdout_0',
          'catalog_private_planner_holdout_1',
        ],
      ),
    );

    expect(report.ready, isTrue, reason: report.failures.join('\n'));
    expect(report.evidenceLabel, 'catalog-ready');
    expect(report.failures, isEmpty);
    expect(report.evidence.productionReplayHoldoutScenarioCount, 4);
    expect(report.evidence.protectedHoldoutScenarioCount, 4);
    expect(report.evidence.adversarialScenarioCount, 4);
    expect(report.evidence.missingAdversarialTags, isEmpty);
    expect(report.evidence.scenarioReviewRequiredCount, 8);
    expect(report.evidence.completedScenarioReviewCount, 8);
    final rendered = EvalTuningReadiness.renderScenarioCatalogPreflight(
      report,
    );
    expect(
      rendered,
      contains('Scenario catalog preflight (modelClassTuning): catalog-ready'),
    );
    expect(
      rendered,
      contains(
        'protected evidence holdout=4/4 agents={planningAgent:2, taskAgent:2}',
      ),
    );
    expect(rendered, contains('scenario reviews completed=8/8'));
  });

  test(
    'scenario catalog preflight explains unprotected production replay',
    () {
      final scenario = _scenarioWith(
        taskReleaseNotesScenario,
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.catalog.unprotected',
        id: 'catalog_unprotected_production_replay',
        source: EvalScenarioSource.productionReplay,
      );
      final evidence = EvalScenarioCatalogEvidence(
        scenarioSetDigest: EvalProvenance.scenarioSetDigest([scenario]),
        publicScenarioCount: 0,
        externalScenarioCount: 1,
        externalCatalogDigest: EvalProvenance.digestText('plain-list'),
        externalSourceLabel: 'plain_list.json',
        protectedHoldout: false,
        protectedScenarioIds: const [],
        protectedHoldoutScenarioIds: const [],
      );

      final report = EvalTuningReadiness.assessScenarioCatalog(
        scenarios: [scenario],
        profiles: kDefaultProfiles,
        scenarioCatalogEvidence: evidence,
      );

      expect(report.ready, isFalse);
      expect(
        report.failures,
        contains(
          'external production-replay holdouts are present but '
          'protectedHoldout=false; they cannot satisfy protected holdout '
          'evidence',
        ),
      );
    },
  );

  test('scenario catalog preflight redacts protected ids when rendered', () {
    final scenario = _scenarioWith(
      plannerCaptureOnlyScenario,
      split: EvalScenarioSplit.holdout,
      capabilityId: 'planner.catalog.redacted',
      id: 'private_customer_calendar_2026_06_10',
      source: EvalScenarioSource.productionReplay,
    );
    final report = EvalTuningReadiness.assessScenarioCatalog(
      scenarios: [scenario],
      profiles: kDefaultProfiles,
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: [scenario],
        protectedHoldoutScenarioIds: [scenario.id],
      ),
    );

    final rendered = EvalTuningReadiness.renderScenarioCatalogPreflight(
      report,
    );

    expect(rendered, isNot(contains(scenario.id)));
    expect(rendered, contains('<protected-scenario>'));
  });
}

class _PairwiseReadinessBench {
  const _PairwiseReadinessBench({
    required this.scenario,
    required this.profiles,
    required this.traces,
    required this.optionA,
    required this.optionB,
  });

  final EvalScenario scenario;
  final List<EvalProfile> profiles;
  final List<EvalTrace> traces;
  final EvalPairwiseTraceRef optionA;
  final EvalPairwiseTraceRef optionB;
}

_PairwiseReadinessBench _pairwiseBench() {
  const baseline = EvalProfile(
    name: 'pairwise-local-test',
    isLocal: true,
    modelClass: EvalModelClass.localSmall,
    modelId: 'pairwise-local-model',
    tokenBudget: 6000,
  );
  const candidate = EvalProfile(
    name: 'pairwise-frontier-test',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'pairwise-frontier-model',
    tokenBudget: 60000,
  );
  final scenario = _scenarioWith(
    taskReleaseNotesScenario,
    split: EvalScenarioSplit.development,
    capabilityId: 'task.pairwise.readiness',
  );
  final baselineTrace = _trace(scenario: scenario, profile: baseline);
  final candidateTrace = _trace(scenario: scenario, profile: candidate);

  return _PairwiseReadinessBench(
    scenario: scenario,
    profiles: const [baseline, candidate],
    traces: [baselineTrace, candidateTrace],
    optionA: _pairwiseRef(baselineTrace),
    optionB: _pairwiseRef(candidateTrace),
  );
}

EvalPairwiseTraceRef _pairwiseRef(EvalTrace trace) =>
    EvalPairwiseTraceRef.fromTrace(
      trace,
      traceDigest:
          trace.verdict?.traceDigest ??
          EvalProvenance.digestJson(trace.toJson()),
    );

String _pairwiseIntentOptionKey(EvalPairwiseTraceRef ref) =>
    '${ref.profileName}::${ref.profileDigest}::prompt-'
    '${ref.agentDirectiveVariantName}::${ref.agentDirectiveVariantDigest}';

Map<String, EvalPairwiseTraceRef> _pairwiseTraceRefsByKey(
  Iterable<EvalPairwiseTraceRef> refs,
) => Map.unmodifiable({
  for (final ref in refs) ref.traceKey: ref,
});

EvalPairwiseTraceRef _pairwiseRefWithTraceDigest(
  EvalPairwiseTraceRef ref,
  String traceDigest,
) {
  return EvalPairwiseTraceRef(
    runId: ref.runId,
    scenarioId: ref.scenarioId,
    profileName: ref.profileName,
    agentDirectiveVariantName: ref.agentDirectiveVariantName,
    agentKind: ref.agentKind,
    modelClass: ref.modelClass,
    capabilityId: ref.capabilityId,
    trialIndex: ref.trialIndex,
    cascadeWake: ref.cascadeWake,
    traceDigest: traceDigest,
    scenarioDigest: ref.scenarioDigest,
    profileDigest: ref.profileDigest,
    agentDirectiveVariantDigest: ref.agentDirectiveVariantDigest,
  );
}

EvalPairwisePreferenceVote _pairwiseVote({
  required EvalPairwiseTraceRef optionA,
  required EvalPairwiseTraceRef optionB,
  String voteId = 'pairwise-vote-1',
  String reviewerId = 'pairwise-reviewer-1',
  EvalPairwisePreferenceChoice choice = EvalPairwisePreferenceChoice.optionA,
  bool imported = false,
  BlindedPairwisePreferenceImportRecord? blindedImport,
  String? promptDigest,
  String calibrationSetVersion = 'pairwise-human-gold-v1',
  String? sourceManifestDigest,
  bool profileVisible = false,
  bool modelIdentityVisible = false,
  bool peerVotesVisible = false,
  bool traceOrderRandomized = true,
}) {
  return EvalPairwisePreferenceVote(
    voteId: voteId,
    optionA: optionA,
    optionB: optionB,
    reviewerId: reviewerId,
    reviewerKind: EvalPairwiseReviewerKind.human,
    promptDigest:
        promptDigest ?? EvalProvenance.digestText('readiness-pairwise-prompt'),
    calibrationSetVersion: calibrationSetVersion,
    profileVisible: profileVisible,
    modelIdentityVisible: modelIdentityVisible,
    peerVotesVisible: peerVotesVisible,
    traceOrderRandomized: traceOrderRandomized,
    choice: choice,
    rationale: 'Digest-bound readiness pairwise fixture.',
    blindedImport:
        blindedImport ??
        (imported
            ? _blindedPairwiseImport(
                optionA: optionA,
                optionB: optionB,
                sourceManifestDigest: sourceManifestDigest,
              )
            : null),
  );
}

BlindedPairwisePreferenceImportRecord _blindedPairwiseImport({
  required EvalPairwiseTraceRef optionA,
  required EvalPairwiseTraceRef optionB,
  String? sourceManifestDigest,
}) {
  return BlindedPairwisePreferenceImportRecord(
    blindedPairId: EvalProvenance.digestText(
      'blind:${optionA.artifactKey}:${optionB.artifactKey}',
    ),
    reviewPayloadDigest: EvalProvenance.digestText(
      'review:${optionA.artifactKey}:${optionB.artifactKey}',
    ),
    judgeManifestDigest: EvalProvenance.digestText('pairwise-judge-manifest'),
    privateKeyDigest: EvalProvenance.digestText('pairwise-private-key'),
    sourceManifestDigest:
        sourceManifestDigest ??
        EvalProvenance.digestText('pairwise-source-run'),
    optionARawTraceDigest: optionA.traceDigest,
    optionBRawTraceDigest: optionB.traceDigest,
  );
}

EvalRunManifest _manifestFor({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  required String targetKind,
  EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
  EvalPairwiseReadinessPlanEvidence? pairwiseReadinessPlanEvidence,
  EvalTuningReadinessPolicyEvidence? tuningReadinessPolicyEvidence,
}) {
  return EvalProvenance.captureRunManifest(
    runId: 'readiness-run',
    targetName: 'readiness-test',
    targetKind: targetKind,
    scenarios: scenarios,
    profiles: profiles,
    scenarioCatalogEvidence: scenarioCatalogEvidence,
    pairwiseReadinessPlanEvidence: pairwiseReadinessPlanEvidence,
    tuningReadinessPolicyEvidence: tuningReadinessPolicyEvidence,
    createdAt: DateTime(2026, 6, 10, 12),
    command: 'readiness-test',
    environment: const <String, String>{},
  );
}

EvalPairwiseReadinessPlanEvidence _pairwiseReadinessPlanEvidenceFor({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  required Set<String> comparisonKeys,
  int minDecisions = 1,
}) {
  final sortedKeys = comparisonKeys.toList()..sort();
  return EvalPairwiseReadinessPlanEvidence(
    planId: 'readiness-pairwise-plan',
    baseReadinessPolicy: 'modelClassTuning',
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
    profileSetDigest: EvalProvenance.profileSetDigest(profiles),
    profileBindingSetDigest: EvalProvenance.profileBindingSetDigest([
      for (final profile in profiles)
        evalProfileConfig(profile).toExecutionBinding(),
    ]),
    minBlindedPairwisePreferenceDecisions: minDecisions,
    comparisonCount: sortedKeys.length,
    pairwiseReadinessPlanSubjectDigest: EvalProvenance.digestJson({
      'planId': 'readiness-pairwise-plan',
      'comparisonKeys': sortedKeys,
    }),
  );
}

EvalScenarioCatalogEvidence _protectedEvidence({
  required List<EvalScenario> scenarios,
  required List<String> protectedHoldoutScenarioIds,
  List<String>? protectedScenarioIds,
}) {
  final allProtectedScenarioIds =
      protectedScenarioIds ?? protectedHoldoutScenarioIds;
  return EvalScenarioCatalogEvidence(
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
    publicScenarioCount: scenarios.length - allProtectedScenarioIds.length,
    externalScenarioCount: allProtectedScenarioIds.length,
    externalCatalogDigest: EvalProvenance.digestText('private-catalog'),
    externalCatalogId: 'private-production-replay-v1',
    externalSourceLabel: 'protected_scenarios.json',
    protectedHoldout: true,
    protectedScenarioIds: allProtectedScenarioIds,
    protectedHoldoutScenarioIds: protectedHoldoutScenarioIds,
  );
}

EvalScenario _scenarioWith(
  EvalScenario scenario, {
  required EvalScenarioSplit split,
  required String capabilityId,
  String? id,
  EvalScenarioSource? source,
  bool? isAdversarial,
  Set<String>? tags,
}) {
  final json = scenario.toJson();
  json['id'] = id ?? '${scenario.id}_${split.name}';
  final metadata = <String, dynamic>{
    ...(json['metadata'] as Map<String, dynamic>),
    'split': split.name,
    'capabilityIds': [capabilityId],
  };
  if (source != null) metadata['source'] = source.name;
  if (isAdversarial != null) metadata['isAdversarial'] = isAdversarial;
  if (tags != null) metadata['tags'] = tags.toList()..sort();
  metadata.remove('review');
  json['metadata'] = metadata;
  return EvalScenario.fromJson(json);
}

List<EvalScenario> _catalogPreflightReadyScenarios() {
  return [
    _reviewedScenario(
      _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        id: 'catalog_private_task_holdout_0',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.catalog.one',
        source: EvalScenarioSource.productionReplay,
        isAdversarial: false,
        tags: {'private', 'production-replay'},
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        taskReleaseNotesScenario,
        id: 'catalog_private_task_holdout_1',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'task.catalog.two',
        source: EvalScenarioSource.productionReplay,
        isAdversarial: false,
        tags: {'private', 'production-replay'},
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        plannerCaptureOnlyScenario,
        id: 'catalog_private_planner_holdout_0',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'planner.catalog.one',
        source: EvalScenarioSource.productionReplay,
        isAdversarial: false,
        tags: {'private', 'production-replay'},
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        plannerWorkflowAmbiguousCarryoverScenario,
        id: 'catalog_private_planner_holdout_1',
        split: EvalScenarioSplit.holdout,
        capabilityId: 'planner.catalog.two',
        source: EvalScenarioSource.productionReplay,
        isAdversarial: false,
        tags: {'private', 'production-replay'},
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        taskWorkflowReleaseNotesScenario,
        id: 'catalog_adversarial_task_0',
        split: EvalScenarioSplit.development,
        capabilityId: 'task.catalog.one',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {
          'adversarial',
          'ambiguous-reference',
          'scope-boundary',
        },
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        taskWorkflowReportRecoveryScenario,
        id: 'catalog_adversarial_task_1',
        split: EvalScenarioSplit.development,
        capabilityId: 'task.catalog.two',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {
          'adversarial',
          'stale-state',
          'tool-recovery',
        },
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        plannerWorkflowAmbiguousCarryoverScenario,
        id: 'catalog_adversarial_planner_0',
        split: EvalScenarioSplit.development,
        capabilityId: 'planner.catalog.one',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {
          'adversarial',
          'ambiguous-reference',
          'stale-state',
        },
      ),
    ),
    _reviewedScenario(
      _scenarioWith(
        plannerCaptureOnlyScenario,
        id: 'catalog_adversarial_planner_1',
        split: EvalScenarioSplit.development,
        capabilityId: 'planner.catalog.two',
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {
          'adversarial',
          'scope-boundary',
          'tool-recovery',
        },
      ),
    ),
    _scenarioWith(
      taskWorkflowPendingProposalMergeScenario,
      id: 'catalog_public_task_0',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.catalog.one',
      source: EvalScenarioSource.handAuthored,
      isAdversarial: false,
      tags: {'public'},
    ),
    _scenarioWith(
      taskReleaseNotesScenario,
      id: 'catalog_public_task_1',
      split: EvalScenarioSplit.development,
      capabilityId: 'task.catalog.two',
      source: EvalScenarioSource.handAuthored,
      isAdversarial: false,
      tags: {'public'},
    ),
    _scenarioWith(
      plannerCaptureOnlyScenario,
      id: 'catalog_public_planner_0',
      split: EvalScenarioSplit.development,
      capabilityId: 'planner.catalog.one',
      source: EvalScenarioSource.handAuthored,
      isAdversarial: false,
      tags: {'public'},
    ),
    _scenarioWith(
      plannerCaptureOnlyScenario,
      id: 'catalog_public_planner_1',
      split: EvalScenarioSplit.development,
      capabilityId: 'planner.catalog.two',
      source: EvalScenarioSource.handAuthored,
      isAdversarial: false,
      tags: {'public'},
    ),
  ];
}

EvalScenario _reviewedScenario(
  EvalScenario scenario, {
  EvalScenarioReviewStatus status = EvalScenarioReviewStatus.reviewed,
  String rationale = 'Digest-bound readiness review fixture.',
  bool includeSourceDigest = true,
  String? sourceDigest,
}) {
  final json = scenario.toJson();
  json['metadata'] = <String, dynamic>{
    ...(json['metadata'] as Map<String, dynamic>),
    'review': EvalScenarioReview(
      status: status,
      reviewer: 'human-reviewer',
      reviewedAt: '2026-06-10T12:00:00.000Z',
      subjectDigest: EvalProvenance.scenarioReviewSubjectDigest(scenario),
      rationale: rationale,
      sourceDigest: includeSourceDigest
          ? sourceDigest ?? EvalProvenance.digestText('source:${scenario.id}')
          : null,
      sourceLabel: scenario.metadata.source == EvalScenarioSource.adversarial
          ? 'readiness-adversarial-fixture'
          : null,
    ).toJson(),
  };
  return EvalScenario.fromJson(json);
}

EvalTrace _trace({
  required EvalScenario scenario,
  required EvalProfile profile,
  int trialIndex = 0,
  bool judged = true,
  bool level1Passed = true,
  String calibrationSetVersion = 'uncalibrated',
  bool modelIdentityVisible = false,
  bool includeBlindedImport = true,
  bool judgePass = true,
  int goalAttainment = 5,
  int quality = 5,
  int efficiency = 4,
  InferenceUsage usage = const InferenceUsage(
    inputTokens: 100,
    outputTokens: 50,
  ),
  EvalAgentDirectiveVariant agentDirectiveVariant =
      const EvalAgentDirectiveVariant(),
  EvalTraceCascadeWake? cascadeWake,
  String? manifestDigest,
}) {
  final provenance = EvalProvenance.capture(
    scenario: scenario,
    profile: profile,
    agentDirectiveVariant: agentDirectiveVariant,
    manifestDigest: manifestDigest ?? EvalProvenance.unboundManifestDigest,
  );
  final traceDigest = EvalProvenance.digestText(
    '${scenario.id}-${profile.name}-'
    '${agentDirectiveVariant.name}-$trialIndex',
  );
  return EvalTrace(
    runId: 'readiness-run',
    scenario: scenario,
    profile: profile,
    agentDirectiveVariant: agentDirectiveVariant,
    provenance: provenance,
    trialIndex: trialIndex,
    cascadeWake: cascadeWake,
    output: AgentRunOutput(
      success: true,
      usage: usage,
      report: const AgentReportRecord(
        oneLiner: 'Handled',
        tldr: 'The wake produced durable state.',
        content: 'Done.',
      ),
    ),
    level1Checks: [
      EvalCheck(
        name: 'example',
        passed: level1Passed,
        detail: level1Passed ? '' : 'failed',
      ),
    ],
    verdict: judged
        ? JudgeVerdict(
            traceDigest: traceDigest,
            goalAttainment: goalAttainment,
            quality: quality,
            efficiency: efficiency,
            pass: judgePass,
            judge: JudgeProvenanceRecord(
              judgeName: 'claude-code',
              judgeModel: 'test-judge',
              promptDigest: EvalProvenance.promptDigest(),
              calibrationSetVersion: calibrationSetVersion,
              profileVisible: true,
              modelIdentityVisible: modelIdentityVisible,
            ),
            blindedImport: !modelIdentityVisible && includeBlindedImport
                ? BlindedVerdictImportRecord(
                    blindedTraceId: EvalProvenance.digestText(
                      'blind:${scenario.id}:${profile.name}:'
                      '${agentDirectiveVariant.name}:$trialIndex',
                    ),
                    reviewPayloadDigest: EvalProvenance.digestText(
                      'review:${scenario.id}:${profile.name}:'
                      '${agentDirectiveVariant.name}:$trialIndex',
                    ),
                    judgeManifestDigest: EvalProvenance.digestText(
                      'judge-manifest:${scenario.id}:${profile.name}:'
                      '${agentDirectiveVariant.name}:$trialIndex',
                    ),
                    privateKeyDigest: EvalProvenance.digestText(
                      'private-key:${scenario.id}:${profile.name}:'
                      '${agentDirectiveVariant.name}:$trialIndex',
                    ),
                    sourceManifestDigest: provenance.manifestDigest,
                    rawTraceDigest: traceDigest,
                  )
                : null,
          )
        : null,
  );
}

JudgeCalibrationSet _calibrationSetFor(
  List<EvalTrace> traces, {
  String version = 'human-gold-v1',
  String judgeCalibrationSetVersion = 'gold-v1',
  JudgeCalibrationSourceRun? sourceRun,
}) {
  return JudgeCalibrationSet(
    version: version,
    judgeCalibrationSetVersion: judgeCalibrationSetVersion,
    sourceRun: sourceRun,
    labels: [
      for (final trace in traces) _calibrationLabelForTrace(trace),
    ],
  );
}

JudgeCalibrationSet _sampledCalibrationSetFromTemplate({
  required List<EvalTrace> traces,
  required EvalRunManifest manifest,
  required int maxRows,
  Map<String, dynamic> Function(Map<String, dynamic> selection)?
  mutateSelection,
}) {
  final template = EvalJudgeCalibration.labelTemplateJson(
    version: 'human-gold-v1',
    traces: traces,
    manifest: manifest,
    maxRows: maxRows,
  );
  final templateRows =
      template['labelTemplates']! as List<Map<String, dynamic>>;
  final selection = {
    ...(template['calibrationTemplateSelection']! as Map<String, dynamic>),
  };
  final tracesByKey = {
    for (final trace in traces) EvalTraceKey.fromTrace(trace).id: trace,
  };
  return JudgeCalibrationSet(
    version: template['version']! as String,
    judgeCalibrationSetVersion:
        template['judgeCalibrationSetVersion']! as String,
    sourceRun: JudgeCalibrationSourceRun.fromJson(
      template['sourceRun']! as Map<String, dynamic>,
    ),
    templateSelection: JudgeCalibrationTemplateSelectionEvidence.fromJson(
      mutateSelection?.call(selection) ?? selection,
    ),
    labels: [
      for (final row in templateRows)
        _calibrationLabelForTrace(
          tracesByKey[EvalTraceKey.fromJson(
            row['key']! as Map<String, dynamic>,
          ).id]!,
        ),
    ],
  );
}

JudgeCalibrationLabel _calibrationLabelForTrace(
  EvalTrace trace, {
  bool? expectedPass,
  int? goalAttainment,
  int? quality,
  int? efficiency,
}) {
  final verdict = trace.verdict!;
  final humanGoalAttainment = goalAttainment ?? verdict.goalAttainment;
  final humanQuality = quality ?? verdict.quality;
  final humanEfficiency = efficiency ?? verdict.efficiency;
  return JudgeCalibrationLabel(
    key: EvalTraceKey.fromTrace(trace),
    scenarioDigest: trace.provenance.scenarioDigest,
    profileDigest: trace.provenance.profileDigest,
    agentDirectiveVariantDigest: trace.provenance.agentDirectiveVariantDigest,
    traceDigest: verdict.traceDigest,
    verdictDigest: EvalProvenance.digestJson(verdict.toJson()),
    expectedPass: expectedPass ?? verdict.pass,
    goalAttainmentMin: humanGoalAttainment,
    goalAttainmentMax: humanGoalAttainment,
    qualityMin: humanQuality,
    qualityMax: humanQuality,
    efficiencyMin: humanEfficiency,
    efficiencyMax: humanEfficiency,
    labeler: 'human-reviewer',
    adjudicationStatus: 'reviewed',
    rationale: 'Digest-bound readiness calibration fixture.',
  );
}

JudgeCalibrationReport _calibrationReport({
  required int judgedTraceCount,
  required int evaluatedCount,
  required int passAgreementCount,
  required int scoreAgreementCount,
  String calibrationSetVersion = 'human-gold-v1',
  String judgeCalibrationSetVersion = 'gold-v1',
  int falsePassCount = 0,
  int falseFailCount = 0,
  int unblindedVerdictCount = 0,
  int staleLabelCount = 0,
  int missingTraceCount = 0,
  int missingVerdictCount = 0,
  int judgeCalibrationMismatchCount = 0,
  int humanReviewPairCount = 0,
  int humanPassAgreementPairCount = 0,
  int humanScoreAgreementPairCount = 0,
  int unresolvedHumanDisagreementCount = 0,
  int unblindedHumanReviewCount = 0,
  List<JudgeCalibrationSliceSummary> promptVariantSummaries = const [],
  List<JudgeCalibrationSliceSummary> modelClassCapabilitySummaries = const [],
  List<JudgeCalibrationSliceSummary> modelClassPromptVariantSummaries =
      const [],
}) {
  return JudgeCalibrationReport(
    calibrationSetVersion: calibrationSetVersion,
    judgeCalibrationSetVersion: judgeCalibrationSetVersion,
    labelCount: evaluatedCount + staleLabelCount + missingTraceCount,
    judgedTraceCount: judgedTraceCount,
    evaluatedCount: evaluatedCount,
    staleLabelCount: staleLabelCount,
    missingTraceCount: missingTraceCount,
    missingVerdictCount: missingVerdictCount,
    unlabeledVerdictCount: judgedTraceCount - evaluatedCount,
    falsePassCount: falsePassCount,
    falseFailCount: falseFailCount,
    unblindedVerdictCount: unblindedVerdictCount,
    judgeCalibrationMismatchCount: judgeCalibrationMismatchCount,
    passAgreementCount: passAgreementCount,
    scoreAgreementCount: scoreAgreementCount,
    humanReviewPairCount: humanReviewPairCount,
    humanPassAgreementPairCount: humanPassAgreementPairCount,
    humanScoreAgreementPairCount: humanScoreAgreementPairCount,
    unresolvedHumanDisagreementCount: unresolvedHumanDisagreementCount,
    unblindedHumanReviewCount: unblindedHumanReviewCount,
    capabilitySummaries: const [],
    modelClassSummaries: const [],
    modelClassCapabilitySummaries: modelClassCapabilitySummaries,
    promptVariantSummaries: promptVariantSummaries,
    modelClassPromptVariantSummaries: modelClassPromptVariantSummaries,
    findings: const [],
  );
}
