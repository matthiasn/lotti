import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../harness/eval_profile_config.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  final scenario = taskReleaseNotesScenario;
  const profile = EvalProfile(
    name: 'verifier-profile',
    isLocal: false,
    modelClass: EvalModelClass.frontierFast,
    modelId: 'verifier-model',
    tokenBudget: 10000,
  );

  test('passes a complete trace and verdict matrix', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      level1Checks: runLevel1(
        scenario,
        _outputFor(profile),
        profile: profile,
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      artifactNames: const ['trace.trace.json', 'trace.verdict.json'],
    );

    expect(verification.errors, isEmpty);
  });

  test('detects missing traces and orphan verdict artifacts', () {
    final verification = _verify(
      runId: 'run-1',
      traces: const [],
      scenarios: [scenario],
      profiles: [profile],
      artifactNames: const ['orphan.verdict.json'],
    );

    expect(verification.errors, contains('run has no traces'));
    expect(
      verification.errors,
      contains(
        'missing trace for task_release_notes::verifier-profile::trial-0',
      ),
    );
    expect(
      verification.errors,
      contains('orphan verdict artifact for orphan'),
    );
  });

  test('rejects duplicated trace keys and wrong run ids', () {
    final checks = runLevel1(scenario, _outputFor(profile), profile: profile);
    final trace = _trace(
      runId: 'other-run',
      scenario: scenario,
      profile: profile,
      level1Checks: checks,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace, trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'duplicate trace for task_release_notes::verifier-profile::trial-0',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 has runId other-run, '
        'expected run-1',
      ),
    );
  });

  test('recomputes Level 1 checks instead of trusting stored empty checks', () {
    final verification = _verify(
      runId: 'run-1',
      traces: [
        _trace(
          scenario: scenario,
          profile: profile,
          level1Checks: const [],
        ),
      ],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing Level 1 check succeeded',
      ),
    );
  });

  test('rejects pass verdicts over failed durable-state oracles', () {
    final scenarioWithOracle = EvalScenario(
      id: scenario.id,
      title: scenario.title,
      agentKind: scenario.agentKind,
      appState: scenario.appState,
      userInput: scenario.userInput,
      metadata: scenario.metadata,
      expectations: const EvalExpectations(
        durableState: ExpectedDurableState(
          reportContains: {'unmet durable goal'},
        ),
      ),
    );
    final output = _outputFor(profile);
    final trace = _trace(
      scenario: scenarioWithOracle,
      profile: profile,
      output: output,
      level1Checks: runLevel1(
        scenarioWithOracle,
        output,
        profile: profile,
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenarioWithOracle],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict passes despite failed Level 1 checks',
      ),
    );
  });

  test('rejects invalid scenario catalog references', () {
    final invalidScenario = EvalScenario(
      id: 'invalid_catalog',
      title: 'Invalid catalog',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 9, 9),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-present',
            title: 'Present task',
            status: 'OPEN',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Handle the missing task.',
        triggerTokens: {'decided_task:task-missing'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.catalog.validation'],
      ),
    );
    final trace = _trace(
      scenario: invalidScenario,
      profile: profile,
      output: _outputFor(profile),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [invalidScenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'scenario catalog validation failed: invalid_catalog: '
        'trigger token references unknown task task-missing',
      ),
    );
  });

  test('rejects tuning-readiness failures when policy is supplied', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      level1Checks: runLevel1(
        scenario,
        _outputFor(profile),
        profile: profile,
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      tuningPolicy: const EvalTuningPolicy(
        name: 'two-class-tuning',
        requiredModelClasses: {
          EvalModelClass.frontierFast,
          EvalModelClass.localSmall,
        },
        requireAllVerdicts: true,
      ),
    );

    expect(
      verification.errors,
      contains(
        'tuning readiness failed: model class localSmall profile count 0 < 1',
      ),
    );
  });

  test('rejects aggregate-only calibration for tuning readiness', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      level1Checks: runLevel1(
        scenario,
        _outputFor(profile),
        profile: profile,
      ),
      verdict: _verdict(),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      tuningPolicy: const EvalTuningPolicy(
        name: 'calibration-gated',
        requireCalibrationReport: true,
        minCalibrationEvaluatedCount: 1,
      ),
      calibrationReport: _calibrationReport(
        judgedTraceCount: 1,
        evaluatedCount: 1,
      ),
    );

    expect(
      verification.errors,
      contains(
        'tuning readiness failed: judge calibration set is required '
        'for readiness gates',
      ),
    );
  });

  test('rejects pass verdicts with low or out-of-range scores', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      level1Checks: runLevel1(
        scenario,
        _outputFor(profile),
        profile: profile,
      ),
      verdict: _verdict(
        goalAttainment: 1,
        quality: 6,
        efficiency: 3,
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 verdict quality '
        'is outside 1..5: 6',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict passes with a score below 3',
      ),
    );
  });

  test('rejects malformed judge provenance', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      verdict: _verdict(
        traceDigest: 'sha256:not-a-real-digest',
        judge: const JudgeProvenanceRecord(
          judgeName: '',
          judgeModel: '',
          promptDigest:
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          calibrationSetVersion: '',
          profileVisible: false,
          modelIdentityVisible: true,
        ),
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict traceDigest is not a sha256 digest',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict judge.judgeName is empty',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict judge.judgeModel is empty',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict judge.calibrationSetVersion is empty',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict judge.promptDigest is '
        'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb, '
        'expected '
        '${EvalProvenance.promptDigest()}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'verdict judge.profileVisible must be true for profile-aware '
        'efficiency grading',
      ),
    );
  });

  test('rejects mixed judge provenance in one verified run', () {
    const repeatedProfile = EvalProfile(
      name: 'mixed-judge-profile',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'verifier-model',
      tokenBudget: 10000,
      trialCount: 2,
    );
    final first = _trace(
      scenario: scenario,
      profile: repeatedProfile,
    );
    final second = _trace(
      scenario: scenario,
      profile: repeatedProfile,
      trialIndex: 1,
      verdict: _verdict(
        judge: JudgeProvenanceRecord(
          judgeName: 'claude-code',
          judgeModel: 'different-test-judge',
          promptDigest: EvalProvenance.promptDigest(),
          calibrationSetVersion: 'test-gold-v1',
          profileVisible: true,
          modelIdentityVisible: true,
        ),
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [first, second],
      scenarios: [scenario],
      profiles: const [repeatedProfile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::mixed-judge-profile::trial-1 '
        'verdict judge provenance differs from '
        'task_release_notes::mixed-judge-profile::trial-0',
      ),
    );
  });

  test('rejects traces without resolved model provenance', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(profile, includeResolvedModel: false),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing resolvedModel provenance',
      ),
    );
  });

  test('rejects traces without provider decision provenance', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(profile, includeProviderDecision: false),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing providerDecision provenance',
      ),
    );
  });

  test('rejects resolved model provenance that does not match profile', () {
    final expected = evalProfileConfig(profile);
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(
        profile,
        resolvedModel: ResolvedModelRecord(
          profileId: expected.profileId,
          modelConfigId: profile.modelId,
          providerModelId: 'legacy-template-model-must-not-win',
          providerId: expected.providerId,
          providerType: 'ollama',
          providerEndpointOrigin: expected.providerEndpointOrigin,
          providerBaseUrlDigest: expected.providerBaseUrlDigest,
          wakeRunResolvedModelId: 'legacy-version-model-must-not-win',
          usageModelId: 'legacy-version-model-must-not-win',
        ),
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.providerModelId is legacy-template-model-must-not-win, '
        'expected ${expected.providerModelId}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.providerType is ollama, expected gemini',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.wakeRunResolvedModelId is '
        'legacy-version-model-must-not-win, '
        'expected legacy-template-model-must-not-win',
      ),
    );
  });

  test('rejects provider decisions that select decoy or legacy rows', () {
    final expected = evalProfileConfig(profile);
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(
        profile,
        providerDecision: ProviderDecisionRecord(
          profileName: profile.name,
          modelClass: profile.modelClass,
          isLocal: profile.isLocal,
          profileId: expected.profileId,
          selectedModelConfigId: expected.decoyDuplicateProviderNativeModel.id,
          selectedProviderId: expected.decoyProvider.id,
          selectedProviderType: expected.providerType,
          selectedProviderModelId: expected.providerModelId,
          selectedProviderEndpointOrigin: expected.providerEndpointOrigin,
          selectedProviderBaseUrlDigest: expected.providerBaseUrlDigest,
          candidateModelConfigIds: [
            for (final row in expected.modelRows) row.id,
          ],
          decoyModelConfigIds: [
            expected.decoyDuplicateProviderNativeModel.id,
          ],
          legacyModelConfigIds: [
            expected.legacyVersionModel.id,
            expected.legacyTemplateModel.id,
          ],
          candidateProviderIds: [
            expected.provider.id,
            expected.decoyProvider.id,
            expected.legacyProvider.id,
          ],
          envPresence: const {'OPENAI_API_KEY': true},
        ),
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerDecision.selectedModelConfigId is '
        '${expected.decoyDuplicateProviderNativeModel.id}, '
        'expected ${expected.modelConfigId}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerDecision selected a decoy model row',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.modelConfigId is ${expected.modelConfigId}, '
        'expected ${expected.decoyDuplicateProviderNativeModel.id}',
      ),
    );
  });

  test('rejects model invocations outside the provider decision', () {
    final expected = evalProfileConfig(profile);
    final firstPrompt = _runtimePrompt('first');
    final finalPrompt = _runtimePrompt('final');
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(
        profile,
        runtimePrompt: finalPrompt,
        turnCount: 2,
        modelInvocations: [
          ModelInvocationRecord(
            invocationIndex: 0,
            providerModelId: 'legacy-template-model-must-not-win',
            providerId: expected.legacyProvider.id,
            providerType: expected.legacyProvider.inferenceProviderType.name,
            providerEndpointOrigin: expected.providerEndpointOrigin,
            providerBaseUrlDigest: expected.providerBaseUrlDigest,
            runtimePrompt: firstPrompt,
            toolNames: const ['update_report'],
          ),
          ModelInvocationRecord(
            invocationIndex: 1,
            providerModelId: expected.providerModelId,
            providerId: expected.providerId,
            providerType: expected.providerType,
            providerEndpointOrigin: expected.providerEndpointOrigin,
            providerBaseUrlDigest: expected.providerBaseUrlDigest,
            runtimePrompt: finalPrompt,
            toolNames: const ['update_report'],
          ),
        ],
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'modelInvocations[0] providerModelId is '
        'legacy-template-model-must-not-win, expected '
        '${expected.providerModelId}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'modelInvocations[0] providerId is ${expected.legacyProvider.id}, '
        'expected ${expected.providerId}',
      ),
    );
  });

  test('rejects missing or malformed model invocation provenance', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(
        profile,
        runtimePrompt: _runtimePrompt('final'),
        turnCount: 1,
      ),
    );
    final shiftedConfig = evalProfileConfig(profile);
    final shifted = _trace(
      scenario: taskWorkflowReleaseNotesScenario,
      profile: profile,
      output: _outputFor(
        profile,
        runtimePrompt: _runtimePrompt('final'),
        turnCount: 1,
        modelInvocations: [
          ModelInvocationRecord(
            invocationIndex: 3,
            providerModelId: shiftedConfig.providerModelId,
            providerId: shiftedConfig.providerId,
            providerType: shiftedConfig.providerType,
            providerEndpointOrigin: shiftedConfig.providerEndpointOrigin,
            providerBaseUrlDigest: shiftedConfig.providerBaseUrlDigest,
            runtimePrompt: _runtimePrompt('different-final'),
            toolNames: const ['update_report'],
            forcedToolName: 'set_task_status',
          ),
        ],
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace, shifted],
      scenarios: [scenario, taskWorkflowReleaseNotesScenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing model invocation provenance',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_workflow_release_notes::verifier-profile::trial-0 '
        'modelInvocations[0] invocationIndex is 3, expected 0',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_workflow_release_notes::verifier-profile::trial-0 '
        'modelInvocations[0] forcedToolName set_task_status is not in '
        'toolNames',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_workflow_release_notes::verifier-profile::trial-0 '
        'runtimePrompt does not match last model invocation',
      ),
    );
  });

  test('rejects missing provider request provenance for live traces', () {
    final prompt = _runtimePrompt('live');
    final output = _outputFor(
      profile,
      workflowRun: const WorkflowRunRecord(
        runKey: 'run-1::task_release_notes::verifier-profile::trial-0',
        threadId:
            'thread::run-1::task_release_notes::verifier-profile::trial-0',
      ),
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(profile, runtimePrompt: prompt),
      ],
      turnCount: 1,
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing provider request provenance for live trace',
      ),
    );
  });

  test('rejects missing provider requests for failed live invocations', () {
    final prompt = _runtimePrompt('failed-live');
    final output = _outputFor(
      profile,
      success: false,
      workflowRun: const WorkflowRunRecord(
        runKey: 'run-1::task_release_notes::verifier-profile::trial-0',
        threadId:
            'thread::run-1::task_release_notes::verifier-profile::trial-0',
      ),
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(profile, runtimePrompt: prompt),
      ],
      turnCount: 1,
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing provider request provenance for live trace',
      ),
    );
  });

  test(
    'rejects missing provider requests for live invocations without workflow '
    'run provenance',
    () {
      final prompt = _runtimePrompt('live-no-workflow');
      final output = _outputFor(
        profile,
        runtimePrompt: prompt,
        modelInvocations: [
          _modelInvocation(profile, runtimePrompt: prompt),
        ],
        turnCount: 1,
      );
      final manifest = _manifestFor(
        scenarios: [scenario],
        profiles: [profile],
        targetKind: 'live',
      );
      final trace = _trace(
        scenario: scenario,
        profile: profile,
        output: output,
        manifest: manifest,
      );

      final verification = _verify(
        runId: 'run-1',
        traces: [trace],
        scenarios: [scenario],
        profiles: [profile],
        manifest: manifest,
      );

      expect(
        verification.errors,
        contains(
          'task_release_notes::verifier-profile::trial-0 '
          'missing provider request provenance for live trace',
        ),
      );
    },
  );

  test('rejects missing provider response provenance for live traces', () {
    final prompt = _runtimePrompt('live-response-missing');
    final profileConfig = evalProfileConfig(profile);
    final request = ProviderRequestRecord(
      invocationIndex: 0,
      requestIndex: 0,
      turnIndex: 1,
      providerModelId: profileConfig.providerModelId,
      providerId: profileConfig.providerId,
      providerType: profileConfig.providerType,
      providerEndpointOrigin: profileConfig.providerEndpointOrigin,
      providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
      messageDigest: EvalProvenance.digestText('messages'),
      messageCount: 2,
      toolSchemaDigest: prompt.toolSchemaDigest!,
      toolCount: 1,
      toolNames: const ['update_report'],
      forcedToolName: 'update_report',
      temperature: profile.temperature,
      thoughtSignatureCount: 0,
    );
    final output = _outputFor(
      profile,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(profile, runtimePrompt: prompt),
      ],
      providerRequests: [request],
      providerResponses: const [],
      turnCount: 1,
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'missing provider response provenance for live trace',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerResponses '
        'missing response evidence for providerRequests[0]',
      ),
    );
  });

  test('rejects provider response model drift from live binding', () {
    const liveProviderModelId = 'gpt-5-mini-live-eval';
    final liveProfileConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: liveProviderModelId,
        providerId: 'live-openai-provider',
        apiKey: 'test-key',
      ),
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
      profileExecutionBindings: [liveProfileConfig.toExecutionBinding()],
    );
    final prompt = _runtimePrompt('live-response-drift');
    final request = ProviderRequestRecord(
      invocationIndex: 0,
      requestIndex: 0,
      turnIndex: 1,
      providerModelId: liveProfileConfig.providerModelId,
      providerId: liveProfileConfig.providerId,
      providerType: liveProfileConfig.providerType,
      providerEndpointOrigin: liveProfileConfig.providerEndpointOrigin,
      providerBaseUrlDigest: liveProfileConfig.providerBaseUrlDigest,
      messageDigest: EvalProvenance.digestText('messages'),
      messageCount: 2,
      toolSchemaDigest: prompt.toolSchemaDigest!,
      toolCount: 1,
      toolNames: const ['update_report'],
      forcedToolName: 'update_report',
      temperature: 1,
      thoughtSignatureCount: 0,
    );
    final output = _outputFor(
      profile,
      profileConfigOverride: liveProfileConfig,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(
          profile,
          runtimePrompt: prompt,
          profileConfigOverride: liveProfileConfig,
        ),
      ],
      providerRequests: [request],
      providerResponses: [
        _providerResponseFor(
          request,
          responseModelIds: const ['gpt-5-full-drift'],
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerResponses[0] responseModelId is gpt-5-full-drift, expected '
        'providerRequests[0].providerModelId $liveProviderModelId',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerResponses[0] responseModelId is gpt-5-full-drift, expected '
        'manifest binding $liveProviderModelId',
      ),
    );
  });

  test('ignores OpenAI-compatible keepalive response model sentinels', () {
    const liveProviderModelId = 'Qwen3.6-35B-A3B-4bit';
    final liveProfileConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: liveProviderModelId,
        providerId: 'live-openai-provider',
        apiKey: 'test-key',
      ),
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
      profileExecutionBindings: [liveProfileConfig.toExecutionBinding()],
    );
    final prompt = _runtimePrompt('live-response-keepalive');
    final request = ProviderRequestRecord(
      invocationIndex: 0,
      requestIndex: 0,
      turnIndex: 1,
      providerModelId: liveProfileConfig.providerModelId,
      providerId: liveProfileConfig.providerId,
      providerType: liveProfileConfig.providerType,
      providerEndpointOrigin: liveProfileConfig.providerEndpointOrigin,
      providerBaseUrlDigest: liveProfileConfig.providerBaseUrlDigest,
      messageDigest: EvalProvenance.digestText('messages'),
      messageCount: 2,
      toolSchemaDigest: prompt.toolSchemaDigest!,
      toolCount: 1,
      toolNames: const ['update_report'],
      forcedToolName: 'update_report',
      temperature: 1,
      thoughtSignatureCount: 0,
    );
    final output = _outputFor(
      profile,
      profileConfigOverride: liveProfileConfig,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(
          profile,
          runtimePrompt: prompt,
          profileConfigOverride: liveProfileConfig,
        ),
      ],
      providerRequests: [request],
      providerResponses: [
        _providerResponseFor(
          request,
          responseModelIds: const [liveProviderModelId, 'keepalive'],
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(verification.errors, isEmpty);
  });

  test('accepts explicit Gemini response model unavailable evidence', () {
    final profileConfig = evalProfileConfig(profile);
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
      profileExecutionBindings: [profileConfig.toExecutionBinding()],
    );
    final prompt = _runtimePrompt('gemini-response-unavailable');
    final request = ProviderRequestRecord(
      invocationIndex: 0,
      requestIndex: 0,
      turnIndex: 1,
      providerModelId: profileConfig.providerModelId,
      providerId: profileConfig.providerId,
      providerType: InferenceProviderType.gemini.name,
      providerEndpointOrigin: profileConfig.providerEndpointOrigin,
      providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
      messageDigest: EvalProvenance.digestText('messages'),
      messageCount: 2,
      toolSchemaDigest: prompt.toolSchemaDigest!,
      toolCount: 1,
      toolNames: const ['update_report'],
      forcedToolName: 'update_report',
      temperature: profile.temperature,
      thoughtSignatureCount: 0,
    );
    final output = _outputFor(
      profile,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(profile, runtimePrompt: prompt),
      ],
      providerRequests: [request],
      providerResponses: [
        _providerResponseFor(
          request,
          responseModelIds: const [],
          systemFingerprints: const [],
          responseModelUnavailableReason:
              'gemini_native_response_model_not_authoritative',
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(verification.errors, isEmpty);
  });

  test('rejects provider request evidence missing an invocation', () {
    final firstPrompt = _runtimePrompt('first-request');
    final finalPrompt = _runtimePrompt('final-request');
    final profileConfig = evalProfileConfig(profile);
    final output = _outputFor(
      profile,
      runtimePrompt: finalPrompt,
      modelInvocations: [
        _modelInvocation(
          profile,
          runtimePrompt: firstPrompt,
        ),
        _modelInvocation(
          profile,
          runtimePrompt: finalPrompt,
          invocationIndex: 1,
        ),
      ],
      providerRequests: [
        ProviderRequestRecord(
          invocationIndex: 1,
          requestIndex: 0,
          turnIndex: 1,
          providerModelId: profileConfig.providerModelId,
          providerId: profileConfig.providerId,
          providerType: profileConfig.providerType,
          providerEndpointOrigin: profileConfig.providerEndpointOrigin,
          providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
          messageDigest: EvalProvenance.digestText('messages'),
          messageCount: 2,
          toolSchemaDigest: finalPrompt.toolSchemaDigest!,
          toolCount: 1,
          toolNames: const ['update_report'],
          forcedToolName: 'update_report',
          temperature: profile.temperature,
          thoughtSignatureCount: 0,
        ),
      ],
      turnCount: 2,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests '
        'missing request evidence for model invocation 0',
      ),
    );
  });

  test('accepts manifest-bound live provider/model overrides', () {
    const liveProviderModelId = 'gpt-5-mini-live-eval';
    final liveProfileConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: liveProviderModelId,
        providerId: 'live-openai-provider',
        apiKey: 'test-key',
      ),
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
      profileExecutionBindings: [liveProfileConfig.toExecutionBinding()],
    );
    final prompt = _runtimePrompt('live-openai-binding');
    final output = _outputFor(
      profile,
      profileConfigOverride: liveProfileConfig,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(
          profile,
          runtimePrompt: prompt,
          profileConfigOverride: liveProfileConfig,
        ),
      ],
      providerRequests: [
        ProviderRequestRecord(
          invocationIndex: 0,
          requestIndex: 0,
          turnIndex: 1,
          providerModelId: liveProfileConfig.providerModelId,
          providerId: liveProfileConfig.providerId,
          providerType: liveProfileConfig.providerType,
          providerEndpointOrigin: liveProfileConfig.providerEndpointOrigin,
          providerBaseUrlDigest: liveProfileConfig.providerBaseUrlDigest,
          messageDigest: EvalProvenance.digestText('messages'),
          messageCount: 2,
          toolSchemaDigest: prompt.toolSchemaDigest!,
          toolCount: 1,
          toolNames: const ['update_report'],
          forcedToolName: 'update_report',
          temperature: 1,
          thoughtSignatureCount: 0,
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(verification.errors, isEmpty);
    expect(
      manifest.profileBindingSetDigest,
      EvalProvenance.profileBindingSetDigest(
        manifest.profileExecutionBindings,
      ),
    );
    expect(
      manifest.profileExecutionBindings.single.providerModelId,
      liveProviderModelId,
    );
  });

  test('rejects trace provider/model drift from manifest binding', () {
    final liveProfileConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: 'gpt-5-mini-live-eval',
        providerId: 'live-openai-provider',
        apiKey: 'test-key',
      ),
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
      profileExecutionBindings: [liveProfileConfig.toExecutionBinding()],
    );
    final driftConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: 'gpt-5-full-drift',
        providerId: 'drift-openai-provider',
        apiKey: 'test-key',
      ),
    );
    final prompt = _runtimePrompt('live-openai-drift');
    final output = _outputFor(
      profile,
      profileConfigOverride: driftConfig,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(
          profile,
          runtimePrompt: prompt,
          profileConfigOverride: driftConfig,
        ),
      ],
      providerRequests: [
        ProviderRequestRecord(
          invocationIndex: 0,
          requestIndex: 0,
          turnIndex: 1,
          providerModelId: driftConfig.providerModelId,
          providerId: driftConfig.providerId,
          providerType: driftConfig.providerType,
          providerEndpointOrigin: driftConfig.providerEndpointOrigin,
          providerBaseUrlDigest: driftConfig.providerBaseUrlDigest,
          messageDigest: EvalProvenance.digestText('messages'),
          messageCount: 2,
          toolSchemaDigest: prompt.toolSchemaDigest!,
          toolCount: 1,
          toolNames: const ['update_report'],
          forcedToolName: 'update_report',
          temperature: 1,
          thoughtSignatureCount: 0,
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.providerModelId is gpt-5-full-drift, expected '
        'gpt-5-mini-live-eval',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerDecision.selectedProviderModelId is gpt-5-full-drift, '
        'expected gpt-5-mini-live-eval',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 modelInvocations[0] '
        'providerModelId is gpt-5-full-drift, expected manifest binding '
        'gpt-5-mini-live-eval',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'providerModelId is gpt-5-full-drift, expected manifest binding '
        'gpt-5-mini-live-eval',
      ),
    );
  });

  test('rejects endpoint drift from manifest binding', () {
    const providerModelId = 'gpt-5-mini-live-eval';
    const providerId = 'live-openai-provider';
    final liveProfileConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: providerModelId,
        providerId: providerId,
        apiKey: 'test-key',
      ),
    );
    final manifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
      targetKind: 'live',
      profileExecutionBindings: [liveProfileConfig.toExecutionBinding()],
    );
    final proxyProfileConfig = evalProfileConfig(
      profile,
      providerOverride: const EvalProfileProviderOverride(
        providerType: InferenceProviderType.openAi,
        providerModelId: providerModelId,
        providerId: providerId,
        apiKey: 'test-key',
        baseUrl: 'https://proxy.invalid/openai/v1',
      ),
    );
    final prompt = _runtimePrompt('live-endpoint-drift');
    final output = _outputFor(
      profile,
      profileConfigOverride: proxyProfileConfig,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(
          profile,
          runtimePrompt: prompt,
          profileConfigOverride: proxyProfileConfig,
        ),
      ],
      providerRequests: [
        ProviderRequestRecord(
          invocationIndex: 0,
          requestIndex: 0,
          turnIndex: 1,
          providerModelId: proxyProfileConfig.providerModelId,
          providerId: proxyProfileConfig.providerId,
          providerType: proxyProfileConfig.providerType,
          providerEndpointOrigin: proxyProfileConfig.providerEndpointOrigin,
          providerBaseUrlDigest: proxyProfileConfig.providerBaseUrlDigest,
          messageDigest: EvalProvenance.digestText('messages'),
          messageCount: 2,
          toolSchemaDigest: prompt.toolSchemaDigest!,
          toolCount: 1,
          toolNames: const ['update_report'],
          forcedToolName: 'update_report',
          temperature: 1,
          thoughtSignatureCount: 0,
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.providerEndpointOrigin is '
        'https://proxy.invalid, expected '
        '${liveProfileConfig.providerEndpointOrigin}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'modelInvocations[0] providerBaseUrlDigest is '
        '${proxyProfileConfig.providerBaseUrlDigest}, expected manifest '
        'binding ${liveProfileConfig.providerBaseUrlDigest}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerRequests[0] providerBaseUrlDigest is '
        '${proxyProfileConfig.providerBaseUrlDigest}, expected manifest '
        'binding ${liveProfileConfig.providerBaseUrlDigest}',
      ),
    );
  });

  test('rejects mutated manifest profile binding evidence', () {
    final validManifest = _manifestFor(
      scenarios: [scenario],
      profiles: [profile],
    );
    final badDigestManifest = _manifestFromJson({
      ...validManifest.toJson(includeManifestDigest: false),
      'profileBindingSetDigest': EvalProvenance.digestText('wrong-bindings'),
    });
    final missingBindingManifest = _manifestFromJson({
      ...validManifest.toJson(includeManifestDigest: false),
      'profileExecutionBindings': <Map<String, dynamic>>[],
      'profileBindingSetDigest': EvalProvenance.profileBindingSetDigest(
        const [],
      ),
    });
    final binding = validManifest.profileExecutionBindings.single.toJson();
    final duplicateManifest = _manifestFromJson({
      ...validManifest.toJson(includeManifestDigest: false),
      'profileExecutionBindings': [binding, binding],
      'profileBindingSetDigest': EvalProvenance.profileBindingSetDigest([
        validManifest.profileExecutionBindings.single,
        validManifest.profileExecutionBindings.single,
      ]),
    });

    final badDigestVerification = _verify(
      runId: 'run-1',
      traces: [
        _trace(
          scenario: scenario,
          profile: profile,
          manifest: badDigestManifest,
        ),
      ],
      scenarios: [scenario],
      profiles: [profile],
      manifest: badDigestManifest,
    );
    final missingVerification = _verify(
      runId: 'run-1',
      traces: [
        _trace(
          scenario: scenario,
          profile: profile,
          manifest: missingBindingManifest,
        ),
      ],
      scenarios: [scenario],
      profiles: [profile],
      manifest: missingBindingManifest,
    );
    final duplicateVerification = _verify(
      runId: 'run-1',
      traces: [
        _trace(
          scenario: scenario,
          profile: profile,
          manifest: duplicateManifest,
        ),
      ],
      scenarios: [scenario],
      profiles: [profile],
      manifest: duplicateManifest,
    );

    expect(
      badDigestVerification.errors,
      contains(
        'manifest profileBindingSetDigest is '
        '${EvalProvenance.digestText('wrong-bindings')}, expected '
        '${EvalProvenance.profileBindingSetDigest(
          validManifest.profileExecutionBindings,
        )}',
      ),
    );
    expect(
      missingVerification.errors,
      contains('manifest profileExecutionBindings are missing'),
    );
    expect(
      missingVerification.errors,
      contains('missing manifest profileExecutionBinding for ${profile.name}'),
    );
    expect(
      duplicateVerification.errors,
      contains(
        'duplicate manifest profileExecutionBinding for ${profile.name}',
      ),
    );
  });

  test('rejects provider requests that do not match their invocation', () {
    final prompt = _runtimePrompt('request-match');
    final profileConfig = evalProfileConfig(profile);
    final output = _outputFor(
      profile,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(profile, runtimePrompt: prompt),
      ],
      providerRequests: [
        ProviderRequestRecord(
          invocationIndex: 0,
          requestIndex: 0,
          turnIndex: 1,
          providerModelId: 'forged-provider-model',
          providerId: 'forged-provider',
          providerType: 'legacy',
          providerEndpointOrigin: 'https://forged.invalid',
          providerBaseUrlDigest: EvalProvenance.digestText('forged-endpoint'),
          messageDigest: EvalProvenance.digestText('messages'),
          messageCount: 2,
          toolSchemaDigest: EvalProvenance.digestJson(['forged-tool']),
          toolCount: 1,
          toolNames: const ['set_task_status'],
          forcedToolName: 'set_task_status',
          temperature: profile.temperature,
          thoughtSignatureCount: 0,
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'providerModelId is forged-provider-model, expected '
        'modelInvocations[0].providerModelId ${profileConfig.providerModelId}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'providerId is forged-provider, expected '
        'modelInvocations[0].providerId ${profileConfig.providerId}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'providerType is legacy, expected '
        'modelInvocations[0].providerType ${profileConfig.providerType}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'toolSchemaDigest is ${EvalProvenance.digestJson(['forged-tool'])}, '
        'expected modelInvocations[0].runtimePrompt.toolSchemaDigest '
        '${prompt.toolSchemaDigest}',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'toolNames are [set_task_status], expected '
        'modelInvocations[0].toolNames [update_report]',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'forcedToolName is set_task_status, expected '
        'modelInvocations[0].forcedToolName update_report',
      ),
    );
  });

  test(
    'rejects provider request temperature drift for non-OpenAI providers',
    () {
      final prompt = _runtimePrompt('gemini-temperature');
      final profileConfig = evalProfileConfig(profile);
      final output = _outputFor(
        profile,
        runtimePrompt: prompt,
        modelInvocations: [
          _modelInvocation(profile, runtimePrompt: prompt),
        ],
        providerRequests: [
          ProviderRequestRecord(
            invocationIndex: 0,
            requestIndex: 0,
            turnIndex: 1,
            providerModelId: profileConfig.providerModelId,
            providerId: profileConfig.providerId,
            providerType: profileConfig.providerType,
            providerEndpointOrigin: profileConfig.providerEndpointOrigin,
            providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
            messageDigest: EvalProvenance.digestText('messages'),
            messageCount: 2,
            toolSchemaDigest: prompt.toolSchemaDigest!,
            toolCount: 1,
            toolNames: const ['update_report'],
            forcedToolName: 'update_report',
            temperature: 1,
            thoughtSignatureCount: 0,
          ),
        ],
        turnCount: 1,
      );
      final trace = _trace(
        scenario: scenario,
        profile: profile,
        output: output,
      );

      final verification = _verify(
        runId: 'run-1',
        traces: [trace],
        scenarios: [scenario],
        profiles: [profile],
      );

      expect(
        verification.errors,
        contains(
          'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
          'temperature is 1.0, expected ${profile.temperature} for providerType '
          '${profileConfig.providerType}',
        ),
      );
    },
  );

  test(
    'rejects OpenAI provider request temperature drift from forced default',
    () {
      const openAiProfile = EvalProfile(
        name: 'openai-verifier-profile',
        isLocal: false,
        modelClass: EvalModelClass.frontierFast,
        modelId: 'openai-verifier-model',
        temperature: 0.2,
        tokenBudget: 10000,
      );
      final prompt = _runtimePrompt('openai-temperature');
      final profileConfig = evalProfileConfig(
        openAiProfile,
        providerOverride: const EvalProfileProviderOverride(
          providerType: InferenceProviderType.openAi,
          providerModelId: 'gpt-5-mini-temperature',
          providerId: 'openai-temperature-provider',
          apiKey: 'test-key',
        ),
      );
      final manifest = _manifestFor(
        scenarios: [scenario],
        profiles: const [openAiProfile],
        targetKind: 'live',
        profileExecutionBindings: [profileConfig.toExecutionBinding()],
      );
      final output = _outputFor(
        openAiProfile,
        profileConfigOverride: profileConfig,
        runtimePrompt: prompt,
        modelInvocations: [
          ModelInvocationRecord(
            invocationIndex: 0,
            providerModelId: profileConfig.providerModelId,
            providerId: profileConfig.providerId,
            providerType: InferenceProviderType.openAi.name,
            providerEndpointOrigin: profileConfig.providerEndpointOrigin,
            providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
            runtimePrompt: prompt,
            toolNames: const ['update_report'],
            forcedToolName: 'update_report',
          ),
        ],
        providerRequests: [
          ProviderRequestRecord(
            invocationIndex: 0,
            requestIndex: 0,
            turnIndex: 1,
            providerModelId: profileConfig.providerModelId,
            providerId: profileConfig.providerId,
            providerType: InferenceProviderType.openAi.name,
            providerEndpointOrigin: profileConfig.providerEndpointOrigin,
            providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
            messageDigest: EvalProvenance.digestText('messages'),
            messageCount: 2,
            toolSchemaDigest: prompt.toolSchemaDigest!,
            toolCount: 1,
            toolNames: const ['update_report'],
            forcedToolName: 'update_report',
            temperature: openAiProfile.temperature,
            thoughtSignatureCount: 0,
          ),
        ],
        turnCount: 1,
      );
      final trace = _trace(
        scenario: scenario,
        profile: openAiProfile,
        output: output,
        manifest: manifest,
      );

      final verification = _verify(
        runId: 'run-1',
        traces: [trace],
        scenarios: [scenario],
        profiles: const [openAiProfile],
        manifest: manifest,
      );

      expect(
        verification.errors,
        contains(
          'task_release_notes::openai-verifier-profile::trial-0 '
          'providerRequests[0] temperature is 0.2, expected 1.0 for '
          'providerType openAi',
        ),
      );
    },
  );

  test('rejects unknown provider type strings before temperature policy', () {
    final prompt = _runtimePrompt('unknown-provider-type');
    final profileConfig = evalProfileConfig(profile);
    final resolvedModel = ResolvedModelRecord(
      profileId: profileConfig.profileId,
      modelConfigId: profileConfig.modelConfigId,
      providerModelId: profileConfig.providerModelId,
      providerId: profileConfig.providerId,
      providerType: 'openai',
      providerEndpointOrigin: profileConfig.providerEndpointOrigin,
      providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
    );
    final providerDecision = ProviderDecisionRecord(
      profileName: profile.name,
      modelClass: profile.modelClass,
      isLocal: profile.isLocal,
      profileId: profileConfig.profileId,
      selectedModelConfigId: profileConfig.modelConfigId,
      selectedProviderId: profileConfig.providerId,
      selectedProviderType: 'openai',
      selectedProviderModelId: profileConfig.providerModelId,
      selectedProviderEndpointOrigin: profileConfig.providerEndpointOrigin,
      selectedProviderBaseUrlDigest: profileConfig.providerBaseUrlDigest,
      candidateModelConfigIds: [
        for (final row in profileConfig.modelRows) row.id,
      ],
      decoyModelConfigIds: [
        profileConfig.decoyDuplicateProviderNativeModel.id,
      ],
      legacyModelConfigIds: [
        profileConfig.legacyVersionModel.id,
        profileConfig.legacyTemplateModel.id,
      ],
      candidateProviderIds: [
        profileConfig.provider.id,
        profileConfig.decoyProvider.id,
        profileConfig.legacyProvider.id,
      ],
    );
    final output = _outputFor(
      profile,
      resolvedModel: resolvedModel,
      providerDecision: providerDecision,
      runtimePrompt: prompt,
      modelInvocations: [
        ModelInvocationRecord(
          invocationIndex: 0,
          providerModelId: profileConfig.providerModelId,
          providerId: profileConfig.providerId,
          providerType: 'openai',
          providerEndpointOrigin: profileConfig.providerEndpointOrigin,
          providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
          runtimePrompt: prompt,
          toolNames: const ['update_report'],
          forcedToolName: 'update_report',
        ),
      ],
      providerRequests: [
        ProviderRequestRecord(
          invocationIndex: 0,
          requestIndex: 0,
          turnIndex: 1,
          providerModelId: profileConfig.providerModelId,
          providerId: profileConfig.providerId,
          providerType: 'openai',
          providerEndpointOrigin: profileConfig.providerEndpointOrigin,
          providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
          messageDigest: EvalProvenance.digestText('messages'),
          messageCount: 2,
          toolSchemaDigest: prompt.toolSchemaDigest!,
          toolCount: 1,
          toolNames: const ['update_report'],
          forcedToolName: 'update_report',
          temperature: profile.temperature,
          thoughtSignatureCount: 0,
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'resolvedModel.providerType is unknown: openai',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'modelInvocations[0] providerType is unknown: openai',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerRequests[0] providerType is unknown: openai',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'providerDecision.selectedProviderType is unknown: openai',
      ),
    );
  });

  test('rejects malformed provider request provenance', () {
    final prompt = _runtimePrompt('request');
    final output = _outputFor(
      profile,
      runtimePrompt: prompt,
      modelInvocations: [
        _modelInvocation(profile, runtimePrompt: prompt),
      ],
      providerRequests: const [
        ProviderRequestRecord(
          invocationIndex: 4,
          requestIndex: 3,
          turnIndex: -1,
          providerModelId: 'unexpected-provider-model',
          providerId: 'unexpected-provider',
          providerType: 'legacy',
          messageDigest: 'sha256:not-a-real-digest',
          messageCount: 0,
          toolSchemaDigest: 'not-a-digest',
          toolCount: 2,
          toolNames: ['update_report'],
          forcedToolName: 'set_task_status',
          temperature: 0.7,
          thoughtSignatureCount: -1,
        ),
      ],
      turnCount: 1,
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: output,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'invocationIndex 4 has no matching model invocation',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests '
        'invocation 4 requestIndex 3 expected 0',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'turnIndex must not be negative',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'messageDigest is not a sha256 digest',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'toolSchemaDigest is not a sha256 digest',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'messageCount must be positive',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'toolCount 2 does not match toolNames length 1',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'forcedToolName set_task_status is not in toolNames',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'thoughtSignatureCount must not be negative',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 providerRequests[0] '
        'providerModelId is unexpected-provider-model, expected '
        '${evalProfileConfig(profile).providerModelId}',
      ),
    );
  });

  test('rejects workflow run ids not bound to the matrix cell', () {
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(
        profile,
        workflowRun: const WorkflowRunRecord(
          runKey: 'eval-run',
          threadId: 'eval-thread',
        ),
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'workflow runKey is not bound to matrix cell '
        'run-1::task_release_notes::verifier-profile::0',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'workflow threadId is not bound to matrix cell '
        'run-1::task_release_notes::verifier-profile::0',
      ),
    );
  });

  test('accepts explicit matrix cell binding for shared workflow runs', () {
    final runtimePrompt = _runtimePrompt('shared-workflow');
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      output: _outputFor(
        profile,
        workflowRun: const WorkflowRunRecord(
          runKey: 'eval-run:shared-cascade:wake-1',
          threadId: 'eval-thread:shared-cascade',
          matrixCellId: 'run-1::task_release_notes::verifier-profile::0',
        ),
        runtimePrompt: runtimePrompt,
        modelInvocations: [
          _modelInvocation(profile, runtimePrompt: runtimePrompt),
        ],
        turnCount: 1,
      ),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(verification.errors, isEmpty);
  });

  test('rejects trace-embedded scenario and profile payload drift', () {
    final output = _outputFor(profile);
    final tamperedScenario = EvalScenario(
      id: scenario.id,
      title: '${scenario.title} (tampered)',
      agentKind: scenario.agentKind,
      appState: MockedAppState(
        now: scenario.appState.now,
        tasks: scenario.appState.tasks,
        capacityMinutes: 1,
        categoryIds: scenario.appState.categoryIds,
      ),
      userInput: scenario.userInput,
      metadata: scenario.metadata,
      expectations: scenario.expectations,
    );
    const tamperedProfile = EvalProfile(
      name: 'verifier-profile',
      isLocal: true,
      modelClass: EvalModelClass.localSmall,
      modelId: 'local-profile-that-must-not-win',
      tokenBudget: 999999,
    );
    final trace = _trace(
      scenario: tamperedScenario,
      profile: tamperedProfile,
      output: output,
      level1Checks: runLevel1(scenario, output, profile: profile),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'scenario payload differs from catalog',
      ),
    );
    expect(
      verification.errors,
      contains(
        'task_release_notes::verifier-profile::trial-0 '
        'profile payload differs from configured profile',
      ),
    );
    expect(
      verification.errors,
      isNot(
        contains(
          'task_release_notes::verifier-profile::trial-0 '
          'resolvedModel.providerType is gemini, expected ollama',
        ),
      ),
      reason: 'resolvedModel must be checked against the canonical profile',
    );
    expect(
      verification.errors.any(
        (error) => error.contains('provenance.scenarioDigest'),
      ),
      isTrue,
    );
    expect(
      verification.errors.any(
        (error) => error.contains('provenance.profileDigest'),
      ),
      isTrue,
    );
  });

  test('rejects missing or stale run manifests', () {
    final manifest = _manifestFor(scenarios: [scenario], profiles: [profile]);
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      manifest: manifest,
    );

    final missing = EvalRunVerifier.verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
    );

    expect(missing.errors, contains('missing run manifest'));

    final staleManifest = manifest.withManifestDigest(
      'sha256:1111111111111111111111111111111111111111111111111111111111111111',
    );
    final stale = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: staleManifest,
    );

    expect(
      stale.errors.any((error) => error.startsWith('manifestDigest is ')),
      isTrue,
    );
    expect(
      stale.errors.any(
        (error) => error.contains('provenance.manifestDigest'),
      ),
      isTrue,
    );
  });

  test('rejects manifest scenario and profile set drift', () {
    final manifest = _manifestFor(scenarios: [scenario], profiles: [profile]);
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      manifest: manifest,
    );
    final alteredScenario = EvalScenario(
      id: scenario.id,
      title: scenario.title,
      agentKind: scenario.agentKind,
      appState: scenario.appState,
      userInput: scenario.userInput,
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.grooming.changed'],
      ),
      expectations: scenario.expectations,
    );
    const alteredProfile = EvalProfile(
      name: 'verifier-profile',
      isLocal: false,
      modelClass: EvalModelClass.frontierFast,
      modelId: 'verifier-model',
      tokenBudget: 20000,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [alteredScenario],
      profiles: const [alteredProfile],
      manifest: manifest,
    );

    expect(
      verification.errors.any(
        (error) => error.startsWith('manifest scenarioSetDigest is '),
      ),
      isTrue,
    );
    expect(
      verification.errors.any(
        (error) => error.startsWith('manifest profileSetDigest is '),
      ),
      isTrue,
    );
  });

  test('explains external-catalog manifest drift', () {
    final privateScenario = _scenarioWithId('private_task_holdout');
    final runScenarios = [scenario, privateScenario];
    final manifest = _manifestFor(
      scenarios: runScenarios,
      profiles: [profile],
      scenarioCatalogEvidence: _protectedEvidence(
        scenarios: runScenarios,
        protectedHoldoutScenarioIds: [privateScenario.id],
      ),
    );
    final trace = _trace(
      scenario: scenario,
      profile: profile,
      manifest: manifest,
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [scenario],
      profiles: [profile],
      manifest: manifest,
    );

    expect(
      verification.errors,
      contains(
        'run was created with an external scenario catalog; set '
        'EVAL_SCENARIOS to the same catalog before verify/report',
      ),
    );
  });

  test('rejects weak scenario governance metadata', () {
    final weakScenario = EvalScenario(
      id: 'weak_scenario',
      title: 'Weak governance scenario',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 9, 9),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-weak',
            title: 'Weak task',
            status: 'OPEN',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Handle weak task.',
        triggerTokens: {'decided_task:task-weak'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['bad_capability'],
        isAdversarial: true,
      ),
    );
    final trace = _trace(
      scenario: weakScenario,
      profile: profile,
      output: _outputFor(profile),
    );

    final verification = _verify(
      runId: 'run-1',
      traces: [trace],
      scenarios: [weakScenario],
      profiles: [profile],
    );

    expect(
      verification.errors,
      contains(
        'weak_scenario::verifier-profile::trial-0 '
        'scenario metadata has invalid capability bad_capability',
      ),
    );
    expect(
      verification.errors,
      contains(
        'weak_scenario::verifier-profile::trial-0 '
        'adversarial scenario must use adversarial source or tag',
      ),
    );
    expect(
      verification.errors,
      contains(
        'weak_scenario::verifier-profile::trial-0 adversarial scenario must '
        'use at least one default stress tag: '
        '${kDefaultAdversarialStressTags.join(', ')}',
      ),
    );
  });
}

