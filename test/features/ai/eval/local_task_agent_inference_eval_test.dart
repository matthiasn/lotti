import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/eval/local_task_agent_inference_eval.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  final provider = AiConfigInferenceProvider(
    id: 'provider-omlx',
    baseUrl: 'http://127.0.0.1:8003/v1',
    apiKey: 'test-key',
    name: 'Local oMLX',
    createdAt: DateTime(2026, 6, 21),
    inferenceProviderType: InferenceProviderType.omlx,
  );

  const profile = LocalTaskAgentEvalProfile(
    name: 'local-model',
    providerModelId: 'local-model-id',
    modelClass: 'local-test',
  );

  test(
    'default scenario uses production task-agent scaffold and expectations',
    () {
      final scenario = defaultLocalTaskAgentWakeScenario();

      expect(
        defaultLocalTaskAgentEvalProfiles.map((profile) => profile.name),
        equals(['qwen36-a35b-a3b-mlx4', 'gemma4-26b-a4b-qat-mlx4']),
      );
      expect(scenario.systemPrompt, contains('You are a Task Agent'));
      expect(scenario.userMessage, contains('## Current Task Context'));
      expect(scenario.userMessage, contains('## Parent Project Context'));
      expect(
        scenario.expectedToolCalls.map((expected) => expected.name),
        equals([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.updateTaskEstimate,
          TaskAgentToolNames.updateTaskDueDate,
          TaskAgentToolNames.updateTaskPriority,
        ]),
      );
    },
  );

  test(
    'task-agent eval tool surface uses the full enabled task-agent registry',
    () {
      final expected = AgentToolRegistry.taskAgentTools
          .where((definition) => definition.enabled)
          .map((definition) => definition.name)
          .toList();

      expect(
        buildLocalTaskAgentEvalTools().map((tool) => tool.function.name),
        equals(expected),
      );
      expect(expected, contains(TaskAgentToolNames.updateReport));
      expect(expected, contains(TaskAgentToolNames.recordObservations));
    },
  );

  test(
    'parseLocalTaskAgentEvalProfile trims and validates name=model pairs',
    () {
      final parsed = parseLocalTaskAgentEvalProfile(
        '  gemma4 = gemma-4-26B-A4B-it-QAT-MLX-4bit  ',
      );

      expect(parsed.name, 'gemma4');
      expect(parsed.providerModelId, 'gemma-4-26B-A4B-it-QAT-MLX-4bit');
      expect(parsed.modelClass, 'gemma4');
      expect(
        () => parseLocalTaskAgentEvalProfile('gemma4'),
        throwsFormatException,
      );
      expect(
        () => parseLocalTaskAgentEvalProfile('=model'),
        throwsFormatException,
      );
      expect(
        () => parseLocalTaskAgentEvalProfile('name='),
        throwsFormatException,
      );
    },
  );

  test('parseLocalTaskAgentEvalTemperature validates the accepted range', () {
    expect(parseLocalTaskAgentEvalTemperature(null), isNull);
    expect(parseLocalTaskAgentEvalTemperature('   '), isNull);
    expect(parseLocalTaskAgentEvalTemperature('0'), 0);
    expect(parseLocalTaskAgentEvalTemperature(' 0.7 '), 0.7);
    expect(parseLocalTaskAgentEvalTemperature('2'), 2);

    for (final value in ['nan', 'NaN', 'Infinity', '-0.1', '2.1']) {
      expect(
        () => parseLocalTaskAgentEvalTemperature(value),
        throwsFormatException,
      );
    }
  });

  test(
    'runner exercises real conversation continuation until update_report',
    () async {
      final scenario = defaultLocalTaskAgentWakeScenario();
      final fakeInference = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.setTaskTitle,
              argumentsJson: '{"title":"Validate local Gemma fallback"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskEstimate,
              argumentsJson: '{"minutes":150}',
            ),
            (
              name: TaskAgentToolNames.updateTaskDueDate,
              argumentsJson: '{"dueDate":"2026-07-04"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskPriority,
              argumentsJson: '{"priority":"P1"}',
            ),
          ]),
        ],
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.updateReport,
              argumentsJson: jsonEncode({
                'oneLiner': 'Local Gemma fallback is being validated',
                'tldr': 'The local model eval now exercises a real wake shape.',
                'content': '## TLDR\nThe stronger local eval passed.',
              }),
            ),
          ]),
        ],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: fakeInference,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [scenario],
      );

      final result = report.results.single;
      expect(result.passed, isTrue);
      expect(result.failureCategory, LocalTaskAgentEvalFailureCategory.none);
      expect(fakeInference.requests, hasLength(2));
      expect(
        fakeInference.requests.first.toolNames,
        containsAll([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.updateReport,
          TaskAgentToolNames.recordObservations,
        ]),
      );
      expect(
        jsonEncode(
          fakeInference.requests.first.messages
              .map((message) => message.toJson())
              .toList(),
        ),
        contains('## Current Task Context'),
      );
    },
  );

  test('runner records inference failure and continues the matrix', () async {
    const secondProfile = LocalTaskAgentEvalProfile(
      name: 'second-local-model',
      providerModelId: 'second-local-model-id',
      modelClass: 'local-test',
    );
    final fakeInference = _FailThenSucceedInferenceRepository();
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: fakeInference,
    );

    final report = await runner.run(
      profiles: const [profile, secondProfile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    expect(report.results, hasLength(2));
    expect(
      report.results.first.failureCategory,
      LocalTaskAgentEvalFailureCategory.inferenceFailed,
    );
    expect(
      report.results.first.finalContent,
      contains('Inference failed'),
    );
    expect(
      report.results.last.failureCategory,
      LocalTaskAgentEvalFailureCategory.none,
    );
    expect(
      fakeInference.requests.map((request) => request.model),
      equals(['local-model-id', 'second-local-model-id']),
    );
  });

  test(
    'runner fails simple tool smoke output when final report is missing',
    () async {
      final fakeInference = _QueuedInferenceRepository([
        [
          _toolCalls([
            (
              name: TaskAgentToolNames.setTaskTitle,
              argumentsJson: '{"title":"Validate local Gemma fallback"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskEstimate,
              argumentsJson: '{"minutes":150}',
            ),
            (
              name: TaskAgentToolNames.updateTaskDueDate,
              argumentsJson: '{"dueDate":"2026-07-04"}',
            ),
            (
              name: TaskAgentToolNames.updateTaskPriority,
              argumentsJson: '{"priority":"P1"}',
            ),
          ]),
        ],
        [_content('Done.')],
      ]);
      final runner = _createRunner(
        provider: provider,
        inferenceRepository: fakeInference,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultLocalTaskAgentWakeScenario()],
      );

      expect(
        report.results.single.failureCategory,
        LocalTaskAgentEvalFailureCategory.missingReport,
      );
    },
  );

  test('runner flags unexpected production-wake tool calls', () async {
    final fakeInference = _QueuedInferenceRepository([
      [
        _toolCalls([
          (
            name: TaskAgentToolNames.setTaskTitle,
            argumentsJson: '{"title":"Validate local Gemma fallback"}',
          ),
          (
            name: TaskAgentToolNames.updateTaskEstimate,
            argumentsJson: '{"minutes":150}',
          ),
          (
            name: TaskAgentToolNames.updateTaskDueDate,
            argumentsJson: '{"dueDate":"2026-07-04"}',
          ),
          (
            name: TaskAgentToolNames.updateTaskPriority,
            argumentsJson: '{"priority":"P1"}',
          ),
          (
            name: TaskAgentToolNames.setTaskStatus,
            argumentsJson: '{"status":"IN PROGRESS"}',
          ),
          (
            name: TaskAgentToolNames.updateReport,
            argumentsJson: jsonEncode({
              'oneLiner': 'Report exists',
              'tldr': 'Report exists.',
              'content': '## TLDR\nReport exists.',
            }),
          ),
        ]),
      ],
    ]);
    final runner = _createRunner(
      provider: provider,
      inferenceRepository: fakeInference,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultLocalTaskAgentWakeScenario()],
    );

    expect(
      report.results.single.failureCategory,
      LocalTaskAgentEvalFailureCategory.unexpectedToolCall,
    );
  });
}

