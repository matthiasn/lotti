import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/classes/ai/ai_call_impact.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/audio_transcript_timing.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/completion_usage_parser.dart';
import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';
import 'package:lotti/features/ai/repository/inference_http_exception.dart';
import 'package:lotti/features/ai/repository/model_catalog_mapping.dart';
import 'package:lotti/features/ai/repository/temporary_mp3_chat_audio_transcriber.dart';
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/temporary_mp3_encoder.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'melious_inference_catalog.dart';
part 'melious_inference_transcription.dart';
part 'melious_inference_chat.dart';

/// How this repository names itself in an [InferenceHttpException].
const _exceptionProvider = 'Melious';

typedef MeliousChatCompletionStreamFactory =
    Stream<CreateChatCompletionStreamResponse> Function({
      required String baseUrl,
      required String apiKey,
      required CreateChatCompletionRequest request,
    });

/// Melious.ai inference repository.
///
/// Melious is OpenAI-compatible for chat, vision chat, audio transcription,
/// and image generation, but its `/models?include_meta=true` response carries
/// provider-specific capability metadata. This class keeps that metadata
/// mapping in one place so the settings UI can install dynamic model rows
/// without hard-coding Melious' catalog into the static known-model list.
class MeliousInferenceRepository extends TranscriptionRepository {
  MeliousInferenceRepository({
    required super.domainLogger,
    super.httpClient,
    CloudInferenceRequestHelpers? helpers,
    MeliousChatCompletionStreamFactory? chatCompletionStreamFactory,
    AudioToTemporaryMp3Encoder? audioToTemporaryMp3Encoder,
    Stream<File> Function(Uint8List)? audioSegmentEncoder,
    TemporaryAudioFileReader? temporaryFileReader,
    TemporaryAudioFileDeleter? temporaryFileDeleter,
    Clock? clockSource,
  }) : _helpers = helpers ?? const CloudInferenceRequestHelpers(),
       _chatCompletionStreamFactory =
           chatCompletionStreamFactory ?? _createChatCompletionStream,
       _audioToTemporaryMp3Encoder =
           audioToTemporaryMp3Encoder ?? encodeAudioBytesToTemporaryMp3,
       _audioSegmentEncoder =
           audioSegmentEncoder ?? encodeAudioBytesToTemporaryMp3Segments,
       _temporaryFileReader =
           temporaryFileReader ?? ((file) => file.readAsBytes()),
       _temporaryFileDeleter =
           temporaryFileDeleter ?? ((file) => file.deleteSync()),
       _clock = clockSource ?? clock;

  /// Segments the model-name humanizer keeps upper-case for this provider.
  static const _modelNameAcronyms = {
    'AI',
    'API',
    'ASR',
    'BGE',
    'CO2',
    'GPT',
    'GLM',
    'JSON',
    'LLAMA',
    'MLX',
    'QWEN',
    'STT',
    'TTS',
    'VL',
  };

  /// Melious models that reject a chat completion outright unless
  /// `reasoning_effort` is present in the body.
  ///
  /// Omitting the field — which is what every non-Gemini call site does, since
  /// `CloudInferenceGenerate` only resolves an effort for Gemini 3 — makes
  /// these models answer `400 invalid_request_error` with the misleading text
  /// "The request was rejected as malformed. Check the message format, tools
  /// schema, or response_format". There is nothing wrong with the message
  /// format: a two-field `{model, messages}` body is rejected just the same,
  /// and the identical body succeeds against every other model in the catalog.
  ///
  /// Verified against the live API on 2026-08-26, five consecutive probes per
  /// cell (probe sequentially — concurrent requests produce spurious 400s):
  ///
  /// | model         | absent | none | minimal | low | medium | high |
  /// |---------------|--------|------|---------|-----|--------|------|
  /// | `qwen3.8-27b` | 400    | 200  | 200     | 200 | 200    | 400  |
  /// | `qwen3.8-max` | 400    | 400  | 200     | 200 | 200    | 400  |
  ///
  /// Every other Melious chat model accepts all six, so this stays a narrow
  /// quirk table rather than a blanket policy — forcing an effort on models
  /// that do not need one would silently change their thinking budget.
  ///
  /// The two models differ on `none` — the 27B accepts it, Max rejects it —
  /// but `ReasoningEffort` in openai_dart 0.6.2 is only
  /// `{minimal, low, medium, high}`, so no caller can express `none` and the
  /// distinction is unreachable. Revisit if that enum ever gains the value.
  static const modelsRequiringReasoningEffort = <String>{
    meliousQwen3827BModelId,
    meliousQwen38MaxModelId,
  };