EvalRunVerification _verify({
  required String runId,
  required List<EvalTrace> traces,
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  EvalRunManifest? manifest,
  Iterable<String> artifactNames = const <String>[],
  bool requireVerdicts = true,
  EvalTuningPolicy? tuningPolicy,
  JudgeCalibrationSet? calibrationSet,
  JudgeCalibrationReport? calibrationReport,
}) {
  return EvalRunVerifier.verify(
    runId: runId,
    traces: traces,
    scenarios: scenarios,
    profiles: profiles,
    manifest:
        manifest ??
        _manifestFor(runId: runId, scenarios: scenarios, profiles: profiles),
    artifactNames: artifactNames,
    requireVerdicts: requireVerdicts,
    tuningPolicy: tuningPolicy,
    calibrationSet: calibrationSet,
    calibrationReport: calibrationReport,
  );
}

EvalRunManifest _manifestFor({
  required List<EvalScenario> scenarios,
  required List<EvalProfile> profiles,
  String runId = 'run-1',
  String targetKind = 'test',
  EvalScenarioCatalogEvidence? scenarioCatalogEvidence,
  List<EvalProfileExecutionBinding>? profileExecutionBindings,
}) {
  return EvalProvenance.captureRunManifest(
    runId: runId,
    targetName: 'verifier-test',
    targetKind: targetKind,
    scenarios: scenarios,
    profiles: profiles,
    scenarioCatalogEvidence: scenarioCatalogEvidence,
    createdAt: DateTime(2026, 6, 10, 12),
    command: 'verifier-test',
    environment: const <String, String>{},
    profileExecutionBindings: profileExecutionBindings,
  );
}

