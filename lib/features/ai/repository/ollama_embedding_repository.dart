import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Repository for generating text embeddings via Ollama's `/api/embed` endpoint.
///
/// Uses `mxbai-embed-large` (1024 dimensions) by default. The returned
/// [Float32List] can be stored directly in [EmbeddingsDb].
///
/// Follows the same HTTP/retry/error patterns as [OllamaInferenceRepository].
class OllamaEmbeddingRepository {
  OllamaEmbeddingRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Overridable for tests to eliminate real delays.
  static Duration retryBaseDelay = const Duration(seconds: 2);

  /// Maximum number of retry attempts for transient errors.
  static const int _maxRetries = 3;

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

    final response = await _retryWithExponentialBackoff(
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

    if (response.statusCode == httpStatusNotFound) {
      final body = response.body.toLowerCase();
      if (body.contains('not found') || body.contains('model')) {
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
              throw Exception(
                'Embedding request timed out after $_maxRetries attempts. '
                'Is the Ollama server running?',
              );
            } else {
              throw Exception(
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
