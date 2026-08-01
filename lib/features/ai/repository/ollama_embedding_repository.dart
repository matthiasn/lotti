import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Repository for generating text embeddings via Ollama's `/api/embed` endpoint.
///
/// Uses `mxbai-embed-large` (1024 dimensions) by default. The returned
/// [Float32List] can be stored directly in an [EmbeddingStore].
///
/// Follows the same HTTP/retry/error patterns as [OllamaInferenceRepository].
class OllamaEmbeddingRepository {
  OllamaEmbeddingRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, _OllamaAvailabilityBackoff> _availabilityBackoff = {};

  /// Overridable for tests to eliminate real delays.
  static Duration retryBaseDelay = const Duration(seconds: 2);

  /// Maximum number of retry attempts for transient errors.
  static const int _maxRetries = 3;

  /// How long a confirmed Ollama outage suppresses optional embedding calls.
  static const Duration availabilityCooldown = Duration(minutes: 5);

  /// Generates an embedding vector for the given [input] text.
  ///
  /// Calls `POST $baseUrl/api/embed` with the specified [model] (defaults to
  /// [ollamaEmbedDefaultModel]).
  ///
  /// Returns a [Float32List] with exactly [kEmbeddingDimensions] elements.
  ///
  /// Throws [ModelNotInstalledException] if the model is not pulled locally.
  /// Throws [Exception] on timeout, network errors, or malformed responses.
  Future<Float32List> embed({
    required String input,
    required String baseUrl,
    String model = ollamaEmbedDefaultModel,
  }) async {
    if (input.isEmpty) {
      throw ArgumentError('OllamaEmbeddingRepository.embed(): input is empty');
    }

    _throwIfAvailabilityCoolingDown(baseUrl);

    final http.Response response;
    try {
      response = await _retryWithExponentialBackoff(
        operation: () => _httpClient
            .post(
              Uri.parse('$baseUrl$ollamaEmbedEndpoint'),
              headers: {'Content-Type': ollamaContentType},
              body: jsonEncode({
                'model': model,
                'input': input,
              }),
            )
            .timeout(
              const Duration(seconds: ollamaEmbedTimeoutSeconds),
            ),
        context: 'embedding generation',
      );
    } on _OllamaEmbeddingUnavailableException {
      _openAvailabilityCooldown(baseUrl);
      rethrow;
    }

    _markAvailable(baseUrl);

    if (response.statusCode == httpStatusNotFound) {
      final body = response.body.toLowerCase();
      if (body.contains('not found') && body.contains('model')) {
        throw ModelNotInstalledException(model);
      }
    }

    if (response.statusCode != httpStatusOk) {
      throw Exception(
        'Embedding request failed (HTTP ${response.statusCode}): '
        '${response.body}',
      );
    }

    return _parseEmbeddingResponse(response.body);
  }

  void _throwIfAvailabilityCoolingDown(String baseUrl) {
    final backoff = _availabilityBackoff[baseUrl];
    if (backoff == null || !clock.now().isBefore(backoff.retryAt)) return;

    backoff.suppressedRequestCount++;
    final exception = OllamaEmbeddingCooldownException(
      retryAt: backoff.retryAt,
      suppressedRequestCount: backoff.suppressedRequestCount,
    );
    if (exception.shouldLogSummary) {
      developer.log(
        'Ollama embedding availability cooldown suppressed '
        '${exception.suppressedRequestCount} request'
        '${exception.suppressedRequestCount == 1 ? '' : 's'}; '
        'next probe is allowed at '
        '${backoff.retryAt.toUtc().toIso8601String()}',
        name: 'OllamaEmbeddingRepository',
      );
    }
    throw exception;
  }

  void _openAvailabilityCooldown(String baseUrl) {
    final retryAt = clock.now().add(availabilityCooldown);
    final current = _availabilityBackoff[baseUrl];
    if (current == null) {
      _availabilityBackoff[baseUrl] = _OllamaAvailabilityBackoff(retryAt);
    } else {
      current.retryAt = retryAt;
    }
  }

