import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Voxtral-specific inference operations
///
/// This repository handles audio transcription using a locally running
/// Voxtral instance with OpenAI-compatible API. Voxtral supports up to
/// 30 minutes of audio transcription with 9 languages.
class VoxtralInferenceRepository {
  VoxtralInferenceRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Default base URL for local Voxtral server
  static const String defaultBaseUrl = 'http://127.0.0.1:11344/';

  /// Transcribes audio using a locally running Voxtral instance
  ///
  /// This method sends audio data to a local Voxtral server for transcription
  /// using the OpenAI-compatible chat completions endpoint.
  ///
  /// Args:
  ///   model: The Voxtral model to use (e.g., 'voxtral-mini')
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL of the local Voxtral server
  ///   prompt: Optional text prompt for context-aware transcription
  ///     (supports speech dictionaries, task context, etc.)
  ///   maxCompletionTokens: Optional token limit for the response
  ///   timeout: Optional timeout override (defaults to 15 minutes for long audio)
  ///   language: Optional language hint (auto-detected if not specified)
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the transcribed text
  ///
  /// Throws:
  ///   ArgumentError if required parameters are empty
  ///   VoxtralInferenceException if transcription fails
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    String? prompt,
    int? maxCompletionTokens,
    Duration? timeout,
    String? language,
  }) {
    // Validate required inputs
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    // Voxtral supports 30 min audio, so use longer timeout
    final requestTimeout =
        timeout ?? const Duration(seconds: voxtralTranscriptionTimeoutSeconds);

    // Define timeout error message
    final timeoutMinutes = requestTimeout.inMinutes;
    final timeoutErrorMessage = 'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording or check your Voxtral server.';

    // Create a stream that performs the async transcription operation
    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to local Voxtral server - '
            'baseUrl: $baseUrl, model: $model, audioLength: ${audioBase64.length}, '
            'timeout: ${requestTimeout.inMinutes} minutes',
            name: 'VoxtralInferenceRepository',
          );

          // Build messages with full context (including speech dictionary)
          final messages = <Map<String, dynamic>>[
            {
              'role': 'user',
              'content': prompt != null && prompt.isNotEmpty
                  ? prompt
                  : 'Transcribe this audio.'
            }
          ];

          // Build request body
          final requestBody = <String, dynamic>{
            'model': model,
            'messages': messages,
            'temperature': 0.0, // Deterministic for transcription
            'max_tokens': maxCompletionTokens ?? 4096,
            'audio': audioBase64,
          };

          // Add language hint if provided
          if (language != null && language.isNotEmpty && language != 'auto') {
            requestBody['language'] = language;
          }

          final response = await _httpClient
              .post(
            Uri.parse(baseUrl).resolve('v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
              .timeout(
            requestTimeout,
            onTimeout: () {
              throw VoxtralInferenceException(
                timeoutErrorMessage,
                statusCode: httpStatusRequestTimeout,
              );
            },
          );

          if (response.statusCode == 404) {
            developer.log(
              'Model not downloaded: HTTP 404',
              name: 'VoxtralInferenceRepository',
              error: response.body,
            );
            throw VoxtralModelNotAvailableException(
              'Voxtral model is not available. Please download it first.',
              modelName: model,
              statusCode: response.statusCode,
            );
          } else if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: 'VoxtralInferenceRepository',
              error: response.body,
            );
            throw VoxtralInferenceException(
              'Failed to transcribe audio (HTTP ${response.statusCode}). '
              'Please check your audio file and try again.',
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          // Extract text from response
          try {
            final choices = result['choices'] as List<dynamic>;
            final firstChoice = choices[0] as Map<String, dynamic>;
            final message = firstChoice['message'] as Map<String, dynamic>;
            final text = message['content'] as String;

            developer.log(
              'Successfully transcribed audio - transcriptionLength: ${text.length}',
              name: 'VoxtralInferenceRepository',
            );

            // Create a stream response to match the expected format
            return CreateChatCompletionStreamResponse(
              id: result['id'] as String? ??
                  'voxtral-${DateTime.now().millisecondsSinceEpoch}',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    content: text,
                  ),
                  index: 0,
                ),
              ],
              object: 'chat.completion.chunk',
              created: result['created'] as int? ??
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
          } catch (e) {
            developer.log(
              'Invalid response from Voxtral server: failed to parse response',
              name: 'VoxtralInferenceRepository',
              error: result,
            );
            throw VoxtralInferenceException(
              'Invalid response from transcription service: $e',
              originalError: e,
            );
          }
        } on VoxtralInferenceException {
          rethrow;
        } on TimeoutException catch (e) {
          developer.log(
            'Transcription request timed out',
            name: 'VoxtralInferenceRepository',
            error: e,
          );
          throw VoxtralInferenceException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          developer.log(
            'Failed to parse response from Voxtral server',
            name: 'VoxtralInferenceRepository',
            error: e,
          );
          throw VoxtralInferenceException(
            'Invalid response format from transcription service',
            originalError: e,
          );
        } catch (e) {
          if (e is VoxtralModelNotAvailableException) {
            rethrow;
          }

          developer.log(
            'Unexpected error during audio transcription',
            name: 'VoxtralInferenceRepository',
            error: e,
          );
          throw VoxtralInferenceException(
            'Failed to transcribe audio: $e',
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }

  /// Check if Voxtral server is healthy and model is available
  Future<VoxtralHealthStatus> checkHealth({
    String baseUrl = defaultBaseUrl,
  }) async {
    try {
      final response = await _httpClient
          .get(Uri.parse(baseUrl).resolve('health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VoxtralHealthStatus(
          isHealthy: data['status'] == 'healthy',
          modelAvailable: data['model_available'] as bool? ?? false,
          modelLoaded: data['model_loaded'] as bool? ?? false,
          device: data['device'] as String? ?? 'unknown',
          maxAudioMinutes:
              (data['max_audio_minutes'] as num?)?.toDouble() ?? 30,
        );
      }
      return VoxtralHealthStatus(isHealthy: false);
    } catch (e) {
      developer.log(
        'Failed to check Voxtral health',
        name: 'VoxtralInferenceRepository',
        error: e,
      );
      return VoxtralHealthStatus(isHealthy: false);
    }
  }

  /// Download the Voxtral model
  Future<void> downloadModel({
    String baseUrl = defaultBaseUrl,
    String modelName = 'mistralai/Voxtral-Mini-3B-2507',
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(baseUrl).resolve('v1/models/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model_name': modelName,
          'stream': false,
        }),
      );

      if (response.statusCode != 200) {
        throw VoxtralInferenceException(
          'Failed to download model: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is VoxtralInferenceException) rethrow;
      throw VoxtralInferenceException(
        'Failed to download model: $e',
        originalError: e,
      );
    }
  }
}

/// Health status of the Voxtral server
class VoxtralHealthStatus {
  VoxtralHealthStatus({
    required this.isHealthy,
    this.modelAvailable = false,
    this.modelLoaded = false,
    this.device = 'unknown',
    this.maxAudioMinutes = 30,
  });

  final bool isHealthy;
  final bool modelAvailable;
  final bool modelLoaded;
  final String device;
  final double maxAudioMinutes;
}

/// Exception thrown when Voxtral operations fail
class VoxtralInferenceException implements Exception {
  VoxtralInferenceException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'VoxtralInferenceException: $message';
}

/// Exception thrown when Voxtral model is not available
class VoxtralModelNotAvailableException extends VoxtralInferenceException {
  VoxtralModelNotAvailableException(
    super.message, {
    required this.modelName,
    super.statusCode,
    super.originalError,
  });

  final String modelName;

  @override
  String toString() => 'VoxtralModelNotAvailableException: $message';
}

/// Timeout for Voxtral transcription (15 minutes for 30-min audio support)
const int voxtralTranscriptionTimeoutSeconds = 900;