  /// Used when a caller supplied no effort for a model that demands one.
  /// Matches [CloudInferenceRequestHelpers.resolveGeminiThinkingConfig], which
  /// also treats `low` as the app-wide default thinking level.
  static const ReasoningEffort _defaultRequiredReasoningEffort =
      ReasoningEffort.low;

  /// The strongest effort the models in [modelsRequiringReasoningEffort]
  /// accept; `high` is rejected as malformed.
  static const ReasoningEffort _maxRequiredReasoningEffort =
      ReasoningEffort.medium;

  /// Resolves the `reasoning_effort` to send for [model].
  ///
  /// Returns [requested] unchanged for models without the quirk, so nothing
  /// else in the catalog changes behaviour. For a quirked model it supplies
  /// [_defaultRequiredReasoningEffort] when the caller asked for nothing, and
  /// clamps `high` down to [_maxRequiredReasoningEffort] rather than letting
  /// the request fail. Idempotent, so applying it twice on one path is safe.
  static ReasoningEffort? resolveReasoningEffort(
    String model,
    ReasoningEffort? requested,
  ) {
    if (!modelsRequiringReasoningEffort.contains(model.trim())) {
      return requested;
    }
    if (requested == null) return _defaultRequiredReasoningEffort;
    if (requested == ReasoningEffort.high) return _maxRequiredReasoningEffort;
    return requested;
  }

  /// Avoids Melious' broken forced-tool mode for DeepSeek V4.1 Flash.
  ///
  /// Live text and image probes on 2026-09-12 returned literal DSML with
  /// `true` instead of arguments for named and `required` choices; `auto`
  /// returned structured calls. Only relax a named choice when the advertised
  /// tool list already contains exactly that tool, so no other tool becomes
  /// callable. Callers must still validate the result: `auto` permits prose.
  /// Other models and unconstrained agent conversations retain their choices.
  static ChatCompletionToolChoiceOption? resolveToolChoice(
    String model,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? requested,
  ) {
    if (model.trim() == meliousDeepseekV41FlashModelId &&
        tools != null &&
        tools.length == 1 &&
        requested
            is ChatCompletionToolChoiceOptionChatCompletionNamedToolChoice &&
        requested.value.function.name == tools.single.function.name) {
      return const ChatCompletionToolChoiceOption.mode(
        ChatCompletionToolChoiceMode.auto,
      );
    }
    return requested;
  }

  static const _providerName = 'MeliousInferenceRepository';
  static const _modelListTimeout = Duration(seconds: 15);
  static const _imageGenerationTimeout = Duration(seconds: 180);
  // Generous because the non-streaming impact path buffers the entire
  // response: nothing is emitted (and no onProgress fires) until the full
  // body arrives or this timeout trips.
  static const _chatCompletionTimeout = Duration(seconds: 300);
  static const _imageGenerationWidth = 1792;
  static const _imageGenerationHeight = 1008;

  /// Cap on speech-dictionary terms forwarded to `/audio/transcriptions`,
  /// mirroring the Mistral `context_bias` limit so a huge dictionary keeps
  /// its leading (most useful) terms instead of ballooning the bias prompt.
  static const _maxContextBiasTerms = 100;

  final CloudInferenceRequestHelpers _helpers;
  final MeliousChatCompletionStreamFactory _chatCompletionStreamFactory;

  /// Provider-documented multipart file limit, in bytes.
  static const maxTranscriptionUploadBytes = 25000000;

  final Stream<File> Function(Uint8List) _audioSegmentEncoder;
  final AudioToTemporaryMp3Encoder _audioToTemporaryMp3Encoder;
  final TemporaryAudioFileReader _temporaryFileReader;
  final TemporaryAudioFileDeleter _temporaryFileDeleter;
  final Clock _clock;

