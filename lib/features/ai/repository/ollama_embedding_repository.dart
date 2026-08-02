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

/// Wraps one already-reserved Ollama embedding provider invocation.
///
/// The repository reserves endpoint availability before calling this wrapper,
/// so attribution can begin only for work that is allowed to reach Ollama.
typedef OllamaEmbeddingInvocationWrapper =
    Future<Float32List> Function(
      Future<Float32List> Function() invoke,
    );

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
  /// Throws [OllamaEmbeddingAvailabilityException] when exhausted transport
  /// retries should pause or requeue optional work. A concurrent successful
  /// request can keep the shared endpoint available while this call receives
  /// an immediate retry marker. Other response and parsing failures surface as
  /// [Exception].
  Future<Float32List> embed({
    required String input,
    required String baseUrl,
    String model = ollamaEmbedDefaultModel,
    OllamaEmbeddingInvocationWrapper? invocationWrapper,
  }) async {
    if (input.isEmpty) {
      throw ArgumentError('OllamaEmbeddingRepository.embed(): input is empty');
    }

    final availabilityAttempt = await _reserveAvailabilityAttempt(baseUrl);
    var providerInvocationStarted = false;

    Future<Float32List> invokeProvider() async {
      if (providerInvocationStarted) {
        throw StateError(
          'An Ollama embedding invocation wrapper must invoke the provider '
          'exactly once.',
        );
      }
      providerInvocationStarted = true;

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
      } on _OllamaEmbeddingTransportException catch (error, stackTrace) {
        // A newer concurrent success advances the endpoint generation and
        // deliberately prevents this stale failure from opening a cooldown.
        // The individual request still exhausted its transport budget, so
        // classify it for immediate requeue instead of leaking the private
        // transport exception through a generic caller catch.
        final retryAt =
            _openAvailabilityCooldown(availabilityAttempt) ?? clock.now();
        Error.throwWithStackTrace(
          OllamaEmbeddingUnavailableException(
            error.message,
            retryAt: retryAt,
          ),
          stackTrace,
        );
      } on Object {
        _releaseAvailabilityProbe(availabilityAttempt);
        rethrow;
      }

      _markAvailable(availabilityAttempt);

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

    if (invocationWrapper == null) {
      return invokeProvider();
    }

    try {
      final result = await invocationWrapper(invokeProvider);
      if (!providerInvocationStarted) {
        _releaseAvailabilityProbe(availabilityAttempt);
        throw StateError(
          'An Ollama embedding invocation wrapper did not invoke the provider.',
        );
      }
      return result;
    } on Object {
      if (!providerInvocationStarted) {
        _releaseAvailabilityProbe(availabilityAttempt);
      }
      rethrow;
    }
  }

  Future<_OllamaAvailabilityAttempt> _reserveAvailabilityAttempt(
    String baseUrl,
  ) async {
    while (true) {
      final now = clock.now();
      final existing = _availabilityBackoff[baseUrl];
      if (existing == null) {
        final initial = _OllamaAvailabilityBackoff(
          phase: _OllamaAvailabilityPhase.probing,
          retryAt: now.add(availabilityCooldown),
          activeProbe: Completer<void>(),
        );
        _availabilityBackoff[baseUrl] = initial;
        return _OllamaAvailabilityAttempt(
          baseUrl: baseUrl,
          generation: initial.generation,
        );
      }

      if (existing.phase == _OllamaAvailabilityPhase.available) {
        return _OllamaAvailabilityAttempt(
          baseUrl: baseUrl,
          generation: existing.generation,
        );
      }

      if (existing.phase == _OllamaAvailabilityPhase.probing) {
        await existing.activeProbe.future;
        continue;
      }

      if (!now.isBefore(existing.retryAt)) {
        existing
          ..phase = _OllamaAvailabilityPhase.probing
          ..retryAt = now.add(availabilityCooldown)
          ..activeProbe = Completer<void>();
        return _OllamaAvailabilityAttempt(
          baseUrl: baseUrl,
          generation: existing.generation,
        );
      }

      existing.suppressedRequestCount++;
      final exception = OllamaEmbeddingCooldownException(
        retryAt: existing.retryAt,
        suppressedRequestCount: existing.suppressedRequestCount,
      );
      if (exception.shouldLogSummary) {
        developer.log(
          'Ollama embedding availability cooldown suppressed '
          '${exception.suppressedRequestCount} request'
          '${exception.suppressedRequestCount == 1 ? '' : 's'}; '
          'next probe is allowed at '
          '${existing.retryAt.toUtc().toIso8601String()}',
          name: 'OllamaEmbeddingRepository',
        );
      }
      throw exception;
    }
  }

  DateTime? _openAvailabilityCooldown(_OllamaAvailabilityAttempt attempt) {
    final current = _availabilityBackoff[attempt.baseUrl];
    if (current == null) {
      return null;
    }
    if (current.generation != attempt.generation) {
      return current.phase == _OllamaAvailabilityPhase.coolingDown &&
              current.outageConfirmed
          ? current.retryAt
          : null;
    }

    final retryAt = clock.now().add(availabilityCooldown);
    current
      ..phase = _OllamaAvailabilityPhase.coolingDown
      ..retryAt = retryAt
      ..outageConfirmed = true
      ..generation = current.generation + 1;
    _completeAvailabilityProbe(current);
    return retryAt;
  }

  void _releaseAvailabilityProbe(_OllamaAvailabilityAttempt attempt) {
    final current = _availabilityBackoff[attempt.baseUrl];
    if (current == null ||
        current.generation != attempt.generation ||
        current.phase != _OllamaAvailabilityPhase.probing) {
      return;
    }

    current
      ..phase = _OllamaAvailabilityPhase.coolingDown
      ..retryAt = clock.now()
      ..generation = current.generation + 1;
    _completeAvailabilityProbe(current);
  }

  void _markAvailable(_OllamaAvailabilityAttempt attempt) {
    final current = _availabilityBackoff[attempt.baseUrl];
    if (current == null) return;

    final suppressedRequestCount = current.suppressedRequestCount;
    final shouldLogRecovery =
        current.outageConfirmed || suppressedRequestCount > 0;
    current
      ..phase = _OllamaAvailabilityPhase.available
      ..retryAt = clock.now()
      ..suppressedRequestCount = 0
      ..outageConfirmed = false
      ..generation = current.generation + 1;
    _completeAvailabilityProbe(current);

    if (!shouldLogRecovery) return;

    developer.log(
      'Ollama embeddings recovered after suppressing '
      '$suppressedRequestCount request'
      '${suppressedRequestCount == 1 ? '' : 's'}',
      name: 'OllamaEmbeddingRepository',
    );
  }

  void _completeAvailabilityProbe(_OllamaAvailabilityBackoff backoff) {
    final activeProbe = backoff.activeProbe;
    if (!activeProbe.isCompleted) {
      activeProbe.complete();
    }
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
        final isTimeout = e is TimeoutException;
        final isNetworkError =
            e is SocketException || e is http.ClientException;
        if (isTimeout || isNetworkError) {
          if (attempt >= _maxRetries) {
            if (isTimeout) {
              throw const _OllamaEmbeddingTransportException(
                'Embedding request timed out after $_maxRetries attempts. '
                'Is the Ollama server running?',
              );
            } else {
              throw _OllamaEmbeddingTransportException(
                'Network error during $context after $_maxRetries attempts. '
                'Is the Ollama server running?',
              );
            }
          }
          final reason = isTimeout ? 'Timeout' : 'Network error';
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
    _availabilityBackoff.values.forEach(_completeAvailabilityProbe);
    _availabilityBackoff.clear();
    _httpClient.close();
  }
}

