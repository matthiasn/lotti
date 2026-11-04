/// Why a cloud speech request failed, so the caller can choose between
/// retrying, asking for a new API key, and falling back to the on-device
/// engine. Shared by every provider's speech client.
enum CloudTtsFailure {
  /// No connection, DNS failure, TLS failure. Retryable; fall back offline.
  network,

  /// No response within the request timeout. Retryable.
  timeout,

  /// HTTP 401/403 — the key is missing, revoked, lacks access or, on
  /// ElevenLabs, has used up its quota. Not retryable until the user fixes
  /// the provider's key or plan.
  unauthorized,

  /// HTTP 429. Retry no sooner than [CloudTtsException.retryAfter].
  rateLimited,

  /// HTTP 400/404/422 — the request itself was rejected (unknown voice,
  /// unknown model, text too long). Not retryable unchanged.
  rejected,

  /// HTTP 5xx. Retryable.
  server,

  /// A 200 whose body is not what the API documents.
  invalidResponse,

  /// The catalog has no voice for the text's language, so nothing was sent.
  noVoice,
}

class CloudTtsException implements Exception {
  const CloudTtsException(
    this.failure,
    this.message, {
    this.statusCode,
    this.retryAfter,
    this.apiError,
    this.requestId,
  });

  final CloudTtsFailure failure;

  /// Diagnostic text. Never contains the spoken text, the API key or the
  /// response body, so it is safe to log; [apiError] carries what the server
  /// said.
  final String message;

  final int? statusCode;

  /// The server's `Retry-After`, when it sent one with a 429.
  final Duration? retryAfter;

  /// The server's own explanation of a non-200 answer — its `message`, or
  /// each validation `detail` as `loc: msg` — so a 422 names the field it
  /// rejected. The `input` a validation detail echoes is never kept: it can
  /// quote the spoken text.
  final String? apiError;

  /// The server's request id for the failed call, for a support ticket.
  final String? requestId;

  bool get isRetryable => switch (failure) {
    CloudTtsFailure.network ||
    CloudTtsFailure.timeout ||
    CloudTtsFailure.rateLimited ||
    CloudTtsFailure.server => true,
    CloudTtsFailure.unauthorized ||
    CloudTtsFailure.rejected ||
    CloudTtsFailure.invalidResponse ||
    CloudTtsFailure.noVoice => false,
  };

  @override
  String toString() =>
      'CloudTtsException(${failure.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'}): $message'
      '${apiError == null ? '' : ' — server: $apiError'}'
      '${requestId == null ? '' : ' (request $requestId)'}';
}