  /// Fetches the live Melious model catalog and maps `_meta` capability data
  /// into the app's [KnownModel] shape.
  Future<List<KnownModel>> listModels({
    required String baseUrl,
    required String apiKey,
    Duration timeout = _modelListTimeout,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (normalizedApiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    try {
      return await _listModelsFromEndpoint(
        baseUrl: normalizedBaseUrl,
        apiKey: normalizedApiKey,
        includeMeta: true,
        timeout: timeout,
      );
    } on InferenceHttpException catch (includeMetaError, stackTrace) {
      if (!_shouldRetryPlainModels(includeMetaError)) rethrow;
      domainLogger.error(
        LogDomain.ai,
        includeMetaError,
        stackTrace: stackTrace,
        subDomain: _providerName,
        message:
            'Melious metadata catalog failed; retrying plain /models as '
            'degraded fallback',
      );
      try {
        return await _listModelsFromEndpoint(
          baseUrl: normalizedBaseUrl,
          apiKey: normalizedApiKey,
          includeMeta: false,
          timeout: timeout,
        );
      } on InferenceHttpException catch (plainError) {
        throw InferenceHttpException(
          provider: _exceptionProvider,
          'include_meta failed: ${includeMetaError.message}; '
          'plain /models failed: ${plainError.message}',
          statusCode: plainError.statusCode ?? includeMetaError.statusCode,
          originalError: plainError.originalError ?? plainError,
        );
      }
    }
  }

  static bool _shouldRetryPlainModels(InferenceHttpException error) {
    final statusCode = error.statusCode;
    if (statusCode == null) return false;
    return statusCode != 401 && statusCode != 403;
  }

  /// Generates text using Melious' OpenAI-compatible endpoint.
  ///
  /// When [impactCollector] is provided the call is issued **non-streaming** so
  /// Melious returns `environment_impact` + `billing_cost` (only present on
  /// non-streaming responses); the parsed impact is written to the collector and
  /// the buffered reply is re-emitted as a single synthetic stream chunk so
  /// existing consumers are unchanged. [preferStreaming] retains the collector
  /// but requests incremental text and token usage. Only an explicit initial
  /// rejection of a streaming parameter permits one same-model buffered
  /// fallback; other errors and partial responses are never retried here.
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    ReasoningEffort? reasoningEffort,
    InferenceImpactCollector? impactCollector,
    bool preferStreaming = false,
  }) {
    final messages = [
      if (systemMessage != null)
        ChatCompletionMessage.system(content: systemMessage),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(prompt),
      ),
    ];
    if (impactCollector != null && !preferStreaming) {
      return _nonStreamingChat(
        messages: messages,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
        reasoningEffort: reasoningEffort,
        impactCollector: impactCollector,
      );
    }
    final request = _helpers
        .createBaseRequest(
          messages: messages,
          model: model,
          temperature: temperature,
          maxCompletionTokens: maxCompletionTokens,
          tools: tools,
          toolChoice: resolveToolChoice(model, tools, toolChoice),
          reasoningEffort: resolveReasoningEffort(model, reasoningEffort),
        )
        .copyWith(
          streamOptions: preferStreaming
              ? const ChatCompletionStreamOptions(includeUsage: true)
              : null,
        );
    late StreamController<CreateChatCompletionStreamResponse> controller;
    StreamSubscription<CreateChatCompletionStreamResponse>? subscription;
    var emitted = false;
    var cancelled = false;
    bool permitsFallback(Object error) {
      if (!preferStreaming ||
          emitted ||
          error is! OpenAIClientException ||
          (error.code != 400 && error.code != 422)) {
        return false;
      }
      var body = error.body;
      if (body is String) {
        try {
          body = jsonDecode(body);
        } catch (_) {
          return false;
        }
      }
      final detail = body is Map ? body['error'] : null;
      final parameter = detail is Map ? detail['param'] : null;
      return parameter == 'stream' || parameter == 'stream_options';
    }

    void finishError(Object error, StackTrace stack) {
      if (cancelled) return;
      controller.addError(error, stack);
      unawaited(controller.close());
    }

    void listen(
      Stream<CreateChatCompletionStreamResponse> source, {
      required bool fallback,
    }) {
      subscription = source.listen(
        (chunk) {
          if (cancelled) return;
          emitted = true;
          controller.add(chunk);
        },
        onError: (Object error, StackTrace stack) {
          if (cancelled) return;
          if (!fallback && permitsFallback(error)) {
            listen(
              _nonStreamingChat(
                messages: messages,
                model: model,
                baseUrl: baseUrl,
                apiKey: apiKey,
                temperature: temperature,
                maxCompletionTokens: maxCompletionTokens,
                tools: tools,
                toolChoice: toolChoice,
                reasoningEffort: reasoningEffort,
                impactCollector: impactCollector ?? InferenceImpactCollector(),
              ),
              fallback: true,
            );
          } else {
            finishError(error, stack);
          }
        },
        onDone: () => unawaited(controller.close()),
        cancelOnError: true,
      );
    }

