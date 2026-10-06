import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/repository/completion_usage_parser.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

/// Repository for handling Voxtral-specific inference operations
///
/// This repository handles audio transcription using a locally running
/// Voxtral instance with OpenAI-compatible API. Voxtral supports up to
/// 30 minutes of audio transcription with 9 languages.
class VoxtralInferenceRepository {
  VoxtralInferenceRepository({
    required this._domainLogger,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final DomainLogger _domainLogger;
  final http.Client _httpClient;

  /// Records [exception] under [subDomain], with an optional content-free
  /// [message]. A `FormatException` loses the response text it quotes.
  void _logException(
    Object exception, {
    required String subDomain,
    StackTrace? stackTrace,
    String? message,
  }) {
    _domainLogger.error(
      LogDomain.speech,
      DomainLogger.withoutSource(exception),
      errorType: exception.runtimeType,
      stackTrace: stackTrace,
      subDomain: subDomain,
      message: message,
    );
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
      _domainLogger.log(
        LogDomain.speech,
        'Model not downloaded: HTTP 404',
        subDomain: 'VoxtralInferenceRepository',
        level: InsightLevel.warn,
      );
      final exception = VoxtralModelNotAvailableException(
        'Voxtral model is not available. Please download it first.',
      );
      if (logException) {
        _logException(exception, subDomain: 'model_not_available');
      }
      throw exception;
    }

    // The body's size, not the body: an error body can echo the request.
    _domainLogger.error(
      LogDomain.speech,
      'Failed to transcribe audio: HTTP $statusCode',
      subDomain: 'VoxtralInferenceRepository',
      message: 'body ${responseBody?.length ?? 0} chars',
    );
    final exception = VoxtralInferenceException(
      'Failed to transcribe audio (HTTP $statusCode). '
      'Please check your audio file and try again.',
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
    final timeoutErrorMessage =
        'Transcription request timed out after '
        '${timeoutMinutes == 1 ? '1 minute' : '$timeoutMinutes minutes'}. '
        'This can happen with very long audio files or slow processing. '
        'Please try with a shorter recording or check your Voxtral server.';

    _domainLogger.log(
      LogDomain.speech,
      'Sending streaming audio transcription request to local Voxtral server - '
      'model: $model, audioLength: ${audioBase64.length}, '
      'timeout: ${requestTimeout.inMinutes} minutes',
      subDomain: 'VoxtralInferenceRepository',
    );

    // Build messages with full context (including speech dictionary)
    final messages = <Map<String, dynamic>>[
      {
        'role': 'user',
        'content': prompt != null && prompt.isNotEmpty
            ? prompt
            : 'Transcribe this audio.',
      },
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
              ),
            );

        _validateResponseStatus(
          statusCode: response.statusCode,
          model: model,
          responseBody: response.body,
          logException: false, // Non-streaming doesn't log (simpler path)
        );

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final usage = parseCompletionUsage(json['usage']);
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices[0] as Map<String, dynamic>;
          final message = choice['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield CreateChatCompletionStreamResponse(
              id:
                  json['id'] as String? ??
                  'voxtral-${DateTime.now().millisecondsSinceEpoch}',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(content: content),
                  index: 0,
                  finishReason: ChatCompletionFinishReason.stop,
                ),
              ],
              object: 'chat.completion.chunk',
              created:
                  json['created'] as int? ??
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
              model: json['model'] as String?,
              usage: usage,
            );
            return;
          }
        }
        if (usage != null) {
          yield CreateChatCompletionStreamResponse(
            id:
                json['id'] as String? ??
                'voxtral-${DateTime.now().millisecondsSinceEpoch}',
            choices: const [],
            object: 'chat.completion.chunk',
            created:
                json['created'] as int? ??
                DateTime.now().millisecondsSinceEpoch ~/ 1000,
            model: json['model'] as String?,
            usage: usage,
          );
        }
        return;
      }

      // Create streaming request
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(
            requestTimeout,
            onTimeout: () {
              throw VoxtralInferenceException(
                timeoutErrorMessage,
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
      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        // SSE format: "data: {...}\n\n"
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();

            // Check for stream end
            if (data == '[DONE]') {
              _domainLogger.log(
                LogDomain.speech,
                'Streaming complete - received $chunksReceived chunks',
                subDomain: 'VoxtralInferenceRepository',
              );
              return;
            }

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final usage = parseCompletionUsage(json['usage']);
              final choices = json['choices'] as List<dynamic>?;

              if (choices != null && choices.isNotEmpty) {
                final choice = choices[0] as Map<String, dynamic>;
                final delta = choice['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                final finishReason = choice['finish_reason'] as String?;

                final hasContent = content != null && content.isNotEmpty;

                // Yield content chunks and final usage-only chunks. Some
                // OpenAI-compatible servers put usage on a terminal SSE event
                // with no text delta, and the recorder consumes usage from
                // any chunk in the stream.
                if (hasContent || usage != null) {
                  if (hasContent) {
                    chunksReceived++;
                    _domainLogger.logSampled(
                      LogDomain.speech,
                      'Received chunk $chunksReceived: ${content.length} chars',
                      sampleKey: 'voxtral_stream_chunk',
                      subDomain: 'VoxtralInferenceRepository',
                    );
                  }

                  yield CreateChatCompletionStreamResponse(
                    id:
                        json['id'] as String? ??
                        'voxtral-${DateTime.now().millisecondsSinceEpoch}',
                    choices: hasContent
                        ? [
                            ChatCompletionStreamResponseChoice(
                              delta: ChatCompletionStreamResponseDelta(
                                content: content,
                              ),
                              index: 0,
                              finishReason: finishReason != null
                                  ? _chatFinishReasonFromApi(finishReason)
                                  : null,
                            ),
                          ]
                        : const [],
                    object: 'chat.completion.chunk',
                    created:
                        json['created'] as int? ??
                        DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    model: json['model'] as String?,
                    usage: usage,
                  );
                }

                // Handle finish_reason without content (final chunk)
                if (finishReason == 'stop' &&
                    (content == null || content.isEmpty)) {
                  _domainLogger.log(
                    LogDomain.speech,
                    'Received stop signal',
                    subDomain: 'VoxtralInferenceRepository',
                  );
                }
              } else if (usage != null) {
                yield CreateChatCompletionStreamResponse(
                  id:
                      json['id'] as String? ??
                      'voxtral-${DateTime.now().millisecondsSinceEpoch}',
                  choices: const [],
                  object: 'chat.completion.chunk',
                  created:
                      json['created'] as int? ??
                      DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  model: json['model'] as String?,
                  usage: usage,
                );
              }
            } on FormatException catch (e, stackTrace) {
              _domainLogger.error(
                LogDomain.speech,
                // Not the exception itself: its toString quotes the chunk.
                DomainLogger.withoutSource(e),
                errorType: e.runtimeType,
                stackTrace: stackTrace,
                subDomain: 'VoxtralInferenceRepository',
                message:
                    'Failed to parse SSE chunk (${data.length} chars) '
                    'at offset ${e.offset}',
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
      _logException(
        e,
        subDomain: 'timeout',
        stackTrace: stackTrace,
        message: 'Transcription request timed out',
      );
      throw VoxtralInferenceException(
        timeoutErrorMessage,
      );
    } on FormatException catch (e, stackTrace) {
      _logException(
        e,
        subDomain: 'format_error',
        stackTrace: stackTrace,
        message: 'Failed to parse response from Voxtral server',
      );
      throw VoxtralInferenceException(
        'Invalid response format from transcription service',
      );
    } catch (e, stackTrace) {
      _logException(
        e,
        subDomain: 'unexpected',
        stackTrace: stackTrace,
        message: 'Unexpected error during audio transcription',
      );
      throw VoxtralInferenceException(
        'Failed to transcribe audio: $e',
      );
    }
  }

  /// Closes the underlying HTTP client and any keep-alive connections.
  void close() => _httpClient.close();
}

ChatCompletionFinishReason _chatFinishReasonFromApi(String finishReason) {
  final normalized = finishReason.replaceAll('_', '').toLowerCase();
  return ChatCompletionFinishReason.values.firstWhere(
    (value) => value.name.toLowerCase() == normalized,
    orElse: () => ChatCompletionFinishReason.stop,
  );
}

/// Exception thrown when Voxtral operations fail
class VoxtralInferenceException implements Exception {
  VoxtralInferenceException(this.message);

  final String message;

  @override
  String toString() => 'VoxtralInferenceException: $message';
}

/// Exception thrown when Voxtral model is not available
class VoxtralModelNotAvailableException extends VoxtralInferenceException {
  VoxtralModelNotAvailableException(super.message);

  @override
  String toString() => 'VoxtralModelNotAvailableException: $message';
}

/// Timeout for Voxtral transcription (15 minutes for 30-min audio support)
const int voxtralTranscriptionTimeoutSeconds = 900;