EvalRunManifest _manifestFromJson(Map<String, dynamic> json) {
  final manifest = EvalRunManifest.fromJson(json);
  return manifest.withManifestDigest(EvalProvenance.manifestDigest(manifest));
}

EvalScenario _scenarioWithId(String id) {
  final json = taskReleaseNotesScenario.toJson();
  json['id'] = id;
  json['metadata'] = <String, dynamic>{
    ...(json['metadata'] as Map<String, dynamic>),
    'split': EvalScenarioSplit.holdout.name,
    'source': EvalScenarioSource.productionReplay.name,
    'capabilityIds': ['task.private.holdout'],
  };
  return EvalScenario.fromJson(json);
}

EvalScenarioCatalogEvidence _protectedEvidence({
  required List<EvalScenario> scenarios,
  required List<String> protectedHoldoutScenarioIds,
}) {
  return EvalScenarioCatalogEvidence(
    scenarioSetDigest: EvalProvenance.scenarioSetDigest(scenarios),
    publicScenarioCount: scenarios.length - protectedHoldoutScenarioIds.length,
    externalScenarioCount: protectedHoldoutScenarioIds.length,
    externalCatalogDigest: EvalProvenance.digestText('private-catalog'),
    externalCatalogId: 'private-production-replay-v1',
    externalSourceLabel: 'protected_scenarios.json',
    protectedHoldout: true,
    protectedScenarioIds: protectedHoldoutScenarioIds,
    protectedHoldoutScenarioIds: protectedHoldoutScenarioIds,
  );
}

