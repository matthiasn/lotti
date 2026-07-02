import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:lotti/features/ai/repository/model_catalog_mapping.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:meta/meta.dart';

/// Fetches Google Gemini's live model catalog for the settings UI.
///
/// Unlike the OpenAI-compatible `/models` surface (which returns bare ids),
/// Gemini's native `GET /v1beta/models` listing carries rich per-model
/// metadata: `displayName`, `description`, `inputTokenLimit`,
/// `outputTokenLimit`, `supportedGenerationMethods`, and (on 2.5+ models) a
/// `thinking` flag. This repository maps that metadata into the app's
/// [KnownModel] shape so a freshly released Gemini model can be installed from
/// settings without shipping a new curated entry.
///
/// Ids that already exist in the curated [geminiModels] list are returned
/// verbatim so their hand-tuned modalities and descriptions survive; unknown
/// ids are derived from the live metadata plus conservative id heuristics,
/// because the native listing describes token limits and generation methods
/// rather than input/output modalities directly.
///
/// Authentication uses the `x-goog-api-key` header rather than a `?key=` query
/// parameter, so the API key never appears in the request URL (and therefore
/// can't leak through proxy/access logs or an exception that echoes the URI).
class GeminiModelsRepository {
  GeminiModelsRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const _providerName = 'GeminiModelsRepository';

  /// Default timeout for a single catalog page request.
  @visibleForTesting
  static const modelListTimeout = Duration(seconds: 15);

  /// Page size requested from the native listing. Gemini caps this at 1000.
  @visibleForTesting
  static const modelListPageSize = 1000;

  /// Hard cap on paginated fetches, guarding against a server that keeps
  /// returning a `nextPageToken`. Well above any realistic Gemini catalog.
  @visibleForTesting
  static const maxCatalogPages = 20;

  void close() => _httpClient.close();