  void _markAvailable(String baseUrl) {
    final recovered = _availabilityBackoff.remove(baseUrl);
    if (recovered == null) return;

    developer.log(
      'Ollama embeddings recovered after suppressing '
      '${recovered.suppressedRequestCount} request'
      '${recovered.suppressedRequestCount == 1 ? '' : 's'}',
      name: 'OllamaEmbeddingRepository',
    );
  }

  /// Parses the Ollama `/api/embed` JSON response into a [Float32List].
  ///
  /// Expected format: `{"embeddings": [[0.1, 0.2, ...]]}`
  Float32List _parseEmbeddingResponse(String body) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw Exception('Malformed embedding response: $e');
    }

    final embeddings = json['embeddings'];
    if (embeddings is! List || embeddings.isEmpty) {
      throw Exception(
        'Embedding response missing or empty "embeddings" field',
      );
    }

    final firstEmbedding = embeddings[0];
    if (firstEmbedding is! List) {
      throw Exception(
        'Embedding response: first embedding is not a list',
      );
    }

    if (firstEmbedding.length != kEmbeddingDimensions) {
      throw Exception(
        'Embedding dimension mismatch: '
        'got ${firstEmbedding.length}, '
        'expected $kEmbeddingDimensions',
      );
    }

    final result = Float32List(kEmbeddingDimensions);
    for (var i = 0; i < kEmbeddingDimensions; i++) {
      result[i] = (firstEmbedding[i] as num).toDouble();
    }
    return result;
  }

  /// Retries [operation] with exponential backoff on transient errors.
  Future<T> _retryWithExponentialBackoff<T>({
    required Future<T> Function() operation,
    required String context,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation();
      } on Exception catch (e) {
        if (e is TimeoutException || e is SocketException) {
          if (attempt >= _maxRetries) {
            if (e is TimeoutException) {
              throw const _OllamaEmbeddingUnavailableException(
                'Embedding request timed out after $_maxRetries attempts. '
                'Is the Ollama server running?',
              );
            } else {
              throw _OllamaEmbeddingUnavailableException(
                'Network error during $context after $_maxRetries attempts. '
                'Is the Ollama server running?',
              );
            }
          }
          final reason = e is TimeoutException ? 'Timeout' : 'Network error';
          developer.log(
            '$reason during $context, retrying (attempt $attempt)...',
            name: 'OllamaEmbeddingRepository',
          );
          await Future<void>.delayed(retryBaseDelay * (1 << (attempt - 1)));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Closes the underlying HTTP client.
  void close() {
    _httpClient.close();
  }
}

/// A transient Ollama outage confirmed after the repository's retry budget.
class _OllamaEmbeddingUnavailableException implements Exception {
  const _OllamaEmbeddingUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A fast failure while a previously confirmed Ollama outage is cooling down.
///
/// [suppressedRequestCount] is cumulative for the current outage and lets
/// callers report sampled summaries without emitting a stack trace per item.
class OllamaEmbeddingCooldownException implements Exception {
  const OllamaEmbeddingCooldownException({
    required this.retryAt,
    required this.suppressedRequestCount,
  });

  final DateTime retryAt;
  final int suppressedRequestCount;

  /// Whether this cumulative count should produce a compact diagnostic.
  ///
  /// Powers of two retain growth visibility with logarithmic log volume.
  bool get shouldLogSummary =>
      suppressedRequestCount > 0 &&
      suppressedRequestCount & (suppressedRequestCount - 1) == 0;

  @override
  String toString() =>
      'Ollama embedding request suppressed during availability cooldown '
      '(count=$suppressedRequestCount, retryAt=${retryAt.toUtc().toIso8601String()})';
}

class _OllamaAvailabilityBackoff {
  _OllamaAvailabilityBackoff(this.retryAt);

  DateTime retryAt;
  int suppressedRequestCount = 0;
}