AgentRunOutput _outputFor(
  EvalProfile profile, {
  ResolvedModelRecord? resolvedModel,
  ProviderDecisionRecord? providerDecision,
  WorkflowRunRecord? workflowRun,
  RuntimePromptRecord? runtimePrompt,
  List<ModelInvocationRecord> modelInvocations = const [],
  List<ProviderRequestRecord> providerRequests = const [],
  List<ProviderResponseRecord>? providerResponses,
  EvalProfileConfig? profileConfigOverride,
  bool includeResolvedModel = true,
  bool includeProviderDecision = true,
  bool success = true,
  int turnCount = 0,
}) {
  final profileConfig = profileConfigOverride ?? evalProfileConfig(profile);
  return AgentRunOutput(
    success: success,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 40),
    report: const AgentReportRecord(
      oneLiner: 'Release notes groomed',
      tldr: 'Estimate and next steps are clear.',
      content: '## Done\nThe release-notes task is ready.',
    ),
    resolvedModel: includeResolvedModel
        ? resolvedModel ??
              profileConfig.toResolvedModelRecord(
                wakeRunResolvedModelId: profileConfig.providerModelId,
                usageModelId: profileConfig.providerModelId,
              )
        : null,
    providerDecision: includeProviderDecision
        ? providerDecision ??
              profileConfig.toProviderDecisionRecord(
                envPresence: const {'OPENAI_API_KEY': true},
              )
        : null,
    workflowRun: workflowRun,
    runtimePrompt: runtimePrompt,
    modelInvocations: modelInvocations,
    providerRequests: providerRequests,
    providerResponses:
        providerResponses ??
        providerRequests.map(_providerResponseFor).toList(),
    turnCount: turnCount,
  );
}