  /// Fetches the live Gemini model catalog and maps each row into a
  /// [KnownModel]. Follows `nextPageToken` pagination up to [maxCatalogPages].
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
      throw const GeminiModelsException('Base URL cannot be empty');
    }
    if (normalizedApiKey.isEmpty) {
      throw const GeminiModelsException('API key cannot be empty');
    }

    final models = <KnownModel>[];
    final seenIds = <String>{};
    String? pageToken;
    var page = 0;

    do {
      final result = await _fetchPage(
        baseUrl: normalizedBaseUrl,
        apiKey: normalizedApiKey,
        pageToken: pageToken,
        timeout: timeout,
      );
      pageToken = result.nextPageToken;
      for (final (index, row) in result.rows.indexed) {
        final KnownModel? known;
        try {
          known = _knownModelFromPayload(row);
        } on GeminiModelsException catch (e) {
          developer.log(
            'Skipping malformed Gemini model row on page ${page + 1} #$index',
            name: _providerName,
            error: e,
          );
          continue;
        }
        // A row can be surfaced twice across pages if the catalog changes
        // mid-fetch; keep the first mapping and drop non-installable rows.
        if (known != null && seenIds.add(known.providerModelId)) {
          models.add(known);
        }
      }
      page++;
    } while (pageToken != null &&
        pageToken.isNotEmpty &&
        page < maxCatalogPages);

    return models;
  }

  Future<({List<Map<String, dynamic>> rows, String? nextPageToken})>
  _fetchPage({
    required String baseUrl,
    required String apiKey,
    required String? pageToken,
    required Duration timeout,
  }) async {
    final Uri uri;
    try {
      uri = GeminiUtils.buildListModelsUri(
        baseUrl: baseUrl,
        pageSize: modelListPageSize,
        pageToken: pageToken,
      );
    } on FormatException catch (e) {
      // `Uri.parse` throws on malformed input (e.g. unbalanced IPv6 brackets).
      // Never echo the raw base URL — a FormatException's message embeds a
      // slice of the offending source.
      throw GeminiModelsException('Invalid Gemini base URL', originalError: e);
    }
    // A scheme-less/host-less base URL yields an empty host; reject it before
    // requesting so the low-level HTTP client can't throw an ArgumentError that
    // echoes the request URI. Never echo the raw base URL either.
    if (uri.host.isEmpty) {
      throw const GeminiModelsException('Invalid Gemini base URL');
    }
    developer.log(
      'Fetching Gemini model catalog from '
      '${ModelCatalogMapping.redactedEndpoint(uri)}',
      name: _providerName,
    );

    try {
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'x-goog-api-key': apiKey,
            },
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GeminiModelsException(
          ModelCatalogMapping.extractErrorMessage(
            response.body,
            response.statusCode,
            providerLabel: 'Gemini',
          ),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const GeminiModelsException(
          'Gemini model list response must be a JSON object',
        );
      }

      final nextToken = decoded['nextPageToken'];
      final rawModels = decoded['models'];
      if (rawModels == null) {
        // A page with no `models` key is a valid empty listing.
        return (
          rows: const <Map<String, dynamic>>[],
          nextPageToken: nextToken is String ? nextToken : null,
        );
      }
      if (rawModels is! List) {
        throw const GeminiModelsException(
          'Gemini model list "models" field must be an array',
        );
      }

      return (
        rows: rawModels.whereType<Map<String, dynamic>>().toList(
          growable: false,
        ),
        nextPageToken: nextToken is String ? nextToken : null,
      );
    } on GeminiModelsException {
      rethrow;
    } on TimeoutException catch (e) {
      throw GeminiModelsException(
        'Gemini model list request timed out',
        originalError: e,
      );
    } on FormatException catch (e) {
      throw GeminiModelsException(
        'Gemini model list response was not valid JSON',
        originalError: e,
      );
    } on Exception catch (e) {
      throw GeminiModelsException(
        'Failed to fetch Gemini models: $e',
        originalError: e,
      );
    }
  }

  /// Maps a single native catalog row into a [KnownModel], or returns `null`
  /// for rows that map onto no app-supported flow (embedding/token-count-only
  /// models that don't expose `generateContent`).
  KnownModel? _knownModelFromPayload(Map<String, dynamic> model) {
    final rawName = model['name'];
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const GeminiModelsException(
        'Gemini model entry is missing a string name',
      );
    }
    final providerModelId = rawName.trim();

    // Curated entries win verbatim so their hand-tuned modalities and copy
    // survive a live refresh.
    final curated = _curatedGeminiModels[providerModelId];
    if (curated != null) return curated;

    final methods = _generationMethods(model['supportedGenerationMethods']);
    // Only models that can actually generate content are installable. Pure
    // embedding (`embedContent`) or answer-attribution (`generateAnswer`)
    // rows are dropped so they can't be added as chat models.
    if (methods.isNotEmpty && !methods.contains('generatecontent')) {
      return null;
    }

    final classification = _classify(providerModelId, model);

    final displayName = model['displayName'];
    final name = displayName is String && displayName.trim().isNotEmpty
        ? displayName.trim()
        : ModelCatalogMapping.humanizeModelId(
            providerModelId,
            acronyms: _acronyms,
          );

    return KnownModel(
      providerModelId: providerModelId,
      name: name,
      inputModalities: classification.inputModalities,
      outputModalities: classification.outputModalities,
      isReasoningModel: classification.isReasoningModel,
      supportsFunctionCalling: classification.supportsFunctionCalling,
      description: _descriptionFor(model),
    );
  }

  /// Derives modalities and capability flags for an uncurated Gemini id.
  ///
  /// The native listing doesn't carry modality metadata, so this leans on
  /// id shape:
  /// - `*image*` → an image-generation model (text + image in/out, no tools).
  /// - `*tts*` → a text-to-speech model (text in, audio out).
  /// - `gemini-*` → a natively multimodal chat model (text + image + audio in,
  ///   text out, tools) that reasons when the live `thinking` flag is set or
  ///   the id looks like a 2.5/3 model.
  /// - anything else (e.g. Gemma) → a conservative text-only chat model with no
  ///   tools, since those families don't accept audio and vary in vision/tool
  ///   support.
  static _GeminiClassification _classify(
    String providerModelId,
    Map<String, dynamic> model,
  ) {
    final input = <Modality>[];
    final output = <Modality>[];

    if (_looksLikeImageModel(providerModelId)) {
      ModelCatalogMapping.addUniqueModality(input, Modality.text);
      ModelCatalogMapping.addUniqueModality(input, Modality.image);
      ModelCatalogMapping.addUniqueModality(output, Modality.text);
      ModelCatalogMapping.addUniqueModality(output, Modality.image);
      return _GeminiClassification(
        inputModalities: input,
        outputModalities: output,
      );
    }

    if (_looksLikeTtsModel(providerModelId)) {
      ModelCatalogMapping.addUniqueModality(input, Modality.text);
      ModelCatalogMapping.addUniqueModality(output, Modality.audio);
      return _GeminiClassification(
        inputModalities: input,
        outputModalities: output,
      );
    }

    ModelCatalogMapping.addUniqueModality(input, Modality.text);
    ModelCatalogMapping.addUniqueModality(output, Modality.text);

    if (!_looksLikeGeminiModel(providerModelId)) {
      // Non-Gemini families (Gemma, …) served through the Gemini API: keep them
      // installable but claim nothing beyond text in/out.
      return _GeminiClassification(
        inputModalities: input,
        outputModalities: output,
      );
    }

    // Gemini chat models are natively multimodal on input.
    ModelCatalogMapping.addUniqueModality(input, Modality.image);
    ModelCatalogMapping.addUniqueModality(input, Modality.audio);

    final isReasoning =
        ModelCatalogMapping.truthy(model['thinking']) ||
        _looksLikeReasoningModel(providerModelId);
    return _GeminiClassification(
      inputModalities: input,
      outputModalities: output,
      supportsFunctionCalling: true,
      isReasoningModel: isReasoning,
    );
  }

  static Set<String> _generationMethods(Object? raw) {
    if (raw is! List) return const {};
    return raw
        .map((value) => '$value'.toLowerCase().trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  String _descriptionFor(Map<String, dynamic> model) {
    final parts = <String>[];

    final description = model['description'];
    if (description is String && description.trim().isNotEmpty) {
      parts.add(description.trim());
    }

    final inputTokenLimit = ModelCatalogMapping.integerValue(
      model['inputTokenLimit'],
    );
    if (inputTokenLimit != null) {
      parts.add('Input limit: $inputTokenLimit tokens.');
    }
    final outputTokenLimit = ModelCatalogMapping.integerValue(
      model['outputTokenLimit'],
    );
    if (outputTokenLimit != null) {
      parts.add('Output limit: $outputTokenLimit tokens.');
    }

    return parts.join(' ');
  }

  static bool _looksLikeImageModel(String modelId) {
    return modelId.toLowerCase().contains('image');
  }

  static bool _looksLikeTtsModel(String modelId) {
    return modelId.toLowerCase().contains('tts');
  }

  static bool _looksLikeGeminiModel(String modelId) {
    return modelId.toLowerCase().contains('gemini');
  }

  static bool _looksLikeReasoningModel(String modelId) {
    final normalized = modelId.toLowerCase();
    return normalized.contains('thinking') ||
        normalized.contains('gemini-2.5') ||
        normalized.contains('gemini-3');
  }

  static const _acronyms = {'AI', 'API', 'TTS', 'VL'};
}

/// Capability + modality classification for an uncurated Gemini catalog row.
class _GeminiClassification {
  _GeminiClassification({
    required this.inputModalities,
    required this.outputModalities,
    this.supportsFunctionCalling = false,
    this.isReasoningModel = false,
  });

  final List<Modality> inputModalities;
  final List<Modality> outputModalities;
  final bool supportsFunctionCalling;
  final bool isReasoningModel;
}

final Map<String, KnownModel> _curatedGeminiModels = {
  for (final model in geminiModels) model.providerModelId: model,
};

/// Exception thrown when the Gemini model catalog fetch fails.
class GeminiModelsException implements Exception {
  const GeminiModelsException(
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
    return 'GeminiModelsException$status: $message$cause';
  }
}
