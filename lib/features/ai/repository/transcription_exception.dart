/// Exception thrown when audio transcription fails.
///
/// Used by all transcription repositories (OpenAI, Mistral, Whisper).
/// The [provider] field identifies which provider encountered the error.
class TranscriptionException implements Exception {
  TranscriptionException(
    this.message, {
    this.provider,
    this.statusCode,
    this.originalError,
  });

  final String message;

  /// Provider name (e.g., 'OpenAI', 'Mistral', 'Whisper') for diagnostics.
  final String? provider;

  /// HTTP status code if the error originated from an HTTP response.
  final int? statusCode;

  /// The original exception that caused this error, if any.
  final Object? originalError;

  @override
  String toString() => 'TranscriptionException($provider): $message';
}
