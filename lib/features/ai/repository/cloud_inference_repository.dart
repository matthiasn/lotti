import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/gemini_thinking_providers.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemma3n_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:lotti/features/ai/util/gemini_config.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository(this.ref, {http.Client? httpClient})
      : _ollamaRepository = ref.read(ollamaInferenceRepositoryProvider),
        _geminiRepository = ref.read(geminiInferenceRepositoryProvider),
        _whisperRepository = WhisperInferenceRepository(httpClient: httpClient),
        _gemma3nRepository = Gemma3nInferenceRepository(httpClient: httpClient);

  final Ref ref;
  final OllamaInferenceRepository _ollamaRepository;
  final GeminiInferenceRepository _geminiRepository;
  final WhisperInferenceRepository _whisperRepository;
  final Gemma3nInferenceRepository _gemma3nRepository;

  /// Helper method to create common request parameters
  CreateChatCompletionRequest _createBaseRequest({
    required List<ChatCompletionMessage> messages,
    required String model,
    double? temperature,
    int? maxCompletionTokens,
    int? maxTokens,
    List<ChatCompletionTool>? tools,
  }) {
    return CreateChatCompletionRequest(
      messages: messages,
      model: ChatCompletionModel.modelId(model),
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      maxTokens: maxTokens,
      stream: true,
      tools: tools,
      toolChoice: tools != null && tools.isNotEmpty
          ? const ChatCompletionToolChoiceOption.mode(
              ChatCompletionToolChoiceMode.auto,
            )
          : null,
    );
  }

  /// Filters out Anthropic ping messages from the stream
  Stream<CreateChatCompletionStreamResponse> _filterAnthropicPings(
    Stream<CreateChatCompletionStreamResponse> stream,
  ) {
    // Use where to filter out errors instead of handleError
    final controller = StreamController<CreateChatCompletionStreamResponse>();

    stream.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) {
        // Check if this is specifically an Anthropic ping message error
        final errorString = error.toString();

        // Anthropic ping messages cause a specific null subtype error when parsing choices
        final isAnthropicPingError = errorString.contains(
                "type 'Null' is not a subtype of type 'List<dynamic>'") &&
            errorString.contains('choices');

        if (isAnthropicPingError) {
          // Log but don't propagate the error
          developer.log(
            'Skipping Anthropic ping message',
            name: 'CloudInferenceRepository',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
        // Propagate other errors
        controller.addError(error, stackTrace);
      },
      onDone: controller.close,
    );

    return controller.stream;
  }

  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
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
        temperature: temperature,
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider,
        tools: tools,
      );
    }

    // For Gemini, use the native Gemini repository to enable thinking config
    if (provider != null &&
        provider.inferenceProviderType == InferenceProviderType.gemini) {
      final thinking = getDefaultThinkingConfig(model);
      // Respect user's "Show reasoning" toggle from UI settings
      final userWantsThoughts = ref.read(geminiIncludeThoughtsProvider);
      // Include thoughts if model supports it AND user has enabled the toggle
      final includeThoughts = thinking.thinkingBudget != 0 && userWantsThoughts;
      final finalThinking = GeminiThinkingConfig(
        thinkingBudget: thinking.thinkingBudget,
        includeThoughts: includeThoughts,
      );
      return _geminiRepository.generateText(
        prompt: prompt,
        model: model,
        temperature: temperature,
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider,
        tools: tools,
        thinkingConfig: finalThinking,
      );
    }

    // For Gemma 3n, use the dedicated repository
    if (provider != null &&
        provider.inferenceProviderType == InferenceProviderType.gemma3n) {
      return _gemma3nRepository.generateText(
        prompt: prompt,
        model: model,
        baseUrl: baseUrl,
        temperature: temperature,
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
      );
    }

    final client = overrideClient ??
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
      request: _createBaseRequest(
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
      ),
    );

    return _filterAnthropicPings(res).asBroadcastStream();
  }

  Stream<CreateChatCompletionStreamResponse> generateWithImages(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required List<String> images,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Ollama, use the dedicated repository
    if (provider?.inferenceProviderType == InferenceProviderType.ollama) {
      return _ollamaRepository.generateWithImages(
        prompt: prompt,
        model: model,
        temperature: temperature,
        images: images,
        maxCompletionTokens: maxCompletionTokens,
        provider: provider!,
      );
    }

    // For other providers, use the standard OpenAI-compatible format
    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to image API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final res = client.createChatCompletionStream(
      request: _createBaseRequest(
        messages: [
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
      ),
    );

    return res.asBroadcastStream();
  }

  /// Generates AI responses with audio input using different providers
  ///
  /// This method handles different inference providers:
  /// - FastWhisper: Uses local FastWhisper server for transcription
  /// - Whisper: Uses OpenAI's Whisper API via our Python proxy server
  /// - Other providers: Uses standard OpenAI-compatible format
  ///
  /// Args:
  ///   prompt: The text prompt to send with the audio
  ///   model: The model identifier to use
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL for the API
  ///   apiKey: The API key for authentication
  ///   provider: The inference provider configuration
  ///   maxCompletionTokens: Maximum tokens for completion
  ///   overrideClient: Optional client override for testing
  ///
  /// Returns:
  ///   Stream of chat completion responses
  Stream<CreateChatCompletionStreamResponse> generateWithAudio(
    String prompt, {
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    List<ChatCompletionTool>? tools,
  }) {
    final client = overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Whisper, use the dedicated repository
    if (provider.inferenceProviderType == InferenceProviderType.whisper) {
      return _whisperRepository.transcribeAudio(
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        prompt: prompt, // Optional parameter
        maxCompletionTokens: maxCompletionTokens,
      );
    }

    // For Gemma 3n, use the dedicated repository
    if (provider.inferenceProviderType == InferenceProviderType.gemma3n) {
      return _gemma3nRepository.transcribeAudio(
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        prompt: prompt,
        maxCompletionTokens: maxCompletionTokens,
      );
    }

    // For other providers, use the standard OpenAI-compatible format
    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to audio API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    return client
        .createChatCompletionStream(
          request: _createBaseRequest(
            messages: [
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.parts(
                  [
                    ChatCompletionMessageContentPart.text(text: prompt),
                    ChatCompletionMessageContentPart.audio(
                      inputAudio: ChatCompletionMessageInputAudio(
                        data: audioBase64,
                        format: ChatCompletionMessageInputAudioFormat.mp3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            model: model,
            maxCompletionTokens: maxCompletionTokens,
            tools: tools,
          ),
        )
        .asBroadcastStream();
  }

  /// Generate with full conversation history for multi-turn interactions.
  ///
  /// This method properly routes to provider-specific multi-turn implementations:
  /// - Gemini: Uses native Gemini API with thought signature support
  /// - Others: Fall back to single-prompt mode (conversation flattened)
  ///
  /// Parameters:
  /// - [messages]: Full conversation history
  /// - [model]: Model ID
  /// - [temperature]: Sampling temperature
  /// - [provider]: Provider configuration
  /// - [tools]: Optional function declarations
  /// - [thoughtSignatures]: Optional signatures from previous turns (Gemini only)
  /// - [signatureCollector]: Optional collector for new signatures (Gemini only)
  Stream<CreateChatCompletionStreamResponse> generateWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
  }) {
    developer.log(
      'CloudInferenceRepository.generateWithMessages called with:\n'
      '  model: $model\n'
      '  provider: ${provider.inferenceProviderType}\n'
      '  messages: ${messages.length}\n'
      '  tools: ${tools?.length ?? 0}\n'
      '  hasSignatures: ${thoughtSignatures?.isNotEmpty ?? false}',
      name: 'CloudInferenceRepository',
    );

    // For Gemini, use the native multi-turn API with signature support
    if (provider.inferenceProviderType == InferenceProviderType.gemini) {
      final thinking = getDefaultThinkingConfig(model);
      // Respect user's "Show reasoning" toggle from UI settings
      final userWantsThoughts = ref.read(geminiIncludeThoughtsProvider);
      // Include thoughts if model supports it AND user has enabled the toggle
      final includeThoughts = thinking.thinkingBudget != 0 && userWantsThoughts;
      final finalThinking = GeminiThinkingConfig(
        thinkingBudget: thinking.thinkingBudget,
        includeThoughts: includeThoughts,
      );

      // Extract system message from messages if present
      String? systemMessage;
      for (final message in messages) {
        if (message.role == ChatCompletionMessageRole.system) {
          message.mapOrNull(
            system: (s) {
              systemMessage = s.content;
            },
          );
          break;
        }
      }

      return _geminiRepository.generateTextWithMessages(
        messages: messages,
        model: model,
        temperature: temperature,
        thinkingConfig: finalThinking,
        provider: provider,
        thoughtSignatures: thoughtSignatures,
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        signatureCollector: signatureCollector,
      );
    }

    // For Ollama, use the dedicated repository
    if (provider.inferenceProviderType == InferenceProviderType.ollama) {
      return _ollamaRepository.generateTextWithMessages(
        messages: messages,
        model: model,
        temperature: temperature,
        provider: provider,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
      );
    }

    // For other providers (OpenAI, OpenRouter, Anthropic), use full message history
    final client = OpenAIClient(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
    );

    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to multi-turn API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final res = client.createChatCompletionStream(
      request: _createBaseRequest(
        messages: messages,
        model: model,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
      ),
    );

    return _filterAnthropicPings(res).asBroadcastStream();
  }

  // Delegate Ollama-specific methods to OllamaInferenceRepository

  /// Install a model in Ollama with progress tracking
  Stream<OllamaPullProgress> installModel(String modelName, String baseUrl) =>
      _ollamaRepository.installModel(modelName, baseUrl);
}

@riverpod
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  return CloudInferenceRepository(ref);
}