/// Base type for Ollama availability failures that should pause optional work.
sealed class OllamaEmbeddingAvailabilityException implements Exception {
  const OllamaEmbeddingAvailabilityException();

  DateTime get retryAt;

  /// Whether a caller should emit its compact availability diagnostic.
  bool get shouldLogDiagnostic => true;
}

/// A transient Ollama outage confirmed after the repository's retry budget.
class OllamaEmbeddingUnavailableException
    extends OllamaEmbeddingAvailabilityException {
  const OllamaEmbeddingUnavailableException(
    this.message, {
    required this.retryAt,
  });

  final String message;

  @override
  final DateTime retryAt;

  @override
  String toString() => message;
}

/// A fast failure while a previously confirmed Ollama outage is cooling down.
///
/// [suppressedRequestCount] is cumulative for the current outage and lets
/// callers report sampled summaries without emitting a stack trace per item.
class OllamaEmbeddingCooldownException
    extends OllamaEmbeddingAvailabilityException {
  const OllamaEmbeddingCooldownException({
    required this.retryAt,
    required this.suppressedRequestCount,
  });

  @override
  final DateTime retryAt;
  final int suppressedRequestCount;

  /// Whether this cumulative count should produce a compact diagnostic.
  ///
  /// Powers of two retain growth visibility with logarithmic log volume.
  bool get shouldLogSummary =>
      suppressedRequestCount > 0 &&
      suppressedRequestCount & (suppressedRequestCount - 1) == 0;

  @override
  bool get shouldLogDiagnostic => shouldLogSummary;

  @override
  String toString() =>
      'Ollama embedding request suppressed during availability cooldown '
      '(count=$suppressedRequestCount, retryAt=${retryAt.toUtc().toIso8601String()})';
}

class _OllamaEmbeddingTransportException implements Exception {
  const _OllamaEmbeddingTransportException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum _OllamaAvailabilityPhase { probing, available, coolingDown }

class _OllamaAvailabilityAttempt {
  const _OllamaAvailabilityAttempt({
    required this.baseUrl,
    required this.generation,
  });

  final String baseUrl;
  final int generation;
}

class _OllamaAvailabilityBackoff {
  _OllamaAvailabilityBackoff({
    required this.phase,
    required this.retryAt,
    required this.activeProbe,
  });

  _OllamaAvailabilityPhase phase;
  DateTime retryAt;
  int suppressedRequestCount = 0;
  int generation = 0;
  bool outageConfirmed = false;
  Completer<void> activeProbe;
}
