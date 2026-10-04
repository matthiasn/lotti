import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_http_exception.dart';
import 'package:lotti/features/ai/repository/model_catalog_mapping.dart';
import 'package:lotti/features/ai/repository/omlx_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';

/// How this repository names itself in an [InferenceHttpException].
const _exceptionProvider = 'oMLX';

/// Repository for oMLX's local OpenAI-compatible inference surface.
///
/// oMLX exposes the standard `/models` endpoint. The response generally only
/// contains model IDs, so this repository preserves rich metadata for IDs that
/// are already in the bundled oMLX catalog and applies conservative heuristics
/// for unknown local models.
class OmlxInferenceRepository {
  OmlxInferenceRepository({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  /// Segments the model-name humanizer keeps upper-case for this provider.
  static const _modelNameAcronyms = {
    'A3B',
    'API',
    'ASR',
    'MLX',
    'QAT',
    'QWEN',
    'STT',
    'UD',
    'VL',
  };

  static const _providerName = 'OmlxInferenceRepository';
  static const _modelListTimeout = Duration(seconds: 15);

  final http.Client httpClient;

  void close() => httpClient.close();

  Future<List<KnownModel>> listModels({
    required String baseUrl,
    String apiKey = '',
    Duration timeout = _modelListTimeout,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedApiKey = apiKey.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    final uri = _buildEndpointUri(normalizedBaseUrl, 'models');
    developer.log('Fetching oMLX model catalog from $uri', name: _providerName);

    try {
      final response = await httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (normalizedApiKey.isNotEmpty)
                'Authorization': 'Bearer $normalizedApiKey',
            },
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InferenceHttpException(
          provider: _exceptionProvider,
          ModelCatalogMapping.extractErrorMessage(
            response.body,
            response.statusCode,
            providerLabel: 'oMLX',
          ),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = switch (decoded) {
        {'data': final List<dynamic> data} => data,
        final List<dynamic> data => data,
        _ => throw const InferenceHttpException(
          provider: _exceptionProvider,
          'oMLX model list response must be a JSON object with data[] '
          'or a JSON array',
        ),
      };

      return data
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const InferenceHttpException(
                provider: _exceptionProvider,
                'oMLX model entry must be a JSON object',
              );
            }
            return _knownModelFromPayload(item);
          })
          .toList(growable: false);
    } on InferenceHttpException {
      rethrow;
    } on TimeoutException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'oMLX model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'oMLX model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Failed to fetch oMLX models: $e',
        originalError: e,
      );
    }
  }

  KnownModel _knownModelFromPayload(Map<String, dynamic> model) {
    final providerModelId = model['id'] ?? model['name'];
    if (providerModelId is! String || providerModelId.trim().isEmpty) {
      throw const InferenceHttpException(
        provider: _exceptionProvider,
        'oMLX model entry is missing a string id',
      );
    }

    final knownModel = _knownOmlxModels[providerModelId];
    if (knownModel != null) {
      return knownModel;
    }

    final meta =
        ModelCatalogMapping.asMap(model['_meta']) ??
        ModelCatalogMapping.asMap(model['metadata']);
    // Merge top-level and metadata capability/modality fields rather than
    // letting one source shadow the other: a partially populated metadata
    // object would otherwise drop provider-supplied flags. Metadata wins on
    // key collisions for capabilities.
    final capabilities = <String, dynamic>{
      ...ModelCatalogMapping.asMap(model['capabilities']) ??
          const <String, dynamic>{},
      ...ModelCatalogMapping.asMap(meta?['capabilities']) ??
          const <String, dynamic>{},
    };
    final inputModalities = ModelCatalogMapping.modalitiesFrom(
      model['input_modalities'],
    );
    for (final modality in ModelCatalogMapping.modalitiesFrom(
      meta?['input_modalities'],
    )) {
      ModelCatalogMapping.addUniqueModality(inputModalities, modality);
    }
    final outputModalities = ModelCatalogMapping.modalitiesFrom(
      model['output_modalities'],
    );
    for (final modality in ModelCatalogMapping.modalitiesFrom(
      meta?['output_modalities'],
    )) {
      ModelCatalogMapping.addUniqueModality(outputModalities, modality);
    }

    _applyInferredModalities(
      providerModelId: providerModelId,
      capabilities: capabilities,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
    );

    final supportsFunctionCalling = ModelCatalogMapping.truthy(
      capabilities['function_calling'],
    );
    final isReasoningModel =
        ModelCatalogMapping.truthy(capabilities['reasoning']) ||
        _looksLikeReasoningModel(providerModelId);

    return KnownModel(
      providerModelId: providerModelId,
      name: ModelCatalogMapping.humanizeModelId(
        providerModelId,
        acronyms: _modelNameAcronyms,
      ),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
      supportsFunctionCalling: supportsFunctionCalling,
      description: _descriptionFor(
        model: model,
        providerModelId: providerModelId,
        capabilities: capabilities,
      ),
    );
  }

  void _applyInferredModalities({
    required String providerModelId,
    required Map<String, dynamic>? capabilities,
    required List<Modality> inputModalities,
    required List<Modality> outputModalities,
  }) {
    if (OmlxTranscriptionRepository.isOmlxTranscriptionModel(providerModelId)) {
      ModelCatalogMapping.addUniqueModality(inputModalities, Modality.audio);
      ModelCatalogMapping.addUniqueModality(outputModalities, Modality.text);
      return;
    }

    ModelCatalogMapping.addUniqueModality(inputModalities, Modality.text);
    ModelCatalogMapping.addUniqueModality(outputModalities, Modality.text);

    if (ModelCatalogMapping.truthy(capabilities?['vision']) ||
        ModelCatalogMapping.truthy(capabilities?['image_input']) ||
        _looksLikeVisionModel(providerModelId)) {
      ModelCatalogMapping.addUniqueModality(inputModalities, Modality.image);
    }
  }

  static bool _looksLikeVisionModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('vision') ||
        normalized.contains('-vl') ||
        normalized.contains('_vl') ||
        normalized.contains('/vl') ||
        normalized.contains('gemma-4') ||
        normalized.contains('qwen3.6');
  }

  static bool _looksLikeReasoningModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('qwen3') ||
        normalized.contains('deepseek') ||
        normalized.contains('reasoning') ||
        normalized.contains('thinking');
  }

  String _descriptionFor({
    required Map<String, dynamic> model,
    required String providerModelId,
    required Map<String, dynamic>? capabilities,
  }) {
    final parts = <String>['oMLX local model.'];

    final ownedBy = model['owned_by'];
    if (ownedBy is String && ownedBy.trim().isNotEmpty) {
      parts.add('Owned by ${ownedBy.trim()}.');
    }

    final featureLabels = <String>[
      if (ModelCatalogMapping.truthy(capabilities?['vision']) ||
          ModelCatalogMapping.truthy(capabilities?['image_input']) ||
          _looksLikeVisionModel(providerModelId))
        'vision',
      if (OmlxTranscriptionRepository.isOmlxTranscriptionModel(providerModelId))
        'audio transcription',
      if (ModelCatalogMapping.truthy(capabilities?['reasoning']) ||
          _looksLikeReasoningModel(providerModelId))
        'reasoning',
      if (ModelCatalogMapping.truthy(capabilities?['function_calling']))
        'tools',
    ];
    if (featureLabels.isNotEmpty) {
      parts.add('Features: ${featureLabels.join(', ')}.');
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
      throw InferenceHttpException(
        provider: _exceptionProvider,
        'Invalid base URL: $baseUrl',
        originalError: e,
      );
    }
  }
}

final Map<String, KnownModel> _knownOmlxModels = {
  for (final model in omlxModels) model.providerModelId: model,
};
