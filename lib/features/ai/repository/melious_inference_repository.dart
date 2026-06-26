import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:lotti/features/ai/repository/gemini_inference_payloads.dart';
import 'package:lotti/features/ai/repository/transcription_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:openai_dart/openai_dart.dart';

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
    super.httpClient,
    CloudInferenceRequestHelpers? helpers,
    MeliousChatCompletionStreamFactory? chatCompletionStreamFactory,
  }) : _helpers = helpers ?? const CloudInferenceRequestHelpers(),
       _chatCompletionStreamFactory =
           chatCompletionStreamFactory ?? _createChatCompletionStream;

  static const _providerName = 'MeliousInferenceRepository';
  static const _modelListTimeout = Duration(seconds: 15);
  static const _imageGenerationTimeout = Duration(seconds: 180);
  static const _imageGenerationWidth = 1792;
  static const _imageGenerationHeight = 1008;

  final CloudInferenceRequestHelpers _helpers;
  final MeliousChatCompletionStreamFactory _chatCompletionStreamFactory;

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
    } on MeliousInferenceException catch (includeMetaError) {
      if (!_shouldRetryPlainModels(includeMetaError)) rethrow;
      developer.log(
        'Melious metadata catalog failed; retrying plain /models as degraded '
        'fallback',
        name: _providerName,
        error: includeMetaError,
      );
      try {
        return await _listModelsFromEndpoint(
          baseUrl: normalizedBaseUrl,
          apiKey: normalizedApiKey,
          includeMeta: false,
          timeout: timeout,
        );
      } on MeliousInferenceException catch (plainError) {
        throw MeliousInferenceException(
          'include_meta failed: ${includeMetaError.message}; '
          'plain /models failed: ${plainError.message}',
          statusCode: plainError.statusCode ?? includeMetaError.statusCode,
          originalError: plainError.originalError ?? plainError,
        );
      }
    }
  }

  static bool _shouldRetryPlainModels(MeliousInferenceException error) {
    final statusCode = error.statusCode;
    if (statusCode == null) return false;
    return statusCode != 401 && statusCode != 403;
  }

  Future<List<KnownModel>> _listModelsFromEndpoint({
    required String baseUrl,
    required String apiKey,
    required bool includeMeta,
    required Duration timeout,
  }) async {
    final uri = _buildEndpointUri(
      baseUrl,
      'models',
      queryParameters: includeMeta ? const {'include_meta': 'true'} : const {},
    );

    developer.log(
      'Fetching Melious model catalog from $uri',
      name: _providerName,
    );

    try {
      final response = await httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(timeout);

      developer.log(
        'Melious model catalog response from $uri: HTTP '
        '${response.statusCode}',
        name: _providerName,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MeliousInferenceException(
          _extractErrorMessage(response.body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = switch (decoded) {
        {'data': final List<dynamic> data} => data,
        final List<dynamic> data => data,
        _ => throw const MeliousInferenceException(
          'Melious model list response must be a JSON object with data[] '
          'or a JSON array',
        ),
      };
      _logCatalogPayload(uri: uri, decoded: decoded, data: data);

      final models = <KnownModel>[];
      for (final (index, item) in data.indexed) {
        try {
          models.add(_knownModelFromCatalogItem(item));
        } on Exception catch (e, stackTrace) {
          developer.log(
            'Failed to parse Melious model catalog row #$index from $uri: '
            '${_catalogItemSummary(item)}',
            name: _providerName,
            error: e,
            stackTrace: stackTrace,
          );
          rethrow;
        }
      }

      developer.log(
        'Mapped ${models.length} Melious catalog rows from $uri',
        name: _providerName,
      );
      return models;
    } on MeliousInferenceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw MeliousInferenceException(
        'Melious model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw MeliousInferenceException(
        'Melious model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw MeliousInferenceException(
        'Failed to fetch Melious models: $e',
        originalError: e,
      );
    }
  }

  KnownModel _knownModelFromCatalogItem(Object? item) {
    if (item is String) {
      return _knownModelFromPayload({'id': item});
    }
    if (item is Map<String, dynamic>) {
      return _knownModelFromPayload(item);
    }

    throw const MeliousInferenceException(
      'Melious model entry must be a JSON object or string id',
    );
  }

  /// Generates text using Melious' OpenAI-compatible streaming endpoint.
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
  }) {
    final stream = _chatCompletionStreamFactory(
      baseUrl: baseUrl,
      apiKey: apiKey,
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

    return _helpers.filterAnthropicPings(stream).asBroadcastStream();
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
  }) {
    final stream = _chatCompletionStreamFactory(
      baseUrl: baseUrl,
      apiKey: apiKey,
      request: _helpers.createBaseRequest(
        messages: messages,
        model: model,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
        toolChoice: toolChoice,
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
  }) {
    return _chatCompletionStreamFactory(
      baseUrl: baseUrl,
      apiKey: apiKey,
      request: _helpers.createBaseRequest(
        messages: [
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
        ],
        model: model,
        temperature: temperature,
        maxCompletionTokens: maxCompletionTokens,
        tools: tools,
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
    return client.createChatCompletionStream(request: request);
  }

  /// Transcribes audio through Melious' OpenAI-compatible
  /// `/audio/transcriptions` endpoint.
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    required String apiKey,
    String responseFormat = 'json',
    Duration? timeout,
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

    return executeTranscription(
      providerName: _providerName,
      responseIdPrefix: 'melious-transcription-',
      audioLengthForLog: audioBase64.length,
      timeout: timeout,
      sendRequest: (requestTimeout, timeoutErrorMessage) async {
        final uri = _buildEndpointUri(
          normalizedBaseUrl,
          'audio/transcriptions',
        );
        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $normalizedApiKey'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              base64Decode(audioBase64),
              filename: 'audio.m4a',
            ),
          )
          ..fields['model'] = model
          ..fields['response_format'] = responseFormat;

        final streamedResponse = await httpClient
            .send(request)
            .timeout(
              requestTimeout,
              onTimeout: () {
                throw TranscriptionException(
                  timeoutErrorMessage,
                  provider: _providerName,
                  statusCode: httpStatusRequestTimeout,
                );
              },
            );

        return http.Response.fromStream(streamedResponse);
      },
    );
  }

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
        throw MeliousInferenceException(
          _extractErrorMessage(response.body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const MeliousInferenceException(
          'Melious image generation response must be a JSON object',
        );
      }
      final data = decoded['data'];
      if (data is! List || data.isEmpty) {
        throw const MeliousInferenceException(
          'Melious image generation response is missing image data',
        );
      }
      final first = data.first;
      if (first is! Map<String, dynamic>) {
        throw const MeliousInferenceException(
          'Melious image generation entry must be a JSON object',
        );
      }
      final encodedImage = first['b64_json'];
      if (encodedImage is! String || encodedImage.isEmpty) {
        throw const MeliousInferenceException(
          'Melious image generation response is missing b64_json',
        );
      }

      return _decodeGeneratedImage(encodedImage);
    } on MeliousInferenceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw MeliousInferenceException(
        'Melious image generation request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw MeliousInferenceException(
        'Melious image generation response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw MeliousInferenceException(
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
        normalized.contains('voxtral') ||
        normalized.contains('asr') ||
        normalized.contains('stt');
  }

  KnownModel _knownModelFromPayload(Map<String, dynamic> model) {
    final providerModelId = model['id'];
    if (providerModelId is! String || providerModelId.trim().isEmpty) {
      throw const MeliousInferenceException(
        'Melious model entry is missing a string id',
      );
    }

    final metaMap =
        _asMap(model['_meta']) ??
        _asMap(model['metadata']) ??
        const <String, dynamic>{};
    final knownModel = _knownMeliousModels[providerModelId];
    if (knownModel != null && metaMap.isEmpty) {
      return knownModel;
    }

    final capabilityMap =
        _asMap(metaMap['capabilities']) ??
        _asMap(model['capabilities']) ??
        const <String, dynamic>{};
    final type = _MeliousModelType.from(metaMap['type'] ?? model['type']);

    final inputModalities = _mergedModalities(
      knownModel?.inputModalities,
      metaMap['input_modalities'] ?? model['input_modalities'],
    );
    final outputModalities = _mergedModalities(
      knownModel?.outputModalities,
      metaMap['output_modalities'] ?? model['output_modalities'],
    );

    _applyCapabilityModalities(
      type: type,
      capabilities: capabilityMap,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
    );

    final supportsFunctionCalling =
        knownModel?.supportsFunctionCalling == true ||
        _truthy(capabilityMap['function_calling']);
    final isReasoningModel =
        knownModel?.isReasoningModel == true ||
        _truthy(capabilityMap['reasoning']) ||
        _truthy(capabilityMap['thinking']) ||
        _looksLikeReasoningModel(providerModelId);

    return KnownModel(
      providerModelId: providerModelId,
      name: knownModel?.name ?? _displayNameForModel(providerModelId),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
      supportsFunctionCalling: supportsFunctionCalling,
      description: _descriptionFor(
        model: model,
        type: type,
        capabilities: capabilityMap,
      ),
    );
  }

  void _applyCapabilityModalities({
    required _MeliousModelType type,
    required Map<String, dynamic> capabilities,
    required List<Modality> inputModalities,
    required List<Modality> outputModalities,
  }) {
    switch (type) {
      case _MeliousModelType.chat:
      case _MeliousModelType.unknown:
        _addUnique(inputModalities, Modality.text);
        _addUnique(outputModalities, Modality.text);
      case _MeliousModelType.audio:
        _addUnique(inputModalities, Modality.audio);
        _addUnique(outputModalities, Modality.text);
      case _MeliousModelType.image:
        _addUnique(inputModalities, Modality.text);
        _addUnique(outputModalities, Modality.image);
      case _MeliousModelType.embeddings:
      case _MeliousModelType.rerank:
        _addUnique(inputModalities, Modality.text);
        _addUnique(outputModalities, Modality.text);
    }

    if (_truthy(capabilities['vision'])) {
      _addUnique(inputModalities, Modality.image);
    }
    if (_truthy(capabilities['audio_input']) ||
        _truthy(capabilities['supports_audio']) ||
        _truthy(capabilities['transcription']) ||
        _truthy(capabilities['translation']) ||
        _truthy(capabilities['diarization'])) {
      _addUnique(inputModalities, Modality.audio);
      _addUnique(outputModalities, Modality.text);
    }
    if (_truthy(capabilities['text_to_image'])) {
      _addUnique(inputModalities, Modality.text);
      _addUnique(outputModalities, Modality.image);
    }
    if (_truthy(capabilities['image_to_image'])) {
      _addUnique(inputModalities, Modality.image);
      _addUnique(outputModalities, Modality.image);
    }
  }

  static List<Modality> _mergedModalities(
    List<Modality>? knownModalities,
    Object? rawModalities,
  ) {
    final out = <Modality>[];
    for (final modality in knownModalities ?? const <Modality>[]) {
      _addUnique(out, modality);
    }
    for (final modality in _modalitiesFrom(rawModalities)) {
      _addUnique(out, modality);
    }
    return out;
  }

  static List<Modality> _modalitiesFrom(Object? raw) {
    if (raw is! List) return <Modality>[];
    final out = <Modality>[];
    for (final value in raw) {
      final normalized = '$value'.toLowerCase().trim();
      switch (normalized) {
        case 'text':
          _addUnique(out, Modality.text);
        case 'audio':
        case 'speech':
          _addUnique(out, Modality.audio);
        case 'image':
        case 'vision':
          _addUnique(out, Modality.image);
      }
    }
    return out;
  }

  static void _addUnique(List<Modality> modalities, Modality modality) {
    if (!modalities.contains(modality)) {
      modalities.add(modality);
    }
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  String _descriptionFor({
    required Map<String, dynamic> model,
    required _MeliousModelType type,
    required Map<String, dynamic> capabilities,
  }) {
    final parts = <String>['Melious ${type.label} model.'];

    final ownedBy = model['owned_by'];
    if (ownedBy is String && ownedBy.trim().isNotEmpty) {
      parts.add('Owned by ${ownedBy.trim()}.');
    }

    final metaMap =
        _asMap(model['_meta']) ??
        _asMap(model['metadata']) ??
        const <String, dynamic>{};
    final contextLength = _integerValue(
      metaMap['context_length'],
    );
    if (contextLength != null) {
      parts.add('Context: $contextLength tokens.');
    }

    final featureLabels = <String>[
      if (_truthy(capabilities['vision'])) 'vision',
      if (_truthy(capabilities['audio_input']) ||
          _truthy(capabilities['supports_audio']))
        'audio input',
      if (_truthy(capabilities['transcription'])) 'transcription',
      if (_truthy(capabilities['translation'])) 'translation',
      if (_truthy(capabilities['diarization'])) 'diarization',
      if (_truthy(capabilities['text_to_image'])) 'text to image',
      if (_truthy(capabilities['image_to_image'])) 'image to image',
      if (_truthy(capabilities['reasoning'])) 'reasoning',
      if (_truthy(capabilities['thinking'])) 'thinking',
      if (_truthy(capabilities['function_calling'])) 'tools',
      if (_truthy(capabilities['structured_output'])) 'structured output',
      if (_truthy(capabilities['json_schema'])) 'JSON schema',
      if (_truthy(capabilities['code_generation'])) 'code generation',
      if (_truthy(capabilities['computer_use'])) 'computer use',
      if (_truthy(capabilities['lora'])) 'LoRA',
      if (_truthy(capabilities['streaming'])) 'streaming',
    ];
    if (featureLabels.isNotEmpty) {
      parts.add('Features: ${featureLabels.join(', ')}.');
    }

    return parts.join(' ');
  }

  static int? _integerValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _truthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static bool _looksLikeReasoningModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('thinking') ||
        normalized.contains('deepseek-r1');
  }

  static String _displayNameForModel(String modelId) {
    final leaf = modelId.split('/').last;
    final words = leaf
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(_titleCaseModelWord);
    final displayName = words.join(' ');
    return displayName.isEmpty ? modelId : displayName;
  }

  static String _titleCaseModelWord(String word) {
    final upper = word.toUpperCase();
    const acronyms = {
      'AI',
      'API',
      'ASR',
      'BGE',
      'CO2',
      'GPT',
      'JSON',
      'KIMI',
      'LLAMA',
      'MLX',
      'QWEN',
      'STT',
      'TTS',
      'VL',
    };
    if (acronyms.contains(upper)) return upper;
    if (RegExp(r'^[a-z]?\d+[a-z]?$', caseSensitive: false).hasMatch(word)) {
      return upper;
    }
    return '${word[0].toUpperCase()}${word.substring(1)}';
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

  static void _logCatalogPayload({
    required Uri uri,
    required Object? decoded,
    required List<dynamic> data,
  }) {
    final shape = switch (decoded) {
      final Map<String, dynamic> map => 'object keys=${map.keys.join(',')}',
      final List<dynamic> _ => 'array',
      // Unreachable: callers only invoke this after the catalog shape switch
      // has already narrowed `decoded` to a map-with-data or a list. Required
      // for switch exhaustiveness over Object?.
      _ => decoded.runtimeType.toString(), // coverage:ignore-line
    };
    developer.log(
      'Melious model catalog payload from $uri: shape=$shape, '
      'count=${data.length}',
      name: _providerName,
    );

    final ids = data.map(_catalogItemIdForLog).toList(growable: false);
    const chunkSize = 25;
    for (var start = 0; start < ids.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, ids.length);
      developer.log(
        'Melious model catalog IDs ${start + 1}-$end/${ids.length}: '
        '${ids.sublist(start, end).join(', ')}',
        name: _providerName,
      );
    }
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

  static String _catalogItemSummary(Object? item) {
    if (item is String) return item;
    if (item is Map<String, dynamic>) {
      final id = item['id'] ?? item['name'];
      final meta = _asMap(item['_meta']) ?? _asMap(item['metadata']);
      final capabilities =
          _asMap(meta?['capabilities']) ?? _asMap(item['capabilities']);
      return [
        if (id is String) 'id=$id' else 'id=<missing>',
        'keys=${item.keys.join(',')}',
        if (meta != null) 'metaKeys=${meta.keys.join(',')}',
        if (capabilities != null)
          'capabilityKeys=${capabilities.keys.join(',')}',
        'snippet=${_clipForLog(jsonEncode(item))}',
      ].join('; ');
    }
    return '<${item.runtimeType}> ${_clipForLog('$item')}';
  }

  static String _clipForLog(String value) {
    const maxLength = 800;
    return value.length > maxLength
        ? '${value.substring(0, maxLength)}...'
        : value;
  }

  static String _extractErrorMessage(String body, int statusCode) {
    final fallback = 'Melious API error (HTTP $statusCode)';
    if (body.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        if (error is String && error.isNotEmpty) return error;
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall through to a clipped raw body.
    }

    return body.length > 240 ? '${body.substring(0, 240)}...' : body;
  }
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

class MeliousInferenceException implements Exception {
  const MeliousInferenceException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    final cause = originalError == null ? '' : ': $originalError';
    return 'MeliousInferenceException$status: $message$cause';
  }
}
