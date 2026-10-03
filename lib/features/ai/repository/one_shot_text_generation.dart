import 'package:collection/collection.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

/// Why a one-shot generation ran, for the AI consumption ledger.
class OneShotGenerationAttribution {
  const OneShotGenerationAttribution({
    required this.workType,
    this.triggerType = AiTriggerType.manual,
    this.automationId,
    this.automationDisplayName,
    this.interactionContext,
    this.categoryId,
    this.taskId,
  });

  final AiWorkType workType;
  final AiTriggerType triggerType;

  /// Stable id of the automation that asked, e.g. `automation:daily-os-…`.
  final String? automationId;
  final String? automationDisplayName;
  final AiCapturedContext? interactionContext;

  /// The category and task the call works for, so the ledger can attribute
  /// its cost to them.
  final String? categoryId;
  final String? taskId;
}

/// One prompt in, one block of text out — the shape every non-conversational
/// text call in the app shares (summaries, digests, notes) — or one pinned
/// tool call out, for an answer with typed parts.
///
/// The call is recorded through [AiInteractionCapture] when it is registered,
/// so its tokens and cost land in the consumption ledger under the given
/// attribution.
extension OneShotTextGeneration on CloudInferenceRepository {
  /// Streams one completion of [prompt] and returns its trimmed text, which
  /// may be empty — callers decide whether an empty answer is an error. A
  /// null [maxCompletionTokens] leaves the limit to the provider.
  Future<String> generateText({
    required String prompt,
    required String systemMessage,
    required String model,
    required AiConfigInferenceProvider provider,
    required double temperature,
    required int? maxCompletionTokens,
    required OneShotGenerationAttribution attribution,
    GeminiThinkingMode? geminiThinkingMode,
    ReasoningEffort? reasoningEffort,
  }) async {
    final buffer = StringBuffer();
    await for (final response in _captured(
      prompt: prompt,
      systemMessage: systemMessage,
      model: model,
      provider: provider,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      attribution: attribution,
      geminiThinkingMode: geminiThinkingMode,
      reasoningEffort: reasoningEffort,
    )) {
      final content = response.choices?.firstOrNull?.delta?.content;
      if (content != null) buffer.write(content);
    }
    return buffer.toString().trim();
  }

  /// Streams one completion of [prompt] offered only [tools], pinned with
  /// [toolChoice] where the model honours a pin, and returns the tool calls
  /// it made with whatever text came alongside. Decoding and validating the
  /// calls is the caller's; an empty list means the model answered in prose.
  Future<({String content, List<ChatCompletionMessageToolCall> toolCalls})>
  generateToolCalls({
    required String prompt,
    required String systemMessage,
    required String model,
    required AiConfigInferenceProvider provider,
    required double temperature,
    required int? maxCompletionTokens,
    required OneShotGenerationAttribution attribution,
    required List<ChatCompletionTool> tools,
    ChatCompletionToolChoiceOption? toolChoice,
    GeminiThinkingMode? geminiThinkingMode,
    ReasoningEffort? reasoningEffort,
  }) async {
    final buffer = StringBuffer();
    final calls = ToolCallAccumulator();
    await for (final response in _captured(
      prompt: prompt,
      systemMessage: systemMessage,
      model: model,
      provider: provider,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      attribution: attribution,
      geminiThinkingMode: geminiThinkingMode,
      reasoningEffort: reasoningEffort,
      tools: tools,
      toolChoice: toolChoice,
    )) {
      final delta = response.choices?.firstOrNull?.delta;
      final content = delta?.content;
      if (content != null) buffer.write(content);
      calls.processChunk(delta);
    }
    return (content: buffer.toString().trim(), toolCalls: calls.toToolCalls());
  }

  /// The completion stream, recorded in the consumption ledger when the
  /// capture is registered.
  Stream<CreateChatCompletionStreamResponse> _captured({
    required String prompt,
    required String systemMessage,
    required String model,
    required AiConfigInferenceProvider provider,
    required double temperature,
    required int? maxCompletionTokens,
    required OneShotGenerationAttribution attribution,
    required GeminiThinkingMode? geminiThinkingMode,
    required ReasoningEffort? reasoningEffort,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
  }) {
    final capture = getIt.isRegistered<AiInteractionCapture>()
        ? getIt<AiInteractionCapture>()
        : null;
    final impactCollector = InferenceImpactCollector();
    Stream<CreateChatCompletionStreamResponse> invoke() => generate(
      prompt,
      model: model,
      temperature: temperature,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      systemMessage: systemMessage,
      maxCompletionTokens: maxCompletionTokens,
      provider: provider,
      tools: tools,
      toolChoice: toolChoice,
      geminiThinkingMode: geminiThinkingMode,
      reasoningEffort: reasoningEffort,
      impactCollector: capture == null ? null : impactCollector,
    );
    return capture == null
        ? invoke()
        : capture.captureStream(
            workType: attribution.workType,
            interactionKind: AiInteractionKind.textGeneration,
            responseType: AiConsumptionResponseType.textGeneration,
            providerType: provider.inferenceProviderType,
            modelId: model,
            requestText: prompt,
            invoke: invoke,
            responseText: (chunk) =>
                chunk.choices?.firstOrNull?.delta?.content ?? '',
            usageForChunk: _usage,
            impact: () => impactCollector.impact,
            triggerType: attribution.triggerType,
            automationId: attribution.automationId,
            automationDisplayName: attribution.automationDisplayName,
            interactionContext: attribution.interactionContext,
            categoryId: attribution.categoryId,
            taskId: attribution.taskId,
          );
  }
}

AiCapturedUsage? _usage(CreateChatCompletionStreamResponse chunk) {
  final usage = chunk.usage;
  if (usage == null) return null;
  return AiCapturedUsage(
    inputTokens: usage.promptTokens,
    outputTokens: usage.completionTokens,
    cachedInputTokens: usage.promptTokensDetails?.cachedTokens,
    thoughtsTokens: usage.completionTokensDetails?.reasoningTokens,
    totalTokens: usage.totalTokens,
  );
}