    controller = StreamController<CreateChatCompletionStreamResponse>(
      onListen: () {
        try {
          listen(
            _helpers.filterAnthropicPings(
              _chatCompletionStreamFactory(
                baseUrl: baseUrl,
                apiKey: apiKey,
                request: request,
              ),
            ),
            fallback: false,
          );
        } catch (error, stack) {
          finishError(error, stack);
        }
      },
      onCancel: () {
        cancelled = true;
        return subscription?.cancel();
      },
    );
    return controller.stream.asBroadcastStream(
      onCancel: (subscription) => unawaited(subscription.cancel()),
    );
  }

  /// Generates with full conversation history through Melious' OpenAI-compatible
  /// streaming endpoint.
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    ReasoningEffort? reasoningEffort,
    InferenceImpactCollector? impactCollector,
  }) {
    if (impactCollector != null) {
      return _nonStreamingChat(
        messages: messages,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
        reasoningEffort: reasoningEffort,
        impactCollector: impactCollector,
      );
    }
    final stream = _chatCompletionStreamFactory(
      baseUrl: baseUrl,
      apiKey: apiKey,
      request: _helpers.createBaseRequest(
        messages: messages,
        model: model,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: resolveToolChoice(model, tools, toolChoice),
        reasoningEffort: resolveReasoningEffort(model, reasoningEffort),
      ),
    );

    return _helpers.filterAnthropicPings(stream).asBroadcastStream();
  }

  /// Generates with text plus image inputs through Melious' OpenAI-compatible
  /// vision chat endpoint.
  Stream<CreateChatCompletionStreamResponse> generateWithImages({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    required List<String> images,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    InferenceImpactCollector? impactCollector,
  }) {
    final messages = [
      if (systemMessage != null)
        ChatCompletionMessage.system(content: systemMessage),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: prompt),
          ...images.map(
            (image) => ChatCompletionMessageContentPart.image(
              imageUrl: ChatCompletionMessageImageUrl(
                url: 'data:image/jpeg;base64,$image',
              ),
            ),
          ),
        ]),
      ),
    ];
    if (impactCollector != null) {
      return _nonStreamingChat(
        messages: messages,
        model: model,
        baseUrl: baseUrl,
        apiKey: apiKey,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
        impactCollector: impactCollector,
      );
    }
    return _chatCompletionStreamFactory(
      baseUrl: baseUrl,
      apiKey: apiKey,
      request: _helpers.createBaseRequest(
        messages: messages,
        model: model,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: resolveToolChoice(model, tools, toolChoice),
        reasoningEffort: resolveReasoningEffort(model, null),
      ),
    ).asBroadcastStream();
  }

  static Stream<CreateChatCompletionStreamResponse>
  _createChatCompletionStream({
    required String baseUrl,
    required String apiKey,
    required CreateChatCompletionRequest request,
  }) {
    final client = OpenAIClient(baseUrl: baseUrl, apiKey: apiKey);
    return const CloudInferenceRequestHelpers().filterAnthropicPings(
      client.createChatCompletionStream(request: request),
      onClose: client.endSession,
    );
  }

  static ChatCompletionFinishReason? _parseFinishReason(Object? raw) {
    if (raw is! String) return null;
    final normalized = raw.replaceAll('_', '').toLowerCase();
    for (final reason in ChatCompletionFinishReason.values) {
      if (reason.name.toLowerCase() == normalized) return reason;
    }
    return null;
  }

  /// Transcribes audio through Melious' OpenAI-compatible
  /// `/audio/transcriptions` endpoint.
  ///
  /// Recordings above the upload limit use consecutive temporary MP3 parts.
  /// Only the complete combined transcript is emitted; cancellation stops
  /// subsequent parts and aborts the current upload. Source bytes are preserved.
  /// [onSegments] requests verbose JSON and receives validated timing only
  /// after every upload succeeds. Split uploads use recording-relative offsets;
  /// an injected segment encoder must preserve the standard twenty-minute
  /// non-final part boundaries.
  ///
  /// [contextBiasTerms] are speech-dictionary words/phrases forwarded as the
  /// OpenAI-standard `prompt` form field to bias recognition toward names and
  /// domain vocabulary — honored by context-aware models such as Voxtral and
  /// safely ignored by models without prompt biasing.
  ///
  /// When [impactCollector] is provided, the cost and environmental impact
  /// Melious reports alongside the transcript are written to it. Transcription
  /// is a single buffered POST, so it always carries the impact fields a
  /// streamed chat response would omit. Fields absent from the response leave
  /// the collector untouched.
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    String responseFormat = 'json',
    List<String>? contextBiasTerms,
    Duration? timeout,
    InferenceImpactCollector? impactCollector,
    void Function(List<AudioTimedSegment>)? onSegments,
  }) {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (model.trim().isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (audioBase64.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }
    if (normalizedBaseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (normalizedApiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    return _transcribeAudioUploads(
      model: model,
      audioBase64: audioBase64,
      baseUrl: normalizedBaseUrl,
      apiKey: normalizedApiKey,
      responseFormat: responseFormat,
      contextBiasTerms: contextBiasTerms,
      timeout: timeout,
      impactCollector: impactCollector,
      onSegments: onSegments,
    );
  }

  /// Transcribes with Voxtral using temporary MP3 audio plus task and
  /// speech-dictionary context in one buffered chat request.
  ///
  /// Melious' chat adapter currently stalls when Lotti's M4A recording bytes
  /// are sent as an audio content block. Lotti therefore preserves M4A as its
  /// compact archive format, decodes only a temporary copy to PCM, and encodes
  /// a much smaller temporary MP3 for transmission. Conversion failures are
  /// surfaced rather than falling back to a request that cannot apply context
  /// during recognition. The MP3 is deleted after every request outcome.
  Stream<CreateChatCompletionStreamResponse> transcribeChatAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    required String prompt,
    int? maxCompletionTokens,
    Duration timeout = temporaryMp3ChatAudioTimeout,
    InferenceImpactCollector? impactCollector,
  }) => transcribeTemporaryMp3ChatAudio(
    httpClient: httpClient,
    domainLogger: domainLogger,
    provider: const TemporaryMp3ChatAudioProvider(
      repositoryName: _providerName,
      displayName: 'Melious',
      requestIdPrefix: 'melious-audio-',
      payloadDialect: ChatAudioPayloadDialect.openAi,
      includeRequestIdInBody: true,
    ),
    model: model,
    audioBase64: audioBase64,
    baseUrl: baseUrl,
    apiKey: apiKey,
    prompt: prompt,
    maxCompletionTokens: maxCompletionTokens,
    timeout: timeout,
    audioToTemporaryMp3Encoder: _audioToTemporaryMp3Encoder,
    temporaryFileReader: _temporaryFileReader,
    temporaryFileDeleter: _temporaryFileDeleter,
    clockSource: _clock,
    impactCollector: impactCollector,
  );

  /// Generates an image through Melious' `/images/generations` endpoint.
  ///
  /// Melious currently documents text-to-image generation returning base64
  /// image bytes. Reference-image editing is intentionally rejected so callers
  /// do not think their reference material was used when the endpoint ignores
  /// it.
  Future<GeneratedImage> generateImage({
    required String prompt,
    required String model,
    required AiConfigInferenceProvider provider,
    List<ProcessedReferenceImage>? referenceImages,
    Duration timeout = _imageGenerationTimeout,
    InferenceImpactCollector? impactCollector,
  }) async {
    if (prompt.trim().isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }
    if (model.trim().isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (provider.baseUrl.trim().isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (provider.apiKey.trim().isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
    if (referenceImages != null && referenceImages.isNotEmpty) {
      throw UnsupportedError(
        'Melious image generation does not currently support reference images',
      );
    }

    final uri = _buildEndpointUri(provider.baseUrl, 'images/generations');
    final body = {
      'model': model,
      'prompt': prompt,
      'n': 1,
      'width': _imageGenerationWidth,
      'height': _imageGenerationHeight,
      'response_format': 'b64_json',
    };

    try {
      final response = await httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${provider.apiKey.trim()}',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InferenceHttpException(
          provider: _exceptionProvider,
          ModelCatalogMapping.extractErrorMessage(
            response.body,
            response.statusCode,
            providerLabel: 'Melious',
            maxLength: 240,
            ellipsis: '...',
          ),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const InferenceHttpException(
          provider: _exceptionProvider,
          'Melious image generation response must be a JSON object',
        );
      }
      final data = decoded['data'];
      if (data is! List || data.isEmpty) {
        throw const InferenceHttpException(
          provider: _exceptionProvider,
          'Melious image generation response is missing image data',
        );
      }
      final first = data.first;
      if (first is! Map<String, dynamic>) {
        throw const InferenceHttpException(
          provider: _exceptionProvider,
          'Melious image generation entry must be a JSON object',
        );
      }
      final encodedImage = first['b64_json'];
      if (encodedImage is! String || encodedImage.isEmpty) {
        throw const InferenceHttpException(
          provider: _exceptionProvider,
          'Melious image generation response is missing b64_json',
        );
      }

      if (impactCollector != null) {
        final impact = MeliousCallImpact.fromResponseJson(
          decoded,
          costCreditsDecimal: MeliousCallImpact.costDecimalFromResponseBody(
            response.body,
          ),
        );
        if (impact.hasData) impactCollector.impact = impact;
      }

      return _decodeGeneratedImage(encodedImage);
    } on InferenceHttpException {
      rethrow;
    } on TimeoutException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Melious image generation request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Melious image generation response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Failed to generate Melious image: $e',
        originalError: e,
      );
    }
  }

  /// Heuristic for routing Melious speech-to-text models to
  /// `/audio/transcriptions` instead of chat completions.
  static bool isMeliousTranscriptionModel(String model) {
    final normalized = model.toLowerCase();
    return normalized.contains('whisper') ||
        normalized.contains('transcribe') ||
        normalized.contains('transcription') ||
        normalized.contains('asr') ||
        normalized.contains('stt');
  }

  /// Whether [model] accepts audio through Melious' chat-completions API.
  static bool isMeliousChatAudioModel(String model) {
    return model.toLowerCase().contains('voxtral') &&
        !isMeliousTranscriptionModel(model);
  }

  static bool _looksLikeReasoningModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('thinking') ||
        normalized.contains('deepseek-r1');
  }

  static GeneratedImage _decodeGeneratedImage(String encodedImage) {
    var mimeType = 'image/png';
    var payload = encodedImage;

    final dataUriMatch = RegExp(
      r'^data:([^;]+);base64,(.*)$',
      dotAll: true,
    ).firstMatch(encodedImage);
    if (dataUriMatch != null) {
      mimeType = dataUriMatch.group(1) ?? mimeType;
      payload = dataUriMatch.group(2) ?? '';
    }

    return GeneratedImage(
      bytes: base64Decode(payload),
      mimeType: mimeType,
    );
  }

  static Uri _buildEndpointUri(
    String baseUrl,
    String endpointPath, {
    Map<String, String> queryParameters = const {},
  }) {
    final baseUri = Uri.parse(baseUrl.trim());
    final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
    final normalizedEndpoint = endpointPath.replaceAll(RegExp('^/+'), '');
    final mergedQuery = <String, String>{
      ...baseUri.queryParameters,
      ...queryParameters,
    };

    return baseUri.replace(
      path: '$basePath/$normalizedEndpoint',
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
  }

  static String _catalogItemIdForLog(Object? item) {
    if (item is String) return item;
    if (item is Map<String, dynamic>) {
      final id = item['id'] ?? item['name'];
      if (id is String && id.trim().isNotEmpty) return id.trim();
      return '<missing id; keys=${item.keys.join(',')}>';
    }
    return '<${item.runtimeType}>';
  }
}

