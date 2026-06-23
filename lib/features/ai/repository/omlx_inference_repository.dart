import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/omlx_transcription_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';

/// Repository for oMLX's local OpenAI-compatible inference surface.
///
/// oMLX exposes the standard `/models` endpoint. The response generally only
/// contains model IDs, so this repository preserves rich metadata for IDs that
/// are already in the bundled oMLX catalog and applies conservative heuristics
/// for unknown local models.
class OmlxInferenceRepository {
  OmlxInferenceRepository({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

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
        throw OmlxInferenceException(
          _extractErrorMessage(response.body, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final data = switch (decoded) {
        {'data': final List<dynamic> data} => data,
        final List<dynamic> data => data,
        _ => throw const OmlxInferenceException(
          'oMLX model list response must be a JSON object with data[] '
          'or a JSON array',
        ),
      };

      return data
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const OmlxInferenceException(
                'oMLX model entry must be a JSON object',
              );
            }
            return _knownModelFromPayload(item);
          })
          .toList(growable: false);
    } on OmlxInferenceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw OmlxInferenceException(
        'oMLX model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw OmlxInferenceException(
        'oMLX model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw OmlxInferenceException(
        'Failed to fetch oMLX models: $e',
        originalError: e,
      );
    }
  }

  KnownModel _knownModelFromPayload(Map<String, dynamic> model) {
    final providerModelId = model['id'] ?? model['name'];
    if (providerModelId is! String || providerModelId.trim().isEmpty) {
      throw const OmlxInferenceException(
        'oMLX model entry is missing a string id',
      );
    }

    final knownModel = _knownOmlxModels[providerModelId];
    if (knownModel != null) {
      return knownModel;
    }

    final meta = _asMap(model['_meta']) ?? _asMap(model['metadata']);
    // Merge top-level and metadata capability/modality fields rather than
    // letting one source shadow the other: a partially populated metadata
    // object would otherwise drop provider-supplied flags. Metadata wins on
    // key collisions for capabilities.
    final capabilities = <String, dynamic>{
      ..._asMap(model['capabilities']) ?? const <String, dynamic>{},
      ..._asMap(meta?['capabilities']) ?? const <String, dynamic>{},
    };
    final inputModalities = _modalitiesFrom(model['input_modalities']);
    for (final modality in _modalitiesFrom(meta?['input_modalities'])) {
      _addUnique(inputModalities, modality);
    }
    final outputModalities = _modalitiesFrom(model['output_modalities']);
    for (final modality in _modalitiesFrom(meta?['output_modalities'])) {
      _addUnique(outputModalities, modality);
    }

    _applyInferredModalities(
      providerModelId: providerModelId,
      capabilities: capabilities,
      inputModalities: inputModalities,
      outputModalities: outputModalities,
    );

    final supportsFunctionCalling = _truthy(capabilities['function_calling']);
    final isReasoningModel =
        _truthy(capabilities['reasoning']) ||
        _looksLikeReasoningModel(providerModelId);

    return KnownModel(
      providerModelId: providerModelId,
      name: _displayNameForModel(providerModelId),
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
      _addUnique(inputModalities, Modality.audio);
      _addUnique(outputModalities, Modality.text);
      return;
    }

    _addUnique(inputModalities, Modality.text);
    _addUnique(outputModalities, Modality.text);

    if (_truthy(capabilities?['vision']) ||
        _truthy(capabilities?['image_input']) ||
        _looksLikeVisionModel(providerModelId)) {
      _addUnique(inputModalities, Modality.image);
    }
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static List<Modality> _modalitiesFrom(Object? raw) {
    if (raw is! List) return <Modality>[];
    final out = <Modality>[];
    for (final value in raw) {
      switch ('$value'.toLowerCase().trim()) {
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

  static bool _truthy(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
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
      if (_truthy(capabilities?['vision']) ||
          _truthy(capabilities?['image_input']) ||
          _looksLikeVisionModel(providerModelId))
        'vision',
      if (OmlxTranscriptionRepository.isOmlxTranscriptionModel(providerModelId))
        'audio transcription',
      if (_truthy(capabilities?['reasoning']) ||
          _looksLikeReasoningModel(providerModelId))
        'reasoning',
      if (_truthy(capabilities?['function_calling'])) 'tools',
    ];
    if (featureLabels.isNotEmpty) {
      parts.add('Features: ${featureLabels.join(', ')}.');
    }

    return parts.join(' ');
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
    if (acronyms.contains(upper)) return upper;
    if (RegExp(r'^[a-z]?\d+[a-z]?$', caseSensitive: false).hasMatch(word)) {
      return upper;
    }
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }

  static Uri _buildEndpointUri(String baseUrl, String endpointPath) {
    try {
      final baseUri = Uri.parse(baseUrl.trim());
      final basePath = baseUri.path.replaceAll(RegExp(r'/+$'), '');
      final normalizedEndpoint = endpointPath.replaceAll(RegExp('^/+'), '');

      return baseUri.replace(path: '$basePath/$normalizedEndpoint');
    } on FormatException catch (e) {
      throw OmlxInferenceException(
        'Invalid base URL: $baseUrl',
        originalError: e,
      );
    }
  }

  static String _extractErrorMessage(String body, int statusCode) {
    final fallback = 'oMLX API error (HTTP $statusCode)';
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
    return body.length > 160 ? '${body.substring(0, 160)}…' : body;
  }
}

final Map<String, KnownModel> _knownOmlxModels = {
  for (final model in omlxModels) model.providerModelId: model,
};

class OmlxInferenceException implements Exception {
  const OmlxInferenceException(
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
    return 'OmlxInferenceException$status: $message$cause';
  }
}
