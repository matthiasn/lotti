import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/providers/gemini_inference_repository_provider.dart';
import 'package:lotti/features/ai/providers/ollama_inference_repository_provider.dart';
import 'package:lotti/features/ai/repository/cloud_inference_generate.dart';
import 'package:lotti/features/ai/repository/cloud_inference_generate_more.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/dashscope_inference_repository.dart';
import 'package:lotti/features/ai/repository/gemini_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_inference_repository.dart';
import 'package:lotti/features/ai/repository/mistral_transcription_repository.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/repository/voxtral_inference_repository.dart';
import 'package:lotti/features/ai/repository/whisper_inference_repository.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_repository.g.dart';

/// Facade over the cloud-inference generate collaborators.
///
/// Owns a [Ref] plus the provider-/HTTP-backed sub-repositories and wires them
/// into two stateless collaborators — [CloudInferenceGenerate] (text/image
/// prompts) and [CloudInferenceGenerateMore] (audio, multi-turn, image
/// generation, model install, cleanup) — sharing a single
/// [CloudInferenceRequestHelpers]. Every public method delegates to the owning
/// collaborator so the mockable surface and all call sites stay unchanged.
class CloudInferenceRepository {
  CloudInferenceRepository(this.ref, {http.Client? httpClient}) {
    final ollamaRepository = ref.read(ollamaInferenceRepositoryProvider);
    final geminiRepository = ref.read(geminiInferenceRepositoryProvider);
    final dashScopeRepository = ref.read(dashScopeInferenceRepositoryProvider);
    final mistralRepository = MistralInferenceRepository(
      httpClient: httpClient,
    );
    final mistralTranscriptionRepository = MistralTranscriptionRepository(
      httpClient: httpClient,
    );
    final whisperRepository = WhisperInferenceRepository(
      httpClient: httpClient,
    );
    final voxtralRepository = VoxtralInferenceRepository(
      httpClient: httpClient,
    );
    final openAiTranscriptionRepository = OpenAiTranscriptionRepository(
      httpClient: httpClient,
    );

    const helpers = CloudInferenceRequestHelpers();

    _generate = CloudInferenceGenerate(
      ollamaRepository: ollamaRepository,
      geminiRepository: geminiRepository,
      mistralRepository: mistralRepository,
      helpers: helpers,
    );

    _generateMore = CloudInferenceGenerateMore(
      ref: ref,
      ollamaRepository: ollamaRepository,
      geminiRepository: geminiRepository,
      dashScopeRepository: dashScopeRepository,
      mistralRepository: mistralRepository,
      mistralTranscriptionRepository: mistralTranscriptionRepository,
      whisperRepository: whisperRepository,
      voxtralRepository: voxtralRepository,
      openAiTranscriptionRepository: openAiTranscriptionRepository,
      helpers: helpers,
    );
  }

  final Ref ref;
  late final CloudInferenceGenerate _generate;
  late final CloudInferenceGenerateMore _generateMore;

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
  }) => _generate.generate(
    prompt,
    model: model,
    temperature: temperature,
    baseUrl: baseUrl,
    apiKey: apiKey,
    systemMessage: systemMessage,
    maxCompletionTokens: maxCompletionTokens,
    overrideClient: overrideClient,
    provider: provider,
    tools: tools,
    toolChoice: toolChoice,
    geminiThinkingMode: geminiThinkingMode,
  );

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
  }) => _generate.generateWithImages(
    prompt,
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    temperature: temperature,
    images: images,
    maxCompletionTokens: maxCompletionTokens,
    overrideClient: overrideClient,
    provider: provider,
    tools: tools,
    systemMessage: systemMessage,
    geminiThinkingMode: geminiThinkingMode,
  );

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
  }) => _generateMore.generateWithAudio(
    prompt,
    model: model,
    audioBase64: audioBase64,
    baseUrl: baseUrl,
    apiKey: apiKey,
    provider: provider,
    maxCompletionTokens: maxCompletionTokens,
    overrideClient: overrideClient,
    tools: tools,
    stream: stream,
    audioFormat: audioFormat,
    speechDictionaryTerms: speechDictionaryTerms,
    systemMessage: systemMessage,
    geminiThinkingMode: geminiThinkingMode,
  );

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
  }) => _generateMore.generateWithMessages(
    messages: messages,
    model: model,
    temperature: temperature,
    provider: provider,
    maxCompletionTokens: maxCompletionTokens,
    tools: tools,
    toolChoice: toolChoice,
    thoughtSignatures: thoughtSignatures,
    signatureCollector: signatureCollector,
    turnIndex: turnIndex,
    geminiThinkingMode: geminiThinkingMode,
  );

  /// Install a model in Ollama with progress tracking
  Stream<OllamaPullProgress> installModel(String modelName, String baseUrl) =>
      _generateMore.installModel(modelName, baseUrl);

  /// Generates an image using a provider-specific image generation API.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    String? systemMessage,
    List<ProcessedReferenceImage>? referenceImages,
  }) => _generateMore.generateImage(
    prompt: prompt,
    model: model,
    provider: provider,
    systemMessage: systemMessage,
    referenceImages: referenceImages,
  );

  /// Closes HTTP clients held by sub-repositories that this instance owns.
  void close() => _generateMore.close();
}

@riverpod
CloudInferenceRepository cloudInferenceRepository(Ref ref) {
  final repo = CloudInferenceRepository(ref);
  ref.onDispose(repo.close);
  return repo;
}