/// The parsed result of a non-streaming Melious chat completion, used to build
/// the synthetic stream chunk and surface the impact side-channel.
class _MeliousChatResult {
  const _MeliousChatResult({
    required this.content,
    required this.finishReason,
    required this.toolCalls,
    required this.usage,
    required this.impact,
  });

  final String content;
  final ChatCompletionFinishReason? finishReason;
  final List<ChatCompletionStreamMessageToolCallChunk> toolCalls;
  final CompletionUsage? usage;
  final MeliousCallImpact impact;
}

final Map<String, KnownModel> _knownMeliousModels = {
  for (final model in meliousModels) model.providerModelId: model,
};

enum _MeliousModelType {
  chat('chat'),
  embeddings('embeddings'),
  audio('audio'),
  image('image'),
  rerank('rerank'),
  unknown('unknown');

  const _MeliousModelType(this.label);

  final String label;

  static _MeliousModelType from(Object? value) {
    final normalized = '$value'.toLowerCase().trim();
    return switch (normalized) {
      'chat' => _MeliousModelType.chat,
      'embeddings' || 'embedding' => _MeliousModelType.embeddings,
      'audio' || 'speech' => _MeliousModelType.audio,
      'image' || 'images' => _MeliousModelType.image,
      'rerank' || 'reranker' => _MeliousModelType.rerank,
      _ => _MeliousModelType.unknown,
    };
  }
}
