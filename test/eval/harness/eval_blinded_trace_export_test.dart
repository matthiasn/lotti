import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../harness/eval_harness.dart';
import '../scenarios/eval_scenarios.dart';

void main() {
  test(
    'writes anonymous judge packet plus private trace mapping key',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'lotti-blinded-export-',
      );
      addTearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });

      final writer = TraceWriter(runsRoot: '${dir.path}/runs');
      final manifest = _manifest();
      await writer.writeManifest(manifest);
      final rawTraceFile = await writer.writeTrace(
        _trace(manifestDigest: manifest.manifestDigest!),
      );
      final run = await writer.readRun('blind-run');

      final result = await EvalBlindedTraceExporter.writeRun(
        run: run,
        writer: writer,
        outputDir: Directory('${dir.path}/blind'),
        exportSeed: 'test-seed',
      );

      final rawTraceDigest = await writer.traceDigest(rawTraceFile);
      final judgeManifest =
          jsonDecode(
                await result.judgeManifestFile.readAsString(),
              )
              as Map<String, dynamic>;
      final blindedTrace =
          jsonDecode(
                await result.blindedTraceFiles.single.readAsString(),
              )
              as Map<String, dynamic>;
      final privateKey =
          jsonDecode(
                await result.privateKeyFile.readAsString(),
              )
              as Map<String, dynamic>;
      final judgePayload = jsonEncode({
        'manifest': judgeManifest,
        'trace': blindedTrace,
      });
      final privatePayload = jsonEncode(privateKey);

      expect(result.judgeDir.path, endsWith('/blind/judge'));
      expect(result.privateDir.path, endsWith('/blind/private'));
      expect(judgeManifest['modelIdentityVisible'], isFalse);
      expect(judgeManifest['profileVisible'], isTrue);
      expect(judgeManifest['sourceRunId'], isNull);
      expect(judgeManifest['sourceRunDigest'], startsWith('sha256:'));
      expect(judgeManifest['traceCount'], 1);
      expect(blindedTrace, isNot(contains('rawTraceDigest')));
      expect(judgePayload, isNot(contains(rawTraceDigest)));
      expect(blindedTrace['blindedTraceDigest'], startsWith('sha256:'));
      expect(
        blindedTrace['verdictContract'],
        containsPair('blindedTraceDigest', blindedTrace['blindedTraceDigest']),
      );
      expect(
        (blindedTrace['profileContext'] as Map<String, dynamic>)['modelClass'],
        EvalModelClass.frontierFast.name,
      );
      expect(
        (blindedTrace['profileContext']
            as Map<String, dynamic>)['profileAlias'],
        'profile-01',
      );
      expect(blindedTrace['promptVariantAlias'], 'prompt-variant-01');
      expect(
        (blindedTrace['output'] as Map<String, dynamic>),
        isNot(contains('resolvedModel')),
      );
      expect(
        (blindedTrace['output'] as Map<String, dynamic>),
        isNot(contains('providerDecision')),
      );
      expect(
        (blindedTrace['output'] as Map<String, dynamic>),
        isNot(contains('modelInvocations')),
      );
      expect(
        (blindedTrace['output'] as Map<String, dynamic>),
        isNot(contains('providerRequests')),
      );
      expect(
        (blindedTrace['output'] as Map<String, dynamic>),
        isNot(contains('providerResponses')),
      );
      expect(judgePayload, isNot(contains('frontier-secret-profile')));
      expect(judgePayload, isNot(contains('gpt-secret-model')));
      expect(judgePayload, isNot(contains('provider-secret-id')));
      expect(judgePayload, isNot(contains('model-config-secret')));
      expect(judgePayload, isNot(contains('metadata-secret-v1')));
      expect(privatePayload, contains('frontier-secret-profile'));
      expect(privatePayload, contains('gpt-secret-model'));
      expect(privatePayload, contains('metadata-secret-v1'));
      expect(privatePayload, contains(rawTraceDigest));
      expect(privatePayload, contains(rawTraceFile.uri.pathSegments.last));
    },
  );

  test('fails closed when model identity leaks through model output', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-blinded-export-leak-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: '${dir.path}/runs');
    final manifest = _manifest();
    await writer.writeManifest(manifest);
    await writer.writeTrace(
      _trace(
        manifestDigest: manifest.manifestDigest!,
        reportContent: 'The gpt-secret-model response completed the task.',
      ),
    );
    final run = await writer.readRun('blind-run');

    await expectLater(
      EvalBlindedTraceExporter.writeRun(
        run: run,
        writer: writer,
        outputDir: Directory('${dir.path}/blind'),
        exportSeed: 'test-seed',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains(
            'Blinded export leaked model identity "gpt-secret-model"',
          ),
        ),
      ),
    );
  });

  test('refuses to overwrite an existing blinded export by default', () async {
    final dir = await Directory.systemTemp.createTemp(
      'lotti-blinded-export-overwrite-',
    );
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    final writer = TraceWriter(runsRoot: '${dir.path}/runs');
    final manifest = _manifest();
    await writer.writeManifest(manifest);
    await writer.writeTrace(_trace(manifestDigest: manifest.manifestDigest!));
    final run = await writer.readRun('blind-run');
    final outputDir = Directory('${dir.path}/blind');

    await EvalBlindedTraceExporter.writeRun(
      run: run,
      writer: writer,
      outputDir: outputDir,
      exportSeed: 'test-seed',
    );

    await expectLater(
      EvalBlindedTraceExporter.writeRun(
        run: run,
        writer: writer,
        outputDir: outputDir,
        exportSeed: 'test-seed',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Refusing to overwrite blinded export directory'),
        ),
      ),
    );
    await EvalBlindedTraceExporter.writeRun(
      run: run,
      writer: writer,
      outputDir: outputDir,
      exportSeed: 'test-seed',
      overwrite: true,
    );
  });
}

