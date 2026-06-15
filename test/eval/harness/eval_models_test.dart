import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';

void main() {
  test('profile cost weights round-trip and price cached/thought tokens', () {
    const profile = EvalProfile(
      name: 'frontier-costed',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'frontier-costed-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 3,
      outputTokenCostMicros: 12,
      thoughtsTokenCostMicros: 12,
    );

    final roundTripped = EvalProfile.fromJson(profile.toJson());

    expect(roundTripped.toJson(), profile.toJson());
    expect(roundTripped.usesWeightedTokenCosts, isTrue);
    expect(
      roundTripped.estimatedUsageCostMicros(
        const InferenceUsage(
          inputTokens: 100,
          cachedInputTokens: 40,
          outputTokens: 10,
          thoughtsTokens: 5,
        ),
      ),
      400,
    );
  });

  test('default profiles keep legacy unweighted cost semantics', () {
    const profile = EvalProfile(
      name: 'frontier-default',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-default-model',
      tokenBudget: 10000,
    );

    final json = profile.toJson();

    expect(profile.usesWeightedTokenCosts, isFalse);
    expect(json, isNot(containsPair('inputTokenCostMicros', anything)));
    expect(json, isNot(containsPair('outputTokenCostMicros', anything)));
    expect(
      profile.estimatedUsageCostMicros(
        const InferenceUsage(inputTokens: 30, outputTokens: 12),
      ),
      42,
    );
  });

  test('directive variants round-trip and merge with a baseline', () {
    const variant = EvalAgentDirectiveVariant(
      name: 'metadata-first-v2',
      generalDirective: 'Call metadata tools before reports.',
      reportDirective: 'Report only after durable proposals are created.',
    );

    final roundTripped = EvalAgentDirectiveVariant.fromJson(variant.toJson());

    expect(roundTripped.toJson(), variant.toJson());
    expect(
      roundTripped.mergedGeneralDirective('Baseline.'),
      'Baseline.\n\nCall metadata tools before reports.',
    );
    expect(
      roundTripped.reportDirective,
      'Report only after durable proposals are created.',
    );
  });

  test('profile cost estimation clamps cached tokens to input tokens', () {
    const profile = EvalProfile(
      name: 'frontier-cached-clamp',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'frontier-cached-clamp-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 5,
    );

    expect(
      profile.estimatedUsageCostMicros(
        const InferenceUsage(
          inputTokens: 10,
          cachedInputTokens: 25,
          outputTokens: 3,
        ),
      ),
      13,
    );
  });

  test('weighted profiles expose missing estimated-cost fields', () {
    const profile = EvalProfile(
      name: 'frontier-missing-cost',
      isLocal: false,
      modelClass: EvalModelClass.frontierReasoning,
      modelId: 'frontier-missing-cost-model',
      tokenBudget: 10000,
      inputTokenCostMicros: 5,
    );

    expect(
      profile.missingEstimatedCostFields(
        const InferenceUsage(outputTokens: 20),
        requireCoreTokenCounts: true,
      ),
      ['inputTokens', 'cachedInputTokens'],
    );
    expect(
      profile.estimatedUsageCostMicrosOrNull(
        const InferenceUsage(outputTokens: 20),
        requireCoreTokenCounts: true,
      ),
      isNull,
    );
  });

  test('blinded verdict import record rejects malformed provenance', () {
    final valid = _blindedVerdictImportJson();

    expect(
      BlindedVerdictImportRecord.fromJson(valid).toJson(),
      valid,
    );
    expect(
      () => BlindedVerdictImportRecord.fromJson({
        ...valid,
        'kind': 'wrong.kind',
      }),
      throwsFormatException,
    );
    expect(
      () => BlindedVerdictImportRecord.fromJson({
        ...valid,
        'blindedTraceId': '   ',
      }),
      throwsFormatException,
    );
    expect(
      () => BlindedVerdictImportRecord.fromJson({
        ...valid,
        'rawTraceDigest': 'sha256:not-a-real-digest',
      }),
      throwsFormatException,
    );
    expect(
      () => BlindedVerdictImportRecord.fromJson({
        ...valid,
        'unexpected': true,
      }),
      throwsFormatException,
    );
  });

  test('judge verdict rejects unknown top-level fields', () {
    final verdict = JudgeVerdict(
      traceDigest: EvalProvenance.digestText('trace'),
      goalAttainment: 5,
      quality: 5,
      efficiency: 4,
      pass: true,
      judge: JudgeProvenanceRecord(
        judgeName: 'claude-code',
        judgeModel: 'test-judge',
        promptDigest: EvalProvenance.digestText('prompt'),
        calibrationSetVersion: 'gold-v1',
        profileVisible: true,
        modelIdentityVisible: true,
      ),
    ).toJson();

    expect(
      () => JudgeVerdict.fromJson({...verdict, 'unexpected': true}),
      throwsFormatException,
    );
  });

  test('tuning readiness contract evidence round-trips and binds manifest', () {
    final scenarioSetDigest = EvalProvenance.scenarioSetDigest([
      taskReleaseNotesScenario,
    ]);
    final evidence = EvalProvenance.tuningReadinessContractEvidence(
      scenarioSetDigest: scenarioSetDigest,
      requiredPrimaryCapabilityIds: const {
        'task.grooming.structuredfields',
        'planner.capture.parseonly',
      },
    );
    const policy = EvalTuningPolicy.modelClassTuning(
      requiredPrimaryCapabilityIds: {'task.grooming.structuredfields'},
    );
    final policyEvidence = EvalTuningReadinessPolicyEvidence(
      policyName: policy.name,
      policyDigest: policy.policyDigest,
    );
    final cascadeScenario = taskWorkflowChecklistTranscriptCascadeScenario;
    final topologyEvidence = EvalProvenance.taskLogCascadeTraceTopologyEvidence(
      scenarioSetDigest: EvalProvenance.scenarioSetDigest([
        cascadeScenario,
      ]),
      profileSetDigest: EvalProvenance.profileSetDigest([
        kDefaultProfiles.first,
      ]),
      agentDirectiveVariantSetDigest:
          EvalProvenance.agentDirectiveVariantSetDigest(
            const [EvalAgentDirectiveVariant()],
          ),
      cascadeWakeCountByScenarioId: {
        cascadeScenario.id: cascadeScenario.appState.taskLogEntries.length,
      },
    );

    expect(evidence.toJson()['requiredPrimaryCapabilityIds'], [
      'planner.capture.parseonly',
      'task.grooming.structuredfields',
    ]);
    expect(
      EvalTuningReadinessContractEvidence.fromJson(
        evidence.toJson(),
      ).toJson(),
      evidence.toJson(),
    );
    expect(
      EvalTuningReadinessPolicyEvidence.fromJson(
        policyEvidence.toJson(),
      ).toJson(),
      policyEvidence.toJson(),
    );
    expect(
      EvalTraceTopologyEvidence.fromJson(
        topologyEvidence.toJson(),
      ).toJson(),
      topologyEvidence.toJson(),
    );

    final changedEvidence = EvalProvenance.tuningReadinessContractEvidence(
      scenarioSetDigest: scenarioSetDigest,
      requiredPrimaryCapabilityIds: const {'task.grooming.structuredfields'},
    );
    final changedTopologyEvidence =
        EvalProvenance.taskLogCascadeTraceTopologyEvidence(
          scenarioSetDigest: topologyEvidence.scenarioSetDigest,
          profileSetDigest: topologyEvidence.profileSetDigest,
          agentDirectiveVariantSetDigest:
              topologyEvidence.agentDirectiveVariantSetDigest,
          cascadeWakeCountByScenarioId: {
            cascadeScenario.id:
                topologyEvidence.cascadeWakeCountByScenarioId[cascadeScenario
                    .id]! +
                1,
          },
        );
    expect(
      changedEvidence.readinessContractSubjectDigest,
      isNot(evidence.readinessContractSubjectDigest),
    );
    expect(
      changedTopologyEvidence.traceTopologySubjectDigest,
      isNot(topologyEvidence.traceTopologySubjectDigest),
    );

    final manifestWithoutContract = EvalProvenance.captureRunManifest(
      runId: 'readiness-contract-model-test',
      targetName: 'model-test',
      targetKind: 'test',
      scenarios: [taskReleaseNotesScenario],
      profiles: [kDefaultProfiles.first],
      createdAt: DateTime.utc(2026, 6, 12),
      command: 'model test',
      environment: const <String, String>{},
    );
    final manifestWithContract = EvalProvenance.captureRunManifest(
      runId: 'readiness-contract-model-test',
      targetName: 'model-test',
      targetKind: 'test',
      scenarios: [taskReleaseNotesScenario],
      profiles: [kDefaultProfiles.first],
      createdAt: DateTime.utc(2026, 6, 12),
      command: 'model test',
      environment: const <String, String>{},
      tuningReadinessContractEvidence: evidence,
      tuningReadinessPolicyEvidence: policyEvidence,
    );
    final manifestWithoutTopology = EvalProvenance.captureRunManifest(
      runId: 'trace-topology-model-test',
      targetName: 'model-test',
      targetKind: 'test',
      scenarios: [cascadeScenario],
      profiles: [kDefaultProfiles.first],
      createdAt: DateTime.utc(2026, 6, 12),
      command: 'model test',
      environment: const <String, String>{},
    );
    final manifestWithTopology = EvalProvenance.captureRunManifest(
      runId: 'trace-topology-model-test',
      targetName: 'model-test',
      targetKind: 'test',
      scenarios: [cascadeScenario],
      profiles: [kDefaultProfiles.first],
      createdAt: DateTime.utc(2026, 6, 12),
      command: 'model test',
      environment: const <String, String>{},
      traceTopologyEvidence: topologyEvidence,
    );
    final launchEvidence = EvalUseCaseWorkOrderLaunchEvidence(
      workOrderRef: EvalProvenance.digestText('work-order-ref'),
      workOrderDigest: EvalProvenance.digestText('work-order'),
      sourceExperimentPlanDigest: EvalProvenance.digestText('plan'),
      sourceMatrixDigest: EvalProvenance.digestText('matrix'),
      workOrderBatchRefs: [EvalProvenance.digestText('batch')],
      workOrderBatchSetDigest: EvalProvenance.digestJson([
        EvalProvenance.digestText('batch'),
      ]),
      requiredPrimaryCapabilityIds: const {'task.workflow'},
      promptVariantNames: const ['default'],
      workOrderLaunchSubjectDigest: '',
    );
    final boundLaunchEvidence = EvalUseCaseWorkOrderLaunchEvidence(
      workOrderRef: launchEvidence.workOrderRef,
      workOrderDigest: launchEvidence.workOrderDigest,
      sourceExperimentPlanDigest: launchEvidence.sourceExperimentPlanDigest,
      sourceMatrixDigest: launchEvidence.sourceMatrixDigest,
      workOrderBatchRefs: launchEvidence.workOrderBatchRefs,
      workOrderBatchSetDigest: launchEvidence.workOrderBatchSetDigest,
      requiredPrimaryCapabilityIds: launchEvidence.requiredPrimaryCapabilityIds,
      promptVariantNames: launchEvidence.promptVariantNames,
      workOrderLaunchSubjectDigest: EvalProvenance.digestJson(
        launchEvidence.toSubjectJson(),
      ),
    );
    final manifestWithLaunchEvidence = EvalProvenance.captureRunManifest(
      runId: 'work-order-launch-model-test',
      targetName: 'model-test',
      targetKind: 'test',
      scenarios: [taskReleaseNotesScenario],
      profiles: [kDefaultProfiles.first],
      createdAt: DateTime.utc(2026, 6, 12),
      command: 'model test',
      environment: const <String, String>{},
      useCaseWorkOrderLaunchEvidence: boundLaunchEvidence,
    );

    expect(
      manifestWithContract.manifestDigest,
      isNot(manifestWithoutContract.manifestDigest),
    );
    expect(
      manifestWithContract
          .tuningReadinessContractEvidence
          ?.readinessContractSubjectDigest,
      evidence.readinessContractSubjectDigest,
    );
    expect(
      manifestWithContract.tuningReadinessPolicyEvidence?.toJson(),
      policyEvidence.toJson(),
    );
    expect(
      manifestWithTopology.manifestDigest,
      isNot(manifestWithoutTopology.manifestDigest),
    );
    expect(
      manifestWithTopology.traceTopologyEvidence?.toJson(),
      topologyEvidence.toJson(),
    );
    expect(
      manifestWithLaunchEvidence.manifestDigest,
      isNot(manifestWithoutContract.manifestDigest),
    );
    expect(
      manifestWithLaunchEvidence.useCaseWorkOrderLaunchEvidence?.toJson(),
      boundLaunchEvidence.toJson(),
    );
  });
}

Map<String, dynamic> _blindedVerdictImportJson() => <String, dynamic>{
  'schemaVersion': BlindedVerdictImportRecord.schemaVersion,
  'kind': BlindedVerdictImportRecord.kindValue,
  'blindedTraceId': 'blind-0001',
  'reviewPayloadDigest': EvalProvenance.digestText('review-payload'),
  'judgeManifestDigest': EvalProvenance.digestText('judge-manifest'),
  'privateKeyDigest': EvalProvenance.digestText('private-key'),
  'sourceManifestDigest': EvalProvenance.digestText('manifest'),
  'rawTraceDigest': EvalProvenance.digestText('raw-trace'),
};
