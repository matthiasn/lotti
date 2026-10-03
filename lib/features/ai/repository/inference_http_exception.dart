/// A failed request to an inference provider's HTTP API — a model listing,
/// a completion, an OCR call — for every provider that reports one the same
/// way.
///
/// [provider] names who answered, so a log line or the settings page still
/// says which one failed now that they share a type; [statusCode] is the
/// HTTP status when there was a response, and [originalError] the cause when
/// the request never got one (a transport failure, an unreadable body).
class InferenceHttpException implements Exception {
  const InferenceHttpException(
    this.message, {
    required this.provider,
    this.statusCode,
    this.originalError,
  });

  /// Display name of the provider, e.g. `oMLX` or `Mistral OCR`.
  final String provider;
  final String message;
  final int? statusCode;
  final Object? originalError;

  /// `InferenceHttpException(provider) (HTTP n): message: cause`, each part
  /// only when present. `AiErrorUtils` classifies provider errors by this
  /// text — a refused key by its `(HTTP 401)` or `(HTTP 403)` — so the form is
  /// load-bearing.
  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    final cause = originalError == null ? '' : ': $originalError';
    return 'InferenceHttpException($provider)$status: $message$cause';
  }
}
