import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
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

  /// Safely log exception to LoggingService if available
  void _logException(
    Object exception, {
    required String subDomain,
    StackTrace? stackTrace,
  }) {
    if (getIt.isRegistered<LoggingService>()) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'VOXTRAL',
        subDomain: subDomain,
        stackTrace: stackTrace,
      );
    }
  }

  /// Validates HTTP response status code and throws appropriate exception
  ///
  /// Throws [VoxtralModelNotAvailableException] for 404 status (model not downloaded)
  /// Throws [VoxtralInferenceException] for other non-200 status codes
  void _validateResponseStatus({
    required int statusCode,
    required String model,
    String? responseBody,
    bool logException = true,
  }) {
    if (statusCode == 200) return;

    if (statusCode == 404) {
      developer.log(
        'Model not downloaded: HTTP 404',
        name: 'VoxtralInferenceRepository',
      );
      final exception = VoxtralModelNotAvailableException(
        'Voxtral model is not available. Please download it first.',
        modelName: model,
        statusCode: statusCode,
      );
      if (logException) {
        _logException(exception, subDomain: 'model_not_available');
      }
      throw exception;
    }

    developer.log(
      'Failed to transcribe audio: HTTP $statusCode',
      name: 'VoxtralInferenceRepository',
      error: responseBody,
    );
    final exception = VoxtralInferenceException(
      'Failed to transcribe audio (HTTP $statusCode). '
      'Please check your audio file and try again.',
      statusCode: statusCode,
    );
    if (logException) {
      _logException(exception, subDomain: 'http_error');
    }
    throw exception;
  }

  /// Transcribes audio using a locally running Voxtral instance
  ///
  /// This method sends audio data to a local Voxtral server for transcription
  /// using the OpenAI-compatible chat completions endpoint.
  ///
  /// Supports two modes:
  /// - **Streaming (default)**: Uses SSE to stream tokens as they're generated,
  ///   providing real-time feedback. Each token batch is yielded as it arrives.
  /// - **Non-streaming**: Waits for complete transcription before returning a
  ///   single response. More efficient for short audio.
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
  ///   stream: Whether to stream tokens (default: true). When false, returns
  ///     a single response after complete transcription.
  ///
  /// Returns:
  ///   Stream of chat completion responses. In streaming mode, yields multiple
  ///   responses with partial content. In non-streaming mode, yields a single
  ///   response with the complete transcription.
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
    bool stream = true,
  }) async* {
    // Validate required inputs
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    if (audioBase64.isEmpty) {
      throw ArgumentError('Audio payload cannot be empty');
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

    developer.log(
      'Sending streaming audio transcription request to local Voxtral server - '
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
            : 'Transcribe this audio.',
      }
    ];

    // Build request body with streaming enabled
    final requestBody = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': 0.0, // Deterministic for transcription
      'max_tokens': maxCompletionTokens ?? 4096,
      'audio': audioBase64,
      'stream': stream,
    };

    // Add language hint if provided
    if (language != null && language.isNotEmpty && language != 'auto') {
      requestBody['language'] = language;
    }

    try {
      final uri = Uri.parse(baseUrl).resolve('v1/chat/completions');

      // Handle non-streaming request
      if (!stream) {
        final response = await _httpClient
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(
              requestTimeout,
              onTimeout: () => throw VoxtralInferenceException(
                timeoutErrorMessage,
                statusCode: httpStatusRequestTimeout,
              ),
            );

        _validateResponseStatus(
          statusCode: response.statusCode,
          model: model,
          responseBody: response.body,
          logException: false, // Non-streaming doesn't log (simpler path)
        );

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices[0] as Map<String, dynamic>;
          final message = choice['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield CreateChatCompletionStreamResponse(
              id: json['id'] as String? ??
                  'voxtral-${DateTime.now().millisecondsSinceEpoch}',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(content: content),
                  index: 0,
                  finishReason: ChatCompletionFinishReason.stop,
                ),
              ],
              object: 'chat.completion.chunk',
              created: json['created'] as int? ??
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
          }
        }
        return;
      }

      // Create streaming request
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _httpClient.send(request).timeout(
        requestTimeout,
        onTimeout: () {
          throw VoxtralInferenceException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout,
          );
        },
      );

      if (streamedResponse.statusCode != 200) {
        // Read body for error logging (only for non-200)
        final body = streamedResponse.statusCode != 404
            ? await streamedResponse.stream.bytesToString()
            : null;
        _validateResponseStatus(
          statusCode: streamedResponse.statusCode,
          model: model,
          responseBody: body,
        );
      }

      // Parse SSE stream
      var chunksReceived = 0;
      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        // SSE format: "data: {...}\n\n"
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();

            // Check for stream end
            if (data == '[DONE]') {
              developer.log(
                'Streaming complete - received $chunksReceived chunks',
                name: 'VoxtralInferenceRepository',
              );
              return;
            }

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choices = json['choices'] as List<dynamic>?;

              if (choices != null && choices.isNotEmpty) {
                final choice = choices[0] as Map<String, dynamic>;
                final delta = choice['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                final finishReason = choice['finish_reason'] as String?;

                // Only yield chunks with actual content
                if (content != null && content.isNotEmpty) {
                  chunksReceived++;
                  developer.log(
                    'Received chunk $chunksReceived: ${content.length} chars',
                    name: 'VoxtralInferenceRepository',
                  );

                  yield CreateChatCompletionStreamResponse(
                    id: json['id'] as String? ??
                        'voxtral-${DateTime.now().millisecondsSinceEpoch}',
                    choices: [
                      ChatCompletionStreamResponseChoice(
                        delta: ChatCompletionStreamResponseDelta(
                          content: content,
                        ),
                        index: 0,
                        finishReason: finishReason != null
                            ? ChatCompletionFinishReason.values.firstWhere(
                                (e) => e.name == finishReason,
                                orElse: () => ChatCompletionFinishReason.stop,
                              )
                            : null,
                      ),
                    ],
                    object: 'chat.completion.chunk',
                    created: json['created'] as int? ??
                        DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  );
                }

                // Handle finish_reason without content (final chunk)
                if (finishReason == 'stop' &&
                    (content == null || content.isEmpty)) {
                  developer.log(
                    'Received stop signal',
                    name: 'VoxtralInferenceRepository',
                  );
                }
              }
            } on FormatException catch (e) {
              developer.log(
                'Failed to parse SSE chunk: $data',
                name: 'VoxtralInferenceRepository',
                error: e,
              );
              // Continue processing other chunks
            }
          }
        }
      }
    } on VoxtralModelNotAvailableException {
      rethrow;
    } on VoxtralInferenceException {
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      developer.log(
        'Transcription request timed out',
        name: 'VoxtralInferenceRepository',
        error: e,
      );
      _logException(e, subDomain: 'timeout', stackTrace: stackTrace);
      throw VoxtralInferenceException(
        timeoutErrorMessage,
        statusCode: httpStatusRequestTimeout,
        originalError: e,
      );
    } on FormatException catch (e, stackTrace) {
      developer.log(
        'Failed to parse response from Voxtral server',
        name: 'VoxtralInferenceRepository',
        error: e,
      );
      _logException(e, subDomain: 'format_error', stackTrace: stackTrace);
      throw VoxtralInferenceException(
        'Invalid response format from transcription service',
        originalError: e,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during audio transcription',
        name: 'VoxtralInferenceRepository',
        error: e,
      );
      _logException(e, subDomain: 'unexpected', stackTrace: stackTrace);
      throw VoxtralInferenceException(
        'Failed to transcribe audio: $e',
        originalError: e,
      );
    }
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