ProviderResponseRecord _providerResponseFor(
  ProviderRequestRecord request, {
  List<String>? responseModelIds,
  List<String> systemFingerprints = const ['fp-eval'],
  String? responseModelUnavailableReason,
}) {
  return ProviderResponseRecord(
    invocationIndex: request.invocationIndex,
    requestIndex: request.requestIndex,
    turnIndex: request.turnIndex,
    providerType: request.providerType,
    chunkCount: 1,
    responseModelIds: responseModelIds ?? [request.providerModelId],
    systemFingerprints: systemFingerprints,
    responseModelUnavailableReason: responseModelUnavailableReason,
  );
}

ModelInvocationRecord _modelInvocation(
  EvalProfile profile, {
  required RuntimePromptRecord runtimePrompt,
  int invocationIndex = 0,
  EvalProfileConfig? profileConfigOverride,
}) {
  final profileConfig = profileConfigOverride ?? evalProfileConfig(profile);
  return ModelInvocationRecord(
    invocationIndex: invocationIndex,
    providerModelId: profileConfig.providerModelId,
    providerId: profileConfig.provider.id,
    providerType: profileConfig.provider.inferenceProviderType.name,
    providerEndpointOrigin: profileConfig.providerEndpointOrigin,
    providerBaseUrlDigest: profileConfig.providerBaseUrlDigest,
    runtimePrompt: runtimePrompt,
    toolNames: const ['update_report'],
    forcedToolName: 'update_report',
  );
}

