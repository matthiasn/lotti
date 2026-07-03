import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/model_catalog_mapping.dart';
import 'package:lotti/features/ai/repository/openai_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:meta/meta.dart';

/// Fetches OpenAI's live model catalog for the settings UI.
///
/// OpenAI's `GET /v1/models` listing returns only bare ids (`id`, `object`,
/// `created`, `owned_by`) with no capability metadata, so this repository maps
/// each id into a [KnownModel] using the curated [openaiModels] list for known
/// ids and conservative id heuristics for everything else. Rows that map onto
/// no app-supported flow (embeddings, moderation, text-to-speech, realtime,
/// and Whisper transcription — which the app's transcription router can't call)
/// are dropped so they can't be installed and then fail at inference time.
class OpenAiModelsRepository {
  OpenAiModelsRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _providerName = 'OpenAiModelsRepository';

  /// Default timeout for [listModels].
  @visibleForTesting
  static const modelListTimeout = Duration(seconds: 15);

  void close() => _httpClient.close();

  /// Fetches the live OpenAI model catalog and maps each installable row into
  /// the app's [KnownModel] shape.
  ///
  /// A single malformed catalog row is skipped and logged rather than aborting
  /// the whole fetch, so one bad entry can't hide the rest of the catalog.
  Future<List<KnownModel>> listModels({
    required String baseUrl,
    required String apiKey,
    Duration timeout = modelListTimeout,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw const OpenAiModelsException('Base URL cannot be empty');
    }
    if (normalizedApiKey.isEmpty) {
      throw const OpenAiModelsException('API key cannot be empty');
    }

    final uri = _buildEndpointUri(normalizedBaseUrl, 'models');
    // A scheme-less/host-less base URL yields an empty host; reject it before
    // requesting so the low-level HTTP client can't throw an ArgumentError that
    // echoes the request URI. Never echo the raw base URL either.
    if (uri.host.isEmpty) {
      throw const OpenAiModelsException('Invalid OpenAI base URL');
    }
    developer.log(
      'Fetching OpenAI model catalog from '
      '${ModelCatalogMapping.redactedEndpoint(uri)}',
      name: _providerName,
    );

    try {
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $normalizedApiKey',
            },
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiModelsException(
          ModelCatalogMapping.extractErrorMessage(
            response.body,
            response.statusCode,
            providerLabel: 'OpenAI',
          ),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = switch (decoded) {
        {'data': final List<dynamic> data} => data,
        final List<dynamic> data => data,
        _ => throw const OpenAiModelsException(
          'OpenAI model list response must be a JSON object with data[] '
          'or a JSON array',
        ),
      };

      final models = <KnownModel>[];
      for (final (index, item) in data.indexed) {
        final KnownModel? known;
        try {
          known = _knownModelFromPayload(item);
        } on OpenAiModelsException catch (e) {
          developer.log(
            'Skipping malformed OpenAI model row #$index',
            name: _providerName,
            error: e,
          );
          continue;
        }
        if (known != null) models.add(known);
      }
      return models;
    } on OpenAiModelsException {
      rethrow;
    } on TimeoutException catch (e) {
      throw OpenAiModelsException(
        'OpenAI model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw OpenAiModelsException(
        'OpenAI model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw OpenAiModelsException(
        'Failed to fetch OpenAI models: $e',
        originalError: e,
      );
    }
  }

  /// Maps a single `/v1/models` row into a [KnownModel], or `null` for
  /// non-installable rows (embeddings, moderation, text-to-speech, realtime,
  /// Whisper).
  KnownModel? _knownModelFromPayload(Object? item) {
    final Map<String, dynamic> model;
    if (item is String) {
      model = {'id': item};
    } else if (item is Map<String, dynamic>) {
      model = item;
    } else {
      throw const OpenAiModelsException(
        'OpenAI model entry must be a JSON object or string id',
      );
    }

    final providerModelId = model['id'];
    if (providerModelId is! String || providerModelId.trim().isEmpty) {
      throw const OpenAiModelsException(
        'OpenAI model entry is missing a string id',
      );
    }

    // Curated entries win verbatim so their hand-tuned copy survives.
    final curated = _curatedOpenAiModels[providerModelId];
    if (curated != null) return curated;

    final classification = _classify(providerModelId);
    if (classification == null) return null;

    return KnownModel(
      providerModelId: providerModelId,
      name: ModelCatalogMapping.humanizeModelId(
        providerModelId,
        acronyms: _acronyms,
      ),
      inputModalities: classification.inputModalities,
      outputModalities: classification.outputModalities,
      isReasoningModel: classification.isReasoningModel,
      supportsFunctionCalling: classification.supportsFunctionCalling,
      description: _descriptionFor(model, classification),
    );
  }

