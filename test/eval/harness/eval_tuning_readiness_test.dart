import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';

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
        isAdversarial: true,
        tags: {
          'adversarial',
          'stale-state',
          'tool-recovery',
        },
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
        minAdversarialScenarioCount: 2,
        minAdversarialScenariosPerAgentKind: 1,
        minAdversarialScenariosPerCapability: 1,
        requiredAdversarialTags: {
          'ambiguous-reference',
          'scope-boundary',
          'stale-state',
          'tool-recovery',
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

    expect(report.ready, isTrue);
    expect(report.failures, isEmpty);
    expect(report.expectedTraceCount, 8);
    expect(report.traceCount, 8);
    expect(report.judgedTraceCount, 8);
    expect(report.evidence.adversarialScenarioCount, 2);
    expect(report.evidence.productionReplayHoldoutScenarioCount, 1);
    expect(report.evidence.protectedHoldoutScenarioCount, 1);
    expect(report.evidence.scenarioReviewRequiredCount, 2);
    expect(report.evidence.completedScenarioReviewCount, 2);
    expect(report.evidence.missingAdversarialTags, isEmpty);
    final rendered = EvalTuningReadiness.render(report);
    expect(
      rendered,
      contains(
        'stress catalog adversarial=2/2 productionReplayHoldout=1/1',
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
        'stress tags={adversarial, ambiguous-reference, scope-boundary, '
        'stale-state, tool-recovery} missing={}',
      ),
    );
    expect(
      rendered,
      contains('scenario reviews completed=2/2 missing={}'),
    );
  });

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
      contains('calibration report has 1 calibration mismatches'),
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

    expect(report.ready, isTrue);
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

EvalRunManifest _manifestFor({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  required String targetKind,
  EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
}) {
  return EvalProvenance.captureRunManifest(
    runId: 'readiness-run',
    targetName: 'readiness-test',
    targetKind: targetKind,
    scenarios: scenarios,
    profiles: profiles,
    scenarioCatalogEvidence: scenarioCatalogEvidence,
    createdAt: DateTime(2026, 6, 10, 12),
    command: 'readiness-test',
    environment: const <String, String>{},
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
        tags: {'adversarial', 'ambiguous-reference'},
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
        tags: {'adversarial', 'tool-recovery'},
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
        tags: {'adversarial', 'stale-state'},
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
        tags: {'adversarial', 'scope-boundary'},
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
  EvalTraceCascadeWake? cascadeWake,
}) {
  return EvalTrace(
    runId: 'readiness-run',
    scenario: scenario,
    profile: profile,
    provenance: EvalProvenance.capture(scenario: scenario, profile: profile),
    trialIndex: trialIndex,
    cascadeWake: cascadeWake,
    output: const AgentRunOutput(
      success: true,
      usage: InferenceUsage(inputTokens: 100, outputTokens: 50),
      report: AgentReportRecord(
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
            traceDigest: EvalProvenance.digestText(
              '${scenario.id}-${profile.name}-$trialIndex',
            ),
            goalAttainment: 5,
            quality: 5,
            efficiency: 4,
            pass: true,
            judge: JudgeProvenanceRecord(
              judgeName: 'claude-code',
              judgeModel: 'test-judge',
              promptDigest: EvalProvenance.promptDigest(),
              calibrationSetVersion: calibrationSetVersion,
              profileVisible: true,
              modelIdentityVisible: modelIdentityVisible,
            ),
          )
        : null,
  );
}

JudgeCalibrationSet _calibrationSetFor(
  List<EvalTrace> traces, {
  String version = 'human-gold-v1',
  String judgeCalibrationSetVersion = 'gold-v1',
}) {
  return JudgeCalibrationSet(
    version: version,
    judgeCalibrationSetVersion: judgeCalibrationSetVersion,
    labels: [
      for (final trace in traces)
        JudgeCalibrationLabel(
          key: EvalTraceKey.fromTrace(trace),
          scenarioDigest: trace.provenance.scenarioDigest,
          profileDigest: trace.provenance.profileDigest,
          agentDirectiveVariantDigest:
              trace.provenance.agentDirectiveVariantDigest,
          traceDigest: trace.verdict!.traceDigest,
          verdictDigest: EvalProvenance.digestJson(trace.verdict!.toJson()),
          expectedPass: trace.verdict!.pass,
          goalAttainmentMin: trace.verdict!.goalAttainment,
          goalAttainmentMax: trace.verdict!.goalAttainment,
          qualityMin: trace.verdict!.quality,
          qualityMax: trace.verdict!.quality,
          efficiencyMin: trace.verdict!.efficiency,
          efficiencyMax: trace.verdict!.efficiency,
          labeler: 'human-reviewer',
          adjudicationStatus: 'reviewed',
          rationale: 'Digest-bound readiness calibration fixture.',
        ),
    ],
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
    findings: const [],
  );
}
