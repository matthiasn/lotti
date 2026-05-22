import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_chat_message_json.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Repository for handling Mistral-specific inference operations
///
/// This repository handles text generation using the Mistral API.
/// It parses streaming responses manually to handle Mistral's response format
/// differences, particularly for tool calls where the content field may be
/// returned as an array instead of a string.
class MistralInferenceRepository {
  MistralInferenceRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Safely log exception to LoggingService if available
  void _logException(
    Object exception, {
    required String subDomain,
    StackTrace? stackTrace,
  }) {
    if (getIt.isRegistered<DomainLogger>()) {
      getIt<DomainLogger>().error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

  /// Generate text using the Mistral API with streaming support.
  ///
  /// This method handles Mistral's specific streaming format, including:
  /// - Content that may be returned as an array instead of a string
  /// - Tool calls in streaming responses
  ///
  /// Args:
  ///   prompt: The text prompt to send
  ///   model: The model identifier (e.g., 'mistral-small-2501')
  ///   baseUrl: The base URL for the API
  ///   apiKey: The API key for authentication
  ///   systemMessage: Optional system message for context
  ///   temperature: Sampling temperature
  ///   maxCompletionTokens: Maximum tokens for completion
  ///   tools: Optional list of tools for function calling
  ///
  /// Returns:
  ///   Stream of chat completion responses
  Stream<AiStreamChunk> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<AiTool>? tools,
  }) async* {
    yield* _generate(
      messages: [
        if (systemMessage != null) AiSystemMessage(systemMessage),
        AiUserMessage(AiUserTextContent(prompt)),
      ],
      model: model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
    );
  }

  /// Generate text with full conversation history.
  ///
  /// This method supports multi-turn conversations with Mistral's API.
  Stream<AiStreamChunk> generateTextWithMessages({
    required List<AiChatMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<AiTool>? tools,
  }) async* {
    yield* _generate(
      messages: messages,
      model: model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
    );
  }

  /// Internal method to generate text with streaming.
  Stream<AiStreamChunk> _generate({
    required List<AiChatMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<AiTool>? tools,
  }) async* {
    final requestBody = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': true,
      'temperature': ?temperature,
      'max_tokens': ?maxCompletionTokens,
    };

    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools.map((t) => t.toJson()).toList();
      requestBody['tool_choice'] = 'auto';
    }

    developer.log(
      'Sending streaming request to Mistral API - '
      'baseUrl: $baseUrl, model: $model, '
      'tools: ${tools?.length ?? 0}',
      name: 'MistralInferenceRepository',
    );

    try {
      // Ensure proper URL construction - append path to baseUrl
      final baseUri = Uri.parse(baseUrl);
      final uri = baseUri.replace(
        path:
            '${baseUri.path}${baseUri.path.endsWith('/') ? '' : '/'}chat/completions',
      );
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.body = jsonEncode(requestBody);

      final streamedResponse = await _httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        developer.log(
          'Mistral API error: HTTP ${streamedResponse.statusCode} - $body',
          name: 'MistralInferenceRepository',
        );
        throw MistralInferenceException(
          'Mistral API error (HTTP ${streamedResponse.statusCode})',
          statusCode: streamedResponse.statusCode,
        );
      }

      var chunksReceived = 0;
      var parseErrorCount = 0;
      const maxParseErrors = 5;
      var buffer = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        // Append chunk to buffer and process complete lines
        buffer.write(chunk);
        final bufferContent = buffer.toString();

        // Find complete lines (SSE format: "data: {...}\n\n")
        final lines = bufferContent.split('\n');

        // Keep the last incomplete line in the buffer
        buffer = StringBuffer();
        if (!bufferContent.endsWith('\n')) {
          buffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          if (trimmedLine.startsWith('data: ')) {
            final data = trimmedLine.substring(6).trim();

            // Check for stream end
            if (data == '[DONE]') {
              developer.log(
                'Streaming complete - received $chunksReceived chunks',
                name: 'MistralInferenceRepository',
              );
              return;
            }

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final response = aiStreamChunkFromJson(json);
              if (response != null) {
                chunksReceived++;
                yield response;
              }
            } on FormatException catch (e) {
              parseErrorCount++;
              developer.log(
                'Failed to parse SSE chunk ($parseErrorCount/$maxParseErrors): $data',
                name: 'MistralInferenceRepository',
                error: e,
              );
              if (parseErrorCount >= maxParseErrors) {
                _logException(
                  e,
                  subDomain: 'parse_threshold_exceeded',
                );
                throw MistralInferenceException(
                  'Too many parse errors ($parseErrorCount) during streaming',
                  originalError: e,
                );
              }
              // Continue processing other chunks
            }
          }
        }
      }
    } on MistralInferenceException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during Mistral inference',
        name: 'MistralInferenceRepository',
        error: e,
      );
      _logException(e, subDomain: 'unexpected', stackTrace: stackTrace);
      throw MistralInferenceException(
        'Failed to generate text: $e',
        originalError: e,
      );
    }
  }

  /// Closes the underlying HTTP client and any keep-alive connections.
  void close() => _httpClient.close();
}

/// Exception thrown when Mistral operations fail.
class MistralInferenceException implements Exception {
  MistralInferenceException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  final String message;
  final int? statusCode;
  final Object? originalError;

  @override
  String toString() => 'MistralInferenceException: $message';
}
