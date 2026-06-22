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
    CloudInferenceRequestHelpers helpers = const CloudInferenceRequestHelpers(),
  }) : _helpers = helpers;

  static const _providerName = 'MeliousInferenceRepository';
  static const _modelListTimeout = Duration(seconds: 15);
  static const _imageGenerationTimeout = Duration(seconds: 180);

  final CloudInferenceRequestHelpers _helpers;

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

    final uri = _buildEndpointUri(
      normalizedBaseUrl,
      'models',
      queryParameters: const {'include_meta': 'true'},
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
              'Authorization': 'Bearer $normalizedApiKey',
            },
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
        throw MeliousInferenceException(
          'Melious model list response must be a JSON object',
        );
      }

      final data = decoded['data'];
      if (data is! List) {
        throw MeliousInferenceException(
          'Melious model list response is missing the data array',
        );
      }

      return data
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw MeliousInferenceException(
                'Melious model entry must be a JSON object',
              );
            }
            return _knownModelFromPayload(item);
          })
          .toList(growable: false);
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
    final client = OpenAIClient(baseUrl: baseUrl, apiKey: apiKey);
    final stream = client.createChatCompletionStream(
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
    final client = OpenAIClient(baseUrl: baseUrl, apiKey: apiKey);
    final stream = client.createChatCompletionStream(
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
    final client = OpenAIClient(baseUrl: baseUrl, apiKey: apiKey);
    return client
        .createChatCompletionStream(
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
            maxTokens: maxCompletionTokens,
            tools: tools,
          ),
        )
        .asBroadcastStream();
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
      'size': '1024x1024',
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
          .timeout(_imageGenerationTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MeliousInferenceException(
          _extractErrorMessage(response.body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw MeliousInferenceException(
          'Melious image generation response must be a JSON object',
        );
      }
      final data = decoded['data'];
      if (data is! List || data.isEmpty) {
        throw MeliousInferenceException(
          'Melious image generation response is missing image data',
        );
      }
      final first = data.first;
      if (first is! Map<String, dynamic>) {
        throw MeliousInferenceException(
          'Melious image generation entry must be a JSON object',
        );
      }
      final encodedImage = first['b64_json'];
      if (encodedImage is! String || encodedImage.isEmpty) {
        throw MeliousInferenceException(
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
      throw MeliousInferenceException(
        'Melious model entry is missing a string id',
      );
    }

    final meta = model['_meta'];
    final metaMap = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};
    final capabilities = metaMap['capabilities'];
    final capabilityMap = capabilities is Map<String, dynamic>
        ? capabilities
        : const <String, dynamic>{};
    final type = _MeliousModelType.from(metaMap['type']);

    final inputModalities = _modalitiesFrom(metaMap['input_modalities']);
    final outputModalities = _modalitiesFrom(metaMap['output_modalities']);

    _applyCapabilityModalities(
      type: type,
      capabilities: capabilityMap,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
    );

    final supportsFunctionCalling = _truthy(capabilityMap['function_calling']);
    final isReasoningModel = _truthy(capabilityMap['reasoning']);

    return KnownModel(
      providerModelId: providerModelId,
      name: _displayNameForModel(providerModelId),
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
    if (_truthy(capabilities['audio_input'])) {
      _addUnique(inputModalities, Modality.audio);
    }
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

  String _descriptionFor({
    required Map<String, dynamic> model,
    required _MeliousModelType type,
    required Map<String, dynamic> capabilities,
  }) {
    final parts = <String>[];
    parts.add('Melious ${type.label} model.');

    final ownedBy = model['owned_by'];
    if (ownedBy is String && ownedBy.trim().isNotEmpty) {
      parts.add('Owned by ${ownedBy.trim()}.');
    }

    final contextLength = _integerValue(
      (model['_meta'] as Map<String, dynamic>?)?['context_length'],
    );
    if (contextLength != null) {
      parts.add('Context: $contextLength tokens.');
    }

    final featureLabels = <String>[
      if (_truthy(capabilities['vision'])) 'vision',
      if (_truthy(capabilities['audio_input'])) 'audio input',
      if (_truthy(capabilities['reasoning'])) 'reasoning',
      if (_truthy(capabilities['function_calling'])) 'tools',
      if (_truthy(capabilities['structured_output'])) 'structured output',
      if (_truthy(capabilities['json_schema'])) 'JSON schema',
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
    final normalizedEndpoint = endpointPath.replaceAll(RegExp(r'^/+'), '');
    final mergedQuery = <String, String>{
      ...baseUri.queryParameters,
      ...queryParameters,
    };

    return baseUri.replace(
      path: '$basePath/$normalizedEndpoint',
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
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