LocalTaskAgentInferenceEvalRunner _createRunner({
  required AiConfigInferenceProvider provider,
  required InferenceRepositoryInterface inferenceRepository,
}) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return LocalTaskAgentInferenceEvalRunner(
    provider: provider,
    conversationRepository: container.read(
      conversationRepositoryProvider.notifier,
    ),
    inferenceRepository: inferenceRepository,
  );
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.messages,
    required this.toolNames,
    required this.model,
  });

  final List<ChatCompletionMessage> messages;
  final List<String> toolNames;
  final String model;
}

class _QueuedInferenceRepository extends InferenceRepositoryInterface {
  _QueuedInferenceRepository(this.responsesByRequest);

  final List<List<CreateChatCompletionStreamResponse>> responsesByRequest;
  final requests = <_RecordedRequest>[];
  var _requestIndex = 0;

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
  }) {
    requests.add(
      _RecordedRequest(
        messages: messages,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
        model: model,
      ),
    );
    final responses = _requestIndex < responsesByRequest.length
        ? responsesByRequest[_requestIndex]
        : const <CreateChatCompletionStreamResponse>[];
    _requestIndex++;
    return Stream.fromIterable(responses);
  }
}

class _FailThenSucceedInferenceRepository extends InferenceRepositoryInterface {
  final requests = <_RecordedRequest>[];

  @override
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
  }) {
    requests.add(
      _RecordedRequest(
        messages: messages,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
        model: model,
      ),
    );
    if (requests.length == 1) {
      throw StateError('connection refused');
    }
    return Stream.fromIterable([
      _toolCalls([
        (
          name: TaskAgentToolNames.setTaskTitle,
          argumentsJson: '{"title":"Validate local Gemma fallback"}',
        ),
        (
          name: TaskAgentToolNames.updateTaskEstimate,
          argumentsJson: '{"minutes":150}',
        ),
        (
          name: TaskAgentToolNames.updateTaskDueDate,
          argumentsJson: '{"dueDate":"2026-07-04"}',
        ),
        (
          name: TaskAgentToolNames.updateTaskPriority,
          argumentsJson: '{"priority":"P1"}',
        ),
        (
          name: TaskAgentToolNames.updateReport,
          argumentsJson: jsonEncode({
            'oneLiner': 'Report exists',
            'tldr': 'Report exists.',
            'content': '## TLDR\nReport exists.',
          }),
        ),
      ]),
    ]);
  }
}

CreateChatCompletionStreamResponse _content(String text) {
  return CreateChatCompletionStreamResponse(
    id: 'content',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta(content: text),
        index: 0,
      ),
    ],
    object: 'chat.completion.chunk',
    created: 0,
  );
}

CreateChatCompletionStreamResponse _toolCalls(
  List<({String name, String argumentsJson})> calls,
) {
  return CreateChatCompletionStreamResponse(
    id: 'tool',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [
            for (var i = 0; i < calls.length; i++)
              {
                'index': i,
                'id': 'call-$i',
                'type': 'function',
                'function': {
                  'name': calls[i].name,
                  'arguments': calls[i].argumentsJson,
                },
              },
          ],
        }),
        index: 0,
      ),
    ],
    object: 'chat.completion.chunk',
    created: 0,
  );
}
