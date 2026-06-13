import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart'
    show CloudInferenceRepository;
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Text and image generation paths for [CloudInferenceRepository].
///
/// Routes the single-prompt `generate` and `generateWithImages` flows to the
/// provider-specific repositories (Ollama, Gemini, Mistral) or, for
/// OpenAI-compatible providers, builds the request via the shared
/// [CloudInferenceRequestHelpers] and streams from an [OpenAIClient].
class CloudInferenceGenerate {
  CloudInferenceGenerate({
    required this._ollamaRepository,
    required this._geminiRepository,
    required this._mistralRepository,
    required this._helpers,
  });

  final OllamaInferenceRepository _ollamaRepository;
  final GeminiInferenceRepository _geminiRepository;
  final MistralInferenceRepository _mistralRepository;
  final CloudInferenceRequestHelpers _helpers;

  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double? temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    GeminiThinkingMode? geminiThinkingMode,
  }) {
    developer.log(
      'CloudInferenceRepository.generate called with:\n'
      '  model: $model\n'
      '  provider: ${provider?.inferenceProviderType}\n'
      '  tools: ${tools?.length ?? 0} - ${tools?.map((t) => t.function.name).join(', ') ?? 'none'}\n'
      '  systemMessage: ${systemMessage != null && systemMessage.length > 100 ? '${systemMessage.substring(0, 100)}...' : systemMessage}',
      name: 'CloudInferenceRepository',
    );

    // For Ollama, use the dedicated repository
    if (provider != null &&
        provider.inferenceProviderType == InferenceProviderType.ollama) {
      return _ollamaRepository.generateText(
        prompt: prompt,
        model: model,
        temperature: temperature ?? 0.7, // Default if not specified
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider,
        tools: tools,
      );
    }

    // For Gemini, use the native Gemini repository to enable thinking config
    if (provider != null &&
        provider.inferenceProviderType == InferenceProviderType.gemini) {
      final finalThinking = _helpers.resolveGeminiThinkingConfig(
        mode: geminiThinkingMode,
      );
      return _geminiRepository.generateText(
        prompt: prompt,
        model: model,
        temperature: temperature ?? 0.7, // Default if not specified
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider,
        tools: tools,
        toolChoice: toolChoice,
        thinkingConfig: finalThinking,
      );
    }

    // For Mistral, use the dedicated repository to handle streaming format differences
    if (provider != null &&
        provider.inferenceProviderType == InferenceProviderType.mistral) {
      return _mistralRepository.generateText(
        prompt: prompt,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        systemMessage: systemMessage,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
      );
    }

    final client =
        overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to OpenAI API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final res = client.createChatCompletionStream(
      request: _helpers.createBaseRequest(
        messages: [
          if (systemMessage != null)
            ChatCompletionMessage.system(content: systemMessage),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(prompt),
          ),
        ],
        model: model,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
      ),
    );

    return _helpers.filterAnthropicPings(res).asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithImages(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required double? temperature,
    required List<String> images,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
    String? systemMessage,
    GeminiThinkingMode? geminiThinkingMode,
  }) {
    final client =
        overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Ollama, use the dedicated repository
    if (provider?.inferenceProviderType == InferenceProviderType.ollama) {
      return _ollamaRepository.generateWithImages(
        prompt: prompt,
        model: model,
        temperature: temperature ?? 0.7, // Default if not specified
        images: images,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider!,
        systemMessage: systemMessage,
      );
    }

    // For other providers, use the standard OpenAI-compatible format
    final reasoningEffort =
        provider?.inferenceProviderType == InferenceProviderType.gemini &&
            GeminiThinkingConfig.isGemini3(model)
        ? _helpers.geminiReasoningEffort(
            model,
            geminiThinkingMode ?? GeminiThinkingMode.low,
          )
        : null;

    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to image API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final res = client.createChatCompletionStream(
      request: _helpers.createBaseRequest(
        messages: [
          if (systemMessage != null)
            ChatCompletionMessage.system(content: systemMessage),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts(
              [
                ChatCompletionMessageContentPart.text(text: prompt),
                ...images.map(
                  (image) {
                    return ChatCompletionMessageContentPart.image(
                      imageUrl: ChatCompletionMessageImageUrl(
                        url: 'data:image/jpeg;base64,$image',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        model: model,
        temperature: temperature,
        maxTokens: maxCompletionTokens,
        tools: tools,
        reasoningEffort: reasoningEffort,
      ),
    );

    return res.asBroadcastStream();
  }
}
