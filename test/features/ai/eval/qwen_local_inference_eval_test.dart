import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/ai/eval/qwen_local_inference_eval.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  const profile = QwenLocalEvalProfile(
    name: 'qwen-test',
    providerModelId: qwen36A35bA3bTurboQuantMlx4BitModelId,
    modelClass: 'qwen36-a35b-a3b-omlx',
  );
  final provider = AiConfigInferenceProvider(
    id: 'provider-omlx',
    baseUrl: 'http://localhost:8002/v1',
    apiKey: '',
    name: 'oMLX',
    createdAt: DateTime(2026, 6, 16),
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );

  test('default eval profiles target all installed oMLX Qwen models', () {
    expect(
      defaultQwenLocalEvalProfiles.map((profile) => profile.providerModelId),
      equals([
        qwen36A35bA3bTurboQuantMlx4BitModelId,
        qwen36A35bA3bMlx4BitModelId,
        qwen36A35bA3bMlx8BitModelId,
      ]),
    );
  });

  test('default eval scenarios validate core task-field arguments', () {
    expect(
      defaultQwenLocalEvalScenarios.map((scenario) => scenario.id),
      equals([
        'task_title_tool_call',
        'task_status_tool_call',
        'task_estimate_tool_call',
        'task_due_date_tool_call',
        'task_priority_tool_call',
      ]),
    );
    expect(
      defaultQwenLocalEvalScenarios
          .map((scenario) => scenario.expectedArgumentsSubset)
          .toList(),
      equals([
        {'title': 'Submit expense report'},
        {'status': 'IN PROGRESS'},
        {'minutes': 150},
        {'dueDate': '2026-07-04'},
        {'priority': 'P1'},
      ]),
    );
  });

  test('parseQwenLocalEvalProfile trims name and model id', () {
    final parsed = parseQwenLocalEvalProfile(
      '  qwen local  =  Qwen3.6-35B-A3B-4bit  ',
    );

    expect(parsed.name, 'qwen local');
    expect(parsed.providerModelId, 'Qwen3.6-35B-A3B-4bit');
    expect(parsed.modelClass, 'qwen local');
  });

  test('parseQwenLocalEvalProfile rejects blank trimmed parts', () {
    expect(
      () => parseQwenLocalEvalProfile('qwen =   '),
      throwsFormatException,
    );
    expect(
      () => parseQwenLocalEvalProfile('   = Qwen3.6-35B-A3B-4bit'),
      throwsFormatException,
    );
  });

  test('parseQwenLocalEvalProfile rejects malformed separators', () {
    for (final value in ['qwen', '=Qwen3.6-35B-A3B-4bit', 'qwen=']) {
      expect(
        () => parseQwenLocalEvalProfile(value),
        throwsFormatException,
      );
    }
  });

  test('selectQwenLocalEvalScenarios filters known ids', () {
    expect(
      selectQwenLocalEvalScenarios(const []),
      same(defaultQwenLocalEvalScenarios),
    );
    expect(
      selectQwenLocalEvalScenarios(const [
        'task_status_tool_call',
      ]).map((scenario) => scenario.id),
      equals(['task_status_tool_call']),
    );
    expect(
      () => selectQwenLocalEvalScenarios(const ['missing_scenario']),
      throwsArgumentError,
    );
  });

  test('tool-call argument matching handles nested maps and lists', () {
    const toolCall = QwenLocalEvalToolCall(
      name: TaskAgentToolNames.setTaskTitle,
      argumentsJson: '''
{
  "title": "Submit expense report",
  "metadata": {
    "priority": "P1",
    "tags": ["finance", "urgent"]
  }
}
''',
    );

    expect(
      toolCall.containsExpectedArguments({
        'metadata': {
          'priority': 'P1',
          'tags': ['finance', 'urgent'],
        },
      }),
      isTrue,
    );
    expect(
      toolCall.containsExpectedArguments({
        'metadata': {
          'tags': ['finance'],
        },
      }),
      isFalse,
    );
    expect(
      toolCall.containsExpectedArguments({
        'metadata': {
          'tags': ['finance', 'later'],
        },
      }),
      isFalse,
    );
    expect(
      toolCall.containsExpectedArguments({'metadata': 'not-a-map'}),
      isFalse,
    );
    expect(
      toolCall.containsExpectedArguments({'missing': true}),
      isFalse,
    );

    const invalidToolCall = QwenLocalEvalToolCall(
      name: TaskAgentToolNames.setTaskTitle,
      argumentsJson: '[]',
    );
    expect(invalidToolCall.hasJsonObjectArguments, isFalse);
    expect(invalidToolCall.containsExpectedArguments(const {}), isFalse);
    expect(
      invalidToolCall.toJson(),
      containsPair('argumentsJsonValid', false),
    );
  });

  test(
    'runner records provenance, latency, usage, and matching tool calls',
    () async {
      final repository = _FakeInferenceRepository([
        _content('I will update the title.'),
        _toolCall(
          name: TaskAgentToolNames.setTaskTitle,
          argumentsJson: '{"title":"Submit expense report"}',
        ),
        _usage(inputTokens: 42, outputTokens: 11),
      ]);
      final scenario = defaultQwenLocalEvalScenarios.first;
      final runner = QwenLocalInferenceEvalRunner(
        provider: provider,
        repository: repository,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [scenario],
      );

      expect(repository.requests, hasLength(1));
      expect(
        repository.requests.single.model,
        qwen36A35bA3bTurboQuantMlx4BitModelId,
      );
      expect(
        repository.requests.single.toolNames,
        equals([
          TaskAgentToolNames.setTaskTitle,
          TaskAgentToolNames.setTaskStatus,
          TaskAgentToolNames.updateTaskEstimate,
          TaskAgentToolNames.updateTaskDueDate,
          TaskAgentToolNames.updateTaskPriority,
        ]),
      );

      final result = report.results.single;
      expect(result.passed, isTrue);
      expect(result.provider.baseUrl, provider.baseUrl);
      expect(
        result.profile.providerModelId,
        qwen36A35bA3bTurboQuantMlx4BitModelId,
      );
      expect(result.latencyMs, greaterThanOrEqualTo(0));
      expect(result.contentLength, greaterThan(0));
      expect(result.inputTokens, 42);
      expect(result.outputTokens, 11);
      expect(result.toolCalls.single.name, TaskAgentToolNames.setTaskTitle);
      expect(result.toolCalls.single.hasJsonObjectArguments, isTrue);
      expect(result.matchedExpectedArguments, isTrue);

      final summary = report.summaries.single;
      expect(summary.passedScenarios, 1);
      expect(summary.toolCallScenarioCount, 1);
      expect(summary.matchedToolCallScenarios, 1);
      expect(summary.argumentScenarioCount, 1);
      expect(summary.matchedArgumentScenarios, 1);
      expect(summary.failureCounts, isEmpty);
    },
  );

  test('runner classifies missing expected tool calls', () async {
    final repository = _FakeInferenceRepository([_content('Done.')]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    final result = report.results.single;
    expect(result.passed, isFalse);
    expect(
      result.failureCategory,
      QwenLocalEvalFailureCategory.missingToolCall,
    );
    expect(report.summaries.single.failureCounts, {
      QwenLocalEvalFailureCategory.missingToolCall: 1,
    });
  });

  test('runner classifies invalid arguments on the expected tool', () async {
    final repository = _FakeInferenceRepository([
      _toolCall(
        name: TaskAgentToolNames.setTaskTitle,
        argumentsJson: 'not-json',
      ),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    expect(
      report.results.single.failureCategory,
      QwenLocalEvalFailureCategory.invalidToolArguments,
    );
  });

  test('runner classifies mismatched expected argument values', () async {
    final repository = _FakeInferenceRepository([
      _toolCall(
        name: TaskAgentToolNames.setTaskTitle,
        argumentsJson: '{"title":"Submit reimbursement"}',
      ),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    final result = report.results.single;
    expect(
      result.failureCategory,
      QwenLocalEvalFailureCategory.argumentMismatch,
    );
    expect(result.matchedExpectedTool, isTrue);
    expect(result.matchedExpectedArguments, isFalse);
    expect(report.summaries.single.failureCounts, {
      QwenLocalEvalFailureCategory.argumentMismatch: 1,
    });
  });

  test('runner accumulates streamed tool-call argument chunks', () async {
    final repository = _FakeInferenceRepository([
      _toolCallChunk(
        id: 'call-1',
        name: TaskAgentToolNames.setTaskTitle,
        argumentsJson: '{"title":',
      ),
      _toolCallChunk(argumentsJson: '"Submit expense report"}'),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    final toolCall = report.results.single.toolCalls.single;
    expect(toolCall.name, TaskAgentToolNames.setTaskTitle);
    expect(toolCall.argumentsJson, '{"title":"Submit expense report"}');
    expect(report.results.single.passed, isTrue);
  });

  test(
    'runner creates fallback ids for streamed tool calls without ids',
    () async {
      final repository = _FakeInferenceRepository([
        _toolCallChunk(
          name: TaskAgentToolNames.setTaskTitle,
          argumentsJson: '{"title":"Submit expense report"}',
        ),
      ]);
      final runner = QwenLocalInferenceEvalRunner(
        provider: provider,
        repository: repository,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: [defaultQwenLocalEvalScenarios.first],
      );

      expect(
        report.results.single.toolCalls.single.name,
        TaskAgentToolNames.setTaskTitle,
      );
      expect(report.results.single.passed, isTrue);
    },
  );

  test('runner preserves function names streamed after arguments', () async {
    final repository = _FakeInferenceRepository([
      _toolCallChunk(id: 'call-1', argumentsJson: '{"title":'),
      _toolCallChunk(
        name: TaskAgentToolNames.setTaskTitle,
        argumentsJson: '"Submit expense report"}',
      ),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    final toolCall = report.results.single.toolCalls.single;
    expect(toolCall.name, TaskAgentToolNames.setTaskTitle);
    expect(toolCall.argumentsJson, '{"title":"Submit expense report"}');
    expect(report.results.single.passed, isTrue);
  });

  test('runner ignores malformed streamed tool-call chunks', () async {
    final repository = _FakeInferenceRepository([
      _toolCallChunkWithoutFunction(),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    expect(report.results.single.toolCalls, isEmpty);
    expect(
      report.results.single.failureCategory,
      QwenLocalEvalFailureCategory.missingToolCall,
    );
  });

  test('runner classifies a different tool as wrong tool call', () async {
    final repository = _FakeInferenceRepository([
      _toolCall(
        name: TaskAgentToolNames.setTaskStatus,
        argumentsJson: '{"status":"IN PROGRESS"}',
      ),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    expect(
      report.results.single.failureCategory,
      QwenLocalEvalFailureCategory.wrongToolCall,
    );
  });

  test(
    'runner classifies empty no-tool scenarios as empty responses',
    () async {
      const scenario = QwenLocalEvalScenario(
        id: 'plain_response',
        userPrompt: 'Answer with a short acknowledgement.',
        exposedToolNames: [],
      );
      final repository = _FakeInferenceRepository(const []);
      final runner = QwenLocalInferenceEvalRunner(
        provider: provider,
        repository: repository,
      );

      final report = await runner.run(
        profiles: const [profile],
        scenarios: const [scenario],
      );

      expect(
        report.results.single.failureCategory,
        QwenLocalEvalFailureCategory.emptyResponse,
      );
    },
  );

  test('runner ignores stream chunks without choices', () async {
    const scenario = QwenLocalEvalScenario(
      id: 'plain_response',
      userPrompt: 'Answer with a short acknowledgement.',
      exposedToolNames: [],
    );
    final repository = _FakeInferenceRepository([
      _chunkWithoutChoices(),
      _content('Acknowledged.'),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: const [scenario],
    );

    expect(
      report.results.single.failureCategory,
      QwenLocalEvalFailureCategory.none,
    );
    expect(report.results.single.contentLength, greaterThan(0));
  });

  test('runner reports unknown exposed tools as request failures', () async {
    const scenario = QwenLocalEvalScenario(
      id: 'unknown_tool',
      userPrompt: 'Use a tool that is not registered.',
      exposedToolNames: ['missing_tool'],
    );
    final repository = _FakeInferenceRepository(const []);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: const [scenario],
    );

    final result = report.results.single;
    expect(result.failureCategory, QwenLocalEvalFailureCategory.requestFailed);
    expect(result.errorMessage, contains('Unknown enabled task-agent tool'));
    expect(repository.requests, isEmpty);
  });

  test('runner records request failures without leaking long errors', () async {
    final repository = _FakeInferenceRepository(
      const [],
      error: StateError(
        'oMLX request failed ${List.filled(260, 'x').join()}',
      ),
    );
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios.first],
    );

    final result = report.results.single;
    expect(result.failureCategory, QwenLocalEvalFailureCategory.requestFailed);
    expect(result.errorMessage, contains('oMLX request failed'));
    expect(result.errorMessage!.length, lessThanOrEqualTo(243));
  });

  test('report JSON and Markdown stay compact and identity-focused', () async {
    final repository = _FakeInferenceRepository([
      _toolCall(
        name: TaskAgentToolNames.setTaskStatus,
        argumentsJson: '{"status":"IN PROGRESS"}',
      ),
    ]);
    final runner = QwenLocalInferenceEvalRunner(
      provider: provider,
      repository: repository,
    );

    final report = await runner.run(
      profiles: const [profile],
      scenarios: [defaultQwenLocalEvalScenarios[1]],
    );

    expect(report.toJson(), containsPair('kind', qwenLocalEvalKind));
    expect(
      report.toJson()['provider'],
      isNot(containsPair('apiKey', provider.apiKey)),
    );
    expect(report.toPrettyJson(), contains('"failureCategory": "none"'));
    expect(report.toPrettyJson(), contains('"matchedExpectedArguments": true'));
    expect(report.toMarkdown(), contains('| qwen-test |'));
    expect(report.toMarkdown(), contains('| Arg match |'));
    expect(report.toMarkdown(), isNot(contains('Task id task-2')));
  });

  test('report summaries keep duplicate profile names isolated', () {
    const secondProfile = QwenLocalEvalProfile(
      name: 'qwen-test',
      providerModelId: qwen36A35bA3bMlx4BitModelId,
      modelClass: 'qwen36-a35b-a3b-omlx',
    );
    final scenario = defaultQwenLocalEvalScenarios.first;
    final report = QwenLocalEvalReport(
      provider: provider,
      scenarios: [scenario],
      profiles: const [profile, secondProfile],
      results: [
        QwenLocalEvalCaseResult(
          profile: profile,
          scenario: scenario,
          provider: provider,
          latencyMs: 10,
          contentLength: 1,
          toolCalls: const [],
          failureCategory: QwenLocalEvalFailureCategory.none,
        ),
        QwenLocalEvalCaseResult(
          profile: secondProfile,
          scenario: scenario,
          provider: provider,
          latencyMs: 20,
          contentLength: 1,
          toolCalls: const [],
          failureCategory: QwenLocalEvalFailureCategory.missingToolCall,
        ),
      ],
    );

    expect(report.summaries, hasLength(2));
    expect(report.summaries[0].totalScenarios, 1);
    expect(report.summaries[0].passedScenarios, 1);
    expect(report.summaries[0].failureCounts, isEmpty);
    expect(report.summaries[1].totalScenarios, 1);
    expect(report.summaries[1].passedScenarios, 0);
    expect(report.summaries[1].failureCounts, {
      QwenLocalEvalFailureCategory.missingToolCall: 1,
    });
  });

  test('report markdown includes failures and empty-profile summaries', () {
    const emptyProfile = QwenLocalEvalProfile(
      name: 'qwen-empty',
      providerModelId: 'not-run',
      modelClass: 'qwen36-a35b-a3b-omlx',
    );
    final scenario = defaultQwenLocalEvalScenarios.first;
    final report = QwenLocalEvalReport(
      provider: provider,
      scenarios: [scenario],
      profiles: const [emptyProfile, profile],
      results: [
        QwenLocalEvalCaseResult(
          profile: profile,
          scenario: scenario,
          provider: provider,
          latencyMs: 25,
          contentLength: 0,
          toolCalls: const [],
          failureCategory: QwenLocalEvalFailureCategory.missingToolCall,
          errorMessage: 'model returned no tool call',
        ),
      ],
    );

    final emptySummary = report.summaries.first;
    expect(emptySummary.totalScenarios, 0);
    expect(emptySummary.passRate, 0);
    expect(emptySummary.toolCallMatchRate, 0);
    expect(emptySummary.argumentMatchRate, 0);

    final markdown = report.toMarkdown();
    expect(markdown, contains('| qwen-empty | `not-run` | 0/0 |'));
    expect(markdown, contains('missingToolCall: 1'));
    expect(markdown, contains('## Failures'));
    expect(markdown, contains('model returned no tool call'));
  });
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.model,
    required this.toolNames,
  });

  final String model;
  final List<String> toolNames;
}

class _FakeInferenceRepository extends InferenceRepositoryInterface {
  _FakeInferenceRepository(this.responses, {this.error});

  final List<CreateChatCompletionStreamResponse> responses;
  final Object? error;
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
        model: model,
        toolNames: tools?.map((tool) => tool.function.name).toList() ?? [],
      ),
    );
    final error = this.error;
    if (error != null) {
      return Stream<CreateChatCompletionStreamResponse>.error(error);
    }
    return Stream.fromIterable(responses);
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

CreateChatCompletionStreamResponse _toolCall({
  required String name,
  required String argumentsJson,
}) {
  return CreateChatCompletionStreamResponse(
    id: 'tool',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [
            {
              'index': 0,
              'id': 'call-1',
              'type': 'function',
              'function': {
                'name': name,
                'arguments': argumentsJson,
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

CreateChatCompletionStreamResponse _toolCallChunk({
  required String argumentsJson,
  String? id,
  String? name,
}) {
  final function = <String, Object?>{
    'arguments': argumentsJson,
  };
  if (name != null) {
    function['name'] = name;
  }
  final toolCall = <String, Object?>{
    'index': 0,
    'type': 'function',
    'function': function,
  };
  if (id != null) {
    toolCall['id'] = id;
  }

  return CreateChatCompletionStreamResponse(
    id: 'tool',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [toolCall],
        }),
        index: 0,
      ),
    ],
    object: 'chat.completion.chunk',
    created: 0,
  );
}

CreateChatCompletionStreamResponse _toolCallChunkWithoutFunction() {
  return CreateChatCompletionStreamResponse(
    id: 'tool',
    choices: [
      ChatCompletionStreamResponseChoice(
        delta: ChatCompletionStreamResponseDelta.fromJson({
          'tool_calls': [
            {
              'index': 0,
              'id': 'call-1',
              'type': 'function',
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

CreateChatCompletionStreamResponse _chunkWithoutChoices() {
  return const CreateChatCompletionStreamResponse(
    id: 'empty',
    object: 'chat.completion.chunk',
    created: 0,
  );
}

CreateChatCompletionStreamResponse _usage({
  required int inputTokens,
  required int outputTokens,
}) {
  return CreateChatCompletionStreamResponse(
    id: 'usage',
    choices: const [],
    object: 'chat.completion.chunk',
    created: 0,
    usage: CompletionUsage(
      promptTokens: inputTokens,
      completionTokens: outputTokens,
      totalTokens: inputTokens + outputTokens,
    ),
  );
}
