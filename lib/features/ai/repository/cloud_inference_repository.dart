import 'dart:async';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/ai_inference_client.dart';
import 'package:lotti/features/ai/repository/dashscope_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'cloud_inference_repository.g.dart';

class CloudInferenceRepository {
  CloudInferenceRepository(this.ref, {http.Client? httpClient})
    : _ollamaRepository = ref.read(ollamaInferenceRepositoryProvider),
      _geminiRepository = ref.read(geminiInferenceRepositoryProvider),
      _dashScopeRepository = ref.read(dashScopeInferenceRepositoryProvider),
      _mistralRepository = MistralInferenceRepository(httpClient: httpClient),
      _mistralTranscriptionRepository = MistralTranscriptionRepository(
        httpClient: httpClient,
      ),
      _whisperRepository = WhisperInferenceRepository(httpClient: httpClient),
      _voxtralRepository = VoxtralInferenceRepository(httpClient: httpClient),
      _openAiTranscriptionRepository = OpenAiTranscriptionRepository(
        httpClient: httpClient,
      );

  final Ref ref;
  final OllamaInferenceRepository _ollamaRepository;
  final GeminiInferenceRepository _geminiRepository;
  final DashScopeInferenceRepository _dashScopeRepository;
  final MistralInferenceRepository _mistralRepository;
  final MistralTranscriptionRepository _mistralTranscriptionRepository;
  final WhisperInferenceRepository _whisperRepository;
  final VoxtralInferenceRepository _voxtralRepository;
  final OpenAiTranscriptionRepository _openAiTranscriptionRepository;

  /// Resolves the effective tool-choice policy. When [toolChoice] is null we
  /// default to `auto` if tools are provided, otherwise leave unset.
  AiToolChoice? _resolveToolChoice(
    AiToolChoice? toolChoice,
    List<AiTool>? tools,
  ) {
    if (toolChoice != null) return toolChoice;
    if (tools != null && tools.isNotEmpty) return const AiToolChoiceAuto();
    return null;
  }

  Stream<AiStreamChunk> generate(
    String prompt, {
    required String model,
    required double? temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    AiInferenceClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<AiTool>? tools,
    AiToolChoice? toolChoice,
    GeminiThinkingMode? geminiThinkingMode,
  }) {
    developer.log(
      'CloudInferenceRepository.generate called with:\n'
      '  model: $model\n'
      '  provider: ${provider?.inferenceProviderType}\n'
      '  tools: ${tools?.length ?? 0} - ${tools?.map((t) => t.name).join(', ') ?? 'none'}\n'
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
      );
    }

