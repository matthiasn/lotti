import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:openai_dart/openai_dart.dart';

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
    if (getIt.isRegistered<LoggingService>()) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'MISTRAL',
        subDomain: subDomain,
        stackTrace: stackTrace,
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
  Stream<CreateChatCompletionStreamResponse> generateText({
    required String prompt,
    required String model,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  }) async* {
    yield* _generate(
      messages: [
        if (systemMessage != null) {'role': 'system', 'content': systemMessage},
        {'role': 'user', 'content': prompt},
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
  Stream<CreateChatCompletionStreamResponse> generateTextWithMessages({
    required List<ChatCompletionMessage> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  }) async* {
    yield* _generate(
      messages: _convertMessages(messages),
      model: model,
      baseUrl: baseUrl,
      apiKey: apiKey,
      temperature: temperature,
      maxCompletionTokens: maxCompletionTokens,
      tools: tools,
    );
  }

  /// Convert openai_dart messages to plain maps for manual serialization.
  List<Map<String, dynamic>> _convertMessages(
      List<ChatCompletionMessage> messages) {
    return messages.map((message) {
      final role = message.role;
      switch (role) {
        case ChatCompletionMessageRole.system:
          return message.mapOrNull(
              system: (m) => {
                    'role': 'system',
                    'content': m.content,
                  })!;

        case ChatCompletionMessageRole.user:
          return message.mapOrNull(user: (m) {
            final content = m.content.mapOrNull(
              string: (c) => c.value,
              parts: (c) => c.value
                  .map((part) => part.mapOrNull(
                        text: (t) => {'type': 'text', 'text': t.text},
                        image: (i) => {
                          'type': 'image_url',
                          'image_url': {'url': i.imageUrl.url}
                        },
                        audio: (a) => {
                          'type': 'input_audio',
                          'input_audio': {
                            'data': a.inputAudio.data,
                            'format': a.inputAudio.format.name
                          }
                        },
                      ))
                  .whereType<Map<String, dynamic>>()
                  .toList(),
            );
            return {
              'role': 'user',
              'content': content,
            };
          })!;

        case ChatCompletionMessageRole.assistant:
          return message.mapOrNull(assistant: (m) {
            final map = <String, dynamic>{'role': 'assistant'};
            if (m.content != null) {
              map['content'] = m.content;
            }
            if (m.toolCalls != null && m.toolCalls!.isNotEmpty) {
              map['tool_calls'] = m.toolCalls!
                  .map((tc) => {
                        'id': tc.id,
                        'type': 'function',
                        'function': {
                          'name': tc.function.name,
                          'arguments': tc.function.arguments,
                        }
                      })
                  .toList();
            }
            return map;
          })!;

        case ChatCompletionMessageRole.tool:
          return message.mapOrNull(
              tool: (m) => {
                    'role': 'tool',
                    'tool_call_id': m.toolCallId,
                    'content': m.content,
                  })!;

        case ChatCompletionMessageRole.function:
          return message.mapOrNull(
              function: (m) => {
                    'role': 'function',
                    'name': m.name,
                    'content': m.content,
                  })!;

        case ChatCompletionMessageRole.developer:
          return message.mapOrNull(
              developer: (m) => {
                    'role': 'developer',
                    'content': m.content,
                  })!;
      }
    }).toList();
  }

  /// Internal method to generate text with streaming.
  Stream<CreateChatCompletionStreamResponse> _generate({
    required List<Map<String, dynamic>> messages,
    required String model,
    required String baseUrl,
    required String apiKey,
    double? temperature,
    int? maxCompletionTokens,
    List<ChatCompletionTool>? tools,
  }) async* {
    final requestBody = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      if (temperature != null) 'temperature': temperature,
      if (maxCompletionTokens != null) 'max_tokens': maxCompletionTokens,
    };

    // Add tools if provided
    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools.map((tool) {
        return {
          'type': 'function',
          'function': {
            'name': tool.function.name,
            'description': tool.function.description,
            if (tool.function.parameters != null)
              'parameters': tool.function.parameters,
          }
        };
      }).toList();
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

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
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
              final response = _parseStreamResponse(json);
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

  /// Parse a streaming response chunk from Mistral's API.
  ///
  /// This method handles Mistral's response format where content may be
  /// returned as an array instead of a string.
  CreateChatCompletionStreamResponse? _parseStreamResponse(
      Map<String, dynamic> json) {
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      return null;
    }

    final parsedChoices = <ChatCompletionStreamResponseChoice>[];

    for (final choice in choices) {
      final choiceMap = choice as Map<String, dynamic>;
      final delta = choiceMap['delta'] as Map<String, dynamic>?;
      if (delta == null) continue;

      // Handle content that may be a string or an array
      final content = _extractContent(delta['content']);

      // Handle tool calls
      final toolCalls = _parseToolCalls(delta['tool_calls']);

      // Handle role
      final roleStr = delta['role'] as String?;
      ChatCompletionMessageRole? role;
      if (roleStr != null) {
        role = ChatCompletionMessageRole.values.firstWhere(
          (r) => r.name == roleStr,
          orElse: () => ChatCompletionMessageRole.assistant,
        );
      }

      // Handle finish reason - convert snake_case from API to camelCase enum
      final finishReasonStr = choiceMap['finish_reason'] as String?;
      ChatCompletionFinishReason? finishReason;
      if (finishReasonStr != null) {
        // Convert snake_case to camelCase for enum matching
        final camelCaseReason = _snakeToCamel(finishReasonStr);
        finishReason = ChatCompletionFinishReason.values.firstWhere(
          (r) => r.name == camelCaseReason,
          orElse: () => ChatCompletionFinishReason.stop,
        );
      }

      parsedChoices.add(
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(
            content: content,
            role: role,
            toolCalls: toolCalls,
          ),
          index: choiceMap['index'] as int? ?? 0,
          finishReason: finishReason,
        ),
      );
    }

    if (parsedChoices.isEmpty) {
      return null;
    }

    // Parse usage if present
    CompletionUsage? usage;
    final usageJson = json['usage'] as Map<String, dynamic>?;
    if (usageJson != null) {
      usage = CompletionUsage(
        completionTokens: usageJson['completion_tokens'] as int? ?? 0,
        promptTokens: usageJson['prompt_tokens'] as int? ?? 0,
        totalTokens: usageJson['total_tokens'] as int? ?? 0,
      );
    }

    return CreateChatCompletionStreamResponse(
      id: json['id'] as String? ??
          'mistral-${DateTime.now().millisecondsSinceEpoch}',
      choices: parsedChoices,
      object: 'chat.completion.chunk',
      created: json['created'] as int? ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      model: json['model'] as String?,
      usage: usage,
    );
  }

  /// Extract content from the delta, handling both string and array formats.
  ///
  /// Mistral may return content as:
  /// - A simple string: "Hello"
  /// - An array of content parts: [{"type": "text", "text": "Hello"}]
  String? _extractContent(dynamic content) {
    if (content == null) {
      return null;
    }

    if (content is String) {
      return content;
    }

    if (content is List) {
      // Extract text from content parts
      final textParts = <String>[];
      for (final part in content) {
        if (part is Map<String, dynamic>) {
          final type = part['type'] as String?;
          if (type == 'text') {
            final text = part['text'] as String?;
            if (text != null) {
              textParts.add(text);
            }
          }
        } else if (part is String) {
          textParts.add(part);
        }
      }
      return textParts.isEmpty ? null : textParts.join();
    }

    // Fallback: try to convert to string
    return content.toString();
  }

  /// Convert snake_case to camelCase (e.g., 'tool_calls' -> 'toolCalls')
  String _snakeToCamel(String input) {
    final parts = input.split('_');
    if (parts.length == 1) return input;

    return parts.first +
        parts.skip(1).map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        }).join();
  }

  /// Parse tool calls from the delta.
  List<ChatCompletionStreamMessageToolCallChunk>? _parseToolCalls(
      dynamic toolCalls) {
    if (toolCalls == null) return null;

    if (toolCalls is! List) return null;

    final result = <ChatCompletionStreamMessageToolCallChunk>[];

    for (final tc in toolCalls) {
      if (tc is Map<String, dynamic>) {
        final function = tc['function'] as Map<String, dynamic>?;

        result.add(
          ChatCompletionStreamMessageToolCallChunk(
            id: tc['id'] as String?,
            index: tc['index'] as int?,
            function: function != null
                ? ChatCompletionStreamMessageFunctionCall(
                    name: function['name'] as String?,
                    arguments: function['arguments'] as String?,
                  )
                : null,
          ),
        );
      }
    }

    return result.isEmpty ? null : result;
  }
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