  /// Classifies an uncurated OpenAI id, or returns `null` when the model maps
  /// onto no app-supported flow and should be dropped from the catalog.
  static _OpenAiClassification? _classify(String modelId) {
    final normalized = modelId.toLowerCase();

    // Non-installable: no supported flow the app can route.
    if (normalized.contains('embedding') ||
        normalized.contains('moderation') ||
        normalized.contains('tts') ||
        normalized.contains('realtime')) {
      return null;
    }

    // Transcription: only the families the transcription router recognizes are
    // installable. Whisper etc. would route to /v1/chat/completions and fail,
    // so they are dropped rather than offered.
    if (OpenAiTranscriptionRepository.isOpenAiTranscriptionModel(modelId)) {
      return _OpenAiClassification(
        inputModalities: [Modality.audio],
        outputModalities: [Modality.text],
        featureLabels: const ['audio transcription'],
      );
    }
    if (_looksLikeTranscriptionModel(normalized)) return null;

    // Image generation.
    if (normalized.contains('gpt-image')) {
      // gpt-image accepts text + reference images and emits images.
      return _OpenAiClassification(
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text, Modality.image],
        featureLabels: const ['image generation'],
      );
    }
    if (normalized.contains('dall-e') || normalized.contains('image')) {
      // DALL·E takes a text prompt and emits an image.
      return _OpenAiClassification(
        inputModalities: [Modality.text],
        outputModalities: [Modality.image],
        featureLabels: const ['image generation'],
      );
    }

    // Legacy text-completion models (davinci-002, babbage-002,
    // gpt-3.5-turbo-instruct) are not chat/vision/tool models — keep them
    // installable as plain text models rather than over-claiming capabilities.
    if (normalized.contains('davinci') ||
        normalized.contains('babbage') ||
        normalized.contains('instruct')) {
      return _OpenAiClassification(
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
      );
    }

    // Default: a multimodal-input chat/reasoning model emitting text.
    final isReasoning = _looksLikeReasoningModel(normalized);
    return _OpenAiClassification(
      inputModalities: [Modality.text, Modality.image],
      outputModalities: [Modality.text],
      supportsFunctionCalling: true,
      isReasoningModel: isReasoning,
      featureLabels: isReasoning ? const ['reasoning'] : const [],
    );
  }

  static bool _looksLikeTranscriptionModel(String normalizedId) {
    return normalizedId.contains('transcribe') ||
        normalizedId.contains('whisper');
  }

  static bool _looksLikeReasoningModel(String normalizedId) {
    // The o-series (o1/o3/o4) are reasoning models. Anchor `o<digit>` on a
    // boundary (start, `:` or `/`) so families that merely contain those tokens
    // (e.g. `gpt-4o`) don't match, while fine-tuned ids (`ft:o1-mini:org::id`)
    // still do.
    if (RegExp(r'(^|:|/)o\d').hasMatch(normalizedId)) return true;
    return normalizedId.contains('reasoning') ||
        normalizedId.contains('thinking');
  }

  String _descriptionFor(
    Map<String, dynamic> model,
    _OpenAiClassification classification,
  ) {
    final parts = <String>['OpenAI model.'];

    final ownedBy = model['owned_by'];
    if (ownedBy is String && ownedBy.trim().isNotEmpty) {
      parts.add('Owned by ${ownedBy.trim()}.');
    }

    if (classification.featureLabels.isNotEmpty) {
      parts.add('Features: ${classification.featureLabels.join(', ')}.');
    }

    return parts.join(' ');
  }

  static Uri _buildEndpointUri(String baseUrl, String endpointPath) {
    try {
      final baseUri = Uri.parse(baseUrl.trim());
      final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
      final normalizedEndpoint = endpointPath.replaceAll(RegExp('^/+'), '');

      return baseUri.replace(path: '$basePath/$normalizedEndpoint');
    } on FormatException catch (e) {
      // Never echo the raw base URL — it may carry userinfo/query secrets.
      throw OpenAiModelsException(
        'Invalid OpenAI base URL',
        originalError: e,
      );
    }
  }

  static const _acronyms = {'AI', 'API', 'GPT', 'TTS'};
}

/// Capability + modality classification for an uncurated OpenAI catalog row.
class _OpenAiClassification {
  _OpenAiClassification({
    required this.inputModalities,
    required this.outputModalities,
    this.supportsFunctionCalling = false,
    this.isReasoningModel = false,
    this.featureLabels = const [],
  });

  final List<Modality> inputModalities;
  final List<Modality> outputModalities;
  final bool supportsFunctionCalling;
  final bool isReasoningModel;
  final List<String> featureLabels;
}

final Map<String, KnownModel> _curatedOpenAiModels = {
  for (final model in openaiModels) model.providerModelId: model,
};

/// Exception thrown when the OpenAI model catalog fetch fails.
class OpenAiModelsException implements Exception {
  const OpenAiModelsException(
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
    return 'OpenAiModelsException$status: $message$cause';
  }
}
