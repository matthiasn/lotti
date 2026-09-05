import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:openai_dart/openai_dart.dart';

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
    this.completedSegments = 0,
    this.partialUsage,
    this.partialImpact,
  });

  final String message;

  /// Provider name (e.g., 'OpenAI', 'Mistral', 'Whisper') for diagnostics.
  final String? provider;

  /// HTTP status code if the error originated from an HTTP response.
  final int? statusCode;

  /// The original exception that caused this error, if any.
  final Object? originalError;

  /// Successfully completed segments before this attempt failed.
  final int completedSegments;

  /// Provider-reported usage already incurred by the completed segments.
  final CompletionUsage? partialUsage;

  /// Provider-reported billing and impact already incurred before failure.
  final MeliousCallImpact? partialImpact;

  @override
  String toString() => 'TranscriptionException($provider): $message';
}
