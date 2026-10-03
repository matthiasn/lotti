import 'package:collection/collection.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
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
  });

  final AiWorkType workType;
  final AiTriggerType triggerType;

  /// Stable id of the automation that asked, e.g. `automation:daily-os-…`.
  final String? automationId;
  final String? automationDisplayName;
  final AiCapturedContext? interactionContext;
}

/// One prompt in, one block of text out — the shape every non-conversational
/// text call in the app shares (summaries, digests, notes).
///
/// The call is recorded through [AiInteractionCapture] when it is registered,
/// so its tokens and cost land in the consumption ledger under the given
/// attribution.
extension OneShotTextGeneration on CloudInferenceRepository {
  /// Streams one completion of [prompt] and returns its trimmed text, which
  /// may be empty — callers decide whether an empty answer is an error.
  Future<String> generateText({
    required String prompt,
    required String systemMessage,
    required String model,
    required AiConfigInferenceProvider provider,
    required double temperature,
    required int maxCompletionTokens,
    required OneShotGenerationAttribution attribution,
    GeminiThinkingMode? geminiThinkingMode,
    ReasoningEffort? reasoningEffort,
  }) async {
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
      geminiThinkingMode: geminiThinkingMode,
      reasoningEffort: reasoningEffort,
      impactCollector: capture == null ? null : impactCollector,
    );
    final stream = capture == null
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
          );

    final buffer = StringBuffer();
    await for (final response in stream) {
      final content = response.choices?.firstOrNull?.delta?.content;
      if (content != null) buffer.write(content);
    }
    return buffer.toString().trim();
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
