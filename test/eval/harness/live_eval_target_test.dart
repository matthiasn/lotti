import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../helpers/fallbacks.dart';
import '../../mocks/mocks.dart' show MockCloudInferenceRepository;
import '../scenarios/eval_scenarios.dart';
import 'eval_target.dart';
import 'live_eval_target.dart';
import 'profiles.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  test('run refuses before touching live dependencies when disabled', () async {
    final target = LiveEvalTarget(
      settings: LiveEvalSettings.fromEnvironment(const <String, String>{}),
    );
    addTearDown(target.dispose);

    expect(
      () => target.run(allEvalScenarios.first, kLocalSmallProfile),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('LOTTI_EVAL_LIVE'),
        ),
      ),
    );
  });

  test('profile execution bindings can be previewed before live opt-in', () {
    final settings = LiveEvalSettings.fromEnvironment(const <String, String>{
      'LOTTI_EVAL_FRONTIER_PROVIDER': 'openAi',
      'LOTTI_EVAL_FRONTIER_MODEL': 'gpt-5-mini',
      'OPENAI_API_KEY': 'live-key',
    });
    final target = LiveEvalTarget(settings: settings);
    addTearDown(target.dispose);

    final bindings = target.profileExecutionBindings([kFrontierFastProfile]);

    expect(bindings, hasLength(1));
    expect(bindings.single.profileName, kFrontierFastProfile.name);
    expect(bindings.single.providerType, InferenceProviderType.openAi.name);
    expect(bindings.single.providerModelId, 'gpt-5-mini');
    expect(
      () => settings.validateProfile(kFrontierFastProfile),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('LOTTI_EVAL_LIVE'),
        ),
      ),
    );
  });

  test('refuses CI live runs without explicit opt-in', () {
    final settings = LiveEvalSettings.fromEnvironment(const <String, String>{
      'LOTTI_EVAL_LIVE': '1',
      'CI': 'true',
      'LOTTI_EVAL_LOCAL_MODEL': 'llama3.1:8b',
    });

    expect(
      () => settings.validateProfile(kLocalSmallProfile),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('LOTTI_EVAL_ALLOW_CI'),
        ),
      ),
    );
  });

  test('maps local profile to live Ollama config from environment', () {
    final settings = LiveEvalSettings.fromEnvironment(const <String, String>{
      'LOTTI_EVAL_LIVE': '1',
      'LOTTI_EVAL_LOCAL_MODEL': 'llama3.1:8b',
      'OLLAMA_BASE_URL': 'http://127.0.0.1:11434',
    });

    final config = settings.profileConfigFor(kLocalSmallProfile);

    expect(config.provider.inferenceProviderType, InferenceProviderType.ollama);
    expect(config.provider.baseUrl, 'http://127.0.0.1:11434');
    expect(config.provider.apiKey, isEmpty);
    expect(config.model.providerModelId, 'llama3.1:8b');
    expect(config.provider.isUsable, isTrue);
  });

  test('maps frontier profile to configured provider credentials', () {
    final settings = LiveEvalSettings.fromEnvironment(const <String, String>{
      'LOTTI_EVAL_LIVE': '1',
      'LOTTI_EVAL_FRONTIER_PROVIDER': 'openAi',
      'LOTTI_EVAL_FRONTIER_MODEL': 'gpt-5-mini',
      'OPENAI_API_KEY': 'live-key',
      'OPENAI_BASE_URL': 'https://example.invalid/v1',
    });

    final config = settings.profileConfigFor(kFrontierFastProfile);

    expect(config.provider.inferenceProviderType, InferenceProviderType.openAi);
    expect(config.provider.apiKey, 'live-key');
    expect(config.provider.baseUrl, 'https://example.invalid/v1');
    expect(config.model.providerModelId, 'gpt-5-mini');
    expect(config.provider.isUsable, isTrue);

    final envPresence = settings.envPresenceForProfile(kFrontierFastProfile);
    expect(envPresence['LOTTI_EVAL_FRONTIER_PROVIDER'], isTrue);
    expect(envPresence['LOTTI_EVAL_FRONTIER_MODEL'], isTrue);
    expect(envPresence['OPENAI_API_KEY'], isTrue);
    expect(envPresence.toString(), isNot(contains('live-key')));
  });

  test(
    'live target binds profile slots to actual provider/model overrides',
    () {
      final target = LiveEvalTarget(
        settings: LiveEvalSettings.fromEnvironment(const <String, String>{
          'LOTTI_EVAL_LIVE': '1',
          'LOTTI_EVAL_FRONTIER_PROVIDER': 'openAi',
          'LOTTI_EVAL_FRONTIER_MODEL': 'gpt-5-mini',
          'LOTTI_EVAL_FRONTIER_BASE_URL': 'https://proxy.invalid/v1',
          'OPENAI_API_KEY': 'live-key',
        }),
      );
      addTearDown(target.dispose);

      final bindings = target.profileExecutionBindings([kFrontierFastProfile]);

      expect(bindings, hasLength(1));
      final binding = bindings.single;
      expect(binding.profileName, kFrontierFastProfile.name);
      expect(binding.modelConfigId, kFrontierFastProfile.modelId);
      expect(binding.providerType, InferenceProviderType.openAi.name);
      expect(binding.providerModelId, 'gpt-5-mini');
      expect(binding.providerEndpointOrigin, 'https://proxy.invalid');
      expect(binding.providerBaseUrlDigest, startsWith('sha256:'));
      expect(binding.providerRequestTemperature, 1);
      expect(binding.toJson().toString(), isNot(contains('live-key')));
    },
  );

  test(
    'live path uses observed provider stream and persisted action rows',
    () async {
      final cloudRepository = MockCloudInferenceRepository();
      var providerInvocation = 0;
      when(
        () => cloudRepository.generateWithMessages(
          messages: any(named: 'messages'),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          provider: any(named: 'provider'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          tools: any(named: 'tools'),
          toolChoice: any(named: 'toolChoice'),
          thoughtSignatures: any(named: 'thoughtSignatures'),
          signatureCollector: any(named: 'signatureCollector'),
          turnIndex: any(named: 'turnIndex'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
        ),
      ).thenAnswer((_) {
        providerInvocation++;
        if (providerInvocation == 1) {
          return Stream<CreateChatCompletionStreamResponse>.fromIterable([
            CreateChatCompletionStreamResponse(
              id: 'live-tool-call',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'draft_day_plan',
                          arguments: _draftDayPlanArgs(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1700000000,
            ),
            const CreateChatCompletionStreamResponse(
              id: 'live-tool-usage',
              choices: [],
              object: 'chat.completion.chunk',
              created: 1700000001,
              usage: CompletionUsage(
                promptTokens: 1200,
                completionTokens: 180,
                totalTokens: 1380,
              ),
            ),
          ]);
        }
        return Stream<CreateChatCompletionStreamResponse>.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'live-final',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'Drafted.'),
              ),
            ],
            object: 'chat.completion.chunk',
            created: 1700000002,
            usage: CompletionUsage(
              promptTokens: 80,
              completionTokens: 10,
              totalTokens: 90,
            ),
          ),
        ]);
      });
      final container = ProviderContainer(
        overrides: [
          cloudInferenceRepositoryProvider.overrideWithValue(cloudRepository),
        ],
      );
      addTearDown(container.dispose);
      final target = LiveEvalTarget(
        settings: LiveEvalSettings.fromEnvironment(const <String, String>{
          'LOTTI_EVAL_LIVE': '1',
          'LOTTI_EVAL_FRONTIER_PROVIDER': 'openAi',
          'LOTTI_EVAL_FRONTIER_MODEL': 'gpt-live-eval',
          'OPENAI_API_KEY': 'live-key',
        }),
        providerContainer: container,
      );
      addTearDown(target.dispose);
      const context = EvalTargetRunContext(
        runId: 'live-unit',
        scenarioId: 'planner_workflow_drafting',
        profileName: 'frontier-gemini',
        trialIndex: 2,
      );

      final output = await target.run(
        plannerWorkflowDraftingScenario,
        kFrontierProfile,
        context: context,
      );

      expect(output.success, isTrue, reason: output.error);
      expect(providerInvocation, 2);
      expect(output.toolCalls.map((record) => record.name), ['draft_day_plan']);
      expect(output.toolCalls.single.args['dayId'], kPlannerWorkflowDayId);
      expect(output.plannedBlocks, hasLength(2));
      expect(output.workflowRun!.runKey, contains(context.cellId));
      expect(output.workflowRun!.threadId, contains(context.cellId));
      expect(output.resolvedModel!.providerModelId, 'gpt-live-eval');
      expect(output.resolvedModel!.usageModelId, 'gpt-live-eval');
      expect(output.providerDecision, isNotNull);
      expect(output.providerDecision!.selectedProviderType, 'openAi');
      expect(output.providerDecision!.selectedProviderModelId, 'gpt-live-eval');
      expect(
        output.providerDecision!.envPresence['LOTTI_EVAL_FRONTIER_MODEL'],
        isTrue,
      );
      expect(output.providerDecision!.envPresence['OPENAI_API_KEY'], isTrue);
      expect(
        output.providerDecision!.toJson().toString(),
        isNot(contains('live-key')),
      );
      expect(output.runtimePrompt, isNotNull);
      expect(output.runtimePrompt!.systemDigest, startsWith('sha256:'));
      expect(output.runtimePrompt!.userDigest, startsWith('sha256:'));
      expect(output.runtimePrompt!.toolSchemaDigest, startsWith('sha256:'));
      expect(output.runtimePrompt!.toolCount, greaterThan(0));
      expect(output.modelInvocations, hasLength(output.turnCount));
      expect(output.modelInvocations.map((record) => record.invocationIndex), [
        0,
      ]);
      expect(
        output.modelInvocations.every(
          (record) => record.providerModelId == 'gpt-live-eval',
        ),
        isTrue,
      );
      expect(
        output.modelInvocations.every(
          (record) => record.providerType == 'openAi',
        ),
        isTrue,
      );
      expect(
        output.modelInvocations.last.runtimePrompt.userDigest,
        output.runtimePrompt!.userDigest,
      );
      expect(output.providerRequests, hasLength(providerInvocation));
      expect(
        output.providerRequests.map((record) => record.invocationIndex),
        [0, 0],
      );
      expect(
        output.providerRequests.map((record) => record.requestIndex),
        [0, 1],
      );
      expect(output.providerRequests.map((record) => record.turnIndex), [1, 2]);
      expect(
        output.providerRequests.every(
          (record) => record.providerModelId == 'gpt-live-eval',
        ),
        isTrue,
      );
      expect(
        output.providerRequests.every(
          (record) => record.providerType == 'openAi',
        ),
        isTrue,
      );
      expect(
        output.providerRequests.every((record) => record.temperature == 1),
        isTrue,
      );
      expect(
        output.providerRequests.every(
          (record) => record.messageDigest.startsWith('sha256:'),
        ),
        isTrue,
      );
      expect(output.providerRequests.first.messageCount, lessThan(3));
      expect(output.providerRequests.last.messageCount, greaterThan(3));
      expect(output.toJson().toString(), isNot(contains('live-key')));
      expect(output.toJson().toString(), isNot(contains('Drafted.')));
      expect(output.usage.inputTokens, 1280);
      expect(output.usage.outputTokens, 190);
    },
  );
}

String _draftDayPlanArgs() =>
    '''
{
  "dayId": "$kPlannerWorkflowDayId",
  "capacityMinutes": 240,
  "decidedTaskIds": ["task-run", "task-adr"],
  "blocks": [
    {
      "id": "live-run",
      "categoryId": "cat-health",
      "start": "2026-06-09T07:30:00.000",
      "end": "2026-06-09T08:10:00.000",
      "taskId": "task-run",
      "title": "Morning run",
      "type": "ai",
      "reason": "live eval fake provider"
    },
    {
      "id": "live-adr",
      "categoryId": "cat-work",
      "start": "2026-06-09T09:00:00.000",
      "end": "2026-06-09T11:00:00.000",
      "taskId": "task-adr",
      "title": "Finish the planner ADR",
      "type": "ai",
      "reason": "live eval fake provider"
    }
  ]
}
''';
