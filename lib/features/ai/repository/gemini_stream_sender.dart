import 'dart:async';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Sends HTTP streamed requests to Gemini with exponential backoff for rate
/// limiting (429/503) and an initial handshake timeout.
///
/// Extracted as a standalone collaborator so the streaming, multi-turn and
/// image-generation paths can share one retry/backoff implementation without
/// living on the repository as private methods.
class GeminiStreamSender {
  GeminiStreamSender({
    http.Client? httpClient,
    this.maxRetries = kDefaultMaxRetries,
    this.baseDelay = kDefaultRetryBaseDelay,
    this.initialRequestTimeout = kDefaultInitialRequestTimeout,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Maximum retry attempts for rate-limited (429) or temporarily
  /// unavailable (503) responses.
  final int maxRetries;

  /// Base delay for exponential backoff on retries.
  /// Actual delay doubles with each attempt: 500ms, 1s, 2s.
  final Duration baseDelay;

  /// Timeout for establishing the initial streaming connection.
  /// This covers the HTTP handshake, not the full response duration.
  final Duration initialRequestTimeout;

  /// Default maximum retry attempts for rate-limited (429) or temporarily
  /// unavailable (503) responses.
  static const int kDefaultMaxRetries = 3;

  /// Default base delay for exponential backoff on retries.
  static const Duration kDefaultRetryBaseDelay = Duration(milliseconds: 500);

  /// Default timeout for establishing the initial streaming connection.
  static const Duration kDefaultInitialRequestTimeout = Duration(seconds: 30);

  /// Send a HTTP streamed request with exponential backoff for rate limiting
  /// (429/503) and an initial handshake timeout. Builds a fresh request per
  /// attempt.
  Future<http.StreamedResponse> send({
    required http.Request Function() buildRequest,
    required String context,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final req = buildRequest();
        final resp = await _httpClient.send(req).timeout(initialRequestTimeout);
        if (resp.statusCode == 429 || resp.statusCode == 503) {
          if (attempt > maxRetries) return resp; // let caller inspect body
          // Honor Retry-After header if present (seconds)
          final retryAfter = resp.headers['retry-after'];
          Duration delay;
          if (retryAfter != null) {
            final secs = int.tryParse(retryAfter.trim());
            delay = secs != null
                ? Duration(seconds: secs)
                : baseDelay * (1 << (attempt - 1));
          } else {
            delay = baseDelay * (1 << (attempt - 1));
          }
          developer.log(
            'Rate limited (${resp.statusCode}) during $context; retrying in '
            '${delay.inMilliseconds}ms (attempt $attempt/$maxRetries)...',
            name: 'GeminiInferenceRepository',
          );
          await Future<void>.delayed(delay);
          continue;
        }
        return resp;
      } on TimeoutException {
        if (attempt > maxRetries) rethrow;
        final delay = baseDelay * (1 << (attempt - 1));
        developer.log(
          'Timeout during $context; retrying in ${delay.inMilliseconds}ms '
          '(attempt $attempt/$maxRetries)...',
          name: 'GeminiInferenceRepository',
        );
        await Future<void>.delayed(delay);
      }
    }
  }
}
