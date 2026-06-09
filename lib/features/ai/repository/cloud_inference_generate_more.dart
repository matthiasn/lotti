part of 'cloud_inference_repository.dart';

mixin _CloudInferenceGenerateMore on _CloudInferenceRepositoryBase {
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
    bool stream = true,
    ChatCompletionMessageInputAudioFormat audioFormat =
        ChatCompletionMessageInputAudioFormat.mp3,
    List<String>? speechDictionaryTerms,
    String? systemMessage,
    GeminiThinkingMode? geminiThinkingMode,
  }) {
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

    // For MLX Audio, stay inside the app process through the native Swift
    // bridge. The bridge reports unsupported on x86 macOS and on platforms
    // where the Swift SDK is not linked.
    if (provider.inferenceProviderType == InferenceProviderType.mlxAudio) {
      return Stream.fromFuture(
        ref
            .read(mlxAudioChannelProvider)
            .transcribeBase64Audio(
              modelId: model,
              audioBase64: audioBase64,
              speechDictionaryTerms: speechDictionaryTerms ?? const [],
              enableSpeakerDiarization: true,
            )
            .then(
              (result) => CreateChatCompletionStreamResponse(
                id: 'mlx-audio-${const Uuid().v4()}',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    delta: ChatCompletionStreamResponseDelta(
                      content: result.text,
                    ),
                    index: 0,
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 0,
              ),
            ),
      );
    }

    final client =
        overrideClient ??
        OpenAIClient(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

    // For Voxtral, use the dedicated repository
    if (provider.inferenceProviderType == InferenceProviderType.voxtral) {
      return _voxtralRepository.transcribeAudio(
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        prompt: prompt,
        maxCompletionTokens: maxCompletionTokens,
        stream: stream,
      );
    }

    // For OpenAI transcription models (gpt-4o-transcribe), use the dedicated
    // transcription repository. These models require the /v1/audio/transcriptions
    // endpoint, not chat completions. The app records in M4A format which OpenAI
    // accepts directly - no conversion needed.
    if (provider.inferenceProviderType == InferenceProviderType.openAi &&
        OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(model)) {
      developer.log(
        'Using OpenAI transcription endpoint for model: $model',
        name: 'CloudInferenceRepository',
      );
      return _openAiTranscriptionRepository.transcribeAudio(
        model: model,
        audioBase64: audioBase64,
        apiKey: apiKey,
        prompt: prompt,
      );
    }

    // For Mistral transcription models, use the dedicated transcription endpoint.
    // Mistral's /v1/audio/transcriptions accepts M4A natively via multipart.
    if (provider.inferenceProviderType == InferenceProviderType.mistral &&
        MistralTranscriptionRepository.isMistralTranscriptionModel(model)) {
      developer.log(
        'Using Mistral transcription endpoint for model: $model',
        name: 'CloudInferenceRepository',
      );
      return _mistralTranscriptionRepository.transcribeAudio(
        model: model,
        audioBase64: audioBase64,
        baseUrl: baseUrl,
        apiKey: apiKey,
        contextBias: speechDictionaryTerms,
      );
    }

    // For all other providers (OpenAI chat models, Gemini, etc.), use the standard
    // OpenAI-compatible chat completions format with audio content parts.
    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to audio API: ${tools.map((t) => t.function.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    final effectiveAudioBase64 =
        provider.inferenceProviderType.requiresDataUriForAudio
        ? 'data:;base64,$audioBase64'
        : audioBase64;
    final reasoningEffort =
        provider.inferenceProviderType == InferenceProviderType.gemini &&
            GeminiThinkingConfig.isGemini3(model)
        ? _geminiReasoningEffort(
            model,
            geminiThinkingMode ?? GeminiThinkingMode.low,
          )
        : null;

    return client
        .createChatCompletionStream(
          request: _createBaseRequest(
            messages: [
              if (systemMessage != null)
                ChatCompletionMessage.system(content: systemMessage),
              ChatCompletionMessage.user(
                content: ChatCompletionUserMessageContent.parts(
                  [
                    ChatCompletionMessageContentPart.text(text: prompt),
                    ChatCompletionMessageContentPart.audio(
                      inputAudio: ChatCompletionMessageInputAudio(
                        data: effectiveAudioBase64,
                        format: audioFormat,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            model: model,
            maxCompletionTokens: maxCompletionTokens,
            tools: tools,
            reasoningEffort: reasoningEffort,
            stream: stream,
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
  /// - [toolChoice]: Optional override of the tool-selection policy. When
  ///   provided, it replaces the default `auto` behavior — useful for forcing
  ///   a terminal tool call (e.g. `update_report`) when a weaker model failed
  ///   to emit it on its own. Honored by Gemini and the OpenAI-compatible
  ///   branch; Ollama ignores it.
  /// - [thoughtSignatures]: Optional signatures from previous turns (Gemini only)
  /// - [signatureCollector]: Optional collector for new signatures (Gemini only)
  /// - [turnIndex]: Current turn number for unique tool call ID generation
  Stream<CreateChatCompletionStreamResponse> generateWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required double? temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    Map<String, String>? thoughtSignatures,
    ThoughtSignatureCollector? signatureCollector,
    int? turnIndex,
    GeminiThinkingMode? geminiThinkingMode,
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
      final finalThinking = _resolveGeminiThinkingConfig(
        mode: geminiThinkingMode,
      );

      // Extract system message from messages if present
      final systemMessage = messages
          .firstWhereOrNull((m) => m.role == ChatCompletionMessageRole.system)
          ?.mapOrNull(system: (s) => s.content);

      return _geminiRepository.generateTextWithMessages(
        messages: messages,
        model: model,
        temperature: temperature ?? 0.7, // Default if not specified
        thinkingConfig: finalThinking,
        provider: provider,
        thoughtSignatures: thoughtSignatures,
        systemMessage: systemMessage,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
        signatureCollector: signatureCollector,
        turnIndex: turnIndex,
      );
    }

    // For Ollama, use the dedicated repository
    if (provider.inferenceProviderType == InferenceProviderType.ollama) {
      return _ollamaRepository.generateTextWithMessages(
        messages: messages,
        model: model,
        temperature: temperature ?? 0.7, // Default if not specified
        provider: provider,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
      );
    }

    // For Mistral, use the dedicated repository to handle streaming format differences
    if (provider.inferenceProviderType == InferenceProviderType.mistral) {
      return _mistralRepository.generateTextWithMessages(
        messages: messages,
        model: model,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
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
        toolChoice: toolChoice,
      ),
    );

    return _filterAnthropicPings(res).asBroadcastStream();
  }

  // Delegate Ollama-specific methods to OllamaInferenceRepository

  /// Install a model in Ollama with progress tracking
  Stream<OllamaPullProgress> installModel(String modelName, String baseUrl) =>
      _ollamaRepository.installModel(modelName, baseUrl);

  // -------------------------------------------------------------------------
  // Image generation
  // -------------------------------------------------------------------------

  /// Generates an image using a provider-specific image generation API.
  ///
  /// Supported providers:
  /// - **Gemini**: Uses Gemini's native image generation API
  /// - **Alibaba**: Uses DashScope's native SSE streaming API (Wan models)
  ///
  /// Parameters:
  /// - [prompt]: The text prompt describing the image to generate.
  /// - [model]: The model ID (e.g., 'models/gemini-3-pro-image-preview').
  /// - [provider]: The inference provider configuration.
  /// - [systemMessage]: Optional system instruction for guiding generation.
  /// - [referenceImages]: Optional list of reference images for visual context.
  ///
  /// Returns a [GeneratedImage] containing the image bytes and MIME type.
  /// Throws an exception if the provider doesn't support image generation.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) async {
    developer.log(
      'CloudInferenceRepository.generateImage called with:\n'
      '  model: $model\n'
      '  provider: ${provider.inferenceProviderType}\n'
      '  promptLength: ${prompt.length}\n'
      '  referenceImages: ${referenceImages?.length ?? 0}',
      name: 'CloudInferenceRepository',
    );

    switch (provider.inferenceProviderType) {
      case InferenceProviderType.gemini:
        return _geminiRepository.generateImage(
          prompt: prompt,
          model: model,
          provider: provider,
          systemMessage: systemMessage,
          referenceImages: referenceImages,
        );
      case InferenceProviderType.alibaba:
        // Note: DashScope's Wan model does not support systemMessage.
        // It supports at most one reference image in interleave mode.
        return _dashScopeRepository.generateImage(
          prompt: prompt,
          model: model,
          provider: provider,
          referenceImages: referenceImages,
        );
      case InferenceProviderType.anthropic:
      case InferenceProviderType.genericOpenAi:
      case InferenceProviderType.mistral:
      case InferenceProviderType.mlxAudio:
      case InferenceProviderType.nebiusAiStudio:
      case InferenceProviderType.openAi:
      case InferenceProviderType.openRouter:
      case InferenceProviderType.ollama:
      case InferenceProviderType.voxtral:
      case InferenceProviderType.whisper:
        throw UnsupportedError(
          'Image generation is not supported for '
          '${provider.inferenceProviderType} providers',
        );
    }
  }

  /// Closes HTTP clients held by sub-repositories that this instance owns.
  ///
  /// Ollama/Gemini/DashScope are sourced from their own providers and are
  /// closed by their own `ref.onDispose` hooks.
  void close() {
    _mistralRepository.close();
    _mistralTranscriptionRepository.close();
    _whisperRepository.close();
    _voxtralRepository.close();
    _openAiTranscriptionRepository.close();
  }
}
