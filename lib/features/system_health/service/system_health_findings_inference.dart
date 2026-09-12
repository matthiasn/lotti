import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:openai_dart/openai_dart.dart';

/// Signature the analyzer uses to obtain findings from a model.
///
/// Kept as a plain function type so the analyzer can be tested with a stub,
/// and so a future scheduler can wire a different writer without touching
/// the analysis.
typedef SystemHealthFindingsWriter =
    Future<String> Function({
      required String systemMessage,
      required String prompt,
      required AiConfigModel model,
    });

/// Runs one text-generation call against the model the user picked.
///
/// Resolves the model's provider, streams the completion through the AI
/// consumption capture when it is registered (so the run shows up in usage
/// attribution as a manual text generation), and returns the accumulated
/// text. Throws [StateError] when the provider is missing or has no key.
class SystemHealthFindingsInference {
  const SystemHealthFindingsInference({
    required this.inferenceRepository,
    required this.aiConfigRepository,
  });

  final CloudInferenceRepository inferenceRepository;
  final AiConfigRepository aiConfigRepository;

  static const double _temperature = 0.2;
  static const int _maxCompletionTokens = 2048;

  Future<String> write({
    required String systemMessage,
    required String prompt,
    required AiConfigModel model,
  }) async {
    final config = await aiConfigRepository.getConfigById(
      model.inferenceProviderId,
    );
    final provider = config is AiConfigInferenceProvider ? config : null;
    if (provider == null || !provider.isUsable) {
      throw StateError(
        'inference provider for ${model.name} is missing or has no API key',
      );
    }

    final impactCollector = InferenceImpactCollector();
    Stream<CreateChatCompletionStreamResponse> invoke() =>
        inferenceRepository.generate(
          prompt,
          model: model.providerModelId,
          temperature: _temperature,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          systemMessage: systemMessage,
          maxCompletionTokens: _maxCompletionTokens,
          provider: provider,
          geminiThinkingMode: model.geminiThinkingMode,
          impactCollector: impactCollector,
        );

    final stream = getIt.isRegistered<AiInteractionCapture>()
        ? getIt<AiInteractionCapture>().captureStream(
            workType: AiWorkType.textGeneration,
            interactionKind: AiInteractionKind.textGeneration,
            responseType: AiConsumptionResponseType.textGeneration,
            providerType: provider.inferenceProviderType,
            modelId: model.providerModelId,
            requestText: prompt,
            invoke: invoke,
            responseText: (chunk) =>
                chunk.choices?.firstOrNull?.delta?.content ?? '',
            usageForChunk: (chunk) {
              final usage = chunk.usage;
              if (usage == null) return null;
              return AiCapturedUsage(
                inputTokens: usage.promptTokens,
                outputTokens: usage.completionTokens,
                cachedInputTokens: usage.promptTokensDetails?.cachedTokens,
                thoughtsTokens: usage.completionTokensDetails?.reasoningTokens,
                totalTokens: usage.totalTokens,
              );
            },
            impact: () => impactCollector.impact,
          )
        : invoke();

    final buffer = StringBuffer();
    await for (final response in stream) {
      final content = response.choices?.firstOrNull?.delta?.content;
      if (content != null) buffer.write(content);
    }
    return buffer.toString();
  }
}
