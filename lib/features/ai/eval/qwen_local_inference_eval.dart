import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/ai/eval/qwen_local_eval_config.dart';
import 'package:lotti/features/ai/eval/qwen_local_eval_report.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

export 'package:lotti/features/ai/eval/qwen_local_eval_config.dart';
export 'package:lotti/features/ai/eval/qwen_local_eval_report.dart';

class QwenLocalInferenceEvalRunner {
  QwenLocalInferenceEvalRunner({
    required this.provider,
    required this.repository,
    this.temperature = 0,
    this.maxCompletionTokens = 512,
  });

  final AiConfigInferenceProvider provider;
  final InferenceRepositoryInterface repository;
  final double temperature;
  final int maxCompletionTokens;

  Future<QwenLocalEvalReport> run({
    required List<QwenLocalEvalProfile> profiles,
    required List<QwenLocalEvalScenario> scenarios,
  }) async {
    final results = <QwenLocalEvalCaseResult>[];

    for (final profile in profiles) {
      for (final scenario in scenarios) {
        results.add(await _runScenario(profile, scenario));
      }
    }

    return QwenLocalEvalReport(
      provider: provider,
      scenarios: scenarios,
      profiles: profiles,
      results: results,
    );
  }

  Future<QwenLocalEvalCaseResult> _runScenario(
    QwenLocalEvalProfile profile,
    QwenLocalEvalScenario scenario,
  ) async {
    final stopwatch = Stopwatch()..start();
    final content = StringBuffer();
    final toolCalls = <ChatCompletionMessageToolCall>[];
    final argumentBuffers = <String, StringBuffer>{};
    CompletionUsage? usage;

    try {
      await for (final response in repository.generateTextWithMessages(
        messages: [
          ChatCompletionMessage.system(content: scenario.systemPrompt),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              scenario.userPrompt,
            ),
          ),
        ],
        model: profile.providerModelId,
        provider: provider,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: _toolsForScenario(scenario),
      )) {
        usage = response.usage ?? usage;
        final choices = response.choices ?? const [];
        for (final choice in choices) {
          final delta = choice.delta;
          final deltaContent = delta?.content;
          if (deltaContent != null) {
            content.write(deltaContent);
          }
          final chunks = delta?.toolCalls;
          if (chunks == null || chunks.isEmpty) continue;
          _accumulateToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: argumentBuffers,
            chunks: chunks,
          );
        }
      }

      stopwatch.stop();
      final evalToolCalls = toolCalls
          .map(
            (call) => QwenLocalEvalToolCall(
              name: call.function.name,
              argumentsJson: call.function.arguments,
            ),
          )
          .toList(growable: false);
      return QwenLocalEvalCaseResult(
        profile: profile,
        scenario: scenario,
        provider: provider,
        latencyMs: stopwatch.elapsedMilliseconds,
        contentLength: content.length,
        inputTokens: usage?.promptTokens,
        outputTokens: usage?.completionTokens,
        toolCalls: evalToolCalls,
        failureCategory: _classifyResult(
          scenario: scenario,
          contentLength: content.length,
          toolCalls: evalToolCalls,
        ),
      );
    } catch (error) {
      stopwatch.stop();
      return QwenLocalEvalCaseResult(
        profile: profile,
        scenario: scenario,
        provider: provider,
        latencyMs: stopwatch.elapsedMilliseconds,
        contentLength: content.length,
        inputTokens: usage?.promptTokens,
        outputTokens: usage?.completionTokens,
        toolCalls: const [],
        failureCategory: QwenLocalEvalFailureCategory.requestFailed,
        errorMessage: _compactError(error),
      );
    }
  }
}

void _accumulateToolCallChunks({
  required List<ChatCompletionMessageToolCall> toolCalls,
  required Map<String, StringBuffer> argumentBuffers,
  required List<ChatCompletionStreamMessageToolCallChunk> chunks,
}) {
  for (final chunk in chunks) {
    var existingIndex = -1;
    if (chunk.id != null && chunk.id!.isNotEmpty) {
      existingIndex = toolCalls.indexWhere((call) => call.id == chunk.id);
    }
    if (existingIndex < 0 && chunk.index != null) {
      final chunkIndex = chunk.index!;
      if (chunkIndex < toolCalls.length) existingIndex = chunkIndex;
    }

    if (existingIndex >= 0) {
      final existing = toolCalls[existingIndex];
      final updatedName = chunk.function?.name;
      final buffer =
          argumentBuffers[existing.id] ??
          StringBuffer(existing.function.arguments);
      argumentBuffers[existing.id] = buffer;
      buffer.write(chunk.function?.arguments ?? '');
      toolCalls[existingIndex] = ChatCompletionMessageToolCall(
        id: existing.id,
        type: existing.type,
        function: ChatCompletionMessageFunctionCall(
          name: updatedName != null && updatedName.isNotEmpty
              ? updatedName
              : existing.function.name,
          arguments: buffer.toString(),
        ),
      );
    } else if (chunk.function != null) {
      final toolCallId = chunk.id ?? 'tool_${chunk.index ?? toolCalls.length}';
      final arguments = chunk.function!.arguments ?? '';
      argumentBuffers[toolCallId] = StringBuffer(arguments);
      toolCalls.add(
        ChatCompletionMessageToolCall(
          id: toolCallId,
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: chunk.function!.name ?? '',
            arguments: arguments,
          ),
        ),
      );
    }
  }
}

QwenLocalEvalFailureCategory _classifyResult({
  required QwenLocalEvalScenario scenario,
  required int contentLength,
  required List<QwenLocalEvalToolCall> toolCalls,
}) {
  final expectedToolName = scenario.expectedToolName;
  if (expectedToolName != null) {
    if (toolCalls.isEmpty) return QwenLocalEvalFailureCategory.missingToolCall;
    final matchingCalls = toolCalls
        .where((call) => call.name == expectedToolName)
        .toList(growable: false);
    if (matchingCalls.isEmpty) {
      return QwenLocalEvalFailureCategory.wrongToolCall;
    }
    if (matchingCalls.any((call) => !call.hasJsonObjectArguments)) {
      return QwenLocalEvalFailureCategory.invalidToolArguments;
    }
    if (scenario.expectsArguments &&
        !matchingCalls.any(
          (call) => call.containsExpectedArguments(
            scenario.expectedArgumentsSubset,
          ),
        )) {
      return QwenLocalEvalFailureCategory.argumentMismatch;
    }
  }

  if (contentLength == 0 && toolCalls.isEmpty) {
    return QwenLocalEvalFailureCategory.emptyResponse;
  }
  return QwenLocalEvalFailureCategory.none;
}

List<ChatCompletionTool> _toolsForScenario(QwenLocalEvalScenario scenario) {
  final byName = {
    for (final definition in AgentToolRegistry.taskAgentTools)
      if (definition.enabled) definition.name: definition,
  };

  return scenario.exposedToolNames
      .map((name) {
        final definition = byName[name];
        if (definition == null) {
          throw StateError('Unknown enabled task-agent tool "$name".');
        }
        return ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: definition.name,
            description: definition.description,
            parameters: definition.parameters,
          ),
        );
      })
      .toList(growable: false);
}

String _compactError(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 240) return text;
  return '${text.substring(0, 240)}...';
}