    final client =
        overrideClient ?? AiInferenceClient(baseUrl: baseUrl, apiKey: apiKey);

    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to OpenAI API: ${tools.map((t) => t.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    return client
        .chatCompletionsStream(
          messages: [
            if (systemMessage != null) AiSystemMessage(systemMessage),
            AiUserMessage(AiUserTextContent(prompt)),
          ],
          model: model,
          temperature: temperature,
          maxCompletionTokens: maxCompletionTokens,
          tools: tools,
          toolChoice: _resolveToolChoice(toolChoice, tools),
        )
        .asBroadcastStream();
  }

  Stream<AiStreamChunk> generateWithImages(
    String prompt, {
    required String baseUrl,
    required String apiKey,
    required String model,
    required double? temperature,
    required List<String> images,
    int? maxCompletionTokens,
    AiInferenceClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<AiTool>? tools,
    String? systemMessage,
    GeminiThinkingMode? geminiThinkingMode,
  }) {
    final client =
        overrideClient ?? AiInferenceClient(baseUrl: baseUrl, apiKey: apiKey);

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
        'Passing ${tools.length} tools to image API: ${tools.map((t) => t.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    return client
        .chatCompletionsStream(
          messages: [
            if (systemMessage != null) AiSystemMessage(systemMessage),
            AiUserMessage(
              AiUserPartsContent([
                AiTextPart(prompt),
                ...images.map(
                  (image) => AiImagePart('data:image/jpeg;base64,$image'),
                ),
              ]),
            ),
          ],
          model: model,
          temperature: temperature,
          maxTokens: maxCompletionTokens,
          tools: tools,
          toolChoice: _resolveToolChoice(null, tools),
          reasoningEffort: reasoningEffort,
        )
        .asBroadcastStream();
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
  Stream<AiStreamChunk> generateWithAudio(
    String prompt, {
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    AiInferenceClient? overrideClient,
    List<AiTool>? tools,
    bool stream = true,
    AiAudioFormat audioFormat = AiAudioFormat.mp3,
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
              (result) => AiStreamChunk(
                id: 'mlx-audio-${const Uuid().v4()}',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(content: result.text),
                  ),
                ],
                created: 0,
              ),
            ),
      );
    }

    final client =
        overrideClient ?? AiInferenceClient(baseUrl: baseUrl, apiKey: apiKey);

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

    // For all other providers (OpenAI chat models, Gemini, etc.), use the
    // standard OpenAI-compatible chat completions format with audio content
    // parts.
    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to audio API: ${tools.map((t) => t.name).join(', ')}',
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
        .chatCompletionsStream(
          messages: [
            if (systemMessage != null) AiSystemMessage(systemMessage),
            AiUserMessage(
              AiUserPartsContent([
                AiTextPart(prompt),
                AiAudioPart(data: effectiveAudioBase64, format: audioFormat),
              ]),
            ),
          ],
          model: model,
          maxCompletionTokens: maxCompletionTokens,
          tools: tools,
          toolChoice: _resolveToolChoice(null, tools),
          reasoningEffort: reasoningEffort,
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
  ///   to emit it on its own. Currently honored only on the OpenAI-compatible
  ///   branch; the Gemini/Ollama/Mistral sub-repositories ignore it.
  /// - [thoughtSignatures]: Optional signatures from previous turns (Gemini only)
  /// - [signatureCollector]: Optional collector for new signatures (Gemini only)
  /// - [turnIndex]: Current turn number for unique tool call ID generation
  Stream<AiStreamChunk> generateWithMessages({
    required List<AiChatMessage> messages,
    required String model,
    required double? temperature,
    required AiConfigInferenceProvider provider,
    int? maxCompletionTokens,
    List<AiTool>? tools,
    AiToolChoice? toolChoice,
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
          .whereType<AiSystemMessage>()
          .firstOrNull
          ?.content;

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
      );
    }

    // For other providers (OpenAI, OpenRouter, Anthropic), use full message
    // history.
    final client = AiInferenceClient(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
    );

    if (tools != null && tools.isNotEmpty) {
      developer.log(
        'Passing ${tools.length} tools to multi-turn API: ${tools.map((t) => t.name).join(', ')}',
        name: 'CloudInferenceRepository',
      );
    }

    return client
        .chatCompletionsStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxCompletionTokens: maxCompletionTokens,
          tools: tools,
          toolChoice: _resolveToolChoice(toolChoice, tools),
        )
        .asBroadcastStream();
  }

  GeminiThinkingConfig _resolveGeminiThinkingConfig({
    GeminiThinkingMode? mode,
  }) {
    final base = GeminiThinkingConfig.fromMode(
      mode ?? GeminiThinkingMode.low,
    );

    // Always capture thoughts for thinking-capable models (budget != 0) so
    // they're available in the AI response modal's Thoughts tab. The chat UI
    // still decides whether inline thinking is displayed.
    return GeminiThinkingConfig(
      thinkingBudget: base.thinkingBudget,
      thinkingMode: base.thinkingMode,
      includeThoughts: base.thinkingBudget != 0,
    );
  }

  /// Maps a [GeminiThinkingMode] to the OpenAI-compatible `reasoning_effort`
  /// value for [model], collapsing modes that the model does not support
  /// (non-Flash Gemini 3 only accepts low/high) via
  /// [GeminiThinkingConfig.effectiveMode].
  AiReasoningEffort _geminiReasoningEffort(
    String model,
    GeminiThinkingMode mode,
  ) {
    return switch (GeminiThinkingConfig.effectiveMode(model, mode)) {
      GeminiThinkingMode.minimal => AiReasoningEffort.minimal,
      GeminiThinkingMode.low => AiReasoningEffort.low,
      GeminiThinkingMode.medium => AiReasoningEffort.medium,
      GeminiThinkingMode.high => AiReasoningEffort.high,
    };
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

@riverpod
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  final repo = CloudInferenceRepository(ref);
  ref.onDispose(repo.close);
  return repo;
}