const _profile = EvalProfile(
  name: 'frontier-secret-profile',
  isLocal: false,
  modelClass: EvalModelClass.frontierFast,
  modelId: 'gpt-secret-model',
  tokenBudget: 50000,
  maxCompletionTokens: 4096,
);

const _variant = EvalAgentDirectiveVariant(
  name: 'metadata-secret-v1',
  generalDirective: 'Create durable metadata before writing reports.',
);

EvalRunManifest _manifest() => EvalProvenance.captureRunManifest(
  runId: 'blind-run',
  targetName: 'blind-export-test',
  targetKind: 'test',
  scenarios: [taskReleaseNotesScenario],
  profiles: const [_profile],
  agentDirectiveVariants: const [_variant],
  createdAt: DateTime(2026, 6, 12, 12),
  command: 'blind-export-test',
  environment: const <String, String>{},
);

EvalTrace _trace({
  required String manifestDigest,
  String reportContent = 'Task metadata was updated.',
}) {
  final output = AgentRunOutput(
    success: true,
    usage: const InferenceUsage(inputTokens: 100, outputTokens: 25),
    toolCalls: const [
      ToolCallRecord(name: 'update_task', args: {'estimateMinutes': 30}),
    ],
    report: AgentReportRecord(
      oneLiner: 'Updated metadata',
      tldr: 'Task metadata was updated.',
      content: reportContent,
    ),
    resolvedModel: const ResolvedModelRecord(
      profileId: 'profile-secret-id',
      modelConfigId: 'model-config-secret',
      providerModelId: 'gpt-secret-model',
      providerId: 'provider-secret-id',
      providerType: 'openAi-secret',
      providerEndpointOrigin: 'https://secret-model.example',
      providerBaseUrlDigest:
          'sha256:1111111111111111111111111111111111111111111111111111111111111111',
      templateId: 'template-secret',
      templateVersionId: 'template-version-secret',
      wakeRunResolvedModelId: 'wake-model-secret',
      usageModelId: 'usage-model-secret',
    ),
    providerDecision: const ProviderDecisionRecord(
      profileName: 'frontier-secret-profile',
      modelClass: EvalModelClass.frontierFast,
      isLocal: false,
      profileId: 'profile-secret-id',
      selectedModelConfigId: 'model-config-secret',
      selectedProviderId: 'provider-secret-id',
      selectedProviderType: 'openAi-secret',
      selectedProviderModelId: 'gpt-secret-model',
      selectedProviderEndpointOrigin: 'https://secret-model.example',
      selectedProviderBaseUrlDigest:
          'sha256:1111111111111111111111111111111111111111111111111111111111111111',
      candidateModelConfigIds: ['model-config-secret'],
      candidateProviderIds: ['provider-secret-id'],
    ),
    runtimePrompt: const RuntimePromptRecord(
      systemDigest:
          'sha256:2222222222222222222222222222222222222222222222222222222222222222',
      userDigest:
          'sha256:3333333333333333333333333333333333333333333333333333333333333333',
      toolSchemaDigest:
          'sha256:4444444444444444444444444444444444444444444444444444444444444444',
      toolCount: 2,
    ),
    modelInvocations: const [
      ModelInvocationRecord(
        invocationIndex: 0,
        providerModelId: 'gpt-secret-model',
        providerId: 'provider-secret-id',
        providerType: 'openAi-secret',
        providerEndpointOrigin: 'https://secret-model.example',
        providerBaseUrlDigest:
            'sha256:1111111111111111111111111111111111111111111111111111111111111111',
        runtimePrompt: RuntimePromptRecord(
          systemDigest:
              'sha256:2222222222222222222222222222222222222222222222222222222222222222',
          userDigest:
              'sha256:3333333333333333333333333333333333333333333333333333333333333333',
          toolSchemaDigest:
              'sha256:4444444444444444444444444444444444444444444444444444444444444444',
          toolCount: 2,
        ),
        toolNames: ['update_task'],
      ),
    ],
    providerRequests: const [
      ProviderRequestRecord(
        invocationIndex: 0,
        requestIndex: 0,
        turnIndex: 0,
        providerModelId: 'gpt-secret-model',
        providerId: 'provider-secret-id',
        providerType: 'openAi-secret',
        providerEndpointOrigin: 'https://secret-model.example',
        providerBaseUrlDigest:
            'sha256:1111111111111111111111111111111111111111111111111111111111111111',
        messageDigest:
            'sha256:5555555555555555555555555555555555555555555555555555555555555555',
        messageCount: 3,
        toolSchemaDigest:
            'sha256:4444444444444444444444444444444444444444444444444444444444444444',
        toolCount: 2,
        toolNames: ['update_task'],
        temperature: 1,
        thoughtSignatureCount: 0,
      ),
    ],
    providerResponses: const [
      ProviderResponseRecord(
        invocationIndex: 0,
        requestIndex: 0,
        turnIndex: 0,
        providerType: 'openAi-secret',
        chunkCount: 8,
        responseModelIds: ['gpt-secret-model'],
        providerNames: ['provider-secret-id'],
      ),
    ],
    turnCount: 1,
    wallClockMs: 1234,
  );
  return EvalTrace(
    runId: 'blind-run',
    scenario: taskReleaseNotesScenario,
    profile: _profile,
    agentDirectiveVariant: _variant,
    provenance: EvalProvenance.capture(
      scenario: taskReleaseNotesScenario,
      profile: _profile,
      agentDirectiveVariant: _variant,
      manifestDigest: manifestDigest,
    ),
    output: output,
    level1Checks: runLevel1(
      taskReleaseNotesScenario,
      output,
      profile: _profile,
    ),
  );
}