RuntimePromptRecord _runtimePrompt(String label) => RuntimePromptRecord(
  systemDigest: EvalProvenance.digestText('system-$label'),
  userDigest: EvalProvenance.digestText('user-$label'),
  toolSchemaDigest: EvalProvenance.digestJson(['tool-$label']),
  toolCount: 1,
);

EvalTrace _trace({
  required EvalScenario scenario,
  required EvalProfile profile,
  String runId = 'run-1',
  int trialIndex = 0,
  AgentRunOutput? output,
  List<EvalCheck>? level1Checks,
  EvalRunManifest? manifest,
  JudgeVerdict? verdict,
}) {
  final traceOutput = output ?? _outputFor(profile);
  final traceManifest =
      manifest ??
      _manifestFor(runId: runId, scenarios: [scenario], profiles: [profile]);
  final provenance = EvalProvenance.capture(
    scenario: scenario,
    profile: profile,
    manifestDigest: traceManifest.manifestDigest!,
  );
  return EvalTrace(
    runId: runId,
    scenario: scenario,
    profile: profile,
    provenance: provenance,
    trialIndex: trialIndex,
    output: traceOutput,
    level1Checks:
        level1Checks ?? runLevel1(scenario, traceOutput, profile: profile),
    verdict: verdict ?? _verdict(judgePromptDigest: provenance.promptDigest),
  );
}

