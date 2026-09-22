import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/services/domain_logging.dart';

/// Thrown, without a network call, while an Ollama base URL is in its outage
/// cooldown.
///
/// Embeddings are optional everywhere they are used, so callers treat this
/// like any other failed embedding: skip it and keep their own work.
class EmbeddingEndpointUnavailableException implements Exception {
  const EmbeddingEndpointUnavailableException({
    required this.baseUrl,
    required this.retryAt,
  });

  final String baseUrl;

  /// When the next call may probe the endpoint again.
  final DateTime retryAt;

  @override
  String toString() =>
      'Ollama embeddings at ${redactEndpoint(baseUrl)} are unavailable; '
      'the next attempt is allowed at ${retryAt.toIso8601String()}';
}

/// [baseUrl] reduced to scheme, host and port, for logs and messages.
///
/// A configured base URL may carry credentials in its user info, or a token
/// in its path or query behind a reverse proxy; none of that may reach a log
/// file. An unparsable URL is not echoed at all.
String redactEndpoint(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return '<unparsable Ollama URL>';
  }
  return uri.hasPort
      ? '${uri.scheme}://${uri.host}:${uri.port}'
      : '${uri.scheme}://${uri.host}';
}

/// Repository for generating text embeddings via Ollama's `/api/embed` endpoint.
///
/// Uses `mxbai-embed-large` (1024 dimensions) by default. The returned
/// [Float32List] can be stored directly in an [EmbeddingStore].
///
/// Follows the same HTTP/retry/error patterns as [OllamaInferenceRepository].
///
/// **Availability.** Each base URL has a circuit breaker, shared by every
/// caller because the app registers one instance. The first call to an
/// unconfirmed endpoint — at startup, or once a cooldown has elapsed — is its
/// probe; concurrent callers wait for that probe instead of each opening a
/// connection. A probe or call that spends the whole transport retry budget
/// (timeouts and socket errors) declares an outage, and every call before
/// [outageCooldown] has passed fails fast with
/// [EmbeddingEndpointUnavailableException]. Any HTTP response, even an error
/// status, proves the endpoint reachable. A failure that started before a
/// newer success is stale and cannot reopen the outage. Suppressed calls are
/// counted per endpoint and reported only at powers of two, so a long outage
/// logs a handful of lines rather than one per entry.
class OllamaEmbeddingRepository {
  OllamaEmbeddingRepository({
    http.Client? httpClient,
    this._domainLogger,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final DomainLogger? _domainLogger;

  /// How long a confirmed outage suppresses calls before the next probe.
  static const Duration outageCooldown = Duration(minutes: 5);

  final Map<String, _EndpointCircuit> _circuits = {};

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
  /// Throws [EmbeddingEndpointUnavailableException] without a network call
  /// while [baseUrl] is in its outage cooldown.
  /// Throws [Exception] on timeout, network errors, or malformed responses.
  Future<Float32List> embed({
    required String input,
    required String baseUrl,
    String model = ollamaEmbedDefaultModel,
  }) async {
    if (input.isEmpty) {
      throw ArgumentError('OllamaEmbeddingRepository.embed(): input is empty');
    }

    final circuit = _circuits.putIfAbsent(baseUrl, _EndpointCircuit.new);
    final probe = await _admit(circuit, baseUrl);
    final generation = circuit.generation;
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
      _recordReachable(circuit, baseUrl);
    } on _TransportExhaustedException catch (exhausted) {
      _recordOutage(circuit, baseUrl, startedAt: generation);
      throw exhausted.error;
    } finally {
      if (probe != null) {
        circuit.probe = null;
        probe.complete();
      }
    }

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

  /// Waits until [circuit] admits a network call to [baseUrl].
  ///
  /// Returns the probe completer when this caller is the endpoint's probe, or
  /// null for an ordinary call to a confirmed endpoint. Throws
  /// [EmbeddingEndpointUnavailableException] during a cooldown, including for
  /// callers that waited on a probe which confirmed the outage.
  Future<Completer<void>?> _admit(
    _EndpointCircuit circuit,
    String baseUrl,
  ) async {
    while (true) {
      final retryAt = circuit.retryAt;
      if (retryAt != null && clock.now().isBefore(retryAt)) {
        circuit.suppressed++;
        if (_isPowerOfTwo(circuit.suppressed)) {
          _log(
            'suppressed ${circuit.suppressed} embedding calls to '
            '${redactEndpoint(baseUrl)} '
            'during outages; next attempt at ${retryAt.toIso8601String()}',
          );
        }
        throw EmbeddingEndpointUnavailableException(
          baseUrl: baseUrl,
          retryAt: retryAt,
        );
      }
      if (circuit.confirmed) return null;
      final pending = circuit.probe;
      if (pending == null) {
        return circuit.probe = Completer<void>();
      }
      await pending.future;
    }
  }

  void _recordReachable(_EndpointCircuit circuit, String baseUrl) {
    final recovered = circuit.retryAt != null;
    circuit
      ..confirmed = true
      ..retryAt = null
      ..generation += 1;
    if (recovered) {
      _log(
        'embedding endpoint ${redactEndpoint(baseUrl)} is reachable again',
      );
    }
  }

  /// Opens the outage unless a success landed after this call began.
  void _recordOutage(
    _EndpointCircuit circuit,
    String baseUrl, {
    required int startedAt,
  }) {
    if (circuit.generation != startedAt) return;
    final retryAt = clock.now().add(outageCooldown);
    circuit
      ..confirmed = false
      ..retryAt = retryAt
      ..generation += 1;
    _log(
      'embedding endpoint ${redactEndpoint(baseUrl)} is unreachable; '
      'suppressing calls until '
      '${retryAt.toIso8601String()}',
      level: InsightLevel.warn,
    );
  }

  void _log(String message, {InsightLevel level = InsightLevel.info}) {
    _domainLogger?.log(
      LogDomain.ai,
      message,
      subDomain: 'embedding_availability',
      level: level,
    );
  }

  static bool _isPowerOfTwo(int value) => value & (value - 1) == 0;

  /// Retries [operation] with exponential backoff on transient errors.
  ///
  /// Throws [_TransportExhaustedException] once the retry budget is spent, so
  /// the caller can tell an unreachable endpoint from any other failure.
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
            throw _TransportExhaustedException(
              e is TimeoutException
                  ? Exception(
                      'Embedding request timed out after $_maxRetries '
                      'attempts. Is the Ollama server running?',
                    )
                  : Exception(
                      'Network error during $context after $_maxRetries '
                      'attempts. Is the Ollama server running?',
                    ),
            );
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

/// Availability of one Ollama base URL, shared by every caller.
class _EndpointCircuit {
  /// Whether a call has reached the endpoint since the last outage.
  bool confirmed = false;

  /// End of the current outage cooldown, or null when none is open.
  DateTime? retryAt;

  /// The in-flight probe other callers wait on.
  Completer<void>? probe;

  /// Bumped by every success and every declared outage, so a failure can
  /// tell whether anything newer has been learned since it started.
  int generation = 0;

  /// Calls suppressed across all outages, for logarithmic reporting.
  int suppressed = 0;
}

/// The transport retry budget ran out; [error] is what the caller sees.
class _TransportExhaustedException implements Exception {
  const _TransportExhaustedException(this.error);

  final Exception error;
}
