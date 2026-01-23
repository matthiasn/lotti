import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Repository for handling OpenAI transcription-specific inference operations.
///
/// OpenAI's gpt-4o-transcribe and gpt-4o-mini-transcribe models require
/// the `/v1/audio/transcriptions` endpoint with multipart/form-data format,
/// not the chat completions endpoint.
class OpenAiTranscriptionRepository {
  OpenAiTranscriptionRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Checks if a model is an OpenAI transcription model that requires
  /// the transcriptions endpoint instead of chat completions.
  ///
  /// Supports exact model names and date/version snapshot aliases:
  /// - gpt-4o-mini-transcribe, gpt-4o-mini-transcribe-2025-01-15, etc.
  /// - gpt-4o-transcribe, gpt-4o-transcribe-2025-01-15, etc.
  /// - gpt-4o-transcribe-diarize (speaker diarization model)
  static bool isOpenAiTranscriptionModel(String model) {
    return model.startsWith('gpt-4o-mini-transcribe') ||
        model.startsWith('gpt-4o-transcribe-diarize') ||
        model.startsWith('gpt-4o-transcribe');
  }

  /// Transcribes audio using OpenAI's transcription API.
  ///
  /// This method sends audio data to OpenAI's `/v1/audio/transcriptions`
  /// endpoint using multipart/form-data format.
  ///
  /// Args:
  ///   model: The OpenAI transcription model to use (e.g., 'gpt-4o-transcribe')
  ///   audioBase64: Base64 encoded audio data (M4A format from app recording)
  ///   apiKey: The OpenAI API key for authentication
  ///   prompt: Optional text prompt for context to improve transcription accuracy
  ///   timeout: Optional timeout override (defaults to whisperTranscriptionTimeoutSeconds)
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the transcribed text
  ///
  /// Throws:
  ///   ArgumentError if required parameters are empty
  ///   OpenAiTranscriptionException if transcription fails
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String apiKey,
    String? prompt,
    Duration? timeout,
  }) {
    // Validate required inputs
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (audioBase64.isEmpty) {
      throw ArgumentError('Audio data cannot be empty');
    }
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    // Use provided timeout or default
    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);

    // Define timeout error message once
    final timeoutMinutes = requestTimeout.inMinutes;
    final timeoutErrorMessage = 'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording.';

    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to OpenAI - '
            'model: $model, audioLength: ${audioBase64.length}, '
            'timeout: ${requestTimeout.inMinutes} minutes',
            name: 'OpenAiTranscriptionRepository',
          );

          // Decode base64 audio to bytes
          final audioBytes = base64Decode(audioBase64);

          // Create multipart request
          final uri =
              Uri.parse('https://api.openai.com/v1/audio/transcriptions');
          final request = http.MultipartRequest('POST', uri);

          // Add headers
          request.headers['Authorization'] = 'Bearer $apiKey';

          // Add file - app records in M4A format
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              audioBytes,
              filename: 'audio.m4a',
            ),
          );

          // Add model
          request.fields['model'] = model;

          // Add optional prompt for context
          if (prompt != null && prompt.isNotEmpty) {
            request.fields['prompt'] = prompt;
          }

          // Send request
          final streamedResponse = await _httpClient.send(request).timeout(
            requestTimeout,
            onTimeout: () {
              throw OpenAiTranscriptionException(
                timeoutErrorMessage,
                statusCode: httpStatusRequestTimeout,
              );
            },
          );

          // Read response
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: 'OpenAiTranscriptionRepository',
              error: response.body,
            );

            // Try to parse error message from response
            var errorMessage =
                'Failed to transcribe audio (HTTP ${response.statusCode})';
            try {
              final errorJson =
                  jsonDecode(response.body) as Map<String, dynamic>;
              if (errorJson['error'] != null) {
                final error = errorJson['error'] as Map<String, dynamic>;
                errorMessage = error['message'] as String? ?? errorMessage;
              }
            } catch (_) {
              // Use default error message if parsing fails
            }

            throw OpenAiTranscriptionException(
              errorMessage,
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          // Validate response structure
          if (!result.containsKey('text')) {
            developer.log(
              'Invalid response from OpenAI transcription: missing text field',
              name: 'OpenAiTranscriptionRepository',
              error: result,
            );
            throw OpenAiTranscriptionException(
              'Invalid response from transcription service: missing text field',
            );
          }

          final text = result['text'] as String;

          developer.log(
            'Successfully transcribed audio - transcriptionLength: ${text.length}',
            name: 'OpenAiTranscriptionRepository',
          );

          // Create a wrapper response to match the expected stream format.
          // Use UUID for unique ID and fixed timestamp (0) since these are
          // internal metadata not used downstream.
          return CreateChatCompletionStreamResponse(
            id: 'openai-transcription-${const Uuid().v4()}',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(
                  content: text,
                ),
                index: 0,
              ),
            ],
            object: 'chat.completion.chunk',
            created: 0,
          );
        } on OpenAiTranscriptionException {
          rethrow;
        } on TimeoutException catch (e) {
          developer.log(
            'Transcription request timed out',
            name: 'OpenAiTranscriptionRepository',
            error: e,
          );
          throw OpenAiTranscriptionException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          developer.log(
            'Failed to parse response from OpenAI transcription',
            name: 'OpenAiTranscriptionRepository',
            error: e,
          );
          throw OpenAiTranscriptionException(
            'Invalid response format from transcription service',
            originalError: e,
          );
        } catch (e) {
          developer.log(
            'Unexpected error during audio transcription',
            name: 'OpenAiTranscriptionRepository',
            error: e,
          );
          throw OpenAiTranscriptionException(
            'Failed to transcribe audio: $e',
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }
}

/// Exception thrown when OpenAI transcription fails
class OpenAiTranscriptionException implements Exception {
  OpenAiTranscriptionException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'OpenAiTranscriptionException: $message';
}