JudgeVerdict _verdict({
  String traceDigest =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  int goalAttainment = 5,
  int quality = 5,
  int efficiency = 4,
  bool pass = true,
  String? judgePromptDigest,
  JudgeProvenanceRecord? judge,
}) => JudgeVerdict(
  traceDigest: traceDigest,
  goalAttainment: goalAttainment,
  quality: quality,
  efficiency: efficiency,
  pass: pass,
  judge:
      judge ??
      JudgeProvenanceRecord(
        judgeName: 'claude-code',
        judgeModel: 'test-judge',
        promptDigest: judgePromptDigest ?? EvalProvenance.promptDigest(),
        calibrationSetVersion: 'test-gold-v1',
        profileVisible: true,
        modelIdentityVisible: true,
      ),
);

JudgeCalibrationReport _calibrationReport({
  required int judgedTraceCount,
  required int evaluatedCount,
}) {
  return JudgeCalibrationReport(
    calibrationSetVersion: 'human-gold-v1',
    judgeCalibrationSetVersion: 'test-gold-v1',
    labelCount: evaluatedCount,
    judgedTraceCount: judgedTraceCount,
    evaluatedCount: evaluatedCount,
    staleLabelCount: 0,
    missingTraceCount: 0,
    missingVerdictCount: 0,
    unlabeledVerdictCount: judgedTraceCount - evaluatedCount,
    falsePassCount: 0,
    falseFailCount: 0,
    unblindedVerdictCount: 0,
    judgeCalibrationMismatchCount: 0,
    passAgreementCount: evaluatedCount,
    scoreAgreementCount: evaluatedCount,
    capabilitySummaries: const [],
    modelClassSummaries: const [],
    findings: const [],
  );
}
