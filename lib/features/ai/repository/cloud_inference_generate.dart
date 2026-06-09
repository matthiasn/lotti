part of 'cloud_inference_repository.dart';

mixin _CloudInferenceGenerate on _CloudInferenceRepositoryBase {
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
      final finalThinking = _resolveGeminiThinkingConfig(
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
        toolChoice: toolChoice,
      ),
    );

    return _filterAnthropicPings(res).asBroadcastStream();
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
        ? _geminiReasoningEffort(
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
      request: _createBaseRequest(
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
  ///   audioFormat: The actual format of the audio data (wav or mp3).
  ///     Required for Mistral/OpenAI chat completions. Defaults to mp3.
  ///
  /// Returns:
  ///   Stream of chat completion responses
}
