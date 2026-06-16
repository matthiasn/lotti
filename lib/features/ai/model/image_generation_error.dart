/// Exception thrown when image generation fails in a way the UI should explain.
///
/// [message] retains the rich, log-friendly diagnostics (finish reason, token
/// usage, raw payload). [providerReason] is the *verbatim* reason the provider
/// itself returned — e.g. a Gemini `finishReason` like `PROHIBITED_CONTENT`, a
/// `promptFeedback.blockReason`, or the message from an HTTP error body. It is
/// surfaced to the user as-is (never paraphrased), so they see exactly what the
/// provider said rather than an invented description. `null` when the failure
/// did not originate from a provider response (e.g. a network timeout).
class ImageGenerationException implements Exception {
  ImageGenerationException(this.message, {this.providerReason});

  /// Human-readable, log-friendly description including provider diagnostics.
  final String message;

  /// The provider's own reason string, shown verbatim in the UI. `null` when
  /// no provider reason is available.
  final String? providerReason;

  @override
  String toString() => 'ImageGenerationException: $message';
}
