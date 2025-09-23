import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/state/consts.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Gemma 3n-specific inference operations
///
/// This repository handles both text generation and audio transcription using
/// a locally running Gemma 3n instance with OpenAI-compatible API.
class Gemma3nInferenceRepository {
  Gemma3nInferenceRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Transcribes audio using a locally running Gemma 3n instance
  ///
  /// This method sends audio data to a local Gemma 3n server for transcription
  /// using the OpenAI-compatible chat completions endpoint.
  ///
  /// Args:
  ///   model: The Gemma 3n model to use (e.g., 'google/gemma-3n-E2B-it')
  ///   audioBase64: Base64 encoded audio data
  ///   baseUrl: The base URL of the local Gemma 3n server
  ///   prompt: Optional text prompt for context-aware transcription
  ///   maxCompletionTokens: Optional token limit for the response
  ///   timeout: Optional timeout override (defaults to whisperTranscriptionTimeoutSeconds)
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the transcribed text
  ///
  /// Throws:
  ///   ArgumentError if required parameters are empty
  ///   Gemma3nInferenceException if transcription fails
  Stream<CreateChatCompletionStreamResponse> transcribeAudio({
    required String model,
    required String audioBase64,
    required String baseUrl,
    String? prompt,
    int? maxCompletionTokens,
    Duration? timeout,
  }) {
    // Validate required inputs
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    // Use provided timeout or default
    final requestTimeout =
        timeout ?? const Duration(seconds: whisperTranscriptionTimeoutSeconds);

    // Define timeout error message
    final timeoutMinutes = requestTimeout.inMinutes;
    final timeoutErrorMessage = 'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording or check your Gemma 3n server performance.';

    // Create a stream that performs the async transcription operation
    return Stream.fromFuture(
      () async {
        try {
          developer.log(
            'Sending audio transcription request to local Gemma 3n server - '
            'baseUrl: $baseUrl, model: $model, audioLength: ${audioBase64.length}, '
            'timeout: ${requestTimeout.inMinutes} minutes',
            name: 'Gemma3nInferenceRepository',
          );

          // Build messages - use simple format like working script
          final messages = <Map<String, dynamic>>[
            {
              'role': 'user',
              'content': prompt != null && prompt.isNotEmpty
                  ? 'Context: $prompt\n\nTranscribe this audio'
                  : 'Transcribe this audio'
            }
          ];

          // Normalize model name - remove google/ prefix to match working script
          final normalizedModel = model.replaceFirst('google/', '');

          // Build request body using exact format from working script
          final requestBody = {
            'model': normalizedModel,
            'messages': messages,
            'temperature': 0.1, // Same as working script
            'max_tokens': maxCompletionTokens ??
                2000, // Use parameter or default for full transcription
            'audio': audioBase64, // Add audio data to the request
          };

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
              throw Gemma3nInferenceException(
                timeoutErrorMessage,
                statusCode: httpStatusRequestTimeout,
              );
            },
          );

          if (response.statusCode != 200) {
            developer.log(
              'Failed to transcribe audio: HTTP ${response.statusCode}',
              name: 'Gemma3nInferenceRepository',
              error: response.body,
            );
            throw Gemma3nInferenceException(
              'Failed to transcribe audio (HTTP ${response.statusCode}). '
              'Please check your audio file and try again.',
              statusCode: response.statusCode,
            );
          }

          final result = jsonDecode(response.body) as Map<String, dynamic>;

          // Extract text from response and create stream response with robust error handling
          try {
            final choices = result['choices'] as List<dynamic>;
            final firstChoice = choices[0] as Map<String, dynamic>;
            final message = firstChoice['message'] as Map<String, dynamic>;
            final text = message['content'] as String;

            developer.log(
              'Successfully transcribed audio - transcriptionLength: ${text.length}',
              name: 'Gemma3nInferenceRepository',
            );

            // Create a mock stream response to match the expected format
            return CreateChatCompletionStreamResponse(
              id: result['id'] as String? ??
                  'gemma3n-${DateTime.now().millisecondsSinceEpoch}',
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
              'Invalid response from Gemma 3n server: failed to parse response',
              name: 'Gemma3nInferenceRepository',
              error: result,
            );
            throw Gemma3nInferenceException(
              'Invalid response from transcription service: $e',
              originalError: e,
            );
          }
        } on Gemma3nInferenceException {
          // Re-throw our custom exceptions as-is
          rethrow;
        } on TimeoutException catch (e) {
          // Handle timeout exceptions from HTTP client
          developer.log(
            'Transcription request timed out',
            name: 'Gemma3nInferenceRepository',
            error: e,
          );
          throw Gemma3nInferenceException(
            timeoutErrorMessage,
            statusCode: httpStatusRequestTimeout,
            originalError: e,
          );
        } on FormatException catch (e) {
          // Handle JSON parsing errors
          developer.log(
            'Failed to parse response from Gemma 3n server',
            name: 'Gemma3nInferenceRepository',
            error: e,
          );
          throw Gemma3nInferenceException(
            'Invalid response format from transcription service',
            originalError: e,
          );
        } catch (e) {
          // Wrap other exceptions
          developer.log(
            'Unexpected error during audio transcription',
            name: 'Gemma3nInferenceRepository',
            error: e,
          );
          throw Gemma3nInferenceException(
            'Failed to transcribe audio: $e',
            originalError: e,
          );
        }
      }(),
    ).asBroadcastStream();
  }

  /// Generates text using the Gemma 3n model with streaming support
  ///
  /// This method provides text generation capabilities using the OpenAI-compatible
  /// chat completions endpoint with Server-Sent Events (SSE) streaming.
  ///
  /// Args:
  ///   prompt: The text prompt to generate from
  ///   model: The Gemma 3n model to use
  ///   baseUrl: The base URL of the local Gemma 3n server
  ///   temperature: Sampling temperature (0.0 to 2.0)
  ///   maxCompletionTokens: Maximum tokens to generate
  ///   systemMessage: Optional system message for context
  ///   timeout: Optional timeout override
  ///
  /// Returns:
  ///   Stream of chat completion responses containing the generated text chunks
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    double temperature = 0.7,
    int? maxCompletionTokens,
    String? systemMessage,
    Duration? timeout,
  }) async* {
    // Validate required inputs
    if (model.isEmpty) {
      throw ArgumentError('Model name cannot be empty');
    }
    if (baseUrl.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }

    // Use provided timeout or default
    final requestTimeout = timeout ?? const Duration(seconds: 120);

    try {
      developer.log(
        'Starting streaming text generation request to Gemma 3n server - '
        'baseUrl: $baseUrl, model: $model, promptLength: ${prompt.length}',
        name: 'Gemma3nInferenceRepository',
      );

      // Build messages
      final messages = <Map<String, dynamic>>[
        if (systemMessage != null && systemMessage.isNotEmpty)
          {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': prompt},
      ];

      // Normalize model name - remove google/ prefix
      final normalizedModel = model.replaceFirst('google/', '');

      // Build request body with streaming enabled
      final requestBody = {
        'model': normalizedModel,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxCompletionTokens ?? 2000,
        'stream': true, // Enable streaming
      };

      // Use http.Request for streaming support
      final request = http.Request(
        'POST',
        Uri.parse(baseUrl).resolve('v1/chat/completions'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(requestBody);

      // Send the request and get the streaming response
      final streamedResponse = await _httpClient.send(request).timeout(
        requestTimeout,
        onTimeout: () {
          throw Gemma3nInferenceException(
            'Request timed out after ${requestTimeout.inSeconds} seconds',
            statusCode: httpStatusRequestTimeout,
          );
        },
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        throw Gemma3nInferenceException(
          'Failed to generate text (HTTP ${streamedResponse.statusCode}): $body',
          statusCode: streamedResponse.statusCode,
        );
      }

      // Process the SSE stream
      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      var buffer = '';
      await for (final line in stream) {
        // SSE format: "data: {json}"
        if (line.startsWith('data: ')) {
          final data = line.substring(6); // Remove "data: " prefix

          // Check for end of stream
          if (data.trim() == '[DONE]') {
            developer.log(
              'Stream completed',
              name: 'Gemma3nInferenceRepository',
            );
            break;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;

            // Extract content from the chunk
            if (json.containsKey('choices')) {
              final choices = json['choices'] as List<dynamic>;
              if (choices.isNotEmpty) {
                final choice = choices[0] as Map<String, dynamic>;
                final delta = choice['delta'] as Map<String, dynamic>?;

                if (delta != null && delta['content'] is String) {
                  final content = delta['content'] as String;
                  buffer += content;

                  // Yield the chunk immediately for real-time display
                  yield CreateChatCompletionStreamResponse(
                    id: json['id'] as String? ??
                        'gemma3n-${DateTime.now().millisecondsSinceEpoch}',
                    choices: [
                      ChatCompletionStreamResponseChoice(
                        delta: ChatCompletionStreamResponseDelta(
                          content: content,
                        ),
                        index: 0,
                      ),
                    ],
                    object: 'chat.completion.chunk',
                    created: json['created'] as int? ??
                        DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  );
                }
              }
            }
          } catch (e) {
            // Log but don't fail on individual chunk parse errors
            developer.log(
              'Error parsing SSE chunk: $data',
              name: 'Gemma3nInferenceRepository',
              error: e,
            );
          }
        }
      }

      developer.log(
        'Successfully completed streaming text generation - totalLength: ${buffer.length}',
        name: 'Gemma3nInferenceRepository',
      );
    } catch (e) {
      developer.log(
        'Text generation streaming error',
        name: 'Gemma3nInferenceRepository',
        error: e,
      );
      if (e is Gemma3nInferenceException) {
        rethrow;
      }
      throw Gemma3nInferenceException(
        'Failed to generate text: $e',
        originalError: e,
      );
    }
  }
}

/// Exception thrown when Gemma 3n operations fail
class Gemma3nInferenceException implements Exception {
  Gemma3nInferenceException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'Gemma3nInferenceException: $message';
}
