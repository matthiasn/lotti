import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Whisper-specific inference operations
///
/// This repository handles audio transcription using a locally running
/// Whisper instance.
class WhisperInferenceRepository {
  WhisperInferenceRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Transcribes audio using a locally running Whisper instance
  ///
  /// This method sends audio data to a local Whisper server for transcription.
  ///
  /// Args:
  ///   model: The Whisper model to use (e.g., 'whisper-1')
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL of the local Whisper server
  ///   prompt: Optional text prompt for context (not used by Whisper)
  ///   maxCompletionTokens: Optional token limit (not used by Whisper)
  ///   language: Optional language hint for transcription (not used by Whisper)
  ///   timeout: Optional timeout override (defaults to whisperTranscriptionTimeoutSeconds)
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the transcribed text
  ///
  /// Throws:
  ///   ArgumentError if required parameters are empty
  ///   WhisperTranscriptionException if transcription fails
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    String? prompt, // Made optional since it's not used
    int? maxCompletionTokens, // Already optional, not used
    String? language, // Optional language hint (not used by Whisper)
    Duration? timeout, // Optional timeout override
  }) {
    // Validate required inputs consistently
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    // Use provided timeout or default
    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);

    // Define timeout error message once to avoid duplication
    final timeoutMinutes = requestTimeout.inMinutes;
    final timeoutErrorMessage = 'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording or check your Whisper server performance.';

    // Create a stream that performs the async transcription operation
    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to local Whisper server - '
            'baseUrl: $baseUrl, model: $model, audioLength: ${audioBase64.length}, '
            'timeout: ${requestTimeout.inMinutes} minutes',
            name: 'WhisperInferenceRepository',
          );

          final response = await _httpClient
              .post(
            Uri.parse(baseUrl).resolve('/v1/audio/transcriptions'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'audio': audioBase64,
            }),
          )
              .timeout(
            requestTimeout,
            onTimeout: () {
              throw WhisperTranscriptionException(
                timeoutErrorMessage,
                statusCode:
                    httpStatusRequestTimeout, // HTTP 408 Request Timeout
              );
            },
          );

          if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: 'WhisperInferenceRepository',
              error: response.body,
            );
            throw WhisperTranscriptionException(
              'Failed to transcribe audio (HTTP ${response.statusCode}). '
              'Please check your audio file and try again.',
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          // Validate response structure
          if (!result.containsKey('text')) {
            developer.log(
              'Invalid response from Whisper server: missing text field',
              name: 'WhisperInferenceRepository',
              error: result,
            );
            throw WhisperTranscriptionException(
              'Invalid response from transcription service: missing text field',
            );
          }

          final text = result['text'] as String;

          developer.log(
            'Successfully transcribed audio - transcriptionLength: ${text.length}',
            name: 'WhisperInferenceRepository',
          );

          // Create a mock stream response to match the expected format
          return CreateChatCompletionStreamResponse(
            id: 'whisper-${DateTime.now().millisecondsSinceEpoch}',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: text,
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
        } on WhisperTranscriptionException {
          // Re-throw our custom exceptions as-is
          rethrow;
        } on TimeoutException catch (e) {
          // Handle timeout exceptions from HTTP client
          developer.log(
            'Transcription request timed out',
            name: 'WhisperInferenceRepository',
            error: e,
          );
          throw WhisperTranscriptionException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout, // HTTP 408 Request Timeout
            originalError: e,
          );
        } on FormatException catch (e) {
          // Handle JSON parsing errors
          developer.log(
            'Failed to parse response from Whisper server',
            name: 'WhisperInferenceRepository',
            error: e,
          );
          throw WhisperTranscriptionException(
            'Invalid response format from transcription service',
            originalError: e,
          );
        } catch (e) {
          // Wrap other exceptions
          developer.log(
            'Unexpected error during audio transcription',
            name: 'WhisperInferenceRepository',
            error: e,
          );
          throw WhisperTranscriptionException(
            'Failed to transcribe audio: $e',
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }
}

/// Exception thrown when Whisper transcription fails
class WhisperTranscriptionException implements Exception {
  WhisperTranscriptionException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'WhisperTranscriptionException: $message';
}
